# Outcome 3 project execution setup

## Objective and outcome

Integrate deterministic project execution setup into Release Radar’s existing
onboarding and plugin installation flows, including project-scoped worktrees,
protected assignments and production hook admission from verified assignments.
Preserve ordinary-worker history/sibling exclusion and deliberate Main retrieval.

## Scope, authority and dependencies

The owner explicitly released worker `01a0acb5-bc87-72b3-a06e-8821cb18bfc9`
on September 16 for this implementation, including production hooks. The current
[Outcome 3 integration contract](../../../design/outcome3-runtime-enforcement-assessment.md#september-16-onboarding-and-worktree-integration-contract)
(`rr-outcome3-runtime-enforcement-assessment-2026-09-14`) controls the product;
[progress](../../progress.md) controls authorization and delivery state. Prior VM
and native desktop attachment requirements are superseded by its September 16
amendments. Accepted [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md)
and [ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) are immutable.
The existing installer helper retains exactly status/install/remove/reinstall.
No generic command or Git/project authority, parallel installer, database or
execution dashboard is included. Preserve unrelated configuration, user removal
and modification semantics. Identify the exact reviewed standalone coordinator
source before reuse. libgit2 is a recommendation requiring a reported compatibility
and adoption decision before adding a dependency.

## Assignment and bounded checkpoints

Main assigned `/Users/jroberts/.codex/worktrees/3ec7/release_radar`, branch
`codex/outcome3-execution-setup`, clean baseline
`805d210784e0004220d4d1f903fb6edac42e14ba`, verified through BuildAgent’s trusted
route. Sol/high is confirmed by Main; ceiling Astra/high only for a named issue.
No Ultra or subagents. This worker owns product/tests/affected mutable docs and
exclusively owns catalog/index/progress edits. Main and BuildAgent own trusted Git,
documentation history traversal and all native compilation/check execution.

First checkpoint: exact plugin package recognition, native bookmark-held
provisioning boundary, protected assignment contract and focused failure/retry
behavior. Continue in coherent bounded changes toward the complete outcome;
checkpoints do not authorize omitting required behavior.

Main confirmed committed recovery baseline
`58d86bf05dac2456f7e52b0b325964b1fbdc0d13`. Corrected checkpoint 16 passed the
app build, all 51 affected tests and documentation/index/diff checks. After the
fresh reviewer's sole Required P2, the bounded historical-retirement correction
passed checkpoint 17's app build, all 14 producer tests and documentation/index/diff
checks. Reviewer `01a0ad8a` cleared P2 with no remaining Required or Optional findings;
these validations and prior terminal reviews remain closed for unchanged behavior.

The current released slice prepares the source package only: concise deterministic
prepare/start/stop/recovery guidance in the existing shipping skill; require the native
coordinator and verify its identifier, hardened runtime and exact approved group-only
entitlements in the existing packaging verifier; align app/plugin version 0.1.19 and
register its normalized package digest without changing any published 0.1.18 pair.
Main/BuildAgent confirmed v0.1.19 is unused locally only; no remote availability is
claimed. Preserve the single native plugin, existing schema and helper authority.
BuildAgent's unchanged native digester returned 0.1.19 digest
`6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35` (exit 0).
The exact pair is now registered and shipping acceptance assertions updated; tests
preceded recognition changes, with no native red run claimed. Package bytes remain
unchanged since readback. The complete source/tests/docs candidate is frozen.
Main/BuildAgent checkpoint 18 passed the app build, all 36 affected tests (lifecycle
acceptance 26, package 2, compatibility 6 and skill contract 2), packaging-script
`bash -n`, documentation and diff checks. The test-built coordinator passed strict
signature and hardened-runtime checks, but identifier `ReleaseRadarCoordinator`
and XCTest-injected entitlements do not establish exact production identity. This
is neither production defect evidence nor a production identity pass. Reviewer
`01a0af6d` found one Required P1: unconditional coordinator verification also rejects
valid older prior destinations during promotion. No other Required findings remain;
published 0.1.18 recognition and guidance review are terminal. Main released only
the verifier correction. The default candidate role requires exact 0.1.19 and strict
coordinator checks. Only the pre-promotion prior destination uses explicit
prior-destination role, allowing supported 0.1.7–0.1.18 without a coordinator while
preserving existing app/bridge/deep/signature/runtime/entitlement verification.
Prior 0.1.19 and any present coordinator require strict coordinator checks; unknown
prior versions/roles refuse. Initial and promoted candidates cannot be legacy.
BuildAgent passed packaging-script `bash -n`, documentation/diff checks and all 13
bounded verifier/promotion fixture cases with actual function bodies, stubbed codesign
and real filesystem/plist operations. The strict new-candidate/legacy-prior distinction
is verified; this is expressly not production signature proof. The same reviewer
cleared P1 with no remaining Required or Optional findings; correction validation is
terminal. Main confirmed the scoped package commit
`05f99ef26cf479221b289d03275148a0194b973f` on the same assigned branch/worktree. Temporary `build/promotion-p1-fixtures` remains retained
and excluded; no cleanup is authorized. Shipping package bytes and
digest remain unchanged; checkpoint 18's unchanged checks remain terminal.
No native red run is claimed. Main→BuildAgent owns trusted Git. No real install,
packaging run or live
state mutation is included. Runtime/UI, production boundaries, portability and catalog
application acceptance remain open; source identity is not complete acceptance.

Main/BuildAgent checkpoint 19 ran the reviewed stage-release-no-launch path.
Release build succeeded, but the stage gate rejected actual coordinator signing
identifier `ReleaseRadarCoordinator` instead of required
`com.rekonlabs.ReleaseRadarCoordinator`. Strict app deep/helper signatures, hardened
runtime and exact group-only entitlements passed without XCTest extras; app version
was 0.1.19. Processes exited with no staging promotion, installation or launch.
Temporary `build/production-stage-019-19.log` remains retained and excluded.

Main released only the project-source signing correction from `05f99ef`: generate
and embed the coordinator's Info.plist in Debug/Release, matching existing
command-line helpers and retaining its required product bundle identifier.
The verifier, signing authority, entitlement structure and helper authority are
unchanged. Corrected checkpoint 19's `stage-release-no-launch` exited 0: Release build,
strict app/coordinator signing, copy and promotion passed. Coordinator identifier is
exactly `com.rekonlabs.ReleaseRadarCoordinator`, hardened runtime passed and its sole
entitlement is application-groups `[2UA854NLX4.com.rekonlabs.ReleaseRadar]`. Built and
staged plugin version 0.1.19 and normalized digest match the registered pair above.
Reviewer `01a0af8d` cleared the bounded signing correction over `05f99ef` with no
Required or Optional findings; checks/review are terminal. Temporary corrected log
`build/production-stage-019-19-corrected.log` remains retained and excluded. Source/docs
remain frozen. Main reported signing commit `e1282b1` and that reviewer `01a0af8d`
is completed and archived; this worker performed no Git operation. Main subsequently
reports BuildAgent installed and launched `/Applications/ReleaseRadar.app` 0.1.19
from source `e1282b1` without rebuilding. Installed shipped and cached plugins both
match the registered normalized digest via the unchanged native digester. Main's
Connections UI reads Installed 0.1.19 matching shipped; no redundant plugin update is
needed. Overall acceptance is not claimed. Shipping package
bytes/digest remain unchanged; package guidance/version checks remain closed.
No worker native/build/Git/live actions are included. Production packaging completion,
actual-flow/runtime/UI, portability and live catalog acceptance remain open.

Main subsequently reports explicit owner authorization for verified 0.1.19 installation
and launch, plugin update, and disposable-project actual onboarding, hook trust,
worker permissions, STOP and recovery, including necessary live app/configuration
state. This is an attributed Main report, not a verbatim owner quotation.
Installation/launch and installed/cached plugin identity are verified as reported
above; disposable-project actual-flow acceptance remains pending.
Main serializes all live writes and releases dependent actions after prerequisite
readback. This source worker performs none: its current assignment is a bounded
ledger/brief update and read-only existing-fixture/UI/tool entry-point inspection,
with no fixture creation, product edit or process artifact. Existing terminal
checks/reviews remain closed; unrelated data, migration and publication are excluded.

The earlier stale inventory needed fresh task loading. Main's fresh task exposes
assignment preparation but worker MCP remains absent: initialization connection closed.
BuildAgent's single installed initialization exchange exited 1 with empty stdout and
execution-setup-unavailable stderr. CoordinatorMain eagerly opened execution storage
before initialization; this is an observed source defect, distinct from stale inventory.
Main reports rejected UI automation clicks while the app was changing. Actual
onboarding/worker/isolation/STOP/recovery acceptance remains open. No task, fixture,
harness or process artifact is created here. The retained transport-only fixture
does not exercise onboarding; recommend a fresh disposable Git repository outside
owner repositories/app storage with committed current guidance/progress, valid
catalog/indexes and app-owned governed pending work. Exact existing routes are
Settings → Connections → Release Radar Codex Plugin status; Initialize Project
Tracking → Choose Project Folder… → Confirm initialization → Initialize Project
Tracking → Resume Execution Setup if pending → Finish Initialization; project
Preview Documentation Action → Bind This Repository/Accept This Catalog; exact
`release_radar_prepare_execution_assignment` → `coordinator_workers.worker_start`
and `worker_status` → independent `worker_interrupt` → confirmed completion and
`worker_close`; Manage Project hook update/remove/resume and selected Worker resources
retirement. Genuine OS authentication/privacy prompts or inaccessible controls need
owner participation; folder selection is required grant UI, not per-worker consent.
Main released only the pre-provisioning MCP discovery correction from committed
baseline `338ca6e1954aa9f9a0e9bd7deffa429036b6e191`, same branch/worktree and model/effort.
Live writes are paused during source correction. The existing MCP service defers
adapter/store construction until a validated worker tool call, caches the same adapter
per connection and disconnects only an opened adapter. Initialization/ping/tools-list
never provision execution storage. Every worker operation retains create:false storage
access and all authority/root/assignment/profile/trust/readiness gates. The existing
service definition moves to the already test-compiled WorkerAdapter file, without new
harness, engine, file, profile or configuration workaround. Shipping package bytes/digest
remain unchanged. Two existing-suite regressions precede source correction: missing/invalid
storage permits initialization/discovery but all tools fail closed without provisioning;
verified work/status/disconnect retain one adapter, launch and physical close. No native
red run is claimed. Main/BuildAgent checkpoint 21 passed app/coordinator build,
all 14 WorkerAdapter tests and documentation/index/diff checks. Actual Debug MCP
initialization/tool listing returned six tools, with EOF exit 0 and empty stderr.
Production checkpoint 22 passed stage-release-no-launch strict signing/copy/promotion,
exact coordinator identifier, hardened runtime and sole approved application-group
entitlement. Staged Release initialization IDs 1/2 and six-tool listing passed,
with EOF exit 0 and empty stderr. Plugin 0.1.19 and registered digest remain unchanged.
Temporary `build/coordinator-startup-21.log`, associated `.xcresult` and
`build/coordinator-startup-release-22.log` are retained/excluded. Reviewer `01a0afd4`
cleared the complete six-file patch over `338ca6e` with no Required or Optional findings:
no-store discovery, lazy create:false gates, atomic cache, independent STOP during
awaited calls and cached EOF physical cleanup are preserved. Checkpoints 21/22 remain
attributed; direct checks/review are terminal, with results preserved for reviewer
archive. Later factual pass annotations were not independently reviewed; they add no
design change and need no additional review. Source/tests/docs remain frozen for
Main's existing live-acceptance route. Main reported commit
`74d227ea3b2d811cd4029e5bf9da010dbfc9d86b` and archived reviewer `01a0afd4`.
BuildAgent installed corrected 0.1.19 without rebuilding and launched PID 71305;
installed native initialization/listing returned six tools with EOF exit 0. Package
bytes/digest remain unchanged. Operator `01a0afcc` fresh-turn metadata now exposes
preparation and all six coordinator worker functions with no loading error and zero
operational calls. The loading defect is resolved; actual onboarding/worker isolation/
STOP/recovery remain untested. Main UI is paused pending the owner's control response
after concurrent-change click rejections; operator remains on hold, no permission
change. This documentation-only checkpoint claims no overall acceptance; source/tests
stay frozen and prior unrelated validation remains terminal.
No worker product edit, retry, native/build/Git/live action or cleanup is included.

### Current bounded onboarding feedback correction

From Main's reported current source `ec860984` on the same branch/worktree, the owner
reports Resume Execution Setup appears inactive in the saved initialization flow.
Source confirms the button invokes prepare, preserves the saved preview and catches
errors; no silent saved-preview return was found. The confirmed feedback defect is
no in-progress indication, stale prior saved status and result/errors after the long
Codex prompt. No native failure or actual retry outcome is inferred. Main explicitly
released local progress/result/error feedback beside initial and resumed setup controls,
placing saved setup controls before the prompt and distinguishing a successful attempt.
Finish Initialization still verifies before completing. Core authority, registration,
preparation/finish and trust/security gates are unchanged.

The existing failed-setup regression now retries a still-failing saved preview and
asserts propagated detail, the same pending registration and refusal to finish until
recovery; it precedes UI changes, with no native red run claimed. Main/BuildAgent
checkpoint 24 reports individual passes for all 38 cases, app compilation and
documentation/index/diff checks. xcodebuild PID 77788 hung over ten minutes in
XCTHRuntimeProfileGenerationCoordinator runtime-profile directory enumeration;
the result bundle is unfinalized, with no TEST SUCCEEDED. BuildAgent terminated
the verified runner with SIGTERM; it exited 143 during runtime-profile finalization.
Logs/results are preserved. Overall command success is not claimed. Independent source reviewer
`01a0b001-e970` cleared the five-file candidate with no Required defects, finding inline
feedback, stale-status clearing, retry, success and error behavior consistent. Source
review is complete/archived through Main; source/tests remain frozen. Focused/source
checks do not prove runtime UI correctness. The onboarding-state mockup was inspected;
actual progress/success/error, accessibility and relevant-width visual comparison/QA
remain pending through Main's serialized runtime route. Core tests cannot prove visual
correctness; no new UI harness is added. Main awaits the owner's Finish Initialization
result, and no actual retry success/failure, overall build pass or overall acceptance
is claimed. The existing documentation result update is refrozen for Main→BuildAgent
scoped commit after runner status resolves; no additional check, retry or review is added.
No worker native/build/Git/live action, new artifact or cleanup.
Shipping plugin bytes/digest and catalog identities/purpose remain unchanged; prior
unrelated checks/reviews remain terminal.

Abrupt coordinator process loss without a retained worker handle or exit proof remains
an unresolved recovery barrier. Existing configuration-handle replacement requires old
worker closure and exact owned resource cleanup and cannot prove an unknown worker exit.
This slice adds no reconnect engine, process registry or universal recovery claim.

## Material risks and compatibility

Protect assignment/session/root identity, worker-readable snapshot integrity,
current context, permission ceilings, historical and sibling exclusions, exact
hook definition/handler trust, dirty-worktree refusal and uncertain outcomes.
Project file writes use RR’s authorized folder access; no assumed child-process
inheritance or hand-written Git metadata. Worktrees use app-owned storage grouped
by stable project/task identity. Register the hook once at the primary repository,
verify linked-worktree discovery/trust, preserve unrelated hooks and explicit
owner disablement, and stop launches on conflict/unavailability. STOP uses the
independent interrupt/control path without continuation hooks or automatic retry.
Assignment and package consumers require an explicit producer/read contract and
version compatibility; report migration/recovery implications in the owning
mutable design as implementation decisions become concrete. No existing worktree
migration is authorized. Only the disposable-project and necessary app/configuration
mutations reported by Main above are released through its serialized live route.

## Tests and acceptance

Use test-first focused repository-native tests of changed behavior, immediate
integration boundaries, failure/retry, assignment admission and exclusions. Main
routes native tests/builds to BuildAgent and documentation generation/checks to a
trusted route. Onboarding guidance changes require approved mockup comparison,
responsive/accessibility runtime checks and independent UX/QA coverage; source
inspection alone cannot establish them. Runtime/install/live-configuration checks
follow Main's separately reported live authorization above; unavailable inspection
and incomplete acceptance must be reported honestly.

Focused acceptance includes the reported repeated-delegation failure: an authorized
coordinator launches an in-scope worker through the integrated plugin/documented
App Server from a verified project assignment without the owner repeating that
same authorization in worker/coordinator tasks. Assignment admission carries only
the existing scoped authority; host/runtime approval policies remain in force.
Do not bypass gates, automatically escalate authority or promise their removal;
report the concrete supported limits separately from assignment admission.

Acceptance requires complete deterministic onboarding/plugin integration, verified
assignment admission before first and subsequent work turns, preserved exclusions,
working failure recovery and owned update/removal semantics, direct checks and one
independent architecture/security/code reviewer through Main→RO04 on a specified
candidate; add UX coverage if guidance changes. Only Required findings block.

## Delivery endpoint and shared execution

Endpoint: source (including the explicitly released 0.1.19 app/plugin version and
normalized digest), affected documentation, focused direct checks, independent review
and scoped local commit through trusted Git. The source worker performs no live action.
Main's subsequent owner-authorized installation/launch, plugin update and disposable
actual-flow acceptance follow the serialized route above. Direct SQLite writes,
unrelated owner-data changes, merge/main writes, release tags, push/PR and publication
remain excluded; Release Radar alone performs supported typed application mutations.

`shared-execution/1` applies. Installed shared-execution and tracking skill reads
were denied by the effective restricted filesystem; packaged source skill declares
standard 1 and supplies diagnostic context only. Repository-local authority,
independent material review, owner acceptance/external-effect and safety/recovery
fallbacks remain controlling. Main confirmed effective restrictions match
`rr-project-restricted`; the named profile label is not exposed to this worker.
All created documentation is durable in this repository. Catalog changes remain
pending application acceptance; checks imply neither acceptance nor synchronization.

## Dependency security correction

Main withdrew the preliminary libgit2 1.9.4 proposal after the owner reported
CVE-2026-53587. It was never added, vendored, linked or adopted. Main’s subsequent
authoritative finding is [upstream 1.9.5](https://github.com/libgit2/libgit2/releases/tag/v1.9.5),
which records the fix for CVE-2026-53587 and related vulnerabilities. Conditional
adoption now requires verified immutable upstream 1.9.5 or a later compatible
security-patched source pin, portable integration and normal license/distribution
review. Local Homebrew 1.9.4 is not a permitted product dependency. Native checks
remain routed through Main→BuildAgent; no helper authority expansion is allowed.

## Focused checkpoint result

Main/BuildAgent passed the corrected native worktree creation/removal case, four
affected adapter tests including cleanup failure remaining unknown, and real
transport initialize/hooks-list/close: six of six. The prior unchanged checks are
terminal. The hosted run has Xcode-injected rights and cannot establish production
app entitlements or external bookmark access. Main separately authorized one tiny
actual-source fixture with exact existing app entitlements, isolated HOME/CODEX_HOME
and project, read-only protocol calls and bounded close; BuildAgent owns compile,
sign and execution. No new endpoint, service, trust, real-home configuration or
owner-state mutation is included. Complete production integration and independent
review remain pending. The exact-entitlement bare executable compiled and passed
signature checks, then trapped in sandbox initialization before main; Main stopped
that unsuitable fixture approach. It neither invoked App Server nor established
actual app/API incompatibility. Checkpoints 7/8 verified strict single-plugin native
inventory and bounded fixture correction; frozen published package identity and
pre-existing version assertions remain distinct pending release concerns. Checkpoint
9 app dependency build and 16 focused setup/store/readiness/onboarding/hook checks
passed; source freeze is released. The setup actor preceded its tests, and no initial
red native run is claimed. Main resolved producer admission under existing explicit
owner onboarding/workflow direction, without another per-worker consent gate; see
the [exact owner wording and attributed interpretation](../../../design/outcome3-runtime-enforcement-assessment.md#existing-onboarding-authority-and-assignment-admission).
App-owned work identities/current policy authorize bounded delivery and independent
review through the existing envelope; eligibility and natural-language role claims
alone do not authorize work. Runtime UI, actual app
sandbox/bookmark access and complete integration/review remain unverified.

## First coherent source commit checkpoint

Main/BuildAgent corrected checkpoint 10 app build passed, with 26 focused checks
passing; the three lifecycle cases passed after a bounded fixture-schema correction.
The first candidate includes production observer/preparer injection, recovery
reconciliation and the strict registered AgentTools preparation route, with focused
route tests written before that wiring. Checkpoint 11 app build and 29 focused tests,
documentation and diff checks passed before Main/BuildAgent made scoped commit
`ffdd65601bd36852b801d79a2061a68f4c7548cc`. Its fresh independent review returned
four Required findings; it remains unaccepted. The bounded correction candidate adds
non-admissible preparation/final admission with exact-request revocation recovery,
startup reservation invalidation, independent known-run STOP/cleanup after uncertain
responses, and operation reservation before awaited follow-up readiness. Existing
project settings now expose owner-only hook update/removal with exact registration
audit, conflict preservation and a disabled workflow until deliberate recovery.
Main/BuildAgent checkpoint 12 passed the app dependency build and 34 focused tests
after the worker corrected one missing `await`; the initial compile failure ran no
tests. Documentation/index and diff checks passed. The scoped local correction
candidate is committed as `c1968a4dd99ad27f772fd9fd238abb325c74c350`; independent
R1–R4 correction review has no remaining Required findings. Its new hook-source
review remains separately pending; the current
result and limitations are recorded in the delivery ledger. Most focused hook/producer/adapter regressions preceded
their bounded corrections; command-route pause/deadline and owner-wrapper tests
followed their source, and no initial native red run is claimed. Runtime UI, actual
worker boundaries and the remaining profile/worktree lifecycle and explicit owner
recovery retain the complete original scope. Outcome 3 is not complete.
Subsequent coherent validated/reviewed slices should be committed
without waiting for whole-outcome completion, as the owner directed through Main.

## Owned lifecycle and explicit owner recovery checkpoint

The next coherent slice retires only owner-selected exact registered assignments
whose runtime connection is confirmed closed or never launched. It preserves dirty/
untracked work and referenced candidates, retains committed branches, and removes
only matching permission profiles through versioned configuration/readback. Protected
receipts retain the exact request, prior outcome state and completed steps for retry.
Unknown outcomes remain recorded after explicit retirement; replacement still needs
a fresh current-work admission. The owner may explicitly restore an unchanged removed
hook in existing settings; policy remains disabled until trusted verification, and
old stopped/unknown workers are not readmitted. Ordinary onboarding/update cannot
perform this resume. Exact registration/root intent and completion use app audit
operations. No new dashboard, generic command, live mutation or authorization engine
is introduced. Main/BuildAgent checkpoint 13 passed the app build and all 50 selected
tests (setup 13, producer 7, profile 2, worktree 3, assignment 5, adapter 12, lifecycle
4 and execution routes 4). Documentation/index and diff checks passed; BuildAgent
regenerated only the task-brief index. Product source/tests remain frozen for the
fresh independent cleanup review through RO04 and Main's scoped commit route.
Native results do not establish production permission or runtime UI acceptance. Lifecycle
regressions preceded their core source; expanded migration/owner-restoration checks
followed source, with no initial native red run claimed. Runtime responsive/accessibility
UI QA and actual app/worker boundaries remain open. Optional receipt fields preserve
legacy decoding; existing worktrees are not automatically migrated or retired.
Registration/root replacement or re-add recovery remains open; these operations
refuse stale identities and do not silently rebind prior authority.

## Required hook mutation-boundary correction

Fresh hook review of `c1968a4` by `01a0ad4c-9745-70d2-9366-153d4d6500c6`
identified a Required P1: registration changes during awaited configuration/trust
reads could precede stale trust/inline writes or an installed receipt. Carry the
existing exact registration/root validator to each actual hook configuration/trust
write after reads and connection initialization, pin the protected policy, and
recheck before receipts. Three focused suspended-call regressions precede this
bounded correction. Main/BuildAgent checkpoint 14 passed the app build and all 23
selected tests plus documentation/diff checks; native processes exited. The same
hook reviewer found no remaining Required or Optional issues, terminal for this
correction. Cleanup behavior
and its separate review remain frozen; R1–R4 are terminal and not reopened. No new
authority, runtime side effect or whole-outcome acceptance is claimed.

## Required cleanup corrections

Cleanup reviewer `01a0ad5f-6db0-7ed0-bde6-0f274bb35353` identified Required P1
ignored-file pruning risk and P2 premature completion before configuration closure.
Explicitly include ignored content in retirement cleanliness checks. Keep retirement
incomplete until closure is confirmed, retain its exact outstanding request/connection
marker and the app's original lifecycle/client, and allow only an explicit same-request
retry of that held connection. A missing original handle remains blocked rather than
claiming closure from a fresh client. Native content-preservation and close failure/
same-handle retry regressions precede the fixes; no native red run is claimed. Source/
docs are frozen for Main's affected checks, scoped commit and the same cleanup
reviewer's correction route. Main/BuildAgent checkpoint 15 passed the app build,
16 of 17 tests and documentation/diff checks; native processes exited. Worktree 4
and assignment 5 passed; producer 7 of 8 passed. The only failure observed close
counts 2/3 against expected 1/2. Its fixture shared a configuration object with the
producer, whose rejection path also calls finish, unlike separate production clients.
Correct the fixture ownership, retain 1/2 assertions and verify typed replacement
conflict and independent producer finish. No production code changes are required;
Main/BuildAgent's fixture-corrected checkpoint 15 passed producer 8/8 and
documentation/diff checks. Prior app/worktree 4/assignment 5 passes remain valid;
no production source changed for that correction. The cleanup review gate is cleared;
reviewer `01a0ad5f-6db0-7ed0-bde6-0f274bb35353` returned PASS with no remaining
Required or Optional findings in either correction. App build, all 17 affected tests
after fixture correction and documentation/diff checks passed; validation is terminal.
The candidate is ready for Main→BuildAgent's scoped local commit; product source
remains frozen and no commit is yet claimed. Runtime/UI acceptance, registration/root
replacement and re-add recovery, and application catalog acceptance remain open.
Outcome 3 remains incomplete. Hook P1 and R1–R4 remain
closed; no other feature, new recovery engine or live mutation is released.

Durable inputs include the pinned libgit2 source/license/notices/lock, module headers
and offline build script. Copied `plugins/coordinator-workers/` Python reference
material and the stopped `script/fixtures/execution_app_server.swift` are temporary,
excluded from candidate staging and retained pending authorized disposition. Native
`.build` dependencies/tools and `build` results are temporary. Main must verify
canonical repository persistence when committing; this worktree is not the final
durable delivery location. No scratch file is a controlling implementation artifact.
