# Release Radar Active Phase Selection Design

- Status: Approved outcome; implementation pending independent release
- Date: 2026-08-29
- Delivery ID: RR-R9

## Purpose

Release Radar already persists one explicit active phase per project and renders
only that phase on Project Overview, Phase Board, and the project-scoped
dependency projection. It does not yet let the owner or an authorized agent
change that selection. The result is a truthful but incomplete dashboard:
`RR-ROADMAP` and its tickets exist in the authoritative store and Activity, but
the accepted Post-MVP phase remains the visible board.

RR-R9 completes active-phase selection as one product capability. The owner can
select a project's active phase from both Project Overview and Phase Board, and
authorized agents receive one typed audited MCP command for the same operation.
Both entry points use the existing `AgentCommandDispatcher`, app-owned
transaction, project authorization, audit, and projection-refresh boundaries.
Changing the active phase changes only the project's active-phase pointer. It
does not delete, rename, reorder, or rewrite phases, tickets, lanes,
dependencies, evidence, reviews, blockers, completions, notifications, or
history.

The complete outcome is delivered through three bounded checkpoints:

- **RR-R9A — active-phase authority:** store, `AgentCommand`, dispatcher,
  signed transport, MCP schema, persistence, idempotency, validation, and audit.
- **RR-R9B — owner experience:** one shared selector on Overview and Board,
  owner authorization, refresh, selection reconciliation, accessibility, and
  recovery states.
- **RR-R9C — acceptance and activation:** integrated independent review,
  running-app visual/responsive/accessibility proof, relaunch proof, and one
  accepted typed command that activates `RR-ROADMAP`.

These checkpoints constrain execution and review risk; none narrows the feature
or makes an incomplete checkpoint a finished RR-R9 delivery.

## Controlling references

- `docs/delivery/progress.md`, especially **Current gate**, **Release Radar
  roadmap synchronization — 2026-08-29**, and the planning reconciliation
- `docs/design/agent-driven-delivery-dashboard-design.md`, especially
  **Dashboard model → Project overview**, **Dashboard model → Phase board**,
  **Failure behavior**, and acceptance criteria 3, 5, and 7
- `docs/design/mockups/phase_board.png`
- `docs/architecture/ADR-001-release-radar-boundaries.md`, especially the
  app-only SQLite authority, explicit active-phase data, typed mutation bridge,
  five-lane board, and prohibited alternatives
- `docs/architecture/ADR-003-active-phase-selection.md`, the accepted owner
  exception, current-request publication ordering, model guard, and
  cross-phase dependency-reference contract
- `docs/superpowers/plans/2026-08-23-release-radar-mvp.md`, especially RR-02,
  RR-03, RR-06, and RR-10 boundaries

If a source or index conflicts with current application source, tests, signed
package behavior, or this approved RR-R9 outcome, the implementation must stop
for architecture or product reconciliation rather than silently invent a new
contract.

## Existing state and decision

Schema version 5 introduced `project_active_phases`:

```sql
CREATE TABLE project_active_phases (
    project_id TEXT PRIMARY KEY NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    phase_id TEXT NOT NULL,
    FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
);
```

That table already enforces exactly zero or one selected phase per project and
same-project phase identity. `DashboardProjection.load(from:)` joins the row,
loads tickets only for the selected phase, and truthfully produces no board
when a multi-phase project has no explicit selection. This design uses that
existing table as the sole active-phase authority. RR-R9 requires no schema
migration and no new persistence table.

The approved command is additive to the existing durable envelope:

```swift
public enum AgentCommand: Codable, Equatable, Sendable {
    // Existing cases remain unchanged.
    case setActivePhase(phaseID: String)
}
```

The corresponding MCP tool is exactly
`release_radar_set_active_phase`. Its command-specific input is the required
non-empty string `phaseID`; the existing required envelope fields remain
`version`, `requestID`, `projectRoot`, and `reason`, with optional
`assertedThreadID`. The command envelope version remains `1`, the bridge wire
version remains `2`, and all current size, deadline, peer-signing, and strict
JSON contracts remain unchanged.

The dispatcher resolves `projectRoot` through the existing
`AuthorizedProjectRegistry`, validates `phaseID` as a bounded command
identifier that is non-whitespace and at most 256 UTF-8 bytes, and calls the
existing same-project entity validator for `phases`. An unknown phase returns
`invalidReference`; a phase owned by another project returns
`crossProjectReference`; an unauthorized root returns
`unauthorizedProjectRoot`. Every rejection occurs before active-phase, request,
or audit persistence.

The accepted mutation is one statement inside the existing app-owned audited
transaction:

```sql
INSERT INTO project_active_phases (project_id, phase_id)
VALUES (?, ?)
ON CONFLICT(project_id) DO UPDATE SET phase_id = excluded.phase_id;
```

The result contains the selected phase ID in `entityIDs` and the transaction's
audit event ID. Audit scope is the resolved project, entity type `phase`, and
the selected phase ID. External calls retain actor `release-radar-agent` and
asserted-thread semantics; owner UI calls use `origin: .ownerApp`, which records
actor `release-radar-owner`. The envelope's non-empty bounded `reason` is the
human-readable audit reason.

Selecting the already-active phase through a valid fresh agent request is a
successful idempotent state assignment and is still audited as an explicit
agent intent. The owner UI does not offer the already-active option as a new
action. Exact replay of the same request body and `requestID` returns the
original result without a second mutation or audit. Reuse of the request ID for
a different body remains rejected.

## Data flow

### Authorized agent

```text
MCP release_radar_set_active_phase
  → strict typed JSON arguments
  → AgentCommandEnvelope(version 1, requestID, root, reason, command)
  → signed AgentTools / broker / app callback boundary
  → AuthorizedProjectRegistry exact-root resolution
  → AgentCommandDispatcher validation and app-owned transaction
  → project_active_phases + agent_command_requests + audit_events commit
  → original AgentCommandResult reply
  → after-reply dashboard refresh before outbound notification draining
  → active phase, board lanes/counts/details, dependencies, and activity reload
```

The app callback replies with the committed result before nonessential
post-reply work. `AppNotificationCoordinator` owns one coalesced
`pendingSuccessfulCommandRefresh` Boolean and a single-drain guard. A
successful after-reply callback sets the pending bit. If the optional dashboard
handler has not registered, the coordinator retains the bit and returns
without beginning notification draining. `setDashboardRefreshHandler` stores
the handler and flushes a pending batch: exactly one read-only dashboard
refresh begins before `dispatchPending()`. With a handler already registered,
the same refresh-before-notification order applies normally. Successful
callbacks that arrive while a refresh is suspended coalesce behind the drain;
the drain services the pending bit before notifications. It never redispatches
an `AgentCommand`.

The handler enters the same AppModel generation-owned projection reload as all
other full loads, so an overlap with initial load, owner selection, or recovery
cannot publish a stale snapshot. A refresh failure does not convert a
successful commit into a failed mutation and does not cause an automatic
command retry. Failed command results set no pending refresh and preserve
existing notification behavior.

### Owner UI

```text
Shared ActivePhaseSelector on Overview or Phase Board
  → AppModel.setActivePhase(projectID:phaseID:)
  → existing security-scoped bookmark resolution for that project
  → exact AuthorizedProject scoped for the duration of the call
  → AgentCommandDispatcher with a fresh UUID and owner-app origin
  → same validated app-owned transaction as the MCP command
  → full project projection reload
  → active board, lane counts/cards/detail, dependency graph, activity,
    and selected-ticket reconciliation update in one visible refresh
```

The owner reason is deterministic and meaningful:
`"Owner selected active phase \(phaseID.rawValue)"`. The selector surface does
not change the reason or authority; Overview and Board are two presentations
of the same operation.

## Projection and selection contract

`DashboardProjection` gains the project's complete persisted phase list for
selection even when that project currently has no active-phase row. The narrow
phase type is:

```swift
struct ProjectPhaseProjection: Equatable, Sendable, Identifiable {
    let id: PhaseID
    let name: String
}
```

`ProjectDashboardProjection` gains `activePhaseID: PhaseID?` and
`phases: [ProjectPhaseProjection]` in deterministic
`name COLLATE NOCASE, id` order. Phase IDs are the explicit tie-break when two
names compare equal under SQLite `NOCASE`; insertion order is never observable.
`PhaseBoardProjection.phaseID` remains non-optional because a board exists only
for an active phase. Board card membership, dependency-graph node membership,
and the keys of `details` remain limited to tickets in that active phase.
`TicketDetailProjection` for an active ticket retains its accepted semantics:
its `requires` and `unlocks` may truthfully include valid same-project tickets
from another phase. Such references do not become board cards or dependency-
graph nodes, and changing the pointer does not delete, filter, or rewrite the
underlying dependency rows.

This project-level placement preserves the truthful existing case where a
multi-phase project has no explicit pointer. Overview and the Phase Board route
render the shared selector from the project projection with accessibility value
**No active phase**; choosing any listed phase creates the pointer and the full
board on reload. The owner is therefore not trapped behind the current
`Tracking state required` fallback. A project with zero phases retains that
fallback because RR-R9 does not create phases.

Every current-generation successful publication reconciles `selectedTicketID`
against the newly loaded active board. Preserve the current selection when
that ticket exists in the new phase; otherwise select the lexically first
ticket ID in the new phase. If the phase has no tickets, no card or detail is
visibly selected, the existing `Select a ticket` empty detail is shown, and the
stale dependency graph is cleared. The dependency graph is rebuilt from the
same new `phaseID` and reconciled selection. This rule applies equally after
owner and agent commands and prevents detail from silently referring to a
historical phase.

The reload swaps the coherent projection only after the complete dashboard,
workspace projections, dependency graph, activity, and visible selection
required for the visible project have loaded. The UI must not combine the new
phase label with stale old-phase counts or dependencies.

Every full projection reload uses one AppModel-owned monotonically increasing
`projectionReloadGeneration`. On the main actor, the reload increments the
generation and captures that value before its first suspension. It prepares
all values locally. Immediately before publishing either success or failure,
it compares the captured generation with the current generation. A mismatch
returns a non-error `superseded` outcome. That reload and its caller then
return without any observable write: no dashboard, workspace dictionary,
dependency graph, Activity, visible ticket selection, dashboard error,
`.idle`, `.savedNeedsReload`, or other phase-selection status reconciliation.
Thus, once reload B begins, older reload A can never overwrite B, even if A
finishes last.

Only the matching current generation owns success, failure, and active-phase
status reconciliation. It performs that work in one main-actor publication or
failure-publication boundary with no suspension. A successful publication
atomically installs the prepared coherent projection, clears the applicable
dashboard load error, and examines each pending `.saving(target)` or
`.savedNeedsReload(target, _)` status. It clears a pending status to `.idle`
only when the prepared project projection contains
`activePhaseID == target`; a target mismatch leaves that status unchanged. A
current-generation owner post-commit load failure establishes or preserves
`.savedNeedsReload(target, name)` and its read-only recovery. Other current-
generation failures publish their existing scoped error presentation without
reconciling an unrelated phase-selection status. Initial dashboard load,
onboarding/folder reload, owner selection, agent post-reply refresh, and both
read-only recovery actions all enter this same generation-owned full-reload
path; callers use its result only for control flow and never repair observable
state after a `superseded` result.

## Owner experience

### Shared selector

Create one reusable `ActivePhaseSelector` and use it on both Project Overview
and Phase Board. The control is a labelled native macOS menu-style `Picker`
with the label **Active phase**. Options show the phase name and expose the
stable phase ID in accessibility help or value when the name alone is
ambiguous. The selected option is the persisted `project.activePhaseID`, or no
selection when the pointer is absent, never an uncommitted local guess.

On Project Overview, place the selector in the existing active-phase delivery
section near **Open phase board**, without replacing the summary cards or
guidance card. On Phase Board, place it in the board header beside **Card
density**. The product remains phase-scoped and the project sidebar/routes do
not change.

The selector follows the established dark graphite/navy native-panel language
from `phase_board.png`: native typography, subtle borders, cyan selection,
restrained status color, and existing spacing. It does not introduce a modal
wizard, floating palette, second toolbar, all-phase board, or manual ticket
editing.

### Responsive behavior

At the accepted wide reference size, project and phase remain the leading
header context and **Active phase** plus **Card density** remain aligned as
compact trailing controls. At narrow widths, the controls wrap or stack above
the five-lane recovery workspace without clipping, shrinking their accessible
labels away, or covering selected-ticket detail. Existing horizontal lane
recovery and vertical board/detail recovery remain intact.

The required runtime sizes are the accepted wide comparison near
`1586 × 992` and the app minimum `760 × 520`. A width-forced Compact density
presentation remains independent from phase selection.

### Owner-approved RR-R9C visual-evidence deviation — 2026-08-29

The owner accepts the current canonical wide `1411 × 768` and compact
`768 × 777` captures, together with independent QA's direct accessibility
observation at a `760 × 552` outer window (`760 × 520` content plus the
32-point title bar), as sufficient RR-R9C responsive evidence. The Computer
Use viewport prevented a `1586 × 992` raster capture. This changes only the
acceptance-evidence threshold: the wide right-side inspector, compact stacked
inspector, all five lanes, and horizontal and vertical recovery behaviors
remain required and were observed. A future exact-size raster capture is
optional and does not block RR-R9C acceptance.

## Interaction and accessibility states

The shared selector has one observable per-project state; navigating between
Overview and Board preserves that state because `AppModel`, not the view, owns
it.

Before creating a UUID or resolving authorization,
`AppModel.setActivePhase(projectID:phaseID:)` checks the last coherent project
projection and per-project selection status. It returns without side effects
when the requested ID is already active, the project is `.saving`, or the
project is `.savedNeedsReload`. These are model-boundary guards; view
disablement is only presentation. The request-ID generator is invoked only
after all three guards pass. A mutation failure may be retried explicitly;
saved-but-not-refreshed state must be recovered by reading, not by mutation.

### Ready

- Label: **Active phase**.
- Accessibility identifier: `active-phase-selector-overview` or
  `active-phase-selector-board` for the two placements.
- Accessibility value includes the selected phase name and ID.
- Native keyboard interaction supports focus traversal, menu opening, option
  navigation, selection, and Escape without a pointing device.
- Choosing a different phase starts exactly one owner command.
- Choosing the already-active phase through a direct model call creates no
  UUID, request receipt, mutation, or audit. A fresh agent request may still
  audit the same assignment as explicit agent intent.

### Busy

- The selector is disabled immediately after one choice until the mutation and
  refresh resolve.
- A visible `ProgressView` and accessibility value **Saving active phase**
  communicate progress; repeated Return, Space, or clicks cannot dispatch
  another request.
- Navigation may continue, and the same shared state appears on either surface.
- A direct model call while `.saving` creates no additional UUID, request, or
  audit; the AppModel guard remains authoritative if a view is stale.

### No alternative phase

- When the project's sole persisted phase is already active, the control
  remains visible so the active-phase authority is understandable, but it is
  disabled. A sole phase with no active pointer remains selectable.
- Help text is exactly **No other phases are available for this project.**
- No request ID, mutation, or audit is created.

### Mutation rejected or unavailable

- Typed validation, authorization, unavailable-store, or internal failures use
  an inline `FailureStateView` with a stable phase-selection accessibility ID.
- A rejected mutation keeps the old active phase, board, selection, and all
  history. The selector becomes available again only when another safe choice
  exists.
- Missing, stale, denied, or mismatched bookmark authorization offers the
  existing owner-mediated **Locate / Reauthorize…** folder picker. Recovery
  only restores the same canonical project root. It never selects a phase or
  retries the rejected command automatically. The owner explicitly selects the
  desired phase again after authorization succeeds.
- `appUnavailable` and store-unavailable states direct the owner to reload or
  reopen Release Radar; they never imply a committed mutation.

### Saved, refresh needed

- A successful command result is definitive even if the following projection
  load fails.
- Show **Active phase saved; refresh needed** and state which phase was saved.
  Keep the last coherent board visibly marked as not refreshed; do not label
  its counts, dependencies, or selection as current for the saved phase.
- Offer only **Reload dashboard**. That action reads persisted state and does
  not dispatch `setActivePhase` again.
- Any direct selection call while `.savedNeedsReload` creates no UUID, request,
  or audit, even when it names a different phase.
- Clear the recovery state only after the refreshed projection contains the
  committed phase. A reload that fails preserves the same recovery state and
  remains safe to repeat.

### Agent outcome unknown

- The existing transport returns `outcomeUnknown` after authenticated handoff
  when it cannot prove whether the reply was delivered.
- Callers do not create a replacement request. They first refresh persisted
  state; when exact result recovery is required, they replay the complete
  original envelope with the same `requestID`.
- Durable replay returns the original audit/result without a duplicate active-
  phase write or audit. No timer, refresh, or UI recovery silently retries the
  mutation.

## Activity and audit evidence

Every accepted phase selection produces one `audit_events` row in the same
transaction as the active-phase pointer and durable command receipt. The event
records:

- actor `release-radar-owner` for the UI or `release-radar-agent` for MCP;
- asserted thread attribution only when the external envelope supplies it;
- the exact non-empty reason;
- resolved project ID;
- entity type `phase`;
- selected phase ID;
- generated audit event ID and timestamp.

Existing Activity projection exposes the reason, but it does not expose actor,
asserted-thread attribution, request receipt, or receipt cardinality. RR-R9
does not add those fields to Activity or add a receipt-inspection UI. Isolated
app-owned RR-R9A dispatcher tests and signed transport fixtures remain the
authority for actor, asserted-thread, audit cardinality, receipt cardinality,
and replay behavior. `AgentCommandResult` does not echo `requestID`, and RR-R9
does not broaden that shared result contract. The final live MCP result
supplies its returned audit ID, and the operator records the exact request ID
before invocation and pairs the two in evidence; the running app
proves the visible reason, selected phase, coherent projection, and relaunch
only. No new history table, notification event, Pushover event, or repository
document is created. Historical audits and every historical phase/ticket
record remain available.

## Security and privacy

- The app process remains the sole SQLite writer. AgentTools, the broker,
  lifecycle helper, observers, and project processes never open the store.
- MCP retains the existing signed same-user peer requirements, fixed local
  Mach services, bounded payload, strict JSON, envelope version, deadline, and
  `projectRoot` authorization.
- Owner UI uses the existing security-scoped bookmark path and keeps access
  balanced for the complete dispatcher call. Stored paths alone do not grant
  mutation authority.
- Phase IDs and names are local delivery metadata. The command sends no ticket
  content, evidence, repository file, credential, bookmark bytes, or network
  request.
- Same-project validation is performed in the app transaction, not trusted to
  UI option filtering or the MCP caller.
- Audit reason and asserted thread ID retain their current size limits and
  attribution truth. The UI does not claim an external thread is verified.
- No permission, signing, sandbox, Hardened Runtime, Keychain, app-group, or
  network entitlement changes are authorized.
- The targeted Debug runtime fixture is default-off, requires the existing
  capture/empty-store guards, operates only in a fresh alternate container,
  and inherits external-service suppression. It neither reads the owner
  container nor authorizes runtime inspection of any SQLite file.

Independent security/privacy review is required because RR-R9 mutates local
authoritative storage through both the bookmark-authorized owner path and the
signed agent bridge.

## Test strategy

Use the existing XCTest targets, temporary stores, dashboard fixtures, signed
package transport tests, and running-app inspection. Add no dependency,
snapshot framework, screenshot-diff gate, mock server, or custom validation
harness.

### RR-R9A focused tests

- Dispatcher success changes only `project_active_phases`, records exactly one
  phase-scoped audit and request receipt, returns the phase ID/audit ID, and
  survives a recreated store/dispatcher.
- Exact request replay returns the original result and produces no duplicate;
  changed-body request-ID reuse is rejected.
- A non-whitespace phase ID whose UTF-8 encoding is greater than 256 bytes
  returns `invalidEnvelope` and changes no active pointer, request receipt,
  audit, phase, ticket, or dependency history. Use
  `String(repeating: "é", count: 129)`, assert its byte count is `258`, and
  thereby prevent the test from accidentally measuring graphemes.
- A fresh request assigning the already-active phase succeeds as explicit
  agent intent, adds exactly one audit and one receipt without changing the
  pointer or history, and exact replay returns that result without another
  audit or receipt.
- Unknown and cross-project phase IDs return their existing typed errors and
  preserve active selection, all phases/tickets/dependencies, request count,
  and audit count.
- Owner origin records `release-radar-owner`; external origin records
  `release-radar-agent`, reason, and asserted attribution correctly.
- MCP `tools/list` exposes exactly one additional strict schema,
  `release_radar_set_active_phase`, with no additional properties.
- The packaged signed tool reaches the existing broker/app callback and commits
  the new command. Wrong peer, wrong wire/envelope version, unavailable app,
  pre-admission expiry, post-handoff uncertainty, and exact replay retain their
  current transport semantics.

### RR-R9B focused tests

- **RED:** add the direct-model and continuation-gated interleaving cases before
  product changes. They must fail because pre-UUID guards and current-generation
  publication are absent. Add the cross-phase dependency case as a passing
  baseline characterization, then retain it through GREEN.
- Projection loads every same-project phase as deterministic selector options
  while limiting cards, detail keys, and dependency-graph nodes to the active
  phase. An active ticket detail still exposes a valid same-project cross-phase
  `requires`/`unlocks` reference, and selection preserves its dependency row.
  At least two phase names compare equal under SQLite `NOCASE`; their expected
  order is asserted by phase ID after reverse-order insertion.
- A successful owner selection uses `origin: .ownerApp`, refreshes Overview,
  Board, lane counts, detail, dependency graph, activity, and valid ticket
  selection, and survives a store/AppModel recreation.
- A pre-registration successful-command fixture proves the coordinator retains
  one coalesced pending refresh, begins no notification draining while the
  handler is absent, and starts exactly one read-only dashboard refresh when
  the handler registers before draining notifications. A separate normal
  registered-handler case retains refresh-before-notification ordering. Both
  use deterministic gates, and overlapping reloads remain subject to AppModel
  current-generation publication.
- Direct AppModel tests inject a counting request-ID generator and prove the
  already-active, `.saving`, and `.savedNeedsReload` guards create no new UUID,
  request receipt, or audit. Single-phase UI state retains the exact help copy.
- Deterministically interleaved dashboard loaders hold older ordinary reload A,
  begin and publish newer reload B through the committed-agent handler, then
  release A. The final dashboard, workspace,
  error, and active-phase selection status remain exactly as B published; A's
  stale success or failure publishes nothing and performs no status
  reconciliation.
- Missing/stale/denied/mismatched authorization fails closed; reauthorization
  changes no phase and requires explicit reselection.
- Mutation failure preserves the last coherent projection. A committed write
  followed by loader failure produces **saved; refresh needed**, exactly one
  request/audit, no automatic retry, and a read-only reload recovery.
- Shared presentation semantics cover both stable accessibility identifiers,
  label/value/help strings, and compact/wide layout decision helpers.
- **GREEN:** the repository-native RR-R9B selection in the implementation plan
  passes with zero failures/skips, including both stale-completion orders, all
  three direct model guards, and unchanged cross-phase dependency rows.

### Debug-only RR-R9 runtime fixture and faults

Runtime acceptance uses the existing alternate-bundle capture pattern, not an
owner database or a new UI-test harness. Add one focused
`ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` file and the minimum
launch/configuration hooks in `ReleaseRadar/App/ReleaseRadarApp.swift` and
`ReleaseRadar/App/AppModel.swift`. The fixture is compiled only for Debug and
is default-off. It activates only when all of these are present:

```text
--rr10-capture
--rr10-empty-store
--rr9-active-phase-fixture=<scenario>
```

The recognized scenario values are `happy`, `busy`, `no-alternative`,
`mutation-failure`, `unavailable`, `authorization-failure`, `saved-refresh`,
`empty-phase`, `no-active-pointer`, and `cross-phase-detail`. Missing,
malformed, non-Debug, or partially supplied arguments return no RR-R9 fixture
or fault. Existing `--rr10-capture` suppression continues to prevent bridge,
Pushover configuration, notification dispatch, Keychain, and network activity.
Ordinary Debug and every Release launch remain byte-for-byte behaviorally
unchanged.

The fixture follows `DashboardSampleData.seedIfNeeded` and creates every
runtime-authorized bookmark through the production
`ProjectBookmarkStore.makeBookmark(for:)` security-scoped bookmark path. It
canonicalizes each disposable root before passing that exact URL to
`makeBookmark(for:)` and persists the same canonical path with the returned
bookmark data, preserving ADR-003 exact-root authorization. Through the app-
owned `DeliveryStore`, it seeds one idempotent, deterministic data set inside a
fresh alternate sandbox: an
authorized multi-phase project with normal, empty, and cross-phase-reference
states; a sole-active-phase project; a bookmark-authorized project with no
active pointer; and a project whose persisted root intentionally lacks a
bookmark for authorization recovery. Disposable fixture roots live beneath
the alternate app's Application Support directory, so the exact authorization
root is derived from and recorded with the alternate bundle identifier. The
acceptance operator never opens, queries, or mutates any SQLite database.
AppModel seeds this fixture before its first projection load; required
`--rr10-empty-store` keeps the ordinary dashboard sample seed absent.
The private `RouteBookmarkStore` remains only a deterministic
`AppRouteTests` fake; it is never used to seed the running fixture and is not
runtime acceptance authority.

The scenario chooses the initial route/project and, only where persisted data
cannot represent the UI condition, one narrowly scoped fault:

- `busy` gates the first owner action after `.saving(target)` and before
  dispatcher entry; process termination releases the capture without a write;
- `mutation-failure` and `unavailable` return the matching typed result through
  a Debug-only active-phase action fault, leaving the last coherent projection;
- `saved-refresh` lets the real command commit, fails exactly the first post-
  commit full reload, and lets the explicit read-only reload succeed;
- all other scenarios use only the seeded store and real selector/reload paths.

The fault selector is not a protocol, service, persistence format, command,
route, or general fault framework. Focused `AppRouteTests` prove the launch
matrix, exact scenario behavior, one-shot saved-refresh fault, no capture
activation in ordinary Debug/Release, and no outbound service use. Automated
model/dispatcher tests remain the authority for mutation and cardinality;
running capture proves the actual accessible presentation and recovery.

Build one fresh alternate Debug bundle identifier and launch each scenario
with `/usr/bin/open -n` against the recorded alternate app path, followed by
`--args` and the three arguments above.
For each launch, wait for the expected accessibility identifier/value before
interacting or recording evidence; do not use fixed sleeps. Keep these four
canonical captures in the repository after acceptance:

- `docs/delivery/evidence/rr-r9-active-phase-overview.png`
- `docs/delivery/evidence/rr-r9-active-phase-board-wide.png`
- `docs/delivery/evidence/rr-r9-active-phase-board-compact.png`
- `docs/delivery/evidence/rr-r9-active-phase-recovery.png`

The ledger records accessibility observations for every scenario even when a
state does not require an additional screenshot.

### RR-R9C acceptance

- Run the combined focused suites, configured signed build, strict deep signing
  verification, and existing app verification command.
- In the defined Debug fixture's isolated alternate app/container, exercise
  both selector placements,
  keyboard-only selection, busy announcement, no-alternative state, mutation
  failure, authorization recovery, saved-refresh recovery, empty target phase,
  wide `1586 × 992`, and compact `760 × 520` behavior. Compare Phase Board with
  `docs/design/mockups/phase_board.png`; record any necessary deviation in the
  controlling design/ADR before acceptance.
- Confirm a selected ticket's valid cross-phase dependency references remain
  visible in detail while the other-phase ticket remains absent from board and
  graph-node membership.
- After independent Code Review, QA, Architecture, Security/Privacy, TPM, and
  Delivery Management all report no Required findings, use the installed typed
  MCP command once against the exact authorized Release Radar root to select
  `RR-ROADMAP`. Before generating the one request UUID, prove the installed app
  dashboard and selector have reached their ready accessibility state and the
  installed MCP connection succeeds at read-only `initialize`/`tools/list` with
  the accepted strict tool schema. A readiness failure stops before UUID
  generation or mutation. Then verify the running board immediately shows
  `RR-ROADMAP` with eight Backlog and three Blocked tickets, Activity contains
  the exact visible reason, and relaunch preserves the same board. Record the
  generated request ID and returned audit ID. Actor, asserted-thread, audit
  cardinality, and receipt cardinality remain proven by isolated RR-R9A and
  signed transport tests, not by Activity. Do not inspect or edit the owner
  SQLite database.

## Out of scope

- Phase creation, deletion, rename, reordering, archival, or import changes
- More than one active phase per project
- Ticket editing, movement, lane transitions, or cross-phase work-board views
- Roadmap/phase-model redesign, Project Plan, all-phase Work Board, or route
  changes
- New schema, migration, persistence table, notification/Pushover delivery
  semantics, event, or repository synchronization; only the required ordering
  of existing after-reply dashboard refresh before notification draining changes
- A generalized runtime fixture/fault framework, UI-test harness, production-
  default sample/fault behavior, owner-database inspection, or capture network
  access; only the targeted default-off Debug RR-R9 path above is authorized
- Direct SQLite edits or agent/helper database access
- New MCP transport, generic command surface, wire/envelope version, plugin
  lifecycle behavior, plugin version bump, permissions, entitlements, network,
  or dependencies
- Automatic mutation retry after unavailable, unknown, rejected, or committed-
  but-refresh-failed outcomes
- Filtering or deleting valid same-project cross-phase ticket-dependency
  references when changing active phase

## Acceptance summary

RR-R9 is complete only when the same validated command path serves authorized
agents and both owner surfaces; selection is persisted, audited, attributed,
immediately and coherently refreshed, accessible, recoverable, and proven
across relaunch; historical records remain unchanged; independent acceptance
is complete; and the final accepted typed command activates `RR-ROADMAP`.
