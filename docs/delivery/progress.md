# Release Radar delivery state

## Current outcome and authorization

MDCP and RR-R10 through Task 11A are delivered.
Task 10 [PR #13](https://github.com/joeroberts/release-radar/pull/13) merged at
`609881fe79ec37180057fc6ed36b6ba49afaa8ab`; the coordinator verified its merge,
exact live completion and canonical reconciliation.
Task 11A integration/staging and live completion are accepted; its
[PR #14](https://github.com/joeroberts/release-radar/pull/14) merged at
`3ae19c6e0d7ca2e1baf6458f6fd73670748c9af0`. Its
[integration/staging brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11a-integration-staged-candidate-brief.md)
is completed and non-authoritative.
The [RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md) remains
controlling; the [Task 10 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-10-phase-browsing-delivery-goals-brief.md)
is completed and non-authoritative.
The coordinator owns scope and sequencing under owner delegation.
Current authorization covers the dedicated
[rendering-test repair](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/rendering-test-repair-brief.md):
diagnosis, bounded test-only implementation, focused isolated validation,
independent review and one commit/push/PR/merge checkpoint. Task 11B remains
paused. Installed-app, live-data/tracking, shared-service, document deployment,
catalog acceptance, product-source expansion and cleanup are outside this task.

## Active verification and delivery

The Task 11B preparation run reported 524 passed / 4 failed / 0 skipped,
excluding five fixed-service selectors. A separately approved serial
maintenance rerun of those same four rendering selectors also failed all four
at own-titled-window AX discovery. That maintenance window is closed; the app
and services were restored and the caller hold released. The off-MainActor
AX lookup hypothesis also failed and was removed. No product defect is
established.

The dedicated rendering repair's implementation and independent code/QA review
are accepted with Required 0. This XCTest host exposes
its exact titled window through `AXFocusedWindow`/`AXMainWindow` while
`AXWindows` is empty, so the fixtures' enumeration assumption was insufficient.
Both existing helpers now try the original window list first, then those
attributes on the same application AX element. A candidate must match the
current process ID, exact fixture title and `AXWindow` role. All original AX
success, missing-window, real-subtree content, state, width, persistence,
recovery and PNG assertions remain intact. No product source changed.

A coordinator-approved passive probe established the attribute difference
against the exact isolated PID/executable/title. The correction then passed
the complete original overview selector in a fresh host with no observer or
inspection pause. The final serial run of all four original selectors reports
**4 passed / 0 failed / 0 skipped, exit 0**, with all **18 PNG attachments**
retained. The independent reviewer confirmed the unchanged assertion coverage,
exact window scope and attachment count.
Native documentation validation and `git diff --check` pass. No product or OS
defect, permission change, or broader UI acceptance is claimed.

The canonical brief is completed and non-authoritative; its catalog identity
and generated index are retained.
Temporary build logs/results/DerivedData, prior-result diagnostics, the
one-off AX probe source/binary/output, and extracted final PNG attachments
remain under `.build/rendering-test-repair`. Synthetic per-PID XCTest host
directories named in those logs are also retained, including the observation
and successful runs (82377, 82610 and 82638). These temporary files are excluded
from the repair implementation; no cleanup occurred. The installed app,
Task 11A signed candidate, owner data and live tracking state remain untouched.

Task 11A's five new integration cases and nine focused existing cases have
passed; Debug and Release builds passed. The exact signed candidate is retained
in protected custody with no installation or owner-app launch. The
[integration/staging handoff](evidence/2026-09-02-rr-r10-task-11a-integration-staging.md)
records direct evidence and limits. Independent QA accepted the integration/
staging checkpoint with Required 0. Reviewed implementation/evidence commit
`7dea462ce42bc2d0d11e4926136991bad285445c` was pushed and remote-verified before
the exact revision-15 baseline check and Task 11A completion below. Temporary
outputs remain under `.build/rr-r10-task11a` and native synthetic directories.

Task 10 direct checks and independent QA/UX plus Security/Privacy review are
accepted with Required 0; its focused tests and runtime evidence remain in the
[Task 10 verification](evidence/2026-09-02-rr-r10-task-10-ui.md).
Its retained live completion supplied the Task 11A pre-operation baseline.
Prior temporary outputs remain retained with no cleanup authorization. Task 7A custody remains
in the [Historical Task 7A closeout](archive/2026-09-02-rr-r10-task-7a-closeout.md).

Development documentation changes remain pending later authorized bound-root
deployment and catalog acceptance. They do not change the installed accepted
snapshot or authorize a new live operation. Task 7A's completed checks remain
closed.

## Last verified live checkpoint

The coordinator's closed Task 11B maintenance handoff is the latest verified
checkpoint; this repair makes no owner calls or independent live readback.

- Installed app remains 0.1.6, schema v14, with 21 tools. Task 11A's retained
  development candidate has 24 tools and has not been installed.
- RR-R10 remains In progress, Task 11B Pending, with 15 of 16 task rows
  complete at revision 16. The original phase `RR-ROADMAP` was restored by
  Task 11B audit `9C547BEF-0C25-4F56-9EF4-AAC0CC5492F7`.
- There are 413 audits / 126 receipts. All prior inventory was preserved;
  additions were two approved phase audits/receipts and one explicitly
  unattributed startup/readback audit. This task does not investigate or
  remove that audit.
- The configured Codex connector is closed following approved client
  terminations. A signed installed-helper restoration readback succeeded;
  connector restoration or a reconnect workaround is outside this repair.
- Task 11A's historical completion request
  `4DA3C7D9-9826-4133-B1D4-E2D0C10FF5FF` established revision 16 with audit
  `61EB3489-4CF7-4751-BC47-39A523EA9812`; its retained association is recorded
  in the [Task 11A handoff](evidence/2026-09-02-rr-r10-task-11a-integration-staging.md).
- Accepted catalog v1 remains the 213-artifact snapshot at digest
  `07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`.
  Completed brief identities are preserved. The development catalog has 227
  artifacts and remains pending separately authorized deployment and
  acceptance. Owner state may change during ordinary use.

## Remaining limits and next work

The pane-height and scroll-affordance issue is explicitly deferred by the
owner to [Issue #9](https://github.com/joeroberts/release-radar/issues/9).
Ordinary scrolling reaches all rows. The accepted physical-keyboard,
spoken-VoiceOver and native macOS text-sizing limits remain in the
[Task 5 verification record](evidence/2026-09-02-rr-r10-task-5-ui.md).
A further bound-root Finder metadata recurrence needs a bounded remedy; no
repeated quarantine loop is authorized.

Protected requests, backups, old app and quarantines retain their recorded
custody through at least 2026-10-02. Temporary outputs remain retained; no
cleanup is authorized. The older dirty bound checkout remains preserved.

Task 11B remains paused pending repair integration and reconciliation. The coordinator may resume
it only after the dedicated repair's verified merge and reconciliation, plus
any new concrete maintenance approval. Installation and owner-data actions
require their own concrete human approval.
