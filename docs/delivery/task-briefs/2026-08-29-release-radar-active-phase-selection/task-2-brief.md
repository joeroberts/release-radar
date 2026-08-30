# RR-R9B Task Brief: Owner Active-Phase Experience and RR-R9C Handoff

**Status:** Planning contract complete; implementation remains closed until
RR-R9A is independently accepted and Delivery Management releases one fresh
RR-R9B Implementer. RR-R9C remains an acceptance gate, not product scope.

## Objective and user-visible outcome

Give the owner one shared accessible **Active phase** selector on both Project
Overview and Phase Board. Every selection resolves the existing
security-scoped project authorization and dispatches the accepted RR-R9A
`AgentCommand.setActivePhase` through `AgentCommandDispatcher` with owner-app
origin. A successful command immediately reloads the selected phase's cards,
five lane counts, ticket detail, dependencies, Activity, and valid ticket
selection and survives relaunch.

The interface explicitly handles busy, no-alternative-phase, unavailable,
authorization, rejected mutation, and committed-but-refresh-failed states. It
never silently retries a mutation. After RR-R9B implementation and independent
acceptance, RR-R9C verifies the complete running feature and uses one accepted
typed MCP command to activate `RR-ROADMAP`.

## Controlling references

- `docs/design/release-radar-active-phase-selection-design.md`
- `docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md`,
  **Task 2 (RR-R9B)** and **Task 3 (RR-R9C)**
- `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-1-brief.md`
- `docs/delivery/progress.md`, current gate, roadmap synchronization, and
  planning reconciliation
- `docs/design/agent-driven-delivery-dashboard-design.md`, Project Overview,
  Phase Board, Failure behavior, and acceptance criteria
- `docs/design/mockups/phase_board.png`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-003-active-phase-selection.md`, especially
  current-request publication ordering, AppModel guard authority, and accepted
  cross-phase ticket-dependency semantics
- Existing accepted compact/runtime evidence under `docs/delivery/evidence/`
  as regression context, not a replacement for fresh RR-R9C proof

The complete owner-approved outcome controls. RR-R9B is a bounded coherent
implementation slice; chunking does not defer error, accessibility, refresh,
persistence, audit, or runtime requirements.

## In scope

- Project all persisted phases for the selected project as deterministic
  selector options while keeping board data scoped to the active phase.
- Create one reusable native SwiftUI `ActivePhaseSelector`.
- Place the shared control on Project Overview and Phase Board without a new
  route or phase manager.
- Use the accepted RR-R9A command path with `.ownerApp`, a fresh UUID, exact
  authorized canonical root, and deterministic owner audit reason.
- Disable duplicate interaction while the mutation/refresh is busy.
- Preserve the persisted selection after store/AppModel/app relaunch.
- Coherently refresh active phase name, cards, counts, ticket detail,
  dependency projection, Activity, and selected ticket.
- Serialize publication with an AppModel generation token so an older full
  reload cannot publish success, failure, or status reconciliation after a
  newer reload begins; a superseded caller performs no observable write.
- Enforce already-active, `.saving`, and `.savedNeedsReload` no-op guards in
  AppModel before request-ID generation; disabled views are not authority.
- Keep cards, detail membership, and dependency-graph nodes active-phase scoped
  while preserving valid same-project cross-phase references inside an active
  ticket's detail.
- Present explicit no-alternative, typed mutation, unavailable, authorization,
  and saved-refresh recovery states.
- Retain one coalesced successful-command refresh when the dashboard handler is
  not yet registered; registration and normal callbacks refresh read-only
  dashboard state before notification draining.
- Reauthorize only the same canonical project folder through the existing
  bookmark workflow; never select automatically after recovery.
- Preserve the existing five-lane, density, inspector, navigation, and
  responsive recovery behavior.
- Provide RR-R9C automated, visual, responsive, keyboard/accessibility,
  security, review, live-command, Activity, and relaunch acceptance evidence.
- Provide the exact default-off Debug RR-R9 fixture/fault path needed to make
  the running accessibility and recovery matrix reproducible in a fresh
  alternate container.

## Out of scope

- Phase create/delete/rename/reorder/archive or multiple active phases
- Ticket editing/movement/transitions or inactive-phase cards on the active
  board
- All-phase Work Board, Project Plan, roadmap/phase redesign, or route/sidebar
  information architecture changes
- New schema, migration, persistence store, Pushover delivery semantics,
  repository document, synchronization, watcher, poller, or service; the
  required after-reply dashboard-before-notification ordering is in scope
- Direct SQLite mutation; agent/helper/observer database access
- Owner database inspection during implementation or acceptance
- New MCP operation beyond accepted RR-R9A; bridge/plugin/signing/permissions,
  entitlements, network, or dependency changes
- Automatic retry after a rejected, unavailable, unknown, or committed write
- Product implementation during RR-R9C except minimum corrections for Required
  findings tied directly to RR-R9 acceptance
- A generalized fixture/fault framework, UI-test harness, production-default
  sample/fault behavior, capture network use, or new runtime dependency
- `docs/delivery/progress.md` changes by the Implementer; Delivery Management
  records evidence and gates

## Dependencies and release gate

- RR-R9A must be implemented and independently accepted with zero open Required
  findings.
- Architect, TPM, QA/Test, and Delivery Management review this brief and release
  one fresh RR-R9B Implementer.
- The accepted schema, `FolderProjectOnboarding.withAuthorizedProject`,
  `reauthorizeProjectRoot`, `DashboardProjection`, `AppModel` reload path,
  FailureState presentation, and phase board are prerequisites.
- No concurrent writer may modify RR-R9B files. The Implementer cannot review
  or approve its own work.
- RR-R9C opens only after fresh combined Code Review, QA, Architecture,
  Security/Privacy, TPM, and Delivery Management GO.
- The live `RR-ROADMAP` command is authorized only after the complete product
  implementation is accepted; it is not a test setup shortcut.

## Affected subsystem and anticipated files

- Create `ReleaseRadar/Projects/ActivePhaseSelector.swift`
- Create `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` as the
  `#if DEBUG`, default-off RR-R9 fixture/fault path only
- Modify `ReleaseRadar/App/ReleaseRadarApp.swift` only to parse the recognized
  capture scenario and inject the fixture in Debug
- Modify `ReleaseRadar/Projects/DashboardProjection.swift`
- Modify `ReleaseRadar/App/AppModel.swift`
- Modify `ReleaseRadar/Projects/ProjectOverviewView.swift`
- Modify `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modify `ReleaseRadar/Navigation/SidebarView.swift`
- Modify `ReleaseRadar/Shared/FailureStateView.swift` only for shared
  phase-selection recovery copy/presentation and full-style action rendering
- Modify `ReleaseRadar/App/AppNotificationCoordinator.swift` only to retain a
  coalesced pre-registration successful-command refresh and run dashboard
  refresh before notification draining
- Modify `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modify `ReleaseRadarTests/AppRouteTests.swift`
- Modify `ReleaseRadarTests/NotificationAcceptanceTests.swift`

The repository uses synchronized Xcode source groups, so the new Swift files
requires no `project.pbxproj` edit. Preserve unrelated existing modifications
in AppModel, Overview, Sidebar, FailureState, tests, project files, and `dist/`.

RR-R9C adds only the four canonical screenshots named in its handoff section
under `docs/delivery/evidence/`, after runtime evidence exists and Delivery
Management records them in the sole ledger. No separate evidence report or
competing ledger is authorized.

## Interface contract

```swift
struct ProjectPhaseProjection: Equatable, Sendable, Identifiable {
    let id: PhaseID
    let name: String
}

struct ProjectDashboardProjection: Equatable, Sendable, Identifiable {
    let id: ProjectID
    let name: String
    let activePhaseID: PhaseID?
    let activePhaseName: String
    let phases: [ProjectPhaseProjection]
    let goalContext: GoalContextProjection
    let currentWorkCount: Int
    let attentionCount: Int
}

struct PhaseBoardProjection: Equatable, Sendable {
    let project: ProjectDashboardProjection
    let phaseID: PhaseID
    let lanes: [DashboardLaneProjection]
    let details: [TicketID: TicketDetailProjection]
}

private enum ProjectionReloadOutcome: Equatable, Sendable {
    case published
    case failed
    case superseded
}

private enum ProjectionReloadContext: Equatable, Sendable {
    case ordinary
    case ownerActivePhaseCommitted(ProjectID, PhaseID, String)
    case agentCommandCommitted
}

#if DEBUG
enum RR9ActivePhaseCaptureScenario: String, Sendable {
    case happy
    case busy
    case noAlternative = "no-alternative"
    case mutationFailure = "mutation-failure"
    case unavailable
    case authorizationFailure = "authorization-failure"
    case savedRefresh = "saved-refresh"
    case emptyPhase = "empty-phase"
    case noActivePointer = "no-active-pointer"
    case crossPhaseDetail = "cross-phase-detail"
}
#endif

private struct PreparedProjectProjections: Sendable {
    let dashboard: DashboardProjection
    let reviewInboxes: [ProjectID: ReviewInboxProjection]
    let dependencyGraphs: [ProjectID: DependencyGraphProjection]
    let projectActivities: [ProjectID: ProjectActivityProjection]
    let projectGuidanceStates: [ProjectID: ProjectGuidanceState]
    let projectRoots: [ProjectID: URL]
    let selectedTicketID: TicketID
    let selectedReviewItemID: ReviewItemID?
}
```

Phase options are same-project rows ordered by case-insensitive name, then ID.
They remain available on the project projection when `activePhaseID == nil` and
no board exists. Board cards, `details` keys, counts, and dependency-graph
nodes remain filtered by the active `PhaseBoardProjection.phaseID`. An active
ticket's `TicketDetailProjection.requires` and `.unlocks` retain valid same-
project cross-phase references; those referenced tickets do not become board
cards or graph nodes.

```swift
enum ActivePhaseSelectionStatus: Equatable, Sendable {
    case idle
    case saving(PhaseID)
    case mutationFailed(FailureStatePresentation, canReauthorize: Bool)
    case savedNeedsReload(PhaseID, String)
}
```

`AppModel` exposes per-project status and these exact operations:

```swift
func setActivePhase(projectID: ProjectID, phaseID: PhaseID) async
func reloadAfterActivePhaseSelection(projectID: ProjectID) async
func reauthorizeActivePhaseProject(at folder: URL, projectID: ProjectID) async
func reloadDashboardAfterCommittedAgentCommand() async
```

`AppModel` also owns:

```swift
private var projectionReloadGeneration: UInt64 = 0
private let requestIDGenerator: () -> UUID
private var activePhaseSelectionStatuses: [ProjectID: ActivePhaseSelectionStatus] = [:]

@MainActor
private func prepareProjectProjections() async throws -> PreparedProjectProjections

@MainActor
private func publish(_ prepared: PreparedProjectProjections)

// AppNotificationCoordinator actor state.
private var pendingSuccessfulCommandRefresh = false
private var successfulCommandRefreshDrainInProgress = false

func setDashboardRefreshHandler(
    _ handler: @escaping DashboardRefreshHandler
) async

private func drainSuccessfulCommandRefreshIfPossible() async
```

Its initializer gains
`requestIDGenerator: @escaping () -> UUID = { UUID() }`. This is the only new
production-default test seam and is invoked only after owner guards pass. The
RR-R9 capture configuration exists only under `#if DEBUG`, defaults to `nil`,
and is not a production behavior or generalized collaborator.

`AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(arguments:isDebugBuild:)`
returns a scenario only for Debug plus `--rr10-capture`,
`--rr10-empty-store`, and exactly one recognized
`--rr9-active-phase-fixture=<scenario>` argument. Missing/unknown/duplicate
arguments and all Release builds yield `nil`.

`setActivePhase` performs these checks before bookmark resolution or UUID
creation:

```swift
guard dashboard?.projects.first(where: { $0.id == projectID })?.activePhaseID != phaseID else {
    return
}
switch activePhaseSelectionStatuses[projectID] ?? .idle {
case .saving, .savedNeedsReload:
    return
case .idle, .mutationFailed:
    break
}
activePhaseSelectionStatuses[projectID] = .saving(phaseID)
let requestID = requestIDGenerator()
```

Every full reload uses this publication order:

```swift
private func reloadProjectProjections(
    context: ProjectionReloadContext = .ordinary
) async -> ProjectionReloadOutcome {
    projectionReloadGeneration += 1
    let generation = projectionReloadGeneration
    let prepared: PreparedProjectProjections
    do {
        prepared = try await prepareProjectProjections()
    } catch {
        guard generation == projectionReloadGeneration else { return .superseded }
        publishFailure(error, context: context)
        return .failed
    }
    guard generation == projectionReloadGeneration else { return .superseded }
    publish(prepared)
    return .published
}
```

The generation is captured on the main actor before the first `await`.
`publish` contains no suspension and is the only success boundary for the
current generation. It installs the prepared coherent snapshot, clears the
applicable dashboard load error, and reconciles each `.saving(target)` or
`.savedNeedsReload(target, _)`: clear to `.idle` only when the prepared project
projection has `activePhaseID == target`; otherwise leave the status exactly
unchanged. `publishFailure` likewise contains no suspension and is the only
failure boundary for the current generation. In
`.ownerActivePhaseCommitted(projectID, phaseID, phaseName)` context, a post-
commit failure establishes or preserves
`.savedNeedsReload(phaseID, phaseName)`; ordinary and agent-command contexts
publish their existing scoped dashboard error without reconciling unrelated
phase-selection status.

Initial load, onboarding/folder reload, owner selection, agent refresh, and
read-only recoveries use this path with the applicable context. Callers use
`.published`, `.failed`, and `.superseded` only for control flow. A
`.superseded` caller returns immediately and performs zero observable writes:
no `.idle`, `.savedNeedsReload`, dashboard error, or other status or projection
reconciliation.

`AppNotificationCoordinator` implements the pre-registration contract with one
pending Boolean and one drain-in-progress Boolean. A successful committed-
command callback sets `pendingSuccessfulCommandRefresh = true`. When no handler
exists it returns without notification draining. Handler registration calls the
same drain. The drain clears the pending bit, awaits the read-only dashboard
handler, repeats if a callback arrived during suspension, then calls
`dispatchPending()`; a callback arriving during notification draining remains
pending and is serviced before the drain exits. The actor guard prevents a
second drain. Failed command results set no bit. No path redispatches a command.

The deterministic contract is:

```swift
func dispatchAfterCommittedCommand(
    _: AgentCommandEnvelope,
    result: AgentCommandResult
) async {
    guard result.error == nil else { return }
    pendingSuccessfulCommandRefresh = true
    await drainSuccessfulCommandRefreshIfPossible()
}

func setDashboardRefreshHandler(
    _ handler: @escaping DashboardRefreshHandler
) async {
    dashboardRefreshHandler = handler
    await drainSuccessfulCommandRefreshIfPossible()
}

private func drainSuccessfulCommandRefreshIfPossible() async {
    guard !successfulCommandRefreshDrainInProgress,
          pendingSuccessfulCommandRefresh,
          let dashboardRefreshHandler else { return }
    successfulCommandRefreshDrainInProgress = true
    defer { successfulCommandRefreshDrainInProgress = false }
    while true {
        repeat {
            pendingSuccessfulCommandRefresh = false
            await dashboardRefreshHandler()
        } while pendingSuccessfulCommandRefresh
        await dispatchPending()
        guard pendingSuccessfulCommandRefresh else { return }
    }
}
```

The command envelope is:

```swift
AgentCommandEnvelope(
    version: AgentCommandDispatcher.commandEnvelopeVersion,
    requestID: requestID,
    projectRoot: project.canonicalRoot.path,
    reason: "Owner selected active phase \(phaseID.rawValue)",
    command: .setActivePhase(phaseID: phaseID.rawValue)
)
```

It is dispatched with `origin: .ownerApp` and only while
`withAuthorizedProject(projectID:)` holds valid scope.

The shared selector surface identities are exactly:

- `active-phase-selector-overview`
- `active-phase-selector-board`

Both controls are labelled **Active phase** and expose the selected phase name
and stable ID in their accessibility value/help.

## Data, persistence, security, and privacy

- RR-R9B reads phase options from current SQLite projection and writes only
  through accepted RR-R9A. It introduces no second active-phase state.
- A successful owner request commits active pointer, owner audit, and durable
  request receipt atomically. A refresh is a read-only postcondition and does
  not determine whether the mutation committed.
- The private full reload prepares dashboard, inbox, guidance/root, dependency,
  Activity, and visible-ticket values before publishing them together. An
  awaited downstream failure leaves the last coherent projection visible.
- On the main actor, every full reload increments and captures
  `projectionReloadGeneration` before its first suspension. Only the matching
  current generation may publish the prepared snapshot or an error and
  reconcile phase-selection status in that non-suspending boundary; a stale
  completion returns `.superseded`, its caller returns immediately, and it
  changes no observable state.
- The notification coordinator retains only a coalesced in-memory pending-
  refresh bit when a successful command precedes handler registration. It
  persists no envelope/payload, performs no mutation retry, and starts no
  notification drain until a handler can begin the read-only refresh.
- AppModel checks already-active, `.saving`, and `.savedNeedsReload` before
  authorization and before `requestIDGenerator()`. Each rejected direct call
  creates no UUID, request receipt, mutation, or audit.
- Bookmark bytes never enter UI, logs, audit reasons, command payload, or test
  screenshots. Stored paths alone never authorize the command.
- Reauthorization accepts only the same canonical persisted project root and
  balances security-scope access. Parent, child, different, stale, denied, or
  mismatched roots fail closed.
- Same-project validation remains in the dispatcher even though selector
  options are filtered.
- The UI sends only project root, phase ID, reason, version, and request ID. It
  sends no ticket content, repository file, credential, or network request.
- No sandbox, Hardened Runtime, signing, app-group, Keychain, helper, or network
  authority changes.
- The RR-R9 runtime fixture/fault is Debug-only, default-off, isolated under a
  fresh alternate bundle/container, and covered by existing capture suppression.
  It has no owner-container or network access. Acceptance operators never open,
  query, or mutate owner or alternate SQLite files directly.
- Security/Privacy independently verifies owner bookmark and agent command
  paths before RR-R9C.

## Fixtures and test strategy defined before implementation

Use existing XCTest, temp-store, bookmark collaborator, `dashboardLoader`,
store-queue, signed package, alternate-container, accessibility, and screenshot
patterns. Add no snapshot library, UI-test harness, mock service, or custom
validator.

### Projection fixture

One authorized project contains:

- `phase-current`: two current tickets and one ticket dependency;
- `phase-roadmap`: eleven tickets, exactly eight Backlog and three Blocked,
  phase/ticket dependencies, and at least one selectable detail;
- `phase-history`: one Accepted historical ticket;
- `phase-order-a` named `Roadmap` and `phase-order-z` named `ROADMAP`, inserted
  in reverse ID order so they compare equal under SQLite `NOCASE` and exercise
  the ID tie-break;
- an explicit active row initially targeting `phase-current`;
- audit/history records whose bytes/counts are snapshotted before selection.

One `phase-current` ticket depends on a `phase-roadmap` ticket. Before and after
selection, require the active board's cards, `details` keys, and graph nodes to
remain phase-scoped while the active ticket detail truthfully exposes that
cross-phase reference. Snapshot the dependency row and require it unchanged.

Require deterministic `name COLLATE NOCASE, id` phase options, explicitly
`phase-order-a` before `phase-order-z`, and exact active-only board membership
before and after the accepted command plus store recreation.

A second multi-phase project has no `project_active_phases` row. Require all
phase options and optional active ID `nil` on its project projection, no board
before selection, and an immediate coherent board after selecting from either
owner route. A single unselected phase remains actionable; only a sole phase
that is already active is the no-alternative state.

### AppModel fixtures

- valid current bookmark and two phases for the owner happy path;
- a store queue gate to hold one command and prove busy deduplication;
- one already-active-phase project for no-alternative behavior;
- missing, stale, resolver-failed, access-denied, and mismatched bookmarks;
- direct invalid target to prove typed mutation failure;
- an injected dashboard loader that fails after committed selection, then
  succeeds for explicit reload;
- the existing injectable `reviewInboxLoader`, sequenced to fail after the new
  dashboard has loaded, proving no partial dashboard/workspace state is
  published before explicit reload succeeds;
- a deterministic coordinator gate receiving two successful callbacks before
  handler registration, then proving one coalesced read-only refresh begins on
  registration before notification draining;
- a separate registered-handler coordinator gate proving ordinary refresh-
  before-notification order, plus a failed-result control with no pending work;
- a counting request-ID generator for direct model-boundary guard assertions;
- a continuation-gated dashboard loader that suspends older reload A, permits
  distinct newer reload B from the committed-agent handler to publish, then
  releases A as either stale success or stale failure;
- target phase whose old selected ticket is absent, plus an empty target phase,
  to prove selection/dependency reconciliation.

The generation fixture must not use sleeps. It observes A entering its loader,
starts B, awaits B's publication, releases A, and then asserts the complete
observable model—including dashboard, workspace dictionaries, dependency
graph, Activity, visible selection, dashboard error, and phase-selection
status—remains exactly as B published. Run both stale-success and stale-failure
orders. Add current-generation cases proving a prepared projection containing
the pending target clears `.saving(target)` or
`.savedNeedsReload(target, _)` to `.idle`, while a target mismatch leaves
either status unchanged. The three guard fixtures call
`AppModel.setActivePhase` directly and assert generator/request/audit deltas:
already active `0/0/0`, a second call while saving `0/0/0`, and a call while
saved-needs-reload `0/0/0` relative to the state immediately before that call.
The coordinator fixtures use checked continuations/event recorders, never
sleeps: before handler registration both refresh and notification counts remain
zero; registration starts exactly one refresh for the pre-registration batch;
notification draining begins only after that refresh is released. The normal
registered case proves the same ordering for one callback. An overlapping
AppModel reload remains governed by the generation tests above.

### Debug runtime fixture

`RR9ActivePhaseCaptureFixture` is compiled only under `#if DEBUG`, defaults
off, and activates only for:

```text
--rr10-capture --rr10-empty-store --rr9-active-phase-fixture=<scenario>
```

Recognized scenarios are `happy`, `busy`, `no-alternative`,
`mutation-failure`, `unavailable`, `authorization-failure`, `saved-refresh`,
`empty-phase`, `no-active-pointer`, and `cross-phase-detail`. It uses an
app-owned `DeliveryStore` seed following `DashboardSampleData`. For every
authorized disposable root, it canonicalizes the URL, creates real security-
scoped bookmark data through the production
`ProjectBookmarkStore.makeBookmark(for:)`, and persists that exact canonical
path with the returned data, preserving ADR-003 exact-root authorization. It
uses an intentionally missing bookmark for authorization recovery, a pre-
dispatch busy gate, typed mutation/unavailable faults before mutation, and a
one-shot first post-commit loader failure for saved-refresh. All roots and
state belong to the fresh alternate container. The private
`RouteBookmarkStore` remains only a deterministic `AppRouteTests` fake; the
running fixture and runtime acceptance never use it as bookmark authority.

`AppRouteTests` prove Debug/capture/empty-store/recognized-scenario are all
required; unknown/duplicate/partial arguments, ordinary Debug, and Release do
nothing. `AppModel.loadDashboard` seeds this fixture before its first projection
load, while `--rr10-empty-store` keeps normal `DashboardSampleData` absent.
Tests also prove deterministic/idempotent fixture state, initial route
and accessibility status per scenario, one-shot fault behavior, and continued
external-service suppression. This is not a new protocol, service, route,
dependency, network path, generalized harness, or production behavior.

### Required RED

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9B-RED \
  -only-testing:ReleaseRadarTests/DashboardProjectionTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails on absent phase options, status/actions,
generation-owned publication, pre-registration refresh retention, model guards,
shared selector presentation, or Debug capture contract.

### Required GREEN

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9B-GREEN \
  -only-testing:ReleaseRadarTests/DashboardProjectionTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests \
  CODE_SIGNING_ALLOWED=NO
git diff --check -- \
  ReleaseRadar/Projects/ActivePhaseSelector.swift \
  ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift \
  ReleaseRadar/Projects/DashboardProjection.swift \
  ReleaseRadar/App/ReleaseRadarApp.swift \
  ReleaseRadar/App/AppModel.swift \
  ReleaseRadar/Projects/ProjectOverviewView.swift \
  ReleaseRadar/Projects/PhaseBoardView.swift \
  ReleaseRadar/Navigation/SidebarView.swift \
  ReleaseRadar/Shared/FailureStateView.swift \
  ReleaseRadar/App/AppNotificationCoordinator.swift \
  ReleaseRadarTests/DashboardProjectionTests.swift \
  ReleaseRadarTests/AppRouteTests.swift \
  ReleaseRadarTests/NotificationAcceptanceTests.swift
```

Require zero failures/skips and clean diff output. The command tests establish
the immediate authority boundary; projection/AppModel tests establish owner-
visible correctness, direct no-UUID guards, deterministic stale-generation
success/failure suppression across projection, error, and phase-selection
status, current-generation target reconciliation, and cross-phase detail-
reference preservation. They also establish `NOCASE`/ID ordering, deterministic
pre-registration and registered refresh-before-notification behavior, and the
default-off Debug capture matrix.

## Happy path

1. Both Overview and Board show the same current persisted phase and ordered
   alternatives.
   A project with phases but no active pointer shows **No active phase** and
   keeps the selector actionable on both routes.
2. Owner chooses a different phase by pointer or keyboard.
3. Per-project state becomes Saving immediately; both controls disable and
   announce **Saving active phase**.
4. App resolves the exact bookmark-backed project and dispatches one fresh
   RR-R9A command with owner origin and deterministic reason.
5. Success reloads a coherent current-generation projection. Active name, five
   lane counts/cards, detail-record membership, dependency-graph nodes,
   Activity, and selected ticket belong to the target phase before the UI
   reports ready. Valid same-project cross-phase references inside that active
   ticket's detail remain truthful.
6. Existing selected ticket remains only when present in the new phase;
   otherwise the lexical first target ticket is selected. An empty phase shows
   no selected card/detail and no stale dependency graph.
7. Relaunch loads the same active phase and board from persistence.

## Non-happy paths and recovery

### Busy

Repeated click, Return, or Space while `.saving` creates no second UUID,
request, mutation, or audit. The state remains visible on both selector
placements. The same guarantee applies to direct model calls because AppModel,
not view disablement, checks `.saving` before request-ID generation.

### Already active

A direct call naming `project.activePhaseID` returns before authorization and
UUID generation regardless of how many alternatives exist. It leaves status,
projection, request receipts, and audits unchanged. This owner no-op does not
change RR-R9A's accepted behavior that a fresh agent assignment of the current
phase may be audited as explicit agent intent.

### No alternative phase

When the sole phase is already active, the selector remains visible but
disabled and exposes exact help: **No other phases are available for this
project.** No command is dispatched. A sole unselected phase is an available
choice, not this state. A project with zero phases keeps the existing tracking
state required fallback because phase creation is outside RR-R9.

### Authorization unavailable

Missing/stale/denied/mismatched bookmark shows a phase-selection authorization
failure and **Locate / Reauthorize…**. The directory-only panel may restore only
the same canonical project root. Cancel or rejected folder changes nothing.
Successful reauthorization changes no phase and does not retry; owner selects
again explicitly.

### Mutation failed

Typed dispatcher error shows inline failure with no saved claim. Preserve old
active phase, coherent board, selection, dependencies, history, and controls.
When another safe attempt is possible, the owner initiates it explicitly.

### Saved, refresh needed

Successful command plus projection-load failure shows **Active phase saved;
refresh needed**, names the committed target, and marks the last coherent board
as not refreshed. It offers only **Reload dashboard**. Reload performs no
command and is safe to repeat. Exactly one request/audit exists throughout.
Any direct same- or different-phase selection call in this state returns before
UUID generation and leaves that one request/audit unchanged.

### Superseded reload

Every full reload increments and captures an AppModel generation before its
first suspension. If a newer reload begins, an older success or failure returns
`.superseded` and publishes nothing. It cannot overwrite the newer dashboard,
workspace dictionaries, dependency graph, Activity, visible selection, error,
or phase-selection recovery state, and its caller performs no `.idle`,
`.savedNeedsReload`, or other observable reconciliation. Only the current
generation's non-suspending success/failure publication boundary may reconcile
status. A current successful projection clears a pending `.saving(target)` or
`.savedNeedsReload(target, _)` only when it contains that target; a mismatch
leaves the pending status unchanged. A current owner post-commit failure may
establish or preserve saved-needs-reload.

### External agent refresh failure

The post-reply refresh runs before potentially slow notification draining. If a
successful command arrives before AppModel registers the optional handler, the
coordinator retains one coalesced pending bit and starts no notification drain.
Handler registration begins exactly one read-only refresh for that batch before
draining; a normally registered callback uses the same order. Generation-owned
publication controls any overlap. The refresh may fail after a successful MCP
response; the full dashboard
failure offers **Reload dashboard** and performs read-only load. It does not
delay/replace the command result, change Pushover delivery semantics, or retry
mutation. The action and coordinator callback both use
`reloadDashboardAfterCommittedAgentCommand()`, which calls only the coherent
projection reload; it does not call the broader launch loader or drain
notifications.

### Outcome unknown

The owner path uses in-process dispatcher results and does not manufacture
uncertainty. The external transport retains `outcomeUnknown`; refresh persisted
state and replay only the complete original request with the same UUID when
needed. Never generate a replacement request automatically.

## UI, keyboard, accessibility, and responsive contract

- Native menu-style Picker labelled **Active phase** on both surfaces.
- Selected accessibility value names phase and ID; duplicated names remain
  distinguishable.
- An absent pointer exposes accessibility value **No active phase** while phase
  options remain operable.
- Standard macOS focus traversal, menu opening, arrow navigation, Return,
  Space, and Escape work without a pointer.
- Busy state is visible and announced; disabled controls communicate why.
- Disabled controls are presentation only; every callback still crosses the
  AppModel already-active, `.saving`, and `.savedNeedsReload` guards.
- Failure and recovery elements use stable identifiers and actionable copy.
- Overview placement remains in the active-phase delivery section beside the
  existing Open Board action.
- Board placement remains in the header beside Card density; phase selection
  does not alter density state.
- At the accepted wide comparison near `1586 × 992`, leading project/phase
  context and trailing controls preserve the hierarchy in `phase_board.png`.
- At `760 × 520`, controls stack/wrap without clipping, and existing horizontal
  lane plus vertical board/detail recovery remains usable.
- Use the existing graphite/navy native panels, typography, borders, cyan
  selection, restrained status tones, spacing, and SF Symbols. No redesign.

## Activity and audit evidence

Happy-path owner selection produces exactly one audit with:

- actor `release-radar-owner`;
- no asserted external thread;
- reason `"Owner selected active phase \(phaseID.rawValue)"`;
- resolved project, entity type `phase`, selected phase ID;
- returned audit event ID and timestamp.

Activity reload displays the exact reason, but Activity does not expose actor,
asserted-thread attribution, audit cardinality, or command receipts. Isolated
RR-R9A dispatcher tests and signed transport fixtures remain authoritative for
those fields and cardinalities; RR-R9C does not add an Activity actor or
receipt UI. Authorization-only reauthorization
retains its existing separate project-scoped owner audit and never doubles as a
phase-selection audit. Rejected selections, no-alternative state, UI cancel,
read-only reload, already-active model calls, duplicate calls while `.saving`,
and calls while `.savedNeedsReload` create no phase-selection audit. RR-R9C
records its request ID and returned audit ID and visibly proves the exact reason;
the isolated tests prove that live-command shape maps to
`release-radar-agent` with the accepted attribution/cardinality semantics.

## Acceptance criteria

- Both owner surfaces use one shared selector and one `AppModel` state/action
  path; no duplicated mutation logic.
- Owner selection dispatches accepted RR-R9A with `.ownerApp` only under valid
  bookmark scope.
- Same-project options are deterministic by `name COLLATE NOCASE, id`, including
  an asserted ID tie-break for names equal under `NOCASE`. Board cards,
  `details` keys, and dependency-graph nodes remain active-phase scoped, while
  valid same-project cross-phase dependency references remain visible in the
  active ticket's detail and their persisted rows remain unchanged.
- Projects with phases but no pointer expose the selector on both routes and
  can establish the first active pointer; zero-phase projects retain the
  existing tracking-state fallback.
- A successful selection immediately and coherently refreshes name, cards,
  counts, detail, dependencies, Activity, and valid visible selection and
  survives relaunch.
- Historical phases, tickets, state, dependencies, and audit history remain
  unchanged.
- Direct AppModel guards prevent UUID generation, request creation, and audit
  creation for already-active, `.saving`, and `.savedNeedsReload` calls; busy
  and sole-already-active views retain exact accessible semantics.
- A captured monotonically increasing generation lets only the newest full
  reload publish. Deterministic stale-success and stale-failure interleavings
  cannot overwrite newer dashboard/workspace state or error/status state, and
  a stale caller performs no observable reconciliation. The current generation
  clears a pending target only when its prepared projection contains that
  target; a mismatch preserves the pending status.
- Authorization, unavailable, mutation-failed, and saved-refresh states are
  explicit, actionable, and never silently retry.
- A committed external command refreshes the dashboard before notification
  draining can delay the visible result. Pre-registration successes coalesce,
  begin no notification drain while the handler is absent, and start exactly
  one read-only refresh on registration; normal registered ordering is also
  acceptance tested without delaying the MCP reply.
- Saved-refresh recovery performs only read-only reload and preserves exactly
  one request/audit.
- Wide and compact source-level layout decisions preserve existing density,
  five-lane, inspector, and recovery behavior; RR-R9C confirms the running UI.
- The exact Debug-only, default-off RR-R9 fixture reproduces every required
  runtime state in a fresh alternate container under existing capture
  suppression, without owner-database inspection, network use, or Release/
  ordinary-Debug behavior.
- No migration, dependency, route, service, permission, notification, phase
  manager, ticket editor, plugin change, or direct SQLite access is introduced.
- Fresh independent reviews report zero open Required findings before RR-R9C.

## Required independent reviews

- Code Reviewer: design/brief compliance, single command path, model guards,
  generation ordering, projection coherence, and behavioral preservation
- QA/Test: fresh RED/GREEN, all state fixtures, relaunch, accessibility and
  runtime visual/responsive proof
- Architect: ADR-003 compliance, persistence/projection/refresh boundaries,
  current-request publication, dependency semantics, and no new authority
- Security/Privacy: bookmark scope/recovery, owner/external attribution,
  same-project validation, no permission/data expansion
- TPM: complete-outcome coverage and RR-R9C readiness
- Delivery Manager: evidence, role independence, serialized writes, live gate

The Implementer cannot perform these reviews. Required findings block; optional
and out-of-scope findings do not expand RR-R9.

## RR-R9C handoff and live acceptance evidence

RR-R9C performs no planned product implementation. After RR-R9A/RR-R9B are
accepted, it must produce the following evidence.

### Automated and signed package evidence

```bash
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
./script/build_and_run.sh --stage-release-no-launch
codesign --verify --deep --strict --verbose=2 dist/ReleaseRadar.app
git diff --check
```

Record test count/failures/skips, package identity/signing, bridge cleanup, and
any unrelated pre-existing failure separately.

### Isolated runtime evidence

Build a fresh alternate Debug identity and retain its generated values:

```bash
RR9_CAPTURE_SUFFIX=$(/usr/bin/uuidgen | /usr/bin/tr '[:upper:]' '[:lower:]')
RR9_CAPTURE_BUNDLE_ID="com.rekonlabs.ReleaseRadar.RR9Capture.${RR9_CAPTURE_SUFFIX}"
RR9_CAPTURE_ROOT=$(/usr/bin/mktemp -d /tmp/release-radar-rr9-capture.XXXXXX)
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -derivedDataPath "${RR9_CAPTURE_ROOT}/DerivedData" \
  PRODUCT_BUNDLE_IDENTIFIER="${RR9_CAPTURE_BUNDLE_ID}"
codesign --verify --deep --strict --verbose=2 \
  "${RR9_CAPTURE_ROOT}/DerivedData/Build/Products/Debug/ReleaseRadar.app"
```

For each state, quit normally and relaunch the same alternate app with the
recognized scenario; wait for the expected accessibility identifier/value,
never a fixed sleep:

```bash
/usr/bin/open -n \
  "${RR9_CAPTURE_ROOT}/DerivedData/Build/Products/Debug/ReleaseRadar.app" \
  --args --rr10-capture --rr10-empty-store \
  --rr9-active-phase-fixture=happy
```

Replace only `happy` with each recognized scenario. Authorization recovery
selects the exact fixture root:

```text
~/Library/Containers/${RR9_CAPTURE_BUNDLE_ID}/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/RR9ActivePhaseCaptureRoots/authorization
```

Do not launch the owner bundle, inspect owner or alternate SQLite files, use a
network service, or seed outside the app-owned fixture. Record accessibility
observations and these canonical screenshots:

- `docs/delivery/evidence/rr-r9-active-phase-overview.png`
- `docs/delivery/evidence/rr-r9-active-phase-board-wide.png`
- `docs/delivery/evidence/rr-r9-active-phase-board-compact.png`
- `docs/delivery/evidence/rr-r9-active-phase-recovery.png`

Cover both selector placements; pointer and keyboard happy path; busy; no
alternative; mutation failure; unavailable and authorization recovery;
saved-refresh failure and read-only retry; empty target phase; coherent
cards/counts/detail/dependencies/selection/Activity; relaunch; wide near
`1586 × 992`; compact `760 × 520`; and recovery from a multi-phase project with
no active pointer. Confirm an active ticket's valid cross-phase dependency
reference remains in detail while its other-phase ticket remains absent from
board cards and graph nodes. Compare the running board with
`docs/design/mockups/phase_board.png`. Source/tests alone are not visual proof.

### Independent gates

Fresh combined Code Review, QA, Architecture, Security/Privacy, TPM, and
Delivery Management must report Required 0. A Required finding may authorize
only the minimum correction necessary for RR-R9 acceptance and its focused
reverification.

### Final accepted live command

Only after final GO and after the owner-facing Release Radar process is no
longer running, install the already verified staged Release bundle, verify it,
and explicitly launch that exact installed bundle:

```bash
./script/build_and_run.sh --install-staged-release-no-launch
codesign --verify --deep --strict --verbose=2 /Applications/ReleaseRadar.app
/usr/bin/open -n /Applications/ReleaseRadar.app
```

Do not generate a UUID yet. First wait for the installed app dashboard and an
**Active phase** selector to expose their ready accessibility state. Then use
the currently installed `release-radar` MCP connection for read-only JSON-RPC
`initialize` and `tools/list`; require the installed server identity and exact
accepted `release_radar_set_active_phase` strict schema. Do not substitute a
staged/test binary or probe readiness with a mutation. If either app or MCP
readiness fails, stop before UUID generation.

Only after both readiness checks pass, from the exact authorized Release Radar
root generate one fresh UUID and call `release_radar_set_active_phase` once.
Generate and durably record the request ID first:

```bash
/usr/bin/uuidgen
```

Use that command's exact stdout as `requestID`; do not regenerate it during the
acceptance attempt. The arguments are exactly:

```json
{
  "version": 1,
  "requestID": "<the one recorded UUID from stdout>",
  "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
  "reason": "Activate RR-ROADMAP after RR-R9 acceptance",
  "phaseID": "RR-ROADMAP"
}
```

Record the actual UUID and returned audit ID. On `outcomeUnknown`, preserve and
replay only the complete original argument object, including that UUID, if
needed; do not create a new request. Owner SQLite inspection and edits are
prohibited.

Require immediate running UI readback of `RR-ROADMAP` with Backlog 8,
In progress 0, Needs review 0, Blocked 3, Accepted 0; target-phase detail and
dependencies; Activity's exact visible reason; the returned audit ID paired
with the one recorded request ID supplied in the invocation; and the same
coherent board/reason after relaunch. `AgentCommandResult` does not echo request
ID, and RR-R9 does not expand that shared result contract. Verify the previous
active phase remains a selector option. Activity
does not expose actor or receipts: isolated app-owned RR-R9A tests and signed
transport fixtures remain the accepted proof for actor/asserted-thread fields,
exactly-one audit/receipt cardinality, replay, and field-for-field history.

## Completion evidence for `docs/delivery/progress.md`

Delivery Management records:

- RR-R9B and RR-R9C status/dependency gates and assigned independent roles;
- bounded files and confirmation of preserved unrelated dirty changes;
- exact RED/GREEN and final test commands/results;
- owner actor/reason/audit/receipt and relaunch evidence from isolated app-owned
  tests, plus visible Activity reason evidence;
- busy/no-alternative/authorization/mutation/saved-refresh/no-retry evidence;
- counting request-ID evidence for direct already-active, `.saving`, and
  `.savedNeedsReload` model guards, with request/audit deltas;
- deterministic older-A/newer-B generation interleavings for stale success and
  stale failure, proving dashboard/workspace/error and phase-selection status
  remain exactly as B published, plus current-generation target match/mismatch
  status reconciliation evidence;
- active-phase card/detail-key/graph-node membership plus preserved cross-phase
  detail reference, unchanged dependency-row evidence, and the `NOCASE`/ID
  phase-order tie-break;
- pre-registration coalesced refresh and ordinary registered refresh-before-
  notification ordering, including zero drain while the handler is absent;
- running wide/compact screenshots, keyboard/accessibility state, mockup
  comparison, every recognized Debug scenario observation, launch-guard matrix,
  and any approved deviation reference;
- configured build, signing, installed package, bridge cleanup, and isolated
  container proof;
- every independent review outcome and Required finding closure;
- installed app/selector and installed MCP `initialize`/`tools/list` readiness
  before UUID generation;
- actual final MCP request UUID, returned audit ID, immediate `RR-ROADMAP`
  counts/detail/dependency/visible-Activity-reason readback, and relaunch
  persistence;
- isolated RR-R9A/signed-transport authority for agent actor/asserted thread and
  exactly-one audit/receipt, unchanged historical state, explicit confirmation
  that no owner database was inspected, residual risks, and the next eligible
  RR-ROADMAP work item or closed decision gate.

The ledger remains the sole current delivery authority. Temporary build/test
paths are evidence locations only, never controlling artifacts.
