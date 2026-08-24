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

    func testResponsivePresentationUsesFullOutcomesWideAndIDsOnlyCompact() {
        XCTAssertEqual(DashboardLayout.presentation(forLaneWidth: 181), .fullOutcome)
        XCTAssertEqual(DashboardLayout.presentation(forLaneWidth: 180), .compactID)
        XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: false), 220)
        XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: true), 96)
    }
}
