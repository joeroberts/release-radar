# RR-R10 Task 7A: Install and bootstrap live task tracking

## Objective and outcome

Install the exact through-Task-7 candidate over the accepted managed v13 owner
store, migrate forward to v14, and create the explicit 16-row RR-R10 task plan.
Complete only Tasks 1A, 1B, 2A, 2B, 3, 4A, 4B, 5, 6 and 7 during bootstrap.
Task 7A remains Pending until its own delivery gate, then its returned revision
and audit are durably reconciled before Task 8 can open.

The coordinator accepted this brief on 2026-09-02 under owner delegation and
released the declared E2E test work, minimum test-only legacy fixture corrections
when demonstrated necessary, and isolated validation. This is delegated
acceptance, not personal human inspection. The human subsequently approved
execution of the exact reviewed live package on 2026-09-02. A temporary pause
after the disposable-copy preflight rejected a recreated `docs/.DS_Store`
allowed correction of stale delivery records. The coordinator then explicitly
resumed Task 7A and authorized the exact second quarantine; that move and
native documentation check passed. All five controlled shared-service tests
passed. Both quarantines and backups are retained. Disposable migration/restore,
installed owner migration and bootstrap/relaunch preservation are directly
verified. The owner confirmed ordinary lower-row scrolling in the stacked
viewport and explicitly deferred its height/scroll-affordance improvements to
[Issue #9](https://github.com/joeroberts/release-radar/issues/9). This is owner
observation, not physical scrolling verification by the independent reviewer.
Independent live acceptance found no Required findings. After first commit
`ac6197c` was pushed and remote-verified, Task 7A completed at revision 12 and
the original phase was restored with exact audited replay. Final catalog
acceptance/replay and complete readback passed. Git handoff and exact live
results are recorded in the ledger; no presentation repair is included here.
Current state and verification are recorded
in the existing [progress ledger](../../progress.md).
The [bounded runbook](task-7a-install-bootstrap-runbook.md) adapts the existing
[M6A recovery procedure](../2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-runbook.md)
and the [shared owner-install contract](../../../design/release-radar-ticket-tasks-design.md#owner-install-security-and-recovery-contract).

## Scope and exclusions

Add the Task 7A integration slice in
`ReleaseRadarTests/EndToEndAcceptanceTests.swift`. The coordinator accepted a
bounded test-only amendment on 2026-09-02 for demonstrated stale planning
prerequisites in `AppRouteTests.swift` and `NotificationAcceptanceTests.swift`.
Use existing governed setup, preserve task-gate/reload/audit/notification
assertions, retain direct Backlog acceptance rejection, and fail promptly when
a required notification event is absent before waiting. No other test repair
is included without classification and acceptance. The coordinator also
accepted the same demonstrated transport-fixture correction in
`AgentBridgeTransportAcceptanceTests.swift`: governed Ready coverage, valid
started lanes, unchanged transport/task/replay assertions and prompt prerequisite
failure. That initial amendment permitted test-only edits and safe build
preparation; the later human approval separately released the exact five
controlled shared-service selectors, which have now passed.
The coordinator approved an opt-in observation pause in the existing render
helpers in `ManagedEvidenceRenderingTests.swift` and
`ProjectDocumentationRenderingTests.swift`. Each pause is at most 60 seconds,
keeps the actual test window alive and leaves the default behavior and all
assertions unchanged. Independent external QA observed five actual windows;
the four native AX tests subsequently passed across all 18 states/widths.
After the pause exposed only the inert main window, the coordinator
accepted the established Task 5 window-presentation setup in these helpers:
save/restore the test process's activation policy, use regular activation,
make the actual window key/front and activate the test app. No OS preference
or permission changes were included. The authorized runtime checks passed
with the observation pause and with default timing; this does not release
additional runtime work outside the approved package.
Update this brief/runbook,
the task-relevant plan/design migration assumptions, the existing progress
ledger, and required catalog/index metadata. Stage and inspect the unchanged
through-Task-7 product. No product fix, exporter, protocol/query API, backup
framework, initial binding/adoption, governing-instruction change, Task 8 work,
or cleanup is authorized. Preserve the older dirty saved/bound checkout.

## Dependencies

- Task 7 PR #8 merged into `codex/release-radar-mvp` at
  2026-09-02T12:20:04Z: `02769d93974810ce2ad0ad713513947a36836109`.
  Reviewed product head: `9f7c574719d332ba75f3a5a0562bb3acf083c6ef`.
  Task 7's direct checks and independent reviews remain terminal.
- Worktree branch: `codex/rr-r10-task-7a`, based on that merge. The coordinator
  is `01a06184-6387-7c42-878e-695db0481a18`; this task is
  `01a06211-8538-7de0-bb66-a5005c6cc4ba`.
- Coordinator brief/scope acceptance precedes RED. Human authorization of the
  exact independently reviewed live package precedes installation/migration,
  restore/overwrite, app/helper/broker changes, bound-root deployment/catalog
  acceptance, or task mutations. Routine Git delivery is already authorized.
- Resolve fresh project/root/binding/catalog identity through supported typed
  readback and retain full owner metadata in the existing protected companion.
  Missing trust anchors are blockers, never inferred or recreated.

## Material risks

The installed baseline is app/plugin 0.1.6, schema v13, guidance v2, originally
MDCP-COMPAT-2. Ordinary use may have changed its data. Task 7's v14 migration
changes only the historical assignment-event ticket foreign key to stable
project/ticket identity, retaining historical phase/goal/audit/row data and
constraints. The old binary refuses v14; recovery needs the consistent
pre-migration database set and exact old software, with no down migration.
Migration-only continuation must survive from real lineage; neither setup nor
recovery may manufacture it. The installed old binary opening v14 was not
exercised in Task 7 and is not presumed successful.

The XCTest host isolates its store, but transport/lifecycle tests can still
register shared macOS services. Complete-scheme verification must have genuine
service isolation or a separately reviewed/authorized controlled execution
package. Skipping those tests cannot be reported as complete-scheme success.
Normal application startup can run notifications, imports and plugin lifecycle
work; documentation maintenance suppresses them but restricts commands and UI.
The exact bootstrap/readback route must be proven before live approval.

## Test strategy

After brief acceptance, implement one focused end-to-end integration test using
existing frozen fixtures and native XCTest machinery. Preserve historical
v10/v11/v12 migration coverage. Derive the synthetic managed-v13 source from
the genuine migration lineage using the existing historical fixture/checkout
approach; never set the continuation flag to fabricate eligibility. Verify
the v13 schema before opening it with the exact v14 product.

The predependency condition belongs to the genuine earlier product/fixture
boundary. If the added integration test already passes on the merged product,
record that result honestly; do not weaken product code or force an artificial
RED. Any historical negative run uses disposable source/fixture inputs and
does not overwrite this worktree or the saved checkout.

Run the focused integration test, the complete scheme on genuinely isolated
data/services, strict app/framework/helper signing checks, native documentation
checks, and diff checks. Inspect selector behavior first. Resolve an unavailable
full-scheme environment with the coordinator before any shared-service action.
Use the existing consistent snapshot and disposable-copy migration/restore
proof at the separately authorized live boundary; no direct owner SQL access.

## Acceptance criteria

- Synthetic v13-to-v14 installation preserves migration-granted continuation,
  roots/bindings/catalog, historical assignment rows, lanes/phases/goals,
  evidence, notifications, pre-existing audits/receipts and unrelated state.
- One typed 16-addition request creates exactly one Active/Pending plan at
  revision 1. Stable IDs, labels, verb-led titles and ordering exactly match
  the active catalog in the RR-R10 plan. Chained completions use each actual
  returned revision. After Task 7, ten rows are checked, six remain Pending,
  count is 16, and Task 7A is unchecked.
- Original request replay and relaunch retain the same audits/revisions,
  with no duplicate row/receipt/audit/notification or unrelated state changes.
  The live card and complete scrollable list truthfully show every row.
- Exact candidate/signing proof, fresh baseline identity, ordered complete
  request manifest and recovery/abort procedure are independently reviewed
  before human authorization; only that authorized package executes.
- Live migration precedes bootstrap and is compared with the preserved v13
  baseline. Continuation and RR-R10 In-progress lane remain unchanged; no
  phase/goal repair occurs here. Catalog transitions preserve inherited
  required intermediate states and accepted trust anchors.
- Independent live acceptance and commit/push/remote verification precede Task
  7A row completion on this same branch. The one Task 7A PR is merged only
  after its reconciliation is committed/pushed on that branch. Its exact result and audit are recorded in
  `docs/delivery/progress.md`, committed/pushed and integrated before Task 8.
  No completion is inferred from Git or Markdown.

## Risk-triggered reviews

Independent QA and Security/Privacy review cover actual isolation, install,
preservation, replay, relaunch and recovery evidence. Architecture review covers
the v13-to-v14 runbook adaptation and existing command boundaries. A qualified
reviewer may cover these competencies. Coordinator acceptance covers scope and
sequencing; it is delegated acceptance, not personal human inspection.
Required defects receive bounded correction and only affected rechecks. Product
defects use the existing Task 7A repair-checkpoint rule, never an in-task fix or
precreated contingency row. No review of reviews or competing ledger.
