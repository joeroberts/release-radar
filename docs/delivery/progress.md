# Release Radar delivery state

## Current phase — 2026-09-07

Slice 2 recovery continues: C4 root management, C5 archive/restore and C6 removal
with retained history are merged. C7 backup/reset recovery is next, with
associated C12 recovery actions. The [full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capabilities; later roadmap outcomes and accepted/proposed distinctions
remain intact.

Orchestrator `01a07b81-ce26-7e70-8696-fc4427eb83a1` owns this ledger/catalog integration
in `f1ab`, branch `codex/recovery-orchestration`. Astra Medium; runtime unexposed.
Canonical checkout, retained recovery stash/exclusions/C8 app and prior dist artifacts
remain untouched. Pursuit migration is stopped; RDS appearance is unchanged.

## Authorization and C7 preparation

Existing authority covers scoped implementation, synthetic checks, commits, pushes and
PR creation. Each new PR merge requires separate owner approval. C6 approval was used
for PR #30 only. No installation, owner backup/reset/restore/removal, real notifications,
cloud/plugin mutation or application catalog acceptance is authorized. SQLite remains
exclusively app-owned. Canonical checkout/application state is preserved.

The [C7 brief](task-briefs/2026-09-07-c7-backup-reset-recovery/c7-backup-reset-recovery-brief.md)
starts from merged C6 `df7157b`. A fresh bounded read-only architecture consultation
will resolve current service/connection recovery and retained-history/nonreplay contracts
before a fresh delivery writer starts. The full approved C7 outcome remains included;
engineering sequencing does not omit backup, distinct resets, recovery or C12 readback.

## Delivered C6

[PR #30](https://github.com/joeroberts/release-radar/pull/30) merged with explicit owner
approval as `df7157bb377985f085903647c709c8c818d7efe9` from final reviewed `68a8282`.
It removes operational graph/capabilities atomically while retaining read-only history,
registration attribution and notification outcomes, leaving repository files untouched.
Fresh re-add cannot revive old prepared identities or requests. Historical unknown
phase/lane remains unknown. Three independent findings were corrected.

Direct evidence: author 309/309 selected serial tests initially, 44/44 correction and
45/45 catalog/index; independent 74 focused/native checks and 2/2 correction regressions,
final Astra High approval with no Required findings. Native docs/diff and CodeRabbit pass.
No whole-suite or shipping folder-grant claim: disabled-broker transport and an existing
disposable-copy docs fixture remain explicit unrelated limits. Both bounded tasks are
stopped/archived. [C6 UI evidence](evidence/2026-09-07-c6-remove-tracking-ui.md) is committed
and catalogued; [Historical handoff/temp inventory](archive/2026-09-07-c6-delivery-history.md)
preserves detailed results and retained paths. No cleanup is authorized.

## Delivered C5

[PR #29](https://github.com/joeroberts/release-radar/pull/29) merged with explicit owner
approval as `c8cba4b223eeeba2f5a0b03d1f649fe5bc51eff9` from final reviewed `1017dad`.
It delivers persistent reversible archive, discoverable read-only archived detail,
operational suspension and generation-based stale-request rejection without replaying
notifications or requiring valid catalog/access. Both independently found admission
bugs and six C5-caused migration/preservation failures were corrected.

Evidence: 344 targeted tests on admission correction; final 10/10 affected migration
cases including malformed-schema rejection; initial 93 independent checks include
native 620/1100 UI/AX. Final correction reviewer Astra High approved with no findings.
[UI evidence](evidence/2026-09-07-c5-archive-restore-ui.md) and its five catalog entries
are current. Native docs/diff checks pass. No whole-suite or shipping permission proof
is claimed. PR description reflects final verification; CodeRabbit was pending
supplemental review when normal GitHub merge succeeded without required-check override.
Writer `01a07bab-4a2b-7e53-b388-10800a2e3a6c` and initial reviewer
`01a07bf9-623b-71d2-9af1-ab70b5dc19e8` are archived, processes stopped. Delivery's
independent correction subagent `01a07c15-0a43-7c61-b720-7e7d0713e315` is complete/stopped.

[Historical C5 coordination and retained temporary inventory](archive/2026-09-07-recovery-through-c5.md)
preserves candidate/review history and exact temporary outputs. No cleanup is authorized.

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
