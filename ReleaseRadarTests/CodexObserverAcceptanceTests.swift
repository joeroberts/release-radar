import Foundation
import XCTest
@testable import ReleaseRadarCore

final class CodexObserverAcceptanceTests: XCTestCase {
    private var databaseURL: URL!

    override func setUp() {
        super.setUp()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-codex-observer-\(UUID().uuidString).sqlite")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("pre-migration"))
        databaseURL = nil
        super.tearDown()
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
        let cached = try decodeRuntimeFixture()
        XCTAssertEqual(cached.freshness.state, .live, "Fixture represents data captured while connected")
        let observer = UnavailableCodexObserver(
            cachedSnapshot: cached,
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
        let cached = try decodeRuntimeFixture()
        let observer = UnavailableCodexObserver(cachedSnapshot: cached)
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
        let observer = UnavailableCodexObserver(cachedSnapshot: try decodeRuntimeFixture())

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

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
