# Phase 5C saved plan-change proposals

## Delivered boundary

Phase 5C persists immutable proposal versions with an app-captured planning
baseline, derived grouped diff, rationale, exact recorded source impacts, separate
owner decisions and a unique atomic application record. External agents can use
the packaged `release_radar_save_plan_change_proposal` tool and read the resulting
history through `release_radar_plan_change_proposals`. The package intentionally
does not publish decision or apply tools: those remain trusted owner-app actions,
and external-origin attempts are rejected before replay lookup.

The native Project Plan workflow presents proposal history and exact versions,
keeps Approve separate from Apply, offers rejection and refresh, reports stale or
unavailable state without changing the graph, and restores exact proposal/source
focus through Back and Forward.

## Direct verification

- `16-contract-native.xcresult`: all 12 proposal acceptance tests passed, covering
  save/relaunch/immutability, exact decisions and replay, the complete additive
  work package, late-failure rollback, every declared baseline category, stale
  refresh/reapproval, source impacts, removal and older-backup reconciliation.
- `23-targeted.xcresult`: 78 passed, 1 failed and 0 skipped across the full proposal,
  dashboard, project-removal, recovery and navigation suites plus the two native
  proposal tests. Its sole failure was a synthetic v16 downgrade fixture retaining
  schema-21 triggers. The bounded fixture correction then passed 1/1 in
  `25-migration-fix.xcresult`.
- `22-live-focus.xcresult`: 1/1 passed. External accessibility inspection observed
  exact wide and compact focus identifier
  `proposal-source-impact-ROAD-1:proposal-requirement:1`; compact navigation brought
  that row into view, deliberate proposal selection moved focus to the proposal
  row, and Back restored the exact source focus before Forward reopened the source
  route.
- `26-packaged-entrypoints.xcresult`: the authorized proposal query and packaged
  schema tests passed (2/2); the inert parser test reached its intended final local
  guard but its assertion expected different wording. The assertion-only correction
  passed 1/1 in `27-packaged-parser.xcresult`. The parser test never connected to or
  registered the owner bridge.
- `30-required-green.xcresult`: all 5 reviewer-regression tests passed, covering
  changed and unavailable recorded sources, stale planning baselines, complete
  owner-visible definitions and post-await query withdrawal after lifecycle or
  registration changes.
- `31-required-affected.xcresult`: 18/19 affected proposal, projection and navigation
  tests passed. Its sole failure was the native-render fixture's obsolete synthetic
  source setup. The corrected fixture binds a valid managed catalog and records the
  real current source through public commands; `39-native-corrected.xcresult` then
  passed the exact native selector 1/1.
- Repository diff whitespace validation passed. The final wide and compact captures
  below were exported unchanged from the passing native-render test in
  `39-native-corrected.xcresult` and compared with the approved
  [Phase Board](../../design/mockups/phase_board.png) and current Plan composition.

## Native captures

![Wide Project Plan proposal inspector](2026-09-10-phase5c-proposals-wide.png)

![Compact Project Plan proposal list and stacked flow](2026-09-10-phase5c-proposals-compact.png)

## Limitations and retained raw evidence

The earlier live journey deliberately points to a missing document, so it verifies
honest `rootUnavailable` recovery, exact history and focus restoration rather than
successful current-source resolution. The corrected native-render fixture uses a
valid managed catalog and real recorded source; its wide inspector capture shows
the complete grouped definitions and source impact. The compact static capture
records the top of the stacked Plan flow, while the live journey supplied the direct
scrolling/focus observation.

`24-migration-fix.xcresult` contains no executed test because the first sanitized
rerun omitted the no-signing overrides; it is retained but is not completion
evidence. Runs 32 and 33 likewise contain no executed test after setup failures;
runs 34 through 38 are retained diagnostic failures that isolated the native fixture
path mismatch corrected in run 39. All raw bundles, attachment exports and one-shot
marker files remain under `/private/tmp/release-radar-phase5c-writer/`. The run-39
fixture remains under `/Users/Shared/ReleaseRadar-RR9Owner-4BF8E306-45B1-4E91-BCCB-E2D6E431172B/`,
and its path preflight remains under
`/Users/Shared/ReleaseRadar-Phase5C-Preflight-C5B53D27-D3F9-4576-B6B1-1D5D1561BA81/`.
No installed owner application, credentials, external service, repository content
outside this worktree, push or pull request was changed.
