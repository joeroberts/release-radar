# Phase 3B evidence preview verification

This record is non-authoritative verification evidence for the bounded Phase 3B
preview candidate. All exercised repositories, stores, bookmarks and evidence
bytes were synthetic or repository-owned fixtures. No owner application state,
credentials, external service or persisted delivery state was used.

## Implemented limits and custody

- Preview payload: 1 MiB maximum.
- Text: strict UTF-8, at most 131,072 displayed characters; any truncation is
  labelled in the interface.
- Raster: PNG, JPEG, GIF, WebP and TIFF; at most 4,096 pixels per dimension and
  16,000,000 decoded pixels. Malformed images fail closed.
- HTML and SVG are rendered only as inert UTF-8 source text.
- Managed documents are revalidated against the exact accepted binding and
  catalog before each descriptor-relative no-follow read.
- Legacy paths resolve only within an existing authorized primary or worktree
  root for the same project. Paths outside those saved grants are inaccessible.
- Legacy read failures use the same typed mapping as managed reads: missing,
  oversized, inaccessible or rejected. Recovery retains the authorizing root
  identity: primary access routes to Restore, saved worktrees route to exact
  reconnect, and paths outside every saved root require explicit legacy
  evidence relocation rather than ineffective folder recovery.
- Preview content is transient. Observation, selection, root, registration or
  service invalidation withdraws content and rejects late results. This fence
  applies to AppModel, documentation-maintenance live observation and reloads,
  and the shared preview coordinator.

## Direct checks

Focused XCTest covered managed text, checksum rejection, byte and decoded-image
limits, malformed and unsupported formats, primary/worktree legacy reads,
external denial, missing files, stale grants, bookmark-access failure, the
repository reader's greater-than-32-MiB cap, symlink rejection, zero preview
side effects, an in-flight bookmark replacement, strict UTF-8, labelled text
truncation and late-result withdrawal. AppModel and documentation-maintenance
tests exercise success plus during/after-read observation withdrawal. The
maintenance regression also changes the observed source after a successful
preview and proves that the next live observation withdraws access without a
manual load or reload. Native host tests activate the real Preview control in
the evidence component and in the Project Overview, ticket detail and
documentation-maintenance consumers; they also prove that this live source
change removes already-rendered preview bytes, and exercise inaccessible
worktree guidance, its recovery action, refresh and successful retry.

Final focused result bundle:
`/tmp/release-radar-phase3b-live-final/Logs/Test/Test-ReleaseRadar-2026.09.08_11-21-42--0400.xcresult`.
Direct `xcresulttool` readback reports 75 passed, 2 skipped and 0 failed across
the preview, shared-observation, managed-presentation, rendering, managed
resolution, root-management, relocation, maintenance and
documentation-rendering suites. The two skips remain the unchanged signed,
owner-assisted native folder-picker scenarios.

The focused native host used accessibility to press the actual Preview button
before reading UI state and capturing both 620- and 1,100-point layouts.
Accessibility readback contained locator identity, availability and readable
preview content at both sizes. The canonical screenshots below were exported
from the prior post-interaction rendering run and visually inspected at 1,240×1,040 and
2,200×1,040 pixels respectively. Their exported bytes match the existing
canonical files, so no binary diff is expected.

- [Compact preview](phase3b-preview-compact.png)
- [Wide preview](phase3b-preview-wide.png)

Temporary XCTest result bundles and exported attachment directories remain
under `/tmp/release-radar-phase3b-*`. No cleanup was performed.
