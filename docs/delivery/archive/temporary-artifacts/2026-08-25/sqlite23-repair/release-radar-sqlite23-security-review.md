# SQLite-23 Repair — Independent Security/Privacy Review

**Verdict:** FAIL  
**Required findings:** 4  
**Optional findings:** 0  
**Out-of-scope items:** 2

This is the pre-packaging engineering review only. I did not stage or install a bundle, inspect `/Applications/ReleaseRadar.app`, access owner SQLite data or Keychain, mutate Git, or launch the normal application through `open` or any script launch mode.

## Scope and evidence integrity

- Reviewed the supplied repair brief, implementer report, scoped review package, repository `AGENTS.md`, and the binding store/signing boundary in ADR-001.
- The SHA-256 hashes of the brief, implementer report, four pre-change snapshots, and four current scoped files match the review package metadata.
- Current behavior was traced from the four scoped source files and the store transaction owner. ADR-001 requires the app process to remain the sole SQLite writer and all delivery mutations to remain transactional and audited (`docs/architecture/ADR-001-release-radar-boundaries.md:12-16`, `:114-116`).
- `git diff --no-index --check` produced no whitespace-error output for all four scoped snapshot/current pairs. Exit status 1 is expected because each pair differs.

## Required findings

### R1 — Authorizer denial diagnostics re-enter the SQLite connection

**Classification:** Required

**Evidence:**

- Both authorizers call `recordAuthorizerDenial` synchronously from inside the SQLite authorizer callback (`ReleaseRadarCore/Store/SQLiteConnection.swift:275-297`, `:325-331`).
- `recordAuthorizerDenial` obtains `isInTransaction` (`ReleaseRadarCore/Store/SQLiteConnection.swift:222-232`).
- `isInTransaction` calls `sqlite3_get_autocommit(databaseHandle)` (`ReleaseRadarCore/Store/SQLiteConnection.swift:169-170`).
- The local macOS SDK SQLite header documents the authorizer as running during prepare/reprepare and warns that the callback must not modify the invoking connection; irrespective of whether this read-only API is tolerated by the current SQLite build, the review requirement is stricter and explicitly requires that diagnostics not query SQLite from the authorizer.

**Impact:** Every denied transaction/savepoint, direct audit mutation, indirect audit mutation, or denied read-callback operation calls back into the same SQLite connection before returning `SQLITE_DENY`. This violates the required callback containment and creates an avoidable re-entrancy/availability risk on a security-failure path. I found no direct owner-data disclosure from this call, but the non-query requirement is not met.

**Required resolution:** Make the authorizer callback derive transaction state from fixed callback context or another precomputed non-SQLite value. The callback must not invoke any `sqlite3_*` operation or execute SQL while authorizing.

### R2 — Exact entitlement verification accepts additional application groups

**Classification:** Required

**Evidence:**

- The verifier checks the exact set of entitlement dictionary keys (`script/build_and_run.sh:59-75`) but checks only application-group element `:0` for the main app (`:83-95`) and Bridge Agent (`:104-110`). It never verifies the array count or rejects later array elements.
- A disposable synthetic plist with the exact expected keys, the approved group at index 0, and an additional `unexpected.extra.group` at index 1 was accepted by both current functions: `main_extra_app_group_exit=0 bridge_extra_app_group_exit=0`.
- A separate synthetic main entitlement plist containing `com.apple.security.get-task-allow=true` was correctly rejected with exit 1, so the defect is specifically nested entitlement values rather than unexpected top-level keys.

**Impact:** A signed product with access to an additional application-group container would pass the release gate. That weakens sandbox least privilege and could expose or permit modification of data shared through an unintended group. It also fails the explicit requirement to verify the exact intended main/bridge entitlements.

**Required resolution:** Verify the application-groups value as an exact one-element array for both products, in addition to the existing exact top-level key checks.

### R3 — Atomic promotion does not fail safe for every post-promotion failure

**Classification:** Required

**Evidence:**

- When no prior final bundle exists, a candidate that fails verification after the atomic rename is left at the final path; the no-backup branch has no removal/quarantine/rename-back action (`script/build_and_run.sh:219-237`).
- A disposable invocation of the exact `promote_verified_bundle` function forced candidate verification to pass and final verification to fail. It returned 1 but left `final.app` present and removed `candidate.app`: `no_prior rc=1 final_exists=yes candidate_exists=no`.
- With a prior final bundle, the same disposable test confirmed that the old bundle and failed candidate were restored to their respective paths: `with_prior rc=1 final_old=yes candidate_new=yes`. The defect is therefore the first-install/first-stage failure branch.
- The function deletes the prior backup immediately after its own final verification (`script/build_and_run.sh:219-223`), but installation performs an additional staged-versus-installed identity check only afterward (`:267-280`). If that final identity gate fails, the script exits after the rollback copy has already been destroyed.

**Impact:** A failed first stage/install can leave an unverified or tampered bundle at the durable handoff path despite returning failure. A later identity failure can similarly leave the new bundle installed without a recoverable previous bundle. This can cause loss of the last known-good application and creates a path for an unverified artifact to be mistaken for the accepted deliverable.

**Required resolution:** Treat every verification/identity check through completion as one promotion transaction. On failure, restore the previous verified bundle when one exists; otherwise remove or move the failed final bundle to a clearly non-final quarantine path. Do not delete the backup until all final identity checks have passed.

### R4 — Signing authority verification does not match the configured identity exactly

**Classification:** Required

**Evidence:**

- Release project configuration pins a full Apple Development identity (`ReleaseRadar.xcodeproj/project.pbxproj:283`).
- The script only requires an authority line beginning with `Authority=Apple Development:` and an exact team identifier (`script/build_and_run.sh:33-44`). It does not compare the authority line with the configured full identity.
- With `codesign` success mocked only for the disposable function test, metadata for `Apple Development: Different Signer (XXXXXXXXXX)` plus the expected team was accepted: `different_authority_same_team_exit=0`.

**Impact:** A product signed by a different Apple Development identity in the same team passes the configured-authority gate. Team membership remains checked, so this is narrower than accepting an unrelated team, but it weakens artifact provenance and fails the explicit configured authority/team requirement.

**Required resolution:** Compare the leaf authority with the exact configured identity (or another explicitly approved immutable signer identifier) as well as the team.

## Controls verified

### SQLite authorization and rollback

- Transaction/savepoint authorization is evaluated before the protected-table rule (`ReleaseRadarCore/Store/SQLiteConnection.swift:267-282`), and the control denies both `SQLITE_TRANSACTION` and `SQLITE_SAVEPOINT` (`:303-312`).
- For a reference naming `audit_events`, only `SQLITE_READ` returns `SQLITE_OK`; every other action returns `SQLITE_DENY` (`ReleaseRadarCore/Store/SQLiteConnection.swift:284-300`).
- The store begins the transaction, scopes the callback, removes restrictions before the store-owned audit insert, commits only after that insert, and rolls back on any error (`ReleaseRadarCore/Store/DeliveryStore.swift:116-153`).
- Direct callback `INSERT`, `UPDATE`, and `DELETE` coverage asserts code 23, sibling-write rollback, stable audit count, and no failed-transaction audit (`ReleaseRadarTests/StoreAcceptanceTests.swift:378-414`).
- The foreign-key `ON DELETE SET NULL` path asserts code 23 and preserves the project, cascade child, scoped audit project ID, audit count, and foreign-key integrity (`ReleaseRadarTests/StoreAcceptanceTests.swift:416-469`).
- Fresh targeted execution passed the direct mutation matrix, indirect mutation rollback, transaction-control, populated legacy onboarding, and diagnostic tests (5 passed, 0 failed).

### Authorizer context/lifetime

- The authorizer receives an unretained pointer to the root connection (`ReleaseRadarCore/Store/SQLiteConnection.swift:153-166`, `:335-337`). The root is strongly held by `DeliveryStore` and the local transaction/read implementation while the synchronous restriction body executes (`ReleaseRadarCore/Store/DeliveryStore.swift:123-130`, `:159-164`), and the authorizer is removed by `defer` before the wrapper returns. I found no dangling-context path in the reviewed synchronous call chain.
- R1 remains blocking because the live context is used to query SQLite from inside the callback.

### Diagnostic privacy

- Unified logging and in-memory capture receive only fixed event/stage names, integer result/action codes, fixed action names, allowlisted protected identifiers or `none`, and a Boolean (`ReleaseRadarCore/Store/SQLiteConnection.swift:363-423`).
- The protected column is reduced to exactly `project_id` or `none` (`ReleaseRadarCore/Store/SQLiteConnection.swift:339-343`). SQL text, bindings, SQLite messages, actor/reason values, owner identifiers, names, paths, bookmarks, and rows are not inputs to the payload builder.
- The privacy regression supplies synthetic actor/reason/project/entity/name/SQL values and asserts none appear (`ReleaseRadarTests/StoreAcceptanceTests.swift:471-516`). It passed in the targeted run. The only callback-safety defect found is R1.

### Synthetic populated fixture

- The legacy regression creates its database and repository tree under a unique temporary directory and uses generic synthetic project, phase, ticket, blocker, audit, sentinel, path, and bookmark values (`ReleaseRadarTests/OnboardingAcceptanceTests.swift:7-70`, `:1493-1522`, `:1593-1607`).
- It asserts the complete pre-existing synthetic rows/relationships remain equal and only project/audit counts increase as specified (`ReleaseRadarTests/OnboardingAcceptanceTests.swift:114-130`). No owner database, absolute owner project path, real bookmark, or copied owner row appears in the fixture.

### Release verifier behavior that passed

- Default and named nonlaunch stage/install modes do not call the launch helpers; `pkill` and `open` are confined to explicit launch modes (`script/build_and_run.sh:283-327`). Invalid mode returned exit 2 with zero stdout bytes.
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` is passed to every scripted Release build (`script/build_and_run.sh:240-249`). Exact top-level entitlement keys reject `get-task-allow` and other unexpected keys.
- The current disposable `/tmp` Release bundle independently passed the script's strict/deep verification. Direct inspection confirmed the current main/bridge products have the intended single app group, Sandbox, Hardened Runtime, expected team, configured current signer, and expected main/bridge identifiers. This proves the current disposable product, not the verifier's behavior against the adversarial cases in R2/R4.
- The script enumerates executable nested code and frameworks for individual strict signature/team checks in addition to deep bundle verification (`script/build_and_run.sh:137-171`).

## Verification commands and results

- Package SHA-256 comparison: matched all supplied metadata.
- `bash -n script/build_and_run.sh`: passed.
- `bash script/build_and_run.sh --invalid-mode`: exit 2; no build/stage/install/launch branch ran.
- Current verifier against `/tmp/release-radar-sqlite23-script-release-no-base-entitlements/Build/Products/Release/ReleaseRadar.app`: passed.
- Five selected Debug regressions using `/tmp/release-radar-sqlite23-security-review-tests`: **TEST SUCCEEDED**, 5 passed, 0 failed.
- Disposable promotion fault injection: restored an existing prior bundle, but left an invalid final bundle when no prior bundle existed.
- Disposable entitlement fault injection: rejected `get-task-allow`; accepted extra application-group array elements for main and bridge.
- Disposable signing-metadata fault injection: accepted a different same-team Apple Development leaf authority.

The selected XCTest run necessarily executed Xcode's temporary Debug test host from `/tmp` DerivedData. It did not invoke a script launch mode, use `/usr/bin/open`, interact with a UI, access `/Applications/ReleaseRadar.app`, or touch owner application data.

## Optional

None.

## Out of scope / deferred gates

1. Verification of actual `dist/ReleaseRadar.app` and `/Applications/ReleaseRadar.app` is a post-review gate after all Required findings close and Delivery authorizes stage/install. Neither path was inspected or mutated in this review.
2. Owner runtime validation and final Done/Accepted status remain exclusively owner-gated and were not assessed.

## Conclusion

The core action-sensitive SQLite repair is supported by current static and targeted runtime evidence: transaction control remains first, protected-table reads work, direct/indirect audit mutations fail closed with rollback, callback context lifetime is bounded, diagnostics contain only fixed allowlisted data, and the populated fixture is synthetic. The engineering Security/Privacy gate nevertheless **FAILS** until R1-R4 are resolved and independently reverified.
