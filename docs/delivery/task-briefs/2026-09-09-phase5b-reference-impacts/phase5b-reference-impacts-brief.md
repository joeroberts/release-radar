# Phase 5B — Revision-specific references and recorded impacts

## Objective and outcome

Deliver the approved ticket-to-repository requirement/decision links and recorded
impact browsing for placed and unassigned tickets. Keep prose authoritative in its
repository, identify the exact linked content revision, and visibly distinguish
current resolution from retained historical facts. The [owner selections and B–E
sequence](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md#remaining-phase-5-delivery-sequence--2026-09-09)
control scope. No product-choice approval remains outstanding.

## Scope and exclusions

Typed app-owned commands create, revise and retire links; scoped read queries and
the native inspector expose source details, link history and recorded reverse
impacts. Several tickets may reference the same artifact/revision. Native browsing
remains read-only under the approved dashboard design. This is one complete slice,
not a schema-only checkpoint.

Do not implement proposals/apply, successors/carry-forward, phase lifecycle,
execution, automated suggestions, general search, Git/history retrieval, portable
export/import, shared integration, new RDS behavior or consumer/runtime changes.
Do not weaken existing Accepted, planning, registration or filesystem boundaries.

## Dependencies and contract

Start from merged Phase 5A `a8877aac3bcbfb4e32abba48073704a253035583` plus the
committed brief/contract handoff named at dispatch. The read-only chief architect
`01a08799-b7e0-7ab2-ae44-74849d8cd892` assessed that baseline; its bounded findings
are incorporated here. Read [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[managed-documentation design](../../../design/managed-repository-documentation-contract.md)
and [dashboard design](../../../design/agent-driven-delivery-dashboard-design.md).

- Give each logical link a stable identity, project/ticket identity,
  requirement-or-decision kind, repository/artifact identity, optional supplied
  source-local ID and locator, and exact content revision. Preserve prior versions
  and explicit retirement history. Use a ticket-local link-set revision for stale
  mutation checks; future proposals consume it without being implemented now.
- Content revision is SHA-256 of the complete bounded, safely read source bytes,
  computed within authorized reader scope with stability verification. It is not
  the catalog digest, path, timestamp or truncated preview hash. Store identity and
  historical metadata, not a competing content database. A digest neither approves
  prose nor preserves historical bytes. Oversized/unsafe/unstable input fails
  honestly; never hash only a displayed prefix and claim an exact revision.
- Preserve supplied source-local IDs verbatim within repository/artifact scope.
  Headings and line locations are locators, not invented semantic IDs. Source-local
  IDs supplied by an agent are not machine-verified requirement meaning.
- New/revised authoritative links require current registration, exact bound root,
  fresh authorized access, managed-v2 mode, accepted repository/catalog
  version/digest and an active controlling document. Revalidate expected content
  digest and catalog immediately before committing. Persist linked path and
  authority/lifecycle as historical observations; resolve using current accepted
  identity, never an old path or matching filename.
- Report independent facts: changed bytes, accepted path move, explicit accepted
  retirement, supersession/archival/loss of controlling authority, and unavailable
  or unchecked resolution. A missing file is not confirmed retirement. Changed and
  moved can coexist. Invalid/pending catalogs and denied/unsafe/unstable reads do
  not establish unchanged content or current authority. Never retarget to a
  replacement. Preview linked historical content only when safely read bytes match
  that revision; otherwise say its content is unavailable.
- Commands carry expected link-set revision, actor/reason and existing request/
  registration admission. Link changes, history, audit and receipt are atomic.
  Exact replay returns its result; conflicting replay, cross-project identity,
  stale state, expired admission and failures have no partial effects. Retirement
  names the exact link/version and may retain/remove the relationship when its
  source is unavailable; it must not require that source file to exist.
- Accepted ticket link sets are immutable, including backfill. Source changes
  affect read-only resolution, not recorded Accepted history. Placement retains
  link identity and versions. Browsing neither mutates delivery state nor grants
  folder, catalog, execution or content approval.

## Integration, recovery and future consumers

Reuse `DocumentationRootContext`, `DocumentationCatalogContext`,
`ManagedDocumentResolver`, `RepositoryDocumentReader.read/verifyStable` and the
bounded display-only protections in `EvidencePreviewReader`. Existing evidence
uniqueness cannot represent these relationships: add ticket-link records without
changing `EvidenceLocator` semantics or relaxing its existing constraints.
Use the established command/receipt and separate read-query dispatchers, transport
and packaged tool schemas; no generic filesystem or SQL capability.

Extend ticket detail/projections and existing typed navigation rather than create
another graph authority. From a source, show project-scoped recorded ticket links,
kind, linked revision, phase or Not placed, and current versus historical relation;
group source-local IDs/revisions where useful. Label results **Recorded impacts**,
not completeness or coverage. Keep ticket dependencies separately labelled. Back/
Forward retains source/link context, ticket, Plan/board scope, filter and actual
focus. Missing targets recover without substituting an entity or broadening scope.
Bounds and incomplete readback must be explicit. Withdraw late source/preview
results after project, registration, root or selected-reference changes.

Add migration after schema 19 with empty links; infer nothing from evidence or
prose. Include actual new records in relaunch, archive/restore and full backup.
Removal retains link/version/retirement facts under historical registration before
operational deletion; re-add never reconnects by folder/name. Backup restore retains
facts while rotating admission and requiring renewed folder access. Repository
bytes remain excluded from full app backup. Future complete portable packages must
carry link/version/retirement identities, source provenance and required documents
without source capabilities. Preserve v1 semantics; exporter/importer stays deferred.

## Acceptance and direct verification

1. Through the real typed interface, link two tickets (one unassigned) to the same
   authoritative source/revision, revise and retire one link, and read exact history
   and reverse impacts. Projections/counts agree; link changes do not execute work.
2. Mutable bytes with unchanged catalog digest report changed. Accepted move,
   retirement, supersession and loss of authority remain distinct from missing,
   pending, denied, unsafe and unstable sources. Historical labels never display
   different current bytes as their linked revision. Locators do not invent IDs.
3. Exercise binding/root/repository mismatch, traversal, symlink/nonregular input,
   read races, size bounds, stale catalog/content/link-set revisions, registration
   invalidation, conflicting/exact replay and transaction rollback. Verify zero
   unintended records, audits or mutations. Accepted link mutations reject.
4. Test migration without inferred links, first placement, archive/restore,
   retained removal/re-add separation and full backup recovery of complete records.
   Preserve prior ticket/goals/tasks/evidence/history and public wire behavior.
5. In the isolated native host, exercise placed and unassigned Details → source →
   Recorded impacts → ticket → Back/Forward, including unavailable/historical
   sources, empty/error/incomplete states, actual keyboard/accessibility focus,
   readable wide/compact scrolling and inert untrusted previews. Compare relevant
   layout/relationship language with [Phase Board](../../../design/mockups/phase_board.png)
   and [Dependencies](../../../design/mockups/dependencies.png); document necessary
   deviations in dashboard design. No unselected historical proposal is adopted.

Use test-first repository-native XCTest at the changed policy/reader/store,
command/query, recovery and native boundaries. Run broader suites only for shared
schema or admission regressions. Before launches verify isolated XCTest host and
AppLaunchConfiguration; use synthetic fixtures and sanitized `env -i` with known
required local signing/package variables. No normal owner app or credentials.
Use canonical `/private/tmp` fixture roots for no-symlink recovery tests. Preserve
raw bundles outside rolling Xcode logs until consumed. The external controller
owns interaction markers; the sandboxed host only reads them. Serialize all hosts.

## Assignment, risk-triggered review and endpoint

Orchestrator `01a086bd-7970-70f0-80e8-8c044ee8ef4a` owns ledger/catalog/generated
indexes and integration in worktree `165b`, branch `codex/phase5-orchestrator`.
One fresh delivery task owns source/tests, this brief, affected ADR/design detail
and canonical evidence. Start Sol High because safe content resolution, persisted
history, command admission, recovery and native navigation cross components;
escalation ceiling Astra High for a named unresolved problem. Never Ultra or
unapproved xhigh/max. Exact committed baseline/task identity is supplied at dispatch.

One fresh independent Astra High reviewer covers code/public contracts,
content authority/security, recovery and native UX/QA; these risks need independent
coverage, not separate review layers. Only Required defects block; no review of a
review, external scanner or verification infrastructure. Runtime settings are
reported only where actually exposed.

Complete direct checks, correction review and scoped commit/push. The orchestrator
integrates metadata and creates the combined PR to `codex/release-radar-mvp`.
Every later merge needs separate owner approval. No installation, app-state/binding/
catalog acceptance, direct SQLite edits, owner content reads, credentials,
notifications, external scan, entitlements, other repository, packaging or cleanup.
Source delivery does not claim application synchronization. Report temporary paths
and stopped-process status; archive peers when their outcomes are preserved.
