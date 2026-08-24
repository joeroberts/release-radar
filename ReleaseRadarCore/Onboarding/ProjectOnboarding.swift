import Foundation

public struct CodexTaskDescriptor: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let workingDirectory: URL
    public let title: String

    public init(id: String, workingDirectory: URL, title: String) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.title = title
    }
}

public struct OnboardingPreview: Equatable, Sendable {
    public let selectedFolder: URL
    public let gitRoot: URL?
    public let includedTaskDescriptors: [CodexTaskDescriptor]
    public let rejectedTaskDescriptors: [CodexTaskDescriptor]
    public let authorizedWorktreeURLs: [URL]
    public let worktreesRequiringAuthorization: [URL]

    public init(
        selectedFolder: URL,
        gitRoot: URL?,
        includedTaskDescriptors: [CodexTaskDescriptor],
        rejectedTaskDescriptors: [CodexTaskDescriptor],
        authorizedWorktreeURLs: [URL],
        worktreesRequiringAuthorization: [URL]
    ) {
        self.selectedFolder = selectedFolder
        self.gitRoot = gitRoot
        self.includedTaskDescriptors = includedTaskDescriptors
        self.rejectedTaskDescriptors = rejectedTaskDescriptors
        self.authorizedWorktreeURLs = authorizedWorktreeURLs
        self.worktreesRequiringAuthorization = worktreesRequiringAuthorization
    }
}

public struct OnboardingDecision: Equatable, Sendable {
    public let preview: OnboardingPreview
    public let projectName: String
    public let excludedTaskIDs: Set<String>

    public init(preview: OnboardingPreview, projectName: String, excludedTaskIDs: Set<String> = []) {
        self.preview = preview
        self.projectName = projectName
        self.excludedTaskIDs = excludedTaskIDs
    }
}

public enum OnboardingError: Error, LocalizedError, Equatable, Sendable {
    case invalidFolder
    case invalidProjectName
    case noFirstPhase
    case projectNotPrepared
    case rootAlreadyOwned

    public var errorDescription: String? {
        switch self {
        case .invalidFolder: "The selected folder is unavailable."
        case .invalidProjectName: "A project name is required."
        case .noFirstPhase: "Ask an agent to define the first phase before finishing onboarding."
        case .projectNotPrepared: "Prepare the project before requesting its first phase."
        case .rootAlreadyOwned: "A selected root or worktree already belongs to another project."
        }
    }
}

public protocol ProjectOnboarding: Sendable {
    func inspect(folder: URL) async throws -> OnboardingPreview
    func finish(_ decision: OnboardingDecision) async throws -> ProjectID
}

public actor FolderProjectOnboarding: ProjectOnboarding {
    private let store: DeliveryStore
    private let bookmarkStore: any ProjectBookmarkStoring
    private let worktreeDiscovery: any GitWorktreeDiscovering
    private let codexTasks: [CodexTaskDescriptor]
    private var separatelyAuthorizedWorktreePaths: Set<String> = []

    public init(
        store: DeliveryStore,
        bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore(),
        worktreeDiscovery: any GitWorktreeDiscovering = GitWorktreeDiscovery(),
        codexTasks: [CodexTaskDescriptor] = []
    ) {
        self.store = store
        self.bookmarkStore = bookmarkStore
        self.worktreeDiscovery = worktreeDiscovery
        self.codexTasks = codexTasks
    }

    public func inspect(folder: URL) async throws -> OnboardingPreview {
        let selected = Self.canonical(folder)
        guard FileManager.default.fileExists(atPath: selected.path) else {
            throw OnboardingError.invalidFolder
        }
        let selectedBookmark = try bookmarkStore.makeBookmark(for: selected)
        let separatelyAuthorizedPaths = separatelyAuthorizedWorktreePaths
        return try await bookmarkStore.withSecurityScopedAccess(bookmark: selectedBookmark) { [self] resolved in
            guard !resolved.isStale else { throw OnboardingError.invalidFolder }
            let authorizedSelected = Self.canonical(resolved.url)
            guard FileManager.default.fileExists(atPath: authorizedSelected.path) else {
                throw OnboardingError.invalidFolder
            }
            let worktrees = (try? worktreeDiscovery.discoverWorktrees(at: authorizedSelected)) ?? []
            let persistedAuthorizedPaths = try await persistedAuthorizedWorktreePaths(for: authorizedSelected)
            let authorized = worktrees.filter {
                Self.contains($0, within: authorizedSelected)
                    || separatelyAuthorizedPaths.contains(Self.canonical($0).path)
                    || persistedAuthorizedPaths.contains(Self.canonical($0).path)
            }
            let outsideWorktrees = worktrees.filter { !authorized.contains(Self.canonical($0)) }
            let roots = [authorizedSelected] + authorized
            let excluded = try await excludedTaskIDs(for: authorizedSelected)
            let included = codexTasks.filter { descriptor in
                !excluded.contains(descriptor.id)
                    && roots.contains(where: { Self.contains(Self.canonical(descriptor.workingDirectory), within: $0) })
            }
            let rejected = codexTasks.filter { descriptor in
                let path = Self.canonical(descriptor.workingDirectory)
                return !roots.contains(where: { Self.contains(path, within: $0) })
            }
            return .init(
                selectedFolder: authorizedSelected,
                gitRoot: GitWorktreeDiscovery.discoverGitRoot(at: authorizedSelected) ?? worktrees.first,
                includedTaskDescriptors: included,
                rejectedTaskDescriptors: rejected,
                authorizedWorktreeURLs: authorized,
                worktreesRequiringAuthorization: outsideWorktrees
            )
        }
    }

    public func authorizeWorktree(_ url: URL, for preview: OnboardingPreview) throws {
        let candidate = Self.canonical(url)
        guard preview.worktreesRequiringAuthorization.contains(candidate) else {
            throw OnboardingError.invalidFolder
        }
        separatelyAuthorizedWorktreePaths.insert(candidate.path)
    }

    public func prepare(_ decision: OnboardingDecision) async throws -> ProjectID {
        guard !decision.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OnboardingError.invalidProjectName
        }
        let projectID = ProjectID(rawValue: Self.projectID(for: decision.preview.selectedFolder))
        let roots = [decision.preview.selectedFolder] + decision.preview.authorizedWorktreeURLs
        let bookmarks = try roots.map { try bookmarkStore.makeBookmark(for: $0) }
        try await store.transact(actor: .init(id: "release-radar-onboarding"), reason: "Prepare folder-backed project onboarding") { connection in
            for root in roots {
                let path = Self.canonical(root).path
                if let ownerID = try connection.scalarText(
                    "SELECT project_id FROM project_roots WHERE path = ?",
                    bindings: [.text(path)]
                ), ownerID != projectID.rawValue {
                    throw OnboardingError.rootAlreadyOwned
                }
            }
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 0) ON CONFLICT(id) DO UPDATE SET name = excluded.name",
                bindings: [.text(projectID.rawValue), .text(decision.projectName)]
            )
            for (index, root) in roots.enumerated() {
                let path = Self.canonical(root).path
                try connection.execute(
                    "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?) ON CONFLICT(path) DO NOTHING",
                    bindings: [.text("\(projectID.rawValue)-root-\(index)"), .text(projectID.rawValue), .text(path)]
                )
                try connection.execute(
                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0) ON CONFLICT(project_id, path) DO UPDATE SET bookmark_data = excluded.bookmark_data, is_stale = 0",
                    bindings: [.text(projectID.rawValue), .text(path), .blob(bookmarks[index])]
                )
            }
            for taskID in decision.excludedTaskIDs {
                try connection.execute(
                    "INSERT INTO thread_exclusions (id, project_id, thread_id, reason) VALUES (?, ?, ?, ?) ON CONFLICT(project_id, thread_id) DO NOTHING",
                    bindings: [.text("\(projectID.rawValue)-excluded-\(taskID)"), .text(projectID.rawValue), .text(taskID), .text("Excluded during onboarding")]
                )
            }
        }
        return projectID
    }

    public func requestFirstPhaseDefinition(projectID: ProjectID) async throws {
        guard try await projectExists(projectID) else { throw OnboardingError.projectNotPrepared }
        try await store.transact(actor: .init(id: "release-radar-onboarding"), reason: "Request agent-defined first phase") { connection in
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, NULL, 'onboarding_phase_request', 'Agent requested to define the first phase', 'open') ON CONFLICT(id) DO NOTHING",
                bindings: [.text("\(projectID.rawValue)-first-phase-request"), .text(projectID.rawValue)]
            )
        }
    }

    public func hasFirstPhase(projectID: ProjectID) async throws -> Bool {
        try await phaseCount(for: projectID) > 0
    }

    public func finish(_ decision: OnboardingDecision) async throws -> ProjectID {
        let projectID = ProjectID(rawValue: Self.projectID(for: decision.preview.selectedFolder))
        guard try await projectExists(projectID) else { throw OnboardingError.projectNotPrepared }
        guard try await phaseCount(for: projectID) > 0 else { throw OnboardingError.noFirstPhase }
        let included = decision.preview.includedTaskDescriptors.filter { !decision.excludedTaskIDs.contains($0.id) }
        try await store.transact(actor: .init(id: "release-radar-onboarding"), reason: "Finish folder-backed project onboarding") { connection in
            try connection.execute(
                "DELETE FROM thread_exclusions WHERE project_id = ? AND reason = 'Excluded during onboarding'",
                bindings: [.text(projectID.rawValue)]
            )
            for taskID in decision.excludedTaskIDs {
                try connection.execute(
                    "INSERT INTO thread_exclusions (id, project_id, thread_id, reason) VALUES (?, ?, ?, 'Excluded during onboarding') ON CONFLICT(project_id, thread_id) DO UPDATE SET reason = excluded.reason",
                    bindings: [.text("\(projectID.rawValue)-excluded-\(taskID)"), .text(projectID.rawValue), .text(taskID)]
                )
            }
            for descriptor in included {
                try connection.execute(
                    "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, NULL, 'unmatched_codex_task', ?, 'open') ON CONFLICT(id) DO NOTHING",
                    bindings: [.text("\(projectID.rawValue)-review-\(descriptor.id)"), .text(projectID.rawValue), .text(descriptor.title)]
                )
            }
        }
        return projectID
    }

    private func excludedTaskIDs(for selectedFolder: URL) async throws -> Set<String> {
        guard let projectID = try? await projectID(forRoot: selectedFolder) else { return [] }
        return try await store.read { connection in
            var ids: Set<String> = []
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT thread_id FROM thread_exclusions WHERE project_id = ? ORDER BY id LIMIT 1 OFFSET ?",
                bindings: [.text(projectID.rawValue), .integer(offset)]
            ) {
                if case let .text(id)? = row["thread_id"] { ids.insert(id) }
                offset += 1
            }
            return ids
        }
    }

    private func projectID(forRoot root: URL) async throws -> ProjectID? {
        try await store.read { connection in
            guard let id = try connection.scalarText("SELECT project_id FROM project_roots WHERE path = ?", bindings: [.text(root.path)]) else { return nil }
            return .init(rawValue: id)
        }
    }

    private func persistedAuthorizedWorktreePaths(for selectedFolder: URL) async throws -> Set<String> {
        guard let projectID = try await projectID(forRoot: selectedFolder) else { return [] }
        let rows = try await store.read { connection in
            var rows: [(String, Data, Int64)] = []
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT path, bookmark_data, is_stale FROM project_bookmarks WHERE project_id = ? ORDER BY path LIMIT 1 OFFSET ?",
                bindings: [.text(projectID.rawValue), .integer(offset)]
            ) {
                if case let .text(path)? = row["path"], case let .blob(bookmark)? = row["bookmark_data"], case let .integer(isStale)? = row["is_stale"] {
                    rows.append((path, bookmark, isStale))
                }
                offset += 1
            }
            return rows
        }
        var authorizedPaths: Set<String> = []
        for (path, bookmark, isMarkedStale) in rows {
            guard isMarkedStale == 0 else { continue }
            do {
                let resolved = try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { resolved in resolved }
                guard !resolved.isStale else {
                    try await markBookmarkStale(projectID: projectID, path: path)
                    continue
                }
                authorizedPaths.insert(Self.canonical(resolved.url).path)
            } catch {
                try await markBookmarkStale(projectID: projectID, path: path)
            }
        }
        return authorizedPaths
    }

    private func markBookmarkStale(projectID: ProjectID, path: String) async throws {
        try await store.transact(actor: .init(id: "release-radar-onboarding"), reason: "Mark unavailable project bookmark") { connection in
            try connection.execute(
                "UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = ? AND path = ?",
                bindings: [.text(projectID.rawValue), .text(path)]
            )
        }
    }

    private func projectExists(_ projectID: ProjectID) async throws -> Bool {
        try await store.read { connection in
            (try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]) ?? 0) == 1
        }
    }

    private func phaseCount(for projectID: ProjectID) async throws -> Int64 {
        try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]) ?? 0
        }
    }


    private static func projectID(for folder: URL) -> String {
        let digest = folder.path.utf8.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
        return "project-\(String(digest, radix: 16))"
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func contains(_ candidate: URL, within root: URL) -> Bool {
        let candidateComponents = candidate.pathComponents
        let rootComponents = root.pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}
