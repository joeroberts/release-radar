# Release Radar delivery state

## Current outcome and authorization

- MDCP is complete and ordinary live use was owner-approved on 2026-09-02.
  M6B adopted five evidence locators; M7 deployed the six stable-ID document
  moves; M8 accepted the catalog and verified exact replay/relaunch. Delivery
  checkpoints are `b9b1932`, `004e2d2`, `d1b974a` and final closeout `a66bf9a`.
- RR-R10 Tasks 1A/1B/2A/2B/3/4A/4B are delivered. The coordinator verified
  [PR #5](https://github.com/joeroberts/release-radar/pull/5) merged into
  `codex/release-radar-mvp` at 2026-09-02T10:29:21Z, merge `ed630dd`.
- Task 5 is implemented, independently reviewed and explicitly accepted in its isolated worktree on
  `codex/rr-r10-task-5`, based on that merge. Implementation, validation,
  commit/push/PR/merge and routine decisions are authorized through coordinator
  `01a06184-6387-7c42-878e-695db0481a18`. On 2026-09-02 the coordinator accepted
  the concrete UI package under owner delegation, before any Task 5 commit,
  with the documented platform/input-tool limitations. Commit/push/PR/merge
  is released; the coordinator verifies integration before opening Task 6.
  High-risk/destructive owner or shared-state actions require the human owner.
- The original bound checkout, older deployed app and intentional dirty
  documentation remain preserved. No owner installation, live bootstrap,
  catalog deployment/acceptance or shared service operation is authorized here.

## Controlling work and verification

- [RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md) controls
  remaining scope. The completed [Task 5 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-5-ticket-task-presentation-brief.md)
  retains its delivered scope. The coordinator accepted the brief and bounded Core/AppModel support on
  2026-09-02 under owner delegation. Implementation is complete, with 23
  focused tests and the native rendering/interactive recovery test passing.
  Independent projection/read-boundary and QA/UX reviews found no remaining
  required product defect. The [Task 5 verification record](evidence/2026-09-02-rr-r10-task-5-ui.md)
  holds canonical wide/compact, accessibility, contrast, scrolling and recovery
  evidence and explicit delegated acceptance. Physical keyboard activation
  and spoken VoiceOver remain unverified and were accepted as residual risks;
  neither is reported as passing or personally inspected by the human owner.
- Task 4B passed 103 focused tests, Debug/build-for-testing, native documentation
  checks and applicable independent reviews. Its one separately authorized
  broker test passed; the installed app was restored, read-only inventory was
  complete, and the caller hold was released. Those completed checks are not
  repeated by Task 5.

## Live baseline and remaining risks

- Accepted application baseline: `MDCP-COMPAT-2` (`b365aff`), signed app/plugin
  0.1.6, schema v13, guidance v2. The last accepted bound-root catalog is v1
  with 194 artifacts; all eight evidence IDs/locators/associations and unrelated
  delivery state were preserved at M8. Ordinary live use may subsequently
  change owner state, so future installs require fresh authorized readback.
- The inherited development catalog adds the Task 4B brief and a historical
  progress record and corrects completed MDCP brief lifecycle metadata. Task 4B
  closeout changes only its brief to completed/non-authoritative, preserving
  its stable artifact ID and path. The branch preserves the missing activation
  revision before the completion revision;
  later catalog deployment must accept those revisions in order. The M6A
  runbook remains a supporting preservation/recovery reference. This catalog
  is repository-prepared only, pending separately
  authorized deployment to the exact bound root and typed acceptance. The
  live bound checkout has not been changed; no managed-current claim is made
  for the development catalog.
- Whole transport/lifecycle test classes can change the shared macOS bridge.
  Future tasks must retain the brief's safe-selector discipline; Task 4B's
  completed controlled run does not authorize later shared-service operations.
- Native macOS does not support Dynamic Type text enlargement. Physical
  keyboard activation and spoken VoiceOver remain unverified because the UI
  tool did not reliably deliver those inputs to the isolated host. These
  limitations were explicitly accepted in the Task 5 UI package. All
  temporarily changed accessibility/keyboard preferences were restored to
  their immediately observed prior values; no permission setting changed.
- The M8 runtime limits remain documented in the historical record, including
  the unchanged legacy directory-locator discrepancy. No accepted MDCP work
  is reopened by Task 4B. Issue #1 remains unopened and the
  held Issue #2 artifacts remain unchanged.

## Retention and next work

The [Historical closeout and review record](archive/2026-09-02-progress-through-mdcp-closeout-and-rr-r10-review.md)
preserves prior delivery details and the seven alignment findings. Earlier
history remains in [Historical progress through M6B](archive/2026-09-02-progress-through-mdcp-m6b.md).
Exact owner approvals, requests, inventories and recovery copies remain in the
owner-designated protected companion, retained through at least 2026-10-02.
Existing M6A/M7/M8 temporary builds, test outputs and isolated host directories
retain their recorded custody terms; none were deleted. Task 4B build logs,
test results and prepared bundles remain temporarily in `.build/rr-r10-task4b`;
the repository-native tests also create synthetic temporary fixture directories.
These are verification output, not controlling deliverables. No additional
cleanup is authorized.
Task 5 temporary builds, copied inert hosts, test results and raw captures
remain under `.build/rr-r10-task5`; its synthetic XCTest fixture directories
are also retained. Durable Task 5 evidence is in the repository and catalog.

Task 5 product work is accepted. Task 6 is next eligible after the coordinator
verifies Task 5's PR merge and must be started by the coordinator. The new
tools remain development-only until Tasks 5, 6 and 7 are accepted; Task 7A owns
the later owner installation and live bootstrap.
