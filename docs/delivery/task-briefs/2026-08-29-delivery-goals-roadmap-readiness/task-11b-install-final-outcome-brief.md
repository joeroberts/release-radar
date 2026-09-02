# RR-R10 Task 11B: Install and verify the final outcome

Completed and non-authoritative. The owner explicitly resumed immediate
Task11B closeout using existing installation, goal results, tests and reviews,
with no additional UI pass, tests or reviews. Completion request
`CE03A579-0CF1-4FC3-91D6-CB6F7A82A3E1` committed task-plan revision17
(from16), audit `B16E76CE-65E5-45E2-9D72-9E2D56D5F156`, after reviewed
implementation/evidence commit `bcc53fe` was pushed. The final catalog acceptance committed audit
`206FC620-2114-4C68-A7D7-4C5EC78C3808`. Source integration and merge are
recorded in [PR #16](https://github.com/joeroberts/release-radar/pull/16). The final installed UI pass and new
post-install independent review were not performed by explicit owner direction;
no such validation is claimed. Parent RR-R10 and Delivery Goal acceptance are
separate, not authorized by this completion. See [progress.md](../../progress.md)
and the [evidence](../../evidence/2026-09-02-rr-r10-task-11b-installation.md).

The scope and criteria below are the retained task contract, interpreted with
the explicit owner overrides recorded in the evidence; they authorize no
further execution after closeout.

## Objective and outcome

Execute [Task 11B](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-11b-install-and-verify-the-final-rr-r10-outcome):
install retained Task 11A bytes, preserve current owner state, explicitly adopt
RR-R10 and repair the six roadmap Delivery Goals through audited commands, then
complete only Task 11B. End with every active task checked, dynamic card count N,
RR-R10 In progress, RR-DG-R10 Active and RR-DG1…6 Planned. Reconcile documentation
and merge one PR on this same branch; later ticket/goal acceptance is excluded.

## Scope and exclusions

Task `01a06307-5ff9-71e0-8ce2-9476c3707647` is the single writer on
`codex/rr-r10-task-11b` in `/Users/jroberts/.codex/worktrees/4a7d/release_radar`.
Change `ReleaseRadarTests/EndToEndAcceptanceTests.swift` and necessary
canonical brief, adapted operation/recovery package, evidence, ledger, catalog
and generated indexes. Coordinator `01a06184-6387-7c42-878e-695db0481a18` owns
scope, sequencing, documentation accuracy and human approval coordination.

The earlier off-MainActor hypothesis failed and was removed. The separately
completed [rendering repair](rendering-test-repair-brief.md) fixes the two
existing fixtures' window-enumeration assumption, retaining every original
assertion. Its verified merge is integrated; no Task 11B product fix, contingent
live repair row, new helper experiment or candidate rebuild is needed.

The approved execution uses the exact request/file/custody scope in the protected
companion's `attempt-2/` directory without modifying first-window records.
The previous approvals remain exhausted; the newly relayed second-window
approval alone authorizes the current conditional operations. Preserve the
dirty bound checkout and governing files outside the exact approved deployment.

No product fix, new API/harness/service/configuration, direct owner SQLite
access, initial repository binding/evidence adoption, plugin reinstall,
cleanup, Task 5/10 visual matrix, Issue #9 fix or successor task. A later
installed-only defect must retain its regression with 11B Pending and follow
the separate meaningful repair-task procedure.

## Dependencies

Task 11A PR #14 merged at `3ae19c6e0d7ca2e1baf6458f6fd73670748c9af0`;
the coordinator verified live revision 16, preservation and canonical closeout.
This branch now includes repair PR #15 merge
`e7c1800a359fd3d976e92cb5d328b75ca03a5dba`, verified by the coordinator from
reviewed head `d678c5ec069e478a1ff9ae178817260d8e37b383`. The
[candidate handoff](../../evidence/2026-09-02-rr-r10-task-11a-integration-staging.md)
and immutable candidate identity/checksum identify the retained signed bytes.
Consume ADR-001/004/005/006, approved task/Delivery Goal designs and the
[Task 7A recovery runbook](task-7a-install-bootstrap-runbook.md), adapted to
current schema 14 and revision 16; old Task 7A backups are not current recovery.

## Material risks

- A rebuild is a different candidate. Verify recorded files/symlinks, signatures,
  entitlements and actual installed/running identities before replacement.
- Fixed broker/lifecycle endpoints are shared despite an inert test host or
  synthetic database. Full-scheme tests need genuine service/session isolation
  or approved bounded quiescence, execution and restoration.
- Preserve owner data and current history through the exact installation and
  typed/UI outcome checks. Existing backups remain intact; further backup/restore
  rehearsals and related pre-install gates were explicitly overridden by owner.
- Preserve roots/bookmarks, accepted catalog/evidence, historical tickets,
  original active phase, observed context, notifications and plugin state.
  Documentation deployment is an exact reviewed file-level transition only.
- Retain complete ordered request bodies, UUIDs, roots, trusted origin,
  attribution and reasons. Replay originals on uncertainty; never restore an
  older store over committed new owner mutations or accepted audit/task history.

## Test strategy

Extend existing synthetic E2E conventions for current v14/revision-16 state:
all original rows, fifteen complete and 11B Pending. Exercise reopen,
genuine continuation lineage, explicit Draft goals/exact assignments, atomic
Ready adoption, exact completion, dynamic rows/count, replay and preservation.
A reviewed-later-row synthetic variant checks N is not fixed at 16. Immediate
GREEN against delivered product is valid; do not manufacture product failures.

Use native Xcode build/test commands, task-local DerivedData and serial focused
in-process/stdio selections. The integrated four repaired original selectors
passed 4/4 with no failures/skips. Prior 524 passing remainder tests and unchanged
E2E verification remain terminal. Two service selectors passed once in the
second window; the remaining three were not rerun and reuse accepted Task 7A
results following the coordinator's source-delta check. Do not repeat accepted
tests or require a new full-suite invocation. Critical installed UI proves count and all
checked rows without repeating visual matrices. Run native documentation
write/check and `git diff --check`; retain temporary results without cleanup.

## Acceptance criteria

- Independent pre-execution safety review accepts the resolved package before
  human approval of the resolved conditional operations; the second-window
  approval is now active and its obsolete repeat-test gate has been removed.
  The owner also explicitly removed backup-related pre-install release gates;
  actual installed outcome reviews remain required.
- Install only retained Task 11A bytes. Typed/UI readback proves current schema,
  revision, all original and reviewed later rows, N, completion through 11A,
  11B Pending, migration continuation and unrelated-state preservation.
- Apply approved full outcomes/criteria and exact ticket sets as Draft, then
  finalize Ready. Only RR-R10 is adopted into Active with activation time and
  continuation cleared atomically; six roadmap goals remain Planned. No inferred
  assignment, accepted-history backfill or general activation command occurs.
- Replay/relaunch preserves tasks, goals, assignments, managed state and history
  without duplicate audits, receipts or notifications.
- QA and Security/Privacy accept actual installation/recovery/preservation.
  Commit/push reviewed tests/evidence while 11B is Pending and RR-R10 unaccepted.
  Then complete only 11B at the fresh exact revision (normally 16→17), verify
  exact result/replay, all N checked, count, audit/revision and unchanged lanes/
  goal states. Close/reconcile canonical and authorized managed documentation,
  commit/push and merge exactly one PR into `codex/release-radar-mvp`.

## Risk-triggered reviews

Unchanged E2E, candidate and completed repair reviews are terminal. One bounded
Security/Privacy recheck covers the changed next-window request/file/custody
and recovery scope; coordinator review covers sequencing and approval.
Independent QA covers actual installed outcome evidence and
critical installed UI. Independent Security/Privacy covers owner storage,
quiescence/recovery, exact mutations and managed preservation. Coordinator
inspection covers scope/currentness and sequencing. Successful checks/reviews
are terminal absent a concrete affected defect; no review-of-review.

Repository tests/documents are durable deliverables. Owner data, complete
requests and backups belong only in the durable protected companion
`/Users/jroberts/Library/Application Support/RekonLabs/ReleaseRadar-MDCP/2026-09-02/task-11b/`,
under restrictive custody through at least 2026-10-02. Build products, logs,
xcresults and synthetic directories are temporary and retained.
