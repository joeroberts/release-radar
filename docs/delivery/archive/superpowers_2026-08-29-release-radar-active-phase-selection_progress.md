# SDD ledger — plan: docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md

## Recovery state

- Durable authority: `docs/delivery/progress.md` and the registered briefs under `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/`.
- Git base at RR-R9A dispatch: `bcd108f3d1a95be7733a39f42d8b68c98748a30e`.
- Gate at dispatch: RR-R9A open; RR-R9B and RR-R9C closed.
- Writer policy: one fresh serialized Implementer; no staging or commit is authorized or required.

## Preflight plan scan

| Producer | Consumer / overlap | Finding |
| --- | --- | --- |
| RR-R9A typed command, dispatcher result/audit, MCP tool | RR-R9B owner action and projection refresh | Clean: RR-R9B consumes the same accepted command path and cannot start before RR-R9A acceptance. |
| RR-R9A signed transport and replay tests | RR-R9C installed MCP activation | Clean: envelope 1, wire 2, signed transport, and same-ID replay remain stable. |
| RR-R9B projection/status/runtime fixture | RR-R9C automated and running-app evidence | Clean: RR-R9C adds evidence only unless a Required finding needs a bounded fix. |
| RR-R9A affected files | Existing dirty plugin-lifecycle work in AgentTools and transport tests | Overlap is real; preserve current bytes and review only RR-R9-attributable hunks using the baseline blobs below. |
| RR-R9B affected AppModel/UI/test files | Existing dirty plugin-lifecycle and guidance work | Overlap is real; take fresh blob baselines before RR-R9B dispatch and keep one writer. |
| Task 1 internal test/code sequence | RR-R9A brief | Clean: dispatcher RED precedes command implementation; signed-tool RED precedes MCP implementation; GREEN covers both. |
| Task 2 internal test/code sequence | RR-R9B brief | Clean after preimplementation corrections: deterministic guards, generation ordering, coordinator readiness, projection semantics, and Debug-only runtime fixture are specified before code. |
| Task 3 evidence authority | RR-R9C acceptance | Clean: live UI proves visible state/reason/relaunch; isolated app-owned tests prove actor and audit/receipt cardinality without owner database inspection. |

## Rulings

- Ruling: work in the current checkout because required accepted work exists only in the dirty baseline and a clean worktree would mis-base RR-R9 — cost if wrong: attribution overlap; mitigated by serialized writers and per-file baseline blobs.
- Ruling: do not execute self-authored commit/staging steps because Delivery Management explicitly recorded that they are not authorized or required — cost if wrong: no Git-history checkpoint; mitigated by the durable ledger, reports, exact blob baselines, and scoped review packages.
- Ruling: the five reproducible plugin/schema migration-fixture failures do not block RR-R9 focused TDD — cost if wrong: a shared regression could be missed; mitigated by targeted Store/AgentBridge/Transport/Projection/AppModel suites and separate reporting of the known baseline.

## RR-R9A pre-edit blob baseline

| Blob | File |
| --- | --- |
| `e6641c8865f63cef78440e824e6e05d9faef0a02` | `ReleaseRadarCore/AgentBridge/AgentCommand.swift` |
| `a0a7cc5ffc84d82c6c5332ceaa2946c4cd10c9d3` | `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift` |
| `5b1a06d69e59ac92e50339efb549d0715fc46107` | `ReleaseRadarAgentTools/main.swift` |
| `9e6c4f8a36783dedd788ee3d09b57d47361b619e` | `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift` |
| `c4faa39505c951b939d07d454048d8fbf2b8b1c0` | `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift` |

## RR-R9B pre-edit blob baseline

| Blob | File |
| --- | --- |
| absent | `ReleaseRadar/Projects/ActivePhaseSelector.swift` |
| absent | `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` |
| `dd22d4420bbec72d72c6af862764b3683bb9ffa8` | `ReleaseRadar/Projects/DashboardProjection.swift` |
| `a9456643bfb74951c369de3a29d3eeed50ac7aed` | `ReleaseRadar/App/ReleaseRadarApp.swift` |
| `a9f656c802eecc5e1f15bee111d4c07b717ec2f0` | `ReleaseRadar/App/AppModel.swift` |
| `59f5f8d31c23bc2d6ab7295fddabd5eb9c382c78` | `ReleaseRadar/Projects/ProjectOverviewView.swift` |
| `deb27fa71c2e79ef137465721e58968c84a05cf3` | `ReleaseRadar/Projects/PhaseBoardView.swift` |
| `206f919fb9b914e0ec51e48f224fefe6e66d6b61` | `ReleaseRadar/Navigation/SidebarView.swift` |
| `6752094749f9c667c5a5b1bf017e9fe168266f26` | `ReleaseRadar/Shared/FailureStateView.swift` |
| `47ff177ad47b1cc2d157912b2ec848707dd74958` | `ReleaseRadar/App/AppNotificationCoordinator.swift` |
| `b12a1427e7d972f7c26ea7b4eb4971ffe70a916d` | `ReleaseRadarTests/DashboardProjectionTests.swift` |
| `1a342f4081286ead06b8206ba110525fd3a28db2` | `ReleaseRadarTests/AppRouteTests.swift` |
| `203c7ad6ba89648a77c143f36928a2b8b206f1f2` | `ReleaseRadarTests/NotificationAcceptanceTests.swift` |

## Task status

- Task 1 / RR-R9A: ACCEPTED; 53/53 focused tests passed with 0 failures/skips. Independent task Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery Management all reported GO/Approved with Required 0. Delivery Management released RR-R9B only. Report: `task-1-report.md`. Review package: `task-1-review-package.md`.
- Task 2 / RR-R9B: IMPLEMENTED; meaningful pre-product RED exited 65 on absent `activePhaseID`/`phases`; final exact focused GREEN passed 100/100 with 0 failures/skips; scoped `git diff --check` is clean. Independent Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery Management acceptance remain pending. Report: `task-2-report.md`. Exact attributable patch: `task-2-review-package.md`. RR-R9C remains closed.
- Task 3 / RR-R9C: closed.

## RR-R9B independent review loop 1

- QA/Test: GO, Required 0; fresh `/tmp/ReleaseRadar-RR-R9B-QA-POST` run passed 100/100 with 0 failures/skips, scoped diff check clean, no staged paths, no test sleeps.
- Architecture: NO-GO, Required 1; a superseded `loadDashboard()` caller continues into route/notification side effects instead of returning immediately.
- Code Review: With fixes, Required 4 total: the same superseded-launch issue; rejected reauthorization folders remove the recovery action; duplicate capture/empty-store guard flags are accepted; preservation coverage compares counts instead of exact dependency/history rows and omits a phase-dependency row.
- Technical evaluation: all four findings are confirmed against the canonical brief and current source. Corrections remain within `AppModel.swift`, `ReleaseRadarApp.swift`, `AppRouteTests.swift`, and `DashboardProjectionTests.swift`; no scope expansion or owner decision is needed.
- Fix-loop pre-edit blobs: `AppModel.swift` `76ccd276c6c9a076fba1f4334fcb1daa7451b777`; `ReleaseRadarApp.swift` `640233363d2dd1081c41510a244470b5124b3da6`; `AppRouteTests.swift` `9597624eb01f53af7d4038a38ac78eff51c36e24`; `DashboardProjectionTests.swift` `309aa500f5e70e02fab6572706fa69492aa21486`.
- Review loop 1 implementation: all four corrections complete; focused RED/GREEN evidence recorded in `task-2-report.md`; final exact GREEN passed 102/102 with 0 failures/skips; scoped diff check clean. Correction package: `task-2-review-fix-1-package.md`.
- Review loop 1 independent closure: Code Review Approved (Critical/Important/Minor 0, Required 0); QA/Test GO (fresh 102/102, Required 0); Architecture GO (Required 0, ADR-001/ADR-003 satisfied, no new ADR). Security/Privacy, TPM, and Delivery Management acceptance remain pending; RR-R9C/live activation remain closed.
- Security/Privacy review: NO-GO, Required 1. The external-command and owner saved-recovery “read-only” projection paths still call mutating guidance authorization, which can mark `project_bookmarks.is_stale` and append an owner audit on resolution/stale/root-mismatch/access-denied failures. This violates the brief/ADR-003 read-only refresh boundary. TPM final release remains held; RR-R9C closed.
- Security fix-loop pre-edit blobs: `AppModel.swift` `6680d2c2f7a651da98e8f2ff4fc11b100579166a`; `AppRouteTests.swift` `e65f8ed50a9ace02be0914626300da96e7c9d871`.
- Security fix-loop implementation: focused RED 2/2 failed on bookmark/audit and cached guidance/root mutation across all four authorization failures; focused GREEN 2/2 passed after committed contexts reused the published guidance/root snapshot; final exact GREEN passed 104/104 with 0 failures/skips and scoped diff check clean. Package: `task-2-security-fix-package.md`. Fresh independent Security/Privacy, QA, Code, Architecture, TPM, and Delivery decisions remain pending; RR-R9C closed.
- Security fix-loop independent closure: Security/Privacy GO (Required 0); QA/Test GO (fresh 104/104, 0 failures/skips, clean scoped diff, no staged paths); Code Review Approved (Critical/Important/Minor/Required 0); Architecture GO (Required 0, ADR-001/ADR-003 satisfied); TPM GO (Required/Optional/Out-of-scope 0). TPM authorizes Delivery Management to accept RR-R9B and release RR-R9C only; live `RR-ROADMAP` activation remains closed pending RR-R9C combined final GO.
- Delivery Management pre-edit ledger blob: `docs/delivery/progress.md` `53e95374c39d549acad86af541c7e41957ba60cc`; branch `codex/release-radar-mvp`; HEAD `bcd108f3d1a95be7733a39f42d8b68c98748a30e`; no staged paths.
- Delivery Management accepted RR-R9B with Required/Optional/Out-of-scope 0 and released RR-R9C only. Canonical ledger section begins at `docs/delivery/progress.md:258`; current gate keeps live `RR-ROADMAP` activation closed until RR-R9C combined final GO.

## RR-R9C evidence collection

- Automated acceptance: exact 7-suite command produced 146 total, 142 passed, 4 failed, 0 skipped/expected. Every RR-R9 direct suite passed; the four failures are the documented End-to-End schema/plugin fixture drift. Result: `/tmp/ReleaseRadar-RR-R9C-Acceptance/Logs/Test/Test-ReleaseRadar-2026.08.29_17-17-31--0400.xcresult`.
- Release package: `--stage-release-no-launch` succeeded; staged `0.1.5` build 1 passes deep/strict codesign; BridgeAgent job absent. No installation or owner-app control occurred.
- Isolated runtime identity: `com.rekonlabs.ReleaseRadar.RR9Capture.6f368f13-5c53-464b-be75-ad8b212bda4b`, root `/tmp/release-radar-rr9-capture.pyI7WK`; alternate Debug bundle passes deep/strict codesign and is quit.
- All ten Debug scenarios were exercised through Computer Use with no owner-container/DB/network/live-MCP/final-UUID access. Runtime evidence includes pointer/keyboard paths, busy/no-alternative/failures, exact-root reauthorization/no retry, saved-refresh read-only recovery, empty/no-pointer states, cross-phase detail/node scoping, and relaunch persistence.
- Four canonical PNGs exist and are readable. SHA-256: overview `ea3b61f69defb448656e5a26e1f4aa98f916a06ee82f54b74c3c21b8654ff084`; wide `5a4e626ce5b5a9693444f5255c919b9cf6328a16b283a0d9e4fe14cd22880d61`; compact `b286ad8e20adae2afb2db98909a8687af3e0af9c1c93077b402dac28c4914a3e`; recovery `4e744541eb09632b48f0419bb48fb0f6e070fe2bf88600014ce769f276f78af4`.
- Open evidence limitation for independent classification: Computer Use produced wide 1411×768 and compact 768×777 rasters; responsive wide/right-inspector and compact/below-inspector AX states were observed, but exact near-1586×992 and 760×520 raster evidence was not obtained. RR-R9C remains unapproved; live activation closed.
- Evidence report: `task-3-report.md`. Temporary paths retained; no staged files and `git diff --check` clean.
- Combined review loop 1: Code/Product NO-GO Required 1 and Architecture NO-GO Required 1 because canonical wide/compact screenshots do not directly prove the requested near-1586×992 and 760×520 runtime sizes; both treat the stale happy interaction as Optional only. Fresh QA GO Required 0 after 142/146 with the same four unrelated failures and a direct 760×552 outer-window observation matching the 760×520 content minimum plus 32px title bar; QA could not obtain the near-1586×992 raster in the current Computer Use viewport. The Required evidence conflict remains unresolved; installation/live activation closed.
- Owner attention requested by Pushover: approve a temporary display-resolution change for exact recapture or explicitly accept the documented target-size evidence deviation. Notification sent successfully at normal priority; awaiting owner direction.
- Owner decision: the owner explicitly accepted the current evidence ("what you have right now is just fine"). The controlling design now records an owner-approved RR-R9C visual-evidence deviation accepting the canonical 1411×768 and 768×777 captures plus QA's direct 760×552 outer-window observation as sufficient; responsive product requirements remain unchanged. Code/Product and Architecture closure re-reviews are in progress; installation/live activation remain closed until all combined gates report GO.
- Owner-decision closure reviews: Code/Product GO (Required 0; exact-size and clean happy-path recaptures Optional) and Architecture GO (Required 0; no ADR change needed). Both confirm that only the evidence threshold changed and the responsive product contract remains intact.
- Security/Privacy combined review: GO, Required 0, Optional 1 (redact the local account path only if internal evidence is later published). Fresh signing, alternate-container isolation, Debug-only/default-off fixture gates, capture suppression, exact-root authorization, no-auto-retry behavior, committed-refresh immutability, screenshot hashes, absent bridge job, and no prior live MCP/final UUID were independently verified. The owner-requested Pushover coordination message is outside the isolated capture path and has no product, owner-data, or fixture coupling.

## RR-R9C live activation and reopened correction

- Combined preactivation Code/Product, QA, Architecture, Security/Privacy, TPM, and Delivery reviews reached GO with Required 0 after the owner-approved visual-evidence deviation.
- The installed signed `0.1.5` app accepted exactly one `release_radar_set_active_phase` request, ID `385154BC-DC33-4F9C-ABBD-D80B271D8FF4`, and returned audit `FBBB409B-9E4A-4165-A22D-6BFD16B3E154`. Immediate and relaunch UI readback showed `RR-ROADMAP`, counts `8/0/0/3/0`, roadmap ticket/detail/dependency state, the exact reason, and the prior phase as a selector option.
- Fresh final verification reproduced the known `142/146` selected-suite result but proved an ordinary app-hosted XCTest process can construct production `ReleaseRadarAppServices.shared` under bundle ID `com.rekonlabs.ReleaseRadar`. RR-R9C and RR-R9 completion were reopened for the registered two-file XCTest-host isolation correction.
- Correction brief: `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-brief.md`, SHA-256 `3ef01ec72886a09c393b6cf49e80778b536660777920a5bec30932cf2368f261`.
- RR-R9 was then found absent from its governing Phase Board. Under the owner's explicit direction, the exact ticket-upsert request `58F4FBDD-2710-427A-8C21-EF96B86B7C37` was replayed through the installed signed STDIO helper after plugin-path `appUnavailable` results; it returned audit `D8B5E932-BC1C-466E-8329-092B166568BA`. Direct UI readback shows `RR-R9` in `in_progress` under `release-radar-post-mvp-remediation`.
- Ruling: the owner-directed RR-R9 ticket-upsert is a separate tracking repair, not the XCTest-host product correction or a second active-phase operation. The correction brief's no-live-MCP/no-UUID safeguard continues to prohibit any correction-generated or phase-selection command. Cost if wrong: the brief's blanket wording is no longer literally true for the surrounding session; mitigation is exact durable attribution, a distinct request/audit, and explicit proof that no second `release_radar_set_active_phase` request occurred.

### Configured plugin-wrapper availability root cause

- Required defect: this root task's configured Release Radar plugin wrapper returned `appUnavailable` even after the installed app and bridge agent were running. The direct signed-helper success did not satisfy the configured-agent-path requirement.
- Proven process identity: plugin-owned helper PID `75927`, parent Codex app-server PID `83481`, started at `2026-08-29 12:08:07`, was still executing the text vnode from `/Applications/.ReleaseRadar.backup.99792.11033/Contents/Helpers/ReleaseRadarAgentTools`; that backup path had since been removed. A separate helper PID `940` mapped to the current installed binary inode `31727106`, and fresh direct helper PID `2817` connected successfully.
- Proven rejection: after bridge agent PID `2759` registered both Mach listeners, the stale plugin helper reached the tools listener at `18:55:35` and `18:55:56`. The bridge's peer requirement check failed with macOS status `-67065`, logged `Received message forbidden due to code signing requirement`, and canceled the connection. `/usr/bin/security error -67065` reports `host has no guest with the requested attributes`.
- Root cause: atomic app promotion moved the prior app bundle to a unique backup and then removed it while this long-lived Codex task retained an MCP helper process loaded from that prior bundle. Once its executable vnode no longer had a resolvable signed bundle, the new bridge correctly rejected the stale client. The current installed helper and bridge are not the same failing pair.
- Ruling: the direct-helper board write remains an audited app-owned mutation but is insufficient plugin-wrapper acceptance. Final RR-R9 acceptance requires a fresh post-install Codex agent whose plugin helper maps to the current installed bundle to replay the existing RR-R9 ticket request and return audit `D8B5E932-BC1C-466E-8329-092B166568BA` without a new mutation. Cost if wrong: a fresh task could still expose a product defect; any mismatch remains Required and reopens product diagnosis. No second active-phase command is permitted.

## XCTest-host isolation correction preflight scan

| Producer | Consumer / overlap | Finding |
| --- | --- | --- |
| `AppLaunchConfiguration.hostMode` in `ReleaseRadarApp.swift` | `ReleaseRadarApp.init`, scene gating, and AppDelegate | Clean: one predicate/decision must be consumed before shared-service/model construction and before delegate notification/bridge startup. |
| PID-scoped temporary URL decision | isolated `DeliveryStore` retained for XCTest-host lifetime | Clean: exact standardized path is specified and no production fallback is permitted. |
| `AppRouteTests` policy RED/GREEN | ordinary app-host runtime evidence | Clean: compile-only RED cannot launch the vulnerable host; focused GREEN proves decision semantics; ordinary seven-suite run proves the actual host path. |
| Correction files | pre-existing accepted RR-R9B changes in `ReleaseRadarApp.swift` and `AppRouteTests.swift` | Overlap is real; one writer may modify only these two files and must report exact pre/post blobs and attributable hunks. |
| XCTest-host branch | normal Release, ordinary Debug, and Debug capture paths | Clean if XCTest presence wins and the `.application` branch preserves current source ordering and policy matrix. |
| Correction acceptance | prior one-time live activation | Clean: corrected install/readback may observe persisted state only; no activation readiness probe, replay, new UUID, or phase mutation is authorized. |

- Correction task status: preimplementation review open. Implementation, install, and all phase-selection MCP work remain closed until Architecture, TPM, QA/Test, and Delivery Management release the writer.

### Fresh configured-plugin acceptance and owner finalization rule

- Fresh configured-plugin QA: **GO, Required 0.** A fresh Codex agent replayed the exact existing RR-R9 ticket-upsert request through the configured plugin wrapper and received the original audit `D8B5E932-BC1C-466E-8329-092B166568BA` with entity `RR-R9` and `isError: false`. Its helper PID `7341` mapped before and after to `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`, not a removed backup. This idempotent replay made no new mutation and closes the configured-agent-path defect.
- Owner finalization rule: RR-R9 remains active and no stage, commit, or push may occur during an intermediate chunk. After the entire RR-R9 outcome is delivered and every required independent approval and verification reports Required 0, create the coherent commit or commits for the accepted Release Radar change set, push the configured upstream, verify the remote result, and only then mark the goal complete. Exclude temporary artifacts and preserve unrelated user work.

### XCTest-host correction implementation release

- QA's initial pre-implementation review found one Required gap: deterministic coverage of temporary-directory preparation failure. Planning amended the registered brief with a regular-file-at-PID-directory fixture and explicit inert unavailable-host state. The current brief, `SHA256SUMS`, and canonical ledger all register SHA-256 `2d4c855adecab3c20da618f8147f60aa42d8da903ea000e5675e58eb3f7571de`; the superseded checksum has no controlling occurrence.
- Final pre-implementation decisions for that exact checksum: Architecture GO Required 0; QA/Test GO Required 0; TPM GO Required 0; Delivery Management GO Required 0. Exactly one fresh Implementer is released for only `ReleaseRadar/App/ReleaseRadarApp.swift` and `ReleaseRadarTests/AppRouteTests.swift`, safe compile-only RED, focused GREEN, and two-file diff check. Installation, app control, MCP/SQLite, phase command, staging, commit, and push remain closed.
- Correction pre-edit blobs: `ReleaseRadarApp.swift` `916e18c67469f60079fc8b829bdfbe6582de203b`; `AppRouteTests.swift` `cd926cbdadaa49902d8282bd79dcd1bf401a013d`. Pre-edit SHA-256 values are respectively `e42ccab0f1aaaa0640aa546f94ba0d9f2d637d501bf3d230eb80f621348df74f` and `42583763d9a16874f09453c215a828a32882d024e3f636bcd583008212eedb01`.

### XCTest-host correction review loop 1

- Initial implementation: safe compile-only RED exited 65 on the absent isolation API with no host launch; focused `AppRouteTests` GREEN passed 53/53 with zero failures/skips; two-file diff check clean. Post-edit blobs were `ReleaseRadarApp.swift` `535abf710fe0a9ab6a1bdd23ad4ddcee38c3daad` and `AppRouteTests.swift` `e545a31b284d4e2f8aa0c02f11a2213ea9ba0b3c`.
- Code Review and Architecture: **NO-GO, Required 2.** Existing same-PID directories are accepted and can reopen stale test state; the `XCTestHostConstruction` booleans are test-only mirrors not consumed by production initialization.
- Security/Privacy: **NO-GO, Required 2.** Existing-directory/symlink acceptance plus check/create/check sequencing can redirect the lexical test URL before `DeliveryStore` opens; creation must be exclusive and fail closed for every pre-existing entry. The new tests also call side-effecting `DeliveryStore.applicationSupportDatabaseURL()`, which creates the owner Application Support directory and violates test-host isolation evidence.
- Fix round 1 boundary: same Implementer, same two files. Add failing regression coverage for a pre-existing real directory/stale sentinel and symlink without SQLite; make directory creation atomic/exclusive and reject every pre-existing entry; make the tested construction decision the actual production-consumed preparation path; stop calling the production Application Support helper in tests. No generalized harness, core/store edit, install, app control, MCP/SQLite inspection, stage, commit, or push.

- Fix round 1 implementation: focused compile-only RED exited 65 for the absent production preparation API with no test-host launch; focused GREEN passed 55/55 with zero failures/skips; two-file diff check clean. Current blobs are `ReleaseRadarApp.swift` `e0965e340b0c6e49451ecdcf31188c301cf9b8ba` and `AppRouteTests.swift` `e0206a8c3fef481c75603d324904a279aabeba06`.
- Fix round 1 scoped closure: Code Review **GO**, Architecture **GO**, and Security/Privacy **GO**, all Required 0. All prior findings are ADDRESSED: POSIX `mkdir` performs exclusive owner-only creation and rejects every existing directory/file/symlink before immediate store construction; `XCTestHostPreparation` is the production-consumed value carrying the exact retained store; collision tests use fail-fast factories and preserve non-SQLite sentinels; and `AppRouteTests` has zero `applicationSupportDatabaseURL` calls. Security classifies the theoretical post-`mkdir` hostile same-user replacement race as out of scope under the local threat model because there is no yield before synchronous store construction and such an actor already has direct owner-data access.
- Runtime QA gate now open: fresh ordinary seven-suite host run plus public PID/path diagnostics and exact installed-owner Active phase/ordered Activity before/after equality. Packaging/install/MCP/phase commands/staging/commit/push remain closed.
