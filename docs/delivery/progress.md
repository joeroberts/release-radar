# Release Radar delivery state

## Current outcome

**Owner-approved continuation: complete the simple workspace setup.** The owner
explicitly directed the coordinator to work from the canonical checkout on main,
create fresh delivery/review tasks, use a reusable workspace-relative restricted
profile, keep history outside worker read/search access, and handle the setup.
This supersedes the earlier assessment-only endpoint for this bounded setup; it
opens no new runtime manager, VM, publication or unrelated app-data operation.
Canonical coordination is active in replacement task
`01a0a034-404c-7d80-91aa-4caf10bc80b3`, at the exact canonical root on `main`
from `e80ab27`. The old coordinator confirmed relinquishing ownership and its
archive closeout; its worktree remains untouched. The existing monitor is retargeted
here and active. The [owning brief](task-briefs/2026-09-14-outcome3-simple-workspace.md)
now includes the authorized configuration continuation. Chief architect
`01a0a035-2586-7ad0-8c29-92fa5d385f1b` reviews only the exact workspace-relative
profile correction before a fresh delivery writer. The profile is still path-specific
pending that review. Other config, accepted ADRs and unrelated dirty proposal files
remain preserved. Current task-creation tools expose no profile selector; no supported
replacement was found. No runtime isolation or application synchronization is claimed.

**Simple coordinator-managed workspace: architect checkpoint complete; delivery is blocked on profile selection at task creation.**
The owner-directed [brief](task-briefs/2026-09-14-outcome3-simple-workspace.md)
retains coordinator-created native tasks and historical files outside worker
read/search permissions. The earlier broad assessment is prior proposal evidence,
not the controlling implementation approach.

Fresh chief architect `01a0a007-5307-72c1-b724-114c72131e1e` (Astra/high) inspected
baseline `b54916a` and installed desktop build 26.908.40834/8881. The internal
`Vhi` task-start helper accepts `permissionProfileId` for ordinary/worktree tasks,
but its exposed create_thread handler omits the argument. Source-task Full Access
and saved selections can override destination defaults; changing a project default
alone is not a demonstrated fix. Computer Use rejected read-only Codex access:
“Computer Use is not allowed to use the app 'com.openai.codex' for safety reasons.”
No alternate automation mechanism was attempted. The precise missing operation is
supported explicit pre-start profile selection through the coordinator's task
creation interface, with effective-settings readback. Do not substitute owner clicks.

The minimal proposed layout retains history in canonical docs/delivery/archive/
and stages active work under the sibling release_radar-workers/<task-id>/ tree.
Workers must lack access to canonical history, shared Git objects and indexes that
recover it. Select obsolete instructions by lifecycle, authority, replacements and
current dependencies; completed supporting evidence is not automatically obsolete.
Keep current accepted ADRs accessible and unchanged; preserve moved bytes, stable
IDs and catalog/reference integrity. Check current input/output use, denied history
read/enumeration/search and Git recovery, and actual CodeGraph/host file-reading
routes to these paths, plus deliberate coordinator retrieval. These paths and tests
are proposed, not created, moved or executed. No new runtime manager is required.

The read-only checkpoint produced no files or temporary artifacts. Its result is
preserved here; the completed task is archived and its monitor is paused. Real migration/configuration,
application catalog acceptance and new probes remain unexecuted. The owner task
creation interface gap must be resolved before releasing a migration writer.
Existing dirty proposal/catalog/index rows and prior fixtures remain untouched.

**Outcome 3 architecture assessment is complete; runtime implementation remains unopened.**
The [reviewed proposal](../design/outcome3-runtime-enforcement-assessment.md)
identifies the remaining native boundary: supported authenticated attachment to the
existing desktop, admission before the first model turn, and persistent enforcement
across all tool/follow-up routes. App Server's separate start/turn primitives can
support pre-turn source inspection in a controlled client; instruction loading is
not itself model exposure. Safe provisioning and nonduplicating recovery may compose
supported configuration primitives with RR-owned records rather than requiring
new desktop APIs for every safeguard.

The selected native desktop/local App Server/profile direction remains in place.
Complete enforcement is unestablished with that route. A separate App Server client
with isolated macOS workers is a conditional alternative, not an approved replacement
or proven implementation; it loses native worker-task integration and still needs
credential, hosted-tool and native-build feasibility checks. The proposal contains
concrete workspace, profile lifecycle, review/integration and allowed/denied test
scenarios; every runtime scenario remains notRun. Hooks supplement covered operations
and do not close the unsupported boundary. New runtime-owner/custody/recovery
decisions require separate authorization; accepted ADRs stay unchanged.

Chief architect `01a09fd8-0f4e-7d61-aa3d-a4ccc5db5f33` (Astra/high) produced
`be30175`, then corrected two Required overstatements in `77def74`. Independent
reviewer `01a09fe2-e4cb-7772-8682-f299d8923713` (Astra/high) passed the corrected
candidate. Installed 0.1.16 documentation check/diagnose passed at canonical
integration; proposal/index bytes match the reviewed candidate, and governing
instructions and accepted ADRs are preserved. The
[assessment brief](task-briefs/2026-09-14-outcome3-runtime-enforcement/brief.md)
is complete. Both peers have stopped and are archived. The monitor pauses at this closeout. No new temporary
files, runtime/configuration/app-state changes or publication occurred. Existing
fixtures and unrelated uncommitted proposal/catalog/index rows remain retained.
Application catalog acceptance remains pending; no synchronization claim is made.

**Exact Shared Execution v1 adoption is complete and locally integrated at `065f8b3`.**
The [completed brief](task-briefs/2026-09-14-shared-execution-v1-adoption/brief.md)
authorized the exact 19-line AGENTS.md addition. Existing clauses and accepted ADRs
are unchanged. Fresh delivery `01a09fb4-d719-73d3-b384-d9db83a1bc6d` (Terra/medium)
produced candidate `a8918a7` from `7a308ce`; fresh independent reviewer
`01a09fb6-7873-7843-a968-7c7447721eff` (Sol/high) passed it without findings.
The installed 0.1.16 helper's diagnose/check passed on the candidate and canonical
integration; exact block comparison, retained fallback clauses, marker uniqueness,
ADR preservation and diff hygiene passed. The reviewer selected the shared skill
from repository-local guidance; it was not explicitly requested in the assignment.
That observation does not prove universal automatic selection or runtime isolation.
Both peers have finished and are archived. No configuration, installation,
app-state or publication change occurred. Temporary comparison files
`/tmp/release-radar-shared-execution-block.actual` and
`/tmp/release-radar-shared-execution-block.expected` remain retained.

**Outcome 2 is complete and locally integrated at `5b17e9a`.** The
[completed brief](task-briefs/2026-09-14-outcome2-current-specifications/brief.md)
records the authorized outcome and local-only endpoint. Current reading routes,
mutable specifications, lifecycle classifications and indexes are reconciled.
Continuing Phase 5B, M6A custody/recovery and conditional Run Guard requirements
have current mutable homes; historical records remain deliberately retrievable.

Independent review passed corrected candidate `7599b80` after three Required
preservation findings were resolved. Native documentation validation, diff hygiene,
current managed-document/shared-V1 reading scenarios and historical lookup passed.
All 396 pre-closeout artifact IDs/paths, AGENTS.md and accepted ADR bytes are
preserved. Integrated reviewed files match that candidate except the separately
retained unapproved proposal registration/index row. This establishes documentation
and navigation correctness, not runtime isolation or application catalog acceptance.

Fresh delivery `01a09deb-5029-7891-aaf2-121780258f55` (Sol/high) and independent
reviewer `01a09dec-933e-7473-aefe-f044fd3d53e5` (Astra/high) finished and are archived.
Temporary build output `/tmp/rr-outcome2-docs.bo7OTV` and prior permission/pilot
fixtures remain retained; nothing was deleted. The older uncommitted broad proposal
and its catalog/index entries remain excluded from authorized commits.

Foundation clarification: Shared Execution V1 source delivery is complete, as recorded in the [source evidence](evidence/2026-09-09-shared-execution-integration-v1.md). Installed capability/runtime verification and exact repository adoption remain separate evidence requirements. Environment provisioning, profiles and enforced task lifecycle are a versioned extension tracked for Outcome 3. Outcome 2 reconciles these distinctions in current specifications; it does not implement or adopt them.

The parallel V1 verification/preparation task `01a09df3-a7ea-7293-848a-4029490cfa82`
(Sol/high) completed on clean baseline `322f4f6` and is archived. Codex's plugin inventory reports
0.1.16 installed/enabled; the product-normalized package digest exactly matches
its recognized standard-[1] row. Installed/cache/source shared-skill bytes match
and the fresh task loaded the skill explicitly. Installed documentation `diagnose`
0.1.16 (build 1, contract 1) passed on its exact worktree. No V1 adoption marker was present at that preparation baseline; the approved
block is now integrated as recorded above. Supported inventory returned `rootUnavailable` for that worktree; this
is neither canonical binding evidence nor a broken installed-capability result.

The exact block from
[the current design's section 5](../design/shared-execution-integration-v1-design.md#5-exact-consumer-adoption-block)
is now adopted immediately before the v2 tracking block. No existing clause was
removed. Missing/incompatible/owner-denied runtime cases, universal skill selection
and registered canonical app compatibility readback remain unproved; they are not
acceptance criteria for this exact patch. No configuration or app state changed.

The chief-architect isolation assessment is complete. The owner approved retaining
native desktop tasks, the desktop's local App Server and named permission profiles.
The unresolved capability is an enforced per-task allowlist covering every exposed
tool route from the first turn through follow-ups while preserving coordinator
access. Command filesystem enforcement is demonstrated; complete worker isolation
is not. The separate local worker client remains an alternative proposal, not an
authorized replacement or implementation. No profile, tool, ADR or runtime change
is authorized by this decision; retained experimental files remain untouched.

The subsequent owner-authorized lifecycle assessment against
[Shared Execution V1](../design/shared-execution-integration-v1-design.md) is
complete: the manager direction is conditionally feasible as a versioned extension,
not functionality already delivered by V1. V1 supplies context, direct checks and
compatibility/adoption diagnostics; it explicitly excludes runtime management.
The chief architect identified these remaining contracts and evidence:

- Provisioning: reusable relative profile templates plus project-specific roots
  and environment records; supported Codex configuration operations must preserve
  unrelated entries and detect conflicting owner edits.
- Task creation: a supported, authenticated RR-to-existing-desktop connection
  must bind workspace and permissions before the first model turn. Documented
  App Server APIs do not prove that attachment or native desktop integration.
- Tools: enforce role-specific capabilities across non-shell routes while leaving
  coordinator and unrelated task access intact.
- Delivery: demonstrate a representative restricted macOS build, read-only current
  inputs, a fixed review candidate, separate role outputs and integration of only
  the reviewed change against its expected canonical baseline.
- Lifecycle: reconcile uncertain creation, version profile updates, rotate identity
  on root changes/re-add, and retire only owned unreferenced resources while
  preserving history. Reuse existing app-owned records, not a second task database.

Codex remains configuration owner; RR would request operations through an approved
boundary. The existing fixed plugin-lifecycle helper cannot be repurposed by
inference. The assessment used supplied canonical source/ADR excerpts and pilot
evidence plus official [App Server](https://learn.chatgpt.com/docs/app-server) and
[permission](https://learn.chatgpt.com/docs/permissions) documentation; it did not
prove new runtime behavior. Accepted ADRs and runtime configuration stay unchanged.

The owner-authorized **current-document workspace pilot is complete**. The
[result](evidence/2026-09-13-current-document-workspace-pilot.md) records selected
current inputs, deliberate historical retrieval, direct source preservation and
independent review. One omitted consumer-compatibility requirement was corrected;
final review has no findings. Both peers used the verified named desktop profile.
Accepted ADRs, configuration and existing fixtures remain unchanged. This proves
the bounded document-selection/handoff route, not complete historical-access or
role isolation. Exposed non-shell tools and blocked skill/Perl dependencies remain
explicit limits; no broader implementation or application operation is opened.

Delivery `01a09d80-ca12-7213-a1fb-6388962b3af2` (Sol/high) and independent reviewer
`01a09d80-ccc0-7b71-8b8e-abb2ac05187e` (Astra/high) are stopped and archived. Experimental files remain retained. Pre-existing broad
proposal changes remain unapproved and excluded from the pilot source and commit.

Outcome 1 operative-authority reconciliation is complete. The
[completed brief](task-briefs/2026-09-13-operative-authority-reconciliation/operative-authority-reconciliation-brief.md)
records the bounded scope and owner evidence. Operative rules now make accepted
ADRs immutable, direct current specification maintenance to owning mutable designs,
and reconcile the bounded authority wording for ADR-006 and the
usable-project-lifecycle brief without changing their catalog classifications or
any ADR bytes. Publication is tracked in
[PR #58](https://github.com/joeroberts/release-radar/pull/58); GitHub is the source
for its live review and merge state. Outcome 2 is now complete; Outcome 3 implementation remains unopened.

The installed release is **0.1.16 (1)**. Published tags `v0.1.14`–`v0.1.16`
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

The September 14 Outcome 3 assessment approval is fulfilled through reviewed
repository documentation and local integration. Runtime implementation, configuration
and the alternative execution environment require the concrete owner decision.

The September 14 exact V1 adoption approval is fulfilled through local integration
and closeout. It authorized no push, PR, remote merge, tag, release or app-state
change. Earlier authorizations below retain their own original task scope.

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

Authority-reconciliation candidate
`f39aae7cf9a2bdfd4adedcd96b1ef73f64014572` passed the repository-native
documentation check, `git diff --check`, focused obsolete-direction searches and
the baseline comparison proving every existing ADR unchanged from
`892b1e11597dd1cff30f04818ecd7dac0605b897`. Independent reviewer task
`01a09b95-5f77-7260-8f06-bccb29143d78` accepted the corrected candidate with no
Required, Optional or Out-of-scope findings. Final catalog/index closeout also
passes repository validation. Chief-architect task
`01a09b8a-1350-7c42-9d14-0aa07f28df40` is now archived after its completed
assessments. The owner explicitly rejected its reuse; future architecture work
requires a fresh task using current documents. Reviewer task
`01a09b95-5f77-7260-8f06-bccb29143d78` is archived. These historical checks do not establish application acceptance or
synchronization, and do not indicate any currently running delivery assignment.

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

The repository cleanup did not perform application inventory, binding/catalog
acceptance or managed readback. The last recorded inventory was `bindingMissing`, `isComplete:false`
for `project-fffdc0e0b15b9b86`; repository checks cannot establish current managed
application synchronization. The changed catalog remains pending application
acceptance; no acceptance has been recorded for this repository correction.

The saved `TEST` search-value diagnosis remains unresolved as to initiator; the
retained audit used only the generic actor. No preference was changed. Details,
prior release checkpoints, review outcomes and task closeouts are preserved in
the [Historical Phase 6 record](archive/2026-09-11-phase6-delivery-history.md#september-12-release-and-integration-checkpoints).

## Next eligible work

Resolve supported coordinator task creation with explicit pre-start profile
selection and effective-settings readback. The simple workspace implementation is
blocked on that operation; no owner task creation or selector babysitting is the
proposed workaround. Earlier broad architectural alternatives below are not the
owner-selected next step.

Outcome 2 and the approved exact V1 adoption patch are complete locally. Installed
capability and fresh-review skill selection are verified to the limits above.
The reviewed Outcome 3 assessment is complete. Its native attachment/admission and
persistent all-tool gaps remain unestablished; implementation is not authorized.
Further installation/configuration/app-state mutations require their separately
bounded authorization.

For the Outcome 3 environment extension, the supported authenticated RR-to-desktop
interface, restrictions before generation, role-specific non-shell capabilities,
configuration/lifecycle recovery and representative native build/review/integration
remain unresolved. V1 adoption does not establish those capabilities.

Inspect the current application binding/catalog status without changing it, then
present any exact required binding or catalog acceptance mutation for owner
approval. This follow-up is not authorized by the completed outcome 1 task. The
last recorded missing binding must not be treated as fresh
application state or repaired by editing SQLite. Broader owner manual
acceptance remains outstanding under the existing guide. No product slice,
paused task, stopped metrics work, live recovery or Phase 8 environment
provisioning is released by this closeout. GitHub protection/CI planning remains
in issue #55 and is not a prerequisite for these follow-ups.
