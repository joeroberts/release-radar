# Outcome 3 runtime enforcement assessment

Date: September 14, 2026. **Proposed; supporting; candidate for independent
review.** This document grants no implementation or configuration authority.

## Current reading guidance — September 16

Read [the retained App Server findings](#september-16-app-server-findings) and
[the onboarding/worktree integration contract](#september-16-onboarding-and-worktree-integration-contract)
for the current follow-up. The original recommendation below is retained as an
attributed September 14 assessment. Its desktop-visibility and VM alternatives
are not requirements for the approved coordinator plugin or this follow-up.
Outcome 3 remains open; a reviewed standalone component does not complete RR
integration. The catalog identity remains proposed/supporting.

## Original September 14 recommendation

Retain the owner's selected native Codex desktop, local App Server and named
profiles direction, but do not implement a purported complete enforcement mode
with the interfaces presently established. The unestablished boundary is supported,
authenticated access to the retained desktop with admission before the first model
turn and persistent all-tool enforcement. A controlled client can inspect loaded
instruction sources between App Server's separate thread-start and turn-start
operations; loading is not itself model exposure. The exposed desktop create tool
provides no such gate, and protection against alternate native starts remains
unestablished. Sections 3–7 distinguish these blockers from RR-owned provisioning
and recovery responsibilities that may compose supported primitives. They are an
implementation proposal, not a claim that new desktop APIs are required for every
safeguard.

If enforcement must proceed without those desktop additions, the concrete
alternative is a separately owned App Server client with isolated macOS worker
VMs, described in section 8. It retains Codex models, named profiles, App Server
events and macOS builds, but workers are **not native tasks in the existing
desktop**. Choose that architectural tradeoff explicitly before implementation.
Do not present a second App Server, private desktop IPC, a remote URL override or
the availability of `proxy` as proof of native integration.

The complete outcome remains current applicable context, deliberate historical
retrieval, restricted implementation, independent review, and integration through
the authorized delivery endpoint. Outcome 2 and V1 adoption stay complete; neither
needs reopening to record these runtime gaps.

## 1. Assignment, authority and source basis

| Shared Execution field | Assessment context |
| --- | --- |
| Standard | `shared-execution/1`; installed 0.1.16 skill was read and declares standard 1. Installed documentation diagnostic reports contract 1. Exact installed-package integrity/adoption evidence is attributed to the current ledger; no new package-integrity or universal skill-loading claim. |
| Root | `/Users/jroberts/.codex/worktrees/ac97/release_radar` |
| Outcome | Resolve the entire runtime boundary with a concrete native proposal or exact missing controls and one enforceable alternative. |
| Scope | This assessment, its catalog row and generated design index. Read-only installed code/interface/documentation inspection. No runtime probes, product/configuration changes, owner task-content access, SQLite or external mutations. |
| Authority | [Outcome 3 brief](../delivery/task-briefs/2026-09-14-outcome3-runtime-enforcement/brief.md), [progress](../delivery/progress.md), [owning V1 design](shared-execution-integration-v1-design.md), and the [full-product plan's integration/runtime sections](../delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md#integration-feasibility-and-boundaries). |
| Endpoint | Local candidate commit for a fresh independent reviewer; coordinator owns ledger, integration and lifecycle disposition. No release or app-state acceptance. |
| Direct checks | Installed documentation `check`/`diagnose`, diff hygiene, scoped file and accepted-ADR preservation. Runtime acceptance scenarios below are not executed. |
| Review | Fresh Astra/high peer, independent of this author, covers architecture, capability/authorization boundaries and recovery on the committed candidate. Assignment is Astra/high, ceiling Astra/high; this task interface does not expose independent model-setting readback. |

Initial HEAD was clean and exactly
`ff73921258fecac204df2263a669704dd4c4b4f0`. Governing instructions and current
catalog/index routes were read first. [ADR-001](../architecture/ADR-001-release-radar-boundaries.md),
[ADR-002](../architecture/ADR-002-codex-plugin-lifecycle.md),
[ADR-006](../architecture/ADR-006-managed-repository-documentation-contract.md)
and [ADR-007](../architecture/ADR-007-proportional-delivery-validation.md) remain
unchanged. ADR-006's historical pending header is not reinterpreted as permission
to edit it; its accepted/current qualification is in the owning managed-document
design and ledger.

## 2. What the evidence establishes

**Evidence labels:** documented means a fetched official contract; installed means
observed shipped code, metadata or help, not an exercised runtime guarantee;
attributed means a named prior result; proposal/inference means this assessment's
reasoning; unknown means not established. Negative discovery is bounded to these
interfaces and sources, not a proof that no unpublished capability exists.

### Installed desktop and exposed interfaces

The installed desktop bundle is `/Applications/ChatGPT.app`, version
`26.908.40834`, build `8881`. Its bundled `Contents/Resources/codex` reports
`0.154.0-alpha.6.2`. The separate Homebrew `codex` symlink targets 0.153.4 and was
not used as desktop-backend evidence. Read-only ASAR inspection decoded the
directory header and selected shipped JavaScript in memory; it extracted no files
and opened no owner database, rollout, credential or unrelated task.

Locators below are inside that bundle's `Contents/Resources/app.asar`.
Minified symbol names are locators for this exact build, not supported APIs.

| Installed observation | Consequence and limit |
| --- | --- |
| `.vite/build/src-CCXHtyvY.js`, `aT`/`lT`: task-start payload construction maps a selected profile to `permissions`; carries runtime workspace roots and configuration overrides. `Tg`/`Eg` map active profile identity. | Desktop internals can construct permission-aware starts. Does not make that constructor an external RR interface. |
| `.vite/build/main-DaMR-wdT.js`, `updateThreadSettings`: calls `thread/settings/update`, with an unsupported-method fallback; the permissions dropdown calls `updateThreadPermissions`. | Settings can change; the fallback itself demonstrates version-dependent handling. No immutable grant or compare-and-set permission ceiling was established. |
| Same main file, local transport factory near `G5`; src file `NU` and stdio transport spawn: local CLI transport exists, alongside alternate transports. | Desktop-owned stdio is a real path. This inspection did not determine the current process's transport or authorize connection to it. |
| Same main file, `Tse`/`Dse` and `Dl`: dynamic app-tool pipe with package-dependent peer admission. | Private app-tool IPC exists. Neither its presence nor same-user access makes RR an admitted supported client. Do not call it. |
| Src file `eae`/`nj`: an internal ambient-classification task suppresses several feature families, memories, apps and tools using configuration; `Tx` filters selected delegation tools. | Scoped suppression exists internally. This is not an exhaustive, stable allowlist contract for arbitrary native workers. |
| Current exposed `create_thread` schema takes target, prompt, title, model and effort; `send_message_to_thread` takes task identity, prompt and optional model/effort. | Neither exposed operation accepts profile, tool inventory, grant revision, immutable input identity or external caller request identity. Creation starts work asynchronously; changing a profile afterward leaves a first-turn gap. |
| Bundled `app-server --help`, `proxy --help`, `daemon --help`: stdio, Unix/WebSocket listeners, auth flags, proxy to a control socket, and managed-daemon lifecycle commands. | Capability discovery only. No daemon/server was launched, connected, bootstrapped, restarted or reconfigured. A daemon socket is not demonstrated attachment to the retained desktop. |

### Documented primitives and their limits

The current official [App Server documentation](https://learn.chatgpt.com/docs/app-server)
documents `initialize`/`initialized`, separate `thread/start` and `turn/start`,
`thread/resume`, `turn/interrupt`, beta `permissionProfile/list` and `permissions`
selection, and returned `instructionSources`. A profile replaces the legacy
`sandbox` start field; do not send both. Turn overrides become later defaults.
`config/read`, `configRequirements/read`, `config/value/write` and atomic
`config/batchWrite` exist. Experimental `dynamicTools` supplies client tools; it is
not documented as a universal built-in-tool allowlist. Unix/WebSocket transport
and bearer authentication are described, but no RR-scoped existing-desktop
attachment/authorization contract is established; WebSocket production support is
explicitly qualified. Model-account authentication is distinct from authenticating
an external client to a particular desktop service instance.

[Permissions](https://learn.chatgpt.com/docs/permissions) expressly applies profiles
to local sandboxed command execution. macOS uses Seatbelt and rejects unsupported
policies. Profiles support restricted reads, separate writes and denied paths;
network domain enforcement additionally requires the network proxy. These do not
cover hosted search, connectors, MCP, browser/computer use or client service
traffic. A name in the picker is therefore insufficient evidence for all-tool
isolation.

The [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
provides `web_search = "disabled"`, `apps._default.enabled` plus per-app overrides,
`mcp_servers.<id>.enabled_tools` and `disabled_tools`, `features.multi_agent`, and
`memories.use_memories`. These are distinct controls, not one permission-profile
tool field. `permissions.<name>.filesystem` accepts path read/write/deny rules and
`:workspace_roots` subpaths. Managed `allowed_permission_profiles` can exclude
profiles; `allow_browser_and_computer_use = false` blocks that capability family.
These managed requirements cannot be presumed to target just one native task.

[Managed configuration](https://learn.chatgpt.com/docs/enterprise/managed-configuration)
is an administrator constraint layer, not an RR-owned per-task provisioning API.
Using it globally to disable tools would affect the coordinator and unrelated
tasks, contrary to this outcome. A normal configuration profile (`profiles.*`) and
a permission profile (`permissions.*`) are also different: the latter alone does
not carry the full capability policy proposed here.

The [September 13 pilot](../delivery/evidence/2026-09-13-current-document-workspace-pilot.md)
is attributed evidence of useful staged current context and deliberate historical
retrieval. It reports initial Full Access turns, owner-selected profiles before
file work, writable staged inputs and exposed non-shell routes. Its prior command
denial tests were not repeated. It proves neither immutable inputs nor complete
native-task isolation.

## 3. Native-desktop blockers and supporting responsibilities

G1–G3 identify the unestablished native attachment/admission and enforcement
boundary. G4–G5 identify necessary provisioning and recovery safeguards, not
additional desktop APIs that must all be invented. RR-owned bookkeeping and
supported primitives may compose those safeguards where their semantics suffice.
The mechanisms below are proposals, **not invented existing method names**.

| Boundary or responsibility | Required behavior | Existing primitives and remaining limitation |
| --- | --- | --- |
| G1: authenticated attachment and delegation | Owner pairs the signed RR integration with the exact existing desktop instance. A revocable grant names permitted projects, task IDs/roles and operations. Read-only observation and mutation grants stay separate. Return provider/instance identity and reconnect generation. | Bearer transport/login, internal pipe admission and desktop task tools do not establish such an external grant. Broad same-user JSON-RPC includes unrelated reads, filesystem/configuration calls and commands. |
| G2: admission before the first model turn | Establish exact root, model/effort, permission revision, tool allowlist, selected instruction sources and immutable inputs; inspect the resolved policy and loaded-source inventory before releasing model generation. Unknown/unrecognized settings fail closed. | The exposed desktop create tool provides no pre-turn inspection gate. App Server's separate start/turn primitives could support one; supported desktop access and prevention of alternate starts remain unestablished. |
| G3: persistent all-tool ceiling | All native/manual follow-ups, steering, resume, fork, subagent creation, permissions requests and automatic continuations inherit an unexpandable task grant. Enforce both tool discovery and execution, including newly introduced tools. An owner-approved policy replacement quiesces the old run first. | Settings are mutable, turn overrides persist, and individual controls have different scopes. No sealed default-deny capability ceiling across all native routes was established. |
| G4: owned provisioning | Preserve exact resource ownership, detect conflicting edits, protect policy, track task references and retire only owned unused resources. Compose supported configuration/project operations with RR-owned bookkeeping. | Atomic `config/batchWrite` and configuration readback exist; installed requests include `expectedVersion`, whose full conflict semantics remain unproved here. RR can own intent/reference records. Supported external project integration remains unestablished; generic config writes alone do not prove task pinning or safe retirement. |
| G5: bounded lifecycle and recovery | Preserve known task/service identity, reconcile reconnect state where supported, request owned cancellation and report stop status truthfully. Unknown creation must never cause duplicate dispatch. | Durable start lookup is one possible recovery mechanism, not a requirement. Without supported exact reconciliation, retain the start as unknown for owner recovery and do not redispatch. JSON-RPC IDs are correlation, not durable idempotency; interrupt/archive alone do not prove descendant processes or side effects stopped. |

RR implementation after approval would prepare the selected source package,
record start intent and consumed policy revision in its existing app-owned records,
request these bounded operations, and show unavailable/conflict/unknown states.
It would not expose generic App Server forwarding to agents. The proposed new
integration owner must authenticate RR and constrain operations; the fixed
four-method ADR-002 plugin helper cannot acquire this authority by reinterpretation.
Accepted observer and delivery-mutation boundaries remain separate.

## 4. Concrete workspace and capability proposal

For each role, provision a fresh run directory with `inputs/`, `work/`, `outputs/`,
`build/` and `tmp/`. Runtime workspace roots contain that exact run only. Trusted
provisioning owns the enclosing directory, frozen inputs and policy; the worker
cannot replace their ancestors. No canonical repository, host home, peer directory,
shared Git object store, old output, owner memory or prior conversation is mounted
or injected by default.

The source selector validates the current catalog and authority route, then exports
only task-relevant controllers, accepted ADRs, required code/tests/build files,
approved mockups and pinned dependencies from the assigned committed baseline.
The input map records repository/artifact identity, source revision, selected paths
and any exact excerpt boundaries. An excerpt cannot drop continuing requirements;
the pilot's omitted consumer requirement illustrates that risk. Include complete
applicable governing instructions byte-for-byte. If they cannot be safely supplied,
stop staging; do not silently rewrite their authority.

Default staging excludes archives, superseded/completed briefs, unrelated plans,
historical indexes, `.git`, `.codegraph` databases and caches that embed excluded
content. A worktree alone cannot do this: `git show` can recover old files through
its shared object database. Keep the real implementation/integration worktree
outside worker access. Export an editable source view to `work/` and return changes
as a candidate patch/file set; source revision remains externally recorded.
Do not put a copy of immutable policy into an editable source view and then rely
on that copy as authority.

Illustrative named profile template using documented syntax (not installed or
validated as a complete runtime configuration):

```toml
[permissions.rr_delivery_v1.filesystem]
":root" = "deny"
":minimal" = "read"
":tmpdir" = "deny"
":slash_tmp" = "deny"

[permissions.rr_delivery_v1.filesystem.":workspace_roots"]
"." = "read"
"work" = "write"
"outputs" = "write"
"build" = "write"
"tmp" = "write"

[permissions.rr_delivery_v1.network]
enabled = false
```

Resolve `TMPDIR` and build/cache output to the run's own writable directories;
add exact versioned Xcode/SDK/tool runtime read roots to the project instance of
this template, never the whole host home. `:minimal` alone did not satisfy all
pilot tools. The review profile removes `work` write access and reads a frozen
`candidate/`; only its own `outputs/build/tmp` are writable. Readback and actual
denial of replacement, symlink/hardlink escape and rename/unlink are acceptance
requirements. `chmod` by the same unrestricted owner or a post-run byte comparison
does not establish immutability.

| Route | Worker policy and enforcing owner |
| --- | --- |
| Shell, scripts, subprocesses, terminal sessions | Exact read/write roots; network off; no permission escalation; no generic host shell or shared sockets. Seatbelt plus the surrounding runtime boundary. Interactive input stays inside the same boundary. |
| File reads, patch tools, image/document readers, JavaScript/code mode | Same path/candidate policy at every implementation, including host callbacks and generated nested calls. Unsupported route is absent and rejected. A shell-only denial cannot stand in for this. |
| MCP, connectors, tool discovery and resource APIs | Empty inventory by default, including RR mutation tools. An approved exception names exact server/tool and data scope; server-side admission enforces scope rather than trusting arguments. Disable plugin auto-install and owner configuration inheritance. |
| Hosted web/image services, browser, computer use, screen/clipboard | Absent by default. No host UI, owner browser session, filesystem URL or connector workaround. A needed research result is an explicitly supplied attributed input; enabling a surface requires a new scoped grant. |
| Task reads, messages, creation, fork, automation, subagents | Absent for these delivery/review roles. Fresh reviewer receives the original outcome and candidate, not author history. The coordinator retains its own authorized task tools outside this grant. |
| Memories, session history, skills and automatic context | Fresh context; no owner memories or inherited history. Package exact required skill content into protected inputs. Inspect returned instruction sources before model admission; unexpected sources prevent the first turn. Stale indexes remain unavailable to worker discovery. |
| Git, signing, package/install tools and RR state | No canonical Git objects, signing key, installation path, host app state or SQLite. Trusted integration owns the authorized commit/release endpoint. Worker tool output never confers that authority. |

The native implementation must enforce the complete table at G2/G3. Feature names
and prompt prohibitions are not substitutes. A worker asking for history submits
artifact/revision/question through its result or one narrowly admitted request
channel. The coordinator retrieves only the authorized passage, labels it
historical/non-authoritative and issues a new immutable supplemental input version.
No search over archives, automatic traversal of historical links or silent policy
widening occurs. If the current source basis changes materially, admit a fresh run;
do not disguise stale context as current.

## 5. Provisioning, conflicts and lifecycle

Use one versioned template family and role-specific instances keyed by project
registration, root generation and template revision. Relative rules are reusable;
root sets and toolchain exceptions are resolved for one run. Store intent, owned
resource IDs, last verified revision and native task references in existing RR
app-owned records under a separately approved schema extension. No second task
database or parallel delivery ledger is proposed.

1. **Onboard:** owner approves exact project/root and previewed capabilities.
   Diagnose supported desktop version, project identity, effective requirements,
   instruction sources and tool inventory without changing trust. Reuse an existing
   owner project only by explicit binding; a name/path resemblance proves no
   ownership. An unmanaged same-name profile is a conflict, never overwritten.
2. **Provision:** persist intent and ownership before dispatch; use supported atomic
   configuration writes and readback with verified conflict handling, such as an
   expected revision where supported. Codex remains configuration owner; RR owns
   its intent and reference bookkeeping. Register the staged root through a
   supported desktop project operation. If project integration or safe conflict
   handling cannot be established, report that specific limitation; neither direct
   TOML edits nor private project-store writes are implementation fallbacks.
3. **Start:** pin template, effective profile and tool capability revision, source
   package, model/effort and endpoint to G2. Record returned desktop/provider/task
   identity. Reject unresolved roots, unsupported keys, extra inherited grants or
   a widened runtime root set before releasing the first model turn.
4. **Update/drift:** create a new profile revision. Existing tasks retain their
   admitted policy or are quiesced and explicitly replaced; never widen an active
   task in place. Changed owner entries, plugin tool inventories, client upgrades
   or requirements conflicts close admission until reviewed readback agrees.
   Keep unrelated settings byte/semantically unchanged. A detected conflict preserves
   both parties' work and requires a fresh preview, not a last-writer-wins retry.
5. **Interrupt/recover:** STOP/revocation closes new work immediately and requests
   owned cancellation. Distinguish waiting for owner, blocked, interrupted,
   completed and unknown. Do not continue on transport loss. Reconnect validates
   service instance, generation, task and grant; reconcile a supported snapshot
   before events. A lost start response remains unknown unless the provider can
   recover that exact request. Never retry by creating another task on speculation.
6. **Archive/remove/re-add:** suspend admission and revoke grants first. Archive is
   not proof of cancellation. Retire only positively owned, unreferenced profiles
   and resources after process quiescence; preserve results/history and leave
   changed/unowned resources for owner resolution. Restore grants nothing. Root
   change or re-add rotates registration/generation and invalidates old callbacks.
   Backup/import retains historical results but excludes live grants, handles,
   credentials and automatic resumes.

## 6. Representative macOS delivery and endpoint

The acceptance slice should be a real bounded Release Radar behavior correction
with a regression test, chosen under a separate implementation brief. The installed
documentation checker alone is too weak a workload to prove a usable build role.

The existing [Xcode scheme](../../ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme)
includes the app, AgentTools, lifecycle helper and DocumentationTool, and runs
`ReleaseRadarTests`. The project pins RDS revision
`f986e85e786f55f1d73d6e429de11370399414f7`. Trusted preparation must supply that exact
dependency and Xcode/SDK version without exposing host package credentials or a
shared mutable dependency cache. Worker dependency resolution stays offline;
unavailable pinned inputs block the build instead of enabling unrestricted network.

Delivery uses repository-native `xcodebuild -project ReleaseRadar.xcodeproj
-scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath <run>/build`
with `test -only-testing:ReleaseRadarTests/<selected test class>` for the actual
change and an appropriate `build` action. This is a proposed invocation shape,
not a test run or guaranteed complete signing setup. Resolve Swift package cache,
module cache, temp and result paths into the role's writable area. A credential-free
compile can use a permitted no-signing configuration; it cannot prove signed XPC,
sandbox, installation or UI behavior. Those checks belong to a separately
authorized isolated QA/signing stage and the normal local release owner.

After delivery, trusted integration freezes the source delta and its input map,
validates changed paths against the brief, and materializes a candidate from the
assigned baseline in its private worktree. Candidate identity includes repository,
baseline and exact resulting content/revision. The worker cannot amend it.

A fresh independent reviewer receives original outcome/constraints, frozen
candidate, approved visual references where relevant and direct evidence. Its
build outputs and report go to its own directory. For tools requiring source-tree
writes, provide a disposable derivative of the fixed candidate; report those
writes and never treat them as the candidate. Required corrections return to the
same delivery outcome, produce a new candidate, and repeat only affected checks
and review. Independence is separate execution/context and authenticated task
assignment, not an agent-written role string.

One integration owner applies only the reviewed delta against the expected
canonical baseline, preserving unrelated dirty work. A changed baseline or semantic
conflict requires bounded reconciliation and relevant review of changed behavior;
an old review does not attest to a materially different merge. Run affected native
checks, update relevant documentation and make the scoped authorized local commit.
Signing/release code runs only after this boundary: the existing
[build/staging script](../../script/build_and_run.sh) includes signing and installed
process/service handling and is unsuitable as an unrestricted worker command.
For an authorized completed app batch the standing version/tag/DMG/install workflow
still belongs to one local release owner. Push, PR, merge and other external effects
retain their separately granted scope. This assessment is documentation-only.

## 7. Hooks and the earlier no-go

Current [Hooks documentation](https://learn.chatgpt.com/docs/hooks#tool-coverage)
describes PreToolUse/PostToolUse for shell, patch, MCP and most local function tools,
including code-mode nested calls. Hosted tools do not use that path; specialized
routes may opt out. `write_stdin` does not rerun PreToolUse. A supported pre-hook
can deny via `permissionDecision: "deny"`; post-hooks observe an already executed
action. Transcript format is not a stable interface. Unsupported output fields
can fail a hook while allowing the tool to continue.

That broader coverage does not overturn I9's recorded no-go for complete
enforcement. State-aware recommendations describe what could become useful after
an independently enforced role envelope and trusted lifecycle state exist. A
hook cannot create those missing controls, authenticate a reviewer or repair
first-turn context leakage. [Command rules](https://learn.chatgpt.com/docs/agent-configuration/rules)
likewise match command policy; they cannot make an omitted test or delivery step
happen, and wrappers require separate consideration.

The concrete proposal uses **no required hook in the admission security path**.
After G1–G3 are established and G4–G5's safeguards are satisfied, an optional
PreToolUse hook may give a precise early denial for
covered prohibited actions; post-hooks may summarize bounded check results without
persisting owner content. A Stop hook may request at most one completion reminder
for an active, authorized run with a known unmet endpoint. STOP, interruption,
approval/question wait, legitimate blocker, unknown state and successful completion
exit immediately. The trusted lifecycle state supplies those distinctions; do not
parse transcripts or let an agent-writable status file grant authority. Hook
failure must never weaken the underlying capability boundary. No hook auto-commits,
publishes, installs, accepts delivery or starts an endless continuation loop.

## 8. Concrete alternative if the native gaps cannot be supplied

**Alternative for a separate owner decision:** a fixed signed RR execution
integration controlling one App Server client and a fresh isolated macOS VM for
each implementation/review role. Use local stdio between the client and its owned
App Server inside the guest; do not open a public or host-wide JSON-RPC listener.
The host-to-guest channel admits only start/status/stop and bounded input/output
transfer for that run. It provides no generic host filesystem, shell, MCP or UI
proxy. This is new runtime ownership and must not be added to ADR-002's helper.

The mechanism capable of exclusion is the guest boundary: no host home/repository
mount, clipboard sharing, owner browser session, host agent socket, shared package
cache or signing Keychain. Transfer only the approved source package on a read-only
input volume. A separate writable volume holds that role's source derivative,
build/tmp and outputs. A read-only review candidate is mounted independently.
Run the worker as a non-admin guest account; provisioning/policy and mount ownership
remain outside that account. The VM host closes the entire role's execution on
revocation, including processes spawned by build tools; it never signals processes
by a shared host name/path. Fresh guests prevent previous worker output and memories
from becoming new context.

The owned client uses the existing App Server start/turn/profile primitives from
section 2, rejects all unapproved client tool requests, supplies no host dynamic
tools, and loads a dedicated guest configuration with no owner plugins/MCP/apps,
memories or hosted research tools. App Server's own service authentication uses a
separately authorized guest Codex login or supported credential boundary; never
copy desktop token files or expose credentials to the model. Network controls
separate required model/auth service traffic from worker subprocess traffic.
If the chosen deployment cannot prevent worker access to service credentials or
unapproved service-side tools, it fails acceptance; an empty filesystem mount list
alone would not fix that issue.

Named command profiles remain useful inside the guest, but host isolation and
read-only volume ownership enforce unavailable host content even if a guest tool
route is missed. Pin the client/backend version and reject unknown enabled tool
families at admission. Provider tool disabling remains necessary for hosted tools
that do not run inside the guest. No claim is made that an unconfigured VM or
stock App Server automatically implements these client policies.

Use a macOS guest with Xcode for the actual macOS build and independent review;
a Linux container cannot replace those acceptance steps. Package preparation,
toolchain provisioning, guest login, signed QA and VM entitlements are new,
explicitly approved installation/security work. Ordinary production build and
local release continue at the trusted host integration endpoint in section 6.

This alternative is a plausible architecture conditional on the listed feasibility
dependencies; it has not been built or tested here. It costs VM/toolchain
maintenance, a small client lifecycle surface and duplicated guest provisioning.
The existing desktop can remain the coordinator's UI. Worker status/results would
be RR observations with external provider/task identities, not native desktop
worker tasks. Opening an external result link or copying a summary into a desktop
task does not change that provenance. No remote-attachment compatibility is assumed.

## 9. Complete acceptance scenarios for either implementation

**All scenarios are proposed and `notRun`.** They become the direct acceptance
scope of a separately approved implementation. Test the actual exposed runtime
inventory, with fresh synthetic canaries and an independent reviewer; do not
repeat the old pilot merely to increase evidence volume.

| Scenario | Allowed result | Required denied/failure result |
| --- | --- | --- |
| Admission/authentication | Exact approved project and native service instance (or explicitly selected external runtime) accepts the one owned request. | Wrong signer/client, project, registration, generation, root, expired/revoked grant and unsupported contract cannot create or inspect another task. |
| First turn/context | A controlled start/turn sequence inspects loaded instruction sources before releasing generation; first model input sees approved sources and exact model/effort/policy. | No preliminary Full Access turn; archive, Git object, stale skill, memory and author-history canaries never enter model input. Unexpected loaded sources prevent the first turn; competing native starts cannot bypass admission. |
| Allowed implementation | Read required code/ADRs; edit scoped source; run a failing regression then passing correction and native build. | Write, unlink, rename, replace or chmod protected input/policy/ancestor; read canonical/peer/history by direct path, symlink, hardlink or alternate tool; request broader permission. |
| All-tool coverage | Approved local tool routes exercise the actual policy. Coordinator can still use its own authorized tools. | Task read/message/fork, connector/MCP resource reads, hosted web, CUA/browser/clipboard, nested code-mode calls, helper sockets and newly discovered tools cannot bypass worker restrictions. Test denial, not merely hidden UI. |
| Network/dependencies | Pinned pre-staged RDS and toolchain build offline; required model traffic uses its own authorized path. | Worker command egress, localhost/Unix socket escape, credential reads and unapproved hosted-tool use fail. Missing dependency returns an actionable blocker. |
| Historical retrieval | Explicit request yields only the named attributed passage in a new protected supplemental input. | Implicit historical link traversal or retrieval of a broader archive fails; current authority remains distinct. |
| Fixed review | Fresh reviewer reads the exact frozen candidate and writes only its own report/build output; directly checks changed behavior. | Candidate modification, delivery-output replacement, author-task ingestion, borrowed self-review identity and stale candidate attestation fail. |
| Follow-up/automatic routes | Ordinary follow-up, steer and valid explicit resume retain the admitted policy. | Manual UI/API widening, fork/resume through another route, subagents or automatic continuation cannot escape the ceiling. A new tool/plugin/client revision suspends incompatible admission. |
| Provisioning conflict/drift | Supported writes/readback and RR-owned records preserve unrelated entries; new revisions pin old runs or explicitly retire them. | Same-name unowned profile, conflicting config revision/owner edit, root expansion, missing key and unsupported setting fail without overwrite/fallback. Unestablished conflict handling prevents mutation. |
| Interruption/recovery | Known run can be stopped; a lost reply is reconciled through supported exact identity or remains unknown for owner recovery without redispatch; owner wait remains idle. | Lost start reply cannot duplicate a worker; missing durable lookup does not trigger speculative retry; stale events cannot revive work; unknown cancellation cannot be displayed as stopped; STOP triggers no follow-up actions. |
| Integration | One owner applies the reviewed delta to its expected baseline, runs affected checks and commits only authorized changes. | Wrong baseline/candidate, extra changed files, concurrent integration, worker-supplied release authority or stale review cannot advance the endpoint. |
| Retirement/re-add | Quiesced owned unreferenced resources retire with history retained; re-add obtains fresh identity. | Removal cannot delete unowned/changed resources; restore cannot revive old grants; late callbacks and backup/imported history cannot restart work. |
| macOS completeness | Actual selected Xcode tests/build run; any applicable signed XPC, UI/mockup, responsive and recovery checks run in their separately authorized QA stage. | Unsigned compilation or documentation validation cannot be labelled full product/runtime acceptance; host owner data and installed apps remain outside worker access. |

## 10. Decisions, delivery status and remaining unknowns

The concrete owner decision is whether to retain native integration while supported
authenticated attachment, pre-turn admission and persistent all-tool enforcement
(G1–G3) remain unestablished, or separately authorize the external macOS
worker-client boundary in section 8. G4–G5 require safe provisioning and
nonduplicating recovery, composed from supported primitives and RR-owned records
where possible; they do not demand new desktop APIs or durable start lookup.
The recommendation is to retain the selected native direction and its explicit
unavailable state until that decision; do not deploy a partial profile/hook setup
under the name of complete isolation.

Either implementation needs a **new architectural decision**, without editing
accepted ADR text, for: (a) the signed runtime-control owner, sandbox/entitlement and
credential boundary separate from observer/plugin lifecycle/delivery mutation;
(b) bounded run/profile/grant identity and recovery fields in the existing store;
and (c) immutable staged-source custody, historical retrieval and candidate-to-Git
integration authority. The external alternative additionally needs explicit
acceptance of losing native worker-task integration and owning VM/client lifecycle.
Record implementation detail in a mutable versioned environment-management design;
do not silently extend Shared Execution V1's delivered contract.

Remaining unknowns are precise: supported third-party desktop attachment/admission,
G2/G3 coverage across all native routes, external project integration and the
conflict semantics needed for safe configuration writes, credential confinement in
the selected alternative, and
usable restricted Xcode/signed-QA behavior. Installed code inspection and current
documentation resolve their API boundaries, not their runtime acceptance. No
permission probe, build, server connection, configuration change or application
mutation ran during this assessment.

Direct assessment checks on September 14 used the proposed working tree based on
the initial revision in section 1. No result below attests to runtime enforcement.

| Check | Runner | Scope | Source | Applicability | Status | Direct result | Limitation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Documentation check/diagnose | Installed `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarDocumentationTool`, 0.1.16 (1) | Repository documentation | This assessment and catalog/index candidate | workingTree | passed | Catalog, documents and generated indexes agree; contract 1 | No application acceptance or runtime claim |
| Preservation | Local Git/Python byte and catalog comparison | AGENTS, seven ADRs, ledger, brief and existing catalog entries | Initial HEAD versus candidate | workingTree | passed | Ten controlling files and all pre-existing catalog records unchanged | Does not establish runtime/configuration isolation |
| Diff hygiene | Local Git | Three owned documentation paths | Candidate diff | workingTree | passed | No whitespace errors; only owned paths changed | No independent content review |
| Runtime scenarios | Not invoked | Section 9 | Proposed scenarios | unknown | notRun | No new runtime experiment | Requires separate implementation/probe authority |

Repository registration remains a proposed/supporting artifact; a changed catalog
is pending application acceptance. No application inventory/binding/readback was
attempted under this repository-only assignment, so no managed-current or delivery
synchronization claim is made. The coordinator owns that distinction and the review
and brief closeout. All new files in this task are durable repository documentation;
no temporary file was created. Existing fixtures and temporary artifacts remain
untouched.

## September 16 App Server findings

The owner authorized retaining this research, not the proposed expansion into
RR-owned execution. This artifact remains **proposed/supporting**, with its
existing catalog identity. The findings correct assumptions in the earlier
assessment; they do not adopt its VM, runtime-manager or provisioning proposals.

### Documented contracts

- **Connection:** a client can launch `codex app-server` and communicate through
  its stdin/stdout using `initialize`, `initialized`, `thread/start` and
  `turn/start`. **Inference from that documented launch sequence:** this
  arrangement does not require attaching to the desktop's existing process or
  finding its control socket.
- **Launch settings:** named permissions can be selected explicitly rather than
  inferred from a coordinator's settings. `config/read` is documented to resolve
  configuration on disk. **Inference about evidence scope:** that result should
  not be treated as a readback of every live worker setting.
- **Approvals and results:** the client receives identified approval requests
  and returns decisions. Turn events distinguish completion, interruption and
  failure. Transport loss alone establishes none of those outcomes; clients must
  retain uncertainty rather than report successful completion or cancellation.

These contracts come from the official
[App Server documentation](https://learn.chatgpt.com/docs/app-server).
They are implementation inputs, not behaviors that need a separate proof harness.

Permission profiles constrain local sandboxed commands, not all retrieval paths.
MCP servers, plugins, apps, web search and browser/computer-use capabilities have
separate controls. MCP server/tool allowlists and plugin-server controls are
documented; a selected filesystem profile is not an all-tool isolation claim.
Sources: [permission scope](https://learn.chatgpt.com/docs/permissions#scope-and-enforcement),
[MCP configuration](https://learn.chatgpt.com/docs/extend/mcp), and
[configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

### Installed interface and observed behavior

The bundled CLI reported `0.154.0-alpha.6.2`. Its generated experimental schema
includes `cwd`, `permissions`, `config`, `approvalPolicy` and `approvalsReviewer`
in `ThreadStartParams`. `ThreadStartResponse` includes resolved cwd, approval
settings and sandbox, plus optional `activePermissionProfile` identity. That
optional identity is not a complete inventory of effective filesystem/tool rules.

A short-lived separate App Server successfully initialized, listed the configured
RO/restricted profiles as allowed, read effective repository configuration and
read Main coordination's existing task metadata. It reported that task as
`notLoaded`; its loaded-task list remained empty. The inspection process was
stopped without starting or resuming a task. This establishes API connectivity
and stored-task access, not shared control of the desktop's live tasks.

The desktop process used stdio. The default control-socket proxy failed because
its socket was absent. That is a bounded connection finding, not proof that all
desktop integration is impossible. Worker creation, effective tool restrictions,
desktop synchronization and execution through the signed RR app were not tested
by this inspection. The desktop `create_thread` wrapper's missing profile selector
must not be presented as a missing App Server capability.

### Outcome 3 scope and remaining limitations

Outcome 3 remains the native hook pilot, correct worker startup, ordinary-worker
history exclusion with deliberate coordinator retrieval, and delivery-record
closeout. The native pilot is complete; these findings do not complete history
exclusion or reopen the pilot. They do not authorize another denied-path probe.

RR-owned worker execution, run/approval UI and execution hosting are **outside
this outcome and are not authorized by these findings**. The current
[dashboard design](agent-driven-delivery-dashboard-design.md) requires bounded
observation; [I7 in the full-product plan](../delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md#integrations-presentation-and-execution-reliability)
leaves app-owned execution as a separate decision. Existing-desktop observation
and client-owned execution must not be conflated.

If app-owned execution is separately pursued, its macOS hosting boundary requires
a specific design. RR is sandboxed, and its plugin lifecycle helper is confined
to fixed plugin operations under [ADR-002](../architecture/ADR-002-codex-plugin-lifecycle.md).
Apple documents that sandbox inheritance does not automatically carry dynamic
file-access grants to child processes. A terminal connection therefore does not
establish signed-app compatibility. Source:
[Apple App Sandbox inheritance](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).
This limitation is not a requirement to build a helper, VM or prototype now.

Trust documented behavior. Reserve any future narrow experiment for a consequential
question left unanswered by sources or an observed implementation mismatch.

## September 16 onboarding and worktree integration contract

### Assignment and evidence

Owner-approved scope: map RR's existing onboarding and plugin installation to
project-owned worktrees and per-worker checkout permissions, identify the necessary
plugin interface changes, and persist a bounded implementation plan. This is design
and documentation only. No installation, runtime/configuration change, worktree
migration, new shared-Git work, or product implementation is authorized here.
The owner granted Main a one-time documentation provisioning/writing exception
because Restricted coordinator 02 cannot provision under its current runtime.

Source baseline: remote main c8dd3c2a99dc7e5f6fa76414a5247f51ffd9a8be, in branch
codex/outcome3-onboarding-worktree-contract. Shared-execution/1 applies; installed
0.1.18 skills declare standard 1. Source inspection, documentation checks and one
independent architecture/permission-boundary review are sufficient for this plan;
no native build or runtime prototype is required. The standalone coordinator plugin
0.1.0 remains a separate reviewed, uncommitted candidate on
codex/coordinator-app-server-plugin; this branch does not import or alter it.

### Existing implementation to extend

| Responsibility | Source evidence | Integration consequence |
| --- | --- | --- |
| Project identity and authorized folders | [FolderProjectOnboarding](../../ReleaseRadarCore/Onboarding/ProjectOnboarding.swift), `inspect`, `prepare`, `finish`, `authorizeWorktree` | Reuse existing registration identity, bookmark authorization and pending/completed setup flow. Today external worktrees are separately authorized; onboarding does not provision execution permissions. |
| Onboarding completion and errors | [OnboardingView](../../ReleaseRadar/Projects/OnboardingView.swift), `finish` | Attach deterministic execution setup to the existing onboarding completion path, preserving pending/error recovery rather than sending an LLM a setup prompt. |
| Plugin lifecycle and user intent | [CodexPluginLifecycleCoordinator](../../ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift), `install`, `update`, `reinstall`; [AppModel](../../ReleaseRadar/App/AppModel.swift), plugin actions | Reuse installation/update/removal and modification-preservation behavior. Do not introduce a parallel installer or require marketplace commands from the user. |
| Privileged operation boundary | [CodexPluginLifecycleClient](../../ReleaseRadarIntegration/CodexPluginLifecycleClient.swift) and [helper](../../ReleaseRadarPluginLifecycleHelper/main.swift) | Existing typed operations are status/install/remove/reinstall for a fixed plugin. They are not permission-profile or Git-worktree operations. |
| Package recognition | [PluginDigester](../../ReleaseRadarPluginLifecycleHelper/PluginDigester.swift) | Fixed release-radar identity, exact package inventory and MCP shape currently exclude the standalone coordinator-workers package. Reuse requires an explicit packaging change, not copying additional files into the current cache. |

[ADR-002](../architecture/ADR-002-codex-plugin-lifecycle.md) remains unchanged. It
establishes the fixed plugin/helper boundary and Codex ownership of installed state.
The app's [entitlements](../../ReleaseRadar/ReleaseRadar.entitlements) and existing
bookmark flow do not establish a general-purpose project provisioning service.
Any required change to that accepted boundary needs a new explicit decision before
implementation; this plan neither grants the existing helper new authority nor
creates another helper.

### Ownership and permission contract

1. Onboarding is the user's agreement to the project's execution workflow. RR
   application code establishes the corresponding project execution policy
   deterministically, using the existing project identity and authorized repository.
   No LLM generates policy, edits permission tables or configures host environment
   variables. Provisioning failure remains visible in setup; it is not reported as
   execution-ready merely because registration exists.
2. RR owns creation, assignment and cleanup of its worktrees under
   `<RR worktree root>/<stable project identity>/<task identity>/`. The stable ID
   controls identity; a readable project name may be a label. The actual base path
   comes from RR's platform storage policy, not a user's copied absolute path.
   This does not move existing worktrees or take ownership of Codex-managed ones.
3. Project-level management authority belongs to RR and its authorized coordinator
   route. An ordinary worker receives one assigned checkout as its runtime root,
   a role-specific permission profile, the bounded assignment and model/effort.
   It does not inherit the coordinator's project-parent grant or sibling roots.
   Existing historical and shared-Git exclusions are unchanged constraints, not
   new work in this follow-up.
4. Future worktrees reuse onboarding's rules; creation produces an assignment,
   not another hand-authored permission configuration. The launch path validates
   that the checkout belongs to this project/task and that effective roots and
   grants do not expose siblings. RR owns the project association; an LLM-supplied
   path or role string alone is not authority.
5. Install/update remains the existing RR plugin lifecycle user experience. Machine
   executable paths and configuration delivery are implementation details of that
   integration. Manual JSON editing, shell startup files and environment-variable
   setup are not the product acceptance criteria. Existing explicit removal and
   modification-preservation semantics must survive adoption.

Codex documents changing its overall Worktree root in Settings, but the inspected
public interfaces do not establish a per-project `<project>/<task>` layout. RR-owned
Git worktrees followed by explicit App Server checkout selection provide the chosen
ownership model; no change to Codex's managed layout is required.
[Official worktree documentation](https://learn.chatgpt.com/docs/environments/git-worktrees).
Codex combines runtime roots with profile-defined roots, so merely passing a narrow
cwd cannot cancel a broader grant. Workspace-relative rules apply to each effective
root and can be reused across assignments.
[Official permission documentation](https://learn.chatgpt.com/docs/permissions).
The inspected installed App Server schema exposes cwd, runtimeWorkspaceRoots and
named permissions; the plugin has already exercised explicit checkout/profile
startup. [Official App Server documentation](https://learn.chatgpt.com/docs/app-server).

### Necessary changes to the standalone plugin interface

The current candidate expects COORDINATOR_WORKERS_POLICY to select an owner-maintained
JSON file containing the executable and static assignments of cwd, profile, allowed
models and excluded paths. This works for the reviewed development candidate but
leaves new task/worktree assignments and per-computer setup outside RR.

Retain its bounded App Server lifecycle, approval identity and unknown-outcome
handling. Replace manual configuration ownership with deterministic RR-provided
project policy and current assignments. The public worker launch should identify
an authorized assignment; it must not accept arbitrary permission/config overrides.
RR's producer and the plugin's consumer need one explicit delivery/read contract
with protection from worker modification. A file-based contract may suffice; a new
service/database is not required by this plan. Do not select transport or cache
placement by assuming the current environment-variable interface is permanent.

Before integration implementation, resolve these two concrete boundary decisions:

- **Packaging:** choose whether coordinator capability joins the existing RR plugin
  or is a second fixed managed package. Recommendation: preserve the existing RR
  installation experience and identity where compatible, but first verify how the
  coordinator-only tool exposure is retained. Update the exact package inventory,
  MCP validation and version recognition accordingly; do not relax integrity checks
  or introduce arbitrary plugin installation.
- **Provisioning ownership:** identify the permitted RR code path for producing
  project policy/assignment data and managing Git worktrees under macOS folder
  authorization. The current lifecycle helper is not that path. Specify exact typed
  operations and storage access if an existing boundary must change; obtain the
  architectural decision before implementing it. No generic shell executor is
  implied, and onboarding consent does not itself supply macOS filesystem access.

These are defined implementation prerequisites, not claims that unsupported
operations already work. Outcome 3 cannot close on a standalone-plugin PASS while
this product contract remains unimplemented or these decisions unresolved.

### Owner clarification: project hook configuration remains in Outcome 3

The owner explicitly confirmed that hooks belong to Outcome 3 and that RR must
configure them deterministically for each onboarded project. Native pilot
completion establishes the tested behavior, not completed product integration.
App Server, permissions and worktree provisioning do not replace this requirement.

Before implementation proceeds, reconcile the original Outcome 3 hook requirements
with delivered behavior and validate the supported configuration contract against
official Codex documentation and RR's existing implementation. The same onboarding
plan must specify required hooks, configuration ownership and location, applicability
to the project and assigned worktrees, installation/update/readiness verification,
preservation of unrelated user hooks, and failure recovery, disablement and removal.
Manual configuration and LLM-generated setup are not the intended user workflow.

This is a persisted owner requirement and pending investigation, not a claim that
these mechanisms are already designed, reviewed or implemented. It does not reopen
settled shared-Git work or authorize configuration changes. Outcome 3 closeout must
account for hook integration as well as the remaining worker-startup and historical
context requirements. This clarification postdates the independent review recorded
for the earlier onboarding/worktree plan.

### Packaging and provisioning decision — September 16 follow-up

This section resolves ownership and packaging direction for implementation planning;
it does not authorize implementation or claim the remaining readiness gaps solved.
The earlier two alternatives are superseded by the choices below. The same named
branch and documentation-only assignment apply.

**Packaging:** retain the single `release-radar` plugin and existing RR installation,
update, removal and reinstall flow. Integrate coordinator launch capability into
that package; do not introduce a separately installed coordinator product. Update
its fixed inventory and MCP validation deliberately, preserving integrity and user
removal/modification semantics. The reviewed development plugin remains a separate
candidate until integrated. Package hook handler code as a signed RR application
resource, registered through project configuration rather than plugin-only hooks.
No second installer is needed. The exact callable coordinator transport must retain
assignment authorization; packaging a tool is not proof that its caller is Main.

**Why project registration:** the current standalone adapter's `worker_overrides`
disables `features.plugins` and configured MCP servers for ordinary workers. Keep
that isolation. Plugin-only hook discovery cannot be assumed to survive it.
A project-local command hook avoids requiring coordinator tools or a live MCP
connection in workers. Do not register the same RR handler in both sources.
The native pilot used `UserPromptSubmit` with session/root scoping; its synthetic
BLOCK tokens and hard-coded session must not become production admission policy.
The original brief asked where hooks help, not an unbounded set of lifecycle hooks.
The remaining product definition is the real admission predicate and required
context, not another transport proof or an invented Stop/retry automation loop.

**Application owner:** extend the existing native onboarding path
`FolderProjectOnboarding.prepare/finish`, with a narrowly typed execution-setup
operation in RR's integration layer. RR owns project identity, consent, policy
materialization, assignment records and readiness. Complete setup only after its
required checks; reuse pending registration/recovery rather than a second workflow
engine. The lifecycle helper remains the fixed four-operation installer from
ADR-002; it receives no project provisioning, Git or generic command authority.

RR performs authorized project-file writes in-process using its existing folder
bookmark access. Store RR-owned task worktrees under the existing app-owned storage
root, grouped by stable project/task ID. Coordinator assignment delivery must expose
only the needed generated policy through a typed interface or protected file;
workers cannot modify it. Reading the current `GitWorktreeDiscovery.runGit` is not
proof that Git writes will work from the sandbox: it only launches discovery.
Apple explicitly distinguishes static inherited sandbox rights from access acquired
after launch. Therefore do not implement provisioning by assuming an ordinary Git
child inherits the application's selected-folder grant.
[Apple sandbox inheritance](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).

For Git provisioning, recommend in-process libgit2 behind the same typed RR
integration operation, while RR holds its repository bookmark access. Its documented
worktree API accepts an explicit destination and reference; this avoids a child
process and grant-transfer machinery. This is a new dependency recommendation,
not an installed dependency or runtime verification. Pinning, license/security
assessment, existing-repository compatibility and focused signed-app tests belong
to its implementation review; preserve ordinary Git interoperability and dirty
worktree refusal. Do not hand-write Git metadata or widen the lifecycle helper.
[libgit2 worktree creation](https://libgit2.org/docs/reference/main/worktree/git_worktree_add.html),
[reference selection](https://libgit2.org/docs/reference/main/worktree/git_worktree_add_options.html),
[pruning safeguards](https://libgit2.org/docs/reference/main/worktree/git_worktree_prune.html).
This selects an implementable application boundary without introducing a new
privileged service. Dependency adoption still needs inclusion in the approved
implementation scope; no library or entitlement was changed here.

**Per-project hook lifecycle:** onboarding prepares RR's registration in the
trusted checkout's `.codex/hooks.json` (or the existing inline hooks representation
when that is already used), pointing to the installed signed handler. Derive the
path from the installed app, not a developer path or shell environment variable.
Use a bounded merge that preserves other definitions and detects conflicts; never
replace the entire user file. Register once at the primary repository. For each new assigned linked worktree,
verify that Codex resolves the expected primary registration before its first turn;
do not duplicate it into every checkout. The cross-worktree evidence below
supersedes the earlier unverified per-checkout registration proposal. Guard execution by registered project/assignment;
an unregistered project receives no RR workflow enforcement. The generated
configuration and handler must be protected from ordinary worker changes.

RR updates/removes only its own unchanged registration. A conflicting edit stays
visible for recovery. Disabling/removing the RR workflow stops new governed worker
launches and removes or disables only RR's registration; it must not disable all
Codex hooks or silently re-enable an owner's disabled hook. Existing worktrees are
not migrated by this design task. Updating a handler requires RR package-integrity
verification independently of Codex's definition trust.

**Readiness boundary:** require project configuration trust and exact-definition
hook trust, and inspect discovery, enablement and trust before worker launch.
The initial claim that no programmatic trust route existed was incorrect: the
installed desktop uses `config/batchWrite` for `hooks.state`. The verified
cross-worktree result and resulting onboarding contract are recorded below.
[Official hooks documentation](https://learn.chatgpt.com/docs/hooks) and
[App Server configuration API](https://learn.chatgpt.com/docs/app-server) supply
public contracts; the concrete state-key use is installed-version evidence.
Outcome 3 remains open for implementation; this is not a signed-RR runtime pass.

Source basis: current remote-main baseline c8dd3c2; inspected onboarding,
GitWorktreeDiscovery, app entitlements, PluginDigester and accepted ADR-002; supplied
pilot brief in the primary checkout; inspected standalone adapter/policy candidate;
official documentation fetched September 16 and installed App Server generated
schema. No hook, profile, trust, installation or application state was changed.
Independent reviewer `01a0abf3-7ace-7a22-a2b2-e04a8bba7679` (Sol/high,
verified rr-project-ro) returned PASS with no Required findings. Review used current
repository sources and cited excerpts; external DNS failed, so it did not independently
fetch official sources. Main fetched those sources directly. Documentation and diff
checks passed. This review does not establish implementation readiness.

### Admission rule and trust disposition — September 16

This resolves the preceding admission/trust investigation at design level. It
supersedes “predicate remains undefined”; it does not claim implemented enforcement
or silently relax the all-in-RR onboarding requirement.

**Admission rule:** ordinary work proceeds only for a current, owner-authorized
assignment whose project registration, exact checkout, role, selected current
context and permission configuration match the launcher's verified assignment.
Use the existing assignment/lifecycle record, not an agent-written ledger or a
prompt assertion. A stopped, revoked, superseded, unverified or unknown assignment
cannot authorize another work turn. A follow-up cannot broaden role, roots, tools,
model permissions or historical access; a changed assignment must be re-established
through the coordinator. Main's deliberate historical retrieval remains separate.
This translates the original current-context/worker-isolation requirements; it does
not introduce a task-completion engine, proof ledger or general prompt classifier.

| Situation | Launcher decision | Hook behavior |
| --- | --- | --- |
| Current verified assignment, matching checkout/session and current context | Admit bounded work | Continue; no synthetic token required. |
| Known RR worker with revoked/stopped/superseded assignment or mismatching checkout/session | Refuse new work | Block an ordinary submitted work prompt with a concise reason and recovery action. |
| Known RR worker whose assignment cannot be read or validated | Refuse new work; report unavailable | Return an explicit block when the handler can execute and identify the managed worker. A crash/timeout/disabled hook is not a reliable block. |
| User changes task scope or asks for broader access | Return to coordinator for a new authorized assignment; do not mutate policy from prompt text | Do not infer authorization or permissions from natural-language claims. |
| Main/coordinator or an unrelated session outside RR's worker assignment | Apply its own separately authorized workflow | Do not apply ordinary-worker blocking globally. |
| STOP, cancellation, approval wait or recovery | Interrupt/pause through the control path; no work turn is required | Never demand more work, auto-retry, or prevent disablement. Recovery changes state outside the blocked worker. |

The production `UserPromptSubmit` handler checks assigned session/checkout and
assignment status, not arbitrary shell command strings or transcript contents.
It receives only the minimal worker-specific read-only assignment snapshot; parent
project policy and sibling assignments stay inaccessible. Protect that snapshot
and the hook definition against worker writes. Establish the session binding from
runtime identity before the first ordinary turn; never copy the pilot's hard-coded
ID or treat an agent-supplied ID as authority. The launcher owns this binding and
checks admission before first and subsequent turns. No LLM infers eligibility.

The hook cannot independently attest the full sandbox, loaded context or all tool
routes from its event payload. Those checks remain in the controlled launcher and
runtime permission boundary. Unknown native/manual sessions are not silently
adopted as RR workers; universal control of arbitrary desktop sessions is not
claimed. `UserPromptSubmit` does not substitute for in-flight revocation or tool
permissions. STOP uses the independent interrupt/control route, with confirmation
from runtime completion; no Stop continuation hook is added. Malformed events and
handler failure are readiness failures, never proof that work was blocked.

### Verified hook trust across linked worktrees — September 16

**Correction:** the earlier “no persistent external trust mutation established”
conclusion searched for a dedicated hooks/trust endpoint and missed how the
installed desktop actually implements Trust. No Codex-only approval handoff is
required by the evidence now available. The all-in-RR onboarding objective is
retained, not replaced with the previously proposed UX compromise.

**Installed implementation:** ChatGPT.app's `app.asar` contains
`webview/assets/hooks-settings-1700361090d3.js`, whose Trust action submits
`{key: hook.key, trustedHash: hook.currentHash}`. Its imported mutation in
`webview/assets/app-initial-4d7ea7f81c2d.js` calls `config/batchWrite` with
`keyPath: "hooks.state"`, `mergeStrategy: "upsert"` and a value mapping that key
to `{trusted_hash: currentHash}`; it requests configuration reload. This is the
application's own use of the documented configuration API, not a private database
write, a fabricated hooks/trust method, or an invocation bypass. It is evidence
for installed Codex 0.154.0-alpha.6.2; the specific hooks.state representation is
not independently promised as a stable public hook-trust API.

**Controlled check:** one synthetic Git repository, separate fixture-only Codex
home, two linked worktrees A/B, and a third linked worktree C created after the
trust write. Only the primary repository had `projects.<root>.trust_level =
"trusted"`; no A/B/C project trust entries were supplied. Its tracked hooks.json
contained one UserPromptSubmit command `/usr/bin/true`. Hooks were listed only:
no hook was executed, no model turn started, and no real Codex configuration,
project hook, credentials, installation or application store was changed.

| Check | Actual result |
| --- | --- |
| Before hook approval: primary, A and B | All discovered the same hook from the primary repository's `.codex/hooks.json`; all reported untrusted. No discovery warnings/errors. |
| Identity | Every row used `<primary>/.codex/hooks.json:user_prompt_submit:0:0` and identical definition hash, rather than a worktree-specific key. |
| Single trust write, selecting A's returned key/hash | `config/batchWrite` returned `ok` and the isolated config file path/version. |
| After that write: primary, A and B | All reported trusted with the same source path/key/hash. |
| C, created after approval | Discovered the same primary hook and reported trusted without another project-trust or hook-trust write. |
| Persistence | Fixture config.toml contains only the primary project trust entry and the single hooks.state key with trusted_hash. |

Thus both project configuration discovery and hook approval carried across the
existing and subsequently created linked worktrees in this installed-version
check. This does not assert inheritance for independent clones, moved primary
repositories, conflicting configuration/trust overrides, changed hook definitions,
other Codex versions or every possible linked-worktree topology. Definition hashes
remain relevant; unchanged source identity does not approve a changed definition.
No additional probe is needed to establish the tested result.

**RR onboarding implication:** configure the exact RR hook once in the registered
primary repository, preserving unrelated hooks. Derive its command from installed
signed RR resources. Under onboarding's explicit workflow consent, inspect the
resolved hook, verify it is the exact RR-owned definition and handler, then apply
its returned key/hash through the same configuration API. Upsert only RR's entry;
never trust the entire discovered inventory. Read back that definition's enabled
and trusted status. Do not claim that writing a hash proves handler integrity.
The signed package and RR verification own that separate property.

Subsequent linked worktrees use the primary registration; validate expected source
and trust when preparing each assignment rather than ask for approval by default.
A changed or conflicting definition is a recovery state, not automatic permission
to approve arbitrary content. Preserve explicit disable/removal and unrelated
configuration. Scope/version checks and configuration concurrency handling belong
to the integration; no direct trust-store edit or bypass flag is needed.

This resolves the worktree-trust uncertainty and withdraws the proposed mandatory
Codex UI handoff. It does not prove the sandboxed RR app can yet invoke the API:
that remains implementation work through its approved integration boundary, not
new authority for the fixed plugin installer helper. No library, service, hook or
permission implementation was added by this investigation. The admission rule
above remains the design contract; Outcome 3 remains open.

Sources: installed files named above; generated installed App Server schema;
[official hook trust semantics](https://learn.chatgpt.com/docs/hooks);
[documented config/batchWrite and hooks/list](https://learn.chatgpt.com/docs/app-server).
Main directly inspected source and ran the isolated check. This result supersedes
the earlier negative trust findings and their reviews. Documentation checks and
one independent review cover this correction; no runtime hook enforcement is
claimed from a discovery/trust-state test.

### Separate delivery sequence and acceptance

1. Implement the selected packaging and provisioning boundaries above against the
   existing installer and project authorization code, resolving implementation
   compatibility and sandboxed API access. Keep the reviewed standalone plugin change separate.
2. Deliver deterministic onboarding/worktree ownership and RR-to-plugin assignment
   integration in bounded implementation changes, with focused authorization and
   failure/retry checks. Reuse registration/setup state and current app-owned storage;
   do not add an execution dashboard, general task database or reconciliation engine.
3. Deliver packaging through the existing install/update/reinstall path. Verify on
   a second computer that installation and project onboarding require no manual
   path/profile/JSON/environment editing; a new task gets the assigned checkout,
   the existing exclusions apply, sibling checkout access is absent, and setup
   failures recover through RR. This future validation is not claimed by today's
   source inspection and requires separately authorized implementation/installation.

Current documentation endpoint: source-backed plan plus independent review and
repository documentation validation. Outcome 3 remains open. Runtime work, commits,
push/PR, installation, migration and application catalog acceptance are not performed
by this follow-up. Catalog identity/authority/lifecycle are unchanged; this mutable
assessment has no checksum. No new durable document or competing ledger is created.

### Implementation checkpoint — September 16

The owner separately released onboarding/plugin implementation, including production
hooks, in the [controlling implementation brief](../delivery/task-briefs/2026-09-16-outcome3-execution-setup/brief.md).
This grants no live configuration, trust/profile mutation, installation, merge,
SQLite/application acceptance or publication. The original documentation-only
assignment remains historical; the September 16 amendments govern this delivery.

The implementation uses a native, signed, unprivileged plugin-side stdio adapter
and hook mode, retaining the single managed plugin and the fixed four-operation
installer helper. Main approved this native port to avoid a Python/manual-policy
runtime prerequisite on another computer. The exact reviewed Python candidate was
identified at `8cd8cd8` in the standalone source checkout and twelve source files
were copied byte-for-byte through BuildAgent into this worktree before reuse; its
prior PASS is attributed component evidence, not integrated runtime proof.

Protected policy and task-specific assignment JSON live in the existing application
group’s `Execution/Projects` and `Execution/Assignments`; worker checkouts live
separately under `Execution/Worktrees/<project>/<task>`. The plugin launch accepts
project/assignment identities and a bounded prompt, without role, path, profile,
model or effort overrides. Application-produced assignments carry existing scoped
owner authorization; host/runtime approval decisions remain separate. Durable
unknown start intent prevents a replacement connection from repeating an uncertain
launch. First and subsequent turns require current assignment/session/root/context
and hook readiness. Unknown native/manual sessions are not adopted by the hook.

The draft is checked against installed Codex 0.154.0-alpha.6.2’s exported static
schema: `hooks/list` uses `cwds` and returns `data` entries, and `instructionSources`
is an array of path strings. Discovery warnings/errors, disablement, modified
trust, source/command mismatch or unsupported shapes fail readiness. No new runtime
probe was needed for schema verification. Native/signed integration is unverified
until Main/BuildAgent exercises the bounded candidate.

The preliminary local libgit2 1.9.4 proposal was never adopted and was withdrawn
after the owner identified CVE-2026-53587. The selected portable source pin is
[upstream 1.9.5](https://github.com/libgit2/libgit2/releases/tag/v1.9.5), immutable
`f7a4071c766ceea3915415e22134cbe3e581c420`, whose release explicitly fixes that
vulnerability and related issues. Main authorized exact source procurement after
the worker’s codeload access was denied. BuildAgent verified the tag/source and
archive SHA-256 before handoff. The canonical source archive, upstream COPYING and
notice accompany the app under `ReleaseRadar/ThirdPartyNotices`; the fixed
`script/build_libgit2.sh` prepares a static library offline with network/auth
transports off and system regcomp. CMake is development tooling only, configured
through `CMAKE_EXECUTABLE`, with no product runtime/Homebrew requirement, source
fetch during Xcode, host configuration or installer-helper authority expansion.
The release security fix is not a blanket security clearance for all library APIs.

Seven focused native assignment/hook tests and eight protected-store/onboarding
retry/adapter/readiness tests passed through Main/BuildAgent. The initial
missing-type baseline was not run. Offline arm64 library preparation and native
app compilation passed. Both worktree tests stopped before product behavior:
their Git subprocess fixture invoked sandbox-prohibited xcrun. The correction
uses in-process libgit2 fixture operations, preserving app entitlements.

The C dependency is an internal import and cannot appear in the provisioner's
public Swift contracts. RRCore remains non-resilient, so its direct build consumers
need the pinned module/header search paths. This follows
[Swift's transitive-dependency contract](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md#transitive-dependency-loading)
and avoids unsafe implementation-only hiding or changing the entire framework's
library-evolution model. Native compilation of this correction passed.

The owner authorized a minimal hosted test of the real App Server transport with
isolated fixture HOME/CODEX_HOME and the fixed installed OpenAI-signed executable.
No real home/configuration/trust or installation changes are included. Host
signing, entitlements and execution context must be reported: a privileged runner
is not app sandbox evidence, and a container fixture does not prove grants to an
external bookmarked repository. The hosted check ran with appSandbox=true but
Xcode-injected root-read/test-manager/get-task-allow entitlements; it is not
production-equivalent. App Server spawned, then a response timed out with unknown
RPC phase/outcome. No trust/configuration broadening is justified by this result.
The source reader used Foundation's filling read(upToCount:) on a live short pipe;
one bounded POSIX read per chunk corrected the hosted protocol check, which passed
initialize/hooks-list/close with no residual process.
Native close now waits for EOF, then bounded termination, exit and reader join;
cleanup errors remain unknown and cannot produce a false closed result.

The in-process worktree collision fixture passed. Clean removal failed because
libgit2 requires PRUNE_VALID independently of PRUNE_WORKING_TREE. The correction
adds that flag only after exact identity and clean-status checks; dirty removal
remains prohibited. The corrected creation/removal case and four affected adapter
checks passed. One tiny signed actual-source bare fixture subsequently compiled and
passed exact app-entitlement/signature checks but trapped during sandbox initialization
before main. It invoked no App Server and created no fixture home. Main stopped
that unsuitable verification approach; it does not establish actual app/API
incompatibility. The next production boundary check must exercise the actual built
app under a separately resolved isolated-data launch authorization.

The single plugin's existing MCP inventory now includes the fixed signed native
coordinator beside AgentTools. Core and installer-helper validators require the
same exact inventory and reject command/argument/environment near misses. No fifth
helper operation, second managed plugin, environment setup or Python runtime is
introduced. App/package version 0.1.18 and its published recognized digest are
unchanged. The new candidate digest is deliberately unregistered until the
coordinated release owner assigns release identity; this candidate is not claimed
as an equal-version update. Checkpoint 7 passed 22 of 26 cases, with four failures
at the published digest or pre-existing version expectations. The newly introduced
test-fixture inventory defect was corrected, and both affected package tests passed
at checkpoint 8.

Native onboarding now records versioned owner consent and an owned hook edit intent
in protected policy before modifying the primary project's fixed hook file. Pending
retry accepts only its exact before/intended bytes, preserving conflicting edits
and explicit disablement. Existing inline project hooks use version-checked App
Server edits to their config.toml; no shadow hooks.json is created. Only the exact
owned definition may receive hook trust, and completion requires trusted readback.
Prepare/verify close configuration connections on all paths; failed cleanup remains
unknown. Protected authority writers use stable per-file advisory locks plus expected
JSON comparisons; primary owner hook edits retain conflict checks without claiming
atomic cooperation from arbitrary external editors.

Onboarding presents scoped execution consent and a resume action for saved pending
setup. Checkpoint 9 app dependency build and all 16 focused setup/store/readiness/
onboarding/hook checks passed, including failure, conflicting edits, inline storage
and cleanup. The initial setup actor preceded its tests; no initial red native run
is claimed. No arbitrary prompt authorization,
role/path/profile/model inputs or new approval service are admitted. Production
flow wiring, review-role assignments, owned update/removal, runtime acceptance,
responsive mockup comparison and independent review remain incomplete; Outcome 3
is not closed.

#### Existing onboarding authority and assignment admission

The owner said in the Main conversation:

> When a user onboards a project into release radar, they are agreeing to the execution workflow. full stop. so configuring permissions for a project should be done at that time. This should not be left to an LLM to do, that would be overkill and my feeling is the results will vary wildly. Installing the pluging should follow a simiar pattern that we have already established in RR.

The subsequent implementation approval was:

> approved -- Outcome 3 implementation: integrate project execution setup into RR’s existing onboarding and plugin installation flows

Main's implementation interpretation is that structured app-owned onboarding policy
and current registered work identities carry scoped authority for delivery and
independent review. Another per-assignment owner approval is not required; Main
withdrew its earlier optional choice as a redundant, self-created gate. Phase
eligibility or a natural-language Main assertion alone does not confer authority.
Use the existing command envelope with exact root/registration, work identities
and expected revisions; derive role, scope, context, baseline, checkout and worker
settings in app code. Caller role/path/model/profile/authorization/prompt overrides
are inadmissible. A signed management client is not cryptographic Main-task identity;
association with Main is operational. Ordinary workers must have management tools
disabled and management executables, shared Git/history and sibling storage excluded,
with direct native boundary checks before acceptance. This source authorization
does not permit live configuration, installation or owner/application-state mutations.

#### Assignment production and conservative invalidation

The unexposed native producer captures current registered work and expected task-plan
and phase revisions. It derives the worker role and finite permission profile,
records preparation before configuration, and resumes only the exact request.
Uncertain worker launches cannot be replaced by another request. Independent review
uses an opaque reference to a known closed delivery assignment and verifies that
assignment's exact clean committed candidate in its assigned branch/worktree; the
primary checkout's HEAD is not the review candidate. Review does not require prior
task acceptance or completion. Context is bounded, read through stable descriptors
and pinned to committed checkout bytes.

Relevant app-store mutations reconcile current work against protected assignments
before SQL COMMIT. Filesystem revocation and SQL are not atomic: if SQL later rolls
back, the assignment stays revoked and requires explicit recovery. Failed revocation
blocks the mutation. Unrelated evidence and notification scopes do not trigger this
reconciliation. Production wiring must configure reconciliation before admitting
execution; absent legacy/test injection grants no execution authority. A prompt hook
checks the next turn and is not an instantaneous interruption mechanism; STOP still
requires the independent interrupt operation. Lost connections remain unknown even
if a late completion notification arrives.

Corrected checkpoint 10 app compilation passed after an explicit execution-error
recovery mapping and its focused regression. Of 29 tests, 26 passed, including
producer, admission, profile, adapter and error presentation; all three lifecycle
cases stopped before behavior at a new fixture's nonexistent bookmark `id` column.
The fixture insert now uses the repository's current composite-key schema, with no
production schema changes; all three corrected lifecycle tests passed. The first
coherent source candidate now wires the single app-owned preparer and exact protected
root into the production bridge. The app's primary store observes relevant mutations
from construction, and both stores reconcile before execution admission. Recovery
reconciles before adopting the replacement store. Legacy/test bridge defaults and
documentation maintenance have no preparer and cannot authorize execution.

AgentTools publishes the bounded preparation command with mandatory registration,
work IDs, expected revisions and optional opaque candidate/correction reference.
Unknown role/path/model/profile/authorization/prompt/baseline fields are rejected
at the tool and callback boundaries. Replay reads current assignment state instead
of reauthorizing a stopped assignment. This route does not launch or commit code.
Ordinary workers retain Git/history denial; Main's authorized trusted route commits
the exact delivery worktree before a fresh review assignment verifies its candidate.
New production wiring and route tests await native checks and independent review;
sources and documentation are frozen for the first scoped commit checkpoint.
Producer/lifecycle source initially preceded its tests; no red baseline
is claimed. Production sandbox/configuration access, actual worker boundaries,
owned update/removal, UI QA and independent candidate review remain open.

The pinned libgit2 source archive, license/notices, dependency lock, module headers
and offline build script are durable reproducible inputs. The copied standalone
Python plugin under `plugins/coordinator-workers/` is temporary reference material,
not shipped product source. The stopped `script/fixtures/execution_app_server.swift`
is temporary abandoned verification material. Both are excluded from the source
candidate; no deletion is authorized. Generated `.build` tools/dependencies and
`build` logs/results are temporary native-check outputs, retained pending owner
disposition. No durable deliverable is assigned to those temporary paths.

#### Required corrections and owned hook lifecycle checkpoint

The first scoped source candidate is `ffdd65601bd36852b801d79a2061a68f4c7548cc`.
Its direct checks passed, but fresh independent review returned four Required
findings; it is unaccepted. The following correction source passed Main/BuildAgent's
checkpoint 12 app dependency build and 34 focused tests after a missing-`await`
compile correction. Documentation/index and diff checks passed. These source checks
do not establish runtime UI or production boundaries; the correction candidate
remains unaccepted pending the same review assignment. The delivery ledger owns the
current result and remaining work.

Configuration preparation now leaves a protected assignment in `preparing`.
After awaited preparation, the app rechecks deadline, exact registration/root,
current work and exact request receipt before synchronous protected admission
inside its final store transaction. Failure revokes that exact preparation. An
unlaunched finalization failure may resume only the same request; another UUID
cannot bypass its recovery barrier. Filesystem authority and SQL are not atomic;
failed SQL finalization invokes protected revocation and reports any failure of
that revocation rather than claiming completion.

Startup records a non-admissible reservation and uncertainty before contacting
the runtime. Relevant work mutations invalidate reservations as well as admitted
assignments. Binding checks the exact reserved snapshot and policy, so a stale
response cannot restore authorization. Unknown outcomes remain barriers after
revocation. An uncertain approval or follow-up response also revokes new work
admission. Independently, STOP may address only the adapter's known thread/turn
on its owned connection. Confirmed physical connection closure is recorded
separately from task outcome; unknown, stopped and revoked records never become
delivered review candidates merely because cleanup succeeded. Follow-up reserves
the operation before awaited readiness, rejects concurrent follow-up/close and
rechecks admission after readiness returns.

Existing project settings provide Update execution hook and Remove execution
hook actions. They hold the exact registered bookmark/root, recheck registration
before writes and record owner intent/completion through the app store. Updates
replace only a verified unchanged RR-owned definition and preserve unrelated
configuration and owner removal. Removal disables policy before configuration
edits, refuses unresolved live/unknown workers, records before/intended digests,
and removes only the unchanged owned definition using its existing JSON or inline
storage. Conflicts retain owner edits and the disabled policy. No shadow hook file,
file deletion, automatic re-enable, installer authority expansion or agent mutation
endpoint is added. Removal verifies the current signed app/handler without requiring
the plugin to be reinstalled after an explicit plugin removal.

The settings mockup was inspected for this presentation change. Running visual,
responsive and accessibility comparison and independent UX/QA remain open; source
inspection does not establish them. Most hook/producer/adapter regressions preceded
their bounded corrections, while command-route pause/deadline and owner-wrapper
tests followed source; no initial native red run is claimed. Remaining owned profile/
worktree lifecycle, explicit owner recovery, actual production sandbox/worker
boundaries and coordinated release identity remain required future slices.

#### Owned resource retirement and explicit owner restoration checkpoint

Main/BuildAgent committed the prior corrections as
`c1968a4dd99ad27f772fd9fd238abb325c74c350` after the app build, all 34 focused tests,
documentation/index and diff checks passed. The independent R1–R4 correction review
has no remaining Required findings and is terminal for that validation. Its new
hook-source review is separate and pending; neither establishes runtime UI or the
production sandbox boundary. Main/BuildAgent checkpoint 13 passed the next lifecycle
candidate's app build and all 50 focused tests: setup 13, producer 7, profile 2,
worktree 3, assignment 5, adapter 12, lifecycle 4 and execution routes 4. Documentation/
index and diff checks passed; BuildAgent regenerated only the task-brief index.
Product source remains frozen for the fresh independent cleanup review through RO04
and Main's scoped commit route. These direct results cover selected native behaviors
and do not establish production permission boundaries, running UI or Outcome 3 acceptance.

Existing settings allow the owner to select an exact current assignment and explicitly
retire its resources to allow replacement. The app holds the registered root bookmark,
rechecks registration/root and records intent/completion. Retirement requires confirmed
runtime closure or a never-launched assignment; an uncertain launch without closure
proof remains blocked. It records an exact request identity and prior state before
external effects. It refuses referenced candidates and prunes only the exact clean
owned checkout after branch/common-Git/root verification. Dirty and untracked data
remain untouched. libgit2 retains the branch and committed history; no branch deletion,
history rewrite or generic filesystem removal is introduced. Known already-pruned
worktrees can read back as absent only when both lookup and checkout agree.

New preparation pins the finite profile definition before configuration. Retirement
removes only a semantically identical owned profile, honoring prior removal and
preserving every unrelated profile through a version-checked replacement/readback of
the existing permissions map. Legacy assignments without a definition use the current
finite derived definition and refuse drift. Worktree removal precedes profile edits,
so dirty checkout refusal changes no profile. Protected receipts record successful
steps; an edited profile leaves a pending exact-request retry without repeating the
confirmed worktree removal. These external effects and receipts are not atomic; no
automatic repair or overwrite is claimed.

Only completed owner retirement marks the old assignment superseded and permits
another request to prepare replacement work. It retains the prior stopped/revoked/
unknown state in its receipt and preserves the unknown-outcome flag. It does not
complete or accept the task, authorize an old turn, or skip new current-work checks.
An assignment under retirement cannot serve as a new review/correction baseline.

The owner may separately choose Resume project workflow after verified removal.
Restoration accepts only the unchanged removal result or its exact pending restoration
intent, preserves conflicts, and holds policy disabled until exact hook readiness/trust
readback. Onboarding and update retries cannot resume it. Before enabling policy it
revokes any remaining authorized/preparing records; stopped and unknown records remain
blocked. This action restores the project workflow and never launches a worker. The
existing settings sheet scrolls and retains accessible action/result identifiers;
actual responsive and visual QA remain unverified. Handler identity validation has
an explicit async protocol implementation; no default-overload dispatch is assumed.

Optional definition/retirement fields retain legacy decoding and introduce no automatic
existing-worktree migration. Lifecycle tests preceded core implementation; expanded
migration/owner-restoration tests followed source, with no initial native red run
claimed. Actual signed-app API/bookmark access, ordinary-worker authority/history
boundaries, running UI QA and coordinated release identity remain open for acceptance.
Registration/root replacement or re-add recovery is also unresolved. This bounded
same-registration lifecycle refuses stale identities; it does not silently rebind
old policy/assignment authority to a new registration or root.

#### Required hook mutation-boundary correction

Independent hook reviewer `01a0ad4c-9745-70d2-9366-153d4d6500c6` found a Required
P1 on `c1968a4`: the exact owner registration check preceded awaited configuration/
trust reads, allowing stale trust or inline-hook edits before completion detected
the change. The bounded correction passes the current registration/root validator
and pinned protected policy through the configuration client. Inline hook edits,
project trust and exact hook-hash trust writes revalidate after their reads and any
connection initialization, immediately before dispatch. Readback and installed/
removal receipts revalidate again. Concurrent disablement or registration changes
therefore produce conflict/stale recovery rather than a ready receipt. Already
dispatched external writes cannot be made atomic with SQLite; this does not claim
rollback of in-flight RPC effects or authorize replay after uncertain results.

Three regressions change or revoke registration during suspended trust discovery,
inline removal and readiness readback. They precede the bounded core correction;
no native red run is claimed. Main/BuildAgent checkpoint 14 passed the app build,
all 23 selected tests and documentation/diff checks; native processes exited. The
same hook reviewer found no remaining Required or Optional issues, terminal for
that correction. Protocol witness and
read-only producer call changes are signature adaptations only. Cleanup/retirement
implementation, UI and its separate independent review remain frozen. R1–R4 are
closed and are not reopened. Main owns affected native checks, scoped commit and
the same hook review correction route. Runtime boundaries/UI and Outcome 3 acceptance
remain open; this source-only correction performs no live configuration operation.

#### Required ignored-content and connection-close corrections

Cleanup reviewer `01a0ad5f-6db0-7ed0-bde6-0f274bb35353` identified Required P1
ignored owner files being omitted by default status checks before prune, and P2
retirement completing before configuration connection closure. Retirement now
requests ignored files and ignored-directory recursion explicitly, in addition to
its exact branch/common-Git/root and ordinary cleanliness checks. A native regression
places content in an ignored `.env`, attempts prune and reads back the unchanged
content, checkout and committed head. Creation/candidate cleanliness semantics are
otherwise preserved.

Resource steps return a pending receipt. Before profile RPCs, protected state marks
configuration closure outstanding for that exact retirement request; failure keeps
the receipt incomplete/visible and replacement blocked. Only confirmed closure and
fresh owner/root/policy checks permit the superseded/completed transition. AppModel
retains one lifecycle/client for owner resource operations, preserving its original
connection. Operations serialize that shared connection. Only an explicit matching
request may retry closure of the held original connection; unrelated requests do
not close it. The client clears its cleanup failure only after successful close.
Hook setup/producer close behavior is unchanged and cannot automatically invoke
this owner recovery operation.

An optional outstanding-close marker preserves legacy receipt decoding. A new client
without the original handle refuses to complete an outstanding receipt, including
after app lifetime loss; no durable process-exit proof is invented. Such lost-handle
recovery remains a named limitation requiring separately supported resolution.
Regression coverage checks visible incomplete state, blocked replacement, fresh-client
refusal, wrong-request refusal and explicit successful retry on the same connection,
without repeating resource removals. These regressions precede the fixes; no native
red run or current passing result is claimed. Source/docs are frozen for Main's
affected native checks, scoped commit and the same cleanup review correction route.
Hook P1 and R1–R4 remain closed. No live configuration/data/install action or full
Outcome 3 acceptance is claimed.

Main/BuildAgent checkpoint 15 passed the app build, 16 of 17 selected tests and
documentation/diff checks; native processes exited. All four native worktree cases,
including ignored-content preservation, and all five assignment cases passed.
Seven of eight producer cases passed. The sole failed close-retry case counted
two closes instead of one before retry and three instead of two afterward. Its
producer and retirement actor shared one configuration fixture; rejected producer
preparation invokes finish, adding the unrelated close to that fixture. Production
`assignments` and `resources` factories construct separate clients, with AppModel
retaining the resource client. The bounded correction separates fixture clients,
keeps the original close-count/same-identity expectations and verifies typed
replacement conflict plus the producer's own finish. No production source changed.
Main/BuildAgent's fixture-corrected checkpoint 15 passed all eight producer tests
and documentation/diff checks. Prior app build, worktree 4 and assignment 5 passes
remain valid and terminal unless a concrete defect appears. No production source
changed for the fixture correction. The cleanup review gate is cleared; reviewer
`01a0ad5f-6db0-7ed0-bde6-0f274bb35353` returned PASS with no remaining Required
or Optional findings in either correction. App build, all 17 affected tests after
fixture correction and documentation/diff checks passed; validation is terminal.
The candidate is ready for Main→BuildAgent's scoped local commit, with product source
frozen and no commit yet claimed. Runtime/UI acceptance, registration/root replacement
and re-add recovery, and application catalog acceptance remain open. Outcome 3 is
not complete; this result update performs no product or live configuration changes.

## Current binding and re-add recovery slice

Main confirmed scoped commit `f0866b7` (parent `c1968a4`) after terminal cleanup
checks/review and released the next unresolved lifecycle slice to the same worker.
The following current source contract supersedes the lost-handle limitation above;
native checks passed as recorded below; fresh independent review and acceptance remain pending.

Existing onboarding and owner Update/Resume actions verify the application's exact
current registration, primary bookmark, repository context and protected policy at
mutation boundaries. A generation advance or primary-root change replaces policy
binding while revoking old authorized/preparing leases. Original stopped/unknown
outcomes and resources stay unchanged. `bindingRecoveryPending` blocks preparation,
final admission and hook/worker admission until current hook trust/readiness and
owner-context readback complete. Explicit disablement survives binding changes;
only existing explicit Resume can restore it. Generation rollback and changed
registration identity cannot replace authority.

A relocated root receives fresh local hook intent/trust. When it contains a carried
hook, the protected original installed receipt permits only the exact unchanged
owned command/group; absence permits fresh registration in the new root. Modified
definitions conflict and unrelated groups remain preserved. No old folder write or
trust grant is inferred from the new bookmark.

Archive/removal disables protected policy before the application SQL commit. Re-add
creates new project/registration identities; onboarding may hand off an unchanged
owned hook only from protected policy whose exact historical registration is proven
removed and inactive by the application, rechecked before every write. Protected
`previousProjectIDs` retain the predecessor chain and owner cleanup visibility.
Preparation blocks unresolved previous runtimes/outcomes across bindings; ordinary
workers gain no sibling authority from that app-only inventory.

Settings inventory retains earlier generations/predecessors. Retirement remains
exact-snapshot/request based and does not advance an old lease. If root relocation
removed old folder access, the existing owner retirement action requests the exact
original folder through the existing picker. Its one-off security-scoped bookmark
is held alongside current project access throughout cleanup; cancellation/wrong
folder/stale current context preserves resources. Current root binding stays intact.
Only pinned original profiles and exact owned clean worktrees are removed; dirty,
ignored, modified and referenced resources remain protected.

Loss of the original configuration connection handle never proves its closure.
The explicit matching owner retirement retry may reconcile only an exact owned
profile with versioned write/readback through a new configuration helper, then
confirm that new helper's closure. With old worker closure and resource cleanup
confirmed, `replacementAllowed` permits a fresh independently admitted assignment.
Original configuration closure remains unknown, retirement remains incomplete,
and original stopped/unknown state/outcome stay recorded. New helper closure never
clears the original outstanding marker. No unknown old work is redispatched.

Optional fields preserve version-one decoding. Focused tests cover generation/root
replacement, carried-hook conflicts, disablement/rollback, pending readback,
application removal/re-add, predecessor isolation/cleanup, exact old-root grants,
lost-handle safe replacement and profile conflicts. Native results are recorded below;
no runtime/UI acceptance is claimed. Main→BuildAgent owns direct checks/Git;
Main→RO04 owns fresh architecture/security/code review. UI/QA, actual production
permission/bookmark boundaries, coordinated package identity and application catalog
acceptance remain open. This source work performs no live bookmark/configuration,
app/SQLite/catalog-acceptance, installation, release or external mutation.

Main/BuildAgent checkpoint 16 passed pre-attempt documentation/diff checks, then
failed compilation because the handle-loss validator captured a nonescaping
`beforeWrite` parameter. Zero tests ran; the native process exited. Main released
only the minimal escaping callback declaration along the retirement call chain,
preserving validation semantics. The previously identified test-only JSON formatting
fixture correction is included in the corrected checkpoint 16: Main/BuildAgent
passed the app build and all 51 selected tests (setup 22, producer 13, execution
onboarding 2, lifecycle 5, admission 1, hook 3, assignment 5), plus documentation/index
and diff checks. BuildAgent made no edits. Product source remains frozen for fresh
independent architecture/security/code review through Main→RO04. No new commit,
independent-review pass or complete acceptance is claimed. Runtime/UI, production
permission/bookmark boundaries, portability, package identity and live catalog
acceptance remain open. This result update changes documentation only.

The fresh reviewer `01a0ad8a` subsequently found one Required P2, with no other
Required/Optional findings: disabled predecessor policy retained its latest binding,
so historical assignment generation/root equality prevented cleanup after generation
and root changes followed by removal/re-add. Main released only that correction.
Retirement now identifies the retained project incarnation by exact project and
registration IDs and a nonfuture historical generation. The exact stored assignment,
owner-granted original folder, recorded worktree and pinned profile still define
resource ownership; latest policy binding is never substituted into that record.
Both current-owner policy and resource-project policy are pinned at mutation
boundaries; a predecessor must remain disabled and linked to the current owner.
Historical cleanup does not restore an old lease or rewrite its original outcome.

The combined regression exercises generation and root replacement, disabled removal
state, native re-add hook handoff and historical retirement. It checks missing old-root
grant and unclosed-worker refusal before successful exact cleanup, preserved original
unknown outcome and unchanged current/predecessor policy bindings. The test preceded
the bounded core fix; no native red run is claimed. Main/BuildAgent checkpoint 17
passed the app build, all 14 producer tests and documentation/index/diff checks.
The same reviewer cleared P2 with no remaining Required or Optional findings;
that validation is terminal. Prior 51-case evidence and other terminal reviews
remain valid for unchanged behavior. Main subsequently confirmed the scoped local
commit `58d86bf05dac2456f7e52b0b325964b1fbdc0d13`. Runtime/UI, actual production
boundaries, portability and application catalog acceptance remain open; full Outcome 3
is incomplete. No live mutation or worker native command/Git operation is claimed.

## Current 0.1.19 source package preparation

Main released the same worker from `58d86bf` for the remaining bounded source package
preparation and selected exact version 0.1.19 after BuildAgent confirmed v0.1.19 is
absent locally. This is local availability only. The app's two marketing-version
settings and the existing single plugin manifest align; published 0.1.18 recognition
remains immutable. The normalized digest includes the shipping manifest, fixed two-server
MCP configuration and both existing skills. No second plugin, schema or helper-authority
expansion is included. BuildAgent's unchanged native
`PluginDigester.marketplacePackage(at:)` returned version 0.1.19 and normalized digest
`6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35` (exit 0)
against the frozen assigned source package. The exact standard-1 capability pair is
registered; tests compare app/plugin version, core/helper digest agreement and current
recognition and preserve exact published 0.1.18 recognition while rejecting crossed
pairs. Tests preceded recognition changes; no native red run is claimed. Package
bytes remain unchanged. Main/BuildAgent checkpoint 18 passed the app build and all
36 affected tests: lifecycle acceptance 26, package 2, compatibility 6 and skill
contract 2. Packaging-script `bash -n`, documentation and diff checks passed.
The test-built coordinator passed strict signature and hardened-runtime checks,
but identifier `ReleaseRadarCoordinator` and XCTest-injected entitlements are not
exact production identity/entitlement evidence. Neither a production defect nor
a production identity pass is inferred. Reviewer `01a0af6d` found one Required P1:
promotion verifies the prior destination as well as the new candidate, and a valid
older destination lacks the coordinator. No other Required findings remain;
published 0.1.18 recognition and guidance review are terminal. Main released only
the packaging-verifier correction described below. BuildAgent passed packaging-script
`bash -n`, documentation/diff checks and all 13 bounded verifier/promotion fixture
cases using the actual function bodies, stubbed codesign and real filesystem/plist
operations. The strict new-candidate/legacy-prior distinction is verified; these
fixtures are expressly not production signature proof. The same reviewer cleared
P1 with no remaining Required or Optional findings; correction validation is terminal.
Main confirmed the scoped package commit
`05f99ef26cf479221b289d03275148a0194b973f` on the same assigned branch/worktree. Temporary `build/promotion-p1-fixtures` remains retained and excluded;
cleanup is not authorized. Shipping package bytes
and the exact registered digest remain unchanged; checkpoint 18's unchanged
app/package checks remain terminal. No native red run is claimed.
The source candidate is not a package, installation or complete runtime acceptance
claim. Catalog identity/lifecycle and collection purpose remain unchanged.

The existing shipping skill now gives the deterministic route from exact current
registration/accepted catalog/governed work through preparation and native worker
start/status, independent interruption, close and existing Settings/Manage Project
recovery controls. Onboarding consent carries the already authorized scoped work;
no per-worker consent or producer/profile choice is added. Genuine runtime approval
requests retain their exact identity and require scoped owner authorization. Main's
management association remains operational, not a cryptographic Main identity.
Ordinary-worker history/sibling exclusions and deliberate authorized Main retrieval
remain required; source guidance alone does not prove runtime enforcement.

The existing packaging verification requires a regular executable at
`Contents/Helpers/ReleaseRadarCoordinator`, rejects a symlinked helper/directory,
verifies its approved signing authority/team and exact
`com.rekonlabs.ReleaseRadarCoordinator` identifier, hardened runtime and exact approved
application-group-only entitlement structure for every 0.1.19 candidate. Verification
defaults to candidate role and requires exact version 0.1.19; promotion's initial
and final candidate checks use that strict default. Only the existing prior-destination
check before moving the old bundle passes an explicit prior-destination role.
Supported older destination versions 0.1.7–0.1.18 may lack a coordinator while retaining
all existing app/bridge/deep/signature/runtime/entitlement verification. Prior 0.1.19
requires the coordinator, and a coordinator present in any older destination must
pass the same strict checks. Unknown prior versions/roles are refused; there is no
generic legacy bypass. Existing release modes and rollback identity checks remain
unchanged. No packaging script is run by this source worker and no real install is
included in the correction checks.

Recovery remains bounded by existing controls. Known held worker connections support
interrupt/close; STOP is not completion and unknown outcomes do not authorize redispatch.
Configuration-handle safe replacement requires old worker closure and exact owned
resource cleanup and does not establish closure of the original configuration connection.
Abrupt coordinator process loss without the worker handle or proof of exit leaves an
unresolved barrier. No universal reconnect/recoverability claim, process registry or new
execution engine is introduced. Runtime/UI comparison, production sandbox/bookmark and
executable identity checks, portability and application catalog acceptance remain open.

## Production coordinator signing correction — checkpoint 19

Main/BuildAgent ran the reviewed stage-release-no-launch path from committed
`05f99ef26cf479221b289d03275148a0194b973f`. The Release build succeeded, but the
stage gate rejected actual signing identifier `ReleaseRadarCoordinator`; the approved
identifier remains `com.rekonlabs.ReleaseRadarCoordinator`. Strict app deep/helper
signatures, hardened runtime and exact group-only entitlements passed without
XCTest-injected extras; app version was 0.1.19. This establishes the production
signing-identifier defect, distinct from checkpoint 18's qualified test-built evidence.
Native processes exited; no staging promotion, installation or launch occurred.
Temporary log `build/production-stage-019-19.log` remains retained and excluded.

The coordinator target already declares the required product bundle identifier but
lacked the generated, embedded Info.plist settings used by existing command-line
helpers. Main released only the source correction: its Debug/Release configurations
now set `GENERATE_INFOPLIST_FILE=YES` and `CREATE_INFOPLIST_SECTION_IN_BINARY=YES`,
providing generated bundle identity in the executable for normal build/signing.
The strict verifier is unchanged; no manual re-signing workaround, signing-authority
change, entitlement or helper-authority expansion is included.

Corrected checkpoint 19's `stage-release-no-launch` exited 0. Release build, strict
app/coordinator signing, copy and promotion passed. Coordinator signing identifier is
exactly `com.rekonlabs.ReleaseRadarCoordinator`; hardened runtime passed and its sole
entitlement is application-groups `[2UA854NLX4.com.rekonlabs.ReleaseRadar]`. Both built
and staged plugin version 0.1.19 and normalized digest
`6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35` match the
registered pair. Reviewer `01a0af8d` cleared the bounded signing correction over
`05f99ef` with no Required or Optional findings; checks/review are terminal. Temporary
log `build/production-stage-019-19-corrected.log` remains retained and excluded.
Source/docs are frozen for Main→BuildAgent documentation/diff checks and scoped commit.
No new commit, installation, launch, live mutation or overall acceptance is claimed.
Shipping package bytes and registered normalized digest remain unchanged;
prior package guidance/version/assertion checks and promotion P1 review remain
terminal. Production packaging completion, installation, runtime/UI, portability
and live catalog acceptance remain open. The source worker performed no native,
build, Git or live action. Catalog identity/lifecycle and collection purpose remain
unchanged; no new durable artifact is added.

## Pre-provisioning MCP discovery correction

Main's fresh-task acceptance exposes assignment preparation but no worker MCP tools;
Codex logs initialization connection closed. BuildAgent's single installed initialization
exchange exited 1 with empty stdout and execution-setup-unavailable stderr. The source
opened ProjectExecutionFileStore.applicationRoot()/create:false storage before responding
to initialize. The native management server consequently could not advertise its tools
until project setup had already provisioned storage. This is an observed runtime defect,
distinct from the earlier stale task inventory; no complete actual-flow acceptance follows.

Main released the minimal correction from committed baseline
`338ca6e1954aa9f9a0e9bd7deffa429036b6e191`, same branch/worktree. The existing MCP service
now defers adapter/store construction until a validated worker-tool call. Its actor
serializes and caches the connection's adapter without blocking independent status/STOP
when a worker call awaits transport. Initialization/ping/tools-list do not resolve, open
or create execution storage; disconnect does nothing if no adapter opened. Missing or
invalid storage fails actual worker operations closed using the unchanged create:false
constructor. No authority, root, assignment, profile, hook/trust or readiness gate is
weakened, and discovery does not imply readiness. WorkerAdapter operations and hook mode
remain unchanged. The existing service definition moved into WorkerAdapter.swift, already
compiled by the test target, so direct regressions exercise its actual dispatch code.
No new engine, harness, source file, profile, configuration workaround or helper authority
is added; shipping plugin bytes and normalized digest remain unchanged.

Two WorkerAdapterTests regressions precede the correction: absent/invalid execution
storage permits initialization and exact six-tool discovery while all worker calls fail
closed and create nothing; verified start/status/disconnect retains one adapter, one
launch and physical close. No native red run is claimed. Main/BuildAgent checkpoint 21
passed app/coordinator build, all 14 WorkerAdapter tests and documentation/index/diff
checks. Actual Debug initialization/tool listing returned all six tools, with EOF
exit 0 and empty stderr. Production checkpoint 22 passed stage-release-no-launch strict
signing, copy and promotion; coordinator identifier is exactly
`com.rekonlabs.ReleaseRadarCoordinator`, hardened runtime passed and its sole entitlement
is application-groups `[2UA854NLX4.com.rekonlabs.ReleaseRadar]`. Staged Release
initialization IDs 1/2 and six-tool listing passed, with EOF exit 0 and empty stderr.
Plugin version 0.1.19 and normalized digest
`6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35` remain unchanged.
Temporary `build/coordinator-startup-21.log`, associated `.xcresult` and
`build/coordinator-startup-release-22.log` remain retained/excluded. Reviewer `01a0afd4`
cleared the complete six-file correction over `338ca6e` with no Required or Optional
findings, confirming no-store discovery, lazy create:false worker gates, atomic cache,
independent STOP during awaited calls and cached EOF physical cleanup. Native checkpoints
21/22 remain attributed; checks/review are terminal. Later factual pass annotations
were not independently reviewed; they add no design change and need no additional
review. The result is
preserved for Main's reviewer archive; reviewer `01a0afd4` is now archived. Main reported
startup-fix commit `74d227ea3b2d811cd4029e5bf9da010dbfc9d86b`. BuildAgent installed
corrected 0.1.19 without rebuilding and launched PID 71305. Installed native
initialization/listing returned all six tools with EOF exit 0; package bytes/digest
remain unchanged. Operator `01a0afcc` fresh-turn metadata exposes preparation and all
six coordinator worker functions, with no loading error and zero operational calls.
The loading defect is resolved; actual onboarding/worker isolation/STOP/recovery remain
untested. Main UI is paused pending the owner's control response after concurrent-change
click rejections; operator remains on hold, no permission change. This documentation-only
checkpoint claims no overall acceptance and keeps source/tests frozen. This worker
performs no product edit, retry,
native/build/Git/live action or cleanup. Prior unrelated checks/reviews remain terminal. Actual-flow,
isolation/STOP/recovery, UI, portability and live catalog acceptance remain open. Existing
temporary/reference/distribution files remain retained and excluded, without cleanup.
Catalog identity/lifecycle and collection purpose remain unchanged; no new durable artifact.

## Saved execution setup feedback correction

The owner reports that Resume Execution Setup appears to do nothing in the saved
initialization flow. Main released bounded source inspection/correction from reported
current revision `ec860984`, same branch/worktree. The button calls initializeProject;
its saved preview supplies the same registration to prepare. Prepare/finish retain
their readiness and security gates, and both typed setup and generic failures are caught.
No silent saved-preview return or concrete native failure was established. The confirmed
UI defect is invisible progress and stale saved status, with eventual status/error below
the long Codex prompt. That is not evidence a live retry succeeded or failed.

Main explicitly released the minimum feedback correction. The existing status/failure
view is reused locally beside initial confirmation and saved setup controls, with an
accessible progress indicator during preparation and no duplicate global feedback.
Saved Resume/Finish controls and their feedback precede the prompt. Each prepare attempt
clears stale status; success reports completed checks and tells the owner that Finish
Initialization verifies before opening. Generic failure clears the in-progress message.
Core preparation/finish, identity, consent, security and trust gates remain unchanged.
The approved `docs/design/mockups/onboarding_state.png` reference was inspected: local
visible recovery feedback follows its no-silent-recovery intent while retaining existing
components and styles. There is no architectural deviation or shared-library change.

The existing failed-setup regression now repeats preparation using the still-failing
saved preview, checks propagated detail and unchanged pending registration, and retains
Finish refusal until recovery. This precedes UI edits; no native red run is claimed.
Main/BuildAgent checkpoint 24 reports individual passes for all 38 focused cases,
app compilation and documentation/index/diff checks. xcodebuild PID 77788 hung for
over ten minutes in XCTHRuntimeProfileGenerationCoordinator runtime-profile directory
enumeration. The result bundle is unfinalized, with no TEST SUCCEEDED. BuildAgent
terminated the verified runner with SIGTERM; it exited 143 during runtime-profile
finalization. Logs/results are preserved. Overall command success is not claimed. Independent source
reviewer `01a0b001-e970` cleared the five-file candidate with no Required defects, finding
inline feedback, stale-status clearing, retry, success and error behavior consistent.
Source review is complete/archived through Main. Source/tests stay frozen; focused cases
and source review do not establish runtime UI correctness. Actual pending/success/error feedback,
accessibility and relevant-width visual comparison/QA remain pending through Main;
core tests do not establish visual correctness and no UI harness is introduced.
Main subsequently reports the owner completed initial test-project onboarding. Full
runtime feedback verification, checkpoint 24 overall build pass and complete Outcome 3
acceptance are not inferred. The source
worker performs no native/build/Git/live action. Shipping package bytes/digest,
catalog identity/lifecycle and collection purpose remain unchanged; no new durable
artifact, governing instruction or accepted ADR change. Existing temporary/reference/
distribution material remains preserved, without cleanup. Prior unrelated validation
remains terminal.

### September 17 macOS documentation root-alias correction

The next actual blocker is documentation preview on the registered `/var` root.
Main/BuildAgent checkpoint 26 passed full catalog/file/index validation on the same
fixture through `/private/var`; checkpoint 28 used the same installed helper through
`/var` and exited 1 with `unsafeFileType`. The reader rejected the symbolic-link ancestor
before catalog loading. Inventory maps that rejection to `unsafePath` and unavailable
guidance; missing guidance is not a documentation-preview prerequisite.

[Apple's NSURL documentation](https://developer.apple.com/documentation/foundation/nsurl/resolvingsymlinksinpath?changes=_1_8)
states that symlink resolution can remove the `/private` prefix when the shorter path
exists. Current onboarding, bookmark and authorized-project normalization uses this
Foundation representation. A sandbox-specific failure is not required to explain it.
Preserve the saved/request root identity rather than changing identities across roots,
bindings, policies and assignments.

Main released only a reader traversal correction for the actual macOS `/var` alias:
require a root-owned symlink in a privileged non-writable parent, its exact `private/var`
target and unchanged link metadata during inspection. Traverse `private/var` and every
remaining component with existing no-follow metadata/open checks. Stable reopening
repeats the alias verification and existing root-descriptor identity checks. Arbitrary
user links, root links and document links remain rejected; there is no general resolver,
identity migration, permission relaxation or accepted-ADR change.

Checkpoint 27's attempted XCTest fixture assumed `/private/var` although the sandboxed
host uses container temporary storage, so it supplied no causal proof and the test edit
was removed. The actual helper pair supplies the regression; no fixture system or new
write permission is introduced. Main/BuildAgent checkpoint 29 compiled the reader and
reports 65 passing cases including containment/replacement and managed setup/security-
scope/generation checks. Seven existing preview fixtures fail creating `/Users/Shared`
directories before reader execution (permission denied); the 72-case command exited 65,
so overall suite success is not claimed. Two live-picker methods were explicitly excluded;
there is no permission workaround or unrelated fixture repair. The newly built helper
passes full validation/index checking through both `/var` and `/private/var`, directly
confirming corrected alias behavior. Documentation/index and scoped diff checks passed. Independent Security/Privacy
reviewer `01a0b049` cleared the exact reader patch with no Required or Optional findings.
Main checkpoint 31 confirms installed `b6dbefb7` fixed the actual preview: the same
project's documentation check/plugin capability passed and preview returned repository
`6fefe2e8-3a09-4fad-88cd-245061a67b65`, catalog v1 and digest
`a09f5b2c8be9f2f1161ca56648600181648f579cbde97dd8567de91696186c50`.
The subsequent explicit binding was not committed with `documentation.guidanceUnavailable`.
This is the separate guidance gate: current binding requires managed v2/v3, while the
actual bootstrap and shipping skill stage v1 then direct binding before audited upgrade.

### September 17 staging-guidance binding sequence correction

Main selected v1 bootstrap → explicit owner binding → separately authorized audited
guidance upgrade. The owning mutable managed-documentation specification now permits
only the initial binding command to additionally accept the exact shipped staging v1
block with a fully validated catalog and exact target. Exact block inspection preserves
unrelated surrounding instructions and rejects missing, modified, duplicate or malformed
staging. Normal root/bookmark/registration/conflict checks, transaction revalidation,
audit, replay and rollback remain. Global managed mode/snapshot gates and every other
operation remain unchanged; v1 binding alone does not enable managed evidence, import
or execution authority. The existing valid-staged-catalog update prompt already routes
to the separately authorized audited guidance upgrade, so no UI/package/copy change
or fixture preactivation is required. Accepted ADRs and governing instructions remain.

The six-file scope is the existing dispatcher/tests, managed-documentation contract
and Outcome 3 ledger/brief/design. Existing container-writable fixtures cover registered
owner preview/bind, preserved legacy state and closed managed operations, separate
audited upgrade, staging/target rejection and rollback/replay. Main/BuildAgent checkpoint
32 compiled/executed the owner-sequence test and reached the exact
`command(documentation.guidanceUnavailable)` failure before dispatcher edits (one
unexpected failure, terminal exit 65). The bind-only correction now uses the existing
exact staging-block inspector and full catalog/target checks; global managed
snapshot/mode gates remain unchanged. Checkpoint 33 compiled the app and passed 11 of
12 selected cases: both new rejection/target/rollback/replay cases and nine existing
safeguards. Documentation/index/diff checks passed. Initial owner binding succeeds;
the lifecycle test then incorrectly reused its legacy dispatcher after seeding a
completed registration. Existing identity gates rejected those calls. Only the fixture
now uses the registered project and matching request tuple; production is unchanged.
Checkpoint 34 passed the corrected lifecycle test (one test, zero failures, terminal
exit 0); the prior 11 passes remain valid. Documentation/index/diff checks passed.
Fresh reviewer `01a0b063-6d28` cleared the complete six-file patch with no Required or
Optional findings; that reviewer is archived after its result was preserved.
Checkpoint 36 verified installed `dce76787`, app `0.1.19`; exact package identity/
CDHash/PID are recorded in progress. Main opened the saved disposable project;
the owner added `Outcome3Acceptance`, and exact-root Local bootstrap task `01a0b081`
appended the exact staging v1 block while preserving all 332 original instruction
bytes (final 1192). Packaged checking passed with unchanged catalog bytes. The
authorized root is
`/var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/rr-outcome3-acceptance-019-3b0aa292-15a6-4de7-bd88-ae30ee890695/project`.
Main observed staged v1 in installed `dce76787`, previewed the same exact project/
root0/repository/catalog/digest and confirmed binding. The UI reports owner action
committed and audited as `9A68179F-2B10-4268-AA7C-24837A0BAD8D`. This verifies actual
bootstrap and initial binding and resolves their prior blockers. The separately
authorized handoff task `01a0b086` wrote the exact v3 span, preserving 334 outside-span
bytes, the 175-byte ledger, catalog, indexes and README; packaged checking passed.
Its single audit call returned `appUnavailable` with empty entity IDs, without success
or retry. Main's UI remains responsive and reports managed handoff incomplete v3.
BuildAgent established a registration serialization mismatch: the helper emits an
object project ID, but the unchanged `ProjectID` Codable contract requires a string.
Callback decoding fails before mutation; no permission/socket/signature failure is
established. Checkpoint 37 compiled/executed the direct callback regression before
production edits (one test, two expected assertion failures, terminal exit 65). The
helper now emits the string and the directly coupled preparation guard accepts it
with unchanged exact-key and authorization/identity checks. Obsolete objects and
extra fields remain rejected. Public arguments, permissions and other behavior
are unchanged; existing transport tests exercise real helper/callback decoding.
Checkpoint 38 passed all five targeted tests, including both new regressions,
signed-helper integration, malformed inputs, lost reply and exact replay
(`TEST SUCCEEDED`, exit 0). Documentation/index and six-file diff checks passed.
Fresh reviewer `01a0b09b-4e49` cleared the six-file patch with no Required or Optional
findings. Main transferred the owning documents to BuildAgent for scoped commit and
signed staging. The same installed `dce76787` app was reopened; installed fix and live
replay remain pending through Main.
The [original pending audit request](../delivery/task-briefs/2026-09-16-outcome3-execution-setup/brief.md#pending-disposable-handoff-audit)
is preserved once in the existing brief, for unchanged replay by the original task
only after availability is established. Audit/full acceptance remain pending;
the three-document status update is refrozen. No source/test/contract or
catalog identity/index change; the worker performs no native/Git/live/config/SQLite
operation or cleanup.


### September 17 approved selected Codex context contract

One app-owned exact existing Codex home is selected explicitly and used across setup,
verification, preparation, worker startup/follow-up and retirement. Reuse its existing
ChatGPT subscription/account through App Server. The selector grants folder access,
including authentication and history, without copying either. A protected machine-local
identity and security-scoped bookmark live outside ordinary-worker checkouts; policies
and assignments bind that identity. Prompt-supplied homes cannot override it. Hold the
grant until the connection physically closes, including failed/uncertain cleanup.
Missing, changed, moved, denied or stale context blocks further lifecycle admission;
existing Connections settings offers exact-folder reselection and actionable recovery.
Never migrate uncertain/reserved assignments or replay their starts. Old unbound
assignments remain blocked. Preserve original f481 request/state.

The macOS picker is an adapter to a separate context contract. Paths/bookmarks are
machine-local and excluded from portable project data. On another machine select its
existing authenticated context, onboard the project and regenerate only RR-owned
configuration from its local project/checkouts. Preserve unrelated configuration and
strict raw owned-profile removal. No credential/history/trust copying, global home
entitlement, installer-helper expansion, new authentication engine, API-key migration,
execution dashboard or headless server deployment is included.

Transport sets explicit validated `CODEX_HOME` and the read-only bootstrap default.
Effective config metadata may include normalized description/extends/workspace_roots;
accept only non-authorizing metadata and exact filesystem/network limits, reject
meaningful inheritance/additional roots. Worker hook matching uses setup's canonical
primary source while preserving actual linked checkout identity.

Visual reference: `mockups/settings.png`. Extend the existing Connections section with
an exact-folder selector, saved context status, explicit access explanation and recovery;
use its existing panels, responsive controls and accessibility identifiers. This is a
necessary extension because the reference predates execution-context selection.
Runtime/visual comparison and bookmark restoration remain open until the actual signed
app is exercised under Main's later live authorization. Minimum readback is
`account/read(refreshToken:false)`, `config/read`, `hooks/list` sanitized metadata then
physical close; no thread creation or reserved-assignment replay. Official
[Codex authentication](https://learn.chatgpt.com/docs/auth),
[environment](https://learn.chatgpt.com/docs/config-file/environment-variables),
[App Server](https://learn.chatgpt.com/docs/app-server) and
[Apple sandbox access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
support the candidate contract, not installed signed-child/account readiness.

The bounded source stores a selection receipt (identity, selection time, prior identity,
folder fingerprint and bookmark) in protected execution storage; only UUID bindings
enter policies/assignments. Owner selection records an application audit intent before
saving the protected receipt. No receipt includes account/token/credential content.
Same-physical-folder reselection restores access with the same identity; a different
folder gets a new identity. Existing connections compare their exact saved receipt and
retain the original grant until physical close. Stop/close remain available after loss.
Production setup opens the grant before lifecycle mutations, and account admission
uses `account/read(refreshToken:false)` requiring ChatGPT; inherited auth/state overrides
are removed only from the child environment. This does not prove the selected account
or credential backend is accessible to the signed production child.
