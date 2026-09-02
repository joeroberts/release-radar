# Release Radar delivery state

## Current outcome and authorization

- M2–M6B are accepted. M6B converted five exact evidence locators, preserved
  three legacy records, and passed replay/relaunch, QA and Architecture/Security
  acceptance. Delivery checkpoint: `b9b1932`.
- M7 repository cutover is accepted: six stable-ID moves, catalog and four
  indexes, current references, and archived closed progress are deployed.
  Active task: M8 catalog acceptance and controlled runtime readback.
- The owner resumed the complete cutover/runtime outcome and selected the
  existing `codex/managed-documentation-contract-planning` worktree. Exact live
  cutover/deployment and catalog-acceptance authorization is recorded in the
  protected companion before execution.
- Controlling scope: [M7 brief](task-briefs/2026-09-01-managed-repository-documentation-contract/m7-catalog-driven-cutover-brief.md),
  [M8 brief](task-briefs/2026-09-01-managed-repository-documentation-contract/m8-runtime-acceptance-closeout-brief.md),
  [managed documentation design](../design/managed-repository-documentation-contract.md),
  [ADR-006](../architecture/ADR-006-managed-repository-documentation-contract.md)
  and [ADR-007](../architecture/ADR-007-proportional-delivery-validation.md).

## State, verification and risks

- Frozen compatibility candidate: `MDCP-COMPAT-2`, commit `b365aff`, signed app
  and plugin 0.1.6. No application, schema, permission or frozen-contract change.
- The application still accepts the M6B catalog snapshot until M8's typed
  acceptance. The cutover candidate is pending; no managed inventory or normal
  writer may consume it before acceptance.
- Both development and bound-checkout native catalog/index/link/checksum
  checks pass. The deployed files equal the independently reviewed candidate;
  Documentation review has no required or optional findings. The approved
  transition retains 193 artifact IDs and adds one historical progress record.
- Before cutover the owner opened the app normally. Fresh complete inventory
  preserved M6B evidence/binding/root/delivery state; only the plugin lifecycle
  record and one audit changed. That owner state is preserved as the new
  baseline. Independent Security review found no remaining blocker. Ordinary
  writers and the installed query client were then quiesced before any move.
- One pre-existing legacy directory locator remains unresolved. The installed
  plugin lifecycle state changed during the owner’s normal launch; its current
  fingerprint is preserved, and no lifecycle repair is part of this cutover.
  Ordinary live use remains unreleased.
- Exact requests, backups, readbacks, UI evidence and recovery terms remain in
  the owner-designated protected companion. Retain them through M8 and at least
  2026-10-02; deletion requires separate authorization.

## Next eligible work

Complete M7 delivery, then M8's exact catalog acceptance, read-only runtime/
relaunch checks and final delivery. Task 4B and Issue #1 remain
separate and unopened.

[Historical delivery through M6B](archive/2026-09-02-progress-through-mdcp-m6b.md)
contains closed task detail and the preserved Issue #2 unknown-authorship record.
The catalog and root/local indexes provide navigation; this file owns current
status and sequencing.
