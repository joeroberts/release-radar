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
    }

    func testFinishRequiresAgentDefinedPhaseThenPersistsExclusionsReviewAndNotificationIneligibility() async throws {
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

        await XCTAssertThrowsErrorAsync {
            _ = try await onboarding.finish(decision)
        }

        let projectID = try await onboarding.prepare(decision)
        let phaseResult = await onboarding.askAgentToDefineFirstPhase(
            projectID: projectID,
            phaseID: "phase-1",
            name: "First phase"
        )
        XCTAssertNil(phaseResult.error)
        XCTAssertNotNil(phaseResult.auditEventID)
        let finishedProjectID = try await onboarding.finish(decision)
        XCTAssertEqual(finishedProjectID, projectID)

        let persisted = try await store.read { connection in
            (
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM thread_exclusions WHERE project_id = ? AND thread_id = 'excluded'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'unmatched_codex_task'", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
            )
        }
        XCTAssertEqual(persisted.0, 0)
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 1)
        XCTAssertEqual(persisted.3, 1)

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

private struct TestBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
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
