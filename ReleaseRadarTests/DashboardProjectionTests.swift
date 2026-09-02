import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class DashboardProjectionTests: XCTestCase {
    func testByteDistinctGoalIDsRemainSeparateInBoardsAndFilters() async throws {
        let composed = DeliveryGoalID(rawValue: "\u{e9}"), decomposed = DeliveryGoalID(rawValue: "e\u{301}")
        let first = DeliveryGoalFilter.goal(composed), second = DeliveryGoalFilter.goal(decomposed)
        XCTAssertNotEqual(first, second, "SQLite BINARY goal identities must not normalize")
        guard first != second else { return } // Do not deliberately crash the host on the known duplicate-key bug.
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Byte-distinct goal snapshot") { c in
            try c.execute("INSERT INTO projects (id,name) VALUES ('p','Project')")
            try c.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase','p','Phase')")
            for id in [composed.rawValue, decomposed.rawValue] {
                try c.execute("INSERT INTO phases (id,project_id,name) VALUES (?,'p','Same name')", bindings: [.text(id)])
            }
            try c.execute("INSERT INTO project_active_phases (project_id,phase_id) VALUES ('p',?)", bindings: [.text(composed.rawValue)])
            for (id, ticket) in [(composed, "one"), (decomposed, "two")] {
                try c.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('p','phase',?,?,?,'draft',0,'2026-09-02T12:00:00Z','2026-09-02T12:00:00Z')",
                              bindings: [.text(id.rawValue), .text(ticket), .text(ticket)])
                try c.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','phase',?,'backlog')", bindings: [.text(ticket), .text(ticket)])
                try c.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p','phase',?,?)", bindings: [.text(id.rawValue), .text(ticket)])
            }
        }
        let dashboard = try await DashboardProjection.load(from: store)
        XCTAssertEqual(dashboard.boards.count, 3)
        let active = try XCTUnwrap(dashboard.board(for: .init(rawValue: "p")))
        XCTAssertEqual(Data(active.phaseID.rawValue.utf8), Data(composed.rawValue.utf8))
        let other = try XCTUnwrap(dashboard.board(for: .init(rawValue: "p"), phaseID: .init(rawValue: decomposed.rawValue)))
        XCTAssertEqual(Data(other.phaseID.rawValue.utf8), Data(decomposed.rawValue.utf8))
        XCTAssertFalse(other.isActivePhase)
        let board = try XCTUnwrap(dashboard.board(for: .init(rawValue: "p"), phaseID: .init(rawValue: "phase")))
        XCTAssertEqual(board.deliveryGoals.map { $0.ticketIDs.map(\.rawValue) }, [["two"], ["one"]])
        XCTAssertEqual(Set(board.deliveryGoals.map(\.id)).count, 2)
        XCTAssertEqual(board.filtered(by: first).lanes.flatMap(\.cards).map(\.id.rawValue), ["one"])
        XCTAssertEqual(board.filtered(by: second).lanes.flatMap(\.cards).map(\.id.rawValue), ["two"])
    }

    func testMigratedLegacyContinuationIsProjectedWithoutInventingCoverage() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SchemaV10/release-radar-v10.sqlite")
        try FileManager.default.copyItem(at: fixture, to: databaseURL)
        do {
            let old = try SQLiteConnection(url: databaseURL)
            try old.execute("INSERT INTO projects (id,name) VALUES ('legacy-project','Legacy project')")
            try old.execute("INSERT INTO phases (id,project_id,name) VALUES ('legacy-phase','legacy-project','Legacy phase')")
            try old.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('active','legacy-project','legacy-phase','Existing work','in_progress'), ('blocked','legacy-project','legacy-phase','Blocked work','blocked'), ('done','legacy-project','legacy-phase','Historical work','accepted')")
        }
        let projection = try await DashboardProjection.load(from: DeliveryStore(databaseURL: databaseURL))
        let board = try XCTUnwrap(projection.board(for: .init(rawValue: "legacy-project"), phaseID: .init(rawValue: "legacy-phase")))
        XCTAssertEqual(board.phasePlan.state, .legacyUnassessed)
        XCTAssertEqual(board.phasePlan.upcomingCount, 2)
        XCTAssertEqual(board.phasePlan.coveredUpcomingCount, 0)
        XCTAssertEqual(board.phasePlan.unassignedUpcomingCount, 2)
        XCTAssertTrue(board.detail(for: .init(rawValue: "active"))?.isLegacyContinuation == true)
        XCTAssertFalse(board.detail(for: .init(rawValue: "blocked"))?.isLegacyContinuation == true)
        XCTAssertNil(board.detail(for: .init(rawValue: "done"))?.deliveryGoal)
    }

    func testInactiveBoardPreservesAuthorizedEvidenceMetadataAndRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("task9-evidence-\(UUID().uuidString)").resolvingSymlinksInPath()
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: fixture, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Managed board evidence") { c in
            try c.execute("INSERT INTO projects (id,name) VALUES ('evidence-project','Evidence project')")
            try c.execute("INSERT INTO phases (id,project_id,name) VALUES ('active-phase','evidence-project','Active'), ('other-phase','evidence-project','Other')")
            try c.execute("INSERT INTO project_active_phases (project_id,phase_id) VALUES ('evidence-project','active-phase')")
            try c.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('evidence-ticket','evidence-project','other-phase','Preserve evidence','backlog')")
            try c.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root','evidence-project',?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data) VALUES ('evidence-project',?,?)", bindings: [.text(root.path), .blob(Data(root.path.utf8))])
            try c.execute("INSERT INTO project_documentation_bindings VALUES ('evidence-project','root',?,1,?,?)",
                          bindings: [.text(snapshot.catalog.repositoryID), .text(snapshot.digest), .blob(snapshot.canonicalCatalog)])
            for artifact in ["current", "draft", "history"] {
                try c.execute("INSERT INTO evidence (id,project_id,ticket_id,artifact_id,path) VALUES (?,'evidence-project','evidence-ticket',?,NULL)", bindings: [.text(artifact), .text(artifact)])
            }
        }
        func bookmarks(allowAccess: Bool) -> ProjectBookmarkStore {
            ProjectBookmarkStore(resolver: { .init(url: URL(fileURLWithPath: String(decoding: $0, as: UTF8.self)), isStale: false) },
                                 startAccessing: { _ in allowAccess }, stopAccessing: { _ in })
        }
        let project = ProjectID(rawValue: "evidence-project"), phase = PhaseID(rawValue: "other-phase")
        let loaded = try await DashboardProjection.load(from: store, bookmarkStore: bookmarks(allowAccess: true))
        let board = try XCTUnwrap(loaded.board(for: project, phaseID: phase))
        let evidence = try XCTUnwrap(board.detail(for: .init(rawValue: "evidence-ticket"))).evidence
        XCTAssertEqual(evidence.count, 3)
        for (id, lifecycle, authority): (String, RepositoryDocumentArtifact.Lifecycle, RepositoryDocumentArtifact.Authority) in
            [("current", .active, .controlling), ("draft", .proposed, .supporting), ("history", .archived, .nonAuthoritative)] {
            let item = try XCTUnwrap(evidence.first { $0.id.rawValue == id })
            XCTAssertEqual(item.locator, .managedDocument(artifactID: id))
            XCTAssertEqual(item.managedDocument?.lifecycle, lifecycle)
            XCTAssertEqual(item.managedDocument?.authority, authority)
            XCTAssertTrue(item.isAvailable)
        }
        XCTAssertEqual(board.filtered(by: .unassigned).detail(for: .init(rawValue: "evidence-ticket"))?.evidence, evidence)
        let denied = try await DashboardProjection.load(from: store, bookmarkStore: bookmarks(allowAccess: false))
        let unavailable = try XCTUnwrap(denied.board(for: project, phaseID: phase)?.detail(for: .init(rawValue: "evidence-ticket"))).evidence
        XCTAssertEqual(unavailable.map(\.id), evidence.map(\.id))
        XCTAssertTrue(unavailable.allSatisfy { !$0.isAvailable && EvidenceStatusPresentation($0).recovery != nil })
        let recovered = try await DashboardProjection.load(from: store, bookmarkStore: bookmarks(allowAccess: true))
        XCTAssertEqual(recovered.board(for: project, phaseID: phase)?.detail(for: .init(rawValue: "evidence-ticket"))?.evidence, evidence)
    }

    func testAllPhaseBoardsKeepActiveSummaryAndExactCoverageWithStableFilters() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        let project = DashboardSampleData.projectID
        try await store.transact(actor: .init(id: "fixture"), reason: "Additional projection phases") { c in
            let statements = """
                INSERT INTO phases (id,project_id,name) VALUES ('roadmap','rekon-pursuit','Roadmap');
                INSERT INTO phases (id,project_id,name) VALUES ('empty','rekon-pursuit','Empty');
                INSERT INTO projects (id,name) VALUES ('no-active','No active phase');
                INSERT INTO phases (id,project_id,name) VALUES ('legacy','no-active','Legacy');
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                  ('r1','rekon-pursuit','roadmap','First outcome','backlog'),
                  ('r2','rekon-pursuit','roadmap','Second outcome','blocked'),
                  ('r3','rekon-pursuit','roadmap','Unassigned outcome','backlog'),
                  ('r4','rekon-pursuit','roadmap','Accepted history','accepted'),
                  ('legacy-work','no-active','legacy','Continue existing work','in_progress'),
                  ('legacy-done','no-active','legacy','Accepted legacy history','accepted');
                INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES
                  ('rekon-pursuit','roadmap','z','Same title','Second goal','draft',1,'2026-09-02T12:00:00Z','2026-09-02T12:00:00Z'),
                  ('rekon-pursuit','roadmap','a','Same title','First goal','draft',1,'2026-09-02T12:00:00Z','2026-09-02T12:00:00Z'),
                  ('rekon-pursuit','roadmap','old','Old goal','Historical goal','superseded',2,'2026-09-02T12:00:00Z','2026-09-02T12:00:00Z');
                INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES
                  ('rekon-pursuit','roadmap','a','r1'), ('rekon-pursuit','roadmap','z','r2');
                INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion)
                  VALUES ('rekon-pursuit','roadmap','a',0,'First outcome is verified');
                UPDATE phase_plans SET state='draft',revision=7 WHERE phase_id='roadmap';
                INSERT INTO evidence (id,project_id,ticket_id,path,is_available) VALUES
                  ('legacy-evidence','rekon-pursuit','r1','/synthetic/missing.md',0);
                INSERT INTO evidence (id,project_id,ticket_id,artifact_id,path) VALUES
                  ('managed-evidence','rekon-pursuit','r1','stable-artifact',NULL);
                """
            for statement in statements.split(separator: ";") where !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try c.execute(String(statement))
            }
            _ = try TicketTaskPlanningPolicy.revisePlan(projectID: project, ticketID: .init(rawValue: "r1"),
                expectedRevision: nil, additions: [.init(id: .init(rawValue: "task"), label: "Task 1", title: "Verify first outcome", sortOrder: 0)],
                definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let before = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let projection = try await DashboardProjection.load(from: store)
        let active = try XCTUnwrap(projection.board(for: project))
        XCTAssertEqual(active.phaseID.rawValue, "rekon-pursuit-post-mvp")
        XCTAssertEqual(active.project.currentWorkCount, 13)
        XCTAssertEqual(active.project.attentionCount, 3)
        XCTAssertEqual(projection.boards.count, 4)
        XCTAssertNil(projection.board(for: .init(rawValue: "no-active")))
        XCTAssertNil(projection.board(for: .init(rawValue: "no-active"), phaseID: .init(rawValue: "roadmap")))
        let board = try XCTUnwrap(projection.board(for: project, phaseID: .init(rawValue: "roadmap")))
        XCTAssertEqual(board.phaseName, "Roadmap")
        XCTAssertFalse(board.isActivePhase)
        XCTAssertEqual(board.phasePlan.state, .draft)
        XCTAssertEqual(board.phasePlan.revision, 7)
        XCTAssertEqual(board.phasePlan.upcomingCount, 3)
        XCTAssertEqual(board.phasePlan.coveredUpcomingCount, 2)
        XCTAssertEqual(board.phasePlan.unassignedUpcomingCount, 1)
        XCTAssertFalse(board.phasePlan.isDeliveryComplete)
        XCTAssertEqual(board.deliveryGoals.map(\.goalID.rawValue), ["a", "z", "old"])
        XCTAssertEqual(board.filterableDeliveryGoals.map(\.goalID.rawValue), ["a", "z"])
        XCTAssertEqual(board.deliveryGoals[0].doneCriteria, ["First outcome is verified"])
        XCTAssertEqual(board.deliveryGoals[0].ticketIDs.map(\.rawValue), ["r1"])
        let detail = try XCTUnwrap(board.detail(for: .init(rawValue: "r1")))
        XCTAssertEqual(detail.deliveryGoal?.goalID.rawValue, "a")
        XCTAssertEqual(detail.deliveryGoal?.lifecycle, .draft)
        XCTAssertEqual(detail.codexExecutionGoal.linkQuality, .unavailable)
        XCTAssertEqual(detail.codexExecutionGoal, detail.goalContext)
        let filtered = board.filtered(by: .goal(.init(rawValue: "a")))
        XCTAssertEqual(filtered.lanes.map(\.lane), TicketLane.allCases)
        XCTAssertEqual(filtered.lanes.map(\.count), [1, 0, 0, 0, 0])
        XCTAssertEqual(filtered.lane(.backlog)?.cards.first?.activeTaskCount, 1)
        XCTAssertEqual(filtered.detail(for: .init(rawValue: "r1")), detail)
        XCTAssertNil(filtered.detail(for: .init(rawValue: "r2")))
        XCTAssertEqual(filtered.phasePlan, board.phasePlan, "Filtering must not change plan coverage")
        XCTAssertEqual(board.filtered(by: .unassigned).lanes.map(\.count), [1, 0, 0, 0, 0])
        XCTAssertEqual(board.filtered(by: .goal(.init(rawValue: "absent"))).lanes.map(\.count), [0, 0, 0, 0, 0])
        XCTAssertEqual(board.filtered(by: .all), board)
        let evidence = try XCTUnwrap(detail.evidence.first { $0.id.rawValue == "managed-evidence" })
        XCTAssertEqual(evidence.locator, .managedDocument(artifactID: "stable-artifact"))
        XCTAssertEqual(evidence.managedDocument?.failure, .bindingMissing)
        XCTAssertFalse(evidence.isAvailable)
        XCTAssertNotNil(EvidenceStatusPresentation(evidence).recovery)
        XCTAssertEqual(detail.evidence.first { $0.id.rawValue == "legacy-evidence" }?.path, "/synthetic/missing.md")
        let legacy = try XCTUnwrap(projection.board(for: .init(rawValue: "no-active"), phaseID: .init(rawValue: "legacy")))
        XCTAssertEqual(legacy.phasePlan.state, .legacyUnassessed)
        XCTAssertEqual(legacy.phasePlan.unassignedUpcomingCount, 1)
        XCTAssertEqual(legacy.phasePlan.coveredUpcomingCount, 0)
        XCTAssertFalse(legacy.detail(for: .init(rawValue: "legacy-work"))?.isLegacyContinuation == true,
                       "Legacy phase membership alone cannot grant continuation")
        XCTAssertNil(legacy.detail(for: .init(rawValue: "legacy-done"))?.deliveryGoal)
        let empty = try XCTUnwrap(projection.board(for: project, phaseID: .init(rawValue: "empty")))
        XCTAssertEqual(empty.phasePlan.upcomingCount, 0)
        XCTAssertFalse(empty.phasePlan.isDeliveryComplete)
        let after = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(after, before, "Loading and filtering are read-only")
        let failedTasks = try await DashboardProjection.load(from: store, taskRows: { connection, project, phase, ticket in
            if phase.rawValue == "roadmap" && (ticket == nil || ticket?.rawValue == "r1") {
                return try connection.rows("SELECT * FROM missing_task_projection_table")
            }
            return try TicketTaskPlanProjection.queryRows(connection, projectID: project, phaseID: phase, ticketID: ticket)
        })
        let failedBoard = try XCTUnwrap(failedTasks.board(for: project, phaseID: .init(rawValue: "roadmap")))
        guard case .unavailable? = failedBoard.detail(for: .init(rawValue: "r1"))?.taskPlan else { return XCTFail("Expected task recovery") }
        XCTAssertNil(failedBoard.lane(.backlog)?.cards.first?.activeTaskCount)
        XCTAssertEqual(failedBoard.detail(for: .init(rawValue: "r1"))?.evidence, detail.evidence)
        XCTAssertEqual(failedBoard.detail(for: .init(rawValue: "r2"))?.taskPlan, .noPlan)
        XCTAssertEqual(failedTasks.board(for: project), active)
    }

    func testReadyCompletedDeliveryRetainsRevisionAndSeparateExecutionContext() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        let project = DashboardSampleData.projectID
        let beforeProjection = try await DashboardProjection.load(from: store)
        let before = try XCTUnwrap(beforeProjection.board(for: project))
        let ticket = TicketID(rawValue: "VD2-07c")
        XCTAssertNotNil(before.detail(for: ticket)?.deliveryGoal)
        XCTAssertEqual(before.detail(for: ticket)?.codexExecutionGoal.status, "Blocked")
        try await store.transact(actor: .init(id: "fixture"), reason: "Completed projection snapshot") { c in
            try c.execute("UPDATE tickets SET lane='accepted' WHERE project_id='rekon-pursuit'")
        }
        let completedProjection = try await DashboardProjection.load(from: store)
        let completed = try XCTUnwrap(completedProjection.board(for: project))
        XCTAssertEqual(completed.phasePlan.state, .ready)
        XCTAssertEqual(completed.phasePlan.revision, before.phasePlan.revision)
        XCTAssertTrue(completed.phasePlan.isDeliveryComplete)
        XCTAssertEqual(completed.phasePlan.upcomingCount, 0)
        XCTAssertEqual(completed.phasePlan.coveredUpcomingCount, 0)
        XCTAssertEqual(completed.phasePlan.unassignedUpcomingCount, 0)
        XCTAssertEqual(completed.lane(.accepted)?.count, 31)
        XCTAssertEqual(completed.detail(for: ticket)?.codexExecutionGoal, before.detail(for: ticket)?.codexExecutionGoal)
    }

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
