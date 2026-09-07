# Release Radar delivery state

## Current phase — 2026-09-07

Slice 2 recovery continues: C4 root management and C5 archive/restore are merged.
C6 remove tracking with retained history is next, followed by C7 backup/reset and
associated C12 recovery actions. The [full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capabilities; later roadmap outcomes and accepted/proposed distinctions
remain intact.

Orchestrator `01a07b81-ce26-7e70-8696-fc4427eb83a1` owns this ledger/catalog integration
in `f1ab`, branch `codex/recovery-orchestration`. Astra Medium; runtime unexposed.
Canonical checkout, retained recovery stash/exclusions/C8 app and prior dist artifacts
remain untouched. Pursuit migration is stopped; RDS appearance is unchanged.

## Authorization and C6 assignment

Existing authority covers scoped implementation, synthetic checks, commits, pushes and
PR creation. Each new PR merge requires explicit approval. C5's approval was consumed
by its merge; it does not cover C6. Installation, real owner-data lifecycle actions,
notifications, cloud/plugin changes and application catalog acceptance are not authorized.
SQLite remains exclusively app-owned; repository-only work grants no application state.

The [C6 brief](task-briefs/2026-09-07-c6-remove-tracking/c6-remove-tracking-brief.md)
is persisted/catalogued against merged C5 `c8cba4b`. Fresh task creation was dispatched
from exact committed baseline `db0b3d4`, explicit Sol High, ceiling Astra High; no Ultra.
Task `01a07cd4-149e-7a63-a3d4-fdfb81783a9d` confirmed clean baseline `db0b3d4` in
fresh worktree `d36f`, with published `codex/c6-remove-tracking` and matching upstream.
Runtime model/effort is unexposed; explicit dispatch was Sol High. The writer
owns source/tests/brief; parent owns ledger/shared metadata. One fresh independent
combined reviewer covers retention, migration, stale authority and native UI/QA.

C6 author candidate `79be22e` is integrated with five catalogued UI evidence artifacts
at `c06d34ea57262360e889eccb4aeff1bcb6f4e552`. Native documentation/diff checks pass.
Author reports removal 7/7 and the serial affected-suite selection passing. Full serial
scheme had the then-pending evidence registration and one environment-gated registered
broker transport case; no whole-suite pass is claimed. A parallel shared-temp read
transient passed on isolated retry and serial selection. No transport configuration
change is authorized.

Fresh reviewer “Review C6 removal and retained history”
(`01a07d25-5a7a-7d01-b30f-f8345a9e3b56`) confirmed clean exact `c06d34e` in isolated
`e58c`, explicit Astra High/runtime unexposed. Review covers removal authority,
historical identity, stale commands/receipts, notification outcomes, migration and
native UI/QA. [PR #30](https://github.com/joeroberts/release-radar/pull/30) is open at exact `c06d34e`;
review requests changes; separate owner merge approval remains pending. Initial writer
handoff was clean/stopped and archived; the same task is restored at Sol High for three
Required corrections:
- P1 stale `FolderProjectOnboarding.prepare` decision recreates the removed registration
  and bookmark; reject old decisions while permitting fresh explicit re-add.
- P2 removal copies current ticket phase/lane into historical events; retain unknown
  event-time context or distinctly label any current-at-removal snapshot.
- P2 removal rewrites prior archive-suppressed notification reason and loses failure/timing
  provenance; preserve terminal facts and terminalize only eligible pending work.

Corrected PR head `68a8282252608ab9c78edfa153140b8abe2f99ad` now rejects removed
historical onboarding identities, leaves unknown event phase/lane unknown, and preserves
terminal notification reason/timing. Writer reports 44/44 Removal/Onboarding plus 45/45
catalog/index tests; permanent regressions added, no UI code changed. Same Astra High
reviewer restored for only these corrections. Writer is clean/pushed/stopped and archived
pending any further Required same-outcome correction; merge approval remains pending.

Reviewer independently passed 74 focused/native checks, then reproduced these defects
with bounded synthetic tests. Same reviewer handles corrected candidate only. Latent
projectID-only goal observation callback has no shipping source caller and is Optional,
not a blocker or authorization for observer work. Reviewer stopped; temporary outputs
retained: `/tmp/c6-review-e58c-derived`, `/tmp/c6-review-e58c-tests.log`,
`/tmp/c6-review-e58c/` (repro source/bundle/logs and synthetic stores). No cleanup.


Author final counts: removal 7/7; broad selected serial 309/309. Before registration,
full scheme 606/609 (two pending-catalog cases plus disabled-broker transport case).
After registration, documentation selection 55/56: actual catalog/index/real-repository
checks pass. The remaining disposable-copy conformance test copies docs without linked
source/entitlement files and fails before its stale-index assertion. Its three links
already exist identically in merged baseline `c8cba4b`; real-repository native check
passes. No discovery document, fixture or transport configuration was altered to mask
these unrelated limits.

Author temporary paths retained: `/tmp/release-radar-c6-baseline`,
`/tmp/release-radar-c6-red`, `/tmp/release-radar-c6-evidence.5yEcMu`,
`/tmp/release-radar-c6-evidence-final.qQrH4d`, `/tmp/release-radar-c6-export.log`.
No cleanup is authorized. All durable UI evidence is committed under
`docs/delivery/evidence/`.


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
