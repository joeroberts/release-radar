# Release Radar delivery state

## Current outcome and authorization

MDCP and RR-R10 through Task 11A are delivered.
Task 10 [PR #13](https://github.com/joeroberts/release-radar/pull/13) merged at
`609881fe79ec37180057fc6ed36b6ba49afaa8ab`; the coordinator verified its merge,
exact live completion and canonical reconciliation.
Task 11A integration/staging and live completion are accepted;
[PR #14](https://github.com/joeroberts/release-radar/pull/14) merged at
`3ae19c6e0d7ca2e1baf6458f6fd73670748c9af0`, verified by the coordinator. Its
[integration/staging brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11a-integration-staged-candidate-brief.md)
is completed and non-authoritative.
The [RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md) remains
controlling; the [Task 10 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-10-phase-browsing-delivery-goals-brief.md)
is completed and non-authoritative.
The coordinator owns scope and sequencing under owner delegation.

On 2026-09-02 the coordinator relayed NEW explicit owner approval of the reviewed
SECOND maintenance-window package and established the exclusive caller hold.
Task 11B is the sole mutation/test caller on `codex/rr-r10-task-11b`, governed by
the [brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11b-install-final-outcome-brief.md)
and [attempt-2 runbook](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11b-install-recovery-runbook.md).
Approval covers exact retained candidate installation, approved goal/document
operations, final-only completion and one PR merge. The owner explicitly removed
further backup/restore rehearsal and related pre-install review/release gates,
then cleared the temporary hold and directed immediate installation. Existing
custody files remain intact; actual installed outcome review remains required. First-window approval remains exhausted, not reused. No candidate
rebuild/re-sign, direct SQLite access, Codex/plugin/configuration changes,
connector workaround, cleanup or unrelated mutation is authorized.

Fresh installed identity/signatures and original RR-ROADMAP UI match. Complete
supported inventory is 417 audits/126 receipts: all 413 prior audits preserved,
four added, no removals/edits, and every other inventory/entity field unchanged.
The four additions remain unattributed. The coordinator independently compared
the complete files and accepted 417/126 as the current preservation baseline,
with no attribution investigation or rollback. Execution proceeds under the
existing approval and caller hold. Exact records are in the attempt-2 companion.

## Active verification and delivery

The [completed rendering repair](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/rendering-test-repair-brief.md)
retains its stable catalog identity and completed/non-authoritative status.
Its reviewed head `d678c5ec069e478a1ff9ae178817260d8e37b383` corrects only the
two test fixtures' window-discovery assumption: try `AXWindows` first, then
`AXFocusedWindow`/`AXMainWindow` on the same application AX element, requiring
exact PID/title/AXWindow role. Original content, state, width, persistence,
recovery and PNG assertions remain intact. The repair task's normal serial run
passed 4/4 with 18 PNG attachments and independent code/QA Required 0.
That review is terminal; no product repair row or candidate rebuild is needed.
Its temporary outputs remain retained in its reference-only repair worktree.

Task 11B's one normal serial integrated run passed **4/4, zero failed/skipped**
in `repair-integration.xcresult`, without observer or inspection pause. Only the
coordinator has cancelled redundant reruns of service selectors 3–5; their
accepted Task 7A results are reused. Selectors 1–2 passed once in this window.
No full-suite, rendering-selector repeat or further service-test cycle is planned. Prior E2E 14/14, affected
preservation tests 2/2, candidate identity review and pre-execution QA/Security
acceptance remain terminal for unchanged scope, not final installation release.
The earlier preparation run had 524 passed/four failed/zero skipped, excluding
five fixed-service selectors. Its first approved maintenance attempt also
failed those four before the five service tests. That attempt closed after
restoring the existing app/services and releasing the caller hold; it does not
authorize another window. Historical failure, phase requests, backups and
restoration evidence remain in [Task 11B evidence](evidence/2026-09-02-rr-r10-task-11b-installation.md).

Closed Task 11A checks and candidate provenance remain in the
[integration/staging handoff](evidence/2026-09-02-rr-r10-task-11a-integration-staging.md).
Task 10 direct checks and independent QA/UX plus Security/Privacy review are
accepted with Required 0 in the
[Task 10 verification](evidence/2026-09-02-rr-r10-task-10-ui.md).
Prior temporary outputs remain retained with no cleanup authorization. Task 7A
custody remains in the [Historical Task 7A closeout](archive/2026-09-02-rr-r10-task-7a-closeout.md).

Development documentation changes remain pending later authorized bound-root
deployment and catalog acceptance. They do not change the installed accepted
snapshot or authorize a new live operation. Task 7A's completed checks remain
closed.

## Historical first-window checkpoint

This is the closed first-window restoration checkpoint, not a fresh readback.
Owner state may have changed during ordinary use.

- Installed app remains 0.1.6/build 1/schema v14 with 21 tools. Task 11A's retained
  signed candidate has 24 tools and was not installed or rebuilt.
- Supported AX captured all 16 active task rows, the first 15 checked and only
  11B unchecked, card count 16 and RR-R10 In progress. Task 11A's retained exact
  completion established revision 16; the unchanged task-domain count 17/digest
  `99daef17e4f396c3822aaaa73b5c29e655fe367b7e2ec1bc19d60f58fd01d778`
  preserves that association.
- Both approved phase requests committed and replayed. Original `RR-ROADMAP`
  was restored before backup by audit `9C547BEF-0C25-4F56-9EF4-AAC0CC5492F7`
  and confirmed after restart with Backlog 8/Blocked 3.
- Complete restoration inventory has 413 audits, 126 receipts and eight evidence
  rows. All 412 post-phase-restoration audits and every non-audit field were
  preserved. One startup/readback-period audit remains explicitly unattributed;
  the coordinator accepted this disclosed restoration limit. No history was
  erased; the invalid truncated capture remains separately labelled.
- The configured connector is closed following approved client terminations.
  The exact installed signed helper's supported stdio readback succeeded;
  reconnect workarounds and Codex/plugin/configuration changes are excluded.
- Accepted catalog v1 remains the 213-artifact snapshot at
  `07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`.
  The integrated development catalog has 230 artifacts and remains pending
  deployment/acceptance. The separate dirty bound checkout is untouched.

## Remaining limits and next work

The pane-height and scroll-affordance issue is explicitly deferred by the
owner to [Issue #9](https://github.com/joeroberts/release-radar/issues/9).
Ordinary scrolling reaches all rows. The accepted physical-keyboard,
spoken-VoiceOver and native macOS text-sizing limits remain in the
[Task 5 verification record](evidence/2026-09-02-rr-r10-task-5-ui.md).
A further bound-root Finder metadata recurrence needs a bounded remedy; no
repeated quarantine loop is authorized.

Protected requests, backups, old app and quarantines retain their recorded
custody through at least 2026-10-02. Temporary outputs and the path-scoped stash
remain retained; no cleanup is authorized. The older dirty bound checkout is
preserved.

The [next-window runbook](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11b-install-recovery-runbook.md)
has fresh phase/catalog request identities, 17 added/five replaced document
paths and separate absent `attempt-2/` recovery destinations. Independent
Security/Privacy accepted the changed proposal with Required 0, Optional 0;
native documentation/transition checks and `git diff --check` pass. This review
is terminal for its scope. NEW human approval has now been relayed for the
second window. The two executed service selectors passed; selectors 3–5 were
not rerun and retain their prior accepted results. The unchanged app/services
are restored, owner bytes matched backup before startup, and complete readback
preserves all 419 prior audits and every non-audit field; two startup/readback
period audits were added (421/128 total), attribution unestablished and surfaced
to the coordinator and accepted as the fresh421/128 baseline. No rollback
occurred. The exact retained updated app is now installed and normally running;
strict signature/CDHash and24-tool identity match. Installed readback is423/128,
all421 prior audits and every non-audit field preserved, with two unattributed
startup-period audit additions. Goal/catalog operations, completion and PR remain
ahead; no additional backup/rehearsal or related pre-install review is required. Task 11B remains Pending; no
successor is opened. Later RR-R10 and Delivery Goal acceptance is excluded.
