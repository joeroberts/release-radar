# ADR-001: Release Radar application boundaries

- Status: Accepted
- Date: 2026-08-23

## Context

Release Radar is a personal, local-first delivery dashboard for folder-backed projects. It must present agent-managed delivery state without turning project repositories, Codex runtime data, or notification credentials into competing authorities.

## Decision

Release Radar is a standalone, signed, sandboxed macOS application with bundle identifier `com.rekonlabs.ReleaseRadar`, minimum macOS version 14.0, and an app-owned Application Support data namespace derived from that bundle identifier. Delivery data is local app state and is never repository state or cloud state.

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
- A cloud backend, browser-hosted localhost dashboard, folderless projects, or owner-facing manual transition controls.
- Full Disk Access, Accessibility scraping, Codex database/rollout-file scraping, or presenting cached/fixture state as live.
- A persisted Ready lane or automatic lane transitions inferred from dependencies or runtime observation.

## Consequences

Later integrations must prove a supported sandbox-compatible transport before implementation. Unavailable observation remains explicit and stale rather than silently becoming authoritative. All delivery mutations are app-validated, transactional, and audited.

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
