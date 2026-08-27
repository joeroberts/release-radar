# SQLite-23 Implementer Report

Status: **NEEDS_CONTEXT / BLOCKED before production implementation.** No commits created.

## Scope and files

The authorized write scope was respected. The only repository edit is a new, currently RED
regression in `ReleaseRadarTests/OnboardingAcceptanceTests.swift`:

- `testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation`
  creates a synthetic version-9 database, adds the specified legacy `active_phase_id` index and
  validation triggers, reopens `DeliveryStore`, then drives the real
  `FolderProjectOnboarding.inspect` / `prepare` path. Its post-success assertions cover project,
  root, bookmark, pending marker, one onboarding audit, no automatic phase/command/notification
  actions, foreign keys, foreign-key check, repository sentinel/listing, relaunch, and bookmark
  scope balance.

No change was made to `ReleaseRadarCore/Store/SQLiteConnection.swift`,
`ReleaseRadarTests/StoreAcceptanceTests.swift`, or `script/build_and_run.sh`. No migrations,
onboarding SQL, owner data, app bundle, `/Applications/ReleaseRadar.app`, Keychain, staging,
installation, commits, or Git index were touched.

## Root-cause diagnostic (pre-source-edit)

A temporary in-memory synthetic SQLite diagnostic used the production upsert and the current
blanket protected-table authorizer. With the legacy index and both active-phase validation
triggers present, it produced:

```text
action = SQLITE_READ (20)
firstArgument = audit_events
secondArgument = project_id
statement = onboarding projects upsert above
prepare result = SQLITE_AUTH (23)
message = access to audit_events.project_id is prohibited
```

The negative control without those triggers produced `SQLITE_OK (0)` at prepare and
`SQLITE_DONE (101)` at execution. This diagnostic used only synthetic schema and values.

## RED evidence

Initial test compilation exposed invalid async assertions; this was corrected before counting
RED evidence. No production source changed.

Command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-red-verified \
  -resultBundlePath /tmp/release-radar-sqlite23-red-verified.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests/testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation
```

Result: 1 selected test failed, as expected before the authorizer repair. The retained
`.xcresult` is `/tmp/release-radar-sqlite23-red-verified.xcresult`.

`xcrun xcresulttool get test-results tests` reports the real callback failure at
`SQLiteConnection.swift:167` as:

```text
SQLiteError(code: 23, message: "not authorized")
```

This confirms the real legacy-schema onboarding callback reaches the protected-table
authorization failure, but it **does not meet the brief's explicit requirement** that this RED
fixture expose the exact message `access to audit_events.project_id is prohibited`.

## Blocking contradiction / owner addendum

The synthetic direct SQLite diagnostic has the exact owner-visible message, while the real
`SQLiteConnection` callback test only observes SQLite's generic `not authorized` message. The
brief directs the Implementer to stop and return to Planning if RED evidence contradicts it;
therefore no authorizer fix, durable logging, security matrix, or script change was attempted.

While blocked, the owner added a binding requirement that the migrated-schema fixture start with
representative unrelated durable project, active-phase, ticket/child, and scoped-audit state and
assert preservation. The existing RED regression was created before that addendum and uses a
fresh synthetic current database plus legacy compatibility objects, so it must be revised by the
next released implementer (or explicitly authorized continuation) before it can count as the
required migrated-state RED evidence.

## GREEN / diagnostics / script verification

Not run, because the required RED evidence contradicted the brief and implementation was stopped.
No Release staging, installation, launch, normal app bundle access, or owner-data access occurred.

## Scoped diff review

Compared against `/tmp/release-radar-sqlite23-pre.ZLUrQy`, this task added only the test described
above. The four pre-task snapshot files otherwise remain the comparison baseline; all unrelated
dirty working-tree changes were left intact. A final `git diff --check` and full suite are
intentionally pending the resolved brief and completed implementation.

## Required resolution

Planning/Architecture/QA need to reconcile whether the accepted RED condition is the real
callback's primary code `23` plus generic SQLite message, or whether `SQLiteConnection` must
preserve the more specific SQLite authorization message for diagnostics. They must also incorporate
the owner’s populated-legacy-fixture preservation requirement into the released task brief before
implementation resumes.

## Resumed implementation (amended brief accepted)

Status: **IMPLEMENTED — ready for independent review only.** No commits were created. The prior
message wording issue was resolved by the amended binding ruling: the real callback RED asserts
primary `SQLITE_AUTH` code `23`; the independent synthetic diagnostic remains the stable evidence
for the exact owner-visible message and authorizer tuple.

### Files and exact behavior changed

- `ReleaseRadarCore/Store/SQLiteConnection.swift`
  - The transaction callback authorizer now permits only `SQLITE_READ` references to
    `audit_events`; every other action referring to that protected table remains `SQLITE_DENY`.
    Transaction/savepoint controls still run first and remain denied.
  - Added fixed-field, privacy-bounded `OSLog` diagnostics for authorizer denials and
    prepare/step failures. The payload contains event/stage, primary/extended result, action
    code/name, the allowlisted `audit_events` / `project_id` identifiers when applicable, and
    transaction state. It never includes SQL, bindings, SQLite message text, actor/reason/thread,
    IDs, names, paths, bookmark data, or row data.
  - The in-memory diagnostic capture exists solely for deterministic test inspection and retains
    only the same bounded payload fields.
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
  - The real legacy callback regression now begins with a recognized version-9 compatibility
    database populated with an unrelated project, active phase relationship, ordinary ticket and
    child blocker, and a project-scoped store-owned audit row. It snapshots exact rows/counts and
    relationships, then proves they are unchanged after successful initialization except for the
    one new project/root/bookmark/pending marker/prepare-audit delta.
  - It also checks current version, foreign keys and `foreign_key_check`, no phase/command/
    notification side effects, repository sentinel/listing preservation, relaunch recovery, and
    balanced bookmark scope. The fresh schema case remains an existing secondary control.
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
  - Added direct callback `INSERT`/`UPDATE`/`DELETE` audit mutation regression coverage. Every
    case must return code `23`, roll back an ordinary sibling write, and emit no failed-transaction
    audit.
  - Added the indirect foreign-key `ON DELETE SET NULL` audit mutation regression, including an
    ordinary cascade child. It proves the parent, child, scoped audit `project_id`, audit count, and
    foreign-key integrity all remain unchanged after code `23`.
  - Added synthetic diagnostic allowlist/privacy assertions for both authorizer and prepare events.
- `script/build_and_run.sh`
  - All normal builds use Release and `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`.
  - Default/no-argument and `stage-release-no-launch` aliases build and verify a complete Release
    bundle before atomic promotion to `dist/ReleaseRadar.app`; the install aliases verify an
    existing staged bundle, copy it to an `/Applications` sibling, then atomically promote with
    backup/restore behavior.
  - It verifies strict/deep signing, authority/team, Hardened Runtime, exact main/bridge
    entitlement allowlists, embedded executables/frameworks, identifier/version/build, CDHash,
    executable hash, and signed resource-manifest identity. `pkill` and `open` are confined to
    explicit legacy launch modes.

### Retained populated RED evidence

The independent pre-source synthetic diagnostic remains unchanged and recorded the exact tuple:

```text
statement = onboarding projects upsert above
action = SQLITE_READ (20)
firstArgument = audit_events
secondArgument = project_id
prepare result = SQLITE_AUTH (23)
message = access to audit_events.project_id is prohibited
```

Its trigger-absent negative control prepared with `SQLITE_OK (0)` and executed with
`SQLITE_DONE (101)`. It used only disposable synthetic schema/values.

The revised, populated legacy-schema RED command was:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-populated-red-verified \
  -resultBundlePath /tmp/release-radar-sqlite23-populated-red-verified.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests/testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation
```

Result: one selected test failed as required before the authorizer correction. The retained result
bundle is `/tmp/release-radar-sqlite23-populated-red-verified.xcresult`; `xcresulttool` reports:

```text
SQLiteError(code: 23, message: "not authorized")
```

This is the real `FolderProjectOnboarding.prepare` legacy-trigger path. Its catch assertions
confirmed code `23` and the full populated unrelated-state snapshot before production code changed.
The generic wrapper message is intentionally not asserted as a stable contract; the standalone
diagnostic above supplies the exact message and `(SQLITE_READ, audit_events, project_id)` tuple.

### GREEN verification

Focused Debug command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-focused-green-pass \
  -resultBundlePath /tmp/release-radar-sqlite23-focused-green-pass.xcresult \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests
```

Result: **passed 51, failed 0, skipped 0**. The populated legacy regression, preservation delta,
direct/indirect rollback tests, and existing Onboarding/Store coverage all passed. Result bundle:
`/tmp/release-radar-sqlite23-focused-green-pass.xcresult`.

Full Debug command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-full-green \
  -resultBundlePath /tmp/release-radar-sqlite23-full-green.xcresult
```

Result: **passed 167, failed 0, skipped 0**. Result bundle:
`/tmp/release-radar-sqlite23-full-green.xcresult`.

### Diagnostic/logging verification

Release diagnostic command (the first plain Release attempt was blocked at test compilation because
that configuration disables `@testable`; this invocation preserves Release optimization while
temporarily enabling testability only for the test target):

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -configuration Release ENABLE_TESTABILITY=YES \
  -derivedDataPath /tmp/release-radar-sqlite23-release-diagnostics-testable \
  -resultBundlePath /tmp/release-radar-sqlite23-release-diagnostics-testable.xcresult \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testSQLiteDiagnosticsAllowlistAuthorizerAndPrepareFailureFields
```

Result: **passed 1, failed 0, skipped 0**. The test proves fixed authorizer/prepare fields,
primary result `23`, `SQLITE_UPDATE`, protected table/column and transaction state, while asserting
that supplied synthetic actor/reason/project/entity/name/SQL-string values are absent from the
captured diagnostics. Result bundle:
`/tmp/release-radar-sqlite23-release-diagnostics-testable.xcresult`.

### Script verification without staging, install, or launch

- Static/synthetic commands included:

```sh
bash -n script/build_and_run.sh
script/build_and_run.sh --invalid-mode
xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -configuration Release CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  -derivedDataPath /tmp/release-radar-sqlite23-script-release-no-base-entitlements
```

  The product verifier functions were then exercised against that disposable `/tmp` Release
  bundle only; no script mode that copies, promotes, installs, terminates, or launches was called.
- `bash -n script/build_and_run.sh` passed.
- An invalid-mode invocation returned usage with exit code 2 and no stdout, so no build/stage/install
  or launch branch ran.
- Static inspection found no Debug configuration/product path. It confirms the Release product path,
  no-base-entitlements setting, both nonlaunch aliases, strict signing/entitlements/Info.plist
  checks, and that `pkill`/`open` occur only in explicit launch helpers.
- A standalone nonlaunch Release build with the previous default signing behavior was intentionally
  rejected by the verifier because its main app had injected
  `com.apple.security.get-task-allow=true`. This was retained as fail-closed evidence.
- A fresh nonlaunch Release build with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` succeeded at
  `/tmp/release-radar-sqlite23-script-release-no-base-entitlements/Build/Products/Release/ReleaseRadar.app`.
  Its main app had exactly sandbox/application-group/user-selected-read-only/network-client;
  its Bridge Agent had exactly sandbox/application-group; `get-task-allow` was absent; and the
  script verifier passed strict/deep signatures, authority/team, Hardened Runtime, embedded-code,
  identifier, and manifest checks.

No `dist` bundle was created or modified, no `/Applications/ReleaseRadar.app` was read, modified,
or launched, no staging/install mode was invoked, and no owner database or Keychain was accessed.

### Scoped self-review

Compared directly with `/tmp/release-radar-sqlite23-pre.ZLUrQy`, only the four authorized files
changed after the snapshot:

```text
SQLiteConnection.swift:          218 insertions, 8 deletions
StoreAcceptanceTests.swift:      140 insertions
OnboardingAcceptanceTests.swift: 173 insertions
build_and_run.sh:                297 insertions, 18 deletions
```

`git diff --check` for the four owned files and `git diff --no-index --check` against each snapshot
file were clean. The broader working tree was already dirty in many unrelated paths; those changes,
including `docs/delivery/progress.md`, were not edited, staged, reverted, or otherwise absorbed.

### Concerns / limitations

- Engineering is ready only for the required independent Code/QA/Architecture/Security/TPM/Delivery
  reviews. This implementer did not stage/install a bundle and cannot mark the task Done, Accepted,
  or Ready for owner validation.
- The first plain Release test command remains non-runnable because the repository Release
  configuration disables `@testable` imports. The logged Release diagnostic GREEN used the narrow
  command-line `ENABLE_TESTABILITY=YES` test override; no project setting changed.
- The build system's normal Apple Development signing injects `get-task-allow`; the script now
  explicitly disables base-entitlements injection and independently rejects any extra entitlement.

## Fix round 1 — review findings corrected

Status: **IMPLEMENTED — ready for independent re-review only.** No commits, staging, installation,
or launch were performed.

### Required corrections made

1. **Authorizer callback containment.** `SQLiteConnection.swift` now captures the Boolean
   transaction state in a short-lived `SQLiteAuthorizerContext` before registering either
   authorizer. The callback reads that immutable context when emitting bounded diagnostics; it does
   not call `sqlite3_get_autocommit`, any other `sqlite3_*` API, or execute SQL. The context remains
   alive through the synchronous restricted body and is removed with the existing authorizer defer.
2. **Exact entitlement structure.** `build_and_run.sh` now canonicalizes and compares the complete
   entitlement plist against fixed approved main/Bridge structures. This enforces value types and
   permits exactly one application-group array value,
   `2UA854NLX4.com.rekonlabs.ReleaseRadar`; extra groups, `get-task-allow`, extra keys, and value or
   type mismatches fail.
3. **Fail-safe verification and promotion.** All verifier functions report then `return 1` rather
   than `exit`, and every consequential signing/metadata/identity result is explicitly checked.
   Promotion preserves a prior verified final bundle until strict verification and exact identity of
   the new final both pass. Any post-promotion failure quarantines the failed final out of its final
   path and restores the backup when present; restoration failure retains and reports both the failed
   and backup paths. A first promotion failure leaves no final path.
4. **Configured signer.** Signed code now requires both `TeamIdentifier=2UA854NLX4` and the exact
   leaf authority `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`.
5. **Populated legacy preservation.** The v9 fixture snapshot now includes `SELECT *` for the full
   seeded phase and audit rows, `projects.active_phase_id`, the phase relationship, ticket and child,
   and all relevant counts. Before/after equality proves every existing field and relationship is
   unchanged; only the required project and audit counts increase. Per the durable scope ruling,
   the one new prepare audit remains asserted by actor/reason/count only; no new project/entity
   association assertion was retained.

### RED evidence retained and fix-round adversarial starting evidence

The real populated version-9 legacy callback RED remains retained at
`/tmp/release-radar-sqlite23-populated-red-verified.xcresult`: one selected onboarding test failed
before the authorizer repair with primary `SQLITE_AUTH` code **23**, while the populated unrelated
fixture snapshot was preserved. The independent synthetic diagnostic retained in the preceding
section captures the owner-visible message and `(SQLITE_READ, audit_events, project_id)` tuple.

The independent review's disposable adversarial RED established that the prior script accepted an
extra application group and a wrong same-team authority, could allow strict verification to pass in
a conditional path, left a failed first promotion at final, and deleted the backup before the final
identity check. Those were the direct starting conditions for the fail-closed changes above; no
owner bundle, `dist`, or `/Applications` path was used.

### Fix-round GREEN commands and results

Populated migrated-schema regression:

```sh
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-fixround-onboarding-green \
  -resultBundlePath /tmp/release-radar-sqlite23-fixround-onboarding-green.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests/testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation \
  test
```

Result: **1 passed, 0 failed, 0 skipped**. The populated recognized-v9 path is green with full
phase/legacy-active-phase/audit preservation. Result:
`/tmp/release-radar-sqlite23-fixround-onboarding-green.xcresult`.

Focused Store + Onboarding suite:

```sh
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-fixround-focused \
  -resultBundlePath /tmp/release-radar-sqlite23-fixround-focused.xcresult \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests test
```

Result: **51 passed, 0 failed, 0 skipped**. Result:
`/tmp/release-radar-sqlite23-fixround-focused.xcresult`.

Full suite, run once after the focused suite was green:

```sh
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-fixround-full \
  -resultBundlePath /tmp/release-radar-sqlite23-fixround-full.xcresult test
```

Result: **167 passed, 0 failed, 0 skipped**. Result:
`/tmp/release-radar-sqlite23-fixround-full.xcresult`.

Release diagnostic:

```sh
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Release \
  ENABLE_TESTABILITY=YES \
  -derivedDataPath /tmp/release-radar-sqlite23-fixround-release-diagnostics \
  -resultBundlePath /tmp/release-radar-sqlite23-fixround-release-diagnostics.xcresult \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testSQLiteDiagnosticsAllowlistAuthorizerAndPrepareFailureFields \
  test
```

Result: **1 passed, 0 failed, 0 skipped**. The diagnostic regression continues to validate only
fixed/allowlisted fields, including code 23 and bounded authorizer data, while excluding supplied
synthetic identifier/reason/name/SQL values. Result:
`/tmp/release-radar-sqlite23-fixround-release-diagnostics.xcresult`.

### Release-script checks (no stage/install/launch)

```sh
bash -n script/build_and_run.sh
bash script/build_and_run.sh --invalid-mode
bash /tmp/release-radar-sqlite23-fixround-adversarial.sh
```

- Syntax check passed. Invalid mode returned **2**, emitted zero stdout bytes, and printed only
  usage to stderr.
- The disposable adversarial test at
  `/tmp/release-radar-sqlite23-fixround-adversarial.sh` passed (log:
  `/tmp/release-radar-sqlite23-fixround-adversarial-green.log`). It proved rejection of both extra
  main/Bridge app-group arrays, wrong same-team authority, and strict-verification failure. It also
  proved first-promotion failure clears final, failed replacement restores the prior final, identity
  failure rolls back before backup deletion, and an injected restoration failure preserves/reports
  failed and backup paths. All synthetic paths were under its unique `/tmp` directory.
- The updated verifier passed against the existing disposable nonlaunch Release product built with
  `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`:
  `/tmp/release-radar-sqlite23-script-release-no-base-entitlements/Build/Products/Release/ReleaseRadar.app`.
  Log: `/tmp/release-radar-sqlite23-fixround-nonlaunch-bundle-verifier.log`. This validates strict
  signatures, exact configured authority/team, Hardened Runtime, exact main/Bridge plist structures
  (including exactly one approved app group), and identity metadata. It did not call a script mode.

No command in this fix round accessed `dist` or `/Applications`, invoked a stage/install mode,
opened a normal bundle, accessed owner SQLite/Keychain data, or created a commit.

### Fix-round scoped self-review

Against `/tmp/release-radar-sqlite23-pre.ZLUrQy` (whose files are flat), only the four authorized
files differ; `git diff --no-index --check` was clean for each pair:

```text
SQLiteConnection.swift:          233 insertions, 10 deletions
StoreAcceptanceTests.swift:      140 insertions
OnboardingAcceptanceTests.swift: 183 insertions
build_and_run.sh:                439 insertions, 18 deletions
```

The repository remains broadly dirty in pre-existing, unrelated paths. They were not edited,
staged, reverted, cleaned, or attributed to this task; `docs/delivery/progress.md` was not edited.

### Concerns / limitations

- The script's stage/install branches remain intentionally unexecuted: this task was prohibited
  from staging or installing a Release bundle. Their fault handling was instead exercised through
  disposable `/tmp` fixtures.
- The repair remains at the independent-review gate. It is not Done, Accepted, packaged, installed,
  or owner-validated.

## Fix round 2 — QA blocker snapshot completeness

Status: **IMPLEMENTED — ready for independent re-review only.**

### Change

The only source change is in `ReleaseRadarTests/OnboardingAcceptanceTests.swift`:
`populatedLegacyFixtureSnapshot` now obtains the seeded blocker with
`SELECT * FROM blockers WHERE id = 'existing-blocker'`. This adds the version-9
`blockers.resolved_at` field to the existing field-for-field before/after preservation map, matching
the full-row phase and audit snapshots. No production or script code changed.

### Verification

Single populated legacy regression:

```sh
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-fixround2-onboarding \
  -resultBundlePath /tmp/release-radar-sqlite23-fixround2-onboarding.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests/testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation \
  test
```

Result: **1 passed, 0 failed, 0 skipped**. Result bundle:
`/tmp/release-radar-sqlite23-fixround2-onboarding.xcresult`.

Focused Store + Onboarding suite:

```sh
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-fixround2-focused \
  -resultBundlePath /tmp/release-radar-sqlite23-fixround2-focused.xcresult \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests test
```

Result: **51 passed, 0 failed, 0 skipped**. Result bundle:
`/tmp/release-radar-sqlite23-fixround2-focused.xcresult`.

The full suite and Release diagnostic were intentionally not repeated: this was a test-oracle-only
one-line query expansion, and both passed after the preceding production/script round.

### Scoped self-review

```sh
git diff --no-index --check \
  /tmp/release-radar-sqlite23-pre.ZLUrQy/OnboardingAcceptanceTests.swift \
  ReleaseRadarTests/OnboardingAcceptanceTests.swift
git diff --check -- ReleaseRadarTests/OnboardingAcceptanceTests.swift
```

Both checks were clean. The snapshot comparison remains one authorized test file (183 insertions
relative to the pre-task baseline); the fix-round delta is the blocker query narrowing above. No
stage/install/launch, owner-data, `/Applications`, `dist`, other-file, ledger, Git staging, or commit
action occurred.
