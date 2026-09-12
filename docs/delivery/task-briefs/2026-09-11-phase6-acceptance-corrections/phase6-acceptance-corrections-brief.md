# Phase 6 acceptance corrections

## Objective and outcome

Restore the focused Phase 4–6 and signed agent-bridge acceptance lanes to green,
then produce a fresh Phase 6 acceptance DMG. Preserve raw UTF-8 identity semantics,
production migration strictness, no-follow document safety, and the signed plugin
lifecycle contract.

## Scope and exclusions

Include the byte-distinct Delivery Goal identity regression, two stale legacy
migration fixtures, two physically non-canonical XCTest temporary-root fixtures,
agent-bridge tool-schema and plan-readiness fixture drift, signed transport test
registration ownership, and the release verifier's stale entitlement expectation.
Add only focused regression coverage and update the existing owner acceptance
evidence for the replacement candidate.

Do not change persistence schemas, normalize stored identifiers, relax migration or
no-follow validation, change public tool semantics, add dependencies, launch or
install the owner app, edit owner SQLite, publish, push, open a PR, merge, or start
Phase 7. Preserve the existing diagnostic DMG and temporary build artifacts.

## Dependencies and boundaries

Start from local commit `d5f1cebad75b6fea6d00693a2b02a3c850dd82d7` on
`codex/phase6-owner-acceptance`. ADR-001, ADR-004, ADR-006, ADR-007 and the
full-product plan remain controlling. SQLite identity is byte-exact; Swift keys
that represent persisted identity must match it. Migration fixtures may unwind
newer empty schema only in dependency-safe order. The repository reader continues
to reject symlink ancestors. Signed transport tests may manage only registration
they create and must restore a clean initial state; any live OS service mutation is
subject to its existing explicit authorization boundary.

No production migration or recovery format changes are intended. The fixture
corrections only reconstruct truthful historical baselines. Future consumers keep
the existing tool names and 37-tool schema.

## Material risks

- Canonically equivalent Swift strings can compare equal while their stored UTF-8
  identities are distinct.
- Fixture teardown can conceal malformed migration state if it drops nonempty data.
- Relaxing the no-follow reader would weaken a security boundary.
- Signed transport tests can disturb an owner-managed service unless registration
  ownership and initial/final state are explicit.

## Test strategy and acceptance criteria

Use existing failing tests as the initial red evidence, then add the smallest direct
identity regression test before production code. Run the affected planning,
successor, proposal, lifecycle, history, migration, recovery and shared-execution
suites. Run signed agent-bridge and plugin-lifecycle tests serially and separately
from unsigned sandboxed core tests.

Acceptance requires: the five focused Phase 4–6 failures pass; byte-distinct goal
IDs finalize and transfer independently; historical fixtures migrate without
weakening production checks; no-follow tests use a physically canonical root while
the reader still rejects unsafe roots; the transport schema/readiness tests reflect
37 tools and complete obligations; agent bridge passes 16/16 and plugin lifecycle
passes 14/14 when the signed-service test boundary is authorized; and a newly named,
strictly signed, verified DMG is produced from the corrected committed source.

## Assignment, review and endpoint

This existing delivery task owns the bounded source, tests, documentation and
packaging corrections at the assigned runtime model/effort; the interface does not
expose an independent settings readback, so no escalation is claimed. The ceiling
remains Astra High and Ultra is prohibited. The parent orchestrator owns the
progress ledger and integration coordination.

One fresh independent code/QA reviewer must review the exact local candidate and
cover the identity, migration, symlink and signed-service boundaries. Only Required
findings block. The endpoint is focused verification, a fresh DMG, updated canonical
evidence, and scoped local commits. Push, PR, merge, installation and owner app or
database state remain unauthorized.

## Completion

Completed on 2026-09-11 at correction source
`acc740113d1e7e056b5e7f1b2e3a0e3e21f24c27`. The exact six focused regression
tests passed with zero failures; the affected unsigned suites passed 114 of 114.
After an initial signed Debug harness build omitted `get-task-allow` and stalled
before loading XCTest, a normal signed Debug test host ran the service suites:
Agent Bridge passed 16 of 16 and plugin lifecycle passed 14 of 14. BridgeAgent
registration returned to absent and the pre-existing owner lifecycle helper kept
the same process identity.

Independent review of the exact correction commit reported no Required or Optional
findings. Package commit `09caafe0108496297684089603aa04c0cfffe361`
contains the verified `ReleaseRadar-0.1.9-acc7401.dmg`; the updated manual guide is
committed separately. No push, PR, merge, installation, installed owner-app launch,
owner SQLite access, or Phase 7 work occurred; XCTest launched only its isolated
signed Debug host.
