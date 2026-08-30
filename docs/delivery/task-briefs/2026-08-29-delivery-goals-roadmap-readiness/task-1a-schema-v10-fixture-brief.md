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
- Preserve the completed historical negative-precondition evidence from the
  original generator; do not rerun it.
- Run the attachment generator once with the exact export gate while v10
  production code is unchanged, then export its validated passing attachment
  into the absent repository fixture path from the parent process.
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

- Generate a brand-new database at a unique sandbox-writable XCTest temporary
  path, close it, and copy only its validated passing-test attachment into the
  exact absent repository fixture path; never copy or open an owner database.
- The fixture must have zero rows in `projects`, `project_roots`, `phases`,
  `tickets`, observed-thread/goal/link tables, audit tables, request receipts,
  notifications, bookmarks, review items, blockers, evidence, and completion
  records.
- Schema-owned rows such as the four `alert_rules` rows and the single
  `codex_plugin_lifecycle` row are expected v10 defaults, not owner data.
- The app process remains the only SQLite initializer. The generator uses a
  `DeliveryStore` at its unique sandbox-writable test URL; the parent process
  only exports/copies captured bytes and no helper gains SQLite authority.
- The fixture contains no path, bookmark, credential, token, project content,
  personal data, or network-derived data.
- The fixture SHA-256 makes accidental replacement or mutation detectable.
- Security/Privacy review is blocking because the fixture is the authority for
  a future local-storage migration.

## Fixtures and test strategy defined before implementation

Add this test verbatim and do not add another generator path:

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

The test intentionally fails if the export gate is absent or not exactly `1`.
It writes only to the sandbox-writable XCTest temporary directory, attaches the
closed schema-v10 database bytes to the passing result, and removes its local
temporary directory. It may be run successfully exactly once for the durable
fixture. Remove it after generation; the generator is not a deliverable.

### Historical negative generator-precondition evidence — completed, do not run

The first Implementer ran this now-retired command once without the old output
environment variable:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-rr-r10-task1a-red \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionTenFixture
```

Its recorded result was the expected failure at `XCTUnwrap` because
`RR_SCHEMA_V10_FIXTURE_OUTPUT` is absent, and no fixture file is created. This
proves generator gating; it is not represented as substantive product TDD.

This negative precondition check completed once on 2026-08-30 with the expected
result and must not be repeated by the successor Implementer. The first GREEN
attempt also failed safely at the same `XCTUnwrap`: this hosted XCTest target
does not propagate an arbitrary parent-shell variable into the test process.
It produced no fixture, the temporary generator was removed, and the worktree
retained no product or test-source change. Do not retry that shell-environment
form.

The reviewed `.xctestrun` correction was then committed and pushed at
`b62dcd12f6740c156ffd87b16c4e5741b4b9783c`. Its single generator run proved
that the environment injection works, but the sandbox correctly rejected
creating the repository fixture directory with Cocoa error 513 / POSIX error
1. It exited 65, created neither fixture nor checksum, and the temporary
generator was removed. Do not weaken or remove the app sandbox, grant a broad
write entitlement, re-sign the test host, or retry a direct repository output
path.

### GREEN generation command

Use Xcode's generated test-run specification to cross only the hosted-test
environment boundary. Start with a new absent DerivedData path, build without
running tests, identify exactly one freshly generated Release Radar format-2
`.xctestrun`, and assert its exact nested test-target environment structure
before copying it under `/tmp`. Insert only the exact export gate, then run only
the attachment generator once with parallel testing disabled and an explicit
result bundle. Run exactly:

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

Expected GREEN: the selected test passes once and retains one fixture
attachment in the explicit result bundle. The configured `.xctestrun`, build
products, sandbox-local database, and result bundle remain temporary; do not
persist a scheme, project, test-plan, entitlement, or signing change.

Immediately remove the generator source with `apply_patch` before exporting
the attachment. Then export and validate only this test's retained attachment,
and copy it into the still-absent durable fixture path:

```bash
set -euo pipefail
RR_TASK1A_RESULT=/tmp/release-radar-rr-r10-v10-attachment-result.xcresult
RR_TASK1A_ATTACHMENTS=/tmp/release-radar-rr-r10-v10-attachment-export
test -d "$RR_TASK1A_RESULT"
test ! -e "$RR_TASK1A_ATTACHMENTS"
xcrun xcresulttool export attachments \
  --test-id 'StoreAcceptanceTests/testGenerateExactVersionTenFixtureAttachment()' \
  --path "$RR_TASK1A_RESULT" \
  --output-path "$RR_TASK1A_ATTACHMENTS"
RR_TASK1A_MANIFEST="$RR_TASK1A_ATTACHMENTS/manifest.json"
test "$(plutil -extract 0.testIdentifier raw "$RR_TASK1A_MANIFEST")" = \
  'StoreAcceptanceTests/testGenerateExactVersionTenFixtureAttachment()'
if plutil -extract 1.testIdentifier raw "$RR_TASK1A_MANIFEST" >/dev/null 2>&1; then
  exit 1
fi
test "$(plutil -extract 0.attachments raw -expect array "$RR_TASK1A_MANIFEST")" = "1"
RR_TASK1A_SUGGESTED_NAME="$(plutil -extract \
  0.attachments.0.suggestedHumanReadableName raw "$RR_TASK1A_MANIFEST")"
case "$RR_TASK1A_SUGGESTED_NAME" in
  release-radar-v10_0_????????-????-????-????-????????????.sqlite) ;;
  *) exit 1 ;;
esac
RR_TASK1A_SUGGESTED_UUID="${RR_TASK1A_SUGGESTED_NAME#release-radar-v10_0_}"
RR_TASK1A_SUGGESTED_UUID="${RR_TASK1A_SUGGESTED_UUID%.sqlite}"
test "${#RR_TASK1A_SUGGESTED_UUID}" = "36"
RR_TASK1A_SUGGESTED_HEX="$(printf '%s' "$RR_TASK1A_SUGGESTED_UUID" | tr -d '-')"
test "${#RR_TASK1A_SUGGESTED_HEX}" = "32"
case "$RR_TASK1A_SUGGESTED_HEX" in
  *[!0-9A-F]*) exit 1 ;;
esac
test "$(plutil -extract 0.attachments.0.isAssociatedWithFailure raw "$RR_TASK1A_MANIFEST")" = \
  'false'
RR_TASK1A_EXPORTED_NAME="$(plutil -extract \
  0.attachments.0.exportedFileName raw "$RR_TASK1A_MANIFEST")"
case "$RR_TASK1A_EXPORTED_NAME" in
  ''|'.'|'..'|*/*) exit 1 ;;
esac
RR_TASK1A_EXPORTED="$RR_TASK1A_ATTACHMENTS/$RR_TASK1A_EXPORTED_NAME"
RR_TASK1A_FIXTURE_DIR="$PWD/ReleaseRadarTests/Fixtures/SchemaV10"
RR_TASK1A_FIXTURE="$RR_TASK1A_FIXTURE_DIR/release-radar-v10.sqlite"
test -f "$RR_TASK1A_EXPORTED"
test ! -e "$RR_TASK1A_FIXTURE"
mkdir -p "$RR_TASK1A_FIXTURE_DIR"
cp "$RR_TASK1A_EXPORTED" "$RR_TASK1A_FIXTURE"
```

Expected export: exactly one passing-test attachment whose Xcode-generated
suggested name preserves the attachment base and appends index `0` plus an
uppercase UUID before `.sqlite`; no failure attachment or second manifest
entry. The parent process creates the repository directory and copies only the
captured database bytes. The test host never gains repository write access.

### Current passing-result recovery — do not rerun the generator or export

The single attachment generator has already passed once with 1 test, 1 passed,
0 failed, 0 skipped, and 0 expected failures at:

`/tmp/release-radar-rr-r10-v10-attachment-result.xcresult`

The exact attachment export also completed before the obsolete exact-name
check stopped the command. Resume only from:

`/tmp/release-radar-rr-r10-v10-attachment-export`

Its manifest contains one passing attachment for the exact selected test,
suggested name
`release-radar-v10_0_D88C301A-B66A-4624-9EC6-A2B7A33B343A.sqlite`, and exported
basename `78312C8A-9AEF-471D-8BB6-0C89884440FF`. Read-only diagnosis reports
SQLite user version 10, integrity `ok`, 34 non-internal schema objects, and
SHA-256 `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`.
After the corrected contract is independently approved, committed, pushed,
and remotely verified, a fresh successor Implementer must run exactly this
recovery command. It validates the preserved result, exact manifest, Xcode
name pattern, safe exported basename, and diagnosed byte SHA before copying;
it does not run `build-for-testing`, `test-without-building`, or
`xcresulttool export`:

```bash
set -euo pipefail
RR_TASK1A_RESULT=/tmp/release-radar-rr-r10-v10-attachment-result.xcresult
RR_TASK1A_ATTACHMENTS=/tmp/release-radar-rr-r10-v10-attachment-export
RR_TASK1A_SUMMARY=/tmp/release-radar-rr-r10-v10-attachment-summary.json
RR_TASK1A_MANIFEST="$RR_TASK1A_ATTACHMENTS/manifest.json"
test -d "$RR_TASK1A_RESULT"
test -d "$RR_TASK1A_ATTACHMENTS"
test -f "$RR_TASK1A_MANIFEST"
test ! -e "$RR_TASK1A_SUMMARY"
git diff --exit-code -- ReleaseRadarTests/StoreAcceptanceTests.swift
xcrun xcresulttool get test-results summary \
  --path "$RR_TASK1A_RESULT" --compact > "$RR_TASK1A_SUMMARY"
test "$(plutil -extract result raw "$RR_TASK1A_SUMMARY")" = "Passed"
test "$(plutil -extract totalTestCount raw "$RR_TASK1A_SUMMARY")" = "1"
test "$(plutil -extract passedTests raw "$RR_TASK1A_SUMMARY")" = "1"
test "$(plutil -extract failedTests raw "$RR_TASK1A_SUMMARY")" = "0"
test "$(plutil -extract skippedTests raw "$RR_TASK1A_SUMMARY")" = "0"
test "$(plutil -extract expectedFailures raw "$RR_TASK1A_SUMMARY")" = "0"
test "$(plutil -extract 0.testIdentifier raw "$RR_TASK1A_MANIFEST")" = \
  'StoreAcceptanceTests/testGenerateExactVersionTenFixtureAttachment()'
if plutil -extract 1.testIdentifier raw "$RR_TASK1A_MANIFEST" >/dev/null 2>&1; then
  exit 1
fi
test "$(plutil -extract 0.attachments raw -expect array "$RR_TASK1A_MANIFEST")" = "1"
RR_TASK1A_SUGGESTED_NAME="$(plutil -extract \
  0.attachments.0.suggestedHumanReadableName raw "$RR_TASK1A_MANIFEST")"
case "$RR_TASK1A_SUGGESTED_NAME" in
  release-radar-v10_0_????????-????-????-????-????????????.sqlite) ;;
  *) exit 1 ;;
esac
RR_TASK1A_SUGGESTED_UUID="${RR_TASK1A_SUGGESTED_NAME#release-radar-v10_0_}"
RR_TASK1A_SUGGESTED_UUID="${RR_TASK1A_SUGGESTED_UUID%.sqlite}"
test "${#RR_TASK1A_SUGGESTED_UUID}" = "36"
RR_TASK1A_SUGGESTED_HEX="$(printf '%s' "$RR_TASK1A_SUGGESTED_UUID" | tr -d '-')"
test "${#RR_TASK1A_SUGGESTED_HEX}" = "32"
case "$RR_TASK1A_SUGGESTED_HEX" in
  *[!0-9A-F]*) exit 1 ;;
esac
test "$(plutil -extract 0.attachments.0.isAssociatedWithFailure raw \
  "$RR_TASK1A_MANIFEST")" = "false"
RR_TASK1A_EXPORTED_NAME="$(plutil -extract \
  0.attachments.0.exportedFileName raw "$RR_TASK1A_MANIFEST")"
case "$RR_TASK1A_EXPORTED_NAME" in
  ''|'.'|'..'|*/*) exit 1 ;;
esac
RR_TASK1A_EXPORTED="$RR_TASK1A_ATTACHMENTS/$RR_TASK1A_EXPORTED_NAME"
RR_TASK1A_FIXTURE_DIR="$PWD/ReleaseRadarTests/Fixtures/SchemaV10"
RR_TASK1A_FIXTURE="$RR_TASK1A_FIXTURE_DIR/release-radar-v10.sqlite"
test -f "$RR_TASK1A_EXPORTED"
test "$(shasum -a 256 "$RR_TASK1A_EXPORTED" | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
test ! -e "$RR_TASK1A_FIXTURE"
mkdir -p "$RR_TASK1A_FIXTURE_DIR"
cp "$RR_TASK1A_EXPORTED" "$RR_TASK1A_FIXTURE"
```

Then continue with checksum creation, complete SQLite assertions,
source-removal proof, and the regression suite already defined below.

Any mismatch stops recovery without changing the repository fixture path.

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

The historical missing-environment negative check proves the generator is
gated. The exact generation command creates one empty v10 store inside the
sandbox, captures its closed bytes as a retained passing-test attachment, and
the parent process exports exactly that attachment into the repository. Direct
SQL proves genuine version/schema identity and absence of v11 state. The local
checksum validates. The generator is removed, v10 store/lifecycle tests pass,
independent review accepts the two durable artifacts, and the exact Task 1A
commit is pushed and remotely verified before Task 1B opens.

## Non-happy paths and recovery

- If the durable repository fixture target exists before the attachment run or
  export, stop. Do not overwrite, delete, or regenerate it until the mismatch
  is investigated and the exact target is explicitly cleared through the
  normal reviewed workflow.
- If `currentVersion` is not 10, Task 1A is blocked; do not reconstruct v10 SQL
  from v11 source.
- If the GREEN test fails or the database is unavailable, retain no claimed
  fixture and diagnose the test/store failure before another materially changed
  attempt.
- If the result bundle or attachment-export path already exists, the manifest
  is not exact, the attachment is associated with failure, or the exported name
  is unsafe, stop without copying or rerunning the generator. Preserve the
  result bundle for diagnosis; a failed export may be resumed from that same
  passing result without another test execution.
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
- [ ] The historical negative precondition evidence records only the absent old
      output variable and no fixture; neither retired command was repeated.
- [ ] The exact attachment GREEN command passed once with
      `RR_SCHEMA_V10_FIXTURE_EXPORT=1`, retained exactly one passing attachment,
      and the parent exported it exactly once; the successor copied only that
      validated retained export into the absent durable fixture path without a
      generator or export rerun.
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
