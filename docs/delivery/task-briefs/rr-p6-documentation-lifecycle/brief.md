# Active execution — rr-p6-documentation-lifecycle

- Plan and acceptance criteria: [GitHub issue #118](https://github.com/joeroberts/release-radar/issues/118).
- Standard: shared-execution/1; coordinator skills are readable. Required worker
  skills, capabilities and effective settings must be verified before dispatch.
  The owner requires supported operations with no fallback paths or shortcuts.
- Root: /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar.
- Outcome: clean this project's documentation and enforce its lifecycle through
  compatible repository rules and Git hooks.
- Current authorization: persist the approved plan and tracking only. Ticket is
  Backlog; implementation, deletion, rule/hook changes and worker launch remain
  unreleased. Issue creation is authorized; future dispositions and publication
  retain the approval boundaries in the full plan.
- Tracking: four original pending tasks at task-plan revision 1, suffixes
  `-task-01` through `-task-04` on this ticket ID. Their exact definitions and
  ordered acceptance scope are in issue #118 and RR. No existing ticket changes.
- Ownership: Main owns this brief, catalog registration, current ledger and
  coordination. Bounded delivery writers receive fresh RR-managed assignments;
  one writer per checkout/shared resource. No orchestrator subagents.
- Baseline: canonical `codex/doc-reconciliation`, source `08948807` before this
  tracking setup. Implementation must start from the later committed setup
  baseline returned by supported managed preparation, not this historical hash.
- Suggested delivery profile: Sol/high for retention/authority/deletion work;
  one qualified independent reviewer Sol/high for those risks. Confirm actual
  app-derived settings at dispatch. Default escalation ceiling Astra/high; no Ultra.
- Controlling local references: [repository instructions](../../../../AGENTS.md),
  [current ledger](../../progress.md),
  [managed documentation contract](../../../design/managed-repository-documentation-contract.md),
  [ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
  [ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md), and
  [shared execution](../../../design/shared-execution-integration-v1-design.md).
  Current rules remain operative until their explicitly scoped changes are approved.

## Execution order and boundaries

1. Task01 establishes rule ownership, compatible RR transitions, actual document
   dependencies and authoritative ticket/merge inputs. Classify keep, extract-then-
   delete or delete; do not reconcile or republish valueless content.
2. Task02 performs approved cleanup/relocation and coherent catalog/reference/
   manifest updates; moves the image input into test-owned fixtures.
3. Task03 implements one small checker for both Git hooks and verifies staged and
   outgoing content, real installation and coexistence with existing hooks.
4. Task04 obtains one independent review, completes authorized delivery and removes
   this directory once its ticket is closed and the work committed and merged.

Task01 must evaluate GH #55, #71, #74, #87, Guided Setup and Plan Reconstruction
for unchanged, partially superseded/completed, wholly superseded/obsolete or concrete
dependency disposition. Identify affected requirements and remaining scope; apply
approved dispositions before closeout. Do not reopen accepted reconciliation or
automatically expand into CI, connectors, knowledge products or other repositories.
Proposals require duplicate/conflict/supersession/deprecation checks before issues.
Retained studies go to the GitHub wiki; obsolete studies/proposals may be deleted.

## Risks, checks and completion

- Risks: losing unique current knowledge; breaking managed references/worker context;
  rejected catalog transitions; plugin repair restoring old rules; overwriting
  hooks; unreliable ticket/merge status; required skill access denied.
- RR attachment inventory previously returned `inventoryTooLarge`. Resolve needed
  dependencies through supported reads; do not claim absence or use SQLite access.
- Proposed ledger limits are 100 lines and 12 KiB, not currently installed rules.
- Direct checks: native documentation validation at the exact changed checkout,
  scoped diff checks, affected image-preview test, hook pass/fail cases from #118,
  supported RR readback, and affected shared-execution/plugin compatibility checks.
- Preserve stable/retired IDs and accepted ADR decision text. Any citation repair
  or shared/public contract change requires its named scope and authorization.
  Migrations and recovery implications must be settled in Task01 before writes.
- Record useful verification and limitations in the issue/PR, not this brief.
  One reviewer covers applicable authority, destructive-operation, documentation
  and hook risks. Only Required findings block; successful checks are terminal.
- Current endpoint: persisted, linked tracking and scoped local documentation
  commit. No implementation release, branch push, PR, merge or installation.
  Catalog acceptance and requirement linking use supported audited operations.
- Disposition: this directory contains active execution details only. Full plan,
  results and issue dispositions belong in #118/the implementation PR. Delete the
  directory after closed-and-merged completion, with compatible catalog cleanup.

## Current tracking baseline

Exact approved setup requests are retained for the tracking contract. Replay only
an unchanged pending request after uncertainty; no implementation is authorized.

```json
{"tool":"release_radar_upsert_ticket","disposition":"committed","auditEventID":"9235A944-09CB-486D-B3B1-1B20780C48D4","arguments":{"version":1,"projectRoot":"/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar","registrationID":"8edc840e-2847-4eeb-af68-282d5ed12b11","registrationProjectID":"project-fffdc0e0b15b9b86","requestGeneration":1,"assertedThreadID":"01a0c4b2-46c6-7e81-ae75-da56109621d1","ticketID":"rr-p6-documentation-lifecycle","requestID":"f1b7d53a-b018-48c9-966a-2199c0696d01","phaseID":"rr-p6-remediation","lane":"backlog","outcome":"Clean Release Radar documentation and enforce its lifecycle through compatible repository rules and Git hooks.","reason":"Owner approved the exact new ticket and four-task tracking plan, including RR/shared-execution/plugin compatibility and disposition of GH55/71/74/87 and the existing guided-setup/plan-reconstruction tickets. Tracking setup only; implementation and acceptance remain unreleased."}}
{"tool":"release_radar_revise_ticket_task_plan","disposition":"committed","auditEventID":"1FB3B576-9D9B-4BC0-A99C-0608C94AF805","ticketTaskPlanRevision":1,"arguments":{"version":1,"projectRoot":"/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar","registrationID":"8edc840e-2847-4eeb-af68-282d5ed12b11","registrationProjectID":"project-fffdc0e0b15b9b86","requestGeneration":1,"assertedThreadID":"01a0c4b2-46c6-7e81-ae75-da56109621d1","ticketID":"rr-p6-documentation-lifecycle","requestID":"f1b7d53a-b018-48c9-966a-2199c0696d02","additions":[{"id":"rr-p6-documentation-lifecycle-task-01","label":"Task 1","sortOrder":0,"title":"Establish retention rules, deletion scope, and compatibility with RR, shared execution, plugins, and existing tracked work."},{"id":"rr-p6-documentation-lifecycle-task-02","label":"Task 2","sortOrder":1,"title":"Perform approved cleanup and relocation; update references, catalog metadata, manifests, and test fixtures through supported workflows."},{"id":"rr-p6-documentation-lifecycle-task-03","label":"Task 3","sortOrder":2,"title":"Implement and verify pre-commit and pre-push enforcement using authoritative lifecycle inputs and existing documentation checks."},{"id":"rr-p6-documentation-lifecycle-task-04","label":"Task 4","sortOrder":3,"title":"Independently review, complete authorized delivery, and remove remaining eligible documents after merge."}],"reason":"Apply the owner's exact approved non-atomic task catalog: new plan baseline absent, four additions in order, no revisions or supersessions; all existing tickets unchanged. Expected revision is omitted for the absent plan per the supported tool schema."}}
{"tool":"release_radar_accept_documentation_catalog","disposition":"committed","auditEventID":"1A2C85C0-B039-485D-854B-522149134DE5","arguments":{"version":1,"projectRoot":"/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar","registrationID":"8edc840e-2847-4eeb-af68-282d5ed12b11","registrationProjectID":"project-fffdc0e0b15b9b86","requestGeneration":1,"assertedThreadID":"01a0c4b2-46c6-7e81-ae75-da56109621d1","requestID":"f1b7d53a-b018-48c9-966a-2199c0696d03","priorCatalogDigest":"bca9a86264e9e97e11f78c49acc87f5fe0f0a24de3da27f10c30a8d06c4824b4","priorCatalogVersion":1,"target":{"catalogDigest":"8b299262cfcc79b35854aa4602c8ea2ba0fd88c385323fce1935cc1d505813c0","catalogVersion":1,"projectID":"project-fffdc0e0b15b9b86","repositoryID":"e7475429-ef51-4368-ad9e-61d9073d5a4f","rootID":"project-fffdc0e0b15b9b86-root-0"},"reason":"Owner explicitly approved exact v1 bca9a862 to 8b299262 catalog transition adding only the documentation-lifecycle active brief and ticket-ID collection; tracking setup only, all tasks remain pending in Backlog."}}
```
