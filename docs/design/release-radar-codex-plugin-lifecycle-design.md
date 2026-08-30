# Release Radar Codex plugin lifecycle design

- Status: Approved
- Date: 2026-08-27
- Owner approval: Approved in the Codex delivery task on 2026-08-27

## Outcome

Release Radar ships and manages one versioned local Codex plugin named
`release-radar`. The plugin teaches Codex how to find or initialize the durable
project tracking documentation Release Radar needs and configures Codex to use
the existing Release Radar STDIO MCP server for typed delivery mutations.

The owner manages the plugin from **Settings > Connections**. Release Radar can
install, update, remove, detect modification, and explicitly reinstall its own
plugin. A clean managed installation advances automatically after a Release
Radar app update. A plugin that was never installed, was removed, or was
modified is never silently installed or overwritten.

This feature does not change the accepted runtime mutation path:

```text
Codex
  -> Release Radar plugin
  -> existing ReleaseRadarAgentTools STDIO MCP server
  -> existing signed XPC bridge
  -> Release Radar app
  -> app-owned SQLite
```

There is no HTTP server, direct SQLite access, generic command layer, periodic
reconciliation framework, or new ticket command surface.

## Plugin package

The signed Release Radar app contains the canonical local marketplace and
plugin source. The package contains only the components needed for this
integration:

```text
Release Radar marketplace
  .agents/plugins/marketplace.json
  plugins/release-radar/
    .codex-plugin/plugin.json
    .mcp.json
    skills/release-radar/SKILL.md
```

The manifest version tracks `CFBundleShortVersionString`. A deterministic
SHA-256 package digest is calculated over normalized relative paths and file
bytes. The app-bundled package is the intended source; Codex owns its installed
cache, enablement, approvals, configuration, and MCP permission state.

The corrected repository handoff ships app and manifest version `0.1.5`
together. A clean managed `0.1.4` plugin reaches it only through the existing
clean-managed launch update or existing explicit Update action; no same-version
overwrite or additional updater path is introduced.

The `.mcp.json` uses the official direct server map form, with
`"release_radar"` as the top-level machine key and `command`/`args` beneath it.
It does not use a camel-case `mcpServers` wrapper. The underscore is required
for Codex to form the callable `mcp__release_radar__...` namespace; it is not a
second plugin, marketplace listing, or user-facing alias. The skill frontmatter
description is the trigger-only sentence `Use when working in a repository
tracked by Release Radar or when the owner asks to initialize or synchronize
Release Radar tracking.`

The skill is concise and project-facing. It tells Codex to:

- require the copied prompt to name the exact Release Radar-authorized
  repository root, canonicalize that root and the current Codex task root, and
  continue only when they match exactly;
- when the exact root is missing or the task is rooted at a parent, child, or
  different directory, report the mismatch and stop before any repository
  write or Release Radar call;
- inspect the current repository instructions and Release Radar tracking
  artifacts before reporting or changing delivery state;
- when the owner asks to initialize or update tracking guidance, preserve every
  unrelated repository instruction and manage
  exact versioned Release Radar managed block in the repository-root
  `AGENTS.md`, creating the file when absent, appending when no marker exists,
  replacing only one older managed range, and stopping on malformed, duplicate,
  modified-current, or newer markers;
- refuse before writing if the root `AGENTS.md` or delivery-ledger path is a
  symlink or non-regular filesystem item;
- preserve the durable delivery ledger at `docs/delivery/progress.md`, creating
  it only when absent with the guidance version and an explicitly pending
  Release Radar audit, never inventing delivery state;
- use the plugin's typed MCP tools for consequential Release Radar state
  transitions rather than editing Release Radar's SQLite database;
- write the managed block and absent-only pending ledger first and directly read
  them back; then record the actual root `AGENTS.md` with the existing
  ticketless `release_radar_add_evidence` mutation and an evidence ID prefixed
  `release-radar-handoff:v1:`. When Release Radar reports that the exact block
  is present but this audited evidence is absent, the copied repair prompt
  authorizes the same evidence mutation without rewriting repository files.
  Never use `upsert_phase` or another delivery-state mutation merely to
  manufacture a handoff audit;
- when the app is closed or no callback is available, retain the repository
  guidance with its audit pending, tell the owner to open Release Radar, and
  retry the complete evidence request. `outcomeUnknown` likewise replays the
  complete request verbatim—including evidence ID, path, command, root, reason,
  attribution, and UUID `requestID`—through the existing idempotent receipt;
- after a successful result, replace only the pending audit value in a ledger
  created by this handoff with the returned audit-event ID and perform final
  readback. A post-audit ledger failure is repaired without another mutation;
- surface uncertainty instead of fabricating completion or acceptance.

The skill does not grant new authority to mutate project files, Release Radar
data, or external systems. Codex performs repository documentation writes only
when normal authorization and the owner request allow them. Release Radar alone
validates and persists its existing typed MCP mutations; the app and lifecycle
helper have no repository-write authority. Normal Codex authorization rules
still apply.

For every onboarded project, Release Radar uses the existing security-scoped
project bookmark to inspect only the root `AGENTS.md` and pairs that read-only
result with its existing ticketless evidence row for the exact file. **Release
Radar guidance current** requires both the exact versioned block and an
available evidence ID prefixed `release-radar-handoff:v1:`. An exact block
without that audited evidence is **Release Radar guidance handoff incomplete**
and offers the copied repair prompt; malformed guidance remains **needs
repair**. Missing, update available, and unavailable retain their existing
meanings. A symlink or non-regular root instruction path is unavailable. The
guidance version is independent of the app/plugin version.
Inspection occurs during the existing project/dashboard load path, including
the existing refresh after a successful MCP mutation. The app never writes the
repository instruction file: when owner action is needed, it copies the exact
current-task prompt, shows and embeds the exact canonical authorized root, and
Codex performs the authorized managed-block change through the installed skill
only from a task rooted there. No watcher, poller, synchronization framework,
or repository-read MCP operation is introduced.

## Existing legacy MCP entry and machine identifier

The managed plugin and marketplace keep the single canonical product identity
`release-radar`. Its bundled STDIO MCP server uses the machine identifier
`release_radar` because Codex CLI `0.149.0-alpha.4.3` accepts and lists a
hyphenated plugin server key but does not expose that server's tools to the
model. The underscore is a syntax adaptation inside the one plugin, not a
second durable product alias. Release Radar does not introduce a second plugin
or server name such as `release-radar-plugin`.

This distinction preserves the original recommendation's outcome: after the
first managed Install completes, there is one installed Release Radar plugin
and one callable bundled MCP server. The temporary coexistence of the legacy
owner-configured `release-radar` entry and bundled `release_radar` server is
limited to first-Install verification and rollback.

Some existing installations have a legacy owner-configured MCP entry with the
canonical name. Release Radar recognizes that entry only when supported
`codex mcp get release-radar --json` output has all of these semantics:

- name `release-radar`, enabled `true`, and no disabled reason;
- STDIO command
  `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`;
- no arguments, working directory, or non-empty environment.

Additional CLI JSON fields are tolerated only when they do not contradict
those required semantics. Malformed, duplicate, or contradictory values fail
closed.

An absent entry is also an allowed initial state. Any same-name entry that does
not match this contract is a conflict and is never overwritten or removed.
All changes use the supported fixed Codex CLI operations; Release Radar never
edits Codex configuration directly.

For the corrected feasibility proof, the exact legacy entry remains untouched
while the derived plugin is installed. Before installation, supported
`codex mcp get release_radar --json` must return the pinned exact-absence tuple:
exit status `1`, empty stdout, and stderr
`Error: No MCP server named 'release_radar' found.` plus one newline. Any
present, malformed, or ambiguous bundled-key state stops before mutation. A
normal fresh Codex task must then prove that the plugin supplies callable tools
through server key `release_radar`. Cleanup removes only the temporary plugin
and marketplace and verifies exact bundled-key absence plus unchanged legacy
entry and unrelated-state fingerprint. Earlier accepted live evidence already
proves exact legacy removal, pinned absence, and exact restoration through the
fixed supported CLI vectors; it is cumulative migration evidence and is not
rerun.

For the product's first managed Install, Release Radar also recognizes the
owner's troubleshooting-era direct `release_radar` entry only when it is an
enabled STDIO entry with no disabled reason, the exact packaged AgentTools
command, empty arguments, null working directory, and empty or null environment
fields. Contradictory fields fail closed. The helper classifies both this direct
entry and the legacy `release-radar` entry before any mutation, then freshly
rereads and removes that exact direct entry through the supported CLI,
then verifies the machine key is absent before installing the plugin. Any
changed or unrecognized `release_radar` entry stops before mutation. If the
attempt later fails, rollback restores the direct entry only when this operation
removed it and the key remains absent; it never overwrites changed state.

Release Radar separately records the operation-local initial `release-radar`
observation as absent or exact legacy, installs the managed plugin, and verifies
bundled server `release_radar`. An initially absent entry
proceeds directly to the final bundled-server postcondition. For an initially
exact legacy entry, Release Radar immediately reads `release-radar` again and
removes it through the Codex CLI only when that fresh observation still matches
the exact legacy contract, then verifies bundled server `release_radar` again.
An absent or changed fresh legacy result causes rollback without removal or
restoration. After an attempted removal, restoration is allowed only because
that operation may have removed the recognized entry. Only the final bundled-
server verification permits `managedInstalled`. Every failed attempt removes
only plugin/marketplace state it introduced and records no success receipt or
audit. Later Update, Reinstall, and Remove operations do not repeat this
migration, and Remove does not recreate the legacy entry. No migration flag,
second plugin/server alias, reconciliation loop, or additional XPC operation is
introduced.

## Lifecycle boundary

The sandboxed app cannot manage Codex-owned state under `~/.codex`. A separate
same-user lifecycle helper is therefore the only additional executable in this
design. It is an installation-management boundary, not an agent runtime
boundary.

The helper:

- is separately signed with Hardened Runtime and deliberately has no App
  Sandbox entitlement;
- has no app-group, Keychain, folder-bookmark, network, SQLite, or
  `ReleaseRadarCore` access;
- is registered as a same-user `SMAppService` agent;
- exposes one private authenticated XPC protocol with exactly `status`,
  `install`, `remove`, and `reinstall` operations;
- accepts no caller-selected command, path, plugin identifier, marketplace,
  environment, arguments, or source URL;
- invokes only the fixed ChatGPT-bundled Codex executable at
  `/Applications/ChatGPT.app/Contents/Resources/codex` after verifying its
  path, file mode, signature, identifier, and OpenAI team identity;
- invokes the executable directly, never through a shell or `$PATH`, with a
  fixed argument allowlist, sanitized environment, neutral working directory,
  bounded output, strict JSON parsing, and a finite timeout;
- for integrity status only, obtains the effective user's home directory with
  `getpwuid_r(geteuid())`, never `$HOME`, and combines it only with the
  CLI-validated target version to derive
  `~/.codex/plugins/cache/release-radar/release-radar/<version>`; the version is
  one path component of at most 128 ASCII characters and must be a strict
  SemVer value (`major.minor.patch` with optional valid prerelease/build
  identifiers), with no empty identifier, `/`, NUL, `.` or `..` component;
- opens each fixed directory component relative to the previously verified
  directory descriptor with no-follow semantics, and reads only
  `.codex-plugin/plugin.json`, `.mcp.json`, and
  `skills/release-radar/SKILL.md`; each file must remain the same regular file
  across the complete read before its bytes enter the deterministic digest;
- never writes Codex configuration or cache directly and never reads Codex
  configuration, another plugin, or any other cache path;
- returns normalized status or error categories and never raw command output,
  home paths, configuration contents, or credentials.

The production status path accepts no filesystem root. An internal-only
`InstalledPluginDigester(homeDirectory:version:)` seam permits derived cache
fixtures in tests; production supplies only the `getpwuid_r` home and targeted
CLI version. Descriptor-relative opening and before/after file metadata checks
reject component replacement or a file changing while read, rather than
canonicalizing an attacker-controlled path.

The XPC listener accepts only the same effective user and the signed Release
Radar application identity. The helper exposes no MCP, STDIO, URL, network, or
agent-facing endpoint. The existing bridge, MCP server, dispatcher, and SQLite
ownership remain unchanged.

## Lifecycle state

Release Radar persists only the owner's intent and the last successfully
verified lifecycle receipt in its app-owned store:

- `neverInstalled`: the owner has never installed the plugin;
- `managedInstalled`: Release Radar successfully installed or reinstalled the
  plugin and recorded its version and digest;
- `removed`: the owner explicitly removed the plugin or a previously managed
  installation is now absent;
- `attentionRequired`: observed state is modified, inconsistent, unsupported,
  or could not be verified.

The installed Codex state is observed external state, not a second authority.
The UI derives one of these presentation states:

| State | Meaning | Action hierarchy |
| --- | --- | --- |
| Checking | Status is being read | No actions |
| Not installed | No managed installation is present | Install, primary |
| Installed | Installed version and digest match the shipped package | Remove, destructive only |
| Update available | An intact recognized managed version is older | Update, primary; Remove, secondary destructive |
| Modified | Installed content differs from its last managed digest | Reinstall, primary; Remove, secondary destructive |
| Needs repair | Cache, manifest, marketplace, or receipt state is inconsistent | Reinstall, primary; Remove, secondary destructive |
| Failed | Codex/helper/status operation failed | Try Again, primary |

Installed integrity classification is exact:

- `clean(version:digest:)` requires the exact three-file inventory, three
  stable regular files, valid plugin manifest and MCP JSON, matching
  `release-radar` identity and targeted version, and the recognized digest;
- `modified(version:observedDigest:)` requires that same valid, stable shape but
  a different digest. A one-byte skill edit or a syntactically valid changed MCP
  command is Modified and its bytes are preserved;
- `needsRepair(.integrityInvalid)` covers an installed CLI target with a missing
  or extra entry, malformed manifest or MCP JSON, symlink, non-regular entry,
  rejected version/path escape, partial tree, component replacement, or content
  that changes while read. It performs no write;
- `.integrityUnknown` is reserved for an operating-system read failure or a
  missing recognized digest that prevents classification; it is presented as
  Failed and performs no write. A targeted CLI result with no installed plugin
  is `absent` and does not trigger any cache read.

Checking and every in-flight operation expose no actions. Their named status
announcements are **Checking plugin status**, **Installing plugin**, **Updating
plugin**, **Removing plugin**, **Reinstalling plugin**, and **Trying plugin
status again**. Completion announces the resulting state; a failure announces
privacy-bounded actionable failure copy.

Codex availability, plugin installation, and live Codex observation are
separate statuses. An installed plugin must never be represented as proof that
Codex is running or connected.

When a supported desktop-observation attachment is unavailable, Settings must
say that **Codex desktop observation is unavailable** (with the bounded reason
when known). It must not say **Codex unavailable** solely because no observation
attachment exists. This presentation change does not add observation transport,
polling, or a live-state claim.

## Lifecycle rules

- Initial install requires a visible owner action.
- Initial install accepts only an absent legacy `release-radar` MCP entry or the
  exact recognized legacy entry above. Bundled server `release_radar` is
  verified before and, when migration occurs, after the one-time legacy
  replacement. An unrecognized legacy entry fails closed.
- Remove requires confirmation that it removes the managed Codex plugin and
  does not remove Release Radar delivery records. Cancel is the default button,
  returns focus to Remove, and makes no helper call. A confirmed removal
  announces start and its verified result or privacy-bounded failure.
- Reinstall requires confirmation that it replaces the managed plugin with the
  shipped version and may overwrite local plugin modifications. Cancel is the
  default button, returns focus to Reinstall, and makes no helper call. A
  confirmed reinstall announces start and its verified result or
  privacy-bounded failure.
- App launch after an app update may update only an intact, recognized,
  `managedInstalled` copy.
- The signed local replacement workflow stops the running app and its two
  Release Radar-owned Service Management helpers before promoting the new
  bundle, preventing an older helper from surviving the replacement with stale
  in-memory package metadata.
- `neverInstalled`, `removed`, absent, modified, conflicted, or unknown state
  never triggers automatic installation or replacement.
- External removal of a previously managed plugin becomes `removed`; it is not
  automatically repaired.
- Modified content is preserved until the owner explicitly chooses Reinstall.
- A lifecycle receipt changes only after the helper command succeeds and a
  fresh status check proves the expected postcondition.
- A timeout, malformed result, conflicting marketplace identity, or
  contradictory postcondition becomes a visible recoverable failure. It is
  never silently retried.
- After a successful lifecycle change, Settings tells the owner to start a new
  Codex task to load the change.

## Settings experience

Add the first section under **Settings > Connections**, using the existing
`settings.png` visual language. The section is titled **Release Radar Codex
Plugin** and includes:

- explicit status text and installed/shipped version where known;
- one primary action appropriate to the current state;
- Remove as a secondary destructive action when an installation is present;
- actionable, privacy-bounded failure copy;
- disabled actions while an operation is in progress;
- accessibility labels, keyboard reachability, status announcements, and no
  color-only state communication.

No new top-level route, wizard, diff viewer, background poller, onboarding
framework, or generalized plugin manager is part of this feature.

## Feasibility gate

No product implementation begins until a scoped proof exercises the actual
bundled Codex CLI in the owner's normal macOS login. This feature exists to
manage that owner's Codex plugin, so the CLI may read and change the owner's
Codex-managed state only for the exact `release-radar` marketplace/plugin.
Every mutation uses supported fixed CLI operations. For the explicit modified
installation requirement, the helper may read only the three expected files
under the exact versioned `release-radar` installed cache root to compute its
digest; it never writes cache/configuration directly or reads unrelated Codex
state. It fails closed if the stable name, root, version, file inventory, or
digest is unrecognized.

The completed no-skill RED pressure scenario remains historical skill-authoring
evidence. It is not rerun and no additional stochastic agent evaluation is a
feasibility gate. The remaining proof is deterministic and product-shaped.

The signed bridge/temporary SQLite transition, wrong-tool no-delta case, direct
packaged AgentTools handshake, and exact owned CLI PID/PGID cancellation have
already passed and remain accepted cumulative Task 1 evidence. This correction
does not rerun them. Its only remaining live sequence is allowed MCP preflight,
exact bundled-key absence, derived plugin install while leaving the legacy
entry untouched, read-only bundled-server verification, one normal fresh-task
skill/MCP/tool-
exposure proof, plugin/marketplace cleanup, and exact unchanged initial MCP-
state verification.

The focused correction is test-first. RED changes only self-test expectations
to require exact `release_radar` keys in both canonical and derived manifests,
fixed `mcp get release_radar`, runtime expectation `release_radar`, and newly
computed canonical digests while the hyphenated fixtures/implementation remain;
the inert suite must fail those affected groups. GREEN changes only the two
fixture `.mcp.json` files and the minimum focused controller/parser/digest
expectations, then compiles with warnings as errors and passes the full inert
suite. Earlier exact fixture digests remain historical evidence for the old
bytes and must not be reported as the corrected canonical digests.

The gate must prove:

1. In the owner's current login, supported read-only CLI preflight records only
   the scoped `release-radar` plugin/marketplace state, the legacy
   `release-radar` MCP entry, exact bundled `release_radar` absence, and an
   opaque before-state for unrelated entries.
   Task 1 requires the target plugin and marketplace to be absent. The legacy
   MCP entry may be absent or may
   match the exact recognized legacy contract above; any other same-name state
   stops before mutation. The proof restores and verifies the complete allowed
   initial state after success or failure, and the opaque unrelated
   marketplace/plugin fingerprint remains unchanged. Task 1 makes no assertion
   about unobservable settings, approval state, or plugin-choice state and
   introduces no separate mechanism for them. No such content is returned,
   logged, or persisted by the helper.
2. Before lifecycle mutation, concrete RED/GREEN probe self-tests exercise
   strict JSON, timeout, output overflow, path confinement, digest, and
   executable identity inputs.
3. A fixed local marketplace can be registered or discovered without editing
   Codex configuration directly, and identity/path conflicts fail closed.
4. Clean v1 install, status, remove, reinstall, and clean v1-to-v2 update reach
   the expected postcondition.
5. The controller issued no remove during v1-to-v2 update, and supported
   before/after observations remained installed and enabled under the same
   plugin identity. This does not claim unobservable internal transient state.
   The pinned CLI exposes no supported MCP
   approval or plugin-choice state. Task 1 makes no assertion about those
   unobservable values and introduces no separate mechanism for them.
6. Repeated operations are either safely idempotent or return a normalized
   non-destructive result.
7. Exact-root read-only digesting produces the classifications above for a
   one-byte skill modification, missing or malformed manifest, syntactically
   valid changed MCP command, unexpected file, symlink, non-regular entry,
   rejected path/version, partial target, component replacement, and
   change-while-read without exposing unrelated Codex state. Derived tests
   snapshot the complete cache-shaped fixture before status and prove identical
   bytes and inventory afterward. They also prove that denied configuration and
   sibling targets are not opened and that structured output and captured logs
   contain no path.
8. After the focused key correction, recompute and record canonical v1/v2
   fixture digests. Those corrected fixtures then remain byte-unchanged during
   the live proof. Runtime-only copies may replace the fixture MCP command with
   the packaged `ReleaseRadarAgentTools` path and must use their own computed
   digest. Do not reuse the earlier digests for the hyphenated fixture bytes.
   Earlier accepted real-lifecycle evidence proved installed digest equality for
   the then-current fixtures and remains behavioral lifecycle evidence. The
   corrected proof does not rerun v1/update matrices; after installing its
   runtime-only v2 copy, the existing read-only digester proves that the actual
   installed digest equals the newly computed derived digest before the fresh
   task. Supported CLI cleanup then restores target absence.
9. The completed plan Steps 1–6 lifecycle evidence remains accepted: the official
   CLI established the absent-to-v1-to-v2-to-absent lifecycle, canonical
   digest/integrity mechanics for the historical hyphenated fixture bytes,
   conflict/repeat/partial-state behavior, and unchanged opaque unrelated-state
   fingerprint. It does not establish the newly computed underscore-fixture
   digests. The remaining proof does not rerun those matrices.
10. Build the current signed app and packaged `ReleaseRadarAgentTools`. A
    derived runtime-only v2 plugin may point `.mcp.json` at that exact packaged
    tool; canonical fixtures remain byte-unchanged. Leave the allowed initial
    legacy MCP state untouched. First require exact pinned absence for bundled
    key `release_radar`, then install the derived plugin and require
    supported `mcp get release_radar --json` to resolve bundled server
    `release_radar` to the derived tool. The accepted direct handshake for that
    packaged binary supplies protocol `2025-06-18`, server name `Release Radar`,
    server version `1`, and the transition-tool schema. One fresh Codex task
    must emit `item.started` and `item.completed` JSONL for one
    `mcp_tool_call` whose server is `release_radar`, tool is
    `release_radar_transition_ticket`, and arguments are `{}`. Completion must
    be `failed` with either a nonempty schema/argument-validation error or a
    Codex approval-policy rejection that prevents server execution, with no
    result and no Release Radar action. The structured event pair proves the
    tool is model-callable without requiring an XPC or SQLite mutation. Agent
    prose is not evidence.
    Cleanup
    removes the derived plugin/marketplace and then exactly verifies bundled
    `release_radar` absence plus the unchanged legacy entry. Missing or
    ambiguous runtime or cleanup evidence fails the gate; agent prose alone is
    not evidence.
11. Accepted cumulative evidence from the existing signed bridge acceptance
    boundary and a fresh temporary app-owned database through
    `testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp`.
    The standalone controller first requires the normal Release Radar app not
    to be running; it makes no service-status claim. Inside the Release Radar
    app-hosted acceptance test, public `SMAppService` status must be exactly
    `.notRegistered`; `.notFound`, enabled, approval-pending, or unknown state
    stops the gate. The test registers the exact bridge itself, records
    ownership only after successful registration, unregisters only when it owns
    that registration, and verifies final `.notRegistered` on every cleanup
    path. It never uses `launchctl`, `libproc`, or private service state. One real
    `release_radar_transition_ticket` request must
    travel through the packaged AgentTools, signed bridge, app callback, and
    `DeliveryStore` produced the expected ticket lane, one request receipt,
    and exactly one matching sanitized audit. The existing same-team wrong-tool
    identity was rejected before dispatch with no database delta. This evidence
    is not rerun for the canonical-name correction.
12. Accepted cumulative evidence from the focused controller's bounded
    cancellation of a directly spawned, fixed read-only Codex CLI request used
    `POSIX_SPAWN_SETPGROUP` and
    Darwin start-suspended behavior. It verifies direct-child ownership and
    `PID == PGID`, signals only that still-owned process/group, continues only
    as needed for bounded TERM-to-KILL cleanup, reaps the direct child with
    `waitpid`, and verifies PID/group absence within two seconds. No fake CLI,
    shell, retry matrix, feasibility helper,
    application harness, Mach service, generated Swift package, `launchctl` or
    `libproc` corroborator, runtime tracer, injected failure matrix, or process
    reconciliation framework was introduced. This evidence is not rerun for
    the canonical-name correction. Production lifecycle-helper
    registration, peer admission, and exhaustive cleanup tests remain Product
    Task 2 requirements.

If the real CLI cannot safely support update or marketplace confinement, or if
the exact-root read-only digest cannot safely prove integrity, implementation
stops at this gate. The result is reported as a blocker; no direct
cache/config writer or replacement framework is introduced.

## Verification and acceptance

After the feasibility gate passes, one bounded vertical implementation slice
covers the package, lifecycle core/helper, persistence, Settings UI, packaging,
and existing runtime integration. It requires independent Code Review, QA,
Architecture, Security/Privacy, TPM, and Delivery Management approval.

Acceptance evidence includes:

- test-first state and persistence coverage for every lifecycle state and
  transition;
- isolated real-CLI lifecycle results for v1 and v2 packages;
- modification preservation and explicit reinstall recovery;
- signed XPC admission, executable verification, timeout/output bounds, and
  proof the helper does not link ReleaseRadarCore or SQLite;
- strict signed-bundle/resource verification;
- Settings visual and accessibility comparison at wide and compact sizes;
- one owner-confirmed Codex task already rooted at the selected repository
  exactly matches the canonical authorized root embedded in the copied prompt
  and explicitly invokes `$release-radar:release-radar` in that same task; for
  initialization it preserves or creates the applicable repository `AGENTS.md`
  guidance and minimum pending-audit `docs/delivery/progress.md` ledger, reads
  those files back, and records the actual `AGENTS.md` with successful audited
  existing ticketless evidence. This is a
  one-shot handoff proof, not an MCP read API or synchronization framework;
- unchanged behavior for the existing runtime bridge and delivery mutations;
- final status, evidence, decisions, and residual risks in
  `docs/delivery/progress.md` only.
