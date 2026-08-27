# RR-R5 Implementer Report

## Scope delivered

- `DependencyGraphLayout` now derives the visible set only from the selected ticket, its direct and indirect requirements, and its direct unlocks.
- The layout exposes deterministic `Foundations`, `Accepted work`, `Selected ticket`, and `Unlocks next` columns plus connector-level blocking metadata.
- Dependencies renders the selected-path count, flowing lane/relationship legend, semantic column headers, dashed separators, directional arrowheads, selected/blocked non-color cues, a right-side inspector at wide width, and a vertically stacked inspector with graph scrolling at compact width.
- Dependency nodes and inspector relationships are buttons with truthful accessibility labels and selection hints; the canvas is hidden from accessibility because the inspector supplies the relationship equivalents.
- Phase Board now owns a view-local `BoardDensity` choice with exact `Full outcomes` and `Compact density` values. Requested full mode is width-forced compact at lane widths of 180 points or less and restores automatically after widening.
- Five-lane horizontal recovery is introduced only below the existing five-lane minimum width. Compact ticket accessibility retains the complete outcome, dependency/blocker counts, and selection state.
- No projection, schema, persistence, audit, notification, bridge, permission, or owner-data code changed.

## TDD evidence

RED command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r5-red -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests
```

Result: expected failure. The test target could not compile because `DependencyGraphLayoutResult.columns`, connector `isBlocking`, and `BoardDensity` did not exist.

GREEN command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r5-green -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests
```

Result: `** TEST SUCCEEDED **`; 20 focused tests passed (11 `ReviewAndGraphAcceptanceTests`, 9 `DashboardProjectionTests`). The selected-path regression verifies exact lexical membership, excludes the unrelated branch, verifies seven endpoints and the sole blocking connector, and repeats layout equality. The density regression verifies both display names and all four 180/181-point cases.

## Isolated build evidence

```sh
xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -derivedDataPath /tmp/release-radar-rr-r5-alt PRODUCT_BUNDLE_IDENTIFIER=com.rekonlabs.ReleaseRadar.RR5QA
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /tmp/release-radar-rr-r5-alt/Build/Products/Debug/ReleaseRadar.app/Contents/Info.plist
codesign --verify --deep --strict /tmp/release-radar-rr-r5-alt/Build/Products/Debug/ReleaseRadar.app
git diff --check
```

Result: `** BUILD SUCCEEDED **`; bundle identifier is `com.rekonlabs.ReleaseRadar.RR5QA`; strict deep signature verification and diff check succeeded. The app was not launched, and the owner bundle/container/database were not accessed.

## Files owned by RR-R5

- `ReleaseRadar/Dependencies/DependencyGraphLayout.swift`
- `ReleaseRadar/Dependencies/DependencyGraphView.swift`
- `ReleaseRadar/Projects/PhaseBoardView.swift`
- `ReleaseRadar/Projects/TicketCardView.swift`
- `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`
- `ReleaseRadarTests/DashboardProjectionTests.swift`

## Known evidence limits and risks

- Computer Use, exact 1586 x 992 / 900 x 650 / 760 x 520 captures, menu interaction, keyboard traversal, and screenshot comparison remain for the independent QA verifier. No runtime visual claim is made by this implementer.
- Existing repository warnings remain: actor-isolation warnings in `ReviewAndGraphAcceptanceTests`, the optional `.none` warning in `AgentCommandDispatcher`, App Intents metadata skips, and signed-binary stripping warnings. None was introduced or expanded for RR-R5.
- The layout intentionally groups all indirect requirements into one semantic Foundations column, including explicit direct-to-selected edges that cross over Accepted work; this follows the approved four-column contract rather than reconstructing arbitrary graph depth.

## Required fix round 1

Independent review reported two Required Phase Board defects: the stacked board clipped the selected-ticket detail at 760 x 520, and macOS exposed the requested `Full outcomes` Picker selection without disclosing that compact cards were actually in effect at compact widths.

- `PhaseBoardView` now places its stacked 390-point five-lane workspace and 260-point selected-ticket detail inside a vertical recovery scroll view. The existing lane workspace remains independently horizontally scrollable, so all five lanes remain recoverable while the selected detail can be reached below them.
- The visually unchanged Picker options remain exactly `Full outcomes` and `Compact density`. Because macOS derives a menu Picker's accessible value from its selected option, the selected option now carries the truthful effective label `Full outcomes requested; showing Compact density at the current width`; the Picker also exposes the same explicit value and an AX hint explaining that the requested full mode restores automatically after widening.
- The focused regression adds only responsive-policy and accessibility-copy API assertions to the existing density test. No Dependencies, ticket-card, projection, data, persistence, audit, notification, bridge, permission, or security code changed in this fix.

RED:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r5-fix1-red -only-testing:ReleaseRadarTests/DashboardProjectionTests/testRequestedBoardDensityUsesCompactCardsAtOrBelowTheLaneWidthBoundary
```

Result: expected compile failure, exit 65, because `accessibilityOptionLabel`, `accessibilityHelp`, and `PhaseBoardLayout` did not exist. Log: `/tmp/release-radar-rr-r5-fix1-red.log`.

GREEN and preservation:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/release-radar-rr-r5-fix1-final -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests
```

Result: `** TEST SUCCEEDED **`; 20/20 RR-R5 focused tests passed with zero failures or skips. Log: `/tmp/release-radar-rr-r5-fix1-final-tests.log`. The first GREEN compile identified one SDK naming correction (`accessibilityHint` is SwiftUI's macOS AX-help modifier); the corrected direct regression then passed before the final suite.

Isolated build:

```sh
xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -derivedDataPath /tmp/release-radar-rr-r5-fix1-build PRODUCT_BUNDLE_IDENTIFIER=com.rekonlabs.ReleaseRadar.RR5FixQA
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /tmp/release-radar-rr-r5-fix1-build/Build/Products/Debug/ReleaseRadar.app/Contents/Info.plist
codesign --verify --deep --strict /tmp/release-radar-rr-r5-fix1-build/Build/Products/Debug/ReleaseRadar.app
git diff --check
```

Result: `** BUILD SUCCEEDED **`; bundle identifier `com.rekonlabs.ReleaseRadar.RR5FixQA`; strict deep signature verification and diff check passed. The app was not launched and owner data was not accessed. Independent live QA remains responsible for verifying the 760 x 520 scroll recovery and effective AX value in the accessibility tree.
