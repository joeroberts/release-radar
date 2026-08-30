# RR-R10 Task 1B Brief: Schema-v11 Persistence and Public Models

**Status:** Canonical planning contract complete. Implementation remains closed
until Task 1A is independently accepted, committed, pushed, and remotely
verified, then Architecture, TPM, QA/Test, Delivery Management, and
Security/Privacy review this exact registered brief and return GO with Required
0.

## Size assessment and dependency-safe boundary

Task 1B is the second half of the owner-required split documented in Task 1A.
With fixture generation removed, it is forecast at roughly 6–8 agent hours and
forms one coherent storage/API review: public plan/goal value types, one
additive v10-to-v11 migration, manifest enforcement, and direct migration/
history verification against the already frozen fixture. Splitting schema SQL
from its preservation and foreign-key tests would create a partially verified
migration commit, which the owner prohibits. Task 1B therefore remains one
bounded task.

Together Task 1A and Task 1B preserve every original plan Task 1 requirement.

## Objective and user-visible outcome

Add Release Radar's complete additive schema-v11 persistence foundation and
public Delivery Goal/phase-plan model contract. Every existing phase migrates
to Legacy unassessed without inferred goals or assignments; only existing In
progress and Needs review tickets receive migration-only continuation; all
existing v10 delivery, dependency, observation, exact Codex-goal link, audit,
notification, and request history remains unchanged.

There is no board or owner-data mutation in this task. Later tasks can build
the governed planning policy and UI on a fail-closed, independently verified
storage foundation while existing observed Codex execution-goal semantics stay
unchanged.

## Controlling product and design references

- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`,
  Global Constraints, File Structure, and Task 1 Steps 3–9
- `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md`,
  Vocabulary and authority, Data model, Phase-plan state machine, Ready
  invariant, Delivery Goal lifecycle, Legacy continuation rule, Migration and
  archive behavior, Verification and acceptance, and Completion boundary
- `docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md`, all
  schema, continuation, Accepted-terminal, observation-separation, audit, and
  archive decisions
- `docs/design/release-radar-delivery-goals-phase-board-design.md` as downstream
  projection vocabulary only; Task 1B changes no UI
- `docs/delivery/progress.md`, Current gate and RR-R10 planning-package evidence
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md`

## In scope

- Add the exact public Delivery Goal/phase-plan IDs, enums, draft/assignment
  values, record values, and actionable readiness-failure value.
- Add `.phasePlan` and `.deliveryGoal` audit entity types without changing any
  existing raw value or audit behavior.
- Advance the store additively from schema version 10 to 11.
- Add `tickets.plan_legacy_continuation` with migration-only grant semantics.
- Add and manifest-register `phase_plans`, `delivery_goals`,
  `delivery_goal_done_criteria`, `delivery_goal_ticket_assignments`, and
  `delivery_goal_assignment_events`.
- Add exact supporting identity/projection indexes, same-project/same-phase
  composite foreign keys, constraint checks, and manifest-validated triggers.
- Insert one `legacy_unassessed` revision-0 plan for each existing phase using
  one migration timestamp; insert no goal, criterion, assignment, or assignment
  event.
- Ensure every future raw phase insert receives a fail-safe Legacy-unassessed
  plan. Task 2 alone may turn an ordinary newly created phase to Draft in the
  same governed transaction.
- Enforce at the database boundary that continuation cannot be granted after
  migration; it may only be cleared.
- Verify the exact checked-in v10 fixture digest, seed a complete v10 graph by
  raw fixture SQL, snapshot it, migrate/relaunch, and compare it field-for-field.
- Update only existing assertions that truthfully change from schema 10 to 11,
  including the plugin-lifecycle persistence boundary.

## Out of scope

- `DeliveryPlanningPolicy`, Ready finalization, goal lifecycle mutations,
  command errors, bridge/MCP tools, importer behavior, sample/debug writers,
  archive-v1 guard implementation, or any ticket-writer routing; Tasks 2 and 3
  own those behaviors
- Inferring goals, criteria, assignments, lifecycle, or continuation from
  ticket prose, lanes, dependencies, blockers, audit, observed threads/goals,
  or `ticket_goal_links`
- A post-v11 legacy-import/sample/debug continuation mode or any API that can
  grant continuation
- Reopening or changing an Accepted ticket; Task 1B only preserves all lanes
  and history, while Task 2 adds mutation enforcement
- Modifying `ObservedGoalID`, `ObservedGoalRecord`, `observed_goals`,
  `ticket_goal_links`, `NotificationEventRecord.goalID`, Codex observation,
  linking, or notification semantics
- Phase Board, viewed/active phase, app model, UI, accessibility, mockup, or
  owner-attention changes
- Owner database/app launch/install, installed-state repair, RR-R10 or
  RR-ROADMAP mutation, bridge/MCP call, or any external state
- Portable archive v2, schema rewriting, destructive migration, or new
  dependency/test infrastructure
- Implementer edits to `docs/delivery/progress.md`; Delivery Management owns
  ledger evidence and adds it after independent verification

## Dependencies and release gate

- Task 1A's exact fixture and checksum must be accepted with Required 0,
  committed, pushed to `origin/codex/release-radar-mvp`, and verified with
  local/remote SHA equality and ahead/behind `0/0`.
- The Task 1A fixture checksum must pass before any Task 1B test or product edit.
- Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy must
  review this exact brief SHA and return GO with Required 0 before the first RED
  test edit.
- One fresh Implementer owns the listed model/store/test files. No concurrent
  writer may modify `StoreMigrations.swift`, `DeliveryStore.swift`, or
  `StoreAcceptanceTests.swift`.
- A separate Code Reviewer and QA verifier, plus Architecture,
  Security/Privacy, TPM, and Delivery Management, must return GO with Required
  0 after implementation and before commit/push or Task 2 release.

## Affected subsystem and anticipated files

- Create: `ReleaseRadarCore/Models/DeliveryGoalModels.swift`
- Modify: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Modify only the schema-version expectation in:
  `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`
- Coordinator modifies: `docs/delivery/progress.md`
- Consume unchanged:
  `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- Consume unchanged:
  `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`

No project-file change is required because the Xcode project uses
file-system-synchronized groups.

## Public interface contract

`DeliveryGoalModels.swift` must define public properties and explicit public
memberwise initializers for these values:

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

The record shapes are exact:

- `PhasePlanRecord`: `projectID`, `phaseID`, `state`, `revision: Int64`,
  `readyRevision: Int64?`, `createdAt: Date`, `updatedAt: Date`, and
  `finalizedAt: Date?`.
- `DeliveryGoalRecord`: `id`, `projectID`, `phaseID`, `title`, `outcome`,
  `lifecycle`, `sortOrder: Int`, `createdAt`, `updatedAt`, `activatedAt: Date?`,
  and `acceptedAt: Date?`.
- `DeliveryGoalCriterionRecord`: `projectID`, `phaseID`, `goalID`,
  `sortOrder: Int`, and `text`.
- `DeliveryGoalAssignmentRecord`: `projectID`, `phaseID`, `goalID`, and
  `ticketID`.
- `DeliveryGoalAssignmentEventRecord`: `auditEventID`, `projectID`, `phaseID`,
  `ticketID`, `previousGoalID: DeliveryGoalID?`,
  `currentGoalID: DeliveryGoalID?`, `revision: Int64`, and `action: String`.
- `PhasePlanReadinessFailure`: sorted `unassignedTicketIDs`, sorted
  `incompleteGoalIDs`, and sorted `conflictingTicketIDs`.

Every record and readiness failure conforms to `Codable`, `Equatable`, and
`Sendable`. Do not move observed-goal types into this file or change their
meaning. Add only `.phasePlan = "phase_plan"` and
`.deliveryGoal = "delivery_goal"` to `AuditEntityType`.

## Exact schema-v11 contract

Use the approved `phase_plans` SQL from plan Task 1, including nonnegative
revision and the two Ready/`ready_revision` checks. The remaining relational
shape is:

- `delivery_goals`: project-local `(project_id, id)` primary identity;
  immutable `phase_id`; title/outcome text; lifecycle CHECK limited to the six
  approved raw values; nonnegative `sort_order`; created/updated plus nullable
  activated/accepted timestamps; composite foreign key to `phase_plans`.
- `delivery_goal_done_criteria`: `(project_id, phase_id, goal_id, sort_order)`
  primary key; nonnegative sort; trimmed nonempty `criterion`; cascading exact
  composite foreign key to the owning goal.
- `delivery_goal_ticket_assignments`: exact project/phase/goal/ticket columns;
  primary/unique `(project_id, ticket_id)`; exact composite foreign keys to the
  owning goal and same-phase ticket.
- `delivery_goal_assignment_events`: audit ID, project, phase, ticket,
  nullable previous/current goals, nonnegative structural revision, and action
  CHECK limited to `assigned`, `unassigned`, `reassigned`; CHECK that assigned
  is null→goal, unassigned is goal→null, and reassigned is different
  goal→goal. Its audit foreign key is `DEFERRABLE INITIALLY DEFERRED`; its
  phase-plan, ticket, and nullable goal references are exact composites.

Add named, manifest-validated indexes sufficient for all composite parent keys
and common lookup paths, including unique ticket `(project_id, phase_id, id)`,
unique goal `(project_id, phase_id, id)`, goal phase/sort, assignment goal, and
assignment-event ticket/revision identities. Register every new table, column,
critical index, trigger, and foreign key in the existing schema manifest.
Validate the normalized assignment-event table SQL so the deferred audit rule
cannot be replaced by an immediate or absent foreign key while still passing
manifest inspection.

Migration order is exact:

1. Add `tickets.plan_legacy_continuation` as non-null 0/1, default 0.
2. Set it to 1 only for already-existing `in_progress` and `needs_review`
   tickets.
3. Create the five tables, supporting indexes, and composite references.
4. Insert one revision-0 `legacy_unassessed` plan for every existing phase with
   one captured migration timestamp used for created/updated values.
5. Insert no Delivery Goal, criterion, assignment, or assignment event.
6. Create and manifest-validate an `AFTER INSERT ON phases` trigger that inserts
   the fail-safe Legacy-unassessed plan for every future phase.
7. Create and manifest-validate ticket triggers that reject inserting a ticket
   with continuation 1 and reject changing continuation from 0 back to 1.
   Clearing 1→0 remains allowed and is irreversible.
8. Validate the complete v11 manifest and `PRAGMA foreign_key_check`, then set
   `PRAGMA user_version = 11` in the existing exclusive migration transaction.

There is no post-v11 legacy continuation mode. There is no goal or assignment
inference. Accepted tickets remain byte/field-semantically unchanged.

## Data, persistence, security, and privacy implications

- The migration is additive and occurs inside the existing exclusive,
  rollback-on-error store migration transaction with the existing
  pre-migration snapshot/recovery contract.
- Existing owner data is not opened during this task; tests use only the
  checked-in empty v10 fixture and temporary copies populated with synthetic
  data.
- Composite foreign keys fail closed on cross-project or cross-phase goal,
  ticket, assignment, and event references.
- The deferred audit reference permits assignment history to be inserted
  inside `DeliveryStore.transact` before its one authoritative audit insert,
  while commit fails if that audit never appears.
- No helper, bridge, importer, UI, sample, or debug path gains SQLite authority
  or continuation capability.
- `observed_goals`, `ticket_goal_links`, and notification goal identity remain
  Codex execution context and are preserved field-for-field.
- No credential, bookmark, permission, sandbox, entitlement, signing, network,
  or external-service behavior changes.
- Independent Security/Privacy review is blocking because this task changes
  the authoritative local store and migration boundary.

## Fixtures and test strategy defined before implementation

Use only XCTest, existing temporary-directory/SQLite helpers, the checked-in
Task 1A fixture, and system `CryptoKit` already used by the project. Add no
dependency or custom test harness.

Before any production edit, add these named RED cases to
`StoreAcceptanceTests`:

- `testDeliveryGoalPublicModelsRoundTripAndKeepObservedGoalIdentityDistinct`
- `testExactVersionTenFixtureMigratesToVersionElevenWithoutInference`
- `testVersionElevenPlanningSchemaEnforcesConstraintsAndCompositeOwnership`
- `testVersionElevenAssignmentHistoryRequiresTheAuthoritativeDeferredAudit`
- `testVersionElevenPhaseInsertCreatesOneLegacyUnassessedPlan`
- `testVersionElevenContinuationCanOnlyBeGrantedByMigration`
- `testVersionElevenManifestRejectsMissingOrCounterfeitPlanningObjects`
- `testVersionElevenMigrationFailureRollsBackToExactVersionTenStateAndRecovers`

The fixture test resolves the fixture relative to `#filePath`, parses the
fixture-local `SHA256SUMS`, computes the file SHA-256, and requires an exact
match before copying the fixture to a per-test temporary URL.

Seed the copy through raw v10 SQL with synthetic rows in every semantic family:

- two projects, roots, at least two phases in the main project, and the exact
  active-phase pointer;
- Backlog, In progress, Needs review, Blocked, and Accepted tickets with exact
  outcomes;
- phase/ticket dependencies, one unresolved blocker, evidence, review and
  completion records;
- project bookmark bytes and a thread exclusion;
- observed thread and observed goal, exact thread link and
  `ticket_goal_links` identity;
- notification event/occurrence, alert-rule state, lifecycle singleton state;
- attributed audit row and `agent_command_requests` receipt.

Snapshot every seeded v10 table in deterministic primary-key order before
opening `DeliveryStore`. After migration and after a second relaunch, require:

```swift
XCTAssertEqual(try migratedVersion(), 11)
XCTAssertEqual(
    try migratedPhasePlanStates(),
    [phase1: .legacyUnassessed, phase2: .legacyUnassessed]
)
XCTAssertEqual(try deliveryGoalCount(), 0)
XCTAssertEqual(try deliveryGoalAssignmentCount(), 0)
XCTAssertEqual(
    try legacyContinuationTicketIDs(),
    Set([activeTicketID, reviewTicketID])
)
XCTAssertEqual(try semanticV10Snapshot(afterMigration: true), beforeMigration)
XCTAssertNil(try migratedConnection.row("PRAGMA foreign_key_check"))
```

The semantic snapshot excludes only `PRAGMA user_version`, the additive v11
objects, and the additive continuation column. It compares every seeded v10
column, including Accepted lane/outcome, active phase, dependencies, blocker,
observed thread/goal, exact ticket/Codex-goal link, notification goal identity,
audit attribution, and request receipt. It must prove no phase is Draft/Ready,
no Delivery Goal/criterion/assignment/event exists, and no Blocked, Backlog, or
Accepted ticket received continuation.

The constraint/history matrix must directly reject and roll back:

- invalid phase-plan state, negative revision, Ready without matching
  `ready_revision`, non-Ready with `ready_revision`, and mismatched revisions;
- invalid goal lifecycle or negative sort order;
- negative, duplicate, or trimmed-empty done criterion;
- duplicate ticket assignment and every cross-project/cross-phase goal/ticket
  reference;
- invalid assignment-event action/null combination, negative revision,
  mismatched phase/ticket/goal, and a committed event without its audit row;
- a new ticket inserted with continuation 1 and a 0→1 continuation update.

It must positively prove: the event can be inserted before the matching audit
inside one `DeliveryStore.transact` and commits once; a future phase insert
creates exactly one Legacy-unassessed plan; 1→0 continuation succeeds and
cannot be regranted; all manifest indexes/triggers/FKs have exact columns and
semantics; and `PRAGMA foreign_key_check` remains empty.

The migration-failure case uses no production fault-injection seam. Copy and
checksum the Task 1A fixture, seed the synthetic v10 graph, then add one
test-only `BEFORE UPDATE ON tickets` trigger whose body raises `ABORT`. Opening
`DeliveryStore` must begin v11 inside the real exclusive migration transaction:
the continuation column is added first and the subsequent continuation
backfill activates the injected trigger, proving failure after v11 work has
started. Require `.unavailable` with recovery kind `.migration`, the exact
original URL, and the physical pre-migration snapshot URL. Before removing the
test trigger, inspect both original and snapshot and require version 10, exact
seeded v10 semantics, the injected trigger as the only test-added object, no
`plan_legacy_continuation` column, no partial v11 table/index/trigger/row, and
no new audit, notification, assignment event, or command receipt. Then drop
only the test trigger from the temporary original, reopen through the normal
store path, prove a clean v11 migration, and prove the second relaunch preserves
that migrated state. Do not add a production hook, alternate migration API, or
custom harness.

## Exact RED and GREEN commands

Verify Task 1A first:

```bash
cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS
```

Run RED before production changes:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-red -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Expected RED: compile/test failure because schema version remains 10 and the
new public types, tables, column, indexes, and triggers do not exist. A failure
caused by a bad fixture digest or unrelated environment is not an accepted RED.

After minimal implementation, run focused GREEN:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-green -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Expected GREEN: every Store acceptance test passes, schema is 11, the exact
v10 semantic snapshot is preserved, no planning data is inferred, and all
constraint/history/manifest tests pass.

Run the complete existing store and plugin-lifecycle migration boundary:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-regression -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests
```

Expected GREEN: all selected tests pass; lifecycle singleton behavior and
receipt persistence are unchanged except that the truthful current schema is
11. Then run `git diff --check`.

## Happy path

The verified fixture is copied and seeded, RED fails for missing v11 contracts,
the minimal public models and additive migration are added, focused tests turn
GREEN, relaunch preserves every v10 semantic field, future phases receive one
Legacy plan, deferred audit history commits correctly, continuation is
migration-only, regression tests pass, and independent reviews accept the
single coherent storage diff before its commit/push/remote checkpoint.

## Non-happy paths and recovery

- Fixture checksum mismatch, wrong schema version, or missing Task 1A remote
  checkpoint blocks Task 1B before test edits.
- Any migration failure must leave the original temporary v10 database and
  pre-migration snapshot recoverable at version 10; do not reset or rebuild it.
- Any cross-project/phase reference, invalid lifecycle/state, invalid criterion,
  duplicate assignment, post-v11 continuation grant, or missing authoritative
  audit must fail atomically with no sibling planning/history row.
- A counterfeit/missing critical index, trigger, foreign key, deferred rule,
  or required singleton must make the store unavailable through the existing
  recovery contract, not silently repair unknown drift.
- Existing In progress/Needs review receive the only continuation grant.
  Existing Blocked receives none; Accepted stays terminal history; Backlog gets
  none. No test may introduce a general continuation API.
- If observed-goal/link/notification identity changes, if any goal/assignment
  is inferred, or if an Accepted ticket changes, return NO-GO.
- No failure authorizes owner-data launch, board mutation, bridge use, direct
  production SQLite editing, or Task 2 implementation.

## Activity and audit evidence requirements

Production migration creates no success audit, Activity item, notification,
review item, command receipt, Delivery Goal, assignment, or assignment event.
Synthetic tests must prove one deferred assignment-event row points to the one
store-owned audit row when explicitly exercised, and failed transactions
create neither. Delivery Management records test/review/Git evidence; no live
Release Radar activity or ticket mutation is permitted.

## Acceptance criteria

- [ ] Task 1A is accepted, pushed, and remotely verified at an exact SHA.
- [ ] Preimplementation Architecture, TPM, QA/Test, Delivery Management, and
      Security/Privacy reviews are GO with Required 0 on this exact brief SHA.
- [ ] The checked-in v10 fixture digest passes before RED and remains unchanged.
- [ ] RED fails for absent v11 model/schema behavior, not fixture/environment
      failure.
- [ ] All specified public models and explicit public initializers exist and
      round-trip; observed-goal types/semantics remain unchanged.
- [ ] Schema version is exactly 11 with all five additive tables, the additive
      ticket column, exact constraints/indexes/triggers/FKs, and deferred audit
      validity registered in the manifest.
- [ ] Existing phases migrate to Legacy unassessed revision 0 using one
      timestamp; future phase insert creates exactly one Legacy plan.
- [ ] Migration creates zero goals, criteria, assignments, and assignment
      events and performs no inference.
- [ ] Only migrated In progress/Needs review tickets receive continuation;
      Blocked, Backlog, and Accepted do not; continuation can clear but cannot
      be granted post-v11.
- [ ] Accepted tickets, all five lanes, outcomes, dependencies, blockers,
      active phase, observed goals, exact ticket/Codex-goal links,
      notifications, audits, and receipts are field-for-field preserved through
      migration and relaunch.
- [ ] Constraint, composite-ownership, rollback, deferred-history, manifest,
      and `foreign_key_check` tests pass.
- [ ] The test-only late-migration abort proves the original and physical
      snapshot remain exact version 10 with no partial v11 state or generated
      evidence, and normal migration plus second relaunch succeeds after only
      the injected trigger is removed.
- [ ] Focused and regression commands pass; `git diff --check` passes.
- [ ] No owner-data launch/install, board mutation, RR-R10/RR-ROADMAP/ticket
      mutation, external state, unrelated refactor, dependency, or project-file
      change occurred.
- [ ] Postimplementation Code Review, QA/Test, Architecture, Security/Privacy,
      TPM, and Delivery Management return GO with Required 0.
- [ ] No partial or unverified commit exists; the exact Task 1B diff alone is
      staged after the complete gate.
- [ ] The accepted Task 1B commit is pushed and local HEAD equals the exact
      remote SHA with ahead/behind `0/0` before Task 2 opens.

## Required independent reviews

Before implementation: Architecture verifies the relational/authority contract;
TPM verifies split/dependency/scope; QA/Test verifies fixture, RED, preservation,
constraint, rollback, and regression strategy; Delivery Management verifies
release/Git/evidence gates; Security/Privacy verifies local-storage, migration,
deferred-audit, and no-owner-data boundaries. All must be GO, Required 0.

After implementation: a fresh Code Reviewer and fresh QA verifier independently
review the diff/results; Architecture, Security/Privacy, TPM, and Delivery
Management disposition the completed task. The Implementer cannot serve any of
those roles. Only Required findings block; optional and out-of-scope findings
do not expand Task 1B.

## Completion evidence required in `docs/delivery/progress.md`

Delivery Management must record:

- Task 1B status, Task 1A remote dependency SHA, Implementer identity, and exact
  Task 1B brief SHA
- fixture checksum verification and unchanged fixture Git identity
- named RED cases, exact RED command/failure reason, implementation summary,
  exact GREEN/regression commands/results, and `git diff --check`
- schema version, table/column/index/trigger/FK/deferred-rule evidence;
  migration timestamp/Legacy-plan counts; zero inferred planning-row counts;
  exact continuation ID set; and empty `foreign_key_check`
- late-v11 failure mechanism, `.migration` recovery projection, original/
  physical-snapshot rollback inventory, absence of partial rows/evidence, and
  recovery migration plus second-relaunch result
- semantic before/after/relaunch snapshot result, explicitly including Accepted
  history, active phase, observed goals, exact links, notifications, audit, and
  request receipt
- deferred assignment-event success and missing-audit rollback evidence
- pre- and postimplementation reviewer identities, dispositions,
  Required/Optional/Out-of-scope counts, and Required 0 closure
- confirmation of no owner-data launch, board/ticket/roadmap mutation, external
  state, or unrelated-file change
- exact staged paths, staged-diff review, commit SHA, push result, exact
  `git ls-remote` SHA, local/remote equality, and ahead/behind `0/0`
- remaining risks/blockers and Task 2 as next eligible only after the verified
  remote checkpoint

## Task-specific completion and Git boundary

Task 1B is complete only when all model/schema/migration/history requirements,
focused/regression checks, and independent postimplementation reviews are GO
with Required 0. Before that point, do not commit or push any Task 1B work.
Afterward, stage only:

```text
ReleaseRadarCore/Models/DeliveryGoalModels.swift
ReleaseRadarCore/Store/DeliveryStore.swift
ReleaseRadarCore/Store/StoreMigrations.swift
ReleaseRadarTests/StoreAcceptanceTests.swift
ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
docs/delivery/progress.md
```

Do not stage the unchanged Task 1A fixture, `default.profraw`, or unrelated
paths. Inspect the staged diff, commit the fully verified task, push
`codex/release-radar-mvp`, and verify local HEAD equals the exact remote branch
SHA with ahead/behind `0/0`. Task 2 remains closed until that checkpoint.
