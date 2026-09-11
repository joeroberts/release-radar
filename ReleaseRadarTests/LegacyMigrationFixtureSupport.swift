import XCTest
@testable import ReleaseRadarCore

private enum LegacyMigrationFixtureError: Error {
    case newerSchemaContainsData(String)
}

private func requireEmptyFixtureTables(
    _ tables: [String],
    connection: SQLiteConnection
) throws {
    for table in tables {
        let count = try connection.scalarInt("SELECT COUNT(*) FROM \(table)") ?? 0
        guard count == 0 else {
            XCTFail("Synthetic legacy fixtures must not discard newer \(table) data")
            throw LegacyMigrationFixtureError.newerSchemaContainsData(table)
        }
    }
}

func removeVersionTwentySixSearchSchema(_ connection: SQLiteConnection) throws {
    try requireEmptyFixtureTables(
        ["workspace_search_preferences", "workspace_saved_queries"],
        connection: connection
    )
    try connection.executeScript("""
    DROP TABLE workspace_saved_queries;
    DROP TABLE workspace_search_preferences;
    """)
}

func removeVersionTwentyFiveDeliveryEvidenceSchema(_ connection: SQLiteConnection) throws {
    try removeVersionTwentySixSearchSchema(connection)
    try requireEmptyFixtureTables(
        [
            "ticket_delivery_evidence_sets",
            "ticket_delivery_evidence_targets",
            "ticket_delivery_evidence_observations",
            "retained_ticket_delivery_evidence_targets",
            "retained_ticket_delivery_evidence_observations",
        ],
        connection: connection
    )
    try connection.executeScript("""
    DROP TRIGGER ticket_delivery_evidence_sets_reject_delete;
    DROP TRIGGER ticket_delivery_evidence_targets_reject_update;
    DROP TRIGGER ticket_delivery_evidence_targets_reject_delete;
    DROP TRIGGER ticket_delivery_evidence_observations_reject_update;
    DROP TRIGGER ticket_delivery_evidence_observations_reject_delete;
    DROP TRIGGER retained_ticket_delivery_evidence_targets_reject_update;
    DROP TRIGGER retained_ticket_delivery_evidence_targets_reject_delete;
    DROP TRIGGER retained_ticket_delivery_evidence_observations_reject_update;
    DROP TRIGGER retained_ticket_delivery_evidence_observations_reject_delete;
    DROP TABLE retained_ticket_delivery_evidence_observations;
    DROP TABLE retained_ticket_delivery_evidence_targets;
    DROP TABLE ticket_delivery_evidence_observations;
    DROP TABLE ticket_delivery_evidence_targets;
    DROP TABLE ticket_delivery_evidence_sets;
    """)
}

func removeVersionTwentyFourHistorySchema(_ connection: SQLiteConnection) throws {
    try removeVersionTwentyFiveDeliveryEvidenceSchema(connection)
    for column in [
        "event_current_phase_id",
        "event_previous_phase_id",
        "event_current_lane",
        "event_previous_lane",
        "event_ticket_outcome",
        "event_phase_name",
        "event_phase_id",
        "event_ticket_id",
        "event_request_generation",
        "event_registration_id",
        "event_project_name",
        "event_recorded_at",
        "event_occurred_at",
        "event_provenance",
        "event_facts_recorded",
    ] {
        try connection.execute("ALTER TABLE audit_events DROP COLUMN \(column)")
    }
}

func removeVersionTwentyThreePhaseLifecycleSchema(_ connection: SQLiteConnection) throws {
    try removeVersionTwentyFourHistorySchema(connection)
    try connection.executeScript("""
    DROP TRIGGER IF EXISTS phase_lifecycles_after_phase_insert;
    DROP TRIGGER IF EXISTS phase_lifecycle_events_reject_update;
    DROP TRIGGER IF EXISTS phase_lifecycle_events_reject_delete;
    DROP TRIGGER IF EXISTS retained_phase_lifecycles_reject_update;
    DROP TRIGGER IF EXISTS retained_phase_lifecycles_reject_delete;
    DROP TRIGGER IF EXISTS retained_phase_lifecycle_events_reject_update;
    DROP TRIGGER IF EXISTS retained_phase_lifecycle_events_reject_delete;
    DROP TABLE IF EXISTS retained_phase_lifecycle_events;
    DROP TABLE IF EXISTS retained_phase_lifecycles;
    DROP TABLE IF EXISTS phase_lifecycle_events;
    DROP TABLE IF EXISTS phase_lifecycles;
    """)
}

func removeVersionTwentyTwoCarryForwardSchema(_ connection: SQLiteConnection) throws {
    try removeVersionTwentyThreePhaseLifecycleSchema(connection)
    try connection.execute("PRAGMA foreign_keys = OFF")
    defer { try? connection.execute("PRAGMA foreign_keys = ON") }
    try connection.executeScript("""
    DROP TRIGGER IF EXISTS retained_ticket_retirements_reject_update;
    DROP TRIGGER IF EXISTS retained_ticket_retirements_reject_delete;
    DROP TRIGGER IF EXISTS retained_ticket_successor_links_reject_update;
    DROP TRIGGER IF EXISTS retained_ticket_successor_links_reject_delete;
    DROP TRIGGER IF EXISTS retained_delivery_goal_obligations_reject_update;
    DROP TRIGGER IF EXISTS retained_delivery_goal_obligations_reject_delete;
    DROP TRIGGER IF EXISTS retained_delivery_goal_obligation_lineage_reject_update;
    DROP TRIGGER IF EXISTS retained_delivery_goal_obligation_lineage_reject_delete;
    DROP TRIGGER IF EXISTS retained_delivery_goal_obligation_drops_reject_update;
    DROP TRIGGER IF EXISTS retained_delivery_goal_obligation_drops_reject_delete;
    DROP TABLE IF EXISTS retained_delivery_goal_obligation_drops;
    DROP TABLE IF EXISTS retained_delivery_goal_obligation_lineage;
    DROP TABLE IF EXISTS retained_ticket_successor_links;
    DROP TABLE IF EXISTS retained_ticket_retirements;
    DROP TABLE IF EXISTS retained_delivery_goal_obligations;
    DROP TABLE IF EXISTS delivery_goal_obligation_drops;
    DROP TABLE IF EXISTS delivery_goal_obligation_lineage;
    DROP TABLE IF EXISTS ticket_successor_links;
    DROP TABLE IF EXISTS ticket_retirements;
    DROP TABLE IF EXISTS delivery_goal_obligations;
    DROP INDEX IF EXISTS delivery_goal_assignment_events_ticket_revision_unique;
    ALTER TABLE delivery_goal_assignment_events RENAME TO delivery_goal_assignment_events_v22;
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
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) DEFERRABLE INITIALLY DEFERRED,
        FOREIGN KEY(project_id, phase_id) REFERENCES phase_plans(project_id, phase_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id),
        FOREIGN KEY(project_id, phase_id, previous_goal_id) REFERENCES delivery_goals(project_id, phase_id, id),
        FOREIGN KEY(project_id, phase_id, current_goal_id) REFERENCES delivery_goals(project_id, phase_id, id),
        CHECK (
            (action = 'assigned' AND previous_goal_id IS NULL AND current_goal_id IS NOT NULL)
            OR (action = 'unassigned' AND previous_goal_id IS NOT NULL AND current_goal_id IS NULL)
            OR (action = 'reassigned' AND previous_goal_id IS NOT NULL AND current_goal_id IS NOT NULL AND previous_goal_id <> current_goal_id)
        )
    );
    INSERT INTO delivery_goal_assignment_events SELECT * FROM delivery_goal_assignment_events_v22;
    DROP TABLE delivery_goal_assignment_events_v22;
    """)
}

func removeVersionTwentyOneProposalSchema(_ connection: SQLiteConnection) throws {
    for table in [
        "plan_change_proposal_applications",
        "plan_change_proposal_decisions",
        "plan_change_proposal_versions",
        "plan_change_proposals",
        "retained_plan_change_proposal_applications",
        "retained_plan_change_proposal_decisions",
        "retained_plan_change_proposal_versions",
        "retained_plan_change_proposals",
    ] {
        XCTAssertEqual(
            try connection.scalarInt("SELECT COUNT(*) FROM \(table)"),
            0,
            "Synthetic legacy fixtures must not discard proposal history"
        )
    }
    try connection.execute("PRAGMA foreign_keys = OFF")
    defer { try? connection.execute("PRAGMA foreign_keys = ON") }
    try connection.executeScript("""
    DROP TRIGGER IF EXISTS plan_change_proposal_versions_reject_update;
    DROP TRIGGER IF EXISTS plan_change_proposal_versions_reject_delete;
    DROP TRIGGER IF EXISTS plan_change_proposal_decisions_reject_update;
    DROP TRIGGER IF EXISTS plan_change_proposal_decisions_reject_delete;
    DROP TRIGGER IF EXISTS plan_change_proposal_applications_reject_update;
    DROP TRIGGER IF EXISTS plan_change_proposal_applications_reject_delete;
    DROP TRIGGER IF EXISTS retained_plan_change_proposals_reject_update;
    DROP TRIGGER IF EXISTS retained_plan_change_proposals_reject_delete;
    DROP TRIGGER IF EXISTS retained_plan_change_proposal_versions_reject_update;
    DROP TRIGGER IF EXISTS retained_plan_change_proposal_versions_reject_delete;
    DROP TRIGGER IF EXISTS retained_plan_change_proposal_decisions_reject_update;
    DROP TRIGGER IF EXISTS retained_plan_change_proposal_decisions_reject_delete;
    DROP TRIGGER IF EXISTS retained_plan_change_proposal_applications_reject_update;
    DROP TRIGGER IF EXISTS retained_plan_change_proposal_applications_reject_delete;
    DROP TABLE IF EXISTS plan_change_proposal_applications;
    DROP TABLE IF EXISTS plan_change_proposal_decisions;
    DROP TABLE IF EXISTS plan_change_proposal_versions;
    DROP TABLE IF EXISTS plan_change_proposals;
    DROP TABLE IF EXISTS retained_plan_change_proposal_applications;
    DROP TABLE IF EXISTS retained_plan_change_proposal_decisions;
    DROP TABLE IF EXISTS retained_plan_change_proposal_versions;
    DROP TABLE IF EXISTS retained_plan_change_proposals;
    """)
}

func removeVersionTwentyReferenceSchema(_ connection: SQLiteConnection) throws {
    try removeVersionTwentyTwoCarryForwardSchema(connection)
    try removeVersionTwentyOneProposalSchema(connection)
    for table in [
        "ticket_reference_versions",
        "ticket_reference_links",
        "ticket_reference_link_sets",
        "retained_ticket_reference_versions",
        "retained_ticket_reference_links",
    ] {
        XCTAssertEqual(
            try connection.scalarInt("SELECT COUNT(*) FROM \(table)"),
            0,
            "Synthetic legacy fixtures must not discard reference history"
        )
    }
    try connection.execute("PRAGMA foreign_keys = OFF")
    defer { try? connection.execute("PRAGMA foreign_keys = ON") }
    try connection.executeScript("""
    DROP TRIGGER IF EXISTS ticket_reference_versions_reject_update;
    DROP TRIGGER IF EXISTS ticket_reference_versions_reject_delete;
    DROP TRIGGER IF EXISTS ticket_reference_links_reject_identity_update;
    DROP TRIGGER IF EXISTS ticket_reference_links_reject_delete;
    DROP TRIGGER IF EXISTS ticket_reference_link_sets_reject_delete;
    DROP TABLE IF EXISTS ticket_reference_versions;
    DROP TABLE IF EXISTS ticket_reference_links;
    DROP TABLE IF EXISTS ticket_reference_link_sets;
    DROP TABLE IF EXISTS retained_ticket_reference_versions;
    DROP TABLE IF EXISTS retained_ticket_reference_links;
    """)
}

func restorePreVersionNineteenTicketSchema(_ connection: SQLiteConnection) throws {
    try removeVersionTwentyReferenceSchema(connection)
    try connection.execute("PRAGMA foreign_keys = OFF")
    defer { try? connection.execute("PRAGMA foreign_keys = ON") }
    try connection.executeScript("""
    PRAGMA legacy_alter_table = ON;
    ALTER TABLE tickets RENAME TO tickets_v19;
    CREATE TABLE tickets (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        phase_id TEXT NOT NULL,
        outcome TEXT NOT NULL,
        lane TEXT NOT NULL CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
        plan_legacy_continuation INTEGER NOT NULL DEFAULT 0
            CHECK (plan_legacy_continuation IN (0, 1)),
        UNIQUE(project_id, id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
    );
    INSERT INTO tickets (id, project_id, phase_id, outcome, lane, plan_legacy_continuation)
        SELECT id, project_id, phase_id, outcome, lane, plan_legacy_continuation FROM tickets_v19;
    DROP TABLE tickets_v19;
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
    CREATE TRIGGER ticket_task_plans_reject_ticket_delete
    BEFORE DELETE ON tickets
    WHEN EXISTS (
        SELECT 1 FROM ticket_task_plans
        WHERE project_id = OLD.project_id AND ticket_id = OLD.id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket owns task history');
    END;
    PRAGMA legacy_alter_table = OFF;
    """)
    XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
}
