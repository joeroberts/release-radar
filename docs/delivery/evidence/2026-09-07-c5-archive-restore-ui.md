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

## Verification limitation

The directly affected storage, notification, onboarding, bridge, route, and
dashboard suites passed. One pre-existing containment fixture was excluded from
the dashboard batch by its exact name:
`DashboardProjectionTests.testInactiveBoardPreservesAuthorizedEvidenceMetadataAndRecovery`.
Its independent reproducer fails before the projection runs because this macOS
Foundation reports the Darwin temporary directory below `/var`; the hardened
descriptor reader correctly rejects `/var` because it is a symlink. The same
environmental condition prevents the existing `ProjectRootManagementTests`
fixtures from reaching root-management behavior. No production containment or
authorization rule was weakened. C5 lifecycle, rollback, stale-preview,
notification ambiguity, mutation-admission, projection, route, restart, and
zero-phase behavior passed in `ProjectArchiveAcceptanceTests`.
