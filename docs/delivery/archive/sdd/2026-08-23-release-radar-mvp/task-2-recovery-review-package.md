# Review package: f1bf8ca9effcefb3588d5a6a97440861ae37d19a..HEAD

## Commits
f49dde9 docs: record RR-02 read allowlist recovery
f5a06cf fix: restrict store reads to observational SQL

## Files changed
 ReleaseRadarCore/Store/SQLiteConnection.swift | 18 +++++++++-
 ReleaseRadarTests/StoreAcceptanceTests.swift  | 50 +++++++++++++++++++++++++--
 docs/delivery/progress.md                     | 12 +++----
 3 files changed, 70 insertions(+), 10 deletions(-)

## Diff
diff --git a/ReleaseRadarCore/Store/SQLiteConnection.swift b/ReleaseRadarCore/Store/SQLiteConnection.swift
index 385c231..35d7bf2 100644
--- a/ReleaseRadarCore/Store/SQLiteConnection.swift
+++ b/ReleaseRadarCore/Store/SQLiteConnection.swift
@@ -144,21 +144,21 @@ public final class SQLiteConnection: @unchecked Sendable {
     }
 
     func withTransactionCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
         let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionAuthorizer, nil)
         guard result == SQLITE_OK else { throw currentError(code: result) }
         defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
         return try body()
     }
 
     func withReadCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
-        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionControlAuthorizer, nil)
+        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreReadAuthorizer, nil)
         guard result == SQLITE_OK else { throw currentError(code: result) }
         defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
         return try body()
     }
 
     var isInTransaction: Bool {
         sqlite3_get_autocommit(databaseHandle) == 0
     }
 
     private func prepare(_ sql: String) throws -> OpaquePointer {
@@ -251,20 +251,36 @@ private func deliveryStoreTransactionControlAuthorizer(
     _: UnsafeMutableRawPointer?,
     action: Int32,
     _: UnsafePointer<CChar>?,
     _: UnsafePointer<CChar>?,
     _: UnsafePointer<CChar>?,
     _: UnsafePointer<CChar>?
 ) -> Int32 {
     action == SQLITE_TRANSACTION || action == SQLITE_SAVEPOINT ? SQLITE_DENY : SQLITE_OK
 }
 
+private func deliveryStoreReadAuthorizer(
+    _: UnsafeMutableRawPointer?,
+    action: Int32,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?,
+    _: UnsafePointer<CChar>?
+) -> Int32 {
+    switch action {
+    case SQLITE_SELECT, SQLITE_READ, SQLITE_FUNCTION:
+        SQLITE_OK
+    default:
+        SQLITE_DENY
+    }
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
index 317f384..a7fbd31 100644
--- a/ReleaseRadarTests/StoreAcceptanceTests.swift
+++ b/ReleaseRadarTests/StoreAcceptanceTests.swift
@@ -201,20 +201,64 @@ final class StoreAcceptanceTests: XCTestCase {
                 try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-accept' AND reason = 'Accept ticket'")
             )
         }
         XCTAssertEqual(state.0, TicketLane.accepted.rawValue)
         XCTAssertEqual(state.1, 2)
         XCTAssertEqual(state.2, 1)
     }
 
+    func testReadCallbackCannotDisableForeignKeysOrBypassAuditedIntegrity() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.read { connection in
+                _ = try connection.row("PRAGMA foreign_keys = OFF")
+            }
+        }
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-invalid"), reason: "Reject missing ticket") { connection in
+                try connection.execute(
+                    "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('rejected', 'project-1', 'missing', 'Rejected')"
+                )
+            }
+        }
+
+        let foreignKeys = try await store.transact(
+            actor: .init(id: "agent-accept"),
+            reason: "Accept ticket"
+        ) { connection in
+            let foreignKeys = try connection.scalarInt("PRAGMA foreign_keys")
+            try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+            return foreignKeys
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM blockers"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-invalid'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'agent-accept' AND reason = 'Accept ticket'")
+            )
+        }
+        XCTAssertEqual(foreignKeys, 1)
+        XCTAssertEqual(state.0, TicketLane.accepted.rawValue)
+        XCTAssertEqual(state.1, 0)
+        XCTAssertEqual(state.2, 2)
+        XCTAssertEqual(state.3, 0)
+        XCTAssertEqual(state.4, 1)
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
@@ -312,30 +356,30 @@ final class StoreAcceptanceTests: XCTestCase {
                 try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('rejected', 'project-1', 'missing', 'Rejected')")
             }
         }
         store = nil
 
         let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
         let persisted = try await relaunchedStore.read { connection in
             (
                 try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-02'"),
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
-                try connection.scalarInt("PRAGMA user_version"),
                 try connection.scalarInt("SELECT COUNT(*) FROM blockers")
             )
         }
+        let relaunchedDatabase = try SQLiteConnection(url: databaseURL)
         let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
 
         XCTAssertEqual(persisted.0, "Store")
         XCTAssertEqual(persisted.1, 1)
-        XCTAssertEqual(persisted.2, 1)
-        XCTAssertEqual(persisted.3, 0)
+        XCTAssertEqual(persisted.2, 0)
+        XCTAssertEqual(try relaunchedDatabase.scalarInt("PRAGMA user_version"), 1)
         XCTAssertEqual(try snapshot.scalarText("SELECT value FROM legacy_marker"), "before-migration")
         XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
     }
 
     func testCorruptDatabaseOpensUnavailableAndLeavesOriginalBytesIntact() async throws {
         let databaseURL = try makeDatabaseURL()
         let originalBytes = Data("not-a-sqlite-database".utf8)
         try originalBytes.write(to: databaseURL)
 
         let store = DeliveryStore(databaseURL: databaseURL)
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index eb6adfa..d6e9135 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -49,27 +49,27 @@ Each task entry records status, verification, reviews with Required/Optional/Out
 
 ### RR-02 release gate
 
 - TPM: GO; RR-01 technically accepted and RR-02 dependency-safe.
 - Delivery Manager: GO; no remaining Required blocker.
 
 ### RR-02 — Transactional local delivery store
 
 - Status: Implemented; independent reviews pending. Not accepted or released.
 - Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
-- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`), `ad6a446` (`fix: reject transaction control in store reads`).
-- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, and rejection of read-callback transaction control without poisoning the following audited transaction. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
-- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 14 of 14 with 0 failures/skips; `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed.
-- Reviews: Fix round 1 addressed the original two Required findings. Fix round 2 addressed the one Required residual: transaction-control SQL through a read callback could poison the actor-owned connection. Code Reviewer, QA, Architect, and Security/privacy re-review remain pending.
-- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; all callbacks deny transaction control, while transaction callbacks additionally cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read projections otherwise retain their existing SQL policy; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
+- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`), `ad6a446` (`fix: reject transaction control in store reads`), `f5a06cf` (`fix: restrict store reads to observational SQL`).
+- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, rejection of read-callback transaction control, and rejection of read-callback `PRAGMA foreign_keys=OFF` while preserving foreign-key enforcement and later valid audited writes. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
+- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 15 of 15 with 0 failures/skips; `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed; `git diff --check` passed.
+- Reviews: Fix round 1 addressed the original two Required findings. Fix round 2 addressed transaction-control SQL through a read callback, but independent review found one remaining Required product-integrity defect: SQLite classifies state-setting PRAGMAs as read-only, allowing a read callback to poison the shared connection. Recovery implementation is complete; fresh Code Reviewer, QA, Architect, and Security/privacy re-review remain pending.
+- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks deny transaction control and cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read callbacks now use a strict SQLite authorizer allowlist limited to SELECT, READ, and FUNCTION actions, denying PRAGMA and every connection/schema/transaction/mutation action by default; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
 - Risks: Review gates remain open. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
-- Stop-rule events: None.
+- Stop-rule events: The original read-boundary remediation stopped after two rounds when review found that the denylist still admitted SQLite connection-state mutation. A fresh recovery implementer preserved the existing lease, audit, and transaction protections and replaced only the read authorizer policy with the smaller fail-closed observational allowlist.
 - Next eligible task: None until independent RR-02 reviews are recorded and TPM/Delivery Manager release the next dependency-safe task.
 
 ### RR-01 — Standalone signed application foundation
 
 - Status: Implemented; QA HOLD round 1 addressed and independent re-review pending.
 - Scope: Standalone Xcode project with app, core framework, agent-tool executable, unit-test, and UI-test targets; signed SwiftUI shell; canonical local run action; ADR-001.
 - Preimplementation gates: Planning complete; Architect approved with corrections; TPM conditional GO satisfied; QA approved with acceptance evidence; Delivery Manager GO; Security/privacy conditional pass incorporated. See the table above for the findings carried into the implementation.
 - Decisions: `com.rekonlabs.ReleaseRadar`, macOS 14.0, filesystem-synchronized source roots, five persisted lanes, app-only database authority, separate observer and typed bridge, App Sandbox and Hardened Runtime.
 - Signing identity: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`; certificate team `2UA854NLX4`.
 - Verification: `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` passed; `./script/build_and_run.sh --verify` passed and found PID 10510; `xcodebuild build-for-testing -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed; `codesign --verify --deep --strict` passed; app entitlements contain App Sandbox and the signature contains Hardened Runtime. After QA fix round 1, the exact focused test command completed with `** TEST SUCCEEDED **`.
