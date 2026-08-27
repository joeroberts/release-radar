# SQLite-23 fix-round-1 scoped review package

- Requirements: `/tmp/release-radar-sqlite23-repair-brief.md`
- Implementer report with appended fix round: `/tmp/release-radar-sqlite23-implementer-report.md`
- Previous reviewed package: `/tmp/release-radar-sqlite23-review-package.md`
- Pre-change snapshots: `/tmp/release-radar-sqlite23-pre.ZLUrQy`
- Repository: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
- Scope: current four-file implementation versus exact pre-task snapshots. Compare the previous package only to isolate the fix-round hunks.

## SHA-256 metadata

```text
03955cc2f5f38ab98edf686a6957e49b616dae371fb9963102e70776955ad6e2  /tmp/release-radar-sqlite23-repair-brief.md
2768c7b118d1d3fc0830f934a5d50f7e3ba9dd26ad7598fdec73eedddec01b06  /tmp/release-radar-sqlite23-implementer-report.md
f59b52e0263025718059130a75a20cb23c7dd712d6610bf6e1e85f0c9fa0b260  ReleaseRadarCore/Store/SQLiteConnection.swift
1fc4a7646a275e299e5283b858d5d6ffe3950a2ba20fd60ce158d2735b2a8052  ReleaseRadarTests/StoreAcceptanceTests.swift
5f0b9143b1b032cd444550b5219d77df7d6ad3175735f115b3c00f6bc4ac0792  ReleaseRadarTests/OnboardingAcceptanceTests.swift
b59bb571af0a0277315690973dadbf96e1aae32664bb4bc61b553098352e9e2e  script/build_and_run.sh

```

## ReleaseRadarCore/Store/SQLiteConnection.swift

```diff
--- /tmp/release-radar-sqlite23-pre.ZLUrQy/SQLiteConnection.swift	2026-08-25 15:36:34
+++ ReleaseRadarCore/Store/SQLiteConnection.swift	2026-08-25 16:19:18
@@ -1,6 +1,7 @@
 import Foundation
 import SQLite3
 import Darwin
+import OSLog
 
 public enum SQLiteValue: Equatable, Sendable {
     case integer(Int64)
@@ -68,7 +69,10 @@
         defer { sqlite3_finalize(statement) }
         try bind(bindings, to: statement)
         let result = sqlite3_step(statement)
-        guard result == SQLITE_DONE else { throw currentError(code: result) }
+        guard result == SQLITE_DONE else {
+            recordSQLiteFailure(stage: .step, code: result)
+            throw currentError(code: result)
+        }
     }
 
     public func row(
@@ -84,7 +88,10 @@
         try bind(bindings, to: statement)
         let result = sqlite3_step(statement)
         if result == SQLITE_DONE { return nil }
-        guard result == SQLITE_ROW else { throw currentError(code: result) }
+        guard result == SQLITE_ROW else {
+            recordSQLiteFailure(stage: .step, code: result)
+            throw currentError(code: result)
+        }
 
         var resultRow: [String: SQLiteValue] = [:]
         for index in 0..<sqlite3_column_count(statement) {
@@ -144,17 +151,21 @@
     }
 
     func withTransactionCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
-        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionAuthorizer, nil)
+        let authorizerContext = SQLiteAuthorizerContext(isInTransaction: isInTransaction)
+        let context = Unmanaged.passUnretained(authorizerContext).toOpaque()
+        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionAuthorizer, context)
         guard result == SQLITE_OK else { throw currentError(code: result) }
         defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
-        return try body()
+        return try withExtendedLifetime(authorizerContext) { try body() }
     }
 
     func withReadCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
-        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreReadAuthorizer, nil)
+        let authorizerContext = SQLiteAuthorizerContext(isInTransaction: isInTransaction)
+        let context = Unmanaged.passUnretained(authorizerContext).toOpaque()
+        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreReadAuthorizer, context)
         guard result == SQLITE_OK else { throw currentError(code: result) }
         defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
-        return try body()
+        return try withExtendedLifetime(authorizerContext) { try body() }
     }
 
     var isInTransaction: Bool {
@@ -164,7 +175,10 @@
     private func prepare(_ sql: String) throws -> OpaquePointer {
         var statement: OpaquePointer?
         let result = sqlite3_prepare_v2(databaseHandle, sql, -1, &statement, nil)
-        guard result == SQLITE_OK, let statement else { throw currentError(code: result) }
+        guard result == SQLITE_OK, let statement else {
+            recordSQLiteFailure(stage: .prepare, code: result)
+            throw currentError(code: result)
+        }
         return statement
     }
 
@@ -205,6 +219,21 @@
 
     private func currentError(code: Int32) -> SQLiteError {
         SQLiteError(code: code, message: databaseHandle.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed")
+    }
+
+    private func recordSQLiteFailure(stage: SQLiteDiagnosticStage, code: Int32) {
+        let extendedCode: Int32
+        if let databaseHandle {
+            extendedCode = sqlite3_extended_errcode(databaseHandle)
+        } else {
+            extendedCode = code
+        }
+        SQLiteDiagnostics.recordFailure(
+            stage: stage,
+            code: code,
+            extendedCode: extendedCode,
+            isInTransaction: isInTransaction
+        )
     }
 
     private var databaseHandle: OpaquePointer? {
@@ -216,6 +245,14 @@
     }
 }
 
+private final class SQLiteAuthorizerContext {
+    let isInTransaction: Bool
+
+    init(isInTransaction: Bool) {
+        self.isInTransaction = isInTransaction
+    }
+}
+
 private func deliveryStoreTransactionAuthorizer(
     context: UnsafeMutableRawPointer?,
     action: Int32,
@@ -233,6 +270,12 @@
         triggerName
     )
     guard transactionControlResult == SQLITE_OK else {
+        recordAuthorizerDenial(
+            context: context,
+            action: action,
+            protectedTable: "none",
+            protectedColumn: "none"
+        )
         return transactionControlResult
     }
 
@@ -241,6 +284,15 @@
     let secondName = secondArgument.map { String(cString: $0) }
     if firstName?.caseInsensitiveCompare(protectedTable) == .orderedSame
         || secondName?.caseInsensitiveCompare(protectedTable) == .orderedSame {
+        if action == SQLITE_READ {
+            return SQLITE_OK
+        }
+        recordAuthorizerDenial(
+            context: context,
+            action: action,
+            protectedTable: protectedTable,
+            protectedColumn: sanitizedProtectedColumn(firstName, secondName)
+        )
         return SQLITE_DENY
     }
 
@@ -259,7 +311,7 @@
 }
 
 private func deliveryStoreReadAuthorizer(
-    _: UnsafeMutableRawPointer?,
+    context: UnsafeMutableRawPointer?,
     action: Int32,
     _: UnsafePointer<CChar>?,
     _: UnsafePointer<CChar>?,
@@ -268,12 +320,183 @@
 ) -> Int32 {
     switch action {
     case SQLITE_SELECT, SQLITE_READ, SQLITE_FUNCTION:
-        SQLITE_OK
+        return SQLITE_OK
     default:
-        SQLITE_DENY
+        recordAuthorizerDenial(
+            context: context,
+            action: action,
+            protectedTable: "none",
+            protectedColumn: "none"
+        )
+        return SQLITE_DENY
     }
 }
 
+private func recordAuthorizerDenial(
+    context: UnsafeMutableRawPointer?,
+    action: Int32,
+    protectedTable: String,
+    protectedColumn: String
+) {
+    let isInTransaction = context.map {
+        Unmanaged<SQLiteAuthorizerContext>.fromOpaque($0).takeUnretainedValue().isInTransaction
+    } ?? false
+    SQLiteDiagnostics.recordAuthorizerDenial(
+        action: action,
+        protectedTable: protectedTable,
+        protectedColumn: protectedColumn,
+        isInTransaction: isInTransaction
+    )
+}
+
+private func sanitizedProtectedColumn(_ firstName: String?, _ secondName: String?) -> String {
+    [firstName, secondName].contains {
+        $0?.caseInsensitiveCompare("project_id") == .orderedSame
+    } ? "project_id" : "none"
+}
+
+enum SQLiteDiagnosticStage: String {
+    case authorizer
+    case prepare
+    case step
+}
+
+enum SQLiteDiagnostics {
+    private static let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "SQLite")
+    private static let capture = SQLiteDiagnosticCapture()
+
+    static func resetForTesting() {
+        capture.reset()
+    }
+
+    static func recentPayloadsForTesting() -> [String] {
+        capture.snapshot()
+    }
+
+    static func recordAuthorizerDenial(
+        action: Int32,
+        protectedTable: String,
+        protectedColumn: String,
+        isInTransaction: Bool
+    ) {
+        record(
+            event: "release_radar_sqlite_authorizer_denied",
+            stage: .authorizer,
+            code: SQLITE_AUTH,
+            extendedCode: SQLITE_AUTH,
+            authorizerAction: action,
+            protectedTable: protectedTable,
+            protectedColumn: protectedColumn,
+            isInTransaction: isInTransaction
+        )
+    }
+
+    static func recordFailure(
+        stage: SQLiteDiagnosticStage,
+        code: Int32,
+        extendedCode: Int32,
+        isInTransaction: Bool
+    ) {
+        record(
+            event: "release_radar_sqlite_failure",
+            stage: stage,
+            code: code,
+            extendedCode: extendedCode,
+            authorizerAction: nil,
+            protectedTable: "none",
+            protectedColumn: "none",
+            isInTransaction: isInTransaction
+        )
+    }
+
+    private static func record(
+        event: String,
+        stage: SQLiteDiagnosticStage,
+        code: Int32,
+        extendedCode: Int32,
+        authorizerAction: Int32?,
+        protectedTable: String,
+        protectedColumn: String,
+        isInTransaction: Bool
+    ) {
+        let primaryCode = code & 0xFF
+        let payload = [
+            "event=\(event)",
+            "stage=\(stage.rawValue)",
+            "primary_result=\(primaryCode)",
+            "extended_result=\(extendedCode)",
+            "authorizer_action=\(authorizerAction.map(String.init) ?? "none")",
+            "authorizer_action_name=\(authorizerAction.map(authorizerActionName) ?? "none")",
+            "protected_table=\(protectedTable)",
+            "protected_column=\(protectedColumn)",
+            "in_transaction=\(isInTransaction)",
+        ].joined(separator: " ")
+        logger.error("\(payload, privacy: .public)")
+        capture.append(payload)
+    }
+
+    private static func authorizerActionName(_ action: Int32) -> String {
+        switch action {
+        case SQLITE_CREATE_INDEX: "SQLITE_CREATE_INDEX"
+        case SQLITE_CREATE_TABLE: "SQLITE_CREATE_TABLE"
+        case SQLITE_CREATE_TEMP_INDEX: "SQLITE_CREATE_TEMP_INDEX"
+        case SQLITE_CREATE_TEMP_TABLE: "SQLITE_CREATE_TEMP_TABLE"
+        case SQLITE_CREATE_TEMP_TRIGGER: "SQLITE_CREATE_TEMP_TRIGGER"
+        case SQLITE_CREATE_TEMP_VIEW: "SQLITE_CREATE_TEMP_VIEW"
+        case SQLITE_CREATE_TRIGGER: "SQLITE_CREATE_TRIGGER"
+        case SQLITE_CREATE_VIEW: "SQLITE_CREATE_VIEW"
+        case SQLITE_DELETE: "SQLITE_DELETE"
+        case SQLITE_DROP_INDEX: "SQLITE_DROP_INDEX"
+        case SQLITE_DROP_TABLE: "SQLITE_DROP_TABLE"
+        case SQLITE_DROP_TEMP_INDEX: "SQLITE_DROP_TEMP_INDEX"
+        case SQLITE_DROP_TEMP_TABLE: "SQLITE_DROP_TEMP_TABLE"
+        case SQLITE_DROP_TEMP_TRIGGER: "SQLITE_DROP_TEMP_TRIGGER"
+        case SQLITE_DROP_TEMP_VIEW: "SQLITE_DROP_TEMP_VIEW"
+        case SQLITE_DROP_TRIGGER: "SQLITE_DROP_TRIGGER"
+        case SQLITE_DROP_VIEW: "SQLITE_DROP_VIEW"
+        case SQLITE_INSERT: "SQLITE_INSERT"
+        case SQLITE_PRAGMA: "SQLITE_PRAGMA"
+        case SQLITE_READ: "SQLITE_READ"
+        case SQLITE_SELECT: "SQLITE_SELECT"
+        case SQLITE_TRANSACTION: "SQLITE_TRANSACTION"
+        case SQLITE_UPDATE: "SQLITE_UPDATE"
+        case SQLITE_ATTACH: "SQLITE_ATTACH"
+        case SQLITE_DETACH: "SQLITE_DETACH"
+        case SQLITE_ALTER_TABLE: "SQLITE_ALTER_TABLE"
+        case SQLITE_REINDEX: "SQLITE_REINDEX"
+        case SQLITE_ANALYZE: "SQLITE_ANALYZE"
+        case SQLITE_CREATE_VTABLE: "SQLITE_CREATE_VTABLE"
+        case SQLITE_DROP_VTABLE: "SQLITE_DROP_VTABLE"
+        case SQLITE_FUNCTION: "SQLITE_FUNCTION"
+        case SQLITE_SAVEPOINT: "SQLITE_SAVEPOINT"
+        case SQLITE_RECURSIVE: "SQLITE_RECURSIVE"
+        default: "SQLITE_OTHER"
+        }
+    }
+}
+
+private final class SQLiteDiagnosticCapture: @unchecked Sendable {
+    private let lock = NSLock()
+    private var payloads: [String] = []
+
+    func reset() {
+        lock.withLock { payloads.removeAll() }
+    }
+
+    func append(_ payload: String) {
+        lock.withLock {
+            payloads.append(payload)
+            if payloads.count > 32 {
+                payloads.removeFirst(payloads.count - 32)
+            }
+        }
+    }
+
+    func snapshot() -> [String] {
+        lock.withLock { payloads }
+    }
+}
+
 enum SQLiteConnectionAccess {
     case transaction
     case readOnly

```

## ReleaseRadarTests/StoreAcceptanceTests.swift

```diff
--- /tmp/release-radar-sqlite23-pre.ZLUrQy/StoreAcceptanceTests.swift	2026-08-25 15:36:34
+++ ReleaseRadarTests/StoreAcceptanceTests.swift	2026-08-25 15:48:13
@@ -373,8 +373,148 @@
         }
         XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
         XCTAssertEqual(state.1, 1)
+    }
+
+    func testCallbackAuditMutationMatrixRemainsDeniedAndRollsBackSiblingWrites() async throws {
+        let mutations = [
+            "INSERT INTO audit_events (id, actor_id, reason, created_at) VALUES ('forbidden-insert', 'forbidden', 'Forbidden insert', '2026-08-25T12:00:00Z')",
+            "UPDATE audit_events SET reason = 'Forbidden update'",
+            "DELETE FROM audit_events",
+        ]
+
+        for mutation in mutations {
+            let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+            try await seedProject(store)
+
+            let caughtError: Error
+            do {
+                try await store.transact(actor: .init(id: "agent-audit-matrix"), reason: "Forbidden audit callback mutation") { connection in
+                    try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+                    try connection.execute(mutation)
+                }
+                XCTFail("Expected callback audit mutation to be denied: \(mutation)")
+                continue
+            } catch {
+                caughtError = error
+            }
+
+            let sqliteError = try XCTUnwrap(caughtError as? SQLiteError)
+            XCTAssertEqual(sqliteError.code, 23)
+            let state = try await store.read { connection in
+                (
+                    try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
+                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-audit-matrix'")
+                )
+            }
+            XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+            XCTAssertEqual(state.1, 1)
+            XCTAssertEqual(state.2, 0)
+        }
+    }
+
+    func testCallbackProjectDeleteCannotIndirectlyMutateScopedAuditEvent() async throws {
+        let databaseURL = try makeDatabaseURL()
+        let store = DeliveryStore(databaseURL: databaseURL)
+        let projectID = ProjectID(rawValue: "project-scoped-audit")
+        try await store.transact(
+            actor: .init(id: "fixture"),
+            reason: "Seed scoped audit fixture",
+            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
+        ) { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-scoped-audit', 'Scoped audit project')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-scoped-audit', 'project-scoped-audit', 'Scoped phase')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('SCOPED-01', 'project-scoped-audit', 'phase-scoped-audit', 'Scoped child', 'backlog')")
+        }
+        let before = try await store.read { connection in
+            (
+                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-scoped-audit'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'SCOPED-01'"),
+                try connection.row("SELECT project_id, entity_type, entity_id FROM audit_events WHERE reason = 'Seed scoped audit fixture'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        let foreignKeyCheckBefore = try SQLiteConnection(url: databaseURL)
+            .scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_check")
+
+        let caughtError: Error
+        do {
+            try await store.transact(actor: .init(id: "agent-delete"), reason: "Delete scoped audit project") { connection in
+                try connection.execute("DELETE FROM projects WHERE id = 'project-scoped-audit'")
+            }
+            XCTFail("Expected foreign-key audit set-null mutation to be denied")
+            return
+        } catch {
+            caughtError = error
+        }
+
+        let sqliteError = try XCTUnwrap(caughtError as? SQLiteError)
+        XCTAssertEqual(sqliteError.code, 23)
+        let after = try await store.read { connection in
+            (
+                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = 'project-scoped-audit'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'SCOPED-01'"),
+                try connection.row("SELECT project_id, entity_type, entity_id FROM audit_events WHERE reason = 'Seed scoped audit fixture'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        let foreignKeyCheckAfter = try SQLiteConnection(url: databaseURL)
+            .scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_check")
+        XCTAssertEqual(after.0, before.0)
+        XCTAssertEqual(after.1, before.1)
+        XCTAssertEqual(after.2, before.2)
+        XCTAssertEqual(after.3, before.3)
+        XCTAssertEqual(foreignKeyCheckBefore, 0)
+        XCTAssertEqual(foreignKeyCheckAfter, 0)
     }
 
+    func testSQLiteDiagnosticsAllowlistAuthorizerAndPrepareFailureFields() async throws {
+        SQLiteDiagnostics.resetForTesting()
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        let projectID = ProjectID(rawValue: "diagnostic-project-id")
+        try await store.transact(
+            actor: .init(id: "diagnostic-owner-id"),
+            reason: "diagnostic-secret-reason",
+            auditScope: .init(projectID: projectID, entityType: .project, entityID: "diagnostic-entity-id")
+        ) { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('diagnostic-project-id', 'diagnostic-project-name')")
+        }
+        SQLiteDiagnostics.resetForTesting()
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "diagnostic-owner-id"), reason: "diagnostic-secret-reason") { connection in
+                try connection.execute("UPDATE audit_events SET project_id = 'diagnostic-project-id' WHERE reason = 'diagnostic-secret-reason'")
+            }
+        }
+
+        let payloads = SQLiteDiagnostics.recentPayloadsForTesting()
+        let authorizerPayload = try XCTUnwrap(payloads.first { $0.contains("event=release_radar_sqlite_authorizer_denied") })
+        let preparePayload = try XCTUnwrap(payloads.first { $0.contains("event=release_radar_sqlite_failure stage=prepare") })
+        XCTAssertTrue(authorizerPayload.contains("primary_result=23"))
+        XCTAssertTrue(authorizerPayload.contains("authorizer_action=23"))
+        XCTAssertTrue(authorizerPayload.contains("authorizer_action_name=SQLITE_UPDATE"))
+        XCTAssertTrue(authorizerPayload.contains("protected_table=audit_events"))
+        XCTAssertTrue(authorizerPayload.contains("protected_column=project_id"))
+        XCTAssertTrue(authorizerPayload.contains("in_transaction=true"))
+        XCTAssertTrue(preparePayload.contains("primary_result=23"))
+        XCTAssertTrue(preparePayload.contains("authorizer_action=none"))
+        XCTAssertTrue(preparePayload.contains("protected_table=none"))
+        XCTAssertTrue(preparePayload.contains("protected_column=none"))
+        XCTAssertTrue(preparePayload.contains("in_transaction=true"))
+
+        let combinedPayloads = payloads.joined(separator: "\n")
+        for prohibitedValue in [
+            "diagnostic-owner-id",
+            "diagnostic-secret-reason",
+            "diagnostic-project-id",
+            "diagnostic-entity-id",
+            "diagnostic-project-name",
+            "UPDATE audit_events",
+        ] {
+            XCTAssertFalse(combinedPayloads.contains(prohibitedValue))
+        }
+    }
+
     func testActivePhaseMustBelongToTheSameProject() async throws {
         let store = DeliveryStore(databaseURL: try makeDatabaseURL())
         try await store.transact(actor: .init(id: "seed"), reason: "Seed active phase integrity") { connection in

```

## ReleaseRadarTests/OnboardingAcceptanceTests.swift

```diff
--- /tmp/release-radar-sqlite23-pre.ZLUrQy/OnboardingAcceptanceTests.swift	2026-08-25 15:36:34
+++ ReleaseRadarTests/OnboardingAcceptanceTests.swift	2026-08-25 16:18:58
@@ -4,6 +4,189 @@
 @testable import ReleaseRadarCore
 
 final class OnboardingAcceptanceTests: XCTestCase {
+    func testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation() async throws {
+        let fixture = try FolderFixture()
+        let sentinelURL = fixture.root.appendingPathComponent("owner-sentinel.txt")
+        let sentinel = Data("synthetic repository content".utf8)
+        try sentinel.write(to: sentinelURL)
+        let listingBefore = try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted()
+        let unrelatedProjectID = ProjectID(rawValue: "existing-project")
+
+        do {
+            let initialStore = DeliveryStore(databaseURL: fixture.databaseURL)
+            let initialAvailability = await initialStore.availability
+            XCTAssertEqual(initialAvailability, .available)
+            try await initialStore.transact(
+                actor: .init(id: "fixture-existing"),
+                reason: "Seed existing durable state",
+                auditScope: .init(
+                    projectID: unrelatedProjectID,
+                    entityType: .project,
+                    entityID: unrelatedProjectID.rawValue
+                )
+            ) { connection in
+                try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('existing-project', 'Existing Project', 1)")
+                try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('existing-phase', 'existing-project', 'Existing Phase')")
+                try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('existing-project', 'existing-phase')")
+                try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('EXISTING-01', 'existing-project', 'existing-phase', 'Existing ticket', 'in_progress')")
+                try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('existing-blocker', 'existing-project', 'EXISTING-01', 'Existing child')")
+            }
+        }
+        var legacyConnection: SQLiteConnection? = try SQLiteConnection(url: fixture.databaseURL)
+        try legacyConnection?.executeScript("""
+        ALTER TABLE projects ADD COLUMN active_phase_id TEXT;
+        CREATE INDEX projects_active_phase_index ON projects(active_phase_id);
+        CREATE TRIGGER validate_project_active_phase_insert
+        BEFORE INSERT ON projects
+        WHEN NEW.active_phase_id IS NOT NULL AND NOT EXISTS (
+            SELECT 1 FROM phases
+            WHERE phases.id = NEW.active_phase_id AND phases.project_id = NEW.id
+        )
+        BEGIN
+            SELECT RAISE(ABORT, 'active phase must belong to project');
+        END;
+        CREATE TRIGGER validate_project_active_phase_update
+        BEFORE UPDATE OF id, active_phase_id ON projects
+        WHEN NEW.active_phase_id IS NOT NULL AND NOT EXISTS (
+            SELECT 1 FROM phases
+            WHERE phases.id = NEW.active_phase_id AND phases.project_id = NEW.id
+        )
+        BEGIN
+            SELECT RAISE(ABORT, 'active phase must belong to project');
+        END;
+        UPDATE projects SET active_phase_id = 'existing-phase' WHERE id = 'existing-project';
+        """)
+        legacyConnection = nil
+
+        let store = DeliveryStore(databaseURL: fixture.databaseURL)
+        let availability = await store.availability
+        XCTAssertEqual(availability, .available)
+        let version = try SQLiteConnection(url: fixture.databaseURL).scalarInt("PRAGMA user_version")
+        XCTAssertEqual(version, 9)
+        let populatedBefore = try await populatedLegacyFixtureSnapshot(store: store)
+        XCTAssertEqual(populatedBefore["project"]?["name"], .text("Existing Project"))
+        XCTAssertEqual(populatedBefore["project"]?["active_phase_id"], .text("existing-phase"))
+        XCTAssertEqual(populatedBefore["phase"]?["name"], .text("Existing Phase"))
+        XCTAssertEqual(populatedBefore["activePhase"]?["phase_id"], .text("existing-phase"))
+        XCTAssertEqual(populatedBefore["ticket"]?["lane"], .text("in_progress"))
+        XCTAssertEqual(populatedBefore["blocker"]?["summary"], .text("Existing child"))
+        XCTAssertEqual(populatedBefore["audit"]?["project_id"], .text(unrelatedProjectID.rawValue))
+        XCTAssertEqual(populatedBefore["counts"]?["projects"], .integer(1))
+        XCTAssertEqual(populatedBefore["counts"]?["audit_events"], .integer(1))
+        let onboarding = FolderProjectOnboarding(
+            store: store,
+            bookmarkStore: fixture.bookmarks,
+            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
+        )
+
+        let preview = try await onboarding.inspect(folder: fixture.root)
+        let projectID = try await onboarding.prepare(.init(
+            preview: preview,
+            projectName: "Fixture Project"
+        ))
+        let rootPath = fixture.root.path
+        let persisted = try await store.read { connection in
+            (
+                try connection.scalarInt("SELECT COUNT(*) FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)]),
+                try connection.scalarInt("SELECT COUNT(*) FROM project_roots WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(rootPath)]),
+                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ? AND path = ? AND is_stale = 0", bindings: [.text(projectID.rawValue), .text(rootPath)]),
+                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_pending' AND status = 'open'", bindings: [.text(projectID.rawValue)]),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-onboarding' AND reason = 'Prepare folder-backed project onboarding'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE project_id = ? AND kind = 'onboarding_phase_request'", bindings: [.text(projectID.rawValue)]),
+                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
+                try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
+                try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
+                try connection.row(
+                    "SELECT actor_id, reason, project_id, entity_type, entity_id FROM audit_events WHERE actor_id = 'release-radar-onboarding' AND reason = 'Prepare folder-backed project onboarding'"
+                )
+            )
+        }
+        let rawConnection = try SQLiteConnection(url: fixture.databaseURL)
+        let foreignKeys = try rawConnection.scalarInt("PRAGMA foreign_keys")
+        let foreignKeyCheck = try rawConnection.scalarInt("SELECT COUNT(*) FROM pragma_foreign_key_check")
+        XCTAssertEqual(persisted.0, 1)
+        XCTAssertEqual(persisted.1, 1)
+        XCTAssertEqual(persisted.2, 1)
+        XCTAssertEqual(persisted.3, 1)
+        XCTAssertEqual(persisted.4, 1)
+        XCTAssertEqual(persisted.5, 0)
+        XCTAssertEqual(persisted.6, 0)
+        XCTAssertEqual(persisted.7, 0)
+        XCTAssertEqual(persisted.8, 0)
+        XCTAssertEqual(persisted.9, 0)
+        XCTAssertEqual(persisted.10?["actor_id"], .text("release-radar-onboarding"))
+        XCTAssertEqual(persisted.10?["reason"], .text("Prepare folder-backed project onboarding"))
+        XCTAssertEqual(foreignKeys, 1)
+        XCTAssertEqual(foreignKeyCheck, 0)
+        let populatedAfter = try await populatedLegacyFixtureSnapshot(store: store)
+        var preexistingRows = populatedBefore
+        let countsBefore = try XCTUnwrap(preexistingRows.removeValue(forKey: "counts"))
+        var preservedRows = populatedAfter
+        let countsAfter = try XCTUnwrap(preservedRows.removeValue(forKey: "counts"))
+        XCTAssertEqual(preservedRows, preexistingRows)
+        guard case let .integer(projectsBefore)? = countsBefore["projects"],
+              case let .integer(auditsBefore)? = countsBefore["audit_events"]
+        else {
+            return XCTFail("Synthetic populated fixture counts were not integers")
+        }
+        XCTAssertEqual(countsAfter["projects"], .integer(projectsBefore + 1))
+        XCTAssertEqual(countsAfter["audit_events"], .integer(auditsBefore + 1))
+        XCTAssertEqual(countsAfter["phases"], countsBefore["phases"])
+        XCTAssertEqual(countsAfter["project_active_phases"], countsBefore["project_active_phases"])
+        XCTAssertEqual(countsAfter["tickets"], countsBefore["tickets"])
+        XCTAssertEqual(countsAfter["blockers"], countsBefore["blockers"])
+        XCTAssertEqual(try Data(contentsOf: sentinelURL), sentinel)
+        XCTAssertEqual(try FileManager.default.subpathsOfDirectory(atPath: fixture.root.path).sorted(), listingBefore)
+
+        let relaunched = FolderProjectOnboarding(
+            store: DeliveryStore(databaseURL: fixture.databaseURL),
+            bookmarkStore: fixture.bookmarks,
+            worktreeDiscovery: FixtureWorktreeDiscovery(worktrees: [fixture.root])
+        )
+        let resumed = try await relaunched.inspect(folder: fixture.root)
+        XCTAssertEqual(resumed.pendingProjectID, projectID)
+        XCTAssertNil(resumed.completedProjectID)
+        let authorizedRoot = try await relaunched.withAuthorizedProject(projectID: projectID) { project in
+            project.canonicalRoot
+        }
+        XCTAssertEqual(authorizedRoot, fixture.root)
+        XCTAssertEqual(fixture.bookmarks.accessStarts, fixture.bookmarks.accessStops)
+    }
+
+    private func populatedLegacyFixtureSnapshot(
+        store: DeliveryStore
+    ) async throws -> [String: [String: SQLiteValue]] {
+        try await store.read { connection in
+            guard
+                let project = try connection.row("SELECT id, name, first_dashboard_opened, active_phase_id FROM projects WHERE id = 'existing-project'"),
+                let phase = try connection.row("SELECT * FROM phases WHERE id = 'existing-phase'"),
+                let activePhase = try connection.row("SELECT project_id, phase_id FROM project_active_phases WHERE project_id = 'existing-project'"),
+                let ticket = try connection.row("SELECT id, project_id, phase_id, outcome, lane FROM tickets WHERE id = 'EXISTING-01'"),
+                let blocker = try connection.row("SELECT id, project_id, ticket_id, summary FROM blockers WHERE id = 'existing-blocker'"),
+                let audit = try connection.row("SELECT * FROM audit_events WHERE project_id = 'existing-project'")
+            else {
+                throw SQLiteError(code: 1, message: "Synthetic populated legacy fixture was not seeded")
+            }
+            return [
+                "project": project,
+                "phase": phase,
+                "activePhase": activePhase,
+                "ticket": ticket,
+                "blocker": blocker,
+                "audit": audit,
+                "counts": [
+                    "projects": .integer(try connection.scalarInt("SELECT COUNT(*) FROM projects") ?? -1),
+                    "phases": .integer(try connection.scalarInt("SELECT COUNT(*) FROM phases") ?? -1),
+                    "project_active_phases": .integer(try connection.scalarInt("SELECT COUNT(*) FROM project_active_phases") ?? -1),
+                    "tickets": .integer(try connection.scalarInt("SELECT COUNT(*) FROM tickets") ?? -1),
+                    "blockers": .integer(try connection.scalarInt("SELECT COUNT(*) FROM blockers") ?? -1),
+                    "audit_events": .integer(try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1),
+                ],
+            ]
+        }
+    }
+
     func testInitializePreviewAbandonedBeforeConfirmationLeavesStoreAndRepositoryUnchanged() async throws {
         let fixture = try FolderFixture()
         let sentinelURL = fixture.root.appendingPathComponent("owner-sentinel.txt")

```

## script/build_and_run.sh

```diff
--- /tmp/release-radar-sqlite23-pre.ZLUrQy/build_and_run.sh	2026-08-25 15:36:34
+++ script/build_and_run.sh	2026-08-25 16:23:56
@@ -1,49 +1,470 @@
 #!/usr/bin/env bash
 set -euo pipefail
 
-MODE="${1:-run}"
+MODE="${1:-stage-release-no-launch}"
 APP_NAME="ReleaseRadar"
 BUNDLE_ID="com.rekonlabs.ReleaseRadar"
+TEAM_ID="2UA854NLX4"
+APP_GROUP="2UA854NLX4.com.rekonlabs.ReleaseRadar"
+SIGNING_AUTHORITY="Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"
 ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 DERIVED_DATA="$ROOT_DIR/DerivedData"
-APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
-APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
+BUILD_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
+BUILD_BINARY="$BUILD_BUNDLE/Contents/MacOS/$APP_NAME"
+DIST_DIR="$ROOT_DIR/dist"
+STAGED_BUNDLE="$DIST_DIR/$APP_NAME.app"
+INSTALLED_BUNDLE="/Applications/$APP_NAME.app"
 
-pkill -x "$APP_NAME" >/dev/null 2>&1 || true
+report_error() {
+    printf 'error: %s\n' "$*" >&2
+}
 
-xcodebuild \
-    -project "$ROOT_DIR/ReleaseRadar.xcodeproj" \
-    -scheme ReleaseRadar \
-    -configuration Debug \
-    -derivedDataPath "$DERIVED_DATA" \
-    build
+require_value() {
+    local actual="$1"
+    local expected="$2"
+    local description="$3"
+    if [[ "$actual" != "$expected" ]]; then
+        report_error "$description was '$actual', expected '$expected'"
+        return 1
+    fi
+}
 
-open_app() {
-    /usr/bin/open -n "$APP_BUNDLE"
+signing_metadata() {
+    codesign -dvvv "$1" 2>&1
 }
 
+verify_signed_code() {
+    local code_path="$1"
+    local metadata
+
+    if [[ ! -e "$code_path" ]]; then
+        report_error "missing signed code at $code_path"
+        return 1
+    fi
+    if ! codesign --verify --strict --verbose=2 "$code_path"; then
+        report_error "strict signature verification failed for $code_path"
+        return 1
+    fi
+    if ! metadata="$(signing_metadata "$code_path")"; then
+        report_error "could not inspect signing metadata for $code_path"
+        return 1
+    fi
+    if ! grep -Fxq "Authority=$SIGNING_AUTHORITY" <<<"$metadata"; then
+        report_error "configured signing authority mismatch for $code_path"
+        return 1
+    fi
+    if ! grep -Fxq "TeamIdentifier=$TEAM_ID" <<<"$metadata"; then
+        report_error "team identifier mismatch for $code_path"
+        return 1
+    fi
+    return 0
+}
+
+verify_hardened_runtime() {
+    local code_path="$1"
+    local metadata
+
+    if ! metadata="$(signing_metadata "$code_path")"; then
+        report_error "could not inspect signing metadata for $code_path"
+        return 1
+    fi
+    if ! grep -Eq 'flags=.*runtime' <<<"$metadata"; then
+        report_error "Hardened Runtime missing for $code_path"
+        return 1
+    fi
+    return 0
+}
+
+entitlements_for() {
+    codesign -dvvv --entitlements :- "$1" 2>/dev/null
+}
+
+canonicalize_entitlements() {
+    plutil -convert xml1 -o - -
+}
+
+expected_main_entitlements() {
+    printf '%s\n' \
+        '<?xml version="1.0" encoding="UTF-8"?>' \
+        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
+        '<plist version="1.0">' \
+        '<dict>' \
+        '<key>com.apple.security.app-sandbox</key>' \
+        '<true/>' \
+        '<key>com.apple.security.application-groups</key>' \
+        '<array>' \
+        "<string>$APP_GROUP</string>" \
+        '</array>' \
+        '<key>com.apple.security.files.user-selected.read-only</key>' \
+        '<true/>' \
+        '<key>com.apple.security.network.client</key>' \
+        '<true/>' \
+        '</dict>' \
+        '</plist>'
+}
+
+expected_bridge_entitlements() {
+    printf '%s\n' \
+        '<?xml version="1.0" encoding="UTF-8"?>' \
+        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
+        '<plist version="1.0">' \
+        '<dict>' \
+        '<key>com.apple.security.app-sandbox</key>' \
+        '<true/>' \
+        '<key>com.apple.security.application-groups</key>' \
+        '<array>' \
+        "<string>$APP_GROUP</string>" \
+        '</array>' \
+        '</dict>' \
+        '</plist>'
+}
+
+assert_exact_entitlements() {
+    local code_path="$1"
+    local entitlement_description="$2"
+    local expected_entitlements="$3"
+    local entitlements
+    local actual_canonical
+    local expected_canonical
+
+    if ! entitlements="$(entitlements_for "$code_path")" || [[ -z "$entitlements" ]]; then
+        report_error "missing entitlements for $code_path"
+        return 1
+    fi
+    if ! actual_canonical="$(printf '%s' "$entitlements" | canonicalize_entitlements)"; then
+        report_error "could not parse $entitlement_description entitlements for $code_path"
+        return 1
+    fi
+    if ! expected_canonical="$(printf '%s' "$expected_entitlements" | canonicalize_entitlements)"; then
+        report_error "could not construct expected $entitlement_description entitlements"
+        return 1
+    fi
+    if [[ "$actual_canonical" != "$expected_canonical" ]]; then
+        report_error "$entitlement_description entitlements differ from the exact approved structure for $code_path"
+        return 1
+    fi
+    return 0
+}
+
+assert_main_entitlements() {
+    local code_path="$1"
+    if ! assert_exact_entitlements "$code_path" "main app" "$(expected_main_entitlements)"; then
+        return 1
+    fi
+    return 0
+}
+
+assert_bridge_entitlements() {
+    local code_path="$1"
+    if ! assert_exact_entitlements "$code_path" "Bridge Agent" "$(expected_bridge_entitlements)"; then
+        return 1
+    fi
+    return 0
+}
+
+bundle_identifier() {
+    plutil -extract CFBundleIdentifier raw "$1/Contents/Info.plist"
+}
+
+bundle_version() {
+    plutil -extract CFBundleShortVersionString raw "$1/Contents/Info.plist"
+}
+
+bundle_build() {
+    plutil -extract CFBundleVersion raw "$1/Contents/Info.plist"
+}
+
+bundle_cdhash() {
+    signing_metadata "$1" | /usr/bin/sed -nE 's/^CDHash=//p' | head -n 1
+}
+
+bundle_executable_sha256() {
+    shasum -a 256 "$1/Contents/MacOS/$APP_NAME" | /usr/bin/awk '{ print $1 }'
+}
+
+bundle_resource_manifest_sha256() {
+    shasum -a 256 "$1/Contents/_CodeSignature/CodeResources" | /usr/bin/awk '{ print $1 }'
+}
+
+verify_bundle() {
+    local bundle="$1"
+    local bridge_agent="$bundle/Contents/Resources/ReleaseRadarBridgeAgent"
+    local executable
+    local framework
+
+    if [[ ! -d "$bundle" ]]; then
+        report_error "missing bundle at $bundle"
+        return 1
+    fi
+    if [[ ! -f "$bundle/Contents/Info.plist" ]]; then
+        report_error "missing Info.plist in $bundle"
+        return 1
+    fi
+    if [[ ! -x "$bundle/Contents/MacOS/$APP_NAME" ]]; then
+        report_error "missing main executable in $bundle"
+        return 1
+    fi
+    if [[ ! -f "$bundle/Contents/_CodeSignature/CodeResources" ]]; then
+        report_error "missing signed resource manifest in $bundle"
+        return 1
+    fi
+
+    if ! codesign --verify --deep --strict --verbose=2 "$bundle"; then
+        report_error "strict bundle verification failed for $bundle"
+        return 1
+    fi
+    if ! signing_metadata "$bundle" >/dev/null; then
+        report_error "could not inspect signing metadata for $bundle"
+        return 1
+    fi
+    if ! require_value "$(bundle_identifier "$bundle")" "$BUNDLE_ID" "bundle identifier"; then return 1; fi
+    if [[ -z "$(bundle_version "$bundle")" ]]; then report_error "missing bundle version"; return 1; fi
+    if [[ -z "$(bundle_build "$bundle")" ]]; then report_error "missing bundle build"; return 1; fi
+    if [[ -z "$(bundle_cdhash "$bundle")" ]]; then report_error "missing CodeDirectory hash"; return 1; fi
+
+    if ! verify_signed_code "$bundle"; then return 1; fi
+    if ! verify_hardened_runtime "$bundle"; then return 1; fi
+    if ! assert_main_entitlements "$bundle"; then return 1; fi
+
+    if ! verify_signed_code "$bridge_agent"; then return 1; fi
+    if ! verify_hardened_runtime "$bridge_agent"; then return 1; fi
+    if ! assert_bridge_entitlements "$bridge_agent"; then return 1; fi
+
+    while IFS= read -r -d '' executable; do
+        if ! verify_signed_code "$executable"; then return 1; fi
+    done < <(/usr/bin/find "$bundle/Contents" -type f -perm +111 -print0)
+    if [[ -d "$bundle/Contents/Frameworks" ]]; then
+        while IFS= read -r -d '' framework; do
+            if ! verify_signed_code "$framework"; then return 1; fi
+        done < <(/usr/bin/find "$bundle/Contents/Frameworks" -type d -name '*.framework' -print0)
+    fi
+    return 0
+}
+
+bundle_identity() {
+    local bundle="$1"
+
+    local cdhash
+    local identifier
+    local version
+    local build
+    local executable_hash
+    local resource_hash
+
+    if ! cdhash="$(bundle_cdhash "$bundle")" || [[ -z "$cdhash" ]]; then return 1; fi
+    if ! identifier="$(bundle_identifier "$bundle")" || [[ -z "$identifier" ]]; then return 1; fi
+    if ! version="$(bundle_version "$bundle")" || [[ -z "$version" ]]; then return 1; fi
+    if ! build="$(bundle_build "$bundle")" || [[ -z "$build" ]]; then return 1; fi
+    if ! executable_hash="$(bundle_executable_sha256 "$bundle")" || [[ -z "$executable_hash" ]]; then return 1; fi
+    if ! resource_hash="$(bundle_resource_manifest_sha256 "$bundle")" || [[ -z "$resource_hash" ]]; then return 1; fi
+    printf '%s\n' "$cdhash" "$identifier" "$version" "$build" "$executable_hash" "$resource_hash"
+}
+
+require_matching_bundle_identity() {
+    local source_bundle="$1"
+    local copied_bundle="$2"
+
+    local source_identity
+    local copied_identity
+
+    if ! source_identity="$(bundle_identity "$source_bundle")"; then
+        report_error "could not determine source bundle identity for $source_bundle"
+        return 1
+    fi
+    if ! copied_identity="$(bundle_identity "$copied_bundle")"; then
+        report_error "could not determine copied bundle identity for $copied_bundle"
+        return 1
+    fi
+    if [[ "$source_identity" != "$copied_identity" ]]; then
+        report_error "bundle identity mismatch between $source_bundle and $copied_bundle"
+        return 1
+    fi
+}
+
+recover_failed_promotion() {
+    local final_bundle="$1"
+    local backup_bundle="$2"
+    local had_backup="$3"
+    local failed_bundle="$4"
+
+    if [[ -e "$final_bundle" ]]; then
+        if ! mv "$final_bundle" "$failed_bundle"; then
+            report_error "failed final remains at $final_bundle; prior bundle remains at $backup_bundle"
+            return 1
+        fi
+    fi
+    if [[ "$had_backup" == true ]]; then
+        if ! mv "$backup_bundle" "$final_bundle"; then
+            report_error "rollback restoration failed; failed bundle is at $failed_bundle and prior bundle remains at $backup_bundle"
+            return 1
+        fi
+    fi
+    return 0
+}
+
+promote_verified_bundle() {
+    local candidate="$1"
+    local final_bundle="$2"
+    local expected_identity="${3:-}"
+    local final_parent
+    local backup_bundle
+    local failed_bundle
+    local final_identity
+    local had_backup=false
+
+    final_parent="$(dirname "$final_bundle")"
+    backup_bundle="$final_parent/.${APP_NAME}.backup.$$.$RANDOM"
+    failed_bundle="$final_parent/.${APP_NAME}.failed.$$.$RANDOM"
+    if [[ ! -d "$candidate" ]]; then
+        report_error "candidate bundle missing at $candidate"
+        return 1
+    fi
+    if ! verify_bundle "$candidate"; then
+        report_error "candidate bundle failed verification at $candidate"
+        return 1
+    fi
+    if [[ -z "$expected_identity" ]]; then
+        if ! expected_identity="$(bundle_identity "$candidate")"; then
+            report_error "could not determine candidate bundle identity for $candidate"
+            return 1
+        fi
+    fi
+
+    if [[ -e "$final_bundle" ]]; then
+        if ! verify_bundle "$final_bundle"; then
+            report_error "prior final bundle failed verification at $final_bundle; refusing replacement"
+            return 1
+        fi
+        if ! mv "$final_bundle" "$backup_bundle"; then
+            report_error "could not preserve prior bundle at $final_bundle"
+            return 1
+        fi
+        had_backup=true
+    fi
+
+    if ! mv "$candidate" "$final_bundle"; then
+        report_error "promotion failed; candidate remains at $candidate"
+        if [[ "$had_backup" == true ]] && ! mv "$backup_bundle" "$final_bundle"; then
+            report_error "rollback failed; prior bundle remains at $backup_bundle"
+        fi
+        return 1
+    fi
+
+    if ! verify_bundle "$final_bundle"; then
+        report_error "promoted candidate failed verification at $final_bundle"
+        recover_failed_promotion "$final_bundle" "$backup_bundle" "$had_backup" "$failed_bundle" || true
+        return 1
+    fi
+    if ! final_identity="$(bundle_identity "$final_bundle")"; then
+        report_error "could not determine promoted bundle identity at $final_bundle"
+        recover_failed_promotion "$final_bundle" "$backup_bundle" "$had_backup" "$failed_bundle" || true
+        return 1
+    fi
+    if [[ "$expected_identity" != "$final_identity" ]]; then
+        report_error "bundle identity mismatch after promotion at $final_bundle"
+        recover_failed_promotion "$final_bundle" "$backup_bundle" "$had_backup" "$failed_bundle" || true
+        return 1
+    fi
+    if [[ "$had_backup" == true ]] && ! /bin/rm -rf "$backup_bundle"; then
+        report_error "final bundle verified but prior backup cleanup failed at $backup_bundle"
+        return 1
+    fi
+    return 0
+}
+
+build_release() {
+    if ! xcodebuild \
+        -project "$ROOT_DIR/ReleaseRadar.xcodeproj" \
+        -scheme ReleaseRadar \
+        -configuration Release \
+        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
+        -derivedDataPath "$DERIVED_DATA" \
+        build; then
+        return 1
+    fi
+    verify_bundle "$BUILD_BUNDLE"
+}
+
+stage_release_no_launch() {
+    local temporary_directory
+    local candidate_bundle
+
+    local source_identity
+
+    if ! build_release; then return 1; fi
+    if ! mkdir -p "$DIST_DIR"; then report_error "could not create $DIST_DIR"; return 1; fi
+    if ! temporary_directory="$(mktemp -d "$DIST_DIR/.${APP_NAME}.stage.XXXXXX")"; then report_error "could not create stage temporary directory"; return 1; fi
+    candidate_bundle="$temporary_directory/$APP_NAME.app"
+    if ! ditto "$BUILD_BUNDLE" "$candidate_bundle"; then report_error "could not copy Release bundle into stage candidate"; return 1; fi
+    if ! verify_bundle "$candidate_bundle"; then return 1; fi
+    if ! source_identity="$(bundle_identity "$BUILD_BUNDLE")"; then report_error "could not determine build bundle identity"; return 1; fi
+    if ! require_matching_bundle_identity "$BUILD_BUNDLE" "$candidate_bundle"; then return 1; fi
+    if ! promote_verified_bundle "$candidate_bundle" "$STAGED_BUNDLE" "$source_identity"; then return 1; fi
+    if ! rmdir "$temporary_directory"; then report_error "could not remove empty stage temporary directory $temporary_directory"; return 1; fi
+    echo "staged verified Release bundle at $STAGED_BUNDLE"
+}
+
+install_staged_release_no_launch() {
+    local temporary_directory
+    local candidate_bundle
+
+    local source_identity
+
+    if ! verify_bundle "$STAGED_BUNDLE"; then return 1; fi
+    if ! temporary_directory="$(mktemp -d "/Applications/.${APP_NAME}.install.XXXXXX")"; then report_error "could not create install temporary directory"; return 1; fi
+    candidate_bundle="$temporary_directory/$APP_NAME.app"
+    if ! ditto "$STAGED_BUNDLE" "$candidate_bundle"; then report_error "could not copy staged bundle into install candidate"; return 1; fi
+    if ! verify_bundle "$candidate_bundle"; then return 1; fi
+    if ! source_identity="$(bundle_identity "$STAGED_BUNDLE")"; then report_error "could not determine staged bundle identity"; return 1; fi
+    if ! require_matching_bundle_identity "$STAGED_BUNDLE" "$candidate_bundle"; then return 1; fi
+    if ! promote_verified_bundle "$candidate_bundle" "$INSTALLED_BUNDLE" "$source_identity"; then return 1; fi
+    if ! rmdir "$temporary_directory"; then report_error "could not remove empty install temporary directory $temporary_directory"; return 1; fi
+    echo "installed verified staged Release bundle at $INSTALLED_BUNDLE"
+}
+
+stop_running_app_for_explicit_launch() {
+    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
+}
+
+open_app_for_explicit_launch() {
+    stop_running_app_for_explicit_launch
+    /usr/bin/open -n "$BUILD_BUNDLE"
+}
+
 case "$MODE" in
+    stage-release-no-launch|--stage-release-no-launch)
+        stage_release_no_launch
+        ;;
+    install-staged-release-no-launch|--install-staged-release-no-launch)
+        install_staged_release_no_launch
+        ;;
     run)
-        open_app
+        build_release
+        open_app_for_explicit_launch
         ;;
     --debug|debug)
-        lldb -- "$APP_BINARY"
+        build_release
+        stop_running_app_for_explicit_launch
+        lldb -- "$BUILD_BINARY"
         ;;
     --logs|logs)
-        open_app
+        build_release
+        open_app_for_explicit_launch
         /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
         ;;
     --telemetry|telemetry)
-        open_app
+        build_release
+        open_app_for_explicit_launch
         /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
         ;;
     --verify|verify)
-        open_app
+        build_release
+        open_app_for_explicit_launch
         sleep 1
         pgrep -x "$APP_NAME" >/dev/null
         ;;
     *)
-        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
+        echo "usage: $0 [stage-release-no-launch|--stage-release-no-launch|install-staged-release-no-launch|--install-staged-release-no-launch|run|--debug|--logs|--telemetry|--verify]" >&2
         exit 2
         ;;
 esac

```

