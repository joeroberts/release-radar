### Task 1: Add the v11 persistence foundation

**Owner-size split:** Deliver this original outcome through two dependency-safe
checkpoints. Task 1A generates, proves, reviews, commits, pushes, and remotely
verifies the genuine schema-v10 fixture before any v11 production edit. Task
1B then delivers the public models plus complete additive v11 migration and
preservation proof. The split changes commit/review boundaries only; together
the two briefs cover every Task 1 requirement.

**Files:**
- Create: `ReleaseRadarCore/Models/DeliveryGoalModels.swift`
- Modify: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Create: `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- Create: `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md`

**Interfaces:**
- Produces: `DeliveryGoalID`, `PhasePlanState`, `DeliveryGoalLifecycle`, `PhasePlanRecord`, `DeliveryGoalRecord`, `DeliveryGoalCriterionRecord`, `DeliveryGoalAssignmentRecord`, `DeliveryGoalAssignmentEventRecord`, `PhasePlanReadinessFailure`.
- Produces schema tables: `phase_plans`, `delivery_goals`, `delivery_goal_done_criteria`, `delivery_goal_ticket_assignments`, `delivery_goal_assignment_events`; column `tickets.plan_legacy_continuation`.
- Consumes no new interface.

- [ ] **Step 1: Write the task brief before implementation release**

Have a fresh independent Planning agent record the objective, exact
spec/ADR/design references, in/out scope, migration risk, v10 fixture,
foreign-key/rollback strategy, no-inference rule, test commands, independent
reviewers, and expected ledger evidence in the two split briefs. Register both SHA-256 values in
`docs/delivery/task-briefs/SHA256SUMS` using the existing format. Architecture,
TPM, QA/Test, Delivery Management, and Security/Privacy must return GO with
Required 0 on that exact brief before Step 2 begins.

After Required-0 closure, create a planning-only checkpoint before any
generator or product edit. Stage only `.gitignore`, this split amendment, both
registered briefs, `docs/delivery/task-briefs/SHA256SUMS`, and the planning/
review evidence in `docs/delivery/progress.md`. Commit, push, and verify exact
local/remote SHA equality with ahead/behind `0/0`; Step 2 remains closed until
that checkpoint is remotely exact.

- [ ] **Step 2: Generate one genuine schema-v10 fixture before changing production code**

While `StoreMigrations.currentVersion` is still 10, temporarily add one
`StoreAcceptanceTests` generator test that requires
`RR_SCHEMA_V10_FIXTURE_OUTPUT`, creates its parent directory, initializes a
`DeliveryStore` at that exact URL, and asserts `PRAGMA user_version == 10`.
Use this exact body and fail if the target already exists:

```swift
func testGenerateExactVersionTenFixture() throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try XCTUnwrap(environment["RR_SCHEMA_V10_FIXTURE_OUTPUT"])
    let url = URL(fileURLWithPath: path)
    XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    _ = DeliveryStore(databaseURL: url)
    XCTAssertEqual(try SQLiteConnection(url: url).scalarInt("PRAGMA user_version"), 10)
}
```
Run only that test with:

```bash
RR_SCHEMA_V10_FIXTURE_OUTPUT="$PWD/ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite" \
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-v10-fixture \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionTenFixture
```

Remove the generator test immediately, verify the fixture directly reports
schema 10 and contains no v11 table, column, index, or trigger, then write its
SHA-256 to `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`. The fixture and
digest are durable test inputs; the removed generator is not a deliverable.
Require fresh postimplementation Code Review and QA plus Architecture,
Security/Privacy, TPM, and Delivery Management GO with Required 0. Update the
ledger, stage only the two fixture artifacts and `docs/delivery/progress.md`,
commit/push Task 1A, and verify exact remote equality before Step 3/Task 1B
opens.

- [ ] **Step 3: Write RED model and migration tests against the exact fixture**

Verify the checked-in v10 fixture against `SHA256SUMS`, copy it to a per-test
temporary URL, seed a complete v10 graph through raw fixture SQL, and snapshot
every seeded v10 table before opening `DeliveryStore`. The graph contains two phases and an active-phase
pointer; Backlog, In progress, Needs review, Blocked, and Accepted tickets;
phase/ticket dependencies; an unresolved blocker; observed thread and goal;
exact ticket/Codex-goal link; audit attribution; and an agent-command receipt.
After migration and relaunch assert:

```swift
XCTAssertEqual(try migratedVersion(), 11)
XCTAssertEqual(try migratedPhasePlanStates(), [phase1: .legacyUnassessed, phase2: .legacyUnassessed])
XCTAssertEqual(try deliveryGoalCount(), 0)
XCTAssertEqual(try deliveryGoalAssignmentCount(), 0)
XCTAssertEqual(try legacyContinuationTicketIDs(), Set([activeTicketID, reviewTicketID]))
XCTAssertEqual(try semanticV10Snapshot(afterMigration: true), beforeMigration)
XCTAssertNil(try migratedConnection.row("PRAGMA foreign_key_check"))
```

The semantic snapshot excludes only `PRAGMA user_version` and the additive v11
objects/column. It compares the active phase, ticket outcomes/lanes,
dependencies, blockers, observed records, exact runtime link, audit, and
request receipt field-for-field. Also add exact-schema tests for lifecycle
`CHECK` constraints, nonnegative revisions, Ready/`ready_revision`
consistency, ordered nonempty criteria, unique ticket assignment,
same-project/same-phase foreign keys, the deferred assignment-event/audit
foreign key, `PRAGMA foreign_key_check`, and the invariant that every newly
inserted phase receives a phase-plan row.

- [ ] **Step 4: Run the focused test and confirm RED**

Run:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-red -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Expected: failure because schema version remains 10 and the new types/tables/column do not exist.

- [ ] **Step 5: Add exact public model types**

Create `DeliveryGoalModels.swift` with these declarations and public memberwise initializers:

```swift
public struct DeliveryGoalID: DeliveryRecordID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum PhasePlanState: String, Codable, CaseIterable, Sendable {
    case legacyUnassessed = "legacy_unassessed"
    case draft
    case ready
}

public enum DeliveryGoalLifecycle: String, Codable, CaseIterable, Sendable {
    case draft
    case planned
    case active
    case awaitingAcceptance = "awaiting_acceptance"
    case accepted
    case superseded
}

public struct DeliveryGoalDraft: Codable, Equatable, Sendable {
    public let id: DeliveryGoalID
    public let title: String
    public let outcome: String
    public let doneCriteria: [String]
    public let sortOrder: Int
}

public struct DeliveryGoalAssignment: Codable, Equatable, Sendable {
    public let goalID: DeliveryGoalID
    public let ticketID: TicketID
}
```

Add `.phasePlan` and `.deliveryGoal` to `AuditEntityType` in
`DeliveryStore.swift`; do not modify `ObservedGoalID`, `ObservedGoalRecord`, or
`NotificationEventRecord.goalID`.

- [ ] **Step 6: Implement schema v11 and manifest validation**

Set `currentVersion` to 11, apply `schemaVersion11` after v10, register all tables/columns/indexes/foreign keys in the existing schema manifest, and use relational done criteria:

```sql
ALTER TABLE tickets ADD COLUMN plan_legacy_continuation INTEGER NOT NULL DEFAULT 0
    CHECK (plan_legacy_continuation IN (0, 1));
UPDATE tickets
SET plan_legacy_continuation = 1
WHERE lane IN ('in_progress', 'needs_review');

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
);
```

Create `delivery_goals`, `delivery_goal_done_criteria`, and
`delivery_goal_ticket_assignments` with exact project/phase composite foreign
keys and a unique `(project_id, ticket_id)` assignment. Add
`delivery_goal_assignment_events` with the exact audit ID, project, phase,
ticket, previous/current goal IDs, structural revision, and assigned/
unassigned/reassigned action. Its audit-event foreign key is
`DEFERRABLE INITIALLY DEFERRED`, allowing the store-owned audit insert later in
the same transaction; all project/phase/ticket/goal references are composite
and fail closed. Add the supporting unique identity indexes required for
composite references. Insert one Legacy-unassessed phase-plan row per existing
phase with one captured migration timestamp. Add a manifest-validated `AFTER
INSERT` phase trigger that creates a Legacy-unassessed phase-plan row as the
fail-safe default for every future phase; the Task 2 governed phase writer
changes a newly created ordinary phase to Draft in the same transaction, while
an imported phase retains Legacy unassessed. Insert no goal, assignment, or
assignment-event rows.

- [ ] **Step 7: Run focused migration tests GREEN**

Use `/tmp/release-radar-rr-r10-task1-green` with the Step 4 command. Expected: every `StoreAcceptanceTests` case passes, schema is 11, and v10 snapshot preservation remains intact.

- [ ] **Step 8: Run the complete existing store and plugin-lifecycle migration boundary**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-regression -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests
```

Expected: all selected tests pass after updating assertions that truthfully expect schema 11; lifecycle singleton behavior remains unchanged.

- [ ] **Step 9: Independent gate, ledger update, commit, and remote verification**

This is the Task 1B gate; Task 1A must already be committed, pushed, and
remotely exact. Run `git diff --check` and require Task 1B's independent reviews
to return GO with Required 0. Record exact commands/results and reviewer
dispositions in `docs/delivery/progress.md`. Stage only Task 1B model/store/test
paths plus the ledger, inspect the staged diff, commit the fully verified task,
push `codex/release-radar-mvp`, and verify local HEAD equals the remote branch
SHA before Task 2 opens.

---

