# MDCP M3A Brief: Add Managed Evidence Identity

**Status:** Completed. Retained as a non-authoritative record of the delivered
task scope; the original execution instructions below do not reopen work.
Current delivery state and authorization are in [progress.md](../../progress.md).

## Objective and user-visible outcome

Add the storage, public model, durable project repository-binding, and secure
resolver foundation for stable managed-document identity while preserving
every existing evidence record as legacy path evidence and preserving legacy
API behavior.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-007-proportional-delivery-validation.md`
- Accepted M2 catalog snapshot and M3A0 schema-v12 fixture

## Scope

In scope:

- additive schema v13 with a database-enforced exhaustive managed/path locator;
- a project-documentation binding relation with one row per project, unique
  `repositoryID` and bound project-root row ID, plus canonical accepted catalog
  snapshot/version/digest fields;
- lossless v12-to-v13 migration with every old row remaining path-located;
- legacy projects initially unbound, with no inferred repository identity;
- public Codable managed/legacy evidence models;
- public project-binding/readback models;
- secure managed-document resolver using authorized catalog snapshots;
- resolved path, label, lifecycle, authority, availability, and typed failure;
- exact schema manifest, rollback, snapshot recovery, relaunch, and legacy
  decoding tests.

Out of scope:

- filesystem inference during migration, binding/inventory/adoption commands,
  importer conversion, root rebinding, UI changes, owner installation/data, or
  document moves.

## Dependencies and release gate

- Accepted immutable M3A0 schema-v12 fixture.
- Separate owner authorization for M3A.

## Anticipated files

- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarCore/Models/DeliveryModels.swift`
- Add focused resolver/model files under `ReleaseRadarCore/Documentation/`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- Focused resolver/model tests and the M3A0 fixture membership

Dashboard/importer/bridge files are not changed in M3A.

## Data, security, and privacy

Migration performs no repository I/O and never sees an authorized root. It
creates no binding. Database constraints permit at most one binding per project
and prevent a `repositoryID` or bound project-root row from binding to multiple
projects. The resolver accepts only the exact bound authorized root row, its
persisted canonical accepted snapshot, and a validated current snapshot whose
repository ID/version/digest matches. It uses no-follow bounded access and must
not persist physical managed paths as identity. Errors avoid exposing bookmark
bytes or unnecessary absolute paths.

## Test-first strategy

RED/GREEN covers exact schema-v12 migration, every legacy row and unrelated
sentinel preserved, zero inferred artifact IDs, exactly-one-locator constraints,
unsupported future schema refusal, injected late migration failure and snapshot
recovery, relaunch, legacy Codable payload compatibility, empty migrated
bindings, binding/root uniqueness, canonical accepted-snapshot round trip,
managed resolution after an accepted path change, missing/mismatched binding,
wrong/stale root row, multiple project roots, same-repository-ID catalog digest
swap, missing/restored files, archived/superseded availability, catalog failure,
checksum mismatch, and root escape. Public-model tests round trip both locator
variants and the binding model and reject missing or mixed locator payloads.

## Happy and non-happy behavior

- Existing evidence behaves as path evidence after migration.
- Managed evidence resolves its current catalog path without row rewrite.
- Available historical evidence remains available but non-controlling.
- Unsafe/unavailable resolution returns typed state without identity loss or
  unrelated mutation.

## Acceptance criteria

- No migration code reads a repository or maps an artifact ID.
- Every migrated project is unbound; project, repository, and root-row binding
  uniqueness is database enforced.
- Evidence IDs, project/ticket associations, paths, availability, audits, and
  unrelated state match the v12 semantic baseline.
- Database constraints reject missing or mixed locators.
- Public Codable behavior is exhaustive for managed and legacy locators while
  preserving accepted legacy payload decoding.
- Managed identity is artifact ID only; cached path cannot own uniqueness.
- Managed resolution requires the exact bound root row and accepted repository
  ID/version/digest and rejects unaccepted same-root catalog replacement without
  mutation.
- Migration rollback/relaunch evidence uses the genuine M3A0 fixture.

## Reviews and completion evidence

Required risk-triggered reviews: Code Review, QA, Architecture, and
Security/Privacy. TPM participates only if sequencing or dependencies materially
change. Planning is not an approval role. Delivery Management records concise
schema, migration, rollback, and fixture verification plus residual risks and
next eligible work; it is not an approval. Completion does not authorize M3B.
