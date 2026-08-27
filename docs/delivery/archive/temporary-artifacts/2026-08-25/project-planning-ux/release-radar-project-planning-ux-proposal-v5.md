# Release Radar Overview + Recorded Project Plan UX Proposal

| Field | Value |
|---|---|
| Revision | v5 |
| Date | 2026-08-25 |
| Author | Independent UX Research / Design Lead (Codex) |
| Status | Proposed / Unapproved |
| Scope | Design-only project-planning visibility proposal |
| Approval effect | Owner approval unlocks only the polished-screenshot design stage |

This document is not an implementation plan, architecture approval, delivery approval, or product acceptance. It makes no code, database, MCP, migration, phase-assignment, repository, or production-artifact change.

## 1. Decision framing

### Problem outcomes that must be solved

1. A user must be able to understand the complete app-owned plan recorded for a project, not only the current phase.
2. App-owned planned work not yet placed in a phase must have a truthful, first-class surface.
3. A phase board must state that it represents one selected phase and must disclose work recorded outside that phase.
4. Planning placement and phase lifecycle must remain distinct from the five persisted delivery lanes.
5. The UI must distinguish a verified zero from data that is loading, unavailable, historically imported, or incomplete because unresolved candidates exist.

### Recommended visible-UX choice

Retain **Overview** as the default project landing and executive snapshot, add **Project Plan** as a distinct sibling planning surface, and retain **Phase Board** as a read-only execution view for one explicitly selected phase. This owner-directed structure is Approach A below and remains Proposed / Unapproved until final Gate-1 owner approval.

### Deferred decisions

The exact schema, migration, mutation bridge, import/export format, lifecycle transition mechanics, request transport, and persistence implementation are Architecture and Planning work after visible-UX approval. This proposal does not claim that the current bridge supports project-level planned work or phase lifecycle actions.

### Owner decision record

On 2026-08-25, the owner directed that **Overview remain a distinct surface and the default project landing page**, with Project Plan added as a sibling route. Overview is the executive “right now” snapshot; Project Plan owns complete recorded planning structure. This direction is incorporated into v5 but remains subject to final v5 Gate-1 owner approval.

## 2. Controlling-artifact register

The following artifacts controlled this design investigation:

| Artifact | Role in this proposal |
|---|---|
| AGENTS.md | Repository delivery, design-reference, role-independence, security, and evidence constraints |
| docs/delivery/progress.md | Current delivery truth, accepted baseline, unphased Back/Forward exemplar, and owner-only acceptance gate |
| docs/design/agent-driven-delivery-dashboard-design.md | Product goals, app-owned authority, five-lane execution model, owner read-only boundary, onboarding, failure, and detail requirements |
| docs/architecture/ADR-001-release-radar-boundaries.md | Local-first app boundary, sole database writer, five lanes, typed mutation boundary, archive constraints, sandbox, and prohibited alternatives |
| docs/superpowers/plans/2026-08-23-release-radar-mvp.md | Approved MVP task and navigation boundaries |
| docs/brand/README.md | Approved Release Radar identity and visual-direction constraints |
| docs/design/mockups/phase_board.png | Phase-scoped five-lane execution reference |
| docs/design/mockups/dependencies.png | Phase-scoped selected ticket dependency-path reference |
| docs/design/mockups/needs_review.png | Unresolved-candidate and owner-decision reference |
| docs/design/mockups/activity.png | Existing goal-context and operational-state presentation reference |
| docs/design/mockups/onboarding_state.png | Incomplete initialization and recovery reference |
| docs/design/mockups/alerts.png | Notification surface reference; excluded from Recorded Project Plan membership |
| docs/design/mockups/settings.png | Configuration surface reference; unchanged by this proposal |
| docs/design/mockups/full_logo.png | Brand reference |
| docs/design/mockups/icon.png | Brand reference |

The dependency mockup's example “Planned” node is treated only as visual evidence that planning context was contemplated. It is not authority for a sixth lane, a planning state, or a data model.

## 3. Research method and evidence manifest

### Method

- Read every controlling artifact named above.
- Inspected all approved mockup PNGs at original resolution.
- Used current on-disk CodeGraph evidence first for focused source discovery, then narrow source inspection for exact route, projection, phase, ticket, and migration facts.
- Inspected the installed app through macOS accessibility and screenshots across Projects, Overview, Phase Board, expanded/collapsed navigation, and compact-rail behavior.
- Performed no app data, database, repository, MCP, migration, or production mutation.

### Evidence identity

| Evidence | Recorded fact |
|---|---|
| Repository HEAD during study | 575d62cc6160fc9ed65e944bbe667ee6bbf79d27 |
| Working tree | Substantial pre-existing dirty changes; this study does not attribute them to itself |
| Accepted product baseline in ledger | 271fcd4 |
| Installed runtime | /Applications/ReleaseRadar.app |
| Runtime version/build | 0.1.0 / 1 |
| Runtime identifier | com.rekonlabs.ReleaseRadar |
| Runtime CDHash | 893c9deab194bfbfbffc8a3966cb92e3c84f448b |
| Main executable SHA-256 | 1cce7f95fc18af8c95f855a1cc4a562795b6ff6a9bc79d0207a6e6f0d57282ee |
| Observed runtime size | Approximately 1224 × 768 |
| Approved UI mockups | 1586 × 992 visual controls |
| Source basis | Current on-disk CodeGraph/source evidence |

No mapping is claimed between the installed runtime and the current dirty source tree. Installed-runtime observations and current-source findings are separate evidence streams.

### Key observed facts

- Projects and Overview expose only the active phase, current work, attention, and compact goal context.
- The Phase Board has no project-wide recorded-plan scope or phase collection.
- Current dashboard and dependency projections filter to one phase.
- Current TicketRecord and tickets.phase_id require phase membership.
- The durable ledger records an unscheduled Back/Forward request that the app cannot currently represent or show.
- The installed sidebar toggle was announced as Back/Forward by accessibility, and the accessibility selected route did not consistently match the visible route. These are evidence about the current experience, not remediation scope for this proposal.

## 4. Compact current-experience findings

### Primary user jobs

Users need to:

1. Understand how a project is doing right now from a concise executive snapshot.
2. Understand the Recorded Project Plan across current, upcoming, completed, unknown/unordered, and unscheduled work.
3. Focus on one phase's execution without mistaking it for the whole recorded plan.
4. Find unresolved intake that may mean the recorded plan is incomplete.
5. Inspect phase and work context without making owner-authored formal transitions.
6. Move from portfolio health to Overview, planning structure, phase execution, dependencies, and operational activity while retaining scope.
7. Recover truthfully when local storage, folder authorization, or Codex context is unavailable.

### Representative scenarios

- **New initialization:** a folder-backed project is saved but tracking definition is pending; no Overview metrics, phase, or plan is fabricated.
- **Partial plan / unresolved intake:** Overview shows the Current-phase snapshot plus recorded-plan coverage and an incomplete warning; Project Plan shows authoritative Unscheduled work while separate Needs Review candidates remain excluded.
- **Mature multi-phase:** Overview summarizes right-now health and project-wide coverage; Project Plan exposes Current, Upcoming, Completed, and possibly Unknown / Unordered phases with explicit counts and relationships.
- **No Current phase:** Overview says “No current phase recorded,” shows Recorded phases, Unscheduled work, and Recorded work with no Current phase; marks Current-phase active work and attention “Not applicable — no Current phase”; keeps unresolved-candidate incompleteness separate; retains View Project Plan; and offers no Current-board launch.
- **Store recovery:** the authoritative store is unavailable, so Overview, plan, and execution fail closed.
- **Folder recovery:** Overview and Project Plan remain visible from a healthy store while folder-dependent evidence/actions require reauthorization.
- **Codex recovery:** persisted Overview metrics and plan remain visible while runtime/goal context is stale or unavailable.

### Current-state information architecture

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

Although this appears project-scoped, the installed experience and current projections make it effectively active-phase-scoped: Projects and Overview summarize the active phase, Phase Board loads that phase's tickets, and Dependencies loads ticket paths only for that phase. Activity is project-scoped but sits beside these phase-scoped surfaces.

### Specific usability failures grounded in evidence

1. **The displayed subset is not named.** The installed Phase Board names the phase but does not state that other recorded phases or unscheduled work may exist.
2. **Unscheduled planned work has no app surface.** The ledger's Back/Forward request is durable evidence of the need, but repository text is excluded from app authority and the current app has no authoritative project-level planned-work representation.
3. **Overview currently creates a false-whole impression.** It shows active-phase counts, attention, and goal context without project-wide coverage signals, an incomplete-intake warning, or a clear route to planning structure.
4. **Phase discovery is absent.** There is no current-state phase collection or explicit lifecycle grouping from which a user can inspect non-current phases.
5. **Execution lanes are at risk of being mistaken for planning state.** The approved five lanes describe delivery inside a phase and cannot truthfully represent unscheduled placement or phase lifecycle.
6. **Zero and unknown are not sufficiently distinguished at project-plan level.** The current experience has no Recorded Project Plan load state, incomplete-intake signal, or project-wide count contract.
7. **Navigation accessibility evidence is inconsistent.** The installed sidebar toggle was announced as Back/Forward and the accessibility-selected route did not consistently match the visual route. Those defects are separate remediation scope, but the new Project Plan route must have one matching visual/accessibility selection contract across the complete visible navigation.

These failures support the owner-directed separation of jobs: Overview becomes an explicitly scoped executive snapshot, Project Plan becomes the planning-structure surface, and Phase Board remains scoped to one selected phase. This v5 remains Proposed / Unapproved.

## 5. Truthful scope: Recorded Project Plan

The owner-facing name for completeness is **Recorded Project Plan**, not “complete project” without qualification.

### Included membership

The Recorded Project Plan contains only authoritative app-owned planning records:

1. Explicitly recorded project phases.
2. Explicitly recorded work identities assigned to those phases.
3. Explicitly recorded unscheduled planned-work identities not assigned to a phase.
4. Explicitly recorded planning relationships among those phases or planned-work identities.
5. Existing compact current/last-known goal context displayed as context, not as plan membership.

### Excluded from membership, but signposted where relevant

The following are not counted as Recorded Project Plan membership:

- Open or unresolved Needs Review candidates.
- Unlinked or merely observed Codex tasks and goals.
- Repository Markdown, plans, ledgers, task briefs, or handoffs.
- Activity and audit entries.
- Goal records or goal history.
- Notifications and delivery attempts.
- Import candidates that have not committed as authoritative plan records.
- Cached, stale, or imported historical runtime observations.

When any excluded candidate may indicate missing plan intake, the UI must say that the Recorded Project Plan may be incomplete and link to the appropriate existing review surface. It must not silently count candidates as planned work.

### Non-overlapping count definitions

After a successful authoritative load:

- **Recorded phases** = distinct authoritative phases in the project.
- **Scheduled work** = distinct authoritative planned-work identities with one recorded phase membership.
- **Unscheduled work** = distinct authoritative planned-work identities with no phase membership.
- **Recorded work** = Scheduled work + Unscheduled work.
- **Selected-phase work** = scheduled work whose phase membership equals the selected phase.
- **Current-phase work** = scheduled work whose phase has explicit lifecycle Current.
- **Work outside selected phase** = Recorded work − Selected-phase work.
- **Work outside Current phase** *(only when exactly one explicit Current phase exists)* = Unscheduled work + scheduled work in every non-Current phase.
- **Recorded work with no Current phase** *(only when no explicit Current phase exists)* = Recorded work; this label replaces Work outside Current phase in that condition.
- **Current-phase active work** *(only when exactly one explicit Current phase exists)* = Current-phase work in Backlog, In progress, Needs review, or Blocked lanes.
- **Current-phase accepted work** *(only when exactly one explicit Current phase exists)* = Current-phase work in Accepted.
- **Current-phase attention** *(only when exactly one explicit Current phase exists)* = Current-phase work in Needs review or Blocked.
- **Unresolved candidate count** = open candidate records in Needs Review that are excluded from Recorded work.

Each work identity is counted once in Recorded work. Unresolved candidates, observations, activities, goals, and notifications never inflate these counts.

### Zero, unknown, and incomplete

- Show **0** only after the authoritative plan load succeeds and the relevant set is verified empty.
- Show **—** with “Loading” while a load is in progress.
- Show **Unavailable** when the authoritative store cannot supply the set.
- Show **Recorded plan may be incomplete · N unresolved candidates** when Needs Review contains relevant unresolved intake.
- Show **Historical last-known context** for imported observations; never count it as current plan or live execution.
- When no explicit Current phase exists, render Current-phase active work and Current-phase attention as **Not applicable — no Current phase**, never as 0 and never as an aggregate of non-Current phases. Use **Recorded work with no Current phase** for all Recorded work; do not use Work outside Current phase.

## 6. Formal planning authority and owner-mediated request loop

### Authority boundary

Unscheduled-work existence, phase membership, planning relationships, phase lifecycle, and phase order are formal app-owned state. Owners remain read-only for these formal transitions.

No visible plan mutation occurs until one of the following future authorities commits:

1. A separately approved, narrow, typed, versioned, project-scoped, app-validated, transactional, audited agent action; or
2. A separately approved atomic authoritative import.

The current bridge is not claimed to support these concepts. Repository text, clipboard actions, Codex observation, timestamps, goals, dependencies, or lane positions cannot mutate or infer them.

### Recommended minimum owner-mediated planning-request flow

The visible UX provides two related owner-mediated actions:

1. **Copy project planning request** is available from the Project Plan header and is the primary loaded-empty action when no authoritative phase or planned-work detail exists. It is project-level only: it does not create a work identity, phase, pending record, lifecycle, ordering, relationship, or plan mutation.
2. **Copy planning request** is available from an existing authoritative phase or planned-work detail and may name that already-recorded identity.

Both actions follow the truthful onboarding handoff boundary:

- They copy a path-free prompt containing only the visible project context and, for detail actions, the existing authoritative identity and requested planning outcome.
- They do not launch, contact, paste into, or submit to Codex.
- They do not create a phase, change lifecycle, assign work, or mark a request pending.
- Success is shown visibly and announced accessibly as: “Copied. No request was sent; paste this into a Codex task rooted at the project folder.”
- Failure is shown visibly and announced accessibly as “Could not copy,” retains focus, and offers Retry.
- The exact prompt content, clipboard seam, and technical realization are deferred; Gate 1 approves only these owner-visible semantics.

### Request-state behavior

| Condition | Visible behavior | Formal plan effect |
|---|---|---|
| No authoritative phase/work identity | Project Plan header and loaded-empty state offer Copy project planning request; success says copied but not sent; failure offers Retry | None; creates no identity or pending record |
| Valid planned-work identity and valid linked Codex task | Show the link as context and allow Copy planning request; the owner may separately open existing linked context where already supported | None |
| Valid identity, no Codex link | Copy remains available; explain that the owner chooses the rooted Codex task | None |
| Codex unavailable or stale | Copy remains available; show Codex freshness separately and do not imply submission | None |
| Clipboard copy succeeds | Transient “Copied; not sent” confirmation | None |
| Clipboard copy fails | Recoverable “Could not copy” state with Retry | None |
| Future approved request record commits | May show Pending only from that committed authoritative request record | No plan mutation until a separate authoritative planning action commits |
| Future action returns a definitive validation failure | Show actionable failure; plan remains unchanged | None |
| Future action outcome is truthfully unknown | Show “Outcome unknown; refresh before retrying” | Do not infer success or failure |
| Future action commits | Reload and display the newly committed authoritative plan | Atomic committed change with audit |

“Pending” is never inferred from copying text, opening Codex, observing a task, or waiting for a goal.

## 7. Phase taxonomy: owner-facing Gate-1 choice

The recommended visible taxonomy is:

| Lifecycle label | Meaning |
|---|---|
| Current | The one explicitly recorded phase currently emphasized for delivery |
| Upcoming | An explicitly recorded future phase with an explicit app-owned order |
| Completed | An explicitly recorded structurally completed phase |
| Unknown / Unordered | A recorded phase whose lifecycle or ordering is not yet authoritative |

Rules:

- At most one phase is Current.
- Zero Current phases is valid and must be shown truthfully.
- Lifecycle and order are never inferred from ticket lanes, dependencies, goals, Markdown, activity, timestamps, creation order, or observation.
- Unknown / Unordered phases remain visible; the app must not silently sort or classify them as Upcoming.
- Completed describes structural phase lifecycle, not the Accepted ticket lane and not History.
- Owner approval at Gate 1 approves only these visible labels and groupings. Representation, transition validation, ordering mechanics, and mutation contracts remain deferred.

### No-current behavior

- Overview says **No current phase recorded**; shows Recorded phases, Unscheduled work, and **Recorded work with no Current phase**; shows Current-phase active work and Current-phase attention as **Not applicable — no Current phase**; shows a separate unresolved-candidate incompleteness warning when relevant; retains **View Project Plan**; and omits **Open Current Phase Board**.
- If recorded phases exist but none is Current, Project Plan remains usable and says **No current phase recorded**.
- Project Plan exposes no default board action.
- Any explicitly recorded phase can still be selected and opened read-only.
- The UI does not promote the first, newest, most active, or least-complete phase.

## 8. Semantic identity continuity

### Recommended identity rule

The same authoritative planned-work identity survives phase placement. Placement changes its recorded phase membership; it does not destroy and recreate the user-visible work item.

Before placement:

- The work is shown under Unscheduled work.
- It has no delivery lane.
- It may carry an explicit outcome/title and other authoritative planning context.

After placement:

- The same identity appears in the assigned phase.
- Only then may it have one of the five delivery lanes.
- Audit and evidence continuity remain associated with that identity.

### Relationships allowed before placement

At the design-concept level, an unscheduled planned-work identity may have explicitly recorded:

- **Depends on** another planned-work identity.
- **Blocked by** another planned-work identity or explicitly recorded planning constraint.
- Evidence references.
- A linked Codex task/goal identity where already authoritative.
- A planning note/outcome.

These are planning relationship concepts, not claims that current ticket-dependency, blocker, evidence, or goal-link tables support them. Their representation and validation are deferred. The UI does not infer readiness from them.

Schema choice remains open: optional phase membership, a separate planning entity, or another authoritative representation may satisfy the semantic contract. A fake Backlog phase and a sixth Planned delivery lane are not recommended.

## 9. Content responsibility and proposed information architecture

### Proposed IA

    Delivery
    ├── Projects
    ├── Needs Review
    ├── Notifications
    └── Settings

    Selected project
    ├── Overview
    ├── Project Plan
    ├── Phase Board
    ├── Dependencies
    └── Activity

### Surface responsibilities

| Surface | Responsibility | Explicit scope label |
|---|---|---|
| Projects | Portfolio health across folder-backed projects; compact current-phase, recorded-plan coverage, attention, and freshness indicators | “Projects · recorded local delivery state” |
| Overview | Executive answer to “How is this project doing right now?”: explicit Current-phase active work/attention or truthful no-Current not-applicable states, compact goal context, recorded-plan coverage/completeness, and quick entry actions | “Overview · current-phase health and recorded-plan coverage” |
| Project Plan | Answer to “What planning structure and work are recorded across the project?”: all phase groups, Unscheduled work, planning relationships, incomplete-intake signposts, selection/inspector, and plan-request handoff | “Recorded Project Plan” |
| Phase Board | One explicitly selected phase’s five delivery lanes and read-only ticket detail | “Phase Board · [phase name] · [lifecycle]” |
| Dependencies | Detailed ticket dependency path for the selected phase only | “Ticket dependencies · [phase name]” |
| Activity | Unchanged project operational audit/runtime/notification record | “Project Activity” |
| Needs Review | Existing unresolved candidates and owner decisions; not plan membership until committed | “Candidates not included in Recorded Project Plan” where relevant |

### Overview as the default executive snapshot

Overview remains distinct and answers only: **How is this project doing right now?**

| Overview content | Visible contract |
|---|---|
| Current phase | Show only an explicitly recorded Current lifecycle; otherwise “No current phase recorded” |
| Current-phase active work | Backlog + In progress + Needs review + Blocked work in the explicit Current phase; otherwise “Not applicable — no Current phase,” never 0 |
| Current-phase attention | Needs review + Blocked work in the explicit Current phase; otherwise “Not applicable — no Current phase,” never 0 |
| Compact current/last-known goal context | Preserve the existing compact context and freshness/provenance semantics |
| Recorded phases | Project-wide authoritative phase count |
| Unscheduled work | Project-wide authoritative Unscheduled count |
| Work outside Current phase | Only with an explicit Current phase: Unscheduled work plus scheduled work in all non-Current phases |
| Recorded work with no Current phase | Only with no explicit Current phase: all Recorded work; replaces Work outside Current phase |
| Recorded-plan completeness | Show unresolved-candidate warning separately when relevant |
| View Project Plan | Always available after a successful authoritative project load |
| Open Current Phase Board | Available only when an explicit Current phase exists |

All Overview counts use the Recorded Project Plan zero/loading/unavailable/incomplete semantics defined in this proposal.

Overview must not render full phase lists, Unscheduled item lists, phase planning relationships, or a planning inspector. It is a summary and launch surface, not a second Project Plan.

Projects owns portfolio health. Overview owns right-now executive health. Project Plan owns recorded planning structure and coverage. Phase Board owns one phase’s execution. Dependencies owns phase-scoped ticket paths. Activity remains unchanged.

## 10. Interaction model

### Default flow and launch actions

    Projects
    → Overview (default)

    Overview
    → View Project Plan → Project Plan → Back to Overview
    → Open Current Phase Board → Phase Board → Back to Overview
      (board launch exists only when an explicit Current phase exists)

    Project Plan
    → select phase → Return or Open Phase Board
    → Phase Board → Back to Project Plan

    Phase Board
    → Dependencies for the same phase/ticket context
    → Back to originating Phase Board

Overview is not a plan-selection surface. **View Project Plan** moves focus to the Project Plan heading and initial/remembered selection. **Open Current Phase Board** moves focus to the Current board heading. When no Current phase exists, Overview uses the no-Current metric contract above, retains View Project Plan, and omits Open Current Phase Board.

### Single consistent selection/activation rule

- Single click or arrow-key movement **selects** a phase or planned-work row and updates the read-only inspector.
- Return or an explicit **Open Phase Board** action **activates** the selected phase board.
- Return on Unscheduled work opens its read-only detail, not a board.
- Space toggles the focused disclosure group.
- Selection never changes phase lifecycle, phase membership, lane, or planning relationship.

### Non-current phases

Any explicitly recorded phase—Current, Upcoming, Completed, or Unknown / Unordered—may open a read-only Phase Board. The header always names its lifecycle. Opening a non-current board does not make it Current.

### Cross-surface context continuity

- Projects opens Overview by default and moves focus to the Overview heading.
- View Project Plan opens Project Plan and restores its remembered phase/work selection when available.
- Project Plan exposes **Back to Overview** (or the consistent project-navigation action); returning restores focus to Overview’s **View Project Plan** action.
- Project Plan stores the selected phase in transient view state.
- Opening Phase Board from Project Plan preserves that phase; **Back to Project Plan** restores selection and focus to the originating phase row.
- Opening Current Phase Board from Overview uses only the explicit Current phase; **Back to Overview** restores focus to Overview’s **Open Current Phase Board** action.
- Opening Dependencies from either board origin preserves the same phase and the selected ticket when that ticket belongs to the phase.
- If the ticket does not belong to the phase, Dependencies opens with no fabricated selection and asks the user to select a ticket.
- **Back from Dependencies** always restores the originating Phase Board with the same phase and ticket focus.
- Returning from an Unscheduled detail restores focus to the originating work row.
- Persisting/restoring origin is deferred view-state mechanics; these visible destinations and focus results are fixed.
- Escape dismisses a popover, overflow menu, or compact pushed detail and restores focus to its invoker. Escape does not change route, phase, or formal state.

### Origin-aware board return and phase navigation

This proposal removes the v1 recommendation for a redundant board-local phase selector. Project Plan is the phase discovery and selection surface. Phase Board exposes:

- The selected phase name and lifecycle.
- Exactly one origin-aware return action: **Back to Overview** when opened from Overview, or **Back to Project Plan** when opened from Project Plan.
- The outside-work signal.

A Board opened from Overview returns to Overview; the user can then choose View Project Plan to change phases. A Board opened from Project Plan returns directly to the originating phase row. Dependencies always returns to its originating Board. No board-local phase selector is added.

## 11. Planning relationships

### Project Plan

Project Plan shows phase-to-phase summary relationships only:

- **Depends on [phase]**
- **Blocked by [phase or explicitly recorded planning constraint]**

These labels describe explicit records. They do not imply readiness, automatic ordering, or lifecycle transition.

### Dependencies

Dependencies remains a selected-ticket path inside one selected phase:

- Direct requirements.
- Indirect requirements.
- Unlocks.
- Explicit blocking path.

This study does not approve cross-phase ticket traversal. Project Plan phase relationships and Dependencies ticket relationships remain separate concepts and surfaces.

## 12. Recommended surface composition

### Wide Overview hierarchy

1. Header: project name, “Overview,” explicit current-scope text, freshness/incomplete status.
2. Current-phase executive cards: with an explicit Current phase, Current phase, Current-phase active work, and Current-phase attention; without one, “No current phase recorded” plus both Current-phase metrics as “Not applicable — no Current phase.”
3. Recorded-plan coverage cards: Recorded phases and Unscheduled work, plus Work outside Current phase only when a Current phase exists or Recorded work with no Current phase when one does not.
4. Compact current/last-known goal context.
5. Direct actions: View Project Plan and, only with an explicit Current phase, Open Current Phase Board.

Overview uses summary cards/rows only. It does not render plan lists, planning relationships, or an inspector.

### Wide Project Plan hierarchy

1. Header: project name, “Recorded Project Plan,” load/freshness/incomplete status.
2. Coverage strip: Recorded phases, Recorded work, Scheduled work, Unscheduled work.
3. Main list:
   - Current phase, expanded when one exists.
   - Unscheduled work, always named and counted.
   - Upcoming phases.
   - Unknown / Unordered phases.
   - Completed phases, collapsed by default.
4. Right-side inspector for selection.

Current/last-known goal context remains on Overview; Project Plan does not duplicate it.

### Unscheduled disclosure behavior

- When **Unscheduled work > 0**, the section is expanded by default and shows a bounded preview of the first **3** items in display order.
- If more than 3 items exist, a named **Show all N unscheduled items** action is exposed. After expansion, a named **Show remaining N** action may progressively reveal the remainder; neither action changes plan state.
- When the verified count is zero, show one compact row: **Unscheduled work · 0**. Do not render a large empty panel.
- Preview rows follow the same deterministic display-order rules as the complete list.
- Loading and unavailable states never render the zero row.

### Deterministic within-group display ordering

Display order is deterministic but does not invent plan priority:

- **Current** is singular.
- **Upcoming** follows explicit authoritative phase order.
- **Unscheduled work** follows explicit authoritative plan order when available. Without it, items use a stable neutral order by human-readable outcome, then stable ID, and the section is labelled **Display order only**.
- **Completed** uses reverse explicit authoritative phase order. Without explicit order, it uses stable neutral phase name, then stable ID, and is labelled **Display order only**.
- **Unknown / Unordered** uses stable neutral phase name, then stable ID, is labelled **Display order only**, and explicitly does not imply lifecycle, readiness, or priority.
- Item previews inside any phase use explicit authoritative item order when available; otherwise they use the same neutral outcome-then-stable-ID order and **Display order only** label.
- Neutral comparison and persistence mechanics are deferred. The visible contract is stability and non-priority semantics, not a new authoritative ordering rule.

Each phase row shows its explicit lifecycle, recorded-work count, explicit phase-level planning-relationship summary, and **Open Phase Board**. Delivery-lane contents remain on Phase Board rather than being reproduced as Project Plan structure.

### Back/Forward exemplar

The owner-visible Back/Forward request remains only an example of an authoritative Unscheduled work item:

    Navigation history
    Owner-visible Back and Forward navigation
    Not assigned to a phase

This proposal does not design the controls, toolbar placement, shortcuts, history rules, or implementation.

## 13. Behavioral state matrices

The UI resolves one **Primary Plan State**, one **Folder Context**, one **Codex Context**, and one **Observation Provenance**. States are mutually exclusive within each class and are never collapsed into a single misleading “unavailable” condition.

### Primary Plan State

| Exclusive state | Predicate | Overview behavior | Project Plan / execution behavior | Next action | Forbidden implication |
|---|---|---|---|---|---|
| Store unavailable | Authoritative local store cannot open/read | Full fail-closed recovery; no executive counts/actions | Plan and execution fail closed | Follow existing recovery guidance | Do not show cached plan, zero counts, or repository-derived substitute |
| Loading | Store is available but authoritative load has not completed | Single executive skeleton; all counts shown as — | Plan skeleton; no zero rows or board | Wait or use existing Retry if load fails | Do not flash 0 phases/work |
| No projects | Load succeeded and no completed/pending project is eligible for Projects | No project Overview | Existing Initialize/Attach entry; no plan | Initialize Project Tracking or Attach Folder | Do not show an empty Overview or Project Plan |
| Initialization pending | Project base exists with open pending tracking marker and no completed initialization | No executive snapshot is fabricated | Existing resumable tracking handoff | Copy prompt, Check Tracking Status, or resume | Do not claim an Overview, Recorded Project Plan, or submitted request |
| Loaded-empty Recorded Project Plan | Completed load succeeded; 0 phases and 0 unscheduled work; no unresolved flag | “No current phase recorded”; Recorded phases 0; Unscheduled work 0; Recorded work with no Current phase 0; both Current-phase metrics “Not applicable — no Current phase”; View Project Plan; no Current-board action | Empty plan with header Copy project planning request | View Project Plan or copy project request | Do not claim the repository has no planned work, show Current-phase metrics as 0, or imply a request was submitted |
| No Current phase, no recorded work | Recorded phases exist, 0 recorded work, none Current | “No current phase recorded”; Recorded phases count; Unscheduled work 0; Recorded work with no Current phase 0; both Current-phase metrics “Not applicable — no Current phase”; View Project Plan; no Current-board action | Show lifecycle groups and header request action | View Project Plan | Do not promote a phase, show Current-phase metrics as 0, or use Work outside Current phase |
| No Current phase, recorded work exists | Recorded work exists but none Current | “No current phase recorded”; Recorded phases; Unscheduled work; Recorded work with no Current phase = all Recorded work; both Current-phase metrics “Not applicable — no Current phase”; separate unresolved-candidate warning when relevant; View Project Plan; no Current-board action | Show all groups and Unscheduled; any recorded phase may open read-only | View Project Plan or select a phase there | Do not infer Current from lanes/activity, aggregate attention across non-Current phases, or use Work outside Current phase |
| Empty Current phase | Exactly one Current phase exists with 0 assigned work | Name Current, active/attention 0, Work outside Current phase coverage, View Project Plan, Open Current Phase Board | Current group expanded; its phase row shows 0 recorded work, with the board owning five verified-zero lanes | Open Current Phase Board or View Project Plan | Do not imply Recorded Project Plan is empty |
| Incomplete Recorded Project Plan | Load succeeded and unresolved relevant candidates exist | Prominent “May be incomplete · N candidates” remains separate from the applicable explicit-Current or no-Current metric contract; View Project Plan remains available | Recorded plan plus same incomplete signpost; candidates excluded | Open Needs Review or View Project Plan | Do not include candidates in counts, convert them into attention, or hide no-Current truth |
| Mature multi-phase | Current exists; recorded work exists; no higher-priority state applies | Current health plus Recorded phases, Unscheduled work, Work outside Current phase, Current-phase attention, goal context, View Project Plan, and Open Current Phase Board | Full grouped plan; Current expanded, Completed collapsed | View Project Plan or Open Current Phase Board | Do not present Overview as the whole plan or hide other groups |

The “Incomplete” state takes precedence over otherwise loaded structural states so the incompleteness signal cannot be hidden.

### Folder Context

| Exclusive state | Visible scope | Next action | Forbidden implication |
|---|---|---|---|
| Authorized | Plan and execution load normally | None | Do not imply Codex is available |
| Authorization unavailable | App-owned plan remains visible when the store is healthy; evidence/actions needing folder access are disabled | Use existing Locate/Reauthorize recovery | Do not label the store or plan unavailable; do not authorize from stored path alone |

### Codex Context

| Exclusive state | Visible scope | Next action | Forbidden implication |
|---|---|---|---|
| Supported fresh context | Compact verified runtime context only | Existing linked-task action where valid | Do not mutate plan or lanes |
| Stale last-known context | Persisted Overview and Project Plan remain visible; Overview goal/runtime context is labelled with its last-known timestamp | None or existing reconnect guidance | Do not call it live |
| Unavailable | Persisted Overview and Project Plan remain visible; Overview says “Codex unavailable” for runtime/goal context | Copy handoff remains usable | Do not hide plan or infer request failure |

### Observation Provenance

| Exclusive state | Visible scope | Next action | Forbidden implication |
|---|---|---|---|
| Current supported observation | Explicit freshness label | None | Do not treat it as delivery authority |
| Authorized cached last-known | Stale label and timestamp | None | Do not call it live |
| Imported historical observation | “Imported historical last-known context” | Inspect only | Do not treat it as current, count it as plan, or generate lifecycle |
| No observation | “No goal/runtime observation” | None | Do not infer idle/completed |

## 14. Responsive macOS behavior

### Chosen sidebar model

Use the existing approved two-state navigation rail:

- Wide: 220-point expanded sidebar with labels.
- Compact: 96-point icon rail with accessible route names.

This proposal requires new Project Plan routes and selected state to expose one matching visual and accessibility route. It does not remediate the existing sidebar toggle or current selected-state defects; those remain separately documented evidence.

### Chosen compact lane model

At compact widths, Phase Board becomes a horizontally scrollable five-lane board:

- Every lane keeps a readable minimum width.
- Cards use compact-ID presentation.
- Lane headers and counts remain visible.
- Keyboard users can reach each lane/card without pointer-only scrolling.
- The outside-work signal remains in the board header.

The app must not compress five lanes until labels or counts are unreadable, and it must not change the canonical lane set.

### Minimum supported compact behavior

At approximately 760 × 520:

- 96-point rail.
- Overview is a single-column executive summary with coverage cards/rows, compact goal context, View Project Plan, and conditional Open Current Phase Board. With no Current phase it uses Recorded work with no Current phase and announces both Current-phase metrics as Not applicable; it never becomes a second plan list.
- Project Plan is a separate single-column planning list.
- Inspector opens as a pushed detail view, not a squeezed side column.
- Current, Unscheduled, Upcoming, Unknown / Unordered, and Completed remain keyboard-reachable.
- Each surface retains its title and scope. Phase Board retains selected phase/lifecycle and its outside-work signal; Overview retains its coverage signal.
- Secondary actions move to a labelled More menu.
- Overview’s View Project Plan and conditional Open Current Phase Board remain directly reachable.
- Project Plan’s Open Phase Board and **Back to Overview** remain directly reachable; each board’s origin-aware **Back to Overview** or **Back to Project Plan** remains directly reachable.

### Toolbar overflow

Primary context stays visible:

- Surface title.
- Selected phase/lifecycle where applicable.
- Recorded-plan incomplete or outside-work signal.

Secondary commands, density, and help move to a labelled overflow menu. This proposal adds no Back/Forward control design.

## 15. Accessibility and keyboard contract

### Selection and route truth

- Exactly one route across the **complete visible sidebar/navigation** exposes selected visual treatment and the accessibility selected trait after Project Plan is introduced; Projects, Needs Review, Notifications, Settings, Overview, Project Plan, Phase Board, Dependencies, and Activity all participate in the same route-truth contract.
- Decorative symbols are hidden from accessibility when the containing control supplies the label.
- Project Plan groups expose name, count, lifecycle, and expanded/collapsed state.
- Unscheduled items announce “Not assigned to a phase.”
- Counts use named forms such as “3 unscheduled items” and “2 unresolved candidates.” With no Current phase, the coverage value is announced as “N recorded items with no Current phase,” and Current-phase active work and attention are each announced as “Not applicable — no Current phase,” never “0.”
- Current/Upcoming/Completed/Unknown and lane states use text plus symbols, not color alone.

### Keyboard behavior

| Key | Behavior |
|---|---|
| Up / Down | Move selection within the current phase/work list and update inspector |
| Space | Toggle focused disclosure group |
| Return | Activate selected phase board or open selected work detail |
| Escape | Dismiss transient menu/popover/compact detail; restore focus to invoker |
| Tab / Shift-Tab | Move through route, summary, list, primary action, and detail in stable order |

### Focus movement/restoration

- Opening Overview from Projects moves focus to the Overview heading.
- View Project Plan moves focus to the Project Plan heading and restores its remembered selection when valid; Back to Overview restores focus to Overview’s View Project Plan action.
- Open Current Phase Board moves focus to the Current board heading, then selected lane/card if present; Back to Overview restores focus to Overview’s Open Current Phase Board action.
- Opening a Phase Board from Project Plan moves focus to its heading; Back to Project Plan restores focus to the originating phase row.
- Opening Dependencies moves focus to its heading, preserving the selected ticket where valid; Back always restores the originating Board with the same phase/ticket focus.
- Closing an Unscheduled detail restores focus to the originating work row.
- Collapsing a disclosure moves focus to its header if the selected child disappears.
- Loading, failure, copy success/failure, and incomplete-plan updates are announced without moving focus unexpectedly.

Existing sidebar accessibility defects are out of scope for this design revision. They establish constraints for the complete navigation after Project Plan is introduced, but remediation of the currently observed defect is separate implementation scope and is not presented as completed or approved here.

## 16. Goals / History boundary

No controlling artifact for a separate Goals/History UX study was found.

For this proposal:

- Activity remains unchanged.
- Existing compact current/last-known goal context remains unchanged on Overview and is not duplicated in Project Plan.
- Completed phases are structural plan summaries, not History.
- Goal timelines, goal archives, history navigation, and Activity restructuring are excluded.
- Future convergence with a Goals/History study is a deferred dependency, not a blocker for Gate-1 Overview + Project Plan UX approval.

## 17. Recovery, audit, and archive implications

These are design-concept requirements, not schema or transport prescriptions.

### Recovery

- Every authoritative planning concept participates in app-owned atomic migration, pre-migration snapshot, integrity validation, and fail-closed recovery guarantees.
- Store unavailable means all authoritative planning and execution surfaces fail closed.
- Folder authorization failure does not erase or hide healthy app-owned planning state.
- Codex stale/unavailable does not erase or hide persisted plan or delivery state.
- Repository documents and cached runtime data never substitute for unavailable authoritative state.

### Consequential planning mutations

Any future committed create, place, move, lifecycle, order, or relationship mutation requires:

- Project and entity scope.
- Actor attribution.
- Reason.
- Idempotent request identity.
- App validation.
- Transactional plan and audit commit.
- Complete rollback on rejection.
- Truthful distinction between definitive failure and unknown outcome.

Transient selection, disclosure state, route history, density, and view preferences are not delivery mutations and do not create delivery audit events.

### Portable archive

A future complete portable Release Radar archive must preserve every new authoritative planning concept approved after this design, or export must fail rather than omit or approximate it. Exact archive version, format, schema, validation, and transport remain Architecture work. Exporter/importer implementation remains blocked by its existing gate.

## 18. Alternatives and trade-offs

### Approach A — Overview + Project Plan + scoped Phase Execution

**Owner-directed and recommended, but still Proposed / Unapproved until final Gate-1 approval.**

Benefits:

- Gives “How is the project doing right now?” and “What plan is recorded?” separate, non-overlapping surfaces.
- Keeps Overview concise and makes its current-phase scope explicit.
- Keeps current execution prominent while Project Plan makes every recorded phase and Unscheduled work discoverable.
- Scales mature planning structure through disclosure groups without turning Overview into a plan list.
- Works with owner read-only formal transitions.

Costs:

- Adds one more sibling project surface.
- Requires disciplined content boundaries so Overview does not duplicate Project Plan.
- Requires later formal planning authority and lifecycle work.
- Adds a planning step for non-current phase discovery, offset by View Project Plan and conditional Open Current Phase Board.

### Approach B — One everything-board

Benefits:

- Maximum simultaneous visibility.
- Easy raw comparison between phases.

Costs:

- Five lanes multiplied across phases becomes visually and cognitively large.
- Mixes lifecycle, placement, and delivery state.
- Encourages a fake phase or sixth lane.
- Performs poorly at compact widths.
- Weakens the approved focused Phase Board.

Not recommended.

### Approach C — Overview plus a separate Unscheduled Work route

Benefits:

- Smaller initial IA change.
- Gives unscheduled work a destination.

Costs:

- Fragments planning structure across Overview, Unscheduled Work, Phase Board, and Dependencies instead of providing one Project Plan.
- Makes completeness a mental assembly task.
- Leaves phase groups and planning relationships without a coherent project-level home.
- Risks hiding unscheduled work behind another route.

Viable but weaker than Approach A.

## 19. Gate-1 owner decision sheet: visible UX only

Owner approval should answer only the following visible-UX questions:

| ID | Visible decision | Recommended choice | Owner response |
|---|---|---|---|
| UX-1 | Project sibling surfaces | Retain Overview and add Project Plan with non-overlapping jobs, per owner direction on 2026-08-25 | Confirm / Revise / Defer |
| UX-2 | Default project destination | Overview executive snapshot | Confirm / Revise / Defer |
| UX-3 | Completeness label | Recorded Project Plan | Approve / Revise / Defer |
| UX-4 | Unplaced-work term | Unscheduled work | Approve / Revise / Defer |
| UX-5 | Phase labels | Current, Upcoming, Completed, Unknown / Unordered | Approve / Revise / Defer |
| UX-6 | Group order | Current, Unscheduled, Upcoming, Unknown / Unordered, Completed | Approve / Revise / Defer |
| UX-7 | Selection model | Select updates inspector; Return/explicit action opens | Approve / Revise / Defer |
| UX-8 | Non-current phase access | Any recorded phase opens read-only board | Approve / Revise / Defer |
| UX-9 | Board return and phase switching | Origin-aware Back to Overview or Back to Project Plan; Dependencies returns to originating Board; no redundant local phase selector | Approve / Revise / Defer |
| UX-10 | Minimum owner request loop | Header/loaded-empty Copy project planning request plus identity-scoped Copy planning request; both path-free, copied but not sent, retryable, and non-mutating | Approve / Revise / Defer |
| UX-11 | Compact board | Horizontal five-lane board with compact-ID cards | Approve / Revise / Defer |
| UX-12 | Incomplete-plan signal | Separate unresolved-candidate count and warning | Approve / Revise / Defer |
| UX-13 | Unscheduled disclosure | Expanded by default when nonzero; preview 3; named Show all/Show remaining; compact verified-zero row | Approve / Revise / Defer |
| UX-14 | Within-group display order | Explicit authoritative order where available; otherwise labelled stable neutral display order only | Approve / Revise / Defer |
| UX-15 | Overview contents and limits | Explicit-Current health or truthful no-Current not-applicable metrics + recorded-plan coverage + direct actions; no plan lists, relationships, or inspector | Confirm / Revise / Defer |
| UX-16 | No-Current Overview metrics | Recorded phases + Unscheduled + Recorded work with no Current phase; active/attention Not applicable; separate incompleteness warning; no Current-board action | Approve / Revise / Defer |

Gate-1 approval does not approve schema, migration, bridge, typed commands, data import, archive format, audit implementation, security design, code, or delivery.

## 20. Deferred technical decision register

| ID | Deferred decision | Owner after Gate 1 |
|---|---|---|
| TECH-1 | Authoritative representation of project-level planned work | Architecture |
| TECH-2 | Identity, membership, and lane persistence mechanics | Architecture |
| TECH-3 | Phase lifecycle/order representation and validation | Architecture + Planning |
| TECH-4 | Narrow typed/versioned planning mutation commands | Architecture + Security |
| TECH-5 | Owner-mediated request prompt and any future request record | Product + Architecture |
| TECH-6 | Planning relationship representation and cycle rules | Architecture |
| TECH-7 | Cross-phase ticket dependency policy | Product + Architecture; not approved here |
| TECH-8 | Aggregate projection/query contracts | Architecture + QA |
| TECH-9 | Migration/snapshot/recovery details | Architecture + Security + QA |
| TECH-10 | Complete portable archive version/format | Architecture; exporter/importer remains blocked |
| TECH-11 | Origin persistence and route/focus restoration mechanics; visible origin-aware semantics are fixed at Gate 1 | Planning + Architecture |
| TECH-12 | Polished screenshot production | Design, only after owner Gate-1 approval |

## 21. Reviewer outcome matrix — v5 focused closure pending

| Review role | Latest recorded focused outcome | v5 status |
|---|---|---|
| Planning | **GO on v4** | Recorded as review evidence, not owner approval; no v5 Planning approval is claimed |
| Architecture | **Required corrections on v4** | No-Current metric semantics and origin-aware return semantics revised in v5; Architecture closure review pending |
| QA | **Required corrections on v4** | No-Current state/announcement coverage and deterministic origin/focus return revised in v5; QA closure review pending |
| TPM | v4 focused outcome not carried to v5 | **Focused v5 review pending** |
| Delivery Management | v4 focused outcome not carried to v5 | **Focused v5 review pending**; v5 remains Proposed / Unapproved and unlocks no packaging |
| Security/Privacy | v4 focused outcome not carried to v5 | **Focused v5 review pending**; no new authority or mutation is introduced |

No reviewer outcome is treated as owner approval.

## 22. Required-finding resolution and disagreement log

| Consolidated finding | Current proposal disposition | Classification |
|---|---|---|
| 1. Recorded-plan boundary/counts | Defined Included/Excluded membership, non-overlapping formulas, zero/unknown/unavailable, and incomplete signal | Resolved design requirement |
| 2. Authority/action loop | Formal app-owned authority and path-free copied-not-sent request flow; no current bridge claim | Resolved visible UX; technical work deferred |
| 3. Phase taxonomy | Current/Upcoming/Completed/Unknown explicit; no inference; no-current behavior | Gate-1 owner choice |
| 4. Identity continuity | Same identity survives placement; no pre-placement lane; pre-placement relationship concepts bounded | Recommended semantic choice; representation deferred |
| 5. Content/IA | Overview retained as default executive snapshot; Project Plan added as sibling; every responsibility and scope assigned without list/inspector duplication | Owner direction incorporated; Planning GO recorded on v4; v5 remains Proposed / Unapproved |
| 6. Interaction | Selection vs activation, non-current boards, context/focus restoration, no local phase selector | Gate-1 owner choice |
| 7. Relationships | Phase summary separated from phase-scoped ticket path; no readiness/cross-phase traversal claim | Resolved design boundary |
| 8. States | Primary, folder, Codex, and provenance exclusive matrices with scope/action/forbidden implication | Resolved behavioral specification |
| 9. Responsive/accessibility | 220/96 rail, horizontal compact board, overflow, pushed detail, exact keyboard/focus semantics | Gate-1 owner choice |
| 10. Goals/History | Activity and compact goal context frozen; histories excluded; no artifact found | Resolved scope boundary |
| 11. Recovery/audit/archive | Concept requirements added without schema/transport prescription | Resolved boundary; technical details deferred |
| 12. Scope corrections | Back/Forward exemplar only; control design removed; sidebar defects evidence/out of scope | Resolved scope correction |
| 13. Delivery packaging | Metadata, registers, manifests, matrices, logs, gate sheet, and explicit gate statement added | Resolved review packaging |
| 14. Restored research outputs | Added compact user jobs, representative scenarios, current active-phase-scoped IA, and evidence-linked usability failures | Resolved v3 closure finding |
| 15. Project-level empty/header action | Added Copy project planning request with path-free copied-not-sent, retry/accessibility, no-identity/no-pending/no-mutation semantics | Gate-1 visible choice; technical realization deferred |
| 16. Unscheduled disclosure | Nonzero defaults expanded with 3-item preview and named Show all/remaining; verified zero is compact | Gate-1 visible choice |
| 17. Deterministic display order | Explicit authoritative order where present; otherwise labelled stable neutral display order only with no priority/lifecycle inference | Visible contract resolved; mechanics deferred |
| 18. Complete route-truth contract | Applies matching visual/AX selection to all visible navigation after Project Plan; current defect remediation remains separate | Resolved design constraint; implementation scope separate |
| 19. Owner-directed Overview retention | Overview remains default executive snapshot; Project Plan is a sibling; state, flow, responsive, focus, alternatives, and Gate-1 records revised | Incorporated on 2026-08-25; pending final owner approval |
| 20. No-Current Overview truth | Added conditional metric names/formulas, Not applicable active/attention states, separate incompleteness, action omission, state/compact/AX coverage | Revised in v5; Architecture and QA closure review pending |
| 21. Origin-aware deterministic returns | Fixed Overview-, Project Plan-, and Dependencies-origin destinations and focus restoration; persistence mechanics remain deferred | Revised in v5; Architecture and QA closure review pending |

### Explicit disagreement rulings

- Approach A is now **Overview + Project Plan + scoped Phase Execution**. Its Overview retention is owner-directed, but the complete v5 remains Proposed / Unapproved until final Gate-1 approval.
- The dependency mockup’s Planned node is not authority for the plan model.
- Back/Forward control design is out of scope; it remains only the unscheduled exemplar.
- Existing sidebar accessibility fixes are out of scope; the defects remain evidence and constraints.
- Exact schema, migration, bridge, typed command, and portable format decisions are deferred.
- Activity remains unchanged.
- Reviewer acceptance cannot make this proposal Done or Accepted.

## 23. Explicit gate statement

**Status: Proposed / Unapproved.**

Approval of this v5 unlocks only the polished-screenshot design stage. It does not authorize an implementation plan, code change, database change, MCP or bridge change, migration, phase assignment, import/export implementation, repository write, production-artifact mutation, packaging, installation, or deployment.

Nothing in this document is Done or Accepted. The 2026-08-25 owner direction to retain Overview is not final v5 approval. Planning GO on v4 is review evidence only; Architecture and QA closure plus focused TPM, Delivery, and Security v5 reviews remain pending. Reviewer approval is not owner approval. The owner must explicitly approve the complete Gate-1 visible UX before any polished screenshot is created.
