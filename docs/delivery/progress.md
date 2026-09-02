# Release Radar delivery state

## Current outcome and authorization

MDCP and RR-R10 through Task 8 are delivered. Task 8
[PR #11](https://github.com/joeroberts/release-radar/pull/11) merged at
`41daf211de8e5d7fbacce794d12f5df98d515093`; the coordinator independently
verified its merge, live completion and brief/catalog closeout. Its 49 focused
tests, independent review and 21-tool compatibility checks remain terminal.
Task 7A custody is preserved in the
[Historical Task 7A closeout](archive/2026-09-02-rr-r10-task-7a-closeout.md).

Task 9 implementation, independent review and live completion are complete on
`codex/rr-r10-task-9`; the single PR merge remains the delivery step. Work follows the
[RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md) and
[Task 9 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-9-delivery-projections-brief.md).
The coordinator owns scope and sequencing under owner delegation.
Authorization covers planning, implementation, focused validation, independent
review, commit/push/PR/merge and exact live task completion with same-branch
reconciliation. Installation, shared-service mutation, UI repair and cleanup
are outside this checkpoint.

## Active verification and delivery

Task 9 implementation `e0a8cf599e1e369fa1706bef0c6cd445bed160e4` is pushed and
directly verified: 39 focused native XCTest cases
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

- Installed app 0.1.6, schema v14, exposes 21 tools. The development
  candidate exposes 24 tools; no replacement was installed here.
- RR-R10 has 16 active task rows. Fresh complete inventory matched the retained
  Task 8 task-domain fingerprint, establishing revision 13. The typed
  `completeTicketTask` request `F5227C04-8387-4FC8-8850-C146B8A47105` for
  `RR-R10` / `rr-r10-task-9` committed revision **14** and audit
  `5C1345DD-5C85-4E91-8872-633344653DA5`; exact replay returned the same result.
  This establishes completion through the typed result and preservation
  association; inventory does not return task rows and no physical checked-row
  observation is claimed.
- Complete post-inventory contains the same one plan plus 16 task rows
  (task-domain count 17), with digest
  `1fd1052be6b13c9a4f7ba2b4f89ccd7002f3276fdcbabc3b6eea5e4322e52e26`.
  Only the task-domain fingerprint changed. All 405 prior audit and 121 receipt
  fingerprints remain, with exactly one new audit and receipt (406/122 total).
  All lane/goal, binding, root, evidence and other preservation groups match.
  The exact request/results and before/after inventories are retained in the
  protected 2026-09-02 Task 9 companion records alongside Task 7A/8 records;
  the canonical request, result, replay and post-inventory copies were read back.
- RR-R10 remains In progress in the remediation phase. The original active
  phase `RR-ROADMAP` was restored, audit
  `1DF40288-7DEE-4BC4-BF34-D859137FAADC`, with exact replay and preserved
  lane/goal state.
- Accepted catalog v1 contains 213 artifacts at digest
  `07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`.
  Acceptance audit `E89F7619-BF0A-45BE-94B0-DA2CA6F71D28` replayed exactly.
  Task 7A, Task 8 and Task 9 briefs are completed/non-authoritative in the development
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

Task 10 remains unopened. Task 9 direct validation, independent review, exact
live completion and same-branch documentation/brief reconciliation are complete.
The coordinator may release Task 10 only after verifying the single Task 9 PR
merge and this closeout. This record does not authorize Task 10 execution.
