# SQLite-23 Post-RED Security/Privacy Review

**Role:** Fresh independent Security/Privacy reviewer  
**Decision:** **GO**  
**Open Required findings:** **0**

## Scope reviewed

This review is limited to the amended post-RED ruling and the owner's requirement that the real-callback migrated-schema fixture begin with representative, unrelated populated state and prove that state remains unchanged. It does not review or approve production implementation, the broader authorizer design, packaging/install mechanics, or an eventual Release artifact.

Reviewed evidence and controlling requirements:

- `AGENTS.md`
- `/tmp/release-radar-sqlite23-repair-brief.md`
- `/tmp/release-radar-sqlite23-implementer-report.md`
- `docs/delivery/progress.md`, especially `Repair-plan ruling after first RED — 2026-08-25`

## Security/privacy decision

Dropping exact higher-level `sqlite3_errmsg` equality from the real-callback RED does **not** materially weaken security assurance. SQLite's human-readable error wording is not the authorization boundary and, in the captured paths, differs between the standalone diagnostic (`access to audit_events.project_id is prohibited`) and the real `SQLiteConnection` callback (`not authorized`) even though both reach primary result code `SQLITE_AUTH` (23). Requiring wrapper-level message equality would test an unstable presentation detail rather than the denied operation.

The amended evidence bundle is sufficient because it correlates independent and complementary signals:

1. The standalone synthetic diagnostic captures primary code 23, the exact authorizer tuple `(SQLITE_READ, audit_events, project_id)`, and the exact owner-visible message.
2. The real production onboarding callback uses the exact production project upsert against the exact recognized legacy compatibility shape and reaches primary code 23.
3. The real-callback fixture is required to be populated with representative unrelated project, active-phase/phase, child/ticket, and project-scoped store-owned audit state.
4. The fixture must snapshot that pre-existing state and prove it unchanged field-for-field and relationship-for-relationship, with the only successful post-fix delta being the exact new onboarding state and its single store-owned prepare audit.
5. Future diagnostics are bound to fixed fields for action, stage, and result, avoiding dependence on arbitrary SQLite message text.

Code 23 alone would be ambiguous. Code 23 plus the independently captured tuple, exact legacy triggers/schema shape, exact production upsert, real callback, and populated-state preservation assertions sufficiently controls the risk that a different authorization failure could be mistaken for this defect.

## Populated-fixture privacy assessment

The populated migrated-schema fixture remains privacy-safe as specified. It uses only synthetic database content and must not copy the owner's database, rows, paths, bookmark bytes, repository content, IDs, or other values into source, test artifacts, logs, or durable evidence. Representative structure and relationships are needed for preservation testing; real owner values are not.

The fixed-field logging boundary is appropriate and security-positive. Stable logs may identify only the fixed action/stage/result fields and explicitly allowlisted schema identifiers. They must not include SQL text, SQLite or trigger messages, bound values, paths, project or actor/reason/thread identifiers, bookmark data, prompts, credentials, or row contents. In particular, the exact owner-visible message belongs only to the standalone synthetic reproduction evidence; production diagnostic correctness must not depend on logging that message.

Snapshot comparisons may use synthetic fixture values internally for assertions, but failures should not print or attach prohibited values. Durable evidence should report pass/fail, counts, stable fixture labels, and result codes rather than row dumps.

## Findings classification

### Required — 0 open findings

No new Required finding is introduced by the amendment.

The following are binding gates already incorporated into the amended brief, not unresolved review findings:

- Before production code changes, revise and rerun the real-callback RED using the populated synthetic migrated-schema fixture. The earlier fresh-database RED described in the implementer report does not satisfy the owner's populated-state requirement.
- Retain the standalone tuple/exact-message diagnostic separately from the real-callback RED.
- Require primary code 23 from the real callback, but do not require exact human-readable message equality there.
- Prove complete preservation of pre-existing synthetic state and relationships; after GREEN, permit only the explicitly expected onboarding delta and one store-owned audit.
- Keep diagnostic output fixed-field and privacy-bounded, with no SQL, messages, values, paths, or IDs.

If the revised populated fixture does not reproduce code 23 through the real callback, or if it requires owner-derived data to do so, implementation must stop and return to Planning/Security review.

### Optional — 0

No optional work is needed for this ruling. Additional message-normalization logic or broader diagnostic payloads would add risk without improving the authorization proof.

### Out of scope

- Requiring `SQLiteConnection` to preserve or expose an exact SQLite human-readable authorization message.
- Logging arbitrary `sqlite3_errmsg`, SQL, trigger text, bindings, paths, IDs, or row values.
- Using a copy, sample, redaction, or extract of the owner's database as a test fixture.
- Reopening migrations, legacy schema objects, onboarding SQL, the owner database, UI, packaging/install behavior, or unrelated repair scope as part of this RED correction.
- Approving the eventual production diff, GREEN security matrix, signed bundles, entitlements, staging, installation, or owner validation; those retain their separate independent gates.

## Resume ruling

**GO for implementation to resume under the amended plan.** The first resumed implementation action must be to revise and retain the populated synthetic real-callback RED. Production authorizer or logging changes may proceed only after that RED reaches primary code 23 and the fixture's pre-existing synthetic snapshot is shown intact. This sequencing preserves both the security boundary and the owner's privacy requirement without treating unstable SQLite message wording as a security contract.
