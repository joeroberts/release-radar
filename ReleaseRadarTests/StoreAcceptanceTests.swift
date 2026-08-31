import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class StoreAcceptanceTests: XCTestCase {
    func testDeliveryGoalPublicModelsRoundTripAndKeepObservedGoalIdentityDistinct() throws {
        let createdAt = Date(timeIntervalSince1970: 1_777_777_777)
        let goalID = DeliveryGoalID(rawValue: "DG-1")
        let observedGoalID = ObservedGoalID(rawValue: "DG-1")
        let envelope = DeliveryGoalModelEnvelope(
            draft: .init(
                id: goalID,
                title: "Outcome",
                outcome: "The complete outcome is delivered.",
                doneCriteria: ["One", "Two"],
                sortOrder: 3
            ),
            assignment: .init(goalID: goalID, ticketID: .init(rawValue: "RR-1")),
            phasePlan: .init(
                projectID: .init(rawValue: "project-1"),
                phaseID: .init(rawValue: "phase-1"),
                state: .ready,
                revision: 4,
                readyRevision: 4,
                createdAt: createdAt,
                updatedAt: createdAt,
                finalizedAt: createdAt
            ),
            goal: .init(
                id: goalID,
                projectID: .init(rawValue: "project-1"),
                phaseID: .init(rawValue: "phase-1"),
                title: "Outcome",
                outcome: "The complete outcome is delivered.",
                lifecycle: .awaitingAcceptance,
                sortOrder: 3,
                createdAt: createdAt,
                updatedAt: createdAt,
                activatedAt: createdAt,
                acceptedAt: nil
            ),
            criterion: .init(
                projectID: .init(rawValue: "project-1"),
                phaseID: .init(rawValue: "phase-1"),
                goalID: goalID,
                sortOrder: 0,
                text: "One measurable result"
            ),
            assignmentRecord: .init(
                projectID: .init(rawValue: "project-1"),
                phaseID: .init(rawValue: "phase-1"),
                goalID: goalID,
                ticketID: .init(rawValue: "RR-1")
            ),
            assignmentEvent: .init(
                auditEventID: .init(rawValue: "audit-1"),
                projectID: .init(rawValue: "project-1"),
                phaseID: .init(rawValue: "phase-1"),
                ticketID: .init(rawValue: "RR-1"),
                previousGoalID: nil,
                currentGoalID: goalID,
                revision: 4,
                action: "assigned"
            ),
            readinessFailure: .init(
                unassignedTicketIDs: [.init(rawValue: "RR-2"), .init(rawValue: "RR-1")],
                incompleteGoalIDs: [.init(rawValue: "DG-2"), .init(rawValue: "DG-1")],
                conflictingTicketIDs: [.init(rawValue: "RR-4"), .init(rawValue: "RR-3")]
            )
        )

        let encoded = try JSONEncoder().encode(envelope)
        XCTAssertEqual(try JSONDecoder().decode(DeliveryGoalModelEnvelope.self, from: encoded), envelope)
        XCTAssertEqual(envelope.readinessFailure.unassignedTicketIDs.map(\.rawValue), ["RR-1", "RR-2"])
        XCTAssertEqual(envelope.readinessFailure.incompleteGoalIDs.map(\.rawValue), ["DG-1", "DG-2"])
        XCTAssertEqual(envelope.readinessFailure.conflictingTicketIDs.map(\.rawValue), ["RR-3", "RR-4"])
        XCTAssertEqual(goalID.rawValue, observedGoalID.rawValue)
        XCTAssertNotEqual(String(reflecting: type(of: goalID)), String(reflecting: type(of: observedGoalID)))
        XCTAssertEqual(AuditEntityType.phasePlan.rawValue, "phase_plan")
        XCTAssertEqual(AuditEntityType.deliveryGoal.rawValue, "delivery_goal")
    }

    func testTicketTaskPublicModelsRoundTripAndAuditScope() throws {
        func roundTrip<Value: Codable & Equatable>(_ value: Value) throws {
            let encoded = try JSONEncoder().encode(value)
            XCTAssertEqual(try JSONDecoder().decode(Value.self, from: encoded), value)
        }

        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let taskID = TicketTaskID(rawValue: "task-2b")
        try roundTrip(taskID)
        try roundTrip(TicketTaskCompletion.pending)
        try roundTrip(TicketTaskCompletion.completed)
        try roundTrip(TicketTaskLifecycle.active)
        try roundTrip(TicketTaskLifecycle.superseded)
        try roundTrip(TicketTaskDraft(id: taskID, label: "Task 2B", title: "Persist tasks", sortOrder: 2))
        try roundTrip(TicketTaskDefinitionRevision(id: taskID, title: "Persist task history", sortOrder: 3))
        try roundTrip(TicketTaskPlanRecord(
            projectID: .init(rawValue: "project-1"),
            ticketID: .init(rawValue: "RR-R10"),
            revision: 2,
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        try roundTrip(TicketTaskRecord(
            projectID: .init(rawValue: "project-1"),
            ticketID: .init(rawValue: "RR-R10"),
            id: taskID,
            label: "Task 2B",
            title: "Persist tasks",
            sortOrder: 2,
            completion: .completed,
            lifecycle: .superseded,
            createdAt: createdAt,
            updatedAt: createdAt,
            completedAt: createdAt,
            supersededAt: createdAt
        ))
        XCTAssertEqual(TicketTaskCompletion.allCases, [.pending, .completed])
        XCTAssertEqual(TicketTaskLifecycle.allCases, [.active, .superseded])
        XCTAssertEqual(AuditEntityType.ticketTaskPlan.rawValue, "ticket_task_plan")
        XCTAssertEqual(AuditEntityType.phasePlan.rawValue, "phase_plan")
        XCTAssertEqual(AuditEntityType.deliveryGoal.rawValue, "delivery_goal")
    }

    func testExactVersionElevenFixtureMigratesToVersionTwelveWithoutInference() async throws {
        let databaseURL = try copyVerifiedVersionElevenFixture()
        let legacy = try SQLiteConnection(url: databaseURL)
        try seedCompleteVersionElevenGraph(legacy)
        let beforeMigration = try semanticVersionElevenSnapshot(legacy)

        var migrated: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await migrated!.availability else {
            return XCTFail("Expected the exact v11 fixture to migrate")
        }
        try assertVersionTwelveStore(
            databaseURL,
            expectedVersionElevenSnapshot: beforeMigration,
            expectedTaskPlanCount: 0,
            expectedTaskCount: 0
        )

        migrated = nil
        let relaunched = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await relaunched.availability else {
            return XCTFail("Expected migrated v12 fixture to relaunch")
        }
        try assertVersionTwelveStore(
            databaseURL,
            expectedVersionElevenSnapshot: beforeMigration,
            expectedTaskPlanCount: 0,
            expectedTaskCount: 0
        )
    }

    func testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await store.availability else {
            return XCTFail("Expected schema-v12 store")
        }
        let connection = try SQLiteConnection(url: databaseURL)
        try seedVersionTwelveTaskOwners(connection)
        try insertTaskPlan(connection, projectID: "p1", ticketID: "ticket-1")
        try insertTaskPlan(connection, projectID: "p1", ticketID: "ticket-2")
        try insertTaskPlan(connection, projectID: "p2", ticketID: "ticket-3")
        try insertTask(
            connection,
            projectID: "p1",
            ticketID: "ticket-1",
            id: "task-1",
            label: "B",
            title: "Pending active",
            sortOrder: 1
        )
        try insertTask(
            connection,
            projectID: "p1",
            ticketID: "ticket-1",
            id: "task-2",
            label: "A",
            title: "Completed superseded",
            sortOrder: 0,
            completion: "completed",
            lifecycle: "superseded",
            completedAt: "2026-08-30T11:00:00Z",
            supersededAt: "2026-08-30T12:00:00Z"
        )
        try insertTask(
            connection,
            projectID: "p1",
            ticketID: "ticket-1",
            id: "task-3",
            label: "A2",
            title: "Ordering A2",
            sortOrder: 1
        )
        try insertTask(
            connection,
            projectID: "p1",
            ticketID: "ticket-1",
            id: "task-0",
            label: "A",
            title: "Duplicate label probe",
            sortOrder: 1,
            expectSuccess: false
        )
        try insertTask(
            connection,
            projectID: "p1",
            ticketID: "ticket-2",
            id: "task-1",
            label: "B",
            title: "Same identity in another plan",
            sortOrder: 0
        )

        for (projectID, ticketID, id, label, title, sortOrder, completion, lifecycle, completedAt, supersededAt) in [
            ("p2", "ticket-1", "cross-project", "cross-project", "Cross project", 0, "pending", "active", nil, nil),
            ("p1", "ticket-3", "cross-ticket", "cross-ticket", "Cross ticket", 0, "pending", "active", nil, nil),
            ("p1", "ticket-1", "", "empty-id", "Empty id", 0, "pending", "active", nil, nil),
            ("p1", "ticket-1", "task-1", "duplicate-id", "Duplicate id", 0, "pending", "active", nil, nil),
            ("p1", "ticket-1", "empty-label", "", "Empty label", 0, "pending", "active", nil, nil),
            ("p1", "ticket-1", "empty-title", "empty-title", "", 0, "pending", "active", nil, nil),
            ("p1", "ticket-1", "negative-order", "negative-order", "Negative", -1, "pending", "active", nil, nil),
            ("p1", "ticket-1", "bad-completion", "bad-completion", "Bad", 0, "unknown", "active", nil, nil),
            ("p1", "ticket-1", "bad-lifecycle", "bad-lifecycle", "Bad", 0, "pending", "unknown", nil, nil),
            ("p1", "ticket-1", "pending-stamped", "pending-stamped", "Bad", 0, "pending", "active", "2026-08-30T11:00:00Z", nil),
            ("p1", "ticket-1", "completed-unstamped", "completed-unstamped", "Bad", 0, "completed", "active", nil, nil),
            ("p1", "ticket-1", "active-stamped", "active-stamped", "Bad", 0, "pending", "active", nil, "2026-08-30T11:00:00Z"),
            ("p1", "ticket-1", "superseded-unstamped", "superseded-unstamped", "Bad", 0, "pending", "superseded", nil, nil),
        ] {
            try insertTask(
                connection,
                projectID: projectID,
                ticketID: ticketID,
                id: id,
                label: label,
                title: title,
                sortOrder: sortOrder,
                completion: completion,
                lifecycle: lifecycle,
                completedAt: completedAt,
                supersededAt: supersededAt,
                expectSuccess: false
            )
        }
        XCTAssertThrowsError(try connection.execute(
            "INSERT INTO ticket_task_plans (project_id, ticket_id, revision, created_at, updated_at) VALUES ('p1', 'ticket-1', 0, 't', 't')"
        ))
        for (id, createdAt, updatedAt, completedAt, supersededAt, completion, lifecycle) in [
            ("bad-updated", "2026-08-30T10:00:00Z", "2026-08-30T09:00:00Z", nil, nil, "pending", "active"),
            ("bad-completed-time", "2026-08-30T10:00:00Z", "2026-08-30T10:00:00Z", "2026-08-30T09:00:00Z", nil, "completed", "active"),
            ("bad-superseded-time", "2026-08-30T10:00:00Z", "2026-08-30T10:00:00Z", nil, "2026-08-30T09:00:00Z", "pending", "superseded"),
        ] {
            XCTAssertThrowsError(try connection.execute(
                """
                INSERT INTO ticket_tasks
                    (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle,
                     created_at, updated_at, completed_at, superseded_at)
                VALUES ('p1', 'ticket-1', ?, ?, 'Bad timestamp', 0, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [.text(id), .text(id), .text(completion), .text(lifecycle), .text(createdAt),
                           .text(updatedAt), completedAt.map(SQLiteValue.text) ?? .null,
                           supersededAt.map(SQLiteValue.text) ?? .null]
            ))
        }

        let asciiLimits = [255, 256, 257]
        let multibyteLimits = [String(repeating: "é", count: 127) + "a", String(repeating: "é", count: 128), String(repeating: "é", count: 128) + "a"]
        for (index, byteCount) in asciiLimits.enumerated() {
            try probeTaskTextBoundary(connection, field: "id", value: String(repeating: "i", count: byteCount), discriminator: "ascii-id-\(index)", expectSuccess: byteCount <= 256)
            try probeTaskTextBoundary(connection, field: "label", value: String(repeating: "l", count: byteCount), discriminator: "ascii-label-\(index)", expectSuccess: byteCount <= 256)
        }
        for (index, value) in multibyteLimits.enumerated() {
            try probeTaskTextBoundary(connection, field: "id", value: value, discriminator: "utf8-id-\(index)", expectSuccess: value.utf8.count <= 256)
            try probeTaskTextBoundary(connection, field: "label", value: value, discriminator: "utf8-label-\(index)", expectSuccess: value.utf8.count <= 256)
        }
        for (index, byteCount) in [4095, 4096, 4097].enumerated() {
            try probeTaskTextBoundary(connection, field: "title", value: String(repeating: "t", count: byteCount), discriminator: "ascii-title-\(index)", expectSuccess: byteCount <= 4096)
        }
        let multibyteTitles = [String(repeating: "é", count: 2047) + "a", String(repeating: "é", count: 2048), String(repeating: "é", count: 2048) + "a"]
        for (index, value) in multibyteTitles.enumerated() {
            try probeTaskTextBoundary(connection, field: "title", value: value, discriminator: "utf8-title-\(index)", expectSuccess: value.utf8.count <= 4096)
        }

        XCTAssertThrowsError(try connection.execute("UPDATE ticket_tasks SET id = 'changed' WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'task-1'"))
        XCTAssertThrowsError(try connection.execute("UPDATE ticket_tasks SET ticket_id = 'ticket-2' WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'task-1'"))
        XCTAssertThrowsError(try connection.execute("UPDATE ticket_tasks SET project_id = 'p2', ticket_id = 'ticket-3' WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'task-1'"))
        XCTAssertThrowsError(try connection.execute("UPDATE ticket_tasks SET label = 'changed' WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'task-1'"))
        XCTAssertEqual(
            try connection.scalarText("SELECT group_concat(id, ',') FROM (SELECT id FROM ticket_tasks WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND lifecycle = 'active' ORDER BY sort_order, label COLLATE BINARY, id COLLATE BINARY LIMIT 2)"),
            "task-3,task-1"
        )
        XCTAssertEqual(try connection.scalarText("SELECT completed_at FROM ticket_tasks WHERE id = 'task-2'"), "2026-08-30T11:00:00Z")
        XCTAssertEqual(try connection.scalarText("SELECT superseded_at FROM ticket_tasks WHERE id = 'task-2'"), "2026-08-30T12:00:00Z")
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
    }

    func testVersionTwelveTaskHistoryCannotBeDeletedOrCascaded() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await store.availability else {
            return XCTFail("Expected schema-v12 store")
        }
        let connection = try SQLiteConnection(url: databaseURL)
        try seedVersionTwelveTaskOwners(connection)
        try insertTaskPlan(connection, projectID: "p1", ticketID: "ticket-1")
        try insertTask(connection, projectID: "p1", ticketID: "ticket-1", id: "pending", label: "Pending", title: "Pending", sortOrder: 0)
        try insertTask(connection, projectID: "p1", ticketID: "ticket-1", id: "completed", label: "Completed", title: "Completed", sortOrder: 1, completion: "completed", completedAt: "2026-08-30T11:00:00Z")
        try insertTask(connection, projectID: "p1", ticketID: "ticket-1", id: "superseded", label: "Superseded", title: "Superseded", sortOrder: 2, lifecycle: "superseded", supersededAt: "2026-08-30T11:00:00Z")
        let before = try taskHistorySnapshot(connection, projectID: "p1", ticketID: "ticket-1")

        for sql in [
            "DELETE FROM ticket_tasks WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'pending'",
            "DELETE FROM ticket_tasks WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'completed'",
            "DELETE FROM ticket_tasks WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND id = 'superseded'",
            "DELETE FROM ticket_task_plans WHERE project_id = 'p1' AND ticket_id = 'ticket-1'",
            "DELETE FROM tickets WHERE project_id = 'p1' AND id = 'ticket-1'",
            "DELETE FROM projects WHERE id = 'p1'",
        ] {
            XCTAssertThrowsError(try connection.execute(sql), "Expected history deletion rejection for \(sql)")
            XCTAssertEqual(try taskHistorySnapshot(connection, projectID: "p1", ticketID: "ticket-1"), before)
        }

        try connection.execute("DELETE FROM tickets WHERE project_id = 'p1' AND id = 'ticket-2'")
        try connection.execute("DELETE FROM projects WHERE id = 'p2'")
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'ticket-2'"), 0)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'p2'"), 0)
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
    }

    func testVersionTwelveManifestRejectsMissingOrCounterfeitTaskObjects() async throws {
        for object in [
            "ticket_tasks",
            "ticket_task_plans",
            "ticket_task_plans_ticket_unique",
            "ticket_tasks_label_unique",
            "ticket_tasks_active_order_index",
            "ticket_tasks_reject_identity_update",
            "ticket_tasks_reject_label_update",
            "ticket_task_plans_reject_delete",
            "ticket_tasks_reject_delete",
            "ticket_task_plans_reject_ticket_delete",
            "ticket_task_plans_reject_project_delete",
        ] {
            let databaseURL = try makeVersionTwelveDatabaseURL()
            do {
                let connection = try SQLiteConnection(url: databaseURL)
                try connection.execute("PRAGMA foreign_keys = OFF")
                let type = try XCTUnwrap(connection.scalarText("SELECT type FROM sqlite_schema WHERE name = ?", bindings: [.text(object)]))
                try connection.execute("DROP \(type.uppercased()) \(object)")
            }
            await assertMigrationUnavailable(databaseURL: databaseURL)
        }

        let counterfeitTableURL = try makeVersionTwelveDatabaseURL()
        do {
            let connection = try SQLiteConnection(url: counterfeitTableURL)
            try reconstructEmptyVersionTwelveTable(
                connection,
                table: "ticket_tasks",
                dependentObjects: [
                    "ticket_tasks_label_unique",
                    "ticket_tasks_active_order_index",
                    "ticket_tasks_reject_identity_update",
                    "ticket_tasks_reject_label_update",
                    "ticket_tasks_reject_delete",
                ],
                sql: """
                CREATE TABLE ticket_tasks (
                    project_id TEXT NOT NULL, ticket_id TEXT NOT NULL, id TEXT NOT NULL,
                    label TEXT NOT NULL, title TEXT NOT NULL, sort_order INTEGER NOT NULL,
                    completion TEXT NOT NULL, lifecycle TEXT NOT NULL, created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL, completed_at TEXT, superseded_at TEXT,
                    PRIMARY KEY(project_id, ticket_id, id),
                    CHECK ('length(CAST(id AS BLOB)) BETWEEN 1 AND 256 FOREIGN KEY ticket_task_plans' <> '')
                )
                """
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'ticket_tasks'"),
                1
            )
        }
        await assertMigrationUnavailable(databaseURL: counterfeitTableURL)

        let counterfeitTriggerURL = try makeVersionTwelveDatabaseURL()
        do {
            let connection = try SQLiteConnection(url: counterfeitTriggerURL)
            try connection.execute("DROP TRIGGER IF EXISTS ticket_tasks_reject_delete")
            try connection.executeScript(
                """
                CREATE TRIGGER ticket_tasks_reject_delete BEFORE DELETE ON ticket_tasks BEGIN
                    SELECT CASE WHEN 'ticket task history cannot be deleted' = ''
                        THEN RAISE(ABORT, 'ticket task history cannot be deleted') END;
                END;
                """
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'trigger' AND name = 'ticket_tasks_reject_delete'"),
                1
            )
        }
        await assertMigrationUnavailable(databaseURL: counterfeitTriggerURL)

        let missingPlanForeignKeyURL = try makeVersionTwelveDatabaseURL()
        do {
            let connection = try SQLiteConnection(url: missingPlanForeignKeyURL)
            try reconstructEmptyVersionTwelveTable(
                connection,
                table: "ticket_task_plans",
                dependentObjects: [
                    "ticket_task_plans_ticket_unique",
                    "ticket_task_plans_reject_delete",
                ],
                sql: """
                CREATE TABLE ticket_task_plans (
                    project_id TEXT NOT NULL, ticket_id TEXT NOT NULL,
                    revision INTEGER NOT NULL CHECK (revision > 0), created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL, PRIMARY KEY(project_id, ticket_id),
                    FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE NO ACTION
                )
                """
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'ticket_task_plans'"),
                1
            )
        }
        await assertMigrationUnavailable(databaseURL: missingPlanForeignKeyURL)

        let missingTaskForeignKeyURL = try makeVersionTwelveDatabaseURL()
        do {
            let connection = try SQLiteConnection(url: missingTaskForeignKeyURL)
            try reconstructEmptyVersionTwelveTable(
                connection,
                table: "ticket_tasks",
                dependentObjects: [
                    "ticket_tasks_label_unique",
                    "ticket_tasks_active_order_index",
                    "ticket_tasks_reject_identity_update",
                    "ticket_tasks_reject_label_update",
                    "ticket_tasks_reject_delete",
                ],
                sql: """
                CREATE TABLE ticket_tasks (
                    project_id TEXT NOT NULL, ticket_id TEXT NOT NULL,
                    id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
                    label TEXT NOT NULL CHECK (length(CAST(label AS BLOB)) BETWEEN 1 AND 256),
                    title TEXT NOT NULL CHECK (length(CAST(title AS BLOB)) BETWEEN 1 AND 4096),
                    sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
                    completion TEXT NOT NULL CHECK (completion IN ('pending', 'completed')),
                    lifecycle TEXT NOT NULL CHECK (lifecycle IN ('active', 'superseded')),
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, completed_at TEXT, superseded_at TEXT,
                    PRIMARY KEY(project_id, ticket_id, id),
                    CHECK ((completion = 'completed') = (completed_at IS NOT NULL)),
                    CHECK ((lifecycle = 'superseded') = (superseded_at IS NOT NULL)),
                    CHECK (completed_at IS NULL OR completed_at >= created_at),
                    CHECK (superseded_at IS NULL OR superseded_at >= created_at),
                    CHECK (updated_at >= created_at)
                )
                """
            )
            XCTAssertEqual(
                try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'ticket_tasks'"),
                1
            )
        }
        await assertMigrationUnavailable(databaseURL: missingTaskForeignKeyURL)

        var acceptedCounterfeitMarkers: [String] = []
        let partialLabelIndexURL = try makeVersionTwelveDatabaseURL()
        do {
            let connection = try SQLiteConnection(url: partialLabelIndexURL)
            try connection.execute("DROP INDEX ticket_tasks_label_unique")
            try connection.execute(
                """
                CREATE UNIQUE INDEX ticket_tasks_label_unique
                ON ticket_tasks(project_id, ticket_id, label COLLATE BINARY)
                WHERE lifecycle = 'active'
                """
            )
            XCTAssertEqual(
                try connection.scalarInt(
                    """
                    SELECT COUNT(*) FROM pragma_index_list('ticket_tasks')
                    WHERE name = 'ticket_tasks_label_unique' AND "unique" = 1 AND partial = 1
                    """
                ),
                1
            )
            XCTAssertEqual(
                try connection.scalarText(
                    "SELECT coll FROM pragma_index_xinfo('ticket_tasks_label_unique') WHERE key = 1 AND seqno = 2"
                ),
                "BINARY"
            )
        }
        let partialLabelIndexStore = DeliveryStore(databaseURL: partialLabelIndexURL)
        if case let .unavailable(recovery) = await partialLabelIndexStore.availability {
            XCTAssertEqual(recovery.kind, .migration)
            XCTAssertEqual(recovery.originalDatabaseURL, partialLabelIndexURL)
            XCTAssertNotNil(recovery.preMigrationSnapshotURL)
        } else {
            acceptedCounterfeitMarkers.append(
                "RR_TASK2B_INDEX_MANIFEST_RED_PARTIAL_ACCEPTED"
            )
        }

        let noCaseLabelIndexURL = try makeVersionTwelveDatabaseURL()
        do {
            let connection = try SQLiteConnection(url: noCaseLabelIndexURL)
            try connection.execute("DROP INDEX ticket_tasks_label_unique")
            try connection.execute(
                """
                CREATE UNIQUE INDEX ticket_tasks_label_unique
                ON ticket_tasks(project_id, ticket_id, label COLLATE NOCASE)
                """
            )
            XCTAssertEqual(
                try connection.scalarInt(
                    """
                    SELECT COUNT(*) FROM pragma_index_list('ticket_tasks')
                    WHERE name = 'ticket_tasks_label_unique' AND "unique" = 1 AND partial = 0
                    """
                ),
                1
            )
            XCTAssertEqual(
                try connection.scalarText(
                    "SELECT coll FROM pragma_index_xinfo('ticket_tasks_label_unique') WHERE key = 1 AND seqno = 2"
                ),
                "NOCASE"
            )
        }
        let noCaseLabelIndexStore = DeliveryStore(databaseURL: noCaseLabelIndexURL)
        if case let .unavailable(recovery) = await noCaseLabelIndexStore.availability {
            XCTAssertEqual(recovery.kind, .migration)
            XCTAssertEqual(recovery.originalDatabaseURL, noCaseLabelIndexURL)
            XCTAssertNotNil(recovery.preMigrationSnapshotURL)
        } else {
            acceptedCounterfeitMarkers.append(
                "RR_TASK2B_INDEX_MANIFEST_RED_NOCASE_ACCEPTED"
            )
        }
        if !acceptedCounterfeitMarkers.isEmpty {
            XCTFail(acceptedCounterfeitMarkers.joined(separator: " "))
        }
    }

    func testVersionTwelveMigrationFailureRollsBackToExactVersionElevenStateAndRecovers() async throws {
        let databaseURL = try copyVerifiedVersionElevenFixture()
        let legacy = try SQLiteConnection(url: databaseURL)
        try seedCompleteVersionElevenGraph(legacy)
        let beforeMigration = try semanticVersionElevenSnapshot(legacy)
        try legacy.executeScript("""
        CREATE TRIGGER ticket_task_plans_reject_ticket_delete
        BEFORE DELETE ON tickets
        BEGIN
            SELECT RAISE(ABORT, 'task2b injected late v12 collision');
        END;
        """)

        let failed = DeliveryStore(databaseURL: databaseURL)
        guard case let .unavailable(recovery) = await failed.availability else {
            return XCTFail("Expected injected late-v12 migration failure")
        }
        XCTAssertEqual(recovery.kind, .migration)
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        for recoverableURL in [databaseURL, snapshotURL] {
            let connection = try SQLiteConnection(url: recoverableURL)
            XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 11)
            XCTAssertEqual(try semanticVersionElevenSnapshot(connection), beforeMigration)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'trigger' AND name = 'ticket_task_plans_reject_ticket_delete'"), 1)
            XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE name IN ('ticket_task_plans', 'ticket_tasks', 'ticket_task_plans_ticket_unique', 'ticket_tasks_label_unique', 'ticket_tasks_active_order_index')"), 0)
        }

        try SQLiteConnection(url: databaseURL).execute("DROP TRIGGER ticket_task_plans_reject_ticket_delete")
        var recovered: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await recovered!.availability else {
            return XCTFail("Expected migration after removing only the collision")
        }
        try assertVersionTwelveStore(databaseURL, expectedVersionElevenSnapshot: beforeMigration, expectedTaskPlanCount: 0, expectedTaskCount: 0)
        recovered = nil
        guard case .available = await DeliveryStore(databaseURL: databaseURL).availability else {
            return XCTFail("Expected recovered v12 store to relaunch")
        }
        try assertVersionTwelveStore(databaseURL, expectedVersionElevenSnapshot: beforeMigration, expectedTaskPlanCount: 0, expectedTaskCount: 0)

        let futureURL = try copyVerifiedVersionElevenFixture()
        let futureLegacy = try SQLiteConnection(url: futureURL)
        try seedCompleteVersionElevenGraph(futureLegacy)
        _ = DeliveryStore(databaseURL: futureURL)
        let future = try SQLiteConnection(url: futureURL)
        try insertTaskPlan(future, projectID: "project-main", ticketID: "ticket-active")
        try insertTask(future, projectID: "project-main", ticketID: "ticket-active", id: "future-task", label: "Future", title: "Future version preservation", sortOrder: 0)
        let futureV11Snapshot = try semanticVersionElevenSnapshot(future)
        let futureTaskSnapshot = try taskTableSnapshot(future)
        try future.execute("PRAGMA user_version = 13")
        let unsupported = DeliveryStore(databaseURL: futureURL)
        guard case let .unavailable(futureRecovery) = await unsupported.availability else {
            return XCTFail("Expected schema-v13 rejection")
        }
        XCTAssertEqual(futureRecovery.kind, .migration)
        let afterUnsupported = try SQLiteConnection(url: futureURL)
        XCTAssertEqual(try afterUnsupported.scalarInt("PRAGMA user_version"), 13)
        XCTAssertEqual(try semanticVersionElevenSnapshot(afterUnsupported), futureV11Snapshot)
        XCTAssertEqual(try taskTableSnapshot(afterUnsupported), futureTaskSnapshot)
        XCTAssertNil(try afterUnsupported.row("PRAGMA foreign_key_check"))
    }

    func testExactVersionTenFixtureMigratesToVersionElevenWithoutInference() async throws {
        let databaseURL = try copyVerifiedVersionTenFixture()
        let fixture = try SQLiteConnection(url: databaseURL)
        try seedCompleteVersionTenGraph(fixture)
        let beforeMigration = try semanticVersionTenSnapshot(fixture)

        var migrated: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await migrated!.availability else {
            return XCTFail("Expected the exact v10 fixture to migrate")
        }
        let firstRead = try await migrated!.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phase_plans WHERE state = 'legacy_unassessed' AND revision = 0 AND ready_revision IS NULL"),
                try connection.scalarInt("SELECT COUNT(DISTINCT created_at) FROM phase_plans"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_plans WHERE created_at = updated_at AND finalized_at IS NULL"),
                try connection.scalarInt("SELECT COUNT(*) FROM delivery_goals"),
                try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_done_criteria"),
                try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_ticket_assignments"),
                try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_assignment_events"),
                try connection.scalarText("SELECT group_concat(id, ',') FROM (SELECT id FROM tickets WHERE plan_legacy_continuation = 1 ORDER BY id)"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE lane IN ('backlog', 'blocked', 'accepted') AND plan_legacy_continuation <> 0")
            )
        }
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(firstRead.0, 2)
        XCTAssertEqual(firstRead.1, 1)
        XCTAssertEqual(firstRead.2, 2)
        XCTAssertEqual(firstRead.3, 0)
        XCTAssertEqual(firstRead.4, 0)
        XCTAssertEqual(firstRead.5, 0)
        XCTAssertEqual(firstRead.6, 0)
        XCTAssertEqual(firstRead.7, "ticket-active,ticket-review")
        XCTAssertEqual(firstRead.8, 0)
        XCTAssertEqual(try semanticVersionTenSnapshot(SQLiteConnection(url: databaseURL)), beforeMigration)
        XCTAssertNil(try SQLiteConnection(url: databaseURL).row("PRAGMA foreign_key_check"))

        migrated = nil
        let relaunched = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await relaunched.availability else {
            return XCTFail("Expected migrated current-schema fixture to relaunch")
        }
        XCTAssertEqual(try semanticVersionTenSnapshot(SQLiteConnection(url: databaseURL)), beforeMigration)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("SELECT COUNT(*) FROM phase_plans"), 2)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("SELECT COUNT(*) FROM delivery_goals"), 0)
        XCTAssertNil(try SQLiteConnection(url: databaseURL).row("PRAGMA foreign_key_check"))
    }

    func testVersionElevenPlanningSchemaEnforcesConstraintsAndCompositeOwnership() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let connection = try SQLiteConnection(url: databaseURL)
        try connection.executeScript(Self.versionElevenOwnershipSeedSQL)

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "planner"), reason: "Reject goal phase move") { connection in
                try connection.execute("UPDATE delivery_goals SET title = 'Tentative', phase_id = 'phase-2' WHERE project_id = 'p1' AND id = 'goal-1'")
            }
        }
        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "planner"), reason: "Reject goal project move") { connection in
                try connection.execute("UPDATE delivery_goals SET title = 'Tentative', project_id = 'p2', phase_id = 'phase-3' WHERE project_id = 'p1' AND id = 'goal-1'")
            }
        }
        let unchangedGoal = try await store.read { connection in
            try connection.row("SELECT project_id, phase_id, title FROM delivery_goals WHERE project_id = 'p1' AND id = 'goal-1'")
        }
        XCTAssertEqual(unchangedGoal?["project_id"], .text("p1"))
        XCTAssertEqual(unchangedGoal?["phase_id"], .text("phase-1"))
        XCTAssertEqual(unchangedGoal?["title"], .text("Goal one"))
        let ownershipAuditCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason IN ('Reject goal phase move', 'Reject goal project move')")
        }
        XCTAssertEqual(ownershipAuditCount, 0)

        for sql in [
            "INSERT INTO phase_plans (project_id, phase_id, state, revision, created_at, updated_at) VALUES ('p1', 'missing', 'draft', 0, 't', 't')",
            "UPDATE phase_plans SET state = 'invalid' WHERE project_id = 'p1' AND phase_id = 'phase-1'",
            "UPDATE phase_plans SET revision = -1 WHERE project_id = 'p1' AND phase_id = 'phase-1'",
            "UPDATE phase_plans SET state = 'ready', ready_revision = NULL WHERE project_id = 'p1' AND phase_id = 'phase-1'",
            "UPDATE phase_plans SET state = 'draft', ready_revision = 0 WHERE project_id = 'p1' AND phase_id = 'phase-1'",
            "UPDATE phase_plans SET state = 'ready', revision = 1, ready_revision = 0 WHERE project_id = 'p1' AND phase_id = 'phase-1'",
            "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('p1', 'phase-1', 'bad-life', 'Bad', 'Bad', 'unknown', 0, 't', 't')",
            "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('p1', 'phase-1', 'bad-sort', 'Bad', 'Bad', 'draft', -1, 't', 't')",
            "INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('p1', 'phase-1', 'goal-1', -1, 'Bad')",
            "INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('p1', 'phase-1', 'goal-1', 1, '   ')",
            "INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('p1', 'phase-2', 'goal-1', 1, 'Wrong phase')",
            "INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('p1', 'phase-1', 'goal-1', 'ticket-2')",
            "INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('p2', 'phase-3', 'goal-3', 'ticket-1')",
        ] {
            XCTAssertThrowsError(try connection.execute(sql), "Expected schema to reject: \(sql)")
        }

        try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('p1', 'phase-1', 'goal-1', 0, 'Complete')")
        XCTAssertThrowsError(
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('p1', 'phase-1', 'goal-1', 0, 'Duplicate')")
        )
        try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('p1', 'phase-1', 'goal-1', 'ticket-1')")
        XCTAssertThrowsError(
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('p1', 'phase-1', 'goal-1b', 'ticket-1')")
        )
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_done_criteria"), 1)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM delivery_goal_ticket_assignments"), 1)
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
    }

    func testVersionElevenAssignmentHistoryRequiresTheAuthoritativeDeferredAudit() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed planning history") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('p1', 'Project One')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'p1', 'One'), ('phase-2', 'p1', 'Two')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ticket-1', 'p1', 'phase-1', 'One', 'backlog'), ('ticket-2', 'p1', 'phase-2', 'Two', 'backlog')")
            try connection.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('p1', 'phase-1', 'goal-1', 'Goal one', 'Outcome one', 'draft', 0, 't', 't'), ('p1', 'phase-2', 'goal-2', 'Goal two', 'Outcome two', 'draft', 0, 't', 't')")
        }
        let auditID = AuditEventID(rawValue: "assignment-audit")
        try await store.transact(
            actor: .init(id: "planner"),
            reason: "Assign ticket",
            auditEventID: auditID,
            auditScope: .init(projectID: .init(rawValue: "p1"), entityType: .phasePlan, entityID: "phase-1")
        ) { connection in
            try connection.execute(
                """
                INSERT INTO delivery_goal_assignment_events
                    (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action)
                VALUES (?, 'p1', 'phase-1', 'ticket-1', NULL, 'goal-1', 1, 'assigned')
                """,
                bindings: [.text(auditID.rawValue)]
            )
        }
        let committed = try await store.read { connection in
            try connection.scalarInt(
                """
                SELECT COUNT(*)
                FROM delivery_goal_assignment_events AS assignment_event
                JOIN audit_events AS audit ON audit.id = assignment_event.audit_event_id
                WHERE assignment_event.audit_event_id = 'assignment-audit'
                  AND audit.entity_type = 'phase_plan'
                """
            )
        }
        XCTAssertEqual(committed, 1)

        let raw = try SQLiteConnection(url: databaseURL)
        try raw.execute("BEGIN IMMEDIATE TRANSACTION")
        try raw.execute(
            """
            INSERT INTO delivery_goal_assignment_events
                (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action)
            VALUES ('missing-audit', 'p1', 'phase-1', 'ticket-1', 'goal-1', NULL, 2, 'unassigned')
            """
        )
        XCTAssertThrowsError(try raw.execute("COMMIT"))
        try? raw.execute("ROLLBACK")
        XCTAssertEqual(try raw.scalarInt("SELECT COUNT(*) FROM delivery_goal_assignment_events"), 1)

        let invalidEventAuditIDs = (1...6).map { AuditEventID(rawValue: "bad-\($0)") }
        for auditID in invalidEventAuditIDs {
            try await store.transact(
                actor: .init(id: "constraint-probe"),
                reason: "Authorize isolated assignment-event constraint probe",
                auditEventID: auditID
            ) { _ in }
        }
        XCTAssertEqual(
            try raw.scalarInt(
                "SELECT COUNT(*) FROM audit_events WHERE id IN ('bad-1', 'bad-2', 'bad-3', 'bad-4', 'bad-5', 'bad-6')"
            ),
            6
        )

        for (sql, expectedFailure) in [
            ("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('bad-1', 'p1', 'phase-1', 'ticket-1', NULL, NULL, 2, 'assigned')", "CHECK constraint failed"),
            ("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('bad-2', 'p1', 'phase-1', 'ticket-1', NULL, 'goal-1', -1, 'assigned')", "CHECK constraint failed"),
            ("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('bad-3', 'p1', 'phase-1', 'ticket-1', 'goal-1', 'goal-1', 2, 'reassigned')", "CHECK constraint failed"),
            ("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('bad-4', 'p1', 'phase-1', 'ticket-1', 'goal-1', NULL, 2, 'unknown')", "CHECK constraint failed"),
            ("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('bad-5', 'p1', 'phase-1', 'ticket-2', NULL, 'goal-1', 2, 'assigned')", "FOREIGN KEY constraint failed"),
            ("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('bad-6', 'p1', 'phase-1', 'ticket-1', NULL, 'goal-2', 2, 'assigned')", "FOREIGN KEY constraint failed"),
        ] {
            XCTAssertThrowsError(try raw.execute(sql)) { error in
                XCTAssertTrue(error.localizedDescription.contains(expectedFailure), "Unexpected failure: \(error)")
            }
        }
        XCTAssertEqual(try raw.scalarInt("SELECT COUNT(*) FROM delivery_goal_assignment_events"), 1)
        XCTAssertNil(try raw.row("PRAGMA foreign_key_check"))
    }

    func testVersionElevenPhaseInsertCreatesOneLegacyUnassessedPlan() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await store.transact(actor: .init(id: "fixture"), reason: "Create future phase") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('p1', 'Project')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'p1', 'Future')")
        }
        let plan = try await store.read { connection in
            try connection.row(
                "SELECT state, revision, ready_revision, created_at, updated_at, finalized_at FROM phase_plans WHERE project_id = 'p1' AND phase_id = 'phase-1'"
            )
        }
        XCTAssertEqual(plan?["state"], .text("legacy_unassessed"))
        XCTAssertEqual(plan?["revision"], .integer(0))
        XCTAssertEqual(plan?["ready_revision"], .null)
        XCTAssertEqual(plan?["created_at"], plan?["updated_at"])
        XCTAssertEqual(plan?["finalized_at"], .null)
        let count = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM phase_plans") }
        XCTAssertEqual(count, 1)
    }

    func testVersionElevenContinuationCanOnlyBeGrantedByMigration() async throws {
        let databaseURL = try copyVerifiedVersionTenFixture()
        let legacy = try SQLiteConnection(url: databaseURL)
        try legacy.executeScript("""
        INSERT INTO projects (id, name) VALUES ('p1', 'Project');
        INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'p1', 'Phase');
        INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
            ('active', 'p1', 'phase-1', 'Active', 'in_progress'),
            ('review', 'p1', 'phase-1', 'Review', 'needs_review'),
            ('blocked', 'p1', 'phase-1', 'Blocked', 'blocked'),
            ('backlog', 'p1', 'phase-1', 'Backlog', 'backlog'),
            ('accepted', 'p1', 'phase-1', 'Accepted', 'accepted');
        """)
        let store = DeliveryStore(databaseURL: databaseURL)
        let initial = try await store.read {
            try $0.scalarText("SELECT group_concat(id, ',') FROM (SELECT id FROM tickets WHERE plan_legacy_continuation = 1 ORDER BY id)")
        }
        XCTAssertEqual(initial, "active,review")

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "fixture"), reason: "Reject continuation insert") { connection in
                try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane, plan_legacy_continuation) VALUES ('new', 'p1', 'phase-1', 'New', 'backlog', 1)")
            }
        }
        try await store.transact(actor: .init(id: "fixture"), reason: "Clear continuation") { connection in
            try connection.execute("UPDATE tickets SET plan_legacy_continuation = 0 WHERE id = 'active'")
        }
        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "fixture"), reason: "Reject continuation regrant") { connection in
                try connection.execute("UPDATE tickets SET plan_legacy_continuation = 1 WHERE id = 'active'")
            }
        }
        let final = try await store.read {
            (
                try $0.scalarText("SELECT group_concat(id, ',') FROM (SELECT id FROM tickets WHERE plan_legacy_continuation = 1 ORDER BY id)"),
                try $0.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'new'")
            )
        }
        XCTAssertEqual(final.0, "review")
        XCTAssertEqual(final.1, 0)
    }

    func testVersionElevenManifestRejectsMissingOrCounterfeitPlanningObjects() async throws {
        let missingIndexURL = try makeVersionElevenDatabaseURL()
        try SQLiteConnection(url: missingIndexURL).execute("DROP INDEX delivery_goals_project_phase_identity_unique")
        await assertMigrationUnavailable(databaseURL: missingIndexURL)

        let counterfeitTriggerURL = try makeVersionElevenDatabaseURL()
        let counterfeitTrigger = try SQLiteConnection(url: counterfeitTriggerURL)
        try counterfeitTrigger.execute("DROP TRIGGER phase_plans_after_phase_insert")
        try counterfeitTrigger.executeScript("""
        CREATE TRIGGER phase_plans_after_phase_insert AFTER INSERT ON phases
        BEGIN
            SELECT 1;
        END;
        """)
        await assertMigrationUnavailable(databaseURL: counterfeitTriggerURL)

        let immediateAuditURL = try makeVersionElevenDatabaseURL()
        let immediateAudit = try SQLiteConnection(url: immediateAuditURL)
        try immediateAudit.executeScript("""
        PRAGMA foreign_keys = OFF;
        DROP INDEX delivery_goal_assignment_events_ticket_revision_unique;
        ALTER TABLE delivery_goal_assignment_events
            RENAME TO delivery_goal_assignment_events_deferred_original;
        CREATE TABLE delivery_goal_assignment_events (
            audit_event_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            phase_id TEXT NOT NULL,
            ticket_id TEXT NOT NULL,
            previous_goal_id TEXT,
            current_goal_id TEXT,
            revision INTEGER NOT NULL CHECK (revision >= 0),
            action TEXT NOT NULL CHECK (action IN ('assigned', 'unassigned', 'reassigned')),
            PRIMARY KEY(audit_event_id, ticket_id),
            FOREIGN KEY(audit_event_id) REFERENCES audit_events(id),
            FOREIGN KEY(project_id, phase_id) REFERENCES phase_plans(project_id, phase_id),
            FOREIGN KEY(project_id, phase_id, ticket_id)
                REFERENCES tickets(project_id, phase_id, id),
            FOREIGN KEY(project_id, phase_id, previous_goal_id)
                REFERENCES delivery_goals(project_id, phase_id, id),
            FOREIGN KEY(project_id, phase_id, current_goal_id)
                REFERENCES delivery_goals(project_id, phase_id, id),
            CHECK (
                (action = 'assigned' AND previous_goal_id IS NULL AND current_goal_id IS NOT NULL)
                OR (action = 'unassigned' AND previous_goal_id IS NOT NULL AND current_goal_id IS NULL)
                OR (
                    action = 'reassigned'
                    AND previous_goal_id IS NOT NULL
                    AND current_goal_id IS NOT NULL
                    AND previous_goal_id <> current_goal_id
                )
            )
        );
        CREATE UNIQUE INDEX delivery_goal_assignment_events_ticket_revision_unique
            ON delivery_goal_assignment_events(project_id, phase_id, ticket_id, revision);
        DROP TABLE delivery_goal_assignment_events_deferred_original;
        PRAGMA foreign_keys = ON;
        """)
        await assertMigrationUnavailable(databaseURL: immediateAuditURL)

        let counterfeitContinuationURL = try makeVersionElevenDatabaseURL()
        do {
            let counterfeitContinuation = try SQLiteConnection(url: counterfeitContinuationURL)
            try counterfeitContinuation.executeScript("""
            PRAGMA foreign_keys = OFF;
            PRAGMA legacy_alter_table = ON;
            DROP TRIGGER tickets_reject_legacy_continuation_regrant;
            DROP TRIGGER tickets_reject_legacy_continuation_insert;
            ALTER TABLE tickets RENAME TO tickets_exact_original;
            CREATE TABLE tickets (
                id TEXT PRIMARY KEY NOT NULL,
                project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                phase_id TEXT NOT NULL,
                outcome TEXT NOT NULL,
                lane TEXT NOT NULL CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
                plan_legacy_continuation INTEGER,
                UNIQUE(project_id, id),
                FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
            );
            INSERT INTO tickets
                (id, project_id, phase_id, outcome, lane, plan_legacy_continuation)
            SELECT id, project_id, phase_id, outcome, lane, plan_legacy_continuation
            FROM tickets_exact_original;
            DROP TABLE tickets_exact_original;
            CREATE UNIQUE INDEX tickets_project_phase_identity_unique
                ON tickets(project_id, phase_id, id);
            CREATE TRIGGER tickets_reject_legacy_continuation_insert
            BEFORE INSERT ON tickets
            WHEN NEW.plan_legacy_continuation = 1
            BEGIN
                SELECT RAISE(ABORT, 'legacy continuation is migration-only');
            END;
            CREATE TRIGGER tickets_reject_legacy_continuation_regrant
            BEFORE UPDATE OF plan_legacy_continuation ON tickets
            WHEN OLD.plan_legacy_continuation = 0 AND NEW.plan_legacy_continuation = 1
            BEGIN
                SELECT RAISE(ABORT, 'legacy continuation cannot be regranted');
            END;
            PRAGMA legacy_alter_table = OFF;
            PRAGMA foreign_keys = ON;
            """)
        }
        do {
            let counterfeitContinuation = try SQLiteConnection(url: counterfeitContinuationURL)
            try counterfeitContinuation.executeScript("""
            INSERT INTO projects (id, name) VALUES ('counterfeit', 'Counterfeit');
            INSERT INTO phases (id, project_id, name) VALUES ('counterfeit-phase', 'counterfeit', 'Counterfeit');
            INSERT INTO tickets
                (id, project_id, phase_id, outcome, lane, plan_legacy_continuation)
            VALUES
                ('counterfeit-ticket', 'counterfeit', 'counterfeit-phase', 'Counterfeit', 'backlog', 2);
            """)
            XCTAssertEqual(
                try counterfeitContinuation.scalarInt(
                    "SELECT plan_legacy_continuation FROM tickets WHERE id = 'counterfeit-ticket'"
                ),
                2
            )
        }
        await assertMigrationUnavailable(databaseURL: counterfeitContinuationURL)

        let semanticCounterfeitContinuationURL = try makeVersionElevenDatabaseURL()
        do {
            let semanticCounterfeitContinuation = try SQLiteConnection(
                url: semanticCounterfeitContinuationURL
            )
            try semanticCounterfeitContinuation.executeScript("""
            PRAGMA foreign_keys = OFF;
            PRAGMA legacy_alter_table = ON;
            DROP TRIGGER tickets_reject_legacy_continuation_regrant;
            DROP TRIGGER tickets_reject_legacy_continuation_insert;
            ALTER TABLE tickets RENAME TO tickets_exact_original;
            CREATE TABLE tickets (
                id TEXT PRIMARY KEY NOT NULL,
                project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                phase_id TEXT NOT NULL,
                outcome TEXT NOT NULL,
                lane TEXT NOT NULL CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
                plan_legacy_continuation INTEGER NOT NULL DEFAULT 0,
                CHECK (
                    'plan_legacy_continuation INTEGER NOT NULL DEFAULT 0 CHECK (plan_legacy_continuation IN (0, 1))' <> ''
                ),
                UNIQUE(project_id, id),
                FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
            );
            INSERT INTO tickets
                (id, project_id, phase_id, outcome, lane, plan_legacy_continuation)
            SELECT id, project_id, phase_id, outcome, lane, plan_legacy_continuation
            FROM tickets_exact_original;
            DROP TABLE tickets_exact_original;
            CREATE UNIQUE INDEX tickets_project_phase_identity_unique
                ON tickets(project_id, phase_id, id);
            CREATE TRIGGER tickets_reject_legacy_continuation_insert
            BEFORE INSERT ON tickets
            WHEN NEW.plan_legacy_continuation = 1
            BEGIN
                SELECT RAISE(ABORT, 'legacy continuation is migration-only');
            END;
            CREATE TRIGGER tickets_reject_legacy_continuation_regrant
            BEFORE UPDATE OF plan_legacy_continuation ON tickets
            WHEN OLD.plan_legacy_continuation = 0 AND NEW.plan_legacy_continuation = 1
            BEGIN
                SELECT RAISE(ABORT, 'legacy continuation cannot be regranted');
            END;
            PRAGMA legacy_alter_table = OFF;
            PRAGMA foreign_keys = ON;
            INSERT INTO projects (id, name) VALUES ('semantic-counterfeit', 'Semantic Counterfeit');
            INSERT INTO phases (id, project_id, name)
            VALUES ('semantic-counterfeit-phase', 'semantic-counterfeit', 'Semantic Counterfeit');
            INSERT INTO tickets
                (id, project_id, phase_id, outcome, lane, plan_legacy_continuation)
            VALUES (
                'semantic-counterfeit-ticket',
                'semantic-counterfeit',
                'semantic-counterfeit-phase',
                'Semantic Counterfeit',
                'backlog',
                2
            );
            """)
            XCTAssertEqual(
                try semanticCounterfeitContinuation.scalarInt(
                    "SELECT plan_legacy_continuation FROM tickets WHERE id = 'semantic-counterfeit-ticket'"
                ),
                2
            )
            XCTAssertNil(try semanticCounterfeitContinuation.row("PRAGMA foreign_key_check"))
        }
        await assertMigrationUnavailable(databaseURL: semanticCounterfeitContinuationURL)
    }

    func testVersionElevenMigrationFailureRollsBackToExactVersionTenStateAndRecovers() async throws {
        let databaseURL = try copyVerifiedVersionTenFixture()
        let legacy = try SQLiteConnection(url: databaseURL)
        try seedCompleteVersionTenGraph(legacy)
        let beforeMigration = try semanticVersionTenSnapshot(legacy)
        try legacy.executeScript("""
        CREATE TRIGGER task1b_abort_continuation_backfill
        BEFORE UPDATE ON tickets
        BEGIN
            SELECT RAISE(ABORT, 'task1b late migration failure');
        END;
        """)

        let failed = DeliveryStore(databaseURL: databaseURL)
        guard case let .unavailable(recovery) = await failed.availability else {
            return XCTFail("Expected the injected late-v11 failure")
        }
        XCTAssertEqual(recovery.kind, .migration)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        let snapshotURL = try XCTUnwrap(recovery.preMigrationSnapshotURL)
        for recoverableURL in [databaseURL, snapshotURL] {
            let recoverable = try SQLiteConnection(url: recoverableURL)
            XCTAssertEqual(try recoverable.scalarInt("PRAGMA user_version"), 10)
            XCTAssertEqual(try semanticVersionTenSnapshot(recoverable), beforeMigration)
            XCTAssertEqual(try recoverable.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE type = 'trigger' AND name = 'task1b_abort_continuation_backfill'"), 1)
            XCTAssertEqual(try recoverable.scalarInt("SELECT COUNT(*) FROM pragma_table_info('tickets') WHERE name = 'plan_legacy_continuation'"), 0)
            XCTAssertEqual(try recoverable.scalarInt("SELECT COUNT(*) FROM sqlite_schema WHERE name IN ('phase_plans', 'delivery_goals', 'delivery_goal_done_criteria', 'delivery_goal_ticket_assignments', 'delivery_goal_assignment_events')"), 0)
            XCTAssertEqual(try recoverable.scalarInt("SELECT COUNT(*) FROM audit_events"), 1)
            XCTAssertEqual(try recoverable.scalarInt("SELECT COUNT(*) FROM notification_events"), 1)
            XCTAssertEqual(try recoverable.scalarInt("SELECT COUNT(*) FROM agent_command_requests"), 1)
        }

        let original = try SQLiteConnection(url: databaseURL)
        try original.execute("DROP TRIGGER task1b_abort_continuation_backfill")
        var recovered: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await recovered!.availability else {
            return XCTFail("Expected normal migration after removing only the injected trigger")
        }
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(try semanticVersionTenSnapshot(SQLiteConnection(url: databaseURL)), beforeMigration)
        recovered = nil
        let relaunched = DeliveryStore(databaseURL: databaseURL)
        guard case .available = await relaunched.availability else {
            return XCTFail("Expected recovered current-schema state to relaunch")
        }
        XCTAssertEqual(try semanticVersionTenSnapshot(SQLiteConnection(url: databaseURL)), beforeMigration)
        XCTAssertNil(try SQLiteConnection(url: databaseURL).row("PRAGMA foreign_key_check"))
    }

    func testSuccessfulTicketTransitionCommitsAttributedAuditEvent() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let projectID = ProjectID(rawValue: "project-1")
        let phaseID = PhaseID(rawValue: "phase-1")
        let ticketID = TicketID(rawValue: "RR-02")
        let actor = DeliveryActor(id: "agent-implementer", threadID: "thread-42")

        try await store.transact(actor: actor, reason: "Complete transactional storage") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, ?)",
                bindings: [.text(projectID.rawValue), .text("Release Radar")]
            )
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
                bindings: [.text(phaseID.rawValue), .text(projectID.rawValue), .text("MVP")]
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
                bindings: [
                    .text(ticketID.rawValue),
                    .text(projectID.rawValue),
                    .text(phaseID.rawValue),
                    .text("Persist delivery state"),
                    .text(TicketLane.backlog.rawValue),
                ]
            )
            try connection.execute(
                "UPDATE tickets SET lane = ? WHERE id = ?",
                bindings: [.text(TicketLane.accepted.rawValue), .text(ticketID.rawValue)]
            )
        }

        let lane = try await store.read { connection in
            try connection.scalarText(
                "SELECT lane FROM tickets WHERE id = ?",
                bindings: [.text(ticketID.rawValue)]
            )
        }
        let audit = try await store.read { connection in
            try connection.row(
                "SELECT actor_id, thread_id, reason FROM audit_events"
            )
        }

        XCTAssertEqual(lane, TicketLane.accepted.rawValue)
        XCTAssertEqual(audit?["actor_id"], .text(actor.id))
        XCTAssertEqual(audit?["thread_id"], .text(actor.threadID!))
        XCTAssertEqual(audit?["reason"], .text("Complete transactional storage"))
    }

    func testAuditedTransactionPersistsOptionalStructuredEntityScope() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        let projectID = ProjectID(rawValue: "project-1")

        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Owner accepted the ticket",
            auditScope: AuditScope(
                projectID: projectID,
                entityType: .ticket,
                entityID: "RR-02"
            )
        ) { connection in
            try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
        }

        let scoped = try await store.read { connection in
            try connection.row(
                "SELECT project_id, entity_type, entity_id FROM audit_events WHERE reason = 'Owner accepted the ticket'"
            )
        }
        let unscoped = try await store.read { connection in
            try connection.row(
                "SELECT project_id, entity_type, entity_id FROM audit_events WHERE reason = 'Seed project'"
            )
        }
        XCTAssertEqual(scoped?["project_id"], .text("project-1"))
        XCTAssertEqual(scoped?["entity_type"], .text("ticket"))
        XCTAssertEqual(scoped?["entity_id"], .text("RR-02"))
        XCTAssertEqual(unscoped?["project_id"], .null)
        XCTAssertEqual(unscoped?["entity_type"], .null)
        XCTAssertEqual(unscoped?["entity_id"], .null)
    }

    func testInvalidReferenceRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-invalid-reference"), reason: "Add blocker") { connection in
                try connection.execute(
                    "UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'"
                )
                try connection.execute(
                    "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('blocker-1', 'project-1', 'missing-ticket', 'Missing ticket')"
                )
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM blockers"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 1)
    }

    func testCrossProjectThreadLinkRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed second project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-2', 'Other')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-2', 'project-2', 'running', '2026-08-23T12:00:00Z')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-cross-project"), reason: "Link thread") { connection in
                try connection.execute("UPDATE tickets SET lane = 'in_progress' WHERE id = 'RR-02'")
                try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('link-1', 'project-1', 'RR-02', 'thread-2')")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM thread_links"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 2)
    }

    func testDependencyCycleRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed dependency") { connection in
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Bridge', 'backlog')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dependency-1', 'project-1', 'RR-03', 'RR-02')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-cycle"), reason: "Add cyclic dependency") { connection in
                try connection.execute("UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'")
                try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dependency-2', 'project-1', 'RR-02', 'RR-03')")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 2)
    }

    func testPhaseDependencyCycleRollsBackDeliveryAndAuditWrites() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed phase dependency") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-2', 'project-1', 'Launch')")
            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-1', 'project-1', 'phase-2', 'phase-1')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-cycle"), reason: "Add cyclic phase dependency") { connection in
                try connection.execute("UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'")
                try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-2', 'project-1', 'phase-1', 'phase-2')")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 2)
    }

    func testReadProjectionCannotBypassAuditedTransactions() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.read { connection in
                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testReadCallbackCannotControlTransactionOrPoisonSubsequentAuditedWrite() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.read { connection in
                _ = try connection.row("BEGIN")
            }
        }

        try await store.transact(actor: .init(id: "agent-accept"), reason: "Accept ticket") { connection in
            try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-accept' AND reason = 'Accept ticket'")
            )
        }
        XCTAssertEqual(state.0, TicketLane.accepted.rawValue)
        XCTAssertEqual(state.1, 2)
        XCTAssertEqual(state.2, 1)
    }

    func testReadCallbackCannotDisableForeignKeysOrBypassAuditedIntegrity() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.read { connection in
                _ = try connection.row("PRAGMA foreign_keys = OFF")
            }
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-invalid"), reason: "Reject missing ticket") { connection in
                try connection.execute(
                    "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('rejected', 'project-1', 'missing', 'Rejected')"
                )
            }
        }

        let foreignKeys = try await store.transact(
            actor: .init(id: "agent-accept"),
            reason: "Accept ticket"
        ) { connection in
            let foreignKeys = try connection.scalarInt("PRAGMA foreign_keys")
            try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
            return foreignKeys
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM blockers"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-invalid'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-accept' AND reason = 'Accept ticket'")
            )
        }
        XCTAssertEqual(foreignKeys, 1)
        XCTAssertEqual(state.0, TicketLane.accepted.rawValue)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 2)
        XCTAssertEqual(state.3, 0)
        XCTAssertEqual(state.4, 1)
    }

    func testConnectionReturnedFromTransactionCannotWriteAfterCallbackCompletes() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        let escapedConnection = try await store.transact(
            actor: .init(id: "agent-leak"),
            reason: "Return transaction handle"
        ) { connection in
            connection
        }

        XCTAssertThrowsError(
            try escapedConnection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
        )
        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 2)
    }

    func testConnectionReturnedFromReadCannotWriteAfterCallbackCompletes() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        let escapedConnection = try await store.read { connection in
            connection
        }

        XCTAssertThrowsError(
            try escapedConnection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
        )
        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testCallbackCommitCannotEscapeStoreOwnedTransaction() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-commit"), reason: "Commit early") { connection in
                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
                try connection.execute("COMMIT")
                throw CallbackFailure.expected
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testCallbackCannotMutateAuditEvents() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await seedProject(store)

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent-audit"), reason: "Delete audit history") { connection in
                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
                try connection.execute("DELETE FROM audit_events")
            }
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testCallbackAuditMutationMatrixRemainsDeniedAndRollsBackSiblingWrites() async throws {
        let mutations = [
            "INSERT INTO audit_events (id, actor_id, reason, created_at) VALUES ('forbidden-insert', 'forbidden', 'Forbidden insert', '2026-08-25T12:00:00Z')",
            "UPDATE audit_events SET reason = 'Forbidden update'",
            "DELETE FROM audit_events",
        ]

        for mutation in mutations {
            let store = DeliveryStore(databaseURL: try makeDatabaseURL())
            try await seedProject(store)

            let caughtError: Error
            do {
                try await store.transact(actor: .init(id: "agent-audit-matrix"), reason: "Forbidden audit callback mutation") { connection in
                    try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
                    try connection.execute(mutation)
                }
                XCTFail("Expected callback audit mutation to be denied: \(mutation)")
                continue
            } catch {
                caughtError = error
            }

            let sqliteError = try XCTUnwrap(caughtError as? SQLiteError)
            XCTAssertEqual(sqliteError.code, 23)
            let state = try await store.read { connection in
                (
                    try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-audit-matrix'")
                )
            }
            XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
            XCTAssertEqual(state.1, 1)
            XCTAssertEqual(state.2, 0)
        }
    }

    func testCallbackProjectDeleteCannotIndirectlyMutateScopedAuditEvent() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let projectID = ProjectID(rawValue: "project-scoped-audit")
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed scoped audit fixture",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-scoped-audit', 'Scoped audit project')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-scoped-audit', 'project-scoped-audit', 'Scoped phase')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('SCOPED-01', 'project-scoped-audit', 'phase-scoped-audit', 'Scoped child', 'backlog')")
        }
        let before = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-scoped-audit'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'SCOPED-01'"),
                try connection.row("SELECT project_id, entity_type, entity_id FROM audit_events WHERE reason = 'Seed scoped audit fixture'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        let foreignKeyCheckBefore = try SQLiteConnection(url: databaseURL)
            .scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_check")

        let caughtError: Error
        do {
            try await store.transact(actor: .init(id: "agent-delete"), reason: "Delete scoped audit project") { connection in
                try connection.execute("DELETE FROM projects WHERE id = 'project-scoped-audit'")
            }
            XCTFail("Expected foreign-key audit set-null mutation to be denied")
            return
        } catch {
            caughtError = error
        }

        let sqliteError = try XCTUnwrap(caughtError as? SQLiteError)
        XCTAssertEqual(sqliteError.code, 23)
        let after = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-scoped-audit'"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'SCOPED-01'"),
                try connection.row("SELECT project_id, entity_type, entity_id FROM audit_events WHERE reason = 'Seed scoped audit fixture'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        let foreignKeyCheckAfter = try SQLiteConnection(url: databaseURL)
            .scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_check")
        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)
        XCTAssertEqual(after.2, before.2)
        XCTAssertEqual(after.3, before.3)
        XCTAssertEqual(foreignKeyCheckBefore, 0)
        XCTAssertEqual(foreignKeyCheckAfter, 0)
    }

    func testSQLiteDiagnosticsAllowlistAuthorizerAndPrepareFailureFields() async throws {
        SQLiteDiagnostics.resetForTesting()
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        let projectID = ProjectID(rawValue: "diagnostic-project-id")
        try await store.transact(
            actor: .init(id: "diagnostic-owner-id"),
            reason: "diagnostic-secret-reason",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: "diagnostic-entity-id")
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('diagnostic-project-id', 'diagnostic-project-name')")
        }
        SQLiteDiagnostics.resetForTesting()

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "diagnostic-owner-id"), reason: "diagnostic-secret-reason") { connection in
                try connection.execute("UPDATE audit_events SET project_id = 'diagnostic-project-id' WHERE reason = 'diagnostic-secret-reason'")
            }
        }

        let payloads = SQLiteDiagnostics.recentPayloadsForTesting()
        let authorizerPayload = try XCTUnwrap(payloads.first { $0.contains("event=release_radar_sqlite_authorizer_denied") })
        let preparePayload = try XCTUnwrap(payloads.first { $0.contains("event=release_radar_sqlite_failure stage=prepare") })
        XCTAssertTrue(authorizerPayload.contains("primary_result=23"))
        XCTAssertTrue(authorizerPayload.contains("authorizer_action=23"))
        XCTAssertTrue(authorizerPayload.contains("authorizer_action_name=SQLITE_UPDATE"))
        XCTAssertTrue(authorizerPayload.contains("protected_table=audit_events"))
        XCTAssertTrue(authorizerPayload.contains("protected_column=project_id"))
        XCTAssertTrue(authorizerPayload.contains("in_transaction=true"))
        XCTAssertTrue(preparePayload.contains("primary_result=23"))
        XCTAssertTrue(preparePayload.contains("authorizer_action=none"))
        XCTAssertTrue(preparePayload.contains("protected_table=none"))
        XCTAssertTrue(preparePayload.contains("protected_column=none"))
        XCTAssertTrue(preparePayload.contains("in_transaction=true"))

        let combinedPayloads = payloads.joined(separator: "\n")
        for prohibitedValue in [
            "diagnostic-owner-id",
            "diagnostic-secret-reason",
            "diagnostic-project-id",
            "diagnostic-entity-id",
            "diagnostic-project-name",
            "UPDATE audit_events",
        ] {
            XCTAssertFalse(combinedPayloads.contains(prohibitedValue))
        }
    }

    func testActivePhaseMustBelongToTheSameProject() async throws {
        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
        try await store.transact(actor: .init(id: "seed"), reason: "Seed active phase integrity") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'One')")
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-2', 'Two')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'One active')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-2', 'project-2', 'Two active')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')")
        }

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "invalid"), reason: "Reject cross-project active phase") { connection in
                try connection.execute("UPDATE project_active_phases SET phase_id = 'phase-2' WHERE project_id = 'project-1'")
            }
        }

        let activePhaseID = try await store.read { connection in
            try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'")
        }
        XCTAssertEqual(activePhaseID, "phase-1")
    }

    func testVersionFourMigrationBackfillsOnlyUnambiguousActivePhase() async throws {
        let databaseURL = try makeDatabaseURL()
        var currentStore: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await currentStore!.transact(actor: .init(id: "seed"), reason: "Seed version four migration") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('single', 'Single phase')")
            try connection.execute("INSERT INTO projects (id, name) VALUES ('multiple', 'Multiple phases')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('single-phase', 'single', 'Only')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('multiple-a', 'multiple', 'Earlier')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('multiple-b', 'multiple', 'Later')")
        }
        currentStore = nil

        let legacy = try SQLiteConnection(url: databaseURL)
        try removeVersionElevenSchema(legacy)
        try legacy.executeScript("""
        DROP TABLE codex_plugin_lifecycle;
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
        PRAGMA user_version = 4;
        """)

        let store = DeliveryStore(databaseURL: databaseURL)
        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'single'"),
                try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'multiple'")
            )
        }
        XCTAssertEqual(state.0, "single-phase")
        XCTAssertNil(state.1)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 12)
    }

    func testVersionSevenMigrationBackfillsOnlyUnambiguousTicketGoalIdentity() async throws {
        let databaseURL = try makeDatabaseURL()
        do {
            let store = DeliveryStore(databaseURL: databaseURL)
            try await store.transact(actor: .init(id: "fixture"), reason: "Seed version seven ticket-goal migration") { connection in
                try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
                try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
                try connection.execute("""
                INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
                    ('ONE', 'project-1', 'phase-1', 'Owner-authored unambiguous outcome', 'backlog'),
                    ('MULTI-THREAD', 'project-1', 'phase-1', 'Owner-authored multi-thread outcome', 'backlog'),
                    ('MULTI-GOAL', 'project-1', 'phase-1', 'Owner-authored multi-goal outcome', 'backlog'),
                    ('SHARED-A', 'project-1', 'phase-1', 'Owner-authored shared outcome A', 'backlog'),
                    ('SHARED-B', 'project-1', 'phase-1', 'Owner-authored shared outcome B', 'backlog')
                """)
                try connection.execute("""
                INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES
                    ('thread-one', 'project-1', 'active', '2026-08-25T10:00:00Z'),
                    ('thread-multi-a', 'project-1', 'active', '2026-08-25T10:00:00Z'),
                    ('thread-multi-b', 'project-1', 'active', '2026-08-25T10:00:00Z'),
                    ('thread-goals', 'project-1', 'active', '2026-08-25T10:00:00Z'),
                    ('thread-shared', 'project-1', 'active', '2026-08-25T10:00:00Z')
                """)
                try connection.execute("""
                INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES
                    ('goal-one', 'project-1', 'thread-one', 'active', 'Approved candidate', '2026-08-25T10:00:00Z'),
                    ('goal-multi-a', 'project-1', 'thread-multi-a', 'active', 'First thread candidate', '2026-08-25T10:00:00Z'),
                    ('goal-multi-b', 'project-1', 'thread-multi-b', 'active', 'Second thread candidate', '2026-08-25T10:00:00Z'),
                    ('goal-goals-a', 'project-1', 'thread-goals', 'active', 'Earlier candidate', '2026-08-25T10:00:00Z'),
                    ('goal-goals-b', 'project-1', 'thread-goals', 'active', 'Later candidate', '2026-08-25T11:00:00Z'),
                    ('goal-shared', 'project-1', 'thread-shared', 'active', 'Shared candidate', '2026-08-25T10:00:00Z')
                """)
                try connection.execute("""
                INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES
                    ('link-one', 'project-1', 'ONE', 'thread-one'),
                    ('link-multi-a', 'project-1', 'MULTI-THREAD', 'thread-multi-a'),
                    ('link-multi-b', 'project-1', 'MULTI-THREAD', 'thread-multi-b'),
                    ('link-goals', 'project-1', 'MULTI-GOAL', 'thread-goals'),
                    ('link-shared-a', 'project-1', 'SHARED-A', 'thread-shared'),
                    ('link-shared-b', 'project-1', 'SHARED-B', 'thread-shared')
                """)
            }
        }

        let legacy = try SQLiteConnection(url: databaseURL)
        try removeVersionElevenSchema(legacy)
        try legacy.executeScript("""
        DROP TABLE codex_plugin_lifecycle;
        DROP TABLE alert_rules;
        DROP TABLE IF EXISTS ticket_goal_links;
        DROP INDEX IF EXISTS observed_goals_project_identity_unique;
        PRAGMA user_version = 7;
        """)

        do {
            let migratedStore = DeliveryStore(databaseURL: databaseURL)
            let state = try await migratedStore.read { connection in
                (
                    try connection.scalarInt("SELECT COUNT(*) FROM tickets"),
                    try connection.scalarInt("SELECT COUNT(*) FROM observed_goals"),
                    try connection.scalarInt("SELECT COUNT(*) FROM thread_links"),
                    try connection.scalarInt("SELECT COUNT(*) FROM ticket_goal_links"),
                    try connection.scalarText("SELECT project_id || '|' || ticket_id || '|' || thread_id || '|' || goal_id FROM ticket_goal_links"),
                    try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'ONE'")
                )
            }
            XCTAssertEqual(state.0, 5)
            XCTAssertEqual(state.1, 6)
            XCTAssertEqual(state.2, 6)
            XCTAssertEqual(state.3, 1)
            XCTAssertEqual(state.4, "project-1|ONE|thread-one|goal-one")
            XCTAssertEqual(state.5, "Owner-authored unambiguous outcome")
            XCTAssertNil(try SQLiteConnection(url: databaseURL).row("PRAGMA foreign_key_check"))
        }

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let relaunchedLinkCount = try await relaunchedStore.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM ticket_goal_links")
        }
        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
        XCTAssertEqual(relaunchedLinkCount, 1)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 7)
        XCTAssertNil(try snapshot.scalarText("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'ticket_goal_links'"))
        XCTAssertEqual(try snapshot.scalarText("SELECT outcome FROM tickets WHERE id = 'ONE'"), "Owner-authored unambiguous outcome")
    }

    func testVersionEightSchemaEnforcesExactTicketAndGoalIdentity() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed ticket-goal integrity") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("""
            INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
                ('RR-1', 'project-1', 'phase-1', 'First', 'backlog'),
                ('RR-2', 'project-1', 'phase-1', 'Second', 'backlog')
            """)
            try connection.execute("""
            INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES
                ('thread-1', 'project-1', 'active', '2026-08-25T10:00:00Z'),
                ('thread-2', 'project-1', 'active', '2026-08-25T10:00:00Z')
            """)
            try connection.execute("""
            INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES
                ('goal-1', 'project-1', 'thread-1', 'active', 'First goal', '2026-08-25T10:00:00Z'),
                ('goal-2', 'project-1', 'thread-2', 'active', 'Second goal', '2026-08-25T10:00:00Z')
            """)
            try connection.execute("""
            INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES
                ('thread-link-1', 'project-1', 'RR-1', 'thread-1'),
                ('thread-link-2', 'project-1', 'RR-2', 'thread-2'),
                ('thread-link-2-goal', 'project-1', 'RR-2', 'thread-1')
            """)
            try connection.execute("INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES ('goal-link-1', 'project-1', 'RR-1', 'thread-1', 'goal-1')")
        }

        let manifestConnection = try SQLiteConnection(url: databaseURL)
        let manifest = (
            try manifestConnection.scalarInt("SELECT COUNT(*) FROM pragma_index_list('observed_goals') WHERE name = 'observed_goals_project_identity_unique' AND \"unique\" = 1"),
            try manifestConnection.scalarInt("SELECT COUNT(*) FROM pragma_index_list('ticket_goal_links') WHERE name = 'ticket_goal_links_project_ticket_unique' AND \"unique\" = 1"),
            try manifestConnection.scalarInt("SELECT COUNT(*) FROM pragma_index_list('ticket_goal_links') WHERE name = 'ticket_goal_links_project_goal_unique' AND \"unique\" = 1"),
            try Self.exactForeignKeyCount(manifestConnection, table: "ticket_goal_links", source: "project_id,ticket_id,thread_id", targetTable: "thread_links", target: "project_id,ticket_id,thread_id"),
            try Self.exactForeignKeyCount(manifestConnection, table: "ticket_goal_links", source: "project_id,goal_id,thread_id", targetTable: "observed_goals", target: "project_id,id,thread_id")
        )
        XCTAssertEqual(manifest.0, 1)
        XCTAssertEqual(manifest.1, 1)
        XCTAssertEqual(manifest.2, 1)
        XCTAssertEqual(manifest.3, 1)
        XCTAssertEqual(manifest.4, 1)
        XCTAssertNil(try SQLiteConnection(url: databaseURL).row("PRAGMA foreign_key_check"))

        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "fixture"), reason: "Reject duplicate ticket identity") { connection in
                try connection.execute("INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES ('duplicate-ticket', 'project-1', 'RR-1', 'thread-1', 'goal-1')")
            }
        }
        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "fixture"), reason: "Reject duplicate goal identity") { connection in
                try connection.execute("INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES ('duplicate-goal', 'project-1', 'RR-2', 'thread-1', 'goal-1')")
            }
        }
        let linkCount = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM ticket_goal_links")
        }
        XCTAssertEqual(linkCount, 1)
    }

    func testVersionNineAlertRulesMigrateExactlyAndOwnerChangesAuditOnce() async throws {
        let databaseURL = try makeDatabaseURL()
        var legacyStore: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        _ = legacyStore
        legacyStore = nil
        let legacy = try SQLiteConnection(url: databaseURL)
        try removeVersionElevenSchema(legacy)
        try legacy.executeScript("""
        DROP TABLE IF EXISTS codex_plugin_lifecycle;
        DROP TABLE IF EXISTS alert_rules;
        PRAGMA user_version = 8;
        """)

        let store = DeliveryStore(databaseURL: databaseURL)
        let ruleStore = AlertRuleStore(store: store)
        let initial = try await ruleStore.load()
        XCTAssertTrue(initial[.blockedLinkedGoals])
        XCTAssertTrue(initial[.agentCompletionAndReview])
        XCTAssertTrue(initial[.needsReviewEntry])
        XCTAssertFalse(initial[.pausedGoals])
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 12)

        let schema = try SQLiteConnection(url: databaseURL)
        XCTAssertThrowsError(try schema.execute("INSERT INTO alert_rules (kind, is_enabled) VALUES ('unknown', 1)"))
        XCTAssertThrowsError(try schema.execute("UPDATE alert_rules SET is_enabled = 2 WHERE kind = 'paused_goals'"))

        let changed = try await ruleStore.set(.pausedGoals, enabled: true)
        _ = try await ruleStore.set(.pausedGoals, enabled: true)
        XCTAssertTrue(changed[.pausedGoals])
        let audit = try await store.read { connection in
            try connection.row(
                """
                SELECT actor_id, thread_id, thread_attribution, project_id, entity_type, entity_id, reason
                FROM audit_events
                WHERE reason LIKE 'Set global alert rule %'
                """
            )
        }
        XCTAssertEqual(audit?["actor_id"], .text("release-radar-owner"))
        XCTAssertEqual(audit?["thread_id"], .null)
        XCTAssertEqual(audit?["thread_attribution"], .text("none"))
        XCTAssertEqual(audit?["project_id"], .null)
        XCTAssertEqual(audit?["entity_type"], .null)
        XCTAssertEqual(audit?["entity_id"], .null)
        XCTAssertEqual(audit?["reason"], .text("Set global alert rule paused_goals enabled"))
        let changeAuditCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Set global alert rule %'")
        }
        XCTAssertEqual(changeAuditCount, 1)

        try await store.transact(actor: .init(id: "fixture"), reason: "Break alert rule fixture") { connection in
            try connection.execute("DELETE FROM alert_rules WHERE kind = 'needs_review_entry'")
        }
        await XCTAssertThrowsErrorAsync { _ = try await ruleStore.load() }
        await XCTAssertThrowsErrorAsync { _ = try await ruleStore.set(.blockedLinkedGoals, enabled: false) }
        let auditCountAfterFailures = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Set global alert rule %'")
        }
        XCTAssertEqual(auditCountAfterFailures, 1)
    }

    func testVersionNineMigratesToVersionTenWithExactlyOneLifecycleSingleton() async throws {
        let databaseURL = try makeDatabaseURL()
        var currentStore: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        _ = currentStore
        currentStore = nil
        let legacy = try SQLiteConnection(url: databaseURL)
        try removeVersionElevenSchema(legacy)
        try legacy.executeScript("""
        DROP TABLE codex_plugin_lifecycle;
        PRAGMA user_version = 9;
        """)

        let migrated = DeliveryStore(databaseURL: databaseURL)
        let state = try await migrated.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM codex_plugin_lifecycle"),
                try connection.scalarText("SELECT intent FROM codex_plugin_lifecycle WHERE plugin_id = 'release-radar'")
            )
        }

        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, "neverInstalled")
    }

    func testVersionTenMissingLifecycleSingletonIsUnavailableAndRecoverable() async throws {
        let databaseURL = try makeDatabaseURL()
        var currentStore: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await currentStore!.transact(actor: .init(id: "fixture"), reason: "Remove lifecycle singleton") {
            try $0.execute("DELETE FROM codex_plugin_lifecycle")
        }
        currentStore = nil

        let relaunched = DeliveryStore(databaseURL: databaseURL)
        guard case let .unavailable(recovery) = await relaunched.availability else {
            return XCTFail("Expected missing lifecycle singleton to make version 12 unavailable")
        }
        XCTAssertEqual(recovery.kind, .migration)
        let original = try SQLiteConnection(url: databaseURL)
        let snapshot = try SQLiteConnection(url: try XCTUnwrap(recovery.preMigrationSnapshotURL))
        XCTAssertEqual(try original.scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(try original.scalarInt("SELECT COUNT(*) FROM codex_plugin_lifecycle"), 0)
        XCTAssertEqual(try snapshot.scalarInt("SELECT COUNT(*) FROM codex_plugin_lifecycle"), 0)
    }

    func testVersionTenMalformedLifecycleSingletonIsRejectedByLoadAndRelaunch() async throws {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await store!.transact(actor: .init(id: "fixture"), reason: "Corrupt lifecycle singleton") {
            try $0.execute(
                """
                UPDATE codex_plugin_lifecycle
                SET intent = 'managedInstalled',
                    managed_version = X'01',
                    managed_digest = 'digest',
                    verified_at = '2026-08-28T00:00:00Z'
                WHERE plugin_id = 'release-radar'
                """
            )
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await CodexPluginLifecycleStore(store: store!).load()
        }
        store = nil

        let relaunched = DeliveryStore(databaseURL: databaseURL)
        guard case .unavailable = await relaunched.availability else {
            return XCTFail("Expected malformed lifecycle singleton to make version 12 unavailable")
        }
        XCTAssertEqual(
            try SQLiteConnection(url: databaseURL).scalarText(
                "SELECT typeof(managed_version) FROM codex_plugin_lifecycle"
            ),
            "blob"
        )
    }

    func testLifecycleUpdateRequiresSingletonAndRollsBackItsAudit() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Remove lifecycle singleton") {
            try $0.execute("DELETE FROM codex_plugin_lifecycle")
        }
        let before = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }

        await XCTAssertThrowsErrorAsync {
            try await CodexPluginLifecycleStore(store: store).recordVerified(
                .init(intent: .managedInstalled, managedVersion: "0.1.0", managedDigest: "digest", verifiedAt: Date(timeIntervalSince1970: 1)),
                reason: "Install Release Radar Codex plugin"
            )
        }

        let after = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }
        XCTAssertEqual(after, before)
        await XCTAssertThrowsErrorAsync {
            _ = try await CodexPluginLifecycleStore(store: store).load()
        }
    }

    func testLinkedGoalThreadReassignmentRollsBackObservedGoalAndLink() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed linked goal") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-1', 'project-1', 'phase-1', 'Keep identity', 'backlog')")
            try connection.execute("""
            INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES
                ('thread-1', 'project-1', 'active', '2026-08-25T10:00:00Z'),
                ('thread-2', 'project-1', 'active', '2026-08-25T10:00:00Z')
            """)
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-1', 'project-1', 'thread-1', 'active', 'Original goal', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-1', 'project-1', 'RR-1', 'thread-1')")
            try connection.execute("INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES ('goal-link-1', 'project-1', 'RR-1', 'thread-1', 'goal-1')")
        }
        let auditCountBefore = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }

        await XCTAssertThrowsErrorAsync {
            try await MeaningfulDeliveryEventRecorder(store: store).recordGoalObservation(
                projectID: .init(rawValue: "project-1"),
                threadID: "thread-2",
                goalID: "goal-1",
                status: .blocked,
                observedAt: Date(timeIntervalSince1970: 2)
            )
        }

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT thread_id || '|' || status || '|' || text FROM observed_goals WHERE id = 'goal-1'"),
                try connection.scalarText("SELECT thread_id || '|' || goal_id FROM ticket_goal_links WHERE id = 'goal-link-1'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
            )
        }
        XCTAssertEqual(state.0, "thread-1|active|Original goal")
        XCTAssertEqual(state.1, "thread-1|goal-1")
        XCTAssertEqual(state.2, auditCountBefore)
        XCTAssertNil(try SQLiteConnection(url: databaseURL).row("PRAGMA foreign_key_check"))
    }

    func testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit() async throws {
        let databaseURL = try makeDatabaseURL()
        do {
            let legacy = try SQLiteConnection(url: databaseURL)
            try legacy.execute("CREATE TABLE legacy_marker (value TEXT NOT NULL)")
            try legacy.execute("INSERT INTO legacy_marker (value) VALUES ('before-migration')")
            try legacy.execute("PRAGMA user_version = 0")
        }

        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(store!)
        await XCTAssertThrowsErrorAsync {
            try await store!.transact(actor: .init(id: "agent-invalid"), reason: "Reject missing reference") { connection in
                try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('rejected', 'project-1', 'missing', 'Rejected')")
            }
        }
        store = nil

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let persisted = try await relaunchedStore.read { connection in
            (
                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-02'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM blockers")
            )
        }
        let relaunchedDatabase = try SQLiteConnection(url: databaseURL)
        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))

        XCTAssertEqual(persisted.0, "Store")
        XCTAssertEqual(persisted.1, 1)
        XCTAssertEqual(persisted.2, 0)
        XCTAssertEqual(try relaunchedDatabase.scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(try snapshot.scalarText("SELECT value FROM legacy_marker"), "before-migration")
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
    }

    func testCorruptDatabaseOpensUnavailableAndLeavesOriginalBytesIntact() async throws {
        let databaseURL = try makeDatabaseURL()
        let originalBytes = Data("not-a-sqlite-database".utf8)
        try originalBytes.write(to: databaseURL)

        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability

        guard case let .unavailable(recovery) = availability else {
            return XCTFail("Expected corrupt database to be unavailable")
        }
        XCTAssertEqual(recovery.kind, .corruption)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        XCTAssertNil(recovery.preMigrationSnapshotURL)
        XCTAssertEqual(try Data(contentsOf: databaseURL), originalBytes)
        await XCTAssertThrowsErrorAsync {
            try await store.transact(actor: .init(id: "agent"), reason: "Must not reset") { _ in }
        }
        XCTAssertEqual(try Data(contentsOf: databaseURL), originalBytes)
    }

    func testMigrationFailureOpensUnavailableWithOriginalAndSnapshotRecoverable() async throws {
        let databaseURL = try makeDatabaseURL()
        do {
            let malformedLegacy = try SQLiteConnection(url: databaseURL)
            try malformedLegacy.execute("CREATE TABLE projects (legacy_value TEXT NOT NULL)")
            try malformedLegacy.execute("INSERT INTO projects (legacy_value) VALUES ('authoritative-original')")
            try malformedLegacy.execute("PRAGMA user_version = 0")
        }

        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability

        guard case let .unavailable(recovery) = availability else {
            return XCTFail("Expected failed migration to leave the store unavailable")
        }
        XCTAssertEqual(recovery.kind, .migration)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
        XCTAssertEqual(recovery.preMigrationSnapshotURL, DeliveryStore.preMigrationSnapshotURL(for: databaseURL))

        let original = try SQLiteConnection(url: databaseURL)
        let snapshot = try SQLiteConnection(url: try XCTUnwrap(recovery.preMigrationSnapshotURL))
        XCTAssertEqual(try original.scalarText("SELECT legacy_value FROM projects"), "authoritative-original")
        XCTAssertEqual(try snapshot.scalarText("SELECT legacy_value FROM projects"), "authoritative-original")
        XCTAssertEqual(try original.scalarInt("PRAGMA user_version"), 0)
        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
        XCTAssertNil(try original.scalarText("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tickets'"))
    }

    private func copyVerifiedVersionElevenFixture() throws -> URL {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixturesDirectory = testsDirectory.appendingPathComponent("Fixtures", isDirectory: true)
        let fixtureDirectory = fixturesDirectory.appendingPathComponent("SchemaV11", isDirectory: true)
        let fixtureURL = fixtureDirectory.appendingPathComponent("release-radar-v11.sqlite")
        let sumsURL = fixtureDirectory.appendingPathComponent("SHA256SUMS")

        let fixturesCanonical = fixturesDirectory.resolvingSymlinksInPath().standardizedFileURL
        let fixtureDirectoryCanonical = fixtureDirectory.resolvingSymlinksInPath().standardizedFileURL
        guard fixtureDirectoryCanonical.path.hasPrefix(fixturesCanonical.path + "/") else {
            throw StoreError.unavailable("SchemaV11 fixture escapes the test fixture root")
        }
        let directoryValues = try fixtureDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let fixtureValues = try fixtureURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        let sumsValues = try sumsURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard directoryValues.isDirectory == true, directoryValues.isSymbolicLink != true,
              fixtureValues.isRegularFile == true, fixtureValues.isSymbolicLink != true,
              sumsValues.isRegularFile == true, sumsValues.isSymbolicLink != true,
              fixtureURL.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent() == fixtureDirectoryCanonical,
              sumsURL.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent() == fixtureDirectoryCanonical
        else {
            throw StoreError.unavailable("SchemaV11 fixture metadata is not regular and contained")
        }

        let expectedManifest = "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c  release-radar-v11.sqlite\n"
        guard try String(contentsOf: sumsURL, encoding: .utf8) == expectedManifest else {
            throw StoreError.unavailable("SchemaV11 manifest is not the pinned one-line manifest")
        }
        let fixtureData = try Data(contentsOf: fixtureURL)
        let digest = SHA256.hash(data: fixtureData).map { String(format: "%02x", $0) }.joined()
        guard digest == "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c",
              try SQLiteConnection(url: fixtureURL).scalarInt("PRAGMA user_version") == 11
        else {
            throw StoreError.unavailable("SchemaV11 fixture digest or schema version is invalid")
        }

        let databaseURL = try makeDatabaseURL()
        guard !FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw StoreError.unavailable("SchemaV11 fixture destination already exists")
        }
        try FileManager.default.copyItem(at: fixtureURL, to: databaseURL)
        let copiedData = try Data(contentsOf: databaseURL)
        let copiedDigest = SHA256.hash(data: copiedData).map { String(format: "%02x", $0) }.joined()
        guard copiedDigest == digest,
              try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version") == 11
        else {
            throw StoreError.unavailable("Copied SchemaV11 fixture changed before open")
        }
        return databaseURL
    }

    private func seedCompleteVersionElevenGraph(_ connection: SQLiteConnection) throws {
        try connection.executeScript("""
        INSERT INTO projects (id, name, first_dashboard_opened) VALUES
            ('project-main', 'Main', 1), ('project-other', 'Other', 0);
        INSERT INTO project_roots (id, project_id, path) VALUES
            ('root-main', 'project-main', '/test/main'), ('root-other', 'project-other', '/test/other');
        INSERT INTO phases (id, project_id, name) VALUES
            ('phase-1', 'project-main', 'Established'),
            ('phase-2', 'project-main', 'Next'),
            ('phase-3', 'project-other', 'Other');
        INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-main', 'phase-2');
        INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
            ('ticket-backlog', 'project-main', 'phase-1', 'Backlog outcome', 'backlog'),
            ('ticket-active', 'project-main', 'phase-1', 'Active outcome', 'in_progress'),
            ('ticket-review', 'project-main', 'phase-2', 'Review outcome', 'needs_review'),
            ('ticket-blocked', 'project-main', 'phase-2', 'Blocked outcome', 'blocked'),
            ('ticket-accepted', 'project-main', 'phase-1', 'Accepted outcome', 'accepted'),
            ('ticket-other', 'project-other', 'phase-3', 'Other outcome', 'backlog');
        INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id)
            VALUES ('phase-dependency', 'project-main', 'phase-2', 'phase-1');
        INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id)
            VALUES ('ticket-dependency', 'project-main', 'ticket-review', 'ticket-accepted');
        INSERT INTO blockers (id, project_id, ticket_id, summary, resolved_at)
            VALUES ('blocker', 'project-main', 'ticket-blocked', 'Still unresolved', NULL);
        INSERT INTO evidence (id, project_id, ticket_id, path, is_available)
            VALUES ('evidence', 'project-main', 'ticket-active', '/test/evidence', 1);
        INSERT INTO thread_exclusions (id, project_id, thread_id, reason)
            VALUES ('exclusion', 'project-main', 'excluded-thread', 'Private');
        INSERT INTO observed_threads (id, project_id, status, last_observed_at)
            VALUES ('thread-1', 'project-main', 'running', '2026-08-30T10:00:00Z');
        INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at)
            VALUES ('observed-goal-1', 'project-main', 'thread-1', 'active', 'Observed execution', '2026-08-30T10:00:00Z');
        INSERT INTO thread_links (id, project_id, ticket_id, thread_id)
            VALUES ('thread-link', 'project-main', 'ticket-active', 'thread-1');
        INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id)
            VALUES ('goal-link', 'project-main', 'ticket-active', 'thread-1', 'observed-goal-1');
        INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status)
            VALUES ('review', 'project-main', 'ticket-review', 'acceptance', 'Review it', 'open');
        INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at)
            VALUES ('completion', 'project-main', 'ticket-accepted', 'Completed', '2026-08-30T10:00:00Z');
        INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale)
            VALUES ('project-main', '/test/main', X'00010203', 0);
        INSERT INTO notification_events
            (id, fingerprint, state, ticket_id, goal_id, provider_receipt, acknowledged_at,
             project_id, event_kind, subject_id, occurrence, title, message, created_at,
             attempt_count, attempt_started_at, completed_at, failure_code)
            VALUES ('notification', 'fingerprint', 'delivered', 'ticket-active', 'observed-goal-1',
             'receipt', NULL, 'project-main', 'goal_blocked', 'observed-goal-1', 1,
             'Blocked', 'Observed goal blocked', '2026-08-30T10:00:00Z', 1,
             '2026-08-30T10:00:01Z', '2026-08-30T10:00:02Z', NULL);
        INSERT INTO notification_occurrences
            (subject_key, project_id, event_kind, subject_id, generation, is_active)
            VALUES ('project-main|observed-goal-1', 'project-main', 'goal_blocked', 'observed-goal-1', 1, 1);
        UPDATE alert_rules SET is_enabled = 1 WHERE kind = 'paused_goals';
        UPDATE codex_plugin_lifecycle
            SET intent = 'managedInstalled', managed_version = '0.1.0', managed_digest = 'digest',
                verified_at = '2026-08-30T10:00:00Z' WHERE plugin_id = 'release-radar';
        INSERT INTO audit_events
            (id, actor_id, thread_id, reason, created_at, thread_attribution, project_id, entity_type, entity_id)
            VALUES ('audit-seeded', 'agent', 'thread-1', 'Seed graph', '2026-08-30T10:00:00Z',
                    'verified', 'project-main', 'ticket', 'ticket-active');
        INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at)
            VALUES ('request-1', X'010203', X'040506', '2026-08-30T10:00:00Z');
        UPDATE phase_plans SET state = 'draft', revision = 1, updated_at = '2026-08-30T10:00:00Z'
            WHERE project_id = 'project-main' AND phase_id = 'phase-1';
        INSERT INTO delivery_goals
            (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at)
            VALUES
            ('project-main', 'phase-1', 'goal-1', 'Goal one', 'Outcome one', 'active', 0, '2026-08-30T10:00:00Z', '2026-08-30T10:00:00Z'),
            ('project-main', 'phase-2', 'goal-2', 'Goal two', 'Outcome two', 'draft', 0, '2026-08-30T10:00:00Z', '2026-08-30T10:00:00Z'),
            ('project-other', 'phase-3', 'goal-3', 'Goal three', 'Outcome three', 'draft', 0, '2026-08-30T10:00:00Z', '2026-08-30T10:00:00Z');
        INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES
            ('project-main', 'phase-1', 'goal-1', 0, 'First'),
            ('project-main', 'phase-1', 'goal-1', 1, 'Second'),
            ('project-main', 'phase-2', 'goal-2', 0, 'Next');
        INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id)
            VALUES ('project-main', 'phase-1', 'goal-1', 'ticket-active');
        INSERT INTO delivery_goal_assignment_events
            (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action)
            VALUES ('audit-seeded', 'project-main', 'phase-1', 'ticket-active', NULL, 'goal-1', 1, 'assigned');
        """)
        XCTAssertEqual(
            try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE plan_legacy_continuation <> 0"),
            0
        )
        guard try connection.row("PRAGMA foreign_key_check") == nil else {
            throw StoreError.unavailable("Seeded schema-v11 graph violates foreign keys")
        }
    }

    private func semanticVersionElevenSnapshot(_ connection: SQLiteConnection) throws -> [String: String] {
        let queries: [(String, String)] = [
            ("projects", "SELECT json_group_array(json_array(id,name,first_dashboard_opened)) FROM (SELECT * FROM projects ORDER BY id)"),
            ("project_roots", "SELECT json_group_array(json_array(id,project_id,path)) FROM (SELECT * FROM project_roots ORDER BY id)"),
            ("phases", "SELECT json_group_array(json_array(id,project_id,name)) FROM (SELECT * FROM phases ORDER BY id)"),
            ("tickets", "SELECT json_group_array(json_array(id,project_id,phase_id,outcome,lane,plan_legacy_continuation)) FROM (SELECT * FROM tickets ORDER BY id)"),
            ("phase_dependencies", "SELECT json_group_array(json_array(id,project_id,phase_id,depends_on_phase_id)) FROM (SELECT * FROM phase_dependencies ORDER BY id)"),
            ("ticket_dependencies", "SELECT json_group_array(json_array(id,project_id,ticket_id,depends_on_ticket_id)) FROM (SELECT * FROM ticket_dependencies ORDER BY id)"),
            ("blockers", "SELECT json_group_array(json_array(id,project_id,ticket_id,summary,resolved_at)) FROM (SELECT * FROM blockers ORDER BY id)"),
            ("evidence", "SELECT json_group_array(json_array(id,project_id,ticket_id,path,is_available)) FROM (SELECT * FROM evidence ORDER BY id)"),
            ("thread_exclusions", "SELECT json_group_array(json_array(id,project_id,thread_id,reason)) FROM (SELECT * FROM thread_exclusions ORDER BY id)"),
            ("observed_threads", "SELECT json_group_array(json_array(id,project_id,status,last_observed_at)) FROM (SELECT * FROM observed_threads ORDER BY id)"),
            ("observed_goals", "SELECT json_group_array(json_array(id,project_id,thread_id,status,text,last_observed_at)) FROM (SELECT * FROM observed_goals ORDER BY id)"),
            ("thread_links", "SELECT json_group_array(json_array(id,project_id,ticket_id,thread_id)) FROM (SELECT * FROM thread_links ORDER BY id)"),
            ("review_items", "SELECT json_group_array(json_array(id,project_id,ticket_id,kind,summary,status)) FROM (SELECT * FROM review_items ORDER BY id)"),
            ("audit_events", "SELECT json_group_array(json_array(id,actor_id,thread_id,reason,created_at,thread_attribution,project_id,entity_type,entity_id)) FROM (SELECT * FROM audit_events ORDER BY id)"),
            ("notification_events", "SELECT json_group_array(json_array(id,fingerprint,state,ticket_id,goal_id,provider_receipt,acknowledged_at,project_id,event_kind,subject_id,occurrence,title,message,created_at,attempt_count,attempt_started_at,completed_at,failure_code)) FROM (SELECT * FROM notification_events ORDER BY id)"),
            ("completion_records", "SELECT json_group_array(json_array(id,project_id,ticket_id,summary,created_at)) FROM (SELECT * FROM completion_records ORDER BY id)"),
            ("agent_command_requests", "SELECT json_group_array(json_array(request_id,hex(request_body),hex(result_data),created_at)) FROM (SELECT * FROM agent_command_requests ORDER BY request_id)"),
            ("project_bookmarks", "SELECT json_group_array(json_array(project_id,path,hex(bookmark_data),is_stale)) FROM (SELECT * FROM project_bookmarks ORDER BY project_id,path)"),
            ("project_active_phases", "SELECT json_group_array(json_array(project_id,phase_id)) FROM (SELECT * FROM project_active_phases ORDER BY project_id)"),
            ("notification_occurrences", "SELECT json_group_array(json_array(subject_key,project_id,event_kind,subject_id,generation,is_active)) FROM (SELECT * FROM notification_occurrences ORDER BY subject_key)"),
            ("ticket_goal_links", "SELECT json_group_array(json_array(id,project_id,ticket_id,thread_id,goal_id)) FROM (SELECT * FROM ticket_goal_links ORDER BY id)"),
            ("alert_rules", "SELECT json_group_array(json_array(kind,is_enabled)) FROM (SELECT * FROM alert_rules ORDER BY kind)"),
            ("codex_plugin_lifecycle", "SELECT json_group_array(json_array(plugin_id,intent,managed_version,managed_digest,verified_at)) FROM (SELECT * FROM codex_plugin_lifecycle ORDER BY plugin_id)"),
            ("phase_plans", "SELECT json_group_array(json_array(project_id,phase_id,state,revision,ready_revision,created_at,updated_at,finalized_at)) FROM (SELECT * FROM phase_plans ORDER BY project_id,phase_id)"),
            ("delivery_goals", "SELECT json_group_array(json_array(project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at,activated_at,accepted_at)) FROM (SELECT * FROM delivery_goals ORDER BY project_id,phase_id,id)"),
            ("delivery_goal_done_criteria", "SELECT json_group_array(json_array(project_id,phase_id,goal_id,sort_order,criterion)) FROM (SELECT * FROM delivery_goal_done_criteria ORDER BY project_id,phase_id,goal_id,sort_order)"),
            ("delivery_goal_ticket_assignments", "SELECT json_group_array(json_array(project_id,phase_id,goal_id,ticket_id)) FROM (SELECT * FROM delivery_goal_ticket_assignments ORDER BY project_id,ticket_id)"),
            ("delivery_goal_assignment_events", "SELECT json_group_array(json_array(audit_event_id,project_id,phase_id,ticket_id,previous_goal_id,current_goal_id,revision,action)) FROM (SELECT * FROM delivery_goal_assignment_events ORDER BY audit_event_id,ticket_id)"),
        ]
        return try Dictionary(uniqueKeysWithValues: queries.map { name, query in
            (name, try XCTUnwrap(connection.scalarText(query), "Missing semantic v11 snapshot for \(name)"))
        })
    }

    private func assertVersionTwelveStore(
        _ databaseURL: URL,
        expectedVersionElevenSnapshot: [String: String],
        expectedTaskPlanCount: Int64,
        expectedTaskCount: Int64
    ) throws {
        let connection = try SQLiteConnection(url: databaseURL)
        XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 12)
        XCTAssertEqual(try semanticVersionElevenSnapshot(connection), expectedVersionElevenSnapshot)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_task_plans"), expectedTaskPlanCount)
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM ticket_tasks"), expectedTaskCount)
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
        XCTAssertEqual(try connection.scalarText("PRAGMA integrity_check"), "ok")
    }

    private func seedVersionTwelveTaskOwners(_ connection: SQLiteConnection) throws {
        try connection.executeScript("""
        INSERT INTO projects (id, name) VALUES ('p1', 'Project One'), ('p2', 'Project Two');
        INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'p1', 'One'), ('phase-2', 'p2', 'Two');
        INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
            ('ticket-1', 'p1', 'phase-1', 'One', 'backlog'),
            ('ticket-2', 'p1', 'phase-1', 'Two', 'backlog'),
            ('ticket-3', 'p2', 'phase-2', 'Three', 'backlog');
        """)
    }

    private func insertTaskPlan(_ connection: SQLiteConnection, projectID: String, ticketID: String) throws {
        try connection.execute(
            "INSERT INTO ticket_task_plans (project_id, ticket_id, revision, created_at, updated_at) VALUES (?, ?, 1, '2026-08-30T10:00:00Z', '2026-08-30T10:00:00Z')",
            bindings: [.text(projectID), .text(ticketID)]
        )
    }

    private func insertTask(
        _ connection: SQLiteConnection,
        projectID: String,
        ticketID: String,
        id: String,
        label: String,
        title: String,
        sortOrder: Int,
        completion: String = "pending",
        lifecycle: String = "active",
        completedAt: String? = nil,
        supersededAt: String? = nil,
        expectSuccess: Bool = true
    ) throws {
        do {
            try connection.execute(
                """
                INSERT INTO ticket_tasks
                    (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle,
                     created_at, updated_at, completed_at, superseded_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, '2026-08-30T10:00:00Z',
                        '2026-08-30T12:00:00Z', ?, ?)
                """,
                bindings: [.text(projectID), .text(ticketID), .text(id), .text(label), .text(title),
                           .integer(Int64(sortOrder)), .text(completion), .text(lifecycle),
                           completedAt.map(SQLiteValue.text) ?? .null,
                           supersededAt.map(SQLiteValue.text) ?? .null]
            )
            if !expectSuccess { XCTFail("Expected ticket task insert to fail for \(id)") }
        } catch {
            if expectSuccess { throw error }
        }
    }

    private func probeTaskTextBoundary(
        _ connection: SQLiteConnection,
        field: String,
        value: String,
        discriminator: String,
        expectSuccess: Bool
    ) throws {
        var id = discriminator
        var label = discriminator
        var title = discriminator
        switch field {
        case "id": id = value
        case "label": label = value
        case "title": title = value
        default: throw StoreError.unavailable("Unknown task boundary field")
        }
        try insertTask(connection, projectID: "p1", ticketID: "ticket-1", id: id, label: label,
                       title: title, sortOrder: 50, expectSuccess: expectSuccess)
    }

    private func taskHistorySnapshot(
        _ connection: SQLiteConnection,
        projectID: String,
        ticketID: String
    ) throws -> [String: String] {
        let project = try XCTUnwrap(connection.scalarText(
            "SELECT json_array(id,name,first_dashboard_opened) FROM projects WHERE id = ?",
            bindings: [.text(projectID)]))
        let ticket = try XCTUnwrap(connection.scalarText(
            "SELECT json_array(id,project_id,phase_id,outcome,lane,plan_legacy_continuation) FROM tickets WHERE project_id = ? AND id = ?",
            bindings: [.text(projectID), .text(ticketID)]))
        let plan = try XCTUnwrap(connection.scalarText(
            "SELECT json_group_array(json_array(project_id,ticket_id,revision,created_at,updated_at)) FROM (SELECT * FROM ticket_task_plans WHERE project_id = ? AND ticket_id = ? ORDER BY project_id,ticket_id)",
            bindings: [.text(projectID), .text(ticketID)]))
        let tasks = try XCTUnwrap(connection.scalarText(
            "SELECT json_group_array(json_array(project_id,ticket_id,id,label,title,sort_order,completion,lifecycle,created_at,updated_at,completed_at,superseded_at)) FROM (SELECT * FROM ticket_tasks WHERE project_id = ? AND ticket_id = ? ORDER BY id)",
            bindings: [.text(projectID), .text(ticketID)]))
        return ["project": project, "ticket": ticket, "plan": plan, "tasks": tasks]
    }

    private func taskTableSnapshot(_ connection: SQLiteConnection) throws -> [String: String] {
        [
            "ticket_task_plans": try XCTUnwrap(connection.scalarText("SELECT json_group_array(json_array(project_id,ticket_id,revision,created_at,updated_at)) FROM (SELECT * FROM ticket_task_plans ORDER BY project_id,ticket_id)")),
            "ticket_tasks": try XCTUnwrap(connection.scalarText("SELECT json_group_array(json_array(project_id,ticket_id,id,label,title,sort_order,completion,lifecycle,created_at,updated_at,completed_at,superseded_at)) FROM (SELECT * FROM ticket_tasks ORDER BY project_id,ticket_id,id)")),
        ]
    }

    private func makeVersionTwelveDatabaseURL() throws -> URL {
        let databaseURL = try makeDatabaseURL()
        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
        _ = store
        store = nil
        guard try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version") == 12 else {
            throw StoreError.unavailable("Expected schema-v12 test database")
        }
        return databaseURL
    }

    private func reconstructEmptyVersionTwelveTable(
        _ connection: SQLiteConnection,
        table: String,
        dependentObjects: [String],
        sql: String
    ) throws {
        XCTAssertEqual(try connection.scalarInt("SELECT COUNT(*) FROM \(table)"), 0)
        let dependentSQL = try dependentObjects.map { object in
            try XCTUnwrap(
                connection.scalarText(
                    "SELECT sql FROM sqlite_schema WHERE name = ?",
                    bindings: [.text(object)]
                )
            )
        }

        try connection.execute("PRAGMA foreign_keys = OFF")
        try connection.execute("DROP TABLE IF EXISTS \(table)")
        try connection.executeScript(sql)
        for statement in dependentSQL {
            try connection.executeScript(statement)
        }
        try connection.execute("PRAGMA foreign_keys = ON")
    }

    private static let versionElevenOwnershipSeedSQL = """
    INSERT INTO projects (id, name) VALUES ('p1', 'Project One'), ('p2', 'Project Two');
    INSERT INTO phases (id, project_id, name) VALUES
        ('phase-1', 'p1', 'One'),
        ('phase-2', 'p1', 'Two'),
        ('phase-3', 'p2', 'Three');
    INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
        ('ticket-1', 'p1', 'phase-1', 'One', 'backlog'),
        ('ticket-2', 'p1', 'phase-2', 'Two', 'backlog'),
        ('ticket-3', 'p2', 'phase-3', 'Three', 'backlog');
    INSERT INTO delivery_goals
        (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at)
    VALUES
        ('p1', 'phase-1', 'goal-1', 'Goal one', 'Outcome one', 'draft', 0, 't', 't'),
        ('p1', 'phase-1', 'goal-1b', 'Goal one B', 'Outcome one B', 'draft', 1, 't', 't'),
        ('p1', 'phase-2', 'goal-2', 'Goal two', 'Outcome two', 'draft', 0, 't', 't'),
        ('p2', 'phase-3', 'goal-3', 'Goal three', 'Outcome three', 'draft', 0, 't', 't');
    """

    private func copyVerifiedVersionTenFixture() throws -> URL {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixtureDirectory = testsDirectory.appendingPathComponent("Fixtures/SchemaV10", isDirectory: true)
        let fixtureURL = fixtureDirectory.appendingPathComponent("release-radar-v10.sqlite")
        let sumsURL = fixtureDirectory.appendingPathComponent("SHA256SUMS")
        let sumFields = try String(contentsOf: sumsURL, encoding: .utf8)
            .split(whereSeparator: \.isWhitespace)
        let expectedDigest = try XCTUnwrap(sumFields.first.map(String.init))
        let fixtureData = try Data(contentsOf: fixtureURL)
        let actualDigest = SHA256.hash(data: fixtureData).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(actualDigest, expectedDigest)
        XCTAssertEqual(expectedDigest, "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559")

        let databaseURL = try makeDatabaseURL()
        try FileManager.default.copyItem(at: fixtureURL, to: databaseURL)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 10)
        return databaseURL
    }

    private func seedCompleteVersionTenGraph(_ connection: SQLiteConnection) throws {
        try connection.executeScript("""
        INSERT INTO projects (id, name, first_dashboard_opened) VALUES
            ('project-main', 'Main', 1),
            ('project-other', 'Other', 0);
        INSERT INTO project_roots (id, project_id, path) VALUES
            ('root-main', 'project-main', '/tmp/main'),
            ('root-other', 'project-other', '/tmp/other');
        INSERT INTO phases (id, project_id, name) VALUES
            ('phase-1', 'project-main', 'Established'),
            ('phase-2', 'project-main', 'Next');
        INSERT INTO project_active_phases (project_id, phase_id)
            VALUES ('project-main', 'phase-2');
        INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES
            ('ticket-backlog', 'project-main', 'phase-1', 'Backlog outcome', 'backlog'),
            ('ticket-active', 'project-main', 'phase-1', 'Active outcome', 'in_progress'),
            ('ticket-review', 'project-main', 'phase-2', 'Review outcome', 'needs_review'),
            ('ticket-blocked', 'project-main', 'phase-2', 'Blocked outcome', 'blocked'),
            ('ticket-accepted', 'project-main', 'phase-1', 'Accepted outcome', 'accepted');
        INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id)
            VALUES ('phase-dependency', 'project-main', 'phase-2', 'phase-1');
        INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id)
            VALUES ('ticket-dependency', 'project-main', 'ticket-review', 'ticket-accepted');
        INSERT INTO blockers (id, project_id, ticket_id, summary, resolved_at)
            VALUES ('blocker', 'project-main', 'ticket-blocked', 'Still unresolved', NULL);
        INSERT INTO evidence (id, project_id, ticket_id, path, is_available)
            VALUES ('evidence', 'project-main', 'ticket-active', '/tmp/evidence', 1);
        INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status)
            VALUES ('review', 'project-main', 'ticket-review', 'acceptance', 'Review it', 'open');
        INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at)
            VALUES ('completion', 'project-main', 'ticket-accepted', 'Completed', '2026-08-29T10:00:00Z');
        INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale)
            VALUES ('project-main', '/tmp/main', X'00010203', 0);
        INSERT INTO thread_exclusions (id, project_id, thread_id, reason)
            VALUES ('exclusion', 'project-main', 'excluded-thread', 'Private');
        INSERT INTO observed_threads (id, project_id, status, last_observed_at)
            VALUES ('thread-1', 'project-main', 'running', '2026-08-29T10:00:00Z');
        INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at)
            VALUES ('observed-goal-1', 'project-main', 'thread-1', 'active', 'Observed execution', '2026-08-29T10:00:00Z');
        INSERT INTO thread_links (id, project_id, ticket_id, thread_id)
            VALUES ('thread-link', 'project-main', 'ticket-active', 'thread-1');
        INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id)
            VALUES ('goal-link', 'project-main', 'ticket-active', 'thread-1', 'observed-goal-1');
        INSERT INTO notification_events
            (id, fingerprint, state, ticket_id, goal_id, provider_receipt, acknowledged_at,
             project_id, event_kind, subject_id, occurrence, title, message, created_at,
             attempt_count, attempt_started_at, completed_at, failure_code)
            VALUES
            ('notification', 'fingerprint', 'delivered', 'ticket-active', 'observed-goal-1',
             'receipt', NULL, 'project-main', 'goal_blocked', 'observed-goal-1', 1,
             'Blocked', 'Observed goal blocked', '2026-08-29T10:00:00Z', 1,
             '2026-08-29T10:00:01Z', '2026-08-29T10:00:02Z', NULL);
        INSERT INTO notification_occurrences
            (subject_key, project_id, event_kind, subject_id, generation, is_active)
            VALUES ('project-main|observed-goal-1', 'project-main', 'goal_blocked', 'observed-goal-1', 1, 1);
        UPDATE alert_rules SET is_enabled = 1 WHERE kind = 'paused_goals';
        UPDATE codex_plugin_lifecycle
            SET intent = 'managedInstalled', managed_version = '0.1.0', managed_digest = 'digest',
                verified_at = '2026-08-29T10:00:00Z'
            WHERE plugin_id = 'release-radar';
        INSERT INTO audit_events
            (id, actor_id, thread_id, reason, created_at, thread_attribution, project_id, entity_type, entity_id)
            VALUES ('audit-seeded', 'agent', 'thread-1', 'Seed graph', '2026-08-29T10:00:00Z',
                    'verified', 'project-main', 'ticket', 'ticket-active');
        INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at)
            VALUES ('request-1', X'010203', X'040506', '2026-08-29T10:00:00Z');
        """)
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
    }

    private func semanticVersionTenSnapshot(_ connection: SQLiteConnection) throws -> [String: String] {
        let queries: [(String, String)] = [
            ("projects", "SELECT json_group_array(json_array(id,name,first_dashboard_opened)) FROM (SELECT * FROM projects ORDER BY id)"),
            ("project_roots", "SELECT json_group_array(json_array(id,project_id,path)) FROM (SELECT * FROM project_roots ORDER BY id)"),
            ("phases", "SELECT json_group_array(json_array(id,project_id,name)) FROM (SELECT * FROM phases ORDER BY id)"),
            ("tickets", "SELECT json_group_array(json_array(id,project_id,phase_id,outcome,lane)) FROM (SELECT id,project_id,phase_id,outcome,lane FROM tickets ORDER BY id)"),
            ("phase_dependencies", "SELECT json_group_array(json_array(id,project_id,phase_id,depends_on_phase_id)) FROM (SELECT * FROM phase_dependencies ORDER BY id)"),
            ("ticket_dependencies", "SELECT json_group_array(json_array(id,project_id,ticket_id,depends_on_ticket_id)) FROM (SELECT * FROM ticket_dependencies ORDER BY id)"),
            ("blockers", "SELECT json_group_array(json_array(id,project_id,ticket_id,summary,resolved_at)) FROM (SELECT * FROM blockers ORDER BY id)"),
            ("evidence", "SELECT json_group_array(json_array(id,project_id,ticket_id,path,is_available)) FROM (SELECT * FROM evidence ORDER BY id)"),
            ("thread_exclusions", "SELECT json_group_array(json_array(id,project_id,thread_id,reason)) FROM (SELECT * FROM thread_exclusions ORDER BY id)"),
            ("observed_threads", "SELECT json_group_array(json_array(id,project_id,status,last_observed_at)) FROM (SELECT * FROM observed_threads ORDER BY id)"),
            ("observed_goals", "SELECT json_group_array(json_array(id,project_id,thread_id,status,text,last_observed_at)) FROM (SELECT * FROM observed_goals ORDER BY id)"),
            ("thread_links", "SELECT json_group_array(json_array(id,project_id,ticket_id,thread_id)) FROM (SELECT * FROM thread_links ORDER BY id)"),
            ("review_items", "SELECT json_group_array(json_array(id,project_id,ticket_id,kind,summary,status)) FROM (SELECT * FROM review_items ORDER BY id)"),
            ("audit_events", "SELECT json_group_array(json_array(id,actor_id,thread_id,reason,created_at,thread_attribution,project_id,entity_type,entity_id)) FROM (SELECT * FROM audit_events ORDER BY id)"),
            ("notification_events", "SELECT json_group_array(json_array(id,fingerprint,state,ticket_id,goal_id,provider_receipt,acknowledged_at,project_id,event_kind,subject_id,occurrence,title,message,created_at,attempt_count,attempt_started_at,completed_at,failure_code)) FROM (SELECT * FROM notification_events ORDER BY id)"),
            ("completion_records", "SELECT json_group_array(json_array(id,project_id,ticket_id,summary,created_at)) FROM (SELECT * FROM completion_records ORDER BY id)"),
            ("agent_command_requests", "SELECT json_group_array(json_array(request_id,hex(request_body),hex(result_data),created_at)) FROM (SELECT * FROM agent_command_requests ORDER BY request_id)"),
            ("project_bookmarks", "SELECT json_group_array(json_array(project_id,path,hex(bookmark_data),is_stale)) FROM (SELECT * FROM project_bookmarks ORDER BY project_id,path)"),
            ("project_active_phases", "SELECT json_group_array(json_array(project_id,phase_id)) FROM (SELECT * FROM project_active_phases ORDER BY project_id)"),
            ("notification_occurrences", "SELECT json_group_array(json_array(subject_key,project_id,event_kind,subject_id,generation,is_active)) FROM (SELECT * FROM notification_occurrences ORDER BY subject_key)"),
            ("ticket_goal_links", "SELECT json_group_array(json_array(id,project_id,ticket_id,thread_id,goal_id)) FROM (SELECT * FROM ticket_goal_links ORDER BY id)"),
            ("alert_rules", "SELECT json_group_array(json_array(kind,is_enabled)) FROM (SELECT * FROM alert_rules ORDER BY kind)"),
            ("codex_plugin_lifecycle", "SELECT json_group_array(json_array(plugin_id,intent,managed_version,managed_digest,verified_at)) FROM (SELECT * FROM codex_plugin_lifecycle ORDER BY plugin_id)"),
        ]
        return try Dictionary(uniqueKeysWithValues: queries.map { name, query in
            (name, try XCTUnwrap(connection.scalarText(query), "Missing semantic snapshot for \(name)"))
        })
    }

    private func makeVersionElevenDatabaseURL() throws -> URL {
        let databaseURL = try copyVerifiedVersionElevenFixture()
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 11)
        return databaseURL
    }

    private func removeVersionElevenSchema(_ connection: SQLiteConnection) throws {
        try connection.executeScript("""
        DROP TRIGGER IF EXISTS ticket_task_plans_reject_project_delete;
        DROP TRIGGER IF EXISTS ticket_task_plans_reject_ticket_delete;
        DROP TRIGGER IF EXISTS ticket_tasks_reject_delete;
        DROP TRIGGER IF EXISTS ticket_task_plans_reject_delete;
        DROP TRIGGER IF EXISTS ticket_tasks_reject_label_update;
        DROP TRIGGER IF EXISTS ticket_tasks_reject_identity_update;
        DROP INDEX IF EXISTS ticket_tasks_active_order_index;
        DROP INDEX IF EXISTS ticket_tasks_label_unique;
        DROP INDEX IF EXISTS ticket_task_plans_ticket_unique;
        DROP TABLE IF EXISTS ticket_tasks;
        DROP TABLE IF EXISTS ticket_task_plans;
        DROP TRIGGER IF EXISTS tickets_reject_legacy_continuation_regrant;
        DROP TRIGGER IF EXISTS tickets_reject_legacy_continuation_insert;
        DROP TRIGGER IF EXISTS phase_plans_after_phase_insert;
        DROP TABLE IF EXISTS delivery_goal_assignment_events;
        DROP TABLE IF EXISTS delivery_goal_ticket_assignments;
        DROP TABLE IF EXISTS delivery_goal_done_criteria;
        DROP TABLE IF EXISTS delivery_goals;
        DROP TABLE IF EXISTS phase_plans;
        DROP INDEX IF EXISTS tickets_project_phase_identity_unique;
        ALTER TABLE tickets DROP COLUMN plan_legacy_continuation;
        """)
    }

    private func assertMigrationUnavailable(
        databaseURL: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let store = DeliveryStore(databaseURL: databaseURL)
        guard case let .unavailable(recovery) = await store.availability else {
            return XCTFail("Expected schema drift to fail closed", file: file, line: line)
        }
        XCTAssertEqual(recovery.kind, .migration, file: file, line: line)
        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL, file: file, line: line)
        XCTAssertNotNil(recovery.preMigrationSnapshotURL, file: file, line: line)
    }

    private func seedProject(_ store: DeliveryStore) async throws {
        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-02', 'project-1', 'phase-1', 'Store', 'backlog')")
        }
    }

    private static func exactForeignKeyCount(
        _ connection: SQLiteConnection,
        table: String,
        source: String,
        targetTable: String,
        target: String
    ) throws -> Int64? {
        try connection.scalarInt(
            """
            SELECT COUNT(*) FROM (
                SELECT id, \"table\" AS target_table,
                       group_concat(\"from\", ',') AS source_columns,
                       group_concat(\"to\", ',') AS target_columns
                FROM (SELECT * FROM pragma_foreign_key_list('\(table)') ORDER BY id, seq)
                GROUP BY id
            )
            WHERE target_table = ? AND source_columns = ? AND target_columns = ?
            """,
            bindings: [.text(targetTable), .text(source), .text(target)]
        )
    }

    private func makeDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("release-radar.sqlite")
    }

    private func XCTAssertThrowsErrorAsync(
        _ expression: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected expression to throw", file: file, line: line)
        } catch {}
    }
}

private struct DeliveryGoalModelEnvelope: Codable, Equatable {
    let draft: DeliveryGoalDraft
    let assignment: DeliveryGoalAssignment
    let phasePlan: PhasePlanRecord
    let goal: DeliveryGoalRecord
    let criterion: DeliveryGoalCriterionRecord
    let assignmentRecord: DeliveryGoalAssignmentRecord
    let assignmentEvent: DeliveryGoalAssignmentEventRecord
    let readinessFailure: PhasePlanReadinessFailure
}

private enum CallbackFailure: Error {
    case expected
}
