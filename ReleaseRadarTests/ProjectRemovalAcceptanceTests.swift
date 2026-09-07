import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

@MainActor
final class ProjectRemovalAcceptanceTests: XCTestCase {
    func testRemovalDeletesOperationalGraphAndCapabilitiesWhileRetainingHistoryAcrossRestart() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seedCompleteProject()
        let manager = ProjectRemovalManager(store: fixture.store)
        let assignmentAuditBefore = try await fixture.store.read { connection in
            try XCTUnwrap(connection.row(
                "SELECT id, actor_id, thread_id, thread_attribution, entity_type, entity_id, reason, created_at, historical_project_id, historical_registration_id FROM audit_events WHERE id = 'assignment-audit'"
            ))
        }

        let preview = try await manager.preview(projectID: fixture.projectID)
        XCTAssertEqual(preview.projectName, "Project One")
        XCTAssertEqual(preview.lifecycle, .active)
        XCTAssertEqual(preview.registration.registrationID, "registration-one")
        XCTAssertEqual(preview.registration.requestGeneration, 4)
        XCTAssertEqual(preview.counts, .init(phases: 1, tickets: 1, evidence: 1, history: 5))

        let removed = try await manager.apply(preview)
        XCTAssertEqual(removed.projectID, fixture.projectID)
        XCTAssertEqual(removed.projectName, "Project One")
        XCTAssertEqual(removed.registration, preview.registration)
        XCTAssertEqual(removed.originalLifecycle, .active)
        XCTAssertEqual(removed.counts, preview.counts)

        let operationalTables = [
            "project_registrations", "project_roots", "project_bookmarks",
            "project_documentation_bindings", "phases", "phase_plans", "tickets",
            "phase_dependencies", "ticket_dependencies", "blockers", "evidence",
            "thread_exclusions", "observed_threads", "observed_goals", "thread_links",
            "ticket_goal_links", "review_items", "completion_records", "notification_events",
            "notification_occurrences", "delivery_goals", "delivery_goal_done_criteria",
            "delivery_goal_ticket_assignments", "delivery_goal_assignment_events",
            "ticket_task_plans", "ticket_tasks",
        ]
        try await fixture.store.read { connection in
            for table in operationalTables {
                XCTAssertEqual(
                    try connection.scalarInt("SELECT COUNT(*) FROM \(table) WHERE project_id = ?", bindings: [.text(fixture.projectID.rawValue)]),
                    0,
                    "Expected \(table) to contain no operational rows for the removed project"
                )
            }
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-one'"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-two'"), 1)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE id = 'legacy-queued'"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM removed_projects WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)]), 1)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_removal_authorizations"), 0)
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE historical_project_id = 'project-one' AND historical_registration_id = 'registration-one'"),
                6
            )
            let assignmentAuditAfter = try XCTUnwrap(connection.row(
                "SELECT id, actor_id, thread_id, thread_attribution, entity_type, entity_id, reason, created_at, historical_project_id, historical_registration_id FROM audit_events WHERE id = 'assignment-audit'"
            ))
            XCTAssertEqual(assignmentAuditAfter, assignmentAuditBefore)
            XCTAssertNil(try connection.scalarText("SELECT project_id FROM audit_events WHERE id = 'assignment-audit'"))
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM retained_delivery_goal_assignment_events WHERE removal_id = ?", bindings: [.text(removed.id.rawValue)]),
                1
            )
        }
        XCTAssertEqual(try Data(contentsOf: fixture.repositoryFile), Data("owner content\n".utf8))

        do {
            try await MeaningfulDeliveryEventRecorder(store: fixture.store).recordGoalObservation(
                projectID: fixture.projectID,
                threadID: "thread-late",
                goalID: "goal-late",
                status: .blocked,
                observedAt: Date(timeIntervalSince1970: 50)
            )
            XCTFail("Expected the late observation to be rejected")
        } catch {}
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM observed_goals WHERE id = 'goal-late'"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-one'"), 0)
        }

        let history = try await ProjectActivityProjection.loadRemoved(
            from: fixture.store,
            removalID: removed.id
        )
        XCTAssertEqual(history.projectID, fixture.projectID)
        XCTAssertTrue(history.items.contains { $0.source == .audit && $0.detail == "Assign retained goal" && $0.assignmentEvents.count == 1 })
        XCTAssertTrue(history.items.contains { $0.source == .review && $0.detail == "Owner reviewed" })
        XCTAssertTrue(history.items.contains { $0.source == .completion && $0.detail == "Delivered" })
        XCTAssertTrue(history.items.contains { $0.source == .runtime && $0.detail == "Observed blocked goal" })
        XCTAssertTrue(history.items.contains { $0.source == .notification && $0.id == "notification-queued" && $0.notificationState == .suppressed })
        XCTAssertTrue(history.items.contains { $0.source == .notification && $0.id == "notification-attempt" && $0.notificationState == .unknown })
        XCTAssertTrue(history.items.contains { $0.source == .notification && $0.id == "notification-sent" && $0.notificationState == .sent })
        XCTAssertTrue(history.items.contains { $0.source == .notification && $0.id == "notification-legacy-queued" && $0.notificationState == .suppressed })
        XCTAssertEqual(
            history.items.first(where: { $0.id == "runtime-goal-one" })?.observedAt,
            ISO8601DateFormatter().date(from: "2026-09-07T10:01:00Z")
        )
        XCTAssertEqual(
            history.items.first(where: { $0.id == "completion-completion-one" })?.observedAt,
            ISO8601DateFormatter().date(from: "2026-09-07T10:02:00Z")
        )
        XCTAssertEqual(
            history.items.first(where: { $0.id == "notification-sent" })?.observedAt,
            ISO8601DateFormatter().date(from: "2026-09-07T10:03:00Z")
        )

        let reopened = DeliveryStore(databaseURL: fixture.databaseURL)
        let reopenedRecord = try await ProjectRemovalManager(store: reopened).record(id: removed.id)
        XCTAssertEqual(reopenedRecord, removed)
        let reopenedHistory = try await ProjectActivityProjection.loadRemoved(from: reopened, removalID: removed.id)
        XCTAssertEqual(reopenedHistory, history)

        do {
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Try to mutate retained history") { connection in
                try connection.execute(
                    "DELETE FROM retained_project_activity_events WHERE removal_id = ?",
                    bindings: [.text(removed.id.rawValue)]
                )
            }
            XCTFail("Expected retained history mutation to be rejected")
        } catch {}
        let historyAfterRejectedMutation = try await ProjectActivityProjection.loadRemoved(
            from: fixture.store,
            removalID: removed.id
        )
        XCTAssertEqual(historyAfterRejectedMutation, history)
    }

    func testStalePreviewAndFailedRemovalRollBackWithoutLeavingAuthorization() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seedCompleteProject()
        let manager = ProjectRemovalManager(store: fixture.store)
        let stale = try await manager.preview(projectID: fixture.projectID)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Rename before removal") { connection in
            try connection.execute("UPDATE projects SET name = 'Renamed' WHERE id = 'project-one'")
        }
        do {
            _ = try await manager.apply(stale)
            XCTFail("Expected stale preview")
        } catch {
            XCTAssertEqual(error as? ProjectRemovalError, .stalePreview)
        }
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-one'"), 1)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM removed_projects"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_removal_authorizations"), 0)
        }

        let current = try await manager.preview(projectID: fixture.projectID)
        let fault = try SQLiteConnection(url: fixture.databaseURL)
        try fault.execute("CREATE TRIGGER fail_project_removal AFTER INSERT ON removed_projects BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END")
        do {
            _ = try await manager.apply(current)
            XCTFail("Expected synthetic failure")
        } catch {}
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-one'"), 1)
            XCTAssertEqual(try connection.scalarText("SELECT state FROM notification_events WHERE id = 'queued'"), "queued")
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM removed_projects"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_removal_authorizations"), 0)
        }
    }

    func testArchivedZeroPhaseRemovalIgnoresLostAccessAndInvalidCatalogThenReportsAlreadyRemoved() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed inaccessible archived project",
            auditScope: .init(projectID: fixture.projectID, entityType: .project, entityID: fixture.projectID.rawValue)
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name, lifecycle) VALUES ('project-one', 'Archived Empty', 'archived')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project-one', 'registration-archived', 7, 'complete')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-archived', 'project-one', '/missing/archived-project')")
            try connection.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('project-one', '/missing/archived-project', X'00', 1)")
            try connection.execute("INSERT INTO project_documentation_bindings (project_id, root_id, repository_id, accepted_catalog_version, accepted_catalog_digest, accepted_catalog) VALUES ('project-one', 'root-archived', '11111111-1111-1111-1111-111111111111', 99, ?, X'00')", bindings: [.text(String(repeating: "0", count: 64))])
        }

        let manager = ProjectRemovalManager(store: fixture.store)
        let preview = try await manager.preview(projectID: fixture.projectID)
        XCTAssertEqual(preview.lifecycle, .archived)
        XCTAssertEqual(preview.counts, .init(phases: 0, tickets: 0, evidence: 0, history: 1))
        let removed = try await manager.apply(preview)
        XCTAssertEqual(removed.originalLifecycle, .archived)
        XCTAssertEqual(removed.registration.registrationID, "registration-archived")

        do {
            _ = try await manager.preview(projectID: fixture.projectID)
            XCTFail("Expected explicit already-removed recovery")
        } catch {
            XCTAssertEqual(error as? ProjectRemovalError, .alreadyRemoved)
        }
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-one'"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE project_id = 'project-one'"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings WHERE project_id = 'project-one'"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE historical_registration_id = 'registration-archived'"), 2)
        }
    }

    func testRemovalAuthorizationCannotDeleteAnotherProjectsProtectedTaskHistory() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seedCompleteProject()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed other task history") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-two', 'project-two', 'Phase Two')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ticket-two', 'project-two', 'phase-two', 'Other', 'backlog')")
            try connection.execute("INSERT INTO ticket_task_plans (project_id, ticket_id, revision, created_at, updated_at) VALUES ('project-two', 'ticket-two', 1, '2026-09-07T10:00:00Z', '2026-09-07T10:00:00Z')")
            try connection.execute("INSERT INTO ticket_tasks (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle, created_at, updated_at) VALUES ('project-two', 'ticket-two', 'task-two', '1', 'Other task', 0, 'pending', 'active', '2026-09-07T10:00:00Z', '2026-09-07T10:00:00Z')")
        }
        do {
            try await fixture.store.transactRemovingProject(
                projectID: fixture.projectID,
                registrationID: "registration-one",
                removalID: .init(rawValue: "synthetic"),
                actor: .init(id: "fixture"),
                reason: "Attempt unrelated delete"
            ) { connection in
                try connection.execute("DELETE FROM ticket_tasks WHERE project_id = 'project-two'")
            }
            XCTFail("Expected protected history rejection")
        } catch {}
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE project_id = 'project-two'"), 1)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_removal_authorizations"), 0)
        }

        do {
            try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Attempt forged removal authorization") { connection in
                try connection.execute("INSERT INTO project_removal_authorizations (project_id, registration_id, removal_id) VALUES ('project-one', 'registration-one', 'forged')")
            }
            XCTFail("Expected removal authorization to remain store-private")
        } catch {}
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM project_removal_authorizations"), 0)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE project_id = 'project-one'"), 1)
        }
    }

    func testOldRegistrationReceiptCannotReplayAfterRemovalAndSameRootReadd() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seedCompleteProject()
        let oldRegistration = ProjectRegistration(projectID: fixture.projectID, registrationID: "registration-one", requestGeneration: 4)
        let request = AgentCommandEnvelope(
            version: 1, requestID: UUID(), projectRoot: fixture.root.path,
            assertedThreadID: "thread-one", reason: "Create receipt",
            command: .upsertPhase(phaseID: "receipt-phase", name: "Receipt Phase")
        )
        let oldRegistry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(registration: oldRegistration, canonicalRoot: fixture.root, authorizedRoots: [fixture.root])
        ])
        let first = await AgentCommandDispatcher(store: fixture.store, projectRegistry: oldRegistry).dispatch(request)
        XCTAssertNil(first.error)
        let manager = ProjectRemovalManager(store: fixture.store)
        _ = try await manager.apply(try await manager.preview(projectID: fixture.projectID))

        let removedAdmission = await AgentCommandDispatcher(store: fixture.store, projectRegistry: oldRegistry).dispatch(request)
        XCTAssertEqual(removedAdmission.error, .unauthorizedProjectRoot)

        let newRegistration = ProjectRegistration(projectID: fixture.projectID, registrationID: "registration-new", requestGeneration: 1)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Re-add same root") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-one', 'Project One Re-added')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project-one', 'registration-new', 1, 'complete')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-new', 'project-one', ?)", bindings: [.text(fixture.root.path)])
        }
        let newRegistry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(registration: newRegistration, canonicalRoot: fixture.root, authorizedRoots: [fixture.root])
        ])
        let replay = await AgentCommandDispatcher(store: fixture.store, projectRegistry: newRegistry).dispatch(request)
        XCTAssertEqual(replay.error, .requestIDReused)
        try await fixture.store.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-one'"), 0)
            XCTAssertEqual(try connection.scalarText("SELECT registration_id FROM agent_command_requests WHERE request_id = ?", bindings: [.text(request.requestID.uuidString)]), "registration-one")
        }
    }

    func testVersionSixteenMigratesHistoricalIdentityAndLeavesLegacyReceiptsUnscoped() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seedCompleteProject()
        let registration = ProjectRegistration(
            projectID: fixture.projectID,
            registrationID: "registration-one",
            requestGeneration: 4
        )
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(registration: registration, canonicalRoot: fixture.root, authorizedRoots: [fixture.root]),
        ])
        let request = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(),
            projectRoot: fixture.root.path,
            assertedThreadID: "thread-one",
            reason: "Create pre-v17 receipt",
            command: .upsertPhase(phaseID: "legacy-receipt-phase", name: "Legacy Receipt Phase")
        )
        let preMigrationResponse = await AgentCommandDispatcher(
            store: fixture.store,
            projectRegistry: registry
        ).dispatch(request)
        XCTAssertNil(preMigrationResponse.error)

        try downgradeToVersionSixteen(databaseURL: fixture.databaseURL)
        let migrated = DeliveryStore(databaseURL: fixture.databaseURL)
        guard case .available = await migrated.availability else {
            return XCTFail("Expected the v16 store to migrate")
        }
        let migratedVersion = await migrated.schemaVersionForDocumentation
        XCTAssertEqual(migratedVersion, 17)
        try await migrated.read { connection in
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM removed_projects"), 0)
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE project_id = 'project-one' AND historical_project_id = 'project-one' AND historical_registration_id = 'registration-one'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE project_id = 'project-one'")
            )
            let receipt = try XCTUnwrap(connection.row(
                "SELECT registration_project_id, registration_id, request_generation FROM agent_command_requests WHERE request_id = ?",
                bindings: [.text(request.requestID.uuidString)]
            ))
            XCTAssertEqual(receipt["registration_project_id"], .null)
            XCTAssertEqual(receipt["registration_id"], .null)
            XCTAssertEqual(receipt["request_generation"], .null)
        }

        let manager = ProjectRemovalManager(store: migrated)
        let removed = try await manager.apply(try await manager.preview(projectID: fixture.projectID))
        XCTAssertEqual(removed.registration, registration)
        let retainedActivity = try await ProjectActivityProjection.loadRemoved(from: migrated, removalID: removed.id)
        XCTAssertEqual(retainedActivity.projectID, fixture.projectID)
    }

    func testRemovedProjectIsDiscoverableAndStaleLiveRouteRecoversToReadOnlyHistory() async throws {
        let fixture = try Fixture(testCase: self)
        try await fixture.seedCompleteProject()
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()

        let preview = try await model.previewProjectRemoval(projectID: fixture.projectID)
        let removed = try await model.applyProjectRemoval(preview)
        XCTAssertEqual(model.selection, .removedProject(removed.id))
        XCTAssertTrue(model.dashboard?.projects.contains(where: { $0.id == fixture.projectID }) == false)
        XCTAssertTrue(model.dashboard?.archivedProjects.contains(where: { $0.id == fixture.projectID }) == false)
        XCTAssertEqual(model.dashboard?.removedProjects.first?.id, removed.id)
        XCTAssertNotNil(model.removedActivity(for: removed.id))

        await model.navigate(to: .phaseBoard(fixture.projectID))
        XCTAssertEqual(model.selection, .removedProject(removed.id))
        await model.navigate(to: .removedProject(removed.id))
        XCTAssertEqual(model.selection, .removedProject(removed.id))
    }

    private func downgradeToVersionSixteen(databaseURL: URL) throws {
        let legacy = try SQLiteConnection(url: databaseURL)
        for trigger in [
            "ticket_task_plans_reject_delete",
            "ticket_tasks_reject_delete",
            "ticket_task_plans_reject_ticket_delete",
            "ticket_task_plans_reject_project_delete",
        ] {
            try legacy.execute("DROP TRIGGER \(trigger)")
        }
        try legacy.execute("DROP INDEX audit_events_historical_project_index")
        try legacy.execute("DROP TABLE retained_delivery_goal_assignment_events")
        try legacy.execute("DROP TABLE retained_project_activity_events")
        try legacy.execute("DROP TABLE project_removal_authorizations")
        try legacy.execute("DROP TABLE removed_projects")
        try legacy.execute("ALTER TABLE audit_events DROP COLUMN historical_registration_id")
        try legacy.execute("ALTER TABLE audit_events DROP COLUMN historical_project_id")
        try legacy.execute("ALTER TABLE agent_command_requests DROP COLUMN request_generation")
        try legacy.execute("ALTER TABLE agent_command_requests DROP COLUMN registration_id")
        try legacy.execute("ALTER TABLE agent_command_requests DROP COLUMN registration_project_id")
        try legacy.execute("""
        CREATE TRIGGER ticket_task_plans_reject_delete BEFORE DELETE ON ticket_task_plans
        BEGIN SELECT RAISE(ABORT, 'ticket task plan history cannot be deleted'); END
        """)
        try legacy.execute("""
        CREATE TRIGGER ticket_tasks_reject_delete BEFORE DELETE ON ticket_tasks
        BEGIN SELECT RAISE(ABORT, 'ticket task history cannot be deleted'); END
        """)
        try legacy.execute("""
        CREATE TRIGGER ticket_task_plans_reject_ticket_delete BEFORE DELETE ON tickets
        WHEN EXISTS (SELECT 1 FROM ticket_task_plans WHERE project_id = OLD.project_id AND ticket_id = OLD.id)
        BEGIN SELECT RAISE(ABORT, 'ticket owns task history'); END
        """)
        try legacy.execute("""
        CREATE TRIGGER ticket_task_plans_reject_project_delete BEFORE DELETE ON projects
        WHEN EXISTS (SELECT 1 FROM ticket_task_plans WHERE project_id = OLD.id)
        BEGIN SELECT RAISE(ABORT, 'project owns task history'); END
        """)
        try legacy.execute("PRAGMA user_version = 16")
    }

    private struct Fixture {
        let store: DeliveryStore
        let databaseURL: URL
        let root: URL
        let repositoryFile: URL
        let projectID = ProjectID(rawValue: "project-one")

        init(testCase: XCTestCase) throws {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReleaseRadar-C6-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            testCase.addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
            databaseURL = directory.appendingPathComponent("store.sqlite")
            root = directory.appendingPathComponent("repository", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            repositoryFile = root.appendingPathComponent("owner.txt")
            try Data("owner content\n".utf8).write(to: repositoryFile)
            store = DeliveryStore(databaseURL: databaseURL)
        }

        func seedCompleteProject() async throws {
            let projectID = projectID
            try await store.transact(
                actor: .init(id: "fixture"),
                reason: "Seed complete removable project",
                auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
            ) { connection in
                try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-one', 'Project One', 1)")
                try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project-one', 'registration-one', 4, 'complete')")
                try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-one', 'project-one', ?)", bindings: [.text(root.path)])
                try connection.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('project-one', ?, ?, 0)", bindings: [.text(root.path), .blob(Data(root.path.utf8))])
                try connection.execute("INSERT INTO project_documentation_bindings (project_id, root_id, repository_id, accepted_catalog_version, accepted_catalog_digest, accepted_catalog) VALUES ('project-one', 'root-one', '11111111-1111-1111-1111-111111111111', 1, ?, X'00')", bindings: [.text(String(repeating: "0", count: 64))])
                try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-one', 'project-one', 'Phase One')")
                try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ticket-one', 'project-one', 'phase-one', 'Deliver', 'in_progress')")
                try connection.execute("INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES ('evidence-one', 'project-one', 'ticket-one', ?, 1)", bindings: [.text(repositoryFile.path)])
                try connection.execute("INSERT INTO thread_exclusions (id, project_id, thread_id, reason) VALUES ('excluded-one', 'project-one', 'excluded-thread', 'Owner excluded')")
                try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-one', 'project-one', 'active', '2026-09-07T10:00:00Z')")
                try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-one', 'project-one', 'thread-one', 'blocked', 'Observed blocked goal', '2026-09-07T10:01:00Z')")
                try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('link-one', 'project-one', 'ticket-one', 'thread-one')")
                try connection.execute("INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES ('goal-link-one', 'project-one', 'ticket-one', 'thread-one', 'goal-one')")
                try connection.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES ('review-one', 'project-one', 'ticket-one', 'test', 'Owner reviewed', 'resolved')")
                try connection.execute("INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES ('completion-one', 'project-one', 'ticket-one', 'Delivered', '2026-09-07T10:02:00Z')")
                try connection.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('project-one', 'phase-one', 'delivery-goal-one', 'Retained goal', 'Retain history', 'active', 0, '2026-09-07T10:00:00Z', '2026-09-07T10:00:00Z')")
                try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('project-one', 'phase-one', 'delivery-goal-one', 0, 'History remains')")
                try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('project-one', 'phase-one', 'delivery-goal-one', 'ticket-one')")
                try connection.execute("INSERT INTO ticket_task_plans (project_id, ticket_id, revision, created_at, updated_at) VALUES ('project-one', 'ticket-one', 1, '2026-09-07T10:00:00Z', '2026-09-07T10:00:00Z')")
                try connection.execute("INSERT INTO ticket_tasks (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle, created_at, updated_at) VALUES ('project-one', 'ticket-one', 'task-one', '1', 'Retained task', 0, 'pending', 'active', '2026-09-07T10:00:00Z', '2026-09-07T10:00:00Z')")
                try connection.execute("INSERT INTO projects (id, name) VALUES ('project-two', 'Other Project')")
                try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project-two', 'registration-two', 1, 'complete')")
            }
            try await store.transact(
                actor: .init(id: "fixture", threadID: "thread-one", threadAttribution: .asserted),
                reason: "Assign retained goal",
                auditEventID: .init(rawValue: "assignment-audit"),
                auditScope: .init(projectID: projectID, entityType: .deliveryGoal, entityID: "delivery-goal-one")
            ) { connection in
                try connection.execute("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('assignment-audit', 'project-one', 'phase-one', 'ticket-one', NULL, 'delivery-goal-one', 1, 'assigned')")
            }
            try await store.transact(
                actor: .init(id: "fixture"),
                reason: "Record review resolution",
                auditScope: .init(projectID: projectID, entityType: .reviewItem, entityID: "review-one")
            ) { _ in }
            try await store.transact(
                actor: .init(id: "fixture"),
                reason: "Record completion",
                auditScope: .init(projectID: projectID, entityType: .completion, entityID: "completion-one")
            ) { _ in }
            try await seedNotifications()
        }

        private func seedNotifications() async throws {
            try await store.transact(
                actor: .init(id: "fixture"),
                reason: "Seed notification outcomes",
                auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
            ) { connection in
                for (id, state) in [("queued", "queued"), ("attempt", "attempt_started"), ("sent", "sent")] {
                    try connection.execute(
                        "INSERT INTO notification_events (id, fingerprint, state, project_id, event_kind, subject_id, occurrence, title, message, created_at, attempt_count) VALUES (?, ?, ?, 'project-one', 'review_requested', ?, 1, 'History notice', 'Retain outcome', '2026-09-07T10:03:00Z', ?)",
                        bindings: [.text(id), .text("fingerprint-\(id)"), .text(state), .text(id), .integer(state == "attempt_started" ? 1 : 0)]
                    )
                    try connection.execute(
                        "INSERT INTO notification_occurrences (subject_key, project_id, event_kind, subject_id, generation, is_active) VALUES (?, 'project-one', 'review_requested', ?, 1, 1)",
                        bindings: [.text("project-one|review_requested|\(id)"), .text(id)]
                    )
                }
                try connection.execute(
                    "INSERT INTO notification_events (id, fingerprint, state, ticket_id, event_kind, subject_id, occurrence, title, message, created_at, attempt_count) VALUES ('legacy-queued', 'fingerprint-legacy-queued', 'queued', 'ticket-one', 'review_requested', 'legacy-queued', 1, 'Legacy history notice', 'Retain legacy outcome', '2026-09-07T10:03:00Z', 0)"
                )
            }
        }
    }
}
