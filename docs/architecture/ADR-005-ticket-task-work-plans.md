# ADR-005: Ticket task work plans

- Status: owner-approved direction; exact planning package pending owner acceptance
- Date: 2026-08-30

## Context

ADR-004 gives Release Radar app-owned phase outcomes and structural readiness,
but a ticket remains one undifferentiated outcome. RR-R10 now has accepted
storage checkpoints and a larger pending implementation sequence, yet Release
Radar cannot represent those required per-ticket units without treating a
Markdown plan or external agent state as authority. It also cannot prove at
acceptance time that every current unit of planned work is complete.

Dependencies and blockers do not solve this problem: they describe ordering
and impediments between delivery records, not the complete internal work plan
for one ticket. Observed Codex goals, Git, tests, and repository plans remain
external evidence and cannot own formal delivery state under ADR-001 and
ADR-004.

## Decision

Release Radar will add optional, app-owned, per-ticket task work plans in
additive store schema version 12.

- A ticket has zero or one task plan. Zero is valid for an atomic ticket.
- A plan has its own monotonic optimistic revision and one or more active tasks.
  Creation commits and returns revision 1; revision 0 is never visible.
- Each task has a stable machine ID, stable visible label, verb-led title,
  deterministic order, pending/completed state, and independent active/
  superseded lifecycle.
- Core and MCP enforce encoded UTF-8 maxima of 256 bytes for the task machine
  ID, 256 bytes for the visible label, and 4,096 bytes for the title, without
  truncation or character-count substitution.
- Task and plan rows are never hard-deleted. Machine IDs and visible labels are
  never reused within a ticket. Completed work never returns to pending;
  discovered or rework scope is a new pending task.
- Superseded tasks remain history but are excluded from the active list, card
  count, and acceptance gate. The last active task may be superseded only with
  an atomic active replacement.
- Task definitions, completion, and supersession change only through bounded,
  typed, audited, idempotent, revision-checked store transactions.
- Every task addition is born Active and Pending. Completed state is reachable
  only through a separate exact-revision completion request.
- A ticket with a plan can enter Accepted only through a revision-bearing
  transition that observes that exact plan revision and verifies every active
  task completed in the same transaction.
- `AgentCommand.upsertTicket` cannot create or update a ticket directly into
  Accepted, regardless of whether a task plan exists. It carries no task-plan
  revision; every Accepted request uses the existing transition path.
- Completing every task never changes the ticket lane, requests review, or
  accepts the ticket automatically.
- Accepted tickets and their task plans are immutable except for exact replay.
- Task-only mutations do not invalidate phase-plan readiness. Existing ticket
  outcome/phase and Delivery Goal structural mutations keep ADR-004 behavior.
- Ticket cards derive a neutral active-task count from the same canonical rows
  as the read-only Ticket Details `Tasks` list. No count is persisted.
- Schema-v12 migration creates no task plans. The accepted schema-v11
  definition and fixture remain immutable.
- The current production artifact boundary is import-only, and import creates
  no task plan. RR-R10 adds no exporter, exportability predicate, guard, archive
  error, or archive v2. Future RM5 owns exporter/archive-format work and must
  represent task plans or fail before emission. RM6 import accepts only
  complete supported exporter output or rejects it; silent omission and an
  RR-R10 archive-v2 shortcut are forbidden.
- Task 4A routes every existing Accepted entry point through the exact-revision
  gate and closes Accepted `upsertTicket` create/update requests while exposing
  no new task-plan mutation command or MCP tool. Task 4B may then add the two
  task mutation commands, but only for isolated tests/development until Tasks
  5, 6, and 7 each reach their remote-exact gates. Task 7A is the first owner-
  install authorization. No feature flag is added.
- Owner-only Delivery Goal replay reauthorizes the trusted
  `AgentCommandOrigin` before returning a durable result. It preserves existing
  canonical receipt bytes and validates same origin through the stored
  authoritative audit actor/result association: the stored result's audit ID
  resolves its persisted actor, which must match the newly supplied trusted
  origin. A missing/mismatched association or cross-origin request-ID reuse
  rejects without replay or mutation.
- The RR-R10 catalog is installed through explicit typed requests. Runtime code
  never parses planning documents, Git, tests, or Codex state to create or
  complete tasks.
- Task 7A creates all 16 rows Active/Pending in one revision, then chains one
  retained exact-revision completion request per accepted remote-exact
  checkpoint through Task 7. Exact replay returns the original audits/
  revisions; stale, out-of-order, or changed-body requests fail without side
  effects. Task 7A completes only after its own remote-exact gate.
- Because the feature does not exist earlier, those rows first become app-owned
  state during Task 7A. The pre-bootstrap repository catalog is owner-approved
  direction whose exact package still requires owner acceptance, not inferred
  or live tracking. After bootstrap, catalog changes use the exact live plan
  revision and every later task completes its own row after its remote gate.
- After each live completion of Task 7A, 8, 9, 10, or 11A, the coordinator
  durably records the exact returned task-plan revision and audit ID in the
  delivery ledger, commits/pushes that ledger record, and verifies remote
  equality no later than the next task's brief/release checkpoint. The next
  task cannot open first. Task 11B is recorded by terminal reconciliation;
  repair rows are reconciled before their parent resumes. This adds no row or
  completion framework.
- The exact planning package does not release implementation by itself. Owner
  acceptance, coordinator ledger recording, planning/ledger commit and push,
  remote equality with ahead/behind 0/0, authorized typed/UI state readback,
  and exact installed app/helper/running-process identity must prove the
  ledger-backed known schema-v10 build and RR-R10 Blocked state before any
  blocker/lane mutation. The exact identity is enumerated in the design and
  binds schema-v10 migration eligibility without direct SQLite inspection.
  Failure to prove identity/schema/state stops before mutation and Task 2A for
  a bounded architecture-reviewed, owner-accepted reconciliation checkpoint.
  Only then may audited blocker resolution, RR-R10 Blocked→In progress
  readback, and a fresh independently released Task 2A brief precede RED.
- The handoff intentionally makes RR-R10 In progress before Task 2A. Task 7A
  re-verifies that v11 migration-only legacy continuation and v12 preservation
  retain that pre-policy state; eligibility was already proven before the
  early mutation and cannot be deferred to Task 7A. An unexpected migration
  result still aborts/restores through the approved runbook.
- Delivery-plan finalization has one narrow adoption rule: when finalizing a
  plan to Ready, a migration-continuation In-progress or Needs-review ticket
  explicitly assigned to exactly one Draft goal atomically promotes that goal
  to Active, sets its activation timestamp, and clears the continuation. It
  never infers or retroactively creates an assignment and does not authorize a
  general freestanding Planned→Active transition.

The complete product, UI, data, mutation, bootstrap, error, and acceptance
contract is
`docs/design/release-radar-ticket-tasks-design.md`.

## Persistence boundary

Schema v12 adds `ticket_task_plans` and `ticket_tasks` with composite project/
ticket ownership, database constraints for valid states and timestamps,
immutable-ID/label and no-delete triggers, and manifest validation. Composite
foreign keys plus explicit parent-delete triggers reject deletion of a ticket
or project that owns task-plan history; no cascade may erase plan/task rows.
Core validation applies the exact UTF-8 byte maxima before persistence. The app
process remains the only SQLite writer. Bridge and owner surfaces call the same
store-owned policy and receive committed task-plan revisions.

The policy validates the final transaction state so a bounded revision may
replace a last active task atomically but can never expose or commit an empty
plan. Durable command receipts own replay. The authoritative audit and request
receipt commit or roll back with task rows and any Accepted lane transition.
Every Accepted entry point uses the same policy. No-plan acceptance carries no
task revision; planned-ticket acceptance carries the exact revision. Existing
store transaction serialization gives one coherent winner when acceptance
races first-plan creation, revision, supersession, or completion, and the loser
rolls back without orphan rows or delivery side effects.

`AgentCommand.upsertTicket` is not an acceptance entry point. Supplying
Accepted for either create or update rejects before mutation, with no task
revision field and no side effects. Both planned and no-plan tickets use the
existing transition command for Accepted.

## Projection boundary

The dashboard projects each ticket as exactly `noPlan`, `loaded(plan)`, or
`unavailable(recovery)`. Only `loaded` supplies active task rows. That one
loaded projection supplies both:

- the neutral active count on the ticket card; and
- the read-only checkbox-shaped rows in Ticket Details.

Completion changes the row indicator only. Additions and supersessions change
both list membership and count. No aggregate completion, percentage, progress
bar, persisted level of effort, or task action is added to the Phase Board.
A task-row query failure produces `unavailable(recovery)` with no stale rows or
count while the rest of the successfully loaded board remains usable.

## Portable-boundary correction

Source validation found no production portable exporter or exportability call
path; `DeliveryArtifactImporter` is import-only. This ADR therefore supersedes
only its own earlier Ticket Tasks archive assumption. It does not claim current
export safety and does not implement the older ADR-004 Delivery Goals archive
helper unless and until separately approved work introduces a real exporter
boundary. No unused predicate, helper, error, framework, or archive v2 is part
of RR-R10.

RM5, if separately approved, owns both portable export and its archive format;
it must serialize task plans completely or stop before emission. RM6 may import
only complete supported RM5 output and otherwise rejects it. This split does
not authorize either capability in RR-R10.

## Owner-install boundary

Task 7A's first install/bootstrap and Task 11B's final install/repair share one
written security/recovery contract. Before any owner install, the Task 7A brief
defines an exact bounded repository-owned backup/restore runbook using existing
repository facilities and receives independent Architecture, Security/Privacy,
QA, TPM, and Delivery approval. It is not a generalized backup framework or
product feature; Task 11B reuses the same approved runbook. Before either
install, typed/UI snapshot covers
the active phase; relevant ticket lanes, outcomes, dependencies, and blockers;
observed goals/links; notifications; and current task-plan/Delivery Goal state
when applicable. The runbook proves app/helper quiescence and process state,
captures SQLite main/WAL/SHM as one consistent set, records backup identity,
verifies a disposable-copy restore, and retains the backup through post-install
acceptance. Exact application/helper/signing/running-process hashes are also
verified first.

Every mutation is retained in an ordered manifest with authorized repository
root, trusted origin, attribution, reason, UUID, full command body, and order.
Snapshot, preflight, hash, signing, or process mismatch stops. Migration
failure, corruption, unexpected state, or an unprovable continuation invariant
executes the runbook's exact abort, quiescence, restore, relaunch, and typed/UI
readback sequence. Post-install verification uses typed/UI readback, never
direct SQLite. Uncertain outcomes recover only by exact original-request
replay.

An installed-only repair task remains Pending through implementation/testing,
corrected-candidate staging, the same snapshot/backup/hash/install contract,
typed/UI proof that the defect is fixed and owner state is preserved,
independent review, commit/push, and remote equality. Only then may its row be
completed/read back and durably reconciled before the interrupted Task 7A or
Task 11B resumes. The Task 7A pre-plan abort/reconciliation branch remains
separate because no live row exists yet.

## Consequences

- Release Radar can represent a ticket's complete work plan without granting
  authority to repository or runtime observations.
- Acceptance has a transactional, revision-specific completeness gate.
- Historical completed or superseded work remains durable and cannot be erased
  to improve a denominator.
- Atomic tickets remain lightweight and need no artificial one-item plan.
- Phase-plan readiness remains structurally meaningful and is not churned by
  ticket execution details.
- Current import remains task-plan-free; export behavior is unchanged because
  no production exporter exists. Future RM5 owns complete representation-or-
  fail-before-emission export behavior, and RM6 accepts only its complete
  supported output or rejects it.
- RR-R10 gains more owner-visible tasks than its prior unopened sequence; that
  count reflects independently reviewable work rather than a fixed target.
- RR-R10 begins with 16 persisted tasks; later reviewed corrections may add
  rows, so 16 is not a permanent denominator target. Accepted-path protection and
  external task-command exposure are separate Task 4A and Task 4B remote-exact
  checkpoints; Task 4A exposes no new task-plan mutation command or MCP tool.
  Task 7A installs the through-Task-7 candidate, creates the live plan, completes
  accepted checkpoints through Task 7, then completes its own row after its
  remote-exact gate. Tasks 8–11B each complete their row after their own remote-
  exact gate, with durable reconciliation before the next task opens. Task 11B
  preserves all 16 initial rows plus every reviewed later row and ends at
  dynamic card signal `☷ N` with installed typed/UI proof that all N active rows
  are checked; terminal reconciliation records its final row. No completed/
  total fraction is ever rendered or announced in the UI or accessibility.
- Task 11B explicitly assigns migration-continuation RR-R10 to Draft
  RR-DG-R10 and finalizes the Ready plan, atomically adopting the ticket by
  moving that goal to Active, setting activation time, and clearing the
  continuation; roadmap goals remain Planned. Completing all rows does not
  move RR-R10. The distinct closing sequence starts from In progress/Active,
  records completion/review evidence, and performs In progress→Needs review.
  Explicit owner acceptance
  then authorizes exact-task-revision Needs review→Accepted, followed by
  RR-DG-R10 Active→Awaiting acceptance and owner-app Awaiting→Accepted. Direct
  invalid acceptance rejects; exact replay creates no duplicate effects; and
  the task-plan revision remains unchanged across every ticket/goal transition.
  This lifecycle work is a distinct post-task governed closure and performs no
  product implementation. If implementation is discovered before acceptance,
  closure stops, a new Active/Pending task is added through the typed plan
  revision, and its full bounded gate completes before closure resumes. Later
  repository terminal reconciliation is separate, is not a task row, and
  cannot mutate the Accepted plan.

## Rejected alternatives

- Parsing the implementation plan or task briefs into runtime state.
- Inferring completion from commits, tests, evidence, Codex goals, or lane
  movement.
- Persisting only a card count or completed/total aggregate.
- Reusing dependencies, blockers, Delivery Goal criteria, or review items as
  ticket tasks.
- Allowing completed tasks to return to pending or deleting history for rework.
- Allowing a plan to be cleared, superseding the last active task without a
  replacement, or accepting against a stale revision.
- Automatically moving a ticket after its last task completes.
- Invalidating phase readiness for task-only execution changes.
- Treating Task 7A or Task 11B install discrepancies as permission to patch
  owner data, inspect SQLite after install, or hide a repair inside the install
  checkpoint.
- Generalizing migration-continuation adoption into inferred assignment or a
  freestanding Planned→Active transition.
- Adding unused export guards or claiming safety where no production exporter
  exists.
- Allowing future RM5 output or RM6 import to omit task plans silently or
  adding archive v2 without separate approval.
