# Release Radar delivery state

## Current state

- Outcome: Managed Repository Documentation Contract M1 approval decision
- Active task: None — durable M1 package awaits owner approval
- Last complete task: Task 4A implementation independently accepted
- Next eligible task: M2A catalog-contract planning refresh, only after owner
  approval of M1 and separate authorization
- Next authorized action: Owner approval or rejection of the M1 package only;
  no implementation action is authorized
- State: AWAITING OWNER APPROVAL
- Last completed task Git checkpoint: `910b9653b661c6088d025bc6f6aea71271cff3b0`
- Planning base: `653cdfd647590bfefbb23b556d48bd5970846a97`
- Active brief: None — M2 and Task 4B remain unopened
- Active brief SHA-256: N/A
- Retry state: N/A
- Owner stopped: No

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
- [MDCP M2-M8 task briefs](task-briefs/2026-09-01-managed-repository-documentation-contract/)
- [Task 2A brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md)
- [Task 2B brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2b-schema-v12-ticket-task-persistence-models-brief.md)
- [Task 3 brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-3-ticket-task-planning-policy-brief.md)
- [Task 4A brief](task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-4a-guard-every-accepted-path-brief.md)

## Managed Repository Documentation Contract M0-M1 gate

- Status: M0 complete; durable M1 package complete and independently reviewed;
  owner approval pending. M1 approval will not authorize M2, tests, app launch,
  installation,
  owner-data access, storage migration, guidance activation, document moves,
  evidence mutation, Task 4B, Git operations, or external issue changes.
- Worktree/base verification: the exact authorized root was the Git top level;
  branch `codex/managed-documentation-contract-planning` was active; HEAD was
  `653cdfd647590bfefbb23b556d48bd5970846a97`; initial status was clean; the
  accepted RR-R10 Task 4A implementation checkpoint remains
  `910b9653b661c6088d025bc6f6aea71271cff3b0`.
- Issue #2 owner disposition: the exact `653cdfd` versions of
  `docs/delivery/evidence/2026-08-30-rr-r10-task-2a-red-evidence.json`
  (`95bfa880903408d20ef7fbaaa8051ef6a2908a45d2ada9f6d01e8ba9d89cdea5`),
  `docs/delivery/task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-2a-schema-v11-fixture-brief.md`
  (`711abe4edee9ac86951e9e41c40170f9fbb67123e2f44216e0203cec85595292`),
  and `docs/delivery/task-briefs/SHA256SUMS`
  (`7205890306b278548d09a67320e2ff6d9b04a0104980a4ca4410a3410229da6d`)
  are accepted as operative RR-R10 output. Session-level authorship remains
  unknown; acceptance neither infers authorship nor retroactively approves the
  post-hold changes. The attribution incident remains historical evidence, the
  preservation hold is resolved, and external GitHub Issue #2 remains open and
  unmodified. Accepted RR-R10 file content/entries were not rewritten merely to
  resolve the issue.
- Priority/dependency decision: MDCP has priority after M1. RR-R10 Task 4B is a
  separate bounded command-exposure task and remains eligible but unopened.
  GitHub Issue #1 is the later separate generic Ticket Tasks onboarding/adoption
  workflow and owns guidance v3.
- Compatibility gate: Task 4B cannot resume until every M2-M5 brief is
  independently accepted at exact clean checkpoint `MDCP-COMPAT-1`, freezing
  shared command/query, evidence, importer, guidance, bundled-skill, tool-schema,
  fixture, and acceptance-test contracts. Task 4B then requires a refreshed
  plan and separate owner authorization. M6-M8 may consume but not reopen the
  frozen contract; a required reopening pauses both programs and MDCP retains
  priority until a replacement checkpoint is accepted.
- Architecture direction: one Core-owned path/catalog contract; orthogonal
  artifact kind/lifecycle/authority; stable artifact IDs; deterministic indexes;
  legacy v1, read-only v1 staging, managed v2, and managed-unavailable modes;
  exhaustive managed/path evidence locators; exact project-root binding;
  canonical accepted catalog snapshots and typed audited catalog transitions;
  explicit root rebinding; and no repository documentation as delivery-state
  authority.
- Migration/adoption boundary: additive schema migration preserves every
  existing evidence row as legacy, leaves projects unbound, and performs no
  repository inference. Managed adoption happens only after exact root/catalog
  binding and read-only inventory through catalog-digest-bound, typed, audited,
  idempotent requests. Catalog changes remain pending until a validated typed
  acceptance transition commits. Ambiguous and arbitrary evidence remains
  legacy.
- Planning inventory: this ledger,
  `docs/design/managed-repository-documentation-contract.md`,
  `docs/architecture/ADR-006-managed-repository-documentation-contract.md`,
  the 13 briefs under
  `docs/delivery/task-briefs/2026-09-01-managed-repository-documentation-contract/`,
  and their appended entries in `docs/delivery/task-briefs/SHA256SUMS` only.
- Planning: `/root/m1_planning` — final exact-byte GO; Required 0, Optional 0,
  Out of scope 0. Milestone ownership, trust-phase recovery, Issue #2, and
  Task 4B/Issue #1 sequencing are coherent.
- Architecture: `/root/m1_architecture` — final exact-byte GO; Required 0,
  Optional 0, Out of scope 0. Root-bound accepted snapshots, catalog
  transitions, evidence identity, rebind, and recovery contracts are coherent.
- TPM: `/root/m1_tpm` — final exact-byte GO; Required 0, Optional 0, Out of
  scope 0. `MDCP-COMPAT-1`, authorization gates, frozen-test ownership, and
  post-acceptance correction sequencing are coherent.
- QA/Test: `/root/m1_qa` — final exact-byte GO; Required 0, Optional 0, Out of
  scope 0. Migration, failure, replay, relaunch, root, transition, UI/readback,
  and unrelated-state coverage is testable and owned by bounded briefs.
- Delivery Management: `/root/m1_delivery` — final exact-byte GO; Required 0,
  Optional 0, Out of scope 0. Quiescence, release tokens, uncertain outcomes,
  recovery, ledger evidence, and live-use release gates are coherent.
- Security/Privacy: `/root/m1_security` — final exact-byte GO; Required 0,
  Optional 0, Out of scope 0. Authorized-root/no-follow boundaries, exact root
  and digest trust, bookmark/receipt redaction, backup custody, and atomic
  mutation/recovery rules are adequate for M1.
- No application code, tests, app launch, owner-data access, storage migration,
  guidance activation, repository document move, evidence mutation, deletion,
  external mutation, commit, or push occurred during M0-M1.

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
