# Independent Architecture Engineering Review — SQLite-23 Repair

## Decision

- **Verdict: GO** for the pre-packaging Architecture engineering gate.
- **Required findings: 0.**
- **Optional findings: 1 documentation/diagnostic clarification; non-blocking.**
- **Out-of-scope findings: 1 previously recorded product/audit-contract change.**
- **ADR disposition: no ADR-001 change is required.** The repair implements the existing signed/sandboxed app, app-owned SQLite, transactional/audited mutation, and configured Apple Development signing boundaries rather than introducing a new architecture decision.

This GO covers the reviewed repair source, tests, and Release script only. It does not authorize packaging or installation, does not claim artifact verification or owner runtime success, and does not change the ledger status from reopened. TPM and Delivery engineering decisions, explicit Delivery packaging authorization, later artifact QA/Security review, and owner approval remain separate gates.

## Review boundary and evidence

I reviewed the governing repository instructions, the amended repair brief, the complete implementer report including fix rounds 1 and 2, both final scoped review packages, the final Code/QA/Security re-reviews, ADR-001, and the complete SQLite-23 repair section of the progress ledger. I also inspected the final relevant source regions and confirmed the production/store/script file hashes still match the fix-round-1 package; the Onboarding test differs only by the fix-round-2 `SELECT *` blocker snapshot described in its scoped package.

No repository file, Git state, application bundle, owner data, or external system was changed or accessed. I did not stage, install, launch, or rerun broad tests. Reported test results are evidence reviewed from the supplied independent reports, not results independently rerun in this Architecture role.

## Architecture assessment

### 1. Final authorizer rule — within ADR-001 and the brief

`deliveryStoreTransactionAuthorizer` still evaluates transaction/savepoint control first. When either SQLite authorizer identifier names `audit_events`, it returns `SQLITE_OK` only for `SQLITE_READ`; every other action returns `SQLITE_DENY`. All unrelated authorizer behavior is preserved.

This is the narrow compatibility correction approved by the brief. It admits a read already consistent with the store's read authority and permits SQLite to enforce the existing foreign-key relationship. It does not grant a helper, observer, bridge, repository process, or callback an independent SQLite writer role. The app process and `DeliveryStore` remain the sole database and transaction authority.

### 2. Callback context — contained and safe

The final callback context is a short-lived immutable object containing only a Boolean transaction-state snapshot. That value is computed before authorizer registration, held through the synchronous restricted body with `withExtendedLifetime`, and the authorizer is removed by `defer`.

The callback no longer calls `sqlite3_get_autocommit`, another SQLite API, or SQL while SQLite is executing the authorizer callback. It carries no connection pointer, SQL, binding, actor/reason, project identifier, path, bookmark, credential, or row data. This preserves the callback and privacy boundaries and does not create a new architectural interface.

### 3. Audit mutation containment — preserved

The action-sensitive rule allows the relational-integrity read but denies direct callback `INSERT`, `UPDATE`, and `DELETE` against `audit_events`. It also denies the SQLite-induced `ON DELETE SET NULL` update caused by deleting a referenced project. The reviewed regressions assert code 23, full rollback of an ordinary sibling mutation, preservation of the project, scoped audit reference and ordinary cascade child, no failed-transaction audit, and a clean foreign-key check.

The store-owned audit insertion remains outside the restricted callback and before commit. Therefore the repair does not weaken ADR-001's requirement that delivery mutations remain app-validated, transactional, and audited.

### 4. Populated-data preservation — within the compatibility boundary

The final synthetic version-9 fixture retains the legacy `projects.active_phase_id`, index and validation triggers that reproduce the installed-app path. It starts with unrelated project, full phase, active-phase relation, ticket, full blocker (including nullable `resolved_at`), and full project-scoped audit state. Before/after snapshots preserve those rows and relationships field-for-field; only the expected new onboarding project and one prepare audit increase counts. Repository sentinel/listing, relaunch recovery, bookmark balance, and foreign-key integrity are also covered by the reviewed evidence.

No migration, schema version change, legacy-object deletion, database reset, copied owner database, or owner-data repair was introduced. That is consistent with ADR-001's app-owned local-state boundary and the brief's compatibility-only scope.

### 5. Fixed-field logging — within ADR-001 and the privacy contract

The SQLite boundary emits fixed event/stage, primary and extended result, authorizer action code/name, equality-sanitized protected table/column, and the precomputed transaction Boolean. It deliberately excludes SQL, bindings, arbitrary SQLite/trigger messages, actors, reasons, thread/project/entity values, names, paths, bookmark bytes, prompts, credentials, and row data. Unified logging and the bounded test capture receive the same fixed payload.

This is diagnostic telemetry inside the app process, not a new source of delivery authority or persistence. The authorizer callback does not query SQLite to construct it. It therefore remains within ADR-001 and the reviewed brief.

### 6. Release script — within signing, sandbox and delivery boundaries

The script builds Release only, disables injected base entitlements, pins the configured Apple Development authority/team, requires Hardened Runtime, and compares the complete main/Bridge entitlement plists against the approved structures. It verifies embedded signed code and the bundle identifier and compares CDHash, version/build, executable hash, and signed-resource manifest.

Nonlaunch stage/install modes copy into unique same-parent temporary directories, verify before and after promotion, preserve a verified prior final until final verification/identity succeeds, and restore or retain/report artifacts on failure. App termination/opening remains confined to explicit launch modes. The script does not add SQLite access, an integration authority, new entitlement, distribution identity, notarization claim, or automatic owner approval. It implements the existing ADR-001 owner-local signing and sandbox decision; no ADR amendment is needed.

## Prepare-audit association scope ruling

The recorded ruling to preserve the existing unscoped prepare audit is architecturally sound and scope-correct for this repair.

ADR-001 requires app-validated, transactional, audited mutations; it does not require every audit to have structured project/entity association. The controlling Task 7A/repair contract identifies this prepare audit by actor `release-radar-onboarding`, reason `Prepare folder-backed project onboarding`, and count. Adding structured scope would require changing `FolderProjectOnboarding.prepare`, which the repair brief explicitly excludes.

The known consequence—this unscoped prepare audit may be absent from a project-filtered Activity view—is a separate product/audit-contract decision. It is **Out of scope**, not a Required defect in the SQLite-23 repair, and should not be folded into this gate without an explicit product requirement and separately reviewed change.

## Findings and concerns

### Required

None.

### Optional — diagnostic/ledger wording alignment

The repair section's diagnostic-boundary summary lists schema version among the log fields, while the final fixed payload does not emit it. The amended brief's operative logging objective and acceptance evidence require stage, results, authorizer action, allowlisted protected identifiers, and transaction state; its privacy contract describes schema version as an allowed field rather than a condition for architecture acceptance. The current payload satisfies that objective and this is not an ADR or packaging blocker.

For future ledger clarity, Delivery may either describe schema version as allowlisted/optional or open a separate bounded diagnostic enhancement. If schema version is later added, it must be precomputed outside the authorizer callback; no SQLite query may be introduced inside that callback.

### Out of scope

- Adding project/entity scope to the prepare audit or changing Activity visibility for legacy/unscoped audit rows.
- Any migration or removal of retained legacy active-phase schema objects.
- Packaging, installation, artifact verification, app launch, owner-data validation, and owner acceptance in this Architecture engineering review.

## Final gate statement

**Architecture GO, Required 0, ADR-001 unchanged.** The final repair preserves the app-only SQLite writer, store-owned transaction/audit authority, callback containment, populated-data compatibility, privacy-bounded diagnostics, and approved signed/sandboxed Release delivery boundary. Packaging remains closed until the remaining TPM and Delivery engineering decisions are recorded and Delivery explicitly authorizes the next gate.
