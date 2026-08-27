# SQLite-23 independent QA/test review

**Verdict: FAIL — 1 Required finding.**

The implementation has strong execution evidence: the retained pre-change RED result proves the real onboarding callback failed with SQLite primary code 23, and all independently re-run Debug and Release test selections passed. The remaining failure is a required test-coverage gap in the populated-fixture preservation assertion.

## Evidence independently inspected

- Retained RED bundle: `/tmp/release-radar-sqlite23-populated-red-verified.xcresult` reports one selected test, **0 passed / 1 failed / 0 skipped**. Its sole failure is `OnboardingAcceptanceTests.testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation()` with `SQLiteError(code: 23, message: "not authorized")`, at `SQLiteConnection.swift:167`. This establishes that the real `FolderProjectOnboarding.prepare` callback path—not an empty-database substitution—failed before the correction.
- The current regression starts from a synthetic, populated version-9 store, explicitly recreates the retained legacy column/index/triggers, checks `PRAGMA user_version == 9`, then calls real `inspect` and `prepare`: `ReleaseRadarTests/OnboardingAcceptanceTests.swift:7-80`.
- The implementation allows only `SQLITE_READ` when the authorizer tuple names `audit_events`; all other named actions remain denied: `ReleaseRadarCore/Store/SQLiteConnection.swift:259-301`. Store-owned audit insertion stays after callback restrictions are removed and before commit: `ReleaseRadarCore/Store/DeliveryStore.swift:123-152`.
- The direct mutation matrix asserts primary code 23, sibling-write rollback, and no failed-transaction audit for INSERT/UPDATE/DELETE: `ReleaseRadarTests/StoreAcceptanceTests.swift:378-414`. The indirect `ON DELETE SET NULL` case asserts code 23, retained parent/child/audit/counts, and clean foreign-key checks: `ReleaseRadarTests/StoreAcceptanceTests.swift:416-469`.
- The onboarding case asserts new project/root/bookmark/pending marker/one audit, no phase/request/command/notification activity, foreign keys, repository sentinel/listing preservation, relaunch recovery, and balanced bookmark scope: `ReleaseRadarTests/OnboardingAcceptanceTests.swift:84-146`.
- Diagnostic tests assert required fixed fields and absence of supplied identifiers, reason, name, and SQL text: `ReleaseRadarTests/StoreAcceptanceTests.swift:471-516`; the emitted payload is fixed-field only: `ReleaseRadarCore/Store/SQLiteConnection.swift:399-423`.

## Independent commands and results

| Check | Result |
| --- | --- |
| Focused Debug `StoreAcceptanceTests` + `OnboardingAcceptanceTests`, fresh `/tmp/release-radar-sqlite23-qa-focused` | **51 passed / 0 failed / 0 skipped** |
| Full Debug suite, fresh `/tmp/release-radar-sqlite23-qa-full` | **167 passed / 0 failed / 0 skipped** |
| Release diagnostic with `ENABLE_TESTABILITY=YES`, fresh `/tmp/release-radar-sqlite23-qa-release-diagnostics` | **1 passed / 0 failed / 0 skipped** |
| `bash -n script/build_and_run.sh` | exit 0 |
| `script/build_and_run.sh --invalid-mode` | exit 2; zero stdout; usage on stderr |

No stage/install/launch mode was invoked. Static inspection confirms Release configuration and `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` at `script/build_and_run.sh:240-248`; `pkill`/`open` are confined to explicit launch helpers at `script/build_and_run.sh:283-290`, dispatched only by explicit legacy modes at `script/build_and_run.sh:299-322`. No `/Applications/ReleaseRadar.app` was opened or accessed, and all test artifacts were written under `/tmp`. The pre-existing unrelated dirty worktree was left untouched.

## Findings

### Required

1. **The populated-fixture preservation assertion is not field-for-field for the pre-existing audit row.** `populatedLegacyFixtureSnapshot` captures only `actor_id`, `reason`, `project_id`, `entity_type`, and `entity_id` for the existing audit record at `ReleaseRadarTests/OnboardingAcceptanceTests.swift:153-175`. The actual current audit schema and store insertion additionally contain `id`, `thread_id`, `thread_attribution`, and `created_at` (`ReleaseRadarCore/Store/StoreMigrations.swift:651-656`, `ReleaseRadarCore/Store/StoreMigrations.swift:520-528`, and `ReleaseRadarCore/Store/DeliveryStore.swift:135-145`). Therefore `XCTAssertEqual(preservedRows, preexistingRows)` at `ReleaseRadarTests/OnboardingAcceptanceTests.swift:114-130` cannot prove the brief's required field-for-field preservation of that pre-existing audit row. Expand the selected fixture snapshot to include every audit column (and retain the same pre/post equality assertion).

### Optional

- None.

### Out of scope / intentionally not performed

- Release staging and installation into `dist` or `/Applications`, exact-bundle identity verification, and owner launch/approval are separately gated delivery work. The brief requires all engineering reviews to close first; this read-only QA review intentionally did not invoke those mutating or launch modes.
- Runtime script promotion/install branches were not exercised because the assigned scope expressly allowed only static, syntax, and invalid-mode checks. This is a scope limitation, not a Required finding against this QA assignment.

## Conclusion

The root-cause RED evidence, authorizer behavior, rollback/foreign-key controls, persistence/relaunch/repository-no-write checks, and diagnostic privacy coverage are independently substantiated. Fix the one Required snapshot omission, then rerun the focused suite and the affected regression before seeking a passing QA decision.
