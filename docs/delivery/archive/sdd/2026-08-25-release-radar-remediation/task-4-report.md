# RR-R4 Implementer Report — Persisted Alert Rules

## Scope delivered

- Added the constrained v9 `alert_rules` authority with exactly four migrated defaults: blocked linked goals on, agent completion/review on, Needs Review on, paused goals off.
- Added the closed `AlertRuleKind`, exact-set `AlertRuleSnapshot` loader, and direct owner-only `AlertRuleStore` load/update path.
- Made no-op and failed updates audit-free. Each actual change writes one unscoped `release-radar-owner` audit with the exact bounded reason.
- Added the exhaustive six-event rule mapping and a rule guard before notification occurrence/event writes.
- Added `goalPaused` and reciprocal blocked/paused occurrence deactivation independent of whether either rule is enabled.
- Added authoritative `AppModel` load/update/retry state and four accessible Settings Toggles. Values change only after the persisted update succeeds; update failures retain the last successful snapshot.
- Did not change `AgentCommand`, `AgentCommandDispatcher`, credentials, providers, entitlements, or bridge mutation authority.
- Did not launch an app bundle or access the owner database.

## RED evidence

Command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r4-red -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests
```

Result: exit 65, as expected. The focused tests failed to compile because `AlertRuleStore`, the four rule cases, `goalPaused`, the event mapping, and AppModel alert-rule state did not exist. The test-only async autoclosure mistakes exposed by the first compile were corrected, and the repeated RED remained solely on the absent product APIs. Evidence:

- `/tmp/release-radar-rr-r4-red/Logs/Test/Test-ReleaseRadar-2026.08.25_00-40-52--0400.xcresult`
- `/tmp/release-radar-rr-r4-red/Logs/Test/Test-ReleaseRadar-2026.08.25_00-41-21--0400.xcresult`

## GREEN evidence

Focused current-source run:

```sh
xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r4-green -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests
```

Result: exit 0, 57/57 tests passed. This includes v8→v9 migration/default/reopen behavior, schema constraints, exact global audit/no-op/failure behavior, disabled-rule suppression with committed delivery state, all six mappings, reciprocal blocked/paused generations, and authoritative AppModel persistence/failure behavior.

Broader run:

```sh
xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r4-final
```

Result: 143 tests passed and one assertion failed because an existing v3-repair test still expected schema version 8. The fixture/expectation was updated for additive v9 and its exact failed test was rerun successfully:

```sh
xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r4-final -only-testing:ReleaseRadarTests/EndToEndAcceptanceTests/testRelaunchRepairsVersionThreeDatabaseMissingAuditAttribution
```

Result: exit 0, 1/1 passed. No production code changed after the 143-pass broader run.

Build:

```sh
xcodebuild build -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r4-build
```

Result: exit 0. Only the existing optional-thread-attribution and signed-binary stripping warnings appeared.

Repository check:

```sh
git diff --check
```

Result: exit 0, no whitespace errors.

## Files changed for RR-R4

- `ReleaseRadarCore/Notifications/AlertRules.swift` (new)
- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- `ReleaseRadar/App/AppModel.swift`
- `ReleaseRadar/Notifications/SettingsModels.swift`
- `ReleaseRadar/Notifications/SettingsView.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- `ReleaseRadarTests/RekonImportAcceptanceTests.swift`
- `ReleaseRadarTests/AppRouteTests.swift`
- `ReleaseRadarTests/EndToEndAcceptanceTests.swift` (mechanical v9 fixture/expectation updates)

## Required fix round 1 — genuine-entry event gating

Independent review found that suppression only inside `MeaningfulDeliveryEvent.enqueue` left no occurrence marker for a disabled entry. After re-enabling a rule, a stable same-state observation or stable-ID upsert could therefore create a retroactive alert.

The bounded fix records producer state before the existing delivery mutation and calls `enqueue` only for a genuine creation or entry:

- linked goals compare the prior observed runtime status;
- ticket upserts/transitions compare the prior lane while retaining unconditional deactivation outside Needs Review;
- review requests alert on creation or reopening after a non-open status;
- completion records alert only for a new stable ID;
- imported review items alert only when the stable record is newly created.

The existing delivery/import/observation mutation, audit, and reciprocal exit deactivation remain unconditional. No alert schema, Settings UI, owner audit contract, `AgentCommand` surface, or owner data changed.

Fresh RED:

```sh
xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r4-fix-red \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests/testLinkedGoalBlockedAndPausedOccurrencesAreReciprocalAcrossSuppressedTransitions \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests/testDisabledEntriesDoNotAlertAfterReenableUntilStableBridgeRecordsEnterAgain \
  -only-testing:ReleaseRadarTests/RekonImportAcceptanceTests/testApplyAtomicallyEnqueuesOpenImportReviewsOnlyAfterDashboardOpened
```

Result: exit 65 with the intended behavioral failures. A stable goal observation produced 4 blocked events instead of 3; stable review/completion/ticket producers produced 3 events instead of 0; and stable import reapply produced 4 events instead of the one genuinely new review.

Fresh GREEN with the same command at `/tmp/release-radar-rr-r4-fix-green`: exit 0, 3/3 passed.

Focused producer-boundary suites:

```sh
xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/release-radar-rr-r4-fix-focused \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/RekonImportAcceptanceTests \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Result: exit 0, 71/71 passed.

Fresh build at `/tmp/release-radar-rr-r4-fix-build`: exit 0. `git diff --check`: exit 0. Only the already-recorded source/signing warnings and an unrelated passcode-protected-device discovery warning appeared. No app was launched and no owner database was accessed.

## Remaining verification / risk

- Independent QA still must inspect the four Toggle accessibility values, persistence across a real alternate-bundle relaunch, in-flight disabled state, and visible retry behavior. This implementer did not perform Computer Use.
- Independent code, architecture, and security/privacy review remain required.
- The existing compiler/test warnings listed above are unchanged and out of RR-R4 scope.
