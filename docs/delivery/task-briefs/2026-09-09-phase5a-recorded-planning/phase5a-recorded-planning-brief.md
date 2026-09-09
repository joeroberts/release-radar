# Phase 5A — Recorded planning and identity-preserving placement

## Objective and outcome

Deliver the owner-selected Overview → Project Plan → phase/all-phase board journey,
with unassigned tickets that can hold planning content and become executable only
through identity-preserving placement into Backlog. Keep phase lifecycle, viewing
context and plan readiness separate; the approved
concurrent In-delivery capability remains a subsequent Phase 5 lifecycle slice.

The owner authorized bounded Phase 5 implementation on 2026-09-09. The exact
[selection record](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md#phase-5-owner-selections-and-implementation-authorization--2026-09-09)
controls scope. This brief does not approve the entire historical UX proposal.

## Scope and exclusions

- Retain Overview landing. Add Project Plan showing every recorded phase,
  phase-owned Delivery Goals/readiness, and separately identified unassigned
  tickets. Recorded counts must agree; unresolved intake is not recorded work.
- Extend the existing board to explicit phase/all-phase scopes, preserving five
  lanes, phase labels on every ticket, one appearance per ticket, goal filters,
  Details, project-wide Dependencies and D6 Back/Forward/focus restoration.
  Unassigned work appears in Project Plan, not a fabricated phase or sixth lane.
- Add authoritative unassigned placement through existing typed app-owned
  mutation conventions. Preserve ticket ID, details, task definitions,
  dependencies, evidence and history on placement; enter Backlog atomically.
  Reject execution, task completion, review/acceptance transitions before placement.
- Preserve current goal cardinality, Ready/start gates, immutable Accepted history
  and started-assignment protections. Goal obligations never silently disappear.
- First placement only: do not add move/unplace of existing assigned work. Existing
  goal-coverage behavior is not evidence that carry-forward is implemented.
- Show existing phases/readiness without new lifecycle transitions. Concurrent
  In delivery and the full lifecycle policy are approved subsequent scope in the
  selection record. No lifecycle/order inference in this slice.

Revision-specific repository requirement/decision links remain authorized Phase 5
follow-on work. Proposal/approval/atomic apply and withdrawal/replacement/split
coverage semantics were subsequently approved and remain follow-on scope excluded
here. Do not introduce those
models speculatively. No Phase 6+, shared execution integration, exporter/importer,
runtime/hooks/configuration, new RDS changes or unrelated refactoring.

## Dependencies, architecture and future consumers

Start from merged Phase 4 `8930f9643ca1f46e7681ce9b838ce9b0f5b024fc` plus the
committed first-slice scope/contract amendments named in the dispatch. The read-only chief
architecture assessment confirmed first placement as the safe initial boundary;
the subsequently approved lifecycle and obligation-transfer implementation belong
to later slices. Read
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-003](../../../architecture/ADR-003-active-phase-selection.md),
[ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
[dashboard design](../../../design/agent-driven-delivery-dashboard-design.md) and
[Delivery Goals readiness](../../../design/2026-08-29-delivery-goals-roadmap-readiness-design.md).
Preserve their enforcement and authority boundaries except explicit amendments.

Use one exhaustive placement state (unassigned or placed phase/lane), backed by
consistent persistence; never a second ticket table. The project ticket/detail
projection must include unassigned records: existing phase loops and inner joins
currently exclude them. Use explicit board scope rather than overloading nil phase.

Use DeliveryModels/store migrations/planning enforcement and existing command,
transport/MCP, projection, AppModel/AppRoute/NavigationHistory, board/inspector
boundaries. Discover exact current files with repository-native tools. Do not build
another execution or change-control system. One delivery writer owns this complete
integration. Future references and successors consume these same durable identities;
future views consume the same navigation boundary. No future cases are needed now.

Migration must preserve existing IDs, phases, lanes, goals, tasks/completions,
active pointer, audit and dependency history. Legacy lifecycle stays unknown.
New records participate in current archive/restore, removed-history and full-backup
recovery. Describe complete future portable representation; do not silently change
v1, omit unsupported records or implement the deferred exporter/importer.

## Acceptance criteria and material risks

1. Create an unassigned ticket with task definitions, dependencies and evidence;
   read it in Project Plan and Details. It has no execution lane or executable
   actions. App/store enforcement rejects execution even if UI or MCP is bypassed.
2. Place it in a same-project phase with one exact typed audited request. Identity,
   content and relationships survive; it appears exactly once in Backlog. Relevant
   structural revisions/readiness and existing goal-assignment policy are respected.
   Cross-project, stale and conflicting requests change nothing. Exact replay
   returns the original result without duplicate audit.
3. Phase/readiness presentation never implies a new lifecycle state or changes
   active context. No empty phase is silently Completed. Distinguish tickets with
   No phase from the existing No Delivery Goal board filter.
4. Overview stays the landing page. Project Plan exposes all recorded phases,
   their Delivery Goals and unassigned work, with truthful zero/loading/unavailable
   states. Folder/runtime failure does not fabricate absent app-owned records.
5. Phase and all-phase boards agree with underlying membership and counts. Labels
   retain phase identity, scoped filters never silently broaden, and unavailable
   targets recover honestly. Project switch/archive/removal/re-add reject stale
   publication. Unassigned dependency nodes remain identifiable as Unassigned.
6. Compact and wide native journeys retain keyboard access, readable content,
   scrollability, useful focus and exact Back/Forward context through Plan, board,
   Details and Dependencies. Browsing issues no delivery mutations.
7. Migration, recovery, archive/restore and retained history preserve actual new
   records. Existing placed-ticket wire behavior remains compatible; no new field
   omission silently converts a placed ticket to unassigned.

## Test strategy and risk-triggered reviews

Use test-first behavior changes and focused repository-native XCTest across
migration/store policy, exact mutation/replay/rollback, command boundary,
projections/counts and actual navigation model integration. Cover the negative
execution paths, assignment protection, cross-project placement, old and new record recovery and stale publication. Run only relevant
broader suites where shared ticket-model changes justify them.

Before any launch inspect the existing isolated XCTest host/AppLaunchConfiguration
and runner. Use synthetic stores, suppressed external services and `env -i` with
only known required local signing/package variables. Never inspect owner credentials
or launch the normal owner app. Use isolated derived data and retain raw result
bundles until consumed. Native compact/wide keyboard/accessibility checks compare
against [Phase Board](../../../design/mockups/phase_board.png); the
[proposed Work Board](../../../design/mockups/work_board.png) and
[historical Plan proposal](../../../design/release-radar-project-planning-ux-proposal.md)
are partial visual references, not wholesale accepted contracts. Use supplied RDS
and record necessary deviations in the existing dashboard design.

The chief architect provides bounded initial contract/sequencing assessment. One
fresh independent Sol High reviewer covers code, schema/recovery/authority risks
and native UX/QA. Only Required defects block. No duplicated approvals, external
security scans, review-of-review or new validation infrastructure.

## Assignment and endpoint

Orchestrator `01a086bd-7970-70f0-80e8-8c044ee8ef4a` owns progress/catalog/generated
indexes in worktree `165b`, branch `codex/phase5-orchestrator`. Delivery is a fresh
Terra Medium task/worktree, with named-problem escalation to Sol High and ceiling
Astra High. No xhigh/max or Ultra. Exact committed baseline and task identity are
provided at dispatch; runtime settings are reported only if actually exposed.
Delivery owns necessary source/tests, this brief, affected product contract detail
and canonical verification evidence. Report any new artifacts for catalog integration.

Complete direct checks, independent review and scoped commits, push branch and
PR targeting `codex/release-radar-mvp`. Every merge needs separate owner approval.
No installation, owner-project/app-state mutation, direct SQLite writes, binding,
catalog acceptance, notifications, external scans, credentials, entitlements,
consumer repositories, publication, packaging or cleanup. Source delivery does not
claim app synchronization. Report retained temporary paths and live processes;
do not delete outputs. Archive bounded peers only when their useful results are
canonical and their work/processes have stopped.
