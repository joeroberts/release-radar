# RR-R10 Task 5: Ticket task presentation

## Objective and outcome

Present canonical ticket tasks on the existing five-lane Phase Board and in
Ticket Details, using the approved [Ticket Tasks contract](../../../design/release-radar-ticket-tasks-design.md)
and [Phase Board reference](../../../design/mockups/phase_board.png).
The [Task 5 plan](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-5-present-ticket-tasks-on-cards-and-ticket-details)
controls the full outcome. The owner authorized implementation and PR delivery
through coordinator task `01a06184-6387-7c42-878e-695db0481a18`.

## Scope and exclusions

Change DashboardProjection, TicketCardView, PhaseBoardView, TicketDetailView,
DashboardProjectionTests and hosted AppRoute UI tests, plus this
brief, canonical runtime evidence, catalog/index metadata and the existing
progress ledger. The coordinator accepted this brief on 2026-09-02 under owner delegation,
including two supporting paths: expose the existing bounded read-only
SQLiteConnection.rows reader without semantic changes, and correct AppModel.reloadAfterActivePhaseSelection for idle or prior failure
while preserving phase-save, savedNeedsReload and existing error behavior. No schema, task mutation policy,
MCP/tool contracts, evidence semantics, owner installation/data, live catalog
acceptance, shared service operation, Issue #1 or held Issue #2 change.

## Dependencies

Task 4B merged through PR #5 (`ed630dd`). Use branch `codex/rr-r10-task-5`
based on that current remote base. Preserve the owner's separate checkout.
Schema v13, the 21-tool API, receipts and all historical manifests remain
unchanged. Task 6 opens only through the coordinator after Task 5 merges.

## Material risks

A failed task read must discard stale rows/counts while preserving usable
board data. Cards and Details must derive from the same active collection.
Narrow cards must preserve identity, blocker/dependency/task metadata and the
48-point target; long task text must wrap and scroll accessibly. Runtime
verification must suppress normal startup and isolate synthetic store data
and the running application from the owner's normal app and fixed broker.
Use the existing inert XCTest host and NSWindow/NSHostingView pattern with
synthetic data and actual PhaseBoardView in AppRouteTests. The empty standalone
UI target and scheme need no ceremonial change. No new verification framework.

## Test strategy

Write failing focused projection and AppRoute/UI acceptance tests, then
implement the smallest change. Verify tri-state distinction, deterministic
ordering, superseded exclusion, count synchronization and completion stability,
per-ticket failure isolation, recovery through the PhaseBoard reload callback,
read-only row accessibility and card semantics. Use native Debug/test builds,
focused safe selectors, documentation check and diff check. Do not repeat
Task 4B transport/lifecycle validation or run unfiltered shared-service suites.
Inspect one isolated running UI at wide and compact widths, keyboard and
VoiceOver/accessibility, increased contrast and Dynamic Type at both widths,
metadata order, long wrapping/scrolling and all three task states. Persist
accepted evidence under `docs/delivery/evidence/` and register it in the catalog.

The [verification record](../../evidence/2026-09-02-rr-r10-task-5-ui.md)
contains the direct results and canonical wide/compact evidence. Apple's
documented native macOS Dynamic Type limitation is recorded explicitly;
identical environment-size renders are not claimed as enlarged-text proof.
Physical keyboard activation and spoken VoiceOver navigation remain
unverified because the current UI tool could not reliably deliver those
inputs to the isolated host. On 2026-09-02 the coordinator explicitly accepted
Task 5 under owner delegation with these residual risks and the native macOS
text-sizing limitation, releasing commit/push/PR/merge. This records delegated
acceptance, not personal human inspection or passing keyboard/VoiceOver checks.

## Acceptance criteria

- Explicit noPlan, loaded(plan:) and unavailable(recovery:) projections; only
  loaded supplies rows and a card count from the same canonical active list.
- Neutral active count, singular/plural accessibility, no completed/total
  fraction or task action, and stable count after completion.
- Read-only Tasks rows announce label, complete title, checked/unchecked and
  item position. No-plan and unavailable remain distinct and recoverable.
- Preserve five lanes, existing evidence/relationships and compact hit target.
- Direct checks and independent QA/UX pass, with concrete runtime evidence.
- Coordinator explicitly accepts the UI under owner delegation before any
  Task 5 path is committed. Record this accurately, without claiming personal
  human inspection. Then commit scoped paths, push, create and merge a PR to
  `codex/release-radar-mvp`, verify merge and report to the coordinator.

## Risk-triggered reviews

Independent QA/UX reviews the implementation, running UI, accessibility,
recovery and concise documentation. Include architecture/security coverage for the exposed Core/app read-only
reader boundary; no additional review matrix applies. Coordinator accepts the brief
and the final concrete UI package under the owner's delegated authority.
Repository catalog changes remain prepared/pending later authorized deployment
and acceptance; no managed-current claim is made for this worktree.

This completed brief is retained as non-authoritative delivery history. The
existing progress ledger controls current task status and sequencing.
