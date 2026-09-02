# Release Radar delivery state

## Current state

- Outcome: M2–M5 accepted and pushed; M6A initial owner preflight performed
- Active task: M6A activation-runbook completion after accepted M2A correction
- Last complete task: M5 — Guidance-v2 Compatibility
- Authorization: The owner authorized development, checks, independent review,
  in-scope corrections, delivery records, and normal commit/push for the MDCP
  program. M6A initial preflight and the separately proposed installed-app
  broker recovery are approved. Installation, disposable/owner migration,
  repository activation, handoff, and binding retain their exact live gates.
  Latest owner direction: finish and deliver M6A, then stop for a new session.
  Do not open M6B, M7, M8, Task 4B, or Issue #1 in this session.
- Controlling decision: root `AGENTS.md` and
  [ADR-007](../architecture/ADR-007-proportional-delivery-validation.md)
- Controlling briefs: [M2A](task-briefs/2026-09-01-managed-repository-documentation-contract/m2a-catalog-contract-validator-brief.md)
  for any confirmed frozen reader correction; [M6A](task-briefs/2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-inventory-brief.md)
  for owner activation.
- Current risk: The synthetic regression confirmed unnecessary ancestor
  directory-read requirements. The accepted correction uses directory search
  access with the same no-follow/identity protections. Actual signed-app
  inventory at the owner root remains the next live verification; missing
  catalog deployment and remaining activation actions are still gated.
- Verified owner state: Protected pre-recovery and post-recovery backups are
  complete. Supported startup restored the exact installed broker; the app and
  lifecycle writer then exited. Read-only maintenance exited, and all captured
  owner-file bytes and sidecar absence remained unchanged. No migration,
  installation, handoff, binding, adoption, or document move occurred.
- Next action: Obtain approval for the completed exact remaining
  [M6A runbook](task-briefs/2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-runbook.md),
  then verify the corrected reader through the approved live sequence.
- State: M2A CORRECTION ACCEPTED; M6A IN PROGRESS
- Prior checkpoint `MDCP-COMPAT-1`:
  `dd32d8d0d7f333afc7367e5f2cc505d9e889c8cf`. The accepted correction below
  establishes replacement `MDCP-COMPAT-2` after its normal commit/push.

## MDCP M2C — Central Path Contract and v1 Catalog Preview

- Implemented: One Core path/version/marker definition, compatible v1 guidance
  and prompts, and one read-only documentation state for legacy or valid/invalid
  staged catalogs. Authorized onboarding observation and app presentation use
  that state; importer/evidence identity and delivery behavior remain legacy.
- Verification: Runtime RED preceded behavior changes. Native `xcodebuild test
  -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination
  'platform=macOS'` with focused `ProjectDocumentationPreviewTests` and
  `OnboardingAcceptanceTests/testCentralizedHandoffPromptIsByteCompatibleWithLegacyV1`
  passed 9/9. The six-suite compatibility run passed 134 tests with only the
  unchanged schema-9 assertion failure. `git diff --check` passed.
- Independent roles: implementer `/root/m2c_implementer`; Code Review
  `/root/m2c_code_review`, QA `/root/m2c_qa`, Architecture
  `/root/m2c_architecture`, and Security/Privacy `/root/m2c_security` all GO.
  Code Review also accepted the default-preserving initializer used for native
  rendering. No required findings remain.
- QA rendered actual overview/onboarding views at 1100×850 and 620×850;
  `ProjectDocumentationRenderingTests` passed 2/2. Current design prose governs
  the superseded onboarding mockup. Representative evidence:
  [overview staged](evidence/mdcp-m2c-overview-staged-wide.png),
  [overview repair](evidence/mdcp-m2c-overview-repair-compact.png),
  [onboarding staged](evidence/mdcp-m2c-onboarding-staged-wide.png), and
  [onboarding repair](evidence/mdcp-m2c-onboarding-repair-compact.png).
  Status/detail wrapping and actions were visually verified. Native AX traversal
  exposed no SwiftUI nodes in the isolated host; runtime accessibility remains
  unverified. Source identifiers and presentation behavior were inspected.
- Durable artifacts: source, focused tests, four screenshots, and this ledger.
  Native outputs under `.build/m2c/` and the two synthetic rendering temporary
  databases were removed after process exit and exact-target verification under
  the owner's cleanup authorization.
  Owner data, bundled skill bytes, existing fixtures, and `docs/superpowers/`
  were unchanged. M3A0 is next.

## MDCP M3A0 — Schema-v12 Migration Fixture

- Implemented: Immutable synthetic
  [schema-v12 fixture](../../ReleaseRadarTests/Fixtures/SchemaV12/release-radar-v12.sqlite)
  generated through accepted production `DeliveryStore` initialization and
  audited transactions. Six evidence variants and unrelated-state sentinels
  populate all 30 tables; full schema, integrity, and foreign-key checks pass.
- Verification: Missing-fixture RED, native generation 1/1, and final 2/2
  without failures/skips. Independent QA repeated
  `StoreAcceptanceTests/testExactVersionTwelveFixtureManifestAndSemantics` and
  `StoreAcceptanceTests/testGenerateVersionTwelveFixtureAttachmentOnlyWhenAbsent`
  through the `ReleaseRadar` Xcode scheme on macOS. Repeat generation emitted
  no replacement attachment. Fixture-local `shasum -a 256 -c SHA256SUMS` and
  `git diff --check` pass. SHA-256:
  `66d777eb7acd9df11c253d8fa51b6932fd1c1b16af74bfbceef5b18c0aed8319`.
- Independent roles: implementer `/root/m3a0_implementer`; Code Review
  `/root/m3a0_code_review`, Architecture `/root/m3a0_architecture`, and QA
  `/root/m2c_qa` all GO. The QA agent did not implement this slice. No required
  findings remain.
- Durable artifacts: fixture/checksum, focused store tests, one Xcode resource
  exclusion, and this ledger. Temporary native results/exports under
  `.build/m3a0/` were removed after process exit and exact-target verification
  under the owner's cleanup authorization. Production behavior, prior fixtures,
  owner data, and Issue #2
  artifacts are unchanged. M3A is next.

## MDCP M3A — Managed Evidence Identity

- Implemented: Schema v13 preserves all frozen-v12 legacy evidence and unrelated
  state, creates no inferred bindings or artifact IDs, and enforces exactly one
  locator plus project/repository/root binding uniqueness. Additive Codable
  models preserve the legacy API; readback validates the persisted canonical
  snapshot. Managed resolution requires the exact authorized bound root and
  accepted repository/version/digest, with separate identity, authority, and
  typed availability outcomes.
- Verification: Schema and root-classification runtime RED preceded changes;
  missing model/readback APIs also failed before implementation. Signed serial
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar
  -destination 'platform=macOS' -parallel-testing-enabled NO` passed 84/84 across
  `StoreAcceptanceTests`, `ManagedDocumentEvidenceTests`, and
  `RepositoryDocumentCatalogTests`. Independent QA passed 44/44, including six
  frozen-v12/v13 tests, model/resolver/catalog coverage, and four existing bridge
  and importer legacy-boundary checks. Migration rollback, actual snapshot
  restoration, exact schema refusal, relaunch, accepted moves, missing/restored
  files, historical authority, checksum and unsafe-path failures are covered.
  The v12 fixture checksum and `git diff --check` pass.
- Independent roles: implementer `/root/m3a_implementer`; Code Review
  `/root/m3a_code_review`, QA `/root/m3a_qa`, Architecture
  `/root/m3a0_architecture`, and Security/Privacy `/root/m3a_security` all GO.
  No required findings remain. Optional extreme caller-supplied `Limits`
  robustness is deferred; defaults are safe and repository content cannot set
  those values.
- Limits: Verification used synthetic stores/files and bookmark authorization.
  No owner migration, installation, UI acceptance, or live mutation occurred.
  One catalog stability test failed transiently, then passed unchanged in
  isolation and both final runs. Four older synthetic downgrade setups were
  updated to remove v13 objects; immutable fixtures remain unchanged.
- Durable artifacts: source, focused tests, and this ledger. Temporary
  `.build/m3a/` outputs and three log-identified synthetic host databases were
  removed after process exit and exact-target verification under owner cleanup
  authorization. Excluded consumers and owner state are unchanged. M3B is next.

## MDCP M3B — Evidence Inventory and Audited Reconciliation

- Outcome: Complete with Code Review, QA, Architecture, and Security/Privacy
  GO; no required findings remain. Implementer `/root/m3b_implementer`;
  reviewers `/root/m3b_code_review`, `/root/m3b_qa`,
  `/root/m3b_architecture`, and `/root/m3a_security` were independent of the
  implementation. The shared-file contract below was published before RED.
- Verification: Signed serial `xcodebuild test -project
  ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS'
  -parallel-testing-enabled NO` passed 126/126 across the new suites and
  existing bridge, importer, notification, resolver, and catalog tests.
  Focused stale-preview/preflight checks passed 6/6; the final preservation
  correction passed 27/27. Independent QA passed 37/37, including all four new
  suites, five store checks, and four existing legacy importer/bridge checks.
  Every mutation's replay, relaunch, request-body mismatch, and late receipt
  rollback passed. Lost-reply recovery used an isolated callback. Packaged
  helper discovery ran without a production connection. `git diff --check`
  passed.
- Required correction: Fixed preservation metadata now includes historical
  notification rows with no project attribution. Its direct regression failed
  before the bounded partition correction and passed afterward. Frozen v10
  semantic preservation across migration and byte-preserving v10–v12 preflight
  passed; immutable fixtures remain unchanged.
- Durable artifacts: source, focused tests, and this ledger. Temporary
  `.build/m3b/` results and 15 log-identified synthetic XCTest host directories
  were removed after process exit and exact-target verification under owner
  cleanup authorization. No owner state, installation, production broker
  registration, live maintenance launch, or UI acceptance was performed.

- Scope: The six named M3B tools use a separate read-only inventory dispatcher
  and five typed audited commands. Inventory returns exact project/root-row
  identity, stored binding context separately from current catalog observation,
  every evidence locator/association, stored versus resolved availability, and
  exact candidate/rejection metadata. An unavailable or oversized result is
  explicit and cannot be used as a complete inventory. Pending catalogs do not
  prevent readback of the persisted binding or authorize managed resolution.
- Required supporting boundary: M6's pre-migration semantic comparison and M7's
  quiesced inventory cannot use ordinary app launch, which migrates storage and
  starts background writers. A fixed-purpose read-only application preflight
  path will open existing supported v10–v13 storage without creation, migration,
  background services, or mutation dispatch. Fixed preservation counts/digests
  and audit/receipt identity fingerprints support the explicit M6–M8 equality
  gates. No arbitrary query/table selector, baseline database, or new ledger is
  introduced. Architecture confirmed this bounded query/transport need before
  implementation; owner execution remains separately gated.
- Exact Task 4B file overlap: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`,
  `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`,
  `ReleaseRadarAgentTools/main.swift`,
  `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`,
  `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`, and
  `ReleaseRadarTests/NotificationAcceptanceTests.swift`. Shared surfaces are
  additive command/result JSON, root authorization, canonical receipts,
  transaction/replay and audit routing, tool translation/schema, transport
  failures, and notification non-effects. Task 4A's accepted-transition and
  upsert rules remain intact. Task 4B's task-plan commands remain unopened.
- Supporting files: focused Documentation query/operation types, store read-only
  access, application/transport hosting, importer classification, and their
  existing or focused native tests. Guidance-v2 source text/package activation
  remains M5 work; no repository guidance, live state, or document paths change.
- Selected interfaces: version-1 inventory query with authorized `projectRoot`
  and optional expected project/root IDs for discovery followed by exact calls;
  exact project/root/repository/version/digest targets on managed commands;
  adoption of 1–128 unique records, including each expected prior path and
  nullable ticket association, within the existing 65,536-byte command bound.
  Inventory is complete or explicitly unavailable/too large at the existing
  131,072-byte response bound. Legacy response fields remain compatible.
- Host operation: `--documentation-maintenance=read-only|commands`, with an
  optional existing-store override for an approved disposable restore. Read-only
  accepts inventory only on recognized v10–v13 shapes without migration. Commands permits only
  the five documentation mutations and the exact root-`AGENTS.md` handoff route,
  with ordinary UI/background writers disabled; this enables M8 acceptance
  under continuing quiescence. Neither mode installs/registers the broker.
  Tests use direct isolated callbacks and safe packaged-tool requests; tests
  that register/unregister the production broker are deferred to authorized
  live acceptance while the owner app is running.
- Compatibility correction: Historical delivery evidence records the last
  verified owner installation at schema v10; v11/v12 development did not imply
  installation. Preflight therefore includes existing frozen v10/v11/v12
  fixtures, exact schema refusal, and preservation of source-version fields
  across migration. M6 compares immediate post-migration state before handoff
  or binding, then uses the v13 baseline for its permitted subsequent changes.
  Live schema/root identities still require the separately authorized readback.
- Preflight storage boundary: Native synthetic tests confirmed that immutable
  SQLite reads can omit committed WAL rows. Preflight therefore rejects any
  nonempty WAL and preserves the database and sidecars unchanged. The later
  owner-approved runbook must require graceful writer shutdown and a
  checkpointed existing store; inventory never checkpoints or repairs storage.

## MDCP M3C — Readback and Root Relocation

- Outcome: Batched public readback and existing detail/overview views preserve
  locator identity and distinguish lifecycle, authority, availability, and
  recovery. Owner prepare/confirm validates the exact accepted repository,
  fresh bookmark, ownership, and handoff association before atomically replacing
  the bound root/bookmark and at most one exact legacy handoff path. Managed and
  other legacy evidence stay unchanged. A bookmark/path-free recovery token
  reads the exact persisted receipt after restart without retrying a mutation.
- Owner boundary: Rebind remains outside agent commands/MCP. Maintenance reuses
  the evidence/recovery UI and one existing store without ordinary app services;
  read-only mode disables relocation. Existing v10–v12 readback stays unmigrated.
  Phase-less projects retain recovery access. Post-relocation overview refresh
  now updates root/guidance without changing navigation or adding an audit.
- Verification: Runtime RED preceded changes and required corrections. Signed,
  serial `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar
  -destination 'platform=macOS' -parallel-testing-enabled NO` passed 159/160
  compatibility tests; the sole failure is the unchanged schema-9 expectation.
  Final rendering passed 2/2. Independent QA passed 43/43 and repeated the
  affected owner-refresh regression 1/1. Replay/restart, ambiguity, collision,
  denial, rollback, root revocation, unavailable guidance, checksum states, and
  changed read-only source rejection passed. `git diff --check` passed.
- Independent roles: implementer `/root/m3c_implementer`; Code Review
  `/root/m3c_code_review`, QA `/root/m3c_qa`, Architecture
  `/root/m3c_architecture`, and Security/Privacy `/root/m3c_security` all GO.
  Required findings are closed; only affected checks/reviews were repeated.
- Actual isolated windows passed AX checks for evidence states, artifact IDs,
  confirmation controls, phase-less recovery, and settled read-only maintenance.
  QA and coordinator inspected wide/compact captures against the existing
  mockups: [evidence wide](evidence/mdcp-m3c-evidence-1100.png),
  [evidence compact](evidence/mdcp-m3c-evidence-620.png),
  [confirmation wide](evidence/mdcp-m3c-confirmation-1100.png),
  [confirmation compact](evidence/mdcp-m3c-confirmation-620.png),
  [phase-less overview](evidence/mdcp-m3c-phase-less-overview.png), and
  [read-only maintenance](evidence/mdcp-m3c-maintenance-read-only.png).
  Synthetic bookmark limitations account for the maintenance unavailable state;
  no owner application, database, installation, or live broker operation ran.
- Durable artifacts: source, focused tests, six screenshots, and this ledger.
  Program-created `.build/m3c/`, associated logs, and 16 synthetic host directories
  were removed after process exit and exact-target verification under owner
  cleanup authorization. Pre-existing outputs were preserved. M4 is next.

## M2A correction — Binary Verification Evidence

- Outcome: Complete. Non-Markdown verification evidence is validated as bytes;
  textual documents, indexes, manifests, and Markdown evidence retain UTF-8
  validation and applicable links. Existing containment, limits, checksums,
  and snapshot-stability validation remain effective.
- Trigger: M4's truthful `verificationEvidence` classification for existing PNG
  screenshots fails `invalidUTF8` in the accepted validator. Artifact kind is
  independent of encoding; relabelling evidence as a design asset is not a fix.
- Scope: Restore binary evidence handling through the existing bounded reader
  and checksum validation while retaining UTF-8 and link checks for textual
  evidence/documents/indexes/manifests. Use the existing focused catalog/index
  tests and independent Code, QA, Architecture, and Security review capabilities.
  No schema, guidance, owner-state, or new validation framework change.
- Delivery: Preserve M4's unapproved draft and commit this source correction
  separately so M4's final diff remains documentation-only. The existing program
  authorization covers this required accepted-contract correction; no live gate
  is consumed or waived.
- Verification: Direct PNG `invalidUTF8` RED preceded the bounded decoder
  correction. Independent coordinator QA ran signed serial `xcodebuild test
  -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination
  'platform=macOS' -parallel-testing-enabled NO` with
  `RepositoryDocumentCatalogTests` and `RepositoryDocumentIndexTests`: 43/43
  passed. Binary indexing, corrupt checksum, changed file, symlink, malformed
  text, and broken Markdown-link regressions passed. `git diff --check` passed.
- Independent review: `/root/m3c_qa` implemented this separate correction;
  `/root/m3c_code_review` supplied Code, Architecture, and Security GO. The
  coordinator independently executed QA. No Required findings remain.
- Durable artifacts: validator, focused native regressions, and this ledger.
  Correction-only build outputs and four synthetic host directories were removed
  after process exit and exact-target verification. M4's unapproved draft and
  temporary preparation outputs remain preserved for immediate continuation.

## MDCP M4 — Stage Repository Catalog In Place

- Outcome: Catalog v1 covers 188 artifacts and 28 collections at unchanged
  paths, with nine generated indexes and 19 leaf collections. Seventeen active
  controllers are distinct. Completed M4 is non-authoritative; later slices
  remain proposed. The root index enumerates the transitional subtree without
  writing inside it. No unresolved authority decision remains.
- Verification: Proposed-fixture check passed and the uncatalogued real tree
  failed as expected before writes. The corrected native
  `ReleaseRadarDocumentationTool` passed full-tree check/write/check; the second
  write changed zero files and all nine indexes remained byte-identical.
  Existing human prose in three READMEs is preserved. The two held artifacts
  match their accepted whole-file hashes; archive and task-brief manifests
  remain unchanged and pass 87/87 entries. Actual guidance is missing/legacy;
  a disposable real-docs copy with synthetic v1 guidance passes staged preview
  without audited handoff or activation. `git diff --check` passes.
- Independent review: `/root/m3c_implementer` authored the catalog/index slice;
  `/root/m3c_code_review` supplied Documentation GO with zero Required findings.
- Durable artifacts: catalog, nine indexes, and this ledger. M4-only inventory,
  fixture, tool build, logs, held drafts, and disposable preview copy under
  `.build/m4/` were removed after process exit and exact-target verification
  under the owner's cleanup authorization. Pre-existing outputs are preserved.
  No source, tests, document moves, guidance activation, or owner-state operation
  occurred. M5 is next.

## MDCP M5 — Guidance-v2 Compatibility

- Outcome: Exact guidance v2, supported v1 upgrades, current/pending/unavailable
  accepted-binding observation, matching prompts and plugin 0.1.6. The stable
  v1 handoff evidence namespace preserves existing identity; an upgrade reuses
  the exact inventoried row with a fresh audited request. The v2 handoff
  requires an existing catalogued ledger and preserves it byte-for-byte. The
  canonical plan collection is `docs/delivery/plans`.
- Shared source/test inventory was identified before RED. Final production
  inventory is Core `RepositoryDocumentContract`, `DocumentationOperations`,
  `ProjectGuidanceInspection`, and `ProjectOnboarding`; app `OnboardingView`
  and `ProjectOverviewView`; bundled plugin skill/manifest; and the Xcode project
  version. Final test inventory is `ManagedGuidanceCompatibilityTests`,
  `ProjectDocumentationPreviewTests`, `ProjectGuidanceAcceptanceTests`,
  `OnboardingAcceptanceTests`, `ManagedDocumentationOperationsTests`,
  `ManagedDocumentEvidenceTests`, `RepositoryRootRelocationTests`,
  `DocumentationCallbackTests`, `ManagedEvidenceRenderingTests`, `AppRouteTests`,
  `CodexPluginLifecycleAcceptanceTests`, `ProjectDocumentationRenderingTests`,
  and `AgentBridgeTransportAcceptanceTests`.
- Verification: Initial six-test RED preceded 6/6 Core GREEN. Direct affected
  checks closed the existing-ledger and persisted phase-less-root regressions.
  Independent signed serial `xcodebuild test -project ReleaseRadar.xcodeproj
  -scheme ReleaseRadar -destination 'platform=macOS'
  -parallel-testing-enabled NO` passed 168/169; its sole stale 13-tool
  expectation was corrected to 19 and the affected malformed-input check
  passed 1/1. All 169 selected checks are covered. They include exact v2/v1/v3,
  package/prompt agreement, actual-tree read-only conformance and damaged-copy
  failures, schema 13, legacy import, binding/evidence/root continuity,
  replay/rollback, and presentation. Production broker/lifecycle registration
  tests remain excluded because they operate on owner services.
- Required corrections: Existing-ledger prerequisites prevent a handoff from
  invalidating its catalog. Folder inspection uses the persisted exact root
  owner independently of phase/onboarding routing. Stale schema/version/tool
  expectations and the native capture's overridden window title were corrected
  without changing production behavior. The transient inventory comparison
  passed unchanged in serial execution and final independent QA.
- Independent roles: `/root/m3c_implementer` authored M5;
  `/root/m3c_code_review` supplied Code, Architecture, targeted Security, and
  UX wording GO; `/root/m3c_qa` supplied final QA GO. The coordinator independently
  accepted runtime visuals. No Required findings remain.
- Runtime UX: Both native UI tests passed, covering 12 actual AX/window captures
  at 620 and 1100 widths. The coordinator inspected seven representative images
  against the accepted existing design. Status, recovery text, and update action
  remain readable. Durable examples: [current overview](evidence/mdcp-m5-overview-current-wide.png),
  [compact upgrade](evidence/mdcp-m5-overview-update-compact.png),
  [compact recovery](evidence/mdcp-m5-onboarding-unavailable-compact.png), and
  [wide recovery](evidence/mdcp-m5-onboarding-unavailable-wide.png).
- Package/candidate: App and plugin version 0.1.6; normalized plugin digest
  `dad143d88e77af7e2ed4523c17c31a24fdd8810e87d02a2ccfe2c39ba5558f8c`.
  Native Release build passed with normal signing and hardened runtime; app,
  agent tool, bridge, and lifecycle helper signatures verify under team
  `2UA854NLX4`. App/helper entitlements match their tracked definitions.
  Release packaged initialize/tools-list exposes exactly 19 typed schemas,
  defined in [AgentTools](../../ReleaseRadarAgentTools/main.swift) and verified
  by the focused tool-schema tests. The six documentation tools are additive;
  Task 4B is not exposed.
- Freeze boundary: M2–M5 command/query/result, schema-v13 evidence/root-bound
  accepted snapshots, inventory/adoption/transition/rebind, importer, guidance,
  plugin, exact tool schemas, and overlapping tests are accepted.
  `MDCP-COMPAT-1` is `dd32d8d0d7f333afc7367e5f2cc505d9e889c8cf`,
  verified clean and equal at HEAD, upstream, and live remote after push.
  M6–M8 consume that candidate; a frozen defect reopens only its owning slice.
- Durable artifacts: nine production/package/project files, thirteen tests,
  four screenshots, catalog/index metadata, and this ledger. Catalog coverage
  is 192 artifacts; the native check and `git diff --check` pass. M4 document
  paths, held files, manifests, and repository guidance remain unchanged.
  M5 native outputs and 26 exact synthetic directories were removed after
  process exit/provenance verification. Verified temporary app/checker copies
  remain under `.build/mdcp-compat-1/` for M6A; pre-existing outputs are preserved.
- M6A runbook limitation: direct supported plugin CLI installation leaves the
  app's managed lifecycle receipt stale. Its existing receipt update requires
  normal app startup, which also starts unrelated writers. Resolve the exact
  approved live workflow before claiming managed lifecycle success. This
  observation authorizes no new feature or owner operation.

## MDCP M2A — Authorized-Root Search Access Correction

- Trigger: M6A read-only owner inventory failed before catalog validation.
  A synthetic readable repository beneath a search-only ancestor reproduced
  unavailable/incomplete inventory even though direct leaf reads succeeded.
- Correction: `RepositoryDocumentReader` opens root-path directories with
  Darwin `O_SEARCH`. Directory-only semantics, no-follow traversal, identity
  stamps, relative file reads, stability checks, and sandbox grants remain
  intact. No storage, command, catalog, or signing contract changed.
- Direct verification: Native regression RED preceded GREEN 1/1. Signed serial
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar
  -destination 'platform=macOS' -parallel-testing-enabled NO` passed 64/64 across
  `RepositoryDocumentCatalogTests`, `RepositoryDocumentIndexTests`, and
  `ManagedDocumentationOperationsTests`. Independent QA repeated 64/64, covering
  search-only access, unchanged inventory/preservation, symlinks, replacement,
  read bounds, query authorization, and index refusal. `git diff --check` passes.
- Independent roles: Implementer `/root/m3c_implementer`; Code, Architecture,
  Security reviewer `/root/m3c_code_review`; QA `/root/m3c_qa`. All GO with no
  Required or Optional findings. Live sandbox verification remains M6A work.
- Replacement candidate: Release build and strict signatures pass with exact
  tracked entitlements, plugin 0.1.6 unchanged, and 19 packaged tool schemas.
  The replacement checker validates all 193 current artifacts. No owner app,
  store, broker registration, installation, or repository activation ran while
  correcting the source.
- Artifacts: Reader source, one focused regression in the existing test suite,
  and concise delivery/runbook updates are durable. Replacement app/checker
  copies under `.build/mdcp-compat-2/` remain temporary activation inputs. The
  prior `.build/mdcp-compat-1/` remains preserved. Correction-only native outputs
  and four identified synthetic host directories were removed under the owner's
  existing cleanup authorization after verified process exit. Protected owner
  material and both retained compatibility candidates remain untouched.

## MDCP M6A — Preparation and Initial Preflight

- Authorization: "m6a is approved" approved initial steps 1–3 and recommended
  target, protected-location, custody, and retention defaults. The subsequent
  "approved" authorized the concrete backup-first recovery: normal startup of
  the installed app, including its normal storage/notification/lifecycle
  effects, broker verification, graceful close, then resumed preflight.
- Recovery: Exact installed app/helper identities verified at version 0.1.5.
  Approved clients and lifecycle helper were quiesced after exact executable
  checks. The complete database/recovery set and app/plugin/configuration/
  guidance recovery material were protected. Normal installed-app startup
  restored its broker; the app quit and remaining lifecycle writer exited.
  Separate pre-recovery and post-recovery copies have identical file bytes.
- Read-only result: The frozen 0.1.6 candidate ran with explicit read-only mode
  and exact existing-store override. Its packaged AgentTools returned schema
  10, one saved root, seven `filePath` evidence rows, no binding, and ten fixed
  preservation domains. Full owner identities and results remain protected.
  The host quit and all captured owner files/sidecar absence matched baseline.
- Required investigation: Inventory is incomplete with `catalogInvalid` and
  unavailable guidance, without a catalog-validation error. Independent source
  diagnosis places that failure before validation, in reader creation or
  guidance reading. The live root has marker-free guidance and no catalog; the
  native unsandboxed checker reports the expected missing catalog, which alone
  would permit complete legacy inventory. Ancestor directory-read requirements
  are the bounded hypothesis; no actual sandbox-denial log was established.
  Live operations paused for a focused M2A regression and, if confirmed, the
  authorized frozen-contract correction procedure.
- Durable artifacts: The [activation runbook](task-briefs/2026-09-01-managed-repository-documentation-contract/m6a-owner-activation-runbook.md)
  is supporting procedure, not an execution approval or competing ledger.
  Exact targets, requests/results, backup manifests, immutable software copies,
  and owner screenshots are in the owner-approved protected companion. Retain
  them through M8 and at least the approved deadline; disposal is separately
  gated. Temporary tool-created screenshot originals remain retained under
  those owner-data terms. The frozen app/checker remain temporary build outputs.
- Remaining activation inputs: Exact corrected candidate, complete inventory,
  selected-root catalog deployment, disposable restoration/migration, install,
  guidance-only handoff, binding/replay, and precise recovery requests must be
  concrete before remaining live approval. The selected owner checkout has no
  catalog; staging in the development worktree does not activate that root.
- Plugin constraint: Supported external CLI installation can satisfy exact
  plugin identity while preserving/reporting its stale managed lifecycle
  receipt. Independent Architecture/Security review accepted that explicit
  limitation; clean lifecycle status and normal startup are not implied.
- Review: Earlier independent procedure review accepted backup of the prior
  migration snapshot, candidate-client inventory, explicit store overrides,
  verified host exits, and complete equality comparisons. M6A's final QA,
  Architecture, and Security/Privacy acceptance remains pending actual execution.
- Session boundary: Deliver M6A and its proposed reconciliation inventory, then
  stop. M6B and later slices require continuation in a new session; no adoption
  or document relocation is authorized by M6A.

This file is the current authoritative delivery state. Archived files are
historical evidence only.

Eligibility does not mean authorization. `Owner stopped: No` does not authorize
work. The owner must explicitly authorize inspection, implementation, testing,
or Git operations.

## Evidence index

- [Historical progress through RR-R10 Task 2B](archive/2026-08-31-progress-through-rr-r10-task-2b.md)
- [Accepted Ticket Tasks design](../design/release-radar-ticket-tasks-design.md)
- [ADR-005: Ticket task work plans](../architecture/ADR-005-ticket-task-work-plans.md)
- [Accepted RR-R10 implementation plan](../superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md)
- [Managed Repository Documentation Contract program plan](../design/managed-repository-documentation-contract.md)
- [ADR-006: Managed repository documentation contract](../architecture/ADR-006-managed-repository-documentation-contract.md)
- [ADR-007: Proportional delivery validation](../architecture/ADR-007-proportional-delivery-validation.md)
- [MDCP M2-M8 task briefs](task-briefs/2026-09-01-managed-repository-documentation-contract/)
- [Task 2A brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md)
- [Task 2B brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md)
- [Task 3 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-3-ticket-task-planning-policy-brief.md)
- [Task 4A brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4a-guard-every-accepted-path-brief.md)

## Managed Repository Documentation Contract M0–M1A

- M1 completed at checkpoint `cc96681`.
- M1A governance completed through accepted
  [ADR-007](../architecture/ADR-007-proportional-delivery-validation.md).
- Controlling references: the
  [managed-documentation design](../design/managed-repository-documentation-contract.md),
  [ADR-006](../architecture/ADR-006-managed-repository-documentation-contract.md),
  and ADR-007.
- Issue #2 files were accepted as operative RR-R10 output. Session authorship
  remains unknown, the preservation hold is resolved, and the external issue
  remains unchanged.
- The managed-documentation program retains priority over RR-R10 Task 4B.
- ADR-007 governs proportional validation for unopened work. This correction
  aligns the design, milestone briefs, checksum registry, and ledger with it.
- The owner approved M1 and M1A, including the propagation correction at
  `57f2633`, and authorized M2A–M8 as one dependency-ordered program.
- RR-R10 Task 4B becomes eligible only at `MDCP-COMPAT-1` and remains a
  separately authorized program. GitHub Issue #1 remains unopened.
- M2A subsequently completed; the current state above controls the handoff.

## MDCP M2A — Catalog Contract and Validator

- Status: Complete with all required reviews GO and no unresolved findings.
- Implemented: Core catalog v1 models, canonical snapshots/digests, bounded
  no-follow tree reads, collection/authority/checksum/link validation, explicit
  prior/current lifecycle and identity transitions, and the narrow transitional
  subtree rule. One synthetic fixture and focused XCTest coverage accompany
  the implementation; Xcode changes only exclude source-read fixture resources.
- Test-first evidence: runtime RED preceded implementation and each required
  correction. The final normal-signing `RepositoryDocumentCatalogTests` run
  passed 23/23 tests with no failures or skips; `git diff --check` passed.
- Native verification command: `xcodebuild test -project ReleaseRadar.xcodeproj
  -scheme ReleaseRadar -destination 'platform=macOS'
  -only-testing:ReleaseRadarTests/RepositoryDocumentCatalogTests`.
- Independent QA ran the signed 16-test and 22-test candidates, then inspected
  the final malformed-angle regression and its signed 23-test result.
- Implementer: `/root/m2a_implementer`. Code: `/root/m2a_code_review` — GO;
  QA: `/root/m2a_qa` — GO; Architecture: `/root/m2a_architecture_review` — GO;
  Security/Privacy: `/root/m2a_security_review` — GO. Required findings were
  corrected and only affected verification/re-review repeated.
- Historical-citation rule: an ordinary inline link beginning with the exact
  visible label `Historical ` may cite archived, non-authoritative evidence.
  Each occurrence still validates its target; other execution links and
  catalog first-read/authority rules remain strict. This preserves the existing
  progress history links for M4 without changing catalog schema.
- Durable changes: Core documentation sources, tests/fixture, Xcode membership,
  and this ledger. Temporary native build/log/result outputs remain under
  `.build/m2a/`; none were deleted.
- No owner application state, guidance, evidence, live repository catalog, or
  document paths changed. M2B is the next slice and remains unopened.

## MDCP M2B — Deterministic Index Tool

- Status: Complete; independent Code Review and QA GO, no unresolved findings.
- Implemented: Core `RepositoryDocumentIndexTool.check` and `write`, a separate
  `ReleaseRadarDocumentationTool` executable and Xcode scheme, deterministic
  collection/leaf/transitional navigation, lifecycle/authority/supersession
  output, strict markers, and byte preservation outside managed sections.
  M2A catalog/path logic validates the complete generated candidate before
  descriptor-relative per-file atomic swaps with bounded rollback.
- Verification: Test-first runtime RED/GREEN; native `ReleaseRadar` scheme with
  `-only-testing:ReleaseRadarTests/RepositoryDocumentIndexTests` and
  `-only-testing:ReleaseRadarTests/RepositoryDocumentCatalogTests` passed 37/37
  (14 index, 23 catalog), independently repeated by QA. Standalone tool build
  and synthetic CLI checks passed for stale/current read-only checks, golden
  output, exact changed paths, idempotence, human bytes/CRLF, and invalid input.
- Code Review identified one required cleanup-recovery provenance defect.
  Four new regression tests preceded its correction; the five affected checks
  (including existing atomic rollback) passed for implementer and independent
  QA. Cleanup failures now distinguish committed replacements, preserved or
  restored originals, and incomplete recovery. `git diff --check` passed.
- Implementer: `/root/m2b_implementer`; Code Review:
  `/root/m2b_code_review` — GO after affected re-review; QA:
  `/root/m2b_qa` — GO including affected verification.
- Durable artifacts: Core sources, executable and Xcode integration, 18 index
  tests, two golden fixtures under `Fixtures/RepositoryDocuments/indexes/`,
  and this ledger. Task-created build/log/CLI outputs and 14 finished isolated
  XCTest host directories were removed after exact-target verification under
  owner cleanup authorization. Pre-existing outputs were preserved.
- No live catalog/index, document path, owner application state, installed
  guidance, or agent bridge change. M2C is next eligible and remains unopened.

## Task 4A planning gate

- Status: Planning complete and independently accepted. Planning checkpoint
  `ab445fb327df03a1518e85fa6146bc3bf69de2fb` was pushed and verified exact at
  local HEAD, upstream, and live remote with ahead/behind `0/0` before
  implementation began. The owner separately authorized implementation,
  testing, the disclosed LaunchAgent side effect, and Git operations.
- Planning agent: `/root/task4a_planner`.
- Brief SHA-256:
  `779c448c852d69dd53f8782fbc87fc560f2b15bfc05084a17f3020a8c4b211b4`.
- Architecture: `/root/task4a_architecture_review` — GO, Required 0,
  Optional 0, Out-of-scope 0 on the initial brief; explicitly accepted the
  staged-create, revisionless-writer, AppModel callback, compatibility,
  transaction, trigger, file-scope, and Task 4B boundary decisions. The later
  bounded QA/Security corrections did not alter those decisions, so only the
  affected roles re-reviewed under the repository rule.
- QA/Test: `/root/task4a_qa_review` — initial NO-GO, Required 1, Optional 2,
  Out-of-scope 0; the brief was corrected to require executable Stage 1
  behavioral RED before the attributable Stage 2 interface compile RED, exact
  trigger error/rollback evidence plus source review, limited policy coverage,
  and disclosure of the existing transport suite's transient LaunchAgent
  registration. Affected-role re-review of the exact final brief returned GO,
  Required 0, Optional 0, Out-of-scope 0.
- Security/Privacy: `/root/task4a_security_review` — initial NO-GO, Required 1,
  Optional 0, Out-of-scope 0; the brief was corrected to reject embedded-NUL
  Accepted ticket IDs before dispatcher project lookup and AppModel
  authorization/request/reload, with indistinguishable zero-effect coverage.
  Affected-role re-review of the exact final brief returned GO, Required 0,
  Optional 0, Out-of-scope 0.
- TPM: `/root/task4a_tpm_review` — GO, Required 0, Optional 0, Out-of-scope 0.
- Delivery Management: `/root/task4a_delivery_review` — GO, Required 0,
  Optional 0, Out-of-scope 0.
- Resolved planning boundaries: creation-only Accepted writers use
  transaction-local Backlog staging, the Task 3 assertion with nil revision,
  then Accepted finalization; Rekon/sample/Debug remain revisionless; the
  owner AppModel path gains one internal revision-aware callback; Task 4B
  commands/tools/concurrency remain closed.
- Planning inventory: the Task 4A brief,
  `docs/delivery/task-briefs/SHA256SUMS`, and this ledger only.
- Implementation release gate: Satisfied. The planning inventory was committed
  alone, exact remote equality was verified, test authorization was obtained,
  and a fresh Implementer worked within the declared 15-path ceiling.
- No implementation, tests, Git operations, app launch/install, owner-data
  access, Release Radar mutation, external action, or temporary artifact was
  created during planning.

## Task 4A implementation gate

- Status: Complete, independently accepted, and terminally remote-exact.
- Planning base/checkpoint: `ab445fb327df03a1518e85fa6146bc3bf69de2fb`,
  verified exact at local HEAD, upstream, and live remote with ahead/behind
  `0/0` before implementation began.
- Implementer: `/root/task4a_implementer`.
- Candidate binary diff SHA-256:
  `9c219573cb1040bcdbc354f7403ce88f22bb89675cacdb9f4a990f3349b993b9`.
- Production inventory and SHA-256:
  - `ReleaseRadar/App/AppModel.swift` —
    `3485211c44d041beb3e108caffe28d54373e224a9543d64be301482189d07471`
  - `ReleaseRadar/Projects/DashboardSampleData.swift` —
    `245c5f5fe77b66c0d2160eec427a70ad1365899377fb00a4e27eb4cf7b344a5a`
  - `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift` —
    `f3b885b855f0d8694bfd08c50db51326f2dbd36c11fea2c722733d11af3d0e18`
  - `ReleaseRadarAgentTools/main.swift` —
    `660676c897e8f8a76a8c2a41d6d7bb3d9aade021ab220871d4e5c8bc90b05c43`
  - `ReleaseRadarCore/AgentBridge/AgentCommand.swift` —
    `e95db7a839776010754f56cd978638a0c6612eda7a178d7e9a28d9a039e72bad`
  - `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift` —
    `e147fb77b862b3d16da67e151364b5ded2f992778074424f3a62ab52bb7848e0`
  - `ReleaseRadarCore/Import/RekonArtifactImporter.swift` —
    `2e73e0b756fa304547f66b29619d44ca5a9a1508827d87ec113ec764f91b90cb`
- Test inventory and SHA-256:
  - `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift` —
    `70ce3a2e529770181b2353ebe5a62e9070493afbec72c6fbcdd959a18e078c31`
  - `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift` —
    `486b974a263f15f08d000b8db75e2b51ee4cb82b6063f5d84a264f58b0e4fb76`
  - `ReleaseRadarTests/AppRouteTests.swift` —
    `808db8f9d89a8a734436f55db3360a8464af44a106057373d25620aa3922f954`
  - `ReleaseRadarTests/NotificationAcceptanceTests.swift` —
    `882d0be909bcba33665eb94cda98d6170eb32362116d24016a6beb989a042962`
  - `ReleaseRadarTests/RekonImportAcceptanceTests.swift` —
    `26c911b0033b61ced360058bc61d17491012c9fc229184b5953aecf9f76b1b69`
  - `ReleaseRadarTests/ReviewAndGraphAcceptanceTests.swift` —
    `286e7d48a09f4e8d9e8f7014787c0fc6305e7b43ae0e81a0bf5ffc68ec373bf3`
  - `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift` —
    `46c24e1e7861ee8c0dffa9f6f9a8770afab7358865b59bdcfdded4287f2c3ea4`
- The fifteenth declared path,
  `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift`, remained
  byte-identical at SHA-256
  `828e7569a1be2854a6c795c11618d6b60a1fd4149290e52634eca8766663b54c`.
- Implemented behavior: every Accepted entry point now invokes the Task 3
  planning assertion in the same transaction before the final lane write;
  Accepted upserts and malformed embedded-NUL ticket IDs are rejected before
  lookup or side effects; revision is optional, Accepted-only, and positive;
  the owner AppModel path preserves bounded authorization, attribution, and
  reload behavior; and Rekon, sample, and RR9 Debug creation stage through
  Backlog before assertion and Accepted finalization.
- Test-first evidence: valid Stage 1 behavioral RED executed `162` tests with
  `156` passing and the six intended failures covering Accepted upsert,
  embedded-NUL preflight, Rekon, sample, and RR9 Debug bypasses. Valid Stage 2
  interface RED was the attributable missing transition-revision/AppModel
  surface compile failure and therefore executed zero tests as designed.
- Stop/resume evidence: Stage 1 first exposed an async XCTest-autoclosure test
  defect, then a second non-Sendable fixture compile defect triggered the
  required stop. The owner explicitly resumed its bounded correction. The
  next run exposed the sample snapshot fixture's invalid `goal_links` query
  and triggered the required stop; the owner explicitly resumed the bounded
  diagnosis and correction now verified here. Stage 2 had one bounded
  test-autoclosure correction, and the first GREEN compile had one bounded
  actor-isolation correction. No production behavior was weakened to clear a
  harness or fixture failure.
- Implementer GREEN passed all `174/174` selected tests with zero failures or
  skips. After Code Review and QA identified missing direct finalization,
  rollback-snapshot, and planned-upsert snapshot evidence, one bounded
  test-only correction across four already-declared test files again passed
  `174/174`; production remained frozen.
- Fresh independent QA repeated the seven-suite `xcodebuild test` selection
  from fresh DerivedData and passed `174/174`, split as policy `32`, bridge
  `24`, transport `5`, Rekon import `16`, App routes `59`, review/graph `12`,
  and notifications `26`, with zero failures, skips, or expected failures.
- Debug/package verification: a fresh `xcodebuild build` succeeded; code-sign
  verification passed; the app, helper, bridge, and launchd plist were
  present; direct packaged-helper initialize/tools-list returned exactly `13`
  tools; transition exposes only an optional integer revision with minimum
  `1`; upsert exposes no revision; and the helper TeamIdentifier is
  `2UA854NLX4`. The transient LaunchAgent and Mach service were absent after
  test cleanup, and the service probe exited `113`.
- Code Review: `/root/task4a_code_review` — initial NO-GO, Required 3,
  Optional 0, Out-of-scope 0; affected-role re-review after the bounded
  test-only correction returned GO, Required 0, Optional 0, Out-of-scope 0.
- QA/Test: `/root/task4a_qa_verifier` — initial NO-GO, Required 1, Optional 0,
  Out-of-scope 0; affected-role rerun returned GO, Required 0, Optional 0,
  Out-of-scope 0 with fresh `174/174` GREEN.
- Architecture: `/root/task4a_architecture_postreview` — GO, Required 0,
  Optional 0, Out-of-scope 0.
- Security/Privacy: `/root/task4a_security_verifier` — GO, Required 0,
  Optional 0, Out-of-scope 0.
- TPM: `/root/task4a_tpm_postreview` — GO, Required 0, Optional 0,
  Out-of-scope 0.
- Delivery Management: `/root/task4a_delivery_postreview` — GO, Required 0,
  Optional 0, Out-of-scope 1 for the nonblocking existing-test warning below.
- Checkpoint inventory: the fourteen changed candidate files above plus this
  ledger only, committed as `910b9653b661c6088d025bc6f6aea71271cff3b0`.
  The approved brief, checksum index, unchanged policy file, ephemeral
  DerivedData, result bundles, and logs were excluded.
- Nonblocking observation: independent QA saw one existing QoS priority-
  inversion warning in the admission-deadline test. It did not fail a test or
  recur as a main-thread responsiveness failure and is outside Task 4A.
- Open risk: None blocking Task 4A. Task 4B commands, tools, concurrency,
  schema, persistence, model, UI, project, and dependency work remain closed.
  No app install/launch, owner-data access, network access, external
  notification, Release Radar mutation, or other external action occurred.
- Temporary-artifact disposition: after the implementation checkpoint, an
  exact `/tmp` inventory for the Task 4A prefix returned no matching paths, so
  no deletion action was necessary and no Task 4A temporary artifact remains.
- Terminal checkpoint: `910b9653b661c6088d025bc6f6aea71271cff3b0`
  was pushed and verified exact at local HEAD, upstream, and live remote with
  ahead/behind `0/0` and a clean worktree. Task 4B is next eligible but remains
  closed pending separate owner authorization.

## Task 3 planning gate

- Status: Planning complete and independently accepted; Git operations and
  implementation owner-approved, with Implementer release gated on exact
  planning-checkpoint remote equality.
- Planning agent: `/root/task3_planner`.
- Architecture: `/root/task3_architecture_review` — GO, Required 0,
  Optional 1, Out-of-scope 0; explicitly approved omission of the unused
  policy-level `auditEventID` parameter.
- TPM: `/root/task3_tpm_review` — GO, Required 0, Optional 0,
  Out-of-scope 0.
- QA/Test: `/root/task3_qa_review` — GO, Required 0, Optional 0,
  Out-of-scope 0.
- Security/Privacy: `/root/task3_security_review` — GO, Required 0,
  Optional 0, Out-of-scope 2.
- Delivery Management: `/root/task3_delivery_review` — GO, Required 0,
  Optional 0, Out-of-scope 0.
- Planning inventory: the Task 3 brief, `docs/delivery/task-briefs/SHA256SUMS`,
  and this ledger only.
- Planning checkpoint: commit/push authorized. Exact local/upstream equality is
  required before a fresh Implementer begins. No implementation, tests, app or
  owner-data access, Release Radar mutation, or external mutation occurred
  before this checkpoint.

## Task 3 implementation gate

- Status: Complete, independently accepted, and terminally remote-exact.
- Planning base/checkpoint: `80a639cccf04d59a116194a1300e55d03ea0ed32`,
  verified exact at local HEAD, upstream, and live remote with ahead/behind
  `0/0` before implementation began.
- Implementer: `/root/task3_implementer`.
- Implementation inventory and SHA-256:
  - `ReleaseRadarCore/Planning/TicketTaskPlanningPolicy.swift` —
    `828e7569a1be2854a6c795c11618d6b60a1fd4149290e52634eca8766663b54c`
  - `ReleaseRadarTests/TicketTaskPlanningPolicyAcceptanceTests.swift` —
    `ecc270116ec4ab49fde59dcef696f76171b7fa2ff135a4226e04df47105e48ba`
- Test-first evidence: the selected RED exited `65` only because the policy and
  typed errors were absent after one bounded test-only correction. Final
  Implementer GREEN passed `73/73`, split `30` policy and `43` Store tests,
  with zero failures or skips. Fresh independent QA repeated the same selection
  and passed `73/73` with the same `30/43` split and zero failures or skips.
- Coverage: creation/revision/completion and `64`-operation limits; ASCII and
  multibyte UTF-8 boundaries; exact BINARY ID/label semantics; completion and
  lifecycle orthogonality; immutable history; acceptance revision/completeness;
  canonical ordering; task-only adjacent-state preservation; store-owned audit
  atomicity; late-audit rollback; and non-disclosing owner/error precedence.
- Stop/resume evidence: the first required stop followed the second failed
  GREEN mechanism; the owner explicitly resumed bounded diagnosis of the
  shared fixture, which removed an invalid migration-only fixture flag. The
  second required stop followed the resulting `27/29` policy run; the owner
  explicitly resumed diagnosis of the two named failures, both corrected as
  test defects. No tool, edit, test, or Git action occurred while stopped.
- Code Review: `/root/task3_code_review` — GO, Required 0, Optional 0,
  Out-of-scope 0 after affected-role closure.
- QA/Test: `/root/task3_qa_verifier` — GO, Required 0, Optional 0,
  Out-of-scope 0 after independent `73/73` GREEN.
- Architecture: `/root/task3_architecture_postreview` — GO, Required 0,
  Optional 0, Out-of-scope 0.
- Security/Privacy: `/root/task3_security_verifier` — GO, Required 0,
  Optional 0, Out-of-scope 0 after affected-role closure.
- TPM: `/root/task3_tpm_postreview` — GO, Required 0, Optional 0,
  Out-of-scope 0.
- Delivery Management: `/root/task3_delivery_postreview` — GO, Required 0,
  Optional 0, Out-of-scope 0.
- Checkpoint inventory: the two implementation files above plus this ledger
  only. Temporary DerivedData and result bundles are excluded.
- Open risk: None. No app launch/install, owner-data access, Release Radar
  mutation, or external mutation occurred.
- Terminal checkpoint: `e7b8d725178663b4d70b6984fbfdda3dcdffaf4a`
  was pushed and verified exact at local HEAD, upstream, and live remote with
  ahead/behind `0/0` and a clean worktree. Task 4A is eligible but remains
  closed pending explicit owner authorization.
