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
- Preview content is transient. Observation, selection, root, registration or
  service invalidation withdraws content and rejects late results.

## Direct checks

Focused XCTest covered managed text, checksum rejection, byte and decoded-image
limits, malformed and unsupported formats, primary/worktree legacy reads,
external denial, missing files, stale grants, symlink rejection, zero preview
side effects, an in-flight bookmark replacement, strict UTF-8, labelled text
truncation and late-result withdrawal. Existing shared-observation and managed
presentation suites were run with the new preview tests; native-only owner-picker
tests remained intentionally skipped and their unchanged Phase 3A evidence is
reused.

Final focused result bundle:
`/tmp/release-radar-phase3b-race-green/Logs/Test/Test-ReleaseRadar-2026.09.08_10-22-58--0400.xcresult`.
Direct `xcresulttool` readback reports 66 passed, 2 skipped and 0 failed across
the preview, shared-observation, managed-presentation, rendering, managed
resolution, root-management, relocation and documentation-rendering suites.

The focused native-host rendering check passed at 620- and 1,100-point widths.
Accessibility readback contained locator identity, availability and the readable
preview content at both sizes. These screenshots establish component rendering
and accessibility state. They do not claim an end-to-end consumer click journey;
the request coordinator and real consumer wiring are covered by focused XCTest.

- [Compact preview](phase3b-preview-compact.png)
- [Wide preview](phase3b-preview-wide.png)

Temporary XCTest result bundles and the exported attachment directory remain in
their generated locations. No cleanup was performed.
