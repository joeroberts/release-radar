# RR-R10 Task 11A: Integration and staged Release candidate

Active controlling scope. Current state is in [progress.md](../../progress.md).

## Objective and outcome

Execute [Task 11A](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-11a-integrate-and-stage-the-release-candidate):
prove the integrated RR-R10 contracts using synthetic stores and retain one
exact, signed Release candidate for Task 11B. Consume the approved RR-R10
design and ADR-001/004/005/006; create no product abstraction.

## Scope and exclusions

Change only EndToEndAcceptanceTests.swift, NotificationAcceptanceTests.swift,
OnboardingAcceptanceTests.swift and necessary canonical brief, evidence,
progress, catalog and generated index records. This task is the single writer
in codex/rr-r10-task-11a. Coordinator 01a06184-6387-7c42-878e-695db0481a18
owns scope/currentness inspection and documentation accuracy; work may proceed
while the coordinator inspects this brief.

No product changes, fixture-file changes, installation or owner-app launch,
owner bootstrap/acceptance, Delivery Goal mutation, phase change, plugin or
configuration change, shared-service mutation, direct owner SQLite access,
cleanup, Task 5/10 UI matrix, or Issue #9 repair. A product defect stays as a
failing regression in one of the three declared files and is reported to the
coordinator with Task 11A Pending. No contingent repair row is created here.

## Dependencies

Task 10 PR #13 merged at 609881fe79ec37180057fc6ed36b6ba49afaa8ab; its exact
live completion at revision 15 and canonical reconciliation were independently
verified by the coordinator. This worktree starts at that freshly fetched base.
The immutable v10/v11/v12 fixtures and prior public APIs remain unchanged.
The separate old dirty owner checkout remains preserved.

## Material risks

Tests must exercise genuine migration lineage, exact revision/assignment
contracts and managed evidence without replacing behavior with test-only
shortcuts. Synthetic stores and the inert XCTest host do not by themselves
isolate the fixed broker service: no packaged broker/lifecycle tests run here.
Candidate custody must preserve the exact signed bytes and reproducible source
provenance; rebuilding does not produce an interchangeable candidate.

## Test strategy

Extend the existing XCTest fixtures: genuine checksum-verified v10 through the
shipped migrations to v14, plus the already-managed recognized v13 baseline
and its forward v14 migration. Assert pending-only creation, chained task
completions, exact task acceptance, seven Delivery Goals and literal roadmap
assignment sets, all ticket writers including Accepted-upsert rejection,
task-plan-free import, terminal Accepted state, notification preservation,
managed binding/evidence/receipt preservation and exact replay after relaunch.
Immediate GREEN against prior implementation is valid; fixture/test corrections
inside the three files are authorized.

Use native xcodebuild with .build/rr-r10-task11a DerivedData and named in-process
or stdio-only test selections. Full-scheme testing is deferred to Task 11B's
controlled service/session gate, not waived. Build Release without launching,
verify strict signatures, team, hardened runtime, entitlements, app/helpers/
framework and packaged plugin identity. Retain the exact candidate under the
owner-designated protected companion at
/Users/jroberts/Library/Application Support/RekonLabs/ReleaseRadar-MDCP/2026-09-02/task-11a/.
Store the canonical handoff, provenance and immutable hashes in
docs/delivery/evidence with catalog/index metadata. Run the native documentation
write/check commands and git diff --check. Preserve temporary outputs.

## Acceptance criteria

- Direct integration checks establish every named contract above without
  changing any owning product boundary or shared/owner service.
- One independently accepted Release candidate is retained in protected custody
  with actual app/helper/plugin identity, source/build provenance and hashes.
- After independent acceptance, commit/push reviewed tests and evidence first.
  A fresh complete task-domain inventory must match the retained Task 10
  revision-15 result before the installed supported typed command completes
  only rr-r10-task-11a (expected revision 15 to 16). Retain original request,
  exact result/replay and complete post-inventory preservation; report any
  mismatch before mutation. Inventory does not expose raw task rows.
- Record exact live revision/audit, close this brief completed/non-authoritative,
  reconcile ledger/catalog/indexes/handoff, run documentation check and readback,
  then commit/push reconciliation and merge exactly one PR to
  codex/release-radar-mvp. Development catalog acceptance remains pending;
  Task 11B is opened only by the coordinator under its separate authorization.

## Risk-triggered reviews

One independent QA review of the actual integration tests and staged-candidate
evidence. Specialist review is added only for a concrete changed risk boundary.
Successful direct checks and independent review are terminal absent a concrete
defect; no review-of-review or additional validation machinery.
