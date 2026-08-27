# RR-02 implementation report — transactional local delivery store

## Outcome

Implemented the app-owned local SQLite delivery store for RR-02. The slice adds stable typed IDs and distinct delivery/runtime/audit/notification records, a versioned schema, an actor-isolated transaction boundary, automatic attributed audit events, foreign-key and project-boundary constraints, recursive phase/ticket dependency-cycle rejection, read-only projections, relaunch persistence, and explicit recovery state that preserves authoritative files.

The implementation is ready for independent code, QA, architecture, and security/privacy review. It is not marked accepted or released.

## Files changed

- `ReleaseRadarCore/Models/DeliveryModels.swift`
- `ReleaseRadarCore/Store/SQLiteConnection.swift`
- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarCore/Store/DeliveryStore.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadar.xcodeproj/project.pbxproj`
- `docs/delivery/progress.md`
- `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`

## Behavior and architecture evidence

- Successful delivery transactions commit their data and one audit event containing actor, optional originating thread, reason, and timestamp.
- Failed invalid-reference, cross-project link, ticket-cycle, and phase-cycle writes roll back both delivery mutations and the would-be audit event.
- Read projections reject writes, so callers cannot bypass `DeliveryStore.transact` and its audit invariant.
- Transaction and read callbacks receive callback-scoped, thread-bound connection leases. Retained handles are invalidated on callback exit, and cross-context use is rejected before SQLite access.
- SQLite authorization denies transaction-callback transaction control (`COMMIT`, `ROLLBACK`, and savepoints) and access to `audit_events`. The store verifies that its transaction is still active before it inserts the automatic audit event and commits.
- Read callbacks use a strict SQLite authorizer allowlist limited to SELECT, READ, and FUNCTION actions. PRAGMA and all connection, schema, transaction, and mutation actions are denied by default, so SQLite's statement-readonly classification cannot admit connection-state changes.
- SQLite foreign keys and uniqueness checks are enabled on the app-owned connection.
- Schema version 1 keeps projects/roots, phases, tickets, phase/ticket dependencies, blockers, evidence, thread links/exclusions, observed threads/goals, review items, audit events, and notification events as distinct tables.
- The default database location is the app's user Application Support directory.
- Existing pre-migration databases receive a consistent `VACUUM INTO` snapshot moved atomically into place before the exclusive transactional migration begins.
- Integrity/open failures and migration failures expose typed unavailable recovery state. Corrupt originals are byte-preserved; failed migrations leave both the original version-0 database and its pre-migration snapshot readable, with no silent reset/recreation.
- Relaunch verification proves accepted data and its audit survive while a rejected write remains absent.

## TDD evidence

### Successful audited commit

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testSuccessfulTicketTransitionCommitsAttributedAuditEvent`

RED result: exit 65; expected compile failure because `DeliveryStore`, the typed IDs, `DeliveryActor`, `TicketLane`, and `SQLiteValue` did not exist.

GREEN command: same command.

GREEN result: exit 0; 1 test passed, 0 failed.

### Callback capability containment — fix round 1

Escaped-handle RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testConnectionReturnedFromTransactionCannotWriteAfterCallbackCompletes -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testConnectionReturnedFromReadCannotWriteAfterCallbackCompletes`

RED result: exit 65; both retained callbacks exposed the live actor-owned SQLite connection and allowed a later write.

GREEN command: same command after adding scoped leases.

GREEN result: exit 0; 2 tests passed, 0 failed. Both escaped handles reject subsequent execution, with delivery state and audit counts unchanged.

Transaction/audit-boundary RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testCallbackCommitCannotEscapeStoreOwnedTransaction -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testCallbackCannotMutateAuditEvents`

RED result: exit 65; early `COMMIT` preserved the delivery mutation despite the later throw, and direct audit deletion committed instead of being rejected.

GREEN command: same command after installing callback authorization and an active-transaction check.

GREEN result: exit 0; 2 tests passed, 0 failed. Both attempts are rejected and roll back their delivery changes without altering audit history.

### Read-callback transaction control — fix round 2

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testReadCallbackCannotControlTransactionOrPoisonSubsequentAuditedWrite`

RED result: exit 65; the read callback accepted `BEGIN`, leaving the root connection inside a transaction so the following audited transaction could not start.

GREEN command: same command after applying the existing transaction-control authorization to the read callback scope.

GREEN result: exit 0; 1 test passed, 0 failed. The attempted `BEGIN` is rejected, and the following audited ticket transition commits with the expected delivery state and attributed audit record.

### Read-callback connection state — stop-rule recovery

After two remediation rounds, independent review found one remaining Required product-integrity defect: system SQLite reports state-setting PRAGMAs such as `PRAGMA foreign_keys=OFF` as statement-readonly. The existing read denylist therefore allowed a callback to disable integrity enforcement on the authoritative connection. The original workstream stopped under the two-round rule; a fresh recovery implementer retained the existing leases and transaction/audit protections and replaced only the read authorizer with a fail-closed observational allowlist.

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testReadCallbackCannotDisableForeignKeysOrBypassAuditedIntegrity`

RED result: exit 65; the read callback accepted `PRAGMA foreign_keys=OFF`, and the subsequent invalid-FK transaction also completed instead of throwing (`StoreAcceptanceTests.swift:215` and `:221`).

GREEN command: same command after allowing only SQLite SELECT, READ, and FUNCTION authorizer actions in read callbacks.

GREEN result: exit 0; 1 test passed, 0 failed. The PRAGMA is rejected, `foreign_keys` remains 1, an invalid-FK transaction rolls back with no audit event, and a following valid audited ticket transition commits.

### Transaction rollback and integrity validation

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests`

RED result: exit 65; invalid-reference and cross-project rollback tests passed, while the ticket dependency-cycle test failed because the cyclic transaction committed.

GREEN command: same command after adding recursive ticket-cycle enforcement.

GREEN result: exit 0; the then-current 4 tests passed, 0 failed.

Additional phase-cycle RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testPhaseDependencyCycleRollsBackDeliveryAndAuditWrites`

Additional phase-cycle RED result: exit 65; the cyclic phase transaction committed. GREEN result with the same command after phase-cycle enforcement: exit 0; 1 test passed, 0 failed.

### Migration and relaunch persistence

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit`

RED result: exit 65; expected compile failure because the pre-migration snapshot contract did not exist.

GREEN command: same command.

GREEN result: exit 0; 1 test passed, 0 failed. The final form also verifies a rejected reference is still absent after relaunch.

### Preserved recovery state on corruption/migration failure

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testCorruptDatabaseOpensUnavailableAndLeavesOriginalBytesIntact -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testMigrationFailureOpensUnavailableWithOriginalAndSnapshotRecoverable`

RED result: exit 65; expected compile failure because explicit store availability and typed recovery state did not exist.

GREEN command: same command.

GREEN result: exit 0; 2 tests passed, 0 failed.

### Audited-write boundary

RED command:

`xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testReadProjectionCannotBypassAuditedTransactions`

RED result: exit 65; the read callback mutated the delivery table without an audit event.

GREEN command: same command.

GREEN result: exit 0; 1 test passed, 0 failed.

## Final verification

- `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` — exit 0, `** TEST SUCCEEDED **`; 15 tests passed, 0 failed/skipped.
- `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` — exit 0, `** BUILD SUCCEEDED **`.
- `git diff --check` / staged diff checks — no whitespace errors.

## Risks and review gate

- Independent code, QA, architecture, and security/privacy reviews remain required before RR-02 acceptance or release.
- The local tool/bridge work that will mediate agent actions is assigned to later slices; RR-02 intentionally exposes no agent-facing database access.
- No UI, notification delivery, observer, onboarding, importer, or bridge behavior was added.

DONE
Implementation commits: `6126178`, `7362903`, `5d8a735`, `ad6a446`, `f5a06cf`
