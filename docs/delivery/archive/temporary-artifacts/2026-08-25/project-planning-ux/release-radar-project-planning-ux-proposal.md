# Unapproved design draft for independent review

# Release Radar project-planning visibility study

## Executive diagnosis

Release Radar currently presents a phase-execution dashboard as if it were a complete project view. The active phase is not merely emphasized; it is the effective query and navigation boundary.

Observed evidence:

- The installed `/Applications/ReleaseRadar.app` Projects screen shows each project’s active phase, current-work count, and attention count only.
- Project Overview repeats that active-phase summary and its five lane counts.
- Phase Board has no phase selector, project-wide work count, or indication that other phases or unscheduled work exist.
- Current projections query tickets only where `phase_id` equals the active phase. Dependencies are likewise phase-scoped.
- `TicketRecord.phaseID` and `tickets.phase_id` are non-optional. The current design has no app-owned representation for planned work before phase assignment.
- The durable ledger contains the concrete “owner-visible Back and Forward navigation” request under “Unscheduled product backlog,” but no current app surface can reveal it.
- The approved Phase Board and dependency mockups are explicitly phase-scoped. The dependency mockup also includes a distinct “Planned” node, suggesting planning context outside delivery lanes, while the ADR correctly preserves exactly five persisted delivery lanes.
- No controlling artifact for a separate Goals/History UX study was found in the searched design, delivery, architecture, plan, or `.superpowers` material.

The central usability failure is therefore semantic: the interface does not tell users that “this is the current phase,” because it behaves as though “current phase” and “whole project” are the same thing.

This report recommends a project-level planning surface that is distinct from phase execution. It is a design recommendation for independent review, not an approval.

## Primary user jobs and scenarios

Users need to:

1. Understand the whole project: what is current, upcoming, completed, and not yet scheduled.
2. See the current execution state without losing the project horizon.
3. Find planned work that has not been assigned to a phase.
4. Understand phase order, dependencies, readiness, and completion.
5. Move from portfolio → project plan → phase execution → ticket detail without losing context.
6. Recognize when a displayed board is only a subset of the project.
7. Review mature projects without allowing completed work to overwhelm active work.
8. Understand incomplete planning honestly after initialization or partial agent setup.
9. Request planning changes through the established agent workflow while retaining an owner read-only formal-transition UI.

Representative scenarios:

- A newly initialized project has a persisted folder and pending tracking setup but no phase.
- A partially planned project has one active phase plus several unscheduled requests, including Back/Forward navigation.
- A mature project has completed, current, and upcoming phases with dependencies between them.
- A project has no current phase but still has completed history and unscheduled work.
- Delivery data is available but Codex context is unavailable or stale.
- The local store or folder authorization is unavailable.

## Current-state information architecture

```text
Delivery
├── Projects
├── Needs Review
├── Notifications
└── Settings

Selected project
├── Overview
├── Phase Board
├── Dependencies
└── Activity
```

The apparent hierarchy is reasonable, but the project branch is actually an active-phase branch:

- Overview: active-phase name, counts, goal context, lane totals.
- Phase Board: active-phase tickets only.
- Dependencies: active-phase tickets and edges only.
- Activity: project activity, but visually adjacent to phase-only surfaces.

There is no route representing the complete plan, phase collection, future work, completed phases, or unscheduled work.

## Specific usability failures

### Required design corrections

1. **Hidden scope.** The board does not disclose that it is showing only one phase. It lacks “1 of N phases,” work-outside-this-phase counts, and a path to the full plan.

2. **Invisible planned work.** The Back/Forward request demonstrates the failure: planned work can be real and durable yet invisible because it is not phase-assigned.

3. **Overview redundancy.** Overview mainly repeats information already available on the project card and Phase Board. It does not answer a distinct project-level question.

4. **No phase discoverability.** There is no phase selector, phase list, upcoming work, completed phase history, or visible phase dependency structure.

5. **Terminology collision.** “Backlog” is already one of the five delivery lanes. Using “backlog” for work not assigned to a phase would make “project backlog” and “phase Backlog lane” indistinguishable.

6. **Execution state is overloaded as planning state.** The five lanes describe delivery progress inside a phase. They should not also be used to describe whether work is unscheduled, upcoming, or historically complete.

7. **Navigation-semantic collision.** In the installed app, the sidebar-collapse chevron was announced through accessibility as “Back” when expanded and “Forward” when collapsed, even though its help text was “Collapse Sidebar” or “Expand Sidebar.” This conflicts directly with the planned navigation-history feature.

8. **Selected-state accessibility mismatch.** During installed-app inspection, the accessibility tree repeatedly marked Needs Review as selected while the visible highlight was Overview or Phase Board. Screen-reader orientation is therefore not reliably aligned with visual location.

9. **Weak responsive hierarchy.** Collapsing the rail recovers space, but it does not solve project scope. Five compressed board lanes and an inspector still dominate while all non-current planning remains absent.

## Solution approaches

### Approach A — Project Plan plus scoped Phase Execution

**Recommendation**

Replace the thin Overview with a first-class **Project Plan**. Keep Phase Board as the focused execution workspace for one selected phase.

```text
Selected project
├── Project Plan
├── Phase Board
├── Dependencies
└── Activity
```

Project Plan contains:

- A persistent summary: total phases, current phase, unscheduled count, work outside the current phase.
- A first-class **Unscheduled work** section.
- Current phase, expanded by default.
- Upcoming phases, concise but discoverable.
- Completed phases, collapsed by default.
- Phase dependencies and ticket counts.
- A read-only detail inspector for the selected phase or planned item.

Phase Board gains:

- A phase selector grouped into Current, Upcoming, and Completed.
- A scope statement such as: “Showing Current phase · 1 of 4 phases.”
- A persistent link back to Project Plan.
- An explicit “3 unscheduled · 18 tickets in other phases” indicator when applicable.
- The unchanged five delivery lanes.

Trade-offs:

- Cleanest separation between planning and execution.
- Reuses existing project navigation and removes rather than adds a redundant Overview.
- Scales to mature projects without flattening every ticket into one surface.
- Requires explicit product semantics for phase lifecycle and project-level planned work.
- Adds one additional conceptual step before the board, mitigated by direct “Open current phase board” actions.

### Approach B — One everything-board

Show all phases and unscheduled work in a single large matrix, using phase rows and the five delivery lanes as columns.

Trade-offs:

- Maximum simultaneous visibility.
- Makes cross-phase movement and totals visually obvious.
- Quickly becomes enormous: five lanes multiplied by multiple phases, plus unassigned work.
- Mixes phase planning with execution state.
- Performs poorly at compact macOS widths.
- Encourages treating unscheduled work as a sixth lane or fake phase.
- Makes current execution less prominent and conflicts with the approved focused Phase Board language.

This approach is not recommended.

### Approach C — Dedicated Unscheduled Work screen plus phase selector

Keep Overview mostly intact, add a separate **Unscheduled Work** project route, and add a phase selector to Phase Board.

Trade-offs:

- Smallest conceptual change to existing screens.
- Gives unassigned work a clear destination.
- Fragments the project plan across Overview, Unscheduled Work, Phase Board, and Dependencies.
- Leaves Overview redundant.
- Makes users assemble the complete plan mentally.
- Encourages “out of sight” behavior because unscheduled work becomes another sidebar destination rather than part of the project story.

This is viable for a narrowly scoped release, but weaker than Approach A.

## Recommended information architecture

```text
Projects
└── Project Plan                           default project destination
    ├── Unscheduled work                   visible even when count is zero
    ├── Current phase                      emphasized
    ├── Upcoming phases                    summarized
    └── Completed phases                   collapsed by default

Project execution
├── Phase Board                            one explicitly selected phase
├── Dependencies                           phase path, with project-plan return
└── Activity                               operational audit/runtime history
```

Project cards should continue showing current phase and attention, but add compact completeness signals such as:

- `4 phases`
- `3 unscheduled`
- `Current: Post-MVP remediation`

Selecting a project should open Project Plan, not the current board.

## Representation of work not assigned to a phase

Use the term **Unscheduled work**.

Each item should show:

- Stable ID and concise outcome.
- “Not yet assigned to a phase.”
- Known dependency, blocker, evidence, goal, or Codex-link indicators.
- Latest meaningful update when available.
- Read-only detail.

Do not give unscheduled work a delivery lane. “Backlog” remains a phase-execution lane only. Do not invent a “Backlog phase”; it would be a fake phase, obscure planning completeness, and conflate lifecycle with delivery status.

The Back/Forward request would appear here as a concrete exemplar:

```text
Unscheduled work · 1

Navigation history
Owner-visible Back and Forward controls
Not yet assigned to a phase
```

Because owners do not control formal transitions, the item should not be draggable into a phase. Any reassignment remains agent-managed through the approved typed workflow.

## Discoverability without overwhelming execution

Use progressive disclosure:

- Current phase: expanded and visually primary.
- Unscheduled work: always named and counted, even when collapsed.
- Upcoming phases: visible as summary rows with phase name, dependency/readiness context, and ticket count.
- Completed phases: collapsed under “Completed phases · N.”
- Phase Board: continues to emphasize execution and never renders every project ticket.
- Persistent board scope text communicates hidden work numerically and textually, not only through color.

A user should never need to infer completeness from lane totals.

## Default project emphasis

The default project destination should be **Project Plan**.

The current Overview is too thin to justify remaining separate. Replacing it avoids adding another redundant screen and makes the distinction explicit:

- Project Plan answers “What is the complete project?”
- Phase Board answers “What is happening in this phase?”

## Navigation and interaction flows

### Portfolio to planning

```text
Projects
→ select project
→ Project Plan
```

### Planning to current execution

```text
Project Plan
→ select Current phase
→ Open Phase Board
```

### Explore another phase

```text
Phase Board
→ phase selector
→ Upcoming or Completed phase
```

The board header must retain the selected phase status and an easy return to Project Plan.

### Inspect unscheduled work

```text
Project Plan
→ Unscheduled work
→ select item
→ read-only detail
→ open linked Codex task when a valid link exists
```

No owner-facing phase assignment control is introduced.

### Navigation history

Future Back/Forward history controls belong in the standard window toolbar, with disabled states and conventional keyboard shortcuts. They must not share location, iconography, or accessibility labels with the sidebar collapse control.

Back/Forward means view history. Previous/next phase, if ever added, must use distinct labels.

## Terminology

| Concept | Recommended term | Avoid |
|---|---|---|
| Whole-project planning surface | Project Plan | Overview, Dashboard |
| Phase-level structure | Phase | Sprint unless product semantics change |
| Currently executed phase | Current phase | Active board |
| Five persisted states | Delivery lanes | Workflow phases |
| Work without a phase | Unscheduled work | Backlog, Unassigned |
| Future phase | Upcoming phase | Planned lane |
| Historical structural work | Completed phases | History |
| Operational record | Activity | Project history |
| Goal/runtime context | Goal context | Delivery state |

“Unscheduled” describes missing phase placement without implying missing ownership by a person. “Completed phases” stays separate from the unresolved Goals/History terminology.

## State behavior

### No projects

Retain the current Initialize/Attach onboarding hierarchy. Do not display an empty plan or invented phase.

### Newly initialized, tracking pending

Show a truthful setup state:

- Project is connected.
- Tracking state is waiting for agent definition.
- No Project Plan or Phase Board is fabricated.
- Existing Check Tracking Status and resumable handoff concepts remain applicable.

### Project exists, no current phase

Project Plan remains available if app-owned planned work or completed phases exist. Phase Board is unavailable with a clear explanation. Do not silently select an arbitrary phase.

### Partially planned

Show:

- Unscheduled count prominently.
- Current phase.
- Any known upcoming phases.
- A completeness cue such as “1 phase · 4 unscheduled items.”

### Current phase with no tickets

Show the phase as real but empty. The plan explains “No work is currently assigned to this phase.” The board may show the five empty lanes, but must not imply the entire project is empty.

### Mature multi-phase project

- Current phase expanded.
- Upcoming phases summarized.
- Completed phases collapsed.
- Counts remain visible.
- Selecting any phase opens its scoped board.
- Project Plan remains the stable home.

### Loading

Use one coherent project-plan skeleton or progress state. Avoid briefly showing zero unscheduled work or zero phases before data is loaded.

### Delivery data unavailable

Retain fail-closed local-store recovery. State whether project planning, phase execution, or both are unavailable. Do not substitute repository Markdown or cached fixture state.

### Codex unavailable or stale

Persisted Project Plan and delivery lanes remain available. Goal context is labelled unavailable or last-known exactly as today.

## Accessibility and keyboard navigation

Required design expectations:

- Explicitly expose the actual selected sidebar route; decorative SF Symbols must not supply selected semantics.
- Give the sidebar toggle the fixed accessible name **Toggle Sidebar**, with current-state help “Collapse Sidebar” or “Expand Sidebar.”
- Back and Forward use explicit labels, disabled states, and conventional `⌘[` / `⌘]` behavior if adopted.
- Announce phase context as “Current phase, Post-MVP remediation, 1 of 4.”
- Announce unscheduled items as “Not assigned to a phase.”
- Use text and symbols in addition to color for Current, Upcoming, Completed, Blocked, and Needs review.
- Support arrow-key movement through phase lists and work lists; Return opens; Escape returns from inspector/detail.
- Phase selector, scope link, lane headers, cards, and inspector should follow a stable focus order.
- No essential action depends on drag-and-drop or hover.
- Collapsed navigation retains accessible project and route names.
- Count badges include their noun: “3 unscheduled items,” not merely “3.”

## Responsive macOS behavior

### Wide windows

- Expanded 220-point sidebar.
- Project Plan uses a main phase/work list plus right-side inspector.
- Current, Upcoming, Completed, and Unscheduled are simultaneously discoverable.
- Phase Board retains the approved five-column layout and side inspector.
- Toolbar carries navigation history, project/phase context, and board density without duplicating sidebar actions.

### Compact windows

- Collapsed 96-point rail or native sidebar behavior.
- Project Plan becomes a single-column ordered list.
- The selected detail pushes in or appears below; it should not squeeze the phase list.
- Current phase stays first, followed by Unscheduled, Upcoming, and Completed disclosures.
- Phase Board uses compact-ID cards. Preserve all five lanes through horizontal board scrolling or another explicit lane-navigation treatment rather than compressing labels below readability.
- Phase and scope controls remain in a compact toolbar menu with accessible current values.
- The “work outside this phase” count remains visible; it must not disappear with the wide header.

## Data concepts implied by the design

These are semantic requirements, not schema prescriptions:

1. A project-scoped planned-work identity that can exist before phase placement.
2. A distinction between planning placement and delivery lane.
3. Phase lifecycle or equivalent semantics for Current, Upcoming, and Completed.
4. Stable phase ordering and phase dependency context.
5. Project-wide aggregates across phases plus unscheduled work.
6. A way to select and display non-current phase projections.
7. Project-level dependency visibility without changing the existing phase dependency view into an everything graph.
8. Audit evidence when agents create, place, or move planned work.
9. Reuse of existing evidence, goal, blocker, and Codex-link concepts where known.
10. Transient view-history state for Back/Forward, separate from persisted delivery state.

The design does not decide whether project-level planned work should use nullable phase membership, a separate planning record, or another app-owned representation. A “Backlog phase” is not recommended. That architecture decision belongs to the Architecture owner.

A critical authority issue remains: the ledger entry proves the need but cannot itself become UI data. Release Radar prohibits arbitrary Markdown synchronization and repository-owned dashboard state. Planned work must enter app-owned state through an approved authority path.

## Goals/History study boundary

No controlling artifact for the referenced separate Goals/History UX study was found.

This study should therefore reserve a seam rather than invent that redesign:

- Project Plan may show current or last-known goal context already supported by the product.
- Completed phases are structural project planning, not “History.”
- Activity remains the operational audit/runtime/notification record.
- This study does not define goal timelines, goal archives, historical goal detail, or replacement Activity navigation.

Owner decisions required before those areas converge:

1. Whether “History” means completed phases, audit activity, goal history, or a container for multiple types.
2. Which team/study owns goal-history navigation and terminology.
3. Whether Project Plan links into a future goal-history surface or only shows current/last-known context.
4. Whether Activity remains an independent project route.

## Assumptions and unresolved owner decisions

### Assumptions

- One current phase per project remains valid.
- Multiple phases and phase dependencies are valid app-owned concepts.
- Owners remain read-only for formal phase and ticket transitions.
- “Complete project” means all app-owned planned work, not repository scanning.
- Existing local-first, folder-backed, app-owned, no-cloud boundaries remain unchanged.
- The five delivery lanes remain exactly Backlog, In progress, Needs review, Blocked, and Accepted.

### Owner/Architecture decisions

- Authoritative representation and bridge contract for project-level planned work.
- Phase lifecycle and ordering semantics.
- Who may designate or complete the current phase and through which typed action.
- Whether ticket dependencies may span phases in the project-planning view.
- Whether completed phase membership is immutable or simply historical presentation.
- Persistence expectations for the last viewed phase and disclosure state.
- Goals/History seam ownership and terminology.
- Whether the Back/Forward item becomes the first acceptance exemplar for Unscheduled work.

## Recommendation classification

- **Required:** Make current phase scope explicit and expose the existence/count of work outside it.
- **Required:** Create a first-class representation for work not yet assigned to a phase.
- **Required:** Keep planning status separate from the five delivery lanes.
- **Recommended:** Replace Overview with Project Plan; retain Phase Board as scoped execution.
- **Recommended:** Use Unscheduled work, Current phase, Upcoming phases, and Completed phases.
- **Recommended:** Put future Back/Forward controls in the window toolbar and rename the sidebar toggle accessibly.
- **Not recommended:** Backlog phase, sixth “planned” delivery lane, or one everything-board.
- **Owner decision required:** data authority/model, phase lifecycle, cross-phase dependency semantics, and Goals/History ownership.

No repository, database, app-owned data, MCP contract, migration, or production artifact was changed.
