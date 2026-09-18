# Outcome 3 project execution setup

## Objective and outcome

Integrate deterministic project execution setup into Release Radar’s existing
onboarding and plugin installation flows, including project-scoped worktrees,
protected assignments and production hook admission from verified assignments.
Preserve ordinary-worker history/sibling exclusion and deliberate Main retrieval.

### Current worker startup configuration investigation

Objective: finish actual RR-owned linked-worktree hook readiness and affected
worker startup without widening permission or trust boundaries. The prior
canonical-source correction is committed in `bff4899`, passed Native71's 18 tests,
compilation, documentation checks and independent review, and was installed with
owner authorization through BuildAgent checkpoint73. Both bounded tasks are
archived; their result remains in Git. This is not complete Outcome 3 acceptance.

The authorized RR hook update returned verified, and the original saved f481
preparation below succeeded with audit
`DE85859C-EFC0-402D-844C-BE8571C88C26`, its existing linked checkout and authorized
assignment. The first worker start then failed `invalidAssignment` with empty
effective settings and no thread ID. Supported status confirmed failure, and
supported close returned connectionClosed/threadId null for
`12311B93-0800-4E76-AAE1-121A235C4722`. Preserve the launch-reserved assignment
and original request; closure is not permission to repeat start or reset state.

Main's read-only configuration/account/hook comparison used the installed
0.155.0-alpha.2.6 App Server without creating threads, refreshing authentication
or writing configuration. Only presence/type/trust metadata was reported:
- Desktop context: account present, exact assigned profile absent, owned hook untrusted.
- RR sandbox context: account absent, assigned profile present, owned hook trusted.
- Effective profile keys include description, extends and workspace_roots as well
  as filesystem/network. WorkerPolicy.validate expects only the raw latter keys.
- WorkerAdapter.verifyHook still passes policy.primaryRoot directly, so the
  coordinator consumer also needs the canonical-source contract examined.

The complete boundary must be settled before implementing a partial profile-only
fix. A CODEX_HOME switch also changes authentication and state. Do not copy
credentials, blindly copy configuration or hashes, bypass profile/trust checks,
broaden installer-helper authority, or relax ordinary-worker exclusions.

Authoritative references:
- [App Server](https://learn.chatgpt.com/docs/app-server): effective config/read,
  named permission profiles and supported thread configuration.
- [Configuration precedence](https://learn.chatgpt.com/docs/config-file/config-basic):
  command-line overrides, trusted project layers and user configuration.
- [Environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables):
  CODEX_HOME owns config, authentication and state, not configuration alone.

Assignment: Main owns this existing brief/progress update on
`codex/worker-startup-config` from `bff4899` in
`/Users/jroberts/.codex/worktrees/rr-worker-startup-config/release_radar`.
Fresh Chief Architecture task `01a0b25e-bdfc-7b20-bac9-14b5b53f7862` investigates
the supported complete correction read-only, requested Astra/high (not exposed),
without owner config/credential inspection or live operations. Its recommendation
must preserve original Outcome 3 scope and classify necessary changes and unknowns.
No product implementation or additional live attempt is yet released.

Direct checks remain repository-native; the next material implementation requires
focused boundary tests and one appropriate independent review. BuildAgent owns
native checks and trusted Git. Record actual RR readiness and startup separately.
Catalog IDs/lifecycle/indexes and accepted ADRs remain unchanged; no new artifact
or mutable-document checksum is needed. Scoped local commits remain authorized;
push/PR, installation and subsequent live changes retain their explicit boundaries.

### Chief Architecture result and remaining decision

Chief Architecture completed its read-only investigation. The complete correction
needs one explicitly selected Codex execution context for setup, verification,
launch and retirement; normalized effective-profile validation that preserves the
exact filesystem/network ceiling and rejects meaningful inheritance/extra roots;
and canonical source matching in coordinator admission and follow-up. Keep raw
persisted profile ownership/removal checks distinct from effective API values.
Worker bootstrap also needs the existing explicit read-only default before the
assigned profile is selected. No trust hash or credential copying is proposed.

The smallest candidate is the authenticated desktop context, but actual signed
RR-process access is unverified. Source entitlements grant the app sandbox,
app-group, user-selected folders and network client; they do not explicitly grant
desktop Codex-home access. Release transport has no context-selection interface.
Therefore current code cannot perform the proposed selected-context readback,
and neither terminal access nor installer-helper access proves RR access. This
is a source limitation, not a newly observed runtime denial.

The alternative supported by official App Server documentation is the RR context
with Codex-managed authentication and recovery. This requires an integrated login
flow; redirecting the worker alone is incomplete. Changing access/installer-helper
authority, introducing authentication ownership, or choosing a new login experience
is not silently authorized by the investigation. Settle this product/security
boundary before releasing the complete source correction. Preserve all current
permission/trust checks and the closed failed assignment's reserved state.

No actual worker turn has run. Current official docs support configuration and
login contracts; the architect could not retrieve exact-version upstream source
and did not use moving-main source as installed-version proof. Exact normalized
field values, selected-process account/model readiness and reserved-assignment
recovery remain to be established through bounded checks once the route is chosen.

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
correctness; no new UI harness is added. Main subsequently reports the owner completed
initial test-project onboarding. Full runtime feedback verification, overall build pass
for checkpoint 24 and overall Outcome 3 acceptance are not inferred.
No worker native/build/Git/live action, new artifact or cleanup.
Shipping plugin bytes/digest and catalog identities/purpose remain unchanged; prior
unrelated checks/reviews remain terminal.

### Current bounded macOS root-alias correction

Documentation preview on the saved `/var` root is the next actual acceptance blocker.
Main/BuildAgent checkpoint 26 passed full validation/index checks on the same fixture
through `/private/var`; checkpoint 28 used the same installed helper through `/var`
and exited 1 with `unsafeFileType`. Checkpoint 27's XCTest fixture assumed the wrong
temporary root for the sandboxed host and is not causal evidence; that test edit was
removed. Actual helper comparison supplies the regression without fixture infrastructure.

Main authorized only narrowly verified system `/var` handling in the existing reader.
Preserve saved/request identity; require the root-owned alias, privileged non-writable
parent, exact `private/var` target and stable link metadata. Open the target and all
remaining components with existing no-follow/identity checks, including stable reopening.
No arbitrary symlink acceptance, canonicalization migration or permission change.
Main/BuildAgent checkpoint 29 compiled the reader, reports 65 passing cases including
containment/replacement and managed setup/security-scope/generation checks, and confirms
the newly built helper passes full validation/index checks through both spellings.
Seven existing preview fixtures fail creating `/Users/Shared` directories before the
reader (permission denied); the 72-case command exited 65, not an overall suite pass.
Two live-picker methods were explicitly excluded. No permission workaround or unrelated
fixture repair is included. Documentation/index and scoped diff checks passed. Independent Security/Privacy
reviewer `01a0b049` cleared the exact reader patch with no Required or Optional findings.
Main checkpoint 31 confirms actual preview after installing reviewed `b6dbefb7`:
repository `6fefe2e8-3a09-4fad-88cd-245061a67b65`, catalog v1, digest
`a09f5b2c8be9f2f1161ca56648600181648f579cbde97dd8567de91696186c50`;
documentation check/plugin capability passed. The separate binding was not committed
with `documentation.guidanceUnavailable`, exposing the v1-bootstrap/managed-binding
sequencing mismatch rather than another preview defect.

### Current bounded staging-guidance binding correction

Main selected the mutable specification amendment: exact shipped staging v1 permits
only the initial explicit binding before the separately authorized audited guidance
upgrade. Preserve fully validated matching catalog/root/registration, conflicts,
audit/replay/rollback and all other managed-operation gates. No global mode change,
preactivated fixture, governing instruction, accepted ADR, packaged skill/copy or
package identity change. Scope is the dispatcher, existing managed-operation tests,
managed-documentation contract and these three Outcome 3 documents.
Test-first existing container-writable fixtures cover owner preview/bind, legacy
preservation/closed managed operations, audited upgrade, bad staging/targets and
rollback/replay. Main/BuildAgent checkpoint 32 compiled/executed the owner-sequence test
and reached the exact `command(documentation.guidanceUnavailable)` failure before
dispatcher edits (one unexpected failure, terminal exit 65). The bind-only correction
now reuses exact staging inspection and full catalog/target checks; global managed
snapshot/mode gates are unchanged. Checkpoint 33 compiled the app and passed 11 of 12
selected cases, including the two other new cases and nine existing safeguards;
documentation/index/diff checks passed. Initial binding succeeds. The lifecycle test
then used its legacy fixture registry after registering the project and was correctly
rejected by identity gates. Only that fixture now uses the registered project and
matching request tuple; production is unchanged. Checkpoint 34 passed the corrected
lifecycle test (one test, zero failures, terminal exit 0); the prior 11 passes remain
valid. Documentation/index/diff checks passed. Fresh reviewer `01a0b063-6d28` cleared
the complete six-file patch with no Required or Optional findings; that reviewer is
archived after its result was preserved. Checkpoint 36 verified installed `dce76787`,
app `0.1.19`; exact package identity/CDHash/PID are recorded in progress. Main opened
the saved disposable project. After the owner added `Outcome3Acceptance`, exact-root
Local bootstrap task `01a0b081` appended the exact staging v1 block, preserving all
332 original instruction bytes (final 1192). Packaged checking passed and catalog
bytes were unchanged. The authorized root is
`/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project`.
Main observed staged v1, previewed the same exact project/root0/repository/catalog/
digest and confirmed binding in installed `dce76787`; the UI reports committed owner
audit `9A68179F-2B10-4268-AA7C-24837A0BAD8D`. Bootstrap and initial binding are verified,
resolving the previous root/binding blockers. Handoff task `01a0b086` wrote the exact
v3 span, preserving 334 outside-span bytes, the 175-byte ledger, catalog, indexes and
README; packaged checking passed. Its single audit call returned `appUnavailable`
with empty entity IDs, without success or retry. Main's responsive UI reports managed
handoff incomplete v3. BuildAgent established that helper registration serialization
uses an object project ID although `ProjectID` Codable expects a string, causing
callback decode failure before mutation. No permission/socket/signature defect is
established. Checkpoint 37 compiled/executed the direct callback regression with the
expected two assertion failures (one test, terminal exit 65), before production edits.
The helper now emits the string; the coupled preparation guard accepts strings and
retains exact registration keys, rejecting obsolete objects/extra fields. Existing
authorization/identity validation and public arguments remain unchanged. Scope is
these three documents, helper emitter, application callback guard and existing
transport tests; no new harness. Checkpoint 38 passed all five targeted tests,
including both new regressions, signed-helper integration, malformed inputs, lost
reply and exact replay (`TEST SUCCEEDED`, exit 0). Documentation/index and six-file
diff checks passed. Fresh reviewer `01a0b09b-4e49` cleared the six-file patch with no
Required or Optional findings. The correction is committed as `bcdb869543b4bd2648e9bc2023dcb12123cf6a8b`;
checkpoint 40 verified 0.1.19 installation and launch. After the hosting ChatGPT
process restarted, Main verified fresh helpers mapped installed inode 41264196.
Original task `01a0b086-4199-7233-9911-879d7b9caa5a` replayed the unchanged request once:
`isError=false`, audit `54096E50-DB79-4838-8049-867FC9DA9C76`. It is idle/completed.
The disposable fixture baseline is committed as `c14efa2e5fb43ee1e634dfd015e1eb6277c69f8e`
on `codex/outcome3-acceptance`, changing only `AGENTS.md` to retain the earlier authorized
v3 guidance and exact installed shared-execution v1 declaration. Fresh reviewer
`01a0b0f8-8df3` found no Required findings; Main's UI readback confirms Compatible with
V1. Packaged documentation and scoped diff checks passed. Existing README, ledger,
catalog, generated indexes and historical isolation sentinel are unchanged; live
`.codex/hooks.json` and `default.profraw` remain untracked and excluded. Next is actual
registered synthetic work/assignment startup and isolation acceptance; full Outcome 3
remains open.
Native/Git/live operations remain with Main/BuildAgent.

<a id="pending-disposable-handoff-audit"></a>

### Completed disposable handoff audit

The unchanged `release_radar_add_evidence` request below is the completed recovery
record. Supported inventory is complete and managedV3, matching repository
`6fefe2e8-3a09-4fad-88cd-245061a67b65`, catalog version 1 and digest
`a09f5b2c8be9f2f1161ca56648600181648f579cbde97dd8567de91696186c50`, with the
unchanged accepted binding and exactly one available ticketless evidence row resolving
the saved `/var` root's `AGENTS.md`. Packaged checking passed; shipped v3 preserves
334 outside-span bytes (333 prefix, one suffix), and the 175-byte ledger, catalog,
README and indexes are unchanged. No further replay is pending.

```json
{
  "version": 1,
  "id": "release-radar-handoff:v1:50073b59-4c94-40c0-8879-0d3dc503dd68",
  "path": "AGENTS.md",
  "projectRoot": "/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project",
  "reason": "Upgrade the exact staged v1 Release Radar guidance span to shipped v3 in the separately owner-authorized disposable project; preserve unrelated instructions and the delivery ledger.",
  "registrationID": "60089feb-7d4a-4503-9543-0c281be6b8fc",
  "registrationProjectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
  "requestGeneration": 1,
  "requestID": "836c2e20-3f6e-481e-8c38-1dec8cbcfab1"
}
```

<a id="pending-synthetic-work-registration-requests"></a>

### Committed synthetic work registration requests

Main executed the following unchanged envelopes in order. Audits: phase
`0443110C-4BCF-4EF4-8AF8-7607C3D71001`, ticket
`F6C39032-E855-4244-BDF2-6C854EBE9148`, task plan
`2788193E-4C72-45CB-99DA-49FEC0ED6E8E`, returning task-plan revision 1. Fresh complete
inventory confirms one Unassessed phase at lifecycle revision 0, one backlog ticket
and one Active Pending task at revision 1, with unchanged registration. Main's Project
Plan readback shows Draft plan revision 1, 0/1 covered. These completed recovery
requests assert no task completion or whole Outcome 3 acceptance.

```json
[
  {
    "method": "release_radar_upsert_phase",
    "arguments": {
      "version": 1,
      "projectRoot": "/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project",
      "registrationID": "60089feb-7d4a-4503-9543-0c281be6b8fc",
      "registrationProjectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
      "requestGeneration": 1,
      "phaseID": "outcome3-acceptance-phase",
      "name": "Outcome 3 synthetic execution acceptance",
      "reason": "Create the sole synthetic phase for the owner-authorized disposable Outcome 3 worker startup, isolation, STOP and recovery acceptance.",
      "requestID": "af7eb713-3062-4b36-abd6-992d9d4eacf5"
    }
  },
  {
    "method": "release_radar_upsert_ticket",
    "arguments": {
      "version": 1,
      "projectRoot": "/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project",
      "registrationID": "60089feb-7d4a-4503-9543-0c281be6b8fc",
      "registrationProjectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
      "requestGeneration": 1,
      "phaseID": "outcome3-acceptance-phase",
      "ticketID": "outcome3-acceptance-worker",
      "lane": "backlog",
      "outcome": "Verify RR-owned worker startup in the assigned checkout, role permissions, history and sibling exclusion, production hook admission, STOP and recovery using only synthetic fixture data.",
      "reason": "Register bounded synthetic work required by the approved disposable Outcome 3 acceptance; no product delivery completion is asserted.",
      "requestID": "9b5f63b3-efbe-4ec9-9b93-415c89e621e6"
    }
  },
  {
    "method": "release_radar_revise_ticket_task_plan",
    "arguments": {
      "version": 1,
      "projectRoot": "/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project",
      "registrationID": "60089feb-7d4a-4503-9543-0c281be6b8fc",
      "registrationProjectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
      "requestGeneration": 1,
      "ticketID": "outcome3-acceptance-worker",
      "additions": [
        {
          "id": "outcome3-acceptance-worker-task",
          "label": "Execution acceptance",
          "title": "Verify RR-owned worker startup in the assigned checkout, role permissions, history and sibling exclusion, production hook admission, STOP and recovery using only synthetic fixture data.",
          "sortOrder": 0
        }
      ],
      "reason": "Define one Pending task for the approved synthetic execution acceptance so RR can derive a protected assignment. No task completion is asserted.",
      "requestID": "d16e06cb-54aa-4e31-89bf-1d10e32ea89f"
    }
  }
]
```

<a id="pending-synthetic-phase-plan-request"></a>

### Committed synthetic phase plan request

Main applied the unchanged envelope below: revision 2, audit
`BF4346E4-E786-48D9-917B-BE6A7CDC796B`. Finalize request
`8524f69f-e714-445a-b2e9-25c56ef06824` committed revision 2, audit
`1D8139C9-CA0E-4DC5-B69F-AA5BCB18B8C4`. Main's UI moved the synthetic phase through
Upcoming to In delivery. Fresh complete supported inventory confirms lifecycle
revision 2 / `in_delivery`, task-plan revision 1 with Pending task and backlog ticket.
No completion is asserted.

```json
{
  "version": 1,
  "projectRoot": "/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project",
  "registrationID": "60089feb-7d4a-4503-9543-0c281be6b8fc",
  "registrationProjectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
  "requestGeneration": 1,
  "requestID": "50556aa6-2f8b-49f6-91c2-621d75a7676d",
  "projectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
  "phaseID": "outcome3-acceptance-phase",
  "expectedRevision": 1,
  "reason": "Define the sole synthetic acceptance goal and ticket coverage for the approved disposable worker lifecycle test.",
  "goalUpserts": [
    {
      "id": "outcome3-acceptance-goal",
      "title": "Verify controlled synthetic execution",
      "outcome": "Establish actual worker startup, scoped permissions, hook admission, STOP and recovery without accessing owner data.",
      "doneCriteria": [
        "The assigned checkout and effective worker permissions are verified.",
        "Historical and sibling isolation and deliberate Main retrieval are exercised with synthetic data.",
        "STOP and supported recovery are observed without claiming unknown outcomes succeeded."
      ],
      "sortOrder": 0
    }
  ],
  "assignments": [
    {
      "goalID": "outcome3-acceptance-goal",
      "ticketID": "outcome3-acceptance-worker"
    }
  ]
}
```

### Pending synthetic assignment request

Main initially executed `release_radar_prepare_execution_assignment` once with the
unchanged envelope below. It returned `isError: true`, `entityIDs: []` and
`error.internalFailure._0`:

> failed to resolve feature override precedence: config defines `[permissions]` profiles but does not set `default_permissions`

No assignment or worker ID was returned and no `worker_start` was issued. Partial
resources remain unverified; BuildAgent preserves the exact request without replay. Preparation
and startup acceptance remain unresolved.

Main verified the real host config is valid, with `default_permissions` set to
`:workspace`, three owner profiles and no legacy sandbox settings. The actual failing
RPC and selected config layer are not established. Existing diagnostics retain only
the error message; the app's stderr resolves to `/dev/null`. The container config
read stalled and was cancelled without contents or explicit denial; do not retry that
file or route around access. This is not evidence that its contents caused the failure.

Main approved only a bounded existing setup error-context correction through
Restricted02/sourceworker: preserve the operation, any already-known target path and
failure/unknown semantics, without sensitive payload or error data. No new diagnostic
endpoint, harness, engine or global config change is released. No original assignment
retry is authorized for BuildAgent.

Native checkpoint 41 established attributable RED against the no-op formatter: the
two error-context tests compiled and executed, with 12 expected assertion failures and
`xcodebuild` exit 65. Checkpoint 42 verified the frozen three-file correction: the same
two tests plus existing conflict/close and uncertain-close/same-connection checks passed
4/4, zero failures, `xcodebuild` exit 0. Both runs used the established signed-host
runner with coverage disabled. Assertions cover operation/readback and known safe target,
original failure and both unknown-outcome flags, sensitive-payload exclusion and omitted
missing/relative/control-character targets. The cleanup checks use local mock-config
fixtures; no live App Server/home or original assignment request was exercised.
Documentation/index and scoped diff checks passed. Temporary native logs, result bundles
and checker profiles remain retained. Initial reviewer creation returned only
`client-new-thread:cd018a57-af90-47a8-b41c-6049aae5caa8`, without an actual task ID,
status or error; Main could not initially confirm a running review and asked the owner
for visible setup status without creating a duplicate. Main now reports the same review
required a handshake-label correction. The refrozen client advances from `initialize`
to `initialized` only after successful initialization, before sending the notification.
Checkpoint 43 ran only the directly affected operation/known-target test, including both
handshake labels for both unknown-outcome values: 1/1 passed, zero failures, exit 0;
current target/callsites compiled and scoped diff check passed, coverage disabled.
Previous payload/cleanup/recovery checks stand. Main reports the same independent
reviewer `01a0b10e` completed the correction check through RO04, cleared P2 and is idle,
with no remaining Required or Optional findings; Main reports the cleared reviewer
is archived. Main released a scoped commit of the
three reviewed source/test files and two owned documents, followed by strict staging,
verification, installation and launch of the approved 0.1.19 acceptance candidate.
No version bump, tag, DMG, push, PR or plugin change is released for this intermediate
candidate. BuildAgent retains the exact original request without replay or manual
configuration changes; Main owns resuming the supported request route.

The five-file scoped commit is `1efc304ddc869caf4aa20d6890fa67a26a5e2c11`.
Checkpoint 44 passed strict Release staging; checkpoint 45 passed no-rebuild strict
installation and launched `/Applications/ReleaseRadar.app` as version 0.1.19/build 1
(observed PID 24876). Installed app/helpers and signed resource manifest match the
staged candidate. App CDHash is `84a77c3db64953cefa48821e739c7a8700b71698`;
Coordinator CDHash is `73c0a0d76d91ec279ca63cde7c7305d84cca10e1`, with hardened runtime
and only the existing application-group entitlement. Source, staged and installed
plugin digests agree and remain unchanged. Temporary stage/install logs are retained.
During BuildAgent delivery, no version/tag/DMG/push/PR, plugin lifecycle, manual config
change or original request replay occurred. Candidate installation is confirmed.

Main subsequently replayed the exact saved `f481e256-3332-43aa-88e1-4c3dd2c6368a`
request once: `isError: true`, `error.appUnavailable: {}`, `entityIDs: []`. No assignment
or worker ID was returned and no worker start followed. The request remains unchanged
and pending; partial resources and preparation/startup remain unresolved.
At that time, read-only diagnosis found app PID 24876 running and five AgentTools
processes mapping pre-install inode 41264196 at the prior backup path, versus installed
inode 41311803, under app-server PID 9217 / ChatGPT host PID 9048. Those mappings did
not establish the failure cause; AgentTools code identity was unchanged and the failed
connection was not individually identified. The owner was asked to refresh ChatGPT.

The owner explicitly resumed after that refresh. Main confirmed old host/app-server
PIDs were absent and replayed the exact unchanged request again; it still returned
`appUnavailable` with empty entity IDs and no assignment/worker/start. Fresh read-only
diagnosis found RR absent; helpers 26466 and 26941 both map current installed inode
41311803 under app-server 26105 / ChatGPT host 25954. Existing logs show the prior RR
callback connection cancelled/exited at 17:18:44 and a fresh tools connection activated
at 17:19:50; no fresh helper mismatch or blocked XPC handshake is established.
Under Main's conditional launch authorization, BuildAgent rechecked exact RR absence
and launched the approved installed candidate (observed PID 27316). No install,
rebuild, manual config/SQLite action or request replay was performed by BuildAgent.
After that launch, Main replayed the exact unchanged request through the supported
route. It returned `internalFailure` with `Execution setup config/read (cwd: ...):`
for the exact saved `/var` fixture root, followed by the same permissions/default
precedence error recorded above. Entity IDs were empty and no worker start followed.
This identifies the first `config/read` after successful initialization, not readback;
no config write was reached on this attempt. The effective failing config layer is
not established. Main released the next bounded source candidate through Restricted02:
the RR setup AppServer subprocess explicitly selects `default_permissions=":read-only"`
with the supported per-run `-c` override. It does not authorize owner-config edits or
expand worker-role permissions. Main reports fresh independent reviewer `01a0b145`
cleared the frozen three-file patch over `797a2046`, with no Required or Optional findings.
Owner config, versioned writes, cleanup and explicit worker roles remain preserved;
GREEN checkpoint 47 is terminal. Main released the five-file scoped commit and strict
stage/verify/no-rebuild install/launch of this approved 0.1.19 acceptance candidate.
No version bump, tag, DMG, push, PR or plugin change is released. BuildAgent verifies
the actual installed main process and whether AgentTools bytes changed, without assuming
a host restart is needed. Original exact request replay remains held; this is the setup
management-selector correction, not completed actual worker startup.
The five-file source commit is `45b611479fd8f9f193cf40181db51233abcbeade`.
Checkpoint 48 passed strict Release staging; checkpoint 49 passed no-rebuild strict
installation and explicit launch as `/Applications/ReleaseRadar.app` 0.1.19/build 1.
Exact process readback confirms installed main PID 33495. Installed app/helpers and
signed resource manifest match stage; signing identifiers/team, hardened runtime and
Coordinator's sole existing application-group entitlement passed. App CDHash is
`705ed186ef2370991e3bf9d74092b59d1e0bbd70`; Coordinator is
`d68ca55d6fdd982b0d790c5a93cd8d235aa3598a`. AgentTools bytes did not change from the
prior installation; source/staged/installed plugin digest also remains unchanged.
During BuildAgent delivery, no host restart, original exact-request replay, manual
config/SQLite change or release publication occurred. Temporary stage/install logs remain
retained.
Main's post-install 49 exact request replay returned `appUnavailable`/empty entity IDs,
with no assignment/worker start. Current read-only diagnosis confirms RR PID 33495 alive.
Around that replay, broker 33502 logs tools peer 26466 rejected at 17:49:18.941:
"Received message forbidden due to code signing requirement: <private>". Peer 26466
maps retained helper inode 41311803 versus installed 41331855, under app-server 26105 /
ChatGPT 25954. The rejection establishes a tools XPC signing-gate failure; private
signing detail does not establish inode mismatch as its cause. App bridge peer activation
is logged, but callback registration is not directly confirmed. No automatic restart,
relaunch, manual kill or further BuildAgent replay is released. The unchanged request,
unknown partial resources and actual startup acceptance remain pending.

After the owner refreshed the host and resumed, Main confirmed RR PID 33495 running
and fresh AgentTools PIDs 35207/35566 mapping installed inode 41331855. Main's next
unchanged request returned `execution.hookNotReady`, empty entity IDs and no worker
start. Existing logs show new tools peer 35566 activation on broker 33502 at
17:56:00.462 and concurrent RR activity. The bounded 17:55:45–17:56:30 info/debug
capture exposes no specific hook discovery, project-trust or root failure; the earlier
17:49 signing rejection belongs to old peer 26466. No signing/config error was returned
on the latest attempt, which does not independently prove effective permission-profile
success. Main's subsequent read-only UI inspection confirmed the exact project has
current guidance v3 / Compatible V1 and Manage Project Worker resources shows the
synthetic assignment in `preparing` state. A partial assignment is therefore present;
the UI exposed no assignment ID, and other partial resources remain unverified. No
Update, Resume or Retire action was clicked. The exact request is preserved; hook
readiness and startup remain pending. Main selected fixed OSLog messages at the existing
hook-readiness failure guards in two source files, preserving the exact `hookNotReady`
wire response and guard predicates. No callback, reason enum, classifier, harness or
schema is added. The worker froze the two-file patch; checkpoint 50 ran the three
existing `ProjectExecutionReadinessTests` and the pending-owned-hook, recovered-binding
and conflicting-pending-edit setup tests in the established signed host with coverage
disabled: 6/6 passed, zero failures/unexpected, Xcode exit 0. Current target/callsites
compiled; scoped diff and documentation checks passed. This verifies existing readiness,
safety, error/receipt and cleanup behavior, not exact encoded wire behavior at runtime;
the wire enum/mapping is untouched. No log-string tests, new harness or unaffected
Producer regression repeat was added. Independent reviewer
`01a0b164-a653-70b2-ab9a-8b6cb8611dd1` completed review of the exact frozen two-file
patch over `45b611479fd8f9f193cf40181db51233abcbeade`: Required none, Optional none;
literal-only logging preserves predicate order, typed errors, RPC/trust writes, cleanup
and partial state. Main confirmed the reviewer idle and archived after preserving the
result in `51b8909`. Main released the scoped four-file source/docs commit and established
strict staging, verification, installation and launch of the 0.1.19 acceptance candidate.
Checkpoint 50 remains terminal; no repeated tests. No tag, DMG, push, PR or cleanup is
released. The saved request and UI-confirmed partial `preparing` assignment remain
unchanged; BuildAgent does not start a worker or mutate an assignment.
Scoped four-file commit `51b89098312e24f52a4d6d36bfd81ee3cbac9464` passed strict Release
staging at checkpoint 51 and no-rebuild installation at checkpoint 52, both exit 0.
The installed `/Applications/ReleaseRadar.app` is 0.1.19/build 1 and launched as exact
main PID 42674. Installed main/Core/helpers/resource-manifest hashes match stage;
identifiers/team, hardened runtime and Coordinator's sole application-group entitlement
passed. AgentTools and Coordinator binary bytes remain unchanged; source/staged/installed
plugin digest remains `6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35`.
The fixed `com.rekonlabs.ReleaseRadar` / `ExecutionSetup` logs are installed for Main's
exact saved request. No host restart, BuildAgent request replay, worker start, assignment
mutation, owner config/SQLite change or release publication occurred.
Main's post-install 52 replay of the exact original request returned `isError: true`,
`appUnavailable`, `entityIDs: []`; no `worker_start` followed. Main's fresh read-only
inspection confirms app PID 42674 alive and bridge PID 42696 logging at
2026-09-17 18:15:11.324: "Received message forbidden due to code signing requirement:
<private>". AgentTools PID 35566 still maps
`/Applications/.ReleaseRadar.backup.41978.26095/Contents/Helpers/ReleaseRadarAgentTools`,
inode 41331855, versus installed current inode 41345698. This confirms recurrence of a
retained helper executable after replacement alongside a signing rejection; the private
signing cause is not established. At that attempt Main observed no ExecutionSetup hook
log and requested a host restart, with no bypass. After the owner confirmed Codex restart,
Main replayed the exact saved request: it reached installed RR PID 42674 and returned
`hookNotReady`, `entityIDs: []`; no worker start. Main observed at 18:20:33.021,
subsystem `com.rekonlabs.ReleaseRadar`, category `ExecutionSetup`:
"Hook readiness failed: owned hook identity or handler is missing, mismatched or duplicated",
then "Hook verification failed: first hooks/list readiness check". The current connection
blocker is cleared; the first `hooks/list` owned identity/handler matching is the current
failure, with the exact failing predicate not yet identified. Main reports the sourceworker's
tagged 0.154 official App Server schema/discovery inspection agrees with the existing
matcher; this does not establish the runtime cause and warrants no semantic fix.
Main authorized refinement only of existing matcher failure logs to distinguish empty or
duplicate hooks and field mismatch, using literals only. No new test fixture, harness,
API, config or trust change is authorized. The one-file `ProjectExecutionHookReadiness.swift`
refinement froze with only the candidate-count failure branch changed (24 insertions,
one deletion); the original filter/order/count and `hookNotReady` remain unchanged.
Checkpoint 53 ran all three existing readiness tests plus
`testPendingOwnedHookResumesSameConsentAndPreservesUnrelatedGroups` in the signed host,
coverage disabled: 4/4 passed, zero failures/unexpected, Xcode exit 0. Target/callsites
compiled and scoped diff check passed; no log-string tests, harness or unrelated repeat.
This verifies existing readiness/safety/consent behavior, not exact encoded wire runtime
coverage or the live failing predicate. Main reports the same-outcome reviewer
`01a0b164` restore failed with a fatal missing-`AGENTS.md` environment error; no file
state is inferred beyond that error. RO04 rearchived it. Main subsequently correlated
queued client `d634035e-4c79-4e7c-8247-65ce972b3b0a` through local Codex logs to actual
reviewer `01a0b17a-2321-7f60-9715-5a0f0ba12400`; task readback confirms review completed
at 18:26:24 in worktree `614e`, with no Required findings. The task-list omission was not
a setup failure. Review confirmed literal-only privacy, progressive-prefix correctness
and unchanged admission/error behavior; checkpoint 53's four passing tests are attributed
without rerunning. Main released the exact three-file source/docs commit and strict
0.1.19 acceptance stage/install/launch. No tag, DMG, push, PR, main mutation or cleanup
is released. Frozen patch, original request, partial assignment and owner config remain
preserved; Main owns replay. Scoped three-file commit
`4e4ccd4d27e8ff8d63ea44318746f5f4fe810ec7` passed strict Release stage 54 and no-rebuild
install 55, both exit 0. Installed `/Applications/ReleaseRadar.app` 0.1.19/build 1 launched
as exact main PID 50402; app CDHash is `26184fb348222a4fd5bdd0e5467c64df0d6b64bc`.
Installed main/Core/helper/resource-manifest hashes match stage; signing identity/team,
hardened runtime and Coordinator's sole existing application-group entitlement passed.
AgentTools/Coordinator bytes remain unchanged; source/staged/installed plugin digest
remains `6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35`.
The refined literal ExecutionSetup logs are installed for Main's saved request. No
BuildAgent replay, host restart, worker start, assignment/owner-config/SQLite mutation,
release publication or cleanup occurred. Main's post-install 55 exact request replay
returned `appUnavailable`, `entityIDs: []`; no worker start. Main observed bridge PID
50424 signing rejection at 18:33:47.907: "Received message forbidden due to code signing
requirement: <private>"; no ExecutionSetup failure was reached. Main reported recurrence
of the post-replacement host/helper connection issue and requested host refresh; the
private signing cause remains unestablished. After the owner restarted Codex, Main's
next exact saved request reached RR PID 51330 and returned `hookNotReady`, empty entity
IDs and no worker start. Direct logs at 18:35:44.555 report "Hook readiness failed: no
hooks were discovered", followed by "Hook verification failed: first hooks/list readiness
check". Empty hooks is the current confirmed blocker, rather than an identity-field or
duplicate mismatch. Primary project trust and response checkout/errors/warnings guards
passed; later readiness gates were not reached. Restricted02/sourceworker are assigned
narrow producer/discovery diagnosis. Main reports tagged 0.154 discovery is filesystem/
trust based; a later Homebrew Git execution denial is not a demonstrated cause of empty
hooks. Main authorized one best-effort `config/read` of the execution checkout through
the same retained setup child only after the first supported empty-hooks failure, with
fixed feature true/false/unspecified and checkout-project-layer/inline-presence categories;
no effective-default, managed-only or root-mapping inference. The frozen one-file
`ProjectExecutionSetupClient.swift` patch adds 59 lines, preserving the original error;
no matcher/API/config/trust mutation, endpoint, fixture or harness change.
Checkpoint 56 ran the existing pending-owned-hook/same-consent and conflicting-pending-
edit/close setup tests once in the signed host, coverage disabled: 2/2 passed, zero
failures/unexpected, Xcode exit 0. The new async branch/current callsites compiled and
scoped one-file diff check passed. Main reconciled parallel dispatch to this single run;
unchanged readiness tests at checkpoint 53 remain terminal. These protocol-fake tests
verify baseline gates/consent/cleanup and do not dynamically exercise the new production
observation. No log-string tests or new fixtures were added. Independent reviewer
`01a0b18b` cleared the exact 59-line SetupClient patch over `4e4ccd4d`: Required none,
Optional none; privacy/literal projection, first-empty trigger, same-child read, original
`hookNotReady` and cleanup are preserved. The added read uses the existing transport's
30-second deadline and may delay cancellation/cleanup up to that response wait; this
existing timeout design was acknowledged without a new Required defect. Actual production
observation remains pending. Main released the exact SetupClient/two-doc scoped commit and
strict 0.1.19 acceptance stage/install/launch, with no tag/DMG/push/PR/main mutation or
unrelated cleanup. Checkpoint 56 remains terminal; Main owns the exact-request replay.
Scoped three-file commit `2b038cc161bb38761fe2bab4beb4849e34a71c76` passed strict Release
stage 57 and no-rebuild install 58, both exit 0. Installed `/Applications/ReleaseRadar.app`
0.1.19/build 1 launched as exact main PID 58011; app CDHash is
`1da4bd2054a0ca045202f20fa27b6ead761809fd`. Installed main/Core/helper/resource hashes
match stage; signing identity/team, hardened runtime and Coordinator's sole existing
application-group entitlement passed. AgentTools/Coordinator bytes and source/staged/
installed plugin digest remain unchanged. The first-empty same-child observation is
installed but not dynamically verified. No BuildAgent replay, host restart, worker start,
assignment/owner-config/SQLite mutation, publication or unrelated cleanup occurred.
Main's post-install 58 replay of the original request returned `appUnavailable`, empty
entity IDs and no worker start. Main observed bridge PID 58033 signing rejection at
18:53:42.601 (private requirement detail) and no ExecutionSetup logs. The recurring
post-replacement connection blocker is current; the private signing cause remains
unestablished and the production observation is pending. No unchanged retry, new checks,
build or install follows. Main confirmed reviewer `01a0b18b` idle/completed and archived
it after preserving the result in `2b038cc`. Exact request and partial assignment remain
intact. Temporary stage/install logs, native log/result bundle and checker profiles are retained.
Prior source `4e4ccd4` checks and checkpoint 53 remain terminal; exact request and
partial assignment stay preserved. Actual hook readiness/startup remain pending. Temporary stage/install logs,
native log/result bundle and checker profiles are retained.
The saved request and partial `preparing` assignment are preserved; readiness and startup
remain pending. Stage/install
logs are temporary and retained. Temporary native
log/result bundle and checker profile are retained. No new state/API, hook-trust mutation
or request replay is released.
BuildAgent performed no replay or live/config/SQLite mutation.

At 21:07:58 EDT, the exact saved request reached the fresh installed AgentTools peer and
returned `hookNotReady` with no hooks; the existing first-empty-hooks diagnostic reported
the exact checkout project layer as disabled with `reason: unrecognized`. This is a
diagnostic inadequacy, not root-cause proof. The bounded corrective worker is attached to
`codex/hook-disabled-reason-detail` at
`ded65f2b733641384df36514267824b4c81ddb0a`. It replaces the two-template classifier
with control-normalized, capped retained reason text. Before capping, it redacts only
known exact checkout, primary-root, user-home and user-config identifiers. The untrusted
text is public at the existing first-empty-hooks OSLog sink, remains non-authoritative,
and does not expose configuration, hook commands or a new diagnostic endpoint. The
original `hookNotReady`, same-child transport, identity, trust/write, retry and cleanup
behavior remain unchanged. Focused helper tests cover unknown-text retention, control
normalization, exact redaction, empty text and capping; BuildAgent owns native checks and
the scoped local commit, with one fresh RO04 privacy/correctness review required. Live
replay and configuration mutation remain excluded. This is not universal secret
scrubbing: it is proportionate redaction for the installed trust-message producer only.
Checkpoint 64 passed all five focused App Server tests, including retained-text coverage.
After the required raw-redaction-order correction, checkpoint 65 passed the directly
affected regression, target compilation and diff checks. The same independent reviewer
confirmed the Required defect resolved with no new defect. The actual live hook cause
remains unknown; no retry or installation occurred. The completed reviewer is to be
archived after Main's scoped local commit, but is not yet claimed archived.
Checkpoint 59 ended before tests (Xcode exit 65) because this fresh worktree lacks the
libgit2 header/module dependency. It applies only to the superseded category candidate
and establishes no corrected-candidate behavior; retained native output is temporary.

Checkpoint 46 established attributable RED with the original setup arguments: only
`testSetupTransportReadsPermissionTablesWithoutChangingOwnerDefault` ran in the existing
signed/sandboxed host against actual verified Codex with isolated HOME/CODEX_HOME. Its
first `config/read` reproduced the exact feature-override/missing-default rejection;
one expected failure, zero unexpected, exit 65. Checkpoint 47 ran the same test once
with the process-local selector: 1/1 passed, zero failures, exit 0. Initialization and
`config/read` succeeded, effective `default_permissions` was `:read-only`, the existing
fixture profile retained root denial/network disabled, and fixture config bytes stayed
identical. Current target/callsites compiled and scoped diff checks passed; coverage was
disabled. Main confirmed this covers the immediate shared-arguments boundary and
withdrew the optional second initialization run. Prior context/cleanup checks remain
terminal. Temporary logs/results are retained; alias/untrusted-project advisories did
not cause test failures and no trust/config workaround was applied. This verifies the
isolated candidate, not the missing real effective default or actual worker startup.

Official references checked on September 17, 2026:
[App Server configuration API](https://learn.chatgpt.com/docs/app-server) documents
layered effective `config/read`; [per-run configuration overrides](https://learn.chatgpt.com/docs/config-file/config-advanced#one-off-overrides-from-the-cli)
document arbitrary `-c` overrides with TOML values. Current upstream
[config processor](https://github.com/openai/codex/blob/main/codex-rs/app-server/src/request_processors/config_processor.rs)
reads config layers before loading runtime Config and adds the observed feature-override
prefix to runtime-load failures. [Core configuration](https://github.com/openai/codex/blob/main/codex-rs/core/src/config/mod.rs)
rejects profiles with no selected default. This supports the diagnosis; it does not prove
which installed config layer failed. These upstream URLs track moving `main`; no pinned
revision or installed-binary source equivalence has been established.
The unchanged request and unknown partial resources remain preserved; preparation/startup
and full Outcome 3 acceptance stay open.

```json
{
  "version": 1,
  "projectRoot": "/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project",
  "registrationID": "60089feb-7d4a-4503-9543-0c281be6b8fc",
  "registrationProjectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
  "requestGeneration": 1,
  "projectID": "project-124ab921-e9da-4b92-8034-3feccb0afcd2",
  "ticketID": "outcome3-acceptance-worker",
  "taskID": "outcome3-acceptance-worker-task",
  "expectedTaskPlanRevision": 1,
  "expectedPhaseRevision": 2,
  "requestID": "f481e256-3332-43aa-88e1-4c3dd2c6368a",
  "reason": "Prepare the owner-authorized synthetic worker assignment from the committed disposable fixture to verify startup, permissions, isolation, STOP and recovery."
}
```

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
