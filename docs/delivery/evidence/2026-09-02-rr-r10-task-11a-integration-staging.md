# RR-R10 Task 11A integration and staged-candidate handoff

Non-authoritative verification evidence for the
[Task 11A brief](../task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11a-integration-staged-candidate-brief.md).
Current authorization and live delivery state remain in [progress.md](../progress.md).

## Integrated behavior

Five new XCTest cases consume existing production APIs; no production source,
schema definition, immutable fixture or configuration changed.

- `testTask11AV10MigrationIntegratesExactRoadmapTasksAndAcceptance` starts from
  the genuine SHA-256-verified v10 fixture, seeds nine Accepted historical
  tickets, migration-continuation RR-R10 and all eleven roadmap tickets, then
  opens the current store through the shipped migrations to v14. The retained
  pre-migration snapshot equals the original synthetic rows. Migration creates
  no inferred goals or task plans; only eligible legacy work has continuation.
- `testTask11AManagedV13BaselineIntegratesWithoutLosingDocumentation` separately
  uses the established recognized-v13 fixture convention, preserving genuine
  v11 continuation lineage. Read-only v13 inventory and the v14 inventory agree
  on managed bindings, roots, evidence, audits, receipts and preservation
  groups before ordinary commands. Neither path reads owner SQLite.
- Both paths create Pending-only tasks, chain exact revisions, establish all
  seven goal IDs and the literal twelve assignment pairs, finalize both plans,
  adopt only RR-R10 into Active, leave the six roadmap goals Planned and
  preserve old ticket content/lanes, active phase, dependencies, blockers,
  observed Codex context, document identity and unrelated state. Explicit
  incomplete/missing/stale revision acceptance rejects without any durable
  effect; exact revision 4 accepts only after all active tasks complete. Every
  attempted transition/upsert reopen rejects. Relaunch/replay preserves exact
  rows and receipts.
- The ordinary command writers (upsert, transition, review and completion),
  Backlog phase moves, sample writer and debug-capture writer are exercised.
  Sample/capture produce Ready assigned plans, no legacy continuation or task
  plans, and preserve all rows on repeated seeding.
- The onboarding/import test covers every source lane under both legacy and
  managed documentation, using real sandbox-local bookmarks. Source lanes
  import as Backlog with four stable review facts and zero tasks/plans/goals.
  Unbound managed import rejects, explicit binding enables exact artifact-ID
  evidence, and reimport preserves delivery/evidence identities and source
  bytes. Managed readback remains complete after store reopen.
- The notification test creates a real linked-Codex-goal blocked occurrence,
  then proves Delivery Goal revisions/finalization, task creation/completion,
  goal Awaiting acceptance and exact replay never impersonate Codex events.
  Existing acceptance/notification occurrence regressions remain green.

The integration goal definitions use synthetic test outcome/criteria text;
the approved goal IDs, titles and roadmap assignment sets are literal. They
are not an owner bootstrap manifest. Task 11B must use the approved full
outcomes/criteria in its separately reviewed operation package.

## Direct checks

Native commands used `ReleaseRadar.xcodeproj`, scheme `ReleaseRadar`, Debug,
destination `platform=macOS`, `-parallel-testing-enabled NO`, and task-local
`.build/rr-r10-task11a/DerivedData`. Debug build-for-testing passed. Fourteen
distinct focused cases passed across the final affected selections:

| Retained result under .build/rr-r10-task11a | Passing evidence |
| --- | --- |
| baseline.xcresult | 3 unchanged baseline cases: Task 7A managed lineage, task-only notification preservation, explicit onboarding import |
| integration-first.xcresult | New sample/debug writer case passed; other initial fixture cases were corrected below |
| integration-fixtures.xcresult | New Delivery Goal/task/Codex-notification case passed |
| integration-lineage.xcresult | New legacy/managed onboarding import case passed |
| integration-acceptance.xcresult; terminality.xcresult | Both new v10 and managed-v13 complete integration paths passed, including transition/upsert no-reopen |
| regressions.xcresult | 5 cases: exact acceptance notification, Accepted-upsert rejection, managed importer binding/classification, pending/invalid catalog preservation, packaged stdio initialize |
| documentation-regression.xcresult | Native actual-repository catalog/index conformance passed after the citation correction |

Initial failures were in new test setup/expectations: missing observation
timestamps, a read-callback PRAGMA that is correctly prohibited, inappropriate
index generation on the minimal fixture, path-only fake bookmark bytes at the
real onboarding/import boundary, and assumptions that review requests move
lanes or that old Accepted-transition errors use the new task-command envelope.
These were corrected only in the declared tests. The shortened historical
ledger link was restored to the catalog's explicit `Historical ` citation
format. No product defect was discovered or repaired.

The additional transport selection performs initialize over stdio only; it
never calls a tool or registers/connects/unregisters the fixed broker. All
data mutations use synthetic stores and the existing inert XCTest host.
Complete-scheme and packaged broker/lifecycle testing are **not performed**
here; Task 11B must satisfy the isolated service/session or explicitly approved
quiescence/restoration gate. Task 7A's old live authorization is not reused.
Task 5/10 UI matrices were not repeated.

## Exact staged Release candidate

The immutable [candidate identity](2026-09-02-rr-r10-task-11a-candidate.json)
records source commit, build command/toolchain, signed component identities,
all 18 regular-file SHA-256 values, framework symlink targets, archive hash and
the packaged-tools transcript hash. Its
[checksum manifest](2026-09-02-rr-r10-task-11a-SHA256SUMS) protects that record.

The canonical staged-candidate custody location is
`/Users/jroberts/Library/Application Support/RekonLabs/ReleaseRadar-MDCP/2026-09-02/task-11a/ReleaseRadar.app`.
The same candidate is retained as `ReleaseRadar-task-11a.zip` in that directory;
the archive SHA-256 is
`dbeb2df8b9a97fb3a6f7e57d47765da39ee802a869d1fe6e55e29e6796c1a44a`.
This owner-designated protected companion is durable, not build output.
Its parent is mode 0700; archive and transcript are 0600. Retain through at
least 2026-10-02 and do not delete without owner authorization.

Release build succeeded with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`.
Product source is unchanged from Task 10 merge
`609881fe79ec37180057fc6ed36b6ba49afaa8ab`; Task 11A adds only tests/docs.
The candidate is 0.1.6/build 1, schema 14, arm64, minimum macOS 14.0,
team `2UA854NLX4`, app CDHash `cd5e6016f9b82577fc53ab9a51cad5755551b13b`.
Strict deep app verification and individual verification of all three helpers
and Core passed. All five signed components have hardened runtime. App,
bridge and lifecycle-helper entitlements exactly match the existing source;
no entitlement was relaxed. All regular-file hashes match the build copy.
Packaged marketplace files match source. The staged AgentTools binary returned
24 tools via initialize/tools-list only, without launching the app or invoking
the broker. The installed app/plugin was not changed.

This is an Apple Development local-owner candidate, not Developer ID or
notarization evidence. Existing optional-`.none`, deprecated C-string initializer,
signed-framework stripping and App Intents metadata warnings remain; they are
not new Task 11A changes. A rebuild produces a different signed candidate:
Task 11B must consume these retained bytes and recheck their identity.

## Independent acceptance and checkpoint

Independent QA (`task11a_qa`, task
`01a062f7-f134-7de2-b746-a5ae79f7ce0d`) accepted this integration/staging
checkpoint with **Required 0**. The reviewer inspected all three test diffs,
the fourteen distinct passing cases, both final terminality paths, all 18
candidate file hashes, archive/transcript hashes and custody permissions.
No optional changes were requested. Full-scheme testing and owner installation
remain Task 11B gates; this verdict does not approve those actions.

No live Task 11A completion has been sent. Reviewed commit/push and an unchanged
exact revision-15 task-domain baseline must precede that operation. The live
accepted catalog remains v1/213 at
`07f804508a5053f1c5644de5f5f8142fb3f5c0531d850ebe3195d3cf9bdf476e`;
development documentation is pending later authorized deployment/acceptance.

Durable deliverables are the three integration files, brief, this handoff,
candidate identity/checksum and catalog/index/ledger records, plus the exact
bundle/archive/transcript in protected owner-designated custody. Temporary
Debug/Release build products, logs, xcresults and remaining synthetic fixture/
XCTest-host directories are retained under task-local build/native temporary
locations. No cleanup is authorized. Physical keyboard/spoken VoiceOver remain
unverified as previously recorded; Issue #9 remains owner-deferred.
