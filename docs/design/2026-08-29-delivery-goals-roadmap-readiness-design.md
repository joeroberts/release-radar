# RR-R10 Delivery Goals and roadmap-readiness design

- Status: Owner-confirmed direction; implementation authorized through independently verified task gates
- Approved in conversation: 2026-08-29
- Governing delivery phase: `release-radar-post-mvp-remediation`
- Governing ticket: `RR-R10`
- Target store migration: additive schema version 11

## Complete outcome

Release Radar will add first-class, phase-scoped Delivery Goals; prevent a
phase from being treated as ready while upcoming work is missing, duplicated,
or attached only to an incomplete label; and repair `RR-ROADMAP` (Established
product roadmap) so all 11 upcoming tickets belong to exactly one approved,
complete outcome. Delivery Goals remain separate from observed Codex execution
goals. The complete outcome includes migration, typed mutations, all ticket-
writer enforcement, Phase Board presentation, installed-state repair,
independent verification, owner acceptance, per-task commit/push checkpoints,
and terminal remote verification.

Bounded delivery chunks are feedback and verification checkpoints under this
one outcome. They do not reduce the feature or redefine completion as the least
possible release.

## Controlling references

- `docs/delivery/progress.md`
- `docs/design/agent-driven-delivery-dashboard-design.md`
- `docs/design/release-radar-project-planning-ux-proposal.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-003-active-phase-selection.md`
- `docs/design/mockups/phase_board.png`
- `docs/design/mockups/goals.png`
- `docs/design/mockups/goal_to_work_flow.png`

The existing five-lane Phase Board and its card vocabulary remain the visual
baseline. The existing Goals studies describe observed Codex execution goals;
they do not authorize conflating those observations with the new app-owned
Delivery Goals.

## Scope

### In scope

- App-owned Delivery Goals scoped to one project phase.
- A phase-plan readiness state and structural revision.
- Exactly-zero-or-one Delivery Goal per ticket while drafting and exactly one
  qualifying Delivery Goal per upcoming ticket when a phase is Ready.
- Complete outcome text and measurable done criteria for each Delivery Goal.
- Goal lifecycle, audit, Activity, error, replay, migration, and recovery
  semantics.
- Central enforcement across every ticket writer, including bridge commands,
  owner actions, importers, seed/sample paths, and test/debug writers.
- Non-mutating phase browsing and Delivery Goal coverage on Phase Board.
- Explicit separation from `observed_goals` and `ticket_goal_links`.
- One-time `RR-R10` bootstrap and exact six-goal repair of `RR-ROADMAP`.
- Archive-v1 protection against silently omitting Delivery Goals.

### Out of scope

- A sixth delivery lane or automatic lane changes from dependencies or Codex
  observations.
- Repository Markdown as a runtime planning authority.
- A generalized workflow engine, cloud backend, or direct SQLite access.
- A writable global Goals screen.
- Implementing the 11 roadmap tickets themselves.
- A portable archive v2; this work only adds the v1 loss-prevention guard and
  leaves v2 as a separately approved future outcome.

## Vocabulary and authority

### Delivery Goal

An app-owned outcome contract for one phase. It explains why a group of tickets
exists and the conditions that make the group complete. One Delivery Goal may
own many tickets. A ticket may belong to at most one Delivery Goal.

### Codex execution goal

An observed or explicitly linked Codex runtime identity stored through the
existing `observed_goals` and `ticket_goal_links` model. It is last-known
execution context, not plan membership or readiness authority.

### Phase plan

The app-owned structural record that says whether one phase's upcoming work
has been assessed and whether its current goal/ticket structure is complete.
Phase-plan readiness is distinct from lane state, dependency eligibility,
blockers, goal lifecycle, and the project's persisted active-phase pointer.

## Data model

Schema version 11 adds, without rewriting existing records:

### `phase_plans`

| Field | Contract |
| --- | --- |
| `project_id`, `phase_id` | Composite identity; phase ownership is enforced. |
| `state` | `legacy_unassessed`, `draft`, or `ready`. |
| `revision` | Monotonic structural revision used for optimistic concurrency. |
| `ready_revision` | The revision most recently finalized; null unless Ready. |
| timestamps | Created, structurally updated, and finalized timestamps. |

### `delivery_goals`

| Field | Contract |
| --- | --- |
| `id` | Stable project-local identity. |
| `project_id`, `phase_id` | Immutable owning phase. |
| `title` | Concise owner-visible name. |
| `outcome` | Complete user/product outcome, not a task label. |
| `done_criteria` | Ordered, nonempty measurable criteria. |
| `lifecycle` | `draft`, `planned`, `active`, `awaiting_acceptance`, `accepted`, or `superseded`. |
| `sort_order` | Stable owner-visible ordering within the phase. |
| timestamps | Created, updated, activated, and accepted timestamps as applicable. |

### `delivery_goal_ticket_assignments`

- Stores one exact project/phase/goal/ticket relationship.
- Enforces `UNIQUE(project_id, ticket_id)`.
- Enforces same-project and same-phase ownership through composite foreign keys.
- Never infers membership from dependencies, text, threads, or observed goals.

### `delivery_goal_assignment_events`

- Links the one store-owned phase-plan audit event to every ticket assigned,
  unassigned, or reassigned by that structural revision.
- Records project, phase, ticket, previous/current goal, action, and resulting
  revision; it is attribution/history, not a second mutation authority.
- Uses a deferred audit-event foreign key so the transaction may write the
  links before `DeliveryStore` inserts its one authoritative audit event.

Existing `observed_goals` and `ticket_goal_links` remain byte-semantically and
contractually unchanged. Migration does not copy, reinterpret, or relabel them.

## Phase-plan state machine

```text
legacy_unassessed ──open/revise──> draft ──finalize──> ready
                                      ^                  |
                                      └──structural edit─┘
```

- **Legacy unassessed** is assigned once to every existing phase at v11
  migration. It says no Delivery Goal assessment has been recorded.
- **Draft** permits zero-or-one Delivery Goal per ticket and incomplete goal
  definitions. It is browsable but does not authorize starting Backlog work.
- **Ready** is a validated structural claim at one exact revision.
- Any structural goal, assignment, ticket creation/deletion/outcome, or ticket
  phase-membership change increments the affected plan revision and atomically
  returns Ready to Draft.
- Lane movement, blockers, dependencies, evidence, audit, notifications, and
  valid Delivery Goal lifecycle progress do not change structural revision.

### Ready invariant

Finalization rejects a phase with zero upcoming tickets. Otherwise it succeeds
only when all of the following are true in one transaction:

1. The phase has at least one non-superseded Delivery Goal.
2. Every non-superseded goal has a title, complete outcome, at least one
   measurable done criterion, and at least one assigned ticket.
3. Every upcoming ticket in the phase has exactly one assignment to a
   non-superseded goal. An upcoming ticket is any ticket not in Accepted.
4. No assignment crosses a project or phase boundary.
5. Every complete Draft goal is promotable to Planned; finalization performs
   those promotions first, then verifies that no upcoming ticket remains
   assigned to a Draft, Accepted, or Superseded goal in the committed Ready
   state.
6. No goal or assignment operation is internally contradictory.

Open blockers and unsatisfied dependencies do not make a structurally complete
plan incomplete. They continue to control delivery eligibility through their
existing contracts.

Accepted legacy tickets are historical delivery evidence and are excluded
from the upcoming-ticket coverage invariant. The app must not invent goals for
them.

After a valid Ready phase delivers all of its assigned tickets into Accepted,
it remains Ready at the same structural revision with zero upcoming and zero
unassigned tickets. That completed state is distinct from attempting to
finalize an initially empty phase and is presented as completed delivery, not
as an invalid `0/0` readiness claim.

## Delivery Goal lifecycle

```text
draft ──phase finalize──> planned ──first work starts──> active
active ──all tickets accepted + request──> awaiting_acceptance
awaiting_acceptance ──new rework ticket starts──> active
awaiting_acceptance ──owner acceptance──> accepted
draft/planned ──bounded structural replacement──> superseded
```

- Finalizing a phase atomically changes its remaining Draft goals to Planned.
- Starting the first assigned ticket atomically changes Planned to Active. This
  is an app-owned formal delivery action, never an inference from Codex state.
- Active may enter Awaiting acceptance only when every assigned ticket is
  Accepted and no required acceptance evidence is missing.
- Awaiting acceptance returns to Active only when owner-directed rework is
  represented by a new Backlog ticket, the revised phase plan is finalized,
  and that new ticket starts. An Accepted ticket is never reopened.
- Accepted requires explicit owner acceptance recorded through the typed
  command path. Accepted is terminal; later defects require new remediation
  work rather than rewriting accepted history.
- Superseded is terminal. Only Draft or Planned goals whose assigned tickets
  have not started may be superseded, and every assignment must be removed or
  transferred atomically in the same structural revision.
- Active and Awaiting-acceptance goals cannot be superseded.
- Accepted or Superseded goal definitions cannot be edited. An assignment for
  a started or Accepted ticket cannot be removed or transferred. Draft
  promotion, first-work activation, and supersession cannot be requested as
  freestanding lifecycle changes; they remain coupled to finalization, ticket
  start, and structural revision respectively.

## Ticket-writer enforcement

All ticket mutations pass through one store-owned validation path. No bridge,
owner UI, importer, seed/sample helper, or test/debug writer may bypass it.

| Operation | Required behavior |
| --- | --- |
| Create a ticket in a phase | Create in Backlog only; structurally invalidate a Ready plan. |
| Move a ticket between phases | Only a Backlog ticket may move; it remains Backlog; both affected plans are structurally revised. |
| Start Backlog work | Require Ready at the current revision, exactly one actionable goal, and existing dependency/blocker eligibility. Planned and Active are actionable. Awaiting acceptance is actionable only for a new owner-directed rework ticket and returns to Active atomically when that ticket starts. |
| Backlog directly to Needs review, Blocked, or Accepted | Reject; these lanes cannot bypass starting-work validation. |
| In progress/Needs review movement | Preserve existing formal transition rules; assignments remain required for post-v11 work. |
| Blocked to active work | Require Ready and exactly one actionable goal; Blocked is not a readiness bypass. |
| Return to Backlog | Allow where existing policy permits; any legacy continuation exemption is permanently lost. |
| Completion/review record for unstarted Backlog | Reject. |
| Create or phase-move directly into an active or Accepted lane | Reject. |
| Move an Accepted ticket to another lane | Reject. Accepted tickets are terminal and are never reopened. |
| Work under an Accepted goal | Reject; create separately governed remediation work. |

Starting or resuming work also requires zero unresolved blockers on the ticket,
every ticket dependency in Accepted, and every phase dependency satisfied by
all tickets in the prerequisite phase being Accepted. Failure changes no lane,
goal lifecycle, audit, request receipt, or notification occurrence.

Owner-rejected goal acceptance and later defects are represented by a new
Backlog ticket. The new ticket structurally revises the phase plan, receives
exactly one Delivery Goal assignment, and passes the normal Ready gate before
work starts. Historical Accepted tickets remain unchanged.

### Legacy continuation rule

At v11 migration only, existing In progress and Needs review tickets may
continue to completion without invented Delivery Goal assignments. If one of
those tickets returns to Backlog, it cannot restart until its phase is Ready
and it has exactly one qualifying assignment. Existing Blocked tickets do not
receive the continuation exemption. Existing Accepted tickets remain immutable
legacy-completed history.

## Typed mutation contract

### Apply a phase-plan revision

One bounded, transactional command accepts:

- `version`, `requestID`, exact project root, task attribution, and reason;
- `projectID`, `phaseID`, and `expectedRevision`;
- explicit goal upserts;
- explicit ticket assignments and unassignments; and
- explicit goal supersessions.

Limits are 64 total goal operations (`goal upserts + supersessions`), 512 total
assignment operations (`assignments + unassignments`), and 65,536 bytes for the
sorted-key JSON encoding of the `AgentCommand` value before it enters the XPC
envelope. Omitted arrays mean no operation; omission never deletes or
supersedes. A command with no operations rejects without audit or receipt. A
successful structural change increments revision exactly once and leaves the
phase in Draft. Invalid, cross-phase, over-limit, or stale-revision requests
change nothing.

### Finalize a phase plan

A separate command takes the exact `expectedRevision`, validates the full
Ready invariant, changes remaining Draft goals to Planned, records
`ready_revision`, and changes the phase to Ready atomically. It returns an
actionable list of unassigned tickets, incomplete goals, or conflicting
assignments when validation fails.

### Goal lifecycle commands

Lifecycle changes use typed commands carrying `phaseID` and
`expectedPlanRevision`. They validate the transition matrix, assigned-ticket
states, a Ready plan whose `ready_revision` equals that current structural
revision, and audit attribution without incrementing that revision.
Draft-to-Planned occurs only during finalization;
Planned-to-Active occurs only with the first governed ticket start; and
supersession occurs only in an atomic structural revision. An external agent
may request Awaiting acceptance after all child tickets are Accepted, but only
an owner-app-origin command may accept a Delivery Goal. They never change a
formal ticket lane merely because the goal lifecycle changed.

### Replay and failure behavior

- The existing durable request receipt owns idempotency.
- Replaying the same `requestID` and byte-equivalent command returns the same
  entity and audit result without another mutation.
- Reusing a request ID with different content fails closed.
- A stale `expectedRevision` returns the current revision and changes nothing.
- Transaction failure rolls back goals, assignments, plan state, ticket state,
  request receipt, and audit together.
- `outcomeUnknown` is recovered only by replaying the complete original
  request.

Named error categories include `phasePlanIncomplete`, `planRevisionConflict`,
`ticketGoalRequired`, `goalPhaseMismatch`, `goalNotActionable`,
`invalidGoalTransition`, and `archiveVersionCannotRepresentDeliveryGoals`.

## Migration and archive behavior

- Migration to v11 creates one `legacy_unassessed` phase-plan row per existing
  phase at revision 0.
- It creates no Delivery Goals and no assignments from prose, dependencies,
  Codex links, audit history, or lane state.
- It preserves all existing tickets, phases, lane states, observed goals,
  exact ticket/Codex-goal links, dependencies, blockers, audits, and request
  receipts.
- Portable archive v1 import creates no Delivery Goals and marks imported
  phases Legacy unassessed. Because continuation is migration-only, every
  imported ticket is created in Backlog; a source lane other than Backlog is
  preserved as an explicit import-review item for owner reconciliation rather
  than becoming a readiness bypass.
- Portable archive v1 export must fail with
  `archiveVersionCannotRepresentDeliveryGoals` when the project contains any
  Delivery Goal, assignment, or non-legacy plan state. It must never silently
  omit the new structure.
- Archive v2 is future work requiring separate design and approval.

## Phase Board experience

The board retains exactly Backlog, In progress, Needs review, Blocked, and
Accepted. It adds planning context without turning plan state into a lane.

```text
release_radar / Established product roadmap
Viewed phase [Established product roadmap ▾]   Active phase: Post-MVP remediation
Plan: Ready · revision 3 · 11/11 upcoming tickets covered · 0 unassigned
Delivery Goal [All goals ▾]   [Show unassigned]

Backlog        In progress        Needs review        Blocked        Accepted
[ticket cards using the existing visual and density contract]

Selected ticket
Delivery Goal       RR-DG2 · Portable project continuity · Planned
Codex execution     No linked Codex execution goal
Dependencies        ...
Owner attention     ...
Evidence / Audit    ...
```

- **Viewed phase** is a navigation-only selection and never mutates the
  persisted active phase.
- The current active phase remains visibly identified. Existing authorized
  **Make active phase** behavior remains a separate, explicit action governed
  by ADR-003.
- Plan state, revision, coverage, and unassigned counts are always scoped to
  the viewed phase.
- Delivery Goal filtering preserves all five lanes and makes membership
  visible without moving cards.
- Draft and Legacy unassessed show an explicit warning and identify which
  Backlog tickets cannot start.
- The ticket inspector uses separate headings **Delivery Goal** and **Codex
  execution goal**. Neither may be displayed under a generic ambiguous
  `GOAL CONTEXT` heading.
- Existing responsive density behavior remains. New controls must remain
  keyboard reachable, VoiceOver labelled, and truthful at compact widths.
- The global Goals surface continues to present Codex execution observations
  until a separately approved information-architecture change replaces it.

## Activity, owner attention, and notifications

- Successful plan revisions, finalization, goal lifecycle changes, and
  assignment changes create project/phase/ticket-attributed audit and Activity
  entries with the originating task when available.
- One phase-plan audit remains the authoritative mutation event. Assignment-
  event links make that same audit/revision discoverable from every affected
  ticket without generating duplicate audit events.
- Failed validation creates no partial delivery state or success audit.
- Awaiting Delivery Goal acceptance creates explicit owner attention through
  the existing review inbox projection. Its Accept action dispatches through
  the existing `ownerApp` origin; the MCP surface cannot assert owner
  acceptance.
- Plan-state changes and Delivery Goal lifecycle changes do not masquerade as
  observed Codex events and do not generate a `Codex goal blocked` Pushover.
- Existing notification behavior for a genuinely observed linked Codex goal
  entering Blocked remains unchanged.

## Approved Established product roadmap catalog

The six goals below are the complete owner-approved goal structure for all 11
upcoming `RR-ROADMAP` tickets. The assignment sets are disjoint and their union
is exactly `RR-RM1` through `RR-RM11`.

### RR-DG1 — Coherent owner planning and navigation

- Tickets: `RR-RM1`, `RR-RM2`, `RR-RM10`
- Outcome: Resolve the coupled product and information-architecture contract
  across Phase Board, Project Plan, Work Board, Activity/History, goal-link
  cardinality, semantic suggestions, and complete history semantics; then
  deliver coherent owner-visible Back/Forward navigation and Help against that
  approved contract.
- Done when:
  1. The coupled product/IA decision is explicit, approved, and reflected in
     controlling design and architecture artifacts.
  2. Back and Forward restore complete owner-visible history coherently across
     the approved surfaces and recover safely at history boundaries.
  3. Help explains the final navigation and onboarding contracts rather than a
     superseded flow.
  4. Runtime visual, keyboard, VoiceOver, persistence, and history behavior is
     independently accepted.

### RR-DG2 — Portable project continuity

- Tickets: `RR-RM5`, `RR-RM6`
- Outcome: Give the owner an authoritative, lossless, versioned export and a
  transactional Portable Import that restores one complete supported Release
  Radar project without copying SQLite, guessing identity, or silently
  dropping state.
- Done when:
  1. The exporter, archive contract, and exporter-produced acceptance fixture
     are approved and independently verified.
  2. Portable Import accepts only the supported exporter output, previews and
     revalidates it, rejects collisions and invalid structure, and writes the
     complete supported project atomically.
  3. Failure, rollback, destination authorization, historical-observation, and
     privacy behavior matches ADR-001.
  4. Export/import round-trip and installed-product recovery evidence is
     independently accepted.

### RR-DG3 — Truthful supported Codex visibility

- Tickets: `RR-RM7`
- Outcome: Attach live Codex task state only through a supported,
  authenticated, sandbox-compatible endpoint, while preserving truthful stale
  or unavailable presentation and never reading private Codex state.
- Done when:
  1. A supported endpoint and authentication boundary are proven before
     implementation, or the goal records an approved no-go decision while the
     current truthful unavailable behavior remains.
  2. Observation cannot mutate formal delivery state or gain SQLite, project,
     credential, Accessibility, Full Disk Access, or private-rollout access.
  3. Freshness, disconnect, relaunch, wrong-project, and failure behavior is
     independently verified in the installed product.

### RR-DG4 — Production-quality macOS release

- Tickets: `RR-RM3`, `RR-RM4`, `RR-RM9`
- Outcome: Finish the production macOS presentation and maintenance baseline,
  and apply Developer ID signing/notarization exactly when the owner-approved
  distribution scope requires it.
- Done when:
  1. Deterministic light/dark wordmark lockups use a licensed production
     typeface or approved drawn outlines and pass visual acceptance.
  2. The scoped Swift optional-`.none` and test actor-isolation warnings are
     removed without unrelated behavior changes.
  3. Distribution scope is explicitly recorded: if delivery remains limited
     to the owner Mac, `RR-RM9` is accepted as not required; if distribution
     expands, Developer ID signing and notarization are implemented and
     verified before acceptance.
  4. The final owner-facing package passes build, signing, launch, and relaunch
     verification for the chosen distribution path.

### RR-DG5 — iPhone-companion scope decision

- Tickets: `RR-RM8`
- Outcome: Make an explicit owner-approved decision on whether to pursue a
  CloudKit-backed read-only iPhone companion after product scope, information
  architecture, privacy, recovery, and boundary implications are understood.
- Done when:
  1. The decision is recorded as pursue or do not pursue with its rationale.
  2. A pursue decision includes an approved architecture-boundary change and a
     separately governed delivery outcome; it does not silently authorize
     implementation here.
  3. A do-not-pursue decision records the rejected scope and completes this
     decision goal without placeholder implementation.

### RR-DG6 — Role-agent workflow decision

- Tickets: `RR-RM11`
- Outcome: Decide whether Release Radar should adopt process-isolated,
  independent role-agent execution without changing delivery semantics merely
  to mirror an implementation process.
- Done when:
  1. The owner-approved decision and rationale are recorded.
  2. A pursue decision defines lifecycle, authority, attribution, failure, and
     review-independence contracts before implementation is planned.
  3. A do-not-pursue decision preserves current delivery semantics and closes
     the candidate without speculative machinery.

## One-time installed-state repair

After the v11 product is installed and verified:

1. Create `RR-DG-R10` under `release-radar-post-mvp-remediation` with the
   complete RR-R10 outcome and acceptance criteria, and assign only `RR-R10`.
2. Finalize that phase without inventing Delivery Goals for accepted legacy
   tickets `RR-R1` through `RR-R9`.
3. Create the six approved `RR-DG1` through `RR-DG6` records under
   `RR-ROADMAP` and apply the exact ticket sets above.
4. Finalize `RR-ROADMAP` only after exact set-equality validation succeeds.
5. Verify that ticket outcomes, lanes, dependencies, blockers, active-phase
   pointer, observed Codex goals, and exact ticket/Codex-goal links are
   otherwise unchanged.
6. Replay the exact idempotent repair requests and relaunch the installed app
   to prove no duplicate goals, assignments, audits, or state changes.

Expected unchanged `RR-ROADMAP` lane counts are Backlog 8 / In progress 0 /
Needs review 0 / Blocked 3 / Accepted 0. The project's active phase remains
Post-MVP reported-defect remediation unless the owner separately changes it.

## Verification and acceptance

Implementation is not complete until independent roles verify:

- v10-to-v11 migration, foreign keys, uniqueness, rollback, and replay;
- both state machines, every allowed/rejected transition, and the invariant
  that Accepted tickets are never reopened;
- every ticket-writer path, including `upsertTicket`, bridge commands, owner
  actions, seed/sample/debug paths, portable import, and phase movement;
- the legacy In progress/Needs review exception and the non-exempt Blocked and
  Backlog cases;
- stale revision, mismatched phase, duplicate assignment, incomplete goal,
  oversized request, and outcome-unknown recovery;
- archive-v1 import behavior and export loss-prevention;
- observed Codex goal storage, display, linking, and notification preservation;
- five-lane Phase Board behavior, non-mutating viewed phase, active-phase
  separation, filters, compact density, keyboard access, VoiceOver, error and
  empty states, and relaunch persistence;
- exact RR-R10 bootstrap and exact six-goal `RR-ROADMAP` repair;
- installed application build/sign/install/launch/relaunch behavior.

Required independent approvals are Planning, Architecture, TPM/Delivery,
QA/Test, Code Review, and Security/Privacy for the applicable high-risk storage,
archive, bridge, and runtime boundaries. The approved planning package is
committed and pushed before implementation; each bounded task is committed and
pushed only after its full independent gate returns GO with Required 0. The
owner then accepts the complete RR-R10 outcome, after which terminal evidence
and exact remote state are reconciled before the persistent goal is completed.

## Completion boundary

The written design is complete when this artifact, ADR-004, and the bounded
Phase Board interaction contract are reviewed as faithful to the approved
conversation design. RR-R10 product work remains incomplete until every
verification and acceptance condition above is satisfied.
