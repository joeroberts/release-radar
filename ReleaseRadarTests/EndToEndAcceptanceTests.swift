import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class EndToEndAcceptanceTests: XCTestCase {
    func testTask11AV10MigrationIntegratesExactRoadmapTasksAndAcceptance() async throws {
        try await task11AIntegration(alreadyManaged: false)
    }

    func testTask11AManagedV13BaselineIntegratesWithoutLosingDocumentation() async throws {
        try await task11AIntegration(alreadyManaged: true)
    }

    private func task11AIntegration(alreadyManaged: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("RR-R10-Task11A-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        let root = directory.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.copyItem(at: fixtures.appendingPathComponent("RepositoryDocuments/valid"), to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let catalog = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let document = root.appendingPathComponent("docs/plans/draft.md")
        let documentBytes = try Data(contentsOf: document)
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let frozen = try Data(contentsOf: fixtures.appendingPathComponent("SchemaV10/release-radar-v10.sqlite"))
        XCTAssertEqual(SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined(),
                       "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559")
        try frozen.write(to: databaseURL)
        do {
            let c = try SQLiteConnection(url: databaseURL)
            XCTAssertEqual(try c.scalarInt("PRAGMA user_version"), 10)
            try c.executeScript("""
            INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('p','Release Radar',1),('other','Other',1);
            INSERT INTO phases (id,project_id,name) VALUES
                ('release-radar-post-mvp-remediation','p','Remediation'),('RR-ROADMAP','p','Established product'),
                ('other-phase','other','Other');
            INSERT INTO project_active_phases VALUES ('p','RR-ROADMAP');
            INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                ('RR-R10','p','release-radar-post-mvp-remediation','Deliver tasks and Delivery Goals','in_progress'),
                ('OTHER','other','other-phase','Preserve other project','needs_review');
            INSERT INTO audit_events (id,actor_id,reason,created_at) VALUES ('prior-audit','fixture','Preserve prior audit','2026-08-29T12:00:00Z');
            INSERT INTO agent_command_requests VALUES ('prior-request',X'00',X'01','2026-08-29T12:00:00Z');
            INSERT INTO notification_events (id,fingerprint,state,project_id,ticket_id)
                VALUES ('prior-notification','prior','delivered','other','OTHER');
            INSERT INTO observed_threads (id,project_id,status,last_observed_at) VALUES ('thread','p','active','2026-08-29T12:00:00Z');
            INSERT INTO observed_goals (id,project_id,thread_id,status,text,last_observed_at) VALUES ('codex-goal','p','thread','active','Execution context','2026-08-29T12:00:00Z');
            INSERT INTO thread_links (id,project_id,ticket_id,thread_id) VALUES ('thread-link','p','RR-R10','thread');
            INSERT INTO ticket_goal_links (id,project_id,ticket_id,thread_id,goal_id) VALUES ('goal-link','p','RR-R10','thread','codex-goal');
            """)
            for number in 1...9 {
                try c.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','release-radar-post-mvp-remediation',?,'accepted')",
                              bindings: [.text("RR-R\(number)"), .text("Accepted historical outcome \(number)")])
            }
            for number in 1...11 {
                try c.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','RR-ROADMAP',?,?)",
                              bindings: [.text("RR-RM\(number)"), .text("Roadmap outcome \(number)"),
                                         .text([6, 8, 11].contains(number) ? "blocked" : "backlog")])
            }
            try c.execute("INSERT INTO ticket_dependencies VALUES ('dependency','p','RR-RM6','RR-RM5')")
            try c.execute("INSERT INTO blockers (id,project_id,ticket_id,summary) VALUES ('blocker','p','RR-RM8','Owner decision')")
            try c.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root','p',?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data) VALUES ('p',?,X'01')", bindings: [.text(root.path)])
            try c.execute("INSERT INTO evidence (id,project_id,ticket_id,path,is_available) VALUES ('legacy-evidence','p','RR-R10',?,1)",
                          bindings: [.text(root.appendingPathComponent("AGENTS.md").path)])
            if alreadyManaged {
                // Same recognized-v13 fixture convention as Task 7/7A. The real
                // v11 migration alone grants continuation; never seed that flag.
                try StoreMigrations.migrate(c)
                let historical = try SQLiteConnection(url: fixtures.appendingPathComponent("SchemaV11/release-radar-v11.sqlite"), immutableReadOnly: true)
                let eventSQL = try XCTUnwrap(historical.scalarText("SELECT sql FROM sqlite_schema WHERE name='delivery_goal_assignment_events'"))
                try c.executeScript("""
                DROP TABLE delivery_goal_assignment_events;
                \(eventSQL);
                CREATE UNIQUE INDEX delivery_goal_assignment_events_ticket_revision_unique
                    ON delivery_goal_assignment_events(project_id,phase_id,ticket_id,revision);
                PRAGMA user_version=13;
                INSERT INTO evidence (id,project_id,ticket_id,artifact_id,is_available)
                    VALUES ('managed-evidence','p','RR-R10','draft',1);
                """)
                try c.execute("""
                INSERT INTO project_documentation_bindings
                    (project_id,root_id,repository_id,accepted_catalog_version,accepted_catalog_digest,accepted_catalog)
                    VALUES ('p','root',?,?,?,?)
                """, bindings: [.text(catalog.catalog.repositoryID), .integer(Int64(catalog.version)),
                                 .text(catalog.digest), .blob(catalog.canonicalCatalog)])
                XCTAssertTrue(try StoreMigrations.recognizesDocumentationPreflightSchema(c, version: 13))
            }
            XCTAssertNil(try c.row("PRAGMA foreign_key_check"))
        }
        let sourceRows = try Self.bootstrapRows(try SQLiteConnection(url: databaseURL, immutableReadOnly: true))
        let bookmarks = ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: false) },
                                            startAccessing: { _ in true }, stopAccessing: { _ in })
        let query = AgentQueryEnvelope(version: 1, projectRoot: root.path, query: .inventoryEvidence(projectID: "p", rootID: "root"))
        var managedBefore: EvidenceInventory?
        if alreadyManaged {
            let readOnly = try DeliveryStore(existingReadOnlyDatabaseURL: databaseURL)
            let result = await AgentQueryDispatcher(store: readOnly, bookmarkStore: bookmarks).dispatch(query)
            managedBefore = try XCTUnwrap(result.inventory)
            XCTAssertTrue(managedBefore?.isComplete == true)
        }
        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability
        XCTAssertEqual(availability, .available)
        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL), immutableReadOnly: true)
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), alreadyManaged ? 13 : 10)
        XCTAssertEqual(try Self.bootstrapRows(snapshot), sourceRows)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL, immutableReadOnly: true).scalarInt("PRAGMA user_version"), 14)
        let migrated = try await store.read { c in
            (try c.scalarInt("SELECT COUNT(*) FROM ticket_task_plans"),
             try c.scalarInt("SELECT COUNT(*) FROM delivery_goals"),
             try c.scalarInt("SELECT plan_legacy_continuation FROM tickets WHERE id='RR-R10'"),
             try c.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id='p' AND id<>'RR-R10' AND plan_legacy_continuation<>0"))
        }
        XCTAssertEqual(migrated.0, 0); XCTAssertEqual(migrated.1, 0)
        XCTAssertEqual(migrated.2, 1); XCTAssertEqual(migrated.3, 0)
        let registry = InMemoryAuthorizedProjectRegistry(projects: [.init(projectID: .init(rawValue: "p"), canonicalRoot: root, authorizedRoots: [root])])
        let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: registry, bookmarkStore: bookmarks)
        var requests: [(AgentCommandEnvelope, AgentCommandResult)] = []
        func request(_ command: AgentCommand) -> AgentCommandEnvelope {
            .init(version: 1, requestID: UUID(), projectRoot: root.path, assertedThreadID: "task-11a-synthetic",
                  reason: "Verify Task 11A integration", command: command)
        }
        func succeed(_ command: AgentCommand) async throws -> AgentCommandResult {
            let envelope = request(command)
            let result = await dispatcher.dispatch(envelope)
            XCTAssertNil(result.error, "\(command)")
            _ = try XCTUnwrap(result.auditEventID)
            requests.append((envelope, result))
            return result
        }
        func reject(_ command: AgentCommand) async throws -> AgentCommandError {
            let before = try await store.read { try Self.bootstrapRows($0) }
            let result = await dispatcher.dispatch(request(command))
            let error = try XCTUnwrap(result.error, "Must reject \(command)")
            XCTAssertNil(result.auditEventID)
            let after = try await store.read { try Self.bootstrapRows($0) }
            XCTAssertEqual(after, before, "Rejected command must have no durable effects")
            return error
        }
        if !alreadyManaged {
            let target = DocumentationTarget(projectID: "p", rootID: "root", repositoryID: catalog.catalog.repositoryID,
                                             catalogVersion: catalog.version, catalogDigest: catalog.digest)
            _ = try await succeed(.bindDocumentationRepository(target: target))
            _ = try await succeed(.addManagedEvidence(target: target, id: "managed-evidence", ticketID: "RR-R10", artifactID: "draft"))
        }
        let inventoryResult = await AgentQueryDispatcher(store: store, bookmarkStore: bookmarks).dispatch(query)
        let inventory = try XCTUnwrap(inventoryResult.inventory)
        XCTAssertTrue(inventory.isComplete)
        XCTAssertEqual(inventory.evidence.count, 2)
        XCTAssertTrue(inventory.evidence.allSatisfy(\.resolvedAvailable))
        if let managedBefore {
            XCTAssertEqual(inventory.preservation, managedBefore.preservation)
            XCTAssertEqual(inventory.evidence, managedBefore.evidence)
            XCTAssertEqual(inventory.binding, managedBefore.binding)
            XCTAssertEqual(inventory.audits, managedBefore.audits)
            XCTAssertEqual(inventory.receipts, managedBefore.receipts)
        }
        let baseline = try await store.read { try Self.bootstrapRows($0) }
        let additions: [TicketTaskDraft] = [
            .init(id: .init(rawValue: "integrate"), label: "Integration", title: "Integrate delivery contracts", sortOrder: 0),
            .init(id: .init(rawValue: "verify"), label: "Verification", title: "Verify exact acceptance", sortOrder: 1),
            .init(id: .init(rawValue: "stage"), label: "Staging", title: "Stage release candidate", sortOrder: 2),
        ]
        let created = try await succeed(.reviseTicketTaskPlan(ticketID: "RR-R10", additions: additions))
        XCTAssertEqual(created.ticketTaskPlanRevision, 1)
        let born = try await store.read { try $0.rows("SELECT lifecycle,completion FROM ticket_tasks ORDER BY sort_order") }
        XCTAssertEqual(born, Array(repeating: ["lifecycle": .text("active"), "completion": .text("pending")], count: 3))

        let roadmap: [(String, String, [String])] = [
            ("RR-DG1", "Coherent owner planning and navigation", ["RR-RM1", "RR-RM2", "RR-RM10"]),
            ("RR-DG2", "Portable project continuity", ["RR-RM5", "RR-RM6"]),
            ("RR-DG3", "Truthful supported Codex visibility", ["RR-RM7"]),
            ("RR-DG4", "Production-quality macOS release", ["RR-RM3", "RR-RM4", "RR-RM9"]),
            ("RR-DG5", "iPhone-companion scope decision", ["RR-RM8"]),
            ("RR-DG6", "Role-agent workflow decision", ["RR-RM11"]),
        ]
        for phase in ["release-radar-post-mvp-remediation", "RR-ROADMAP"] {
            let goals: [DeliveryGoalDraft]
            let assignments: [DeliveryGoalAssignment]
            if phase == "RR-ROADMAP" {
                goals = roadmap.enumerated().map { index, row in
                    .init(id: .init(rawValue: row.0), title: row.1, outcome: "Deliver \(row.1.lowercased()).",
                          doneCriteria: ["Every assigned roadmap ticket has its owner-approved outcome accepted."], sortOrder: index)
                }
                assignments = roadmap.flatMap { row in row.2.map { .init(goalID: .init(rawValue: row.0), ticketID: .init(rawValue: $0)) } }
            } else {
                goals = [.init(id: .init(rawValue: "RR-DG-R10"), title: "Delivery Goals and ticket tasks",
                               outcome: "Deliver first-class per-ticket tasks, phase-scoped Delivery Goals and exact roadmap readiness.",
                               doneCriteria: ["Exact task acceptance is enforced.", "All seven goals and exact roadmap assignments persist."], sortOrder: 0)]
                assignments = [.init(goalID: .init(rawValue: "RR-DG-R10"), ticketID: .init(rawValue: "RR-R10"))]
            }
            let revised = try await succeed(.applyPhasePlanRevision(projectID: "p", phaseID: phase, expectedRevision: 0,
                                                                  goalUpserts: goals, assignments: assignments))
            XCTAssertEqual(revised.phasePlanRevision, 1)
            let finalized = try await succeed(.finalizePhasePlan(projectID: "p", phaseID: phase, expectedRevision: 1))
            XCTAssertEqual(finalized.phasePlanRevision, 1)
        }
        let planned = try await store.read { try Self.bootstrapRows($0) }
        let expectedAssignments: Set<String> = [
            "RR-DG-R10|RR-R10", "RR-DG1|RR-RM1", "RR-DG1|RR-RM2", "RR-DG1|RR-RM10",
            "RR-DG2|RR-RM5", "RR-DG2|RR-RM6", "RR-DG3|RR-RM7", "RR-DG4|RR-RM3",
            "RR-DG4|RR-RM4", "RR-DG4|RR-RM9", "RR-DG5|RR-RM8", "RR-DG6|RR-RM11",
        ]
        let actualAssignments = try await store.read { c in
            try c.rows("SELECT goal_id || '|' || ticket_id AS pair FROM delivery_goal_ticket_assignments").compactMap { row -> String? in
                guard case let .text(value) = row["pair"] else { return nil }; return value
            }
        }
        XCTAssertEqual(Set(actualAssignments), expectedAssignments)
        XCTAssertEqual(actualAssignments.count, 12, "Disjoint exact assignments, no accepted-history backfill")
        XCTAssertEqual(planned["delivery_goals"]?.count, 7)
        let adoption = try await store.read { c in
            (try c.scalarInt("SELECT COUNT(*) FROM delivery_goals WHERE id='RR-DG-R10' AND lifecycle='active' AND activated_at IS NOT NULL"),
             try c.scalarInt("SELECT COUNT(*) FROM delivery_goals WHERE phase_id='RR-ROADMAP' AND lifecycle='planned' AND activated_at IS NULL"),
             try c.scalarInt("SELECT plan_legacy_continuation FROM tickets WHERE id='RR-R10'"),
             try c.scalarInt("SELECT COUNT(*) FROM phase_plans WHERE project_id='p' AND state='ready' AND revision=1 AND ready_revision=1"))
        }
        XCTAssertEqual(adoption.0, 1); XCTAssertEqual(adoption.1, 6); XCTAssertEqual(adoption.2, 0); XCTAssertEqual(adoption.3, 2)
        let preservedTables = ["projects", "project_active_phases", "ticket_dependencies", "blockers", "observed_threads",
                               "observed_goals", "thread_links", "ticket_goal_links", "notification_events", "notification_occurrences",
                               "project_documentation_bindings", "project_roots", "project_bookmarks", "evidence", "codex_plugin_lifecycle"]
        for table in preservedTables { XCTAssertEqual(planned[table], baseline[table], table) }
        let oldTickets = try XCTUnwrap(baseline["tickets"])
        for old in oldTickets {
            let current = try XCTUnwrap(planned["tickets"]?.first { $0["id"] == old["id"] })
            XCTAssertEqual(current.filter { $0.key != "plan_legacy_continuation" }, old.filter { $0.key != "plan_legacy_continuation" })
        }

        _ = try await succeed(.requestReview(id: "review", ticketID: "RR-R10", kind: "review", summary: "Review integrated delivery"))
        _ = try await succeed(.transitionTicket(ticketID: "RR-R10", lane: .needsReview))
        let incomplete = try await reject(.transitionTicket(ticketID: "RR-R10", lane: .accepted, ticketTaskPlanRevision: 1))
        // Accepted transitions retain their pre-Task-4B error envelope; the new
        // structured task errors belong only to the two task mutation commands.
        XCTAssertEqual(incomplete, .internalFailure("Complete every active ticket task before accepting the ticket."))
        for ticket in ["RR-R10", "RR-R1", "new-accepted"] {
            _ = try await reject(.upsertTicket(ticketID: ticket, phaseID: "release-radar-post-mvp-remediation", outcome: "Reject bypass", lane: .accepted))
        }
        var revision: Int64 = 1
        for (index, task) in additions.enumerated() {
            let completed = try await succeed(.completeTicketTask(ticketID: "RR-R10", taskID: task.id.rawValue, expectedRevision: revision))
            revision = try XCTUnwrap(completed.ticketTaskPlanRevision)
            XCTAssertEqual(revision, Int64(index + 2))
        }
        let tasksCompleted = try await store.read { try Self.bootstrapRows($0) }
        XCTAssertEqual(tasksCompleted["phase_plans"], planned["phase_plans"])
        XCTAssertEqual(tasksCompleted["delivery_goals"], planned["delivery_goals"])
        let noAutomaticAcceptance = try await store.read { try $0.scalarText("SELECT lane FROM tickets WHERE id='RR-R10'") }
        XCTAssertEqual(noAutomaticAcceptance, "needs_review")
        _ = try await reject(.transitionTicket(ticketID: "RR-R10", lane: .accepted))
        let stale = try await reject(.transitionTicket(ticketID: "RR-R10", lane: .accepted, ticketTaskPlanRevision: 3))
        XCTAssertEqual(stale, .internalFailure("The ticket task plan changed. Refresh it before retrying."))
        _ = try await succeed(.recordCompletion(id: "completion", ticketID: "RR-R10", summary: "Integration verified"))
        _ = try await succeed(.transitionTicket(ticketID: "RR-R10", lane: .accepted, ticketTaskPlanRevision: revision))
        for lane in TicketLane.allCases where lane != .accepted {
            _ = try await reject(.transitionTicket(ticketID: "RR-R10", lane: lane, ticketTaskPlanRevision: revision))
            _ = try await reject(.transitionTicket(ticketID: "RR-R1", lane: lane))
            for ticket in ["RR-R10", "RR-R1"] {
                _ = try await reject(.upsertTicket(ticketID: ticket, phaseID: "release-radar-post-mvp-remediation", outcome: "Reject reopening", lane: lane))
            }
        }
        _ = try await reject(.reviseTicketTaskPlan(ticketID: "RR-R10", expectedRevision: revision, additions: [.init(id: .init(rawValue: "reopen"), label: "Reopen", title: "Reject accepted plan changes", sortOrder: 3)]))

        // The other command writer must invalidate both sides of a Backlog
        // phase move. New work cannot inherit migration continuation/readiness.
        _ = try await succeed(.upsertTicket(ticketID: "new-work", phaseID: "RR-ROADMAP", outcome: "New work", lane: .backlog))
        _ = try await reject(.transitionTicket(ticketID: "new-work", lane: .inProgress))
        _ = try await reject(.requestReview(id: "new-review", ticketID: "new-work", kind: "review", summary: "Cannot skip start"))
        _ = try await reject(.recordCompletion(id: "new-completion", ticketID: "new-work", summary: "Cannot skip start"))
        _ = try await succeed(.upsertTicket(ticketID: "new-work", phaseID: "release-radar-post-mvp-remediation", outcome: "Moved work", lane: .backlog))
        let moved = try await store.read { c in
            (try c.scalarInt("SELECT COUNT(*) FROM phase_plans WHERE project_id='p' AND state='draft'"),
             try c.scalarText("SELECT phase_id || '|' || lane || '|' || plan_legacy_continuation FROM tickets WHERE id='new-work'"))
        }
        XCTAssertEqual(moved.0, 2)
        XCTAssertEqual(moved.1, "release-radar-post-mvp-remediation|backlog|0")
        let committed = try await store.read { try Self.bootstrapRows($0) }
        let relaunched = DeliveryStore(databaseURL: databaseURL)
        let replayDispatcher = AgentCommandDispatcher(store: relaunched, projectRegistry: registry, bookmarkStore: bookmarks)
        for (envelope, result) in requests {
            let replay = await replayDispatcher.dispatch(envelope)
            XCTAssertEqual(replay, result)
        }
        let replayRows = try await relaunched.read { try Self.bootstrapRows($0) }
        XCTAssertEqual(replayRows, committed)
        let finalResult = await AgentQueryDispatcher(store: relaunched, bookmarkStore: bookmarks).dispatch(query)
        let finalInventory = try XCTUnwrap(finalResult.inventory)
        XCTAssertTrue(finalInventory.isComplete)
        XCTAssertEqual(finalInventory.evidence, inventory.evidence)
        XCTAssertEqual(finalInventory.binding, inventory.binding)
        XCTAssertEqual(finalInventory.roots, inventory.roots)
        for fingerprint in inventory.audits { XCTAssertTrue(finalInventory.audits.contains(fingerprint)) }
        for fingerprint in inventory.receipts { XCTAssertTrue(finalInventory.receipts.contains(fingerprint)) }
        for table in preservedTables where !["notification_events", "notification_occurrences"].contains(table) {
            XCTAssertEqual(committed[table], baseline[table], table)
        }
        for row in baseline["notification_events"] ?? [] {
            XCTAssertTrue(committed["notification_events"]?.contains(row) == true)
        }
        XCTAssertEqual(try Data(contentsOf: document), documentBytes)
        XCTAssertEqual(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root).digest, catalog.digest)
        let projection = try await DashboardProjection.load(from: relaunched)
        let board = try XCTUnwrap(projection.board(for: .init(rawValue: "p"), phaseID: .init(rawValue: "release-radar-post-mvp-remediation")))
        let card = try XCTUnwrap(board.lane(.accepted)?.cards.first { $0.id.rawValue == "RR-R10" })
        XCTAssertEqual(card.activeTaskCount, 3)
        guard case let .loaded(plan)? = board.detail(for: .init(rawValue: "RR-R10"))?.taskPlan else {
            return XCTFail("Expected persisted completed task projection")
        }
        XCTAssertEqual(plan.revision, 4)
        XCTAssertEqual(plan.tasks.map(\.id.rawValue), ["integrate", "verify", "stage"])
        XCTAssertTrue(plan.tasks.allSatisfy { $0.completion == .completed })
    }

    func testTask11ASampleAndDebugWritersCreateGovernedPlansWithoutLegacyContinuation() async throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("RR-R10-Task11A-Writers-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for sample in [true, false] {
            let store = DeliveryStore(databaseURL: directory.appendingPathComponent(sample ? "sample.sqlite" : "debug.sqlite"))
            if sample { try await DashboardSampleData.seedIfNeeded(in: store) }
            else { try await RR9ActivePhaseCaptureFixture.seedIfNeeded(in: store, rootDirectory: directory.appendingPathComponent("roots"), scenario: .happy) }
            let first = try await store.read { try Self.bootstrapRows($0) }
            let state = try await store.read { c in
                (try c.scalarInt("SELECT COUNT(*) FROM tickets"),
                 try c.scalarInt("SELECT COUNT(*) FROM tickets WHERE lane='accepted'"),
                 try c.scalarInt("SELECT COUNT(*) FROM tickets WHERE plan_legacy_continuation<>0"),
                 try c.scalarInt("SELECT COUNT(*) FROM ticket_task_plans"),
                 try c.scalarInt("SELECT COUNT(*) FROM tickets t LEFT JOIN delivery_goal_ticket_assignments a ON a.project_id=t.project_id AND a.phase_id=t.phase_id AND a.ticket_id=t.id WHERE a.ticket_id IS NULL"),
                 try c.scalarInt("SELECT COUNT(*) FROM phase_plans p WHERE EXISTS (SELECT 1 FROM tickets t WHERE t.project_id=p.project_id AND t.phase_id=p.phase_id) AND (p.state<>'ready' OR p.ready_revision<>p.revision)"))
            }
            XCTAssertGreaterThan(state.0 ?? 0, 0); XCTAssertGreaterThan(state.1 ?? 0, 0)
            XCTAssertEqual(state.2, 0); XCTAssertEqual(state.3, 0); XCTAssertEqual(state.4, 0); XCTAssertEqual(state.5, 0)
            if sample { try await DashboardSampleData.seedIfNeeded(in: store) }
            else { try await RR9ActivePhaseCaptureFixture.seedIfNeeded(in: store, rootDirectory: directory.appendingPathComponent("roots"), scenario: .happy) }
            let second = try await store.read { try Self.bootstrapRows($0) }
            XCTAssertEqual(second, first, "Writer re-entry must not rewrite delivery history")
        }
    }

    func testTask7ABootstrapPreservesManagedV13MigrationLineageAndReplaysThroughTask7() async throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("RR-R10-Task7A-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        let root = directory.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.copyItem(at: fixtures.appendingPathComponent("RepositoryDocuments/valid"), to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let catalog = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let frozen = try Data(contentsOf: fixtures.appendingPathComponent("SchemaV10/release-radar-v10.sqlite"))
        XCTAssertEqual(SHA256.hash(data: frozen).map { String(format: "%02x", $0) }.joined(),
                       "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559")
        try frozen.write(to: databaseURL)
        do {
            let c = try SQLiteConnection(url: databaseURL)
            XCTAssertEqual(try c.scalarInt("PRAGMA user_version"), 10)
            try c.executeScript("""
            INSERT INTO projects (id,name) VALUES ('project-1','Release Radar'),('other','Unrelated');
            INSERT INTO phases (id,project_id,name) VALUES ('phase-1','project-1','Roadmap'),('other-phase','other','Other');
            INSERT INTO project_active_phases VALUES ('project-1','phase-1');
            INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                ('RR-R10','project-1','phase-1','Delivery Goals and task tracking','in_progress'),
                ('history','project-1','phase-1','Retain assignment history','backlog'),
                ('unrelated','other','other-phase','Preserve other project','needs_review');
            INSERT INTO audit_events (id,actor_id,reason,created_at) VALUES ('prior-audit','fixture','Existing history','2026-08-29T12:00:00Z');
            INSERT INTO notification_events (id,fingerprint,state,project_id,ticket_id) VALUES ('prior-notification','prior','delivered','other','unrelated');
            INSERT INTO agent_command_requests VALUES ('prior-request',X'00',X'01','2026-08-29T12:00:00Z');
            """)
            try c.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root-1','project-1',?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id,path,bookmark_data) VALUES ('project-1',?,X'01')", bindings: [.text(root.path)])
            // The shipped v11 migration, starting from the genuine v10 schema,
            // is the only operation that grants either ticket continuation.
            try StoreMigrations.migrate(c)
            XCTAssertEqual(try c.scalarInt("SELECT plan_legacy_continuation FROM tickets WHERE id='RR-R10'"), 1)
            let historical = try SQLiteConnection(url: fixtures.appendingPathComponent("SchemaV11/release-radar-v11.sqlite"), immutableReadOnly: true)
            let eventSQL = try XCTUnwrap(historical.scalarText("SELECT sql FROM sqlite_schema WHERE name='delivery_goal_assignment_events'"))
            // Existing Task 7 fixture convention: restore only the historical
            // event-table shape, then require genuine v13 schema recognition.
            // Ticket rows and their migration lineage are never rewritten.
            try c.executeScript("""
            BEGIN EXCLUSIVE;
            DROP TABLE delivery_goal_assignment_events;
            \(eventSQL);
            CREATE UNIQUE INDEX delivery_goal_assignment_events_ticket_revision_unique
                ON delivery_goal_assignment_events(project_id,phase_id,ticket_id,revision);
            PRAGMA user_version=13;
            COMMIT;
            INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at)
                VALUES ('project-1','phase-1','historical-goal','Retain goal','Preserve history','draft',0,'2026-08-29T12:00:00Z','2026-08-29T12:00:00Z');
            INSERT INTO delivery_goal_assignment_events
                (audit_event_id,project_id,phase_id,ticket_id,previous_goal_id,current_goal_id,revision,action)
                VALUES ('prior-audit','project-1','phase-1','history',NULL,'historical-goal',1,'assigned');
            INSERT INTO evidence (id,project_id,ticket_id,artifact_id,is_available)
                VALUES ('managed-evidence','project-1','RR-R10','draft',1);
            """)
            try c.execute("""
            INSERT INTO project_documentation_bindings
                (project_id,root_id,repository_id,accepted_catalog_version,accepted_catalog_digest,accepted_catalog)
                VALUES ('project-1','root-1',?,?,?,?)
            """, bindings: [.text(catalog.catalog.repositoryID), .integer(Int64(catalog.version)),
                             .text(catalog.digest), .blob(catalog.canonicalCatalog)])
            XCTAssertTrue(try StoreMigrations.recognizesDocumentationPreflightSchema(c, version: 13))
            XCTAssertNil(try c.row("PRAGMA foreign_key_check"))
        }
        let bookmarkStore = ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: false) },
                                                startAccessing: { _ in true }, stopAccessing: { _ in })
        let query = AgentQueryEnvelope(version: 1, projectRoot: root.path,
                                       query: .inventoryEvidence(projectID: "project-1", rootID: "root-1"))
        let baseline = try Self.bootstrapRows(try SQLiteConnection(url: databaseURL, immutableReadOnly: true))
        let preflight = try DeliveryStore(existingReadOnlyDatabaseURL: databaseURL)
        let priorResult = await AgentQueryDispatcher(store: preflight, bookmarkStore: bookmarkStore).dispatch(query)
        let prior = try XCTUnwrap(priorResult.inventory)
        XCTAssertTrue(prior.isComplete)
        XCTAssertEqual(prior.schemaVersion, 13)

        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability
        XCTAssertEqual(availability, .available)
        let migrated = try await store.read { try Self.bootstrapRows($0) }
        XCTAssertEqual(migrated, baseline, "v14 migration must preserve every existing row")
        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL), immutableReadOnly: true)
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 13)
        XCTAssertEqual(try Self.bootstrapRows(snapshot), baseline)
        let postMigration = await AgentQueryDispatcher(store: store, bookmarkStore: bookmarkStore).dispatch(query)
        XCTAssertEqual(postMigration.inventory?.schemaVersion, 14)
        XCTAssertEqual(postMigration.inventory?.preservation, prior.preservation)
        XCTAssertEqual(postMigration.inventory?.evidence, prior.evidence)
        XCTAssertEqual(postMigration.inventory?.binding, prior.binding)
        XCTAssertTrue(postMigration.inventory?.isComplete == true)

        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: .init(rawValue: "project-1"), canonicalRoot: root, authorizedRoots: [root]),
        ])
        let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: registry)
        let catalogRows: [(String, String)] = [
            ("1A", "Generate and verify the genuine schema-v10 fixture"),
            ("1B", "Add schema-v11 persistence and public models"),
            ("2A", "Generate and verify the genuine schema-v11 fixture"),
            ("2B", "Add schema-v12 ticket-task persistence and models"),
            ("3", "Enforce ticket-task revisions and acceptance"),
            ("4A", "Guard every Accepted path"),
            ("4B", "Expose audited ticket-task commands"),
            ("5", "Present ticket tasks on cards and Ticket Details"),
            ("6", "Enforce Delivery Goal plan and lifecycle rules"),
            ("7", "Route every ticket writer and compose planning policy"),
            ("7A", "Install and bootstrap live RR-R10 task tracking"),
            ("8", "Expose audited Delivery Goal commands"),
            ("9", "Project Delivery Goals, Activity, and owner review"),
            ("10", "Present non-mutating phase browsing and Delivery Goals"),
            ("11A", "Integrate and stage the release candidate"),
            ("11B", "Install and verify the final RR-R10 outcome"),
        ]
        let additions = catalogRows.enumerated().map { index, row in
            TicketTaskDraft(id: .init(rawValue: "rr-r10-task-" + row.0.lowercased()),
                            label: "Task " + row.0, title: row.1, sortOrder: index)
        }
        func request(_ command: AgentCommand) -> AgentCommandEnvelope {
            .init(version: 1, requestID: UUID(), projectRoot: root.path,
                  assertedThreadID: "task-7a-integration", reason: "Verify explicit Task 7A bootstrap", command: command)
        }
        let create = request(.reviseTicketTaskPlan(ticketID: "RR-R10", additions: additions))
        let created = await dispatcher.dispatch(create)
        XCTAssertNil(created.error)
        var revision = try XCTUnwrap(created.ticketTaskPlanRevision)
        XCTAssertEqual(revision, 1)
        var requests = [(create, created)]
        let born = try await store.read { try $0.rows("SELECT lifecycle,completion FROM ticket_tasks ORDER BY sort_order") }
        XCTAssertEqual(born, Array(repeating: ["lifecycle": .text("active"), "completion": .text("pending")], count: 16))
        for (index, task) in additions.prefix(10).enumerated() {
            let envelope = request(.completeTicketTask(ticketID: "RR-R10", taskID: task.id.rawValue, expectedRevision: revision))
            let result = await dispatcher.dispatch(envelope)
            XCTAssertNil(result.error)
            revision = try XCTUnwrap(result.ticketTaskPlanRevision)
            XCTAssertEqual(revision, Int64(index + 2))
            XCTAssertNotNil(result.auditEventID)
            requests.append((envelope, result))
        }
        let committed = try await store.read { try Self.bootstrapRows($0) }
        let changed = Set(["ticket_task_plans", "ticket_tasks", "audit_events", "agent_command_requests"])
        XCTAssertEqual(committed.filter { !changed.contains($0.key) }, baseline.filter { !changed.contains($0.key) })
        XCTAssertEqual(committed["ticket_task_plans"]?.count, 1)
        XCTAssertEqual(committed["ticket_tasks"]?.count, 16)
        for table in ["audit_events", "agent_command_requests"] {
            XCTAssertEqual(committed[table]?.count, baseline[table]!.count + 11)
            for row in baseline[table]! { XCTAssertTrue(committed[table]!.contains(row)) }
        }
        let relaunched = DeliveryStore(databaseURL: databaseURL)
        let replayDispatcher = AgentCommandDispatcher(store: relaunched, projectRegistry: registry)
        for (envelope, result) in requests {
            let immediate = await dispatcher.dispatch(envelope)
            let replayed = await replayDispatcher.dispatch(envelope)
            XCTAssertEqual(immediate, result)
            XCTAssertEqual(replayed, result)
        }
        let replayRows = try await relaunched.read { try Self.bootstrapRows($0) }
        XCTAssertEqual(replayRows, committed)
        let projection = try await DashboardProjection.load(from: relaunched)
        let board = try XCTUnwrap(projection.board(for: .init(rawValue: "project-1")))
        let card = try XCTUnwrap(board.lane(.inProgress)?.cards.first { $0.id.rawValue == "RR-R10" })
        XCTAssertEqual(card.activeTaskCount, 16)
        guard case let .loaded(plan)? = board.detail(for: .init(rawValue: "RR-R10"))?.taskPlan else {
            return XCTFail("Expected the complete installed task projection")
        }
        XCTAssertEqual(plan.revision, 11)
        XCTAssertEqual(plan.tasks.map(\.id), additions.map(\.id))
        XCTAssertEqual(plan.tasks.map(\.label), additions.map(\.label))
        XCTAssertEqual(plan.tasks.map(\.title), additions.map(\.title))
        for (index, task) in plan.tasks.enumerated() {
            XCTAssertEqual(task.completion, index < 10 ? .completed : .pending)
            XCTAssertEqual(task.accessibilityLabel(position: index + 1, total: 16),
                           "\(additions[index].label): \(additions[index].title), \(index < 10 ? "checked" : "unchecked"), item \(index + 1) of 16")
        }
        XCTAssertEqual(plan.tasks[10].label, "Task 7A")
        XCTAssertEqual(plan.tasks[10].completion, .pending)
        let finalInventory = await AgentQueryDispatcher(store: relaunched, bookmarkStore: bookmarkStore).dispatch(query)
        XCTAssertTrue(finalInventory.inventory?.isComplete == true)
        XCTAssertEqual(finalInventory.inventory?.preservation.filter { $0.key != "project.tasksV12" },
                       prior.preservation.filter { $0.key != "project.tasksV12" })
        XCTAssertEqual(finalInventory.inventory?.evidence, prior.evidence)
        XCTAssertEqual(finalInventory.inventory?.roots, prior.roots)
    }

    private static func bootstrapRows(_ c: SQLiteConnection) throws -> [String: [[String: SQLiteValue]]] {
        var result: [String: [[String: SQLiteValue]]] = [:]
        for row in try c.rows("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name") {
            guard case let .text(table) = row["name"] else { continue }
            let rows = try c.rows("SELECT * FROM \"\(table)\"")
            result[table] = rows.sorted { lhs, rhs in
                String(reflecting: lhs.sorted { $0.key < $1.key })
                    < String(reflecting: rhs.sorted { $0.key < $1.key })
            }
        }
        return result
    }

    func testRelaunchRepairsVersionThreeDatabaseMissingAuditAttribution() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeVersionThreeAuditDrift(at: databaseURL)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        let availability = await relaunchedStore.availability
        XCTAssertEqual(availability, .available)
        try await relaunchedStore.transact(
            actor: .init(id: "rr10-recovery", threadID: "thread-recovery"),
            reason: "Verify repaired version three schema",
            auditScope: .init(
                projectID: .init(rawValue: "project-1"),
                entityType: .ticket,
                entityID: "RR-10"
            )
        ) { _ in }
        let repairedConnection = try SQLiteConnection(url: databaseURL)
        let repaired = (
            try repairedConnection.scalarInt("PRAGMA user_version"),
            try repairedConnection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
            try repairedConnection.scalarText("SELECT thread_attribution FROM audit_events WHERE reason = 'Verify repaired version three schema'")
        )
        XCTAssertEqual(repaired.0, StoreMigrations.currentVersion)
        XCTAssertEqual(repaired.1, 1)
        XCTAssertEqual(repaired.2, "asserted")

        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 3)
        XCTAssertEqual(
            try snapshot.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
            0
        )
    }

    func testRelaunchRepairsObservedVersionSevenOwnerSchemaDrift() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeObservedVersionSevenDrift(at: databaseURL)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        let availability = await relaunchedStore.availability
        XCTAssertEqual(availability, .available)
        let repairedConnection = try SQLiteConnection(url: databaseURL)
        let repaired = (
            try repairedConnection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name IN ('project_id', 'entity_type', 'entity_id')"),
            try repairedConnection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'")
        )
        XCTAssertEqual(repaired.0, 3)
        XCTAssertEqual(repaired.1, "phase-1")
        try await relaunchedStore.transact(
            actor: .init(id: "rr10-recovery"),
            reason: "Verify repaired version seven schema",
            auditScope: .init(
                projectID: .init(rawValue: "project-1"),
                entityType: .project,
                entityID: "project-1"
            )
        ) { _ in }

        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 7)
        XCTAssertEqual(
            try snapshot.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'project_active_phases'"),
            0
        )
        XCTAssertEqual(
            try snapshot.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name IN ('project_id', 'entity_type', 'entity_id')"),
            0
        )
    }

    func testVersionThreeCandidateMissingCoreTableFailsClosedWithoutMutation() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeVersionThreeAuditDrift(at: databaseURL)
        let malformed = try SQLiteConnection(url: databaseURL)
        try malformed.execute("DROP TABLE ticket_dependencies")

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await relaunchedStore.availability else {
            return XCTFail("Expected an incomplete version three schema to be unavailable")
        }
        XCTAssertEqual(recovery.kind, .migration)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        let original = try SQLiteConnection(url: databaseURL)
        let snapshot = try SQLiteConnection(url: snapshotURL)
        for connection in [original, snapshot] {
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 3)
            XCTAssertEqual(
                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-10'"),
                "Final integration"
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'ticket_dependencies'"),
                0
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
                0
            )
        }
    }

    func testVersionSevenCandidateMissingCoreTableFailsClosedWithoutMutation() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeObservedVersionSevenDrift(at: databaseURL)
        let malformed = try SQLiteConnection(url: databaseURL)
        try malformed.execute("DROP TABLE phase_dependencies")

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await relaunchedStore.availability else {
            return XCTFail("Expected an incomplete version seven schema to be unavailable")
        }
        XCTAssertEqual(recovery.kind, .migration)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        let original = try SQLiteConnection(url: databaseURL)
        let snapshot = try SQLiteConnection(url: snapshotURL)
        for connection in [original, snapshot] {
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 7)
            XCTAssertEqual(
                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-10'"),
                "Final integration"
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'phase_dependencies'"),
                0
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'project_id'"),
                0
            )
        }
    }

    func testVersionThreeCandidateWithCounterfeitCycleTriggerFailsClosedWithoutMutation() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeVersionThreeAuditDrift(at: databaseURL)
        let malformed = try SQLiteConnection(url: databaseURL)
        try malformed.executeScript("""
        DROP TRIGGER reject_phase_dependency_cycle_insert;
        CREATE TRIGGER reject_phase_dependency_cycle_insert
        AFTER INSERT ON phase_dependencies
        BEGIN
            SELECT 1;
        END;
        """)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await relaunchedStore.availability else {
            return XCTFail("Expected a counterfeit dependency trigger to make version three unavailable")
        }
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        for connection in [try SQLiteConnection(url: databaseURL), try SQLiteConnection(url: snapshotURL)] {
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 3)
            XCTAssertTrue(try XCTUnwrap(connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'trigger' AND name = 'reject_phase_dependency_cycle_insert'"
            )).contains("SELECT 1"))
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
                0
            )
        }
    }

    func testVersionThreeCandidateWithCommentSpoofedDisabledTriggerFailsClosedWithoutMutation() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        try makeVersionThreeAuditDrift(at: databaseURL)
        let malformed = try SQLiteConnection(url: databaseURL)
        try malformed.executeScript("""
        DROP TRIGGER reject_phase_dependency_cycle_insert;
        CREATE TRIGGER reject_phase_dependency_cycle_insert
        BEFORE INSERT ON phase_dependencies
        WHEN 0
        BEGIN
            /* with recursive dependency_path
               from phase_dependencies as dependency
               where dependency.project_id = new.project_id
               where phase_id = new.phase_id
               select raise(abort, 'phase dependency cycle') */
            SELECT 1;
        END;
        """)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await relaunchedStore.availability else {
            return XCTFail("Expected a comment-spoofed disabled trigger to make version three unavailable")
        }
        XCTAssertEqual(recovery.kind, .migration)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        for connection in [try SQLiteConnection(url: databaseURL), try SQLiteConnection(url: snapshotURL)] {
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 3)
            XCTAssertTrue(try XCTUnwrap(connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'trigger' AND name = 'reject_phase_dependency_cycle_insert'"
            )).contains("WHEN 0"))
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM pragma_table_info('audit_events') WHERE name = 'thread_attribution'"),
                0
            )
        }
    }

    func testCurrentSchemaWithWrongCriticalIndexFailsClosedWithoutMutation() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        let malformed = try SQLiteConnection(url: databaseURL)
        try malformed.executeScript("""
        DROP INDEX audit_events_project_entity_index;
        CREATE INDEX audit_events_project_entity_index ON audit_events(actor_id);
        """)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await relaunchedStore.availability else {
            return XCTFail("Expected a wrong-column critical index to make the current schema unavailable")
        }
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        for connection in [try SQLiteConnection(url: databaseURL), try SQLiteConnection(url: snapshotURL)] {
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), StoreMigrations.currentVersion)
            XCTAssertEqual(
                try connection.scalarText("SELECT name FROM pragma_index_info('audit_events_project_entity_index') ORDER BY seqno LIMIT 1"),
                "actor_id"
            )
        }
    }

    func testCurrentSchemaMissingCriticalForeignKeyFailsClosedWithoutMutation() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        store = nil
        let malformed = try SQLiteConnection(url: databaseURL)
        try malformed.executeScript("""
        PRAGMA foreign_keys = OFF;
        DROP INDEX project_active_phases_phase_index;
        ALTER TABLE project_active_phases RENAME TO malformed_active_phases;
        CREATE TABLE project_active_phases (
            project_id TEXT PRIMARY KEY NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            phase_id TEXT NOT NULL
        );
        INSERT INTO project_active_phases SELECT project_id, phase_id FROM malformed_active_phases;
        DROP TABLE malformed_active_phases;
        CREATE INDEX project_active_phases_phase_index ON project_active_phases(phase_id);
        PRAGMA foreign_keys = ON;
        """)

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await relaunchedStore.availability else {
            return XCTFail("Expected a missing project-boundary foreign key to make the current schema unavailable")
        }
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        for connection in [try SQLiteConnection(url: databaseURL), try SQLiteConnection(url: snapshotURL)] {
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), StoreMigrations.currentVersion)
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_list('project_active_phases') WHERE \"table\" = 'phases'"),
                0
            )
            XCTAssertEqual(
                try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'"),
                "phase-1"
            )
        }
    }

    private func seedProject(_ store: DeliveryStore) async throws {
        try await store.transact(actor: .init(id: "rr10-seed"), reason: "Seed recovery fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-10', 'project-1', 'phase-1', 'Final integration', 'in_progress')")
        }
    }

    private func makeVersionThreeAuditDrift(at databaseURL: URL) throws {
        let connection = try SQLiteConnection(url: databaseURL)
        try removePostVersionNineSchema(connection)
        try connection.executeScript("""
        DROP TABLE alert_rules;
        DROP TABLE ticket_goal_links;
        DROP INDEX observed_goals_project_identity_unique;
        DROP INDEX notification_events_project_created_index;
        DROP INDEX notification_events_state_index;
        DROP TABLE notification_occurrences;
        ALTER TABLE notification_events DROP COLUMN failure_code;
        ALTER TABLE notification_events DROP COLUMN completed_at;
        ALTER TABLE notification_events DROP COLUMN attempt_started_at;
        ALTER TABLE notification_events DROP COLUMN attempt_count;
        ALTER TABLE notification_events DROP COLUMN created_at;
        ALTER TABLE notification_events DROP COLUMN message;
        ALTER TABLE notification_events DROP COLUMN title;
        ALTER TABLE notification_events DROP COLUMN occurrence;
        ALTER TABLE notification_events DROP COLUMN subject_id;
        ALTER TABLE notification_events DROP COLUMN event_kind;
        ALTER TABLE notification_events DROP COLUMN project_id;
        DROP INDEX project_active_phases_phase_index;
        DROP TABLE project_active_phases;
        DROP INDEX audit_events_project_entity_index;
        ALTER TABLE audit_events DROP COLUMN entity_id;
        ALTER TABLE audit_events DROP COLUMN entity_type;
        ALTER TABLE audit_events DROP COLUMN project_id;
        ALTER TABLE audit_events DROP COLUMN thread_attribution;
        PRAGMA user_version = 3;
        """)
    }

    private func makeObservedVersionSevenDrift(at databaseURL: URL) throws {
        let connection = try SQLiteConnection(url: databaseURL)
        try removePostVersionNineSchema(connection)
        try connection.executeScript("""
        DROP TABLE alert_rules;
        DROP TABLE ticket_goal_links;
        DROP INDEX observed_goals_project_identity_unique;
        ALTER TABLE projects ADD COLUMN active_phase_id TEXT;
        UPDATE projects SET active_phase_id = 'phase-1' WHERE id = 'project-1';
        DROP INDEX project_active_phases_phase_index;
        DROP TABLE project_active_phases;
        DROP INDEX audit_events_project_entity_index;
        ALTER TABLE audit_events DROP COLUMN entity_id;
        ALTER TABLE audit_events DROP COLUMN entity_type;
        ALTER TABLE audit_events DROP COLUMN project_id;
        PRAGMA user_version = 7;
        """)
    }

    private func removePostVersionNineSchema(_ connection: SQLiteConnection) throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SchemaV10/release-radar-v10.sqlite")
        let historical = try SQLiteConnection(url: fixture, immutableReadOnly: true)
        let evidenceSQL = try XCTUnwrap(historical.scalarText("SELECT sql FROM sqlite_schema WHERE name='evidence'"))
        try connection.executeScript("""
        DROP TABLE project_documentation_bindings;
        DROP INDEX project_roots_project_identity_unique;
        ALTER TABLE evidence RENAME TO current_evidence;
        \(evidenceSQL);
        INSERT INTO evidence (id,project_id,ticket_id,path,is_available)
            SELECT id,project_id,ticket_id,path,is_available FROM current_evidence;
        DROP TABLE current_evidence;
        DROP TRIGGER ticket_task_plans_reject_project_delete;
        DROP TRIGGER ticket_task_plans_reject_ticket_delete;
        DROP TRIGGER ticket_tasks_reject_delete;
        DROP TRIGGER ticket_task_plans_reject_delete;
        DROP TRIGGER ticket_tasks_reject_label_update;
        DROP TRIGGER ticket_tasks_reject_identity_update;
        DROP TABLE ticket_tasks;
        DROP TABLE ticket_task_plans;
        DROP TRIGGER tickets_reject_legacy_continuation_regrant;
        DROP TRIGGER tickets_reject_legacy_continuation_insert;
        DROP TRIGGER phase_plans_after_phase_insert;
        DROP TABLE delivery_goal_assignment_events;
        DROP TABLE delivery_goal_ticket_assignments;
        DROP TABLE delivery_goal_done_criteria;
        DROP TABLE delivery_goals;
        DROP TABLE phase_plans;
        DROP INDEX tickets_project_phase_identity_unique;
        ALTER TABLE tickets DROP COLUMN plan_legacy_continuation;
        DROP TABLE codex_plugin_lifecycle;
        """)
    }

    private func makeDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarEndToEndTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("release-radar.sqlite")
    }
}
