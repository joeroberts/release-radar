# RR-R10 Task 8: Audited Delivery Goal commands

## Objective and outcome

Expose the three audited commands and matching MCP tools defined by
[Task 8](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-8-expose-audited-delivery-goal-commands),
using the accepted [design](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md)
and [ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md).

## Scope and exclusions

Add applyPhasePlanRevision, finalizePhasePlan and transitionDeliveryGoal to
AgentCommand and AgentCommandDispatcher; add their three tools in
ReleaseRadarAgentTools/main.swift and optional phasePlanRevision results.
Route all mutations through Tasks 6–7 policies in the existing transaction.
Use the existing model records and additive typed planning errors; preserve
all 21 existing schemas, MDCP behavior and old encoded results/receipt bodies.
Update bridge/transport tests and required brief/catalog/index/ledger records.
The additive errors also require bounded recovery text in the exhaustive
AgentCommandError switch in ReleaseRadar/Shared/FailureStateView.swift and
focused presentation assertions. Update the existing documentation callback
tool-count assertion to 24. The coordinator accepted these necessary support
changes under existing authorization.
No migration, dependency, Task 9/10 feature, owner installation, shared-service
registration change, UI repair, or cleanup is included.

## Dependencies

Task 7A PR #10 merged at 979926be37609b9f52c5588d238bc8f34753361b; the
coordinator independently verified it and released the caller hold. The
owner authorized Task 8 planning, implementation, validation, independent
review, commit, push, one PR and merge on codex/rr-r10-task-8. Routine
sequencing decisions are delegated to coordinator
01a06184-6387-7c42-878e-695db0481a18. Preserve the old dirty bound checkout.

## Material risks

Trusted origin must authorize owner acceptance before either mutation or
receipt replay. For lifecycle replay, decode the stored result audit ID and
require the authoritative persisted audit actor association to match the
supplied owner/agent origin; reject missing or mismatched association before
returning any stored result. Do not add origin to canonical receipt bytes.
Keep MDCP authorized replay before current catalog validation unchanged.
Rollback must cover goals, assignments, plans, audit and receipt together.

## Test strategy

Write failing native XCTest cases, then implement the bounded command path.
Use synthetic stores and inert native hosts; run focused bridge tests and
safe individual transport selectors, plus a Debug build and repository-native
DocumentationTool write/check. Do not run whole shared-service classes or a
full scheme. Test actual commands, stored receipts and audits, packaged helper
schemas and input rejection before transport. One qualified independent
reviewer covers the material implementation and documentation while the
coordinator inspects scope/sequencing. Keep temporary logs and test output in
.build/rr-r10-task8 and existing synthetic test directories; retain them.

## Acceptance criteria

- All three commands round-trip and return the exact committed phase-plan
  revision; old result fields remain omitted when absent. The helper exposes
  all 24 tools, with prior 21 schemas unchanged and only awaiting_acceptance
  allowed by the external lifecycle schema.
- Exercise aggregate 64 goal/512 assignment operation limits and sorted-key
  AgentCommand byte boundaries 65,535/65,536/65,537. Omitted arrays do nothing;
  empty, malformed, cross-phase and stale operations fail without writes.
- Finalization returns actionable incomplete-plan details; stale and current
  Draft lifecycle requests reject. Coupled lifecycle transitions cannot be
  requested independently. External acceptance rejects; ownerApp acceptance
  succeeds without changing ticket lanes or structural revision.
- Same-origin replay returns the original result after relaunch and writes
  once. Cross-origin request-ID reuse, missing/mismatched audit association,
  and changed-body reuse reject without returning the stored result.
- Directly verify transaction rollback, one authoritative audit/receipt and
  assignment-event attribution to every affected ticket. Preserve MDCP replay
  and existing task command compatibility through focused regression checks.
- After direct checks and independent review, commit/push the reviewed
  implementation. Use the installed completeTicketTask route at a freshly
  read exact live revision, preserve its request on uncertainty, and read back
  the checked rr-r10-task-8 row, revision/audit, 16 active rows and unchanged
  ticket lane/goal state. Record that result and close this brief/catalog in
  the same branch before the single Task 8 PR is merged. Development catalog
  changes remain pending later authorized bound-root deployment/acceptance.

## Risk-triggered reviews

One independent reviewer covers Code/QA, Architecture, Security/Privacy and
documentation, focusing on command/transaction and trusted-origin replay
boundaries. Coordinator scope/sequencing inspection is under owner delegation.
No review of reviews or additional generic approval gates. Preserve Task 5's
physical keyboard, spoken VoiceOver and native macOS Dynamic Type limits.
Issue #9 remains owner-deferred. The coordinator owns dispatch after Task 8.

This brief is completed and non-authoritative. The scoped native checks and
independent review completed with no Required findings. The exact live Task 8
completion returned revision 13 and audit
`25B157F9-1877-487C-A0B3-CE198AD70528`, with identical replay and complete
preservation readback. The [progress ledger](../../progress.md) records the
current outcome and pending deployment boundary. Source, tests and delivery
documents are durable repository artifacts; private live requests/readbacks
are retained in the protected owner-designated companion location. Build/test
outputs remain temporary and retained; no cleanup is authorized.
