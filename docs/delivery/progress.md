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
