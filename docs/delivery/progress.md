# Release Radar delivery state

## Current outcome and authorization

- MDCP is complete and ordinary live use was owner-approved on 2026-09-02.
  M6B adopted five evidence locators; M7 deployed the six stable-ID document
  moves; M8 accepted the catalog and verified exact replay/relaunch. Delivery
  checkpoints are `b9b1932`, `004e2d2`, `d1b974a` and final closeout `a66bf9a`.
- RR-R10 Tasks 1A/1B/2A/2B/3/4A/4B/5 are delivered. The coordinator verified
  [Task 5 PR #6](https://github.com/joeroberts/release-radar/pull/6) merged into
  `codex/release-radar-mvp` at 2026-09-02T11:35:34Z, merge `cdc3e6e`.
- Task 6 is implemented, directly verified and independently reviewed in its
  isolated worktree on
  `codex/rr-r10-task-6`, based on that merge. Coordinator
  `01a06184-6387-7c42-878e-695db0481a18` accepted the canonical brief, initial
  sequencing and existing-evidence interpretation on 2026-09-02 under owner
  delegation. Focused validation, independent review, commit/push/PR/merge
  are authorized and released for delivery. High-risk/destructive owner or
  shared-state actions require the human owner. Task 7 remains unopened.
- The original bound checkout, older deployed app and intentional dirty
  documentation remain preserved. No owner installation, live bootstrap,
  catalog deployment/acceptance or shared service operation is authorized here.

## Controlling work and verification

- Completed [Task 6 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-6-delivery-planning-policy-brief.md)
  records the policy/test scope. Debug build-for-testing passed. The focused
  run passed 17 new policy, 50 Store and 32 Task policy tests (99 total).
  Independent Code/QA, Architecture, Security/Privacy and documentation review
  identified one required byte-identity defect. Two regression tests reproduced
  it; the bounded UTF-8 identity correction passed all 19 policy tests and
  independent correction review. No Required finding remains. Native
  documentation and diff checks pass. Only the affected policy suite was rerun;
  the successful 82 existing checks remain terminal.
- The policy preserves exact revisions, coverage and assignment/audit history,
  enforces current Ready and owner-origin acceptance, and adopts only explicit
  migration-continuation work into its Draft goal during finalization. Linked
  child evidence marked unavailable blocks acceptance; absent evidence adds no
  requirement. No ticket writer routing or bridge commands were added.
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
  for the development catalog. Task 5 evidence and the completed Task 6 brief
  are also repository-prepared additions pending that separate acceptance.
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

Task 6 temporary native build logs, DerivedData, result bundles and PR body
remain under `.build/rr-r10-task6`; synthetic `RR-R10-Task6-*` fixture directories
and inert XCTest host output are retained. Production code, tests and the
accepted brief are durable repository files; no deliverable exists only in
scratch storage. No cleanup was performed or authorized.

Task 6 implementation is complete; PR integration is the remaining delivery
step. Task 7 is next eligible only after the coordinator verifies Task 6's merge
and opens that checkpoint. The new
tools remain development-only until Tasks 5, 6 and 7 are accepted; Task 7A owns
the later owner installation and live bootstrap.
