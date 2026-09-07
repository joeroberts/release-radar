# Discover complete read-only iPhone companion

## Assignment brief — 2026-09-07

Status: authorized bounded discovery; findings pending. This artifact records a
proposal, not accepted architecture or implementation.

Assess the full companion corpus: delivery/planning, operational documents, evidence, history and agent status. Propose publication, asset/cache bounds, privacy/inclusion, account switching, deletion propagation, offline/freshness and backup/reset/schema recovery. Return concrete pursue/no-go choices and the smallest complete product boundary.

Use current Apple primary sources. Mac delivery authority and repository document authority remain accepted, with read-only cloud publication. Preserve retained-history and self-contained package policies. Live agent status depends on I1; useful delivery/document browsing does not. No cloud provisioning, entitlement changes, production publisher or mobile implementation; no dashboard-only reduction. I6/RM8 consumes C7 recovery and later history/portable model changes.

Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Retain all 40 capabilities and accepted versus proposed distinctions. RDS appearance
is unchanged. This discovery does not reopen completed lifecycle work or gate C4.

Model/effort: gpt-5.6-sol / high; ceiling: Astra High; Ultra prohibited. Assigned baseline is
`c4ddffb` plus the committed discovery briefs/catalog preparation on
`codex/recovery-orchestration`; the dispatch supplies its exact revision. Use a fresh
worktree and named `codex/discovery-iphone-companion` branch with upstream. Own only this
artifact. The orchestrator owns progress, shared plan/catalog/index integration.
Do not overwrite another worker's files or edit the canonical checkout.

Verification: cite current primary sources supporting conclusions; distinguish
verified local capability, documentary evidence, hypothesis and unavailable proof.
Use only bounded isolated tests justified by the question. Report compatibility,
privacy/recovery risks and any material unresolved owner choice with recommendation.
One fresh independent substantive reviewer covers actual proposal risks; only
Required findings block. No review-of-review or implementation approval implied.

Endpoint: coherent findings in this artifact, scoped commit, branch push and PR
against `codex/release-radar-mvp`. Each merge needs owner approval. No installation,
owner/application-state mutation, cloud provisioning, active configuration change or
production implementation. List retained temporary files; do not delete unrelated
files. Report exact commit, checks, limitations and stopped processes to the
orchestrator before archival.

## Findings

### Decision

**Pursue a complete read-only iPhone companion through the owner's private
CloudKit database, using `CKSyncEngine`, one opaque custom zone per published
project registration, and a separate local cache on each device.** This is
technically feasible and fits the accepted Mac/repository authority boundary.
It is not ready for implementation: C7 recovery, event-time History, bounded
artifact-content reading, the production publication schema and iPhone design
still need their owning outcomes. The decision can proceed without gating C4.

The following alternatives are no-go for this product direction:

- synchronizing or copying the live SQLite database;
- making CloudKit or the phone authoritative for delivery or documents;
- a dashboard-only/status-only mobile release described as the companion;
- a custom backend, multi-user account system or shared CloudKit database;
- iCloud Documents as the primary structured publication mechanism;
- phone-side delivery, document, acceptance or notification mutations;
- source-code, Git, build-product, credential or device-capability publication;
- treating published copies as backup, Portable Import input or Mac recovery;
- claiming live agent state before I1 provides a supported source; and
- widgets, lock-screen notifications, sharing/export and mobile search of remote
  encrypted fields in the first outcome.

This is a product/architecture proposal, not approval to add targets,
entitlements, containers, production schemas or cloud resources.

### Evidence and confidence

**Accepted documentary evidence.** [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md)
keeps Mac delivery and repository-document authority while permitting read-only
publication. The [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
requires I6 to cover planning, operational documents, evidence, history and agent
status, preserves all 40 capabilities, makes live status conditional on I1 and
places recovery/package/history work upstream of the complete companion.

**Verified local capability.** `DashboardProjection.load` currently reads the
app-owned `DeliveryStore` to assemble projects, phases, five-lane tickets,
Delivery Goals, readiness, Ticket Tasks and evidence metadata
(`ReleaseRadar/Projects/DashboardProjection.swift:19-184`).
`ProjectActivityProjection.load` separately assembles audits, reviews,
completion records, observed goals and notification history
(`ReleaseRadar/Activity/ProjectActivityProjection.swift:48-283`). Managed
document resolution preserves repository/artifact identity and current
readability (`ReleaseRadarCore/Documentation/ManagedEvidenceReadback.swift:3-106`),
while descriptor-relative no-follow reads already bound catalogued documents to
an authorized root (`RepositoryDocumentReader.swift:4-210`). These are useful
publication inputs, not a mobile/publication API.

The only current observer implementation deliberately returns unavailable or
downgrades an authorized cached snapshot to stale
(`ReleaseRadarCore/Codex/CodexObserver.swift:3-58`). The current Xcode project is
macOS-only, the app entitlements contain no iCloud/CloudKit container, and no
CloudKit implementation exists in the source. Evidence content also lacks a
general mobile-safe reader today; the current evidence view presents locator,
authority and availability metadata rather than file bytes.

**Current Apple primary sources.** Apple describes `CKSyncEngine` as the
controlled CloudKit option for an existing model, with automatic private-database
send/fetch scheduling, application-supplied changed records, persisted engine
state and application-owned conflict/error handling
([CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9),
[choosing a CloudKit approach](https://developer.apple.com/documentation/cloudkit/deciding-whether-cloudkit-is-right-for-your-app)).
Private databases are scoped to the signed-in account and consume that owner's
iCloud quota ([CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)).
Custom private zones provide change tracking and same-zone atomic modification
([CKRecordZone](https://developer.apple.com/documentation/cloudkit/ckrecordzone)).
This supports the proposed boundary; it does not prove a configured container or
real-device behavior.

**Unavailable proof.** No iCloud capability/container, development or production
schema, iPhone target, physical-device push test, CloudKit quota test or iOS RDS
compatibility proof was created or inspected. Apple requires CloudKit and remote
notification capabilities, and Apple's sample notes that real devices are needed
to prove remote-notification-driven sync
([configuring iCloud](https://developer.apple.com/documentation/xcode/configuring-icloud-services),
[CKSyncEngine sample](https://github.com/apple/sample-cloudkit-sync-engine)).
Those are later explicitly authorized implementation/acceptance steps.

### Smallest complete product boundary

The first shippable outcome is one-owner, one-private-iCloud-account publication
from the Mac plus a read-only iPhone browser. It has a Projects list and one
project detail with four destinations:

1. **Overview:** lifecycle, health, active/viewed context, last publication and
   agent availability/freshness.
2. **Work:** recorded plan, phases, five-lane boards, dependencies, blockers,
   Delivery Goals/readiness, Ticket Tasks, reviews and execution observations.
3. **Library:** catalogued operational documents plus managed and explicitly
   included legacy evidence, with lifecycle, authority, provenance and
   availability.
4. **History:** retained audit/activity, plan/task/goal revisions, completions,
   notification outcomes, imports and removal records.

The phone offers navigation, filtering, local search and native safe preview only.
It never shows a mutation control. Markdown/plain text/JSON render as inert text;
PDF and raster images use native read-only preview. Unsupported or oversized
content remains listed as metadata with a reason and Mac location description,
not silently omitted or executed. The first outcome has no share sheet, external
open, widget or notification surface.

The publication vocabulary must represent the 40-capability programme without
pretending every capability is already delivered:

| Programme area | Companion contract |
| --- | --- |
| C1-C4 registration/access/roots | Publish stable project/registration identity, setup and root-health facts but no paths, bookmarks or recovery actions. Browsing never changes active context or access. |
| C5-C7 lifecycle/recovery | Archive remains browsable; removal retains only attributable read-only history; reset/restore advances publication epoch. Cloud data never reconstructs Mac authority. |
| C8-C12 documents/evidence/export/import/health | Publish accepted catalog identity, independently observed content revision/readability, bounded selected bytes, package/import history and health. Catalog checks, publishing and phone reads never accept or repair documents. |
| P1-P19 planning/navigation/history/evidence/search | Publish every supported recorded phase, work, goal, task, relationship, revision, event and evidence identity. The phone derives read-only routes and local search; unsupported future types are explicit, not empty. |
| I1-I2 observation/plugin | Publish last-known plugin/observer health. Only an I1-supported leased observation can be live; otherwise agent material is historical/stale/unavailable. |
| I3-I5 presentation/distribution | Preserve the accepted RDS appearance and explicit status mapping. iOS package compatibility and distribution remain separate proofs; the Mac design is not changed to make the phone possible. |
| I6-I9 companion/execution/host/hooks | I6 owns publication/readback. If later I7-I9 exist, publish their attributed run/configuration events and evidence only; the phone neither owns runs nor treats configuration as delivery state. |

At implementation time, “complete” means every record/artifact class supported by
that Mac version is either present in the active manifest or named there with a
specific unavailable/excluded/unsupported reason. A new authoritative feature
must extend the shared publication contract in its own slice; an old phone keeps
the last complete compatible generation and shows **Update required** rather than
dropping new data.

### Publication and consistency model

Use the private database only. Store a small account-scoped control zone containing
opaque publisher epoch and project-index records. Give each published local
project registration its own randomly named custom zone; do not derive zone or
record names from repository paths, project names or delivery IDs.

Within a project zone, publish immutable versioned items and an `RRManifest`:

- structured state chunks for the recorded graph and health;
- artifact revisions plus separate `CKAsset` content;
- immutable event/history records with occurrence, recording and provenance facts;
- an optional short-lived `RRRuntimeLease`; and
- withdrawal/removal tombstones.

The manifest names the schema version, minimum reader version, publisher epoch,
project registration, generation, expected item identities/byte counts and the
Mac source/publication times. Upload all records/assets first and update the
manifest pointer last. The iPhone activates a generation only after every expected
item is present and valid; otherwise it continues showing the last complete
generation with **Sync incomplete**. Retain the prior complete generation until
the replacement is published, then garbage-collect older generations. CloudKit
atomicity is zone-scoped and large requests must be split, so the manifest—not a
false distributed transaction—provides mobile consistency.

App-owned delivery changes should record a coalescible project publication intent
with the local transaction. The publisher then reads one consistent projection
and publishes the newest generation. Repository changes remain separate: publish
only after bounded current read/validation, and carry artifact ID, accepted catalog
version/digest, actual content digest, observed time and publication time. The
content digest versions the published bytes; it does not approve prose or alter
the catalog.

CloudKit records must remain well below Apple's 1 MiB non-asset record limit
([CKRecord](https://developer.apple.com/documentation/cloudkit/ckrecord)). Use a
Release Radar maximum of **256 KiB encoded non-asset payload per record** and
**200 records / 1 MiB non-asset payload per send batch**. Apple describes general
guidelines of 400 items and 2 MiB per request and requires splitting a rejected
request ([`limitExceeded`](https://developer.apple.com/documentation/cloudkit/ckerror/code/limitexceeded)).

Use the existing repository-reader bounds as the companion content ceiling:
**32 MiB per artifact and 256 MiB aggregate selected artifact bytes per project
generation** (`RepositoryDocumentContract.Limits`). Structured records and
manifests do not count against that artifact ceiling. Content larger than a few
kilobytes uses `CKAsset`; Apple stages fetched assets temporarily, so the phone
must move accepted bytes into its bounded cache
([CKAsset](https://developer.apple.com/documentation/cloudkit/ckasset)). A limit
failure leaves the project **Publication limited**, lists every omitted item and
requires an explicit Mac-side exclusion or smaller authoritative artifact; it
never calls the generation complete by omission.

The iPhone keeps the complete latest structured graph/history and artifact
metadata, plus a **512 MiB per-account content cache** for document/evidence bytes.
Evict least-recently-viewed content first while retaining metadata and availability.
No per-item offline pinning is needed initially. Cache files use complete file
protection, live in the caches directory, and are excluded from device backup
because they are recreatable published copies
([iOS file protection](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files),
[backup treatment](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)).

### Privacy and inclusion

Publication is **off by default per project**. Enabling it on the Mac shows a
preflight with account status, categories, item count, byte total and every
exclusion/limit reason. The default included set is the full current structured
project graph/history, every catalogued owner-consumable document across active,
completed, superseded and archived lifecycles, and current managed evidence whose
accepted identity resolves safely. Non-managed legacy evidence requires explicit
per-item inclusion because a stored path alone is not a managed-content grant.

Hard exclusions are source code, Git data, build/dependency output, absolute paths,
bookmarks, root IDs with device meaning, SQLite and sidecars, credentials/tokens,
Keychain values, command receipts containing reusable authority, and content outside
current authorized roots. A file must be a stable no-follow regular file, satisfy
the type and size policy and retain its source identity through the read. Publication
does not expand the existing filesystem grant.

Use opaque record/zone names. Keep only schema/generation/kind/time/size routing
metadata unencrypted. Store project names, domain IDs, titles, descriptions,
document bodies, audit details and other owner text in encrypted fields or encrypted
assets, with device-local search after decryption. Apple states encrypted fields
cannot be indexed or retrofitted onto existing unencrypted schema fields, while
private-database `CKAsset` content is encrypted automatically
([Encrypting User Data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)).
The encryption classification therefore belongs in schema v1, before production
deployment. Lock-screen/widget exposure is deferred.

### Freshness, account and deletion behavior

The phone always shows separate facts: Mac source commit/observation time,
repository content observation time, CloudKit publication time, device receipt
time and last successful server check. Offline mode says **Cached — received …**;
it never says current. Delivery/document browsing remains useful from cache without
I1. Agent state is `Live` only when a supported I1 observation identifies the
source and its lease has not expired; upload recency cannot extend that lease.

Persist `CKSyncEngine` state beside the corresponding cache and replace it on every
state-update event. Apple requires the newest serialization across launches and
warns that automatic scheduling is indeterminate; recoverable failures stay pending
and retry under the system scheduler
([state serialization](https://developer.apple.com/documentation/cloudkit/cksyncenginestateupdateevent/stateserialization),
[`automaticallySync`](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/automaticallysync)).

On iCloud sign-out or account switch, immediately hide and purge the old phone
cache and engine state before initializing the new account. On the Mac, suspend
publication and require the owner to explicitly enable the companion for the new
account; never upload existing projects merely because a new account appeared.
Transient network or account unavailability retains the same-account cache and
shows the error. Apple reports account changes through `CKSyncEngine`, resets its
internal pending state, and leaves local-persistence response to the app
([account change](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange)).

Lifecycle propagation is explicit:

- **Archive:** publish archived lifecycle and keep the full browsable corpus.
- **Restore:** publish a new generation under the same registration.
- **Remove from tracking:** publish a terminal removal generation containing the
  retained attributable history/removal record, then delete operational records
  and assets. Re-add uses a new registration/zone and cannot receive old requests.
- **Stop publishing:** a separate owner action deletes the project zone and purges
  the phone cache without changing Mac delivery or repository data.
- **User-deleted zone/encrypted-data reset:** purge phone data, suspend Mac
  publication and require explicit republish. Do not automatically recreate data
  the owner deleted in iCloud settings. Apple distinguishes deleted, purged and
  encrypted-data-reset zone reasons; encrypted-key reset can make prior encrypted
  data permanently unavailable
  ([zone deletion reasons](https://developer.apple.com/documentation/cloudkit/cksyncenginezonedeletionreason),
  [encrypted-data recovery](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)).

### Backup, reset and schema recovery

Cloud publication is never offered as backup or import. C7 must define these
companion consequences before production publication:

- preference reset leaves publication content intact but resets only nonessential
  local UI preferences;
- tracking-data reset withdraws cloud project zones, or durably records a visible
  cleanup-pending obligation that survives store replacement when iCloud is
  unavailable—reset must not silently leave readable copies;
- full backup restore quiesces publisher/bridge work, restores the authoritative
  graph, advances the publisher epoch, republishes the restored state and withdraws
  zones absent from the backup; and
- lost Mac authority requires C7 backup or C10/C11 package recovery. Phone/cloud
  bytes cannot be promoted into a project or replay notifications/commands.

A phone seeing a new epoch purges older cached registrations before activating the
new complete generation. While offline it may still show the old cache, but only
with its recorded publication/receipt times and no live claim.

Use additive CloudKit production-schema evolution, per-record payload versions and
manifest `minimumReaderVersion`. An unsupported generation yields **Update
required** while retaining the last compatible complete generation. Never partially
decode an unknown authoritative type as an empty field. Apple requires development
schema testing before deployment and says production record types/fields cannot be
deleted; later additions merge into production
([deploying a CloudKit schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)).
Loss of local engine state triggers a server bootstrap on the phone or a complete
republish from the Mac; it does not alter Mac delivery data.

### Dependencies, delivery shape and acceptance

The pursue decision opens a later, separately approved outcome; it does not open
cloud or mobile implementation. That outcome should start only after:

- C7 supplies reset/restore/cleanup semantics and registration epoch behavior;
- D7/P11 supplies immutable event-time facts so publication does not freeze the
  current-lane decoration as false history;
- C9 supplies bounded safe artifact-content reads beyond metadata;
- the then-current C10/C11 portable model identifies every supported record and
  provenance field that the companion must also understand (without sharing
  package bytes or import authority); and
- an iPhone design and RDS iOS compatibility decision preserve the accepted visual
  language without changing the existing RDS appearance.

I1 is not a prerequisite for this outcome: ship the complete delivery/document/
evidence/history browser with agent status explicitly unavailable, then add leased
live status only if I1 succeeds.

Implementation should be delivered in two bounded candidates that together form
one complete product outcome: (1) shared versioned publication DTOs, Mac preflight/
outbox/publisher and deterministic simulated CloudKit tests; (2) iPhone cache,
full four-destination browser and development/production real-device acceptance.
Neither a schema-only foundation nor a status-only mobile prototype is completion.

Minimum direct acceptance is a fixture containing every supported record/artifact
class; multi-batch incomplete-generation rejection; offline relaunch; account
sign-out/switch; archive/restore/remove/re-add; stop-publishing and user-deleted
zone behavior; quota/limit/partial/retry failures; backup-restore epoch change;
old/new schema compatibility; encrypted-field classification; no mobile write path;
and physical-device remote-change delivery. Architecture and Security/Privacy
review are required for authority, schema, credentials/content and deletion/reset;
independent QA covers the complete phone journey and truthful offline/freshness
presentation. One qualified independent review may cover overlapping risks.

### Material risks and remaining owner choices

No accepted product choice is reopened. The remaining implementation-time choices
are bounded:

1. Confirm the proposed 32 MiB/item, 256 MiB/project-generation and 512 MiB/device
   cache limits against representative owner corpora; retain fail-visible semantics
   if numbers change.
2. Approve the exact first iPhone design and whether the RDS package gains iOS
   support or the phone uses a separately reviewed compatible presentation layer.
   Existing Mac/RDS appearance remains unchanged either way.
3. Approve the explicit cloud-cleanup-pending choice in C7 when a destructive local
   reset occurs while iCloud is unavailable. Automatic silent retention and a
   recovery deadlock are both rejected.

The largest feasibility risk is operational, not conceptual: a new iPhone target,
container, entitlements, production schema and real-device push behavior are all
unproven. The design keeps those failures bounded and truthful; a failed production
gate closes implementation without weakening local Release Radar or any of the 40
capabilities.
