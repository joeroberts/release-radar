# C6 remove-from-tracking UI evidence

## Scope

This evidence covers the exact-registration removal confirmation and the retained read-only Removed Project surface. It was rendered from synthetic test data only; no owner project, app store, saved authorization, notification provider, or repository content was read or changed.

## Direct evidence

- Wide confirmation: `c6-remove-confirmation-wide.png` at 1100 points.
- Compact confirmation: `c6-remove-confirmation-compact.png` at 620 points.
- Wide retained history: `c6-removed-history-wide.png` at 1100 points.
- Compact retained history: `c6-removed-history-compact.png` at 620 points.
- `ProjectDocumentationRenderingTests.testProjectRemovalConfirmationAndRemovedHistoryAtWideAndCompactWidths` rendered all four states in dark appearance, walked the test process's own accessibility hierarchy, verified the exact project and registration, destructive scope, retained-history explanation, cancellation, retryable failure, and absence of restore or management actions, and passed.

The final PNGs were exported from that passing test result and visually inspected at their original resolution. Text is not clipped, compact content reflows without horizontal truncation, the confirmation distinguishes live-data deletion from untouched repository files, and the Removed surface is visibly read-only with no restore action.

## Design comparison

The new surfaces were compared with the approved project, phase-board, history, settings, and C5 archive evidence references. They preserve Release Radar's dark desktop palette, blue outlined cards and separators, restrained status color, monospaced identity metadata, responsive `ViewThatFits` composition, and activity-card hierarchy. C6 has no dedicated approved mockup, so the necessary deviation is a new explicit removal warning and a Removed status/history surface; both reuse existing design-system components and established project-lifecycle patterns rather than introducing a separate visual language.
