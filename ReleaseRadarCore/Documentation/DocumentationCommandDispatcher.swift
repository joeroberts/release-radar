import Foundation

struct DocumentationCommandDispatcher: Sendable {
    let store: DeliveryStore
    let bookmarkStore: any ProjectBookmarkStoring

    func dispatch(_ envelope: AgentCommandEnvelope, requestBody: Data, origin: AgentCommandOrigin,
                  admissionDeadline: TimeInterval?) async -> AgentCommandResult {
        do {
            try envelope.command.validateDocumentation()
            let projectID: String
            let rootID: String
            if let target = envelope.command.documentationTarget { projectID = target.projectID; rootID = target.rootID }
            else if case let .relocateLegacyEvidence(project, root, _, _, _) = envelope.command { projectID = project; rootID = root }
            else { throw DocumentationOperationError.invalidRequest }
            let context = try await store.documentationRead { try DocumentationRootContext.read($0, path: envelope.projectRoot, projectID: projectID, rootID: rootID) }
            let receiptBody = Data(documentationDigest(requestBody).utf8)
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: context.bookmark) { resolved in
                try context.verifyAuthorization(resolved)
                // Replay is independent of the repository's later state, but still authorized.
                if let result = try await store.documentationRead({ try Self.replay($0, requestID: envelope.requestID, body: receiptBody) }) { return result }
                let prepared = try Self.prepare(envelope.command, context: context)
                let auditID = AuditEventID(rawValue: UUID().uuidString)
                let result = AgentCommandResult(entityIDs: envelope.command.documentationIDs, auditEventID: auditID, error: nil)
                let resultData = try JSONEncoder().encode(result)
                let actor: DeliveryActor = origin == .ownerApp ? .init(id: "release-radar-owner")
                    : .init(id: "release-radar-agent", threadID: envelope.assertedThreadID, threadAttribution: envelope.assertedThreadID == nil ? ThreadAttribution.none : .asserted)
                do {
                    return try await store.transact(actor: actor, reason: envelope.command.documentationAuditReason, auditEventID: auditID,
                        auditScope: .init(projectID: .init(rawValue: projectID), entityType: envelope.command.documentationTarget != nil && envelope.command.documentationIDs.first == projectID ? .project : .evidence,
                                          entityID: envelope.command.documentationIDs.first ?? projectID)) { c in
                        if let deadline = admissionDeadline, deadline <= Date().timeIntervalSince1970 { throw DocumentationControl.expired }
                        if let result = try Self.replay(c, requestID: envelope.requestID, body: receiptBody) { throw DocumentationControl.replay(result) }
                        try context.verifyPersisted(c)
                        // Re-read while the authorized scope and the store transaction are held.
                        // No mutation occurs until this exact snapshot has been revalidated.
                        let current = try Self.prepare(envelope.command, context: context)
                        guard current == prepared else { throw DocumentationOperationError.catalogUnaccepted }
                        try Self.apply(envelope.command, snapshot: current, context: context, connection: c)
                        try c.execute("INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, ?)",
                                      bindings: [.text(envelope.requestID.uuidString), .blob(receiptBody), .blob(resultData), .text(ISO8601DateFormatter().string(from: Date()))])
                        return result
                    }
                } catch let DocumentationControl.replay(result) { return result }
            }
        } catch DocumentationControl.requestIDReused { return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused) }
        catch DocumentationControl.expired { return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable) }
        catch let error as DocumentationOperationError { return .init(entityIDs: [], auditEventID: nil, error: .documentation(error)) }
        catch { return .init(entityIDs: [], auditEventID: nil, error: .documentation(DocumentationCatalogContext.map(error))) }
    }
    private static func replay(_ c: SQLiteConnection, requestID: UUID, body: Data) throws -> AgentCommandResult? {
        guard let row = try c.row("SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?", bindings: [.text(requestID.uuidString)]) else { return nil }
        guard row["request_body"] == .blob(body), case let .blob(bytes) = row["result_data"],
              let result = try? JSONDecoder().decode(AgentCommandResult.self, from: bytes) else { throw DocumentationControl.requestIDReused }
        return result
    }
    private static func prepare(_ command: AgentCommand, context: DocumentationRootContext) throws -> RepositoryDocumentSnapshot? {
        let catalog = try DocumentationCatalogContext(root: context.root)
        if case let .relocateLegacyEvidence(_, _, _, _, newPath) = command {
            guard catalog.mode != .unavailable else { throw DocumentationOperationError.guidanceUnavailable }
            let relative = try DocumentationCatalogContext.relative(path: newPath, root: context.root)
            _ = try catalog.reader.read(relative)
            if catalog.mode == .managedV2 {
                let snapshot = try catalog.managedSnapshot(); try context.requireAccepted(snapshot)
                guard try catalog.exactArtifact(path: newPath, root: context.root) == nil else { throw DocumentationOperationError.managedCommandRequired }
            }
            try catalog.reader.verifyStable()
            return catalog.snapshot
        }
        let snapshot = try catalog.managedSnapshot(target: command.documentationTarget)
        switch command {
        case .bindDocumentationRepository:
            guard context.binding == nil else { throw DocumentationOperationError.bindingConflict }
        case let .acceptDocumentationCatalog(_, priorVersion, priorDigest):
            guard let binding = context.binding else { throw DocumentationOperationError.bindingMissing }
            guard binding.rootID.rawValue == context.rootID, binding.repositoryID == snapshot.catalog.repositoryID.lowercased() else { throw DocumentationOperationError.bindingMismatch }
            guard binding.acceptedCatalogVersion == priorVersion, binding.acceptedCatalogDigest == priorDigest else { throw DocumentationOperationError.catalogUnaccepted }
            do { try RepositoryDocumentValidator().validateTransition(from: binding.acceptedSnapshot(), to: snapshot) }
            catch { throw DocumentationOperationError.invalidTransition }
        default: try context.requireAccepted(snapshot)
        }
        if case let .addManagedEvidence(_, _, _, artifactID) = command {
            guard snapshot.catalog.artifacts.contains(where: { $0.artifactID == artifactID }) else { throw DocumentationOperationError.evidenceConflict }
        }
        if case let .adoptManagedEvidence(_, adoptions) = command {
            for item in adoptions {
                guard try catalog.exactArtifact(path: item.expectedPath, root: context.root)?.artifactID == item.artifactID else { throw DocumentationOperationError.staleEvidence }
            }
        }
        try catalog.reader.verifyStable()
        return snapshot
    }
    private static func apply(_ command: AgentCommand, snapshot: RepositoryDocumentSnapshot?, context: DocumentationRootContext, connection c: SQLiteConnection) throws {
        let project = context.projectID
        switch command {
        case .bindDocumentationRepository:
            guard let snapshot,
                  try c.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings WHERE project_id = ? OR root_id = ? OR repository_id = ?", bindings: [.text(project), .text(context.rootID), .text(snapshot.catalog.repositoryID.lowercased())]) == 0 else { throw DocumentationOperationError.bindingConflict }
            try c.execute("INSERT INTO project_documentation_bindings (project_id, root_id, repository_id, accepted_catalog_version, accepted_catalog_digest, accepted_catalog) VALUES (?, ?, ?, ?, ?, ?)",
                          bindings: [.text(project), .text(context.rootID), .text(snapshot.catalog.repositoryID.lowercased()), .integer(Int64(snapshot.version)), .text(snapshot.digest), .blob(snapshot.canonicalCatalog)])
        case .acceptDocumentationCatalog:
            guard let snapshot else { throw DocumentationOperationError.catalogInvalid }
            try c.execute("UPDATE project_documentation_bindings SET accepted_catalog_version = ?, accepted_catalog_digest = ?, accepted_catalog = ? WHERE project_id = ? AND root_id = ?",
                          bindings: [.integer(Int64(snapshot.version)), .text(snapshot.digest), .blob(snapshot.canonicalCatalog), .text(project), .text(context.rootID)])
        case let .addManagedEvidence(_, id, ticket, artifact):
            if let ticket {
                guard try c.scalarText("SELECT project_id FROM tickets WHERE id = ?", bindings: [.text(ticket)]) == project else { throw DocumentationOperationError.evidenceConflict }
            }
            guard try c.scalarInt("SELECT COUNT(*) FROM evidence WHERE id = ? OR (project_id = ? AND artifact_id = ?)", bindings: [.text(id), .text(project), .text(artifact)]) == 0 else { throw DocumentationOperationError.evidenceConflict }
            try c.execute("INSERT INTO evidence (id, project_id, ticket_id, path, artifact_id, is_available) VALUES (?, ?, ?, NULL, ?, 1)",
                          bindings: [.text(id), .text(project), ticket.map(SQLiteValue.text) ?? .null, .text(artifact)])
        case let .adoptManagedEvidence(_, adoptions):
            // Validate the entire named set before its first locator update.
            for item in adoptions {
                guard let row = try c.row("SELECT project_id, ticket_id, path, artifact_id FROM evidence WHERE id = ?", bindings: [.text(item.evidenceID)]),
                      row["project_id"] == .text(project), row["path"] == .text(item.expectedPath), row["artifact_id"] == .null,
                      row["ticket_id"] == (item.expectedTicketID.map(SQLiteValue.text) ?? .null),
                      try c.scalarInt("SELECT COUNT(*) FROM evidence WHERE project_id = ? AND artifact_id = ?", bindings: [.text(project), .text(item.artifactID)]) == 0 else { throw DocumentationOperationError.staleEvidence }
            }
            for item in adoptions {
                try c.execute("UPDATE evidence SET path = NULL, artifact_id = ? WHERE project_id = ? AND id = ?", bindings: [.text(item.artifactID), .text(project), .text(item.evidenceID)])
            }
        case let .relocateLegacyEvidence(_, _, id, prior, next):
            guard let row = try c.row("SELECT project_id, path, artifact_id FROM evidence WHERE id = ?", bindings: [.text(id)]),
                  row["project_id"] == .text(project), row["path"] == .text(prior), row["artifact_id"] == .null else { throw DocumentationOperationError.staleEvidence }
            let relative = try DocumentationCatalogContext.relative(path: next, root: context.root)
            let path = context.root.appendingPathComponent(relative).path
            guard try c.scalarInt("SELECT COUNT(*) FROM evidence WHERE project_id = ? AND path = ? AND id != ?", bindings: [.text(project), .text(path), .text(id)]) == 0 else { throw DocumentationOperationError.evidenceConflict }
            try c.execute("UPDATE evidence SET path = ? WHERE project_id = ? AND id = ?", bindings: [.text(path), .text(project), .text(id)])
        default: throw DocumentationOperationError.invalidRequest
        }
    }
}
private enum DocumentationControl: Error { case requestIDReused, expired, replay(AgentCommandResult) }
