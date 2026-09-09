import XCTest
@testable import ReleaseRadarCore

func restorePreVersionNineteenTicketSchema(_ connection: SQLiteConnection) throws {
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
