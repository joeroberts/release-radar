# RR-R9B Implementer report

## Status

IMPLEMENTED — the serialized RR-R9B owner selector/reload/recovery/runtime-
fixture slice, its required review-loop corrections, and focused automated
evidence are ready for independent review. This is Implementer evidence, not
independent acceptance. Code Review, QA, Architecture, Security/Privacy, TPM,
and Delivery Management decisions remain outside Implementer authority;
RR-R9C and live RR-ROADMAP activation remain closed.

## Files changed

- Created `ReleaseRadar/Projects/ActivePhaseSelector.swift`
- Created `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`
- Modified `ReleaseRadar/Projects/DashboardProjection.swift`
- Modified `ReleaseRadar/App/ReleaseRadarApp.swift`
- Modified `ReleaseRadar/App/AppModel.swift`
- Modified `ReleaseRadar/Projects/ProjectOverviewView.swift`
- Modified `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modified `ReleaseRadar/Navigation/SidebarView.swift`
- Modified `ReleaseRadar/Shared/FailureStateView.swift`
- Modified `ReleaseRadar/App/AppNotificationCoordinator.swift`
- Modified `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modified `ReleaseRadarTests/AppRouteTests.swift`
- Modified `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- Created `.superpowers/sdd/2026-08-29-release-radar-active-phase-selection/task-2-report.md`
  (this required non-authoritative scratch report)

The pre-existing unrelated edits in owned files were retained. No project
file, dependency, manifest, signing, bridge/plugin implementation, migration,
delivery ledger, design/ADR/plan, script, `dist/`, or other file was edited by
this Implementer. Nothing was staged, committed, pushed, installed, deployed,
or launched.

## Skill effects on implementation

- `superpowers:test-driven-development` and `writing-good-tests.md` kept the
  direct projection, AppModel, generation, authorization, coordinator-ordering,
  and Debug-fixture behaviors under XCTest before product implementation. All
  concurrency fixtures use actors and checked continuations; no test sleeps.
- `build-macos-apps:swiftui-patterns` kept one shared native menu-style Picker,
  explicit model-owned state, `ViewThatFits` responsive composition, and the
  existing five-lane/detail recovery rather than introducing custom AppKit
  control state. `phase_board.png` was inspected at original detail before the
  UI work.
- `superpowers:systematic-debugging` was applied when the saving-deduplication
  test hung. Isolation showed the test bookmark gate had been armed before the
  initial coherent load, whose read-only guidance authorization legitimately
  entered it. The test now arms the deterministic gate only after initial load;
  product code was unchanged for that diagnosis.
- `superpowers:receiving-code-review` kept the correction loop evidence-led:
  each Required finding was rechecked against the brief and current source,
  then handled individually with focused deterministic coverage before the
  corresponding product edit. The Security-loop finding was independently
  traced through the authorization-failure transaction before tests or product
  edits. No adjacent refactor or optional review idea was added.
- `superpowers:verification-before-completion` required the literal full GREEN
  command and scoped diff check from the final code state before this report.

## RED command and observed failure

The exact required RED command was run before product implementation and exited
65:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9B-RED \
  -only-testing:ReleaseRadarTests/DashboardProjectionTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  CODE_SIGNING_ALLOWED=NO
```

After correcting a test-only optional-assertion compile issue, the repeated
meaningful RED still exited 65 for the intended absent RR-R9B product surface:
`ProjectDashboardProjection` had no `activePhaseID` or `phases` members, with
the expected downstream inference errors. No tests executed because the test
target could not compile: 0 passed, 0 failed, 0 skipped. Meaningful RED result
bundle:
`/tmp/ReleaseRadar-RR-R9B-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_15-23-31--0400.xcresult`.

## Implementation delivered

- Dashboard projection now loads every same-project phase ordered by
  `name COLLATE NOCASE, id`, exposes an optional persisted active pointer, does
  not guess a board without that pointer, and keeps cards/details/counts scoped
  to the active phase while retaining truthful same-project cross-phase detail
  references.
- `AppModel.setActivePhase` applies already-active, saving, and saved-needs-
  reload guards before bookmark access and UUID generation. It dispatches the
  accepted RR-R9A command with owner origin only inside the existing exact-root
  bookmark authorization, exposes typed mutation/authorization/saved-refresh
  state, restores authorization without retrying the mutation, and makes saved
  recovery read-only.
- Full dashboard/workspace reloads now prepare dashboard, review inboxes,
  dependency graphs, Activity, guidance, roots, and visible selections before a
  single non-suspending generation-owned publication. Older success and failure
  completions publish nothing; target-matched current generations clear pending
  state and mismatches preserve it. Empty targets have no visible detail or
  dependency graph; otherwise the visible ticket is retained or reconciled to
  the lexical first target ticket. Ordinary loads freshly observe folder
  guidance, while post-command and owner saved-refresh reloads reuse the last
  published guidance/root context so those specified read-only paths cannot
  stale a bookmark or append an authorization audit.
- Project Overview and Phase Board share one native `ActivePhaseSelector`,
  including absent-pointer selection, duplicate-name ID labels, saving state,
  exact no-alternative help, inline authorization recovery, mutation failure,
  and saved-refresh reload. The board header retains card density, five lanes,
  detail inspection, and wide/compact recovery.
- Successful external command callbacks now coalesce before handler
  registration and always begin the read-only dashboard refresh before
  notification draining. Failed results enqueue no refresh work.
- The Debug-only/default-off RR-R9 capture matrix requires Debug plus the two
  existing capture flags and exactly one recognized scenario. It uses only an
  app-owned `DeliveryStore`, real production bookmark creation for disposable
  roots, intentionally missing authorization for the recovery case, isolated
  projects for mutating scenarios, and targeted busy/mutation/unavailable/
  one-shot saved-refresh faults. Same-container tests prove scenario mutations
  do not contaminate cross-phase evidence or relaunch state.

## Direct automated evidence

- Projection tests cover deterministic option order and `NOCASE` ID tie-break,
  optional no-pointer projection, active-only cards/details/counts/graph,
  cross-phase detail truth, dependency/history preservation, accepted owner
  selection, and store recreation.
- AppModel tests cover owner success/relaunch/activity/audit, no-UUID guards,
  valid/missing/stale/resolver-failed/denied/mismatched bookmarks, exact-root
  recovery without retry, direct invalid target, both no-pointer owner routes,
  empty target reconciliation, post-dashboard workspace preparation failure,
  saved read-only recovery, target match/mismatch, and continuation-gated stale
  success/failure generation order.
- Debug tests cover every recognized launch argument, partial/unknown/duplicate
  scenario rejection, duplicate capture-control-flag rejection, default-off
  behavior, deterministic/idempotent seed, initial route/accessibility states,
  real bookmark happy/empty/saved paths, all targeted fault states, one-shot
  saved recovery, absence of ordinary sample data, and mutating-scenario
  isolation across same-container relaunches.
- Coordinator tests cover pre-registration coalescing, zero drain while no
  handler exists, registered refresh-before-notification ordering, repeat
  callbacks during refresh, and a failed-result control using deterministic
  event gates.
- Security-loop AppModel/store tests cover external committed-command refresh
  and owner saved-refresh recovery across resolver failure, stale resolution,
  root mismatch, and access denial. Each failure is armed only after a
  successful ordinary load and compares exact bookmark, audit, command-receipt,
  and active-pointer rows plus cached guidance/root, dashboard, Activity,
  error, and phase status; owner recovery also proves the command is never
  retried.

## Required review-loop correction evidence

- Superseded top-level load: a continuation-gated older `loadDashboard()` and
  newer agent reload test failed at the stale Debug route mutation while its
  Activity, error, dashboard, and phase-status preservation assertions held
  (1 test, 1 failure). After requiring `.published` before all post-reload work,
  the focused rerun passed 1 of 1.
- Reauthorization recovery: the parent, child, and different-folder table test
  failed three assertions because each rejected folder removed Locate
  eligibility. After preserving recovery eligibility for an attempted
  reauthorization error, the focused rerun passed 1 of 1 and proved no active
  pointer, durable request, selection audit, total audit, or UUID-count change;
  a subsequent exact-root recovery remained actionable without auto-retry.
- Strict Debug capture flags: the parser test failed two assertions because a
  duplicate `--rr10-capture` and a duplicate `--rr10-empty-store` each selected
  `happy`. Exact-one flag guards made the focused rerun pass 1 of 1.
- Projection persistence: the focused strengthened test passed 1 of 1. The
  fixture now seeds a phase dependency and pre-existing audit row, then compares
  exact phase, ticket, phase-dependency, ticket-dependency, active-pointer,
  audit, and durable-receipt rows across store recreation. This was a
  coverage-only finding with already-correct product behavior, so no artificial
  failing assertion was introduced.

## Security review-loop correction evidence

The focused Security RED command exited 65:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9B-Security-RED \
  -only-testing:ReleaseRadarTests/AppRouteTests/testExternalCommittedRefreshReusesCachedGuidanceWithoutBookmarkOrAuditMutation \
  -only-testing:ReleaseRadarTests/AppRouteTests/testOwnerSavedRefreshReusesCachedGuidanceWithoutBookmarkAuditOrCommandRetry \
  CODE_SIGNING_ALLOWED=NO
```

Fresh `xcresulttool` summary: 2 total, 0 passed, 2 failed, 0 skipped,
0 expected failures. For all four armed authorization failures, current product
code marked the bookmark stale, appended the owner stale-authorization audit,
and replaced cached guidance/root. The owner recovery assertions confirmed the
committed command was not retried. Result bundle:
`/tmp/ReleaseRadar-RR-R9B-Security-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_16-50-20--0400.xcresult`.

After the context-aware projection preparation correction, the same focused
command with derived data at `/tmp/ReleaseRadar-RR-R9B-Security-GREEN` exited 0.
Fresh `xcresulttool` summary: 2 total, 2 passed, 0 failed, 0 skipped,
0 expected failures. Result bundle:
`/tmp/ReleaseRadar-RR-R9B-Security-GREEN/Logs/Test/Test-ReleaseRadar-2026.08.29_16-52-06--0400.xcresult`.

## Final GREEN and cleanliness evidence

Fresh final required GREEN command (exit 0):

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9B-GREEN \
  -only-testing:ReleaseRadarTests/DashboardProjectionTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  CODE_SIGNING_ALLOWED=NO
```

`** TEST SUCCEEDED **`. Fresh `xcresulttool` summary: 104 total, 104 passed,
0 failed, 0 skipped, 0 expected failures. Result bundle:
`/tmp/ReleaseRadar-RR-R9B-GREEN/Logs/Test/Test-ReleaseRadar-2026.08.29_16-52-46--0400.xcresult`.

The brief's exact scoped `git diff --check` command exited 0 with no output.

## Warnings, limitations, and remaining gates

- Final Xcode output contained only the standard multiple-matching-macOS-
  destination warning and App Intents metadata skip because that target has no
  AppIntents dependency. Neither was a test failure.
- Clean-build focused runs also surfaced the pre-existing optional `.none`
  ambiguity warning in `AgentCommandDispatcher.swift:42`; that file is outside
  this correction loop and the warning did not fail compilation or tests.
- Per the task gate, the owner app bundle was not launched and no runtime
  accessibility/screenshot comparison is claimed. RR-R9C owns the isolated
  alternate-bundle wide/compact, keyboard, accessibility, recovery, signing,
  and screenshot evidence after independent RR-R9B acceptance.
- The repository-wide suite was not substituted for or added to the brief's
  exact focused GREEN suite. Existing unrelated dirty-tree changes and their
  recorded baseline failures remain outside this slice.
- Required independent reviews remain pending. This Implementer did not review
  or approve its own implementation and does not claim RR-R9B acceptance.
- Non-authoritative temporary build/test evidence remains under
  `/tmp/ReleaseRadar-RR-R9B-RED` and `/tmp/ReleaseRadar-RR-R9B-GREEN`. It was
  not deleted because destructive cleanup was not authorized. The repository-
  root `default.profraw` predates this RR-R9B implementation session and was
  neither created nor modified by this Implementer.
