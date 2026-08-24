import Foundation

enum StoreMigrations {
    static let currentVersion: Int64 = 7

    static func requiresMigrationOrRepair(_ connection: SQLiteConnection) throws -> Bool {
        let version = try connection.scalarInt("PRAGMA user_version") ?? 0
        if version != currentVersion { return true }
        return try !hasExpectedCurrentSchema(connection)
    }

    static func migrate(_ connection: SQLiteConnection) throws {
        let version = try connection.scalarInt("PRAGMA user_version") ?? 0
        guard version <= currentVersion else {
            throw StoreError.unsupportedSchemaVersion(found: version, supported: currentVersion)
        }
        if version == currentVersion, try hasExpectedCurrentSchema(connection) { return }

        try connection.execute("BEGIN EXCLUSIVE TRANSACTION")
        do {
            try repairKnownSchemaDrift(connection, version: version)
            if version < 1 {
                try connection.executeScript(schemaVersion1)
            }
            if version < 2 {
                try connection.executeScript(schemaVersion2)
            }
            if version < 3 {
                try connection.executeScript(schemaVersion3)
            }
            if version < 4 {
                try connection.executeScript(schemaVersion4)
            }
            if version < 5 {
                try connection.executeScript(schemaVersion5)
            }
            if version < 6 {
                try connection.executeScript(schemaVersion6)
            }
            if version < 7 {
                try connection.executeScript(schemaVersion7)
            }
            guard try hasExpectedCurrentSchema(connection) else {
                throw StoreError.unavailable(
                    "Database schema version \(version) does not match a recognized Release Radar schema"
                )
            }
            try connection.execute("PRAGMA user_version = \(currentVersion)")
            try connection.execute("COMMIT")
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    private static func repairKnownSchemaDrift(
        _ connection: SQLiteConnection,
        version: Int64
    ) throws {
        if version == 3,
           try hasTable(connection, name: "audit_events"),
           try !hasColumn(connection, table: "audit_events", name: "thread_attribution") {
            guard try isKnownVersionThreeAuditDrift(connection, version: version) else {
                throw StoreError.unavailable(
                    "Database schema version 3 does not match a recognized Release Radar schema"
                )
            }
            try connection.executeScript(schemaVersionThreeAuditRepair)
        }
        if try isKnownVersionSevenOwnerDrift(connection, version: version) {
            try connection.executeScript(schemaVersionSevenOwnerRepair)
        }
    }

    private static func isKnownVersionThreeAuditDrift(
        _ connection: SQLiteConnection,
        version: Int64
    ) throws -> Bool {
        guard version == 3,
              try !hasColumn(connection, table: "audit_events", name: "thread_attribution"),
              try !hasColumn(connection, table: "audit_events", name: "project_id"),
              try !hasTable(connection, name: "project_active_phases")
        else { return false }
        return try hasRequiredSchema(
            connection,
            throughVersion: 3,
            missingColumns: ["audit_events.thread_attribution"]
        )
    }

    private static func isKnownVersionSevenOwnerDrift(
        _ connection: SQLiteConnection,
        version: Int64
    ) throws -> Bool {
        guard version == 7,
              try hasColumn(connection, table: "audit_events", name: "thread_attribution"),
              try !hasColumn(connection, table: "audit_events", name: "project_id"),
              try !hasColumn(connection, table: "audit_events", name: "entity_type"),
              try !hasColumn(connection, table: "audit_events", name: "entity_id"),
              try hasColumn(connection, table: "projects", name: "active_phase_id"),
              try !hasTable(connection, name: "project_active_phases")
        else { return false }
        return try hasRequiredSchema(
            connection,
            throughVersion: currentVersion,
            missingTables: ["project_active_phases"],
            missingColumns: [
                "audit_events.project_id",
                "audit_events.entity_type",
                "audit_events.entity_id",
            ],
            missingObjects: [
                "audit_events_project_entity_index",
                "project_active_phases_phase_index",
            ]
        )
    }

    private static func hasExpectedCurrentSchema(_ connection: SQLiteConnection) throws -> Bool {
        try hasRequiredSchema(connection, throughVersion: currentVersion)
    }

    private static func hasRequiredSchema(
        _ connection: SQLiteConnection,
        throughVersion version: Int64,
        missingTables: Set<String> = [],
        missingColumns: Set<String> = [],
        missingObjects: Set<String> = []
    ) throws -> Bool {
        var tables: [(name: String, columns: [String])] = baseTables
        for table in addedTables where table.version <= version {
            tables.append((table.name, table.columns))
        }

        for table in tables {
            if missingTables.contains(table.name) {
                guard try !hasTable(connection, name: table.name) else { return false }
                continue
            }
            guard try hasTable(connection, name: table.name) else { return false }
            var expected = table.columns
            for column in addedColumns where column.version <= version && column.table == table.name {
                expected.append(column.name)
            }
            expected.removeAll { missingColumns.contains("\(table.name).\($0)") }
            let allowedExtras: Set<String> = table.name == "projects" ? ["active_phase_id"] : []
            let actual = try columnNames(connection, table: table.name)
            guard actual.filter({ !allowedExtras.contains($0) }) == expected else { return false }
        }

        for futureTable in addedTables where futureTable.version > version {
            guard try !hasTable(connection, name: futureTable.name) else { return false }
        }
        for object in criticalObjects {
            let shouldExist = object.version <= version && !missingObjects.contains(object.name)
            guard try hasObject(connection, type: object.type, name: object.name) == shouldExist else {
                return false
            }
        }
        guard try hasExpectedTriggerSemantics(connection, throughVersion: version),
              try hasExpectedIndexes(
                connection,
                throughVersion: version,
                missingObjects: missingObjects
              ),
              try hasExpectedForeignKeys(
                connection,
                throughVersion: version,
                missingTables: missingTables,
                missingColumns: missingColumns
              )
        else { return false }
        return try connection.row("PRAGMA foreign_key_check") == nil
    }

    private static func hasExpectedTriggerSemantics(
        _ connection: SQLiteConnection,
        throughVersion version: Int64
    ) throws -> Bool {
        for trigger in criticalTriggers where trigger.version <= version {
            guard let sql = try connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'trigger' AND name = ?",
                bindings: [.text(trigger.name)]
            ) else { return false }
            guard normalizedSQL(sql) == normalizedSQL(trigger.sql) else { return false }
        }
        return true
    }

    private static func normalizedSQL(_ sql: String) -> String {
        sql.lowercased().split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
    }

    private static func hasExpectedIndexes(
        _ connection: SQLiteConnection,
        throughVersion version: Int64,
        missingObjects: Set<String>
    ) throws -> Bool {
        for index in criticalIndexes where index.version <= version && !missingObjects.contains(index.name) {
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM pragma_index_list('\(index.table)') WHERE name = ? AND \"unique\" = ?",
                bindings: [.text(index.name), .integer(index.isUnique ? 1 : 0)]
            ) == 1,
            try connection.scalarInt(
                "SELECT COUNT(*) FROM pragma_index_xinfo('\(index.name)') WHERE key = 1"
            ) == Int64(index.columns.count)
            else { return false }
            for (offset, column) in index.columns.enumerated() {
                guard try connection.scalarText(
                    "SELECT name FROM pragma_index_xinfo('\(index.name)') WHERE key = 1 AND seqno = ?",
                    bindings: [.integer(Int64(offset))]
                ) == column.name,
                try connection.scalarInt(
                    "SELECT desc FROM pragma_index_xinfo('\(index.name)') WHERE key = 1 AND seqno = ?",
                    bindings: [.integer(Int64(offset))]
                ) == (column.descending ? 1 : 0)
                else { return false }
            }
        }
        return true
    }

    private static func hasExpectedForeignKeys(
        _ connection: SQLiteConnection,
        throughVersion version: Int64,
        missingTables: Set<String>,
        missingColumns: Set<String>
    ) throws -> Bool {
        for foreignKey in requiredForeignKeys where foreignKey.version <= version {
            guard !missingTables.contains(foreignKey.table),
                  foreignKey.source.split(separator: ",").allSatisfy({
                    !missingColumns.contains("\(foreignKey.table).\($0)")
                  })
            else { continue }
            let sql = """
            SELECT COUNT(*) FROM (
                SELECT id, \"table\" AS target_table, on_delete,
                       group_concat(\"from\", ',') AS source_columns,
                       group_concat(\"to\", ',') AS target_columns
                FROM (SELECT * FROM pragma_foreign_key_list('\(foreignKey.table)') ORDER BY id, seq)
                GROUP BY id
            )
            WHERE target_table = ? AND source_columns = ? AND target_columns = ? AND on_delete = ?
            """
            guard try connection.scalarInt(sql, bindings: [
                .text(foreignKey.targetTable),
                .text(foreignKey.source),
                .text(foreignKey.target),
                .text(foreignKey.onDelete),
            ]) == 1 else { return false }
        }
        return true
    }

    private static func columnNames(
        _ connection: SQLiteConnection,
        table: String
    ) throws -> [String] {
        var names: [String] = []
        var offset: Int64 = 0
        while let name = try connection.scalarText(
            "SELECT name FROM pragma_table_info('\(table)') ORDER BY cid LIMIT 1 OFFSET ?",
            bindings: [.integer(offset)]
        ) {
            names.append(name)
            offset += 1
        }
        return names
    }

    private static func hasColumn(
        _ connection: SQLiteConnection,
        table: String,
        name: String
    ) throws -> Bool {
        try connection.scalarInt(
            "SELECT COUNT(*) FROM pragma_table_info('\(table)') WHERE name = ?",
            bindings: [.text(name)]
        ) == 1
    }

    private static func hasTable(_ connection: SQLiteConnection, name: String) throws -> Bool {
        try connection.scalarInt(
            "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = ?",
            bindings: [.text(name)]
        ) == 1
    }

    private static func hasObject(
        _ connection: SQLiteConnection,
        type: String,
        name: String
    ) throws -> Bool {
        try connection.scalarInt(
            "SELECT COUNT(*) FROM sqlite_schema WHERE type = ? AND name = ?",
            bindings: [.text(type), .text(name)]
        ) == 1
    }

    private static let baseTables: [(name: String, columns: [String])] = [
        ("projects", ["id", "name"]),
        ("project_roots", ["id", "project_id", "path"]),
        ("phases", ["id", "project_id", "name"]),
        ("tickets", ["id", "project_id", "phase_id", "outcome", "lane"]),
        ("phase_dependencies", ["id", "project_id", "phase_id", "depends_on_phase_id"]),
        ("ticket_dependencies", ["id", "project_id", "ticket_id", "depends_on_ticket_id"]),
        ("blockers", ["id", "project_id", "ticket_id", "summary"]),
        ("evidence", ["id", "project_id", "ticket_id", "path", "is_available"]),
        ("thread_exclusions", ["id", "project_id", "thread_id", "reason"]),
        ("observed_threads", ["id", "project_id", "status", "last_observed_at"]),
        ("observed_goals", ["id", "project_id", "thread_id", "status", "text", "last_observed_at"]),
        ("thread_links", ["id", "project_id", "ticket_id", "thread_id"]),
        ("review_items", ["id", "project_id", "ticket_id", "kind", "summary"]),
        ("audit_events", ["id", "actor_id", "thread_id", "reason", "created_at"]),
        ("notification_events", [
            "id", "fingerprint", "state", "ticket_id", "goal_id",
            "provider_receipt", "acknowledged_at",
        ]),
    ]

    private static let addedTables: [(version: Int64, name: String, columns: [String])] = [
        (2, "completion_records", ["id", "project_id", "ticket_id", "summary", "created_at"]),
        (2, "agent_command_requests", ["request_id", "request_body", "result_data", "created_at"]),
        (3, "project_bookmarks", ["project_id", "path", "bookmark_data", "is_stale"]),
        (5, "project_active_phases", ["project_id", "phase_id"]),
        (6, "notification_occurrences", [
            "subject_key", "project_id", "event_kind", "subject_id", "generation", "is_active",
        ]),
    ]

    private static let addedColumns: [(version: Int64, table: String, name: String)] = [
        (2, "audit_events", "thread_attribution"),
        (2, "blockers", "resolved_at"),
        (2, "review_items", "status"),
        (3, "projects", "first_dashboard_opened"),
        (4, "audit_events", "project_id"),
        (4, "audit_events", "entity_type"),
        (4, "audit_events", "entity_id"),
        (6, "notification_events", "project_id"),
        (6, "notification_events", "event_kind"),
        (6, "notification_events", "subject_id"),
        (6, "notification_events", "occurrence"),
        (6, "notification_events", "title"),
        (6, "notification_events", "message"),
        (6, "notification_events", "created_at"),
        (6, "notification_events", "attempt_count"),
        (6, "notification_events", "attempt_started_at"),
        (6, "notification_events", "completed_at"),
        (6, "notification_events", "failure_code"),
    ]

    private static let criticalObjects: [(version: Int64, type: String, name: String)] = [
        (1, "trigger", "reject_phase_dependency_cycle_insert"),
        (1, "trigger", "reject_phase_dependency_cycle_update"),
        (1, "trigger", "reject_ticket_dependency_cycle_insert"),
        (1, "trigger", "reject_ticket_dependency_cycle_update"),
        (4, "index", "audit_events_project_entity_index"),
        (5, "index", "project_active_phases_phase_index"),
        (6, "index", "notification_events_project_created_index"),
        (6, "index", "notification_events_state_index"),
    ]

    private static let phaseDependencyCycleInsertTrigger = """
    CREATE TRIGGER reject_phase_dependency_cycle_insert
    BEFORE INSERT ON phase_dependencies
    WHEN EXISTS (
        WITH RECURSIVE dependency_path(phase_id) AS (
            SELECT NEW.depends_on_phase_id
            UNION
            SELECT dependency.depends_on_phase_id
            FROM phase_dependencies AS dependency
            JOIN dependency_path ON dependency.phase_id = dependency_path.phase_id
            WHERE dependency.project_id = NEW.project_id
        )
        SELECT 1 FROM dependency_path WHERE phase_id = NEW.phase_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'phase dependency cycle');
    END
    """

    private static let phaseDependencyCycleUpdateTrigger = """
    CREATE TRIGGER reject_phase_dependency_cycle_update
    BEFORE UPDATE OF project_id, phase_id, depends_on_phase_id ON phase_dependencies
    WHEN EXISTS (
        WITH RECURSIVE dependency_path(phase_id) AS (
            SELECT NEW.depends_on_phase_id
            UNION
            SELECT dependency.depends_on_phase_id
            FROM phase_dependencies AS dependency
            JOIN dependency_path ON dependency.phase_id = dependency_path.phase_id
            WHERE dependency.project_id = NEW.project_id AND dependency.id <> OLD.id
        )
        SELECT 1 FROM dependency_path WHERE phase_id = NEW.phase_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'phase dependency cycle');
    END
    """

    private static let ticketDependencyCycleInsertTrigger = """
    CREATE TRIGGER reject_ticket_dependency_cycle_insert
    BEFORE INSERT ON ticket_dependencies
    WHEN EXISTS (
        WITH RECURSIVE dependency_path(ticket_id) AS (
            SELECT NEW.depends_on_ticket_id
            UNION
            SELECT dependency.depends_on_ticket_id
            FROM ticket_dependencies AS dependency
            JOIN dependency_path ON dependency.ticket_id = dependency_path.ticket_id
            WHERE dependency.project_id = NEW.project_id
        )
        SELECT 1 FROM dependency_path WHERE ticket_id = NEW.ticket_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket dependency cycle');
    END
    """

    private static let ticketDependencyCycleUpdateTrigger = """
    CREATE TRIGGER reject_ticket_dependency_cycle_update
    BEFORE UPDATE OF project_id, ticket_id, depends_on_ticket_id ON ticket_dependencies
    WHEN EXISTS (
        WITH RECURSIVE dependency_path(ticket_id) AS (
            SELECT NEW.depends_on_ticket_id
            UNION
            SELECT dependency.depends_on_ticket_id
            FROM ticket_dependencies AS dependency
            JOIN dependency_path ON dependency.ticket_id = dependency_path.ticket_id
            WHERE dependency.project_id = NEW.project_id AND dependency.id <> OLD.id
        )
        SELECT 1 FROM dependency_path WHERE ticket_id = NEW.ticket_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket dependency cycle');
    END
    """

    private static let criticalTriggers: [(version: Int64, name: String, sql: String)] = [
        (1, "reject_phase_dependency_cycle_insert", phaseDependencyCycleInsertTrigger),
        (1, "reject_phase_dependency_cycle_update", phaseDependencyCycleUpdateTrigger),
        (1, "reject_ticket_dependency_cycle_insert", ticketDependencyCycleInsertTrigger),
        (1, "reject_ticket_dependency_cycle_update", ticketDependencyCycleUpdateTrigger),
    ]

    private static let criticalIndexes: [(
        version: Int64,
        name: String,
        table: String,
        isUnique: Bool,
        columns: [(name: String, descending: Bool)]
    )] = [
        (4, "audit_events_project_entity_index", "audit_events", false,
         [("project_id", false), ("entity_type", false), ("entity_id", false), ("created_at", false)]),
        (5, "project_active_phases_phase_index", "project_active_phases", false, [("phase_id", false)]),
        (6, "notification_events_project_created_index", "notification_events", false,
         [("project_id", false), ("created_at", true)]),
        (6, "notification_events_state_index", "notification_events", false,
         [("state", false), ("created_at", false)]),
    ]

    private static let requiredForeignKeys: [(
        version: Int64,
        table: String,
        source: String,
        targetTable: String,
        target: String,
        onDelete: String
    )] = [
        (1, "project_roots", "project_id", "projects", "id", "CASCADE"),
        (1, "phases", "project_id", "projects", "id", "CASCADE"),
        (1, "tickets", "project_id", "projects", "id", "CASCADE"),
        (1, "tickets", "project_id,phase_id", "phases", "project_id,id", "NO ACTION"),
        (1, "phase_dependencies", "project_id,phase_id", "phases", "project_id,id", "CASCADE"),
        (1, "phase_dependencies", "project_id,depends_on_phase_id", "phases", "project_id,id", "CASCADE"),
        (1, "ticket_dependencies", "project_id,ticket_id", "tickets", "project_id,id", "CASCADE"),
        (1, "ticket_dependencies", "project_id,depends_on_ticket_id", "tickets", "project_id,id", "CASCADE"),
        (1, "blockers", "project_id,ticket_id", "tickets", "project_id,id", "CASCADE"),
        (1, "evidence", "project_id", "projects", "id", "CASCADE"),
        (1, "evidence", "project_id,ticket_id", "tickets", "project_id,id", "CASCADE"),
        (1, "thread_exclusions", "project_id", "projects", "id", "CASCADE"),
        (1, "observed_threads", "project_id", "projects", "id", "CASCADE"),
        (1, "observed_goals", "project_id,thread_id", "observed_threads", "project_id,id", "CASCADE"),
        (1, "thread_links", "project_id,ticket_id", "tickets", "project_id,id", "CASCADE"),
        (1, "thread_links", "project_id,thread_id", "observed_threads", "project_id,id", "CASCADE"),
        (1, "review_items", "project_id", "projects", "id", "CASCADE"),
        (1, "review_items", "project_id,ticket_id", "tickets", "project_id,id", "CASCADE"),
        (1, "notification_events", "ticket_id", "tickets", "id", "SET NULL"),
        (1, "notification_events", "goal_id", "observed_goals", "id", "SET NULL"),
        (2, "completion_records", "project_id,ticket_id", "tickets", "project_id,id", "CASCADE"),
        (3, "project_bookmarks", "project_id", "projects", "id", "CASCADE"),
        (4, "audit_events", "project_id", "projects", "id", "SET NULL"),
        (5, "project_active_phases", "project_id", "projects", "id", "CASCADE"),
        (5, "project_active_phases", "project_id,phase_id", "phases", "project_id,id", "NO ACTION"),
        (6, "notification_events", "project_id", "projects", "id", "CASCADE"),
        (6, "notification_occurrences", "project_id", "projects", "id", "CASCADE"),
    ]
    private static let schemaVersionThreeAuditRepair = """
    ALTER TABLE audit_events ADD COLUMN thread_attribution TEXT NOT NULL DEFAULT 'none'
        CHECK (thread_attribution IN ('none', 'asserted', 'verified'));
    """

    private static let schemaVersionSevenOwnerRepair = """
    ALTER TABLE audit_events ADD COLUMN project_id TEXT REFERENCES projects(id) ON DELETE SET NULL;
    ALTER TABLE audit_events ADD COLUMN entity_type TEXT;
    ALTER TABLE audit_events ADD COLUMN entity_id TEXT;
    CREATE INDEX audit_events_project_entity_index
        ON audit_events(project_id, entity_type, entity_id, created_at);
    CREATE TABLE project_active_phases (
        project_id TEXT PRIMARY KEY NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        phase_id TEXT NOT NULL,
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
    );
    CREATE INDEX project_active_phases_phase_index ON project_active_phases(phase_id);
    INSERT INTO project_active_phases (project_id, phase_id)
    SELECT projects.id, projects.active_phase_id
    FROM projects
    JOIN phases
      ON phases.project_id = projects.id
     AND phases.id = projects.active_phase_id
    WHERE projects.active_phase_id IS NOT NULL;
    """

    private static let schemaVersion1 = """
    CREATE TABLE projects (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL
    );
    CREATE TABLE project_roots (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        path TEXT NOT NULL UNIQUE
    );
    CREATE TABLE phases (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        UNIQUE(project_id, id)
    );
    CREATE TABLE tickets (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        phase_id TEXT NOT NULL,
        outcome TEXT NOT NULL,
        lane TEXT NOT NULL CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
        UNIQUE(project_id, id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
    );
    CREATE TABLE phase_dependencies (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        depends_on_phase_id TEXT NOT NULL,
        UNIQUE(phase_id, depends_on_phase_id),
        CHECK (phase_id <> depends_on_phase_id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE,
        FOREIGN KEY(project_id, depends_on_phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE
    );
    \(phaseDependencyCycleInsertTrigger);
    \(phaseDependencyCycleUpdateTrigger);
    CREATE TABLE ticket_dependencies (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        depends_on_ticket_id TEXT NOT NULL,
        UNIQUE(ticket_id, depends_on_ticket_id),
        CHECK (ticket_id <> depends_on_ticket_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE,
        FOREIGN KEY(project_id, depends_on_ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
    );
    \(ticketDependencyCycleInsertTrigger);
    \(ticketDependencyCycleUpdateTrigger);
    CREATE TABLE blockers (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        summary TEXT NOT NULL,
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
    );
    CREATE TABLE evidence (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        ticket_id TEXT,
        path TEXT NOT NULL,
        is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
        UNIQUE(project_id, path),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
    );
    CREATE TABLE thread_exclusions (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        thread_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        UNIQUE(project_id, thread_id)
    );
    CREATE TABLE observed_threads (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        status TEXT NOT NULL,
        last_observed_at TEXT NOT NULL,
        UNIQUE(project_id, id)
    );
    CREATE TABLE observed_goals (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        thread_id TEXT NOT NULL,
        status TEXT NOT NULL,
        text TEXT NOT NULL,
        last_observed_at TEXT NOT NULL,
        FOREIGN KEY(project_id, thread_id) REFERENCES observed_threads(project_id, id) ON DELETE CASCADE
    );
    CREATE TABLE thread_links (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        thread_id TEXT NOT NULL,
        UNIQUE(project_id, ticket_id, thread_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE,
        FOREIGN KEY(project_id, thread_id) REFERENCES observed_threads(project_id, id) ON DELETE CASCADE
    );
    CREATE TABLE review_items (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        ticket_id TEXT,
        kind TEXT NOT NULL,
        summary TEXT NOT NULL,
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
    );
    CREATE TABLE audit_events (
        id TEXT PRIMARY KEY NOT NULL,
        actor_id TEXT NOT NULL,
        thread_id TEXT,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
    );
    CREATE TABLE notification_events (
        id TEXT PRIMARY KEY NOT NULL,
        fingerprint TEXT NOT NULL UNIQUE,
        state TEXT NOT NULL,
        ticket_id TEXT REFERENCES tickets(id) ON DELETE SET NULL,
        goal_id TEXT REFERENCES observed_goals(id) ON DELETE SET NULL,
        provider_receipt TEXT,
        acknowledged_at TEXT
    );
    """

    private static let schemaVersion2 = """
    ALTER TABLE audit_events ADD COLUMN thread_attribution TEXT NOT NULL DEFAULT 'none'
        CHECK (thread_attribution IN ('none', 'asserted', 'verified'));
    ALTER TABLE blockers ADD COLUMN resolved_at TEXT;
    ALTER TABLE review_items ADD COLUMN status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'resolved', 'dismissed'));
    CREATE TABLE completion_records (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        summary TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
    );
    CREATE TABLE agent_command_requests (
        request_id TEXT PRIMARY KEY NOT NULL,
        request_body BLOB NOT NULL,
        result_data BLOB NOT NULL,
        created_at TEXT NOT NULL
    );
    """

    private static let schemaVersion3 = """
    ALTER TABLE projects ADD COLUMN first_dashboard_opened INTEGER NOT NULL DEFAULT 0
        CHECK (first_dashboard_opened IN (0, 1));
    CREATE TABLE project_bookmarks (
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        bookmark_data BLOB NOT NULL,
        is_stale INTEGER NOT NULL DEFAULT 0 CHECK (is_stale IN (0, 1)),
        PRIMARY KEY(project_id, path)
    );
    """

    private static let schemaVersion4 = """
    ALTER TABLE audit_events ADD COLUMN project_id TEXT REFERENCES projects(id) ON DELETE SET NULL;
    ALTER TABLE audit_events ADD COLUMN entity_type TEXT;
    ALTER TABLE audit_events ADD COLUMN entity_id TEXT;
    CREATE INDEX audit_events_project_entity_index
        ON audit_events(project_id, entity_type, entity_id, created_at);
    """

    private static let schemaVersion5 = """
    CREATE TABLE project_active_phases (
        project_id TEXT PRIMARY KEY NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        phase_id TEXT NOT NULL,
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
    );
    CREATE INDEX project_active_phases_phase_index ON project_active_phases(phase_id);
    INSERT INTO project_active_phases (project_id, phase_id)
    SELECT projects.id, phases.id
    FROM projects
    JOIN phases ON phases.project_id = projects.id
    WHERE (SELECT COUNT(*) FROM phases AS candidate WHERE candidate.project_id = projects.id) = 1;
    """

    private static let schemaVersion6 = """
    ALTER TABLE notification_events ADD COLUMN project_id TEXT REFERENCES projects(id) ON DELETE CASCADE;
    ALTER TABLE notification_events ADD COLUMN event_kind TEXT;
    ALTER TABLE notification_events ADD COLUMN subject_id TEXT;
    ALTER TABLE notification_events ADD COLUMN occurrence INTEGER;
    ALTER TABLE notification_events ADD COLUMN title TEXT;
    ALTER TABLE notification_events ADD COLUMN message TEXT;
    ALTER TABLE notification_events ADD COLUMN created_at TEXT;
    ALTER TABLE notification_events ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE notification_events ADD COLUMN attempt_started_at TEXT;
    ALTER TABLE notification_events ADD COLUMN completed_at TEXT;
    ALTER TABLE notification_events ADD COLUMN failure_code TEXT;
    UPDATE notification_events
    SET project_id = (SELECT project_id FROM tickets WHERE tickets.id = notification_events.ticket_id)
    WHERE project_id IS NULL AND ticket_id IS NOT NULL;
    UPDATE notification_events
    SET project_id = (SELECT project_id FROM observed_goals WHERE observed_goals.id = notification_events.goal_id)
    WHERE project_id IS NULL AND goal_id IS NOT NULL;
    CREATE TABLE notification_occurrences (
        subject_key TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        event_kind TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        generation INTEGER NOT NULL,
        is_active INTEGER NOT NULL CHECK (is_active IN (0, 1))
    );
    CREATE INDEX notification_events_project_created_index
        ON notification_events(project_id, created_at DESC);
    CREATE INDEX notification_events_state_index
        ON notification_events(state, created_at);
    """

    private static let schemaVersion7 = """
    UPDATE notification_occurrences
    SET subject_key = project_id || '|' || subject_key
    WHERE subject_key NOT LIKE project_id || '|%';
    UPDATE notification_events
    SET fingerprint = project_id || ':' || fingerprint
    WHERE project_id IS NOT NULL
      AND fingerprint NOT LIKE project_id || ':%';
    """
}
