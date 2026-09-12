# Phase 6 extension: project management and persistent toolbar

Status: owner-requested design candidate for feature architecture, chief architecture and UX review. No implementation authorization. The stopped Overview metric task remains stopped. This proposal is separate from the 0.1.11 release and the Add Project styling correction.

## Owner outcome

Reduce Overview/sidebar clutter, make shared navigation and search persistent, and evaluate an RDS-owned toolbar reusable across Rekon applications. Preserve existing navigation, search, saved-query, lifecycle, authorization and data behavior unless the explicit interaction changes below require a change.

[Latest owner-directed static mockup](mockups/phase6-persistent-workspace-toolbar-proposal.png). This generated image communicates layout only; text below is authoritative for the requested behavior. It is not running-app evidence or a finished component specification.

## Requested design

- Use the actual Release Radar application logo in the sidebar header, replacing the generic Delivery / Local agent workspace identity shown in the mockup. Use the approved existing brand asset; do not invent a replacement logo. The current generated image predates this correction.

- Main content has a persistent top toolbar, separated from the page by a thin divider. Page title/subtitle sit underneath.
- Left toolbar order: sidebar toggle, Back, Forward. All use borderless glyphs. Sidebar toggle moves out of the sidebar. Preserve navigation history semantics.
- Balanced central persistent RDS search field; magnifying glass submits. Save query is available in the toolbar. Submitting changes the main content area to search results while the toolbar stays visible. Existing scope, filters, saved queries and exact-record navigation must remain reachable; the design needs to settle their placement.
- Right toolbar order: Help (question mark enclosed in a circle, no outer button outline or visible Help text), Settings cog, Notifications bell. Icons are borderless. Search, Help, Settings and Notifications leave the sidebar.
- Remaining global sidebar items: Projects, Goals, Needs Review. Existing project navigation remains.
- Move the animated Checking project documentation indicator to a fixed sidebar footer area so its appearance/disappearance does not shift menu items. Remove the redundant Persisted locally footer label. Preserve validation behavior and accessible checking state; reserve stable layout space when needed.
- Overview metric labels Active phase, Current work and Owner attention sit beside their unchanged icons with balanced typography. All three values/statuses are centered below. Preserve glyphs, colors and semantics, including long phase names.
- Documentation activation, shared execution, repository folder access and project evidence move into Manage Project for the selected project, not Settings. Overview focuses on delivery progress and attention.
- Archive and Remove move into Manage Project. Their confirmations, authorization, retained history and recovery behavior remain intact.
- Guided shared-execution setup is a required Phase 6 extension: a user can initiate setup, understand and approve exact repository changes, then see success or actionable recovery. Existing documentation/repository authority is preserved. No automatic adoption or live mutation follows from this review.

## RDS boundary proposed for review

RDS supplies reusable toolbar composition, spacing, appearance, search/input presentation, icon treatment, keyboard/focus/accessibility and compact-width behavior. Each application chooses relevant controls and owns action callbacks, routing, search execution/scope, saved-query persistence, notifications and project-specific state. Verify current pinned RDS capability before proposing new public APIs. Avoid app-local substitutes and avoid coupling the library to Release Radar entities or requiring every app to expose every control.

## Review questions and limits

Feature architect: determine the smallest coherent RDS/consumer design, preserving existing navigation and search contracts. Identify necessary API/state boundaries and concrete gaps; no code changes.

Chief architect: assess cross-application ownership, compatibility, guided-adoption authority and project-management/recovery boundaries. Recommend sequencing only where a dependency requires it. Do not authorize implementation or recovery.

UX reviewer: assess hierarchy, discoverability of moved actions, search/results/save journeys, loading/empty/error/disabled states, keyboard and accessibility, notification visibility and compact widths. Distinguish a necessary design decision from optional polish. The wide mockup alone does not demonstrate those behaviors.

Each reviewer evaluates the original owner outcome and this candidate independently; no reviewer reviews another review. Required findings must name a correctness, accessibility, authority or explicit-requirement risk. Optional advice does not expand scope or block automatically. Reports go to the parent; parent alone updates this proposal and ledger.

## Phase allocation and authorization

Owner explicitly assigned metric alignment to 6F, moving project configuration to 6G, and Archive/Remove/Help/navigation changes to 6H. Persistent search and reusable toolbar are required Phase 6 work. Earlier discussion also called guided setup 6F; preserve that outcome and reconcile the slice naming before implementation rather than silently dropping or renumbering it. This review does not approve code, a library change, branch publication, installation, live data recovery or application-state mutation.

Relevant existing context: [Phase 6 plan](../delivery/plans/2026-09-10-phase6-outcomes-tasks-history.md), [shared execution design](shared-execution-integration-v1-design.md), [architecture boundaries](../architecture/ADR-001-release-radar-boundaries.md), [proportional review policy](../architecture/ADR-007-proportional-delivery-validation.md).
