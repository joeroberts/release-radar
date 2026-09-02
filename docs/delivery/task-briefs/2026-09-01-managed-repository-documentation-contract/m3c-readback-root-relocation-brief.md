# MDCP M3C Brief: Evidence Readback and Repository-Root Relocation

**Status:** Completed. Retained as a non-authoritative record of the delivered
task scope; the original execution instructions below do not reopen work.
Current delivery state and authorization are in [progress.md](../../progress.md).

## Objective and user-visible outcome

Present managed evidence's resolved identity, lifecycle, authority, and
availability truthfully, and add an explicit owner-confirmed repository-root
rebind so managed evidence survives a folder move without row repair.

## Controlling references

- `docs/design/managed-repository-documentation-contract.md`
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-006-managed-repository-documentation-contract.md`
- `docs/architecture/ADR-007-proportional-delivery-validation.md`
- `docs/design/mockups/phase_board.png`
- `docs/design/mockups/needs_review.png`
- Accepted M3A-M3B contracts

The approved mockups establish the existing restrained board/detail/failure
language. This slice adds status truth to the existing evidence detail and
folder-recovery patterns; it does not add a new primary destination.

## Scope

In scope:

- projections/public readback for locator kind, artifact ID, resolved path,
  lifecycle, authority, availability, and recovery reason;
- accessible proposed/current/historical/unavailable, catalog-pending/
  unaccepted, and non-bound-root evidence presentation;
- explicit owner-selected root relocation with fresh bookmark, confirmation,
  project ownership and persisted accepted catalog repository ID/version/digest
  validation against the proposed root, exact bound-root replacement, audit,
  and relaunch persistence;
- managed identity stability and legacy path preservation;
- exact root `AGENTS.md` handoff-evidence rebind rule.

Out of scope:

- automatic root discovery/rewrite, generic legacy prefix relocation, evidence
  adoption execution, document moves, new navigation, Task 4B, or Issue #1.

## Dependencies and release gate

- M3B completed and accepted.
- Separate owner authorization for M3C.

## Anticipated files

- `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- `ReleaseRadarCore/Onboarding/ProjectBookmarkStore.swift` only if the accepted
  protocol cannot express a fresh rebind
- Focused documentation resolver/query contracts
- `ReleaseRadar/App/AppModel.swift`
- `ReleaseRadar/Projects/OnboardingView.swift`
- `ReleaseRadar/Projects/DashboardProjection.swift`
- `ReleaseRadar/Projects/TicketDetailView.swift`
- `ReleaseRadar/Shared/FailureStateView.swift`
- Existing onboarding, projection, route, and failure-presentation tests

## Data, security, and privacy

Relocation is owner-only, project-scoped, and requires a newly selected root to
contain the exact accepted catalog durably bound at v2 activation or later
acceptance; the old root may already be unavailable.
Reject stale/denied/mismatched bookmarks, symlink escape, roots owned by another
project, bad catalog snapshots, or source changes. Bookmark bytes never enter
audits, receipts, logs, or UI. Replay receipts persist stable IDs, expected
digests, and request hashes rather than raw bookmark bytes or unnecessary old/
new absolute paths. One transaction may change only the root row, bookmark row,
binding's exact root-row association, and a uniquely identified legacy old-root
`AGENTS.md` handoff evidence path, plus its audit/receipt. It revokes the old
bound bookmark and makes old/unbound roots ineligible for managed operations.
Zero matching old-root handoff rows permits rebind without an evidence update.
Exactly one matching row updates in that transaction.
Multiple, ambiguous, or mismatched rows reject the entire rebind with zero
root, bookmark, evidence, audit, or receipt changes. Managed and all other
legacy evidence remain immutable.

## Test-first strategy

RED/GREEN covers managed proposed/current/completed/superseded/archived/missing/catalog-
invalid/pending/unaccepted/root-unavailable/non-bound/checksum-invalid
projection and accessibility; root
move success; collision, stale bookmark, mismatch, symlink, late failure,
repository identity/version/digest mismatch, same-root unaccepted catalog
replacement, multiple/stale root rows, old-root rejection, new-root collision,
rollback, and denial; managed stability; zero-row and exactly-one-row AGENTS
handoff success;
multiple-row ambiguity, mismatch, late-failure rollback, exact replay,
arbitrary legacy preservation, no generic prefix rewrite, and relaunch.

## Happy and non-happy behavior

- Historical evidence can show Available and Non-authoritative together.
- Missing or invalid managed evidence preserves artifact identity and explains
  recovery.
- Confirmed root relocation preserves project and managed evidence identity.
- Failed relocation preserves the old authorized state and all unrelated data.

## Acceptance criteria

- UI/readback never equates availability with authority.
- Available proposed evidence is explicitly non-controlling and tested.
- Managed document paths are resolved, not stored as identity.
- Root relocation is explicit and audited, not same-root reauthorization.
- Rebind atomically replaces the bound-root association and bookmark; the old
  root cannot satisfy any managed operation after commit or relaunch.
- Zero/one/multiple/mismatched handoff-row behavior is exhaustive and the root,
  bookmark, evidence, audit, and receipt commit or roll back together.
- Legacy evidence changes only through M3B's exact reconciliation, except for
  the single exact old-root `AGENTS.md` handoff-row update expressly permitted
  inside the atomic M3C root-rebind transaction.
- Relevant UI is accessible and visually consistent with inspected references.

## Reviews and completion evidence

Required risk-triggered reviews: Code Review, QA, Architecture, and
Security/Privacy. TPM participates only if sequencing or dependencies materially
change. Planning is not an approval role. Delivery Management records concise
readback, relaunch, accessibility, screenshot, and audit-redaction evidence plus
residual risks and next eligible work; it is not an approval. Completion does
not authorize M4.
