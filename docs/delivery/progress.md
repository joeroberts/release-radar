# Release Radar delivery state

## Current outcome and authorization

MDCP and RR-R10 through Task 8 are delivered. Task 8
[PR #11](https://github.com/joeroberts/release-radar/pull/11) merged at
`41daf211de8e5d7fbacce794d12f5df98d515093`; the coordinator independently
verified its merge, live completion and brief/catalog closeout. Its 49 focused
tests, independent review and 21-tool compatibility checks remain terminal.
Task 7A custody is preserved in the
[Historical Task 7A closeout](archive/2026-09-02-rr-r10-task-7a-closeout.md).

Task 9 is active on `codex/rr-r10-task-9`, under the
[RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md) and
[Task 9 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-9-delivery-projections-brief.md).
The coordinator owns scope and sequencing under owner delegation.
Authorization covers planning, implementation, focused validation, independent
review, commit/push/PR/merge and exact live task completion with same-branch
reconciliation. Installation, shared-service mutation, UI repair and cleanup
are outside this checkpoint.

## Active verification and delivery

Task 9 implementation is directly verified: 39 focused native XCTest cases
pass (18 DashboardProjectionTests, 18 ReviewAndGraphAcceptanceTests and three
ManagedEvidencePresentationTests), plus Debug build, documentation check and
diff whitespace check. Tests cover all-phase/active separation, exact coverage,
filtering, tasks/evidence recovery, derived acceptance lifecycle and replay.
Missing-API RED, saved-review refresh failure, byte-distinct identity and
ticket-audit regressions were observed before their corresponding corrections;
synthetic fixture setup errors were corrected without relaxing production rules.

Independent Code/QA review, including the changed projection contracts and
evidence/authority boundaries, reports Required 0. The two required findings
were corrected: exact UTF-8 identities now survive maps/filters/review IDs,
and ticket-owned audits retain relational attribution without prose inference.
The coordinator approved the one AppModel initializer argument needed to retain
unrelated goal attention on a saved review decision with failed refresh.
No shared-service tests, installation, Task 10 UI controls or owner acceptance
actions were added. Temporary outputs are retained under `.build/rr-r10-task9`
and native synthetic test directories; no cleanup is authorized.

Development documentation changes remain pending later authorized bound-root
deployment and catalog acceptance. They do not change the installed accepted
snapshot or authorize a new live operation. Task 7A's completed checks remain
closed.

## Last verified live checkpoint

- Installed app 0.1.6, schema v14, exposes 21 tools. The Task 8 development
  candidate exposes 24 tools; no replacement was installed here.
- RR-R10 has 16 active task rows. Fresh complete inventory matched the retained
  Task 7A task-domain fingerprint, establishing revision 12. The typed
  `completeTicketTask` request `C0FFDCA0-7592-4317-A3CD-0203E21D416E` for
  `RR-R10` / `rr-r10-task-8` committed revision **13** and audit
  `25B157F9-1877-487C-A0B3-CE198AD70528`; exact replay returned the same result.
  This establishes completion through the typed result and preservation
  association; inventory does not return task rows and no physical checked-row
  observation is claimed.
- Complete post-inventory contains the same one plan plus 16 task rows
  (task-domain count 17), with digest
  `b02d047088233d7d1977ded9caf9d2acbcbeeb4cc80368b13659ed0c1c749d44`.
  Only the task-domain fingerprint changed. All 404 prior audit and 120 receipt
  fingerprints remain, with exactly one new audit and receipt (405/121 total).
  All lane/goal, binding, root, evidence and other preservation groups match.
  The exact request/results and before/after inventories are retained in the
  protected 2026-09-02 Task 8 companion records alongside Task 7A records.
- RR-R10 remains In progress in the remediation phase. The original active
  phase `RR-ROADMAP` was restored, audit
  `1DF40288-7DEE-4BC4-BF34-D859137FAADC`, with exact replay and preserved
  lane/goal state.
- Accepted catalog v1 contains 213 artifacts at digest
  `07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`.
  Acceptance audit `E89F7619-BF0A-45BE-94B0-DA2CA6F71D28` replayed exactly.
  Task 7A and Task 8 briefs are completed/non-authoritative in the development
  catalog. The Task 7A recovery runbook remains supporting material. The
  development catalog has 216 artifacts and remains pending deployment and
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

Task 10 remains unopened. The coordinator may release it only after Task 9
direct validation, independent review, exact live completion, same-branch
documentation/brief reconciliation and the single PR merge are verified.
