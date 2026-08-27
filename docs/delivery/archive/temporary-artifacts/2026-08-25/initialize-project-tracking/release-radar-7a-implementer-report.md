# Release Radar Task 7A Implementer Report

## Status

DONE. Implementation is ready for the controller's required fresh independent reviews. This report is implementation evidence, not an approval of my own work.

## Scope and preservation

- Changed only `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift` and `ReleaseRadarTests/OnboardingAcceptanceTests.swift`.
- Did not edit `SQLiteConnection.swift`, store migrations/schema, `RekonArtifactImporter.swift`, Attach behavior, the bridge, app/UI code, or `docs/delivery/progress.md`.
- Did not launch the owner bundle, inspect or mutate owner Application Support data, stage, commit, revert, or reformat unrelated work.
- The working tree was substantially dirty before Task 7A. All unrelated and earlier-task changes were preserved. The current repository diff for the two owned files includes earlier-task changes; Task 7A attribution is limited to the typed preparation error/catch and the three initialization acceptance tests plus their test-only helpers.

## SQLite error-23 hard reproduction gate

### Procedure

I temporarily added one isolated XCTest investigation, ran it, retained its xcresult, and then removed the diagnostic test because current source did not reproduce the reported error and the brief permits a retained SQLite regression only when reproduced.

Command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/release-radar-7a-investigation.Kjn2S9 \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests/testDiagnosticFourStatePrepareAuthorizationInvestigation
```

Result: 1/1 passed, zero failures. Result bundle:

`/tmp/release-radar-7a-investigation.Kjn2S9/Logs/Test/Test-ReleaseRadar-2026.08.25_13-05-00--0400.xcresult`

A second `test-without-building` execution also passed:

`/tmp/release-radar-7a-investigation.Kjn2S9/Logs/Test/Test-ReleaseRadar-2026.08.25_13-05-23--0400.xcresult`

Each case used a new `FolderFixture`, whose database is a temporary `release-radar.sqlite` and whose selected root is a disposable temporary `project` directory:

1. **Fresh**: no project rows; call `FolderProjectOnboarding.prepare`.
2. **Pending**: call `prepare` once to seed one pending project, then call `prepare` again.
3. **Pending with phase request**: seed with `prepare`, call `requestFirstPhaseDefinition`, then call `prepare` again.
4. **Pending with project-scoped audit**: seed with `prepare`, add one empty store-owned transaction with project audit scope, then call `prepare` again.

The diagnostic queried `(projects, onboarding_pending markers, onboarding_phase_request markers, project-scoped audits)` immediately before and after the target call. The state shapes were:

- Fresh: `(0,0,0,0)` before; target `prepare` succeeded and established `(1,1,0,0)`.
- Pending: `(1,1,0,0)` before; target `prepare` succeeded and preserved those state counts.
- Pending with phase request: `(1,1,1,0)` before; target `prepare` succeeded and preserved those state counts.
- Pending with project-scoped audit: `(1,1,0,1)` before; target `prepare` succeeded and preserved those state counts.

The exercised caller was `FolderProjectOnboarding.prepare(_:)` in `ProjectOnboarding.swift`. In its base store transaction the current SQL path was:

- `SELECT project_id FROM project_roots WHERE path = ?`
- `INSERT INTO projects ... ON CONFLICT(id) DO UPDATE ...`
- marker lookup `SELECT COUNT(*) FROM review_items WHERE id = ?`
- fresh state: pending-marker `INSERT INTO review_items ...`
- existing pending states: exact-marker `SELECT COUNT(*) ...` followed by `UPDATE review_items SET status = 'open' WHERE id = ?`
- `INSERT INTO project_roots ... ON CONFLICT(path) DO NOTHING`
- `INSERT INTO project_bookmarks ... ON CONFLICT(project_id, path) DO UPDATE ...`
- DeliveryStore's store-owned prepare audit insertion after the restricted callback returns.

### Reproduction conclusion

SQLite error 23 (`SQLITE_AUTH`) did **not** occur in any state. Consequently there is no failing statement, primary/extended result code, or denied authorizer action/arguments to report. No authorizer or callback policy was changed, and no caller correction was made. The protected `audit_events` policy remains intact. I make no bundle-mismatch claim; bundle provenance was not separately established. The owner bundle and owner data were not used.

## TDD RED

Before production changes, I added focused tests for these production breaks:

- base initialization loses its atomic project/root/bookmark/pending marker/prepare-audit contract;
- initialization creates a phase request, phase, bridge request, notification, or repository file side effect;
- persisted pending identity or folder authorization does not survive a new store/onboarding instance;
- a recognized artifact changes after preview and the post-base failure escapes as a raw importer error instead of typed saved-incomplete state;
- recognized-seed failure leaves partial imported rows or an importer audit;
- bookmark creation fails before the base commit but any database or repository state changes.

RED command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/release-radar-7a-red.kYDHnt \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests
```

After correcting test-only compile issues, the retained RED failed for the intended missing production contract only:

```text
OnboardingAcceptanceTests.swift:95:30: error: cannot find type 'OnboardingPreparationError' in scope
** TEST FAILED **
```

RED result bundle:

`/tmp/release-radar-7a-red.kYDHnt/Logs/Test/Test-ReleaseRadar-2026.08.25_13-07-38--0400.xcresult`

## Minimum implementation

- Added public, `Equatable`, `Sendable`, localized `OnboardingPreparationError.seedApplicationFailedAfterSave(ProjectID)`.
- Kept `FolderProjectOnboarding.prepare(_:) async throws -> ProjectID` source-compatible.
- Wrapped only the post-base `RekonArtifactImporter.apply(importPreview, to:)` call in `do/catch`.
- Any failure from that apply boundary is now converted to the typed saved-incomplete state carrying the already-persisted project identity.
- The bookmark creation and base project/root/bookmark/exclusion/pending transaction are unchanged, including rollback and the single prepare audit.
- No automatic phase request, command, notification, repository write, policy relaxation, schema change, or importer-scope change was added.

## GREEN and verification

### All OnboardingAcceptanceTests in fresh DerivedData

Final command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/release-radar-7a-final.nygXl0 \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests
```

Result: **23/23 passed**, zero failures, zero skips. Result bundle:

`/tmp/release-radar-7a-final.nygXl0/Logs/Test/Test-ReleaseRadar-2026.08.25_13-09-03--0400.xcresult`

This run included the existing Attach persistence/rollback regressions:

- `testAttachFolderPreservesExistingProjectGraphAndAddsOnlyAuthorization`
- `testAttachFolderOwnedSymlinkConflictRollsBackPopulatedGraph`
- `testAttachFolderRejectsRootOnlyBookmarkOnlyAndPairedAuthorizationWithoutRepair`

All three passed as part of the 23-test suite.

### Store authorizer negative control

Command against the final fresh build:

```sh
xcodebuild test-without-building -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/release-radar-7a-final.nygXl0 \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests/testCallbackCannotMutateAuditEvents
```

Result: **1/1 passed**, zero failures, zero skips. Result bundle:

`/tmp/release-radar-7a-final.nygXl0/Logs/Test/Test-ReleaseRadar-2026.08.25_13-09-28--0400.xcresult`

This is the existing negative control proving transaction callbacks still cannot mutate `audit_events`.

### Diff hygiene

Command:

```sh
git diff --check -- ReleaseRadarCore/Onboarding/ProjectOnboarding.swift ReleaseRadarTests/OnboardingAcceptanceTests.swift
```

Result: exit 0, no output.

## Row, audit, and side-effect evidence

### Successful initialization delta

The new base-state test proves:

- projects `+1`
- selected project roots `+1`
- non-stale bookmarks `+1`, with the expected persisted bookmark bytes
- open `onboarding_pending` marker `+1`
- `Prepare folder-backed project onboarding` audit `+1`
- `onboarding_phase_request` markers `+0`
- phases `+0`
- agent command requests `+0`
- notification events `+0`
- notification occurrences `+0`
- `Request agent-defined first phase` audits `+0`

### Recognized-seed revalidation failure after base commit

The test previews a valid recognized artifact, changes its phase label on disk after preview, then opts into import. `RekonArtifactImporter.apply` revalidates current source and fails before its import transaction. The observed typed result is `seedApplicationFailedAfterSave(savedProjectID)`.

Persisted base delta remains:

- project/root/non-stale bookmark/open pending marker: `+1` each
- prepare audit: `+1`

Import and automatic-action deltas remain zero:

- non-pending review rows: `+0`
- phases and active-phase rows: `+0`
- tickets: `+0`
- phase dependencies: `+0`
- ticket dependencies: `+0`
- evidence: `+0`
- agent command requests: `+0`
- notification events and occurrences: `+0`
- `Import recognized Rekon delivery records` audits: `+0`

### Pre-commit failure

A test-only bookmark store throws `bookmarkCreationFailed` before the base transaction. Complete snapshots of every existing app table before and after are equal, including projects, roots, bookmarks, onboarding markers, delivery graph, audits, notifications, requests, and alert rules. All database and audit deltas are `+0`.

## Repository sentinel and listing evidence

Both the successful base initialization test and pre-commit bookmark failure test create `owner-sentinel.txt` in the disposable project root, capture its bytes and the complete recursive relative-path listing before the operation, and compare both afterward. Sentinel bytes and listings are identical. No repository file or directory is created, removed, or changed by initialization.

## Relaunch and bookmark evidence

For successful initialization and saved-incomplete seed failure, each test creates a new `DeliveryStore` and new `FolderProjectOnboarding` against the same temporary database. `inspect(folder:)` returns the same persisted `pendingProjectID`. `withAuthorizedProject(projectID:)` resolves the stored non-stale bookmark and returns the canonical selected root. Test security-scope start/stop counts remain balanced.

## Files changed for Task 7A

- `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
  - typed saved-incomplete preparation error
  - narrow catch around recognized seed apply only
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
  - base initialization/no-automatic-action/sentinel/relaunch acceptance
  - recognized-seed saved-incomplete and zero-partial-import acceptance
  - pre-commit rollback/sentinel acceptance
  - test-only changed-artifact and rejecting-bookmark fixtures

## Self-review and concerns

- Mutation check: removing the catch or throwing the original importer error fails the typed outcome test; moving base writes before bookmark creation fails the pre-commit snapshot; adding phase/request/notification/import side effects fails explicit zero-count assertions; losing bookmark persistence or pending identity fails the new-store relaunch checks; touching repository contents fails sentinel/listing checks.
- The implementation changes one behavior at one boundary and preserves `prepare`'s public return signature.
- No SQLite regression was retained because the required isolated investigation did not reproduce SQLite 23.
- The typed error intentionally carries the durable project identity, not the underlying importer error, matching the exact brief. Broader diagnostic payloads would expand the requested contract.
- No Task 7A implementation concern remains. Fresh independent Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery acceptance remain the controller's next gate; I did not perform or claim those approvals.
