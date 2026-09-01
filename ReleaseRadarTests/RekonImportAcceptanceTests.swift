import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RekonImportAcceptanceTests: XCTestCase {
    func testAcceptedImportFailsClosedWhenAPlanAppearsAfterStagedInsertion() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        try await store.transact(actor: .init(id: "test-trigger"), reason: "Install scoped trigger") { connection in
            try connection.execute(
                """
                CREATE TRIGGER task4a_import_plan_after_insert
                AFTER INSERT ON tickets WHEN NEW.id = 'TASK-A'
                BEGIN
                    INSERT INTO ticket_task_plans (project_id, ticket_id, revision, created_at, updated_at)
                    VALUES (NEW.project_id, NEW.id, 1, '2026-08-31T12:00:00Z', '2026-08-31T12:00:00Z');
                    INSERT INTO ticket_tasks
                        (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle, created_at, updated_at)
                    VALUES
                        (NEW.project_id, NEW.id, 'injected-task', 'Injected', 'Injected pending task', 0,
                         'pending', 'active', '2026-08-31T12:00:00Z', '2026-08-31T12:00:00Z');
                END
                """
            )
        }
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        let preview = try importer.preview(fixture.root)
        let before = try await Self.task4AImportSnapshot(store)

        do {
            try await importer.apply(preview, to: fixture.projectID)
            XCTFail("Expected the injected plan to reject the Accepted import")
        } catch {
            XCTAssertEqual(
                error as? TicketTaskPlanningPolicyError,
                .ticketTaskPlanRevisionConflict(expected: nil, current: 1)
            )
        }

        let after = try await Self.task4AImportSnapshot(store)
        XCTAssertEqual(after, before)
    }

    private static func task4AImportSnapshot(_ store: DeliveryStore) async throws -> [String] {
        try await store.read { connection in
            var rows: [String] = []
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'phases|' || quote(id) || '|' || quote(project_id) || '|' || quote(name) AS value FROM phases ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'project_active_phases|' || quote(project_id) || '|' || quote(phase_id) AS value FROM project_active_phases ORDER BY project_id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'tickets|' || quote(id) || '|' || quote(project_id) || '|' || quote(phase_id) || '|' || quote(outcome) || '|' || quote(lane) AS value FROM tickets ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'ticket_task_plans|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(revision) || '|' || quote(created_at) || '|' || quote(updated_at) AS value FROM ticket_task_plans ORDER BY project_id, ticket_id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'ticket_tasks|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(id) || '|' || quote(label) || '|' || quote(title) || '|' || quote(sort_order) || '|' || quote(completion) || '|' || quote(lifecycle) || '|' || quote(created_at) || '|' || quote(updated_at) || '|' || quote(completed_at) || '|' || quote(superseded_at) AS value FROM ticket_tasks ORDER BY project_id, ticket_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'phase_dependencies|' || quote(id) || '|' || quote(project_id) || '|' || quote(phase_id) || '|' || quote(depends_on_phase_id) AS value FROM phase_dependencies ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'ticket_dependencies|' || quote(id) || '|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(depends_on_ticket_id) AS value FROM ticket_dependencies ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'evidence|' || quote(id) || '|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(path) || '|' || quote(is_available) AS value FROM evidence ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'review_items|' || quote(id) || '|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(kind) || '|' || quote(summary) || '|' || quote(status) AS value FROM review_items ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'notification_occurrences|' || quote(subject_key) || '|' || quote(project_id) || '|' || quote(event_kind) || '|' || quote(subject_id) || '|' || quote(generation) || '|' || quote(is_active) AS value FROM notification_occurrences ORDER BY subject_key"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'notification_events|' || quote(id) || '|' || quote(fingerprint) || '|' || quote(state) || '|' || quote(ticket_id) || '|' || quote(goal_id) || '|' || quote(provider_receipt) || '|' || quote(acknowledged_at) || '|' || quote(project_id) || '|' || quote(event_kind) || '|' || quote(subject_id) || '|' || quote(occurrence) || '|' || quote(title) || '|' || quote(message) || '|' || quote(created_at) || '|' || quote(attempt_count) || '|' || quote(attempt_started_at) || '|' || quote(completed_at) || '|' || quote(failure_code) AS value FROM notification_events ORDER BY id"
            ))
            rows.append(contentsOf: try Self.task4ATextRows(
                connection,
                sql: "SELECT 'audit_events|' || quote(id) || '|' || quote(actor_id) || '|' || quote(thread_id) || '|' || quote(thread_attribution) || '|' || quote(reason) || '|' || quote(created_at) || '|' || quote(project_id) || '|' || quote(entity_type) || '|' || quote(entity_id) AS value FROM audit_events ORDER BY id"
            ))
            return rows
        }
    }

    private static func task4ATextRows(
        _ connection: SQLiteConnection,
        sql: String
    ) throws -> [String] {
        var values: [String] = []
        var offset: Int64 = 0
        while let row = try connection.row("\(sql) LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
            guard case let .text(value)? = row["value"] else {
                throw RekonImportError.malformedArtifact
            }
            values.append(value)
            offset += 1
        }
        return values
    }

    func testPreviewMapsStableContractAndRoutesAmbiguityWithoutMarkdownInference() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let sourceBytes = try Data(contentsOf: fixture.artifactURL)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )

        XCTAssertTrue(importer.canImport(fixture.root))
        let preview = try importer.preview(fixture.root)

        XCTAssertEqual(preview.schemaVersion, 1)
        XCTAssertEqual(preview.activePhaseID, PhaseID(rawValue: "phase-main"))
        XCTAssertEqual(preview.phases.map(\.id), [PhaseID(rawValue: "phase-main"), PhaseID(rawValue: "phase-next")])
        XCTAssertEqual(preview.phaseDependencies, [
            .init(phaseID: .init(rawValue: "phase-next"), dependsOnPhaseID: .init(rawValue: "phase-main")),
        ])
        XCTAssertEqual(preview.tickets.map(\.id), [
            TicketID(rawValue: "TASK-A"),
            TicketID(rawValue: "TASK-B"),
            TicketID(rawValue: "TASK-C"),
        ])
        XCTAssertEqual(preview.tickets.map(\.lane), [.accepted, .inProgress, .blocked])
        XCTAssertEqual(preview.ticketDependencies, [
            .init(ticketID: .init(rawValue: "TASK-B"), dependsOnTicketID: .init(rawValue: "TASK-A")),
        ])

        let evidencePaths = Set(preview.evidence.map { URL(fileURLWithPath: $0.path).lastPathComponent })
        XCTAssertEqual(evidencePaths, ["TASK-A.md", "roadmap.md", "owner-handoff.md", "delivery-ledger.md"])
        XCTAssertFalse(evidencePaths.contains("README.md"))
        XCTAssertEqual(Set(preview.reviewItems.map(\.kind)), [.duplicate, .missingOutcome, .unresolvedDependency])
        XCTAssertEqual(Set(preview.reviewItems.map(\.sourceID)), ["DUP", "NO-TITLE", "TASK-C→TASK-MISSING"])
        XCTAssertEqual(try Data(contentsOf: fixture.artifactURL), sourceBytes)
    }

    func testApplyIsTransactionalIdempotentAndPersistsAcrossRelaunch() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        let preview = try importer.preview(fixture.root)
        let sourceBytes = try Data(contentsOf: fixture.artifactURL)

        try await importer.apply(preview, to: fixture.projectID)
        let firstAcceptance = try await Self.task4ANormalImportAcceptanceState(store)
        try await importer.apply(preview, to: fixture.projectID)
        let secondAcceptance = try await Self.task4ANormalImportAcceptanceState(store)

        let expectedAudit = "release-radar-importer||none|Import recognized Rekon delivery records|project-import|project|project-import"
        XCTAssertEqual(firstAcceptance.acceptedTicketRows, ["TASK-A|accepted"])
        XCTAssertTrue(firstAcceptance.planRows.isEmpty)
        XCTAssertTrue(firstAcceptance.taskRows.isEmpty)
        XCTAssertEqual(firstAcceptance.importAuditRows, [expectedAudit])
        XCTAssertEqual(secondAcceptance.acceptedTicketRows, ["TASK-A|accepted"])
        XCTAssertTrue(secondAcceptance.planRows.isEmpty)
        XCTAssertTrue(secondAcceptance.taskRows.isEmpty)
        XCTAssertEqual(secondAcceptance.importAuditRows, [expectedAudit, expectedAudit])

        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let state = try await relaunchedStore.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM evidence WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, 4)
        XCTAssertEqual(state.5, 3)
        XCTAssertEqual(state.6, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.artifactURL), sourceBytes)
    }

    private static func task4ANormalImportAcceptanceState(
        _ store: DeliveryStore
    ) async throws -> Task4ANormalImportAcceptanceState {
        try await store.read { connection in
            Task4ANormalImportAcceptanceState(
                acceptedTicketRows: try Self.task4ATextRows(
                    connection,
                    sql: "SELECT id || '|' || lane AS value FROM tickets WHERE project_id = 'project-import' AND lane = 'accepted' ORDER BY id"
                ),
                planRows: try Self.task4ATextRows(
                    connection,
                    sql: "SELECT project_id || '|' || ticket_id || '|' || revision AS value FROM ticket_task_plans ORDER BY project_id, ticket_id"
                ),
                taskRows: try Self.task4ATextRows(
                    connection,
                    sql: "SELECT project_id || '|' || ticket_id || '|' || id AS value FROM ticket_tasks ORDER BY project_id, ticket_id, id"
                ),
                importAuditRows: try Self.task4ATextRows(
                    connection,
                    sql: "SELECT actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') AS value FROM audit_events WHERE actor_id = 'release-radar-importer' AND reason = 'Import recognized Rekon delivery records' ORDER BY created_at, id"
                )
            )
        }
    }

    func testApplyAtomicallyEnqueuesOpenImportReviewsOnlyAfterDashboardOpened() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        try await store.transact(actor: .init(id: "owner"), reason: "Open imported project") { connection in
            try connection.execute("UPDATE projects SET first_dashboard_opened = 1 WHERE id = 'project-import'")
        }
        let rules = AlertRuleStore(store: store)
        _ = try await rules.set(.needsReviewEntry, enabled: false)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        let preview = try importer.preview(fixture.root)

        try await importer.apply(preview, to: fixture.projectID)
        _ = try await rules.set(.needsReviewEntry, enabled: true)
        try await importer.apply(preview, to: fixture.projectID)

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixture.artifactURL)) as? [String: Any]
        )
        object["activePhaseId"] = NSNull()
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-import' AND event_kind = 'import_needs_review'"),
                try connection.scalarInt("SELECT COUNT(DISTINCT fingerprint) FROM notification_events WHERE project_id = 'project-import'")
            )
        }
        XCTAssertEqual(state.0, 4)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
    }

    func testApplyPersistsConfidentActivePhaseInsteadOfEarlierHistoricalPhase() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        try await store.transact(actor: .init(id: "test-seed"), reason: "Seed historical phase") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-history', 'project-import', 'Historical')")
        }
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let activePhaseID = try await store.read { connection in
            try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-import'")
        }
        XCTAssertEqual(activePhaseID, "phase-main")
    }

    func testMissingActivePhaseCreatesReviewAndLeavesAmbiguousProjectUnset() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixture.artifactURL)) as? [String: Any]
        )
        object["activePhaseId"] = NSNull()
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        let preview = try importer.preview(fixture.root)
        XCTAssertTrue(preview.reviewItems.contains {
            $0.sourceID == "activePhaseId" && $0.kind == .missingOutcome
        })
        try await importer.apply(preview, to: fixture.projectID)

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'import-review:project-import:missing_outcome:activePhaseId' AND status = 'open'")
            )
        }
        XCTAssertNil(state.0)
        XCTAssertEqual(state.1, 2)
        XCTAssertEqual(state.2, 1)
    }

    func testReimportMarksMissingEvidenceUnavailableWithoutDeletingDeliveryOrReopeningReview() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let reviewID = try await store.read { connection in
            try connection.scalarText(
                "SELECT id FROM review_items WHERE project_id = 'project-import' AND kind = 'duplicate'"
            )
        }
        try await store.transact(actor: .init(id: "owner"), reason: "Resolve duplicate") { connection in
            try connection.execute(
                "UPDATE review_items SET status = 'resolved' WHERE id = ?",
                bindings: [.text(try XCTUnwrap(reviewID))]
            )
        }
        try FileManager.default.removeItem(at: fixture.handoffURL)

        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let missingEvidencePath = fixture.handoffURL.path
        let resolvedReviewID = try XCTUnwrap(reviewID)
        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT is_available FROM evidence WHERE path = ?", bindings: [.text(missingEvidencePath)]),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarText("SELECT status FROM review_items WHERE id = ?", bindings: [.text(resolvedReviewID)])
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, "resolved")
    }

    func testApplyRejectsWrongTargetAndUnpersistedRootWithoutPartialWrites() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)
        let preview = try importer.preview(fixture.root)

        do {
            try await importer.apply(preview, to: .init(rawValue: "wrong-project"))
            XCTFail("Expected target mismatch")
        } catch let error as RekonImportError {
            XCTAssertEqual(error, .targetProjectMismatch)
        }
        do {
            try await importer.apply(preview, to: fixture.projectID)
            XCTFail("Expected an unpersisted project/root rejection")
        } catch let error as RekonImportError {
            XCTAssertEqual(error, .projectNotFound)
        }

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 0)
    }

    func testCrossProjectRecordConflictBecomesReviewWhileOtherRecordsImport() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        try await store.transact(actor: .init(id: "test-seed"), reason: "Seed conflicting project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-other', 'Other')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('other-phase', 'project-other', 'Other phase')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('TASK-A', 'project-other', 'other-phase', 'Existing task', 'backlog')")
        }
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'TASK-A' AND project_id = 'project-other'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import' AND kind = 'conflict'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 2)
        XCTAssertEqual(state.3, 0)
    }

    func testPreviewFailsClosedForUnsupportedOversizedAndEscapingArtifacts() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        XCTAssertThrowsError(try importer.preview(fixture.root.appendingPathComponent("sibling"))) { error in
            XCTAssertEqual(error as? RekonImportError, .unauthorizedFolder)
        }

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture.artifactURL)) as? [String: Any])
        object["schemaVersion"] = 2
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            XCTAssertEqual(error as? RekonImportError, .unsupportedSchemaVersion(2))
        }

        object["schemaVersion"] = 1
        var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        tasks[0]["evidence"] = ["label": "Escape", "href": "../../../../outside.md"]
        object["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .invalidPath = error as? RekonImportError else {
                return XCTFail("Expected invalid evidence path, got \(error)")
            }
        }

        let oversizedHandle = try FileHandle(forWritingTo: fixture.artifactURL)
        try oversizedHandle.truncate(atOffset: 1_048_577)
        try oversizedHandle.close()
        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            XCTAssertEqual(error as? RekonImportError, .inputTooLarge)
        }
    }

    func testPreviewStopsWhenRecognizedEvidenceDirectoryExceedsScanLimit() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        let taskBriefs = fixture.root.appendingPathComponent("docs/delivery/task-briefs", isDirectory: true)
        for index in 0...512 {
            FileManager.default.createFile(
                atPath: taskBriefs.appendingPathComponent("generated-\(index).md").path,
                contents: Data()
            )
        }

        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .limitExceeded = error as? RekonImportError else {
                return XCTFail("Expected bounded evidence scan, got \(error)")
            }
        }
        XCTAssertFalse(importer.canImport(fixture.root))
    }

    func testTwoNodePhaseAndTicketCyclesBecomeReviewsWhileConfidentEdgesApply() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixture.artifactURL)) as? [String: Any]
        )
        var phases = try XCTUnwrap(object["phases"] as? [[String: Any]])
        phases[0]["dependsOnPhaseIds"] = ["phase-next"]
        object["phases"] = phases
        var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        tasks[0]["dependsOnTaskIds"] = ["TASK-B"]
        object["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.artifactURL)
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        let preview = try importer.preview(fixture.root)

        XCTAssertEqual(preview.phaseDependencies, [
            .init(phaseID: .init(rawValue: "phase-main"), dependsOnPhaseID: .init(rawValue: "phase-next")),
        ])
        XCTAssertEqual(preview.ticketDependencies, [
            .init(ticketID: .init(rawValue: "TASK-A"), dependsOnTicketID: .init(rawValue: "TASK-B")),
        ])
        let cycleReviews = preview.reviewItems.filter { $0.kind == .unresolvedDependency }
        XCTAssertTrue(cycleReviews.contains { $0.sourceID == "phase-next→phase-main" })
        XCTAssertTrue(cycleReviews.contains { $0.sourceID == "TASK-B→TASK-A" })

        try await importer.apply(preview, to: fixture.projectID)
        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = 'project-import' AND kind = 'unresolved_dependency'")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, 3)
    }

    func testApplyRoutesDependenciesThatCycleWithPersistedGraphsToReviewWithoutRollback() async throws {
        let fixture = try RekonImportFixture(testCase: self)
        let store = DeliveryStore(databaseURL: fixture.databaseURL)
        try await fixture.seedProject(in: store)
        try await store.transact(actor: .init(id: "test-seed"), reason: "Seed persisted dependency graphs") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-main', 'project-import', 'Main delivery')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-next', 'project-import', 'Next delivery')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('TASK-A', 'project-import', 'phase-main', 'Build foundation', 'accepted')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('TASK-B', 'project-import', 'phase-main', 'Integrate workflow', 'in_progress')")
            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('persisted-phase-edge', 'project-import', 'phase-main', 'phase-next')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('persisted-ticket-edge', 'project-import', 'TASK-A', 'TASK-B')")
        }
        let importer = RekonArtifactImporter(store: store, project: fixture.authorizedProject)

        try await importer.apply(try importer.preview(fixture.root), to: fixture.projectID)

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'project-import'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = 'project-import' AND phase_id = 'phase-main' AND depends_on_phase_id = 'phase-next'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies WHERE project_id = 'project-import' AND phase_id = 'phase-next' AND depends_on_phase_id = 'phase-main'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'project-import' AND ticket_id = 'TASK-A' AND depends_on_ticket_id = 'TASK-B'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'project-import' AND ticket_id = 'TASK-B' AND depends_on_ticket_id = 'TASK-A'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'import-review:project-import:unresolved_dependency:phase-next→phase-main' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'import-review:project-import:unresolved_dependency:TASK-B→TASK-A' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(state.0, 2)
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 0)
        XCTAssertEqual(state.4, 1)
        XCTAssertEqual(state.5, 0)
        XCTAssertEqual(state.6, 1)
        XCTAssertEqual(state.7, 1)
        XCTAssertEqual(state.8, 0)
    }

    func testPreviewRejectsArtifactSymlinkThatEscapesAuthorizedRoot() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        let externalDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RekonImportExternal-\(UUID().uuidString)", isDirectory: true)
        let externalArtifact = externalDirectory.appendingPathComponent("dashboard-status.json")
        try FileManager.default.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
        try Data(contentsOf: fixture.artifactURL).write(to: externalArtifact)
        try FileManager.default.removeItem(at: fixture.artifactURL)
        try FileManager.default.createSymbolicLink(at: fixture.artifactURL, withDestinationURL: externalArtifact)
        addTeardownBlock { try? FileManager.default.removeItem(at: externalDirectory) }

        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .invalidPath = error as? RekonImportError else {
                return XCTFail("Expected escaped artifact rejection, got \(error)")
            }
        }
        XCTAssertFalse(importer.canImport(fixture.root))
    }

    func testPreviewRejectsFinalArtifactSymlinkWithinAuthorizedRoot() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        let realArtifact = fixture.root.appendingPathComponent("dashboard-status-real.json")
        try FileManager.default.moveItem(at: fixture.artifactURL, to: realArtifact)
        try FileManager.default.createSymbolicLink(at: fixture.artifactURL, withDestinationURL: realArtifact)

        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .invalidPath = error as? RekonImportError else {
                return XCTFail("Expected final artifact symlink rejection, got \(error)")
            }
        }
        XCTAssertFalse(importer.canImport(fixture.root))
    }

    func testPreviewRejectsDeliveryDirectorySymlinkWithinAuthorizedRoot() throws {
        let fixture = try RekonImportFixture(testCase: self)
        let importer = RekonArtifactImporter(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            project: fixture.authorizedProject
        )
        let deliveryDirectory = fixture.root.appendingPathComponent("docs/delivery", isDirectory: true)
        let realDeliveryDirectory = fixture.root.appendingPathComponent("docs/actual-delivery", isDirectory: true)
        try FileManager.default.moveItem(at: deliveryDirectory, to: realDeliveryDirectory)
        try FileManager.default.createSymbolicLink(at: deliveryDirectory, withDestinationURL: realDeliveryDirectory)

        XCTAssertThrowsError(try importer.preview(fixture.root)) { error in
            guard case .invalidPath = error as? RekonImportError else {
                return XCTFail("Expected delivery directory symlink rejection, got \(error)")
            }
        }
        XCTAssertFalse(importer.canImport(fixture.root))
    }
}

private struct Task4ANormalImportAcceptanceState {
    let acceptedTicketRows: [String]
    let planRows: [String]
    let taskRows: [String]
    let importAuditRows: [String]
}

private final class RekonImportFixture {
    let root: URL
    let databaseURL: URL
    let artifactURL: URL
    let projectID = ProjectID(rawValue: "project-import")

    var taskBriefURL: URL {
        root.appendingPathComponent("docs/delivery/task-briefs/TASK-A.md")
    }

    var handoffURL: URL {
        root.appendingPathComponent("docs/delivery/handoffs/owner-handoff.md")
    }

    var authorizedProject: AuthorizedProject {
        .init(projectID: projectID, canonicalRoot: root, authorizedRoots: [root])
    }

    init(testCase: XCTestCase) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RekonImportTests-\(UUID().uuidString)", isDirectory: true)
        databaseURL = root.appendingPathComponent("release-radar.sqlite")
        artifactURL = root.appendingPathComponent("docs/delivery/dashboard-status.json")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("docs/delivery/task-briefs"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("docs/delivery/handoffs"),
            withIntermediateDirectories: true
        )
        let bundle = Bundle(for: RekonImportAcceptanceTests.self)
        try Self.copy("rekon-import-dashboard-status", extension: "json", from: bundle, to: artifactURL)
        try Self.copy("rekon-import-task-brief", extension: "md", from: bundle, to: taskBriefURL)
        try Self.copy("rekon-import-roadmap", extension: "md", from: bundle, to: root.appendingPathComponent("docs/delivery/roadmap.md"))
        try Self.copy("rekon-import-handoff", extension: "md", from: bundle, to: handoffURL)
        try Self.copy("rekon-import-ledger", extension: "md", from: bundle, to: root.appendingPathComponent("docs/delivery/delivery-ledger.md"))
        try Self.copy("rekon-import-arbitrary", extension: "md", from: bundle, to: root.appendingPathComponent("README.md"))
        testCase.addTeardownBlock { [root] in try? FileManager.default.removeItem(at: root) }
    }

    func seedProject(in store: DeliveryStore) async throws {
        let projectID = projectID
        let rootPath = root.path
        try await store.transact(actor: .init(id: "test-seed"), reason: "Seed import project") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, ?)",
                bindings: [.text(projectID.rawValue), .text("Imported project")]
            )
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                bindings: [.text("root-import"), .text(projectID.rawValue), .text(rootPath)]
            )
        }
    }

    private static func copy(_ name: String, extension fileExtension: String, from bundle: Bundle, to destination: URL) throws {
        let source = try XCTUnwrap(bundle.url(forResource: name, withExtension: fileExtension))
        try FileManager.default.copyItem(at: source, to: destination)
    }
}
