# Shared Execution Integration V1 — source implementation plan

**Status:** source implementation authorized; staged path release applies

**Prepared:** 2026-09-09

**Planning baseline:** `a8877aac3bcbfb4e32abba48073704a253035583`

**Design source:** `docs/design/shared-execution-integration-v1-design.md` at exact reviewed candidate `7c50b61b0033a6d61fc60259a21acb60ca862069`

**Controlling context:**
[`ADR-002`](../../../architecture/ADR-002-codex-plugin-lifecycle.md),
[`ADR-006`](../../../architecture/ADR-006-managed-repository-documentation-contract.md),
[`ADR-007`](../../../architecture/ADR-007-proportional-delivery-validation.md), and
the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md)

This plan translates the reviewed shared-execution design candidate into a
bounded source-delivery sequence. The design and plan are integrated,
registered, and independently reviewed at
`3a49fb278dfbbbc80d9322e1f3ea757f4eceafda`. This owner-requested sequencing
amendment is a descendant of that candidate. The owner authorizes one fresh
isolated delivery task to begin disjoint source implementation in parallel with
Phase 5, with overlapping paths released only by the parent after Phase 5B.
This authorization does not install or update a plugin, adopt a consumer
repository, run a runtime pilot, mutate Release Radar application state, push,
open a PR, or merge. The catalogued supporting/proposed lifecycle remains a
documentation classification; it does not erase the explicit source authority
recorded here.

## Objective and complete outcome

Deliver Shared Execution Integration V1 as one coherent Release Radar source
slice whose observable outcome is:

1. a new `$release-radar:shared-execution` plugin skill carries the reviewed V1
   contract and canonical consumer adoption block;
2. `ReleaseRadarDocumentationTool diagnose` returns the reviewed, versioned
   machine-readable repository-document diagnosis without changing the
   existing `check`, `write`, or `--help` contracts;
3. Release Radar recognizes shared-execution support only from an exact plugin
   manifest-version plus normalized-package-digest capability entry;
4. project UI reports technical compatibility and local adoption truthfully,
   read-only, including root-unknown, unavailable, unknown, incompatible, and
   owner-denied paths; and
5. source-level and synthetic acceptance evidence covers the changed contract.

Installation/update and consumer adoption remain distinct later owner actions.
The source slice must not claim that a plugin is installed, a repository is
adopted, checks passed in a real consumer, or work is complete merely because
the source and tests exist.

## Scope and exclusions

### Included

- Plugin manifest/package inventory updates and the new shared-execution skill.
- One app-owned immutable capability registry keyed by exact plugin version and
  normalized package digest.
- Additive `diagnose` parsing, structured result types, JSON output, exit-code
  behavior, and backward-compatibility tests for the documentation helper.
- Read-only inspection of the exact local `AGENTS.md` marker/block under an
  explicitly known authorized project root, using existing hardened no-follow
  and stability-checked file access.
- A pure compatibility reducer for plugin capability, checker contract, root,
  repository identity, and local adoption observations.
- Read-only project presentation using existing project health/overview
  patterns, with actionable but non-mutating recovery guidance.
- Focused Core, helper, package-contract, reducer, and SwiftUI presentation
  tests plus synthetic repository fixtures.
- Documentation updates made necessary by the implementation when their exact
  paths are released, plus parent-owned catalog/index registration,
  progress/evidence recording, scoped commits, and the required independent
  review.

### Excluded

- A task runner, arbitrary command/recipe executor, new orchestration engine,
  formal completion or check attestation, verified run/reviewer identity, or a
  second database/schema.
- Treating existing mutation request/result receipts as check, run, reviewer,
  or completion attestations.
- Run Guard, role execution, hooks or I9 enforcement, guidance V3, new Phase 5
  domain fields, or changes to public command/evidence semantics.
- Plugin installation/update, installed-app replacement, catalog acceptance in
  the owner app, owner SQLite/Keychain reads or writes, credentials, networked
  services, or any real consumer-repository edit.
- Inspecting consumer repositories before the owner supplies and authorizes an
  exact root.
- A runtime consumer pilot. That is a later, separately authorized acceptance
  activity described below, not part of source implementation or source review.
- Cleanup of retained evidence or temporary runtime artifacts without separate
  authorization.

## Frozen identities and compatibility mapping

The implementation must use these identities exactly; aliases and inferred
equivalence are incompatible:

| Identity | V1 value |
| --- | --- |
| Plugin skill ID | `$release-radar:shared-execution` |
| Consumer standard marker | `shared-execution-standard: 1` |
| Managed block marker | `release-radar-shared-execution:v1` |
| Task `Standard` field | `shared-execution/1` |
| Checker result format | `com.rekonlabs.release-radar.documentation-check-result` |
| Checker result `schemaVersion` | `1` |
| Checker `contractVersion` | `1` |
| Repository catalog version supported by V1 | `1` |
| Capability key | exact manifest version + normalized package digest |

The first V1-capable package is reserved as plugin version `0.1.8`, the next
version after the baseline package `0.1.7`. The current source-delivery
authorization retains that reservation. The registry must contain both rows
after delivery:

| Manifest version | Normalized package digest | Shared standard versions |
| --- | --- | --- |
| `0.1.7` | `75f513d53675b6ae5679d2add575b76f9d32575d605f77702fd91a8c70d9f198` | none |
| `0.1.8` | exact SHA-256 computed after the V1 package bytes and inventory are frozen | `1` |

The `0.1.8` digest is deliberately not guessed in this plan. The delivery
writer must compute it with the established normalized-package algorithm after
the skill and manifest bytes are final, then commit the concrete literal in the
capability registry and its frozen fixture. A placeholder, wildcard, SemVer
range, version-only inference, or digest-only inference is not acceptable.

## Dependencies and Phase 5 sequencing

The owner authorizes one Shared Execution V1 source task to start from the exact
committed descendant of reviewed candidate
`3a49fb278dfbbbc80d9322e1f3ea757f4eceafda` that contains this amendment while
Phase 5 continues. The parent supplies that exact baseline at dispatch; paths
not expressly released remain held. This staged start changes sequencing, not
the complete V1 outcome, design contract, test obligations, or final review.

Phase 5B's current source ownership includes:

- `ReleaseRadar/App/AppModel.swift`;
- `ReleaseRadarTests/ProjectDocumentationRenderingTests.swift`;
- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md`;
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`; and
- `ReleaseRadarAgentTools/main.swift`;
- `ReleaseRadarTests/DocumentationCallbackTests.swift`; and
- all observation/UI paths until the reviewed Phase 5B descendant and ownership
  handoff, including `ReleaseRadar/App/DocumentationObservation.swift`,
  `ReleaseRadar/Projects/ProjectOverviewView.swift`, and any shared rendering or
  observation tests.

Those paths are held until Phase 5B has a reviewed committed candidate and the
parent explicitly hands off ownership. The existing-skill edit also changes the
normalized plugin package bytes, so final package inventory and digest work is
held even where its implementation files are otherwise disjoint. Never compute
or freeze the `0.1.8` digest against the obsolete pre-Phase-5B skill bytes.

The Phase 5 owner has confirmed this initial released path set for the sole
source writer:

- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json`;
- new `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/shared-execution/SKILL.md`;
- `ReleaseRadar.xcodeproj/project.pbxproj`;
- `ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift`;
- `ReleaseRadarPluginLifecycleHelper/main.swift`;
- `ReleaseRadar/App/AppNotificationCoordinator.swift`;
- new `ReleaseRadarCore/Documentation/RepositoryDocumentDiagnostic.swift`;
- `ReleaseRadarCore/Documentation/RepositoryDocumentIndexTool.swift`;
- `ReleaseRadarDocumentationTool/main.swift`;
- `ReleaseRadarTests/RepositoryDocumentIndexTests.swift`;
- `ReleaseRadarTests/DocumentationToolInstallationTests.swift`; and
- new `ReleaseRadarTests/SharedExecutionSkillContractTests.swift`;
- new `ReleaseRadarTests/RecognizedPluginCapabilityTests.swift`; and
- new `ReleaseRadarTests/RepositoryDocumentDiagnosticTests.swift`.

This release allows Chunk 2's additive `diagnose` contract and the disjoint
portion of Chunk 1 to begin. It is not a blanket lifecycle-test release. The
writer must reserve the shared test-host slot with the parent before any build
or test-host launch; source ownership alone does not grant concurrent host use.

Early release does not include the held lifecycle acceptance test, final
package inventory/digest/capability mapping, observation/UI paths, combined UI
tests, or any newly discovered Phase 5 overlap. If package work cannot remain
independent, narrow the first release to Chunk 2 rather than sharing ownership.

The staged delivery order is:

1. the parent dispatches the exact committed baseline containing this amendment
   and the released path set above;
2. one fresh isolated Shared Execution V1 writer starts only those paths and may
   make bounded local checkpoint commits;
3. the same task stops at every hold—no early checkpoint is full V1 completion,
   final package validation, or a review candidate;
4. before any build/test-host launch, the writer obtains the parent's explicit
   test-host reservation; if no slot is available, source work pauses without
   inventing test evidence;
5. Phase 5B completes its direct checks, independent review, and committed
   candidate, then the parent supplies the exact descendant and releases
   overlapping ownership;
6. the same Shared Execution writer integrates that baseline, computes and
   freezes the final package inventory/digest, and completes all remaining
   chunks and full-source validation; and
7. after the complete local candidate is immutable, one fresh independent
   reviewer evaluates the entire V1 outcome.

Do not ask the active Phase 5 writer to absorb Shared Execution work or create a
second source writer for the later integration. Parallelism is path-scoped
inside one delivery task; the complete source result remains one integration
and review boundary.

## Delivery ownership and exact source map

One delivery task owns all product-source writes for this slice. The parent
task remains sole writer for `docs/delivery/progress.md` and shared catalog/index
metadata unless the later dispatch explicitly transfers those paths.

| Area | Exact paths | Required change and ownership boundary |
| --- | --- | --- |
| Plugin package | `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json`; new `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/shared-execution/SKILL.md` | Set the retained V1 package version and add the reviewed skill contract. Do not modify the existing `release-radar` skill contract except for an explicit design requirement discovered before implementation. |
| Xcode resource/version membership | `ReleaseRadar.xcodeproj/project.pbxproj` | Keep app/package version expectations and filesystem-synchronized resource exceptions accurate for the new skill. Preserve all Phase 5 additions from the chosen baseline. |
| Package integrity and capability | `ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift`; `ReleaseRadarPluginLifecycleHelper/main.swift`; `ReleaseRadar/App/AppNotificationCoordinator.swift` | Recognize both exact old and new inventories, compute the established normalized digest, expose the raw observed package identity needed by the reducer, and map exact recognized packages to supported standard versions. The Core registry is the sole authority for capability; helper inventory recognition must not become a second capability registry. |
| Checker contract | new `ReleaseRadarCore/Documentation/RepositoryDocumentDiagnostic.swift`; `ReleaseRadarCore/Documentation/RepositoryDocumentIndexTool.swift`; `ReleaseRadarDocumentationTool/main.swift` | Add the typed V1 result and `diagnose`; reuse the same reader/validation interval as `check`; preserve existing verbs and output byte-for-byte where already frozen. |
| Local adoption inspection | new `ReleaseRadarCore/SharedExecution/SharedExecutionCompatibility.swift`; `ReleaseRadarCore/Onboarding/ProjectGuidanceInspection.swift` | Parse only the exact standard marker and full managed block from `AGENTS.md`. Read through descriptor-relative no-follow access, validate stability after the read, and report absence/difference/unsafe/unavailable truthfully without writing. Keep shared-execution state separate from guidance-version state. |
| App observation | `ReleaseRadar/App/DocumentationObservation.swift`; `ReleaseRadar/App/AppModel.swift` | Carry a generation-safe snapshot of root, repository diagnosis, plugin package identity/capability, checker contract, and local adoption. Invalidate it under the same project/root/binding changes as documentation observations; never persist it as a new domain record. |
| Project presentation | new `ReleaseRadar/Projects/SharedExecutionCompatibilityView.swift`; `ReleaseRadar/Projects/ProjectOverviewView.swift`; `ReleaseRadar/Projects/ProjectLifecycleSupport.swift` only if the existing health-row API cannot represent the reviewed states without semantic loss | Add one read-only compatibility surface within the existing project overview/health language. Do not create an unrelated destination or imply an owner action occurred. Preserve keyboard, accessibility, compact/wide layout, selection, and refresh behavior. |
| Source tests | `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`; `ReleaseRadarTests/CodexPluginLifecycleTransportTests.swift`; `ReleaseRadarTests/ManagedGuidanceCompatibilityTests.swift`; `ReleaseRadarTests/RepositoryDocumentIndexTests.swift`; `ReleaseRadarTests/DocumentationToolInstallationTests.swift`; `ReleaseRadarTests/ProjectDocumentationRenderingTests.swift`; new `ReleaseRadarTests/SharedExecutionSkillContractTests.swift`; new `ReleaseRadarTests/RecognizedPluginCapabilityTests.swift`; new `ReleaseRadarTests/RepositoryDocumentDiagnosticTests.swift`; new `ReleaseRadarTests/SharedExecutionCompatibilityTests.swift`; any exact observation test file introduced by the final Phase 5B baseline | Freeze package bytes/inventories, helper compatibility, checker JSON/exit codes, reducer states, no-follow/stability behavior, observation invalidation, and UI copy/accessibility. Preserve Phase 5B rendering coverage and extend repository-native fixtures; do not build a new harness. |
| Delivery documents | `docs/design/shared-execution-integration-v1-design.md`; `docs/architecture/ADR-002-codex-plugin-lifecycle.md`; `docs/architecture/ADR-006-managed-repository-documentation-contract.md`; `docs/delivery/plans/2026-09-06-full-product-architecture-and-delivery-plan.md`; `docs/delivery/progress.md`; `docs/catalog.json`; affected `docs/**/README.md`; one bounded evidence record under `docs/delivery/evidence/` | Update only facts made current by the owner-authorized implementation. Design status changes require explicit owner approval; source completion alone must not silently promote proposed design. The parent/Phase 5 owner owns shared metadata/ledger integration. |

Before initial dispatch, the parent must use the released and held sets above.
Before resuming held work, the delivery owner must re-resolve this map against
the chosen post-Phase-5B baseline. Newly introduced Phase 5 filenames may
replace a test filename above, but must not expand the behavior or ownership
boundary.

## Implementation sequence

All behavior changes use test-first development after the parent reserves the
test-host slot. Chunk numbering describes the complete dependency structure,
not a requirement to wait before released Chunk 2 work: the writer may execute
Chunk 2 and disjoint Chunk 1 steps first, while held steps remain untouched.
Early source or failing-test preparation is not a pass claim. A failure in
unrelated baseline tests is recorded and classified, not silently repaired.

### Chunk 1 — freeze the package contract and recognized capability

1. Add failing package-contract tests that require the exact
   `$release-radar:shared-execution` skill, V1 marker/block, eight task fields
   (`Standard`, `Root`, `Outcome`, `Scope`, `Authority`, `Endpoint`, `Direct
   checks`, `Review`), and the reviewed result-row vocabulary. Use the released
   new skill-contract and capability test files for early work; do not fold them
   into a held lifecycle test.
2. Add failing lifecycle/helper tests that preserve recognition of `0.1.7` with
   no shared standard and reject unknown version/digest combinations. Changes
   to `CodexPluginLifecycleAcceptanceTests.swift` wait for the Phase 5B handoff.
3. Add the V1 skill and retained version update. Freeze its exact normalized
   inventory in both the app lifecycle and helper boundary.
4. Compute the final package digest once bytes are frozen, add the exact
   `0.1.8` capability entry for standard version `1`, and pin it in tests.
5. Expose the minimum raw package identity/capability observation required by
   the app without changing install/update/recovery authority or status copy.

Acceptance for this chunk: both exact packages are recognized according to
their frozen inventories; only `0.1.8` plus its exact digest advertises V1; any
other combination is unknown/incompatible; installation remains a separate
typed owner action.

### Chunk 2 — add the additive checker diagnosis

1. Add failing Core tests in the released new
   `ReleaseRadarTests/RepositoryDocumentDiagnosticTests.swift` for the exact
   result envelope and all bounded failure cases before changing the helper.
2. Introduce typed `RepositoryDocumentDiagnostic` values with:
   - top-level `format = com.rekonlabs.release-radar.documentation-check-result`
     and `schemaVersion = 1`;
   - `checker.contractVersion = 1`;
   - nullable `checker.toolVersion` and `checker.toolBuild` when not available;
   - `checker.supportedCatalogVersions = [1]`;
   - nullable `target.repositoryID`, `target.catalogVersion`, and
     `target.catalogDigest`;
   - top-level `status` of `passed` or `failed`; and
   - a bounded nullable structured top-level `error`.
3. Refactor `RepositoryDocumentIndexTool` only enough for `check` and
   `diagnose` to share the same `RepositoryDocumentReader`, validated snapshot,
   and stability check. Do not reread the tree merely to populate identity.
4. Add `diagnose --root "/absolute/authorized/repository" --format json` to
   the helper. It performs no Git or other command execution and never writes,
   binds, accepts, or mutates.
5. Preserve existing `check`, `write`, and `--help` behavior and output. Freeze
   exits `0` for pass, `1` for bounded validation/I/O failure, and `64` for
   invalid arguments. Tool absence or an unrecognized contract is surfaced by
   the caller as unavailable/unknown, never synthesized as a pass.

Acceptance for this chunk: a stable valid synthetic repository produces one
deterministic V1 JSON result whose target identity comes from the validated
snapshot; malformed, unsafe, changing, and unsupported repositories produce
bounded failures; all pre-existing helper contract tests remain unchanged and
pass.

### Chunk 3 — reduce local technical compatibility without persistence

1. Add failing table-driven reducer tests for every state:
   `notDeclared`, `compatibleV1`, `compatibleOlder`, `updateAvailable`,
   `pendingCatalogAcceptance`, `incompatible`, `unavailable`, `rootUnknown`,
   and `unknown`.
2. Add exact adoption-block parsing tests for absent, exact, duplicate,
   modified, legacy, unreadable, symlink, non-regular, oversized, and
   changed-during-read `AGENTS.md` cases.
3. Implement a pure reducer over explicit observations: authorized root,
   recognized plugin capability, checker contract/result, validated repository
   identity, and local marker/block state. Keep evidence source and limitation
   with every direct-result row.
4. Use the exact row fields `Check`, `Runner`, `Scope`, `Source`,
   `Applicability`, `Status`, `Direct result`, and `Limitation`; restrict status
   to `passed`, `failed`, `skipped`, `unavailable`, `unknown`, or `notRun`, and
   applicability to `exactRevision`, `workingTree`, or `unknown`.
5. Represent task-side adoption progress only as
   `workingTreeCandidate`, `committedCandidate`, `ledgerRecorded`, or `unknown`
   in transient presentation/adoption results. Do not store those values in
   Release Radar's SQLite model.

The reducer must not treat catalog digest as approval, a tested Git revision,
or owner consent. It must not treat a valid local block as proof that direct
checks or independent review ran. If no exact authorized root exists, its
result is `rootUnknown` and it performs no fallback search.

Acceptance for this chunk: every state is determined from explicit input with
no SemVer inference, filesystem search, network call, external command, or
state mutation; unsafe or incomplete observations degrade to the reviewed
non-pass states and retain actionable limitations.

### Chunk 4 — present compatibility in the existing project workflow

1. Add failing observation-coordinator tests for identity/generation races,
   project removal, root replacement, documentation binding/catalog change,
   plugin observation change, and refresh.
2. Add failing view-model/rendering tests for all compatibility states and
   direct-result rows, including accessible labels and recovery copy.
3. Wire the snapshot through `AppModel` and the existing project overview. A
   selected project with no known root shows `rootUnknown`; a missing or older
   capable package distinguishes update availability from installation consent;
   a locally exact block distinguishes declaration from runtime proof.
4. Offer only truthful next-step guidance: authorize/select an exact root,
   inspect the technical limitation, update/install in a separate owner action,
   or begin a separate adoption task. No button in this slice writes the
   consumer or installs the plugin.
5. Compare the running synthetic test host with the relevant project-overview
   design language at compact and wide window sizes, and exercise keyboard,
   accessibility, refresh, focus, and recovery behavior. Record any necessary
   visual deviation in the existing design document before review.

Acceptance for this chunk: the surface is readable and recoverable at compact
and wide sizes, never displays stale observations after identity changes, and
does not imply support, adoption, checks, review, or completion beyond the
explicit evidence supplied to it.

### Chunk 5 — integrate documentation and prepare one immutable candidate

1. After the parent releases the applicable paths, update only documentation
   made inaccurate by the delivered source. Preserve `ADR-002` lifecycle
   authority, `ADR-006` repository-document boundaries, and `ADR-007`
   proportional validation.
2. Report the exact changed durable-artifact set and direct evidence to the
   parent/Phase 5 owner. That coordinator remains the sole writer for
   `docs/catalog.json`, generated indexes, and `docs/delivery/progress.md`; it
   integrates those updates without creating another ledger, process transcript,
   or validation harness.
3. Run the focused tests below, repository documentation validation, link/path
   checks, and `git diff --check` from the exact authorized worktree.
4. Inspect the final diff against the frozen identities, exclusions, and chosen
   Phase 5 baseline. Attribute only this slice's changes.
5. Commit bounded local checkpoints and one complete scoped local candidate.
   Push/PR require separately resolved authorization; merge always requires
   explicit owner approval.

## Test and validation strategy

### Required source-delivery checks

- Package/skill contract tests for exact inventory, exact old/new digest rows,
  markers, fields, status vocabulary, and local fallback safeguards.
- Plugin lifecycle and transport tests for intact/outdated/missing/modified
  packages and unchanged install/update/recovery authority.
- Checker unit/acceptance tests for valid, invalid, missing, unsafe,
  changed-during-read, unsupported-version, and invalid-argument paths; exact
  JSON decoding and exit codes; regression tests for existing verbs/output.
- Reducer matrix tests across every reviewed compatibility state, including
  mismatched repository identity and pending catalog acceptance.
- Descriptor-relative `AGENTS.md` tests for no-follow, regular-file, bounds, and
  stability behavior.
- Observation generation/identity tests and synthetic SwiftUI tests for
  compact/wide, keyboard, accessibility, focus, refresh, and error recovery.
- The repository's focused affected Xcode test suites, only after the parent
  reserves the shared test-host slot, with isolated DerivedData and synthetic
  per-process state following the established test-host pattern.
- Exact-root repository documentation check, affected-link/path validation, and
  `git diff --check`.

Source verification must use synthetic fixtures and the repository-native test
host. It must not launch the owner's installed app, inspect owner databases,
install a runtime package, or mutate a real consumer.

### Separately authorized runtime pilot

The later pilot is not a hidden completion gate for source implementation. If
the owner authorizes it after a source candidate and its independent review, use
a fresh task and exact synthetic repository root to verify:

1. a fresh Codex task sees the newly installed skill only after the documented
   plugin lifecycle boundary;
2. the skill emits the exact standard fields and runs only the stated direct
   checks;
3. a fresh independent reviewer receives the immutable candidate and actual
   direct results;
4. missing/older/incompatible skill and checker cases remain honest;
5. owner-denied adoption performs no consumer write; and
6. readback proves the exact synthetic consumer block/result without relying on
   a transcript parser or custom harness.

Plugin installation, installed-app replacement, catalog acceptance, and any
consumer write each need their own explicit authorization. A pilot failure may
justify a bounded source correction; it does not authorize changes to real
consumer repositories or owner state.

## Compatibility, migration, and recovery

- **Plugin compatibility:** retain exact recognition and repair behavior for
  package `0.1.7`; adding the new skill changes the inventory, so app and helper
  recognition must be updated atomically. Unknown package bytes never inherit
  V1 capability from a version string.
- **Checker compatibility:** `diagnose` is additive. Existing `check`, `write`,
  `--help`, exit codes, stdout/stderr, no-follow behavior, and accepted catalog
  version remain externally stable except for the explicitly added verb.
- **Data migration:** none. V1 adds no Release Radar schema or persisted
  adoption state. Any proposal to add one is a scope change requiring owner and
  architecture review before work continues.
- **Consumer compatibility:** existing `AGENTS.md` content remains untouched by
  source implementation. An exact V1 block is compatible; absence is
  `notDeclared`; modified/duplicate/incompatible blocks require bounded guidance
  and owner-directed recovery, never automatic replacement.
- **Recovery:** plugin lifecycle recovery remains the typed existing flow.
  Checker/adoption read failures are retryable observations. Root changes cancel
  or supersede stale observation generations. No recovery path weakens sandbox,
  path containment, validation, authentication, or owner authority.
- **Rollback:** reverting the scoped source candidate restores the old package
  and helper behavior without a data migration. A later installed package or
  consumer adoption has its own separately authorized recovery plan and must
  not be inferred from this source rollback.

## Material risks and bounded mitigations

| Risk | Required mitigation |
| --- | --- |
| Package inventory changes cause healthy `0.1.7` installations to appear modified | Freeze both exact inventories/digests; retain old-row tests in app and helper. |
| Version or digest is mistaken for capability/approval | One Core exact-pair registry; explicit empty `0.1.7` capability; reducer tests for unknown pairs and catalog-digest limitations. |
| `diagnose` drifts from `check` or reads two repository states | Share one reader, validated snapshot, and stability interval; freeze existing CLI behavior. |
| Consumer inspection escapes the owner-selected root or follows a replacement | Reuse descriptor-relative no-follow access, regular-file/bounds checks, and final stability validation; no root discovery. |
| Stale async results attach to a new project/root/binding/plugin state | Extend identity/generation invalidation tests before UI wiring. |
| UI implies installation, adoption, test success, review, or completion | Use exact reviewed states/row vocabulary and visible source/limitation; no mutating control in V1. |
| Phase 5 edits are lost or two writers share source | Dispatch only from a reviewed post-Phase-5B baseline after explicit ownership release; one integration writer. |
| Verification expands into a custom runner or attestation system | Use existing XCTest/helper fixtures and direct result readback only; stop at the source acceptance criteria. |

## Acceptance criteria

The source slice is ready for independent review only when all of the following
are true:

- The exact skill, marker, block, checker, result-row, and capability identities
  match the reviewed design candidate.
- `0.1.7` is preserved as recognized but not V1-capable; the retained `0.1.8`
  exact version/digest pair alone advertises standard `1`.
- `diagnose` returns the V1 JSON contract from one stable validation interval,
  while existing helper verbs and outputs pass their regression tests.
- All reviewed compatibility states are reachable in deterministic reducer
  tests, and none is inferred from SemVer, a catalog digest, or absent evidence.
- Consumer inspection is read-only, root-bound, no-follow, bounded, and stable;
  root unknown performs no filesystem search.
- UI is truthful, accessible, recoverable, responsive, and free of install or
  adoption side effects.
- No database/schema, guidance V3, Phase 5 domain, hook, Run Guard, runner,
  attestation, or real-consumer change appears in the diff.
- Required focused tests, native synthetic checks, repository documentation
  validation, path/link validation, and diff checks pass, with any unrelated
  baseline failure clearly separated.
- Documentation/catalog/index/progress facts are current without silently
  promoting the proposed design beyond owner approval.
- One fresh independent reviewer reports no unresolved Required finding against
  the exact immutable candidate. Optional findings do not expand scope or block
  completion.
- The source writer and reviewer have stopped relevant processes and reported
  retained temporary evidence; no installation, owner-state mutation, push, PR,
  merge, or cleanup is claimed without its separate authorization.

## Assignment and delivery endpoint

### Authorized source writer

- **Profile:** `gpt-5.6-sol` / `high` because the slice crosses plugin package
  integrity, CLI compatibility, root-bound untrusted file reading, asynchronous
  app observation, and user-facing recovery. Astra `high` is the escalation
  ceiling only for a named unresolved shared-contract or authority conflict.
  `xhigh`, `max`, and `ultra` are not authorized.
- **Initial baseline:** the exact parent-supplied committed descendant of
  `3a49fb278dfbbbc80d9322e1f3ea757f4eceafda` containing this sequencing
  amendment. The initial release is limited to the explicit disjoint paths
  above.
- **Continuation baseline:** before held work or final package digest/inventory,
  the same task integrates the parent's exact reviewed Phase 5B descendant and
  receives an explicit ownership handoff. Never infer a default branch or use a
  dirty checkout.
- **Ownership:** sole source writer for the complete V1 outcome, but only for
  paths the parent has released at that stage. The parent/Phase 5 owner remains
  sole writer for shared catalog/index/progress metadata.
- **Endpoint:** direct checks, necessary released documentation, bounded local
  checkpoint commits, one complete scoped local candidate, and stopped
  processes. Push/PR require separately resolved authorization; installation,
  catalog acceptance, app-state mutation, consumer adoption, runtime pilot, and
  merge each require separate owner authorization.

### Independent reviewer

- **Profile:** fresh `gpt-6-astra` / `high`, justified by the combined package
  integrity, filesystem containment, public helper compatibility, and truthful
  UX boundary. The reviewer is not forked from the writer and does not edit the
  candidate.
- **Candidate:** the exact immutable source commit plus the original outcome,
  reviewed design, this plan, direct test results, and known baseline failures.
- **Coverage:** one reviewer may cover code, security/privacy, CLI compatibility,
  and UX risks because they meet at the same reducer/observation boundary. Do
  not create additional reviewers or review the review absent a named unresolved
  risk or explicit owner requirement.
- **Endpoint:** Required findings with exact file/line evidence, or a pass with
  residual limitations. Corrections return to the same writer and repeat only
  affected checks and the applicable bounded recheck.

### Current planning task

This task changes only this plan and may make one scoped local commit. The parent
task owns catalog/index/progress registration, independent document review, and
any later integration. No push, PR, merge, product-source edit, test/app launch,
plugin install, consumer inspection, or state mutation is authorized here.
