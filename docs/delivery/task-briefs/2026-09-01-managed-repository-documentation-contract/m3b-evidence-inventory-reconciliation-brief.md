# MDCP M3B Brief: Evidence Inventory and Audited Reconciliation

**Status:** Completed. Retained as a non-authoritative record of the delivered
task scope; the original execution instructions below do not reopen work.
Current delivery state and authorization are in [progress.md](../../progress.md).

## Objective and user-visible outcome

Expose a complete project-scoped read-only evidence inventory and bounded typed
commands for exact repository activation, catalog acceptance, managed adoption,
and legacy relocation, with catalog-snapshot binding, transactional audit/
replay, and no unrelated state changes.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-007-proportional-delivery-validation.md`
- Accepted M3A evidence locator/resolver contract

## Scope

In scope:

- read-only inventory query/result for every project evidence record;
- exact candidate/rejection classification and catalog version/digest;
- typed, audited, idempotent activation of an unbound project documentation
  binding from exact authorized root-row ID, `repositoryID`, and canonical
  catalog snapshot/version/digest;
- typed, audited, idempotent acceptance of one candidate catalog transition
  from the persisted prior accepted snapshot at the bound root;
- typed, audited, idempotent managed-adoption request for one bounded complete
  approved set in one transaction;
- first-class managed-evidence creation from artifact ID and expected catalog
  digest;
- separately explicit exact-path legacy relocation request;
- request receipt, stale snapshot, rollback, replay, and outcome-unknown rules;
- managed-v2 importer classification through exact catalog identity; and
- exact additive application query/tool schemas for the supported workflow.

Out of scope:

- automatic migration inference, batch guessing, filename/basename/checksum-only
  identity, root relocation, UI redesign, owner-state execution, repository
  writes, document moves, Task 4B task commands, or generic read APIs.

## Dependencies and release gate

- M3A completed and accepted.
- Separate owner authorization for M3B.

## Anticipated files

- Add focused query/request/result contracts under
  `ReleaseRadarCore/Documentation/`.
- Add a distinct read-only query dispatcher on the existing authenticated
  fixed-purpose application transport.
- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarAgentTools/main.swift` for exact additive tools
  `release_radar_inventory_evidence`,
  `release_radar_bind_documentation_repository`,
  `release_radar_accept_documentation_catalog`,
  `release_radar_add_managed_evidence`,
  `release_radar_adopt_managed_evidence`, and
  `release_radar_relocate_legacy_evidence`
- `ReleaseRadarCore/Import/DeliveryArtifactImporter.swift`
- `ReleaseRadarCore/Import/RekonArtifactImporter.swift`
- Existing bridge, transport, importer, store, and documentation tests

This slice must publish its exact overlap with Task 4B before RED.

## Data, security, and privacy

Inventory requires an authorized project root and is read-only end to end. A
staged v1 inventory may preview candidates while the project remains unbound.
Under managed v2, inventory and every managed operation require the exact bound
root row and snapshot repository ID/version/digest to match the accepted
project binding. Inventory must not create an audit or receipt merely for
reading. Mutations revalidate the exact snapshot before one store transaction,
redact physical paths and bookmark bytes from audit text, validate project
ownership, and preserve ticket associations. No caller accesses SQLite
directly.

The activation command is the sole initially-unbound v2 exception. It requires
the exact project ID, authorized project-root row ID, `repositoryID`, catalog
version/digest, and request ID. It persists the canonical accepted snapshot and
changes only the binding, audit, and receipt; exact replay returns the original
result. A conflicting binding, repository/root identity already owned by
another project, stale root/snapshot, or late failure changes nothing.

The catalog-acceptance command requires the bound root row, expected repository
ID, expected prior version/digest, expected candidate version/digest, and
request ID. It validates the stored canonical prior snapshot against the
current bound-root candidate using M2 transition rules, then atomically replaces
only the accepted snapshot/version/digest plus audit/receipt. Exact replay
returns the original result. Any stale, illegal, unsafe, mismatched, or late-
failure outcome is zero-effect; no managed operation consumes the candidate
until acceptance commits.

Receipts and audits persist stable IDs, digests, request hash, and bounded
outcome fields. They omit bookmark bytes and document content, and avoid
persisting canonical absolute paths or free-form reasons when stable root/evidence
IDs suffice; any path strictly required for exact recovery remains classified
local-sensitive and protected by existing store access/retention boundaries.

## Test-first strategy

RED/GREEN covers exact, ambiguous, arbitrary, missing, symlinked, outside-root,
filename-only, basename-only, checksum-only, stale-digest, and changed-during-
read classifications; zero-effect inventory snapshots; typed validation;
activation success and exact replay; conflicting/missing/mismatched bindings;
wrong/multiple root rows; repository/root cross-project collision; unaccepted
same-repository-ID catalog replacement; accepted legal transition; illegal ID/
lifecycle/path transition; stale prior/candidate digest; request-ID/body
mismatch; injected late rollback; activation/acceptance/adoption relaunch;
outcome-unknown recovery; unrelated tickets/phases/tasks/dependencies/blockers/
goals/reviews/notifications/roots/evidence preservation; new managed-evidence
creation; rejection of catalogued paths through the legacy command under v2;
unconditional legacy-client compatibility for genuinely arbitrary evidence;
and bound/accepted/pending/missing/mismatched v1/v2 importer behavior.

Under v1, Rekon evidence remains legacy and exact behavior is unchanged. Under
managed v2, the exact bound root and accepted catalog must match before one
exact canonical catalog match may create managed evidence; arbitrary/uncertain
evidence remains legacy and a pending/missing/mismatched binding or bad managed
catalog rejects before delivery mutation.

## Happy and non-happy behavior

- Inventory reports enough metadata to prepare an exact reconciliation map
  without mutation.
- Activation binds an unbound project to one repository identity without
  changing the root or evidence and cannot replace an existing binding.
- Catalog acceptance advances only a legal bound-root snapshot transition and
  does not change evidence, root, or delivery state.
- Adoption changes only the locator for named exact evidence plus its audit and
  request receipt.
- Legacy relocation changes only the exact named legacy path plus audit/receipt.
- Managed evidence cannot be path-relocated.
- Stale or unsafe input fails closed and replay is deterministic.

## Acceptance criteria

- No identity is inferred from filename, suffix, or checksum alone.
- Inventory is demonstrably mutation-free.
- Activation and catalog acceptance are exact-root/snapshot-bound, audited,
  idempotent, transactional, replay-safe, persistent across relaunch, and
  rollback-safe.
- Every managed resolution, inventory, creation, adoption, and managed-v2
  importer path enforces the exact bound root and accepted repository ID/
  version/digest match.
- Adoption is catalog-digest-bound, transactional, audited, and replay-safe.
- New managed evidence has a first-class artifact-ID command; the existing path
  command remains backward compatible for non-catalogued evidence and never
  silently creates legacy identity for a catalogued v2 path.
- Rekon/catalog/generated-index behavior follows ADR-006 exactly.
- Existing `addEvidence` legacy clients remain backward compatible for
  genuinely non-catalogued paths.

## Reviews and completion evidence

Required risk-triggered reviews: Code Review, QA, Architecture, and
Security/Privacy. TPM participates only if sequencing or dependencies materially
change. Planning is not an approval role. Delivery Management records concise
contract, test, rollback/replay, and Task 4B-overlap evidence plus residual
risks and next eligible work; it is not an approval. Completion does not
authorize M3C.
