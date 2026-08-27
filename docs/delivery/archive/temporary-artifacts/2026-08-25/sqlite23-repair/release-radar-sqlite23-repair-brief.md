# Initialize Project Tracking SQLite-23 Repair Brief

**Planning status:** Ready for independent Architecture, QA/test, Security/Privacy, TPM, and Delivery review. This brief is not an implementation approval and its author must not implement or approve it.

## Objective and user-visible outcome

Repair the real **Initialize Project Tracking** failure shown by the owner. On the signed sandboxed app's existing local database, pressing **Initialize Project Tracking** must save the same resumable pending project, folder root, bookmark, onboarding marker, and one store-owned prepare audit that the accepted Task 7A/7B workflow specifies. It must no longer display `SQLite error 23: access to audit_events.project_id is prohibited`.

After engineering code/test/script review closes every Required finding and Delivery authorizes packaging, produce a signed **Release** bundle at the durable repository path:

`/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app`

Then, and only then, install that exact verified bundle at:

`/Applications/ReleaseRadar.app`

Automated build, signing, staging, and installation verification must not launch the app or access owner project data. Installation moves the task only to **Ready for owner validation**. The task must not be marked Done or Accepted until the owner launches `/Applications/ReleaseRadar.app`, exercises Initialize Project Tracking, and explicitly approves the result.

## Controlling references

- Owner screenshot and request in the current conversation, including the exact SQLite-23 message and selected Release Radar repository folder.
- `AGENTS.md`, especially the execution gates, app-only SQLite authority, test-first rule, security/privacy review, progress-ledger requirements, and Release verification standard.
- `docs/delivery/progress.md`, “Initialize Project Tracking — owner decision and implementation-plan gate,” including accepted Task 7A/7B behavior and the previously unresolved SQLite-23 non-reproduction.
- `docs/superpowers/plans/2026-08-25-release-radar-remediation.md`, Task 7A and Task 7B.
- `docs/architecture/ADR-001-release-radar-boundaries.md`: signed/sandboxed app, app-owned Application Support database, app process as sole SQLite writer, transactional/audited mutations, and unchanged signing/entitlement boundaries.
- `docs/design/agent-driven-delivery-dashboard-design.md` and the accepted Task 7B UI/copy contract. No visual redesign is authorized.
- Current source in `ProjectOnboarding.swift`, `DeliveryStore.swift`, `SQLiteConnection.swift`, and `StoreMigrations.swift`; current acceptance coverage in `StoreAcceptanceTests.swift` and `OnboardingAcceptanceTests.swift`.

## Confirmed root cause and required evidence

### Evidence gathered by Planning

The prior Task 7A fresh-schema four-state diagnostic did not represent the database shape used by the signed sandboxed app.

Read-only metadata inspection of the sandbox container database established:

- `PRAGMA user_version = 9`.
- The target derived project identity has no project/root/bookmark/pending-marker rows, so this is the first initialization attempt for that folder.
- `audit_events` contains existing history and has `project_id TEXT REFERENCES projects(id) ON DELETE SET NULL`.
- The recognized version-9 schema retains the legacy `projects.active_phase_id` column, `projects_active_phase_index`, and `validate_project_active_phase_insert` / `validate_project_active_phase_update` triggers while also using `project_active_phases`.

On a disposable copy of that sandbox database, the current `FolderProjectOnboarding.prepare` project statement:

```sql
INSERT INTO projects (id, name, first_dashboard_opened)
VALUES (?, ?, 0)
ON CONFLICT(id) DO UPDATE SET name = excluded.name
```

was executed through the current transaction-callback authorizer. SQLite invoked this authorizer tuple while preparing the statement:

```text
action = SQLITE_READ (20)
firstArgument = audit_events
secondArgument = project_id
```

The current blanket `audit_events` rule returned `SQLITE_DENY`, and `sqlite3_prepare_v2` returned `SQLITE_AUTH` (23) with the owner's exact message. Dropping only the two retained legacy active-phase triggers on another disposable copy made the same statement prepare and execute successfully; dropping the legacy index alone did not. A fresh current schema also succeeds. No owner database was modified.

### Root-cause conclusion

The callback authorizer conflates a SQLite-generated **read** of the protected audit foreign-key column with a caller-authored audit mutation. The retained, recognized legacy trigger shape makes SQLite compile the parent-project upsert's foreign-key path and read `audit_events.project_id`. That read is needed to enforce relational integrity, but the blanket table-name denial rejects it before the onboarding transaction can write the project.

The minimum compatible correction is action-sensitive authorization: allow `SQLITE_READ` of `audit_events` during a transaction callback, while continuing to deny every callback-authored or SQLite-induced mutation of `audit_events`. The app-owned audit insert remains outside the restricted callback and remains the only writer.

Do not drop legacy columns, triggers, indexes, audit rows, or owner data as part of this repair. Do not add a schema migration. If the RED fixture contradicts the evidence above or an independent Architecture/Security review finds that action-sensitive authorization cannot preserve the boundary, stop and return to planning; do not improvise a migration or delete owner schema objects.

## Explicit scope

### In scope

- Add a disposable version-9 legacy-active-phase-schema fixture that deterministically reproduces the exact production statement and `SQLITE_AUTH` failure without copying owner data.
- Change the transaction callback authorizer's classification of protected-table **reads** versus mutations.
- Add durable, sanitized unified logging for SQLite transaction/authorizer failures so an installed-app failure identifies the fixed stage, result codes, authorizer action, and allowlisted protected schema identifiers without exposing owner data or SQL.
- Prove direct and foreign-key-induced `audit_events` mutations still fail closed and roll back the whole transaction.
- Prove the real `FolderProjectOnboarding.prepare` callback succeeds on the fixture and preserves Task 7A/7B persistence, repository no-write, audit, relaunch, and no-automatic-action contracts.
- Update `script/build_and_run.sh` so every normal build uses `Release`, atomically stages a complete verified bundle at `dist/ReleaseRadar.app`, and supplies a nonlaunch staging mode plus a post-gate nonlaunch install-existing-staged mode.
- After all independent engineering gates pass, install the exact staged Release bundle at `/Applications/ReleaseRadar.app`, verify exact-bundle identity, and hand it to the owner for validation.
- Update only `docs/delivery/progress.md` as the durable ledger.

### Out of scope

- UI redesign, copy changes, Attach changes, portable import/export, Help, Codex automation, notification behavior, bridge/observer behavior, or additional product work.
- Changes to `FolderProjectOnboarding.prepare`, `DeliveryStore.transact`, schema version, `StoreMigrations`, foreign keys, legacy owner schema objects, or audit contents unless new RED evidence invalidates this plan and the independent roles approve a replacement brief.
- Weakening transaction ownership, callback lease/thread checks, transaction/savepoint denial, read-callback restrictions, rollback behavior, or app-only SQLite authority.
- Allowing callback `INSERT`, `UPDATE`, `DELETE`, DDL, trigger, index, reindex, attach/detach, or foreign-key cascade/set-null mutation of `audit_events`.
- Resetting, deleting, moving, replacing, or manually editing the owner's SQLite database or container.
- Debug as the delivered artifact; DerivedData or `/tmp` as the handoff location; notarization or Developer ID distribution; automatic app launch; automatic owner approval.
- Staging, committing, reverting, formatting, or absorbing unrelated dirty working-tree changes.

## Dependency and release gate

1. Independent Architecture, QA/test, Security/Privacy, TPM, and Delivery roles review this brief. Every Required finding must be resolved and the ledger must record all five GO decisions.
2. Delivery releases one fresh Implementer as the sole writer for this bounded repair. No concurrent writer may touch the store, onboarding tests, build script, or progress ledger.
3. The Implementer records the exact RED before changing production code, implements the approved correction and durable diagnostics, and produces focused and full GREEN evidence.
4. Separate Code Review, QA/test, Architecture, Security/Privacy, TPM, and Delivery roles independently review the code, tests, diagnostic contract, and build/install script. The Implementer cannot fill any of those roles.
5. When those engineering reviews have zero open Required findings, Delivery authorizes the nonlaunch Release stage and install.
6. QA and Security/Privacy then independently verify the actual `dist` and `/Applications` bundles, strict signing, fail-closed entitlements, exact-bundle identity, durable paths, and no-launch evidence. Delivery records those artifact-verification decisions.
7. Ledger status becomes **Ready for owner validation**, not Done/Accepted.
8. Only a later explicit owner approval after the owner launches the installed app and tests Initialize Project Tracking authorizes the final ledger transition to Done/Accepted.

## Anticipated files and ownership

- Modify: `ReleaseRadarCore/Store/SQLiteConnection.swift` — action-sensitive transaction authorizer correction plus fixed-field sanitized unified diagnostics.
- Modify: `ReleaseRadarTests/StoreAcceptanceTests.swift` — protected audit mutation matrix and indirect foreign-key mutation rollback regression.
- Modify: `ReleaseRadarTests/OnboardingAcceptanceTests.swift` — disposable recognized legacy-schema fixture and real onboarding callback regression.
- Modify: `script/build_and_run.sh` — Release-by-default build, atomic `dist` staging, nonlaunch verification/install modes, exact identity checks.
- Modify after evidence/reviews: `docs/delivery/progress.md` — durable gates and evidence only.
- Read/verify, do not modify absent contradictory evidence: `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`, `ReleaseRadarCore/Store/DeliveryStore.swift`, `ReleaseRadarCore/Store/StoreMigrations.swift`, `ReleaseRadar.xcodeproj/project.pbxproj`, `ReleaseRadar/ReleaseRadar.entitlements`, and `ReleaseRadar/Info.plist`.

Because these files already coexist with unrelated uncommitted work, the Implementer must capture pre-task file snapshots/diffs, make targeted hunks only, and use a scoped review package. Do not stage or claim pre-existing changes.

## Persistence, security, and privacy contract

- `DeliveryStore` remains the sole database transaction owner. It begins, audits, commits, and rolls back; callback code cannot commit, roll back, or create savepoints.
- A transaction callback may read `audit_events`, matching the already available read-only store surface, but may not mutate it directly or indirectly.
- Protected-table authorization must be based on SQLite action class. `SQLITE_READ` for `audit_events` is allowed. Any other action that names `audit_events` remains denied.
- The store-owned `INSERT INTO audit_events` continues to run only after the callback restriction is removed and before commit. One successful initialization produces exactly one prepare audit.
- If callback work or the store-owned audit insert fails, all project/root/bookmark/marker changes roll back together.
- The foreign key `audit_events.project_id -> projects.id ON DELETE SET NULL` stays enabled. A callback attempting to delete or alter a referenced project must fail when SQLite requests the resulting `audit_events` update; project and audit history remain unchanged.
- Installed-app diagnostics use a fixed event/stage identifier and may include only primary/extended SQLite result codes, authorizer action code/name, allowlisted protected schema identifiers (`audit_events`, `project_id`), schema version, and transaction-state booleans. They must never log SQL text, bindings, arbitrary SQLite/trigger messages, actor/reason/thread IDs, project names/IDs/paths, repository content, bookmark bytes, prompts, credentials, or row data.
- The test fixture contains synthetic IDs, paths, bookmarks, and audit rows only. Do not copy the owner database into the repository, tests, result bundle attachments, or durable evidence.
- No repository file content, bookmark bytes, project path, credential, prompt, or owner database row may be logged by the app or packaging script.
- App Sandbox, Hardened Runtime, Apple Development signing, bundle identifier `com.rekonlabs.ReleaseRadar`, team identifier, and entitlements remain unchanged.

## Test-first implementation sequence

### 1. First evidence: sanitized statement/authorizer diagnostic

Before editing repository files, independently rerun one targeted diagnostic
against an in-memory or disposable **synthetic** SQLite database. Create only
the current `projects` / `audit_events` foreign-key relationship plus the
legacy `active_phase_id` column and the two active-phase validation triggers
shown below. Use synthetic identifiers and no owner database, path, bookmark,
or row data. Apply the current transaction-callback authorizer policy, then
prepare the exact production statement with bound fixture values:

```sql
INSERT INTO projects (id, name, first_dashboard_opened)
VALUES (?, ?, 0)
ON CONFLICT(id) DO UPDATE SET name = excluded.name
```

Retain sanitized output proving:

```text
statement = onboarding projects upsert above
action = SQLITE_READ (20)
firstArgument = audit_events
secondArgument = project_id
prepare result = SQLITE_AUTH (23)
message = access to audit_events.project_id is prohibited
```

Run one negative control with the legacy triggers absent; the same statement
must prepare and execute. This step is diagnostic evidence only: it must not
change repository source, the owner database, or the proposed policy. If the
synthetic result differs, stop and return to Planning before writing tests or
production code.

### 2. RED: real onboarding callback / foreign-key compatibility path

In `OnboardingAcceptanceTests`, create a synthetic database using the current `DeliveryStore` and populate it with representative unrelated durable state before closing it: at minimum one existing unrelated project, its active phase/phase relationship, an ordinary ticket or equivalent project child, and one project-scoped store-owned audit row. Capture the exact existing row values, relationships, and relevant counts. Then close the store and use the existing test-visible `SQLiteConnection` to recreate only the recognized legacy project compatibility shape:

```sql
ALTER TABLE projects ADD COLUMN active_phase_id TEXT;
CREATE INDEX projects_active_phase_index ON projects(active_phase_id);
CREATE TRIGGER validate_project_active_phase_insert
BEFORE INSERT ON projects
WHEN NEW.active_phase_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM phases
    WHERE phases.id = NEW.active_phase_id AND phases.project_id = NEW.id
)
BEGIN
    SELECT RAISE(ABORT, 'active phase must belong to project');
END;
CREATE TRIGGER validate_project_active_phase_update
BEFORE UPDATE OF id, active_phase_id ON projects
WHEN NEW.active_phase_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM phases
    WHERE phases.id = NEW.active_phase_id AND phases.project_id = NEW.id
)
BEGIN
    SELECT RAISE(ABORT, 'active phase must belong to project');
END;
```

Reopen `DeliveryStore`, verify it is available/current version 9, then run the actual production path:

```swift
let preview = try await onboarding.inspect(folder: fixture.root)
let projectID = try await onboarding.prepare(
    .init(preview: preview, projectName: "Fixture Project")
)
```

Name the test to identify the break, for example:

`testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation`

Assert the same contracts as the accepted Task 7A test for the newly initialized project: one new project, one root, one current bookmark, one open pending marker, one prepare audit, zero phase request/audit, zero new phases, zero command requests, zero notification events/occurrences, unchanged repository sentinel/listing, balanced bookmark scope, and pending identity/root authorization after a new store/onboarding instance. Also assert the complete pre-existing populated snapshot is unchanged field-for-field and relationship-for-relationship; the only database delta is the exact new onboarding state and its one prepare audit. Before production code changes, the real callback test must fail at the project upsert with primary code `SQLITE_AUTH` (23). SQLite's human-readable `sqlite3_errmsg` wording is platform/path dependent: retain the separately captured authorizer tuple `(SQLITE_READ, audit_events, project_id)` and standalone synthetic exact message `access to audit_events.project_id is prohibited` as the stable root-cause evidence, but do not require the higher-level XCTest wrapper to repeat that exact string when it reports the generic `not authorized`. Retain the `.xcresult` as RED evidence. A fresh empty/current-schema case is a secondary control and is not sufficient replacement evidence.

### 3. RED/security controls: audit mutation remains prohibited

In `StoreAcceptanceTests`:

- Retain the existing `testCallbackCannotMutateAuditEvents` regression.
- Add a compact direct mutation matrix for callback `INSERT`, `UPDATE`, and `DELETE` against `audit_events`; each attempt must throw `SQLITE_AUTH`, roll back an ordinary sibling mutation, and add no store-owned audit for the failed transaction.
- Add an indirect mutation regression: seed a project with a project-scoped store-owned audit, then attempt to delete that project inside a callback. SQLite may read `audit_events.project_id`, but its `ON DELETE SET NULL` update must be denied. Assert the project, scoped audit row, original `project_id`, and total audit count are unchanged.
- The indirect mutation fixture must also seed at least one ordinary project child using an existing `ON DELETE CASCADE` relationship. After the denied parent delete, assert that child remains unchanged and `PRAGMA foreign_key_check` is empty, in addition to the unchanged project and audit row.
- Retain transaction/savepoint and expired/cross-context callback protections.

The tests must distinguish allowed audit **read** from forbidden audit **mutation**; a generic “some error occurred” assertion is insufficient for the new security controls.

### 4. Implement the authorizer correction and durable diagnostics

In `deliveryStoreTransactionAuthorizer`, keep transaction-control authorization first. When the protected table is `audit_events`, return `SQLITE_OK` only for `SQLITE_READ`; return `SQLITE_DENY` for every other action that references that table. Leave read-callback authorization, connection leases, `DeliveryStore.transact`, store-owned audit insertion, foreign keys, migrations, and onboarding SQL unchanged.

At the SQLite boundary, emit one unified-log event for authorizer denials and one for prepare/step failures using only the allowlisted fixed fields above. Add synthetic tests that trigger the exact denial and failure path and prove the diagnostic payload contains the required fixed fields and none of the supplied prohibited fixture values. Run that diagnostic verification in Release configuration as well as the ordinary Debug-focused suite; do not launch the installed owner app to collect it.

### 5. GREEN and integration verification

Run in fresh non-owner DerivedData locations:

```bash
xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-focused \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests

xcodebuild test \
  -project ReleaseRadar.xcodeproj \
  -scheme ReleaseRadar \
  -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-full
```

Required GREEN evidence:

- The new legacy-schema onboarding test passes and the exact persisted/audit/no-write/relaunch assertions hold.
- All `StoreAcceptanceTests` and `OnboardingAcceptanceTests` pass with no skips.
- The full suite passes with no new failures.
- Existing Task 7A saved-incomplete/rollback tests and all Attach persistence/rollback regressions pass.
- `PRAGMA foreign_keys = 1` and `PRAGMA foreign_key_check` is empty for the fixture after success.
- `git diff --check` is clean for the owned files.

Do not run the app against the owner's container database during implementation or automated QA.

## Happy path and non-happy paths

### Happy path

On either fresh current schema or recognized version-9 legacy compatibility schema, Initialize preview remains read-only; confirmation runs the existing atomic base transaction; the SQLite FK read is allowed; exactly one store-owned prepare audit is appended; the pending project resumes after relaunch; the repository is unchanged; and the existing Codex handoff appears.

### Non-happy paths

- Invalid name, bookmark creation/resolution failure before transaction, root ownership conflict, marker conflict, or any callback SQL failure leaves project/root/bookmark/marker/audit state unchanged as already specified.
- Recognized-seed failure after the base commit remains the typed saved-incomplete outcome from Task 7A, with no partial import.
- Direct callback audit insert/update/delete fails with code 23 and rolls back sibling work.
- Indirect audit update caused by parent delete/update fails with code 23 and preserves project plus audit history.
- Store-owned audit insertion failure rolls back callback work.
- Unsupported/corrupt schema remains unavailable/recoverable under existing migration behavior; this task does not coerce it.
- Release build, stage, signing, identity, or installation failure stops before owner validation and preserves the last verified `dist` or installed bundle through the script's staging/rollback behavior.

## Activity and audit evidence

- Successful Initialize: exactly one audit with actor `release-radar-onboarding` and reason `Prepare folder-backed project onboarding`; no phase-request, import, notification, or command-request audit/side effect unless the already explicit later action occurs. This repair preserves the existing prepare-audit association contract and does not add project/entity scope to `FolderProjectOnboarding.prepare`.
- Failed callback or denied direct/indirect audit mutation: no audit for the failed transaction and no partial state.
- Packaging/install operations do not write application audit events and do not launch the app.
- The progress ledger records test/build/sign/install evidence and the owner-validation gate; it must not contain copied owner rows, bookmark data, credentials, or misleading claims of live validation.

## Release build, atomic staging, signing, and installation acceptance

Update `script/build_and_run.sh` proportionally:

- Use `-configuration Release` and `Build/Products/Release/ReleaseRadar.app` for every normal mode. No Debug bundle may be staged or handed off.
- Build intermediates may remain in DerivedData, but the durable deliverable is always `dist/ReleaseRadar.app`.
- Copy the complete built bundle to a uniquely named temporary sibling under `dist`, verify it there, and only then rename it into `dist/ReleaseRadar.app`. Never copy in place to the final path. If a prior verified `dist` bundle exists, move it to a backup and restore it on any staging failure; remove the backup only after the final bundle verifies.
- Preserve existing explicit run/debug/log/telemetry capabilities, but add a clearly named **nonlaunch** staging/verification mode used by automated acceptance. Move `pkill` and `/usr/bin/open` behind explicit launch modes so nonlaunch verification neither terminates nor starts the owner's app.
- Add a post-gate **install existing staged bundle** mode. It must not rebuild or launch. It verifies `dist/ReleaseRadar.app`, copies it to a temporary sibling under `/Applications`, verifies that temporary copy, then transactionally replaces `/Applications/ReleaseRadar.app` with rollback to the previous installed bundle on failure.
- Avoid `ditto` merging into an existing final bundle; final names receive only already-complete verified temporary bundles.

For both `dist/ReleaseRadar.app` and `/Applications/ReleaseRadar.app`, require:

```bash
codesign --verify --deep --strict --verbose=2 <bundle>
codesign -dvvv --entitlements :- <bundle>
plutil -extract CFBundleIdentifier raw <bundle>/Contents/Info.plist
```

Acceptance values:

- Configuration/product location proves Release, not Debug.
- `CFBundleIdentifier = com.rekonlabs.ReleaseRadar`.
- Signature authority/team match the configured Apple Development identity/team.
- Verification must parse metadata and fail closed rather than merely print it. The main app must have Hardened Runtime plus the approved App Sandbox, application group, user-selected read-only, and network-client entitlement values. The embedded `ReleaseRadarBridgeAgent` must have Hardened Runtime, App Sandbox, and the approved application group. Every embedded signed executable and framework must have the expected Apple Development authority/team and independently pass strict signature verification.
- The staged and installed bundles have the same CodeDirectory `CDHash`, identifier, version/build, main-executable SHA-256, and byte-identical signed resource manifest. Both independently pass strict/deep verification.
- `dist/ReleaseRadar.app` remains present after installation.
- No `open`, executable launch, process assertion, or owner database access occurs in build/sign/install verification.

Apple Development signing is sufficient for this owner-local handoff under the accepted ADR. Do not claim Developer ID distribution, notarization, or general Gatekeeper readiness.

## Acceptance criteria

Engineering may reach **Ready for owner validation** only when all of the following are true:

1. The populated synthetic recognized-legacy-schema RED fails through the real `FolderProjectOnboarding.prepare` callback with primary code `SQLITE_AUTH` (23), while the standalone diagnostic independently records the exact owner-visible message and authorizer tuple. It passes after the fix and proves all pre-existing unrelated project, phase/child, and scoped-audit data remains unchanged.
2. Fresh-schema initialization remains a secondary control; both fresh and populated legacy-schema initialization persist the accepted Task 7A/7B base state, one prepare audit, no automatic action, unchanged repository, and relaunch recovery.
3. Callback audit reads required by SQLite foreign-key enforcement work; all direct and indirect callback audit mutations remain denied and atomic rollback is proven.
4. Focused and full tests pass with no skips or new failures, and the scoped diff contains no migration, database reset, UI, Attach, bridge, notification, or unrelated change.
5. Independent Code, QA, Architecture, Security/Privacy, TPM, and Delivery engineering reviews have zero open Required findings, after which Delivery explicitly authorizes packaging/install.
6. The signed Release bundle is atomically staged at `dist/ReleaseRadar.app`, strict signing/entitlement/identity checks pass, and the exact same verified bundle is installed without launch at `/Applications/ReleaseRadar.app`.
7. Independent QA and Security/Privacy verify both actual bundles and Delivery records their artifact-verification decisions.
8. The ledger says **Ready for owner validation** and explicitly records that owner runtime validation is pending.

Final Done/Accepted requires a separate final condition: the owner personally launches `/Applications/ReleaseRadar.app`, tests Initialize Project Tracking against the intended workflow, and explicitly approves. Until that message exists, no agent may claim the app is done, accepted, working for the owner, or release-complete.

## Required independent post-reviews

- **Code Reviewer:** specification compliance, narrow authorizer action logic, exact failing callback fixture, rollback tests, script atomicity, and unrelated-diff exclusion.
- **QA/test:** first independently rerun focused/full tests, verify RED provenance, and inspect row/audit/cascade deltas, relaunch, repository sentinel, failure matrix, and sanitized diagnostic behavior; after Delivery authorizes packaging, independently verify both actual Release artifact paths and no-launch evidence.
- **Architect:** confirm allowing protected-table reads while denying all mutations preserves ADR-001 and that no migration/ADR change is needed.
- **Security/Privacy:** first verify direct and indirect audit-write denial, cascade rollback, callback/transaction containment, diagnostic allowlisting, and no owner-data fixture; after Delivery authorizes packaging, independently verify fail-closed sandbox/hardened-runtime/entitlement/signing assertions, atomic install, and exact bundle identity for both actual bundles.
- **TPM:** confirm scope/sequencing, Required findings closure, and owner validation as the terminal gate.
- **Delivery Manager:** record the engineering reviews, explicitly release packaging/install, then record the separate QA/Security artifact-verification decisions before setting **Ready for owner validation**; keep later work closed.

## Required progress-ledger evidence

Record in `docs/delivery/progress.md` without creating a competing ledger:

- Owner-reported failure and screenshot message; status reopened from the prior Task 7A/7B closeout.
- Planning evidence: sandbox version/recognized legacy object shape, exact onboarding SQL, authorizer tuple `(SQLITE_READ, audit_events, project_id)`, exact code-23 failure, and trigger-isolation result. State clearly that diagnostics used disposable copies and did not modify owner data.
- Independent preimplementation Architecture/QA/Security/TPM/Delivery decisions and Required findings/dispositions.
- Fresh sole Implementer attribution, scoped files, pre-existing dirty-worktree preservation, and RED `.xcresult` path.
- Exact production change and security boundary; explicit confirmation that `DeliveryStore`, onboarding SQL, schema/migrations, owner database, and unrelated work were unchanged.
- Focused/full commands, counts, failures/skips, `.xcresult` paths, foreign-key checks, row/audit deltas, sentinel/listing, relaunch, and `git diff --check` evidence.
- Independent postimplementation Code/QA/Architecture/Security/TPM/Delivery decisions, Required/Optional/Out-of-scope classification, and ADR disposition.
- Nonlaunch Release command, built Release source path, durable `dist/ReleaseRadar.app` path, strict codesign output, identity/team/entitlements, CDHash/version/executable/resource-manifest identity, installation command/path, rollback result, and evidence that no app launch occurred.
- Status **Ready for owner validation**, with `/Applications/ReleaseRadar.app` handed to the owner and explicit runtime approval still pending.
- Only after a later explicit owner approval: date/statement, tested workflow/result, final Accepted/Done transition, remaining risks, and next eligible task.

## Unresolved questions / blockers for independent review

There is no remaining technical reproduction blocker. The following are approval questions, not permission for the Implementer to choose silently:

1. Architecture and Security must explicitly confirm that transaction-callback reads of `audit_events` are within the existing read authority and that denying every non-read protected-table action is sufficient to preserve app-only audit writing.
2. QA must approve the synthetic legacy-trigger fixture as an owner-data-free representation of the confirmed sandbox schema path.
3. Delivery must pin the exact nonlaunch script mode names and rollback behavior before implementation; those CLI names are not a product API and may follow existing shell style.
4. Final acceptance is blocked by design until the owner's manual installed-app validation and explicit approval.
