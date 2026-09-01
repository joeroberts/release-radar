# ADR-006: Managed repository documentation contract

- Status: Proposed; independently reviewed; owner approval pending
- Date: 2026-09-01

## Context

Release Radar currently recognizes repository documentation by physical path
across guidance inspection, onboarding copy, a bundled skill, the Rekon seed
importer, evidence commands, SQLite rows, dashboard projections, fixtures, and
tests. Repository documentation has no complete root index or uniform local
indexes, current and historical authority compete, and active artifacts remain
under `docs/superpowers/`. `docs/delivery/progress.md` also retains completed
detail that should not remain active execution context.

The application stores evidence identity as `evidence.path`, enforces
`UNIQUE(project_id, path)`, and derives UI labels from that path. Moving a
document can therefore invalidate durable evidence even when the document's
meaning has not changed. The store migrates before a project bookmark and
catalog can be safely resolved, so automatic migration cannot truthfully infer
document identity.

ADR-001 prohibits repository documentation from becoming a competing delivery
authority and keeps SQLite app-owned. ADR-002 makes bundled-plugin integrity
and exact installed content explicit. ADR-005 keeps Task 4B a separate bounded
command feature. The managed-documentation repair must preserve all three
boundaries.

## Decision

Release Radar will support a versioned, opt-in managed repository documentation
contract with these invariants.

### Contract and catalog authority

- One Core-owned `RepositoryDocumentContract` defines recognized relative
  paths, catalog and guidance versions, managed index markers, and bounded
  limits.
- `docs/catalog.json` v1 is the navigation, lifecycle, authority, and stable
  identity source for eligible artifacts under `docs/`. It does not replace
  their content and never owns ticket/phase/delivery state.
- Catalog artifact kind, lifecycle, and authority are separate dimensions.
  Evidence is a kind. Archived is a lifecycle. Only active artifacts may be
  controlling, and only one active artifact may control an authority role.
- `artifactID` is immutable and independent of path, filename, checksum, and
  content. Moves update only the catalog path; exceptionally deleted IDs enter
  a permanent retired-ID set and can never be reused.
- Schema v13 persists a one-to-one project documentation binding with the exact
  project-root row ID, immutable catalog `repositoryID`, and canonical accepted
  catalog snapshot/version/digest. Legacy projects migrate unbound; repository
  and root identities cannot bind to multiple projects or silently replace an
  existing project binding.
- A typed, audited, idempotent activation command binds an unbound project to
  the exact authorized root row and catalog snapshot. Every managed resolution,
  inventory, creation, adoption, import, and root rebind requires that bound
  root and the current catalog repository ID/version/digest to match the
  accepted binding. Same-root catalog replacement, missing binding, and
  mismatch fail closed without mutation.
- A separate typed, audited, idempotent catalog-acceptance command validates the
  stored prior accepted snapshot against the bound-root candidate, including
  artifact identity and lifecycle/path transitions, then atomically advances
  only the accepted snapshot/version/digest plus audit/receipt. Until it
  succeeds, the candidate is pending and managed operations remain closed.
- Every directory has catalog collection metadata for stable collection/parent
  IDs, path, purpose, allowed/prohibited contents, first read, index artifact
  or leaf state, and optional archive destination. Index generation has no
  second configuration source.
- `docs/catalog.json` is excluded from its own artifact set. All other eligible
  regular files and durable assets under `docs/` are catalogued. Narrow future
  exclusions are versioned and tested; transient files are otherwise rejected.

### Safe catalog snapshots and transition validation

- Catalog reads occur only below an authorized, resolved project root using
  bounded no-follow access. Absolute paths, dot-segment traversal, symlinked
  components, non-regular files, root escape, duplicate IDs/paths, invalid
  authority/lifecycle, and required-checksum disagreement reject.
- A snapshot includes the supported catalog version and deterministic digest.
  A file or catalog change observed during the read invalidates the snapshot.
- Current-state validation proves completeness and consistency. Lifecycle
  transition validation also consumes the explicit prior accepted catalog; a
  single snapshot cannot prove a legal transition or deletion.
- Superseding an active controller requires an active replacement link.
  Archived content remains non-authoritative regardless of preserved prose.

### Deterministic indexes

- A separate, fixed-purpose repository documentation executable uses the same
  Core model to validate catalogs and render managed README sections.
- Check mode is read-only. Write mode, when separately authorized, replaces
  only exact managed markers and preserves human text. It prevalidates the
  complete candidate, uses per-file atomic replacement, and performs bounded
  rollback of already replaced indexes if a later replacement fails.
- Generation is deterministic and every directory is indexed or declared a
  leaf by its parent.
- The executable is not folded into the existing narrow agent mutation helper
  and does not gain generic filesystem capability.

### Documentation modes

The UI and public contracts expose one coherent mode:

- legacy guidance v1;
- a staged valid catalog under v1, usable only for read-only preview;
- managed guidance v2 with a required compatible catalog v1; or
- managed unavailable when v2 guidance is readable but its catalog is missing,
  malformed, unsupported, unsafe, checksum-invalid, or unstable, or the
  project repository binding/root is missing or mismatched, or the current
  catalog digest is not accepted. Only the explicit activation command may
  establish an initially missing binding; only catalog acceptance may advance
  an existing accepted snapshot.

Under v1, catalog presence never changes import, evidence, availability, or
delivery state. Managed operations fail closed when v2 is unavailable, while
guidance remains inspectable. Guidance v3 is reserved for GitHub Issue #1.

Guidance v2 owns the reusable agent behavior: catalog-first discovery, local
index traversal before broad search, task-relevant controlling context only,
same-change catalog/index/reference/checksum maintenance, active-only progress,
archival closeout, no new or recreated `docs/superpowers/`, no direct managed
evidence path repair or SQLite edit, supported catalog-transition acceptance,
and validation/readback agreement before completion. A filesystem catalog
change remains pending until the typed application acceptance succeeds.

### Typed evidence locator

Evidence uses an exhaustive locator, and schema v13 also introduces the empty
project documentation binding relation described above:

- `managedDocument(artifactID)`; or
- `filePath(path)`.

Persistence enforces exactly one locator. Existing rows migrate losslessly to
legacy path locators. A managed row stores no physical path as identity or
uniqueness. Its path, label, lifecycle, authority, and availability are
resolved from the authorized catalog snapshot.

Automatic schema migration is catalog-agnostic. It performs no repository I/O
or identity inference and preserves all evidence IDs, associations, paths,
availability values, audits, and unrelated delivery state. A genuine,
checksummed schema-v12 fixture is frozen before schema implementation and
covers managed-eligible, arbitrary, missing, ticketless, and ticket-associated
legacy evidence plus unrelated state.

### Inventory, adoption, and legacy relocation

- The existing authenticated fixed-purpose application transport gains one
  distinct read-only query dispatcher and additive tools named
  `release_radar_inventory_evidence`,
  `release_radar_bind_documentation_repository`,
  `release_radar_accept_documentation_catalog`,
  `release_radar_add_managed_evidence`,
  `release_radar_adopt_managed_evidence`, and
  `release_radar_relocate_legacy_evidence`. Catalog/index write behavior remains
  entirely in the separate repository documentation executable.
- The binding command names the project, exact authorized root-row ID,
  `repositoryID`, catalog version, and digest. One transaction writes only the
  binding with canonical accepted snapshot, audit, and receipt; exact replay
  returns the original result, while conflict or late failure changes nothing.
- The acceptance command names the project/root binding, expected prior and
  candidate version/digests, and request ID. It validates the stored canonical
  prior snapshot against the current bound-root candidate before its atomic
  accepted-snapshot update; replay, stale input, and failure are zero-effect.
- A project-scoped read-only inventory reports evidence ID, project, optional
  ticket, locator, current/resolved path, availability, lifecycle/authority,
  exact managed candidate, and rejection reason. It creates no database,
  repository, audit, request-receipt, notification, or delivery mutation.
- Unbound v1 catalog preview remains read-only. Under managed v2, inventory and
  every managed mutation first require the exact root-row binding and current
  snapshot repository ID/version/digest to match the accepted project binding.
- Existing evidence becomes managed only through an explicit typed, audited,
  idempotent adoption bound to the expected catalog version/digest, exact
  evidence ID, exact prior path, and exact artifact ID.
- The app revalidates the same catalog snapshot immediately before one
  store-owned transaction. Stale, ambiguous, missing, unsafe, filename-only,
  basename-only, or checksum-only matches reject or remain legacy.
- Arbitrary legacy evidence uses a separate explicit exact-path relocation;
  managed evidence is never path-repaired.
- New managed evidence is created only from artifact ID plus expected catalog
  digest and commits its audit/receipt atomically. The existing path-based
  `addEvidence` remains backward compatible for genuinely arbitrary evidence;
  under v2 it rejects an exact catalogued path with actionable managed-command
  recovery rather than silently creating legacy identity.
- Uncertain outcomes use the existing request receipt and exact replay
  contract. Failure rolls back the locator, audit, and receipt together.

### Importer behavior

- Legacy v1 Rekon schema-v1 import remains path-based and behaviorally
  unchanged.
- Staged catalog preview under v1 cannot alter importer output.
- Under managed v2, a valid catalog snapshot from the bound root whose
  repository ID/version/digest matches the accepted project binding may
  classify a recognized documentation path as managed only through one exact
  canonical catalog match. Arbitrary and uncertain paths remain legacy. A
  missing/mismatched/pending binding or bad managed catalog rejects before
  import delivery mutation.
- Catalogs and generated indexes are never interpreted as seed delivery
  authority.

### Resolution, presentation, and root relocation

- Managed evidence resolves through the exact bound authorized root row and
  current catalog path only when the catalog repository ID/version/digest
  matches the durable accepted project binding. Missing/restored files change
  resolved availability without changing identity.
- Availability and authority are distinct. UI/readback distinguishes proposed,
  current, completed, superseded, archived, missing, catalog-invalid/pending/
  unaccepted, root-unavailable/non-bound, and checksum-invalid states.
  Historical evidence may be available without being controlling.
- Repository relocation is an explicit owner-confirmed, typed, audited root
  rebind with a fresh security-scoped bookmark. It preserves project identity,
  requires the exact accepted catalog repository ID/version/digest, and rejects
  roots owned elsewhere or a different/unaccepted managed repository.
- The rebind transaction may change only the root row, bookmark row, binding's
  root-row association, and—when uniquely identified—the legacy root-
  `AGENTS.md` handoff evidence path, plus its audit/receipt. The proposed root
  must contain the exact accepted catalog. Zero matching old-root handoff rows
  permits a rebind with no evidence update; exactly one matching row updates
  atomically; multiple, ambiguous, or mismatched rows reject the entire
  transaction. The old bound bookmark is revoked and old/unbound roots cannot
  resolve managed evidence. All other evidence remains unchanged; there is
  never a partial rebind or generic prefix rewrite.

### Compatibility and sequencing

M2-M5 exclusively own changes to shared command/query, evidence, importer,
guidance, bundled-skill, and overlapping test contracts. After all M2-M5
briefs are independently accepted and one exact clean candidate is recorded,
the coordinator may declare `MDCP-COMPAT-1`.

Only then may Task 4B become eligible for a separate planning refresh and
owner authorization. Task 4B remains the RR-R10 command-exposure task; Issue #1
remains the later guidance-v3 onboarding/adoption feature.

M6-M8 consume the frozen candidate and may not change frozen application or
test contracts. If a later milestone discovers that such a change is required,
both MDCP live work and Task 4B stop. The affected M2/M3/M5 slice is corrected,
independently re-reviewed, and a replacement `MDCP-COMPAT-1` is recorded before
Task 4B may resume. Progress-ledger writes are serialized.

M7 changes repository bytes while the application remains bound to the old
accepted catalog and all writers are quiesced. M8, under separate owner
authorization, uses the frozen acceptance command to validate and advance to
the exact M7 candidate before managed readback or live-use release. Failure
before acceptance retains the old trust anchor; failure after acceptance keeps
the new repository/snapshot quiesced and cannot silently roll it backward. An
unknown acceptance outcome must resolve through exact replay and supported
binding readback before repository recovery. A post-acceptance repository-only
defect uses a new forward M7/M8 transition from the accepted snapshot; only a
frozen-contract defect reopens M2/M3/M5.

The normal repository test/check workflow invokes the M2 check implementation
against the real repository once managed v2 is the candidate. Missing,
malformed, unsafe, or stale catalog/index state therefore fails the ordinary
workflow rather than depending on a manual closeout command.

## Consequences

- Documentation moves retain stable managed evidence identity.
- Legacy and arbitrary evidence remain compatible and explicitly distinct.
- Storage migration stays deterministic, transactional, and independent of
  filesystem authorization.
- Repository catalogs can be staged and inspected before they become active.
- Broken managed documentation fails truthfully without mutating delivery
  state.
- Historical availability no longer implies current authority.
- Root relocation becomes a supported owner action rather than an inferred
  path rewrite.
- The catalog adds a durable repository obligation: every eligible artifact,
  index, lifecycle transition, link, and applicable checksum must agree.
- The new documentation executable adds one bounded build target, justified by
  the need for deterministic repository-native validation; it is not a general
  automation framework.

## Rejected alternatives

- **Rewriting all evidence paths during document moves.** This preserves path
  identity and repeats the failure mode.
- **Inferring artifact IDs during schema migration.** Migration lacks safe
  repository context and would make rollback and relaunch depend on mutable
  filesystem state.
- **Using filenames or checksums as identity.** They are ambiguous and mutable.
- **Treating catalog presence under v1 as activation.** This silently changes
  existing repositories.
- **Combining Task 4B or Issue #1 with MDCP.** They have separate user outcomes
  and release gates despite shared surfaces.
- **Letting the app write repository documentation.** This violates the
  repository-content boundary and is unnecessary; owner-authorized agents use
  the bounded repository tool.
- **Adding catalog/index filesystem behavior to the agent bridge helper.** The
  bridge carries only the explicit app-owned evidence query/mutations above;
  repository validation and README generation stay in the fixed-purpose tool.
- **Keeping one overloaded status field.** Kind, lifecycle, and authority have
  different semantics and validation rules.

## Approval boundary

This ADR records a proposed M1 architecture. Owner approval accepts the
direction only. It does not authorize implementation, tests, app launch,
installation, storage migration, guidance activation, repository moves,
evidence mutation, Task 4B, Issue #1, Git operations, or external issue
changes.
