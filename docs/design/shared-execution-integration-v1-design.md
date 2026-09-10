# Shared Execution Integration v1

| Field | Value |
| --- | --- |
| Status | Source implementation authorized; design remains non-gating |
| Date | 2026-09-09 |
| Baseline inspected | `8930f9643ca1f46e7681ce9b838ce9b0f5b024fc` |
| Intended consumers | Release Radar, Rekon Pursuit, and separately adopted future repositories |
| Delivery effect | Local source candidate only; no installation, app-state, or consumer-adoption effect |

The owner authorized source implementation under this reviewed design. The local
source candidate still creates no installed behavior, application-state mutation,
runtime proof, or consumer adoption. This design defines a small shared execution
contract for repeatable Codex
delivery without turning Release Radar into an execution engine or copying another
large instruction manual into every repository. It remains non-gating design input,
not a completion gate or permission to change any consumer.

The design consumes the non-gating assessment in the
[full-product plan](../delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md#shared-execution-integration-assessment--proposed-non-gating--2026-09-08),
[ADR-001](../architecture/ADR-001-release-radar-boundaries.md),
[ADR-002](../architecture/ADR-002-codex-plugin-lifecycle.md),
[ADR-006](../architecture/ADR-006-managed-repository-documentation-contract.md),
and [ADR-007](../architecture/ADR-007-proportional-delivery-validation.md).
Phase 5 continues independently. Its placement, phase lifecycle, proposal,
successor, and carried-obligation contracts remain owned by Phase 5 and are
consumed through their accepted interfaces rather than restated here.

## 1. Outcome and limits

V1 has four outcomes:

1. A task receives only the context needed to understand its outcome, authority,
   scope, delivery endpoint, direct checks, and required independent review.
2. Existing repository-native tools produce direct results with honest source and
   applicability information. The first shared check is the existing
   `ReleaseRadarDocumentationTool`; V1 does not execute arbitrary recipes.
3. Release Radar diagnoses the installed shared-standard capability and a
   repository's declared technical compatibility, then presents owner-mediated
   adoption or recovery choices. Diagnosis never establishes a committed or
   owner-approved adoption and never installs, upgrades, trusts, grants, accepts, or
   executes.
4. Consumer repositories keep their product, architecture, privacy, recovery,
   acceptance, and ledger authority. Shared clauses replace local duplication only
   through an exact, separately approved patch.

V1 does **not** provide:

- a task runner, shell wrapper, general command manifest, CI replacement, or second
  delivery database;
- formal completion or check attestations, verified reviewer identity, run identity,
  reviewer scheduling, or automatic acceptance;
- hooks, command rules, transcript parsing, Stop continuation, automatic commits,
  publication, notification, or any other automatic action;
- Run Guard, role execution, provider admission, process ownership, or cancellation;
- new Phase 5 domain fields or meanings; or
- ADR-006 guidance v3, which remains reserved for Issue #1/P10.

### Baseline evidence

- The current [documentation-tool entry point](../../ReleaseRadarDocumentationTool/main.swift)
  exposes only `check`, `write`, and help. `check` is read-only and prints one
  success sentence; it does not report checker version, app build, catalog identity,
  or a structured result.
- The packaged [plugin manifest](../../ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json)
  is version `0.1.7` and currently points to the existing `release-radar` skill;
  there is no `shared-execution` skill in this baseline.
- The current [command envelope](../../ReleaseRadarCore/AgentBridge/AgentCommand.swift)
  carries an expected project registration, and the
  [dispatcher](../../ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift)
  validates current registration scope and stores request body/result with project,
  registration, and request generation. This resolves the older discovery's
  missing-registration premise; it does not create check or run attestation.
- `assertedThreadID` remains asserted attribution in that dispatcher. Current source
  therefore does not verify independent reviewer identity.
- The [rules/hooks discovery](../delivery/task-briefs/2026-09-07-parallel-discovery/rules-hooks-discovery.md)
  found no safe I9 pilot, and the
  [run-ownership discovery](../delivery/task-briefs/2026-09-07-parallel-discovery/run-ownership-discovery.md)
  made Run Guard only a conditional future feasibility path.

## 2. Choice and tradeoffs

### Selected: on-demand skill, thin local adoption, direct tools

Add one `shared-execution` skill to the existing signed Release Radar plugin. A
consumer adopts it with one short, versioned block in its own `AGENTS.md`. The skill
loads only when an authorized implementation or substantive review task invokes it.
It points back to the consumer's own controlling documents and tells the task how to
report direct results from tools the repository already owns.

This keeps shared mechanics in one versioned package while local outcomes and
exceptions stay local. It also reuses Release Radar's existing plugin integrity and
lifecycle boundary instead of creating a second installer or distribution channel.

### Rejected: copy a comprehensive shared policy into every repository

Copying the full operating model would make every task reread duplicated prose,
cause local variants to drift, and make supersession ambiguous. A short local block
is still necessary because only the repository owner can adopt the standard and
identify local authority.

### Rejected: a general recipe executor or attestation service

A recipe engine would need command authority, input validation, secrets handling,
timeouts, cancellation, process ownership, and a new versioned result protocol
before it could safely run arbitrary checks. That machinery is larger than the V1
problem. Existing tests, linters, Git, and the documentation checker remain direct
sources. Formal check attestations and verified reviewer identity stay in the
separate P10/P17/D13 or runtime scope.

### Deferred: Run Guard and hooks

Run Guard remains a conditional I7/I8 feasibility path. The I9 discovery is no-go
on the currently demonstrated hook/rule capability. Neither is needed to load a
small standard or run a read-only documentation check.

## 3. Authority and operation ownership

| Concern or operation | Sole source/owner | V1 treatment |
| --- | --- | --- |
| Product outcome and acceptance criteria | Consumer repository's controlling product/design documents | Referenced by stable artifact/path and exact source basis; never copied into the shared skill as authority. |
| Architecture, privacy, security, persistence, and recovery | Consumer repository's accepted architecture and security contracts | Always retained unless a later owner-approved local patch explicitly changes them. |
| Current work, authorization, blockers, and next eligible work | Consumer `docs/delivery/progress.md` or its named local equivalent | Remains the durable ledger. Catalogs and indexes do not infer this state. |
| Document identity, lifecycle, authority, and navigation | Repository `docs/catalog.json` plus actual documents | Catalog metadata identifies and navigates content; it does not approve mutable prose or delivery state. |
| Repository document validation | The invoked `ReleaseRadarDocumentationTool` process | Its exit/result proves only the catalog, files, links, checksums, and generated indexes it actually read at that time. |
| Source revision and working-tree state | The repository's own Git commands, when Git is present | Reported separately from checker output. A dirty result applies to the working tree, not silently to `HEAD`. |
| Product tests, lint, format, and build checks | Existing repository-native commands selected by the task brief or local instructions | V1 reports their direct results; it does not choose or execute a universal recipe. |
| Release Radar delivery mutations and accepted documentation snapshot | Release Radar app through existing typed, audited operations | Exact root, project registration, request generation, and request replay rules remain mandatory. A check does not mutate or accept. |
| Plugin package and installed plugin intent/integrity | Release Radar's existing fixed plugin package/lifecycle boundary; Codex owns its installed state | V1 consumes status. Install, update, remove, and reinstall remain explicit owner actions under ADR-002. |
| Plugin availability, connections, trust, and runtime permissions | Codex and the owner | Release Radar cannot infer or grant them. Official OpenAI documentation treats plugin installation and each bundled capability's permissions as separate controls. |
| Task scope, side effects, and external actions | Owner authorization plus applicable repository instructions | The skill cannot enlarge them. Missing authority produces a blocker or diagnostic, not an automatic request. |
| Independent material review | Consumer delivery policy and separately assigned reviewer | V1 carries the requirement and candidate identity only. A role/thread assertion is not trusted attestation. |
| Product acceptance | Owner and the consumer's durable acceptance record | Never inferred from a pass, commit, review message, catalog digest, or command receipt. |

The official [Plugins documentation](https://learn.chatgpt.com/docs/plugins)
describes plugins as packages that may contain skills, MCP servers, and hooks, and
requires a new session after installation before bundled capabilities are used. The
official [Skill controls documentation](https://learn.chatgpt.com/docs/enterprise/skills)
states that filesystem skills, workspace skills, and plugin skills have distinct
lifecycle and access controls, and that plugin installation does not grant its
connectors or MCP servers access. These are documentary compatibility constraints,
not runtime proof for any installed client.

## 4. Shared standard clauses

The plugin skill declares `shared-execution-standard: 1` and implements exactly
these behavioral clauses. Clause IDs are stable within V1 so a consumer can state
what replaces local duplication without copying all prose.

### SEI-1 — Local authority wins

Read the repository catalog/index and only the task-relevant controlling artifacts.
The task's explicit owner authorization, local product/architecture contracts, and
local delivery ledger remain authoritative. The shared standard cannot expand
scope, change sequencing, accept work, or supersede a local clause by implication.

### SEI-2 — Minimum context only

Carry the eight required fields in section 6 and only the conditional fields that
apply. Link to controlling material instead of copying it. Load a referenced body
only when needed for a decision or implementation. Do not include closed delivery
history, reviewer transcripts, exhaustive inventories, or other evidence merely to
prove that a process happened.

### SEI-3 — Exact root and source basis

Resolve the current task root exactly. Do not substitute a parent, child, similarly
named folder, or path prefix. Record the Git `HEAD` and scoped working-tree state
when available. `clean` supports exact-revision applicability; `dirty` identifies a
working-tree result; inability to establish either is `unknown`. This provenance
does not create generic product revision semantics.

### SEI-4 — Existing checks first

Use the checks already owned by repository configuration, instructions, or the
bounded task brief. In a managed Release Radar documentation tree, invoke the
existing documentation checker with the exact authorized root. V1 never invents a
general recipe executor, substitutes compilation for a behavioral check, or runs an
unrelated suite to manufacture confidence.

### SEI-5 — Honest direct results

For each applicable check, report its actual runner identity/version when available,
exact scope, source basis, and one status from section 8. Mark absent evidence as
`unknown` or `unavailable`; do not convert it to `passed`. An agent summary is a
transcription of direct evidence, not a trusted attestation.

### SEI-6 — Typed mutation boundary

Any Release Radar mutation uses the existing exact project root, current project
registration ID and request generation, bounded canonical command body, and stable
request ID. Reuse with a changed body rejects. An uncertain result is reconciled by
supported readback or exact replay of the same request. Existing receipts prove
canonical replay scope; they are not check, run, review, or completion attestations.

### SEI-7 — Proportional independent review

Material implementation keeps one suitable independent reviewer other than the
implementer, with specialist review added only for a named risk. Reviewers classify
findings as Required, Optional, or Out of scope. Only Required findings block. V1
does not verify reviewer identity or make an asserted task ID authoritative.

### SEI-8 — Owner acceptance and external effects remain explicit

A check, review, commit, catalog digest, plugin receipt, or task completion does not
imply owner acceptance, push, merge, installation, trust, permission, catalog
acceptance, application mutation, notification, or publication. Each consequential
external or owner-state action retains its existing explicit authorization.

### SEI-9 — Fail honest and recover forward

Stale, missing, inaccessible, incompatible, interrupted, or uncertain states remain
visible. Preserve original content, receipts, IDs, and history. Do not bypass trust,
weaken permissions, regenerate request identity, silently retry an uncertain
mutation, or rewrite history to make a diagnostic green.

### SEI-10 — Completion stops the process

When the authorized outcome, direct checks, required independent review, and
authorized endpoint are complete, stop. Optional suggestions do not create new
scope, another review layer, or a validation-of-validation loop.

## 5. Exact consumer adoption block

The following is the complete V1 block proposed for a consumer's root `AGENTS.md`.
It is separate from `release-radar-guidance:v2` and does not consume guidance v3.

```markdown
<!-- release-radar-shared-execution:v1:start -->
## Shared execution integration

For authorized implementation or substantive review work, invoke the installed
`$release-radar:shared-execution` skill and apply shared-execution standard v1.
This repository's explicit owner authorization, controlling product and architecture
documents, and delivery ledger remain authoritative. The shared standard supplies
bounded context, repository-native check reporting, and compatibility diagnostics
only; it cannot grant authority, accept work, identify an independent reviewer,
change delivery state, or trigger installation, trust, permissions, publication,
or any other action. If the skill is missing, modified, incompatible, or unavailable,
report that state and use only this repository's own governing instructions. The
repository must independently retain its requirements for material independent
review, explicit owner acceptance and external effects, and material safety and
recovery. If those local fallbacks do not cover every removed required clause, stop
the affected material work; unrelated read-only and product work may continue under
the local instructions.
<!-- release-radar-shared-execution:end -->
```

Adoption never silently replaces existing instructions. The preview for each
consumer must include one ordinary Git diff that shows:

- this exact block;
- each exact local clause removed or shortened;
- the replacement SEI clause IDs;
- every local product outcome and stricter local rule retained;
- independent local fallback clauses, outside the shared skill, covering material
  independent review, explicit owner acceptance and external effects, and material
  security, safety, and recovery for every removed required clause; and
- any local rule intentionally stricter than V1.

The owner approves that exact patch. The consumer's normal Git history and delivery
ledger record the adopted standard version and commit. No checksum, second
supersession manifest, or Release Radar database field is added merely to restate
the diff. An adoption preview lacking any required local fallback is incompatible;
the affected material work stops rather than depending on a missing or untrusted
skill. Unrelated read-only and product work may continue under the remaining local
authority.

### Pursuit candidate boundary

No Pursuit edit is authorized by this design. A later exact owner-approved patch
must retain, at minimum:

- complete product outcomes and the UI completion floor of persistence,
  activity/audit evidence, non-happy-path behavior, and acceptance tests;
- independent material review and applicable privacy, security, transaction,
  rollback, and recovery coverage;
- explicit owner acceptance before dependent successors when its governing
  handoff requires that acceptance;
- `docs/product/prd.md`, `docs/product/ux-design-review.md`, accepted mockups,
  architecture/ADR material, `docs/delivery/progress.md`, and
  `docs/delivery/roadmap.md` in their existing authority roles;
- catalog/navigation versus content/delivery authority and Release Radar's
  exclusive SQLite ownership; and
- Pursuit's current delivery hold until the Pursuit owner separately changes it.

V1 may replace only duplicated execution ceremony explicitly shown in that future
patch. Adoption does not repair Pursuit product defects or authorize feature work.

### Perspective candidate boundary

No Perspective root is established. Prior supplied evidence identifies both
`/Users/jroberts/Documents/perspective` and
`/Users/jroberts/Documents/ChatGPT/Perspective`; neither may be selected by
inference. V1 diagnosis reports `rootUnknown`. No inspection, bootstrap, adoption,
or write is eligible until the owner confirms one exact canonical root.

## 6. Minimum task context payload

The shared skill asks for these eight fields. A task prompt can express them in
plain text; V1 does not require another persisted manifest.

| Required field | Minimum content |
| --- | --- |
| Standard | `shared-execution/1` and the observed plugin/skill compatibility state |
| Root | One exact absolute task root, or `unknown` before any repository action |
| Outcome | One complete owner-requested outcome in one or two sentences |
| Scope | Owned paths/systems plus explicit exclusions and non-gating dependencies |
| Authority | Only task-relevant controlling artifact IDs/paths and their source basis |
| Endpoint | Local edit/commit, PR, merge, install, or other endpoint actually authorized; all others excluded |
| Direct checks | Repository-owned commands/properties and the behavior each must establish |
| Review | Whether independent review is required, candidate identity, and named risks it covers |

Add these fields only when applicable:

- Release Radar project ID, registration ID, and request generation for an existing
  typed mutation;
- catalog repository ID/version/digest and accepted/pending state for managed
  documentation work;
- exact prior request ID/body for uncertain typed-operation replay;
- a destructive, owner-data, credential, permission, installation, or external
  side effect and its explicit authorization; and
- consumer-specific migration, compatibility, or recovery obligations.

Do not copy Phase 5 placement, lifecycle, proposal, successor, goal-coverage, or
future domain schemas into this payload. Link the owning accepted contract and pass
only the exact domain IDs/fields required by its existing typed operation.

## 7. Documentation checker contract

### Existing invocation and meaning

The current executable contract remains backward compatible:

```sh
ReleaseRadarDocumentationTool check --root "/absolute/authorized/repository"
```

Current source and the shipped catalog-v1 reference define these outcomes:

| Direct process result | V1 interpretation |
| --- | --- |
| Exit `0` and `Repository documentation indexes match the catalog.` | `passed` for catalog/files/links/checksums/index agreement at the checked root and read interval |
| Exit `1` with a bounded `RepositoryDocumentError` or `RepositoryDocumentIndexError` | `failed` with that validation or I/O category |
| Exit `64` and usage text | `failed` because the invocation is invalid |
| No executable, no execute access, or incompatible platform | `unavailable` |
| Interrupted process or lost final result | `unknown`; a fresh read-only check may be run, but the prior result is not invented |
| Repository has no applicable managed-documentation contract and the task does not require bootstrap | `skipped` with the local reason; the tool is not run merely to produce a status |

A pass does not prove that mutable document prose is approved, that `HEAD` was
tested, that the working tree was clean, that the app accepted the catalog, or that
delivery state is correct. `write` remains a separate explicitly authorized
repository mutation and is never part of a check fallback.

### Small additive diagnostic for later implementation

The current tool exposes catalog-v1 compatibility in `--help`, but it does not emit
an explicit checker contract, tool version/build, catalog identity/digest, or
machine-readable result. V1 proposes one additive read-only command in the **same**
fixed-purpose executable:

```sh
ReleaseRadarDocumentationTool diagnose --root "/absolute/authorized/repository" --format json
```

It returns one bounded object:

```json
{
  "format": "com.rekonlabs.release-radar.documentation-check-result",
  "schemaVersion": 1,
  "checker": {
    "contractVersion": 1,
    "toolVersion": null,
    "toolBuild": null,
    "supportedCatalogVersions": [1]
  },
  "target": {
    "repositoryID": null,
    "catalogVersion": 1,
    "catalogDigest": null
  },
  "status": "passed",
  "error": null
}
```

Strings replace the example null tool version/build and target values only when the
running executable can establish them directly. On validation failure it still
emits the same shape with `failed` and one existing bounded error category, then
exits `1`. Unsupported result format or arguments exit `64`. Failure before a safe
catalog identity is established leaves target values null. It must not emit
document content, credentials, bookmark bytes, owner data, or unsafe paths. It uses
the existing no-follow reader and check implementation; it does not call Git, run
another command, write files, bind a repository, accept a catalog, or change
delivery state.

Existing `check`, `write`, `--help`, output strings, and exit meanings stay
unchanged. Consumers without `diagnose` fall back to `check` and report unavailable
identity fields as `unknown`; lack of the new diagnostic does not turn a real pass
into an attestation or block unrelated product work.

## 8. Direct result model

Every task final report uses one row per check. This is a reporting contract, not a
signed or persisted attestation.

| Field | Meaning |
| --- | --- |
| Check | Stable local name, such as `documentation`, `focused-store-tests`, or `git-diff-check` |
| Runner | Actual executable/tool name and observed version; `unknown` when the tool provides none |
| Scope | Exact root plus files, target, test selector, or property actually exercised |
| Source | Git `HEAD` and `clean`, `dirty`, or `unknown`; non-Git source is identified honestly |
| Applicability | `exactRevision`, `workingTree`, or `unknown` |
| Status | Exactly one of the six values below |
| Direct result | Exit/result identifier and concise output; a log/artifact link only when already required and durable |
| Limitation | Material gap only; omit when none |

Statuses are exhaustive:

- `passed`: the direct runner completed and the expected property passed;
- `failed`: the runner completed and reported failure, including an invalid command;
- `skipped`: the check was intentionally not run because it was inapplicable or
  explicitly excluded, with a reason;
- `unavailable`: the runner, access, dependency, or compatible version was absent;
- `unknown`: execution or result was interrupted, lost, ambiguous, or could not be
  attributed to the stated source; and
- `notRun`: applicable work remains and no attempt occurred. `notRun` is visible but
  is never represented as success.

`passed`, `failed`, `skipped`, and `unavailable` describe a completed diagnostic
decision. `unknown` requires readback or a safe fresh check when the task still
needs that evidence. A mutable or side-effecting operation with unknown outcome
uses its own exact replay/recovery contract instead of an automatic rerun.

## 9. Version and adoption diagnostics

### One package-capability source

V1 uses one app-owned immutable `RecognizedPluginCapability` list as the sole
package-to-standard source. Each row contains an exact plugin manifest version,
the exact normalized package digest already produced by the package-integrity
boundary, and the sorted shared-execution standard versions that package supports.
Package validation requires the currently shipped package to match exactly one row.
Selected older packages are compatible only when their exact version/digest row is
retained. Duplicate rows, a known version with a different digest, a digest with a
different version, and an otherwise unrecognized combination support no standard.

The app exposes the matched version, digest-match state, and supported-standard list
read-only to the compatibility reducer. It never infers capability from SemVer
ordering, a version string alone, a receipt alone, or skill text read from a modified
installation. The current `0.1.7` baseline package supports no shared-execution
standard because it contains no such skill; when the list is introduced, any row
retained for exact `0.1.7` backward diagnosis therefore has an empty supported-
standard set. The first package that adds V1 must add and package-validate its own
new exact row. This list is source code/package contract, not an adoption database or
a new installed-state owner.

Release Radar computes, but does not authorize, one **technical compatibility**
diagnostic from four independent observations:

1. **Declared standard:** exact local adoption marker/version and whether its body
   matches the supported block.
2. **Installed package:** existing plugin lifecycle status plus an exact match in
   `RecognizedPluginCapability`. A modified, never-installed, or unrecognized
   version/digest combination is not treated as V1.
3. **Checker capability:** `diagnose` contract/result version when supported, or
   `unknown` for an older checker.
4. **Repository documentation:** actual catalog/guidance validation and, when the
   project is managed, existing binding/accepted-snapshot state.

The app diagnostic states are:

| State | Meaning and permitted response |
| --- | --- |
| `notDeclared` | No shared marker. Offer an exact preview only after owner requests adoption. |
| `compatibleV1` | Exact V1 block, clean recognized plugin proven to contain V1, compatible checker, and no required managed-documentation discrepancy. This does not establish that the block is committed, owner-approved, or accepted. |
| `compatibleOlder` | Exact older declaration supported by the installed package's retained exact capability row. Continue under that version; offer a separately authorized upgrade. |
| `updateAvailable` | The installed exact capability row supports the declaration and the shipped exact row supports a newer standard. No automatic repository edit. |
| `pendingCatalogAcceptance` | Repository files validate but the managed catalog snapshot is not accepted. Existing managed operations remain closed until explicit acceptance/readback. |
| `incompatible` | Declared standard is newer/unsupported, plugin is modified, or checker cannot satisfy a required repository contract. Disable standard-specific assistance and show the exact mismatch. |
| `unavailable` | Root, plugin status, checker, trust, permission, or catalog access is unavailable. Offer only the existing owner-controlled recovery. |
| `rootUnknown` | No exact canonical consumer root is established. Do not inspect, bootstrap, or adopt. |
| `unknown` | An observation was interrupted or cannot be attributed. Do not infer adoption or repeat a possibly mutating action. |

Official documentation says plugin installation takes effect for bundled skills and
tools in a new chat/session. Accordingly, a successful plugin lifecycle receipt does
not prove that the current task loaded the new standard. The task reports the loaded
skill version when visible; otherwise that field is `unknown` and a fresh task is the
supported recovery after installation.

Repository adoption progress is a separate task-side observation, not an app
diagnostic. An authorized adoption task may report `workingTreeCandidate`,
`committedCandidate`, `ledgerRecorded`, or `unknown` only from direct Git and local
ledger readback. Those labels describe the task's observed repository state; they
do not make Git an approval authority, and Release Radar does not compute or persist
them in V1. Explicit owner approval remains a distinct fact supplied through the
normal task and recorded under the consumer's existing policy.

No new Release Radar adoption table is required for V1. The exact repository diff,
normal Git commit, local delivery-ledger acceptance record, plugin lifecycle receipt,
and existing catalog binding/acceptance remain their respective sources. The app may
cache its technical compatibility diagnostic for presentation only if it preserves
source/timestamp and never becomes authority.

## 10. Adoption, upgrade, and recovery

Each repository is independent. Release Radar may prepare and display these steps,
but every mutation retains its existing owner and authorization.

### First adoption

1. Confirm the exact canonical repository root and inspect existing governing
   instructions, catalog/index, and current delivery ledger read-only.
2. Determine whether a clean recognized Release Radar plugin with V1 is installed.
   Missing installation or trust is diagnostic; do not change it during repository
   adoption without separate owner authorization.
3. Generate one exact Git diff containing the V1 block, local clause-by-clause
   supersession, catalog/index updates required by the consumer, and no unrelated
   changes.
4. Obtain explicit owner approval for that exact consumer patch.
5. Apply the repository patch with one writer, run the existing documentation check
   and consumer-native documentation checks, then commit at the authorized endpoint.
6. If the managed catalog changed, keep it pending until the owner separately
   authorizes the existing typed catalog-acceptance operation. Preserve the same
   request across an uncertain result and read back the binding afterward.
7. Record the adopted standard version and commit in the consumer's existing
   delivery ledger. Start a fresh Codex task before relying on newly installed plugin
   content.

### Compatible upgrade

An exact recognized plugin package may support more than one declared standard
version. Updating a clean recognized managed plugin can therefore precede repository
adoption without changing consumer behavior when both exact capability rows say so.
A repository moves from V1 to a future version only through another exact
owner-approved local diff. Newer SemVer alone never proves compatibility, and newer
package availability never rewrites a consumer block or supersedes local clauses
automatically.

If a future exact capability row removes V1 support, upgrade work must first identify
every consumer still declaring V1 and provide a recovery path. An older package is
supported only while its exact row is retained; an unknown version/digest combination
reports `incompatible` or `unknown`, never inferred backward compatibility. Do not
update a consumer and installed package as an unobservable distributed transaction.

### Interrupted or uncertain change

- **Plugin operation interrupted:** use existing lifecycle status and receipts to
  distinguish absent, clean installed, modified, update available, needs repair, or
  unknown. Do not edit Codex configuration/cache directly or invent success.
- **Repository write interrupted:** inspect the exact block, catalog, indexes, Git
  diff, and direct checker result. Preserve history; finish or revert with an
  owner-authorized forward commit rather than destructive reset.
- **Catalog files changed but acceptance did not:** report
  `pendingCatalogAcceptance`; do not silently use managed operations against the new
  digest.
- **Typed acceptance outcome unknown:** replay the complete original request with
  its existing request ID/body after availability returns, then use supported
  readback. Never generate a replacement request merely because the reply was lost.
- **Checker interrupted:** the check is read-only, so a fresh invocation is safe
  after confirming the same root and source state. The interrupted attempt remains
  `unknown`.
- **Access denied:** preserve repository/plugin state and offer the owning recovery
  surface. Permission denial never grants broader root access or trust.

### Archive, restore, removal, and re-add

- Project archive does not edit the consumer repository or uninstall the plugin.
  It suspends applicable project operations under the existing lifecycle contract;
  the repository's declared standard remains documentary state.
- Restore re-diagnoses exact root access, current registration, plugin integrity,
  standard compatibility, and catalog acceptance. It restores no trust, permission,
  or pending action automatically.
- Remove from tracking retains the existing read-only history/removal record and
  leaves repository files untouched. It removes the old operational registration
  and capabilities; the standard block alone cannot reactivate them.
- Re-adding the same folder creates a new registration and request generation.
  Old callbacks and receipts cannot mutate it. Adoption is re-diagnosed against the
  new registration and current files; no path or name match silently transfers
  authority.

## 11. Verification and pilot acceptance

The source slice and the runtime pilot are separate. Source verification uses only
synthetic repositories, stores, and fixtures. It does not inspect Pursuit or either
Perspective path, use owner data, launch the normal app, install a plugin, or enable
hooks. Actual selected-skill loading and task behavior require a later, separately
authorized fresh-task/runtime pilot; source fixtures cannot prove them.

### Static standard and context contracts

1. Package/source checks prove the shipped skill contains the exact V1 marker,
   adoption block, SEI clauses, local fallback language, and no hook, task-runner, or
   mutation declaration. They prove the normalized package digest matches exactly one
   `RecognizedPluginCapability` row whose supported standards are explicit.
2. Adoption-preview fixtures preserve local stricter clauses and the mandatory local
   fallbacks. Missing/unsupported skill inputs produce `incompatible` or
   `unavailable`; no preview removes a required local clause without independent
   local coverage.
3. Static checks verify the eight-field payload contract names only references to
   local controllers and excludes copied closed history and Phase 5 schemas. They do
   not claim an agent actually selected the skill, minimized context, or applied the
   correct review policy in a live task.

### Checker and results

4. Existing `check --root` output and exit codes remain byte/behavior compatible.
   `diagnose` returns actual checker/tool/catalog identity when available and null,
   bounded fields when validation prevents safe identity.
5. Valid docs pass; stale indexes, uncatalogued content, bad links/checksums,
   unsafe/symlinked paths, and changing files fail through the existing validator.
   `diagnose` never writes.
6. A check whose complete scope is clean is `exactRevision`; any checked path with
   tracked or untracked changes is `workingTree`; unavailable or ambiguous Git state
   is `unknown`. Unrelated dirty paths are reported in task context but do not
   silently change or broaden the check's declared scope. No result is attributed to
   another commit.
7. Passed, failed, skipped, unavailable, unknown, and notRun fixtures serialize and
   render distinctly. A catalog digest never becomes content approval, code revision,
   or check/reviewer attestation.

### Compatibility and adoption

8. Matrix fixtures cover no marker, exact V1, an older exact recognized capability
   row, known version with wrong digest, unknown version/digest, a newer unsupported
   declaration, malformed/modified blocks, absent/modified/clean plugins, old/new
   checker capability, valid/pending/invalid catalog state, denied access, and unknown
   observations. No case infers support from SemVer; diagnostics perform zero
   mutation.
9. An adoption preview changes only the exact shared block and explicitly selected
   duplicate clauses. Owner denial changes nothing. Owner approval still does not
   install/trust the plugin or accept a catalog.
10. A plugin update can coexist with a repository still declaring V1. A repository
    update with an old plugin reports incompatibility and preserves local rules.
    Interrupted repository update, plugin update, catalog acceptance, and lost reply
    all follow section 10 without silent retry or partial authority.

### Lifecycle and cross-project isolation

11. Archive/restore and removal/re-add preserve repository files and retained history.
    Restore grants nothing. Re-add rotates registration/request generation, and an
    old receipt/request cannot mutate the new registration.
12. Exact-root fixtures reject parent, child, prefix, symlink, different repository
    ID, stale registration, and changed request body. A worktree is used only when it
    is an explicitly authorized project root under the existing registration model.
13. Pursuit adoption fixtures preserve the clauses listed in section 5 and show no
    product-defect repair. A Perspective fixture with the two conflicting supplied
    paths returns `rootUnknown` and performs no inspection or write.

### Negative authority

14. Static API/reducer checks expose no path from a check result, task/reviewer
    assertion, plugin receipt, catalog digest, Git commit, archive/restore event, or
    generated adoption text to delivery acceptance, installation, trust, permission,
    push, merge, publication, notification, or a Run Guard action. This establishes
    the source boundary, not universal runtime behavior.
15. Existing Release Radar command fixtures continue to prove registration/request-
    generation scope and canonical-body replay. Tests explicitly assert that those
    receipts are not exposed or interpreted as check, run, review, or completion
    attestations.

### Separately authorized fresh-task/runtime pilot

After source delivery, plugin installation/update and runtime inspection receive
their own explicit authorization. Use the supported Codex task interface and normal
Release Radar diagnostic surfaces, not a custom agent harness or transcript parser.
The pilot starts a fresh task after installation, targets only a synthetic repository,
and directly observes whether the task loads the selected V1 skill, names the exact
root/source basis, limits its context to the eight fields and named controllers, and
reports actual check results without claiming acceptance. A separate fresh reviewer
task receives the same synthetic outcome and an identified candidate; the observation
can show that this tested workflow preserved review separation, but it is not verified
reviewer identity or a general enforcement claim.

Run one missing/incompatible-skill case under an isolated supported setup and confirm
that affected material work stops while unrelated read-only work follows local
fallbacks. Run one owner-denied adoption case and confirm no repository, plugin,
catalog, or app state changes. Read back repository and app diagnostic state after
the tested prompt/adoption flow; absence of mutation in that run is evidence only for
that run, not proof that prompts can never cause actions. Archive/restore and
removal/re-add runtime coverage remains synthetic app-state acceptance unless a later
owner authorization explicitly permits installed-app lifecycle inspection.

One later independent reviewer should cover the shared clause boundary, checker
compatibility/security, consumer supersession preservation, and recovery matrix. A
separate reviewer is needed only if an implementation introduces a distinct named
risk. Runtime installation, signed bundle behavior, actual task context selection,
and real consumer adoption need their own separately authorized acceptance; static
or synthetic source proof cannot establish them.

## 12. Later authorized work and owner decisions

This candidate authors no implementation. If approved, the smallest Release Radar
source slice is:

- add the one on-demand `shared-execution` skill to the existing plugin package and
  extend existing package-integrity tests with the exact
  `RecognizedPluginCapability` source;
- add the read-only `diagnose` mode to the existing documentation executable while
  preserving `check`/`write` compatibility;
- add a read-only technical compatibility presentation using existing plugin,
  repository, binding, and catalog observations, without Git/owner-approval claims;
  and
- add only the static and synthetic source checks in section 11. Actual task/runtime
  behavior remains a separately authorized fresh-task pilot.

It must not add a task runner, adoption database, generic command schema, hook,
review-attestation model, Run Guard dependency, or new delivery mutation merely to
implement V1.

The remaining owner decisions are:

1. approve, revise, or reject the on-demand-skill plus thin-local-block approach;
2. approve the exact V1 block and stable SEI clauses;
3. separately authorize and scope the Release Radar source slice;
4. later approve an exact Pursuit supersession/adoption patch;
5. identify Perspective's one canonical root before any inspection or adoption;
6. separately authorize any plugin install/update, Codex trust/permission change,
   repository catalog acceptance, or runtime verification; and
7. decide any future P10/P17/D13 attestation or Run Guard work on its own merits.

Until those decisions occur, this file remains a proposed, non-gating design. Phase
5 and ordinary consumer delivery continue under their existing contracts.
