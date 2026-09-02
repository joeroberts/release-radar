# Release Radar Active Phase Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let owners and authorized agents select a project's persisted active
phase through one validated, audited command path, refresh every affected
dashboard projection immediately, and finish by activating `RR-ROADMAP`.

**Architecture:** Extend the existing durable `AgentCommandEnvelope` with one
additive `setActivePhase` case and expose it through the current signed MCP/XPC
transport. The app remains the only SQLite writer and updates only
`project_active_phases` inside the existing audited/idempotent transaction.
Project Overview and Phase Board share one native SwiftUI selector backed by
`AppModel`; the owner path resolves the existing security-scoped bookmark and
dispatches the same command with `.ownerApp`, then coherently reloads the board,
dependencies, activity, and ticket selection. AppModel guards no-op/duplicate
owner calls before UUID creation and uses a current-generation publication gate
so stale reloads cannot overwrite newer state; active ticket detail retains
accepted same-project cross-phase dependency references.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation/AppKit,
`DeliveryStore`/SQLite, the existing signed ServiceManagement/XPC bridge,
newline-delimited MCP JSON-RPC, XCTest, Xcode 26, and existing Computer Use
runtime inspection.

**Spec:** `docs/design/release-radar-active-phase-selection-design.md`

**Architecture Decision:**
`docs/architecture/ADR-003-active-phase-selection.md`

**Task briefs:**

- `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-1-brief.md`
- `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-2-brief.md`

## Global Constraints

- Complete RR-R9 means RR-R9A authority, RR-R9B owner experience, and RR-R9C
  integrated acceptance plus `RR-ROADMAP` activation. A passed intermediate
  task does not narrow or complete the feature.
- Minimum macOS remains 14.0 and Swift remains 6.0. Add no dependency, test
  framework, target, service, helper, schema migration, entitlement, or network
  access.
- `project_active_phases` remains the sole active-phase authority and already
  enforces zero-or-one selection plus same-project phase identity.
- The app process remains the sole SQLite writer. AgentTools, broker, lifecycle
  helper, observers, and project processes never open the store.
- Implementers and acceptance operators never inspect or mutate the owner
  SQLite database; app-owned isolated fixtures/tests prove persistence and
  cardinality.
- Durable command-envelope version remains `1`; bridge wire version remains
  `2`; every current size, deadline, signing, strict-JSON, authorization,
  request-replay, and post-handoff uncertainty rule remains unchanged.
- The new typed MCP tool is exactly `release_radar_set_active_phase`; its only
  command-specific field is required string `phaseID`.
- Owner UI resolves the existing project bookmark and dispatches
  `AgentCommand.setActivePhase` with `origin: .ownerApp`. It does not write the
  table directly or introduce a second mutation service.
- Selection updates only the active-phase pointer and one audit/request receipt.
  Preserve all phases, tickets, lanes, dependencies, blockers, evidence,
  reviews, completions, notifications, and audit history.
- Board cards, `details` keys, and dependency-graph nodes are active-phase
  scoped. An active ticket's detail may continue to expose valid same-project
  cross-phase `requires` or `unlocks` references; selection never filters or
  rewrites those dependency rows.
- Never retry a phase mutation automatically. A committed-but-refresh-failed
  state offers read-only reload; `outcomeUnknown` recovery replays only the
  complete original request with the same `requestID`.
- AppModel guards owner requests before UUID generation: already-active,
  per-project `.saving`, and per-project `.savedNeedsReload` calls return with
  no new request or audit. View disablement is not authority.
- Every full AppModel projection reload captures one monotonically increasing
  generation before its first suspension; only the current generation's non-
  suspending boundary may publish success, failure, or active-phase status
  reconciliation. A superseded caller performs no observable write.
- Project Overview and Phase Board remain the only owner selector surfaces.
  No new route, all-phase board, Project Plan, ticket editor, or phase manager.
- Runtime acceptance adds only the exact default-off Debug RR-R9 fixture/fault
  path under existing capture suppression; no generalized harness, dependency,
  network use, or production-default behavior.
- `docs/delivery/progress.md` remains the only status/evidence ledger and may be
  changed only by the assigned Delivery Manager after implementation/reviews.
- Preserve unrelated dirty-working-tree changes and do not modify current
  `AGENTS.md` files.

---

### Task 1 (RR-R9A): Add the typed active-phase authority end to end

RR-R9A is independently reviewable but not a complete user feature. It
delivers the command contract through persistence, audit, durable replay,
signed transport, and MCP. It changes no owner UI.

**Files:**

- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarAgentTools/main.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- Verify unchanged contract: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Verify unchanged contract: `ReleaseRadarTransport/BridgeXPCContracts.swift`

**Interfaces:**

- Consumes `project_active_phases(project_id PRIMARY KEY, phase_id)` and its
  composite foreign key to `phases(project_id, id)`.
- Produces `AgentCommand.setActivePhase(phaseID: String)`.
- Produces MCP tool `release_radar_set_active_phase` with the standard envelope
  fields plus required `phaseID` and `additionalProperties: false`.
- Produces a successful `AgentCommandResult` with
  `entityIDs: [phaseID]`, the transaction's returned `auditEventID`, and
  `error: nil`, with audit scope `(project, phase, phaseID)`.
- Preserves all current `AgentCommandError` cases; unknown, cross-project, and
  unauthorized inputs map to existing typed errors.

- [ ] **Step 1: Write dispatcher RED tests for commit, audit, replay, relaunch,
  origin, and history preservation**

Add a two-project, multi-phase fixture in
`AgentBridgeAcceptanceTests`. Snapshot the ordered rows from `phases`,
`tickets`, `phase_dependencies`, and `ticket_dependencies`, then dispatch:

```swift
let envelope = AgentCommandEnvelope(
    version: AgentCommandDispatcher.commandEnvelopeVersion,
    requestID: UUID(uuidString: "91919191-9191-4919-8919-919191919191")!,
    projectRoot: fixture.projectRoot.path,
    reason: "Activate established product roadmap",
    command: .setActivePhase(phaseID: "RR-ROADMAP")
)
let first = await fixture.dispatcher.dispatch(envelope)
let replay = await AgentCommandDispatcher(
    store: DeliveryStore(databaseURL: fixture.databaseURL),
    projectRegistry: fixture.registry
).dispatch(envelope)
```

Require `entityIDs == ["RR-ROADMAP"]`, a non-nil stable audit ID, exact replay
equality, one command receipt, one audit, active phase `RR-ROADMAP` after store
recreation, actor `release-radar-agent`, exact reason, entity type `phase`, and
unchanged history snapshots. Dispatch a second valid selection with
`origin: .ownerApp` and require actor `release-radar-owner`.

Before changing the pointer, dispatch a separate fresh request that assigns the
already-active `phase-current`. Require success, `entityIDs ==
["phase-current"]`, the pointer unchanged, and exactly one new
`release-radar-agent` phase audit plus one new durable request receipt because
this is explicit agent intent. Replay that exact envelope after dispatcher
recreation and require the original result with no further audit, receipt,
pointer, or history delta.

- [ ] **Step 2: Write dispatcher RED tests for invalid, cross-project, empty,
  oversized UTF-8, and changed-replay inputs**

Use separate fresh request IDs for missing and other-project phase IDs:

```swift
let missing = AgentCommand.setActivePhase(phaseID: "missing-phase")
let crossProject = AgentCommand.setActivePhase(phaseID: "other-project-phase")
```

Require `.invalidReference` and `.crossProjectReference`, respectively. Add an
empty phase ID and this non-whitespace multibyte over-limit ID to the existing
bounded-envelope validation matrix:

```swift
let oversizedPhaseID = String(repeating: "é", count: 129)
XCTAssertEqual(oversizedPhaseID.utf8.count, 258)
```

Use a fresh request ID, require `.invalidEnvelope`, and require zero pointer,
receipt, audit, phase, ticket, and dependency-history changes. Reuse the success
request ID with a different phase and require `.requestIDReused`. After every
rejection, require the prior active phase, all historical table snapshots,
audit count, and command-receipt count to remain unchanged.

- [ ] **Step 3: Run the core RED test**

Run:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Core-RED \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `AgentCommand.setActivePhase` does not
exist. Preserve that failure as RR-R9A RED evidence; do not change the schema.

- [ ] **Step 4: Implement the additive command and dispatcher contract**

Add the enum case exactly:

```swift
case setActivePhase(phaseID: String)
```

Add exhaustive handling to `validate`, `resultForCommand`, `auditScope`, and
`apply`. The implementation branch is exactly the existing validator plus one
upsert:

```swift
case let .setActivePhase(phaseID):
    try requireProjectEntity(
        phaseID,
        table: "phases",
        projectID: projectID,
        connection: connection
    )
    try connection.execute(
        """
        INSERT INTO project_active_phases (project_id, phase_id)
        VALUES (?, ?)
        ON CONFLICT(project_id) DO UPDATE SET phase_id = excluded.phase_id
        """,
        bindings: [.text(projectID.rawValue), .text(phaseID)]
    )
```

Validation uses `valid(phaseID, maximum: 256)`. Result scope is
`entityIDs: [phaseID]`; audit scope is `(.phase, phaseID)`. Do not add a store
method, migration, notification, or special-case transaction.

- [ ] **Step 5: Run the core GREEN test**

Run the Step 3 command with DerivedData
`/tmp/ReleaseRadar-RR-R9A-Core-GREEN`. Expected: all
`AgentBridgeAcceptanceTests` pass, including new success/rejection/replay cases.

- [ ] **Step 6: Write the MCP schema and packaged-tool RED test**

In `AgentBridgeTransportAcceptanceTests`, update the typed-tool assertion to
expect 13 tools and require this exact schema:

```swift
let setActivePhase = tools.first {
    $0["name"] as? String == "release_radar_set_active_phase"
}
let schema = setActivePhase?["inputSchema"] as? [String: Any]
let properties = schema?["properties"] as? [String: Any]
let required = schema?["required"] as? [String]
XCTAssertEqual(
    Set(properties?.keys.map { $0 } ?? []),
    ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "phaseID"]
)
XCTAssertEqual(
    Set(required ?? []),
    ["version", "requestID", "projectRoot", "reason", "phaseID"]
)
XCTAssertEqual(schema?["additionalProperties"] as? Bool, false)
```

Extend the temporary signed-transport fixture with `phase-2`, invoke the
packaged tool with a fresh request ID and reason, assert `mcpIsError == false`,
the selected phase persisted, the returned audit is phase-scoped, and exact
replay returns the same result with one receipt/audit. Retain the existing
wrong-peer, wrong-version, app-unavailable, pre-admission-expiry,
post-handoff-unknown, and exact-replay cases; they are the unchanged recovery
contract for every command.

- [ ] **Step 7: Run the signed transport RED test**

Run:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Transport-RED \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests
```

Expected: the tool count/schema or new tool call fails because AgentTools does
not expose `release_radar_set_active_phase`.

- [ ] **Step 8: Implement the MCP tool without changing transport**

Add this exact command mapping:

```swift
case "release_radar_set_active_phase":
    return (
        "setActivePhase",
        ["phaseID": try string("phaseID", in: arguments)]
    )
```

Add this exact definition beside the other delivery mutations:

```swift
definition(
    "release_radar_set_active_phase",
    required: ["phaseID"],
    fields: ["phaseID": string]
)
```

Keep the standard definition helper, strict string parser, envelope size,
MCP protocol version, broker call, and error mapping unchanged. Do not update
the plugin manifest/version; it already points to the installed AgentTools
binary.

- [ ] **Step 9: Run RR-R9A GREEN and regression verification**

Run:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9A-GREEN \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests
git diff --check -- \
  ReleaseRadarCore/AgentBridge/AgentCommand.swift \
  ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift \
  ReleaseRadarAgentTools/main.swift \
  ReleaseRadarTests/AgentBridgeAcceptanceTests.swift \
  ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
```

Expected: all selected tests pass with zero failures/skips, the signed transport
cleanup leaves no owned bridge registration/process, and diff check is clean.
`StoreAcceptanceTests` is regression evidence for the unchanged active-phase
foreign key and transaction boundary, not a substitute for the new command
tests.

- [ ] **Step 10: Obtain RR-R9A independent acceptance**

A fresh Code Reviewer, QA/Test verifier, Architect, Security/Privacy verifier,
TPM, and Delivery Manager inspect RR-R9A. Required findings only block release.
Delivery Management records RED/GREEN commands, signed transport cleanup,
schema-unchanged proof, audit/replay/history evidence, role decisions, and the
RR-R9B gate in `docs/delivery/progress.md`. RR-R9B starts only after GO.

- [ ] **Step 11: Commit the independently accepted RR-R9A slice**

```bash
git add \
  ReleaseRadarCore/AgentBridge/AgentCommand.swift \
  ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift \
  ReleaseRadarAgentTools/main.swift \
  ReleaseRadarTests/AgentBridgeAcceptanceTests.swift \
  ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift \
  docs/delivery/progress.md
git commit -m "feat: add active phase command"
```

Stage only files attributable to RR-R9A and the Delivery Manager's ledger
entry. Preserve every unrelated working-tree change.

---

### Task 2 (RR-R9B): Deliver the shared owner phase selector and coherent refresh

**Dependencies:** RR-R9A accepted and the Delivery Manager releases RR-R9B.

**Files:**

- Create: `ReleaseRadar/Projects/ActivePhaseSelector.swift`
- Create: `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` as the
  targeted Debug-only, default-off RR-R9 runtime fixture/fault path
- Modify: `ReleaseRadar/App/ReleaseRadarApp.swift` only for the recognized
  Debug capture launch configuration and fixture injection
- Modify: `ReleaseRadar/Projects/DashboardProjection.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Projects/ProjectOverviewView.swift`
- Modify: `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modify: `ReleaseRadar/Navigation/SidebarView.swift`
- Modify: `ReleaseRadar/Shared/FailureStateView.swift` only for phase-selection
  failure/recovery presentation reused by both surfaces
- Modify: `ReleaseRadar/App/AppNotificationCoordinator.swift` only to retain a
  coalesced pre-registration successful-command refresh and run read-only
  dashboard refresh before potentially slow notification draining
- Modify: `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`

The synchronized Xcode source groups automatically include the new Swift files;
do not modify `ReleaseRadar.xcodeproj/project.pbxproj` for membership.

**Interfaces:**

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

enum ActivePhaseSelectionStatus: Equatable, Sendable {
    case idle
    case saving(PhaseID)
    case mutationFailed(FailureStatePresentation, canReauthorize: Bool)
    case savedNeedsReload(PhaseID, String)
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

// AppModel-owned and accessed only on the main actor.
private var projectionReloadGeneration: UInt64 = 0
private let requestIDGenerator: () -> UUID
private var activePhaseSelectionStatuses: [ProjectID: ActivePhaseSelectionStatus] = [:]

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

@MainActor
private func prepareProjectProjections() async throws -> PreparedProjectProjections

@MainActor
private func publish(_ prepared: PreparedProjectProjections)

@MainActor
func setActivePhase(projectID: ProjectID, phaseID: PhaseID) async

@MainActor
func reloadAfterActivePhaseSelection(projectID: ProjectID) async

@MainActor
func reauthorizeActivePhaseProject(at folder: URL, projectID: ProjectID) async

@MainActor
func reloadDashboardAfterCommittedAgentCommand() async

// AppNotificationCoordinator actor state.
private var pendingSuccessfulCommandRefresh = false
private var successfulCommandRefreshDrainInProgress = false

func setDashboardRefreshHandler(
    _ handler: @escaping DashboardRefreshHandler
) async

private func drainSuccessfulCommandRefreshIfPossible() async
```

`AppModel.init` gains
`requestIDGenerator: @escaping () -> UUID = { UUID() }` as a narrow test seam.
Production calls it only after every owner no-op/duplicate guard passes.

`AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(arguments:isDebugBuild:)`
returns a scenario only for Debug launches that contain `--rr10-capture`,
`--rr10-empty-store`, and exactly one recognized
`--rr9-active-phase-fixture=<scenario>` argument. The RR-R9 fixture/fault
configuration is compiled under `#if DEBUG`; its AppModel input defaults to
`nil` and has no Release-build or ordinary-Debug behavior.

The shared `ActivePhaseSelector` consumes `project.phases`, optional
`project.activePhaseID`, per-project status, and the three actions above.
`PhaseBoardProjection.phaseID` remains non-optional. Card membership,
`details` keys, and dependency-graph nodes remain active-only; dependency
references inside each active ticket detail retain the cross-phase exception
defined above.

- [ ] **Step 1: Write projection RED tests for full phase options and scoped
  board data**

Extend `DashboardProjectionTests` with a project containing:

- active `phase-current` with two tickets, one phase-local dependency, and one
  dependency from an active ticket to a ticket in `phase-roadmap`;
- inactive `phase-roadmap` with eleven tickets, including eight Backlog and
  three Blocked, and phase-local dependencies;
- a historical phase with an Accepted ticket;
- phases `phase-order-a` and `phase-order-z`, inserted in reverse ID order,
  whose names are `Roadmap` and `ROADMAP` and therefore compare equal under
  SQLite `NOCASE`.

Require deterministic `name COLLATE NOCASE, id` phase options, including
`phase-order-a` before `phase-order-z` regardless of reverse insertion order;
require `board.phaseID` equal to the persisted active phase, and cards,
`details` keys, and dependency-graph nodes containing only its tickets. Require
the selected active ticket's detail to retain the cross-phase ticket in
`requires`, while that referenced ticket is absent from board cards and graph
nodes. Change the pointer through
`AgentCommand.setActivePhase`, recreate the store, reload, and require
`phase-roadmap`, counts `[8, 0, 0, 3, 0]`, truthful `requires`/`unlocks`
direction, unchanged dependency rows/history, and no cross-phase card or graph-
node leakage.

Add a second multi-phase project with no `project_active_phases` row. Require
its project projection to expose optional `activePhaseID == nil` and all phase
options while `board(for:) == nil`. This is an accepted persisted state, not a
reason to hide the selector.

- [ ] **Step 2: Write AppModel RED tests for owner dispatch and coherent
  refresh**

Use the existing temporary store/bookmark fixture patterns in `AppRouteTests`.
After `loadDashboard()`, call:

```swift
await model.setActivePhase(
    projectID: projectID,
    phaseID: PhaseID(rawValue: "phase-roadmap")
)
```

Require one `release-radar-owner` audit with reason
`Owner selected active phase phase-roadmap`, one command receipt, persisted
selection, new board/counts/details, rebuilt dependency graph, Activity reason,
and a selected ticket that belongs to the new phase. Recreate `AppModel` and
require the same selected phase after load.

Inject a counting `requestIDGenerator`. Add three direct model-boundary cases:

- requesting `project.activePhaseID` from `.idle` leaves the generator, request
  rows, audits, status, and projection unchanged;
- while the first call is held after entering `.saving`, a second call for the
  same or a different phase does not increment the generator or counts;
- after one committed command and forced refresh failure establish
  `.savedNeedsReload`, another call for the same or a different phase does not
  increment the generator or counts.

The expected request-ID counts are `0`, `1`, and `1`, respectively; request and
phase-selection audit counts match those deltas. Invoke `setActivePhase`
directly in every case rather than relying on disabled SwiftUI controls.

- [ ] **Step 3: Write RED tests for busy, no-alternative, authorization,
  mutation-failed, and saved-refresh recovery**

Add focused cases using existing store queue and injectable `dashboardLoader`
patterns:

- while the store holds the first dispatch, a second selection attempt produces
  no second request/audit and status remains `.saving(target)`;
- one already-active phase yields selector help
  `No other phases are available for this project.` and no mutation, while one
  unselected phase remains actionable;
- a multi-phase project with no active pointer can select from Overview or the
  Phase Board recovery surface and obtains its first coherent board;
- missing/stale/denied/mismatched bookmark produces `.mutationFailed` with the
  phase authorization presentation, leaves the active phase unchanged, and
  requires explicit selection after successful reauthorization;
- unknown target from a direct model call produces typed mutation failure and
  no projection change;
- a dashboard loader that fails after commit produces `.savedNeedsReload`,
  keeps one request/audit, performs no automatic retry, and clears only after
  `reloadAfterActivePhaseSelection(projectID:)` observes the committed phase;
- a sequenced existing `reviewInboxLoader` that fails after the new dashboard
  has loaded proves the reload publishes none of the new dashboard/workspace
  pieces until every required projection is prepared, then succeeds on the
  explicit read-only reload;
- a continuation-gated `dashboardLoader` returns an initial snapshot, suspends
  older ordinary reload A, lets newer reload B enter through the committed-
  agent dashboard handler and publish a distinct active phase/count snapshot,
  then releases A to return its stale snapshot. Require
  the final dashboard, workspace projections, dependency graph, Activity,
  visible selection, error state, and phase-selection status to remain exactly
  as B published. Repeat with A throwing after release and require its stale
  failure not to replace B with an error or reconcile phase-selection status.
  Use checked continuations/actor state, never sleeps or timing polls;
- current-generation publications containing the pending target change
  `.saving(target)` or `.savedNeedsReload(target, _)` to `.idle`; a prepared
  current-generation projection whose active phase does not match `target`
  leaves either pending status exactly unchanged;
- a deterministic pre-registration `AppNotificationCoordinator` fixture sends
  two successful committed-command callbacks before any dashboard handler is
  installed. Require zero refreshes and zero notification-drain starts, then
  register the handler and require exactly one coalesced read-only refresh to
  begin. Hold that refresh with a checked continuation and prove notification
  draining still has not begun; release it and require notification draining;
- a separate normal registered-handler fixture sends one successful committed
  callback, holds the refresh, and proves refresh begins before notification
  draining. Failed command results create no pending refresh. Neither fixture
  uses sleeps, starts a mutation, or changes after-reply result semantics, and
  AppModel generation tests cover overlap with another full reload.

Add pure presentation assertions for accessibility identifiers
`active-phase-selector-overview` and `active-phase-selector-board`, selected
phase name/ID value, **No active phase**, **Saving active phase**, and the exact
sole-active-phase help.

- [ ] **Step 4: Run RR-R9B RED**

Run:

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

Expected: compilation fails because phase options, owner action state,
generation-owned publication, model guards, and the shared selector contract
do not exist.

- [ ] **Step 5: Extend the projection without changing persistence**

For each loaded project, query all same-project phases before the existing
active-phase guard, in deterministic order:

```swift
let phases = try connection.dashboardRows(
    """
    SELECT id, name
    FROM phases
    WHERE project_id = ?
    ORDER BY name COLLATE NOCASE, id
    """,
    bindings: [.text(projectID.rawValue)]
).map {
    ProjectPhaseProjection(
        id: PhaseID(rawValue: try $0.text("id")),
        name: try $0.text("name")
    )
}
```

Pass `phases` and optional active ID into `ProjectDashboardProjection` in both
the active and **No active phase** branches. Keep board-card queries and the
keys inserted into `details` filtered by `projectID` and active `phaseID`.
Preserve `ticketDetail`'s same-project dependency lookups without adding a
phase predicate, so an active ticket may still reference another phase in
`requires` or `unlocks`. Keep dependency-graph nodes active-phase scoped; its
existing edge filter naturally omits an edge whose other endpoint is not a
node. Add no inactive cards or graph nodes, and continue returning no
`PhaseBoardProjection` until a pointer is persisted.

- [ ] **Step 6: Implement per-project owner action state through the same
  dispatcher**

In `AppModel`, store a status dictionary by `ProjectID`. At the start of
`setActivePhase`, before authorization or request-ID creation, apply these exact
guards:

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

Only then resolve authorization with
`projectOnboarding.withAuthorizedProject(projectID:)` and dispatch:

```swift
let result = await AgentCommandDispatcher(
    store: store,
    projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
).dispatch(
    AgentCommandEnvelope(
        version: AgentCommandDispatcher.commandEnvelopeVersion,
        requestID: requestID,
        projectRoot: project.canonicalRoot.path,
        reason: "Owner selected active phase \(phaseID.rawValue)",
        command: .setActivePhase(phaseID: phaseID.rawValue)
    ),
    origin: .ownerApp
)
```

On a typed error, create the phase-selection failure presentation and leave the
old coherent dashboard untouched. On success, call only the existing full
projection reload path. Refactor that private path to increment and capture
`projectionReloadGeneration` on the main actor before its first `await`, then
prepare the new dashboard, review inboxes, guidance/root state, dependency
graphs, Activity, and reconciled visible ticket selection in local values.

Use this publication shape:

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

`PreparedProjectProjections` is a private AppModel value containing only the
dashboard and existing workspace dictionaries plus reconciled visible ticket
selection; it is not a service or second source of truth. `publish` performs no
await and assigns them as one main-actor operation. In that same non-suspending
publication boundary, it clears the applicable dashboard load error and
reconciles every `.saving(target)` or `.savedNeedsReload(target, _)`: change it
to `.idle` only when the prepared project projection has
`activePhaseID == target`; otherwise leave it exactly unchanged.
`publishFailure` also performs no await. For
`.ownerActivePhaseCommitted(projectID, phaseID, phaseName)`, a current-
generation post-commit failure establishes or preserves
`.savedNeedsReload(phaseID, phaseName)` and never dispatches again. Ordinary
and agent-command failures publish their existing scoped dashboard error and
do not reconcile unrelated phase-selection status.

All full dashboard entry points use this method with the appropriate context.
Owner success and explicit saved-refresh recovery use
`.ownerActivePhaseCommitted`; the after-reply agent callback uses
`.agentCommandCommitted`; other loads use `.ordinary`. Callers inspect the
outcome only for control flow. In particular, a stale success or failure
returns `.superseded`, and the caller returns without writing `.idle`,
`.savedNeedsReload`, dashboard error, or any other observable state. Reconcile
`selectedTicketID` to the lexical first card when the old ticket is absent from
the new board; when the phase is empty, no card or detail is visibly selected
and clear that project's stale dependency graph. Preserve the selected ticket
when it exists in the target phase. Reauthorization calls the existing
`reauthorizeProjectRoot`, clears only the authorization failure, and never
selects a phase automatically.

In `AppNotificationCoordinator`, implement the pending-successful-command
contract with actor-owned Booleans, not a queue of envelopes:

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

If the handler is absent, the method retains one coalesced pending bit and does
not begin notification draining. Registration flushes that bit with exactly
one read-only refresh for the pre-registration batch before notifications. A
successful callback arriving during a suspended refresh sets the bit and is
serviced by the same drain before notifications; actor reentrancy cannot start
a second drain. A callback arriving during notification draining remains
pending and is serviced by the same drain before it exits. Failed results do
nothing. Keep this work in the existing
after-reply callback so it cannot delay or replace the committed MCP response.
Route the handler and external-agent failure action through
`reloadDashboardAfterCommittedAgentCommand()`, which calls only the coherent
generation-owned projection reload and never dispatches a command or drains
notifications itself.
Update `FailureStateView` so its existing optional action is also rendered in
`.full` style, and have `SidebarView` offer **Reload dashboard** for this error.

- [ ] **Step 7: Implement the shared native selector**

Create `ActivePhaseSelector.swift` with the exact surface identity:

```swift
enum ActivePhaseSelectorSurface: String, Sendable {
    case overview
    case board

    var accessibilityIdentifier: String {
        "active-phase-selector-\(rawValue)"
    }
}
```

Use a menu-style `Picker` labelled **Active phase**, bind its selection to the
project's optional active `PhaseID`, and tag every option by `PhaseID`. Disable
the whole picker while saving, while saved-refresh recovery is active, or when
the sole option is already active. A sole unselected phase remains enabled.
Ignore a selection equal to the current active ID. Expose **No active phase**
when the pointer is absent. A native `ProgressView` and accessibility value
communicate **Saving active phase**. Add the exact single-active-phase help.
Present
mutation/authorization failures and saved-refresh recovery through inline
`FailureStateView`; only the latter offers **Reload dashboard**, and only
authorization failure offers **Locate / Reauthorize…**. The folder action uses
one directory-only `NSOpenPanel` and passes its URL to the model; cancel
produces no state change.

Treat these disabled states only as accessible presentation. Every picker
callback still calls `AppModel.setActivePhase`, whose already-active,
`.saving`, and `.savedNeedsReload` guards are the mutation authority.

- [ ] **Step 8: Place the same selector on Overview and Board responsively**

Refactor `ProjectOverviewView` to receive its project plus an optional board;
add the selector in the active-phase section before **Open phase board** and
retain truthful zero counts/empty delivery state while no board exists. Add the
selector to `PhaseBoardView.boardHeader` beside the existing Card density
picker. When the route has no board but its project has phases, render the same
selector with the existing tracking-state explanation instead of hiding it
behind `FailureStateView`. Pass identical projection/status/action inputs from
`SidebarView` for both routes. A zero-phase project retains the existing
tracking-state fallback because phase creation is out of scope.

Use `ViewThatFits(in: .horizontal)` or the established width decision so the
Phase Board header presents controls horizontally when they fit and stacked
when they do not. Keep `phase-board-vertical-recovery`, horizontal lane
scrolling, Card density semantics, and selected-ticket detail unchanged.

- [ ] **Step 9: Implement and test the targeted Debug runtime fixture/fault
  path**

Create `RR9ActivePhaseCaptureFixture.swift` under `#if DEBUG`. Follow the
existing `DashboardSampleData.seedIfNeeded` app-owned transaction pattern and
create each runtime-authorized bookmark with the production
`ProjectBookmarkStore.makeBookmark(for:)` security-scoped path. Standardize and
resolve symlinks for the disposable root, pass that exact canonical URL to
`makeBookmark(for:)`, and persist the same canonical path with the returned
bookmark data so ADR-003 exact-root authorization is exercised. Seed one
idempotent fixture in the fresh alternate container. It contains:

- an authorized multi-phase project with current, selectable, empty, and
  historical phases, active/current and cross-phase dependency tickets, and
  the two `NOCASE`-equal phase names;
- one sole-active-phase project;
- one authorized multi-phase project with no active pointer;
- one project with a real disposable persisted root and intentionally absent
  bookmark for **Locate / Reauthorize…** recovery;
- separate IDs for the saved-refresh scenario so its real command does not
  disturb the other captures.

Create disposable roots beneath the alternate bundle's Application Support
directory. Never read or write the owner container. In `ReleaseRadarApp`, parse
only the exact recognized Debug combination:

```text
--rr10-capture --rr10-empty-store --rr9-active-phase-fixture=<scenario>
```

Use the scenario enum defined above. Missing capture/empty-store flags,
unknown/duplicate scenarios, ordinary Debug, and every Release build yield no
RR-R9 seed or fault. `--rr10-capture` continues suppressing external services.
In `AppModel.loadDashboard`, seed the RR-R9 fixture before the first dashboard
load when the Debug scenario is present; `--rr10-empty-store` keeps the normal
`DashboardSampleData` seed off, so the two sample sets never mix. The fixture
then selects the initial project/route. Its only Debug faults are: gate
the first `busy` owner action after `.saving` and before dispatch; synthesize
the typed `mutation-failure` or `unavailable` result before mutation; and fail
exactly the first post-commit full projection load for `saved-refresh` before
allowing the explicit read-only reload. The remaining scenarios exercise real
seeded data and product paths. Do not add a protocol, service, dependency,
network path, persistence field, command, route, or generalized fault harness.

In `AppRouteTests`, test the complete launch-policy matrix, deterministic seed,
valid bookmark versus intentional authorization failure, each initial
route/state, one-shot saved-refresh fault, busy pre-dispatch gate, ordinary-
launch nonactivation, and unchanged external-service suppression. These tests
use temporary stores and existing collaborators; runtime QA never opens or
inspects SQLite directly. Retain the private `RouteBookmarkStore` only as the
deterministic `AppRouteTests` fake; neither the running fixture nor runtime
acceptance may use it as bookmark authority.

- [ ] **Step 10: Run RR-R9B GREEN and the combined regression suites**

Run:

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

Expected: all selected tests pass with zero failures/skips, including the three
direct no-UUID model guards, deterministic stale-generation success/failure
interleavings whose stale completions cannot change projection, error, or
phase-selection status, current-generation target-match status
reconciliation, pending pre-registration command-refresh coalescing and normal
registered ordering, `NOCASE`/ID ordering, the default-off Debug capture matrix,
and cross-phase detail-reference regression; diff check is clean. Do not
broadly refactor AppModel or create runtime infrastructure beyond RR-R9.

- [ ] **Step 11: Obtain RR-R9B independent acceptance**

A separate Code Reviewer verifies spec compliance and behavioral preservation;
QA independently runs the focused suites and runtime checklist; Architecture
checks the single command/store/projection authority; Security/Privacy checks
bookmark scope, same-project validation, signed transport, audit attribution,
and no new entitlement/data exposure; TPM and Delivery Management decide the
RR-R9C gate. The Implementer performs none of these reviews.

- [ ] **Step 12: Commit the independently accepted RR-R9B slice**

```bash
git add \
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
  ReleaseRadarTests/NotificationAcceptanceTests.swift \
  docs/delivery/progress.md
git commit -m "feat: let owners select active phase"
```

Stage only RR-R9B-attributable files and the Delivery Manager's ledger update.

---

### Task 3 (RR-R9C): Integrate, verify the running app, and activate RR-ROADMAP

**Dependencies:** RR-R9A and RR-R9B accepted; all independent reviewers return
Required 0; TPM and Delivery Management explicitly release RR-R9C. RR-R9C adds
no product implementation except minimum corrections for Required acceptance
findings.

**Files:**

- Modify after evidence exists: `docs/delivery/progress.md`
- Add after runtime verification:
  `docs/delivery/evidence/rr-r9-active-phase-overview.png`
- Add after runtime verification:
  `docs/delivery/evidence/rr-r9-active-phase-board-wide.png`
- Add after runtime verification:
  `docs/delivery/evidence/rr-r9-active-phase-board-compact.png`
- Add after runtime verification:
  `docs/delivery/evidence/rr-r9-active-phase-recovery.png`
- Modify product/test files only for a Required finding tied directly to RR-R9
- Do not create a new evidence framework, route, mockup, schema, or service

- [ ] **Step 1: Run the complete focused automated acceptance selection**

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

The signed transport suite must clean up its owned registration/process. Report
unrelated pre-existing failures separately; do not repair them unless they
prevent direct RR-R9 verification.

- [ ] **Step 2: Perform isolated running-app UI and recovery verification**

Build one fresh alternate Debug bundle/container and record its generated
identifier and derived-data root:

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

The bundle has a new sandbox container and launches only with existing external-
service suppression plus the targeted fixture. Do not launch the owner bundle,
inspect any owner or alternate SQLite file, use a network service, or seed data
outside the app-owned fixture. For each scenario, quit normally, relaunch the
same alternate app with the exact scenario, and wait on the expected
accessibility identifier/value rather than sleeping:

```bash
/usr/bin/open -n \
  "${RR9_CAPTURE_ROOT}/DerivedData/Build/Products/Debug/ReleaseRadar.app" \
  --args --rr10-capture --rr10-empty-store \
  --rr9-active-phase-fixture=happy
```

Replace only the final scenario value with `busy`, `no-alternative`,
`mutation-failure`, `unavailable`, `authorization-failure`, `saved-refresh`,
`empty-phase`, `no-active-pointer`, or `cross-phase-detail`. The fixture is
idempotent, uses separate projects for mutating scenarios, and persists in this
isolated container for relaunch checks. For authorization recovery, select the
fixture-created exact root at:

```text
~/Library/Containers/${RR9_CAPTURE_BUNDLE_ID}/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/RR9ActivePhaseCaptureRoots/authorization
```

Through accessibility state and screenshots, verify:

- Overview and Board expose the same **Active phase** selection and state;
- keyboard focus, menu open/navigation/select, Return, Space, and Escape;
- one dispatch while busy, exact saving announcement, and disabled control;
- exact no-alternative help with zero mutation;
- unavailable and authorization failure, directory-only reauthorization, and
  explicit reselection;
- typed mutation failure with unchanged board/history;
- committed write followed by refresh failure, no mutation retry, and successful
  read-only **Reload dashboard** recovery;
- active phase label, five lane counts/cards, selected ticket/detail,
  dependency graph, and Activity update together;
- empty target phase shows no selected card/detail without stale dependencies;
- a multi-phase project with no active pointer can select on both routes and
  obtains the board without a restart;
- an active ticket detail preserves a valid cross-phase dependency reference
  while the referenced ticket remains absent from board cards and graph nodes;
- wide comparison near `1586 × 992` and compact `760 × 520` preserve the mockup
  hierarchy, both controls, all five-lane recovery, and unclipped detail.

Capture the accepted windows directly as PNGs at these canonical repository
paths; other scenario evidence is an accessibility observation in the sole
progress ledger, not an extra evidence framework:

- `docs/delivery/evidence/rr-r9-active-phase-overview.png`
- `docs/delivery/evidence/rr-r9-active-phase-board-wide.png`
- `docs/delivery/evidence/rr-r9-active-phase-board-compact.png`
- `docs/delivery/evidence/rr-r9-active-phase-recovery.png`

Compare the wide Board directly with
`docs/design/mockups/phase_board.png`. Do not claim visual correctness from
source or tests alone. A necessary visual/architecture deviation must be
approved and recorded in the applicable design/ADR before proceeding.

- [ ] **Step 3: Reconfirm independent final gates**

Fresh Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery
Management review the combined result and runtime evidence. Required findings
must be corrected and rechecked by independent roles. Optional or out-of-scope
ideas do not expand RR-R9.

- [ ] **Step 4: Activate RR-ROADMAP with one accepted live typed command**

Only after Step 3 GO and after the owner-facing Release Radar process is no
longer running, promote the already verified staged bundle without launching it,
verify the installed artifact, and then explicitly launch that exact bundle:

```bash
./script/build_and_run.sh --install-staged-release-no-launch
codesign --verify --deep --strict --verbose=2 /Applications/ReleaseRadar.app
/usr/bin/open -n /Applications/ReleaseRadar.app
```

Do not generate a request UUID yet. First prove both installed sides are ready:

1. Wait until the installed app's main dashboard is loaded and the Overview or
   Board exposes the **Active phase** selector with its current accessibility
   value. A launch spinner or window alone is insufficient.
2. Through the currently installed `release-radar` MCP connection, run only
   JSON-RPC `initialize` and `tools/list`; retain the results and require the
   server identity plus the exact `release_radar_set_active_phase` strict schema
   accepted in RR-R9A. This is a read-only readiness check and must use the
   installed tool, not a staged/test binary.

If either readiness check fails, stop before UUID generation and correct the
installation/startup issue under the existing acceptance gate. Do not inspect
the owner database and do not probe readiness with a mutation.

Only after both checks pass, use the installed MCP tool from the exact
authorized Release Radar repository root. Generate one fresh UUID at execution
time and record its concrete value. Invoke `release_radar_set_active_phase`
once with that recorded UUID and these exact fields:

```bash
/usr/bin/uuidgen
```

Use the command's exact stdout as `requestID`; do not regenerate it during this
acceptance attempt.

```json
{
  "version": 1,
  "requestID": "<the one recorded UUID from stdout>",
  "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
  "reason": "Activate RR-ROADMAP after RR-R9 acceptance",
  "phaseID": "RR-ROADMAP"
}
```

The execution-time UUID is deliberately generated once because pre-recording a
shared request identifier would violate the durable idempotency contract. If
the tool reports `outcomeUnknown`, do not generate another UUID; refresh
persisted state and replay only the complete original argument object,
including the recorded `requestID`, when result recovery is required. Do not
use SQLite or another tool.

- [ ] **Step 5: Verify live postconditions and relaunch persistence**

Require the running installed app, without navigation or manual refresh, to
show active phase `RR-ROADMAP` and its eleven roadmap tickets: Backlog 8,
In progress 0, Needs review 0, Blocked 3, Accepted 0. Verify dependency/detail
selection belongs to `RR-ROADMAP`, Activity visibly shows the exact reason, and
the recorded MCP response contains the returned audit ID associated with the
one recorded request ID supplied in the invocation. `AgentCommandResult` does
not echo request ID; do not expand that shared result contract for acceptance.
Relaunch the installed app and require the same phase, counts, detail/dependency
selection, and reason. Verify the formerly active
phase remains available as a selector option. Do not inspect the owner SQLite
database: actor/asserted-thread fields, exactly-one audit/receipt cardinality,
replay, and field-for-field historical preservation are accepted from the
isolated app-owned RR-R9A dispatcher tests and signed transport fixtures, not
from live Activity or a nonexistent receipt UI.

- [ ] **Step 6: Record RR-R9 completion and stop**

Delivery Management records the actual commands/results, RED/GREEN evidence,
runtime screenshots/accessibility observations, mockup comparison, signing,
relaunch, the recorded live request ID/returned audit ID and visible reason,
isolated test authority for actor/thread/audit/receipt cardinality, three direct
model-guard deltas, stale-generation success/failure interleavings,
cross-phase detail-reference preservation, independent decisions, residual
risks, and the newly active RR-ROADMAP gate in `docs/delivery/progress.md`.
State explicitly that no owner database was inspected. Commit only the accepted
ledger/evidence changes attributable to RR-R9C:

```bash
git add \
  docs/delivery/progress.md \
  docs/delivery/evidence/rr-r9-active-phase-overview.png \
  docs/delivery/evidence/rr-r9-active-phase-board-wide.png \
  docs/delivery/evidence/rr-r9-active-phase-board-compact.png \
  docs/delivery/evidence/rr-r9-active-phase-recovery.png
git commit -m "chore: accept active phase selection"
```

Do not stage unrelated evidence or working-tree changes. RR-R9 is complete at
this stop condition; further roadmap implementation requires its own released
task.
