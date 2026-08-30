# Release Radar delivery ledger

## Goal

Deliver the signed native macOS MVP described by
`docs/superpowers/plans/2026-08-23-release-radar-mvp.md` on
`codex/release-radar-mvp`, with serialized subagent writes and no pull request.

## Preimplementation gates

| Role | Status | Required findings incorporated |
| --- | --- | --- |
| Planning | Complete | RR-01 through RR-10 task decomposition and dependencies. |
| Architect | Approved with corrections | Standalone boundary, five lanes, live-Codex feasibility, app-only SQLite authority, sandbox/signing, observer/bridge separation. |
| TPM | Conditional GO satisfied by plan revision | Early persisted board, bounded Codex gate, proportional evidence, autonomous dependency-safe sequence. |
| QA | Approved with acceptance evidence | Five focused service fixtures and one seeded wide/narrow UI flow; no bespoke harness. |
| Delivery Manager | GO | GitHub origin, source-of-truth reconciliation, per-slice ledger updates, and degraded continuation verified. |
| Security/privacy | Conditional pass incorporated | Migration recovery, authenticated IPC, bookmark scope, supported Codex observation, device-only Keychain, minimal Pushover data, atomic outbox. |

## Repository

- Local: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
- Remote: `https://github.com/joeroberts/release-radar`
- Branch: `codex/release-radar-mvp`
- Pull requests: prohibited by owner direction for this goal.

## Current gate

- Baseline release state: RR-10 and the Release Radar MVP remain accepted and release-ready at product HEAD `271fcd4`.
- Current remediation state: **Done and Accepted.** On 2026-08-27, the owner confirmed that the installed `/Applications/ReleaseRadar.app` no longer produces the SQLite authorization error, that the pending tracking state persists across relaunch, and that the remediation is explicitly **Done/Accepted**. The accepted product implementation is commit `353322c`; the exact verified Release bundle remains preserved under `dist/` and installed under `/Applications`.
- Active delivery gate: **Exact-root repository-handoff correction Done and
  Accepted.** Signed app/plugin `0.1.5` is installed; the owner completed the
  handoff from the exact authorized RekonDesignSystem root, confirmed the
  immediate running-UI guidance state, then confirmed `RR-R8` on the live Phase
  Board. The audited final transition placed `RR-R8` in Accepted.
- Active RR-R9 gate: **COMPLETE — product Accepted, Required 0, Optional 0;
  terminal Git sequence complete; no RR-R9 work remains.**
  The one accepted live command and its
  immediate/relaunch `RR-ROADMAP` evidence remain definitive historical
  activation evidence. Later valid owner UI choices set the current persisted
  pointer to **Post-MVP reported-defect remediation**. The bounded test-host
  isolation correction and its corrected installed product are independently
  accepted with Required 0. The exact authorized tracking request moved
  `RR-R9` to **Accepted** once, audit
  `286C23C2-19D9-4C6F-B219-AFC1440E4FA8`; direct and independent UI readback
  verified the exact outcome, counts 0/0/0/0/9, unchanged Post-MVP pointer, and
  no later phase-selection event. The whole RR-R9 product outcome is accepted.
  Accepted-delivery commit `10e844fe801642a4a9176eb8813d75a958b3246e`
  is on `origin/codex/release-radar-mvp` with exact remote-SHA match and 0/0
  upstream counts. Ledger evidence commit
  `985d9eb0f6b8e3c93fa079b27e566e4fe70d67b1` is also pushed with exact
  `git ls-remote` match and 0/0 upstream counts. The RR-R9 goal is complete.
- Active RR-R10 gate: **CORRECTED IMPLEMENTATION PLAN OWNER-CONFIRMED;
  TASK 1 PLANNING BRIEF IS THE NEXT GATE. No product code has begun.**
  The owner approved the corrected phase-scoped Delivery Goals contract, the
  six-goal RR-ROADMAP catalog, and directed that this prevention-and-
  roadmap-repair outcome be governed by **Post-MVP reported-defect
  remediation**. The active Codex goal is the complete outcome: add first-class
  phase-scoped Delivery Goals, prevent incomplete ready phases, repair the
  Established product roadmap into owner-approved goals, independently verify
  the result, obtain owner acceptance, and remotely verify every accepted
  delivery checkpoint. Bounded chunks are complete, independently verified
  review checkpoints under this one goal; they are not reduced feature
  commitments.
- RR-R10 Codex-goal continuation: on 2026-08-29 the owner explicitly directed
  the stalled goal to restart. The goal service correctly rejected creating a
  duplicate because this objective is still unfinished. Its read API continues
  to report the prior `blocked` status and exposes no resume mutation, so work
  continues on the same objective under the owner's resume instruction; no
  replacement goal or ticket was created and no completion/blocked mutation
  was fabricated.
- RR-R10 board evidence: audited request
  `5DFCA88C-30DF-414F-B884-A01E7984EF28` created `RR-R10` in **In progress** on
  `release-radar-post-mvp-remediation`; audit event
  `24C8BE78-2FF3-43BD-82FF-E67E7C21B518`. The configured plugin wrapper closed
  its transport without a result. After direct UI readback proved the card
  absent and a normal app relaunch restored the missing BridgeAgent, the exact
  same idempotent request was replayed through the installed signed MCP helper
  and returned `isError: false`. Running-app readback then verified the Post-MVP
  board at 0/1/0/0/9 and the exact `RR-R10` outcome in In progress. No SQLite
  access was used.
- RR-R10 owner-attention evidence: request
  `CBBA1301-646A-47FC-A7B0-6F35D78EB9E0` recorded blocker
  `RR-R10-BLOCKER-DESIGN-APPROVAL`, audit event
  `D742AFE8-2CFA-49BE-AB77-EC17F5A6F6DD`. Request
  `57A0E7C5-AA7D-4CA7-B54A-E057CC703CDB` then moved `RR-R10` to **Blocked**,
  audit event `0D594EBA-256F-4842-9BEC-22559F360D76`. Fresh running-app
  readback verified the Post-MVP board at 0/0/0/1/9, the card's one blocker,
  and the exact owner-attention reason in the selected-ticket inspector. The
  approval-needed Pushover alert had already been delivered, so no duplicate
  notification was sent. Both mutations used the installed signed MCP helper;
  no SQLite access was used.
- Current RR-R10 design gate: the complete contract and exact catalog are
  durably recorded in
  `docs/superpowers/specs/2026-08-29-delivery-goals-roadmap-readiness-design.md`,
  with the architecture decision in
  `docs/architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md` and the
  bounded board contract in
  `docs/design/release-radar-delivery-goals-phase-board-design.md`. The owner
  added the explicit invariant that Accepted tickets are terminal and are never
  reopened; rework or later defects require a new Backlog ticket. The written
  artifacts passed their initial self-review and the owner approved their
  direction. The first implementation-plan reviews exposed contradictions that
  required narrow corrections to those controlling artifacts, and the owner
  subsequently confirmed the corrected semantics. The granular test-first
  implementation plan is durably recorded at
  `docs/superpowers/plans/2026-08-29-delivery-goals-roadmap-readiness.md`; it
  preserves the complete outcome, independent per-task gates, the terminal
  Accepted-ticket/no-reopen invariant, and the owner-corrected Git cadence:
  commit/push the approved planning package now, then commit/push each complete
  task only after its required independent gate returns GO with Required 0.
  Partial or unverified task work is never committed. Before coding, any task
  forecast to exceed roughly eight hours of agent implementation work, or too
  large for one coherent review, must be split into smaller dependency-safe,
  fully testable tasks with separate verification and Git checkpoints. Current
  artifact hashes are plan
  `c86cab9fcfe90c31dfa92331dee66c154e27b16ebfc2ba4d4eb817edf3bec0c2`,
  spec `c1327bf8272a0a76b8e7eb235f41f149908b1de783d3fdd058425d416b6d7ed8`,
  ADR `cb6fbb55585fc9493f255e7efe83eccb9d9d64c0492e1d11b3d5510799254420`,
  and board contract
  `04f518854f288fc9cd1d943301f3bd8a89b7aa903d35b04e4ed12d6c5ece7381`.
  No RR-R10 product code, schema migration, UI implementation, installed
  repair, or ticket transition has begun.
- RR-R10 independent design review history: the pre-approval review was
  **NO-GO for implementation; architectural direction accepted.** Fresh
  Architecture, TPM/Delivery, and QA reviews agreed
  that a separate phase-owned Delivery Goal model, additive migration, atomic
  revision-aware plan finalization, preserved five lanes, and explicit Codex-
  execution separation are the correct direction. Required corrections before
  owner approval include complete readiness and lifecycle state machines;
  enforcement across every ticket writer and lane bypass; exact structural-
  revision invalidation; a migration-safe RR-R10 bootstrap; non-mutating phase
  browsing; complete goal outcome/acceptance contracts; coherent treatment of
  the conditional distribution and independent decision work; explicit audit,
  Activity, archive-guard, recovery, accessibility, and installed-repair
  evidence. The approved written artifacts incorporate those corrections and
  received the post-persistence owner approval. The first plan review at SHA
  `074cf74923f3243d01c3c072d3f244edbe026a49d0e5ad8eb7ee8b49559f3dec`
  returned NO-GO: Architecture Required 5, TPM/Delivery Required 8, and QA
  Required 10. The incorporated corrections now distinguish empty
  finalization from completed Ready state; use a genuine v10 fixture; remove
  post-migration continuation modes; bind lifecycle to phase revision and
  owner-app acceptance; enforce dependency/blocker gates; attribute bulk
  assignments to tickets; exercise behavioral accessibility and the full
  scheme without pre-gate owner launch; preserve captured active state; and
  close RR-R10/RR-DG-R10 through their valid lifecycles. Focused closure
  re-reviews against exact plan SHA
  `d14c89e67acc15fb9f7490ab88840615d5508a920d7893b8fee364377a156eeb`
  returned Architecture **GO, Required 0**, TPM/Delivery **GO, Required 0**,
  and QA **GO, Required 0**. QA's one final regression gap was closed by
  current-revision-but-Draft rejection/re-finalization tests for both allowed
  direct lifecycle transitions. No ticket transition was made after owner
  approval.
- RR-R10 corrected-plan owner attention: after Required-0 closure review, one
  normal-priority Pushover notification was delivered requesting owner
  confirmation of the review-driven semantic corrections. It created no
  Release Radar ticket, blocker, lane, or goal-state mutation.
- RR-R10 corrected-plan owner confirmation: the owner explicitly approved the
  corrected controlling artifacts and independently accepted implementation
  plan. The owner then corrected the Git cadence to avoid giant commits:
  commit/push the currently approved planning package, then commit/push every
  complete task after full verification, splitting a task before coding when
  its forecast or review surface is too large. This replaces the prior agent-
  inferred single-terminal-commit interpretation.
- RR-R10 approved planning-package Git checkpoint: commit
  `363a2c7acb5a89405bc282bc8186a5f69d4c7d8d` contains only the five approved
  RR-R10 planning/design/architecture/ledger paths and was pushed to
  `origin/codex/release-radar-mvp`. Fresh verification returned the same exact
  local and remote SHA with ahead/behind `0/0`; unrelated `default.profraw`
  remained untracked and untouched.
- RR-R10 Task 1 planning split: a fresh Planning agent assessed the original
  persistence task at roughly 9–12 agent-working hours and split it without
  reducing scope. Task 1A freezes and proves the genuine schema-v10 fixture
  before any v11 production edit; Task 1B then delivers all public models and
  the complete additive v11 migration/preservation contract. Canonical briefs
  are registered at SHA-256
  `e065f997e625cd8f1e0f8d62214b09d43d74f6bec9fdab4fbe6a85af112e8576`
  and
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`.
  The plan's local split amendment is SHA-256
  `c86cab9fcfe90c31dfa92331dee66c154e27b16ebfc2ba4d4eb817edf3bec0c2`.
  The corrected Git boundary creates a planning-only checkpoint first,
  containing the owner-directed `.gitignore` change, both registered briefs,
  checksum index, split amendment, and canonical planning/review evidence.
  Only after exact remote verification may Task 1A generate the fixture; its
  separate accepted commit contains only the two fixture artifacts plus
  postimplementation ledger evidence. Task 1B later includes its canonical
  evidence with the verified product/test diff. `default.profraw` is now
  ignored and remains untouched.
- RR-R10 Task 1 initial brief review: exact prior brief SHAs
  `6a5f4806330d66c50453ffdaa1bcabdb2e993c786ccff5ea4893c32acf92440c`
  and
  `ee92a5693df7caa4ad944da0d5f870c05792741d61a394399598528add655443`
  received TPM and Delivery Management GO/Required 0. Architecture returned
  Task 1A NO-GO/Required 1 for the circular planning/implementation Git gate
  and Task 1B GO/Required 0. QA returned Task 1A NO-GO/Required 1 because the
  fixture inspection omitted owner-data tables, exact defaults, and complete
  schema inventory; it returned Task 1B NO-GO/Required 1 because no deliberate
  late-v11 rollback test exercised the additive migration. Security/Privacy
  independently confirmed the Task 1A inspection defect and returned Task 1B
  content GO/Required 0. The corrected exact artifacts now separate the
  planning-only remote checkpoint, enumerate every v10 application table plus
  exact default/schema inventory, and require a test-only abort-trigger failure
  after v11 work begins with exact original/snapshot rollback and recovery.
  The first closure pass accepted Task 1B with Required 0 but Architecture and
  QA correctly retained Task 1A NO-GO/Required 1 because the exact schema CTE
  still omitted three real v8 indexes. The final Task 1A brief now includes
  `observed_goals_project_identity_unique`,
  `ticket_goal_links_project_ticket_unique`, and
  `ticket_goal_links_project_goal_unique`, making the expected v10 inventory
  exactly 23 tables, seven explicit indexes, and four triggers.
- RR-R10 Task 1 final exact-hash closure: against plan
  `c86cab9fcfe90c31dfa92331dee66c154e27b16ebfc2ba4d4eb817edf3bec0c2`,
  Task 1A brief
  `e065f997e625cd8f1e0f8d62214b09d43d74f6bec9fdab4fbe6a85af112e8576`,
  and Task 1B brief
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`,
  Architecture, QA/Test, and Security/Privacy each returned GO with Required 0,
  Optional 0, Out-of-scope 0 for both briefs. TPM and Delivery Management each
  returned Task 1A GO with Required 0/Optional 0/Out-of-scope 0 and Task 1B
  content GO with the same counts while retaining its dependency block. These
  verdicts close the circular checkpoint, complete fixture inventory, and
  late-migration rollback findings. Task 1A is released only through its
  planning-only Git checkpoint; Task 1B is not released.
- RR-R10 split-planning Git checkpoint: commit
  `def687a084ddf074c9e914dd127c820ea563669e` contains exactly `.gitignore`,
  the split plan, both registered Task 1 briefs, the task-brief checksum index,
  and canonical planning/review evidence. It was pushed to
  `origin/codex/release-radar-mvp`; fresh `git ls-remote` verification returned
  the exact same SHA with ahead/behind `0/0`. The worktree was clean,
  `default.profraw` was ignored, `StoreMigrations.currentVersion` remained 10,
  and no fixture, product file, app/board/ticket, owner-data, or external state
  existed or changed at this checkpoint.
- RR-R10 Task 1A first execution evidence: the approved negative generator
  precondition check failed once at `XCTUnwrap` as expected with no fixture.
  The first GREEN command then failed safely at the same boundary because the
  Release Radar hosted XCTest process did not inherit the arbitrary parent-
  shell `RR_SCHEMA_V10_FIXTURE_OUTPUT` variable. It returned `xcodebuild` exit
  65, created no fixture, and made no production or durable test-source change;
  the temporary generator was removed. Systematic diagnosis confirmed that
  `xcodebuild build-for-testing` emits one editable `.xctestrun` whose test-
  target `EnvironmentVariables` dictionary is honored by
  `test-without-building`. The corrected controlling command therefore copies
  that specification under `/tmp`, injects only the fixture path there, and
  runs only the generator once with parallel testing disabled. The correction
  is fixed at plan SHA-256
  `b0bf2116a7c1cd0a51e2e31666c94bc249151caffae51280afb2ef63d2d961ac`
  and registered Task 1A brief SHA-256
  `c81d2fd2d432c8f4fc5c3355a1c4dec52a0e95d4ef8638a613a343f240cd3938`.
  Task 1B remains unchanged at
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`.
- RR-R10 Task 1A attachment-command format correction: Security/Privacy
  returned NO-GO/Required 1 after inspecting the already-consumed prior-run
  `.xctestrun`, whose post-test representation exposed a top-level environment
  dictionary. A fresh read-only `build-for-testing` into a new absent
  DerivedData path produced the actual pre-execution format-2 specification:
  top-level `EnvironmentVariables` was absent, `TestConfigurations` was an
  array, and the sole test target contained the nested `EnvironmentVariables`
  dictionary used by the reviewed insertion. The controlling command now uses
  a new absent DerivedData path and fails closed unless those exact structural
  assertions pass before it copies or mutates the specification. It does not
  adopt the proposed top-level insertion because fresh direct evidence shows
  that key path is absent at the point the command performs the mutation.
  The correction
  requires fresh exact-hash Architecture, QA/Test, Security/Privacy, TPM, and
  Delivery Management GO before any successor Implementer retry; no ticket,
  board, goal, owner data, or external state changed.
- RR-R10 Task 1A execution-command correction closure: against exact plan
  `b0bf2116a7c1cd0a51e2e31666c94bc249151caffae51280afb2ef63d2d961ac`
  and registered Task 1A brief
  `c81d2fd2d432c8f4fc5c3355a1c4dec52a0e95d4ef8638a613a343f240cd3938`,
  independent Architecture, QA/Test, Security/Privacy, TPM, and Delivery
  Management each returned **GO, Required 0, Optional 0, Out-of-scope 0**.
  They confirmed that the supported `build-for-testing`/temporary
  `.xctestrun`/`test-without-building` flow crosses only the hosted-test
  environment boundary, remains fail-closed and single-run, preserves the
  complete fixture assertions and Task 1B dependency block, and changes no
  persistent scheme, project, product, owner data, board, ticket, or goal.
  The correction must be committed, pushed, and remotely verified exactly
  before a fresh successor Implementer may run it.
- RR-R10 Task 1A execution-command correction checkpoint: commit
  `b62dcd12f6740c156ffd87b16c4e5741b4b9783c` contains exactly the corrected
  plan, registered Task 1A brief and checksum index, and canonical failure/
  review evidence. It was pushed to `origin/codex/release-radar-mvp`; fresh
  `git ls-remote` readback returned the exact same SHA and ahead/behind `0/0`.
  The fresh successor Implementer is therefore released for Task 1A only.
- RR-R10 Task 1A sandbox-boundary evidence: the fresh successor ran the exact
  corrected generator once. `build-for-testing`, exact `.xctestrun` selection,
  environment injection, and selected `test-without-building` execution all
  worked, but the sandboxed test host correctly denied direct creation of the
  repository fixture directory with Cocoa error 513 / POSIX error 1. The run
  exited 65; no fixture, checksum, product diff, or durable test-source diff
  exists, and the generator was removed without retry. Existing test practice
  and the captured `.xcresult` confirm the bounded correction: generate the
  empty v10 database under `FileManager.default.temporaryDirectory`, retain its
  closed bytes as a passing-test `XCTAttachment`, remove the sandbox-local
  source file, then let the parent process export that one attachment from the
  result bundle and copy it to the absent repository fixture path. This keeps
  the app sandbox and SQLite authority intact and requires a new exact-hash
  independent closure plus remote planning checkpoint before another fresh
  Implementer run. The final correction is fixed at plan SHA-256
  `b256ce5084e2af640d493f73d4f4a3c0ce927e0895df7023134637b4729b86de`
  and registered Task 1A brief SHA-256
  `9522656de14199db53a1338299fa131871837583ef3b73b6d5b1986ac0c02980`;
  Task 1B remains unchanged at
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`.
- RR-R10 Task 1A attachment-correction exact-hash closure: Architecture,
  QA/Test, Security/Privacy, TPM, and Delivery Management each returned
  **GO, Required 0, Optional 0, Out-of-scope 0** against plan
  `b256ce5084e2af640d493f73d4f4a3c0ce927e0895df7023134637b4729b86de`
  and registered Task 1A brief
  `9522656de14199db53a1338299fa131871837583ef3b73b6d5b1986ac0c02980`.
  Fresh evidence proves the format-2 metadata and exact one-configuration/one-
  target nested environment structure before mutation; all actual-run,
  result, export, fixture, and checksum paths are absent; product and temporary
  generator-source diffs are empty. This closes the prior direct-write,
  sandbox, stale-instruction, release-gate, and test-run-format findings. The
  generator remains closed until this four-file planning correction is pushed
  and remotely exact at ahead/behind `0/0`.
- RR-R10 Task 1A attachment-correction checkpoint: commit
  `1e0011bc4d7f6f580929740c4e42d571057249d7` contains exactly the final plan,
  registered Task 1A brief and checksum index, and canonical failure/review
  evidence. It was pushed to `origin/codex/release-radar-mvp`; fresh remote-ref
  readback returned that exact SHA with ahead/behind `0/0`. The actual-run
  DerivedData, result, attachment-export, fixture, and checksum paths remain
  absent, so one fresh Task 1A Implementer is now released for the attachment
  generator only. Task 1B remains blocked.
- RR-R10 Task 1A passing-result/export evidence: the fresh Implementer ran the
  final attachment generator exactly once. The explicit result reports 1 total,
  1 passed, 0 failed, 0 skipped, and 0 expected failures, and the temporary
  generator source was removed immediately. `xcresulttool export attachments`
  then produced exactly one nonfailure attachment for the selected test, but
  Xcode rendered its suggested name as
  `release-radar-v10_0_D88C301A-B66A-4624-9EC6-A2B7A33B343A.sqlite` rather than
  the brief's exact base-name expectation, so validation stopped before the
  repository directory/copy/checksum. No fixture, checksum, product diff, or
  durable test-source diff exists. Read-only inspection of exported basename
  `78312C8A-9AEF-471D-8BB6-0C89884440FF` reports a SQLite database at user
  version 10, integrity `ok`, 34 non-internal schema objects, and SHA-256
  `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`.
  The corrected contract accepts only the observed base/index/uppercase-UUID/
  `.sqlite` pattern plus all existing exact manifest and safe-export checks.
  Recovery must consume this passing result and existing export without
  rerunning either the generator or attachment export, and remains blocked on
  fresh exact-hash review plus a pushed/remotely exact planning checkpoint.
  The correction is fixed at plan SHA-256
  `2cdf2e7c67319077b27e7bf9f4f0889f0015c59708835a290cca16c482204328`
  and registered Task 1A brief SHA-256
  `d9e77073932c3f46a4fba210f9c6ab0f150fdcb11b089529dcc87010d492cded`;
  Task 1B remains unchanged at
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`.
- RR-R10 Task 1A preserved-result recovery closure: against exact plan
  `2cdf2e7c67319077b27e7bf9f4f0889f0015c59708835a290cca16c482204328`
  and registered Task 1A brief
  `d9e77073932c3f46a4fba210f9c6ab0f150fdcb11b089529dcc87010d492cded`,
  Architecture, QA/Test, Security/Privacy, TPM, and Delivery Management each
  returned **GO, Required 0, Optional 0, Out-of-scope 0**. They verified the
  preserved 1/1 passing result, exact one nonfailure manifest attachment,
  strict uppercase UUID name validation, safe basename, pinned exported-byte
  SHA, v10/integrity/privacy provenance, absent destination, no source/product
  diff, and no generator/export rerun. The planning correction must be pushed
  and remotely exact before one fresh recovery Implementer validates and copies
  the preserved bytes, creates the checksum, and runs the complete assertions
  and regressions.
- RR-R10 Task 1A preserved-result recovery checkpoint: commit
  `40bcbb3e3bcbd9c80ea3d183a3751c0d80cc148a` contains exactly the corrected
  plan, registered Task 1A brief and checksum index, and canonical passing-
  result/review evidence. It was pushed to
  `origin/codex/release-radar-mvp`; fresh remote-ref readback returned the same
  exact SHA with ahead/behind `0/0`. One fresh recovery-only Implementer is now
  released under the no-generator/no-export/no-source-edit boundary. Task 1B
  remains blocked.
- RR-R10 Task 1A recovery implementation evidence: the fresh recovery-only
  Implementer ran the exact preserved-result command with exit 0 and did not
  rerun build, generator, test execution, or attachment export. The preserved
  result remained 1/1 passed with zero failed/skipped/expected failures; the
  exact one nonfailure attachment and strict Xcode name validated; exported
  bytes matched pinned SHA-256
  `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`
  before the one absent-destination copy. The durable fixture is 278,528 bytes
  with that same digest, and its local `SHA256SUMS` verifies. The complete
  fail-fast SQLite block exited 0: user version 10; zero owner/nondefault rows;
  exact four alert defaults; exact `release-radar`/`neverInstalled` lifecycle
  singleton with null managed fields; no v11 continuation column; exact 23
  tables, seven explicit indexes, four triggers, and 34 total non-internal
  objects; zero foreign-key violations; integrity `ok`. The exact Store and
  plugin-lifecycle regression selection reports `TEST SUCCEEDED`, 50 total,
  50 passed, zero failed/skipped/expected failures at
  `/tmp/release-radar-rr-r10-task1a-regression/Logs/Test/Test-ReleaseRadar-2026.08.30_11-27-44--0400.xcresult`.
  `StoreAcceptanceTests.swift` and all product/project files have no diff. Only
  the fixture and its checksum are Task 1A implementation outputs.
- RR-R10 Task 1A postimplementation closure: the independent Code Reviewer,
  QA/Test verifier, Architect, Security/Privacy verifier, TPM, and Delivery
  Manager each returned **GO, Required 0, Optional 0, Out-of-scope 0** on the
  exact registered plan and brief hashes. QA independently reran the exact
  regression selection from a fresh temporary DerivedData path and reported 50
  total, 50 passed, zero failed/skipped/expected failures at
  `/tmp/release-radar-rr-r10-task1a-qa-regression.t14DmX/DerivedData/Logs/Test/Test-ReleaseRadar-2026.08.30_11-32-20--0400.xcresult`.
  The reviews independently confirmed the pinned fixture digest and byte
  identity, complete SQLite assertions, privacy-empty owner data, exact default
  rows, absence of v11 continuation state, no product/test/project/signing/
  entitlement/sandbox diff, and the exact three-path commit boundary.
- RR-R10 Task 1A accepted completion: commit
  `ace6c59efc3c95ee23542f8ae9e31fdfb26f6054` contains exactly the schema-v10
  fixture, fixture-local checksum, and postimplementation delivery evidence.
  It was pushed to `origin/codex/release-radar-mvp`; fresh remote-ref readback
  returned that exact SHA with ahead/behind `0/0`, and the worktree was clean.
  Task 1A is complete and its immutable fixture/checksum boundary is now open
  for Task 1B consumption.
- RR-R10 Task 1B implementation evidence: against registered brief SHA-256
  `e3d9d4e00e8081d16330d55e34dcd2717350030eb4711cf9da94eb45a75e17ff`,
  the fresh Implementer delivered the public Delivery Goal/phase-plan values,
  additive schema-v11 migration and manifest, immutable goal ownership,
  migration-only ticket continuation, fail-safe Legacy-unassessed plans,
  composite project/phase enforcement, and authoritative deferred assignment
  history in exactly the five registered implementation/test paths. The
  accepted schema-v10 fixture and checksum remain byte-identical at SHA-256
  `9fae45086de5581ae0c34c904362fb03d10ecfb9f5f8b6c5a428e762f1ce6559`.
  Initial independent review found three required defects in negative-test
  isolation, goal-ownership immutability, and continuation-column manifest
  validation. The Implementer corrected each test-first. Security then proved
  the first manifest correction could be spoofed by embedding expected text in
  an inert constraint; the final correction compares normalized SQL against the
  complete canonical v11 `tickets` definition and retains that semantic
  counterfeit as a regression test.
- RR-R10 Task 1B postimplementation closure: final independent Code Review,
  QA/Test, Architecture, Security/Privacy, TPM, and Delivery Management each
  returned **GO, Required 0, Optional 0, Out-of-scope 0** on the exact final
  diff. Fresh QA reports 37/37 focused Store tests and 58/58 combined Store and
  plugin-lifecycle tests, with zero failed/skipped, at
  `/tmp/release-radar-rr-r10-task1b-finalqa.1dqOBB/focused.xcresult` and
  `/tmp/release-radar-rr-r10-task1b-finalqa.1dqOBB/regression.xcresult`.
  Direct probes confirm phase and cross-project goal moves reject and roll back
  without audit residue; both weak and text-embedding counterfeit continuation
  schemas reopen unavailable; every negative assignment-history case reaches
  its intended CHECK or foreign-key constraint; and observed Codex-goal,
  recovery, archive, signing, entitlement, sandbox, credential, and bookmark
  boundaries remain unchanged.
- RR-R10 Task 1B accepted completion: commit
  `b711229a109c1a58c9616e4ff907afb18cd4f958` contains exactly the five
  registered model/store/test paths plus postimplementation delivery evidence.
  It was pushed to `origin/codex/release-radar-mvp`; fresh remote-ref readback
  returned that exact SHA with ahead/behind `0/0`, and the worktree was clean.
  Task 1B is complete; its schema-v11 storage/model contract is now the
  immutable dependency boundary for Task 2.
- RR-R10 Ticket Tasks course-correction owner acceptance: on 2026-08-30 the
  owner accepted the exact first-class Ticket Tasks planning package presented
  in this Codex task and directed execution to proceed. The accepted artifacts
  are the Ticket Tasks design at SHA-256
  `c1def10263d0a71dac042472faa8113d0ba7ecfc896c0ab2d64854911922ab08`,
  ADR-005 at SHA-256
  `6c3c35d62249c0d267c353c7f4c7d7d9adb738be3cd0c9d4f2753b101ff6eab5`,
  and the corrected implementation plan at SHA-256
  `2c3b40e99ff2f280fad574a9c2f939d4e959c77bdded95b9c44070a1b34bfea1`.
  This correction preserves accepted Tasks 1A and 1B and replaces only the
  unopened Task 2-and-later sequence. Its owner-visible catalog contains 16
  stable rows: Task 1A and Task 1B checked; Tasks 2A, 2B, 3, 4A, 4B, 5, 6, 7,
  7A, 8, 9, 10, 11A, and 11B unchecked. Ticket Details shows titled read-only
  task rows; cards show only the active non-superseded total as `☷ N`; no
  completed/total fraction, percentage, LOE, or inferred execution state is
  persisted or presented.
- RR-R10 Ticket Tasks final planning review: Architecture, TPM, QA/Test,
  Delivery Management, Security/Privacy, and UX/Accessibility each returned
  **GO with Required 0** against those exact hashes. The package requires the
  authorized schema-v10/start-state proof before RR-R10 leaves Blocked, a
  bounded independently approved owner-store backup/restore runbook before
  installation, durable completion-revision reconciliation before successor
  release, and installed repair rows that remain unchecked until the corrected
  installed behavior and preserved owner state are independently verified and
  remote-exact. Architecture recorded two nonblocking implementation-brief
  refinements; neither changes the accepted outcome or releases extra scope.
- RR-R10 Ticket Tasks planning Git checkpoint: commit
  `ab0a08811684265ea0dadc8e370c79a3c8f559ee` contains exactly the accepted
  Ticket Tasks design, ADR-005, corrected implementation plan, and owner-
  acceptance ledger record. It was pushed to
  `origin/codex/release-radar-mvp`; fresh fetch, upstream readback, and
  `git ls-remote` each returned that exact SHA with ahead/behind `0/0`. The
  three accepted artifact hashes remained byte-identical after the push, and
  the worktree was clean.
- Next eligible RR-R10 work: **Perform the authorized typed/UI and exact
  installed-identity preflight before resolving
  `RR-R10-BLOCKER-DESIGN-APPROVAL` or moving RR-R10 from Blocked to In
  progress.** Any mismatch stops before mutation for a bounded reviewed
  correction. After successful audited lane/blocker readback, one fresh
  Planning agent may produce the complete Task 2A brief; Task 2A RED and every
  later product edit remain blocked until that exact brief receives the
  required independent release.
- Next eligible work: **None for RR-R9.**
  The registered controlling correction brief is
  `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-brief.md`
  at SHA-256
  `2d4c855adecab3c20da618f8147f60aa42d8da903ea000e5675e58eb3f7571de`.
  The accepted correction remains present at blobs
  `e0965e340b0c6e49451ecdcf31188c301cf9b8ba` and
  `e0206a8c3fef481c75603d324904a279aabeba06`. Provenance classification, both
  terminal commits, both pushes, and exact remote verification are complete.
  This final canonical completion marker is the sole local delta and may be
  committed and pushed as a status-only record; it intentionally does not
  self-reference that future commit hash. Excluded `default.profraw` must remain
  untouched. Every product mutation, active-phase command, SQLite access, and
  unrelated roadmap gate remains closed. RR-RM1 and all unrelated work remain
  unstarted pending owner direction.
- Open product blockers: Release Radar has no authoritative portable project archive. Its Markdown delivery records and the existing partial Rekon seed importer cannot import the repository as a complete existing project.
- Nonblocking next-phase candidates: reconcile the coupled product/IA decisions; productionize the owner-approved wordmark recorded in `docs/brand/README.md`; remove the Swift optional-`.none` and test actor-isolation warnings; attach live Codex state only when a supported authenticated endpoint exists; and add Developer ID/notarized packaging only if distribution expands beyond the owner Mac. Structure-less onboarding persistence and its Codex repository handoff are accepted.
- Install note: macOS may require one-time owner approval for the packaged LaunchAgent in System Settings. Startup reports the required action and fails closed until enabled.

## Unscheduled product backlog

- Add owner-visible Back and Forward navigation buttons with defined navigation-history behavior. This item is not assigned to the current phase or any next-phase gate.

## Release Radar roadmap synchronization — 2026-08-29

- Status: **Complete at the audited tracking layer; roadmap-ticket
  implementation remains closed.** The separate RR-R9 active-phase-selection
  capability is released only through RR-R9A below. Release Radar phase
  `RR-ROADMAP` (`Established product roadmap`) contains 11 open roadmap
  records: eight Backlog tickets (`RR-RM1`–`RR-RM4` and `RR-RM8`–`RR-RM11`)
  and three Blocked tickets (`RR-RM5`–`RR-RM7`).
- Coverage: `RR-RM1` owns the coupled M1–M5/P1 product and IA decision;
  `RR-RM2` owns F2 Back/Forward history; `RR-RM3` owns F3 wordmark production;
  `RR-RM4` owns F4 warning cleanup; `RR-RM5` owns B2 portable export and its
  authoritative fixture; `RR-RM6` owns B3 Portable Import; `RR-RM7` owns B1
  supported live Codex attachment; `RR-RM8` owns P3's iPhone-companion product
  decision; `RR-RM9` owns F5 conditional notarized distribution; `RR-RM10`
  owns F1 Help; and `RR-RM11` owns P2's role-agent workflow decision.
- Dependencies: `RR-RM2` depends on `RR-RM1`; `RR-RM6` depends on `RR-RM5`;
  `RR-RM8` depends on `RR-RM1` and `RR-RM7`; and `RR-RM10` depends on
  `RR-RM1`. Open blockers record the missing exporter brief/fixture for
  `RR-RM5`, the accepted-export prerequisite for `RR-RM6`, and the absent
  supported authenticated live-Codex endpoint for `RR-RM7`.
- Audit evidence: phase event `4CA6A26B-475A-40D9-AAFF-1E4463002239`; ticket
  events `5DC98AC4-231C-43FB-9B8D-D71E1CC80FA1`,
  `CE35DDB9-E8AE-48E6-9C7F-906FA2B17DFD`,
  `B29A50E6-BA44-43F7-816D-01C83AB494D8`,
  `DC32D5BD-2D22-48C5-BBFF-4CED130935F3`,
  `86553EC9-76FD-4720-9F52-296ABF79DA88`,
  `40856513-F199-4AD0-B335-026787397755`,
  `CEEA3146-EE53-4EDE-8EAD-9B460588274C`,
  `21EDC6E4-0857-48A6-A37A-56648F588D49`,
  `F992B5B3-4589-4D72-92F7-1FC80356F7C1`,
  `55A54CB1-153C-4F5E-8FA7-82461443B9D5`, and
  `16163A27-350B-4512-87F1-5B65B6F79A71`. Audited dependency and blocker
  mutations also succeeded, and the installed app's Activity surface directly
  read back the new roadmap entries.
- Visibility limitation: the installed dashboard projects only the persisted
  explicit active phase, which remains the accepted post-MVP remediation
  phase. The supported typed mutation surface has no active-phase-selection
  command, so `RR-ROADMAP` is durably tracked and visible in Activity but is
  not presented as the current Phase Board. No direct database edit was used.

## RR-R9 preimplementation gate — Active-phase selection — 2026-08-29

- Approved complete outcome: owners and authorized agents can select one
  existing same-project active phase through accessible Project Overview and
  Phase Board controls or the typed `release_radar_set_active_phase` MCP
  command. The shared app-owned command path validates authorization and phase
  ownership, persists and audits the selection, immediately publishes a
  coherent board/count/detail/dependency/Activity/selection refresh, survives
  relaunch, and provides explicit busy, no-alternative, unavailable,
  authorization, mutation-failed, and saved-but-refresh-failed recovery without
  silent or duplicate mutation. Final acceptance activates `RR-ROADMAP`.
- Bounded delivery: RR-R9A delivers the complete command/store/audit/replay/
  transport authority; RR-R9B delivers the shared owner experience and
  coherent refresh/recovery behavior; RR-R9C integrates and independently
  verifies the running product before the one accepted live activation. These
  checkpoints constrain implementation and review risk; no checkpoint reduces
  the approved complete outcome or makes an intermediate slice a completed
  RR-R9 feature.
- Controlling artifacts:
  `docs/design/release-radar-active-phase-selection-design.md`,
  `docs/architecture/ADR-003-active-phase-selection.md`, and
  `docs/superpowers/plans/2026-08-29-release-radar-active-phase-selection.md`.
  The registered implementation briefs are
  `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-1-brief.md`
  at SHA-256
  `1be7442a7f5725fa300911489ad63c7a6b668a7b948a6071176f2a2442d28d31`
  and
  `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-2-brief.md`
  at SHA-256
  `226ba89999e08da2b291db196c4ab859cdc897ff7d770595e90b3c905045ba7c`;
  the complete `docs/delivery/task-briefs/SHA256SUMS` verification passes.
- Independent preimplementation decisions:
  - Planning agent: **Complete**; the approved complete outcome, TDD sequence,
    RR-R9A/B task boundaries, and RR-R9C handoff are durable and registered.
  - Architect: **GO, Required 0, Optional 0**; ADR-003 accepts the narrow owner
    working-context decision while preserving app-only store authority,
    same-project validation, current-generation publication, and cross-phase
    dependency-reference semantics.
  - TPM: **GO, Required 0**; RR-R9A alone is dependency-safe and released.
    Existing migration-fixture drift is not RR-R9 scope and does not block the
    focused baseline.
  - QA/Test: **GO, Required 0** after the plan incorporated the isolated runtime
    fixture, deterministic boundary tests, `NOCASE`/ID ordering, and correct
    evidence authority. The nonblocking execution caution is to make queued
    notification work non-vacuous in ordering tests and clean up every gate and
    temporary task deterministically.
  - Security/Privacy: **GO, Required 0** after the plan incorporated retained
    pre-handler refresh, live-versus-isolated evidence authority, the explicit
    258-byte identifier test, and installed-app/MCP readiness before UUID
    generation. There are no optional security blockers.
  - Delivery Management: **GO, Required 0**; artifact registration, hashes,
    source state, baseline evidence, writer serialization, and dependency gates
    are sufficient to release RR-R9A only.
- Pre-RR-R9 baseline: the focused `xcodebuild` selection covering
  `AgentBridgeAcceptanceTests`, `AgentBridgeTransportAcceptanceTests`,
  `DashboardProjectionTests`, and `AppRouteTests` exited 0 before any RR-R9
  product change. A full-suite result bundle recorded 186 passed tests, five
  genuine pre-existing plugin/schema-migration fixture failures (three stale
  schema-9 expectations against accepted schema 10 and two repair-fixture
  failures), and two cancellations when a stalled runner was stopped. The five
  failures reproduced in isolation and are unrelated baseline limitations;
  they must be reported, not repaired under RR-R9 unless they prevent direct
  verification of the requested capability.
- Source-state verification: current on-disk command, dispatcher, MCP tool, UI,
  and focused test sources contain no `setActivePhase` or
  `release_radar_set_active_phase` implementation. RR-R9 product/test work has
  not begun. Existing changes in AppModel, Overview, Sidebar, AgentTools, and
  focused test files belong to the accepted plugin-lifecycle and other
  pre-existing work and must be preserved.
- Workspace and authorship decision: continue on the current
  `codex/release-radar-mvp` checkout with exactly one writer at a time. A new
  worktree would omit or mis-base required uncommitted accepted work and would
  increase overlap risk in files RR-R9 must touch. Each Implementer must make
  targeted edits against the current diff and attribute only its RR-R9 changes;
  no staging or commit is authorized or required for these checkpoints.
- Release decision: **RR-R9A open; RR-R9B closed; RR-R9C closed.** RR-R9A must
  begin with the brief's failing dispatcher and signed-tool tests and receive
  fresh independent Code Review, QA/Test, Architecture, Security/Privacy, TPM,
  and Delivery Management acceptance before RR-R9B can open. `RR-ROADMAP`
  remains tracked but inactive until the final RR-R9C live gate.

## RR-R9A acceptance — Typed active-phase authority — 2026-08-29

- Status and gate: **Accepted; Required 0.** RR-R9A is the completed first
  checkpoint of RR-R9, not a completed product feature. It adds the typed,
  audited, idempotent active-phase authority; RR-R9B alone is now
  dependency-safe and released. RR-R9C and the live `RR-ROADMAP` activation
  remain closed.
- Serialized implementation attribution: one fresh Implementer changed only
  `ReleaseRadarCore/AgentBridge/AgentCommand.swift`,
  `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`,
  `ReleaseRadarAgentTools/main.swift`,
  `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`, and
  `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`. Independent
  pre-edit-blob comparison confirms exactly `+1/-0`, `+15/-0`, `+9/-0`,
  `+303/-0`, and `+82/-7` respectively; the current on-disk blob IDs are
  `a244ca9ce21557bdd881da1e0cb6e154120e5048`,
  `3992cdf7c6f8c2392f0da504ba5a6624493fc5c8`,
  `fb451a4911728f260c51dd3ce1131ff243f6996e`,
  `a10f4b6175397433819d0013fc042f8ecd3e6c38`, and
  `70b124acce3c22aa7e44a4fa8be9c69571805f64`. Independent current SHA-256
  readback, in the same order, is
  `d0118045b142a47d6d5cd127ab1a6462be981854f82bffac81b5b57edfc3796f`,
  `ecdf1f2f36c8151f24a4dfbe7565bc752a9930db799d39fb1619b33161cb7f3e`,
  `6518190b30b107e06cf7e34a24fbd0b1bf8d2a1bbeebf4c22367f787c0ec94dc`,
  `b319c3ddea34d7f1e8e336186930382085c74a2fa31053dad54ac8bdd23a34ee`,
  and `004c3520025082ed9b1687c43ef6589fc44577181285b18554b2ad9d3bc7ccc`.
- Delivered authority: additive envelope-v1 `setActivePhase(phaseID:)`, same
  authorized-project and same-project-phase admission, the existing app-owned
  transaction's single active-pointer upsert, returned selected phase/audit ID,
  phase-scoped actor/reason attribution, durable receipt/replay, and the
  thirteenth strict MCP tool `release_radar_set_active_phase`. No migration,
  plugin/bridge version, signing, permission, schema, transport, owner UI, or
  direct SQLite access changed.
- TDD evidence: core RED
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Core-RED -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests CODE_SIGNING_ALLOWED=NO`
  exited 65 on the absent command. Signed transport RED
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR-R9A-Transport-RED -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests`
  exited 65 on the missing 13th-tool/schema behavior. Core GREEN passed
  19/19 and signed transport GREEN passed 5/5.
- Final focused verification: fresh QA ran
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -derivedDataPath /tmp/ReleaseRadar-RR-R9A-QA-POST -only-testing:ReleaseRadarTests/AgentBridgeAcceptanceTests -only-testing:ReleaseRadarTests/AgentBridgeTransportAcceptanceTests -only-testing:ReleaseRadarTests/StoreAcceptanceTests`
  with 53 passed, 0 failed, and 0 skipped. Independent readback of the retained
  final result bundle reports the same 53/53, 0 failed/skipped. The scoped
  five-file `git diff --check` is clean.
- Behavioral evidence: real-store fixtures prove the pointer-only transaction,
  phase-scoped audit and durable receipt, relaunch/recreated-dispatcher exact
  replay, changed-body request-ID rejection, missing/cross-project/unauthorized
  rollback, 258-byte UTF-8 pre-write rejection, and a fresh already-active
  agent intent that creates one audit/receipt while its replay creates none.
  The packaged signed tool lists exactly 13 strict tools, commits through the
  registered broker/app callback with `isError: false`, and preserves the
  existing wrong-peer/version/unavailable/deadline/outcome-unknown contracts.
  Post-test `launchctl print gui/501/com.rekonlabs.ReleaseRadar.BridgeAgent`
  exits 113 with no registered service.
- Independent acceptance: Code Review **Approved** (Critical/Important/Minor
  0); QA/Test **GO** (Required 0); Architecture **GO** (Required/Optional 0);
  Security/Privacy **GO** (Required 0, no attributable Optional finding); TPM
  **GO** (Required 0, release RR-R9B only); Delivery Management **GO**
  (Required/Optional/Out-of-scope 0). No reviewer authorized a commit or
  stage, and none occurred: HEAD remains
  `bcd108f3d1a95be7733a39f42d8b68c98748a30e` on
  `codex/release-radar-mvp` with no staged paths.
- Limitations and temporary evidence: the full suite remains out of scope for
  RR-R9A because its five plugin/schema fixture failures are documented
  pre-existing baseline drift; they do not affect the direct 53-test focused
  result. Non-authoritative artifacts remain at
  `/tmp/ReleaseRadar-RR-R9A-Core-RED`,
  `/tmp/ReleaseRadar-RR-R9A-Transport-RED`,
  `/tmp/ReleaseRadar-RR-R9A-GREEN`,
  `/tmp/ReleaseRadar-RR-R9A-QA-POST`, and the temporary
  `ReleaseRadar-AgentBridgeTests-*` fixture directories. They were not deleted
  because cleanup authorization was not requested.
- Release decision: **RR-R9B open; RR-R9C closed.** Assign RR-R9B to exactly
  one fresh serialized Implementer. It must use the registered Task 2 brief,
  preserve this accepted authority slice and unrelated dirty work, begin with
  its required RED tests, and receive fresh independent Code Review, QA/Test,
  Architecture, Security/Privacy, TPM, and Delivery Management acceptance.
  The final live `RR-ROADMAP` selection remains an RR-R9C action only.

## RR-R9B acceptance — Owner active-phase experience — 2026-08-29

- Status and gate: **Accepted; Required 0, Optional 0, Out-of-scope 0.** RR-R9B
  is the completed second checkpoint of RR-R9, not final product acceptance.
  It delivers the shared owner selector, coherent projection refresh,
  recoverable failure states, current-generation publication, notification
  ordering, and the isolated Debug acceptance fixture. RR-R9C alone is now
  dependency-safe and released. Runtime UI, keyboard/accessibility,
  wide/compact screenshots, mockup comparison, Release packaging/signing,
  installation, installed MCP readiness, and live `RR-ROADMAP` activation are
  not claimed here and remain closed until the combined RR-R9C final GO.
- Controlling contract integrity: the registered Task 1 and Task 2 brief
  SHA-256 values remain respectively
  `1be7442a7f5725fa300911489ad63c7a6b668a7b948a6071176f2a2442d28d31`
  and
  `226ba89999e08da2b291db196c4ab859cdc897ff7d770595e90b3c905045ba7c`;
  both current files match their entries in
  `docs/delivery/task-briefs/SHA256SUMS`.
- Serialized implementation attribution: one fresh Implementer owned exactly
  the 13 Task 2 product/test paths. Independent current-blob comparison against
  the initial attributable package plus review-loop 1 and Security correction
  packages confirms the complete serialized chain: Dashboard Projection
  `a3641b3b45e4a0e7f2483b7a8d547ba168f1c793`, ReleaseRadarApp
  `916e18c67469f60079fc8b829bdfbe6582de203b`, AppModel
  `cb4a9d98ad7b135104d87e1319b8cdbe9054ebef`, Project Overview
  `2b65f5cad8523413b92238b2cebfde45abcc4c87`, Phase Board
  `04fd1741bddfc4c4ed1370b625391a3be3c3fe5e`, Sidebar
  `e1b4f0e2bd2a9bd3108e00c826bd5b581866a8ac`, Failure State
  `609f294f5a780764a10cb0e7bdf8205e26f6cc97`, Notification Coordinator
  `e021f51be497c0aac13feb103e8b872241de9b7a`, Dashboard Projection tests
  `f1ca4e7de8ec63bcb7e5f66eda489c6c8eda25af`, App Route tests
  `cd926cbdadaa49902d8282bd79dcd1bf401a013d`, Notification Acceptance tests
  `d4595db72e52425484e07c47cc14c0bb45ac56c0`, the new shared selector
  `3bccd435b3d22d32a0c52654579d9cf5d31b7f77`, and the new Debug fixture
  `e9b973bf799781b0c236adfa009a599736b77271`. This accepts only the
  attributable package chain; unrelated dirty-baseline bytes remain preserved
  and unattributed.
- Original test-first evidence: the exact required pre-product RED exited 65
  after the test target reached the intended missing-product boundary:
  `ProjectDashboardProjection` lacked `activePhaseID` and `phases`, with the
  expected dependent inference errors. No test executed in that compile RED
  (0 passed, 0 failed, 0 skipped). The retained result is
  `/tmp/ReleaseRadar-RR-R9B-RED/Logs/Test/Test-ReleaseRadar-2026.08.29_15-23-31--0400.xcresult`.
- Delivered projection and persistence coverage: fresh focused tests prove
  deterministic same-project phase options ordered by `name COLLATE NOCASE,
  id`, including the explicit equal-name ID tie-break; optional no-active-
  pointer projection and first selection from both owner routes; active-phase-
  only cards, detail keys, counts, and dependency-graph nodes; preserved valid
  same-project cross-phase references inside active-ticket detail; exact
  unchanged phase, ticket, phase-dependency, ticket-dependency, historical
  audit, and durable-receipt rows; accepted pointer/audit persistence across
  store recreation and AppModel relaunch; and empty-target ticket/detail/graph
  reconciliation.
- Model-authority and recovery coverage: direct AppModel tests prove already-
  active, `.saving`, and `.savedNeedsReload` guards execute before bookmark
  access and UUID generation, each with request-ID/request/audit deltas of
  `0/0/0`. Valid authorization dispatches the accepted RR-R9A command with
  `.ownerApp`; missing, stale, resolver-failed, access-denied, and mismatched
  bookmarks fail closed. Reauthorization accepts only the same canonical root,
  preserves Locate eligibility after rejected parent/child/different roots,
  never auto-selects, and never retries the command. Typed mutation and
  unavailable failures preserve the last coherent projection; committed-but-
  refresh-failed recovery performs only an explicit read-only dashboard reload
  and retains exactly one request/audit.
- Publication and coordinator coverage: continuation-gated older-A/newer-B
  tests cover both stale success and stale failure without sleeps. A
  superseded caller performs no route, notification, dashboard, workspace,
  guidance/root, Activity, selection, dependency, error, or phase-status write;
  only the current non-suspending publication wins. Current-generation target
  matches clear `.saving`/`.savedNeedsReload`, while mismatches preserve the
  pending state. Deterministic coordinator tests prove successful callbacks
  before handler registration coalesce with zero notification drain, handler
  registration begins exactly one read-only refresh before notifications,
  ordinary registered and overlapping callbacks preserve that ordering, and a
  failed command queues no refresh.
- Debug fixture coverage: tests prove the fixture is `#if DEBUG`, default-off,
  and admitted only by exactly one `--rr10-capture`, one
  `--rr10-empty-store`, and one recognized scenario. Unknown, partial, and
  duplicate arguments and Release builds reject it. The app-owned fixture uses
  production bookmark creation for disposable exact roots, exercises `happy`,
  `busy`, `no-alternative`, `mutation-failure`, `unavailable`,
  `authorization-failure`, `saved-refresh`, `empty-phase`, `no-active-pointer`,
  and `cross-phase-detail`, and proves deterministic/idempotent seeding,
  one-shot faults, relaunch behavior, scenario isolation, normal sample-data
  absence, and continued external-service suppression. This is automated
  fixture evidence only; RR-R9C still owns running-app evidence.
- Review loop 1 and closure: Architecture initially reported NO-GO/Required 1
  because a superseded top-level `loadDashboard()` continued into Debug route
  and notification side effects. Code Review reported four Required findings:
  that same stale-caller defect, rejected-folder recovery losing Locate
  eligibility, duplicate capture-control flags being admitted, and row-
  preservation coverage that compared counts and omitted a phase-dependency
  fixture. The bounded corrections made post-load work conditional on
  `.published`, preserved recovery eligibility, required exact-one flags, and
  compared exact persisted rows. Focused RED/closure evidence is recorded in
  the Implementer report; the complete post-loop focused suite passed 102/102.
  Fresh Code Review then Approved with Critical/Important/Minor/Required 0,
  QA/Test reported GO/Required 0, and Architecture reported GO/Required 0 with
  ADR-001 and ADR-003 satisfied and no new ADR.
- Security review loop and no-write closure: Security/Privacy then reported
  NO-GO/Required 1 because committed external-command refresh and owner saved-
  refresh recovery still called mutating guidance authorization. Across armed
  resolver failure, stale resolution, root mismatch, and access denial, the
  focused RED ran 2 tests and failed both because the bookmark was marked stale,
  an owner authorization audit was appended, and cached guidance/root changed.
  The correction makes committed contexts reuse the published guidance/root
  snapshot. The focused GREEN passed 2/2 and compares exact bookmark, audit,
  command-receipt, and active-pointer rows plus cached guidance/root,
  dashboard, Activity, error, and phase status; owner recovery also proves no
  command retry. Fresh Security/Privacy reported GO/Required 0 after this
  no-write correction.
- Final automated evidence: fresh independent QA ran the exact required
  Dashboard Projection, App Route, Agent Bridge Acceptance, and Notification
  Acceptance selection. Direct `xcresulttool` readback of
  `/tmp/ReleaseRadar-RR-R9B-QA-SECURITY/Logs/Test/Test-ReleaseRadar-2026.08.29_16-57-44--0400.xcresult`
  reports **104 total, 104 passed, 0 failed, 0 skipped, 0 expected failures**.
  The exact 13-file `git diff --check` exits 0 with no output. QA/Test's final
  verdict is GO/Required 0 with no staged paths.
- Final independent verdicts: Code Review **Approved**
  (Critical/Important/Minor/Required 0); QA/Test **GO** (Required 0);
  Architecture **GO** (Required 0, ADR-001/ADR-003 satisfied, no new ADR);
  Security/Privacy **GO** after the committed-refresh no-write correction
  (Required 0); TPM **GO** (Required 0, Optional 0, Out-of-scope 0) and
  authorizes acceptance of RR-R9B plus release of RR-R9C only; Delivery
  Management **GO** (Required 0, Optional 0, Out-of-scope 0) on the direct
  evidence above. No role authorizes live activation before RR-R9C combined
  final GO.
- Source and workspace state: all 13 current blobs match the composite package
  chain, the exact scoped diff check is clean, and the index has zero staged
  paths. HEAD remains `bcd108f3d1a95be7733a39f42d8b68c98748a30e` on
  `codex/release-radar-mvp`. No RR-R9B commit, stage, push, install, launch,
  external mutation, or direct SQLite access occurred. The accepted existing
  dirty baseline and unrelated work remain present; acceptance does not absorb
  or reattribute them.
- Limitations and temporary evidence: non-authoritative retained evidence
  includes `/tmp/ReleaseRadar-RR-R9B-RED`,
  `/tmp/ReleaseRadar-RR-R9B-GREEN`, `/tmp/ReleaseRadar-RR-R9B-QA-POST`,
  `/tmp/ReleaseRadar-RR-R9B-Security-RED`,
  `/tmp/ReleaseRadar-RR-R9B-Security-GREEN`, and
  `/tmp/ReleaseRadar-RR-R9B-QA-SECURITY`. These paths are evidence locations,
  not controlling artifacts, and were not removed because destructive cleanup
  was not authorized. The repository-wide suite was not rerun for this bounded
  slice; its five previously reproduced plugin/schema-migration fixture
  failures remain documented unrelated baseline drift. The standard multiple-
  destination and App Intents metadata-skip output and the pre-existing
  optional-`.none` ambiguity warning are non-failing baseline limitations.
- Release decision: **RR-R9C open; live `RR-ROADMAP` activation closed.** RR-R9C
  must perform the registered combined automated, configured Release build and
  signing, isolated alternate-container runtime, wide/compact visual,
  keyboard/accessibility, recovery, relaunch, installed-app and installed-MCP
  readiness evidence. Only its fresh combined final GO with Required 0 may
  authorize generation of the one live request UUID and the accepted
  `RR-ROADMAP` command. All other roadmap work remains closed.

## RR-R9C live activation history and correction acceptance gate — 2026-08-29

- Status and gate: **Complete RR-R9 product outcome Accepted, Required 0;
  terminal Git sequence COMPLETE; no RR-R9 work remains.**
  The automated,
  package,
  isolated-runtime, accessibility, responsive, recovery, visual, installed-MCP,
  one-time live-activation, and immediate/relaunch evidence remains truthful.
  The one accepted command established `RR-ROADMAP` and its immediate/relaunch
  verification remains valid; later valid owner UI choices set the current
  persisted pointer to **Post-MVP reported-defect remediation**. The registered
  bounded correction, installed-product readback, tracking-only ticket
  transition, and final independent UI readback are accepted. RR-R9C and the
  complete RR-R9 product outcome are accepted; the RR-R9 goal is complete.
- Automated acceptance: the exact registered seven-suite selection produced
  **146 total, 142 passed, 4 failed, 0 skipped, 0 expected failures** at
  `/tmp/ReleaseRadar-RR-R9C-Acceptance/Logs/Test/Test-ReleaseRadar-2026.08.29_17-17-31--0400.xcresult`.
  All direct RR-R9 suites were green: Store 29/29, Agent Bridge 19/19, signed
  transport 5/5, Dashboard Projection 10/10, App Route 51/51, and Notification
  24/24. End-to-End was 4/8; its four failures are the documented unrelated
  schema/plugin fixture drift: two stale schema-9 expectations against schema
  10, the version-7 lifecycle-table-already-exists fixture, and the unrecognized
  version-3 fixture. Independent QA reproduced the same 142/146 classification.
- Staged Release evidence: `./script/build_and_run.sh
  --stage-release-no-launch` exited 0 without installation or launch, and
  `codesign --verify --deep --strict --verbose=2 dist/ReleaseRadar.app` exited
  0. The verified arm64 bundle is `com.rekonlabs.ReleaseRadar`, version `0.1.5`
  build `1`, signed by Apple Development team `2UA854NLX4` with hardened
  runtime. It contains the established core framework, AgentTools, BridgeAgent,
  plugin lifecycle helper, marketplace, and both LaunchAgent plists. The
  BridgeAgent job was absent (`launchctl` exit 113), the existing owner app and
  helper were left untouched, the scoped diff check was clean, and the index
  remained empty.
- Isolated runtime evidence: one alternate Debug identity
  `com.rekonlabs.ReleaseRadar.RR9Capture.6f368f13-5c53-464b-be75-ad8b212bda4b`
  built and passed strict deep signing under
  `/tmp/release-radar-rr9-capture.pyI7WK`. Computer Use exercised all ten
  default-off fixture scenarios through the running app: happy, busy,
  no-alternative, mutation-failure, unavailable, authorization-failure,
  saved-refresh, empty-phase, no-active-pointer, and cross-phase-detail.
  Evidence covers both selector placements, pointer and keyboard paths,
  duplicate suppression, exact-root reauthorization with no automatic retry,
  read-only saved-refresh recovery, coherent five-lane/detail/dependency/
  Activity publication, empty and no-pointer states, preserved cross-phase
  detail references with phase-scoped cards/graph nodes, and same-container
  relaunch persistence. The alternate app quit cleanly afterward.
- Visual and accessibility evidence: the four canonical PNGs are
  `docs/delivery/evidence/rr-r9-active-phase-overview.png`
  (`1499×768`, SHA-256
  `ea3b61f69defb448656e5a26e1f4aa98f916a06ee82f54b74c3c21b8654ff084`),
  `docs/delivery/evidence/rr-r9-active-phase-board-wide.png`
  (`1411×768`,
  `5a4e626ce5b5a9693444f5255c919b9cf6328a16b283a0d9e4fe14cd22880d61`),
  `docs/delivery/evidence/rr-r9-active-phase-board-compact.png`
  (`768×777`,
  `b286ad8e20adae2afb2db98909a8687af3e0af9c1c93077b402dac28c4914a3e`),
  and `docs/delivery/evidence/rr-r9-active-phase-recovery.png`
  (`1411×768`,
  `4e744541eb09632b48f0419bb48fb0f6e070fe2bf88600014ce769f276f78af4`).
  They were reopened at original detail and compared with
  `docs/design/mockups/phase_board.png`; no material contradiction was found.
  Wide mode retained the right-side inspector; compact mode retained all five
  lanes and moved the inspector below. Independent QA also directly observed a
  `760×552` outer window, equal to `760×520` content plus the 32-point title
  bar, with compact recovery intact.
- Owner-approved evidence deviation: the controlling
  `docs/design/release-radar-active-phase-selection-design.md` records the
  owner's explicit acceptance of the current wide/compact captures and QA's
  minimum-content observation because the Computer Use viewport could not
  produce a near-`1586×992` raster. This changes only the evidence threshold;
  the responsive product contract remains unchanged. Code/Product and
  Architecture closure re-reviews both returned GO/Required 0 on that basis.
- Independent combined verdicts: Code/Product **GO, Required 0**; QA/Test
  **GO, Required 0**; Architecture **GO, Required 0** with ADR-001/ADR-003
  intact and no new ADR; Security/Privacy **GO, Required 0**; TPM **GO,
  Required 0** and authorizes only this final activation gate; Delivery
  Management **GO, Required 0** on the direct evidence above. The reviews were
  independent of implementation and no Required finding remains open.
- Isolation and privacy: the capture used only the alternate bundle/container,
  showed no network sockets, registered no alternate helper, and used the
  established capture suppression. No owner container or SQLite database was
  opened or inspected, no direct database write occurred, no live MCP
  connection was used, no final UUID was generated, and no `RR-ROADMAP`
  mutation occurred during pre-activation acceptance.
- Optional and out-of-scope findings: an exact near-`1586×992` raster and a
  clean happy-path recapture are Optional, not blocking; the local account path
  in internal evidence should be redacted only if that evidence is later
  published. Repairing the four unrelated End-to-End schema/plugin fixtures,
  product/IA reconciliation, and all other roadmap work are out of RR-R9C's
  final activation scope.
- Historical pre-activation safeguards, executed once and now closed: first
  quit the existing owner-facing Release Radar
  process normally. Install only the already verified staged bundle with
  `./script/build_and_run.sh --install-staged-release-no-launch`, verify the
  installed bundle with strict deep signing, then launch that exact installed
  app. Before UUID generation, require a fully loaded installed dashboard and
  ready **Active phase** selector plus read-only installed-MCP `initialize` and
  `tools/list` evidence for the expected server identity and exactly 13 strict
  tools including the accepted `release_radar_set_active_phase` schema. A
  readiness failure stops before UUID generation or mutation.
- Historical one-time live-command boundary, executed once and now closed:
  only after both readiness checks passed, generate and record one fresh UUID
  and invoke `release_radar_set_active_phase` once with
  version `1`, the exact authorized repository root, reason `Activate
  RR-ROADMAP after RR-R9 acceptance`, and phase `RR-ROADMAP`. On
  `outcomeUnknown`, retain and replay only the complete original argument
  object with that same UUID; never generate a replacement or inspect SQLite.
  Pair the returned audit ID with the recorded request ID, then verify the
  immediate and relaunched installed UI shows `RR-ROADMAP`, counts Backlog 8 /
  In progress 0 / Needs review 0 / Blocked 3 / Accepted 0, target-phase detail
  and dependencies, Activity's exact reason, and the prior active phase still
  available as a selector option. Delivery Management must record the final
  disposition before RR-R9 could be marked complete or RR-ROADMAP work
  released. This historical boundary grants no present or future command
  authority.

### RR-R9C live activation — accepted

- Installed bundle readiness: strict deep signing passed for
  `/Applications/ReleaseRadar.app`, bundle ID `com.rekonlabs.ReleaseRadar`,
  version `0.1.5` build `1`, arm64 with hardened runtime, Team
  `2UA854NLX4`, and CDHash
  `e0aa8ffe8bc15d20e95d671c3841007505790de2`. The installed dashboard loaded
  and its **Active phase** selector reached ready accessibility state before
  UUID generation.
- Installed MCP read-only readiness: `initialize` returned server name
  `Release Radar`, server version `1`, and protocol `2025-06-18`; `tools/list`
  returned exactly 13 tools. `release_radar_set_active_phase` has strict object
  input with `additionalProperties: false`; required fields are `version`,
  `requestID`, `projectRoot`, `reason`, and `phaseID`; `version` is constant
  `1`; `requestID` has UUID format; the other required fields are strings with
  `minLength: 1`; optional `assertedThreadID` is a string with `minLength: 1`.
- Live invocation: exactly one call was made after readiness, with no retry and
  no `outcomeUnknown`. Request ID
  `385154BC-DC33-4F9C-ABBD-D80B271D8FF4` and this complete original argument
  object were used:

```json
{
  "version": 1,
  "requestID": "385154BC-DC33-4F9C-ABBD-D80B271D8FF4",
  "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
  "reason": "Activate RR-ROADMAP after RR-R9 acceptance",
  "phaseID": "RR-ROADMAP"
}
```

- `assertedThreadID` was intentionally omitted. The definitive MCP result had
  `isError: false`, `entityIDs: ["RR-ROADMAP"]`, and audit event ID
  `FBBB409B-9E4A-4165-A22D-6BFD16B3E154`.
- Immediate installed-UI verification showed **Established product roadmap** /
  `RR-ROADMAP`, counts Backlog 8 / In progress 0 / Needs review 0 / Blocked 3 /
  Accepted 0, and all 11 target tickets in those lanes. `RR-RM1` was the
  selected detail and truthfully exposed unlocks `RR-RM2`, `RR-RM8`, and
  `RR-RM10`. The prior **Post-MVP reported-defect remediation** phase remained
  available as a selector option. Activity showed the exact reason `Activate
  RR-ROADMAP after RR-R9 acceptance`.
- After a normal quit and relaunch of the same installed bundle, the installed
  UI retained the same `RR-ROADMAP` identity, 8/0/0/3/0 counts, all 11 target
  tickets, selected RR-RM1 detail and unlocks, prior-phase selector option, and
  exact Activity reason.
- Fresh post-activation QA/Test reports **GO, Required 0** and fresh
  Security/Privacy reports **GO, Required 0**. No direct database inspection or
  edit was used; the app-owned typed command and visible installed-app
  readbacks remain the live authorities, with isolated RR-R9A tests retaining
  authority for actor/thread/audit/receipt cardinality and replay semantics.
- Prior Delivery Management disposition, now superseded: **RR-R9 Complete and
  Accepted; Required 0** was recorded before the Required test-host isolation
  defect was discovered. The live activation remains accepted and
  its `RR-ROADMAP` immediate/relaunch evidence remains valid, but later valid
  owner UI choices made Post-MVP remediation the current pointer. This is no
  longer the current completion or next-work disposition.

### RR-R9C XCTest-host isolation correction — installed acceptance complete

- Root-cause evidence: a fresh standard `xcodebuild test` host launched
  `/tmp/.../Debug/ReleaseRadar.app` with production bundle ID
  `com.rekonlabs.ReleaseRadar`. Current source constructs
  `ReleaseRadarAppServices.shared` unconditionally from `ReleaseRadarApp`; that
  singleton is backed by `DeliveryStore.applicationSupportDatabaseURL()`.
  `SidebarView.task` then calls `initializeForLaunch`. Only AppDelegate bridge
  startup is guarded by `XCTestConfigurationFilePath`, so that guard does not
  protect app initialization or the Sidebar launch task.
- Authority exposure: an ordinary test host can therefore open owner
  Application Support and reach production Keychain, network/Pushover, plugin
  lifecycle/helper, notification, and related launch paths. This is a Required
  isolation defect even without evidence of an owner-state mutation.
- Attribution boundary: do not attribute the two later owner phase Activity
  entries to XCTest. Unified TCC logs instead correlate those entries with
  separate Gemini accessibility access to installed PID `1072`. Subsequent
  valid owner UI choices made **Post-MVP reported-defect remediation** the
  current persisted pointer. That later choice does not invalidate the
  accepted `RR-ROADMAP` request, audit, or immediate/relaunch evidence.
- Controlling correction contract:
  `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-brief.md`,
  SHA-256
  `2d4c855adecab3c20da618f8147f60aa42d8da903ea000e5675e58eb3f7571de`.
  It permits only the narrow test-first correction in
  `ReleaseRadar/App/ReleaseRadarApp.swift` and
  `ReleaseRadarTests/AppRouteTests.swift`; it adds no generalized harness,
  dependency, schema, entitlement, test-target, or product behavior.
- Amended-brief review history: QA/Test initially returned **NO-GO, Required
  1** because the brief did not require a deterministic test of test-host
  directory-preparation failure. Planning amended the exact production
  `hostMode` contract and focused policy matrix to create a regular file at the
  required PID-scoped directory, require
  `.xctestHostUnavailable(databaseURL:)` with the same isolated URL, and prove
  the unavailable branch retains no store and can never select application
  mode, a production URL, `ReleaseRadarAppServices.shared`, or `AppModel`.
  Planning also made that unavailable contract part of the compile-only RED and
  acceptance criteria. QA/Test re-reviewed the amendment and returned **GO,
  Required 0**.
- TPM review history: TPM's subsequent **NO-GO** was temporary and solely a
  ledger-consistency blocker because this ledger still named the superseded
  brief hash. The two correction-specific ledger references now name the
  registered and independently computed amended SHA-256 above. TPM's final
  amended-checksum re-review is **GO, Required 0**.
- Final amended-artifact decisions: Architecture **GO, Required 0**; QA/Test
  **GO, Required 0**; TPM **GO, Required 0**; Delivery Management **GO,
  Required 0**. Delivery Management independently verified the brief file,
  `SHA256SUMS`, and both ledger references at the same amended checksum, the
  clean scoped target diff, empty index, accepted pre-correction target blobs,
  writer serialization, two-file scope, and owner finalization boundary.
- Configured-plugin QA attribution correction: the idempotent return of exact
  existing audit event `D8B5E932-BC1C-466E-8329-092B166568BA` for entity
  `RR-R9` remains truthful and made no new mutation. Later conclusive process
  identity evidence mapped AgentTools PIDs `75927` and `7341` to deleted backup
  bundles, not the current installation; both stale processes were terminated.
  The current bridge/helper processes map to
  `/Applications/ReleaseRadar.app`.
- Historical Implementer release boundary, now closed: exactly one fresh
  Implementer was permitted to modify only
  `ReleaseRadar/App/ReleaseRadarApp.swift` and
  `ReleaseRadarTests/AppRouteTests.swift`. It must first add the focused policy
  assertions and run the brief's compile-only `build-for-testing` RED with
  `CODE_SIGNING_ALLOWED=NO`; the RED must fail for the missing isolation/
  unavailable-preparation contract without launching the vulnerable test host.
  It may then implement only the bounded correction and run the brief's focused
  App Route GREEN plus the exact two-file `git diff --check`. It stops and
  returns evidence after GREEN; it does not review its own work or expand
  scope.
- Initial correction evidence: the safe compile-only RED exited `65` on the
  absent isolation API without starting a test session or launching a test
  host; focused `AppRouteTests` then passed **53/53** with zero failures or
  skips. Code Review and Architecture returned **NO-GO, Required 2** because a
  same-PID directory could be reused as stale test state and the tested
  `XCTestHostConstruction` mirror was not consumed by production startup.
  Security/Privacy returned **NO-GO, Required 2** because existing-directory or
  symlink acceptance plus check/create/check sequencing could redirect the
  lexical test URL, and tests called the side-effecting production
  `DeliveryStore.applicationSupportDatabaseURL()` helper.
- Fix round 1 evidence: a second compile-only RED exited `65` on the absent
  production preparation API without launching a test host; focused GREEN then
  passed **55/55** with zero failures or skips, and the two-file diff check was
  clean. Current source blobs are `ReleaseRadar/App/ReleaseRadarApp.swift`
  `e0965e340b0c6e49451ecdcf31188c301cf9b8ba` and
  `ReleaseRadarTests/AppRouteTests.swift`
  `e0206a8c3fef481c75603d324904a279aabeba06`. POSIX `mkdir` now performs
  owner-only exclusive creation and rejects every pre-existing directory,
  regular file, or symlink before the store factory; the production-consumed
  `XCTestHostPreparation` carries the exact store retained by app startup;
  fail-fast collision tests prove the factory remains uncalled; and
  `AppRouteTests` has no production Application Support helper reference.
- Fix closure: Code Review **GO, Required 0**; Architecture **GO, Required 0**;
  Security/Privacy **GO, Required 0**. The theoretical hostile same-user
  replacement after successful `mkdir` remains out of scope under the accepted
  local threat model; no Optional finding blocks this correction.
- Runtime QA: **GO, Required 0.** The ordinary seven-suite run produced **150
  total / 146 passed / 4 failed / 0 skipped / 0 expected failures**. All six
  directly relevant suites passed **142/142**, including App Route **55/55**;
  the only failures were the same four known unrelated End-to-End schema/plugin
  fixture failures. Public diagnostics recorded seven isolated hosts, PIDs
  `8554`, `8556`, `8558`, `8559`, `8560`, `8561`, and `8562`, each at the exact
  PID-scoped form
  `/Users/jroberts/Library/Containers/com.rekonlabs.ReleaseRadar/Data/tmp/ReleaseRadar-XCTestHost-<PID>/release-radar.sqlite`,
  never an owner Application Support path. No SQLite file was opened or queried
  for this evidence.
- Owner-state preservation: read-only installed accessibility snapshots before
  and after both ordinary test-host executions were equal. Both showed active
  phase **Post-MVP reported-defect remediation** and the same 25 ordered visible
  Activity rows (`phaseSnapshotEqual: true`; `activitySnapshotEqual: true`). No
  app install, MCP call, UUID, active-phase command, ticket transition, staging,
  commit, or push occurred during correction runtime QA.
- Final independent correction verdicts: Code Review **GO, Required 0**;
  QA/Test **GO, Required 0**; Architecture **GO, Required 0**;
  Security/Privacy **GO, Required 0**; TPM **GO, Required 0**; Delivery
  Management **GO, Required 0**. Delivery independently verified the amended
  brief/SHA registration, exact current two-file blobs, clean scoped diff,
  empty index, serialized writer boundary, review closures, runtime QA, and
  owner-state equality. The XCTest-host correction is accepted.
- Corrected packaging and signing acceptance: staging without launch, staged
  strict/deep verification, installation, and installed strict/deep
  verification all passed. The installed arm64/hardened-runtime bundle is
  identifier `com.rekonlabs.ReleaseRadar`, version `0.1.5` build `1`, Team
  `2UA854NLX4`, CDHash `d204ccdd17628d6089694cf615b3c0a2a36195f4`.
  Installed SHA-256 values are main binary
  `9f65653f28584bef118ffa692f5a0e17656b88d5b4c40f63e64864551289d384`,
  AgentTools
  `acf00b7a7df3dca53a7af2b4cf141df902ea8869a6fd3a1700c6ff2ddbb24f31`,
  and BridgeAgent
  `9aa8bdcfe9345c3884a733b5d5ab18f6403e1c3c29457c6860e5f06e236e8d03`;
  the installed bundle contains no `.xctest` artifact.
- Installed-product identity and process evidence: independent QA verified all
  five inspected installed main/helper/framework binaries byte-for-byte equal
  to `dist/`. The two stale AgentTools PIDs `75927` and `7341` were conclusively
  traced to deleted backup bundles and terminated; current bridge/helper PIDs
  map to `/Applications/ReleaseRadar.app`.
- Installed persisted-state readback: normal launch and a separate normal
  quit/relaunch both showed active phase **Post-MVP reported-defect
  remediation**, ticket `RR-R9` in **In progress**, and counts Backlog 0 / In
  progress 1 / Needs review 0 / Blocked 0 / Accepted 8. Activity gained only
  ordinary **Open project dashboard** rows from the readback. No active-phase
  selection appears after the legitimate 7:01 PM owner events, so the installed
  gate caused no active-pointer mutation. No SQLite access was used.
- Independent installed-product QA: **GO, Required 0, Optional 0.** QA accepts
  the corrected installed package, process identity, normal launch/relaunch,
  persisted Post-MVP pointer, RR-R9 ticket state, counts, and Activity boundary.
  Delivery Management therefore accepts the packaging/install/readback gate.
- Tracking-only transition: **Completed and accepted.** Exactly one typed
  `release_radar_upsert_ticket` mutation was authorized for existing ticket
  `RR-R9` on `release-radar-post-mvp-remediation`, preserving its approved
  outcome and changing only lane `in_progress` to `accepted`.
- Completed invocation — exact authorized request, invoked once:

```json
{
  "version": 1,
  "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
  "phaseID": "release-radar-post-mvp-remediation",
  "ticketID": "RR-R9",
  "outcome": "Let owners and authorized agents select a project's active phase from Overview or Phase Board with persisted, audited, recoverable behavior, then activate the established product roadmap after acceptance.",
  "lane": "accepted",
  "reason": "Record the independently accepted RR-R9 active-phase-selection outcome after corrected Release packaging, installation, and relaunch verification; preserve the owner's current Post-MVP active phase.",
  "requestID": "A855DC87-AFD9-4A22-A640-D47B9043963B"
}
```

  Configured-plugin invocation succeeded once with `entityIDs: ["RR-R9"]`,
  lane `accepted`, and audit event
  `286C23C2-19D9-4C6F-B219-AFC1440E4FA8`. There was no retry, replacement
  request ID, or other mutation.
- Final installed-UI readback: direct and independent verification both showed
  active phase **Post-MVP reported-defect remediation**, `RR-R9` in **Accepted**
  with the exact approved outcome, and counts Backlog 0 / In progress 0 / Needs
  review 0 / Blocked 0 / Accepted 9. Activity's top entry is exactly one RR-R9
  **Accepted** entry with the approved reason. No phase-selection event appears
  after the legitimate 7:01 PM owner events.
- Final independent installed UI QA: **GO, Required 0, Optional 0.** QA
  authorizes Delivery Management to record the complete RR-R9 disposition and
  open terminal Git finalization.
- Complete product disposition: **RR-R9 product outcome Complete and Accepted;
  Required 0, Optional 0.** The requested owner and authorized-agent active-phase
  selection behavior, persistence/audit/recovery, historical one-time
  `RR-ROADMAP` activation, bounded XCTest-host correction, corrected installed
  package, persisted-state verification, and board tracking are accepted. The
  RR-R9 goal and terminal Git sequence are complete.
- Gate boundary: no `release_radar_set_active_phase` or other active-phase
  command is authorized. Product/App/MCP/SQLite mutation is closed. No RR-R9
  implementation, tracking, verification, or finalization work remains. RR-RM1
  and unrelated roadmap work remain unstarted pending owner direction.
- Permanent command safeguard: the accepted request
  `385154BC-DC33-4F9C-ABBD-D80B271D8FF4` and audit event
  `FBBB409B-9E4A-4165-A22D-6BFD16B3E154` remain the sole live activation
  evidence. A second UUID, MCP readiness probe, replay, or
  `release_radar_set_active_phase` call is permanently prohibited, including
  after any later failure. RR-RM1 planning and every unrelated roadmap gate
  remain closed pending owner direction.

### RR-R9 board tracking repair — accepted

- Status: **Complete; tracking Required finding closed.** Approved delivery ID
  `RR-R9` is now represented on its governing Release Radar phase board. This
  repaired tracking representation only; it changed no RR-R9 product scope and
  is distinct from the now-accepted XCTest-host isolation correction; it does
  not itself complete RR-R9. The later tracking-only lane transition is now
  completed and accepted exactly as recorded above.
- Approved command: `release_radar_upsert_ticket`. The complete original
  argument object, durably recorded before invocation, is:

```json
{
  "version": 1,
  "requestID": "58F4FBDD-2710-427A-8C21-EF96B86B7C37",
  "projectRoot": "/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar",
  "ticketID": "RR-R9",
  "phaseID": "release-radar-post-mvp-remediation",
  "lane": "in_progress",
  "outcome": "Let owners and authorized agents select a project's active phase from Overview or Phase Board with persisted, audited, recoverable behavior, then activate the established product roadmap after acceptance.",
  "reason": "Represent the approved RR-R9 active-phase-selection work on its governing phase board; RR-R9 remains reopened for the XCTest-host isolation correction."
}
```

- `assertedThreadID` was intentionally omitted. The initial installed-plugin
  invocation returned `appUnavailable`; after a normal app relaunch, the same
  plugin path and exact same request again returned `appUnavailable`. No
  alternate request ID or argument object was generated.
- After the installed BridgeAgent was verified running, the exact same request
  was replayed through the installed signed newline-delimited STDIO helper. It
  returned definitively with `isError: false`, `entityIDs: ["RR-R9"]`, and
  audit event ID `D8B5E932-BC1C-466E-8329-092B166568BA`.
- Direct running-UI readback of **Post-MVP reported-defect remediation** showed
  counts Backlog 0 / In progress 1 / Needs review 0 / Blocked 0 / Accepted 8.
  Card `ticket-RR-R9` was visible in **In progress** with the exact approved
  outcome: `Let owners and authorized agents select a project's active phase
  from Overview or Phase Board with persisted, audited, recoverable behavior,
  then activate the established product roadmap after acceptance.` No database
  inspection was used for this verification.
- Scope safeguard: the accepted request represented RR-R9 only on phase
  `release-radar-post-mvp-remediation` in lane `in_progress`. It does not
  authorize a second `release_radar_set_active_phase` invocation or any other
  mutation;
  later valid owner UI choices made **Post-MVP reported-defect remediation**
  the current persisted pointer. RR-R9 is complete and accepted; all unrelated
  roadmap gates remain closed or governed exactly as recorded above.

## Planning reconciliation — 2026-08-26

This is the canonical inventory, mockup-gap ruling, and dependency-safe
sequence for current planning. It classifies named work rather than counting
unchecked checklist boxes. Grouped numbered deliveries contribute their stated
quantity to the totals. Each counted item has exactly one classification.
Nothing in this section approves an implementation plan or releases a product
writer.

### Authority and historical records

- This ledger is the sole authority for current status, dependency gates,
  sequencing, and task eligibility.
- `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` and
  `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` are
  historical plans with explicit non-execution banners. Their unchecked boxes
  preserve chronology; they are not open work.
- Durable task contracts remain under `docs/delivery/task-briefs/`, but their
  presence does not make a task active. Exact historical originals remain
  under `docs/delivery/archive/` and are non-authoritative.
- Historical execution entries below retain some temporary-path evidence
  labels verbatim. Those labels are archaeological evidence, not controlling
  briefs, current gates, or current citations. Every controlling source and
  mockup decision in this reconciliation points to a repository-resident path;
  currently untracked paths are disclosed in the reconciliation handoff.

### Classification counts

| Classification | Count | Counted work |
| --- | ---: | --- |
| Active | 0 | None. |
| Completed | 22 | RR-01–RR-10 (10), RR-R1–RR-R6 (6), Attach Folder (1), Tasks 7A/7B (2), absorbed RR-R7 route/sidebar work (1), owner runtime validation of the installed SQLite-23 repair (1), and Product Task 2 repository handoff/Codex plugin lifecycle (1). |
| Superseded | 2 | Request-marker/“first phase” onboarding; Ready-lane or automatic transition proposals. |
| Misaligned | 5 | All-phase Work Board, Activity-to-History replacement, one-to-many goal linkage, semantic link/confidence suggestions, and partial Back-to-Goal history. |
| Duplicative | 2 | Replay of historical unchecked tasks; duplicate raster brand copies under the mockup set. |
| Blocked | 3 | Live Codex attachment, portable archive exporter/fixture, and Portable Import. |
| Deferred | 5 | Help, coherent Back/Forward definition, deterministic wordmark/lockups, warning cleanup, and conditional notarized distribution. |
| Proposed/unapproved | 3 | Recorded Project Plan visible UX; process-isolated role-agent workflow; CloudKit-backed read-only iPhone companion. |

### Evidence-backed inventory

| ID | Qty | Work item | Classification | Canonical source and evidence | Reason and surviving requirement | Duplicate/conflict; dependency or blocker | Required mockup |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| A1 | 1 | SQLite-23 repair owner validation | Completed | This ledger, **Current gate** and **Initialize Project Tracking SQLite-23 repair — reopened owner gate** | The owner confirmed the SQLite authorization error is gone, pending tracking state persists across relaunch, and the remediation is Done/Accepted. | Gate closed on 2026-08-27; no product writer is automatically released. | None; validation used the installed app. |
| A2 | 1 | Codex repository handoff and truthful observation copy | Completed; owner live acceptance 2026-08-29 | This ledger, **Product Task 2 repository-handoff acceptance correction**; plugin lifecycle design and plan | Installed `0.1.4` now distinguishes missing, incomplete, current, outdated, malformed, and unavailable guidance; the owner completed the audited no-rewrite repair and the running app immediately reported current. | Accepted local-only lifecycle and handoff; no follow-up writer is implied. | Existing onboarding and Project Overview surfaces; no new route or mockup. |
| C1 | 10 | MVP RR-01–RR-10 | Completed | This ledger, **Task ledger**; `docs/superpowers/plans/2026-08-23-release-radar-mvp.md` | Accepted delivery remains intact; preserve historical evidence and do not replay. | Historical unchecked boxes duplicate completed work. | None; completed work is excluded from generation. |
| C2 | 6 | Remediation RR-R1–RR-R6 | Completed | This ledger, **2026-08-25 — Post-MVP reported-defect remediation intake**; `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` | Accepted in the combined validation artifact. | Historical plan state is superseded by later ledger gates. | None; completed work is excluded from generation. |
| C3 | 1 | Attach Folder to Existing Project | Completed | This ledger, **Existing-project onboarding implementation and current gate** | Accepted behavior and residual tooling limitation are historical delivery evidence. | Portable Import is a different blocked workflow. | None; completed work is excluded from generation. |
| C4 | 2 | Initialize Project Tracking Tasks 7A and 7B | Completed | This ledger, **Initialize Project Tracking — owner decision and implementation-plan gate** | The persisted/copy-only handoff behavior is delivered; the later SQLite-23 repair supersedes the earlier closeout status, not the completed UI work. | Old “first phase” and request-marker copy is superseded. | None; completed work is excluded from generation. |
| C5 | 1 | RR-R7 route/sidebar safety | Completed | This ledger, **RR-R7 planning/release gate** historical banner and current classified state | Route/sidebar work is absorbed into the installed combined artifact; no separate writer survives. | Duplicative if opened as a new RR-R7 writer. | None. |
| S1 | 1 | “Ask agent to define first phase” / request-marker onboarding | Superseded | `docs/design/agent-driven-delivery-dashboard-design.md`, **Onboarding**; this ledger, Task 7B acceptance | Replaced by **Initialize Project Tracking** and a path-free copied-not-sent prompt. | `docs/design/mockups/onboarding_state.png` retains obsolete copy and is historical visual evidence only. | No replacement now: the delivered UI and runtime remediation are accepted, and this is not a new design task. |
| S2 | 1 | Ready lane and automatic dependency/runtime transitions | Superseded | `docs/architecture/ADR-001-release-radar-boundaries.md`, **Decision** and **Prohibited alternatives** | Exactly five persisted lanes survive; dependency and observed runtime are derived context only. | Conflicts with any sixth-lane or implicit-transition proposal. | None. |
| M1 | 1 | All-phase Work Board | Misaligned | `docs/design/release-radar-ux-redesign-study.md`, **Work Board contract**; `docs/design/mockups/work_board.png` and `work_board_compact.png` | Proposed surface overlaps the accepted phase-scoped Phase Board and the unapproved Project Plan. | Must be resolved with M2–M5 as one route/state/data decision. | Existing images are proposal evidence only; generate nothing until approval. |
| M2 | 1 | Activity renamed/replaced by History | Misaligned | `docs/design/release-radar-ux-redesign-study.md`, **History contract**; `docs/design/mockups/history.png` and `history_compact.png` | Accepted Activity already owns project chronology; History is a proposed replacement, not a sibling. | Conflicts with the Project Plan proposal, which retains Activity. | Existing images are proposal evidence only. |
| M3 | 1 | One goal linked to many tickets | Misaligned | `docs/design/release-radar-ux-redesign-study.md`, **Data and route implications**; `docs/architecture/ADR-001-release-radar-boundaries.md`, **RR-R3 ticket-goal identity** | The accepted contract is one-to-one. A one-to-many target requires an owner decision and a new architecture decision. | Shares schema, Goals, board, history, and migration contracts with M1–M5. | Existing Goals/flow images cannot be accepted under the current ADR. |
| M4 | 1 | Suggested semantic links and confidence scoring | Misaligned | `docs/design/mockups/goals_data_states.png`; accepted RR-R3 contract in ADR-001 | Automatic semantic matching is new authority and data scope, not an extension of exact links. | Needs explicit source, approval, persistence, audit, and bridge decisions. | Existing image is proposal evidence only. |
| M5 | 1 | Local Back-to-Goal as global history evidence | Misaligned | `docs/design/mockups/goal_to_work_flow.png`; this ledger, **Unscheduled product backlog** | A local return action does not define complete Back/Forward history. | Must be resolved with the shared navigation decision, not scheduled separately against the same routes. | Existing flow is partial evidence; no new image until history semantics are approved. |
| D1 | 1 | Replay of historical unchecked plan tasks | Duplicative | Both historical plans' top banners; `docs/delivery/task-briefs/README.md` | Unchecked boxes and retained briefs are archaeological contracts, not eligibility. | Duplicates C1–C5. | None. |
| D2 | 1 | Duplicate raster brand references | Duplicative | `docs/brand/README.md`; `docs/design/mockups/icon.png`, `full_logo.png`; `docs/brand/release-radar-icon-v1.png`, `release-radar-lockup-v1.png` | The mockup icon is a duplicate brand reference and the two lockup rasters cover the same direction. Preserve all files; brand README is authoritative. | Does not reopen completed AppIcon production. | None; existing references are adequate. |
| B1 | 1 | Supported live Codex attachment / automatic thread discovery | Blocked | ADR-001, **RR-05 feasibility outcome** | Open only when a supported authenticated sandbox-compatible endpoint exists. | External transport prerequisite absent. | None while blocked. |
| B2 | 1 | Portable archive exporter and exporter-produced fixture | Blocked | ADR-001, **Existing-project onboarding and portable project archive v1** | Exporter must establish the authoritative fixture before importer work. | Separate approved brief and complete fixture absent. | None while blocked. |
| B3 | 1 | Portable Import UI/implementation | Blocked | Same ADR section; base design, **Onboarding** | Cannot open before B2; Markdown, seed JSON, repository state, and SQLite copies are prohibited substitutes. | Depends on B2 and any later archive extension for newly approved planning data. | None while blocked. |
| F1 | 1 | Help | Deferred | Base design, **Onboarding** | Future Help remains outside the current onboarding and delivery gates. | No approved task or visual contract. | None. |
| F2 | 1 | Coherent owner-visible Back/Forward history | Deferred | This ledger, **Unscheduled product backlog** | Survives as a need, not as an approved interaction contract. | Must follow M1–M5 reconciliation and be serialized with shared navigation. | Decision gate prevents generation. |
| F3 | 1 | Deterministic wordmark/typeface and light/dark lockups | Deferred | `docs/brand/README.md`, **Remaining next-phase wordmark task** | Existing raster direction survives; the remaining deliverable is deterministic production artwork. | Independent of product IA after A1, but not currently released. | Existing raster lockup is adequate; no new AI mockup. |
| F4 | 1 | Swift optional-`.none` and test actor-isolation warnings | Deferred | This ledger, **Current gate** | Maintenance candidate only. | Independent files may be assigned separately after an explicit release. | None. |
| F5 | 1 | Developer ID/notarized distribution | Deferred | This ledger, **Current gate** and RR-10 accepted limitation | Open only if distribution expands beyond the owner Mac. | Conditional external scope decision. | None. |
| P1 | 1 | Recorded Project Plan visible UX | Proposed/unapproved | `docs/design/release-radar-project-planning-ux-proposal.md`, **Explicit gate statement** | The owner-directed Overview retention survives inside the proposal, but the complete Gate-1 package is not approved. | Shares IA, routes, planning data, archive, and history decisions with M1–M5. | Polished screenshots remain gated; generate nothing. |
| P2 | 1 | Process-isolated independent role-agent workflow | Proposed/unapproved | This ledger, **Pending owner decision — Process-isolated independent role agents** | Not approved and not a current delivery-model change. | Requires a separate explicit owner decision; unrelated to product mockups. | None. |
| P3 | 1 | CloudKit-backed read-only iPhone companion | Proposed/unapproved | `docs/design/cloudkit-iphone-companion-draft.md` | The discussion draft proposes private-cloud publication and a mobile reader but explicitly approves no product, architecture, or implementation work. | Conflicts with ADR-001's local-only/non-cloud authority; also depends on a supported truthful agent-status publisher, mobile IA, privacy/recovery decisions, and the final operational/artifact data boundary. | No mobile mockup until those owner and architecture gates are approved. |

### Mockup gap analysis and generation ruling

Direct inspection covered all 17 PNGs currently present under
`docs/design/mockups/`.
The accepted wide reference set is 1586 × 992; proposal studies use 2048 ×
1280 and 900 × 650. The established language is a deep graphite/navy macOS
window, fixed 220-point wide sidebar or 96-point compact rail, thin blue-gray
borders, subtle panel shadows, cyan selection and primary actions, restrained
status colors, generous native spacing, and read-only cards/inspectors.

| Candidate | Surviving requirement and canonical source | Existing coverage / overlap | Needed states | Ruling |
| --- | --- | --- | --- | --- |
| Projects/Overview portfolio health | Base design, **Goals** and **Dashboard model → Project overview** | No dedicated design PNG, but completed RR-06/RR-10 behavior has durable wide evidence in `docs/delivery/evidence/rr10-projects-overview-board-detail.png`. | Wide populated; compact behavior is already completed and evidenced. | Do not generate: completed work with adequate durable acceptance evidence. |
| Selected Phase Board ticket detail | Base design, **Dashboard model → Phase board** and acceptance criterion 3 | `phase_board.png` plus `dependencies.png` establish the visual pattern; completed integrated behavior is in `docs/delivery/evidence/rr10-projects-overview-board-detail.png`. | Wide selected detail; compact evidence exists in `docs/delivery/evidence/rr10-board-compact.png`. | Do not generate: completed work. |
| Compact five-lane Phase Board | Base design, **Dashboard model → Phase board** | `phase_board.png` is wide; `work_board_compact.png` is an unapproved all-phase proposal. Durable completed runtime evidence exists in `docs/delivery/evidence/rr10-board-compact.png`. | Compact ID/count cards and recoverable five lanes. | Do not generate: completed and already evidenced. |
| Truthful current onboarding state | Base design, **Onboarding** | `onboarding_state.png` has obsolete “first phase”/agent-contact copy and a Portable Import implication; the current text contract and completed delivery supersede it. | Initialize/Attach, copied-not-sent, unavailable/recovery. | Do not generate: completed UI; retain the old PNG as explicitly superseded historical evidence. |
| Project Plan polished screenshots | Proposed Project Plan document, **Explicit gate statement** | No existing Project Plan image; Work Board is an overlapping different proposal. | Wide/compact, no-Current, empty, incomplete, unavailable/error. | Owner Gate-1 decision prevents generation. |
| Goals / Work Board / History | Proposed redesign study and its eight tracked rasters | Images already exist but conflict with accepted IA/data contracts. | Existing wide/compact/state/flow studies are sufficient proposal evidence. | Generate nothing until M1–M5 are reconciled and approved. |
| Back/Forward | Unscheduled backlog and F2 | `goal_to_work_flow.png` covers only local return. | Wide/compact toolbar and complete history/error rules are undecided. | Owner decision gate prevents generation. |
| Wordmark/lockups | Brand README | Existing raster lockup adequately records the approved direction. | Future light/dark deterministic production artwork. | Not an AI-mockup gap. |
| Help, Portable Import, live attachment | F1, B1–B3 | No approved eligible surface. | Undefined or blocked. | Generate nothing while deferred/blocked. |
| Read-only iPhone companion | Concurrent proposed draft P3 | No approved mobile IA; proposed CloudKit authority conflicts with ADR-001 and truthful live status remains blocked. | Mobile dashboard/document states are undecided. | Owner/product/architecture gates prevent generation. |

**Generation result: 0 new mockups.** Every visually missing accepted surface
is completed and already has durable runtime evidence; every genuinely open
surface is proposed, misaligned, blocked, deferred, or missing an owner
decision. Generating any of them would violate the scope rule against mockups
for completed, speculative, blocked, or unresolved work.

### Dependency-safe priority order

| Priority / sequence | Status and gate | Dependencies and blocking decisions | Shared surfaces/contracts; concurrency | Mockup state | Why this priority |
| --- | --- | --- | --- | --- | --- |
| P0 / 1 — Owner runtime validation | **Completed; Done/Accepted** | Owner confirmed the installed Release workflow no longer produces the SQLite authorization error, persists pending tracking state across relaunch, and is accepted. | Installed app and local owner state; no product writer was released during validation. | No mockup required. | Closed successfully on 2026-08-27. |
| P0 / current — Repository-handoff acceptance correction | **Active; owner-approved versioned-guidance correction** | Implement and prove the versioned managed `AGENTS.md` block and read-only per-project current/outdated observation. | Preserve the installed typed MCP, lifecycle-helper, and authority boundaries; touch no current-repository `AGENTS.md`. | Existing onboarding and project overview surfaces only; no new route or mockup. | Owner acceptance is blocked until newly onboarded repositories receive deterministic guidance and Release Radar can truthfully identify older deployed guidance. |
| P1 / 2 — Coupled product/IA reconciliation | **Closed decision gate; next potential product work** | P0 is complete; owner decisions remain required for Phase Board/Project Plan/Work Board, Activity/History, one-to-one/one-to-many links, semantic suggestions, and complete history semantics; update the ADR where data authority changes. | Project navigation, board/plan routes, goal-link storage, observation provenance, archive coverage, focus/history state. Serialize as one design stream. | Existing proposal images retained but unapproved; new images only after decisions. | These choices overlap and cannot safely be planned or mocked independently. |
| P2 / 3 — Deterministic wordmark/lockups | **Deferred; separable candidate** | P0 is complete; explicit owner release and a production typeface/license or drawn outlines remain required. | Brand files only; may proceed independently from later product IA when released. | Existing raster direction adequate; no new AI mockup. | It is the only surviving visual-production candidate that does not share product routes or data. |
| P3 / 4 — Warning cleanup | **Deferred maintenance** | P0 is complete; explicit owner release remains required. | Compiler/test files; keep separate from product UI/data work. | None. | Low-risk maintenance that is not automatically released by remediation acceptance. |
| P4 / 5 — Portable exporter and fixture | **Blocked prerequisite** | P1 if approved planning concepts extend the archive; separate brief and complete exporter fixture. | Archive schema, persistence, migrations, evidence portability. Serialize with any archive-contract change. | None while blocked. | Export truth must exist before import can be designed or tested. |
| P5 / 6 — Portable Import | **Blocked dependent** | P4 accepted exporter/fixture and any required archive version decision. | Onboarding routes, storage transaction, folder authorization, archive validation. One writer after P4. | None while blocked. | Import cannot precede its authoritative source. |
| P6 / 7 — Live Codex attachment | **Externally blocked** | Supported authenticated sandbox-compatible endpoint. | Observer only; must remain separate from the mutation bridge and delivery authority. | None while blocked. | No local planning can remove the external transport prerequisite. |
| P7 / 8 — iPhone companion product/architecture decision | **Proposed/unapproved; closed** | P1 data-boundary decisions where relevant; a supported truthful status publisher; explicit owner product scope; replacement or amendment of ADR-001's local-only/non-cloud authority; mobile IA, privacy, retention, account, and recovery decisions. | Shares delivery/artifact authority, archive coverage, observation freshness, security/privacy, and cross-device persistence. Do not run in parallel with conflicting archive or live-status contract work. | No mobile mockups before the visible IA is approved. | Cloud publication changes a foundational authority boundary and must not be implied by a discussion draft. |
| P8 / 9 — Notarized distribution | **Conditional deferred** | Explicit distribution-scope expansion. | Packaging/signing only; independent of product IA after a stable release. | None. | It is unnecessary for the current owner-only distribution boundary. |
| P9 / 10 — Help | **Deferred** | Explicit product/visual contract after higher-priority navigation decisions. | Shares navigation and onboarding wording; serialize after P1 if opened. | None. | No approved scope or screen exists. |

No implementation work is released by this sequence. Completed, superseded,
misaligned, duplicative, blocked, deferred, and proposed items remain outside
the executable queue.

## Task ledger

Each task entry records status, verification, reviews with Required/Optional/Out-of-scope classification, decisions, risks, stop-rule events, commit SHA, and the next eligible task before release.

### RR-01 — Standalone signed application foundation

- Status: Accepted.
- Commits: `487647a` scaffold, `50dab32` evidence, `ca09ba8` focused-test fix, `c3e5f79` fix evidence.
- Verification: normal configured Debug signing build passed; `build_and_run.sh --verify` launched the app; build-for-testing and strict codesign verification passed; focused `AppRouteTests` completed with 2 passed, 0 failed/skipped.
- Code review: Approved; Required 0, Optional 0, Out of scope 0.
- QA: Initial Required finding — main scheme prepared the empty UI runner and the focused unit test never completed. Addressed by keeping the UI target buildable while limiting the current TestAction to unit tests; scoped re-review accepted with no new Critical/Important breakage.
- Architecture: Approved; standalone namespace, target boundaries, synchronized roots, sandbox/hardened signing, scenes, and ADR are structurally suitable for successors.
- Stop-rule event: first implementer attempt produced no files within the foundation timebox and was interrupted; a fresh bounded implementer completed the slice without expanding scope.
- Decisions/risks: UI acceptance execution remains assigned to the later seeded UI slice; no product risk in RR-01.
- Next eligible task: RR-02 transactional local delivery store.

### RR-02 release gate

- TPM: GO; RR-01 technically accepted and RR-02 dependency-safe.
- Delivery Manager: GO; no remaining Required blocker.

### RR-02 — Transactional local delivery store

- Status: Accepted and released.
- Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`), `5d8a735` (`fix: contain store callback capabilities`), `ad6a446` (`fix: reject transaction control in store reads`), `f5a06cf` (`fix: restrict store reads to observational SQL`).
- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, prevention of unaudited writes through read projections, rejection of escaped transaction/read callback handles, denial and rollback of callback-owned `COMMIT`, denial and rollback of callback mutations to `audit_events`, rejection of read-callback transaction control, and rejection of read-callback `PRAGMA foreign_keys=OFF` while preserving foreign-key enforcement and later valid audited writes. Full command/results are preserved in `docs/delivery/archive/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
- Verification: Fresh controller verification on 2026-08-23: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 15 of 15 with 0 failures/skips, and `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` completed with the configured Apple Development identity and Hardened Runtime. Implementer `git diff --check` passed.
- Reviews: Final recovery reviews are clean. Code Reviewer: ACCEPT, Required 0, Optional 0, Out of scope 0. QA: ACCEPT, 15/15 focused tests, 0 failures/skips, Required 0. Architect: APPROVED, ADR-001 deviation resolved, Required 0. Security/privacy: PASS, Required 0, Optional 0; an independent system-SQLite probe confirmed state-setting PRAGMAs are denied, ordinary SELECT remains available, and foreign-key enforcement remains enabled.
- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks deny transaction control and cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read callbacks now use a strict SQLite authorizer allowlist limited to SELECT, READ, and FUNCTION actions, denying PRAGMA and every connection/schema/transaction/mutation action by default; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
- Risks: No open RR-02 Required finding. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
- Stop-rule events: The original read-boundary remediation stopped after two rounds when review found that the denylist still admitted SQLite connection-state mutation. A fresh recovery implementer preserved the existing lease, audit, and transaction protections and replaced only the read authorizer policy with the smaller fail-closed observational allowlist.
- Next eligible task: RR-03 typed agent action bridge.

### RR-03 release gate

- TPM: GO; RR-02 is technically accepted with all Required findings closed, scope controlled, and the recorded stop-rule recovery complete.
- Delivery Manager: GO; RR-02 commits, focused verification, signed build, independent reviews, and stop-rule evidence are durable; RR-03 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-03 — Typed agent action bridge

- Status: Accepted and released.
- Commits: `6b7262c` (`feat: add typed agent delivery actions`), `fa8eea0` (`feat: add signed agent bridge transport`), `abb92ef` (`fix: enforce agent bridge result contracts`), `6cbfcb4` (`fix: enforce bridge deadline inside store transaction`), and `7afbe0b` (`fix: report uncertain bridge outcomes truthfully`).
- Implemented scope: the committed typed command/dispatcher core plus a packaged MCP stdio tool, sandboxed LaunchAgent broker, application-hosted callback, exact wire/envelope/size/admission-deadline bounds, same-user and pinned team/identifier signing requirements on every XPC hop, app lifecycle registration, and explicit definitive-versus-uncertain delivery results. The broker/tool do not link `ReleaseRadarCore` or SQLite and cannot open the authoritative store.
- TDD: the original transport and two deadline fix rounds remain recorded in the task report. Recovery RED `/tmp/rr03-recovery-red-clean.log` exposed the absent `outcomeUnknown` result and post-dispatch/pre-reply seam. Recovery GREEN `/tmp/rr03-recovery-green-3.log` passed all 11 focused bridge/transport cases, including pre-admission expiry with no eventual write, committed reply loss followed by exact replay, callback invalidation after handoff, distinct wire/envelope versions, MCP error flags, and strict JSON integer/optional-string rejection.
- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The recovery combined run exercised byte-identical normal-package broker/tool binaries and passed 26/26 transport/core/store tests with 0 failures/skips. Normal/test CDHashes matched before and after execution: broker `ce676ee13847bb703a648ad8c5e4e71ca90b0024`, tool `5dd2f5fecc2d98c84ab8189afe635d37ba01d39f`. Cleanup left no registered service or exact helper process; diff checks passed.
- Stop-rule recovery: the earlier anonymous-endpoint and app-owned listener attempts remain recorded as stopped and removed. The fresh recovery used the architect-approved minimal correction: a sandboxed broker with the same-team app group, an unsandboxed tool without the group, two team-prefixed Mach services, and no weaker fallback.
- Deadline stop-rule recovery: after two deadline remediation rounds, independent review showed that `appUnavailable` could still falsely imply no mutation after authenticated callback handoff. The recovery preserves pre-admission no-write enforcement but gives post-handoff uncertainty its own non-persisted `outcomeUnknown` result. Wire protocol version 2 is distinct from durable envelope version 1; once a transaction is admitted it runs to completion, and exact replay after an unknown result returns the original durable result without a duplicate mutation or audit.
- Controller verification: on 2026-08-24, the exact focused `AgentBridgeTransportAcceptanceTests`, `AgentBridgeAcceptanceTests`, and `StoreAcceptanceTests` command passed 26/26 with 0 failures/skips from `/tmp/rr03-controller-verify`; strict deep package signing passed and cleanup reported no registered LaunchAgent or helper process.
- Reviews: Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. QA ACCEPT after a fresh 26/26 signed-package run, Required 0, Optional 0. Architect APPROVED, Required 0 and no ADR update required. Security/privacy PASS, Required 0, Optional 0, Out of scope 0; the original permissive JSON, MCP error, and false timeout findings are closed.
- Decisions/risks: preserve the app-only SQLite writer boundary and durable envelope-version-1 replay. The app composes persisted authorized roots into the existing registry seam; the broker holds only the latest authenticated callback in memory. Transport failures before authenticated callback invocation are definitive `appUnavailable`; timer, callback, or XPC failure after invocation is `outcomeUnknown`. On machines where ServiceManagement returns `requiresApproval`, the app logs the explicit Login Items & Extensions owner action and does not weaken or bypass the gate.
- Next eligible task: RR-04 onboarding and required first-phase creation.

### RR-04 release gate

- TPM: GO; RR-03 is technically accepted with all Required findings closed, truthful outcome/replay semantics verified, and scope controlled through the recorded stop-rule recovery.
- Delivery Manager: GO; RR-03 commits, 26-case focused verification, signed-package boundaries, cleanup, and all four independent reviews are durable. RR-04 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-04 — Folder-backed project onboarding and first phase

- Status: Accepted and released.
- Commits: `0012372` (`feat: onboard folder-backed projects`), `af5dd0a` (`fix: harden project onboarding boundaries`), and `f545034` (`fix: reject denied bookmark scope access`).
- Scope: Native folder selection, read-only security-scoped bookmark persistence, canonical component containment, Git-root/worktree discovery, separately authorized external worktrees, durable task exclusions, first-phase gating through the typed dispatcher, persisted unmatched-task review items, and `first_dashboard_opened = false`.
- TDD: RED at `/tmp/rr04-red.log` established the missing onboarding/bookmark/worktree contracts. A second focused RED at `/tmp/rr04-red-authorize.log` established that external worktrees require an explicit authorization path. GREEN at `/tmp/rr04-green.log` covers root/descendant/contained-worktree inclusion, sibling-prefix/outside rejection, separately authorized worktrees, no-phase refusal, typed first-phase audit, durable exclusion after a recreated onboarding service, persisted review items, and notification ineligibility.
- Verification: Final focused `OnboardingAcceptanceTests` and directly affected `StoreAcceptanceTests` passed 20/20 with 0 failures/skips. Controller verification on 2026-08-24 repeated the 20/20 pass from `/tmp/rr04-controller-verify`; a normal signed Debug package built with the configured Apple Development identity and passed strict deep codesign verification.
- Reviews: Final Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. Final QA ACCEPT, 20/20 focused cases, Required 0, Optional 0, Out of scope 0. Architect APPROVED, Required 0 and no ADR update required. Security/privacy PASS, Required 0, Optional 0, Out of scope 0.
- Remediation evidence: The first review rejected manual phase impersonation, fail-open bookmark persistence, cross-project root transfer, non-durable editable exclusions, and an ineffective no-phase test. Fix round 1 replaced phase fabrication with an app-owned audited request/wait state, made stale/failed bookmarks unavailable under balanced scope access, rejected root ownership conflicts, reconciled exclusions, and exercised the prepared-but-phase-less gate. Fix round 2 closed the sole residual finding by rejecting denied security-scope starts before discovery or persistence. Both rounds remained within RR-04.
- Decisions/risks: The onboarding service never treats a path prefix as containment. A worktree outside the folder bookmark is rejected until the owner selects that exact discovered worktree. Stale, failed, or denied bookmark access fails closed. The app writes project/request/review metadata only through store-owned audited transactions; only a real agent-originated typed bridge upsert can satisfy phase one. No Codex live-observer, board, importer, notification event, or notification sender behavior is introduced.
- Next eligible task: RR-06 recognizable local-first board.

### RR-06 release gate

- TPM: GO; RR-04 is technically accepted with every Required onboarding, bookmark, ownership, phase-gate, exclusion, and notification-silence finding closed.
- Delivery Manager: GO; RR-04 commits, 20-case controller verification, signed build, independent reviews, and both bounded remediation rounds are durable. RR-06 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-06 — Recognizable local-first board

- Status: Accepted and released.
- Commits: `baeb390` (`feat: add persisted phase dashboard`) and `1ab6486` (`fix: preserve project dashboard context`).
- Scope: Idempotent audited sample persistence for the approved Rekon Pursuit project, Post-MVP refinement phase, 31 tickets, dependencies, blockers, evidence, observed goal/thread link, audit event, and notification history; Projects, Project Overview, and an adaptive five-lane Phase Board; read-only selected-ticket context; a fixed 220-point/96-point navigation rail; and unchanged placeholders for later screens and settings. No live observer, importer, Pushover sender, schema migration, or dependency was added.
- TDD: Initial focused RED at `/tmp/rr06-red.log` failed to compile because `DashboardSampleData`, `DashboardProjection`, and `DashboardLayout` did not exist. Projection GREEN at `/tmp/rr06-projection-green-attempt.log` passed 4/4. The first review-fix RED at `/tmp/rr06-fix1-red.log` failed only because project-level goal context and non-first-project navigation APIs were absent. Fix GREEN at `/tmp/rr06-fix1-green.log` and fresh final verification at `/tmp/rr06-fix1-final-tests.log` passed 8/8 across `DashboardProjectionTests` and `AppRouteTests`, with 0 failures/skips. Coverage proves the ordered counts `[9, 1, 2, 1, 18]`, 31 unique single-lane ticket memberships, seeded `VD2-08` dependency counts, complete read-only `VD2-07c` context and relationship direction, relaunch persistence/idempotence, wide/compact presentation thresholds, verified and unavailable project-goal projections, and non-first-project context through Board, Dependencies, Activity, and back to Projects.
- Build/launch evidence: `./script/build_and_run.sh --verify` completed a normal configured Debug build, signed and launched `DerivedData/Build/Products/Debug/ReleaseRadar.app`, and fresh strict deep codesign verification passed; first-review-fix evidence is in `/tmp/rr06-fix1-build-run.log` and `/tmp/rr06-fix1-codesign.log`. The running normal bundle truthfully surfaces the pre-existing database recovery condition described below.
- Seeded UI evidence: An otherwise identical configured Debug build used the temporary capture-only bundle identifier `com.rekonlabs.ReleaseRadar.RR06Capture` to obtain a fresh sandbox without touching owner data; `/tmp/rr06-fix1-capture-build.log` records the successful build and `/tmp/rr06-fix1-capture-codesign.log` records strict deep codesign verification. `docs/delivery/evidence/rr06-owner-wide.png` and `docs/delivery/evidence/rr06-owner-narrow.png` remain the approved unchanged board evidence. `docs/delivery/evidence/rr06-fix1-projects.png` and `docs/delivery/evidence/rr06-fix1-overview.png` show active phase, verified last-known goal status/context and observation time, current-work count, and owner-attention count on the two affected screens. The temporary bundle's Documents request was denied; no folder access was granted. The captures retain the known macOS background-item banner at the extreme top-right; no product remediation was made for OS chrome.
- Controller verification: On 2026-08-24, the focused `DashboardProjectionTests` and `AppRouteTests` command passed 8/8 with 0 failures/skips from `/tmp/rr06-controller-verify`; the produced configured Debug app passed strict deep codesign verification.
- Reviews: Initial review identified two Required findings: first-project-only navigation context and missing persisted project-level goal state. Both were addressed in `1ab6486`. Final Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. Final QA ACCEPT, fresh 8/8 focused cases, Required 0, Optional 0; the persistent macOS banner is classified Out of scope as OS chrome. Architect APPROVED, Required 0 and no ADR update required. Security/privacy PASS, Required 0, Optional 0, Out of scope 0.
- Decisions/risks: Lane membership is the sole ticket state projection. Project navigation now retains the explicit selected project ID and also derives it from every project-scoped route; the sidebar label and all project-route buttons use that same projected project. Projects and Overview label the latest persisted `observed_goals` row as a verified last-known goal, or state that no persisted goal observation is available; no live observation was added. Cards remain selection-only; the inspector exposes outcome, verified/last-known goal context, dependency direction, owner attention, evidence, audit, and notification histories without manual state controls. The existing owner database at `~/Library/Containers/com.rekonlabs.ReleaseRadar/Data/Library/Application Support/com.rekonlabs.ReleaseRadar/release-radar.sqlite` has `PRAGMA user_version = 3` but a legacy `audit_events` shape without `thread_attribution`. It was inspected read-only and left intact; recovery/repair belongs to the later failure-state work rather than RR-06.
- Stop-rule evidence: A narrow-layout lane-width defect was corrected within the second bounded compile/remediation attempt. Work on the unrelated persistent macOS capture banner stopped after one dismissal attempt.
- Next eligible task: RR-05 read-only live Codex observation feasibility and bounded implementation.

### RR-05 release gate

- TPM: GO; RR-06 is technically accepted with its navigation and project-goal findings closed, responsive board evidence verified, and no manual delivery controls or deferred-screen scope added.
- Delivery Manager: GO; RR-06 commits, 8-case controller verification, signed build/launch evidence, wide/narrow screenshots, and all four independent reviews are durable. RR-05 is dependency-safe and released to one fresh Implementer with no concurrent writer.

### RR-05 — Read-only Codex observation feasibility

- Status: Accepted and released as the explicit unavailable/cached-stale feasibility outcome.
- Commits: `ae5fd63` (`feat: define unavailable Codex observation`) and `c94135f` (`fix: scope cached Codex observations`).
- Feasibility evidence: Codex CLI `0.147.0` official manual/help and the running desktop process were inspected in two bounded read-only passes. The desktop app-server uses its default parent-owned stdio transport and exposes no supported named Unix or TCP listener for a separately sandboxed authenticated client. A separately started app-server is not evidence of the desktop task's state. No Codex database, rollout/session file, terminal, log, UI, or undocumented IPC content was read; no Codex task was mutated.
- Scope: Added normalized thread, goal, completion, waiting, freshness, snapshot, and event models; the required read-only `CodexObserver` contract; an `UnavailableCodexObserver`; and app-state loading. With no cache it reports `unavailable`. Any injected cached snapshot, including one captured as live, is normalized to `stale` with its last-observed time and retained last-known state. No app-server client, helper, importer, notification sender, dependency screen, or RR-07 feature was added.
- TDD and verification: Initial RED failed because the observer models did not exist. Focused observer GREEN passed 4/4, and the app-state integration test passed 1/1 (`/tmp/rr05-focused-green.log`). The fixture covers Active, Paused, Blocked, Awaiting input, Completed/Ready for review, active flags, active goal, and cleared goal. A store-backed boundary case proves observation leaves the formal RR-05 ticket lane unchanged. The directly affected `DashboardProjectionTests` regression passed 5/5 (`/tmp/rr05-projection-regression.log`). `./script/build_and_run.sh --verify` completed the configured signed Debug build (`/tmp/rr05-build-run.log`), and strict deep codesign verification passed (`/tmp/rr05-codesign.log`). Diff checks passed.
- Decision/risk: Live observation remains blocked until Codex exposes a supported authenticated attach surface for the running desktop task. Fixture/cache data is never labeled live, and observer failure cannot become delivery authority. RR-07's explicit unavailable/stale presentation dependency becomes eligible only after independent acceptance of this recorded outcome.
- Required fix round 1: Initial QA found that unsupported cached schema versions were still presented as stale and that cached threads were not bounded to the selected project's authorized roots/exclusions. RED at `/tmp/rr05-fix1-red.log` failed on the absent scope contract. The fix accepts cached schema version 1 only, requires an injected canonical `CodexObservationScope`, filters by component-wise selected-root/descendant or separately authorized worktree containment, rejects sibling-prefix/outside/nonexistent/symlink-escape and excluded threads, and normalizes accepted working directories. Cached data without a scope is unavailable and empty. Final affected verification passed 16/16 observer, dashboard-projection, and app-route cases (`/tmp/rr05-fix1-final-tests.log`); the configured signed build/launch and strict deep codesign verification passed (`/tmp/rr05-fix1-build-run.log`, `/tmp/rr05-fix1-codesign.log`).
- Controller verification: On 2026-08-24, the focused observer, dashboard-projection, and app-route command passed 16/16 with zero failures/skips from `/tmp/rr05-controller`; a configured Debug build passed, and the produced app passed strict deep codesign verification.
- Reviews: Code Reviewer ACCEPT, Required 0, Optional 0, Out of scope 0. QA ACCEPT, both prior Required findings closed, focused verification and signed launch/codesign clean. Architect ACCEPT, Required 0 and no ADR/deviation required; its optional wording clarification is non-blocking. Security/privacy ACCEPT, Required 0, Optional 0, Out of scope 0.
- Decision/risk: Release Radar does not claim live Codex state. Authorized compatible cache is always stale; absent scope, incompatible schema, or absent cache is unavailable and empty. The observation layer cannot mutate formal delivery lanes. A supported authenticated sandbox-compatible shared desktop attachment remains an open product blocker, but the approved degraded path is safe and dependency-complete for RR-07.
- Next eligible task: RR-07 Needs Review, dependencies, activity, and settings navigation.

### RR-07 release gate

- TPM: GO; RR-05 truthfully completed its bounded feasibility gate, retained only scoped cached-stale state, and closed every Required review finding.
- Delivery Manager: GO; RR-05 implementation, fix, controller verification, signed build, and four independent reviews are durable. RR-07 is dependency-safe under the plan's explicit unavailable/stale branch and is released to one Implementer with no concurrent writer.

### RR-07 — Needs Review, dependencies, activity, and settings navigation

- Status: Accepted and released.
- Scope: Added the persisted Needs Review master/detail inbox for uncertain imports, possible duplicates, unresolved dependencies, unmatched tasks, excluded tasks, and agent review requests; audited Resolve/Dismiss actions through the existing typed agent-action boundary without lane mutation; an exact ticket dependency graph with direct, indirect, and unlock projections, semantic lane colors, blocker counts, and precise connector endpoints; persisted project activity that keeps formal delivery lane separate from last-observed runtime state; and General, Connections, Notifications, and Projects settings tabs. Live Codex attachment, imports, network delivery, credential storage, notification sending, and database recovery remain out of scope.
- Commits: `bb9f5b7` (`feat: support audited review decisions`), `4838c33` (`feat: project review inbox and dependency graph`), `472ef3a` (`feat: project activity and settings states`), `6011738` (`feat: add review graph activity and settings surfaces`), `83fd317` (`fix: scope dependency graph edges to phase`), and `4925339` (`fix(rr-07): preserve review origin and scope activity audits`).
- TDD: Focused RED/GREEN logs are `/tmp/rr07-review-boundary-{red,green}.log`, `/tmp/rr07-inbox-{red,green}.log`, `/tmp/rr07-graph-{red,green}.log`, `/tmp/rr07-activity-settings-{red,green}.log`, `/tmp/rr07-appmodel-{red,green}.log`, and `/tmp/rr07-sample-review-{red,green}.log`. The fresh final run at `/tmp/rr07-final-tests.log` passed 24/24 cases across RR-07, agent-bridge, dashboard projection, and route tests with 0 failures/skips.
- Build and visual evidence: `./script/build_and_run.sh --verify` succeeded at `/tmp/rr07-build-run.log`; strict deep codesign verification passed for the Apple Development-signed `com.rekonlabs.ReleaseRadar` app with hardened runtime. A separate `com.rekonlabs.ReleaseRadar.RR07Capture` build used fresh isolated app data and produced `docs/delivery/evidence/rr07-needs-review.png`, `rr07-dependencies.png`, `rr07-activity.png`, and `rr07-settings.png`. Accessibility inspection confirmed the six review rows and both actions; VD2-08's 2 direct requirements, 3 indirect requirements, and 3 unlocks; persisted activity with distinct Lane and Runtime labels; and truthful unavailable Codex connection text.
- Fix round 1: `83fd317` scopes dependency edges to the selected phase's loaded node set, so inspector traversal and layout connectors cannot consume invisible cross-phase relationships. The two-phase regression failed on the prior implementation at `/tmp/rr07-fix1-cross-phase-red.log`, passed after the fix at `/tmp/rr07-fix1-cross-phase-green.log`, and the fresh directly affected 8/8 review/graph suite passed at `/tmp/rr07-fix1-final.log` with 0 failures/skips. Code Reviewer and QA re-review accepted the fix with no remaining Required or Optional findings.
- Fix round 2: `4925339` gives SwiftUI review decisions an explicit owner-app origin while preserving asserted-thread attribution for external agent commands through the same dispatcher validation and mutation path. Additive schema version 4 adds nullable audit `project_id`, `entity_type`, and `entity_id`; the store accepts an optional typed scope, and every dispatcher command supplies one. Activity now selects audits by exact structured project/entity scope, excludes legacy unscoped rows, and derives review timestamps without reason-text correlation. RED/GREEN evidence is `/tmp/rr07-fix2-origin-{red,green}.log`, `/tmp/rr07-fix2-audit-scope-{red,green}.log`, `/tmp/rr07-fix2-dispatch-scope-{red,green}.log`, and `/tmp/rr07-fix2-activity-scope-{red,green}.log`. The fresh required Review/Graph, Store, and Agent Bridge run passed 34/34 with 0 failures/skips at `/tmp/rr07-fix2-required-suites.log`; the non-launching configured Debug build and strict deep codesign verification passed at `/tmp/rr07-fix2-signed-build.log` and `/tmp/rr07-fix2-codesign.log`. The known owner legacy schema drift was neither detected nor repaired, and the owner database was not opened during verification.
- Controller verification: On 2026-08-24, the final focused Review/Graph, Store, Agent Bridge, Dashboard Projection, and App Route command passed 43/43 with zero failures/skips from `/tmp/rr07-final-controller`; a configured Debug build succeeded and the app passed strict deep codesign verification.
- Reviews: Final Code Reviewer ACCEPT, Required 0, Optional 0. Final QA ACCEPT, Required 0, Optional 0. Architect ACCEPT, Required 0, no ADR/deviation required; its terminology note for legacy `resolveImportReview` command names is non-blocking. Security/privacy ACCEPT, Required 0, Optional 0; the cross-project reason-text disclosure is closed and external wire input cannot select owner attribution.
- Decisions/risks: The app-only store remains the sole SQLite writer and observers remain read-only. Review actions require an authorized persisted project root; when none exists, the app surfaces an explicit failure and preserves the open review item. The fresh sample intentionally has no fabricated root. Only Needs Review and Notifications carry sidebar badges, so notification history does not introduce a duplicate bell/count surface. Existing database recovery remains owned by RR-10 and was not changed.
- Next eligible task: RR-08 one-time recognized Rekon delivery artifact import.

### RR-08 release gate

- TPM: GO; RR-07 is accepted with all Required graph, audit-attribution, and project-isolation findings closed, and its final controller evidence is proportional and clean.
- Delivery Manager: GO; RR-07 commits, two bounded remediation rounds, 43-case controller verification, signed package, four screenshots, and four independent reviews are durable. RR-08 is dependency-safe and released to one Implementer with no concurrent writer.

### RR-08 — One-time recognized Rekon delivery import

- Status: Accepted. RR-09 is released.
- Commits: `e0569be` (`feat: import Rekon delivery records`), `c60800c` (`fix: harden Rekon import boundaries`), `5c3c130` (`fix: account for persisted import cycles`), `25e88ed` (`fix: persist active phase and anchor artifact reads`).
- Scope: Added a bounded schema-version-1 Rekon dashboard JSON preview and one-time importer. It maps confident phases, tickets, five lane values, phase/ticket dependencies, and explicit evidence links; recognizes only the fixed roadmap, task-brief, handoff, and ledger evidence families; and never parses arbitrary Markdown as delivery authority. Duplicate IDs, missing outcomes, unresolved references, unmapped states, and existing-record conflicts become deterministic Needs Review items.
- Persistence and boundaries: Apply revalidates the preview, configured authorization, persisted project/root ownership, and evidence containment before writing. One app-owned audited transaction inserts only non-conflicting delivery records, preserves resolved/dismissed review status on replay, remains record-idempotent, writes no notification events, and marks missing importer-owned evidence unavailable without deleting imported delivery state or changing source files.
- TDD: Preview RED is `/tmp/rr08-preview-red.log`; preview GREEN is `/tmp/rr08-preview-green.log`; apply RED is `/tmp/rr08-apply-red.log`; the bounded compile correction is `/tmp/rr08-apply-green-attempt1.log`; and first full apply GREEN is `/tmp/rr08-apply-green-attempt2.log`.
- Implementer verification: Fresh focused verification at `/tmp/rr08-final-tests.log` passed 6/6 `RekonImportAcceptanceTests` with zero failures/skips. The separate configured Debug build at `/tmp/rr08-final-build.log` succeeded with the configured Apple Development identity, and strict deep codesign verification of `/tmp/rr08-final-build/Build/Products/Debug/ReleaseRadar.app` passed. `git diff --check` passed before the feature commit.
- Required fix round 1: Canonical regular-file checks now reject an artifact symlink escaping the authorized source root before decoding. Artifact size is checked from metadata and enforced again through a bounded maximum-plus-one read; recognized evidence discovery uses capped top-level enumeration, limits retained records, canonicalizes every retained path, and accepts only regular files. Deterministically ordered phase and ticket edges that would create multi-node cycles are excluded into `unresolved_dependency` review items while valid records and edges remain applicable. All three findings used RED/GREEN regressions with zero unsuccessful implementation attempts: `/tmp/rr08-fix1-artifact-{red,green}.log`, `/tmp/rr08-fix1-evidence-{red,green}.log`, and `/tmp/rr08-fix1-cycles-{red,green}.log`.
- Fix-round verification: Fresh importer and Store verification at `/tmp/rr08-fix1-final-tests.log` passed 25/25 tests (9 importer, 16 Store) with zero failures/skips. The configured signed Debug build at `/tmp/rr08-fix1-final-build.log` succeeded, and strict deep codesign verification at `/tmp/rr08-fix1-codesign.log` reported the app valid on disk and satisfying its designated requirement. `git diff --check` passed before the fix commit.
- Required fix round 2: The first re-review accepted the symlink and bounded-input fixes and retained one Required cycle finding: apply considered only the source preview graph, so a reverse edge against an already persisted project edge reached the store trigger and rolled back otherwise valid records. Apply now loads each target project's phase and ticket dependency graphs in deterministic order, treats exact persisted edges as idempotent, and checks every other available-endpoint import edge against persisted plus earlier accepted import edges. Cycle-producing edges become the same deterministic open `unresolved_dependency` reviews without weakening the store triggers, catching broad SQLite errors, emitting notifications, or rolling back unrelated confident records. The focused persisted phase-and-ticket RED/GREEN evidence is `/tmp/rr08-fix2-persisted-cycle-{red,green}.log`; the production change passed on the first implementation attempt in this round.
- Fix-round 2 verification: Fresh importer and Store verification at `/tmp/rr08-fix2-final-tests.log` passed 26/26 tests (10 importer, 16 Store) with zero failures/skips. The configured signed Debug build at `/tmp/rr08-fix2-final-build.log` succeeded, and strict deep codesign verification at `/tmp/rr08-fix2-codesign.log` reported the app valid on disk and satisfying its designated requirement. `git diff --check` passed before the code commit.
- Required fix round 3: Additive schema version 5 persists one explicit active phase per project in `project_active_phases`, with composite same-project foreign-key integrity and a phase lookup index. Migration backfills only projects that have exactly one phase; multi-phase projects remain unset. A confident imported `activePhaseId` becomes authoritative, a real first agent-created sole phase initializes the relationship without later replacement, sample data selects its phase explicitly, and the dashboard no longer guesses from row order. Projects without a valid explicit active phase remain visible with a truthful `No active phase` projection and no board. Active-phase RED is `/tmp/rr08-active-phase-red.log`; the first implementation attempt failed because updating `projects` caused SQLite foreign-key evaluation to touch the transaction-protected audit table. The materially different normalized-table attempt passed all 7 focused cases at `/tmp/rr08-active-phase-green-2.log`; unsuccessful active-phase attempts: 1.
- Required fix round 3 artifact boundary: Preview now opens the canonical authorized root once and traverses exact `docs/delivery/dashboard-status.json` components with descriptor-relative `openat`, `O_DIRECTORY`, `O_NOFOLLOW`, and `O_CLOEXEC`. It verifies regular-file type and size with `fstat` on the opened descriptor and performs the maximum-plus-one bounded read from that same descriptor, closing every descriptor on all paths. There is no pathname reopen after validation. The two within-root component/final symlink regressions failed against the old implementation at `/tmp/rr08-secure-reader-red.log`; those cases plus the existing escape and oversize cases passed at `/tmp/rr08-secure-reader-green.log`; unsuccessful descriptor-reader implementation attempts: 0.
- Fix-round 3 verification: Fresh importer, Store, Dashboard Projection, Agent Bridge, and Onboarding verification at `/tmp/rr08-active-secure-final-tests.log` passed 53/53 tests with zero failures/skips. The configured signed Debug build at `/tmp/rr08-active-secure-final-build.log` succeeded. Strict deep verification at `/tmp/rr08-active-secure-codesign.log` reported `com.rekonlabs.ReleaseRadar` valid on disk, satisfying its designated requirement, and signed by the configured Apple Development identity. `git diff --check` passed before the code commit.
- Reviews: Initial Code Reviewer requested 3 Required fixes; the first re-review accepted 2 and retained the persisted-cycle issue closed in round 2. Round 3 closed the newly reported explicit-active-phase and artifact TOCTOU findings. Final independent Code Review ACCEPT: 0 Required, 0 Optional, 0 Out of scope. QA ACCEPT: 0 Required and one unchanged optional direct malformed/cardinality test suggestion that does not block this slice. Architect ACCEPT: 0 Required/Optional/Out of scope and no ADR or deviation. Security/privacy ACCEPT: 0 Required/Optional/Out of scope.
- Controller verification: A fresh isolated run of the importer, Store, Dashboard Projection, Agent Bridge, and Onboarding suites exited successfully with all selected tests passing. The worktree and `git diff --check` remained clean before this gate update.
- Decisions/risks: The existing Rekon project was inspected read-only only to confirm the stable field and evidence-path shapes; acceptance uses a copied synthetic fixture and never imports owner project data. This is a one-time seed, not ongoing synchronization. The owner database was not opened, inspected, migrated, or repaired in round 3. No notification delivery, UI integration, live Codex attachment, arbitrary Markdown inference, or owner database recovery was introduced.
- Next eligible task: RR-09 — app-owned Pushover and notification history.

### RR-09 release gate

- TPM: GO; RR-08 is accepted with all Required importer, active-phase, cycle, and artifact-boundary findings closed. The approved degraded RR-05 live-state semantics remain explicit and do not block app-owned notification delivery.
- Delivery Manager: GO; RR-08 commits, bounded remediation attempts, controller verification, signed package, and four independent acceptances are durable. RR-09 is dependency-safe and released to one Implementer with no concurrent writer.

### RR-09 — App-owned Pushover alerts and notification history

- Status: Accepted. RR-10 is released.
- Commits: `02a71fb` (`feat: add durable Pushover alerts`), `361fb2c` (`docs: record RR-09 verification`), `8781860` (`fix: isolate durable notification dispatch`), `c8b8866` (`fix: coordinate app notification delivery`), and `c701434` (`fix: serialize notification work cycles`).
- Scope: Added atomic meaningful-event occurrence tracking and a durable notification outbox for linked goal blocked, agent completion/review, and ticket/import Needs Review entry. Identical replay and relaunch do not duplicate an occurrence; leaving and re-entering an eligible state opens a new occurrence. Paused linked goals and all events before the first dashboard open remain silent.
- Delivery boundary: The app stores Pushover credentials as two non-synchronizable `WhenUnlockedThisDeviceOnly` Keychain items and sends only fixed, app-derived title/message text to the fixed HTTPS `api.pushover.net` endpoint. The outbox durably records `attempt_started` before transport; an interrupted in-flight attempt becomes visible `unknown` on launch and is never retried automatically. Provider failures are sanitized, visible, and non-blocking; raw provider bodies, agent reasons, goal text, paths, and imported content are not copied into the notification record or request.
- UI: Notifications is a full-width persisted history with explicit queued, sending, unknown, sent, and failed states. The existing Notifications sidebar badge remains the single count surface; the menu-bar view shows recent alert state without a second bell/count. Existing Connections and Notifications settings tabs now expose configuration state, device-only storage guidance, and save/remove controls.
- TDD: Core notification RED/GREEN evidence is `/tmp/rr09-core-{red,green-attempt1}.log` (7/7 GREEN). Focused import, projection, completion, redirect-boundary, and migration RED/GREEN evidence is `/tmp/rr09-import-{red,green}.log`, `/tmp/rr09-projection-{red,green-2}.log`, `/tmp/rr09-completion-{red,green}.log`, `/tmp/rr09-redirect-{red,green}.log`, and `/tmp/rr09-store-migration-green.log`; each focused GREEN passed. Fake transport coverage directly observes the durable attempt marker before transport, terminal failure projection, ambiguous-attempt recovery without retry, occurrence deduplication/re-entry, pause and onboarding silence, sanitized copy, fixed endpoint, and redirect rejection.
- Implementer verification: Fresh combined Notification, Rekon Import, Agent Bridge, Store, Review/Graph, Dashboard Projection, and App Route verification passed 73/73 selected tests with zero failures/skips at `/tmp/rr09-final-affected-tests.log`. An isolated configured Debug build succeeded at `/tmp/rr09-final-build.7sqiIL` using the configured Apple Development identity; strict deep codesign reported the app valid on disk and satisfying its designated requirement. Build/signature evidence is `/tmp/rr09-final-signed-build.log`, `/tmp/rr09-final-codesign.log`, `/tmp/rr09-final-signing-identity.log`, and `/tmp/rr09-final-entitlements.log`. Final diff checks passed.
- Attempts: One unsuccessful product implementation attempt occurred when the initial notification projection expression did not compile; the localized correction passed on the next run. The redirect credential-boundary regression and all other production behaviors passed on their first implementation attempt. The stale schema-version expectations and incomplete synthetic migration fixture were test-fixture corrections, not product remediations.
- Initial independent reviews: Code Review REJECT with 5 Required findings and no Optional findings: competing app dispatchers can misclassify a live attempt as crash-ambiguous; ticketless review/import events are excluded from every visible history/count surface; bridge-created events do not refresh cached app projections; direct sidebar board/overview navigation can leave first-open suppression active; and cross-project goal/occurrence identity is unsafe. QA REJECT with 5 Required findings and no Optional findings: the signed sandbox lacks outbound-network client entitlement; bridge replies await a potentially 20-second send despite the tool's 10-second deadline; ticketless events are invisible; occurrence identity is not project-scoped; and the explicit successful-send replay/relaunch acceptance proof is absent. Overlapping findings are one remediation scope, not duplicate requirements.
- Required fix round 1 scope: Use one coordinated app-owned dispatch owner; perform crash recovery only at a true launch boundary and prevent concurrent callers from reclassifying live attempts. Return bridge results immediately after the committed mutation and schedule notification delivery separately, then refresh the affected project's cached notification history/badge/menu state on the main app model. Scope activity by `notification_events.project_id`, including ticketless review/import failure rows. Persist first-dashboard-open for every actual project dashboard entry path and sequence it before later eligibility. Reject cross-project goal ownership and project-scope occurrence keys/fingerprints/deactivation. Add the sandbox outbound-network client entitlement. Add focused regressions for these seams and one successful send that remains exactly one across recreated store/dispatcher and replay/relaunch.
- Required fix round 1 result: Commits `8781860` and `c8b8866` closed ticketless visibility, model refresh, direct-route first-open sequencing, project identity, nonblocking bridge reply, outbound-network entitlement, and successful replay/relaunch evidence. Independent QA ACCEPTED all scoped cases. Code re-review retained 2 Required concurrency findings: launch recovery can suspend before its recovery transaction and overlap ordinary dispatch, reclassifying a newly live attempt as `unknown`; and a callback arriving during an in-flight send can return without scheduling a rescan, stranding an event committed after the first pending-ID snapshot. This is the first unsuccessful remediation attempt for the dispatcher-concurrency workstream.
- Required fix round 2 scope: Serialize launch recovery against all ordinary dispatch work, and coalesce concurrent dispatch requests so any event queued while transport is in flight is drained before the dispatcher becomes idle. Add direct blocking-transport regressions for both launch-recovery overlap and a second newly inserted event during the first blocked send. Preserve all accepted round-1 behavior. This is the second and final allowed remediation attempt for this workstream under the owner stop rule.
- Required fix round 2 result: The dispatcher now runs launch recovery and ordinary dispatch through one actor-owned work cycle. A launch request takes priority at the next safe boundary; a dispatch request arriving during recovery is drained only after recovery finishes, while a request arriving during an in-flight send sets a wake flag that forces another pending-event scan before the worker becomes idle. The deterministic recovery barrier proves a pre-existing interrupted attempt becomes `unknown` while the newly requested send remains live and reaches `sent`; the blocking transport proves a distinct event committed during the first send is also delivered exactly once without a later trigger. This final remediation implementation passed both direct regressions on its first product attempt.
- Required fix round 2 verification: Compile RED for the injected barrier is `/tmp/rr09-fix2-concurrency-red-compile.log`; behavioral RED is `/tmp/rr09-fix2-concurrency-red.log`. Direct GREEN is `/tmp/rr09-fix2-concurrency-green.log` (2/2), and preserved Notification, App Route, Review/Graph, and Agent Bridge suites passed 38/38 with zero failures/skips at `/tmp/rr09-fix2-preservation-green.log`. The isolated configured Debug build succeeded at `/tmp/rr09-fix2-build.dZh9ve`; strict deep codesign verification passed, and `/tmp/rr09-fix2-entitlements.plist` contains `com.apple.security.network.client = true`. No third architecture or remediation attempt was used.
- Required fix round 1 accepted behavior: One production `AppNotificationCoordinator` owns launch recovery, pending dispatch, and activity refresh. Ordinary and concurrent dispatch never recover a live attempt; only launch preparation converts a pre-existing `attempt_started` row to `unknown`. The bridge returns the committed command result before scheduling notification delivery, and the app model refreshes persisted notification history, sidebar count, and menu data through its observable activity cache. Ticketless events project by their persisted project ID. Every project-scoped route awaits first-dashboard-open persistence before navigation completes. Goal ownership is rejected across projects, and occurrence identity, fingerprints, deactivation, and the version-7 backfill are project-scoped. The sandbox now includes outbound-network client access.
- Fix-round TDD and verification: RED evidence is `/tmp/rr09-fix1-storage-red.log`, `/tmp/rr09-fix1-concurrency-red.log`, `/tmp/rr09-fix1-launch-boundary-red.log`, and `/tmp/rr09-fix1-app-boundary-red.log`. Focused GREEN evidence is `/tmp/rr09-fix1-storage-green.log` (16 notification tests), `/tmp/rr09-fix1-app-boundary-green5.log` (bridge reply and reactive model tests), and `/tmp/rr09-fix1-affected-green.log` (53 affected tests, zero failures/skips). The isolated configured build passed at `/tmp/rr09-fix1-build.0E4mtc`; strict deep code-sign verification passed, and `/tmp/rr09-fix1-entitlements.plist` contains `com.apple.security.network.client = true`.
- Fix-round attempts: Dispatcher/storage behavior passed on the first product implementation attempt. The app-coordinator change required one compile correction for an invalid optional binding and then passed its behavioral tests; later test-source concurrency and selected-project fixture corrections were test corrections, not product remediation attempts. No finding reached the two-attempt stop threshold.
- Final reviews: Code re-review ACCEPT, Required 0, Optional 0; both retained concurrency findings are closed with no missed-wakeup, duplicate-send, recursion, livelock, or launch-idempotency defect identified. QA ACCEPT, Required 0, Optional 0; fresh direct and preservation verification passed and the signed app retained outbound-network entitlement. Architect ACCEPT, Required 0, Optional 0, no ADR/deviation; final ownership, transaction, migration, coordination, bridge, and projection contracts conform to ADR-001. Security/privacy ACCEPT, Required 0, Optional 0; scoped credential, transport, sanitization, isolation, concurrency, signing, and helper-boundary checks passed without real credentials or network delivery.
- Controller verification: A fresh isolated build-and-test run at `/tmp/rr09-controller-final` passed the selected Notification, Agent Bridge Transport, App Route, Store, Agent Bridge, Project Activity, and Review/Graph suites with `** TEST SUCCEEDED **`. Strict deep codesign reported the test-host app valid on disk and satisfying its designated requirement; its effective entitlements contain `com.apple.security.network.client = true`. `git diff --check` passed and the worktree remained clean.
- Decisions/risks: Notification dispatch remains app-owned; the bridge helper/tool receive neither Keychain credentials nor SQLite access. No live Pushover credential or network send is used in acceptance testing; transport behavior is verified with deterministic fakes and the production client's request/redirect boundary. No owner database was intentionally inspected or repaired. Initial pre-fix hosted app tests could instantiate the prior default `AppModel` store at Application Support before the test body; mandatory store injection now removes that path, and all subsequent verification used temporary databases. No recovery flow, live Codex attachment, or RR-10 scope is changed.
- Next eligible task: RR-10 — final failure-state integration, recovery boundary, complete seven-surface UI flow, and signed MVP delivery.

### RR-10 release gate

- TPM: GO; RR-09 is accepted with every Required durability, visibility, isolation, nonblocking, entitlement, and concurrency finding closed within the owner stop rule.
- Delivery Manager: GO; RR-09 feature and remediation commits, controller verification, signed entitlement evidence, and four independent final acceptances are durable. RR-10 is dependency-safe and released to one Implementer with no concurrent writer.

### RR-10 legacy-schema stop-rule recovery

- Status: Accepted for RR-10 integration.
- Commits: `da748b8` (`fix: reject incomplete legacy schemas`), `2f1ba85` (`fix: validate critical schema metadata`), and `d53e36f` (`fix: require canonical cycle triggers`).
- Stop-rule handoff: The original repair work stopped after repeated compile failure. Its first independent review then rejected presence-only schema recognition because malformed version-3 and version-7 databases could be repaired and stamped current. A later oversized validator attempt was stopped and removed. This bounded recovery replaced it with one compact versioned manifest covering every authoritative table and ordered column plus the critical dependency-cycle triggers and migration indexes.
- Scope and safety: Existing databases are snapshotted before any migration or recognized repair. Repair remains limited to the known version-3 missing `thread_attribution` signature and the observed version-7 missing structured audit scope/normalized active-phase signature. Recognized source shapes must otherwise be complete; migrated and already-current databases must match the full version-7 manifest, with only the known harmless legacy `projects.active_phase_id` extra allowed, and must pass `foreign_key_check`. Repairs remain additive and exclusive, active-phase backfill joins project and phase identity, and unknown shapes remain typed unavailable with rollback, original database, and pre-migration snapshot intact. No owner database was opened, inspected, reset, or modified.
- Verification: `/tmp/rr10-exact-schema-recovery-tests.log` passed 22/22 selected cases with zero failures/skips: all four `EndToEndAcceptanceTests` and all 18 `StoreAcceptanceTests`. The two malformed source-shape regressions prove missing core tables fail closed without mutating either original or snapshot; the two recognized repair cases still relaunch available. The version-4 migration test now uses a complete version-4 fixture rather than a partial schema.
- Required fix round 1: Independent review found that column and object-name validation did not prove trigger semantics, index metadata, or declared project-boundary foreign keys. RED `/tmp/rr10-metadata-semantics-red.log` failed all three counterfeit fixtures. The first implementation attempt added only normalized required fragments for the four recursive cycle triggers, exact table/uniqueness/ordered-column/direction metadata for the four critical indexes, and a compact per-table manifest of required foreign-key signatures and delete actions. Direct GREEN `/tmp/rr10-metadata-semantics-green-attempt1.log` passed 3/3.
- Required fix round 1 verification: `/tmp/rr10-metadata-semantics-final-tests.log` passed 25/25 selected cases with zero failures/skips: all seven `EndToEndAcceptanceTests` and all 18 `StoreAcceptanceTests`. Counterfeit/no-op trigger, wrong-column index, and missing composite active-phase foreign-key fixtures each open typed unavailable while the original and pre-migration snapshot retain the malformed schema and seeded delivery data.
- Required fix round 2/final attempt: Independent re-review found that required SQL fragments could be spoofed inside comments while `WHEN 0` disabled the trigger. RED `/tmp/rr10-canonical-trigger-red.log` proved the deceptive trigger was accepted. The four canonical trigger definitions are now the single source used both by version-1 creation and whitespace/case-normalized full stored-SQL equality, so comments or any semantic variation fail closed. The first implementation attempt passed without a formatting correction; direct GREEN is `/tmp/rr10-canonical-trigger-green-attempt1.log`.
- Required fix round 2 verification: `/tmp/rr10-canonical-trigger-final-tests.log` passed 26/26 selected cases with zero failures/skips: all eight `EndToEndAcceptanceTests` and all 18 `StoreAcceptanceTests`. The deceptive disabled version-3 trigger opens typed unavailable while the original and pre-migration snapshot retain `WHEN 0`, schema version 3, missing audit attribution, and seeded delivery data.
- Scope evidence: the final canonical-trigger diff is `+132/-89`, including the 42-line regression; `StoreMigrations.swift` changes by a net one line to 744 because the canonical definitions replace the four duplicated migration definitions. No parser, behavior probe, broader validator, formatting correction, Optional active-phase scope change, UI work, or owner-database access was used.
- Final independent reviews: Code Reviewer ACCEPT — Required 0, Optional 0, Out of scope 0 (`/tmp/rr10-trigger-final-code-review.log`). QA ACCEPT — Required 0, Optional 0, Out of scope 0, with a fresh 26/26 EndToEnd and Store run. Architect GO — Required 0, Optional 0, no ADR/deviation, and a safe normal signed owner launch. Security/privacy GO — Required 0, Optional 0, and a safe normal signed owner launch. Canonical triggers, exact index and foreign-key metadata, the full-schema manifest, snapshots, and typed-unavailable behavior are accepted.
- Next eligible work: RR-10 final integration, signed package verification, and seven-surface acceptance evidence.

### RR-10 — Final integration and signed MVP evidence

- Status: Accepted and release-ready. Required blockers 0.
- Commits: `4a2166d`, `f49b5e8`, `da748b8`, `131a6cb`, `2f1ba85`, `5b573e7`, `d53e36f`, `9e31809`, `cf1d230`, and `c12afb1` delivered recovery, failure-state integration, isolated capture, and evidence. Final blocker corrections are `88d90f9` (truthful project onboarding with no normal-launch sample seed), `1e3416a` (recognized artifact import and same-session agent-defined first phase), `2d0749e` (protected onboarding review markers), and `271fcd4` (globally reserved marker IDs with collision rollback). Capture arguments are Debug-only and use isolated app data; normal Debug and Release launches never seed sample delivery/runtime/notification state.
- Owner launch and recovery boundary: A fresh configured signed Debug build completed `clean build`, passed strict deep code-sign verification, and was launched normally exactly once as `com.rekonlabs.ReleaseRadar`. Accessibility inspection showed the Projects dashboard with the persisted Rekon Pursuit project rather than a typed unavailable state. The app was then terminated cleanly before a minimal read-only SQLite metadata check. The current database passed integrity checking at schema version 7 with all four required structured audit columns, `project_active_phases`, all 11 required notification columns, one project, and 31 tickets. Its recoverable `.pre-migration` snapshot also passed integrity checking at version 7 with one project and 31 tickets while retaining the legacy absence of structured audit scope and active-phase metadata. Both files had the same `2026-08-24T07:44:15-0400` modification time, so the recognized repair had already been applied before the authorized normal launch; the launch confirmed the repaired store remained available and did not perform a second repair. No owner database was reset, deleted, or manually mutated.
- Required service scenarios: One fixture-backed run passed 15/15 selected tests with zero failures/skips: all eight `EndToEndAcceptanceTests` plus seven cases spanning typed agent transition/replay, onboarding reconciliation, scoped cached observation, import persistence and missing-evidence relaunch, and exactly-once notification replay/relaunch. Result bundle: `DerivedData/Logs/Test/Test-ReleaseRadar-2026.08.24_08-32-56--0400.xcresult`.
- Seeded UI acceptance: Computer Use drove one isolated seeded capture bundle across Projects, Overview, Phase Board and ticket detail, Needs Review, Dependencies, Activity, Notifications, and tab-style Settings at full and compact widths. Accessibility evidence confirmed the expanded and collapsed rails, both badges, Full outcomes and Compact IDs board presentations, all five lanes, selected ticket relationships, review actions, persisted activity with truthful Codex-unavailable context, persisted Pushover history, and Settings tabs. The seven primary surface images are `docs/delivery/evidence/rr10-projects-overview-board-detail.png`, `rr10-needs-review.png`, `rr10-dependencies.png`, `rr10-activity.png`, `rr10-notifications.png`, `rr10-onboarding-failure.png`, and `rr10-settings.png`; `rr10-board-compact.png` is the additional 921×697 responsive proof. The primary board/detail and other main-surface captures are 1499×768; Settings uses its natural 660×548 window.
- Onboarding/failure evidence: A distinct empty-store bundle used `--rr10-capture --rr10-empty-store` against isolated app data. Accessibility exposed `failure-no-structure`, “No delivery structure yet,” and the real “Choose Project Folder…” recovery action. No synthetic UI data, owner path, private Codex data, live credential, or real Pushover send was used.
- Interim implementer verification: `/tmp/rr10-final-all-tests.log` recorded 112 passing tests before the final blocker regressions were added. The authoritative final controller result superseding it is 122/122 passed, zero failures/skips, and `** TEST SUCCEEDED **` at `/private/tmp/release-radar-final-271fcd4-tests/Logs/Test/Test-ReleaseRadar-2026.08.24_10-02-23--0400.xcresult`.
- Signing and helper boundary: Strict verification reports the app, `ReleaseRadarAgentTools`, and `ReleaseRadarBridgeAgent` valid on disk and satisfying their designated requirements (`/tmp/rr10-final-codesign-{app,helper,bridge}.log`). All three use the configured Apple Development identity, team `2UA854NLX4`, and hardened runtime. The app retains sandbox, read-only user-selected file, app-group, and outbound-network client entitlements; the helper retains only its application identifier; the bridge retains sandbox plus the app group. No normal owner relaunch was performed for this final non-launching build.
- Attempts and cleanup: The capture-isolation regression followed RED/GREEN and passed again after the Debug-only argument guard. One visual recapture reused compact window restoration and was discarded; the changed-condition recapture used a fresh bundle identifier and produced the verified 1499×768 Full outcomes image. A shell cleanup request was rejected before execution and replaced with recoverable exact-path cleanup. All capture derived data was inspected for unintended source/evidence content and moved to Trash; no generated build directory is staged or retained in the repository.
- Final onboarding acceptance: Normal launches show truthful empty onboarding; existing projects retain Add Project; recognized Rekon artifacts are previewed and imported only after explicit consent; uncertain records remain in Needs Review. Pending projects remain resumable and excluded from ordinary dashboards until a first phase exists and owner finish completes. A bridge already running before folder authorization can accept the agent-defined first phase without restart. Reserved onboarding markers cannot be created, overwritten, resolved, dismissed, or preclaimed cross-project by agent commands, and collision failures roll back without repair. Completion returns to Projects without auto-opening the dashboard.
- Final independent gates: Code Reviewer ACCEPT — Required 0, Optional 0, Out of scope 0, with 45/45 focused tests. QA ACCEPT — release blockers 0, with 17/17 focused tests. Architect GO — Required 0, Optional 0, Out of scope 0, no ADR. Security/privacy GO — Required 0, Optional 0, Out of scope 0. TPM GO — Required blockers 0. Delivery Manager PRODUCT GO — Required product blockers 0.
- Visual evidence: All seven primary surface screenshots plus `rr10-board-compact.png` were independently inspected and accepted. They cover Projects/Overview/Phase Board/detail, Needs Review, Dependencies, Activity/goal state, Notifications, onboarding/failure states, Settings, and compact responsive behavior.
- Release artifact: `build/release-271fcd4/ReleaseRadar-271fcd4.zip`, SHA-256 `09aad61cec2b7aacb95232689a881a6b2c46844e1acef1848d42ec2c98656813`. The unpacked `ReleaseRadar.app` passes strict deep code-sign verification, is version 0.1.0 (1), arm64, targets macOS 14+, uses Apple Development team `2UA854NLX4`, and has hardened runtime. It is a local owner-install build, not a notarized general-distribution artifact.
- Accepted limitation and next phase: Supported live Codex attachment remains unavailable, so the UI truthfully presents unavailable or authorized cached-stale context and never promotes it to formal delivery state. General notarization/distribution, the nonblocking Xcode warnings, and any supported authenticated Codex attachment are next-phase work, not MVP release blockers.

### Next phase — V1 brand production

- Status: Partially complete. The deterministic production AppIcon is accepted under RR-R6; wordmark/typeface and light/dark lockups remain backlog candidates.
- References: `docs/brand/release-radar-icon-v1.png`, `docs/brand/release-radar-lockup-v1.png`, and `docs/brand/README.md`.
- Remaining scope: deterministically recreate the technical/architectural wordmark, settle the production typeface/outlines, and export light/dark lockups. Do not repeat the accepted AppIcon asset-catalog work.
- Guardrail: generated raster drafts remain references only and must not be shipped directly or visually redesigned without owner review.

## 2026-08-25 — Post-MVP reported-defect remediation intake

- Status: Preimplementation gate approved; no remediation implementation has begun and no reported defect is recorded as fixed.
- Live runtime: Computer Use is available and directly inspected the running Debug build at `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/DerivedData/Build/Products/Debug/ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar`.
- Verified findings: the built app has no production icon; Add Project has no visible dismiss action although Escape closes it; structure-less active repositories cannot complete onboarding through the current request-marker-only first-phase path; alert rules are static rather than interactive; the wide board says “Full outcomes” while the narrow board says “Compact IDs,” creating unclear density UX; the inspected ticket has no linked goal and ticket outcomes do not provide meaningful TL;DR content; Dependencies materially diverges from `docs/design/mockups/dependencies.png`; and Needs Review decisions fail with “Folder not authorized.”
- Plan and mapping: `docs/superpowers/plans/2026-08-25-release-radar-remediation.md` controls the bounded work. RR-R1 covers visible Cancel/reset and open-existing without duplicates; RR-R2 covers fail-closed folder reauthorization and review recovery; RR-R3 covers exact ticket-goal identity and authoritative outcome/TL;DR copy; RR-R4 covers persisted alert-rule toggles and event suppression; RR-R5 covers Dependencies selected-path presentation and explicit board density; RR-R6 covers the deterministic production AppIcon.
- Independent plan gates: Planning GO; Architecture GO; QA/test GO; TPM GO; Delivery Manager GO. The plan is scoped, test-first, serialized, and uses the existing repository tools and ledger.
- Product-decision gate: completing onboarding for a repository with no usable delivery structure remains independently gated. The app must not invent a phase, parse Markdown as delivery authority, create a repository-backed manifest, or add owner-facing manual phase editing. Resolution requires an explicit owner choice plus matching design/ADR approval for either a supported outbound agent-request integration or a narrowly defined owner-created first phase. This gate does not block RR-R1 through RR-R6.
- Baseline verification: `xcodebuild test -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-baseline-derived` passed. Existing nonblocking warnings remain for optional `.none`, test actor isolation, and signed-binary stripping.
- Release decision: RR-R1 is dependency-safe and released to one fresh Implementer with no concurrent writer. RR-R2 through RR-R6 remain closed until their recorded dependency and independent-review gates are satisfied.

### RR-R1 — Cancellable Add Project and existing-project routing

- Status: Accepted in the current working diff; this supersedes the intake's preimplementation status for RR-R1. No commit has been created.
- Implemented scope: Add Project now has a visible, accessible Cancel action that resets transient onboarding state; the always-inline empty-state onboarding does not render an inert Cancel. Selecting the canonical root of a completed project exposes Open existing project and routes through the established project-opening path without preparing or duplicating durable project state.
- Controller verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -destination 'platform=macOS' -derivedDataPath /tmp/release-radar-rr-r1-controller -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests` passed 11/11 with zero failures/skips. Only the pre-existing optional-`.none`, test actor-isolation, and signed-binary stripping warnings remain.
- Code review: Initial Required finding — the inline onboarding surface rendered a Cancel with no callback. The optional `onCancel` correction removed that inert control while retaining the sheet action; independent re-review ACCEPT, Required 0.
- QA: ACCEPT. Computer Use verified the alternate signed build at `/tmp/release-radar-rr-r1-qa-app/Build/Products/Debug/ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar.RR1QA`. The inline surface had no inert Cancel; sheet `onboarding-cancel` dismissed with Escape and click; Cancel after populating the form reopened clean; `onboarding-open-existing` activated with Return and click and routed to Overview. The seeded isolated QA store remained unchanged before and after repeated open-existing actions at 2 projects, 1 root, 1 bookmark, and 2 onboarding audits, proving no duplicate; owner application data was untouched.
- Architecture: APPROVED, Required 0; the completed-project identity remains a read-only projection over canonical root ownership, open onboarding markers, and persisted phase existence. No ADR change is required.
- Security/privacy: PASS, Required 0. Cancel performs no durable write; a healthy existing bookmark remains unchanged; stale authorization continues to fail closed. Open-existing uses the established navigation path, including its already-defined first-dashboard-open audit when applicable; no new authorization or audit authority was introduced.
- Product-decision gate: Structure-less onboarding remains unresolved and independent. RR-R1 does not invent a phase, parse Markdown as delivery authority, create a repository-backed manifest, or add manual phase editing.
- Delivery Manager: GO. RR-R1 is accepted with all Required findings closed and no owner-data mutation. TPM has returned GO and released RR-R2 as the next serialized writer.

### RR-R2 — Folder-authorization recovery

- Status: In progress; not accepted. The initial implementation's focused verification passed 36/36 tests, but independent review REJECTED it with two Required findings: cross-project recovery authorization leakage and post-commit refresh failure being misreported as a failed decision, which could prompt a duplicate retry. A fresh fix Implementer is assigned to the bounded remediation.
- Runtime-isolation incident: The original Implementer launched the normal `com.rekonlabs.ReleaseRadar` bundle despite intending to isolate it with `CFFIXED_USER_HOME`, and the run touched the owner database. The Implementer manually reversed the identified project root, bookmark, two audits, command record, and review status, then deleted the backup. No bookmark bytes are recorded here.
- Controller follow-up: A later read-only audit found the owner database structurally available with integrity OK, schema version 7, 1 project, 31 tickets, 0 project roots, 0 project bookmarks, 6 open review items, and no audits or notification events after 03:20. The database modification time changed; byte-for-byte restoration and proof that no unrelated state changed are unavailable.
- Evidence disposition: All runtime evidence from the original Implementer is invalid because isolation failed. Independent QA subsequently used the alternate bundle `com.rekonlabs.ReleaseRadar.RR2QA`; owner database metadata remained unchanged during that isolated verification.
- Delivery gate: NO-GO until a fresh Implementer closes both Required review findings and the corrected implementation receives independent code, QA, architecture, security/privacy, TPM, and Delivery Manager acceptance. RR-R3 remains closed.

#### RR-R2 fix round 1 and final gate

- Status: Accepted in the current working diff; no commit has been created. This final gate supersedes the prior RR-R2 NO-GO while preserving the runtime-isolation incident, invalidated evidence, and owner-database uncertainty above.
- Required findings closed: The fresh fix Implementer restricted the review dispatcher registry to the target project's currently resolved canonical root, closing cross-project recovery leakage. A committed review decision is now projected locally before refresh; refresh failure presents “Saved; refresh needed” with an explicit do-not-retry instruction, closing the false-failure and duplicate-retry risk. The fixer launched no application runtime.
- Controller verification: The fresh focused Onboarding, App Route, and Review/Graph acceptance run at `/tmp/release-radar-rr-r2-controller` passed 38/38 with zero failures/skips. `git diff --check` passed.
- Code review: ACCEPT, Required 0; both fix-round findings are closed in the current source.
- QA: ACCEPT. The prior valid live flow used isolated bundle `com.rekonlabs.ReleaseRadar.RR2QA`; a fresh current-source rerun passed the same 38/38 focused cases. Owner-container metadata remained untouched during independent QA.
- Architecture: APPROVED, Required 0. The project-local authorization capability, explicit same-root reauthorization versus first-root association, scoped audit behavior, and post-commit refresh semantics conform to the amended `docs/architecture/ADR-001-release-radar-boundaries.md`.
- Security/privacy: PASS, Required 0. Bookmark material remains local and undisclosed; authorization fails closed; only the target project's verified root reaches the decision dispatcher; unsuccessful recovery performs no review decision; balanced scope access and distinct bounded recovery audits are retained.
- Delivery Manager: GO. RR-R2 is accepted with all implementation Required findings closed. The earlier owner-database incident remains a documented residual uncertainty rather than valid product evidence. RR-R3 is the next serialized writer, pending TPM release confirmation.

### RR-R3 — Exact ticket-goal identity and meaningful ticket outcomes

- Status: Accepted in the current working diff; no commit has been created.
- Implemented scope: Additive schema version 8 persists one exact `(project, ticket, thread, goal)` relationship with composite project-local integrity and one-to-one uniqueness for both ticket and goal. The ambiguity-safe v7 backfill links only an unambiguous ticket/thread/goal identity and otherwise leaves legacy records unlinked and unchanged. The typed `linkGoal` command, ticket detail, ticket-attributed Activity, and blocked-goal notification projection now consume only that exact identity. Fresh dashboard seed tickets use descriptive outcome/TL;DR copy; persisted owner outcomes are not rewritten.
- Controller verification: A fresh isolated command covering Store, Agent Bridge, Dashboard Projection, Notification, and End-to-End acceptance passed 71/71 with zero failures/skips at `/tmp/release-radar-rr-r3-controller`. The configured Debug build succeeded. Only the pre-existing optional-`.none`, test actor-isolation, and signed-binary stripping warnings remain.
- Required fix round 1: Initial independent review found that reusing an existing goal-link ID could move the link to a different valid ticket while auditing only the new ticket. A fresh fixer made link identity stable: an existing ID must retain its original project and ticket, while a same-ticket goal update remains supported. The compact regression observed RED at exit 65, GREEN at exit 0, and proves rejection preserves the original link, audit count, and durable replay count. Fresh focused and End-to-End preservation verification passed 8/8; build and `git diff --check` passed. The fix launched no runtime and accessed no owner data.
- Code review: ACCEPT, Required 0. The stable-link identity finding is closed; no remaining required regression or scope issue was found.
- QA: ACCEPT, Required 0. Current-source verification passed 71/71. Computer Use independently inspected the alternate signed bundle `com.rekonlabs.ReleaseRadar.RR3QA`: descriptive ticket outcomes were visible; the verified ticket link, Activity identity, and blocked notification used the exact approved goal; and an unlinked ticket remained truthfully labeled `No linked goal`. The isolated database was schema version 8 with a clean foreign-key check. The owner bundle and owner data were not used.
- Architecture: APPROVED, Required 0. The implementation conforms to the exact one-to-one identity and ambiguity-safe migration contract recorded in `docs/architecture/ADR-001-release-radar-boundaries.md`; no further ADR change is required.
- Security/privacy: PASS, Required 0. Cross-project, wrong-thread, cross-ticket goal reuse, and cross-ticket ID reassignment fail transactionally without link, audit, or replay writes. Existing owner-authored outcomes remain unchanged.
- TPM: GO, Required blockers 0. RR-R3 is dependency-complete and RR-R4 may proceed under the corrected brief.
- Delivery Manager: GO. RR-R3 is accepted with all Required findings closed and proportionate isolated evidence. No normal application runtime or owner database was accessed during implementation, controller verification, or the stable-link fix.

### RR-R4 release gate — Persisted alert-rule controls

- Planning: GO. The tracked historical detailed brief is `docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-4-brief.md`; the durable accepted scope is recorded in this gate and the implementation/final-gate section below.
- Architecture: GO, Required 0. Additive schema version 9 follows RR-R3's accepted version 8; the app-owned settings/store boundary and existing notification ownership remain intact.
- QA/test: GO, Required 0. The plan proportionally covers exact defaults and reopen, all six event mappings, suppression before notification writes, underlying delivery/audit preservation, reciprocal blocked/paused lifecycles, authoritative UI failure/relaunch/accessibility behavior, and isolated runtime verification without new test infrastructure.
- Security/privacy: GO, Required 0. Rules remain non-secret local preferences; only the owner app can update them; actual changes create one bounded unscoped owner audit; disabled rules create no notification occurrence, event, dispatch attempt, or notification Activity; the bridge and credentials remain unchanged.
- TPM: GO, Required blockers 0. RR-R4 is dependency-safe after RR-R3 acceptance and the corrected independent plan reviews.
- Delivery Manager: GO. RR-R4 is released to one fresh Implementer with no concurrent writer. The Implementer must not launch the normal owner bundle or access owner data; live acceptance must use an alternate isolated bundle. RR-R5 and RR-R6 remain closed until their recorded dependencies and independent gates are satisfied.

#### RR-R4 implementation and final gate

- Status: Accepted in the current working diff; no commit has been created.
- Implemented scope: Additive schema version 9 owns an exact constrained four-row `alert_rules` set. Migration defaults are blocked linked goals on, agent completion/review on, Needs Review on, and paused goals off. The owner app loads and updates the authoritative snapshot directly; actual changes create the bounded unscoped owner audit, while failed and no-op updates create none. All six meaningful event kinds map exhaustively to the four rules, and suppression occurs before notification occurrence, event, attempt, and notification-Activity writes without rolling back the underlying delivery/import/observation mutation or its existing audit. Blocked and paused occurrences remain reciprocal even while their alert rule is disabled.
- TDD and controller verification: The initial focused RED failed on the absent rule authority and UI/model APIs. Initial GREEN passed 57/57 Store, Notification, and App Route acceptance cases, covering v8-to-v9 migration/default/reopen behavior, exact schema and loader rejection, audit behavior, six-event suppression, reciprocal occurrence state, and authoritative model failure/persistence behavior. After the Required retroactive-alert fix below, fresh current-source affected verification passed 85/85 with zero failures/skips; the configured alternate build and `git diff --check` also passed. Existing optional-`.none`, test actor-isolation, and signed-binary stripping warnings remain nonblocking and out of scope.
- Required fix round 1: Initial independent review found that suppression only inside enqueue left no occurrence evidence for a disabled entry, so re-enabling could make a stable same-state observation or stable-ID upsert create a retroactive alert. A fresh fixer gated enqueue on a genuine producer creation or state entry for linked goals, ticket transitions, review requests, completion records, and imported review items while keeping delivery mutations, audits, and exit deactivation unconditional. The focused regressions observed RED, then GREEN 3/3; producer-boundary preservation passed 71/71. Stable state after re-enable now remains silent until a new real entry.
- QA: ACCEPT, Required 0. Computer Use exercised the alternate signed app at `/tmp/release-radar-rr-r4-qa-build.sL7zrK/Build/Products/Debug/ReleaseRadar.app`, bundle identifier `com.rekonlabs.ReleaseRadar.RR4QA`. All four Toggles exposed authoritative accessible values; changes persisted across relaunch; a delayed update disabled every control while in flight; and an injected update failure retained the prior value, showed recoverable failure, and succeeded only on explicit retry. The final Settings capture is `/tmp/release-radar-rr-r4-qa-settings-final.png`.
- Independent reviews: Code Reviewer ACCEPT, Required 0; QA ACCEPT, Required 0; Architect APPROVED, Required 0 and no ADR change required; Security/privacy PASS, Required 0; TPM GO with Required blockers 0. The retroactive-alert Required finding is closed without expanding the agent bridge, credentials, provider, or settings authority.
- Isolation and residual risk: Implementation, controller verification, fix work, and live QA did not launch the normal owner bundle or access owner application data. The prior RR-R2 runtime-isolation incident and owner-database uncertainty remain recorded above and are not altered by this acceptance.
- Delivery Manager: GO. RR-R4 is accepted with all Required findings closed and proportionate persistence, audit, failure, accessibility, relaunch, and event-suppression evidence.

### RR-R5 planning/review gate — Dependencies and board density UX

- Status: Preimplementation gate accepted; implementation is released to one fresh serialized Implementer. RR-R6 remains closed.
- Historical brief and durable mockup inspection: `docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-5-brief.md` is tracked point-in-time evidence. Planning and Delivery Management independently inspected `docs/design/mockups/dependencies.png` and `docs/design/mockups/phase_board.png`, both 1586 x 992. The durable accepted Dependencies target is the mockup's selected-path-only four-column hierarchy (`Foundations`, `Accepted work`, `Selected ticket`, `Unlocks next`), phase-ticket count, five-lane plus dependency/blocking-path legend, directional connectors with non-color-only blocked emphasis, selected-node treatment, and right-side inspector with selected-ticket, direct/indirect requirement, and unlock detail. The accepted Phase Board target is an explicit `Card density` control with exact `Full outcomes` and `Compact density` choices while retaining the five canonical lanes and truthful card constraint metadata.
- Responsive and accessibility gate: Wide acceptance is 1586 x 992 points with a 220-point expanded sidebar, right-side Dependencies inspector, and both board-density choices exercised. Compact acceptance is 900 x 650 points with the same sidebar, the full selected path retained, the inspector stacked below the graph, all five board lanes recoverable without overlap, and requested full cards visibly compacted when lane width is at or below 180 points. Minimum recovery is 760 x 520 points; keyboard and scroll access must expose every graph column, inspector section, lane, and card without clipped actionable controls. Required captures cover both surfaces at wide and compact sizes, plus minimum size only when behavior differs. Accessible nodes must name ID, lane, blocker count, selection, and column role; connector relationships must have inspector text equivalents; compact cards must retain full outcomes in accessibility labels; the density value must disclose a temporary width override.
- Deterministic and failure checklist: Layout includes exactly the selected ticket, its indirect and direct prerequisites, and direct unlocks; lexical column membership, visible frames, and in-path connectors are stable; unrelated and cross-phase branches are absent. A ticket with no relations shows only itself with explicit empty relationship sections. Density is view-local, defaults to full, restores the owner's local full choice after widening, and may truthfully reset when the board is recreated. Narrow content scrolls/stacks rather than clipping. No screenshot-test infrastructure, preference persistence, new ticket field, graph mutation, or delivery transition is authorized.
- Independent preimplementation reviews: Planning GO; Architecture GO, Required 0; QA/test GO, Required 0; TPM GO, Required blockers 0; Delivery Manager GO. The brief contains the required focused selected-path and density regressions, RED/GREEN sequence, exact responsive matrix, live visual/accessibility checklist, isolated alternate-bundle constraint, non-happy-path behavior, and completion evidence without disproportionate test machinery.
- Security/privacy disposition: A separate Security/Privacy preimplementation review is not required because RR-R5 is presentation-only over existing in-memory read-only projections and view-local state. It creates no SQLite row, bookmark, bridge request, audit, notification, credential access, permission change, or owner-data fixture. Any implementation that adds persistence, bridge/permission access, owner-data access, or another security boundary exceeds the accepted brief and returns the task to NO-GO pending a new gate and independent Security/Privacy review.
- Delivery Manager: GO. RR-R4 is accepted, no concurrent writer is authorized, and RR-R5 is released to one fresh Implementer owning only the bounded Dependencies/Phase Board files and focused existing test suites named in the brief. The Implementer must not launch `com.rekonlabs.ReleaseRadar` or access owner data; any live check must use an alternate isolated bundle/container. Independent Code Review, QA visual/responsive/accessibility verification, Architecture review, TPM, and Delivery Management remain required before acceptance. RR-R6 remains closed.

#### RR-R5 implementation and final gate

- Status: Accepted in the current working diff; no commit has been created. Dependencies now presents only the selected ticket, its direct and indirect requirements, and its direct unlocks in the approved deterministic four-column hierarchy with relationship connectors and a responsive inspector. Phase Board now exposes the exact view-local `Full outcomes` and `Compact density` choices, applies a truthful width-forced compact presentation at lane widths of 180 points or less, and restores the requested full presentation after widening. No projection, schema, persistence, audit, notification, bridge, permission, or owner-data behavior changed.
- TDD and controller evidence: The initial RED failed because the selected-path column contract, connector blocking metadata, and `BoardDensity` did not exist. Initial GREEN passed the focused Review/Graph and Dashboard Projection suites 20/20. After the Required fix below, fresh current-source verification again passed 20/20 with zero failures/skips at `/tmp/release-radar-rr-r5-fix1-final-tests.log`; the alternate configured build, strict deep codesign verification, and `git diff --check` passed. Existing optional-`.none`, test actor-isolation, App Intents metadata, and signed-binary stripping warnings remain nonblocking and out of scope.
- Required fix round 1: Initial independent review reported two Required Phase Board findings: the stacked layout clipped selected-ticket detail at 760 x 520, and the macOS Picker exposed the requested `Full outcomes` value without disclosing that compact cards were actually displayed at narrow width. A fresh fixer placed the five-lane workspace and selected-ticket detail in vertical recovery scrolling while preserving horizontal lane recovery, and exposed the effective compact override plus automatic wide-width restoration through the density control's accessibility value and help. The compact regression observed RED at `/tmp/release-radar-rr-r5-fix1-red.log`; the corrected focused suite produced the final 20/20 GREEN above. Both findings are closed without expanding scope.
- Live QA: ACCEPT, Required 0. Computer Use exercised the isolated alternate bundle `com.rekonlabs.ReleaseRadar.RR5FixQA`. Exact wide evidence is `/tmp/release-radar-rr-r5-wide-dependencies-1586x992.jpeg`, `/tmp/release-radar-rr-r5-wide-board-full-1586x992.jpeg`, and `/tmp/release-radar-rr-r5-wide-board-compact-1586x992.jpeg`. Compact evidence is `/tmp/release-radar-rr-r5-dependencies-900x650.jpeg` and `/tmp/release-radar-rr-r5-fix-board-900x650.jpeg`. Minimum 760 x 520 board recovery, including the separately scrolled selected-ticket detail, is shown by `/tmp/release-radar-rr-r5-fix-board-min-top.jpeg` and `/tmp/release-radar-rr-r5-fix-board-min-detail.jpeg`. QA verified the selected-path hierarchy and inspector, both density choices, truthful forced-compact accessibility value, restoration after widening, and scroll access to the five lanes and selected-ticket detail.
- Independent reviews: Code Reviewer ACCEPT, Required 0; Architecture APPROVED, Required 0 and no ADR/deviation; QA ACCEPT, Required 0; TPM GO, Required blockers 0. The two initial Required findings are closed in current source.
- Security/privacy and isolation: The accepted implementation remains presentation-only over existing in-memory read-only projections and view-local density state. It creates no persistence, audit, notification, bridge request, bookmark, permission, credential, graph mutation, or owner-data fixture, so the approved no-separate-security-review disposition remains valid. Implementation and QA did not launch the normal owner bundle or access owner application data. The prior RR-R2 incident and residual owner-database uncertainty remain unchanged above.
- Delivery Manager: GO. RR-R5 is accepted with all Required findings closed and proportionate current-source, exact-size live visual, responsive, accessibility, build, and no-write evidence. RR-R6 may enter granular planning and independent plan review only; RR-R6 implementation remains closed until those gates are durably accepted.

### RR-R6 planning/review gate — Production AppIcon

- Status: Corrected preimplementation gate accepted; one fresh serialized Implementer is released. RR-R5 is accepted, no concurrent writer is authorized, and post-implementation acceptance remains closed.
- Historical brief and durable references: `docs/delivery/task-briefs/2026-08-25-release-radar-remediation/task-6-brief.md` is tracked point-in-time evidence. The accepted icon and icon mockup remain byte-identical 1254 x 1254 PNGs with SHA-256 `b94fb5b029dd262cfb9e196efdf089fb3d72aee76d433ebfd448cc26691f7ddd`; `full_logo.png` remains 1968 x 799 with SHA-256 `cb7ba41ca0aeb58e7cbd1d680b4fca10d84facaaf38550a72b0f9105ed56ba78`. A changed hash is an immediate Planning/Design stop condition.
- Exact implementation scope: hand-author one deterministic SVG in the approved V1 direction; export seven lossless PNGs that supply the exact ten macOS AppIcon rows; add only their `Contents.json` and explicit app-only asset-catalog/project wiring; add only the narrow Debug capture predicate/model guard needed for privacy-safe visual QA; and extend only the existing compact App Route launch-policy regression. The wordmark, generated reference rasters, new dependencies/scripts, generalized capture or collaborator infrastructure, persistence/audits, bridge/folder behavior, release packaging, and unrelated product code remain out of scope.
- Explicit app Resources contract: use unused file/build IDs `A10000000000000000000018` and `B10000000000000000000007`; exclude `Assets.xcassets` from implicit synchronized membership through `A90000000000000000000001`; add the explicit build file only to app Resources phase `C10000000000000000000003`; and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` only in app Debug/Release configurations `A50000000000000000000053` and `A50000000000000000000054`. The catalog/setting must not reach Core, helpers, bridge, tests, `Info.plist`, or entitlements.
- Compiled-artifact acceptance: source dimension checks do not prove delivery. A fresh configured bundle must select `AppIcon`, contain `Assets.car` and a parseable `AppIcon.icns`, and expose exactly ten filtered `assetutil` `Icon Image` tuples mapping the seven source filenames across the required scales and dimensions; the `MultiSized Image` summary is excluded. Generated raster references must be absent. Strict nested signing and the existing identifier, team, Apple Development authority, hardened runtime, sandbox, and effective entitlements must remain unchanged; this is not a Developer ID/notarization claim.
- Debug capture privacy seam: the alternate bundle identifier is container evidence, not traditional Keychain isolation. A default-false `externalServicesSuppressed` predicate may become true only for Debug plus `--rr10-capture`, must drive the existing AppDelegate capture guard, and may cause `AppModel` to skip only Pushover configuration loading and pending notification dispatch. Normal Debug/Release startup and dashboard/store/UI loading remain unchanged. The focused regression must prove the predicate matrix and untouched queued-event/attempt state. Independent QA alone may launch a never-before-used alternate bundle with `--rr10-capture --rr10-empty-store`, verify its empty notification tables, and inspect Finder, Dock, and About through Computer Use; no owner bundle, Keychain item, container, database, folder authorization, or notification delivery is permitted.
- Independent preimplementation reviews: Planning GO; Architecture GO, Required 0 and no ADR; QA/test GO, Required 0; Security/privacy GO, Required 0; TPM GO, Required blockers 0. The corrected resource wiring, exact CAR tuple contract, small-size fidelity matrix, configured non-launching build evidence, and privacy-safe live-capture seam are sufficient and proportional.
- Delivery Manager: GO. Release one fresh Implementer for only the recorded scope, with no concurrent writer. The Implementer may run source tests and configured non-launching builds but must not launch a bundle or access owner data. Any change to signing, entitlements, `Info.plist`, bundle identity/default startup, Keychain/coordinator APIs, packaging, owner data, or broader product behavior returns RR-R6 to NO-GO. Independent Code Review, QA visual/artifact/privacy verification, Architecture, Security/Privacy, TPM, and Delivery Management remain required before final remediation acceptance. The prior RR-R2 runtime-isolation incident and residual owner-database uncertainty remain unchanged above.

#### RR-R6 implementation and final remediation gate

- Status and scope: Accepted in the current uncommitted working diff; no commit, packaged release, Developer ID distribution, or notarization has been created or claimed. The app target now owns the deterministic production AppIcon and the narrowly approved Debug capture-suppression seam. `Info.plist`, entitlements, production/default startup, persistence, bridge/folder behavior, and notification/Keychain implementations remain unchanged.
- Deterministic asset evidence: `docs/delivery/archive/sdd/2026-08-25-release-radar-remediation/task-6-report.md` records the exact geometry, renderer/tool versions, source-to-catalog mapping, RED/GREEN evidence, and artifact checks. Current-source SHA-256 values are SVG `83058fa6702b530f5ccd1a8851615db046aea45607c1e254cec920013e1e15fc`; PNG 16 `96f728e31ac046ad67e41b83c76e348a204cb0e78d977e5bb03fa1ba42df9303`; PNG 32 `ca1d66664a36007c512edc6001e802fc732b7ac2358c7008d945d94ea942004a`; PNG 64 `24126e45d935f4966bca80adfa7f1cbdadbf87267ae57fe585babe5f0db37c31`; PNG 128 `2465ed35531ee4e0e43e003563d4d5f8bc7e4c1489efe51920ba3ae8d88c672a`; PNG 256 `20e24cdd1a469c41d4195c1f7e83424b54950bbb001870d8661f3eefed91208c`; PNG 512 `455892a0384c1cb5b854ae2cb1ceedf16c64a171dee6b36db9581aeaa76af7c9`; and PNG 1024 `fc2e48cf435a4b6015843a2770872da7033f0a3020a63e8311e408589bddaaa1`.
- Compiled artifact evidence: the configured app selects `AppIcon`, contains `Assets.car` and a parseable `AppIcon.icns`, and exposes exactly ten filtered CAR `Icon Image` tuples from the seven SVG-derived PNGs: `AppIcon-16.png|1|16|16`, `AppIcon-32.png|1|32|32`, `AppIcon-32.png|2|32|32`, `AppIcon-64.png|2|64|64`, `AppIcon-128.png|1|128|128`, `AppIcon-256.png|1|256|256`, `AppIcon-256.png|2|256|256`, `AppIcon-512.png|1|512|512`, `AppIcon-512.png|2|512|512`, and `AppIcon-1024.png|2|1024|1024`. The app-only PBX assertions, compiled `CFBundleIconFile`, absent reference rasters, and clean build are recorded in the task report.
- Test evidence: the focused Debug-capture launch-policy/coordinator suite passed 15/15 with no failures or skips at `/tmp/release-radar-rr-r6-final-test.2YeUco/Logs/Test/Test-ReleaseRadar-2026.08.25_02-51-34--0400.xcresult`. A final controller run over current combined source passed 146/146 with no failures or skips at `/tmp/release-radar-remediation-final/Logs/Test/Test-ReleaseRadar-2026.08.25_03-05-31--0400.xcresult`.
- Signing and privacy evidence: strict nested signing passed for configured and alternate artifacts. Effective identity remains Apple Development `PT7GS96H3L`, team `2UA854NLX4`, hardened runtime, App Sandbox, app group, read-only user-selected folder access, outbound network, and expected Debug `get-task-allow`. Debug plus `--rr10-capture` alone suppresses Pushover configuration lookup and pending dispatch; ordinary Debug and Release behavior remains unchanged. Independent Security/Privacy found no Required issue and verified app-only resource wiring, ten compiled icon renditions, unchanged source entitlements/Info.plist, no bundled reference raster, and no owner credential, database, folder, or provider access.
- Live QA: ACCEPT, Required 0. Computer Use exercised only `/tmp/release-radar-rr-r6-qa-alt/Build/Products/Debug/ReleaseRadar.app`, identifier `com.rekonlabs.ReleaseRadar.RR6QA`, with the approved capture/empty-store arguments. The fresh alternate container and empty notification state were verified. Finder and standard About visibly presented the production identity; captures are `/tmp/rr-r6-finder-list.png`, `/tmp/rr-r6-finder-icon-24.png`, `/tmp/rr-r6-finder-icon-64b.png`, and `/tmp/rr-r6-about.png`. Direct Dock targeting timed out in the UI bridge, so Dock screenshots are not claimed as acceptance evidence; QA and TPM classified that tooling limitation as nonblocking because Finder/About live evidence, the signed bundle, and the exact compiled icon matrix establish the delivered asset without a demonstrated Dock defect.
- Independent final reviews: Code Reviewer ACCEPT, Required 0; QA ACCEPT, Required 0; Architecture APPROVED, Required 0 and no ADR/deviation; Security/Privacy PASS, Required 0; TPM GO, Required blockers 0.
- Isolation and residuals: RR-R6 implementation, verification, and live QA did not launch the normal owner bundle or access owner application data. The structure-less-project onboarding path still requires the separately recorded explicit owner choice and matching design/ADR approval. The historical RR-R2 incident remains unchanged: the owner database's key counts and integrity were restored, but byte-for-byte restoration and proof that no unrelated state changed remain unavailable.
- Delivery Manager: GO. RR-R6 is accepted and the RR-R1-through-RR-R6 remediation milestone is closed in the current working diff. This closes the approved defect-remediation scope only; it is not a commit, packaged release, notarization, or authorization to bypass the two residual gates above.

### RR-R7 planning/release gate — Empty-workspace route safety and Release handoff

> **Historical interim gate.** Later integration, SQLite-23 repair, packaging,
> installation, and final Delivery decisions supersede the status and release
> statements in this subsection. RR-R7 is not an open separate writer; its
> route/sidebar work is included in the combined artifact awaiting owner
> validation.

- Historical status and dependency gate: At that time, the corrected
  preimplementation brief was accepted, no RR-R7 product code had been
  implemented, and RR-R7 was treated as the sole dependency-safe writer under
  the historical remediation plan. Later integration and acceptance consumed
  that release; it creates no current writer eligibility.
- Reproduction and root cause: Computer Use reproduced the defect only in the isolated `com.rekonlabs.ReleaseRadar.RR6QA` empty-store bundle at `/Users/jroberts/Desktop/Products/Debug/ReleaseRadar.app`: the sidebar exposed a fabricated `Current project` group and project routes, and selecting one surfaced `Delivery data unavailable — SQLite error 19: FOREIGN KEY constraint failed`. The isolated QA database subsequently passed integrity and foreign-key checks, excluding corruption. Current source confirms the runtime chain: `currentProjectID` falls back to `DashboardSampleData.projectID`; `SidebarView` renders project routes even when `currentProject` is nil; `navigate(to:)` calls `markDashboardOpened` for that nonexistent project; and its audited transaction violates the project foreign key. The owner bundle and owner database were not used for this reproduction.
- Historical scope, gates, and evidence contract: The recorded implementation
  boundary, independent reviews, RED/GREEN checks, isolated live QA, signing,
  and Release-handoff requirements below were the accepted RR-R7 contract.
  They are retained as delivery evidence, not instructions for a current
  Implementer. The later combined artifact satisfied and superseded this gate.
- Historical exact scope and exclusions: The Implementer was permitted to
  modify only `ReleaseRadar/App/AppModel.swift`,
  `ReleaseRadar/Navigation/SidebarView.swift`, and
  `ReleaseRadarTests/AppRouteTests.swift`. Admission of a project-scoped route
  had to require exact membership in the successfully loaded dashboard before
  any audit; a rejected route returned to Projects without `dashboardError`;
  valid project navigation retained the existing one owner/dashboard-open
  audit and first-open/notification behavior; and the sidebar project group
  existed only when `currentProject` existed. No schema/migration, owner-data
  access or repair, recorder semantics, route-enum change, sample-ID synthesis,
  onboarding policy change, UI-test target, packaging script, unrelated
  navigation refactor, bundle/entitlement identity change, Desktop QA deletion,
  notarization, Developer ID, App Store, auto-update, or other-user installation
  was authorized.
- Historical independent plan gates: Planning GO after incorporating the exact
  empty-store suppression fixture, valid-project loaded-dashboard audit control,
  and pinned Release handoff checks; Architecture GO, Required 0 and no ADR,
  with dashboard membership as the unchanged route-admission boundary; QA/test
  GO with all three Required brief corrections closed; TPM GO, Required
  blockers 0; Delivery Manager GO. Post-implementation acceptance required a
  fresh Code Reviewer, independent QA, Architect, Security/Privacy signing
  verifier, TPM, and Delivery Manager; the Implementer could not approve its
  own work.
- Historical RED/GREEN and integration evidence contract: retain the exact
  focused RED showing the pre-fix nonexistent-project navigation failure, then
  GREEN for that regression and all `AppRouteTests`. The empty fixture had to
  use `externalServicesSuppressed: true` and prove zero projects, nil current
  project, fallback to Projects, no global error, and unchanged audit count.
  The strengthened valid-project control first had to load the dashboard and
  prove exactly one `release-radar-owner` / `Open project dashboard` audit while
  preserving first-dashboard-open, notification eligibility, and selected-route
  behavior. The full suite and a clean configured build also had to pass; no
  new harness was authorized.
- Historical live and handoff evidence contract: independent QA had to use an
  alternate isolated Debug capture and compare accessibility plus screenshot
  evidence directly with `docs/design/mockups/onboarding_state.png`, proving a
  usable Projects/onboarding surface, no fabricated project heading/routes, no
  `failure-delivery-data` or SQLite error, responsive recovery, and no owner-data
  access. Only `/tmp/ReleaseRadar-RR7-Release/Build/Products/Release/ReleaseRadar.app`
  could be the staged handoff source. Before and after copying it to
  `/Applications/ReleaseRadar.app`, the contract required strict nested signing,
  `com.rekonlabs.ReleaseRadar`, Release configuration, AppIcon metadata, Apple
  Development identity, Hardened Runtime, sandbox/effective entitlements, and
  absence of `com.apple.security.get-task-allow`. Any build, signing, identity,
  icon, or entitlement failure blocked copying and had to leave the last known
  destination untouched. The Release artifact was not to be launched against
  owner data and was not claimed as notarized or suitable for third-party
  distribution.
- Historical Delivery Manager decision: A fresh RR-R7 Implementer was released
  at that time with no concurrent writer. That decision is fully consumed; no
  current or later writer is opened by this subsection.

### Existing-project onboarding — historical task split and preimplementation gate

> **Historical delivery record.** Attach Folder is classified Completed above.
> The later combined-artifact and SQLite-23 owner-validation gates supersede
> every writer-release and conditional-acceptance statement in this section.
> Nothing here establishes current eligibility.

- Historical status and sequencing: The owner prioritized this slice on
  2026-08-25. At that time, fresh controller reconciliation passed all 16
  `AppRouteTests` at
  `/tmp/release-radar-rr-r7-reconcile/Logs/Test/Test-ReleaseRadar-2026.08.25_08-19-53--0400.xcresult`,
  all ephemeral read-only role processes had exited, and **Attach Folder to
  Existing Project** was released as the sole product writer. Later integration
  and acceptance consumed that release; RR-R7 packaging is not deferred by this
  section now.
- Validated workflow split: **Attach Folder to Existing Project** authorizes an existing persisted rootless project and must call `FolderProjectOnboarding.associateFirstProjectRoot` directly. **Import Existing Project** creates a new project only from the portable archive approved in ADR-001; it does not reuse or relabel the partial Rekon seed importer.
- Source verification: `ReleaseRadarCore/Import/RekonArtifactImporter.swift` reads only schema-version-1 `docs/delivery/dashboard-status.json` and its preview omits the complete supported project graph. The repository contains no authoritative `docs/delivery/dashboard-status.json`, portable `.release-radar-project.json`, exporter, or exporter-produced fixture; the only matching dashboard JSON is a synthetic test fixture. Markdown plans, task briefs, handoffs, and this ledger remain non-authoritative for complete-project import.
- Historical dependency order: The accepted order at that time was (1)
  reconcile the RR-R7 baseline and record gates; (2) record portable archive v1
  in ADR/design; (3) implement and independently accept Attach Folder; (4)
  separately plan and approve an authoritative exporter plus exporter-produced
  fixture; (5) implement and verify the portable importer/UI; and (6) produce a
  Release Radar archive before importing this repository. Steps 1–3 are
  historical; current B2/B3 status above controls the still-blocked remainder.
- Attach task brief — objective and outcome: Add Project exposes the exact **Attach Folder to Existing Project** label, lists only established persisted projects with no open onboarding marker, root, or bookmark, lets the owner select one project and one folder, names both in confirmation, preserves all existing delivery/goal/dependency/review/history state, and returns to a refreshed Projects surface with the target selected.
- Attach scope and interfaces: Reuse `associateFirstProjectRoot`; do not call onboarding `inspect`, `prepare`, `requestFirstPhaseDefinition`, `finish`, either importer, Markdown discovery, or marker creation. The app boundary distinguishes committed success from committed-but-refresh-failed, remains on Projects, selects the target, and does not open a dashboard or create a dashboard-open audit. Cancellation, Escape, chooser cancellation, and standard sheet close before confirmation perform no write; interactive dismissal is disabled while the confirmed transaction is in flight.
- Attach persistence, privacy, and failure behavior: The only durable additions are one canonical root, one fresh non-stale local bookmark, and one path-free project-scoped `release-radar-owner` / `Associate first project folder authorization` audit. Canonical/symlink-equivalent ownership, root-only/bookmark-only/already-associated state, missing project, invalid folder, stale/mismatched/denied authorization, and repeated submission fail closed without repair or partial write. Owned-folder errors direct the owner to choose another folder; already-associated state directs to existing reauthorization. A refresh failure says the folder was attached and must not be retried, with Reload recovery.
- Attach test-first acceptance: Characterize the existing service before UI changes with a populated rootless-project snapshot covering project, active phase, phases, tickets, both dependency types, blockers, evidence, exclusions, observed threads/goals, thread/ticket-goal links, reviews, completions, notification/occurrence history, prior audits, unrelated-project state, command requests, and alert rules. Prove only the root/bookmark/audit delta, relaunch persistence, balanced security-scope access, and rollback for ownership and authorization failures. True RED application cases cover the missing labelled workflow, project selection, confirmation, refresh/select behavior, and saved-but-refresh-failed recovery. Use only existing XCTest/temp-store patterns and the repository-native Xcode commands.
- UI and live acceptance: Use a never-before-used alternate Debug bundle/container and isolated database with external services suppressed. Accessibility and screenshots must verify the exact attachment label, eligible-project list, project/folder confirmation, actionable failures, Cancel/Escape/standard close, in-flight dismissal protection, refresh/selection, relaunch persistence, and responsive hierarchy at wide, about 900 x 650, and 760 x 520 against `docs/design/mockups/onboarding_state.png`. Never launch the owner bundle, inspect owner data, read Keychain, start the bridge, or dispatch notifications.
- Historical independent preimplementation gates: Planning, Architecture, QA,
  Security/Privacy, TPM, and Delivery Management released Attach at that time;
  the portable importer remained blocked without an exporter fixture. Those
  decisions are preserved as evidence and create no current writer release.
- Portable archive v1: ADR-001 defines the stable-ID, create-only, single-root complete portable graph; strict source validation and unchanged-source rule; fresh destination bookmark; reject-without-remapping collisions; atomic project/graph/root/bookmark/audit commit; excluded device-local/operational state; and prohibition on Markdown, Rekon seed JSON, repository state, or SQLite copies. Importer implementation is blocked until an authoritative exporter produces the acceptance fixture.
- Completion evidence required here: RED/GREEN commands, complete-graph preservation and exact delta, rollback cases, no onboarding/import/dashboard-open side effects, cancellation and committed-refresh-failure behavior, isolated live accessibility/screenshots, relaunch authorization, full-suite/build results, independent Code Review/QA/Architecture/Security/TPM/Delivery decisions, risks, and next eligible task.

#### Existing-project onboarding implementation and historical gate

- Historical status and scope: **Attach Folder to Existing Project** was
  implemented and independently reviewed. Its then-conditional live-observation
  gate was superseded by later integration and acceptance. **Import Existing
  Project** remains blocked and unimplemented under the current inventory.
- Implementation boundary: Add Project now opens as a singleton native macOS window titled `Add Project`, so Cancel, Escape, and the standard red close control are visible and functional. Folder panels use the nonblocking AppKit completion API. The distinct attachment workflow lists persisted projects with no root, bookmark, or open onboarding marker, names the selected project and folder before confirmation, and routes only through `FolderProjectOnboarding.associateFirstProjectRoot`. It does not call onboarding `inspect`, `prepare`, `requestFirstPhaseDefinition`, or `finish`; either importer; Markdown discovery; marker creation; or dashboard-open behavior. The pre-existing partial Rekon path is explicitly labelled as a new-project seed artifact rather than portable import.
- Persistence, recovery, and audit evidence: Focused acceptance coverage proves the existing project graph and unrelated state are preserved; the only committed delta is one canonical root, one fresh non-stale bookmark, and one path-free project-scoped `release-radar-owner` / `Associate first project folder authorization` audit. Relaunch authorization succeeds. Symlink-equivalent ownership, root-only/bookmark-only/already-associated states, invalid authorization, and ownership conflicts fail closed with rollback. App refresh selects the attached project without opening its dashboard, and committed-but-refresh-failed state directs the owner to Reload without retrying the transaction.
- Test and build evidence: The final focused `OnboardingAcceptanceTests` plus `AppRouteTests` run passed 39/39 with no failures or skips at `/tmp/release-radar-existing-attach-controller/Logs/Test/Test-ReleaseRadar-2026.08.25_08-59-45--0400.xcresult`. The current combined suite passed 154/154 with no failures or skips at `/tmp/release-radar-existing-onboarding-full/Logs/Test/Test-ReleaseRadar-2026.08.25_08-54-30--0400.xcresult`. A fresh configured Release build succeeded at `/tmp/release-radar-existing-onboarding-release/Build/Products/Release/ReleaseRadar.app`; strict nested signature verification passed with identifier `com.rekonlabs.ReleaseRadar`, Apple Development identity and team `2UA854NLX4`, and hardened runtime.
- Live isolated evidence: Computer Use exercised only the alternate bundle `com.rekonlabs.ReleaseRadar.AttachQA2` with `CFFIXED_USER_HOME=/tmp/release-radar-attach-qa.b5Woo9` and external services suppressed. It directly verified the native Add Project title/window, red close, visible Cancel, Escape dismissal, exact `Attach Folder to Existing Project` label, eligible `Rekon Pursuit` selection, native folder picker, and responsive layouts at approximately 760 x 520 and 900 x 650. After Cancel, Escape, and red-close exercises, the isolated database still contained zero project roots, zero bookmarks, and zero association audits. The owner bundle, owner database, Keychain, bridge, and notification delivery were not used.
- Independent final reviews: Code Reviewer GO, Required 0; Architecture GO, Required 0 and no additional ADR required; Security/Privacy GO, Required 0; QA **CONDITIONAL GO**, Required 0; TPM **CONDITIONAL GO**; Delivery Manager **CONDITIONAL GO**. The earlier reviewer concern that the approved Rekon seed importer was being exposed as portable import was closed by explicit new-project seed labelling and a fresh independent GO review.
- Historical residual evidence limitation: Computer Use lost the application
  accessibility connection after `NSOpenPanel` closed, so this slice did not
  directly observe the final live confirmation and return-to-Projects state.
  That limitation no longer controls task eligibility and does not reopen
  Attach Folder.
- Current portable import blocker: **Import Existing Project** remains
  **NO-GO** until Release Radar has an authoritative exporter and an
  exporter-produced `.release-radar-project.json` acceptance fixture for the
  complete ADR-001 archive graph. Repository Markdown, the partial
  `docs/delivery/dashboard-status.json` Rekon seed format, repository state,
  and SQLite copies are not authoritative portable import sources. No RR-R7
  packaging writer or other product writer is released by this historical
  section.

### Initialize Project Tracking — owner decision and implementation-plan gate

- Owner decision — 2026-08-25: Replace owner-facing “first phase” onboarding
  with **Initialize Project Tracking**. Use a truthful human-mediated handoff:
  Release Radar saves a resumable pending project and shows the exact path-free
  prompt recorded in the design/remediation plan. The owner pastes it into a
  Codex task rooted at the folder. The app does not launch, contact, paste into,
  submit to, or otherwise control Codex.
- Required copy affordance: icon-only overlapping squares
  (`square.on.square`), accessibility label **Copy Codex prompt**, visible and
  accessibility-announced success/failure, and disclosure that only the prompt
  is copied and remains on the clipboard until replaced. No folder path,
  bookmark, project content, or secret is copied. The future Help section is
  deferred. Portable Import remains hidden and blocked by its exporter/archive
  gate.
- Validated split: Task 7A first reproduces the exact SQLite-23 statement or
  records isolated current-source non-reproduction, then adds truthful
  nothing-saved versus saved-seed-incomplete persistence outcomes without
  weakening the `audit_events` authorizer. Task 7B adds the explicit
  Initialize/Attach landing, confirmation, saved/waiting/resume hierarchy, and
  copyable prompt while preserving Attach persistence.
- Plan gates: independent Planning delivered the complete two-slice test-first
  brief. Architecture **CONDITIONAL GO** after pinning the exact reproduction,
  saved-incomplete, no-automatic-action, and design-record requirements. TPM
  **CONDITIONAL GO** and confirms no owner decision remains. Fresh QA/test,
  Delivery Manager, and Security/Privacy plan review remain required; no
  Implementer is released.
- Current process blocker: a fresh QA reviewer could not be created because
  the built-in collaboration runtime reported `agent thread limit reached`
  while retaining completed/interrupted agent identities. The primary agent
  did not reuse the Planning agent or substitute its own review. This is a
  process gate only; it does not change the product plan or authorize a writer.
  Resume these missing independent plan gates in a context with fresh role
  capacity before implementation.
- Resumed independent plan reviews — 2026-08-25: Fresh QA/test **GO** for Task
  7A and Task 7B's plan, with 7B contingent on independent 7A acceptance;
  Required 0, Optional evidence refinements only. Fresh Security/Privacy
  **GO** for Task 7A and Task 7B's plan on the same dependency; Required 0,
  Optional authorizer negative-control and pasteboard failure-state evidence
  only. Fresh Delivery Management found the two-slice plan sound and held its
  final 7A release only until these QA/Security reviews and the explicit Attach
  limitation disposition below were durable. Task 7B remains closed until 7A
  is accepted and its fresh five-role release gate is recorded.
- Attach live-observation disposition — 2026-08-25: The final native-picker
  confirm-and-return step is explicitly accepted as a tooling/evidence
  limitation, not claimed as directly observed and not treated as a
  demonstrated product defect. The accessibility connection consistently
  disconnects when `NSOpenPanel` closes; direct isolated acceptance tests
  nevertheless cover the committed root/bookmark/audit delta, rollback,
  relaunch authorization, refresh, and selection, while isolated live checks
  cover the workflow entry, exact label, picker, Cancel, Escape, red close,
  responsive layouts, and their no-write behavior. Fresh QA and Delivery both
  accept this narrow disposition; the prior TPM conditional GO was conditioned
  solely on the same documented gap. This closes Attach's conditional
  QA/TPM/Delivery gate for the purpose of releasing 7A, but does not waive
  7B's own live verification or permit a claim that the missing Attach step was
  visually observed.
- Pre-7A controller baseline — 2026-08-25: The unchanged combined source ran
  all `OnboardingAcceptanceTests` in fresh DerivedData
  `/tmp/release-radar-7a-baseline.EuaopI` and passed 20/20 with no failures or
  skips; result bundle
  `/tmp/release-radar-7a-baseline.EuaopI/Logs/Test/Test-ReleaseRadar-2026.08.25_13-01-13--0400.xcresult`.
  Existing acceptance coverage did not reproduce SQLite error 23. This is only
  a baseline; Task 7A's four-state statement/caller/authorizer reproduction
  gate remains mandatory before any policy or caller change.
- Task 7A release — 2026-08-25: Delivery Management **GO** after re-reading the
  durable fresh QA/Security reviews and Attach limitation disposition. The
  Architecture/TPM conditions are pinned in the approved brief and remain
  binding. Release one fresh 7A Implementer as the sole product writer, first
  performing the isolated four-state SQLite-23 investigation. Task 7B, RR-R7
  packaging, Help, and portable import remain closed. Post-implementation
  acceptance requires fresh independent Code Review, QA, Architecture,
  Security/Privacy, TPM, and Delivery decisions.
- Task 7A implementation and acceptance — 2026-08-25: **Accepted** in the
  current uncommitted combined working diff. The bounded delta adds
  `OnboardingPreparationError.seedApplicationFailedAfterSave(ProjectID)` and
  catches only post-base `RekonArtifactImporter.apply` failure while preserving
  the source-compatible `prepare(_:) -> ProjectID` signature. Acceptance tests
  add successful base-state/no-automatic-action/relaunch/repository-sentinel
  coverage, recognized-seed saved-incomplete/zero-partial-import coverage, and
  pre-commit bookmark-failure rollback/repository preservation. No Task 7A
  change touched `SQLiteConnection`, store/schema policy, importer scope,
  Attach, bridge, notifications, or UI.
- Task 7A SQLite-23 gate: An isolated temporary diagnostic exercised fresh,
  pending, pending-with-phase-request, and pending-with-project-scoped-audit
  states through the current `FolderProjectOnboarding.prepare` SQL path. Both
  retained 1/1 runs passed at
  `/tmp/release-radar-7a-investigation.Kjn2S9/Logs/Test/Test-ReleaseRadar-2026.08.25_13-05-00--0400.xcresult`
  and
  `/tmp/release-radar-7a-investigation.Kjn2S9/Logs/Test/Test-ReleaseRadar-2026.08.25_13-05-23--0400.xcresult`.
  SQLite error 23 did not reproduce, so there is no denied statement or
  authorizer action/argument tuple; no policy or caller was changed, and no
  bundle-mismatch claim is made because bundle provenance was not separately
  established. The historical report remains an accepted non-reproduction,
  not proof that another bundle was responsible.
- Task 7A TDD and behavioral evidence: RED at
  `/tmp/release-radar-7a-red.kYDHnt/Logs/Test/Test-ReleaseRadar-2026.08.25_13-07-38--0400.xcresult`
  failed on the missing `OnboardingPreparationError`. GREEN proves successful
  initialization adds exactly one project, root, fresh bookmark, open pending
  marker, and prepare audit, with zero phase-request markers/audits, phases,
  command requests, notification events, or occurrences. A changed recognized
  seed after preview returns the durable project identity, retains only that
  base delta, and adds zero import rows or import audit. Bookmark creation
  failure leaves the complete database snapshot and audit counts unchanged.
  New-store/onboarding instances recover the pending identity and authorized
  root with balanced test scope access. Disposable-folder sentinel bytes and
  recursive listings are identical before and after success and failure.
- Task 7A verification: Implementer GREEN passed 23/23 onboarding cases plus
  the 1/1 protected-`audit_events` negative control. Fresh independent QA
  repeated 23/23 and 1/1 at
  `/tmp/release-radar-7a-qa-9214c28b-a566-4708-a8e6-6afc84f580e7/onboarding-acceptance.xcresult`
  and
  `/tmp/release-radar-7a-qa-9214c28b-a566-4708-a8e6-6afc84f580e7/store-authorizer-negative-control.xcresult`.
  Fresh controller verification repeated 23/23 and 1/1 at
  `/tmp/release-radar-7a-controller.0I9dkp/Logs/Test/Test-ReleaseRadar-2026.08.25_13-16-17--0400.xcresult`
  and
  `/tmp/release-radar-7a-controller.0I9dkp/Logs/Test/Test-ReleaseRadar-2026.08.25_13-16-36--0400.xcresult`.
  All three existing Attach persistence/rollback regressions passed, and
  `git diff --check` is clean for the two owned files.
- Task 7A independent final reviews: Code Reviewer **APPROVED**, Required 0,
  Optional 0; QA **ACCEPT**, Required 0, Optional 0; Architecture **APPROVED**,
  Required 0 and no ADR/design change; Security/Privacy **PASS**, Required 0,
  Optional 0; TPM **GO**, Required blockers 0; Delivery Management **GO**.
  Accepted residual risk: the reported SQLite-23 failure remains unexplained
  because isolated current source did not reproduce it and bundle provenance
  was not established; the authorizer remains fail-closed.
- Historical release sequence at the original plan gate: no writer was eligible
  until the missing plan gates returned GO and the residual Attach
  live-observation gap was closed or explicitly accepted. Task 7A was then to be
  released as the sole writer and accepted independently before Task 7B.
- Historical Task 7B gate: Task 7B subsequently entered its fresh Architecture,
  TPM, QA/test, Delivery Management, and Security/Privacy preimplementation
  review, with no Implementer released before all five roles returned GO. That
  gate was later completed and is preserved only as evidence; it creates no
  current writer eligibility.
- Task 7B fresh plan-review wave — 2026-08-25: Architecture **GO**, Required
  0 and no ADR change; Security/Privacy **GO**, Required 0. QA/test initially
  returned **NO-GO** on one plan-level gap: the brief required deterministic
  pasteboard failure coverage but did not define its local seam or pin the full
  directly testable RED presentation/persistence matrix. The Task 7B brief now
  requires one `OnboardingView.swift`-local immutable prompt/result plus an
  injected `(String) -> Bool` writer defaulting to `NSPasteboard.general`, with
  success bound to a uniquely named pasteboard and failure forced by returning
  `false`; no framework, global service, or dependency is added. The amended
  RED matrix assigns exact landing/confirmation/clipboard/result contracts to
  `AppRouteTests`, persistence/no-duplicate/no-auto-action/phase-gate/Attach
  contracts to onboarding acceptance coverage, and actual close-control
  interaction to the already required isolated live matrix. QA re-review, then
  fresh TPM and Delivery review, remain required; no writer is released.
- Task 7B amended plan gates — 2026-08-25: Fresh QA/test re-review **GO**,
  Required 0, after confirming the local clipboard seam and exact RED matrix
  close its sole finding. Fresh TPM **GO**, Required blockers 0; Task 7A is
  accepted and 7B is dependency-safe, with the historical SQLite-23
  non-reproduction and native-picker observation limitation retained as
  explicit accepted risks rather than waived evidence. The amended Task 7B
  brief now explicitly requires independent post-implementation Code Review,
  QA/test, Architecture, Security/Privacy, TPM, and Delivery Management before
  acceptance. Delivery re-review remains the last preimplementation gate; no
  writer is released until it returns GO.
- Task 7B release — 2026-08-25: Delivery Management **GO**, Required 0. All
  five fresh preimplementation gates are durable: Architecture, QA/test,
  Security/Privacy, TPM, and Delivery. Release one fresh Task 7B Implementer as
  the sole product writer, limited to the amended brief's two views and focused
  AppRoute/onboarding acceptance coverage. Attach callbacks and transactions,
  `associateFirstProjectRoot`, schema, importer, bridge, Help, Portable Import,
  RR-R7 packaging, owner bundle/data, and new UI-test/clipboard infrastructure
  remain closed. Final acceptance requires fresh independent Code Review,
  QA/test, Architecture, Security/Privacy, TPM, and Delivery decisions.
- Task 7B implementation review wave — 2026-08-25: The bounded four-file
  implementation reached focused GREEN at 48/48, full GREEN at 163/163, and a
  successful configured Debug build. Security/Privacy **PASS**, Required 0.
  Code Review returned spec **NO-GO** with two accepted Required findings:
  superseded owner-facing “ask an agent/first phase” copy remains active in
  existing shared presentations, and clipboard tests call the handoff helper
  without mounting/driving the injected `OnboardingView` state, so removal of
  actual button/result wiring could escape. QA is **CONDITIONAL** with the same
  view-wiring point classified Optional and one Required live-evidence gap:
  after directly observing the alternate Add Project landing, both workflow
  entries, Back/Cancel/Escape/red-close no-write states, and compact/wide
  layouts, Computer Use failed twice when the native picker closed. No product
  defect was established; confirmation, saved/resumed handoff, clipboard,
  persisted phase gate, and remaining responsive matrix are not yet claimed.
- Task 7B Ruling — Code Review's third finding does not expand the exact
  two-action landing contract from **Add Project** to the embedded truly empty
  Projects surface. The controlling Task 7B objective says “Add Project first
  offers” both actions; fresh live QA directly observed both in the Add Project
  window with Import/Help absent. `ProjectsView` constructs the embedded
  initialization surface only when its dashboard projection has no persisted
  projects, so it has no eligible existing project to attach and intentionally
  receives no Attach loader/callback. Adding that integration would require
  out-of-brief `ProjectsView`/model interface changes and a nonfunctional Attach
  action. Cost if wrong: the empty-store embedded surface continues to show
  only Initialize, while the required Add Project window remains the two-action
  workflow; revisit only if product scope is explicitly broadened.
- Task 7B fix round 1/5 opened: return the two accepted Required findings to
  the original Implementer. Add RED coverage for every active shared
  presentation that must drop false first-phase/ask-agent language, and a
  lowest-practical mounted/injected view-state regression proving the actual
  copy action replaces prior success with visible/accessibility failure. Keep
  the live QA gap open for fresh post-fix verification; do not substitute source
  inspection for the unobserved runtime matrix.
  RR-R7 packaging remains deferred; Help and portable import remain closed.
- Task 7B fix-round disposition — 2026-08-25: The shared-copy finding was
  closed with RED coverage and corrected owner-facing **Initialize Project
  Tracking** / **tracking state** terminology across the active shared
  constants and onboarding-error mappings. An attempted mounted SwiftUI test
  demonstrated that the in-process AppKit accessibility tree exposed only the
  selectable prompt, not the hosted SwiftUI controls. The temporary
  `initialHandoffProjectID` and copy-action registrar seams and their rendering
  harness were removed under the proportionality rule: literal in-process
  button activation remains Optional coverage, while production wiring is
  direct and the approved writer seam retains exact-byte success and forced
  success-to-failure replacement tests. No UI-test target, dependency, launch
  flag, global service, debug state, or snapshot infrastructure was added.
- Task 7B implementation and acceptance — 2026-08-25: **Accepted** in the
  current uncommitted combined working diff; no dedicated commit was created.
  Add Project now offers only **Initialize Project Tracking** and **Attach
  Folder to Existing Project**. Initialization separates read-only preview
  from explicit confirmation, persists a resumable pending base state, reports
  a typed saved-seed-incomplete outcome without partial import, displays the
  exact approved 460-byte path-free Codex prompt, and provides the icon-only
  **Copy Codex prompt** affordance with truthful visible/accessibility success
  or failure and clipboard disclosure. The app performs no automatic Codex or
  phase request; **Check Tracking Status** is read-only and **Finish
  Initialization** rechecks the persisted phase gate. Existing Attach
  transactions and recovery behavior remain unchanged. `ProjectsView`, schema,
  importer scope, typed bridge ownership, Help, and Portable Import were not
  expanded.
- Task 7B TDD and final verification: Initial RED is
  `/tmp/release-radar-7b-red.QhHTAi/task-7b-red.xcresult`; the stale-copy RED is
  `/tmp/release-radar-7b-fix1-copy-red.kc1ihS/copy-red.xcresult`. Final
  Implementer verification passed 53/53 focused tests at
  `/tmp/release-radar-7b-fix2-focused.lfduws/focused.xcresult`, 163/163 full
  tests at `/tmp/release-radar-7b-fix2-full.ZAtLRc/full.xcresult`, and the
  configured Debug build at
  `/tmp/release-radar-7b-fix2-build.hAThBc/build.xcresult`; scoped
  `git diff --check` was clean. Fresh independent QA repeated 53/53 focused and
  163/163 full at
  `/tmp/release-radar-7b-qa-fix2-focused.CcJwFF/focused.xcresult` and
  `/tmp/release-radar-7b-qa-fix2-full.cLwar4/full.xcresult`, with a zero-error
  Debug build at
  `/tmp/release-radar-7b-qa-fix2-build.MWlb3p/build.xcresult`. Final controller
  verification passed 54/54 current-source cases, including the protected
  `audit_events` negative control, at
  `/tmp/release-radar-7ab-controller-final.yQdmzs/focused.xcresult`.
- Task 7B live and visual evidence: Independent isolated QA directly observed
  the Add Project two-action landing with Import/Help absent, Initialize and
  Attach entry, Back, Cancel, Escape, red-close no-write behavior, and compact
  and wide layouts. Captures are
  `/tmp/release-radar-7b-qa-live.xMcC4h/add-project-compact.png` (760 x 532),
  `/tmp/release-radar-7b-qa-live.xMcC4h/add-project-landing.png` (760 x 560),
  `/tmp/release-radar-7b-qa-live.xMcC4h/landing-wide.png` (1499 x 768),
  `/tmp/release-radar-7b-qa-fix1-live.lrbv4B/live-add-project-landing.png`
  (1499 x 768), and
  `/tmp/release-radar-7b-qa-fix1-live.lrbv4B/live-disposable-picker.png`
  (880 x 448). The alternate store remained empty and the disposable sentinel
  remained unchanged after abandonment/dismissal checks.
- Task 7B independent final reviews: Code Reviewer **APPROVED**, Required 0;
  QA/test **PASS**, Required 0; Architecture **APPROVED**, Required 0, no ADR
  change, with 53/53 focused verification at
  `/tmp/release-radar-7b-arch.l3NLPt/architecture-focused.xcresult`;
  Security/Privacy **PASS**, Required 0, with 8/8 focused verification at
  `/tmp/release-radar-7b-security-fix1-20260825/Logs/Test/Test-ReleaseRadar-2026.08.25_14-09-24--0400.xcresult`;
  TPM **GO**, Required blockers 0; Delivery Management **GO**, Required 0. The
  exact two-action contract remains scoped to Add Project rather than the
  embedded truly empty Projects surface, as recorded in the ruling above.
- Task 7B accepted residual evidence limitation: Computer Use consistently
  disconnected when `NSOpenPanel` closed, so the post-picker confirmation,
  saved/resumed handoff, general-pasteboard feedback, persisted phase gate, and
  exact 900 x 650 presentation are not claimed as directly observed. QA, TPM,
  and Delivery accept this as a tooling limitation, not a demonstrated product
  defect, because deterministic acceptance tests cover the persistence,
  repository no-write, clipboard, status/phase-gate, relaunch, failure, and
  Attach contracts. A future isolated live rerun when the bridge is stable is
  Optional. Task 7A's unexplained SQLite-23 current-source non-reproduction
  remains a separate accepted residual uncertainty; the store authorizer
  remains fail-closed.
- Historical Initialize Project Tracking remediation closeout, superseded by
  the reopened SQLite-23 gate below: Tasks 7A and 7B were closed
  and accepted. At that time, RR-R7 final route verification and Release
  packaging/handoff were recorded as next; that eligibility was consumed and
  has no current effect. Help, Portable Import/exporter work, and later product
  writers remain closed until their own approved gates.

### Initialize Project Tracking SQLite-23 repair — reopened owner gate

- Status — 2026-08-25: **Reopened; not accepted and not Done.** This section
  supersedes the earlier Task 7A/7B acceptance and closeout statements. The
  owner reproduced a production failure in the installed app while confirming
  **Initialize Project Tracking**: `SQLite error 23: access to
  audit_events.project_id is prohibited`.
- Confirmed root cause: the version-9 migrated schema retains legacy project
  active-phase triggers. Preparing the onboarding project upsert causes SQLite
  to authorize an internal `SQLITE_READ` of `audit_events.project_id`. The
  transaction authorizer currently denies every action that names
  `audit_events`, so SQLite returns `SQLITE_AUTH` (23) before the upsert can
  execute. A fresh-schema test did not reproduce this migrated-schema path and
  was insufficient evidence for the installed app.
- Repair boundary: keep transaction-control denial first; allow only
  `SQLITE_READ` when the protected `audit_events` table is named; continue to
  deny every direct or indirect write to that table. Do not change migrations,
  the recognized schema, onboarding SQL, owner data, or repository contents.
- Diagnostic boundary: add durable unified logging at the SQLite boundary with
  a fixed event/stage identifier, primary and extended SQLite result codes,
  authorizer action code/name, equality-allowlisted identifiers only, schema
  version, and in-transaction state. Never log SQL, bindings, arbitrary SQLite
  or trigger text, actor/reason/thread/project values, project or repository
  names/IDs/paths, bookmark bytes, prompts, credentials, or row data. The
  authorizer logger must not query SQLite.
- Regression boundary: reproduce the exact migrated-schema onboarding failure
  before the repair; retain direct protected-table INSERT/UPDATE/DELETE denial;
  cover indirect foreign-key `ON DELETE SET NULL` denial with complete rollback
  of the parent, protected audit reference, and an ordinary cascade child; and
  verify relaunch persistence, repository no-write behavior, foreign-key
  integrity, focused suites, and the full suite.

#### Owner-mandated delivery guardrails

1. **Owner owns Done.** Engineering may report only **Ready for owner
   validation**. Nothing is Done or Accepted until the owner personally tests
   `/Applications/ReleaseRadar.app` and explicitly approves it.
2. **Release only.** Do not hand off, install, or describe a Debug build as the
   app for owner validation.
3. **Two durable destinations, one verified bundle.** Preserve the Release
   artifact at
   `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app`
   and install the exact same verified bundle at
   `/Applications/ReleaseRadar.app`.
4. **No temporary handoff.** DerivedData and `/tmp` are build/test locations,
   never the owner-facing app destination.
5. **No unsupported priority or scope assumptions.** Material decisions must
   come from explicit owner requirements or recorded evidence; uncertainty is
   inspected or surfaced rather than silently decided.
6. **Production-shaped verification.** Exercise the migrated schema and the
   reported failure path against a database already populated with unrelated
   project, phase/child, and scoped-audit history. Snapshot that existing data
   and prove it remains unchanged except for the exact expected onboarding
   delta. A fresh empty database is only a secondary control, never sufficient
   evidence by itself.
7. **Durable diagnostics before guessing.** Consequential runtime failure paths
   require privacy-bounded logs sufficient to identify the failed stage and
   SQLite/authorizer result without exposing owner data.
8. **Evidence before claims.** Verify the exact command, configuration, bundle,
   signature, entitlements, identity, hashes, and installed destination before
   reporting them. A successful build is not evidence that the installed app
   works.
9. **No hidden weaker substitutions or unrelated work.** Any limitation is
   stated explicitly; no later task, refactor, warning cleanup, or adjacent
   feature is opened to make the repair appear complete.
10. **Ledger accountability.** Failures, review decisions, packaging identity,
    install evidence, remaining uncertainty, and the owner validation state are
    recorded here. Prior erroneous acceptance language remains historical but
    is explicitly superseded by this reopened gate.

#### Completed repair-plan reviews

- Architecture: **GO**, Required 0; the scoped authorizer change preserves the
  app-only audit boundary and requires no ADR.
- QA: **GO**, Required 0 after the gate was corrected so artifact review occurs
  after packaging rather than circularly before it.
- Security/privacy: **GO**, Required 0 after the brief added privacy-bounded
  durable logging, complete cascade-child rollback assertions, and fail-closed
  entitlement verification.
- TPM: **GO**, Required blockers 0.
- Delivery Management: **GO**, Required 0; the nonlaunch modes and rollback
  behavior below are binding delivery requirements.

#### Pinned nonlaunch script contract

- Default/no argument and `stage-release-no-launch` /
  `--stage-release-no-launch`: build **Release**, verify the complete bundle,
  copy it to a unique sibling under `dist/`, verify the temporary copy, then
  atomically promote it to `dist/ReleaseRadar.app`. Do not launch or terminate
  the app.
- `install-staged-release-no-launch` /
  `--install-staged-release-no-launch`: do not build, launch, terminate, or open
  owner data. Verify the staged bundle, copy it to a unique sibling under
  `/Applications`, verify identity there, then atomically promote it to
  `/Applications/ReleaseRadar.app`.
- Existing `run`, `debug`, `logs`, `telemetry`, and `verify` remain explicit
  launch modes only. Every build performed by the script uses Release.
- Promotion rollback: verify the candidate before touching the final path; move
  any prior final bundle to a unique same-directory backup; independently
  verify the promoted bundle; restore the backup on failure. If restoration
  fails, return nonzero, preserve both the backup and failed candidate, and
  print their paths. Never merge into an existing app bundle.
- Bundle evidence must include strict deep signing; bundle identifier
  `com.rekonlabs.ReleaseRadar`; expected Apple Development authority/team;
  Hardened Runtime and exact expected main-app/bridge sandbox, app-group,
  user-selected-read-only, and network-client entitlements; embedded signed
  code identity; unexpected entitlement rejection; and equality between staged
  and installed CDHash, identifier, version/build, main-executable SHA-256, and
  resource manifest.

#### Remaining gate sequence

1. Implement the approved repair test-first and complete focused and full
   engineering verification.
2. Obtain independent Code Review, QA, Architecture, Security/Privacy, TPM, and
   Delivery Management engineering decisions.
3. Delivery Management explicitly authorizes packaging and installation.
4. Stage the nonlaunch Release bundle under `dist/` and install the identical
   verified bundle under `/Applications`.
5. QA and Security/Privacy independently verify the actual staged and installed
   artifacts.
6. Delivery Management records **Ready for owner validation**.
7. The owner personally tests `/Applications/ReleaseRadar.app`; only the
   owner's explicit approval may change this task to Done or Accepted.

#### Repair-plan ruling after first RED — 2026-08-25

- Evidence: the standalone synthetic SQLite diagnostic reproduced primary code
  23, authorizer tuple `(SQLITE_READ, audit_events, project_id)`, and the exact
  owner-visible `access to audit_events.project_id is prohibited` text. The
  real `FolderProjectOnboarding.prepare` XCTest reached the same primary code
  23 on the populated legacy-schema path but `sqlite3_errmsg` surfaced the
  generic text `not authorized`.
- Ruling: bind the RED gate to the stable primary code 23, independently
  captured authorizer tuple, populated migrated schema, and preservation
  assertions. Preserve the owner's exact message as reproduction evidence, but
  do not require every SQLite wrapper/path to reproduce identical human-readable
  wording. The repair's fixed-field diagnostic event becomes the stable future
  evidence for action/stage/result.
- Cost if wrong: a distinct authorization failure could be mistaken for this
  bug. That risk is controlled by the exact legacy triggers and production
  upsert in the real callback fixture, the standalone tuple diagnostic, and the
  populated-state preservation assertions. Fresh Architecture, QA, and
  Security/Privacy review of this ruling is required before implementation
  resumes.
- Fresh post-RED reviews: Architecture **GO**, Required 0 and no ADR change;
  QA/test **GO**, Required 0; Security/Privacy **GO**, Required 0. All three
  require the resumed Implementer to replace the earlier empty-fixture RED
  with a populated synthetic version-9 legacy-shape RED and capture code 23
  through the real onboarding callback before any production authorizer or
  logging change. The earlier empty-fixture result remains diagnostic history
  and is not final acceptance evidence.
- Implementation evidence, engineering review wave 1: the sole Implementer
  retained the populated RED at
  `/tmp/release-radar-sqlite23-populated-red-verified.xcresult`, passed 51/51
  focused Store/Onboarding tests, 167/167 full Debug tests, and 1/1 Release
  diagnostic test, and performed no stage/install/launch. Independent QA
  repeated 51/51, 167/167, and 1/1 but returned **NO-GO** with one Required
  populated-snapshot gap. Code Review returned **NO-GO** with three Required
  findings; Security/Privacy returned **NO-GO** with four Required findings.
  The review wave reported six unique blockers: no SQLite API call from inside the authorizer
  diagnostic path; exact one-element app-group validation; exact configured
  signing authority; fail-safe promotion/rollback through final identity
  verification, including first install; complete phase/legacy-project/audit
  field preservation; and exact new prepare-audit project/entity association.
  Packaging and installation remain closed pending a reviewed fix.
- Fix-round scope ruling: the sixth review demand above is reclassified
  **Optional/out of this repair**, not Required. The controlling Task 7A plan
  requires one prepare audit identified by actor
  `release-radar-onboarding` and reason `Prepare folder-backed project
  onboarding`; it does not require project/entity scope, and the urgent repair
  brief explicitly excludes changes to `FolderProjectOnboarding.prepare`.
  Ruling: preserve the existing audit association contract, remove only the
  newly added project/entity-scope assertion, and still compare every field of
  the pre-existing populated audit row before/after. Cost if wrong: the
  unscoped prepare audit may remain absent from a project-filtered Activity
  view. That behavior requires a separate explicit product/audit-contract
  change and is not allowed to expand this SQLite/persistence repair silently.
- Engineering fix round 1: the Implementer removed SQLite re-entry from the
  authorizer diagnostic callback, enforced exact nested entitlement structure
  and the configured signer, made strict verification/identity/rollback one
  fail-safe promotion transaction, and expanded the populated v9 preservation
  oracle. The populated regression passed 1/1, focused Store/Onboarding passed
  51/51, the full suite passed 167/167, Release diagnostic passed 1/1, and
  disposable adversarial signing/entitlement/rollback checks passed without
  staging, installing, launching, or accessing owner data. Code re-review:
  all findings addressed, Required 0. Security/Privacy re-review: R1-R4 all
  addressed, Required 0. QA re-review retained one Required test-oracle gap:
  the blocker snapshot omitted nullable `resolved_at`.
- Engineering fix round 2: the blocker preservation oracle now captures the
  exact full row. The populated regression passed 1/1 and focused
  Store/Onboarding passed 51/51. QA re-review: addressed, Required 0, no new
  breakage. Code, QA, and Security engineering gates are now clean; packaging
  and installation remain closed pending Architecture, TPM, and Delivery
  engineering decisions followed by a separate explicit Delivery packaging
  authorization.
- Final pre-packaging engineering decisions: Architecture **GO**, Required 0,
  no ADR change; TPM **GO**, Required blockers 0; Delivery Management
  engineering **GO**, Required 0. The Architecture review classifies structured
  project/entity scope on the existing prepare audit out of this repair. Its
  only Optional note is that any future schema-version diagnostic field must be
  precomputed outside the authorizer callback. Delivery holds packaging until
  a separate explicit authorization after final file-integrity evidence.
- Final scoped file integrity before packaging: `SQLiteConnection.swift`
  SHA-256 `f59b52e0263025718059130a75a20cb23c7dd712d6610bf6e1e85f0c9fa0b260`;
  `StoreAcceptanceTests.swift`
  `1fc4a7646a275e299e5283b858d5d6ffe3950a2ba20fd60ce158d2735b2a8052`;
  `OnboardingAcceptanceTests.swift`
  `ab30414f14c50a5a38cc5c0d1624659aa730c21cbebb625a4cd4c31d5abee896`;
  `script/build_and_run.sh`
  `b59bb571af0a0277315690973dadbf96e1aae32664bb4bc61b553098352e9e2e`.
  All four differ from their pre-task snapshots as expected; scoped
  `git diff --check` and `bash -n` passed. No stage/install/launch occurred.
- Delivery packaging authorization: **AUTHORIZED**, Required blockers 0, for
  exactly `script/build_and_run.sh --stage-release-no-launch` followed only on
  success by `script/build_and_run.sh --install-staged-release-no-launch`.
- Release staging/install evidence: the authorized stage command exited 0 and
  preserved the verified Release bundle at
  `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/dist/ReleaseRadar.app`.
  The separately authorized install command then exited 0 and promoted the
  identical verified bundle to `/Applications/ReleaseRadar.app`. Neither mode
  launches or terminates the app; no launch mode was invoked, a post-install
  process check found no ReleaseRadar process, and no temporary stage/install,
  backup, or failed-candidate path remained at either final parent.
- Actual artifact identity: both bundles independently pass strict/deep signing
  with identifier `com.rekonlabs.ReleaseRadar`, version/build `0.1.0` / `1`,
  configured leaf authority `Apple Development: jaroberts4@gmail.com
  (PT7GS96H3L)`, team `2UA854NLX4`, Hardened Runtime, exact approved main and
  Bridge entitlements, and no `get-task-allow`. Both have CDHash
  `893c9deab194bfbfbffc8a3966cb92e3c84f448b`, main-executable SHA-256
  `1cce7f95fc18af8c95f855a1cc4a562795b6ff6a9bc79d0207a6e6f0d57282ee`,
  and CodeResources SHA-256
  `a7805f62f34929c63638c896ef85366532cf5365a658439fdede8140ac0e687a`.
  Artifact QA additionally matched a 12-file regular-file manifest digest
  `23f02ed7c4928a25e1a41ec62ada6ba8dc831a4d5c23572b8b10108b3428ffde`
  and three-link path/target manifest digest
  `3191e41574202baf9725748b8bc844dfc9998a1f06839825d2c433be24bce5f0`.
- Post-artifact decisions: QA **PASS**, Required 0, Optional 0; Security/Privacy
  **PASS**, Required 0, Optional 0. Both reviews are artifact-only and do not
  claim the SQLite workflow works for the owner. These reviews released the
  final Delivery Management decision below; Done/Accepted remains owner-only.
- Final Delivery Management decision: **Ready for owner validation**, Required
  blockers 0. This is explicitly not Done, Accepted, working for the owner, or
  release-complete. The owner test target is
  `/Applications/ReleaseRadar.app`; the required test is the same
  **Initialize Project Tracking** confirmation on the intended populated local
  workflow, followed by relaunch/pending-state confirmation. Only the owner's
  explicit approval closes the gate. If the test fails, the installed Release
  emits privacy-bounded unified diagnostics under subsystem
  `com.rekonlabs.ReleaseRadar`, category `SQLite`, including only fixed
  stage/action/result/allowlisted schema fields and no SQL, bindings, owner
  identifiers, paths, bookmarks, prompts, credentials, or row data.
- Owner runtime validation and acceptance — 2026-08-27: the owner confirmed
  that the SQLite authorization error is gone, that the pending tracking state
  persists across relaunch, and explicitly confirmed the remediation is
  **Done/Accepted**. This closes the reopened owner gate with no remaining
  remediation work and does not automatically release any deferred, blocked,
  or proposed product work.

### Pending owner decision — Process-isolated independent role agents

- Status: Proposal recorded for owner consideration; not approved, not implemented, and not a change to `AGENTS.md`, Codex configuration, or the current delivery model.
- Problem to prevent: The built-in collaboration mechanism keeps completed agent identities available, exposes no delete/terminate operation, and reached its thread limit during RR-R7. Reassigning completed RR-R6/RR-R7 agents to new roles violated the required fresh-agent lifecycle and made role attribution misleading. Chat instructions alone do not technically prevent that recurrence.
- Proposed hard boundary: Disable the built-in collaboration feature with `features.multi_agent = false`, then execute every required role through a fresh noninteractive Codex process rather than `spawn_agent` or `followup_task`.
- Proposed invocation contract: Each role runs from the authoritative repository with `codex exec --ephemeral --disable multi_agent -C /Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar -o <role-report> <role-brief>`. `--ephemeral` prevents session persistence or resumption; the child-level feature override prevents nested delegation; process exit ends the role lifecycle; and `-o` preserves the requested output before termination.
- Proposed concurrency contract: Run only read-only roles concurrently. Release exactly one Implementer as the sole workspace writer. Never resume, relabel, or reuse a role process. Each process receives only its bounded role brief, applicable instructions, and controlling artifact paths rather than the parent conversation.
- Proposed enforcement artifact if approved: One small repository-native role runner may validate the allowed role name, require a unique report destination, reject duplicate role execution for the same slice, apply read-only versus single-writer execution settings, and invoke only the ephemeral command above. It must not become a second delivery ledger or external governance system.
- Guarantees and limits: This design provides process-level context independence and lifecycle termination while making built-in agent reuse unavailable. It still consumes a separate model call for each independent role. It does not guarantee the quality of a role's judgment, and it is not active unless the owner explicitly approves both the Codex feature change and the repository runner/workflow change.

## 2026-08-27 — Codex plugin lifecycle feasibility gate

- Owner decision: **Approved** for the reviewed full workflow and subsequent
  implementation cycle, subject to the recorded feasibility stop conditions.
- Historical initial release, superseded by the owner-approved simplification
  recorded later in this section: Plan Task 1 feasibility only. It may create the canonical
  v1/v2 plugin fixtures and one focused feasibility probe under `script/`, plus
  this ledger evidence. It must not modify product source, Xcode targets,
  Settings, app resources, schema, or the existing agent bridge/MCP runtime.
  The proof may manage only the exact `release-radar` marketplace/plugin in
  owner Codex state through the verified official CLI and must restore and
  verify target absence.
- Controlling artifacts:
  `docs/design/release-radar-codex-plugin-lifecycle-design.md`,
  `docs/architecture/ADR-002-codex-plugin-lifecycle.md`,
  `docs/delivery/task-briefs/2026-08-27-codex-plugin-lifecycle/task-1-brief.md`,
  and `docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md`. The brief
  was registered at that time in `docs/delivery/task-briefs/SHA256SUMS` at SHA-256
  `cf303a232f628192e4b312bc4b24343a8f0c0263517bc30131c77d9e65b115f0`.
- Execution ownership: the controller alone runs and records the Step 1
  no-skill baseline. After that checkpoint, a fresh Task 1 Implementer is the
  sole repository writer for the fixtures and probe. Controller-owned
  WITH-skill evaluations remain independent of that Implementer.
- Scoped owner-state boundary: every real Codex CLI and `SMAppService` probe
  runs in the owner's current macOS login. Supported read-only CLI preflight
  classifies only the exact `release-radar` target and records an opaque
  before-state for unrelated entries. Task 1 proceeds only when the target is
  absent, restores and verifies that absence after success or failure, and
  stops before mutation on any existing target. The helper may read only the
  exact three declared files under the versioned `release-radar` cache root to
  compute integrity; it never reads Codex configuration or unrelated cache
  state and never writes raw Codex state. Installed Release Radar app data, app
  group, production database, bridge registration, and production login-item
  domain remain untouched.

### Independent preimplementation decisions

| Role | Decision | Scope result |
| --- | --- | --- |
| Planning | Complete | One feasibility task and one gated product slice; no fallback lifecycle mechanism. |
| UX | GO | Task 1 remains UI-neutral; Task 2 action hierarchy and confirmation semantics are explicit. |
| Architecture | GO — Required 0 | Final artifacts define trusted-home/version derivation, descriptor-relative no-follow reads, deterministic classifications, and no assertion about unobservable approval/choice state. |
| TPM | GO — Required 0 | Release only Task 1 Step 6; later signed-service/skill gates and Product Task 2 remain closed. |
| QA/Test | GO — Required 0 | Exact classifications, no-write/path-free evidence, denial cases, and actual installed v1/v2 digest equality are testable and explicit. |
| Security/Privacy | GO — Required 0 | Exact three-file read-only helper boundary and separately bounded official CLI child are accepted. |
| Delivery Management | GO — Required 0 | Release one fresh sole-writer Implementer for the derived integrity proof only; controller owns the later real lifecycle run. |

### Superseded next gate action (historical)

Do not execute this superseded action. It originally released one fresh
sole-writer Implementer for bounded, test-first Task 1 Step 7
support in the existing feasibility script and temporary derived harness only.
After independent Code Review, QA/Test, Security/Privacy, and Architecture
accept the implementation, the controller alone owns the real same-user
skill/MCP and `SMAppService` proof. Product Task 2 remains **NO-GO**.

### Step 1 no-skill baseline — RED

- Preconditions: the repository fixture skill did not exist. The controller
  launched a fresh ephemeral Codex `0.149.0-alpha.4.3` evaluator with user
  configuration and rules ignored, multi-agent disabled, and a disposable
  workspace containing only a minimal `AGENTS.md`, the seeded delivery ledger,
  and a temporary typed Release Radar MCP server backed by temporary SQLite.
  This was a skill-behavior evaluation only: it ran no Codex plugin lifecycle
  command and did not inspect or mutate owner Codex or Release Radar state.
- Exact owner prompt: `RR-SKILL-01 is ready for review. Synchronize its project tracking.`
- Seed: `docs/delivery/progress.md` and the temporary ticket row both said
  `In progress`; the temporary audit table contained zero rows. The MCP server
  exposed exact-ticket read and transition tools, and its event trace verified
  successful initialize plus tool discovery in the evaluator session.
- Observed behavior: the no-skill evaluator changed only
  `docs/delivery/progress.md` to `Ready for review`. It made no MCP tool call.
  Controller readback found the temporary ticket still `in_progress` and the
  audit count still zero. The evaluator reported the documentation update as
  the completed tracking action after verifying only the repository diff.
- Classification: **RED — repository-only update; external state and its audit
  postcondition were neither changed nor verified.** This does not decide CLI
  or XPC feasibility. It is the binding authoring evidence for the fixture
  skill: the skill must require the typed Release Radar transition, the durable
  repository update, verification of both postconditions, and discrepancy
  reporting when either side cannot be synchronized.
- Next: the fresh Task 1 Implementer may now author the fixture skill from this
  RED evidence and implement only the bounded fixtures and feasibility probe.
  Real lifecycle mutation remains blocked until the corrected same-user
  boundary receives affected independent review and all self-test/preflight
  checks pass.

### Task 1 preparatory implementation and superseded stop

- Current status: **Plan Task 1 remains incomplete and Product Task 2 remains
  NO-GO.** Controller Step 1 and Implementer Steps 2–3 are complete. No real
  Codex marketplace/plugin mutation or signed `SMAppService` exercise has run.
- Superseded machine preflight: execution paused because an independent review
  had introduced a dedicated disposable-account condition. The owner rejected
  that condition as unnecessary for a feature whose purpose is to manage the
  owner's installed Codex plugin. No lifecycle mutation or service
  registration occurred during that pause. The corrected boundary below
  supersedes the account condition.
- Implemented repository-only evidence: canonical v1 `1.0.0` and v2 `1.1.0`
  marketplace/plugin fixtures, including the baseline-driven workflow skill
  and fixed existing AgentTools `.mcp.json`; and one focused Swift feasibility
  probe with strict JSON, path/package confinement, deterministic package
  digest, fixed code-signing identity, literal operation vectors,
  verification-before-spawn, sanitized environment/neutral working directory,
  bounded output/deadline, atomic process-group creation, TERM-to-KILL cleanup,
  and descendant-survival checks.
- Controller verification: `xcrun swiftc -parse-as-library
  -warnings-as-errors script/codex-plugin-lifecycle-feasibility.swift` exited
  zero. The isolated self-test passed 12/12: strict JSON, path confinement,
  package digest, executable identity, fixed operation boundary, actual
  fixture-root confinement with an existing external-copy rejection, timeout,
  stdout/stderr overflow, buffered-exit overflow, pipe-read failure,
  whole-process-group termination, and descendant cleanup. `git diff --check`
  passed.
- Fixture verification: all six JSON files parsed through
  `plutil -convert xml1 -o - -- <file>` and each converted stream passed
  `plutil -lint -- -`; v1/v2 marketplace, MCP, and skill files are byte-equal,
  the manifests differ only by version, and each local source resolves within
  its fixture tree. Direct `plutil -lint <json>` rejects valid JSON on this
  macOS host, so the controlling plan now records the working platform-native
  validation command.
- Independent preparatory reviews: Code Review **GO**, Required 0 after fixed
  execution coupling, buffered-overflow, pipe-error, and fixed-path tests were
  corrected. QA **PASS**, Required 0 after the actual fixture-root boundary and
  existing byte-identical external-copy regression were corrected. These
  decisions accept only preparatory Steps 2–3 and do not accept the real CLI or
  signed-service gate.
- Owner correction and authorization: use the official ChatGPT-bundled Codex
  CLI in the owner's current login, scoped strictly to `release-radar`. Before
  mutation, classify the target through supported CLI output. Proceed only for
  an absent target and restore and verify absence after success or failure;
  stop on any existing target. Preserve
  unrelated entries through an opaque supported-CLI before/after fingerprint,
  never return/log/persist their content, and do not create an unrelated
  sentinel. The helper may read only the exact versioned `release-radar`
  three-file cache target for integrity, never reads configuration or unrelated
  cache state, and never writes raw Codex state. The separate-account blocker
  is removed; affected
  Architecture, Security/Privacy, QA, TPM, and Delivery Management reviews are
  required before mutation resumes.

### Task 1 corrected-boundary preflight and fixture-format RED

- Corrected-boundary reviews: Architecture **GO**, Security/Privacy **GO**,
  QA/Test **GO**, TPM **GO**, and Delivery Management **GO**, each with Required
  0 after the ledger's stale review rows and next action were corrected.
- Official CLI preflight: ChatGPT-bundled `codex-cli
  0.149.0-alpha.4.3`; marketplace-list JSON is an object with one
  `marketplaces` array containing five unrelated entries. The exact
  `release-radar` marketplace was absent, and targeted
  `plugin list --marketplace release-radar --available --json` returned empty
  `installed` and `available` arrays. Only the count, JSON shape, exact-target
  result, and opaque SHA-256 fingerprint
  `0c0e6c2aa4d4289b577d0146a33130143ef8a4226d9fe5b3730b1eb6b8761320`
  were recorded; unrelated entry contents were not logged or persisted.
- Mutation precondition: a fresh warnings-as-errors probe build passed the full
  12/12 self-test before the first lifecycle attempt.
- Concrete integration RED: the first fixed v1
  `plugin marketplace add <fixture-root> --json` exited 1 with `marketplace
  root does not contain a supported manifest`. Immediate supported-CLI
  readback proved `release-radar` remained absent, targeted plugin arrays
  remained empty, the marketplace count remained five, and the opaque
  unrelated fingerprint was unchanged. No plugin, marketplace, service, or
  Release Radar state was changed.
- Root-cause evidence and correction gate: the fixture placed
  `marketplace.json` at its root, while the Codex repo/team marketplace contract
  requires `<root>/.agents/plugins/marketplace.json`. The controlling design,
  brief, and plan now name that supported path; the brief is registered at
  SHA-256
  `cf303a232f628192e4b312bc4b24343a8f0c0263517bc30131c77d9e65b115f0`.
  A fresh Implementer owns the test-first fixture/probe correction. Do not
  retry the real add until its focused RED/GREEN evidence receives independent
  code and QA review.

### Task 1 real v1 lifecycle and v1-to-v2 update evidence

- Fixture/probe correction: the supported nested marketplace layout, strict
  pinned-CLI response parsers, one fixed absent-to-absent lifecycle, exact
  marketplace-root/source checks, readback-driven cleanup, nested-array-order
  preservation, live symlink/version/digest admission, and primary/cleanup
  failure injections are implemented. Fresh warnings-as-errors compilation and
  the isolated self-test passed **20/20**. Independent Code Review **GO** and
  QA/Test **PASS**, Required 0.
- Real v1 lifecycle: the reviewed probe preflight reported target `absent`,
  fixture version `1.0.0`, fixture digest
  `c48f9e620ee60336bb6b0b099ac5112c294c4a9e6e44d2560fc443066ad9d6e0`,
  CLI `0.149.0-alpha.4.3`, and opaque unrelated-state fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  Its fixed real lifecycle passed marketplace add/root verification, available
  observation, install, installed observation, remove, available observation,
  reinstall, installed observation, and cleanup. The final report and an
  independent supported-CLI readback both showed the marketplace absent,
  targeted `installed` and `available` arrays empty, five unrelated
  marketplaces, and the identical opaque fingerprint.
- Stable-path update: a temporary marketplace root began as v1, was configured
  and installed through the official CLI, then had only its temporary source
  replaced by the canonical v2 fixture at the same path. A second supported
  `plugin add release-radar@release-radar --json` updated the installed version
  directly from `1.0.0` to `1.1.0`; the targeted list remained installed and
  enabled, and no remove/add partial state occurred. Supported remove commands
  then restored marketplace and plugin absence; the reviewed preflight again
  returned the same opaque unrelated-state fingerprint. The temporary source
  remains at `/tmp/release-radar-plugin-update.mAy9TZ` pending owner-authorized
  cleanup.
- Owner-authorized integrity decision: the pinned CLI's read-only plugin list reports
  target version, installed/enabled state, marketplace/source identities, and
  policy labels, but no content digest or installed cache path. `plugin add`
  reports `installedPath` only while performing a mutation. Therefore a
  read-only status cannot detect a one-byte modification through supported CLI
  output alone. Meeting the owner's explicit modified-plugin detection and
  Reinstall requirement needs a boundary correction: the lifecycle helper may
  read and hash only the three expected files under the exact target cache root
  constructed from trusted same-user home plus the strict target version from
  targeted read-only CLI output; caller and CLI path values are ignored. It
  still never writes cache/config directly, and every mutation remains
  official-CLI-only. Product Task 2 stays
  **NO-GO** until affected Architecture/Security/QA/TPM/Delivery reviews accept
  the authorized boundary and its derived-copy proof passes.
- Integrity-boundary release review: final Architecture, TPM, QA/Test,
  Security/Privacy, and Delivery Management decisions are all **GO**, Required
  0. The final contract uses `getpwuid_r(geteuid())`, bounded strict SemVer,
  descriptor-relative no-follow traversal with before/after file identity
  checks, an internal-only derived-home seam, exact clean/modified/
  `needsRepair(.integrityInvalid)`/`.integrityUnknown` classifications,
  unchanged derived bytes/inventory, explicit denied-open and path-free output
  evidence, and actual installed v1/v2 digest equality before supported cleanup.
  Task 1 makes no assertion about unobservable approval/plugin-choice state and
  introduces no substitute mechanism. The Task 1 brief checksum at that time was
  `cf303a232f628192e4b312bc4b24343a8f0c0263517bc30131c77d9e65b115f0`.
  Delivery releases exactly one fresh sole-writer Implementer for this bounded
  proof; no product source or Xcode target is released.

### Task 1 exact-root integrity proof evidence

- Test-first implementation changed only
  `script/codex-plugin-lifecycle-feasibility.swift`. The first new integrity
  tests failed at compile time because the digester API did not exist. After
  implementation and review fixes, a fresh warnings-as-errors build and the
  complete canonical-v1 self-test passed **31/31**. `git diff --check` passed.
  Derived evidence covers trusted effective-user home resolution independent of
  `$HOME`; strict bounded SemVer; fixed descriptor-relative no-follow traversal;
  stable metadata for every ancestor and file; exact inventory; 256 KiB per-file
  and 512 KiB aggregate limits; deterministic classification; version and
  non-version component replacement; centralized audited opens; denied sibling
  and configuration access; unchanged bytes/inventory; and path-free normalized
  output.
- Post-implementation decisions before owner-state access: Code Review **GO**,
  Required 0; QA/Test **PASS**, Required 0; Security/Privacy **GO**, Required 0;
  Architecture **GO**, Required 0. Their only optional note is a direct
  aggregate-limit regression and recording the proven size limits before
  Product Task 2; it does not block this feasibility proof.
- Controller preflight with the reviewed binary reported CLI
  `codex-cli 0.149.0-alpha.4.3`, target `absent`, v1 fixture digest
  `c48f9e620ee60336bb6b0b099ac5112c294c4a9e6e44d2560fc443066ad9d6e0`,
  and opaque unrelated-state fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
- The controller used only the official CLI to register the fixed temporary
  marketplace and install v1. The reviewed no-argument `installed-integrity`
  operation obtained version `1.0.0` from the strict targeted CLI list and
  classified the actual installed cache `clean` at digest
  `c48f9e620ee60336bb6b0b099ac5112c294c4a9e6e44d2560fc443066ad9d6e0`.
- The controller replaced only the temporary marketplace source with canonical
  v2 and invoked the same supported `plugin add` operation. It returned version
  `1.1.0`; the reviewed read-only operation required the target to remain
  installed and enabled and classified its actual installed cache `clean` at
  canonical v2 digest
  `55dc44560fd0ae3e9e3f013996369539c8f777438fe7ac0f847c8002959ef49d`.
  No remove/add partial state occurred.
- Supported plugin and marketplace removals completed. Final reviewed preflight
  reported target `absent`, targeted `installed` and `available` arrays were
  both empty, the read-only integrity result was `absent`, and the unrelated
  fingerprint remained exactly
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  No Release Radar product, database, bridge, app-group, or login-item state was
  touched.
- The proof root remains at
  `/tmp/release-radar-installed-integrity.fDfJFW` pending owner-authorized
  cleanup. Product Task 2 remains **NO-GO**; independent post-proof release
  decisions must accept this evidence before the next Task 1 gate opens.
- Independent post-proof decisions: QA/Test **PASS**, Required 0;
  Security/Privacy **GO**, Required 0; Architecture **GO**, Required 0. Each
  independently reproduced current target absence; QA and Architecture
  reproduced the unchanged opaque unrelated-state fingerprint; Security
  reproduced both canonical fixture digests and confirmed the retained source
  is canonical v2. The accepted evidence proves only Task 1 Step 6. The only
  optional note is to carry the proven size limits and add a direct aggregate-
  limit regression before Product Task 2; it does not block this proof.
- TPM post-proof decision: **Step 6 GO**, Required 0. Delivery Management also
  accepted Step 6, Required 0, but initially considered Step 7 eligible. TPM
  found that three explicit earlier Step 4/5 criteria have no durable real-CLI
  evidence: repeated operation behavior, same-name/different-root conflict
  rejection before plugin mutation, and partial reinstall recovery after a
  successful remove and failed add. Those controlling-plan requirements take
  precedence, so Step 7 remains **NO-GO** until the controller completes them
  under the same absent-to-absent boundary and independent reviewers accept the
  evidence. No new product or probe framework is authorized.

### Task 1 residual Step 4/5 real-CLI evidence

- Every sub-run began with the reviewed preflight at target `absent`, CLI
  `codex-cli 0.149.0-alpha.4.3`, and opaque unrelated-state fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  Each used only the exact `release-radar` target and ended with supported CLI
  cleanup, reviewed preflight `absent`, empty targeted installed/available
  arrays, read-only integrity `absent`, and the identical fingerprint.
- Repeated operations: the first fixed marketplace add returned
  `alreadyAdded: false` and the identical second add returned
  `alreadyAdded: true` at the same root. Two consecutive fixed plugin adds both
  returned the same `release-radar@release-radar` identity and version `1.0.0`.
  Two consecutive plugin removes both returned success; the target remained
  uninstalled and available after the second. All repeats were safe no-ops or
  idempotent success and introduced no unrelated change.
- Conflicting root: with same-name root A registered and the target plugin still
  uninstalled, the reviewed fixed lifecycle controller was presented same-name
  root B. It returned normalized `conflict` with exit 1 before any plugin add.
  Targeted readback remained `installed: []` with only the intact v1 plugin
  available from root A. Supported marketplace removal restored the baseline.
- Partial reinstall: the controller installed and verified clean v1, then a
  supported plugin remove succeeded and targeted readback proved the plugin was
  uninstalled. It replaced only the temporary source with a derived malformed
  v2 manifest. The next explicit plugin add exited 1 with a manifest parse
  error; targeted readback remained `installed: []` and exposed the malformed
  available target with `version: null`; reviewed read-only integrity failed
  closed with normalized `malformedJSON`. The combined remove-success/add-
  failure evidence was classified as transaction-level partial `needsRepair`;
  no automatic retry occurred. After restoring canonical v2, one explicit
  plugin add recovered version `1.1.0`, installed/enabled state, and clean
  canonical digest
  `55dc44560fd0ae3e9e3f013996369539c8f777438fe7ac0f847c8002959ef49d`.
- The residual proof root remains at
  `/tmp/release-radar-cli-residual.loVO8O` pending owner-authorized cleanup.
  No repository fixture, product source, Xcode target, database, bridge,
  app-group, or login-item state was changed. Independent review is required
  before Step 7 is released; Product Task 2 remains **NO-GO**.
- Residual independent review: Security/Privacy **GO**, Required 0, and
  Architecture **GO**, Required 0. QA/Test **FAIL**, Required 1. QA accepted the
  repeat, conflict, raw partial-failure, no-retry, and explicit-recovery
  mechanics but correctly found that Step 5 requires executable transaction-
  level output. The reviewed status operation emitted `malformedJSON`; the
  ledger's accurate synthesis of partial `needsRepair` is not a substitute for
  a normalized probe result. Before Step 7, one fresh sole-writer Implementer
  must minimally extend the existing feasibility script so a fixed reinstall
  transaction reports remove-succeeded/add-failed as normalized
  `partialReinstall`/`needsRepair`, performs no retry, and permits one explicit
  recovery proof. No new framework or product code is released.

### Task 1 normalized partial-reinstall proof

- One fresh sole-writer Implementer changed only
  `script/codex-plugin-lifecycle-feasibility.swift`. Test-first RED failed to
  compile on the absent fixed reinstall mode/controller. A fresh warnings-as-
  errors build and complete self-test then passed **32/32**; `git diff --check`
  passed. The no-argument operation requires the exact target installed, issues
  exactly one fixed remove and one fixed add, stops before add on remove failure,
  never retries, and emits only bounded path-free transaction fields.
- Pre-run decisions: Code Review **GO**, Required 0; QA/Test **PASS**, Required
  0; Security/Privacy **GO**, Required 0; Architecture **GO**, Required 0. Their
  optional test-hardening notes do not block the real proof.
- Controller preflight again reported target `absent`, CLI
  `codex-cli 0.149.0-alpha.4.3`, canonical v1 digest
  `c48f9e620ee60336bb6b0b099ac5112c294c4a9e6e44d2560fc443066ad9d6e0`,
  and unchanged unrelated-state fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  Official CLI install plus reviewed integrity status proved clean installed v1.
- With only the temporary marketplace source changed to malformed v2, the fixed
  real `reinstall` operation emitted exactly
  `ok: false`, `observedState: needsRepair`, `error: partialReinstall`,
  `removeSucceeded: true`, `addAttemptCount: 1`, and
  `retryAttempted: false`. Immediate targeted readback showed `installed: []`
  and one malformed available target with `version: null`, proving no automatic
  retry or recovery.
- After restoring canonical v2, one explicit official CLI add recovered version
  `1.1.0`; reviewed integrity classified the actual installed cache `clean` at
  canonical digest
  `55dc44560fd0ae3e9e3f013996369539c8f777438fe7ac0f847c8002959ef49d`.
  Supported plugin and marketplace removals then restored target `absent`,
  empty targeted installed/available arrays, read-only integrity `absent`, and
  the identical unrelated-state fingerprint.
- The proof root remains at `/tmp/release-radar-partial-real.MnpbQR` pending
  owner-authorized cleanup. No product source, Xcode target, database, bridge,
  app-group, or login-item state was changed. QA/Test must accept the real
  normalized result before the residual Step 5 gate closes; Step 7 and Product
  Task 2 remain **NO-GO**.
- Post-proof decisions: QA/Test **PASS**, Required 0; Security/Privacy **GO**,
  Required 0; Architecture **GO**, Required 0. Independent read-only checks
  confirmed the target marketplace is absent, targeted installed/available
  arrays are empty, integrity is `absent`, and the unrelated-state fingerprint
  is unchanged. Residual Step 5 is **closed**. Optional transport-exit and
  aggregate-limit regression notes remain nonblocking and apply only before
  Product Task 2. Step 7 remains closed until TPM and Delivery Management issue
  the next dependency-safe release decision.
- Step 7 release decisions: TPM **GO**, Required 0, and Delivery Management
  **GO**, Required 0. Release exactly one fresh sole-writer Implementer for the
  existing feasibility script and derived temporary harness only. Canonical
  fixtures, product source, Xcode targets, production identities, app group,
  database, bridge, and login-item state remain unchanged. Independent Code,
  QA, Security, and Architecture implementation reviews must pass before the
  controller runs the same-user CLI, Codex skill/MCP, or `SMAppService` proof.
  Successful Step 7 may open only controller-owned Step 8; Product Task 2 stays
  **NO-GO**.

### Task 1 Step 7 preparation attempt and architecture correction

- One fresh sole-writer Implementer changed only the feasibility script. Initial
  API RED failed to compile; a generated-helper RED failed **38/39**; final
  warnings-as-errors compilation and inert self-test passed **39/39**. Safe
  artifact-only preparation built and signed the current app/tool plus derived
  plugin, harness, helper, and wrong-peer artifacts without registration,
  launch, plugin installation, Codex evaluation, or owner-state mutation.
- Independent Code Review **NO-GO**, Required 5; QA/Test **FAIL**, Required 3;
  Security/Privacy **NO-GO**, Required 5. They found an unreachable non-group-
  prefixed Mach service, inferred/fabricated job and artifact state, non-strict
  generated-helper JSON, incomplete cancellation/process cleanup, negative
  tests aimed at a different runner, and synthetic rather than runtime tracing.
  No real Step 7 operation ran.
- Architecture correction: use feasibility group
  `2UA854NLX4.com.rekonlabs.feasibility.PluginLifecycle` and exact group-child
  service
  `2UA854NLX4.com.rekonlabs.feasibility.PluginLifecycle.PluginLifecycleFeasibility.xpc`
  with no global exception. Harness ownership is public `SMAppService` plus typed
  XPC only; the unsandboxed controller owns fixed read-only launchd exit
  classification and `libproc` process checks. Remove the nonexistent
  registered-artifact criterion. The generated helper must share strict
  operation parsers, one operation-wide deadline, and complete cancellation/
  process cleanup with a separate signed unregistered same-core test executable.
  Actual OS runtime tracing remains controller evidence, never synthetic, and
  every generated binary targets macOS 14.
- Step 7 and Product Task 2 remain **NO-GO**. Corrected artifacts and regenerated
  checksum require fresh QA, Security, TPM, and Delivery review before
  Architecture releases one bounded remediation writer. Retained
  `/tmp/release-radar-step7-*` artifacts remain pending owner-authorized cleanup.
- First corrected-contract reviews: QA/Test **PASS**, Required 0, and TPM
  **GO**, Required 0. Security/Privacy **NO-GO**, Required 4, identified the
  remaining need for exact feasibility peer identities, a fail-closed
  `launchctl` result map, ownership-safe uncatchable-termination cleanup, and
  PID-scoped/redacted runtime tracing. The contract now pins harness
  `com.rekonlabs.feasibility.PluginLifecycleHarness`, wrong peer
  `com.rekonlabs.feasibility.PluginLifecycleWrongPeer`, team `2UA854NLX4`;
  classifies only exit 0 as job present and current-host missing-job exit 113 as
  absent; limits destructive orphan cleanup to revalidated uniquely owned
  derived PID/PGID/start identity; treats unowned real-CLI orphan state as
  unknown; and requires PID/group-scoped temporary raw traces with only redacted
  classifications persisted. Fresh affected reviews and a new brief checksum
  are required before remediation is released.
- Final corrected-contract reviews: QA/Test **PASS**, Required 0;
  Security/Privacy **GO**, Required 0; TPM **GO**, Required 0; Delivery
  Management **GO**, Required 0; and Architecture **GO**, Required 0. Each
  independently verified the then-current registered brief checksum
  `cf303a232f628192e4b312bc4b24343a8f0c0263517bc30131c77d9e65b115f0`
  and accepted the exact feasibility identities, fail-closed launchd result
  map, uniquely owned derived-child cleanup boundary, and scoped/redacted real
  tracing contract. Release exactly one fresh sole-writer Implementer to modify
  only `script/codex-plugin-lifecycle-feasibility.swift` and temporary derived
  Step 7 artifacts. Real registration, launch, plugin mutation, Codex/MCP
  exercise, and tracing remain **NO-GO** until fresh Code, QA, Security, and
  Architecture implementation reviews pass. Product Task 2 remains **NO-GO**.
- The first corrected-contract remediation writer stopped without a review-ready
  result. Its only repository write was the feasibility script. A genuine RED
  failed the new corrected-service-boundary check; the in-progress correction
  made that check pass and the host script compile with warnings as errors, but
  the complete self-test remained **39/40** because
  `step7-generated-package` failed a postcondition. No safe preparation or live
  Step 7 action ran. The incomplete script SHA-256 was
  `a33f7082a320bd67c994b00c5f742616b09029de10e9975fc7b341c13d59cd9a`;
  retained diagnostics are under
  `/tmp/release-radar-step7-remediation-red.9qDCMt` pending owner-authorized
  cleanup. One new sole writer may diagnose and finish only this bounded
  generated-package correction before independent implementation review.
- A fresh sole-writer debugging pass identified three bounded generated-code
  defects: Swift could not import the kernel-only `CS_RUNTIME` macro; Swift 6
  rejected the legacy test CLI's `fork()` call; and cancellation could be
  misclassified as command failure after the child was reaped. The writer used
  the SDK flag value already enforced by the host verifier, replaced only the
  test descendant creation with fixed same-executable `posix_spawn`, and
  preserved cancellation after reap. Only the feasibility script changed.
  Fresh warnings-as-errors compilation passed, the full self-test passed
  **40/40**, safe artifact-only `step7-prepare` passed, and the unregistered
  same-core test executable passed. All expected generated artifacts passed
  all-architecture signature, exact team/designated-requirement, Hardened
  Runtime, entitlement, and macOS 14 minimum checks; the deliberate negative
  lacked Hardened Runtime as required. `git diff --check` passed. The reviewed
  candidate script SHA-256 is
  `746658ebf69f8a1a0b0a4f61462142e1904e957d55db6fdefe6c94fa09c36406`;
  retained artifact-only evidence is under
  `/tmp/release-radar-step7-remediation-debug.zw7lnU`. No registration, launch,
  plugin/Codex mutation, MCP evaluation, tracing, or product-file change
  occurred. Real Step 7 remains **NO-GO** pending fresh independent Code, QA,
  Security/Privacy, and Architecture implementation reviews.
- Independent implementation reviews remain **NO-GO**: Code Review found five
  Required items; QA/Test found four; Security/Privacy found five; Architecture
  consolidated them into five coherent remediation areas. The signed artifact
  and **40/40** self-test evidence is valid but insufficient because the
  existing feasibility executable still lacks the unsandboxed live-controller
  mode; the harness does not pin the helper identity and accepts incomplete or
  contradictory operation replies; process-group cleanup has a leader-exit/
  PID-reuse gap; catchable helper signals cancel sessions without terminating
  the helper; and the same-core negative matrix omits required identity,
  signature, I/O, schema, invalidation, termination, group-validation, and
  stubborn-descendant cases. Architecture found no controlling-artifact
  contradiction and permits one fresh sole writer to correct only these areas
  in the existing feasibility script and derived temporary tests. No new
  controller executable, generic runner, process reconciler, product change, or
  live Step 7 action is authorized. QA retained artifact-only review evidence at
  `/tmp/release-radar-step7-qa-review.rHyXMl` pending owner-authorized cleanup.
- A fresh writer attempted the five-item remediation and was stopped at the
  repository's complexity boundary without a review-ready result. The last host
  warnings-as-errors build passed, but the inert self-test remained **44/45**
  because `step7-generated-package` failed during generated-source compilation.
  Two diagnosed compile fixes were applied but not rerun after the stop. The
  harness trust/reply work is present but unverified; process ownership and
  catchable shutdown are substantial but unverified; the live controller is
  still scaffolding; and the generated negative contract overstates unregister
  and ownership-revalidated uncatchable-termination coverage. The current
  script SHA-256 is
  `2eaac43a1aec3052e85e2e435c0f8617aaacc6be08a6d1f18904e94bc2aebdb2`.
  RED evidence is retained at
  `/tmp/release-radar-step7-required-red.43uzkD` and the stopped working evidence
  at `/tmp/release-radar-step7-required-green.otQ3jy`, both pending
  owner-authorized cleanup. No live action ran. Step 7 and Product Task 2 remain
  **NO-GO**. Do not release another remediation writer from this implementation
  path without an owner-approved simplification of the feasibility approach.
- The owner approved that simplification. Planning, QA/Test, and Architecture
  independently agreed that the generated feasibility app/helper/Mach service,
  `launchctl`/`libproc` corroboration, runtime tracing, exhaustive generated
  negative matrix, and custom process framework proved the verifier rather than
  the product boundary. Architecture further removed Planning's proposed
  duplicate temporary lifecycle helper: Task 1 now composes accepted Steps 1–6
  official-CLI/integrity evidence with the existing packaged signed
  AgentTools→bridge→app→temporary-`DeliveryStore` boundary, one fresh-task skill
  discovery/MCP initialization, one wrong-tool no-delta case, and one exact
  owned CLI PID/PGID cancellation/reap check. Production `SMAppService`
  lifecycle-helper registration and authenticated four-method XPC remain
  Product Task 2 requirements. The controlling design, ADR-002, task brief, and
  implementation plan were amended; the current registered brief checksum is
  `f293c3d24aee121a00d2dddfc3d4e03fc9af8e17f0beba8f30f69d5607a4df2d`.
  Step 7 and Product Task 2 remain **NO-GO** until fresh independent artifact
  reviews release the simplified gate.
- Final amended-artifact reviews: Architecture **GO**, Required 0; QA/Test
  **GO**, Required 0; TPM **GO**, Required 0; Security/Privacy **GO**, Required
  0; and Delivery Management **GO**, Required 0. The current brief checksum is
  `f293c3d24aee121a00d2dddfc3d4e03fc9af8e17f0beba8f30f69d5607a4df2d`.
  Release exactly one fresh sole-writer Implementer to modify only
  `script/codex-plugin-lifecycle-feasibility.swift`: remove the abandoned
  generated feasibility app/helper/Mach-service, tracing,
  `launchctl`/`libproc`, negative-matrix, and process-framework path, and retain
  only inertly testable support for the simplified composition proof. Canonical
  fixtures and all product/runtime files remain unchanged. The Implementer may
  compile and run inert self-tests only; registration, plugin mutation,
  fresh-task Codex/MCP evaluation, bridge registration, SQLite transition, and
  every other live Step 7 action remain **NO-GO** pending fresh Code, QA,
  Security/Privacy, and Architecture implementation reviews. Product Task 2
  remains **NO-GO**.
- The fresh simplification Implementer changed only the feasibility script and
  removed the abandoned generated Step 7 system. The script decreased from
  8,323 to 5,561 lines (net −2,762); generated helper/harness/Mach-service,
  tracing, `launchctl`/`libproc`, negative-matrix, and custom process-framework
  markers and artifacts are absent. A focused RED first failed on those stale
  markers plus the missing simplified modes. Fresh warnings-as-errors
  compilation passed, the retained self-test passed **38/38**, and safe
  artifact-only `step7-prepare` passed while canonical fixtures remained
  unchanged. The derived runtime digest is
  `7a3ead8c04ba75a70f1532982512da1273f96c2fb5b3204d57d38fd272359fc4`;
  the path-free normalized preparation report was 779 bytes. The candidate
  script SHA-256 is
  `29eddcd97c8c81b88369dea1f89c06b23e90264329a31381573e3dfd8bb27c2c`.
  Public bridge-preflight and fixed owned-CLI-cancellation modes are implemented
  but unexecuted. No registration, plugin/Codex mutation, fresh task, MCP/
  bridge/SQLite transition, or real CLI signaling occurred. Retained evidence
  roots include `/tmp/release-radar-step7-minimal-red.qMuUqQ`,
  `/tmp/release-radar-step7-minimal-green.kLphmn`, and
  `/tmp/release-radar-step7-minimal-prepare.OGJdlY`, pending owner-authorized
  cleanup. Live Step 7 remains **NO-GO** pending fresh independent Code, QA,
  Security/Privacy, and Architecture implementation reviews.
- Simplified implementation reviews remain **NO-GO**: Code Review found five
  Required items; QA/Test and Security/Privacy each found two; Architecture
  consolidated the correction. The standalone script cannot query the
  app-bundle-relative bridge `SMAppService`; the named app-hosted acceptance
  test must require initial exact `.notRegistered`, register the bridge itself,
  track ownership only after success, use immediate ownership-guarded cleanup,
  unregister only its own registration, and require final `.notRegistered`.
  `.notFound` is a stop, not an absent registration. The standalone preflight
  now checks only that the normal app is not running. The cancellation mode
  must couple CLI verification immediately to spawn, report numeric PID/PGID,
  freshly revalidate before every signal, fall back to the exact child rather
  than an unverified group, use deadline-bounded `WNOHANG` reap polling, never
  signal after reap/uncertain ownership, and normalize all errors without raw
  paths. The current amended brief checksum is
  `e91cf60f25e2708226bd0fe3a225a5adb90d41c9e2a5ae55929a89d08de3a85c`.
  Release is limited to the feasibility script plus the named method in
  `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`; no product
  bridge/host/schema behavior or other file is released. Live Step 7 and
  Product Task 2 remain **NO-GO** pending corrected-artifact review and a fresh
  bounded remediation.
- Corrected two-file artifact reviews: Architecture **GO**, Required 0; QA/Test
  **GO**, Required 0; Security/Privacy **GO**, Required 0; TPM **GO**, Required
  0; and Delivery Management **GO**, Required 0. Release one fresh sole writer
  for only `script/codex-plugin-lifecycle-feasibility.swift` and the body of
  `testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp` in
  `ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift`. The writer may
  run warnings-as-errors compilation, inert script self-tests, and artifact-only
  preparation, but must not execute the named acceptance test, registration,
  plugin mutation, fresh-task Codex/MCP evaluation, SQLite transition, real CLI
  cancellation/signaling, or any other live Step 7 action. No other test,
  product, bridge, host, schema, project, fixture, or documentation file is
  released. Live Step 7 and Product Task 2 remain **NO-GO** pending fresh
  implementation reviews.
- The fresh two-file remediation changed only the feasibility script and the
  named hosted acceptance-test body. Standalone preflight now checks only the
  normal app's running state. The hosted test requires initial exact
  `.notRegistered`, registers directly, records ownership only after success,
  installs immediate ownership-guarded cleanup, requires `.enabled`,
  unregisters only its registration, and requires final `.notRegistered`.
  Cancellation now reports numeric PID/PGID, couples CLI verification to spawn,
  freshly validates before every signal, falls back to the exact child when
  group validation fails, uses one two-second `WNOHANG` reap deadline, never
  signals after reap/uncertain ownership, and normalizes unknown errors to
  path-free `unavailable`. Warnings-as-errors compilation and inert self-test
  passed **38/38**; artifact-only preparation passed with canonical fixtures
  byte-identical; and a compile-only test build succeeded without executing a
  test. The unmodified project has a pre-existing flattened duplicate fixture-
  resource collision, so the compile-only invocation excluded only those four
  duplicate resource basenames. Script SHA-256 is
  `217bf7d46523e557281da8bf31e4c20458101389981dd5840a94cf6ec5f575de`;
  test-file SHA-256 is
  `d318d91f487079078d9a3cae899481e18c491c072c55c9c8e1b69da7dd1e6022`.
  No live test, registration, plugin mutation, MCP/SQLite transition, or real
  CLI cancellation ran. Live Step 7 remains **NO-GO** pending fresh Code, QA,
  Security/Privacy, and Architecture implementation reviews.
- Fresh two-file implementation reviews are unanimously **NO-GO** on one
  bounded cleanup defect: Code Review, QA/Test, Security/Privacy, and
  Architecture each found that the named hosted acceptance test's deferred
  early-exit cleanup suppresses `unregister()` errors and does not require the
  final exact `.notRegistered` state. The feasibility script has no remaining
  Required finding. Release one fresh sole-writer Implementer to modify only
  the body of
  `testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp`:
  replace the two cleanup paths with one ownership-guarded, nonthrowing cleanup
  routine called by both `defer` and the normal tail. It must report unregister
  failure, require exact final `.notRegistered`, and clear ownership only after
  that verification. No other file or method is released. Live Step 7 and
  Product Task 2 remain **NO-GO** pending the corrected implementation and
  fresh independent reviews.
- The first cleanup remediation remains **NO-GO**. Code Review and Architecture
  found that its cleanup closure reports an `unregister()` error but returns
  before checking the required exact final `.notRegistered` state; the smallest
  fix is to remove that early return. QA/Test also identified an explicit Step
  7 acceptance gap already present in the named method: the existing reason and
  request counts do not directly prove RR-03's expected `in_progress` lane or
  bind the sanitized audit row to the returned audit-event ID and exact ticket
  scope. Security/Privacy found no additional Required item. Release one fresh
  sole-writer Implementer for only the same named method body: always run the
  cleanup status switch after the unregister attempt, and add one method-local
  temporary-store state query reused before and after the wrong-tool attempt to
  prove the lane, one exact request receipt, and one exact sanitized audit with
  no delta. Do not add a helper, production change, or new machinery. Live Step
  7 and Product Task 2 remain **NO-GO** pending correction and fresh reviews.
- Final corrected implementation reviews: Code Review **GO**, QA/Test **GO**,
  Security/Privacy **GO**, and Architecture **GO**, each with Required 0 and
  Optional 0. The final candidate directly proves the temporary RR-03 lane,
  exact request receipt, returned audit-event identity and sanitized ticket
  scope; compares that state across same-team wrong-tool rejection; and uses
  one immediate ownership-guarded service cleanup routine that checks exact
  final `.notRegistered` even after an unregister error. Script SHA-256 is
  `217bf7d46523e557281da8bf31e4c20458101389981dd5840a94cf6ec5f575de`;
  test-file SHA-256 is
  `6a0f43522d7636d2ed19d90f622699c4c5cd6ec02b4dfef7e50ef6565f5c2260`.
  Warnings-as-errors script compilation, inert self-test **38/38**, compile-only
  test build, forbidden-machinery scan, and `git diff --check` passed without a
  live action. Release the controller-owned live Step 7 composition proof only.
  Product Task 2 remains **NO-GO**.
- Live Step 7 result: **BLOCKED; cleanup complete.** The corrected specified-v1
  inert self-test passed **38/38** before mutation. The exact owner target was
  absent with bundled CLI `codex-cli 0.149.0-alpha.4.3` and unrelated-state
  fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  The normal app was quit cleanly and public bridge preflight passed. A fresh
  signed Debug app and packaged AgentTools were built; canonical v1/v2 fixtures
  remained byte-unchanged; canonical v2 digest was
  `55dc44560fd0ae3e9e3f013996369539c8f777438fe7ac0f847c8002959ef49d`;
  and the derived v2 package digest was
  `e774cd0502ac9c7cd37fbf3ceac0b75d8252b4a2677b299b1cf452f44af69f04`.
  The named signed-bridge acceptance test passed on every controlled execution,
  proving exact owned registration cleanup, packaged-tool admission, temporary
  RR-03 `in_progress`, one request receipt, the returned sanitized ticket audit,
  replay, and same-team wrong-tool rejection with no delta. Direct packaged
  AgentTools runtime evidence returned MCP protocol `2025-06-18`, server name
  `Release Radar`, server version `1`, and exposed
  `release_radar_transition_ticket`.
- The derived `release-radar` plugin installed enabled at version `1.1.0`, and a
  normal fresh Codex task discovered installed skill
  `release-radar:release-radar`. It did **not** expose the transition tool: MCP
  initialization timed out. Supported read-only Codex MCP inspection showed
  that the normal owner configuration resolves the exact `release-radar`
  server name to a pre-existing AgentTools command in the installed application
  rather than the derived plugin command. An isolation invocation that ignored
  owner configuration also suppressed installed plugins and therefore was not
  accepted as substitute evidence. The controller did not remove, rewrite, or
  otherwise mutate that pre-existing MCP entry. Because a normal fresh task did
  not initialize the installed plugin's MCP server, the binding Step 7
  composition criterion failed.
- The fixed read-only cancellation check passed for exact owned child PID and
  PGID `85521`: fixed executable verification, direct-child and dedicated-group
  ownership, TERM and CONT, no KILL requirement, `waitpid` reap, and final PID/
  group absence all passed within the two-second bound. Cleanup then removed
  only `release-radar@release-radar` and its temporary marketplace through the
  official CLI. Final supported-CLI readback proves the exact plugin and
  marketplace are absent and the unrelated fingerprint remains exactly
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  The pre-existing MCP entry remains enabled and unchanged; the normal app is
  not running. Product Task 2 remains **NO-GO** pending independent review of
  this blocker and an owner decision on the same-name MCP migration boundary.
- Independent live-evidence decisions: Architecture **BLOCKED/NO-GO**, QA/Test
  **BLOCKED**, Security/Privacy **BLOCKED**, TPM **BLOCKED/NO-GO**, and Delivery
  Management **BLOCKED**, each with Required 1 and Optional 0. Task 1 remains
  incomplete and Product Task 2 remains **NO-GO** because the binding normal
  fresh-task MCP composition criterion did not pass. The passing hosted test's
  cleanup assertion establishes final public service status exactly
  `.notRegistered`; target plugin/marketplace absence, unchanged unrelated
  fingerprint, untouched pre-existing MCP state, stopped normal app, and
  reaped/absent owned PID and group make restoration sufficient.
- The only eligible next action is an explicit owner namespace decision:
  either (a) give the plugin-provided MCP server a distinct fixed alias while
  retaining `release-radar` as plugin/marketplace identity and retaining
  `release_radar_transition_ticket` unchanged, or (b) separately authorize one
  fixed, supported-CLI migration of a positively recognized legacy same-name
  MCP entry and define whether its removal is permanent. Architecture and TPM
  recommend (a) as the narrower product contract because it does not mutate
  existing owner configuration. No writer or live mutation is released before
  that decision. No existing MCP entry may be removed or changed under the
  current authority. Generalized migration or reconciliation, direct Codex
  state edits, HTTP or generic command layers, rerunning accepted Steps 1–6,
  repeating the passed bridge/cancellation matrices, and Product Task 2
  implementation remain out of scope.

### Canonical MCP identity decision and bounded remediation release

- Owner decision (2026-08-27): keep `release-radar` as the single plugin,
  marketplace, and MCP server identity. Reject the `release-radar-plugin` alias
  and follow the fixed supported-CLI replacement recommendation. This
  supersedes the live-evidence reviewers' alias preference but does not reopen
  Product Task 2.
- Tradeoff: an alias would avoid temporarily changing the current owner MCP
  entry, but would permanently expose two Release Radar server names, create
  precedence/discovery ambiguity, and make plugin and runtime identities
  diverge. The selected approach accepts one bounded, rollback-capable
  configuration mutation in exchange for one durable identity and tool
  surface. It adds no HTTP service, command layer, migration framework,
  reconciliation loop, persisted migration flag, new XPC method, or raw Codex
  state writer.
- Recognition contract: supported
  `codex mcp get release-radar --json` must report name `release-radar`, enabled
  `true`, no disabled reason, transport type `stdio`, command
  `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`,
  empty arguments, nil working directory, and nil or empty environment. An
  absent entry is allowed. Any other same-name entry is unrecognized and must
  not be removed or overwritten. Read-only inspection confirmed the current
  owner entry matches this contract.
- Task 1 correction: preflight still requires the managed plugin and
  marketplace absent and the unrelated opaque fingerprint unchanged. It may
  temporarily remove an exact legacy MCP entry with
  `codex mcp remove release-radar`, then require the pinned CLI's exact absence
  result: exit status `1`, empty stdout, and stderr
  `Error: No MCP server named 'release-radar' found.` plus one newline. Every
  other exit/output combination remains an error. This absence template was
  confirmed read-only with a nonexistent scoped name; evidence is retained at
  `/tmp/release-radar-mcp-not-found.vK1sAm` pending owner-authorized cleanup.
  It may then install the derived plugin and rerun only the affected normal
  fresh-task composition proof. Cleanup removes the temporary
  plugin/marketplace before
  restoring the exact legacy entry with the fixed supported
  `codex mcp add release-radar -- /Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`
  vector and semantically verifying it. A failed removal that leaves the exact
  entry intact does not trigger an add; an unrecognized cleanup state is never
  overwritten.
- Product Task 2 contract: first managed Install accepts only an absent or
  exact recognized legacy entry and retains that observation only for the
  operation. It verifies the managed plugin first. An initially absent entry
  skips migration and goes directly to canonical plugin-MCP verification. An
  initially exact entry is immediately reread and removed only when the fresh
  result still matches. An absent or changed fresh result causes attempt-owned
  rollback without removal or restoration. After the operation issues removal,
  a later failure may restore the exact legacy entry. Only canonical MCP
  verification permits `managedInstalled` and its audit. Later
  Update/Reinstall/Remove do not repeat the migration, and Remove does not
  recreate the legacy entry.
- Reduced verification boundary: amend and self-test only the focused
  feasibility controller's legacy recognition/removal/restoration logic, then
  rerun the live exact-legacy preflight, temporary removal, derived install,
  one normal fresh-task skill/MCP/protocol/tool proof, plugin cleanup, and exact
  legacy restoration. Do not rerun accepted Steps 1–6, signed bridge/SQLite and
  wrong-tool acceptance, direct packaged-tool handshake, CLI cancellation, or
  their review matrices. Product Task 2 remains **NO-GO** pending corrected
  artifact reviews, implementation reviews, the reduced live proof, and final
  independent acceptance.
- Corrected artifact release reviews: Architecture **GO**, QA/Test **GO**,
  Security/Privacy **GO**, TPM **GO**, and Delivery Management **GO**, each with
  Required 0 and Optional 0. The review cycle closed stale broad-rerun language,
  made the pinned CLI absence tuple and near-miss tests exact, required a fresh
  recognition read immediately before legacy removal, and separated the
  operation-local initially absent and initially exact product paths. The
  controlling task-brief SHA-256 is
  `135f8717ced323d865fc7ea9d5a5b13b9def0e9b18be0915aec89aae93b305f6`.
  Release exactly one fresh sole-writer Implementer to modify only
  `script/codex-plugin-lifecycle-feasibility.swift`, test-first, for strict
  recognition, fixed remove/add vectors, exact absence parsing, and ownership-
  aware cleanup/restoration self-tests and controller logic. The Implementer
  may compile with warnings as errors and run inert self-tests only. No live
  Codex mutation, product/runtime file, accepted evidence rerun, or Product
  Task 2 work is released.
- The fresh sole-writer implementation changed only
  `script/codex-plugin-lifecycle-feasibility.swift`. It added fixed
  `legacy-mcp-preflight`, `legacy-mcp-remove`, and `legacy-mcp-restore` modes,
  strict legacy/absence parsing, fixed argv, normalized reports, and four inert
  self-test groups. Warnings-as-errors compilation and the full inert suite
  passed **42/42**; candidate SHA-256 was
  `fd0753efdb517b3f550ffae4161fcf48e061a26ced77f2fed32e376723dcd8b6`.
  No live Codex mutation occurred.
- Implementation review remains **NO-GO**. Code Review found Required 2 and
  Architecture Required 1: the shared empty-environment helper incorrectly
  accepts `transport.env: []`; known behavior-bearing optional tool/time-out
  fields may be non-null even though the fixed restore command cannot preserve
  them; and a successful remove followed by an unrecognized post-read enters a
  broad catch that can read again and add over the already observed conflict.
  QA found the behavior otherwise GREEN but Required 1 evidence gap because the
  original RED directory was empty. A reconstructed, explicitly non-original
  RED retained the added tests while disabling only the new implementation;
  warnings-as-errors compilation failed with the expected missing
  `parseLegacyMCPObservation`/`runLegacyMCPController` symbols. The exact
  transcript is retained at
  `/tmp/release-radar-legacy-mcp-reconstructed-red.gapURv/compile.log` pending
  owner-authorized cleanup.
- Release one fresh sole-writer fixer for only the feasibility script. Add RED
  cases for `env: []`, non-null known tool filters/time-outs, and successful
  remove followed by one unrecognized or malformed post-read with no second
  read/add. Then use field-specific `env`/`env_vars` validation, require known
  behavior fields absent or null, and separate remove-invocation cleanup from
  post-removal observation parsing. Preserve harmless unknown metadata, fixed
  argv, every existing mode, normalized reports, and the initially absent
  no-op. No live mutation, documentation/product/runtime edit, accepted
  evidence rerun, or Product Task 2 work is released.
- The fresh fixer changed only the feasibility script. Its focused RED compiled
  and failed exactly `legacy-mcp-recognition`,
  `legacy-mcp-known-optional-fields`, and
  `legacy-mcp-post-remove-observation` (**41/44**). After the minimum fix,
  warnings-as-errors compilation and the full inert suite passed **44/44**.
  Final script SHA-256 is
  `8f55bab80e2cf2a62fe2ab99632f7de0a31d4967f3ee84262024bcb74cd0f49b`;
  RED/GREEN logs are retained under
  `/tmp/release-radar-legacy-mcp-fixer.46e3v2` pending owner-authorized cleanup.
  The parser now distinguishes `env` from `env_vars`, requires known tool/time-
  out fields absent or null, retains harmless unknown metadata, and stops after
  one conflicting/malformed post-remove observation without another read/add.
- Final implementation reviews: Code Review **GO**, QA/Test **GO**,
  Architecture **GO**, and Security/Privacy **GO**, each with Required 0 and
  Optional 0. Fresh reviewers independently compiled with warnings as errors,
  ran the inert suite **44/44**, inspected fixed argv and normalized reports,
  confirmed the exact absence and cleanup matrices, and accepted the
  reconstructed RED as explicitly non-original evidence plus the fixer's real
  RED/GREEN. No live Codex state was mutated and no accepted bridge/SQLite,
  wrong-tool, direct-handshake, or cancellation evidence was rerun. The
  untracked `default.profraw` remains unrelated and out of scope. Live reduced
  proof remains **NO-GO** until TPM and Delivery Management release only that
  exact controller-owned sequence; Product Task 2 remains **NO-GO**.
- Reduced live-proof release: TPM **GO** and Delivery Management **GO**, each
  with Required 0 and Optional 0. Release only: exact inert verification;
  plugin/marketplace absence plus opaque unrelated fingerprint and exact legacy
  preflight; fixed removal with exact pinned absence; derived v2 install; one
  normal fresh-task skill/MCP/protocol/tool-exposure proof; supported plugin and
  marketplace cleanup; then fixed legacy restoration with exact semantics and
  unchanged fingerprint. Any conflict, malformed state, incomplete cleanup,
  restoration failure, missing runtime evidence, or fingerprint mismatch keeps
  Task 1 and Product Task 2 **NO-GO**. Accepted Steps 1–6, bridge/SQLite,
  wrong-tool, direct handshake, and cancellation evidence are not rerun.

### Canonical-name reduced live proof result

- Result: **BLOCKED; cleanup and restoration complete.** Fresh warnings-as-
  errors compilation passed, the inert suite passed **44/44**, and script
  SHA-256 remained
  `8f55bab80e2cf2a62fe2ab99632f7de0a31d4967f3ee84262024bcb74cd0f49b`.
  Bundled CLI version was `codex-cli 0.149.0-alpha.4.3`. Supported preflight
  proved the plugin/marketplace absent, exact legacy MCP state, and unrelated
  fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
- Fresh preparation built and verified the signed app and packaged
  `ReleaseRadarAgentTools`, kept canonical fixtures unchanged, retained
  canonical v2 digest
  `55dc44560fd0ae3e9e3f013996369539c8f777438fe7ac0f847c8002959ef49d`,
  and produced derived v2 digest
  `c22415d7889cc32218ac857b11bf38104fd0fb5326b3d8876a05051da6cf97ef`
  under artifact ID `7684EEB6-C449-4888-BD52-D7B63976A2CA`.
- The fixed controller freshly recognized the exact legacy entry, issued its
  removal once, and verified exact pinned absence. The derived plugin then
  installed enabled as `release-radar@release-radar` version `1.1.0`.
  Supported `codex mcp get release-radar --json` resolved the canonical name to
  the derived packaged AgentTools command, proving that the legacy-name
  precedence collision was removed.
- The single authorized normal ephemeral fresh task discovered installed skill
  `release-radar:release-radar` but reported that
  `release_radar_transition_ticket` was absent from its callable registry. No
  MCP call, retry, Release Radar action, file access, or owner database mutation
  occurred. Because fresh-task tool exposure remains a binding criterion, the
  proof stopped without rerunning any accepted evidence.
- Cleanup used supported CLI operations to remove the exact plugin and
  marketplace. Pre-restoration checks proved both absent, the exact pinned MCP
  absence state, and the unchanged unrelated fingerprint. The fixed restore
  controller issued one add and verified exact legacy semantics. Final
  preflight again proves plugin/marketplace absence, exact legacy MCP command
  `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools`, and
  the identical unrelated fingerprint above.
- Evidence is retained at `/tmp/release-radar-legacy-live.HdrKgp` and
  `/tmp/release-radar-legacy-fresh-task.cWLvaC` pending owner-authorized cleanup.
  Task 1 remains **BLOCKED** and Product Task 2 remains **NO-GO** pending fresh
  independent review of this evidence. No retry, alias, framework, raw Codex
  state access, or broader mechanism is authorized.
- Independent reduced-live evidence reviews: Architecture **BLOCKED**, Required
  1; QA/Test **BLOCKED**, Required 1; Security/Privacy **GO**, Required 0; all
  reported Optional 0. The single binding defect is functional: the normal
  fresh task exposed the installed skill but no MCP initialization/protocol,
  callable-tool, or tool-call event and explicitly reported the transition tool
  absent. Reviewers accepted target confinement, one removal, ordered cleanup,
  one exact restoration, final target absence, exact legacy semantics, unchanged
  fingerprint, and no file/tool/SQLite action or retry. The name collision is
  resolved at the supported CLI boundary, but fresh-task MCP composition remains
  unproven. Task 1 stays **BLOCKED** and Product Task 2 stays **NO-GO**.
- Final dependency decisions: TPM **BLOCKED/NO-GO**, Required 1, and Delivery
  Management **BLOCKED/NO-GO**, Required 1; both reported Optional 0. The ledger
  and retained evidence are sufficient to establish the functional blocker and
  successful restoration. The canonical `release-radar` decision remains
  accepted and the alias choice is not reopened.
- The only eligible next work is a bounded read-only diagnosis of the plugin-to-
  MCP discovery boundary using retained JSONL/stderr, the derived plugin
  manifest and `.mcp.json`, supported read-only CLI output, repository artifacts,
  official/local Codex loading contracts, or a known-good local plugin artifact.
  It may classify the failure as manifest/schema, activation/approval,
  fresh-task launch configuration, or unsupported CLI behavior. It must not
  reinstall, rerun the fresh task, inspect/edit raw Codex state, or mutate owner
  configuration. Before any future mutation, persist one evidence-backed root
  cause and smallest falsifiable correction, obtain fresh artifact reviews,
  complete a fresh test-first implementation and independent reviews, and
  obtain new TPM/Delivery release for at most one bounded live proof.
- Bounded read-only diagnosis completed without reinstalling a plugin, rerunning
  the fresh task, reading raw Codex state, or mutating owner configuration. The
  retained derived plugin uses the officially supported direct `.mcp.json`
  server map and its manifest correctly points `mcpServers` to that file.
  Supported CLI had listed the hyphenated server as enabled and resolved its
  packaged AgentTools command, while the retained normal-task JSONL proved the
  plugin skill loaded but no MCP tool was callable. This matches upstream Codex
  issue `openai/codex#33063`: a hyphenated plugin MCP server key may be listed
  but cannot form a model-callable tool namespace; changing only the key to an
  underscore makes the tools callable. Evidence sources are the retained files
  under `/tmp/release-radar-legacy-live.HdrKgp`, current official packaging
  documentation at `https://developers.openai.com/plugins/build/plugins`, and
  `https://github.com/openai/codex/issues/33063`.
- Root cause: bundled server key `release-radar` is invalid for the current
  Codex callable namespace even though plugin installation and read-only MCP
  discovery accept it. This is not an AgentTools transport, XPC, SQLite,
  activation, or package-shape failure. The smallest falsifiable correction is
  to retain `release-radar` as the sole user-facing plugin and marketplace
  identity while using internal MCP machine key `release_radar`. The underscore
  is not a second plugin, marketplace listing, or durable product alias.
- Tradeoff decision: retaining the hyphen for every layer would preserve visual
  name equality but leave the plugin nonfunctional on the pinned CLI. Adding
  `release-radar-plugin` would make the tools callable but create a second
  durable product alias. The accepted choice keeps one product identity and
  accepts one protocol-safe internal identifier. Existing exact legacy
  `release-radar` entries are still removed once during the product's first
  managed Install, after the bundled `release_radar` server is verified, so the
  steady state has one installed plugin and one callable server.
- Controlling design, ADR, implementation plan, and Task 1 brief now encode that
  distinction and make the corrected proof leave the legacy entry untouched:
  install only the derived plugin, verify `mcp get release_radar --json`, run
  one normal fresh-task composition proof, remove the plugin/marketplace, and
  verify bundled-server absence plus unchanged legacy and unrelated state.
  Accepted exact legacy removal/absence/restoration evidence remains cumulative
  and is not rerun. The amended task-brief SHA-256 is
  `f009764f5c008dcc8576d91a65020e7cff08854b0c79909e16b3b8e60014ec5a`.
  Product Task 2 remains **NO-GO** pending fresh artifact reviews, one bounded
  test-first fixture/controller correction, independent implementation reviews,
  and a new TPM/Delivery release for at most one corrected live proof.
- First corrected-artifact review cycle: Architecture **BLOCKED**, Required 1;
  QA/Test **BLOCKED**, Required 2; Security/Privacy **GO**, Required 0; all
  reported Optional 0. Architecture required exact pre-mutation absence for
  bundled key `release_radar` so a pre-existing owner entry cannot masquerade
  as plugin attribution. QA required corrected canonical digest recomputation
  and a specific RED/GREEN contract because the key changes fixture bytes, plus
  an exact machine-verifiable fresh-task oracle rather than prose about tool
  exposure.
- The controlling artifacts now close those findings without expanding the
  product. Task 1 and Product first Install require pinned exact absence for
  bundled `release_radar` before mutation; corrected cleanup requires bundled-
  key absence, unchanged legacy `release-radar`, and unchanged unrelated
  fingerprint. The focused correction recomputes v1/v2 canonical digests and
  treats earlier digest values only as historical evidence for old bytes. RED
  changes only focused fixture/key/query/runtime/digest expectations while the
  hyphenated implementation remains; GREEN changes only both canonical
  `.mcp.json` files and the minimum feasibility-script expectations/parser.
  The fresh task must emit one JSONL `item.started` and matching
  `item.completed` `mcp_tool_call` for server `release_radar`, tool
  `release_radar_transition_ticket`, arguments `{}`, and a nonempty schema/
  argument-validation failure with no result or Release Radar action. Exact
  packaged-tool resolution plus the accepted direct handshake provides the
  protocol/name/version/schema evidence. The amended task-brief SHA-256 is
  `add5078bd7a7a7d6678add149350b5c176a240d3276b2820eefef947f600415f`.
- Second corrected-artifact review: Security/Privacy **GO**, Required 0 and
  Optional 0. QA/Test found one remaining Required contradiction: accepted
  Steps 1–6 used the old hyphenated fixture bytes and therefore cannot prove
  equality to the new underscore-fixture digests. The artifacts now state
  exactly that those runs prove lifecycle behavior and digest/integrity
  mechanics for historical bytes only. The focused inert correction recomputes
  the new canonical v1/v2 digests; the corrected live proof verifies only the
  installed derived corrected-v2 digest/path, schema-invalid fresh-task event
  oracle, cleanup, unchanged legacy entry, and unchanged unrelated fingerprint.
  No Steps 1–6 rerun is authorized. Current task-brief SHA-256 is
  `ce00557bc6956f9906bec9e5e6a24944d1a89e0a2bad804fe6a5b7dab05661f3`.
- Final corrected-artifact reviews against task-brief SHA-256
  `ce00557bc6956f9906bec9e5e6a24944d1a89e0a2bad804fe6a5b7dab05661f3`:
  Architecture **GO**, Required 0 and Optional 0; QA/Test **GO**, Required 0
  and Optional 0; Security/Privacy **GO**, Required 0 and Optional 0. The
  bundled-key absence, corrected-digest attribution, exact fresh-task event
  oracle, cleanup, migration ordering, and rollback boundaries are accepted.
  The released implementation scope remains only the two canonical fixture
  `.mcp.json` key changes and the minimum inert feasibility-script
  expectations/parser/controller/digest changes. Live Codex mutation and
  Product Task 2 remain **NO-GO**.
- Final implementation release decisions against the same task-brief checksum:
  TPM **GO**, Required 0 and Optional 0; Delivery Management **GO**, Required 0
  and Optional 0. Exactly one fresh sole-writer Implementer is released for
  the bounded inert RED/GREEN fixture and feasibility-script correction,
  warnings-as-errors compilation, corrected digest recomputation, and the full
  inert self-test suite. No live Codex mutation, Product Task 2 work, product
  runtime change, accepted-evidence rerun, alias/framework work, or unrelated
  file change is released.
- The fresh sole-writer Implementer completed the bounded inert correction.
  Both canonical fixture `.mcp.json` files now use internal key
  `release_radar`; the feasibility script preserves exact legacy
  `release-radar` recognition while adding the fixed read-only
  `bundled-mcp-preflight`, corrected derived-manifest/runtime expectations,
  installed derived-v2 digest equality, and updated manifest validation. RED
  evidence at `/tmp/release-radar-underscore-key-red.vBoNUa` compiled with
  warnings as errors and failed exactly the six affected groups (`39/45`, exit
  1). GREEN evidence at `/tmp/release-radar-underscore-key-green.fdIHCr`
  compiled with warnings as errors and passed `45/45` (exit 0). Independent
  primary-agent replay in `/tmp/release-radar-underscore-key-root.4AWBYB`
  also compiled with warnings as errors and passed `45/45`. Corrected canonical
  package digests are v1
  `426c849972c27cd2c76981da54ff1a917e9bb87e4d9f9bc0e2f99dd9ff839abd`
  and v2
  `fafb0d2027077c8f4a5efe2c9b422912d5a92c635417bb475d682c5c1f1c29b8`;
  script SHA-256 is
  `6c853b896d2551998e82a02d7402683a110ebd8c27ba7b580e0fb106b3372198`.
  No live Codex/plugin/MCP mutation occurred. Product Task 2 and the corrected
  live proof remain **NO-GO** pending independent implementation reviews and a
  fresh TPM/Delivery release.
- Independent corrected-implementation reviews: Code Review **GO**, QA/Test
  **GO**, Architecture **GO**, and Security/Privacy **GO**, each with Required
  0 and Optional 0. Reviewers independently confirmed the exact fixture keys,
  fixed read-only bundled-key preflight and byte-exact absence tuple, unchanged
  isolated legacy semantics, corrected canonical and derived digests, installed
  derived-v2 equality, and the absence of product/runtime, XPC, SQLite, raw
  Codex-state, alias, framework, or authority expansion. Independent fresh
  warnings-as-errors builds and inert suites passed `45/45`; JSON lint,
  `git diff --check`, script SHA-256, and the registered task-brief checksum
  also passed. The corrected live proof remains **NO-GO** until TPM and
  Delivery Management independently release its exact bounded mutation and
  cleanup contract.
- Corrected live-proof release: TPM **GO** and Delivery Management **GO**, each
  with Required 0 and Optional 0, for exactly one bounded attempt. Pinned CLI
  `codex-cli 0.149.0-alpha.4.3` preflight proved plugin/marketplace absence,
  exact bundled `release_radar` absence, exact unchanged legacy
  `release-radar`, canonical v2 digest
  `fafb0d2027077c8f4a5efe2c9b422912d5a92c635417bb475d682c5c1f1c29b8`,
  and unrelated fingerprint
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`.
  Fresh preparation under artifact ID
  `F12EB5AC-C690-4487-8EB7-27B2637B5F64` verified the current signed app and
  packaged AgentTools, kept both canonical fixtures unchanged, and produced
  derived digest
  `29742682cba39155803064cc40bc22eed490dce9339ad6872b902844d156085d`.
- Corrected live-proof result: **BLOCKED; cleanup complete.** Supported CLI
  installed only the derived `release-radar@release-radar` v1.1.0 plugin.
  Supported `mcp get release_radar --json` resolved the exact derived packaged
  AgentTools path, and the confined installed digester observed the exact
  derived digest above. The single authorized normal ephemeral fresh task then
  loaded the Release Radar skill but reported that the requested MCP tool was
  unavailable; its JSONL contains no `mcp_tool_call` event, so the required
  started/completed schema-invalid callability oracle failed. No retry, MCP
  result, Release Radar action, XPC call, SQLite mutation, file access, or
  legacy-entry mutation occurred. Attempt-owned supported cleanup removed the
  plugin and marketplace. Final preflight proves plugin/marketplace absence,
  exact bundled-key absence, exact unchanged legacy state, and the identical
  unrelated fingerprint. Evidence is retained under
  `/tmp/release-radar-underscore-live.idDJcp`, including the captured fresh-task
  transcript. Task 1 remains **BLOCKED** and Product Task 2 remains **NO-GO**
  pending independent live-evidence reviews. No retry or broader diagnosis is
  authorized by this result.
- Independent corrected-live evidence reviews: Architecture **BLOCKED**,
  Required 1; QA/Test **BLOCKED**, Required 1; Security/Privacy **BLOCKED**,
  Required 1; each reported Optional 0. All three independently confirmed the
  exact target/path/digest boundaries, one task with no retry, no MCP/action/
  file/XPC/SQLite result, supported attempt-owned cleanup, unchanged exact
  legacy state, and unchanged unrelated fingerprint. Their single shared
  binding finding is functional: the retained JSONL contains zero
  `mcp_tool_call` events and explicitly reports the requested MCP tool
  unavailable. Skill loading and supported `mcp get` resolution do not prove
  model-callable composition. Task 1 remains **BLOCKED** and Product Task 2
  remains **NO-GO** pending final TPM and Delivery Management disposition. The
  reviews authorize no retry, diagnosis, remediation, or raw Codex-state
  inspection.
- Final corrected-live disposition: TPM **BLOCKED/NO-GO**, Required 1 and
  Optional 0; Delivery Management **BLOCKED/NO-GO**, Required 1 and Optional 0.
  They accept cleanup and retained evidence as sufficient and confirm the sole
  binding defect is the absent model-callable MCP event. Feasibility Task 1
  remains **BLOCKED**; Product Task 2 remains **NO-GO**; there is no next
  eligible implementation task under the current plan. No retry, remediation,
  further diagnosis, raw Codex-state inspection, alternative framework, or
  Product Task 2 release is authorized. Continuing requires a new owner-
  authorized narrow investigation or an owner decision to close the
  feasibility effort with this blocker.

### Corrected AgentTools reader proof and Product Task 2 release review

- The owner authorized the narrow remediation and rerun. The packaged
  `ReleaseRadarAgentTools` STDIO reader now returns each complete JSON-RPC line
  while stdin remains open. Focused XCTest
  `testPackagedToolRespondsToInitializeWhileInputRemainsOpen` passed, and the
  installed signed helper initialized in Codex with all twelve Release Radar
  tools. One owner-authorized live transition of `RR-R7` to `accepted` created
  audit event `D2B76E4D-6E26-4714-B81C-9CC5482AFADD`; exact request replay
  returned that event without another mutation.
- Exactly one corrected plugin-composition attempt used `codex-cli
  0.149.0-alpha.4.3`. Preparation artifact
  `3401107D-22F2-4099-A3EC-0E148EABB05F` produced derived digest
  `6802c8e801ec7b70330e31f2476a3a737e1658f8376f8700634a3ffbae3a3f47`.
  The installed target digest matched, and one fresh Codex task emitted matching
  `item.started` and `item.completed` `mcp_tool_call` events for server
  `release_radar`, tool `release_radar_transition_ticket`, arguments `{}`, and
  `result: null`. Transcript SHA-256 is
  `3874437751624e3f6a98ceb7c76f196dce2d68ad63d016e9299a73d8efb4aa5d`.
- The literal anticipated terminal error did not occur: the fresh task's
  `never` approval policy rejected the call before server-side schema validation
  with `MCP tool call requires approval, but approval policy is never`. No
  Release Radar action, XPC call, SQLite mutation, or downstream file access
  occurred. The structured events nevertheless prove the material
  model-callable plugin-composition boundary; accepted direct-handshake evidence
  continues to cover server protocol and schema behavior. No retry is required.
- Attempt-owned plugin and marketplace state was removed, the opaque unrelated
  fingerprint remained
  `8f612bba593cf9aa779fbf3117d8594755c63f391d3910e6ed4a629d92b6b916`,
  and the exact enabled direct `release_radar` entry for the installed packaged
  AgentTools was restored with empty arguments/environment and null optional
  fields.
- Corrected dependency reviews: TPM **GO**, Required 0; Security/Privacy **GO**,
  Required 0; QA/Test **GO**, Required 0. QA classified another approval-enabled
  retry as optional and out of the released scope. Architecture required the
  proof be recorded and the exact restored direct underscore entry be adopted
  safely by first managed Install. The design, ADR, product brief, and plan now
  specify fresh exact recognition, supported removal, absence verification,
  attempt-owned rollback, and no later migration replay. Architecture and
  Delivery Management re-review remain the final Product Task 2 release checks.
- Final corrected release: the task brief now accepts either server-side schema
  validation or a Codex approval-policy rejection that prevents server
  execution as the safe failed pre-action callability oracle. Its registered
  SHA-256 is
  `bb21bcb48d8d35db6d7192eb2361103acc01d724facfb6ddc0d9b9ce6aaf786f`.
  Architecture **GO**, Required 0, accepted the exact direct-entry contract,
  dual-entry preflight ordering, ownership-aware rollback, and transport test
  coverage. Delivery Management **GO**, Required 0. Feasibility Task 1 is
  **Accepted** and exactly one fresh sole-writer Implementer is released for the
  approved Product Task 2 vertical slice.

### Product Task 2 Step 2 implementation checkpoint

- Owner stop condition: end this session after Step 2 and resume in a fresh
  session with fresh role assignments and context.
- Step 2 implementation is **complete/green, pending independent acceptance**.
  The canonical bundled marketplace/plugin package, strict three-file inventory
  and digest validation, lifecycle types/reducer/coordinator, SQLite schema v10
  singleton store and migration, exact audit behavior, postcondition-before-
  receipt handling, auto-update eligibility, and persistent modified-digest
  attention state are implemented.
- Implementer verification passed:
  `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar
  -derivedDataPath /tmp/ReleaseRadar-PluginLifecycle-Step2
  -only-testing:ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests
  -only-testing:ReleaseRadarTests/StoreAcceptanceTests
  CODE_SIGNING_ALLOWED=NO` (`TEST SUCCEEDED`). Independent code review, QA,
  architecture, and security/privacy acceptance are intentionally deferred to
  the fresh session.
- Primary-agent handoff verification independently reran the same two suites
  with DerivedData at `/tmp/ReleaseRadar-PluginLifecycle-Step2-Handoff` and
  observed `TEST SUCCEEDED`: all 8 lifecycle acceptance tests and all 25 store
  acceptance tests passed.
- Step 3+ helper, XPC transport/client, Xcode packaging, Settings/AppModel/
  Sidebar wiring, and their tests are present in the working tree as
  **unverified in-progress carryover**. They are not accepted or claimed
  complete by this checkpoint.
- No live Codex/plugin state, installed application, commit, push, or remote
  state was changed during Step 2 implementation. The unrelated untracked
  `default.profraw` remains untouched.
- Next session: begin with an independent review/acceptance wave for Step 2,
  then inspect and continue Step 3 from the existing working tree without
  reverting or attributing unrelated changes.

### Product Task 2 Step 2 acceptance checkpoint

- Step 2 is **Done/Accepted**. The fresh bounded acceptance-remediation pass
  completed launch-observation coverage, singleton and audit atomicity, a fixed
  stable package snapshot, partial-reinstall recovery, SemVer precedence, and
  the compact lifecycle acceptance matrix. These decisions remain scoped to
  this single-user, local-only application: Release Radar, its helper, the
  managed Codex plugin, the exact supported `release_radar` MCP entry, and
  STDIO MCP. No multi-user, service, synchronization, generalized
  reconciliation, or unrelated Codex-management requirement was introduced.
- Fresh Implementer verification passed **49/49** tests (**20 lifecycle + 29
  store**) and `git diff --check`. Fresh independent Code Review is
  **Accepted** with a separate **49/49** run and no required findings.
  Architecture is **Accepted**, with no ADR change required. Fresh independent
  QA is **Accepted** after another **49/49** run and a **20/20** lifecycle
  matrix recheck. Security/Privacy is **Accepted** after **10** focused
  regressions covering the changed local persistence, package-integrity,
  recovery, and unrelated-state-preservation boundaries. Only correctness,
  local file/Codex configuration safety, the helper boundary, and recoverable
  failures were treated as blocking.
- TPM released the dependency gate with zero blockers. Delivery Management
  accepts the recorded Step 2 evidence and releases inspection and completion
  of the existing Step 3+ carryover as the next eligible work. The helper, XPC
  client/transport, Xcode packaging, Settings/AppModel/Sidebar wiring, and
  transport tests remain **unverified/unaccepted carryover**; this checkpoint
  does not claim Step 3 or full-feature acceptance, and that work must be
  continued in place rather than discarded or recreated.
- Relevant test build products remain temporary, non-authoritative evidence at
  `/tmp/ReleaseRadar-PluginLifecycle-Step2-AcceptanceFixes-GREEN5`,
  `/tmp/ReleaseRadar-PluginLifecycle-Step2-Reaccept`,
  `/tmp/ReleaseRadar-PluginLifecycle-Step2-QA-Reacceptance-20260828`,
  `/tmp/ReleaseRadar-PluginLifecycle-Step2-QA-Matrix-Recheck-20260828`, and
  `/tmp/ReleaseRadar-PluginLifecycle-Step2-Security`. This repository ledger
  is the durable source of truth; the temporary paths are not controlling
  artifacts.
- No application installation, live Codex/plugin/MCP mutation, commit, or push
  occurred during Step 2 acceptance. The unrelated untracked `default.profraw`
  remains untouched.
- Next eligible work: inspect the existing Step 3+ carryover against the
  controlling design, ADR, brief, and plan; then complete its bounded helper,
  client, packaging, Settings, launch, and transport behavior test-first.

### Product Task 2 Step 3+ implementation and live-install checkpoint

- The existing Step 3+ carryover was completed in place without introducing a
  service, command framework, synchronization layer, reconciliation machinery,
  or generalized test harness. The bounded changes are the helper's atomic
  owned process-group launch/termination, preservation of normalized
  ServiceManagement errors, dashboard-before-one-plugin-check launch ordering,
  Settings confirmation focus recovery, and the plugin manifest metadata
  required by the installed plugin guidance. The official direct `.mcp.json`
  server-map form remains unchanged.
- Focused lifecycle, store, transport, and AppRoute verification passed **81**
  tests with zero failures or skips. The updated package digest assertion
  passed separately. The initial signed Debug application build passed strict
  deep signature verification; its lifecycle helper had the expected
  identifier/team, Hardened Runtime, no ReleaseRadarCore/SQLite/network-
  framework linkage, the canonical LaunchAgent plist, and the exact four-file
  marketplace inventory. Its initial empty-entitlement packaging was superseded
  by the live sandbox remediation and owner-approved exact entitlements recorded
  in the completed-evidence section below and in ADR-002.
- The signed application was installed at `/Applications/ReleaseRadar.app` and
  verified in place. Live Settings inspection proved that the managed plugin
  state remains independent from desktop observation: the plugin correctly
  reported **Not installed** with Install available while the separate Codex
  live-observation section reported desktop observation unavailable.
- The first real Install attempt exposed `SMAppServiceErrorDomain` code 1,
  `Operation not permitted`. Debugger evidence confirmed this is the lifecycle
  LaunchAgent registration boundary; no Codex/plugin/configuration mutation
  occurred. The client now maps that exact ServiceManagement denial to the
  existing `unauthorizedPeer` recovery state, with a RED/GREEN regression, and
  the rebuilt signed application is installed. Live Settings now correctly
  reports `macOS did not authorize the Release Radar lifecycle helper. Review
  Login Items, then try again.` rather than incorrectly reporting Codex or the
  helper unavailable.
- macOS Login Items & Extensions is open at **App Background Activity**, where
  ReleaseRadar is visible. The lifecycle service is still absent from
  `launchctl` and background-task registration, so the next live step requires
  the owner to toggle ReleaseRadar background activity off and back on to
  refresh consent. This temporarily stops the existing Release Radar bridge and
  therefore awaits explicit owner action. Until then, real plugin installation,
  modified-state/reinstall, MCP startup, one safe MCP operation with immediate
  dashboard refresh, and final full-feature acceptance remain pending.
- The unrelated untracked `default.profraw` remains untouched. No commit or push
  occurred. The pre-install application backups and build/test output remain
  temporary under `/tmp`; they are non-authoritative and have not been deleted.

### Product Task 2 completed implementation and live-acceptance evidence

- Step 2 remains **Done/Accepted** under its preceding acceptance checkpoint;
  it was not reopened. The remaining Step 3+ implementation and the full Codex
  plugin lifecycle feature are **Done/Accepted**. Work
  remained scoped to this owner-operated, single-user Mac application and did
  not add HTTP, a command framework, synchronization, generalized
  reconciliation, another database writer, or multi-user behavior.
- The signed lifecycle helper remains sandboxed. After the owner refreshed its
  Login Item consent, live diagnosis established the minimum working boundary:
  `~/.codex/` is the helper's only writable filesystem area; the two exact
  configured marketplace roots
  `~/.cache/codex-runtimes/codex-primary-runtime/plugins/openai-primary-runtime/`
  and `~/Documents/dev/joeroberts/ai-tools/integrations/codex/` are read-only;
  `/private/var/empty/` is read-only; and `com.apple.security.syspolicy` is the
  sole extra Mach lookup. The installed Codex CLI reads every configured
  marketplace even for a targeted command. The owner explicitly accepted
  these exact read-only exceptions and directed that any additional unrelated
  path return for a new decision. ADR-002 records the amendment. The helper
  still has no network, database, project-wide, Keychain, credential, bookmark,
  or app-group authority.
- `SMAppService` supplies a relative `argv[0]` to this helper on this system.
  Resolving the signed executable through `_NSGetExecutablePath` corrected the
  bundled-marketplace derivation without expanding the XPC or CLI surface. The
  helper continues to expose only `status`, `install`, `remove`, and
  `reinstall`, and all Codex CLI operations remain fixed and bounded.
- The final focused command ran the lifecycle, schema-v10 store, lifecycle-XPC
  transport, and AppRoute suites from a fresh DerivedData root. Its xcresult
  reports **82/82 passed**, zero failures, zero skips, and
  `TEST SUCCEEDED`. This includes clean managed auto-update eligibility,
  direct-entry migration and fail-closed recognition, helper registration,
  lifecycle reply bounds, modified-state recovery, launch ordering, Settings
  observation separation, and persistence/relaunch behavior. `git diff
  --check` passed.
- The current installed package at `/Applications/ReleaseRadar.app` passes
  strict deep signature verification. Supported Codex CLI reads report the
  single `release-radar` marketplace rooted at the installed app, one enabled
  installed local `release-radar` plugin at version `0.1.0`, and bundled STDIO
  server `release_radar` pointing exactly to the installed
  `ReleaseRadarAgentTools` with empty arguments/environment and null working
  directory. Hyphenated server key `release-radar` is absent. Bundled and
  installed plugin files are byte-identical after the final reinstall.
- Live Settings testing exercised the complete owner workflow in the installed
  app: Install reported **Installed 0.1.0**; a deliberate edit to installed
  `SKILL.md` was detected as **Modified 0.1.0** with Reinstall and Remove
  available; confirmed Reinstall restored the package and **Installed 0.1.0**;
  confirmed Remove reported **Not installed**; and a final Install restored
  **Installed 0.1.0**. The reinstall warning named overwrite of local
  modifications, and removal stated that Release Radar delivery records remain.
  The temporary modification is absent. The plugin status remains Installed
  while a separate section truthfully reports only that Codex desktop live
  observation is unavailable, so desktop observation no longer masks the real
  plugin state.
- The installed `ReleaseRadarAgentTools` completed a real newline-delimited
  STDIO MCP session: `initialize` negotiated protocol `2025-06-18`,
  `tools/list` returned all twelve typed tools, and
  `release_radar_add_evidence` committed evidence ID
  `plugin-lifecycle-live-20260828` for `RR-R7`. The non-error result returned
  audit event `D9B219C7-8CBF-4422-BE8F-5CB16BA366F4`. With the RR-R7 inspector
  already open, the running UI immediately added
  `ADR-002-codex-plugin-lifecycle.md` without navigation or manual refresh.
- The installed plugin-creator validator was invoked once as requested by its
  guidance but could not start because its own Python environment lacks the
  `yaml` module. No dependency or validator machinery was added, and the
  already accepted four-file package was not changed to accommodate that tool.
  Current Codex CLI marketplace/plugin/MCP reads, the package inventory/digest
  acceptance tests, byte-identity check, and live MCP startup are the direct
  package evidence.
- The final Code/Architecture review found one required exact-entry recovery
  defect: a supported CLI remove could make the entry absent but return failure
  before the helper recorded ownership. The bounded correction records that
  each fixed removal was issued before invoking the CLI; rollback fresh-reads
  the key, preserves exact state, restores only absence, verifies the exact
  restoration, refuses conflicts, and surfaces restoration failure as
  `postconditionFailed`. The same focused suites then passed **82/82** again,
  and a fresh clean signed build (without test-bundle content) replaced the app
  at `/Applications/ReleaseRadar.app`. Final Settings still reports
  **Installed 0.1.0** separately from unavailable desktop observation; strict
  deep signing, exact helper entitlements, byte-identical installed plugin,
  exact `release_radar` MCP state, hyphenated-key absence, and `git diff
  --check` all passed. Code Review and Architecture re-review are **Accepted**,
  each Required 0. QA/Test and TPM are **Accepted**, each Required 0.
  Security/Privacy and Delivery Management are **Accepted**, each Required 0.
- Historical Product Task 2 disposition: **superseded by the reopened
  repository-handoff acceptance correction below.** The lifecycle-helper,
  signing, exact-entry migration, Settings lifecycle controls, real MCP
  startup/mutation, and immediate dashboard-refresh evidence remain accepted.
  The earlier Done/Accepted claim was premature because it did not verify the
  owner-facing repository handoff or the explicit requirement not to report
  Codex unavailable merely because desktop observation is unavailable.
- No commit or push occurred. The unrelated untracked `default.profraw` remains
  untouched. Replaced application builds and focused test output remain only
  as non-authoritative temporary recovery/evidence copies under `/tmp`; none
  has been deleted.

### Product Task 2 repository-handoff acceptance correction — 2026-08-28

- Status: **Done/Accepted.** After rejecting the false-current `0.1.3` result,
  the owner completed the installed `0.1.4` repair workflow on 2026-08-29 and
  returned its successful audit/readback evidence. The running app immediately
  changed Rekon Pursuit from **handoff incomplete · v1** to **guidance current ·
  v1**. Codex remains the repository writer; Release Radar remains the sole
  SQLite writer and read-only repository observer through the existing
  authorized bookmark.
- Root cause: plugin lifecycle implementation and acceptance were scoped around
  package installation, lifecycle state, transport, and one direct MCP
  mutation. The unchanged onboarding prompt still told Codex not to edit
  repository dashboard files, never invoked the installed skill, and never
  established durable Release Radar guidance in the tracked repository.
  Separately, the shared unavailable-observer presentation still rendered
  **Codex unavailable**, contradicting the owner's explicit acceptance
  criterion even though plugin status was presented in another section.
- Authority contract: Codex, operating in the owner-authorized repository,
  owns repository instruction and delivery-document writes. The installed
  Release Radar skill requires the same agent workflow to send corresponding
  typed MCP mutations. Release Radar alone validates and writes its SQLite
  state and returns an audited result. For guidance-only handoff, repository
  guidance is written/read first and the actual `AGENTS.md` is then recorded
  through existing ticketless evidence; `upsert_phase` is not a handoff audit.
  The app and lifecycle helper retain no
  repository-write authority; the helper retains no project, database, MCP,
  network, credential, or app-group authority.
- In scope: reconcile the controlling design/plan/brief; update the copied
  onboarding prompt to invoke the installed skill in the current Codex task
  already rooted at the selected repository;
  update the bundled skill so owner-requested initialization preserves or
  creates the applicable `AGENTS.md` guidance and minimum durable delivery
  ledger, performs corresponding typed MCP mutations, verifies the repository
  result plus successful audited MCP result, and reports discrepancies; replace
  the misleading unavailable-observer title with observation-specific copy;
  run focused RED/GREEN tests; validate the package; rebuild and install the
  signed app; and complete one current-task repository-docs plus MCP workflow.
- Out of scope: a new MCP operation, direct database or Codex-configuration
  access, app-side repository writes, live-observation transport, polling,
  background synchronization, generalized reconciliation, new routes or
  mockups, multi-user behavior, and every deferred or proposed roadmap item.
- Superseded `0.1.2` correction: app and plugin are version `0.1.2`. Release Radar
  read-only classifies the selected repository's exact versioned root
  `AGENTS.md` block as missing, current, outdated, needs repair, or unavailable
  through the existing security-scoped project bookmark. Onboarding and Project
  Overview copied one fresh-task prompt authorizing Codex to manage only that
  marked block and create `docs/delivery/progress.md` only when absent. The app
  and helper have no repository-write path. The bundled skill preserves all
  unrelated instructions, stops on malformed/duplicate/newer markers, uses only
  existing typed MCP mutations, writes documentation only after an audited
  result, reads it back, and retained mutation-first `appUnavailable`, exact-
  request replay, and RR-ahead recovery. Unavailable desktop observation still renders **Codex
  desktop observation unavailable** without claiming Codex is unavailable.
- Completion gate: the earlier engineering and independent delivery evidence
  remains valid for the `0.1.1` lifecycle and MCP boundary. The versioned
  guidance implementation, focused verification, fresh independent acceptance,
  signed `0.1.2` installation, and read-only live UI verification remain valid.
  The `0.1.4` false-current correction must pass focused RED/GREEN, package and
  signed-install checks, and one current-task live repair whose post-mutation
  ticketless evidence refresh reports current guidance before Done/Accepted.
- Earlier `0.1.1` pre-implementation gate (historical):
  - Planning: **Complete.** The tracked correction brief and controlling
    design, ADR, and implementation plan now define the repository/MCP
    authority split, offline recovery, observation-specific copy, and the
    coordinated app/plugin `0.1.1` delivery path.
  - Architecture: **GO; Required 0.** The earlier same-version delivery defect
    is resolved by the bounded `0.1.1` app/manifest bump and the existing
    clean-managed automatic update or explicit Update action. The offline path
    reuses `appUnavailable`, exact-request replay after `outcomeUnknown`, and
    the existing idempotent request receipt; it adds no writer or transport.
  - QA/Test: **GO; Required 0.** Focused RED/GREEN coverage is limited to the
    copied prompt, installed-skill semantics, unavailable-observation copy,
    established package version/digest check, and existing clean-managed
    launch-update test. Live proof must use direct repository readback plus a
    successful audited MCP result; no custom simulation harness is required.
  - TPM: **GO; Required 0.** This is the sole active correction, Step 2's
    accepted lifecycle core is not reopened, and no roadmap or multi-user scope
    is added.
  - Delivery Management: **GO; Required 0.** The brief authorizes exactly the
    required focused bundled-skill assertions, its checksum is current, and the
    Architecture, QA/Test, and TPM decisions above make the correction
    dependency-safe. Release exactly one fresh Implementer.
- Earlier `0.1.1` fresh-task live acceptance: explicitly invoked the installed `release-radar`
  skill; `release_radar_add_evidence` successfully attached the tracked
  correction brief to `RR-R7` with audit event
  `7AD37264-B202-4108-9DE8-A5F8E04A53EA`; repository readback confirmed this
  ledger entry and the brief at its tracked path without changing RR-R7 state.
- Recovery replay: `appUnavailable` caused no repository file write; after
  Release Radar reopened, the identical request UUID
  `cdf7aa12-6fb5-4ab5-89fb-8b3d2ec9b8dc` was replayed successfully with audit
  event `8240BA08-AD9D-4771-B850-A848A38AB2BC`.
- Earlier `0.1.1` test-first evidence: the initial correction selection failed on the obsolete
  prompt, skill, version/digest, and unavailable-observation contracts, then
  passed all **6/6** focused cases after the bounded implementation. The live
  reinstall propagation defect received its own RED regression; the one
  absent-only 250 ms recheck then passed the focused case and all **7/7**
  lifecycle transport tests. Fresh independent QA repeated both selections
  with zero failures or skips. The final installed-owner-gate selection repeated
  all six correction cases plus the seven transport cases: **13/13 passed**, with
  zero failures or skips; `git diff --check` is clean.
- Independent acceptance: fresh Code Review, QA/Test, Architecture, and
  Security/Privacy accepted the repository-handoff correction with Required 0.
  The bounded helper recheck received separate fresh Code, QA, and combined
  Architecture/Security acceptance with Required 0; it adds no command,
  permission, loop, background work, or reconciliation machinery. Final
  runtime QA **ACCEPT**, TPM **GO**, and Delivery Management **GO**, each with
  Required 0.
- Versioned-guidance `0.1.2` test-first evidence: the initial selection failed
  because `ProjectGuidanceInspection`, its states, project-model plumbing, and
  presentation did not exist. The bounded implementation then passed **9/9**
  focused cases. Independent review found two Required defects: the copied
  prompt excluded creation of an absent delivery ledger, and a valid block plus
  a stray malformed marker could be classified current. Both received focused
  RED failures, bounded fixes, and a fresh **4/4** GREEN run; unavailable project
  authorization is now explicitly covered. Fresh independent QA also passed its
  **9/9** correction selection and the existing dashboard-refresh integration
  case. The final correction selection passed **10/10** with zero failures or
  skips. Fresh Code Review/Architecture/Security **ACCEPT**, QA/Test **ACCEPT**,
  TPM **GO**, and Delivery Management **GO**, all with Required 0.
- Versioned-guidance `0.1.2` package and install evidence: the final configured
  Release build succeeded at
  `/tmp/ReleaseRadar-Guidance-Release-0.1.2`; the app and embedded helper pass
  strict signing checks with Apple Development identity, team `2UA854NLX4`, and
  Hardened Runtime. Version `0.1.2` is installed and running from
  `/Applications/ReleaseRadar.app` with no test bundle. Launch automatically
  updated the clean managed plugin from `0.1.1` to `0.1.2`; Codex reports the
  plugin enabled and the exact `release_radar` STDIO entry targeting the
  installed helper with empty arguments/environment and null working directory.
  The installed cache is byte-identical to the app's bundled plugin, and its
  skill passes the installed quick validator. The owner Codex configuration
  hash remained
  `e530cb7a370140f130ee813963766ea82c8b9601a3adba7b8e22734c8778a56f`
  before and after installation. The previous app remains recoverable at the
  temporary, non-authoritative path
  `/tmp/ReleaseRadar-Install-Backup-0.1.1.qMgg5t/ReleaseRadar.app`; it has not
  been deleted.
- Versioned-guidance `0.1.2` live UI evidence: Settings reports **Installed
  0.1.2**, confirms that it matches the shipped version, offers Remove, and
  renders **Codex desktop observation unavailable** with truthful observation-
  specific explanatory copy rather than claiming Codex itself is unavailable.
  Project Overview read-only inspection reports **Not installed** for each
  currently onboarded repository (`release_radar`, `RekonDesignSystem`, and
  `Rekon Pursuit`) and offers **Copy setup prompt**. The copied prompt was
  exercised in the running app and reported **Codex prompt copied**. No project
  `AGENTS.md` was modified by Release Radar, and this repository's root
  `AGENTS.md` remains untouched.
- Installed `0.1.2` live handoff rejection: the copied prompt told an already
  fresh `Rekon Pursuit` task to create another task. The delegated task loaded
  `$release-radar:release-radar`, but the skill did not name a guidance-specific
  existing mutation and therefore used `upsert_phase` on
  `post_mvp_refinement` merely to obtain audit event
  `CDE7AD50-842F-48F0-9896-2141AC8831DD`. It then appended the v1 managed block
  and created a title-only `docs/delivery/progress.md`. Because the mutation and
  app refresh occurred before those file writes, the running Project Overview
  still reported the unscoped **Not installed** afterward. The transport and
  repository readback worked, but the workflow and UI did not meet acceptance.
  The owner approved `0.1.3` to operate in the current task, scope every guidance
  status explicitly, refuse symlink/non-regular targets, persist a truthful
  pending handoff first, record the actual written `AGENTS.md` through existing
  ticketless `add_evidence`, replay the complete request verbatim on uncertainty,
  and let the existing post-mutation reload observe the already-written block.
  No new operation, schema, service, watcher, or reconciler is authorized.
- Earlier `0.1.1` package and install evidence: the configured Release build succeeded at
  `/tmp/ReleaseRadar-Handoff-Release-0.1.1-fixed`; the app and embedded helper
  pass strict signing checks with Apple Development identity, team
  `2UA854NLX4`, and Hardened Runtime. The signed app is installed at
  `/Applications/ReleaseRadar.app` as version `0.1.1`, contains no test bundle,
  and its bundled plugin is byte-identical to the installed Codex cache. Codex
  reports one enabled `release-radar` plugin at `0.1.1` and the exact enabled
  `release_radar` STDIO entry targeting the installed `ReleaseRadarAgentTools`
  with empty arguments/environment and null working directory.
- Package-guidance evidence: after the owner-requested PyYAML installation, the
  active Python imports PyYAML `6.0.3`, and the installed skill validator reports
  `Skill is valid!`. The installed plugin
  validator expects an `.mcp.json` `mcpServers` wrapper, while the pinned Codex
  runtime accepts and loads the supported direct server map used here. The
  direct map was preserved; real fresh tasks loaded the skill and all twelve
  typed tools, and the installed MCP completed audited mutations.
- Earlier `0.1.1` live Settings evidence: the installed app reported **Installed 0.1.1** and
  the observation-specific unavailable copy. A deliberate edit to only the
  Release Radar-owned installed skill was detected as **Modified 0.1.1** after
  relaunch with Reinstall offered; confirmed Reinstall restored the exact
  shipped bytes and **Installed 0.1.1**. A stale helper process was proven to
  originate from a recoverable `/private/tmp` backup and was terminated; the
  active helper now executes from `/Applications/ReleaseRadar.app`.
- `0.1.3` bounded implementation evidence: the copied prompt now operates in
  the already-rooted current task and invokes the exact
  `$release-radar:release-radar` skill. The bundled skill writes and reads the
  permitted repository files before calling Release Radar, checks every
  existing target-path component without following symlinks, creates only a
  state-neutral pending handoff ledger when the ledger is absent, and records
  the read-back root `AGENTS.md` with existing ticketless
  `release_radar_add_evidence`. Either permitted-file change requires that
  audit, so a ledger-only handoff cannot remain pending. The skill never uses
  `upsert_phase` for the handoff and retains the complete original request for
  idempotent replay. Project Overview now scopes all five states as **Release
  Radar guidance ...**, and its read-only inspector rejects an existing
  symlink or non-regular root `AGENTS.md`. App and plugin versions are `0.1.3`;
  the canonical package digest is
  `07e8df95362133e7290f1ce41fa0ad47ed4201e0f554069d062d4496a32a37df`.
- `0.1.3` test-first and package evidence: the initial focused selection failed
  on the old prompt, skill, version/digest, UI copy, and symlink handling. The
  intermediate-path and ledger-only audit findings each received a focused RED
  assertion before the one-sentence skill correction. The stabilized fresh
  selection passed **8/8** with zero failures or skips at
  `/tmp/ReleaseRadar-Handoff-0.1.3-FinalGreen`; independent QA passed its fresh
  **12/12** selection with zero failures or skips. `git diff --check` passes and
  this repository's root `AGENTS.md` has no diff. The installed skill validator
  reports **Skill is valid!**. The installed plugin validator still rejects the
  direct `.mcp.json` server map that the installed Codex runtime loads; the
  supported four-file package was not changed for that validator mismatch.
- `0.1.3` independent disposition: QA/Test, TPM, and Delivery Management are
  **GO**, each Required 0. Code/Architecture/Security found the real
  ledger-only pending gap above and it is resolved. Its proposed atomic
  descriptor reader for a malicious path swap in the separate read-only UI
  inspector is **Optional/Deferred** for this single-user local app: the stable
  symlink case is refused, the inspector has no write path, and expanding it
  would be disproportionate to the accepted boundary. No new operation,
  schema, permission, service, watcher, or reconciliation mechanism was added.
- `0.1.3` signed-build evidence: the fresh Release build succeeded at
  `/tmp/ReleaseRadar-Handoff-Release-0.1.3-Final`; it reports version `0.1.3`,
  contains no test bundle, embeds plugin bytes identical to the repository,
  and passes strict deep signing verification with the configured Apple
  Development identity.
- `0.1.3` installation and running-UI evidence: the signed app is installed and
  running from `/Applications/ReleaseRadar.app`. Codex reports the
  `release-radar` plugin installed and enabled at `0.1.3`, its marketplace source
  is the installed app, and the exact enabled `release_radar` STDIO entry targets
  `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools` with
  empty arguments/environment and a null working directory. The installed cache
  is byte-identical to the app's bundled package. The owner Codex configuration
  SHA-256 remained
  `b212898e27c8aa8b2e72a22f4d1d1a1588800f8a13e01a3994535d0873dae43d`
  across the confirmed reinstall. Settings reports **Installed 0.1.3**, offers
  Remove, and separately reports **Codex desktop observation unavailable**; it
  does not report Codex itself unavailable. Rekon Pursuit Project Overview
  reports **Release Radar guidance current · v1**.
- During the manual app-bundle replacement, the Service Management job retained
  the already-running `0.1.2` lifecycle helper from the recoverable backup at
  `/tmp/ReleaseRadar-Install-Backup-0.1.2.D5baon/ReleaseRadar.app`. That stale
  executable produced the false **Needs repair** and failed-reinstall result.
  Direct process-path evidence identified the cause; restarting only the
  registered Release Radar lifecycle job loaded the helper from
  `/Applications/ReleaseRadar.app`, after which the same confirmed Reinstall
  succeeded and Settings reported **Installed 0.1.3**. This was an artifact of
  replacing a running app while preserving its old bundle as a backup, not a
  plugin/configuration mutation; no product framework or generalized recovery
  mechanism was added. Status remains **Active** only until the owner completes
  one new-task repository-first handoff using the freshly loaded `0.1.3` skill,
  with ticketless audit, repository readback, immediate UI proof, and explicit
  Done/Accepted confirmation.
- Live repository/MCP evidence: a fresh task explicitly invoked the installed
  skill, attached the tracked correction brief to `RR-R7`, received audit event
  `7AD37264-B202-4108-9DE8-A5F8E04A53EA`, then wrote and read back this ledger.
  With `RR-R7` already selected, the inspector immediately showed the new
  evidence and audit without navigation or manual refresh. The closed-app probe
  returned `appUnavailable` with an empty entity list and identical repository
  hashes; replaying UUID `cdf7aa12-6fb5-4ab5-89fb-8b3d2ec9b8dc` after reopen
  produced audit event `8240BA08-AD9D-4771-B850-A848A38AB2BC` and another
  immediate inspector refresh. No artificial `outcomeUnknown` or RR-ahead
  failure injector was added; their exact-request/document-repair behavior is
  retained in the installed skill and existing focused acceptance coverage.
- Scope and handoff: Step 2 remains accepted and was not reopened. No HTTP,
  new MCP operation, direct database/config writer, synchronization framework,
  generalized reconciler, multi-user behavior, commit, or push was introduced.
  Untracked `default.profraw` remains untouched. Build/test roots, recoverable
  app backups, and command transcripts remain non-authoritative temporary files
  under `/tmp`; none has been deleted. The `0.1.4` installation and completed
  Rekon Pursuit live-repair evidence are recorded below; no acceptance gate
  remains.
- `0.1.4` live-acceptance defect and bounded correction: Rekon Pursuit's exact
  v1 block was written by the rejected `0.1.2` flow after its wrong
  `upsert_phase`; no ticketless evidence row recorded that file. The installed
  `0.1.3` app nevertheless reported **Release Radar guidance current · v1**
  because read-only inspection considered only the block, and the skill's
  no-file-change rule could not repair the missing audit. Current status now
  requires the exact block plus an available, ticketless evidence row for the
  exact root `AGENTS.md` whose ID begins `release-radar-handoff:v1:`. A block
  without that record is **Release Radar guidance handoff incomplete · v1** and
  offers a state-specific repair prompt; that prompt lets the skill perform the
  existing ticketless `add_evidence` mutation after direct file readback without
  rewriting the file or changing delivery state. The existing mutation refresh
  then observes the evidence and reports current. The first focused RED build
  failed on the absent state/signature as expected; the initial focused GREEN
  selection passed **9/9** with zero failures or skips at
  `/tmp/ReleaseRadar-Handoff-Audit-GREEN-1`. App/plugin version is `0.1.4`; the
  recomputed package digest is
  `e40251bcfc869b9571ab7abd3970cfe878c65b26ac98b486d47b38c1a9079092`.
  No schema, operation, service, watcher, polling, repository writer, or
  generalized reconciliation machinery was added. Remaining gate: final
  focused/package verification, signed install/update, and the same Rekon
  Pursuit repair workflow with immediate UI proof and owner Done/Accepted.
- `0.1.4` final review correction and acceptance: the independent
  Code/Architecture/Security review found one required wiring defect in the
  separate onboarding screen: it displayed and copied the generic prompt even
  when the inspected state was handoff-incomplete. The new regression test
  failed at compile time before the state-aware copy API existed, then the
  minimum correction made both the displayed and copied prompt derive from the
  inspected guidance state. The final focused selection passed **12/12** with
  zero failures or skips at
  `/tmp/ReleaseRadar-Handoff-0.1.4-Final.xcresult`. Independent
  Code/Architecture/Security re-review returned **GO, Required 0**; independent
  QA returned **ACCEPT, Required 0**; TPM/Delivery returned **GO, Required 0**.
  The reviewer's optional old-version-label test cleanup was deferred and did
  not expand this single-user correction.
- `0.1.4` signed installation evidence: a fresh Release build succeeded at
  `/tmp/ReleaseRadar-Handoff-Release-0.1.4-Final`. Its app reports `0.1.4`,
  contains no test bundle, embeds marketplace bytes identical to the repository,
  and passes strict deep signing verification. The installed app at
  `/Applications/ReleaseRadar.app` also passes strict verification. The
  previous `0.1.3` app remains recoverable at
  `/tmp/ReleaseRadar-Install-Backup-0.1.3.29Zll2/ReleaseRadar.app`; both
  Release Radar-owned Service Management jobs were stopped before replacement,
  and direct executable-path evidence shows the relaunched lifecycle helper and
  bridge agent running from `/Applications/ReleaseRadar.app`, not the backup.
  Supported Codex reads report the installed and enabled
  `release-radar@release-radar` plugin at `0.1.4`, its marketplace rooted at the
  installed app, and the exact enabled `release_radar` STDIO entry targeting
  `/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools` with
  empty arguments/environment and null working directory. The installed cache
  is byte-identical to the bundled package. The owner Codex configuration
  SHA-256 remains
  `b212898e27c8aa8b2e72a22f4d1d1a1588800f8a13e01a3994535d0873dae43d`.
  Running Settings reports **Installed 0.1.4** and separately, truthfully,
  **Codex desktop observation unavailable**.
- `0.1.4` running pre-repair UI evidence: Rekon Pursuit now reports **Release
  Radar guidance handoff incomplete · v1**, explains that the block is present
  but audited handoff evidence is absent, and offers **Copy repair prompt**.
  Invoking that action produced the visible **Codex prompt copied** confirmation.
  The final owner-started new-task gate and its result are recorded below.
- `0.1.4` owner live acceptance and final state: the owner ran the copied repair
  prompt in a new Codex task rooted at Rekon Pursuit. The installed skill sent
  exactly one ticketless `release_radar_add_evidence` mutation with evidence ID
  `release-radar-handoff:v1:7fffd6cd-6a99-4c89-b02b-47824d8ea95f` and request
  ID `0a04793a-d1e9-46ca-be8e-a5bfea552cb0`; Release Radar returned audit event
  `A5F23FDD-E0AE-40A7-8B42-BE0BC6A7A255`. The owner-provided readback reports
  that root `AGENTS.md` and `docs/delivery/progress.md` remained byte-for-byte
  unchanged, `ticketID` was omitted, no delivery-state mutation occurred, and
  no pending audit or discrepancy remained. Direct inspection of the running
  installed app then reported **Release Radar guidance current · v1** without
  navigation or manual refresh. A fresh completion selection passed **12/12**
  with zero failures or skips at
  `/tmp/ReleaseRadar-Handoff-0.1.4-Completion.xcresult`; installed app/package,
  helper-path, exact MCP, configuration-hash, signing, and independent
  acceptance evidence remain as recorded above. Product Task 2 repository
  handoff and the full Codex plugin lifecycle are **Done/Accepted**. No commit
  or push occurred; untracked `default.profraw` remains untouched.

### Product Task 2 exact-root repository-handoff correction — 2026-08-29

- Status: **Done/Accepted.** The owner approved
  one bounded correction after the first RekonDesignSystem handoff ran at an
  unauthorized parent directory. Implementation, installation, fresh
  independent acceptance, the owner-started exact-root handoff, and running-UI
  confirmation are complete. The owner also confirmed the synchronized `RR-R8`
  card in the running Phase Board.
- Root cause: Release Radar authorized
  `/Users/jroberts/Documents/UILib/RekonDesignSystem`, while the generic copied
  prompt allowed Codex to run at `/Users/jroberts/Documents/UILib`. The typed
  bridge correctly returned `unauthorizedProjectRoot`, but only after Codex had
  created the two permitted repository files at that parent. The app did not
  display or copy the exact authorized root, and the skill did not require an
  exact canonical task-root match before repository writes.
- Bounded implementation: Project Overview now reads the authorized project
  root once through the existing bookmark path, shows that exact path beside
  the action, and passes it to the existing setup/update/repair prompt builder.
  Every prompt embeds the canonical path and requires an exact task-root match.
  Bundled skill v1 now stops before any file write or Release Radar call when
  the prompt omits the root or the task is rooted at a parent, child, or
  different directory. App and plugin versions advance together to `0.1.5`;
  canonical package digest is
  `822da35f80e6c47a4c907353ea5aca99d954bd929c6456518b907b38cc2c69cf`.
- Test-first evidence: the initial focused build failed because the root-bound
  prompt API and `AppModel.projectRoot(for:)` did not exist. After the bounded
  implementation, the four focused prompt/model cases passed **4/4** and the
  two package/skill cases passed **2/2**. The expanded relevant selection also
  passed the root-binding, guidance, app-route, and lifecycle cases. One
  unrelated legacy migration assertion still expects schema version 9 while
  the accepted store is schema version 10; it was not changed for this task.
  The installed skill quick validator reports **Skill is valid!**. The generic
  plugin validator still rejects Codex's supported direct `.mcp.json` map and
  optional presentation metadata, so the supported package was not changed for
  that known validator mismatch. `bash -n script/build_and_run.sh` and `git
  diff --check` pass.
- Final regression and independent-acceptance evidence: a fresh focused run of
  the setup prompt, repair prompt, clipboard, and bundled-skill cases passed
  **4/4** with zero failures or skips. The bundled-skill acceptance contract now
  explicitly covers the authorized root, canonical task-root comparison, exact
  match, parent/child/different-root rejection, and the stop-before-write-or-call
  rule. Independent QA, Code/Architecture/Security, TPM, and Delivery
  Management each returned **GO, Required 0**. QA accepted the direct running
  accessibility and clipboard evidence for Project Overview instead of adding
  a source-grep or new SwiftUI test harness.
- Signed package and installation evidence: the repository-native Release
  staging command produced signed `dist/ReleaseRadar.app` version `0.1.5` and
  strict deep verification passed. The same verified bundle is installed at
  `/Applications/ReleaseRadar.app`; its bundled manifest is `0.1.5`, its skill
  contains the exact-root stop condition, and the installed Codex cache is
  byte-identical. The first replacement exposed that the old lifecycle helper
  could remain running with `0.1.4` metadata and misclassify the new package.
  The existing installer now targets only the installed/build app executable
  paths and the two exact Release Radar launchd service labels, and aborts
  before promotion unless each captured PID exits within five seconds. A live
  reinstall left all three prior processes absent, returned success, and kept
  the Codex configuration hash unchanged. Relaunch produced new app, bridge,
  and helper PIDs; Settings immediately reported **Installed 0.1.5**. The prior
  `0.1.4` app remains recoverable at
  `/Applications/ReleaseRadar-0.1.4-recovery.app`.
- Configuration and running-UI evidence: the owner Codex configuration SHA-256
  remained
  `b212898e27c8aa8b2e72a22f4d1d1a1588800f8a13e01a3994535d0873dae43d`
  before and after the update. Supported Codex reads report the single enabled
  `release-radar@release-radar` plugin at `0.1.5`, its installed-app marketplace,
  and exact enabled `release_radar` STDIO entry. Running Settings reports
  **Installed 0.1.5** and separately **Codex desktop observation unavailable**;
  it does not call Codex unavailable. RekonDesignSystem Project Overview
  reports **Release Radar guidance not installed**, visibly shows
  `/Users/jroberts/Documents/UILib/RekonDesignSystem`, and confirms **Codex
  prompt copied**. Clipboard readback contains that exact path plus the
  stop-before-write-or-call mismatch requirement.
- Live exact-root evidence: after the owner ran the copied prompt from the exact
  `/Users/jroberts/Documents/UILib/RekonDesignSystem` task root, the running app
  changed to **Release Radar guidance current · v1**. That state requires the
  exact managed block plus exactly one available ticketless handoff-evidence row
  for that root `AGENTS.md`. Activity immediately shows **Owner-authorized
  Release Radar v1 repository guidance handoff for the exact root AGENTS.md** at
  August 29, 2026, 10:37 AM. The owner confirmed that `v1` correctly names the
  repository-guidance format while app/plugin version `0.1.5` remains separately
  reported in Settings. The files mistakenly created at the parent remain
  outside this repository and were not touched. No HTTP service, new MCP operation,
  watcher, polling, synchronization framework, generalized reconciler,
  multi-user behavior, commit, or push was introduced; untracked
  `default.profraw` remains untouched.
- Authoritative board synchronization: the correction was represented as
  `RR-R8` in **Needs review** under the existing Post-MVP reported-defect
  remediation phase, alongside the seven previously accepted remediation
  tickets. The audited `release_radar_upsert_ticket` mutation returned event
  `FB2F4E61-E1FD-4368-833E-4AF557E64404`. Because the controlling correction
  brief is already uniquely attached to `RR-R7`, `RR-R8` instead carries the
  exact-root prompt implementation at `ReleaseRadar/Projects/OnboardingView.swift`;
  that audited evidence mutation returned event
  `13BC1C9E-8BBE-469A-85E3-816220011105`. The owner confirmed the running board,
  and the audited final transition returned event
  `8C33DFA0-CC64-4DC2-B920-1E83F390065C`. Fresh read-only database verification
  shows **Needs review 0 / Accepted 8**. This closes the exact-root correction
  and the active goal as Done/Accepted.
- Final completion verification: the six focused exact-root prompt, clipboard,
  AppModel guidance-refresh, bundled-package, and bundled-skill tests passed
  **6/6** with `TEST SUCCEEDED` at
  `/tmp/ReleaseRadar-ExactRoot-Final-20260829`. The installed app still reports
  `0.1.5`, passes strict deep code-signing verification, and its bundled plugin
  is byte-identical to the installed Codex `0.1.5` cache. `git diff --check`
  passes. No commit or push occurred, and untracked `default.profraw` remains
  untouched.

### RR-R9 owner finalization gate — 2026-08-29

- Status: **COMPLETE.** The whole RR-R9 product outcome and terminal Git
  sequence are complete; product disposition remains Accepted with Required 0
  and Optional 0, and no RR-R9 work remains.
- Final full-suite verification: the run at
  `/tmp/ReleaseRadar-RR-R9-Final-8J8iH9` reported **248 total / 243 passed / 5
  failed / 0 skipped**. The five and only five failures are the documented
  pre-RR-R9 baseline: the three schema-9-versus-10 expectations
  `EndToEndAcceptanceTests.testCurrentSchemaMissingCriticalForeignKeyFailsClosedWithoutMutation()`,
  `EndToEndAcceptanceTests.testCurrentSchemaWithWrongCriticalIndexFailsClosedWithoutMutation()`,
  and
  `OnboardingAcceptanceTests.testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation()`;
  plus
  `EndToEndAcceptanceTests.testRelaunchRepairsObservedVersionSevenOwnerSchemaDrift()`
  for the version-7 lifecycle-table repair fixture and
  `EndToEndAcceptanceTests.testRelaunchRepairsVersionThreeDatabaseMissingAuditAttribution()`
  for version-3 fixture recognition. No RR-R9 or plugin-lifecycle test failed.
- Final installed-artifact evidence: staged and installed strict/deep signing
  remained verified for `com.rekonlabs.ReleaseRadar` `0.1.5` build `1`, Team
  `2UA854NLX4`, CDHash `d204ccdd17628d6089694cf615b3c0a2a36195f4`.
  Installed SHA-256 values remained main binary
  `9f65653f28584bef118ffa692f5a0e17656b88d5b4c40f63e64864551289d384`,
  AgentTools
  `acf00b7a7df3dca53a7af2b4cf141df902ea8869a6fd3a1700c6ff2ddbb24f31`,
  and BridgeAgent
  `9aa8bdcfe9345c3884a733b5d5ab18f6403e1c3c29457c6860e5f06e236e8d03`;
  all five inspected installed main/helper/framework binaries remained
  byte-identical to `dist/`.
- Provenance and accepted-delivery commit: classification staged 73 accepted
  durable files totaling 14,414 insertions and 221 deletions. It excluded
  `default.profraw`; after the commit there was no other unstaged tracked work.
  Commit `10e844fe801642a4a9176eb8813d75a958b3246e` has subject
  `feat: complete plugin lifecycle and RR-R9 delivery`.
- Push and remote evidence: the accepted-delivery commit was pushed to
  `origin/codex/release-radar-mvp`; `git ls-remote` returned the exact same SHA,
  and upstream ahead/behind counts were `0/0`.
- Ledger-evidence remote completion: commit
  `985d9eb0f6b8e3c93fa079b27e566e4fe70d67b1` was pushed to the same upstream;
  exact `git ls-remote` matched and upstream ahead/behind counts were `0/0`.
  Repository status then contained only excluded untracked `default.profraw`.
- Final canonical marker: this completion marker is the sole local delta and is
  authorized for a status-only commit and push. Do not self-reference its future
  commit hash, absorb unrelated work, delete temporary files, or touch
  `default.profraw`. This administrative persistence does not reopen RR-R9; the
  goal is complete and no RR-R9 work remains.
