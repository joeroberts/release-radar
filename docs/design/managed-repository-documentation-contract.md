# Release Radar Managed Repository Documentation Contract

- Status: Active product contract; MDCP M1-M8 delivered; later amendments retain
  their own stated approval and implementation boundaries
- Date: 2026-09-01
- Program: MDCP
- Planning base: `653cdfd647590bfefbb23b556d48bd5970846a97`
- Architecture: `docs/architecture/ADR-006-managed-repository-documentation-contract.md`

This mutable design is the current product specification for managed repository
documentation. The accepted ADR records the architecture decision and remains
unchanged; this file owns current implementation detail. Completed MDCP
milestones are not instructions to repeat delivery work. Current work is
recorded in GitHub and the short `docs/delivery/progress.md` snapshot.

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

## Catalog v1 contract

### C8 compatibility decision — discovery exclusion v1

Selected for the owner-authorized C8 source-repair pilot on 2026-09-06. This
section amends only the blanket metadata prohibition in the original v1
inventory paragraph below. It records the source-delivery rule, not implemented
behavior, independent acceptance, installation, or application catalog acceptance.
Other proposed contracts in the
[full-product plan](../delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
remain proposed.

Keep catalog schema version **1**, guidance version **2**, index markers and
canonical catalog encoding/digest unchanged. Add the separately named Core
constant `RepositoryDocumentContract.discoveryExclusionVersion = 1` for this
first exclusion rule; mirror that version and rule in the shipped
`ReleaseRadarDocumentationTool/catalog-v1.md` reference with exact-agreement
coverage. This is a reader capability revision, not a repository-selectable
ignore setting or a new catalog field. No schema bump, capability negotiation,
database migration, or accepted-snapshot rewrite is needed.

During discovery under `docs/`, exclude only an exact, case-sensitive
`.DS_Store` basename whose descriptor-relative, no-follow metadata identifies
an ordinary regular file. Check type before exclusion; never open or read its
contents. Apply this at the docs root and within otherwise valid collections.
Same-named directories, symlinks and other non-regular entries reject. Keep
catalog path validation prohibitive: an artifact or collection entry naming
excluded metadata rejects, so it cannot acquire managed evidence identity.
Other hidden files, backups, prohibited ancestors, build output, unsafe paths
and unregistered documents retain their existing rejection rules. Git ignore
rules do not participate.

Metadata-only creation, content changes or removal between stable validations
must leave document/collection inventory, generated indexes and catalog digest
unchanged. Preserve bounded enumeration, root/ancestor containment, no-follow
opens, directory identity checks, document stamps, links, checksums and catalog
stability checks. Directory-entry comparisons used by index-write stability
verification must apply the same type-checked exclusion, including when the
writer has staged its own temporary entries; a name-only filter is unsafe.
Concurrent filesystem changes may still fail conservatively with
`changedDuringRead` and require a fresh read. C8 does not authorize dropping
stability checks to suppress such failures or masking real-document changes.

Current consumers are the shared Core validator; documentation-tool check and
index generation; app catalog preview, binding and acceptance; and managed
evidence inventory, resolution, creation/adoption, import and root rebind.
They consume one rule through Core, with no independent app/checker whitelist.
The Phase 3A C8 freshness candidate and its contextual C12 health/recovery
presentation distinguish this reader capability from
valid/current/accepted/bound state. C10/C11 portability
and P17 code-revision evidence retain repository/artifact identity and explicit
provenance: the catalog digest is not a reader-version, code-revision or installed
binary attestation. These consumers are compatibility constraints, not new C8
implementation work.

Older installed validators retain the original prohibition and reject even
ordinary `.DS_Store` files. They can still validate an otherwise compatible v1
tree without that metadata. A new source checker passing does not prove the
installed app/helper has the new rule. Installation remains separately
authorized; verify the installed reader and bundled checker against the
canonical tree with metadata retained. Report real catalog, authorization and
binding failures separately. Do not delete metadata, rebind, accept catalogs,
reconstruct audits or rewrite evidence as recovery for an older validator.
Reverting to an older binary may restore this rejection but requires no data
migration; preserve existing IDs, snapshots and receipts. Actual catalog
changes still require their existing explicit acceptance transition.

Minimum source delivery updates are the shared contract constant, reader
discovery and affected stability comparisons, the shipped catalog reference,
and focused existing reader/validator/index and reference-agreement tests.
Retain catalog-registration rejection in the validator. Verify root/nested
metadata invariance, unsafe same-name entries, prohibited/unregistered content
and actual index generation, alongside existing containment and change-during-
read checks. No new persistence, command surface, observation service or broad
design reconciliation is part of this decision.

### Original v1 inventory and identity rules

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

The later catalog-transition diagnostic is an additive read-only compatibility
surface. `release_radar_documentation_catalog_transition` requires the exact
authorized project root, project ID and root-row ID, compares only the persisted
accepted snapshot with the validated current catalog, and returns bounded
accepted/candidate identities plus the validator's exact rejection code and safe
affected artifact ID/path when available. It exports no catalog snapshot and
creates no receipt, audit, acceptance, repository or delivery-state change.
Malformed catalogs, stale roots and identity mismatches retain their existing
fail-closed errors. The acceptance command keeps the same rejection semantics but
returns this diagnostic alongside `invalidTransition`; Documentation activation
shows the code, safe artifact context, repair direction and an explicit statement
that accepted state did not change.

## Documentation modes

Release Radar presents one coherent documentation mode:

1. **Legacy v1** — current guidance behavior; no catalog is required.
2. **Staged catalog under v1** — valid catalog v1 may be inspected and
   validated read-only, but cannot change import identity, evidence identity,
   availability, or delivery state. For current Outcome 3 onboarding, only an
   exact shipped staging v1 guidance block additionally permits the initial
   explicit repository-binding command. That command accepts the exact authorized
   root/catalog snapshot in its normal audited, idempotent transaction; it does
   not activate managed guidance or enable any other managed operation.
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
candidate inventory remain read-only and never imply a binding. Current Outcome 3
onboarding separately permits initial binding with the exact shipped staging v1
block and validated catalog, before the separately authorized audited guidance
upgrade. Missing, modified or malformed staging guidance does not permit binding.
All existing target, folder authorization, registration, conflict, audit, replay and
rollback checks remain; catalog acceptance and other managed operations retain
their managed-guidance gates. Existing managed v2 activation uses
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

## Phase 3A runtime observation contract

The Phase 3A source candidate adds one shared, in-memory documentation observation
for Overview, evidence, and documentation health. Its identity is the exact project
registration and request generation, root row and canonical path, and optional
accepted binding. Its result carries a local observation generation and check time.
Starting a refresh withdraws prior success; concurrent requests coalesce, and a
result from an invalidated identity, service graph, lifecycle, or older generation
cannot publish.

The active-project observer rechecks after dashboard load/reopening, app activation,
authorized recovery, and relevant nested filesystem changes. Archive, removal, and
service replacement terminate monitoring and withdraw the observation. Observation
uses the existing bookmark and bounded no-follow readers but does not persist
availability, mark bookmark state, audit, accept catalogs, or infer delivery state.

Same-folder recovery is deliberately narrower than relocation. The native picker
accepts one existing folder. Commit requires an exact canonical-path match and
rechecks the captured registration, root row, persisted path, binding, lifecycle,
and store graph before replacing only the bookmark in an audited transaction.
Catalog validation follows renewal, so invalid or pending catalogs remain visibly
invalid or pending. Repository relocation retains its separate accepted-catalog
workflow.

Phase 3A signed native verification established that the accessibility action
opens the shared picker and that cancellation is non-mutating. Successful signed selection through
real sandbox authorization to bookmark renewal remains an outstanding Phase 3
verification gap; synthetic integration tests cover the renewal contract itself.

## Evidence preview limits and access

Evidence previews are transient, read-only views of authorized content. Previewing
never updates evidence, catalog acceptance, audit records or delivery state.

- The preview payload is limited to **1 MiB (1,048,576 bytes)**. Larger payloads
  report `oversized` and expose no preview content.
- Text must be valid UTF-8. Display at most **131,072 characters**, with truncation
  explicitly labelled. HTML and SVG are displayed as inert source text; previews
  execute no scripts and load no remote resources.
- Supported raster formats are PNG, JPEG, GIF, WebP and TIFF. An image must contain
  exactly one image/frame, have positive dimensions no greater than **4,096 pixels
  per dimension**, and contain no more than **16,000,000 decoded pixels**.
  Malformed or out-of-bounds images are rejected; unsupported formats are explicit.
- Managed previews revalidate the exact accepted binding and current catalog before
  descriptor-relative, no-follow reads. Legacy paths must resolve within an
  existing authorized primary or worktree root for the same project.
- Missing, oversized, inaccessible and rejected sources remain distinct. Recovery
  preserves the authorizing root: restore primary-folder access, reconnect the
  exact saved worktree, or explicitly relocate legacy evidence outside saved grants.
- Selection, observation, root, registration or service invalidation withdraws
  displayed content and rejects late read results. Preview bytes are not a
  persistent copy or a new source of authority.

These are the existing limits implemented by `EvidencePreviewReader` and its
preview consumers; recording them here does not change product behavior.

## Mutation and failure guarantees

Managed mutations are typed, project-scoped, audited, idempotent and bound to
the exact inspected catalog snapshot. Replay receipts use stable IDs, digests
and request hashes; omit bookmark bytes, document content and unnecessary
absolute paths or free-form reasons from audit, receipt, log and UI surfaces.
Missing or malformed documentation yields a recoverable, read-only failure
without unrelated mutation. The app remains the only SQLite writer; filename
inference and silent evidence-path rewrites cannot establish authority.

## Phase 5B source revision and readback extension — 2026-09-09

The later owner-approved Phase 5B links use exact content revisions independently
of catalog snapshots. A bounded authorized full-byte read and stability check
produces the source digest; preview truncation never defines that revision. A
supplied source-local identifier is preserved, while headings/lines remain
locators. No copied prose or derived heading becomes requirement authority.

Recorded source metadata and current resolution are presented separately. Denied,
pending, missing, unsafe or unstable access remains explicit, and late callbacks
cannot republish content after context changes. Historical content is shown only
when safely resolved bytes match the linked digest. Scoped link/history/reverse
queries report incomplete results honestly and never mutate app or repository
state.

Each logical ticket link has stable identity and a ticket-local link-set revision.
New or revised authoritative links require current registration, exact bound root,
fresh authorized access, managed-v2 mode, the accepted repository/catalog identity,
an active controlling source, and revalidation of both expected content digest and
catalog immediately before commit. Commands carry the expected link-set revision,
actor/reason and existing request/registration admission; link changes, retained
history, audit and receipt commit atomically. Exact replay returns its prior result.
Conflicting replay, cross-project identity, stale state, expired admission or any
failure leaves no partial link, history, audit or mutation. Accepted ticket link
sets are immutable, including backfill.

Relaunch, archive/restore and full backup preserve link versions and retirement
facts. Removal retains them under the historical registration before operational
deletion; re-add never reconnects by folder or name. Restore rotates admission and
requires renewed folder access. Repository bytes stay outside app backup. A future
portable package carries link/version/retirement identity, source provenance and
required documents without source capabilities; it does not silently change the
existing format. Direct acceptance exercises placed and unassigned links, revision
and retirement history, reverse impacts, binding/root/repository mismatch, unsafe
or unstable reads, bounds, stale revisions, replay/rollback, migration with no
inferred links, lifecycle/recovery, and complete wide/compact accessible navigation.


## Protected activation artifacts and recovery

Continuing custody rules apply to historical activation resources: approved
protected copies, backups, disposable restores, migration snapshots and quarantined
failed state remain retained under their exact owner-approved custody and disposal
terms. Routine work must not inspect protected owner paths, bookmark bytes, evidence
content, backup locations or request bodies, and historical activation approval does
not authorize another operation, recovery, read, cleanup or deletion.

If a typed operation is `outcomeUnknown`, keep writers quiesced and reconcile by
supported readback or exact replay of the complete original request; never create a
replacement request or restore across an uncertain commit. Migration, corruption or
unexpected-state recovery closes all writers and restores the exact approved
database set, including the approved presence or absence of its pre-migration
snapshot, together with the matching software, configuration and guidance. Recovery
then proves supported readback against the preserved baseline. Quarantine is allowed
only at an explicitly approved protected location, and retained material is deleted
only under its specific approved retention/disposal terms.
