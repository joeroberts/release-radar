# RR-R9A Task Brief: Typed Active-Phase Authority

**Status:** Planning contract complete; implementation remains closed until
independent Architect, TPM, QA/Test, and Delivery Management preimplementation
review releases one fresh Implementer.

## Objective and user-visible outcome

Add one typed, audited, idempotent `setActivePhase` command that lets an
authorized agent select any existing phase belonging to the resolved project.
The selection persists across app/store relaunch and the existing post-command
refresh path can immediately project the selected phase. Invalid,
cross-project, unauthorized, unavailable, expired, duplicate, or uncertain
requests retain the existing explicit error/recovery semantics and never create
a partial or duplicate mutation.

RR-R9A is the complete authority slice through store, command, dispatcher,
signed transport, and MCP. It deliberately has no owner selector; RR-R9 is not
complete until RR-R9B and RR-R9C are accepted.

## Controlling references

- `docs/design/release-radar-active-phase-selection-design.md`
- `docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md`,
  **Task 1 (RR-R9A)**
- `docs/delivery/progress.md`, **Current gate** and **Release Radar roadmap
  synchronization — 2026-08-29**
- `docs/design/agent-driven-delivery-dashboard-design.md`, **Dashboard model**
  and **Failure behavior**
- `docs/architecture/ADR-001-release-radar-boundaries.md`, app-only database,
  explicit active phase, and typed bridge boundaries
- `docs/architecture/ADR-003-active-phase-selection.md`, shared command
  authority, same-project identity, audit/replay, and unchanged dependency
  semantics
- `docs/design/mockups/phase_board.png` as downstream RR-R9B/RR-R9C visual
  context; RR-R9A changes no UI

The approved complete RR-R9 outcome controls over implementation convenience.
This brief bounds only the first reviewable delivery checkpoint and does not
remove any RR-R9B or RR-R9C acceptance requirement.

## In scope

- Add `AgentCommand.setActivePhase(phaseID: String)` to durable envelope
  version 1.
- Validate non-empty bounded phase identity and the existing required envelope
  fields.
- Resolve the exact authorized project root through the existing registry.
- Require the target phase to exist in that same project.
- Upsert only the project's row in `project_active_phases` inside the existing
  app-owned audited/idempotent transaction.
- Return selected phase ID plus one audit ID.
- Audit external actor/reason/asserted attribution with project/phase scope;
  prove owner origin attribution at the dispatcher boundary for RR-R9B.
- Expose exactly one additional strict MCP tool:
  `release_radar_set_active_phase`.
- Preserve signed-peer, strict-JSON, payload, deadline, definitive-unavailable,
  uncertain-outcome, request replay, and request-ID-reuse behavior.
- Prove persistence across a recreated store/dispatcher and preservation of all
  historical phase/ticket/dependency state.

## Out of scope

- Project Overview, Phase Board, `AppModel`, selector UI, owner folder picker,
  or visual/runtime acceptance
- Phase creation, deletion, rename, reorder, archive, or multiple active phases
- Ticket editing, movement, lane transitions, or any roadmap/phase redesign
- A store migration, new table, new store service, notification/Pushover event,
  repository file write, new route, new helper, or generic MCP surface
- Bridge wire/envelope version changes; plugin manifest/version or lifecycle
  changes; signing, sandbox, entitlement, app-group, Keychain, or network
  changes
- Direct SQLite editing or database access from AgentTools/broker/helper
- Automatic retry after any failure or uncertain outcome
- Changes to `docs/delivery/progress.md` by the Implementer; Delivery Management
  owns the evidence entry after review

## Dependencies and release gate

- The existing schema contains `project_active_phases` with one row per project
  and a composite foreign key to same-project `phases`.
- The existing signed AgentTools → broker → app callback transport and app-only
  `AgentCommandDispatcher` transaction are accepted prerequisites.
- The owner-approved RR-R9 design and this registered brief require independent
  Architect, TPM, QA/Test, and Delivery Management review before implementation.
- One fresh Implementer owns only RR-R9A files. No concurrent writer may modify
  the same command, dispatcher, AgentTools, or bridge test files.
- A separate Code Reviewer, QA verifier, Architect, Security/Privacy verifier,
  TPM, and Delivery Manager must accept RR-R9A before RR-R9B is released.

## Affected subsystem and anticipated files

- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarAgentTools/main.swift`
- `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`

Inspect but do not modify for RR-R9A:

- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarTransport/BridgeXPCContracts.swift`
- `ReleaseRadarIntegration/AgentBridgeApplicationHost.swift`
- `ReleaseRadar/App/AppNotificationCoordinator.swift`

The implementation must preserve unrelated dirty changes in all files. No
project-file edit is required.

## Interface contract

```swift
public enum AgentCommand: Codable, Equatable, Sendable {
    // Existing cases remain byte/behavior compatible.
    case setActivePhase(phaseID: String)
}
```

The dispatcher adds exhaustive handling:

- `validate`: `phaseID` is non-whitespace and at most 256 UTF-8 bytes;
- `apply`: call `requireProjectEntity` for `phaseID` in `phases` using the
  resolved `projectID` and active transaction connection, then upsert the
  active row;
- `resultForCommand`: `entityIDs == [phaseID]`;
- `auditScope`: resolved project, `.phase`, `phaseID`.

The only mutation SQL is:

```sql
INSERT INTO project_active_phases (project_id, phase_id)
VALUES (?, ?)
ON CONFLICT(project_id) DO UPDATE SET phase_id = excluded.phase_id;
```

The MCP definition is exactly:

```json
{
  "name": "release_radar_set_active_phase",
  "inputSchema": {
    "type": "object",
    "properties": {
      "version": {"type": "integer", "const": 1},
      "requestID": {"type": "string", "format": "uuid"},
      "projectRoot": {"type": "string", "minLength": 1},
      "assertedThreadID": {"type": "string", "minLength": 1},
      "reason": {"type": "string", "minLength": 1},
      "phaseID": {"type": "string", "minLength": 1}
    },
    "required": ["version", "requestID", "projectRoot", "reason", "phaseID"],
    "additionalProperties": false
  }
}
```

The encoded command payload key is `setActivePhase` with field `phaseID`.

## Data, persistence, security, and privacy

- `project_active_phases` remains the only source of truth. No migration or
  duplicate active-phase field is allowed.
- The pointer update, audit row, and `agent_command_requests` receipt commit in
  the same existing store-owned transaction or all roll back.
- Composite same-project validation occurs in the app even though the database
  also has a foreign key. UI/tool input is not trusted.
- The app is the sole SQLite opener/writer. AgentTools only encodes and forwards
  the bounded envelope; broker and helpers retain no database authority.
- External actor is `release-radar-agent`; optional thread identity remains
  asserted rather than verified. Owner-origin dispatcher proof records
  `release-radar-owner` without a thread.
- Reasons retain the existing 1...1000 UTF-8-byte rule. No project content,
  ticket outcome, repository file, bookmark bytes, credential, or network data
  is introduced.
- Existing code-signing requirements, fixed local Mach services, exact peer
  identifiers/team, payload limits, and deadlines remain unchanged.
- Independent Security/Privacy review is blocking because the slice mutates
  authoritative local storage through the signed agent boundary.

## Fixtures and test strategy defined before implementation

Use only existing XCTest/temp-directory/store helpers. Add no new harness or
dependency.

The core fixture contains:

- project `project-1` with authorized root, active `phase-current`, target
  `RR-ROADMAP`, a historical phase, tickets in all three, and ticket/phase
  dependencies;
- project `project-2` with `other-project-phase`;
- ordered before-snapshots of phases, tickets, phase dependencies, ticket
  dependencies, active selection, audit count, and request count.

Before implementation, add these two explicit dispatcher RED cases:

- Create a fresh envelope that selects already-active `phase-current`. Require
  success, unchanged pointer/history, exactly one new agent audit and one new
  request receipt as explicit agent intent, then exact replay after dispatcher
  recreation with no further audit/receipt.
- Create a separate fresh envelope with
  `String(repeating: "é", count: 129)` as `phaseID`; first assert its UTF-8 byte
  count is `258`, then require `invalidEnvelope` and zero pointer, receipt,
  audit, phase, ticket, or dependency-history changes.

The signed transport fixture adds a second phase to its existing temporary
project and continues to use the package's real AgentTools, registered broker,
and app callback. Update the strict tool inventory from 12 to 13 and verify the
new tool's exact schema independently of the existing transition schema.

### Required RED

Run core RED before implementation:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Core-RED \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails on absent `AgentCommand.setActivePhase`.

After the core is green, write the MCP test and run signed transport RED:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Transport-RED \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests
```

Expected: tool inventory/schema or call fails because packaged AgentTools does
not expose the command.

### Required GREEN

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

Require zero test failures/skips, signed transport cleanup, and clean diff
output. Compilation or `StoreAcceptanceTests` alone is not acceptance.

## Happy path

1. AgentTools receives exact typed fields for an authorized project root and an
   existing same-project target phase.
2. The broker and app callback authenticate the current signed peers and admit
   the request before its deadline.
3. Dispatcher validates the envelope/root/phase and commits active pointer,
   external actor/reason phase-scoped audit, and durable receipt atomically.
4. The result returns target phase ID plus audit ID with MCP `isError: false`.
5. Exact replay, including after store/dispatcher recreation, returns the same
   result with one audit/receipt and no duplicate write.
6. A separate fresh request assigning the already-active phase succeeds and
   creates exactly one new audit/receipt as explicit agent intent; replay is
   duplicate-free.
7. A normal subsequent dashboard load sees the selected phase; RR-R9B owns the
   visible selector/refresh behavior.

## Non-happy paths and recovery

- Empty `phaseID`, or a non-whitespace `phaseID` greater than 256 UTF-8 bytes:
  `invalidEnvelope`; zero pointer/receipt/audit/history writes.
- Missing phase: `invalidReference`; prior pointer/history unchanged.
- Other-project phase: `crossProjectReference`; prior pointer/history unchanged.
- Unauthorized root: `unauthorizedProjectRoot`; zero writes.
- Unsupported envelope or wire version, malformed number/optional field,
  oversized payload, wrong peer, or unavailable app: existing structured
  failure and zero admitted writes.
- Deadline expires before transaction admission: `appUnavailable` or transport
  uncertainty according to the accepted boundary, with no eventual write from
  an unadmitted request.
- Reply/callback loss after authenticated handoff: `outcomeUnknown`; caller
  refreshes state and may replay only the complete original request with the
  same ID. No automatic replacement request.
- Same request ID/different body: `requestIDReused`; original result/state
  remains authoritative.
- Store internal/unavailable failure: existing mapped error and atomic rollback.

## Activity and audit evidence

For each accepted fresh request, require exactly one audit row with:

- returned audit event ID;
- actor `release-radar-agent` or `release-radar-owner` according to origin;
- asserted thread fields only when supplied externally;
- exact reason;
- resolved project ID;
- entity type `phase`;
- entity ID equal to selected phase ID;
- non-empty timestamp.

Rejected requests create no audit or request receipt. Exact replay returns the
original audit ID without another row. RR-R9A creates no notification or
repository evidence.

A valid fresh already-active assignment is not rejected: it records exactly
one audit/receipt as explicit agent intent even though the pointer value does
not change. Its exact replay adds nothing.

## Acceptance criteria

- `setActivePhase` is a real additive `AgentCommand` handled exhaustively by
  validation, result, audit, and apply switches.
- A successful same-project command changes only the active pointer plus its
  transactional audit/receipt and survives relaunch.
- The command does not filter, delete, or rewrite valid same-project cross-
  phase ticket-dependency references; RR-R9B owns their phase-scoped board and
  truthful active-ticket-detail projection regression.
- Every phase, ticket, lane, dependency, blocker, evidence, review, completion,
  notification, and earlier audit remains unchanged.
- Unknown/cross-project/unauthorized/malformed inputs return their existing
  typed errors with full rollback.
- Exact durable replay returns the original result; changed request-ID reuse is
  rejected; no silent retry or duplicate mutation exists.
- A fresh already-active agent assignment succeeds with exactly one new
  audit/receipt, while its replay is duplicate-free.
- A 258-byte non-whitespace phase ID fails as `invalidEnvelope` before any
  pointer, receipt, audit, or history change.
- MCP lists exactly 13 typed tools including the exact new strict schema and
  forwards it through the unchanged signed transport.
- Wrong peer/version, unavailable, deadline, and uncertain-outcome behaviors
  remain accepted and tested.
- No migration, new service/dependency/permission, plugin version change,
  owner UI, or direct SQLite access is introduced.
- Fresh independent reviews report zero open Required findings before RR-R9B.

## Required independent reviews

- Code Reviewer: exhaustive switch/interface correctness, regression, scope
- QA/Test: fresh core and signed transport runs, rollback/relaunch/history
- Architect: app-only authority, unchanged versions/schema/transport boundaries
- Security/Privacy: root authorization, same-project validation, peer signing,
  audit attribution, no new data exposure
- TPM: complete-outcome preservation and RR-R9B dependency release
- Delivery Manager: evidence sufficiency, serialized writer, next gate

The Implementer may not perform or approve any of these reviews.

## Completion evidence for `docs/delivery/progress.md`

Delivery Management records:

- RR-R9A status and dependency gate;
- Implementer identity and bounded files;
- exact RED/GREEN commands, counts, failures/skips, and DerivedData locations as
  non-authoritative temporary evidence;
- command result, audit/request IDs from fixtures, fresh already-active intent
  plus duplicate-free replay, oversized UTF-8 rollback, relaunch/history proof;
- signed package/tool schema and transport cleanup results;
- confirmation that schema, bridge versions, plugin version, permissions,
  historical records, and unrelated dirty changes were preserved;
- Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery decisions;
- required findings and their closure, residual risks, and whether RR-R9B is
  released as the next eligible task.
