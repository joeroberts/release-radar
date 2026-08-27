# Review package: ecaeda58fb9abda16c53ffb569764b726f02493e..HEAD

## Commits
1af4533 docs: record RR-02 callback containment fix
5d8a735 fix: contain store callback capabilities

## Files changed
 ReleaseRadarCore/Store/DeliveryStore.swift    |  16 +++-
 ReleaseRadarCore/Store/SQLiteConnection.swift | 118 ++++++++++++++++++++++++--
 ReleaseRadarTests/StoreAcceptanceTests.swift  |  92 ++++++++++++++++++++
 docs/delivery/progress.md                     |  10 +--
 4 files changed, 218 insertions(+), 18 deletions(-)

## Diff
diff --git a/ReleaseRadarCore/Store/DeliveryStore.swift b/ReleaseRadarCore/Store/DeliveryStore.swift
index a158837..c656b64 100644
--- a/ReleaseRadarCore/Store/DeliveryStore.swift
+++ b/ReleaseRadarCore/Store/DeliveryStore.swift
@@ -1,11 +1,12 @@
 import Foundation
+import SQLite3
 
 public enum StoreError: Error, LocalizedError, Equatable, Sendable {
     case unavailable(String)
     case unsupportedSchemaVersion(found: Int64, supported: Int64)
 
     public var errorDescription: String? {
         switch self {
         case let .unavailable(message): message
         case let .unsupportedSchemaVersion(found, supported):
             "Database schema version \(found) is newer than supported version \(supported)"
@@ -73,22 +74,29 @@ public actor DeliveryStore {
         }
     }
 
     public func transact<T: Sendable>(
         actor: DeliveryActor,
         reason: String,
         _ body: @Sendable (SQLiteConnection) throws -> T
     ) throws -> T {
         let connection = try availableConnection()
         try connection.execute("BEGIN IMMEDIATE TRANSACTION")
+        let scopedConnection = connection.makeScopedConnection(access: .transaction)
+        defer { scopedConnection.invalidate() }
         do {
-            let result = try body(connection)
+            let result = try connection.withTransactionCallbackRestrictions {
+                try body(scopedConnection)
+            }
+            guard connection.isInTransaction else {
+                throw SQLiteError(code: SQLITE_MISUSE, message: "The transaction callback ended the store-owned transaction")
+            }
             try connection.execute(
                 "INSERT INTO audit_events (id, actor_id, thread_id, reason, created_at) VALUES (?, ?, ?, ?, ?)",
                 bindings: [
                     .text(UUID().uuidString),
                     .text(actor.id),
                     actor.threadID.map(SQLiteValue.text) ?? .null,
                     .text(reason),
                     .text(ISO8601DateFormatter().string(from: Date())),
                 ]
             )
@@ -97,23 +105,23 @@ public actor DeliveryStore {
         } catch {
             try? connection.execute("ROLLBACK")
             throw error
         }
     }
 
     public func read<T: Sendable>(
         _ body: @Sendable (SQLiteConnection) throws -> T
     ) throws -> T {
         let connection = try availableConnection()
-        return try connection.withReadOnlyAccess {
-            try body(connection)
-        }
+        let scopedConnection = connection.makeScopedConnection(access: .readOnly)
+        defer { scopedConnection.invalidate() }
+        return try body(scopedConnection)
     }
 
     public static func applicationSupportDatabaseURL(
         fileManager: FileManager = .default
     ) -> URL {
         let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
         let directory = baseURL.appendingPathComponent("com.rekonlabs.ReleaseRadar", isDirectory: true)
         try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
         return directory.appendingPathComponent("release-radar.sqlite")
     }
diff --git a/ReleaseRadarCore/Store/SQLiteConnection.swift b/ReleaseRadarCore/Store/SQLiteConnection.swift
index 53ca54c..c5280b6 100644
--- a/ReleaseRadarCore/Store/SQLiteConnection.swift
+++ b/ReleaseRadarCore/Store/SQLiteConnection.swift
@@ -12,23 +12,26 @@ public enum SQLiteValue: Equatable, Sendable {
 
 public struct SQLiteError: Error, LocalizedError, Equatable, Sendable {
     public let code: Int32
     public let message: String
 
     public var errorDescription: String? { "SQLite error \(code): \(message)" }
 }
 
 public final class SQLiteConnection: @unchecked Sendable {
     private var database: OpaquePointer?
-    private var isReadOnly = false
+    private let root: SQLiteConnection?
+    private let lease: SQLiteConnectionLease?
 
     init(url: URL) throws {
+        root = nil
+        lease = nil
         let result = sqlite3_open_v2(
             url.path,
             &database,
             SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
             nil
         )
         guard result == SQLITE_OK else {
             let error = currentError(code: result)
             sqlite3_close(database)
             database = nil
@@ -37,42 +40,52 @@ public final class SQLiteConnection: @unchecked Sendable {
         do {
             sqlite3_busy_timeout(database, 5_000)
             try execute("PRAGMA foreign_keys = ON")
         } catch {
             sqlite3_close(database)
             database = nil
             throw error
         }
     }
 
+    private init(root: SQLiteConnection, access: SQLiteConnectionAccess) {
+        database = nil
+        self.root = root
+        lease = SQLiteConnectionLease(access: access)
+    }
+
     deinit {
-        sqlite3_close(database)
+        if root == nil {
+            sqlite3_close(database)
+        }
     }
 
     public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
-        guard !isReadOnly else {
+        try validateLease()
+        guard lease?.access != .readOnly else {
             throw SQLiteError(code: SQLITE_READONLY, message: "Writes require DeliveryStore.transact")
         }
         let statement = try prepare(sql)
         defer { sqlite3_finalize(statement) }
         try bind(bindings, to: statement)
         let result = sqlite3_step(statement)
         guard result == SQLITE_DONE else { throw currentError(code: result) }
     }
 
     public func row(
         _ sql: String,
         bindings: [SQLiteValue] = []
     ) throws -> [String: SQLiteValue]? {
+        try validateLease()
         let statement = try prepare(sql)
         defer { sqlite3_finalize(statement) }
-        guard !isReadOnly || sqlite3_stmt_readonly(statement) != 0 else {
+        guard lease?.access != .readOnly || sqlite3_stmt_readonly(statement) != 0 else {
             throw SQLiteError(code: SQLITE_READONLY, message: "Writes require DeliveryStore.transact")
         }
         try bind(bindings, to: statement)
         let result = sqlite3_step(statement)
         if result == SQLITE_DONE { return nil }
         guard result == SQLITE_ROW else { throw currentError(code: result) }
 
         var resultRow: [String: SQLiteValue] = [:]
         for index in 0..<sqlite3_column_count(statement) {
             let name = String(cString: sqlite3_column_name(statement, index))
@@ -115,29 +128,42 @@ public final class SQLiteConnection: @unchecked Sendable {
         let temporaryURL = destinationURL
             .deletingLastPathComponent()
             .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
         defer { try? FileManager.default.removeItem(at: temporaryURL) }
         try execute("VACUUM INTO ?", bindings: [.text(temporaryURL.path)])
         guard rename(temporaryURL.path, destinationURL.path) == 0 else {
             throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destinationURL.path])
         }
     }
 
-    func withReadOnlyAccess<T>(_ body: () throws -> T) rethrows -> T {
-        isReadOnly = true
-        defer { isReadOnly = false }
+    func makeScopedConnection(access: SQLiteConnectionAccess) -> SQLiteConnection {
+        SQLiteConnection(root: root ?? self, access: access)
+    }
+
+    func invalidate() {
+        lease?.invalidate()
+    }
+
+    func withTransactionCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
+        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionAuthorizer, nil)
+        guard result == SQLITE_OK else { throw currentError(code: result) }
+        defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
         return try body()
     }
 
+    var isInTransaction: Bool {
+        sqlite3_get_autocommit(databaseHandle) == 0
+    }
+
     private func prepare(_ sql: String) throws -> OpaquePointer {
         var statement: OpaquePointer?
-        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
+        let result = sqlite3_prepare_v2(databaseHandle, sql, -1, &statement, nil)
         guard result == SQLITE_OK, let statement else { throw currentError(code: result) }
         return statement
     }
 
     private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
         guard sqlite3_bind_parameter_count(statement) == bindings.count else {
             throw SQLiteError(code: SQLITE_RANGE, message: "Expected \(sqlite3_bind_parameter_count(statement)) bindings, received \(bindings.count)")
         }
         let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
         for (offset, value) in bindings.enumerated() {
@@ -164,13 +190,87 @@ public final class SQLiteConnection: @unchecked Sendable {
         case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(statement, index)))
         case SQLITE_BLOB:
             let count = Int(sqlite3_column_bytes(statement, index))
             guard count > 0, let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
             return .blob(Data(bytes: bytes, count: count))
         default: return .null
         }
     }
 
     private func currentError(code: Int32) -> SQLiteError {
-        SQLiteError(code: code, message: database.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed")
+        SQLiteError(code: code, message: databaseHandle.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed")
+    }
+
+    private var databaseHandle: OpaquePointer? {
+        root?.database ?? database
+    }
+
+    private func validateLease() throws {
+        try lease?.validate()
+    }
+}
+
+private func deliveryStoreTransactionAuthorizer(
+    _: UnsafeMutableRawPointer?,
+    action: Int32,
+    firstArgument: UnsafePointer<CChar>?,
+    secondArgument: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?
+) -> Int32 {
+    if action == SQLITE_TRANSACTION || action == SQLITE_SAVEPOINT {
+        return SQLITE_DENY
+    }
+
+    let protectedTable = "audit_events"
+    let firstName = firstArgument.map { String(cString: $0) }
+    let secondName = secondArgument.map { String(cString: $0) }
+    if firstName?.caseInsensitiveCompare(protectedTable) == .orderedSame
+        || secondName?.caseInsensitiveCompare(protectedTable) == .orderedSame {
+        return SQLITE_DENY
+    }
+
+    return SQLITE_OK
+}
+
+enum SQLiteConnectionAccess {
+    case transaction
+    case readOnly
+}
+
+private final class SQLiteConnectionLease: @unchecked Sendable {
+    let access: SQLiteConnectionAccess
+
+    private let lock = NSLock()
+    private let ownerThreadID: UInt64
+    private var isActive = true
+
+    init(access: SQLiteConnectionAccess) {
+        self.access = access
+        ownerThreadID = Self.currentThreadID()
+    }
+
+    func validate() throws {
+        lock.lock()
+        let isActive = self.isActive
+        lock.unlock()
+
+        guard isActive else {
+            throw SQLiteError(code: SQLITE_MISUSE, message: "SQLite callback scope has ended")
+        }
+        guard Self.currentThreadID() == ownerThreadID else {
+            throw SQLiteError(code: SQLITE_MISUSE, message: "SQLite callback connection cannot cross execution contexts")
+        }
+    }
+
+    func invalidate() {
+        lock.lock()
+        isActive = false
+        lock.unlock()
+    }
+
+    private static func currentThreadID() -> UInt64 {
+        var identifier: UInt64 = 0
+        pthread_threadid_np(nil, &identifier)
+        return identifier
     }
 }
diff --git a/ReleaseRadarTests/StoreAcceptanceTests.swift b/ReleaseRadarTests/StoreAcceptanceTests.swift
index 9b570be..626d2ea 100644
--- a/ReleaseRadarTests/StoreAcceptanceTests.swift
+++ b/ReleaseRadarTests/StoreAcceptanceTests.swift
@@ -175,20 +175,108 @@ final class StoreAcceptanceTests: XCTestCase {
         let state = try await store.read { connection in
             (
                 try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
             )
         }
         XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
         XCTAssertEqual(state.1, 1)
     }
 
+    func testConnectionReturnedFromTransactionCannotWriteAfterCallbackCompletes() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        let escapedConnection = try await store.transact(
+            actor: .init(id: "agent-leak"),
+            reason: "Return transaction handle"
+        ) { connection in
+            connection
+        }
+
+        XCTAssertThrowsError(
+            try escapedConnection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+        )
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 2)
+    }
+
+    func testConnectionReturnedFromReadCannotWriteAfterCallbackCompletes() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        let escapedConnection = try await store.read { connection in
+            connection
+        }
+
+        XCTAssertThrowsError(
+            try escapedConnection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+        )
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 1)
+    }
+
+    func testCallbackCommitCannotEscapeStoreOwnedTransaction() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-commit"), reason: "Commit early") { connection in
+                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+                try connection.execute("COMMIT")
+                throw CallbackFailure.expected
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 1)
+    }
+
+    func testCallbackCannotMutateAuditEvents() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-audit"), reason: "Delete audit history") { connection in
+                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+                try connection.execute("DELETE FROM audit_events")
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 1)
+    }
+
     func testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit() async throws {
         let databaseURL = try makeDatabaseURL()
         do {
             let legacy = try SQLiteConnection(url: databaseURL)
             try legacy.execute("CREATE TABLE legacy_marker (value TEXT NOT NULL)")
             try legacy.execute("INSERT INTO legacy_marker (value) VALUES ('before-migration')")
             try legacy.execute("PRAGMA user_version = 0")
         }
 
         var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
@@ -290,10 +378,14 @@ final class StoreAcceptanceTests: XCTestCase {
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
+
+private enum CallbackFailure: Error {
+    case expected
+}
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index 223b6fe..1643a78 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -49,25 +49,25 @@ Each task entry records status, verification, reviews with Required/Optional/Out
 
 ### RR-02 release gate
 
 - TPM: GO; RR-01 technically accepted and RR-02 dependency-safe.
 - Delivery Manager: GO; no remaining Required blocker.
 
 ### RR-02 — Transactional local delivery store
 
 - Status: Implemented; independent reviews pending. Not accepted or released.
 - Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
-- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`).
-- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, and prevention of unaudited writes through read projections. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
-- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 9 of 9 with 0 failures/skips; `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` passed.
-- Reviews: Code Reviewer pending; QA pending; Architect pending; Security/privacy pending. No findings classified yet.
-- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; read projections are write-protected; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
+- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`).
+- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, and denial and rollback of callback mutations to `audit_events`. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
+- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 13 of 13 with 0 failures/skips; `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed.
+- Reviews: Fix round 1 addressed two independently validated Required findings: escaped callback connections and callback access to transaction control/audit storage. Code Reviewer, QA, Architect, and Security/privacy re-review remain pending.
+- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks cannot control transactions or access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read projections are write-protected; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
 - Risks: Review gates remain open. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
 - Stop-rule events: None.
 - Next eligible task: None until independent RR-02 reviews are recorded and TPM/Delivery Manager release the next dependency-safe task.
 
 ### RR-01 — Standalone signed application foundation
 
 - Status: Implemented; QA HOLD round 1 addressed and independent re-review pending.
 - Scope: Standalone Xcode project with app, core framework, agent-tool executable, unit-test, and UI-test targets; signed SwiftUI shell; canonical local run action; ADR-001.
 - Preimplementation gates: Planning complete; Architect approved with corrections; TPM conditional GO satisfied; QA approved with acceptance evidence; Delivery Manager GO; Security/privacy conditional pass incorporated. See the table above for the findings carried into the implementation.
 - Decisions: `com.rekonlabs.ReleaseRadar`, macOS 14.0, filesystem-synchronized source roots, five persisted lanes, app-only database authority, separate observer and typed bridge, App Sandbox and Hardened Runtime.
