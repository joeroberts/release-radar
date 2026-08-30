# Product Task 1: Ship the Release Radar Codex plugin lifecycle

**Status:** Planning complete; product implementation is **NO-GO** until the
separate feasibility gate in
`docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md` Task 1 passes and
Architecture, TPM, QA/Test, Security/Privacy, and Delivery Management record
independent GO decisions in `docs/delivery/progress.md`. The implementation of
this brief is Task 2 of that plan. This is the first and only product task brief
for the feature; the feasibility proof is not product implementation.

## Objective and user-visible outcome

Release Radar ships one versioned local Codex plugin with stable plugin and
marketplace identity `release-radar`. In **Settings > Connections**, the owner
can install, update, remove, detect modification, and explicitly reinstall the
plugin. A clean previously managed installation may advance automatically once
at app launch after an app update. A plugin that was never installed, was
removed or externally removed, was modified, conflicts with another
marketplace, or cannot be verified is never silently installed or overwritten.

The plugin teaches Codex to inspect repository instructions and durable Release
Radar tracking artifacts, initialize only the minimum owner-requested tracking
documentation when absent, use the existing typed Release Radar MCP tools for
consequential delivery transitions, keep repository documentation and ticket
state consistent in one owner-directed workflow, and report uncertainty rather
than inventing completion. Installing the plugin does not imply that Codex is
running, attached, or live.

## Controlling product, design, and architecture references

- `docs/design/release-radar-codex-plugin-lifecycle-design.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-002-codex-plugin-lifecycle.md`
- `docs/design/mockups/settings.png`
- `docs/delivery/progress.md`, which remains the sole status and sequencing
  ledger
- `docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md`
- Current official plugin packaging and marketplace documentation:
  `https://developers.openai.com/plugins/build/plugins`

The approved design and ADRs control whenever implementation convenience or
CLI behavior differs from an assumption in this brief. A CLI difference that
breaks the feasibility criteria blocks implementation; it does not authorize a
fallback writer.

## In scope

- One signed app resource tree containing `.agents/plugins/marketplace.json`
  and exactly one plugin at `plugins/release-radar/` with `.codex-plugin/plugin.json`,
  `.mcp.json`, and `skills/release-radar/SKILL.md`.
- Skill frontmatter whose description is the trigger-only sentence
  `Use when working in a repository tracked by Release Radar or when the owner asks to initialize or synchronize Release Radar tracking.`
  It must not summarize the workflow.
- Plugin and marketplace name `release-radar`; plugin manifest version equal to
  the app's `CFBundleShortVersionString`; a deterministic SHA-256 digest over
  the three normalized plugin-relative paths and their bytes.
- Bundled MCP machine identifier `release_radar`, so Codex can expose the
  `mcp__release_radar__...` callable namespace. This is an internal identifier
  in the one `release-radar` plugin, not a second plugin or product alias.
- A dedicated same-user `SMAppService` lifecycle helper, separately signed with
  Hardened Runtime and deliberately without App Sandbox, exposed only through
  four no-argument typed operations: `status`, `install`, `remove`, and
  `reinstall`.
- Strict helper admission, fixed Codex executable verification, fixed command
  vectors proven by the feasibility gate, a sanitized allowlist environment,
  neutral working directory, finite timeout, bounded output, strict JSON, and
  normalized privacy-bounded results.
- One first-Install migration for an exact recognized owner-configured
  `release-radar` MCP entry, using only fixed supported `codex mcp get`,
  `remove`, and rollback `add` operations. An absent entry is also accepted;
  any unrecognized same-name entry stops before mutation.
- Exact pre-install absence for bundled machine key `release_radar`, using fixed
  supported `codex mcp get release_radar --json`. Any present, malformed, or
  ambiguous bundled-key state stops before mutation.
- App-owned persistence of only owner intent and the last verified lifecycle
  receipt, plus path-free sanitized audit events for verified lifecycle state
  changes.
- Presentation states **Checking**, **Not installed**, **Installed**, **Update
  available**, **Modified**, **Needs repair**, and **Failed** as the first
  section under **Settings > Connections**.
- Visible owner actions, Remove/Reinstall confirmations, disabled controls in
  flight, actionable failures, installed/shipped versions where known, a
  post-success message to start a new Codex task, keyboard and VoiceOver access,
  and wide/compact visual comparison with `settings.png`.
- One launch-time automatic check/update attempt only for an intact recognized
  `managedInstalled` receipt whose installed digest still matches its recorded
  digest and whose shipped version is newer.
- Packaging/signing verification, isolated real-CLI lifecycle acceptance, skill
  discovery in a new Codex task, and one existing typed MCP action through the
  unchanged signed bridge into a temporary app-owned database.

## Out of scope

- HTTP, sockets, URL endpoints, a shell, `$PATH` command lookup, caller-selected
  commands/paths/identities/marketplaces/arguments/environment/source URLs, or
  a generic XPC or command surface.
- Direct writes to Codex configuration or cache, a replacement plugin manager,
  background polling, periodic reconciliation, a new top-level route, wizard,
  diff viewer, onboarding framework, or new UI mockup.
- A second MCP alias, generalized migration/reconciliation framework, persisted
  migration flag, caller-selected MCP command, or new lifecycle XPC operation.
- Changes to `ReleaseRadarAgentTools`, `ReleaseRadarBridgeAgent`,
  `ReleaseRadarTransport/BridgeXPCContracts.swift`,
  `AgentCommandDispatcher`, the MCP tool schemas, delivery commands, SQLite
  ownership, or the accepted runtime mutation path.
- App-group, Keychain, project-folder/bookmark, network, `ReleaseRadarCore`,
  SQLite, MCP, STDIO, URL, or agent-facing use by the lifecycle helper.
- Treating install status as live Codex observation, silently repairing
  modified content, automatically reinstalling absent content, or assuming
  remove-then-add is atomic.
- Developer ID distribution, notarization, a root helper, another database
  writer, or changes to unrelated settings, notifications, onboarding, or
  delivery behavior.
- Additional stochastic no-skill or forced-discrepancy evaluations. The
  completed no-skill result remains historical skill-authoring evidence; final
  skill behavior receives focused Product Task 2 acceptance coverage.

## Dependencies and release gate

1. Completed Steps 1–6 evidence remains accepted historical proof of the exact
   official CLI lifecycle, digest/integrity mechanics for the old hyphenated
   fixture bytes, conflict/repeat/partial-state behavior, and opaque unrelated-
   state preservation. It does not establish the corrected underscore-fixture
   digests. Do not rerun those matrices or recreate their verification machinery.
2. The remaining live proof runs in the owner's current login. Supported
   preflight must show the exact `release-radar` plugin and marketplace absent,
   record only an opaque unrelated-state fingerprint, and classify the
   legacy `release-radar` MCP entry as absent or the exact recognized STDIO
   entry.
   The recognized entry is enabled with no disabled reason, arguments, working
   directory, or non-empty environment and uses command
   `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`.
   Additional CLI fields are accepted only when they do not contradict these
   required semantics; malformed, duplicate, or contradictory values stop the
   gate. Before mutation, bundled `release_radar` must be exactly absent: exit
   status `1`, empty stdout, and stderr
   `Error: No MCP server named 'release_radar' found.` plus one newline. Any
   other bundled-key result stops the gate. The corrected composition proof
   leaves an exact legacy entry untouched
   while the derived plugin is installed; accepted cumulative evidence already
   proves its exact removal, pinned absence, and restoration. For the pinned
   CLI, targeted legacy absence is exactly exit status `1`, empty stdout, and stderr
   `Error: No MCP server named 'release-radar' found.` plus one newline. Every
   other exit/output combination remains an error. Cleanup removes only the
   temporary plugin/marketplace and requires exact bundled-key absence, the
   exact initial legacy MCP state, plus the identical unrelated fingerprint.
3. Build the current signed app and packaged `ReleaseRadarAgentTools`. Install
   only a derived v2 plugin whose `.mcp.json` resolves to that exact tool;
   corrected canonical fixtures remain unchanged during derivation, and the
   existing confined read-only digester must prove the actual installed digest
   equals the newly computed derived digest. Do not rerun v1/update matrices. System/
   runtime evidence from one fresh Codex task must expose installed skill
   `release-radar` and emit `item.started` plus `item.completed` JSONL for one
   `mcp_tool_call` with server `release_radar`, tool
   `release_radar_transition_ticket`, and arguments `{}`. Completion must be
   `failed` with either a nonempty schema/argument-validation error or a Codex
   approval-policy rejection that prevents server execution, with no result and
   no Release Radar action. Together with exact packaged-tool resolution and the
   accepted direct handshake's protocol `2025-06-18`, server name
   `Release Radar`, server version `1`, and tool schema, this is the machine-
   verifiable composition oracle. Agent prose alone is not evidence.
4. Accepted cumulative Task 1 evidence already proves that the standalone
   controller made no service-status claim and that the Release Radar
   app-hosted test bundle required public `SMAppService` status exactly
   `.notRegistered`, rejecting `.notFound` and every other state. The amended
   `AgentBridgeTransportAcceptanceTests.testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp`
   and a fresh temporary app-owned database proved one real
   `release_radar_transition_ticket` request through
   packaged AgentTools, the existing signed bridge, app callback, and
   `DeliveryStore`. Require the expected ticket lane, exactly one request
   receipt, exactly one matching sanitized audit, and wrong-tool rejection with
   no database delta. The test registers the bridge itself, records ownership
   only after successful registration, installs immediate ownership-guarded
   cleanup for all exit paths, unregisters only its own registration, and
   requires final `.notRegistered`. Do not use `launchctl`, `libproc`, private
   service state, or change the bridge host, dispatcher, schemas, or SQLite
   ownership. This correction does not rerun the bridge, temporary SQLite,
   wrong-tool, or direct packaged-tool handshake evidence.
5. Accepted cumulative Task 1 evidence also proves one bounded cancellation of
   a directly spawned, fixed read-only Codex CLI request with
   `POSIX_SPAWN_SETPGROUP` and Darwin start-suspended behavior. It verified
   direct-child ownership and `PID == PGID`, then used bounded
   TERM/continue/KILL as necessary, reap with `waitpid`, and require PID/group
   absence within two seconds. This correction does not rerun cancellation. No
   fake CLI, shell, broad enumeration,
   shared-path signaling, retry matrix, or orphan reconciliation is permitted.
6. No feasibility helper, harness application, Mach service, generated Swift
   source package, `launchctl`/`libproc` corroborator, runtime tracer, injected
   failure matrix, or custom process framework is part of this gate. If any
   criterion fails, record NO-GO and stop. After a passing proof, Architecture,
   TPM, QA/Test, Security/Privacy, and Delivery Management must independently
   release one fresh Product Task 2 Implementer.

## Affected subsystem and anticipated files

Create:

- `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/` and `v2/` canonical
  marketplace/plugin trees
- `script/codex-plugin-lifecycle-feasibility.swift`; it is one focused fixed
  controller and generates no Swift source or feasibility service
- `ReleaseRadar/CodexPluginMarketplace/.agents/plugins/marketplace.json`
- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json`
- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.mcp.json`
- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md`
- `ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift`
- `ReleaseRadarCore/CodexPlugin/CodexPluginLifecycleStore.swift`
- `ReleaseRadarTransport/PluginLifecycleXPCContracts.swift`
- `ReleaseRadarIntegration/CodexPluginLifecycleClient.swift`
- `ReleaseRadarPluginLifecycleHelper/main.swift`
- `ReleaseRadarPluginLifecycleHelper/ReleaseRadarPluginLifecycleHelper.entitlements`
- `ReleaseRadarPluginLifecycleHelper/com.rekonlabs.ReleaseRadar.PluginLifecycleHelper.plist`
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`
- `ReleaseRadarTests/CodexPluginLifecycleTransportTests.swift`

Modify only as needed for this slice:

- `ReleaseRadarCore/Store/StoreMigrations.swift`
- `ReleaseRadar/App/AppModel.swift`
- `ReleaseRadar/App/AppNotificationCoordinator.swift` only if the existing
  `ReleaseRadarAppServices` composition remains there
- `ReleaseRadar/App/ReleaseRadarApp.swift`
- `ReleaseRadar/Navigation/SidebarView.swift` for one launch-time coordinator
  call; no route change
- `ReleaseRadar/Notifications/SettingsModels.swift`
- `ReleaseRadar/Notifications/SettingsView.swift`
- `ReleaseRadarTests/AppRouteTests.swift`
- `ReleaseRadarTests/StoreAcceptanceTests.swift`
- `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift` only for the
  named unchanged-runtime acceptance method's ownership-safe public
  `SMAppService` preflight/register/cleanup
- `ReleaseRadar.xcodeproj/project.pbxproj`
- `ReleaseRadar.xcodeproj/xcshareddata/xcschemes/ReleaseRadar.xcscheme`

Do not modify `ReleaseRadarAgentTools/main.swift`,
`ReleaseRadarBridgeAgent/main.swift`,
`ReleaseRadarTransport/BridgeXPCContracts.swift`, or
`ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`. A need to change
one returns the task to Architecture rather than expanding the slice.

## Required interfaces and state contract

The product implementation keeps these names and meanings consistent:

```swift
public enum CodexPluginIntent: String, Codable, Sendable {
    case neverInstalled, managedInstalled, removed, attentionRequired
}

public struct CodexPluginReceipt: Equatable, Sendable {
    public let intent: CodexPluginIntent
    public let managedVersion: String?
    public let managedDigest: String?
    public let verifiedAt: Date?
}

public enum CodexPluginObservedState: Codable, Equatable, Sendable {
    case absent
    case clean(version: String, digest: String)
    case modified(version: String?, observedDigest: String?)
    case needsRepair(CodexPluginLifecycleError)
}

public enum CodexPluginPresentationState: Equatable, Sendable {
    case checking
    case notInstalled
    case installed(version: String)
    case updateAvailable(installed: String, shipped: String)
    case modified(version: String?)
    case needsRepair
    case failed(CodexPluginLifecycleError)
}

public enum CodexPluginLifecycleError: String, Codable, Equatable, Sendable {
    case codexUnavailable
    case codexUntrusted
    case unauthorizedPeer
    case marketplaceConflict
    case malformedResult
    case outputOverflow
    case timeout
    case integrityInvalid
    case integrityUnknown
    case postconditionFailed
    case partialReinstall
}

public struct CodexPluginHelperReply: Codable, Equatable, Sendable {
    public let wireVersion: Int
    public let observedState: CodexPluginObservedState?
    public let error: CodexPluginLifecycleError?
}

public protocol CodexPluginLifecycleManaging: Sendable {
    func status() async -> CodexPluginHelperReply
    func install() async -> CodexPluginHelperReply
    func remove() async -> CodexPluginHelperReply
    func reinstall() async -> CodexPluginHelperReply
}

@objc protocol ReleaseRadarPluginLifecycleXPC {
    func status(withReply reply: @escaping (Data) -> Void)
    func install(withReply reply: @escaping (Data) -> Void)
    func remove(withReply reply: @escaping (Data) -> Void)
    func reinstall(withReply reply: @escaping (Data) -> Void)
}
```

The XPC methods accept no data. `CodexPluginHelperReply` is a bounded,
versioned `Codable` envelope containing only normalized state, plugin version,
target-plugin digest where proven, and an optional normalized error enum. It
never includes CLI output, home/cache paths, configuration data, environment,
credentials, or arbitrary strings.

The deterministic digest covers, in byte-sorted POSIX relative-path order,
exactly:

```text
.codex-plugin/plugin.json
.mcp.json
skills/release-radar/SKILL.md
```

For each entry hash `UTF8(relativePath)`, one NUL byte, eight-byte big-endian
file length, and the unmodified file bytes into one SHA-256 stream. Reject
unexpected/missing files, symlinks, non-regular files, duplicate normalized
paths, path traversal, and files that change while read. Marketplace identity
and source-path agreement are checked separately.

For installed status, production obtains the effective user's home with
`getpwuid_r(geteuid())`, never `$HOME`, and combines it only with the strict
target version returned by the targeted CLI list to derive
`~/.codex/plugins/cache/release-radar/release-radar/<version>`. The version must
be one path component of at most 128 ASCII characters and strict SemVer:
three dot-separated non-negative integer core identifiers without leading
zeroes except `0`, optional dot-separated prerelease identifiers containing
only `[0-9A-Za-z-]` and no leading zero in numeric identifiers, and optional
dot-separated build identifiers containing only `[0-9A-Za-z-]`; reject empty
identifiers, `/`, NUL, `.` and `..`.

Open each fixed directory component relative to the previously verified
directory descriptor using no-follow/directory semantics. Open each allowlisted
file relative to its verified parent with no-follow semantics, compare file
device, inode, type, size, modification time, and change time before and after
the complete read, and reject any mismatch. Do not canonicalize an
attacker-controlled path. The public XPC/helper surface accepts no path. An
internal-only `InstalledPluginDigester(homeDirectory:version:)` constructor is
the derived-copy test seam; production passes only the `getpwuid_r` result and
targeted CLI version.

Classification is deterministic:

- `clean` requires the exact three-file inventory, stable regular files, valid
  plugin manifest and MCP JSON, matching `release-radar` identity/version, and
  the recognized digest;
- `modified` requires that same structurally valid shape but a different digest,
  including a one-byte skill change or a syntactically valid changed MCP
  command;
- `needsRepair(.integrityInvalid)` covers missing/extra entries, malformed
  manifest/MCP, symlinks, non-regular entries, rejected version/path escape,
  partial trees, component replacement, and change-while-read;
- `.integrityUnknown` is returned as a status error only for an OS read failure
  or unavailable recognized digest. A targeted CLI result with no installed
  plugin is `absent` and performs no cache read.

Every classification is read-only. The helper never enumerates a sibling
plugin/version and never returns, logs, or persists the home or cache root.

`.mcp.json` uses the official direct server map with `"release_radar"` as the
top-level machine key containing `command` and `args`; it must not use a camel-case
`mcpServers` wrapper. If the proven CLI requires the documented alternative,
use `mcp_servers`, not `mcpServers`.

## Data, persistence, security, and privacy implications

- Advance the store from schema version 9 to 10 with one singleton table keyed
  by `release-radar`. Store `intent`, optional verified version/digest, and
  optional verified timestamp. Do not persist CLI output, Codex paths,
  marketplace/config contents, credentials, or observed unrelated plugins.
- A verified owner Install/Update/Remove/Reinstall transaction changes the row
  and appends exactly one path-free `release-radar-owner` audit with one of:
  `Install Release Radar Codex plugin`, `Update Release Radar Codex plugin`,
  `Remove Release Radar Codex plugin`, or `Reinstall Release Radar Codex
  plugin`. A status observation may change only intent to `removed` or
  `attentionRequired`, preserve the last verified receipt fields, and append
  one sanitized observation audit only when the persisted intent actually
  changes. Failures and repeated identical observations do not create audits.
- First Install accepts bundled key `release_radar` only when absent or when it
  is the exact enabled STDIO entry with no disabled reason, the packaged
  AgentTools command, empty arguments, null working directory, and empty or null
  environment fields. Contradictory fields fail closed. Classify both direct
  and legacy entries before any mutation. Freshly reread and remove only that
  exact direct entry through the fixed supported CLI, then verify absence before
  plugin installation. Changed or unrecognized direct state fails closed.
  Rollback restores the direct entry
  only if this attempt removed it and the key remains absent. Separately record
  an operation-local legacy `release-radar` observation that is absent or exact
  recognized legacy. Install, digest, and bundled
  `release_radar` MCP postconditions pass first. An initially absent legacy
  entry proceeds directly to the final bundled-server postcondition. For an
  initially exact legacy entry, a fresh targeted `mcp get release-radar`
  immediately before removal must still match the exact legacy contract. If it
  is absent or changed/unrecognized, do not remove or restore anything; roll
  back only attempt-owned plugin/marketplace state and create no success receipt
  or audit. After this operation issues removal, a later failure may restore the
  recognized legacy entry when absent. The final `release_radar` MCP
  postcondition must pass after migration before persisting
  `managedInstalled` or its audit. Do not overwrite an unrecognized entry.
  Update, Reinstall, and Remove do not repeat either migration, and Remove does
  not recreate the legacy or direct entry.
- Change the verified receipt only after the helper reports success and a fresh
  status proves the exact expected postcondition. Reinstall remove success plus
  add failure is `needsRepair`; it must not be recorded as installed or retried
  silently.
- App-group, Keychain, bookmark/folder, network, `ReleaseRadarCore`, SQLite, MCP,
  and agent endpoints are prohibited helper uses, not authorities whose absence
  is proved by entitlements or linkage inspection. Verify the boundary through
  focused source review and targeted tests of the fixed public operations. The
  helper's only direct filesystem read is the exact three-file `release-radar`
  cache digest above. The official CLI child necessarily
  accesses Codex-owned state and is instead bounded by fixed commands, bounded
  normalized output, exact-target postconditions, and the unchanged opaque
  unrelated-state fingerprint. Binary/link and entitlement inspection is
  corroborating inventory only.
- The helper accepts only the same effective UID and signed
  `com.rekonlabs.ReleaseRadar` identity for team `2UA854NLX4`. The app pins the
  helper identifier/team. Unauthorized peers fail before an operation runs.
- Verify every path component of
  `/Applications/ChatGPT.app/Contents/Resources/codex` without following a
  symlink; require a regular executable not group/world writable; strict valid
  signature; containing app identifier `com.openai.codex`; nested CLI
  identifier `codex`; OpenAI team `2DC432GLL2`; and Hardened Runtime. Any
  mismatch is `codexUntrusted`. Require strict all-architectures verification
  of both the CLI and containing ChatGPT app, verify the signing-information
  `CS_RUNTIME` bit, and repeat verification immediately before every vector.
- Invoke the executable directly with the exact feasibility-proven fixed argv,
  never a shell or `$PATH`; construct environment values in the helper from
  same-user system account data using an allowlist; use a fixed neutral working
  directory; cap stdout and stderr independently; apply one operation-wide
  15-second deadline, including reinstall. Launch the CLI in a dedicated
  process group tracked
  by the authenticated connection/session. XPC interruption/invalidation,
  caller timeout or abnormal exit, unregister, catchable helper termination,
  command timeout, late overflow, read failure, and group-validation failure
  cancel active work, terminate the exact owned group TERM-to-KILL, and reap the
  direct child; uncertain cleanup fails closed. Recheck overflow/read errors
  after readers finish. Strictly decode
  one operation-specific JSON value and require exact response fields, target
  identity, version, installed/enabled state, and postconditions; `{}`, unknown
  fields, multiple values, malformed/non-UTF8 output, and contradictory state
  fail closed.
- Use targeted `plugin list --marketplace release-radar ... --json` whenever
  possible. `plugin marketplace list --json` is global; if supported
  marketplace lifecycle cannot avoid it, the helper may transiently parse the
  result in memory only to locate or collision-check `release-radar`. Capture
  an opaque supported-CLI before/after fingerprint for unrelated entries when
  they exist; do not create an unrelated sentinel in owner state. Unrelated
  entries are never returned, persisted, logged, mutated, or used for
  decisions. Do not claim the CLI never technically reads them. If
  Security/Privacy does not accept this minimum exposure after evidence, the
  feasibility gate fails. No Codex config/cache write is performed outside the
  CLI; the helper's only direct Codex-state access is the exact read-only target
  digest above.

## Test fixtures and test-first strategy

Correct the feasibility fixtures at
`ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1` and `v2`, with exact
manifest versions `1.0.0` and `1.1.0`. Their `.mcp.json` key changes from
`release-radar` to `release_radar`, so recompute and record both canonical
digests. Earlier real-CLI lifecycle behavior remains cumulative, but the old
digest values describe the old fixture bytes and must not be reused. The
remaining run derives only a v2 copy whose `.mcp.json` points to the freshly
built packaged `ReleaseRadarAgentTools`; after correction, canonical fixture
bytes stay unchanged during derivation and the live proof. Supported CLI
preflight and cleanup enforce exact-target absent-to-absent state and opaque
unrelated-fingerprint equality. All Release Radar mutations use a fresh
temporary app-owned SQLite database; the production database is never opened.
The completed no-skill pressure result remains historical evidence and is not
rerun.

Write RED tests before each implementation boundary:

1. For this correction, change only focused self-test expectations first so
   exact canonical and derived `.mcp.json` keys, the bundled read-only query,
   runtime server expectation, and recomputed canonical digests require
   `release_radar` while the current hyphenated fixtures/implementation remain.
   Compile with warnings as errors and retain the full inert-suite RED showing
   only the affected groups fail. GREEN changes only both fixture `.mcp.json`
   files and the minimum script parser/controller/digest expectations, then
   compiles with warnings as errors and passes the full inert suite.
2. Product Task 2 later adds package parser/digest/version tests and v9-to-v10
   migration/rollback tests.
3. Pure lifecycle reduction tests for all intent, observed, presentation, and
   automatic-update eligibility combinations.
4. Coordinator tests with a scripted four-method manager proving postcondition
   recheck, receipt/audit timing, idempotence, external removal, modification
   preservation, contradictory result, timeout, and partial reinstall.
5. Retain the accepted packaged signed-transport, temporary SQLite, same-team
   wrong-tool, direct packaged-tool handshake, and exact owned PID/PGID
   cancellation/reaping evidence without rerunning it. Add only the minimum
   fixed-controller assertions needed to prove strict legacy MCP recognition,
   exact supported absence, ownership-aware remove/restore cleanup, installed
   `.mcp.json` resolution, and one fresh-task MCP initialization. Cover removal
   absence near misses for wrong exit status, non-empty stdout, missing terminal
   newline, and extra terminal newline. Also cover removal
   failure with the exact entry still present (no add), removal failure with
   the entry absent (fixed add plus exact verification), unrecognized cleanup
   state (no overwrite), and every rollback producing no success receipt/audit
   and removing only attempt-owned plugin/marketplace state. No generated helper
   or negative matrix.
6. Settings presentation/action tests for every state, confirmations,
   in-flight disabling, failure recovery, version copy, new-task message, and
   separate live-observation copy.
6. One deterministic fresh-task success proves installed skill discovery and
   MCP initialization. Forced-discrepancy agent behavior is a Product Task 2
   skill acceptance case, not a feasibility gate.
7. Isolated real-CLI and final end-to-end acceptance after unit/integration
   GREEN; unit doubles never substitute for this evidence.

Target plugin queries to `--marketplace release-radar`. If the supported
marketplace commands require the global marketplace list, capture only an
opaque before/after fingerprint for existing unrelated entries and assert they
are unchanged. Do not create an unrelated owner-state sentinel. The helper
must never return, persist, log, mutate, or use unrelated entries in a
decision; Security rejection of that minimum exposure is a gate failure.

Use repository-native `xcodebuild` commands with a fresh temporary
`-derivedDataPath`. Do not add a test framework, daemon framework, snapshot-test
dependency, or generic process runner.

## Happy-path behavior

- `neverInstalled` with bundled key `release_radar` absent and an absent or
  exact recognized legacy MCP entry shows
  **Not installed** and Install. Owner Install registers/reaches the helper,
  adds or confirms the fixed marketplace, adds `release-radar`, verifies
  version/digest and bundled `release_radar` MCP resolution, removes an exact
  freshly reread legacy entry through the supported CLI, verifies bundled MCP
  resolution again, persists `managedInstalled`, writes one audit, and says to
  start a new Codex task.
- **Not installed** exposes primary Install. A clean matching managed install
  shows **Installed**, its version, and destructive Remove only.
- A clean recognized older managed install shows **Update available**. Owner
  Update, or the single eligible launch check, uses the feasibility-proven
  non-destructive update path, verifies v2, then changes receipt/audit. Update
  is primary and Remove is secondary destructive.
- Owner-confirmed Remove verifies absence, persists `removed` while preserving
  the last verified receipt fields, writes one audit, and shows **Not
  installed** without automatically reinstalling.
- A modified installation shows **Modified**, preserves its bytes, and offers
  primary Reinstall and secondary destructive Remove; **Needs repair** uses the
  same hierarchy. Confirmed Reinstall reaches a clean shipped digest before
  recording success. **Failed** exposes primary Try Again. **Checking** and all
  in-flight operations expose no actions.
- Named busy announcements are **Checking plugin status**, **Installing
  plugin**, **Updating plugin**, **Removing plugin**, **Reinstalling plugin**,
  and **Trying plugin status again**. Completion announces the verified result;
  failure announces privacy-bounded actionable copy.

## Non-happy-path and recovery behavior

- Never-installed, removed, absent/external removal, modified, conflicted,
  unknown, malformed, or unverifiable states never auto-install or overwrite.
- Conflicting marketplace identity/path, target symlink, unexpected file,
  malformed manifest/JSON, broken MCP path, untrusted/unavailable CLI,
  unauthorized peer, output overflow, timeout, and contradictory postcondition
  fail closed with privacy-bounded actionable copy and **Try Again** where safe.
- An unrecognized same-name MCP entry is a conflict and is not removed or
  overwritten. If first Install fails after removing a recognized legacy entry,
  rollback removes only newly introduced managed plugin state, restores the
  fixed legacy entry when absent, and verifies its exact semantics. A failed
  remove that leaves the exact legacy entry in place never triggers another
  add.
- External removal of a previously managed install becomes `removed` and is
  not repaired. Modified content becomes `attentionRequired` and remains
  untouched until confirmed Reinstall or Remove.
- A failed command or failed postcondition preserves the prior receipt. A
  partial Reinstall is **Needs repair**, never **Installed**, and is never
  retried automatically.
- Remove confirmation states that the managed Codex plugin will be removed and
  Release Radar delivery records will not. Cancel is default, returns focus to
  Remove, and makes no helper call. Confirmed Remove announces start and the
  verified result or privacy-bounded failure.
- Reinstall confirmation states that the plugin will be replaced with the
  shipped version and local modifications may be overwritten. Cancel is
  default, returns focus to Reinstall, and makes no helper call. Confirmed
  Reinstall announces start and the verified result or privacy-bounded failure.
- Repeated clicks while an operation is in flight perform no lifecycle call,
  persistence write, or audit.

## Activity and audit evidence requirements

For each tested transition, capture the exact lifecycle row before/after and
the matching audit delta. Assert actor, reason, timestamp presence, null project
scope, and absence of paths, raw output, config, environment, and credentials.
Record helper normalized error categories without raw command output. Existing
delivery mutation audits and notification history must remain unchanged.

## Acceptance criteria

- The feasibility gate passed with the exact bundled CLI and all independent
  preimplementation reviewers recorded GO.
- Accepted Steps 1–6, signed bridge/temporary SQLite transition, wrong-tool
  no-delta, direct packaged-tool handshake, exact legacy removal/restoration,
  and owned CLI PID/PGID evidence remain valid and are not rerun. The simplified
  remaining proof leaves the legacy entry untouched while a fresh task
  discovers the installed skill and emits the exact failed pre-action
  `mcp_tool_call` event pair for the packaged MCP tool under bundled server key
  `release_radar`.
- The signed app contains only the approved marketplace/plugin files, manifest
  version equals `CFBundleShortVersionString`, source path stays inside the
  marketplace root, and the normalized digest is deterministic.
- All four persisted intents, seven presentation states, transition rules,
  owner confirmations, automatic-update restrictions, and postcondition-first
  receipt/audit rules pass focused tests and relaunch persistence.
- Initial install, status, remove, reinstall, v1-to-v2 update, repeated
  operations, corruption cases, and partial-state recovery pass against the
  real CLI in the current login. The exact allowed `release-radar` plugin,
  marketplace, and MCP preflight state is restored. Strict recognized-legacy
  migration and rollback pass; any modified, conflicted, or unrecognized
  target stops before mutation.
- Product Task 2's signed lifecycle-helper XPC admits only the same-user Release
  Radar app, pins both peer identities, uses fixed verified CLI vectors and
  bounded output/deadlines, and passes targeted registration, approval,
  cancellation, cleanup, and wrong-peer tests. Task 1 does not generate or
  duplicate that future service.
- Targeted plugin listing and an opaque before/after fingerprint of existing
  unrelated entries prove the global marketplace list's minimum exposure is
  transient and privacy-bounded. If Security/Privacy does not accept that
  evidence, the gate fails.
- Settings is the first Connections section, separately labels plugin state
  and live Codex observation, exposes only the allowed actions, remains
  keyboard/VoiceOver accessible, announces status changes, communicates no
  state by color alone, and matches `settings.png` at wide and compact sizes.
- A new Codex task discovers the installed skill and starts the existing signed
  STDIO MCP server through machine key `release_radar`. Accepted cumulative
  evidence proves one existing typed MCP
  action reached a temporary app-owned database through the unchanged bridge;
  that action and existing bridge/dispatcher/tool schema tests are not rerun
  for this correction, and their source files remain unchanged.
- A clean Release build passes strict nested signature/resource verification.
  No claim of Developer ID/notarized distribution is made.

## Required independent reviews

- Code Reviewer: specification compliance, regressions, and no unrelated diff.
- QA/Test: fixtures, RED/GREEN, real-CLI postconditions, all state/recovery
  behavior, relaunch, UI/accessibility, and unchanged runtime integration.
- Architect: ADR boundary, interface consistency, package ownership, store
  ownership, and absence of bridge/runtime expansion.
- Security/Privacy: isolation proof, same-user/pinned identities, executable
  verification, XPC admission, environment/output/timeout bounds, helper
  and CLI-child source/runtime access evidence, descendant reaping, unique
  service cleanup, opaque unrelated-state preservation, owner-state protection, and
  sanitized persistence/audit. Linkage/entitlements are inventory, not proof of
  absent authority.
- TPM: dependency gates, single bounded product slice, and scope control.
- Delivery Manager: durable evidence completeness and next-task eligibility.

The Implementer cannot perform or substitute for any of these reviews.

## Completion evidence expected in the progress ledger

Record only in `docs/delivery/progress.md`: accepted historical CLI/integrity
evidence; current CLI/build versions; exact target preflight and cleanup;
derived `.mcp.json` to packaged-tool identity; fresh-task skill discovery and
MCP initialization; accepted cumulative temporary ticket/request/audit,
wrong-tool, direct handshake, and exact owned PID/PGID evidence; opaque
unrelated-state preservation; Product Task 2
RED/GREEN results and UI/package evidence; independent decisions; residual
risks; and the next eligible task. Do not persist raw CLI output, owner paths,
temporary database contents, or create another ledger.
