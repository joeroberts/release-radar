# Management and recovery coordination history through C7 review

Historical and non-authoritative. This retained ledger snapshot records prior coordination
states through final C7 review. Its older pending statuses and authorization language do
not govern current work; use [current progress](../progress.md). C7 source merge had not
been approved when this snapshot was retained. Original temporary-file reports are
historical reports, not a fresh filesystem inventory; the original untracked C7 reproducer
was later found absent, as recorded below.

# Retained ledger snapshot

## Current phase — 2026-09-07

Slice 2 recovery continues: C4 root management, C5 archive/restore and C6 removal
with retained history are merged. C7 backup/reset recovery and associated C12 actions
have passed final independent corrective review and await owner-approved PR #31 merge. The [full-product plan](../plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capabilities; later roadmap outcomes and accepted/proposed distinctions
remain intact.

Fresh orchestrator `01a07e22-3d02-7cb1-a6e3-b4f274dea577` owns ledger/catalog integration
in `44e0`, branch `codex/management-recovery-20260907-44e0`, from fetched merged
`df7157b`. Dispatch specifies Astra Medium; runtime settings are unexposed. The execution
goal covers all C4–C7 and associated C12 through owner-approved merges, without a token
budget. The retired orchestration handoff at `def4ebd` is preserved in Git.
Canonical checkout, retained recovery stash/exclusions/C8 app and prior dist artifacts
remain untouched. Pursuit migration is stopped; RDS appearance is unchanged.

## Current authorization

Existing authority covers scoped implementation, synthetic checks, commits, pushes and
PR creation. Each new PR merge requires separate owner approval. C6 approval was used
for PR #30 only. No installation, owner backup/reset/restore/removal, real notifications,
cloud/plugin mutation or application catalog acceptance is authorized. SQLite remains
exclusively app-owned. Canonical checkout/application state is preserved.

The [C7 brief](../task-briefs/2026-09-07-c7-backup-reset-recovery/c7-backup-reset-recovery-brief.md)
starts from merged C6 `df7157b`. Fresh read-only consultation “Resolve C7 coordinated
recovery boundaries” (`01a07d4b-28f0-7bf0-aa64-810d1e389e2f`) confirmed clean isolated
`f1e8` at `3503793`, explicit Astra High/ceiling High, runtime unexposed. It completed the current-source handoff with no policy ambiguity, changes, tests,
temporary artifacts or running processes, and is archived. The existing brief now
records exact reset contents, app/bridge close-and-drain, rollback/crash startup,
request-incarnation invalidation, historical retention, notification nonreplay and
mutation-free plugin inspection. Fresh Sol High delivery creation was dispatched from exact `872fb3e`, requested branch
`codex/c7-backup-reset-recovery`, with full coupled C7 ownership through backup/reopen,
reset-retention and Settings/health checkpoints. Task `01a07d52-bff1-7042-9483-92e9e42e340a` confirmed clean exact `872fb3e` in
fresh `89ef` worktree with published branch/upstream. Its session metadata exposes
`gpt-5.6-sol` and `reasoning_effort: high`, matching dispatch; no Ultra or subagents.

[PR #31](https://github.com/joeroberts/release-radar/pull/31) is open at integrated
`48903b6166ef3468272f400e5ea6786425e7e0d9`; actual original product commit is
`9df32a66b2a3f1d4ce2f4e04a6e41dc21bc4fc95` (an initial handoff full-SHA typo was
corrected by branch/PR readback). Evidence-only `c075ba6` flattened seven PNGs into
existing delivery.evidence; parent registered eight artifacts/generated index. Native
catalog/docs and diff checks pass. Author reports 76/76 bounded tests and integrated
Debug build plus wide/compact visual checks; no whole-suite or owner-state claim.

Fresh combined reviewer “Review C7 backup reset and recovery”
(`01a07da3-6b87-7623-ae69-9b59a9398a4d`) confirmed isolated `3c78` clean at exact
`48903b6`, explicit Astra High/ceiling High, runtime unexposed. It covers complete
backup/reset/recovery, stale authority, retained facts/nonreplay, rollback/containment,
mutation-free plugin inspection and native UI/QA. Review and C7 merge approval pending.
Initial writer handoff was clean/stopped and archived. Review now requests eight Required
corrections; the same writer is restored at explicit Sol High:
1. Crash between original rename and marker update can create an empty store; preserve
   originals through every cutpoint, including unreadable rollback material.
2. Restore accepts stale displaced-registration previews; revalidate after quiesce and
   identify restored/displaced targets in confirmation.
3. Restored occurrence/observation state can resend a previously sent blocked alert.
4. OwnerApp bypasses recovery identity; capture/enforce prepared owner-action identity.
5. Newer live-project audit/activity/assignment facts are lost during reconciliation.
6. Ordinary unavailable-store health lacks exact target and Restore action.
7. Signed user-selected read-only authority plus sibling staging cannot support backup
   save; writer prepares a narrow destination/entitlement proposal before any sandbox
   boundary change, while independent fixes proceed. Concrete owner approval requested:
   replace only app `user-selected.read-only` with `user-selected.read-write`, keeping
   other entitlements unchanged; select one existing folder and confine backup/staging
   inside its temporary scope. No broad/persistent grants. Signed synthetic picker
   verification outside the app container is proposed; no owner data or installation.
   Owner explicitly authorized this exact R7 change on 2026-09-07; it is now assigned
   to the same C7 writer at actual requested Sol High. This is not merge approval.
8. Successful crash-marker recovery falls into automatic plugin update instead of
   read-only recovery initialization.

Writer checkpoint `c8f282ed4ed6b8932c28005fe3ae562810be7569` is pushed and clean.
R1/R2/R3/R4/R5/R6/R8 report green: 18/18 recovery plus 24/24 affected integration cases;
independent correction review remains outstanding. Owner explicitly resumed the same C7
writer at Sol High for R7: replace only the shipping user-selected read-only entitlement
with read-write=true, keep every other entitlement unchanged, select one existing folder
with a single-selection directories-only picker, confine generated backup and staging
inside it, and balance temporary security scope without persistent grants. Verify the
signed app's real entitlements and picker with an isolated synthetic store and a fresh
folder outside its container. The R7 candidate is now available for corrective review.
No installation, owner-data operations, credential changes, real notifications, plugin
mutations or cloud changes are authorized. The same independent reviewer will assess
remaining corrections at Astra High after the final candidate is pushed. PR #31 was
freshly verified OPEN at `c8f282e`; PRs #28–#30 are MERGED. No C7 source is accepted yet.

R7 is pushed at `587701b1e91c8e4fd51888349eaaa9321542d6be`. The writer reports 19/19
focused tests passed, a native single-folder picker test generated and validated a backup
inside a fresh external synthetic folder without leftover staging, and a Release build with
strict deep signing verification. Actual Release entitlements have the authorized read-write
selection, unchanged sandbox/app-group/network scope, generated get-task-allow and no broad
filesystem exception. The XCTest host has injected read-only `/` and test-manager exceptions;
its picker/write evidence does not by itself settle the exact shipping-boundary requirement.
Independent correction review must assess that remaining verification limitation.

The same writer's scope is now complete through candidate handoff; its worktree is clean,
branch pushed, and it reports all owned C7-R7 app processes stopped. Independent corrective review of `ab53f1ba748351785f126309cc2281adaefa8ff1` completed:
12 committed focused correction tests passed; two negative cases reproduced Required P1
defects. R1 crash-resume `replacementInstalled` cleanup loses unreadable original rollback;
R5 reconciliation drops displaced registration/history when that project was absent from
the selected backup. R2/R3/R4/R6/R8 selected checks pass. R7 source conforms, but exact
shipping-permission picker proof remains Required. Evidence must distinguish known synthetic
results from unknown normal-launch effects and accurately state selected test counts.
The reviewer is stopped/archived; its old untracked reproducer was already absent before
checkout recovery. New temporary `3c78/ReleaseRadarTests/C7CorrectiveReviewTests.swift`
and `/tmp/c7-corrective-review-01a07da3/` are retained, with old `/tmp` evidence.
The same writer is restored at explicit Sol High from `ab53f1b` for only these corrections,
evidence accuracy and bounded R7 verification. Native launches require a source-proven
synthetic initialization/termination route without broad filesystem exceptions; no new
normal-app launch, harness, owner-state inspection or credential use is authorized.
Final corrective candidate `19a428488a6ad73cffd09bec2dbd36be084f31e5` is pushed.
Both R1/R5 regressions failed before correction and pass afterward; the complete directly
affected RecoveryAcceptanceTests passed 20/20. New markers retain explicit unreadable-original
policy; legacy crash markers preserve invalid rollback material. Displaced registration/history
is preserved even when that project was absent from the selected backup. Evidence wording
and run-selection counts are corrected.
The existing synthetic host was re-signed from production filesystem entitlements with only
required XCTest runtime exceptions. Strict signature verification and actual entitlement
readback before and after launch show no broad filesystem exception. Its single native picker
check selected `/Users/Shared/ReleaseRadar-C7-SignedPicker-Corrective.Po4gPJ`, created and
validated one backup there, left no staging, and exited. The XCTest termination guard returns
before shared-service initialization. No retry or normal launch was used for this check.
The writer and final reviewer are terminal/stopped and archived. Final independent Astra High
review passed at `7dd9763811876fa33535e33ff3375cba2add21a1` with no remaining Required findings.
Four focused regressions passed independently (zero skipped); the reviewer directly read the
20/20 recovery result, verified the retained signed host and its actual no-broad-filesystem
entitlements, and inspected the existing native picker command/actions/package readback.
R1/R5/R7 and the minimal termination guard are closed; prior unrelated successful checks stand.
Native documentation/diff checks pass. Product merge approval remains outstanding.
Final reviewer temporary outputs: `/tmp/c7-final-review-01a07da3/` and synthetic XCTest host
directories `ReleaseRadar-XCTestHost-51125`/`-56288` beneath app-container Data/tmp, alongside
the earlier retained reviewer source/output inventory. No cleanup is authorized.

No merge approval has been requested or given. Final phase acceptance remains outstanding.

Verification incidents remain disclosed in the [C7 evidence](../evidence/2026-09-07-c7-backup-reset-recovery.md).
A CUA attempt launched the test-built app normally; only that new PID 48085 was stopped.
Default-service initialization and resulting owner-state effects are unverified. A later
`xcrun xctest -h` printed inherited credentials in the writer transcript. The owner was told
Jira and Pushover credentials should be rotated. No values are retained in repository docs;
no credential use/change or owner-state inspection/repair is authorized. No further
exploratory runtime launches were authorized for that writer.

Retained R7 temporary artifacts: writer `build/c7-r7`, `build/c7-r7-final-tests`,
`build/c7-r7-native`, `build/c7-r7-native-host`, `build/c7-r7-release`, and external synthetic
`/Users/Shared/ReleaseRadar-C7-SignedPicker.QVvAJK` with generated package. No cleanup authorized.

Six failures were reproduced synthetically; destination/signing and recovery-mode issues
are source-backed. Eighteen existing selected/native tests passed. Same reviewer stopped
and archived for the candidate; only affected corrections will be reviewed on return.
No additional reviewer, owner-state action or silent sandbox modification is authorized.
Temporary reviewer source remains in `3c78/release_radar/ReleaseRadarTests/`
`C7IndependentReviewTests.swift`; `/tmp/c7-independent-review-01a07da3/` retains build
output, three result bundles and logs. All review processes exited; no cleanup authorized.

All durable [C7 evidence](../evidence/2026-09-07-c7-backup-reset-recovery.md) is committed.
Temporary ignored build directories under writer worktree `89ef/release_radar/build/`
remain: `c7-build-final`, `c7-contracts`, `c7-recovery-final`, `c7-recovery-final2`,
`c7-red-1`, `c7-red-2`, `c7-services`, `c7-services-2`, `c7-store`, `c7-ui`,
`c7-ui-final`, `c7-verification`. No cleanup authorized.
 The full approved C7 outcome remains included;
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
stopped/archived. [C6 UI evidence](../evidence/2026-09-07-c6-remove-tracking-ui.md) is committed
and catalogued; [Historical handoff/temp inventory](../archive/2026-09-07-c6-delivery-history.md)
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
[UI evidence](../evidence/2026-09-07-c5-archive-restore-ui.md) and its five catalog entries
are current. Native docs/diff checks pass. No whole-suite or shipping permission proof
is claimed. PR description reflects final verification; CodeRabbit was pending
supplemental review when normal GitHub merge succeeded without required-check override.
Writer `01a07bab-4a2b-7e53-b388-10800a2e3a6c` and initial reviewer
`01a07bf9-623b-71d2-9af1-ab70b5dc19e8` are archived, processes stopped. Delivery's
independent correction subagent `01a07c15-0a43-7c61-b720-7e7d0713e315` is complete/stopped.

[Historical C5 coordination and retained temporary inventory](../archive/2026-09-07-recovery-through-c5.md)
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
CodeRabbit passed. See [C4 brief/evidence](../task-briefs/2026-09-07-c4-root-management/c4-root-management-brief.md).
XCTest injects read-only `/`; containment/injected-denial tests do not prove real
NSOpenPanel grants under shipping entitlements. The owner approved source merge with
this limitation disclosed. No installation or owner-state acceptance is claimed.
Writer `01a07b7a-f30a-7373-99ba-709e4f9c6a69` and reviewer
`01a07ba1-5d2b-7921-8e72-558438f15167` are stopped/archived.

## Completed parallel discovery

All four bounded discovery writers and reviewers are stopped/archived. Their
artifacts contain the original briefs, source-backed findings and limitations.

- [Run ownership](../task-briefs/2026-09-07-parallel-discovery/run-ownership-discovery.md):
  PR #25 merged with owner approval as `7e38fb8`; independent review passed. Conditional
  pursuit of a synthetic first-provider proof is proposed, not authorized. Production
  execution/control of existing desktop runs remains no-go without proof.
- [Rules/hooks](../task-briefs/2026-09-07-parallel-discovery/rules-hooks-discovery.md):
  PR #24 merged with owner approval as `fb57804`; corrected `c71d880` passed review.
  No-go for enabling active controls today; authorization-aware enforcement, safe Stop
  state and hook privacy/trust remain unproven. No configuration pilot is authorized.
- [Live observation](../task-briefs/2026-09-07-parallel-discovery/live-observation-discovery.md):
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

[Historical recovery record](../archive/2026-09-07-recovery-through-c4-and-parallel-discoveries.md)
preserves retired task/branch facts, complete bounded assignment IDs, review results,
prior lifecycle acceptance and temporary-path inventories. Retained temporary C4
builds/fixtures/logs/attachments/test-host outputs and rules-discovery `pilot.rules`/
`pr-body.md` remain as inventoried there and in the C4 brief. No cleanup is authorized
or performed. Prior broad-suite574/576 is historical, not a current whole-suite pass.
