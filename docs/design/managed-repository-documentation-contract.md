# Release Radar Managed Repository Documentation Contract

- Status: M1 package independently reviewed; owner approval pending
- Date: 2026-09-01
- Program: MDCP
- Planning base: `653cdfd647590bfefbb23b556d48bd5970846a97`
- Architecture: `docs/architecture/ADR-006-managed-repository-documentation-contract.md`

## Decision summary

Release Radar will own one opt-in contract for how a tracked repository
identifies, indexes, governs, and safely relocates durable documentation. The
repository remains the source of document content. Release Radar owns the
contract definition, safe inspection, evidence identity, and audited adoption
workflow; it does not turn repository Markdown into delivery-state authority.

The durable direction is:

1. a versioned `docs/catalog.json` identifies every eligible durable artifact
   by stable artifact ID and current canonical path;
2. deterministic catalog-driven indexes make authority and lifecycle visible
   without broad repository search;
3. Release Radar centralizes recognized repository paths and managed-guidance
   behavior in one Core-owned contract;
4. managed documentation evidence uses artifact identity while arbitrary
   evidence retains the bounded legacy path locator;
5. automatic storage migration preserves every existing evidence row as
   legacy and performs no repository inference;
6. a read-only inventory precedes any exact, typed, audited adoption;
7. guidance v2 activates the managed-documentation contract only after the
   complete compatibility candidate is accepted; and
8. this repository moves documents only after that contract is live and its
   managed evidence has been adopted.

This program fixes documentation lifecycle and application coupling together.
It does not make the catalog a dashboard manifest, infer delivery state from
files, or authorize Release Radar to edit repository files autonomously.

## Intended outcome

After M8, a new agent can start at `docs/README.md`, follow generated local
indexes, identify the one current controller for a decision or delivery role,
load only task-relevant material, and close or move a document without losing
Release Radar evidence identity. Missing, malformed, unsafe, superseded, or
archived artifacts remain truthful and recoverable rather than silently
becoming current authority.

The terminal acceptance criterion is:

> Future document moves, lifecycle changes, and application references cannot
> silently drift, lose identity, invalidate evidence, inflate agent context, or
> force another manual repository-wide repair.

## Scope boundaries

In scope:

- documentation identity, authority, lifecycle, indexes, links, and checksums;
- Release Radar guidance v2 for managed repository documentation;
- centralized repository-document paths and exact bundled-copy agreement;
- safe catalog parsing, validation, index rendering, and check mode;
- additive legacy/managed evidence identity, inventory, adoption, explicit
  legacy relocation, resolution, projection, and readback;
- explicit repository-root rebinding with fresh authorization;
- this repository's later catalog bootstrap, evidence adoption, document
  cutover, archive repair, `progress.md` compaction, and closeout; and
- focused compatibility, persistence, failure, relaunch, and UI verification.

Out of scope:

- Task 4B implementation or command exposure;
- GitHub Issue #1 implementation, generic Ticket Tasks onboarding, or guidance
  v3;
- delivery-state inference or mutation from catalog contents;
- application-authored repository edits or recurring filesystem sync;
- a portable project exporter/archive revision;
- direct SQLite access, arbitrary path repair, filename-only identity
  inference, or unaudited owner-state mutation;
- product work unrelated to repository-document compatibility; and
- M2 or later work during this M0-M1 planning session.

## M0: isolated and attributable baseline

M0 established the following facts before any repository write:

- Worktree root and Git top level both resolved to
  `/Users/jroberts/.codex/worktrees/b0f1/release_radar`.
- The active branch was
  `codex/managed-documentation-contract-planning`.
- `HEAD` was exactly
  `653cdfd647590bfefbb23b556d48bd5970846a97` and the worktree was clean.
- That commit is the accepted post-Task-4A documentation closeout based on
  completed implementation checkpoint
  `910b9653b661c6088d025bc6f6aea71271cff3b0`.
- No original-checkout content or uncommitted state was imported.
- No application, test, owner data, storage, guidance, document, evidence, or
  external issue mutation occurred.

### Issue #2 owner disposition

The owner accepted the exact current versions of these three files at
checkpoint `653cdfd` as operative RR-R10 output:

- `docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json` —
  SHA-256
  `95bfa880903408d20ef7fbaaa8051ef6a2908a45d2ada9f6d01e8ba9d89cdea5`;
- `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md`
  — SHA-256
  `711abe4edee9ac86951e9e41c40170f9fbb67123e2f44216e0203cec85595292`;
  and
- `docs/delivery/task-briefs/SHA256SUMS` — checkpoint SHA-256
  `7205890306b278548d09a67320e2ff6d9b04a0104980a4ca4410a3410229da6d`.

Their session-level authorship remains **unknown**. Acceptance neither infers
authorship nor retroactively approves changes made after the preservation hold
opened. The attribution incident remains historical evidence. The owner
directed that the accepted artifacts not be investigated, replaced,
regenerated, or rewritten merely to resolve Issue #2. The preservation hold is
resolved. The external GitHub issue remains open and unmodified.

M1 may append checksums for its newly authorized briefs to the shared checksum
manifest; it must preserve all accepted RR-R10 entries. The checkpoint hash
above remains the attribution incident's immutable baseline.

### Issue #1, Task 4B, and program priority

These are separate work items:

- **Task 4B** is the bounded RR-R10 task that exposes the already designed,
  audited Ticket Task plan commands.
- **GitHub Issue #1** is a later generic Ticket Tasks onboarding/adoption
  workflow and owns guidance v3.
- **MDCP** owns the managed repository-document contract, guidance v2, and
  evidence compatibility described here.

MDCP has priority after M1. Task 4B remains eligible but unopened until the
`MDCP-COMPAT-1` checkpoint below is accepted. Issue #1 remains open externally
but unopened for implementation until MDCP terminal acceptance and separate
owner authorization. None is merged into another feature.

## Catalog v1 contract

`docs/catalog.json` is repository contract metadata. It is not substantive
document content and is the only regular file under `docs/` excluded from its
own artifact inventory. Every other eligible regular file or durable asset
under `docs/`, including README indexes and checksum manifests, must have one
entry. Hidden OS files, editor backups, build output, and temporary inventories
are prohibited rather than silently ignored. Any future exclusion must be a
narrow, versioned contract rule with a test.

The catalog has one immutable `repositoryID`. Schema v13 persists a one-to-one
project documentation binding containing the project ID, exact bound project-
root row ID, `repositoryID`, and canonical accepted catalog snapshot with its
version/digest. Legacy projects migrate unbound. A repository ID and bound root
row may each belong to only one project documentation binding, and an existing
binding cannot be replaced by presenting another otherwise-valid catalog.

Release Radar creates the binding only through an explicit typed, audited,
idempotent activation request that names the exact authorized root row and
expected catalog version/digest. Exact replay returns the original result;
conflict or late failure leaves the project, binding, audit, and receipt
unchanged. Every managed resolution, inventory, creation, adoption, managed-v2
import, and root rebind requires that exact bound root row and requires the
current catalog `repositoryID`, version, and digest to equal the accepted
binding. A missing or mismatched binding fails closed, including when another
catalog with the same repository ID is placed at the same root.

Catalog change is an explicit trust transition, not an implicit filesystem
event. `release_radar_accept_documentation_catalog` consumes the persisted
accepted snapshot and the candidate at the bound root, validates their exact
prior/candidate digests and every legal identity/lifecycle/path transition, and
atomically replaces only the accepted snapshot/version/digest plus its audit
and receipt. Exact replay is idempotent; an invalid transition, stale digest,
root mismatch, or late failure changes nothing. Until acceptance, all managed
operations report a pending/unaccepted catalog and cannot reinterpret artifact
IDs or paths.

Catalog fields are orthogonal:

- `artifactID`: immutable repository-scoped document identity;
- `path`: normalized root-relative canonical path under `docs/`;
- `kind`: document, collection index, design asset, verification evidence, or
  checksum manifest;
- `lifecycle`: proposed, active, completed, superseded, or archived;
- `authorityLevel`: controlling, supporting, or non-authoritative;
- `authorityRole`: stable role key required for controlling artifacts;
- `parentCollection`: stable collection ID that owns navigation for the
  artifact;
- `supersedes`: zero or more replaced artifact IDs;
- `applicationSensitivity`: a bounded set such as guidance, importer,
  evidence, prompt, fixture, or none; and
- `checksum`: required manifest reference or explicit not-applicable policy.

Every documentation directory also has deterministic collection metadata: a
stable collection ID, normalized path, parent collection, purpose,
allowed/prohibited contents, first-read artifact when applicable, index
artifact ID or explicit leaf declaration, and optional archive destination.
Generated indexes consume only catalog artifact and collection data; they do
not parse human prose as configuration.

Only an active artifact may be controlling. At most one active artifact may
control an authority role. Evidence is a kind, not a lifecycle. Archived
content is non-authoritative regardless of words such as "current" or
"canonical" preserved in its historical narrative.

Artifact IDs never change when paths change and are never reused. IDs are not
derived from paths, filenames, hashes, or content. A replacement receives its
own ID and lists the artifact it supersedes. A move retains the existing ID.
An exceptionally authorized deletion adds its ID to permanent
`retiredArtifactIDs`; prior/current validation rejects reuse.

## Lifecycle and transition validation

Catalog validation checks both the current snapshot and, for a change, an
explicit prior accepted catalog. A current snapshot alone cannot prove a legal
transition or distinguish deletion from omission.

Normal transitions are:

- proposed to active;
- active controlling to superseded, with an explicit replacement link;
- active delivery artifact to completed; and
- completed to archived.

Archival placement never grants authority. Restoring archived material to an
active controlling role requires an explicit owner restoration decision, a
current-path move or new replacement artifact, and validation against the
prior catalog. The normal validator rejects:

- two active controllers for one authority role;
- removal of an active controlling artifact;
- a controlling-to-superseded change without a current replacement;
- a path move without the catalog path changing in the same repository
  change;
- active references that route current execution through archived artifacts;
- closeout without the applicable completed/archive status and destination;
  and
- any unsupported old/new lifecycle pair.

## Index contract

The repository documentation tool renders deterministic managed sections in
`docs/README.md` and every indexed subdirectory README. It preserves
human-authored text outside exact managed markers and provides a check-only
mode that makes no writes.

Each managed section is rendered from catalog collection and artifact metadata
and states:

- directory purpose and allowed contents;
- the first artifact to read;
- every child artifact's ID, path, authority, and lifecycle;
- controllers and supersession relationships;
- archive destination or historical boundary; and
- child-index navigation or an explicit leaf declaration.

Generation is stable regardless of JSON member order or filesystem enumeration
order. Validation rejects missing files, uncatalogued eligible files, duplicate
IDs or paths, unsafe paths or file types, invalid authority or lifecycle,
stale generated sections, broken applicable links, checksum disagreement, and
catalog changes during a read. Generation must leave all repository bytes
unchanged when any validation step fails.

## Application-owned repository-document contract

One Core-owned definition will name and version:

- root `AGENTS.md` guidance;
- `docs/catalog.json`;
- `docs/README.md`;
- `docs/delivery/progress.md`;
- the recognized Rekon seed artifact;
- task-brief, handoff, review, evidence, plan, and archive collections;
- managed index markers;
- catalog and guidance versions; and
- bounded path and file-count limits.

Swift consumers use that definition directly. Bundled Markdown, plugin files,
and owner-facing prompt text that cannot import Swift constants retain literal
text only behind exact-agreement tests. M2-M5 remove duplicated literals where
possible without altering legacy behavior.

The separate repository documentation executable owns catalog/index checking
and owner-authorized README generation; it never enters the application bridge.
Application evidence uses the existing authenticated fixed-purpose transport
with a distinct read-only query dispatcher and additive typed tools:

- `release_radar_inventory_evidence` performs the mutation-free query;
- `release_radar_bind_documentation_repository` atomically binds an unbound
  project to the exact authorized catalog snapshot;
- `release_radar_accept_documentation_catalog` atomically advances the bound
  project's accepted catalog through one validated transition;
- `release_radar_add_managed_evidence` creates new artifact-ID evidence;
- `release_radar_adopt_managed_evidence` atomically adopts one bounded complete
  approved set; and
- `release_radar_relocate_legacy_evidence` updates only exact named arbitrary
  legacy path evidence.

The existing `release_radar_add_evidence` remains the backward-compatible
arbitrary-path command. M3B fixes exact request/result fields and bounds before
RED. All six additive surfaces are part of the shared contract frozen before
Task 4B refresh.

## Documentation modes

Release Radar presents one coherent documentation mode:

1. **Legacy v1** — current guidance behavior; no catalog is required.
2. **Staged catalog under v1** — valid catalog v1 may be inspected and
   validated read-only, but cannot change import identity, evidence identity,
   availability, or delivery state.
3. **Managed v2** — exact guidance v2 plus a valid compatible catalog v1;
   managed operations and artifact identity are enabled.
4. **Managed unavailable** — guidance v2 is readable, but its catalog is
   missing, malformed, unsupported, unsafe, checksum-invalid, or unstable, or
   the project binding/root is missing or mismatched, or the current catalog is
   not the exact accepted digest; managed operations fail closed and explain
   recovery. The explicit activation command may bind an unbound project, and
   the explicit catalog-acceptance command may validate and advance a bound
   project from its prior accepted snapshot.

This is not an independent guidance/catalog feature matrix. Guidance v3 is
reserved for Issue #1 and is unsupported by this program.

Guidance v2 makes Release Radar responsible for the reusable agent operating
contract. Its exact managed block and bundled skill require agents to:

- begin documentation discovery at `docs/README.md` and follow generated local
  indexes before broad search;
- load only task-relevant controlling artifacts;
- update the catalog, collection/index metadata, active references, and
  applicable checksums in the same change as any durable add, move, rename,
  supersession, closeout, restoration, or deletion;
- keep active operational detail in `docs/delivery/progress.md` and move closed
  detail to the historical archive;
- add no new content under `docs/superpowers/` during transition and never
  recreate it after cutover;
- never repair a managed evidence path directly or edit SQLite;
- use supported inventory, catalog-acceptance, and typed audited evidence
  workflows; treat a changed repository catalog as pending until Release Radar
  accepts its validated transition; and
- refuse completion while catalog, indexes, lifecycle, authority, references,
  checksums, evidence resolution, or application readback disagree.

Repository-local instructions may add narrower project rules outside the
managed block. They cannot weaken or duplicate the versioned v2 contract.

## Evidence identity and adoption

Evidence has one exhaustive locator:

- `managedDocument(artifactID)` for catalogued documents; or
- `filePath(path)` for arbitrary or legacy evidence.

Persistence enforces exactly one locator. Managed paths are resolution and
presentation data, never identity or uniqueness. Legacy path evidence retains
its existing bounded behavior.

The additive schema migration runs before reliable repository authorization.
It therefore:

- adds locator capability;
- adds an empty project-documentation binding relation with database-enforced
  one-project/one-repository/one-bound-root identity uniqueness and an accepted
  canonical catalog snapshot/version/digest;
- preserves every evidence ID, project/ticket association, path, availability,
  audit, and unrelated record;
- marks every pre-existing evidence row as legacy path evidence; and
- performs no filesystem read, catalog lookup, filename match, checksum match,
  or identity inference.

Activation and adoption are separate and later. Under v1, catalog preview and
candidate inventory remain read-only and unbound. Managed v2 first uses
`release_radar_bind_documentation_repository` to bind an unbound project to
its exact authorized root row, `repositoryID`, and accepted canonical catalog
snapshot/version/digest in one store-owned audit/receipt transaction. It never
changes the project root or evidence. Exact replay is idempotent; a different
existing binding or any late failure rolls back completely.

After binding, a read-only inventory classifies exact candidates without
repository, database, audit, receipt, notification, or delivery-state
mutation. A managed adoption request requires the expected catalog
version/digest, exact evidence ID, exact prior path, and exact artifact ID. The
app revalidates the bound root row and exact accepted repository ID/version/
digest immediately before one store-owned, audited, idempotent
transaction. Ambiguous, missing, symlinked, outside-root, filename-only,
basename-only, or checksum-only candidates remain legacy.

Managed v2 also provides a first-class typed command for new managed evidence.
It accepts an artifact ID and expected catalog digest, resolves through the
authorized snapshot, and commits the evidence, audit, and request receipt in
one transaction. The existing path-based `addEvidence` contract remains
backward compatible for genuinely non-catalogued evidence. Under v2, an exact
catalogued path submitted to that legacy command rejects with actionable
recovery directing the caller to managed evidence creation; it may not silently
recreate path identity.

Under legacy v1, the Rekon schema-v1 importer remains path-based and unchanged.
Under managed v2, the importer may create managed evidence only when the exact
bound root and accepted project catalog match the valid current catalog and it
supplies one exact canonical artifact match; otherwise the record remains
legacy or the managed operation fails as specified by the brief. It never
treats `docs/catalog.json` or generated indexes as seed delivery authority.

## Resolution, availability, and authority

Managed evidence resolves through the exact bound project-root row and the
current catalog path only after the snapshot repository ID/version/digest
matches the accepted binding. Resolution uses no-follow, bounded reads and rejects
absolute paths, dot-segment traversal, symlinked roots/intermediates/finals,
non-regular files, root escape, checksum mismatch, and catalog mutation during
the read.

UI and public readback keep file availability separate from lifecycle and
authority. At minimum they distinguish:

- available and current;
- available but completed, superseded, or archived;
- missing artifact;
- invalid, unavailable, pending, or unaccepted catalog;
- unauthorized, stale, or non-bound root; and
- checksum mismatch.

Historical evidence may be available and useful while remaining ineligible to
control current work.

## Repository-root relocation

The current same-root reauthorization behavior is not relocation. Managed v2
adds an explicit owner-confirmed, typed, audited root-rebind operation. It
validates a newly selected canonical root and fresh security-scoped bookmark,
requires the exact accepted catalog repository ID/version/digest already bound
to the Release Radar project, rejects a root owned by another project, and
preserves the project ID.

The one transaction may change only the project root row, its bookmark row, the
binding's exact root-row association,
and—when exactly one existing legacy handoff evidence record identifies the old
root `AGENTS.md`—that record's path to the new root `AGENTS.md`, plus the scoped
audit and receipt. Zero matching old-root handoff rows permits rebind without
an evidence update. Exactly one matching row updates in the same transaction.
Multiple, ambiguous, or mismatched rows reject the entire rebind with zero
root, bookmark, evidence, audit, or receipt change. Managed evidence and every
other legacy evidence row remain unchanged. The old bound bookmark is revoked
and the old root can no longer satisfy managed operations; unrelated unbound
root rows remain ineligible. No partial rebind or prefix rewrite is allowed.

## Milestones and release gates

### M1 — durable planning package

This document, ADR-006, the M2-M8 briefs, checksum entries, and the delivery
ledger are the complete M1 inventory. M1 approval authorizes neither M2 nor
Task 4B.

### M2 — repository contract foundation

- M2A: catalog contract, snapshot, parser, and validator.
- M2B: deterministic repository documentation tool and check mode.
- M2C: centralized application path contract and read-only v1 catalog preview.

### M3 — application compatibility foundation

- M3A0: immutable checksummed schema-v12 migration fixture.
- M3A: additive evidence locator and accepted-snapshot/root-bound project
  repository-binding schema/models/resolver.
- M3B: typed repository activation/catalog acceptance, read-only inventory,
  audited exact reconciliation, and importer compatibility.
- M3C: projection/UI readback and explicit root relocation.

### M4 — stage this repository in place

Catalog and index the current tree without moving documents, activating v2, or
adopting evidence. M4 uses one tested transitional exception: `docs/README.md`
directly enumerates the existing `docs/superpowers/` subtree, its `plans/` and
`specs/` leaf collections, and every contained artifact without adding a file
there. The exception permits no new content and expires in M7.

### M5 — freeze the v2 compatibility candidate

Make guidance v2 current in the exact application/bundled candidate while all
repository document paths remain unchanged. Complete exact contract and
failure tests, including real-tree catalog/index conformance in the normal
repository test/check workflow. Do not install the candidate, mutate owner
state, adopt evidence, or move documents.

### `MDCP-COMPAT-1`

Task 4B becomes eligible for a separate planning refresh and owner
authorization only after every M2-M5 brief is implemented, independently
accepted with zero required findings, and recorded at one exact attributable
clean checkpoint. That checkpoint freezes:

- command/query envelopes and result JSON;
- evidence and root-bound accepted-catalog schema, activation/transition,
  resolver, inventory, reconciliation, and root-rebind contracts;
- importer behavior;
- guidance v1/v2 semantics and bundled-skill content;
- exact tool names and schemas; and
- overlapping fixtures and acceptance tests.

Task 4B does not open automatically. Its existing 13-tool and shared-file
baselines must be refreshed against `MDCP-COMPAT-1` without absorbing MDCP
behavior.

M6-M8 consume the frozen candidate and may not reopen a frozen source or test
contract. If they expose such a need, both programs stop; MDCP reopens only the
affected M2/M3/M5 slice, receives affected-role review, replaces
`MDCP-COMPAT-1`, and Task 4B refreshes again before resuming. Ledger writes are
serialized even when implementation files do not overlap.

### M6 — owner-authorized activation and adoption

- M6A: exact candidate install, storage migration, v2 repository handoff,
  typed root-row repository binding, relaunch readback, and read-only inventory
  under a separately approved backup/recovery runbook.
- M6B: one catalog-digest-bound atomic reconciliation of the complete approved
  managed-adoption set.

Uncertain and arbitrary evidence remains legacy. M6 requires separate owner
authorization for every application and repository mutation.

### M7 — catalog-driven repository cutover

Before the repository-only M7 slice opens, prepare the exact move map, then use
a separately authorized live preflight outside that slice. First quiesce the
app and every mutation-capable client/helper, leaving only the authenticated
read-only M3B query path for one authoritative inventory against the frozen
map. Close that query path after it returns and keep all writers quiesced
through M7. The map/inventory digests and quiescence proof form the release
token. Every evidence row targeting a moved file must already be managed;
otherwise that file is removed from the move set pending a separately
authorized exact legacy relocation and a new token. The preflight mutates no
owner data, and M7 itself does not launch or access the app.

Before the first move, record an exact clean pre-M7 Git checkpoint and validate
both the complete old and proposed new catalog/tree candidates. Any changed
move map, failed/uncertain preflight, or paused or aborted cutover invalidates
the M7 continuation token. Preserve the partial state and keep writers
quiesced. Recovery is phase-specific:

- Restoring the exact old accepted candidate requires validator-clean proof,
  then a separately authorized fresh inventory/token before retrying M7 or
  resuming live use on the old state.
- Forward-completing the exact new pending candidate is permitted only if
  writer quiescence was never lost. After validator-clean proof it remains
  quiesced and proceeds directly to separately authorized M8 catalog acceptance;
  managed inventory cannot run while the old digest remains accepted.
- If any writer resumes or evidence-state quiescence is uncertain, forward
  completion is prohibited. Restore the exact old candidate, validate it, and
  obtain a fresh inventory/token.

Never inventory a partial, invalid, or unaccepted candidate as if it were
authoritative.

After the release gate is satisfied, move documents, update catalog paths,
generate indexes, repair active links and checksums, compact `progress.md`,
establish archive boundaries and lifecycle rules, and remove active
`docs/superpowers/` dependencies. Managed evidence rows are not path-rewritten.
Successful M7 does not release live use: mutation-capable clients remain
quiesced until M8 performs the controlled post-cutover catalog-transition
mutation, then read-only application readback, and records an explicit owner
release decision. The app binding remains on the old accepted digest throughout
M7; the exact validator-clean new catalog is only a pending candidate.

### M8 — runtime acceptance and closeout

While mutation-capable clients remain quiesced, validate the exact new catalog
against the stored prior accepted snapshot and execute the separately
authorized typed catalog-acceptance command. Then prove controlled application
resolution/readback, relaunch, root relocation,
import/onboarding/guidance compatibility, UI truthfulness, and unrelated-state
preservation. Before catalog acceptance commits, recovery follows the M7
phase-specific old-restore or continuously-quiesced new-forward branch. If
the acceptance outcome is unknown, keep repository state and writers quiesced,
replay the exact original request/receipt, and use supported binding readback to
establish which digest committed before selecting any recovery branch. If
acceptance commits but a later check fails, keep the new repository candidate
and writers quiesced; do not invoke the old-restore branch or silently roll the
accepted snapshot backward. A repository-only defect then uses a separately
authorized forward M7/M8 correction: derive and validate a corrected candidate
from the new accepted snapshot, apply it under quiescence, and accept that next
transition. Only an actual frozen-contract defect reopens M2/M3/M5 and replaces
`MDCP-COMPAT-1`. Release live use
only through an explicit owner decision after post-cutover readback succeeds.
Record the terminal current state and next eligible work.

## Program-wide execution rules

- One brief is opened at a time after dependency-safe release and explicit
  owner authorization.
- Every behavior change starts with the brief's attributable RED and uses the
  repository's existing XCTest and fixture patterns.
- Application source and live repository/state changes never share a slice.
- Catalog staging precedes v2 activation; v2 activation precedes evidence
  adoption; evidence adoption precedes document movement.
- No direct SQLite access, filename-only inference, silent prefix rewrite, or
  delivery-state mutation is permitted.
- Every mutating request is typed, project-scoped, audited, idempotent, and
  bound to the exact inspected catalog snapshot.
- Replay receipts prefer stable IDs, digests, and request hashes; bookmark
  bytes, content, and unnecessary absolute paths/free-form reasons are omitted
  from durable audit, receipt, log, and UI surfaces.
- Missing or malformed managed documentation produces truthful, recoverable,
  read-only failure and no unrelated mutation.
- Human historical narratives remain intact; current indexes and archive maps
  explain moved paths.
- The Release Radar-managed `AGENTS.md` block changes only through its exact
  versioned guidance workflow. M7 operating rules are placed outside that block
  unless guidance v2 explicitly owns them.
- Completion requires repository validation, focused application evidence,
  supported readback, and the progress ledger to agree.

## Review and approval state

Planning, Architecture, TPM, QA, Delivery Management, and Security/Privacy each
reviewed the exact substantive M1 package and returned GO with Required 0,
Optional 0, and Out of scope 0. The resulting status-only ledger update records
those verdicts; owner approval remains pending.

Owner approval of M1 accepts this planning direction only. M2, Task 4B, app
launch, tests, storage migration, guidance activation, document movement,
evidence mutation, Git commit/push, and external issue changes each remain
separately authorization-gated.
