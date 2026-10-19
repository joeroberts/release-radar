# Project Plan roadmap-first proposal

Status: **Proposed for owner review; not approved for implementation**

Owning issue: [#121](https://github.com/joeroberts/release-radar/issues/121)

Selected direction: [#273 owner choice](https://github.com/joeroberts/release-radar/issues/273#issuecomment-6269695502)

Recovered scope and evidence state: [#121 current handoff](https://github.com/joeroberts/release-radar/issues/121#issuecomment-6269722669)

Source baseline: `2d6a974c5d636632fa4e1cf989399a46ed58749e` (application source unchanged from `61a4dabb35a41c0417d4a591148f0df673c0fc66`)

This proposal develops the owner's selected direction—**Roadmap first: show
phases and open details on selection**—into an implementation-ready interaction
design. It is a design artifact, not evidence that the proposed interface is
running. Current-runtime captures, when produced by QA from the pinned synthetic
fixture, belong in [`before/`](before/).

## Outcome and boundary

Project Plan becomes a phase roadmap whose default presentation answers four
questions without requiring the owner to interpret implementation metadata:

1. Where is the project in its lifecycle?
2. Which phases are complete, active, or proposed?
3. What is preventing the selected phase from advancing?
4. What is the single most relevant next action?

The proposal reorganizes existing and already-planned capabilities. It does not
change the planning data model, invent a phase-filtered dependency graph, move
tickets, execute work, infer acceptance, or make finalization automatic.

## Proposed experience

### Default roadmap

Phases are grouped by their current lifecycle—`In delivery`, `Upcoming`,
`Unassessed`, and `Completed`—as one compact row each. A row exposes only:

- human phase name and exact lifecycle (`Unassessed`, `Upcoming`, `In delivery`,
  or `Completed`);
- structural plan readiness (`Legacy unassessed`, `Draft`, or `Ready`);
- delivery progress as delivered or accepted tickets over total tickets;
- one gap indicator when action is required; and
- at most one recommended-action label.

The row remains one selection control; it does not contain nested action
buttons. Selecting it reveals the executable action in the phase details. This
keeps keyboard behavior predictable and avoids duplicating the same control in
the roadmap and inspector.

The selected row receives a persistent visual and accessibility-selected state.
Completed phases remain visible but visually quieter. Unassessed, Upcoming, In
delivery, and Completed are never collapsed into one generic status. Readiness
describes structural plan quality; delivery progress describes ticket movement;
goal/ticket owner acceptance remains a separate fact and is never used as a
readiness label.

The page header retains the project name, **Prepare repository plan**, and
**Open all-phase board**. Preparation remains the #101 source-bound
prepare/review/Apply journey; the roadmap does not reproduce that workflow.

### Selected phase details

On a wide window, selection opens a fixed inspector beside the roadmap. On a
compact window, it opens a dedicated detail screen with a **Back to roadmap**
button. Back restores the selected row, scroll position, and keyboard focus.

The detail screen uses this order:

1. **Phase summary** — lifecycle, readiness, delivery progress, and the reason
   behind the recommended next action.
2. **Goals** — goal title, intended outcome, and done-criteria summary. Retain
   #191 **Create Delivery Goal** and **Edit** actions for an editable phase. A
   request originating in Goals continues through `requestedDeliveryGoalEditor`
   to the exact phase/goal; completing or cancelling restores that originating
   context.
3. **Ticket assignments** — concise covered/uncovered summary. Retain #192
   **Edit assignments** when its feature is delivered and the phase is eligible.
4. **Finalize plan** — explicit #193 action only for an eligible draft. The
   action must never imply execution, lane movement, owner acceptance, or a new
   revision.
5. **Open phase board** and **View dependencies** — navigation, not embedded
   duplicate views. Dependency navigation carries an exact selected ticket when
   one exists; no phase-filter mode is proposed.
6. **Plan changes** — #101 prepared proposal summary and source-bound review,
   correction, Apply, and recovery entry.
7. **Technical record** — collapsed by default; revision IDs, internal IDs,
   audit details, and attempt identifiers live here.

When a phase exposes ticket membership, selecting a ticket opens the existing
ticket detail in place of the phase inspector (or pushes a ticket-detail screen
on compact layout). Back returns to the originating phase, row, and ticket.
Requires/Unlocks, owner attention, evidence, audit, and notifications remain
ticket details; they do not become phase-row content.

Two plan-wide collections remain discoverable without masquerading as phases:

- **Not placed** appears as a plan-wide gap immediately before the roadmap when
  it is nonempty, with its count and one **Review unplaced work** label. Its
  detail lists the affected tickets and preserves existing ticket inspection.
- **Retired originals** appears after the roadmap as a collapsed read-only
  collection with its count. Selection exposes disposition, rationale, last
  placement, and successor lineage. Retired tickets never appear on active
  boards or contribute to phase progress.

Only sections with useful content appear. When a required capability is not yet
delivered (#192 or #193), the design specifies its eventual placement without
representing it as present in the pinned runtime.

### Owner task coverage

| Planning task | Default roadmap support | Selected-detail support |
| --- | --- | --- |
| Understand current position | Lifecycle-ordered phases; active selection; completed phases visually quiet | Phase summary explains readiness separately from progress and acceptance |
| Find what needs attention | One gap and one recommended-action label per actionable row | One executable next action with the reason it is appropriate |
| Create or correct goals | `Needs goal` is visible without showing all goal text | #191 Create/Edit opens the exact phase/goal and preserves recovery context |
| Correct ticket coverage and finalize | Uncovered count remains scannable | #192 assignment correction precedes the explicit #193 finalize action |
| Inspect delivery or dependencies | Progress stays visible; global board remains in the header | Phase board and existing dependency view open without duplicating their contents |
| Find unplaced or retired work | A nonempty plan-wide gap precedes phases; retired originals collapse to a read-only count after them | Ticket selection preserves existing detail; retired details preserve disposition and successor lineage |
| Prepare or apply repository changes | Project-level Prepare action remains stable | #101 owns source-bound review, correction, refresh, and explicit Apply |

## Representative states

### Populated plan

The roadmap shows all phases with one selected active phase. The inspector leads
with its gap and one next action. Goals and ticket assignments are summarized;
details are disclosed within the inspector rather than repeated on every row.
If work is not placed, its plan-wide gap precedes the phase rows so the owner
does not have to scroll past phases to discover it.

### Empty plan

The roadmap area becomes a single empty state:

> No phases yet. Prepare a plan from this repository, or create the first
> delivery goal when a phase already exists but has no goals.

Show **Prepare repository plan** as the primary action. Show **Create Delivery
Goal** only when an editable phase actually exists. Do not display zero-valued
coverage, readiness, or progress as though they were confirmed data.

### Large plan

The roadmap remains a single virtualizable/scrollable sequence grouped under
`In delivery`, `Upcoming`, `Unassessed`, and `Completed`. The current group is
expanded; completed phases may be collapsed into a count, with an accessible
**Show completed phases** control. Selection stays stable during refresh. No
horizontal phase carousel is introduced. Search/filtering is outside #121
unless later evidence shows the grouped roadmap is insufficient.

### Loading, stale, and uncertain outcomes

- Initial loading uses row-shaped placeholders and does not announce invented
  counts.
- If refresh fails after a successful load, keep the last successful roadmap,
  label it **May be out of date**, and offer **Retry**.
- If no successful data exists, show an actionable load error instead of an
  empty plan.
- A stale-revision response keeps edits, refreshes the phase, and explains what
  changed before Save can be attempted again.
- A confirmed save that still needs a published reload retains the receipt and
  offers **Reload saved result**; it must not replay the mutation.
- An unknown mutation outcome retains the exact attempt and offers **Reconcile
  saved attempt** before any new dispatch.

## Action and data contract

| Visible value or action | Authoritative source | Freshness shown to the user | Failure / uncertainty behavior |
| --- | --- | --- | --- |
| Phase name, order, lifecycle | Current published plan projection | Updated with the containing plan load | Keep last successful roadmap and mark stale; never substitute inferred order |
| Readiness and saved revision | Selected phase projection at its exact revision | Readiness applies to the displayed revision | Disable consequential actions on revision conflict; reload while preserving the selection |
| Delivery progress | Current ticket membership and lane state for the phase | Count belongs to the displayed plan projection | Do not turn a failed load into `0 / total`; show unavailable or stale |
| Gap and recommended next action | Deterministic derivation from the same displayed phase, goals, assignments, and receipt state | Must agree with the visible readiness and revision | Recovery (`Retry`, `Reload saved result`, or `Reconcile saved attempt`) replaces ordinary action while uncertain |
| Create/Edit Delivery Goal (#191) | Selected editable phase and exact goal/revision | Editor shows plan revision | Retain edits; stale reloads; confirmed-needs-reload does not replay; unknown outcome reconciles exact attempt |
| Edit assignments (#192) | Eligible tickets and current goals for the selected phase/revision | Form shows plan revision and covered/uncovered work | Retain selections; use typed receipt plus published readback; reconcile exact phase-keyed attempt. This feature was not delivered in the baseline |
| Finalize plan (#193) | Eligible draft phase at exact saved revision | Success sets Ready on the same revision with an audit record | Incomplete goals, unassigned tickets, and conflicts link to the exact correction surface; empty-goal recovery links to Create Goal. This feature was only prepared, not implemented, at the baseline |
| Prepare / review / Apply (#101) | Repository-plan proposal bound to its source and attempt | Source and proposal identity remain visible in its review surface | Preserve correction links, explicit Apply, refresh, and exact-attempt recovery |
| View dependencies | Existing dependency projection, optionally with exact selected ticket | Existing view owns its freshness and stale warning | Keep the last successful graph with **Dependency data may be stale** and **Retry**; #121 makes no claim about the held #123 incident |
| Not placed work | Current plan-wide unplaced-ticket projection | Count belongs to the displayed plan projection | Never fold unplaced tickets into a phase count; unavailable/stale follows the containing plan state |
| Retired originals | Current read-only retirement projection | Disposition and successor lineage belong to the displayed projection | Never count retired tickets as active progress or return them to active boards |

## Interaction details

### Keyboard and focus

- `Tab` traverses header actions, roadmap, then visible inspector actions.
- Each phase row is one focusable selection control. Its next-action text is a
  label, not a nested button. Up/Down arrows move between rows without triggering
  the recommended action; Return/Space selects.
- After wide-layout selection, focus remains on the row. A documented shortcut
  or the next Tab moves into the inspector; selection alone does not steal focus.
- On compact layout, Return/Space opens details and moves focus to the detail
  heading. **Back to roadmap** restores focus to the originating row and its
  scroll position.
- Opening Create/Edit Goal, Edit assignments, or Finalize moves focus to the
  sheet heading. Cancel returns focus to the invoking control. Successful close
  returns focus to the updated phase summary or invoking control.
- When validation fails, focus moves to the first invalid field or the error
  summary. Stale and uncertain-result recovery announcements use a polite live
  region; destructive or blocking errors use an assertive announcement only
  when immediate attention is required.

### VoiceOver semantics

Each roadmap row is announced as a single control in this order:

> “Planning, selected, In delivery phase, Draft plan, 8 of 10 tickets
> delivered, 2 tickets unassigned, action available: Assign tickets.”

Do not expose decorative dots, duplicated badges, or raw revision identifiers
as separate accessibility elements. The inspector/detail title includes the
selected phase name. Progress uses both a value and text; color is never the
only carrier. Collapsed sections expose expanded/collapsed state. Disabled
actions include the reason in help text rather than only lowering opacity.

Touch/click targets are at least 44 points high. Text supports macOS accessibility
sizes without clipping; long phase and goal names wrap before truncation.

## Removed, moved, and retained

| Treatment | Information / control | Rationale |
| --- | --- | --- |
| Remove from default rows | Internal phase IDs, revision IDs, repeated ticket/goal totals, full goal bodies, obligation lists, audit metadata | They compete with lifecycle, readiness, progress, and action; none is needed to scan the roadmap |
| Move to selected details | Goals, assignment coverage, obligations, validation gaps, preparation/reconstruction status | These explain one phase and are useful after selection, not on every row |
| Move to Technical record | Raw identifiers, exact saved revisions, attempt/receipt details, low-level provenance | Necessary for diagnosis and trust, but only on demand |
| Move to plan-wide summaries | Not placed tickets and Retired originals | They remain essential but are not phases; one nonempty gap before the roadmap and one collapsed read-only collection after it preserve meaning without dominating the default |
| Retain in default rows | Human name, lifecycle, readiness, progress, one gap, one next action | Directly answers the owner's primary planning questions |
| Retain in header | Project identity, Prepare repository plan, Open all-phase board | Stable project-level actions should not repeat per phase |
| Retain in details | #191 goal actions, #192 assignment entry, #193 explicit finalization, phase board, dependencies, #101 review/Apply entry | Preserves essential planning behavior without exposing every control at once |
| Keep distinct | #120 on-demand board refresh behavior | Its stable, explicit refresh principle applies, but its separate drawer behavior is not reimplemented here |

## Layout rules

- **Wide (`>= 1100 pt`)**: roadmap uses the flexible leading region; the
  inspector is 440–520 pt wide and remains visible while the roadmap scrolls.
- **Compact (`< 1100 pt`)**: show either roadmap or detail, never a squeezed
  two-column layout. A clearly labeled Back action restores context.
- Roadmap rows are at least 64 pt tall at default text size and grow for wrapped
  names or accessibility text sizes.
- Use restrained semantic color plus icons/text: blue for selected/current,
  amber for a correctable gap, green for a completed lifecycle, and neutral for
  Upcoming or Unassessed. `Ready` and `Accepted` always retain their explicit
  labels even when they share a success color. Never use color alone.

## Acceptance scenarios for the proposed design

These are design acceptance scenarios. They become implementation acceptance
criteria only after the owner approves the concrete proposal on #121.

| ID | Given / When | Observable result | Evidence status |
| --- | --- | --- | --- |
| RR-1 | Given a populated plan with Unassessed, Upcoming, In delivery, and Completed phases, the owner opens Project Plan | Every phase is grouped under its exact lifecycle; each row exposes name, lifecycle, separate structural readiness, progress, at most one gap, and at most one next-action label without goal bodies, revision IDs, or obligation lists | Proposed; visualized in the wide and compact mockups |
| RR-2 | Given an actionable phase, the owner selects its row | Wide layout shows the inspector without moving row focus; compact layout opens a detail screen and Back restores the row, focus, and scroll position | Proposed; visualized, not runtime verified |
| RR-3 | Given an editable phase/goal reached from Project Plan or Goals, the owner chooses Create/Edit Goal | The #191 editor opens for the exact phase/goal; Cancel returns to the invoker; validation or stale/uncertain outcomes retain edits and provide the defined recovery | #191 entry behavior is implemented at the baseline; proposed layout integration is unverified |
| RR-4 | Given uncovered tickets and delivered #192 behavior, the owner opens Edit assignments and saves | Eligible tickets/current goals are shown for the exact revision; Cancel retains no mutation; failure retains selections; confirmed/published success closes; saved-needs-reload does not replay; unknown reconciles the exact attempt | #192 was a candidate, not delivered, at the baseline |
| RR-5 | Given an eligible draft and delivered #193 behavior, the owner chooses Finalize | The action is explicit; successful completion marks Ready at the same saved revision and records audit evidence; gaps link to exact correction surfaces; no work executes and no acceptance is inferred | #193 was prepared only at the baseline |
| RR-6 | Given no confirmed phases, loading failure, or a large plan | Empty directs to Prepare without invented zeroes; a load failure is distinguishable from empty; a large plan remains one grouped vertical sequence with stable selection | Proposed; visualized, not runtime verified |
| RR-7 | Given successful data followed by refresh failure or an uncertain mutation | Last good data is marked stale; consequential actions pause; receipts/attempts are retained; recovery is Retry, Reload saved result, or Reconcile saved attempt as appropriate | Proposed integration of established recovery contracts; not runtime verified |
| RR-8 | Given keyboard or VoiceOver operation at wide and compact sizes | Rows are single focusable controls; navigation, selected state, lifecycle, progress, gap, action availability, focus transitions, and expanded state are conveyed without relying on color | Proposed; requires implementation QA |
| RR-9 | Given a selected ticket and View dependencies | Existing dependency navigation receives that exact ticket; Back restores Project Plan context; stale graph behavior remains owned by the dependency view; no phase filter is implied | Existing navigation observed in source/tests; proposed placement is unverified |
| RR-10 | Given unplaced work or retired originals | A nonempty unplaced count is visible before phase rows and opens existing ticket inspection; retired originals are available after the roadmap as a collapsed read-only collection and never affect active progress | Current collections observed in the hosted baseline; proposed hierarchy is unverified |

## Dependencies and remaining decisions

| Item | Impact | Owner / next action |
| --- | --- | --- |
| Current hosted baseline | The pinned populated wide/compact captures are now present; they establish the current density but not the proposed behavior | Coordinator links the captures and their qualification in #121; implementation QA still owns empty/large/accessibility evidence |
| #192 delivery | The selected-detail placement is specified, but the assignment feature must not be represented as present until its candidate is delivered and verified | #192 owners complete their existing work; #121 later integrates only the delivered contract |
| #193 delivery | Finalize placement and recovery are specified, but the feature is not implemented in the baseline | #193 owners deliver under their own issue; #121 does not absorb that implementation |
| Concrete design approval | #273 approved the roadmap-first direction, not every detail in this proposal | After independent review and current-baseline comparison, the #121 coordinator obtains explicit owner approval before application implementation |
| Visual tokens and final copy | Mockup colors, spacing, and illustrative labels communicate hierarchy but are not independently approved design-system tokens or final localized copy | Implementation uses existing app/RDS conventions; QA verifies meaning, contrast, scaling, and labels without expanding #121 into shared-library work |

## Visual proposals

- Current baseline: [wide 1500×900](before/project-plan-current-wide-1500x900.png)
  and [compact 760×900](before/project-plan-current-compact-760x900.png), with
  [capture provenance and limits](before/README.md)
- [Wide populated roadmap and selected inspector](project-plan-roadmap-wide-proposal.svg)
- [Compact roadmap-to-detail navigation](project-plan-roadmap-compact-proposal.svg)
- [Empty, large-plan, and recovery states](project-plan-roadmap-states-proposal.svg)

Mockup content is synthetic and contains no owner data. Labels illustrate the
contract above; final copy should be verified in the implemented interface.

### Observed before / proposed after

| Owner task | Current hosted baseline | Proposed hierarchy |
| --- | --- | --- |
| Scan the plan | Both sizes show expanded phase cards with phase IDs, readiness and lifecycle revisions, counts, every goal, goal state, coverage, ticket IDs, and done-criteria text | One compact row per phase shows only lifecycle, readiness, progress, one gap, and one next-action label |
| Inspect details | Wide uses the trailing inspector for a selected ticket; compact stacks the same long plan before lower content | Selecting a phase opens a stable wide inspector or dedicated compact detail; selecting a ticket temporarily drills into the existing ticket detail and Back restores context |
| Find exceptional work | Retired originals and Not placed are full-width sections in the same continuous default scroll | Nonempty unplaced work becomes a plan-wide gap before phases; retired originals become a collapsed read-only collection after phases |
| Decide what to do next | Multiple Open board controls and dense status/process text compete for attention; the owner must interpret coverage and readiness | One derived next action is explained and executed from selected details; uncertainty replaces ordinary actions with recovery |

The baseline is direct current-runtime evidence from the pinned synthetic
fixture, not owner data. Its selector passed at both target sizes. The
prerequisite build produced the matching test bundle and xctestrun, but its
wrapper did not retain the numeric build exit; that limitation does not change
the directly observed selector result and is not represented as a clean build.

## Evidence and approval gates

The current hosted baseline is the existing synthetic Project Plan fixture
captured at 1500×900 and 760×900 from the pinned candidate, with source revision
and test selector recorded. Those two captures establish only the current
populated wide/compact presentation. They do **not** verify empty or large plans,
the complete keyboard journey, VoiceOver output, or the proposed design.

Before implementation begins:

1. An independent reviewer checks this exact proposal against #121, #101, #120,
   #191, the current #192 candidate boundary, and the prepared #193 contract.
2. Required findings are corrected; optional suggestions do not expand scope.
3. The coordinator records the reviewed proposal and before/after comparison on
   #121 and obtains explicit owner approval of this concrete design.

After implementation, QA must separately verify populated, empty, and large
plans; wide and compact layouts; keyboard/focus restoration; VoiceOver names,
roles, values, and announcements; failure/recovery behavior; and preservation of
the #101/#191/#192/#193 entry points. Proposed SVGs and compilation alone are not
runtime evidence.
