import Foundation

public enum RepositoryRootRelocationError: String, Error, LocalizedError, Sendable {
    case bindingUnavailable, sameRoot, unsafeRoot, rootAlreadyOwned, authorizationFailed
    case catalogMismatch, sourceChanged, handoffConflict, requestIDReused

    public var errorDescription: String? {
        switch self {
        case .bindingUnavailable: "This project needs an accepted documentation binding before its repository can be relocated."
        case .sameRoot: "Choose the relocated repository folder. Use reauthorization to restore access to the same folder."
        case .unsafeRoot: "Choose a regular repository folder without symbolic links."
        case .rootAlreadyOwned: "The selected folder already has a saved project association or authorization."
        case .authorizationFailed: "Folder access is unavailable, stale, or mismatched. Select the relocated repository again."
        case .catalogMismatch: "The selected repository must contain the exact accepted catalog and valid managed documents. Restore that snapshot and select the folder again."
        case .sourceChanged: "Project authorization or evidence changed after preparation. Select the relocated folder again."
        case .handoffConflict: "The root AGENTS.md handoff evidence is ambiguous or mismatched. Resolve its exact evidence association before relocating."
        case .requestIDReused: "This relocation request ID already identifies a different operation. Prepare a new relocation."
        }
    }
}

/// Created only by a successful owner preparation. Bookmark bytes remain private
/// in memory; neither the confirmation UI nor the durable receipt receives them.
public struct PreparedRepositoryRootRelocation: Sendable {
    public let requestID: UUID
    public let projectID: ProjectID
    public let oldRoot: URL
    public let selectedRoot: URL
    public let repositoryID: String
    public let catalogVersion: Int
    public let catalogDigest: String
    fileprivate let newRootID: ProjectRootID
    fileprivate let source: RelocationSource
    fileprivate let bookmark: Data
    fileprivate let requestHash: Data
    public var recoveryToken: RepositoryRootRelocationRecoveryToken {
        .init(version: 1, requestID: requestID, projectID: projectID, rootID: newRootID,
              requestHash: String(decoding: requestHash, as: UTF8.self))
    }
}

/// Safe to retain across app restarts: contains no bookmark or filesystem path.
public struct RepositoryRootRelocationRecoveryToken: Equatable, Codable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let projectID: ProjectID
    public let rootID: ProjectRootID
    public let requestHash: String
}

public struct RepositoryRootRelocationResult: Equatable, Codable, Sendable {
    public let projectID: ProjectID
    public let rootID: ProjectRootID
    public let auditEventID: AuditEventID
}

/// Owner-only operation. Intentionally absent from AgentCommand and the bridge.
public struct RepositoryRootRelocation: Sendable {
    private let store: DeliveryStore
    private let bookmarkStore: any ProjectBookmarkStoring

    public init(store: DeliveryStore, bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) {
        self.store = store; self.bookmarkStore = bookmarkStore
    }

    public func prepare(projectID: ProjectID, folder: URL, requestID: UUID = UUID()) async throws -> PreparedRepositoryRootRelocation {
        guard folder.isFileURL, folder.standardizedFileURL.path == folder.path,
              folder.resolvingSymlinksInPath().path == folder.path else { throw RepositoryRootRelocationError.unsafeRoot }
        let source = try await store.documentationRead { try RelocationSource.read($0, projectID: projectID) }
        guard source.path != folder.path else { throw RepositoryRootRelocationError.sameRoot }
        try await store.read { try Self.requireUnowned($0, folder: folder) }
        let bookmark: Data
        do { bookmark = try bookmarkStore.makeBookmark(for: folder) }
        catch { throw RepositoryRootRelocationError.authorizationFailed }
        try await withCandidate(bookmark: bookmark, folder: folder, binding: source.binding) {
            try Self.validateCandidate(folder: folder, binding: source.binding, hasHandoff: source.handoff != nil)
        }
        try await store.read { try Self.requireHandoffDestination($0, projectID: projectID, folder: folder) }
        let newRootID = ProjectRootID(rawValue: UUID().uuidString)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let identity = RelocationIdentity(operation: "owner-repository-root-relocation-v1", requestID: requestID,
            newRootID: newRootID, source: source, selectedPath: folder.path, bookmarkDigest: documentationDigest(bookmark))
        let hash = Data(documentationDigest(try encoder.encode(identity)).utf8)
        return .init(requestID: requestID, projectID: projectID, oldRoot: URL(fileURLWithPath: source.path),
            selectedRoot: folder, repositoryID: source.binding.repositoryID, catalogVersion: source.binding.acceptedCatalogVersion,
            catalogDigest: source.binding.acceptedCatalogDigest, newRootID: newRootID, source: source, bookmark: bookmark, requestHash: hash)
    }

    /// Read-only recovery of one exact receipt. Nil means no committed receipt;
    /// it never retries a mutation or asks for the revoked old bookmark.
    public func recover(_ token: RepositoryRootRelocationRecoveryToken) async throws -> RepositoryRootRelocationResult? {
        try await store.documentationRead { try Self.replay($0, token: token) }
    }

    public func confirm(_ prepared: PreparedRepositoryRootRelocation) async throws -> RepositoryRootRelocationResult {
        // Exact replay is read before the old, now revoked root is needed.
        if let result = try await store.read({ try Self.replay($0, prepared) }) { return result }
        return try await withCandidate(bookmark: prepared.bookmark, folder: prepared.selectedRoot, binding: prepared.source.binding) {
            let auditID = AuditEventID(rawValue: UUID().uuidString)
            let result = RepositoryRootRelocationResult(projectID: prepared.projectID, rootID: prepared.newRootID, auditEventID: auditID)
            let resultData = try JSONEncoder().encode(result)
            do {
                return try await store.transact(actor: .init(id: "release-radar-owner"), reason: "Relocate bound documentation repository",
                    auditEventID: auditID, auditScope: .init(projectID: prepared.projectID, entityType: .project, entityID: prepared.projectID.rawValue)) { c in
                    if let replay = try Self.replay(c, prepared) { throw RelocationReplay.result(replay) }
                    guard try RelocationSource.read(c, projectID: prepared.projectID) == prepared.source else { throw RepositoryRootRelocationError.sourceChanged }
                    try Self.requireUnowned(c, folder: prepared.selectedRoot)
                    try Self.requireHandoffDestination(c, projectID: prepared.projectID, folder: prepared.selectedRoot)
                    // Synchronous no-follow revalidation is inside the one store-owned
                    // transaction, before its first change, while new scope is held.
                    try Self.validateCandidate(folder: prepared.selectedRoot, binding: prepared.source.binding, hasHandoff: prepared.source.handoff != nil)
                    let project = prepared.projectID.rawValue
                    try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)", bindings: [.text(prepared.newRootID.rawValue), .text(project), .text(prepared.selectedRoot.path)])
                    try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)", bindings: [.text(project), .text(prepared.selectedRoot.path), .blob(prepared.bookmark)])
                    try c.execute("UPDATE project_documentation_bindings SET root_id = ? WHERE project_id = ? AND root_id = ?", bindings: [.text(prepared.newRootID.rawValue), .text(project), .text(prepared.source.binding.rootID.rawValue)])
                    if let handoff = prepared.source.handoff {
                        try c.execute("UPDATE evidence SET path = ? WHERE project_id = ? AND id = ?", bindings: [.text(prepared.selectedRoot.appendingPathComponent(RepositoryDocumentContract.guidancePath).path), .text(project), .text(handoff.id.rawValue)])
                    }
                    try c.execute("DELETE FROM project_bookmarks WHERE project_id = ? AND path = ?", bindings: [.text(project), .text(prepared.source.path)])
                    try c.execute("DELETE FROM project_roots WHERE project_id = ? AND id = ?", bindings: [.text(project), .text(prepared.source.binding.rootID.rawValue)])
                    try c.execute("INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, ?)", bindings: [.text(prepared.requestID.uuidString), .blob(prepared.requestHash), .blob(resultData), .text(ISO8601DateFormatter().string(from: Date()))])
                    return result
                }
            } catch let RelocationReplay.result(result) { return result }
        }
    }

    private func withCandidate<T: Sendable>(bookmark: Data, folder: URL, binding: ProjectDocumentationBinding,
                                            _ body: @Sendable () async throws -> T) async throws -> T {
        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in
                guard !resolved.isStale, resolved.url.path == folder.path else { throw RepositoryRootRelocationError.authorizationFailed }
                try Self.validateCandidate(folder: folder, binding: binding, hasHandoff: false)
                return try await body()
            }
        } catch let error as ProjectBookmarkError {
            _ = error
            throw RepositoryRootRelocationError.authorizationFailed
        }
    }

    private static func validateCandidate(folder: URL, binding: ProjectDocumentationBinding, hasHandoff: Bool) throws {
        do {
            let catalog = try DocumentationCatalogContext(root: folder)
            let snapshot = try catalog.managedSnapshot()
            guard snapshot.catalog.repositoryID.lowercased() == binding.repositoryID, snapshot.version == binding.acceptedCatalogVersion,
                  snapshot.digest == binding.acceptedCatalogDigest, snapshot.canonicalCatalog == binding.acceptedCatalog else { throw RepositoryRootRelocationError.catalogMismatch }
            if hasHandoff { _ = try catalog.reader.read(RepositoryDocumentContract.guidancePath) }
            try catalog.reader.verifyStable()
        } catch { throw RepositoryRootRelocationError.catalogMismatch }
    }
    private static func requireUnowned(_ c: SQLiteConnection, folder: URL) throws {
        guard try c.scalarInt("SELECT COUNT(*) FROM project_roots WHERE path = ?", bindings: [.text(folder.path)]) == 0,
              try c.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE path = ?", bindings: [.text(folder.path)]) == 0 else { throw RepositoryRootRelocationError.rootAlreadyOwned }
    }
    private static func requireHandoffDestination(_ c: SQLiteConnection, projectID: ProjectID, folder: URL) throws {
        guard try c.scalarInt("SELECT COUNT(*) FROM evidence WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(folder.appendingPathComponent(RepositoryDocumentContract.guidancePath).path)]) == 0 else { throw RepositoryRootRelocationError.handoffConflict }
    }
    private static func replay(_ c: SQLiteConnection, _ prepared: PreparedRepositoryRootRelocation) throws -> RepositoryRootRelocationResult? {
        try replay(c, token: prepared.recoveryToken)
    }
    private static func replay(_ c: SQLiteConnection, token: RepositoryRootRelocationRecoveryToken) throws -> RepositoryRootRelocationResult? {
        guard token.version == 1, token.requestHash.count == 64,
              token.requestHash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw RepositoryRootRelocationError.requestIDReused }
        guard let row = try c.row("SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?", bindings: [.text(token.requestID.uuidString)]) else { return nil }
        guard row["request_body"] == .blob(Data(token.requestHash.utf8)), case let .blob(data) = row["result_data"],
              let result = try? JSONDecoder().decode(RepositoryRootRelocationResult.self, from: data),
              result.projectID == token.projectID, result.rootID == token.rootID else { throw RepositoryRootRelocationError.requestIDReused }
        return result
    }
}

private enum RelocationReplay: Error { case result(RepositoryRootRelocationResult) }
private struct RelocationIdentity: Encodable {
    let operation: String; let requestID: UUID; let newRootID: ProjectRootID
    let source: RelocationSource; let selectedPath: String; let bookmarkDigest: String
}
fileprivate struct RelocationSource: Equatable, Encodable, Sendable {
    let binding: ProjectDocumentationBinding
    let path: String
    let bookmarkDigest: String?
    let bookmarkStale: Int64?
    let handoff: LocatedEvidenceRecord?

    static func read(_ c: SQLiteConnection, projectID: ProjectID) throws -> Self {
        guard let binding = try DocumentationRootContext.binding(c, projectID: projectID.rawValue),
              let path = try c.scalarText("SELECT path FROM project_roots WHERE project_id = ? AND id = ?", bindings: [.text(projectID.rawValue), .text(binding.rootID.rawValue)]) else { throw RepositoryRootRelocationError.bindingUnavailable }
        let bookmark = try c.row("SELECT bookmark_data, is_stale FROM project_bookmarks WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(path)])
        let digest: String?
        if case let .blob(data) = bookmark?["bookmark_data"] { digest = documentationDigest(data) } else { digest = nil }
        let stale: Int64?
        if case let .integer(value) = bookmark?["is_stale"] { stale = value } else { stale = nil }
        let handoffPath = URL(fileURLWithPath: path).appendingPathComponent(RepositoryDocumentContract.guidancePath).path
        // Include suspicious handoff IDs and exact-path rows so a mismatch cannot
        // disappear into the zero-row case. No basename or prefix path matching.
        let sql = "SELECT id, ticket_id, path, artifact_id, is_available FROM evidence WHERE project_id = ? AND (substr(id, 1, ?) = ? OR path = ?)"
        let args: [SQLiteValue] = [.text(projectID.rawValue), .integer(Int64(ProjectGuidanceInspection.handoffEvidenceIDPrefix.count)), .text(ProjectGuidanceInspection.handoffEvidenceIDPrefix), .text(handoffPath)]
        let row = try c.row(sql + " ORDER BY id LIMIT 1", bindings: args)
        guard try c.row(sql + " ORDER BY id LIMIT 1 OFFSET 1", bindings: args) == nil else { throw RepositoryRootRelocationError.handoffConflict }
        var handoff: LocatedEvidenceRecord?
        if let row {
            guard case let .text(id) = row["id"], id.hasPrefix(ProjectGuidanceInspection.handoffEvidenceIDPrefix),
                  row["path"] == .text(handoffPath), row["artifact_id"] == .null, row["ticket_id"] == .null,
                  case let .integer(available) = row["is_available"] else { throw RepositoryRootRelocationError.handoffConflict }
            handoff = .init(id: .init(rawValue: id), projectID: projectID, ticketID: nil, locator: .filePath(handoffPath), isAvailable: available == 1)
        }
        return .init(binding: binding, path: path, bookmarkDigest: digest, bookmarkStale: stale, handoff: handoff)
    }
}
