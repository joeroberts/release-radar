import Foundation

enum StoreMigrations {
    static let currentVersion: Int64 = 26

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

        let rebuildsTicketPlacement = version > 0 && version < 19
        if rebuildsTicketPlacement {
            try connection.execute("PRAGMA foreign_keys = OFF")
        }
        defer {
            if rebuildsTicketPlacement {
                try? connection.execute("PRAGMA foreign_keys = ON")
            }
        }
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
            if version < 8 {
                try connection.executeScript(schemaVersion8)
            }
            if version < 9 {
                try connection.executeScript(schemaVersion9)
            }
            if version < 10 {
                try connection.executeScript(schemaVersion10)
            }
            if version < 11 {
                try connection.executeScript(schemaVersion11)
            }
            if version < 12 {
                try connection.executeScript(schemaVersion12)
            }
            if version < 13 {
                try connection.executeScript(schemaVersion13)
            }
            if version < 14 {
                guard let historicalEventsSQL = try connection.scalarText(
                    "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'delivery_goal_assignment_events'"
                ), normalizedSQL(historicalEventsSQL) == normalizedSQL(deliveryGoalAssignmentEventsTableSQL),
                try connection.row("PRAGMA foreign_key_check") == nil
                else {
                    throw StoreError.unavailable(
                        "Database schema version \(version) has an unrecognized assignment history table or invalid foreign keys"
                    )
                }
                try connection.executeScript(schemaVersion14)
            }
            if version < 15 {
                try connection.executeScript(schemaVersion15)
            }
            if version < 16 {
                try connection.executeScript(schemaVersion16)
            }
            if version < 17 {
                try connection.executeScript(schemaVersion17)
            }
            if version < 18 {
                try connection.executeScript(schemaVersion18)
            }
            if version > 0, version < 19 {
                try connection.executeScript(schemaVersion19)
            }
            if version < 20 {
                try connection.executeScript(schemaVersion20)
            }
            if version < 21 {
                try connection.executeScript(schemaVersion21)
            }
            if version < 22 {
                try connection.executeScript(schemaVersion22)
            }
            if version < 23 {
                try connection.executeScript(schemaVersion23)
            }
            if version < 24 {
                try connection.executeScript(schemaVersion24)
            }
            if version < 25 {
                try connection.executeScript(schemaVersion25)
            }
            if version < 26 {
                try connection.executeScript(schemaVersion26)
            }
            guard try connection.row("PRAGMA foreign_key_check") == nil else {
                throw StoreError.unavailable(
                    "Database schema version \(version) has invalid references after the placement migration"
                )
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
            throughVersion: 7,
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

    static func recognizesDocumentationPreflightSchema(_ connection: SQLiteConnection, version: Int64) throws -> Bool {
        guard (10...currentVersion).contains(version) else { return false }
        return try hasRequiredSchema(connection, throughVersion: version)
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
        if version >= 9 {
            guard let alertRulesSQL = try connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'alert_rules'"
            ), normalizedSQL(alertRulesSQL) == normalizedSQL(alertRulesTableSQL)
            else { return false }
        }
        if version >= 10 {
            guard let lifecycleSQL = try connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'codex_plugin_lifecycle'"
            ), normalizedSQL(lifecycleSQL) == normalizedSQL(codexPluginLifecycleTableSQL),
            try connection.scalarInt(
                """
                SELECT COUNT(*) FROM codex_plugin_lifecycle
                WHERE plugin_id = 'release-radar'
                  AND intent IN ('neverInstalled','managedInstalled','removed','attentionRequired')
                  AND ((managed_version IS NULL) = (managed_digest IS NULL))
                  AND ((managed_version IS NULL) = (verified_at IS NULL))
                  AND (
                    managed_version IS NULL OR (
                      typeof(managed_version) = 'text'
                      AND typeof(managed_digest) = 'text'
                      AND typeof(verified_at) = 'text'
                    )
                  )
                """
            ) == 1,
            try connection.scalarInt("SELECT COUNT(*) FROM codex_plugin_lifecycle") == 1
            else { return false }
        }
        if version >= 11 {
            guard try hasExpectedLegacyContinuationColumn(connection, throughVersion: version) else { return false }
            for table in planningTableSQL {
                let expectedSQL = version >= 22 && table.name == "delivery_goal_assignment_events"
                    ? deliveryGoalAssignmentEventsVersionTwentyTwoTableSQL
                    : version >= 14 && table.name == "delivery_goal_assignment_events"
                    ? deliveryGoalAssignmentEventsVersionFourteenTableSQL : table.sql
                guard let actualSQL = try connection.scalarText(
                    "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = ?",
                    bindings: [.text(table.name)]
                ), normalizedSQL(actualSQL) == normalizedSQL(expectedSQL)
                else { return false }
            }
        }
        if version >= 12 {
            for table in ticketTaskTableSQL {
                guard let actualSQL = try connection.scalarText(
                    "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = ?",
                    bindings: [.text(table.name)]
                ), normalizedSQL(actualSQL) == normalizedSQL(table.sql)
                else { return false }
            }
        }
        if version >= 13 {
            for table in [("evidence", evidenceTableSQL), ("project_documentation_bindings", documentationBindingsTableSQL)] {
                guard let actualSQL = try connection.scalarText(
                    "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = ?",
                    bindings: [.text(table.0)]
                ), normalizedSQL(actualSQL) == normalizedSQL(table.1) else { return false }
            }
        }
        if version >= 15 {
            guard let registrationSQL = try connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'project_registrations'"
            ), normalizedSQL(registrationSQL) == normalizedSQL(projectRegistrationsTableSQL)
            else { return false }
        }
        if version >= 18 {
            guard let recoverySQL = try connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'application_recovery_state'"
            ), normalizedSQL(recoverySQL) == normalizedSQL(applicationRecoveryStateTableSQL),
            try connection.scalarInt("SELECT COUNT(*) FROM application_recovery_state") == 1,
            try connection.scalarInt(
                """
                SELECT COUNT(*) FROM application_recovery_state
                WHERE singleton_id = 1
                  AND typeof(incarnation_id) = 'text'
                  AND length(incarnation_id) = 36
                  AND requires_scoped_commands IN (0, 1)
                  AND ((last_operation_kind IS NULL) = (last_operation_id IS NULL))
                  AND ((last_operation_kind IS NULL) = (completed_at IS NULL))
                """
            ) == 1 else { return false }
        }
        return try connection.row("PRAGMA foreign_key_check") == nil
    }

    private static func hasExpectedTriggerSemantics(
        _ connection: SQLiteConnection,
        throughVersion version: Int64
    ) throws -> Bool {
        for trigger in criticalTriggers where trigger.version <= version {
            let expectedSQL: String
            if version >= 17 {
                switch trigger.name {
                case "ticket_task_plans_reject_delete": expectedSQL = ticketTaskPlansRejectDeleteVersionSeventeenTrigger
                case "ticket_tasks_reject_delete": expectedSQL = ticketTasksRejectDeleteVersionSeventeenTrigger
                case "ticket_task_plans_reject_ticket_delete": expectedSQL = ticketTaskPlansRejectTicketDeleteVersionSeventeenTrigger
                case "ticket_task_plans_reject_project_delete": expectedSQL = ticketTaskPlansRejectProjectDeleteVersionSeventeenTrigger
                default: expectedSQL = trigger.sql
                }
            } else {
                expectedSQL = trigger.sql
            }
            guard let sql = try connection.scalarText(
                "SELECT sql FROM sqlite_schema WHERE type = 'trigger' AND name = ?",
                bindings: [.text(trigger.name)]
            ) else { return false }
            guard normalizedSQL(sql) == normalizedSQL(expectedSQL) else { return false }
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
                "SELECT COUNT(*) FROM pragma_index_list('\(index.table)') WHERE name = ? AND \"unique\" = ? AND partial = 0",
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
                ) == (column.descending ? 1 : 0),
                try connection.scalarText(
                    "SELECT coll FROM pragma_index_xinfo('\(index.name)') WHERE key = 1 AND seqno = ?",
                    bindings: [.integer(Int64(offset))]
                ) == "BINARY"
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
        var expectedForeignKeys = requiredForeignKeys
        if version >= 14 {
            expectedForeignKeys.removeAll {
                $0.table == "delivery_goal_assignment_events" && $0.targetTable == "tickets"
            }
            expectedForeignKeys.append(
                (14, "delivery_goal_assignment_events", "project_id,ticket_id", "tickets", "project_id,id", "NO ACTION")
            )
        }
        for foreignKey in expectedForeignKeys where foreignKey.version <= version {
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

    private static func hasExpectedLegacyContinuationColumn(
        _ connection: SQLiteConnection,
        throughVersion version: Int64
    ) throws -> Bool {
        guard try connection.scalarText(
            "SELECT type FROM pragma_table_info('tickets') WHERE name = 'plan_legacy_continuation'"
        ) == "INTEGER",
        try connection.scalarInt(
            "SELECT \"notnull\" FROM pragma_table_info('tickets') WHERE name = 'plan_legacy_continuation'"
        ) == 1,
        try connection.scalarText(
            "SELECT dflt_value FROM pragma_table_info('tickets') WHERE name = 'plan_legacy_continuation'"
        ) == "0",
        let ticketsSQL = try connection.scalarText(
            "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'tickets'"
        ),
        normalizedSQL(ticketsSQL) == normalizedSQL(
            version >= 19 ? ticketsVersionNineteenTableSQL : ticketsVersionElevenTableSQL
        )
        else { return false }
        return true
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
        (15, "project_registrations", [
            "project_id", "registration_id", "request_generation", "setup_state",
        ]),
        (13, "project_documentation_bindings", [
            "project_id", "root_id", "repository_id", "accepted_catalog_version",
            "accepted_catalog_digest", "accepted_catalog",
        ]),
        (2, "completion_records", ["id", "project_id", "ticket_id", "summary", "created_at"]),
        (2, "agent_command_requests", ["request_id", "request_body", "result_data", "created_at"]),
        (3, "project_bookmarks", ["project_id", "path", "bookmark_data", "is_stale"]),
        (5, "project_active_phases", ["project_id", "phase_id"]),
        (6, "notification_occurrences", [
            "subject_key", "project_id", "event_kind", "subject_id", "generation", "is_active",
        ]),
        (8, "ticket_goal_links", ["id", "project_id", "ticket_id", "thread_id", "goal_id"]),
        (9, "alert_rules", ["kind", "is_enabled"]),
        (10, "codex_plugin_lifecycle", [
            "plugin_id", "intent", "managed_version", "managed_digest", "verified_at",
        ]),
        (11, "phase_plans", [
            "project_id", "phase_id", "state", "revision", "ready_revision",
            "created_at", "updated_at", "finalized_at",
        ]),
        (11, "delivery_goals", [
            "project_id", "phase_id", "id", "title", "outcome", "lifecycle", "sort_order",
            "created_at", "updated_at", "activated_at", "accepted_at",
        ]),
        (11, "delivery_goal_done_criteria", [
            "project_id", "phase_id", "goal_id", "sort_order", "criterion",
        ]),
        (11, "delivery_goal_ticket_assignments", [
            "project_id", "phase_id", "goal_id", "ticket_id",
        ]),
        (11, "delivery_goal_assignment_events", [
            "audit_event_id", "project_id", "phase_id", "ticket_id", "previous_goal_id",
            "current_goal_id", "revision", "action",
        ]),
        (12, "ticket_task_plans", [
            "project_id", "ticket_id", "revision", "created_at", "updated_at",
        ]),
        (12, "ticket_tasks", [
            "project_id", "ticket_id", "id", "label", "title", "sort_order", "completion",
            "lifecycle", "created_at", "updated_at", "completed_at", "superseded_at",
        ]),
        (17, "removed_projects", [
            "removal_id", "historical_project_id", "project_name", "original_lifecycle",
            "registration_id", "request_generation", "removed_at", "phase_count",
            "ticket_count", "evidence_count", "history_count",
        ]),
        (17, "retained_project_activity_events", [
            "removal_id", "source", "source_id", "title", "detail", "occurred_at",
            "observed_at", "recorded_at", "ticket_id", "phase_id", "delivery_goal_id",
            "originating_thread_id", "delivery_lane", "runtime_state", "notification_state",
            "notification_status_text",
        ]),
        (17, "retained_delivery_goal_assignment_events", [
            "removal_id", "audit_event_id", "project_id", "phase_id", "ticket_id",
            "previous_goal_id", "current_goal_id", "revision", "action",
        ]),
        (17, "project_removal_authorizations", [
            "project_id", "registration_id", "removal_id",
        ]),
        (18, "application_recovery_state", [
            "singleton_id", "incarnation_id", "requires_scoped_commands",
            "last_operation_kind", "last_operation_id", "completed_at",
        ]),
        (20, "ticket_reference_link_sets", [
            "project_id", "ticket_id", "revision", "created_at", "updated_at",
        ]),
        (20, "ticket_reference_links", [
            "project_id", "ticket_id", "id", "kind", "repository_id", "artifact_id",
            "current_version", "relationship", "retired_version", "retired_at",
            "retirement_reason", "created_at", "updated_at",
        ]),
        (20, "ticket_reference_versions", [
            "project_id", "ticket_id", "link_id", "version", "content_digest",
            "source_local_id", "locator", "catalog_version", "catalog_digest",
            "observed_path", "observed_lifecycle", "observed_authority",
            "created_at",
        ]),
        (20, "retained_ticket_reference_links", [
            "removal_id", "historical_project_id", "ticket_id", "link_id", "kind",
            "repository_id", "artifact_id", "current_version", "relationship",
            "retired_version", "retired_at", "retirement_reason", "link_set_revision",
            "created_at", "updated_at",
        ]),
        (20, "retained_ticket_reference_versions", [
            "removal_id", "historical_project_id", "ticket_id", "link_id", "version",
            "content_digest", "source_local_id", "locator", "catalog_version",
            "catalog_digest", "observed_path", "observed_lifecycle",
            "observed_authority", "created_at",
        ]),
        (21, "plan_change_proposals", [
            "project_id", "id", "current_version", "created_at", "updated_at",
        ]),
        (21, "plan_change_proposal_versions", [
            "project_id", "proposal_id", "version", "registration_id",
            "request_generation", "baseline_digest", "baseline_data",
            "operations_data", "diff_data", "source_impacts_data", "rationale", "created_at",
        ]),
        (21, "plan_change_proposal_decisions", [
            "project_id", "proposal_id", "version", "id", "disposition",
            "baseline_digest", "registration_id", "request_generation", "actor_id",
            "created_at",
        ]),
        (21, "plan_change_proposal_applications", [
            "project_id", "proposal_id", "version", "id", "decision_id",
            "audit_event_id", "applied_at",
        ]),
        (21, "retained_plan_change_proposals", [
            "removal_id", "historical_project_id", "proposal_id", "current_version",
            "created_at", "updated_at",
        ]),
        (21, "retained_plan_change_proposal_versions", [
            "removal_id", "historical_project_id", "proposal_id", "version",
            "registration_id", "request_generation", "baseline_digest", "baseline_data",
            "operations_data", "diff_data", "source_impacts_data", "rationale", "created_at",
        ]),
        (21, "retained_plan_change_proposal_decisions", [
            "removal_id", "historical_project_id", "proposal_id", "version", "id",
            "disposition", "baseline_digest", "registration_id", "request_generation",
            "actor_id", "created_at",
        ]),
        (21, "retained_plan_change_proposal_applications", [
            "removal_id", "historical_project_id", "proposal_id", "version", "id",
            "decision_id", "audit_event_id", "applied_at",
        ]),
        (22, "ticket_retirements", [
            "project_id", "ticket_id", "disposition", "reason", "last_phase_id",
            "last_lane", "audit_event_id", "retired_at",
        ]),
        (22, "ticket_successor_links", [
            "project_id", "original_ticket_id", "successor_ticket_id", "relation",
            "sort_order", "audit_event_id", "created_at",
        ]),
        (22, "delivery_goal_obligations", [
            "project_id", "phase_id", "goal_id", "ticket_id", "scope",
            "assessment", "created_at",
        ]),
        (22, "delivery_goal_obligation_lineage", [
            "project_id", "source_phase_id", "source_goal_id", "source_ticket_id",
            "descendant_phase_id", "descendant_goal_id", "descendant_ticket_id",
            "reason", "audit_event_id", "created_at",
        ]),
        (22, "delivery_goal_obligation_drops", [
            "project_id", "phase_id", "goal_id", "ticket_id", "reason",
            "audit_event_id", "created_at",
        ]),
        (22, "retained_ticket_retirements", [
            "removal_id", "historical_project_id", "ticket_id", "outcome", "disposition", "reason",
            "last_phase_id", "last_lane", "audit_event_id", "retired_at",
        ]),
        (22, "retained_ticket_successor_links", [
            "removal_id", "historical_project_id", "original_ticket_id", "successor_ticket_id",
            "relation", "sort_order", "audit_event_id", "created_at",
        ]),
        (22, "retained_delivery_goal_obligations", [
            "removal_id", "historical_project_id", "phase_id", "goal_id", "ticket_id",
            "scope", "assessment", "created_at",
        ]),
        (22, "retained_delivery_goal_obligation_lineage", [
            "removal_id", "historical_project_id", "source_phase_id", "source_goal_id",
            "source_ticket_id", "descendant_phase_id", "descendant_goal_id",
            "descendant_ticket_id", "reason", "audit_event_id", "created_at",
        ]),
        (22, "retained_delivery_goal_obligation_drops", [
            "removal_id", "historical_project_id", "phase_id", "goal_id", "ticket_id",
            "reason", "audit_event_id", "created_at",
        ]),
        (23, "phase_lifecycles", [
            "project_id", "phase_id", "lifecycle", "revision",
            "completion_baseline_digest", "created_at", "updated_at", "completed_at",
        ]),
        (23, "phase_lifecycle_events", [
            "project_id", "phase_id", "revision", "previous_lifecycle", "current_lifecycle",
            "action", "reason", "audit_event_id", "registration_id", "request_generation",
            "planning_baseline_digest", "created_at",
        ]),
        (23, "retained_phase_lifecycles", [
            "removal_id", "historical_project_id", "phase_id", "phase_name", "lifecycle",
            "revision", "completion_baseline_digest", "created_at", "updated_at", "completed_at",
        ]),
        (23, "retained_phase_lifecycle_events", [
            "removal_id", "historical_project_id", "phase_id", "revision",
            "previous_lifecycle", "current_lifecycle", "action", "reason", "audit_event_id",
            "registration_id", "request_generation", "planning_baseline_digest", "created_at",
        ]),
        (25, "ticket_delivery_evidence_sets", [
            "project_id", "ticket_id", "revision", "current_target_version", "created_at", "updated_at",
        ]),
        (25, "ticket_delivery_evidence_targets", [
            "project_id", "ticket_id", "version", "repository_id", "root_id", "revision_data",
            "expectations_data", "registration_id", "request_generation", "recorded_at",
        ]),
        (25, "ticket_delivery_evidence_observations", [
            "project_id", "ticket_id", "id", "target_version", "fact_data", "source_data",
            "source_availability", "outcome", "observed_at", "recorded_at",
            "attachment_evidence_id", "supersedes_observation_id", "append_revision",
        ]),
        (25, "retained_ticket_delivery_evidence_targets", [
            "removal_id", "historical_project_id", "ticket_id", "version", "repository_id",
            "root_id", "revision_data", "expectations_data", "registration_id",
            "request_generation", "recorded_at", "evidence_revision", "current_target_version",
        ]),
        (25, "retained_ticket_delivery_evidence_observations", [
            "removal_id", "historical_project_id", "ticket_id", "id", "target_version",
            "fact_data", "source_data", "source_availability", "outcome", "observed_at",
            "recorded_at", "attachment_evidence_id", "supersedes_observation_id", "append_revision",
        ]),
        (26, "workspace_search_preferences", [
            "singleton_id", "payload_version", "payload_data", "updated_at",
        ]),
        (26, "workspace_saved_queries", [
            "id", "name", "payload_version", "payload_data", "created_at", "updated_at",
        ]),
    ]

    private static let addedColumns: [(version: Int64, table: String, name: String)] = [
        (13, "evidence", "artifact_id"),
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
        (11, "tickets", "plan_legacy_continuation"),
        (16, "projects", "lifecycle"),
        (17, "audit_events", "historical_project_id"),
        (17, "audit_events", "historical_registration_id"),
        (24, "audit_events", "event_facts_recorded"),
        (24, "audit_events", "event_provenance"),
        (24, "audit_events", "event_occurred_at"),
        (24, "audit_events", "event_recorded_at"),
        (24, "audit_events", "event_project_name"),
        (24, "audit_events", "event_registration_id"),
        (24, "audit_events", "event_request_generation"),
        (24, "audit_events", "event_ticket_id"),
        (24, "audit_events", "event_phase_id"),
        (24, "audit_events", "event_phase_name"),
        (24, "audit_events", "event_ticket_outcome"),
        (24, "audit_events", "event_previous_lane"),
        (24, "audit_events", "event_current_lane"),
        (24, "audit_events", "event_previous_phase_id"),
        (24, "audit_events", "event_current_phase_id"),
        (17, "agent_command_requests", "registration_project_id"),
        (17, "agent_command_requests", "registration_id"),
        (17, "agent_command_requests", "request_generation"),
    ]

    private static let criticalObjects: [(version: Int64, type: String, name: String)] = [
        (13, "index", "project_roots_project_identity_unique"),
        (13, "index", "project_documentation_bindings_repository_unique"),
        (13, "index", "project_documentation_bindings_root_unique"),
        (1, "trigger", "reject_phase_dependency_cycle_insert"),
        (1, "trigger", "reject_phase_dependency_cycle_update"),
        (1, "trigger", "reject_ticket_dependency_cycle_insert"),
        (1, "trigger", "reject_ticket_dependency_cycle_update"),
        (4, "index", "audit_events_project_entity_index"),
        (5, "index", "project_active_phases_phase_index"),
        (6, "index", "notification_events_project_created_index"),
        (6, "index", "notification_events_state_index"),
        (11, "index", "tickets_project_phase_identity_unique"),
        (11, "index", "delivery_goals_project_phase_identity_unique"),
        (11, "index", "delivery_goals_phase_sort_index"),
        (11, "index", "delivery_goal_ticket_assignments_goal_index"),
        (11, "index", "delivery_goal_assignment_events_ticket_revision_unique"),
        (11, "trigger", "phase_plans_after_phase_insert"),
        (11, "trigger", "delivery_goals_reject_ownership_change"),
        (11, "trigger", "tickets_reject_legacy_continuation_insert"),
        (11, "trigger", "tickets_reject_legacy_continuation_regrant"),
        (12, "index", "ticket_task_plans_ticket_unique"),
        (12, "index", "ticket_tasks_label_unique"),
        (12, "index", "ticket_tasks_active_order_index"),
        (12, "trigger", "ticket_tasks_reject_identity_update"),
        (12, "trigger", "ticket_tasks_reject_label_update"),
        (12, "trigger", "ticket_task_plans_reject_delete"),
        (12, "trigger", "ticket_tasks_reject_delete"),
        (12, "trigger", "ticket_task_plans_reject_ticket_delete"),
        (12, "trigger", "ticket_task_plans_reject_project_delete"),
        (17, "index", "removed_projects_historical_registration_unique"),
        (17, "index", "removed_projects_historical_project_index"),
        (17, "index", "audit_events_historical_project_index"),
        (20, "index", "ticket_reference_links_source_index"),
        (20, "index", "ticket_reference_versions_source_index"),
        (20, "index", "retained_ticket_reference_links_source_index"),
        (20, "trigger", "ticket_reference_versions_reject_update"),
        (20, "trigger", "ticket_reference_versions_reject_delete"),
        (20, "trigger", "ticket_reference_links_reject_identity_update"),
        (20, "trigger", "ticket_reference_links_reject_delete"),
        (20, "trigger", "ticket_reference_link_sets_reject_delete"),
        (21, "trigger", "plan_change_proposal_versions_reject_update"),
        (21, "trigger", "plan_change_proposal_versions_reject_delete"),
        (21, "trigger", "plan_change_proposal_decisions_reject_update"),
        (21, "trigger", "plan_change_proposal_decisions_reject_delete"),
        (21, "trigger", "plan_change_proposal_applications_reject_update"),
        (21, "trigger", "plan_change_proposal_applications_reject_delete"),
        (21, "trigger", "retained_plan_change_proposals_reject_update"),
        (21, "trigger", "retained_plan_change_proposals_reject_delete"),
        (21, "trigger", "retained_plan_change_proposal_versions_reject_update"),
        (21, "trigger", "retained_plan_change_proposal_versions_reject_delete"),
        (21, "trigger", "retained_plan_change_proposal_decisions_reject_update"),
        (21, "trigger", "retained_plan_change_proposal_decisions_reject_delete"),
        (21, "trigger", "retained_plan_change_proposal_applications_reject_update"),
        (21, "trigger", "retained_plan_change_proposal_applications_reject_delete"),
        (22, "trigger", "retained_ticket_retirements_reject_update"),
        (22, "trigger", "retained_ticket_retirements_reject_delete"),
        (22, "trigger", "retained_ticket_successor_links_reject_update"),
        (22, "trigger", "retained_ticket_successor_links_reject_delete"),
        (22, "trigger", "retained_delivery_goal_obligations_reject_update"),
        (22, "trigger", "retained_delivery_goal_obligations_reject_delete"),
        (22, "trigger", "retained_delivery_goal_obligation_lineage_reject_update"),
        (22, "trigger", "retained_delivery_goal_obligation_lineage_reject_delete"),
        (22, "trigger", "retained_delivery_goal_obligation_drops_reject_update"),
        (22, "trigger", "retained_delivery_goal_obligation_drops_reject_delete"),
        (23, "trigger", "phase_lifecycles_after_phase_insert"),
        (23, "trigger", "phase_lifecycle_events_reject_update"),
        (23, "trigger", "phase_lifecycle_events_reject_delete"),
        (23, "trigger", "retained_phase_lifecycles_reject_update"),
        (23, "trigger", "retained_phase_lifecycles_reject_delete"),
        (23, "trigger", "retained_phase_lifecycle_events_reject_update"),
        (23, "trigger", "retained_phase_lifecycle_events_reject_delete"),
        (25, "trigger", "ticket_delivery_evidence_sets_reject_delete"),
        (25, "trigger", "ticket_delivery_evidence_targets_reject_update"),
        (25, "trigger", "ticket_delivery_evidence_targets_reject_delete"),
        (25, "trigger", "ticket_delivery_evidence_observations_reject_update"),
        (25, "trigger", "ticket_delivery_evidence_observations_reject_delete"),
        (25, "trigger", "retained_ticket_delivery_evidence_targets_reject_update"),
        (25, "trigger", "retained_ticket_delivery_evidence_targets_reject_delete"),
        (25, "trigger", "retained_ticket_delivery_evidence_observations_reject_update"),
        (25, "trigger", "retained_ticket_delivery_evidence_observations_reject_delete"),
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

    private static let phasePlanAfterPhaseInsertTrigger = """
    CREATE TRIGGER phase_plans_after_phase_insert
    AFTER INSERT ON phases
    BEGIN
        INSERT INTO phase_plans (
            project_id, phase_id, state, revision, ready_revision,
            created_at, updated_at, finalized_at
        ) VALUES (
            NEW.project_id, NEW.id, 'legacy_unassessed', 0, NULL,
            strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
            strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
            NULL
        );
    END
    """

    private static let rejectDeliveryGoalOwnershipChangeTrigger = """
    CREATE TRIGGER delivery_goals_reject_ownership_change
    BEFORE UPDATE OF project_id, phase_id ON delivery_goals
    WHEN OLD.project_id <> NEW.project_id OR OLD.phase_id <> NEW.phase_id
    BEGIN
        SELECT RAISE(ABORT, 'delivery goal ownership is immutable');
    END
    """

    private static let rejectLegacyContinuationInsertTrigger = """
    CREATE TRIGGER tickets_reject_legacy_continuation_insert
    BEFORE INSERT ON tickets
    WHEN NEW.plan_legacy_continuation = 1
    BEGIN
        SELECT RAISE(ABORT, 'legacy continuation is migration-only');
    END
    """

    private static let rejectLegacyContinuationRegrantTrigger = """
    CREATE TRIGGER tickets_reject_legacy_continuation_regrant
    BEFORE UPDATE OF plan_legacy_continuation ON tickets
    WHEN OLD.plan_legacy_continuation = 0 AND NEW.plan_legacy_continuation = 1
    BEGIN
        SELECT RAISE(ABORT, 'legacy continuation cannot be regranted');
    END
    """

    private static let ticketTasksRejectIdentityUpdateTrigger = """
    CREATE TRIGGER ticket_tasks_reject_identity_update
    BEFORE UPDATE OF project_id, ticket_id, id ON ticket_tasks
    WHEN OLD.project_id <> NEW.project_id
       OR OLD.ticket_id <> NEW.ticket_id
       OR OLD.id <> NEW.id
    BEGIN
        SELECT RAISE(ABORT, 'ticket task identity is immutable');
    END
    """

    private static let ticketTasksRejectLabelUpdateTrigger = """
    CREATE TRIGGER ticket_tasks_reject_label_update
    BEFORE UPDATE OF label ON ticket_tasks
    WHEN OLD.label <> NEW.label
    BEGIN
        SELECT RAISE(ABORT, 'ticket task label is immutable');
    END
    """

    private static let ticketTaskPlansRejectDeleteTrigger = """
    CREATE TRIGGER ticket_task_plans_reject_delete
    BEFORE DELETE ON ticket_task_plans
    BEGIN
        SELECT RAISE(ABORT, 'ticket task plan history cannot be deleted');
    END
    """

    private static let ticketTasksRejectDeleteTrigger = """
    CREATE TRIGGER ticket_tasks_reject_delete
    BEFORE DELETE ON ticket_tasks
    BEGIN
        SELECT RAISE(ABORT, 'ticket task history cannot be deleted');
    END
    """

    private static let ticketTaskPlansRejectTicketDeleteTrigger = """
    CREATE TRIGGER ticket_task_plans_reject_ticket_delete
    BEFORE DELETE ON tickets
    WHEN EXISTS (
        SELECT 1
        FROM ticket_task_plans
        WHERE project_id = OLD.project_id
          AND ticket_id = OLD.id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket owns task history');
    END
    """

    private static let ticketTaskPlansRejectProjectDeleteTrigger = """
    CREATE TRIGGER ticket_task_plans_reject_project_delete
    BEFORE DELETE ON projects
    WHEN EXISTS (
        SELECT 1
        FROM ticket_task_plans
        WHERE project_id = OLD.id
    )
    BEGIN
        SELECT RAISE(ABORT, 'project owns task history');
    END
    """

    private static let ticketTaskPlansRejectDeleteVersionSeventeenTrigger = """
    CREATE TRIGGER ticket_task_plans_reject_delete
    BEFORE DELETE ON ticket_task_plans
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket task plan history cannot be deleted');
    END
    """

    private static let ticketTasksRejectDeleteVersionSeventeenTrigger = """
    CREATE TRIGGER ticket_tasks_reject_delete
    BEFORE DELETE ON ticket_tasks
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket task history cannot be deleted');
    END
    """

    private static let ticketTaskPlansRejectTicketDeleteVersionSeventeenTrigger = """
    CREATE TRIGGER ticket_task_plans_reject_ticket_delete
    BEFORE DELETE ON tickets
    WHEN EXISTS (
        SELECT 1
        FROM ticket_task_plans
        WHERE project_id = OLD.project_id
          AND ticket_id = OLD.id
    )
      AND NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket owns task history');
    END
    """

    private static let ticketTaskPlansRejectProjectDeleteVersionSeventeenTrigger = """
    CREATE TRIGGER ticket_task_plans_reject_project_delete
    BEFORE DELETE ON projects
    WHEN EXISTS (
        SELECT 1
        FROM ticket_task_plans
        WHERE project_id = OLD.id
    )
      AND NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'project owns task history');
    END
    """

    private static let ticketReferenceVersionsRejectUpdateTrigger = """
    CREATE TRIGGER ticket_reference_versions_reject_update
    BEFORE UPDATE ON ticket_reference_versions
    BEGIN
        SELECT RAISE(ABORT, 'ticket reference versions are immutable');
    END
    """

    private static let ticketReferenceVersionsRejectDeleteTrigger = """
    CREATE TRIGGER ticket_reference_versions_reject_delete
    BEFORE DELETE ON ticket_reference_versions
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket reference versions cannot be deleted');
    END
    """

    private static let ticketReferenceLinksRejectIdentityUpdateTrigger = """
    CREATE TRIGGER ticket_reference_links_reject_identity_update
    BEFORE UPDATE OF project_id, ticket_id, id, kind, repository_id, artifact_id, created_at
        ON ticket_reference_links
    WHEN OLD.project_id <> NEW.project_id
      OR OLD.ticket_id <> NEW.ticket_id
      OR OLD.id <> NEW.id
      OR OLD.kind <> NEW.kind
      OR OLD.repository_id <> NEW.repository_id
      OR OLD.artifact_id <> NEW.artifact_id
      OR OLD.created_at <> NEW.created_at
    BEGIN
        SELECT RAISE(ABORT, 'ticket reference identity is immutable');
    END
    """

    private static let ticketReferenceLinksRejectDeleteTrigger = """
    CREATE TRIGGER ticket_reference_links_reject_delete
    BEFORE DELETE ON ticket_reference_links
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket reference links cannot be deleted');
    END
    """

    private static let ticketReferenceLinkSetsRejectDeleteTrigger = """
    CREATE TRIGGER ticket_reference_link_sets_reject_delete
    BEFORE DELETE ON ticket_reference_link_sets
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'ticket reference link sets cannot be deleted');
    END
    """

    private static func deliveryEvidenceImmutableTrigger(table: String, action: String) -> String {
        let name = "\(table)_reject_\(action)"
        let event = action.uppercased()
        let removalCondition = action == "delete" ? """
        WHEN NOT EXISTS (
            SELECT 1 FROM project_removal_authorizations
            JOIN project_registrations USING (project_id)
            WHERE project_removal_authorizations.project_id = OLD.project_id
              AND project_removal_authorizations.registration_id = project_registrations.registration_id
        )
        """ : ""
        return """
        CREATE TRIGGER \(name)
        BEFORE \(event) ON \(table)
        \(removalCondition)BEGIN
            SELECT RAISE(ABORT, 'delivery evidence records are immutable');
        END
        """
    }

    private static let deliveryEvidenceSetsRejectDeleteTrigger = """
    CREATE TRIGGER ticket_delivery_evidence_sets_reject_delete
    BEFORE DELETE ON ticket_delivery_evidence_sets
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'delivery evidence sets cannot be deleted');
    END
    """

    private static let planChangeProposalVersionsRejectUpdateTrigger = """
    CREATE TRIGGER plan_change_proposal_versions_reject_update
    BEFORE UPDATE ON plan_change_proposal_versions
    BEGIN
        SELECT RAISE(ABORT, 'plan change proposal versions are immutable');
    END
    """

    private static let planChangeProposalVersionsRejectDeleteTrigger = """
    CREATE TRIGGER plan_change_proposal_versions_reject_delete
    BEFORE DELETE ON plan_change_proposal_versions
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'plan change proposal versions cannot be deleted');
    END
    """

    private static let planChangeProposalDecisionsRejectUpdateTrigger = """
    CREATE TRIGGER plan_change_proposal_decisions_reject_update
    BEFORE UPDATE ON plan_change_proposal_decisions
    BEGIN
        SELECT RAISE(ABORT, 'plan change proposal decisions are immutable');
    END
    """

    private static let planChangeProposalDecisionsRejectDeleteTrigger = """
    CREATE TRIGGER plan_change_proposal_decisions_reject_delete
    BEFORE DELETE ON plan_change_proposal_decisions
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'plan change proposal decisions cannot be deleted');
    END
    """

    private static let planChangeProposalApplicationsRejectUpdateTrigger = """
    CREATE TRIGGER plan_change_proposal_applications_reject_update
    BEFORE UPDATE ON plan_change_proposal_applications
    BEGIN
        SELECT RAISE(ABORT, 'plan change proposal applications are immutable');
    END
    """

    private static let planChangeProposalApplicationsRejectDeleteTrigger = """
    CREATE TRIGGER plan_change_proposal_applications_reject_delete
    BEFORE DELETE ON plan_change_proposal_applications
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'plan change proposal applications cannot be deleted');
    END
    """

    private static let phaseLifecyclesAfterPhaseInsertTrigger = """
    CREATE TRIGGER phase_lifecycles_after_phase_insert
    AFTER INSERT ON phases
    BEGIN
        INSERT INTO phase_lifecycles (
            project_id, phase_id, lifecycle, revision, completion_baseline_digest,
            created_at, updated_at, completed_at
        ) VALUES (
            NEW.project_id, NEW.id, 'unassessed', 0, NULL,
            strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
            strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
            NULL
        );
    END
    """

    private static let phaseLifecycleEventsRejectUpdateTrigger = """
    CREATE TRIGGER phase_lifecycle_events_reject_update
    BEFORE UPDATE ON phase_lifecycle_events
    BEGIN
        SELECT RAISE(ABORT, 'phase lifecycle history is immutable');
    END
    """

    private static let phaseLifecycleEventsRejectDeleteTrigger = """
    CREATE TRIGGER phase_lifecycle_events_reject_delete
    BEFORE DELETE ON phase_lifecycle_events
    WHEN NOT EXISTS (
        SELECT 1 FROM project_removal_authorizations
        JOIN project_registrations USING (project_id)
        WHERE project_removal_authorizations.project_id = OLD.project_id
          AND project_removal_authorizations.registration_id = project_registrations.registration_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'phase lifecycle history cannot be deleted');
    END
    """

    private static func immutableRetainedTrigger(
        table: String,
        action: String
    ) -> String {
        """
        CREATE TRIGGER \(table)_reject_\(action)
        BEFORE \(action.uppercased()) ON \(table)
        BEGIN
            SELECT RAISE(ABORT, 'retained plan change proposal history is immutable');
        END
        """
    }

    private static let criticalTriggers: [(version: Int64, name: String, sql: String)] = [
        (1, "reject_phase_dependency_cycle_insert", phaseDependencyCycleInsertTrigger),
        (1, "reject_phase_dependency_cycle_update", phaseDependencyCycleUpdateTrigger),
        (1, "reject_ticket_dependency_cycle_insert", ticketDependencyCycleInsertTrigger),
        (1, "reject_ticket_dependency_cycle_update", ticketDependencyCycleUpdateTrigger),
        (11, "phase_plans_after_phase_insert", phasePlanAfterPhaseInsertTrigger),
        (11, "delivery_goals_reject_ownership_change", rejectDeliveryGoalOwnershipChangeTrigger),
        (11, "tickets_reject_legacy_continuation_insert", rejectLegacyContinuationInsertTrigger),
        (11, "tickets_reject_legacy_continuation_regrant", rejectLegacyContinuationRegrantTrigger),
        (12, "ticket_tasks_reject_identity_update", ticketTasksRejectIdentityUpdateTrigger),
        (12, "ticket_tasks_reject_label_update", ticketTasksRejectLabelUpdateTrigger),
        (12, "ticket_task_plans_reject_delete", ticketTaskPlansRejectDeleteTrigger),
        (12, "ticket_tasks_reject_delete", ticketTasksRejectDeleteTrigger),
        (12, "ticket_task_plans_reject_ticket_delete", ticketTaskPlansRejectTicketDeleteTrigger),
        (12, "ticket_task_plans_reject_project_delete", ticketTaskPlansRejectProjectDeleteTrigger),
        (20, "ticket_reference_versions_reject_update", ticketReferenceVersionsRejectUpdateTrigger),
        (20, "ticket_reference_versions_reject_delete", ticketReferenceVersionsRejectDeleteTrigger),
        (20, "ticket_reference_links_reject_identity_update", ticketReferenceLinksRejectIdentityUpdateTrigger),
        (20, "ticket_reference_links_reject_delete", ticketReferenceLinksRejectDeleteTrigger),
        (20, "ticket_reference_link_sets_reject_delete", ticketReferenceLinkSetsRejectDeleteTrigger),
        (21, "plan_change_proposal_versions_reject_update", planChangeProposalVersionsRejectUpdateTrigger),
        (21, "plan_change_proposal_versions_reject_delete", planChangeProposalVersionsRejectDeleteTrigger),
        (21, "plan_change_proposal_decisions_reject_update", planChangeProposalDecisionsRejectUpdateTrigger),
        (21, "plan_change_proposal_decisions_reject_delete", planChangeProposalDecisionsRejectDeleteTrigger),
        (21, "plan_change_proposal_applications_reject_update", planChangeProposalApplicationsRejectUpdateTrigger),
        (21, "plan_change_proposal_applications_reject_delete", planChangeProposalApplicationsRejectDeleteTrigger),
        (21, "retained_plan_change_proposals_reject_update", immutableRetainedTrigger(table: "retained_plan_change_proposals", action: "update")),
        (21, "retained_plan_change_proposals_reject_delete", immutableRetainedTrigger(table: "retained_plan_change_proposals", action: "delete")),
        (21, "retained_plan_change_proposal_versions_reject_update", immutableRetainedTrigger(table: "retained_plan_change_proposal_versions", action: "update")),
        (21, "retained_plan_change_proposal_versions_reject_delete", immutableRetainedTrigger(table: "retained_plan_change_proposal_versions", action: "delete")),
        (21, "retained_plan_change_proposal_decisions_reject_update", immutableRetainedTrigger(table: "retained_plan_change_proposal_decisions", action: "update")),
        (21, "retained_plan_change_proposal_decisions_reject_delete", immutableRetainedTrigger(table: "retained_plan_change_proposal_decisions", action: "delete")),
        (21, "retained_plan_change_proposal_applications_reject_update", immutableRetainedTrigger(table: "retained_plan_change_proposal_applications", action: "update")),
        (21, "retained_plan_change_proposal_applications_reject_delete", immutableRetainedTrigger(table: "retained_plan_change_proposal_applications", action: "delete")),
        (22, "retained_ticket_retirements_reject_update", immutableRetainedTrigger(table: "retained_ticket_retirements", action: "update")),
        (22, "retained_ticket_retirements_reject_delete", immutableRetainedTrigger(table: "retained_ticket_retirements", action: "delete")),
        (22, "retained_ticket_successor_links_reject_update", immutableRetainedTrigger(table: "retained_ticket_successor_links", action: "update")),
        (22, "retained_ticket_successor_links_reject_delete", immutableRetainedTrigger(table: "retained_ticket_successor_links", action: "delete")),
        (22, "retained_delivery_goal_obligations_reject_update", immutableRetainedTrigger(table: "retained_delivery_goal_obligations", action: "update")),
        (22, "retained_delivery_goal_obligations_reject_delete", immutableRetainedTrigger(table: "retained_delivery_goal_obligations", action: "delete")),
        (22, "retained_delivery_goal_obligation_lineage_reject_update", immutableRetainedTrigger(table: "retained_delivery_goal_obligation_lineage", action: "update")),
        (22, "retained_delivery_goal_obligation_lineage_reject_delete", immutableRetainedTrigger(table: "retained_delivery_goal_obligation_lineage", action: "delete")),
        (22, "retained_delivery_goal_obligation_drops_reject_update", immutableRetainedTrigger(table: "retained_delivery_goal_obligation_drops", action: "update")),
        (22, "retained_delivery_goal_obligation_drops_reject_delete", immutableRetainedTrigger(table: "retained_delivery_goal_obligation_drops", action: "delete")),
        (23, "phase_lifecycles_after_phase_insert", phaseLifecyclesAfterPhaseInsertTrigger),
        (23, "phase_lifecycle_events_reject_update", phaseLifecycleEventsRejectUpdateTrigger),
        (23, "phase_lifecycle_events_reject_delete", phaseLifecycleEventsRejectDeleteTrigger),
        (23, "retained_phase_lifecycles_reject_update", immutableRetainedTrigger(table: "retained_phase_lifecycles", action: "update")),
        (23, "retained_phase_lifecycles_reject_delete", immutableRetainedTrigger(table: "retained_phase_lifecycles", action: "delete")),
        (23, "retained_phase_lifecycle_events_reject_update", immutableRetainedTrigger(table: "retained_phase_lifecycle_events", action: "update")),
        (23, "retained_phase_lifecycle_events_reject_delete", immutableRetainedTrigger(table: "retained_phase_lifecycle_events", action: "delete")),
        (25, "ticket_delivery_evidence_sets_reject_delete", deliveryEvidenceSetsRejectDeleteTrigger),
        (25, "ticket_delivery_evidence_targets_reject_update", deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_targets", action: "update")),
        (25, "ticket_delivery_evidence_targets_reject_delete", deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_targets", action: "delete")),
        (25, "ticket_delivery_evidence_observations_reject_update", deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_observations", action: "update")),
        (25, "ticket_delivery_evidence_observations_reject_delete", deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_observations", action: "delete")),
        (25, "retained_ticket_delivery_evidence_targets_reject_update", immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_targets", action: "update")),
        (25, "retained_ticket_delivery_evidence_targets_reject_delete", immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_targets", action: "delete")),
        (25, "retained_ticket_delivery_evidence_observations_reject_update", immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_observations", action: "update")),
        (25, "retained_ticket_delivery_evidence_observations_reject_delete", immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_observations", action: "delete")),
    ]

    private static let criticalIndexes: [(
        version: Int64,
        name: String,
        table: String,
        isUnique: Bool,
        columns: [(name: String, descending: Bool)]
    )] = [
        (13, "project_roots_project_identity_unique", "project_roots", true,
         [("project_id", false), ("id", false)]),
        (13, "project_documentation_bindings_repository_unique", "project_documentation_bindings", true,
         [("repository_id", false)]),
        (13, "project_documentation_bindings_root_unique", "project_documentation_bindings", true,
         [("root_id", false)]),
        (4, "audit_events_project_entity_index", "audit_events", false,
         [("project_id", false), ("entity_type", false), ("entity_id", false), ("created_at", false)]),
        (5, "project_active_phases_phase_index", "project_active_phases", false, [("phase_id", false)]),
        (6, "notification_events_project_created_index", "notification_events", false,
         [("project_id", false), ("created_at", true)]),
        (6, "notification_events_state_index", "notification_events", false,
         [("state", false), ("created_at", false)]),
        (8, "observed_goals_project_identity_unique", "observed_goals", true,
         [("project_id", false), ("id", false), ("thread_id", false)]),
        (8, "ticket_goal_links_project_ticket_unique", "ticket_goal_links", true,
         [("project_id", false), ("ticket_id", false)]),
        (8, "ticket_goal_links_project_goal_unique", "ticket_goal_links", true,
         [("project_id", false), ("goal_id", false)]),
        (11, "tickets_project_phase_identity_unique", "tickets", true,
         [("project_id", false), ("phase_id", false), ("id", false)]),
        (11, "delivery_goals_project_phase_identity_unique", "delivery_goals", true,
         [("project_id", false), ("phase_id", false), ("id", false)]),
        (11, "delivery_goals_phase_sort_index", "delivery_goals", false,
         [("project_id", false), ("phase_id", false), ("sort_order", false)]),
        (11, "delivery_goal_ticket_assignments_goal_index", "delivery_goal_ticket_assignments", false,
         [("project_id", false), ("phase_id", false), ("goal_id", false)]),
        (11, "delivery_goal_assignment_events_ticket_revision_unique", "delivery_goal_assignment_events", true,
         [("project_id", false), ("phase_id", false), ("ticket_id", false), ("revision", false)]),
        (12, "ticket_task_plans_ticket_unique", "ticket_task_plans", true,
         [("project_id", false), ("ticket_id", false)]),
        (12, "ticket_tasks_label_unique", "ticket_tasks", true,
         [("project_id", false), ("ticket_id", false), ("label", false)]),
        (12, "ticket_tasks_active_order_index", "ticket_tasks", false,
         [("project_id", false), ("ticket_id", false), ("lifecycle", false),
          ("sort_order", false), ("label", false), ("id", false)]),
        (17, "removed_projects_historical_registration_unique", "removed_projects", true,
         [("historical_project_id", false), ("registration_id", false)]),
        (17, "removed_projects_historical_project_index", "removed_projects", false,
         [("historical_project_id", false), ("removed_at", true)]),
        (17, "audit_events_historical_project_index", "audit_events", false,
         [("historical_project_id", false), ("historical_registration_id", false), ("created_at", true)]),
        (20, "ticket_reference_links_source_index", "ticket_reference_links", false,
         [("project_id", false), ("repository_id", false), ("artifact_id", false)]),
        (20, "ticket_reference_versions_source_index", "ticket_reference_versions", false,
         [("project_id", false), ("link_id", false), ("version", true)]),
        (20, "retained_ticket_reference_links_source_index", "retained_ticket_reference_links", false,
         [("historical_project_id", false), ("repository_id", false), ("artifact_id", false)]),
    ]

    private static let requiredForeignKeys: [(
        version: Int64,
        table: String,
        source: String,
        targetTable: String,
        target: String,
        onDelete: String
    )] = [
        (15, "project_registrations", "project_id", "projects", "id", "CASCADE"),
        (13, "project_documentation_bindings", "project_id", "projects", "id", "CASCADE"),
        (13, "project_documentation_bindings", "project_id,root_id", "project_roots", "project_id,id", "NO ACTION"),
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
        (8, "ticket_goal_links", "project_id,ticket_id,thread_id", "thread_links", "project_id,ticket_id,thread_id", "CASCADE"),
        (8, "ticket_goal_links", "project_id,goal_id,thread_id", "observed_goals", "project_id,id,thread_id", "CASCADE"),
        (11, "phase_plans", "project_id,phase_id", "phases", "project_id,id", "CASCADE"),
        (11, "delivery_goals", "project_id,phase_id", "phase_plans", "project_id,phase_id", "NO ACTION"),
        (11, "delivery_goal_done_criteria", "project_id,phase_id,goal_id", "delivery_goals", "project_id,phase_id,id", "CASCADE"),
        (11, "delivery_goal_ticket_assignments", "project_id,phase_id,goal_id", "delivery_goals", "project_id,phase_id,id", "NO ACTION"),
        (11, "delivery_goal_ticket_assignments", "project_id,phase_id,ticket_id", "tickets", "project_id,phase_id,id", "NO ACTION"),
        (11, "delivery_goal_assignment_events", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (11, "delivery_goal_assignment_events", "project_id,phase_id", "phase_plans", "project_id,phase_id", "NO ACTION"),
        (11, "delivery_goal_assignment_events", "project_id,phase_id,ticket_id", "tickets", "project_id,phase_id,id", "NO ACTION"),
        (11, "delivery_goal_assignment_events", "project_id,phase_id,previous_goal_id", "delivery_goals", "project_id,phase_id,id", "NO ACTION"),
        (11, "delivery_goal_assignment_events", "project_id,phase_id,current_goal_id", "delivery_goals", "project_id,phase_id,id", "NO ACTION"),
        (12, "ticket_task_plans", "project_id", "projects", "id", "NO ACTION"),
        (12, "ticket_task_plans", "project_id,ticket_id", "tickets", "project_id,id", "NO ACTION"),
        (12, "ticket_tasks", "project_id,ticket_id", "ticket_task_plans", "project_id,ticket_id", "NO ACTION"),
        (17, "retained_project_activity_events", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (17, "retained_delivery_goal_assignment_events", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (20, "ticket_reference_link_sets", "project_id,ticket_id", "tickets", "project_id,id", "NO ACTION"),
        (20, "ticket_reference_links", "project_id,ticket_id", "ticket_reference_link_sets", "project_id,ticket_id", "NO ACTION"),
        (20, "ticket_reference_versions", "project_id,ticket_id,link_id", "ticket_reference_links", "project_id,ticket_id,id", "NO ACTION"),
        (20, "retained_ticket_reference_links", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (20, "retained_ticket_reference_versions", "removal_id,historical_project_id,ticket_id,link_id", "retained_ticket_reference_links", "removal_id,historical_project_id,ticket_id,link_id", "NO ACTION"),
        (21, "plan_change_proposals", "project_id", "projects", "id", "CASCADE"),
        (21, "plan_change_proposal_versions", "project_id,proposal_id", "plan_change_proposals", "project_id,id", "NO ACTION"),
        (21, "plan_change_proposal_decisions", "project_id,proposal_id,version", "plan_change_proposal_versions", "project_id,proposal_id,version", "NO ACTION"),
        (21, "plan_change_proposal_applications", "project_id,proposal_id,version", "plan_change_proposal_versions", "project_id,proposal_id,version", "NO ACTION"),
        (21, "plan_change_proposal_applications", "project_id,proposal_id,version,decision_id", "plan_change_proposal_decisions", "project_id,proposal_id,version,id", "NO ACTION"),
        (21, "plan_change_proposal_applications", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (21, "retained_plan_change_proposals", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (21, "retained_plan_change_proposal_versions", "removal_id,historical_project_id,proposal_id", "retained_plan_change_proposals", "removal_id,historical_project_id,proposal_id", "NO ACTION"),
        (21, "retained_plan_change_proposal_decisions", "removal_id,historical_project_id,proposal_id,version", "retained_plan_change_proposal_versions", "removal_id,historical_project_id,proposal_id,version", "NO ACTION"),
        (21, "retained_plan_change_proposal_applications", "removal_id,historical_project_id,proposal_id,version", "retained_plan_change_proposal_versions", "removal_id,historical_project_id,proposal_id,version", "NO ACTION"),
        (21, "retained_plan_change_proposal_applications", "removal_id,historical_project_id,proposal_id,version,decision_id", "retained_plan_change_proposal_decisions", "removal_id,historical_project_id,proposal_id,version,id", "NO ACTION"),
        (21, "retained_plan_change_proposal_applications", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (22, "ticket_retirements", "project_id,ticket_id", "tickets", "project_id,id", "NO ACTION"),
        (22, "ticket_retirements", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (22, "ticket_successor_links", "project_id,original_ticket_id", "ticket_retirements", "project_id,ticket_id", "NO ACTION"),
        (22, "ticket_successor_links", "project_id,successor_ticket_id", "tickets", "project_id,id", "NO ACTION"),
        (22, "ticket_successor_links", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (22, "delivery_goal_obligations", "project_id,phase_id,goal_id", "delivery_goals", "project_id,phase_id,id", "NO ACTION"),
        (22, "delivery_goal_obligations", "project_id,ticket_id", "tickets", "project_id,id", "NO ACTION"),
        (22, "delivery_goal_obligation_lineage", "project_id,source_phase_id,source_goal_id,source_ticket_id", "delivery_goal_obligations", "project_id,phase_id,goal_id,ticket_id", "NO ACTION"),
        (22, "delivery_goal_obligation_lineage", "project_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id", "delivery_goal_obligations", "project_id,phase_id,goal_id,ticket_id", "NO ACTION"),
        (22, "delivery_goal_obligation_lineage", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (22, "delivery_goal_obligation_drops", "project_id,phase_id,goal_id,ticket_id", "delivery_goal_obligations", "project_id,phase_id,goal_id,ticket_id", "NO ACTION"),
        (22, "delivery_goal_obligation_drops", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (22, "retained_ticket_retirements", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (22, "retained_ticket_successor_links", "removal_id,historical_project_id,original_ticket_id", "retained_ticket_retirements", "removal_id,historical_project_id,ticket_id", "NO ACTION"),
        (22, "retained_delivery_goal_obligations", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (22, "retained_delivery_goal_obligation_lineage", "removal_id,historical_project_id,source_phase_id,source_goal_id,source_ticket_id", "retained_delivery_goal_obligations", "removal_id,historical_project_id,phase_id,goal_id,ticket_id", "NO ACTION"),
        (22, "retained_delivery_goal_obligation_lineage", "removal_id,historical_project_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id", "retained_delivery_goal_obligations", "removal_id,historical_project_id,phase_id,goal_id,ticket_id", "NO ACTION"),
        (22, "retained_delivery_goal_obligation_drops", "removal_id,historical_project_id,phase_id,goal_id,ticket_id", "retained_delivery_goal_obligations", "removal_id,historical_project_id,phase_id,goal_id,ticket_id", "NO ACTION"),
        (23, "phase_lifecycles", "project_id,phase_id", "phases", "project_id,id", "CASCADE"),
        (23, "phase_lifecycle_events", "project_id,phase_id", "phases", "project_id,id", "NO ACTION"),
        (23, "phase_lifecycle_events", "audit_event_id", "audit_events", "id", "NO ACTION"),
        (23, "retained_phase_lifecycles", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (23, "retained_phase_lifecycle_events", "removal_id,historical_project_id,phase_id", "retained_phase_lifecycles", "removal_id,historical_project_id,phase_id", "NO ACTION"),
        (25, "ticket_delivery_evidence_sets", "project_id,ticket_id", "tickets", "project_id,id", "NO ACTION"),
        (25, "ticket_delivery_evidence_targets", "project_id,ticket_id", "ticket_delivery_evidence_sets", "project_id,ticket_id", "NO ACTION"),
        (25, "ticket_delivery_evidence_observations", "project_id,ticket_id,target_version", "ticket_delivery_evidence_targets", "project_id,ticket_id,version", "NO ACTION"),
        (25, "retained_ticket_delivery_evidence_targets", "removal_id", "removed_projects", "removal_id", "NO ACTION"),
        (25, "retained_ticket_delivery_evidence_observations", "removal_id,historical_project_id,ticket_id,target_version", "retained_ticket_delivery_evidence_targets", "removal_id,historical_project_id,ticket_id,version", "NO ACTION"),
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

    private static let evidenceTableSQL = """
    CREATE TABLE evidence (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        ticket_id TEXT,
        path TEXT,
        is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
        artifact_id TEXT,
        CHECK ((path IS NOT NULL AND artifact_id IS NULL) OR
               (path IS NULL AND typeof(artifact_id) = 'text' AND length(artifact_id) BETWEEN 1 AND 128)),
        UNIQUE(project_id, path),
        UNIQUE(project_id, artifact_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
    )
    """

    private static let documentationBindingsTableSQL = """
    CREATE TABLE project_documentation_bindings (
        project_id TEXT PRIMARY KEY NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        root_id TEXT NOT NULL,
        repository_id TEXT NOT NULL CHECK (typeof(repository_id) = 'text' AND length(repository_id) = 36 AND repository_id = lower(repository_id)),
        accepted_catalog_version INTEGER NOT NULL CHECK (typeof(accepted_catalog_version) = 'integer' AND accepted_catalog_version > 0),
        accepted_catalog_digest TEXT NOT NULL CHECK (length(accepted_catalog_digest) = 64 AND accepted_catalog_digest NOT GLOB '*[^0-9a-f]*'),
        accepted_catalog BLOB NOT NULL CHECK (typeof(accepted_catalog) = 'blob' AND length(accepted_catalog) BETWEEN 1 AND 4194304),
        FOREIGN KEY(project_id, root_id) REFERENCES project_roots(project_id, id)
    )
    """

    // Catalog-agnostic: every old locator, ID, association, and availability is copied
    // exactly. No root/bookmark is opened and no repository binding is inferred.
    private static let schemaVersion13 = """
    ALTER TABLE evidence RENAME TO evidence_v12;
    \(evidenceTableSQL);
    INSERT INTO evidence (id, project_id, ticket_id, path, is_available)
        SELECT id, project_id, ticket_id, path, is_available FROM evidence_v12;
    DROP TABLE evidence_v12;
    CREATE UNIQUE INDEX project_roots_project_identity_unique ON project_roots(project_id, id);
    \(documentationBindingsTableSQL);
    CREATE UNIQUE INDEX project_documentation_bindings_root_unique ON project_documentation_bindings(root_id);
    CREATE UNIQUE INDEX project_documentation_bindings_repository_unique ON project_documentation_bindings(repository_id);
    """

    // History retains its original phase and goals when the ticket moves phases.
    // Only the ticket reference changes; current assignments remain phase-local.
    private static let schemaVersion14 = """
    ALTER TABLE delivery_goal_assignment_events RENAME TO delivery_goal_assignment_events_v13;
    \(deliveryGoalAssignmentEventsVersionFourteenTableSQL);
    INSERT INTO delivery_goal_assignment_events
        (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action)
        SELECT audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action
        FROM delivery_goal_assignment_events_v13;
    DROP TABLE delivery_goal_assignment_events_v13;
    CREATE UNIQUE INDEX delivery_goal_assignment_events_ticket_revision_unique
        ON delivery_goal_assignment_events(project_id, phase_id, ticket_id, revision);
    """

    private static let projectRegistrationsTableSQL = """
    CREATE TABLE project_registrations (
        project_id TEXT PRIMARY KEY NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        registration_id TEXT NOT NULL UNIQUE CHECK (typeof(registration_id) = 'text' AND length(registration_id) BETWEEN 1 AND 128),
        request_generation INTEGER NOT NULL DEFAULT 1 CHECK (typeof(request_generation) = 'integer' AND request_generation > 0),
        setup_state TEXT NOT NULL DEFAULT 'complete' CHECK (setup_state IN ('pending', 'complete'))
    )
    """

    // Existing project IDs are retained byte-for-byte. Each receives a new opaque local
    // registration identity, without inferring lifecycle state from paths or phases.
    private static let schemaVersion15 = """
    \(projectRegistrationsTableSQL);
    INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state)
    SELECT id,
           lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) ||
                 '-' || substr('89ab', (random() & 3) + 1, 1) || substr(hex(randomblob(2)), 2) ||
                 '-' || hex(randomblob(6))),
           1,
           CASE WHEN EXISTS (
               SELECT 1 FROM review_items
               WHERE review_items.project_id = projects.id
                 AND review_items.kind = 'onboarding_pending'
                 AND review_items.status = 'open'
           ) THEN 'pending' ELSE 'complete' END
    FROM projects;
    """

    private static let schemaVersion16 = """
    ALTER TABLE projects ADD COLUMN lifecycle TEXT NOT NULL DEFAULT 'active'
        CHECK (lifecycle IN ('active', 'archived'));
    """

    private static let schemaVersion17 = """
    CREATE TABLE removed_projects (
        removal_id TEXT PRIMARY KEY NOT NULL,
        historical_project_id TEXT NOT NULL,
        project_name TEXT NOT NULL,
        original_lifecycle TEXT NOT NULL CHECK (original_lifecycle IN ('active', 'archived')),
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL CHECK (request_generation > 0),
        removed_at TEXT NOT NULL,
        phase_count INTEGER NOT NULL CHECK (phase_count >= 0),
        ticket_count INTEGER NOT NULL CHECK (ticket_count >= 0),
        evidence_count INTEGER NOT NULL CHECK (evidence_count >= 0),
        history_count INTEGER NOT NULL CHECK (history_count >= 0)
    );
    CREATE UNIQUE INDEX removed_projects_historical_registration_unique
        ON removed_projects(historical_project_id, registration_id);
    CREATE INDEX removed_projects_historical_project_index
        ON removed_projects(historical_project_id, removed_at DESC);

    CREATE TABLE retained_project_activity_events (
        removal_id TEXT NOT NULL,
        source TEXT NOT NULL CHECK (source IN ('runtime', 'review', 'completion', 'notification')),
        source_id TEXT NOT NULL,
        title TEXT NOT NULL,
        detail TEXT NOT NULL,
        occurred_at TEXT,
        observed_at TEXT,
        recorded_at TEXT,
        ticket_id TEXT,
        phase_id TEXT,
        delivery_goal_id TEXT,
        originating_thread_id TEXT,
        delivery_lane TEXT CHECK (delivery_lane IS NULL OR delivery_lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
        runtime_state TEXT,
        notification_state TEXT,
        notification_status_text TEXT,
        PRIMARY KEY(removal_id, source, source_id),
        FOREIGN KEY(removal_id) REFERENCES removed_projects(removal_id) ON DELETE NO ACTION
    );

    CREATE TABLE retained_delivery_goal_assignment_events (
        removal_id TEXT NOT NULL,
        audit_event_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        previous_goal_id TEXT,
        current_goal_id TEXT,
        revision INTEGER NOT NULL,
        action TEXT NOT NULL,
        PRIMARY KEY(removal_id, audit_event_id, ticket_id),
        FOREIGN KEY(removal_id) REFERENCES removed_projects(removal_id) ON DELETE NO ACTION
    );

    CREATE TABLE project_removal_authorizations (
        project_id TEXT PRIMARY KEY NOT NULL,
        registration_id TEXT NOT NULL,
        removal_id TEXT NOT NULL
    );

    ALTER TABLE audit_events ADD COLUMN historical_project_id TEXT;
    ALTER TABLE audit_events ADD COLUMN historical_registration_id TEXT;
    UPDATE audit_events
    SET historical_project_id = project_id,
        historical_registration_id = (
            SELECT registration_id FROM project_registrations
            WHERE project_registrations.project_id = audit_events.project_id
        )
    WHERE project_id IS NOT NULL;
    CREATE INDEX audit_events_historical_project_index
        ON audit_events(historical_project_id, historical_registration_id, created_at DESC);

    ALTER TABLE agent_command_requests ADD COLUMN registration_project_id TEXT;
    ALTER TABLE agent_command_requests ADD COLUMN registration_id TEXT;
    ALTER TABLE agent_command_requests ADD COLUMN request_generation INTEGER;

    DROP TRIGGER ticket_task_plans_reject_delete;
    DROP TRIGGER ticket_tasks_reject_delete;
    DROP TRIGGER ticket_task_plans_reject_ticket_delete;
    DROP TRIGGER ticket_task_plans_reject_project_delete;
    \(ticketTaskPlansRejectDeleteVersionSeventeenTrigger);
    \(ticketTasksRejectDeleteVersionSeventeenTrigger);
    \(ticketTaskPlansRejectTicketDeleteVersionSeventeenTrigger);
    \(ticketTaskPlansRejectProjectDeleteVersionSeventeenTrigger);
    """

    private static let applicationRecoveryStateTableSQL = """
    CREATE TABLE application_recovery_state (
        singleton_id INTEGER PRIMARY KEY NOT NULL CHECK (singleton_id = 1),
        incarnation_id TEXT NOT NULL CHECK (length(incarnation_id) = 36),
        requires_scoped_commands INTEGER NOT NULL DEFAULT 0
            CHECK (requires_scoped_commands IN (0, 1)),
        last_operation_kind TEXT CHECK (last_operation_kind IS NULL OR last_operation_kind IN ('restore', 'tracking_reset')),
        last_operation_id TEXT,
        completed_at TEXT,
        CHECK ((last_operation_kind IS NULL) = (last_operation_id IS NULL)),
        CHECK ((last_operation_kind IS NULL) = (completed_at IS NULL))
    )
    """

    private static let schemaVersion18 = """
    \(applicationRecoveryStateTableSQL);
    INSERT INTO application_recovery_state (
        singleton_id, incarnation_id, requires_scoped_commands
    ) VALUES (
        1,
        lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' ||
        lower(hex(randomblob(2))) || '-' || lower(hex(randomblob(2))) || '-' ||
        lower(hex(randomblob(6))),
        0
    );
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
        phase_id TEXT,
        outcome TEXT NOT NULL,
        lane TEXT CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
        CHECK ((phase_id IS NULL) = (lane IS NULL)),
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

    private static let schemaVersion8 = """
    CREATE UNIQUE INDEX observed_goals_project_identity_unique
        ON observed_goals(project_id, id, thread_id);
    CREATE TABLE ticket_goal_links (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        thread_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        FOREIGN KEY(project_id, ticket_id, thread_id)
            REFERENCES thread_links(project_id, ticket_id, thread_id) ON DELETE CASCADE,
        FOREIGN KEY(project_id, goal_id, thread_id)
            REFERENCES observed_goals(project_id, id, thread_id) ON DELETE CASCADE
    );
    CREATE UNIQUE INDEX ticket_goal_links_project_ticket_unique
        ON ticket_goal_links(project_id, ticket_id);
    CREATE UNIQUE INDEX ticket_goal_links_project_goal_unique
        ON ticket_goal_links(project_id, goal_id);
    INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id)
    SELECT 'v8-' || thread_links.id,
           thread_links.project_id,
           thread_links.ticket_id,
           thread_links.thread_id,
           observed_goals.id
    FROM thread_links
    JOIN observed_goals
      ON observed_goals.project_id = thread_links.project_id
     AND observed_goals.thread_id = thread_links.thread_id
    WHERE (
        SELECT COUNT(*)
        FROM thread_links AS ticket_candidate
        WHERE ticket_candidate.project_id = thread_links.project_id
          AND ticket_candidate.ticket_id = thread_links.ticket_id
    ) = 1
      AND (
        SELECT COUNT(*)
        FROM observed_goals AS goal_candidate
        WHERE goal_candidate.project_id = thread_links.project_id
          AND goal_candidate.thread_id = thread_links.thread_id
      ) = 1
      AND (
        SELECT COUNT(*)
        FROM thread_links AS ticket_candidate
        WHERE ticket_candidate.project_id = observed_goals.project_id
          AND ticket_candidate.thread_id = observed_goals.thread_id
      ) = 1;
    """

    private static let alertRulesTableSQL = """
    CREATE TABLE alert_rules (
        kind TEXT PRIMARY KEY NOT NULL
            CHECK (kind IN ('blocked_linked_goals', 'agent_completion_and_review', 'needs_review_entry', 'paused_goals')),
        is_enabled INTEGER NOT NULL CHECK (is_enabled IN (0, 1))
    )
    """

    private static let schemaVersion9 = """
    \(alertRulesTableSQL);
    INSERT INTO alert_rules (kind, is_enabled) VALUES
        ('blocked_linked_goals', 1),
        ('agent_completion_and_review', 1),
        ('needs_review_entry', 1),
        ('paused_goals', 0);
    """

    private static let codexPluginLifecycleTableSQL = """
    CREATE TABLE codex_plugin_lifecycle (
        plugin_id TEXT PRIMARY KEY NOT NULL CHECK (plugin_id = 'release-radar'),
        intent TEXT NOT NULL CHECK (intent IN ('neverInstalled','managedInstalled','removed','attentionRequired')),
        managed_version TEXT,
        managed_digest TEXT,
        verified_at TEXT,
        CHECK ((managed_version IS NULL) = (managed_digest IS NULL)),
        CHECK ((managed_version IS NULL) = (verified_at IS NULL))
    )
    """

    private static let schemaVersion10 = """
    \(codexPluginLifecycleTableSQL);
    INSERT INTO codex_plugin_lifecycle (plugin_id, intent)
    VALUES ('release-radar', 'neverInstalled');
    """

    private static let phasePlansTableSQL = """
    CREATE TABLE phase_plans (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        state TEXT NOT NULL CHECK (state IN ('legacy_unassessed', 'draft', 'ready')),
        revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
        ready_revision INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        finalized_at TEXT,
        PRIMARY KEY(project_id, phase_id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE,
        CHECK ((state = 'ready') = (ready_revision IS NOT NULL)),
        CHECK (ready_revision IS NULL OR ready_revision = revision)
    )
    """

    private static let deliveryGoalsTableSQL = """
    CREATE TABLE delivery_goals (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        outcome TEXT NOT NULL,
        lifecycle TEXT NOT NULL CHECK (
            lifecycle IN ('draft', 'planned', 'active', 'awaiting_acceptance', 'accepted', 'superseded')
        ),
        sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        activated_at TEXT,
        accepted_at TEXT,
        PRIMARY KEY(project_id, id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phase_plans(project_id, phase_id)
    )
    """

    private static let deliveryGoalDoneCriteriaTableSQL = """
    CREATE TABLE delivery_goal_done_criteria (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
        criterion TEXT NOT NULL CHECK (length(trim(criterion)) > 0),
        PRIMARY KEY(project_id, phase_id, goal_id, sort_order),
        FOREIGN KEY(project_id, phase_id, goal_id)
            REFERENCES delivery_goals(project_id, phase_id, id) ON DELETE CASCADE
    )
    """

    private static let deliveryGoalTicketAssignmentsTableSQL = """
    CREATE TABLE delivery_goal_ticket_assignments (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id),
        FOREIGN KEY(project_id, phase_id, goal_id)
            REFERENCES delivery_goals(project_id, phase_id, id),
        FOREIGN KEY(project_id, phase_id, ticket_id)
            REFERENCES tickets(project_id, phase_id, id)
    )
    """

    private static let deliveryGoalAssignmentEventsTableSQL = """
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
    )
    """

    private static let deliveryGoalAssignmentEventsVersionFourteenTableSQL = """
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
        FOREIGN KEY(project_id, ticket_id)
            REFERENCES tickets(project_id, id),
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
    )
    """

    private static let deliveryGoalAssignmentEventsVersionTwentyTwoTableSQL = """
    CREATE TABLE delivery_goal_assignment_events (
        audit_event_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        previous_goal_id TEXT,
        current_goal_id TEXT,
        revision INTEGER NOT NULL CHECK (revision >= 0),
        action TEXT NOT NULL CHECK (action IN ('assigned', 'unassigned', 'reassigned')),
        PRIMARY KEY(audit_event_id, phase_id, ticket_id),
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) DEFERRABLE INITIALLY DEFERRED,
        FOREIGN KEY(project_id, phase_id) REFERENCES phase_plans(project_id, phase_id),
        FOREIGN KEY(project_id, ticket_id)
            REFERENCES tickets(project_id, id),
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
    )
    """

    private static let ticketTaskPlansTableSQL = """
    CREATE TABLE ticket_task_plans (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        revision INTEGER NOT NULL CHECK (revision > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id),
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE NO ACTION,
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id)
            ON DELETE NO ACTION
    )
    """

    private static let ticketTasksTableSQL = """
    CREATE TABLE ticket_tasks (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
        label TEXT NOT NULL CHECK (length(CAST(label AS BLOB)) BETWEEN 1 AND 256),
        title TEXT NOT NULL CHECK (length(CAST(title AS BLOB)) BETWEEN 1 AND 4096),
        sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
        completion TEXT NOT NULL CHECK (completion IN ('pending', 'completed')),
        lifecycle TEXT NOT NULL CHECK (lifecycle IN ('active', 'superseded')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        superseded_at TEXT,
        PRIMARY KEY(project_id, ticket_id, id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES ticket_task_plans(project_id, ticket_id)
            ON DELETE NO ACTION,
        CHECK ((completion = 'completed') = (completed_at IS NOT NULL)),
        CHECK ((lifecycle = 'superseded') = (superseded_at IS NOT NULL)),
        CHECK (completed_at IS NULL OR completed_at >= created_at),
        CHECK (superseded_at IS NULL OR superseded_at >= created_at),
        CHECK (updated_at >= created_at)
    )
    """

    private static let ticketTaskTableSQL: [(name: String, sql: String)] = [
        ("ticket_task_plans", ticketTaskPlansTableSQL),
        ("ticket_tasks", ticketTasksTableSQL),
    ]

    private static let planningTableSQL: [(name: String, sql: String)] = [
        ("phase_plans", phasePlansTableSQL),
        ("delivery_goals", deliveryGoalsTableSQL),
        ("delivery_goal_done_criteria", deliveryGoalDoneCriteriaTableSQL),
        ("delivery_goal_ticket_assignments", deliveryGoalTicketAssignmentsTableSQL),
        ("delivery_goal_assignment_events", deliveryGoalAssignmentEventsTableSQL),
    ]

    private static let ticketsVersionElevenTableSQL = """
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
    )
    """

    private static let ticketsVersionNineteenTableSQL = """
    CREATE TABLE tickets (
        id TEXT PRIMARY KEY NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        phase_id TEXT,
        outcome TEXT NOT NULL,
        lane TEXT CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
        plan_legacy_continuation INTEGER NOT NULL DEFAULT 0
            CHECK (plan_legacy_continuation IN (0, 1)),
        CHECK ((phase_id IS NULL) = (lane IS NULL)),
        UNIQUE(project_id, id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
    )
    """

    private static let schemaVersion11 = """
    ALTER TABLE tickets ADD COLUMN plan_legacy_continuation INTEGER NOT NULL DEFAULT 0
        CHECK (plan_legacy_continuation IN (0, 1));
    UPDATE tickets
    SET plan_legacy_continuation = 1
    WHERE lane IN ('in_progress', 'needs_review');

    \(phasePlansTableSQL);
    \(deliveryGoalsTableSQL);
    CREATE UNIQUE INDEX tickets_project_phase_identity_unique
        ON tickets(project_id, phase_id, id);
    CREATE UNIQUE INDEX delivery_goals_project_phase_identity_unique
        ON delivery_goals(project_id, phase_id, id);
    CREATE INDEX delivery_goals_phase_sort_index
        ON delivery_goals(project_id, phase_id, sort_order);
    \(deliveryGoalDoneCriteriaTableSQL);
    \(deliveryGoalTicketAssignmentsTableSQL);
    CREATE INDEX delivery_goal_ticket_assignments_goal_index
        ON delivery_goal_ticket_assignments(project_id, phase_id, goal_id);
    \(deliveryGoalAssignmentEventsTableSQL);
    CREATE UNIQUE INDEX delivery_goal_assignment_events_ticket_revision_unique
        ON delivery_goal_assignment_events(project_id, phase_id, ticket_id, revision);

    INSERT INTO phase_plans (
        project_id, phase_id, state, revision, ready_revision,
        created_at, updated_at, finalized_at
    )
    SELECT phases.project_id, phases.id, 'legacy_unassessed', 0, NULL,
           migration_timestamp.value, migration_timestamp.value, NULL
    FROM phases
    CROSS JOIN (
        SELECT strftime('%Y-%m-%dT%H:%M:%fZ', 'now') AS value
    ) AS migration_timestamp;

    \(phasePlanAfterPhaseInsertTrigger);
    \(rejectDeliveryGoalOwnershipChangeTrigger);
    \(rejectLegacyContinuationInsertTrigger);
    \(rejectLegacyContinuationRegrantTrigger);
    """

    private static let schemaVersion12 = """
    \(ticketTaskPlansTableSQL);
    \(ticketTasksTableSQL);
    CREATE UNIQUE INDEX ticket_task_plans_ticket_unique
        ON ticket_task_plans(project_id, ticket_id);
    CREATE UNIQUE INDEX ticket_tasks_label_unique
        ON ticket_tasks(project_id, ticket_id, label COLLATE BINARY);
    CREATE INDEX ticket_tasks_active_order_index
        ON ticket_tasks(
            project_id, ticket_id, lifecycle, sort_order,
            label COLLATE BINARY, id COLLATE BINARY
        );
    \(ticketTasksRejectIdentityUpdateTrigger);
    \(ticketTasksRejectLabelUpdateTrigger);
    \(ticketTaskPlansRejectDeleteTrigger);
    \(ticketTasksRejectDeleteTrigger);
    \(ticketTaskPlansRejectTicketDeleteTrigger);
    \(ticketTaskPlansRejectProjectDeleteTrigger);
    """

    // Preserve every existing ticket identity and its dependent records while
    // making placement explicit: an unassigned ticket has neither phase nor lane.
    private static let schemaVersion19 = """
    PRAGMA legacy_alter_table = ON;
    ALTER TABLE tickets RENAME TO tickets_v18;
    \(ticketsVersionNineteenTableSQL);
    INSERT INTO tickets (id, project_id, phase_id, outcome, lane, plan_legacy_continuation)
    SELECT id, project_id, phase_id, outcome, lane, plan_legacy_continuation FROM tickets_v18;
    DROP TABLE tickets_v18;
    CREATE UNIQUE INDEX tickets_project_phase_identity_unique
        ON tickets(project_id, phase_id, id);
    \(rejectLegacyContinuationInsertTrigger);
    \(rejectLegacyContinuationRegrantTrigger);
    \(ticketTaskPlansRejectTicketDeleteVersionSeventeenTrigger);
    PRAGMA legacy_alter_table = OFF;
    """

    // Reference history starts empty. Existing documentation and ticket text are
    // deliberately not interpreted as links during migration.
    private static let schemaVersion20 = """
    CREATE TABLE ticket_reference_link_sets (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        revision INTEGER NOT NULL CHECK (revision > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE NO ACTION
    );

    CREATE TABLE ticket_reference_links (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
        kind TEXT NOT NULL CHECK (kind IN ('requirement', 'decision')),
        repository_id TEXT NOT NULL CHECK (length(repository_id) = 36 AND repository_id = lower(repository_id)),
        artifact_id TEXT NOT NULL CHECK (length(CAST(artifact_id AS BLOB)) BETWEEN 1 AND 128),
        current_version INTEGER NOT NULL CHECK (current_version > 0),
        relationship TEXT NOT NULL CHECK (relationship IN ('current', 'retired')),
        retired_version INTEGER,
        retired_at TEXT,
        retirement_reason TEXT CHECK (retirement_reason IS NULL OR length(CAST(retirement_reason AS BLOB)) BETWEEN 1 AND 4096),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id, id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES ticket_reference_link_sets(project_id, ticket_id) ON DELETE NO ACTION,
        CHECK ((relationship = 'current' AND retired_version IS NULL AND retired_at IS NULL AND retirement_reason IS NULL)
            OR (relationship = 'retired' AND retired_version = current_version AND retired_at IS NOT NULL))
    );
    CREATE INDEX ticket_reference_links_source_index
        ON ticket_reference_links(project_id, repository_id, artifact_id);

    CREATE TABLE ticket_reference_versions (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        link_id TEXT NOT NULL,
        version INTEGER NOT NULL CHECK (version > 0),
        content_digest TEXT NOT NULL CHECK (length(content_digest) = 64 AND content_digest NOT GLOB '*[^0-9a-f]*'),
        source_local_id TEXT CHECK (source_local_id IS NULL OR length(CAST(source_local_id AS BLOB)) BETWEEN 1 AND 256),
        locator TEXT CHECK (locator IS NULL OR length(CAST(locator AS BLOB)) BETWEEN 1 AND 4096),
        catalog_version INTEGER NOT NULL CHECK (catalog_version > 0),
        catalog_digest TEXT NOT NULL CHECK (length(catalog_digest) = 64 AND catalog_digest NOT GLOB '*[^0-9a-f]*'),
        observed_path TEXT NOT NULL CHECK (length(CAST(observed_path AS BLOB)) BETWEEN 1 AND 4096),
        observed_lifecycle TEXT NOT NULL CHECK (observed_lifecycle IN ('proposed', 'active', 'completed', 'superseded', 'archived')),
        observed_authority TEXT NOT NULL CHECK (observed_authority IN ('controlling', 'supporting', 'nonAuthoritative')),
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id, link_id, version),
        FOREIGN KEY(project_id, ticket_id, link_id)
            REFERENCES ticket_reference_links(project_id, ticket_id, id) ON DELETE NO ACTION
    );
    CREATE INDEX ticket_reference_versions_source_index
        ON ticket_reference_versions(project_id, link_id, version DESC);

    CREATE TABLE retained_ticket_reference_links (
        removal_id TEXT NOT NULL REFERENCES removed_projects(removal_id) ON DELETE NO ACTION,
        historical_project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        link_id TEXT NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('requirement', 'decision')),
        repository_id TEXT NOT NULL,
        artifact_id TEXT NOT NULL,
        current_version INTEGER NOT NULL,
        relationship TEXT NOT NULL CHECK (relationship IN ('current', 'retired')),
        retired_version INTEGER,
        retired_at TEXT,
        retirement_reason TEXT,
        link_set_revision INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, ticket_id, link_id)
    );
    CREATE INDEX retained_ticket_reference_links_source_index
        ON retained_ticket_reference_links(historical_project_id, repository_id, artifact_id);

    CREATE TABLE retained_ticket_reference_versions (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        link_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        content_digest TEXT NOT NULL,
        source_local_id TEXT,
        locator TEXT,
        catalog_version INTEGER NOT NULL,
        catalog_digest TEXT NOT NULL,
        observed_path TEXT NOT NULL,
        observed_lifecycle TEXT NOT NULL,
        observed_authority TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, ticket_id, link_id, version),
        FOREIGN KEY(removal_id, historical_project_id, ticket_id, link_id)
            REFERENCES retained_ticket_reference_links(removal_id, historical_project_id, ticket_id, link_id)
            ON DELETE NO ACTION
    );

    \(ticketReferenceVersionsRejectUpdateTrigger);
    \(ticketReferenceVersionsRejectDeleteTrigger);
    \(ticketReferenceLinksRejectIdentityUpdateTrigger);
    \(ticketReferenceLinksRejectDeleteTrigger);
    \(ticketReferenceLinkSetsRejectDeleteTrigger);
    """

    // Proposal history starts empty. No existing plan edits or audits imply a
    // proposal, decision, approval, or application.
    private static let schemaVersion21 = """
    CREATE TABLE plan_change_proposals (
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
        current_version INTEGER NOT NULL CHECK (current_version > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(project_id, id)
    );

    CREATE TABLE plan_change_proposal_versions (
        project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        version INTEGER NOT NULL CHECK (version > 0),
        registration_id TEXT NOT NULL CHECK (length(CAST(registration_id AS BLOB)) BETWEEN 1 AND 128),
        request_generation INTEGER NOT NULL CHECK (request_generation > 0),
        baseline_digest TEXT NOT NULL CHECK (length(baseline_digest) = 64 AND baseline_digest NOT GLOB '*[^0-9a-f]*'),
        baseline_data BLOB NOT NULL CHECK (length(baseline_data) > 0),
        operations_data BLOB NOT NULL CHECK (length(operations_data) > 0),
        diff_data BLOB NOT NULL CHECK (length(diff_data) > 0),
        source_impacts_data BLOB NOT NULL CHECK (length(source_impacts_data) > 0),
        rationale TEXT NOT NULL CHECK (length(CAST(rationale AS BLOB)) BETWEEN 1 AND 4096),
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, proposal_id, version),
        FOREIGN KEY(project_id, proposal_id)
            REFERENCES plan_change_proposals(project_id, id) ON DELETE NO ACTION
    );

    CREATE TABLE plan_change_proposal_decisions (
        project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
        disposition TEXT NOT NULL CHECK (disposition IN ('approved', 'rejected')),
        baseline_digest TEXT NOT NULL CHECK (length(baseline_digest) = 64 AND baseline_digest NOT GLOB '*[^0-9a-f]*'),
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL CHECK (request_generation > 0),
        actor_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, proposal_id, version),
        UNIQUE(project_id, proposal_id, version, id),
        FOREIGN KEY(project_id, proposal_id, version)
            REFERENCES plan_change_proposal_versions(project_id, proposal_id, version) ON DELETE NO ACTION
    );

    CREATE TABLE plan_change_proposal_applications (
        project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
        decision_id TEXT NOT NULL,
        audit_event_id TEXT NOT NULL,
        applied_at TEXT NOT NULL,
        PRIMARY KEY(project_id, proposal_id, version),
        UNIQUE(id),
        FOREIGN KEY(project_id, proposal_id, version)
            REFERENCES plan_change_proposal_versions(project_id, proposal_id, version) ON DELETE NO ACTION,
        FOREIGN KEY(project_id, proposal_id, version, decision_id)
            REFERENCES plan_change_proposal_decisions(project_id, proposal_id, version, id) ON DELETE NO ACTION,
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) ON DELETE NO ACTION
            DEFERRABLE INITIALLY DEFERRED
    );

    CREATE TABLE retained_plan_change_proposals (
        removal_id TEXT NOT NULL REFERENCES removed_projects(removal_id) ON DELETE NO ACTION,
        historical_project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        current_version INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, proposal_id)
    );

    CREATE TABLE retained_plan_change_proposal_versions (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL,
        baseline_digest TEXT NOT NULL,
        baseline_data BLOB NOT NULL,
        operations_data BLOB NOT NULL,
        diff_data BLOB NOT NULL,
        source_impacts_data BLOB NOT NULL,
        rationale TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, proposal_id, version),
        FOREIGN KEY(removal_id, historical_project_id, proposal_id)
            REFERENCES retained_plan_change_proposals(removal_id, historical_project_id, proposal_id)
            ON DELETE NO ACTION
    );

    CREATE TABLE retained_plan_change_proposal_decisions (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        id TEXT NOT NULL,
        disposition TEXT NOT NULL,
        baseline_digest TEXT NOT NULL,
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL,
        actor_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, proposal_id, version),
        UNIQUE(removal_id, historical_project_id, proposal_id, version, id),
        FOREIGN KEY(removal_id, historical_project_id, proposal_id, version)
            REFERENCES retained_plan_change_proposal_versions(removal_id, historical_project_id, proposal_id, version)
            ON DELETE NO ACTION
    );

    CREATE TABLE retained_plan_change_proposal_applications (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        proposal_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        id TEXT NOT NULL,
        decision_id TEXT NOT NULL,
        audit_event_id TEXT NOT NULL REFERENCES audit_events(id) ON DELETE NO ACTION
            DEFERRABLE INITIALLY DEFERRED,
        applied_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, proposal_id, version),
        UNIQUE(removal_id, id),
        FOREIGN KEY(removal_id, historical_project_id, proposal_id, version)
            REFERENCES retained_plan_change_proposal_versions(removal_id, historical_project_id, proposal_id, version)
            ON DELETE NO ACTION,
        FOREIGN KEY(removal_id, historical_project_id, proposal_id, version, decision_id)
            REFERENCES retained_plan_change_proposal_decisions(removal_id, historical_project_id, proposal_id, version, id)
            ON DELETE NO ACTION
    );

    \(planChangeProposalVersionsRejectUpdateTrigger);
    \(planChangeProposalVersionsRejectDeleteTrigger);
    \(planChangeProposalDecisionsRejectUpdateTrigger);
    \(planChangeProposalDecisionsRejectDeleteTrigger);
    \(planChangeProposalApplicationsRejectUpdateTrigger);
    \(planChangeProposalApplicationsRejectDeleteTrigger);
    \(immutableRetainedTrigger(table: "retained_plan_change_proposals", action: "update"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposals", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposal_versions", action: "update"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposal_versions", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposal_decisions", action: "update"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposal_decisions", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposal_applications", action: "update"));
    \(immutableRetainedTrigger(table: "retained_plan_change_proposal_applications", action: "delete"));
    """

    // Current goal membership becomes explicit coverage. Historical membership
    // loss is preserved as unassessed debt; migration never invents a carry,
    // successor, drop, approval, or completed result.
    private static let schemaVersion22 = """
    ALTER TABLE delivery_goal_assignment_events RENAME TO delivery_goal_assignment_events_v21;
    \(deliveryGoalAssignmentEventsVersionTwentyTwoTableSQL);
    INSERT INTO delivery_goal_assignment_events
        SELECT * FROM delivery_goal_assignment_events_v21;
    DROP TABLE delivery_goal_assignment_events_v21;
    CREATE UNIQUE INDEX delivery_goal_assignment_events_ticket_revision_unique
        ON delivery_goal_assignment_events(project_id, phase_id, ticket_id, revision);

    CREATE TABLE ticket_retirements (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        disposition TEXT NOT NULL CHECK (disposition IN ('withdrawn', 'replaced', 'split')),
        reason TEXT NOT NULL CHECK (length(CAST(reason AS BLOB)) BETWEEN 1 AND 4096),
        last_phase_id TEXT,
        last_lane TEXT CHECK (last_lane IS NULL OR last_lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
        audit_event_id TEXT NOT NULL,
        retired_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE NO ACTION,
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
        CHECK ((last_phase_id IS NULL) = (last_lane IS NULL))
    );

    CREATE TABLE ticket_successor_links (
        project_id TEXT NOT NULL,
        original_ticket_id TEXT NOT NULL,
        successor_ticket_id TEXT NOT NULL,
        relation TEXT NOT NULL CHECK (relation IN ('replacement', 'split')),
        sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
        audit_event_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, original_ticket_id, successor_ticket_id),
        UNIQUE(project_id, successor_ticket_id),
        FOREIGN KEY(project_id, original_ticket_id) REFERENCES ticket_retirements(project_id, ticket_id) ON DELETE NO ACTION,
        FOREIGN KEY(project_id, successor_ticket_id) REFERENCES tickets(project_id, id) ON DELETE NO ACTION,
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
        CHECK (original_ticket_id <> successor_ticket_id)
    );

    CREATE TABLE delivery_goal_obligations (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        scope TEXT NOT NULL CHECK (length(CAST(scope AS BLOB)) BETWEEN 1 AND 4096),
        assessment TEXT NOT NULL CHECK (assessment IN ('current', 'unassessed')),
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, phase_id, goal_id, ticket_id),
        FOREIGN KEY(project_id, phase_id, goal_id) REFERENCES delivery_goals(project_id, phase_id, id) ON DELETE NO ACTION,
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE NO ACTION
    );

    CREATE TABLE delivery_goal_obligation_lineage (
        project_id TEXT NOT NULL,
        source_phase_id TEXT NOT NULL,
        source_goal_id TEXT NOT NULL,
        source_ticket_id TEXT NOT NULL,
        descendant_phase_id TEXT NOT NULL,
        descendant_goal_id TEXT NOT NULL,
        descendant_ticket_id TEXT NOT NULL,
        reason TEXT NOT NULL CHECK (length(CAST(reason AS BLOB)) BETWEEN 1 AND 4096),
        audit_event_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(
            project_id, source_phase_id, source_goal_id, source_ticket_id,
            descendant_phase_id, descendant_goal_id, descendant_ticket_id
        ),
        UNIQUE(project_id, descendant_phase_id, descendant_goal_id, descendant_ticket_id),
        FOREIGN KEY(project_id, source_phase_id, source_goal_id, source_ticket_id)
            REFERENCES delivery_goal_obligations(project_id, phase_id, goal_id, ticket_id) ON DELETE NO ACTION,
        FOREIGN KEY(project_id, descendant_phase_id, descendant_goal_id, descendant_ticket_id)
            REFERENCES delivery_goal_obligations(project_id, phase_id, goal_id, ticket_id) ON DELETE NO ACTION,
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
        CHECK (
            source_phase_id <> descendant_phase_id
            OR source_goal_id <> descendant_goal_id
            OR source_ticket_id <> descendant_ticket_id
        )
    );

    CREATE TABLE delivery_goal_obligation_drops (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        reason TEXT NOT NULL CHECK (length(CAST(reason AS BLOB)) BETWEEN 1 AND 4096),
        audit_event_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, phase_id, goal_id, ticket_id),
        FOREIGN KEY(project_id, phase_id, goal_id, ticket_id)
            REFERENCES delivery_goal_obligations(project_id, phase_id, goal_id, ticket_id) ON DELETE NO ACTION,
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED
    );

    CREATE TABLE retained_ticket_retirements (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        outcome TEXT NOT NULL,
        disposition TEXT NOT NULL,
        reason TEXT NOT NULL,
        last_phase_id TEXT,
        last_lane TEXT,
        audit_event_id TEXT NOT NULL,
        retired_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, ticket_id),
        FOREIGN KEY(removal_id) REFERENCES removed_projects(removal_id) ON DELETE NO ACTION
    );

    CREATE TABLE retained_ticket_successor_links (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        original_ticket_id TEXT NOT NULL,
        successor_ticket_id TEXT NOT NULL,
        relation TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        audit_event_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, original_ticket_id, successor_ticket_id),
        FOREIGN KEY(removal_id, historical_project_id, original_ticket_id)
            REFERENCES retained_ticket_retirements(removal_id, historical_project_id, ticket_id) ON DELETE NO ACTION
    );

    CREATE TABLE retained_delivery_goal_obligations (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        scope TEXT NOT NULL,
        assessment TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, phase_id, goal_id, ticket_id),
        FOREIGN KEY(removal_id) REFERENCES removed_projects(removal_id) ON DELETE NO ACTION
    );

    CREATE TABLE retained_delivery_goal_obligation_lineage (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        source_phase_id TEXT NOT NULL,
        source_goal_id TEXT NOT NULL,
        source_ticket_id TEXT NOT NULL,
        descendant_phase_id TEXT NOT NULL,
        descendant_goal_id TEXT NOT NULL,
        descendant_ticket_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        audit_event_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(
            removal_id, historical_project_id, source_phase_id, source_goal_id, source_ticket_id,
            descendant_phase_id, descendant_goal_id, descendant_ticket_id
        ),
        FOREIGN KEY(removal_id, historical_project_id, source_phase_id, source_goal_id, source_ticket_id)
            REFERENCES retained_delivery_goal_obligations(removal_id, historical_project_id, phase_id, goal_id, ticket_id) ON DELETE NO ACTION,
        FOREIGN KEY(removal_id, historical_project_id, descendant_phase_id, descendant_goal_id, descendant_ticket_id)
            REFERENCES retained_delivery_goal_obligations(removal_id, historical_project_id, phase_id, goal_id, ticket_id) ON DELETE NO ACTION
    );

    CREATE TABLE retained_delivery_goal_obligation_drops (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        audit_event_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, phase_id, goal_id, ticket_id),
        FOREIGN KEY(removal_id, historical_project_id, phase_id, goal_id, ticket_id)
            REFERENCES retained_delivery_goal_obligations(removal_id, historical_project_id, phase_id, goal_id, ticket_id) ON DELETE NO ACTION
    );

    \(immutableRetainedTrigger(table: "retained_ticket_retirements", action: "update"));
    \(immutableRetainedTrigger(table: "retained_ticket_retirements", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_ticket_successor_links", action: "update"));
    \(immutableRetainedTrigger(table: "retained_ticket_successor_links", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_delivery_goal_obligations", action: "update"));
    \(immutableRetainedTrigger(table: "retained_delivery_goal_obligations", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_delivery_goal_obligation_lineage", action: "update"));
    \(immutableRetainedTrigger(table: "retained_delivery_goal_obligation_lineage", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_delivery_goal_obligation_drops", action: "update"));
    \(immutableRetainedTrigger(table: "retained_delivery_goal_obligation_drops", action: "delete"));

    INSERT INTO delivery_goal_obligations (
        project_id, phase_id, goal_id, ticket_id, scope, assessment, created_at
    )
    SELECT assignments.project_id, assignments.phase_id, assignments.goal_id,
           assignments.ticket_id, tickets.outcome, 'current',
           strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    FROM delivery_goal_ticket_assignments AS assignments
    JOIN tickets
      ON tickets.project_id = assignments.project_id
     AND tickets.id = assignments.ticket_id;

    INSERT OR IGNORE INTO delivery_goal_obligations (
        project_id, phase_id, goal_id, ticket_id, scope, assessment, created_at
    )
    SELECT events.project_id, events.phase_id, events.previous_goal_id,
           events.ticket_id, tickets.outcome, 'unassessed',
           strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    FROM delivery_goal_assignment_events AS events
    JOIN tickets
      ON tickets.project_id = events.project_id
     AND tickets.id = events.ticket_id
    WHERE events.action IN ('unassigned', 'reassigned')
      AND events.previous_goal_id IS NOT NULL
      AND tickets.lane <> 'accepted';
    """

    private static let schemaVersion23 = """
    CREATE TABLE phase_lifecycles (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        lifecycle TEXT NOT NULL CHECK (lifecycle IN ('unassessed', 'upcoming', 'in_delivery', 'completed')),
        revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
        completion_baseline_digest TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        PRIMARY KEY(project_id, phase_id),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE,
        CHECK (
            (lifecycle = 'completed' AND completion_baseline_digest IS NOT NULL AND completed_at IS NOT NULL)
            OR (lifecycle <> 'completed' AND completion_baseline_digest IS NULL AND completed_at IS NULL)
        )
    );

    CREATE TABLE phase_lifecycle_events (
        project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        revision INTEGER NOT NULL CHECK (revision > 0),
        previous_lifecycle TEXT NOT NULL CHECK (previous_lifecycle IN ('unassessed', 'upcoming', 'in_delivery', 'completed')),
        current_lifecycle TEXT NOT NULL CHECK (current_lifecycle IN ('upcoming', 'in_delivery', 'completed')),
        action TEXT NOT NULL CHECK (action IN ('move_upcoming', 'begin_delivery', 'complete', 'reopen_in_delivery', 'reopen_upcoming')),
        reason TEXT NOT NULL CHECK (length(CAST(reason AS BLOB)) BETWEEN 1 AND 4096),
        audit_event_id TEXT NOT NULL,
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL CHECK (request_generation >= 1),
        planning_baseline_digest TEXT,
        created_at TEXT NOT NULL,
        PRIMARY KEY(project_id, phase_id, revision),
        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id) ON DELETE NO ACTION,
        FOREIGN KEY(audit_event_id) REFERENCES audit_events(id) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
        CHECK ((action = 'complete') = (planning_baseline_digest IS NOT NULL)),
        CHECK (previous_lifecycle <> current_lifecycle)
    );

    CREATE TABLE retained_phase_lifecycles (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        phase_name TEXT NOT NULL,
        lifecycle TEXT NOT NULL,
        revision INTEGER NOT NULL,
        completion_baseline_digest TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        PRIMARY KEY(removal_id, historical_project_id, phase_id),
        FOREIGN KEY(removal_id) REFERENCES removed_projects(removal_id) ON DELETE NO ACTION
    );

    CREATE TABLE retained_phase_lifecycle_events (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        phase_id TEXT NOT NULL,
        revision INTEGER NOT NULL,
        previous_lifecycle TEXT NOT NULL,
        current_lifecycle TEXT NOT NULL,
        action TEXT NOT NULL,
        reason TEXT NOT NULL,
        audit_event_id TEXT NOT NULL,
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL,
        planning_baseline_digest TEXT,
        created_at TEXT NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, phase_id, revision),
        FOREIGN KEY(removal_id, historical_project_id, phase_id)
            REFERENCES retained_phase_lifecycles(removal_id, historical_project_id, phase_id)
            ON DELETE NO ACTION
    );

    INSERT INTO phase_lifecycles (
        project_id, phase_id, lifecycle, revision, completion_baseline_digest,
        created_at, updated_at, completed_at
    )
    SELECT project_id, id, 'unassessed', 0, NULL,
           strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
           strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
           NULL
    FROM phases;

    \(phaseLifecyclesAfterPhaseInsertTrigger);
    \(phaseLifecycleEventsRejectUpdateTrigger);
    \(phaseLifecycleEventsRejectDeleteTrigger);
    \(immutableRetainedTrigger(table: "retained_phase_lifecycles", action: "update"));
    \(immutableRetainedTrigger(table: "retained_phase_lifecycles", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_phase_lifecycle_events", action: "update"));
    \(immutableRetainedTrigger(table: "retained_phase_lifecycle_events", action: "delete"));
    """

    private static let schemaVersion24 = """
    ALTER TABLE audit_events ADD COLUMN event_facts_recorded INTEGER NOT NULL DEFAULT 0
        CHECK (event_facts_recorded IN (0, 1));
    ALTER TABLE audit_events ADD COLUMN event_provenance TEXT
        CHECK (event_provenance IS NULL OR event_provenance IN ('local_audit'));
    ALTER TABLE audit_events ADD COLUMN event_occurred_at TEXT;
    ALTER TABLE audit_events ADD COLUMN event_recorded_at TEXT;
    ALTER TABLE audit_events ADD COLUMN event_project_name TEXT;
    ALTER TABLE audit_events ADD COLUMN event_registration_id TEXT;
    ALTER TABLE audit_events ADD COLUMN event_request_generation INTEGER
        CHECK (event_request_generation IS NULL OR event_request_generation > 0);
    ALTER TABLE audit_events ADD COLUMN event_ticket_id TEXT;
    ALTER TABLE audit_events ADD COLUMN event_phase_id TEXT;
    ALTER TABLE audit_events ADD COLUMN event_phase_name TEXT;
    ALTER TABLE audit_events ADD COLUMN event_ticket_outcome TEXT;
    ALTER TABLE audit_events ADD COLUMN event_previous_lane TEXT
        CHECK (event_previous_lane IS NULL OR event_previous_lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted'));
    ALTER TABLE audit_events ADD COLUMN event_current_lane TEXT
        CHECK (event_current_lane IS NULL OR event_current_lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted'));
    ALTER TABLE audit_events ADD COLUMN event_previous_phase_id TEXT;
    ALTER TABLE audit_events ADD COLUMN event_current_phase_id TEXT;
    """

    // Delivery evidence starts empty. Legacy path and managed-document evidence
    // remain in their existing table with unknown revision provenance.
    private static let schemaVersion25 = """
    CREATE TABLE ticket_delivery_evidence_sets (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        revision INTEGER NOT NULL CHECK (revision > 0),
        current_target_version INTEGER NOT NULL CHECK (current_target_version > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id),
        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE NO ACTION
    );

    CREATE TABLE ticket_delivery_evidence_targets (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        version INTEGER NOT NULL CHECK (version > 0),
        repository_id TEXT NOT NULL CHECK (length(repository_id) = 36 AND repository_id = lower(repository_id)),
        root_id TEXT NOT NULL CHECK (length(CAST(root_id AS BLOB)) BETWEEN 1 AND 256),
        revision_data BLOB NOT NULL,
        expectations_data BLOB NOT NULL,
        registration_id TEXT NOT NULL CHECK (length(CAST(registration_id AS BLOB)) BETWEEN 1 AND 128),
        request_generation INTEGER NOT NULL CHECK (request_generation > 0),
        recorded_at TEXT NOT NULL,
        PRIMARY KEY(project_id, ticket_id, version),
        FOREIGN KEY(project_id, ticket_id)
            REFERENCES ticket_delivery_evidence_sets(project_id, ticket_id) ON DELETE NO ACTION
    );

    CREATE TABLE ticket_delivery_evidence_observations (
        project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        id TEXT NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 256),
        target_version INTEGER NOT NULL CHECK (target_version > 0),
        fact_data BLOB NOT NULL,
        source_data BLOB NOT NULL,
        source_availability TEXT NOT NULL CHECK (source_availability IN ('available', 'unavailable', 'unknown')),
        outcome TEXT NOT NULL CHECK (outcome IN ('observed', 'passed', 'failed', 'skipped', 'unknown')),
        observed_at TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        attachment_evidence_id TEXT,
        supersedes_observation_id TEXT,
        append_revision INTEGER NOT NULL CHECK (append_revision > 0),
        PRIMARY KEY(project_id, ticket_id, id),
        UNIQUE(project_id, ticket_id, append_revision),
        FOREIGN KEY(project_id, ticket_id, target_version)
            REFERENCES ticket_delivery_evidence_targets(project_id, ticket_id, version) ON DELETE NO ACTION,
        CHECK (supersedes_observation_id IS NULL OR supersedes_observation_id <> id)
    );

    CREATE TABLE retained_ticket_delivery_evidence_targets (
        removal_id TEXT NOT NULL REFERENCES removed_projects(removal_id) ON DELETE NO ACTION,
        historical_project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        version INTEGER NOT NULL,
        repository_id TEXT NOT NULL,
        root_id TEXT NOT NULL,
        revision_data BLOB NOT NULL,
        expectations_data BLOB NOT NULL,
        registration_id TEXT NOT NULL,
        request_generation INTEGER NOT NULL,
        recorded_at TEXT NOT NULL,
        evidence_revision INTEGER NOT NULL,
        current_target_version INTEGER NOT NULL,
        PRIMARY KEY(removal_id, historical_project_id, ticket_id, version)
    );

    CREATE TABLE retained_ticket_delivery_evidence_observations (
        removal_id TEXT NOT NULL,
        historical_project_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        id TEXT NOT NULL,
        target_version INTEGER NOT NULL,
        fact_data BLOB NOT NULL,
        source_data BLOB NOT NULL,
        source_availability TEXT NOT NULL,
        outcome TEXT NOT NULL,
        observed_at TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        attachment_evidence_id TEXT,
        supersedes_observation_id TEXT,
        append_revision INTEGER NOT NULL CHECK (append_revision > 0),
        PRIMARY KEY(removal_id, historical_project_id, ticket_id, id),
        UNIQUE(removal_id, historical_project_id, ticket_id, append_revision),
        FOREIGN KEY(removal_id, historical_project_id, ticket_id, target_version)
            REFERENCES retained_ticket_delivery_evidence_targets(
                removal_id, historical_project_id, ticket_id, version
            ) ON DELETE NO ACTION
    );

    \(deliveryEvidenceSetsRejectDeleteTrigger);
    \(deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_targets", action: "update"));
    \(deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_targets", action: "delete"));
    \(deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_observations", action: "update"));
    \(deliveryEvidenceImmutableTrigger(table: "ticket_delivery_evidence_observations", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_targets", action: "update"));
    \(immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_targets", action: "delete"));
    \(immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_observations", action: "update"));
    \(immutableRetainedTrigger(table: "retained_ticket_delivery_evidence_observations", action: "delete"));
    """

    private static let schemaVersion26 = """
    CREATE TABLE workspace_search_preferences (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        payload_version INTEGER NOT NULL CHECK (payload_version > 0),
        payload_data BLOB NOT NULL CHECK (length(payload_data) > 0),
        updated_at TEXT NOT NULL
    );

    CREATE TABLE workspace_saved_queries (
        id TEXT PRIMARY KEY NOT NULL CHECK (length(CAST(id AS BLOB)) BETWEEN 1 AND 128),
        name TEXT NOT NULL CHECK (length(CAST(name AS BLOB)) BETWEEN 1 AND 128),
        payload_version INTEGER NOT NULL CHECK (payload_version > 0),
        payload_data BLOB NOT NULL CHECK (length(payload_data) > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """
}
