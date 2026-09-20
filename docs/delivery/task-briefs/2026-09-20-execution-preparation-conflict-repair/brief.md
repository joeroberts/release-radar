# Execution preparation conflict diagnostic and bounded recovery repair

Current authorization and runtime state remain in
[the delivery ledger](../../progress.md). Main owns that ledger. This brief owns
only the isolated source/test/documentation candidate described below.

## Shared execution context

- **Standard:** `shared-execution/1`. Installed Release Radar plugin `0.1.30`
  exposes the compatible v1 skill. Sol/high was requested for this writer, but
  effective model/effort are not exposed and must not be inferred. CodeGraph
  discovery was attempted first; the checkout contains only an uninitialized
  `.codegraph` stub, so narrow local symbol reads are used instead.
- **Root:** `/Users/jroberts/.codex/worktrees/8e4c/release_radar`, detached at
  baseline `0ebbe7c5b5fbf44921285b491813858a43e1da6a` (`exactRevision` before
  this correction). Build Agent owns attaching the scoped
  `codex/execution-preparation-context-repair` branch for the local commit. The
  registered application root remains
  `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`; this task
  must not mutate that application registration or owner state.
- **Outcome:** let the existing audited no-effects recovery path terminally
  refuse only a closed-parent preparation whose app-selected context is missing,
  while preserving every unreadable, partial, live or otherwise uncertain case.
- **Scope:** `ProjectExecutionAssignmentCoordinator` only, focused producer and
  dispatcher regressions, and this brief. The correction classifies only
  `RepositoryDocumentError(.missingFile)` from the parent context read before
  assignment creation; it adds no overlay, permission change, schema, public
  contract, diagnostic kind or generalized recovery mechanism. Main retains the
  canonical ledger, live exact replay and later product integration. Build Agent
  task `01a0c061-578a-7e22-8ba3-77348fd6dcac` owns all compilation, RED/GREEN
  runs and the scoped local commit; this writer owns brief/source/test edits and
  does not compile or commit.
- **Authority:** owner delegation for this isolated repair; catalog artifact
  `450e84de-703b-4dcd-ad1a-f711ae82bd5a` at ledger commit `67236e19` for the
  exact blocked request; `rr-outcome3-execution-setup-brief-2026-09-16` for the
  existing preparation-recovery contract;
  `rr-shared-execution-integration-v1-design-2026-09-09` for shared execution;
  ADR-001 for application/state boundaries and ADR-005 for retained task
  history. Accepted ADRs are immutable.
- **Endpoint:** one reviewed local commit containing the bounded repair,
  focused tests and applicable documentation. No push, PR, merge, packaging,
  installation, owner acceptance, Release Radar mutation, live replay, board
  change, permission/configuration change or artifact cleanup.
- **Direct checks:** Build Agent first runs the new missing-context regression
  RED, then after the source correction runs that selector GREEN plus only the
  relevant existing no-effects, uncertainty, exact-replay and changed-body
  regressions, repository documentation validation and `git diff --check`.
  Results identify the exact candidate revision, runner, scope and limitations.
- **Review:** one fresh independent reviewer after an immutable candidate covers
  recovery/authority, receipt and audit preservation, public diagnostic safety
  and actionable user guidance. UI QA is required only if presentation changes.
  A public contract or persistence-boundary decision requires chief-architect
  direction before implementation; no new schema or generalized recovery engine
  is authorized.

## Scope, exclusions and risks

The supported live result for the exact request is a missing app-selected context
file in closed candidate `6ba3ce8e`. That result does not expose the durable receipt
disposition. Current source implies an unchanged `outcomeUnknown` result because a
generic repository-document error bypasses the existing terminal-refusal branch;
this remains source inference until Main performs supported readback or exact replay
after a reviewed installed repair.

The missing-file read occurs after the closed parent candidate is selected but
before request-owned assignment, worktree/branch/provisioning or profile creation.
Code position alone is not no-effects proof. The existing verifier must additionally
prove the deterministic assignment and all provisioning resources absent, the
worker profile absent, the exact single-flight still owned, and the parent still the
same-registration, same-work, closed, non-retired eligible delivery assignment.

Preserve the original request ID/body and all uncertainty/audit history. Never
delete or rewrite a receipt, synthesize success, change request identity, retire
a resource, replay live effects automatically, weaken root/registration/revision
checks, or treat an absent assignment alone as proof of no effects. Live,
reserved, partially prepared, unreadable, resource-present or otherwise
uncertain states remain pending and block replacement. Only authoritative
request-scoped proof that assignment, worktree/branch/provisioning and profile
effects are absent may reach the existing normal audited terminal-refusal path.

The exact blocked request is preserved unchanged:

```json
{"version":1,"projectRoot":"/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar","projectID":"project-fffdc0e0b15b9b86","registrationID":"8edc840e-2847-4eeb-af68-282d5ed12b11","registrationProjectID":"project-fffdc0e0b15b9b86","requestGeneration":1,"requestID":"154c4774-9565-4fa9-8cff-bbccf3a908cb","ticketID":"rr-p6-manage-project","taskID":"rr-p6-manage-project-task-01","expectedPhaseRevision":1,"expectedTaskPlanRevision":1,"reviewOfAssignmentID":"delivery-7cd1c166-73e5-4c9a-b062-a6553878c55b","reason":"Independent UX and recovery review of committed Manage Project task01 candidate 6ba3ce8e after four focused runtime passes. Delivery connection closed; preserve later relocation scope."}
```

## Test strategy and acceptance

Tests are authored before product changes. The causal regression uses a closed
same-work delivery parent whose committed candidate lacks one app-selected context
path. RED must show that this exact failure cannot enter the existing no-effects
terminal path. GREEN must prove the coordinator returns the existing typed
no-effects candidate only for `missingFile`, the verifier accepts only the exact
eligible closed parent after proving every request-owned effect absent, and the
dispatcher atomically stores an audited `assignmentNotAuthorized` result.

The same test boundary proves identical replay returns the stored audit without a
second preparation, changed-body reuse rejects, and a fresh same-role/task request
is no longer blocked only after terminal settlement. Focused existing negatives
must keep resource-present, profile-present, mismatched parent/registration/work,
unreadable proof, partial preparation, live/reserved and failed-CAS cases uncertain.
Other repository-document errors are unchanged. No test or code may mutate the
preserved parent candidate, private receipt state or live Release Radar state.

Acceptance is one reviewed local source/tests/brief commit. The original request
body and target remain unchanged; Main alone may later exact-replay it against an
installed repair. An audited terminal refusal, if returned, permits Main to abandon
the obsolete exact-`6ba3ce8e` review while preserving its branch and artifacts, then
integrate the already-authorized Manage Project behavior onto current main and use a
fresh truthful review request. No old request may be retargeted or reworded.

## Approved diagnostic contract

Chief architecture approved one additive optional
`AgentCommandResult.preparationDiagnostic` with default `nil`; existing
`execution.conflict`, entity/audit semantics, envelope version and replay
contracts stay unchanged. Its typed kind is one of `pendingPreparationRequest`,
`preparationInProgress`, `blockingAssignment` or `causeUnavailable`, with one
optional directly proven request or assignment witness and evidence classified
as `observedAtFailure` or `recordedFailure`. It contains no free text, request
body/reason, path, prompt, content, session/account detail, raw error or recovery
action. One observed blocker is not an exhaustive inventory and removing it does
not imply eligibility.

The receipt guard may expose an ID only after exact root, current registration
and generation, project, ticket, task, revisions and role are validated. The
single-flight guard exposes no request ID because its current key does not prove
role/registration. The assignment guard exposes only its verified matching
assignment witness. Other conflicts are `causeUnavailable`; absent legacy
detail is never reconstructed. The internal diagnostic carrier remains distinct
from the no-effects candidate, creates no receipt/audit, settles no uncertainty,
releases no other gate and performs no provisioning/configuration. Stored
diagnostics replay as recorded evidence without rewriting history; old JSON and
unrelated results decode with `nil`. No query, schema, UI or recovery engine is
part of this task.

After installed `0.1.28` returned an observed `causeUnavailable` for the exact
preserved review request, chief architecture approved one further additive,
optional `stage` only for that kind. Its closed values are
`parentCandidateValidation`, `targetProvisioning`,
`preparedAssignmentConfiguration`, `assignmentStoreIntegrity` and
`assignmentStoreCompareAndSwap`. Capture the narrow failing site and preserve a
nested store stage through broader wrappers; do not infer a last-reached stage,
parse error text, attach a stage to known blocker kinds, or route the diagnostic
through no-effects settlement, receipt commits or gate cleanup. Legacy payloads
decode with `stage == nil`; recorded replay changes only evidence classification
and never rewrites the stored receipt. The field discloses no paths, content,
raw errors or recovery instructions.
