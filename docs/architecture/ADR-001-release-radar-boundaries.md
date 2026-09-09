# ADR-001: Release Radar application boundaries

- Status: Accepted
- Date: 2026-08-23

## Context

Release Radar is a personal, local-first delivery dashboard for folder-backed projects. It must present agent-managed delivery state without turning project repositories, Codex runtime data, or notification credentials into competing authorities.

## Decision

Release Radar is a standalone, signed, sandboxed macOS application with bundle identifier `com.rekonlabs.ReleaseRadar`, minimum macOS version 14.0, and an app-owned Application Support data namespace derived from that bundle identifier. The Mac app is authoritative for delivery state. Repository documents and future read-only cloud publications do not become delivery authorities.

The app process is the sole authority allowed to open and write its SQLite database. A separately bounded read-only observer may supply Codex thread, goal, waiting, completion, and freshness context through a supported sandbox-compatible connection. A distinct, narrowly typed mutation bridge may request validated transactional delivery commands from the app. The observer cannot mutate delivery state; the bridge cannot open SQLite, issue generic commands, observe unrelated state, or receive Pushover credentials.

App Sandbox and Hardened Runtime remain enabled. Owner-facing builds use the configured Apple Development identity. Future helpers or tools must have their own signed identities and the minimum entitlements needed for their proven boundary; signing does not grant database authority.

The approved board has exactly five persisted lanes: Backlog, In progress, Needs review, Blocked, and Accepted. This supersedes the earlier Ready-lane concept. Dependency eligibility is derived context, not a sixth lane or an automatic transition. Observed Codex state never changes a formal lane implicitly, and agents may make any formal transition through the typed bridge.

## RR-R2 folder-authorization recovery — 2026-08-25

An owner-triggered Needs Review Resolve or Dismiss action requires a currently
resolved, active security-scoped bookmark for that project. Stored paths alone
do not authorize the action.

Reauthorizing the same canonical persisted root and associating the first root
for a rootless legacy project are distinct owner actions. First-root association
requires project-named owner confirmation and a globally unowned canonical root.
Both actions are app-owned, bounded, and audited; failed, stale, denied, or
mismatched authorization fails closed and preserves existing history.

## Existing-project onboarding and portable project archive v1 — 2026-08-25

The v1 format below retains its defined compatibility behavior. It is not the
target for future complete-project export: the owner-approved 2026-09-06 package
direction below supersedes its contents as the RM5/RM6 product requirement.
No new format version or implementation is established by this amendment.

Existing-project onboarding has two non-overlapping owner workflows:

1. **Attach Folder to Existing Project** authorizes a canonical folder for an
   already-persisted project that has no root or bookmark. It reuses the
   app-owned first-root association transaction, preserves every delivery and
   history record, and adds only one root, one fresh local bookmark, and one
   project-scoped owner audit.
2. **Import Existing Project** creates a new project from an authoritative
   portable Release Radar archive. It never attaches to, merges with, replaces,
   or updates an existing project.

Portable project archive version 1 is one bounded JSON file using the extension
`.release-radar-project.json`, `format` value
`com.rekonlabs.release-radar.project-archive`, and `schemaVersion` value `1`.
It contains exporter timestamp and producer bundle/app/store-schema metadata,
plus exactly one project. Stable IDs are preserved without remapping for the
project, phases and active phase, phase dependencies, tickets and lanes and
outcomes, ticket dependencies, blockers, root-relative evidence, thread
exclusions, observed threads and goals, thread links, ticket-goal links, review
items and statuses, and completion records. Imported observations are labelled
historical last-known context and never presented as live.

Version 1 represents exactly one source project root and requires one newly
selected destination root. Multiple-root projects or evidence outside that one
root are not representable and export must fail instead of omitting records.
Absolute roots, root IDs, security-scoped bookmark bytes and stale flags,
`first_dashboard_opened`, audits, notification events and delivery attempts,
alert rules, agent-command replay records, credentials, Keychain data, live
freshness, evidence availability, and onboarding markers are not portable.
The destination receives a newly validated local bookmark,
`first_dashboard_opened` resets to false, and evidence availability is
recomputed under the destination root.

Preview strictly rejects unsupported versions, unknown or duplicate JSON
fields, duplicate IDs or logical edges, any existing project or same-table ID
collision, dangling or cross-project references, invalid states, dependency
cycles, absolute or traversing evidence paths, symlinks, non-regular or
oversized input, and source changes between preview and apply. Invalid archives
do not degrade into partial records or generated Needs Review items. Import
revalidates the exact source bytes and all database/root collisions, then
creates the project, complete portable graph, destination root, fresh bookmark,
and one `release-radar-owner` / `Import portable Release Radar project archive`
audit in one store-owned transaction. Any failure rolls back the complete
operation. Historical audits are never restored or fabricated, source bytes
remain unchanged, and no notification, bridge request, onboarding marker,
network request, or content execution is produced.

The existing Rekon `docs/delivery/dashboard-status.json` importer remains a
partial one-time seed importer. Rekon JSON, arbitrary Markdown, repository
state, and copied SQLite databases are not portable complete-project archives.
Portable importer implementation remains blocked until an authoritative
exporter produces the acceptance fixture.

## Owner-approved continuity and companion direction — 2026-09-06

The owner selected these product policies. They control subsequent design while
leaving schemas, migrations, package encoding, delivery briefs and implementation
to their authorized slices. Other proposed architecture decisions remain proposed.

**Archive and remove from tracking:** Archive retains the complete project and
history, hides it from active views and suspends monitoring; Restore is reversible.
Remove from tracking removes the operational project and local access capabilities,
stops project monitoring and prevents pending app-owned actions from applying,
and retains read-only audit/activity history and a removal record. The confirmation
must state that history is retained. Both preserve repository files and other
projects. Re-adding the folder creates a new registration
that old requests cannot mutate. Removal is not full erasure; no erasure operation
or destructive action is authorized by this policy decision.

**Portable project package:** Export must contain the complete supported project
records, managed documents and evidence files, including historical provenance.
Supported goals, task plans, revisions, dependencies and later authoritative
features must be represented rather than silently omitted. Preserve domain and
artifact identities; use explicit destination root mappings and fresh folder
authorization. Source-code checkouts, credentials and device access permissions
are outside the package. Unavailable required content prevents a claim of complete
export. Imported history is source history, not a fabricated local audit or a
request to replay notifications or commands. Preserve the v1 rule that import
creates a new project, rejects live collisions and revalidates its exact input;
the package's file placement, failure recovery and database transaction must be
designed together before implementation. A self-contained project package is
distinct from a full application backup and from reversible project archiving.

**Full application backup and recovery:** The versioned app-backup package is an
app-created, integrity-checked snapshot of the supported local store, including configuration,
audits, retained history, plugin receipts and notification history. It excludes Keychain
credentials, repositories, portable project files and device permission grants. Restoration
uses adjacent no-follow staging, an explicit rollback marker, drained app-owned services and
a fresh store/service graph. It preserves readable newer historical and terminal notification
facts, disables backed-up pending sends, marks bookmarks stale and rotates live registration
authority so pre-recovery or root-only external commands cannot silently target restored work.
Interrupted replacement resolves before normal launch services start. Plugin inspection after
recovery is read-only and cannot register, rebind, install, remove or update the external plugin.

**Read-only companion authority:** The Mac app remains authoritative for delivery
state; repository documents retain their authoritative location and catalogued
identity. Cloud storage carries published copies for the read-only iPhone client,
including the selected operational documents, evidence and history, with explicit
publication and freshness information. Cloud and phone copies cannot independently
edit or accept delivery/document state. This replaces the companion draft's
cloud-source-of-truth and document-relocation direction. It does not authorize a
cloud deployment or settle the remaining RM8 feasibility, content-limit, privacy,
account, deletion-propagation, backup or recovery details. Publication is not a
backup or automatic authority takeover after Mac loss.

## RR-R3 ticket-goal identity — 2026-08-25

A ticket's approved goal is an explicit, persistent `(project, ticket, thread,
goal)` identity. The goal must belong to the ticket's existing linked thread,
and composite storage constraints preserve that relationship after later
observations. Project-local ticket/goal links are one-to-one:
`UNIQUE(project_id, ticket_id)` and `UNIQUE(project_id, goal_id)` reject
cross-ticket goal reuse transactionally.

Backfill occurs only when a candidate goal maps to exactly one ticket
project-wide; ambiguous legacy thread data remains unlinked and is never
recency-guessed.
Projections and notifications are read-only consumers of the approved identity.
Existing `tickets.outcome` remains the sole concise outcome; migration never
rewrites owner content.

## Prohibited alternatives

- Repository-backed dashboard manifests or recurring synchronization from arbitrary Markdown.
- Treating Rekon seed JSON, Markdown, repository state, or copied SQLite databases as portable complete-project archives.
- Direct SQLite access by agent tools, observers, helpers, or project processes.
- A combined read/write Codex integration or a generic shell/filesystem/JSON-RPC mutation surface.
- Credentials outside the app-owned Keychain boundary or credentials supplied to agents.
- A cloud delivery authority, browser-hosted localhost dashboard, folderless projects, or owner-facing manual transition controls. The owner-approved future read-only companion publication boundary above does not transfer authority or authorize deployment.
- Full Disk Access, Accessibility scraping, Codex database/rollout-file scraping, or presenting cached/fixture state as live.
- A persisted Ready lane or automatic lane transitions inferred from dependencies or runtime observation.

## Consequences

Later integrations must prove a supported sandbox-compatible transport before implementation. Unavailable observation remains explicit and stale rather than silently becoming authoritative. All delivery mutations are app-validated, transactional, and audited.

## Codex plugin lifecycle boundary — 2026-08-27

ADR-002 authorizes one separately signed, same-user, fixed-purpose helper for
the lifecycle of the single app-shipped `release-radar` Codex plugin. The
helper is not part of the agent runtime path: it cannot access SQLite, the app
group, project folders, credentials, networking, arbitrary commands, or ticket
mutations. The app remains sandboxed and Codex remains the owner of its plugin
configuration and cache.

This authorization is conditional on a signed, isolated feasibility gate that
proves the supported Codex CLI can perform confined marketplace and plugin
lifecycle operations, verify their postconditions, and distinguish a clean
managed install from modified or inconsistent content. Direct Codex
config/cache writes, HTTP, generic command execution, or expansion of the
existing mutation bridge remain prohibited.

## RR-05 feasibility outcome — 2026-08-24

Codex CLI `0.147.0` documentation and command help describe app-server clients
connecting through the transport selected when that app-server process starts.
The running Codex desktop app starts its app-server without an explicit listener,
which selects the parent-owned standard-input/standard-output transport. Process
and listener inspection found no supported named Unix or TCP listener through
which a separately sandboxed Release Radar process could authenticate and attach
to that already-running desktop task. Starting another app-server process would
not prove access to the desktop process's live task state.

The shared live-observation gate is therefore blocked. Release Radar does not
implement an app-server client, helper, or private-state reader for RR-05. It
retains the stable `CodexObserver` contract and normalized thread/goal models,
but its configured observer explicitly reports `unavailable`; an injected
last-known snapshot is always downgraded to `stale`. Neither state may be
presented as live or mutate a formal delivery lane. This is the approved
degraded dependency outcome for continuing to RR-07 after independent RR-05
review.

## Phase 5A placement amendment — 2026-09-09

The owner authorized unassigned tickets with permanent ticket identities, details,
task definitions, dependencies and evidence. Unassigned is placement state, not a
sixth lane or fake phase. Such tickets have neither phase nor execution lane and
cannot execute, complete tasks, request review or be accepted. First placement
into a same-project phase atomically enters Backlog while preserving identity and
all planning content/history. Existing signed typed app-owned operations, receipt
replay, actor/reason, project scope and sole-store-writer authority apply. New
planning views do not authorize owner-facing manual delivery mutations.
