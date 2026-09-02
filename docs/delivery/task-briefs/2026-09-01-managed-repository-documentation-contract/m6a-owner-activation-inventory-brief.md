# MDCP M6A Brief: Owner Activation, Migration, and Read-Only Inventory

**Status:** Active operator contract. The owner approved the exact runbook and
metadata quarantine; installation, migration, deployment, handoff, binding,
and relaunch readback are verified. Current closeout status is in the ledger. This
contract remains applicable to preservation/recovery through M8; that lifecycle
status authorizes no later slice. Deliver M6A, then stop for a new session.

## Objective and user-visible outcome

Safely install the exact frozen candidate, migrate owner storage without
identity inference, activate this repository's v2 handoff at unchanged paths,
and produce a complete read-only evidence inventory before any adoption.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-007-proportional-delivery-validation.md`
- Exact accepted replacement `MDCP-COMPAT-2` candidate and unchanged accepted catalog
- Separately owner-approved backup/restore/install runbook

## Scope

In scope only under explicit authorization:

- exact app/helper/plugin identity and process-state preflight;
- consistent owner-store backup and disposable restore proof using existing
  repository-approved facilities;
- installation of the exact frozen candidate and schema migration;
- v2 repository guidance handoff/audit at unchanged catalog paths;
- binding the M4 catalog `repositoryID` through the frozen
  `release_radar_bind_documentation_repository` command using the exact project,
  authorized root-row ID, canonical catalog snapshot/version/digest, and request
  ID;
- supported typed/UI relaunch readback;
- M3B read-only evidence inventory and exact adoption proposal.

Out of scope:

- evidence adoption/relocation, document moves, Task 4B implementation, source
  changes, direct SQLite inspection/editing, or unrelated owner-state mutation.

## Dependencies and release gate

- `MDCP-COMPAT-2` accepted for the bounded M2A reader correction, replacing
  `MDCP-COMPAT-1`; Task 4B cannot substitute a newer candidate.
- Exact owner authorization naming every live action.
- Separately owner-approved backup, restore, installation, and recovery runbook.

## Anticipated files/state

- No application source change.
- Exact v2 `AGENTS.md` managed block and applicable M4 repository catalog/index
  status only through the approved guidance workflow.
- Coordinator-owned `docs/delivery/progress.md` evidence after readback.
- Owner Application Support state only through the app migration.

## Data, security, and privacy

Quiesce the app/helpers, snapshot SQLite main/WAL/SHM consistently, verify a
disposable restore, retain backup through acceptance, and use supported app
readback rather than database queries. The separately approved runbook names an
owner-approved protected backup location, least-readable file permissions,
retention deadline, restoration custody, and separately authorized secure
disposal of both backup and disposable restore. Never record bookmark bytes,
owner paths, evidence content, or backup location in the ledger/audit. Any
identity, signing, schema, catalog, root, process, or snapshot mismatch stops
before mutation.

## Verification strategy

Prove pre/post semantic equality for all legacy evidence and unrelated
delivery/audit/notification state except expected schema metadata, the new
project binding, the exact binding/handoff audit and receipts, and approved
plugin lifecycle state.
Migration first leaves the project unbound; after the v2 handoff, execute the
frozen binding command once and verify exact replay. Relaunch must show schema
available, guidance v2 current, exact root row and accepted catalog snapshot
bound, and every pre-existing evidence row legacy. Inventory itself must
produce zero mutation.

## Recovery behavior

Migration/corruption/unexpected-state failure executes the pre-approved
quiesce/restore/relaunch/readback path. `outcomeUnknown` replays the exact
original request. No second invented request or partial repair is permitted.

## Acceptance criteria

- Exact frozen candidate installed and verified.
- Migration preserves all evidence as legacy and unrelated state.
- v2 is active while physical document paths remain unchanged.
- The exact root-row ID and catalog repository ID/version/digest/snapshot are
  durably bound for later root and catalog continuity.
- Supported readback proves the bound root and accepted snapshot survived
  relaunch; conflict, retry, and recovery use the frozen command contract.
- Read-only inventory identifies exact, ambiguous, arbitrary, and unresolved
  records without mutation.
- No adoption or document move occurs.

## Reviews and completion evidence

Required risk-triggered reviews: QA, Architecture, and Security/Privacy. TPM
participates only if sequencing or dependencies materially change. Planning is
not an approval role. Delivery Management records concise authorization,
migration, recovery, relaunch, readback, and inventory evidence plus residual
risks and next eligible work; it is not an approval. Completion does not
authorize M6B.
