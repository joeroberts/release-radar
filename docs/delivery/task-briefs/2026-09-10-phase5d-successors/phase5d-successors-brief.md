# Phase 5D — Successors and carried obligations

## Objective and outcome

Deliver the [approved successor/carry-forward slice](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md#remaining-phase-5-delivery-sequence--2026-09-09)
through Phase 5C's saved proposal, explicit owner approval and atomic apply path.
Retain originals/history on withdrawal, replacement and splitting; create explicit
new incomplete successors; preserve goal obligations until explicit reconciliation
or drop. No automatic goal acceptance, phase completion or external-run stop.
No new product-choice approval is outstanding.

## Scope and exclusions

Include retirement with mandatory reason (withdrawn/replaced/split), explicit
successor links, Backlog moves and membership changes, bounded dependency
reconciliation, stable obligations and explicit carry/drop. Replacement names one
new successor; split names at least two. New successor IDs must be absent in the
baseline and created in the same atomic package. They start unplaced or Backlog
with new Active/Pending tasks; no completion, acceptance, execution links or
notification credit is copied. Inherited evidence is provenance, not completion.
Accepted originals remain immutable; follow-up references cannot retire them.

Cover ALL existing loss paths, not only proposal operations: Backlog phase moves,
plan unassignment/reassignment and accompanying goal supersession. There is no
placed-to-unplaced operation to add. Preserve existing Backlog-only move rules and
Active-goal supersession prohibition. Full phase lifecycle belongs to Phase 5E;
no sixth lane, general change engine, broad History/Goals screen, execution engine,
portable exporter/importer, consumer/runtime work or unrelated refactor.

## Dependencies and accepted contracts

Start from local `dcfc709ca5d53373e59c9cc2235d9668b4ff5df0` plus this committed
handoff. This preserves independently passed shared and Phase 5C source, which
remain unpublished. Read [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md), the
[goal design](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md)
and [dashboard design](../../../design/agent-driven-delivery-dashboard-design.md).
Chief consultation `01a08988-2e67-72f2-b682-3ac707e5a37f` identified the concrete
loss/gate/recovery boundaries below; it created no files or runtime state.

- Persist ticket lifecycle separately from lane. Keep original ID, outcome, phase,
  last lane, task definitions/completions, evidence/reference identities, links and
  audit. Retired originals cannot execute or be edited through affected upsert,
  task/completion/review/reference/association writers. Guard both old and new owner
  when an existing association ID could be rehomed. Runtime observations may still
  truthfully change; retirement neither requests nor asserts external cancellation.
- Persist stable goal-owned obligation identity distinct from current assignment
  and historical assignment events. Maintain at most one current goal per ticket
  and same-phase goal membership. Readback distinguishes uncovered, required work
  coverage, carried successor obligations and explicitly dropped scope, preserving
  original goal/ticket/scope plus approved reason/provenance.
- Cross-phase carry uses explicit lineage between phase-owned obligations, never
  cross-phase membership or duplicate credit. Every required split descendant must
  resolve. Reject cycles, cross-project links, reused terminal credit and conflicting
  resolutions. Reassignment cannot resolve old debt implicitly; goal-definition
  edits/supersession cannot erase its scope/history. Existing loss paths leave prior
  debt uncovered unless they consume exact approved reconciliation.
- Drop names exact outstanding obligations and a nonblank reason through an approved
  proposal. It means intentionally removed scope, never Delivered or Accepted, and
  changes no goal lifecycle. Preserve non-vacuous acceptance: required coverage must
  resolve, required leaf work must be Accepted under existing task/evidence gates,
  and owner acceptance remains explicit. All-dropped work cannot count as delivery.
- One store-owned coverage assessment serves readiness, goal acceptance, dependency
  eligibility and later E. Ready can recognize explicit carried coverage and already
  delivered work without requiring local upcoming membership; uncovered/unassessed
  coverage remains actionable. Incoming ticket dependencies on retired work stay
  blocked until explicitly retargeted/removed in the approved proposal; no automatic
  successor substitution. Phase prerequisites consider obligation resolution and
  remaining required acceptance, avoiding permanent retired-row blocking and empty
  count success. Retain dependency before/after history.

## Proposal, authority and recovery integration

Extend existing immutable PlanChangeOperation/version/diff/decision/apply. Baseline
and stale categories include lifecycle, obligations, lineage/reconciliation and each
evidence/association fact used by preview or eligibility. Freeze relevant association
identities, not volatile runtime observations. Source impacts include originals,
successors and both dependency/coverage ends. Validate complete proposed graph,
same-project ownership, cycles and deterministic ordering before atomic commit.
Preserve Phase 5C current-source preflight, exact admission/version/decision binding,
audit/application/receipt atomicity, stale refresh/reapproval and single-effect replay.

Agents save/read only; decision/apply stays trusted owner-app and is checked before
replay. Narrow started-assignment detachment/drop exceptions require an internal
validated application context, never caller actor/approved Boolean or an ordinary
revision command. Existing safe operations gain no unnecessary approval gate.

Add schema 22 after 21. Current assignments are evidence for initial current coverage;
create no inferred successors, approvals, historical drops or transfers. Historical
loss events do not each become an assumed debt: mark affected coverage unassessed
where current facts cannot establish resolution and require explicit reconciliation.
Never reopen Accepted history. Preserve new lifecycle/obligation/lineage/provenance
through relaunch, archive/restore, removal/reset retained history and older-backup
reconciliation. Do not tie retained obligations to live proposal rows that recovery
removes. Backup registration rotation invalidates approvals as live authority;
re-add cannot reconnect old lineage. Future portable representation must carry all
new facts; no v1 semantic change or exporter/importer implementation here.

## Native workflow and direct verification

Extend the existing Plan proposal inspector with complete before/after retirement,
last-lane, successor, obligation and dependency sections plus retained-ticket access.
Show uncovered, carried, dropped and delivered distinctly in Plan/board/detail counts
and recovery guidance. Keep original task/evidence access truthful and read-only.
Use current RDS and [Phase Board](../../../design/mockups/phase_board.png) /
[Dependencies](../../../design/mockups/dependencies.png); verify actual native
wide/compact behavior and keyboard/AX navigation rather than source alone.

Test first with repository-native policy/proposal/bridge/store/recovery/projection
and native tests. Direct cases: withdraw with no successor; replace; split; same-
and cross-phase carry; every existing loss path; explicit reasoned drop; partial
child completion; goal definition/supersession; source-plan re-finalization with no
upcoming work; phase/ticket dependency gates; Accepted and retired-writer/rehome
rejection; wrong origin before replay; stale source/evidence/coverage; conflicting
replay/concurrent apply/late rollback; migration unassessed history and all recovery
paths. Assert actual state changes and no unintended graph/audit/receipt writes.

Native journey: inspect → approve → relaunch → apply → original/successor → retained
tasks/evidence, with uncovered/drop/carry readback, stale refresh/rejection/lost-reply
recovery, exact Back/Forward focus and wide/compact count agreement. One successful
case cannot substitute for materially distinct drop/lineage/security boundaries.
Use focused suites; no custom validation framework or recursive review.

All build/test/native launches require exact orchestrator reservation. Reuse verified
sanitized env-i, isolated XCTest/AppLaunchConfiguration/default-service suppression
and successful no-signing settings. Pre-existing owner app is protected; never
launch, stop or control it. No real service registration, credentials or owner state.
Use actual fixture path/bookmark equality under the security reader; preserve all
raw outputs and generated fixtures, no cleanup. Host reads interaction markers only;
external controller owns them. Canonical screenshots/evidence belong in repository.

## Assignment, review and endpoint

Orchestrator `01a086bd-7970-70f0-80e8-8c044ee8ef4a` owns catalog/indexes/progress
and integration on local `codex/phase5d-orchestrator`. One fresh Sol High writer owns
related source/tests, this brief, required ADR/design detail and canonical evidence;
Astra High ceiling for named unresolved issues, never Ultra or unapproved xhigh/max.
Persistence/recovery, cross-feature coverage and authority justify that profile.
Fresh independent Astra High review covers those risks and native QA in one bounded
candidate review; only Required findings block. Exact baseline/task supplied at
dispatch. No implementer self-review substitution or additional review layers.

Complete local implementation, direct checks, required corrections, canonical docs
and scoped LOCAL commits. **No push/PR of inherited shared+C/D commits without
explicit owner publication authorization; every merge remains separate.** No
installation, app state/binding/catalog acceptance, direct owner SQLite, consumer
adoption, runtime pilot, notifications or cleanup. Preserve named branches before
archiving; report raw paths and process quiescence. E consumes this canonical
coverage assessment for explicit guarded full lifecycle, without treating Ready,
zero current tickets, dropped scope or successor creation as phase completion.
