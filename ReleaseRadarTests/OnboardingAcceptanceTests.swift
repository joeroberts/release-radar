import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class OnboardingAcceptanceTests: XCTestCase {
    func testRecognizedArtifactPreviewRequiresExplicitImportDecision() async throws {
        let fixture = try FolderFixture()
        try fixture.installRecognizedArtifact()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )

        let preview = try await onboarding.inspect(folder: fixture.root)
        let importPreview = try XCTUnwrap(preview.recognizedArtifactPreview)
        XCTAssertEqual(importPreview.phases.map(\.id.rawValue), ["phase-imported"])
        XCTAssertEqual(importPreview.tickets.map(\.id.rawValue), ["TASK-IMPORTED"])
        XCTAssertEqual(importPreview.reviewItems.map(\.sourceID), ["TASK-UNCERTAIN"])

        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))
        let beforeOptIn = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
        }
        XCTAssertEqual(beforeOptIn, 0)

        _ = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project",
            importRecognizedArtifacts: true
        ))
        let imported = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'missing_outcome' AND status = 'open'", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(imported.0, 1)
        XCTAssertEqual(imported.1, 1)
        XCTAssertEqual(imported.2, 1)
    }

    func testRunningDispatcherAuthorizesRootCommittedByOnboardingPrepare() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Fixture Project"
        ))

        let result = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.appendingPathComponent("..").appendingPathComponent("project").path,
            reason: "Define the first phase without restarting the bridge",
            command: .upsertPhase(phaseID: "phase-agent", name: "Agent phase")
        ))

        XCTAssertNil(result.error)
        let hasFirstPhase = try await onboarding.hasFirstPhase(projectID: projectID)
        XCTAssertTrue(hasFirstPhase)
    }

    func testPreparedProjectRemainsPendingUntilFirstPhaseAndFinish() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let decision = OnboardingDecision(preview: preview, projectName: "Fixture Project")
        let projectID = try await onboarding.prepare(decision)

        let pendingMarkerCount = try await store.read { connection in
            try connection.scalarInt(
                "SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'",
                bindings: [.text(projectID.rawValue)]
            )
        }
        XCTAssertEqual(pendingMarkerCount, 1)
        let preparedDashboard = try await DashboardProjection.load(from: store)
        XCTAssertTrue(preparedDashboard.projects.isEmpty)
        let relaunchedOnboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let resumedPreview = try await relaunchedOnboarding.inspect(folder: fixture.root)
        XCTAssertEqual(resumedPreview.pendingProjectID, projectID)
        try await onboarding.requestFirstPhaseDefinition(projectID: projectID)

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let result = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            reason: "Define first phase",
            command: .upsertPhase(phaseID: "phase-first", name: "First phase")
        ))
        XCTAssertNil(result.error)
        let phaseReadyDashboard = try await DashboardProjection.load(from: store)
        XCTAssertTrue(phaseReadyDashboard.projects.isEmpty)

        _ = try await onboarding.finish(decision)

        let completed = try await DashboardProjection.load(from: store)
        XCTAssertEqual(completed.projects.map(\.id), [projectID])
        let inbox = try await ReviewInboxProjection.load(from: store, projectID: projectID)
        XCTAssertTrue(inbox.openItems.isEmpty)
        let finalState = try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind IN ('onboarding_pending', 'onboarding_phase_request') AND status = 'open'",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(finalState.0, 0)
        XCTAssertEqual(finalState.1, 0)
    }

    func testDeniedSecurityScopeDoesNotRunDiscoveryOrAuthorizeFolder() async throws {
        let fixture = try FolderFixture()
        let scopeAccess = DeniedScopeAccessRecorder()
        let discovery = CountingWorktreeDiscovery()
        let root = fixture.root
        let bookmarkStore = ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { scopeAccess.start($0) },
            stopAccessing: { scopeAccess.stop($0) }
        )
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: bookmarkStore,
            worktreeDiscovery: discovery
        )

        do {
            _ = try await onboarding.inspect(folder: fixture.root)
            XCTFail("Expected denied security-scoped access")
        } catch let error as ProjectBookmarkError {
            XCTAssertEqual(error, .securityScopeAccessDenied)
        }

        XCTAssertEqual(scopeAccess.startCount, 1)
        XCTAssertEqual(scopeAccess.stopCount, 0)
        XCTAssertEqual(discovery.callCount, 0)
        let persistedAuthorizationCount = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM project_roots")
        }
        XCTAssertEqual(persistedAuthorizationCount, 0)
    }

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

    func testPrepareRejectsWrongKindMarkerCollisionWithoutRepairOrPartialUpdate() async throws {
        let fixture = try FolderFixture()
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let onboarding = FolderProjectOnboarding(
            store: store,
            bookmarkStore: fixture.bookmarks,
            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
        )
        let preview = try await onboarding.inspect(folder: fixture.root)
        let projectID = try await onboarding.prepare(.init(
            preview: preview,
            projectName: "Original Project"
        ))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed wrong-kind marker collision") { connection in
            try connection.execute(
                "UPDATE review_items SET kind = 'agent_request' WHERE id = ?",
                bindings: [.text("\(projectID.rawValue)-onboarding-pending")]
            )
        }

        do {
            _ = try await onboarding.prepare(.init(
                preview: preview,
                projectName: "Renamed Project"
            ))
            XCTFail("Expected the marker collision to fail onboarding prepare")
        } catch let error as OnboardingError {
            XCTAssertEqual(error, .reviewMarkerConflict)
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT name FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarText("SELECT project_id || '|' || kind || '|' || summary || '|' || status FROM review_items WHERE id = ?", bindings: [.text("\(projectID.rawValue)-onboarding-pending")])
            )
        }
        XCTAssertEqual(state.0, "Original Project")
        XCTAssertEqual(
            state.1,
            "\(projectID.rawValue)|agent_request|Project onboarding is awaiting owner completion|open"
        )
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
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind <> 'onboarding_pending'", bindings: [.text(projectID.rawValue)])
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

    func installRecognizedArtifact() throws {
        let delivery = root.appendingPathComponent("docs/delivery", isDirectory: true)
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let artifact = """
        {
          "schemaVersion": 1,
          "activePhaseId": "phase-imported",
          "phases": [
            { "id": "phase-imported", "label": "Imported phase", "dependsOnPhaseIds": [] }
          ],
          "tasks": [
            {
              "id": "TASK-IMPORTED",
              "title": "Imported outcome",
              "status": "backlog",
              "phaseId": "phase-imported",
              "dependsOnTaskIds": []
            },
            {
              "id": "TASK-UNCERTAIN",
              "title": "   ",
              "status": "backlog",
              "phaseId": "phase-imported",
              "dependsOnTaskIds": []
            }
          ]
        }
        """
        try Data(artifact.utf8).write(to: delivery.appendingPathComponent("dashboard-status.json"))
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

private final class DeniedScopeAccessRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0

    var startCount: Int { lock.withLock { starts } }
    var stopCount: Int { lock.withLock { stops } }

    func start(_ url: URL) -> Bool {
        lock.withLock { starts += 1 }
        return false
    }

    func stop(_ url: URL) {
        lock.withLock { stops += 1 }
    }
}

private final class CountingWorktreeDiscovery: @unchecked Sendable, GitWorktreeDiscovering {
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int { lock.withLock { calls } }

    func discoverWorktrees(at folder: URL) throws -> [URL] {
        lock.withLock { calls += 1 }
        return []
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
