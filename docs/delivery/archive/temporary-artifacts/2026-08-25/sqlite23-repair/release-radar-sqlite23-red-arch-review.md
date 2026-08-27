# Release Radar SQLite-23 Post-RED Architecture Review

**Role:** Fresh independent Architecture reviewer  
**Date:** 2026-08-25  
**Scope:** Post-RED repair-plan correction only  
**Decision:** **GO**  
**Required findings:** **0**

## Materials reviewed

- Repository `AGENTS.md`
- `/tmp/release-radar-sqlite23-repair-brief.md`
- `/tmp/release-radar-sqlite23-implementer-report.md`
- `docs/delivery/progress.md`, especially “Repair-plan ruling after first RED”
- `docs/architecture/ADR-001-release-radar-boundaries.md` solely to confirm the existing app-only SQLite writer and transactional/audited mutation boundary

## Architecture decision

The amended RED contract is architecturally sound. It should bind the real onboarding regression to the stable primary SQLite result `SQLITE_AUTH` (23), the exact production `projects` upsert, the exact recognized legacy active-phase trigger shape, a populated synthetic version-9 fixture, and complete preservation assertions. The independently captured authorizer tuple `(SQLITE_READ, audit_events, project_id)` and the standalone exact message `access to audit_events.project_id is prohibited` provide root-cause attribution. Requiring the higher-level XCTest path to reproduce identical `sqlite3_errmsg` wording would incorrectly make a platform/path-dependent human-readable string part of the architecture contract; the generic `not authorized` text does not contradict the shared primary code or the independently observed authorizer decision.

This evidence is sufficiently specific to prevent an unrelated authorization failure from satisfying the RED gate: the real callback must execute `FolderProjectOnboarding.inspect` and `prepare`, use the production upsert, run against the exact legacy compatibility objects, and fail with primary code 23 before the policy change. The separate diagnostic must retain the exact tuple and owner-visible text. These are complementary pieces of evidence, not substitutes for one another.

The populated fixture correction is necessary and correctly scoped. Before production code changes, the resumed implementer must seed unrelated durable state including an unrelated project, its active phase/phase relationship, an ordinary child such as a ticket, and a project-scoped store-owned audit. The test must snapshot values, counts, and relationships and capture a new RED through the real callback. The existing `/tmp/release-radar-sqlite23-red-verified.xcresult` came from an unpopulated fixture and therefore must not be represented as the final populated-state RED. After GREEN, the fixture must prove the unrelated graph and scoped audit are unchanged field-for-field and relationship-for-relationship, with the only delta being the exact new onboarding state and its one store-owned prepare audit.

Implementation may resume under the amended sequence. Resumption means first amending and rerunning the populated migrated-schema RED; production authorizer work may proceed only after that test fails through the expected real callback with primary code 23. This Architecture GO does not waive the separately required fresh QA/test and Security/Privacy decisions, nor any later post-implementation or packaging gates.

## Boundary and ADR assessment

Allowing only `SQLITE_READ` when the transaction authorizer names `audit_events`, while denying every other action naming that table and retaining transaction-control checks first, preserves the established boundary:

- The app process remains the sole SQLite writer.
- `DeliveryStore` remains the transaction owner and the only component that appends the successful audit outside the restricted callback.
- Callback code gains no protected-table mutation authority; direct `INSERT`, `UPDATE`, and `DELETE` remain denied.
- SQLite-required foreign-key reads can proceed, while indirect `ON DELETE SET NULL` mutation of `audit_events.project_id` remains denied and must roll back the parent, ordinary cascade child, and audit reference atomically.
- No migration, schema deletion, owner-data repair, onboarding SQL change, signing change, or entitlement change is needed.

The correction is compatible with ADR-001’s app-only SQLite authority and transactional/audited mutation requirements. No ADR amendment is required.

## Durable diagnostic disposition

Privacy-bounded durable unified logging remains the correct future stable evidence. The installed path should identify a fixed event/stage, primary and extended SQLite result codes, authorizer action code/name, equality-allowlisted protected identifiers, schema version, and transaction-state booleans. It must not depend on arbitrary `sqlite3_errmsg` text and must not log SQL, bindings, owner identifiers, paths, bookmark data, row values, actor/reason/thread values, or other owner content. The authorizer logger must not query SQLite. This makes action/stage/result observable at the real failure boundary without turning unstable wording or sensitive data into the diagnostic contract.

## Findings classification

### Required

None. The amended brief already contains the required populated-fixture, preservation, tuple, mutation-denial, rollback, and diagnostic gates.

### Optional

None.

### Out of scope

- Changing `SQLiteConnection` merely to force every wrapper/path to reproduce the exact owner-visible SQLite message.
- Dropping or rewriting legacy triggers, indexes, columns, foreign keys, audits, or owner data.
- Adding a migration, changing the onboarding SQL, weakening callback containment, or broadening diagnostics beyond the fixed privacy allowlist.

## Gate conclusion

**GO — Required 0.** The amended plan uses stable machine-readable evidence for the RED contract, retains the exact owner-visible message and authorizer tuple as independent root-cause evidence, and adds the production-shaped populated-state preservation proof that the first RED lacked. Architecture permits implementation to resume with the populated RED as the first mandatory step; all other independent gates remain binding.
