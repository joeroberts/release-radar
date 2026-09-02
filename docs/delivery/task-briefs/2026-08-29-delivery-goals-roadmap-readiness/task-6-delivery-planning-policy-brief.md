# RR-R10 Task 6: Delivery Goal plan and lifecycle policy

## Objective and outcome

Implement the current [Task 6](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-6-enforce-delivery-goal-plan-and-lifecycle-rules)
using the accepted [ADR-004 contract](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md)
and [design state machines](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md).
The coordinator accepted this brief and initial sequencing on 2026-09-02 under
owner delegation before implementation.

## Scope and exclusions

Create `DeliveryPlanningPolicy.swift` and its focused acceptance tests. Provide
`PhaseCreationMode`, `applyRevision`, `finalizePlan`, `transitionGoal`, and typed
plan/goal/criterion/assignment/history readers using unchanged v11 models and
schema. Policy writes execute inside the caller's existing store transaction,
with private SQL mutation helpers and one supplied phase-plan audit identity.
No new bridge command, general ticket writer routing, schema, UI, installation,
owner data, live catalog acceptance, or shared service mutation is included.
Task 7 owns phase/ticket writer routing; Task 8 owns command exposure and its
65,536-byte sorted-key AgentCommand envelope boundary. This slice enforces
64 goal operations and 512 assignment operations directly in Core.

## Dependencies

Task 5 merged as PR #6 at 2026-09-02T11:35:34Z (`cdc3e6e`). Work uses isolated
branch `codex/rr-r10-task-6` from that merged default branch. Accepted Task 1B
v11 types/schema, v12 task policy, v13 store transactions and current dispatcher
origin remain unchanged. Preserve the separate old/dirty bound checkout and
live 0.1.6/schema-v13 baseline. Estimated implementation is one coherent
policy/test review, under eight agent hours.

## Material risks

Structural edits must advance exactly once, invalidate Ready, preserve terminal
history, and roll back with their audit. Ready requires complete non-superseded
goals, nonempty coverage and exact phase-local assignments. Lifecycle requests
must require current Ready even when their expected revision is current.
Owner acceptance uses the existing trusted `AgentCommandOrigin`, never actor
text. Migration adoption is explicit and atomic: only a migration-continuation
In-progress/Needs-review ticket newly assigned to one Draft goal may activate
that goal at finalization, set `activated_at`, and clear continuation. No inferred
membership, retroactive Accepted assignment, regrant, or standalone activation.

## Test strategy

Write failing XCTest cases before policy code. Use synthetic temporary stores
and copies of the accepted v10 fixture to exercise real migration continuation.
Run only DeliveryPlanningPolicyAcceptanceTests, TicketTaskPlanningPolicyAcceptanceTests
and StoreAcceptanceTests with the inert XCTest host; none invokes shared broker
or lifecycle services. Use native Debug build-for-testing and focused test
selectors, repository DocumentationTool check/write, and `git diff --check`.
Retain `.build/rr-r10-task6` build/test output and synthetic fixtures; no cleanup.
No Task 5 UI test repetition or live application inventory is authorized.

## Acceptance criteria

- Cover Legacy/Draft/Ready revisions, optimistic conflicts, empty/contradictory
  operations, omission preservation, and goal/assignment limits at N-1/N/N+1.
- Finalization rejects empty, uncovered, incomplete, cross-boundary or
  non-actionable plans; promotes Draft goals atomically; ignores delivery
  blockers/dependencies for structural readiness. Previously Ready completed
  delivery stays Ready without a new revision.
- Preserve assignment history linked to one audit/revision. Reject transfers
  or removal after work starts, retroactive Accepted assignments, terminal
  definition edits, and supersession except unstarted Draft/Planned goals with
  every assignment explicitly removed/transferred in the same revision.
- Exercise all goal lifecycle pairs: only Active to Awaiting acceptance and
  owner-origin Awaiting acceptance to Accepted are standalone transitions,
  with current Ready and all assigned tickets Accepted. No ticket lanes or
  task-plan revisions change. Required acceptance evidence uses existing
  product records: any linked child-ticket evidence marked unavailable blocks
  the transition; no linked evidence adds no new requirement. The coordinator
  confirmed this interpretation under delegation before implementation. No
  filesystem/network scan or inferred done-criteria evidence requirement.
- Prove narrow explicit migration adoption for both continuing lanes, zero/
  multiple/invalid assignment rejection, only the assigned goal activating,
  timestamp persistence, continuation clearing, and no free activation.
- Verify rollback after partial writes and audit failure, persisted readback,
  no task-table reads in planning operations, and existing task-only
  non-invalidation. Obtain required independent review with no Required finding.
- Commit, push, create and merge a PR into `codex/release-radar-mvp`; report
  actual integration to the coordinator and stop before Task 7.

## Risk-triggered reviews

One independent code/QA reviewer covers behavior and documentation; include
Architecture coverage for lifecycle/transactions/adoption and Security/Privacy
coverage for owner-only acceptance. The coordinator provides delegated brief
acceptance and initial sequencing review. No review of reviews or extra matrix.
Catalog/index changes remain repository-prepared, pending separately authorized
bound-root deployment and acceptance; no managed-current claim is made.

This completed brief is retained as non-authoritative delivery history. The
[progress ledger](../../progress.md) records direct checks and independent
review. Code/QA, Architecture and Security/Privacy review closed the byte-exact
identity correction after both regressions and all 19 policy tests passed.
The successful 50 Store and 32 Task policy tests were not repeated. No Required
finding remains. PR integration is authorized; Task 7 opens only through the
coordinator after merge verification.
