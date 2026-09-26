# Project execution design

Current product boundaries for the Outcome 3 execution model recorded in
[ADR-008](../architecture/ADR-008-opt-in-project-execution.md). This specification
grants no execution authorization and does not claim that every runtime acceptance
scenario passed.
This repository is offboarded; this contract describes the app's opt-in product.

Pending second-Mac acceptance is [#91](https://github.com/joeroberts/release-radar/issues/91),
signed-upgrade connector verification is [#106](https://github.com/joeroberts/release-radar/issues/106),
and broader residual execution discovery is [#96](https://github.com/joeroberts/release-radar/issues/96).
Do not recreate delivered worker behavior from those backlog references.

## Ownership and packaging

Onboarding consent establishes the project's execution workflow. App code derives
policy, role, bounded context, baseline, worktree and finite worker permissions from
exact registered work and expected revisions. Caller-supplied role/path/model/profile,
authorization, prompt or baseline overrides cannot grant authority. Eligibility or
a natural-language coordinator claim alone is insufficient. Signed management-client
identity is not cryptographic identity of a particular coordinator conversation.

Keep one managed release-radar plugin and its install/update/remove/reinstall flow.
Coordinator capability belongs to that package; the hook handler is a signed app
resource. Preserve package integrity and user removal/modification semantics.
Coordinator signing identity is `com.rekonlabs.ReleaseRadarCoordinator`, with
hardened runtime and the existing application-group-only entitlement.
The ADR-002 lifecycle helper retains its fixed installer operations, without project
provisioning, Git or generic command authority.

RR owns only its generated worktrees, grouped by stable project/task identities under
app storage. In-process libgit2 operates while RR holds authorized repository access;
ordinary Git-child inheritance of a dynamically acquired bookmark is not assumed.
Codex-managed and existing unrelated worktrees do not become RR-owned. Workers get
one exact checkout, not project-parent, sibling, shared-Git/history or management
access. Worker plugins and configured MCP servers remain disabled. A narrow cwd
cannot cancel broader effective grants: validate every effective root and permission.

## Assignment admission and lifecycle

Preparation persists intent before configuration and resumes only the exact request.
After awaited setup, recheck deadline, registration/root, work revisions, selected
context and request receipt before protected admission. Failure revokes the exact
preparation. SQL and filesystem authority are not atomic: SQL failure cannot imply
that a revocation or external write was rolled back. Report failed cleanup explicitly.

Review assignments name a known closed delivery assignment and verify its exact clean
committed candidate in its assigned branch/worktree. Primary HEAD, task acceptance or
a caller's role label does not establish that candidate or independent review.
Selected repository context uses stable bounded reads pinned to committed bytes.

Relevant app-store work mutations revoke affected preparing, reserved and admitted
assignments before SQL commit; revocation failure blocks mutation, while SQL rollback
does not reauthorize the assignment. Unrelated evidence/notification changes do not
invalidate unrelated assignments. Missing production reconciliation grants no authority.

Startup records reservation and uncertainty before runtime creation. Binding verifies
the exact reserved snapshot; late results cannot reauthorize stale work. Follow-up
reserves before awaited readiness, excludes concurrent follow-up/close and rechecks
admission afterward. Uncertain starts, approvals or follow-ups block replacement work
and cannot be blindly redispatched. Lost connections remain unknown despite late
completion notifications. STOP addresses the known thread/turn on its owned connection;
physical process/reader closure and delivery outcome are separate facts.

## Hooks and configuration

Register the production UserPromptSubmit handler once in the primary project's
.codex/hooks.json or existing inline representation. Preserve unrelated definitions;
update/remove only an unchanged owned definition. Do not duplicate plugin-only hooks
or copy the primary registration into each worktree. The linked checkout must have a
real .codex directory, created descriptor-relatively without following links or
replacing existing content, so the primary layer can be discovered.

Readiness verifies canonical source, discovery, exact definition/hash trust,
enablement, signed handler identity and project trust before first work. Definition
trust does not replace package verification. Revalidate registration/root and pinned
policy after awaited reads and immediately before configuration/trust writes, then
again on readback. Uncertain in-flight effects are not atomic with the app store.

The handler checks exact assignment/session/checkout and current authority, not
arbitrary command text, transcript contents or synthetic approval tokens. It blocks
invalid known workers when executable, but crashes/timeouts/disabled hooks are not
reliable enforcement. Do not apply worker restrictions globally to unrelated sessions.
A prompt hook is not immediate interruption; STOP uses its independent control path.
Never turn STOP, approval waits or recovery into a forced continuation loop.

Review assignments may view images only within their existing authorized read roots;
this capability does not grant browser, image-generation or wider filesystem access.
Delivery assignments retain their separate image-tool policy. Build support uses
task-owned scratch and narrowly scoped caches/test fixtures; it must not grant general
home, sibling, Git-history, application-data or authority/configuration writes,
management tools or unrestricted network. Source profile checks alone do not prove
that native tests can run under the effective worker permissions.

Removal disables policy before editing configuration and refuses unresolved workers.
Conflicting user edits stay visible and policy stays disabled. Do not delete a user's
hook file, silently re-enable their disabled hook, or require plugin reinstallation
to remove the signed app's owned hook. Resume is explicit and never launches a worker.

## Selected Codex context

The owner selects one existing authenticated Codex home. RR stores protected,
machine-local identity/fingerprint/bookmark receipts outside worker checkouts; only
identity bindings enter assignments/policies. Do not copy credentials or history,
accept prompt-supplied homes, transfer trust between machines or publish bookmarks.
Missing, moved, stale, denied or changed context blocks new admission; STOP and closure
remain available. Same-physical-folder reselection keeps identity. A different home
requires retirement of retained assignments and removal of installed execution hooks.

Selection and selection-sensitive preparation/policy writes share a native lock;
writers captured before a switch cannot later admit old-context work. Connections
compare the complete receipt, including same-ID changes, and retain their original
grant until physical closure. Context selection records app audit intent first.

Set explicit validated CODEX_HOME and read-only bootstrap defaults. Use
account/read(refreshToken:false), requiring ChatGPT, and effective built-in openai
provider/default endpoints before thread creation; verify returned provider again
before binding or generation. Remove inherited auth/state/base-URL overrides only
from the child environment. Custom routing, meaningful profile inheritance, extra
roots and unknown permission fields fail closed without editing owner configuration.
Allow only recognized non-authorizing metadata: the named optional network overlays
may be absent/null with enabled:false, and glob depth may be absent/null, never an
additional numeric limit or grant. Compare remaining filesystem/network fields exactly.

Recorded context and automatically loaded instruction sources differ. Admit the
first nonempty AGENTS.override.md or AGENTS.md in the exact selected home alongside
pinned checkout sources, using no-follow bounded UTF-8 reads (16 MiB file limit).
Source identity does not attest the instruction bytes actually loaded by Codex.
Do not invent content pins or copy/suppress owner instructions to make admission pass.

## Cross-process access

RR restores its durable bookmark; Coordinator receives a fresh memory-only implicit
bookmark through mutually authenticated internal XPC, bound to exact connection,
assignment and complete selected receipt. Broker discovery exposes only the endpoint;
code-signature validation precedes interface selection. Coordinator gains no general
RR command RPC authority. Acquisition requires a fresh unreserved session-free
assignment, precedes reservation, and cannot be duplicated. Reservation precedes
App Server creation. Expired, wrong-peer or changed-context handoffs fail closed.

Resolve the returned NSURL with withoutImplicitStartAccessing, withoutUI and
withoutMounting; retain that URL, reject staleness and require explicit access-start
success. Canonical path/device/inode checks establish identity independently. Balance
each successful start once, after confirmed child/reader closure. Admission expiry
limits initial consumption, not the admitted worker lifetime. Connection invalidation
disables future admission and initiates bounded cleanup, but cannot prove closure.

RR holds an unresolved grant until the original authenticated grant-bound closure
acknowledgement. A replacement connection, timeout or missing session is insufficient.
RR termination cannot preserve its memory grant or imply revocation of consumed helper
capability; durable reserved/uncertain recovery state remains. Bookmark capabilities
never enter MCP responses, prompts or logs. Diagnostics distinguish resolution, stale,
start and identity stages, recording sanitized error domain/code, not NSError.userInfo.

## Resource retirement and binding recovery

Owner retirement pins exact request, prior assignment, registration/root and resource
identities. Require never-launched state or confirmed runtime closure. Refuse referenced
candidates and dirty/untracked/ignored content; prune only the exact owned worktree
with matching branch/common-Git/root. Preserve branches and committed history.
Remove only a semantically identical pinned owned profile using versioned map updates;
legacy definitions must match the finite derived profile. Worktree refusal precedes
profile changes. Record successful steps for exact retry without repeating removals.

Configuration closure is a separate pending receipt condition. Only the matching
request may retry the held original connection. Missing original handles do not prove
closure. The supported recovery may reconcile an exact owned profile with a new helper
and confirm that helper's closure; after old worker closure and resource cleanup it may
permit replacement while original configuration closure stays unknown and retirement
incomplete. Never clear the original marker or replay unknown work on that basis.

Registration generation/root changes revoke old leases and set bindingRecoveryPending
until current hook trust/readiness and owner-context readback succeed. Disablement
survives rebinding; rollback or a different registration cannot inherit authority.
A relocated root receives new local intent/trust; carried definitions must match the
protected owned receipt. Archive/removal disables policy before SQL commit. Re-add
creates new identities; handoff requires an exactly proven removed/inactive predecessor.
Retain predecessor resources/outcomes for owner cleanup, never worker sibling access.

Historical cleanup pins the stored assignment and nonfuture incarnation, not the latest
policy binding. If original-root access is lost, request that exact folder and hold its
one-off bookmark during cleanup; cancellation/wrong folder preserves resources and the
current binding. Preparation remains blocked by unresolved earlier runtime outcomes.

## Preparation and lost-worker recovery

A thrown preparation error does not prove zero effects. Terminal settlement requires a
typed pre-resource refusal and authoritative absence of exact assignment, branch/worktree,
profile and in-flight preparation. Partial/unreadable/reserved/live/uncertain evidence
stays outcomeUnknown. Retired-parent replay additionally proves current identity and
completed parent retirement, without resurrecting it or changing baseline relations.
Only the exact pending receipt may settle transactionally, preserving request body,
creation and prior audit. Terminal replay validates exact scope/body before mutable work
eligibility, never prepares again, and rejects changed bodies. Single-flight spans
admission, revocation and settlement; a failed/stale settlement remains uncertain.

A missing app-selected context file in an eligible closed parent can enter that
no-effects proof path only for the typed missing-file condition before resources
are created. Unreadable or other document failures are not equivalent. Parent-work
mismatch and retired-parent failures likewise need the full request-scoped proof;
an error label alone never settles a pending receipt.

Preparation failures may carry optional typed `preparationDiagnostic` data without
changing the existing error, entity, audit, envelope or replay contracts. Kinds are
`pendingPreparationRequest`, `preparationInProgress`, `blockingAssignment` and
`causeUnavailable`. At most one directly proven request or assignment witness is
reported, classified as `observedAtFailure` or `recordedFailure`; it is not a complete
blocker inventory or a promise that removing it permits admission. Validate exact
root, registration/generation, work, revisions and role before exposing a receipt
witness. A single-flight key lacking role/registration proof exposes no request ID.

Only `causeUnavailable` may carry an optional observed failure stage:
`parentCandidateValidation`, `targetProvisioning`, `preparedAssignmentConfiguration`,
`assignmentStoreIntegrity` or `assignmentStoreCompareAndSwap`. Preserve a nested store
stage through wrappers; never infer a last-reached stage or parse error prose.
Diagnostics contain no free text, paths, request bodies/reasons, prompts, content,
account/session detail, raw errors or recovery actions. Legacy payloads decode with
nil fields. Replay labels stored evidence as recorded without rewriting its receipt;
diagnostics create no audit/receipt, settle no uncertainty and release no gate.

Owner-invoked lost-worker recovery preserves checkout, branch, profile, session and
uncertain outcome. It neither retires resources nor accepts work. Require exact current
identity and clean committed candidate, complete same-user kernel process inventory,
stable PID/start time, full arguments and matching signed Codex identity. Live/suspicious
markers or incomplete inspection block recovery. Process absence alone is insufficient:
reconcile the exact retained context grant before assignment compare-and-swap.

The recovery receipt records prior state, observation, permission marker, retained-grant
disposition and candidate revision. State becomes stopped/connection-cleaned with
uncertain delivery outcome. Only a delivery assignment naming that exact baseline receipt
may reuse the still-clean candidate; it cannot be a review parent. If success audit fails
after persistence, read back and expose Finish recovery audit with deterministic request/
audit identity. Exact replay finalizes audit without repeating inspection or grant release;
unavailable readback reports unconfirmed outcome, not invented failure or success.

## Discovery, setup feedback and documentation access

MCP initialize/ping/tools-list must work before execution storage exists, without opening
or creating it. Actual worker calls lazily validate create:false storage and fail closed.
Serialize/cache the connection adapter without blocking independent status/STOP behind
an awaited worker call. Disconnect closes only an adapter that actually opened.

Setup shows progress and failure next to Resume/Finish, ahead of the generated prompt;
clear stale status on retry. Completed preparation does not bypass Finish verification.
The documented macOS /var alias exception requires the exact root-owned link in a
privileged non-writable parent, exact private/var target and stable link metadata, then
no-follow traversal and stable root reopening. It is not general symlink acceptance.

## Acceptance boundary

Source checks do not prove signed sandbox grants, installed worker isolation, UI usability
or second-Mac behavior. Existing issues retain outstanding work; this extraction creates
no new acceptance obligations from old logs. Preserve explicit unknown outcomes and
owner authorization for live operations. See also the [plugin lifecycle contract](release-radar-codex-plugin-lifecycle-design.md),
[shared execution contract](shared-execution-integration-v1-design.md) and
[managed documentation contract](managed-repository-documentation-contract.md).
