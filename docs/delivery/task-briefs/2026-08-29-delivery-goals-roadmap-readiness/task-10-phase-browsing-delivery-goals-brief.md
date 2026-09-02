# RR-R10 Task 10: Phase browsing and Delivery Goals

## Objective and outcome

Implement [Task 10](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-10-present-non-mutating-phase-browsing-and-delivery-goals)
under the approved [Phase Board contract](../../../design/release-radar-delivery-goals-phase-board-design.md),
[RR-R10 design](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md)
and ADR-001/003/004. Owners can browse phases without changing active execution,
filter the existing five lanes by Delivery Goal, inspect separate Tasks,
Delivery Goal and Codex execution goal sections, and explicitly accept an
Awaiting-acceptance Delivery Goal in Needs Review through the owner boundary.

## Scope and exclusions

Create PhaseBoardPlanningControls.swift; change PhaseBoardView,
ActivePhaseSelector, TicketDetailView, AppModel, SidebarView, NeedsReviewView,
AppRouteTests. The existing empty ReleaseRadarUITests target stays unchanged;
the approved isolated AppRoute fixture plus external AX/keyboard method supplies
the UI checks without a new runner or scheme. Consume Task 9 projections unchanged.
Keep viewed-phase state per project, separate from the persisted active phase.
Keep Make active phase explicit, audited and recoverable. Preserve exact UTF-8
projection identity, five lane identities, stable goal/unassigned filtering,
canonical Task 5 counts and tri-state read-only tasks, and existing evidence
identity, resolution, authority and recovery. Add trusted owner-only acceptance
with revision, authorization and saved-refresh failure recovery.

No Core persistence/schema/dependency changes, MCP acceptance exposure, task-row
actions, notification changes, owner installation, live goal acceptance,
bootstrap, Task 11 integration, shared-service tests, cleanup or Issue #9 repair.
The owner explicitly deferred the stacked Details-pane height/scroll affordance.

## Dependencies

Task 9 PR #12 merged at ea2f0f0a4cf36e7bf5de89ee030b5f98eafadf34;
the coordinator verified its direct checks, independent review, live revision 14
and brief closeout. This isolated worktree starts from that merged base on
codex/rr-r10-task-10. Owner standing authorization covers planning, test-first
implementation, validation, independent review, commit/push, one PR/merge and
exact live task completion. Coordinator 01a06184-6387-7c42-878e-695db0481a18 owns
routine scope/sequencing and documentation accuracy; authorized test-first work
may proceed during scope inspection. Preserve the separate old dirty checkout.

## Material risks

Browsing must never create an active-phase audit or rewrite the pointer.
Filtering and refresh must not misattribute goals, lose valid focus/selection,
show stale readiness as current, or discard tasks/evidence. Owner acceptance
must require active exact-root authorization and trusted .ownerApp dispatch;
stale revision, failure and committed-but-unrefreshed results must not invite
duplicate mutation. No synthetic test may implicitly start shared services.

## Test strategy

Use native XCTest RED/GREEN checks for AppModel browsing/active separation,
per-project state, explicit Make-active mutation, filters/lane identity,
task/evidence retention, authorization/origin and revision/refresh failure.
Add focused UI assertions using the existing native isolated fixture/window
approach, with a fresh signed candidate and unique test app identity, preserving
the built Debug XCTest host entitlements and inert LaunchServices startup.
Use hosted rendering/model assertions plus external Computer Use accessibility
readback and key events against the confirmed-running isolated test app. The
in-process AXWindows query returns no window in this host; coordinator-approved
external inspection replaces that query, not the behavioral criteria. No new
XCTest runner or scheme is required. Perform one wide/compact runtime
comparison against phase_board.png and needs_review.png for the changed
controls, focus, inspector headings and task regression. Do not repeat Task 5's
exhaustive visual matrix. Distinguish runtime evidence, native AX assertions and
unverified physical keyboard/spoken VoiceOver behavior. Required focus/announcement
behavior must have direct evidence or be reported as a precise unresolved gap.

Build with xcodebuild build-for-testing -project ReleaseRadar.xcodeproj -scheme
ReleaseRadar -configuration Debug -destination 'platform=macOS' using
.build/rr-r10-task10; run only named AppRoute/UI tests through the isolated
xctestrun. Run ReleaseRadarDocumentationTool write/check --root for this
worktree and git diff --check. Durable accepted UI evidence goes in
docs/delivery/evidence with catalog entries; temporary build/test outputs are
retained without cleanup.

## Acceptance criteria

- Viewed phase and active phase stay visibly and behaviorally distinct,
  including no-active-pointer, reload and per-project navigation cases.
- Planning summary truthfully reports state, revision, coverage/unassigned,
  completed delivery and legacy continuation; goals do not replace lane state.
- Goal/unassigned filters retain five lanes and selected-ticket focus when
  visible; hidden selection moves to an accessible filter summary.
- Tasks precede separate Delivery Goal and Codex execution goal sections.
  Evidence and observation failure semantics remain intact; no row actions.
- Needs Review includes derived goal attention and owner-only explicit Accept
  with criteria, trusted dispatch, exact revision and recoverable errors.
- Direct checks, focused runtime comparison and independent acceptance pass
  before pushing reviewed implementation. Complete rr-r10-task-10 through the
  installed typed tool at a freshly established exact revision (expected
  14 to 15), retaining exact request on uncertainty. Verify result/replay and
  complete inventory preservation without claiming inventory exposes raw rows.
- Record exact live revision/audit, close this brief completed/non-authoritative,
  reconcile catalog/indexes/ledger, commit/push this branch and merge one PR into
  codex/release-radar-mvp. Catalog deployment/acceptance remains separately
  pending. The coordinator alone opens Task 11A after verification.

## Risk-triggered reviews

Coordinator scope/sequencing inspection and one independent qualified QA/UX plus
Security/Privacy reviewer for actual changed UI and owner-acceptance boundaries.
The reviewer inspects implementation and runtime evidence, not prior reviews.
Required defects receive bounded correction and only directly affected checks.
