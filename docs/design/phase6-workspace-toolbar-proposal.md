# Phase 6 extension: project management and persistent toolbar

Status: initial feature-architecture, chief-architecture and UX reviews concluded; owner selections recorded below. On September 12 the owner authorized the bounded RDS toolbar consumer adoption described in the delivery brief. That authorization does not extend to the stopped Overview metric task, Manage Project relocation, guided setup, packaging or installation. This proposal remains separate from the 0.1.11 release and the Add Project styling correction.

## Owner outcome

Reduce Overview/sidebar clutter, make shared navigation and search persistent, and evaluate an RDS-owned toolbar reusable across Rekon applications. Preserve existing navigation, search, saved-query, lifecycle, authorization and data behavior unless the explicit interaction changes below require a change.

[Latest owner-directed static mockup](mockups/phase6-persistent-workspace-toolbar-proposal.png). This generated image communicates layout only; text below is authoritative for the requested behavior. It is not running-app evidence or a finished component specification.

The owner accepted the smaller, borderless-logo revision as sufficient visual reference. All three initial reviews concluded and supplied practical options. The owner subsequently selected the search, compact-layout, management-loading and guided-setup recommendations below. The compact mockup's corrected colors and inset divider were also accepted as visual reference.

## Owner selections — September 12

- **Search:** keep query entry and Save query in the persistent toolbar; filters and saved-query management belong on the results page. Typing does not navigate. Submission opens results; Back restores the source context. Implement this with the recommended app-owned draft and existing complete search/history definition, preserving scope and exact-record navigation.
- **Save query correction:** at both wide and compact widths, represent Save query with a borderless bookmark icon immediately adjacent to the central search field. Keep Help, Settings and Notifications directly visible in their approved right-hand order. Retain the Save query accessible name/help, keyboard navigation, naming popover and notification state.
- **Manage Project:** open immediately with the selected project's identity, load sections independently, and show applicable retry/recovery in place if a section fails. Preserve existing authorization and archived/removed-record access.
- **Guided setup:** initiate a Codex task that prepares the exact repository change for owner approval. Apply only the approved change and report verified completion or actionable recovery; task dispatch itself is not successful setup.

These are design selections. The merged RDS toolbar API and its Release Radar consumer adoption are now authorized through the bounded delivery brief. The proposed guided-setup slice label remains a recommendation, and the explicitly stopped metric implementation remains stopped.

## Requested design

- Use the Release Radar application logo in the sidebar header, replacing the generic Delivery / Local agent workspace identity. The owner requests a smaller mark centered horizontally above the menu, seamless against the sidebar with no border or enclosing tile. Preserve the existing orbit/tile identity; this sidebar presentation does not replace the production macOS AppIcon. The generated mockup illustrates the direction; exact centering belongs in the layout specification, not inferred raster coordinates.

- Main content has a persistent top toolbar, separated from the page by a thin divider inset at both ends, connecting to neither the sidebar boundary nor the right window edge. Page title/subtitle sit underneath. Preserve the installed application's near-black navy surfaces and restrained blue borders; the brighter blue/cyan surface treatment in earlier generated mockups is not approved.
- Left toolbar order: sidebar toggle, Back, Forward. All use borderless glyphs. Sidebar toggle moves out of the sidebar. Preserve navigation history semantics.
- Balanced central persistent RDS search field; magnifying glass submits. A bookmark Save query icon is grouped immediately after the field at every supported width. Submitting changes the main content area to search results while the toolbar stays visible. The results page retains scope, filters, saved-query management and exact-record navigation.
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

## Reviewer options and retained alternatives

All three reviewers supplied these options. The owner selections above control where chosen; other recommendations remain proposed. None constitutes implementation approval.

| Decision | Recommended option | Alternative and tradeoff |
| --- | --- | --- |
| Persistent search | Keep an app-owned toolbar draft; commit on submission, capture the source route, and preserve full search history/focus on Back/Forward. | Bind directly to working search state; fewer properties but conditional history handling risks regressions. |
| Save and reopen queries | Toolbar Save opens a naming popover; the Search destination retains query management, scope, record types and sort. Saving preserves the complete definition without executing. | Put query management in a toolbar menu; faster global retrieval but more compact-toolbar complexity. |
| RDS contract | Add a generic toolbar shell, borderless icon style and backward-compatible search-submit support. Apps own routes, query state, identities, authority and notifications. | Styles alone leave every app to duplicate responsive toolbar composition. |
| Compact toolbar | Keep Help, Settings and Notifications visible; use a bookmark glyph for Save query and an icon sidebar. | Keep Save query text and place Help/Settings in More; trades direct access for the visible label. |
| Guided setup | A user-initiated Codex task prepares the exact repository patch for approval, applies the authorized change and reports verified results. Binding/catalog acceptance remain separate when applicable. | An app-applied patch requires a new write/interruption/recovery contract. |
| Manage Project failure | Open immediately with project identity; load sections independently and retain applicable retry/recovery. | Settings-first opening plus a separate recovery entry splits management across destinations. |
| Sequence labels | Preserve metrics 6F, management 6G and toolbar/lifecycle 6H; propose guided setup as 6I. | Earlier guided-setup 6F label conflicts with the owner's metric assignment; owner confirmation is pending. |

[Compact-view reference](mockups/phase6-compact-workspace-toolbar-proposal.png) illustrates the owner-selected compact option. It is a static approximation, not proof of minimum-width layout. UX proposed approximately 760 × 560 with a 96-point sidebar; exact fit must be verified in implementation. The icon-only sidebar applies to compact mode; the wide layout retains labels.

Search options beneath the Search page title can expose scope, record types, sort and saved queries in a popover. The toolbar Save action opens a name field with Save/Cancel. Keyboard order follows visible controls; Enter and magnifier submit identically. Preserve existing Back/Forward shortcuts and restored focus, accessible names, disabled-state explanations, notification indicators and explicit loading/error/partial/unsupported-scope recovery. Search configuration must remain reachable before submission; final entry-point detail remains to settle.

The owner accepted the wide logo treatment as visual reference. The actual sidebar asset must preserve the approved orbit identity while meeting the requested borderless appearance; reviewers' earlier suggestion to display the complete tiled AppIcon does not override that later owner direction.

## Allocation remains proposed

Owner explicitly assigned metric alignment to 6F, moving project configuration to 6G, and Archive/Remove/Help/navigation changes to 6H. Persistent search and reusable toolbar are required Phase 6 work. Earlier discussion also called guided setup 6F; preserve that outcome and reconcile the slice naming before implementation rather than silently dropping or renumbering it. This review does not approve code, a library change, branch publication, installation, live data recovery or application-state mutation.

Relevant existing context: [Phase 6 plan](../delivery/plans/2026-09-10-phase6-outcomes-tasks-history.md), [shared execution design](shared-execution-integration-v1-design.md), [architecture boundaries](../architecture/ADR-001-release-radar-boundaries.md), [proportional review policy](../architecture/ADR-007-proportional-delivery-validation.md).
