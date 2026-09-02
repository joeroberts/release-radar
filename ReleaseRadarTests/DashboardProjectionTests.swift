import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class DashboardProjectionTests: XCTestCase {
    func testTaskPlansProjectCanonicalActiveRowsAndCountsAcrossMutations() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let ticketID = TicketID(rawValue: "VD2-07c")
        let initial = try await DashboardProjection.load(from: store)
        XCTAssertEqual(initial.board(for: projectID)?.detail(for: ticketID)?.taskPlan, .noPlan)
        XCTAssertNil(initial.board(for: projectID)?.lane(.blocked)?.cards.first?.activeTaskCount)
        let revision = try await store.transact(actor: .init(id: "fixture"), reason: "Create task projection fixture") { c in
            try TicketTaskPlanningPolicy.revisePlan(projectID: projectID, ticketID: ticketID, expectedRevision: nil,
                additions: [
                    .init(id: .init(rawValue: "z"), label: "Task B", title: "Verify recovery", sortOrder: 1),
                    .init(id: .init(rawValue: "a"), label: "Task A", title: "Load canonical tasks", sortOrder: 1),
                    .init(id: .init(rawValue: "old"), label: "Task old", title: "Replace prior definition", sortOrder: 0)
                ], definitionRevisions: [], supersededTaskIDs: [], connection: c).revision
        }
        let revised = try await store.transact(actor: .init(id: "fixture"), reason: "Supersede old task") { c in
            try TicketTaskPlanningPolicy.revisePlan(projectID: projectID, ticketID: ticketID, expectedRevision: revision,
                additions: [], definitionRevisions: [], supersededTaskIDs: [.init(rawValue: "old")], connection: c).revision
        }
        let loaded = try await DashboardProjection.load(from: store)
        guard case let .loaded(plan)? = loaded.board(for: projectID)?.detail(for: ticketID)?.taskPlan else {
            return XCTFail("Expected loaded canonical plan")
        }
        XCTAssertEqual(plan.tasks.map(\.id.rawValue), ["a", "z"])
        XCTAssertEqual(plan.tasks.map(\.completion), [.pending, .pending])
        XCTAssertEqual(loaded.board(for: projectID)?.lane(.blocked)?.cards.first?.activeTaskCount, 2)
        let completedRevision = try await store.transact(actor: .init(id: "fixture"), reason: "Complete task") { c in
            try TicketTaskPlanningPolicy.completeTask(projectID: projectID, ticketID: ticketID,
                taskID: .init(rawValue: "a"), expectedRevision: revised, connection: c).revision
        }
        let completed = try await DashboardProjection.load(from: store)
        guard case let .loaded(completedPlan)? = completed.board(for: projectID)?.detail(for: ticketID)?.taskPlan else {
            return XCTFail("Expected completed row")
        }
        XCTAssertEqual(completedPlan.tasks.map(\.completion), [.completed, .pending])
        XCTAssertEqual(completed.board(for: projectID)?.lane(.blocked)?.cards.first?.activeTaskCount, 2)
        _ = try await store.transact(actor: .init(id: "fixture"), reason: "Add next task") { c in
            try TicketTaskPlanningPolicy.revisePlan(projectID: projectID, ticketID: ticketID, expectedRevision: completedRevision,
                additions: [.init(id: .init(rawValue: "next"), label: "Task C", title: "Inspect running UI", sortOrder: 2)],
                definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let added = try await DashboardProjection.load(from: store)
        guard case let .loaded(addedPlan)? = added.board(for: projectID)?.detail(for: ticketID)?.taskPlan else {
            return XCTFail("Expected added row")
        }
        XCTAssertEqual(addedPlan.tasks.map(\.id.rawValue), ["a", "z", "next"])
        let card = try XCTUnwrap(added.board(for: projectID)?.lane(.blocked)?.cards.first)
        XCTAssertEqual(card.activeTaskCount, 3)
        XCTAssertEqual(card.taskPlan, .loaded(plan: addedPlan))
    }

    func testTaskQueryFailureDropsOnlyFailedTicketTasksAndRecovers() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let ticketID = TicketID(rawValue: "VD2-07c")
        _ = try await store.transact(actor: .init(id: "fixture"), reason: "Seed failed task query") { c in
            try TicketTaskPlanningPolicy.revisePlan(projectID: projectID, ticketID: ticketID, expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "one"), label: "Task 1", title: "Recover task load", sortOrder: 0)],
                definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let before = try await DashboardProjection.load(from: store)
        XCTAssertEqual(before.board(for: projectID)?.lane(.blocked)?.cards.first?.activeTaskCount, 1)
        let failed = try await DashboardProjection.load(from: store, taskRows: { connection, project, phase, ticket in
            if ticket == nil || ticket == ticketID {
                // Exercise a genuine failing read; other ticket queries still succeed.
                return try connection.rows("SELECT * FROM missing_task_projection_table")
            }
            return try TicketTaskPlanProjection.queryRows(connection, projectID: project, phaseID: phase, ticketID: ticket)
        })
        let board = try XCTUnwrap(failed.board(for: projectID))
        guard case let .unavailable(recovery)? = board.detail(for: ticketID)?.taskPlan else {
            return XCTFail("Task query failure must be distinct from no plan")
        }
        XCTAssertFalse(recovery.message.isEmpty)
        XCTAssertNil(board.lane(.blocked)?.cards.first?.activeTaskCount)
        XCTAssertEqual(board.detail(for: .init(rawValue: "VD2-08"))?.taskPlan, .noPlan)
        XCTAssertEqual(board.lanes.map(\.count), [9, 1, 2, 1, 18])
        XCTAssertEqual(board.detail(for: ticketID)?.evidence, before.board(for: projectID)?.detail(for: ticketID)?.evidence)
        let recovered = try await DashboardProjection.load(from: store)
        XCTAssertEqual(recovered.board(for: projectID)?.lane(.blocked)?.cards.first?.activeTaskCount, 1)
    }

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

    func testManagedRowWithNoPersistedPathDoesNotBreakDashboard() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "fixture"), reason: "Managed evidence fixture") { c in
            try c.execute("INSERT INTO evidence (id, project_id, ticket_id, artifact_id, path) VALUES ('managed', 'rekon-pursuit', 'VD2-07c', 'draft', NULL)")
        }
        let projection = try await DashboardProjection.load(from: store)
        let detail = try XCTUnwrap(projection.board(for: DashboardSampleData.projectID)?.detail(for: .init(rawValue: "VD2-07c")))
        XCTAssertEqual(detail.evidence.count, 2)
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
        let planning = try await store.read { connection in
            (
                try connection.scalarText("SELECT state FROM phase_plans WHERE phase_id = 'rekon-pursuit-post-mvp'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_plans WHERE ready_revision = revision"),
                try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_ticket_assignments"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE plan_legacy_continuation <> 0"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_task_plans")
            )
        }
        XCTAssertEqual(planning.0, "ready")
        XCTAssertEqual(planning.1, 1)
        XCTAssertEqual(planning.2, 31)
        XCTAssertEqual(planning.3, 0)
        XCTAssertEqual(planning.4, 0)
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
        XCTAssertEqual(project.activePhaseID?.rawValue, "phase-active")
        XCTAssertEqual(project.phases.map(\.id.rawValue), ["phase-active", "phase-history"])
        XCTAssertEqual(board.phaseID.rawValue, "phase-active")
        XCTAssertEqual(board.lane(.inProgress)?.cards.map(\.id.rawValue), ["ACTIVE-1"])
    }

    func testActivePhaseSelectionKeepsOptionsDeterministicAndBoardMembershipScopedAcrossRelaunch() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        let projectID = ProjectID(rawValue: "phase-selection-project")
        let projectRoot = databaseURL.deletingLastPathComponent()
        try await store.transact(
            actor: .init(id: "dashboard-test"),
            reason: "Seed active phase projection fixture",
            auditEventID: .init(rawValue: "phase-selection-seed-audit"),
            auditScope: .init(
                projectID: projectID,
                entityType: .phase,
                entityID: "phase-current"
            )
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('phase-selection-project', 'Phase Selection')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'phase-selection-project', 'Current')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-history', 'phase-selection-project', 'History')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-roadmap', 'phase-selection-project', 'Roadmap delivery')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-order-z', 'phase-selection-project', 'ROADMAP')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-order-a', 'phase-selection-project', 'Roadmap')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('phase-selection-project', 'phase-current')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-A', 'phase-selection-project', 'phase-current', 'Current ticket keeps cross phase truth.', 'backlog')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-B', 'phase-selection-project', 'phase-current', 'Current ticket keeps local dependency.', 'in_progress')")
            for index in 1...8 {
                try connection.execute(
                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, 'phase-selection-project', 'phase-roadmap', ?, 'backlog')",
                    bindings: [.text("ROAD-B\(index)"), .text("Roadmap backlog outcome \(index).")]
                )
            }
            for index in 1...3 {
                try connection.execute(
                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, 'phase-selection-project', 'phase-roadmap', ?, 'blocked')",
                    bindings: [.text("ROAD-X\(index)"), .text("Roadmap blocked outcome \(index).")]
                )
            }
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('HISTORY-A', 'phase-selection-project', 'phase-history', 'Historical accepted outcome.', 'accepted')")
            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dep-roadmap', 'phase-selection-project', 'phase-roadmap', 'phase-current')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-cross', 'phase-selection-project', 'CURRENT-A', 'ROAD-B1')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-current', 'phase-selection-project', 'CURRENT-B', 'CURRENT-A')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-roadmap', 'phase-selection-project', 'ROAD-X1', 'ROAD-B2')")
        }

        let initial = try await DashboardProjection.load(from: store)
        let initialProject = try XCTUnwrap(initial.projects.first { $0.id == projectID })
        let initialBoard = try XCTUnwrap(initial.board(for: projectID))
        XCTAssertEqual(initialProject.activePhaseID?.rawValue, "phase-current")
        XCTAssertEqual(initialProject.phases.map(\.id.rawValue), [
            "phase-current", "phase-history", "phase-order-a", "phase-order-z", "phase-roadmap",
        ])
        XCTAssertEqual(Set(initialBoard.details.keys.map(\.rawValue)), ["CURRENT-A", "CURRENT-B"])
        XCTAssertEqual(initialBoard.detail(for: .init(rawValue: "CURRENT-A"))?.requires.map(\.id.rawValue), ["ROAD-B1"])
        let initialGraph = try await DependencyGraphProjection.load(
            from: store,
            projectID: projectID,
            phaseID: .init(rawValue: "phase-current"),
            selectedTicketID: .init(rawValue: "CURRENT-A")
        )
        XCTAssertEqual(Set(initialGraph.nodes.map(\.id.rawValue)), ["CURRENT-A", "CURRENT-B"])
        XCTAssertNil(initialGraph.node(id: .init(rawValue: "ROAD-B1")))

        let before = try await Self.phaseSelectionPersistenceSnapshot(store)
        XCTAssertEqual(before.activeRows, ["phase-selection-project|phase-current"])
        XCTAssertEqual(before.phaseDependencies, [
            "phase-dep-roadmap|phase-selection-project|phase-roadmap|phase-current",
        ])
        let requestID = UUID(uuidString: "29292929-2929-4929-8929-292929292929")!
        let result = await AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(projectID: projectID, canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
            ])
        ).dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: projectRoot.path,
            reason: "Select roadmap projection",
            command: .setActivePhase(phaseID: "phase-roadmap")
        ))
        XCTAssertNil(result.error)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let reloaded = try await DashboardProjection.load(from: relaunchedStore)
        let reloadedProject = try XCTUnwrap(reloaded.projects.first { $0.id == projectID })
        let reloadedBoard = try XCTUnwrap(reloaded.board(for: projectID))
        XCTAssertEqual(reloadedProject.activePhaseID?.rawValue, "phase-roadmap")
        XCTAssertEqual(reloadedProject.phases, initialProject.phases)
        XCTAssertEqual(reloadedBoard.lanes.map(\.count), [8, 0, 0, 3, 0])
        XCTAssertEqual(Set(reloadedBoard.details.keys.map(\.rawValue)), Set((1...8).map { "ROAD-B\($0)" } + (1...3).map { "ROAD-X\($0)" }))
        XCTAssertEqual(reloadedBoard.detail(for: .init(rawValue: "ROAD-B1"))?.unlocks.map(\.id.rawValue), ["CURRENT-A"])
        XCTAssertNil(reloadedBoard.detail(for: .init(rawValue: "CURRENT-A")))
        let roadmapGraph = try await DependencyGraphProjection.load(
            from: relaunchedStore,
            projectID: projectID,
            phaseID: .init(rawValue: "phase-roadmap"),
            selectedTicketID: .init(rawValue: "ROAD-B1")
        )
        XCTAssertNil(roadmapGraph.node(id: .init(rawValue: "CURRENT-A")))
        let after = try await Self.phaseSelectionPersistenceSnapshot(relaunchedStore)
        XCTAssertEqual(after.phases, before.phases)
        XCTAssertEqual(after.tickets, before.tickets)
        XCTAssertEqual(after.phaseDependencies, before.phaseDependencies)
        XCTAssertEqual(after.ticketDependencies, before.ticketDependencies)
        XCTAssertEqual(after.activeRows, ["phase-selection-project|phase-roadmap"])

        let auditEventID = try XCTUnwrap(result.auditEventID)
        let selectionAuditPrefix = "\(auditEventID.rawValue)|"
        let selectionAudits = after.auditRows.filter { $0.hasPrefix(selectionAuditPrefix) }
        XCTAssertEqual(selectionAudits.count, 1)
        XCTAssertEqual(
            after.auditRows.filter { !$0.hasPrefix(selectionAuditPrefix) },
            before.auditRows
        )

        let receiptPrefix = "\(requestID.uuidString.lowercased())|"
        let durableReceipts = after.requestRows.filter {
            $0.lowercased().hasPrefix(receiptPrefix)
        }
        XCTAssertEqual(durableReceipts.count, 1)
        XCTAssertEqual(
            after.requestRows.filter { !$0.lowercased().hasPrefix(receiptPrefix) },
            before.requestRows
        )
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

        XCTAssertNil(project.activePhaseID)
        XCTAssertEqual(project.phases.map(\.id.rawValue), ["phase-a", "phase-b"])
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

    private struct PhaseSelectionPersistenceSnapshot: Equatable {
        let phases: [String]
        let tickets: [String]
        let phaseDependencies: [String]
        let ticketDependencies: [String]
        let activeRows: [String]
        let auditRows: [String]
        let requestRows: [String]
    }

    private static func phaseSelectionPersistenceSnapshot(
        _ store: DeliveryStore
    ) async throws -> PhaseSelectionPersistenceSnapshot {
        try await store.read { connection in
            PhaseSelectionPersistenceSnapshot(
                phases: try textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || name AS value FROM phases ORDER BY project_id, id"
                ),
                tickets: try textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || outcome || '|' || lane AS value FROM tickets ORDER BY project_id, id"
                ),
                phaseDependencies: try textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || depends_on_phase_id AS value FROM phase_dependencies ORDER BY project_id, id"
                ),
                ticketDependencies: try textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || ticket_id || '|' || depends_on_ticket_id AS value FROM ticket_dependencies ORDER BY project_id, id"
                ),
                activeRows: try textRows(
                    connection,
                    sql: "SELECT project_id || '|' || phase_id AS value FROM project_active_phases ORDER BY project_id"
                ),
                auditRows: try textRows(
                    connection,
                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') || '|' || created_at AS value FROM audit_events ORDER BY id"
                ),
                requestRows: try textRows(
                    connection,
                    sql: "SELECT request_id || '|' || hex(request_body) || '|' || hex(result_data) || '|' || created_at AS value FROM agent_command_requests ORDER BY request_id"
                )
            )
        }
    }

    private static func textRows(
        _ connection: SQLiteConnection,
        sql: String
    ) throws -> [String] {
        var values: [String] = []
        var offset: Int64 = 0
        while let row = try connection.row(
            "\(sql) LIMIT 1 OFFSET ?",
            bindings: [.integer(offset)]
        ) {
            guard case let .text(value)? = row["value"] else {
                throw DashboardProjectionTestError.missingSnapshotText
            }
            values.append(value)
            offset += 1
        }
        return values
    }
}

private enum DashboardProjectionTestError: Error {
    case missingSnapshotText
}
