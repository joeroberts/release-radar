# RR-R10 Task 4A Brief: Guard Every Accepted Path

**Status:** Planning draft complete. The owner has authorized Task 4A planning
and implementation. Implementation remains gated on independent review of this
exact brief, Delivery Management release from an exact remote-equal base, and
separate authorization before tests or Git operations. Task 4B remains closed.

## Objective and user-visible outcome

Make every current production path that writes a ticket as Accepted enforce
Task 3's optional task-plan gate in the same transaction as the lane change.

- Atomic tickets with no plan retain revisionless acceptance.
- Planned tickets accept only at their exact current task-plan revision after
  every Active task is Completed.
- Missing/stale/misapplied revisions, pending tasks, terminal tickets, raw
  Accepted bypasses, and Accepted upsert leave all state unchanged.
- The existing transition command/tool remains the only command acceptance
  surface. Task 4A adds no task mutation, new tool, or owner-facing UI.

## Controlling references

- `docs/design/release-radar-ticket-tasks-design.md`, especially Plan
  invariants, Accept a planned ticket, Audit/replay/failure, and Portable import
  and future export boundary; inspected SHA-256
  `c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08`.
- `docs/architecture/ADR-005-ticket-task-work-plans.md`, especially the exact
  revision-bearing transition, Accepted-upsert closure, and Task 4A/4B
  sequencing; inspected SHA-256
  `6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5`.
- `docs/architecture/ADR-001-release-radar-boundaries.md`, especially app-owned
  SQLite writes, the typed bridge, five lanes, and the Rekon seed-import
  boundary; inspected SHA-256
  `390d30e6ad100bdc5ba1cf408e319ad446467c67e719d1a89002858bee96a668`.
- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`,
  active Task 4A at lines 1532 onward; inspected SHA-256
  `2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1`.
- `docs/delivery/progress.md`, which records Task 3 independently accepted and
  Task 4A next eligible; inspected SHA-256
  `55428d0027ef3f088f4af06c7e69bf6fb8cc7654cf6cebb504028255a17964ae`.
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-3-ticket-task-planning-policy-brief.md`
  and `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift` for the
  accepted assertion/error/transaction contract. The production policy was
  inspected at SHA-256
  `828e7569a1be2854a6c795c11618d6b60a1fd4149290e52634eca8766663b54c`.

Task 4A changes no visual surface, so no mockup/runtime visual gate applies.

## Dependencies and release gate

The ledger records Task 3 complete, independently accepted, and remote-exact at
`e7b8d725178663b4d70b6984fbfdda3dcdffaf4a`. Before RED:

1. Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy must
   review this exact brief and return GO/Required 0.
2. Architecture and QA must explicitly accept the three resolutions below.
3. Delivery Management must register this brief in `docs/delivery/progress.md`,
   checkpoint the planning inventory through the approved cadence, and verify
   the chosen implementation base equals upstream/live remote with
   ahead/behind `0/0` and a clean worktree.
4. A fresh Implementer must own only the declared implementation paths; no
   concurrent writer may modify them.
5. The owner must separately authorize the test commands before RED. That
   authorization request must disclose that the existing transport suite
   transiently registers and unregisters its packaged LaunchAgent through
   `SMAppService`; this reversible local side effect uses existing cleanup and
   no owner data. Git operations require separate authorization before any
   checkpoint commit/push.

Task 4B cannot open until Task 4A is implemented, independently accepted, and
remote-exact. A first failed mechanism permits only the repository-authorized
bounded diagnosis/correction; a second failure of that mechanism stops.

## In scope

- Add optional `ticketTaskPlanRevision` only to the existing transition command
  and transition MCP schema/translator.
- Preserve legacy transition decoding, canonical request bytes, receipts,
  replay, result shape, audit scope, and omitted-revision behavior.
- Reject a revision on a non-Accepted destination before transaction.
- Reject every Accepted-transition ticket ID containing embedded NUL through
  one generic preflight error before project lookup or transaction.
- Invoke `TicketTaskPlanningPolicy.assertCanAcceptTicket` before every current
  Accepted lane write, on the same store connection/transaction.
- Reject every Accepted `upsertTicket` before create or conflict-update.
- Add one internal AppModel owner callback using the same dispatcher command
  with `.ownerApp` origin; add no UI.
- Route Rekon, sample, and Debug Accepted creation through the bounded staged
  pattern below without changing their input contracts.
- Preserve existing lane/review/notification/import-conflict/idempotence rules.
- Add the targeted seven-file regression matrix and Debug/package gate.

## Out of scope

- Task 4B's `reviseTicketTaskPlan`/`completeTicketTask` commands, results,
  tools, replay/concurrency matrix, or any other task-plan mutation.
- A dedicated accept command/tool, command/wire version bump, new result field,
  or new `AgentCommandError` case.
- A revision field in upsert, `ImportPreview`, `ImportTicket`, Rekon schema-v1,
  sample data, or Debug scenario input.
- Delivery Goal/phase-plan policy, general lane lifecycle enforcement,
  migration-continuation behavior, or Task 5 UI/projections.
- Production schema/migration/trigger, Store/SQLite, import protocol/model,
  notification model, dependency, Xcode project, build script, or feature-flag
  changes. The scoped test-database trigger below is fixture setup only.
- Owner database/app mutation, installation/launch, external notifications,
  credentials, accounts, networking, or other external state.
- Implementer changes to this brief, `docs/delivery/progress.md`, or the task-
  brief checksum manifest; those remain coordinator-owned.

## Exact file inventory

Task 4A has a strict 15-path ceiling.

Production:

- `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarAgentTools/main.swift`
- `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- `ReleaseRadar/Projects/DashboardSampleData.swift`
- `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`
- `ReleaseRadar/App/AppModel.swift`

Tests:

- `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`
- `ReleaseRadarTests/RekonImportAcceptanceTests.swift`
- `ReleaseRadarTests/AppRouteTests.swift`
- `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift`
- `ReleaseRadarTests/NotificationAcceptanceTests.swift`

The Task 3 assertion already has the required semantics. Its production file
is declared by the master plan, but no semantic/error change is anticipated.
Leave it byte-identical if the existing API can be consumed unchanged; do not
manufacture a diff. A required path outside this inventory stops the task.

## Resolved inspection mismatches

### 1. The assertion requires an existing non-Accepted ticket

Rekon, sample, and Debug writers currently create Accepted rows directly.
Calling Task 3 before insertion would report `ticketNotFound`; calling it after
a direct Accepted insert would report `acceptedTicket`.

For a new source row whose final lane is Accepted, each creation-only writer
must therefore run this inside its existing single `DeliveryStore.transact`:

1. insert the complete row with transaction-local lane Backlog;
2. call `assertCanAcceptTicket(... expectedRevision: nil ...)`;
3. after success, update that same composite `(project_id, id)` row to
   Accepted; and
4. continue the writer's existing work.

`BEGIN IMMEDIATE` makes Backlog unobservable outside the transaction. Any
assertion or later failure rolls back the staged ticket, adjacent writer state,
and store-owned audit. Non-Accepted rows retain their current direct insert.

Exact dispatcher receipt replay is resolved before policy invocation. Exact
already-persisted Accepted Rekon data likewise remains the existing idempotent
delivery-state no-op because it performs no lane change; Rekon retains its
current per-apply audit behavior. Existing non-Accepted/imported mismatches
remain conflicts rather than becoming a new import transition surface. Sample
and Debug re-entry retain their current early return/no-second-seed-audit.

### 2. The Rekon importer has no revision contract

The approved design says the current `DeliveryArtifactImporter` is a partial
seed importer and creates no task plans. Its protocol/model files are not in
Task 4A. Task 4A therefore does not add or infer an import revision.

The importer's representable matrix is:

- new no-plan Accepted row + implicit nil revision: stage/assert/finalize;
- a plan appearing after staged insertion + nil: reject and roll back; and
- exact existing Accepted data: idempotent delivery-state no-op.

The test for the second row installs a test-local SQLite `AFTER INSERT` trigger
for one synthetic staged ticket; the trigger adds one valid pending plan/task.
The gate must see that plan and roll the whole import back. This provides the
behavioral rollback evidence without adding a product test hook or format;
source review separately confirms the named production assertion call.

The no-plan/present-revision and planned/exact-revision rows are exercised at
the policy, dispatcher, tool, and AppModel paths—the only approved contracts
that can carry a revision. Adding a Rekon/import/seed revision is a scope change
requiring owner direction.

### 3. AppModel has no current owner ticket-transition callback

Add exactly this internal, non-UI callback:

```swift
func transitionTicket(
    projectID: ProjectID,
    ticketID: TicketID,
    to lane: TicketLane,
    ticketTaskPlanRevision: Int64? = nil
) async throws -> AgentCommandResult
```

It resolves the project through the existing
`FolderProjectOnboarding.withAuthorizedProject`, uses the existing envelope
version and `requestIDGenerator`, dispatches the same transition command with
`.ownerApp`, and returns the exact dispatcher result. On committed success only,
it invokes the existing committed-command projection reload. Authorization
errors continue to throw through the existing recovery boundary; dispatcher
rejection performs no optimistic projection mutation or reload.

Before generating a request ID or calling `withAuthorizedProject`, the callback
rejects an Accepted transition whose raw `ticketID` contains embedded NUL. It
returns the same generic `.invalidEnvelope` value used by dispatcher preflight,
with empty entity IDs and nil audit ID. It does not inspect whether the prefix
names a same-project, cross-project, or missing ticket.

A need for new UI state, a button/route, or another return/error contract stops
for Architecture/product review.

## Exact command and MCP contract

Change only the existing command case, with a default for source compatibility:

```swift
case transitionTicket(
    ticketID: String,
    lane: TicketLane,
    ticketTaskPlanRevision: Int64? = nil
)
```

`upsertTicket(ticketID:phaseID:outcome:lane:)` remains unchanged.

For `release_radar_transition_ticket`:

- add optional schema property
  `ticketTaskPlanRevision: {"type":"integer","minimum":1}`;
- do not add it to `required`;
- preserve `additionalProperties: false`;
- parse present input only through
  `ReleaseRadarBridgeTransport.exactJSONInteger`, reject Boolean/fractional/
  out-of-`Int`/nonpositive input, then convert safely to `Int64`; and
- omit the associated JSON key when absent.

The tool-name set remains exactly 13. Upsert has no revision in its command,
schema, or translator. No command-envelope/wire/result version changes.

Synthesized Codable must decode old transition JSON with the missing field as
nil and encode nil without the new key. Seed an old canonical transition
receipt and prove replay through new code returns its original result instead
of `requestIDReused`.

## Validation and transition semantics

`AgentCommandDispatcher.validate` rejects before project lookup/transaction:

- every Accepted upsert;
- every Accepted transition whose raw ticket ID contains embedded NUL;
- a present revision for Backlog, In progress, Needs review, or Blocked; and
- a present revision less than 1.

Use existing `.invalidEnvelope` with non-sensitive text; add no bridge error.
The three NUL forms—valid same-project prefix plus suffix, valid cross-project
prefix plus suffix, and missing prefix plus suffix—must return an identical
error/message without querying ticket ownership. AppModel applies the same
preflight before project authorization/request generation.
Accepted upsert rejection precedes phase lookup, writable-ID checks, prior-lane
reads, insert/update, and review-occurrence handling, so absent create and
existing update have identical zero-effect behavior.

For an Accepted transition, after project/ticket ownership validation and
before lane update, dispatcher `apply` calls:

```swift
try TicketTaskPlanningPolicy.assertCanAcceptTicket(
    projectID: projectID,
    ticketID: TicketID(rawValue: ticketID),
    expectedRevision: ticketTaskPlanRevision,
    connection: connection
)
```

Only success permits the existing lane update and
`updateNeedsReviewOccurrence`. Non-Accepted/nil behavior is unchanged. Exact
receipt replay returns before `apply` and creates no second effect.

| Ticket state | Revision | Accepted result |
| --- | --- | --- |
| No plan | Nil | Existing acceptance may continue. |
| No plan | Present | Reject plan not found. |
| Loaded plan | Nil | Reject revision conflict. |
| Loaded plan | Stale | Reject revision conflict. |
| Exact plan with pending Active task | Exact | Reject incomplete tasks. |
| Exact plan with all Active tasks Completed | Exact | Accept; plan/tasks unchanged. |
| Already Accepted | Any new request | Reject terminal; exact receipt replay alone is a no-op success. |

Task 3 errors continue through the current non-disclosing dispatcher mapper;
Task 4A adds no result/error JSON.

## Accepted-path inventory

| Path | Revision input | Required behavior |
| --- | --- | --- |
| External transition | Optional | Full matrix in dispatcher transaction. |
| AppModel owner callback | Optional | Same command/gate with owner attribution. |
| Transition MCP tool | Optional | Exact integer translation; no new tool. |
| Upsert command/tool | None | Every Accepted lane rejects before effects. |
| Rekon seed import | None | Stage/assert nil/finalize; exact persisted replay remains idempotent. |
| Dashboard sample seed | None | Stage/assert nil/finalize inside its one seed transaction. |
| RR9 Debug capture/private insert helper | None | Accepted history uses the same staged branch. |

Inspection found no other production Accepted SQL writer. Final diff review
must repeat a narrow production Swift source search and reject any newly added
raw writer; do not build a custom validator.

## Transaction, audit, data, and privacy requirements

- Assertion, lane update, Needs Review occurrence handling, receipt, and audit
  commit/rollback together in the existing dispatcher transaction.
- Accepted upsert and structural revision misuse reject before transaction.
- Embedded-NUL Accepted transition IDs reject before dispatcher project lookup;
  AppModel rejects them before request generation, project authorization, or
  projection reload. Prefix content cannot change the surfaced error.
- Rekon/sample/Debug retain their current single transaction and audit shape;
  staging creates no additional activity event.
- A rejected transition leaves lane/outcome/phase, task plan/tasks, phase plan/
  goals, audit/receipt, review/owner attention, notification occurrences, and
  notification events unchanged.
- A valid transition out of Needs Review retains the current one-time
  occurrence deactivation behavior; rejection leaves it active.
- Project/ticket ownership, authorized roots, app-only SQLite access, request
  replay, helper signing/transport, sandboxing, and app-unavailable behavior are
  unchanged.
- The optional revision reveals only an integer. Do not log/store task content,
  owner paths, request bodies, credentials, database dumps, or notification
  secrets as evidence.
- Task 4A creates, revises, completes, supersedes, or deletes no task/plan and
  changes no task-plan revision.

## Test fixtures and test-first matrix

Use XCTest, existing temporary stores, existing authorized-root/bookmark
doubles, and the existing packaged-helper test path. Add no fixture file,
dependency, clock/fault framework, production test hook, or test target.

Seed synthetic no-plan, completed-plan/exact, pending-plan, stale-plan,
terminal, and upsert-update tickets. Create task plans through Task 3 policy in
fixture setup. For each rejection, compare stable before/after snapshots of the
complete state named above. Success asserts only its lane, existing receipt/
audit/owner attribution, projection refresh, and notification-occurrence delta.

For embedded-NUL tests, use a test-local counting
`AuthorizedProjectRegistry` at the dispatcher boundary and existing AppModel
authorization/request-ID/reload probes. Same-project, cross-project, and
missing ticket prefixes plus a NUL suffix must return the identical generic
error with every counter at zero and the complete state snapshot unchanged.

For Rekon/sample/Debug fail-closed tests, install the scoped test-only
`AFTER INSERT` trigger described above before calling the real writer. Current
raw Accepted insertion makes these tests RED; stage/assert/finalize makes them
GREEN only when the writer surfaces
`TicketTaskPlanningPolicyError.ticketTaskPlanRevisionConflict(expected: nil,
current: 1)` from the named Task 3 assertion and the complete pre-call delivery
snapshot is unchanged. The trigger itself is established before that snapshot;
its candidate plan/task rows, writer rows, and audit must not survive the
failed call. A corresponding fresh store without the trigger proves normal
no-plan Accepted seed behavior and existing re-entry/audit semantics.

These trigger tests are behavioral evidence of fail-closed rollback, not by
themselves proof of which production function performed the check. Code Review
must inspect the final source/diff and confirm each named writer directly calls
`TicketTaskPlanningPolicy.assertCanAcceptTicket` after staging and before its
Accepted update. Completion claims require both forms of evidence.

| Test file | Required Task 4A coverage |
| --- | --- |
| `TicketTaskPlanningPolicyAcceptanceTests` | Add only the missing-ticket check if not already explicit and one read-your-write test in which a transaction stages Backlog, invokes the existing no-plan assertion, and caller alone performs the final lane write. Do not recreate Task 3's matrix or writer orchestration here. |
| `AgentBridgeAcceptanceTests` | Full matrix, pending/stale/terminal, non-Accepted revision misuse, Accepted upsert absent/existing with/without plan, zero-effect snapshots, exact replay, old canonical receipt compatibility, and the three indistinguishable pre-lookup embedded-NUL prefixes. |
| `AgentBridgeTransportAcceptanceTests` | Tool set remains 13; transition optional schema/translation; upsert has no revision; malformed/nonpositive inputs reject; omitted legacy and exact positive inputs; packaged app-unavailable/outcome-unknown/replay remain intact. |
| `RekonImportAcceptanceTests` | No-plan Accepted stage/finalize, injected-plan full rollback, no imported task plans, current conflict and per-apply idempotence/audit behavior. |
| `AppRouteTests` | AppModel full matrix, owner audit attribution, authorization failure, no reload on rejection, reload after success, the three embedded-NUL prefixes rejected before authorization/request/reload, RR9 normal Debug projection, and injected-plan exact-error/full-snapshot rollback. |
| `ReviewAndGraphAcceptanceTests` | Sample normal projection/audit and injected-plan whole-seed rollback. |
| `NotificationAcceptanceTests` | Rejection preserves Needs Review occurrence/events/audit/receipt; valid guarded acceptance deactivates once; Accepted upsert creates no effects. |

Malformed transport coverage includes Boolean, fractional, null, zero,
negative, and out-of-`Int` revisions. Exact positive integer translation must
not use floating-point coercion.

## Happy and non-happy behavior

Happy paths:

- Legacy omitted-revision transitions retain non-Accepted behavior and accept
  atomic no-plan tickets.
- A fully completed plan accepts at exact revision without changing plan/tasks.
- Exact receipt replay returns the original result/audit with no duplicate.
- The owner callback uses identical gate semantics and refreshes committed
  state.
- Rekon/sample/Debug preserve current no-plan Accepted data and idempotence.

Non-happy paths:

- Missing/stale/misapplied revisions, pending tasks, terminal tickets, malformed
  MCP integers, and Accepted upserts reject with zero effects.
- Embedded-NUL Accepted ticket IDs reject generically before dispatcher project
  lookup and before AppModel authorization/request/reload, regardless of a
  same-project, cross-project, or missing prefix.
- Creation-only writers roll back completely if a plan appears after staging.
- Authorization/store/transport failure preserves existing recovery behavior
  and never becomes an acceptance success.

## Test-first execution and verification

### RED stage 1: executable existing-interface behavior

After the disclosed test authorization, the fresh Implementer first adds only
tests that compile against the current production interfaces:

- the two bounded policy checks (missing ticket and one read-your-write staged
  assertion);
- Accepted upsert absent-create/existing-update cases and dispatcher
  embedded-NUL Accepted transitions in `AgentBridgeAcceptanceTests`;
- Rekon, sample, and RR9 Debug scoped-trigger exact-error/full-snapshot cases;
  and
- Accepted-upsert notification/attention preservation.

Do not yet add a transition call with `ticketTaskPlanRevision`, AppModel's new
callback tests, or the new transport schema/translator assertions. Run the six
compile-compatible suites from fresh DerivedData:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task4a-red-stage1 \
  -only-testing:ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/RekonImportAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests
```

Stage 1 is valid only if the suites compile, the new tests execute, and the
Accepted upsert, embedded-NUL dispatcher boundary, and Rekon/sample/Debug
bypass assertions fail behaviorally against current production. The policy
checks may already pass; they are not the RED mechanism. The trigger failures
must show that current writers did not surface the exact Task 3 error/full
rollback. A compile failure, zero selected tests, unrelated failure, or test-
harness failure is not an accepted RED and stops before continuing.

### RED stage 2: revision-bearing interface

Only after recording valid Stage 1 behavioral RED, add the remaining test-only
changes:

- revision-bearing transition matrix and canonical compatibility;
- optional transition MCP schema/translator/malformed-input coverage;
- AppModel callback matrix, attribution, authorization/reload behavior, and
  its same/cross/missing-prefix embedded-NUL cases; and
- revision-bearing notification behavior.

Production remains untouched. Run all seven suites from a second fresh path:

```sh
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task4a-red-stage2 \
  -only-testing:ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests \
  -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests \
  -only-testing:ReleaseRadarTests/RekonImportAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests \
  -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests \
  -only-testing:ReleaseRadarTests/NotificationAcceptanceTests
```

Expected Stage 2 RED is the attributable compile failure caused only by the
absent optional transition associated value and absent AppModel callback. This
compile RED is accepted because Stage 1 already proved the existing-interface
bypasses behaviorally. Any unrelated compile failure or undeclared-path need
stops. No production edit may begin until both RED stages are valid.

### GREEN and Debug/package gate

After both valid RED stages, make the minimum production changes and run the
same seven-suite Stage 2 selection from
`/tmp/release-radar-rr-r10-task4a-green`. Every suite must compile and execute
with zero failures and zero skips.

Then build Debug from fresh output:

```sh
xcodebuild build \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task4a-debug
```

The packaged-helper tests must prove the exact tool/schema/transport contract.
No app install, owner launch/data, external plugin/provider, or network action
is permitted. The previously disclosed transient LaunchAgent
register/unregister performed by the existing transport suite is the sole
additional local system side effect and must execute its existing cleanup.
With later Git authorization, run ordinary diff checks, inspect the 15-path
ceiling, and perform the narrow Accepted-writer source search, including direct
confirmation that every creation-only Accepted branch names
`TicketTaskPlanningPolicy.assertCanAcceptTicket` between staging and final lane
update.

## Activity and audit evidence requirements

- Successful external/owner transitions retain one ticket-scope audit and one
  durable receipt with their existing agent/owner attribution.
- Exact receipt replay returns the original audit/result and creates no second
  mutation, audit, receipt, occurrence, or notification.
- Rejected transitions, revision misuse, and Accepted upserts create no audit,
  receipt, activity, review/attention, occurrence, or notification effect.
- All embedded-NUL prefix variants return one indistinguishable non-sensitive
  error with no project lookup, lane/audit/receipt/attention/notification, or
  AppModel authorization/reload effect.
- Rekon/sample/Debug success retains each writer's existing transaction/audit
  behavior; staged assertion failure rolls back the whole database mutation
  and its candidate audit.
- Ledger evidence records only test counts, categories, hashes, and audit/
  receipt counts—not task content, request bodies, owner paths, or store dumps.

## Acceptance criteria

Task 4A is complete only when:

1. Existing transition alone carries the optional revision; no new command,
   result field, tool, or version exists.
2. Legacy Swift/JSON/canonical receipt behavior remains compatible when
   revision is omitted.
3. Nonpositive and non-Accepted-destination revisions reject before mutation.
4. Embedded-NUL Accepted transition IDs reject through one indistinguishable
   preflight error before dispatcher project lookup and AppModel authorization/
   request/reload, with zero persisted or presentation effects.
5. Every dispatcher/owner Accepted update calls Task 3 in the lane transaction.
6. The full matrix succeeds/rejects exactly as specified with zero rejection
   effects and no task/plan mutation on success.
7. Accepted upsert create/update reject before effects, and upsert carries no
   revision.
8. AppModel has only the bounded internal owner callback, correct attribution,
   and success-only reload; no UI is added.
9. Rekon/sample/Debug use stage/assert nil/finalize without input-format change
   or task-plan creation; injected-plan tests surface the exact Task 3 revision
   conflict and prove complete snapshot rollback, while source review confirms
   the named assertion call.
10. Existing import conflicts, writer idempotence/audit behavior, Needs Review
   occurrence semantics, authorization, replay, and unavailable behavior remain
   intact.
11. Stage 1 compiles/executes and fails behaviorally for the existing-interface
    bypasses; Stage 2 then produces only the attributable interface compile RED.
12. All seven selected suites pass with zero failures/skips, Debug builds, and
    packaged-helper schema/transport checks pass after implementation.
13. Final implementation stays within the 15-path ceiling with no schema,
    dependency, UI, project, protocol/model, or Task 4B change.
14. Independent Code Review, QA/Test, Architecture, Security/Privacy, TPM, and
    Delivery Management return GO/Required 0 against the exact candidate.
15. With explicit Git authorization, the accepted paths plus coordinator-owned
    ledger/checksum evidence are committed/pushed and exact local/upstream/live
    remote equality with ahead/behind `0/0` is verified before Task 4B opens.

## Required independent reviews and ledger evidence

Before implementation, Architecture, QA/Test, Security/Privacy, TPM, and
Delivery Management review the exact brief. They must explicitly confirm the
staged-create resolution, no-revision importer/seed boundary, AppModel callback,
embedded-NUL pre-lookup boundary, ordered two-stage RED, matrix coverage,
transaction/rollback semantics, file ceiling, and Task 4B closure. After
implementation, an independent Code Reviewer plus the affected
roles review the exact candidate; the Implementer cannot review its own work.

Delivery Management records:

- brief SHA, reviewer identities/outcomes, Required/Optional/Out-of-scope
  counts, and exact planning/base checkpoint;
- changed-file hashes, Stage 1 executed test counts/behavioral failures, Stage 2
  attributable compile RED, per-suite GREEN counts/failures/skips, Debug build,
  and packaged-helper tool/schema results;
- matrix/upsert/AppModel/import/sample/Debug/notification rollback evidence,
  exact injected-plan Task 3 error, source-confirmed assertion calls, and
  embedded-NUL indistinguishability/no-lookup evidence;
- confirmation of no owner/external/schema/dependency/UI/Task 4B action;
- final authorized commit/push SHA and exact remote equality; and
- Task 4B as next eligible but still separately authorization-gated.

Evidence contains scalar results/hashes only, never task content, owner paths,
request bodies, database dumps, credentials, or provider data.

## Durable and temporary artifacts

This tracked brief is Planning's only durable artifact. The coordinator must
register its canonical path/checksum before implementation release.

DerivedData, result bundles, logs, test databases/triggers, temporary project
roots, and helper output are temporary. List any remaining temporary artifacts
at handoff and obtain authorization before deleting material artifacts.

## Required planning questions

No implementation question remains open within Task 4A. A request for a
revision-bearing import/seed format, new error/result/UI, second accept command,
or undeclared file is a scope change requiring owner direction.
