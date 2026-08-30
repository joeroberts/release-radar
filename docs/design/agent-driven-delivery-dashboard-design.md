# Release Radar By Rekon Labs — agent-driven delivery dashboard design

## Decision

Replace the Rekon-specific static delivery Kanban with a separate, native macOS
application for the owner's personal use across any folder-backed project. The
application is an agent-driven operational view: agents own delivery structure
and delivery transitions; the owner uses the application to see current work,
progress, dependencies, requests for review, blocks, and notification history.

The application does not write delivery state into project repositories and does
not ask agents to maintain a parallel JSON dashboard. It keeps its own local
state and links back to project documents as evidence.

## Goals

- Show all onboarded projects and their current delivery health before drilling
  into a phase-level Kanban board.
- Make every ticket understandable in board view: its outcome, delivery state,
  goal state, dependencies, attention required, and evidence must be visible.
- Present live Codex thread and goal state only when a supported authenticated
  observation transport exists; otherwise show truthful unavailable or
  persisted-last-known stale context without agent-authored duplication.
- Let agents manage phases, tickets, dependencies, delivery status, outcome
  text, evidence, and review requests through structured local app actions.
- Send Pushover notifications from the app for blocks, task completion, and
  review requests, with a durable local delivery record and de-duplication.
- Require a local folder for every project. Discover Codex work in that folder
  and its worktrees automatically; remember excluded exceptions.

## Non-goals

- No repository-backed dashboard state, committed manifest, or recurring
  synchronization with a project folder.
- No manual phase/ticket editing surface for the owner.
- No attempt to infer canonical delivery state from arbitrary Markdown.
- No cloud backend, multi-user sharing, web app, or browser-hosted localhost
  dashboard.
- No direct agent access to the app database or Pushover credentials.

## Architecture

The app is a menu-bar-capable SwiftUI macOS application with a local SQLite
database. It has two integrations:

1. A bounded read-only Codex observer may list and read linked threads, goals,
   runtime statuses, and streamed changes only after a supported authenticated
   transport is proven. The current configured observer reports unavailable;
   injected persisted observations are explicitly stale.
2. A local agent tool interface exposes narrow, structured commands to create
   and update delivery records. The app remains the sole database writer.

The Pushover client is app-owned. Its credentials live in Keychain. Agents do
not submit raw HTTP requests or handle credentials.

```mermaid
flowchart LR
  Folder["Project folder"] --> App["Native delivery app\nlocal SQLite"]
  Codex["Supported Codex observer\nwhen available"] --> App
  Tools["Local agent delivery tools"] --> App
  App --> UI["Project overview\nand phase Kanban"]
  App --> Push["Pushover"]
  Push --> Owner["Owner"]
  Owner --> Chat["Codex conversation\nvalidate or redirect"]
  Chat --> Tools
```

## State ownership

The SQLite database has four distinct record groups:

| Group | Authority | Contents |
| --- | --- | --- |
| Delivery structure | Agents via app tools | Projects, phases, tickets, outcome text, dependencies, evidence references, ticket-to-Codex links, exclusions. |
| Observed runtime state | Codex App Server | Thread status, goal text/status, waiting-for-input, last observed time, and connection freshness. |
| Operational audit | App | Every agent delivery update and observed meaningful runtime change, attributed to its originating Codex thread when available. |
| Notification history | App | Pushover event fingerprint, attempted/sent/failed state, provider receipt when returned, acknowledgement, and related ticket/goal. |

The app validates only data integrity: valid project and ticket references,
project-bound thread links, dependency acyclicity, and atomic audit creation.
It does not impose delivery gates or reserve Accepted for a manual app action.

Observed Codex state is display context, not an implicit delivery transition.
For example, a ticket may remain In progress while its linked goal is shown as
Blocked. A block can alert the owner immediately; an agent records any formal
ticket lane/phase change through the delivery tools.

## Agent tool contract

Agents receive local actions to:

- create or update a phase or ticket;
- set a ticket's plain-language outcome, phase, lane, dependencies, evidence,
  and linked Codex task;
- request review or record a completion;
- resolve or dismiss an import-review item.

Each action includes an explanatory reason, executes transactionally, and
produces an audit event. Invalid references, cross-project links, or dependency
cycles fail clearly and make no partial update. Agents may make any delivery
transition, including Accepted, after obtaining owner validation through the
normal Codex conversation.

## Onboarding

Add Project presents distinct, clearly labelled choices. **Attach Folder to
Existing Project** selects an eligible persisted rootless project first, then a
folder, and names both in confirmation. It preserves the project's complete
delivery history and uses the minimum explicit owner decision; it never runs
new-project preparation or import.

**Import Existing Project** is complete-project restoration from the approved
versioned portable Release Radar archive. It shows a validation preview before
writing, creates a new project atomically, rejects collisions instead of
overwriting or remapping, and creates fresh local folder authorization.
Release Radar's Markdown delivery records and the Rekon seed JSON are not that
archive. The import workflow remains unavailable until an authoritative
exporter and exporter-produced fixture exist.

New folder-backed projects use **Initialize Project Tracking**. Folder
selection and discovery are preview-only. Before the durable write, the app
names the project and folder and explains that initialization saves local
Release Radar state and folder authorization without modifying repository
files. After the write, closing preserves resumable pending setup.

If no usable delivery structure is found, the app presents a truthful
owner-mediated Codex handoff. It shows the exact prompt below with an
icon-only overlapping-squares copy control labelled **Copy Codex prompt**,
confirms the copy visibly and through accessibility, and does not launch,
contact, paste into, or submit to Codex. Only the prompt is copied; it contains
no folder path or project content.

> In this Codex task rooted at the selected repository, explicitly invoke and
> follow the installed `$release-radar:release-radar` skill. You are authorizing this task to
> create or update only the Release Radar managed guidance block in the
> selected repository's root AGENTS.md, and to create
> docs/delivery/progress.md only if it is absent, while preserving every other
> instruction and all existing delivery content. Follow the skill's repository
> handoff: write and read back the permitted repository guidance first, record
> that exact `AGENTS.md` with the existing ticketless Release Radar evidence
> mutation, preserve the complete request across uncertain outcomes, and report
> any pending audit or discrepancy instead of guessing.
> Do not invent an MCP repository-read operation, access Release Radar SQLite,
> infer canonical state from arbitrary Markdown, or guess; send uncertain items
> to Needs Review.

Portable Import remains hidden until its exporter/archive gate opens. The
owner-approved future Help section is deferred and is not part of onboarding
initialization.

For new folder-backed project onboarding:

1. The owner selects a local project folder. The app retains a local
   security-scoped bookmark and discovers the Git root and worktrees.
2. If a supported observer exists, it may discover Codex threads whose working
   directory is that folder or a subfolder, including matching worktrees. With
   no supported observer, discovery is unavailable rather than inferred from
   private state. Explicit exclusions remain durable when observations exist.
3. The app recognizes only explicitly supported seed artifacts and offers a
   seed preview. The current one-time Rekon seed importer reads its supported
   schema-version-1 dashboard JSON; Markdown roadmaps, task briefs, handoffs,
   and ledgers remain evidence rather than import authority. Seed import does
   not restore a complete portable project or establish ongoing synchronization.
4. Confidently mapped phases/tickets/dependencies are imported. Ambiguous
   items, possible duplicates, unmatched threads, and missing outcome text go
   to a Needs review inbox instead of blocking onboarding.
5. If no usable delivery structure is found, initialization remains saved and
   resumable until the owner uses the displayed prompt in the current task
   already rooted at the selected folder to invoke the installed skill,
   preserve or create the applicable repository guidance and
   minimum delivery ledger, and establish the project's current tracking state
   through audited ticketless evidence. Completion still requires a persisted
   active phase, but the owner-facing workflow does not call it the "first
   phase." The app never invents a default phase, claims an agent was
   contacted, writes repository files, or treats missing desktop observation as
   Codex unavailability.
6. The app creates no Pushover alert during onboarding. It may notify about
   outstanding review items only after the owner has opened that project's
   dashboard once.

## Dashboard model

### Project overview

The home screen lists projects with their active phase, verified persisted or
truthfully unavailable/stale goal context, current work count, and attention
count. A project is always represented by a folder-backed record; there are no
folderless planning projects.

### Phase board

The project board contains a selected phase, phase dependencies, Codex sync
freshness, active goals, and last notification. The later approved visual
design supersedes the earlier Ready-lane proposal. Its lanes are:

1. Backlog
2. In progress
3. Needs review
4. Blocked
5. Accepted

Dependency eligibility is derived information available in detail and agent
workflow context. It is not a separate lane and never causes an automatic
delivery transition.

A separate, visible Needs review inbox contains uncertain imports, possible
duplicates, unresolved dependencies, excluded/untracked task candidates, and
agent-requested owner review. It is a first-class attention surface, not an
empty-state message.

At full width, each card shows its ticket ID, concise agent-maintained outcome,
dependency count, and blocker count. At compact widths it shows only the ticket
ID and counts. Lane position communicates delivery state, so cards do not
repeat it.

Selecting a card opens a read-only detail view with full outcome, dependency
graph and direction, linked Codex task/goal and verified persisted or
truthfully unavailable/stale state, owner-attention reason, latest meaningful
update, evidence, audit history, and notification delivery history. Opening a
linked Codex task is available only after a separate supported handoff is
proven; the detail contains no manual delivery editing controls.

## Notification policy

The app sends Pushover only for meaningful events:

- a linked Codex goal becomes Blocked;
- an agent records task completion or requests review; or
- a ticket or import item enters Needs review.

Each notification event has a durable fingerprint. Reconnects, page refreshes,
or app restarts never resend an identical event. A later resolved-and-reentered
state creates a new event and may send a new alert. Failed/misconfigured
Pushover attempts are recorded and visible; they do not prevent dashboard use.

Paused goals are shown explicitly but do not alert by default.

## Failure behavior

- If Codex is offline or unavailable, the app displays the last observed state
  and timestamp instead of presenting stale state as live.
- If a linked project document is moved or removed, its evidence link is marked
  unavailable and historical imported state remains intact.
- Agent-tool validation failures return actionable errors and make no partial
  write.
- Pushover problems create an audit/notification failure record without
  exposing credentials.

## Visual reference status — 2026-08-26

The accepted wide mockup vocabulary remains:

- `docs/design/mockups/phase_board.png`
- `docs/design/mockups/dependencies.png`
- `docs/design/mockups/needs_review.png`
- `docs/design/mockups/alerts.png`
- `docs/design/mockups/settings.png`

`docs/design/mockups/activity.png` remains a historical supported-observer
concept. Its live/synced wording is not authority for current behavior; ADR-001
requires unavailable or persisted-last-known stale context until a supported
authenticated attachment exists.

`docs/design/mockups/onboarding_state.png` is superseded visual evidence. Its
“Ask agent to define first phase” action and Portable Import implication do not
match the accepted **Initialize Project Tracking** copied-not-sent handoff or
the exporter/archive gate above. Preserve the image for history, but do not use
its copy as a current product requirement.

Completed Projects/Overview, selected-ticket detail, and compact-board behavior
are covered by durable runtime evidence under `docs/delivery/evidence/`; they
are not missing-work mockup candidates. Goals, all-phase Work Board, History,
and their compact/state/flow images remain proposal evidence only. Their
current classification and decision gates are recorded exclusively in
`docs/delivery/progress.md`.

## Acceptance criteria

1. Onboarding any local folder preserves a resumable **Initialize Project
   Tracking** state, discovers matching Codex threads/worktrees only when a
   supported observer exists, remembers exclusions, and requires persisted
   current tracking state before completion without owner-facing “first phase”
   or false automatic-agent language. Its copied prompt operates in the current
   task rooted at the selected folder and explicitly invokes
   `$release-radar:release-radar`; owner-requested initialization preserves or
   creates applicable repository guidance and the minimum pending-audit ledger,
   reads it back, then records the actual `AGENTS.md` with existing ticketless
   evidence without an invented MCP API.
2. Rekon's importer produces local phases/tickets/dependencies/evidence links
   from its existing delivery records, routing uncertain mappings to Needs
   review rather than silently guessing.
3. The responsive board follows the approved five-lane compact-card design:
   full-width cards show ticket ID, outcome, dependency count, and blocker
   count; narrow cards show ID and counts; the selected read-only detail view
   communicates goal state, dependency direction, attention, activity, and
   evidence.
4. When supported Codex observation exists, runtime updates refresh the live
   goal display and show a last-sync timestamp without silently changing formal
   delivery lanes. Otherwise the UI truthfully presents unavailable or
   persisted-last-known stale context.
5. Agent delivery actions are atomic, audited, attributed, and reject invalid
   references/cycles without partial state.
6. Block, completion/review, and Needs review events create one deduplicated
   Pushover attempt with visible delivery history; paused goals do not notify
   by default.
7. The dashboard remains useful when Codex, Pushover, or linked evidence is
   unavailable, with clear stale/error state rather than hidden failure.
