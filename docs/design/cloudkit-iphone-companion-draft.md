# CloudKit-backed iPhone companion — discussion draft

- Status: Draft for future product and architecture discussion
- Date: 2026-08-26
- Approval state: Mac/repository authority and read-only cloud publication selected by the owner on 2026-09-06 and recorded in ADR-001; remaining design is proposed, not an implementation brief

## Purpose

Explore a read-only iPhone companion for Release Radar that lets one owner check
project delivery and agent status while away from the Mac. The companion would
use the same owner's private iCloud account and would not introduce team
collaboration, multi-user permissions, or mobile delivery mutations.

This draft develops the owner-selected authority boundary in
`docs/architecture/ADR-001-release-radar-boundaries.md`. It does not supersede that
ADR or release implementation. Its former cloud-source-of-truth and authoritative
document-relocation direction is not selected.

## Clarified scope

"All data" means the operational project corpus managed or presented by
Release Radar, including:

- product and delivery planning;
- architecture and design artifacts;
- implementation briefs, notes, outcomes, and verification evidence;
- roadmap, phase, ticket, dependency, blocker, and review state;
- progress tracking, activity, audit history, and completion records;
- agent status, heartbeat, waiting state, and last meaningful activity; and
- reports, attachments, and other evidence intended for owner consumption.

It does **not** mean application or project source code, Git metadata, build
products, dependency caches, or a remotely accessible code checkout. Source
code remains in its ordinary local repository on the Mac.

The intended operating model is deliberately narrow:

- one owner;
- one private iCloud account;
- the Mac is the only delivery-state publisher;
- the iPhone is a read-only subscriber;
- the iPhone may cache the last available state for offline viewing; and
- stale or unavailable information must never be presented as live.

## Proposed direction

Keep the **Mac app authoritative for delivery state and repositories authoritative
for their documents**. Publish read-only copies through the owner's private cloud
storage for the iPhone. CloudKit records/assets remain the proposed publication
mechanism; publication does not relocate source documents or transfer authority.

The proposed CloudKit publication mechanism uses record identity, incremental
changes, deletion handling, retry behavior,
account scoping, remote change delivery, and platform-supported synchronization.

The high-level flow is:

```text
Mac delivery mutation
        |
        v
authoritative local SQLite transaction + proposed publication outbox
        |
        v
read-only publication in private CloudKit
        |
        v
iPhone local cache -> read-only SwiftUI projections
```

The Mac remains the delivery mutation authority. CloudKit carries published
representations; the Mac's SQLite store is not merely a cache of cloud authority.
The repository catalog owns document identity/authority, and the app explicitly
accepts snapshots under its existing contract. Neither cloud publication nor phone
readback accepts a changed catalog. SQLite is not copied to the phone or opened
from iCloud Drive. Source loss requires an explicit backup/import recovery path;
cloud publication alone does not become a full backup or authority takeover.

## Reconciled companion requirements

The completed iPhone discovery is retained as historical provenance under artifact
`rr-iphone-companion-discovery-2026-09-07`. The following applicable requirements
now belong to this proposed design; the completed assignment is not a default input.

- The first complete product has Projects plus four read-only project destinations:
  Overview, Work, Library, and History. It represents every record/artifact class
  supported by the publishing Mac version or names the exact unavailable, excluded,
  unsupported, or update-required reason. It is not a dashboard-only prototype.
- Publication uses opaque account/project-zone identity, immutable versioned items,
  and a manifest containing schema/minimum-reader version, publisher epoch,
  registration, generation, expected identities/bytes, and source/publication
  times. Upload items first and activate the manifest last. An incomplete generation
  retains only the non-withdrawn portion of the last complete compatible generation.
- A backward-compatible withdrawal envelope is processed before generation fallback.
  It immediately hides named records, purges their cached bytes and derived search/
  preview state, and prevents an older generation from restoring revoked content.
  Archive remains browsable; remove-from-tracking publishes retained attributable
  history only; re-add uses a new registration and zone.
- Publication is off by default per project. Mac preflight lists account, categories,
  item count, bytes, and every exclusion/limit reason. Managed evidence requires a
  currently resolved accepted identity; legacy evidence requires explicit per-item
  inclusion. Publication never expands a filesystem grant.
- Hard exclusions are source/Git/build/dependency data, absolute paths, bookmarks,
  device root IDs, SQLite/sidecars, credentials/tokens/Keychain values, reusable
  command authority, and content outside current authorized roots. Stable no-follow
  reads preserve source identity through the read.
- Proposed bounds are 256 KiB encoded non-asset payload per record, 200 records and
  1 MiB non-asset payload per send batch, existing repository-reader bounds of 32
  MiB per artifact and 256 MiB selected artifact bytes per project generation, and
  a 512 MiB per-account phone content cache. A limit failure is visible and never
  produces a falsely complete manifest. Validate these numbers against representative
  owner corpora before implementation.
- Keep routing metadata minimal. Project names, domain IDs, titles, descriptions,
  document bodies, audit detail and other owner text use encrypted fields/assets;
  search is device-local after decryption. Cache files use complete file protection,
  are treated as recreatable, and are excluded from device backup.
- Display source observation/commit, repository-content observation, publication,
  device-receipt, and last-server-check times separately. Offline says cached; recent
  upload never extends a live-agent lease. Delivery/document/evidence/history remain
  useful when agent status is unavailable.
- Account switch/sign-out purges the old account's phone cache before initializing
  another and suspends Mac publication until explicit re-enable. Stop publishing,
  user-deleted zones, encrypted-data reset, quota/partial failures, and offline
  cleanup remain visible; deleted/purged cloud data is not silently recreated.
- Cloud is never backup or import authority. Tracking reset must withdraw cloud data
  or durably retain a visible cleanup obligation. Backup restore reconciles current
  account, consent and withdrawals before advancing the publisher epoch; uncertainty
  disables publication pending explicit republish. Phone/cloud bytes cannot restore
  Mac authority, resume execution, or replay commands/notifications.
- Schema evolution is additive with per-record versions and minimum reader version.
  Unknown authoritative types are not decoded as empty. A new Mac feature extends
  the shared publication contract in its own slice; an older phone keeps only the
  non-withdrawn last compatible generation and says Update required.

Implementation remains separately authorized and depends on complete reset/restore
semantics, event-time history, bounded artifact-content reads, current portable-model
coverage, and an approved iPhone/RDS presentation decision. I1 live observation is
not a prerequisite. Direct acceptance must cover every supported record class,
incomplete multi-batch generations, offline relaunch, account changes, lifecycle and
withdrawal, cache purge, reset/restore epochs, quota/retry/partial failures, schema
compatibility, encrypted-field classification, absence of mobile writes, and
physical-device remote-change delivery.

## Proposed storage boundaries

| Information | Proposed storage | Notes |
| --- | --- | --- |
| Projects, phases, tickets, lanes, dependencies, blockers, and reviews | Mac SQLite authority; published CloudKit records | Structured records or consistent projections, depending on the final publication schema. |
| Agent status and heartbeat | Mac-side supported observation; published CloudKit records | Publication and expiry timestamps preserve the source's freshness and availability limits. |
| Activity, audit, notification history, and completion records | Mac history; read-only cloud publication | Phone copies must not trigger delivery or retries. |
| Planning, architecture, design, implementation, and tracking artifacts | Repository originals; published CloudKit records/assets | Keep ordinary file interoperability and authoritative catalog identity in the repository. |
| Reports, screenshots, attachments, and evidence intended for mobile viewing | Authorized originals; published CloudKit assets | Publish portable metadata and content without moving authoritative files; local build availability remains device-specific. |
| Local source-code checkout | Mac filesystem | Outside the mobile data model. |
| Absolute checkout path and security-scoped bookmark | Mac device only | Link a stable cloud project ID to the local checkout without publishing a meaningless device path or capability token. |
| API tokens and notification credentials | Keychain | The read-only iPhone does not need Mac delivery credentials. |
| SQLite database and synchronization engine state | Local to each device | Authoritative delivery store on Mac; read-only cache on phone; no synchronized database file. |

Prompts, raw audits, implementation notes, and evidence are not categorically
excluded from CloudKit. For this personal application they may be synchronized
when they are useful to the owner. Their inclusion is a product-content and
retention decision, not a presumption that private CloudKit is unsafe.

## CloudKit record shape

Do not mechanically mirror every SQLite table. Start from the read models and
artifacts the iPhone needs. A plausible initial record vocabulary is:

### `RRProject`

- stable project ID;
- display name;
- schema version;
- current published generation;
- last publication date; and
- lifecycle state.

### `RRStatusSnapshot`

- project ID and generation;
- generated date;
- agent state and last activity date;
- heartbeat expiry date;
- active phase;
- ticket summaries grouped by the five persisted lanes;
- blockers and Needs Review summaries; and
- counts and other compact dashboard projections.

The snapshot provides an internally consistent mobile dashboard without
requiring the first iPhone release to reconstruct every relational invariant.
More granular records may be added only when a concrete mobile use case needs
them.

### `RRArtifact`

- stable artifact ID;
- project ID;
- category, title, and portable relative path;
- media type, content hash, and modified date;
- schema or format version; and
- inline content or a CloudKit asset.

Artifacts may represent planning documents, task briefs, architecture records,
design documents, implementation notes, progress records, reports, or evidence.

### `RRActivity`

- stable event ID;
- project and optional entity identity;
- event type and owner-facing description;
- original audit detail when the product's retention decision includes it;
- actor attribution when available;
- occurrence date; and
- originating publication ID for idempotency.

Activity is append-only from the iPhone's perspective. Receiving activity must
not schedule notifications or replay Mac-side operational work.

## Planning-file interoperability

Repository artifacts remain ordinary files for Codex, Git, shell tools and text
editors. Their authoritative location and catalogued identity stay in the
repository. CloudKit assets are published copies for reading, not a replacement
file workspace, and phone/cloud copies cannot be edited independently.

Publication design must identify the source artifact and content version, preserve
pending/invalid/unavailable states, and avoid mixing incompatible generations.
Moving authoritative documents into iCloud Documents or replacing them with
checked-out cloud projections is outside the selected direction. Detailed update,
withdrawal, size-limit and offline-download behavior remains to be designed.

## Publishing and offline behavior

The Mac should record each publishable delivery mutation and a stable CloudKit
outbox operation in the same local SQLite transaction. After commit,
`CKSyncEngine` can send the pending records. Successful publication marks the
outbox operation acknowledged; transient network or account failures leave it
pending for retry.

This does not attempt a distributed transaction between SQLite and CloudKit.
The owner-visible states are instead explicit:

- locally committed and pending publication on the Mac;
- published to CloudKit;
- received by the iPhone; and
- stale or unavailable on the iPhone.

The iPhone persists received records locally and remains useful without a
network connection. It does not enqueue outgoing record changes.

## Truthful agent status

Planning and tracking records do not by themselves prove that an agent is
currently running. A Mac-side supported source must publish a leased status
record similar to:

```json
{
  "state": "running",
  "taskID": "RR-R7",
  "publishedAt": "2026-08-26T14:20:00Z",
  "validUntil": "2026-08-26T14:22:00Z",
  "lastMeaningfulActivityAt": "2026-08-26T14:19:42Z"
}
```

The iPhone may display `running` only while the lease remains valid. After
expiry it shows a last-seen or stale state. CloudKit transport cannot make a
status more authoritative than the Mac-side observation that produced it.

The existing supported-live-observation limitation in ADR-001 therefore
remains relevant. A future design must identify the supported publisher for
running, waiting, approval-needed, completed, and unavailable states before it
claims live agent monitoring.

## Proportional security and privacy position

This is a personal, private-iCloud feature. It does not need a multi-tenant
authorization service, organization roles, collaboration permissions, or a
custom backend.

The realistic concerns are limited to:

- compromise of the owner's Apple account or another trusted device;
- accidental inclusion of credentials in an artifact;
- sensitive content appearing in lock-screen notifications or widgets;
- stale data being presented as current;
- deletion, account switching, or loss of private CloudKit data; and
- malformed or partially available artifacts at the local rendering boundary.

Normal platform protections, private CloudKit scope, optional encrypted fields,
Keychain storage for credentials, strict rendering boundaries, and explicit
freshness states are proportionate controls. Security-scoped bookmark bytes
remain local because they are device access capabilities and have no mobile
utility, not because the rest of the operational corpus is too sensitive for
private CloudKit.

## Why not synchronize the live SQLite file

Do not put the open `release-radar.sqlite` database in iCloud Drive for the Mac
and iPhone to access directly. This is an integrity and synchronization-model
problem rather than a privacy objection. SQLite's database, transaction,
locking, WAL, and shared-memory behavior does not map cleanly onto asynchronous
document replication and conflict versions.

CloudKit records plus local caches preserve the useful SQLite transaction
boundary on the Mac without treating a live database file as a portable
document.

## Alternatives considered

### Private CloudKit publication — proposed mechanism within selected authority

Use CloudKit for published state, status, activity and artifact metadata, with
assets for published document/evidence content. Originals remain under Mac app
or repository authority; no second editable source is introduced.

This provides incremental synchronization, offline caches, remote change
delivery, and a clear path to widgets or notifications without a custom
backend.

### iCloud Documents only

As an alternative publication mechanism, publish copies of status and operational
data as versioned files while retaining Mac/repository authority. This is viable for
a single read-only consumer but requires custom indexing, change discovery,
deletion handling, conflict behavior, and mobile projection work that CloudKit
already provides. It is not the preferred default.

### Custom backend

Adds authentication, hosting, operations, and data-service ownership without a
current cross-platform or multi-user requirement. It is out of scope unless a
future requirement cannot be met by the owner's private iCloud account.

## Remaining choices before implementation

1. Validate the proposed item, generation, batch, and cache limits against
   representative owner corpora while preserving fail-visible behavior.
2. Approve the first iPhone interaction design and whether RekonDesignSystem gains
   iOS support or a separately reviewed compatible presentation layer is used.
3. Approve the exact offline cloud-cleanup-pending behavior for a destructive local
   reset; neither silent retention nor a recovery deadlock is acceptable.

## Conditions before approval or implementation

Before this direction can become controlling architecture:

- preserve ADR-001's selected Mac/repository authority and read-only publication;
- define publication representations and lifecycle for each artifact class;
- confirm the Mac-side agent-status publisher and freshness contract;
- define CloudKit development, production-schema, account-change, deletion,
  and recovery behavior;
- decide the first iPhone information architecture and inspect or create its
  approved design references;
- produce a bounded, test-first implementation brief through the repository's
  independent delivery gates; and
- conduct the required architecture, security/privacy, QA, and code reviews for
  the approved slice.

No implementation is authorized by this draft.

## Reference material

- [Apple: Deciding whether CloudKit is right for your app](https://developer.apple.com/documentation/cloudkit/deciding-whether-cloudkit-is-right-for-your-app)
- [Apple: CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)
- [Apple: Encrypting user data in CloudKit](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)
- [Apple: Synchronizing documents in the iCloud environment](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment)
- [Apple: NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
