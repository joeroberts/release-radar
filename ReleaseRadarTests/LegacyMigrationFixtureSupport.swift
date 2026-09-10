import XCTest
@testable import ReleaseRadarCore

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
