import Foundation

public struct ProjectRootSnapshot: Sendable {
    public struct Root: Identifiable, Sendable {
        public enum Role: String, Sendable { case primary, worktree }
        public let id: ProjectRootID
        public let path: String
        public let role: Role
        public let isAccessible: Bool
        public let accessDetail: String
    }
    public let registration: ProjectRegistration
    public let roots: [Root]
    public let checkedAt: Date
    fileprivate let source: RootManagementSource
}

public enum ProjectRootAction: String, Sendable, Codable {
    case authorize, reconnect, revoke
    public var title: String {
        switch self {
        case .authorize: "Authorize worktree"
        case .reconnect: "Reconnect worktree"
        case .revoke: "Revoke worktree authorization"
        }
    }
}

public enum ProjectRootManagementError: Error, LocalizedError {
    case stale, primaryRoot, wrongWorktree, unavailable, alreadyOwned
    case primaryUnavailable, gitMetadataOutsideAuthorization, invalidGitMetadata
    public var errorDescription: String? {
        switch self {
        case .stale: "The saved registration or roots changed. Reload and prepare this exact action again."
        case .primaryRoot: "The primary root cannot be revoked here. Use the accepted repository relocation action to replace it."
        case .wrongWorktree: "Select a Git worktree belonging to the saved primary repository. Discovery alone does not authorize it."
        case .unavailable: "Folder access is unavailable, stale, or mismatched. Select the exact folder again."
        case .alreadyOwned: "This folder already has a saved root or authorization. Reconnect its existing association instead."
        case .primaryUnavailable: "Access to the exact saved primary folder is unavailable. Reauthorize that primary folder in Project Health, then select the worktree again."
        case .gitMetadataOutsideAuthorization: "Git worktree metadata is outside the authorized primary and selected folders. Select the main repository folder that contains the common Git metadata, or use a supported primary-root relocation before retrying. No extra folder access was granted."
        case .invalidGitMetadata: "Git worktree links are missing, changed, unsafe or unsupported. Repair the worktree using Git outside Release Radar, then select the folder again. Repository files were not changed."
        }
    }
}

public struct PreparedProjectRootAction: Sendable {
    public let requestID: UUID
    public let action: ProjectRootAction
    public let folder: URL
    public let registration: ProjectRegistration
    fileprivate let source: RootManagementSource
    fileprivate let rootID: ProjectRootID
    fileprivate let bookmark: Data?
    fileprivate let membership: GitWorktreeMembership.Proof?
    fileprivate let requestHash: Data
}

/// Owner-only, exact-target changes to local root capabilities. Never edits repository files.
public struct ProjectRootManagement: Sendable {
    private let store: DeliveryStore
    private let bookmarkStore: any ProjectBookmarkStoring

    public init(store: DeliveryStore, bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) {
        self.store = store; self.bookmarkStore = bookmarkStore
    }

    public func snapshot(projectID: ProjectID) async throws -> ProjectRootSnapshot {
        let source = try await store.read { try RootManagementSource.read($0, projectID: projectID) }
        var roots: [ProjectRootSnapshot.Root] = []
        for root in source.roots {
            var accessible = false
            if let bookmark = root.bookmark, !root.stale {
                do { try await withAccess(bookmark, folder: URL(fileURLWithPath: root.path)) {}; accessible = true }
                catch { accessible = false }
            }
            roots.append(.init(id: root.id, path: root.path, role: root.id == source.primaryID ? .primary : .worktree,
                isAccessible: accessible, accessDetail: accessible ? "Folder access ready" : "Folder access unavailable. Reconnect this exact saved folder."))
        }
        guard try await isCurrent(source) else { throw ProjectRootManagementError.stale }
        return .init(registration: source.registration, roots: roots, checkedAt: Date(), source: source)
    }

    public func isCurrent(_ snapshot: ProjectRootSnapshot) async throws -> Bool { try await isCurrent(snapshot.source) }

    public func prepare(_ action: ProjectRootAction, folder: URL, snapshot: ProjectRootSnapshot,
                        requestID: UUID = UUID()) async throws -> PreparedProjectRootAction {
        try await store.read {
            try ProjectLifecycleManager.requireActive(projectID: snapshot.registration.projectID, connection: $0)
        }
        guard try await isCurrent(snapshot.source) else { throw ProjectRootManagementError.stale }
        let existing = snapshot.source.roots.first { $0.path == folder.path }
        if action != .authorize {
            guard let existing else { throw ProjectRootManagementError.stale }
            guard existing.id != snapshot.source.primaryID else { throw ProjectRootManagementError.primaryRoot }
        } else if existing != nil { throw ProjectRootManagementError.alreadyOwned }
        var bookmark: Data?
        var membership: GitWorktreeMembership.Proof?
        if action != .revoke {
            try Self.validateFolder(folder)
            do { bookmark = try bookmarkStore.makeBookmark(for: folder) }
            catch { throw ProjectRootManagementError.unavailable }
            membership = try await withAccess(bookmark!, folder: folder) {
                if action == .authorize {
                    return try await withPrimaryAccess(snapshot.source) { primary in
                        try GitWorktreeMembership.validate(primary: primary, candidate: folder)
                    }
                }
                return nil
            }
        }
        if action == .authorize { try await store.read { try Self.requireUnowned($0, folder: folder) } }
        guard try await isCurrent(snapshot.source) else { throw ProjectRootManagementError.stale }
        let rootID = existing?.id ?? ProjectRootID(rawValue: UUID().uuidString.lowercased())
        let identity = RootActionIdentity(requestID: requestID, action: action, path: folder.path, rootID: rootID,
            source: snapshot.source, bookmarkDigest: bookmark.map(documentationDigest), membership: membership)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return .init(requestID: requestID, action: action, folder: folder, registration: snapshot.registration,
            source: snapshot.source, rootID: rootID, bookmark: bookmark, membership: membership,
            requestHash: Data(documentationDigest(try encoder.encode(identity)).utf8))
    }

    @discardableResult
    public func confirm(_ prepared: PreparedProjectRootAction) async throws -> AuditEventID {
        if let replay = try await store.read({ connection in
            try ProjectLifecycleManager.requireActive(projectID: prepared.registration.projectID, connection: connection)
            return try Self.replay(connection, prepared)
        }) { return replay }
        if let bookmark = prepared.bookmark {
            return try await withAccess(bookmark, folder: prepared.folder) {
                if prepared.action == .authorize {
                    return try await withPrimaryAccess(prepared.source) { _ in try await commit(prepared) }
                }
                return try await commit(prepared)
            }
        }
        return try await commit(prepared)
    }

    private func commit(_ p: PreparedProjectRootAction) async throws -> AuditEventID {
        let auditID = AuditEventID(rawValue: UUID().uuidString)
        do {
            return try await store.transact(actor: .init(id: "release-radar-owner"), reason: p.action.title,
                auditEventID: auditID, auditScope: .init(projectID: p.registration.projectID, entityType: .project, entityID: p.registration.projectID.rawValue)) { c in
                try ProjectLifecycleManager.requireActive(projectID: p.registration.projectID, connection: c)
                if let replay = try Self.replay(c, p) { throw RootActionReplay.result(replay) }
                guard try RootManagementSource.read(c, projectID: p.registration.projectID) == p.source else { throw ProjectRootManagementError.stale }
                let project = p.registration.projectID.rawValue
                if p.action == .authorize {
                    try Self.requireUnowned(c, folder: p.folder)
                    guard let primary = p.source.roots.first(where: { $0.id == p.source.primaryID }),
                          try GitWorktreeMembership.validate(primary: URL(fileURLWithPath: primary.path), candidate: p.folder) == p.membership else { throw ProjectRootManagementError.stale }
                    try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)", bindings: [.text(p.rootID.rawValue), .text(project), .text(p.folder.path)])
                }
                if p.action == .revoke {
                    guard p.rootID != p.source.primaryID else { throw ProjectRootManagementError.primaryRoot }
                    try c.execute("DELETE FROM project_bookmarks WHERE project_id = ? AND path = ?", bindings: [.text(project), .text(p.folder.path)])
                    try c.execute("DELETE FROM project_roots WHERE project_id = ? AND id = ?", bindings: [.text(project), .text(p.rootID.rawValue)])
                } else {
                    try Self.validateFolder(p.folder)
                    guard let bookmark = p.bookmark else { throw ProjectRootManagementError.unavailable }
                    try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0) ON CONFLICT(project_id, path) DO UPDATE SET bookmark_data = excluded.bookmark_data, is_stale = 0", bindings: [.text(project), .text(p.folder.path), .blob(bookmark)])
                }
                try c.execute("INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, ?)", bindings: [.text(p.requestID.uuidString), .blob(p.requestHash), .blob(try JSONEncoder().encode(auditID)), .text(ISO8601DateFormatter().string(from: Date()))])
                return auditID
            }
        } catch let RootActionReplay.result(id) { return id }
    }

    private func isCurrent(_ source: RootManagementSource) async throws -> Bool {
        try await store.read { try RootManagementSource.read($0, projectID: source.registration.projectID) == source }
    }
    private func withAccess<T: Sendable>(_ bookmark: Data, folder: URL, _ body: @Sendable () async throws -> T) async throws -> T {
        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in
                guard !resolved.isStale, resolved.url.path == folder.path else { throw ProjectRootManagementError.unavailable }
                try Self.validateFolder(folder)
                return try await body()
            }
        } catch is ProjectBookmarkError { throw ProjectRootManagementError.unavailable }
    }
    private static func validateFolder(_ folder: URL) throws {
        guard folder.isFileURL, folder.standardizedFileURL.path == folder.path,
              folder.resolvingSymlinksInPath().path == folder.path,
              (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { throw ProjectRootManagementError.unavailable }
    }
    private func withPrimaryAccess<T: Sendable>(_ source: RootManagementSource, _ body: @Sendable (URL) async throws -> T) async throws -> T {
        guard let primary = source.roots.first(where: { $0.id == source.primaryID }),
              let bookmark = primary.bookmark, !primary.stale else { throw ProjectRootManagementError.primaryUnavailable }
        let folder = URL(fileURLWithPath: primary.path)
        do { return try await withAccess(bookmark, folder: folder) { try await body(folder) } }
        catch ProjectRootManagementError.unavailable { throw ProjectRootManagementError.primaryUnavailable }
    }
    private static func requireUnowned(_ c: SQLiteConnection, folder: URL) throws {
        guard try c.scalarInt("SELECT COUNT(*) FROM project_roots WHERE path = ?", bindings: [.text(folder.path)]) == 0,
              try c.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE path = ?", bindings: [.text(folder.path)]) == 0 else { throw ProjectRootManagementError.alreadyOwned }
    }
    private static func replay(_ c: SQLiteConnection, _ p: PreparedProjectRootAction) throws -> AuditEventID? {
        guard try RootManagementSource.registration(c, projectID: p.registration.projectID) == p.registration else { throw ProjectRootManagementError.stale }
        guard let row = try c.row("SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?", bindings: [.text(p.requestID.uuidString)]) else { return nil }
        guard row["request_body"] == .blob(p.requestHash), case let .blob(data) = row["result_data"],
              let id = try? JSONDecoder().decode(AuditEventID.self, from: data) else { throw ProjectRootManagementError.stale }
        return id
    }
}

private enum RootActionReplay: Error { case result(AuditEventID) }
private struct RootActionIdentity: Encodable {
    let requestID: UUID; let action: ProjectRootAction; let path: String; let rootID: ProjectRootID
    let source: RootManagementSource; let bookmarkDigest: String?; let membership: GitWorktreeMembership.Proof?
}
fileprivate struct RootManagementSource: Equatable, Encodable, Sendable {
    struct Root: Equatable, Encodable, Sendable {
        let id: ProjectRootID; let path: String; let bookmark: Data?; let stale: Bool
    }
    let registration: ProjectRegistration
    let primaryID: ProjectRootID?
    let roots: [Root]

    static func registration(_ c: SQLiteConnection, projectID: ProjectID) throws -> ProjectRegistration {
        guard let row = try c.row("SELECT registration_id, request_generation FROM project_registrations WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
              case let .text(id) = row["registration_id"], case let .integer(generation) = row["request_generation"] else { throw ProjectRootManagementError.stale }
        return .init(projectID: projectID, registrationID: id, requestGeneration: generation)
    }
    static func read(_ c: SQLiteConnection, projectID: ProjectID) throws -> Self {
        let registration = try registration(c, projectID: projectID)
        var roots: [Root] = []
        while let row = try c.row("SELECT r.id, r.path, b.bookmark_data, b.is_stale FROM project_roots r LEFT JOIN project_bookmarks b ON b.project_id = r.project_id AND b.path = r.path WHERE r.project_id = ? ORDER BY r.rowid LIMIT 1 OFFSET ?", bindings: [.text(projectID.rawValue), .integer(Int64(roots.count))]) {
            guard case let .text(id) = row["id"], case let .text(path) = row["path"] else { throw ProjectRootManagementError.stale }
            let bookmark: Data?
            if case let .blob(data) = row["bookmark_data"] { bookmark = data } else { bookmark = nil }
            roots.append(.init(id: .init(rawValue: id), path: path, bookmark: bookmark, stale: row["is_stale"] != .integer(0)))
        }
        let bound = try c.scalarText("SELECT root_id FROM project_documentation_bindings WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
        let primary = bound.map(ProjectRootID.init(rawValue:)) ?? roots.first?.id
        guard primary == nil || roots.contains(where: { $0.id == primary }) else { throw ProjectRootManagementError.stale }
        return .init(registration: registration, primaryID: primary, roots: roots)
    }
}
