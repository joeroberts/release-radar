# RR-R10 Task 11B installation, recovery and owner-operation package

On 2026-09-02 the coordinator relayed the owner's NEW explicit approval of this
reviewed SECOND maintenance-window package and established an exclusive caller
hold. Task 11B is the sole mutation/test caller; reviewers must not introduce
concurrent callers or writers. The first window remains closed, with all
requests, audits, results, backups and diagnostics preserved.

The four repaired rendering selectors and prior 524 passing remainder tests,
E2E/candidate reviews and bounded attempt-2 safety review are terminal. The
coordinator removed the inherited repeat/full-suite gate after the owner
challenged redundant tests. Selectors 1–2 below passed once in this window;
selectors 3–5 were not rerun and reuse their accepted Task 7A results. The
service-test cycle is finished; do not start another.

The owner subsequently clarified that the temporary hold rejected backup work,
not installation, and explicitly resumed direct installation. No further
owner-data backups, disposable restore rehearsals or backup-related pre-install
reviews/releases are authorized or required. Existing custody files remain
untouched. Approval covers retained candidate promotion,
installed review, goal/document operations, final-only completion and one PR
merge. No further approval is needed for already covered operations. Resolve
changed preconditions before mutation. Failed or unexercised required assertions
cannot be waived. No direct SQLite access, candidate rebuild/re-sign, Codex/
plugin/configuration change, connector workaround, cleanup or unrelated mutation.

The [brief](task-11b-install-final-outcome-brief.md) and
[progress.md](../../progress.md) record scope and current execution state.
This remains the bounded adaptation of the [Task 7A runbook](task-7a-install-bootstrap-runbook.md).

## Exact targets and custody

| Target | Exact identity |
| --- | --- |
| Development root | `/Users/jroberts/.codex/worktrees/4a7d/release_radar` |
| Bound deployment root | `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar` |
| Project / root row | `project-fffdc0e0b15b9b86` / `project-fffdc0e0b15b9b86-root-0` |
| Repository | `e7475429-ef51-4368-ad9e-61d9073d5a4f` |
| Installed app | `/Applications/ReleaseRadar.app` |
| Retained candidate | `/Users/jroberts/Library/Application Support/RekonLabs/ReleaseRadar-MDCP/2026-09-02/task-11a/ReleaseRadar.app` |
| Next-window companion | `/Users/jroberts/Library/Application Support/RekonLabs/ReleaseRadar-MDCP/2026-09-02/task-11b/attempt-2/` |
| Owner store | `/Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/release-radar.sqlite` |
| Disposable working store | `/Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/RR-R10-Task11B-Restore-2026-09-02-Attempt2/release-radar.sqlite` |
| Staged install | `/Applications/.ReleaseRadar-Task11B-2026-09-02-Attempt2.app` |

The only store companion paths are the owner main path plus `-wal`, `-shm`,
`-journal` and `.pre-migration`. No SQL reads of owner data or its copies.
Within the next-window companion, exact recovery destinations are
`pre-service-backup/`, `pre-install-backup/`, `installed-app-before-task11b.app`,
`disposable-before-restore/`, `failed-state/` and `failed-installed-app.app`.
All must be absent before creation/use; preserve collisions, never overwrite.
The bound documentation backup is `bound-documentation-before/` there.
The original parent companion and its first-window `pre-service-backup/`,
request manifests, results/replays and inventories remain verbatim. Never
reuse those destinations or treat that old snapshot as current recovery.
`attempt-2/resolved-paths.json` contains every full proposed target.

Custodian is jroberts/UID 501. Private directories are 0700 and owner-data/request
records 0600; signed bundles retain executable modes under private custody.
Do not change original owner-store permissions. Retain everything through actual
acceptance and at least 2026-10-02. No cleanup or deletion is authorized.

Candidate provenance, 18 regular-file hashes, framework symlinks, component
signatures/entitlements and archive hash are in the immutable
[Task 11A identity](../../evidence/2026-09-02-rr-r10-task-11a-candidate.json).
Archive SHA-256 is `dbeb2df8b9a97fb3a6f7e57d47765da39ee802a869d1fe6e55e29e6796c1a44a`;
app CDHash is `cd5e6016f9b82577fc53ab9a51cad5755551b13b`, version 0.1.6/build 1,
schema 14, arm64, team `2UA854NLX4`, 24 tools. This is Apple Development local-owner
signing, not Developer ID/notarization. A rebuilt bundle is not interchangeable.
The current installed app is 0.1.6/build 1/schema 14/21 tools, app CDHash
`47c3d305ad91e64a21b0bccd5ea585f447e81948`.

## Fresh baseline and temporary pre-install UI selection

The last completed restoration inventory has 413 audits/126 receipts, eight
evidence rows and accepted catalog v1/213 at
`07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`.
RR-ROADMAP was restored; AX showed 15/16 tasks complete, only 11B Pending,
revision 16 and RR-R10 In progress. One audit remains explicitly unattributed.
The configured connector is closed. These are HISTORICAL observations only;
they are not the second-window execution baseline. Establish fresh readback
under the new approval before requests.

During a NEW approved window and caller hold, first establish complete current
supported inventory and exact original RR-ROADMAP identity. Reconcile ordinary
owner changes without guessing or erasing history. If that phase, task revision
16, both phase-plan revision-0 baselines, installed identity or accepted catalog
snapshot differs, stop before any request; do not edit a body under an existing
UUID or invent a new operation.

The old app predates view-only browsing. The next proposal contains new phase
mutations: select `release-radar-post-mvp-remediation`, capture all N task rows
with exact labels/titles/order/statuses and outcome/context, then restore
RR-ROADMAP and replay both exactly before authoritative snapshots/backups.
Only 11B should remain Pending. Pair complete fingerprints with actual UI/typed
associations for lanes, blockers, observed context, notifications and goals.

The exact full bodies are in the next-window `ordered-owner-requests.json`:

| Order | New request identity | Operation |
| --- | --- | --- |
| 10 | `74F667E3-9A85-4A2D-8BDC-E38935071455` | Fresh RR-R10 selection |
| 20 | `88C59207-CE31-45F1-84A5-2D7F9445A5F4` | Fresh original-phase restoration |

Both use authenticated agent-origin helper transport and this task's asserted
attribution. Old phase UUIDs `3A1A6E9E-5191-4756-AE09-53673656ED5A` and
`B6AEDA45-B0F8-4D08-A1B4-8016A442B99D` remain committed first-window history.
Their replay retrieves that old result; it cannot perform a new phase change.
Resolve uncertainty only by replaying the exact current attempt's original.
If restoration cannot be established, do not start service work or install,
and never restore an older database to undo phase audits. The later candidate's
UI checks use view-only browsing, not further phase mutation.

## Completed service-test cycle and retained evidence

Fixed jobs are `gui/501/com.rekonlabs.ReleaseRadar.BridgeAgent` and
`gui/501/com.rekonlabs.ReleaseRadar.PluginLifecycleHelper`. Fixed Mach endpoints
are `2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.app`, `.bridge.tools`, and
`2UA854NLX4.com.rekonlabs.ReleaseRadar.plugin-lifecycle`.
Resolve current PIDs and executable paths with process/launchctl/lsof readback;
stale recorded PIDs are never termination targets. The app, its two services
and AgentTools clients must resolve to the exact installed bundle and recorded
signatures. A mismatch pauses execution.

1. Human approval must include the coordinator's caller hold: no other Release
   Radar mutation clients or test hosts until restoration/readback is complete.
   Retain unresolved requests; resolve exact replay before recovery decisions.
2. Gracefully Quit the exact installed app. SIGTERM only freshly identified
   installed AgentTools clients and helper processes explicitly covered by the
   hold. Keep broker/lifecycle registrations enabled for their required tests.
   Verify writer/client/test-host exit. Do not use the build/run script to quit.
3. While quiescent, no-follow inspect the exact store set. Reject nonregular or
   symlinked files, a journal, or nonempty WAL. Do not remove a WAL or issue SQL.
   Capture every present permitted file together, recording absence, source
   metadata and byte equality, into `pre-service-backup/`; preserve the existing
   `.pre-migration` separately. This is current v14/history, not Task 7A's v13
   snapshot. Unexpected residual WAL requires a bounded recovery disposition.
4. This service-test cycle is finished. Selectors 1 and 2 ran once and passed
   (one test each, zero failures, exit 0) in `attempt2-service-1.xcresult` and
   `attempt2-service-2.xcresult`. Selectors 3–5 were NOT rerun: the coordinator
   verified their accepted Task 7A passes remain valid. Broker/lifecycle service
   implementations are unchanged since Task 7A; Task 8 command additions and
   Task 9/10 projections/UI have accepted focused coverage. Production source
   and project configuration are unchanged from Task 10 merge through the
   retained-candidate/repair head. Do not repeat any accepted test or initiate
   another full-suite/service-only cycle. The table records selector identity
   and prior service effects, not an instruction to run more tests.

| Order | Selector under ReleaseRadarTests | Service requirement/effect |
| --- | --- | --- |
| 1 | `AgentBridgeTransportAcceptanceTests/testTicketTaskToolsUseRegisteredBrokerAndRecoverExactRequests` | Enabled broker, no other host; preserves registration |
| 2 | `AgentBridgeTransportAcceptanceTests/testCallbackInvalidationAfterHandoffReturnsOutcomeUnknownAndReplayWritesOnce` | Enabled broker; cleanup unregisters |
| 3 | `AgentBridgeTransportAcceptanceTests/testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp` | Starts unregistered; registers/unregisters |
| 4 | `AgentBridgeTransportAcceptanceTests/testAfterReplyWorkCannotDelayCommittedToolResult` | Registers/unregisters |
| 5 | `CodexPluginLifecycleTransportTests/testPackagedLifecycleHelperCanRegisterFromSandboxedApp` | Existing enabled lifecycle service; enabled branch returns early |

The fifth test's enabled branch is not new registration proof. Do not unregister
the lifecycle service merely to expand coverage. Do not claim a newly completed full-scheme invocation. Retained successful
results remain accepted; historical rendering failures remain recorded.
An inert host and separate database alone do not prove service isolation.

5. After the two completed selectors, verify all test hosts/helpers exited and
   owner store set unchanged. Explicitly
   approved normal startup of the unchanged `/Applications/ReleaseRadar.app`
   restores the broker after unregistering tests. Maintenance cannot do that.
   Approval includes ordinary notification recovery/delivery and plugin lifecycle
   startup; preserve existing plugin/configuration and compare actual effects.
   Verify installed process/service identity, fresh complete inventory and UI
   before continuing. Any unexpected effect pauses for bounded disposition.
   A failed held selector ends here after restoration; it does not
   authorize proceeding to the pre-install steps or restoring an older store.

## Current-store recovery proof and exact installation

6. The owner explicitly overrode further backup/restore rehearsal and related
   pre-install review gates. The existing current backup and first read-only
   disposable readback remain preserved; no additional rehearsal occurred.
7. The exact retained candidate was installed through the approved bounded
   moves: stop the maintenance instance and old helper, stage retained bytes,
   preserve the old installed bundle at the approved attempt-2 custody path,
   then promote to `/Applications/ReleaseRadar.app`. No rebuild/re-sign.
8. Strict installed signature verification matches candidate CDHash
   `cd5e6016f9b82577fc53ab9a51cad5755551b13b`; normal launch runs the installed
   executable and exposes 24 tools. Complete installed readback is schema14,
   423 audits/128 receipts, preserving all421 prior audits and every other
   inventory field. Two normal-startup-period audit additions remain
   unattributed and preserved. No owner-store replacement occurred.
9. Continue directly with the approved operations and actual installed outcome/
   preservation verification. No extra maintenance-mode launch cycle,
   backup-related release or repeated accepted review is required.

## Exact documentation and Delivery Goal operations

10. `attempt-2/documentation-deployment-files.json` and
    `attempt-2/ordered-catalog-requests.json` in protected custody define the exact bound-root file set and prior/candidate
    digests. The integrated catalog has 230 artifacts: 17 additions and five
    replacement paths. The added repair brief retains stable ID
    `01415623-2b67-48f0-860e-18e9be333e6b`, completed/non-authoritative, alongside
    all existing Task 11B IDs. No new live repair row is included.
    The unchanged 213 accepted records need only one direct preparation
    acceptance, not intermediate activation of completed historical briefs.
    Verify original bytes still match the reviewed Task 7A deployed tree;
    retain that Git source identity without creating additional backup copies. Additions must be absent. Preserve dirty
    Git/index/application source and AGENTS.md byte-for-byte. No pull/reset/clean.
    Validate the complete deployed tree before the exact acceptance request;
    replay and read back before further managed operations. New catalog UUIDs
    `D8DB5640-05E6-4B37-B914-30B1EEFF9B67` (preparation) and
    `6F9B6E0B-1105-476F-B840-F570E3DFB5D6` (conditional closeout) carry the
    changed exact target digests. Old unsent catalog manifests stay verbatim;
    they are not executable alternatives for this proposal. No binding, evidence
    adoption, locator repair or new evidence row is included. A Finder-metadata
    recurrence pauses for a concrete bounded remedy; no repeated quarantine loop.
11. The next-window ordered owner manifest retains full approved outcomes/criteria,
    exact literal assignments, root, trusted origin, attribution, reason, UUID,
    complete arguments and order. Execute through the installed signed
    `Contents/Helpers/ReleaseRadarAgentTools` stdio initialize/tools-call route
    from the exact bound root. The configured connector lacks the three new
    goal tools and is currently closed; do not restart Codex, reinstall a plugin,
    change configuration or improvise reconnect work. The approved stdio route
    must use the actual installed signed helper and exact request bodies.
12. Apply RR-DG-R10 Draft and only RR-R10 assignment at fresh phase-plan revision
    0, expecting 1; finalize exact revision 1. Require atomic Active activation,
    activation time and cleared continuation. Then apply six roadmap Draft goals
    at fresh revision 0, expecting 1; finalize exact revision 1. Literal sets are
    DG1=RM1/RM2/RM10, DG2=RM5/RM6, DG3=RM7, DG4=RM3/RM4/RM9,
    DG5=RM8 and DG6=RM11, all with RR- prefixes. Full values come from the
    [approved goal catalog](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md#approved-established-product-roadmap-catalog)
    and revised complete Tasks/Delivery Goal contract, never Task 11A synthetic
    strings. The five unsent goal/task request bodies and UUIDs are unchanged
    from the first proposal; only the two new phase requests differ. Verify
    exact revisions before each request; a mismatch stops.
    No freestanding activation, historical-ticket assignment or lane move.
13. Replay all original goal requests, relaunch and verify exact goals/assignments,
    RR-DG-R10 Active, six roadmap goals Planned, original active phase and history,
    all task rows, managed evidence/root/catalog and plugin state. Pair full
    fingerprints with actual typed results and UI; do not infer raw values from
    fingerprints. No duplicate audits, receipts or notifications are permitted.

## Completion and recovery boundary

14. Independent QA and Security/Privacy accept actual install/recovery/managed
    preservation and critical UI evidence. Commit/push reviewed tests/evidence
    first while RR-R10 is unaccepted and 11B Pending. Then send retained 11B-only
    completion at the fresh exact task revision, normally 16→17. Replay and prove
    all N checked, card N, exact revision/audit and unchanged lane/goal states.
15. Close the brief completed/non-authoritative, retain this runbook supporting,
    reconcile evidence/ledger/index/catalog, deploy the approved exact closeout
    metadata transition and read back acceptance. Commit/push reconciliation,
    create/merge exactly one PR to `codex/release-radar-mvp`, and report actual
    installed/managed/task/merge identity. Stop before later Needs review/Accepted
    or Delivery Goal Awaiting acceptance/Accepted work.

Automatic recovery is permitted only before any bound-root deployment write and
with direct proof that no post-backup persisted or external effect occurred.
Normal startup can persist lifecycle/audit state or deliver notifications; an
unchanged catalog/goal/task fingerprint alone does not prove absence of those
effects. Compare complete supported readback and actual startup effects with
the latest baseline. If absence cannot be established, preserve current state
and hold for a bounded recovery disposition instead of restoring older history.

Within that boundary, installation invariant failure uses only the approved
recovery: close exact host/client/helpers, verify exit,
move failed store set and software to absent protected failed-state destinations,
restore the consistent latest pre-install set (including original sidecar absence,
`.pre-migration` and metadata) plus exact old software. Restore only reviewed
store/software; documentation is still untouched at this point. Relaunch old
software read-only against the explicit restored v14 store,
then normal UI; require equality to the latest baseline including phase audits.
No downgrade, SQLite editing, blanket overwrite or deletion is permitted.

After any bound-root deployment write begins, do not automatically roll back
documents, store or software. Retain the exact partial file state and backups
for bounded disposition: restoring only old catalog/replacement bytes would
leave the manifest's additions uncatalogued. No added file is deleted or moved
under this package's automatic recovery authority.

After any new persisted or external effect, including normal startup or a
catalog/goal/assignment/task commit, never restore an older store over that
history. Resolve uncertain requests by complete original replay, preserve
current state and hold for a bounded recovery disposition.
If restoration identities/permissions do not match, do not substitute targets.
Installed-only product defects remain regressions with 11B Pending and follow
the separate reviewed repair-task procedure; no hidden fix or contingent row.

This runbook and repository evidence are durable. Complete requests, inventories,
backups and owner UI records are durable only in protected companion custody.
Builds, test results and native diagnostics are temporary and retained.
