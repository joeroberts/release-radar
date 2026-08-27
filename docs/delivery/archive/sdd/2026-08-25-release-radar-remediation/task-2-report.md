# RR-R2 Implementer Report

## Result

- Review Resolve and Dismiss now fail closed unless the project's persisted bookmark resolves to its saved canonical root and security-scoped access remains active for the complete owner command dispatch.
- Recovery distinguishes same-root reauthorization from confirmed first-root association, rejects mismatches and globally owned roots, and never resolves or dismisses the review item automatically.
- Recoverable folder failures expose a keyboard-accessible Locate / Reauthorize or Associate action. Resolve and Dismiss remain disabled until recovery succeeds, after which an explicit retry is required.
- Bookmark failure, reauthorization, and first-root association audits use bounded fixed reasons and project scope; no path or bookmark bytes are included.

## Files changed

- `ReleaseRadarCore/Onboarding/ProjectBookmarkStore.swift`
- `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- `ReleaseRadar/App/AppModel.swift`
- `ReleaseRadar/Navigation/SidebarView.swift`
- `ReleaseRadar/Review/NeedsReviewView.swift`
- `ReleaseRadar/Shared/FailureStateView.swift`
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- `ReleaseRadarTests/AppRouteTests.swift`
- `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`

`SidebarView.swift` contains only the required recovery callback wiring. `ReviewAndGraphAcceptanceTests.swift` contains only the bookmark collaborator required for its existing `AppModel` review-decision fixtures after the new fail-closed gate.

## TDD evidence

- RED: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests`
  - Exit 65 as expected after the focused tests were added: `ProjectAuthorizationError`, `withAuthorizedProject`, `reauthorizeProjectRoot`, and `associateFirstProjectRoot` did not exist.
- GREEN: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests`
  - Exit 0; all 36 focused tests passed (16 onboarding, 10 route, 10 review/graph).
- Debug build: `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -derivedDataPath DerivedData build`
  - Exit 0.

## Runtime evidence

### Invalid evidence — do not use for acceptance

- The initial Computer Use run entered the owner app container after the attempted `CFFIXED_USER_HOME` isolation was ignored. Although the implementer reported reversing its fixture changes, that run is invalid as RR-R2 runtime evidence and must not be cited for acceptance.
- Fix round 1 did not launch the app and did not inspect or mutate any application/container database.

## Required fix round 1

- Root cause: authorization recovery was one global enum, and `recoverReviewAuthorization(at:for:)` trusted the callback project ID. A recovery originating in project A could therefore disable project B's review UI and reauthorize project B when invoked through a mismatched callback.
- Root cause: successful review dispatch and successful authorization mutation shared a `do/catch` with projection refresh. A refresh error after commit was therefore presented as a failed decision or failed authorization and could invite a duplicate retry.
- RED: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r2-fix1-red -only-testing:ReleaseRadarTests/AppRouteTests`
  - Exit 65 as expected: the scoped recovery/failure accessors and injected review projection loader did not exist.
- GREEN: `xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r2-fix1-green -only-testing:ReleaseRadarTests/AppRouteTests`
  - Exit 0; all 12 AppRoute tests passed, including cross-project callback isolation and committed-review refresh failure.
- Final affected verification: `xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r2-fix1-final -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests -only-testing:ReleaseRadarTests/AppRouteTests -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests`
  - Exit 0; all 38 selected tests passed (16 onboarding, 12 route, 10 review/graph).
- `git diff --check` passed.
- Recovery, failure, and in-progress state are now keyed by their originating `ProjectID`; another project's view receives no failure/recovery/disabled state and a mismatched recovery callback performs no mutation or audit.
- A committed review decision is applied to the in-memory inbox before projection refresh. A later refresh error presents `review-refresh-failed` with truthful saved/reload guidance, leaves no recovery action, and does not leave the committed item open for a duplicate retry.
- A successful authorization mutation clears recovery before reload. Its nested reload failure path presents the same refresh-only state and cannot restore the already-consumed authorization action.

## Remaining risk

- No valid live runtime evidence exists from the initial implementation. Independent QA must use a genuinely isolated app container for any replacement runtime inspection.
- Same-root reauthorization is covered by the focused fake-bookmark tests but still requires independent QA against a genuinely stale macOS bookmark.
- Independent code review, QA, architecture, and security/privacy verification remain required by the task brief.
