# Independent TPM Engineering Review — SQLite-23 Pre-Packaging Repair

## Decision

**Engineering GO.** Required blocker count: **0**.

This is an engineering-gate decision only. It does **not** authorize staging,
installation, artifact verification, a `Ready for owner validation` ledger
transition, or Done/Accepted.

**Next eligible gate:** an independent post-implementation Architecture
decision, followed by an independent Delivery Management engineering decision.
If both are GO with zero Required findings, Delivery Management may then
separately consider and explicitly record packaging/install authorization. This
TPM decision is not that authorization.

## Evidence and scope disposition

- The repair stays within its four-file implementation boundary: action-sensitive
  `audit_events` authorization and bounded diagnostics, Store/Onboarding
  regressions, and the Release-only nonlaunch staging/install script. The final
  fix-round-2 package changes only the populated blocker snapshot from a
  selected column list to `SELECT *`; it does not alter production or script
  behavior. Current SHA-256 values match the scoped package for the repair
  brief, SQLite source, Store tests, and script; the expected Onboarding hash
  differs only because of that documented final one-line test-oracle change.
- The owner failure is represented by both required forms of evidence: the
  synthetic diagnostic records `SQLITE_READ`, `audit_events`, `project_id`,
  primary `SQLITE_AUTH` 23, and the exact owner-visible text; the real
  `FolderProjectOnboarding.prepare` path fails with code 23 on the populated
  synthetic version-9 legacy-trigger database before the correction.
- The populated fixture has unrelated project, legacy active-phase relation,
  phase, ticket, blocker, and project-scoped audit history. Its final oracle
  compares complete pre-existing rows, including the nullable blocker field,
  and allows only the new onboarding project/audit delta. Reported coverage is
  the fix-round populated regression (1/1), focused Store/Onboarding suite
  (51/51), preceding full Debug suite (167/167), and Release diagnostic (1/1).
  The final test-only oracle correction appropriately reran the affected 1/1
  and 51/51 checks; no broad rerun is required for this TPM gate.
- The bounded diagnostic contract is covered in Release test configuration and
  the Security/Privacy re-review confirms authorizer logging no longer re-enters
  SQLite and the payload is limited to fixed/allowlisted data. Direct
  INSERT/UPDATE/DELETE and indirect foreign-key audit mutations remain denied
  and atomic in the recorded coverage.
- The script contract is Release-only, uses the durable `dist/ReleaseRadar.app`
  then `/Applications/ReleaseRadar.app` destinations, verifies strict signing,
  exact authority/team and entitlement structures, checks bundle identity, and
  uses fail-safe promotion/rollback. Disposable adversarial checks closed the
  original entitlement, signer, and rollback findings. Actual `dist` and
  `/Applications` artifacts were intentionally not created or inspected, so
  their required post-authorization QA/Security verification remains pending.
- Code re-review (fix round 1), QA re-review (fix round 2), and Security/Privacy
  re-review (fix round 1) each report zero open Required findings. The delivery
  ledger records the same state and correctly leaves Architecture, TPM, and
  Delivery engineering decisions outstanding before any packaging authorization.

## Finding classification

- **Required:** none open for this TPM engineering decision.
- **Optional:** associating the new prepare audit with a project/entity is
  expressly ruled Optional outside this repair's persistence contract; no work
  is opened by this review.
- **Out of scope:** migrations, recognized legacy schema objects, onboarding
  SQL, owner data, UI/product expansion, and unrelated dirty-tree changes.
  Packaging and installed-artifact verification are not out of the overall
  repair; they are deliberately later gated work.

## Owner terminal gate

The owner-only terminal condition remains intact. Even after a separately
authorized nonlaunch stage/install and independent QA/Security verification of
both durable paths, Delivery may record only **Ready for owner validation**.
Done/Accepted requires the owner to launch `/Applications/ReleaseRadar.app`,
exercise Initialize Project Tracking, and explicitly approve the result.

## Review limits

Read-only TPM review: no repository or ledger edit, Git mutation, test rerun,
bundle stage/install/launch, `/Applications` access, or owner-data access was
performed.
