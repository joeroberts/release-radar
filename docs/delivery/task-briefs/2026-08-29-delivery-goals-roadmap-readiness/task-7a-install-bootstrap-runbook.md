# RR-R10 Task 7A installation and recovery runbook

Status: the human approved exact gated execution on 2026-09-02; see the current
host prerequisite and caller hold in the progress ledger. The protected
approval record preserves the exact scope relayed by the coordinator.
QA, Security/Privacy and Architecture review found no Required findings in the
resolved package on 2026-09-02. This is a bounded
adaptation of the [M6A runbook](../2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-runbook.md),
not a replacement for its retained custody records. Current status lives only
in [progress.md](../../progress.md). Scope is the [Task 7A brief](task-7a-install-bootstrap-brief.md).

## Candidate and baseline

Product source is Task 7 merge `02769d93974810ce2ad0ad713513947a36836109`,
reviewed head `9f7c574719d332ba75f3a5a0562bb3acf083c6ef`. Task 7A adds tests
and delivery documentation only. Before approval record exact bundle identity,
app/helper/framework strict verification, entitlements, team, version/build,
executable hashes, CodeResources and packaged plugin identity. A rebuild changes
the candidate and needs a new identity record. Expected signing team remains
`2UA854NLX4`; verify from the actual candidate rather than trusting this text.

The previous accepted installed baseline is 0.1.6/schema v13/guidance v2. Obtain
fresh read-only typed/UI metadata, recording the exact project ID, root-row ID,
authorized root, repository ID, accepted catalog version/digest and evidence
inventory. Capture RR-R10 lane, outcome, dependencies/blockers, active phase,
observed goals/links, task/Delivery Goal state and notifications. Retain only
metadata necessary for preservation. Full inventories, exact paths, request
bodies, custody and approvals stay in the existing owner-approved companion.
Never read owner SQLite with SQL. No old inventory is a fresh baseline.

The prepared Release candidate is version 0.1.6/build 1, app CDHash
`47c3d305ad91e64a21b0bccd5ea585f447e81948`. Strict verification passed for the
app, all three packaged helpers and the embedded Core framework; expected team
and hardened runtime were verified. Protected `candidate-signing.json` retains
exact identities and entitlements. `candidate-plugin-schemas.json` records 21
tool schemas and byte-identical packaged marketplace files compared with the
installed baseline. Fresh installed cache/configuration and verified CLI
marketplace/plugin readback also match: version 0.1.6, enabled, exact installed
marketplace path, all three cache files equal. Protected
`installed-plugin-readback.json` and `plugin-cli-readback.json` retain this
evidence. Omit plugin reinstall and marketplace/configuration edits.

Fresh initial typed inventory is complete at v13, with the M8 accepted binding,
eight evidence rows, unchanged preservation metadata and grown audit history.
It remains an initial observation; repeat it at the authorized quiescent boundary.
The retained original M6A owner migration and M8 continuation metadata match.

The minimum catalog sequence is accepted M8 catalog
`5310c3fbc02ff0485857f0affff7322e5bb5b95c8b3978e1b5974293fcdb920d`
(194 artifacts), then the activation snapshot at
`e786cfbf4795eb4ece985ac888f36e57caac0e19`, digest
`a67380545404e183d960a71d4c6b5b31d791b07ec79e81c5145bde4a929582bf`
(196 artifacts), then the final Task 7A catalog. The intermediate preserves
M6B/M7/M8 proposed-to-active transitions and introduces active Task 4B before
completion. Each exact tree must validate before acceptance. Current bound
catalogued documentation matches completed MDCP source `a66bf9a`; its intentional
dirty Git state must stay intact. Do not deploy `AGENTS.md` or whole commits.
The current preparation catalog has 213 artifacts and digest
`9ce0598d88bf8802e9c509a42cd94b4871db9e1866f92b81a138a74f8c60e03f`.
The prepared closeout changes only the stable Task 7A brief to completed and
non-authoritative, retaining the recovery runbook as active supporting material;
its proposed digest is
`07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`.
Both the intermediate tree and disposable closeout proposal pass the native
documentation check. The real closeout catalog must validate and match before
its retained request is sent after the live completion gate. Content-only
ledger updates do not add another catalog transition.

Fresh complete-tree inspection found `docs/.DS_Store` in the bound checkout;
the native checker rejects it as prohibited content. Exactly that regular file
has a protected quarantine proposal, with its observed metadata and bytes
identified in the companion. Its move requires human authorization before a
fresh complete inventory; no deletion, broader cleanup or instruction change
is included. Prior catalogued-file equality remains valid. The deployment
manifest lists eight intermediate and 38 preparation additions/replacements,
plus final closeout catalog/index/brief/ledger reconciliation.

## Reviewable operation package

The protected Task 7A package must resolve, before live authorization:

1. The existing owner store, its adjacent `.pre-migration` snapshot, installed
   app/plugin/configuration, bound root and accepted snapshot; exact paths and
   no-follow metadata; complete fresh typed inventory and relevant UI readback.
2. The retained old and proposed candidate identities; installed destination;
   verified CLI and bundled marketplace; existing broker and exact process
   identities; permitted normal/maintenance launches and expected side effects.
3. Distinct protected backup, failed-state quarantine and app-writable
   disposable restore locations under existing custody terms. Retain through
   acceptance and at least the existing 2026-10-02 deadline; no disposal occurs
   without explicit authorization.
4. Exact file-level bound-root deployment, preserving dirty owner changes and
   all governing instructions. No checkout/reset/clean/automatic fast-forward.
   Include every inherited catalog transition and its typed acceptance request
   in order; preserve accepted repository identity and prior snapshot. A missing
   required intermediate transition or conflict stops preparation.
5. The ordered typed request manifest: authorized root, trusted execution
   origin, this task attribution, reason, stable request UUID, complete command
   body, expected revision source, response/audit and replay status. Retain each
   exact serialized request before sending. Subsequent revisions come only from
   the preceding successful response; unexpected values stop execution.
6. Exact abort/recovery and relaunch commands for those paths/processes, with
   explicit authorization for each overwrite, snapshot replacement and
   process/service change. No placeholder path or inferred identity authorizes
   an action. The reviewer must assess actual resolved inputs before approval.

The existing maintenance host rejects task creation/completion. The approved
bootstrap route must therefore explicitly cover normal-host startup, notification
recovery/delivery and plugin lifecycle behavior, with a caller hold and fresh
preservation comparison. Do not add an API or maintenance bypass. Inventory
provides continuation metadata digests, not individual flags: require unchanged
fresh `project.ticketMetadataV11` and `other.ticketMetadataV11` values anchored
to the retained real migration-lineage evidence; a fresh digest alone does not
prove eligibility. Task rows/labels/checked states are verified through the
normal UI/accessibility list and exact command responses.

Five tests require separately isolated or controlled shared services:
`AgentBridgeTransportAcceptanceTests/testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp`,
`AgentBridgeTransportAcceptanceTests/testCallbackInvalidationAfterHandoffReturnsOutcomeUnknownAndReplayWritesOnce`,
`AgentBridgeTransportAcceptanceTests/testAfterReplyWorkCannotDelayCommittedToolResult`,
`AgentBridgeTransportAcceptanceTests/testTicketTaskToolsUseRegisteredBrokerAndRecoverExactRequests`, and
`CodexPluginLifecycleTransportTests/testPackagedLifecycleHelperCanRegisterFromSandboxedApp`.
The first bridge test requires unregistered service; the task transport test
requires an enabled broker without another host. Under explicit human
authorization, the least disruptive sequence is: quiesce the owner host with
the enabled broker retained; run task-tools first, callback-invalidation second
(its cleanup unregisters), packaged-signed third (registers/unregisters), and
after-reply fourth (registers/unregisters). Run lifecycle fifth with the existing
enabled lifecycle service; its early-return branch does not prove registration.
Use serial native XCTest launches and native test timeouts. After host/helper
exit, normal startup of the unchanged installed app restores its broker. Verify
the exact installed service identity and typed inventory before continuing.
No manual launchctl bootstrap, registration harness, VM or account is included.
Three held transport fixtures have stale Task 7 policy prerequisites and must
be corrected under coordinator scope acceptance before this phase executes.

The remaining suite uses native inert hosts with parallel execution disabled,
but its initial run failed outside the declared E2E slice and stalled; see the
progress ledger. Resolve that prerequisite before controlled services or live
installation. Excluding those five is not complete-scheme success. Resolve the exact service phase with the
coordinator before acting; no account/VM/service creation is implicit.

## Temporary phase selection for live readback

Through Task 7, the normal dashboard displays only the persisted active phase.
The owner-approved historical typed record establishes `RR-ROADMAP` as
Established product roadmap and `release-radar-post-mvp-remediation` as RR-R10's
phase. Fresh initial UI shows Established product roadmap selected. Inventory
does not return an individual active-phase pointer or ticket membership; this
identity uses retained successful request/result and UI evidence, not an
invented query. The source is historical and non-authoritative:
`docs/delivery/archive/2026-08-31-progress-through-rr-r10-task-2b.md`,
RR-R10 creation and RR-ROADMAP activation sections. It establishes recorded
identities only; this runbook and the exact human approval govern new actions.

The coordinator approved preparation of exactly two additional typed
`setActivePhase` requests, retained unsent in protected
`ordered-phase-requests.json`: select the remediation phase once and restore
RR-ROADMAP once. Human execution authorization remains required. Refresh the
current displayed phase before selection; any mismatch stops. Keep the caller
hold throughout selection, bootstrap, relaunch, independent acceptance and
Task 7A completion. Restore the original phase before releasing callers.
Selection changes only the persisted pointer and its expected audit/receipt
records; preserve ticket membership, lanes, goals, dependencies and blockers.
No additional phase changes or Task 10 behavior are included.

## Ordered execution after exact human authorization

1. Revalidate the candidate, target, accepted binding, process identities and
   owner baseline. Obtain the approved caller hold and gracefully quiesce all
   exact app/helper writers and mutation-capable clients. Verify process exit.
   The build/run script is not a preflight quiescence command: its install/run
   modes also replace or launch software. Do not unregister or repair services
   unless that exact action was separately included in the approved package.
2. Under continuing quiescence, inspect the exact SQLite main, `-wal`, `-shm`,
   `-journal` and `.pre-migration` paths with no-follow metadata. Reject any
   symlink/nonregular file, journal or nonempty WAL. Use supported graceful
   recovery for a residual WAL; never delete it or issue SQL. Copy the main and
   every present permitted sidecar together, recording absences, stable source
   metadata and byte equality. Preserve the old `.pre-migration` snapshot and
   exact software/plugin/configuration needed for recovery. Keep directories
   0700 and owner-data files 0600 under the approved custodian.
3. On a distinct approved disposable copy, use the exact candidate with
   `--documentation-maintenance=read-only` and an explicit
   `--documentation-maintenance-store=<resolved-copy>` override. The enabled
   authenticated broker must already be available. Obtain typed inventory,
   close the host and verify exit before any other host/store launch. Require
   schema v13 and the preserved accepted metadata; no implicit binding.
4. Launch that copy in commands maintenance with the same explicit override,
   sending no mutation. The existing store migration advances v13 to v14.
   Close/relaunch read-only and compare every preservation domain, evidence
   locator, root/bookmark fingerprint, accepted binding, original audit/receipt
   fingerprint and migration-continuation metadata. Require only the schema
   version to change before bootstrap. Restore another disposable working copy
   from the protected original set and prove original-v13 supported readback.
   The automatic VACUUM-INTO `.pre-migration` file supplements the protected
   backup; it does not replace it.
5. Only after disposable proof, perform the exact approved installation and
   plugin workflow. Verify installed bundle/helper/plugin bytes and signatures.
   The old managed plugin receipt is not presumed current after an external
   CLI install. Preserve it unless the approved package explicitly includes a
   supported lifecycle update; never edit it manually.
6. Migrate the exact owner store through commands maintenance, then close and
   read-only relaunch. Require v14, unchanged continuation and complete equality
   of pre-existing preservation domains before any task mutation. Close the
   read-only host, verify exit, and launch the installed candidate in commands
   maintenance with the same exact owner-store override before catalog
   acceptance. Deploy and
   accept only the reviewed bound-root catalog sequence. Never repeat initial
   binding or adoption. An observed catalog change remains pending until typed
   acceptance and exact readback agree.
7. If explicitly authorized, submit the retained temporary phase-selection
   request and verify RR-R10's In-progress lane and original context before
   bootstrap. Through the approved existing task-command route, submit the retained
   `reviseTicketTaskPlan` with `expectedRevision` omitted (no existing plan),
   containing exactly the 16 Active/Pending
   additions in the plan's stable catalog. Require returned revision 1. Chain
   `completeTicketTask` for 1A, 1B, 2A, 2B, 3, 4A, 4B, 5, 6 and 7 using each
   actual returned revision. Expected progression is 2 through 11; stop on
   disagreement. Task 7A and Tasks 8–11B remain Pending. No ticket lane,
   membership or goal operation is included.
8. Replay the entire original creation and ten completion requests verbatim.
   Require each original audit/revision with no new audit/receipt/notification
   or row. Perform approved relaunch and typed/UI readback: one plan, 16 active
   rows, `☷ 16`, exact labels/titles/order and ten checked rows, six Pending;
   first/last rows and Task 7A must be visible through the complete list.
   Compare continuation, RR-R10 In-progress lane, phase/goals, bindings/evidence
   and unrelated preservation metadata against baseline.
9. Obtain independent acceptance of actual results and commit/push/remote-verify
   the declared test and delivery evidence on this branch. Only then submit the retained Task 7A completion at the
   actual current revision (normally 11), expecting revision 12. Read back its
   exact audit and checked row with count/lane/goals unchanged. Record that
   revision/audit in the sole progress ledger. Submit the retained restoration request,
   verify Established product roadmap and record its exact audit/receipt.
   Mark the brief completed/non-authoritative, deploy the reviewed closeout
   catalog/index and current brief/ledger, then submit the retained closeout
   acceptance and verify exact readback. Commit/push this complete reconciliation
   before releasing the caller hold. Merge the one Task 7A PR containing the
   complete checkpoint only after that record is present. Task 8 waits for
   this final merge and durable reconciliation; no second status-only PR.

## Abort and recovery

A snapshot/signing/process/root/schema mismatch, unavailable inventory,
unexpected persisted change or unprovable continuation stops further mutation.
For `outcomeUnknown`, preserve the original serialized request and quiescence;
resolve by replaying that request before any recovery decision. Never restore
over an uncertain committed operation or invent a new UUID.

Before any catalog, phase or task mutation, authorized restoration may close
the exact current host, verify app/helper
quiescence, preserve the failed state in the approved quarantine, and restore
the consistent pre-migration database set, old `.pre-migration` presence/bytes,
and exact old software/configuration together. Never open v14 with the old
binary as a rollback method or down-migrate it. Restore only the approved
documentation deployment state while retaining accepted trust anchors and dirty
owner changes; reconcile any accepted catalog transition before claiming
recovery. Relaunch against the explicit restored path and require original-v13
typed/UI equality. If identities or permissions prevent this exact procedure,
hold and obtain coordinator resolution instead of selecting another target.
After a catalog, phase or task mutation commits, this package does not restore
the old store over it. Retain the exact receipts, resolve uncertain outcomes
by replay and hold for a bounded recovery disposition; do not erase accepted
trust anchors or completed task history.

An installed product defect follows the plan's bounded repair-checkpoint rule.
Before plan creation, abort/restore and seek the separate accepted repair scope.
After creation, retain Task 7A Pending and have the coordinator authorize the
meaningful Active/Pending repair row and separate brief. No product patch or
contingency row is included in this installation task.

## Artifact custody

This runbook, brief, changed test and required catalog/index/progress records
are durable repository deliverables. Owner inventories, exact requests and
backups are durable protected companion records. Build products, logs, XCTest
results and synthetic fixture/host directories are temporary verification
inputs/output and remain retained. No cleanup is authorized.
