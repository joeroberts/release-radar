import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectGuidanceAcceptanceTests: XCTestCase {
    func testInspectionDistinguishesMissingCurrentOutdatedAndMalformedGuidance() {
        XCTAssertEqual(ProjectGuidanceInspection.inspect(contents: nil), .missing)
        XCTAssertEqual(ProjectGuidanceInspection.inspect(contents: "# Existing instructions\n"), .missing)
        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(contents: ProjectGuidanceInspection.managedBlock),
            .current(version: 2)
        )
        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(contents: Self.guidance(version: 0)),
            .outdated(installed: 0, current: 2)
        )
        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(contents: "<!-- release-radar-guidance:v1:start -->\nmissing end"),
            .needsRepair
        )
        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(contents: Self.guidance(version: 1)),
            .needsRepair
        )
        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(
                contents: ProjectGuidanceInspection.managedBlock
                    + "\n <!-- release-radar-guidance:v1:start -->"
            ),
            .needsRepair
        )
    }

    func testUnavailableProjectAuthorizationReportsUnavailable() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GuidanceUnavailable-\(UUID().uuidString)", isDirectory: true)
        let onboarding = FolderProjectOnboarding(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            bookmarkStore: GuidanceBookmarkStore()
        )

        let state = await onboarding.observeProjectGuidance(
            projectID: ProjectID(rawValue: "missing-project")
        )

        XCTAssertEqual(state, .unavailable)
    }

    func testOnboardingPreviewReadsGuidanceWithoutChangingRepositoryBytes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GuidancePreview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let agentsURL = directory.appendingPathComponent("AGENTS.md")
        let original = Data(("# Owner instructions\n\n" + Self.guidance(version: 0)).utf8)
        try original.write(to: agentsURL)
        let bookmarks = GuidanceBookmarkStore()
        let onboarding = FolderProjectOnboarding(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            bookmarkStore: bookmarks
        )

        let preview = try await onboarding.inspect(folder: directory)

        XCTAssertEqual(preview.projectGuidanceState, .outdated(installed: 0, current: 2))
        XCTAssertEqual(try Data(contentsOf: agentsURL), original)
        XCTAssertEqual(bookmarks.accessStarts, 1)
        XCTAssertEqual(bookmarks.accessStops, 1)
    }

    func testInspectionRefusesSymlinkRootAgentsWithoutFollowingTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GuidanceSymlink-\(UUID().uuidString)", isDirectory: true)
        let project = directory.appendingPathComponent("project", isDirectory: true)
        let outside = directory.appendingPathComponent("outside-AGENTS.md")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let original = Data(ProjectGuidanceInspection.managedBlock.utf8)
        try original.write(to: outside)
        try FileManager.default.createSymbolicLink(
            at: project.appendingPathComponent("AGENTS.md"),
            withDestinationURL: outside
        )

        XCTAssertEqual(ProjectGuidanceInspection.inspect(rootURL: project), .unavailable)
        XCTAssertEqual(try Data(contentsOf: outside), original)
    }

    func testRepositoryInspectionRequiresAuditedHandoffEvidenceForCurrentGuidance() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GuidanceAudit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        try Data(ProjectGuidanceInspection.managedBlock.utf8)
            .write(to: directory.appendingPathComponent("AGENTS.md"))

        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(rootURL: directory, hasAuditedHandoff: false),
            .handoffIncomplete(version: 2)
        )
        XCTAssertEqual(
            ProjectGuidanceInspection.inspect(rootURL: directory, hasAuditedHandoff: true),
            .current(version: 2)
        )
    }

    private static func guidance(version: Int) -> String {
        """
        <!-- release-radar-guidance:v\(version):start -->
        ## Release Radar tracking

        This repository is tracked by Release Radar.
        <!-- release-radar-guidance:end -->
        """
    }
}

private final class GuidanceBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0

    var accessStarts: Int { lock.withLock { starts } }
    var accessStops: Int { lock.withLock { stops } }

    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.resolvingSymlinksInPath().path.utf8)
    }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
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
}
