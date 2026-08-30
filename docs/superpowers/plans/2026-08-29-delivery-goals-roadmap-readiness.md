# RR-R10 Delivery Goals and Roadmap Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver first-class phase-scoped Delivery Goals, enforce exact ready-phase coverage across every ticket writer, present the distinction from Codex execution goals, and repair RR-R10 plus the complete Established product roadmap without reopening any Accepted ticket.

**Architecture:** Add an additive v11 relational model and a single store-owned planning policy consumed by bridge, importer, sample, and debug phase/ticket writers. Extend the existing audited/idempotent agent-command path for bounded plan revisions, finalization, and Delivery Goal lifecycle, then project all phase plans into the existing five-lane SwiftUI board with a non-mutating viewed-phase selector. Finish with an installed, replay-safe data repair and exact state-preservation proof.

**Tech Stack:** Swift 6, SwiftUI, Observation, SQLite3, XCTest, macOS 14+, Xcode project file-system-synchronized groups, existing XPC/MCP bridge.

**Spec:** `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md`

## Global Constraints

- The governing ticket is `RR-R10` in `release-radar-post-mvp-remediation`.
- Delivery chunks are review checkpoints under the complete RR-R10 outcome; no chunk is a reduced feature commitment.
- Keep exactly five persisted lanes: Backlog, In progress, Needs review, Blocked, Accepted.
- Accepted tickets are terminal and are never reopened. Rework and later defects create new Backlog tickets.
- Delivery Goals are app-owned phase-plan records; `observed_goals` and `ticket_goal_links` remain Codex execution context with unchanged semantics.
- Release Radar's app process remains the only SQLite writer. The helper and bridge use typed commands only.
- Store migration is additive v10 to v11 and never infers Delivery Goals or assignments.
- New and phase-moved tickets enter Backlog. Backlog and Blocked cannot bypass Ready plus exact-assignment validation.
- Existing v10 In progress and Needs review tickets receive the only legacy continuation; existing Blocked tickets do not.
- Plan revisions allow at most 64 total goal operations (`goalUpserts + supersededGoalIDs`), 512 total assignment operations (`assignments + unassignedTicketIDs`), and 65,536 bytes for the sorted-key JSON encoding of the `AgentCommand` value before it is placed in the XPC envelope. Validate limit−1, limit, and limit+1 at the command boundary.
- A viewed phase is navigation-only. Existing active-phase mutation remains separate and governed by ADR-003.
- Portable archive v1 must never silently omit Delivery Goals; no portable archive v2 is added.
- The approved planning package is committed and pushed before implementation. Thereafter, each bounded task is committed and pushed only after that task is completely implemented and its required independent gate returns GO with Required 0. Never commit or push partial or unverified task work.
- Before coding begins, the task brief must split any task forecast to exceed roughly eight hours of agent implementation work, or whose diff would be too large for one coherent review, into smaller dependency-safe tasks. Each resulting task must still deliver a complete testable slice, pass its own independent gate, and receive its own commit/push/remote checkpoint.
- Preserve the unrelated untracked `default.profraw` file untouched.
- Before each implementation task, a fresh independent Planning agent produces its durable brief under `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/`; Architecture, TPM, QA/Test, and Delivery Management review and release that brief before even the RED implementation test is written. After implementation, a separate fresh Code Reviewer and QA verifier review the result, with Architecture, TPM, and Delivery Management disposition before the next task opens. Storage/bridge/archive tasks also require independent Security/Privacy review. No implementer reviews or verifies its own work.

## File Structure

### New production files

- `ReleaseRadarCore/Models/DeliveryGoalModels.swift` — public IDs, phase-plan/goal states, revision operations, projections shared across Core and app.
- `ReleaseRadarCore/Planning/DeliveryPlanningPolicy.swift` — the sole SQL-writing policy for phase creation, phase plans, Delivery Goals, assignments, goal lifecycle, ticket creation/movement/lane transitions, migration-granted continuation enforcement, and archive-v1 compatibility.
- `ReleaseRadar/Projects/PhaseBoardPlanningControls.swift` — viewed-phase, active-phase action, plan summary, goal filters, status, and accessibility presentation.

The Xcode project uses file-system-synchronized groups, so these files require no `project.pbxproj` membership edit.

### Modified production files

- `ReleaseRadarCore/Store/StoreMigrations.swift` — schema v11, manifest validation, indexes, foreign keys, migration backfill.
- `ReleaseRadarCore/Store/DeliveryStore.swift` — new audit entity types only; existing observed-goal types remain unchanged.
- `ReleaseRadarCore/AgentBridge/AgentCommand.swift` — new bounded plan/lifecycle commands and typed errors/results.
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift` — validation, audit scope, replay-safe application, and routing all ticket writes through planning policy.
- `ReleaseRadarAgentTools/main.swift` — MCP definitions and exact JSON translation for the new commands.
- `ReleaseRadarCore/Import/RekonArtifactImporter.swift` — Legacy-unassessed phase creation, Backlog-only ticket creation, and source-lane review facts.
- `ReleaseRadar/Projects/DashboardSampleData.swift` — valid sample plan creation before governed lane transitions.
- `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` — valid capture plan creation before governed lane transitions under `#if DEBUG`.
- `ReleaseRadar/Projects/DashboardProjection.swift` — all-phase boards, plan/goal coverage, unambiguous ticket goal contexts, filtering.
- `ReleaseRadar/Projects/PhaseBoardView.swift` — planning controls and filtered five-lane board.
- `ReleaseRadar/Projects/ActivePhaseSelector.swift` — extract reusable active-phase mutation status presentation; keep Overview behavior unchanged.
- `ReleaseRadar/Projects/TicketDetailView.swift` — separate Delivery Goal and Codex execution goal sections.
- `ReleaseRadar/App/AppModel.swift` — per-project viewed-phase state and dependency/selection coherence without active-phase mutation.
- `ReleaseRadar/Navigation/SidebarView.swift` — supply the viewed board and planning-control callbacks.
- `ReleaseRadar/Activity/ProjectActivityProjection.swift` — goal/plan audit titles and phase/ticket attribution.
- `ReleaseRadar/Review/ReviewInboxProjection.swift` — derived Awaiting-acceptance owner-attention records with stable identity.
- `ReleaseRadar/Review/NeedsReviewView.swift` — owner-app-only Delivery Goal acceptance action.

### Test files

- Modify `ReleaseRadarTests/StoreAcceptanceTests.swift` — v11 migration and schema integrity.
- Create `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite` — exact empty schema-v10 database generated before v11 production code changes.
- Create `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS` — exact fixture digest.
- Create `ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests.swift` — state machines, readiness, ticket-writer matrix, rollback, archive guard.
- Modify `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift` — typed command validation, replay, limits, and all existing-ticket command bypasses.
- Modify `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift` — packaged MCP schemas and signed bridge transport.
- Modify `ReleaseRadarTests/RekonImportAcceptanceTests.swift` — Legacy phase state, Backlog coercion, and source-lane review behavior.
- Modify `ReleaseRadarTests/DashboardProjectionTests.swift` — phase-plan/goal projection and exact RR-ROADMAP catalog.
- Modify `ReleaseRadarTests/AppRouteTests.swift` — non-mutating viewed phase, active-phase separation, refresh/recovery, selection coherence.
- Modify `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift` — Activity attribution and dependency preservation.
- Modify `ReleaseRadarTests/EndToEndAcceptanceTests.swift` — complete v11 command-to-UI data flow and no-reopen invariant.
- Modify `ReleaseRadarUITests/ReleaseRadarUITests.swift` — wide/compact controls, keyboard/VoiceOver identifiers, goal filters, inspector headings.

---

### Task 1: Add the v11 persistence foundation

**Owner-size split:** Deliver this original outcome through two dependency-safe
checkpoints. Task 1A generates, proves, reviews, commits, pushes, and remotely
verifies the genuine schema-v10 fixture before any v11 production edit. Task
1B then delivers the public models plus complete additive v11 migration and
preservation proof. The split changes commit/review boundaries only; together
the two briefs cover every Task 1 requirement.

**Files:**
- Create: `ReleaseRadarCore/Models/DeliveryGoalModels.swift`
- Modify: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Create: `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- Create: `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md`

**Interfaces:**
- Produces: `DeliveryGoalID`, `PhasePlanState`, `DeliveryGoalLifecycle`, `PhasePlanRecord`, `DeliveryGoalRecord`, `DeliveryGoalCriterionRecord`, `DeliveryGoalAssignmentRecord`, `DeliveryGoalAssignmentEventRecord`, `PhasePlanReadinessFailure`.
- Produces schema tables: `phase_plans`, `delivery_goals`, `delivery_goal_done_criteria`, `delivery_goal_ticket_assignments`, `delivery_goal_assignment_events`; column `tickets.plan_legacy_continuation`.
- Consumes no new interface.

- [ ] **Step 1: Write the task brief before implementation release**

Have a fresh independent Planning agent record the objective, exact
spec/ADR/design references, in/out scope, migration risk, v10 fixture,
foreign-key/rollback strategy, no-inference rule, test commands, independent
reviewers, and expected ledger evidence in the two split briefs. Register both SHA-256 values in
`docs/delivery/task-briefs/SHA256SUMS` using the existing format. Architecture,
TPM, QA/Test, Delivery Management, and Security/Privacy must return GO with
Required 0 on that exact brief before Step 2 begins.

After Required-0 closure, create a planning-only checkpoint before any
generator or product edit. Stage only `.gitignore`, this split amendment, both
registered briefs, `docs/delivery/task-briefs/SHA256SUMS`, and the planning/
review evidence in `docs/delivery/progress.md`. Commit, push, and verify exact
local/remote SHA equality with ahead/behind `0/0`; Step 2 remains closed until
that checkpoint is remotely exact.

- [ ] **Step 2: Generate one genuine schema-v10 fixture before changing production code**

While `StoreMigrations.currentVersion` is still 10, temporarily add one
`StoreAcceptanceTests` generator test. Require the exact
`RR_SCHEMA_V10_FIXTURE_EXPORT=1` gate, create a unique directory under the
sandbox-writable XCTest temporary directory, initialize a `DeliveryStore`
there, assert `PRAGMA user_version == 10`, close the store, and attach the
database bytes to the passing test result before removing the temporary
directory. Use this exact body:

```swift
func testGenerateExactVersionTenFixtureAttachment() throws {
    let environment = ProcessInfo.processInfo.environment
    let exportGate = try XCTUnwrap(environment["RR_SCHEMA_V10_FIXTURE_EXPORT"])
    guard exportGate == "1" else {
        XCTFail("RR_SCHEMA_V10_FIXTURE_EXPORT must equal 1")
        return
    }
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("rr-schema-v10-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("release-radar-v10.sqlite")
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    var store: DeliveryStore? = DeliveryStore(databaseURL: url)
    guard try SQLiteConnection(url: url).scalarInt("PRAGMA user_version") == 10 else {
        return XCTFail("Generated fixture was not schema version 10")
    }
    withExtendedLifetime(store) {}
    store = nil
    let attachment = XCTAttachment(
        data: try Data(contentsOf: url),
        uniformTypeIdentifier: "public.data"
    )
    attachment.name = "release-radar-v10.sqlite"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```
Two prior forms failed closed without producing a fixture: the original parent-
shell variable did not reach hosted XCTest, and the first `.xctestrun` form
successfully crossed that boundary but the app sandbox correctly denied a
direct repository write. Keep the sandbox intact. Build without running tests,
use a new absent DerivedData path, copy the single freshly generated format-2
`.xctestrun` under `/tmp`, assert its exact nested test-target environment
structure before injecting only the export gate, run only the attachment
generator once with parallel testing disabled and an explicit absent result-
bundle path, then remove the generator source:

```bash
set -euo pipefail
RR_TASK1A_DERIVED=/tmp/release-radar-rr-r10-v10-attachment
test ! -e "$RR_TASK1A_DERIVED"
xcodebuild build-for-testing -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' -derivedDataPath "$RR_TASK1A_DERIVED"
RR_TASK1A_XCTESTRUN="$(rg --files --hidden --no-ignore "$RR_TASK1A_DERIVED/Build/Products" \
  | rg '/ReleaseRadar_ReleaseRadar_.*\.xctestrun$')"
test -n "$RR_TASK1A_XCTESTRUN"
test "$(printf '%s\n' "$RR_TASK1A_XCTESTRUN" | wc -l | tr -d ' ')" = "1"
test "$(plutil -extract __xctestrun_metadata__.FormatVersion raw \
  "$RR_TASK1A_XCTESTRUN")" = "2"
test "$(plutil -type TestConfigurations "$RR_TASK1A_XCTESTRUN")" = "array"
test "$(plutil -extract TestConfigurations raw -expect array \
  "$RR_TASK1A_XCTESTRUN")" = "1"
if plutil -type EnvironmentVariables "$RR_TASK1A_XCTESTRUN" >/dev/null 2>&1; then
  exit 1
fi
test "$(plutil -extract TestConfigurations.0.TestTargets raw -expect array \
  "$RR_TASK1A_XCTESTRUN")" = "1"
test "$(plutil -type \
  TestConfigurations.0.TestTargets.0.EnvironmentVariables \
  "$RR_TASK1A_XCTESTRUN")" = "dictionary"
RR_TASK1A_CONFIGURED="$RR_TASK1A_DERIVED/Build/Products/ReleaseRadar_Task1A.xctestrun"
cp "$RR_TASK1A_XCTESTRUN" "$RR_TASK1A_CONFIGURED"
plutil -insert \
  TestConfigurations.0.TestTargets.0.EnvironmentVariables.RR_SCHEMA_V10_FIXTURE_EXPORT \
  -string "1" \
  "$RR_TASK1A_CONFIGURED"
RR_TASK1A_RESULT=/tmp/release-radar-rr-r10-v10-attachment-result.xcresult
test ! -e "$RR_TASK1A_RESULT"
xcodebuild test-without-building -xctestrun "$RR_TASK1A_CONFIGURED" \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -resultBundlePath "$RR_TASK1A_RESULT" \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionTenFixtureAttachment
```

After removing the generator, export only that test's attachments to a new
`/tmp` directory. Require exactly one manifest entry and one nonfailure
attachment named `release-radar-v10.sqlite`, reject unsafe exported names, and
copy those bytes from the result bundle to the still-absent repository fixture
path. Verify the fixture directly reports schema 10 and contains no v11 table,
column, index, or trigger, then write its SHA-256 to
`ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`. The fixture and digest are
durable test inputs; the removed generator, result bundle, and attachment export
are temporary evidence, not deliverables.
Require fresh postimplementation Code Review and QA plus Architecture,
Security/Privacy, TPM, and Delivery Management GO with Required 0. Update the
ledger, stage only the two fixture artifacts and `docs/delivery/progress.md`,
commit/push Task 1A, and verify exact remote equality before Step 3/Task 1B
opens.

- [ ] **Step 3: Write RED model and migration tests against the exact fixture**

Verify the checked-in v10 fixture against `SHA256SUMS`, copy it to a per-test
temporary URL, seed a complete v10 graph through raw fixture SQL, and snapshot
every seeded v10 table before opening `DeliveryStore`. The graph contains two phases and an active-phase
pointer; Backlog, In progress, Needs review, Blocked, and Accepted tickets;
phase/ticket dependencies; an unresolved blocker; observed thread and goal;
exact ticket/Codex-goal link; audit attribution; and an agent-command receipt.
After migration and relaunch assert:

```swift
XCTAssertEqual(try migratedVersion(), 11)
XCTAssertEqual(try migratedPhasePlanStates(), [phase1: .legacyUnassessed, phase2: .legacyUnassessed])
XCTAssertEqual(try deliveryGoalCount(), 0)
XCTAssertEqual(try deliveryGoalAssignmentCount(), 0)
XCTAssertEqual(try legacyContinuationTicketIDs(), Set([activeTicketID, reviewTicketID]))
XCTAssertEqual(try semanticV10Snapshot(afterMigration: true), beforeMigration)
XCTAssertNil(try migratedConnection.row("PRAGMA foreign_key_check"))
```

The semantic snapshot excludes only `PRAGMA user_version` and the additive v11
objects/column. It compares the active phase, ticket outcomes/lanes,
dependencies, blockers, observed records, exact runtime link, audit, and
request receipt field-for-field. Also add exact-schema tests for lifecycle
`CHECK` constraints, nonnegative revisions, Ready/`ready_revision`
consistency, ordered nonempty criteria, unique ticket assignment,
same-project/same-phase foreign keys, the deferred assignment-event/audit
foreign key, `PRAGMA foreign_key_check`, and the invariant that every newly
inserted phase receives a phase-plan row.

- [ ] **Step 4: Run the focused test and confirm RED**

Run:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-red -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Expected: failure because schema version remains 10 and the new types/tables/column do not exist.

- [ ] **Step 5: Add exact public model types**

Create `DeliveryGoalModels.swift` with these declarations and public memberwise initializers:

```swift
public struct DeliveryGoalID: DeliveryRecordID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum PhasePlanState: String, Codable, CaseIterable, Sendable {
    case legacyUnassessed = "legacy_unassessed"
    case draft
    case ready
}

public enum DeliveryGoalLifecycle: String, Codable, CaseIterable, Sendable {
    case draft
    case planned
    case active
    case awaitingAcceptance = "awaiting_acceptance"
    case accepted
    case superseded
}

public struct DeliveryGoalDraft: Codable, Equatable, Sendable {
    public let id: DeliveryGoalID
    public let title: String
    public let outcome: String
    public let doneCriteria: [String]
    public let sortOrder: Int
}

public struct DeliveryGoalAssignment: Codable, Equatable, Sendable {
    public let goalID: DeliveryGoalID
    public let ticketID: TicketID
}
```

Add `.phasePlan` and `.deliveryGoal` to `AuditEntityType` in
`DeliveryStore.swift`; do not modify `ObservedGoalID`, `ObservedGoalRecord`, or
`NotificationEventRecord.goalID`.

- [ ] **Step 6: Implement schema v11 and manifest validation**

Set `currentVersion` to 11, apply `schemaVersion11` after v10, register all tables/columns/indexes/foreign keys in the existing schema manifest, and use relational done criteria:

```sql
ALTER TABLE tickets ADD COLUMN plan_legacy_continuation INTEGER NOT NULL DEFAULT 0
    CHECK (plan_legacy_continuation IN (0, 1));
UPDATE tickets
SET plan_legacy_continuation = 1
WHERE lane IN ('in_progress', 'needs_review');

CREATE TABLE phase_plans (
    project_id TEXT NOT NULL,
    phase_id TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('legacy_unassessed', 'draft', 'ready')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0),
    ready_revision INTEGER,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    finalized_at TEXT,
    PRIMARY KEY(project_id, phase_id),
    FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE,
    CHECK ((state = 'ready') = (ready_revision IS NOT NULL)),
    CHECK (ready_revision IS NULL OR ready_revision = revision)
);
```

Create `delivery_goals`, `delivery_goal_done_criteria`, and
`delivery_goal_ticket_assignments` with exact project/phase composite foreign
keys and a unique `(project_id, ticket_id)` assignment. Add
`delivery_goal_assignment_events` with the exact audit ID, project, phase,
ticket, previous/current goal IDs, structural revision, and assigned/
unassigned/reassigned action. Its audit-event foreign key is
`DEFERRABLE INITIALLY DEFERRED`, allowing the store-owned audit insert later in
the same transaction; all project/phase/ticket/goal references are composite
and fail closed. Add the supporting unique identity indexes required for
composite references. Insert one Legacy-unassessed phase-plan row per existing
phase with one captured migration timestamp. Add a manifest-validated `AFTER
INSERT` phase trigger that creates a Legacy-unassessed phase-plan row as the
fail-safe default for every future phase; the Task 2 governed phase writer
changes a newly created ordinary phase to Draft in the same transaction, while
an imported phase retains Legacy unassessed. Insert no goal, assignment, or
assignment-event rows.

- [ ] **Step 7: Run focused migration tests GREEN**

Use `/tmp/release-radar-rr-r10-task1-green` with the Step 4 command. Expected: every `StoreAcceptanceTests` case passes, schema is 11, and v10 snapshot preservation remains intact.

- [ ] **Step 8: Run the complete existing store and plugin-lifecycle migration boundary**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task1-regression -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests
```

Expected: all selected tests pass after updating assertions that truthfully expect schema 11; lifecycle singleton behavior remains unchanged.

- [ ] **Step 9: Independent gate, ledger update, commit, and remote verification**

This is the Task 1B gate; Task 1A must already be committed, pushed, and
remotely exact. Run `git diff --check` and require Task 1B's independent reviews
to return GO with Required 0. Record exact commands/results and reviewer
dispositions in `docs/delivery/progress.md`. Stage only Task 1B model/store/test
paths plus the ledger, inspect the staged diff, commit the fully verified task,
push `codex/release-radar-mvp`, and verify local HEAD equals the remote branch
SHA before Task 2 opens.

---

### Task 2: Implement the store-owned plan and ticket policy

**Files:**
- Create: `ReleaseRadarCore/Planning/DeliveryPlanningPolicy.swift`
- Create: `ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Modify: `ReleaseRadar/Projects/DashboardSampleData.swift`
- Modify: `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`
- Modify: `ReleaseRadarTests/RekonImportAcceptanceTests.swift`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2-planning-policy-brief.md`

**Interfaces:**
- Consumes Task 1 model types and v11 tables.
- Produces `DeliveryPlanningPolicy.upsertPhase`, `applyRevision`, `finalizePlan`, `transitionGoal`, `upsertTicket`, `transitionTicket`, `assertCanRecordReviewOrCompletion`, `assertPortableArchiveV1Exportable`, and `PhaseCreationMode`.
- Existing `AgentCommandDispatcher` phase/ticket/review/completion cases become clients of this policy; no new bridge command is exposed until Task 3.

- [ ] **Step 1: Persist and register the Task 2 brief**

A fresh independent Planning agent must produce the brief with the exact Ready
invariant, complete goal transition matrix, ticket operation matrix, legacy
continuation deletion rule, Accepted-terminal rule, import/debug modes,
archive-v1 precondition, rollback tests, and independent security review.
Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy must
return GO with Required 0 on that exact brief before Step 2 begins.

- [ ] **Step 2: Write RED phase-plan state-machine tests**

Create tests that call the intended policy directly inside `DeliveryStore.transact`:

```swift
let auditEventID = AuditEventID(rawValue: UUID().uuidString)
try await store.transact(
    actor: .init(id: "planner"),
    reason: "Draft complete plan",
    auditEventID: auditEventID,
    auditScope: .init(projectID: projectID, entityType: .phasePlan, entityID: phaseID.rawValue)
) { db in
    try DeliveryPlanningPolicy.applyRevision(
        projectID: projectID,
        phaseID: phaseID,
        expectedRevision: 0,
        goalUpserts: [
            .init(
                id: .init(rawValue: "DG-1"),
                title: "Complete outcome",
                outcome: "Every upcoming ticket has one accepted plan outcome.",
                doneCriteria: ["All upcoming tickets are assigned exactly once."],
                sortOrder: 0
            ),
        ],
        assignments: [.init(goalID: .init(rawValue: "DG-1"), ticketID: ticketID)],
        unassignedTicketIDs: [],
        supersededGoalIDs: [],
        auditEventID: auditEventID,
        connection: db
    )
}
```

Assert Draft revision 1, omission-does-not-delete, stale revision rollback,
cross-phase rejection, the three total-operation limit boundaries, nonempty/
bounded strings, empty revision rejection with no audit/receipt, no assignment
to Superseded, and Ready finalization that atomically promotes complete Draft
goals to Planned. Reject finalizing zero upcoming tickets, zero goals,
zero-ticket goals, incomplete definitions, missing/duplicate coverage, and
non-promotable lifecycles. Prove structural revision changes exactly once for
ticket create, same-phase outcome edit, phase move, assignment change, and goal
definition change; exact no-op replay and lane/blocker/evidence progress do not
change it. Prove a previously Ready plan stays Ready and projects a legitimate
completed state after all assigned tickets become Accepted.

- [ ] **Step 3: Write RED ticket matrix and lifecycle tests**

Cover every row from the spec with named tests. Prove that governed phase
creation yields Draft, imported phase creation yields Legacy unassessed, and
an existing Ready/Draft phase is never reset by a replay or import.
The core Accepted invariant is:

```swift
await XCTAssertThrowsErrorAsync {
    try await store.transact(actor: .init(id: "agent"), reason: "Forbidden reopen") { db in
        try DeliveryPlanningPolicy.transitionTicket(
            projectID: projectID,
            ticketID: acceptedTicketID,
            to: .inProgress,
            connection: db
        )
    }
}
XCTAssertEqual(try await lane(of: acceptedTicketID, in: store), .accepted)
```

Also prove: new/moved non-Backlog rejection; Backlog direct review/blocked/
accepted rejection; incomplete phase start rejection; Blocked cannot bypass;
open blocker and unsatisfied ticket/phase dependency start rejection with
zero audit/receipt, followed by success only after blockers resolve and
dependencies are Accepted; Planned becomes Active with first work; Awaiting
acceptance requires all tickets Accepted; rejected goal acceptance uses a new
Backlog ticket; legacy
In progress/Needs review can continue; returning to Backlog clears the flag;
legacy Blocked cannot resume; Accepted legacy remains immutable; and request-
review/record-completion mutations reject for an unstarted Backlog ticket
without blocking dependencies, blockers, or evidence mutations.

Also reject definition changes to Accepted/Superseded goals, assignment removal
or transfer for a started/Accepted ticket, and direct lifecycle requests for
Draft→Planned, Planned→Active, or supersession because those transitions must
remain coupled to finalization, governed ticket start, or structural revision.
For both Active→Awaiting acceptance and owner-app Awaiting acceptance→Accepted,
structurally edit the Ready plan back to Draft, pass the new current (therefore
not stale) revision, and assert `phasePlanNotReady` with lifecycle, audit,
receipt, owner attention, assignment events, and notifications unchanged.
Re-finalize that same revision and prove the otherwise identical valid
transition succeeds.

- [ ] **Step 4: Run focused tests and confirm RED**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task2-red -only-testing:ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests
```

Expected: compilation/test failure because `DeliveryPlanningPolicy` is absent.

- [ ] **Step 5: Implement the single policy surface**

Create the exact interface below and keep all SQL mutation helpers private to
the file:

```swift
public enum PhaseCreationMode: Sendable {
    case governed
    case legacyUnassessedImport
}

public enum DeliveryPlanningPolicy {
    public static func upsertPhase(
        projectID: ProjectID,
        phaseID: PhaseID,
        name: String,
        mode: PhaseCreationMode,
        connection: SQLiteConnection
    ) throws

    public static func applyRevision(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        goalUpserts: [DeliveryGoalDraft],
        assignments: [DeliveryGoalAssignment],
        unassignedTicketIDs: [TicketID],
        supersededGoalIDs: [DeliveryGoalID],
        auditEventID: AuditEventID,
        connection: SQLiteConnection
    ) throws

    public static func finalizePlan(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        connection: SQLiteConnection
    ) throws

    public static func transitionGoal(
        projectID: ProjectID,
        phaseID: PhaseID,
        goalID: DeliveryGoalID,
        expectedPlanRevision: Int64,
        to lifecycle: DeliveryGoalLifecycle,
        origin: AgentCommandOrigin,
        connection: SQLiteConnection
    ) throws

    public static func upsertTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        phaseID: PhaseID,
        outcome: String,
        lane: TicketLane,
        connection: SQLiteConnection
    ) throws

    public static func transitionTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        to lane: TicketLane,
        connection: SQLiteConnection
    ) throws

    public static func assertCanRecordReviewOrCompletion(
        projectID: ProjectID,
        ticketID: TicketID,
        connection: SQLiteConnection
    ) throws

    public static func assertPortableArchiveV1Exportable(
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws
}
```

Use one private `phasePlan(projectID:phaseID:connection:)` read and one private
`invalidatePlan` writer. `upsertTicket` must distinguish create, same-phase
update, and Backlog-only phase move; delete an old assignment on phase move;
invalidate source and destination exactly once; and route any requested lane
change through `transitionTicket`. Exact accepted no-op may replay, but no field
of an Accepted ticket may change. `applyRevision` inserts one deferred
`delivery_goal_assignment_events` row for each affected ticket using the same
store-owned `auditEventID`, including previous/current goal and resulting
revision, so ticket Activity can recover the exact bulk assignment change.

`transitionGoal` validates `expectedPlanRevision` but does not increment it.
Both allowed transitions require the phase plan to be Ready at that exact
`ready_revision`. The direct surface permits Active→Awaiting acceptance after
all children are Accepted and Awaiting acceptance→Accepted only when
`origin == .ownerApp`.
Draft promotion, first-work activation, and supersession reject here and occur
only in their coupled policy operations.

- [ ] **Step 6: Route every product/debug phase and ticket writer through the policy**

Replace the dispatcher phase branch and two ticket SQL branches with governed
policy calls. In `RekonArtifactImporter`, create phases through
`.legacyUnassessedImport`, create every imported ticket in Backlog, and add one
stable import-review item whenever the source lane was not Backlog; the review
summary preserves that source lane for owner reconciliation. The importer never
writes `plan_legacy_continuation`. Make sample/capture writers create Draft
goals and assignments, finalize their plans, and use governed ticket
transitions to reach fixture lanes; remove every legacy fixture mode. Direct SQL
in XCTest setup may remain setup-only, but no shipping or debug product path may
create phases or write tickets around the policy. Before the dispatcher inserts
a ticket-scoped review or completion record, call
`assertCanRecordReviewOrCompletion` in the same transaction. Keep blockers,
dependencies, and evidence available and nonstructural exactly as approved.

- [ ] **Step 7: Implement the archive-v1 loss guard**

`assertPortableArchiveV1Exportable` returns normally only when every phase plan
is Legacy unassessed and no Delivery Goal or assignment exists. Otherwise throw
`PlanningPolicyError.archiveVersionCannotRepresentDeliveryGoals`. Keep the
currently unavailable Portable Import UI unavailable; do not implement archive
v2 or an exporter in RR-R10.

- [ ] **Step 8: Run focused and importer tests GREEN**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task2-green -only-testing:ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests -only-testing:ReleaseRadarTests/RekonImportAcceptanceTests -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests
```

Expected: all selected tests pass; existing observed goals and ticket-goal links
remain unchanged in before/after snapshots.

- [ ] **Step 9: Independent gate, ledger update, commit, and remote verification**

Require Code Review, QA/Test, Architecture, Security/Privacy, TPM, and Delivery
Management GO with Required 0 before Task 3 opens. Record evidence, stage only
Task 2 paths, inspect the staged diff, commit and push the fully verified task,
and verify exact local/remote SHA equality before Task 3 opens.

---

### Task 3: Expose audited, bounded Delivery Goal commands

**Files:**
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarAgentTools/main.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-3-agent-command-surface-brief.md`

**Interfaces:**
- Consumes Task 2 policy exactly.
- Produces agent commands `applyPhasePlanRevision`, `finalizePhasePlan`, and `transitionDeliveryGoal`.
- Produces MCP tools `release_radar_apply_phase_plan_revision`, `release_radar_finalize_phase_plan`, and `release_radar_transition_delivery_goal`.
- Extends `AgentCommandResult` with optional `phasePlanRevision` and adds typed planning errors without changing existing command JSON.

- [ ] **Step 1: Persist/register the Task 3 brief and exact JSON fixtures**

Have a fresh independent Planning agent include full example requests, the
summed 64/512 limits, exact 65,536-byte encoded-command boundary, canonical
replay body, stale revision response, external-agent acceptance denial,
owner-app acceptance origin, audit/event-link scopes, XPC envelope boundary,
wrong-request replay behavior, and installed-helper tests. Architecture, TPM, QA/Test, Delivery
Management, and Security/Privacy must return GO with Required 0 on that exact
brief before Step 2 begins.

- [ ] **Step 2: Write RED command and MCP schema tests**

Add an exact command round-trip:

```swift
let command = AgentCommand.applyPhasePlanRevision(
    phaseID: "phase-1",
    expectedRevision: 3,
    goalUpserts: [goalDraft],
    assignments: [.init(goalID: .init(rawValue: "DG-1"), ticketID: .init(rawValue: "T-1"))],
    unassignedTicketIDs: [],
    supersededGoalIDs: []
)
XCTAssertEqual(try JSONDecoder().decode(AgentCommand.self, from: JSONEncoder().encode(command)), command)
```

Test each MCP definition for `additionalProperties: false`, integer revision,
per-array `maxItems`, summed operation limits at limit−1/limit/limit+1, bounded
nested fields, optional arrays meaning empty/no-op, empty-operation rejection,
and exact tool-to-command JSON. Test the precise sorted-key encoded command at
65,535/65,536/65,537 bytes; stale revision for plan and lifecycle; incomplete
finalization; current-revision-but-Draft rejection for both allowed lifecycle
transitions with zero side effects followed by re-finalize/success;
coupled-transition denial; MCP owner-acceptance denial;
owner-app-origin acceptance success; replay; changed-body request-ID reuse;
`outcomeUnknown` recovery only by replaying the entire original request; and
transactional rollback with no audit/request receipt/assignment-event row.

- [ ] **Step 3: Run RED bridge tests**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task3-red -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests
```

Expected: failure because the new command cases/tools do not exist.

- [ ] **Step 4: Add exact command cases and typed results**

Add:

```swift
case applyPhasePlanRevision(
    phaseID: String,
    expectedRevision: Int64,
    goalUpserts: [DeliveryGoalDraft],
    assignments: [DeliveryGoalAssignment],
    unassignedTicketIDs: [TicketID],
    supersededGoalIDs: [DeliveryGoalID]
)
case finalizePhasePlan(phaseID: String, expectedRevision: Int64)
case transitionDeliveryGoal(
    phaseID: String,
    goalID: String,
    expectedPlanRevision: Int64,
    lifecycle: DeliveryGoalLifecycle
)
```

Add domain errors carrying actionable data, including
`planRevisionConflict(expected:found:)`,
`phasePlanIncomplete(PhasePlanReadinessFailure)`,
`phasePlanNotReady(state:revision:)`, `ticketGoalRequired`,
`goalPhaseMismatch`, `goalNotActionable`, `invalidGoalTransition`, and
`ownerApprovalRequired`, and `archiveVersionCannotRepresentDeliveryGoals`. Add
`phasePlanRevision: Int64? = nil` to `AgentCommandResult` with backward-
compatible decoding.

- [ ] **Step 5: Dispatch through the Task 2 policy in one transaction**

Validate summed operation counts and encoded command bytes before opening the
store transaction. Use `.phasePlan` audit scope for revision/finalization and
pass the store-owned audit ID into `applyRevision`, which writes the deferred
per-ticket assignment-event links. Use `.deliveryGoal` for lifecycle and pass
the non-spoofable dispatcher `origin` plus `phaseID`/expected revision into the
policy. External MCP dispatch may request only Awaiting acceptance; the
owner-app origin may accept. Query and return the committed revision. Preserve
the existing canonical request body, request receipt, replay, deadline,
authorization, and audit transaction.

- [ ] **Step 6: Add exact MCP schemas and translators**

Use array/object JSON Schemas with `maxItems` and bounded strings. Parse exact
integers through `ReleaseRadarBridgeTransport.exactJSONInteger`; parse missing
operation arrays as `[]`; never interpret omission as deletion. Keep existing
tool names and schemas unchanged. The transition tool's lifecycle schema
allows only `awaiting_acceptance`; `accepted` is deliberately absent because it
is an owner-app-only command origin.

- [ ] **Step 7: Run bridge and packaged-helper tests GREEN**

Repeat Step 3 with `/tmp/release-radar-rr-r10-task3-green`, then run:

```bash
xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task3-build
```

Expected: tests and build pass; packaged helper lists all old tools plus exactly
the three new tools and still fails closed when the app is unavailable.

- [ ] **Step 8: Independent gate, ledger update, commit, and remote verification**

Require all six independent disciplines, including Security/Privacy for bridge
and request-boundary changes. Record the exact installed-helper digest only at
the later installed gate; do not install or mutate owner data in this task.
After GO with Required 0, stage only Task 3 paths, inspect the staged diff,
commit and push the fully verified task, and verify exact local/remote SHA
equality before Task 4 opens.

---

### Task 4: Present Delivery Goals and non-mutating phase browsing

**Files:**
- Create: `ReleaseRadar/Projects/PhaseBoardPlanningControls.swift`
- Modify: `ReleaseRadar/Projects/DashboardProjection.swift`
- Modify: `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modify: `ReleaseRadar/Projects/ActivePhaseSelector.swift`
- Modify: `ReleaseRadar/Projects/TicketDetailView.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Navigation/SidebarView.swift`
- Modify: `ReleaseRadar/Activity/ProjectActivityProjection.swift`
- Modify: `ReleaseRadar/Review/ReviewInboxProjection.swift`
- Modify: `ReleaseRadar/Review/NeedsReviewView.swift`
- Modify: `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Modify: `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`
- Modify: `ReleaseRadarUITests/ReleaseRadarUITests.swift`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4-phase-board-experience-brief.md`

**Interfaces:**
- Consumes v11 tables and existing active-phase selection callbacks.
- Produces `PhaseBoardKey`, `PhasePlanProjection`, `DeliveryGoalSummaryProjection`, `TicketDeliveryGoalProjection`, `DeliveryGoalAcceptanceReviewProjection`, `DashboardProjection.board(for:phaseID:)`, `AppModel.viewPhase(projectID:phaseID:)`, and `AppModel.acceptDeliveryGoal(projectID:phaseID:goalID:expectedPlanRevision:)`.
- Preserves `DashboardProjection.board(for:)` as the active-board accessor for Overview and existing callers.

- [ ] **Step 1: Persist/register the Task 4 brief and visual checkpoints**

Have a fresh independent Planning agent name
`docs/design/mockups/phase_board.png` and
`docs/design/release-radar-delivery-goals-phase-board-design.md` as controlling
references. Define wide and compact sizes, accessibility identifiers, viewed/
active copy, focus behavior, filters, Legacy/Draft/Ready states, store/refresh/
revision failure, and screenshot evidence paths under `docs/delivery/evidence/`.
Architecture, TPM, QA/Test, and Delivery Management must return GO with
Required 0 on that exact brief before Step 2 begins; Security/Privacy must also
confirm the observed-goal authority separation.

- [ ] **Step 2: Write RED all-phase projection tests**

Seed active Post-MVP and non-active RR-ROADMAP phases, then assert:

```swift
let projection = try await DashboardProjection.load(from: store)
let active = try XCTUnwrap(projection.board(for: projectID))
let roadmap = try XCTUnwrap(projection.board(for: projectID, phaseID: roadmapPhaseID))
XCTAssertEqual(active.phaseID, postMVPPhaseID)
XCTAssertEqual(roadmap.phasePlan.state, .ready)
XCTAssertEqual(roadmap.phasePlan.coveredUpcomingCount, 11)
XCTAssertEqual(roadmap.phasePlan.unassignedUpcomingCount, 0)
XCTAssertEqual(Set(roadmap.deliveryGoals.flatMap(\.ticketIDs)), Set(roadmap.lanes.flatMap(\.cards).map(\.id)))
```

Assert the ticket inspector has separate `deliveryGoal` and
`codexExecutionGoal`; an observed goal can be absent/present independently of a
Delivery Goal; filters preserve lane identities and counts for their filtered
set; Legacy/Draft report exact unassigned counts; accepted history is excluded
from unassigned; an initially empty phase cannot be Ready; and a previously
Ready phase whose assigned tickets are all Accepted projects
`isDeliveryComplete == true`, zero upcoming, and zero unassigned without losing
its Ready revision.

Assert assignment-event rows make the exact structural revision/audit visible
from every assigned, unassigned, or reassigned ticket. Entering Awaiting
acceptance projects exactly one stable Needs Review item; replay does not
duplicate it; leaving/accepting removes it; and a failed transition creates no
owner-attention, assignment-event, audit, or request-receipt row.

- [ ] **Step 3: Write RED AppModel/UI behavior tests**

Assert `viewPhase` changes `viewedPhaseID` and selected ticket but leaves the
database `project_active_phases` row and active-phase audit count unchanged.
Assert `Make active phase` still uses the existing owner command and recovery.
Add UI assertions for identifiers:

```swift
XCTAssertTrue(app.popUpButtons["viewed-phase-selector"].exists)
XCTAssertTrue(app.staticTexts["phase-plan-summary"].exists)
XCTAssertTrue(app.popUpButtons["delivery-goal-filter"].exists)
XCTAssertTrue(app.staticTexts["ticket-delivery-goal"].exists)
XCTAssertTrue(app.staticTexts["ticket-codex-execution-goal"].exists)
```

Also test compact wrapping, keyboard order, filtered-selection focus recovery,
saved-needs-refresh messaging, store unavailable, observation unavailable,
actual accessibility values for Legacy/Draft/Ready/completed/error states, and
the owner-only Delivery Goal Accept action. Dispatching that action must use
`.ownerApp`; an otherwise identical external dispatch must fail with
`ownerApprovalRequired` and no mutation.

- [ ] **Step 4: Run projection/app tests and confirm RED**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task4-red -only-testing:ReleaseRadarTests/DashboardProjectionTests -only-testing:ReleaseRadarTests/AppRouteTests -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests -only-testing:ReleaseRadarUITests
```

Expected: compilation/test failure because the new projections and view method
do not exist.

- [ ] **Step 5: Load all phase boards while preserving active-board callers**

Introduce:

```swift
struct PhaseBoardKey: Hashable, Sendable {
    let projectID: ProjectID
    let phaseID: PhaseID
}

struct PhasePlanProjection: Equatable, Sendable {
    let state: PhasePlanState
    let revision: Int64
    let coveredUpcomingCount: Int
    let unassignedUpcomingCount: Int
    let isDeliveryComplete: Bool
}
```

Change internal board storage to `[PhaseBoardKey: PhaseBoardProjection]`.
`board(for:)` resolves the project's active phase; `board(for:phaseID:)` reads
the exact phase. Project Overview/current-work/attention counts continue to use
only the active board.

- [ ] **Step 6: Add unambiguous goal projections and Activity language**

Rename ticket `goalContext` to `codexExecutionGoal`; add a separate optional
`deliveryGoal` containing ID, title, outcome, lifecycle, and criteria. Do not
rename or rewrite persisted observed-goal data. Map `.phasePlan` audits to
`Phase plan updated` and `.deliveryGoal` audits to `Delivery Goal updated` in
Activity; retain reason, attribution, and timestamps. Join
`delivery_goal_assignment_events` so ticket detail and ticket-filtered Activity
show the exact bulk revision audit that assigned, unassigned, or reassigned
that ticket without fabricating duplicate top-level audits.

- [ ] **Step 7: Add viewed-phase state without active mutation**

In `AppModel`, add private `[ProjectID: PhaseID]` viewed selections and:

```swift
func viewedPhaseID(for projectID: ProjectID) -> PhaseID? {
    viewedPhaseIDs[projectID] ?? dashboard?.projects.first { $0.id == projectID }?.activePhaseID
}

func viewPhase(projectID: ProjectID, phaseID: PhaseID) async {
    guard dashboard?.board(for: projectID, phaseID: phaseID) != nil else { return }
    viewedPhaseIDs[projectID] = phaseID
    synchronizeSelectionAndDependencyGraph(projectID: projectID, phaseID: phaseID)
}
```

Do not call `setActivePhase`, dispatch an agent command, write SQLite, or create
an audit from `viewPhase`. After a successful active-phase mutation, preserve
the explicitly viewed phase unless it no longer exists.

- [ ] **Step 8: Implement the planning controls and inspector**

Create `PhaseBoardPlanningControls` with a Viewed phase Picker, active-phase
label, conditional `Make active phase` button, plan summary, Delivery Goal
filter, and Show unassigned toggle. Extract the existing active-phase status
recovery view for reuse without changing Overview's Active phase Picker.
Filter cards in place within their existing lanes. Replace generic `Goal
context` with separate `Delivery Goal` and `Codex execution goal` sections.
Project Awaiting-acceptance goals into the existing Needs Review inbox with a
stable `delivery-goal:<project>:<phase>:<goal>:<revision>` identity. Its Accept
button calls `AppModel.acceptDeliveryGoal`, which constructs the revision-aware
command and dispatches only with `.ownerApp`; do not expose this action on the
Phase Board or through MCP.

- [ ] **Step 9: Run focused projection/app/UI tests GREEN**

Run Step 4 using `/tmp/release-radar-rr-r10-task4-green`, then:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task4-ui -only-testing:ReleaseRadarUITests
```

Expected: all selected tests pass with no active-phase mutation from browsing.

- [ ] **Step 10: Compare running UI, pass the independent gate, commit, and verify the remote**

Build and launch an isolated alternate-bundle test artifact, inspect via
accessibility plus screenshots at wide and compact sizes, and compare with the
approved references. Do not launch an owner-data bundle from a test fixture.
Exercise actual keyboard traversal in the specified order, VoiceOver values,
filter exclusion announcement/focus recovery, completed Ready presentation,
all Legacy/Draft/Ready/load/recovery states, and the owner-only Needs Review
acceptance action rather than accepting identifier existence alone.
Require Code Review, QA/Test, Architecture, TPM, and Delivery Management GO;
Security/Privacy verifies that observed-goal data remains separate and no new
authority exists. After all required reviews return GO with Required 0, stage
only Task 4 paths, inspect the staged diff, commit and push the fully verified
task, and verify exact local/remote SHA equality before Task 5 opens.

---

### Task 5: Prove full integration and installed-state repair

**Files:**
- Modify: `ReleaseRadarTests/EndToEndAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- Modify: `docs/delivery/progress.md`
- Create: `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-5-integration-repair-brief.md`

**Interfaces:**
- Consumes every Task 1-4 interface and the installed three-tool MCP surface.
- Produces no new product abstraction. Produces exact accepted integration and repair evidence.

- [ ] **Step 1: Persist/register the Task 5 brief and repair manifest**

Have a fresh independent Planning agent include exact IDs, outcome text, done
criteria, ticket assignments, expected
lane/dependency/blocker sets, a captured-not-hardcoded active phase, observed-goal snapshots, original
request IDs, replay steps, relaunch readback, rollback boundary, owner-data
backup/recovery procedure, and Pushover non-duplication expectation. The brief
must explicitly forbid changing any Accepted ticket and include the governed
RR-R10 lifecycle sequence after the repair reaches Ready.
Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy must
return GO with Required 0 on that exact brief before Step 2 begins.

- [ ] **Step 2: Write end-to-end and notification-preservation acceptance tests**

Create an isolated v10 fixture containing accepted RR-R1 through RR-R9,
blocked RR-R10, and the 11-ticket roadmap. Drive only the public dispatcher and
projection APIs. Assert the bootstrap creates `RR-DG-R10` assigned only to
RR-R10, leaves its migration continuation flag false, and finalizes Post-MVP
with RR-DG-R10 Planned without assigning accepted history. Apply the six
catalog goals and assert exact sets:

```swift
let expected: [DeliveryGoalID: Set<TicketID>] = [
    .init(rawValue: "RR-DG1"): [
        .init(rawValue: "RR-RM1"),
        .init(rawValue: "RR-RM2"),
        .init(rawValue: "RR-RM10"),
    ],
    .init(rawValue: "RR-DG2"): [
        .init(rawValue: "RR-RM5"),
        .init(rawValue: "RR-RM6"),
    ],
    .init(rawValue: "RR-DG3"): [.init(rawValue: "RR-RM7")],
    .init(rawValue: "RR-DG4"): [
        .init(rawValue: "RR-RM3"),
        .init(rawValue: "RR-RM4"),
        .init(rawValue: "RR-RM9"),
    ],
    .init(rawValue: "RR-DG5"): [.init(rawValue: "RR-RM8")],
    .init(rawValue: "RR-DG6"): [.init(rawValue: "RR-RM11")],
]
XCTAssertEqual(actualAssignments, expected)
XCTAssertEqual(Set(actualAssignments.values.flatMap { $0 }).count, 11)
```

Compare all seven expected Delivery Goal records (`RR-DG-R10` plus RR-DG1…6)
field-for-field against the approved catalog: ID, project/phase, title, complete
outcome, ordered criteria, sort order, and Planned post-finalize lifecycle.
Assert lane counts `8/0/0/3/0`, the active phase equals the fixture's captured
pre-repair active phase, dependencies/blockers/outcomes are unchanged, RR-R1
through RR-R9 remain Accepted, RR-R10 remains Blocked, observed goals and
ticket-goal links are byte-semantic equals, replay adds no rows/audits/review
items/assignment events, and Delivery Goal changes produce no Codex-blocked
notification.

- [ ] **Step 3: Run the integration acceptance tests**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task5-red -only-testing:ReleaseRadarTests/EndToEndAcceptanceTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests
```

Because Tasks 1–4 are already integrated, an immediate pass is valid acceptance
evidence. If a test exposes a defect, preserve that single failing case as RED,
fix only its owning boundary, and rerun it GREEN before the selection.

- [ ] **Step 4: Close only integration defects in existing Task 1-4 files**

Fix failures at their owning boundary. Do not add a repair framework, test-only
production API, archive v2, general goal editor, new lane, or ticket reopen path.
For every fix, rerun the single failing test RED/GREEN before the full Step 3
selection.

- [ ] **Step 5: Run the full relevant automated suite and build**

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task5-green
./script/build_and_run.sh --stage-release-no-launch
```

Expected: the complete scheme passes, including UI, observer, plugin lifecycle,
transport, onboarding, notification, migration-history, and failure/recovery
suites. Before running it, verify the existing UI/test-host launch contract
uses the isolated test database/app-group path and cannot open or migrate owner
data. The repository-native command builds, signs, verifies, and stages the
Release bundle without stopping or launching the owner app and without opening
owner data. Record staged app/helper hashes and strict/deep signing evidence;
only previously classified unrelated warnings may remain.

- [ ] **Step 6: Independent pre-install gate**

Require Code Review, QA/Test, Architecture, Security/Privacy, TPM, and Delivery
Management GO with Required 0 against the exact candidate hashes. Do not touch
owner data until this gate explicitly releases the installed repair.

- [ ] **Step 7: Install and verify the signed product**

Before replacement, capture the exact current active phase, RR-R1…RR-R10 lanes,
all roadmap lanes/outcomes/dependencies/blockers, observed goals/links, and
notification counts through running UI/typed read surfaces. Preserve the
accepted owner-data backup/recovery point. Install with
`./script/build_and_run.sh --install-staged-release-no-launch`, verify strict
deep code signing and exact staged/installed hashes, then launch the normal
owner bundle. Read schema/Phase Board state only through app and typed MCP/UI
surfaces; do not open SQLite directly. Record app/helper digests and process
identities.

- [ ] **Step 8: Apply the one-time audited repair through typed MCP commands**

Retain each full original request and UUID. Apply `RR-DG-R10`, its RR-R10
assignment, and Post-MVP finalization. Then apply the six exact RR-DG1…RR-DG6
records and assignments and finalize RR-ROADMAP. Do not resolve, transition,
reopen, or otherwise change any ticket during this repair.

- [ ] **Step 9: Replay, relaunch, and verify exact state**

Replay every original request verbatim; confirm the same audit results with no
additional mutation. Quit/relaunch normally. Verify via running UI: the active
phase exactly equals the pre-install snapshot; RR-R1…RR-R9 are still Accepted;
RR-R10 is still Blocked with its existing design-approval blocker;
RR-ROADMAP counts are 8/0/0/3/0; all seven goal records match exact IDs,
ownership, titles, outcomes, ordered criteria, sort order, assignment sets, and
Planned lifecycles; both plans are Ready; roadmap coverage is 11/11 with zero
unassigned; dependencies/blockers/outcomes and observed execution state are
unchanged; Delivery Goal and Codex execution goal headings are distinct; and
there is no duplicate notification.

- [ ] **Step 10: Final independent gate and move RR-R10 to Needs review**

Independent QA repeats installed readback; Architecture and Security/Privacy
confirm boundaries; Code Review checks the final diff; TPM and Delivery
Management confirm every acceptance criterion and no ticket reopen. With
Required 0, resolve `RR-R10-BLOCKER-DESIGN-APPROVAL`, transition RR-R10 through
Blocked→In progress (which atomically moves RR-DG-R10 Planned→Active), record
the completion/review evidence, and transition RR-R10 to Needs review. Verify
that exact sequence and present the complete installed result to the owner.

- [ ] **Step 11: Record explicit owner acceptance and close formal delivery state**

Wait for explicit RR-R10 outcome acceptance. That approval authorizes the
typed Needs review→Accepted transition for RR-R10; it does not reopen or modify
RR-R1…RR-R9. Then request RR-DG-R10 Active→Awaiting acceptance with its current
expected plan revision. Have the owner use the installed Needs Review Accept
action, which dispatches Awaiting acceptance→Accepted with `.ownerApp` origin.
Verify RR-R10 Accepted, RR-DG-R10 Accepted, the Post-MVP plan still Ready at the
same revision with `delivery complete · 0 upcoming · 0 unassigned`, one owner-
acceptance audit, closed owner attention, and no Accepted ticket reopening.
Keep the persistent Codex goal active until Task 6 finishes commit/push/remote
verification.

- [ ] **Step 12: Commit, push, and remotely verify the accepted Task 5 delivery**

After owner acceptance and exact Accepted-state readback, update the ledger,
stage only Task 5 paths, inspect the staged diff, commit and push the fully
verified accepted task, and verify exact local/remote SHA equality. Keep the
persistent Codex goal active for Task 6's terminal evidence reconciliation.

---

### Task 6: Terminal evidence reconciliation, status commit, and goal completion

**Files:**
- Modify: `docs/delivery/progress.md`

**Interfaces:**
- Consumes explicit owner acceptance plus Accepted RR-R10/RR-DG-R10 state from Task 5.
- Consumes the exact pushed SHA for the approved planning package and every fully verified Task 1–5 commit.
- Produces one terminal status-only ledger commit on `codex/release-radar-mvp`, pushed to `origin`, with exact local/remote SHA verification before the persistent goal is completed.

- [ ] **Step 1: Confirm the terminal gate**

Do not proceed unless Task 5 records Required 0 across every independent role,
installed evidence is accepted, the owner explicitly accepts RR-R10, and no
product work remains. Verify each approved planning/task commit is present on
the remote and `default.profraw` remains untracked and untouched.

- [ ] **Step 2: Record terminal delivery evidence in the ledger**

Update `docs/delivery/progress.md` with implementation, focused/full tests,
installed build/sign/launch/relaunch evidence, exact repair/replay/audit results,
six-goal set equality, no-reopen proof, reviews, owner acceptance, remaining
risks, and every exact planning/task commit plus remote SHA.

- [ ] **Step 3: Run final source and repository checks**

```bash
git diff --check
git status --short --branch
```

Rerun the Task 5 relevant suite if any product source changed after its accepted
run. Inspect the remaining diff and confirm it contains only the terminal
ledger update.

- [ ] **Step 4: Stage only exact RR-R10 paths**

Use an explicit `git add docs/delivery/progress.md`. Never use `git add .`,
`git add -A`, or a glob. Confirm `git diff --cached --name-status` contains
only the reviewed terminal ledger update.

- [ ] **Step 5: Create the terminal status-only commit**

```bash
git commit -m "docs: record accepted RR-R10 delivery"
```

Expected: one status-only commit recording the complete accepted RR-R10 goal
and its already-pushed task SHAs. Record its SHA. Do not amend earlier history.

- [ ] **Step 6: Push and verify the remote exactly**

```bash
git push origin codex/release-radar-mvp
git rev-parse HEAD
git ls-remote origin refs/heads/codex/release-radar-mvp
git status --short --branch
```

Expected: local HEAD equals the remote branch SHA, upstream ahead/behind is
0/0, only the unrelated `default.profraw` remains untracked, and no RR-R10 file
is dirty.

- [ ] **Step 7: Record remote evidence and complete the persistent goal**

Record the terminal status commit/push/remote evidence in Release Radar using the
approved typed evidence path without changing any ticket or Delivery Goal
state; Task 5 already closed RR-R10 and RR-DG-R10 through their valid lifecycle.
Read back the evidence, exact remote SHA, and unchanged Accepted state. Mark the
persistent Codex goal complete only after remote verification and no required
work remains.

## Plan Completion Check

- Every spec requirement maps to Tasks 1-5; each verified task is committed and remotely verified before the next opens, and terminal evidence reconciliation maps to Task 6.
- Every new type and method used by a later task is declared in an earlier `Interfaces` block.
- All ticket writer paths found in shipping/debug source are routed through Task 2 policy.
- Portable archive v1 is guarded without implementing archive v2 or the roadmap exporter/importer.
- Viewed-phase browsing remains separate from active-phase mutation.
- Accepted tickets are terminal in schema/policy tests, bridge tests, end-to-end tests, installed repair, and terminal tracking.
- No partial or unverified task is committed or pushed; the approved planning package and each fully verified task have an exact remote checkpoint.
