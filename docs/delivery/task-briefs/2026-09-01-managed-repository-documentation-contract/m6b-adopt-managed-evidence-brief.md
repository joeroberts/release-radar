# MDCP M6B Brief: Adopt Exact Managed Evidence

**Status:** Proposed and unopened. M6A acceptance and separate explicit owner
authorization for the exact named evidence mutation are required.

## Objective and user-visible outcome

Convert only the owner-approved, exact M6A evidence matches to stable catalog
artifact identity, leaving ambiguous, arbitrary, missing, and unrelated
evidence on the legacy path model while all delivery state remains unchanged.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- Exact M6A inventory version/digest and owner-approved reconciliation map
- Accepted M3B command/replay contract

## Scope

In scope:

- one bounded catalog-digest-bound managed adoption request containing the
  complete approved set in one store-owned transaction;
- exact replay/recovery and supported readback/relaunch;
- semantic proof of permitted locator/audit/receipt changes only.

Out of scope:

- inferred matches, physical document movement, legacy path relocation unless
  separately named and authorized, root relocation, source changes, direct
  SQLite access, ticket/phase/task/notification mutation, or Task 4B.

## Dependencies and release gate

- M6A independently accepted with a stable exact inventory.
- Supported readback shows the durable bound root and accepted catalog
  repository ID/version/digest match the current snapshot; mismatch or pending
  transition stops before adoption.
- Owner approval names each evidence ID, prior path, artifact ID, catalog
  digest, project/ticket association, and expected outcome.
- Fresh pre-mutation supported semantic snapshot and recovery readiness.
- If the complete approved set exceeds the accepted M3B bound, stop for a
  revised atomic design before any mutation; do not split the set into partial
  commits.

## Anticipated files/state

- No application source or physical document changes.
- Supported app evidence locator/audit/receipt state only.
- Coordinator-owned ledger record after application/UI readback.

## Data, security, and privacy

Use the typed app command only. Revalidate the exact bound root and accepted
catalog snapshot immediately before mutation. Do not put absolute paths,
bookmark bytes, or document content in audit reasons. Preserve all associations
and availability truth. Uncertain outcomes use exact replay.

## Verification strategy

Before/after supported snapshots prove only the exact evidence locators plus
expected audits/receipts changed. Verify ticket associations, evidence IDs,
availability, current/resolved paths, lifecycle/authority, relaunch persistence,
and unchanged tickets, phases, tasks, dependencies, blockers, goals, reviews,
notifications, roots, and unrelated evidence.

## Happy and non-happy behavior

- Exact matches become managed and resolve the same current path.
- Uncertain records remain legacy without error-driven guessing.
- Stale catalog/request mismatch rolls back completely.
- Exact replay creates no duplicate audit or locator change.

## Acceptance criteria

- Every adopted row is traceable to the exact owner-approved M6A inventory.
- No filename-only, checksum-only, or broad prefix conversion occurs.
- Supported UI/readback and relaunch confirm identities.
- No document move or unrelated state change occurs.

## Reviews and completion evidence

Required reviews: QA, Architecture, Security/Privacy, TPM, and Delivery
Management. Record exact authorized request bodies/IDs safely, catalog digest,
audit/receipt IDs, before/after semantic comparison, replay/relaunch results,
remaining legacy inventory, and M7 eligibility in the ledger.
