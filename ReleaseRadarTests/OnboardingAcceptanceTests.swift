import Foundation
import XCTest
@testable import ReleaseRadarCore

final class OnboardingAcceptanceTests: XCTestCase {
    func testPreviewContainsOnlySelectedRootDescendantsAndAuthorizedWorktrees() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.containedWorktree, fixture.externalWorktree]),
            codexTasks: [
                .init(id: "root", workingDirectory: fixture.root, title: "Root task"),
                .init(id: "descendant", workingDirectory: fixture.descendant, title: "Nested task"),
                .init(id: "worktree", workingDirectory: fixture.containedWorktree, title: "Worktree task"),
                .init(id: "external-worktree", workingDirectory: fixture.externalWorktree, title: "External worktree task"),
                .init(id: "sibling", workingDirectory: fixture.sibling, title: "Sibling task"),
                .init(id: "outside", workingDirectory: fixture.outside, title: "Outside task"),
            ]
        )

        let preview = try await onboarding.inspect(folder: fixture.symlinkedRoot)

        XCTAssertEqual(Set(preview.includedTaskDescriptors.map(\.id)), ["root", "descendant", "worktree"])
        XCTAssertEqual(Set(preview.rejectedTaskDescriptors.map(\.id)), ["external-worktree", "sibling", "outside"])
        XCTAssertFalse(preview.authorizedWorktreeURLs.contains(fixture.externalWorktree))

        try await onboarding.authorizeWorktree(fixture.externalWorktree, for: preview)
        let authorizedPreview = try await onboarding.inspect(folder: fixture.root)
        XCTAssertTrue(authorizedPreview.authorizedWorktreeURLs.contains(fixture.externalWorktree))
        XCTAssertEqual(Set(authorizedPreview.includedTaskDescriptors.map(\.id)), ["root", "descendant", "worktree", "external-worktree"])
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
        XCTAssertGreaterThan(fixture.bookmarks.accessStarts, 0)
    }

    func testPersistedBookmarksFailClosedWhenStaleOrUnresolvable() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree, fixture.outside])
        )
        let initial = try await onboarding.inspect(folder: fixture.root)
        try await onboarding.authorizeWorktree(fixture.externalWorktree, for: initial)
        let partiallyAuthorized = try await onboarding.inspect(folder: fixture.root)
        try await onboarding.authorizeWorktree(fixture.outside, for: partiallyAuthorized)
        let authorized = try await onboarding.inspect(folder: fixture.root)
        _ = try await onboarding.prepare(.init(preview: authorized, projectName: "Fixture Project"))

        fixture.bookmarks.markStale(fixture.externalWorktree)
        fixture.bookmarks.failResolution(for: fixture.outside)
        let unavailablePreview = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree, fixture.outside])
        ).inspect(folder: fixture.root)
        XCTAssertFalse(unavailablePreview.authorizedWorktreeURLs.contains(fixture.externalWorktree))
        XCTAssertFalse(unavailablePreview.authorizedWorktreeURLs.contains(fixture.outside))
        XCTAssertTrue(unavailablePreview.worktreesRequiringAuthorization.contains(fixture.externalWorktree))
        XCTAssertTrue(unavailablePreview.worktreesRequiringAuthorization.contains(fixture.outside))

        let staleBookmarkCount = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM project_bookmarks WHERE is_stale = 1"
            )
        }
        XCTAssertEqual(staleBookmarkCount, 2)
        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
    }

    func testPrepareRejectsRootAlreadyOwnedByAnotherProject() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let first = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root, fixture.externalWorktree])
        )
        let firstPreview = try await first.inspect(folder: fixture.root)
        try await first.authorizeWorktree(fixture.externalWorktree, for: firstPreview)
        let authorizedFirstPreview = try await first.inspect(folder: fixture.root)
        let firstID = try await first.prepare(.init(preview: authorizedFirstPreview, projectName: "First"))

        let secondPreview = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.sibling, fixture.externalWorktree])
        ).inspect(folder: fixture.sibling)
        let second = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.sibling, fixture.externalWorktree])
        )
        try await second.authorizeWorktree(fixture.externalWorktree, for: secondPreview)
        let authorizedSecondPreview = try await second.inspect(folder: fixture.sibling)
        do {
            _ = try await second.prepare(.init(preview: authorizedSecondPreview, projectName: "Second"))
            XCTFail("Expected root ownership conflict")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .rootAlreadyOwned)
        }

        let rootPath = fixture.root.path
        let persisted = try await store.read { connection in
            (
                try connection.scalarText("SELECT project_id FROM project_roots WHERE path = ?", bindings: [.text(rootPath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks"),
                try connection.scalarInt("SELECT COUNT(*) FROM projects")
            )
        }
        XCTAssertEqual(persisted.0, firstID.rawValue)
        XCTAssertEqual(persisted.1, 2)
        XCTAssertEqual(persisted.2, 1)
    }

    func testFinishWaitsForTypedAgentPhaseAndReconcilesEditableExclusions() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let decision = OnboardingDecision(
            preview: preview,
            projectName: "Fixture Project",
            excludedTaskIDs: ["excluded"]
        )

        let projectID = try await onboarding.prepare(decision)
        let hadFirstPhaseBeforeRequest = try await onboarding.hasFirstPhase(projectID: projectID)
        XCTAssertFalse(hadFirstPhaseBeforeRequest)
        do {
            _ = try await onboarding.finish(decision)
            XCTFail("Expected no first phase")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .noFirstPhase)
        }

        let beforeAgentPhase = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(beforeAgentPhase.0, 0)
        XCTAssertEqual(beforeAgentPhase.1, 0)

        try await onboarding.requestFirstPhaseDefinition(projectID: projectID)
        let request = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_phase_request'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarText("SELECT actor_id FROM audit_events ORDER BY created_at DESC LIMIT 1")
            )
        }
        XCTAssertEqual(request.0, 1)
        XCTAssertEqual(request.1, "release-radar-onboarding")

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(projectID: projectID, canonicalRoot: fixture.root, authorizedRoots: [fixture.root])
            ])
        )
        let phaseResult = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            reason: "Define first phase",
            command: .upsertPhase(phaseID: "phase-1", name: "First phase")
        ))
        XCTAssertNil(phaseResult.error)
        let hasFirstPhaseAfterAgentCommand = try await onboarding.hasFirstPhase(projectID: projectID)
        XCTAssertTrue(hasFirstPhaseAfterAgentCommand)
        let finishedProjectID = try await onboarding.finish(decision)
        XCTAssertEqual(finishedProjectID, projectID)

        let persisted = try await store.read { connection in
            (
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM thread_exclusions WHERE project_id = ? AND thread_id = 'excluded'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'unmatched_codex_task'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(persisted.0, 0)
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 1)
        XCTAssertEqual(persisted.3, 1)
        XCTAssertEqual(persisted.4, 0)

        let relaunchedOnboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        )
        let rescanned = try await relaunchedOnboarding.inspect(folder: fixture.root)
        XCTAssertEqual(rescanned.includedTaskDescriptors.map(\.id), ["included"])

        _ = try await relaunchedOnboarding.finish(.init(preview: rescanned, projectName: "Fixture Project"))
        let reIncluded = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        ).inspect(folder: fixture.root)
        XCTAssertEqual(Set(reIncluded.includedTaskDescriptors.map(\.id)), ["included", "excluded"])

        _ = try await relaunchedOnboarding.finish(decision)
        let reExcluded = try await FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root]),
            codexTasks: [
                .init(id: "included", workingDirectory: fixture.descendant, title: "Unmapped task"),
                .init(id: "excluded", workingDirectory: fixture.root, title: "Ignore this task"),
            ]
        ).inspect(folder: fixture.root)
        XCTAssertEqual(reExcluded.includedTaskDescriptors.map(\.id), ["included"])
    }
}

private final class FolderFixture {
    let directory: URL
    let databaseURL: URL
    let root: URL
    let symlinkedRoot: URL
    let descendant: URL
    let containedWorktree: URL
    let externalWorktree: URL
    let sibling: URL
    let outside: URL
    let bookmarks = TestBookmarkStore()

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        root = directory.appendingPathComponent("project", isDirectory: true)
        symlinkedRoot = directory.appendingPathComponent("project-link", isDirectory: true)
        descendant = root.appendingPathComponent("Sources/Feature", isDirectory: true)
        containedWorktree = root.appendingPathComponent(".worktrees/feature", isDirectory: true)
        externalWorktree = directory.appendingPathComponent("external-worktree", isDirectory: true)
        sibling = directory.appendingPathComponent("project-sibling", isDirectory: true)
        outside = directory.appendingPathComponent("outside", isDirectory: true)
        databaseURL = directory.appendingPathComponent("release-radar.sqlite")

        try FileManager.default.createDirectory(at: descendant, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: containedWorktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalWorktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkedRoot, withDestinationURL: root)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

private final class TestBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let lock = NSLock()
    private var stalePaths: Set<String> = []
    private var failedPaths: Set<String> = []
    private var starts = 0
    private var stops = 0

    var accessStarts: Int { lock.withLock { starts } }
    var accessStops: Int { lock.withLock { stops } }

    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        let path = String(decoding: bookmark, as: UTF8.self)
        if lock.withLock({ failedPaths.contains(path) }) {
            throw CocoaError(.fileNoSuchFile)
        }
        return .init(url: URL(fileURLWithPath: path), isStale: lock.withLock { stalePaths.contains(path) })
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        let resolved = try resolve(bookmark)
        lock.withLock { starts += 1 }
        defer { lock.withLock { stops += 1 } }
        return try await body(resolved)
    }

    func markStale(_ url: URL) {
        _ = lock.withLock { stalePaths.insert(url.path) }
    }

    func failResolution(for url: URL) {
        _ = lock.withLock { failedPaths.insert(url.path) }
    }
}

private struct FixtureWorktreeDiscovery: GitWorktreeDiscovering {
    let worktrees: [URL]

    func discoverWorktrees(at folder: URL) throws -> [URL] { worktrees }
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: @escaping @Sendable () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected an error", file: file, line: line)
        } catch {}
    }
}
