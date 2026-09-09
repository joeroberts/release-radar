# Phase 5A recorded planning verification

## Verified outcome

Phase 5A adds an authoritative unassigned ticket state, exact first placement into
a same-project phase Backlog, Project Plan, and explicit phase/all-phase board
scope. Placement preserves the ticket identity and its task definitions,
dependencies, evidence and audit history. Unassigned tickets remain outside all
five execution lanes and cannot execute, complete tasks, request review or record
completion before placement.

Schema v19 enforces one placement shape: `phase_id` and `lane` are either both
null for retained Project Plan work or both non-null for placed execution work.
The policy boundary independently checks both columns before updating an existing
unassigned ticket.

The packaged agent helper exposes separate `release_radar_upsert_unassigned_ticket`
and `release_radar_place_unassigned_ticket` tools. Placement requires the exact
destination plan revision. Existing placed-ticket tool fields remain required, so
omitting a phase or lane cannot silently convert placed work to unassigned work.

## Direct checks

All tests used an isolated derived-data directory and the XCTest app host, with
external services suppressed by the existing test launch configuration.

- Store migration: frozen v12 graph/history and a populated v18-era graph migrate
  to schema v19 with nullable placement, clean foreign keys and no record loss.
  Fresh and migrated v19 stores accept only the two valid placement shapes and
  reject phase-only or lane-only inserts and updates.
- Policy and command boundary: pre-placement execution/task completion/review/
  completion and legacy-upsert bypass fail without effects; stale and cross-project
  placement fail; exact replay retains one request receipt and audit. Existing-ticket
  unassigned upsert rejects both possible partial-placement shapes.
- Projections and navigation: all phases, readiness, phase-owned goals and Not
  placed details agree; all-phase board has exactly five lanes and one phase label
  per card; the No Delivery Goal filter is distinct from No phase; Back restores
  Project Plan/all-phase scope, selection and focus; Dependencies selects an
  unassigned node labelled Unassigned. Removing a selected card with a Delivery
  Goal filter clears the selection, focuses the filter summary for keyboard and
  accessibility navigation, and shows the explicit `Select a ticket` empty detail.
- Persistence: archive/restore/relaunch, full backup, and removal retained-history
  checks preserve or truthfully retain the new record identity as applicable.
- Public transport: the real registered broker completed unassigned creation and
  revision-checked placement through the packaged helper, with exact replay.

Green result bundles retained for delivery review include:

- core migration, policy, projection, navigation, archive and removal suites:
  `Test-ReleaseRadar-2026.09.09_12-49-18--0400.xcresult` (248 passed; the
  unchanged signed native backup-picker scenario was skipped by design);
- the complete recovery suite, including unassigned backup preservation:
  `Test-ReleaseRadar-2026.09.09_12-47-58--0400.xcresult`;
- real registered-broker unassigned create/place transport:
  `Test-ReleaseRadar-2026.09.09_12-53-49--0400.xcresult`; and
- isolated native rendering plus the externally exercised interaction journey:
  `Test-ReleaseRadar-2026.09.09_12-50-43--0400.xcresult`.

Reviewer corrections were directly rechecked in these additional bundles:

- invariant, policy, navigation and native regression tests:
  `/tmp/release-radar-phase5a-correction-targeted.xcresult` (5 passed);
- affected store, policy, projection, route, archive and removal suites:
  `/tmp/release-radar-phase5a-correction-affected-suites-final.xcresult`
  (230 passed, 1 unchanged signed-native backup-picker scenario skipped);
- a fully externally exercised native focus/filter journey:
  `/tmp/release-radar-phase5a-native-focus-filter-final.xcresult`; and
- two immediate no-rebuild native repeats:
  `/tmp/release-radar-phase5a-native-corrected-repeat1-final.xcresult` and
  `/tmp/release-radar-phase5a-native-corrected-repeat2-final.xcresult`.

The original timestamped bundles are preserved outside Xcode's rolling logs under
`/tmp/release-radar-phase5a-review.Tbu6kw/`; the correction bundles remain
at the explicit `/tmp` paths above. They are temporary diagnostic output rather
than durable evidence artifacts.

The coordinator's combined candidate includes this document and its screenshots
in the catalog and generated indexes. Repository validation does not constitute
application catalog acceptance; application state operations remain unauthorized.

## Native comparison

The isolated XCTest host rendered both surfaces at 1500 × 900 and 760 × 900 in
Dark Aqua. The wide layouts keep a side inspector; compact layouts stack the
inspector below readable, scrollable primary content. The all-phase board preserves
five lanes and excludes the Not placed ticket.

External accessibility control also exercised the native test host from Project
Plan through the unassigned `PLAN-ONLY` item and project-wide Dependencies. Back
readback showed the actual `PLAN-ONLY` card as the focused macOS accessibility
element, not only a matching model identifier. On the all-phase board, accessibility
control selected `ROAD-1` and then filtered to `road-goal-2`; readback showed the
filter summary as the focused accessibility element, `ROAD-1` absent, no selected
ticket, and only the `Select a ticket` empty detail rather than a fallback ticket.
The journey then restored All goals, selected `ROAD-1`, and finished on its
Dependencies path.

The reviewer's first rebuilt native run completed every capture and then reported
an `idle` to `failed(deinit)` transition. A controlled lifecycle reduction exposed
the underlying sandbox denial (Cocoa error 513): the XCTest app host was trying to
delete the externally owned `/tmp` interaction markers. The test now treats those
markers as read-only synchronization input; the external controller creates and
retires them. A fresh build, the full interaction journey and two immediate repeats
all completed without the lifecycle failure. No RDS change or error suppression was
used.

- [Project Plan — wide](phase5a-project-plan-wide.png)
- [Project Plan — compact](phase5a-project-plan-compact.png)
- [All-phase board — wide](phase5a-all-phase-board-wide.png)
- [All-phase board — compact](phase5a-all-phase-board-compact.png)

The comparison used `docs/design/mockups/phase_board.png` as the approved lane
reference and `docs/design/mockups/work_board.png` plus the historical planning
proposal only as partial references. Necessary deviations are recorded in the
dashboard design document.
