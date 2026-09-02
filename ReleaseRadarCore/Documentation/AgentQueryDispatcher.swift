import Foundation

/// A distinct read-only dispatcher. It has no route to AgentCommandDispatcher.
public struct AgentQueryDispatcher: Sendable {
    public static let maximumResponseBytes = 131_072
    private let store: DeliveryStore
    private let bookmarkStore: any ProjectBookmarkStoring
    public init(store: DeliveryStore, bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) {
        self.store = store; self.bookmarkStore = bookmarkStore
    }
    public func dispatch(_ envelope: AgentQueryEnvelope, admissionDeadline: TimeInterval? = nil) async -> AgentCommandResult {
        guard envelope.version == 1 else { return .init(entityIDs: [], auditEventID: nil, error: .unsupportedVersion(found: envelope.version, supported: 1)) }
        do {
            if let deadline = admissionDeadline, deadline <= Date().timeIntervalSince1970 { return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable) }
            let projectID: String?; let rootID: String?
            switch envelope.query { case let .inventoryEvidence(project, root): projectID = project; rootID = root }
            for identity in [projectID, rootID].compactMap({ $0 }) {
                guard !identity.isEmpty, identity.utf8.count <= 256, !identity.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { throw DocumentationOperationError.invalidRequest }
            }
            let captured = try await store.documentationRead { c in
                let context = try DocumentationRootContext.read(c, path: envelope.projectRoot, projectID: projectID, rootID: rootID, schemaVersion: store.schemaVersionForDocumentation)
                return try InventoryCapture(c, context: context)
            }
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: captured.context.bookmark) { resolved in
                try captured.context.verifyAuthorization(resolved)
                let inventory = try captured.resolve()
                let result = AgentCommandResult(entityIDs: [], auditEventID: nil, error: nil, inventory: inventory)
                guard try JSONEncoder().encode(result).count <= Self.maximumResponseBytes else { throw DocumentationOperationError.inventoryTooLarge }
                return result
            }
        } catch let error as DocumentationOperationError { return .init(entityIDs: [], auditEventID: nil, error: .documentation(error)) }
        catch { return .init(entityIDs: [], auditEventID: nil, error: .documentation(DocumentationCatalogContext.map(error))) }
    }
}

private struct InventoryCapture: Sendable {
    let context: DocumentationRootContext
    let records: [(LocatedEvidenceRecord, String?)]
    let roots: [DocumentationRootMetadata]
    let preservation: [String: PreservationDigest]
    let audits: [PreservationFingerprint]
    let receipts: [PreservationFingerprint]
    init(_ c: SQLiteConnection, context: DocumentationRootContext) throws {
        self.context = context
        let artifact = context.schemaVersion >= 13 ? "e.artifact_id" : "NULL AS artifact_id"
        records = try c.rows("SELECT e.id, e.ticket_id, e.path, e.is_available, \(artifact), t.phase_id FROM evidence e LEFT JOIN tickets t ON t.id = e.ticket_id AND t.project_id = e.project_id WHERE e.project_id = ? ORDER BY e.id", bindings: [.text(context.projectID)], maximum: 4096).map { row in
            guard case let .text(id) = row["id"], case let .integer(available) = row["is_available"] else { throw DocumentationOperationError.invalidRequest }
            let locator: EvidenceLocator
            switch (row["path"], row["artifact_id"]) {
            case let (.text(path), .null): locator = .filePath(path)
            case let (.null, .text(artifact)): locator = .managedDocument(artifactID: artifact)
            default: throw DocumentationOperationError.invalidRequest
            }
            let ticket: String? = if case let .text(value) = row["ticket_id"] { value } else { nil }
            let phase: String? = if case let .text(value) = row["phase_id"] { value } else { nil }
            return (.init(id: .init(rawValue: id), projectID: .init(rawValue: context.projectID), ticketID: ticket.map(TicketID.init(rawValue:)), locator: locator, isAvailable: available == 1), phase)
        }
        roots = try c.rows("SELECT r.id, r.path, b.bookmark_data, b.is_stale FROM project_roots r LEFT JOIN project_bookmarks b ON b.project_id = r.project_id AND b.path = r.path WHERE r.project_id = ? ORDER BY r.id", bindings: [.text(context.projectID)]).map { row in
            guard case let .text(id) = row["id"], case let .text(path) = row["path"] else { throw DocumentationOperationError.invalidRequest }
            let digest: String? = if case let .blob(bytes) = row["bookmark_data"] { documentationDigest(bytes) } else { nil }
            let stale: Bool? = if case let .integer(value) = row["is_stale"] { value == 1 } else { nil }
            return .init(rootID: id, path: path, bookmarkDigest: digest, isStale: stale)
        }
        preservation = try Self.preservation(c, context: context)
        audits = try Self.fingerprints(c, table: "audit_events", id: "id")
        receipts = try Self.fingerprints(c, table: "agent_command_requests", id: "request_id")
    }
    func resolve() throws -> EvidenceInventory {
        let catalog: DocumentationCatalogContext
        do { catalog = try DocumentationCatalogContext(root: context.root) }
        catch {
            let error = DocumentationCatalogContext.map(error)
            return inventory(observation: .init(guidance: .unavailable, repositoryID: nil, version: nil, digest: nil, error: error, validationError: nil), rows: records.map { row($0, error: error) })
        }
        var failure: DocumentationOperationError?
        if catalog.mode == .unavailable { failure = .guidanceUnavailable }
        else if catalog.snapshot == nil, catalog.validationError != .missingFile || catalog.mode == .managedV2 { failure = .catalogInvalid }
        if failure == nil, catalog.mode == .managedV2, let snapshot = catalog.snapshot {
            do { try context.requireAccepted(snapshot) } catch { failure = DocumentationCatalogContext.map(error) }
        }
        let observation = DocumentationCatalogObservation(guidance: catalog.mode, repositoryID: catalog.snapshot?.catalog.repositoryID.lowercased(), version: catalog.snapshot?.version,
                                                          digest: catalog.snapshot?.digest, error: failure, validationError: catalog.validationError)
        let rows = records.map { pair -> EvidenceInventoryRow in
            if let failure { return row(pair, error: failure) }
            let record = pair.0
            do {
                let artifact: RepositoryDocumentArtifact?
                let path: String
                switch record.locator {
                case let .managedDocument(id):
                    guard catalog.mode == .managedV2 else { return row(pair, error: .guidanceUnavailable) }
                    guard let match = catalog.snapshot?.catalog.artifacts.first(where: { $0.artifactID == id }) else { return row(pair, error: .evidenceConflict) }
                    artifact = match; path = match.path
                    _ = try catalog.reader.read(path)
                case let .filePath(value):
                    path = try DocumentationCatalogContext.relative(path: value, root: context.root)
                    artifact = try catalog.exactArtifact(path: value, root: context.root)
                }
                return .init(evidence: record, phaseID: pair.1, resolvedPath: path, resolvedAvailable: true,
                             lifecycle: artifact?.lifecycle, authority: artifact?.authorityLevel, candidateArtifactID: artifact?.artifactID,
                             rejection: artifact == nil ? .evidenceConflict : nil)
            } catch { return row(pair, error: DocumentationCatalogContext.map(error)) }
        }
        try catalog.reader.verifyStable()
        return inventory(observation: observation, rows: rows)
    }
    private func row(_ pair: (LocatedEvidenceRecord, String?), error: DocumentationOperationError) -> EvidenceInventoryRow {
        .init(evidence: pair.0, phaseID: pair.1, resolvedPath: nil, resolvedAvailable: false, lifecycle: nil, authority: nil, candidateArtifactID: nil, rejection: error)
    }
    private func inventory(observation: DocumentationCatalogObservation, rows: [EvidenceInventoryRow]) -> EvidenceInventory {
        .init(projectID: context.projectID, projectName: context.projectName, rootID: context.rootID, schemaVersion: context.schemaVersion,
              binding: context.binding.map(DocumentationBindingMetadata.init), catalog: observation, evidence: rows, roots: roots,
              isComplete: observation.error == nil, preservation: preservation, audits: audits, receipts: receipts)
    }
    private static func fingerprints(_ c: SQLiteConnection, table: String, id: String) throws -> [PreservationFingerprint] {
        try c.rows("SELECT * FROM \(table) ORDER BY \(id)").map { row in
            guard case let .text(value) = row[id] else { throw DocumentationOperationError.invalidRequest }
            return .init(idHash: documentationDigest(Data(value.utf8)), digest: hash(row))
        }.sorted { $0.idHash < $1.idHash }
    }
    private static func preservation(_ c: SQLiteConnection, context: DocumentationRootContext) throws -> [String: PreservationDigest] {
        let base = ["phases", "tickets", "project_active_phases", "phase_dependencies", "ticket_dependencies", "blockers", "thread_exclusions", "observed_threads", "observed_goals", "thread_links", "ticket_goal_links", "review_items", "completion_records", "notification_events", "notification_occurrences"]
        let planning = ["phase_plans", "delivery_goals", "delivery_goal_done_criteria", "delivery_goal_ticket_assignments", "delivery_goal_assignment_events"]
        var groups: [(String, [String])] = [("deliveryV10", base), ("roots", ["project_roots", "project_bookmarks"])]
        if context.schemaVersion >= 11 { groups.append(("planningV11", planning)) }
        if context.schemaVersion >= 12 { groups.append(("tasksV12", ["ticket_task_plans", "ticket_tasks"])) }
        if context.schemaVersion >= 13 { groups.append(("bindingsV13", ["project_documentation_bindings"])) }
        var result: [String: PreservationDigest] = [:]
        for (group, tables) in groups {
            for other in [false, true] {
                var hashes: [String] = []
                for table in tables {
                    let rows = try c.rows("SELECT * FROM \(table) WHERE \(other ? "project_id != ? OR project_id IS NULL" : "project_id = ?")", bindings: [.text(context.projectID)])
                    for var row in rows {
                        if table == "tickets", group == "deliveryV10" { row.removeValue(forKey: "plan_legacy_continuation") }
                        row["table"] = .text(table); hashes.append(hash(row))
                    }
                }
                result[(other ? "other." : "project.") + group] = digest(hashes)
            }
        }
        // Projects and legacy evidence are normalized identically before and after v13.
        for other in [false, true] {
            let op = other ? "!=" : "="
            let projectRows = try c.rows("SELECT * FROM projects WHERE id \(op) ?", bindings: [.text(context.projectID)])
            result[(other ? "other." : "project.") + "identity"] = digest(projectRows.map(hash))
            let artifact = context.schemaVersion >= 13 ? "artifact_id" : "NULL AS artifact_id"
            let rows = try c.rows("SELECT id, project_id, ticket_id, path, is_available, \(artifact) FROM evidence WHERE project_id \(op) ?", bindings: [.text(context.projectID)])
            result[(other ? "other." : "project.") + "evidence"] = digest(rows.map(hash))
            if context.schemaVersion >= 11 {
                let rows = try c.rows("SELECT id, project_id, plan_legacy_continuation FROM tickets WHERE project_id \(op) ?", bindings: [.text(context.projectID)])
                result[(other ? "other." : "project.") + "ticketMetadataV11"] = digest(rows.map(hash))
            }
        }
        for table in ["alert_rules", "codex_plugin_lifecycle"] { result[table] = digest(try c.rows("SELECT * FROM \(table)").map(hash)) }
        return result
    }
    private static func digest(_ hashes: [String]) -> PreservationDigest {
        .init(count: hashes.count, digest: documentationDigest(Data(hashes.sorted().joined(separator: "\n").utf8)))
    }
    private static func hash(_ row: [String: SQLiteValue]) -> String {
        var bytes = Data()
        func append(_ value: Data) { bytes.append(Data("\(value.count):".utf8)); bytes.append(value) }
        for key in row.keys.sorted() {
            append(Data(key.utf8))
            switch row[key]! {
            case let .integer(value): append(Data("i\(value)".utf8))
            case let .real(value): append(Data("r\(value.bitPattern)".utf8))
            case let .text(value): append(Data("t\(value)".utf8))
            case let .blob(value): append(Data("b".utf8) + value)
            case .null: append(Data("n".utf8))
            }
        }
        return documentationDigest(bytes)
    }
}
