# RR-R10 Task 2A Brief: Genuine Schema-v11 Fixture

**Status:** Canonical planning contract complete. Implementation remains closed
until this exact registered brief is independently reviewed by Architecture,
TPM, QA/Test, and Delivery Management and every role returns GO with Required
0. Because this fixture freezes the authoritative local-storage boundary,
Security/Privacy also reviews the brief before implementation.

## Size assessment and checkpoint decision

The accepted implementation plan forecasts Task 2A at roughly 3–5 agent-hours.
It has one coherent, independently testable outcome: migrate the accepted empty
schema-v10 fixture through the accepted Task 1B product, capture the resulting
privacy-empty schema-v11 database, and prove its exact identity. It is below the
owner's roughly-eight-hour split threshold and has one review surface, so no
further split is warranted.

Task 2A produces only the schema-v11 fixture and its local checksum. It adds no
product behavior or API and does not begin Task 2B.

## Objective and user-visible outcome

Generate and verify the immutable, repository-owned schema-v11 fixture that
Task 2B will use as the genuine additive v11-to-v12 migration boundary. Start
only from a checksum-verified copy of the accepted schema-v10 fixture, open that
copy through the exact accepted Task 1B `DeliveryStore`, prove the complete
schema-v11 manifest and zero Delivery Goal planning rows, close the store, and
capture only those migrated bytes.

There is no user-visible application change. The owner-visible value is a
trustworthy migration boundary whose provenance is the accepted v10 fixture
plus the accepted Task 1B implementation, not SQL reconstructed after schema
v12 exists.

## Controlling references and immutable hashes

- `docs/design/release-radar-ticket-tasks-design.md`, especially Data contract,
  Planning-package status and delivery-state handoff, RR-R10 command
  availability sequence, and Acceptance criteria; accepted SHA-256
  `c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08`
- `docs/architecture/ADR-005-ticket-task-work-plans.md`, especially Decision,
  Persistence boundary, and Owner-install boundary; accepted SHA-256
  `6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5`
- `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`,
  Global Constraints, Ticket Tasks course correction, Task 2A, and checkpoint
  sizing; accepted SHA-256
  `2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1a-schema-v10-fixture-brief.md`,
  registered SHA-256
  `d9e77073932c3f46a4fba210f9c6ab0f150fdcb11b089529dcc87010d492cded`
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-1b-v11-persistence-models-brief.md`,
  registered SHA-256
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`
- `docs/delivery/progress.md`, Current gate, accepted Task 1A/1B checkpoints,
  accepted Ticket Tasks planning package, schema-v10 start-state proof, audited
  RR-R10 start handoff, and next eligible RR-R10 work

The accepted Phase Board mockup is downstream context only. Task 2A changes no
UI and authorizes no visual deviation.

Architecture's accepted planning review recorded two nonblocking
implementation-brief refinements without persisting separate wording. This
brief does not invent new requirements from that note. It directly applies the
accepted package's relevant boundaries: exact fixture provenance and a
fail-closed generator/manifest verification path. The exact-hash reviewers
decide whether those boundaries are complete.

## Immutable dependency evidence and release gate

- The accepted Ticket Tasks planning checkpoint is commit
  `ab0a08811684265ea0dadc8e370c79a3c8f559ee`, pushed and remotely exact.
- Task 1A is accepted at commit
  `ace6c59efc3c95ee23542f8ae9e31fdfb26f6054`, and its fixture bytes are
  immutable at SHA-256
  `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`.
- Task 1B is accepted at commit
  `b711229a109c1a58c9616e4ff907afb18cd4f958`, pushed and remotely exact. Its
  five registered product/test paths are the exact schema-v11 authority.
- The governed start handoff is complete. RR-R10 is already In progress, with
  blocker-resolution audit `44783DB0-14B9-4912-BF49-136CDB62CB88` and start
  audit `7A91291D-1098-4D45-806C-AE12A3A693E3`. Task 2A performs no Release
  Radar mutation and does not repeat either request.
- No Ticket Tasks plan exists yet. Task 2A must not create, infer, revise, or
  complete one. The 16-row live plan remains a Task 7A action.
- This exact brief and its root checksum entry must be independently reviewed
  by Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy.
  Every role must return GO with Required 0 before the RED source edit.
- The coordinator records the exact brief SHA and reviewer dispositions in
  `docs/delivery/progress.md`. The canonical brief, root checksum registry, and
  coordinator-owned release evidence must be committed, pushed, and verified
  at exact local/remote equality before an Implementer writes the RED test.
- One fresh serialized Implementer owns only the temporary generator edit and
  the two fixture artifacts. No concurrent writer may modify
  `StoreAcceptanceTests.swift` or either fixture directory.
- After implementation, a separate Code Reviewer and QA verifier, plus
  Architecture, Security/Privacy, TPM, and Delivery Management, must return GO
  with Required 0 before the Task 2A implementation checkpoint is committed or
  Task 2B opens.

## In scope

- Verify the accepted design, ADR, and plan hashes above before implementation.
- Verify the accepted schema-v10 fixture against its local `SHA256SUMS` and
  pinned digest before RED and again after all Task 2A work.
- Verify the five Task 1B product/test paths are byte-identical to their
  accepted commit before RED.
- Temporarily add exactly one gated XCTest attachment generator and its
  generator-local throwing v10 verification/copy boundary to
  `ReleaseRadarTests/StoreAcceptanceTests.swift`.
- Run the selected generator once without its gate and inspect the preserved
  RED result bundle to prove exactly 1/1 selected test failed specifically at
  the missing `RR_SCHEMA_V11_FIXTURE_EXPORT` `XCTUnwrap`, with zero skipped or
  expected failures and zero retained attachments.
- Run the gated attachment generator exactly once through the already-proven
  sandbox-safe format-2 `.xctestrun` path.
- Start from a test-local copy of the accepted v10 fixture, open it through
  `DeliveryStore`, and require `.available` at schema version 11.
- Assert all accepted v11 tables, explicit indexes, triggers, continuation
  column properties, default/singleton rows, and zero planning/owner rows.
- Close every SQLite owner before reading and attaching the database bytes.
- Prove the fresh GREEN result is Passed 1/1 with zero failed, skipped, or
  expected failures, then remove the temporary generator immediately.
- Export exactly one passing attachment under an exclusively created temporary
  parent; reject symlinks and containment escapes while validating its
  manifest, Xcode-suggested name, and safe exported basename.
- Copy only the validated exported bytes into the absent schema-v11 fixture
  path from the parent process.
- Create and verify the fixture-local SHA-256 manifest.
- Run complete direct SQLite assertions plus the exact Store and plugin-
  lifecycle regression selection.

## Out of scope

- Any durable product or test-source change, including
  `StoreMigrations.swift`, `DeliveryStore.swift`, model files, Xcode project
  membership, or a schema version change
- Any change to the accepted schema-v10 fixture or checksum, accepted Task 1B
  SQL/manifest/model/test semantics, or the accepted commits above
- Schema v12, `ticket_task_plans`, `ticket_tasks`, Ticket Task models, policies,
  commands, MCP tools, task projections, or acceptance enforcement; Task 2B and
  successors own them
- Seeding a project, phase, ticket, Delivery Goal, assignment, observed goal,
  audit, notification, request receipt, bookmark, or owner value into the
  fixture
- Leaving a generator, runtime fixture mode, environment setting, scheme,
  test plan, entitlement, signing change, result bundle, or export directory in
  source control
- Launching or installing the owner-facing Release Radar bundle outside the
  required isolated XCTest host, opening or inspecting the owner's SQLite
  store, using owner UI, calling MCP/bridge tools, mutating RR-R10,
  reopening/upserting any Accepted ticket, or changing any external state
- Creating the live 16-row RR-R10 Ticket Tasks plan or treating this repository
  checkpoint as a live task completion
- Implementer edits to `docs/delivery/progress.md`; coordinator/Delivery
  Management owns the ledger evidence

## Affected subsystem and anticipated files

Durable implementation outputs:

- `ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite`
- `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS`

Durable planning outputs, completed before implementation:

- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md`
- `docs/delivery/task-briefs/SHA256SUMS`

Coordinator-owned evidence:

- `docs/delivery/progress.md`

Temporary implementation edit, required to be absent from the final diff:

- `ReleaseRadarTests/StoreAcceptanceTests.swift`

Consumed unchanged:

- `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`
- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarCore/Store/DeliveryStore.swift`
- `ReleaseRadarCore/Models/DeliveryGoalModels.swift`
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`

The repository uses file-system-synchronized Xcode groups, so no
`project.pbxproj` change is required.

## Data, persistence, security, and privacy implications

- The only database opened for migration is a unique XCTest-temporary copy of
  the checksum-verified repository v10 fixture. The owner database, app
  container, bookmarks, credentials, Keychain, and authorized project content
  are never opened.
- The temporary generator parses the exact local v10 manifest and requires its
  pinned digest and the source bytes' computed digest to match before it
  creates, copies, or opens any destination database. It writes those exact
  verified bytes with no-overwrite semantics into an exclusively created test
  temporary directory, proves the copy still reports schema version 10, and
  only then gives the URL to `DeliveryStore`.
- `DeliveryStore` remains the only schema initializer. The test host uses the
  accepted app-owned store path at a sandbox-writable temporary URL; the parent
  process only validates and copies the retained attachment bytes.
- The generated database contains no owner or synthetic project data. The four
  `alert_rules` rows and one `codex_plugin_lifecycle` row are schema-required
  defaults, not owner data.
- Migration of the empty v10 fixture must create zero phase plans, Delivery
  Goals, criteria, assignments, and assignment events. It has no tickets and
  therefore no migration-continuation row.
- The fixture is one closed standalone SQLite main file. A WAL or SHM sidecar
  at attachment time is a failure, as is a rollback journal; none is an
  additional artifact to copy.
- Every result, export, manifest, and exported-attachment path is beneath an
  exclusively created unique temporary parent. No-follow metadata checks reject
  symlinks, and canonical-path checks reject any containment escape before a
  file is read or copied.
- `SchemaV11` must be wholly absent, including as a broken symlink. Its existing
  canonical parent must be the repository fixture directory; the parent process
  creates `SchemaV11` once with plain `mkdir` and writes the validated bytes
  using exclusive no-clobber output rather than ordinary `cp`.
- The fixture-local SHA-256 makes replacement or mutation detectable. Task 2B
  must consume it unchanged.
- No helper, bridge, UI, import path, or external process gains SQLite
  authority. No network access or notification dispatch occurs.
- Security/Privacy review is blocking because this fixture becomes the
  authority for the next local-store migration.

## Exact schema-v11 fixture contract

The genuine fixture must report `PRAGMA user_version = 11` and contain exactly
28 application tables, 12 explicit indexes, and 8 triggers (48 non-internal
schema objects total).

The five v11 planning tables exist but contain zero rows:

- `phase_plans`
- `delivery_goals`
- `delivery_goal_done_criteria`
- `delivery_goal_ticket_assignments`
- `delivery_goal_assignment_events`

The additive `tickets.plan_legacy_continuation` column is `INTEGER NOT NULL
DEFAULT 0`; the canonical accepted Task 1B manifest validation must pass. No
v12 table, index, trigger, column, or row exists.

Every owner-data table is empty. The only rows are exactly:

- four `alert_rules`: `blocked_linked_goals = 1`,
  `agent_completion_and_review = 1`, `needs_review_entry = 1`, and
  `paused_goals = 0`; and
- one `codex_plugin_lifecycle` row for `release-radar` with intent
  `neverInstalled` and null managed version, digest, and verification time.

`PRAGMA foreign_key_check` returns no row and `PRAGMA integrity_check` returns
exactly `ok`.

## Test fixture and exact test-first strategy

Use only XCTest, CryptoKit/Foundation/Darwin already available to the test
target, `DeliveryStore`, `SQLiteConnection`, Xcode's generated `.xctestrun`,
system `xcresulttool`, `sqlite3`, and `shasum`. Do not call the existing
nonthrowing-assertion-based `copyVerifiedVersionTenFixture()` helper from the
generator. Add no durable helper, dependency, or harness.

### Temporary generator source

Temporarily add `import Darwin` beside the existing imports, then add this
generator-local throwing verification/copy boundary and one test inside
`StoreAcceptanceTests` before RED. Do not alter the existing helper, add
another generator, or add a shipping/debug fixture mode:

```swift
private struct Task2AGeneratorInput {
    let databaseURL: URL
    let cleanupDirectoryURL: URL
}

private func makeVerifiedTask2AGeneratorInput() throws -> Task2AGeneratorInput {
    let pinnedDigest = "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
    let fixtureDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/SchemaV10", isDirectory: true)
    let manifestURL = fixtureDirectory.appendingPathComponent("SHA256SUMS")
    let sourceURL = fixtureDirectory.appendingPathComponent("release-radar-v10.sqlite")
    let expectedManifest = "\(pinnedDigest)  release-radar-v10.sqlite\n"
    let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
    guard manifest == expectedManifest else {
        throw NSError(
            domain: "RRTask2AGenerator",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "SchemaV10 manifest is not the exact pinned manifest"]
        )
    }

    let verifiedData = try Data(contentsOf: sourceURL)
    let computedDigest = SHA256.hash(data: verifiedData)
        .map { String(format: "%02x", $0) }
        .joined()
    guard computedDigest == pinnedDigest else {
        throw NSError(
            domain: "RRTask2AGenerator",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "SchemaV10 bytes do not match the pinned digest"]
        )
    }

    var template = Array(
        (FileManager.default.temporaryDirectory.path
            + "/release-radar-task2a-generator.XXXXXX").utf8CString
    )
    let directoryPath: String? = template.withUnsafeMutableBufferPointer { buffer in
        guard let pointer = mkdtemp(buffer.baseAddress) else { return nil }
        return String(cString: pointer)
    }
    guard let directoryPath else {
        throw NSError(
            domain: "RRTask2AGenerator",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Could not create the exclusive Task 2A directory"]
        )
    }

    let cleanupDirectoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
    let databaseURL = cleanupDirectoryURL.appendingPathComponent("release-radar-v10.sqlite")
    do {
        try verifiedData.write(to: databaseURL, options: .withoutOverwriting)
        let copiedData = try Data(contentsOf: databaseURL)
        let copiedDigest = SHA256.hash(data: copiedData)
            .map { String(format: "%02x", $0) }
            .joined()
        guard copiedDigest == pinnedDigest else {
            throw NSError(
                domain: "RRTask2AGenerator",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Task 2A copy changed the verified v10 bytes"]
            )
        }
        let copiedFixture = try SQLiteConnection(url: databaseURL)
        guard try copiedFixture.scalarInt("PRAGMA user_version") == 10 else {
            throw NSError(
                domain: "RRTask2AGenerator",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Task 2A input is not schema version 10"]
            )
        }
    } catch {
        try? FileManager.default.removeItem(at: cleanupDirectoryURL)
        throw error
    }
    return Task2AGeneratorInput(
        databaseURL: databaseURL,
        cleanupDirectoryURL: cleanupDirectoryURL
    )
}

func testGenerateExactVersionElevenFixtureAttachment() async throws {
    let environment = ProcessInfo.processInfo.environment
    let exportGate = try XCTUnwrap(environment["RR_SCHEMA_V11_FIXTURE_EXPORT"])
    guard exportGate == "1" else {
        XCTFail("RR_SCHEMA_V11_FIXTURE_EXPORT must equal 1")
        return
    }

    let input = try makeVerifiedTask2AGeneratorInput()
    defer { try? FileManager.default.removeItem(at: input.cleanupDirectoryURL) }
    let databaseURL = input.databaseURL
    var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
    guard case .available = await store!.availability else {
        return XCTFail("Expected the accepted v10 fixture to migrate to schema version 11")
    }

    do {
        let connection = try SQLiteConnection(url: databaseURL)
        XCTAssertEqual(try connection.scalarInt("PRAGMA user_version"), 11)
        XCTAssertEqual(
            try connection.scalarInt(
                "SELECT COUNT(*) FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'"
            ),
            48
        )
        XCTAssertEqual(
            try connection.scalarInt(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
            ),
            28
        )
        XCTAssertEqual(
            try connection.scalarInt(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'index' AND name NOT LIKE 'sqlite_%'"
            ),
            12
        )
        XCTAssertEqual(
            try connection.scalarInt(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'trigger' AND name NOT LIKE 'sqlite_%'"
            ),
            8
        )
        XCTAssertEqual(
            try connection.scalarInt(
                """
                SELECT
                    (SELECT COUNT(*) FROM phase_plans) +
                    (SELECT COUNT(*) FROM delivery_goals) +
                    (SELECT COUNT(*) FROM delivery_goal_done_criteria) +
                    (SELECT COUNT(*) FROM delivery_goal_ticket_assignments) +
                    (SELECT COUNT(*) FROM delivery_goal_assignment_events)
                """
            ),
            0
        )
        XCTAssertEqual(
            try connection.scalarInt(
                "SELECT COUNT(*) FROM tickets WHERE plan_legacy_continuation <> 0"
            ),
            0
        )
        XCTAssertNil(try connection.row("PRAGMA foreign_key_check"))
        XCTAssertEqual(try connection.scalarText("PRAGMA integrity_check"), "ok")
    }

    withExtendedLifetime(store) {}
    store = nil
    for suffix in ["-wal", "-shm", "-journal"] {
        guard !FileManager.default.fileExists(atPath: databaseURL.path + suffix) else {
            throw NSError(
                domain: "RRTask2AGenerator",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Task 2A database retained a SQLite sidecar"]
            )
        }
    }

    let attachment = XCTAttachment(
        data: try Data(contentsOf: databaseURL),
        uniformTypeIdentifier: "public.data"
    )
    attachment.name = "release-radar-v11.sqlite"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

The export gate is checked before the throwing verifier is called, so an
absent/wrong gate creates no generator directory, database, migration, or
attachment. The verifier accepts only the exact one-line local manifest and
pinned v10 bytes; every validation through copied schema version 10 throws
before `DeliveryStore` can open an unverified input. Remove the import, helper,
struct, and test byte-exactly after the one accepted GREEN run; no part is a
durable helper change.

### Pre-RED immutable-boundary checks

Run from the repository root:

```bash
set -euo pipefail
RR_TASK2A_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md
RR_TASK2A_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2A_BRANCH=codex/release-radar-mvp
RR_TASK2A_REPO_ROOT="$(git rev-parse --show-toplevel)"
test "$(pwd -P)" = "$(realpath "$RR_TASK2A_REPO_ROOT")"

RR_TASK2A_PLANNING_SHA="$(git log -1 --format=%H -- "$RR_TASK2A_BRIEF")"
test -n "$RR_TASK2A_PLANNING_SHA"
test "$(git rev-parse HEAD)" = "$RR_TASK2A_PLANNING_SHA"
RR_TASK2A_REMOTE_LINE="$(git ls-remote --exit-code origin \
  "refs/heads/$RR_TASK2A_BRANCH")"
test "$(printf '%s\n' "$RR_TASK2A_REMOTE_LINE" | wc -l | tr -d ' ')" = "1"
test "$(printf '%s\n' "$RR_TASK2A_REMOTE_LINE" | awk '{print $1}')" = \
  "$RR_TASK2A_PLANNING_SHA"

git diff --exit-code "$RR_TASK2A_PLANNING_SHA" -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY"
git diff --cached --exit-code "$RR_TASK2A_PLANNING_SHA" -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY"
git diff --exit-code -- "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY"
test "$(git hash-object "$RR_TASK2A_BRIEF")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_BRIEF")"
test "$(git hash-object "$RR_TASK2A_REGISTRY")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_REGISTRY")"

test "$(awk -v path="$RR_TASK2A_BRIEF" \
  '$2 == path { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A_REGISTRY")" = "1"
RR_TASK2A_REGISTERED_BRIEF_SHA="$(awk -v path="$RR_TASK2A_BRIEF" \
  '$2 == path { print $1 }' "$RR_TASK2A_REGISTRY")"
case "$RR_TASK2A_REGISTERED_BRIEF_SHA" in
  (*[!0-9a-f]*|'') exit 1 ;;
esac
test "${#RR_TASK2A_REGISTERED_BRIEF_SHA}" = "64"
test "$(shasum -a 256 "$RR_TASK2A_BRIEF" | awk '{print $1}')" = \
  "$RR_TASK2A_REGISTERED_BRIEF_SHA"
shasum -a 256 -c "$RR_TASK2A_REGISTRY"

test "$(shasum -a 256 docs/design/release-radar-ticket-tasks-design.md | awk '{print $1}')" = \
  "c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08"
test "$(shasum -a 256 docs/architecture/ADR-005-ticket-task-work-plans.md | awk '{print $1}')" = \
  "6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5"
test "$(shasum -a 256 docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md | awk '{print $1}')" = \
  "2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1"
(cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS)
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
git merge-base --is-ancestor b711229a109c1a58c9616e4ff907afb18cd4f958 HEAD
git diff --exit-code b711229a109c1a58c9616e4ff907afb18cd4f958 -- \
  ReleaseRadarCore/Models/DeliveryGoalModels.swift \
  ReleaseRadarCore/Store/DeliveryStore.swift \
  ReleaseRadarCore/Store/StoreMigrations.swift \
  ReleaseRadarTests/StoreAcceptanceTests.swift \
  ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
RR_TASK2A_FIXTURE_PARENT="$RR_TASK2A_REPO_ROOT/ReleaseRadarTests/Fixtures"
RR_TASK2A_FIXTURE_DIR="$RR_TASK2A_FIXTURE_PARENT/SchemaV11"
test -d "$RR_TASK2A_FIXTURE_PARENT"
test ! -L "$RR_TASK2A_FIXTURE_PARENT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_FIXTURE_PARENT")" = "Directory"
test "$(realpath "$RR_TASK2A_FIXTURE_PARENT")" = \
  "$(realpath "$RR_TASK2A_REPO_ROOT")/ReleaseRadarTests/Fixtures"
test ! -e "$RR_TASK2A_FIXTURE_DIR"
test ! -L "$RR_TASK2A_FIXTURE_DIR"
```

`stat` is intentionally used without `-L`, so its type check is an `lstat`-
style no-follow check. Any failure stops before the temporary generator edit.
This executable gate directly proves the exact Task 2A brief digest, exactly
one equal registry entry, the full root registry, byte identity of both
planning files to the remotely exact planning checkpoint, and the wholly
absent destination. Do not repair an accepted dependency inside Task 2A.

### RED: prove the missing gate fails before attachment

After adding the exact temporary test, run it without injecting the export
gate and retain the explicit result bundle:

```bash
set -euo pipefail
rr_task2a_require_directory() {
  test -d "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Directory"
}
rr_task2a_require_file() {
  test -f "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Regular File"
}
rr_task2a_require_beneath() {
  case "$(realpath "$2")" in
    ("$(realpath "$1")"/*) ;;
    (*) exit 1 ;;
  esac
}

RR_TASK2A_RED_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2a-red.XXXXXX)"
rr_task2a_require_directory "$RR_TASK2A_RED_PARENT"
RR_TASK2A_RED="$RR_TASK2A_RED_PARENT/DerivedData"
RR_TASK2A_RED_RESULT="$RR_TASK2A_RED_PARENT/red.xcresult"
RR_TASK2A_RED_SUMMARY="$RR_TASK2A_RED_PARENT/red-summary.json"
RR_TASK2A_RED_DETAILS="$RR_TASK2A_RED_PARENT/red-details.json"
RR_TASK2A_RED_EXPORT="$RR_TASK2A_RED_PARENT/red-export"
test ! -e "$RR_TASK2A_RED" && test ! -L "$RR_TASK2A_RED"
test ! -e "$RR_TASK2A_RED_RESULT" && test ! -L "$RR_TASK2A_RED_RESULT"
test ! -e "$RR_TASK2A_RED_SUMMARY" && test ! -L "$RR_TASK2A_RED_SUMMARY"
test ! -e "$RR_TASK2A_RED_DETAILS" && test ! -L "$RR_TASK2A_RED_DETAILS"
test ! -e "$RR_TASK2A_RED_EXPORT" && test ! -L "$RR_TASK2A_RED_EXPORT"
unset RR_SCHEMA_V11_FIXTURE_EXPORT
test -z "${RR_SCHEMA_V11_FIXTURE_EXPORT+x}"
test "$(rg --fixed-strings \
  'let exportGate = try XCTUnwrap(environment["RR_SCHEMA_V11_FIXTURE_EXPORT"])' \
  ReleaseRadarTests/StoreAcceptanceTests.swift | wc -l | tr -d ' ')" = "1"
if xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' -derivedDataPath "$RR_TASK2A_RED" \
  -resultBundlePath "$RR_TASK2A_RED_RESULT" \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment; then
  exit 1
fi
rr_task2a_require_directory "$RR_TASK2A_RED_RESULT"
rr_task2a_require_beneath "$RR_TASK2A_RED_PARENT" "$RR_TASK2A_RED_RESULT"
(
  set -C
  xcrun xcresulttool get test-results summary \
    --path "$RR_TASK2A_RED_RESULT" --compact > "$RR_TASK2A_RED_SUMMARY"
)
rr_task2a_require_file "$RR_TASK2A_RED_SUMMARY"
rr_task2a_require_beneath "$RR_TASK2A_RED_PARENT" "$RR_TASK2A_RED_SUMMARY"
test "$(plutil -extract result raw "$RR_TASK2A_RED_SUMMARY")" = "Failed"
test "$(plutil -extract totalTestCount raw "$RR_TASK2A_RED_SUMMARY")" = "1"
test "$(plutil -extract passedTests raw "$RR_TASK2A_RED_SUMMARY")" = "0"
test "$(plutil -extract failedTests raw "$RR_TASK2A_RED_SUMMARY")" = "1"
test "$(plutil -extract skippedTests raw "$RR_TASK2A_RED_SUMMARY")" = "0"
test "$(plutil -extract expectedFailures raw "$RR_TASK2A_RED_SUMMARY")" = "0"
test "$(plutil -extract testFailures raw -expect array \
  "$RR_TASK2A_RED_SUMMARY")" = "1"
test "$(plutil -extract testFailures.0.testIdentifierString raw \
  "$RR_TASK2A_RED_SUMMARY")" = \
  'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()'
case "$(plutil -extract testFailures.0.failureText raw \
  "$RR_TASK2A_RED_SUMMARY")" in
  (*XCTUnwrap*) ;;
  (*) exit 1 ;;
esac
(
  set -C
  xcrun xcresulttool get test-results test-details \
    --test-id 'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()' \
    --path "$RR_TASK2A_RED_RESULT" --compact > "$RR_TASK2A_RED_DETAILS"
)
rr_task2a_require_file "$RR_TASK2A_RED_DETAILS"
rr_task2a_require_beneath "$RR_TASK2A_RED_PARENT" "$RR_TASK2A_RED_DETAILS"
test "$(plutil -extract testIdentifier raw "$RR_TASK2A_RED_DETAILS")" = \
  'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()'
test "$(plutil -extract testResult raw "$RR_TASK2A_RED_DETAILS")" = "Failed"
test "$(plutil -extract hasMediaAttachments raw "$RR_TASK2A_RED_DETAILS")" = "false"
xcrun xcresulttool export attachments \
  --test-id 'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()' \
  --path "$RR_TASK2A_RED_RESULT" \
  --output-path "$RR_TASK2A_RED_EXPORT"
rr_task2a_require_directory "$RR_TASK2A_RED_EXPORT"
rr_task2a_require_beneath "$RR_TASK2A_RED_PARENT" "$RR_TASK2A_RED_EXPORT"
RR_TASK2A_RED_MANIFEST="$RR_TASK2A_RED_EXPORT/manifest.json"
rr_task2a_require_file "$RR_TASK2A_RED_MANIFEST"
rr_task2a_require_beneath "$RR_TASK2A_RED_EXPORT" "$RR_TASK2A_RED_MANIFEST"
test "$(plutil -extract 0.testIdentifier raw "$RR_TASK2A_RED_MANIFEST")" = \
  'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()'
if plutil -extract 1.testIdentifier raw \
  "$RR_TASK2A_RED_MANIFEST" >/dev/null 2>&1; then
  exit 1
fi
test "$(plutil -extract 0.attachments raw -expect array \
  "$RR_TASK2A_RED_MANIFEST")" = "0"
test "$(find "$RR_TASK2A_RED_EXPORT" -mindepth 1 -maxdepth 1 -print | \
  wc -l | tr -d ' ')" = "1"
RR_TASK2A_FIXTURE_DIR="$PWD/ReleaseRadarTests/Fixtures/SchemaV11"
test ! -e "$RR_TASK2A_FIXTURE_DIR"
test ! -L "$RR_TASK2A_FIXTURE_DIR"
```

Accepted RED requires every assertion above: the preserved result says Failed
exactly 1/1, the only failure identifier is the selected generator, its failure
text contains `XCTUnwrap`, the gate is demonstrably absent at a source line that
names `RR_SCHEMA_V11_FIXTURE_EXPORT`, skipped and expected-failure counts are
zero, `hasMediaAttachments` is false, the attachment export manifest contains
the selected test and zero attachments, and the durable `SchemaV11` directory
is wholly absent. A compile error, fixture checksum error, unrelated test
failure, environment failure, different failure text/count, or any attachment
is not an accepted RED.

Do not rerun the RED after it proves this boundary once.

### GREEN: one sandbox-safe attachment generation

Use a new absent DerivedData path. Build without running tests, locate exactly
one fresh Release Radar format-2 `.xctestrun`, assert the exact nested target
environment structure, inject only the export gate, and run only the generator
once with parallel testing disabled:

```bash
set -euo pipefail
rr_task2a_require_directory() {
  test -d "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Directory"
}
rr_task2a_require_file() {
  test -f "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Regular File"
}
rr_task2a_require_beneath() {
  case "$(realpath "$2")" in
    ("$(realpath "$1")"/*) ;;
    (*) exit 1 ;;
  esac
}

RR_TASK2A_GREEN_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2a-green.XXXXXX)"
rr_task2a_require_directory "$RR_TASK2A_GREEN_PARENT"
RR_TASK2A_DERIVED="$RR_TASK2A_GREEN_PARENT/DerivedData"
RR_TASK2A_RESULT="$RR_TASK2A_GREEN_PARENT/green.xcresult"
RR_TASK2A_SUMMARY="$RR_TASK2A_GREEN_PARENT/green-summary.json"
RR_TASK2A_DETAILS="$RR_TASK2A_GREEN_PARENT/green-details.json"
test ! -e "$RR_TASK2A_DERIVED" && test ! -L "$RR_TASK2A_DERIVED"
test ! -e "$RR_TASK2A_RESULT" && test ! -L "$RR_TASK2A_RESULT"
test ! -e "$RR_TASK2A_SUMMARY" && test ! -L "$RR_TASK2A_SUMMARY"
test ! -e "$RR_TASK2A_DETAILS" && test ! -L "$RR_TASK2A_DETAILS"
xcodebuild build-for-testing -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' -derivedDataPath "$RR_TASK2A_DERIVED"
RR_TASK2A_XCTESTRUN="$(rg --files --hidden --no-ignore "$RR_TASK2A_DERIVED/Build/Products" \
  | rg '/ReleaseRadar_ReleaseRadar_.*\.xctestrun$')"
test -n "$RR_TASK2A_XCTESTRUN"
test "$(printf '%s\n' "$RR_TASK2A_XCTESTRUN" | wc -l | tr -d ' ')" = "1"
rr_task2a_require_file "$RR_TASK2A_XCTESTRUN"
rr_task2a_require_beneath "$RR_TASK2A_GREEN_PARENT" "$RR_TASK2A_XCTESTRUN"
test "$(plutil -extract __xctestrun_metadata__.FormatVersion raw \
  "$RR_TASK2A_XCTESTRUN")" = "2"
test "$(plutil -type TestConfigurations "$RR_TASK2A_XCTESTRUN")" = "array"
test "$(plutil -extract TestConfigurations raw -expect array \
  "$RR_TASK2A_XCTESTRUN")" = "1"
if plutil -type EnvironmentVariables "$RR_TASK2A_XCTESTRUN" >/dev/null 2>&1; then
  exit 1
fi
test "$(plutil -extract TestConfigurations.0.TestTargets raw -expect array \
  "$RR_TASK2A_XCTESTRUN")" = "1"
test "$(plutil -type \
  TestConfigurations.0.TestTargets.0.EnvironmentVariables \
  "$RR_TASK2A_XCTESTRUN")" = "dictionary"
RR_TASK2A_CONFIGURED="$RR_TASK2A_DERIVED/Build/Products/ReleaseRadar_Task2A.xctestrun"
test ! -e "$RR_TASK2A_CONFIGURED" && test ! -L "$RR_TASK2A_CONFIGURED"
/bin/cp -n "$RR_TASK2A_XCTESTRUN" "$RR_TASK2A_CONFIGURED"
rr_task2a_require_file "$RR_TASK2A_CONFIGURED"
plutil -insert \
  TestConfigurations.0.TestTargets.0.EnvironmentVariables.RR_SCHEMA_V11_FIXTURE_EXPORT \
  -string "1" \
  "$RR_TASK2A_CONFIGURED"
xcodebuild test-without-building -xctestrun "$RR_TASK2A_CONFIGURED" \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -resultBundlePath "$RR_TASK2A_RESULT" \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment
rr_task2a_require_directory "$RR_TASK2A_RESULT"
rr_task2a_require_beneath "$RR_TASK2A_GREEN_PARENT" "$RR_TASK2A_RESULT"
(
  set -C
  xcrun xcresulttool get test-results summary \
    --path "$RR_TASK2A_RESULT" --compact > "$RR_TASK2A_SUMMARY"
)
rr_task2a_require_file "$RR_TASK2A_SUMMARY"
rr_task2a_require_beneath "$RR_TASK2A_GREEN_PARENT" "$RR_TASK2A_SUMMARY"
test "$(plutil -extract result raw "$RR_TASK2A_SUMMARY")" = "Passed"
test "$(plutil -extract totalTestCount raw "$RR_TASK2A_SUMMARY")" = "1"
test "$(plutil -extract passedTests raw "$RR_TASK2A_SUMMARY")" = "1"
test "$(plutil -extract failedTests raw "$RR_TASK2A_SUMMARY")" = "0"
test "$(plutil -extract skippedTests raw "$RR_TASK2A_SUMMARY")" = "0"
test "$(plutil -extract expectedFailures raw "$RR_TASK2A_SUMMARY")" = "0"
test "$(plutil -extract testFailures raw -expect array \
  "$RR_TASK2A_SUMMARY")" = "0"
(
  set -C
  xcrun xcresulttool get test-results test-details \
    --test-id 'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()' \
    --path "$RR_TASK2A_RESULT" --compact > "$RR_TASK2A_DETAILS"
)
rr_task2a_require_file "$RR_TASK2A_DETAILS"
rr_task2a_require_beneath "$RR_TASK2A_GREEN_PARENT" "$RR_TASK2A_DETAILS"
test "$(plutil -extract testIdentifier raw "$RR_TASK2A_DETAILS")" = \
  'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()'
test "$(plutil -extract testResult raw "$RR_TASK2A_DETAILS")" = "Passed"
```

Expected GREEN: exactly one selected test passes with zero failed, skipped, or
expected failures and retains one `release-radar-v11.sqlite` attachment. The
test migrates only the verified test-local v10 copy. It does not write the
repository fixture path.

Only after all fresh GREEN summary/detail assertions pass, remove `import
Darwin`, `Task2AGeneratorInput`, `makeVerifiedTask2AGeneratorInput()`, and
`testGenerateExactVersionElevenFixtureAttachment()` with `apply_patch`. Then
run this gate before attachment export:

```bash
set -euo pipefail
RR_TASK2A_ACCEPTED_COMMIT=b711229a109c1a58c9616e4ff907afb18cd4f958
RR_TASK2A_TEST_SOURCE=ReleaseRadarTests/StoreAcceptanceTests.swift
git diff --cached --exit-code "$RR_TASK2A_ACCEPTED_COMMIT" -- \
  "$RR_TASK2A_TEST_SOURCE"
git diff --exit-code -- "$RR_TASK2A_TEST_SOURCE"
git diff --exit-code "$RR_TASK2A_ACCEPTED_COMMIT" -- \
  "$RR_TASK2A_TEST_SOURCE"
test "$(git hash-object "$RR_TASK2A_TEST_SOURCE")" = \
  "$(git rev-parse "$RR_TASK2A_ACCEPTED_COMMIT:$RR_TASK2A_TEST_SOURCE")"
```

These staged, unstaged, combined working-tree, and exact blob checks prove the
entire file is byte-identical to the accepted commit, not merely equal to the
current index. Do not export or copy while any check fails.

### Export and copy the one passing attachment

Export only the selected test's attachment to a new absent temporary directory,
validate the summary/manifest and safe names, and copy the exported bytes into
the still-absent repository path:

```bash
set -euo pipefail
rr_task2a_require_directory() {
  test -d "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Directory"
}
rr_task2a_require_file() {
  test -f "$1"
  test ! -L "$1"
  test "$(/usr/bin/stat -f '%HT' "$1")" = "Regular File"
}
rr_task2a_require_beneath() {
  case "$(realpath "$2")" in
    ("$(realpath "$1")"/*) ;;
    (*) exit 1 ;;
  esac
}

: "${RR_TASK2A_GREEN_PARENT:?Run export in the preserved GREEN shell}"
RR_TASK2A_RESULT="$RR_TASK2A_GREEN_PARENT/green.xcresult"
RR_TASK2A_ATTACHMENTS="$RR_TASK2A_GREEN_PARENT/export"
rr_task2a_require_directory "$RR_TASK2A_GREEN_PARENT"
rr_task2a_require_directory "$RR_TASK2A_RESULT"
rr_task2a_require_beneath "$RR_TASK2A_GREEN_PARENT" "$RR_TASK2A_RESULT"
test ! -e "$RR_TASK2A_ATTACHMENTS"
test ! -L "$RR_TASK2A_ATTACHMENTS"
xcrun xcresulttool export attachments \
  --test-id 'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()' \
  --path "$RR_TASK2A_RESULT" \
  --output-path "$RR_TASK2A_ATTACHMENTS"
rr_task2a_require_directory "$RR_TASK2A_ATTACHMENTS"
rr_task2a_require_beneath "$RR_TASK2A_GREEN_PARENT" "$RR_TASK2A_ATTACHMENTS"
RR_TASK2A_MANIFEST="$RR_TASK2A_ATTACHMENTS/manifest.json"
rr_task2a_require_file "$RR_TASK2A_MANIFEST"
rr_task2a_require_beneath "$RR_TASK2A_ATTACHMENTS" "$RR_TASK2A_MANIFEST"
test "$(plutil -extract 0.testIdentifier raw "$RR_TASK2A_MANIFEST")" = \
  'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()'
if plutil -extract 1.testIdentifier raw "$RR_TASK2A_MANIFEST" >/dev/null 2>&1; then
  exit 1
fi
test "$(plutil -extract 0.attachments raw -expect array "$RR_TASK2A_MANIFEST")" = "1"
RR_TASK2A_SUGGESTED_NAME="$(plutil -extract \
  0.attachments.0.suggestedHumanReadableName raw "$RR_TASK2A_MANIFEST")"
case "$RR_TASK2A_SUGGESTED_NAME" in
  release-radar-v11_0_????????-????-????-????-????????????.sqlite) ;;
  *) exit 1 ;;
esac
RR_TASK2A_SUGGESTED_UUID="${RR_TASK2A_SUGGESTED_NAME#release-radar-v11_0_}"
RR_TASK2A_SUGGESTED_UUID="${RR_TASK2A_SUGGESTED_UUID%.sqlite}"
test "${#RR_TASK2A_SUGGESTED_UUID}" = "36"
RR_TASK2A_SUGGESTED_HEX="$(printf '%s' "$RR_TASK2A_SUGGESTED_UUID" | tr -d '-')"
test "${#RR_TASK2A_SUGGESTED_HEX}" = "32"
case "$RR_TASK2A_SUGGESTED_HEX" in
  *[!0-9A-F]*) exit 1 ;;
esac
test "$(plutil -extract 0.attachments.0.isAssociatedWithFailure raw \
  "$RR_TASK2A_MANIFEST")" = "false"
RR_TASK2A_EXPORTED_NAME="$(plutil -extract \
  0.attachments.0.exportedFileName raw "$RR_TASK2A_MANIFEST")"
case "$RR_TASK2A_EXPORTED_NAME" in
  (''|'.'|'..'|*/*|*\\*) exit 1 ;;
esac
RR_TASK2A_EXPORTED="$RR_TASK2A_ATTACHMENTS/$RR_TASK2A_EXPORTED_NAME"
rr_task2a_require_file "$RR_TASK2A_EXPORTED"
rr_task2a_require_beneath "$RR_TASK2A_ATTACHMENTS" "$RR_TASK2A_EXPORTED"
test "$(find "$RR_TASK2A_ATTACHMENTS" -mindepth 1 -maxdepth 1 -print | \
  wc -l | tr -d ' ')" = "2"

RR_TASK2A_REPO_ROOT="$(git rev-parse --show-toplevel)"
test "$(pwd -P)" = "$(realpath "$RR_TASK2A_REPO_ROOT")"
RR_TASK2A_FIXTURE_PARENT="$RR_TASK2A_REPO_ROOT/ReleaseRadarTests/Fixtures"
RR_TASK2A_FIXTURE_DIR="$RR_TASK2A_FIXTURE_PARENT/SchemaV11"
RR_TASK2A_FIXTURE="$RR_TASK2A_FIXTURE_DIR/release-radar-v11.sqlite"
rr_task2a_require_directory "$RR_TASK2A_FIXTURE_PARENT"
test "$(realpath "$RR_TASK2A_FIXTURE_PARENT")" = \
  "$(realpath "$RR_TASK2A_REPO_ROOT")/ReleaseRadarTests/Fixtures"
test ! -e "$RR_TASK2A_FIXTURE_DIR"
test ! -L "$RR_TASK2A_FIXTURE_DIR"
mkdir "$RR_TASK2A_FIXTURE_DIR"
rr_task2a_require_directory "$RR_TASK2A_FIXTURE_DIR"
test "$(realpath "$RR_TASK2A_FIXTURE_DIR")" = \
  "$(realpath "$RR_TASK2A_FIXTURE_PARENT")/SchemaV11"
test ! -e "$RR_TASK2A_FIXTURE"
test ! -L "$RR_TASK2A_FIXTURE"
(
  umask 077
  set -C
  /bin/dd if="$RR_TASK2A_EXPORTED" bs=1048576 2>/dev/null > "$RR_TASK2A_FIXTURE"
)
rr_task2a_require_file "$RR_TASK2A_FIXTURE"
test "$(shasum -a 256 "$RR_TASK2A_EXPORTED" | awk '{print $1}')" = \
  "$(shasum -a 256 "$RR_TASK2A_FIXTURE" | awk '{print $1}')"
for suffix in -wal -shm -journal; do
  test ! -e "$RR_TASK2A_FIXTURE$suffix"
  test ! -L "$RR_TASK2A_FIXTURE$suffix"
done
test "$(find "$RR_TASK2A_FIXTURE_DIR" -mindepth 1 -maxdepth 1 -print | \
  wc -l | tr -d ' ')" = "1"
```

The parent process uses the shell's `noclobber` open for an exclusive
no-overwrite destination and streams the one validated attachment through that
descriptor; ordinary `cp` is not permitted for the durable fixture. Every
directory/file type test above is no-follow and every canonical path remains
beneath its approved parent. Any mismatch stops before or at exclusive creation;
do not rerun the passing generator with a new UUID merely to obtain different
output.

### Checksum and complete direct SQLite verification

Create the local checksum from inside the fixture directory so its manifest
contains only the fixture filename:

```bash
set -euo pipefail
RR_TASK2A_FIXTURE_DIR="$PWD/ReleaseRadarTests/Fixtures/SchemaV11"
RR_TASK2A_FIXTURE="$RR_TASK2A_FIXTURE_DIR/release-radar-v11.sqlite"
RR_TASK2A_FIXTURE_CHECKSUM="$RR_TASK2A_FIXTURE_DIR/SHA256SUMS"
test -d "$RR_TASK2A_FIXTURE_DIR"
test ! -L "$RR_TASK2A_FIXTURE_DIR"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_FIXTURE_DIR")" = "Directory"
test -f "$RR_TASK2A_FIXTURE"
test ! -L "$RR_TASK2A_FIXTURE"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_FIXTURE")" = "Regular File"
test ! -e "$RR_TASK2A_FIXTURE_CHECKSUM"
test ! -L "$RR_TASK2A_FIXTURE_CHECKSUM"
(
  cd "$RR_TASK2A_FIXTURE_DIR"
  set -C
  shasum -a 256 release-radar-v11.sqlite > SHA256SUMS
)
test -f "$RR_TASK2A_FIXTURE_CHECKSUM"
test ! -L "$RR_TASK2A_FIXTURE_CHECKSUM"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_FIXTURE_CHECKSUM")" = "Regular File"
test "$(awk '$2 == "release-radar-v11.sqlite" { count += 1 } \
  END { print count + 0 }' "$RR_TASK2A_FIXTURE_CHECKSUM")" = "1"
test "$(wc -l < "$RR_TASK2A_FIXTURE_CHECKSUM" | tr -d ' ')" = "1"
(cd "$RR_TASK2A_FIXTURE_DIR" && shasum -a 256 -c SHA256SUMS)
for suffix in -wal -shm -journal; do
  test ! -e "$RR_TASK2A_FIXTURE$suffix"
  test ! -L "$RR_TASK2A_FIXTURE$suffix"
done
test "$(find "$RR_TASK2A_FIXTURE_DIR" -mindepth 1 -maxdepth 1 -print | \
  wc -l | tr -d ' ')" = "2"
test "$(find "$RR_TASK2A_FIXTURE_DIR" -mindepth 1 -maxdepth 1 \
  ! -name release-radar-v11.sqlite ! -name SHA256SUMS -print | wc -l | \
  tr -d ' ')" = "0"
```

Then run this fail-fast assertion block from the repository root:

```bash
sqlite3 ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite <<'SQL'
.bail on
CREATE TEMP TABLE fixture_assertions (value INTEGER NOT NULL CHECK (value = 1));
INSERT INTO fixture_assertions
SELECT (SELECT user_version FROM pragma_user_version) = 11;
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
  (SELECT COUNT(*) FROM ticket_goal_links) +
  (SELECT COUNT(*) FROM phase_plans) +
  (SELECT COUNT(*) FROM delivery_goals) +
  (SELECT COUNT(*) FROM delivery_goal_done_criteria) +
  (SELECT COUNT(*) FROM delivery_goal_ticket_assignments) +
  (SELECT COUNT(*) FROM delivery_goal_assignment_events)
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
SELECT COUNT(*) = 1
   AND SUM(type = 'INTEGER' AND "notnull" = 1 AND dflt_value = '0') = 1
FROM pragma_table_info('tickets')
WHERE name = 'plan_legacy_continuation';
INSERT INTO fixture_assertions
WITH expected(type, name) AS (VALUES
  ('index', 'audit_events_project_entity_index'),
  ('index', 'delivery_goal_assignment_events_ticket_revision_unique'),
  ('index', 'delivery_goal_ticket_assignments_goal_index'),
  ('index', 'delivery_goals_phase_sort_index'),
  ('index', 'delivery_goals_project_phase_identity_unique'),
  ('index', 'notification_events_project_created_index'),
  ('index', 'notification_events_state_index'),
  ('index', 'observed_goals_project_identity_unique'),
  ('index', 'project_active_phases_phase_index'),
  ('index', 'ticket_goal_links_project_goal_unique'),
  ('index', 'ticket_goal_links_project_ticket_unique'),
  ('index', 'tickets_project_phase_identity_unique'),
  ('table', 'agent_command_requests'),
  ('table', 'alert_rules'),
  ('table', 'audit_events'),
  ('table', 'blockers'),
  ('table', 'codex_plugin_lifecycle'),
  ('table', 'completion_records'),
  ('table', 'delivery_goal_assignment_events'),
  ('table', 'delivery_goal_done_criteria'),
  ('table', 'delivery_goal_ticket_assignments'),
  ('table', 'delivery_goals'),
  ('table', 'evidence'),
  ('table', 'notification_events'),
  ('table', 'notification_occurrences'),
  ('table', 'observed_goals'),
  ('table', 'observed_threads'),
  ('table', 'phase_dependencies'),
  ('table', 'phase_plans'),
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
  ('trigger', 'delivery_goals_reject_ownership_change'),
  ('trigger', 'phase_plans_after_phase_insert'),
  ('trigger', 'reject_phase_dependency_cycle_insert'),
  ('trigger', 'reject_phase_dependency_cycle_update'),
  ('trigger', 'reject_ticket_dependency_cycle_insert'),
  ('trigger', 'reject_ticket_dependency_cycle_update'),
  ('trigger', 'tickets_reject_legacy_continuation_insert'),
  ('trigger', 'tickets_reject_legacy_continuation_regrant')
), actual(type, name) AS (
  SELECT type, name FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'
), difference AS (
  SELECT type, name FROM expected EXCEPT SELECT type, name FROM actual
  UNION ALL
  SELECT type, name FROM actual EXCEPT SELECT type, name FROM expected
)
SELECT COUNT(*) = 0 FROM difference;
INSERT INTO fixture_assertions
SELECT COUNT(*) = 0
FROM sqlite_schema
WHERE name IN ('ticket_task_plans', 'ticket_tasks');
INSERT INTO fixture_assertions
SELECT COUNT(*) = 0 FROM pragma_foreign_key_check;
INSERT INTO fixture_assertions
SELECT (SELECT integrity_check FROM pragma_integrity_check) = 'ok';
SQL
```

Expected: exit 0; exact schema version 11; exact 28-table, 12-index,
8-trigger inventory; all 26 non-default application/planning tables empty;
exact defaults only; canonical continuation column; no v12 object; empty
foreign-key check; and integrity `ok`.

### Regression and final source-boundary verification

Prove the v10 fixture stayed immutable, the generator is gone, the v11
checksum passes, and the accepted Store/plugin migration boundary is green:

```bash
set -euo pipefail
(cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS)
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
RR_TASK2A_FIXTURE_DIR="$PWD/ReleaseRadarTests/Fixtures/SchemaV11"
RR_TASK2A_FIXTURE="$RR_TASK2A_FIXTURE_DIR/release-radar-v11.sqlite"
for path in "$RR_TASK2A_FIXTURE" "$RR_TASK2A_FIXTURE_DIR/SHA256SUMS"; do
  test -f "$path"
  test ! -L "$path"
  test "$(/usr/bin/stat -f '%HT' "$path")" = "Regular File"
done
for suffix in -wal -shm -journal; do
  test ! -e "$RR_TASK2A_FIXTURE$suffix"
  test ! -L "$RR_TASK2A_FIXTURE$suffix"
done
test "$(find "$RR_TASK2A_FIXTURE_DIR" -mindepth 1 -maxdepth 1 \
  ! -name release-radar-v11.sqlite ! -name SHA256SUMS -print | wc -l | \
  tr -d ' ')" = "0"
git diff --cached --exit-code b711229a109c1a58c9616e4ff907afb18cd4f958 -- \
  ReleaseRadarTests/StoreAcceptanceTests.swift
git diff --exit-code -- ReleaseRadarTests/StoreAcceptanceTests.swift
git diff --exit-code b711229a109c1a58c9616e4ff907afb18cd4f958 -- \
  ReleaseRadarCore/Models/DeliveryGoalModels.swift \
  ReleaseRadarCore/Store/DeliveryStore.swift \
  ReleaseRadarCore/Store/StoreMigrations.swift \
  ReleaseRadarTests/StoreAcceptanceTests.swift \
  ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
RR_TASK2A_REGRESSION_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2a-regression.XXXXXX)"
test -d "$RR_TASK2A_REGRESSION_PARENT"
test ! -L "$RR_TASK2A_REGRESSION_PARENT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_REGRESSION_PARENT")" = "Directory"
RR_TASK2A_REGRESSION_DERIVED="$RR_TASK2A_REGRESSION_PARENT/DerivedData"
RR_TASK2A_REGRESSION_RESULT="$RR_TASK2A_REGRESSION_PARENT/regression.xcresult"
RR_TASK2A_REGRESSION_SUMMARY="$RR_TASK2A_REGRESSION_PARENT/regression-summary.json"
test ! -e "$RR_TASK2A_REGRESSION_DERIVED"
test ! -L "$RR_TASK2A_REGRESSION_DERIVED"
test ! -e "$RR_TASK2A_REGRESSION_RESULT"
test ! -L "$RR_TASK2A_REGRESSION_RESULT"
test ! -e "$RR_TASK2A_REGRESSION_SUMMARY"
test ! -L "$RR_TASK2A_REGRESSION_SUMMARY"
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath "$RR_TASK2A_REGRESSION_DERIVED" \
  -resultBundlePath "$RR_TASK2A_REGRESSION_RESULT" \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests
test -d "$RR_TASK2A_REGRESSION_RESULT"
test ! -L "$RR_TASK2A_REGRESSION_RESULT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_REGRESSION_RESULT")" = "Directory"
test "$(dirname "$(realpath "$RR_TASK2A_REGRESSION_RESULT")")" = \
  "$(realpath "$RR_TASK2A_REGRESSION_PARENT")"
(
  set -C
  xcrun xcresulttool get test-results summary \
    --path "$RR_TASK2A_REGRESSION_RESULT" --compact > \
    "$RR_TASK2A_REGRESSION_SUMMARY"
)
test -f "$RR_TASK2A_REGRESSION_SUMMARY"
test ! -L "$RR_TASK2A_REGRESSION_SUMMARY"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_REGRESSION_SUMMARY")" = "Regular File"
test "$(dirname "$(realpath "$RR_TASK2A_REGRESSION_SUMMARY")")" = \
  "$(realpath "$RR_TASK2A_REGRESSION_PARENT")"
test "$(plutil -extract result raw "$RR_TASK2A_REGRESSION_SUMMARY")" = "Passed"
test "$(plutil -extract totalTestCount raw \
  "$RR_TASK2A_REGRESSION_SUMMARY")" = "58"
test "$(plutil -extract passedTests raw \
  "$RR_TASK2A_REGRESSION_SUMMARY")" = "58"
test "$(plutil -extract failedTests raw \
  "$RR_TASK2A_REGRESSION_SUMMARY")" = "0"
test "$(plutil -extract skippedTests raw \
  "$RR_TASK2A_REGRESSION_SUMMARY")" = "0"
test "$(plutil -extract expectedFailures raw \
  "$RR_TASK2A_REGRESSION_SUMMARY")" = "0"
test "$(plutil -extract testFailures raw -expect array \
  "$RR_TASK2A_REGRESSION_SUMMARY")" = "0"
git diff --check -- \
  ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite \
  ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS
```

Expected GREEN: the fresh absent DerivedData and explicit absent result-bundle
paths produce a non-symlink preserved summary reporting Passed exactly 58/58,
with zero failed, skipped, or expected failures and no partial/stale result
accepted. Both fixture-local checksums pass; the accepted v10 fixture and all
five Task 1B paths remain unchanged; the generator is absent; and only the two
regular non-symlink SchemaV11 artifacts are implementation outputs.

### Post-task planning-authority recheck

After every fixture, SQLite, regression, and source-restoration check, repeat
the planning authority gate before review or staging. This must still resolve
to the original remotely exact planning checkpoint; an implementation commit
must not yet exist:

```bash
set -euo pipefail
RR_TASK2A_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md
RR_TASK2A_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2A_BRANCH=codex/release-radar-mvp
RR_TASK2A_PLANNING_SHA="$(git log -1 --format=%H -- "$RR_TASK2A_BRIEF")"
test -n "$RR_TASK2A_PLANNING_SHA"
test "$(git rev-parse HEAD)" = "$RR_TASK2A_PLANNING_SHA"
RR_TASK2A_REMOTE_LINE="$(git ls-remote --exit-code origin \
  "refs/heads/$RR_TASK2A_BRANCH")"
test "$(printf '%s\n' "$RR_TASK2A_REMOTE_LINE" | wc -l | tr -d ' ')" = "1"
test "$(printf '%s\n' "$RR_TASK2A_REMOTE_LINE" | awk '{print $1}')" = \
  "$RR_TASK2A_PLANNING_SHA"
git diff --exit-code "$RR_TASK2A_PLANNING_SHA" -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY"
git diff --cached --exit-code "$RR_TASK2A_PLANNING_SHA" -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY"
git diff --exit-code -- "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY"
test "$(git hash-object "$RR_TASK2A_BRIEF")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_BRIEF")"
test "$(git hash-object "$RR_TASK2A_REGISTRY")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_REGISTRY")"
test "$(awk -v path="$RR_TASK2A_BRIEF" \
  '$2 == path { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A_REGISTRY")" = "1"
RR_TASK2A_REGISTERED_BRIEF_SHA="$(awk -v path="$RR_TASK2A_BRIEF" \
  '$2 == path { print $1 }' "$RR_TASK2A_REGISTRY")"
case "$RR_TASK2A_REGISTERED_BRIEF_SHA" in
  (*[!0-9a-f]*|'') exit 1 ;;
esac
test "${#RR_TASK2A_REGISTERED_BRIEF_SHA}" = "64"
test "$(shasum -a 256 "$RR_TASK2A_BRIEF" | awk '{print $1}')" = \
  "$RR_TASK2A_REGISTERED_BRIEF_SHA"
shasum -a 256 -c "$RR_TASK2A_REGISTRY"
```

Any mismatch is Required and blocks review, staging, commit, and Task 2B. Do
not update planning artifacts during implementation to make this gate pass.

## Happy path

The remote-exact planning/registry and immutable dependency checks pass. The
preserved absent-gate RED proves Failed 1/1 only at the named `XCTUnwrap`, with
no skip, expected failure, attachment, or durable destination. The format-2
`.xctestrun` injects only the exact export gate; the temporary throwing boundary
verifies the exact v10 manifest and bytes before exclusive copy and schema-10
inspection, then one selected GREEN test migrates through the accepted Task 1B
store, closes every SQLite owner, and attaches the standalone bytes. Fresh
result inspection proves Passed 1/1 before the complete temporary edit is
removed byte-exactly to `b711229...`. The parent exports exactly one contained,
non-symlink passing attachment, creates the absent fixture directory once,
copies with exclusive no-clobber output, and creates only the fixture and
checksum. Direct checks prove the complete v11 contract, fresh regression
evidence proves Passed 58/58, the planning-authority gate still passes, and
independent reviewers accept the exact artifacts before the implementation
checkpoint is committed, pushed, and remotely verified.

## Non-happy paths and recovery

- If the planning checkpoint is not exact local/remote HEAD, either planning
  file differs from that checkpoint in the index or worktree, the Task 2A entry
  is absent/duplicated/wrong, or any entry in the full root registry fails,
  stop before RED. The identical post-task gate must also pass; do not rewrite
  planning authority during implementation.
- If any accepted artifact hash, Task 1A digest, or Task 1B ancestry/path
  identity differs, stop before RED. Do not repair an accepted dependency
  inside Task 2A.
- If `SchemaV11` exists as any object, including a broken symlink, or its parent
  is not the regular non-symlink canonical repository fixture directory, stop.
  Do not overwrite, delete, follow, or regenerate it until provenance is
  resolved through the reviewed workflow.
- If RED is not Failed exactly 1/1 at the named `XCTUnwrap` while the named gate
  is absent, if it has a skip/expected failure, or if test details report any
  media attachment, return NO-GO and diagnose before changing the approach.
- If the temporary throwing boundary cannot parse the exact one-line v10
  manifest, match both pinned and computed digests before destination creation,
  exclusively write unchanged bytes, or prove copied schema version 10 before
  `DeliveryStore`, stop without migration or attachment.
- If the `.xctestrun` is not fresh format 2 with exactly one configuration, one
  target, no top-level environment dictionary, and one nested target
  environment dictionary, stop before copying or mutation.
- If fresh GREEN result inspection is not Passed exactly 1/1 with zero failed,
  skipped, or expected failures before source removal, or produces more or
  fewer than one attachment, stop without copying. Retain the result for
  diagnosis; do not silently rerun or request a broader sandbox entitlement.
- If removal does not restore staged and unstaged `StoreAcceptanceTests.swift`
  byte identity to accepted commit `b711229...`, stop before export.
- If a passing result exists but export/copy validation fails, recover only
  from that exact preserved passing result. Do not rerun the generator merely
  to obtain new output.
- If any result/export/manifest/attachment path is a symlink, has the wrong
  no-follow type, escapes its exclusive temporary parent after canonicalization,
  has an unsafe/failure-associated name, or loses exact cardinality, stop.
- If exclusive destination creation/copy/checksum creation fails, a WAL, SHM,
  or rollback journal exists, either final artifact is not a regular
  non-symlink file, the destination contains an unexpected entry, owner/default
  rows differ, any owner/planning row exists, the object inventory differs, the
  continuation column is wrong, a v12 object appears, the checksum fails, or
  SQLite reports a foreign-key/integrity error, return NO-GO and do not commit.
- If the final Store/plugin result did not start from absent DerivedData and
  result-bundle paths or does not report fresh Passed 58/58 with all failure,
  skip, and expected-failure counts zero, reject it as partial/stale evidence.
- If the generator or any Task 1B/product/test change remains in the final
  diff, Task 2A is incomplete.
- No failure authorizes owner-data access, owner-bundle launch/install outside
  the required isolated XCTest host, bridge/MCP use, RR-R10 mutation,
  Accepted-ticket change, live task-plan
  creation, schema repair, entitlement change, or Task 2B implementation.

## Activity and audit evidence requirements

Task 2A is repository-only and creates no Release Radar audit, Activity row,
review item, notification, bridge receipt, ticket evidence, task-plan revision,
or task completion. Required evidence is both full-registry/planning-authority
transcripts, immutable-dependency transcript, RED Failed 1/1 summary/failure
text/detail with no attachment, GREEN Passed 1/1 summary/detail, attachment
manifest and containment/type checks, exact accepted-source restoration proof,
direct SQLite assertions, fixture byte size and SHA-256, final directory
inventory/sidecar proof, fresh Passed 58/58 regression summary, independent
dispositions, exact Git checkpoint, push, and remote-SHA equality recorded by
Delivery Management.

The existing blocker/start audit IDs are read-only dependency evidence. They
must not be replayed or supplemented in this task.

## Acceptance criteria

- [ ] The accepted design, ADR, and plan hashes match exactly.
- [ ] Task 1A commit/digest and Task 1B commit/path identity are verified and
      unchanged before RED and after implementation.
- [ ] This brief and its root checksum entry are canonical, and preimplementation
      Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy
      reviews are GO with Required 0 on the exact brief SHA.
- [ ] Before RED, the executable planning-authority gate proves the planning
      checkpoint is local/remote exact, the brief and registry are byte-identical
      to it in staged and unstaged state, exactly one Task 2A registry entry
      equals the computed brief SHA, and the full root registry verifies.
- [ ] The missing-gate RED result is preserved and reports Failed exactly 1/1,
      with its sole failure at the `RR_SCHEMA_V11_FIXTURE_EXPORT` `XCTUnwrap`,
      zero skipped/expected failures, no media attachment, and a wholly absent
      durable `SchemaV11` directory.
- [ ] The temporary generator uses its own throwing boundary—not
      `copyVerifiedVersionTenFixture()`—to parse the exact local v10 manifest,
      match pinned and computed source digests before any destination exists,
      exclusively write unchanged bytes in a unique test temp directory, and
      prove the copied database is schema 10 before `DeliveryStore` opens it.
- [ ] The exact format-2 GREEN command runs the selected generator once with
      `RR_SCHEMA_V11_FIXTURE_EXPORT=1`; the fresh result is inspected as Passed
      exactly 1/1 with zero failed/skipped/expected failures before removal and
      retains exactly one passing attachment.
- [ ] The generated database starts from a checksum-verified v10 fixture copy,
      opens `.available` through accepted Task 1B, and reports schema 11.
- [ ] After `apply_patch` removal and before export, staged, unstaged, combined,
      and blob-hash checks prove `StoreAcceptanceTests.swift` byte-identical to
      accepted commit `b711229...`; no temporary helper/import/test is durable.
- [ ] Result, export, manifest, and attachment paths are non-symlink objects of
      the expected type beneath an exclusively created temporary parent, and
      canonical path checks reject containment escape.
- [ ] The canonical fixture parent is verified; wholly absent `SchemaV11` is
      created once with plain `mkdir`; exactly one safe attachment is copied by
      exclusive no-clobber output rather than ordinary `cp`.
- [ ] Direct inspection proves the exact 28-table, 12-index, 8-trigger v11
      inventory; canonical continuation column; zero owner/planning rows;
      exact default/singleton rows; no v12 object; empty `foreign_key_check`;
      and integrity `ok`.
- [ ] `ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS` contains the exact
      generated digest and `shasum -a 256 -c` passes; fixture and checksum are
      regular non-symlink files, no WAL/SHM/rollback journal exists, and the
      directory contains exactly those two expected entries.
- [ ] The accepted v10 fixture checksum remains byte-identical and the five
      accepted Task 1B paths have no diff.
- [ ] The exact Store plus plugin-lifecycle regression starts with both fresh
      absent DerivedData and explicit result-bundle paths; its preserved summary
      reports Passed exactly 58/58 with zero failed/skipped/expected failures,
      and the authorized-path diff check is clean.
- [ ] After all task work, the full root checksum and exact-one-entry planning
      gate repeats successfully and proves the brief/registry still match the
      remotely exact planning checkpoint.
- [ ] No product/test source, owner data, owner-bundle launch/install outside
      the required isolated XCTest host, bridge/MCP call, RR-R10/board/ticket
      mutation, Accepted-ticket change, live task plan,
      external state, dependency, project file, or unrelated path changed.
- [ ] Fresh postimplementation Code Review, QA/Test, Architecture,
      Security/Privacy, TPM, and Delivery Management return GO with Required 0.
- [ ] No partial or unverified implementation commit exists. Only the two
      fixture artifacts plus coordinator-owned ledger evidence enter the Task
      2A implementation checkpoint.
- [ ] The accepted Task 2A implementation commit is pushed; local HEAD equals
      the exact remote branch SHA with ahead/behind `0/0`; only then may Task
      2B planning/release begin.

## Required independent reviews and role separation

Before implementation:

- Architecture verifies accepted v11 provenance, exact manifest identity,
  single-file fixture semantics, and no v12/Ticket Tasks scope.
- QA/Test verifies the RED failure identity and exact 1/1/no-attachment counts,
  fresh GREEN 1/1 inspection before source removal, accepted-commit source
  restoration before export, attachment cardinality, direct inventory/default/
  privacy checks, and fresh final 58/58 result-bundle evidence.
- Security/Privacy verifies the throwing manifest/digest/copy/schema-10 boundary,
  test-local-only migration, privacy-empty bytes, closed-store copy, no-follow
  path types, canonical containment, exclusive durable copy, exact directory
  inventory/sidecar absence, sandbox preservation, and no owner-data path.
- TPM verifies dependency order, 3–5-hour sizing, bounded scope, and that Task
  2B plus every live Ticket Tasks action remains closed.
- Delivery Management verifies both executable full-registry/exact-one-entry
  planning-authority gates, exact hashes, writer serialization, durable path
  placement, evidence, and Git/remote gates.

After implementation, a fresh Code Reviewer and fresh QA verifier independently
review the artifacts and results. Architecture, Security/Privacy, TPM, and
Delivery Management disposition the completed task. The Planning agent cannot
implement Task 2A, and the Implementer cannot review, approve, or independently
verify its own work. Required 0 is a hard gate. Optional findings do not expand
scope; out-of-scope findings are recorded but do not block this task.

## Completion evidence required in `docs/delivery/progress.md`

Delivery Management must record:

- Task 2A status, dependency gate, Planning/Implementer identities, exact brief
  SHA, exact-one-entry/full-root checksum-registry verification, planning-release
  remote checkpoint, and identical post-task planning-authority recheck
- exact design/ADR/plan hashes; Task 1A commit and fixture digest; Task 1B
  commit, ancestry, and five-path identity; unchanged RR-R10 In-progress
  dependency state; and confirmation that no live task plan exists
- exact pre-RED planning-file staged/unstaged/commit identity, local/remote SHA,
  full registry, destination-absence, and immutable dependency checks/results
- the named temporary generator, exact absent-gate RED command/result/failure
  identifier/text, Failed 1/1 and zero skip/expected-failure counts, test-detail
  no-attachment result, and proof no durable fixture directory was created
- exact temporary throwing verifier evidence: one-line v10 manifest, pinned and
  computed digests before destination creation, exclusive unique test temp copy,
  copied digest, and copied schema version 10 before `DeliveryStore`
- exact format-2 structure checks, configured `.xctestrun`, GREEN command,
  fresh Passed 1/1 selected-test summary/detail before source removal,
  result-bundle identity, and one passing attachment
- accepted-commit staged/unstaged/combined/blob identity for restored
  `StoreAcceptanceTests.swift` before export
- attachment manifest test ID, suggested name, safe exported basename, and
  no-follow type/canonical-containment evidence for the result/export/manifest/
  attachment; canonical fixture-parent proof; and confirmation that the parent
  copied only the preserved passing bytes once with exclusive no-clobber output
- fixture path, byte size, SHA-256, fixture-local checksum verification, exact
  28/12/8 and 48-object inventory, zero-row/default-row results, continuation
  column, no-v12 proof, empty foreign-key check, integrity result, exact two-file
  directory inventory, regular non-symlink types, and absent WAL/SHM/journal
- proof the temporary generator was removed; accepted v10 and Task 1B paths
  remained unchanged; and no result/export/build or other temporary artifact is
  durable
- exact Store/plugin regression command, proof both paths began absent, fresh
  result-bundle identity, Passed 58/58 with all non-pass counts zero, and
  authorized-path `git diff --check`
- pre- and postimplementation reviewer identities, GO/NO-GO dispositions,
  Required/Optional/Out-of-scope counts, and Required 0 closure
- confirmation of no owner/app/bridge/board/ticket/Accepted-ticket/task-plan/
  external-state mutation and no unrelated path change
- exact staged paths, staged-diff inspection, commit SHA, push result,
  `git ls-remote` remote SHA, local/remote equality, and ahead/behind `0/0`
- remaining risks/blockers and Task 2B as the next eligible task only after the
  exact remote checkpoint

## Task-specific completion and Git/remote boundary

Before RED, the coordinator's preimplementation checkpoint contains only the
canonical planning artifacts and coordinator-owned review evidence:

```text
docs/delivery/progress.md
docs/delivery/task-briefs/SHA256SUMS
docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md
```

Inspect the staged diff, commit/push it, and verify exact local/remote equality
with ahead/behind `0/0`. This does not complete the product task or create a
live Ticket Tasks row; it only fixes the reviewed implementation authority.

Task 2A implementation is complete only after the genuine v11 fixture and
fixture-local checksum pass every direct/regression check and all independent
postimplementation gates return GO with Required 0. Before then, do not commit
or push implementation work. Afterward, stage only:

```text
ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite
ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS
docs/delivery/progress.md
```

Inspect the staged inventory/diff, commit the fully verified checkpoint, push
`codex/release-radar-mvp`, and verify local HEAD equals the exact remote branch
SHA with ahead/behind `0/0`. The removed generator, accepted v10 fixture,
accepted Task 1B paths, planning files already checkpointed above, temporary
result/export/build paths, and every unrelated path are excluded. Task 2B
remains dependency-blocked until this exact remote checkpoint is complete.
