# ADR-002: Codex plugin lifecycle boundary

- Status: Accepted
- Date: 2026-08-27

## Context

Release Radar must ship and version a local Codex plugin and let the owner
install, update, remove, detect modification, and reinstall it from the macOS
application. A clean managed installation must update with the application,
while a never-installed, removed, or modified installation must not be silently
installed or overwritten.

Codex owns plugin configuration and installed cache state under the owner's
Codex home. Release Radar remains sandboxed, and sandbox extensions granted to
the running app are not inherited by a child process. Directly editing Codex
configuration or cache would create an unsupported competing owner.

## Decision

Release Radar will ship a canonical local marketplace and `release-radar`
plugin as signed application resources. Codex remains the owner of installed
plugin state, enablement, approval, and permissions.

Release Radar may register one separately signed, same-user lifecycle helper.
The helper remains inside App Sandbox and invokes the verified ChatGPT-bundled
Codex CLI only for the fixed Release Radar plugin. Its private typed XPC
interface contains exactly `status`, `install`, `remove`, and `reinstall`. It
accepts no arbitrary command, path, identity, source, arguments, or
environment.

The helper has no app-group, Keychain, folder-bookmark, network, SQLite, MCP,
STDIO, URL, or agent-facing authority and does not link `ReleaseRadarCore`. It
authenticates the same-user Release Radar caller, directly invokes only the
fixed verified Codex executable with fixed arguments and a sanitized
environment, strictly parses bounded results, and fails closed.

### 2026-08-28 implementation amendment

Live signed-app testing established that macOS rejects a sandboxed application
registering an unsandboxed `SMAppService` login-item helper. The production
helper therefore remains sandboxed. The owner approved the minimum local,
single-user exceptions needed by the installed Codex CLI: read-write access to
`~/.codex/`; read-only access to
`~/.cache/codex-runtimes/codex-primary-runtime/plugins/openai-primary-runtime/`
and `~/Documents/dev/joeroberts/ai-tools/integrations/codex/`; read-only access
to `/private/var/empty/`; and Mach lookup of `com.apple.security.syspolicy`.
The two marketplace roots are required because this installed CLI reads every
configured marketplace even when Release Radar issues a targeted marketplace
or plugin command. The helper still has no network, database, project-wide,
Keychain, credential, bookmark, or app-group access, and `~/.codex/` remains
its only writable filesystem area. A request for any additional unrelated root
requires a new owner decision.

`SMAppService` may launch the helper with a relative `argv[0]`. The helper uses
`_NSGetExecutablePath` to locate its own signed bundle and derive the bundled
marketplace root instead of interpreting that relative argument as a path.
This amendment changes only the helper's minimum sandbox access needed for the
fixed CLI operations; the four-method XPC surface, exact-entry migration,
official-CLI ownership, and local-only runtime boundary are unchanged.

The plugin and marketplace retain the single canonical product identity
`release-radar`. The plugin-provided MCP server uses machine identifier
`release_radar`, which is required for Codex to form a callable tool namespace.
It is an internal identifier in the one plugin, not a second plugin or durable
product alias. A pre-existing owner-configured `release-radar` MCP entry is
eligible for one-time replacement only when
supported `codex mcp get release-radar --json` output proves that it is enabled
STDIO with no disabled reason, arguments, working directory, or non-empty
environment and its command is exactly
`/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`.
An absent entry is also allowed. Additional CLI fields are tolerated only when
they do not contradict the required semantics; malformed, duplicate, or
contradictory values fail closed. Any other same-name entry fails closed.

### 2026-08-28 repository-handoff clarification

The installed skill may direct an owner-authorized Codex task to preserve or
create applicable repository `AGENTS.md` guidance and the minimum durable
delivery ledger during requested initialization. Those are Codex repository
writes, not app or lifecycle-helper writes. The same task uses only existing
typed Release Radar MCP mutations for the corresponding delivery state; Release
Radar remains the sole SQLite writer and returns the mutation's audit result.
Completion reads repository files back and requires that successful audited MCP
result. This does not authorize an MCP repository-read operation, app-side
repository authority, a new MCP operation, observer transport, polling,
synchronization/reconciliation, HTTP, or multi-user behavior.

For Task 1's corrected composition proof, the exact recognized legacy entry
remains untouched. The proof first requires exact absence for bundled key
`release_radar`, then installs the derived plugin and requires one fresh task to
emit a machine-verifiable `mcp_tool_call` for that server; cleanup removes only
the temporary plugin and marketplace and re-verifies exact bundled-key absence.
Earlier accepted Task 1 evidence already proves exact legacy
removal, pinned absence, and restoration through supported CLI vectors. For the
product's first managed Install, the helper first accepts bundled key
`release_radar` as absent or as the exact enabled STDIO entry with no disabled
reason, the packaged AgentTools command, empty arguments, null working
directory, and empty or null environment fields. Contradictory fields fail
closed. It classifies both direct and legacy entries before mutation, then
immediately rereads and removes only that exact direct entry through the
supported CLI, verifies absence, and restores it
on a later failure only if this operation removed it and the key remains absent.
Changed or unrecognized direct state fails closed. The helper then retains the
operation-local initial absent or exact-legacy `release-radar` observation,
installs the managed plugin, and verifies
bundled server `release_radar`. An initially absent entry proceeds directly to
the final bundled-server postcondition. An initially exact legacy entry is
immediately reread and removed through the supported CLI only when the fresh
result still exactly matches, after which bundled server `release_radar` is
verified again. An absent or changed fresh legacy result avoids removal and
rolls back attempt-owned state without restoration. After the operation issues
removal, a later failure may restore the recognized entry. Only the final
bundled-server verification permits the app to persist `managedInstalled`.
Later lifecycle operations neither repeat the migration nor recreate the
legacy or direct entry.

Task 1 feasibility composes two existing Release Radar boundaries instead of
creating a second lifecycle service. The lifecycle lane uses only the verified
official Codex CLI and the accepted focused controller evidence. The runtime
lane reuses the packaged `ReleaseRadarAgentTools`, existing signed
`ReleaseRadarBridgeAgent`, existing typed bridge contracts, and a temporary
app-owned `DeliveryStore`.

Task 1 creates no lifecycle-helper target, feasibility Mach service, generated
harness application, alternate XPC protocol, process reconciler, or tracing
framework. The production lifecycle helper's `SMAppService` registration,
approval, authenticated four-method XPC surface, and cleanup remain blocking
Product Task 2 acceptance requirements after that helper exists; they are not
prerequisites for proving the v1 CLI and existing local runtime boundaries.

The official CLI is the sole mutation owner but does not expose installed
content integrity. For status only, production obtains the effective user's
home with `getpwuid_r(geteuid())`, never `$HOME`, and combines it with one strict
SemVer component from the targeted CLI version to construct only
`~/.codex/plugins/cache/release-radar/release-radar/<version>`. It walks fixed
components through descriptor-relative no-follow opens, verifies each file is
stable and regular across the complete read, and reads exactly the three
declared plugin files to compute the normalized digest. Only an internal test
seam accepts a derived home. It never writes Codex state, reads Codex
configuration, enumerates other plugins, or returns, logs, or persists a home
or cache path.

The app persists owner intent and verified lifecycle receipts through its
existing sole-writer store. It does not treat those receipts as Codex
configuration. Automatic update is permitted only for an intact, recognized,
previously managed installation. Never-installed, removed, absent, modified,
conflicted, or unknown state requires no automatic mutation. Modified content
requires an explicit confirmed Reinstall.

The accepted runtime delivery boundary is unchanged:

```text
Codex -> ReleaseRadarAgentTools -> signed XPC bridge
      -> Release Radar app -> app-owned SQLite
```

The lifecycle helper is not callable by Codex and cannot request or perform a
ticket transition.

## Feasibility condition

This decision authorizes the boundary but not an unproven implementation. A
signed, isolated feasibility gate must prove fixed local-marketplace behavior,
CLI install/update/remove postconditions, package-integrity observation, MCP
executable resolution, XPC admission, and fail-closed executable verification.
The proof may read and change owner Codex plugin state only through the
verified official CLI and only for the exact `release-radar` marketplace/plugin,
legacy `release-radar` MCP target, and bundled `release_radar` MCP target. Task 1
requires the plugin and marketplace to
start and end absent. Its MCP baseline may be absent or the exact recognized
legacy entry, while bundled key `release_radar` must start and end at the pinned
exact-absence tuple. Any present, malformed, or ambiguous bundled-key result
stops before mutation. The proof must restore the legacy baseline and preserve
unrelated state. The only direct Codex-state read is the
owner-authorized exact-root digest above; direct cache/configuration writes and
all unrelated configuration/cache reads remain prohibited. Product behavior
for an existing recognized managed install remains subject to the evidence
established within that absent-baseline lifecycle.

The remaining feasibility gate passes when a derived installed plugin resolves
to the freshly built packaged AgentTools, a fresh Codex task discovers the
installed skill and initializes its STDIO MCP server, and the existing signed
runtime lane commits one typed ticket transition with exactly one matching
request receipt and audit in a temporary app-owned database. The existing
wrong-tool acceptance case supplies negative peer-admission evidence.

Because public `SMAppService.agent(plistName:)` resolves relative to the calling
application bundle, the standalone controller makes no bridge-service status
claim; it verifies only that the normal Release Radar app is not running. The
existing Release Radar app-hosted acceptance test requires initial exact
`.notRegistered`, treats `.notFound` and every other state as a stop, registers
the bridge itself, records ownership only after successful registration, and
unregisters only that owned registration before requiring final
`.notRegistered`.

Every CLI or MCP process started by the proof uses a fixed executable and
arguments, bounded output, and a fixed deadline. The controller records the
exact directly owned PID and, when it creates a dedicated process group, the
exact PGID. On timeout or cancellation it revalidates ownership, sends TERM and
then KILL after a bounded grace period if necessary, and reaps the direct child.
It never enumerates, signals, or reconciles processes by shared path or same-user
identity.

If the bundled Codex CLI cannot support safe update or marketplace confinement,
or if exact-root read-only digesting cannot prove integrity, the implementation
remains blocked. Direct configuration/cache writes, broader cache reads, a
shell wrapper, HTTP, generic XPC execution, or an expanded agent bridge are not
acceptable fallbacks.

## Consequences

The application gains one narrow installation-management component and its
signing/package verification obligations. It does not gain general filesystem
or command execution authority. The plugin lifecycle and the runtime delivery
bridge remain separate trust boundaries.

The canonical product-name choice requires one narrowly recognized CLI
migration for existing installations and therefore a rollback path during
first Install. Codex's callable namespace constraint requires the internal
bundled-server identifier `release_radar`. In exchange, Release Radar exposes
one installed plugin and one callable tool surface instead of carrying a second
plugin/server alias such as `release-radar-plugin` indefinitely. No persisted
migration flag is needed: the existing lifecycle intent distinguishes the first
successful managed Install from later operations.

The detailed product, state, UX, security, and acceptance contract is
`docs/design/release-radar-codex-plugin-lifecycle-design.md`.

## Rejected alternatives

- User-mediated commands alone: safer, but they do not meet app-owned buttons
  and automatic clean-install updates.
- Main-app write access, direct Codex cache/configuration writes, or broader
  cache reads: unsupported ownership and sandbox boundary.
- Expanding the existing bridge, MCP server, or dispatcher: mixes plugin
  installation authority with delivery mutation authority.
- Naming the plugin or bundled server `release-radar-plugin`: creates a second
  durable product alias and makes discovery and troubleshooting ambiguous.
- Keeping `release-radar` as the bundled server key: the pinned Codex CLI lists
  it but cannot expose its tools because the hyphen cannot form a callable model
  tool namespace.
- A generalized legacy-entry migrator, persisted migration state, or periodic
  reconciliation: unnecessary for one exact supported-CLI replacement during
  first managed Install.
- HTTP, shell, generic command/XPC, root helper, periodic reconciliation, or a
  second SQLite writer: unnecessary and outside the approved product.
- A generated feasibility application, duplicate lifecycle helper, alternate
  Mach service, same-core test executable, synthetic runtime tracer, or custom
  process framework: duplicates established boundaries and makes the proof
  larger than the product behavior being evaluated.
