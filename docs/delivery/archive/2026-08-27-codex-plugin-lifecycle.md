# Release Radar Codex Plugin Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship and safely manage the single app-bundled `release-radar` Codex
plugin from Settings, but only after an isolated signed proof establishes that
the actual bundled Codex CLI supports the approved lifecycle boundary.

**Architecture:** Task 1 is a non-product feasibility proof in the owner's
current Codex state, strictly scoped to `release-radar` through the supported
CLI. It either records a complete passing CLI/XPC contract or blocks the
feature. Only after independent GO decisions may Task 2 deliver one bounded
vertical slice: signed plugin resources, one narrow same-user lifecycle helper,
app-owned intent/receipt persistence, Settings state/actions, and final
unchanged-runtime acceptance.

**Tech Stack:** Swift 6, SwiftUI, Foundation, CryptoKit, Security,
ServiceManagement/`SMAppService`, private `NSXPCConnection`, SQLite through the
existing `DeliveryStore`, XCTest, Xcode 26, and the fixed ChatGPT-bundled Codex
CLI.

**Spec:** `docs/design/release-radar-codex-plugin-lifecycle-design.md`

**Product task brief:**
`docs/delivery/task-briefs/2026-08-27-codex-plugin-lifecycle/task-1-brief.md`

## Global Constraints

- Minimum macOS version remains 14.0; Swift remains 6.0.
- Stable plugin and marketplace identity is exactly `release-radar`.
- The plugin-provided MCP server uses machine key `release_radar`, required for
  Codex's callable `mcp__release_radar__...` namespace. It is an internal
  identifier in the one plugin, not a second product alias. Do not add a
  `release-radar-plugin` alias. A legacy owner-configured `release-radar` MCP
  entry is replaceable only when supported CLI JSON proves the exact recognized
  AgentTools STDIO contract; an unrecognized same-name entry fails closed.
- Product manifest version must equal the app's
  `CFBundleShortVersionString`/`MARKETING_VERSION` (currently `0.1.0`).
- Feasibility fixtures are exactly v1 `1.0.0` and v2 `1.1.0`.
- The only Codex executable is
  `/Applications/ChatGPT.app/Contents/Resources/codex`; require containing app
  identifier `com.openai.codex`, CLI identifier `codex`, team `2DC432GLL2`, a
  strict valid signature, Hardened Runtime, a regular non-symlink executable,
  and no group/world write bit.
- The lifecycle helper accepts only the same effective UID and signed Release
  Radar app identity `com.rekonlabs.ReleaseRadar`, team `2UA854NLX4`.
- The helper XPC surface is exactly `status`, `install`, `remove`, and
  `reinstall`, with no method arguments and a bounded normalized reply.
- App-group, Keychain, bookmark/project-folder, network, `ReleaseRadarCore`,
  SQLite, MCP, STDIO, URL, and agent endpoints are prohibited helper uses, not
  OS-enforced absences. Focused source review and targeted implementation/
  acceptance tests establish the helper's direct-access boundary. The
  official CLI child necessarily accesses Codex-owned state and is bounded by
  fixed commands, normalized output, exact-target postconditions, and the
  opaque unrelated-state fingerprint; linkage/entitlement inspection is
  corroborating inventory only.
- Every real CLI proof runs in the owner's current macOS login. Product
  `SMAppService` acceptance runs there only after the lifecycle helper exists.
  Supported CLI preflight classifies only the exact `release-radar`
  plugin/marketplace/MCP target and records an opaque before-state for unrelated
  entries. The run restores the allowed target state exactly and stops before
  mutation on any modified, conflicted, or unrecognized target. The MCP
  baseline may be absent or the exact recognized legacy entry. The helper's
  only direct
  Codex-state access is the owner-authorized read-only three-file digest under
  the exact versioned `release-radar` cache root; it never reads configuration
  or unrelated cache state and never writes raw Codex state.
- Production derives the exact cache root from `getpwuid_r(geteuid())`, not
  `$HOME`, plus one strict SemVer component from targeted CLI output. The public
  helper accepts no path; only an internal digester constructor accepts a
  derived test home. Descriptor-relative no-follow opens and before/after
  identity/metadata checks reject path replacement and change-while-read.
- The completed no-skill RED baseline remains historical evidence. No further
  stochastic agent evaluation is required by the feasibility gate.
- No direct Codex config/cache writes, shell, `$PATH`, HTTP, generic command or
  XPC surface, background poller, periodic reconciliation, new ticket command,
  new top-level UI, diff viewer, wizard, or generalized plugin manager.
- Existing `ReleaseRadarAgentTools`, bridge, dispatcher, tool schemas, runtime
  XPC contracts, and app-only SQLite mutation path remain unchanged.
- `docs/delivery/progress.md` remains the only status/evidence ledger.

---

### Task 1: Prove the real CLI and signed lifecycle boundary in isolation

This task is a feasibility probe, not product implementation. It may add only
fixtures and a focused probe under `script/`; it must not add the product
helper target, app resources, schema, Settings UI, or runtime code. A failure
ends this plan.

**Files:**

- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/.agents/plugins/marketplace.json`
- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/.codex-plugin/plugin.json`
- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/.mcp.json`
- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/skills/release-radar/SKILL.md`
- Create: the same four paths under
  `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v2/`
- Create: `script/codex-plugin-lifecycle-feasibility.swift`
- Modify only
  `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift` method
  `testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp` for
  bundle-context ownership-safe bridge registration and cleanup
- Modify at the controller-owned Step 1 checkpoint and after the proof:
  `docs/delivery/progress.md` with the no-skill RED evidence, gate result, and
  independent decisions
- Must not modify: product source, `ReleaseRadar.xcodeproj/project.pbxproj`,
  app resources, existing bridge/MCP files, ADRs, or design documents

**Interfaces:**

- Consumes the bundled CLI's documented JSON commands from the current login:
  `plugin marketplace add/list/remove` and targeted
  `plugin add/list/remove` for `release-radar`, plus fixed supported
  `mcp get release_radar --json` for the bundled server, and legacy
  `mcp get release-radar --json`, `mcp remove release-radar`, and rollback
  `mcp add release-radar -- /Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`.
- Produces a durable pass record containing the exact CLI version, marketplace
  name/path JSON, plugin add/list/remove JSON, fixed argv for the four helper
  operations, repeated-operation semantics, update semantics, integrity
  mechanism, MCP discovery result, output limits/timeout chosen by the proof,
  and packaged-runtime mutual peer-admission plus wrong-tool no-delta results.
- A pass permits Task 2. Any missing proof item produces a blocker and no
  product implementation.

- [ ] **Step 1: Record the controller-owned no-skill RED pressure scenario**

Before either fixture `SKILL.md` exists, the primary/controller creates a
disposable repository with applicable repository instructions and an existing
durable tracking convention, plus a temporary Release Radar database. Ticket
`RR-SKILL-01` starts in progress in both stores. Make the typed Release Radar
MCP tools available, but do not install or expose the proposed skill.

Prompt exactly:

```text
RR-SKILL-01 is ready for review. Synchronize its project tracking.
```

The evaluator starts in fresh context with access only to that repository, the
typed tools, and the owner prompt; it cannot see the proposed skill, approved
design, or this plan. Record whether the agent reads the instructions and convention, updates only
repository documentation, updates only Release Radar, updates and verifies
both, or claims consistency without both verified. Preserve the observed
rationalization. This is the RED baseline even if the unspecialized agent
happens to satisfy some requirements; its stochastic result does not decide
CLI or XPC feasibility. A `docs/delivery/progress.md` checkpoint is permitted
immediately after the controller records it. The Task Implementer must not spawn,
prompt, or substitute an evaluator. Only after the controller records this
baseline may the fixture skill be written.

- [ ] **Step 2: Create exact v1 and v2 marketplace fixtures**

Use the same marketplace JSON in both versions:

```json
{
  "name": "release-radar",
  "interface": { "displayName": "Release Radar" },
  "plugins": [
    {
      "name": "release-radar",
      "source": { "source": "local", "path": "./plugins/release-radar" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
      "category": "Productivity"
    }
  ]
}
```

Use this manifest, changing only `version` from `1.0.0` to `1.1.0`:

```json
{
  "name": "release-radar",
  "version": "1.0.0",
  "description": "Keep durable Release Radar tracking and typed delivery state consistent.",
  "skills": "./skills/",
  "mcpServers": "./.mcp.json",
  "interface": {
    "displayName": "Release Radar",
    "shortDescription": "Track delivery with Release Radar",
    "developerName": "Rekon Labs",
    "category": "Productivity",
    "capabilities": ["Read", "Write"]
  }
}
```

The `.mcp.json` in both fixtures is exactly the following and contains no
caller-selected arguments or environment:

```json
{
  "release_radar": {
    "command": "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools",
    "args": []
  }
}
```

The skill frontmatter is exactly:

```markdown
---
name: release-radar
description: Use when working in a repository tracked by Release Radar or when the owner asks to initialize or synchronize Release Radar tracking.
---
```

Write the concise body only after reading the controller's Step 1 RED evidence.
It must contain the minimum guidance that corrects the observed failure and the
approved invariants: read applicable repository instructions and existing
durable tracking conventions; initialize only minimum owner-requested tracking
documentation; use typed Release Radar MCP tools rather than SQLite; update
repository documentation and corresponding Release Radar state in the same
owner-directed workflow; verify both postconditions; report a discrepancy
instead of completion when either remains unverified; and never fabricate
completion, review, acceptance, or authority. Do not add generic project
process not justified by the RED evidence.

Validate every JSON file by converting it with
`plutil -convert xml1 -o - -- <file>` and linting the converted stream with
`plutil -lint -- -`; direct `plutil -lint <json>` rejects valid JSON on this
macOS host. Byte-compare every file except the manifest version, and assert
each marketplace source path resolves inside its fixture root.

- [ ] **Step 3: Write the isolated feasibility probe before running lifecycle commands**

Implement `script/codex-plugin-lifecycle-feasibility.swift` as one focused
executable. Its public test model is:

```swift
enum ProbeOperation: String, Codable { case status, install, remove, reinstall }

struct ProbeResult: Codable {
    let cliVersion: String
    let operation: ProbeOperation
    let exitStatus: Int32
    let stdout: Data
    let stderr: Data
    let elapsedMilliseconds: Int
}

struct ProbeFailure: Error, Equatable {
    enum Kind: String, Codable, Equatable { case unavailable, untrusted, timeout, outputOverflow, malformedJSON, conflict, postcondition }
    let kind: Kind
}
```

The runner invokes the fixed CLI path directly with `posix_spawn`, exact argv,
a file-action working directory set to a newly created empty directory, and an
environment containing only fixed locale/path values derived from trusted
same-user system account data. Use `POSIX_SPAWN_SETPGROUP` with process group zero so the
child group is established atomically without a shell or wrapper. Cap stdout
and stderr at 1 MiB each and terminate at 15 seconds. On timeout, either output
overflow, unregister, or abnormal helper exit, send TERM to the whole group,
send KILL after the fixed grace interval if needed, and `waitpid` until every
child is reaped.
Reject nonzero exit, more than one JSON value, unknown JSON fields, non-UTF-8
JSON text, and any caller-supplied path outside the fixed fixture/runtime root.

Before invoking the CLI, `lstat` every fixed path component and run
`codesign --verify --strict`; validate `com.openai.codex`, `codex`,
`2DC432GLL2`, runtime flags, regular-file type, and mode `& 0o022 == 0`.

Compile without adding a target:

```bash
xcrun swiftc -parse-as-library \
  script/codex-plugin-lifecycle-feasibility.swift \
  -framework Foundation -framework Security -framework CryptoKit \
  -o "$RR_PLUGIN_PROBE_ROOT/codex-plugin-lifecycle-feasibility"
```

Expected before completing the probe logic: compilation or the probe's own
self-tests fail on missing strict parsing, deadline, integrity, and identity
checks. Do not run a lifecycle mutation until those checks pass.

Run the same concrete self-test command before and after implementing those
checks:

```bash
"$RR_PLUGIN_PROBE_ROOT/codex-plugin-lifecycle-feasibility" self-test \
  --fixture-root ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1 \
  --cli /Applications/ChatGPT.app/Contents/Resources/codex
```

The self-test creates only runtime inputs under `$RR_PLUGIN_PROBE_ROOT`: valid,
malformed, multi-value, and unknown-field JSON; a 16-second child; stdout and
stderr streams of 1 MiB plus one byte; timeout/overflow/abnormal-exit children
that each spawn a grandchild; an escaping and a confined path; clean
and one-byte-edited fixture copies with expected digests; and fixed CLI path,
writable-copy, symlink, and wrong-identity candidates. Record failing RED and
passing GREEN output for JSON, timeout, overflow, path, digest, identity, whole
process-group termination, and descendant reaping.

Before any real CLI/service mutation, the controller uses supported read-only
CLI commands in the current login to classify the exact `release-radar`
marketplace/plugin/MCP state and capture an opaque fingerprint for unrelated
entries. Proceed only when the plugin and marketplace are absent and the MCP
entry is absent or exactly recognized: name `release-radar`, enabled, no
disabled reason, STDIO command
`/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`, empty
arguments, nil working directory, and nil or empty environment. Unknown JSON,
contradictory values, or any other same-name entry stops before mutation.
Additional CLI fields are tolerated only when they do not contradict the
required semantics. For the pinned CLI, targeted absence is exactly exit status
`1`, empty stdout, and stderr
`Error: No MCP server named 'release-radar' found.` followed by one newline;
every other exit/output combination is an error.

Self-tests must prove strict recognition, exact fixed remove/add vectors,
supported not-found handling, removal failure that leaves the exact entry in
place without a duplicate add, restoration when absent, and failure without
overwrite when cleanup sees an unrecognized entry. After success and every
failure, use only supported CLI operations to clean up and verify plugin and
marketplace absence, exact initial MCP semantics, and the unchanged unrelated
fingerprint. Cleanup failure stops all later gate work. Do not read raw Codex
configuration or unrelated cache state and do not write raw Codex state.

The absence-parser table must accept only the pinned tuple above and reject at
least: exit status `0`, non-empty stdout, the otherwise exact stderr without its
terminal newline, and the exact stderr with an extra newline. These are inert
self-tests; they perform no CLI mutation.

- [ ] **Step 4: Prove marketplace confinement and clean v1 lifecycle**

Inside the current login, create fresh fixture/runtime working roots with
`mktemp -d` and use only the allowlisted environment. Do not create an
unrelated marketplace/plugin sentinel. Record the supported-CLI scoped target
state and opaque unrelated-entry fingerprint, then run. Implement the
fingerprint by strictly parsing the supported marketplace-list JSON, removing
only the exact `release-radar` entry, recursively sorting object keys and
sorting semantically unordered array entries by their canonical JSON bytes,
then hashing those bytes with SHA-256 in memory. Never log or persist the
unrelated JSON:

```text
codex plugin marketplace add <fixed-v1-marketplace-root> --json
codex plugin marketplace list --json
codex plugin add release-radar@release-radar --json
codex plugin list --marketplace release-radar --available --json
codex plugin remove release-radar@release-radar --json
codex plugin list --marketplace release-radar --available --json
codex plugin add release-radar@release-radar --json
```

Assert the marketplace list resolves the exact fixture root and stable name;
the plugin list distinguishes installed from available; install and remove
reach exact postconditions; and reinstall ends with version `1.0.0` plus the
fixture digest. Repeat marketplace add, plugin add, and plugin remove once each
and require either a successful no-op or a normalized non-destructive error.

Use `plugin list --marketplace release-radar ... --json` for every plugin
observation. The supported marketplace lifecycle may require the unfiltered
`plugin marketplace list --json`; when it does, permit only transient in-memory
parsing to locate or collision-check `release-radar`. Assert an opaque
before/after fingerprint for existing unrelated entries is unchanged and that
their contents are never returned by the helper, persisted, logged, or used in
a decision. Do not claim the CLI never technically reads those entries. If
Security/Privacy does not accept this minimum exposure after the evidence is
reviewed, fail the feasibility gate.

Add a second marketplace using the same name with a different root and require
the probe to reject the conflict before plugin mutation. If CLI JSON omits the
resolved marketplace identity/path needed for that decision, the gate fails.

- [ ] **Step 5: Prove v1-to-v2 update and non-atomic reinstall behavior**

Start clean at installed v1 from one derived stable marketplace root, replace
only that temporary source with the v2 fixture at the same path, invoke the
same supported `plugin add release-radar@release-radar --json`, and re-list.
Require installed version `1.1.0`, the v2 digest, the same plugin identity,
installed/enabled state, and no remove/add partial state or unrelated change.
The pinned CLI exposes no supported MCP approval or plugin-choice state. Task 1
makes no assertion about those unobservable values and introduces no separate
mechanism for them.

Separately force add failure after a successful remove using a malformed copy
of v2. Require the probe to report partial `needsRepair`, preserve evidence that
remove succeeded, and perform no automatic retry. Restore the valid fixture and
require one explicit reinstall to recover. If the CLI cannot update safely or
cannot make the partial state observable, fail the gate.

- [ ] **Step 6: Prove target-scoped integrity and malformed-state handling**

Use derived fixture/runtime copies, never an installed owner target, to
exercise the classifier with exactly one mutation: one-byte `SKILL.md` edit;
missing manifest; malformed manifest; `.mcp.json` command changed to a
nonexistent file; partial install metadata; target-root symlink; non-regular
entry; or unexpected extra file. Require: exact valid recognized bytes are
`clean`; an exact valid shape with a one-byte skill edit or syntactically valid
changed MCP command is `modified`; missing/extra, malformed, symlink,
non-regular, rejected version/path escape, partial, component replacement, and
change-while-read are `needsRepair(.integrityInvalid)`; and only OS read failure
or unavailable expected digest is `.integrityUnknown`.

Against a derived cache-shaped target, use the internal digester seam with a
derived home. Production obtains home from `getpwuid_r(geteuid())`, never
`$HOME`, and accepts only a single strict SemVer component of at most 128 ASCII
characters from targeted CLI JSON. Construct only
`~/.codex/plugins/cache/release-radar/release-radar/<version>`, walk fixed
components through descriptor-relative no-follow opens, and compare each
regular file's device/inode/type/size/modification/change metadata before and
after the complete read. Read exactly the three declared plugin files. Snapshot
the full derived tree before each status call and prove identical inventory and
bytes afterward. Prove the exact classifications above, denial without open of
configuration and sibling version/plugin paths, and no home/cache path in
structured output or captured logs.

Then repeat the authorized absent-to-absent real lifecycle using only supported
CLI mutations. After v1 install, use the production root derivation and
read-only digester to prove the actual installed digest equals the canonical v1
digest. Update in place through the same supported `plugin add`, then prove the
actual installed v2 digest equals the canonical v2 digest. Supported CLI
cleanup must restore target absence. Do not corrupt an owner installation.

- [ ] **Step 7: Prove the installed plugin and existing signed runtime compose**

Treat the accepted Steps 1–6 CLI and digest/integrity mechanics for the old
hyphenated fixture bytes as historical proof; they do not establish the new
underscore-fixture digests, and their matrices are not regenerated. Build the
current signed app and packaged
`ReleaseRadarAgentTools` in fresh DerivedData. Create one derived v2 plugin copy
whose `.mcp.json` points to that exact packaged tool, compute its derived digest,
and prove both corrected canonical fixtures remain byte-unchanged during
derivation. Because this correction changes both canonical `.mcp.json` files,
recompute and record v1/v2 digests; earlier digest values remain historical
evidence for the old bytes and are not reused.

Before implementation, change only focused self-test expectations to require
exact `release_radar` canonical/derived keys, fixed
`mcp get release_radar --json`, runtime server `release_radar`, and newly
computed canonical digests while the hyphenated fixture/implementation remains.
Compile with warnings as errors and retain the inert-suite RED with only the
affected groups failing. GREEN changes only the two fixture `.mcp.json` files
and the minimum script parser/controller/digest expectations, then requires a
warnings-as-errors compile and full inert-suite pass.

From the supported baseline, leave any exact recognized legacy
`release-radar` MCP entry untouched and install only the derived `release-radar`
plugin through the verified official CLI. Before installation, require
supported `mcp get release_radar --json` to return exit `1`, empty stdout, and
exact stderr `Error: No MCP server named 'release_radar' found.` plus one
newline; every other result stops before mutation. After installation, verify
supported
`mcp get release_radar --json` resolves to the derived packaged AgentTools.
Use the existing confined read-only digester to require that the installed
three-file digest equals the newly computed derived digest; do not rerun v1 or
update lifecycle matrices.
The accepted direct handshake for that exact binary supplies protocol
`2025-06-18`, server name `Release Radar`, server version `1`, and the tool
schema. Start one fresh Codex task and require JSONL `item.started` plus
`item.completed` for one `mcp_tool_call` whose server is `release_radar`, tool
is `release_radar_transition_ticket`, and arguments are `{}`. Completion must
be `failed` with either a nonempty schema/argument-validation error or a Codex
approval-policy rejection that prevents server execution, with no result and
no Release Radar action. This expected non-mutating event pair proves callability;
agent prose alone is not evidence. No forced-discrepancy or second stochastic
agent evaluation is part of this gate. Accepted cumulative evidence already
proves the fixed exact-legacy removal, pinned absence, and restoration sequence;
do not rerun it.

Retain without rerunning the accepted signed bridge/temporary SQLite
transition, same-team wrong-tool no-delta case, direct packaged AgentTools
handshake, and exact owned CLI PID/PGID cancellation/reap evidence. Those
results remain cumulative Task 1 evidence; this correction changes none of
their source or boundary. Do not run the named hosted acceptance test, direct
handshake, or cancellation again.

On success or failure, remove only the exact plugin and marketplace through the
supported CLI. Require plugin/marketplace absence, bundled `release_radar` MCP
absence, the exact unchanged initial legacy `release-radar` MCP state, and the
unchanged opaque unrelated fingerprint. Do not remove or restore the legacy
entry in this corrected proof. No feasibility helper, harness application, Mach service,
generated Swift source, `launchctl`/`libproc` corroborator, runtime tracer,
signal-injection matrix, or process-reconciliation framework is permitted.
Production lifecycle-helper registration, approval, authenticated XPC, and
cleanup tests remain Product Task 2 requirements.

- [ ] **Step 8: Record the pass or blocker and stop at the gate**

Run `git diff --check`, confirm product source and the Xcode project are
unchanged, and update only `docs/delivery/progress.md` with exact versions,
target-only preflight/cleanup, derived packaged-tool identity, fresh-task skill
discovery and MCP initialization, legacy MCP recognition/removal/restoration,
temporary ticket/request/audit postconditions,
wrong-tool no-delta evidence, exact owned PID/PGID cleanup, unchanged unrelated
fingerprint, and residual risks.

Architecture, TPM, QA/Test, Security/Privacy, and Delivery Management each
review the real evidence. If any Required finding remains or any gate criterion
failed, record NO-GO and stop. Do not begin Task 2 and do not add a config/cache
writer or alternative framework.

---

### Task 2: Deliver the single product lifecycle vertical slice

**Files:**

- Create the product package, lifecycle Core/store, lifecycle transport/client,
  lifecycle helper, and two focused test files listed in the product brief.
- Modify only `StoreMigrations.swift`, app composition/model/launch task,
  Settings models/view, focused store/app/runtime acceptance tests, and Xcode
  target/resource/signing wiring listed in the product brief.
- Do not modify existing runtime bridge, dispatcher, AgentTools source, or tool
  schema files.

**Interfaces:**

- Consumes Task 1's independently accepted fixed CLI argv, JSON fields,
  isolation/integrity semantics, and partial-state behavior.
- Produces the exact `CodexPluginIntent`, `CodexPluginReceipt`,
  `CodexPluginObservedState`, `CodexPluginPresentationState`,
  `CodexPluginLifecycleManaging`, and four-method XPC interfaces in the product
  brief.

- [ ] **Step 1: Write RED package, digest, state, migration, and coordinator tests**

In `CodexPluginLifecycleAcceptanceTests.swift`, add table-driven tests that:

```swift
XCTAssertEqual(try package.version, Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
XCTAssertEqual(try package.relativeFiles, [
    ".codex-plugin/plugin.json",
    ".mcp.json",
    "skills/release-radar/SKILL.md",
])
```

Assert the normalized digest is stable across enumeration order and rejects a
symlink, traversal, missing/extra file, non-regular file, or concurrent byte
change. Add v9-to-v10 migration, schema-drift, rollback, relaunch, and singleton
row tests.

Table-drive every persisted intent plus absent/clean-old/clean-current/modified/
repair observation into the seven presentation states and available actions.
Prove auto-update eligibility is true only for clean recognized
`managedInstalled` with matching recorded digest and older version.

With a scripted `CodexPluginLifecycleManaging`, require every command success
to be followed by `status`; mutate receipt and append the exact path-free audit
only after the postcondition matches. Prove timeout, malformed, contradictory,
external removal, modification, repeated observation, and remove-success/
add-failure behavior preserve receipt and never silently retry.

Add first-Install cases for an absent bundled MCP entry, the exact recognized
direct underscore entry, an unrecognized underscore entry, the exact recognized
legacy hyphenated entry, and an unrecognized legacy entry. Require managed plugin
version/digest verification, an initially absent branch that skips migration,
full direct-entry near-miss coverage for disabled state, disabled reason,
command, arguments, working directory, and environment fields, classification
of both direct and legacy entries before mutation,
an immediate fresh exact-recognition read before direct-entry removal and
absence verification before plugin add, and an immediate fresh exact-recognition
read before legacy removal only for the initially exact branch. Require bundled
`release_radar` MCP verification
before and after any legacy removal and before `managedInstalled`, and
rollback that removes only plugin/marketplace state introduced by the attempt
and restores the exact legacy entry only after the attempt issued removal.
Require the same ownership-aware rollback for the exact direct entry: restore
it only after this attempt removed it and only while the key remains absent.
Explicitly prove: removal
failure with the exact entry still present causes no add; removal failure with
the entry absent performs the fixed add and exact verification; unrecognized
cleanup state is not overwritten; every rollback creates no success receipt or
audit; later Update/Reinstall/Remove never repeat the migration; and Remove
never recreates the legacy entry. Do not add a migration table or flag.

Run:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-PluginLifecycle-RED \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests \
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests
```

Expected: FAIL because the package, version-10 table, lifecycle types, store,
and coordinator do not exist.

- [ ] **Step 2: Implement the minimum package/core/store behavior to make the focused tests GREEN**

Create the canonical resource tree with marketplace source
`./plugins/release-radar`; manifest version equal to the app marketing version;
the concise approved skill; and one `.mcp.json` entry for the existing signed
AgentTools path proven by Task 1. Implement the exact digest framing and strict
resource validation from the brief.

Add schema version 10 with one `codex_plugin_lifecycle` singleton row contract:

```sql
CREATE TABLE codex_plugin_lifecycle (
    plugin_id TEXT PRIMARY KEY NOT NULL CHECK (plugin_id = 'release-radar'),
    intent TEXT NOT NULL CHECK (intent IN ('neverInstalled','managedInstalled','removed','attentionRequired')),
    managed_version TEXT,
    managed_digest TEXT,
    verified_at TEXT,
    CHECK ((managed_version IS NULL) = (managed_digest IS NULL)),
    CHECK ((managed_version IS NULL) = (verified_at IS NULL))
);
INSERT INTO codex_plugin_lifecycle (plugin_id, intent)
VALUES ('release-radar', 'neverInstalled');
```

Implement lifecycle reduction/coordinator and store calls using the exact audit
reasons in the brief. A read-only status does not audit unless it changes
persisted intent to `removed` or `attentionRequired`; it never rewrites the last
verified version/digest/time.

Re-run the Step 1 command and expect PASS.

- [ ] **Step 3: Write RED transport/helper security tests**

In `CodexPluginLifecycleTransportTests.swift`, build the packaged helper and a
wrong-identity peer. Require:

- four no-argument selectors only and a versioned reply no larger than 64 KiB;
- same UID plus app identifier/team admission and wrong-peer rejection before
  invocation;
- fixed Task 1 argv only; no shell, caller input, `$PATH`, or inherited
  environment; neutral cwd; 15-second timeout; 1 MiB stdout/stderr bounds;
- strict parsing of both exact direct `release_radar` and legacy `release-radar`
  `mcp get` contracts; fixed remove and rollback-add vectors for each; all
  enabled/disabled-reason/command/arguments/cwd/environment near misses;
  dual-entry classification before mutation; ownership-aware restoration;
  absent-entry and unrecognized-entry behavior;
  no direct configuration access and no second MCP alias;
- dedicated CLI process group, bounded TERM/KILL of the exact owned group, and
  direct-child reap on timeout, output overflow, unregister, and abnormal exit;
- exact required JSON semantics with additional fields allowed only when
  noncontradictory; malformed, duplicate, or contradictory values fail closed;
  normalized errors contain no raw output or paths;
- fixed CLI and containing-app path, mode, identifier, team, signature, and
  Hardened Runtime checks;
- exact versioned target-cache three-file digest with component/symlink/
  inventory/change-while-read checks; deny configuration, sibling plugin, and
  sibling version reads; conflict failure before mutation;
- targeted plugin listing; privacy-bounded transient global marketplace parsing
  only when required, with an opaque unrelated-entry before/after fingerprint
  and non-return/persistence/logging/mutation/decision assertions;
- focused source review and targeted operation tests for prohibited Core,
  SQLite, app-group, Keychain, bookmark/folder, network, MCP, agent endpoint,
  configuration, and unrelated-cache direct use by the helper; fixed commands,
  normalized output, exact-target postconditions, and the unchanged opaque
  unrelated-state fingerprint bound the CLI child.

Expected RED: the helper target, lifecycle XPC contract, and client do not yet
exist.

- [ ] **Step 4: Implement and package the narrow helper/client, then run transport GREEN**

Create `ReleaseRadarPluginLifecycleHelper` as a tool target with Hardened
Runtime, `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`, an empty entitlement plist,
no Core linkage, and a LaunchAgent plist under
`Contents/Library/LaunchAgents`. Copy the helper into
`Contents/Resources` with CodeSignOnCopy. Add a distinct fixed Mach service and
designated requirements; do not reuse or change the existing bridge services.

The helper derives its marketplace resource from its own containing signed app
bundle, accepts no path, and implements the exact fixed commands accepted in
Task 1. `install` handles initial add and proven clean update; `reinstall`
performs explicit remove then add and reports partial failure without claiming
atomicity. The client registers/reaches the agent only for owner Install or an
already-managed launch check and pins the helper identity.

On first Install only, accept bundled key `release_radar` as absent or as the
exact enabled STDIO entry with no disabled reason, the packaged AgentTools
command, empty arguments, null working directory, and empty or null environment
fields. Contradictory fields fail closed. Classify both the direct and legacy
entries before any mutation. Freshly reread and remove only that exact direct
entry through the supported
CLI, then verify absence before plugin installation. Changed or unrecognized
direct state is a conflict. Restore the direct entry on later failure only if
this operation removed it and the key remains absent. Separately accept an
absent legacy `release-radar` MCP entry or the exact recognized legacy entry and
retain that observation only for the duration of the operation. Install and
verify the managed plugin, including bundled
server `release_radar`. If the legacy entry was initially absent, skip migration
and verify the final bundled-server postcondition. If it was initially exact,
immediately reread it and remove it with the fixed supported CLI vector only if
it still matches, then verify bundled server `release_radar` again. If the
legacy entry is absent or changed/unrecognized at the reread, avoid
removal/restoration, roll back only attempt-owned managed state, and report no
success. After this operation issues removal, a later failure may restore the
exact legacy entry. Report success only after the final bundled-server
verification and all postconditions pass. An unrecognized entry is never
mutated. Use the existing lifecycle intent as the boundary; add no migration
state, second plugin/server alias, reconciliation loop, XPC method, or caller-
selected command.

Run the focused transport tests and inspect:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-PluginLifecycle-Transport \
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleTransportTests
otool -L /tmp/ReleaseRadar-PluginLifecycle-Transport/Build/Products/Debug/ReleaseRadar.app/Contents/Resources/ReleaseRadarPluginLifecycleHelper
codesign -d --entitlements :- /tmp/ReleaseRadar-PluginLifecycle-Transport/Build/Products/Debug/ReleaseRadar.app/Contents/Resources/ReleaseRadarPluginLifecycleHelper
```

Expected: tests PASS; no `ReleaseRadarCore`/SQLite link and no sandbox, app
group, Keychain, folder, or network entitlement in the corroborating inventory;
focused source review and targeted operation tests, not that inventory alone,
establish the prohibited-use boundary.

- [ ] **Step 5: Write RED Settings and launch-policy tests**

In `AppRouteTests.swift`, table-drive all presentation states and assert exact
action hierarchy: Not installed has primary Install; Installed has destructive
Remove only; Update available has primary Update and secondary destructive
Remove; Modified and Needs repair have primary Reinstall and secondary
destructive Remove; Failed has primary Try Again; Checking and every in-flight
operation have no actions. Assert the named busy announcements **Checking
plugin status**, **Installing plugin**, **Updating plugin**, **Removing plugin**,
**Reinstalling plugin**, and **Trying plugin status again**, plus result and
privacy-bounded failure announcements.

Require the Remove confirmation to say it removes the managed Codex plugin,
not Release Radar delivery records; Cancel is default, returns focus to Remove,
and makes no helper call. Require the Reinstall confirmation to say it replaces
the plugin with the shipped version and may overwrite modifications; Cancel is
default, returns focus to Reinstall, and makes no helper call. Confirmed actions
announce start and verified result or privacy-bounded failure. Also assert
version copy, separation from `CodexConnectionPresentation`, one call while in
flight, and `Start a new Codex task to load the plugin change.` after success.

Add a launch test proving automatic check/update runs once only for eligible
clean managed state and never for never-installed, removed, absent, modified,
conflict, unknown, or `externalServicesSuppressed` test launches.

Expected RED: AppModel and Settings have no lifecycle state/actions.

- [ ] **Step 6: Implement the first Connections section and one launch-time check**

Compose the lifecycle coordinator in `ReleaseRadarAppServices`, inject it into
`AppModel`, and expose `loadCodexPluginStatus()`, `installCodexPlugin()`,
`updateCodexPlugin()`, `removeCodexPlugin()`, and
`reinstallCodexPlugin()`. Disable all actions while one operation is active.
Call the single launch initialization after the existing dashboard load in
`SidebarView.task`; do not add a timer or background poller.

Add **Release Radar Codex Plugin** as the first `connections` section, above the
existing Codex observation, bridge, and Pushover sections. Use text plus system
symbols, the tested per-state action hierarchy and confirmation/focus behavior,
stable accessibility IDs, named busy/result/failure announcements, and
`ViewThatFits`/wrapping so the current compact Settings window and a wider
window preserve hierarchy. Do not add a route or mockup.

Run the focused package/store/transport/app tests and expect PASS.

- [ ] **Step 7: Run isolated real-CLI, UI, unchanged-runtime, and Release acceptance**

Repeat Task 1's v1/v2 lifecycle matrix with the packaged signed helper in the
owner's current macOS login. Use the same supported-CLI conflict preflight,
strict legacy MCP recognition, first-Install replacement/rollback, exact
target-state restoration, and opaque unrelated-entry before/after fingerprint.
Never directly inspect raw owner Codex configuration or cache
state outside the exact owner-authorized three-file `release-radar` digest;
never write raw Codex state. Verify modification preservation, confirmed
reinstall, partial-state recovery, targeted plugin listing, privacy bounds,
process-group cleanup, and exact service unregistration.

Run a new Codex task against the installed product plugin, verify skill
discovery, and execute one existing typed MCP action through the existing
signed bridge into a temporary database. Re-run
`AgentBridgeTransportAcceptanceTests` and confirm no source diff in the four
protected runtime files.

Capture Settings accessibility and screenshots at current compact and wider
sizes against `docs/design/mockups/settings.png`; verify focus order,
announcements, confirmations, disabled in-flight actions, actionable failure,
versions, separate observation state, and new-task message.

Finally run:

```bash
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -derivedDataPath /tmp/ReleaseRadar-PluginLifecycle-Full
xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -configuration Release -derivedDataPath /tmp/ReleaseRadar-PluginLifecycle-Release \
  clean build
codesign --verify --deep --strict --verbose=4 \
  /tmp/ReleaseRadar-PluginLifecycle-Release/Build/Products/Release/ReleaseRadar.app
git diff --check
```

Inspect the resource inventory, manifest/app version equality, deterministic
digest, main/helper identities and entitlements, nested signatures, helper
linkage, and protected runtime-file diffs. Compilation alone is not acceptance.

- [ ] **Step 8: Independent acceptance and ledger closeout**

Fresh Code Review, QA/Test, Architecture, Security/Privacy, TPM, and Delivery
Management independently review the product evidence. Required findings block
completion; optional improvements do not expand this slice.

After all six GO decisions, update only `docs/delivery/progress.md` with the
evidence enumerated in the product brief and the next eligible task. Stop when
the approved lifecycle outcome is accepted; do not add adjacent plugin,
runtime, UI, or distribution work.

### Task 3: Correct the owner-requested repository handoff and observation copy

**Current amendment:** the installed `0.1.2` live proof exposed a self-
referential copied prompt, unscoped project-status copy, a guidance-only
`upsert_phase` used solely to obtain an audit, and mutation-before-write ordering
that refreshed the UI before the guidance existed. The active correction is
`0.1.3`; `docs/delivery/progress.md` remains the status source of truth.

**Files:**
- Modify: `ReleaseRadar.xcodeproj/project.pbxproj` (`ReleaseRadar` Debug and Release `MARKETING_VERSION`)
- Modify: `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json`
- Modify: `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md`
- Add: `ReleaseRadarCore/Onboarding/ProjectGuidanceInspection.swift`
- Modify: `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- Modify: `ReleaseRadar/App/AppModel.swift`
- Modify: `ReleaseRadar/Projects/OnboardingView.swift`
- Modify: `ReleaseRadar/Projects/ProjectOverviewView.swift`
- Modify: `ReleaseRadar/Navigation/SidebarView.swift`
- Modify: `ReleaseRadar/Shared/FailureStateView.swift`
- Test: `ReleaseRadarTests/ProjectGuidanceAcceptanceTests.swift`
- Test: `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- Test: `ReleaseRadarTests/FailureStatePresentationTests.swift`
- Test: `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift` (`testBundledPackageMatchesAppVersionAndCanonicalDigest`)
- Test: `ReleaseRadarTests/AppRouteTests.swift` (`testPluginLaunchUpdateRunsOnceAndSuppressedLaunchNeverCallsHelper`)

**Boundary:** Codex alone writes owner-authorized repository documentation.
Release Radar continues to validate, persist, and audit only the existing typed
MCP mutations. Do not add an MCP operation or read API, app repository-write
authority, lifecycle-helper authority, live observer, HTTP, polling,
synchronization/reconciliation framework, route/mockup, or multi-user flow.
For guidance-only work, Codex refuses symlink/non-regular instruction or ledger
paths, writes and reads back only the managed block plus an absent-only truthful
pending-audit ledger, then records the written `AGENTS.md` using the existing
ticketless `release_radar_add_evidence` mutation. It never uses `upsert_phase`
merely to obtain a handoff audit. `appUnavailable` preserves the repo-ahead
pending state and asks the owner to open Release Radar; `outcomeUnknown` replays
the complete original request verbatim, including the same evidence ID and UUID
`requestID`, using the existing idempotent receipt. A post-audit ledger failure
is repaired without another mutation. The existing post-mutation reload then
observes the already-written guidance.
The active correction changes the shipped app and plugin version together from
`0.1.2` to `0.1.3`; it uses the existing clean-managed automatic update at launch or
the existing explicit Update action as the only live installation path. It does
not add a same-version overwrite, updater, lifecycle operation, or CLI/config
path.

- [ ] **Step 1: Write focused RED acceptance tests**

Require `CodexPromptHandoff.prompt` and the packaged skill to operate in the
current repository-rooted task, invoke `$release-radar:release-radar` exactly,
and never create or delegate another task. For an
owner-authorized initialization, update, or repair, require preservation of all
unrelated `AGENTS.md` content, safe management of the exact versioned Release
Radar block, and creation of `docs/delivery/progress.md` only when absent; require direct
repository readback plus a successful audited ticketless evidence result, and
require discrepancy reporting instead of an invented MCP API. Require the
packaged skill to fail closed on symlink/non-regular targets, persist/read back
guidance before evidence, preserve a pending audit on `appUnavailable`, and
replay the complete identical evidence request after `outcomeUnknown`; forbid
guidance-only `upsert_phase` and require ledger repair without a second
mutation. In
`FailureStatePresentationTests`, require unavailable observation
copy to say **Codex desktop observation unavailable** and reject **Codex
unavailable**. Require both ReleaseRadar `MARKETING_VERSION` configurations and
the plugin manifest to be `0.1.3`, update only the established bundled-package
digest expectation, and prove the existing clean managed `0.1.2` to shipped
`0.1.3` launch-update case (or existing Update action) reaches the existing
verified update path. Run the focused suites and observe RED.

- [ ] **Step 2: Implement the minimum copied prompt, skill, and copy correction**

Change only the installed plugin skill, copied onboarding prompt, read-only
guidance inspector/presentation, and shared unavailable-observation presentation
needed by the RED assertions. The skill must preserve existing instructions,
manage only its exact versioned block, create the truthful pending ledger only
when absent and the owner explicitly asks, write/read back before the exact
ticketless evidence mutation, and use no delivery-state mutation for the
guidance-only handoff. It reports unpaired readback/audit results. Keep the app and lifecycle
helper without repository-write authority. Change the two ReleaseRadar
`MARKETING_VERSION` values and the plugin manifest version together to `0.1.3`;
then recompute only the established bundled package-digest expectation. Preserve
all lifecycle semantics, including clean-managed-only automatic update, the
existing explicit Update action, repo-ahead `appUnavailable` handling,
`outcomeUnknown` complete-request replay, idempotent request receipts, and
post-audit ledger repair without a distinct mutation.

- [ ] **Step 3: Run focused GREEN and package checks**

Run the same focused suites with a fresh temporary DerivedData path. Verify the
packaged three-file plugin inventory/digest assertions still pass and that no
new MCP schema, operation, or protected runtime mutation surface was added.

- [ ] **Step 4: Perform the live owner handoff proof**

Build, sign, and install the bounded correction. In one Codex task the owner
already rooted at an authorized repository, copy the app prompt and invoke the
installed skill in that same task. Request initialization: it writes and reads back applicable
guidance and the absent-only pending ledger, sends ticketless evidence for the
actual `AGENTS.md`, records the returned audit ID, and reaches the scoped
current-guidance state through the existing refresh. Confirm `appUnavailable`
preserves the pending repository handoff and directs the owner to open the app;
confirm `outcomeUnknown` replays the complete identical request after
availability; confirm a post-audit ledger failure is repaired without a second
mutation. Confirm Settings
reports unavailable **desktop observation**, not unavailable Codex.
Starting from the clean managed `0.1.2` plugin, install the signed `0.1.3`
application through the existing clean-managed launch update or the existing
Update action, verify the `0.1.3` postcondition and digest, then run the handoff
in that same already-rooted task. Do not add a new installation/update path.

- [ ] **Step 5: Independent acceptance and ledger evidence**

Fresh Code Review, QA/Test, Architecture, Security/Privacy, TPM, and Delivery
Management independently review this correction. Record focused RED/GREEN,
package/signing, current-task readback/audit proof, Settings observation copy,
scope confirmation, and the next eligible work in `docs/delivery/progress.md`.

### 2026-08-29 live-acceptance amendment

Before Step 4 can pass, correct the false-current state exposed by Rekon
Pursuit. Release Radar must require the exact managed block plus its existing
ticketless handoff evidence record, show **handoff incomplete** with a copied
repair prompt when only the block exists, and let the installed skill complete
that evidence mutation without rewriting an already-matching file. Ship the
coordinated correction as `0.1.4` from clean managed `0.1.3`, then repeat only
the focused tests, install checks, and the same Rekon Pursuit live handoff. No
new operation, schema, service, watcher, or reconciler is part of this amendment.
