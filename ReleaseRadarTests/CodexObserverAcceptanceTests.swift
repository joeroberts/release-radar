import Foundation
import XCTest
@testable import ReleaseRadarCore

final class CodexObserverAcceptanceTests: XCTestCase {
    private var fixtureDirectory: URL!
    private var databaseURL: URL!
    private var selectedRoot: URL!
    private var rootSymlink: URL!
    private var descendant: URL!
    private var authorizedWorktree: URL!
    private var authorizedWorktreeDescendant: URL!
    private var siblingPrefix: URL!
    private var outside: URL!
    private var escapeSymlink: URL!
    private var missing: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-codex-observer-\(UUID().uuidString)", isDirectory: true)
        databaseURL = fixtureDirectory.appendingPathComponent("release-radar.sqlite")
        selectedRoot = fixtureDirectory.appendingPathComponent("project", isDirectory: true)
        rootSymlink = fixtureDirectory.appendingPathComponent("project-link", isDirectory: true)
        descendant = selectedRoot.appendingPathComponent("Sources/Feature", isDirectory: true)
        authorizedWorktree = fixtureDirectory.appendingPathComponent("authorized-worktree", isDirectory: true)
        authorizedWorktreeDescendant = authorizedWorktree.appendingPathComponent("Sources/Feature", isDirectory: true)
        siblingPrefix = fixtureDirectory.appendingPathComponent("project-sibling", isDirectory: true)
        outside = fixtureDirectory.appendingPathComponent("outside", isDirectory: true)
        escapeSymlink = selectedRoot.appendingPathComponent("escape", isDirectory: true)
        missing = selectedRoot.appendingPathComponent("missing", isDirectory: true)

        for directory in [descendant!, authorizedWorktreeDescendant!, siblingPrefix!, outside!] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try FileManager.default.createSymbolicLink(at: rootSymlink, withDestinationURL: selectedRoot)
        try FileManager.default.createSymbolicLink(at: escapeSymlink, withDestinationURL: outside)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixtureDirectory)
        fixtureDirectory = nil
        databaseURL = nil
        selectedRoot = nil
        rootSymlink = nil
        descendant = nil
        authorizedWorktree = nil
        authorizedWorktreeDescendant = nil
        siblingPrefix = nil
        outside = nil
        escapeSymlink = nil
        missing = nil
        try super.tearDownWithError()
    }

    func testUnavailableObserverNeverClaimsLiveWithoutCache() async throws {
        let observer = UnavailableCodexObserver(reason: "No supported desktop attachment")

        let snapshot = try await observer.snapshot()

        XCTAssertEqual(snapshot.schemaVersion, CodexSnapshot.currentSchemaVersion)
        XCTAssertEqual(snapshot.freshness.state, .unavailable)
        XCTAssertNil(snapshot.freshness.lastObservedAt)
        XCTAssertEqual(snapshot.freshness.reason, "No supported desktop attachment")
        XCTAssertTrue(snapshot.threads.isEmpty)
    }

    func testCachedRuntimeFixtureIsDowngradedToStaleAndRetainsLastKnownState() async throws {
        let cached = try scopedRuntimeFixture()
        XCTAssertEqual(cached.freshness.state, .live, "Fixture represents data captured while connected")
        let observer = UnavailableCodexObserver(
            cachedSnapshot: cached,
            scope: observationScope(),
            reason: "Desktop live attachment unavailable"
        )

        let snapshot = try await observer.snapshot()

        XCTAssertEqual(snapshot.freshness.state, .stale)
        XCTAssertEqual(snapshot.freshness.lastObservedAt, date("2026-08-24T07:45:00Z"))
        XCTAssertEqual(snapshot.freshness.reason, "Desktop live attachment unavailable")
        XCTAssertEqual(snapshot.threads.map(\.status), [
            .active,
            .paused,
            .blocked,
            .awaitingInput,
            .completedReadyForReview,
        ])
        XCTAssertEqual(snapshot.threads.first?.activeFlags, ["waitingOnApproval"])
        XCTAssertEqual(snapshot.threads.first?.goal?.status, .active)
        XCTAssertNil(snapshot.threads.last?.goal, "A cleared goal stays cleared in cached state")
    }

    func testUnavailableObserverEventStreamUsesTheSameNonLiveBoundary() async throws {
        let cached = try scopedRuntimeFixture()
        let observer = UnavailableCodexObserver(cachedSnapshot: cached, scope: observationScope())
        var iterator = observer.events().makeAsyncIterator()

        let event = try await iterator.next()

        guard case let .snapshot(snapshot)? = event else {
            return XCTFail("Expected one normalized snapshot event")
        }
        XCTAssertEqual(snapshot.freshness.state, .stale)
        XCTAssertNotEqual(snapshot.freshness.state, .live)
        let nextEvent = try await iterator.next()
        XCTAssertNil(nextEvent)
    }

    func testUnsupportedCachedSchemaIsUnavailableRatherThanStale() async throws {
        let compatible = try scopedRuntimeFixture()
        let unsupported = CodexSnapshot(
            schemaVersion: CodexSnapshot.currentSchemaVersion + 1,
            capturedAt: compatible.capturedAt,
            freshness: compatible.freshness,
            threads: compatible.threads
        )
        let observer = UnavailableCodexObserver(
            cachedSnapshot: unsupported,
            scope: observationScope()
        )

        let snapshot = try await observer.snapshot()

        XCTAssertEqual(snapshot.schemaVersion, CodexSnapshot.currentSchemaVersion)
        XCTAssertEqual(snapshot.freshness.state, .unavailable)
        XCTAssertTrue(snapshot.freshness.reason?.localizedCaseInsensitiveContains("schema") == true)
        XCTAssertTrue(snapshot.threads.isEmpty)
    }

    func testCachedRuntimeIsLimitedToCanonicalAuthorizedRootsAndExclusions() async throws {
        let fixture = try decodeRuntimeFixture()
        let prototype = try XCTUnwrap(fixture.threads.first)
        let threads = [
            runtime(prototype, id: "root", workingDirectory: selectedRoot),
            runtime(prototype, id: "descendant", workingDirectory: descendant),
            runtime(prototype, id: "root-symlink", workingDirectory: rootSymlink),
            runtime(prototype, id: "worktree", workingDirectory: authorizedWorktree),
            runtime(prototype, id: "worktree-descendant", workingDirectory: authorizedWorktreeDescendant),
            runtime(prototype, id: "excluded", workingDirectory: selectedRoot),
            runtime(prototype, id: "sibling-prefix", workingDirectory: siblingPrefix),
            runtime(prototype, id: "outside", workingDirectory: outside),
            runtime(prototype, id: "missing", workingDirectory: missing),
            runtime(prototype, id: "symlink-escape", workingDirectory: escapeSymlink),
        ]
        let cached = CodexSnapshot(
            capturedAt: fixture.capturedAt,
            freshness: fixture.freshness,
            threads: threads
        )
        let scope = CodexObservationScope(
            selectedRoot: selectedRoot,
            authorizedWorktreeRoots: [authorizedWorktree],
            excludedThreadIDs: ["excluded"]
        )
        let observer = UnavailableCodexObserver(cachedSnapshot: cached, scope: scope)

        let snapshot = try await observer.snapshot()

        XCTAssertEqual(snapshot.freshness.state, .stale)
        XCTAssertEqual(Set(snapshot.threads.map(\.id)), [
            "root",
            "descendant",
            "root-symlink",
            "worktree",
            "worktree-descendant",
        ])
        XCTAssertEqual(
            snapshot.threads.first { $0.id == "root-symlink" }?.workingDirectory,
            selectedRoot.standardizedFileURL.resolvingSymlinksInPath()
        )
    }

    func testCachedRuntimeWithoutAuthorizedProjectScopeIsUnavailableAndEmpty() async throws {
        let observer = UnavailableCodexObserver(cachedSnapshot: try scopedRuntimeFixture())

        let snapshot = try await observer.snapshot()

        XCTAssertEqual(snapshot.freshness.state, .unavailable)
        XCTAssertTrue(snapshot.threads.isEmpty)
    }

    func testRuntimeObservationCannotMutateFormalTicketLane() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(
            actor: DeliveryActor(id: "codex-observer-fixture"),
            reason: "Seed formal lane for observer boundary test"
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'Fixture', 0)")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'Delivery')")
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-05', 'project-1', 'phase-1', 'Observe runtime', 'in_progress')"
            )
        }
        let observer = UnavailableCodexObserver(
            cachedSnapshot: try scopedRuntimeFixture(),
            scope: observationScope()
        )

        _ = try await observer.snapshot()
        let lane = try await store.read { connection in
            try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-05'")
        }

        XCTAssertEqual(lane, TicketLane.inProgress.rawValue)
    }

    private func decodeRuntimeFixture() throws -> CodexSnapshot {
        let bundle = Bundle(for: Self.self)
        let fixtureURL = try XCTUnwrap(bundle.url(forResource: "cached-runtime", withExtension: "json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CodexSnapshot.self, from: Data(contentsOf: fixtureURL))
    }

    private func scopedRuntimeFixture() throws -> CodexSnapshot {
        let fixture = try decodeRuntimeFixture()
        let paths = [selectedRoot, descendant, authorizedWorktree, selectedRoot, selectedRoot]
        return CodexSnapshot(
            schemaVersion: fixture.schemaVersion,
            capturedAt: fixture.capturedAt,
            freshness: fixture.freshness,
            threads: zip(fixture.threads, paths).map { runtime($0.0, id: $0.0.id, workingDirectory: $0.1!) }
        )
    }

    private func observationScope(excludedThreadIDs: Set<String> = []) -> CodexObservationScope {
        CodexObservationScope(
            selectedRoot: selectedRoot,
            authorizedWorktreeRoots: [authorizedWorktree],
            excludedThreadIDs: excludedThreadIDs
        )
    }

    private func runtime(
        _ prototype: CodexThreadRuntime,
        id: String,
        workingDirectory: URL
    ) -> CodexThreadRuntime {
        CodexThreadRuntime(
            id: id,
            workingDirectory: workingDirectory,
            status: prototype.status,
            activeFlags: prototype.activeFlags,
            waitingForInput: prototype.waitingForInput,
            lastObservedAt: prototype.lastObservedAt,
            goal: prototype.goal
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
