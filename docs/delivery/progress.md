# Release Radar delivery state

## Current outcome and authorization

- MDCP is complete and ordinary live use was owner-approved on 2026-09-02.
  M6B adopted five evidence locators; M7 deployed the six stable-ID document
  moves; M8 accepted the catalog and verified exact replay/relaunch. Delivery
  checkpoints are `b9b1932`, `004e2d2`, `d1b974a` and final closeout `a66bf9a`.
- RR-R10 Tasks 1A/1B/2A/2B/3/4A are delivered. Ten checkpoints remain:
  4B, 5, 6, 7, 7A, 8, 9, 10, 11A and 11B, then explicit ticket/Delivery Goal
  acceptance and terminal reconciliation. Stable task identities and the full
  product outcome are unchanged.
- On 2026-09-02 the owner approved the alignment review findings and authorized
  a focused remaining-plan revision and Task 4B brief. This repository planning
  slice is complete with native documentation validation and independent
  review accepted, Required 0 and Optional 0.
  Task 4B implementation, owner installation, catalog deployment/acceptance and
  other live mutations are not authorized by that planning approval.
- Repository work uses `codex/managed-documentation-contract-planning` in its
  associated development worktree. The original bound checkout retains its
  deployment branch/commit and authorized MDCP documentation delta.

## Controlling work and verification

- [Revised RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md)
  and [Task 4B brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4b-audited-ticket-task-commands-brief.md)
  apply the current schema/tool baseline, bridge-test isolation, managed import
  and evidence preservation, catalog release path and ADR-007 review policy.
  The linked Ticket Tasks design now distinguishes completed handoff history
  from current entry conditions.
- Task 4B's bounded test scope includes updating the existing MDCP callback
  assertion that the new task tool is absent. It preserves all six MDCP tools;
  the intended inventory is 19 existing plus two new tools.
- Native catalog/index/link/checksum validation and `git diff --check` pass.
  All 194 existing artifact IDs/paths and the 16 task labels/titles/order are
  preserved; the catalog adds only the brief and historical progress record.
  Completed MDCP brief lifecycle metadata and status headers are reconciled.
  The correction passed native current-tree/transition checks and independent
  documentation review; no runtime tests were rerun.
  Independent review accepted the plan, brief and authorization/preservation
  boundaries. No product code, runtime tests or owner-state operations are
  part of this planning slice.

## Live baseline and remaining risks

- Accepted application baseline: `MDCP-COMPAT-2` (`b365aff`), signed app/plugin
  0.1.6, schema v13, guidance v2. The last accepted bound-root catalog is v1
  with 194 artifacts; all eight evidence IDs/locators/associations and unrelated
  delivery state were preserved at M8. Ordinary live use may subsequently
  change owner state, so future installs require fresh authorized readback.
- This development candidate adds the Task 4B brief and a historical progress
  record, and corrects completed MDCP brief lifecycle metadata. The branch
  preserves the missing activation revision before the completion revision;
  later catalog deployment must accept those revisions in order. The M6A
  runbook remains a supporting preservation/recovery reference. This catalog
  is repository-prepared only, pending separately
  authorized deployment to the exact bound root and typed acceptance. The
  live bound checkout has not been changed; no managed-current claim is made
  for the development catalog.
- Whole transport/lifecycle test classes can change the shared macOS bridge.
  Task 4B's brief supplies safe development selections; required packaged
  transport acceptance still needs an isolated service/session or separately
  authorized quiescence and restoration.
- The M8 runtime limits remain documented in the historical record, including
  the unchanged legacy directory-locator discrepancy. No accepted MDCP work
  is reopened by this planning refresh. Issue #1 remains unopened and the
  held Issue #2 artifacts remain unchanged.

## Retention and next work

The [Historical closeout and review record](archive/2026-09-02-progress-through-mdcp-closeout-and-rr-r10-review.md)
preserves prior delivery details and the seven alignment findings. Earlier
history remains in [Historical progress through M6B](archive/2026-09-02-progress-through-mdcp-m6b.md).
Exact owner approvals, requests, inventories and recovery copies remain in the
owner-designated protected companion, retained through at least 2026-10-02.
Existing M6A/M7/M8 temporary builds, test outputs and isolated host directories
retain their recorded custody terms; none were deleted. This planning slice
creates no new temporary files.

After this planning slice is delivered, Task 4B is the next eligible feature
under its separate implementation authorization. Complete the required
controlled transport checks before claiming that future slice complete.
