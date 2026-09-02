# RR-R10 Delivery Goals and Roadmap Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver first-class per-ticket Tasks and phase-scoped Delivery Goals, enforce exact ticket-task completion plus ready-phase coverage through app-owned authority, present both without conflating Codex execution goals, and repair RR-R10 plus the complete Established product roadmap without reopening any Accepted ticket.

**Architecture:** Build on the delivered v11 Delivery Goal foundation, v12 ticket-task model/policy/acceptance gate, and v13 managed documentation contract. Preserve their independent revisions and app-owned authority. Route task plans, Delivery Goals, and every ticket writer through store-owned policies and the existing audited/idempotent command path; project canonical tasks and phase plans into the five-lane SwiftUI board; finish with typed, replay-safe installed bootstraps and exact state-preservation proof.

**Tech Stack:** Swift 6, SwiftUI, Observation, SQLite3, XCTest, macOS 14+, Xcode project file-system-synchronized groups, existing XPC/MCP bridge.

**Specs:** `docs/design/2026-08-29-delivery-goals-roadmap-readiness-design.md` and `docs/design/release-radar-ticket-tasks-design.md`

**Package status:** owner-authorized post-MDCP plan, updated 2026-09-02. Tasks 1A/1B/2A/2B/3/4A and MDCP are delivered; Task 4B implementation and acceptance are complete with PR delivery in progress. Current authorization and the next eligible task are recorded in `docs/delivery/progress.md`; this plan alone does not authorize feature execution or owner-state changes.

## Global Constraints

- The governing ticket is `RR-R10` in `release-radar-post-mvp-remediation`.
- Delivery chunks are review checkpoints under the complete RR-R10 outcome; no chunk is a reduced feature commitment.
- Keep exactly five persisted lanes: Backlog, In progress, Needs review, Blocked, Accepted.
- Accepted tickets are terminal and are never reopened. Rework and later defects create new Backlog tickets.
- Delivery Goals are app-owned phase-plan records; `observed_goals` and `ticket_goal_links` remain Codex execution context with unchanged semantics.
- Release Radar's app process remains the only SQLite writer. The helper and bridge use typed commands only.
- Store migration is additive v10 to v11 and never infers Delivery Goals or assignments.
- The accepted Task 1A schema-v10 fixture and Task 1B schema-v11 persistence/model contract are complete, immutable dependency boundaries. Do not reopen, rename, or semantically rewrite them.
- Schema v12 is additive to v11, creates zero task plans/tasks, and never rewrites the accepted v11 definitions.
- Atomic tickets may have no task plan. Once a plan exists it cannot be deleted or have zero active tasks; all active tasks must be completed before the exact-revision Accepted transition.
- Task machine IDs and visible labels are stable; task rows are never hard-deleted; completed history never returns to pending; superseded history remains durable but is excluded from the visible list, card count, and acceptance gate.
- Core and MCP enforce encoded UTF-8 maxima of 256 bytes for task machine IDs, 256 bytes for visible labels, and 4,096 bytes for titles; no truncation or character-count substitution is permitted.
- Schema v12 parent foreign keys and triggers reject ticket/project deletion or cascade attempts that would erase task-plan or task history.
- Task-only mutations never change phase-plan state or revision. Ticket outcome/phase and Delivery Goal structural changes retain ADR-004 invalidation semantics.
- A Ticket Details task row is read-only `[checked/unchecked] [label]: [verb-led title]`. Cards show only a neutral active-task count. No completion aggregate, percentage, progress bar, or persisted level of effort exists.
- New and phase-moved tickets enter Backlog. Backlog and Blocked cannot bypass Ready plus exact-assignment validation.
- Existing v10 In progress and Needs review tickets receive the only legacy continuation; existing Blocked tickets do not.
- The early schema-v10 Blocked-to-In-progress handoff and migration are completed history. Future installs start from the existing managed v13 store and preserve the migration-granted continuation until explicit Delivery Goal adoption. Fresh authorized readback establishes the live baseline; do not repeat the historical handoff.
- Plan revisions allow at most 64 total goal operations (`goalUpserts + supersededGoalIDs`), 512 total assignment operations (`assignments + unassignedTicketIDs`), and 65,536 bytes for the sorted-key JSON encoding of the `AgentCommand` value before it is placed in the XPC envelope. Validate limit−1, limit, and limit+1 at the command boundary.
- A viewed phase is navigation-only. Existing active-phase mutation remains separate and governed by ADR-003.
- Current production import creates no task plans, and no production portable exporter/exportability call path exists. RR-R10 adds no export guard or archive v2. Future RM5 owns exporter/archive-format work and must represent Delivery Goals and ticket tasks or fail before emission; RM6 import accepts only complete supported exporter output or rejects it.
- Deliver each completed, directly verified and independently reviewed slice with a normal fast-forward push and verify the resulting remote commit. Keep exact live task revisions/audits in the ledger. Do not repeat Git-state gates around intermediate actions or commit partial/unverified implementation.
- After each live completion of Task 7A, 8, 9, 10, or 11A, the exact returned task-plan revision/audit must be durably recorded, committed/pushed, and remote-verified no later than the next task brief/release; the next task cannot open first. Task 11B's final row is recorded by terminal reconciliation, and repair rows are reconciled before their parent resumes. These records create no task row or framework.
- Before coding begins, the task brief must split any task forecast to exceed roughly eight hours of agent implementation work, or whose diff would be too large for one coherent review, into smaller dependency-safe tasks. Each resulting task must still deliver a complete testable slice, pass its own independent gate, and receive its own commit/push/remote checkpoint.
- Preserve the unrelated untracked `default.profraw` file untouched.
- Apply `AGENTS.md` and ADR-007 to unopened work: a concise brief where risk requires it, direct behavior checks, and an independent reviewer with the applicable Architecture, Security/Privacy, UX or TPM coverage. Delivery Management records the outcome. Mutable plans/briefs are not checksummed, and successful checks/reviews are terminal unless they identify a concrete defect. Preserve explicit owner UI/live-action acceptance gates.

## Post-MDCP execution baseline

These shared conditions apply to Tasks 4B–11B and final closure.

- The accepted application baseline is `MDCP-COMPAT-2` (`b365aff`), app/plugin
  0.1.6, schema v13, guidance v2 and catalog v1. Later candidates retain that
  behavior while adding RR-R10 functionality. Historical v10/v11/v12 fixtures
  and migration definitions remain valid immutable dependencies.
- Preserve all 19 existing tools, including six MDCP tools. Task 4B adds two
  (21 total); Task 8 adds three (24 total). Preserve existing tool schemas,
  `AgentCommandResult.inventory`, the distinct read-only query route and old
  encoded results. Ordinary commands retain canonical JSON receipts; managed
  commands retain digest receipts and their authorized exact-replay path.
- Development tests must isolate the broker/service as well as SQLite and
  ordinary app startup. Whole transport/lifecycle classes can register,
  connect to or unregister the fixed macOS service. Use focused in-process and
  stdio-only selections during development. Packaged broker tests and full
  scheme runs require an isolated macOS service/session environment or
  separately authorized quiescence and restoration; a temporary database or
  DerivedData path alone is insufficient. Do not omit required transport
  acceptance: identify the controlled execution path in the applicable brief.
- Task 7 retains bookmark access, bound-root/accepted-catalog validation and
  evidence resolution inside the importer's existing transaction before any
  delivery write. Keep managed artifact IDs and arbitrary legacy locators.
  Tasks 5/9/10 retain authorized evidence projections, lifecycle/authority,
  availability/recovery and the existing evidence component while changing
  board/detail composition. Reuse focused MDCP regression cases.
- New briefs, archives and lifecycle changes maintain catalog metadata, local
  indexes and active references together; use the native documentation tool.
  Preserve artifact IDs and accepted historical checksum manifests. New mutable
  plans, briefs and review/progress records have no checksum requirement.
- Repository preparation stays in the managed-documentation development
  worktree. The original bound deployment checkout is a separate target.
  Prepare and validate catalog changes locally, then obtain authorization for
  the exact bound-root deployment and prior-to-candidate catalog acceptance
  before managed operations use those changes. Keep the currently deployed
  accepted tree usable meanwhile. Do not rebind to the development worktree.
  Content-only edits to mutable plans/progress do not by themselves change the
  catalog digest. Catalogued evidence uses `addManagedEvidence` with artifact
  IDs, never a direct path repair or legacy `addEvidence` workaround.

## File Structure

This inventory includes delivered foundations for context. Only the remaining
Task 4B–11B sections describe prospective changes; completed task instructions
and superseded task sections are historical, not execution gates.

### Accepted immutable foundations

- `ReleaseRadarCore/Models/DeliveryGoalModels.swift` — accepted Task 1B v11 public model contract; no Ticket Tasks edit.
- `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite` and `SHA256SUMS` — accepted Task 1A fixture/checksum; unchanged.
- The schema-v11 SQL, manifest objects, and Task 1B tests in `ReleaseRadarCore/Store/StoreMigrations.swift`, `ReleaseRadarCore/Store/DeliveryStore.swift`, and `ReleaseRadarTests/StoreAcceptanceTests.swift` remain semantically immutable while receiving additive v12 content.
- `ReleaseRadarCore/Import/DeliveryArtifactImporter.swift` — unchanged import-only boundary; current import creates no task plans, and no production exporter/exportability path exists.

### New production files

- `ReleaseRadarCore/Models/TicketTaskModels.swift` — task-plan IDs, states, revision operations, and records shared across Core and app.
- `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift` — the sole task-plan definition/completion/supersession authority and the exact-revision task gate composed by every Accepted transition.
- `ReleaseRadarCore/Planning/DeliveryPlanningPolicy.swift` — the sole SQL-writing policy for phase creation, phase plans, Delivery Goals, assignments, goal lifecycle, ticket creation/movement/lane transitions, and migration-granted continuation enforcement; its Accepted path delegates to the Ticket Task gate.
- `ReleaseRadar/Projects/PhaseBoardPlanningControls.swift` — viewed-phase, active-phase action, plan summary, goal filters, status, and accessibility presentation.

The Xcode project uses file-system-synchronized groups, so these files require no `project.pbxproj` membership edit.

### Modified production files

- `ReleaseRadarCore/Store/StoreMigrations.swift` — additive schema v12 task tables/indexes/triggers/manifest; accepted v11 definitions unchanged.
- `ReleaseRadarCore/Store/DeliveryStore.swift` — additive task-plan audit entity type; existing v11 and observed-goal types unchanged.
- `ReleaseRadarCore/AgentBridge/AgentCommand.swift` — Task 4A extends only the existing ticket transition with optional exact task-plan revision while upsert retains no such field; Task 4B adds bounded task-plan commands/results; later work adds Delivery Goal commands.
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift` — Task 4A rejects Accepted upsert create/update and routes every existing transition to Accepted through the task gate; Task 4B adds audited task-plan revision/replay/concurrency; later work adds Delivery Goal/ticket-writer routing.
- `ReleaseRadarAgentTools/main.swift` — Task 4A updates only the existing transition translator/schema for exact planned acceptance; Task 4B exposes the two new task-plan mutation tools; later work adds Delivery Goal tools.
- `ReleaseRadarCore/Import/RekonArtifactImporter.swift` — Legacy-unassessed phase creation, Backlog-only ticket creation, and source-lane review facts.
- `ReleaseRadar/Projects/DashboardSampleData.swift` — valid sample plan creation before governed lane transitions.
- `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` — valid capture plan creation before governed lane transitions under `#if DEBUG`.
- `ReleaseRadar/Projects/DashboardProjection.swift` — tri-state ticket tasks, shared card/detail task rows, then all-phase Delivery Goal coverage and filtering.
- `ReleaseRadar/Projects/TicketCardView.swift` — neutral canonical active-task count with existing dependency/blocker metadata.
- `ReleaseRadar/Projects/PhaseBoardView.swift` — pass its existing reload callback into Task 5's unavailable Tasks treatment, then add planning controls and the filtered five-lane board in Task 10.
- `ReleaseRadar/Projects/ActivePhaseSelector.swift` — extract reusable active-phase mutation status presentation; keep Overview behavior unchanged.
- `ReleaseRadar/Projects/TicketDetailView.swift` — read-only Tasks plus separate Delivery Goal and Codex execution goal sections.
- `ReleaseRadar/App/AppModel.swift` — per-project viewed-phase state and dependency/selection coherence without active-phase mutation.
- `ReleaseRadar/Navigation/SidebarView.swift` — supply the viewed board and planning-control callbacks.
- `ReleaseRadar/Activity/ProjectActivityProjection.swift` — goal/plan audit titles and phase/ticket attribution.
- `ReleaseRadar/Review/ReviewInboxProjection.swift` — derived Awaiting-acceptance owner-attention records with stable identity.
- `ReleaseRadar/Review/NeedsReviewView.swift` — owner-app-only Delivery Goal acceptance action.

### Test files

- Modify `ReleaseRadarTests/StoreAcceptanceTests.swift` — additive v11-to-v12 migration, representative v11 graph preservation, rollback, and manifest integrity.
- Create `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite` — exact empty schema-v10 database generated before v11 production code changes.
- Create `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS` — exact fixture digest.
- Create `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite` and `SHA256SUMS` — genuine accepted schema-v11 migration boundary.
- Create `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift` — task-plan invariants, revision, replay, acceptance, and rollback.
- Create `ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests.swift` — state machines, readiness, complete ticket-writer matrix, and rollback.
- Modify `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift` — Task 4A Accepted-path bypass rejection, then Task 4B task-command validation, replay, bounds, and concurrency.
- Modify `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift` — Task 4A existing-transition revision schema and Task 4B packaged task-plan tools/transport.
- Modify `ReleaseRadarTests/RekonImportAcceptanceTests.swift` — Legacy phase state, Backlog coercion, and source-lane review behavior.
- Modify `ReleaseRadarTests/DashboardProjectionTests.swift` — phase-plan/goal projection and exact RR-ROADMAP catalog.
- Modify `ReleaseRadarTests/AppRouteTests.swift` — non-mutating viewed phase, active-phase separation, refresh/recovery, selection coherence.
- Modify `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift` — Activity attribution and dependency preservation.
- Modify `ReleaseRadarTests/EndToEndAcceptanceTests.swift` — v12 task/acceptance, Task 7A live bootstrap/replay, Delivery Goal integration, and final installed verification.
- Modify `ReleaseRadarTests/NotificationAcceptanceTests.swift` and `OnboardingAcceptanceTests.swift` — acceptance side effects, import preservation, and installed critical paths.
- Modify `ReleaseRadarUITests/ReleaseRadarUITests.swift` — task card/detail tri-state and accessibility, then Delivery Goal controls/filters/inspector headings.

---

### Task 1: Add the v11 persistence foundation

**Completed historical instructions:** Tasks 1A/1B are delivered. Preserve their artifacts; do not repeat this section.

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
attachment whose Xcode-suggested name matches
`release-radar-v10_0_<uppercase UUID>.sqlite`, reject unsafe exported names,
and copy those bytes from the result bundle to the still-absent repository
fixture path. Verify the fixture directly reports schema 10 and contains no v11
table, column, index, or trigger, then write its SHA-256 to
`ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`. The fixture and digest are
durable test inputs; the removed generator, result bundle, and attachment export
are temporary evidence, not deliverables.

For the current Task 1A execution, the generator and attachment export have
already each completed once. Resume only from their preserved passing result
and exported bytes after the corrected manifest-name contract is independently
approved and remotely checkpointed; do not rerun either operation.
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

### Superseded unopened Task 2: Implement the store-owned plan and ticket policy

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

### Superseded unopened Task 3: Expose audited, bounded Delivery Goal commands

**Files:**
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarAgentTools/main.swift`
- Modify: `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Modify: `ReleaseRadar/Projects/DashboardSampleData.swift`
- Modify: `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/RekonImportAcceptanceTests.swift`
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

### Superseded unopened Task 4: Present Delivery Goals and non-mutating phase browsing

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

### Superseded unopened Task 5: Prove full integration and installed-state repair

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

### Superseded unopened Task 6: Terminal evidence reconciliation, status commit, and goal completion

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

## Historical plan completion check (superseded)

- Every spec requirement maps to Tasks 1-5; each verified task is committed and remotely verified before the next opens, and terminal evidence reconciliation maps to Task 6.
- Every new type and method used by a later task is declared in an earlier `Interfaces` block.
- All ticket writer paths found in shipping/debug source are routed through Task 2 policy.
- Portable archive v1 is guarded without implementing archive v2 or the roadmap exporter/importer.
- Viewed-phase browsing remains separate from active-phase mutation.
- Accepted tickets are terminal in schema/policy tests, bridge tests, end-to-end tests, installed repair, and terminal tracking.
- No partial or unverified task is committed or pushed; the approved planning package and each fully verified task have an exact remote checkpoint.

---

## 2026-08-30 Ticket Tasks course correction — accepted historical mapping

Everything under a `Superseded unopened Task` heading above is retained only
as historical planning context and has no implementation authority. No brief
was accepted and no product work began for those tasks. Task 1A and Task 1B
remain accepted exactly as delivered; their checked state, labels, titles,
fixture/checksum, schema-v11 definitions, commit history, and semantics are not
reopened by this correction. Any preserved Task 1 text that says the next gate
is `Task 2` now points only to revised Task 2A; it does not release any
superseded Task 2 work.

### Exact old-to-revised mapping

| Prior unopened task | Revised active replacement | Disposition |
| --- | --- | --- |
| Task 2 — Implement the store-owned plan and ticket policy | Tasks 6 and 7 | Split between Delivery Goal state/policy and all structural ticket-writer integration; the acceptance path now consumes the independent ticket-task revision. The older archive-helper assumption is not implemented without a real exporter boundary. |
| Task 3 — Expose audited, bounded Delivery Goal commands | Task 8 | Renumbered after the Ticket Tasks foundation; Delivery Goal command semantics remain as approved. |
| Task 4 — Present Delivery Goals and non-mutating phase browsing | Tasks 9 and 10 | Split into projection/activity/review data and running Phase Board/AppModel UI for coherent review. |
| Task 5 — Prove full integration and installed-state repair | Tasks 7A, 11A, and 11B | Task 7A installs and bootstraps live tracking after the policy/UI foundation; Tasks 11A/11B split final automated integration from installed repair/readback. |
| Task 6 — Terminal evidence reconciliation, status commit, and goal completion | Non-ticket terminal reconciliation | Retained as a repository execution step after Accepted state; it is not a task-plan row and cannot mutate the Accepted plan. |

The first Ticket Tasks course-correction draft had one unopened, planning-only
row `Task 4: Expose audited ticket-task commands` with proposed machine ID
`rr-r10-task-4`. This correction replaces it before bootstrap with Task 4A
(`rr-r10-task-4a`) for all Accepted-path safety and Task 4B
(`rr-r10-task-4b`) for external task-plan mutations. No app-owned Task 4 row or
ID was ever created, so there is no persisted history to delete or supersede;
`rr-r10-task-4` is not an alias and must never be installed or reused. Every
other previously named active row keeps its prior label, title, machine ID, and
status. Task 7A is a new owner-visible checkpoint required to make tracking live
before the remaining work; no earlier row or ID is repurposed.

### Historical exact-package acceptance and RR-R10 start handoff

**Completed history, not current entry conditions.** The following records the
original pre-Task-2A handoff, including its then-current identities and process.
Do not repeat it or apply its superseded review/hash ceremony to unopened work.
Current authorization is in `docs/delivery/progress.md`.

1. The owner explicitly accepts the exact hashes of the design, ADR, and this
   plan.
2. The coordinator records that exact acceptance in
   `docs/delivery/progress.md`.
3. Commit and push only those planning artifacts plus the coordinator-owned
   ledger record. Verify exact local/remote SHA equality and upstream ahead/
   behind `0/0`.
4. Before any mutation, use the authorized typed command path and owner UI to
   confirm the active phase and unrelated state plus RR-R10 Blocked with
   `RR-R10-BLOCKER-DESIGN-APPROVAL` present. Prove the installed application,
   helper, and running processes match the ledger-backed schema-v10 build:
   bundle `com.rekonlabs.ReleaseRadar`, version `0.1.5` build `1`, Team
   `2UA854NLX4`, CDHash `d204ccdd17628d6089694cf615b3c0a2a36195f4`, main
   SHA-256 `9f65653f28584bef118ffa692f5a0e17656b88d5b4c40f63e64864551289d384`,
   AgentTools SHA-256
   `acf00b7a7df3dca53a7af2b4cf141df902ea8869a6fd3a1700c6ff2ddbb24f31`,
   and BridgeAgent SHA-256
   `9aa8bdcfe9345c3884a733b5d5ab18f6403e1c3c29457c6860e5f06e236e8d03`.
   Running executable paths and hashes must resolve to those artifacts and
   their accepted schema-v10 manifest. Together with the Blocked readback, this
   proves the authorized early move will leave RR-R10 In progress on schema v10
   and eligible for v10→v11 migration-only continuation. Do not inspect SQLite
   directly.
5. If identity, schema eligibility, state, or authorized readback cannot be
   proven, stop before blocker/lane mutation and before Task 2A. Define a
   bounded architecture-reviewed, owner-accepted reconciliation checkpoint,
   make it remote-exact, and repeat this preflight. Do not force state or defer
   this discovery to Task 7A.
6. Through the currently valid typed audited path, resolve that blocker and
   transition RR-R10 Blocked→In progress. Read back the lane, cleared blocker,
   exact audit/receipt, and unchanged unrelated delivery state through typed/UI
   surfaces. No task plan exists yet and none is inferred.
7. A fresh Planning agent writes the complete Task 2A brief. Architecture,
   TPM, QA/Test, and Delivery Management independently review and explicitly
   release that exact brief before an Implementer writes the RED test.

Owner acceptance alone never releases Task 2A.

Tasks 2A/2B/3/4A have since been delivered. Ten feature/delivery checkpoints
remain: 4B, 5, 6, 7, 7A, 8, 9, 10, 11A and 11B. The 16 stable labels, titles,
machine IDs and ordering below are unchanged. Checked status records repository
delivery only; initial app-owned rows are all created Active/Pending at Task 7A
and completed only by explicit revisioned commands. Internal checkboxes in this
plan never become additional ticket tasks.

### Active task catalog

```text
[checked] Task 1A: Generate and verify the genuine schema-v10 fixture
[checked] Task 1B: Add schema-v11 persistence and public models
[checked] Task 2A: Generate and verify the genuine schema-v11 fixture
[checked] Task 2B: Add schema-v12 ticket-task persistence and models
[checked] Task 3: Enforce ticket-task revisions and acceptance
[checked] Task 4A: Guard every Accepted path
[unchecked] Task 4B: Expose audited ticket-task commands
[unchecked] Task 5: Present ticket tasks on cards and Ticket Details
[unchecked] Task 6: Enforce Delivery Goal plan and lifecycle rules
[unchecked] Task 7: Route every ticket writer and compose planning policy
[unchecked] Task 7A: Install and bootstrap live RR-R10 task tracking
[unchecked] Task 8: Expose audited Delivery Goal commands
[unchecked] Task 9: Project Delivery Goals, Activity, and owner review
[unchecked] Task 10: Present non-mutating phase browsing and Delivery Goals
[unchecked] Task 11A: Integrate and stage the release candidate
[unchecked] Task 11B: Install and verify the final RR-R10 outcome
```

Machine IDs, in the same order, are `rr-r10-task-1a`, `rr-r10-task-1b`,
`rr-r10-task-2a`, `rr-r10-task-2b`, `rr-r10-task-3`, `rr-r10-task-4a`,
`rr-r10-task-4b`, `rr-r10-task-5`, `rr-r10-task-6`, `rr-r10-task-7`,
`rr-r10-task-7a`, `rr-r10-task-8`, `rr-r10-task-9`, `rr-r10-task-10`,
`rr-r10-task-11a`, and `rr-r10-task-11b`. Labels, titles, IDs, and order above
are stable bootstrap values. Sixteen is the initial reviewed catalog, not a
fixed target; later accepted scope is added as a new Active/Pending row through
the live revisioned plan and never by rewriting this history.

### Checkpoint sizing forecasts

These planning forecasts size independent review checkpoints only. They are
not fields in the task model, bootstrap payload, card, Ticket Details, or any
runtime/UI contract.

| Active task | Forecast |
| --- | --- |
| Task 2A | 3–5 agent-hours |
| Task 2B | 6–8 agent-hours |
| Task 3 | 6–8 agent-hours |
| Task 4A | 6–8 agent-hours |
| Task 4B | 7–8 agent-hours |
| Task 5 | 6–8 agent-hours |
| Task 6 | 6–8 agent-hours |
| Task 7 | 7–8 agent-hours |
| Task 7A | 6–8 agent-hours |
| Task 8 | 5–7 agent-hours |
| Task 9 | 5–7 agent-hours |
| Task 10 | 7–8 agent-hours |
| Task 11A | 6–8 agent-hours |
| Task 11B | 6–8 agent-hours |

Task 7 remains one checkpoint because its single rejectable outcome is routing
every structural shipping/debug ticket writer through one shared Delivery Goal
policy while preserving Task 4A's Accepted gate; splitting writers would
knowingly commit a bypassable structural policy. Task 10 remains one
checkpoint because its files form one owner-visible Delivery Goal browsing and
acceptance surface, and its 7–8 hour forecast stays within the owner limit.
Task 7A remains one 6–8 hour checkpoint because its one rejectable outcome is
the safely installed through-Task-7 candidate plus a live, replay-proven task
plan; splitting install from bootstrap would leave owner state upgraded without
the recovery/visibility contract that authorizes that upgrade.

## Revised implementation sequence

Tasks 2A–4A below are completed historical instructions. Their original gates
are retained as delivery context and do not reopen accepted work. Task 4B implementation and acceptance are also complete; its PR checkpoint
precedes the next separately coordinated Task 5.

### Task 2A: Generate and verify the genuine schema-v11 fixture

**Files:**
- Create: `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite`
- Create: `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS`
- Temporary modify then restore: `ReleaseRadarTests/StoreAcceptanceTests.swift`

**Interfaces:** Consumes the accepted v10 fixture and exact Task 1B product
commit. Produces one privacy-empty, checksum-pinned schema-v11 database for
Task 2B; produces no product API or runtime mode.

- [ ] **RED:** Add an exact-gated XCTest attachment generator that starts from
  a checksum-verified copy of the v10 fixture, opens `DeliveryStore`, asserts
  user version 11 plus all accepted v11 manifest objects and zero planning
  rows, and prove the absent gate fails without an attachment.
- [ ] **GREEN:** Use the already-proven sandbox-safe `.xctestrun` attachment
  path, export exactly one passing attachment, remove the generator, pin its
  SHA-256, and verify zero owner rows, exact v11 objects, empty
  `foreign_key_check`, and `integrity_check = ok`.
- [ ] **Verify:** Run
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r10-task2a -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests`.
- [ ] **Gate/checkpoint:** Fresh Code Review, QA/Test, Architecture,
  Security/Privacy, TPM, and Delivery Management must return GO with Required
  0. Commit/push only the two fixture artifacts plus coordinator-owned ledger
  evidence and verify exact local/remote SHA before Task 2B.

### Task 2B: Add schema-v12 ticket-task persistence and models

**Files:**
- Create: `ReleaseRadarCore/Models/TicketTaskModels.swift`
- Modify: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Modify: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`

**Interfaces:** Produces `TicketTaskID`, `TicketTaskCompletion`,
`TicketTaskLifecycle`, `TicketTaskDraft`, `TicketTaskDefinitionRevision`,
`TicketTaskPlanRecord`, and `TicketTaskRecord`; adds `.ticketTaskPlan` audit
scope; adds manifest-validated `ticket_task_plans` and `ticket_tasks` in schema
v12. `TicketTaskDraft` carries only machine ID, label, title, and sort order;
policy creation always writes Active/Pending and accepts no completion input.
Parent foreign keys/triggers reject deletion of any ticket or project that owns
task history; no cascade can erase a task plan or task row.

- [ ] **RED:** Copy and checksum the v11 fixture, seed a representative valid
  nonempty v11 graph through raw fixture SQL, and snapshot every seeded v11
  table in primary-key order. Include two projects/phases; all five lanes;
  Delivery Goals, ordered criteria, assignments and deferred assignment-event/
  audit history; dependencies, blockers, evidence, reviews/completions;
  active-phase pointer; observed threads/goals/exact links; notifications;
  bookmarks; lifecycle singleton; and request receipts. Test exact additive
  migration, zero inferred task rows, model round trips, composite ownership,
  stable ID/label uniqueness, state/timestamp checks, immutable ID/label and
  no-delete triggers, deterministic ordering indexes, counterfeit-manifest
  rejection, direct ticket delete, project-delete cascade attempts, direct
  plan/task deletion, late-migration rollback, relaunch, and unchanged v11
  snapshot. Every rejected deletion leaves parent, plan, and task rows intact.
- [ ] **GREEN:** Set `currentVersion` to 12, apply only the two additive tables,
  indexes, composite parent restrictions, parent/no-delete triggers, and
  manifest entries, and add the public value types with explicit initializers.
  Do not alter any v11 SQL constant or the accepted SchemaV10/SchemaV11
  fixtures.
- [ ] **Verify:** Reuse that same seeded fixture copy for the deliberate late-
  migration abort, rollback/snapshot inspection, trigger removal, normal
  reopen, and second reopen; add no harness or second fixture. Run Store tests
  RED before product edits and GREEN afterward, then Store plus plugin-
  lifecycle tests from fresh DerivedData and require schema 12, zero task
  plans/tasks, empty `foreign_key_check`, and exact every-table v11 equality.
- [ ] **Gate/checkpoint:** All six independent disciplines, including storage
  Security/Privacy, return GO/Required 0. Commit/push only the registered
  model/store/test paths plus ledger evidence and verify remote equality before
  Task 3.

### Task 3: Enforce ticket-task revisions and acceptance

**Files:**
- Create: `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift`
- Create: `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift`

**Interfaces:** Produces:

```swift
TicketTaskPlanningPolicy.revisePlan(
    projectID:ticketID:expectedRevision:additions:definitionRevisions:
    supersededTaskIDs:auditEventID:connection:
) throws -> TicketTaskPlanRecord
TicketTaskPlanningPolicy.completeTask(
    projectID:ticketID:taskID:expectedRevision:connection:
) throws -> TicketTaskPlanRecord
TicketTaskPlanningPolicy.assertCanAcceptTicket(
    projectID:ticketID:expectedRevision:connection:
) throws
```

- [ ] **RED:** Prove optional no-plan tickets; create-only nil revision; exact
  creation returns revision 1; stale revision rollback; one R→R+1 increment per
  later mutation; immutable machine ID/label/completed definition; monotonic
  completion; retained superseded state;
  no deletion/reuse; 64-operation boundaries; empty-command rejection; atomic
  last-task replacement; and Accepted-plan immutability. At the Core boundary,
  test ASCII and multibyte machine IDs at 255/256/257 UTF-8 bytes, labels at
  255/256/257 bytes, and titles at 4,095/4,096/4,097 bytes; exact-limit values
  succeed and oversize values reject without truncation or effects.
- [ ] **RED:** Direct store/policy tests prove completion/lifecycle
  orthogonality: superseding pending and completed tasks preserves completion
  plus completed timestamp; completing or definition-revising a superseded task
  rejects; re-superseding rejects as a no-op. Reject the same or duplicate task
  ID within additions, revisions, or supersessions and every ID repeated across
  those arrays, with plan/task/audit state unchanged.
- [ ] **RED:** Directly prove `assertCanAcceptTicket` distinguishes no plan from
  exact-revision loaded plan, rejects pending active tasks, and has no lane-
  mutation authority itself. All-complete remains in its current lane and
  creates no review/audit/notification.
- [ ] **GREEN:** Implement private SQL helpers behind the three policy methods,
  validate the final transaction state, and expose no command/dispatcher/MCP
  integration. Do not change phase-plan state/revision for task-only mutation.
- [ ] **Verify/gate/checkpoint:** Run only the new direct policy tests plus the
  Store boundary; require fresh Code Review, QA, Architecture,
  Security/Privacy, TPM, and Delivery Management GO/Required 0; commit/push the
  bounded policy/test diff and verify exact remote equality before Task 4A.

### Task 4A: Guard every Accepted path

**Files:**
- Modify: `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarAgentTools/main.swift`
- Modify: `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Modify: `ReleaseRadar/Projects/DashboardSampleData.swift`
- Modify: `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/RekonImportAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Modify: `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`

**Interfaces:** Extends the existing `.transitionTicket` command and existing
`release_radar_transition_ticket` translator/schema with an optional
`ticketTaskPlanRevision` used only for an Accepted destination. It adds no new
command case, no task-plan definition/completion mutation, and no new MCP tool.
Dispatcher, owner-AppModel callback, importer, sample, debug capture, and any
internal ticket-transition helper all invoke Task 3's
`assertCanAcceptTicket` inside the same transaction. `AgentCommand.upsertTicket`
retains its existing shape with no task-plan revision and rejects every create
or update whose supplied lane is Accepted. Planned and no-plan acceptance both
use only the existing transition command.

- [ ] **RED/Accepted matrix:** For dispatcher, owner AppModel, Rekon importer,
  sample seed, debug capture, and internal transition helper, test all four
  acceptance inputs: no plan/no revision keeps existing rules; completed
  plan/exact revision may accept; no plan/any revision rejects; and any plan
  without its exact revision rejects. Pending tasks, stale revisions, legacy
  `.transitionTicket(...accepted)` without a plan revision, non-Accepted
  destinations carrying a task revision, and every raw bypass attempt reject
  without lane, task, task-plan, audit, receipt, owner-attention, or notification
  effects. Accepted plans remain immutable and no-plan atomic tickets remain
  supported.
- [ ] **RED/upsert closure:** Exercise `AgentCommand.upsertTicket` with Accepted
  for both absent-ticket create and existing-ticket update, with and without a
  task plan. Every request rejects without ticket/outcome/phase/lane, task/plan,
  audit, receipt, review occurrence, owner-attention, or notification effects.
  Prove upsert has no task-plan revision field and the transition path remains
  the only Accepted route.
- [ ] **GREEN:** Route every listed Accepted entry point through Task 3 in the
  transaction that changes the lane, preserve existing lane/dependency/review/
  notification rules, and add only the optional revision field to the existing
  transition JSON/tool schema. Reject Accepted in `upsertTicket` before either
  its insert or conflict-update branch can write. Do not expose
  `reviseTicketTaskPlan`, `completeTicketTask`, a dedicated accept command, or a
  new MCP tool in this checkpoint.
- [ ] **Verify:** Run `TicketTaskPlanningPolicyAcceptanceTests`,
  `AgentBridgeAcceptanceTests`, `AgentBridgeTransportAcceptanceTests`,
  `RekonImportAcceptanceTests`, `AppRouteTests`,
  `ReviewAndGraphAcceptanceTests`, and `NotificationAcceptanceTests`, plus a
  Debug build. Inspect the packaged helper schema to prove upsert has no task-
  plan revision, both Accepted upsert branches reject, the existing transition
  tool accepts the bounded optional revision, and the tool-name set is
  otherwise unchanged. Verify every listed Accepted path fails closed.
- [ ] **Gate/checkpoint:** Code Review, QA/Test, Architecture,
  Security/Privacy, TPM, and Delivery Management return GO/Required 0. Do not
  install or mutate owner data. Commit/push only the 8 production paths and 7
  test paths declared above plus coordinator-owned ledger evidence; verify the
  exact reviewed local/remote SHA before Task 4B.

### Task 4B: Expose audited ticket-task commands

**Completed implementation and acceptance (2026-09-02); retained scope:** [Task 4B](../task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4b-audited-ticket-task-commands-brief.md).

**Files:**
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarAgentTools/main.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/DocumentationCallbackTests.swift` — update only the obsolete absence assertion and preserve MDCP schema coverage.

**Interfaces:** Adds `reviseTicketTaskPlan` and `completeTicketTask` command
cases plus MCP tools `release_radar_revise_ticket_task_plan` and
`release_radar_complete_ticket_task`. Additions contain no completion field and
are always Active/Pending. Results add optional `ticketTaskPlanRevision` while
preserving existing `inventory` and prior encoded result JSON. Both commands
dispatch only through Task 3 and use the existing durable request receipt,
transaction, `.ticketTaskPlan` audit
scope, authorized-root/attribution checks, and packaged helper transport. Task
4A's existing revision-bearing Accepted path and upsert rejection remain
unchanged.

- [x] **RED/commands:** Add exact command JSON round trips, translators, and
  strict MCP schemas. Test nil creation returning revision 1 versus present
  expected revision,
  63/64/65 aggregate operations, 65,535/65,536/65,537 sorted-key bytes, stable
  IDs/labels, Core-plus-MCP UTF-8 boundaries for 255/256/257-byte machine IDs
  and labels plus 4,095/4,096/4,097-byte titles using ASCII and multibyte
  values, wrong-project/ticket references, stale revision, pending-only
  additions, duplicate/conflicting operation identities, semantic no-op,
  changed-body request reuse, exact create/each-completion replay, out-of-order
  chained completion, transaction rollback, committed audit/revision/result,
  helper/app unavailable, and `outcomeUnknown` recovery by replaying the exact
  complete original request.
- [x] **RED/concurrency:** Build on delivered Task 4A and use the existing
  store/dispatcher concurrency infrastructure for all four schedules: no-plan
  Accept versus first plan creation; Accept@R versus add/supersede@R; Accept@R
  versus completion@R; and two revisions or completions at R. Assert one
  coherent winner and exact loser rollback with no orphan task/plan, extra
  audit/receipt, lane, owner-attention, or notification effect.
- [x] **GREEN:** Validate schema/bounds before mutation, canonicalize request
  bodies once, transact through Task 3, return only committed revisions and
  audits, and retain complete requests for replay/outcome-unknown recovery. Add
  exactly the two new helper tools; do not add a second accept tool, alter any
  Accepted-path rule, or infer state from Git, Markdown, tests, goals, or
  execution.
- [x] **Verify:** Run the brief's focused policy/bridge/notification and safe
  stdio/schema selections plus a Debug build. Preserve all 19 current tools
  and add exactly two (21 total), with strict translators and unchanged MDCP
  schemas/read-only routing. Update the existing transport count and MDCP
  callback test's obsolete task-tool absence assertion. Verify app-unavailable
  and outcome-unknown behavior through the controlled transport path; never
  run shared-service tests merely because the database is disposable.
- [x] **Gate/checkpoint:** Obtain independent code/QA review plus Architecture
  and Security/Privacy coverage for the public command/authorization/replay
  boundary. Deliver the 3 production and 4 test paths above plus necessary
  documentation with a verified fast-forward push after acceptance. Once
  separately authorized, this checkpoint permits only isolated tests and development-build exercise: do not install it for the
  owner, designate it as a release candidate, ship it, or permit external use
  of either new tool until Task 5 task visibility/recovery and Task 7 full
  planning/lane enforcement are independently accepted and remote-exact. Add no
  feature-flag system.

### Task 5: Present ticket tasks on cards and Ticket Details

**Files:**
- Modify: `ReleaseRadar/Projects/DashboardProjection.swift`
- Modify: `ReleaseRadar/Projects/TicketCardView.swift`
- Modify: `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modify: `ReleaseRadar/Projects/TicketDetailView.swift`
- Modify: `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Modify: `ReleaseRadarUITests/ReleaseRadarUITests.swift`

**Interfaces:** Produces `TicketTaskProjection` and explicit
`TicketTaskPlanProjection.noPlan`, `.loaded(plan:)`, and
`.unavailable(recovery:)`; only Loaded supplies
`TicketCardProjection.activeTaskCount` and Ticket Details rows from the same
active collection. `PhaseBoardView`, which constructs `TicketDetailView`,
routes its existing reload action/callback into the unavailable Tasks recovery
treatment; Task 5 adds no separate reload mechanism.

- [ ] **RED:** Assert the three projection states cannot collapse into each
  other; card count exists only for Loaded. Assert no-plan omission,
  unavailable recovery/omission, and isolated task-query failure: discard stale
  task rows/count, return unavailable recovery for that ticket, and keep the
  rest of the successfully loaded phase board usable. Assert
  deterministic active list, superseded exclusion, checked/unchecked state,
  add/supersede count synchronization, completion count stability, and no
  aggregate or task action. Test one-task `1 task` and sixteen-task `16 tasks`
  announcements with no completed/total fraction rendered or announced;
  glyph/count have no separate focus/action;
  completion preserves count; superseded rows disappear; a long list scrolls
  from first through last with no hidden `more`; compact identity, dependency,
  blocker, count, and full hit target do not overlap. Add row accessibility for
  label/title/checked state/item position and hidden decorative box. Exercise
  the existing PhaseBoardView reload callback from the unavailable treatment
  and assert the compact card retains its current 48-point minimum hit-target
  height.
- [ ] **GREEN:** Batch-load canonical active task rows, derive the card count
  from that array, add the neutral checklist signal, and render the read-only
  `Tasks` section exactly as the design specifies. Route the existing
  `PhaseBoardView` reload callback into the unavailable treatment. Keep five
  lanes and existing dependency/blocker signals.
- [ ] **Verify:** This is the exhaustive Ticket Tasks visual gate. Run
  projection/AppRoute/UI selections, then inspect one isolated running app at
  relevant wide and compact widths against
  `docs/design/mockups/phase_board.png`; exercise keyboard, VoiceOver,
  increased contrast, Dynamic Type at both wide and compact widths, exact
  metadata order/separators/narrow priority, long wrapping/scrolling, no-plan,
  Loaded, and unavailable states. Reuse this existing manual/runtime path; add
  no verification harness.
- [ ] **Focused owner UI acceptance:** Present the isolated running Ticket
  Tasks surface and exact wide/compact/accessibility evidence, including
  running-app Dynamic Type at both widths, to the owner. Record explicit
  acceptance of this UI contract before Task 5 closes or any Task 5 path is
  committed. This focused product gate applies to Task 5 only; it is not
  repeated as an owner-acceptance requirement on every later task.
- [ ] **Gate/checkpoint:** Independent QA/UX review covers the working UI,
  accessibility and recovery. Additional reviews follow actual changed
  boundaries under ADR-007. After the focused owner UI acceptance, deliver the
  seven UI/projection/test paths plus evidence with a verified fast-forward push. Task 4B
  tools now have their required visible
  recovery surface but remain non-installable/non-shippable until Task 7 also
  reaches its remote-exact gate.

### Task 6: Enforce Delivery Goal plan and lifecycle rules

**Files:**
- Create: `ReleaseRadarCore/Planning/DeliveryPlanningPolicy.swift`
- Create: `ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests.swift`

**Interfaces:** Produces `PhaseCreationMode`, `applyRevision`, `finalizePlan`,
`transitionGoal`, and plan/goal read helpers using the accepted Task 1B types
and v11 tables. It does not yet expose commands or own general ticket writers.

- [ ] **RED:** Cover the full ADR-004 phase-plan and goal lifecycle matrices,
  exact structural revisions, finalization coverage, initially empty versus
  delivery-complete Ready, assignment history, lifecycle current-revision-but-
  Draft rejection, owner-only acceptance, supersession rules, operation limits,
  and rollback. Add the one migration-adoption case: when finalizing a plan to
  Ready, a migration-continuation In-progress or Needs-review ticket explicitly
  assigned to exactly one Draft goal atomically promotes only that goal to
  Active, sets `activated_at`, and clears the continuation. Reject
  zero/multiple/inferred/retroactive assignments and prove this grants no
  freestanding Planned→Active transition.
- [ ] **GREEN:** Implement one store-owned Delivery Goal policy with private SQL
  mutation helpers. Keep the legacy-adoption branch narrow, explicit-assignment
  only, and inside finalization. Task-plan rows are read only when ticket
  acceptance needs them; task-only mutation never calls phase invalidation.
- [ ] **Verify/gate/checkpoint:** Run focused policy and Store tests; obtain
  independent code/QA and Architecture review of lifecycle, transaction and
  migration-adoption behavior, with Security/Privacy coverage of owner-only
  acceptance. Deliver this policy/test slice and concise evidence with a
  verified fast-forward push.

### Task 7: Route every ticket writer and compose planning policy

**Files:**
- Modify: `ReleaseRadarCore/Planning/DeliveryPlanningPolicy.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Modify: `ReleaseRadar/Projects/DashboardSampleData.swift`
- Modify: `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`
- Modify: `ReleaseRadarTests/DeliveryPlanningPolicyAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/RekonImportAcceptanceTests.swift`

**Interfaces:** Adds policy-owned `upsertPhase`, `upsertTicket`,
`transitionTicket`, and `assertCanRecordReviewOrCompletion`; every product/debug
ticket writer becomes a client. The Accepted transition preserves Task 4A's
exact task revision gate and its unconditional rejection of Accepted upsert
create/update requests. No portable exporter/exportability helper is added.

- [ ] **RED:** Exercise every ticket operation row, dependency/blocker gates,
  legacy continuation, Accepted terminality, structural invalidation, task-
  only non-invalidation, Backlog-only import, source-lane review facts, valid
  sample/debug setup, and Accepted-upsert rejection across every routed writer.
  Current import creates no task plans.
- [ ] **GREEN:** Route all current shipping/debug phase and ticket SQL writers
  through the policy; remove bypass modes; keep setup-only test SQL isolated.
  Preserve the Task 4A task gate and upsert closure. Retain the importer's
  existing authorized transaction, bookmark/binding/catalog checks before
  delivery writes, managed artifact identities and legacy evidence behavior.
  Do not create an unused archive predicate/helper/error or archive v2; future RM5 owns exporter/
  archive-format completeness and RM6 may import only its complete supported
  output.
- [ ] **Verify/gate/checkpoint:** Run focused policy, importer, onboarding,
  bridge and sample/capture tests, including existing managed-import
  authorization/identity regressions under the shared test-isolation boundary.
  Obtain independent code/QA, Architecture and Security/Privacy coverage of the
  writer/transaction boundaries. Deliver the bounded diff with a verified
  fast-forward push before Task 7A. This checkpoint, together with Tasks 5
  and 6, makes Task 7A eligible to lift Task 4B's owner-install restriction; Task 7 itself
  does not install or ship the tools.

### Task 7A: Install and bootstrap live RR-R10 task tracking

**Files:**
- Modify: `ReleaseRadarTests/EndToEndAcceptanceTests.swift`
- Coordinator modify: `docs/delivery/progress.md`

**Interfaces:** Consumes the exact remote-equal through-Task-7 candidate and
the shared owner-install security/recovery contract in the Ticket Tasks design.
It adds no product behavior. It installs task UI/policy/tools over the existing
managed schema-v13 store using Task 7's forward-v14 migration, creates the live 16-row RR-R10 plan at revision 1, completes accepted rows
through Task 7, and produces installed replay/readback evidence that every
later task command consumes.

- [ ] **Brief/runbook release gate:** Before RED or any owner install, the Task
  7A brief adapts the existing M6A recovery procedure to the current managed
  v13 baseline and records the exact bounded backup/restore runbook in the
  repository. Owner data, complete inventories and recovery copies remain in
  the owner-approved protected companion. It specifies app/helper
  quiescence and process checks; one consistent SQLite main/WAL/SHM set; backup
  identity; restore verification on a disposable copy; retention through post-
  install acceptance; and exact abort, restore, relaunch, and typed/UI readback.
  Independent QA and Security/Privacy review cover the actual installation,
  preservation and recovery risks. Apply Architecture review only if a contract
  changes. Do not add a generalized backup framework or product feature.
- [ ] **RED/isolated install proof:** In the declared end-to-end test, start
  from the existing managed v13 owner-state shape with RR-R10 In progress and
  assert its migration-only continuation survives the v13-to-v14 install
  path. Retain historical v10/v11/v12 fixture migration coverage through v14;
  do not recreate or infer the owner's continuation. Exercise one 16-addition
  Active/Pending creation request,
  the exact chained completion manifest through Task 7, replay, relaunch, and
  Task 7A still Pending. Prove `☷ 16`, all labels/titles/order, checked states
  through Task 7, no lane/goal movement, no duplicate audit/receipt/
  notification, and unchanged unrelated state. Establish the predependency
  condition using genuine earlier product/fixture inputs; do not manufacture
  RED by weakening the merged product. Old binaries refuse v14; restoration
  requires the consistent pre-migration snapshot and exact old software.
- [ ] **GREEN/isolated install proof:** Make only the declared integration test
  pass against the exact through-Task-7 product. Do not add product behavior in
  this checkpoint. Run the focused test, complete scheme on isolated data, and
  strict application/helper signing checks before owner installation.
- [ ] **Owner pre-install safety:** Confirm Tasks 5, 6, and 7 are independently
  accepted, committed/pushed, remote-equal, and the through-Task-7 candidate is
  exact. Apply the shared contract explicitly: capture typed/UI active-phase,
  relevant lane/outcome/dependency/blocker, observed-goal/link, notification,
  and no-plan/goal-state snapshot. Also capture the fresh authorized root and
  repository binding, accepted catalog, evidence IDs/locators/associations and
  resolution, legacy behavior, guidance and plugin state. Ordinary live use
  may have changed state since MDCP; use fresh authorized readback rather than
  reusing M6A/M8 inventory. Execute the approved runbook's quiescence,
  consistent main/WAL/SHM backup, identity, disposable-copy restore proof, and
  retention steps; verify candidate/helper/signing/running-process hashes; and
  retain the ordered request manifest with authorized root, trusted origin,
  attribution, reason, UUID, full body, and order. Include separately authorized
  bound-checkout catalog deployment/acceptance when the candidate needs new
  documentation. Preserve the accepted trust anchor and resolve uncertain
  requests before recovery. Stop on any mismatch; do not rerun initial binding
  or evidence adoption.
- [ ] **Install and bootstrap:** Install only the exact candidate. Do not read
  SQLite after install. Through retained typed requests, create every catalog
  row Active/Pending at revision 1, then complete Task 1A, Task 1B, Task 2A,
  Task 2B, Task 3, Task 4A, Task 4B, Task 5, Task 6, and Task 7 in order using
  each returned exact revision. Leave Task 7A and Tasks 8–11B Pending. Relaunch
  and verify the live list/card, migration continuation, unchanged RR-R10 In
  progress lane, stable first/last row, exact revisions/audits, and original-
  request replay with no duplicates.
- [ ] **Abort/repair rule:** Migration failure, corruption, unexpected state,
  inability to prove the continuation, or any snapshot/hash/signing/process
  mismatch executes the approved runbook's exact abort, quiescence, restore,
  relaunch, and typed/UI readback. The pre-Task-2A gate has already proved
  migration eligibility; this is failure recovery, not deferred discovery. If a
  product defect appears before live plan creation, stop and add a separately
  owner-accepted, architecture-reviewed bounded catalog checkpoint before
  retrying. If it appears after plan creation, keep Task 7A Pending, use
  `reviseTicketTaskPlan` at the exact revision to add one meaningful Active/
  Pending repair task, and create/review/release its full brief. Keep that row
  Pending through implementation/tests, corrected-candidate staging, the
  shared snapshot/backup/hash/install contract, typed/UI proof that the defect
  is fixed and owner state preserved, independent review, commit/push, and
  remote equality. Only then complete/read back the repair row, durably record/
  commit/push/remote-verify its returned revision and audit, and resume Task 7A.
  Never hide the fix here or precreate a contingent row.
- [ ] **Gate/checkpoint and row completion:** Independent QA and
  Security/Privacy accept the actual isolated/installed preservation, managed
  readback and recovery evidence under the shared contract. Commit/push only the declared test plus the
  coordinator-owned ledger evidence and verify exact remote equality with
  ahead/behind `0/0`. Only then issue the retained exact-revision
  `completeTicketTask` for Task 7A and read back its checked row, unchanged
  active count/lane/goal state, resulting revision, and audit. The coordinator
  records that exact revision/audit in `docs/delivery/progress.md`, commits/
  pushes it, and verifies remote equality no later than Task 8's brief/release
  checkpoint. Task 8 cannot open before that durable reconciliation.

### Task 8: Expose audited Delivery Goal commands

**Files:**
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Modify: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Modify: `ReleaseRadarAgentTools/main.swift`
- Modify: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`

**Interfaces:** Adds `applyPhasePlanRevision`, `finalizePhasePlan`, and
`transitionDeliveryGoal`; adds MCP tools `release_radar_apply_phase_plan_revision`,
`release_radar_finalize_phase_plan` and `release_radar_transition_delivery_goal`;
extends results with optional `phasePlanRevision`.
Preserve the 21 existing tools and all MDCP schemas/query/results; the three
new tools bring the inventory to 24. Before either mutation or durable replay,
only the new owner-only lifecycle requests
reauthorize the trusted `AgentCommandOrigin`. Preserve the preexisting
canonical request-receipt bytes: validate replay origin through the stored
authoritative audit actor/result association rather than adding origin to old
receipt bodies. Decode the stored result's audit event ID, load that
authoritative audit row, and require its persisted owner/agent actor identity
to match the newly supplied trusted origin before returning the old result;
missing or mismatched association rejects.

- [ ] **RED:** Test exact round trips/schemas, 64 goal and 512 assignment
  aggregate limits, 65,536-byte boundary, stale/current-Draft revisions,
  coupled transition denial, external acceptance denial, owner-app acceptance,
  same-origin exact replay returning the original result, cross-origin reuse of
  an owner request ID rejecting without replay, changed-body reuse, rollback,
  no duplicate mutation/audit, and assignment-event audit scope.
- [ ] **GREEN:** Dispatch only through Tasks 6–7, preserve non-spoofable origin
  and current canonical request-receipt bytes, reauthorize the supplied trusted
  origin against the persisted authoritative audit actor/result association on
  replay, and expose only `awaiting_acceptance` through the external lifecycle
  schema. A mismatched origin returns the typed reuse/authorization rejection
  before the prior result can escape. Keep MDCP digest receipts and their
  authorized replay-before-current-catalog-validation behavior unchanged.
- [ ] **Verify/gate/checkpoint:** Run focused bridge/transport selections and a
  Debug build under the shared service-isolation boundary; exercise a new
  owner request, same-origin replay and external-origin reuse with one result,
  audit and mutation total. Verify all 24 tools and old encoded results.
  Obtain independent code/QA, Architecture and Security/Privacy review of the
  command/replay boundary; deliver with a verified fast-forward push. Then issue `completeTicketTask` for Task 8 at
  the exact live revision and read back its checked row, resulting revision,
  audit, unchanged active count, and unchanged lane/goal state. The coordinator
  records that exact revision/audit in `docs/delivery/progress.md`, commits/
  pushes it, and verifies remote equality no later than Task 9's brief/release
  checkpoint. Task 9 cannot open before that durable reconciliation.

### Task 9: Project Delivery Goals, Activity, and owner review

**Files:**
- Modify: `ReleaseRadar/Projects/DashboardProjection.swift`
- Modify: `ReleaseRadar/Activity/ProjectActivityProjection.swift`
- Modify: `ReleaseRadar/Review/ReviewInboxProjection.swift`
- Modify: `ReleaseRadarTests/DashboardProjectionTests.swift`
- Modify: `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`

**Interfaces:** Produces `PhaseBoardKey`, `PhasePlanProjection`,
`DeliveryGoalSummaryProjection`, `TicketDeliveryGoalProjection`,
`DeliveryGoalAcceptanceReviewProjection`, and both dashboard board accessors;
preserves the active-board accessor for existing callers.

- [ ] **RED:** Assert all-phase loading, exact coverage/unassigned/completed
  states, separate Delivery Goal/Codex execution context, stable goal filters,
  assignment-event Activity attribution, and exactly one Awaiting-acceptance
  review item with replay/failure cleanup behavior.
- [ ] **GREEN:** Add all-phase keyed projection and unambiguous goal/activity/
  review joins without changing observed-goal persistence or notification
  semantics. Preserve Task 5 task rows/counts in every board projection and
  authorized managed/legacy evidence readbacks, including null stored paths,
  artifact IDs, lifecycle, authority, availability and recovery presentation.
- [ ] **Verify/gate/checkpoint:** Run focused projection/review tests including
  existing managed evidence presentation regressions. Obtain independent
  code/QA review, with Architecture or Security/Privacy review only where the
  changed component or content/authorization boundaries trigger it. Deliver
  with a verified fast-forward push. Then issue `completeTicketTask` for Task 9 at the exact live
  revision and read back its checked row, revision, audit, unchanged count,
  and unchanged lane/goal state. The coordinator records that exact revision/
  audit in `docs/delivery/progress.md`, commits/pushes it, and verifies remote
  equality no later than Task 10's brief/release checkpoint. Task 10 cannot
  open before that durable reconciliation.

### Task 10: Present non-mutating phase browsing and Delivery Goals

**Files:**
- Create: `ReleaseRadar/Projects/PhaseBoardPlanningControls.swift`
- Modify: `ReleaseRadar/Projects/PhaseBoardView.swift`
- Modify: `ReleaseRadar/Projects/ActivePhaseSelector.swift`
- Modify: `ReleaseRadar/Projects/TicketDetailView.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Navigation/SidebarView.swift`
- Modify: `ReleaseRadar/Review/NeedsReviewView.swift`
- Modify: `ReleaseRadarTests/AppRouteTests.swift`
- Modify: `ReleaseRadarUITests/ReleaseRadarUITests.swift`

**Interfaces:** Adds `AppModel.viewPhase` and owner-only
`acceptDeliveryGoal`; consumes Task 9 projections while preserving Task 5's
read-only `Tasks` section before Delivery Goal and Codex execution goal.

- [ ] **RED:** Prove viewed phase never mutates the active pointer/audit,
  Make-active remains separate, filters retain lane identity, owner acceptance
  uses `.ownerApp`, and wide/compact/focus/keyboard/VoiceOver/store-refresh/
  revision failures match the Delivery Goal design. Retain a focused regression
  that Task 5's tri-state Tasks section and canonical count survive phase
  browsing/filtering; do not repeat Task 5's exhaustive task visual matrix.
- [ ] **GREEN:** Build the planning controls, per-project viewed state, distinct
  inspector sections, filtered five-lane board, and Needs Review acceptance
  action without exposing task-row actions or owner acceptance through MCP.
  Reuse the existing evidence component and preserve managed/legacy resolution,
  lifecycle/authority and recovery through phase browsing and filtering.
- [ ] **Verify/gate/checkpoint:** Run AppRoute/UI tests and one isolated wide/
  compact runtime comparison focused on Delivery Goal controls, active/viewed
  separation, filter/focus, inspector headings, and the task regression;
  obtain independent QA/UX and owner-acceptance Security/Privacy review;
  deliver with a verified fast-forward push. Then issue `completeTicketTask` for Task 10 at the exact live
  revision and read back its checked row, revision, audit, unchanged count,
  and unchanged lane/goal state. The coordinator records that exact revision/
  audit in `docs/delivery/progress.md`, commits/pushes it, and verifies remote
  equality no later than Task 11A's brief/release checkpoint. Task 11A cannot
  open before that durable reconciliation.

### Task 11A: Integrate and stage the release candidate

**Files:**
- Modify: `ReleaseRadarTests/EndToEndAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- Modify: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- Coordinator modify: `docs/delivery/progress.md`

**Interfaces:** Consumes every prior public command/projection. Produces no new
product abstraction; produces an independently accepted, committed/pushed,
remote-exact staged candidate and automated integration evidence for Task 11B.

- [ ] **RED/integration fixture:** Drive public APIs from a v10 fixture through
  v11/v12/v13, and separately exercise the already-managed v13 baseline.
  Cover pending-only plan creation, chained completions, exact task
  acceptance, the seven Delivery Goals, roadmap assignment sets, all ticket
  writers including Accepted-upsert rejection, import creating no task plans,
  no-reopen, notification preservation and the shared managed-documentation
  preservation contract. Immediate pass after prior tasks is
  valid. A discovered product defect remains a
  failing regression in one of the three declared integration-test files and
  stops Task 11A; it is not repaired inside this checkpoint.
- [ ] **GREEN/integration:** Prove the exact seven Delivery Goals and roadmap
  assignment sets, all ticket writers, task-plan-free import, no-reopen rule,
  notification preservation, focused integration selections, build/signing,
  and one staged Release candidate. Modify only the three declared integration
  tests and coordinator-owned evidence; do not change any owning product
  boundary, install, bootstrap owner data, repeat Task 5/10 manual UI matrices,
  or perform owner acceptance. If a product defect appears, the coordinator
  must stop with Task 11A Pending, call `reviseTicketTaskPlan` at the exact live
  revision to add one meaningful Active/Pending repair task, obtain its complete
  brief and independent release, implement/test/review/commit/push/remote-
  verify it, complete that new row explicitly, and then rerun Task 11A. No
  owning product fix is hidden inside Task 11A and no contingent defect row is
  created in advance.
- [ ] **Gate/checkpoint:** Obtain independent QA review of integration and
  staged-candidate evidence; add specialist review only for a changed risk
  boundary. The shared isolation rule governs complete-scheme testing. Update
  coordinator evidence, commit/push only the three declared integration-test
  paths plus that evidence, and verify exact remote equality. Then issue
  `completeTicketTask` for Task 11A at the exact live revision and read back
  its checked row, revision, audit, unchanged count, and unchanged lane/goal
  state. The coordinator records that exact revision/audit in
  `docs/delivery/progress.md`, commits/pushes it, and verifies remote equality
  no later than Task 11B's brief/release checkpoint. Task 11B cannot open before
  that durable reconciliation. Owner acceptance remains closed.

### Task 11B: Install and verify the final RR-R10 outcome

**Files:**
- Modify: `ReleaseRadarTests/EndToEndAcceptanceTests.swift`
- Modify: `docs/delivery/progress.md`

**Interfaces:** Consumes the exact Task 11A staged hashes plus every prior
checkpoint and the live Task 7A plan. Produces final installed preservation,
Delivery Goal repair/adoption, replay/readback evidence, then a completed Task
11B row and final task-plan revision. If N is the dynamic active count of all
16 initial rows plus every reviewed later row, it ends with installed card
signal `☷ N` and typed/UI proof that all N active rows are checked, and performs
none of the later ticket or Delivery Goal closure.

- [ ] **Pre-install/full-suite gate:** Verify Task 11A local/remote/hash equality,
  run the complete scheme against isolated data, and require independent pre-
  install release. Apply the shared owner-install contract explicitly: capture
  typed/UI active-phase, relevant ticket lane/outcome/dependency/blocker,
  observed-goal/link, notification, all 16 initial task rows plus every reviewed
  later row, dynamic active count N, and current Delivery Goal state. Include
  the same fresh managed binding/catalog/evidence/plugin preservation baseline
  and authorized document deployment/acceptance conditions as Task 7A. Reuse
  its adapted v13 runbook: prove app/helper quiescence, consistent SQLite
  main/WAL/SHM backup identity, disposable-copy restore, and retained backup;
  verify exact staged app/helper/signing/running-process hashes; retain every
  repair request's
  authorized root, trusted origin, attribution, reason, UUID, complete body,
  and order. Any mismatch stops without installation.
- [ ] **Final install and continuation preservation:** Install only the exact
  candidate and do not read SQLite afterward. Through typed/UI readback, prove
  the plan contains all 16 initial rows plus every reviewed later row with
  dynamic active count N, every required row through Task 11A completed, Task
  11B Pending, exact revision/audits, RR-R10 In progress migration
  continuation, and all unrelated snapshot state preserved. Migration failure,
  corruption, unexpected state, or inability to prove that invariant executes
  the approved runbook's exact abort, quiescence, restore, relaunch, and typed/
  UI readback.
- [ ] **Installed Delivery Goal repair/adoption:** Through the retained typed
  manifest, create RR-DG-R10 and RR-DG1…6 as Draft, explicitly assign the
  migration-continuation RR-R10 to exactly RR-DG-R10, assign the roadmap
  tickets as specified, and finalize the Ready plan. Assert finalization
  atomically promotes RR-DG-R10 to Active, sets its activation time, and clears
  RR-R10's continuation; RR-DG1…6 remain Planned. Prove there is no inferred or
  retroactive assignment and no general goal-activation request. Replay every
  original request, relaunch, and verify `☷ N`, exact goals/assignments,
  unchanged historical tickets/active phase/observed goals, and no duplicate
  audit/receipt/notification. This is critical installed readback, not a repeat
  of Task 5 or Task 10's exhaustive visual matrices.
- [ ] **Installed-only defect stop/repair:** Keep Task 11B Pending. At the exact
  live revision, add one meaningfully titled Active/Pending task through
  `reviseTicketTaskPlan` and create/review/release its full bounded brief. Keep
  both Task 11B and the repair row Pending through implementation/tests,
  corrected-candidate staging, the shared snapshot/approved-runbook/hash/
  install contract, typed/UI proof that the original defect is fixed and owner
  state preserved, independent risk-triggered review and a verified
  fast-forward push. Only
  then complete/read back the repair row, record its exact revision/audit in
  `docs/delivery/progress.md`, commit/push/remote-verify that ledger record, and
  resume Task 11B. Never hide the fix in Task 11B or precreate a contingent row.
  Uncertain requests recover only through exact original replay.
- [ ] **Independent gate/checkpoint:** Independent QA and Security/Privacy
  review accept Task 11B's actual installation, recovery and managed-state
  preservation evidence. Commit/push its exact tests/evidence and verify local/remote equality
  while RR-R10 remains unaccepted and Task 11B remains pending.
- [ ] **Complete Task 11B and stop:** Send the retained exact-next-revision
  `completeTicketTask` for Task 11B only after its independent checkpoint is
  committed/pushed/remote-exact. Read back all 16 initial rows plus every
  reviewed later row completed, dynamic active count N, card signal `☷ N`,
  proof that all N active rows are checked, and the resulting final task-plan
  revision/audit. Verify RR-R10 remains In progress,
  RR-DG-R10 remains Active, RR-DG1…6 remain Planned, no lane or goal moved
  because of task completion, and the task-plan revision is authoritative.
  Task 11B ends immediately at this installed readback; terminal reconciliation
  durably records its returned revision/audit.

## Post-task governed ticket and Delivery Goal closure before Accepted

This is an execution section, not an owner-visible task row. It cannot perform
product implementation and begins only after Task 11B has ended with all 16
initial rows plus every reviewed later row checked at dynamic active count N.

- [ ] **Verify the adopted starting state:** Preserve the final task-plan
  revision. Read back the Post-MVP plan Ready at its exact revision, RR-R10
  already In progress and explicitly assigned only to RR-DG-R10, RR-DG-R10
  Active with activation time, migration continuation cleared, dependencies
  satisfied, and zero blockers. No blocker-resolution, ticket-start, or goal-
  activation action occurs in this post-task section.
- [ ] **Reach owner review:** Record the governed completion and review evidence
  through typed audited requests, then transition RR-R10 In progress→Needs
  review. Read back each committed request and prove the final task-plan
  revision is unchanged.
- [ ] **Owner acceptance and goal closure:** Obtain explicit owner acceptance,
  then use the exact unchanged task-plan revision for RR-R10 Needs
  review→Accepted. Request RR-DG-R10 Active→Awaiting acceptance with the exact
  current phase-plan revision, then use the installed owner-app action for
  Awaiting acceptance→Accepted. Read back each step; replay every original
  request verbatim and prove the original receipts/audits, no duplicate
  side effects, terminal Accepted states, and unchanged task-plan revision.
  Any optional owner-visible closing summary states that Task 7A, Task 11A,
  and Task 11B were each completed only after their own remote-exact
  checkpoints, never by bootstrap or lane movement.
- [ ] **New implementation stop rule:** If any product implementation is
  discovered before acceptance, stop this closure. Use
  `reviseTicketTaskPlan` at the exact current revision to add a new active
  Pending task; create its complete bounded brief, independently release it,
  implement/review/verify/commit/push it through its own remote-exact gate, and
  explicitly complete that row. Only then resume this closure from current
  authoritative readback. Do not implement the work inside this non-task
  section or erase completed history.

## Non-ticket terminal reconciliation after Accepted state

This is a repository execution step, not an owner-visible task row. It cannot
add, revise, complete, supersede, or otherwise mutate the Accepted RR-R10 task
plan and is not part of its denominator.

- [ ] Record the already-Accepted RR-R10/RR-DG-R10 state, final task-plan
  revision/audit and concise acceptance result in `docs/delivery/progress.md`.
  Archive necessary closed detail; preserve task/artifact identities and keep
  lifecycle/catalog/index/reference changes in the same documentation slice.
  Retain owner data and full requests only in the approved protected companion.
- [ ] Run the native documentation check and `git diff --check`; commit the
  complete closeout documentation slice, push normally and verify the remote
  commit. Do not create checksums for mutable records or duplicate review logs.
- [ ] If closeout changes the catalog, deploy and accept its exact transition
  at the authorized bound root before managed readback. Record repository
  evidence with the catalogued artifact ID through `addManagedEvidence`, with
  the exact accepted root/repository/version/digest, without changing ticket,
  goal or task-plan state. Complete the persistent Codex goal only
  when no required work remains.

## Revised plan completion check

- The 2026-09-02 planning refresh consumes completed MDCP and delivered
  Tasks 1A/1B/2A/2B/3/4A. Historical package approval and schema-v10 handoff
  instructions are not reopened. Current authorization is in the ledger.
- The initial bootstrap has 16 stable identities, six delivered repository
  checkpoints and ten remaining checkpoints at this refresh. They first
  become app-owned at Task 7A through pending-only creation and explicit
  completion requests; document checkboxes confer no application authority.
- Tasks 2A/2B/3/4A/4B/5 implement Ticket Tasks without reopening accepted v11
  work; Tasks 6–10 replace prior unopened Tasks 2–4; Task 7A makes tracking
  live; Tasks 11A/11B split final integration from installed repair. The non-
  ticket reconciliation preserves prior Task 6 responsibility without ever
  becoming a task row or mutating Accepted state.
- Every revised task is a complete independently testable slice with explicit
  files, interfaces, RED/GREEN behavior, independent review, and its own
  commit/push/remote checkpoint. Internal checkbox steps are execution actions,
  not persisted task rows.
- Every Task 7A bootstrap addition is Active/Pending. Explicit chained
  completion requests through Task 7, then exact completion after each Task
  7A/8/9/10/11A/11B remote gate, produce checked rows and preserve replay/
  audit/revision evidence. Creation returns revision 1; every later successful
  mutation advances once. Task-plan definition changes after bootstrap use
  `reviseTicketTaskPlan` at the exact live revision and never infer authority.
- The coordinator durably records, commits/pushes, and remote-verifies each
  Task 7A/8/9/10/11A completion revision/audit no later than the next task's
  brief/release; the next task cannot open first. Repair rows are reconciled
  before their parent resumes, and Task 11B's final row is recorded by terminal
  reconciliation. No reconciliation becomes a task row or framework.
- Task-plan and phase-plan revisions remain independent; the Accepted
  transaction observes the exact task revision and all active completions.
  Final task completion never changes the lane or goal.
- Card count and Ticket Details list share canonical active rows; completion
  never changes count or lane; isolated task-query failure supplies unavailable
  recovery with no stale count while the rest of the board remains usable.
- Core and MCP enforce 256-byte machine-ID, 256-byte label, and 4,096-byte title
  UTF-8 maxima with minus-one/exact/plus-one ASCII and multibyte tests. Schema
  v12 parent deletion and cascade attempts cannot erase task history.
- Current import creates no task plans. RR-R10 adds no exporter, exportability
  helper, guard, archive error, or archive v2. Future RM5 export/format work
  represents tasks or fails before emission; RM6 accepts only complete
  supported exporter output or rejects it.
- Task 7A adapts the existing recovery procedure to the current managed v13
  state, with independent QA/Security review before owner install: app/helper
  quiescence, SQLite main/WAL/SHM consistency, backup identity, disposable-copy
  restore proof, retention through post-install acceptance, and exact abort/
  restore/relaunch/readback. Task 11B reuses it. Both installs retain exact
  hash/signing/process/request-manifest/replay checks without direct post-
  install SQLite reads or a generalized backup product/framework.
- Installed repair rows remain Pending through corrected-candidate staging,
  the shared install contract, typed/UI defect and owner-state proof,
  independent review, commit/push, and remote equality; only then are they
  completed/read back and durably reconciled before the parent resumes.
- RR-R10 is already In progress when Task 7A installs. Migration-only
  continuation is preserved in existing v13 state; historical fixture
  migration covers v11/v12/v13. Task 11B explicitly assigns it to
  Draft RR-DG-R10 and Ready finalization atomically adopts it by promoting that
  goal to Active, setting activation time, and clearing continuation; roadmap
  goals remain Planned. No inferred assignment or general goal-activation path
  exists.
- Task 11B independently reviews/commits/pushes/verifies final installed repair,
  then completes its row and ends with all 16 initial rows plus every reviewed
  later row checked and card signal `☷ N`. A separate non-implementation closure begins from
  In progress/Active, records completion/review, moves to Needs review, obtains
  explicit owner acceptance for exact-task-revision Needs review→Accepted, and
  closes RR-DG-R10 through Active→Awaiting acceptance→owner-app Accepted. Post-
  Accepted terminal reconciliation remains a separate final section.
