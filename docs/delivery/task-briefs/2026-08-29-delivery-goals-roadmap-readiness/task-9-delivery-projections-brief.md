# RR-R10 Task 9: Delivery Goal projections

## Objective and outcome

Completed 2026-09-02; this brief is historical and non-authoritative. The
implementation is pushed at `e0a8cf599e1e369fa1706bef0c6cd445bed160e4`;
39 focused tests, Debug build, documentation checks and independent review
(Required 0) passed. Typed live Task 9 completion committed revision 14, audit
`5C1345DD-5C85-4E91-8872-633344653DA5`, with exact replay and preserved unrelated
state. See the [current delivery state](../../progress.md) for the merge checkpoint.

Implement the complete read-projection outcome in
[Task 9](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-9-project-delivery-goals-activity-and-owner-review),
under the accepted [design](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md)
and [ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md).

## Scope and exclusions

Change DashboardProjection, ProjectActivityProjection, ReviewInboxProjection
and their DashboardProjectionTests/ReviewAndGraphAcceptanceTests.
The coordinator also approved one AppModel.swift initializer argument to retain
derived goal attention when an unrelated review decision saves but refresh fails.
Produce PhaseBoardKey, PhasePlanProjection, DeliveryGoalSummaryProjection,
TicketDeliveryGoalProjection and DeliveryGoalAcceptanceReviewProjection.
Load every project/phase board, retaining board(for:) for active-phase callers
and adding board(for:phaseID:). Reuse existing policy reads and authorized
evidence readbacks. Keep five lanes and stable goal/unassigned filters, exact
upcoming coverage, completed-delivery and legacy-continuation distinctions.
Activity retains one authoritative audit with relational assignment attribution;
the inbox derives stable Awaiting-acceptance entries without writing review rows.

No new persistence, migration, dependency, harness, observed-goal or notification
semantics, browsing/acceptance UI, installation, catalog acceptance, service
registration, Issue #9 repair or cleanup. Task 10 owns controls and owner actions.

## Dependencies

Task 8 PR #11 merged at 41daf211de8e5d7fbacce794d12f5df98d515093 and was
independently closed by coordinator 01a06184-6387-7c42-878e-695db0481a18.
The owner authorizes this checkpoint through planning, test-first implementation,
validation, independent review, commit/push, exact live completion, same-branch
reconciliation and one PR/merge on codex/rr-r10-task-9. Ordinary scope/sequencing
decisions are delegated to the coordinator; test-first work may proceed while
that review runs. The old dirty bound checkout remains untouched.

## Material risks

All-phase loading must not change the active pointer or Overview counts, confuse
project/phase/goal identities, drop Task 5 rows/counts, or lose managed/legacy
evidence identity, lifecycle, authority, availability and recovery. Review items
must not duplicate across replay, survive failed transitions incorrectly, or
remain after successful acceptance/rework. Projections never authorize acceptance.

## Test strategy

Write failing native projection/review tests, then implement the minimum read
changes. Exercise all-phase loading (including no active phase), exact coverage,
legacy/empty/completed states, stable filtering, task tri-state/count preservation,
managed null-path and legacy evidence, structured Activity attribution, lifecycle
replay/failure cleanup and unchanged observations/notifications. Run the two
focused test classes, ManagedEvidencePresentationTests and applicable existing
managed-readback tests, plus a Debug build and native documentation write/check.
Use synthetic stores and inert XCTest hosts only; no unfiltered service or full
scheme tests. Temporary outputs stay in .build/rr-r10-task9 and native test
directories, retained without cleanup.

## Acceptance criteria

- All five named projection types and both board accessors are present; every
  phase is readable without changing the persisted active phase.
- Coverage excludes Accepted history, reports unassigned upcoming work exactly,
  and distinguishes Ready delivery complete from an initially empty plan.
- Delivery Goals and linked Codex execution context remain separate; stable
  filters preserve five-lane membership and task/evidence detail.
- One plan audit exposes its affected tickets, phase, revision and originating
  task without reason-text inference or duplicate success events.
- Exactly one stable owner-review item exists per Awaiting-acceptance goal,
  with current phase revision and criteria; replay/failure/rework/acceptance
  readbacks are correct and no owner mutation or new notification is introduced.
- Direct checks and independent review pass before implementation delivery.
  Then exact live Task 9 completion and replay at the freshly established
  revision preserve the 16 rows and unrelated state; record returned revision/
  audit and complete this brief/catalog before the single PR is merged.

## Risk-triggered reviews

Coordinator reviews scope/sequencing. One independent Code/QA reviewer covers
the implementation and documentation, including the new app projection contracts
(Architecture), evidence readback/authorization preservation (Security/Privacy),
and truthful projected state wording (UX). No additional review loop is required.
Task 10 owns running UI acceptance; Task 9 claims projection correctness only.
