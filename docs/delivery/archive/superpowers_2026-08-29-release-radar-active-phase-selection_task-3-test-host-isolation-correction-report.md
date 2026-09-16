# RR-R9C XCTest-host isolation correction — Implementer report

## Scope and attribution

Only the two authorized source/test files were edited. The required report is
the sole additional artifact and is in the explicitly requested scratch path;
it is not a Release Radar deliverable or competing delivery ledger.

| File | Pre-edit blob | Pre-edit SHA-256 | Post-edit blob | Post-edit SHA-256 |
| --- | --- | --- | --- | --- |
| `ReleaseRadar/App/ReleaseRadarApp.swift` | `916e18c67469f60079fc8b829bdfbe6582de203b` | `e42ccab0f1aaaa0640aa546f94ba0d9f2d637d501bf3d230eb80f621348df74f` | `535abf710fe0a9ab6a1bdd23ad4ddcee38c3daad` | `23340bf3c3a6edd57aa852db7944f93b3575217ec3bc5061f450ad7eb0dc1c12` |
| `ReleaseRadarTests/AppRouteTests.swift` | `cd926cbdadaa49902d8282bd79dcd1bf401a013d` | `42583763d9a16874f09453c215a828a32882d024e3f636bcd583008212eedb01` | `e545a31b284d4e2f8aa0c02f11a2213ea9ba0b3c` | `20b8495199a4010100dc8800e4b0e00f3405389ecea36039ded8068f02bb2529` |

Exact attributable hunks, compared directly with those pre-edit blobs:

- `ReleaseRadar/App/ReleaseRadarApp.swift:6-79`: adds the `AppHostMode` /
  `XCTestHostConstruction` contract, central presence-based XCTest predicate,
  PID-scoped temporary URL, and failure-to-unavailable preparation result.
- `ReleaseRadar/App/ReleaseRadarApp.swift:115-128`: routes the AppDelegate's
  existing guard through the central predicate before activation, notification,
  shared-service, or bridge work.
- `ReleaseRadar/App/ReleaseRadarApp.swift:175-248`: takes the XCTest branch
  before `ReleaseRadarAppServices.shared`, retains only the successful
  isolated `DeliveryStore`, keeps `AppModel` absent, and writes the public
  `XCTestHostIsolation` diagnostic. The unavailable branch keeps no store.
- `ReleaseRadar/App/ReleaseRadarApp.swift:251-297`: gates every product view
  on a present model; XCTest renders inert text and cannot construct
  `SidebarView`, add-project, menu-bar, or settings content.
- `ReleaseRadarTests/AppRouteTests.swift:43-146`: adds focused normal/XCTest
  mode, empty-value, exact temporary-path, per-PID, capture coexistence, and
  deterministic regular-file-at-PID-directory unavailable-mode coverage.

## TDD RED

Before production edits, I ran exactly:

```bash
xcodebuild build-for-testing \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-TestHost-RED \
  CODE_SIGNING_ALLOWED=NO
```

Result: exit 65. `AppRouteTests.swift` failed compilation because
`AppLaunchConfiguration` had no `hostMode` or `isXCTestHost`; the expected
`AppHostMode` cases and unavailable construction contract were also absent.
The command was `build-for-testing`; its output ended at `TEST BUILD FAILED`
while compiling test sources and contains no `Testing started`, launched-test,
or test-host process output. No test host launched during RED.

## Focused GREEN

After the narrow implementation, I ran exactly:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-TestHost-GREEN \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  CODE_SIGNING_ALLOWED=NO
```

Result: exit 0, `TEST SUCCEEDED`. The result bundle summary reports 53 passed,
0 failed, 0 skipped, 0 expected failures, total 53. Both focused isolation
tests passed, including the deterministic regular-file preparation failure.

Focused-run diagnostic observations from the unified log (no SQLite file was
opened or queried):

- PID 6555 used
  `/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/ReleaseRadar-XCTestHost-6555/release-radar.sqlite`.
- PIDs 6556 and 6557 likewise used distinct PID-scoped paths beneath the same
  process temporary directory.
- The `XCTestHostIsolation` category emitted those diagnostics. In the focused
  test time window, the filtered Release Radar log had no AgentBridge,
  Pushover, or Application Support diagnostic.

## Diff and worktree evidence

`git diff --check -- ReleaseRadar/App/ReleaseRadarApp.swift
ReleaseRadarTests/AppRouteTests.swift` produced no output (success).

The pre-existing dirty worktree remains dirty across the many files observed
before this task. The two assigned files were already modified before this
task, and the direct pre-blob comparison above isolates only the listed hunks.
No file outside the two authorized files was edited by this Implementer. No
staging, commit, push, installation, MCP operation, active-phase command,
UUID creation, network request, or SQLite inspection occurred.

## Self-review against acceptance criteria

- Any present XCTest key, including an empty value, reaches a standardized
  PID-scoped temporary database URL; absence returns application mode.
- A regular file at the expected PID directory returns explicit unavailable
  XCTest mode with the same isolated URL, no retained store, no model, and no
  shared-service construction policy.
- App initialization branches before `ReleaseRadarAppServices.shared`; the
  successful path retains only its isolated store and both XCTest outcomes have
  no model. Product view content is guarded by model presence, so no
  `SidebarView.task` is constructed in XCTest.
- AppDelegate uses the same predicate before notification and bridge work.
- The normal branch retains the existing Release/Debug/capture service/model
  construction and the existing policy tests passed in the focused suite.
- The actual focused app-host run emitted only temporary-path test-host
  diagnostics observed above.

## Concerns / independent work remaining

The required seven-suite ordinary-host acceptance run, installed-owner
before/after accessibility comparison, and independent Code Review, QA/Test,
Architecture, Security/Privacy, TPM, and Delivery Management reviews were not
run by this Implementer and remain required before RR-R9C acceptance. The
temporary report above is intentionally scratch-only; no durable delivery
ledger was changed.

## Fix Round 1 — exclusive XCTest host creation and production-coupled preparation

### Fix base and post-edit blobs

| File | Fix-base blob | Fix-base SHA-256 | Post-edit blob | Post-edit SHA-256 |
| --- | --- | --- | --- | --- |
| `ReleaseRadar/App/ReleaseRadarApp.swift` | `535abf710fe0a9ab6a1bdd23ad4ddcee38c3daad` | `23340bf3c3a6edd57aa852db7944f93b3575217ec3bc5061f450ad7eb0dc1c12` | `e0965e340b0c6e49451ecdcf31188c301cf9b8ba` | `3d173965e2ffc244862210ca56eda1bb5cc0b2a4e3caa6aba8d1b26730755b27` |
| `ReleaseRadarTests/AppRouteTests.swift` | `30dcf7a782d3c70d78fae709672d967e26b96a79` | `2471c0d49e32bb10b0e8f9b6ac03e98af844f74419439793373d768b89e970d1` | `e0206a8c3fef481c75603d324904a279aabeba06` | `9de289cefbd9e3275ce9397dc9739fa88c9fb17df2b79cb4b7b7d81645a15c14` |

### Root cause and exact hunks

The prior `hostMode` checked and reused a pre-existing PID directory, then
returned a path-only mode. `ReleaseRadarApp.init` constructed the store later,
so the tests could not prove the production construction branch stayed inert
on a collision. Test comparisons also called the owner Application Support
helper.

The exact round-one hunks are:

- `ReleaseRadar/App/ReleaseRadarApp.swift:2,14-73`: imports Darwin; removes
  the test-only `XCTestHostConstruction` mirror; adds
  `XCTestHostPreparation`, the production-consumed value that carries the
  isolated `DeliveryStore`; makes legacy `hostMode` derive its result from that
  preparation; and atomically creates the PID directory with POSIX `mkdir`
  using owner-only permissions. Any existing directory, regular file, or
  symlink makes `mkdir` fail, returns unavailable, and never calls the store
  factory.
- `ReleaseRadar/App/ReleaseRadarApp.swift:173-200`: changes app startup to
  switch on the same `XCTestHostPreparation` used by the focused tests and
  retain the store that was constructed immediately after exclusive creation.
- `ReleaseRadarTests/AppRouteTests.swift:43-194`: tests fresh, distinct PID
  preparation for non-empty and empty XCTest values, then adds deterministic
  real-directory/stale-sentinel, regular-file, and symlink-target collisions.
  Each collision passes a fail-fast factory, requires unavailable mode, and
  proves the sentinel or target remains unchanged. No test calls
  `DeliveryStore.applicationSupportDatabaseURL()`.

### TDD RED

Before modifying `ReleaseRadarApp.swift`, I amended only the focused tests and
ran:

```bash
xcodebuild build-for-testing \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-TestHost-RED \
  CODE_SIGNING_ALLOWED=NO
```

Result: exit 65. `AppRouteTests.swift` failed because
`AppLaunchConfiguration.prepareXCTestHost` did not exist (lines 65, 72, 110,
and 144); the associated unavailable result could not resolve either. This
was a compile-only build-for-testing RED with no test-session start or launched
test-host output.

### Focused GREEN

After the narrow production change, I ran:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-TestHost-GREEN \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  CODE_SIGNING_ALLOWED=NO
```

Result: exit 0, `TEST SUCCEEDED`. The final result bundle reports 55 passed,
0 failed, 0 skipped, and 0 expected failures. The fresh-directory,
pre-existing-directory, pre-existing-file, and pre-existing-symlink tests all
passed. The test file has zero `applicationSupportDatabaseURL` references.

`git diff --check -- ReleaseRadar/App/ReleaseRadarApp.swift
ReleaseRadarTests/AppRouteTests.swift` produced no output and succeeded.

### Fix-round self-review

- `mkdir` is exclusive: it succeeds only for a fresh PID entry and rejects
  all pre-existing directory, file, and symlink entries without a
  check/create/check race.
- The factory is reached only after successful exclusive creation, and the
  returned store is the exact object retained by `ReleaseRadarApp.init`.
  Collision tests make factory invocation an immediate test failure.
- The stale directory sentinel and symlink target are read only as
  test-owned non-SQLite evidence; no SQLite database was opened or queried.
- AppDelegate's pre-existing central XCTest early guard and the normal
  Release/Debug/capture branch were preserved. Existing focused policy tests
  remain green.
- No source file outside the two authorized files, delivery ledger, external
  integration, installation, SQLite inspection, active-phase command, UUID,
  staging, commit, or push was performed in this round.

Independent seven-suite, installed-owner before/after, and role-review gates
remain outside this Implementer round.
