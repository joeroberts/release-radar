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

    public var errorDescription: String? {
        switch self {
        case .invalidFolder: "The selected folder is unavailable."
        case .invalidProjectName: "A project name is required."
        case .noFirstPhase: "Ask an agent to define the first phase before finishing onboarding."
        case .projectNotPrepared: "Prepare the project before requesting its first phase."
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
        let accessingSelectedFolder = selected.startAccessingSecurityScopedResource()
        defer {
            if accessingSelectedFolder {
                selected.stopAccessingSecurityScopedResource()
            }
        }
        let worktrees = (try? worktreeDiscovery.discoverWorktrees(at: selected)) ?? []
        let persistedAuthorizedPaths = try await persistedAuthorizedWorktreePaths(for: selected)
        let authorized = worktrees.filter {
            Self.contains($0, within: selected)
                || separatelyAuthorizedWorktreePaths.contains(Self.canonical($0).path)
                || persistedAuthorizedPaths.contains(Self.canonical($0).path)
        }
        let outsideWorktrees = worktrees.filter { !authorized.contains(Self.canonical($0)) }
        let roots = [selected] + authorized
        let excluded = try await excludedTaskIDs(for: selected)
        let included = codexTasks.filter { descriptor in
            !excluded.contains(descriptor.id)
                && roots.contains(where: { Self.contains(Self.canonical(descriptor.workingDirectory), within: $0) })
        }
        let rejected = codexTasks.filter { descriptor in
            let path = Self.canonical(descriptor.workingDirectory)
            return !roots.contains(where: { Self.contains(path, within: $0) })
        }
        return .init(
            selectedFolder: selected,
            gitRoot: GitWorktreeDiscovery.discoverGitRoot(at: selected) ?? worktrees.first,
            includedTaskDescriptors: included,
            rejectedTaskDescriptors: rejected,
            authorizedWorktreeURLs: authorized,
            worktreesRequiringAuthorization: outsideWorktrees
        )
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
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 0) ON CONFLICT(id) DO UPDATE SET name = excluded.name",
                bindings: [.text(projectID.rawValue), .text(decision.projectName)]
            )
            for (index, root) in roots.enumerated() {
                let path = Self.canonical(root).path
                try connection.execute(
                    "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?) ON CONFLICT(path) DO UPDATE SET project_id = excluded.project_id",
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

    public func askAgentToDefineFirstPhase(
        projectID: ProjectID,
        phaseID: String,
        name: String
    ) async -> AgentCommandResult {
        guard let root = try? await primaryRoot(for: projectID),
              let authorizedRoots = try? await roots(for: projectID)
        else {
            return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
        }
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(projectID: projectID, canonicalRoot: root, authorizedRoots: authorizedRoots)
            ])
        )
        return await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: root.path,
            reason: "Agent-defined first phase requested during onboarding",
            command: .upsertPhase(phaseID: phaseID, name: name)
        ))
    }

    public func finish(_ decision: OnboardingDecision) async throws -> ProjectID {
        let projectID = ProjectID(rawValue: Self.projectID(for: decision.preview.selectedFolder))
        guard try await projectExists(projectID) else { throw OnboardingError.projectNotPrepared }
        guard try await phaseCount(for: projectID) > 0 else { throw OnboardingError.noFirstPhase }
        let included = decision.preview.includedTaskDescriptors.filter { !decision.excludedTaskIDs.contains($0.id) }
        try await store.transact(actor: .init(id: "release-radar-onboarding"), reason: "Finish folder-backed project onboarding") { connection in
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
            var rows: [(String, Data)] = []
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT path, bookmark_data FROM project_bookmarks WHERE project_id = ? ORDER BY path LIMIT 1 OFFSET ?",
                bindings: [.text(projectID.rawValue), .integer(offset)]
            ) {
                if case let .text(path)? = row["path"], case let .blob(bookmark)? = row["bookmark_data"] {
                    rows.append((path, bookmark))
                }
                offset += 1
            }
            return rows
        }
        return Set(rows.compactMap { path, bookmark in
            (try? bookmarkStore.resolve(bookmark).url.path) ?? Self.canonical(URL(fileURLWithPath: path)).path
        })
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

    private func primaryRoot(for projectID: ProjectID) async throws -> URL {
        guard let path = try await store.read({ connection in
            try connection.scalarText("SELECT path FROM project_roots WHERE project_id = ? ORDER BY id LIMIT 1", bindings: [.text(projectID.rawValue)])
        }) else { throw OnboardingError.projectNotPrepared }
        return URL(fileURLWithPath: path)
    }

    private func roots(for projectID: ProjectID) async throws -> [URL] {
        try await store.read { connection in
            var roots: [URL] = []
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT path FROM project_roots WHERE project_id = ? ORDER BY id LIMIT 1 OFFSET ?",
                bindings: [.text(projectID.rawValue), .integer(offset)]
            ) {
                if case let .text(path)? = row["path"] { roots.append(URL(fileURLWithPath: path)) }
                offset += 1
            }
            return roots
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
