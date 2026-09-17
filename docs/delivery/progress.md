# Release Radar delivery state

## Current outcome

**Outcome 3 — package promotion P1 cleared; source candidate ready for scoped local commit; complete acceptance open.**
Main confirmed the registration/root and removal/re-add recovery commit
`58d86bf05dac2456f7e52b0b325964b1fbdc0d13` on the assigned branch/worktree.
Corrected checkpoint 16 passed the app build, all 51 affected tests and
documentation/index/diff checks; checkpoint 17 passed the app build, all 14
producer tests and documentation/index/diff checks. Fresh reviewer `01a0ad8a`
cleared its sole Required P2 after the bounded historical-retirement correction,
with no remaining Required or Optional findings. Those checks/reviews and prior
hook/cleanup/R1–R4 validation remain terminal for unchanged behavior.

Main released this same Sol/high worker from `58d86bf` for source package preparation:
concise prepare/start/stop/recovery guidance in the existing shipping skill,
coordinator presence/identifier/hardened-runtime/approved-group checks in the existing
packaging verifier, and exact app/plugin version 0.1.19 with its normalized digest.
BuildAgent confirmed only local availability: tags through v0.1.18 exist and
v0.1.19 is absent. Published 0.1.18 recognition remains unchanged. There is one native
plugin and no helper authority expansion. BuildAgent computed the frozen 0.1.19 package digest using the unchanged native
`PluginDigester.marketplacePackage(at:)` at the assigned source root (exit 0):
`6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35`.
The exact pair is registered for standard 1; acceptance assertions compare app/plugin
version, core/helper digest agreement and recognized capability and preserve the
published 0.1.18 pair while rejecting crossed version/digest pairs. Tests preceded
the recognition change; no native red run is claimed. The entire source/tests/docs
candidate remains frozen for fresh scoped independent review through Main→RO04.
Main/BuildAgent checkpoint 18 passed the app build and all 36 affected tests:
lifecycle acceptance 26, package 2, compatibility 6 and skill contract 2.
Packaging-script `bash -n`, documentation and diff checks passed. The test-built
coordinator passed strict signature and hardened-runtime checks, but its identifier
was `ReleaseRadarCoordinator` and its entitlements included XCTest-injected rights.
That is not exact production identity/entitlement evidence and establishes neither
a production defect nor a production identity pass. Reviewer `01a0af6d` found one
Required P1: promotion verifies both the new candidate and prior destination, so
unconditionally requiring a coordinator also rejects valid older destinations.
There were no other Required findings; published 0.1.18 recognition and guidance
review are terminal. Main released only this packaging-verifier correction.
Verification now defaults to candidate role and requires exact version 0.1.19 plus
all strict coordinator checks. Only the existing pre-promotion destination call
uses prior-destination role: supported versions 0.1.7–0.1.18 may omit the coordinator,
while every existing app/bridge/signature/runtime/entitlement check remains.
Prior 0.1.19 and any present coordinator retain strict coordinator verification;
unknown destination versions/roles are refused. Promoted candidates remain strict.
BuildAgent passed packaging-script `bash -n`, documentation/diff checks and all 13
bounded verifier/promotion fixture cases using the actual function bodies, stubbed
codesign and real filesystem/plist operations. The strict new-candidate/legacy-prior
distinction is verified; these fixtures are expressly not production signature proof.
The same reviewer cleared P1 with no remaining Required or Optional findings;
correction checks/review are terminal. Source remains frozen and ready for
Main→BuildAgent's scoped local commit; no new commit or real install is claimed.
Temporary `build/promotion-p1-fixtures` remains retained and excluded; cleanup is
not authorized. The shipping
package bytes and registered digest remain unchanged, so checkpoint 18's app/package
test results remain terminal for unchanged behavior. No native red run is claimed.

Onboarding authority carries only existing registered work scope; no repeated
per-worker consent is introduced, and genuine runtime approval gates remain.
Lost configuration handles permit safe replacement only after proven old worker
closure and exact owned resource cleanup. Abrupt coordinator process loss without
a retained worker handle or proof of exit remains an unresolved recovery barrier;
no universal reconnect/cleanup claim is made. Runtime/UI acceptance, actual production
sandbox/bookmark/executable boundaries, portability and application catalog acceptance
remain open. The source release identity is not installation or full Outcome 3
acceptance. No live app/configuration, bookmark grant, SQLite/catalog acceptance,
tag, packaging run, installation, release or external mutation is authorized in
this slice. Main owns native checks and trusted Git.

Source/tests/docs are durable repository inputs. Existing temporary reference plugin,
stopped fixture and native build/check outputs remain retained and excluded; no deletion
is authorized. No new temporary artifact was created for this preparation.

**Prior cleanup checkpoint — committed as `f0866b7`; terminal checks and review.**
Main/BuildAgent checkpoint 15 passed the app build, 16 of 17 selected tests and
documentation/diff checks; native processes exited. Worktree 4 (including actual
ignored-content preservation), assignment 5 and producer 7 of 8 passed. The sole
same-connection regression observed close counts 2 versus expected 1, then 3 versus
expected 2. Source diagnosis found its producer shared the retirement configuration
fixture; the producer's rejected preparation calls its own finish operation, adding
a close to the shared fixture. Production factories allocate separate clients.
The bounded test correction separates those clients, retains the original one/two
close expectations and additionally asserts typed replacement conflict and the
producer's independent finish call. No production source or behavior changed.
Main/BuildAgent's fixture-corrected checkpoint 15 passed all eight producer tests
and documentation/diff checks. The prior app build, worktree 4 and assignment 5
passes remain valid and terminal absent a defect; no production change was made
for the fixture correction. The cleanup review gate is cleared; reviewer
`01a0ad5f-6db0-7ed0-bde6-0f274bb35353` returned PASS with no remaining Required
or Optional findings in either correction. App build, all 17 affected tests after
fixture correction, and documentation/diff checks passed. This validation is terminal.
Main→BuildAgent subsequently committed this checkpoint as `f0866b7`; its prior
source freeze is released only for the active bounded recovery slice above.
Runtime/UI and application catalog acceptance remain open; this does not complete
Outcome 3. The recorded checkpoint introduced no live mutation.
Main/BuildAgent checkpoint 14 passed the app build, all 23 selected tests and
documentation/diff checks; native processes exited. The same hook reviewer found
no remaining Required or Optional issues. Hook P1 and R1–R4 validation are terminal.
Cleanup reviewer `01a0ad5f-6db0-7ed0-bde6-0f274bb35353` identified two Required
findings: default cleanliness could omit ignored owner files before pruning (P1),
and retirement became complete before configuration connection closure (P2).
The bounded fixes explicitly include ignored content in retirement status checks
and defer superseded/completed until confirmed close. A protected outstanding-close
marker keeps the exact request visible and blocks replacement. AppModel retains the
same lifecycle/client; only an explicit matching request retries its held connection.
A new client without the original handle refuses completion. Native ignored-content
preservation and close failure/same-handle retry regressions preceded these fixes;
no initial native red run is claimed. Checkpoint 15 and its bounded fixture correction
are recorded above. Main owns affected
native checks, scoped commit and the same cleanup reviewer’s correction route.
No live state/configuration/install or external action is released; temporary material
remains retained and excluded from staging.

**Prior hook correction — direct checks and independent correction review passed.**
Independent hook reviewer `01a0ad4c-9745-70d2-9366-153d4d6500c6` found a Required
P1 on `c1968a4`: registration could change during configuration/trust reads before
stale writes or an installed receipt. The bounded correction carries the exact
current registration/root validator and pinned protected policy to inline hook edits,
project trust and exact hook-hash trust writes, after intervening reads/connection
initialization, and rechecks before installed/removal receipts. Three new regressions
change/revoke registration during suspended trust discovery, inline removal and
readiness readback. These tests preceded the bounded core correction; no initial
native red run is claimed. Checkpoint 14 and terminal review are recorded above. Protocol witnesses/read-only
producer calls receive only the required signature adaptation. Cleanup source and
UI behavior remain frozen for their separate independent review; R1–R4 stay closed.
Main/BuildAgent own the app build, affected tests and documentation/diff checks,
scoped commit and same hook review correction route. No live action is released.

**Prior lifecycle checkpoint — direct checks passed; cleanup behavior frozen for independent review.**
Committed correction candidate `c1968a4dd99ad27f772fd9fd238abb325c74c350`
passed the app build, all 34 focused tests, documentation/index and diff checks.
The independent R1–R4 correction review has no remaining Required findings; that
validation is terminal. Independent review of its new hook source is separately
pending and does not establish runtime permission or UI acceptance.

The next bounded source slice implements owner-selected resource retirement and
explicit workflow restoration in existing project settings. It requires the exact
registered snapshot and confirmed runtime closure (or a never-launched assignment),
preserves dirty/untracked work and referenced candidates, prunes only the exact
owned worktree while retaining its committed branch, and removes only the matching
owned permission profile with versioned configuration/readback. Protected retirement
receipts retain exact request identity, prior state and completed steps for retry.
An explicit completed retirement permits replacement preparation, preserves unknown
outcome history and never admits the old worker. Explicit workflow restoration keeps
policy disabled until its unchanged owned hook is restored/trusted, refuses conflicts,
and leaves stopped/unknown assignments blocked. No automatic resume is added.
Main/BuildAgent checkpoint 13 passed the app build and all 50 selected tests: setup
13, producer 7, profile 2, worktree 3, assignment 5, adapter 12, lifecycle 4 and execution
routes 4. Documentation/index and diff checks passed; BuildAgent regenerated only
the task-brief index. These results establish the selected native behaviors, not
production permission boundaries or UI acceptance. Product source remains frozen
for the fresh independent cleanup review through RO04 and Main's scoped commit route.
This update records verified results only; no new source or live action is released.
Independent architecture/security/code and UX/QA coverage remains required. Actual app/
worker boundaries, running UI comparison and coordinated package identity remain open.
Registration/root replacement or re-add recovery remains separately unresolved;
this slice deliberately refuses stale identities rather than rebinding old authority.
Application catalog acceptance and every live configuration/data/install/external
action remain excluded. Durable source/tests/docs remain repository inputs; temporary
reference plugin, stopped fixture and native outputs remain retained and excluded from
staging, with no deletion authorized.

**Prior correction checkpoint — committed direct evidence.**
First scoped commit `ffdd65601bd36852b801d79a2061a68f4c7548cc` is unaccepted;
its fresh independent review returned four Required findings. This bounded correction
candidate keeps preparation non-admissible until the final app current-work check,
revokes failed finalization with exact-request recovery, revokes stale startup
reservations without losing uncertainty barriers, permits independent STOP/physical
cleanup of known uncertain runs, and reserves follow-up operations before awaited
readiness. It also adds owner-only update/removal controls in existing project settings,
exact registration/root audit checks, conflict-preserving hook edits, and disabled-policy
removal receipts. Removal retains the admission hook when worker cleanup is unresolved.
Main/BuildAgent checkpoint 12 initially failed compilation on a missing `await`;
no tests ran. After the same worker corrected that call, the app dependency build
and all 34 focused tests passed: setup 10, adapter 12, producer 4, lifecycle 4 and
execution routes 4. The installed documentation checker passed after regenerating
the stale task-brief index; diff checks passed. These results apply to the frozen
working-tree correction candidate based on `ffdd656`, using `xcodebuild` and the
repository-native test filters. Temporary results remain in
`build/execution-review-corrections-12-corrected.log` and its `.xcresult` bundle;
this ledger retains the durable result. Main authorized the scoped local candidate
commit `c1968a4dd99ad27f772fd9fd238abb325c74c350`; correction review and current slice are recorded above. This checkpoint does not complete Outcome 3. Actual app/worker
permission boundaries, running responsive/accessibility UI QA, remaining owned profile/
worktree lifecycle and explicit owner recovery, and coordinated package identity remain
open. No live configuration, installation, application acceptance or external action is
released. Temporary reference plugin, stopped fixture and native build outputs remain
retained and excluded from staging; no deletion is authorized.

**September 16 — Outcome 3 execution setup implementation is authorized and in progress.** The
owner explicitly authorized the assigned worker’s onboarding/plugin implementation,
including production hook integration, on `codex/outcome3-execution-setup` at
Main/BuildAgent-verified clean baseline `805d210784e0004220d4d1f903fb6edac42e14ba`.
The [controlling implementation brief](task-briefs/2026-09-16-outcome3-execution-setup/brief.md)
records complete scope, exclusions, checks and review. Worker
`01a0acb5-bc87-72b3-a06e-8821cb18bfc9` exclusively owns this delivery’s ledger/catalog.
First checkpoint is exact package recognition, native provisioning boundary and
protected assignments with focused failure/retry behavior. Installed skill reads
are denied; repository-local fallbacks apply. Named permission label is unexposed;
Main confirmed effective restrictions and actual Sol/high. Git/native checks and
documentation history traversal use Main’s trusted route. No live configuration,
trust/profile/install, SQLite/application acceptance, release, push/PR, merge or
main mutation is released. Source implementation, direct checks, independent
RO04 review and trusted scoped local commit are authorized. Catalog changes are
pending application acceptance. Main/BuildAgent passed seven assignment/hook tests
and eight protected-store/onboarding-retry/readiness/adapter tests. The initial
missing-type baseline was not run. Offline arm64 libgit2 preparation and the native
app build passed. The corrected in-process collision fixture passed. Clean-worktree
removal exposed a missing libgit2 PRUNE_VALID flag; the bounded correction passed.
The initial isolated signed App Server test timed out with unknown RPC outcome;
its Xcode-injected root-read/test-manager entitlements are not production-equivalent
sandbox evidence. The corrected failed worktree case, four affected adapter tests
and hosted real transport initialize/hooks-list/close check passed six of six;
no extra test process remained. Prior unchanged checks are terminal. Main authorized
one actual-source fixture with exact existing app entitlements. It compiled and
passed signature/entitlement checks, then trapped in sandbox initialization before
main; it invoked no App Server and created no fixture home. Main stopped that
unsuitable bare-executable approach. This is not evidence that the actual app's
configuration API is incompatible. Package checkpoint 7 passed 22 of 26 cases;
the four failed cases included a new fixture-inventory defect, the frozen published
package digest, and stale version/registry expectations. The fixture defect was corrected; checkpoint 8
passed both package tests. App/package release metadata remains unchanged, and the
new candidate digest is intentionally unregistered pending coordinated delivery.
Checkpoint 9 app dependency build passed and all 16 focused setup/store/readiness/
onboarding/hook checks passed. Source freeze is released. The new setup actor
preceded its tests; no initial red native run is claimed. Main resolved the redundant
producer-choice gate: existing explicit onboarding/workflow direction authorizes
app-owned bounded assignment production without repeated per-worker consent.
Producer, hook-layout and profile wiring continue under the same scope. Actual app sandbox/external bookmark access, complete
integration, running UI QA and independent review remain unverified.

Corrected checkpoint 10 app build and 26 checks passed; after correcting a new
fixture's nonexistent bookmark `id` column, lifecycle retesting passed all three
cases. No production schema change was made. The
unexposed producer selects review from a known closed delivery assignment's exact
clean commit. Relevant SQL mutations conservatively revoke obsolete assignments
before COMMIT; rollback does not reauthorize, and failed revocation blocks mutation.
Connection loss persists unknown and late completion cannot create a review candidate.
The first coherent source candidate now includes production observer/preparer wiring
and a strict bounded AgentTools route. After the explicit Sendable fixture correction,
checkpoint 11 passed the app dependency build and all 29 selected tests: public route 2,
callback/schema 2, construction observer 1, bridge schema 2, and recovery 22.
Repository documentation and diff checks passed. Main authorized a scoped local
candidate commit to enable a fresh independent review worktree; the candidate is
unaccepted; its subsequent independent review and correction status are recorded above. No push, installation or release is authorized. New producer and
lifecycle source preceded its tests; no initial red run is claimed. Outcome 3 remains
open for actual app/worker boundary verification, UI QA, owned update/removal and
coordinated package release identity. Copied Python reference material and the
stopped bare fixture are temporary and excluded from the source candidate; retained
dependency source/license/pin and offline integration are durable inputs.

**September 16 — historical Superpowers archive.** Owner authorized preserving
14 ignored Markdown records directly in `docs/delivery/archive/`, named
`superpowers_<original-folder>_<filename>`. Copies retain the original bytes;
new catalog identities classify them as archived/non-authoritative. The
[archive index](archive/README.md#superpowers-records-preserved-september-16)
records provenance. After verifying all 14 committed copies in `2286c53` against their source bytes,
Main removed exactly those original Markdown files. The ignored
`.superpowers/sdd/.gitignore` remains outside this move.
Independent metadata/disposition review passed with no Required findings
(task `01a0aca2-2d99-71c1-bb20-ddad18d06d91`); Main directly verified bytes.
Documentation and scoped metadata diff checks passed. This does not reopen the
historical assignments or complete Outcome 3.
The app's pre-change readback reported `catalogUnaccepted` for the canonical
checkout. Repository catalog checks and application catalog acceptance are
separate; no application synchronization or evidence mutation is claimed.



**September 16 — Outcome 3 remains open: onboarding/worktree integration plan.**
The owner approved documenting deterministic project execution setup during
onboarding, RR-owned project/task worktrees, per-worker checkout scope, and use of
the existing RR plugin installation pattern. See the
[bounded contract and implementation sequence](../design/outcome3-runtime-enforcement-assessment.md#september-16-onboarding-and-worktree-integration-contract).
Main prepared this documentation under a one-time owner exception after Restricted
coordinator 02 reported provisioning denied. Source baseline is c8dd3c2 on
codex/outcome3-onboarding-worktree-contract. The separately reviewed standalone plugin
is a component result, not Outcome 3 completion. Packaging identity and RR provisioning ownership are selected below; implementation
compatibility and sandboxed API access remain to be established.
**Owner clarification: hooks remain in Outcome 3.** RR must configure hooks
deterministically for each onboarded project, including assigned-worktree behavior
and lifecycle/recovery while preserving unrelated hooks. The native pilot is
complete; product hook integration is not established as complete. Next reconcile
the original requirements and validate the configuration contract against official
documentation and existing code; persist it in the
[same onboarding plan](../design/outcome3-runtime-enforcement-assessment.md#owner-clarification-project-hook-configuration-remains-in-outcome-3).
The [packaging/provisioning follow-up](../design/outcome3-runtime-enforcement-assessment.md#packaging-and-provisioning-decision--september-16-follow-up)
selects the existing single plugin, project-local hook registration and native RR
onboarding ownership, preserving the fixed installer helper. In-process libgit2 is recommended for Git provisioning, subject to dependency
review. The [admission/trust disposition](../design/outcome3-runtime-enforcement-assessment.md#admission-rule-and-trust-disposition--september-16)
now defines assignment-based admission and STOP/recovery. The
[verified worktree-trust correction](../design/outcome3-runtime-enforcement-assessment.md#verified-hook-trust-across-linked-worktrees--september-16)
supersedes the earlier claimed automatic-trust gap: installed desktop Trust uses
config/batchWrite on hooks.state, and one isolated approval carried across two
existing linked worktrees and one created afterward. Only the primary repository
had a project trust entry; every checkout resolved its same hook key/hash/source.
RR should register once at the primary repository and apply/read back only its
verified definition under onboarding consent. The proposed mandatory Codex UI
handoff is withdrawn. This is installed-version evidence, not completed RR
integration or universal compatibility. Independent correction review
`01a0ac06-941c-7ec1-8c19-89cdf89e3172` (Sol/high, rr-project-ro) passed with
no Required findings. Documentation and diff checks passed.
The following earlier reviews predate and do not establish this correction.
Admission/trust review `01a0abf8-4099-76f3-bdf6-a5e823e854fc` (Sol/high,
rr-project-ro) passed with no Required or Optional findings and is archived. It reviewed repository
sources and attributed official-source/schema findings; Main inspected those
sources directly. Documentation and diff checks passed. The follow-up received independent PASS with no Required findings from
`01a0abf3-7ace-7a22-a2b2-e04a8bba7679` (Sol/high, rr-project-ro); source-fetch
limitation is recorded in the assessment. Reviewer archived. Documentation/diff checks passed.
Main used the existing bounded documentation exception after RO04 could not target
the assigned checkout. No product/configuration changes or commits were made.
Independent read-only review by task `01a0abd1-ea2a-7231-a9fb-8766329cb6b3`
passed with no Required findings and is archived. Repository documentation and diff checks passed;
catalog metadata and generated indexes are unchanged. No product code, profiles,
installed plugins, existing worktrees, app data or accepted ADRs are changed.

The signed-helper verification fix and 0.1.18 Git delivery are complete through
[PR #70](https://github.com/joeroberts/release-radar/pull/70), merged into `main`
at `f7e07b88296f7ef24747f4bb7bff66ee5d6f4ba8` from PR head
`25aa1857f40906e34192d30dc84554d7339ce23`.
Source security review passed `a30cfea04944e84559c208b4961dca1e57079c9e`;
independent package/version review passed exact artifact
`4ebbf754c316ccf33e8a81a8b77f89f61a64fe1f`, both with no findings.
Published annotated `v0.1.18` remains on that reviewed artifact; the later
publication-record commit does not rebuild it. Twelve reader tests, same-entitlement
signed real-home boundary proof, fresh Release/signatures/metadata, isolated signed
0.1.18 reader and mounted DMG/Downloads checks passed. See
[0.1.18 evidence](evidence/2026-09-15-release-0.1.18-packaging.md) and the
[completed brief](task-briefs/2026-09-15-plugin-verification-sandbox-fix/brief.md).
**Installation remains on hold.** The owner reports that 0.1.18 fixed the plugin
failure; this closeout does not claim agent-observed live upgrade, reinstall, or
recovery. Main owns installation coordination; BuildAgent has finished this
assignment. The source writer and both completed source/package reviewers are
archived with their results preserved.

The owner merged [PR #59](https://github.com/joeroberts/release-radar/pull/59) into
`main` at `2f73623`, [PR #60](https://github.com/joeroberts/release-radar/pull/60)
into the Outcome 2 branch at `ac6c440`, [PR #61](https://github.com/joeroberts/release-radar/pull/61)
into the V1 branch at `7defed8`, and corrective [PR #62](https://github.com/joeroberts/release-radar/pull/62)
into `main` at historical integration `f4e77542`. Outcome 2 specifications, Shared
Execution V1 guidance, and the Outcome 3 assessment are integrated into remote
`main`. The [preserved assessment](../design/outcome3-runtime-enforcement-assessment.md)
records the remaining native attachment, pre-turn admission, and persistent
all-tool enforcement gaps. The assessment’s original runtime boundary remains attributed; the September 16
onboarding/plugin implementation is now released under the brief above.

Main is the sole delegator to the standing Restricted and RO04 coordinators.
Restricted provisions named branches and worktrees, then launches read-write
`rr-project-restricted` workers. RO04 launches `rr-project-ro` independent reviewers
only against candidates and roots assigned by Main. Neither coordinator merges
`main`; all work uses a named branch.

The documentation corrections are integrated through
[PR #63](https://github.com/joeroberts/release-radar/pull/63) and
[PR #64](https://github.com/joeroberts/release-radar/pull/64). The installed-cache
containment security fix is merged through
[PR #65](https://github.com/joeroberts/release-radar/pull/65), release baseline
`89dfc85ad330a30a2ae48d09c7e5252a44ac5111`. Main reported its independent review
and focused native containment tests complete. This restores the helper-local
cache boundary; it does not implement the separate Outcome 3 runtime-enforcement
assessment. Canonical-main state and unrelated work are outside this writer's
ownership and were not changed.

Release metadata **0.1.17 (1)** was recorded by [PR #66](https://github.com/joeroberts/release-radar/pull/66)
at `ef012b68`. [PR #67](https://github.com/joeroberts/release-radar/pull/67) merged
the corrected release record at `7172df9`; its durable evidence is
`62fa8d0`. The owner-authorized 0.1.17 packaging and Git-distribution outcome is
complete through [PR #69](https://github.com/joeroberts/release-radar/pull/69),
merged at `328f2737`. The signed DMG and matching Downloads copy passed direct
verification and independent RO04 review. Published annotated tag `v0.1.17`
points to reviewed artifact commit `430e891244cef931bdc55293fa6d6967b1c0570e`;
publication-record follow-ups do not rebuild the artifact. **Installation remains
on hold**; last verified installed version is **0.1.17 (1)**. The
[package evidence](evidence/2026-09-15-release-0.1.17-packaging.md) records source
provenance, package identity, checks, review and publication. Main retains
installation coordination; BuildAgent's 0.1.18 assignment is complete.

Outcome 1 operative-authority reconciliation is complete. The
[completed brief](task-briefs/2026-09-13-operative-authority-reconciliation/operative-authority-reconciliation-brief.md)
records the bounded scope and owner evidence. Operative rules now make accepted
ADRs immutable, direct current specification maintenance to owning mutable designs,
and reconcile the bounded authority wording for ADR-006 and the
usable-project-lifecycle brief without changing their catalog classifications or
any ADR bytes. Publication is tracked in
[PR #58](https://github.com/joeroberts/release-radar/pull/58); GitHub is the source
for its live review and merge state. Outcome 2's delivered specifications, Shared
Execution V1 guidance, and Outcome 3's assessment are integrated into `main`;
Outcome 3 onboarding/plugin implementation is now released under the brief above.

The last directly verified installed release is **0.1.17 (1)**. Published tags `v0.1.14`–`v0.1.16`
remain unchanged; `v0.1.16` targets `76cce40cc810d0e8f35af70f05b9d8ea5d884727`.
Releases 0.1.14–0.1.16 are integrated into `main` through
[PR #52](https://github.com/joeroberts/release-radar/pull/52). `main` is GitHub's
default branch. [PR #53](https://github.com/joeroberts/release-radar/pull/53)
removed the unauthorized saved-checkout integration rule.

The RDS search-submit focus correction, consumer adoption and Add Project RDS
styling corrections are complete; their bounded delivery tasks are archived.
The [0.1.16 package evidence](evidence/2026-09-12-release-0.1.16-packaging.md)
records signed identity, matching repository/Downloads DMGs, installation,
layout, focus, accessibility and smoke-launch checks. Existing versioned DMGs
remain the rollback copies.

The owner-approved repository cleanup is complete. Documentation reconciliation
[PR #54](https://github.com/joeroberts/release-radar/pull/54) and the **Stage Release**
action label [PR #56](https://github.com/joeroberts/release-radar/pull/56) are merged
into `main`. Local Git references and disposable build output were cleaned up;
retained work, installers and test evidence were preserved. The
[Historical cleanup closeout](archive/2026-09-11-phase6-delivery-history.md#september-12-repository-cleanup-closeout)
records review limitations and disk recovery. No app release was required.
Current coordination is tracking closeout; no new product implementation is open.

## Current authorization

**September 16 — Outcome 3 execution setup implementation is released.** The
owner explicitly authorized the assigned worker’s onboarding/plugin implementation,
including production hook integration, on `codex/outcome3-execution-setup` at
Main/BuildAgent-verified clean baseline `805d210784e0004220d4d1f903fb6edac42e14ba`.
The [controlling implementation brief](task-briefs/2026-09-16-outcome3-execution-setup/brief.md)
records complete scope, exclusions, checks and review. Worker
`01a0acb5-bc87-72b3-a06e-8821cb18bfc9` exclusively owns this delivery’s ledger/catalog.
First checkpoint is exact package recognition, native provisioning boundary and
protected assignments with focused failure/retry behavior. Installed skill reads
are denied; repository-local fallbacks apply. Named permission label is unexposed;
Main confirmed effective restrictions and actual Sol/high. Git/native checks and
documentation history traversal use Main’s trusted route. No live configuration,
trust/profile/install, SQLite/application acceptance, release, push/PR, merge or
main mutation is released. Source implementation, direct checks, independent
RO04 review and trusted scoped local commit are authorized. Catalog changes are
pending application acceptance. Main/BuildAgent’s focused native assignment/hook run passed seven tests on the
working tree; tests were authored first, the initial missing-type baseline was not
run. The protected store and native adapter are not yet checked. Independent
review and complete onboarding/plugin integration remain pending.

The owner authorized the completed 0.1.18 (1) metadata, signed package/Downloads
delivery, tracked staged app and DMG commits, independent package review, branch
push/normal PR and annotated version-tag push. The current closeout is limited to
recording the merged result and cleanup readback; exact reviewed source is
`a30cfea`.
Installation, app launch, live helper restart/reinstall/registration, owner plugin
writes, notarization, GitHub Release, main merge and application/catalog mutations
remain excluded. Preserve earlier installers and tags.

Outcome 3 assessment work is complete. Present implementation authority is the
September 16 release above; the assessment alone grants no authority.

The following paragraph records historical Outcome 1 operative-authority
reconciliation authorization only; it does not authorize present actions. The
current branch-only, no-main-merge rule supersedes it, and no current authority may
be inferred from that historical record.

The owner authorized this repository-only outcome, its controlling brief,
documentation/index changes, independent review, scoped local commits, branch push,
PR creation and merge, and the annotated documentation milestone tag
`docs/operative-authority-reconciliation-2026-09-13` after merge. The delivery
owner owns the branch push and PR creation; the coordinator owns merge and tagging.
Packaging, app release, installation, application launch, binding, catalog
acceptance, evidence mutation and owner data or SQLite access remain excluded.

The owner authorized the documentation reconciliation, local Git/build cleanup,
and the specific Codex action rename, then separately approved both PR merges.
Recording their verified outcomes remains part of delivery coordination.
Application binding/catalog acceptance, evidence mutation and owner SQLite or
project-data changes remain outside that authorization. GitHub protections and
CI are captured for further planning in
[issue #55](https://github.com/joeroberts/release-radar/issues/55); no protection,
workflow or governing-policy change has been approved by that issue.

Earlier owner directions authorize scoped local commits, branch pushes and PRs
for already-authorized delivery work. Earlier Phase 6 local-only publication
restrictions do not revoke those directions or authorize new slices. Every merge
still requires owner approval. Completed authorized app batches retain the
standing local version/tag/DMG/installation workflow in [AGENTS.md](../../AGENTS.md);
documentation-only work does not trigger it. GitHub's default branch must not be
changed without an explicit owner request.

Phase 6F metrics remain explicitly stopped. Remaining Phase 6 extensions are
unimplemented and are not opened by this reconciliation. Phase 7 planning is
independently approved at `a0f22d965395248be6ec5928d2932d3a7ce5166d`; implementation
remains paused and both preserved Phase 7 tasks must remain untouched. The approved
[Pursuit reconstruction design](../design/repository-plan-reconstruction-design.md)
remains sequenced after Phase 6H. Proposed guided-setup label 6I does not silently
add another dependency. No live reconstruction is authorized.

## Verification and remaining limitations

BuildAgent built the native Release package from clean source `0670e7a` using the
existing staging script: exit 0, strict signing/entitlements and source/staged
identity passed. Read-only APFS DMG payload verification passed; repository and
Downloads copies match SHA-256 `68bc6da35ff75a23fde777bd8beb67a3802eb2a205da260459a51fbb0ab58c5b`.
All 46 built/staged/mounted entries match. Zero XCTest ran under the explicit
no-app-launch boundary. Independent RO04 review passed exact artifact commit
`430e8912` with no findings; branch, normal PR #69 and annotated tag are published;
see the [package evidence](evidence/2026-09-15-release-0.1.17-packaging.md).

BuildAgent task `01a0a51a-43e5-7a62-8571-519dfc7e57d7` ran an incremental DEBUG
build at `ef012b68`: exit `0`, `BUILD SUCCEEDED`, succeeded xcresult, zero
errors, one warning, signed Core not stripped, analyzer `0`, and arm64. It used
the `danger-full-access` / `never` profile with the default SwiftPM sandbox.
No build tests ran; separate production-reader verification recorded 10 passes
and 0 failures. This is evidence of the incremental DEBUG build, not of a clean
build, Release build, package, installer, or enforcement proof. The restricted
profile's nested-apply limitation remains and is not a profile fix.

PR #67's worker and reviewer are archived. Branch and tracking readback found
the expected registration state (`e8f2` path registration absent), no retained
scratch artifact, and the superseded PR #66 `d7aa` worktree removed. Existing
catalog identities, paths, lifecycle and index sections remain unchanged.

Authority-reconciliation candidate
`f39aae7cf9a2bdfd4adedcd96b1ef73f64014572` passed the repository-native
documentation check, `git diff --check`, focused obsolete-direction searches and
the baseline comparison proving every existing ADR unchanged from
`892b1e11597dd1cff30f04818ecd7dac0605b897`. Independent reviewer task
`01a09b95-5f77-7260-8f06-bccb29143d78` accepted the corrected candidate with no
Required, Optional or Out-of-scope findings. Final catalog/index closeout also
passes repository validation. Chief-architect task
`01a09b8a-1350-7c42-9d14-0aa07f28df40` and reviewer task
`01a09b95-5f77-7260-8f06-bccb29143d78` are archived. The delivery-owner task
remains active only to report this closeout; coordinator archival follows that
stopped result. These checks do not establish application acceptance or
synchronization.

Repository documentation validation passes. The eight completed briefs and their
catalog/index metadata agree; stable artifact identities and evidence remain
preserved. Closed delivery details are in the historical archive. Repository
validation does not establish application acceptance or synchronization.

The previously completed product reviews remain terminal. They do not establish
CodeRabbit review of the remote integrations: PR #52 had no CodeRabbit review or
comment, and PR #53's CodeRabbit review failed because the PR was already closed.
PR #54's final documentation head received an explicit successful CodeRabbit
review. PR #56 was merged on the owner's instruction while CodeRabbit remained
rate-limited; its green status was not a completed review. The
[Historical cleanup closeout](archive/2026-09-11-phase6-delivery-history.md#september-12-repository-cleanup-closeout)
retains the review links and exact outcomes.

The last combined source check recorded **194 passed, 7 skipped, and 6 failed
cases (12 assertions)**. Those failures reproduced on unchanged `5e7b9b8`; this
is not a green full-suite result. Latest consumer-focused verification recorded
3 passing checks and 1 skipped AX-fixture check. These are retained product
results, not new tests performed by this documentation task.

Full owner [manual acceptance](evidence/2026-09-11-phase6-owner-acceptance-guide.md)
remains outstanding. The owner deferred the isolated production stale-helper
scenario to [Phase 8](plans/2026-09-06-full-product-architecture-and-delivery-plan.md#phase-8-deferred-stale-helper-acceptance--owner-decision-2026-09-11).
It remains unpassed: the real stale `SMAppService` upgrade through the installed
Settings button has not been exercised. The
[signed installation evidence](evidence/2026-09-11-restart-helper-signed-installation.md#remaining-stale-helper-gap)
retains the exact limitation. A separately provisioned GUI account or VM remains
future work requiring its own authorization; the owner's live helper must not be
used to manufacture the stale precondition.

The fresh read-only managed readback at `2026-09-16T00:21:05Z` reports the exact
canonical root `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
bound to project `project-fffdc0e0b15b9b86`, root
`project-fffdc0e0b15b9b86-root-0`, and repository
`e7475429-ef51-4368-ad9e-61d9073d5a4f`. Bookmark status is `NOT STALE` and the
inventory is complete with zero evidence rows. The read-only
`ReleaseRadarDocumentationTool` 0.1.18 `(1)` `diagnose --root` check passed with
catalog version `1` and digest
`112beed626b832915e31d1296baa3ce1f8355ce84d16db086c2321c459302369`, matching
the exact accepted snapshot. No binding or catalog acceptance mutation was
needed or performed. These facts are scoped to this root and snapshot only;
they do not establish all-project or ticket completion, later catalog state, or
broader owner manual acceptance.

The saved `TEST` search-value diagnosis remains unresolved as to initiator; the
retained audit used only the generic actor. No preference was changed. Details,
prior release checkpoints, review outcomes and task closeouts are preserved in
the [Historical Phase 6 record](archive/2026-09-11-phase6-delivery-history.md#september-12-release-and-integration-checkpoints).

## Next eligible work

PR #70 merge, source/package review, direct checks, branch/PR and annotated tag
publication are complete. Installation stays on hold; no live recovery journey is
claimed by this closeout. Continue the released Outcome 3 implementation from its
controlling brief; report concrete boundary decisions and candidate checkpoints
to Main/coordinator02, route checks and independent review through Main.

The exact canonical root is currently bound and its catalog snapshot is
accepted; no binding or catalog mutation is pending for this root/snapshot.
This read-only status does not authorize changes to other projects, ticket
completion, later catalogs, SQLite, or application state. Broader owner manual
acceptance remains outstanding under the existing guide. The closeout itself releases no product slice, paused task, stopped metrics work,
live recovery or Phase 8 environment provisioning. Outcome 3’s separate explicit
release above controls its bounded implementation. GitHub protection/CI planning remains
in issue #55 and is not a prerequisite for these follow-ups.
