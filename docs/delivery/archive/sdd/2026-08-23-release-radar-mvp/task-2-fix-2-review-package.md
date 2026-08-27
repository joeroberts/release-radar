# Review package: 1af4533ed88d91f0b0197b40340ee878921242f6..HEAD

## Commits
f1bf8ca docs: record RR-02 read boundary fix
ad6a446 fix: reject transaction control in store reads

## Files changed
 ReleaseRadarCore/Store/DeliveryStore.swift    |  4 ++-
 ReleaseRadarCore/Store/SQLiteConnection.swift | 36 +++++++++++++++++++++++----
 ReleaseRadarTests/StoreAcceptanceTests.swift  | 26 +++++++++++++++++++
 docs/delivery/progress.md                     | 10 ++++----
 4 files changed, 65 insertions(+), 11 deletions(-)

## Diff
diff --git a/ReleaseRadarCore/Store/DeliveryStore.swift b/ReleaseRadarCore/Store/DeliveryStore.swift
index c656b64..0d7160d 100644
--- a/ReleaseRadarCore/Store/DeliveryStore.swift
+++ b/ReleaseRadarCore/Store/DeliveryStore.swift
@@ -107,21 +107,23 @@ public actor DeliveryStore {
             throw error
         }
     }
 
     public func read<T: Sendable>(
         _ body: @Sendable (SQLiteConnection) throws -> T
     ) throws -> T {
         let connection = try availableConnection()
         let scopedConnection = connection.makeScopedConnection(access: .readOnly)
         defer { scopedConnection.invalidate() }
-        return try body(scopedConnection)
+        return try connection.withReadCallbackRestrictions {
+            try body(scopedConnection)
+        }
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
index c5280b6..385c231 100644
--- a/ReleaseRadarCore/Store/SQLiteConnection.swift
+++ b/ReleaseRadarCore/Store/SQLiteConnection.swift
@@ -143,20 +143,27 @@ public final class SQLiteConnection: @unchecked Sendable {
         lease?.invalidate()
     }
 
     func withTransactionCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
         let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionAuthorizer, nil)
         guard result == SQLITE_OK else { throw currentError(code: result) }
         defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
         return try body()
     }
 
+    func withReadCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
+        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionControlAuthorizer, nil)
+        guard result == SQLITE_OK else { throw currentError(code: result) }
+        defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
+        return try body()
+    }
+
     var isInTransaction: Bool {
         sqlite3_get_autocommit(databaseHandle) == 0
     }
 
     private func prepare(_ sql: String) throws -> OpaquePointer {
         var statement: OpaquePointer?
         let result = sqlite3_prepare_v2(databaseHandle, sql, -1, &statement, nil)
         guard result == SQLITE_OK, let statement else { throw currentError(code: result) }
         return statement
     }
@@ -203,42 +210,61 @@ public final class SQLiteConnection: @unchecked Sendable {
     private var databaseHandle: OpaquePointer? {
         root?.database ?? database
     }
 
     private func validateLease() throws {
         try lease?.validate()
     }
 }
 
 private func deliveryStoreTransactionAuthorizer(
-    _: UnsafeMutableRawPointer?,
+    context: UnsafeMutableRawPointer?,
     action: Int32,
     firstArgument: UnsafePointer<CChar>?,
     secondArgument: UnsafePointer<CChar>?,
-    _: UnsafePointer<CChar>?,
-    _: UnsafePointer<CChar>?
+    databaseName: UnsafePointer<CChar>?,
+    triggerName: UnsafePointer<CChar>?
 ) -> Int32 {
-    if action == SQLITE_TRANSACTION || action == SQLITE_SAVEPOINT {
-        return SQLITE_DENY
+    let transactionControlResult = deliveryStoreTransactionControlAuthorizer(
+        context,
+        action: action,
+        firstArgument,
+        secondArgument,
+        databaseName,
+        triggerName
+    )
+    guard transactionControlResult == SQLITE_OK else {
+        return transactionControlResult
     }
 
     let protectedTable = "audit_events"
     let firstName = firstArgument.map { String(cString: $0) }
     let secondName = secondArgument.map { String(cString: $0) }
     if firstName?.caseInsensitiveCompare(protectedTable) == .orderedSame
         || secondName?.caseInsensitiveCompare(protectedTable) == .orderedSame {
         return SQLITE_DENY
     }
 
     return SQLITE_OK
 }
 
+private func deliveryStoreTransactionControlAuthorizer(
+    _: UnsafeMutableRawPointer?,
+    action: Int32,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?
+) -> Int32 {
+    action == SQLITE_TRANSACTION || action == SQLITE_SAVEPOINT ? SQLITE_DENY : SQLITE_OK
+}
+
 enum SQLiteConnectionAccess {
     case transaction
     case readOnly
 }
 
 private final class SQLiteConnectionLease: @unchecked Sendable {
     let access: SQLiteConnectionAccess
 
     private let lock = NSLock()
     private let ownerThreadID: UInt64
diff --git a/ReleaseRadarTests/StoreAcceptanceTests.swift b/ReleaseRadarTests/StoreAcceptanceTests.swift
index 626d2ea..317f384 100644
--- a/ReleaseRadarTests/StoreAcceptanceTests.swift
+++ b/ReleaseRadarTests/StoreAcceptanceTests.swift
@@ -175,20 +175,46 @@ final class StoreAcceptanceTests: XCTestCase {
         let state = try await store.read { connection in
             (
                 try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
             )
         }
         XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
         XCTAssertEqual(state.1, 1)
     }
 
+    func testReadCallbackCannotControlTransactionOrPoisonSubsequentAuditedWrite() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.read { connection in
+                _ = try connection.row("BEGIN")
+            }
+        }
+
+        try await store.transact(actor: .init(id: "agent-accept"), reason: "Accept ticket") { connection in
+            try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-accept' AND reason = 'Accept ticket'")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.accepted.rawValue)
+        XCTAssertEqual(state.1, 2)
+        XCTAssertEqual(state.2, 1)
+    }
+
     func testConnectionReturnedFromTransactionCannotWriteAfterCallbackCompletes() async throws {
         let store = DeliveryStore(databaseURL: try makeDatabaseURL())
         try await seedProject(store)
 
         let escapedConnection = try await store.transact(
             actor: .init(id: "agent-leak"),
             reason: "Return transaction handle"
         ) { connection in
             connection
         }
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index 1643a78..eb6adfa 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -49,25 +49,25 @@ Each task entry records status, verification, reviews with Required/Optional/Out
 
 ### RR-02 release gate
 
 - TPM: GO; RR-01 technically accepted and RR-02 dependency-safe.
 - Delivery Manager: GO; no remaining Required blocker.
 
 ### RR-02 — Transactional local delivery store
 
 - Status: Implemented; independent reviews pending. Not accepted or released.
 - Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
-- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`).
-- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, and denial and rollback of callback mutations to `audit_events`. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
-- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 13 of 13 with 0 failures/skips; `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed.
-- Reviews: Fix round 1 addressed two independently validated Required findings: escaped callback connections and callback access to transaction control/audit storage. Code Reviewer, QA, Architect, and Security/privacy re-review remain pending.
-- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks cannot control transactions or access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read projections are write-protected; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
+- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`), `ad6a446` (`fix: reject transaction control in store reads`).
+- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, and rejection of read-callback transaction control without poisoning the following audited transaction. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
+- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 14 of 14 with 0 failures/skips; `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed.
+- Reviews: Fix round 1 addressed the original two Required findings. Fix round 2 addressed the one Required residual: transaction-control SQL through a read callback could poison the actor-owned connection. Code Reviewer, QA, Architect, and Security/privacy re-review remain pending.
+- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; all callbacks deny transaction control, while transaction callbacks additionally cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read projections otherwise retain their existing SQL policy; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
 - Risks: Review gates remain open. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
 - Stop-rule events: None.
 - Next eligible task: None until independent RR-02 reviews are recorded and TPM/Delivery Manager release the next dependency-safe task.
 
 ### RR-01 — Standalone signed application foundation
 
 - Status: Implemented; QA HOLD round 1 addressed and independent re-review pending.
 - Scope: Standalone Xcode project with app, core framework, agent-tool executable, unit-test, and UI-test targets; signed SwiftUI shell; canonical local run action; ADR-001.
 - Preimplementation gates: Planning complete; Architect approved with corrections; TPM conditional GO satisfied; QA approved with acceptance evidence; Delivery Manager GO; Security/privacy conditional pass incorporated. See the table above for the findings carried into the implementation.
 - Decisions: `com.rekonlabs.ReleaseRadar`, macOS 14.0, filesystem-synchronized source roots, five persisted lanes, app-only database authority, separate observer and typed bridge, App Sandbox and Hardened Runtime.
