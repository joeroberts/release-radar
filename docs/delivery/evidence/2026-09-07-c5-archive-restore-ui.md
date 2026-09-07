# C5 archive and restore native verification

## Scope

Non-authoritative verification evidence for the
[C5 archive and restore brief](../task-briefs/2026-09-07-c5-archive-restore/c5-archive-restore-brief.md).
The native XCTest host used synthetic project identity, counts, and local stores.
It did not install the app, read or mutate owner application data, send a
notification, or change an external service.

## Direct native checks

`ProjectDocumentationRenderingTests.testProjectArchiveAndArchivedDetailAtWideAndCompactWidths`
passed at 1100- and 620-point content widths. The mounted native views exposed
the exact project, registration, request generation, retained graph counts,
archive and restore actions, and read-only archived state through accessibility.
The same test pressed **Archive Project** and kept an actionable stale-preview
failure visible without dismissing the confirmation; pressing **Cancel** did
not invoke the lifecycle mutation.

The post-review correction added focused non-UI coverage proving that an archived
project rejects operational documentation binding without losing read-only
documentation context, and that an ordinary command resolved before archive cannot
mutate after restore while a freshly resolved post-restore command succeeds. The
bridge now revalidates the exact registration generation inside both mutation
transactions before consulting durable receipts. No UI code or captured native state
changed, so the native render was not rerun for this correction.

The confirmation initially clipped the preservation explanation in visual
inspection. The text was allowed to grow vertically, the same native test
passed again, and the final attachments below were re-inspected with the full
message visible at both widths.

## Visual comparison

The final [wide archive confirmation](c5-archive-confirmation-wide.png) and
[compact archive confirmation](c5-archive-confirmation-compact.png) show the
explicit target, retained counts, non-deletion promise, notification treatment,
cancel action, and primary archive action. The final
[wide archived project](c5-archived-project-wide.png) and
[compact archived project](c5-archived-project-compact.png) show a deliberately
read-only surface with retained counts, preserved registration identity, and
the only lifecycle action, **Restore Project…**.

The four screenshots retain the approved dark Rekon Design System vocabulary
and were compared with `docs/design/mockups/settings.png` and
`docs/design/mockups/phase_board.png`. The compact layouts wrap safety guidance,
retain labelled actions, and do not expose project settings, repository-root
management, or documentation setup while archived.

## Migration compatibility correction

A post-review migration run exposed two C5-specific issues. The synthetic v3,
v7, and v13 End-to-End fixtures had been built by downgrading a current database
without removing the v16 `projects.lifecycle` column. Those fixtures now remove
that future column before claiming a historical version, while strict schema
recognition and the production migration remain unchanged.

The run also demonstrated a production compatibility issue in preservation
readback: a pre-v16 project has an implicit active lifecycle, while the v16
migration persists that same state as `active`. Preservation hashing now
normalizes only a missing pre-v16 lifecycle to that migration default. Explicit
v16 `active` and `archived` values remain distinct and unchanged. The Task 7A
raw-row fixture comparison applies the same missing-only normalization.

The ten directly affected historical migration cases passed after this bounded
correction, including the four malformed-schema fail-closed controls. The prior
targeted C5 batch passed 344 tests including the dashboard containment case; it
and the unchanged native UI were not rerun for this migration-only correction.
