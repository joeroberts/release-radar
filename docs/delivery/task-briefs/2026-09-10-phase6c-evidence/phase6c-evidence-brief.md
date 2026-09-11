# Phase 6C: revision-bound delivery evidence

Status: controlling refinement of the approved Phase 6 sequence; local delivery
authorized. Dispatch supplies the exact committed baseline containing this brief.

## Objective and boundaries

Deliver the complete 6C outcome in the
[Phase 6 plan](../../plans/2026-09-10-phase6-outcomes-tasks-history.md): a ticket
evidence panel, typed recording/readback and contextual Help connecting repository,
commit, PR, check, document, build and installed facts to explicit revision
applicability. Preserve manual/local evidence and unknown legacy provenance.
Expected evidence, observations, applicability, source availability, result and
owner acceptance remain separate. A prior passing revision cannot silently satisfy
a newer commit, merge result, dirty checkout or installed binary.

The source baseline follows reviewed 6B endpoint
`024a3b5d48517129e3309327ed9fed15cb3c6a38`. Chief architecture consultation
`01a08d16-cc19-7143-b158-f175f88ef1a6` (Astra High) assessed the same product source
at `3eb5e47`, found no blocking owner choice and recommended the bounded design
below. It is consultation, not independent review of the implementation.

No live observer, implicit network/source-control access, test execution, Git
mutation, publication, acceptance, manual delivery editor, new service, Phase 7
portability, owner-state operation or unrelated refactor is included. Recorded
external facts are labelled as observations, not independent verification by the
app. Reading or refreshing never grants an action's authority.

## Implementation and dependencies

Use the [whole-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
P17/D13, [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and
[product design](../../../design/agent-driven-delivery-dashboard-design.md).
Preserve accepted authority and compatibility. The following are selected bounded
implementation choices, not permission to create a generic evidence engine:

- Keep `EvidenceLocator` as file path or managed artifact identity. Add immutable
  ticket observations beside locators; attachment is optional. Record an explicit
  ticket target and expectations with optimistic revision. Label it **Recorded
  target**, never live HEAD. Unspecified categories are Not specified, not missing
  requirements. Changing targets preserves observations; corrections append with
  explicit supersession rather than rewriting history.
- Separate repository identity from revision, clean/dirty/unknown state and exact
  dirty snapshot identity. Use accepted repository/root identity for managed work;
  preserve explicit registration/root context and unknown provenance for legacy
  work. Paths, matching HEAD or version labels alone do not prove identity.
- Use typed facts for repository/commit, PR head/merge/state, check scope/outcome,
  document artifact/content revision, build artifact/source and installation
  identity/context. Preserve claimed source, observation time and app recording
  time. Do not add checksums to mutable plans or catalog metadata.
- A bounded Core applicability evaluator serves this panel and future 6D adoption.
  Exact identity and scope determine applicability; stale, missing, unavailable
  and unknown explain different conditions. Applicable failed checks remain
  failed. Unknown installation identity cannot imply that a tested build is
  installed. Timestamp recency cannot substitute for identity.
- Extend existing typed command/query transports with target revision and append
  observation operations plus complete scoped readback. Reuse exact registration,
  root authorization, canonical-body replay and transactional audit/receipt
  machinery. Same request with changed body rejects; authorized exact replay
  returns the original result. Recheck scope inside the transaction. Recording
  never changes lanes, task completion or acceptance; preserve existing lifecycle
  guards, including completed-phase restrictions.
- Reuse bounded stable document reads without imposing controlling-document
  eligibility on historical evidence. Managed reads retain the accepted
  repository/root/catalog tuple. Current readability is not stored approval and
  does not become part of mutation replay identity.

Current navigation points are `ManagedEvidenceModels`, `AgentCommandDispatcher`,
`AgentQueryDispatcher`, `TicketReferenceCommandDispatcher`, `DeliveryStore`,
`StoreMigrations`, `ProjectLifecycle`, `ApplicationRecovery`, `TicketDetailView`
and `EvidenceDetailView`. Verify current source before changes; no CodeGraph
indexing. Schema was 24 at consultation; use the next additive migration after
checking the assigned baseline. Add no fabricated migration observations.

Extend existing removal retention, restored-registration retention and
`reconcileNewerFacts`, not only live tables. Preserve observation/target history,
original registration and audit provenance when newer facts survive restoration
of an older backup. Displaced records stay historical; restored observations do
not prove current readability or installation. Existing backup format, rollback,
authority rotation, stale bookmarks and notification suppression remain intact.
Preserve portable-v1 behavior and truthful legacy imports. Future RM5/RM6 must
represent these records or reject unsupported content; no exporter or unused
portability guard belongs here. Wire new audits into event-time 6A snapshots.

## UI and direct verification

Inspect `docs/design/mockups/work_board.png`, `work_board_compact.png` and the
existing ticket inspector. Extend its Evidence section and existing Help surface
using current RDS components. Show recorded target, observation source/time,
applicability reasons, document availability and distinct build/installation
facts. Preserve readable legacy evidence. No separate design framework or owner
delivery editor. Help explains recorded versus live identity and what Refresh
can actually read. Record necessary deviations in the existing design document.

Use test-first repository-native focused checks covering:

1. Correct/wrong repository, older commit or merge, exact scope, dirty snapshots,
   failed/skipped checks, unknown installation and unspecified expectations.
2. Additive migration and legacy import without invented revision provenance.
3. Exact replay, changed-body rejection, stale registration, lifecycle guards and
   atomic rollback without orphan audit or receipt.
4. Document byte changes despite unchanged catalog acceptance, unsafe/unavailable
   sources and refresh without execution, mutation or implicit network access.
5. Removal and older-backup recovery, newer/displaced history and rejection of
   requests authorized before recovery. Full-backup round-trip preservation.
6. Actual wide/compact panel, keyboard/AX, Help, recoverable non-happy paths,
   unavailable versus empty state and late-result rejection after identity changes.

All Xcode invocations require a concrete command and serialized reservation from
the orchestrator, explicit sanitized `env -i` identity/PATH/TMPDIR/DEVELOPER_DIR,
unsigned arm64 serial/offline execution, unique outputs and clean pinned cache.
Inspect inert synthetic XCTest startup before launch. Native sessions use a fresh
copied xctestrun and unique token; verify exact PID/window before CUA. Never call
CUA after the test host exits: it can launch the plain product. Coordinate stopping
UI reads before terminating the host. No plain app, signed/direct-xctest/linker
fallback, owner SQLite, services, credentials, notifications or cleanup. Report
startup failure; do not change the method. Existing successful checks are terminal
unless a concrete defect requires an affected recheck.

## Assignment and endpoint

Fresh delivery owner: Sol High, ceiling Astra High, no subagents. This profile
addresses additive provenance, authority and recovery across existing components.
Dispatch sets actual model/effort and exact baseline. Writer owns the complete
source/tests, affected design/ADR text and canonical evidence under
`docs/delivery/evidence/2026-09-10-phase6c-evidence.md` plus necessary screenshots.
Orchestrator exclusively owns progress/catalog/index metadata. Existing governing
instructions, security policies, installed skills and configuration are excluded.

One fresh independent Astra High reviewer covers the actual candidate's shared
contracts, persistence/recovery, security/privacy and native UX/QA risks. Only
Required findings block. No review-of-review, separate role matrix or repeated
verification of terminal properties. New scope or authority choices return to
the orchestrator; routine implementation remains within this brief.

Deliver the working slice, affected docs, direct checks, independent review and
scoped local commits. Return exact commits, evidence, remaining risks, retained
scratch and stopped-process confirmation. No push/PR, remote merge, installation,
owner-state/catalog binding or acceptance, external mutations or cleanup.
