# Discover role execution and Run Guard boundary

## Assignment brief — 2026-09-07

Status: authorized bounded discovery; findings pending. This artifact records a
proposal, not accepted architecture or implementation.

Treat role execution and Run Guard as one coupled I7/I8, RM11/#3 discovery: whether and how Release Radar should own first-party runs, with one run owner, separate execution/delivery state, real attribution and review independence, capabilities, cancellation/recovery, isolation and compatibility/distribution implications. Return concrete pursue/no-go choices and the smallest complete product boundary preserving the full outcomes if pursued.

Use primary sources and bounded relevant local capability inspection. Preserve app-owned delivery and repository authority, registration/request isolation, retained history and one run owner. No general executor, marketplace, public SDK, second delivery database or product implementation. Account for C5–C7 lifecycle/recovery and I1 observer boundaries without treating observation as execution authority.

Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md) and the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Retain all 40 capabilities and accepted versus proposed distinctions. RDS appearance
is unchanged. This discovery does not reopen completed lifecycle work or gate C4.

Model/effort: gpt-6-astra / high; ceiling: Astra High; Ultra prohibited. Assigned baseline is
`c4ddffb` plus the committed discovery briefs/catalog preparation on
`codex/recovery-orchestration`; the dispatch supplies its exact revision. Use a fresh
worktree and named `codex/discovery-run-ownership` branch with upstream. Own only this
artifact. The orchestrator owns progress, shared plan/catalog/index integration.
Do not overwrite another worker's files or edit the canonical checkout.

Verification: cite current primary sources supporting conclusions; distinguish
verified local capability, documentary evidence, hypothesis and unavailable proof.
Use only bounded isolated tests justified by the question. Report compatibility,
privacy/recovery risks and any material unresolved owner choice with recommendation.
One fresh independent substantive reviewer covers actual proposal risks; only
Required findings block. No review-of-review or implementation approval implied.

Endpoint: coherent findings in this artifact, scoped commit, branch push and PR
against `codex/release-radar-mvp`. Each merge needs owner approval. No installation,
owner/application-state mutation, cloud provisioning, active configuration change or
production implementation. List retained temporary files; do not delete unrelated
files. Report exact commit, checks, limitations and stopped processes to the
orchestrator before archival.

## Findings

### Disposition — 2026-09-07

**Pursue a separately authorized, synthetic feasibility proof; no-go for product
implementation commitment today.** Recommend one first-party Run Guard execution
owner behind a fixed Release Radar integration. I7 role assignments become bounded
run requests to that owner, not a competing Release Radar executor. Existing Codex
desktop sessions remain outside its control until separately proven. A decision to
stop this work leaves delivery tracking and truthful unavailable observation useful.
C4 and completed lifecycle work have no dependency on this discovery.

These are proposals, not accepted contracts, enabled controls or a roadmap change.
The assignment brief above is retained as issued; its pending label describes the
original dispatch. The [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capabilities, including complete packages, Mac/repository authority,
retained history and unchanged RDS appearance.

### Evidence and what it establishes

- **Repository source, baseline `1d4ba4f`:**
  [AgentCommandEnvelope](../../../../ReleaseRadarCore/AgentBridge/AgentCommand.swift)
  carries `assertedThreadID`; [dispatch](../../../../ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift)
  records `.asserted` attribution and compares canonical request bodies for replay.
  The [bridge transport](../../../../ReleaseRadarTransport/BridgeXPCContracts.swift)
  authenticates component signing requirements, not the independent origin of an
  agent's reasoning. This is a useful transactional boundary, not verified reviewer
  identity. Existing receipts lack the proposed registration/run-generation binding.
- **Repository source:** [UnavailableCodexObserver](../../../../ReleaseRadarCore/Codex/CodexObserver.swift)
  exposes snapshots/events only and downgrades scoped caches to stale. Its
  [acceptance tests](../../../../ReleaseRadarTests/CodexObserverAcceptanceTests.swift)
  describe unavailable, stale and root/exclusion behavior; tests were inspected,
  not rerun. No execution authority follows from this contract.
- **Verified installed capability:** `codex --version` returned `codex-cli 0.153.4`.
  `codex app-server --help` advertises stdio, Unix and WebSocket transports,
  daemon/proxy and schema generators, with experimental labeling. Help is not a
  successful authenticated connection, cancellation test or signed-app proof.
  No daemon, model run or owner session was started, attached to or interrupted.
- **Current primary documentation:** [Codex App Server](https://learn.chatgpt.com/docs/app-server)
  documents initialization, thread/turn identity, approval requests, streamed
  completion and `turn/interrupt`. An interrupt response is followed by an
  interrupted turn result. Fresh threads differ from forks; detached review forks
  context, so a different thread ID alone is insufficient for this review policy.
  The page labels app-server/WebSocket transport experimental and unsupported for
  production. It does not establish safe attachment from this sandboxed app to the
  owner's desktop instance. [Sandbox documentation](https://learn.chatgpt.com/docs/sandboxing)
  distinguishes technical restrictions from approval policy; command sandboxing
  does not by itself settle separate plugin/network controls.
- **Apple platform evidence:** [Creating XPC services](https://developer.apple.com/documentation/xpc/creating-xpc-services)
  describes separate client/service processes and typed requests.
  [Apple's XPC design guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html)
  describes independent sandboxes and service restarts, including abrupt termination.
  [Helper embedding guidance](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)
  requires appropriate signing/entitlements and warns that an unsandboxed debug
  target behaves differently. These support an isolation approach, not a proven
  Codex-host composition. Current Apple Markdown was read directly when the web
  renderer could not display it. Sources accessed 2026-09-07.
- **Product context:** [issue #3](https://github.com/joeroberts/release-radar/issues/3),
  read through `gh issue view`, proposes Run Guard domain ownership and an isolated
  first-party integration. It remains provisional; its feasibility checklist is
  not evidence of implementation. [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md)
  and [ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) still control
  delivery authority, observation and the separate four-method plugin installer.

### Smallest complete boundary if pursued

| Concern | Concrete recommendation and limit |
| --- | --- |
| One run owner | Run Guard owns admission, provider interaction, enforcement, cancellation, run history and recovery. Release Radar owns extension enablement, permission presentation, navigation and attributed projections. No second I7 controller; no delivery graph in Run Guard. |
| UI | One compiled first-party Run Guard presentation module using existing RDS components, receiving bounded typed view data and actions. Run semantics and terminology remain Run Guard's; Release Radar contains navigation and accessibility. Prefer this over remotely supplied HTML/code or a general extension system. Compiled UI shares app memory and is trusted presentation code, never the security boundary. |
| Runtime isolation | A separately signed, sandboxed Run Guard service with authenticated, versioned XPC is the candidate. No Release Radar app-group/SQLite, delivery bridge, notification credentials, unrelated roots or unrelated process control. A fixed provider adapter privately speaks Codex; do not expose shell/JSON-RPC pass-through to the host. Proving this composition is a gate, not an entitlement change authorized here. |
| Persistence | Prefer a separate Run Guard-owned run journal/store containing only its execution contracts, events, receipts and history. Release Radar stores host preferences and opaque run links/projections, not duplicate authoritative run state. Namespaced Release Radar SQLite storage would entangle Run Guard recovery with delivery migrations and is not recommended. This is a proposal for execution persistence, not a second delivery database. |
| Host display | Selected attributed projections plus opaque links: owner, role, requested and observed model/effort, execution state, freshness, approval/cancellation status and result references. Explicitly identify unknown attribution. Do not ingest unrestricted transcripts by default. Missing extension/history produces an unavailable link, never a retargeted one. |

The complete owner journey is enable/compatibility check → explicit scoped grant →
review a bounded assignment → start and monitor → handle denial/approval/failure →
cancel or inspect the result → independently review the identified candidate when
required. Execution success, role completion, crash or uninstall cannot change a
lane, Ticket Task, Delivery Goal, blocker or review request. Results are evidence
for separately authorized typed delivery actions; this integration has no ambient
permission to call the delivery bridge. No automatic commit, PR, acceptance or
publication is implied.

### Identity, grants and reviewer independence

Propose a run contract that binds domain project ID, local registration ID/request
generation, authorized root identity, immutable candidate/source revision, owner
assignment, role, provider identity, requested model/effort, grant revision and a
stable start request ID. Run Guard adds its run ID, service-instance generation and
provider thread/turn IDs from its own authenticated start result. Record effective
settings when returned; otherwise show unverified rather than inventing them.

Reject cross-project/registration/root mismatches and reused request IDs with a
changed body. Persist the start intent before dispatch. A lost provider start reply
is an unknown outcome: reconcile through supported provider identity or retain it
for owner recovery; never blindly repeat a possibly successful start. JSON-RPC
request correlation alone does not prove provider-side idempotency. A reconnect
must establish the same owner/instance relationship before admitting commands.

Grants enumerate allowed operations, exact root/read/write scope, network/provider
use, limits and expiry. Denial, stale grant or unsupported enforcement prevents
start. Revocation immediately closes admission, cancels pending approval requests
and initiates owned cancellation; it cannot undo bytes already read/transmitted or
external effects already committed. Do not inherit arbitrary owner MCP servers,
plugins, hooks, environment secrets or full-access settings. The isolation proof
must exercise those routes, including descendant processes, not merely hide tools
in the UI. Run Guard's provider authentication needs a separately approved supported
credential boundary; borrowing the installer's Codex-home exception or exposing
Release Radar Keychain data is no-go. The app's current
[read-only folder entitlement](../../../../ReleaseRadar/ReleaseRadar.entitlements)
is not a repository-write grant.

A review assignment must originate as a fresh context for the original outcome and
an identified candidate, with its own run, isolated working files and bounded
inputs. Reject self-review and implementer forks/resumes as independent review;
provider names, stronger models and self-asserted thread IDs are insufficient.
Capture assignment provenance, candidate revision and verifier-observed run identity.
This proves operational separation only, not statistically independent model
judgment or correctness. Existing external asserted attribution remains asserted;
no retroactive upgrade or mandatory role matrix.

### Cancellation, lifecycle and retained history

Execution lifecycle and observation certainty are separate. Proposed execution
states are starting, running, waiting for input/approval, cancelling, completed,
failed and cancelled; loss of certainty is unknown/unavailable, not success or a
confirmed terminal state. Completion evidence records its source and timestamp.

Run Guard first requests cooperative cancellation of its exact provider turn. On a
bounded timeout it may terminate only a still-revalidated process it launched,
using ownership evidence stronger than a saved PID/name. Descendant containment,
PID reuse and whether cancellation stops every owned side effect require direct
proof. No broad process-name kill, existing desktop termination or automatic retry.
If termination cannot be confirmed, retain unknown state and recovery guidance.
Transport loss/service crash closes grants and new starts; service relaunch
reconciles its persisted intent and current owned processes before any resume.
Duplicate events deduplicate by source/run/event identity; late or out-of-order
events cannot reopen terminal work, restore grants or apply to a newer registration.

| Operation / consumer | Proposed behavior preserving accepted lifecycle policy |
| --- | --- |
| Enable / upgrade | Install only the fixed signed component through a separately authorized delivery. Enable never starts work or grants folders. Negotiate host, Run Guard, provider and schema compatibility; unknown combinations disable actions while preserving readable history. Quiesce before migration; preserve recoverable old data and reject unsupported downgrade without destructive rewrite. |
| Disable / uninstall / reinstall | Close admission and revoke grants, then cancel/reconcile owned work before declaring stopped. Unknown shutdown remains visible. Disable retains history; uninstall removes executable integration only after safe shutdown and retains execution history unless erasure is separately authorized. Reinstall reads compatible history but restores no grants or pending starts. |
| C5 archive / restore | Archive suspends monitoring and prevents new runs; coordinate owned cancellation without falsely claiming external runs stopped. Restore lifecycle only, requiring renewed availability/grants and explicit restart. |
| C6 removal / P18 ticket cancellation | Invalidate the old registration's admission and callbacks before releasing capabilities; preserve read-only event-time history/removal identity and repository files. Re-add creates a new registration. Ticket withdrawal does not prove external execution stopped. History never resolves old actions into a replacement by matching its path. |
| C7 backup / reset | Quiesce each app-owned connection plus the Run Guard owner. Back up stores at a defined consistent boundary, or explicitly report incomplete backup. Restore source history but rotate local generations and invalidate grants, pending starts and replay authority; no automatic run or notification replay. Uncertain external effects remain uncertain. |
| C10/C11 package / I6 companion | Once run history is a supported project record, complete packages include its portable contracts, results/evidence and provenance through an explicit versioned snapshot; unavailable required material blocks complete-export claims. Exclude credentials, live handles, grants and source checkouts. Imported history cannot resume execution. Phone/cloud copies remain attributed read-only publications, never run or delivery authority. |
| I1 / P11/P14/P17 | Read-only observation can display last-known execution, history and revision evidence; it cannot claim Run Guard ownership or cancel. Run events retain provenance distinct from delivery audits, imported history and notification results. |

### Feasibility gates and owner choices

Recommend an owner-Mac, one-provider synthetic proof first. The meaningful outcome
is one complete bounded run and a genuinely separate review candidate, with allowed
and denied actions, durable identity, cancellation and recovery—not merely a rendered
panel or successful handshake. Before production commitment, independently exercise:

1. Signed service authentication and compatible/incompatible handshake; exact grants,
   revocation and attempts against unrelated folders, SQLite, bridge, credentials,
   plugins/network and unrelated processes.
2. One idempotent start; uncertain start recovery; cooperative interruption and bounded
   forced termination with descendant/PID-reuse checks; denial and approval waits.
3. Crash/relaunch/transport loss, duplicate/out-of-order callbacks, removal/re-add and
   backup restore. Verify no old request can apply and no run restarts silently.
4. Upgrade/downgrade, disable/uninstall/reinstall with retained readable history,
   contained accessible UI, and complete history/package handling. Verify app-owned
   delivery rows are unchanged across all run outcomes except separate host metadata.

These are future proof requirements from the proposed boundary and issue #3, not
checks performed in this Markdown task. A synthetic protocol test without a signed
sandbox/provider composition cannot satisfy the security or distribution gate.

The material owner choices are whether first-party owned execution is valuable
enough to pursue, whether to accept this Run Guard-owned service/store boundary,
and the intended distribution audience. Recommend conditional pursuit with these
boundaries; wider distribution remains no-go until portable provider discovery,
authentication, signing/notarization, install/upgrade and macOS 14 compatibility are
proven under I5. Do not reuse owner-specific installer exceptions. If supported
provider access requires broad owner-home/credential access or loss of isolation,
stop with a no-go finding rather than weaken ADR-001. App-server's documented
experimental status is a specific production-support risk requiring resolution.

### Assignment evidence and limits

Task `01a07b8e-c2da-79a1-955e-0deb0a1e8a72`, returned title
“Discover role execution and Run Guard…”, began from clean `1d4ba4f` in the assigned
fresh worktree on `codex/discovery-run-ownership`, with matching upstream.
Astra/high was requested; the task readback did not expose runtime model/effort.
No subagents or additional tasks were created. CodeGraph reported no usable index,
so bounded direct source inspection was used.

The repository-packaged documentation checker passed before and after the edit;
`git diff --check` passed, the scoped diff contains only this artifact, and relative
links resolve. Fresh substantive review is pending through the orchestrator. No run/isolation/runtime UI proof is claimed; no product
code, governing files, catalog/indexes, owner state, installed configuration or
credentials changed. Application binding/readback belongs to the orchestrator's
separately authorized integration; this task makes no managed-current or app-sync
claim. The sole durable change is this catalogued artifact; no temporary files were
created for the investigation.
