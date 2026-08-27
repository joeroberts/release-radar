# RR-R3 Implementer Report

## Result

- Store schema v8 now persists one exact `(project, ticket, thread, goal)` identity with composite foreign keys and project-local uniqueness for both ticket and goal.
- The v7 backfill creates a link only when the ticket has one linked thread, the thread has one project-local goal, and the thread belongs to one ticket. Ambiguous legacy records remain unlinked, all source records remain intact, and persisted ticket outcomes are not rewritten.
- `AgentCommand.linkGoal` validates project ownership and an existing exact ticket/thread relationship, rejects invalid references and cross-ticket goal reuse transactionally, and records one ticket-scoped audit that replays durably.
- Ticket detail, ticket-attributed Activity rows, and goal-blocked notifications now consume only the approved exact identity. A newer unapproved goal on the same thread cannot replace it.
- Fresh dashboard seeds use descriptive `tickets.outcome` copy. The existing audited `upsertTicket` path remains the only ticket-content mutation and continues to edit that same field.

## Files changed

- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- `ReleaseRadarCore/Notifications/MeaningfulDeliveryEvent.swift`
- `ReleaseRadar/Projects/DashboardSampleData.swift`
- `ReleaseRadar/Projects/DashboardProjection.swift`
- `ReleaseRadar/Activity/ProjectActivityProjection.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`
- `ReleaseRadarTests/DashboardProjectionTests.swift`
- `ReleaseRadarTests/NotificationAcceptanceTests.swift`
- `ReleaseRadarTests/EndToEndAcceptanceTests.swift` (v8 expectations and downgrade-fixture compatibility only)

The approved RR-R3 ADR section was already present and was preserved. `TicketDetailView.swift` already renders `tickets.outcome` as its sole description and the existing `No linked goal` state, so no implementation change was necessary there.

## TDD evidence

- RED: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests -only-testing:ReleaseRadarTests/DashboardProjectionTests -only-testing:ReleaseRadarTests/NotificationAcceptanceTests`
  - Exit 65 as expected: the new acceptance tests could not compile because `AgentCommand` had no `linkGoal` member.
- GREEN: the same focused command.
  - Exit 0; 63 selected tests passed with zero failures or skips.
- Impacted recovery coverage: the focused command plus `EndToEndAcceptanceTests`.
  - Exit 0; 71 selected tests passed with zero failures or skips.
- Build: `xcodebuild build -project ReleaseRadar.xcodeproj -scheme ReleaseRadar`
  - Exit 0; `BUILD SUCCEEDED`.
- `git diff --check`
  - Exit 0.

## Migration and integrity evidence

- Isolated v7 fixture: one unambiguous identity backfilled; multiple-ticket-thread, multiple-goal-thread, and shared-thread cases remained unlinked. Ticket, goal, and thread-link counts were preserved, and the owner-authored outcome was unchanged in both the migrated database and pre-migration snapshot.
- Relaunching the migrated fixture retained exactly one link and did not rerun or duplicate the backfill.
- Fixture schema inspection confirmed both exact composite foreign keys, the required observed-goal parent key, both project-local unique indexes, and a clean `PRAGMA foreign_key_check`.
- Duplicate ticket identity and duplicate goal identity writes were rejected. Reobserving a linked goal on a different thread rejected and rolled back the goal, link, and audit changes.
- Missing, cross-project, wrong-thread, and cross-ticket-reuse `linkGoal` requests left link, audit, and replay counts unchanged.

## Product evidence and boundaries

- The phase-board mockup and the controlling State ownership, Agent tool contract, and Phase board design sections were inspected before implementation.
- Projection tests verify the approved older goal remains the detail and ticket-attributed Activity identity while a newer unapproved goal remains ticketless.
- Notification tests verify only the approved goal produces the ticket's blocked alert.
- Fresh-seed tests verify descriptive card outcomes and subsequent audited `upsertTicket` editing.
- Per the RR-R3 scope restriction, the normal app was not launched, no owner database was inspected or mutated, and no persisted owner outcome was rewritten. Consequently, this report makes no live visual-runtime acceptance claim.

## Required fix round 1 — stable goal-link identity

- Independent review found that reusing an existing `ticket_goal_links.id` with a different otherwise-valid ticket and unused goal could move the link while auditing only the new ticket. The root cause was project-only ID validation followed by an `ON CONFLICT(id)` update that permitted `ticket_id` replacement.
- RED: the existing `testLinkGoalRejectsMissingCrossProjectWrongThreadAndCrossTicketReuseWithoutWrites` gained one compact case with a second valid unused goal. The direct test exited 65 because the cross-ticket ID reassignment succeeded instead of returning `invalidReference`.
- GREEN: `linkGoal` now requires an existing link ID to retain its original project and ticket. The same direct test exited 0 and proves the rejected command leaves the link, audit count, and durable replay count unchanged while preserving the original `RR-03|goal-approved` identity. Updating the approved goal for that same ticket under the same ID remains supported.
- Preservation: Store, Agent Bridge, Dashboard Projection, Notification, and impacted End-to-End acceptance suites passed together with exit 0. `xcodebuild build` and `git diff --check` also passed with exit 0. Only the already-recorded optional-`.none`, test actor-isolation, and signed-binary stripping warnings appeared.
- Scope: only `AgentCommandDispatcher.swift`, the existing Agent Bridge rejection test, and this report changed in the fix round. No application runtime or owner database was accessed.

## Remaining review gates

- Independent code review, QA migration/behavior verification, architecture review, security/privacy verification, TPM review, and Delivery Manager recording remain required by the task brief.
