# RR-R10 Task 2B Brief: Schema-v12 Ticket-task Persistence and Models

**Status:** Canonical planning contract drafted. Implementation remains closed
until Architecture, QA/Test, Security/Privacy, TPM, and Delivery Management
review this exact registered brief and return GO with Required 0.

## Size assessment and checkpoint decision

The accepted implementation plan forecasts Task 2B at roughly 6-8 agent-hours.
It has one coherent storage/API review surface: public Ticket Task value types,
one additive v11-to-v12 migration, manifest enforcement, direct preservation
tests against the accepted schema-v11 fixture, and the narrow
plugin-lifecycle schema-version regression. Splitting the models from the
schema would leave the migration unreviewable against the public contract;
splitting the schema from rollback and parent-delete tests would create a
partially verified persistence checkpoint. Task 2B therefore remains one
bounded task.

This task adds no policy, command, MCP tool, projection, UI, installed app,
owner-store mutation, or live RR-R10 task plan. If implementation work
discovers that this exact scope cannot stay within the accepted 6-8 hour
boundary, stop before product edits expand and request a new dependency-safe
split.

## Objective and user-visible outcome

Add Release Radar's schema-v12 Ticket Task persistence foundation and public
model contract. Existing schema-v11 stores migrate additively, create zero
ticket task plans and zero ticket tasks, preserve every v11 row byte-
semantically, and gain database constraints that prevent plan/task history
from being deleted directly or cascaded away through ticket/project deletion.

There is no user-visible application change. The owner-visible value is a
trustworthy, fail-closed storage boundary that later tasks can use for audited
task revisions, acceptance gating, and read-only board projection without
parsing Markdown, Git, test state, Codex state, or repository progress as
delivery authority.

## Controlling product and design references

- `docs/design/release-radar-ticket-tasks-design.md`, especially Product
  outcome, Vocabulary and authority, Data contract, Plan invariants, Audit,
  replay, and failure, Delivery Goal and phase-plan interaction, and
  Acceptance criteria; accepted SHA-256
  `c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08`
- `docs/architecture/ADR-005-ticket-task-work-plans.md`, especially Decision,
  Persistence boundary, Projection boundary, RR-R10 command availability
  sequence, and Consequences; accepted SHA-256
  `6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5`
- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`,
  Global Constraints, File Structure, Task 2A, and Task 2B; accepted SHA-256
  `2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md`,
  registered SHA-256
  `d9e77073932c3f46a4fba210f9c6ab0f150fdcb11b089529dcc87010d492cded`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md`,
  registered SHA-256
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md`,
  registered SHA-256
  `711abe4edee9ac86951e9e41c40170f9fbb67123e2f44216e0203cec85595292`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md`,
  registered SHA-256
  `db34c56d5c312a82b35e5a07434a94db2388d567e75ac1e8085d307d69dce733`
- `docs/delivery/progress.md`, Current gate, accepted Task 1A/1B checkpoints,
  accepted Ticket Tasks planning package, final Task 2A0 checkpoint, and Task
  2A accepted implementation checkpoint

The accepted Phase Board mockup and Ticket Tasks owner-visible details are
downstream projection context only. Task 2B changes no UI and authorizes no
visual deviation.

## Dependencies and release gate

- Branch must be exactly `codex/release-radar-mvp`.
- Local HEAD, upstream, and live remote must be exactly
  `a08c88c5818f5ea6dbb6932fa336b7bd88b88ddd` with ahead/behind `0/0`
  before planning review, RED, GREEN, or implementation checkpoint assembly.
- HEAD commit `a08c88c5818f5ea6dbb6932fa336b7bd88b88ddd` must have parent
  `e1f3321afefcf95707cef25fe58f24859331e323`, subject
  `test: add genuine schema-v11 fixture`, and commit inventory exactly:
  `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS`,
  `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite`, and
  `docs/delivery/progress.md`.
- The schema-v11 fixture must remain 348,160 bytes at SHA-256
  `ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c`.
  Its one-line `SHA256SUMS` must remain 91 bytes at SHA-256
  `ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3`,
  and `(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)`
  must report `release-radar-v11.sqlite: OK`.
- The accepted design, ADR, implementation plan, Task 1A, Task 1B, Task 2A,
  and Task 2A0 brief hashes listed above must remain exact.
- This exact brief and its exactly one root-registry entry must be
  independently reviewed by Architecture, QA/Test, Security/Privacy, TPM, and
  Delivery Management. Every role must return GO with Required 0 before the
  first RED test edit.
- One fresh serialized Implementer owns the listed product/test files. No
  concurrent writer may modify `StoreMigrations.swift`, `DeliveryStore.swift`,
  `TicketTaskModels.swift`, `StoreAcceptanceTests.swift`, or
  `CodexPluginLifecycleAcceptanceTests.swift`.
- After implementation, a separate Code Reviewer and QA verifier, plus
  Architecture, Security/Privacy, TPM, and Delivery Management, must return GO
  with Required 0 before the implementation checkpoint is committed or Task 3
  opens.

## In scope

- Create the exact public Ticket Task ID, enum, draft, definition-revision,
  plan-record, and task-record values in
  `ReleaseRadarCore/Models/TicketTaskModels.swift`.
- Add only `.ticketTaskPlan = "ticket_task_plan"` to `AuditEntityType` without
  changing any existing raw value or audit behavior.
- Advance `StoreMigrations.currentVersion` from 11 to 12.
- Add manifest-validated schema-v12 tables `ticket_task_plans` and
  `ticket_tasks`.
- Add exact supporting indexes, composite foreign keys, state/timestamp CHECK
  constraints, immutable-ID/label triggers, no-delete triggers, and explicit
  parent-delete protection triggers for project and ticket deletion.
- Ensure v11-to-v12 migration creates zero task plans and zero tasks and does
  not rewrite accepted v11 SQL constants or any accepted fixture.
- Verify with one seeded, copied schema-v11 fixture that every seeded v11 table
  is preserved in primary-key order after migration, rollback, relaunch, and
  counterfeit-schema rejection.
- Update only schema-version expectations that truthfully become version 12 in
  `CodexPluginLifecycleAcceptanceTests.swift`.

## Out of scope

- `TicketTaskPlanningPolicy`, ticket acceptance gates, exact-revision task
  mutation, replay receipts, typed errors, bridge/dispatcher/MCP tools, owner
  actions, importer/sample/debug routing, concurrency policy, or outcome-
  unknown replay; Task 3 and Task 4B own those behaviors.
- Projection, card count, Ticket Details rows, unavailable task recovery,
  accessibility, Dynamic Type, screenshots, or Phase Board UI; Task 5 owns
  task visibility.
- Any Delivery Goal policy change, phase-plan state transition, Delivery Goal
  revision, assignment, lifecycle, or ADR-004 readiness invalidation behavior.
- Creating, inferring, revising, completing, superseding, accepting, or
  displaying the live 16-row RR-R10 Ticket Tasks plan. Runtime code must not
  parse planning documents, Git history, tests, Codex state, or the progress
  ledger to manufacture a task plan.
- Owner database/app launch/install, owner UI, bridge/MCP call, notification
  dispatch, RR-R10 mutation, Accepted-ticket mutation, or any external state.
- Modifying `ReleaseRadar.xcodeproj/project.pbxproj`, schemes, entitlements,
  sandbox/signing settings, fixtures, fixture manifests, generated resources,
  or adding a dependency, framework, harness, or second fixture.
- Portable export/import changes, archive v2, export guards, or archive
  predicates. Current import remains task-plan-free, and RR-R10 adds no
  exporter.
- Implementer edits to `docs/delivery/progress.md`; coordinator/Delivery
  Management owns ledger evidence after independent verification.

## Affected subsystem and anticipated files

- Create: `ReleaseRadarCore/Models/TicketTaskModels.swift`
- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Modify only schema-version expectations in:
  `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`
- Coordinator modifies after verification: `docs/delivery/progress.md`
- Consume unchanged:
  `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite`
- Consume unchanged:
  `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS`

No project-file change is required because the Xcode project uses
file-system-synchronized groups. No fixture membership correction is authorized
in this task.

## Public interface contract

`TicketTaskModels.swift` must define public properties and explicit public
memberwise initializers for exactly these values:

```swift
public struct TicketTaskID: DeliveryRecordID {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum TicketTaskCompletion: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
}

public enum TicketTaskLifecycle: String, Codable, CaseIterable, Sendable {
    case active
    case superseded
}

public struct TicketTaskDraft: Codable, Equatable, Sendable {
    public let id: TicketTaskID
    public let label: String
    public let title: String
    public let sortOrder: Int

    public init(
        id: TicketTaskID,
        label: String,
        title: String,
        sortOrder: Int
    ) {
        self.id = id
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
    }
}

public struct TicketTaskDefinitionRevision: Codable, Equatable, Sendable {
    public let id: TicketTaskID
    public let title: String?
    public let sortOrder: Int?

    public init(
        id: TicketTaskID,
        title: String?,
        sortOrder: Int?
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
    }
}

public struct TicketTaskPlanRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let ticketID: TicketID
    public let revision: Int64
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        projectID: ProjectID,
        ticketID: TicketID,
        revision: Int64,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.projectID = projectID
        self.ticketID = ticketID
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TicketTaskRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let ticketID: TicketID
    public let id: TicketTaskID
    public let label: String
    public let title: String
    public let sortOrder: Int
    public let completion: TicketTaskCompletion
    public let lifecycle: TicketTaskLifecycle
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?
    public let supersededAt: Date?

    public init(
        projectID: ProjectID,
        ticketID: TicketID,
        id: TicketTaskID,
        label: String,
        title: String,
        sortOrder: Int,
        completion: TicketTaskCompletion,
        lifecycle: TicketTaskLifecycle,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?,
        supersededAt: Date?
    ) {
        self.projectID = projectID
        self.ticketID = ticketID
        self.id = id
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
        self.completion = completion
        self.lifecycle = lifecycle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.supersededAt = supersededAt
    }
}
```

`TicketTaskDraft` carries only machine ID, visible label, title, and sort
order. It has no completion or lifecycle field. That is a future API contract
for Task 3's policy: later task additions are born Active/Pending through the
policy and cannot carry a completion input. Task 2B's schema legitimately
permits valid completed and superseded historical rows so migrations, audits,
and later policy operations can preserve durable history.

Every record conforms to `Codable`, `Equatable`, and `Sendable`. Do not move
Delivery Goal or observed-goal types into this file or change their meaning.
Add only `.ticketTaskPlan = "ticket_task_plan"` to `AuditEntityType`; preserve
`.phasePlan`, `.deliveryGoal`, and every preexisting audit raw value.

## Exact schema-v12 contract

Schema v12 is additive to v11. It must not change the accepted v11 table SQL,
including `ticketsVersionElevenTableSQL`, `phasePlansTableSQL`,
`deliveryGoalsTableSQL`, `deliveryGoalDoneCriteriaTableSQL`,
`deliveryGoalTicketAssignmentsTableSQL`, or
`deliveryGoalAssignmentEventsTableSQL`.

`ticket_task_plans`:

```sql
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
```

`ticket_tasks`:

```sql
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
```

The encoded UTF-8 byte maxima are mandatory in the canonical table SQL:
machine ID 1-256 bytes, visible label 1-256 bytes, and title 1-4,096 bytes,
using `length(CAST(column AS BLOB))`. Character counts, lossy truncation,
normalization, or replacement are not acceptable substitutes. Boundary tests
must cover ASCII and multibyte strings at limit minus one, exact limit, and
limit plus one for all three fields.

Manifest objects:

- `ticket_task_plans_ticket_unique`: unique index on `(project_id, ticket_id)`.
- `ticket_tasks_label_unique`: unique index on
  `(project_id, ticket_id, label COLLATE BINARY)`.
- `ticket_tasks_active_order_index`: nonunique index on
  `(project_id, ticket_id, lifecycle, sort_order, label COLLATE BINARY,
  id COLLATE BINARY)` for deterministic active-row projection. Manifest
  validation must also assert BINARY collation for the ordered text columns.
- `ticket_tasks_reject_identity_update`: rejects update of `project_id`,
  `ticket_id`, or `id`.
- `ticket_tasks_reject_label_update`: rejects update of `label`.
- `ticket_task_plans_reject_delete`: rejects direct deletion from
  `ticket_task_plans`.
- `ticket_tasks_reject_delete`: rejects direct deletion from `ticket_tasks`.
- `ticket_task_plans_reject_ticket_delete`: rejects deletion of any `tickets`
  row whose `(project_id, id)` owns a task plan.
- `ticket_task_plans_reject_project_delete`: rejects deletion of any
  `projects` row that owns task-plan history.

`StoreMigrations.hasRequiredSchema` must validate the new tables, indexes,
foreign keys, triggers, and canonical table SQL. Counterfeit validation must
compare normalized SQL against canonical v12 SQL, not just search for expected
words. A counterfeit table or trigger that embeds the expected text inside an
inert constraint or no-op body must fail closed.

`schemaVersion12` must execute in this order so rollback tests can collide with
a late DDL object after earlier v12 DDL has already run:

1. `ticketTaskPlansTableSQL`
2. `ticketTasksTableSQL`
3. `ticket_task_plans_ticket_unique`
4. `ticket_tasks_label_unique`
5. `ticket_tasks_active_order_index`
6. `ticketTasksRejectIdentityUpdateTrigger`
7. `ticketTasksRejectLabelUpdateTrigger`
8. `ticketTaskPlansRejectDeleteTrigger`
9. `ticketTasksRejectDeleteTrigger`
10. `ticketTaskPlansRejectTicketDeleteTrigger`
11. `ticketTaskPlansRejectProjectDeleteTrigger`

The trigger bodies and error literals are exact:

```sql
CREATE TRIGGER ticket_tasks_reject_identity_update
BEFORE UPDATE OF project_id, ticket_id, id ON ticket_tasks
WHEN OLD.project_id <> NEW.project_id
   OR OLD.ticket_id <> NEW.ticket_id
   OR OLD.id <> NEW.id
BEGIN
    SELECT RAISE(ABORT, 'ticket task identity is immutable');
END
```

```sql
CREATE TRIGGER ticket_tasks_reject_label_update
BEFORE UPDATE OF label ON ticket_tasks
WHEN OLD.label <> NEW.label
BEGIN
    SELECT RAISE(ABORT, 'ticket task label is immutable');
END
```

```sql
CREATE TRIGGER ticket_task_plans_reject_delete
BEFORE DELETE ON ticket_task_plans
BEGIN
    SELECT RAISE(ABORT, 'ticket task plan history cannot be deleted');
END
```

```sql
CREATE TRIGGER ticket_tasks_reject_delete
BEFORE DELETE ON ticket_tasks
BEGIN
    SELECT RAISE(ABORT, 'ticket task history cannot be deleted');
END
```

```sql
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
```

```sql
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
```

Migration creates no task plan or task rows:

```sql
SELECT COUNT(*) FROM ticket_task_plans;
SELECT COUNT(*) FROM ticket_tasks;
```

Both counts must remain `0` for the accepted empty schema-v11 fixture and for
the seeded representative v11 graph after migration.

## Test fixture strategy

Use one test-first seeded-v11 fixture-copy strategy:

1. Verify the committed schema-v11 fixture with a throwing fail-closed helper
   before any copy or open. The helper must require an exact one-line manifest,
   pinned digest, regular-file/no-symlink metadata for the directory, manifest,
   and database, canonical containment under `ReleaseRadarTests/Fixtures`, and
   user version 11 on the source.
2. Copy `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite` to a
   per-test temporary URL using no-overwrite semantics, then verify the copied
   digest before opening it.
3. Seed the copied database through raw schema-v11 SQL before opening
   `DeliveryStore`.
4. Snapshot every seeded v11 table in primary-key order before migration.
5. Open only that copied database through `DeliveryStore` to migrate to v12.
6. Compare every v11 snapshot field-for-field after migration, after store
   relaunch, after rejected deletion attempts, and after rollback recovery.

Never alter the committed schema-v11 fixture or its manifest. Never create a
new fixture, generator, export, result bundle, or source fixture mode in Task
2B.

Do not call the existing nonthrowing assertion-based fixture helper as the
schema-v11 copy authority. The new helper must throw before a destination copy
or store open if any manifest, digest, no-follow type, containment, or schema
precondition fails.

The source manifest content is exact:

```text
ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c  release-radar-v11.sqlite
```

The representative v11 graph must include:

- two projects;
- a nonempty `project_roots` row so all 28 v11 tables are actually seeded and
  snapshotted;
- at least two phases in the main project and one phase in the second project;
- active-phase pointer for the main project;
- tickets in all five lanes: Backlog, In progress, Needs review, Blocked, and
  Accepted;
- phase and ticket dependencies;
- one unresolved blocker;
- evidence, review item, and completion record;
- project bookmark row;
- thread exclusion;
- observed thread, observed goal, thread link, and exact `ticket_goal_links`
  link;
- notification event and notification occurrence;
- alert-rule state different from the default for at least one rule;
- `codex_plugin_lifecycle` singleton with managed fields populated;
- at least one audit event with project/entity scope;
- at least one agent command request receipt;
- phase plans for all seeded phases;
- Delivery Goals in at least two phases, ordered done criteria, ticket
  assignments, and one deferred assignment-event row linked to the same
  transaction's authoritative audit event.

Snapshot every seeded v11 table in this order, each sorted by its primary key
or documented stable key:

- `projects` by `id`
- `project_roots` by `id`
- `phases` by `id`
- `tickets` by `id`
- `phase_dependencies` by `id`
- `ticket_dependencies` by `id`
- `blockers` by `id`
- `evidence` by `id`
- `thread_exclusions` by `id`
- `observed_threads` by `id`
- `observed_goals` by `id`
- `thread_links` by `id`
- `review_items` by `id`
- `audit_events` by `id`
- `notification_events` by `id`
- `completion_records` by `id`
- `agent_command_requests` by `request_id`
- `project_bookmarks` by `project_id, path`
- `project_active_phases` by `project_id`
- `notification_occurrences` by `subject_key`
- `ticket_goal_links` by `id`
- `alert_rules` by `kind`
- `codex_plugin_lifecycle` by `plugin_id`
- `phase_plans` by `project_id, phase_id`
- `delivery_goals` by `project_id, phase_id, id`
- `delivery_goal_done_criteria` by `project_id, phase_id, goal_id, sort_order`
- `delivery_goal_ticket_assignments` by `project_id, ticket_id`
- `delivery_goal_assignment_events` by `audit_event_id, ticket_id`

The semantic v11 snapshot excludes only `PRAGMA user_version` and the additive
v12 objects. It does not ignore row changes, ordering differences, missing
columns, or changed default rows.

## Required tests

Add RED tests in `StoreAcceptanceTests.swift` before any product edit. The
first RED command must fail because `TicketTaskModels.swift`,
`.ticketTaskPlan`, schema version 12, and the v12 tables/triggers do not exist.
Expected failure is a compile error or missing schema assertion; a passing RED
is invalid and must stop implementation.

Happy-path tests:

- `testTicketTaskPublicModelsRoundTripAndAuditScope`: round-trips every public
  model and asserts `.ticketTaskPlan.rawValue == "ticket_task_plan"`.
- `testExactVersionElevenFixtureMigratesToVersionTwelveWithoutInference`:
  copies and verifies the accepted schema-v11 fixture, seeds the complete graph
  above, snapshots every v11 table, opens `DeliveryStore`, asserts schema 12,
  zero task plans/tasks, unchanged v11 snapshot, empty `foreign_key_check`, and
  `integrity_check = ok`, then relaunches and repeats the same assertions.
- `testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants`: proves
  valid same-ticket plan/task rows insert, cross-project/cross-ticket task rows
  reject, duplicate machine IDs reject within the same ticket plan, duplicate
  labels reject within the same ticket plan even after supersession, the same
  machine ID and label are allowed in a different ticket plan, empty labels and
  empty titles reject, ASCII and multibyte ID/label/title byte limits reject
  only at limit plus one, negative sort rejects, revision 0 rejects, invalid
  completion and lifecycle values reject, pending with `completed_at` rejects,
  completed without `completed_at` rejects, active with `superseded_at`
  rejects, superseded without `superseded_at` rejects, `completed_at`,
  `superseded_at`, and `updated_at` before `created_at` reject, and
  deterministic active order is `sort_order`, then label BINARY byte order,
  then machine ID BINARY byte order.
- `testVersionTwelveTaskHistoryCannotBeDeletedOrCascaded`: after valid plan
  and task history exists, direct task delete, direct plan delete, direct
  ticket delete, and project delete that would otherwise cascade all reject.
  Every rejected deletion leaves the parent project, parent ticket, plan row,
  and task rows unchanged. The same test also proves tickets and projects
  without task history remain deletable under the existing v11 rules.
- `testVersionTwelveManifestRejectsMissingOrCounterfeitTaskObjects`: drops or
  counterfeits each required v12 table/index/trigger/FK class and asserts a
  reopened `DeliveryStore` is unavailable with migration recovery. Include at
  least one semantic counterfeit table and one trigger that embed expected text
  while omitting the real constraint/body.
- `testVersionTwelveMigrationFailureRollsBackToExactVersionElevenStateAndRecovers`:
  reuses the same seeded fixture copy shape, injects exactly this v11-compatible
  late-DDL collision object before opening `DeliveryStore`, opens the store,
  asserts unavailable migration recovery, proves `PRAGMA user_version` is still
  11, proves every pre-migration v11 snapshot is unchanged, proves no v12 table
  or index survived the rolled-back transaction, proves the injected trigger
  still exists because it predates migration, removes only that trigger, then
  reopens normally to v12 and relaunches once more:

```sql
CREATE TRIGGER ticket_task_plans_reject_ticket_delete
BEFORE DELETE ON tickets
BEGIN
    SELECT RAISE(ABORT, 'task2b injected late v12 collision');
END
```

This injected object deliberately collides with the late
`ticketTaskPlansRejectTicketDeleteTrigger` creation after the v12 table,
index, and earlier trigger DDL has already executed. The test verifies actual
migration ordering and manifest behavior; it must not use a non-firing DML
abort trigger. The same test creates a separate valid copied/seeded store,
migrates it to v12, snapshots every v11 and v12 task table row, sets
`PRAGMA user_version = 13`, opens `DeliveryStore`, asserts unsupported-version
migration recovery, and proves no row, `user_version`, fixture, audit, receipt,
task, or lifecycle singleton was changed by the failed open.

Non-happy-path coverage must include:

- direct task identity update rejection and direct label update rejection;
- no hard deletion of pending, completed, active, or superseded tasks;
- completed and superseded timestamp preservation;
- manifest validation for canonical SQL, required indexes, required foreign
  keys, and all no-delete/parent-delete triggers;
- direct project deletion that would otherwise cascade through tickets;
- successful deletion of tickets/projects that have no task-plan history;
- no cascade history loss from ticket/project deletion attempts;
- relaunch after migrated v12 store;
- schema-v13 unsupported future-version setup, unavailable recovery, and no
  mutation;
- Store recovery state uses the existing migration recovery path;
- plugin-lifecycle singleton remains valid and independently tested at schema
  12.

## Test-first sequence

1. Verify the planning checkpoint gate below after the brief is independently
   reviewed, registered, committed by the coordinator, pushed, and remote-exact.
2. Add only the RED model/migration tests in `StoreAcceptanceTests.swift` and
   the truthful schema-version expectation in
   `CodexPluginLifecycleAcceptanceTests.swift`.
3. Run the RED command once. Expected: fail before product edit.
4. Implement the smallest GREEN in `TicketTaskModels.swift`,
   `DeliveryStore.swift`, and `StoreMigrations.swift`.
5. Run the focused Store GREEN command.
6. Run the combined Store plus plugin-lifecycle regression command.
7. Run `git diff --check`.
8. Stop for independent postimplementation review.

Do not build a new harness, fixture, dependency, result parser, generator, or
project membership correction.

## Executable gates

All shell fences below are `/bin/bash` fences. Implementers must run them with
`/bin/bash`, not `zsh`, and must not use the zsh-special variable name `path`.
Each RED, GREEN, and regression fence owns one restricted evidence parent and
must run exactly once. Any `xcodebuild`, result extraction, parser,
count/cardinality, fixture boundary, containment, mode, or privacy-scan failure
retains its restricted evidence and stops before any subsequent run,
`git diff --check`, review request, staging, checkpoint, or retry. A retry or
continuation after such a failure requires new reviewed recovery authority.

Every evidence fence uses the same narrow credential/private-key marker regex:
`(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})`.
Run `rg --quiet --pcre2` against raw logs and extracted textual JSON, redirect
all output to `/dev/null`, accept only exit status `1` for no matches, reject
status `0` or scanner errors, and never print matching lines.

### Planning checkpoint gate

Run only after this brief's preimplementation reviews return GO/Required 0 and
the coordinator commits this brief, the root registry, and ledger evidence as
the single direct child of `a08c88c5818f5ea6dbb6932fa336b7bd88b88ddd`.

```bash
set -euo pipefail
RR_TASK2B_BRANCH=codex/release-radar-mvp
RR_TASK2B_PARENT=a08c88c5818f5ea6dbb6932fa336b7bd88b88ddd
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md
RR_TASK2B_REPO_ROOT="$(git rev-parse --show-toplevel)"
test "$(pwd -P)" = "$(realpath "$RR_TASK2B_REPO_ROOT")"
test "$(git rev-parse --abbrev-ref HEAD)" = "$RR_TASK2B_BRANCH"

RR_TASK2B_HEAD="$(git rev-parse HEAD)"
test "$(git rev-parse "$RR_TASK2B_HEAD^")" = "$RR_TASK2B_PARENT"
RR_TASK2B_REMOTE_LINE="$(git ls-remote --exit-code origin "refs/heads/$RR_TASK2B_BRANCH")"
test "$(printf '%s\n' "$RR_TASK2B_REMOTE_LINE" | wc -l | tr -d ' ')" = "1"
test "$(printf '%s\n' "$RR_TASK2B_REMOTE_LINE" | awk '{print $1}')" = "$RR_TASK2B_HEAD"
test "$(git rev-list --left-right --count HEAD...@{u})" = "0	0"

RR_TASK2B_INVENTORY="$(git diff-tree --no-commit-id --name-only -r "$RR_TASK2B_HEAD" | LC_ALL=C sort)"
test "$RR_TASK2B_INVENTORY" = "$(printf '%s\n' "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" | LC_ALL=C sort)"
git diff --exit-code "$RR_TASK2B_HEAD" -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
git diff --cached --exit-code "$RR_TASK2B_HEAD" -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
git diff --exit-code -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"

test "$(awk -v brief_file="$RR_TASK2B_BRIEF" '$2 == brief_file { count += 1 } END { print count + 0 }' "$RR_TASK2B_REGISTRY")" = "1"
RR_TASK2B_REGISTERED_BRIEF_SHA="$(awk -v brief_file="$RR_TASK2B_BRIEF" '$2 == brief_file { print $1 }' "$RR_TASK2B_REGISTRY")"
case "$RR_TASK2B_REGISTERED_BRIEF_SHA" in
  (*[!0-9a-f]*|'') exit 1 ;;
esac
test "${#RR_TASK2B_REGISTERED_BRIEF_SHA}" = "64"
test "$(shasum -a 256 "$RR_TASK2B_BRIEF" | awk '{print $1}')" = "$RR_TASK2B_REGISTERED_BRIEF_SHA"
shasum -a 256 -c "$RR_TASK2B_REGISTRY"

test "$(shasum -a 256 docs/design/release-radar-ticket-tasks-design.md | awk '{print $1}')" = "c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08"
test "$(shasum -a 256 docs/architecture/ADR-005-ticket-task-work-plans.md | awk '{print $1}')" = "6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5"
test "$(shasum -a 256 docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md | awk '{print $1}')" = "2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1"
test "$(shasum -a 256 docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md | awk '{print $1}')" = "d9e77073932c3f46a4fba210f9c6ab0f150fdcb11b089529dcc87010d492cded"
test "$(shasum -a 256 docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md | awk '{print $1}')" = "e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff"
test "$(shasum -a 256 docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md | awk '{print $1}')" = "711abe4edee9ac86951e9e41c40170f9fbb67123e2f44216e0203cec85595292"
test "$(shasum -a 256 docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md | awk '{print $1}')" = "db34c56d5c312a82b35e5a07434a94db2388d567e75ac1e8085d307d69dce733"
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite | awk '{print $1}')" = "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS | awk '{print $1}')" = "ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3"

git diff --exit-code b711229a109c1a58c9616e4ff907afb18cd4f958 -- \
  ReleaseRadarCore/Models/DeliveryGoalModels.swift \
  ReleaseRadarCore/Store/DeliveryStore.swift \
  ReleaseRadarCore/Store/StoreMigrations.swift \
  ReleaseRadarTests/StoreAcceptanceTests.swift \
  ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
test "$(git show --name-only --format= "$RR_TASK2B_PARENT" | LC_ALL=C sort)" = "$(printf '%s\n' \
  ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS \
  ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite \
  docs/delivery/progress.md | LC_ALL=C sort)"
test "$(git status --porcelain=v1)" = ""
```

### RED command

Run exactly once before product edits after adding only RED tests. The command
uses one unique mode-700 parent, no-follow absent paths, restricted logs and
result bundle, and fail-closed log classification.

```bash
set -euo pipefail
umask 077
RR_TASK2B_RED_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-red.XXXXXX)"
chmod 700 "$RR_TASK2B_RED_PARENT"
RR_TASK2B_RED_DERIVED="$RR_TASK2B_RED_PARENT/DerivedData"
RR_TASK2B_RED_RESULT="$RR_TASK2B_RED_PARENT/red.xcresult"
RR_TASK2B_RED_LOG="$RR_TASK2B_RED_PARENT/red.log"
RR_TASK2B_RED_SANITIZED="$RR_TASK2B_RED_PARENT/red-sanitized.log"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RED_PARENT")" = "Directory"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RED_PARENT")" = "700"
for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_RED_DERIVED" \
  "$RR_TASK2B_RED_RESULT" \
  "$RR_TASK2B_RED_LOG" \
  "$RR_TASK2B_RED_SANITIZED"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_RED_DERIVED" \
  -resultBundlePath "$RR_TASK2B_RED_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests >"$RR_TASK2B_RED_LOG" 2>&1
RR_TASK2B_RED_STATUS=$?
set -e
test "$RR_TASK2B_RED_STATUS" -ne 0
test -f "$RR_TASK2B_RED_LOG"
test ! -L "$RR_TASK2B_RED_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RED_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RED_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_RED_LOG")")" = "$(realpath "$RR_TASK2B_RED_PARENT")"
sed -E 's#/Users/[^[:space:]]+#<redacted-user-path>#g; s#/tmp/release-radar-[^[:space:]]+#<redacted-temp-path>#g' \
  "$RR_TASK2B_RED_LOG" >"$RR_TASK2B_RED_SANITIZED"
test -f "$RR_TASK2B_RED_SANITIZED"
test ! -L "$RR_TASK2B_RED_SANITIZED"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RED_SANITIZED")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RED_SANITIZED")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_RED_SANITIZED")")" = "$(realpath "$RR_TASK2B_RED_PARENT")"
if test -e "$RR_TASK2B_RED_RESULT"; then
  test -d "$RR_TASK2B_RED_RESULT"
  test ! -L "$RR_TASK2B_RED_RESULT"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RED_RESULT")" = "Directory"
  test "$(dirname "$(realpath "$RR_TASK2B_RED_RESULT")")" = "$(realpath "$RR_TASK2B_RED_PARENT")"
fi
RR_TASK2B_RED_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_RED_LOG" "$RR_TASK2B_RED_SANITIZED" >/dev/null 2>&1 || \
  RR_TASK2B_RED_SCAN_STATUS=$?
test "$RR_TASK2B_RED_SCAN_STATUS" = "1"
for RR_TASK2B_EXPECTED in \
  TicketTaskID \
  TicketTaskCompletion \
  TicketTaskLifecycle \
  TicketTaskDraft \
  TicketTaskDefinitionRevision \
  TicketTaskPlanRecord \
  TicketTaskRecord \
  ticketTaskPlan; do
  /usr/bin/grep -F "$RR_TASK2B_EXPECTED" "$RR_TASK2B_RED_LOG" >/dev/null
done
for RR_TASK2B_UNRELATED in \
  "Multiple commands produce" \
  "No such module 'ReleaseRadarCore'" \
  "CodeSign failed" \
  "Provisioning profile" \
  "timed out waiting"; do
  if /usr/bin/grep -F "$RR_TASK2B_UNRELATED" "$RR_TASK2B_RED_LOG" >/dev/null; then
    exit 1
  fi
done
```

Expected: nonzero failure before product edit at the exact missing
model/audit-scope boundary. Any unrelated build, module, signing, duplicate
resource, timeout, test-host, fixture, or owner-state failure invalidates RED
and stops implementation. RED is not retried.

### GREEN Store command

Run exactly once after the smallest product/test implementation. It must
produce structured xcresult evidence showing exactly 43 passed Store tests:
the 37 accepted baseline Store cases plus exactly the six named Task 2B cases
in this brief. Any GREEN command, extraction, parser, count/cardinality,
boundary, or privacy-scan failure stops before regression, diff check, review,
staging, checkpoint, or retry pending new reviewed recovery authority.

```bash
set -euo pipefail
umask 077
RR_TASK2B_GREEN_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-green.XXXXXX)"
chmod 700 "$RR_TASK2B_GREEN_PARENT"
RR_TASK2B_GREEN_DERIVED="$RR_TASK2B_GREEN_PARENT/DerivedData"
RR_TASK2B_GREEN_RESULT="$RR_TASK2B_GREEN_PARENT/store-green.xcresult"
RR_TASK2B_GREEN_LOG="$RR_TASK2B_GREEN_PARENT/store-green.log"
RR_TASK2B_GREEN_SUMMARY="$RR_TASK2B_GREEN_PARENT/store-green-summary.json"
RR_TASK2B_GREEN_TESTS="$RR_TASK2B_GREEN_PARENT/store-green-tests.json"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'
for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_GREEN_DERIVED" \
  "$RR_TASK2B_GREEN_RESULT" \
  "$RR_TASK2B_GREEN_LOG" \
  "$RR_TASK2B_GREEN_SUMMARY" \
  "$RR_TASK2B_GREEN_TESTS"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_GREEN_DERIVED" \
  -resultBundlePath "$RR_TASK2B_GREEN_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests >"$RR_TASK2B_GREEN_LOG" 2>&1
RR_TASK2B_GREEN_STATUS=$?
set -e
test -f "$RR_TASK2B_GREEN_LOG"
test ! -L "$RR_TASK2B_GREEN_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_GREEN_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_GREEN_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_GREEN_LOG")")" = "$(realpath "$RR_TASK2B_GREEN_PARENT")"
RR_TASK2B_GREEN_LOG_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" "$RR_TASK2B_GREEN_LOG" >/dev/null 2>&1 || \
  RR_TASK2B_GREEN_LOG_SCAN_STATUS=$?
test "$RR_TASK2B_GREEN_LOG_SCAN_STATUS" = "1"
test "$RR_TASK2B_GREEN_STATUS" = "0"
test -d "$RR_TASK2B_GREEN_RESULT"
test ! -L "$RR_TASK2B_GREEN_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_GREEN_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2B_GREEN_RESULT")")" = "$(realpath "$RR_TASK2B_GREEN_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary --path "$RR_TASK2B_GREEN_RESULT" --compact >"$RR_TASK2B_GREEN_SUMMARY"
  xcrun xcresulttool get test-results tests --path "$RR_TASK2B_GREEN_RESULT" --compact >"$RR_TASK2B_GREEN_TESTS"
)
for RR_TASK2B_RESULT_FILE in \
  "$RR_TASK2B_GREEN_LOG" \
  "$RR_TASK2B_GREEN_SUMMARY" \
  "$RR_TASK2B_GREEN_TESTS"; do
  test -f "$RR_TASK2B_RESULT_FILE"
  test ! -L "$RR_TASK2B_RESULT_FILE"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RESULT_FILE")" = "Regular File"
  test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RESULT_FILE")" = "600"
  test "$(dirname "$(realpath "$RR_TASK2B_RESULT_FILE")")" = "$(realpath "$RR_TASK2B_GREEN_PARENT")"
done
RR_TASK2B_GREEN_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_GREEN_LOG" "$RR_TASK2B_GREEN_SUMMARY" "$RR_TASK2B_GREEN_TESTS" >/dev/null 2>&1 || \
  RR_TASK2B_GREEN_SCAN_STATUS=$?
test "$RR_TASK2B_GREEN_SCAN_STATUS" = "1"
python3 - "$RR_TASK2B_GREEN_SUMMARY" "$RR_TASK2B_GREEN_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected = {
    "result": "Passed",
    "totalTestCount": 43,
    "passedTests": 43,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected summary field {key}: {summary.get(key)!r}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be empty")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 43 or len({identifier for identifier, _ in cases}) != 43:
    raise SystemExit("expected exactly 43 unique Store test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every Store test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
if len(store) != 43 or len(store) != len(cases):
    raise SystemExit("unexpected suite in Store-only result")
required = {
    "StoreAcceptanceTests/testTicketTaskPublicModelsRoundTripAndAuditScope",
    "StoreAcceptanceTests/testExactVersionElevenFixtureMigratesToVersionTwelveWithoutInference",
    "StoreAcceptanceTests/testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants",
    "StoreAcceptanceTests/testVersionTwelveTaskHistoryCannotBeDeletedOrCascaded",
    "StoreAcceptanceTests/testVersionTwelveManifestRejectsMissingOrCounterfeitTaskObjects",
    "StoreAcceptanceTests/testVersionTwelveMigrationFailureRollsBackToExactVersionElevenStateAndRecovers",
}
missing = sorted(required.difference(identifier for identifier, _ in cases))
if missing:
    raise SystemExit(f"missing required Task 2B tests: {missing}")
if len(required) != 6:
    raise SystemExit("Task 2B named-test set must remain exact")
PYTHON
```

Expected: all `StoreAcceptanceTests` pass with exactly 43 cases and no failure
records. Direct assertions prove schema 12, zero `ticket_task_plans`, zero
`ticket_tasks`, empty `foreign_key_check`, `integrity_check = ok`, complete v11
snapshot equality, parent/no-delete protection, counterfeit rejection,
future-version recovery, late-DDL rollback, and relaunch. The evidence under
the mode-700 parent is temporary and sanitized before any ledger summary. GREEN
is not retried.

### Store plus plugin regression

Run from a fresh mode-700 parent and absent DerivedData/result paths. It must
produce exactly 64 passed selected tests: 43 Store cases plus 21
plugin-lifecycle cases, with no unexpected suite.

```bash
set -euo pipefail
umask 077
RR_TASK2B_REGRESSION_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-regression.XXXXXX)"
chmod 700 "$RR_TASK2B_REGRESSION_PARENT"
RR_TASK2B_REGRESSION_DERIVED="$RR_TASK2B_REGRESSION_PARENT/DerivedData"
RR_TASK2B_REGRESSION_RESULT="$RR_TASK2B_REGRESSION_PARENT/regression.xcresult"
RR_TASK2B_REGRESSION_LOG="$RR_TASK2B_REGRESSION_PARENT/regression.log"
RR_TASK2B_REGRESSION_SUMMARY="$RR_TASK2B_REGRESSION_PARENT/regression-summary.json"
RR_TASK2B_REGRESSION_TESTS="$RR_TASK2B_REGRESSION_PARENT/regression-tests.json"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'
for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_REGRESSION_DERIVED" \
  "$RR_TASK2B_REGRESSION_RESULT" \
  "$RR_TASK2B_REGRESSION_LOG" \
  "$RR_TASK2B_REGRESSION_SUMMARY" \
  "$RR_TASK2B_REGRESSION_TESTS"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_REGRESSION_DERIVED" \
  -resultBundlePath "$RR_TASK2B_REGRESSION_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests >"$RR_TASK2B_REGRESSION_LOG" 2>&1
RR_TASK2B_REGRESSION_STATUS=$?
set -e
test -f "$RR_TASK2B_REGRESSION_LOG"
test ! -L "$RR_TASK2B_REGRESSION_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_REGRESSION_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_REGRESSION_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_REGRESSION_LOG")")" = "$(realpath "$RR_TASK2B_REGRESSION_PARENT")"
RR_TASK2B_REGRESSION_LOG_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" "$RR_TASK2B_REGRESSION_LOG" >/dev/null 2>&1 || \
  RR_TASK2B_REGRESSION_LOG_SCAN_STATUS=$?
test "$RR_TASK2B_REGRESSION_LOG_SCAN_STATUS" = "1"
test "$RR_TASK2B_REGRESSION_STATUS" = "0"
test -d "$RR_TASK2B_REGRESSION_RESULT"
test ! -L "$RR_TASK2B_REGRESSION_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_REGRESSION_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2B_REGRESSION_RESULT")")" = "$(realpath "$RR_TASK2B_REGRESSION_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary --path "$RR_TASK2B_REGRESSION_RESULT" --compact >"$RR_TASK2B_REGRESSION_SUMMARY"
  xcrun xcresulttool get test-results tests --path "$RR_TASK2B_REGRESSION_RESULT" --compact >"$RR_TASK2B_REGRESSION_TESTS"
)
for RR_TASK2B_RESULT_FILE in \
  "$RR_TASK2B_REGRESSION_LOG" \
  "$RR_TASK2B_REGRESSION_SUMMARY" \
  "$RR_TASK2B_REGRESSION_TESTS"; do
  test -f "$RR_TASK2B_RESULT_FILE"
  test ! -L "$RR_TASK2B_RESULT_FILE"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RESULT_FILE")" = "Regular File"
  test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RESULT_FILE")" = "600"
  test "$(dirname "$(realpath "$RR_TASK2B_RESULT_FILE")")" = "$(realpath "$RR_TASK2B_REGRESSION_PARENT")"
done
RR_TASK2B_REGRESSION_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_REGRESSION_LOG" "$RR_TASK2B_REGRESSION_SUMMARY" "$RR_TASK2B_REGRESSION_TESTS" >/dev/null 2>&1 || \
  RR_TASK2B_REGRESSION_SCAN_STATUS=$?
test "$RR_TASK2B_REGRESSION_SCAN_STATUS" = "1"
python3 - "$RR_TASK2B_REGRESSION_SUMMARY" "$RR_TASK2B_REGRESSION_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected = {
    "result": "Passed",
    "totalTestCount": 64,
    "passedTests": 64,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected summary field {key}: {summary.get(key)!r}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be empty")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 64 or len({identifier for identifier, _ in cases}) != 64:
    raise SystemExit("expected exactly 64 unique test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every selected test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
plugin = [identifier for identifier, _ in cases if identifier.startswith("CodexPluginLifecycleAcceptanceTests/")]
if len(store) != 43 or len(plugin) != 21 or len(store) + len(plugin) != len(cases):
    raise SystemExit("unexpected selected suite or suite cardinality")
PYTHON
```

Expected: the selected Store and plugin-lifecycle tests pass at schema 12 with
zero failed, skipped, expected-failure, or failure-record results. The
plugin-lifecycle singleton and repair behavior remain unchanged except for
truthful schema-version expectations. The run is retained as temporary
sanitized evidence and is not retried.

### Implementation checkpoint boundary

Run after postimplementation independent GO/Required 0 and before staging.

```bash
set -euo pipefail
git diff --cached --exit-code
RR_TASK2B_EXPECTED_TRACKED="$(printf '%s\n' \
  ReleaseRadarCore/Store/DeliveryStore.swift \
  ReleaseRadarCore/Store/StoreMigrations.swift \
  ReleaseRadarTests/StoreAcceptanceTests.swift \
  ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift \
  docs/delivery/progress.md | LC_ALL=C sort)"
RR_TASK2B_TRACKED_CHANGED="$(git diff --name-only -- | LC_ALL=C sort)"
test "$RR_TASK2B_TRACKED_CHANGED" = "$RR_TASK2B_EXPECTED_TRACKED"
test -f ReleaseRadarCore/Models/TicketTaskModels.swift
test ! -L ReleaseRadarCore/Models/TicketTaskModels.swift
RR_TASK2B_UNTRACKED_CHANGED="$(git ls-files --others --exclude-standard | LC_ALL=C sort)"
test "$RR_TASK2B_UNTRACKED_CHANGED" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
git diff --check
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
git diff --exit-code -- ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS
```

The implementation checkpoint may stage and commit only the five product/test
paths above plus coordinator-owned ledger evidence. It must be pushed to
`origin/codex/release-radar-mvp` and verified at exact local/upstream/live
remote equality with ahead/behind `0/0` before Task 3 opens.

## Activity and audit evidence requirements

Task 2B adds the `.ticketTaskPlan` audit entity type only. It does not write
task-plan audit events, request receipts, owner attention, notifications, or
live task mutations. Store tests may seed audit rows as raw fixture data to
prove v11 preservation and deferred assignment-event integrity, but no
production code path may emit a task audit in this task.

The coordinator ledger must later record:

- exact brief SHA-256 and root-registry verification;
- Architecture, QA/Test, Security/Privacy, TPM, and Delivery Management
  preimplementation GO/Required 0 dispositions;
- RED command, exact nonzero failure boundary, optional xcresult presence/
  absence, evidence path modes, sizes/hashes, and credential/private-key scan
  status only;
- GREEN Store command result, exact 43/43 count, Store-only cardinality,
  evidence path modes, sizes/hashes, and credential/private-key scan statuses
  only;
- Store plus plugin regression result, exact 64/64 count, exact 43/21 suite
  split, evidence path modes, sizes/hashes, and credential/private-key scan
  statuses only;
- direct fixture checksum verification;
- schema 12, zero inferred task rows, FK/integrity, rollback/relaunch, and v11
  equality evidence;
- postimplementation Code Review, QA/Test, Architecture, Security/Privacy,
  TPM, and Delivery Management GO/Required 0 dispositions;
- implementation checkpoint commit SHA and remote-equality proof.

Durable ledger or evidence packets may contain only sanitized scalar facts:
commands, paths, modes, sizes, hashes, counts, result statuses, suite
cardinality, failure categories, and scan statuses. They must not contain raw
logs, raw extracted JSON, owner data, raw result bundles, raw evidence files,
credential/private-key matches, or matching lines. GREEN and regression may
not be summarized as sanitized unless the required scans ran and returned
status `1` for no matches.

## Acceptance criteria

- `TicketTaskModels.swift` defines exactly the listed public model types with
  explicit public initializers, `Codable`, `Equatable`, and `Sendable`
  conformance where specified, and no completion input on `TicketTaskDraft`.
- `AuditEntityType.ticketTaskPlan.rawValue` is exactly `ticket_task_plan`, and
  existing audit raw values are unchanged.
- `StoreMigrations.currentVersion` is 12, v11 stores migrate additively to v12,
  and future schema versions still reject as unsupported.
- `ticket_task_plans` and `ticket_tasks` are manifest-validated by canonical
  SQL, required indexes, required foreign keys, and required triggers.
- Migration creates zero task plans and zero ticket tasks for both the accepted
  empty schema-v11 fixture and the representative seeded v11 graph.
- Composite ownership, stable machine-ID uniqueness, stable label uniqueness,
  deterministic order, legal states, nonnegative order, positive revision, and
  state/timestamp invariants are enforced at the store boundary.
- `TicketTaskDraft` has no completion or lifecycle input. Active/Pending
  addition semantics are reserved for Task 3's policy/API boundary; Task 2B's
  schema permits valid completed and superseded historical rows without adding
  any production create policy.
- Direct plan deletion, direct task deletion, direct ticket deletion with task
  history, and project deletion that would cascade task history all reject and
  leave parent, plan, and task rows unchanged.
- Counterfeit schema objects fail closed even when they embed expected text.
- Deliberate late-v12 migration failure rolls back to exact v11 state, exposes
  existing migration recovery, then recovers after only the injected blocker is
  removed.
- Store relaunch after migration stays available, schema 12, zero inferred
  task rows, empty `foreign_key_check`, and `integrity_check = ok`.
- Every seeded v11 table listed in this brief remains equal in primary-key
  order after migration, deletion rejection, rollback recovery, and relaunch.
- GREEN Store verification passes exactly once from a fresh restricted parent
  with Store `43/43`, no retry, and required privacy scans. Store plus
  plugin-lifecycle regression passes exactly once from a separate fresh
  restricted parent with `64/64`, exact `43/21` suite split, no retry, and
  required privacy scans.
- SchemaV10 and SchemaV11 fixtures and their manifests remain byte-identical;
  project, scheme, entitlement, signing, sandbox, owner-state, bridge/MCP, UI,
  and external-state boundaries remain untouched.

## Required independent reviews

Preimplementation release requires fresh independent Architecture, QA/Test,
Security/Privacy, TPM, and Delivery Management GO with Required 0 on this
exact brief SHA and registry entry. Storage Security/Privacy review is blocking
because this task changes local persistence, migration recovery, and deletion
resistance.

Postimplementation completion requires a fresh Code Reviewer and QA verifier,
plus Architecture, Security/Privacy, TPM, and Delivery Management GO with
Required 0. The Implementer may not review, verify, or approve its own work.

## Durable and temporary artifacts

Durable planning artifacts for this planning task:

- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md`
- one root-registry line in `docs/delivery/task-briefs/SHA256SUMS`

Durable implementation artifacts for the later Task 2B implementation:

- `ReleaseRadarCore/Models/TicketTaskModels.swift`
- `ReleaseRadarCore/Store/DeliveryStore.swift`
- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`
- coordinator-owned `docs/delivery/progress.md`

Temporary implementation evidence may include only `/tmp` DerivedData/result
directories from the RED, GREEN, and regression commands. These are not
controlling sources, must not be staged, and must not be presented as final
deliverables.

## GREEN-recovery amendment — 2026-08-31

This amendment is the durable recovery authority after the first Task 2B
one-time GREEN Store command failed. It preserves the accepted Task 2B product
contract above and supersedes only the original post-RED recovery, test-harness,
GREEN, regression, and checkpoint instructions where they conflict with this
section. No Task 3 work, live Ticket Tasks plan, owner-state access, Release
Radar mutation, external-service mutation, build, test, staging, commit, push,
or implementation edit is authorized by this amendment until the pre-resumption
gate below is satisfied.

### Recovery objective and user-visible outcome

The recovery objective is to correct the recovery-critical `StoreAcceptanceTests`
authority so the existing five-path Task 2B implementation can be evaluated
truthfully against the accepted product contract:

- schema v12 adds `ticket_task_plans` and `ticket_tasks` additively;
- migration from accepted schema v11 creates zero task plans and zero tasks;
- v11 data remains semantically unchanged;
- task-plan/task-history deletion and parent cascade are rejected;
- counterfeit schema objects fail closed through supported SQLite DDL setup;
- public Ticket Task model and audit-entity declarations remain scoped to
  persistence/model setup only;
- Task 3 remains closed and no live task plan is created.

The user-visible outcome remains unchanged from the accepted brief: Task 2B
prepares durable local persistence and public model types for later Ticket Task
APIs. It does not expose UI, command, owner workflow, projection, notification,
or live planning behavior.

### Controlling lineage and fixed recovery state

The accepted preimplementation planning checkpoint for this recovery is commit
`94f89409631b345d1058dd16a85aaae2f8e26885`, with HEAD, upstream, and live
remote all exact and ahead/behind `0/0` at the time the one-time RED and
one-time GREEN were run.

Original Task 2B brief lineage:

- first complete candidate brief SHA-256
  `968c2dad19e77c68ac44c5f3da770da1931e799c247e973f3dd057fcf6dc6c49`,
  registry SHA-256
  `f9f7e9ae5e90a1fd4cc1bccd3cd06f84f25ecc64cb95b826f68e36ca6560c8db`;
- corrected candidate brief SHA-256
  `8802606e5d5e25d05ed322dde66381eabfa3d30fb2a170ff2b727be7d7dacbd5`,
  registry SHA-256
  `35f03cfad537050f780cbc74fe0190975611660b54e1d3bb9b3f8607ffa1eb34`;
- final accepted brief SHA-256
  `5e1f416cee20ffbd4337beed155f7c04d144c9bd91f25a9e1d2294c18710d954`,
  root registry SHA-256
  `e40a565fd97722fc44fc72697a71138cdbf37aadda4abc392791ef8008951802`.

The valid one-time RED is retained under
`/tmp/release-radar-rr-r10-task2b-red.ZvNHEi`. Its retained evidence metadata
is:

- parent directory mode `700`;
- `red.log` mode `600`, size `373840`, SHA-256
  `e2ecbe942744ec8485dabde2653a1f85b422c51b4839d42e52a661429b4f34b9`;
- `red-sanitized.log` mode `600`, size `166546`, SHA-256
  `a3573c4982544e309afb5b6b7ed0cfc08a0c0f4fa8802a2aa16175485e92d7af`;
- `red.xcresult` directory retained.

The failed one-time GREEN is retained under
`/tmp/release-radar-rr-r10-task2b-green.YczYQm`. Its retained evidence metadata
is:

- parent directory mode `700`;
- `store-green.log` mode `600`, size `449226`, SHA-256
  `135c9b47b363d29a24e831408bbbf577eb2dfd24d6f899c5bd74c0ade3fa83a6`;
- `store-green.xcresult` directory retained;
- structured result summary: `43` Store tests total, `30` passed, `13` failed
  unique test identifiers, `0` skipped, `0` expected failures.

The recovery ledger may record `17` failure records or `8` unexpected failures
only if a fresh read-only `xcresulttool` extraction from
`store-green.xcresult` directly supports those exact scalar counts. The
recovery authority must not infer them from raw logs, copy raw logs, copy raw
JSON, or record them from memory. If the direct structured extraction does not
support those counts, the ledger must record only the supported scalar fields
above and the failure matrix below.

The original RED and GREEN one-run fences are consumed. No RED rerun, original
GREEN retry, regression run, diff check, postimplementation review, staging,
implementation checkpoint, or Task 3 release may occur until this recovery
amendment has been independently reviewed and committed as described below.

### Retained implementation inventory

The current uncommitted Task 2B implementation must be preserved exactly until
a reviewed recovery edit is authorized. Before any recovery edit, the
coordinator and recovery writer must verify these five retained blob IDs:

| Path | Required retained blob |
| --- | --- |
| `ReleaseRadarCore/Models/TicketTaskModels.swift` | `49f365dd1e074d4d2b716384756e71a3c5fb1ce1` |
| `ReleaseRadarCore/Store/DeliveryStore.swift` | `d930ab18794a959b44cad4293cee24647a1af8f6` |
| `ReleaseRadarCore/Store/StoreMigrations.swift` | `6fad7835211cace656e854aa0249f8775280a6dd` |
| `ReleaseRadarTests/StoreAcceptanceTests.swift` | `87d5ee313570069c6a5e237cf5b91e2aa10935e9` |
| `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift` | `d5d2bd7411bf7b10892b93ee57f62cc76c47492a` |

Read-only verification command:

```bash
set -euo pipefail
test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "87d5ee313570069c6a5e237cf5b91e2aa10935e9"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/StoreAcceptanceTests.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard ReleaseRadarCore/Models/TicketTaskModels.swift)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
```

If any retained blob differs, this amendment does not authorize recovery
implementation. A fresh diagnostic/recovery brief must explain the divergence
and receive new independent review.

### Failure-to-root-cause matrix

| Failing identifier | Required classification | Root cause | Authorized correction |
| --- | --- | --- | --- |
| `StoreAcceptanceTests/testExactVersionElevenFixtureMigratesToVersionTwelveWithoutInference()` | Required test/harness defect | The seeded v11 graph inserted `plan_legacy_continuation = 1`, which the accepted v11 trigger rejects because direct continuation grants are migration-only. | Seed representative v11 rows with omitted/default `plan_legacy_continuation` or explicit `0` only; add a seed assertion that no raw-seeded v11 row has nonzero continuation. |
| `StoreAcceptanceTests/testVersionTwelveMigrationFailureRollsBackToExactVersionElevenStateAndRecovers()` | Required test/harness defect | Same invalid v11 continuation seed occurs before the late-v12 collision path is exercised. | Use the corrected v11 seed before injecting the late-v12 trigger collision. |
| `StoreAcceptanceTests/testExactVersionTenFixtureMigratesToVersionElevenWithoutInference()` | Required test defect | Stale schema-11 assertion after opening the current store; Task 2B current schema is v12. | Change current-store post-open expectations and wording to schema 12/current while preserving v10 semantic snapshot assertions. |
| `StoreAcceptanceTests/testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit()` | Required test defect | Stale schema-11 assertion after relaunching through current migrations. | Expect schema 12 for the live database and keep the pre-migration snapshot version expectation unchanged. |
| `StoreAcceptanceTests/testVersionElevenManifestRejectsMissingOrCounterfeitPlanningObjects()` | Required harness defect | `makeVersionElevenDatabaseURL()` opens `DeliveryStore`, which migrates the database to v12 before the helper asserts v11. | Make the helper return a verified unopened schema-v11 fixture copy and never open `DeliveryStore` inside that helper. |
| `StoreAcceptanceTests/testVersionElevenMigrationFailureRollsBackToExactVersionTenStateAndRecovers()` | Required test defect | Stale schema-11 assertion after recovering through the current migration path. | Expect schema 12 after successful recovery and relaunch while preserving exact v10 snapshot equality. |
| `StoreAcceptanceTests/testVersionFourMigrationBackfillsOnlyUnambiguousActivePhase()` | Required harness defect | Downgrade helper removes v11 objects only; v12 task tables remain and collide when current migration reruns. | Drop v12 task triggers, indexes, and tables before removing v11 schema and lowering `user_version`; expect final schema 12. |
| `StoreAcceptanceTests/testVersionSevenMigrationBackfillsOnlyUnambiguousTicketGoalIdentity()` | Required harness defect | Same v12 leftover collision; final schema expectation is also stale. | Use the expanded downgrade helper and expect final schema 12 while preserving v7 snapshot assertions. |
| `StoreAcceptanceTests/testVersionNineAlertRulesMigrateExactlyAndOwnerChangesAuditOnce()` | Required harness defect | Same v12 leftover collision; final schema expectation is also stale. | Use the expanded downgrade helper and expect final schema 12 while preserving alert-rule and audit assertions. |
| `StoreAcceptanceTests/testVersionNineMigratesToVersionTenWithExactlyOneLifecycleSingleton()` | Required harness defect | Same v12 leftover collision; final schema expectation is also stale. | Use the expanded downgrade helper and expect final schema 12 while preserving lifecycle singleton assertions. |
| `StoreAcceptanceTests/testVersionTenMissingLifecycleSingletonIsUnavailableAndRecoverable()` | Required test defect | Unavailable/recovery message and database-version assertion still describe schema 11 after current schema has advanced to 12. | Update the failure message and post-failure original database version expectation to schema 12 while preserving missing-singleton recovery assertions. |
| `StoreAcceptanceTests/testVersionTwelveManifestRejectsMissingOrCounterfeitTaskObjects()` | Required harness defect | The counterfeit helper rewrites `sqlite_schema`/`sqlite_master` directly; SQLite rejects catalog mutation. | Replace direct catalog rewriting with supported SQLite DDL reconstruction that creates missing/counterfeit objects through ordinary `DROP`, `ALTER TABLE`, `CREATE TABLE`, `CREATE INDEX`, and `CREATE TRIGGER` statements only. |
| `StoreAcceptanceTests/testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants()` | Required test defect | The test expects a successful duplicate label in the same `(project_id, ticket_id)` ownership scope even though stable label uniqueness is required. | Make the successful historical/active task use a distinct label, then make the duplicate-label probe reuse an existing label with `expectSuccess: false`. |

Failure counts for this recovery: Required product implementation defects
currently identified: `0`. Required test/harness/recovery defects:
`13` failing identifiers across `6` correction/root-cause categories:
v11 continuation seeding, stale current-version assertions, schema-v11 fixture
helper construction, legacy downgrade cleanup, supported-SQLite counterfeit
manifest setup, and task-label uniqueness probing. Optional: `0`.
Out-of-scope: `0`.

No product defect is currently identified from the GREEN failure evidence.
Product correctness remains unapproved because the accepted GREEN and
regression evidence do not yet exist.

### Authorized recovery writer scope

After the pre-resumption gate and independent GO dispositions below, exactly
one fresh recovery writer may modify only:

- `ReleaseRadarTests/StoreAcceptanceTests.swift`

No recovery writer may modify `ReleaseRadarCore/Models/TicketTaskModels.swift`,
`ReleaseRadarCore/Store/DeliveryStore.swift`,
`ReleaseRadarCore/Store/StoreMigrations.swift`,
`ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`, fixtures,
project files, entitlements, signing configuration, package configuration,
scripts, generated result bundles, `/tmp` evidence, owner state, Release Radar
state, or external services unless a fresh reviewed correction brief supersedes
this amendment and names the exact additional file and reason.

### Exact recovery implementation requirements

Apply these corrections in `ReleaseRadarTests/StoreAcceptanceTests.swift` only.

1. Correct the representative v11 seed.
   - In `seedCompleteVersionElevenGraph(_:)`, remove
     `plan_legacy_continuation` from the raw `INSERT INTO tickets` column list
     and remove the continuation values, or keep the column and set every
     value to `0`.
   - Prefer omitting the column so the v11 default is exercised.
   - Add this assertion immediately after the seed script:

     ```swift
     XCTAssertEqual(
         try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE plan_legacy_continuation <> 0"),
         0
     )
     ```

   - Preserve v10-to-v11 migration tests that legitimately expect continuation
     rows created by migration. Do not insert continuation `1` directly into a
     schema-v11 fixture.

2. Correct the task-label uniqueness probe.
   - In `testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants`,
     change the successful `task-3` label from `"A"` to `"A2"`.
   - Change the duplicate-label probe `task-0` label from `"A2"` to `"A"` and
     keep `expectSuccess: false`.
   - Keep the active-order assertion as `"task-3,task-1"` because label
     `"A2"` sorts before `"B"` under BINARY collation and equal `sort_order`.

3. Correct the unopened schema-v11 fixture helper.
   - Replace `makeVersionElevenDatabaseURL()` with a helper that returns
     `try copyVerifiedVersionElevenFixture()`.
   - Do not instantiate `DeliveryStore` inside `makeVersionElevenDatabaseURL()`.
   - Preserve explicit unopened fixture v11 expectations in helpers and
     manifest tests where no current-store migration has run.

4. Correct the legacy downgrade helper.
   - Expand `removeVersionElevenSchema(_:)` or rename it to
     `removeCurrentSchemaAfterVersionTen(_:)`.
   - Before dropping v11 objects, drop v12 objects in dependency-safe order:

     ```sql
     DROP TRIGGER IF EXISTS ticket_task_plans_reject_project_delete;
     DROP TRIGGER IF EXISTS ticket_task_plans_reject_ticket_delete;
     DROP TRIGGER IF EXISTS ticket_tasks_reject_delete;
     DROP TRIGGER IF EXISTS ticket_task_plans_reject_delete;
     DROP TRIGGER IF EXISTS ticket_tasks_reject_label_update;
     DROP TRIGGER IF EXISTS ticket_tasks_reject_identity_update;
     DROP INDEX IF EXISTS ticket_tasks_active_order_index;
     DROP INDEX IF EXISTS ticket_tasks_label_unique;
     DROP INDEX IF EXISTS ticket_task_plans_ticket_unique;
     DROP TABLE IF EXISTS ticket_tasks;
     DROP TABLE IF EXISTS ticket_task_plans;
     ```

   - Then perform the existing v11 drops. Use `IF EXISTS` for v11 drops where
     the test setup can validly start from more than one legacy shape.
   - Update call sites if the helper is renamed.

5. Correct stale current-version assertions and messages.
   - Expectations after opening or reopening `DeliveryStore` on the current
     schema must expect `PRAGMA user_version = 12`.
   - Update at least these current-store assertions/messages:
     `testExactVersionTenFixtureMigratesToVersionElevenWithoutInference`,
     `testVersionElevenMigrationFailureRollsBackToExactVersionTenStateAndRecovers`,
     `testVersionFourMigrationBackfillsOnlyUnambiguousActivePhase`,
     `testVersionSevenMigrationBackfillsOnlyUnambiguousTicketGoalIdentity`,
     `testVersionNineAlertRulesMigrateExactlyAndOwnerChangesAuditOnce`,
     `testVersionNineMigratesToVersionTenWithExactlyOneLifecycleSingleton`,
     `testVersionTenMissingLifecycleSingletonIsUnavailableAndRecoverable`, and
     `testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit`.
   - Do not change explicit unopened fixture expectations that intentionally
     prove a copied schema-v10 or schema-v11 fixture remains at its pinned
     version before migration.

6. Replace direct SQLite catalog rewriting.
   - Delete or stop using `rewriteSchemaSQL`.
   - Do not use `PRAGMA writable_schema`, `UPDATE sqlite_schema`, `UPDATE
     sqlite_master`, `DELETE FROM sqlite_schema`, `DELETE FROM sqlite_master`,
     or any equivalent direct catalog mutation.
   - Create missing and counterfeit v12 manifest cases with supported SQLite
     DDL only.
   - For missing-object cases, ordinary `DROP TRIGGER IF EXISTS`, `DROP INDEX
     IF EXISTS`, and dependency-aware `DROP TABLE IF EXISTS` setup is allowed.
   - For counterfeit table cases, use one of these supported strategies:
     - start from a fresh schema-v11 fixture copy, apply a test-local v12 DDL
       script that creates all required v12 objects except the deliberately
       counterfeit table, set `PRAGMA user_version = 12`, and reopen
       `DeliveryStore`; or
     - on an empty v12 database, disable foreign keys for setup, drop dependent
       v12 triggers/indexes, drop the target empty table and dependent empty
       child table when required, recreate the target table with counterfeit
       SQL, recreate enough dependent required v12 objects with ordinary
       `CREATE` statements so the only intended mismatch is the counterfeit
       SQL, re-enable foreign keys, and reopen `DeliveryStore`.
   - For counterfeit trigger cases, use ordinary `DROP TRIGGER IF EXISTS` plus
     `CREATE TRIGGER` with a wrong body that still parses.
   - Every counterfeit setup must prove the target object exists before reopen
     and must fail closed through `DeliveryStore.availability`, not by throwing
     during harness setup.

### Corrected test strategy

Do not rerun RED. The retained RED is valid and consumed.

After this amendment has been reviewed, committed, pushed, and the committed
planning gate below has passed exactly once, the recovery writer must perform
one implementation edit pass and then run exactly one successor GREEN-recovery
Store fence from a fresh mode-700 parent. This is not a retry of the original
GREEN; it is a new recovery-authorized GREEN fence with the original failed
GREEN retained as historical evidence.

If the successor GREEN-recovery Store fence fails for any reason, stop before
regression, `git diff --check`, review, staging, checkpoint, retry, or Task 3.
The failure must be diagnosed in a new reviewed recovery artifact.

If and only if the successor GREEN-recovery Store fence passes, run exactly one
combined Store plus plugin-lifecycle regression fence from a separate fresh
mode-700 parent. If that regression fails for any reason, stop before
postimplementation review, staging, checkpoint, retry, or Task 3.

### Successor GREEN-recovery Store fence

Run exactly once after the authorized `StoreAcceptanceTests.swift` recovery
edit. Use a fresh parent path and verify it is mode `700`.

```bash
set -euo pipefail
umask 077
RR_TASK2B_RECOVERY_GREEN_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-green-recovery.XXXXXX)"
chmod 700 "$RR_TASK2B_RECOVERY_GREEN_PARENT"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY_GREEN_PARENT")" = "700"
RR_TASK2B_RECOVERY_GREEN_DERIVED="$RR_TASK2B_RECOVERY_GREEN_PARENT/DerivedData"
RR_TASK2B_RECOVERY_GREEN_RESULT="$RR_TASK2B_RECOVERY_GREEN_PARENT/store-green-recovery.xcresult"
RR_TASK2B_RECOVERY_GREEN_LOG="$RR_TASK2B_RECOVERY_GREEN_PARENT/store-green-recovery.log"
RR_TASK2B_RECOVERY_GREEN_SUMMARY="$RR_TASK2B_RECOVERY_GREEN_PARENT/store-green-recovery-summary.json"
RR_TASK2B_RECOVERY_GREEN_TESTS="$RR_TASK2B_RECOVERY_GREEN_PARENT/store-green-recovery-tests.json"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'
for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_RECOVERY_GREEN_DERIVED" \
  "$RR_TASK2B_RECOVERY_GREEN_RESULT" \
  "$RR_TASK2B_RECOVERY_GREEN_LOG" \
  "$RR_TASK2B_RECOVERY_GREEN_SUMMARY" \
  "$RR_TASK2B_RECOVERY_GREEN_TESTS"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_RECOVERY_GREEN_DERIVED" \
  -resultBundlePath "$RR_TASK2B_RECOVERY_GREEN_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests >"$RR_TASK2B_RECOVERY_GREEN_LOG" 2>&1
RR_TASK2B_RECOVERY_GREEN_STATUS=$?
set -e
test -f "$RR_TASK2B_RECOVERY_GREEN_LOG"
test ! -L "$RR_TASK2B_RECOVERY_GREEN_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY_GREEN_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY_GREEN_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY_GREEN_LOG")")" = "$(realpath "$RR_TASK2B_RECOVERY_GREEN_PARENT")"
RR_TASK2B_RECOVERY_GREEN_LOG_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" "$RR_TASK2B_RECOVERY_GREEN_LOG" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY_GREEN_LOG_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY_GREEN_LOG_SCAN_STATUS" = "1"
test "$RR_TASK2B_RECOVERY_GREEN_STATUS" = "0"
test -d "$RR_TASK2B_RECOVERY_GREEN_RESULT"
test ! -L "$RR_TASK2B_RECOVERY_GREEN_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY_GREEN_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY_GREEN_RESULT")")" = "$(realpath "$RR_TASK2B_RECOVERY_GREEN_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary --path "$RR_TASK2B_RECOVERY_GREEN_RESULT" --compact >"$RR_TASK2B_RECOVERY_GREEN_SUMMARY"
  xcrun xcresulttool get test-results tests --path "$RR_TASK2B_RECOVERY_GREEN_RESULT" --compact >"$RR_TASK2B_RECOVERY_GREEN_TESTS"
)
for RR_TASK2B_RESULT_FILE in \
  "$RR_TASK2B_RECOVERY_GREEN_LOG" \
  "$RR_TASK2B_RECOVERY_GREEN_SUMMARY" \
  "$RR_TASK2B_RECOVERY_GREEN_TESTS"; do
  test -f "$RR_TASK2B_RESULT_FILE"
  test ! -L "$RR_TASK2B_RESULT_FILE"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RESULT_FILE")" = "Regular File"
  test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RESULT_FILE")" = "600"
  test "$(dirname "$(realpath "$RR_TASK2B_RESULT_FILE")")" = "$(realpath "$RR_TASK2B_RECOVERY_GREEN_PARENT")"
done
RR_TASK2B_RECOVERY_GREEN_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_RECOVERY_GREEN_LOG" "$RR_TASK2B_RECOVERY_GREEN_SUMMARY" "$RR_TASK2B_RECOVERY_GREEN_TESTS" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY_GREEN_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY_GREEN_SCAN_STATUS" = "1"
python3 - "$RR_TASK2B_RECOVERY_GREEN_SUMMARY" "$RR_TASK2B_RECOVERY_GREEN_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected = {
    "result": "Passed",
    "totalTestCount": 43,
    "passedTests": 43,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected summary field {key}: {summary.get(key)!r}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be empty")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 43 or len({identifier for identifier, _ in cases}) != 43:
    raise SystemExit("expected exactly 43 unique Store test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every Store test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
if len(store) != 43 or len(store) != len(cases):
    raise SystemExit("unexpected suite in Store-only result")
PYTHON
```

Expected: exactly `43/43` Store tests pass, with zero failures, zero skips,
zero expected failures, zero failure records, mode-`600` retained summary/test
files, and privacy scan status `1` for no secret/private-key matches. The
coordinator may record only sanitized scalar facts.

### Combined Store plus plugin-lifecycle regression fence

Run exactly once only after the successor GREEN-recovery Store fence passes.
Use a new mode-700 parent distinct from RED, original GREEN, and recovery
GREEN evidence.

```bash
set -euo pipefail
umask 077
RR_TASK2B_RECOVERY_REGRESSION_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-regression-recovery.XXXXXX)"
chmod 700 "$RR_TASK2B_RECOVERY_REGRESSION_PARENT"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY_REGRESSION_PARENT")" = "700"
RR_TASK2B_RECOVERY_REGRESSION_DERIVED="$RR_TASK2B_RECOVERY_REGRESSION_PARENT/DerivedData"
RR_TASK2B_RECOVERY_REGRESSION_RESULT="$RR_TASK2B_RECOVERY_REGRESSION_PARENT/regression-recovery.xcresult"
RR_TASK2B_RECOVERY_REGRESSION_LOG="$RR_TASK2B_RECOVERY_REGRESSION_PARENT/regression-recovery.log"
RR_TASK2B_RECOVERY_REGRESSION_SUMMARY="$RR_TASK2B_RECOVERY_REGRESSION_PARENT/regression-recovery-summary.json"
RR_TASK2B_RECOVERY_REGRESSION_TESTS="$RR_TASK2B_RECOVERY_REGRESSION_PARENT/regression-recovery-tests.json"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'
for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_RECOVERY_REGRESSION_DERIVED" \
  "$RR_TASK2B_RECOVERY_REGRESSION_RESULT" \
  "$RR_TASK2B_RECOVERY_REGRESSION_LOG" \
  "$RR_TASK2B_RECOVERY_REGRESSION_SUMMARY" \
  "$RR_TASK2B_RECOVERY_REGRESSION_TESTS"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_RECOVERY_REGRESSION_DERIVED" \
  -resultBundlePath "$RR_TASK2B_RECOVERY_REGRESSION_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests >"$RR_TASK2B_RECOVERY_REGRESSION_LOG" 2>&1
RR_TASK2B_RECOVERY_REGRESSION_STATUS=$?
set -e
test -f "$RR_TASK2B_RECOVERY_REGRESSION_LOG"
test ! -L "$RR_TASK2B_RECOVERY_REGRESSION_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY_REGRESSION_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY_REGRESSION_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY_REGRESSION_LOG")")" = "$(realpath "$RR_TASK2B_RECOVERY_REGRESSION_PARENT")"
RR_TASK2B_RECOVERY_REGRESSION_LOG_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" "$RR_TASK2B_RECOVERY_REGRESSION_LOG" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY_REGRESSION_LOG_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY_REGRESSION_LOG_SCAN_STATUS" = "1"
test "$RR_TASK2B_RECOVERY_REGRESSION_STATUS" = "0"
test -d "$RR_TASK2B_RECOVERY_REGRESSION_RESULT"
test ! -L "$RR_TASK2B_RECOVERY_REGRESSION_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY_REGRESSION_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY_REGRESSION_RESULT")")" = "$(realpath "$RR_TASK2B_RECOVERY_REGRESSION_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary --path "$RR_TASK2B_RECOVERY_REGRESSION_RESULT" --compact >"$RR_TASK2B_RECOVERY_REGRESSION_SUMMARY"
  xcrun xcresulttool get test-results tests --path "$RR_TASK2B_RECOVERY_REGRESSION_RESULT" --compact >"$RR_TASK2B_RECOVERY_REGRESSION_TESTS"
)
for RR_TASK2B_RESULT_FILE in \
  "$RR_TASK2B_RECOVERY_REGRESSION_LOG" \
  "$RR_TASK2B_RECOVERY_REGRESSION_SUMMARY" \
  "$RR_TASK2B_RECOVERY_REGRESSION_TESTS"; do
  test -f "$RR_TASK2B_RESULT_FILE"
  test ! -L "$RR_TASK2B_RESULT_FILE"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RESULT_FILE")" = "Regular File"
  test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RESULT_FILE")" = "600"
  test "$(dirname "$(realpath "$RR_TASK2B_RESULT_FILE")")" = "$(realpath "$RR_TASK2B_RECOVERY_REGRESSION_PARENT")"
done
RR_TASK2B_RECOVERY_REGRESSION_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_RECOVERY_REGRESSION_LOG" "$RR_TASK2B_RECOVERY_REGRESSION_SUMMARY" "$RR_TASK2B_RECOVERY_REGRESSION_TESTS" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY_REGRESSION_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY_REGRESSION_SCAN_STATUS" = "1"
python3 - "$RR_TASK2B_RECOVERY_REGRESSION_SUMMARY" "$RR_TASK2B_RECOVERY_REGRESSION_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected = {
    "result": "Passed",
    "totalTestCount": 64,
    "passedTests": 64,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected summary field {key}: {summary.get(key)!r}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be empty")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 64 or len({identifier for identifier, _ in cases}) != 64:
    raise SystemExit("expected exactly 64 unique selected test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every selected test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
plugin = [identifier for identifier, _ in cases if identifier.startswith("CodexPluginLifecycleAcceptanceTests/")]
if len(store) != 43 or len(plugin) != 21 or len(store) + len(plugin) != len(cases):
    raise SystemExit("unexpected selected suite split")
PYTHON
```

Expected: exactly `64/64` selected tests pass, with exact `43/21`
Store/plugin split, zero failures, zero skips, zero expected failures, zero
failure records, mode-`600` retained summary/test files, and privacy scan
status `1` for no secret/private-key matches. The coordinator may record only
sanitized scalar facts.

### Pre-resumption planning checkpoint gate

Before any recovery edit, build, test, executable run, staging, commit, push,
or owner/external action, fresh independent Architecture, QA/Test, TPM,
Delivery Management, and Security/Privacy reviewers must each return GO with
Required `0` on this amended brief and registry entry. Delivery Management
must additionally review the actual coordinator ledger literal hash bindings
and exact checkpoint inventory before staging.

After final exact-hash reviews and before staging, the coordinator must update
`docs/delivery/progress.md` with reviewer dispositions and exactly one literal
field for each of these two non-circular bindings:

```text
- RR-R10 Task 2B recovery final reviewed brief SHA-256: `<64 lowercase hex>`
- RR-R10 Task 2B recovery final reviewed registry SHA-256: `<64 lowercase hex>`
```

The two ledger fields must bind the reviewed current worktree bytes of this
brief and `docs/delivery/task-briefs/SHA256SUMS`. This brief must not contain
its own final SHA-256 as a required literal because that would be
self-referential.

Run this precommit gate exactly once after the coordinator ledger update and
before staging:

```bash
set -euo pipefail
RR_TASK2B_BASE=94f89409631b345d1058dd16a85aaae2f8e26885
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md

test "$(git rev-parse HEAD)" = "$RR_TASK2B_BASE"
test "$(git rev-parse @{u})" = "$RR_TASK2B_BASE"
test "$(git ls-remote origin refs/heads/codex/release-radar-mvp | awk '{print $1}')" = "$RR_TASK2B_BASE"
test "$(git rev-list --left-right --count HEAD...@{u} | tr '\t' ' ')" = "0 0"
git diff --cached --exit-code

RR_TASK2B_LEDGER_SHAS="$(python3 - "$RR_TASK2B_LEDGER" <<'PYTHON'
import re
import sys

ledger = open(sys.argv[1], encoding="utf-8").read()
patterns = {
    "brief": r"^- RR-R10 Task 2B recovery final reviewed brief SHA-256: `([0-9a-f]{64})`$",
    "registry": r"^- RR-R10 Task 2B recovery final reviewed registry SHA-256: `([0-9a-f]{64})`$",
}
values = []
for name, pattern in patterns.items():
    matches = re.findall(pattern, ledger, flags=re.MULTILINE)
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one {name} SHA ledger field, found {len(matches)}")
    values.append(matches[0])
print(" ".join(values))
PYTHON
)"
RR_TASK2B_LEDGER_BRIEF_SHA="${RR_TASK2B_LEDGER_SHAS%% *}"
RR_TASK2B_LEDGER_REGISTRY_SHA="${RR_TASK2B_LEDGER_SHAS##* }"
test "$RR_TASK2B_LEDGER_BRIEF_SHA" = "$(shasum -a 256 "$RR_TASK2B_BRIEF" | awk '{print $1}')"
test "$RR_TASK2B_LEDGER_REGISTRY_SHA" = "$(shasum -a 256 "$RR_TASK2B_REGISTRY" | awk '{print $1}')"
test "$(awk -v path="$RR_TASK2B_BRIEF" '$2 == path { count += 1 } END { print count + 0 }' "$RR_TASK2B_REGISTRY")" = "1"
shasum -a 256 -c "$RR_TASK2B_REGISTRY"

test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "87d5ee313570069c6a5e237cf5b91e2aa10935e9"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift docs/delivery/progress.md docs/delivery/task-briefs/SHA256SUMS docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
```

The planning checkpoint commit may stage exactly this brief,
`docs/delivery/task-briefs/SHA256SUMS`, and `docs/delivery/progress.md`.
The five retained implementation paths must remain unstaged and must still
match the retained blob inventory.

After staging, run this exact checkpoint assembly gate before committing:

```bash
set -euo pipefail
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md

test "$(git diff --cached --name-only | LC_ALL=C sort)" = "$(printf '%s\n' "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" | LC_ALL=C sort)"
git diff --exit-code -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "87d5ee313570069c6a5e237cf5b91e2aa10935e9"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
```

After the planning commit, push to `origin/codex/release-radar-mvp`. Then run
this committed post-push recovery gate exactly once. This gate verifies the
committed bytes without altering the worktree.

```bash
set -euo pipefail
RR_TASK2B_BASE=94f89409631b345d1058dd16a85aaae2f8e26885
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md

test "$(git rev-parse HEAD^)" = "$RR_TASK2B_BASE"
test "$(git diff-tree --no-commit-id --name-only -r HEAD | LC_ALL=C sort)" = "$(printf '%s\n' "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" | LC_ALL=C sort)"
test "$(git rev-parse HEAD)" = "$(git rev-parse @{u})"
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/codex/release-radar-mvp | awk '{print $1}')"
test "$(git rev-list --left-right --count HEAD...@{u} | tr '\t' ' ')" = "0 0"

python3 - "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" <<'PYTHON'
import hashlib
import re
import subprocess
import sys

brief_path, registry_path, ledger_path = sys.argv[1:4]

def committed_text(path):
    return subprocess.check_output(["git", "show", f"HEAD:{path}"], text=True)

def committed_bytes(path):
    return subprocess.check_output(["git", "show", f"HEAD:{path}"])

ledger = committed_text(ledger_path)
patterns = {
    "brief": r"^- RR-R10 Task 2B recovery final reviewed brief SHA-256: `([0-9a-f]{64})`$",
    "registry": r"^- RR-R10 Task 2B recovery final reviewed registry SHA-256: `([0-9a-f]{64})`$",
}
ledger_values = {}
for name, pattern in patterns.items():
    matches = re.findall(pattern, ledger, flags=re.MULTILINE)
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one committed {name} SHA ledger field, found {len(matches)}")
    ledger_values[name] = matches[0]

if hashlib.sha256(committed_bytes(brief_path)).hexdigest() != ledger_values["brief"]:
    raise SystemExit("committed brief hash does not match committed ledger literal")
if hashlib.sha256(committed_bytes(registry_path)).hexdigest() != ledger_values["registry"]:
    raise SystemExit("committed registry hash does not match committed ledger literal")

registry = committed_text(registry_path)
task2b_count = 0
for line_number, line in enumerate(registry.splitlines(), start=1):
    if not line:
        continue
    parts = line.split("  ", 1)
    if len(parts) != 2:
        raise SystemExit(f"registry line {line_number} is not two-space separated")
    digest, path = parts
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise SystemExit(f"registry line {line_number} has invalid digest")
    actual = hashlib.sha256(committed_bytes(path)).hexdigest()
    if actual != digest:
        raise SystemExit(f"registry mismatch for {path}")
    if path == brief_path:
        task2b_count += 1
if task2b_count != 1:
    raise SystemExit(f"expected exactly one Task 2B registry entry, found {task2b_count}")
PYTHON

git diff --exit-code -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "87d5ee313570069c6a5e237cf5b91e2aa10935e9"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift | LC_ALL=C sort)"
test "$(git diff --cached --name-only)" = ""
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
```

Only after this committed recovery planning gate passes may the coordinator
release the fresh recovery writer for the single-file test-harness edit and
the one-time successor GREEN-recovery Store fence. No test, build, executable
run, regression, diff-check, implementation review, implementation staging,
implementation commit, or Task 3 release is permitted before this committed
recovery gate passes.

### Postimplementation boundary and required reviews

After the authorized recovery writer completes the single-file edit and the
two one-time fences above pass, no further product or test edit is authorized.
Run `git diff --check` once, verify the schema-v10/schema-v11 fixture manifests
remain byte-identical, and preserve all `/tmp` evidence. Then obtain fresh
independent Code Review, QA/Test, Architecture, Security/Privacy, TPM, and
Delivery Management GO with Required `0`.

The postimplementation checkpoint may stage and commit only:

- the five Task 2B implementation paths named in this brief;
- coordinator-owned `docs/delivery/progress.md`.

It must not stage this planning amendment again unless the coordinator makes a
new reviewed planning correction. It must not stage raw logs, raw result
bundles, temporary summaries, fixtures, scripts, project files, owner data,
Release Radar state, or external-service artifacts.

Task 3, live task-plan creation, RR-R10 command behavior, owner UI, projection,
notification, bridge/MCP behavior, and all external mutations remain closed
until the postimplementation checkpoint is committed, pushed, and verified at
exact local/upstream/live remote equality with ahead/behind `0/0`.

### Activity, audit, privacy, and evidence retention

This recovery authorizes no production activity or audit event. It authorizes
only repository planning documentation, later single-file test-harness repair,
and local test evidence. No Release Radar SQLite write, direct SQLite owner
database access, owner bundle launch, bridge launch, notification dispatch,
Pushover access, provider access, or credential inspection is authorized.

Raw logs, raw result bundles, raw extracted JSON, owner data, secret matches,
private-key matches, and matching lines must not be copied into durable
artifacts. Durable summaries may contain only sanitized scalar facts: command
identity, paths, modes, sizes, SHA-256 hashes, result status, suite
cardinality, supported failure counts, failing identifiers, root-cause
classification, role-review dispositions, and scan statuses.

Temporary evidence retained and not deleted:

- `/tmp/release-radar-rr-r10-task2b-red.ZvNHEi`;
- `/tmp/release-radar-rr-r10-task2b-green.YczYQm`.

Future recovery GREEN and regression evidence must also remain under fresh
mode-700 `/tmp` parents, must not be staged, and must not be deleted without
explicit owner authorization.

### Recovery acceptance criteria

- This amended brief and root registry are reviewed by Architecture, QA/Test,
  TPM, Delivery Management, and Security/Privacy with GO/Required `0`.
- Delivery Management reviews the actual ledger literal hash bindings and
  checkpoint inventory before staging.
- Coordinator `progress.md` contains exactly one final reviewed brief SHA
  field and exactly one final reviewed registry SHA field, and both literal
  values match the actual current worktree hashes before staging and the
  committed hashes after push.
- The planning checkpoint stages exactly this brief, the task-brief registry,
  and coordinator `progress.md`, while the five retained implementation paths
  remain unstaged and match the blob inventory above.
- The committed recovery planning gate passes exactly once after push and
  remote equality proof, with parent exactly
  `94f89409631b345d1058dd16a85aaae2f8e26885`, commit inventory exactly
  brief/registry/progress, full committed registry verification, clean doc
  worktree, and exact retained implementation inventory still unstaged.
- Recovery implementation modifies only
  `ReleaseRadarTests/StoreAcceptanceTests.swift`.
- The v11 seed no longer performs direct continuation grants.
- The duplicate-label test probes stable label reuse as a rejection, not as a
  successful insert.
- The schema-v11 helper returns an unopened verified fixture copy.
- Legacy downgrade setup removes v12 task objects before lowering schema
  versions.
- Current-store migration tests expect schema 12 after `DeliveryStore` opens
  or relaunches; unopened pinned fixture expectations remain v10/v11.
- Counterfeit manifest tests use supported SQLite DDL only and never rewrite
  `sqlite_schema` or `sqlite_master`.
- The successor GREEN-recovery Store fence runs once and passes exactly
  `43/43`.
- The combined Store plus plugin-lifecycle regression fence runs once after
  GREEN-recovery success and passes exactly `64/64` with split `43/21`.
- Failure at any recovery fence stops work before retry, regression when
  GREEN failed, diff check, review, staging, checkpoint, or Task 3.
- Postimplementation independent Code Review, QA/Test, Architecture,
  Security/Privacy, TPM, and Delivery Management return GO/Required `0`.
- All RED, failed GREEN, recovery GREEN, and regression evidence remains
  temporary, retained, unstaged, privacy-scanned before summary, and not
  deleted.

## Second GREEN-recovery amendment — 2026-08-31

This amendment is the durable recovery authority after the first
GREEN-recovery Store fence failed. It preserves the accepted Task 2B product,
architecture, persistence, migration, privacy, and fixture contracts above and
supersedes only the first GREEN-recovery amendment's post-failure diagnosis,
writer scope, successor-fence, regression, planning-checkpoint, and
postimplementation instructions where they conflict with this section.

No implementation edit, build, test, executable run, gate, staging, commit,
push, owner-state access, Release Radar mutation, external-service mutation,
live Ticket Tasks plan, or Task 3 work is authorized until the second-recovery
pre-resumption reviews and committed planning checkpoint defined below pass.

### Objective and user-visible outcome

The recovery objective is to correct one cardinality defect in the Task 2B
Store acceptance harness without changing product behavior. The accepted
user-visible outcome remains schema-v12 persistence and public value types for
future Ticket Task behavior. This amendment does not add a command, UI,
projection, notification, bridge/MCP behavior, owner workflow, live task plan,
or any new persistence behavior.

The exact successful outcome of the recovery implementation is:

- the accepted schema-v12 implementation remains byte-identical across its
  four non-Store-test paths;
- the Store ordering assertion requests the two rows it asserts;
- all `43` selected Store acceptance tests pass once in a newly authorized
  second-successor GREEN fence;
- only after that success, all `64` selected Store plus plugin-lifecycle tests
  pass once with exact `43/21` suite cardinality;
- Task 3 and every live product path remain closed.

### Controlling references and dependency gate

This amendment remains controlled by:

- `docs/superpowers/plans/2026-08-23-release-radar-mvp.md`;
- `docs/design/agent-driven-delivery-dashboard-design.md`;
- `docs/design/release-radar-ticket-tasks-design.md`;
- `docs/architecture/ADR-001-release-radar-boundaries.md`;
- `docs/architecture/ADR-005-ticket-task-work-plans.md`;
- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`;
- this canonical Task 2B brief;
- `docs/delivery/progress.md` as the only delivery ledger.

The fixed second-recovery base checkpoint is
`22178e5cea42a3a3006a8800309d5a76f6610596`. At authorization, local HEAD,
upstream, and the live `origin/codex/release-radar-mvp` remote were exact at
that commit with ahead/behind `0/0`. The accepted first-recovery brief SHA-256
is `01a4a13081f2c7f37e800a6be53cc19e471960925acd7fe62cb69c07ad333379` and
the accepted root task-brief registry SHA-256 is
`9ac9eef010404426c000ea36f99a20f7e5f717ce1978c2796c708cdb6feb917d`.

Task 2A and the accepted schema-v11 fixture remain dependency prerequisites.
Task 3 remains dependency-blocked until Task 2B has passing second-successor
GREEN and regression evidence, all six postimplementation reviews, and an
accepted implementation checkpoint at exact local/upstream/live-remote
equality.

### First-successor evidence and sanitized failure facts

The first GREEN-recovery Store fence was consumed exactly once and failed. Its
restricted evidence is retained at
`/tmp/release-radar-rr-r10-task2b-green-recovery.uYnBjE`:

- parent directory mode `700`;
- `store-green-recovery.log` mode `600`, size `450416`, SHA-256
  `f48aafa353257827ed9a83e5a1df598d15716f3a7f4619f0b5faf1779a28198a`;
- `store-green-recovery.xcresult` directory present and retained;
- structured result `Failed`, `43` total, `42` passed, `1` failed, `0`
  skipped, `0` expected failures, and exactly `1` failure record;
- exactly `43` unique Store test identifiers;
- privacy scan status `1` for no secret/private-key marker match.

The exact failed identifier is:

`StoreAcceptanceTests/testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants()`

Fresh read-only structured inspection reported every other identifier from the
original thirteen-failure matrix as `Passed`:

1. `testExactVersionElevenFixtureMigratesToVersionTwelveWithoutInference()`
2. `testVersionTwelveMigrationFailureRollsBackToExactVersionElevenStateAndRecovers()`
3. `testExactVersionTenFixtureMigratesToVersionElevenWithoutInference()`
4. `testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit()`
5. `testVersionElevenManifestRejectsMissingOrCounterfeitPlanningObjects()`
6. `testVersionElevenMigrationFailureRollsBackToExactVersionTenStateAndRecovers()`
7. `testVersionFourMigrationBackfillsOnlyUnambiguousActivePhase()`
8. `testVersionSevenMigrationBackfillsOnlyUnambiguousTicketGoalIdentity()`
9. `testVersionNineAlertRulesMigrateExactlyAndOwnerChangesAuditOnce()`
10. `testVersionNineMigratesToVersionTenWithExactlyOneLifecycleSingleton()`
11. `testVersionTenMissingLifecycleSingletonIsUnavailableAndRecoverable()`
12. `testVersionTwelveManifestRejectsMissingOrCounterfeitTaskObjects()`

Two diagnostic-tool incidents are retained only as sanitized categories. A
surrounding read-only command wrapper terminated while reporting the already
failed fence, and a later read-only parser command had a quoting `SyntaxError`.
Neither incident invoked another build or test, mutated the repository,
evidence, owner state, Release Radar, or an external service, nor changed the
structured result. Neither incident was retried. They do not authorize a
fence rerun.

The original RED, original GREEN, and first-successor GREEN-recovery fences are
all consumed. The combined regression has not run.

### Direct root cause and classification

The sole failure is a Required prior-recovery test-harness defect. The first
recovery correctly made `task-3` a successful active row with label `A2` and
made `task-0` a rejected duplicate-label probe with label `A`. The same test
then successfully inserts exact-boundary task probes into the same
`(project_id, ticket_id)` plan with lifecycle `active` and `sort_order = 50`.

The final ordering query orders active tasks by `sort_order`, BINARY `label`,
and BINARY `id`, requests `LIMIT 3`, but asserts only
`"task-3,task-1"`. SQLite therefore correctly returns the two intended
ordering fixtures plus one valid boundary-probe row. The accepted product
constraint and the valid boundary insertion are working as designed; the
query cardinality is wrong for the two-row assertion.

Classification:

- Required product implementation defects: `0`;
- Required test/harness defects: `1`, specifically the incomplete prior
  recovery edit/instruction at the active-order assertion;
- Optional: `0`;
- Out-of-scope: `0`.

Product correctness remains unaccepted until the newly authorized evidence
passes, but no product defect is identified.

### In scope, out of scope, and affected files

In scope after the committed second-recovery planning gate:

- one fresh sole-writer implementation pass;
- one textual change in
  `ReleaseRadarTests/StoreAcceptanceTests.swift`;
- one newly authorized second-successor Store GREEN fence;
- only after Store GREEN success, one newly authorized selected regression
  fence;
- ordinary fixture/diff checks and independent postimplementation review only
  after both fences pass;
- coordinator-owned sanitized ledger evidence and the bounded implementation
  checkpoint.

Out of scope:

- every product-source, model, migration, fixture, project, scheme,
  entitlement, signing, sandbox, package, script, generated-result, UI,
  command, projection, notification, bridge/MCP, owner-state, Release Radar,
  and external-service edit or mutation;
- RED reconstruction or rerun;
- rerunning the original GREEN or first-successor GREEN-recovery fences;
- preserving or accepting a different Store test blob;
- retrying any failed build, test, extraction, parser, cardinality,
  containment, mode, hash, or privacy check;
- Task 3 and live task-plan creation.

The only implementation file that may change is:

- `ReleaseRadarTests/StoreAcceptanceTests.swift`

The planning checkpoint may change only this brief, the root task-brief
registry, and coordinator-owned `docs/delivery/progress.md`. This Planning
writer changes only the brief and registry; Delivery Management owns the later
ledger update and reviews the actual ledger before staging.

### Data, persistence, security, and privacy implications

The recovery changes no table, index, trigger, migration, public type,
persistence format, database row, fixture, data-retention rule, sandbox,
entitlement, permission, authentication boundary, owner data, or external
state. Exact-boundary task rows remain successful test fixtures and continue
to exercise the accepted byte-length contract.

No raw log, raw extracted JSON, raw result bundle, owner data, credential,
secret match, private-key match, or matching line may enter a durable artifact
or terminal summary. Restricted evidence remains under fresh mode-`700`
parents; regular log/summary/test files remain mode `600`; result bundles
remain contained directories. A privacy scan status other than exactly `1`
stops the fence before structured extraction or durable summary.

### Retained implementation inventory and exact target blob

Before the second-recovery writer edits anything, all five retained paths must
match exactly:

| Path | Required pre-edit blob |
| --- | --- |
| `ReleaseRadarCore/Models/TicketTaskModels.swift` | `49f365dd1e074d4d2b716384756e71a3c5fb1ce1` |
| `ReleaseRadarCore/Store/DeliveryStore.swift` | `d930ab18794a959b44cad4293cee24647a1af8f6` |
| `ReleaseRadarCore/Store/StoreMigrations.swift` | `6fad7835211cace656e854aa0249f8775280a6dd` |
| `ReleaseRadarTests/StoreAcceptanceTests.swift` | `4d7ac34c31e19c16c46b6bae3d1cf3aec1f294e3` |
| `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift` | `d5d2bd7411bf7b10892b93ee57f62cc76c47492a` |

After the exact edit, the required
`ReleaseRadarTests/StoreAcceptanceTests.swift` blob is
`6be00b5661c48121b4fa054507b15b627fda1c9f`. The other four blobs must remain
exactly unchanged.

Any pre-edit or post-edit blob mismatch stops work and requires a new reviewed
recovery amendment. Do not repair, recreate, or normalize a mismatched file.

### Exact authorized implementation

After all five pre-resumption reviewers return GO/Required `0`, the
second-recovery planning checkpoint is committed and pushed, and the committed
post-push gate passes exactly once, one fresh sole writer may make exactly this
change in
`testVersionTwelveTaskSchemaEnforcesCompositeOwnershipAndInvariants()`:

```diff
-        try connection.scalarText("SELECT group_concat(id, ',') FROM (SELECT id FROM ticket_tasks WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND lifecycle = 'active' ORDER BY sort_order, label COLLATE BINARY, id COLLATE BINARY LIMIT 3)"),
+        try connection.scalarText("SELECT group_concat(id, ',') FROM (SELECT id FROM ticket_tasks WHERE project_id = 'p1' AND ticket_id = 'ticket-1' AND lifecycle = 'active' ORDER BY sort_order, label COLLATE BINARY, id COLLATE BINARY LIMIT 2)"),
         "task-3,task-1"
```

The expected value remains exactly `"task-3,task-1"`. The writer must not
move, reformat, rename, refactor, or otherwise change the assertion, the
boundary probes, any helper, or any other line. The one-line edit must produce
the exact post-edit blob above.

### Test fixtures and strategy

No new RED is authorized. The original one-time RED remains valid and
consumed. The first recovery closed twelve of the thirteen original failures;
the retained first-successor xcresult is the diagnostic evidence for the
single remaining harness defect.

Happy path:

1. Verify the exact pre-edit five-blob inventory.
2. Apply the one-line `LIMIT 3` to `LIMIT 2` edit.
3. Verify the exact post-edit five-blob inventory.
4. Run the second-successor Store GREEN fence exactly once from a fresh,
   unique, restricted evidence parent.
5. Require exact structured `43/43` Store success and all privacy,
   containment, mode, uniqueness, and failure-record checks.
6. Only then run the selected regression fence exactly once from a different
   fresh restricted parent.
7. Require exact structured `64/64` success with `43/21` Store/plugin split.
8. Only then run `git diff --check` once, verify schema-v10/schema-v11 fixture
   manifests and fixture bytes remain exact, and begin independent review.

Non-happy path:

- Any blob, branch, base, remote, inventory, mode, containment, no-clobber,
  command, exit-status, log scan, result-bundle, extraction, parser,
  cardinality, uniqueness, suite, failure-record, or privacy check failure
  stops immediately.
- A failed second-successor GREEN stops before regression, diff check, review,
  staging, checkpoint, retry, or Task 3.
- A failed regression stops before diff check, review, staging, checkpoint,
  retry, or Task 3.
- A wrapper or parser failure is a fence failure, not permission to rerun the
  underlying command or repeat extraction.
- All evidence remains retained and unstaged after any stop.

### Second-successor GREEN fence

This is a newly authorized successor fence, not a retry. Run it exactly once
after the exact edit and post-edit blob gate. Its fresh parent prefix is unique
from every earlier RED, GREEN, and recovery parent.

```bash
set -euo pipefail
umask 077
RR_TASK2B_RECOVERY2_GREEN_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-green-recovery-2.XXXXXX)"
chmod 700 "$RR_TASK2B_RECOVERY2_GREEN_PARENT"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY2_GREEN_PARENT")" = "700"
RR_TASK2B_RECOVERY2_GREEN_DERIVED="$RR_TASK2B_RECOVERY2_GREEN_PARENT/DerivedData"
RR_TASK2B_RECOVERY2_GREEN_RESULT="$RR_TASK2B_RECOVERY2_GREEN_PARENT/store-green-recovery-2.xcresult"
RR_TASK2B_RECOVERY2_GREEN_LOG="$RR_TASK2B_RECOVERY2_GREEN_PARENT/store-green-recovery-2.log"
RR_TASK2B_RECOVERY2_GREEN_SUMMARY="$RR_TASK2B_RECOVERY2_GREEN_PARENT/store-green-recovery-2-summary.json"
RR_TASK2B_RECOVERY2_GREEN_TESTS="$RR_TASK2B_RECOVERY2_GREEN_PARENT/store-green-recovery-2-tests.json"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'

test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "6be00b5661c48121b4fa054507b15b627fda1c9f"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --cached --name-only)" = ""
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"

for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_RECOVERY2_GREEN_DERIVED" \
  "$RR_TASK2B_RECOVERY2_GREEN_RESULT" \
  "$RR_TASK2B_RECOVERY2_GREEN_LOG" \
  "$RR_TASK2B_RECOVERY2_GREEN_SUMMARY" \
  "$RR_TASK2B_RECOVERY2_GREEN_TESTS"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_RECOVERY2_GREEN_DERIVED" \
  -resultBundlePath "$RR_TASK2B_RECOVERY2_GREEN_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests >"$RR_TASK2B_RECOVERY2_GREEN_LOG" 2>&1
RR_TASK2B_RECOVERY2_GREEN_STATUS=$?
set -e

test -f "$RR_TASK2B_RECOVERY2_GREEN_LOG"
test ! -L "$RR_TASK2B_RECOVERY2_GREEN_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY2_GREEN_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY2_GREEN_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY2_GREEN_LOG")")" = "$(realpath "$RR_TASK2B_RECOVERY2_GREEN_PARENT")"
RR_TASK2B_RECOVERY2_GREEN_LOG_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" "$RR_TASK2B_RECOVERY2_GREEN_LOG" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY2_GREEN_LOG_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY2_GREEN_LOG_SCAN_STATUS" = "1"
test "$RR_TASK2B_RECOVERY2_GREEN_STATUS" = "0"

test -d "$RR_TASK2B_RECOVERY2_GREEN_RESULT"
test ! -L "$RR_TASK2B_RECOVERY2_GREEN_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY2_GREEN_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY2_GREEN_RESULT")")" = "$(realpath "$RR_TASK2B_RECOVERY2_GREEN_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary --path "$RR_TASK2B_RECOVERY2_GREEN_RESULT" --compact >"$RR_TASK2B_RECOVERY2_GREEN_SUMMARY"
  xcrun xcresulttool get test-results tests --path "$RR_TASK2B_RECOVERY2_GREEN_RESULT" --compact >"$RR_TASK2B_RECOVERY2_GREEN_TESTS"
)

for RR_TASK2B_RESULT_FILE in \
  "$RR_TASK2B_RECOVERY2_GREEN_LOG" \
  "$RR_TASK2B_RECOVERY2_GREEN_SUMMARY" \
  "$RR_TASK2B_RECOVERY2_GREEN_TESTS"; do
  test -f "$RR_TASK2B_RESULT_FILE"
  test ! -L "$RR_TASK2B_RESULT_FILE"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RESULT_FILE")" = "Regular File"
  test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RESULT_FILE")" = "600"
  test "$(dirname "$(realpath "$RR_TASK2B_RESULT_FILE")")" = "$(realpath "$RR_TASK2B_RECOVERY2_GREEN_PARENT")"
done

RR_TASK2B_RECOVERY2_GREEN_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_RECOVERY2_GREEN_LOG" \
  "$RR_TASK2B_RECOVERY2_GREEN_SUMMARY" \
  "$RR_TASK2B_RECOVERY2_GREEN_TESTS" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY2_GREEN_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY2_GREEN_SCAN_STATUS" = "1"

python3 - "$RR_TASK2B_RECOVERY2_GREEN_SUMMARY" "$RR_TASK2B_RECOVERY2_GREEN_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected = {
    "result": "Passed",
    "totalTestCount": 43,
    "passedTests": 43,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected summary field {key}: {summary.get(key)!r}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be empty")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 43 or len({identifier for identifier, _ in cases}) != 43:
    raise SystemExit("expected exactly 43 unique Store test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every Store test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
if len(store) != 43 or len(store) != len(cases):
    raise SystemExit("unexpected suite in Store-only result")
PYTHON
```

Expected: exact `43/43` Store success, zero failed/skipped/expected tests,
zero failure records, `43` unique Store identifiers, required mode and
containment checks, and both privacy scan statuses exactly `1`. The parent,
log, xcresult, summary, and tests remain temporary retained evidence.

### Second-recovery selected regression fence

Run exactly once if and only if the second-successor Store GREEN fence passes
completely. Use a new parent distinct from every RED, GREEN, and recovery
parent. This is the first authorized Task 2B regression execution.

```bash
set -euo pipefail
umask 077
RR_TASK2B_RECOVERY2_REGRESSION_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2b-regression-recovery-2.XXXXXX)"
chmod 700 "$RR_TASK2B_RECOVERY2_REGRESSION_PARENT"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY2_REGRESSION_PARENT")" = "700"
RR_TASK2B_RECOVERY2_REGRESSION_DERIVED="$RR_TASK2B_RECOVERY2_REGRESSION_PARENT/DerivedData"
RR_TASK2B_RECOVERY2_REGRESSION_RESULT="$RR_TASK2B_RECOVERY2_REGRESSION_PARENT/regression-recovery-2.xcresult"
RR_TASK2B_RECOVERY2_REGRESSION_LOG="$RR_TASK2B_RECOVERY2_REGRESSION_PARENT/regression-recovery-2.log"
RR_TASK2B_RECOVERY2_REGRESSION_SUMMARY="$RR_TASK2B_RECOVERY2_REGRESSION_PARENT/regression-recovery-2-summary.json"
RR_TASK2B_RECOVERY2_REGRESSION_TESTS="$RR_TASK2B_RECOVERY2_REGRESSION_PARENT/regression-recovery-2-tests.json"
RR_TASK2B_SECRET_MARKER='(BEGIN[[:space:]]+(RSA |EC |OPENSSH |DSA |PRIVATE )?PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]+|gh[pousr]_[0-9A-Za-z_]{36,}|sk-[A-Za-z0-9_-]{20,})'

test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "6be00b5661c48121b4fa054507b15b627fda1c9f"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --cached --name-only)" = ""

for RR_TASK2B_ABSENT in \
  "$RR_TASK2B_RECOVERY2_REGRESSION_DERIVED" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_LOG" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_SUMMARY" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_TESTS"; do
  test ! -e "$RR_TASK2B_ABSENT"
  test ! -L "$RR_TASK2B_ABSENT"
done

set +e
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2B_RECOVERY2_REGRESSION_DERIVED" \
  -resultBundlePath "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT" \
  -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests >"$RR_TASK2B_RECOVERY2_REGRESSION_LOG" 2>&1
RR_TASK2B_RECOVERY2_REGRESSION_STATUS=$?
set -e

test -f "$RR_TASK2B_RECOVERY2_REGRESSION_LOG"
test ! -L "$RR_TASK2B_RECOVERY2_REGRESSION_LOG"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY2_REGRESSION_LOG")" = "Regular File"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RECOVERY2_REGRESSION_LOG")" = "600"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY2_REGRESSION_LOG")")" = "$(realpath "$RR_TASK2B_RECOVERY2_REGRESSION_PARENT")"
RR_TASK2B_RECOVERY2_REGRESSION_LOG_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" "$RR_TASK2B_RECOVERY2_REGRESSION_LOG" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY2_REGRESSION_LOG_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY2_REGRESSION_LOG_SCAN_STATUS" = "1"
test "$RR_TASK2B_RECOVERY2_REGRESSION_STATUS" = "0"

test -d "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT"
test ! -L "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT")")" = "$(realpath "$RR_TASK2B_RECOVERY2_REGRESSION_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary --path "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT" --compact >"$RR_TASK2B_RECOVERY2_REGRESSION_SUMMARY"
  xcrun xcresulttool get test-results tests --path "$RR_TASK2B_RECOVERY2_REGRESSION_RESULT" --compact >"$RR_TASK2B_RECOVERY2_REGRESSION_TESTS"
)

for RR_TASK2B_RESULT_FILE in \
  "$RR_TASK2B_RECOVERY2_REGRESSION_LOG" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_SUMMARY" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_TESTS"; do
  test -f "$RR_TASK2B_RESULT_FILE"
  test ! -L "$RR_TASK2B_RESULT_FILE"
  test "$(/usr/bin/stat -f '%HT' "$RR_TASK2B_RESULT_FILE")" = "Regular File"
  test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2B_RESULT_FILE")" = "600"
  test "$(dirname "$(realpath "$RR_TASK2B_RESULT_FILE")")" = "$(realpath "$RR_TASK2B_RECOVERY2_REGRESSION_PARENT")"
done

RR_TASK2B_RECOVERY2_REGRESSION_SCAN_STATUS=0
rg --quiet --pcre2 "$RR_TASK2B_SECRET_MARKER" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_LOG" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_SUMMARY" \
  "$RR_TASK2B_RECOVERY2_REGRESSION_TESTS" >/dev/null 2>&1 || \
  RR_TASK2B_RECOVERY2_REGRESSION_SCAN_STATUS=$?
test "$RR_TASK2B_RECOVERY2_REGRESSION_SCAN_STATUS" = "1"

python3 - "$RR_TASK2B_RECOVERY2_REGRESSION_SUMMARY" "$RR_TASK2B_RECOVERY2_REGRESSION_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected = {
    "result": "Passed",
    "totalTestCount": 64,
    "passedTests": 64,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected summary field {key}: {summary.get(key)!r}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be empty")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 64 or len({identifier for identifier, _ in cases}) != 64:
    raise SystemExit("expected exactly 64 unique selected test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every selected test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
plugin = [identifier for identifier, _ in cases if identifier.startswith("CodexPluginLifecycleAcceptanceTests/")]
if len(store) != 43 or len(plugin) != 21 or len(store) + len(plugin) != len(cases):
    raise SystemExit("unexpected selected suite split")
PYTHON
```

Expected: exact `64/64` selected success with `43` Store and `21`
plugin-lifecycle cases, zero failed/skipped/expected tests, zero failure
records, `64` unique selected identifiers, required mode and containment
checks, and both privacy scan statuses exactly `1`.

### Pre-resumption independent reviews

Before implementation, fresh independent agents must review the exact final
brief and registry bytes and return:

- Architecture: GO, Required `0`;
- QA/Test: GO, Required `0`;
- Security/Privacy: GO, Required `0`;
- TPM: GO, Required `0`;
- Delivery Management: GO, Required `0`.

Delivery Management must additionally review the actual
`docs/delivery/progress.md` second-recovery evidence, distinct hash literals,
review dispositions, exact checkpoint inventory, retained implementation
hashes, and Task 3 closure before staging. A reviewer may not approve its own
implementation. Any Required finding keeps direct continuation NO-GO.

### Non-circular progress bindings

After all five exact-hash artifact reviews and before staging, Delivery
Management must add exactly one ledger line matching each regex:

```text
^- RR-R10 Task 2B second-recovery final reviewed brief SHA-256: `([0-9a-f]{64})`$
^- RR-R10 Task 2B second-recovery final reviewed registry SHA-256: `([0-9a-f]{64})`$
```

These distinct fields do not replace or duplicate the accepted first-recovery
fields. Their values bind the actual final second-recovery worktree bytes of
this brief and `docs/delivery/task-briefs/SHA256SUMS`. This brief deliberately
does not contain its own final digest as a literal.

### Second-recovery precommit gate

Run exactly once after the coordinator ledger update and Delivery Management's
review of the actual ledger, before staging:

```bash
set -euo pipefail
RR_TASK2B_RECOVERY2_BASE=22178e5cea42a3a3006a8800309d5a76f6610596
RR_TASK2B_BRANCH=codex/release-radar-mvp
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md

test "$(git branch --show-current)" = "$RR_TASK2B_BRANCH"
test "$(git rev-parse HEAD)" = "$RR_TASK2B_RECOVERY2_BASE"
test "$(git rev-parse '@{u}')" = "$RR_TASK2B_RECOVERY2_BASE"
test "$(git ls-remote origin refs/heads/codex/release-radar-mvp | awk '{print $1}')" = "$RR_TASK2B_RECOVERY2_BASE"
test "$(git rev-list --left-right --count HEAD...'@{u}' | tr '\t' ' ')" = "0 0"
test "$(git diff --cached --name-only)" = ""

RR_TASK2B_RECOVERY2_LEDGER_SHAS="$(python3 - "$RR_TASK2B_LEDGER" <<'PYTHON'
import re
import sys

ledger = open(sys.argv[1], encoding="utf-8").read()
patterns = {
    "brief": r"^- RR-R10 Task 2B second-recovery final reviewed brief SHA-256: `([0-9a-f]{64})`$",
    "registry": r"^- RR-R10 Task 2B second-recovery final reviewed registry SHA-256: `([0-9a-f]{64})`$",
}
values = []
for name, pattern in patterns.items():
    matches = re.findall(pattern, ledger, flags=re.MULTILINE)
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one second-recovery {name} SHA field, found {len(matches)}")
    values.append(matches[0])
print(" ".join(values))
PYTHON
)"
RR_TASK2B_RECOVERY2_LEDGER_BRIEF_SHA="${RR_TASK2B_RECOVERY2_LEDGER_SHAS%% *}"
RR_TASK2B_RECOVERY2_LEDGER_REGISTRY_SHA="${RR_TASK2B_RECOVERY2_LEDGER_SHAS##* }"
test "$RR_TASK2B_RECOVERY2_LEDGER_BRIEF_SHA" = "$(shasum -a 256 "$RR_TASK2B_BRIEF" | awk '{print $1}')"
test "$RR_TASK2B_RECOVERY2_LEDGER_REGISTRY_SHA" = "$(shasum -a 256 "$RR_TASK2B_REGISTRY" | awk '{print $1}')"

python3 - "$RR_TASK2B_REGISTRY" "$RR_TASK2B_BRIEF" <<'PYTHON'
import hashlib
import re
import sys
from pathlib import Path

registry_path, brief_path = sys.argv[1:3]
task2b_count = 0
for line_number, line in enumerate(Path(registry_path).read_text(encoding="utf-8").splitlines(), start=1):
    if not line:
        continue
    parts = line.split("  ", 1)
    if len(parts) != 2:
        raise SystemExit(f"registry line {line_number} is not two-space separated")
    digest, path = parts
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise SystemExit(f"registry line {line_number} has invalid digest")
    actual = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    if actual != digest:
        raise SystemExit(f"registry mismatch for {path}")
    if path == brief_path:
        task2b_count += 1
if task2b_count != 1:
    raise SystemExit(f"expected exactly one Task 2B registry entry, found {task2b_count}")
PYTHON

test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "4d7ac34c31e19c16c46b6bae3d1cf3aec1f294e3"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift docs/delivery/progress.md docs/delivery/task-briefs/SHA256SUMS docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite | awk '{print $1}')" = "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS | awk '{print $1}')" = "ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3"
git diff --check -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
```

Any failure stops before staging or retry. The planning checkpoint may stage
exactly this brief, the root registry, and `docs/delivery/progress.md`. The
five implementation paths remain unstaged at the pre-edit inventory.

### Second-recovery staged-checkpoint gate

After staging exactly the three planning documents, run exactly once before
commit:

```bash
set -euo pipefail
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md

test "$(git diff --cached --name-only | LC_ALL=C sort)" = "$(printf '%s\n' "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" | LC_ALL=C sort)"
git diff --exit-code -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
git diff --cached --check

RR_TASK2B_RECOVERY2_STAGED_SHAS="$(python3 - "$RR_TASK2B_LEDGER" <<'PYTHON'
import re
import subprocess
import sys

ledger = subprocess.check_output(["git", "show", f":{sys.argv[1]}"], text=True)
patterns = [
    r"^- RR-R10 Task 2B second-recovery final reviewed brief SHA-256: `([0-9a-f]{64})`$",
    r"^- RR-R10 Task 2B second-recovery final reviewed registry SHA-256: `([0-9a-f]{64})`$",
]
values = []
for pattern in patterns:
    matches = re.findall(pattern, ledger, flags=re.MULTILINE)
    if len(matches) != 1:
        raise SystemExit("staged second-recovery ledger binding is not unique")
    values.append(matches[0])
print(" ".join(values))
PYTHON
)"
test "${RR_TASK2B_RECOVERY2_STAGED_SHAS%% *}" = "$(git show ":$RR_TASK2B_BRIEF" | shasum -a 256 | awk '{print $1}')"
test "${RR_TASK2B_RECOVERY2_STAGED_SHAS##* }" = "$(git show ":$RR_TASK2B_REGISTRY" | shasum -a 256 | awk '{print $1}')"

test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "4d7ac34c31e19c16c46b6bae3d1cf3aec1f294e3"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
```

Commit exactly the three staged planning documents as a direct child of
`22178e5cea42a3a3006a8800309d5a76f6610596`, then push to
`origin/codex/release-radar-mvp`. Do not stage or commit implementation paths.

### Second-recovery committed post-push gate

Run exactly once after push and before releasing the implementation writer:

```bash
set -euo pipefail
RR_TASK2B_RECOVERY2_BASE=22178e5cea42a3a3006a8800309d5a76f6610596
RR_TASK2B_BRANCH=codex/release-radar-mvp
RR_TASK2B_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md
RR_TASK2B_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2B_LEDGER=docs/delivery/progress.md

test "$(git branch --show-current)" = "$RR_TASK2B_BRANCH"
test "$(git rev-parse HEAD^)" = "$RR_TASK2B_RECOVERY2_BASE"
test "$(git diff-tree --no-commit-id --name-only -r HEAD | LC_ALL=C sort)" = "$(printf '%s\n' "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" | LC_ALL=C sort)"
test "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')"
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/codex/release-radar-mvp | awk '{print $1}')"
test "$(git rev-list --left-right --count HEAD...'@{u}' | tr '\t' ' ')" = "0 0"

python3 - "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER" <<'PYTHON'
import hashlib
import re
import subprocess
import sys

brief_path, registry_path, ledger_path = sys.argv[1:4]

def committed_bytes(path):
    return subprocess.check_output(["git", "show", f"HEAD:{path}"])

def committed_text(path):
    return committed_bytes(path).decode("utf-8")

ledger = committed_text(ledger_path)
patterns = {
    "brief": r"^- RR-R10 Task 2B second-recovery final reviewed brief SHA-256: `([0-9a-f]{64})`$",
    "registry": r"^- RR-R10 Task 2B second-recovery final reviewed registry SHA-256: `([0-9a-f]{64})`$",
}
values = {}
for name, pattern in patterns.items():
    matches = re.findall(pattern, ledger, flags=re.MULTILINE)
    if len(matches) != 1:
        raise SystemExit(f"expected one committed second-recovery {name} binding, found {len(matches)}")
    values[name] = matches[0]
if hashlib.sha256(committed_bytes(brief_path)).hexdigest() != values["brief"]:
    raise SystemExit("committed brief does not match second-recovery ledger binding")
if hashlib.sha256(committed_bytes(registry_path)).hexdigest() != values["registry"]:
    raise SystemExit("committed registry does not match second-recovery ledger binding")

task2b_count = 0
for line_number, line in enumerate(committed_text(registry_path).splitlines(), start=1):
    if not line:
        continue
    parts = line.split("  ", 1)
    if len(parts) != 2:
        raise SystemExit(f"registry line {line_number} is not two-space separated")
    digest, path = parts
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise SystemExit(f"registry line {line_number} has invalid digest")
    if hashlib.sha256(committed_bytes(path)).hexdigest() != digest:
        raise SystemExit(f"committed registry mismatch for {path}")
    if path == brief_path:
        task2b_count += 1
if task2b_count != 1:
    raise SystemExit(f"expected exactly one committed Task 2B registry entry, found {task2b_count}")
PYTHON

git diff --exit-code -- "$RR_TASK2B_BRIEF" "$RR_TASK2B_REGISTRY" "$RR_TASK2B_LEDGER"
test "$(git diff --cached --name-only)" = ""
test "$(git hash-object ReleaseRadarCore/Models/TicketTaskModels.swift)" = "49f365dd1e074d4d2b716384756e71a3c5fb1ce1"
test "$(git hash-object ReleaseRadarCore/Store/DeliveryStore.swift)" = "d930ab18794a959b44cad4293cee24647a1af8f6"
test "$(git hash-object ReleaseRadarCore/Store/StoreMigrations.swift)" = "6fad7835211cace656e854aa0249f8775280a6dd"
test "$(git hash-object ReleaseRadarTests/StoreAcceptanceTests.swift)" = "4d7ac34c31e19c16c46b6bae3d1cf3aec1f294e3"
test "$(git hash-object ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "d5d2bd7411bf7b10892b93ee57f62cc76c47492a"
test "$(git diff --name-only -- | LC_ALL=C sort)" = "$(printf '%s\n' ReleaseRadarCore/Store/DeliveryStore.swift ReleaseRadarCore/Store/StoreMigrations.swift ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift ReleaseRadarTests/StoreAcceptanceTests.swift | LC_ALL=C sort)"
test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = "ReleaseRadarCore/Models/TicketTaskModels.swift"
```

Only after this post-push gate passes may the fresh writer perform the exact
one-line edit and run the newly authorized second-successor fence.

### Activity, audit evidence, and retained temporary evidence

This recovery creates no production activity or audit event. The durable
ledger may record only sanitized scalar command identity, paths, modes, sizes,
hashes, result status, suite counts, failure counts, exact failed identifier,
root-cause classification, privacy scan statuses, and independent review
dispositions.

Retain without mutation, staging, or deletion:

- `/tmp/release-radar-rr-r10-task2b-red.ZvNHEi`;
- `/tmp/release-radar-rr-r10-task2b-green.YczYQm`;
- `/tmp/release-radar-rr-r10-task2b-green-recovery.uYnBjE`;
- the future second-successor GREEN parent, whether the fence passes or fails;
- the future regression parent, if regression becomes eligible and runs.

No cleanup is authorized without explicit owner approval. Scratch evidence is
not a durable deliverable and must never be staged.

### Postimplementation reviews and checkpoint

Only after both newly authorized fences pass may the coordinator run
`git diff --check` once and the accepted fixture checksum/diff checks. Then
obtain fresh independent:

- Code Review: GO, Required `0`;
- QA/Test: GO, Required `0`;
- Architecture: GO, Required `0`;
- Security/Privacy: GO, Required `0`;
- TPM: GO, Required `0`;
- Delivery Management: GO, Required `0`.

The writer may not review its own implementation. Required findings block the
checkpoint. Optional and out-of-scope observations do not silently expand the
task.

The postimplementation checkpoint may stage exactly:

- `ReleaseRadarCore/Models/TicketTaskModels.swift`;
- `ReleaseRadarCore/Store/DeliveryStore.swift`;
- `ReleaseRadarCore/Store/StoreMigrations.swift`;
- `ReleaseRadarTests/StoreAcceptanceTests.swift`;
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`;
- coordinator-owned `docs/delivery/progress.md`.

It must require the four unchanged implementation blobs and the exact
post-edit Store test blob `6be00b5661c48121b4fa054507b15b627fda1c9f`.
It must not stage this brief or registry again unless another reviewed
planning correction changes them. It must not stage fixtures, raw evidence,
scripts, project files, generated files, owner data, Release Radar state, or
external artifacts.

### Completion evidence expected in the progress ledger

The coordinator ledger must record, using sanitized scalar facts only:

- second-recovery artifact reviewer dispositions and the two distinct exact
  hash bindings;
- planning precommit, staged-checkpoint, commit inventory, post-push remote
  equality, and retained-blob gate outcomes;
- exact one-line implementation scope and post-edit Store test blob;
- second-successor evidence parent, file modes, log size/hash, structured
  `43/43` counts, suite uniqueness, failure-record count, and privacy scan
  statuses;
- if eligible, regression evidence parent, file modes, log size/hash,
  structured `64/64` counts, exact `43/21` split, failure-record count, and
  privacy scan statuses;
- fixture checksum/diff-check outcomes;
- all six postimplementation review dispositions;
- implementation checkpoint inventory and exact local/upstream/live-remote
  equality;
- open blockers, evidence-retention status, and Task 3 gate state.

### Second-recovery acceptance criteria

- The canonical brief contains this complete second-recovery authority and the
  root registry contains exactly one matching Task 2B entry.
- Architecture, QA/Test, Security/Privacy, TPM, and Delivery Management review
  the exact brief and registry bytes and return GO/Required `0`.
- Delivery Management reviews the actual ledger before staging.
- The ledger contains exactly one distinct second-recovery brief binding and
  one distinct second-recovery registry binding; both match worktree, staged,
  and committed bytes at their applicable gates.
- The planning checkpoint is a direct child of
  `22178e5cea42a3a3006a8800309d5a76f6610596`, contains exactly brief,
  registry, and progress, and reaches exact local/upstream/live-remote equality
  with ahead/behind `0/0` before implementation resumes.
- The pre-edit five blobs match the retained inventory.
- One fresh writer changes only
  `ReleaseRadarTests/StoreAcceptanceTests.swift`, exactly replacing `LIMIT 3`
  with `LIMIT 2` in the active-order query while keeping
  `"task-3,task-1"` unchanged.
- The post-edit Store test blob is exactly
  `6be00b5661c48121b4fa054507b15b627fda1c9f`; the other four blobs remain
  exact.
- No RED, original GREEN, or first-successor GREEN-recovery fence reruns.
- The newly authorized second-successor fence runs once from a fresh unique
  mode-`700` parent and passes exact structured `43/43` with no failures,
  skips, expected failures, failure records, privacy matches, or unexpected
  suite.
- Regression runs once only after complete Store success, from a different
  fresh mode-`700` parent, and passes exact structured `64/64` with `43/21`
  suite split and no failures, skips, expected failures, failure records,
  privacy matches, or unexpected suite.
- Any fence or parser failure stops with no retry and retains all evidence.
- Fixture bytes and manifests remain exact; no product, fixture, project,
  signing, sandbox, owner, Release Radar, live-plan, Task 3, or external state
  changes.
- Independent Code Review, QA/Test, Architecture, Security/Privacy, TPM, and
  Delivery Management return GO/Required `0` before the bounded
  implementation checkpoint.
- Required `1`, Optional `0`, Out-of-scope `0` at planning diagnosis is closed
  only by the exact edit plus passing newly authorized evidence; until then,
  direct continuation remains NO-GO.
