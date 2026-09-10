# Phase 5E — Explicit phase lifecycle

## Objective and outcome

Deliver the [approved final Phase 5 lifecycle slice](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md#remaining-phase-5-delivery-sequence--2026-09-09)
from exact local Phase 5D closeout `9bd11ca4a9ed26b4e67fd4c0baa79274c0290f6d`
plus this committed handoff. The owner selected Unassessed / Upcoming /
In delivery / Completed, legacy phases Unassessed, multiple concurrent
In-delivery phases, explicit completion after obligations resolve, and explicit
reopening or a new phase for further work. No product-choice approval is pending.

## Scope and exclusions

Persist phase lifecycle independently of structural readiness, active/viewed phase,
Delivery Goal lifecycle, ticket lanes and runtime observations. Provide typed,
audited explicit lifecycle decisions and a complete native owner workflow in the
existing Plan/phase surfaces. Completed phases reject new or revised delivery
work through every affected writer until explicitly reopened. Preserve all D
retirement, successor, obligation and historical facts; never auto-accept goals,
reopen Accepted tickets/goals, stop external runs or infer lifecycle from counts.

No new phase ordering policy, sixth ticket lane, broad Goals/History redesign,
execution engine, exporter/importer, new dependency, runtime pilot, installation,
owner-data repair, publication or unrelated refactor is included. Existing phase
creation remains available as the alternative to reopening; do not invent cloning.

## Dependencies and accepted architecture

Read [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-003](../../../architecture/ADR-003-active-phase-selection.md),
[ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md), the
[dashboard design](../../../design/agent-driven-delivery-dashboard-design.md),
and [Phase 5D evidence](../../evidence/2026-09-10-phase5d-successors.md).
Read-only chief consultation `01a08a76-9040-75a2-9e8d-9b367e08903e`
confirmed the shared boundaries before dispatch. The existing store-owned D
assessment is the coverage authority. Preserve its
exact current-assignment delivery credit, detached debt, explicit reconciliation,
superseded obligations, required split descendants and non-vacuity rules.

## Explicit lifecycle contract

Both migrated and newly inserted phases start Unassessed at lifecycle revision 0,
without invented owner events. Explicit decisions permit Unassessed to Upcoming
or In delivery, Upcoming to In delivery and In delivery to Upcoming, and guarded
completion from any noncompleted state. Completed exits only through a named
Reopen action to In delivery (default) or Upcoming for deferred work. No implicit
return to Unassessed or lifecycle change on ordinary execution. New work after
completion requires reopening or a new phase; old Accepted/retired work stays so.

Use narrow typed owner-app decisions with exact registration/project/phase,
expected lifecycle revision, requested action/target and nonblank reason. Agents
may read lifecycle but cannot complete, reopen or assert trusted owner origin.
Origin checks precede replay. Each new decision increments only lifecycle revision;
completion binds the current relevant planning/coverage baseline as well. Reuse
existing baseline machinery after including lifecycle facts, not another proposal
framework. Same-state fresh actions may be rejected as no change; exact committed
request replay returns the original receipt. Reopen does not revive stale approvals.

Completion assesses every phase-owned goal and every nonretired phase ticket.
Globally unplaced project tickets do not become obligations of every phase.
Remaining required non-superseded goals must be explicitly Accepted. Fully and
explicitly dropped goal scope remains removed scope, not a goal to auto-accept;
a mixed phase still needs actual delivered work and acceptance of remaining
required goals. Superseded debt must resolve; debt-free superseded goals do not
block. Cross-phase carry depends on exact descendant work, not completion of the
whole destination phase. Legacy phases with no goals can qualify through actual
nonretired Accepted work. Do not add retrospective evidence-freshness gates.
D dependency eligibility remains its existing contract; do not require a Completed
label merely to unlock downstream work.

Distinguish mutated work ownership from read-only reference targets. Open-phase
work may depend on Completed Accepted work without modifying that prerequisite.
Preserve browsing, runtime observations, exact historical replay and identity-
preserving evidence-location recovery; do not freeze unrelated project maintenance.
Lifecycle storage has a current record plus immutable transition history including
project/phase, revision, from/to, owner reason/time and audit identity, with retained
removal counterparts. Backup restores its live snapshot; newer events are retained
history, not automatically replayed over it. Registration rotation never erases
live lifecycle/coverage/retirement facts or transfers old authority to new work.

## Required behavior and material risks

- Add schema 23 after 22. Existing phases migrate to Unassessed without guessing
  from active context, readiness, Accepted work or runtime state. New phases have
  an explicit safe default. Preserve phase IDs, names, ordering, plans, goals,
  tickets, links, completions and all retained history.
- Completion rechecks canonical obligations, actual delivered outcome, accepted
  required goals and remaining required work in the same audited transaction.
  Uncovered/unassessed debt, incomplete carried descendants, unaccepted required
  goals and unfinished live work reject. Empty or all-dropped scope is not proof
  of delivery. D dependency eligibility alone is insufficient: E completion also
  requires explicit Accepted lifecycle for every required non-superseded goal.
  Debt-free superseded goals do not invent blockers; legacy Accepted
  work is not retroactively assigned to fabricated goals.
- Optimistic lifecycle revision and current relevant planning facts guard stale
  owner actions. Exact successful replay stays idempotent; conflicting request
  reuse rejects. Race completion against edits atomically: one commits and the
  other observes the resulting state. Failed changes leave no partial domain,
  audit or receipt writes. Caller data cannot assert trusted owner origin.
- Enforce Completed admission across the existing common store policies and every
  affected mutation boundary: placement/moves, plan/goal/task edits, ticket work,
  completion/review, dependencies, references, evidence and associations. Validate
  old and new owners where rehoming touches two phases. Saved proposals cannot
  bypass the guard at apply, including proposals approved before completion.
  Include separate managed-evidence and importer insertion paths, not just
  AgentCommandDispatcher. Read-only navigation, observed external runtime updates and historical receipts
  must not be confused with new delivery work.
- Preserve lifecycle/current revision and transition history through application
  relaunch, project archive/removal, retained-history readback and full backup
  restore, including older backups and rotated authority. Do not delete live
  domain facts when rotating proposal/registration authority. Historical approvals
  and removed registrations cannot authorize new transitions after recovery.
- Include lifecycle facts in existing proposal baselines/readback where they
  affect admission. Keep strict packaged command schemas/help/query contracts
  aligned. Document complete future portable representation without changing v1
  or implementing a new exporter.
- Existing native Plan and board surfaces show the lifecycle distinctly from
  readiness and active/view context. Replace existing Ready-plus-zero-upcoming
  wording that calls a phase delivery-complete with truthful structural/readiness
  wording and persisted lifecycle; counts never publish Completed. Owner actions show exact phase/current state,
  intended state, eligibility or blocking reason, pending/success/failure state,
  and explicit reopening. Preserve exact selection and keyboard/AX focus through
  action/refresh/Back/Forward. Completed history remains browsable. Multiple
  In-delivery phases must render truthfully without changing the active pointer.
- Inspect relevant [Phase Board mockup](../../../design/mockups/phase_board.png)
  and current Plan captures before UI work. Preserve supplied RDS, five-lane
  hierarchy and compact stacking. Verify actual native controls and visible
  content at wide/compact widths; offscreen AX text alone is not visual proof.

## Test strategy and acceptance

Use repository-native test-first development at the lowest practical layer.
Cover migration defaults and preservation; lifecycle transitions/reopen; all
completion blockers and positive legacy/carried cases; exact authority and replay;
stale/racing completion versus relevant edits; Completed writer and association
bypasses; proposal approval-before-completion/apply-after-completion; recovery live
state and guards; query/package parsing. Reuse established fixtures and guards,
not a custom validation framework or an exhaustive duplicate writer matrix.

Native acceptance must exercise actual owner lifecycle controls, blocking errors,
completion, preserved-state reload, rejection of new work until explicit reopen,
multiple In-delivery phases, active/view independence and wide/compact focus.
Distinguish new AppModel over a store from full process restart. Read screenshots
against the approved design; record necessary deviations in the existing design.

Every Xcode/native launch requires an exact selector/result reservation from the
orchestrator. Use task-local HOME/TMPDIR under a dedicated Phase 5E temporary root,
`env -i`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`,
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, and
`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=`.
Freeze all candidate files during execution. Use synthetic stores and default
services suppressed; no real service registration or owner bridge. External CUA
may select only an already-running verified synthetic PID and uniquely titled
window. Never select a non-running development app: app lookup can launch it.
Hosts read fresh request-specific markers only; the external controller writes
markers. Preserve outputs and fixtures; no cleanup is authorized.

## Assignment, review and delivery endpoint

One fresh local delivery task owns product source, affected tests, necessary
ADR/design facts and canonical evidence. Use `gpt-5.6-sol` / `high` for the
cross-component authority/recovery work; escalation ceiling Astra High for a
named unresolved issue. No Ultra or unspecified inherited effort; no subagents.
Start from this committed handoff containing exact D baseline. The orchestrator
owns `docs/catalog.json`, generated indexes and `docs/delivery/progress.md`.
No overlapping writer or shared app-state mutation is released.

One fresh independent `gpt-6-astra` / `high` reviewer covers architecture/data,
security and native UX/QA risks after direct checks. Required findings alone
block; the same reviewer checks bounded corrections. Do not review reviews or
restart passed checks absent a concrete affected property. Chief consultation
resolves shared contract dependencies before writer dispatch.

Persist evidence under `docs/delivery/evidence/2026-09-10-phase5e-lifecycle.md`
with selected images alongside. Report changed behavior, scoped local commit,
checks and limitations; preserve temporary output paths and distinguish any
pre-existing state. Expected endpoint: source/tests/docs committed, direct checks,
independent PASS, integrated catalog/ledger, and completed peers archived.

Local source, tests, necessary documentation, commits and fresh tasks are
explicitly authorized. Shared+C/D/E push, PR and merge remain unapproved; do not
publish inherited commits through an E branch. Installation, app-state mutation,
binding/catalog acceptance, credentials, notifications and cleanup are excluded.
No application synchronization claim is allowed without separate authorization.
The documented D development-app startup incident remains retained, with no claim
that incidental effects were disproved. The installed owner app stays untouched.
