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
migration or owner-state mutation is authorized.

## Tests and acceptance

Use test-first focused repository-native tests of changed behavior, immediate
integration boundaries, failure/retry, assignment admission and exclusions. Main
routes native tests/builds to BuildAgent and documentation generation/checks to a
trusted route. Onboarding guidance changes require approved mockup comparison,
responsive/accessibility runtime checks and independent UX/QA coverage; source
inspection alone cannot establish them. Runtime/install/live-configuration checks
remain unavailable unless separately authorized and must be reported honestly.

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

Endpoint: source, affected documentation, focused direct checks, independent review
and scoped local commit through trusted Git. Live configuration/trust/profile
changes, installation, app/SQLite/catalog-acceptance mutations, merge/main writes,
release metadata/tags, push/PR and other external mutations are excluded.

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
