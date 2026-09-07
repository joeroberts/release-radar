# Release Radar delivery state

## Current phase — 2026-09-07

Slice 2 recovery is active: C4 is merged; C5 archive/restore is dispatched, then C6
removal with retained history and C7 coordinated backup/reset follow, with associated
C12 health. The [full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capabilities and accepted/proposed distinctions. Later documentation,
navigation, planning/traceability, history/search/evidence, portable continuity and
conditional integrations remain included.

Recovery orchestrator `01a07b81-ce26-7e70-8696-fc4427eb83a1` owns this ledger and
shared documentation integration in worktree `f1ab`, published branch
`codex/recovery-orchestration`. Assigned Astra Medium; runtime model settings are not
exposed by the coordination API. It began at `80521d6`. Prior orchestrator
`01a078bb-1a08-7222-96b1-58e842f5f809` is stopped/archived; its branch is retired,
`b2425c1` remains on `origin/codex/archive-lifecycle-delivery-2026-09-07`, and `26a5`
is recovery-only. Do not reuse them.

## Authorization and active C5 assignment

Continuing owner authority covers approved product implementation, affected docs,
synthetic checks, scoped commits, branch pushes and PR creation. **Ask before each
PR merge.** Installation, real owner-data archive/relocation/deletion/reset, real
notifications and other reserved application/external mutations need exact authority.
SQLite remains exclusively app-owned. Preserve canonical recovery stash `7adfff2`,
local exclusions, C8 app and retained `dist/PR-23-*` acceptance/rollback artifacts.
Pursuit migration is stopped; RDS appearance is unchanged.

“Deliver reversible project archive and…” (`01a07bab-4a2b-7e53-b388-10800a2e3a6c`)
was dispatched fresh with explicit
Sol High from committed `6e67cd6`, containing merged C4 `32bb2ce` and the
[controlling C5 brief](task-briefs/2026-09-07-c5-archive-restore/c5-archive-restore-brief.md).
The worker confirmed dedicated worktree `dc15`, baseline `6e67cd6`, and published
`codex/c5-archive-restore` with matching upstream; runtime model/effort is unexposed.
It owns source/tests/brief; parent retains
ledger and shared catalog/index integration. Ceiling Astra High, Ultra prohibited.
The complete outcome preserves graph/registration/history and association, suspends
operational activity, supports discoverable restore without a valid catalog, and
prevents stale callbacks or notification replay.

[PR #29](https://github.com/joeroberts/release-radar/pull/29) contains author candidate
`8c85e48`, integrated with catalogued [native UI evidence](evidence/2026-09-07-c5-archive-restore-ui.md)
at `e81828d`. Author reports C5 10/10, Store/Notification 82/82, affected
Onboarding/Bridge/Route/Dashboard 173/173 and native compact/wide 1/1. The dashboard
batch excludes `testInactiveBoardPreservesAuthorizedEvidenceMetadataAndRecovery`;
the author reports that fixture and existing root-management fixtures fail before
relevant behavior on this host's `/var` symlink containment. No protection was weakened;
this is not a full-suite pass or shipping folder-grant proof.

Fresh independent task “Review C5 reversible archive and restore”
(`01a07bf9-623b-71d2-9af1-ab70b5dc19e8`) confirmed clean candidate `e81828d` in `f419`.
Explicit Astra High; runtime settings unexposed. It covers persistence, authorization,
notification recovery and native UI/QA. Review found two Required P1 admission defects; owner merge approval is not yet requested.
Independent checks passed 93/93 (C5 10, Notification 28, Store 54, native UI 1).
Two bounded negative reproducers then confirmed:
- Documentation mutations bypass active admission (`AgentCommandDispatcher.swift:56`);
  an archived project accepted binding and added an audit/receipt.
- Ordinary resolved authorization omits registration/generation; a pre-archive request
  created a phase after restore advanced generation 1→3.
Correction must reject operational documentation while archived and revalidate captured
registration/generation transactionally, while preserving fresh post-restore work.
The same reviewer will check the corrected candidate's affected boundaries; unchanged
native/UI checks do not restart. No unrelated fixture/security change is authorized.
Reviewer temporary repro source remains untracked in `f419/ReleaseRadarTests/`
`C5IndependentReviewTests.swift`. Under `/tmp/`, prefix `c5-review-f419-` outputs are
`build`, `focused.log`, `focused.xcresult`, `repro.log`, `repro.xcresult`, `attachments`.
No cleanup is authorized.

Repository documentation and diff checks pass after the five evidence registrations;
no application catalog acceptance is claimed.
Writer confirmed PR/branch `e81828d`, clean worktree, final documentation/diff checks
passing and no active xcodebuild-test/xctest processes; delivery task was archived, then restored for the two Required same-outcome corrections
at explicit Sol High.

C5 temporary files remain; no deletion is authorized. Under `/tmp/`, all names below
use prefix `release-radar-c5-`: build directories `direct`, `doc-tool`, `red`,
`verify-adjacent`, `verify-c5`, `verify-render`, `verify-store`; result bundles
`failing-0907.xcresult`, `direct-0828.xcresult` (interrupted/corrupt aggregate),
`render-0813.xcresult`, `render-0814.xcresult`, `render-0815.xcresult`,
`render-0822.xcresult`, `render-0823.xcresult`, `render-final.xcresult`,
`render-final2.xcresult`; attachment directories `images-0823`,
`render-final-attachments`, `render-final2-attachments`; diagnostics
`dashboard-debug.log`, `dashboard-one.log`, `dashboard-repeat.log`, `direct-0828.log`,
`root-debug.log`, `root-debug2.log`, `root-debug3.log`, `root-one.log`,
`root-repeat.log`, `store-one.log`, `xcresult.err`. All durable UI evidence is committed
under `docs/delivery/evidence/`; these are retained temporary verification outputs.


## Delivered C4 and verification limits

[PR #28](https://github.com/joeroberts/release-radar/pull/28) merged with owner approval
as `32bb2cee59f34f7dfc9eae4b7a86391f77bf742d`, from reviewed product `1801ded` and
final documentation integration `5816c71`. It delivers explicit worktree grant,
reconnect/revoke, existing worktree promotion through accepted-catalog relocation,
per-root health and C4-local no-follow Git membership. Bound root remains primary;
legacy first-root semantics and repository files/history are preserved.

Author reports 66 selected checks across focused runs. Fresh combined Astra High
reviewer passed 31 selected cases plus native620/1100 AX/Escape/Health and visual
comparison, with no Required/Optional findings. Documentation/diff checks and
CodeRabbit passed. See [C4 brief/evidence](task-briefs/2026-09-07-c4-root-management/c4-root-management-brief.md).
XCTest injects read-only `/`; containment/injected-denial tests do not prove real
NSOpenPanel grants under shipping entitlements. The owner approved source merge with
this limitation disclosed. No installation or owner-state acceptance is claimed.
Writer `01a07b7a-f30a-7373-99ba-709e4f9c6a69` and reviewer
`01a07ba1-5d2b-7921-8e72-558438f15167` are stopped/archived.

## Completed parallel discovery

All four bounded discovery writers and reviewers are stopped/archived. Their
artifacts contain the original briefs, source-backed findings and limitations.

- [Run ownership](task-briefs/2026-09-07-parallel-discovery/run-ownership-discovery.md):
  PR #25 merged with owner approval as `7e38fb8`; independent review passed. Conditional
  pursuit of a synthetic first-provider proof is proposed, not authorized. Production
  execution/control of existing desktop runs remains no-go without proof.
- [Rules/hooks](task-briefs/2026-09-07-parallel-discovery/rules-hooks-discovery.md):
  PR #24 merged with owner approval as `fb57804`; corrected `c71d880` passed review.
  No-go for enabling active controls today; authorization-aware enforcement, safe Stop
  state and hook privacy/trust remain unproven. No configuration pilot is authorized.
- [Live observation](task-briefs/2026-09-07-parallel-discovery/live-observation-discovery.md):
  PR #26 merged with owner approval as `bf263b1`; `95ad1fc` passed review. Supported
  authenticated observation of the current desktop-owned runtime is no-go; historical
  browsing and companion delivery/document publication remain independent.
- [Companion PR #27](https://github.com/joeroberts/release-radar/pull/27): final
  `6385d49628a6ca83bd22caf8d02bac8edff1c679` passed corrected review and merged with
  owner approval as `d4bacea40aa4f40e6f41a9f7ca2337165b2a6b30`. It proposes complete
  read-only private
  CloudKit publication with withdrawal preserved across recovery and cache fallback.
  No production feasibility, cloud provisioning or implementation is authorized.

## Repository/application state and retained history

Native documentation and diff checks pass for coordination changes. The last supported
canonical application inventory reports `bindingMissing`, `isComplete:false` for
`project-fffdc0e0b15b9b86`; no managed synchronization/catalog acceptance is claimed.
No owner/application-state mutation was performed by this orchestration.

[Historical recovery record](archive/2026-09-07-recovery-through-c4-and-parallel-discoveries.md)
preserves retired task/branch facts, complete bounded assignment IDs, review results,
prior lifecycle acceptance and temporary-path inventories. Retained temporary C4
builds/fixtures/logs/attachments/test-host outputs and rules-discovery `pilot.rules`/
`pr-body.md` remain as inventoried there and in the C4 brief. No cleanup is authorized
or performed. Prior broad-suite574/576 is historical, not a current whole-suite pass.
