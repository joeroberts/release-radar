import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class DashboardProjectionTests: XCTestCase {
    private var databaseURL: URL!

    override func setUp() {
        super.setUp()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-dashboard-\(UUID().uuidString).sqlite")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("pre-migration"))
        databaseURL = nil
        super.tearDown()
    }

    func testSeededBoardProjectsEveryTicketIntoExactlyOneOrderedLane() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)

        let projection = try await DashboardProjection.load(from: store)
        let project = try XCTUnwrap(projection.projects.first)
        let board = try XCTUnwrap(projection.board(for: project.id))

        XCTAssertEqual(project.name, "Rekon Pursuit")
        XCTAssertEqual(project.activePhaseName, "Post-MVP refinement")
        XCTAssertEqual(project.goalContext.linkQuality, .verified)
        XCTAssertEqual(project.goalContext.status, "Blocked")
        XCTAssertEqual(project.goalContext.text, "Resolve the policy boundary for Activity and AI areas.")
        XCTAssertEqual(
            project.goalContext.lastObservedAt,
            ISO8601DateFormatter().date(from: "2026-08-23T22:14:00Z")
        )
        XCTAssertEqual(project.currentWorkCount, 13)
        XCTAssertEqual(project.attentionCount, 3)
        XCTAssertEqual(board.lanes.map(\.lane), TicketLane.allCases)
        XCTAssertEqual(board.lanes.map(\.count), [9, 1, 2, 1, 18])

        let allIDs = board.lanes.flatMap { $0.cards.map(\.id) }
        XCTAssertEqual(allIDs.count, 31)
        XCTAssertEqual(Set(allIDs).count, allIDs.count, "Lane position is the sole ticket state membership")

        let inProgress = try XCTUnwrap(board.lane(.inProgress)?.cards.first)
        XCTAssertEqual(inProgress.id.rawValue, "VD2-08")
        XCTAssertEqual(inProgress.outcome, "Visual QA and accessibility acceptance")
        XCTAssertEqual(inProgress.dependencyCount, 4)
        XCTAssertEqual(inProgress.blockerCount, 0)
    }

    func testSelectedTicketProjectsReadOnlyContextAndRelationshipDirection() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)

        let projection = try await DashboardProjection.load(from: store)
        let detail = try XCTUnwrap(
            projection.board(for: DashboardSampleData.projectID)?
                .detail(for: TicketID(rawValue: "VD2-07c"))
        )

        XCTAssertEqual(detail.outcome, "Activity and AI areas")
        XCTAssertEqual(detail.goalContext.linkQuality, .verified)
        XCTAssertEqual(detail.goalContext.status, "Blocked")
        XCTAssertEqual(detail.requires.map(\.id.rawValue), ["VD2-03", "VD2-04", "VD2-05"])
        XCTAssertEqual(detail.unlocks.map(\.id.rawValue), ["UX-D12"])
        XCTAssertEqual(detail.ownerAttention, ["Policy decision required before work can continue."])
        XCTAssertEqual(detail.evidence.map(\.label), ["Activity areas decision record"])
        XCTAssertTrue(detail.auditHistory.contains { $0.contains("VD2-07c") })
        XCTAssertEqual(detail.notificationHistory, ["Blocked alert · Delivered"])
    }

    func testSeedIsIdempotentAndPersistsAcrossStoreRelaunch() async throws {
        let firstStore = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: firstStore)
        try await DashboardSampleData.seedIfNeeded(in: firstStore)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let projection = try await DashboardProjection.load(from: relaunchedStore)
        let board = try XCTUnwrap(projection.board(for: DashboardSampleData.projectID))

        XCTAssertEqual(board.lanes.reduce(0) { $0 + $1.count }, 31)
    }

    func testProjectWithoutPersistedGoalReportsGoalContextUnavailable() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(
            actor: DeliveryActor(id: "dashboard-projection-test"),
            reason: "Add project without observed goal",
            auditEventID: AuditEventID(rawValue: "dashboard-project-without-goal")
        ) { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 0)",
                bindings: [.text("project-without-goal"), .text("No Goal Project")]
            )
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
                bindings: [.text("no-goal-phase"), .text("project-without-goal"), .text("Planning")]
            )
            try connection.execute(
                "INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-without-goal', 'no-goal-phase')"
            )
        }

        let projection = try await DashboardProjection.load(from: store)
        let project = try XCTUnwrap(
            projection.projects.first { $0.id.rawValue == "project-without-goal" }
        )

        XCTAssertEqual(project.activePhaseName, "Planning")
        XCTAssertEqual(project.goalContext.linkQuality, .unavailable)
        XCTAssertNil(project.goalContext.status)
        XCTAssertNil(project.goalContext.text)
        XCTAssertNil(project.goalContext.lastObservedAt)
        XCTAssertEqual(project.currentWorkCount, 0)
        XCTAssertEqual(project.attentionCount, 0)
    }

    func testExplicitActivePhaseOverridesEarlierHistoricalPhase() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "dashboard-test"), reason: "Seed explicit active phase") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-explicit', 'Explicit')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-history', 'project-explicit', 'Historical')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-active', 'project-explicit', 'Current delivery')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-explicit', 'phase-active')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ACTIVE-1', 'project-explicit', 'phase-active', 'Current work', 'in_progress')")
        }

        let projection = try await DashboardProjection.load(from: store)
        let project = try XCTUnwrap(projection.projects.first { $0.id.rawValue == "project-explicit" })
        let board = try XCTUnwrap(projection.board(for: project.id))

        XCTAssertEqual(project.activePhaseName, "Current delivery")
        XCTAssertEqual(board.phaseID.rawValue, "phase-active")
        XCTAssertEqual(board.lane(.inProgress)?.cards.map(\.id.rawValue), ["ACTIVE-1"])
    }

    func testProjectWithMultiplePhasesAndNoExplicitActivePhaseHasNoGuessedBoard() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "dashboard-test"), reason: "Seed ambiguous project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-ambiguous', 'Ambiguous')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-a', 'project-ambiguous', 'Historical')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-b', 'project-ambiguous', 'Planned')")
        }

        let projection = try await DashboardProjection.load(from: store)
        let project = try XCTUnwrap(projection.projects.first { $0.id.rawValue == "project-ambiguous" })

        XCTAssertEqual(project.activePhaseName, "No active phase")
        XCTAssertNil(projection.board(for: project.id))
        XCTAssertEqual(project.currentWorkCount, 0)
        XCTAssertEqual(project.attentionCount, 0)
    }

    func testResponsivePresentationUsesFullOutcomesWideAndIDsOnlyCompact() {
        XCTAssertEqual(DashboardLayout.presentation(forLaneWidth: 181), .fullOutcome)
        XCTAssertEqual(DashboardLayout.presentation(forLaneWidth: 180), .compactID)
        XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: false), 220)
        XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: true), 96)
    }
}
