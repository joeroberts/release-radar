import Foundation
import XCTest
@testable import ReleaseRadarCore

final class StoreAcceptanceTests: XCTestCase {
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
        try legacy.executeScript("""
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
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 9)
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
        try legacy.executeScript("""
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
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 9)
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
        try legacy.executeScript("""
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
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 9)

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
        XCTAssertEqual(try relaunchedDatabase.scalarInt("PRAGMA user_version"), 9)
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

private enum CallbackFailure: Error {
    case expected
}
