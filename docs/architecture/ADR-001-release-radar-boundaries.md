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

## Prohibited alternatives

- Repository-backed dashboard manifests or recurring synchronization from arbitrary Markdown.
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
