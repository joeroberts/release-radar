# Outcome 3 runtime enforcement assessment

Date: September 14, 2026. **Proposed; supporting; candidate for independent
review.** This document grants no implementation or configuration authority.

## Recommendation

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
