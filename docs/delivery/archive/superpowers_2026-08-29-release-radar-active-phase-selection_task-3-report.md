# RR-R9C Evidence and QA Report

Date: 2026-08-29  
Role: fresh serialized Evidence/QA operator  
Status: evidence collection complete; this report is non-authoritative scratch evidence and is not an RR-R9C approval, a final GO, or authorization to activate `RR-ROADMAP`.

## Scope and safety boundary

This run verified the owner-approved first-class active-phase selection outcome after RR-R9A and RR-R9B acceptance. It did not modify product source, tests, project files, task briefs, design/architecture documents, the progress ledger, scripts, or dependencies. The only durable files created were the four authorized screenshots under `docs/delivery/evidence/`; the only additional authored file is this permitted scratch report. The repository-native release staging command was allowed to refresh the established `dist/` bundle.

No staging, commit, push, `/Applications` installation, owner-bundle launch, installed MCP use, final live request UUID, `RR-ROADMAP` mutation, direct SQLite access, network transmission, or Pushover notification occurred.

## Automated acceptance evidence

Exact command:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-Acceptance \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests \
  -only-testing:ReleaseRadarTests/DashboardProjectionTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  -only-testing:ReleaseRadarTests/EndToEndAcceptanceTests
```

Result: exit 65 because four known pre-existing schema/plugin fixture tests failed. The xcresult is:

`/tmp/ReleaseRadar-RR-R9C-Acceptance/Logs/Test/Test-ReleaseRadar-2026.08.29_17-17-31--0400.xcresult`

Structured xcresult totals:

- Total: 146
- Passed: 142
- Failed: 4
- Skipped: 0
- Expected failures: 0

Suite totals:

| Suite | Passed | Total |
| --- | ---: | ---: |
| `AgentBridgeAcceptanceTests` | 19 | 19 |
| `AgentBridgeTransportAcceptanceTests` | 5 | 5 |
| `AppRouteTests` | 51 | 51 |
| `DashboardProjectionTests` | 10 | 10 |
| `NotificationAcceptanceTests` | 24 | 24 |
| `StoreAcceptanceTests` | 29 | 29 |
| `EndToEndAcceptanceTests` | 4 | 8 |

The four failures reproduced existing baseline drift and were not caused by RR-R9:

1. `EndToEndAcceptanceTests/testCurrentSchemaMissingCriticalForeignKeyFailsClosedWithoutMutation()` — expected schema version `Optional(9)`, actual `Optional(10)`.
2. `EndToEndAcceptanceTests/testCurrentSchemaWithWrongCriticalIndexFailsClosedWithoutMutation()` — expected schema version `Optional(9)`, actual `Optional(10)`.
3. `EndToEndAcceptanceTests/testRelaunchRepairsObservedVersionSevenOwnerSchemaDrift()` — fixture unavailable because the lifecycle table already exists.
4. `EndToEndAcceptanceTests/testRelaunchRepairsVersionThreeDatabaseMissingAuditAttribution()` — schema version 3 is now unrecognized.

The handoff describes five historical fixture failures across the broader baseline. This exact selected command contains and reproduces four of them; no fifth test failed in this selection. I did not alter or reinterpret the unrelated baseline.

All RR-R9 direct coverage passed, including these active-phase and fixture checks enumerated from the xcresult:

- `testActivePhaseMustBelongToTheSameProject()`
- `testActivePhaseSelectionKeepsOptionsDeterministicAndBoardMembershipScopedAcrossRelaunch()`
- `testActivePhaseSelectorPresentationDistinguishesSelectionBusyAndNoAlternative()`
- `testExplicitActivePhaseOverridesEarlierHistoricalPhase()`
- `testOwnerActivePhaseSelectionPublishesCoherentProjectionAndPersistsAcrossModelRelaunch()`
- `testProjectWithMultiplePhasesAndNoExplicitActivePhaseHasNoGuessedBoard()`
- `testRR9CapturePolicyRequiresDebugCaptureEmptyStoreAndOneKnownScenario()`
- `testRR9DebugFixtureScenariosExposeDeterministicRoutesStatusesAndOneShotRecovery()`
- `testRR9DebugFixtureSeedsIdempotentlyAndSelectsScenarioRouteWithoutOrdinarySampleData()`
- `testRR9MutatingCaptureScenariosStayIsolatedAcrossSameContainerRelaunches()`
- `testSetActivePhaseChangedBodyRequestIDReusePreservesOriginalSelection()`
- `testSetActivePhaseCommitsOnlyPointerAuditAndReceiptAndDurablyReplays()`
- `testSetActivePhaseFreshAlreadyActiveIntentAuditsOnceAndReplayAddsNothing()`
- `testSetActivePhaseOwnerOriginUsesOwnerAttributionWithoutAssertedThread()`
- `testSetActivePhaseRejects258ByteIdentifierBeforeAnyWrite()`
- `testSetActivePhaseRejectsMissingCrossProjectAndUnauthorizedTargetsWithoutWrites()`
- `testVersionFourMigrationBackfillsOnlyUnambiguousActivePhase()`

The route/fixture policy tests establish that RR-R9 capture is default-off, requires Debug plus `--rr10-capture`, `--rr10-empty-store`, and exactly one recognized scenario, and suppresses ordinary sample data and external services.

## Staged release package and signing

Exact staging command:

```sh
./script/build_and_run.sh --stage-release-no-launch
```

Result: exit 0. The command staged but did not launch or install the application.

Exact verification command:

```sh
codesign --verify --deep --strict --verbose=2 dist/ReleaseRadar.app
```

Result: exit 0. `codesign` prepared and validated the bundled helper binaries and `ReleaseRadarCore.framework`, then reported:

- `dist/ReleaseRadar.app: valid on disk`
- `dist/ReleaseRadar.app: satisfies its Designated Requirement`

Staged bundle identity:

- `CFBundleIdentifier`: `com.rekonlabs.ReleaseRadar`
- `CFBundleShortVersionString`: `0.1.5`
- `CFBundleVersion`: `1`
- Architecture: arm64
- Signing authority: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`
- Team identifier: `2UA854NLX4`
- Hardened runtime: enabled
- Observed CDHash: `e0aa8ffe...`

Package inspection confirmed these established payloads:

- `Contents/Frameworks/ReleaseRadarCore.framework`
- `Contents/Helpers/ReleaseRadarAgentTools`
- `Contents/Resources/ReleaseRadarBridgeAgent`
- `Contents/Resources/ReleaseRadarPluginLifecycleHelper`
- `Contents/Resources/CodexPluginMarketplace/`
- `Contents/Library/LaunchAgents/com.rekonlabs.ReleaseRadar.BridgeAgent.plist`
- `Contents/Library/LaunchAgents/com.rekonlabs.ReleaseRadar.PluginLifecycleHelper.plist`
- application assets and icon resources

Cleanup/runtime registration evidence:

- `launchctl print gui/501/com.rekonlabs.ReleaseRadar.BridgeAgent` exited 113: the bridge service was absent.
- The owner-installed `com.rekonlabs.ReleaseRadar.PluginLifecycleHelper` was already registered and running before isolated QA; it remained associated with parent bundle `com.rekonlabs.ReleaseRadar`, version 1, and was not stopped, restarted, or otherwise touched.
- The owner-installed `/Applications/ReleaseRadar.app` process and its helpers were already running before this task. They were not launched or controlled during RR-R9C evidence collection.
- The alternate capture app registered no alternate helper process. After its final normal quit, no process under the alternate capture root remained.

`git diff --check` was clean after staging. The Git index was empty.

## Isolated Debug identity

The exact alternate build command was:

```sh
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -derivedDataPath "/tmp/release-radar-rr9-capture.pyI7WK/DerivedData" \
  PRODUCT_BUNDLE_IDENTIFIER="com.rekonlabs.ReleaseRadar.RR9Capture.6f368f13-5c53-464b-be75-ad8b212bda4b"
```

Result: `** BUILD SUCCEEDED **`.

Recorded isolated identity:

- Bundle ID: `com.rekonlabs.ReleaseRadar.RR9Capture.6f368f13-5c53-464b-be75-ad8b212bda4b`
- Capture root: `/tmp/release-radar-rr9-capture.pyI7WK`
- App path: `/tmp/release-radar-rr9-capture.pyI7WK/DerivedData/Build/Products/Debug/ReleaseRadar.app`
- Actual launched executable path reported by `ps`: `/private/tmp/release-radar-rr9-capture.pyI7WK/DerivedData/Build/Products/Debug/ReleaseRadar.app/Contents/MacOS/ReleaseRadar`
- CDHash: `03776016d1ad2506c5ba3a7bc73faa0218c20c63`
- Signing authority: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`
- Team identifier: `2UA854NLX4`
- Runtime enabled

Exact alternate signature check:

```sh
codesign --verify --deep --strict --verbose=2 /tmp/release-radar-rr9-capture.pyI7WK/DerivedData/Build/Products/Debug/ReleaseRadar.app
```

Result: exit 0, valid on disk, satisfies its Designated Requirement.

Every scenario launch used only this app and this argument form:

```sh
/usr/bin/open -n /tmp/release-radar-rr9-capture.pyI7WK/DerivedData/Build/Products/Debug/ReleaseRadar.app \
  --args --rr10-capture --rr10-empty-store --rr9-active-phase-fixture=<scenario>
```

The scenarios shared this alternate container. The app was quit normally with Command-Q and observed absent through `sky.list_apps()` before each relaunch. No alternate capture path was deleted; it remains available for independent follow-up.

All UI reads and actions used `@oai/sky` through the persistent `node_repl`, targeted by the unique bundle ID, and refreshed accessibility state after actions. No AppleScript, System Events, CGEvent synthesis, shell screenshot, or fixed sleep was used. Accessibility state/list changes were polled instead.

## Runtime scenario evidence

### `happy`

- Initial route: Overview.
- Overview selector: `active-phase-selector-overview`, value `Current`.
- Initial coherent counts: Backlog 0, In progress 1, Needs review 0, Blocked 0, Accepted 0.
- The target transition produced `Roadmap delivery`, a Phase Board with Backlog 1 and the remaining lanes at 0, and selected ticket `RR9-HAPPY-TARGET`.
- After a normal quit and same-container relaunch, Overview still reported active phase `Roadmap delivery` and counts 1/0/0/0/0, proving persisted selection rather than view-only state.
- The first Computer Use click sequence received a stale-state/user-change notice. Immediate fresh state showed the target already selected and two identical active-phase audit strings. Because that interaction was not cleanly attributable, it was not used as dedup evidence; the passing store tests and the clean `busy` scenario below are the dedup evidence.

### `busy`

- Initial Overview selector value: `Current`; counts 1/1/0/0/0.
- Pointer interaction opened the native phase menu and selected `Roadmap delivery`.
- While the command remained in-flight, selector `active-phase-selector-overview` became disabled with help `Wait for the active phase change and dashboard refresh to finish.`
- One busy indicator was exposed as `active-phase-saving`, description `Saving active phase`, value `0`.
- A repeated AX click against the disabled selector produced no new menu, no additional indicator, no visible phase/count change, and no second dispatch surface. This is the clean runtime dedup/busy evidence.

### `no-alternative`

- Project: `RR-R9 No Alternative`; active phase `Only phase`.
- Selector remained visible but disabled.
- Exact help: `No other phases are available for this project.`
- Counts remained 0/0/0/0/0; no mutation or recovery action was exposed.

### `mutation-failure`

- Selecting `Roadmap delivery` left the active phase and board on `Current`, counts 1/1/0/0/0.
- Exact visible recovery copy: `Active phase change failed, The selected phase is unavailable. No delivery state changed.`
- Selector returned to enabled `Current`; there was no false success or partial board switch.

### `unavailable`

- Selecting `Roadmap delivery` left the active phase and board on `Current`, counts 1/1/0/0/0.
- Accessibility ID/value: `active-phase-unavailable`, `Active phase unavailable`.
- Exact visible copy: `Release Radar could not accept the phase change. The active phase and current board did not change. Reopen or reload Release Radar before trying again.`

### `authorization-failure`

- Project: `RR-R9 Authorization Recovery`; initial active phase `Current`; target `Target`.
- Failed selection exposed container `active-phase-authorization-failed` and action `active-phase-authorization-failed-action` (`Locate / Reauthorize…`).
- Visible copy: `Active phase authorization required. Folder authorization is missing. Select the project folder again before retrying. Locate the same project folder to restore access, then select the phase again.`
- The native panel was directory-only and titled `Locate Project Folder`; its confirmation button was `Reauthorize`.
- Only this exact fixture root was entered through the panel:
  `/Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar.RR9Capture.6f368f13-5c53-464b-be75-ad8b212bda4b/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/RR9ActivePhaseCaptureRoots/authorization`
- After reauthorization, the failure surface disappeared but active phase remained `Current`. There was no automatic retry.
- A second explicit selector action then changed the persisted active phase to `Target`, still with coherent zero counts.

### `saved-refresh`

- Initial active phase `Current`.
- Selecting `Saved target` committed the selection but intentionally failed the first post-commit dashboard reload.
- Selector stayed visibly on `Current`, became disabled, and exposed container `active-phase-saved-refresh-needed`.
- Exact copy: `Active phase saved; refresh needed. Saved target was saved as the active phase, but the visible dashboard has not refreshed. Reload the dashboard; do not select the phase again.`
- The only recovery action was `Reload dashboard` (`active-phase-saved-refresh-needed-action`); there was no resubmit/reselect action.
- Clicking `Reload dashboard` refreshed to active phase `Saved target` without a second selection command; counts remained coherent at 0/0/0/0/0.

### `empty-phase`

- Initial Phase Board selector value `Current`; counts 0/1/0/0/0; selected ticket `RR9-EMPTY-CURRENT`.
- Keyboard path: open the board selector, press Down, fresh AX state reported `(selected) Empty phase`, then Return.
- Result: selector and board phase `Empty phase`; all five lane counts 0; all five lane containers persisted; ticket detail became `Select a ticket` with no stale current-phase ticket.
- The board selector is exposed inside the board's `phase-board` accessibility group; it has the same `Active phase` label and persisted-phase help as the Overview selector.

### `no-active-pointer`

- Overview selector value and summary were exactly `No active phase`; no phase was guessed.
- The recovery copy was: `Choose an existing active phase to load its five-lane board. The persisted phase and ticket history remains unchanged.`
- Opening Phase Board exposed `active-phase-board-recovery` with `No active phase` and a phase selector.
- Keyboard path selected the first menu option `First candidate` (Down, fresh selected AX state, Return).
- Result: normal Phase Board, active phase `First candidate`, five empty lanes, no ticket selection. This establishes a first persisted pointer from the no-pointer state.

### `cross-phase-detail`

- Initial Phase Board phase `Current`; coherent counts 1/1/0/0/0.
- Board cards were only `RR9-CURRENT-READY` and selected `RR9-CURRENT-CROSS`; `RR9-ROADMAP-TARGET` was absent as a board card.
- Selected ticket detail preserved the valid cross-phase reference: `RR9-CURRENT-CROSS` requires `RR9-ROADMAP-TARGET`, `Roadmap backlog outcome 1.`
- Dependencies view reported `1 of 2 phase tickets shown`, rendered only node `RR9-CURRENT-CROSS`, and did not render `RR9-ROADMAP-TARGET` as a current-phase graph node. The scoped dependency inspector therefore reported direct/indirect phase dependencies as 0 while the board ticket detail retained the cross-phase reference.
- Activity remained coherent for `RR-R9 Active Phase` and showed the persisted seed record `Delivery record updated` / `Seed RR-R9 active phase capture fixture`.

## Selector placement, keyboard, accessibility, and responsiveness

Both required selector placements were exercised:

- Overview: `active-phase-selector-overview`.
- Phase Board: the `Active phase` pop-up inside accessibility group `phase-board`; no-active recovery uses `active-phase-board-recovery`.

Pointer selection was cleanly exercised in `busy`, `mutation-failure`, `unavailable`, `authorization-failure`, and `saved-refresh`. Keyboard menu traversal and Return commitment were exercised in `empty-phase` and `no-active-pointer`, with fresh AX state confirming the highlighted menu row before commitment.

The compact state exposed these useful AX values:

- `Active phase`, value `Current`.
- `Card density`, value `Full outcomes requested; showing Compact density at the current width`.
- Individual lane IDs: `lane-backlog`, `lane-in_progress`, `lane-needs_review`, `lane-blocked`, `lane-accepted`.
- Detail region: `ticket-inspector`.

The wide state exposed the same five lane counts and selected-ticket detail while placing the inspector to the right. The compact state retained all five lanes and moved the inspector below the board.

## Screenshot evidence

Computer Use returned JPEG screenshot URLs. Inside the same persistent `node_repl`, each expected state was read with `node:fs/promises`, decoded with `jpeg-js`, encoded as a real PNG with `pngjs`, and written with `fs.writeFile` directly to the canonical path. No shell screenshot tool was used.

| Screenshot | State | PNG dimensions | Bytes | SHA-256 |
| --- | --- | ---: | ---: | --- |
| `docs/delivery/evidence/rr-r9-active-phase-overview.png` | Happy Overview, active `Current`, selector visible | 1499×768 | 263505 | `ea3b61f69defb448656e5a26e1f4aa98f916a06ee82f54b74c3c21b8654ff084` |
| `docs/delivery/evidence/rr-r9-active-phase-board-wide.png` | Cross-phase Board, full outcomes, right-side inspector | 1411×768 | 252670 | `5a4e626ce5b5a9693444f5255c919b9cf6328a16b283a0d9e4fe14cd22880d61` |
| `docs/delivery/evidence/rr-r9-active-phase-board-compact.png` | Cross-phase Board, automatic compact cards, inspector below | 768×777 | 185917 | `b286ad8e20adae2afb2db98909a8687af3e0af9c1c93077b402dac28c4914a3e` |
| `docs/delivery/evidence/rr-r9-active-phase-recovery.png` | Authorization-required Overview and reauthorization action | 1411×768 | 243134 | `4e744541eb09632b48f0419bb48fb0f6e070fe2bf88600014ce769f276f78af4` |

All four files were visually reopened at original detail. They contain only deterministic RR-R9 fixture content, the isolated container fixture path, and ordinary application chrome. They contain no credentials, bookmark bytes, or unrelated private content.

### Requested-size limitation

I attempted the requested wide layout near 1586×992 and compact layout at 760×520 using only Computer Use window actions. The capture environment's current display/window geometry did not produce those exact raster dimensions:

- The largest useful windowed board capture available during this run was 1411×768.
- A bottom-right resize targeted approximately 760×520 and produced a 768×777 Computer Use raster. The horizontal breakpoint fired correctly, and AX explicitly reported automatic compact density; repeated bottom-edge drags did not reduce the captured raster height.

This is a capture-geometry limitation, not a claim that exact dimensions were verified. Wide and compact responsive behavior was directly verified, but exact 1586×992 and 760×520 screenshot rasters remain unverified in this environment.

## Mockup comparison

The running app was compared with `docs/design/mockups/phase_board.png` at original detail.

Matched design characteristics:

- graphite/navy application surfaces and persistent left navigation;
- strong project/phase hierarchy with a five-lane board;
- lane-specific top accents and count badges;
- cyan selected-card outline and blue/cyan navigation selection;
- compact delivery metadata and an adjacent/stacked ticket inspector;
- clear separation of backlog, in-progress, review, blocked, and accepted states.

Expected RR-R9 additions are integrated into the same design language: the `Active phase` selector and `Card density` control occupy the board header; the Overview selector sits beside `Open phase board`; recovery uses an inline amber-brown status surface rather than a modal error.

Observed non-material differences from the static mockup are fixture-specific ticket content, sparse lane population, and evidence-window aspect ratio. The compact layout intentionally truncates card labels and stacks the inspector below the lanes while keeping the dependency reference readable. No material visual contradiction with the approved mockup was observed.

## Isolation, network, and prohibited-action confirmations

- Runtime process path and launch arguments were under the unique alternate capture root only.
- While the alternate cross-phase fixture was running as PID 96839, `lsof -nP -a -p 96839 -i` returned no network sockets (exit 1 with no rows).
- The final normal quit removed the alternate application process; no process under `/tmp/release-radar-rr9-capture.pyI7WK` remained.
- No alternate bridge or lifecycle helper process was present.
- The capture-policy and route tests passed, including default-off and external-service suppression behavior.
- No owner container was opened. No SQLite file was read directly.
- `/Applications/ReleaseRadar.app`, its already-running process, and its installed helper registration were not controlled or modified.
- No live MCP connection was used. No final live request UUID was generated. No `RR-ROADMAP` activation or mutation occurred.
- No OS approval or unexpected permission dialog blocked the run. The only folder panel was the expected fixture-only directory reauthorization flow.

## Final verification and handoff

At the final evidence boundary:

- `git diff --check`: exit 0.
- `git diff --cached --name-only`: empty; nothing staged.
- All four canonical screenshots were nonzero, readable PNG files and were reopened visually.
- The isolated app was no longer running.
- The capture root, acceptance DerivedData, xcresult, and temporary launchctl output were intentionally preserved as temporary evidence. They are not durable deliverables and were not deleted.

RR-R9C now has automated, package, isolated runtime, accessibility, persistence, recovery, responsiveness, signing, cleanup, privacy, and screenshot evidence for independent combined review. This report does not self-approve RR-R9C and does not open the live activation/install gate.
