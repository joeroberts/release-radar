# Phase 4 — Coherent navigation and usable Ticket Details

## Objective and outcome

Deliver RM2, P7/P8 and issue #9 as one complete existing-surface journey: browse a
nonactive phase, select its ticket, inspect its project-wide dependencies, and use
Back/Forward to recover the exact board context and meaningful focus. Make compact
Ticket Details use available space and expose all its content without changing
any formal delivery or task semantics.

The owner authorized source/tests/docs, scoped commits, pushes and PRs. On
2026-09-08 the owner explicitly selected project-wide Dependencies focused on the
selected ticket with phase labels, and Projects with empty history on relaunch.
No other proposed Phase 5 contract is selected by this brief.

## Scope, dependencies and future consumers

Use the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-003 and its Phase 4 amendment](../../../architecture/ADR-003-active-phase-selection.md),
[ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md),
[dashboard design](../../../design/agent-driven-delivery-dashboard-design.md),
[Ticket Tasks design](../../../design/release-radar-ticket-tasks-design.md), and
[Phase Board](../../../design/mockups/phase_board.png) /
[Dependencies](../../../design/mockups/dependencies.png) references.
The dependency mockup's phase-only label is superseded by the explicit scope
amendment; record any other necessary deviation in the existing design document.

Phase 3 is merged at `6f528c551b2c8de1597ad29a108a749712d26a6c`. The delivery
assignment names a committed descendant containing this brief and the amended
contracts. One writer owns the navigation/board/dependency integration and inspector.
Likely source boundaries are AppRoute, AppModel, SidebarView, the app shell/commands,
PhaseBoardView and planning bindings, TicketDetailView, and dependency projection/
view. Follow current source rather than treating this inventory as a required diff.

Phase 5 planning/impact links and Phase 6 goals/search/saved views must later enter
the same typed navigation boundary. They do not require future cases, screens,
filters or infrastructure now. No persistent navigation state, schema migration,
external URL registration, package format or Phase 7 export/import change is needed.
Preserve saved-view compatibility by keeping unsupported scope/filter states
explicit; never silently broaden them. RDS is consumed as supplied; appearance,
light/dark work and changes to the shared library are excluded.

## Acceptance criteria and material risks

- One typed history owns destination, project/registration identity where needed,
  explicit viewed phase/scope, current filter, selected entity and restoration/
  focus context. Existing sidebar, links, phase navigation, navigation buttons and
  standard keyboard Back/Forward commands share it. Capture the current context
  before leaving; restoring history does not add a new entry; branching clears
  Forward. Filter adjustments update the current entry, avoiding a step per edit.
- A nonactive-phase ticket opens its own project-wide dependency relationships,
  labelled by phase, including prerequisites/dependents across phases. Preserve
  the selected ticket, direction and truthful empty/error states. Dense paths
  remain legible/reachable rather than compressing or clipping every node. No
  wrong-project content or silent active-phase/first-ticket substitution.
- Back/Forward restores project, viewed phase, filters, selection and appropriate
  keyboard/accessibility focus; selected content remains reachable. Focus returns
  to the originating valid control/entity or a useful heading/recovery message.
  Verify boundary disablement, repeated navigation and branching.
- Empty, archived, removed or stale project/phase/ticket/filter targets recover
  honestly. Preserve a valid parent scope with an unavailable-selection explanation;
  never silently select a different ticket/phase or broaden a stale filter.
  Archive/removal uses existing read-only presentation and exact historical identity.
  Removal/re-add and recovery generations cannot redirect old history into a new
  registration by matching a path/name. Reject stale asynchronous publication.
- Browsing and history never select the persisted active phase, move a lane, alter
  readiness/task completion/acceptance, or issue other delivery mutations. Existing
  explicit Make Active remains separate. Preserve existing first-dashboard-open
  bookkeeping only where current behavior requires it; it is not a new audit of
  every navigation. Preserve evidence-preview invalidation and existing access rules.
- On a fresh model/application relaunch, start at Projects with empty history.
  Closing/reopening a detail during a session is not application relaunch. Do not
  persist navigation or change other saved preferences to implement this policy.
- Compact Ticket Details uses available vertical space, advertises overflow and
  allows ordinary scrolling/keyboard access to first and last task rows. Retain
  the wide side inspector, wrapping and native accessibility. Card count and list
  membership still derive from existing active task projection; no fixed row limit,
  completion/total fraction, altered denominator or acceptance semantic change.

## Direct verification and isolation

Use test-first changes and repository-native XCTest. Cover the nonactive-phase →
ticket → Dependencies → Back/Forward integration, cross-project navigation and
cross-phase edges, branching/boundaries, filter/selection/focus restoration,
empty/stale/missing targets, archive/removal/re-add, relaunch and late publication.
Exercise the actual app model/shell boundary, not only a standalone history type.
Retain focused dependency-policy and task-plan tests where their behavior is touched.

Use the existing isolated XCTest host from AppLaunchConfiguration and synthetic
stores with external services suppressed. Inspect every runner/script before use.
No normal installed-app launch or owner secrets just to set up a test. Focused
command shape: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar
-configuration Debug -destination 'platform=macOS' -derivedDataPath <isolated-build>
-only-testing:ReleaseRadarTests/<relevant-suite-or-method>`.
Inspect the scheme/host and run only the directly relevant suites/methods.

Perform native UI/keyboard/accessibility checks and capture compact/wide results
against the two approved references, including long task content, dense dependency
paths and restored focus. The Mac is available now. A test-only filesystem bypass
or broad exception is not shipping-boundary evidence. No entitlement changes.
If a check truly requires owner participation, name the exact missing evidence;
do not claim complete UI/installed acceptance. Hands-on testing on other Macs and
private DMG preparation wait until September 11 or later and do not gate source
PR delivery. Existing unrelated skips/failures remain separately reported.

## Assignment, ownership and delivery endpoint

Delivery: fresh Terra Medium task/worktree; escalate a named implementation problem
to Sol High only when needed, ceiling Astra High. No xhigh/max or Ultra. Orchestrator
owns progress, catalog and generated indexes. Delivery owns necessary product code,
tests, affected product design clarification, this brief and canonical verification
evidence; report new artifacts to the orchestrator for catalog integration.

One fresh independent Sol High reviewer covers the combined navigation contract,
code, native UX/QA, registration and preview-isolation risks. Independent context
must include this original outcome and direct evidence. Only Required findings
block; bounded corrections repeat affected checks and review. No review of reviews.

Finish scoped commits, pushed branch and PR to `codex/release-radar-mvp`, with
verification results and precise limitations. Every merge requires owner approval.
No installation, owner-data operation, direct SQLite edit, application binding or
catalog acceptance, credentials, real notifications, plugin/cloud mutation,
entitlement change, publication, packaging or cleanup is authorized. No external
security scan is implied by review. Preserve unrelated files and retained outputs.
Report temporary artifacts and running processes; do not delete them. Archive the
bounded task only after useful results are canonical and its work has stopped.
