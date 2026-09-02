# Historical progress through MDCP closeout and RR-R10 alignment review

> **Historical and non-authoritative.** This preserves the delivery ledger
> before the owner-authorized RR-R10 planning refresh. Review findings describe
> the pre-refresh plan and do not determine current task eligibility.
> Current state is recorded in [progress.md](../progress.md).

# Release Radar delivery state

## Current outcome and authorization

- M2–M8 are accepted. M6B adopted five exact evidence locators; M7 deployed six
  stable-ID document moves, complete indexes, current references and archived
  closed progress. Delivery checkpoints: M6B `b9b1932`, M7 `004e2d2`, and
  M8 runtime acceptance `d1b974a`.
- M8 runtime acceptance is complete, including independent QA with no
  required or optional findings. On 2026-09-02, after successful readback and
  review, the owner explicitly approved release for ordinary live use.
  MDCP is complete.
- The owner approved the exact adoption, cutover, bound-checkout deployment,
  catalog-acceptance request, replay, backup and controlled readback packages.
  Repository delivery uses `codex/managed-documentation-contract-planning` in
  its associated development worktree. The original bound checkout retains its
  deployment branch and commit with only the authorized documentation delta.
- Controlling scope: [M7 brief](task-briefs/2026-09-01-managed-repository-documentation-contract/m7-catalog-driven-cutover-brief.md),
  [M8 brief](task-briefs/2026-09-01-managed-repository-documentation-contract/m8-runtime-acceptance-closeout-brief.md),
  [managed documentation design](../design/managed-repository-documentation-contract.md),
  [ADR-006](../architecture/ADR-006-managed-repository-documentation-contract.md)
  and [ADR-007](../architecture/ADR-007-proportional-delivery-validation.md).

## Verification and remaining limits

- Frozen `MDCP-COMPAT-2` is `b365aff`: signed app/plugin 0.1.6. No production
  source, schema, permission or frozen-contract change was needed.
- Native current-tree, accepted-prior transition, index, link and checksum
  checks pass. Deterministic rendering changes zero indexes. The catalog has
  194 artifacts, preserving all 193 existing IDs. No active dependency on the
  removed transitional subtree remains; historical references are retained.
- The typed M8 operation accepted the deployed catalog. Exact replay returned
  the original result and one audit/receipt pair. Complete readback persisted
  across read-only relaunch. Only the accepted snapshot and the moved managed
  plan's resolved path changed; all eight evidence IDs, locators, associations,
  availability, roots, and 17 other preservation domains remain exact.
- Before cutover, the owner confirmed opening the app normally. Fresh inventory
  isolated its effect to plugin lifecycle state and one audit. That state was
  preserved as the new baseline after independent Security acceptance.
  Ordinary writers stayed quiesced throughout actual cutover and acceptance.
- Native tests: 38 focused cases plus one post-cutover repository-conformance
  case passed, with zero failures/skips. Isolated fixtures cover migration,
  transition refusal/rollback, replay, compatibility, missing/historical
  evidence, and root-relocation identity/recovery. Real macOS bookmark creation
  and broker-level lost acceptance replies were not injected in this run.
- Installed-app accessibility and screenshots show the accepted repository,
  current/completed/superseded managed evidence and the moved canonical path.
  Maintenance preserves the approved design's readable hierarchy and explicit
  status labels; the normal phase-board shell was not relaunched. One existing
  legacy directory locator remains typed unresolved while its legacy UI shows
  stored availability. Its identity and behavior remain unchanged.
- Read-only maintenance exited; database, sidecars and recovery snapshot stayed
  byte-identical during relaunch/UI inspection. Ordinary live use is released
  under the owner's final approval.
- Independent M6B QA/Architecture/Security and M7 Documentation reviews accepted
  their actual slices with no required findings. Independent M8 runtime QA
  accepted the actual transition, replay, relaunch, state preservation and UI.

## Durable records and next work

Exact approvals, requests/results, complete inventories, UI evidence and
verified recovery copies remain in the owner-designated protected companion.
Retain them through M8 and at least 2026-10-02; deletion needs separate approval.
The temporary M7 candidate and M8 test outputs remain under the development
worktree's `.build/mdcp-m7-candidate/` and `.build/mdcp-m8-tests/`; two isolated
XCTest host directories also remain. Earlier M6A build/disposable inputs retain
their existing custody and disposal terms.

No MDCP work remains. Task 4B is the next separately authorized feature task;
Issue #1 remains unopened. Neither is authorized by this closeout. The held Issue #2 artifacts
remain unchanged.

[Historical delivery through M6B](archive/2026-09-02-progress-through-mdcp-m6b.md)
contains closed detail and the preserved Issue #2 attribution record. The
catalog and indexes own navigation; this ledger owns delivery status.

## RR-R10 post-MDCP alignment review

On 2026-09-02 the owner authorized review of the remaining RR-R10 work.
Static review of the [remaining implementation plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md),
current source and accepted documentation found seven required planning
corrections. Independent read-only reviews covered command/import/presentation
compatibility and deployment/recovery. These are findings for the planning
refresh, not authorization to implement Task 4B or change owner state.

1. **P1 — Isolate the bridge as well as the database.** Task 4B's whole-class
   transport-test instruction (plan lines 1643–1647) includes tests that connect
   to the fixed macOS service and unregister it during cleanup
   (`AgentBridgeTransportAcceptanceTests.swift:513,578`). Use focused tests
   without shared-service effects during development; packaged broker tests
   require an isolated service/session environment or separately authorized
   quiescence and restoration. Apply this boundary to Task 8 and full-suite
   installation gates as well.
2. **P1 — Preserve the current command surface.** Task 4B's Task-4A-plus-two
   inventory (plan lines 1645–1647) predates six MDCP tools. Preserve the current
   19 tools and add two, yielding 21; Task 8 later adds three, yielding 24.
   Keep existing schemas, the read-only inventory route, optional result
   inventory, and existing receipt/replay behavior. Task 8's owner-origin
   check remains valid when scoped to its new owner-only lifecycle commands;
   ordinary JSON receipts and MDCP digest receipts must retain their encodings.
3. **P1 — Install over the existing managed v13 store.** Tasks 7A/11A still
   describe schema v12 as the installation/migration endpoint (plan lines
   1794–1809 and 1988–1991). Preserve the immutable older fixtures and exercise
   their migrations through current v13, separately from installation over
   an existing v13 store. Preserve RR-R10's existing continuation. Extend the
   shared Task 7A/11B preservation contract to the fresh authorized binding,
   root, accepted catalog, evidence IDs/locators/associations/resolution, legacy
   behavior and plugin state. Adapt the existing M6A recovery procedure to
   that baseline; do not replay initial binding/adoption or reuse old approval
   as authority for a new installation.
4. **P2 — Retain the MDCP boundaries in shared files.** Task 7's writer routing
   must remain inside the importer's existing authorized transaction and
   preserve bound-root/catalog checks, managed artifact IDs and legacy
   locators. Tasks 5/9/10 must retain authorized evidence projections and their
   lifecycle, authority and recovery presentation while changing board/detail
   composition. Reuse focused importer and evidence-presentation regressions;
   no new evidence feature or repeated exhaustive visual gate is needed.
5. **P2 — Use the managed documentation release path.** New briefs and durable
   lifecycle changes need catalog/index/reference maintenance and native
   validation in the development worktree. Deploy changed catalogs to the
   exact bound root and accept the prior-to-candidate transition at an
   authorized live checkpoint before managed operations. Catalogued evidence
   uses artifact IDs. Final reconciliation (plan lines 2133–2143) must keep
   progress concise and archive necessary closed detail with its metadata.
   Content-only edits to mutable plans/progress do not themselves require
   catalog acceptance.
6. **P2 — Separate completed handoff history from current entry conditions.**
   The plan header/completion check and Ticket Tasks design still describe
   pending package acceptance and a schema-v10 Blocked-state handoff. Mark
   those as historical and point current execution to this ledger. Tasks
   1A/1B/2A/2B/3/4A are delivered; retain the 16 stable initial task identities
   and create no app-owned completion from document status.
7. **P2 — Apply the accepted proportional delivery policy.** Replace the
   unopened tasks' mandatory all-role matrices, mutable-brief hashes and
   repeated intermediate Git gates with AGENTS.md/ADR-007 risk-triggered
   review and ordinary verification. Preserve product/security requirements,
   Task 5's explicit owner UI acceptance, final owner acceptance, and verified
   fast-forward delivery checkpoints for completed slices.

The remaining sequence is unchanged: 4B, 5, 6, 7, 7A, 8, 9, 10, 11A, 11B,
then explicit ticket/Delivery Goal acceptance and terminal reconciliation.
Next eligible repository work is the bounded alignment revision and Task 4B
brief; feature execution and live actions still need their applicable owner
authorization. Native documentation checking passed during review. No runtime
tests or owner-state operations were performed; no new temporary files were
created. The review record is the only repository edit from this pass.
