# Phase 4 navigation and Ticket Details verification

Non-authoritative verification evidence for the
[Phase 4 brief](../task-briefs/2026-09-08-phase4-navigation/phase4-navigation-brief.md).
Current authorization, integration and review state remain in
[progress.md](../progress.md).

## Implemented behavior

- One model-owned history restores the project registration, explicitly viewed
  phase, board filter, selected ticket and useful focus context. Back/Forward
  restoration does not create another entry, changing the current filter updates
  the current entry, and navigating after Back clears Forward.
- Restoration follows the stable registration identity across lifecycle request
  generations while rejecting a removed-and-re-added registration with a new
  identity. Missing phases and tickets recover in a valid parent scope with an
  explicit explanation and no first-item substitution. Stale asynchronous
  navigation publication is rejected.
- The Dependencies destination is project-wide and remains focused on the selected
  ticket. Cross-phase prerequisites and dependents retain their phase labels. Dense
  paths keep fixed readable node heights on an expandable two-axis canvas.
- Compact Ticket Details uses the available height, exposes a visible scroll
  affordance, and makes each read-only task row keyboard focusable without changing
  task completion, acceptance or lane semantics.
- A fresh model/application session still starts at Projects with empty history.
  Browsing does not change the persisted active phase or issue delivery mutations.

## Focused XCTest result

The final selected Debug/macOS XCTest run passed in
`/tmp/release-radar-phase4-final-2.xcresult`: **35 tests passed, 0 failed,
0 skipped and 0 expected failures** on an arm64 MacBook Pro running macOS 26.5.2.
The selected cases cover history entries and boundaries, branch replacement,
filter/selection/focus restoration, cross-project navigation, archive/removal/
re-add identity, relaunch, late publication, the nonactive-phase integration
journey, project-wide cross-phase dependency projection, dense graph layout,
compact/wide task and dependency rendering, evidence-preview isolation and the
existing Task 10 filter/task projection boundary.

An earlier bundle, `/tmp/release-radar-phase4-final.xcresult`, retained two
failures: a test-only external-interaction marker had not been completed, and an
archive recovery expectation still included a ticket selection that the required
cross-project transition intentionally clears. The expectation was aligned with
that asserted contract, the external native check was completed, and the complete
same selected set then passed in the final bundle above.

## Native accessibility, keyboard and visual checks

The isolated XCTest host used synthetic stores and suppressed external services.
No normal app launch, installation, owner-data operation, notification, service
binding, entitlement change or direct application SQLite edit was performed.

- Accessibility readback exposed enabled Back and disabled Forward controls.
  Actual accessibility button presses exercised both directions in one run.
  In a separate run, actual `Command-[` and `Command-]` key events moved history
  backward and forward and produced the expected boundary states. These are native
  control/shortcut observations, not only calls to the history model.
- Restoring Back from Dependencies returned to the nonactive Roadmap board with
  filter `road-goal-1`, selected ticket `ROAD-1`, and accessibility focus on
  `ticket-ROAD-1`.
- At compact width, accessibility exposed task rows 1 through 16. After focusing
  row 1, fifteen actual Tab events reached row 16; the captured native rendering
  shows the final focus state and visible vertical scroll affordance.
- Wide and compact project-wide dependency views were rendered and visually
  compared with `docs/design/mockups/dependencies.png`. The approved Phase 4 design
  deliberately supersedes the reference's phase-only heading while retaining its
  selected-path, relationship-direction, inspector and visual-language cues.
  The nonactive board and compact Ticket Details were also compared with
  `docs/design/mockups/phase_board.png`.

Canonical captures:

- [History boundary controls](phase4-navigation-history-controls.png)
- [Restored nonactive board focus](phase4-restored-nonactive-board-focus.png)
- [Project dependencies, wide](phase4-project-dependencies-wide.png)
- [Project dependencies, compact](phase4-project-dependencies-compact.png)
- [Compact Ticket Details](phase4-ticket-details-compact.png)

## Retained temporary outputs and limitations

The following temporary diagnostics are retained and are not controlling
artifacts: `/tmp/release-radar-phase4-derived`,
`/tmp/phase4-dependency-attachments`, `/tmp/phase4-compact-task-attachments`,
`/tmp/phase4-history-attachments`, `/tmp/phase4-focus-attachments`,
`/tmp/phase4-native-history.log`, `/tmp/release-radar-phase4-final.xcresult`, and
`/tmp/release-radar-phase4-final-2.xcresult`. Three empty test-coordination
directories were removed with `rmdir` before the no-cleanup boundary was
reiterated: `/tmp/release-radar-phase4-external-history-check`,
`/tmp/release-radar-phase4-compact-task-check`, and
`/tmp/release-radar-phase4-restored-focus-check`. No further cleanup occurred.

Physical VoiceOver speech, other Macs, installation, packaging, owner-data
readback, full-scheme testing and catalog acceptance were not performed. The
orchestrator owns catalog/index integration and the required fresh independent
Sol High review before delivery completion.
