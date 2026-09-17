# RR-R9C XCTest-host isolation — independent runtime QA report

## Verdict

**GO — Required 0.**

The ordinary app-hosted XCTest selection used only fresh PID-scoped temporary
stores. The six directly relevant suites passed (142/142) and `AppRouteTests`
passed its 55 cases, including the corrected host-preparation cases. The four
non-blocking failures are the pre-existing End-to-End migration fixture drift
called out by the controlling brief. The installed owner's active-phase value
and complete visible Activity snapshot were identical before and after the
ordinary test-host executions.

No SQLite file was opened or queried by this QA verification. No app install,
MCP call, UUID, active-phase command, staging, commit, or push occurred.

## Controlling scope and source review

- Correction brief SHA-256: `2d4c855adecab3c20da618f8147f60aa42d8da903ea000e5675e58eb3f7571de`.
- Current source blobs: `ReleaseRadar/App/ReleaseRadarApp.swift`
  `e0965e340b0c6e49451ecdcf31188c301cf9b8ba`; `ReleaseRadarTests/AppRouteTests.swift`
  `e0206a8c3fef481c75603d324904a279aabeba06`.
- `git diff --check -- ReleaseRadar/App/ReleaseRadarApp.swift ReleaseRadarTests/AppRouteTests.swift`
  exited 0 with no output. `git diff --cached --name-only` produced no paths.
- Static/review correlation: `AppDelegate.applicationDidFinishLaunching` returns
  on the shared XCTest predicate before activation, notification initialization,
  `ReleaseRadarAppServices.shared`, or bridge startup. `ReleaseRadarApp.init`
  prepares the XCTest host before its only `ReleaseRadarAppServices.shared`
  access; both XCTest preparation cases set the model to `nil` and return.
  The scene gates `SidebarView`, Add Project, menu-bar, and Settings content on
  a present model. Successful test-host preparation retains only the store made
  for the isolated URL; unavailable preparation retains no store. The focused
  collision cases use fail-fast factories, so pre-existing directory, regular
  file, and symlink collisions cannot call the store factory.
- The selected `AgentBridgeTransportAcceptanceTests` intentionally exercise
  test-owned transport behavior. They do not evidence production AppDelegate
  bridge startup; that startup is unreachable under the XCTest predicate.

## Installed owner UI — before

Read only through Computer Use accessibility. The Active phase picker was read
without opening it.

- Active phase value: `Post-MVP reported-defect remediation`.
- Visible Activity rows: 25, in this exact ordered accessibility text:

```text
Delivery record updated, Last seen Aug 29, 2026 at 7:01 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 7:01 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 7:01 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 7:00 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 7:00 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 7:00 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 6:57 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 6:57 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 6:56 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:56 PM, Open project dashboard
Delivery record updated, RR-R9, Last seen Aug 29, 2026 at 6:56 PM, Represent the approved RR-R9 active-phase-selection work on its governing phase board; RR-R9 remains reopened for the XCTest-host isolation correction., Lane · In progress
Delivery record updated, Last seen Aug 29, 2026 at 6:54 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 6:51 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 6:51 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:51 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:49 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:49 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:49 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 6:48 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:48 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:41 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:40 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:37 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:37 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:37 PM, Open project dashboard
```

## Ordinary seven-suite XCTest selection

First fresh root: `/tmp/ReleaseRadar-RR-R9C-QA-eVHdm1`.

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-QA-eVHdm1 \
  -resultBundlePath /tmp/ReleaseRadar-RR-R9C-QA-eVHdm1/RR-R9C-seven-suite.xcresult \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests \
  -only-testing:ReleaseRadarTests/DashboardProjectionTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  -only-testing:ReleaseRadarTests/EndToEndAcceptanceTests
```

The result bundle is at
`/tmp/ReleaseRadar-RR-R9C-QA-eVHdm1/RR-R9C-seven-suite.xcresult`.
`xcresulttool` reports `result: Failed`, 150 total, 146 passed, 4 failed,
0 skipped, and 0 expected failures. The command's semantic exit was nonzero
because of those four test failures; the execution wrapper yielded before it
retained the numeric terminal status. A second identical fresh-root capture
at `/tmp/ReleaseRadar-RR-R9C-QA-exit-TodKWF` emitted `** TEST FAILED **` and
the same 146/4/0 result; its result bundle is
`/tmp/ReleaseRadar-RR-R9C-QA-exit-TodKWF/RR-R9C-seven-suite.xcresult`.

Per-suite totals from the first result bundle:

| Suite | Passed | Failed | Skipped | Result |
| --- | ---: | ---: | ---: | --- |
| `StoreAcceptanceTests` | 29 | 0 | 0 | Passed |
| `AgentBridgeAcceptanceTests` | 19 | 0 | 0 | Passed |
| `AgentBridgeTransportAcceptanceTests` | 5 | 0 | 0 | Passed |
| `DashboardProjectionTests` | 10 | 0 | 0 | Passed |
| `AppRouteTests` | 55 | 0 | 0 | Passed |
| `NotificationAcceptanceTests` | 24 | 0 | 0 | Passed |
| `EndToEndAcceptanceTests` | 4 | 4 | 0 | Failed — known fixture drift |

The four and only four failures are the previously known End-to-End fixture
drift; none is attributed to the XCTest-host correction:

1. `testCurrentSchemaMissingCriticalForeignKeyFailsClosedWithoutMutation()` —
   expected schema `9`, observed `10`.
2. `testCurrentSchemaWithWrongCriticalIndexFailsClosedWithoutMutation()` —
   expected schema `9`, observed `10`.
3. `testRelaunchRepairsObservedVersionSevenOwnerSchemaDrift()` — the legacy
   fixture encounters existing `codex_plugin_lifecycle` during migration.
4. `testRelaunchRepairsVersionThreeDatabaseMissingAuditAttribution()` — the
   version-3 fixture is not a recognized current schema.

## Public XCTestHostIsolation diagnostics

The following raw unified-log lines are from the final second ordinary run
(start `2026-08-29 19:52:30`). Each path is in the process temporary directory
inside the test host's sandbox, has its own PID directory, ends in
`release-radar.sqlite`, and is not an owner Application Support database path.

```text
2026-08-29 19:53:06.850 Df ReleaseRadar[8554:101f014] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8554/release-radar.sqlite for PID 8554
2026-08-29 19:53:07.550 Df ReleaseRadar[8556:101f0f6] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8556/release-radar.sqlite for PID 8556
2026-08-29 19:53:07.668 Df ReleaseRadar[8558:101f0ff] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8558/release-radar.sqlite for PID 8558
2026-08-29 19:53:07.783 Df ReleaseRadar[8559:101f103] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8559/release-radar.sqlite for PID 8559
2026-08-29 19:53:07.912 Df ReleaseRadar[8560:101f107] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8560/release-radar.sqlite for PID 8560
2026-08-29 19:53:08.042 Df ReleaseRadar[8561:101f112] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8561/release-radar.sqlite for PID 8561
2026-08-29 19:53:08.170 Df ReleaseRadar[8562:101f11d] [com.rekonlabs.ReleaseRadar:XCTestHostIsolation] Using isolated XCTest host database /Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-8562/release-radar.sqlite for PID 8562
```

## Installed owner UI — after

Read only through Computer Use after both test hosts exited. Navigation to the
Phase Board and Activity was the only UI action; the Active phase control was
not opened or selected.

- Active phase value: `Post-MVP reported-defect remediation`.
- Visible Activity rows: 25, byte-for-byte/field-for-field equal to the before
  snapshot. Computer Use compared the raw phase and Activity accessibility
  strings directly: `phaseSnapshotEqual: true`, `activitySnapshotEqual: true`.

```text
Delivery record updated, Last seen Aug 29, 2026 at 7:01 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 7:01 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 7:01 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 7:00 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 7:00 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 7:00 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 6:57 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 6:57 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 6:56 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:56 PM, Open project dashboard
Delivery record updated, RR-R9, Last seen Aug 29, 2026 at 6:56 PM, Represent the approved RR-R9 active-phase-selection work on its governing phase board; RR-R9 remains reopened for the XCTest-host isolation correction., Lane · In progress
Delivery record updated, Last seen Aug 29, 2026 at 6:54 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 6:51 PM, Owner selected active phase RR-ROADMAP
Delivery record updated, Last seen Aug 29, 2026 at 6:51 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:51 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:49 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:49 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:49 PM, Owner selected active phase release-radar-post-mvp-remediation
Delivery record updated, Last seen Aug 29, 2026 at 6:48 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:48 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:41 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:40 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:37 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:37 PM, Open project dashboard
Delivery record updated, Last seen Aug 29, 2026 at 6:37 PM, Open project dashboard
```

## Findings

- Required: none.
- Optional: none.
- Known non-blocking limitation: the selected End-to-End suite retains the four
  pre-existing fixture failures listed above. They were reproduced but not
  changed under this correction.

## Temporary artifacts

The two fresh DerivedData/result/log roots are temporary and outside the
repository: `/tmp/ReleaseRadar-RR-R9C-QA-eVHdm1` and
`/tmp/ReleaseRadar-RR-R9C-QA-exit-TodKWF`. They are not deliverables and were
not deleted. The requested scratch report above is also non-authoritative;
Delivery Management alone may copy the relevant evidence into
`docs/delivery/progress.md` after all independent approvals.
