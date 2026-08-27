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
        XCTAssertEqual(inProgress.outcome, "Verifies the dashboard’s visual fidelity and accessibility before release.")
        XCTAssertEqual(inProgress.dependencyCount, 4)
        XCTAssertEqual(inProgress.blockerCount, 0)
        XCTAssertTrue(
            board.lanes.flatMap(\.cards).allSatisfy {
                $0.outcome.split(whereSeparator: \.isWhitespace).count >= 5 && $0.outcome.hasSuffix(".")
            }
        )
    }

    func testSelectedTicketProjectsReadOnlyContextAndRelationshipDirection() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)

        let projection = try await DashboardProjection.load(from: store)
        let detail = try XCTUnwrap(
            projection.board(for: DashboardSampleData.projectID)?
                .detail(for: TicketID(rawValue: "VD2-07c"))
        )

        XCTAssertEqual(detail.outcome, "Makes delivery activity and AI context understandable to the owner.")
        XCTAssertEqual(detail.goalContext.linkQuality, .verified)
        XCTAssertEqual(detail.goalContext.status, "Blocked")
        XCTAssertEqual(detail.requires.map(\.id.rawValue), ["VD2-03", "VD2-04", "VD2-05"])
        XCTAssertEqual(detail.unlocks.map(\.id.rawValue), ["UX-D12"])
        XCTAssertEqual(detail.ownerAttention, ["Policy decision required before work can continue."])
        XCTAssertEqual(detail.evidence.map(\.label), ["Activity areas decision record"])
        XCTAssertTrue(detail.auditHistory.contains { $0.contains("VD2-07c") })
        XCTAssertEqual(detail.notificationHistory, ["Blocked alert · Delivered"])
    }

    func testApprovedOlderGoalRemainsTheOnlyTicketAttributedRuntimeIdentity() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "dashboard-test"), reason: "Observe a newer unapproved goal") { connection in
            try connection.execute(
                "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('newer-unapproved-goal', 'rekon-pursuit', 'rr06-thread-vd2-07c', 'active', 'Newer unapproved goal', '2026-08-25T12:00:00Z')"
            )
        }

        let projection = try await DashboardProjection.load(from: store)
        let detail = try XCTUnwrap(
            projection.board(for: DashboardSampleData.projectID)?
                .detail(for: TicketID(rawValue: "VD2-07c"))
        )
        let activity = try await ProjectActivityProjection.load(from: store, projectID: DashboardSampleData.projectID)
        let approvedRuntime = try XCTUnwrap(activity.items.first { $0.ticketID?.rawValue == "VD2-07c" && $0.source == .runtime })
        let newerRuntime = try XCTUnwrap(activity.items.first { $0.id == "runtime-newer-unapproved-goal" })

        XCTAssertEqual(detail.goalContext.text, "Resolve the policy boundary for Activity and AI areas.")
        XCTAssertEqual(detail.goalContext.status, "Blocked")
        XCTAssertEqual(approvedRuntime.id, "runtime-rr06-goal-vd2-07c")
        XCTAssertEqual(approvedRuntime.detail, "Resolve the policy boundary for Activity and AI areas.")
        XCTAssertNil(newerRuntime.ticketID)
    }

    func testFreshSampleOutcomeRemainsEditableThroughTicketUpsert() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        let root = databaseURL.deletingLastPathComponent()
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(projectID: DashboardSampleData.projectID, canonicalRoot: root, authorizedRoots: [root]),
            ])
        )

        let result = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "14141414-1414-4414-8414-141414141414")!,
            projectRoot: root.path,
            reason: "Clarify VD2-07c outcome",
            command: .upsertTicket(
                ticketID: "VD2-07c",
                phaseID: DashboardSampleData.phaseID.rawValue,
                outcome: "Explains the approved Activity policy boundary and next delivery step.",
                lane: .blocked
            )
        ))
        let projection = try await DashboardProjection.load(from: store)
        let detail = try XCTUnwrap(
            projection.board(for: DashboardSampleData.projectID)?
                .detail(for: TicketID(rawValue: "VD2-07c"))
        )

        XCTAssertNil(result.error)
        XCTAssertEqual(detail.outcome, "Explains the approved Activity policy boundary and next delivery step.")
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

    func testRequestedBoardDensityUsesCompactCardsAtOrBelowTheLaneWidthBoundary() {
        XCTAssertEqual(BoardDensity.fullOutcomes.displayName, "Full outcomes")
        XCTAssertEqual(BoardDensity.compact.displayName, "Compact density")
        XCTAssertEqual(BoardDensity.fullOutcomes.presentation(forLaneWidth: 181), .fullOutcome)
        XCTAssertEqual(BoardDensity.fullOutcomes.presentation(forLaneWidth: 180), .compactID)
        XCTAssertEqual(BoardDensity.compact.presentation(forLaneWidth: 181), .compactID)
        XCTAssertEqual(BoardDensity.compact.presentation(forLaneWidth: 180), .compactID)
        XCTAssertEqual(
            BoardDensity.fullOutcomes.accessibilityOptionLabel(isSelected: true, forLaneWidth: 180),
            "Full outcomes requested; showing Compact density at the current width"
        )
        XCTAssertEqual(
            BoardDensity.fullOutcomes.accessibilityHelp(forLaneWidth: 180),
            "Full outcomes remains selected and restores automatically when the window is wide enough."
        )
        XCTAssertEqual(
            BoardDensity.compact.accessibilityOptionLabel(isSelected: true, forLaneWidth: 180),
            "Compact density"
        )
        XCTAssertTrue(PhaseBoardLayout.usesVerticallyScrollableStack(forWidth: 760))
        XCTAssertTrue(PhaseBoardLayout.usesVerticallyScrollableStack(forWidth: 900))
        XCTAssertFalse(PhaseBoardLayout.usesVerticallyScrollableStack(forWidth: 1_260))
        XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: false), 220)
        XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: true), 96)
    }
}
