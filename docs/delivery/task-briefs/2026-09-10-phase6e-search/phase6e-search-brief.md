# Phase 6E: workspace search, saved views and Help

Status: controlling refinement of the authorized Phase 6 sequence. Implementation
waits for reviewed 6D integration; dispatch sets the exact committed baseline
containing that dependency and this brief.

## Objective and boundaries

Complete P19/D6 and the [Phase 6 plan](../../plans/2026-09-10-phase6-outcomes-tasks-history.md):
authorized known-record search across projects, both goal domains, tickets,
decision references and History; persistent scope/filter/sort and saved queries;
exact typed restoration; contextual and searchable Help for selected setup,
recovery, planning and acceptance journeys. Preserve all selected domains and
recoverable non-happy paths rather than delivering only a search-shaped screen.

No full document-content indexing, external search/provider/network access,
portability-v1 change, Phase 7 work, live observer, task engine, automatic delivery
mutation, consumer adoption, installation, owner-state operation, publication,
configuration/guardrail change or cleanup. Searching or reading Help grants no
authority and dispatches no command.

## Dependencies and implementation choices

Consume reviewed 6A–6D identities and contracts. The reviewed 6D endpoint is
`1d69858f98f55af1ef504f4a43df1c601db879b9` on `codex/phase6d-reviewed`; it also
includes merged PR #45 and its required Goals corrections. Follow the
[whole-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md)
and [ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md).
Read-only chief consultation `01a08dab-7ac7-7031-96c8-d658e29bfe1e` (Astra High)
found no blocking owner choice. Its selected bounded recommendations follow:

- Add one workspace Search destination with ID/name/text search, explicit project
  scope, entity/domain filters, deterministic sort, named saved queries and
  relaunch restoration. Distinguish all currently authorized projects from an
  explicit set of registrations; recovery never silently changes one into the
  other. Preserve restrictive intent for unsupported filters/versions.
- Use bounded app-owned persisted-record projections, not only visible dashboard
  cards, which omit archived projects and retired tickets. Search already recorded
  decision-reference metadata; do not invoke repository file resolution per
  keystroke. Explicit source opening reuses the existing authorized resolver.
  Do not add a general indexing engine when bounded existing queries suffice.
- Results and navigation carry exact project/registration and domain identities:
  Delivery phase/goal, Execution thread/goal, ticket, reference ticket/link/version
  and repository/artifact, History source/source ID and historical registration.
  Keep byte-exact identity independent of normalized search text. Reuse AppRoute,
  NavigationHistoryEntry and AppModel boundaries; Back/Forward preserves query,
  selected result, scroll and focus without changing active phase.
- Store a small versioned saved-query/preference payload in the existing app-owned
  SQLite boundary so full backup includes it. Persist preferences, not bookmarks,
  cached results or the session Back/Forward stack. Use the next additive schema
  only if needed after confirming the actual baseline; legacy stores gain no
  fabricated queries. Unsupported payloads remain visible and recoverable without
  executing them or dropping filters. No second database or sidecar preference
  backup boundary.
- Full-backup restore rotates registrations and leaves bookmarks stale. Preserve
  old saved scope honestly; require fresh authorization and explicit scope
  reselection/resaving. Do not reconnect by name/path or silently replace old
  registration IDs. Preserve saved views across tracking reset as global
  preferences. Keep current narrowly defined preference-reset semantics unless a
  necessary deliberate extension also updates its preview and documentation.
- Complete Help using shared local topic content and a searchable entry point,
  reusing lifecycle, Goals, History, evidence and adoption Help. Cover setup and
  documentation handoff, health/recovery, active versus viewed phase, planning
  and unplaced work, task adoption, proposal approval versus application,
  readiness versus acceptance, and saved-query recovery. Contextual links open
  actual existing controls. Reading Help or copying a request never sends it.

Existing seams include DashboardProjection, TicketReferenceQuery,
NavigationHistory, AppModel, ApplicationBackup and ApplicationRecovery. Verify
current source before changes; no CodeGraph indexing. Withdrawn tickets remain
discoverable with successor context; archived targets open read-only recovery;
removed targets retain removal/historical-registration identity and never open a
re-added replacement. Missing reference versions remain missing, never replaced
with current bytes. Distinguish loading, failed, incomplete and complete zero
results, identify omitted project scope and reject stale asynchronous results.

## Direct verification and design

Use test-first focused repository XCTest checks for all record domains, colliding
IDs, retired/archived/removed targets, denied or changing authorization, partial
reads and complete zero, exact reference versions, unsupported filters/versions,
saved-query migration/relaunch and full-backup authority rotation. Exercise actual
Search → detail → Back/Forward restoration without active-phase mutation, plus
tracking reset and selected preference-reset semantics. Confirm no implicit file
reads, provider access or delivery mutations. Do not substitute only compilation
or string assertions for these changed behaviors.

Inspect relevant History, Goals wide/compact/data-state and Settings mockups under
`docs/design/mockups/` before UI work. There is no dedicated Search/Help mockup;
reuse their scope headers, provenance callouts, accessible list/detail layout and
compact stacking, documenting the necessary new surface in the existing design
document. Do not adopt out-of-scope suggestions/attention from Goals data states.
Verify actual native wide/compact Search, saved-view controls, Help and result
navigation with keyboard/accessibility and recoverable errors. One appropriate
independent reviewer covers architecture/security and native UX/QA. Successful
direct checks and reviews are terminal unless a concrete defect needs correction.

Build/test reservation is explicit and serialized. Submit concrete sanitized
unsigned arm64 offline serial commands with fresh scratch/output and pinned cache
before any launch. Inspect inert synthetic XCTest startup. Native sessions use a
fresh copied xctestrun and unique token, exact PID/window verification, and CUA
stop before host termination. Never call CUA after host exit; it may launch a
plain product. No plain/signed/direct-xctest fallback, owner SQLite, services,
credentials or cleanup. Read-only result/attachment inspection is authorized.

## Assignment and endpoint

Fresh delivery owner: Sol High, ceiling Astra High, no subagents. Sol is selected
for the named cross-component identity, saved-query persistence and recovery
ambiguity; ordinary presentation alone would use Terra Medium. Dispatch sets
actual model/effort and exact committed baseline containing reviewed 6D.
Writer owns complete source/tests, affected ADR/design docs and canonical evidence
`docs/delivery/evidence/2026-09-10-phase6e-search.md` plus necessary screenshots.
Root owns progress/catalog/index metadata and integration; one product writer.
Never modify governing instructions or installed configuration.

One fresh independent Astra High reviewer covers public contracts, persistence,
authorization/known owner content, recovery and native UX/QA. Only Required
findings block; no role matrix or review-of-review. Preserve original complete
scope while correcting bounded defects. Escalation requires a named problem;
never Ultra.

Deliver working behavior, relevant documentation, direct checks, independent
review and scoped local commits. Report actual verified SHAs, files/checks,
remaining risks, retained temporary outputs and stopped-process handback. No
push/PR/merge, package publication, installation, owner-state/catalog acceptance,
consumer adoption, notifications or cleanup is authorized by this brief.
