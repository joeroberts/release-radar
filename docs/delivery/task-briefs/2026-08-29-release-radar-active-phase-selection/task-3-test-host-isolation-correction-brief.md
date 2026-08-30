# RR-R9C Correction Brief: XCTest Host Isolation

**Status:** Awaiting independent Architecture, TPM, QA/Test, and Delivery
Management release. RR-R9 completion is reopened. Installation and live MCP
use remain closed, and this correction never authorizes a second
`release_radar_set_active_phase` invocation. Do not commit or push this
correction before the owner accepts the complete RR-R9 goal.

## Objective and user-visible outcome

Make every ordinary app-hosted `ReleaseRadarTests` run incapable of opening or
changing the installed owner's Release Radar store or reaching the owner's
Keychain, Pushover/network, plugin lifecycle, or agent-bridge paths.

When XCTest launches the built `ReleaseRadar.app` host with the production
bundle identifier, the app must take an early, inert test-host branch. That
branch opens only a fresh PID-scoped database under the process temporary
directory, retains it for the test-host lifetime, emits a public diagnostic of
that exact non-production path, and renders no `SidebarView`. It must not
construct `ReleaseRadarAppServices.shared` or an `AppModel`, so
`SidebarView.task` cannot call `initializeForLaunch`. The existing AppDelegate
XCTest guard must return before notification or bridge services are
constructed.

Normal Release, ordinary Debug, and the accepted alternate-bundle Debug
capture path keep their current launch, storage, fixture, external-service,
plugin, notification, bridge, and UI behavior.

## Root-cause evidence and attribution boundary

- `ReleaseRadarTests` is app-hosted through
  `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ReleaseRadar.app/Contents/MacOS/ReleaseRadar"`.
  Unified logs from final verification prove the host under fresh temporary
  DerivedData launched as `com.rekonlabs.ReleaseRadar`.
- `ReleaseRadarApp.init` currently constructs
  `ReleaseRadarAppServices.shared` unconditionally. That singleton constructs a
  `DeliveryStore` at `DeliveryStore.applicationSupportDatabaseURL()`, a
  `PushoverKeychainStore`, a Pushover dispatcher, and a plugin lifecycle
  coordinator.
- `SidebarView.task` unconditionally calls `AppModel.initializeForLaunch()`.
  That path loads the dashboard and can initialize plugin/notification work
  unless external services are suppressed.
- Only AppDelegate bridge startup currently checks
  `XCTestConfigurationFilePath`; that guard does not protect app initialization
  or `SidebarView.task`.
- Two owner phase Activity entries at 18:34 correlate with an external Gemini
  accessibility client. They are not evidence that XCTest changed the phase,
  and this task must not attribute them to the test host. The correction is
  required by the proven authority exposure above, independent of those
  entries.

## Controlling references

- `docs/delivery/progress.md`, including the reopened RR-R9C gate and the
  recorded one-time live activation evidence
- `docs/design/release-radar-active-phase-selection-design.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`, especially app-only
  SQLite authority, sandbox, external integration, and signing boundaries
- `docs/architecture/ADR-003-active-phase-selection.md`
- `docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md`,
  Task 3 and its Required-finding correction allowance
- `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-2-brief.md`,
  especially isolated runtime evidence, independent gates, and live-command
  cardinality

This brief supplements the accepted RR-R9 artifacts only for the Required
test-host isolation correction. It does not replace their product, command,
projection, UI, audit, or acceptance contracts.

## In scope

- Central XCTest-host detection based on the presence of
  `XCTestConfigurationFilePath`, independent of Debug/Release compilation and
  command-line capture arguments.
- A deterministic launch decision that returns either normal application mode
  or isolated XCTest-host mode with an exact temporary database URL.
- A fresh per-process test-host directory named with the current PID beneath
  `FileManager.default.temporaryDirectory`; the database filename remains
  `release-radar.sqlite`.
- An early `ReleaseRadarApp.init` XCTest branch that opens and retains only the
  isolated `DeliveryStore`, leaves the production model absent, and logs the
  exact isolated path with category `XCTestHostIsolation`.
- Inert scene content for XCTest that never creates `SidebarView`, onboarding,
  Settings, menu-bar product content, or another view with launch tasks.
- Reuse of the same XCTest-host predicate in AppDelegate before any access to
  `ReleaseRadarAppServices.shared`, notification initialization, or bridge
  startup.
- Focused launch-policy tests, fresh full RR-R9C selected-test verification,
  and direct before/after owner Activity evidence without opening or querying
  SQLite.
- One deterministic failure fixture that creates a regular file where the
  PID-scoped test-host directory must be created, then proves the production
  host-preparation path remains an isolated unavailable XCTest mode rather
  than falling back to application mode, production storage, shared services,
  or an `AppModel`.

## Out of scope

- Any RR-R9 command, selector, projection, persistence, audit, Activity,
  notification, plugin, or bridge feature change
- A schema migration, app group, entitlement, sandbox, signing, bundle-ID,
  test-target, scheme, `TEST_HOST`, or package change
- A generalized test harness, dependency container, service locator, launch
  framework, mock server, UI-test target, validator, or new dependency
- Direct inspection or mutation of any owner or test SQLite database
- Repair of the four unrelated `EndToEndAcceptanceTests` legacy schema/plugin
  fixture failures already separated in RR-R9C evidence
- Investigation or control of Gemini or another accessibility client, or a
  claim that XCTest caused the two 18:34 owner Activity entries
- Installation, installed MCP readiness probing, request-ID generation,
  replay, or another activation command. The accepted live activation is
  one-time evidence and must never be repeated for this correction.
- Commit or push before the owner accepts the complete RR-R9 goal

## Dependencies and release gate

- RR-R9A and RR-R9B remain accepted; RR-R9C and overall RR-R9 completion remain
  reopened only for this Required correction and its independent evidence.
- Architecture, TPM, QA/Test, and Delivery Management must independently review
  this brief before releasing one fresh Implementer.
- The Implementer owns only the two anticipated product/test files below and
  may not edit the progress ledger or review its own work.
- The Implementer and coordinating agents must leave all correction changes
  uncommitted and unpushed until the owner accepts the complete RR-R9 goal.
- Installation and all live MCP use remain closed throughout implementation,
  review, and verification. No review role may authorize a second active-phase
  mutation.
- After Code Review, QA/Test, Architecture, Security/Privacy, TPM, and Delivery
  Management report zero open Required findings, Delivery Management may
  record correction acceptance and the next safe packaging/relaunch gate. That
  gate remains read-only with respect to active-phase authority.

## Affected subsystem and anticipated files

- Modify `ReleaseRadar/App/ReleaseRadarApp.swift`
  - add the narrow XCTest-host launch decision and PID-scoped temporary URL;
  - take the inert branch before `ReleaseRadarAppServices.shared`;
  - retain the isolated store and conditionally render product scenes only for
    a real application launch;
  - route AppDelegate's existing early return through the same predicate; and
  - emit the one public test-host database-path diagnostic.
- Modify `ReleaseRadarTests/AppRouteTests.swift`
  - add only the focused launch-decision/isolation tests below; and
  - preserve all existing ordinary Debug and capture-policy tests.

No `project.pbxproj`, core store, model, sidebar, notification, plugin,
transport, fixture, package, screenshot, or evidence-framework change is
anticipated. If implementation appears to require one, stop for Architecture
and Delivery Management review rather than expanding this brief.

## Interface and implementation contract

Keep the decision inside the existing `AppLaunchConfiguration` surface. The
exact names may follow local style, but the implemented interface must be
equivalent to:

```swift
enum AppHostMode: Equatable {
    case application
    case xctestHost(databaseURL: URL)
    case xctestHostUnavailable(databaseURL: URL)
}

static func hostMode(
    environment: [String: String],
    temporaryDirectory: URL,
    processIdentifier: Int32,
    fileManager: FileManager = .default
) -> AppHostMode
```

The contract is:

- any present `XCTestConfigurationFilePath` key, including an empty value,
  resolves to `.xctestHost`; absence resolves to `.application`;
- the test URL is standardized beneath `temporaryDirectory`, contains the PID
  as a path component or bounded suffix, ends in `release-radar.sqlite`, and
  never equals or falls beneath
  `DeliveryStore.applicationSupportDatabaseURL()`;
- XCTest mode takes precedence even when Debug capture arguments are present;
- `hostMode` performs the same PID-scoped directory preparation used by
  `ReleaseRadarApp.init`; success returns `.xctestHost`, while any creation or
  non-directory failure returns `.xctestHostUnavailable` carrying the same
  isolated database URL;
- neither XCTest case may return `.application`, call
  `DeliveryStore.applicationSupportDatabaseURL()`, substitute a production URL,
  evaluate `ReleaseRadarAppServices.shared`, or construct an `AppModel`;
- `ReleaseRadarApp.init` handles `.xctestHostUnavailable` as an inert test-host
  scene with no store, model, or product services. It logs the unavailable
  isolated URL and error context but never falls back to Application Support;
- the XCTest branch retains its store for the host lifetime but creates no
  model and no product-task-bearing view;
- the diagnostic includes the standardized database path and process ID, uses
  `Logger` category `XCTestHostIsolation`, and is emitted only for XCTest; and
- the `.application` branch retains the existing source path and ordering for
  Release, ordinary Debug, and Debug capture.

Do not add a second environment flag. `XCTestConfigurationFilePath` is already
the launch authority supplied by XCTest and already guards AppDelegate.

## Data, persistence, security, and privacy implications

- The test host may create and migrate only its PID-scoped temporary database.
  It must never calculate an XCTest store by calling the production Application
  Support helper and must never fall back to that helper.
- No test-host view or model initialization means no project bookmark,
  authorization scope, owner Activity, audit, request receipt, notification
  event, settings, or active-phase path is read or written.
- No `ReleaseRadarAppServices.shared` construction means no test-host Keychain
  access, Pushover credentials load, `URLSession`/Pushover transport, plugin
  package/coordinator, or lifecycle-helper path.
- AppDelegate exits before notification initialization and bridge startup.
- The public diagnostic contains only a temporary path and PID. It contains no
  owner path, project data, credential, bookmark, ticket content, or command.
- Temporary test state is non-authoritative and may be reclaimed by the OS.
  No cleanup machinery or durable evidence file is added.
- The owner Application Support database and all SQLite files remain opaque to
  acceptance. Verification uses the running UI's accessibility state and the
  test-host diagnostic, never database access.

## Test fixtures and strategy defined before implementation

Use only existing XCTest, `AppLaunchConfiguration` policy-test style,
temporary-directory construction, `xcodebuild`, unified logging, and Computer
Use accessibility inspection. The failure fixture uses only a test-owned
temporary directory and `FileManager` to create one regular file at the
expected PID-directory path. Add no test double, harness, dependency, or
SQLite inspection.

### Focused policy cases

Add tests in `AppRouteTests` that prove:

1. an environment without `XCTestConfigurationFilePath` resolves to normal
   application mode;
2. present non-empty and present empty XCTest values both resolve to isolated
   mode;
3. a supplied temporary root and PID produce the exact expected standardized
   temporary database path, different from and outside the production
   Application Support database path;
4. two different PIDs produce different directories;
5. XCTest mode wins when the existing Debug capture arguments are also present;
   and
6. the existing Release, ordinary Debug, `--rr10-capture`,
   `--rr10-empty-store`, and RR-R9 scenario matrix remains unchanged.
7. for a fresh test-owned temporary root, create a regular file at the exact
   PID-scoped directory that `hostMode` must create, invoke the same production
   `hostMode` preparation with an XCTest environment, and require
   `.xctestHostUnavailable(databaseURL:)`. Assert that URL is the expected
   standardized child of the supplied temporary root, ends in
   `release-radar.sqlite`, differs from and is not beneath the production
   Application Support URL, and that the result is never `.application`.
   Exercise the exact unavailable case consumed by `ReleaseRadarApp.init` and
   require its declared construction policy to retain no store and create no
   `ReleaseRadarAppServices.shared` or `AppModel`. Do not open or query either
   database URL.

### Meaningful required RED

Write the focused assertions before product code. Run a compile-only RED so
the vulnerable test host is not launched:

```bash
xcodebuild build-for-testing \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-TestHost-RED \
  CODE_SIGNING_ALLOWED=NO
```

Expected RED: compilation fails because the XCTest-host launch decision,
unavailable preparation result, or inert unavailable-host construction
contract referenced by the new tests does not exist. Record the specific
compiler failure. A passing build, a failure in unrelated code, or a runtime
launch is not the required RED.

### Required GREEN

After the narrow implementation, run:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9C-TestHost-GREEN \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  CODE_SIGNING_ALLOWED=NO
git diff --check -- \
  ReleaseRadar/App/ReleaseRadarApp.swift \
  ReleaseRadarTests/AppRouteTests.swift
```

Require every `AppRouteTests` case to pass with zero skips and clean diff
output. Confirm the test-host diagnostic names a temporary database and that
no production-service diagnostic or owner Application Support path appears.
The deterministic regular-file fixture must pass in this same command and
prove the unavailable branch without launching an app or inspecting SQLite.

### Direct ordinary-host runtime evidence

After targeted GREEN and before acceptance, use a fresh DerivedData root and
run the unchanged seven-suite RR-R9C selection from the controlling Task 3
plan, with no capture flags and no test-only environment override. This is an
ordinary app-hosted XCTest run.

Before the run, use Computer Use accessibility state in the installed app to
record the ordered visible owner Activity rows and active-phase value. After
the test host exits, observe the same installed UI again and require identical
ordered Activity rows/count and active-phase value. A relaunch may be used for
read-only UI readback; do not invoke a mutation or manually inspect storage.

From the test host's `XCTestHostIsolation` diagnostic, record the actual PID and
database path. Require the path to be under the process temporary directory,
to end in `release-radar.sqlite`, and not to equal or fall beneath the owner's
Application Support database path. Obtain this from normal test output or
unified logs; do not open or query the file.

Record the seven-suite totals and separate the four already-known unrelated
End-to-End fixture failures if they recur. Those failures do not authorize
fixture repair, and they do not substitute for passing focused isolation tests.

## Happy path

1. XCTest launches the built Debug app host with
   `XCTestConfigurationFilePath` present and production bundle ID unchanged.
2. AppDelegate recognizes XCTest and returns before shared services or bridge
   work.
3. `ReleaseRadarApp.init` recognizes the same mode before touching
   `ReleaseRadarAppServices.shared`, opens only the PID-scoped temporary store,
   logs its path, and leaves the production model absent.
4. The scene renders inert test-host content, so `SidebarView.task` and all
   launch initialization remain unreachable.
5. The selected XCTest suites run normally. The installed owner's phase and
   Activity remain unchanged.

## Non-happy paths and recovery

- **Temporary directory unavailable or not a directory:** return the explicit
  unavailable XCTest-host case with the intended isolated database URL, retain
  no store, render only inert test-host content, and emit the clear test-host
  diagnostic. Never return application mode, fall back to owner Application
  Support, evaluate shared services, or construct an `AppModel`. The focused
  regular-file fixture deterministically exercises this branch.
- **Conflicting capture arguments:** XCTest mode wins. Do not seed the RR-R9
  capture fixture, sample data, or any app model.
- **Missing XCTest environment key:** use the existing application branch;
  ordinary Release, Debug, and alternate capture behavior remain unchanged.
- **Repeated or concurrent hosts:** the PID-scoped directory prevents hosts
  from sharing a test database. No global fixed test database is permitted.
- **Known End-to-End fixture drift:** report the same unrelated failures and
  continue only if focused isolation tests and direct host evidence pass. Do
  not repair or hide them.
- **Owner Activity differs:** stop RR-R9 completion, keep installation/live MCP
  closed, and investigate without attributing the difference to XCTest until
  evidence establishes causation. Never compensate with a phase mutation.

## Activity and audit evidence

The correction itself creates no owner Activity, audit event, request receipt,
evidence row, notification event, phase change, or MCP request. Temporary store
schema creation is not owner delivery history.

Acceptance evidence is the unchanged before/after accessibility snapshot of
the installed owner's Activity and active-phase value, paired with the actual
test-host temporary-path diagnostic. Explicitly record that no SQLite file was
opened or queried. Preserve the evidence classification that the two 18:34
owner phase entries correlate with the external Gemini accessibility client;
do not relabel them as XCTest activity.

The previously accepted `RR-ROADMAP` activation request and returned audit ID
remain the sole live activation evidence. This correction creates no UUID and
must never send or replay that command.

## Acceptance criteria

- Focused RED is captured before product code and fails for the missing
  test-host isolation contract without launching the vulnerable host.
- Focused GREEN passes every `AppRouteTests` case with zero skips.
- Any presence of `XCTestConfigurationFilePath` selects a fresh PID-scoped
  temporary database outside production Application Support.
- A deterministic regular-file-at-the-PID-directory test proves preparation
  failure returns the explicit unavailable XCTest mode with the isolated URL,
  retains no store, and cannot select a production URL, application mode,
  `ReleaseRadarAppServices.shared`, or `AppModel`.
- The actual ordinary test-host diagnostic proves the launched host used that
  non-production path without SQLite inspection.
- XCTest construction never evaluates `ReleaseRadarAppServices.shared`, never
  creates an `AppModel`, and never renders `SidebarView` or another product
  launch task.
- AppDelegate returns before notification initialization or bridge startup.
  Therefore XCTest has no owner database, Keychain, Pushover/network, plugin
  lifecycle/helper, or bridge path.
- The installed owner's ordered Activity rows/count and active-phase value are
  identical before and after the fresh ordinary selected test run.
- Existing normal Release, ordinary Debug, and alternate Debug capture policy
  tests remain green and their behavior is unchanged.
- The correction modifies only the two anticipated files, adds no dependency
  or persistent machinery, and preserves unrelated dirty work.
- The four unrelated End-to-End fixture failures, if present, are reported and
  not repaired under this brief.
- Fresh Code Review, QA/Test, Architecture, Security/Privacy, TPM, and Delivery
  Management report zero open Required findings.
- No app installation, live MCP readiness probe, UUID, command replay, direct
  SQLite access, or second active-phase mutation occurs.

## Required independent reviews

- **Code Reviewer:** early-branch ordering, exhaustive scene gating, exact
  temporary-path contract, AppDelegate predicate reuse, and preservation of
  all non-XCTest launch behavior
- **QA/Test:** safe compile-only RED, focused GREEN, fresh ordinary selected
  run, deterministic non-directory/unwritable-root failure, exact diagnostic
  path, and before/after installed Activity/phase proof
- **Architect:** app-only persistence boundary, no production-service
  construction, no fallback to owner storage, and no new framework or authority
- **Security/Privacy:** no owner database, bookmark, Keychain, network,
  Pushover, plugin/helper, bridge, credential, or project-data exposure
- **TPM:** correction-only scope, known-failure separation, complete RR-R9
  outcome, and permanent prohibition on a second activation command
- **Delivery Manager:** role independence, evidence sufficiency, dirty-worktree
  attribution, closed install/live-MCP gate, and sole-ledger update after GO

The Implementer cannot perform or approve any of these reviews.

## Completion evidence for `docs/delivery/progress.md`

After all independent reviews return GO, Delivery Management records:

- this brief's path, registered SHA-256, dependency state, Implementer, and
  independent reviewers;
- the proven production-bundle-ID test-host root cause and exact source paths;
- the safe compile-only RED command, failure, and confirmation that no test
  host launched during RED;
- focused GREEN command, counts, skips, and `git diff --check` result;
- deterministic regular-file failure-fixture result, including the exact
  isolated unavailable URL and proof of no application-mode, production-URL,
  shared-services, model, or SQLite fallback;
- the fresh ordinary seven-suite command, totals, actual temporary database
  path/PID diagnostic, and separately classified known End-to-End failures;
- exact before/after installed owner Activity rows/count and active-phase value,
  with explicit confirmation that no SQLite file was opened or queried;
- evidence that XCTest constructed neither shared services nor model/UI launch
  tasks and reached no Keychain, network/Pushover, plugin/helper, notification,
  or bridge path;
- normal Release, ordinary Debug, and alternate Debug capture preservation;
- the two 18:34 entries' external Gemini accessibility correlation without an
  unsupported XCTest-causation claim;
- the bounded two-file implementation diff and preservation of unrelated
  working-tree changes;
- every independent review decision, Required finding closure, and residual
  risk; and
- explicit confirmation that RR-R9 remains reopened until this correction is
  accepted, install/live MCP remained closed, and no second activation request
  was or will be authorized; and
- confirmation that no correction change was committed or pushed before the
  owner's complete-goal acceptance.

`docs/delivery/progress.md` remains the sole delivery ledger. Planning and the
Implementer do not edit it.
