# Release Radar Ticket Tasks contract

- Status: owner-approved product contract; post-MDCP execution alignment authorized 2026-09-02
- Date: 2026-08-30
- Governing delivery phase: `release-radar-post-mvp-remediation`
- Governing ticket: `RR-R10`
- Delivered task-storage foundation: additive schema v12; installed store schema v13; through-Task-7 candidate schema v14
- Architecture decision: `docs/architecture/ADR-005-ticket-task-work-plans.md`

## Product outcome

Release Radar will add a first-class app-owned per-ticket section named
`Tasks`. A task plan makes the bounded work required for one non-atomic ticket
explicit without turning repository documents, Git state, tests, Codex goals,
or an agent's execution state into delivery authority.

Atomic tickets may have no task plan. Once a ticket has a plan, every active
task is required. An incomplete active task blocks that ticket's transition to
Accepted. Completing every task changes neither the ticket lane nor its review
or acceptance state: review requests and owner acceptance remain explicit,
separate actions.

## Controlling references

- `docs/design/2026-08-29-delivery-goals-roadmap-readiness-design.md`
- `docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md`
- `docs/design/release-radar-delivery-goals-phase-board-design.md`
- `docs/design/mockups/phase_board.png`

The approved five-lane Phase Board, ticket-card hierarchy, density behavior,
and selected-ticket inspector remain the visual baseline. Ticket Tasks add
work-plan context; they do not add a lane, change Delivery Goal meaning, or
replace dependencies, blockers, evidence, review, or acceptance.

## Vocabulary and authority

### Ticket task plan

An app-owned, optional, revisioned plan for exactly one ticket. A plan has its
own optimistic revision and owns an ordered set of ticket tasks. The plan is
not a phase plan and its revision is independent of the phase-plan structural
revision.

### Ticket task

A required unit of work inside a ticket task plan. Each task has:

- a stable machine ID, distinct from all owner-visible text;
- a stable visible label such as `Task 3` or `Task 1B`;
- a meaningful verb-led owner-visible title;
- deterministic order;
- completion `pending` or `completed`; and
- lifecycle `active` or `superseded`.

Completion and lifecycle are independent. Superseding a task preserves whether
it was pending or completed. IDs are never reused and rows are never hard-
deleted. A task's visible label is immutable after creation. Completed task
definitions are immutable; later correction or rework is a new task.

### Non-authoritative inputs

Git commits, Markdown plans and briefs, tests, observed Codex goals, Codex
thread state, repository status, and execution progress may be attached as
evidence, but none can create, revise, complete, supersede, or accept a task.
Only typed app-owned requests through the audited store transaction have that
authority. Runtime code never parses this or another document to manufacture a
task plan.

## Owner-visible contract

### Ticket Details

The selected-ticket inspector contains a section titled exactly `Tasks`.

- No plan: show `No task plan`. Do not render an empty checklist or zero count.
- Loaded plan: show active, non-superseded tasks in deterministic order.
- Load unavailable: show `Tasks unavailable` with the existing actionable
  store reload/recovery treatment. `PhaseBoardView`, which constructs
  `TicketDetailView` and owns the existing reload action, passes that callback
  into this treatment so the owner can retry without a new task-specific reload
  mechanism. Do not render stale tasks as current.
- Superseded tasks are retained in the store and audit history but excluded
  from the visible active list.

Each visible row is read-only and formatted as:

```text
[checked or unchecked box shape] [stable visible label]: [meaningful verb-led title]
```

The box is a status indicator, not a control. There is no redundant visible
`Completed` or `Pending` text. The section has no completed/total aggregate,
percentage, progress bar, estimated effort, or persisted level of effort.

### Ticket cards

A card whose task plan loaded successfully shows a neutral checklist glyph and
the total count of active, non-superseded tasks only, for example:

```text
☷ 7
```

The card never shows `2/7`, a percentage, or completion-colored progress. No
completed/total fraction is ever rendered or announced by the card, Ticket
Details, or accessibility. The only card task signal is `☷ N`, where N is the
active, non-superseded total. The signal is omitted when the ticket has no plan
or task loading is unavailable. It appears alongside the existing dependency
and blocker signals and remains neutral in every lane.

The card count and Ticket Details list are derived in one dashboard load from
the same canonical active task rows. The count is never separately persisted.
Adding one active task increases both list length and card count. Superseding
one decreases both. Completing a task changes its row indicator but not the
card count.

The projection is an explicit tri-state value, never nested optionals or an
empty-array convention:

```swift
enum TicketTaskPlanProjection {
    case noPlan
    case loaded(plan: LoadedTicketTaskPlanProjection)
    case unavailable(recovery: TaskPlanRecoveryProjection)
}
```

Only `loaded` supplies task rows or a card count. `noPlan` supplies the
deliberate atomic-ticket copy and no card signal. `unavailable` supplies
actionable recovery and no card signal; it never degrades to `noPlan` or a
stale count.

A task-row query failure is isolated to that ticket's task projection: return
`unavailable(recovery:)`, discard any previously projected task rows/count, and
keep the rest of the phase board usable from its successfully loaded canonical
data. The failure neither converts the ticket to `noPlan` nor replaces the
whole board with a task-specific error.

### Wide and compact behavior

- Wide cards keep the current ticket ID/outcome hierarchy. Their metadata row
  is ordered exactly `task count`, `dependency count`, `blocker count`, with a
  system hairline vertical separator and 8–11 points of spacing between
  adjacent present signals, with no leading/trailing separator. The task glyph
  is neutral; dependency remains secondary and blocker remains red, matching
  the current mockup language.
- Compact cards retain the task signal even when outcome text is omitted; the
  signal uses the same active count as wide cards.
- Narrow layout priority is ticket identity, blocker, dependency, task count,
  then outcome. Identity and every present metadata signal remain visible;
  outcome is omitted first. Metadata may wrap or increase card height but may
  not overlap, clip, or shrink the card's existing full hit target or its
  current 48-point compact minimum height.
- Wide Ticket Details rows keep the label and title on one line when space
  permits. Long titles wrap under their own text, not under the indicator.
- Compact Ticket Details rows may wrap the title, but the complete label,
  title, and state remain available and no task is collapsed into a count-only
  inspector.
- A long active list scrolls with the existing inspector. It is not truncated
  behind a hidden `more` disclosure.

### Accessibility and interaction

- Each row exposes one accessibility element announcing the stable label,
  complete title, `checked` or `unchecked`, and `item N of M`.
- The decorative box shape is hidden from accessibility so state is not
  announced twice.
- Rows have no button, toggle, checkbox action, hover action, context-menu
  mutation, or keyboard activation.
- The card signal announces `N tasks` and is part of the card's existing
  accessibility label. It does not announce a completed fraction.
- The glyph and count are hidden as separate accessibility elements and expose
  no action; the ticket card remains the single focusable hit target.
- Inspector keyboard order places `Tasks` after the ticket outcome and before
  Delivery Goal, Codex execution goal, relationships, attention, and evidence.
- Dynamic Type, increased contrast, and VoiceOver must preserve the readable
  label/title association at wide and compact widths.

## Data contract

Schema v12 adds two tables without changing the accepted v11 definitions.

### `ticket_task_plans`

| Field | Contract |
| --- | --- |
| `project_id`, `ticket_id` | Composite identity and exact ticket ownership. |
| `revision` | Positive, monotonic optimistic revision. A newly created plan commits and returns revision 1; revision 0 is never visible. |
| timestamps | Created and most-recently-mutated timestamps. |

There is at most one plan per ticket. A plan row is never deleted. Every
committed plan has at least one active task.

### `ticket_tasks`

| Field | Contract |
| --- | --- |
| `project_id`, `ticket_id`, `id` | Stable plan-local machine identity; task machine ID is at most 256 UTF-8 bytes. |
| `label` | Nonempty immutable owner-visible label, at most 256 UTF-8 bytes. |
| `title` | Nonempty meaningful owner-visible work title, at most 4,096 UTF-8 bytes. |
| `sort_order` | Nonnegative stable ordering key. |
| `completion` | `pending` or `completed`. |
| `lifecycle` | `active` or `superseded`. |
| timestamps | Created, updated, completed, and superseded timestamps as applicable. |

The store rejects machine-ID reuse, label reuse within one ticket plan,
cross-project ownership, cross-ticket ownership, negative ordering, invalid
state/timestamp combinations, and direct deletion. Projection order is
`sort_order`, then label, then machine ID, each using stable byte ordering.

Core validation and both task-command MCP schemas enforce the exact encoded
UTF-8 byte limits above without truncation or character-count substitution.
Boundary tests use ASCII and multibyte values at limit minus one, the exact
limit, and limit plus one.

Schema v12 cannot cascade away plan or task history. Composite foreign keys
and explicit parent-delete triggers reject deletion of a ticket or project
while it owns any task-plan history; task-plan and task no-delete triggers
continue to reject direct deletion. Migration and Store tests exercise direct
ticket deletion, project deletion that would otherwise cascade through its
tickets, and direct plan/task deletion, with all rows unchanged after rejection.

Schema v12 migration creates zero task plans and zero ticket tasks. The
accepted schema-v11 fixture and v11 schema contract remain immutable.

## Plan invariants

1. A ticket may have no plan.
2. A committed plan has at least one active task.
3. Every active task is required for acceptance.
4. Superseded tasks remain durable history and are excluded from the visible
   list, card count, and acceptance denominator.
5. The last active task cannot be superseded unless the same transaction adds
   at least one replacement active task.
6. A plan cannot be deleted, cleared, or replaced by omission.
7. Task IDs and labels cannot be reused after supersession.
8. Pending may move to Completed once. Completed never moves back to Pending;
   newly discovered or rework scope is a new unchecked active task.
9. Accepted tickets and their task plans are immutable except for an exact
   idempotent replay returning the original result.
10. Every addition is created Active and Pending. An addition payload has no
    completion field and cannot create a completed task.

The final-state invariant, not operation ordering, prevents denominator
laundering: a bounded revision may add replacements and supersede obsolete
tasks atomically, but it cannot commit zero active tasks at any intermediate
transaction outcome visible to another reader.

## Typed mutation contract

### Revise a task plan

`reviseTicketTaskPlan` carries the command version, request ID, authorized
project root, attribution/reason, ticket ID, optional exact expected revision,
explicit task additions, explicit pending-task definition revisions, and
explicit supersessions.

- `expectedRevision == nil` means the plan must not exist and the command must
  add at least one active task. Successful creation commits and returns
  revision 1.
- A present revision must equal the current plan revision.
- Omitted arrays mean no operation. Omission never deletes or supersedes.
- Every addition is active and pending. Completed state is not accepted in an
  addition or definition-revision payload.
- A definition revision may change only the title or order of an active pending
  task; machine ID and label are immutable.
- One command allows at most 64 total additions, definition revisions, and
  supersessions, and the sorted-key encoded `AgentCommand` remains subject to
  the existing 65,536-byte boundary.
- Core and MCP validation both reject a task machine ID over 256 UTF-8 bytes,
  a visible label over 256 UTF-8 bytes, or a title over 4,096 UTF-8 bytes.
- After creation, a successful nonempty mutation at revision R commits and
  returns R+1 exactly once. A semantically empty new request rejects without
  audit or receipt.

### Complete a task

`completeTicketTask` carries ticket ID, task machine ID, and exact expected
plan revision. It may change one active pending task to completed and increments
the plan revision exactly once. Completing an already-completed task under a
new request rejects as a no-op; exact replay of the original request returns
the original result. A completed task never returns to pending.

### Accept a planned ticket

The typed Accepted transition for a ticket with a task plan carries the exact
expected task-plan revision. Inside the same `BEGIN IMMEDIATE` store-owned
transaction it reads that exact current revision and verifies every active
task is completed before changing the lane. A missing/stale revision or any
pending active task rejects with no lane, audit, notification, receipt, task,
or plan change.

The legacy ticket transition may accept an atomic no-plan ticket under the
existing acceptance rules. It must reject acceptance of a planned ticket
without the revision-bearing path. Completing all active tasks never changes a
lane, requests review, or accepts a ticket automatically.

No Accepted path is exempt: agent transition command, owner action, importer,
sample/debug writer, and any internal transition helper route through the same
policy. `AgentCommand.upsertTicket` is closed as an alternate Accepted path:
for both create and update, any upsert whose supplied lane is Accepted rejects
with zero ticket/task/plan/audit/receipt/attention/notification effects. Upsert
does not accept a task-plan revision. Planned and no-plan tickets reach
Accepted only through the existing transition path, whose optional exact task-
plan revision follows the matrix below. The transaction distinguishes exactly:

- no plan plus no supplied task revision: apply existing acceptance rules;
- loaded plan plus its exact supplied revision: require all active tasks
  completed, then accept; and
- no plan with a supplied revision, or loaded plan without one: reject.

Concurrent commands serialize through the existing `BEGIN IMMEDIATE`
transaction. Acceptance racing first-plan creation, addition/supersession,
completion, another revision, or another completion has one coherent winner.
The loser re-reads a missing/stale revision or terminal ticket and rolls back
without orphan tasks, audits, receipts, lane changes, owner attention, or
notifications.

### Audit, replay, and failure

- All three mutation families use the existing durable request receipt and one
  authoritative store-owned audit event.
- Audit scope is the ticket task plan and includes the ticket, prior/resulting
  revision, typed operation identities, and task attribution when available.
- Exact request replay returns the original entity IDs, audit ID, and revision
  without another mutation or audit.
- Reusing a request ID with different canonical content fails closed.
- Revision conflict returns the current revision and changes nothing.
- Transaction failure rolls back plan rows, task rows, ticket lane, receipt,
  audit, owner attention, and notifications together.
- `outcomeUnknown` recovery replays the complete original request only.

Named error categories include `ticketTaskPlanNotFound`,
`ticketTaskPlanAlreadyExists`, `ticketTaskPlanRevisionConflict`,
`ticketTaskNotFound`, `ticketTaskImmutable`, `ticketTaskIncomplete`,
`ticketTaskReplacementRequired`, and `invalidTicketTaskMutation`.

Acceptance verification covers these schedules with the repository's existing
store/dispatcher concurrency infrastructure: no-plan Accept versus first plan
create; Accept at revision R versus add/supersede at R; Accept at R versus
completion at R; and two revisions or completions at R. Tests assert the exact
winner state and zero loser side effects rather than relying on timing.

## Delivery Goal and phase-plan interaction

Ticket-task-only additions, definition revisions, completion, and supersession
do not change Delivery Goal lifecycle, phase-plan state, phase-plan revision,
or `ready_revision`. They change how the existing ticket proves its own work;
they do not change phase membership, ticket outcome, or Delivery Goal
structure.

Ticket creation, ticket outcome change, ticket phase move, Delivery Goal
definition/assignment/supersession, and phase changes remain structural under
ADR-004 and invalidate readiness exactly as that contract requires. A task
mutation cannot be used to bypass or satisfy Delivery Goal readiness.

RR-R10 needs one narrow legacy-adoption rule after its pre-Task-2A start. When
finalizing a plan to Ready explicitly assigns a migration-continuation In-
progress or Needs-review ticket to exactly one Draft Delivery Goal, that same
transaction promotes only that goal to Active, sets its activation timestamp,
and clears the continuation. It never infers or retroactively creates an
assignment, and it grants no general freestanding Planned→Active transition.

## Portable import and future export boundary

The current production `DeliveryArtifactImporter` boundary is import-only;
Release Radar has no production portable exporter or exportability call path
for RR-R10 to guard. Current import creates no task plans. RR-R10 therefore
adds no exporter, archive predicate, guard, archive error, compatibility
framework, or archive v2, and it makes no claim that current export is safe.

Future Established-roadmap RM5 owns the exporter and archive-format boundary.
It must represent ticket task plans in its separately approved format or fail
before emitting an archive; it must never silently omit them. RM6 import may
accept only complete output in that supported exporter format and otherwise
must reject it. RR-R10 authorizes no exporter or archive-v2 work.
ADR-005 supersedes only its own earlier Ticket Tasks archive assumption; it
does not implement the older Delivery Goals helper described by ADR-004 unless
and until a real production exporter boundary exists.

## Failure and recovery presentation

- Store unavailable: replace Tasks and its card signal with the existing
  actionable store-recovery state; never present cached counts as current.
- Refresh failure after a committed mutation: state that the task change was
  saved and a refresh is needed; do not invite duplicate submission.
- Revision conflict: retain safe unsubmitted owner view state, show the current
  revision, and offer reload. No row appears changed before authoritative
  reload.
- No plan: present the deliberate atomic-ticket state, not an error.
- Empty or corrupt loaded plan: fail the projection closed as unavailable; do
  not render `0 tasks` or permit acceptance.
- Acceptance blocked by tasks: identify the pending active task labels/titles
  in the actionable error without changing the lane.

## Acceptance criteria

- Schema v11 migrates additively to v12 with zero inferred plans/tasks and
  complete v11 semantic preservation.
- Stable IDs/labels, deterministic order, completion/lifecycle independence,
  immutable history, no deletion, no reuse, and atomic last-task replacement
  are enforced at policy and store boundaries.
- Core and MCP reject task machine IDs over 256 UTF-8 bytes, labels over 256
  UTF-8 bytes, and titles over 4,096 UTF-8 bytes; limit-minus-one, exact-limit,
  and limit-plus-one tests cover ASCII and multibyte input.
- Ticket/project parent deletion and cascade attempts cannot erase task-plan or
  task history and leave all rows unchanged when rejected.
- Revision conflicts, changed-body replay, limits, cross-project/ticket access,
  no-op requests, rollback, and outcome-unknown recovery fail closed.
- New-plan creation returns revision 1; each later successful mutation advances
  exactly once from R to R+1.
- Planned-ticket acceptance observes the exact task revision and all active
  completions in the same transaction; atomic no-plan tickets retain their
  explicit path.
- Accepted `upsertTicket` create and update requests always reject without
  effects and carry no task-plan revision; all acceptance uses the transition
  path.
- Task-only mutations leave phase-plan state/revisions byte-semantically
  unchanged; structural Delivery Goal/ticket edits retain ADR-004 behavior.
- Card count and Ticket Details list derive from the same active rows; add and
  supersede change both, completion changes neither count nor lane.
- No-plan, loaded-list, unavailable, wide, compact, keyboard, increased-
  contrast, and VoiceOver behavior pass running-app comparison against the
  approved Phase Board design language. The same manual/runtime verification
  exercises Dynamic Type at both wide and compact widths without a new test
  harness.
- A task query failure produces unavailable recovery with no stale rows/count
  while the rest of the successfully loaded phase board remains usable.
- Current import creates no task plans. RR-R10 adds no exporter or export guard;
  future RM5 export/format work must represent task plans or fail before
  emission, RM6 import accepts only complete supported exporter output or
  rejects it, and no archive v2 is authorized here.
- RR-R10 bootstrap uses explicit typed requests, reflects truthful completion
  at application time, replays exactly, and never derives authority from
  repository or Codex state.
- Additions are always pending; chained completion replay/rejection preserves
  exact revision and audit history.
- Pending and completed supersession preserve completion/timestamps;
  completion or definition revision of a superseded task, re-supersession, and
  duplicate/conflicting IDs within or across operation arrays reject without
  effects.
- One-task and 16-task cards announce only `1 task`/`16 tasks`; completion does
  not change the count, superseded rows are absent, glyph/count are not separate
  focus/actions, long lists expose first/last without hidden `more`, and compact
  identity/metadata/hit targets do not overlap.
- The original package approval and schema-v10 start handoff remain completed
  history. Unopened work follows the current ledger, accepted post-MDCP
  baseline and risk-triggered review policy; historical status does not reopen
  work or authorize new owner mutations.
- Task 7A makes the initial 16-row plan live while RR-R10 is In progress. Its
  adapted, independently reviewed managed-v13 recovery runbook covers
  process quiescence, SQLite main/WAL/SHM consistency, backup identity,
  disposable-copy restore proof, retention, and exact abort/restore/relaunch/
  readback; Task 11B reuses it without creating a backup product/framework.
- Every live Task 7A/8/9/10/11A completion is durably reconciled before the
  next task opens; Task 11B is reconciled terminally. Final Task 11B readback
  uses all initial plus reviewed later rows, dynamic active count N, card
  signal `☷ N`, and proof that all N active rows are checked.
