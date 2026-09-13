# Phase 6B: workspace Delivery and Execution Goals

Status: completed; historical and non-authoritative. Delivery is integrated into
`main`; current authorization lives in [progress](../../progress.md#current-authorization).

Original assignment status (historical): controlling refinement of the independently reviewed Phase 6 sequence;
local implementation authorized. Dispatch names the committed handoff revision.

## Objective and scope

Deliver the complete Workspace Goals slice of the
[Phase 6 plan](../../plans/2026-09-10-phase6-outcomes-tasks-history.md): a workspace
Goals destination with clearly separate Delivery and Execution views, useful
cross-project discovery, exact associated-work navigation and contextual Help.

Delivery aggregates existing phase-owned outcomes. Show project/phase identity,
criteria, recorded formal state, membership and carried-obligation coverage,
structural readiness and owner acceptance context using existing authoritative
policies. Preserve discovery of terminal goals and work with no Delivery Goal;
no goal is inferred for unassigned or legacy work. Superseded/dropped scope is
not delivered credit. Existing owner acceptance authority remains unchanged.

Execution defaults to All Projects and All goals, including completed and
unlinked persisted observations. Show exact link identity separately from source
provenance, observation time/freshness and availability. Persisted historical data
is useful without pretending a live observer exists. An unlinked observation is
not an error or new attention rule. Derived execution summaries never become
formal lanes or Delivery Goal states.

Both views support useful project/state filters, exact selected details, distinct
empty/filter-zero/incomplete/failed/unavailable states, and associated work across
stored phases with phase identity. A goal opens the existing all-phase board in
its explicit typed goal filter; Clear filter remains on that board. Back/Forward
restores the original Goals domain, project/filter scope, selection, actual scroll
and focus. Browsing does not change active phase or formal state. Missing or
replaced registrations explain recovery rather than redirecting silently.

Add contextual Goals Help to the delivered Help surface, explaining the two
domains, readiness versus acceptance, stale/unavailable execution observations,
filters and navigation/recovery. Do not advertise future live visibility.

No cross-phase Delivery Goal schema, 1:N execution links, suggestions, unlinked
attention, live observer, search/saved views, adoption, evidence revisions, new
service, portability, owner-app operation or unrelated refactor is included.

## Dependencies and design

The baseline contains completed reviewed 6A at `95cad491f096c83d1bfec9a5decb60b270f454a4`;
this brief's committed handoff follows it. Read the Phase 6 plan and relevant
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and
[product design](../../../design/agent-driven-delivery-dashboard-design.md).

Inspect `docs/design/mockups/goals.png`: its list/detail, source chips and
cross-project selectors are the Execution reference, not a replacement for formal
Delivery Goals. Add explicit domain separation using current RDS components and
formal phase-goal patterns. Preserve the existing Phase Board name/five lanes,
not historical mockup lane names. Compare the running inert test app at wide and
compact widths; document necessary deviations concisely.

Reuse current scoped store read APIs, goal/coverage projections, AppRoute,
NavigationHistory and AppModel boundaries. Inspect source before modifying;
CodeGraph is a navigation aid only (no new indexing). Implement bounded queries
only where this consumer needs them. Preserve registration-scoped identities and
existing 1:1 links. Session navigation stays session-only. Goal data already uses
existing persistence; do not add persistence merely for hypothetical consumers.
Any genuinely necessary additive record must survive existing full-backup/removal
recovery and be disclosed before implementation. Phase 6E will consume these
stable identities for search; Phase 7 portability remains separately scoped.

## Direct checks and acceptance

Use repository-native test-first focused XCTest at the lowest useful layer:

1. Delivery and Execution cannot be confused or promote one another's authority;
   coverage/readiness/acceptance come from current policy, including carried,
   superseded, dropped and terminal outcomes.
2. Default discovery includes completed/unlinked observations and terminal goals;
   colliding IDs across projects, registrations, phases or runtime threads remain
   distinct. Filtering does not erase unavailable or partial-source context.
3. Associated work is project-wide with exact goal and phase identity. Goal-to-board
   and Clear filter preserve board scope; Back/Forward restores domain, filters,
   selected detail, actual viewport and keyboard/AX focus without active-phase,
   lane, lifecycle, acceptance or attention mutation.
4. Stale/removed/replaced target recovery is explicit and accessible. Existing
   persistence/reload maintains authoritative goal and link facts; reads do not
   invoke external services or mutate owner state.
5. Native wide/compact checks exercise both domains, filters, nonactive-phase
   associated work, actual return viewport/focus, empty/error recovery and Help.
   Compare screenshots against the approved reference and current formal patterns.

Inspect the inert synthetic XCTest startup before any build/launch. Obtain a
serialized reservation from the orchestrator with the concrete command first.
Every Xcode invocation must use explicit sanitized `env -i` identity/path/temp/
Developer settings and `CODE_SIGNING_ALLOWED=NO`, unique results and markers,
serial `ReleaseRadar` scheme on macOS. Use a clean pinned offline dependency
cache and approved fresh products; never the contaminated writer scratch Build.
Pass native session variables through a freshly generated copied xctestrun.
Verify actual host PID and unique window before CUA. No plain app, signed fallback,
direct xctest or linker/symlink workaround. Stop and report startup/dependency
failure without changing the method. No owner data, credentials or notifications.

## Assignment, review and endpoint

Fresh delivery owner: Terra Medium, escalation ceiling Astra High. This slice
primarily composes existing domain policies and UI/navigation; request bounded
Sol High analysis if those boundaries reveal substantial ambiguity. Actual task
settings and exact baseline are supplied at dispatch. No subagents are needed.
Writer owns source/tests, affected design/ADR text and canonical Goals evidence
under `docs/delivery/evidence/2026-09-10-phase6b-goals.md` plus necessary screenshots.
Orchestrator exclusively owns progress/catalog/indexes and new artifact metadata.

One fresh independent Sol High reviewer covers the candidate's domain/identity,
read-only authority and native UX/QA boundaries. Only Required findings block;
corrections retain the same reviewer and repeat affected checks only. No extra
planning review or review-of-review is required for this refinement of the already
reviewed sequence. Scope changes or genuinely new persistence/public contracts
return to the orchestrator before implementation.

Deliver one coherent source slice with affected docs, focused checks, independent
review and scoped local commits. Return exact commits, behavior, results, retained
temporary paths and stopped-process confirmation. No push/PR, remote merge,
installation, owner-state/catalog acceptance, external mutation, instruction/config
change or cleanup is authorized. Publication is separately coordinated; source
completion does not claim installation or managed-current application state.
