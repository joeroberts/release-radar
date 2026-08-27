# Independent Code Re-review — SQLite-23 Fix Round 1

## Verdict

- **Specification compliance: PASS for this code-review gate.** All three original Required findings are addressed within the four-file snapshot boundary.
- **Task code quality: PASS for this code-review gate.** No new Critical or Important defect was found in the fix-round changes.
- **Open Required findings from this review:** 0.
- **New Critical/Important breakage:** None found.

This verdict covers source/test/script review only. It does not authorize or claim staging, installation, artifact verification, owner runtime validation, or completion of the separate QA/Architecture/Security/TPM/Delivery gates.

Review boundary: `/tmp/release-radar-sqlite23-review-package-fix1.md` was compared with the prior reviewed package and exact pre-task snapshots. The implementer report was treated as claims. I did not inspect the broader dirty worktree, owner data, `dist`, or `/Applications`, and did not rerun broad suites. No focused command was needed to resolve a code question in this round.

## Original finding dispositions

### 1. ADDRESSED — Critical promotion verification/rollback control flow

**Evidence:** `script/build_and_run.sh:18-30`, `:36-60`, `:189-242`, `:284-373`, `:388-423`.

- Verifiers now report and return nonzero instead of calling `exit`; every consequential strict-signature, metadata, Hardened Runtime, entitlement, and embedded-code check is explicitly tested and propagated. This removes the prior dependence on Bash `errexit` inside an `if`-condition function.
- `promote_verified_bundle` verifies the candidate and any prior final, moves the prior verified final to backup, verifies the promoted final, computes and compares its complete expected identity, and only then removes the backup.
- Any post-promotion verification or identity failure calls `recover_failed_promotion`, which moves the failed new bundle out of the durable final path even when there was no prior final, and restores the backup when present. Restoration failure returns failure while retaining and reporting the failed/backup locations.
- Stage and install capture the source identity before promotion and pass it into promotion, so the final identity check occurs before backup deletion rather than afterward.

The original fail-open strict-verification path, `exit`-before-restoration path, failed-first-promotion residue, and backup-before-identity-deletion defect are no longer present.

### 2. ADDRESSED — Exact nested application-group entitlement validation

**Evidence:** `script/build_and_run.sh:82-163`, `:225-231`.

The script parses both actual and fixed expected entitlement plists through `plutil` and compares their complete canonical XML structures. The approved main structure contains exactly the four allowed keys with correct Boolean/array types; the Bridge structure contains exactly its two allowed keys. Each application-groups array contains exactly one value, `2UA854NLX4.com.rekonlabs.ReleaseRadar`. Extra groups, extra keys such as `get-task-allow`, wrong values, and type mismatches therefore change the canonical structure and fail. Both the main app and Bridge Agent invoke these exact checks during bundle verification.

### 3. ADDRESSED — Complete populated migrated-state preservation

**Evidence:** `ReleaseRadarTests/OnboardingAcceptanceTests.swift:57-75`, `:122-138`, `:157-186`.

The synthetic legacy shape now gives the unrelated project a non-null legacy `active_phase_id`, snapshots and asserts that field, includes the complete seeded phase row, retains the explicit active-phase relationship/ticket/blocker rows, and snapshots the complete scoped audit row with `SELECT *`. Before/after row dictionaries are compared exactly, while the count oracle permits only one new project and one new audit and requires phase/relationship/ticket/blocker counts to remain unchanged. This closes the missing phase, legacy-field, and audit-identity/timestamp preservation gaps from the original review.

## Separately ruled prepare-audit association issue

The ruling is internally consistent. The amended brief defines successful Initialize evidence as exactly one audit with actor `release-radar-onboarding` and reason `Prepare folder-backed project onboarding`, explicitly preserves the existing association contract, and excludes a `ProjectOnboarding.swift` behavior change from this repair. `OnboardingAcceptanceTests.swift:94` and `:118-119` enforce that actor/reason/count contract. Per the supplied ruling, project/entity association is Optional/out of this repair and is not merged into finding 3 or counted as Required.

## Configured signer enforcement

**Verified in code:** `script/build_and_run.sh:7-9`, `:36-60`, `:212-239`.

`verify_signed_code` requires strict signature verification plus an exact metadata line for both:

- `Authority=Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`
- `TeamIdentifier=2UA854NLX4`

The check is applied to the main app, Bridge Agent, every discovered executable, and every discovered framework. A different Apple Development identity from the same team no longer passes. The top-level bundle also independently receives deep/strict verification.

## Additional fix-round inspection

- `ReleaseRadarCore/Store/SQLiteConnection.swift:153-169`, `:245-252`, `:335-352` replaces the prior connection pointer with a short-lived immutable authorizer context containing only the precomputed transaction-state Boolean. `withExtendedLifetime` keeps it alive through the synchronous restricted callback body, and authorizer denial logging no longer calls a SQLite API from inside the SQLite callback. The original narrow `SQLITE_READ` allow / all-other-protected-actions deny behavior remains intact.
- Launch separation remains intact: nonlaunch stage/install paths contain no `pkill`, `open`, executable launch, or process assertion; those operations remain confined to explicit launch modes at `script/build_and_run.sh:425-464`.
- The Store acceptance changes are unchanged from the prior reviewed package and retain direct/indirect mutation denial and rollback coverage.

## Gate disposition

**Code review GO for fix round 1: zero open Required findings.** Later independent roles and the separately authorized artifact stage/install checks remain mandatory before Ready for owner validation.
