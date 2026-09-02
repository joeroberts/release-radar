# Rendering test discovery repair

Completed and non-authoritative. The implementation and independent code/QA
review are accepted; current delivery and Task 11B authorization remain in the
[progress ledger](../../progress.md).

## Objective and outcome

Diagnose and repair the four original rendering selectors blocking RR-R10
Task 11B. Establish the cause and pass their complete existing behaviors in an
isolated native run, then independently review and deliver one PR to
`codex/release-radar-mvp`.

## Scope and exclusions

Work only on `codex/rr-r10-rendering-test-repair` in its dedicated worktree.
The implementation boundary is `ManagedEvidenceRenderingTests.swift`,
`ProjectDocumentationRenderingTests.swift`, and their immediate test-only
fixture if necessary. Preserve all assertions, own-process/titled-window
scope, states, widths, persistence/recovery checks, and failure semantics.

The retained maintenance result reports all four selectors failing to find
their titled AX window. Both helpers first enumerate `AXWindows` using an
AX client pointed at their own PID. External inspection previously observed
rendered content; moving that client call off MainActor did not fix discovery.
The initial diagnostic will compare AX status/window titles with the same
window's native accessibility data to identify the failing boundary. A
test-only correction must follow that evidence, with coordinator scope and
currentness review before implementation.

No product defect is established. Product-source changes require evidence and
coordinator disposition. Exclude installed-app/helper changes, live data or
tracking operations, document deployment/catalog acceptance, permissions,
signing/entitlements/configuration changes, new harnesses or dependencies,
the fixed-service tests, Issue #9, Task 5/10's full UI matrix, and cleanup.
Task 11B remains paused; this work creates no live repair row.

The coordinator additionally permits one temporary read-only Swift AX probe
and one original-selector inspection run to resolve external observation
identity. Bind only to the already-running isolated test PID, verify its exact
task-local executable and test-log identity, and check trust without prompting.
Read only that application's window attributes; do not launch, activate, send
events, mutate attributes, or change permissions. Stop on denied access or an
unresolved identity/lifetime. Retain the probe and output only as temporary
diagnostics; they are excluded from the repair implementation.

## Dependencies

- Task 11A delivered baseline: `3ae19c6e0d7ca2e1baf6458f6fd73670748c9af0`.
- The [RR-R10 plan](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md)
  and [progress ledger](../../progress.md).
- Task 11B's retained original failure result is read-only evidence; its
  uncommitted operation package and candidate remain untouched.

## Material risks

The main risks are mistaking discovery failure for a product defect, reducing
coverage, inspecting another process/window, and touching fixed services or
owner state. Use the existing inert XCTest host and synthetic fixtures, exact
test selectors, task-local DerivedData, serial runs, and real accessibility
data. Report any required expansion before acting.

## Focused tests and acceptance criteria

- Reuse the existing red result; run a targeted diagnostic only with a new
  hypothesis. Preserve diagnostic output in temporary build storage.
- Pass both methods of `ManagedEvidenceRenderingTests` and both methods of
  `ProjectDocumentationRenderingTests` serially with no skips and all existing
  content, recovery, persistence and PNG attachment behavior intact.
- Use repository-native `xcodebuild`, documentation `write`/`check`, and
  `git diff --check`. Compilation alone is not runtime evidence.
- Keep catalog identity/indexes and relative references valid. Development
  documentation stays pending later separately authorized live acceptance.
- Record the supported cause, direct results, review and remaining limits in
  the existing progress ledger. Commit only this repair, push, open one PR and
  merge under the owner's standing authorization. Only the coordinator may
  resume Task 11B after reconciliation and any new maintenance approval.

## Independent review

One independent code/QA reviewer must accept the test-only correction and its
direct evidence, including unchanged assertion coverage and isolation. Add a
specialist only if a concrete changed risk requires it.
