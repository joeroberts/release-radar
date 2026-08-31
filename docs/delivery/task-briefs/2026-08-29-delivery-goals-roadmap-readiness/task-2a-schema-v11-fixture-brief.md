# RR-R10 Task 2A Brief: Genuine Schema-v11 Fixture

**Status:** Regression-continuation planning correction. Task 2A's generator
RED, RED export, GREEN generator, GREEN attachment export/copy, checksum, and
direct SQLite verification are completed historical evidence and must never be
rerun. Continuation is closed until this exact registered brief is reviewed by
Architecture, QA/Test, Security/Privacy, TPM, and Delivery Management, then
committed with only the root registry and coordinator ledger as the direct
child of remote-exact Task 2A0 checkpoint
`f480f8361b562acda760f27e836f8ae595c60a1d`. Only after that checkpoint is
HEAD/upstream/live-remote exact at `0/0` may one fresh serialized regression
verifier run the single 58-test continuation defined below.

## Size assessment and checkpoint decision

The accepted implementation plan forecasts Task 2A at roughly 3–5 agent-hours.
It has one coherent, independently testable outcome: migrate the accepted empty
schema-v10 fixture through the accepted Task 1B product, capture the resulting
privacy-empty schema-v11 database, and prove its exact identity. It is below the
owner's roughly-eight-hour split threshold and has one review surface, so no
further split is warranted.

Task 2A implementation produces only the schema-v11 fixture and its local
checksum. The fixture pair already exists untracked at its accepted generated
identities. Task 2A0 has separately corrected and committed the Xcode test-
bundle membership prerequisite. This revision changes planning authority only;
it adds no product behavior or API and does not begin Task 2B.

## Objective and user-visible outcome

The completed generator produced the immutable, repository-owned schema-v11
fixture that Task 2B will use as the genuine additive v11-to-v12 migration
boundary. Its preserved evidence proves it started only from a checksum-
verified copy of the accepted schema-v10 fixture, opened that copy through the
exact accepted Task 1B `DeliveryStore`, proved the complete schema-v11 manifest
and zero Delivery Goal planning rows, closed the store, and captured only those
migrated bytes. The current objective is to run the one permitted 58-test
regression continuation without rerunning or reconstructing that generator
work, then accept the existing two fixture artifacts at the bounded Task 2A
checkpoint.

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
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md`,
  final registered SHA-256
  `db34c56d5c312a82b35e5a07434a94db2388d567e75ac1e8085d307d69dce733`
- `docs/delivery/progress.md`, Current gate, accepted Task 1A/1B checkpoints,
  accepted Ticket Tasks planning package, schema-v10 start-state proof, audited
  RR-R10 start handoff, Task 2A immutable generator history, accepted Task 2A0
  implementation checkpoint, and next eligible RR-R10 work

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
- Task 2A's corrected pre-GREEN checkpoint
  `d8bda5a035e0324acd90bcbe67036f8d217b18bf` remains historical generator
  provenance only. It is not the current continuation baseline and must not be
  used as HEAD, remote, project, or regression authority.
- Task 2A0 is accepted at implementation checkpoint
  `f480f8361b562acda760f27e836f8ae595c60a1d`, pushed and remote-exact with
  ahead/behind `0/0`. That commit contains exactly
  `ReleaseRadar.xcodeproj/project.pbxproj` and `docs/delivery/progress.md`.
  Its committed project blob is
  `2b984d44e5b73602bf04b18b761d308761de789c`, containing only the accepted
  `Fixtures/SchemaV11/SHA256SUMS` ReleaseRadarTests membership exception over
  the prior project baseline. This remote-exact commit is the sole direct
  regression-continuation parent.
- The governed start handoff is complete. RR-R10 is already In progress, with
  blocker-resolution audit `44783DB0-14B9-4912-BF49-136CDB62CB88` and start
  audit `7A91291D-1098-4D45-806C-AE12A3A693E3`. Task 2A performs no Release
  Radar mutation and does not repeat either request.
- No Ticket Tasks plan exists yet. Task 2A must not create, infer, revise, or
  complete one. The 16-row live plan remains a Task 7A action.
- This exact revised brief and its one root checksum entry must be independently
  reviewed by Architecture, QA/Test, Security/Privacy, TPM, and Delivery
  Management. Every role must return GO with Required 0 before the coordinator
  assembles the regression-continuation planning checkpoint.
- The coordinator records the exact brief SHA and reviewer dispositions in
  `docs/delivery/progress.md`. The planning checkpoint must be the single direct
  child of `f480f8361b562acda760f27e836f8ae595c60a1d` and contain exactly this
  brief, `docs/delivery/task-briefs/SHA256SUMS`, and
  `docs/delivery/progress.md`. It must be committed, pushed, and verified at
  exact HEAD/upstream/live-remote equality with ahead/behind `0/0` before any
  regression command runs.
- One fresh serialized regression verifier/Implementer owns only the one-time
  fresh-DerivedData Store plus plugin-lifecycle regression and its temporary
  result parsing. It may not edit source, project configuration, either fixture,
  or planning authority; it may not run any generator, RED, attachment export,
  copy, checksum creation, or direct fixture-generation step.
- After implementation, a separate Code Reviewer and QA verifier, plus
  Architecture, Security/Privacy, TPM, and Delivery Management, must return GO
  with Required 0 before the Task 2A implementation checkpoint is committed or
  Task 2B opens.

## Current regression-continuation scope

- Verify the accepted design, ADR, plan, Task 1A, Task 1B, prior Task 2A, and
  final Task 2A0 brief identities without modifying them.
- Verify HEAD, upstream, and live remote are the exact new planning checkpoint,
  whose sole parent is `f480f8361b562acda760f27e836f8ae595c60a1d`, whose
  inventory is exactly the revised Task 2A brief, root registry, and
  coordinator ledger, and whose ahead/behind count is `0/0`.
- Verify the committed and working project blob is exactly
  `2b984d44e5b73602bf04b18b761d308761de789c` and the Task 2A0 membership
  exception occurs exactly once.
- Verify the accepted schema-v10 fixture, both generated SchemaV11 artifacts,
  and all five accepted Task 1B source/test paths at their pinned identities.
- Preserve the immutable Task 2A RED/export/GREEN generator record and durable
  RED packet. Explicitly prohibit every rerun of those commands and every new
  generator, attachment, export, fixture copy, or checksum write.
- Run exactly one serialized regression from fresh absent DerivedData and
  result-bundle paths, selecting only `StoreAcceptanceTests` and
  `CodexPluginLifecycleAcceptanceTests` with parallel testing disabled.
- Parse the fresh result fail-closed: Passed exactly 58/58, zero failed,
  skipped, expected failures, or test-failure records; exactly 37 Store test
  cases and 21 plugin-lifecycle test cases; no other suite and no generator
  test identifier.
- Recheck immutable source, project, fixtures, planning authority, exact
  two-file untracked inventory, and `git diff --check` after the run.

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
- Rerunning the Task 2A missing-gate RED, RED attachment export, GREEN
  `build-for-testing`, configured `.xctestrun`, GREEN generator, GREEN result
  parsing, attachment export/copy, checksum creation, or direct SQLite
  generation assertions; all are immutable historical evidence
- Rerunning either Task 2A0 `build-for-testing` RED/GREEN or modifying its
  accepted project membership correction
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

Consumed immutable historical evidence:

- `docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json`

Current regression-planning outputs:

- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md`
- `docs/delivery/task-briefs/SHA256SUMS`
- coordinator-owned `docs/delivery/progress.md`

The planning checkpoint contains exactly those three current planning paths.
The later Task 2A implementation checkpoint contains exactly the two durable
fixture outputs plus coordinator-owned ledger evidence.

Accepted source, unchanged throughout continuation:

- `ReleaseRadarTests/StoreAcceptanceTests.swift`

Consumed unchanged:

- `ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite`
- `ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS`
- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarCore/Store/DeliveryStore.swift`
- `ReleaseRadarCore/Models/DeliveryGoalModels.swift`
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`

Task 2A0 changed and committed `ReleaseRadar.xcodeproj/project.pbxproj` at
checkpoint `f480f8361b562acda760f27e836f8ae595c60a1d`; its current blob
`2b984d44e5b73602bf04b18b761d308761de789c` is now an immutable consumed
dependency. No further project-file change is required or authorized.

## Data, persistence, security, and privacy implications

The generator-specific bullets below describe completed historical evidence;
they do not authorize another generator, export, copy, checksum, or direct
SQLite generation check. The current regression uses only XCTest's isolated
temporary stores through the two accepted selected suites and never accesses
owner state.

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
- The repository-owned RED evidence packet is stable, privacy-sanitized JSON.
  It contains only the exact command/tool identity, required outcome facts,
  hashes of the four reviewed source captures, accepted-source restoration,
  destination absence, and explicit privacy exclusions. Device identifiers,
  device names, other hardware metadata, owner data, and user paths are omitted.
  The packet is the sole RED recovery authority after its corrected planning
  checkpoint; temporary capture files are non-authoritative and disposable.
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

## Immutable historical generator evidence — do not execute

Use only XCTest, CryptoKit/Foundation/Darwin already available to the test
target, `DeliveryStore`, `SQLiteConnection`, Xcode's generated `.xctestrun`,
system `xcresulttool`, `sqlite3`, and `shasum`. Do not call the existing
nonthrowing-assertion-based `copyVerifiedVersionTenFixture()` helper from the
generator. Add no durable helper, dependency, or harness.

Everything from this heading through `Checksum and complete direct SQLite
verification` records the already-completed Task 2A generator cycle. Every
shell and source fence in that historical span is archival evidence, not an
executable continuation. Do not reapply the source, run a fence, recreate or
reparse a RED/GREEN result, export an attachment, copy fixture bytes, create a
checksum, or rerun direct generation verification. The only executable Task 2A
continuation begins at `Regression-continuation planning checkpoint gate`.

### Historical temporary generator source — completed and removed

The first Implementer temporarily added `import Darwin` plus this generator-
local throwing verification/copy boundary and one test before the preserved
RED, then removed them byte-exactly. After the corrected checkpoint and RED
recovery gate pass, the fresh Implementer reapplies this exact source solely
for GREEN. Do not alter the existing helper, add another generator, run the
absent-gate RED again, or add a shipping/debug fixture mode:

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

### Historical corrected pre-GREEN immutable-boundary checks — passed, do not run

The following block passed before the one GREEN generator run. It is preserved
verbatim as provenance and must not be run from the current checkout:

```bash
set -euo pipefail
RR_TASK2A_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md
RR_TASK2A_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2A_RED_EVIDENCE=docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json
RR_TASK2A_LEDGER=docs/delivery/progress.md
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
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY" "$RR_TASK2A_RED_EVIDENCE" \
  "$RR_TASK2A_LEDGER"
git diff --cached --exit-code "$RR_TASK2A_PLANNING_SHA" -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY" "$RR_TASK2A_RED_EVIDENCE" \
  "$RR_TASK2A_LEDGER"
git diff --exit-code -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY" "$RR_TASK2A_RED_EVIDENCE" \
  "$RR_TASK2A_LEDGER"
test "$(git hash-object "$RR_TASK2A_BRIEF")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_BRIEF")"
test "$(git hash-object "$RR_TASK2A_REGISTRY")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_REGISTRY")"
test "$(git hash-object "$RR_TASK2A_RED_EVIDENCE")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_RED_EVIDENCE")"
test "$(git hash-object "$RR_TASK2A_LEDGER")" = \
  "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_LEDGER")"

test "$(awk -v brief_file="$RR_TASK2A_BRIEF" \
  '$2 == brief_file { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A_REGISTRY")" = "1"
RR_TASK2A_REGISTERED_BRIEF_SHA="$(awk -v brief_file="$RR_TASK2A_BRIEF" \
  '$2 == brief_file { print $1 }' "$RR_TASK2A_REGISTRY")"
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
one equal registry entry, the full root registry, and byte identity of all four
corrected planning-checkpoint paths—the brief, registry, durable RED packet,
and coordinator ledger—to the remotely exact commit, plus the wholly absent
destination. Do not repair an accepted dependency inside Task 2A.

### Historical durable RED recovery — passed, do not run

The missing-gate RED already ran exactly once. The privacy-sanitized repository
packet at
`docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json` is the sole
continuation authority after the corrected planning checkpoint. Its source
hashes identify the reviewed capture inputs, but those original temporary
summary/details/manifest/report files, result bundle, DerivedData, and export
directory are non-authoritative provenance and are not recovery inputs. Their
loss does not block continuation once this exact packet is committed and
remote-exact.

The packet records the exact one-run command, `xcresulttool` version 24757 and
schema 0.1.0, direct selected-test result facts, and the schema-valid empty top-
level `AttachmentDetails` array. A fresh Implementer must not run `xcodebuild`,
regenerate RED summary/details, or repeat `xcresulttool export` for RED.

The following repository-only recovery gate passed before the temporary source
was reapplied for GREEN. The SHA-256 literal below remains the packet's
historical pin; do not execute the block again:

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
RR_TASK2A_REPO_ROOT="$(git rev-parse --show-toplevel)"
test "$(pwd -P)" = "$(realpath "$RR_TASK2A_REPO_ROOT")"
RR_TASK2A_EVIDENCE_PARENT="$RR_TASK2A_REPO_ROOT/docs/delivery/evidence"
RR_TASK2A_RED_EVIDENCE="$RR_TASK2A_EVIDENCE_PARENT/2026-08-30-rr-r10-task-2a-red-evidence.json"
RR_TASK2A_RED_EVIDENCE_SHA=95bfa880903408d20ef7fbaaa8051ef6a2908a45d2ada9f6d01e8ba9d89cdea5
rr_task2a_require_directory "$RR_TASK2A_EVIDENCE_PARENT"
test "$(realpath "$RR_TASK2A_EVIDENCE_PARENT")" = \
  "$(realpath "$RR_TASK2A_REPO_ROOT")/docs/delivery/evidence"
rr_task2a_require_file "$RR_TASK2A_RED_EVIDENCE"
test "$(realpath "$RR_TASK2A_RED_EVIDENCE")" = \
  "$(realpath "$RR_TASK2A_EVIDENCE_PARENT")/2026-08-30-rr-r10-task-2a-red-evidence.json"
test "$(shasum -a 256 "$RR_TASK2A_RED_EVIDENCE" | awk '{print $1}')" = \
  "$RR_TASK2A_RED_EVIDENCE_SHA"
/usr/bin/plutil -convert json -o - "$RR_TASK2A_RED_EVIDENCE" >/dev/null

test "$(plutil -extract evidence_schema_version raw "$RR_TASK2A_RED_EVIDENCE")" = "1"
test "$(plutil -extract capture.execution_count raw "$RR_TASK2A_RED_EVIDENCE")" = "1"
test "$(plutil -extract capture.temporary_capture_provenance_authoritative raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "false"
test "$(plutil -extract capture.xcresulttool_version raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "24757"
test "$(plutil -extract capture.xcresulttool_schema_version raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "0.1.0"

test "$(plutil -extract capture.command_argv raw -expect array \
  "$RR_TASK2A_RED_EVIDENCE")" = "13"
test "$(plutil -extract capture.command_argv.0 raw "$RR_TASK2A_RED_EVIDENCE")" = "xcodebuild"
test "$(plutil -extract capture.command_argv.1 raw "$RR_TASK2A_RED_EVIDENCE")" = "test"
test "$(plutil -extract capture.command_argv.2 raw "$RR_TASK2A_RED_EVIDENCE")" = "-project"
test "$(plutil -extract capture.command_argv.3 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "ReleaseRadar.xcodeproj"
test "$(plutil -extract capture.command_argv.4 raw "$RR_TASK2A_RED_EVIDENCE")" = "-scheme"
test "$(plutil -extract capture.command_argv.5 raw "$RR_TASK2A_RED_EVIDENCE")" = "ReleaseRadar"
test "$(plutil -extract capture.command_argv.6 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "-destination"
test "$(plutil -extract capture.command_argv.7 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "platform=macOS"
test "$(plutil -extract capture.command_argv.8 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "-derivedDataPath"
test "$(plutil -extract capture.command_argv.9 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "/tmp/release-radar-rr-r10-task2a-red.hEFKt4/DerivedData"
test "$(plutil -extract capture.command_argv.10 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "-resultBundlePath"
test "$(plutil -extract capture.command_argv.11 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "/tmp/release-radar-rr-r10-task2a-red.hEFKt4/red.xcresult"
test "$(plutil -extract capture.command_argv.12 raw "$RR_TASK2A_RED_EVIDENCE")" = \
  "-only-testing:ReleaseRadarTests/StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment"

test "$(plutil -extract source_sha256.red_summary raw \
  "$RR_TASK2A_RED_EVIDENCE")" = \
  "b82976f48fca9e7dc3ff2f68c97eb2e3d5575e3cf41c7cd4f8c2f1d04ed9e4e3"
test "$(plutil -extract source_sha256.red_details raw \
  "$RR_TASK2A_RED_EVIDENCE")" = \
  "4f35b2c3d09c0cf684b600f28c6690a36cd49e24f6abec4c6be6aa295b1f5c9c"
test "$(plutil -extract source_sha256.red_manifest raw \
  "$RR_TASK2A_RED_EVIDENCE")" = \
  "ace810d7e2cbb4f8c40ce09dc8e191ae466adb4e1a7d49c59f2215b411d38b05"
test "$(plutil -extract source_sha256.implementer_report raw \
  "$RR_TASK2A_RED_EVIDENCE")" = \
  "19bf2b8c989e4c381e76c64fa7a92bff172e2b165c2b7a9e7e18874185707d20"

test "$(plutil -extract result.status raw "$RR_TASK2A_RED_EVIDENCE")" = "Failed"
test "$(plutil -extract result.total_tests raw "$RR_TASK2A_RED_EVIDENCE")" = "1"
test "$(plutil -extract result.passed_tests raw "$RR_TASK2A_RED_EVIDENCE")" = "0"
test "$(plutil -extract result.failed_tests raw "$RR_TASK2A_RED_EVIDENCE")" = "1"
test "$(plutil -extract result.skipped_tests raw "$RR_TASK2A_RED_EVIDENCE")" = "0"
test "$(plutil -extract result.expected_failures raw "$RR_TASK2A_RED_EVIDENCE")" = "0"
test "$(plutil -extract result.failure_count raw "$RR_TASK2A_RED_EVIDENCE")" = "1"
test "$(plutil -extract result.failure_kind raw "$RR_TASK2A_RED_EVIDENCE")" = "XCTUnwrap"
test "$(plutil -extract result.failure_text raw "$RR_TASK2A_RED_EVIDENCE")" = \
  'XCTUnwrap failed: expected non-nil value of type "String"'
test "$(plutil -extract result.test_identifier raw "$RR_TASK2A_RED_EVIDENCE")" = \
  'StoreAcceptanceTests/testGenerateExactVersionElevenFixtureAttachment()'
test "$(plutil -extract result.has_media_attachments raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "false"
test "$(plutil -extract result.manifest raw -expect array \
  "$RR_TASK2A_RED_EVIDENCE")" = "0"
test "$(plutil -extract result.export_inventory raw -expect array \
  "$RR_TASK2A_RED_EVIDENCE")" = "1"
test "$(plutil -extract result.export_inventory.0 raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "manifest.json"
test "$(plutil -extract result.green_executed raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "false"
test "$(plutil -extract result.schema_v11_destination_absent raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "true"

test "$(plutil -extract privacy.contains_owner_data raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "false"
test "$(plutil -extract privacy.excluded_fields raw -expect array \
  "$RR_TASK2A_RED_EVIDENCE")" = "5"
test "$(plutil -extract privacy.excluded_fields.0 raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "device_identifiers"
test "$(plutil -extract privacy.excluded_fields.1 raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "device_names"
test "$(plutil -extract privacy.excluded_fields.2 raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "hardware_metadata"
test "$(plutil -extract privacy.excluded_fields.3 raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "owner_data"
test "$(plutil -extract privacy.excluded_fields.4 raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "user_paths"

RR_TASK2A_ACCEPTED_COMMIT="$(plutil -extract \
  result.store_acceptance_tests_restoration.accepted_commit raw \
  "$RR_TASK2A_RED_EVIDENCE")"
RR_TASK2A_ACCEPTED_BLOB="$(plutil -extract \
  result.store_acceptance_tests_restoration.accepted_git_blob raw \
  "$RR_TASK2A_RED_EVIDENCE")"
test "$RR_TASK2A_ACCEPTED_COMMIT" = "b711229a109c1a58c9616e4ff907afb18cd4f958"
test "$RR_TASK2A_ACCEPTED_BLOB" = "7041bd69a9a8349e7164eaee21a11858e9ebd87d"
test "$(plutil -extract \
  result.store_acceptance_tests_restoration.restored_to_accepted_blob raw \
  "$RR_TASK2A_RED_EVIDENCE")" = "true"
RR_TASK2A_TEST_SOURCE=ReleaseRadarTests/StoreAcceptanceTests.swift
test "$(git rev-parse "$RR_TASK2A_ACCEPTED_COMMIT:$RR_TASK2A_TEST_SOURCE")" = \
  "$RR_TASK2A_ACCEPTED_BLOB"
test "$(git hash-object "$RR_TASK2A_TEST_SOURCE")" = "$RR_TASK2A_ACCEPTED_BLOB"
RR_TASK2A_FIXTURE_DIR="$PWD/ReleaseRadarTests/Fixtures/SchemaV11"
test ! -e "$RR_TASK2A_FIXTURE_DIR"
test ! -L "$RR_TASK2A_FIXTURE_DIR"
```

Accepted RED requires every assertion above. The exact durable packet proves
one execution, exact command/tool identity, Failed exactly 1/1, zero passed/
skipped/expected failures, sole selected-test `XCTUnwrap` failure,
`hasMediaAttachments=false`, an exact empty top-level manifest, one-file export
inventory, GREEN not run, restored accepted source, and absent durable
destination. It contains no device identifiers/names, other hardware metadata,
owner data, or user paths. Its command's `/tmp` arguments and source hashes are
capture provenance only; no temporary object is opened by this gate.

Any packet path/type/canonicalization/digest/JSON/field mismatch is not accepted
evidence and stops continuation. It does not authorize another RED run. RED is
complete and must never be rerun for Task 2A.

### Historical GREEN: one sandbox-safe attachment generation — passed once, do not run

After the historical corrected planning checkpoint became remote-exact and the
durable RED evidence gate passed, the fresh Implementer reapplied the temporary
source and executed the following GREEN block exactly once. That action is
complete. The block is retained only as provenance and authorizes no current
execution.

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

After the fresh GREEN summary/detail assertions passed, the Implementer removed
`import Darwin`, `Task2AGeneratorInput`,
`makeVerifiedTask2AGeneratorInput()`, and
`testGenerateExactVersionElevenFixtureAttachment()` with `apply_patch`, then
ran the following source-restoration gate before attachment export. It is
historical and must not be rerun:

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

### Historical attachment export and exclusive copy — completed, do not run

The Implementer exported only the selected test's attachment to a new absent
temporary directory, validated the summary/manifest and safe names, and copied
the exported bytes into the then-absent repository path with the following
block. This completed action must not be repeated:

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

### Historical checksum and complete direct SQLite verification — completed, do not run

The Implementer created the local checksum from inside the fixture directory so
its manifest contains only the fixture filename. The following block is
historical and must not be repeated:

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

The following fail-fast assertion block then passed from the repository root.
It is retained as immutable evidence and must not be rerun:

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

### Regression-continuation planning checkpoint gate

Before any regression command, Architecture, QA/Test, Security/Privacy, TPM,
and Delivery Management must each return GO with Required 0 on this exact
registered brief. The coordinator then updates only the ledger and creates the
three-path planning checkpoint. Extract this fence and run it once with
`/bin/bash` from the canonical repository root after that checkpoint is pushed:

```bash
set -euo pipefail
export LC_ALL=C
RR_TASK2A_ROOT="$(git rev-parse --show-toplevel)"
RR_TASK2A_BRANCH=codex/release-radar-mvp
RR_TASK2A_PARENT=f480f8361b562acda760f27e836f8ae595c60a1d
RR_TASK2A_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md
RR_TASK2A_REGISTRY=docs/delivery/task-briefs/SHA256SUMS
RR_TASK2A_LEDGER=docs/delivery/progress.md
RR_TASK2A_PROJECT=ReleaseRadar.xcodeproj/project.pbxproj
RR_TASK2A_TASK2A0_BRIEF=docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a0-xcode-fixture-manifest-membership-prerequisite-brief.md
RR_TASK2A_RED_EVIDENCE=docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json
RR_TASK2A_FIXTURES_ROOT=ReleaseRadarTests/Fixtures
RR_TASK2A_V11_DIR="$RR_TASK2A_FIXTURES_ROOT/SchemaV11"
RR_TASK2A_V11_MANIFEST="$RR_TASK2A_V11_DIR/SHA256SUMS"
RR_TASK2A_V11_DATABASE="$RR_TASK2A_V11_DIR/release-radar-v11.sqlite"

test "$(pwd -P)" = "$(realpath "$RR_TASK2A_ROOT")"
test "$(git branch --show-current)" = "$RR_TASK2A_BRANCH"
RR_TASK2A_BRIEF_DIGEST="$(shasum -a 256 "$RR_TASK2A_BRIEF" | awk '{print $1}')"
test "$(awk -v brief_file="$RR_TASK2A_BRIEF" \
  '$2 == brief_file { count += 1 } END { print count + 0 }' \
  "$RR_TASK2A_REGISTRY")" = "1"
test "$(awk -v brief_file="$RR_TASK2A_BRIEF" \
  '$2 == brief_file { print $1 }' "$RR_TASK2A_REGISTRY")" = \
  "$RR_TASK2A_BRIEF_DIGEST"
shasum -a 256 -c "$RR_TASK2A_REGISTRY"

RR_TASK2A_PLANNING_SHA="$(git rev-parse HEAD)"
test "$(git rev-parse "$RR_TASK2A_PLANNING_SHA^")" = "$RR_TASK2A_PARENT"
test "$(git rev-list --count "$RR_TASK2A_PARENT..$RR_TASK2A_PLANNING_SHA")" = "1"
RR_TASK2A_EXPECTED_INVENTORY="$(printf '%s\n' \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY" "$RR_TASK2A_LEDGER" | LC_ALL=C sort)"
RR_TASK2A_ACTUAL_INVENTORY="$(git diff-tree --no-commit-id --name-only -r \
  "$RR_TASK2A_PLANNING_SHA" | LC_ALL=C sort)"
test "$RR_TASK2A_ACTUAL_INVENTORY" = "$RR_TASK2A_EXPECTED_INVENTORY"
for checkpoint_file in \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY" "$RR_TASK2A_LEDGER"; do
  test "$(git hash-object "$checkpoint_file")" = \
    "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$checkpoint_file")"
done

git fetch --quiet origin "$RR_TASK2A_BRANCH"
test "$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" = \
  "origin/$RR_TASK2A_BRANCH"
test "$(git rev-parse '@{upstream}')" = "$RR_TASK2A_PLANNING_SHA"
RR_TASK2A_REMOTE_LINES="$(git ls-remote --heads origin \
  "refs/heads/$RR_TASK2A_BRANCH")"
test "$(printf '%s\n' "$RR_TASK2A_REMOTE_LINES" | \
  awk 'NF { count += 1 } END { print count + 0 }')" = "1"
test "$(printf '%s\n' "$RR_TASK2A_REMOTE_LINES" | awk '{print $1}')" = \
  "$RR_TASK2A_PLANNING_SHA"
read -r RR_TASK2A_AHEAD RR_TASK2A_BEHIND < <(
  git rev-list --left-right --count HEAD...'@{upstream}'
)
test "$RR_TASK2A_AHEAD" = "0"
test "$RR_TASK2A_BEHIND" = "0"

git diff --cached --exit-code
git diff --exit-code
test "$(git status --short --untracked-files=all)" = \
  "$(printf '?? %s\n?? %s' \
    'ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' \
    'ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite')"
test "$(git rev-parse "$RR_TASK2A_PARENT:$RR_TASK2A_PROJECT")" = \
  "2b984d44e5b73602bf04b18b761d308761de789c"
test "$(git rev-parse "$RR_TASK2A_PLANNING_SHA:$RR_TASK2A_PROJECT")" = \
  "2b984d44e5b73602bf04b18b761d308761de789c"
test "$(git hash-object "$RR_TASK2A_PROJECT")" = \
  "2b984d44e5b73602bf04b18b761d308761de789c"
test "$(rg -F -o 'Fixtures/SchemaV11/SHA256SUMS' "$RR_TASK2A_PROJECT" | \
  wc -l | tr -d ' ')" = "1"

test "$(shasum -a 256 docs/design/release-radar-ticket-tasks-design.md | awk '{print $1}')" = \
  "c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08"
test "$(shasum -a 256 docs/architecture/ADR-005-ticket-task-work-plans.md | awk '{print $1}')" = \
  "6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5"
test "$(shasum -a 256 docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md | awk '{print $1}')" = \
  "2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1"
test "$(shasum -a 256 "$RR_TASK2A_TASK2A0_BRIEF" | awk '{print $1}')" = \
  "db34c56d5c312a82b35e5a07434a94db2388d567e75ac1e8085d307d69dce733"
test "$(shasum -a 256 "$RR_TASK2A_RED_EVIDENCE" | awk '{print $1}')" = \
  "95bfa880903408d20ef7fbaaa8051ef6a2908a45d2ada9f6d01e8ba9d89cdea5"

test "$(stat -f '%z' ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite)" = "278528"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/release-radar-v10.sqlite | awk '{print $1}')" = \
  "9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559"
test "$(shasum -a 256 ReleaseRadarTests/Fixtures/SchemaV10/SHA256SUMS | awk '{print $1}')" = \
  "c1c162cabdeb43ec92471b15de4e2d1ee30e7a50c15c89a2503e0c8c58c1b28f"
(cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS)

for fixture_directory in "$RR_TASK2A_FIXTURES_ROOT" "$RR_TASK2A_V11_DIR"; do
  test -d "$fixture_directory"
  test ! -L "$fixture_directory"
  test "$(/usr/bin/stat -f '%HT' "$fixture_directory")" = "Directory"
done
RR_TASK2A_FIXTURES_REAL="$(realpath "$RR_TASK2A_FIXTURES_ROOT")"
RR_TASK2A_V11_REAL="$(realpath "$RR_TASK2A_V11_DIR")"
test "$RR_TASK2A_FIXTURES_REAL" = \
  "$(realpath "$RR_TASK2A_ROOT")/$RR_TASK2A_FIXTURES_ROOT"
test "$RR_TASK2A_V11_REAL" = "$RR_TASK2A_FIXTURES_REAL/SchemaV11"
for v11_file in "$RR_TASK2A_V11_MANIFEST" "$RR_TASK2A_V11_DATABASE"; do
  test -f "$v11_file"
  test ! -L "$v11_file"
  test "$(/usr/bin/stat -f '%HT' "$v11_file")" = "Regular File"
  test "$(dirname "$(realpath "$v11_file")")" = "$RR_TASK2A_V11_REAL"
done
test "$(/usr/bin/stat -f '%z' "$RR_TASK2A_V11_MANIFEST")" = "91"
test "$(/usr/bin/stat -f '%z' "$RR_TASK2A_V11_DATABASE")" = "348160"
test "$(shasum -a 256 "$RR_TASK2A_V11_DATABASE" | awk '{print $1}')" = \
  "ad6f2eddf7d47016d4f09fdf50bc82ad8f3cce94043064713607d6b07934762c"
test "$(shasum -a 256 "$RR_TASK2A_V11_MANIFEST" | awk '{print $1}')" = \
  "ea66d26b4172876ed473a98e09b54149e0fc4896186ed63bd66f8e70bbd17da3"
(cd "$RR_TASK2A_V11_DIR" && shasum -a 256 -c SHA256SUMS)

while read -r expected_blob source_file; do
  test "$(git hash-object "$source_file")" = "$expected_blob"
done <<'SOURCE_BLOBS'
6864341813b5534c44af2190111c00051422940a ReleaseRadarCore/Models/DeliveryGoalModels.swift
1cf2170f0ba80df7b576bc90b84d528cc3b1efc4 ReleaseRadarCore/Store/DeliveryStore.swift
c6a15c122eb37aebfc62a8927639ce0b4c14699d ReleaseRadarCore/Store/StoreMigrations.swift
7041bd69a9a8349e7164eaee21a11858e9ebd87d ReleaseRadarTests/StoreAcceptanceTests.swift
ffd37da848294fc071cdd9954ba10de812138157 ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
SOURCE_BLOBS
test "$(rg -c '^    func test' ReleaseRadarTests/StoreAcceptanceTests.swift)" = "37"
test "$(rg -c '^    func test' ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift)" = "21"
if rg -q 'testGenerateExactVersionElevenFixtureAttachment|Task2AGeneratorInput|RR_SCHEMA_V11_FIXTURE_EXPORT' \
  ReleaseRadarTests/StoreAcceptanceTests.swift; then
  exit 1
fi
git diff --check "$RR_TASK2A_PARENT..$RR_TASK2A_PLANNING_SHA" -- \
  "$RR_TASK2A_BRIEF" "$RR_TASK2A_REGISTRY" "$RR_TASK2A_LEDGER"
```

Any mismatch is Required and stops before regression. It never authorizes a
generator, build-for-testing, export, fixture rewrite, source/project edit, or
repair inside Task 2A.

### One-time serialized 58-test regression continuation

After the planning gate passes, a fresh regression verifier/Implementer runs
this fence exactly once with `/bin/bash`. The selected test command is the
repository-native Task 1B Store plus plugin-lifecycle boundary. If the command
or parser fails, preserve the one result and stop; do not retry without a new
reviewed continuation decision.

```bash
set -euo pipefail
export LC_ALL=C
umask 077
RR_TASK2A_REGRESSION_PARENT="$(mktemp -d /tmp/release-radar-rr-r10-task2a-regression.XXXXXX)"
RR_TASK2A_REGRESSION_DERIVED="$RR_TASK2A_REGRESSION_PARENT/DerivedData"
RR_TASK2A_REGRESSION_RESULT="$RR_TASK2A_REGRESSION_PARENT/regression.xcresult"
RR_TASK2A_REGRESSION_SUMMARY="$RR_TASK2A_REGRESSION_PARENT/regression-summary.json"
RR_TASK2A_REGRESSION_TESTS="$RR_TASK2A_REGRESSION_PARENT/regression-tests.json"
test -d "$RR_TASK2A_REGRESSION_PARENT"
test ! -L "$RR_TASK2A_REGRESSION_PARENT"
test "$(/usr/bin/stat -f '%HT' "$RR_TASK2A_REGRESSION_PARENT")" = "Directory"
test "$(/usr/bin/stat -f '%Lp' "$RR_TASK2A_REGRESSION_PARENT")" = "700"
for absent_item in \
  "$RR_TASK2A_REGRESSION_DERIVED" \
  "$RR_TASK2A_REGRESSION_RESULT" \
  "$RR_TASK2A_REGRESSION_SUMMARY" \
  "$RR_TASK2A_REGRESSION_TESTS"; do
  test ! -e "$absent_item"
  test ! -L "$absent_item"
done

xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
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
  xcrun xcresulttool get test-results tests \
    --path "$RR_TASK2A_REGRESSION_RESULT" --compact > \
    "$RR_TASK2A_REGRESSION_TESTS"
)
for result_file in \
  "$RR_TASK2A_REGRESSION_SUMMARY" "$RR_TASK2A_REGRESSION_TESTS"; do
  test -f "$result_file"
  test ! -L "$result_file"
  test "$(/usr/bin/stat -f '%HT' "$result_file")" = "Regular File"
  test "$(dirname "$(realpath "$result_file")")" = \
    "$(realpath "$RR_TASK2A_REGRESSION_PARENT")"
  /usr/bin/plutil -convert json -o - "$result_file" >/dev/null
done
RR_TASK2A_PYTHON="$(command -v python3)"
test -n "$RR_TASK2A_PYTHON"
"$RR_TASK2A_PYTHON" - \
  "$RR_TASK2A_REGRESSION_SUMMARY" \
  "$RR_TASK2A_REGRESSION_TESTS" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    document = json.load(source)

expected_summary = {
    "result": "Passed",
    "totalTestCount": 58,
    "passedTests": 58,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
}
if not isinstance(summary, dict):
    raise SystemExit("test summary must be a JSON object")
for key, expected in expected_summary.items():
    if summary.get(key) != expected:
        raise SystemExit(f"unexpected summary field {key}")
if summary.get("testFailures") != []:
    raise SystemExit("testFailures must be an empty array")

cases = []
def visit(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            cases.append((value.get("nodeIdentifier"), value.get("result")))
        for child in value.values():
            visit(child)
    elif isinstance(value, list):
        for child in value:
            visit(child)

visit(document)
if len(cases) != 58 or len({identifier for identifier, _ in cases}) != 58:
    raise SystemExit("expected exactly 58 unique test cases")
if any(result != "Passed" for _, result in cases):
    raise SystemExit("every selected test case must pass")
store = [identifier for identifier, _ in cases if identifier.startswith("StoreAcceptanceTests/")]
plugin = [identifier for identifier, _ in cases if identifier.startswith("CodexPluginLifecycleAcceptanceTests/")]
if len(store) != 37 or len(plugin) != 21 or len(store) + len(plugin) != len(cases):
    raise SystemExit("unexpected selected suite or suite cardinality")
if any("GenerateExactVersionElevenFixtureAttachment" in identifier for identifier, _ in cases):
    raise SystemExit("generator test must not execute")
PYTHON
```

Expected: one fresh serialized result reports Passed exactly 58/58—37 Store
and 21 plugin-lifecycle cases—with zero failed, skipped, expected failures, or
failure records and no generator identifier.

### Post-regression immutable-boundary gate

After the one regression and before postimplementation review, rerun the
planning checkpoint gate above, then run this additional `/bin/bash` fence.
It performs no test, generator, export, fixture write, staging, commit, push,
or owner-state access:

```bash
set -euo pipefail
export LC_ALL=C
test "$(git hash-object ReleaseRadar.xcodeproj/project.pbxproj)" = \
  "2b984d44e5b73602bf04b18b761d308761de789c"
while read -r expected_blob source_file; do
  test "$(git hash-object "$source_file")" = "$expected_blob"
done <<'SOURCE_BLOBS'
6864341813b5534c44af2190111c00051422940a ReleaseRadarCore/Models/DeliveryGoalModels.swift
1cf2170f0ba80df7b576bc90b84d528cc3b1efc4 ReleaseRadarCore/Store/DeliveryStore.swift
c6a15c122eb37aebfc62a8927639ce0b4c14699d ReleaseRadarCore/Store/StoreMigrations.swift
7041bd69a9a8349e7164eaee21a11858e9ebd87d ReleaseRadarTests/StoreAcceptanceTests.swift
ffd37da848294fc071cdd9954ba10de812138157 ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift
SOURCE_BLOBS
(cd ReleaseRadarTests/Fixtures/SchemaV10 && shasum -a 256 -c SHA256SUMS)
(cd ReleaseRadarTests/Fixtures/SchemaV11 && shasum -a 256 -c SHA256SUMS)
test "$(git status --short --untracked-files=all)" = \
  "$(printf '?? %s\n?? %s' \
    'ReleaseRadarTests/Fixtures/SchemaV11/SHA256SUMS' \
    'ReleaseRadarTests/Fixtures/SchemaV11/release-radar-v11.sqlite')"
git diff --cached --exit-code
git diff --exit-code
git diff --check
```

Any mismatch blocks post-run acceptance and Task 2B. Do not modify an accepted
dependency or rerun a generator/test to force the gate.

## Happy path

Task 2A0 checkpoint `f480f83…` is the exact remote-equal baseline and commits
project blob `2b984d44…`. Independent pre-continuation roles accept this exact
brief with Required 0. The coordinator commits only this brief, its sole root-
registry update, and the ledger as one direct child of `f480f83…`, pushes it,
and proves exact HEAD/upstream/live-remote equality at `0/0`. The executable
planning gate pins that checkpoint, project, accepted source, and both fixture
pairs. One fresh serialized regression verifier then runs only the Store and
plugin-lifecycle suites once from fresh DerivedData and result paths. Fail-
closed parsing proves 58 unique passed cases—37 Store and 21 plugin lifecycle—
with no generator case or other suite. The post-run immutable gate passes and
all six post-run roles return GO/Required 0. Only then may the coordinator
stage the two SchemaV11 artifacts plus the ledger for Task 2A's implementation
checkpoint.

## Non-happy paths and recovery

- If the planning checkpoint is not the one direct child of `f480f83…`, its
  inventory is not exactly brief/registry/ledger, or HEAD, upstream, live
  remote, or `0/0` differs, stop before regression.
- If the project commit or working blob is not `2b984d44…`, or the exact Task
  2A0 membership exception does not occur once, stop. Do not restore the older
  project baseline or edit the project in Task 2A.
- If any accepted design/ADR/plan/Task 2A0, Task 1A fixture, Task 1B source, RED
  packet, or SchemaV11 fixture identity differs, stop. Do not repair or
  regenerate an accepted dependency.
- If the exact worktree inventory is not only the two untracked SchemaV11
  artifacts, or either is missing, a symlink, checksum-invalid, or changed from
  its pinned size/digest, stop without overwriting or deleting it.
- If any historical Task 2A/Task 2A0 RED, GREEN, generator, attachment export,
  fixture-copy, checksum-write, direct-generation assertion, or
  `build-for-testing` action is attempted, stop. Historical evidence is never a
  recovery command surface.
- If the regression DerivedData/result/summary/tests path exists before the
  run, the result is not exactly Passed 58/58, suite counts are not exactly
  37/21, any non-pass or unexpected suite/generator identifier appears, or
  parsing fails, reject the run. Preserve it for diagnosis and do not rerun
  without a new reviewed continuation decision.
- If any source, project, fixture, planning file, index, or unrelated path
  changes during regression, return NO-GO. Do not modify it to make the result
  pass.
- No failure authorizes owner-data access, owner-bundle launch/install outside
  the required isolated XCTest host, bridge/MCP use, RR-R10 mutation,
  Accepted-ticket change, live task-plan
  creation, schema repair, entitlement change, or Task 2B implementation.

## Activity and audit evidence requirements

Task 2A is repository-only and creates no Release Radar audit, Activity row,
review item, notification, bridge receipt, ticket evidence, task-plan revision,
or task completion. Historical evidence remains the immutable one RED, RED
export, one GREEN generator, attachment export/copy, checksum, direct SQLite
assertions, exact fixture identities, source restoration, and the accepted
Task 2A0 RED/GREEN plus project correction. Current evidence is the three-path
planning checkpoint and remote gate, exact project/source/fixture pins, one
fresh 58/58 result with 37/21 selected-case parsing, post-run immutable gate,
independent dispositions, and the later exact Task 2A Git/remote checkpoint.

The existing blocker/start audit IDs are read-only dependency evidence. They
must not be replayed or supplemented in this task.

## Historical generator acceptance record — completed, do not execute

The bullets below preserve the criteria used for the completed generator,
export/copy, checksum, and direct SQLite cycle. References to "before RED",
"GREEN continuation", an absent `SchemaV11`, the earlier corrected planning
checkpoint, or no project-file change describe that historical moment only.
They are not current gates and authorize no rerun. Task 2A0 subsequently
changed and committed the project file at `f480f83…` / `2b984d44…`.

- [ ] The accepted design, ADR, and plan hashes match exactly.
- [ ] Task 1A commit/digest and Task 1B commit/path identity are verified and
      unchanged before RED and after implementation.
- [ ] This corrected brief and its root checksum entry are canonical, and
      Architecture, TPM, QA/Test, Delivery Management, and Security/Privacy
      correction reviews are GO with Required 0 on the exact brief SHA before
      any GREEN continuation.
- [ ] The already-recorded pre-RED planning-authority evidence proves its
      planning checkpoint was local/remote exact. Before GREEN continuation,
      the corrected executable gate proves the brief, registry, durable RED
      packet, and coordinator ledger are byte-identical to their new local/
      remote-exact checkpoint in combined, cached/index, unstaged/worktree, and
      exact planning-commit blob state; exactly one Task 2A registry entry
      equals the computed brief SHA; and the full root registry verifies.
- [ ] RED is not rerun. The exact durable sanitized evidence packet is a regular
      non-symlink at its canonical repository path, matches its pinned digest,
      parses as JSON, and passes every required field assertion. It proves one
      exact execution, selected test Failed 1/1, zero passed/skipped/expected
      failures, sole `RR_SCHEMA_V11_FIXTURE_EXPORT` `XCTUnwrap`,
      `hasMediaAttachments=false`, empty top-level manifest, one-file export
      inventory, GREEN not run, restored Task 1B test-source blob, and absent
      `SchemaV11`, while excluding all prohibited private metadata.
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

## Current regression-continuation acceptance criteria

- [ ] Accepted design, ADR, plan, final Task 2A0 brief, durable RED packet,
      Task 1A fixture, Task 1B source/test, and both SchemaV11 artifact
      identities match every pinned value in the planning gate.
- [ ] `f480f8361b562acda760f27e836f8ae595c60a1d` is verified as the accepted
      remote-exact Task 2A0 implementation checkpoint, and its committed plus
      working project blob is exactly
      `2b984d44e5b73602bf04b18b761d308761de789c`.
- [ ] Pre-continuation Architecture, QA/Test, Security/Privacy, TPM, and
      Delivery Management each return GO with Required 0 on the exact revised
      brief SHA and sole root-registry entry.
- [ ] The planning checkpoint is the single direct child of `f480f83…`, has
      exactly the Task 2A brief, root registry, and coordinator ledger in its
      commit inventory, and is HEAD/upstream/live-remote exact at `0/0` before
      regression.
- [ ] Historical Task 2A RED/export/GREEN generator/export/copy/checksum/direct
      SQLite work and Task 2A0 RED/GREEN are not rerun or replaced.
- [ ] One fresh serialized regression verifier runs only Store and plugin-
      lifecycle tests once, using fresh absent DerivedData and result paths and
      `-parallel-testing-enabled NO`.
- [ ] Fresh result parsing proves Passed exactly 58/58: 37 unique Store cases,
      21 unique plugin-lifecycle cases, zero failed/skipped/expected failures or
      failure records, no other suite, and no fixture-generator identifier.
- [ ] The planning gate repeats after the run; the post-run boundary proves the
      exact project/source/fixture identities, empty index, and only the two
      untracked SchemaV11 artifacts; `git diff --check` passes.
- [ ] Fresh Code Review, QA/Test, Architecture, Security/Privacy, TPM, and
      Delivery Management each return GO with Required 0 on the result and
      immutable boundary.
- [ ] The Task 2A implementation checkpoint later contains only the two
      SchemaV11 artifacts plus coordinator-owned `docs/delivery/progress.md`,
      is pushed, and is HEAD/upstream/live-remote exact at `0/0`.
- [ ] Task 2B and every later task remain closed until that remote-exact Task
      2A acceptance checkpoint is complete.

## Required independent reviews and role separation

Historical pre-GREEN reviews below are preserved as evidence and do not
release the regression:

- Architecture verifies accepted v11 provenance, the `xcresulttool` 24757 /
  schema-0.1.0 empty-top-level-array RED contract represented by the durable
  packet, unchanged exactly-one-attachment GREEN manifest contract, single-file
  fixture semantics, and no v12/Ticket Tasks scope.
- QA/Test verifies the exact durable packet digest and all field assertions,
  exact Failed 1/1/no-pass/no-skip/no-expected-failure counts, direct selected-
  test identity, `hasMediaAttachments=false`, exact empty top-level RED export
  manifest, one-file export cardinality, source restoration, destination
  absence, and no-rerun boundary; fresh GREEN 1/1 inspection before source
  removal; GREEN attachment cardinality; direct inventory/default/privacy
  checks; and fresh final 58/58 result-bundle evidence.
- Security/Privacy verifies the packet is stable parseable JSON at the exact
  regular non-symlink canonical repository path, matches the pinned digest,
  contains only the necessary capture facts/source hashes, excludes device
  identifiers/names, user paths, owner data, and other hardware metadata, and
  makes all temporary inputs non-authoritative. It also verifies the throwing
  manifest/digest/copy/schema-10 boundary, test-local-only migration, privacy-
  empty bytes, closed-store copy, exclusive durable copy, exact directory
  inventory/sidecar absence, sandbox preservation, and no owner-data path.
- TPM verifies dependency order, 3–5-hour sizing, bounded scope, and that Task
  2B plus every live Ticket Tasks action remains closed.
- Delivery Management verifies both executable full-registry/exact-one-entry
  planning-authority gates, exact four-path corrected checkpoint including
  coordinator-ledger combined/cached/unstaged/blob identity, durable packet
  digest/field gate and no-rerun boundary, writer serialization, durable path
  placement, evidence, and Git/remote gates.

Before regression, fresh Architecture, QA/Test, Security/Privacy, TPM, and
Delivery Management reviewers independently verify this exact revision,
`f480f83…` plus project blob `2b984d44…`, the three-path planning checkpoint,
no-rerun boundaries, one-run 58-test command/parser, and Task 2B closure. Each
must return GO with Required 0 before the planning checkpoint releases a fresh
serialized regression verifier/Implementer.

After the one-time run, a fresh Code Reviewer and fresh QA verifier
independently review the artifacts and parsed result. Architecture,
Security/Privacy, TPM, and Delivery Management independently disposition the
completed task. The Planning agent cannot run the regression, and the
regression verifier/Implementer cannot review, approve, or independently verify
its own work. Required 0 is a hard gate. Optional findings do not expand scope;
out-of-scope findings are recorded but do not block this task.

## Completion evidence required in `docs/delivery/progress.md`

Delivery Management must record:

- Task 2A status, dependency gate, Planning/Implementer identities, exact brief
  SHA, exact-one-entry/full-root checksum-registry verification, planning-release
  remote checkpoint, and identical post-task planning-authority recheck
- exact design/ADR/plan hashes; Task 1A commit and fixture digest; Task 1B
  commit, ancestry, and five-path identity; unchanged RR-R10 In-progress
  dependency state; and confirmation that no live task plan exists
- exact accepted Task 2A0 checkpoint `f480f83…`, committed project blob
  `2b984d44…`, and exact three-path regression-planning checkpoint parent,
  inventory, local/upstream/live-remote SHA, full registry, ahead/behind `0/0`,
  worktree inventory, and immutable dependency checks/results
- the durable RED evidence packet's exact canonical repository path and digest;
  valid stable JSON; privacy exclusions; every exact command/tool/source-hash/
  result/manifest/inventory/GREEN/source-restoration/destination field; proof
  RED and its export were not rerun; and confirmation that temporary capture
  files are non-authoritative and need not remain
- the completed temporary throwing verifier, format-2 GREEN, source
  restoration, attachment export/copy, checksum, and direct SQLite evidence as
  immutable history, with explicit proof none was rerun during continuation
- fixture path, byte size, SHA-256, fixture-local checksum verification, exact
  28/12/8 and 48-object inventory, zero-row/default-row results, continuation
  column, no-v12 proof, empty foreign-key check, integrity result, exact two-file
  directory inventory, regular non-symlink types, and absent WAL/SHM/journal
- proof the temporary generator was removed; accepted v10 and Task 1B paths
  remained unchanged; and no result/export/build or other temporary artifact is
  durable
- exact one-time Store/plugin regression command, fresh absent DerivedData and
  result paths, serialized/parallel-disabled execution, result identity,
  summary Passed 58/58, exact parsed 37/21 unique selected-case split, no other
  suite or generator case, all non-pass counts zero, and post-run immutable/
  `git diff --check` results
- pre- and postimplementation reviewer identities, GO/NO-GO dispositions,
  Required/Optional/Out-of-scope counts, and Required 0 closure
- confirmation of no owner/app/bridge/board/ticket/Accepted-ticket/task-plan/
  external-state mutation and no unrelated path change
- exact staged paths, staged-diff inspection, commit SHA, push result,
  `git ls-remote` remote SHA, local/remote equality, and ahead/behind `0/0`
- remaining risks/blockers and Task 2B as the next eligible task only after the
  exact remote checkpoint

## Task-specific completion and Git/remote boundary

The original Task 2A generator checkpoints and Task 2A0 checkpoint are
immutable history. Before regression continuation, the coordinator creates one
planning checkpoint whose parent is exactly
`f480f8361b562acda760f27e836f8ae595c60a1d` and whose inventory is exactly:

```text
docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md
docs/delivery/task-briefs/SHA256SUMS
docs/delivery/progress.md
```

Inspect the staged diff, commit/push it, and verify exact local/remote equality
with ahead/behind `0/0`. It contains no evidence packet, project, source, test,
fixture, or temporary result. This does not complete the product task or create
a live Ticket Tasks row; it only releases the one-time regression continuation.

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
accepted Task 1B paths, Task 2A0 project file, planning files already
checkpointed above, every historical/current temporary result/export/build
path, and every unrelated path are excluded. Task 2B remains dependency-
blocked until fresh post-run Code Review, QA/Test, Architecture,
Security/Privacy, TPM, and Delivery Management return GO with Required 0 and
this exact Task 2A fixture/ledger checkpoint is accepted, committed, pushed,
and HEAD/upstream/live-remote exact at `0/0`.
