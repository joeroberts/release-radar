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
    public let recognizedArtifactPreview: ImportPreview?
    public let documentationState: ProjectDocumentationState
    public var projectGuidanceState: ProjectGuidanceState { documentationState.guidanceState }
    public let pendingProjectID: ProjectID?
    public let completedProjectID: ProjectID?

    public init(
        selectedFolder: URL,
        gitRoot: URL?,
        includedTaskDescriptors: [CodexTaskDescriptor],
        rejectedTaskDescriptors: [CodexTaskDescriptor],
        authorizedWorktreeURLs: [URL],
        worktreesRequiringAuthorization: [URL],
        recognizedArtifactPreview: ImportPreview? = nil,
        projectGuidanceState: ProjectGuidanceState = .missing,
        documentationState: ProjectDocumentationState? = nil,
        pendingProjectID: ProjectID? = nil,
        completedProjectID: ProjectID? = nil
    ) {
        self.selectedFolder = selectedFolder
        self.gitRoot = gitRoot
        self.includedTaskDescriptors = includedTaskDescriptors
        self.rejectedTaskDescriptors = rejectedTaskDescriptors
        self.authorizedWorktreeURLs = authorizedWorktreeURLs
        self.worktreesRequiringAuthorization = worktreesRequiringAuthorization
        self.recognizedArtifactPreview = recognizedArtifactPreview
        self.documentationState = documentationState ?? .legacy(projectGuidanceState)
        self.pendingProjectID = pendingProjectID
        self.completedProjectID = completedProjectID
    }
}

public struct OnboardingDecision: Equatable, Sendable {
    public let preview: OnboardingPreview
    public let projectName: String
    public let excludedTaskIDs: Set<String>
    public let importRecognizedArtifacts: Bool

    public init(
        preview: OnboardingPreview,
        projectName: String,
        excludedTaskIDs: Set<String> = [],
        importRecognizedArtifacts: Bool = false
    ) {
        self.preview = preview
        self.projectName = projectName
        self.excludedTaskIDs = excludedTaskIDs
        self.importRecognizedArtifacts = importRecognizedArtifacts
    }
}

public enum OnboardingReviewMarkerKind: String, CaseIterable, Sendable {
    case pending = "onboarding_pending"
    case phaseRequest = "onboarding_phase_request"

    public func reviewItemID(for projectID: ProjectID) -> String {
        "\(projectID.rawValue)\(reviewItemIDSuffix)"
    }

    public static func isReserved(kind: String) -> Bool {
        allCases.contains { $0.rawValue == kind }
    }

    public static func isReserved(id: String) -> Bool {
        allCases.contains { kind in
            id.count > kind.reviewItemIDSuffix.count && id.hasSuffix(kind.reviewItemIDSuffix)
        }
    }

    fileprivate var summary: String {
        switch self {
        case .pending: "Project onboarding is awaiting owner completion"
        case .phaseRequest: "Agent requested to define the first phase"
        }
    }

    private var reviewItemIDSuffix: String {
        switch self {
        case .pending: "-onboarding-pending"
        case .phaseRequest: "-first-phase-request"
        }
    }
}

public enum OnboardingError: Error, LocalizedError, Equatable, Sendable {
    case invalidFolder
    case invalidProjectName
    case noFirstPhase
    case projectNotPrepared
    case rootAlreadyOwned
    case reviewMarkerConflict

    public var errorDescription: String? {
        switch self {
        case .invalidFolder: "The selected folder is unavailable."
        case .invalidProjectName: "A project name is required."
        case .noFirstPhase: "Ask an agent to define the first phase before finishing onboarding."
        case .projectNotPrepared: "Prepare the project before requesting its first phase."
        case .rootAlreadyOwned: "A selected root or worktree already belongs to another project."
        case .reviewMarkerConflict: "A reserved onboarding review marker conflicts with persisted project state."
        }
    }
}

public enum OnboardingPreparationError: Error, LocalizedError, Equatable, Sendable {
    case seedApplicationFailedAfterSave(ProjectID)

    public var errorDescription: String? {
        switch self {
        case .seedApplicationFailedAfterSave:
            "Project tracking was initialized, but the recognized seed could not be applied. Resume setup and try again."
        }
    }
}

public enum ProjectAuthorizationError: Error, LocalizedError, Equatable, Sendable {
    case projectNotFound
    case projectRootMissing
    case projectRootAlreadyAssociated
    case bookmarkMissing
    case bookmarkStale
    case bookmarkResolutionFailed
    case securityScopeAccessDenied
    case bookmarkRootMismatch
    case projectRootMismatch
    case rootAlreadyOwned
    case invalidFolder

    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            "The project no longer exists. Refresh Release Radar before retrying."
        case .projectRootMissing:
            "This project has no associated folder. Associate its project folder before retrying."
        case .projectRootAlreadyAssociated:
            "This project already has an associated folder. Reauthorize that same folder instead."
        case .bookmarkMissing:
            "Folder authorization is missing. Select the project folder again before retrying."
        case .bookmarkStale:
            "Folder authorization has expired. Select the project folder again before retrying."
        case .bookmarkResolutionFailed:
            "Folder authorization could not be restored. Select the project folder again before retrying."
        case .securityScopeAccessDenied:
            "macOS denied access to the project folder. Select it again before retrying."
        case .bookmarkRootMismatch:
            "Saved folder authorization does not match this project. Select the project folder again."
        case .projectRootMismatch:
            "The selected folder is not this project's saved folder. Choose the original project folder."
        case .rootAlreadyOwned:
            "The selected folder already belongs to another project."
        case .invalidFolder:
            "The selected folder is unavailable."
        }
    }
}

private struct PersistedProjectAuthorization: Sendable {
    let projectExists: Bool
    let rootPath: String?
    let bookmarkData: Data?
    let bookmarkIsStale: Bool
    let bookmarkCount: Int64
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
            let projectIdentity = try await projectIdentity(forRoot: authorizedSelected)
            let projectID = try await projectID(forRoot: authorizedSelected) ?? ProjectID(rawValue: Self.projectID(for: authorizedSelected))
            let authorizedProject = AuthorizedProject(
                projectID: projectID,
                canonicalRoot: authorizedSelected,
                authorizedRoots: roots
            )
            let recognizedArtifactPreview = try? RekonArtifactImporter(
                store: store,
                project: authorizedProject
            ).preview(authorizedSelected)
            let hasAuditedHandoff = try await hasAuditedGuidanceHandoff(
                projectID: projectID,
                rootURL: authorizedSelected
            )
            let documentationState = await documentationState(projectID: projectID, rootURL: authorizedSelected, hasAuditedHandoff: hasAuditedHandoff)
            return .init(
                selectedFolder: authorizedSelected,
                gitRoot: GitWorktreeDiscovery.discoverGitRoot(at: authorizedSelected) ?? worktrees.first,
                includedTaskDescriptors: included,
                rejectedTaskDescriptors: rejected,
                authorizedWorktreeURLs: authorized,
                worktreesRequiringAuthorization: outsideWorktrees,
                recognizedArtifactPreview: recognizedArtifactPreview,
                documentationState: documentationState,
                pendingProjectID: projectIdentity.pending,
                completedProjectID: projectIdentity.completed
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

    public func withAuthorizedProject<T: Sendable>(
        projectID: ProjectID,
        _ body: @Sendable (AuthorizedProject) async throws -> T
    ) async throws -> T {
        let authorization = try await persistedProjectAuthorization(for: projectID)
        guard authorization.projectExists else { throw ProjectAuthorizationError.projectNotFound }
        guard let rootPath = authorization.rootPath else {
            throw authorization.bookmarkCount == 0
                ? ProjectAuthorizationError.projectRootMissing
                : ProjectAuthorizationError.bookmarkMissing
        }
        guard let bookmark = authorization.bookmarkData else {
            throw ProjectAuthorizationError.bookmarkMissing
        }
        guard !authorization.bookmarkIsStale else {
            throw ProjectAuthorizationError.bookmarkStale
        }

        let persistedRoot = Self.canonical(URL(fileURLWithPath: rootPath))
        let resolved: ResolvedProjectBookmark
        do {
            resolved = try bookmarkStore.resolve(bookmark)
        } catch {
            try await markReviewBookmarkStale(projectID: projectID, path: rootPath)
            throw ProjectAuthorizationError.bookmarkResolutionFailed
        }
        guard !resolved.isStale else {
            try await markReviewBookmarkStale(projectID: projectID, path: rootPath)
            throw ProjectAuthorizationError.bookmarkStale
        }
        guard Self.canonical(resolved.url) == persistedRoot else {
            try await markReviewBookmarkStale(projectID: projectID, path: rootPath)
            throw ProjectAuthorizationError.bookmarkRootMismatch
        }

        do {
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { activeBookmark in
                guard !activeBookmark.isStale else {
                    throw ProjectAuthorizationError.bookmarkStale
                }
                let activeRoot = Self.canonical(activeBookmark.url)
                guard activeRoot == persistedRoot else {
                    throw ProjectAuthorizationError.bookmarkRootMismatch
                }
                return try await body(AuthorizedProject(
                    projectID: projectID,
                    canonicalRoot: activeRoot,
                    authorizedRoots: [activeRoot]
                ))
            }
        } catch let error as ProjectAuthorizationError {
            if error == .bookmarkStale || error == .bookmarkRootMismatch {
                try await markReviewBookmarkStale(projectID: projectID, path: rootPath)
            }
            throw error
        } catch let error as ProjectBookmarkError {
            try await markReviewBookmarkStale(projectID: projectID, path: rootPath)
            switch error {
            case .securityScopeAccessDenied:
                throw ProjectAuthorizationError.securityScopeAccessDenied
            case .bookmarkCreationFailed, .bookmarkResolutionFailed:
                throw ProjectAuthorizationError.bookmarkResolutionFailed
            }
        }
    }

    public func observeProjectGuidance(projectID: ProjectID) async -> ProjectGuidanceState {
        await observeProjectGuidanceContext(projectID: projectID).state
    }

    public func observeProjectGuidanceContext(projectID: ProjectID) async -> ProjectGuidanceObservation {
        do {
            return try await withAuthorizedProject(projectID: projectID) { [self] project in
                let hasAuditedHandoff = try await hasAuditedGuidanceHandoff(
                    projectID: project.projectID,
                    rootURL: project.canonicalRoot
                )
                return ProjectGuidanceObservation(
                    projectRoot: project.canonicalRoot,
                    documentationState: await documentationState(projectID: project.projectID, rootURL: project.canonicalRoot, hasAuditedHandoff: hasAuditedHandoff)
                )
            }
        } catch {
            return ProjectGuidanceObservation(projectRoot: nil, state: .unavailable)
        }
    }

    private func documentationState(projectID: ProjectID, rootURL: URL, hasAuditedHandoff: Bool) async -> ProjectDocumentationState {
        do {
            let context = try await store.documentationRead { c in
                try DocumentationRootContext.read(c, path: rootURL.path, projectID: projectID.rawValue, schemaVersion: store.schemaVersionForDocumentation)
            }
            return ProjectGuidanceInspection.inspectDocumentation(rootURL: rootURL, hasAuditedHandoff: hasAuditedHandoff, context: context)
        } catch {
            let observation = ProjectGuidanceInspection.inspectDocumentation(rootURL: rootURL, hasAuditedHandoff: hasAuditedHandoff)
            // A new folder has no persisted root yet. Catalog validation still runs,
            // while a malformed saved binding must retain its precise recovery reason.
            if case .managedUnavailable(_, .bindingMissing, _) = observation,
               DocumentationCatalogContext.map(error) != .rootUnavailable {
                return .managedUnavailable(hasAuditedHandoff: hasAuditedHandoff, reason: DocumentationCatalogContext.map(error), validationError: nil)
            }
            return observation
        }
    }

    private func hasAuditedGuidanceHandoff(
        projectID: ProjectID,
        rootURL: URL
    ) async throws -> Bool {
        let agentsPath = Self.canonical(rootURL)
            .appendingPathComponent(RepositoryDocumentContract.guidancePath, isDirectory: false)
            .path
        return try await store.documentationRead { connection in
            try connection.scalarInt(
                """
                SELECT COUNT(*)
                FROM evidence
                WHERE project_id = ?
                  AND ticket_id IS NULL
                  AND path = ?
                  AND is_available = 1
                  AND id LIKE ?
                """,
                bindings: [
                    .text(projectID.rawValue),
                    .text(agentsPath),
                    .text(ProjectGuidanceInspection.handoffEvidenceIDPrefix + "%"),
                ]
            ) == 1
        }
    }

    public func reauthorizeProjectRoot(_ folder: URL, for projectID: ProjectID) async throws {
        let authorization = try await persistedProjectAuthorization(for: projectID)
        guard authorization.projectExists else { throw ProjectAuthorizationError.projectNotFound }
        guard let rootPath = authorization.rootPath else { throw ProjectAuthorizationError.projectRootMissing }
        let persistedRoot = Self.canonical(URL(fileURLWithPath: rootPath))
        let candidate = Self.canonical(folder)
        guard candidate == persistedRoot else { throw ProjectAuthorizationError.projectRootMismatch }
        let bookmark = try await validatedBookmark(for: candidate)

        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Reauthorize project folder access",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            guard try connection.scalarText(
                "SELECT path FROM project_roots WHERE project_id = ? AND (NOT EXISTS (SELECT 1 FROM project_documentation_bindings WHERE project_id = project_roots.project_id) OR id = (SELECT root_id FROM project_documentation_bindings WHERE project_id = project_roots.project_id)) ORDER BY rowid LIMIT 1",
                bindings: [.text(projectID.rawValue)]
            ) == rootPath else {
                throw ProjectAuthorizationError.projectRootMismatch
            }
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0) ON CONFLICT(project_id, path) DO UPDATE SET bookmark_data = excluded.bookmark_data, is_stale = 0",
                bindings: [.text(projectID.rawValue), .text(rootPath), .blob(bookmark)]
            )
        }
    }

    public func associateFirstProjectRoot(_ folder: URL, for projectID: ProjectID) async throws {
        let candidate = Self.canonical(folder)
        guard Self.isDirectory(candidate) else { throw ProjectAuthorizationError.invalidFolder }
        let state = try await projectRootAssociationState(projectID: projectID, candidatePath: candidate.path)
        guard state.projectExists else { throw ProjectAuthorizationError.projectNotFound }
        guard state.rootCount == 0, state.bookmarkCount == 0 else {
            throw ProjectAuthorizationError.projectRootAlreadyAssociated
        }
        guard !state.isOwned else { throw ProjectAuthorizationError.rootAlreadyOwned }
        let bookmark = try await validatedBookmark(for: candidate)

        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Associate first project folder authorization",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            let rootCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM project_roots WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            ) ?? 0
            let bookmarkCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            ) ?? 0
            guard rootCount == 0, bookmarkCount == 0 else {
                throw ProjectAuthorizationError.projectRootAlreadyAssociated
            }
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM project_roots WHERE path = ?",
                bindings: [.text(candidate.path)]
            ) == 0 else {
                throw ProjectAuthorizationError.rootAlreadyOwned
            }
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                bindings: [.text("\(projectID.rawValue)-root-0"), .text(projectID.rawValue), .text(candidate.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
                bindings: [.text(projectID.rawValue), .text(candidate.path), .blob(bookmark)]
            )
        }
    }

    public func eligibleProjectsForFirstRootAssociation() async throws -> [ProjectRecord] {
        try await store.read { connection in
            var projects: [ProjectRecord] = []
            var offset: Int64 = 0
            while let row = try connection.row(
                """
                SELECT projects.id, projects.name, projects.first_dashboard_opened
                FROM projects
                WHERE NOT EXISTS (
                    SELECT 1 FROM project_roots
                    WHERE project_roots.project_id = projects.id
                )
                  AND NOT EXISTS (
                    SELECT 1 FROM project_bookmarks
                    WHERE project_bookmarks.project_id = projects.id
                )
                  AND NOT EXISTS (
                    SELECT 1 FROM review_items
                    WHERE review_items.project_id = projects.id
                      AND review_items.kind IN (?, ?)
                      AND review_items.status = 'open'
                )
                ORDER BY projects.name COLLATE NOCASE, projects.id
                LIMIT 1 OFFSET ?
                """,
                bindings: [
                    .text(OnboardingReviewMarkerKind.pending.rawValue),
                    .text(OnboardingReviewMarkerKind.phaseRequest.rawValue),
                    .integer(offset),
                ]
            ) {
                guard
                    case let .text(id)? = row["id"],
                    case let .text(name)? = row["name"],
                    case let .integer(firstDashboardOpened)? = row["first_dashboard_opened"]
                else { throw SQLiteError(code: 20, message: "Invalid eligible project row") }
                projects.append(ProjectRecord(
                    id: ProjectID(rawValue: id),
                    name: name,
                    firstDashboardOpened: firstDashboardOpened != 0
                ))
                offset += 1
            }
            return projects
        }
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
            try Self.ensureOnboardingReviewMarker(
                kind: .pending,
                projectID: projectID,
                connection: connection
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
        if decision.importRecognizedArtifacts,
           let importPreview = decision.preview.recognizedArtifactPreview {
            let authorizedProject = AuthorizedProject(
                projectID: projectID,
                canonicalRoot: decision.preview.selectedFolder,
                authorizedRoots: roots
            )
            do {
                try await RekonArtifactImporter(store: store, project: authorizedProject)
                    .apply(importPreview, to: projectID)
            } catch {
                throw OnboardingPreparationError.seedApplicationFailedAfterSave(projectID)
            }
        }
        return projectID
    }

    public func requestFirstPhaseDefinition(projectID: ProjectID) async throws {
        guard try await projectExists(projectID) else { throw OnboardingError.projectNotPrepared }
        try await store.transact(actor: .init(id: "release-radar-onboarding"), reason: "Request agent-defined first phase") { connection in
            try Self.ensureOnboardingReviewMarker(
                kind: .phaseRequest,
                projectID: projectID,
                connection: connection
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
                "DELETE FROM review_items WHERE project_id = ? AND (kind IN (?, ?) OR id IN (?, ?))",
                bindings: [
                    .text(projectID.rawValue),
                    .text(OnboardingReviewMarkerKind.pending.rawValue),
                    .text(OnboardingReviewMarkerKind.phaseRequest.rawValue),
                    .text(OnboardingReviewMarkerKind.pending.reviewItemID(for: projectID)),
                    .text(OnboardingReviewMarkerKind.phaseRequest.reviewItemID(for: projectID)),
                ]
            )
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

    private func persistedProjectAuthorization(
        for projectID: ProjectID
    ) async throws -> PersistedProjectAuthorization {
        try await store.read { connection in
            let projectExists = try connection.scalarInt(
                "SELECT COUNT(*) FROM projects WHERE id = ?",
                bindings: [.text(projectID.rawValue)]
            ) == 1
            let rootPath = try connection.scalarText(
                "SELECT path FROM project_roots WHERE project_id = ? AND (NOT EXISTS (SELECT 1 FROM project_documentation_bindings WHERE project_id = project_roots.project_id) OR id = (SELECT root_id FROM project_documentation_bindings WHERE project_id = project_roots.project_id)) ORDER BY rowid LIMIT 1",
                bindings: [.text(projectID.rawValue)]
            )
            let bookmarkCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            ) ?? 0
            guard let rootPath,
                  let bookmarkRow = try connection.row(
                      "SELECT bookmark_data, is_stale FROM project_bookmarks WHERE project_id = ? AND path = ?",
                      bindings: [.text(projectID.rawValue), .text(rootPath)]
                  ) else {
                return .init(
                    projectExists: projectExists,
                    rootPath: rootPath,
                    bookmarkData: nil,
                    bookmarkIsStale: false,
                    bookmarkCount: bookmarkCount
                )
            }
            let bookmarkData: Data?
            if case let .blob(data)? = bookmarkRow["bookmark_data"] { bookmarkData = data }
            else { bookmarkData = nil }
            let bookmarkIsStale: Bool
            if case let .integer(value)? = bookmarkRow["is_stale"] { bookmarkIsStale = value != 0 }
            else { bookmarkIsStale = true }
            return .init(
                projectExists: projectExists,
                rootPath: rootPath,
                bookmarkData: bookmarkData,
                bookmarkIsStale: bookmarkIsStale,
                bookmarkCount: bookmarkCount
            )
        }
    }

    private func projectRootAssociationState(
        projectID: ProjectID,
        candidatePath: String
    ) async throws -> (projectExists: Bool, rootCount: Int64, bookmarkCount: Int64, isOwned: Bool) {
        try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM projects WHERE id = ?",
                    bindings: [.text(projectID.rawValue)]
                ) == 1,
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM project_roots WHERE project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ) ?? 0,
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ) ?? 0,
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM project_roots WHERE path = ?",
                    bindings: [.text(candidatePath)]
                ) != 0
            )
        }
    }

    private func validatedBookmark(for folder: URL) async throws -> Data {
        guard Self.isDirectory(folder) else { throw ProjectAuthorizationError.invalidFolder }
        let bookmark: Data
        do {
            bookmark = try bookmarkStore.makeBookmark(for: folder)
        } catch {
            throw ProjectAuthorizationError.bookmarkResolutionFailed
        }
        let resolved: ResolvedProjectBookmark
        do {
            resolved = try bookmarkStore.resolve(bookmark)
        } catch {
            throw ProjectAuthorizationError.bookmarkResolutionFailed
        }
        guard !resolved.isStale else { throw ProjectAuthorizationError.bookmarkStale }
        guard Self.canonical(resolved.url) == folder else {
            throw ProjectAuthorizationError.bookmarkRootMismatch
        }
        do {
            try await bookmarkStore.withSecurityScopedAccess(bookmark: bookmark) { activeBookmark in
                guard !activeBookmark.isStale else { throw ProjectAuthorizationError.bookmarkStale }
                guard Self.canonical(activeBookmark.url) == folder else {
                    throw ProjectAuthorizationError.bookmarkRootMismatch
                }
            }
        } catch let error as ProjectAuthorizationError {
            throw error
        } catch let error as ProjectBookmarkError {
            switch error {
            case .securityScopeAccessDenied:
                throw ProjectAuthorizationError.securityScopeAccessDenied
            case .bookmarkCreationFailed, .bookmarkResolutionFailed:
                throw ProjectAuthorizationError.bookmarkResolutionFailed
            }
        }
        return bookmark
    }

    private func markReviewBookmarkStale(projectID: ProjectID, path: String) async throws {
        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Mark project folder authorization stale",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            try connection.execute(
                "UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = ? AND path = ?",
                bindings: [.text(projectID.rawValue), .text(path)]
            )
        }
    }

    private static func ensureOnboardingReviewMarker(
        kind: OnboardingReviewMarkerKind,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        let id = kind.reviewItemID(for: projectID)
        let existingCount = try connection.scalarInt(
            "SELECT COUNT(*) FROM review_items WHERE id = ?",
            bindings: [.text(id)]
        ) ?? 0
        if existingCount == 0 {
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, NULL, ?, ?, 'open')",
                bindings: [.text(id), .text(projectID.rawValue), .text(kind.rawValue), .text(kind.summary)]
            )
            return
        }

        let exactMatchCount = try connection.scalarInt(
            "SELECT COUNT(*) FROM review_items WHERE id = ? AND project_id = ? AND ticket_id IS NULL AND kind = ? AND summary = ?",
            bindings: [.text(id), .text(projectID.rawValue), .text(kind.rawValue), .text(kind.summary)]
        ) ?? 0
        guard exactMatchCount == 1 else { throw OnboardingError.reviewMarkerConflict }
        try connection.execute(
            "UPDATE review_items SET status = 'open' WHERE id = ?",
            bindings: [.text(id)]
        )
    }

    private func projectID(forRoot root: URL) async throws -> ProjectID? {
        try await store.read { connection in
            guard let id = try connection.scalarText("SELECT project_id FROM project_roots WHERE path = ?", bindings: [.text(root.path)]) else { return nil }
            return .init(rawValue: id)
        }
    }

    private func projectIdentity(forRoot root: URL) async throws -> (pending: ProjectID?, completed: ProjectID?) {
        try await store.read { connection in
            let ownerCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM project_roots WHERE path = ?",
                bindings: [.text(root.path)]
            ) ?? 0
            guard ownerCount == 1,
                  let ownerID = try connection.scalarText(
                      "SELECT project_id FROM project_roots WHERE path = ?",
                      bindings: [.text(root.path)]
                  ) else {
                return (nil, nil)
            }
            let projectID = ProjectID(rawValue: ownerID)
            let pendingMarkerCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = ? AND status = 'open'",
                bindings: [.text(ownerID), .text(OnboardingReviewMarkerKind.pending.rawValue)]
            ) ?? 0
            if pendingMarkerCount == 1 {
                return (projectID, nil)
            }
            let openOnboardingMarkerCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind IN (?, ?) AND status = 'open'",
                bindings: [
                    .text(ownerID),
                    .text(OnboardingReviewMarkerKind.pending.rawValue),
                    .text(OnboardingReviewMarkerKind.phaseRequest.rawValue),
                ]
            ) ?? 0
            let phaseCount = try connection.scalarInt(
                "SELECT COUNT(*) FROM phases WHERE project_id = ?",
                bindings: [.text(ownerID)]
            ) ?? 0
            guard openOnboardingMarkerCount == 0, phaseCount > 0 else {
                return (nil, nil)
            }
            return (nil, projectID)
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

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func contains(_ candidate: URL, within root: URL) -> Bool {
        let candidateComponents = candidate.pathComponents
        let rootComponents = root.pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}
