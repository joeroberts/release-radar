# Release Radar Task 7B Implementer Report

## Status

`DONE_WITH_CONCERNS`

The bounded Task 7B implementation is complete in the four assigned files. Focused and full tests pass and the configured Debug build succeeds. The concern is limited to runtime visual evidence: the isolated alternate bundle launched and exposed the expected landing/initialize accessibility state, but the Computer Use native pipe closed immediately after the open-panel handoff, preventing the requested multi-size screenshot/AX matrix and confirmed-save/resume live walkthrough. No owner bundle, owner database, Keychain, bridge, notification path, or external service was launched or inspected.

## Scope and Files Changed

- `ReleaseRadar/Projects/OnboardingView.swift`
- `ReleaseRadar/Shared/FailureStateView.swift`
- `ReleaseRadarTests/AppRouteTests.swift`
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift`

No other file was edited, staged, committed, reformatted, or reverted. `docs/delivery/progress.md` was not changed.

## Test-First RED Evidence

The amended presentation, persistence, resume, read-only status, phase gate, and clipboard tests were added before production code. After correcting test-only autoclosure/actor issues, a fresh DerivedData run failed solely because the production handoff type did not exist:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-red.QhHTAi \
  -resultBundlePath /tmp/release-radar-7b-red.QhHTAi/task-7b-red.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests
```

Result bundle: `/tmp/release-radar-7b-red.QhHTAi/task-7b-red.xcresult`

- Status: failed as expected before production implementation.
- Compiler errors: two `Cannot find 'CodexPromptHandoff' in scope` failures in `OnboardingAcceptanceTests.swift`.
- Test summary reports zero executed tests because compilation stopped first; the build-results payload records `status: failed`, `errorCount: 3`, including the expected cancellation wrapper and the two missing-production-API errors.

## Implementation Delivered

### Local SwiftUI workflow and truthful commit boundary

- Added view-local `landing`, `initialize`, and `attach` workflow state.
- The Add Project landing presentation contains exactly `Initialize Project Tracking` and `Attach Folder to Existing Project`; Portable Import and Help are absent.
- Folder selection remains preview-only. The confirmation explicitly names the project and folder, shows the selected path, says local tracking/folder authorization will be saved, and says repository files are not modified.
- Back and Cancel reset only local presentation state before confirmation. Escape maps to Cancel where the cancel callback exists.
- SwiftUI dismissal is disabled only while a confirmed Initialize or Attach commit is in flight.
- Initialization calls the existing `prepare` transaction exactly once and no longer invokes `requestFirstPhaseDefinition` automatically.
- `OnboardingPreparationError.seedApplicationFailedAfterSave(projectID)` is caught explicitly. The saved project ID is retained for resume, the UI says not to initialize again, and `prepare` is not retried.
- Saved and saved-incomplete states render the same Codex handoff surface. Reopening a pending folder resumes the saved project rather than creating another project/audit event.
- `Check Tracking Status` only calls the persisted phase read. `Finish Initialization` stays disabled until that read observes a phase, while the existing `finish` boundary still rechecks persistence.
- Existing Attach callbacks/transaction implementation were not changed; only local workflow entry/back presentation was added around the existing path.

### Exact Codex prompt and clipboard behavior

The immutable approved prompt is one UTF-8 line and is 460 bytes:

```text
Define the current Release Radar tracking state for this project. Through Release Radar's existing typed inbound bridge, create or update the active phase and the work currently in scope. Record truthful ticket outcomes, lanes, dependencies, blockers, evidence, and Codex links only when known. Do not create or edit repository dashboard files, do not infer canonical state from arbitrary Markdown, and send uncertain items to Needs Review instead of guessing.
```

- Icon-only SF Symbol: `square.on.square`.
- Accessibility label/help: `Copy Codex prompt`.
- Accessibility identifier: `onboarding-copy-codex-prompt`.
- Disclosure: only the prompt is copied and it remains until replaced.
- Success and failure both produce visible text and an accessibility announcement.
- Copy state is cleared before each attempt; a failed writer therefore cannot leave or report stale UI success.
- AppKit remains the narrow `NSPasteboard.general` writer edge plus the pre-existing `NSOpenPanel` edges. Presentation state and announcements remain SwiftUI-owned.

The success test creates a unique `NSPasteboard(name:)`, copies through the real production `CodexPromptHandoff.copy` function, reads the string back, and compares `Data(copied.utf8)` byte-for-byte with both the independently repeated approved prompt and the production constant. The failure test first injects `true`, then injects `false`, and proves the second result/announcement is `.failed` / `Codex prompt could not be copied`, not the prior success.

## GREEN Verification

### Focused Task 7B suites

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-green.8JsyGL \
  -resultBundlePath /tmp/release-radar-7b-green.8JsyGL/task-7b-focused.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests
```

Result: **48 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-green.8JsyGL/task-7b-focused.xcresult`

### Full suite

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-full.4ENkd0 \
  -resultBundlePath /tmp/release-radar-7b-full.4ENkd0/task-7b-full.xcresult
```

Result: **163 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-full.4ENkd0/task-7b-full.xcresult`

### Configured Debug build

```sh
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-build.n7YuXQ \
  -resultBundlePath /tmp/release-radar-7b-build.n7YuXQ/task-7b-debug-build.xcresult
```

Result: **BUILD SUCCEEDED**, `errorCount: 0`.

Result bundle: `/tmp/release-radar-7b-build.n7YuXQ/task-7b-debug-build.xcresult`

Four build warnings were pre-existing/non-Task-7B: the existing `Optional<ThreadAttribution>.none` inference warning and three signed-binary stripping warnings.

### Final owned-file hygiene

```sh
git diff --check -- \
  ReleaseRadar/Projects/OnboardingView.swift \
  ReleaseRadar/Shared/FailureStateView.swift \
  ReleaseRadarTests/AppRouteTests.swift \
  ReleaseRadarTests/OnboardingAcceptanceTests.swift
```

Result: clean, exit 0.

## Persistence, Audit, No-Action, Sentinel, and Attach Evidence

The focused/full passing suites directly exercise the following properties:

- `testInitializePreviewAbandonedBeforeConfirmationLeavesStoreAndRepositoryUnchanged`
  - snapshots every relevant database table before/after preview;
  - proves no persisted project/root/bookmark/audit change;
  - proves a sentinel file is byte-identical and the folder listing is identical.
- `testInitializeProjectTrackingPersistsOnlyResumableBaseStateWithoutChangingRepository`
  - proves exactly one project, root, fresh bookmark, pending marker, and prepare audit;
  - proves zero phases, phase-request markers, agent command requests, notification events, and notification occurrences;
  - proves sentinel bytes and folder listing are unchanged;
  - relaunches the store, resumes the same project ID, and proves prepare audit count remains one.
- `testRecognizedSeedRevalidationFailureReportsSavedIncompleteWithoutPartialImport`
  - proves the typed saved-incomplete error exposes the saved project ID;
  - proves base state/audit persists exactly once while no partial phase/ticket/dependency/evidence/import audit, agent request, or notification state appears;
  - proves relaunch resumes the same ID with no second prepare/import audit.
- `testCheckTrackingStatusIsReadOnlyAndFinishRechecksPersistedPhase`
  - database snapshot is unchanged by `hasFirstPhase`;
  - finish fails with `.noFirstPhase` before typed inbound phase data;
  - after the existing typed dispatcher creates a phase, status observes it and finish succeeds;
  - the UI path itself creates no phase-request marker or agent command request.
- Existing Attach regression coverage remained green, including preservation of the populated project graph, exactly one redacted owner audit for the authorization, relaunch persistence, symlink ownership rollback, and root-only/bookmark-only/paired fail-closed states. The Attach callback/transaction implementation was not edited.

## Isolated Live / Visual / Accessibility Attempt

### Isolation controls

The live attempt used a separately built app bundle and disposable folder only:

```sh
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-live.jP7hbl \
  PRODUCT_BUNDLE_IDENTIFIER=com.rekonlabs.ReleaseRadar.Task7B

open -n /tmp/release-radar-7b-live.jP7hbl/Build/Products/Debug/ReleaseRadar.app \
  --args --rr10-capture --rr10-empty-store
```

- Built bundle ID verified as `com.rekonlabs.ReleaseRadar.Task7B`.
- App sandbox entitlement verified present.
- Capture mode suppressed external services; empty-store mode suppressed sample persistence.
- Disposable folder: `/tmp/release-radar-7b-folder.xHkzC4`.
- Alternate container database only: `/Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar.Task7B/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/release-radar.sqlite`.
- The owner Release Radar bundle/database, shared Keychain, inbound bridge, notification delivery, and external services were not launched, accessed, or exercised.

### Direct observations

Computer Use accessibility inspection observed:

- isolated `Projects` window;
- heading `Add a project` and description `Choose how this folder-backed project should join Release Radar.`;
- `Initialize Project Tracking` with identifier `onboarding-initialize-project`;
- after activation: `Back` with `onboarding-back`, heading `Initialize Project Tracking`, preview-only instructions, and `Choose Project Folder…`;
- open panel prompt `Choose Project`, navigated only to the disposable folder.

The initial captured app screenshot was 1499×768 pixels at the current desktop/window state. It visually showed the running isolated UI, but this is not evidence of the requested exact 760×520 or 900×650 window sizes.

Immediately after choosing the disposable folder, the Computer Use native pipe closed. A changed-condition retry after resetting the Node/Computer Use session failed the same way, so the runtime inspection stopped rather than repeatedly retrying. Consequently, no defensible live claim is made for:

- exact 760×520, 900×650, or wide responsive screenshots;
- runtime confirmation/handoff/copy-success state;
- runtime red-close/Cancel/Escape matrix;
- runtime confirmed-save/relaunch/resume state.

After the failed picker handoff, read-only inspection of the **alternate** database proved:

- `projects = 0`
- `project_roots = 0`
- `audit_events = 0`
- `agent_command_requests = 0`

The disposable sentinel SHA-256 remained `981b411924ef930a16c071a0176848fbc2856487f445796355ddede6d9244913`, and the folder listing still contained only `owner-sentinel.txt`. This directly corroborates preview/no-confirmation no-action for the live attempt. The exact alternate app process was then terminated; no owner process was targeted.

An earlier alternate-build experiment that overrode `PRODUCT_NAME` caused helper output-name collisions and did not produce or launch an app. The retry narrowed the override to the bundle identifier and succeeded; no repository or owner data changed.

## Self-Inspection and Concerns

- Inspected the owned-file diff and reran owned-file `git diff --check`; no whitespace errors were found.
- Searched the production onboarding view for `requestFirstPhaseDefinition`; there is no UI invocation. Two references remain in historical tests that explicitly exercise the core API, as required.
- The approved prompt is duplicated independently in the byte-exact test so the test does not derive its expected bytes from the production constant.
- Production AppKit usage added by this task is limited to the pasteboard write; the existing open-panel boundary remains unchanged.
- The embedded empty-project runtime surface had no attach loader and therefore exposed only Initialize. The `AddProjectWindowView` supplies the attach callbacks/loader, and the production landing presentation plus tests verify the required two-action Add Project contract. The unavailable Computer Use pipe prevented opening and directly observing that separate Add Project window in this run.
- I did not independently approve or review my own implementation. Independent code review, QA, architecture, and controller ledger updates remain for the coordinating agents.

# Task 7B Fix Round 1/5 — Required Findings

## Scope and Controlling Ruling

This round changed only the already-owned Task 7B files plus the controller-authorized obsolete assertions in `ReleaseRadarTests/FailureStatePresentationTests.swift`. `ProjectsView`, Attach callbacks/transactions, the historical `requestFirstPhaseDefinition` core API/tests, schema/store/authorizer/importer/bridge/project settings, and the delivery ledger were not edited. Help and Portable Import remain absent.

The controller-provided baseline for `FailureStatePresentationTests.swift` was `/tmp/release-radar-7b-before.xss0Lv/ReleaseRadarTests/FailureStatePresentationTests.swift`. A final `diff -u` proved that only the obsolete onboarding title/detail test was replaced; the remaining tests in that file are byte-for-byte unchanged.

## Finding 1: Shared Onboarding Presentation Copy

### RED

The regression was written first and directly exercised every active shared presentation/mapping that could expose the superseded terminology:

- `FailureStatePresentation.noDeliveryStructure`
- `FailureStatePresentation.firstPhaseRequired`
- `FailureStatePresentation.trackingStateRequired`
- `FailureStatePresentation(onboardingError: .noFirstPhase)`
- `FailureStatePresentation(onboardingError: .projectNotPrepared)`
- the existing invalid-folder assertions were retained

Command:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-copy-red.kc1ihS \
  -resultBundlePath /tmp/release-radar-7b-fix1-copy-red.kc1ihS/copy-red.xcresult \
  -only-testing:ReleaseRadarTests/FailureStatePresentationTests/testOnboardingStatesUseInitializationAndTrackingStateTerminology
```

Expected result: **1 failed, 0 passed**. The failures were the intended old production copy/mapping, including `No delivery structure yet` versus `Project tracking not initialized` and `First phase required` versus `Tracking state required`.

Result bundle: `/tmp/release-radar-7b-fix1-copy-red.kc1ihS/copy-red.xcresult`

### Fix

- `.noDeliveryStructure` now directs the owner to **Initialize Project Tracking** and describes the current **tracking state**.
- `.firstPhaseRequired` now uses **Tracking state required**, the Codex prompt, and **Check Tracking Status** terminology.
- `.noFirstPhase` and `.projectNotPrepared` now map to `.trackingStateRequired` instead of the superseded first-phase presentation.
- Existing accessibility identifiers and historical core APIs remain unchanged.

The final production scan:

```sh
rg -n -i "ask an agent|first phase" ReleaseRadar/Shared/FailureStateView.swift
```

returned no matches.

## Finding 2: Mounted Production Onboarding Copy Action

### Initial RED and Technical Evidence

The first real-view regression mounted `OnboardingView` with an injected writer and attempted to enter the saved handoff state without using `NSOpenPanel`. Before the production state seam existed it failed to compile for exactly the intended reason:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-view-red.iXO39l \
  -resultBundlePath /tmp/release-radar-7b-fix1-view-red.iXO39l/view-red.xcresult \
  -only-testing:ReleaseRadarTests/AppRouteTests/testMountedOnboardingCopyActionReplacesVisibleSuccessWithAccessibleFailure
```

Expected result: build failed with `Extra argument 'initialHandoffProjectID' in call`.

Result bundle: `/tmp/release-radar-7b-fix1-view-red.iXO39l/view-red.xcresult`

The smallest state seam added was `initialHandoffProjectID: ProjectID? = nil`. It initializes only the view-local workflow/project state, leaves all production callers unchanged, and lets a mounted test enter the real saved/handoff presentation without a native folder picker or another persistence write.

### In-process AX limitation and proportional seam

The first mounted implementation tried to find and press the production SwiftUI button through AppKit accessibility. Concrete checks included `NSHostingView` and `NSHostingController`, view/window roots, AppKit AX children/visible children/contents, unignored children, platform subviews, activated and non-activated test windows, 760×520 and 760×900 viewports, and an explicit SwiftUI accessibility container. In this unit-test host every variant exposed only the selectable 460-byte prompt; the SwiftUI button and result text were not vended as traversable AppKit AX elements. The representative retained failure bundle is `/tmp/release-radar-7b-fix1-direct-green.f5HTtF/direct-green3.xcresult`. The traversal/container experiments were removed rather than retained as test infrastructure.

The replacement is one optional, view-local `copyActionRegistrar`, defaulting to `nil`. On appearance it registers the exact private `copyCodexPrompt` closure used by the production icon button. The closure writes through the already-injected writer, clears and replaces SwiftUI-owned `@State`, posts the production accessibility announcement, and returns the same result stored by the view. It adds no service, framework, global state, AppKit edge, or production caller requirement.

The registrar seam itself was test-first:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-registrar-red.Q6XoVH/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix1-registrar-red.Q6XoVH/registrar-red.xcresult \
  -only-testing:ReleaseRadarTests/AppRouteTests/testMountedOnboardingCopyActionReplacesVisibleSuccessWithAccessibleFailure
```

Expected result: build failed with `Extra argument 'copyActionRegistrar' in call`.

Result bundle: `/tmp/release-radar-7b-fix1-registrar-red.Q6XoVH/registrar-red.xcresult`

The final result-returning action assertion was also RED before the minimum action change:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-render-red.S18fcw/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix1-render-red.S18fcw/render-red.xcresult \
  -only-testing:ReleaseRadarTests/AppRouteTests/testMountedOnboardingCopyActionReplacesVisibleSuccessWithAccessibleFailure
```

Expected result: build failed because the mounted production action still returned `Void`, not `CodexPromptCopyResult`.

Result bundle: `/tmp/release-radar-7b-fix1-render-red.S18fcw/render-red.xcresult`

### Direct GREEN and What It Proves

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-ax.JpSsb7/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix1-render-green.M4I4yt/render-green.xcresult \
  -only-testing:ReleaseRadarTests/AppRouteTests/testMountedOnboardingCopyActionReplacesVisibleSuccessWithAccessibleFailure
```

Result: **1 passed, 0 failed**.

Result bundle: `/tmp/release-radar-7b-fix1-render-green.M4I4yt/render-green.xcresult`

The test:

- inserts a real saved project and `onboarding_pending` handoff marker into a disposable store;
- mounts the actual production `OnboardingView` in an `NSHostingController`/`NSWindow` at 900×650;
- obtains the exact action used by the real copy button from the mounted view;
- injects writer outcomes `[true, false]` and invokes the action twice;
- proves result/accessibility announcement transitions from `.copied` / `Codex prompt copied` to `.failed` / `Codex prompt could not be copied`;
- proves the failure result replaces, rather than reuses, success;
- proves the writer received the immutable production prompt twice and consumed both outcomes;
- captures the mounted view in memory after each state and proves the success and failure rendered PNG bytes differ.

No snapshot files, UI-test target, ViewInspector, framework, global service, owner bundle, owner database, Keychain, bridge, notifications, or external service were used.

The original byte-exact clipboard acceptance remains green in the focused/full suites. It uses a unique `NSPasteboard(name:)`, reads back **460 UTF-8 bytes**, and compares those bytes to an independently repeated approved prompt. Its injected false path still proves `.failed` / `Codex prompt could not be copied` with no stale success.

## Fresh GREEN Verification After Both Fixes

### Focused suites

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-focused.7AFA5E/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix1-focused.7AFA5E/focused.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/FailureStatePresentationTests
```

Result: **54 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-fix1-focused.7AFA5E/focused.xcresult`

### Full suite

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-full.bO1qYs/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix1-full.bO1qYs/full.xcresult
```

Result: **164 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-fix1-full.bO1qYs/full.xcresult`

### Configured Debug build

```sh
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix1-build.wzh4EX/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix1-build.wzh4EX/build.xcresult
```

Result: **BUILD SUCCEEDED**.

Result bundle: `/tmp/release-radar-7b-fix1-build.wzh4EX/build.xcresult`

### Integrity checks

```sh
git diff --check -- \
  ReleaseRadar/Projects/OnboardingView.swift \
  ReleaseRadar/Shared/FailureStateView.swift \
  ReleaseRadarTests/AppRouteTests.swift \
  ReleaseRadarTests/OnboardingAcceptanceTests.swift \
  ReleaseRadarTests/FailureStatePresentationTests.swift
```

Result: no output; no whitespace errors.

`git status --short` confirmed the substantial pre-existing accepted/user changes are still present. None were reverted, staged, committed, reformatted, or attributed to this fix. The delivery ledger remains controller-owned and was not edited in this round.

## Fix-Round Files Changed

- `ReleaseRadar/Projects/OnboardingView.swift`
- `ReleaseRadar/Shared/FailureStateView.swift`
- `ReleaseRadarTests/AppRouteTests.swift`
- `ReleaseRadarTests/FailureStatePresentationTests.swift` (only the controller-authorized obsolete expectations)

`ReleaseRadarTests/OnboardingAcceptanceTests.swift` remains changed from the original Task 7B implementation and was included in focused/full/diff verification; no additional fix-round edit was necessary there.

## Final Self-Inspection and Concerns

- The shared presentation regression covers both named shared constants and both active onboarding-error mappings; a production scan finds no remaining superseded owner-facing first-phase/ask-an-agent copy in `FailureStateView.swift`.
- `OnboardingView.swift` contains no `requestFirstPhaseDefinition` invocation. The core historical API/tests were not changed.
- The mounted test does not call `CodexPromptHandoff.copy` directly. It drives the exact action registered by the mounted production view; the same function is the real icon button action.
- The optional registrar remains the only new action seam, defaults to `nil`, and does not own presentation state or introduce another AppKit boundary.
- Direct in-process AX traversal of SwiftUI controls is a documented harness limitation. The test therefore combines the exact production accessibility announcement result with two distinct in-memory renderings; an independent runtime/UI review may still directly inspect the external AX tree.
- I did not independently approve or review my own fix. Independent code review, QA, architecture review, and controller ledger updates remain with the coordinating agents.

# Task 7B Fix Round 2/5 — Proportionality Cleanup

## Controller Ruling Applied

This section supersedes the Fix Round 1 mounted-view seam/harness implementation and its associated completion concern. The following were removed completely:

- production `initialHandoffProjectID`;
- production `copyActionRegistrar`;
- the temporary result return from `copyCodexPrompt` (restored to `Void`);
- the mounted `NSHostingController`/render comparison regression;
- the now-unused test `SwiftUI` import and mounted-view settle/render helpers.

No replacement UI-test target, launch flag, debug state, dependency, framework, snapshot machinery, service, or alternate test harness was added. `OnboardingView` again begins from its normal local `.landing`/nil-project state for every production caller.

Retained unchanged:

- the writer-only `pasteboardWriter` seam;
- the unique-`NSPasteboard(name:)` 460-byte exact success/readback contract;
- the injected `false` failure and prior-success replacement contract;
- the visible/accessibility success/failure production presentation;
- every actual Task 7B initialization, persistence, saved-incomplete, resume, status, Finish, dismissal, and Attach behavior;
- the Fix Round 1 tracking-state terminology production fix and `FailureStatePresentationTests` regression.

## Targeted Verification After Harness Removal

After removing the mounted test/import/helpers, and before removing the corresponding production seams, the remaining AppRoute suite was run in fresh DerivedData:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix2-test-cleanup.F81y4Y/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix2-test-cleanup.F81y4Y/app-route.xcresult \
  -only-testing:ReleaseRadarTests/AppRouteTests
```

Result: **23 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-fix2-test-cleanup.F81y4Y/app-route.xcresult`

This run explicitly included and passed:

- `testCodexPromptCopyWritesExactApprovedBytesAndReturnsAccessibleSuccess`
- `testCodexPromptCopyFailureReplacesPriorSuccessWithoutReportingCopied`

## Focused Verification After Production Seam Removal

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix2-focused.lfduws/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix2-focused.lfduws/focused.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/FailureStatePresentationTests
```

Result: **53 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-fix2-focused.lfduws/focused.xcresult`

The count is one lower than Fix Round 1 because the controller-directed mounted harness test was removed.

## Full Suite

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix2-full.ZAtLRc/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix2-full.ZAtLRc/full.xcresult
```

Result: **163 passed, 0 failed, 0 skipped, 0 expected failures**.

Result bundle: `/tmp/release-radar-7b-fix2-full.ZAtLRc/full.xcresult`

The count is restored to the original Task 7B full-suite baseline after removing the one mounted harness test.

## Configured Debug Build

```sh
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-7b-fix2-build.hAThBc/DerivedData \
  -resultBundlePath /tmp/release-radar-7b-fix2-build.hAThBc/build.xcresult
```

Result: **BUILD SUCCEEDED**.

Result bundle: `/tmp/release-radar-7b-fix2-build.hAThBc/build.xcresult`

## Final Integrity Evidence

```sh
git diff --check -- \
  ReleaseRadar/Projects/OnboardingView.swift \
  ReleaseRadar/Shared/FailureStateView.swift \
  ReleaseRadarTests/AppRouteTests.swift \
  ReleaseRadarTests/OnboardingAcceptanceTests.swift \
  ReleaseRadarTests/FailureStatePresentationTests.swift
```

Result: no output; no whitespace errors.

The following cleanup scan returned no matches:

```sh
rg -n "initialHandoffProjectID|copyActionRegistrar|testMountedOnboarding|NSHostingController|settleMountedView|renderedPNGData" \
  ReleaseRadar/Projects/OnboardingView.swift \
  ReleaseRadarTests/AppRouteTests.swift
```

The retained-contract scan found only the expected writer property/default/usage and the two byte/failure tests. The production onboarding view still contains no `requestFirstPhaseDefinition` invocation. The shared presentation and its regression still contain `Project tracking not initialized` / `Tracking state required`, with no superseded first-phase/ask-an-agent production copy.

`git status --short` confirmed that the substantial pre-existing accepted/user changes remain present. This round did not revert, stage, commit, reformat, or modify unrelated work, and did not edit the delivery ledger.

## Fix Round 2 Files Changed

- `ReleaseRadar/Projects/OnboardingView.swift`
- `ReleaseRadarTests/AppRouteTests.swift`

## Fix Round 2 Self-Inspection

- The remaining production seam is the requested writer closure only; SwiftUI continues to own `promptCopyResult` and presentation state.
- `copyCodexPrompt` clears stale state, writes through the injected writer, stores the new result, and posts the exact accessibility announcement, but exposes no test-only action or return value.
- AppKit production usage remains only the narrow `NSPasteboard.general` writer edge plus the existing `NSOpenPanel` folder pickers.
- No independent approval or review was performed by this implementer; the coordinating agents retain those roles.
