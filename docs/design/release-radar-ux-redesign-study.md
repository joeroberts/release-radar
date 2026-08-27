# Release Radar UX redesign study — owner-review proposal

Design and validation only. The proposal uses illustrative persisted data and never claims live Codex state. It does not modify application code, approved mockups, brand originals, governing documents, or delivery phases.

> **Reconciliation status — 2026-08-26: Proposed / Unapproved and
> misaligned.** The all-phase Work Board overlaps the accepted phase-scoped
> Phase Board and proposed Project Plan; History overlaps accepted Activity;
> one-to-many goal links conflict with ADR-001's accepted one-to-one contract;
> semantic suggestions/confidence add unapproved authority; and the local
> Back-to-Goal flow does not define complete Back/Forward history. The study
> and its eight rasters remain proposal evidence only. Current status and
> sequencing are controlled by `docs/delivery/progress.md`.

## Recommendation

Use one workspace-level Goals route and retain the selected-project destinations that answer distinct questions:

| Destination | Question | Scope and durable default |
|---|---|---|
| **Goals** | Why are we doing the work, and what work satisfies each goal? | Workspace route; **All Projects + All goals**, including completed goals |
| **Overview** | What is the selected project's current snapshot, current work, and attention state? | Selected project |
| **Work Board** | What work exists, and what persisted delivery state is it in? | Selected project; **All phases** |
| **Dependencies** | What blocks or unlocks other work? | Selected project |
| **History** | What happened and when? | Selected project; chronological persisted events |

Rename Activity to **History**, with no separate Live Work screen. Rename Phase Board to **Work Board**. Work Board is clearest because it names the object managed, stays distinct from History, and avoids implying a phase-management surface. Delivery Board is too broad; Kanban Board foregrounds a mechanism; Activity Board conflicts with History.

The Work Board keeps the exact persisted lanes: **Backlog / In progress / Needs review / Blocked / Accepted**. Goals translates their relationship to a goal into **Planned / Underway / Blocked / Awaiting review / Completed** without renaming the stored board state.

## Current-state diagnosis

The installed app, canonical current source, and approved mockups were inspected together.

- Current navigation exposes Projects, Needs Review, Notifications, Settings, then project Overview, Phase Board, Dependencies, and Activity. Goals has no destination.
- Activity already projects a chronological record of audits, reviews, completions, runtime observations, and notification events. The content role fits History; the name does not.
- Phase Board is a five-lane execution board. Its name implies phase administration, while the current surface is ticket delivery state.
- The board projection resolves active phase before querying tickets, so the active phase currently acts as a visibility boundary. This conflicts with goal satisfaction work that spans stored phases.
- Runtime goal observation was unavailable during inspection. The mockups therefore use dated persisted observations and never show Live or imply a current check.
- The current board already offers **Full outcomes** and **Compact density**; the redesign preserves those exact labels and the current selection-to-inspector pattern.
- The approved `activity.png` screen is not adopted as the new History direction. Only its visual vocabulary and goal-card grouping inform Goals.

Source evidence:

- `ReleaseRadar/Navigation/AppRoute.swift:4-11,20-38` — current routes and labels.
- `ReleaseRadar/Projects/DashboardProjection.swift:30-69` — active-phase ticket query.
- `ReleaseRadar/Projects/DashboardProjection.swift:185-187` — current goal-link quality and observation freshness are not independently represented.
- `ReleaseRadar/Projects/DashboardProjection.swift:218-222` — persisted lane names.
- `ReleaseRadar/Projects/PhaseBoardView.swift:4-37,52,128` — board density control and selection behavior.
- `ReleaseRadar/Activity/ActivityView.swift:13-23,86-103` and `ProjectActivityProjection.swift:4-9,48-236` — chronological persisted event categories.
- `ReleaseRadarCore/Store/StoreMigrations.swift:474-479` — current v8 uniqueness constraints.

## Visual system alignment

The redesigned screens deliberately reuse the approved application's framing rather than introducing a separate dashboard style:

- 2048×1280 wide studies use the fixed dark sidebar, single top breadcrumb/status bar, deep navy stage, hairline dividers, muted blue-gray bordered surfaces, cyan selected-navigation rail, cyan primary actions, and generous panel spacing.
- Compact 900×650 studies retain the same chrome through an icon rail; every route remains reachable and named by tooltip/accessibility label.
- The actual supplied Release Radar icon artwork is shown with the deterministic `Release Radar / BY REKON LABS` and `Delivery / Local agent workspace` hierarchy. The copied raster is study input only and is not presented as a shipped asset.
- Headings, navigation, panels, and cards match the larger macOS-scale density of the approved set rather than the prior dense web-dashboard treatment.

Reference-by-reference fidelity:

- `phase_board.png` — application frame, sidebar proportions, top bar, board card treatment, exact lane order, and gray/cyan/amber/red/green lane accents.
- `dependencies.png` — selected-object inspector, substantial bordered surfaces, and separation between stored identity and observed status.
- `needs_review.png` — master/detail composition and an explicit owner-confirmation action for suggested links.
- `alerts.png` — grouped chronological rows, calm status hierarchy, and workspace-wide Notifications placement.
- `settings.png` — border, control, tab, and status-chip language.
- `onboarding_state.png` — large state symbols, 2×2 panel rhythm, clear actions, and a full-width error state.
- `activity.png` — restrained goal-card vocabulary only; its Live Work implication and screen role are intentionally rejected.
- `full_logo.png`, `icon.png`, `release-radar-icon-v1.png`, and `release-radar-lockup-v1.png` — actual mark and Release Radar/Rekon Labs hierarchy, without altering or claiming to ship the raster drafts.

## Considered approaches

### 1. One global Goals route plus project Work Board — recommended

All Projects + All goals is the default. Selecting a goal keeps the global route but names its project. View Work Board first selects that project, then opens its All-phases board with the goal filter and selected ticket.

Benefits: includes goals without work; keeps completed goals discoverable; makes cross-project context explicit; avoids duplicate global/local Goals screens.

Trade-off: requires workspace aggregation, restorable route state, and the approved goal-link cardinality change.

### 2. Project-local Goals

Benefits: simpler query and obvious local context.

Trade-offs: workspace goals and unlinked goals are easy to miss; a later workspace roll-up would duplicate the surface.

### 3. Goal overlay inside Overview or Work Board

Benefits: smallest navigation change.

Trade-offs: conflates Why with current snapshot or execution state, hides unlinked goals, and gives goals no durable workspace destination. Overview is retained, but only for its distinct current-project snapshot role.

## Information architecture and navigation

Workspace navigation:

- Projects
- Goals
- Needs Review — workspace-wide across all projects
- Notifications — workspace-wide across all projects
- Settings

Selected-project navigation:

- Overview
- Work Board
- Dependencies
- History

Global Goals never implies that a different project is active. Goal detail always names the goal's project. For example, selecting the `radar_service` goal while another project was previously selected remains a global Goals state; **View Work Board** selects `radar_service` before navigation, so sidebar and board context cannot disagree.

Compact navigation retains all routes through the icon rail or one native overflow. Icon routes require tooltips and accessibility names, and exactly one route is programmatically selected. Notifications is not omitted.

## Goals contract

- Default: All Projects + All goals. Completed and unlinked goals remain visible.
- Every goal row independently shows link identity and observation freshness.
- Link terms: **Persisted exact local link(s)**, **No exact local link**, and **No persisted linked work**.
- Observation terms: **Observation stale · date** or unavailable, plus **Source · persisted snapshot** in detail.
- Workspace banner states observer availability and, when useful, the newest persisted observation for the displayed scope. It does not imply a current check.
- Staleness applies to observed goal text/status, not persisted local lane state.
- Goal detail queries linked work across the selected goal's project and shows phase on every item before grouping into all five semantic goal states.

Unlinked goals create a workspace Needs Review item. An agent may offer a suggested ticket link, but the interface labels it as a suggestion, not a persisted exact link, and requires owner confirmation before linkage.

## Goal-to-Work Board flow

### Forward — View Work Board

1. Save Goals route, All Projects/project filter, All goals/status filter, selected goal, list/detail scroll, selected work item, and focus.
2. Select the goal's project.
3. Open Work Board with All phases, the visible goal filter, and optional selected ticket.
4. Land focus on the Work Board heading/filter summary and reveal the selected ticket and inspector.

Compact goal detail exposes both **Back to Goals** and **View Work Board** without relying on Escape. The standard macOS Back command (`⌘[`) also returns.

### Back to Goal

Returns to Goals and restores its exact route filters, selected goal, list/detail scroll, work selection, and focus.

### Clear goal filter

Stays on the selected project's Work Board, removes only the goal filter, restores the All-phases board, and gives sensible focus to the board heading/filter summary. It is not Back.

The five-panel flow image renders goal selection, all five semantic states, forward navigation, restored Back behavior, and stay-on-board Clear behavior.

## Work Board contract

**All phases** means every persisted ticket in every stored phase for the selected project. It is not lifecycle semantics and does not imply unobserved work exists. Goal counts are computed after the project-wide query. Goal deep links force All phases and show phase on every card. All phases is the durable default for this proposal.

Selecting a ticket preserves the current inspector pattern. Wide windows use the right inspector at the existing 1260-point threshold. Narrower layouts stack explicit selected-ticket detail. Both preserve outcome, phase, persisted exact goal link, observation state/source, requirements and unlocks, owner attention, and evidence/audit/notification context.

Compact density is based on available lane width. All five lanes remain horizontally recoverable; edge fade and position cues expose Accepted at the end. Full Keyboard Access and VoiceOver traversal auto-scroll the focused lane or card into view.

## History contract

History remains the chronological selected-project record of persisted audits, reviews, completions, goal observations, and notification events. It uses stored lane names such as **Needs review → Accepted**. Observer availability may appear in a transient banner; it is not fabricated as a persisted history event.

Each event is one accessibility row with event type/source, full local date-time, title, summary, and provenance. Rich normalized transition titles may require projection/data work if stored fields do not contain both prior and new state.

## Data and route implications — no implementation

The study's proposed target is **1:N: one goal may link many tickets; each ticket may link at most one goal**. ADR-001 currently accepts one-to-one ticket/goal identity, so this target requires a separate explicit owner and architecture decision. The current implementation uniquely constrains both project+ticket and project+goal. This conflict remains explicit in the report and explanatory goal-to-work flow; it is intentionally omitted from simulated product screens.

The later data contract must:

- remove the goal-side uniqueness while retaining ticket-side uniqueness;
- retain project + thread + goal identity;
- define migration/collision handling;
- preserve exact linkage separately from observation provenance and freshness;
- never promote agent suggestions to exact links without owner confirmation.

Conceptual navigation requirements:

- `goals(projectFilter?, statusFilter?, goalID?, workID?, restorationState)`
- `workBoard(projectID, phaseScope: all, goalID?, selectedTicketID?, returnContext?)`
- `dependencies(projectID, phaseScope?)`
- `history(projectID, eventFilter?)`

These are behavior implications, not implementation prescriptions.

## Empty, unavailable, stale, and error contracts

Goals distinguishes workspace empty, project empty, filter-zero, query error, known project with no cached observation, stale observation, and unlinked state. Copy says no persisted records or observations; it does not assert that authoritative goals do not exist.

Work Board distinguishes no persisted tickets across stored phases, a filter-zero result with Clear action, and a load error that retains the selected project's identity without substituting another project.

History distinguishes no persisted events, an event-filter-zero result with All events action, and a load error that retains project identity and offers retry.

The state-sheet PNG focuses on Goals while this report defines the Board and History contracts.

## Responsive behavior and macOS accessibility

Responsive behavior follows available width and content fit; 760×520 is a validation minimum, not a Goals-specific hard breakpoint. Master/detail remains split while both panes fit, then moves to a native single-pane detail with visible Back. The board's existing inspector threshold remains 1260; lane density responds to lane width, and compact board recovery is horizontal.

Accessibility requirements:

- native macOS control sizing and hit regions;
- Full Keyboard Access, visible focus rings, `AXSelected`, and exactly one selected route;
- verification with Accessibility Inspector;
- Larger Text/accessibility text sizes, Increase Contrast, Differentiate Without Color, Reduce Motion, and Reduce Transparency;
- full accessibility names and tooltips for icon routes and truncated filters;
- named lane groups/cards including lane, ticket, phase, and selection;
- auto-scroll on keyboard/VoiceOver traversal;
- separate History AX rows with type/source, full local date-time, title, summary, and provenance;
- distinct names and focus restoration for Back, Back to Goal, View Work Board, and Clear goal filter.

## Proposed choices captured from owner-review direction

Within this study only, the proposal treats these choices as settled inputs:
Overview retained; Needs Review workspace-wide; Notifications workspace-wide;
1:N goal-to-ticket target; All phases durable default; unlinked goals create
Needs Review with owner-confirmed agent suggestions; completed goals visible by
default; responsive switching based on available width/content fit. They do
not override ADR-001, the accepted base design, or the delivery ledger.

No additional owner decision is required to understand the proposed IA or interaction. Production asset status for the supplied raster brand drafts and implementation/migration details remain outside this design study. The entire proposal still requires explicit owner approval before product work is scheduled or implemented.

## Artifacts for review

- `docs/design/mockups/goals.png` — 2048×1280
- `docs/design/mockups/goals_compact.png` — 900×650 selected-detail state with Back and View Work Board
- `docs/design/mockups/work_board.png` — 2048×1280
- `docs/design/mockups/work_board_compact.png` — 900×650, Compact density, horizontal recovery, stacked inspector
- `docs/design/mockups/history.png` — 2048×1280
- `docs/design/mockups/history_compact.png` — 900×650
- `docs/design/mockups/goals_data_states.png` — 2048×1280
- `docs/design/mockups/goal_to_work_flow.png` — 2048×1280
- `docs/design/release-radar-ux-redesign.html` — editable design-study source
- `docs/brand/release-radar-icon-v1.png` — selected brand reference

The renderer source named by earlier study notes is not tracked. It is not a
controlling or required artifact; the tracked HTML and PNGs above are the
complete retained proposal package.

This is an owner-review proposal, not a completed or approved production
change. Its rasters are not accepted product mockups.
