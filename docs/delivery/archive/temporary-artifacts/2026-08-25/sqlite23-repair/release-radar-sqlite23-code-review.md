# Independent Code Review — SQLite-23 Repair

## Verdicts

- **Specification compliance: FAIL / CHANGES REQUIRED.** The authorizer repair and fixed-field SQLite diagnostics comply with the central repair contract, but the Release stage/install script and populated-state acceptance test leave three Required findings open.
- **Task code quality: FAIL / CHANGES REQUIRED.** The Swift production change is focused and readable, but the shell verifier has unsafe error/rollback control flow and the entitlement/preservation assertions are not fail-closed enough for this gate.
- **Required findings:** 3 (1 Critical, 2 Important).
- **Optional findings:** 0.
- **Out-of-scope findings:** 0.

Review boundary: only `/tmp/release-radar-sqlite23-review-package.md` was used to attribute the four authorized file changes against the exact pre-task snapshots. The broader dirty worktree was not used for attribution. The implementer report was treated as untrusted claims. I did not rerun test suites or inspect owner data/artifacts. I ran one focused, non-mutating Bash semantic check confirming that `set -e` is suppressed inside a function invoked as an `if` condition.

## Findings

### 1. Critical / Required — Final bundle verification can fail open or terminate before rollback

**Evidence:** `script/build_and_run.sh:17-19`, `script/build_and_run.sh:38`, `script/build_and_run.sh:149`, `script/build_and_run.sh:219-237`, `script/build_and_run.sh:277-278`.

`promote_verified_bundle` evaluates `verify_bundle` as an `if` condition at line 219. Bash suppresses `errexit` for commands in a function called from an `if` condition, so the bare strict-verification commands at lines 38 and 149 can fail while later metadata checks succeed and the function ultimately returns success. A damaged resource seal is a concrete example: `codesign --verify --deep --strict` can fail while `codesign -d`, identity metadata, and entitlement extraction still succeed, after which the script deletes the backup and accepts the promoted bundle.

The opposite path is also unsafe: explicit verifier failures call `fail`, which uses `exit 1`. When this occurs during the conditional final verification, the shell exits immediately and never reaches the restoration block at lines 226-236. If no prior final bundle existed, a failed promoted candidate is also left at the durable final path because line 227 restores only when `had_backup` is true. Finally, installation deletes the backup inside promotion before the separate final staged/installed identity comparison at line 278, so an identity failure there cannot restore the previous installed app.

**Impact:** The script can report success and delete the last verified backup after strict signature failure, or it can stop with an invalid `dist/ReleaseRadar.app` or `/Applications/ReleaseRadar.app` in place and no restoration. This violates fail-closed strict verification, final-bundle verification, transactional replacement, and rollback-on-any-failure acceptance criteria.

**Required correction:** Make verifier functions return nonzero rather than exit, make every consequential verification command explicitly propagate failure (independent of `errexit` context), and keep the prior bundle backup until final strict verification and exact identity comparison both succeed. On any post-promotion failure, move an unverified new bundle out of the final path even when no backup exists, and restore the backup when present.

### 2. Important / Required — Entitlement validation accepts extra application-group values

**Evidence:** `script/build_and_run.sh:59-75`, `script/build_and_run.sh:83-95`, `script/build_and_run.sh:104-110`.

`assert_exact_entitlement_keys` counts only top-level entitlement keys. Both main and Bridge checks then validate only `com.apple.security.application-groups:0`. A bundle containing the approved group at index 0 plus one or more unexpected groups passes the key-count and value checks. The scalar comparisons also do not independently establish plist value types, so textual equality is weaker than an exact entitlement-value comparison.

**Impact:** An app or Bridge Agent with an expanded application-group access boundary can pass the purported exact/fail-closed entitlement verifier, contrary to the requirement that missing, extra, or mismatched entitlement key/value data be rejected and that the approved sandbox boundary remain unchanged.

**Required correction:** Validate the complete entitlement structure and types, including that the application-groups array has exactly one element equal to `2UA854NLX4.com.rekonlabs.ReleaseRadar`, for both binaries. A canonical structured comparison against the approved entitlement contract is preferable to top-level key counting plus index-0 string reads.

### 3. Important / Required — The migrated-state test does not prove the required complete preservation or exact prepare-audit association

**Evidence:** `ReleaseRadarTests/OnboardingAcceptanceTests.swift:91`, `ReleaseRadarTests/OnboardingAcceptanceTests.swift:114-130`, `ReleaseRadarTests/OnboardingAcceptanceTests.swift:149-175`.

The preservation snapshot omits the seeded `phases` row entirely, despite seeding an active phase and requiring its exact values/relationship to survive. It also omits the legacy `projects.active_phase_id` value from the project snapshot and omits fields such as the audit row identity/timestamp. Counts at lines 127-130 cannot detect field changes to those rows. Separately, the new prepare-audit assertion at line 91 filters only by actor/reason and does not assert that the audit is scoped to the newly initialized project/entity; the total-audit `+1` check proves quantity but not association.

**Impact:** A regression that modifies the unrelated phase/legacy compatibility fields, or writes the one prepare audit with the wrong project/entity scope, can still pass. That falls short of the brief's explicit field-for-field, relationship-for-relationship pre-existing snapshot and “exact new onboarding state and its one prepare audit” delta.

**Required correction:** Include the full seeded phase row and the legacy active-phase field in the before/after oracle (and all relevant seeded audit identity/scope fields), then assert the newly added prepare audit's project/entity association to `projectID` in addition to actor, reason, and count.

## Compliant areas inspected

- `ReleaseRadarCore/Store/SQLiteConnection.swift:275-297` preserves transaction-control authorization ordering, permits only `SQLITE_READ` when `audit_events` is named, and denies every other protected-table action. This is the requested action-sensitive correction.
- `ReleaseRadarCore/Store/SQLiteConnection.swift:153-165` installs an unretained callback context only for the synchronous restricted body and removes the authorizer with `defer`; the connection remains alive for that lexical lifetime.
- `ReleaseRadarCore/Store/SQLiteConnection.swift:339-343` and `:399-422` constrain logged schema identifiers to `project_id`/`none` and emit only fixed event/stage, numeric/action, protected-identifier, and transaction-state fields. No SQL, bindings, SQLite message, owner identifier/path, or row value is included in the production payload.
- `ReleaseRadarTests/StoreAcceptanceTests.swift:376-420` covers direct callback INSERT/UPDATE/DELETE denial with code 23, sibling rollback, and absence of a failed-transaction audit. `:422-479` covers indirect `ON DELETE SET NULL` denial, preservation of the parent, cascade child and scoped audit row, audit count, and foreign-key integrity.
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift:7-146` exercises the real onboarding path on a synthetic version-9 legacy-trigger shape, verifies current availability/version, new project/root/bookmark/pending state, one prepare audit by actor/reason, no automatic phase/command/notification behavior, repository no-write, foreign-key integrity, relaunch recovery, root authorization, and balanced bookmark access. Finding 3 is limited to the missing exact preservation/audit-scope assertions.
- `script/build_and_run.sh:240-280` uses Release, disables injected base entitlements, separates nonlaunch stage/install modes, stages through same-parent temporary bundles, preserves `dist` during install, and compares the requested identity fields. `:283-322` confines `pkill`, `open`, and process assertions to explicit launch modes. Findings 1 and 2 prevent approval of the script as currently written.

## Gate disposition

Both verdicts remain **CHANGES REQUIRED** until all three Required findings are corrected and independently re-reviewed. No conclusion is made here about actual `dist` or `/Applications` artifacts; packaging/install was not authorized or performed within this review.
