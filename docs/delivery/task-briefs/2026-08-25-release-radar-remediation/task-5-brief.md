### Task 5: Match the selected-path Dependencies view and add an explicit local board-density control

**Objective / user-visible outcome:** Dependencies shows only the selected ticket's prerequisite path and direct unlocks in the hierarchy and inspector language of the approved mockup. Phase Board replaces the ambiguous automatic presentation badge with an operable `Full outcomes` / `Compact density` control, while a narrow window still forces compact cards safely.

**Controlling references:** `docs/design/mockups/dependencies.png` (1586 x 992), `docs/design/mockups/phase_board.png` (1586 x 992), `docs/design/agent-driven-delivery-dashboard-design.md` “Phase board” and acceptance criterion 3, and `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` Task 5.

**In scope:** Read-only selected-path filtering/layout; stable four-column metadata and connectors; count/legend/column headers; selected and blocking-path presentation; existing inspector regrouping; responsive recovery; one view-local density selection and a width-derived effective card presentation. **Out of scope:** changing `DependencyGraphProjection` storage/loading authority, graph or lane mutation, a sixth lane, automatic delivery transitions, preference persistence, a new ticket field, owner-data migration, or screenshot-test infrastructure.

**Dependencies / release gate:** No technical dependency on RR-R1 through RR-R4, but this writer remains serialized after the prior accepted task. TPM and Delivery Manager may release implementation only after Architect, QA, and Delivery Management accept this brief, the width matrix, and the visual/accessibility checklist.

**Anticipated files:**

- Modify `ReleaseRadar/Dependencies/DependencyGraphLayout.swift` for selected-path columns, visible-node filtering, stable frames, and blocking connector metadata.
- Modify `ReleaseRadar/Dependencies/DependencyGraphView.swift` for count/legend/headers/separators/arrows, responsive workspace/inspector composition, and accessibility text equivalents.
- Modify `ReleaseRadar/Projects/PhaseBoardView.swift` for the view-local `BoardDensity` / effective-presentation helper, density state, the accessible selector, and responsive lane recovery; do not change persisted projections.
- Modify `ReleaseRadar/Projects/TicketCardView.swift` only if needed to keep compact/full visual and accessibility behavior truthful.
- Modify `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift` and `ReleaseRadarTests/DashboardProjectionTests.swift` for the two focused regression groups below.

**Interfaces / deterministic rules:** Keep `DependencyGraphProjection` read-only. `DependencyGraphLayout.makeLayout(graph:size:)` must derive its visible set from exactly `selected.indirectRequires + selected.directRequires + selected.ticket + selected.unlocks`, never every phase node. Expose four stable column groups in this order and with these visible labels: `Foundations`, `Accepted work`, `Selected ticket`, `Unlocks next`; sort IDs lexically within a group. Include only edges whose two endpoints are in the visible set. Expose connector blocking metadata derived from a blocked source node so the view and tests do not re-infer styling independently. Repeated calls with the same graph and size must return equal column membership, frames, and connectors.

Add a two-case `BoardDensity` with display values exactly `Full outcomes` and `Compact density`. The Phase Board owns it as non-persisted `@State`, initially `fullOutcomes` to preserve the approved full-width default. The pure effective-presentation rule is: requested compact is always `.compactID`; requested full is `.fullOutcome` only when lane width is greater than 180 points; lane width at or below 180 points is forced `.compactID`. Resizing back above 180 restores the owner's still-local full selection. The density control remains operable and its accessibility value must disclose when `Full outcomes` is temporarily compacted by width.

**Data / persistence / security / privacy:** This task reads existing in-memory projections and changes presentation only. It creates no SQLite row, bookmark, bridge request, audit, notification, credential access, or owner-data fixture. Any implementation that introduces persistence or new data access exceeds this brief and requires a new gate and Security/Privacy review.

#### Test-first implementation sequence

- [ ] **1. Add one selected-path layout regression.** Build a deterministic in-memory graph with three indirect foundations, two direct prerequisites (one accepted and one blocked), one selected in-progress ticket, two direct unlocks, and a separate two-node branch. Assert exact column order and lexical membership; the visible frame keys contain only the eight selected-path nodes; the unrelated nodes and edge have no frame/connector; all seven path edges have endpoints; only the blocked-prerequisite-to-selected connector is marked blocking; and two layout calls at `CGSize(width: 960, height: 520)` are equal. Keep the existing cross-phase projection test.

- [ ] **2. Add one density regression.** Assert the exact display strings and the effective matrix: `(fullOutcomes, 181) -> fullOutcome`, `(fullOutcomes, 180) -> compactID`, `(compact, 181) -> compactID`, and `(compact, 180) -> compactID`. Preserve existing sidebar-width assertions. Do not add view-snapshot infrastructure.

- [ ] **3. Run RED.**

  ```sh
  xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/ReviewAndGraphAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests
  ```

  Expected: the new assertions fail because the current layout includes every phase node/edge, has no column or blocking metadata, and density is inferred solely from width.

- [ ] **4. Implement the smallest production change.** Filter and group in `DependencyGraphLayout`; render the selected-path count, lane/line legend, dashed column separators, directional arrowheads, selected border, blocked path, and inspector sections in `DependencyGraphView`. At compact width, flow the legend and stack the inspector below the scrollable graph rather than clipping either pane. In `PhaseBoardView`, replace `board-presentation` text with a labeled `Menu` or `Picker` identified as `board-density`, containing both exact options; use the pure effective rule for all five lanes and add horizontal recovery only when the five minimum-width lanes cannot fit. Keep every compact card's full outcome in its accessibility label even when its visible outcome is omitted.

- [ ] **5. Run GREEN and build an isolated alternate-bundle app.** Re-run the focused command and the repository-native app build. Runtime acceptance must use an alternate bundle/container and must not launch `com.rekonlabs.ReleaseRadar` or read/write its owner database.

#### Exact responsive acceptance matrix

- **Wide reference:** window **1586 x 992 points**, matching both PNG dimensions, expanded 220-point sidebar. Capture Dependencies and Phase Board. Dependencies must use a right-side inspector; Phase Board must exercise both explicit density choices.
- **Compact target:** window **900 x 650 points**, expanded 220-point sidebar. Capture both surfaces. Dependencies must retain the full selected path and move the inspector below the graph; Phase Board must show all five lanes without overlapping headers/counts/signals and must visibly compact when full was requested but lane width is at or below 180.
- **Minimum recovery check:** window **760 x 520 points**, the app's declared minimum. A capture is required only if behavior differs from the 900 x 650 compact capture. Verify keyboard/scroll recovery exposes every lane, graph column, and inspector section without clipped actionable controls.

#### Visual and accessibility acceptance checklist

**Dependencies**

- [ ] Header says `Phase dependency map` and identifies the selected ticket/path; the workspace reports `N of M phase tickets shown` from layout-visible versus phase-total counts.
- [ ] Legend distinguishes the five lane colors plus `Dependency` and `Blocking path`; blocked red is also named in text and is not the sole status cue.
- [ ] Four headers read `Foundations`, `Accepted work`, `Selected ticket`, and `Unlocks next`; dashed separators, left-to-right arrowheads, selected accent border, and blocked connector emphasis follow `dependencies.png`.
- [ ] No unrelated node or connector is visible. No-path/empty relationships say `None` or retain the existing explicit unavailable state rather than substituting phase nodes.
- [ ] Every node is keyboard-focusable and selectable; its accessibility label includes ID, lane, blocker count, selection when applicable, and its column role. Selecting it updates the inspector.
- [ ] Canvas lines have equivalent relationship information in the accessible inspector. Inspector headings and counts expose selected ticket, outcome, runtime/freshness, direct requirements, indirect requirements, and unlocks in navigable order.
- [ ] At 900 x 650 and 760 x 520, wrapped legend/header content, graph scrolling, and stacked inspector provide recovery with no hidden control.

**Phase Board**

- [ ] A visible control labeled `Card density` replaces the passive `Full outcomes` / `Compact IDs` badge; its two choices are exactly `Full outcomes` and `Compact density`, with stable identifier `board-density`.
- [ ] At wide width, selecting `Full outcomes` visibly shows outcome plus dependency/blocker counts; selecting `Compact density` hides only the visible outcome and retains ID/counts.
- [ ] At compact width, a requested full presentation is forced compact without overlap; the control/accessibility value truthfully communicates the width override and returns to full after widening.
- [ ] All five lanes remain present in canonical order with unclipped names and counts. Keyboard and scroll recovery can reach every card and the existing ticket detail.
- [ ] Long outcomes are visually bounded in full mode but read completely in the card accessibility label; compact cards remain distinguishable by ID and named dependency/blocker counts. Selection is not color-only.

**Happy path:** Selecting any visible dependency node deterministically redraws only that node's prerequisite/unlock path and inspector. Density changes apply immediately for the current board, do not mutate data, and retain the requested choice while the view remains alive.

**Non-happy path / failure behavior:** A selected ticket with no relations shows only the selected node and empty relationship sections. Unrelated/cross-phase nodes never fill empty space. Very narrow content scrolls/stacks instead of clipping. Since density is intentionally local, leaving/recreating the board may reset it to `Full outcomes`; no “saved” copy or audit may be shown.

**Activity / audit evidence:** None. QA must confirm no bridge request, audit row, notification, or database mutation occurs when selecting density or dependency nodes.

**Acceptance criteria:** Focused regressions pass; Dependencies visibly follows the selected-path hierarchy/legend/inspector intent of `dependencies.png` with unrelated nodes absent and a non-color-only blocking path; Phase Board has an explicit truthful density control matching `phase_board.png`; wide, compact, and minimum recovery checks remain accessible with all five lanes. Any mockup deviation is called out explicitly for design/QA acceptance rather than silently treated as a match.

**Required independent reviews:** Code Reviewer; QA visual/responsive/accessibility verifier; Architect; TPM; Delivery Manager. Security/Privacy is not required unless the implementer expands storage, bridge, permission, or owner-data access.

**Completion evidence:** Record the RED/GREEN command and result, isolated build identity, captures with exact window dimensions, checklist result and approved deviations, accessibility tree/keyboard evidence, no-write confirmation, each independent decision, remaining risk, and RR-R6 release gate in `docs/delivery/progress.md`.
