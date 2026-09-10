# Phase 6D: generic task adoption

Status: controlling refinement of the authorized Phase 6 sequence. Dispatch sets
the exact committed baseline containing this brief and reviewed 6C dependency.

## Objective and scope

Deliver the complete generic task adoption outcome in the
[Phase 6 plan](../../plans/2026-09-10-phase6-outcomes-tasks-history.md) and
[issue #1](https://github.com/joeroberts/release-radar/issues/1): complete scoped
typed inventory, owner-visible atomic/non-atomic/already-planned/blocked
reconciliation, exact approved task catalogs, resumable existing receipts,
explicit evidence-backed past completion and readback, product guidance v3 and
contextual adoption Help. Atomic tickets may remain without a plan. Adoption
must not change lanes, outcomes, Delivery Goals, phase readiness, review or
acceptance. No implicit tasks or completion from Git, Markdown, tests or Codex.

No new proposal engine, task database, runtime Markdown parser, automatic approval,
live observer, hooks, cardinality/suggestions, native catalog editor, consumer
adoption, installed skill/configuration or governing-instruction edits. Product-
owned templates and packaged skill source are explicitly in scope. Installation,
owner state, publication and cleanup are excluded.

## Dependencies and bounded implementation

Reviewed 6C endpoint is `c7ee42bdffe1d6d89156430f5e2e167394e9dfb5` on
`codex/phase6c-reviewed`. Its corrected applicability, append ordering and replay
contracts are available in the writer baseline. Preserve
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and
[whole-product direction](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Chief consultation `01a08d93-8aa5-7611-a33e-e8fdb960d52c` (Astra High) found no
blocking owner choice. Its following recommendations are selected implementation
choices within scope, not additional product requirements:

- Extend `AgentQueryDispatcher` with complete project-scoped delivery inventory:
  exact project/root/registration, all phases and lifecycle restrictions,
  placed/unassigned tickets, retirement/Accepted exclusions, plan absence or
  exact revision, all task rows including superseded identity history, and active
  count. Distinguish absent from unavailable. Oversized, partial or failed reads
  cannot appear complete. Revalidate authorization during capture; reads write
  nothing. Reuse existing transport/query and projection patterns.
- Packaged guidance produces one owner-visible reconciliation for every scoped
  non-Accepted ticket, with classification/rationale, current plan baseline,
  complete proposed additions/revisions/supersessions and unchanged rows. Show
  Accepted exclusions and other lifecycle restrictions. Owner approval identifies
  that exact reconciliation; general implementation approval is not approval of
  runtime task mutations. Preserve the approved catalog and ordered requests in
  existing repository delivery documentation referenced by its ledger.
- Reuse existing `reviseTicketTaskPlan` and `completeTicketTask` commands and
  `TicketTaskPlanningPolicy`. No-plan creation uses expectedRevision nil and
  returns revision 1; every addition is Active/Pending. Existing plans require
  exact revisions. Omission never deletes or supersedes. Accepted, retired and
  Completed-phase guards remain intact; unassigned definitions are permitted
  but completion remains blocked. Migration and import remain task-neutral.
- Preserve each original complete request envelope before sending, then retain
  returned revision/audit IDs. Resume uncertainty by replaying that envelope
  unchanged. Chain each completion using the preceding returned revision. A
  changed baseline requires refreshed reconciliation and approval of the affected
  change, not reconstructed uncertain requests or rollback of successful work.
- Prior completion is separately explicit and supported by identified 6C
  observations, target version and relevant scope. Consume the actual evidence
  query/evaluator; preserve failed, stale, superseded, unavailable and unknown
  distinctions. Not specified, unrelated expectations and generic observations
  do not establish task completion. Guidance obtains owner approval; existing
  runtime commands enforce authority/revision/lifecycle/replay, not conversational
  approval or evidence sufficiency. Do not claim stronger enforcement than exists.
- Typed inventory confirms current revision, complete rows and count; mutation
  receipts confirm audit identity. Existing native Tasks list, neutral card count
  and History provide owner readback. Add adoption Help and actionable unavailable
  states. No separate native proposal screen is needed for this guidance-driven
  workflow. Inspect Work Board wide/compact mockups before UI work.
- Guidance v3 must update product-owned contract, inspection, onboarding/repair
  prompts and packaged skill coherently. Preserve exact v2 recognition and narrow
  idempotent upgrade; modified/duplicate/newer blocks remain recovery states.
  Keep catalog v1 and `release-radar-handoff:v1:` identity semantics. New package
  bytes require a new version/digest entry; retain frozen 0.1.7 and 0.1.8 pairs,
  shared-execution standard v1 and rejection of unknown pairs. Never edit the
  active repository AGENTS, installed skill/configuration or consumer instructions.

No new persistent adoption store is required. Existing task retention/full-backup
and authority rotation remain the recovery boundary. Future search consumes these
identities; Phase 7 portability is excluded. Any unavoidable new persistence or
public-contract change must be bounded to this outcome and explicitly explained.

## Acceptance and direct verification

Use test-first repository-native checks for complete mixed-ticket inventory and
workflow, zero-write reads, partial/unavailable/oversized results, stale scope or
registration, exact revisions, Accepted/retired/Completed guards, revision-1
creation and Active/Pending additions. Exercise existing plan revisions without
implicit deletion, separate prior completion with applicable evidence, missing
approval guidance, interrupted ordered execution/exact replay, changed-body
rejection, restored authority and unchanged phase/lane/goal/readiness/acceptance.
Test actual boundaries and mixed workflow, not only expected words in a template.
Do not build a new test engine to simulate conversational approval.

Verify narrow v2-to-v3 generated handoff/repair in synthetic repositories and
historical package capability compatibility. No owner guidance is upgraded here.
Compare actual native Tasks/card/readback and Help at wide/compact sizes with
`docs/design/mockups/work_board.png` and `work_board_compact.png`, including
keyboard/accessibility, no-plan, complete titled rows and recoverable errors.
Existing successful checks are terminal unless changed behavior or a concrete
risk requires affected repetition. No full-suite claim from focused tests.

All builds/tests require a concrete command and serialized reservation from the
orchestrator: sanitized env -i with explicit identity/PATH/TMPDIR/DEVELOPER_DIR,
unsigned arm64 serial/offline execution, fresh outputs and clean pinned package
cache. Inspect inert synthetic XCTest startup before launch. Native sessions use
fresh copied xctestrun, unique token and exact PID/window verification. Coordinate
CUA stop before host termination; never call CUA after exit because it can launch
a plain product. No plain/signed/direct-xctest fallback, owner SQLite, credentials,
services, notifications or cleanup. Report launch failures without changing the
method. Read-only result/attachment inspection is already authorized.

## Assignment and endpoint

One fresh Sol High delivery owner, ceiling Astra High, no subagents. The profile
addresses cross-component inventory, guidance compatibility and replay/recovery.
Writer owns complete source/tests, affected ADR/design docs and canonical evidence
`docs/delivery/evidence/2026-09-10-phase6d-adoption.md` plus necessary screenshots.
Root alone owns progress/catalog/index metadata and integration. One product writer
at a time; no shared app-state mutations. Dispatch names exact branch/revision.

One fresh independent Astra High reviewer covers actual public contracts,
authority/owner-content and replay/recovery risks plus native UX/QA. Only Required
findings block. No review-of-review, role matrix or extra approval layers. Return
routine in-scope corrections to the same outcome; owner decisions only for genuine
scope/authority conflicts. Never Ultra.

Deliver working behavior, affected documentation, direct checks, independent
review and scoped local commits. Report actual verified commit IDs, changed files,
checks, remaining risks, retained temporary outputs and stopped-process handback.
No push/PR/merge, package publication, installation, owner-state/catalog binding or
acceptance, external mutations, cleanup or installed guidance edits are authorized.
