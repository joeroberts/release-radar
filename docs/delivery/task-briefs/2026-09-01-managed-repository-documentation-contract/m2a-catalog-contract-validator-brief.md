# MDCP M2A Brief: Catalog Contract and Validator

**Status:** Proposed and unopened. M1 owner approval and separate M2A
authorization are required before RED, implementation, tests, or Git actions.

## Objective and user-visible outcome

Define catalog v1 and a safe Core parser/validator so a managed repository can
identify every durable documentation artifact by stable ID and report precise,
read-only failures before any index, evidence, or delivery behavior changes.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/delivery/progress.md`

No UI is added in this slice, so no runtime visual gate applies.

## Scope

In scope:

- Core-owned catalog v1 models, decoding, normalized path rules, and typed
  errors;
- immutable repository identity, permanent retired artifact IDs, and
  deterministic collection metadata for purpose, allowed/prohibited contents,
  first read, index/leaf state, and archive destination;
- orthogonal kind, lifecycle, authority, parent, supersession, application
  sensitivity, and checksum policies;
- deterministic catalog snapshot version/digest;
- current-tree completeness and safety validation;
- explicit prior/current catalog transition validation;
- one narrowly enumerated transitional-subtree exception that requires direct
  navigation from an indexed ancestor, catalogs every contained artifact,
  rejects new content, and is removed by the cutover transition;
- no-follow, bounded, authorized-root reads; and
- focused XCTest fixtures and rejection coverage.

Out of scope:

- index generation, application guidance changes, evidence schema/commands,
  importer changes, owner data, repository catalog creation, or document moves;
- a JSON Schema dependency, generalized filesystem library, or new package;
- application launch, installed guidance, and Task 4B.

## Dependencies and release gate

- Owner-approved M1 package and ADR-006.
- Fresh Planning, Architecture, QA, TPM, Delivery, and Security/Privacy release
  of this exact brief.
- Exact clean implementation base recorded in `docs/delivery/progress.md`.

## Anticipated files

- Add focused files under `ReleaseRadarCore/Documentation/` for the contract,
  catalog models, snapshot, validator, and errors.
- Add catalog fixtures below `ReleaseRadarTests/Fixtures/RepositoryDocuments/`.
- Add focused `ReleaseRadarTests/RepositoryDocumentCatalogTests.swift`.
- Modify `ReleaseRadar.xcodeproj/project.pbxproj` only if synchronized-group
  membership does not already include the new files.

A needed production path outside Core stops for Architecture review.

## Data, security, and privacy

The parser reads repository metadata only through the caller's authorized root.
It must reject absolute/traversing paths, symlinked roots/intermediates/finals,
non-regular files, root escape, invalid UTF-8, over-limit input/counts, and
content changing during the snapshot. It writes no repository or app state and
must not include file content or owner paths in errors beyond the bounded
root-relative artifact path.

## Test-first strategy

RED must first prove missing, valid v1, malformed, unsupported-version,
duplicate-ID, duplicate-normalized-path, invalid-enum, conflicting-controller,
supersession-cycle, missing-replacement, missing-file, uncatalogued-file,
checksum, broken applicable link, unsafe path/type, and changed-during-read
behavior. Old/new fixture pairs prove allowed and prohibited lifecycle changes,
including controlling deletion, retired-ID reuse, collection graph/metadata,
repository-ID validity, transitional-subtree scope/new-content/removal, and
archive restoration refusal.

Use one small valid fixture and programmatically mutated temporary copies. Do
not create a fixture DSL or custom test framework.

## Happy and non-happy behavior

- A valid v1 tree returns one immutable, deterministically digested snapshot.
- Current validation is read-only and does not claim transition validity.
- Transition validation requires an explicit prior accepted snapshot.
- Any unsafe or inconsistent input returns a typed actionable error with zero
  repository, database, audit, receipt, notification, or delivery mutation.

## Acceptance criteria

- Catalog fields and invariants exactly match ADR-006.
- `docs/catalog.json` is the sole self-exclusion; every other eligible regular
  `docs/` file/asset must be catalogued.
- Only active artifacts can control and controller roles are unique.
- Artifact identity is independent of path, filename, checksum, and content.
- Collection metadata is the complete deterministic input for generated index
  semantics, and repository/artifact identities cannot be silently reused.
- Every required rejection and catalog-change race has an attributable GREEN
  test after valid RED.
- Existing non-documentation behavior and files remain unchanged.

## Reviews and completion evidence

Required post-implementation reviews: Code Review, QA, Architecture, TPM,
Delivery Management, and Security/Privacy. The ledger records the exact file
inventory, RED/GREEN commands and counts, review verdicts, residual risks, and
the next eligible brief. Presence of this brief does not open M2A.
