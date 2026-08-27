# CloudKit-backed iPhone companion — discussion draft

- Status: Draft for future product and architecture discussion
- Date: 2026-08-26
- Approval state: Not approved; not an implementation brief or controlling architecture decision

## Purpose

Explore a read-only iPhone companion for Release Radar that lets one owner check
project delivery and agent status while away from the Mac. The companion would
use the same owner's private iCloud account and would not introduce team
collaboration, multi-user permissions, or mobile delivery mutations.

This draft records a direction for later discussion. It does not supersede
`docs/architecture/ADR-001-release-radar-boundaries.md`, alter the approved MVP,
or release implementation work.

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

Use the owner's **private CloudKit database as the structured cross-device
source of truth** for Release Radar's operational data. Use iCloud Documents
only where an artifact must remain an ordinary file that agents, text editors,
or other filesystem-oriented tools can open directly.

CloudKit is the primary synchronization mechanism, not an optional afterthought.
It is a better fit than copying the live SQLite database because it provides
record identity, incremental changes, deletion handling, retry behavior,
account scoping, remote change delivery, and platform-supported synchronization.

The high-level flow is:

```text
Mac delivery mutation
        |
        v
local SQLite transaction + durable CloudKit outbox
        |
        v
private CloudKit database
        |
        v
iPhone local cache -> read-only SwiftUI projections
```

The Mac remains the only mutation authority. CloudKit is the durable
cross-device representation. SQLite remains useful as the Mac's transactional
working store, offline cache, and outbox; it is not copied to the iPhone and is
not opened from iCloud Drive.

## Proposed storage boundaries

| Information | Proposed storage | Notes |
| --- | --- | --- |
| Projects, phases, tickets, lanes, dependencies, blockers, and reviews | Private CloudKit | Structured records or an atomic status projection, depending on the final schema. |
| Agent status and heartbeat | Private CloudKit | Includes publication and expiry timestamps so stale state is explicit. |
| Activity, audit, notification history, and completion records | Private CloudKit | Read-only on iPhone; cloud replicas must not trigger delivery or retries. |
| Planning, architecture, design, implementation, and tracking artifacts | CloudKit records/assets by default | Use iCloud Documents instead when ordinary file interoperability is required. |
| Reports, screenshots, attachments, and evidence intended for mobile viewing | CloudKit assets or iCloud Documents | Store portable metadata and content; local build availability remains device-specific. |
| Local source-code checkout | Mac filesystem | Outside the mobile data model. |
| Absolute checkout path and security-scoped bookmark | Mac device only | Link a stable cloud project ID to the local checkout without publishing a meaningless device path or capability token. |
| API tokens and notification credentials | Keychain | The read-only iPhone does not need Mac delivery credentials. |
| SQLite database and synchronization engine state | Local to each device | Cache, index, outbox, and CloudKit engine state rather than a synchronized database file. |

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

CloudKit assets are appropriate when Release Radar is the authoritative reader
and writer of an artifact. They keep the artifact inside the app's private
CloudKit data model and avoid a second synchronization system.

Some planning and implementation artifacts currently matter specifically as
ordinary Markdown, JSON, image, or report files. Codex, Git, shell tools, and
text editors operate on filesystem paths rather than CloudKit records. If that
interoperability remains a requirement, those artifacts should live in an
app-owned iCloud Documents container while CloudKit stores their identity,
classification, hashes, mobile metadata, and status.

This is the only material justification for not storing every artifact solely
as a CloudKit record. It is an interface constraint, not a generalized security
concern. The approved design must select one authoritative representation for
each artifact and must not create an unmanaged CloudKit/file mirror in which
both copies can be edited independently.

The design must also decide how repository-controlling artifacts are exposed to
agents if their authoritative copy moves outside the code repository. Possible
choices include direct operation in an authorized iCloud Documents workspace or
an explicit checked-out projection managed by Release Radar. A casual copy or
symlink that creates two apparent sources of truth is not sufficient.

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

### Private CloudKit plus selective iCloud Documents — recommended direction

Use CloudKit for structured state, status, activity, and artifact metadata. Use
CloudKit assets by default and iCloud Documents only where real filesystem
interoperability is required.

This provides incremental synchronization, offline caches, remote change
delivery, and a clear path to widgets or notifications without a custom
backend.

### iCloud Documents only

Publish status and all operational data as versioned files. This is viable for
a single read-only consumer but requires custom indexing, change discovery,
deletion handling, conflict behavior, and mobile projection work that CloudKit
already provides. It is not the preferred default.

### Custom backend

Adds authentication, hosting, operations, and data-service ownership without a
current cross-platform or multi-user requirement. It is out of scope unless a
future requirement cannot be met by the owner's private iCloud account.

## Open questions for later discussion

1. Must planning and implementation artifacts remain directly editable by
   Codex, Git, shell tools, and external editors, or may Release Radar own them
   as CloudKit assets?
2. Which operational artifacts are authoritative CloudKit records, and which
   are authoritative iCloud Documents indexed by CloudKit?
3. Does the first iPhone release need full document reading, or only dashboard,
   activity, and status views?
4. Which Mac-side supported event source can publish truthful running, waiting,
   approval-needed, and completed agent states?
5. How much activity and audit history should be retained and downloaded to the
   phone?
6. Should CloudKit contain the complete normalized delivery graph initially, or
   only atomic mobile status projections plus artifacts?
7. What owner-facing recovery is required for iCloud sign-out, account changes,
   deleted zones, quota exhaustion, or an unavailable network?
8. Should prompts and sensitive text use encrypted CloudKit fields, accepting
   the corresponding query and indexing limitations?
9. Should mobile notifications or widgets be included in the first companion
   milestone or deferred until read-only in-app status is proven?

## Conditions before approval or implementation

Before this direction can become controlling architecture:

- reconcile it explicitly with ADR-001's current local-only and sole-database-
  authority decisions;
- define the authoritative representation for each artifact class;
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
