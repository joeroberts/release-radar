# SQLite-23 Repair — Security/Privacy Re-review, Fix Round 1

**Overall verdict:** PASS  
**Open Required findings:** 0  
**New Critical/Important security or privacy breakage:** None found

This is the scoped pre-packaging re-review of R1-R4. No repository file or Git state was modified. No bundle was staged, installed, or launched; `/Applications/ReleaseRadar.app`, owner SQLite data, owner project data, and Keychain were not accessed.

## Evidence integrity and scope

- Read the amended repair brief, appended implementer report, prior Security/Privacy report, previous scoped package, and fix-round-1 package.
- The current brief, implementer report, and four scoped repository files match the SHA-256 values in `/tmp/release-radar-sqlite23-review-package-fix1.md`.
- Compared the current implementation with the original finding paths, rather than treating the implementer report or prior green results as proof.
- Re-ran the inspected disposable adversarial harness under `set -u -o pipefail` with no `set -e`, plus the current verifier against the existing disposable `/tmp` Release product. No stage/install/launch mode was called.

## Per-finding verdicts

### R1 — Authorizer denial diagnostics re-enter SQLite

**Verdict: ADDRESSED**

The original path was authorizer callback → `recordAuthorizerDenial` → connection `isInTransaction` → `sqlite3_get_autocommit`. That path no longer exists.

- Transaction and read wrappers compute `isInTransaction` before registering the authorizer and store only that Boolean in a short-lived `SQLiteAuthorizerContext` (`ReleaseRadarCore/Store/SQLiteConnection.swift:153-168`, `:248-254`).
- The callback dereferences only the immutable Boolean and forwards fixed values to `SQLiteDiagnostics` (`ReleaseRadarCore/Store/SQLiteConnection.swift:335-350`). The complete callback/denial-helper region contains no `sqlite3_*` call or SQL execution (`:256-350`).
- The context is strongly held across the synchronous restricted body with `withExtendedLifetime`, and the authorizer is removed by `defer` before the wrapper returns (`:153-168`). There is no reachable callback after the context lifetime ends.
- Legitimate behavior is preserved: transaction/savepoint control still executes first, only protected-table `SQLITE_READ` is allowed, and all other protected-table actions remain denied (`:264-310`).

The non-authorizer prepare/step failure path may still query extended code and transaction state after SQLite returns an error (`:224-236`); that is outside the authorizer callback and does not recreate R1.

### R2 — Exact entitlement verification accepts extra application groups

**Verdict: ADDRESSED**

- The script constructs fixed approved main and Bridge entitlement plists with Boolean Sandbox/capability values and exactly one application-group string (`script/build_and_run.sh:82-120`).
- It parses both actual and expected plists with `plutil`, then compares the complete canonical XML values (`script/build_and_run.sh:122-163`). Extra keys, extra array members, missing members, and type/value differences therefore return nonzero.
- Fresh disposable adversarial execution rejected both a main plist and a Bridge plist containing the approved group at index 0 plus an additional group.
- The same verifier accepted the existing disposable Release product, proving the approved one-element structures remain usable.

This closes the unintended shared-container access path while preserving the intended main/Bridge app group.

### R3 — Promotion is not fail-safe across post-promotion verification/identity failures

**Verdict: ADDRESSED**

- `verify_bundle`, signature, metadata, entitlement, and identity functions now explicitly test consequential command results and return nonzero; propagation does not rely on ambient `set -e` (`script/build_and_run.sh:18-282`).
- Promotion verifies the candidate and derives its identity before touching the final path; an existing final is itself verified and retained as a backup (`script/build_and_run.sh:305-343`).
- After the rename, both strict bundle verification and exact expected-versus-final identity complete before backup deletion (`:345-371`).
- Every post-promotion verification/identity failure moves the failed final out of the final path and restores the prior backup when present (`:284-303`, `:353-366`). With no prior bundle, the final path is cleared into a uniquely named failed path. If restoration itself fails, both the failed and prior backup artifacts are retained and their paths are reported; the promotion still returns nonzero.
- Stage and install callers compute source identity before promotion and pass it into the same promotion transaction; there is no later source/target identity gate after backup deletion (`:388-423`).

Fresh adversarial execution, intentionally without `set -e`, passed all of these cases:

1. strict verification failure returned nonzero;
2. first-promotion failure cleared the final path and retained the failed candidate;
3. replacement failure restored the prior final;
4. final identity mismatch restored the prior final before backup deletion; and
5. injected restoration failure retained/reported both failed and backup paths and returned nonzero.

The original unverified-final and lost-rollback paths are closed. Backup cleanup failure leaves a verified final plus the prior backup and returns nonzero (`:368-370`), which is fail-safe and does not discard the known-good artifact.

### R4 — Signing authority verification is not exact

**Verdict: ADDRESSED**

- The script pins the configured leaf authority and team (`script/build_and_run.sh:7-9`).
- Signed-code verification now requires an exact complete metadata line for `Authority=$SIGNING_AUTHORITY` and an exact `TeamIdentifier=$TEAM_ID` line after strict signature verification (`script/build_and_run.sh:36-60`).
- Fresh disposable adversarial metadata using a different Apple Development signer with the expected team returned nonzero.
- The existing disposable Release product passed the exact authority/team verifier, so legitimate configured signing remains supported.

This closes the same-team/different-leaf provenance gap.

## New-breakage review

No new Critical or Important security/privacy breakage was found in the fix hunks.

- Authorizer behavior remains action-sensitive and transaction control remains first (`ReleaseRadarCore/Store/SQLiteConnection.swift:256-310`).
- The new authorizer context contains only a Boolean and has a synchronous, explicitly extended lifetime; it cannot carry SQL, bindings, messages, owner identifiers, paths, bookmarks, or rows (`:153-168`, `:248-254`).
- Diagnostic construction remains limited to fixed event/stage labels, SQLite numeric codes, fixed action names, hardcoded/sanitized protected identifiers, and the Boolean transaction flag (`ReleaseRadarCore/Store/SQLiteConnection.swift:352-475`). Unified logging and the bounded 32-entry in-memory capture receive the same payload (`:423-435`, `:478-497`).
- The current diagnostic privacy regression still asserts that supplied synthetic actor, reason, project/entity IDs, name, and SQL text are absent (`ReleaseRadarTests/StoreAcceptanceTests.swift:471-516`).
- The populated compatibility fixture continues to use a unique temporary tree and synthetic values. Its stronger snapshot now preserves all phase/audit fields and the legacy `active_phase_id` relation without introducing owner data (`ReleaseRadarTests/OnboardingAcceptanceTests.swift:7-75`, `:157-187`).
- Script error output contains fixed descriptions and artifact paths only; it does not read or print application data.

## Commands and fresh results

- `bash -n script/build_and_run.sh` — passed.
- `bash /tmp/release-radar-sqlite23-fixround-adversarial.sh` — passed every R2/R3/R4 adversarial case. The harness runs with `set -u -o pipefail`, not `set -e`, so verifier rejection does not depend on suppressed errexit behavior.
- Direct `verify_bundle` against `/tmp/release-radar-sqlite23-script-release-no-base-entitlements/Build/Products/Release/ReleaseRadar.app` — passed strict/deep signatures, exact authority/team, Hardened Runtime, exact main/Bridge entitlement plists, embedded signed code, bundle identity, and manifest checks.

No XCTest command was rerun in this re-review because the four fix-round doubts were settled by exact static paths and the disposable shell adversarial checks, and the task prohibited app launch. Existing fix-round test evidence reports the focused suites, full suite, populated legacy regression, and Release diagnostic regression green; those reports were treated as supporting evidence, not as the sole proof for R1-R4.

## Conclusion

R1: **ADDRESSED**  
R2: **ADDRESSED**  
R3: **ADDRESSED**  
R4: **ADDRESSED**

There are **0 open Required findings** from this Security/Privacy re-review. Actual `dist/ReleaseRadar.app` and `/Applications/ReleaseRadar.app` verification remains the separate post-authorization artifact gate and was not performed here.
