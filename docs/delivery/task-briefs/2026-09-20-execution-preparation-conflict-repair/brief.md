# Execution preparation conflict diagnostic and bounded recovery repair

Current authorization and runtime state remain in
[the delivery ledger](../../progress.md). Main owns that ledger. This brief owns
only the isolated source/test/documentation candidate described below.

## Shared execution context

- **Standard:** `shared-execution/1`. Installed Release Radar plugin `0.1.28`
  exposes the compatible v1 skill. Effective model/effort are not exposed to
  this task and must not be inferred. CodeGraph discovery was attempted first;
  the checkout contains only an uninitialized `.codegraph` stub, so the tool
  reported no available index and narrow local symbol reads are used instead.
- **Root:** `/Users/jroberts/.codex/worktrees/reviewer-preparation-stage-repair/release_radar`,
  branch `codex/reviewer-preparation-stage-repair`, baseline
  `5d15676d54fb6fb03abd69b3fd1df373e643fafe` (`exactRevision` before this
  correction). The registered application root remains
  `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`; this task
  must not mutate that application registration or owner state.
- **Outcome:** identify the exact supported cause of the repeated review
  preparation conflict, expose an actionable bounded diagnostic, and correct
  only the demonstrated no-effects recovery defect while preserving uncertain
  outcomes, receipts and audit history.
- **Scope:** execution-preparation dispatcher/coordinator and the smallest
  existing public diagnostic surface needed to distinguish a pending prior
  receipt, protected assignment reservation, or active in-process settlement;
  focused repository tests; this brief and any owning mutable execution design
  update required by the final contract. Main retains the live retry and
  canonical ledger. Build Agent task `01a0b55a-56ad-71c1-a93c-4552cf69514a`
  owns compilation and RED/GREEN runs; this writer owns the scoped source,
  tests, brief update and local commit in the isolated checkout.
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
- **Direct checks:** Build Agent runs focused dispatcher/coordinator tests first
  RED then GREEN, relevant existing replay/authority regressions, repository
  documentation validation and `git diff --check`. Results must identify the
  exact candidate revision, runner, scope and limitations; this writer does not
  compile.
- **Review:** one fresh independent reviewer after an immutable candidate covers
  recovery/authority, receipt and audit preservation, public diagnostic safety
  and actionable user guidance. UI QA is required only if presentation changes.
  A public contract or persistence-boundary decision requires chief-architect
  direction before implementation; no new schema or generalized recovery engine
  is authorized.

## Scope, exclusions and risks

The source currently maps several causes to `execution.conflict`: an earlier
same-role/same-task `outcomeUnknown` receipt, an in-memory preparation key, and a
protected same-role reservation. Restart excludes only a stale process-local key.
Supported Worker resources reports no same-task review assignment, making a
prior receipt the leading hypothesis, not a proven fact. The implementation must
use a supported typed diagnostic or failed-command result to establish the cause;
it must not inspect or edit private SQLite, receipts, assignment control files or
profiles directly.

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

Tests are authored before product changes and cover: diagnostic distinction for
prior pending receipt versus durable resource reservation versus active
single-flight settlement; exact request/body/registration/work/role scoping;
no disclosure beyond the authorized request; no-effects historical recovery;
resource-present, unreadable and partial-effect cases remaining pending; failed
resolution commit preserving `outcomeUnknown`; exact terminal replay returning
the stored audit without preparing again; changed-body reuse rejection; fresh
replacement remaining blocked until a terminal audited result exists; and the
existing live/unknown/revoked authority protections.

Acceptance requires the supported diagnostic to identify the synthetic cause
without private-state access and provide one actionable next step. The repair
must settle only a proven no-effects request through an atomic audited
transition, preserve all original identity/history, and leave every uncertain
case blocked. The exact live Release Radar cause and recovery remain unclaimed
until a separately authorized installed candidate returns supported typed
readback for the preserved envelope.

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
