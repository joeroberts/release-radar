# Release Radar By Rekon Labs MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a signed native macOS application that gives one owner an agent-driven, local-first view of delivery state for any folder-backed project.

**Architecture:** Release Radar is a standalone sandboxed SwiftUI application and the sole writer of its SQLite database. A narrowly typed local agent bridge may request transactional delivery updates, while a separately bounded read-only Codex observer supplies runtime context; neither receives database access or Pushover credentials. The latest approved five-lane mockup is authoritative for board presentation, and richer goal, evidence, dependency, and activity information lives in read-only detail surfaces.

**Tech Stack:** Swift 6, SwiftUI, macOS 14+, XCTest/XCUITest, system SQLite3, Security.framework/Keychain, ServiceManagement/XPC where required by sandbox boundaries, URLSession, and Codex app-server JSONL only after the live-state feasibility gate succeeds.

**Spec:** `docs/design/agent-driven-delivery-dashboard-design.md`

**Visual reference:** `docs/design/delivery-dashboard-seven-mockups.html`

## Global Constraints

- Product presentation is exactly **Release Radar By Rekon Labs**; application name is **Release Radar**.
- Repository: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`.
- All work is serialized on `codex/release-radar-mvp`; commit accepted slices directly to that branch; create no pull requests or agent-specific branches.
- Bundle identifier is `com.rekonlabs.ReleaseRadar`; minimum deployment target is macOS 14.0.
- App Sandbox and Hardened Runtime remain enabled; owner-facing builds use the configured signing identity.
- The application database is local Application Support state, never committed project state. There is no cloud backend.
- The app is the sole database writer. Agent tools never open SQLite and never receive Pushover credentials.
- Persisted lanes are Backlog, In progress, Needs review, Blocked, and Accepted. Dependency eligibility is derived information, not a sixth Ready lane and not an automatic transition.
- Agents may make any formal transition, including Accepted. The owner UI contains no manual delivery-transition controls.
- Observed Codex state never changes a formal delivery lane implicitly.
- Automated verification is limited to the direct acceptance scenarios named below. Do not add a bespoke harness, exhaustive parser matrix, load suite, mockup tests, or tests of framework internals.
- After two failed remediation attempts or ten active minutes on a non-product blocker, stop that workstream, record evidence, continue unrelated dependency-safe work, and escalate only if the goal cannot progress.
- Every task and gate updates `docs/delivery/progress.md` with status, classified findings, verification, commit SHA, decisions, risks, stop-rule events, and the next eligible task.

---

## File Structure

Create the standalone Xcode project and these responsibility boundaries:

- `ReleaseRadar.xcodeproj/` — app, helper/tool, unit-test, and UI-test targets.
- `ReleaseRadar/App/ReleaseRadarApp.swift` — WindowGroup, MenuBarExtra, and Settings scenes.
- `ReleaseRadar/App/AppModel.swift` — composition root and observable application state.
- `ReleaseRadar/Navigation/` — sidebar routes, collapsible rail, and responsive split view.
- `ReleaseRadar/Projects/` — project list, onboarding, overview, phase board, and ticket detail.
- `ReleaseRadar/Review/` — Needs Review inbox and resolution actions.
- `ReleaseRadar/Dependencies/` — graph layout and selected-ticket inspector.
- `ReleaseRadar/Activity/` — audit/runtime/notification activity projection.
- `ReleaseRadar/Notifications/` — menu alerts and Settings tabs.
- `ReleaseRadarCore/Models/` — stable domain identifiers and records.
- `ReleaseRadarCore/Store/` — SQLite connection, migrations, repositories, and sole-writer actor.
- `ReleaseRadarCore/AgentBridge/` — versioned commands, validation, and app-owned dispatcher.
- `ReleaseRadarCore/Onboarding/` — bookmarks, Git/worktree discovery, and import preview.
- `ReleaseRadarCore/Codex/` — read-only normalized observer protocol and feasibility adapter.
- `ReleaseRadarCore/Import/` — one-time Rekon artifact importer.
- `ReleaseRadarCore/Notifications/` — event fingerprints, outbox, Keychain, and Pushover transport.
- `ReleaseRadarIntegration/` — any signed non-root helper proven necessary by RR-05.
- `ReleaseRadarAgentTools/` — MCP stdio executable exposing only approved delivery commands.
- `ReleaseRadarTests/Fixtures/` — the five acceptance fixtures shared by focused tests.
- `ReleaseRadarUITests/` — one seeded navigation/responsiveness acceptance flow.
- `docs/architecture/ADR-001-release-radar-boundaries.md` — product, data, observer, bridge, sandbox, and signing boundaries.
- `docs/delivery/progress.md` — durable task, gate, commit, verification, decision, and risk ledger.

---

### RR-01: Scaffold the signed standalone application

**Dependencies:** none.

**Files:**

- Create: `ReleaseRadar.xcodeproj/project.pbxproj`
- Create: `ReleaseRadar/App/ReleaseRadarApp.swift`
- Create: `ReleaseRadar/App/AppModel.swift`
- Create: `ReleaseRadar/Navigation/AppRoute.swift`
- Create: `ReleaseRadar/Navigation/SidebarView.swift`
- Create: `ReleaseRadar/ReleaseRadar.entitlements`
- Create: `ReleaseRadar/Info.plist`
- Create: `docs/architecture/ADR-001-release-radar-boundaries.md`
- Create: `docs/delivery/progress.md`

**Interfaces produced:**

```swift
enum AppRoute: Hashable, Sendable {
    case projects, needsReview, notifications, settings
    case projectOverview(ProjectID), phaseBoard(ProjectID)
    case dependencies(ProjectID), activity(ProjectID)
}
```

- [ ] Record ADR-001 with the standalone bundle/data namespace, app-only database authority, separate read-only observer and typed mutation bridge, sandbox/signing boundary, five-lane supersession, and prohibited alternatives. Backfill the Planning, Architect, TPM, QA, Delivery Manager, and security preimplementation gates in the ledger.
- [ ] Create the Xcode targets `ReleaseRadar`, `ReleaseRadarCore`, `ReleaseRadarAgentTools`, `ReleaseRadarTests`, and `ReleaseRadarUITests` without third-party dependencies.
- [ ] Implement `ReleaseRadarApp` with `WindowGroup`, `MenuBarExtra`, and `Settings`, plus a `NavigationSplitView` shell whose sidebar is 220 points expanded and 96 points collapsed.
- [ ] Add the primary and per-project routes with consistent thin SF Symbol icons and accessible labels. Use `Release Radar` in app chrome and `Release Radar By Rekon Labs` in About/onboarding presentation.
- [ ] Run `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` and record the resolved signing identity in `docs/delivery/progress.md`.
- [ ] Commit the accepted foundation: `git commit -am "feat: scaffold Release Radar macOS app"` after staging the new files.

### RR-02: Add the transactional local delivery store

**Dependencies:** RR-01.

**Files:**

- Create: `ReleaseRadarCore/Models/DeliveryModels.swift`
- Create: `ReleaseRadarCore/Store/SQLiteConnection.swift`
- Create: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Create: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Create: `ReleaseRadarTests/StoreAcceptanceTests.swift`

**Interfaces produced:**

```swift
actor DeliveryStore {
    func transact<T>(
        actor: DeliveryActor,
        reason: String,
        _ body: (SQLiteConnection) throws -> T
    ) throws -> T
}

enum TicketLane: String, Codable, CaseIterable, Sendable {
    case backlog, inProgress, needsReview, blocked, accepted
}
```

- [ ] Define projects/roots, phases, tickets, phase/ticket dependencies, blockers, evidence, thread links/exclusions, observed threads/goals, review items, audit events, and notification events as distinct records with stable typed IDs.
- [ ] Write `StoreAcceptanceTests` first for one valid ticket transition that commits its attributed audit event, plus invalid reference, cross-project link, and dependency-cycle cases that leave both delivery and audit tables unchanged.
- [ ] Implement versioned migrations and the `DeliveryStore` actor using SQLite transactions, foreign keys, uniqueness constraints, and an application-support database URL. Before migration, preserve an atomic pre-migration snapshot. Corruption or migration failure keeps the original database intact and opens an explicit unavailable/recovery state; never silently delete or recreate authoritative state.
- [ ] Relaunch the store in the test and prove the valid record/audit survives while rejected writes do not appear.
- [ ] Run `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests`.
- [ ] Obtain independent code, QA, architecture, and security review; update the ledger and commit as `feat: add transactional delivery store`.

### RR-03: Expose one narrow agent action bridge

**Dependencies:** RR-02.

**Files:**

- Create: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Create: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Create: `ReleaseRadarIntegration/AgentBridgeService.swift`
- Create: `ReleaseRadarAgentTools/main.swift`
- Create: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`

**Interfaces produced:**

```swift
struct AgentCommandEnvelope: Codable, Sendable {
    let version: Int
    let requestID: UUID
    let projectRoot: String
    let assertedThreadID: String?
    let reason: String
    let command: AgentCommand
}

struct AgentCommandResult: Codable, Sendable {
    let entityIDs: [String]
    let auditEventID: AuditEventID?
    let error: AgentCommandError?
}
```

- [ ] Implement the approved commands only: phase/ticket upsert, ticket transition, dependency set, blocker record/resolve, evidence add, thread link, review request, completion record, and import-review resolve/dismiss.
- [ ] First prove the one concrete transport works from the sandboxed signed configuration: MCP JSON-RPC over stdio in `ReleaseRadarAgentTools`, forwarded through one bounded same-user local bridge to the running app. Authenticate the packaged signed peer by audit token/designated requirement or equivalent and fail closed on identity or protocol-version mismatch. The bridge never opens SQLite and has no generic shell, filesystem, URL, or arbitrary JSON-RPC method.
- [ ] Require version, bounded payload, reason, and a durably idempotent request ID. Resolve `projectRoot` to an onboarded canonical bookmark-backed project rather than trusting the supplied string. Evidence URLs must resolve within an authorized project/worktree root. Treat agent thread attribution as asserted unless the read-only observer verifies the thread belongs to that project.
- [ ] Write one integration scenario proving a valid command commits delivery state and audit ID, while invalid reference/cross-project/cycle commands return structured errors with full rollback; app unavailable returns `appUnavailable` and never writes elsewhere.
- [ ] Run the focused bridge test target, perform independent review, update the ledger, and commit as `feat: add typed agent delivery actions`.

### RR-04: Onboard folder-backed projects and require phase one

**Dependencies:** RR-02, RR-03.

**Files:**

- Create: `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- Create: `ReleaseRadarCore/Onboarding/ProjectBookmarkStore.swift`
- Create: `ReleaseRadarCore/Onboarding/GitWorktreeDiscovery.swift`
- Create: `ReleaseRadar/Projects/OnboardingView.swift`
- Create: `ReleaseRadarTests/Fixtures/FolderDiscovery/`
- Create: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`

**Interfaces produced:**

```swift
protocol ProjectOnboarding: Sendable {
    func inspect(folder: URL) async throws -> OnboardingPreview
    func finish(_ decision: OnboardingDecision) async throws -> ProjectID
}
```

- [ ] Build the single folder fixture with root, descendant, matching worktree, sibling/outside, and explicitly excluded Codex task descriptors plus no delivery structure.
- [ ] Implement `NSOpenPanel`, canonical path-component containment, read-only security-scoped bookmark persistence, stale-bookmark/symlink resolution, balanced security-scope access, Git-root discovery, and `git worktree list --porcelain` parsing. Worktrees outside the selected bookmark scope require a separate owner-selected authorization.
- [ ] Include matching root/descendant/worktree tasks automatically, reject sibling-prefix/outside tasks, and persist exclusions across rescan and relaunch.
- [ ] Refuse onboarding completion when no phase exists. Wire “Ask agent to define first phase” to the typed bridge, and allow completion with uncertain items held in Needs Review after phase one exists.
- [ ] Persist that the first dashboard has not yet been opened so onboarding creates no notification eligibility.
- [ ] Run `OnboardingAcceptanceTests`, review, update the ledger, and commit as `feat: onboard folder-backed projects`.

### RR-06: Deliver the recognizable local-first board

**Dependencies:** RR-02, RR-04. This task intentionally precedes live Codex work.

**Files:**

- Create: `ReleaseRadar/Projects/ProjectsView.swift`
- Create: `ReleaseRadar/Projects/ProjectOverviewView.swift`
- Create: `ReleaseRadar/Projects/PhaseBoardView.swift`
- Create: `ReleaseRadar/Projects/TicketCardView.swift`
- Create: `ReleaseRadar/Projects/TicketDetailView.swift`
- Create: `ReleaseRadarCore/Models/DashboardProjection.swift`
- Create: `ReleaseRadarTests/DashboardProjectionTests.swift`

**Interfaces produced:**

```swift
struct PhaseBoardProjection: Equatable, Sendable {
    let project: ProjectSummary
    let phase: PhaseSummary
    let lanes: [TicketLane: [TicketCardProjection]]
}
```

- [ ] Seed persisted project, phase, ticket, dependency, blocker, evidence, and audit data matching the approved board examples.
- [ ] Implement Projects and Overview plus exactly five lanes: Backlog, In progress, Needs review, Blocked, Accepted. Lane position is the state; never repeat state text on cards.
- [ ] At full width show ticket ID and concise outcome title; at compact lane widths show ticket ID only. Show dependency and blocker icons with counts, and keep lane counts readable without crowding titles.
- [ ] Put full outcome, verified/last-known goal context, dependency direction, owner attention, evidence, audit, and notification history in the selected read-only inspector. Add no manual transition controls.
- [ ] Verify projection membership/counts and one seeded wide/narrow UI flow covering 220-to-96 sidebar collapse, unclipped badges/highlight, visible full-width titles, and narrow ID-only cards.
- [ ] Build and launch the signed app, capture wide/narrow owner comparison screenshots without a pixel-diff gate, review, update the ledger, and commit as `feat: deliver local phase board`.

### RR-05: Prove and add read-only live Codex observation

**Dependencies:** RR-04, RR-06.

**Files:**

- Create: `ReleaseRadarCore/Codex/CodexObserver.swift`
- Create: `ReleaseRadarCore/Codex/CodexRuntimeModels.swift`
- Create: `ReleaseRadarCore/Codex/CodexJSONLClient.swift` only if feasibility succeeds.
- Create: `ReleaseRadarIntegration/CodexObserverService.swift` only if a helper is required and proven.
- Create: `ReleaseRadarTests/Fixtures/CodexRuntime/`
- Create: `ReleaseRadarTests/CodexObserverAcceptanceTests.swift`
- Modify: `docs/architecture/ADR-001-release-radar-boundaries.md` only with proven integration facts.

**Interfaces produced:**

```swift
protocol CodexObserver: Sendable {
    func snapshot() async throws -> CodexSnapshot
    func events() -> AsyncThrowingStream<CodexRuntimeEvent, Error>
}
```

- [ ] Feasibility gate: from a configured signed build, prove Release Radar can observe an actually running Codex desktop task’s cwd, thread state, goal state, waiting flags, and completion event through a sandbox/signing-compatible supported connection. A separately launched app-server is not assumed to share desktop live state.
- [ ] Timebox this proof to the repository stop rule. If attachment is unavailable, retain cached state as stale, record the blocked live-state gate, and continue dependency-safe work in explicit stale/unavailable mode. Ask the owner only when no safe work remains or a real decision is required. Do not request Full Disk Access or Accessibility; do not scrape Codex databases, rollout files, terminals, or UI; and never label fixture/cache data live.
- [ ] If proven, implement a read-only normalized adapter for paginated thread listing/reading, goal retrieval, status/goal/completion notifications, reconnect reconciliation, bounded JSONL, and explicit freshness.
- [ ] Use the folder fixture to prove root/subfolder/worktree discovery and exclusions; use the runtime fixture to prove Active, Paused, Blocked, Awaiting input, Completed/Ready for review, goal clearing, malformed input, disconnect, and last-seen stale state.
- [ ] Assert that every observed transition updates runtime state/timestamp and never changes the linked ticket’s formal lane.
- [ ] Reject malformed, oversized, or version-mismatched events; retain last-known state as stale; perform architecture, security, code, and QA review; update the ledger; commit the proven implementation as `feat: observe Codex delivery state` or record a blocked gate without speculative fallback.

### RR-07: Add Needs Review, dependencies, activity, and settings navigation

**Dependencies:** RR-05 when live observation succeeds; otherwise RR-06 with explicit stale/unavailable presentation.

**Files:**

- Create: `ReleaseRadar/Review/NeedsReviewView.swift`
- Create: `ReleaseRadar/Dependencies/DependencyGraphView.swift`
- Create: `ReleaseRadar/Dependencies/DependencyGraphLayout.swift`
- Create: `ReleaseRadar/Activity/ActivityView.swift`
- Create: `ReleaseRadar/Notifications/SettingsView.swift`
- Create: `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`

- [ ] Implement the master-detail Needs Review inbox for uncertain imports, duplicates, unresolved dependencies, unmatched/excluded tasks, and agent review requests; resolution/dismissal uses the typed bridge and persists.
- [ ] Implement the dependency graph with ticket-ID-only nodes, semantic state color, numeric blocker bubble, multiple precise edge-to-card connectors, direct/indirect requirements, unlocks, and selected-ticket inspector.
- [ ] Implement Activity from audit, runtime, review/completion, and notification records. Implement tab-style Settings navigation: General, Connections, Notifications, Projects.
- [ ] Extend the one seeded UI flow across all seven approved surfaces and assert key accessible content, multi-dependency endpoints, tab navigation, and absence of duplicate bell/count UI.
- [ ] Run the focused review/graph and seeded UI acceptance tests, review, update the ledger, and commit as `feat: add review dependency and activity views`.

### RR-08: Import Rekon delivery artifacts once

**Dependencies:** RR-04, RR-07.

**Files:**

- Create: `ReleaseRadarCore/Import/DeliveryArtifactImporter.swift`
- Create: `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Create: `ReleaseRadarTests/Fixtures/RekonImport/`
- Create: `ReleaseRadarTests/RekonImportAcceptanceTests.swift`

**Interfaces produced:**

```swift
protocol DeliveryArtifactImporter: Sendable {
    func canImport(_ folder: URL) -> Bool
    func preview(_ folder: URL) throws -> ImportPreview
    func apply(_ preview: ImportPreview, to project: ProjectID) async throws
}
```

- [ ] Create the minimal fixture with one confident phase/ticket/dependency/evidence mapping and ambiguous duplicate, unmatched reference, and missing-outcome records.
- [ ] Parse the stable delivery JSON contract and recognize roadmap/task-brief/handoff/ledger paths only as one-time evidence sources; do not infer canonical state from arbitrary Markdown.
- [ ] Import confident local records transactionally, route uncertainty to Needs Review, make re-import idempotent, and leave every source file byte-for-byte unchanged.
- [ ] Prove relaunch persistence and mark moved/removed evidence unavailable without deleting imported state.
- [ ] Run the focused importer scenario, review, update the ledger, and commit as `feat: import Rekon delivery records`.

### RR-09: Add app-owned Pushover and notification history

**Dependencies:** RR-02, RR-03, the recorded RR-05 live-or-degraded semantics, and RR-07.

**Files:**

- Create: `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`
- Create: `ReleaseRadarCore/Notifications/NotificationDispatcher.swift`
- Create: `ReleaseRadarCore/Notifications/PushoverClient.swift`
- Create: `ReleaseRadarCore/Notifications/PushoverKeychainStore.swift`
- Create: `ReleaseRadar/Notifications/NotificationsView.swift`
- Create: `ReleaseRadarTests/NotificationAcceptanceTests.swift`

**Interfaces produced:**

```swift
protocol NotificationDispatcher: Sendable {
    func enqueue(_ event: MeaningfulDeliveryEvent) async
}
```

- [ ] Commit the meaningful transition, audit entry, and durable occurrence fingerprint/outbox record in the same app-owned transaction for Blocked entry, agent completion/review, and Needs Review entry. Durably mark `attemptStarted` before network send; a crash-ambiguous attempt becomes visible `unknown` and is not retried automatically.
- [ ] Store both Pushover credentials only as non-synchronizing, device-only Keychain items accessible to the app. Use the fixed HTTPS Pushover endpoint, minimal app-derived notification text without raw goals/reasons/evidence/paths, and persist only sanitized status/receipt data—not request or response bodies.
- [ ] Use fake transport to prove one attempt per fingerprint across replay/relaunch, a new event after resolve/re-enter, paused suppression, pre-first-dashboard-open onboarding silence, and visible non-blocking send failure.
- [ ] Implement the full-width Notifications screen and menu-bar alert surface without duplicate bells/counts; complete Connections and Notifications settings states.
- [ ] Perform security, architecture, code, and QA review; update the ledger and commit as `feat: add durable Pushover alerts`.

### RR-10: Integrate failure states and deliver the signed MVP

**Dependencies:** RR-06, RR-07, RR-08, RR-09 and the recorded RR-05 gate result.

**Files:**

- Create: `ReleaseRadar/Shared/FailureStateView.swift`
- Create: `ReleaseRadarTests/EndToEndAcceptanceTests.swift`
- Modify: `ReleaseRadarUITests/ReleaseRadarUITests.swift`
- Modify: `docs/delivery/progress.md`

- [ ] Integrate explicit states already produced by each slice: no structure, Codex unavailable/last seen, moved or inaccessible folder, unavailable evidence, import Needs Review, Pushover failure, and typed agent validation failure.
- [ ] Rerun the five focused service scenarios after app/store relaunch: store/action atomicity, folder/runtime discovery, Rekon import, notification deduplication, and degraded dependencies.
- [ ] Run the single seeded wide/narrow UI flow through Projects, Overview/Board/detail, Needs Review, Dependencies, Activity/goal states, Notifications, failure/onboarding states, and tab-style Settings.
- [ ] Build with the configured Debug signing identity, launch the signed `.app`, and record bundle identity, signing identity, screenshots, commands, results, unresolved risks, and RR-05 live-state truth in the durable ledger.
- [ ] Obtain independent milestone architecture, security, QA, TPM, and Delivery Manager gates. Required findings only block delivery; optional suggestions remain outside this goal.
- [ ] Commit final accepted evidence as `chore: complete Release Radar MVP acceptance`. Do not create a pull request.

## Dependency Order

```text
RR-01 → RR-02 → RR-03 → RR-04 → RR-06 → RR-05 → RR-07 → RR-08 → RR-09 → RR-10
```

The Delivery Manager releases one task at a time. Each task uses a fresh Implementer, then a separate Code Reviewer and QA verifier; the Architect checks architectural effects, and the Security/privacy verifier independently gates RR-02, RR-05, and RR-09. All write work is serialized on `codex/release-radar-mvp`.
