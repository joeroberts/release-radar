# RR-R10 Task 3 Brief: Ticket-task Planning Policy

**Status:** Planning draft complete. Implementation remains closed until this
exact durable brief receives independent Architecture, TPM, QA/Test, Delivery
Management, and Security/Privacy GO with Required 0 and the Delivery Manager
releases Task 3.

## Size assessment and checkpoint decision

The accepted implementation plan forecasts Task 3 at 6–8 agent-hours. The task
has one coherent rejectable outcome: a direct Core policy that enforces
revisioned creation, revision, completion, supersession, and acceptance
preconditions against the schema-v12 Ticket Task substrate, plus one direct
acceptance-test file. Splitting the three policy entry points would temporarily
leave shared invariants inconsistent. Task 3 therefore remains one bounded
checkpoint.

If the implementation cannot remain within the two-file inventory below or
requires a schema, dispatcher, command, receipt, projection, UI, project-file,
or dependency change, stop before expanding scope and return to independent
planning review.

## Objective and user-visible outcome

Create the store-internal Ticket Task planning policy that makes a ticket's
optional task plan safe to create and revise, makes task completion monotonic,
preserves superseded history, and supplies the exact read-only precondition
later Accepted transitions must invoke.

There is no owner-visible UI or command in Task 3. The user-visible value is a
fail-closed Core boundary: later command and acceptance work can rely on one
transactional policy instead of writing task rows directly. Completing all
active tasks still does not move the ticket, request review, create owner
attention, or notify anyone.

## Controlling references

- `docs/design/release-radar-ticket-tasks-design.md`, especially Data contract,
  Plan invariants, Typed mutation contract, Audit/replay/failure, and
  Acceptance criteria; inspected SHA-256
  `c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08`
- `docs/architecture/ADR-005-ticket-task-work-plans.md`, especially Decision and
  Persistence boundary; inspected SHA-256
  `6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5`
- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`, active
  revised Task 3 at lines 1484 onward; inspected SHA-256
  `2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1`
- `docs/delivery/progress.md`, which records Task 2B complete and Task 3 as the
  next eligible task; inspected SHA-256
  `f31cc54e2625f1e8fe1971a2a7469a43ae4af32896d8bddcb88368cf6400bb6c`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md`
  for the accepted substrate lineage; current implementation source, not the
  brief's historical recovery amendments, is authoritative for the starting
  model and schema inventory.
- `ReleaseRadarCore/Models/TicketTaskModels.swift`, inspected SHA-256
  `b323585a9d487505f77545b52ea5fb42597b454d5770c5788906247484e88193`
- `ReleaseRadarCore/Store/StoreMigrations.swift`, inspected SHA-256
  `b36cbe0626f27a967536aad559cd3d0f7621ac18f96de23976bd18392c25c6a8`
- `ReleaseRadarCore/Store/DeliveryStore.swift`, inspected SHA-256
  `67503c749948c42dd0d86df2daa4dd2db441b411dbef7b6d845ee47db162e9e5`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`, inspected SHA-256
  `837084bc38e0da903e142664bf2e486a1932f55f20fc493d50f83226c214538d`

The Ticket Tasks UI and Phase Board mockup are downstream Task 5 references.
Task 3 changes no visual surface and authorizes no design deviation.

## Dependencies and release gate

At planning inspection, the repository was on
`codex/release-radar-mvp` at local/upstream SHA
`feb4600e3d0d4125b93f061445850dfc2f9def51`, ahead/behind `0/0`, with a clean
working tree. The completed Task 2B implementation checkpoint is ancestor
`f122b61603d1b8f467f039b27810b8816c8e4686`. Those facts establish planning
eligibility; they do not authorize implementation.

Before the RED edit:

1. This exact tracked brief must receive independent Architecture, TPM,
   QA/Test, Delivery Management, and Security/Privacy review with GO and
   Required 0.
2. Architecture's independent review has explicitly approved the
   `auditEventID` interface correction under **Resolved interface ambiguity**
   below. The final Architecture review must confirm that this approved
   correction remains intact; no interface decision is still open.
3. Delivery Management must record the reviewed brief as the active Task 3
   brief in `docs/delivery/progress.md`, commit and push the planning
   checkpoint through the repository's accepted cadence, and verify the chosen
   implementation base is exact locally and upstream with ahead/behind `0/0`.
4. A fresh Implementer must own exactly the two implementation paths. The
   Planning agent and every reviewer remain independent of that writer.
5. No concurrent writer may modify either implementation path or the
   schema-v12 store/model substrate during this checkpoint.

The first failing mechanism permits only the bounded diagnosis/correction
allowed by repository instructions. A second failure of that same mechanism
stops Task 3; it does not authorize a harness or scope expansion.

## In scope

- Create `TicketTaskPlanningPolicy` and its exact public error contract.
- Create a plan only when no plan exists and `expectedRevision` is `nil`.
- Revise an existing plan only at the exact positive current revision.
- Add only Active/Pending tasks.
- Definition-revise only the title and/or sort order of an Active/Pending task.
- Complete one Active/Pending task exactly once.
- Supersede Active/Pending or Active/Completed tasks while preserving
  completion and completion timestamp.
- Enforce at least one active task in every committed plan, including atomic
  last-task replacement.
- Enforce operation, duplicate-ID, ownership, immutable-history, UTF-8 byte,
  no-op, and Accepted-ticket boundaries before effects become visible.
- Supply a read-only `assertCanAcceptTicket` precondition that distinguishes
  atomic no-plan tickets from exact-revision loaded plans and requires every
  active task to be complete.
- Use existing `DeliveryStore.transact` ownership for serialization, rollback,
  and audit insertion.
- Verify all behavior in one new direct policy acceptance-test file and run the
  existing Store acceptance boundary unchanged.

## Out of scope

- Changes to schema-v12 tables, indexes, triggers, manifests, migrations,
  `DeliveryStore`, `SQLiteConnection`, or Ticket Task model definitions.
- Durable request receipts, request-ID replay, changed-body replay,
  `outcomeUnknown`, canonical command bytes, dispatcher result mapping, or MCP
  schemas. Task 4B owns those command-layer behaviors.
- Any ticket lane mutation or routing of existing Accepted entry points. Task
  4A owns the shared transition gate and Accepted `upsertTicket` closure.
- Agent commands, bridge transport, MCP tools, owner actions, import/sample/
  debug writers, notifications, review requests, or owner-attention changes.
- Phase-plan or Delivery Goal state/revision changes.
- Projection, task count, Ticket Details, UI, accessibility, screenshots, or
  runtime visual comparison.
- Creation or mutation of the live RR-R10 16-row task plan, owner database/app
  access, app install/launch, signing, sandbox, or external systems.
- Fixture, fixture checksum, `ReleaseRadar.xcodeproj/project.pbxproj`,
  dependency, package, script, validator, feature-flag, or custom harness
  changes.
- Implementer edits to this brief or `docs/delivery/progress.md`. Delivery
  Management owns ledger changes after independent evidence review.

## Affected subsystem and exact file inventory

Implementation creates exactly:

- `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift`
- `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift`

The Xcode project already uses file-system-synchronized groups for
`ReleaseRadarCore` and `ReleaseRadarTests`; no project-file registration is
needed. Production implementation may consume but not modify:

- `ReleaseRadarCore/Models/TicketTaskModels.swift`
- `ReleaseRadarCore/Store/DeliveryStore.swift`
- `ReleaseRadarCore/Store/SQLiteConnection.swift`
- `ReleaseRadarCore/Store/StoreMigrations.swift`

After verification, the coordinator may separately modify only
`docs/delivery/progress.md` to record the accepted checkpoint. No other file is
anticipated.

## Resolved interface ambiguity

The active Task 3 plan lists `auditEventID` in `revisePlan`, omits it from
`completeTask`, and returns only `TicketTaskPlanRecord`. The implemented
transaction boundary establishes that:

- `DeliveryStore.transact(actor:reason:auditEventID:auditScope:_:)` alone
  inserts `audit_events` after the callback;
- transaction callbacks are denied direct audit-table mutation;
- `ticket_task_plans` and `ticket_tasks` have no audit-ID column; and
- neither revision logic nor the returned plan record consumes an audit ID.

Therefore Task 3 must not preserve an unused `auditEventID` policy parameter.
The caller supplies the ID exactly once to `DeliveryStore.transact`; the policy
receives only its transaction-scoped `SQLiteConnection`. This makes revise and
complete symmetric and preserves store-owned audit authority. Task 4B will
generate the request's audit ID, pass it to the store transaction, and return
the committed ID from its command result without routing it through policy
SQL.

This is a narrow correction to the active plan's displayed signature, not a
change to the approved audit outcome. Independent Architecture review
explicitly approved this correction. The Implementer must not add an ignored
parameter or move audit insertion into the policy.

The accepted design also describes richer operation identities and replay
evidence. Task 3 proves the existing authoritative audit row's atomicity and
`.ticketTaskPlan` scope. Task 4B's canonical command/receipt layer owns request
identity, exact replay, changed-body rejection, and operation-specific command
evidence; Task 3 adds no shadow audit payload or schema.

## Exact public API

Create a non-instantiable public policy namespace with these constants and
methods:

```swift
public enum TicketTaskPlanningPolicy {
    public static let maximumOperationsPerRevision = 64
    public static let maximumTaskIDUTF8Bytes = 256
    public static let maximumTaskLabelUTF8Bytes = 256
    public static let maximumTaskTitleUTF8Bytes = 4_096

    public static func revisePlan(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedRevision: Int64?,
        additions: [TicketTaskDraft],
        definitionRevisions: [TicketTaskDefinitionRevision],
        supersededTaskIDs: [TicketTaskID],
        connection: SQLiteConnection
    ) throws -> TicketTaskPlanRecord

    public static func completeTask(
        projectID: ProjectID,
        ticketID: TicketID,
        taskID: TicketTaskID,
        expectedRevision: Int64,
        connection: SQLiteConnection
    ) throws -> TicketTaskPlanRecord

    public static func assertCanAcceptTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedRevision: Int64?,
        connection: SQLiteConnection
    ) throws
}
```

The methods are synchronous because they run within a synchronous
`DeliveryStore` transaction/read callback. They do not retain the connection
or begin, commit, savepoint, or roll back a transaction.

Create these exact public typed errors in the same file:

```swift
public enum InvalidTicketTaskMutationReason: Equatable, Sendable {
    case ticketNotFound
    case acceptedTicket
    case emptyOperationSet
    case invalidCreationOperations
    case operationLimitExceeded(actual: Int, maximum: Int)
    case duplicateOperationTaskID(TicketTaskID)
    case invalidTaskID(TicketTaskID)
    case invalidLabel(taskID: TicketTaskID)
    case invalidTitle(taskID: TicketTaskID)
    case invalidSortOrder(taskID: TicketTaskID)
    case emptyDefinitionRevision(TicketTaskID)
    case noEffectiveDefinitionRevision(TicketTaskID)
    case taskIDAlreadyUsed(TicketTaskID)
    case labelAlreadyUsed(String)
    case revisionExhausted
}

public enum TicketTaskPlanningPolicyError:
    Error, LocalizedError, Equatable, Sendable
{
    case ticketTaskPlanNotFound
    case ticketTaskPlanAlreadyExists
    case ticketTaskPlanRevisionConflict(expected: Int64?, current: Int64)
    case ticketTaskNotFound(TicketTaskID)
    case ticketTaskImmutable(TicketTaskID)
    case ticketTaskIncomplete(pendingTaskIDs: [TicketTaskID])
    case ticketTaskReplacementRequired
    case invalidTicketTaskMutation(InvalidTicketTaskMutationReason)
}
```

`errorDescription` must be actionable and contain no sensitive store content.
Tests match enum cases and associated values, not prose. The error cases map as
follows:

- Missing plan when a present revision is required:
  `.ticketTaskPlanNotFound`.
- Existing plan when `expectedRevision == nil`:
  `.ticketTaskPlanAlreadyExists`.
- Loaded plan without an expected revision, or any expected/current mismatch:
  `.ticketTaskPlanRevisionConflict(expected:current:)` with the actual current
  revision.
- Missing targeted task:
  `.ticketTaskNotFound(id)`.
- Definition revision of Completed or Superseded, completion of Completed or
  Superseded, or re-supersession:
  `.ticketTaskImmutable(id)`.
- Acceptance with pending active tasks:
  `.ticketTaskIncomplete`, whose IDs use canonical active-task order.
- A final state with zero active tasks:
  `.ticketTaskReplacementRequired`.
- All validation, no-op, limit, reuse, missing-ticket, Accepted-ticket, and
  exhausted-revision cases use the exact
  `.invalidTicketTaskMutation(reason)` value above.

A project/ticket ownership mismatch returns the same not-found category as a
missing record and does not disclose cross-project content.

## Policy invariants and operation semantics

### Shared validation

Before issuing any SQL, all three entry points inspect the raw composite owner
identities. If `projectID.rawValue` or `ticketID.rawValue` contains an embedded
NUL, reject as
`.invalidTicketTaskMutation(.ticketNotFound)`. This intentionally uses the
existing non-disclosing missing-ticket category: no SQL is prepared or bound,
and no row, audit, or adjacent state changes. This preflight is required
because the current SQLite text binder supplies `-1` length and an embedded
NUL must never be allowed to truncate an ownership predicate.

After that preflight, all three entry points require a ticket row matching both
`project_id` and `id`. Mutation entry points reject lane `accepted` as
`.invalidTicketTaskMutation(.acceptedTicket)`. Exact command replay will be
resolved outside the policy before invocation in Task 4A/4B.

For `revisePlan`, validate the complete request before the first write:

- Total operations are exactly
  `additions.count + definitionRevisions.count + supersededTaskIDs.count`.
- Zero rejects as `.emptyOperationSet`; totals 1 through 64 are eligible; 65
  or more reject with exact actual/maximum values.
- A task ID may appear only once across the concatenation of all three arrays.
  Repetition within one array or across arrays rejects as
  `.duplicateOperationTaskID(id)`.
- Two distinct additions may not carry BINARY-equal labels. Detect that
  collision in memory before the first write and reject as
  `.labelAlreadyUsed(label)`. A case-distinct pair such as `Task A` and
  `task a` is valid because the schema contract uses `COLLATE BINARY`.
- Every task ID is nonempty, contains no embedded NUL, is not whitespace-only,
  and has 1–256 encoded UTF-8 bytes.
- Every label is nonempty after trimming only for the emptiness check, contains
  no embedded NUL, and has 1–256 encoded UTF-8 bytes. Persist the supplied
  string unchanged; never trim or truncate it.
- Every title is nonempty after trimming only for the emptiness check, contains
  no embedded NUL, and has 1–4,096 encoded UTF-8 bytes. Persist the supplied
  string unchanged; never trim or truncate it.
- Every sort order is nonnegative. Duplicate sort orders are allowed because
  canonical byte-order tie-breakers are defined.
- A definition revision must supply a title, a sort order, or both. A supplied
  revision whose resulting title and sort order equal the existing values
  rejects as `.noEffectiveDefinitionRevision(id)`, even if another operation
  in the same request would change state.
- IDs and labels are compared with SQLite `BINARY` semantics and may never
  reuse any historical row, including Active and Superseded rows. Historical
  label reuse rejects as `.labelAlreadyUsed(label)`; historical ID reuse
  rejects as `.taskIDAlreadyUsed(id)`.

Core performs these checks before relying on schema CHECK/UNIQUE constraints.
An unexpected SQLite constraint failure still propagates and the store rolls
back the transaction; it is not converted into success.

### Create

`expectedRevision == nil` is create-only:

- the ticket must exist and not be Accepted;
- no plan may exist;
- `additions` must contain at least one task;
- `definitionRevisions` and `supersededTaskIDs` must be empty; and
- every addition is inserted as `completion = pending`, `lifecycle = active`,
  with `completed_at` and `superseded_at` NULL.

Supplying a definition revision or supersession in create mode rejects as
`.invalidTicketTaskMutation(.invalidCreationOperations)`. Create mode with no
addition rejects as `.invalidTicketTaskMutation(.emptyOperationSet)`.

The plan and all additions commit at revision 1. Revision 0 is never returned
or stored. The returned `TicketTaskPlanRecord` is loaded from the persisted
row, not reconstructed with divergent timestamps.

### Later revision

A present `expectedRevision` requires an existing plan at that exact positive
revision. Any stale value returns the current revision and changes nothing.

Within one transaction:

- additions create new Active/Pending historical identities;
- definition revisions update only `title`, `sort_order`, and `updated_at` of
  Active/Pending rows;
- supersessions update only `lifecycle`, `superseded_at`, and `updated_at` of
  Active rows;
- superseding a Completed task preserves `completion = completed` and the
  original non-NULL `completed_at` exactly;
- untouched rows remain byte-semantically unchanged; and
- no DELETE statement is used.

Validate the final transaction state after all requested row changes. It must
contain at least one Active row. This permits adding a replacement and
superseding the prior last Active task atomically, but rejects a zero-active
final state with `.ticketTaskReplacementRequired` and full rollback.

One successful later revision updates the plan from R to R+1 exactly once and
updates `ticket_task_plans.updated_at`. A shared pre-write revision-advance
check guards `R == Int64.max` as
`.invalidTicketTaskMutation(.revisionExhausted)` rather than overflowing. It
applies to both `revisePlan` and `completeTask` before either changes a task or
plan row. A rejected or semantically empty request does not advance the
revision.

### Complete

`completeTask` requires an existing plan at exact `expectedRevision`, then an
Active/Pending task matching the supplied project, ticket, and task ID. It
changes only that row to Completed, sets `completed_at` and `updated_at`, and
advances the plan once from R to R+1. It does not change lifecycle, label,
title, order, lane, review, notification, or phase/goal state.

Completing an already Completed task, a Superseded task of either completion
state, or a task on an Accepted ticket rejects without effects. Exact replay
of the original external request is a Task 4B receipt concern and does not call
`completeTask` a second time.

### Acceptance assertion

`assertCanAcceptTicket` is read-only and implements exactly this matrix:

| Persisted state | Supplied revision | Result |
| --- | --- | --- |
| No plan | `nil` | Success; atomic-ticket path may continue. |
| No plan | Present | `.ticketTaskPlanNotFound`. |
| Loaded plan | `nil` | Revision conflict with current revision. |
| Loaded plan | Stale | Revision conflict with current revision. |
| Loaded exact plan with pending Active rows | Exact | `.ticketTaskIncomplete` in canonical order. |
| Loaded exact plan with all Active rows Completed | Exact | Success. |
| Already Accepted ticket, with or without a plan | Any | `.invalidTicketTaskMutation(.acceptedTicket)`. |

The assertion does not mutate the lane, revision, task rows, audit table,
review items, owner attention, notifications, or Delivery Goal/phase-plan
state. Task 4A must invoke it inside the same store-owned Accepted transition
transaction before changing the lane; this method alone grants no transition
authority. Invoking it for an already Accepted ticket rejects as
`.invalidTicketTaskMutation(.acceptedTicket)`; a later exact receipt replay is
resolved before policy invocation.

## SQL, transaction, audit, and timestamp ownership

The policy uses private SQL helpers in its new production file only. Required
query/write shapes are:

- Load ticket ownership/lane with `WHERE project_id = ? AND id = ?`.
- Load a plan with `WHERE project_id = ? AND ticket_id = ?`.
- Load targeted tasks with the full composite key.
- Load active or pending-active rows in canonical order:
  `ORDER BY sort_order, label COLLATE BINARY, id COLLATE BINARY`.
- Insert the plan once at revision 1.
- Insert additions with explicit columns and Pending/Active constants.
- Guard task updates by the preloaded composite identity and eligible state.
- Update the plan once with `WHERE revision = expectedRevision`, then require
  exactly one changed row.
- Count the final Active rows before returning.
- Reload and decode the committed candidate plan row into
  `TicketTaskPlanRecord` before the callback returns.

No SQL string interpolates user input; every value uses `SQLiteValue`
bindings. No helper starts transaction control or writes `audit_events`.

Mutation tests and later callers invoke the policy only inside
`DeliveryStore.transact(actor:reason:auditEventID:auditScope:_:)` with:

```swift
AuditScope(
    projectID: projectID,
    entityType: .ticketTaskPlan,
    entityID: ticketID.rawValue
)
```

`DeliveryStore` owns `BEGIN IMMEDIATE`, callback lease restrictions, the one
audit insert, COMMIT, and rollback. A policy error or a failure during the
store-owned audit insert rolls back plan/task writes and creates no audit row.
Task 3 creates no receipt, review, attention, or notification row.

Each successful policy mutation captures one UTC instant after validation and
before its first write. Format it once with `ISO8601DateFormatter` using
`[.withInternetDateTime, .withFractionalSeconds]`; use that exact stored text
for the plan and every task touched by the operation. Reload the plan so the
returned dates reflect persisted text. Timestamp rules are:

- creation: plan/task `created_at == updated_at == operation instant`;
- definition revision: only targeted task `updated_at` changes;
- completion: targeted task `updated_at == completed_at == operation instant`;
- supersession: targeted task `updated_at == superseded_at == operation
  instant`, while any existing `completed_at` is unchanged; and
- every successful later mutation: plan `updated_at == operation instant` and
  `created_at` unchanged.

The store creates its audit timestamp after the callback; it need not equal the
policy timestamp. Tests assert equality among columns owned by the policy and
preservation/ordering relationships, not wall-clock prose or a hard-coded
current time.

## Data, persistence, security, and privacy implications

- This task mutates only local schema-v12 `ticket_task_plans` and
  `ticket_tasks` through the existing app-process writer boundary.
- Composite project/ticket predicates prevent cross-project and cross-ticket
  access. Not-found errors do not reveal the mismatched owner's content.
- Immutable IDs/labels, no-delete triggers, and historical rows remain the
  database backstop; policy validation adds clearer fail-closed behavior.
- UTF-8 checks use `String.utf8.count`, not grapheme or character counts. No
  input is normalized, truncated, logged, or echoed in audit metadata by this
  policy.
- Task titles and labels may be user content. Failure evidence and the progress
  ledger record scalar outcomes/test counts only, never row values or database
  dumps.
- No credential, network, external service, owner store, application install,
  permission, entitlement, signing, sandbox, import/export, or portable
  artifact boundary changes.
- Task-only mutation must leave `phase_plans`, `delivery_goals`, goal criteria,
  assignments/events, ticket lane/outcome/phase, review items, owner attention,
  notifications, and command receipts unchanged.

## Test fixtures and strategy defined before implementation

All tests live in the new
`TicketTaskPlanningPolicyAcceptanceTests.swift`. Use XCTest and existing
repository APIs only; add no fixture file, dependency, clock framework, test
harness, or Store test modification.

Each test creates a fresh temporary database URL and `DeliveryStore`, verifies
availability, and seeds through one audited store transaction:

- project `task-project`, phase `task-phase`;
- atomic/no-plan ticket `TASK-ATOMIC` in Backlog;
- mutable tickets `TASK-CREATE`, `TASK-REVISE`, and `TASK-LIMIT` in In progress;
- acceptance ticket `TASK-ACCEPT` in Needs review;
- terminal ticket `TASK-TERMINAL` in Accepted;
- terminal no-plan ticket `TASK-TERMINAL-ATOMIC` in Accepted;
- second project `other-project`, phase `other-phase`, and ticket `TASK-OTHER`
  for ownership tests; and
- the automatically created phase-plan rows, which are snapshotted before
  task mutation.

The same seed transaction creates valid, nonempty adjacent-state sentinels:

- Draft Delivery Goal `task-sentinel-goal`, done criterion
  `task-sentinel-criterion`, assignment of `TASK-REVISE`, and one `assigned`
  `delivery_goal_assignment_events` row bound to the seed transaction's known
  audit ID;
- open blocker `task-sentinel-blocker` and open review item
  `task-sentinel-review` for `TASK-REVISE`; these are the current-schema
  owner-attention sentinels because there is no separate owner-attention table;
- notification event `task-sentinel-notification` and active notification
  occurrence `task-project|task-sentinel-occurrence`; and
- agent command receipt `task-sentinel-request` with fixed nonempty synthetic
  request/result BLOB bytes.

All sentinel foreign keys and state/timestamp combinations must be valid.
They contain only synthetic test data and remain adjacent evidence; they do
not authorize task planning or affect the policy result.

Tests may create task plans through the policy after seeding. Only the terminal
immutability fixture may seed a valid plan/tasks before setting its ticket lane
to Accepted in the same fixture transaction; this is test setup for a state
Task 4A will later protect, not a production bypass.

Use a test-private snapshot helper in this same test file—no separate harness—
that reads, in stable primary/canonical order:

- the target ticket lane/outcome/phase;
- its plan row and every task column;
- phase-plan and Delivery Goal rows/revisions;
- audit count and target plan-scope audit rows;
- review/attention rows;
- notification rows; and
- command-request receipt rows.

Every rejection captures this snapshot immediately before the call and asserts
exact equality afterward. Successful task-only mutations assert only the
expected plan/task/audit delta and exact equality for all other state. The
snapshot retains ordered `[SQLiteValue]` rows, including exact BLOB data, so
representative successful revision/completion and representative rejection
tests prove byte-exact preservation of the seeded Delivery Goal, criterion,
assignment/event, blocker/review attention, notification, occurrence, and
request-receipt sentinels.

Boundary strings are exact:

- ASCII ID/label: 255, 256, and 257 single-byte characters.
- Multibyte ID/label: 127 `é` plus `a` (255 bytes), 128 `é` (256 bytes), and
  128 `é` plus `a` (257 bytes).
- ASCII title: 4,095, 4,096, and 4,097 single-byte characters.
- Multibyte title: 2,047 `é` plus `a` (4,095 bytes), 2,048 `é` (4,096 bytes),
  and 2,048 `é` plus `a` (4,097 bytes).

Exact-limit and limit-minus-one values succeed; limit-plus-one values reject at
the Core boundary without truncation or effects. Also reject empty,
whitespace-only, and embedded-NUL ID/label/title values. Persisted successful
values must round-trip byte-for-byte.

Separate ownership-preflight cases pass `"task\0-project"` as the project raw
value and `"TASK\0-REVISE"` as the ticket raw value to each of the three policy
entry points. Every call must return the exact non-disclosing
`.invalidTicketTaskMutation(.ticketNotFound)` error before SQL and preserve the
complete snapshot, including all adjacent sentinels.

Operation-limit fixtures exercise aggregate, not per-array, bounds on separate
fresh tickets. Distribute 63 operations as 21 additions + 21 definition
revisions + 21 supersessions; 64 as 22 + 21 + 21; and 65 as 22 + 22 + 21.
Seed enough distinct eligible Active/Pending rows that every revision and
supersession is otherwise valid and every successful final plan remains
nonempty. Both 63 and 64 commit; 65 rejects with
`.operationLimitExceeded(actual: 65, maximum: 64)` and an unchanged snapshot.

## Required tests

The RED file defines focused tests covering these behaviors (names may be
combined only when all assertions remain explicit and failure-local):

1. `testNoPlanAcceptanceRequiresNilRevisionAndHasNoEffects`
2. `testCreationRequiresNilRevisionAndReturnsRevisionOne`
3. `testCreationRejectsEmptyOrNonCreationOperationsWithoutEffects`
4. `testPlanExistenceAndStaleRevisionErrorsReturnTypedCurrentState`
5. `testMixedRevisionAdvancesExactlyOnceAndUsesCanonicalOrdering`
6. `testDefinitionRevisionAllowsOnlyEffectiveActivePendingTitleOrOrderChanges`
7. `testCompletionIsMonotonicAndAdvancesExactlyOnce`
8. `testSupersessionPreservesCompletionAndCompletedTimestamp`
9. `testLastActiveTaskRequiresAtomicReplacement`
10. `testDuplicateIDsWithinAndAcrossOperationArraysRejectWithoutEffects`
11. `testHistoricalIDsAndLabelsCannotBeReused`
12. `testOperationCountAcceptsSixtyThreeAndSixtyFourAndRejectsSixtyFive`
13. `testASCIIAndMultibyteUTF8BoundariesRejectWithoutTruncation`
14. `testInvalidEmptyWhitespaceNULAndSortOrderValuesRejectWithoutEffects`
15. `testAcceptedTicketPlanRejectsRevisionCompletionAndSupersession`
16. `testAcceptanceRequiresExactRevisionAndEveryActiveTaskCompleted`
17. `testWrongProjectAndTicketOwnershipFailClosed`
18. `testTaskOnlyMutationsPreserveTicketLanePhasePlanGoalsAndDeliveryEffects`
19. `testLateStoreAuditFailureRollsBackPlanTasksRevisionAndAuditAtomically`
20. `testProjectAndTicketEmbeddedNULRejectBeforeSQLAcrossEveryEntryPoint`
21. `testAdditionLabelsPreflightBinaryDuplicatesAndAllowCaseDistinctValues`
22. `testLabelReuseAgainstActiveAndSupersededHistoryRejectsWithoutEffects`
23. `testCurrentRevisionRejectsEmptyLaterRevisionWithoutEffects`
24. `testNoEffectiveDefinitionRevisionRejectsEvenWithEffectiveAddition`
25. `testRevisionExhaustionRejectsReviseAndCompleteBeforeEffects`
26. `testMissingDefinitionCompletionAndSupersessionTargetsReturnTypedErrors`
27. `testAggregateOperationLimitSpansAllThreeOperationArrays`
28. `testAcceptedNoPlanRejectsCreationAndAcceptedPlanRejectsAcceptanceAssertion`
29. `testAdjacentDeliverySentinelsRemainByteExactAcrossSuccessAndRejection`

The duplicate test covers same-array duplicates for additions, revisions, and
supersessions and every pairwise cross-array collision. The lifecycle tests
cover pending and completed supersession, definition-revising/completing a
Superseded task, completing a Completed task, and re-supersession. All reject
cases assert exact plan/task/audit snapshots.

The explicit edge tests additionally pin these cases rather than leaving them
implicit in a loop or nearby assertion:

- an all-empty later revision at the exact current revision returns
  `.invalidTicketTaskMutation(.emptyOperationSet)`;
- a no-effective definition revision combined with an otherwise-valid
  addition rejects the entire request as
  `.invalidTicketTaskMutation(.noEffectiveDefinitionRevision(id))`;
- a plan seeded at `Int64.max` rejects both `revisePlan` and `completeTask` as
  `.invalidTicketTaskMutation(.revisionExhausted)` before any task update;
- missing definition-revision, completion, and supersession targets each
  return `.ticketTaskNotFound(theMissingID)` with unchanged state;
- two distinct additions with the same BINARY label reject before write;
  reuse against both Active and Superseded rows rejects; and case-distinct
  labels commit and round-trip unchanged; and
- first-plan creation on `TASK-TERMINAL-ATOMIC` and acceptance assertion on
  `TASK-TERMINAL` both reject as
  `.invalidTicketTaskMutation(.acceptedTicket)` with byte-exact state.

The late-failure test first consumes a chosen `AuditEventID` in a harmless
store transaction, then attempts a mixed valid policy revision inside another
`DeliveryStore.transact` using that same ID. The callback performs candidate
writes, the store-owned audit insert fails uniqueness, and the final snapshot
must prove full rollback. This directly verifies audit/transaction ownership
without a fault-injection framework.

`assertCanAcceptTicket` tests run through `DeliveryStore.read` when testing the
assertion alone so success itself creates no audit. They prove no-plan/nil,
no-plan/present, loaded/nil, loaded/stale, loaded/exact/pending, and loaded/
exact/all-complete results, plus the explicit already-Accepted rejection, an
unchanged lane, and byte-exact review, notification, receipt, and
owner-attention sentinels.

## Happy paths

- Create a nonempty plan at nil expected revision; receive persisted revision
  1 and Active/Pending tasks in canonical order.
- At revision R, add tasks, revise Active/Pending definitions, and supersede
  obsolete Active tasks in one bounded transaction; receive R+1 once.
- Atomically add a replacement while superseding the previous last Active task.
- Complete one Active/Pending task at exact revision; receive R+1 while lane
  and all structural planning state remain unchanged.
- Supersede pending or completed work while preserving its completion fields.
- Accept assertion succeeds for an atomic no-plan ticket with nil revision.
- Accept assertion succeeds for a loaded exact-revision plan when every Active
  row is Completed.

## Non-happy paths

- Missing/wrong-owner tickets or plans, existing-plan creation, stale/missing
  expected revisions, invalid or duplicate inputs, historical ID/label reuse,
  over-limit requests, empty/no-op revisions, and revision exhaustion fail
  before commit.
- Embedded NUL in either composite owner identity rejects before SQL through
  the non-disclosing missing-ticket category.
- BINARY-equal labels across distinct additions reject in memory; case-distinct
  labels remain distinct and valid.
- Missing, Completed, or Superseded targets reject according to the typed error
  map.
- Superseding the final Active task without a same-transaction replacement
  rolls back every candidate change.
- Any plan mutation on an Accepted ticket rejects. Exact replay is handled
  outside this policy in later command work.
- Acceptance with a missing/mismatched plan revision or any pending Active task
  rejects without lane or delivery side effects.
- A SQLite or store-owned audit failure rolls back all candidate task/plan
  writes and emits no second audit.

## Test-first execution

### RED

The fresh Implementer first creates only
`ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift` with the
fixtures and tests above. Before creating production policy code, run exactly:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task3-red \
  -only-testing:ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests
```

Expected RED: build/test failure attributable only to the absent
`TicketTaskPlanningPolicy`, `TicketTaskPlanningPolicyError`, and
`InvalidTicketTaskMutationReason` production API. A passing RED, an unrelated
compile/test failure, zero selected tests, or a failure requiring changes
outside the two-file inventory stops the task.

### GREEN and Store boundary

After valid RED, create only
`ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift` and implement the
minimum policy described by this brief. Run exactly from fresh DerivedData:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task3-green \
  -only-testing:ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Both selected suites must execute and pass. Do not substitute build success,
linting, CodeGraph output, or unrelated tests for this behavior evidence. Do
not add a broader suite unless an independent reviewer identifies a concrete
Task 3 regression risk that the selected policy plus Store boundary cannot
cover.

After GREEN, run `git diff --check` and inspect the exact diff/stat to confirm
only the two implementation files changed. DerivedData and test logs are
temporary, are not source of truth, and must not be committed or cited as the
controlling brief.

No tests are authorized or run during this planning action.

## Activity and audit evidence requirements

Successful `revisePlan` and `completeTask` test calls must be wrapped in one
store transaction with an explicit unique `AuditEventID` and the exact
`.ticketTaskPlan` scope. Evidence must prove:

- one successful mutation produces exactly one audit row;
- audit `project_id`, `entity_type`, and `entity_id` identify the exact ticket
  task plan;
- returned plan revision and persisted plan revision match;
- rejected policy calls produce no audit row;
- late audit insertion failure rolls back the candidate policy mutation; and
- acceptance assertion alone produces no audit or other delivery effect.

The test actor and reason are synthetic and non-sensitive. Task 3 does not
claim durable request replay or operation-body audit payload; those remain
Task 4B responsibilities at the command/receipt boundary.

## Acceptance criteria

- The only implementation files are the exact new policy and test files.
- The public methods, constants, and typed errors match this brief, including
  the Architecture-approved omission of policy-level `auditEventID`.
- No-plan tickets remain valid; nil revision is create-only; creation returns
  revision 1; every later successful mutation returns R+1 exactly once.
- Every committed plan has at least one Active task. Atomic last-task
  replacement succeeds; zero-active final state rolls back.
- Machine IDs and labels are immutable and never reused; task rows are never
  deleted; Completed never returns to Pending.
- Additions are always Active/Pending. Definition revision is limited to
  effective title/order changes on Active/Pending tasks.
- Pending and Completed supersession preserve completion semantics and
  timestamps. Completing/revising Superseded tasks, completing Completed tasks,
  and re-supersession reject without effects.
- Same-array and cross-array duplicate IDs reject without effects.
- Same-request BINARY-equal labels across distinct additions and historical
  label reuse against Active or Superseded rows reject before effects;
  case-distinct BINARY labels succeed.
- Aggregate operation totals spanning all three arrays accept 63 and 64 when
  valid; 65 rejects.
- ASCII and multibyte ID/label 255/256/257-byte and title
  4,095/4,096/4,097-byte boundaries are enforced with no truncation.
- Embedded NUL in project or ticket raw identity rejects before SQL for all
  three entry points with the non-disclosing missing-ticket category.
- Empty later revision, mixed no-effective definition revision, missing
  targets, and `Int64.max` exhaustion for both revision and completion have
  exact typed-error and unchanged-state coverage.
- Canonical task order is `sort_order`, binary label, then binary task ID.
- Accepted ticket plans are immutable at the policy boundary; first-plan
  creation on an Accepted no-plan ticket and acceptance assertion on an
  already Accepted ticket both reject unchanged.
- Acceptance assertion distinguishes no plan from loaded plan, requires exact
  revision and all Active tasks Completed, and has no lane-mutation authority.
- Task-only changes leave ticket lane/outcome/phase, phase-plan state/revision,
  Delivery Goals, reviews, attention, notifications, and receipts unchanged.
- Valid nonempty Delivery Goal/criterion/assignment/event, blocker/review
  attention, notification/occurrence, and request-receipt sentinels remain
  byte-exact across representative success and rejection.
- Store-owned audit insertion is exactly once on success and atomic with
  policy writes; rejected and late-failed mutations have zero effects.
- The targeted GREEN command passes both the new policy suite and existing
  Store boundary from fresh DerivedData, followed by `git diff --check`.
- Fresh independent Code Review, QA/Test, Architecture, Security/Privacy, TPM,
  and Delivery Management return GO with Required 0 before checkpoint.
- The bounded implementation checkpoint is committed/pushed through the
  accepted cadence and is exact locally/upstream with ahead/behind `0/0`
  before Task 4A opens.

## Required independent reviews

Before implementation:

- **Architecture:** transaction/audit ownership, exact public API and typed
  errors, final-state invariant, timestamp strategy, and preservation of its
  explicit approval of the `auditEventID` signature correction.
- **QA/Test:** fixture isolation, RED validity, all boundary matrices,
  deterministic ordering, rollback snapshots, and exact commands.
- **Security/Privacy:** composite ownership, input/UTF-8 handling, audit
  atomicity, absence of owner/external access, and sanitized evidence.
- **TPM:** dependency safety, 6–8 hour coherence, Task 4A/4B boundary, and no
  scope expansion.
- **Delivery Management:** Task 2B dependency closure, exact file inventory,
  writer independence, planning checkpoint, and release state.

After implementation, a fresh Code Reviewer and QA verifier independently
review the result; Architecture, Security/Privacy, TPM, and Delivery Management
also confirm their boundaries. The Implementer may not approve or independently
verify its own work. Only Required findings block completion; optional or
out-of-scope recommendations do not expand Task 3.

## Completion evidence expected in the progress ledger

Delivery Management records concise scalar evidence only:

- exact reviewed brief identity and all five preimplementation GO/Required 0
  outcomes, including Architecture's approved interface correction;
- implementation base, branch, dependency checkpoint, and clean/exact remote
  state;
- exact two-file implementation inventory and diff summary;
- RED command and attributable expected failure;
- GREEN command, selected suite/test counts, and pass result;
- exact boundary coverage for revisions, 64 operations, UTF-8 bytes,
  lifecycle/completion, acceptance, deterministic order, and rollback;
- `git diff --check` result;
- six postimplementation GO/Required 0 outcomes;
- final checkpoint SHA, local/upstream/live remote equality, ahead/behind
  `0/0`, open risks, and Task 4A gate state.

Do not persist raw database rows, task content, full test logs, result bundles,
credentials, secrets, or private owner data in the ledger.

## Durable and temporary artifacts

This brief is the only durable artifact created by the authorized planning
action. No temporary artifact is created by planning. During later authorized
implementation, DerivedData and any raw test logs are temporary and disposable;
the repository policy/test sources and coordinator ledger entry are the only
durable Task 3 artifacts.

## Required planning questions

None. Architecture explicitly approved removal of the unused policy-level
`auditEventID` parameter. This revision incorporates every Required planning
finding without expanding the two-file implementation scope.
