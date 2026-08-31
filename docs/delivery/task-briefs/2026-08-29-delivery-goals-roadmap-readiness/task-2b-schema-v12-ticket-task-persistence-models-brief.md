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
