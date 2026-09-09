# Phase 5A recorded planning verification

## Verified outcome

Phase 5A adds an authoritative unassigned ticket state, exact first placement into
a same-project phase Backlog, Project Plan, and explicit phase/all-phase board
scope. Placement preserves the ticket identity and its task definitions,
dependencies, evidence and audit history. Unassigned tickets remain outside all
five execution lanes and cannot execute, complete tasks, request review or record
completion before placement.

The packaged agent helper exposes separate `release_radar_upsert_unassigned_ticket`
and `release_radar_place_unassigned_ticket` tools. Placement requires the exact
destination plan revision. Existing placed-ticket tool fields remain required, so
omitting a phase or lane cannot silently convert placed work to unassigned work.

## Direct checks

All tests used an isolated derived-data directory and the XCTest app host, with
external services suppressed by the existing test launch configuration.

- Store migration: frozen v12 graph/history and a populated v18-era graph migrate
  to schema v19 with nullable placement, clean foreign keys and no record loss.
- Policy and command boundary: pre-placement execution/task completion/review/
  completion and legacy-upsert bypass fail without effects; stale and cross-project
  placement fail; exact replay retains one request receipt and audit.
- Projections and navigation: all phases, readiness, phase-owned goals and Not
  placed details agree; all-phase board has exactly five lanes and one phase label
  per card; the No Delivery Goal filter is distinct from No phase; Back restores
  Project Plan/all-phase scope, selection and focus; Dependencies selects an
  unassigned node labelled Unassigned.
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

The bundles remain under `/tmp/release-radar-phase5a-derived/Logs/Test/`; they
are temporary diagnostic output rather than durable evidence artifacts.

## Native comparison

The isolated XCTest host rendered both surfaces at 1500 × 900 and 760 × 900 in
Dark Aqua. The wide layouts keep a side inspector; compact layouts stack the
inspector below readable, scrollable primary content. The all-phase board preserves
five lanes and excludes the Not placed ticket.

External accessibility control also exercised the native test host from Project
Plan through the unassigned `PLAN-ONLY` item, Open all-phase board, accessible
selection of `ROAD-1`, project-wide Dependencies, Back and Forward. Readback after
Back showed `ROAD-1` selected and focused inside the restored board scroll area;
Forward restored the `ROAD-1` dependency path and correctly moved navigation focus
to Dependencies. macOS accessibility exposes the focused visible element and the
scroll container, but not a stable numeric SwiftUI scroll offset, so the check does
not claim byte- or coordinate-exact offset restoration.

- [Project Plan — wide](phase5a-project-plan-wide.png)
- [Project Plan — compact](phase5a-project-plan-compact.png)
- [All-phase board — wide](phase5a-all-phase-board-wide.png)
- [All-phase board — compact](phase5a-all-phase-board-compact.png)

The comparison used `docs/design/mockups/phase_board.png` as the approved lane
reference and `docs/design/mockups/work_board.png` plus the historical planning
proposal only as partial references. Necessary deviations are recorded in the
dashboard design document.
