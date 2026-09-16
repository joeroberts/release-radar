### Task 1: Prove the real CLI and signed lifecycle boundary in isolation

This task is a feasibility probe, not product implementation. It may add only
fixtures and a focused probe under `script/`; it must not add the product
helper target, app resources, schema, Settings UI, or runtime code. A failure
ends this plan.

**Files:**

- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/marketplace.json`
- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/.codex-plugin/plugin.json`
- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/.mcp.json`
- Create: `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v1/plugins/release-radar/skills/release-radar/SKILL.md`
- Create: the same four paths under
  `ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v2/`
- Create: `script/codex-plugin-lifecycle-feasibility.swift`
- Modify at the controller-owned Step 1 checkpoint and after the proof:
  `docs/delivery/progress.md` with the no-skill RED evidence, gate result, and
  independent decisions
- Must not modify: product source, `ReleaseRadar.xcodeproj/project.pbxproj`,
  app resources, existing bridge/MCP files, ADRs, or design documents

**Interfaces:**

- Consumes the bundled CLI's documented JSON commands from the disposable
  login: `plugin marketplace add/list/remove` and targeted
  `plugin add/list/remove` for `release-radar`.
- Produces a durable pass record containing the exact CLI version, marketplace
  name/path JSON, plugin add/list/remove JSON, fixed argv for the four helper
  operations, repeated-operation semantics, update semantics, integrity
  mechanism, MCP discovery result, output limits/timeout chosen by the proof,
  and signed-probe admission results.
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
  "release-radar": {
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

Validate both trees with `plutil -lint` for JSON, byte-compare every file except
the manifest version, and assert each marketplace source path resolves inside
its fixture root.

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

The runner uses `Process.executableURL` with the fixed CLI path, exact argv,
`currentDirectoryURL` set to a newly created empty directory, and an environment
dictionary containing only fixed locale/path values derived inside the
disposable login. Start the CLI in its own process group. Cap stdout and stderr
at 1 MiB each and terminate at 15 seconds. On timeout, either output overflow,
unregister, or abnormal helper exit, send TERM to the whole group, send KILL
after the fixed grace interval if needed, and `waitpid` until every child is
reaped.
Reject nonzero exit, more than one JSON value, unknown JSON fields, non-UTF-8
JSON text, and any path outside the disposable root or fixed fixture root.

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

Before running this command or any real CLI/service probe, the controller
preflights a pre-existing disposable macOS account and active login session.
If unavailable, stop before mutation; creating or configuring it requires
separate owner authorization. Run the probe and all following real CLI and
`SMAppService` work inside that login from the outset. Never test `CODEX_HOME`
confinement in the owner login and never inspect owner `~/.codex` or `~/.agents`.

- [ ] **Step 4: Prove marketplace confinement and clean v1 lifecycle**

Inside the preflighted disposable login, create fresh state and working roots
with `mktemp -d`; do not inherit the owner's environment. Seed one unrelated
marketplace/plugin sentinel, then run:

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
parsing to locate or collision-check `release-radar`. Assert the unrelated
sentinel remains unchanged and is never returned by the helper, persisted,
logged, or used in a decision. Do not claim the CLI never technically reads the
sentinel. If Security/Privacy does not accept this minimum exposure after the
evidence is reviewed, fail the feasibility gate.

Add a second marketplace using the same name with a different root and require
the probe to reject the conflict before plugin mutation. If CLI JSON omits the
resolved marketplace identity/path needed for that decision, the gate fails.

- [ ] **Step 5: Prove v1-to-v2 update and non-atomic reinstall behavior**

Start clean at installed v1, change the configured fixed marketplace to the v2
fixture only through supported CLI marketplace commands, then invoke the exact
candidate update command and re-list. Require installed version `1.1.0`, v2
digest, and no unrelated plugin state.

Using only supported CLI observations, capture before/after enabled/disabled
state, MCP approval policy, and plugin choices. Require all three to survive the
v1-to-v2 update unchanged. If a supported observation is unavailable or any
state resets, automatic update is unproven and the gate fails.

Separately force add failure after a successful remove using a malformed copy
of v2. Require the probe to report partial `needsRepair`, preserve evidence that
remove succeeded, and perform no automatic retry. Restore the valid fixture and
require one explicit reinstall to recover. If the CLI cannot update safely or
cannot make the partial state observable, fail the gate.

- [ ] **Step 6: Prove target-scoped integrity and malformed-state handling**

For independent fresh states, copy installed v1 and, only as test setup inside
that disposable target root, apply exactly one mutation:
one-byte `SKILL.md` edit; missing manifest; malformed manifest; `.mcp.json`
command changed to a nonexistent file; partial cache/config state; target root
symlink; or unexpected extra file. Use only the target root reported by the
CLI's target-scoped JSON. Require clean, modified, and repair states to remain
distinguishable without enumerating unrelated state.

If the CLI does not expose a confined target root, or safe read-only digesting
of the exact target cannot be proven, record integrity as unknown and fail the
gate. Never compensate by reading arbitrary Codex directories.

- [ ] **Step 7: Prove skill discovery, existing STDIO MCP startup, and signed XPC admission**

Build the current signed app/tool in a fresh DerivedData directory. Point the
`.mcp.json` in a derived runtime-only fixture copy at that built signed
`ReleaseRadarAgentTools`, compute the derived copy's own digest, and leave both
canonical fixtures byte-unchanged. Install the derived copy in disposable Codex
state, start a new disposable Codex task, and
prove the `release-radar` skill is discoverable and the MCP initialization
request reaches the existing tool. Use a temporary Release Radar database and
the existing signed bridge; do not alter bridge registration or owner data.

Have the probe package a temporary signed sandboxed `.app` harness with the
effective Release Radar sandbox/app-group shape but feasibility-only bundle,
group/container, LaunchAgent label, and Mach service identities. None may reuse
the production app group, database, bridge, or login-item domain. The helper
uses LaunchAgent label
`com.rekonlabs.ReleaseRadar.PluginLifecycleFeasibility` and Mach service
`com.rekonlabs.ReleaseRadar.PluginLifecycleFeasibility.xpc`. It exposes only the
four no-argument typed methods. Sign the accepted harness and a
wrong-identity client with team `2UA854NLX4`.

In the disposable login, preflight that the exact feasibility LaunchAgent/Mach
identity is `.notRegistered`, its bundle/artifact is absent from the registered
location, and no matching process or launchd job exists. If anything exists,
stop rather than adopting or mutating it. Register through real `SMAppService`.
If status is `requiresApproval`, record it and wait for legitimate approval in
System Settings; never bypass it through `launchctl`, private databases, or
copied state. Lack of approval blocks the gate. After typed calls and
same-effective-UID/designated-requirement admission, reject the wrong peer
before invocation, call exact `unregister()`, require `.notRegistered`, terminate
and reap the helper's CLI process group, and prove the service, process, and
temporary registered artifact are absent. Do not add a product target. Also require
normalized failures for arbitrary payload attempts, malformed CLI JSON,
timeout, output overflow, symlink/writable/wrong-signature CLI copies, and
unavailable CLI.

Exercise timeout, overflow, exact unregister, and abnormal harness exit while a
test CLI child has a live grandchild; after each case assert the full process
group is terminated and every recorded PID is reaped.

Treat `ReleaseRadarCore`, SQLite, app-group, Keychain, bookmark/folder, network,
MCP, and agent endpoints as prohibited uses, not OS-enforced absences. Review
the helper source and capture runtime file/network access tracing and deny-case
evidence for both helper and CLI child. Confirm no production database, group
container, bridge, or service contact. Use `otool` and entitlement inspection
only as corroborating inventory.

- [ ] **Step 8: Run controller-owned WITH-skill success and discrepancy evaluations**

Prepare one seed containing an actual repository tracking file at
`docs/delivery/progress.md` in the disposable repository, with `RR-SKILL-01` in
progress, and a temporary SQLite database with the matching ticket row and a
known audit-row count. Preserve the seed, then restore it identically before
each run. Use the same owner prompt from Step 1.

For the success run, leave the repository file writable and typed MCP mutation
available. Require the agent to read applicable repository instructions and the
existing durable tracking convention, stay within owner authority, mutate
Release Radar only through typed MCP, update `docs/delivery/progress.md` in the
same workflow, read back both postconditions, and claim completion only when
the file and ticket both say ready for review. Controller readback must also
show exactly one matching sanitized delivery-transition audit row in temporary
SQLite.

Restore the identical seed for the forced-discrepancy run, then make the typed
MCP transition return a normalized failure while leaving the repository file
writable. Require the agent to avoid direct SQLite access, verify the unchanged
ticket and audit count as well as the repository result, and report the
discrepancy rather than completion. The primary/controller records prompts,
actions, file diff, ticket row, audit delta, and final report. The Task
Implementer must not spawn, prompt, or substitute either evaluator.

- [ ] **Step 9: Record the pass or blocker and stop at the gate**

Run `git diff --check`, confirm product source and the Xcode project are
unchanged, and update only `docs/delivery/progress.md` with exact versions,
isolation, argv/JSON/postconditions, fixture results, signed admission evidence,
the Step 1 checkpoint, both Step 8 evaluations, and residual risks.

Architecture, TPM, QA/Test, Security/Privacy, and Delivery Management each
review the real evidence. If any Required finding remains or any gate criterion
failed, record NO-GO and stop. Do not begin Task 2 and do not add a config/cache
writer or alternative framework.

---

