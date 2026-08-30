# RR-R10 Task 1A Brief: Genuine Schema-v10 Fixture

**Status:** Canonical planning contract complete. Implementation remains closed
until Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy
review this exact registered brief and each returns GO with Required 0.

## Size assessment and split decision

Original plan Task 1 is forecast at roughly 9–12 hours of agent implementation
work and combines two sequentially sensitive review surfaces: freezing a
genuine schema-v10 database while production still reports version 10, then
adding five relational tables, public models, manifest enforcement, triggers,
foreign keys, and complete migration-preservation tests. That is too large for
one coherent review and commit under the owner's roughly-eight-hour rule.

Task 1 is therefore split without reducing its outcome:

- **Task 1A (this brief):** generate, prove, checksum, independently review,
  commit, push, and remotely verify the genuine empty schema-v10 fixture while
  `StoreMigrations.currentVersion` is still 10.
- **Task 1B:** use the verified fixture for RED migration/model tests and
  deliver the complete public-model and additive schema-v11 foundation.

Task 1A is an independently testable prerequisite artifact slice. Task 1B may
not begin until Task 1A's exact commit is on the remote branch.

## Objective and user-visible outcome

Create the immutable, repository-owned schema-v10 database that proves the
future v10-to-v11 migration starts from Release Radar's genuine current schema,
not from SQL reconstructed after v11 exists. The fixture contains schema and
required v10 singleton/default rows only; it contains no owner or project data.

There is no user-visible application change. The owner-visible value is a
trustworthy migration boundary that Task 1B can seed, migrate, relaunch, and
compare without guessing historical schema.

## Controlling product and design references

- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`,
  Global Constraints and Task 1 Steps 1–2
- `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md`,
  Complete outcome, Migration and archive behavior, Verification and
  acceptance, and Completion boundary
- `docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md`,
  additive v11 and no-inference decisions
- `docs/design/release-radar-delivery-goals-phase-board-design.md` as downstream
  context only; Task 1A changes no UI
- `docs/delivery/progress.md`, Current gate and next eligible RR-R10 work

The approved Phase Board mockups are not an acceptance surface for this
non-UI fixture task. No visual deviation or design mutation is authorized.

## In scope

- Confirm from current source that `StoreMigrations.currentVersion == 10`
  before adding the temporary generator test.
- Temporarily add exactly the approved generator test to
  `ReleaseRadarTests/StoreAcceptanceTests.swift`.
- Prove the generator's negative precondition when its required output
  environment variable is absent.
- Run that test once with the exact repository fixture output path while v10
  production code is unchanged.
- Remove the generator test immediately after successful generation.
- Prove the generated database reports `PRAGMA user_version == 10`.
- Prove it has no v11 tables, indexes, triggers, or
  `tickets.plan_legacy_continuation` column.
- Prove it contains no project/phase/ticket/observed/audit/request data and only
  the v10 schema-required default/singleton rows.
- Write and verify the fixture-local SHA-256 manifest.
- Preserve the binary fixture and its digest as durable Task 1B inputs.

## Out of scope

- Any modification to `StoreMigrations.swift`, `DeliveryStore.swift`, model
  files, shipping code, Xcode project membership, or a schema version
- Leaving a generator, fixture-writer, runtime fixture mode, or generated
  project data in source control
- v11 tables, columns, indexes, triggers, foreign keys, public Delivery Goal
  models, migration logic, or migration preservation tests; Task 1B owns them
- Any inferred Delivery Goal, ticket assignment, or continuation grant
- Ticket, lane, phase, active-phase, board, audit, notification, or owner-data
  mutation
- Launching or installing the application, opening an owner database, using
  the bridge/MCP surface, or changing any external state
- Implementer edits to `docs/delivery/progress.md`; Delivery Management alone
  records the reviewed evidence after implementation

## Dependencies and release gate

- The approved RR-R10 plan/spec/ADR/board contract and their verified Git
  checkpoint are prerequisites.
- `StoreMigrations.currentVersion` must still be 10 and the fixture target must
  not exist before the GREEN generation command.
- This exact brief and its root checksum entry must be independently reviewed
  by Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy.
  Every role must return GO with Required 0 before the temporary test is added.
- After those preimplementation reviews close, the split plan, both exact
  briefs, checksum index, planning/review ledger evidence, and the owner-
  directed `.gitignore` change must be committed, pushed, and verified at an
  exact planning-only remote checkpoint before the temporary test is added.
- One fresh Implementer owns only the temporary generator edit and the two
  fixture artifacts. No concurrent writer may modify
  `StoreAcceptanceTests.swift` or the fixture directory.
- After implementation, a separate Code Reviewer and QA verifier, plus
  Architecture, Security/Privacy, TPM, and Delivery Management, must return GO
  with Required 0 before any Task 1A commit or push.

## Affected subsystem and anticipated files

Durable outputs:

- `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`

Coordinator-owned checkpoint paths:

- `.gitignore` — the owner-directed `default.profraw` ignore rule
- `docs/delivery/progress.md` — exact planning, implementation, review, and Git evidence
- `docs/delivery/task-briefs/SHA256SUMS`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md`
- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md` — owner-size split only

These coordinator paths belong to the planning-only checkpoint before
implementation. They are not bundled into Task 1A's postimplementation fixture
commit.

Temporary implementation edit, required to be absent from the final diff:

- `ReleaseRadarTests/StoreAcceptanceTests.swift`

No product file may change. The repository uses file-system-synchronized Xcode
groups; no `project.pbxproj` change is required.

## Data, persistence, security, and privacy implications

- Generate a brand-new database at the exact fixture path; never copy or open
  an owner database.
- The fixture must have zero rows in `projects`, `project_roots`, `phases`,
  `tickets`, observed-thread/goal/link tables, audit tables, request receipts,
  notifications, bookmarks, review items, blockers, evidence, and completion
  records.
- Schema-owned rows such as the four `alert_rules` rows and the single
  `codex_plugin_lifecycle` row are expected v10 defaults, not owner data.
- The app process remains the only SQLite initializer. The generator uses a
  `DeliveryStore` at the explicitly supplied test URL; no helper gains SQLite
  authority.
- The fixture contains no path, bookmark, credential, token, project content,
  personal data, or network-derived data.
- The fixture SHA-256 makes accidental replacement or mutation detectable.
- Security/Privacy review is blocking because the fixture is the authority for
  a future local-storage migration.

## Fixtures and test strategy defined before implementation

Add this test verbatim and do not add another generator path:

```swift
func testGenerateExactVersionTenFixture() throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try XCTUnwrap(environment["RR_SCHEMA_V10_FIXTURE_OUTPUT"])
    let url = URL(fileURLWithPath: path)
    XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    _ = DeliveryStore(databaseURL: url)
    XCTAssertEqual(try SQLiteConnection(url: url).scalarInt("PRAGMA user_version"), 10)
}
```

The test intentionally fails if the environment variable is absent or the
target already exists. It may be run successfully exactly once for the durable
fixture. Remove it after generation; the generator is not a deliverable.

### Negative generator-precondition check

Run without the environment variable:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task1a-red \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionTenFixture
```

Expected negative result: the selected test fails at `XCTUnwrap` because
`RR_SCHEMA_V10_FIXTURE_OUTPUT` is absent, and no fixture file is created. This
proves generator gating; it is not represented as substantive product TDD.

This negative precondition check completed once on 2026-08-30 with the expected
result and must not be repeated by the successor Implementer. The first GREEN
attempt also failed safely at the same `XCTUnwrap`: this hosted XCTest target
does not propagate an arbitrary parent-shell variable into the test process.
It produced no fixture, the temporary generator was removed, and the worktree
retained no product or test-source change. Do not retry that shell-environment
form.

### GREEN generation command

Use Xcode's generated test-run specification to cross the hosted-test
environment boundary. Build without running tests, identify exactly one
generated Release Radar `.xctestrun`, copy it under `/tmp`, insert the fixture
variable into its documented `EnvironmentVariables` dictionary, and run only
the generator once with parallel testing disabled. Run exactly:

```bash
set -euo pipefail
RR_TASK1A_DERIVED=/tmp/release-radar-rr-r10-v10-fixture
xcodebuild build-for-testing -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' -derivedDataPath "$RR_TASK1A_DERIVED"
RR_TASK1A_XCTESTRUN="$(rg --files --hidden --no-ignore "$RR_TASK1A_DERIVED/Build/Products" \
  | rg '/ReleaseRadar_ReleaseRadar_.*\.xctestrun$')"
test -n "$RR_TASK1A_XCTESTRUN"
test "$(printf '%s\n' "$RR_TASK1A_XCTESTRUN" | wc -l | tr -d ' ')" = "1"
RR_TASK1A_CONFIGURED="$RR_TASK1A_DERIVED/Build/Products/ReleaseRadar_Task1A.xctestrun"
cp "$RR_TASK1A_XCTESTRUN" "$RR_TASK1A_CONFIGURED"
plutil -insert \
  TestConfigurations.0.TestTargets.0.EnvironmentVariables.RR_SCHEMA_V10_FIXTURE_OUTPUT \
  -string "$PWD/ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite" \
  "$RR_TASK1A_CONFIGURED"
xcodebuild test-without-building -xctestrun "$RR_TASK1A_CONFIGURED" \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionTenFixture
```

Expected GREEN: the selected test passes, the target is created once, and
direct inspection reports schema version 10. The configured `.xctestrun` and
all build products remain temporary under `/tmp`; do not persist a scheme,
project, or test-plan environment change.

After removing the generator, create the fixture-local checksum from the
fixture directory so its manifest contains only the filename:

```bash
cd ReleaseRadarTests/Fixtures/SchemaV10
shasum -a 256 release-radar-v10.sqlite > SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

Directly verify complete schema identity, privacy emptiness, exact defaults,
and foreign-key integrity. The assertion table makes any mismatch return a
nonzero `sqlite3` exit instead of relying on visual inspection:

```bash
sqlite3 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite <<'SQL'
.bail on
CREATE TEMP TABLE fixture_assertions (value INTEGER NOT NULL CHECK (value = 1));
INSERT INTO fixture_assertions
SELECT (SELECT user_version FROM pragma_user_version) = 10;
INSERT INTO fixture_assertions
SELECT (
  (SELECT COUNT(*) FROM projects) +
  (SELECT COUNT(*) FROM project_roots) +
  (SELECT COUNT(*) FROM phases) +
  (SELECT COUNT(*) FROM tickets) +
  (SELECT COUNT(*) FROM phase_dependencies) +
  (SELECT COUNT(*) FROM ticket_dependencies) +
  (SELECT COUNT(*) FROM blockers) +
  (SELECT COUNT(*) FROM evidence) +
  (SELECT COUNT(*) FROM thread_exclusions) +
  (SELECT COUNT(*) FROM observed_threads) +
  (SELECT COUNT(*) FROM observed_goals) +
  (SELECT COUNT(*) FROM thread_links) +
  (SELECT COUNT(*) FROM review_items) +
  (SELECT COUNT(*) FROM audit_events) +
  (SELECT COUNT(*) FROM notification_events) +
  (SELECT COUNT(*) FROM completion_records) +
  (SELECT COUNT(*) FROM agent_command_requests) +
  (SELECT COUNT(*) FROM project_bookmarks) +
  (SELECT COUNT(*) FROM project_active_phases) +
  (SELECT COUNT(*) FROM notification_occurrences) +
  (SELECT COUNT(*) FROM ticket_goal_links)
) = 0;
INSERT INTO fixture_assertions
SELECT COUNT(*) = 4
   AND SUM(CASE kind
       WHEN 'blocked_linked_goals' THEN is_enabled = 1
       WHEN 'agent_completion_and_review' THEN is_enabled = 1
       WHEN 'needs_review_entry' THEN is_enabled = 1
       WHEN 'paused_goals' THEN is_enabled = 0
       ELSE 0 END) = 4
FROM alert_rules;
INSERT INTO fixture_assertions
SELECT COUNT(*) = 1
   AND SUM(plugin_id = 'release-radar'
       AND intent = 'neverInstalled'
       AND managed_version IS NULL
       AND managed_digest IS NULL
       AND verified_at IS NULL) = 1
FROM codex_plugin_lifecycle;
INSERT INTO fixture_assertions
SELECT COUNT(*) = 0
FROM pragma_table_info('tickets')
WHERE name = 'plan_legacy_continuation';
INSERT INTO fixture_assertions
WITH expected(type, name) AS (VALUES
  ('index', 'audit_events_project_entity_index'),
  ('index', 'notification_events_project_created_index'),
  ('index', 'notification_events_state_index'),
  ('index', 'observed_goals_project_identity_unique'),
  ('index', 'project_active_phases_phase_index'),
  ('index', 'ticket_goal_links_project_goal_unique'),
  ('index', 'ticket_goal_links_project_ticket_unique'),
  ('table', 'agent_command_requests'),
  ('table', 'alert_rules'),
  ('table', 'audit_events'),
  ('table', 'blockers'),
  ('table', 'codex_plugin_lifecycle'),
  ('table', 'completion_records'),
  ('table', 'evidence'),
  ('table', 'notification_events'),
  ('table', 'notification_occurrences'),
  ('table', 'observed_goals'),
  ('table', 'observed_threads'),
  ('table', 'phase_dependencies'),
  ('table', 'phases'),
  ('table', 'project_active_phases'),
  ('table', 'project_bookmarks'),
  ('table', 'project_roots'),
  ('table', 'projects'),
  ('table', 'review_items'),
  ('table', 'thread_exclusions'),
  ('table', 'thread_links'),
  ('table', 'ticket_dependencies'),
  ('table', 'ticket_goal_links'),
  ('table', 'tickets'),
  ('trigger', 'reject_phase_dependency_cycle_insert'),
  ('trigger', 'reject_phase_dependency_cycle_update'),
  ('trigger', 'reject_ticket_dependency_cycle_insert'),
  ('trigger', 'reject_ticket_dependency_cycle_update')
), actual(type, name) AS (
  SELECT type, name FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'
), difference AS (
  SELECT type, name FROM expected EXCEPT SELECT type, name FROM actual
  UNION ALL
  SELECT type, name FROM actual EXCEPT SELECT type, name FROM expected
)
SELECT COUNT(*) = 0 FROM difference;
INSERT INTO fixture_assertions
SELECT COUNT(*) = 0 FROM pragma_foreign_key_check;
INSERT INTO fixture_assertions
SELECT (SELECT integrity_check FROM pragma_integrity_check) = 'ok';
SQL
```

Expected: exit 0 with every v10 application table present; all 21 non-default
tables empty; exact four alert-rule rows and exact `release-radar` /
`neverInstalled` lifecycle singleton; the exact 23-table, seven-index,
four-trigger v10 inventory and no extra v11 object; no continuation column;
empty `foreign_key_check`; and `integrity_check = ok`.

Finally prove the temporary source edit is gone and the current v10 boundary
still passes:

```bash
git diff --exit-code -- ReleaseRadarTests/StoreAcceptanceTests.swift
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task1a-regression \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests
```

## Happy path

The missing-environment negative check proves the generator is gated. The exact
generation command creates one empty v10 store. Direct SQL proves genuine version/schema
identity and absence of v11 state. The local checksum validates. The generator
is removed, v10 store/lifecycle tests pass, independent review accepts the two
durable artifacts, and the exact Task 1A commit is pushed and remotely verified
before Task 1B opens.

## Non-happy paths and recovery

- If the target exists before generation, stop. Do not overwrite, delete, or
  regenerate it until the mismatch is investigated and the exact target is
  explicitly cleared through the normal reviewed workflow.
- If `currentVersion` is not 10, Task 1A is blocked; do not reconstruct v10 SQL
  from v11 source.
- If the GREEN test fails or the database is unavailable, retain no claimed
  fixture and diagnose the test/store failure before another materially changed
  attempt.
- If direct inspection finds project data, v11 objects, a wrong singleton
  count, a foreign-key error, or a digest mismatch, return NO-GO and do not
  commit or release Task 1B.
- If the temporary generator remains in the final diff, Task 1A is incomplete.
- No failure authorizes opening owner data, launching the app, or editing the
  migration to make fixture generation pass.

## Activity and audit evidence requirements

This repository-only fixture task creates no Release Radar audit, Activity,
notification, review-inbox, bridge request, or ticket evidence. Required
evidence is the test transcript, direct SQLite output, fixture SHA-256,
generator-removal diff, independent dispositions, Git commit, push, and exact
remote-SHA equality recorded by Delivery Management.

## Acceptance criteria

- [ ] Preimplementation Architecture, TPM, QA/Test, Delivery Management, and
      Security/Privacy reviews are GO with Required 0 on this exact SHA.
- [ ] The exact planning-only path set is committed, pushed, and remotely
      verified before the temporary generator is added.
- [ ] `StoreMigrations.currentVersion` was 10 throughout generation and no
      product source changed.
- [ ] The required negative precondition check failed only because the output
      environment variable was absent and created no fixture.
- [ ] The exact GREEN command passed and created the exact durable fixture.
- [ ] Direct inspection proves schema version 10, expected empty/default-row
      inventory, no v11 table/column/index/trigger, and no foreign-key error.
- [ ] `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS` contains the exact
      SHA-256 and `shasum -a 256 -c` passes.
- [ ] The generator test is absent from the final diff.
- [ ] Selected Store and plugin-lifecycle regression tests pass at schema 10.
- [ ] No owner data, app launch/install, board mutation, bridge call, ticket
      mutation, external state, or unrelated file was touched.
- [ ] `.gitignore` contains exactly the owner-directed `default.profraw` entry,
      and the file is ignored without being staged or deleted.
- [ ] Postimplementation Code Review, QA/Test, Architecture, Security/Privacy,
      TPM, and Delivery Management return GO with Required 0.
- [ ] No partial or unverified commit exists; only the exact Task 1A artifacts
      are staged after the full gate.
- [ ] The Task 1A commit is pushed and local HEAD equals the exact remote branch
      SHA before Task 1B is released.

## Required independent reviews

Before implementation: Architecture, TPM, QA/Test, Delivery Management, and
Security/Privacy. After implementation: a fresh Code Reviewer, fresh QA
verifier, Architecture, Security/Privacy, TPM, and Delivery Management. No
Implementer may review or independently verify its own work. Required 0 is a
hard gate; optional or out-of-scope findings do not expand this task.

## Completion evidence required in `docs/delivery/progress.md`

Delivery Management must record:

- Task 1A status, dependency gate, Implementer identity, and exact brief SHA
- current-version precondition and exact negative/generation commands/results
- fixture path, byte size, SHA-256, checksum verification, direct SQL output,
  exact full v10 schema-object/default-row inventory, and confirmation that no
  v11 object or owner data exists
- proof the temporary generator was removed and the final source diff is empty
- selected regression command/result
- pre- and postimplementation reviewer identities, GO/NO-GO dispositions,
  Required/Optional/Out-of-scope counts, and Required 0 closure
- confirmation of no owner-data launch, board/ticket mutation, external state,
  or unrelated-file change
- exact staged paths, reviewed staged diff, commit SHA, push result,
  `git ls-remote` remote SHA, local/remote equality, and ahead/behind `0/0`
- remaining risks/blockers and Task 1B as the next eligible task only after the
  remote checkpoint

## Task-specific completion and Git boundary

Before implementation, the preimplementation Required-0 gate must create and
remotely verify one planning-only checkpoint containing exactly:

```text
.gitignore
docs/delivery/progress.md
docs/delivery/task-briefs/SHA256SUMS
docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md
docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md
docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md
```

Only after exact remote equality may the Implementer add the temporary
generator. Task 1A is complete only when the genuine v10 fixture and its
fixture-local checksum pass every check and independent postimplementation gate
with Required 0. Before that point, do not commit or push implementation work.
Afterward, stage only:

```text
ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite
ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS
docs/delivery/progress.md
```

Inspect the staged diff/inventory, commit, push
`codex/release-radar-mvp`, and verify local HEAD equals the exact remote SHA.
The removed generator, already-checkpointed planning paths, Task 1B product
work, `default.profraw` itself, and every unrelated path are excluded. Task 1B
stays closed until this remote checkpoint is exact.
