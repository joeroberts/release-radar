# Release Radar delivery state

## Current outcome and authorization

- MDCP is complete and ordinary live use was owner-approved on 2026-09-02.
  M6B adopted five evidence locators; M7 deployed the six stable-ID document
  moves; M8 accepted the catalog and verified exact replay/relaunch. Delivery
  checkpoints are `b9b1932`, `004e2d2`, `d1b974a` and final closeout `a66bf9a`.
- RR-R10 Tasks 1A/1B/2A/2B/3/4A are delivered. Task 4B implementation and
  acceptance are complete, with PR delivery in progress. Nine later checkpoints
  remain: 5, 6, 7, 7A, 8, 9, 10, 11A and 11B, then explicit ticket/Delivery Goal
  acceptance and terminal reconciliation. Stable task identities and the full
  product outcome are unchanged.
- The alignment review and controlling Task 4B brief were independently
  accepted and merged in PR #4. On 2026-09-02 the owner separately authorized
  Task 4B implementation, validation, commit, push, pull request and merge,
  through coordinator task `01a06184-6387-7c42-878e-695db0481a18`. Routine
  decisions are delegated to that coordinator; high-risk/destructive owner
  or shared-state actions still require the human owner.
- Task 4B is active on `codex/rr-r10-task-4b` in its isolated development
  worktree, based on merged commit `02d16db`. The original bound checkout,
  deployment commit and intentional documentation changes are preserved.
  Owner installation, live bootstrap and catalog deployment/acceptance are
  outside this task's authorization.
- The verified implementation is pushed as `ddf551a` in
  [PR #5](https://github.com/joeroberts/release-radar/pull/5), targeting
  `codex/release-radar-mvp`. PR merge is the remaining delivery action.

## Controlling work and verification

- [Revised RR-R10 plan](plans/2026-08-29-delivery-goals-roadmap-readiness.md)
  and [Task 4B brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4b-audited-ticket-task-commands-brief.md)
  apply the current schema/tool baseline, bridge-test isolation, managed import
  and evidence preservation, catalog release path and ADR-007 review policy.
  The linked Ticket Tasks design now distinguishes completed handoff history
  from current entry conditions.
- Task 4B's bounded test scope includes updating the existing MDCP callback
  assertion for the two newly exposed tools. The verified inventory preserves
  all 19 prior tools, including the six MDCP tools, and adds exactly two.
  The only supporting production path beyond the original brief is the
  compiler-required exhaustive error mapping in `FailureStateView.swift`,
  confirmed by the coordinator under the existing authorization.
- Test-first implementation passed 103 focused native tests: policy, bridge,
  notifications, safe packaged schemas/input validation and selected MDCP
  regressions. Debug build and prepared test build pass. Native documentation
  validation and `git diff --check` pass. Independent code/QA, public-contract/
  transaction, Security/Privacy, error-presentation and documentation review
  found Required 0 and Optional 0. No schema or policy implementation changed.
- The coordinator separately approved the bounded app pause/relaunch and
  controlled broker test, including ordinary startup effects. The single
  guarded transport selector passed (1 test, 0 failures), proving both tools,
  committed revisions/receipts, exact replay, lost-reply recovery and
  unavailable-app refusal. The installed broker, lifecycle helper and existing
  MCP clients remained running. The exact installed app was restored, and
  read-only inventory at the saved bound root returned `isComplete = true`,
  schema v13, eight evidence rows and matching catalog/accepted-binding digest.
  The caller hold was released after restoration; no further service test is
  required. No owner installation, live task bootstrap, catalog acceptance or
  direct owner-store access occurred.

## Live baseline and remaining risks

- Accepted application baseline: `MDCP-COMPAT-2` (`b365aff`), signed app/plugin
  0.1.6, schema v13, guidance v2. The last accepted bound-root catalog is v1
  with 194 artifacts; all eight evidence IDs/locators/associations and unrelated
  delivery state were preserved at M8. Ordinary live use may subsequently
  change owner state, so future installs require fresh authorized readback.
- The inherited development catalog adds the Task 4B brief and a historical
  progress record and corrects completed MDCP brief lifecycle metadata. Task 4B
  closeout changes only its brief to completed/non-authoritative, preserving
  its stable artifact ID and path. The branch preserves the missing activation
  revision before the completion revision;
  later catalog deployment must accept those revisions in order. The M6A
  runbook remains a supporting preservation/recovery reference. This catalog
  is repository-prepared only, pending separately
  authorized deployment to the exact bound root and typed acceptance. The
  live bound checkout has not been changed; no managed-current claim is made
  for the development catalog.
- Whole transport/lifecycle test classes can change the shared macOS bridge.
  Future tasks must retain the brief's safe-selector discipline; Task 4B's
  completed controlled run does not authorize later shared-service operations.
- The M8 runtime limits remain documented in the historical record, including
  the unchanged legacy directory-locator discrepancy. No accepted MDCP work
  is reopened by Task 4B. Issue #1 remains unopened and the
  held Issue #2 artifacts remain unchanged.

## Retention and next work

The [Historical closeout and review record](archive/2026-09-02-progress-through-mdcp-closeout-and-rr-r10-review.md)
preserves prior delivery details and the seven alignment findings. Earlier
history remains in [Historical progress through M6B](archive/2026-09-02-progress-through-mdcp-m6b.md).
Exact owner approvals, requests, inventories and recovery copies remain in the
owner-designated protected companion, retained through at least 2026-10-02.
Existing M6A/M7/M8 temporary builds, test outputs and isolated host directories
retain their recorded custody terms; none were deleted. Task 4B build logs,
test results and prepared bundles remain temporarily in `.build/rr-r10-task4b`;
the repository-native tests also create synthetic temporary fixture directories.
These are verification output, not controlling deliverables. No additional
cleanup is authorized.

Task 4B is verified for its authorized PR/merge checkpoint. Task 5 may open
only in the next separately coordinated task after that merge. The new tools
remain development-only until Tasks 5, 6 and 7 are accepted; Task 7A owns the
later owner installation and live bootstrap.
