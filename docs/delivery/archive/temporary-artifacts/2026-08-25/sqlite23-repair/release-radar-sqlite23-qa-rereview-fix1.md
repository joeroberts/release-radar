# SQLite-23 QA re-review — fix round 1

**Verdict: NOT ADDRESSED — 1 Required finding remains.**

The original QA finding is addressed: the populated fixture now snapshots every existing `audit_events` column via `SELECT *` and compares the result before/after. The Code Review additions are also addressed: the fixture now establishes and snapshots the legacy `projects.active_phase_id`, and snapshots the full seeded phase row. The single migrated regression independently passes.

## Confirmed addressed

- Full pre-existing audit row: `ReleaseRadarTests/OnboardingAcceptanceTests.swift:167` captures `SELECT * FROM audit_events WHERE project_id = 'existing-project'`; the audit map is included in the pre/post equality at lines `122-127`. This covers the audit columns omitted in the prior review (`id`, `thread_id`, `thread_attribution`, and `created_at`) as well as the previously captured scope fields.
- Legacy active phase: the fixture assigns `projects.active_phase_id = 'existing-phase'` at lines `35-58`, captures it at lines `162-167`, and asserts the seeded value at line `68`; the full project snapshot participates in the same equality comparison at lines `122-127`.
- Full phase row: `SELECT * FROM phases WHERE id = 'existing-phase'` at line `163` is captured as `phase` (lines `171-177`) and is preserved by the pre/post comparison at lines `122-127`.
- New prepare audit: per the amended scope ruling, the test asserts exactly one new audit by actor/reason count at lines `88-119`; no project/entity association assertion was added or required.

## Required finding

1. **The complete pre-existing snapshot remains short one existing blocker column.** The fixture snapshot selects only `id`, `project_id`, `ticket_id`, and `summary` for the seeded blocker at `ReleaseRadarTests/OnboardingAcceptanceTests.swift:166`, then uses that partial map in the purported field-for-field equality at lines `122-127`. The version-9 schema adds `blockers.resolved_at` in `ReleaseRadarCore/Store/StoreMigrations.swift:669-688` (line `672`); it is not asserted before or after. The repair brief still requires the complete pre-existing snapshot to remain unchanged field-for-field and relationship-for-relationship at `/tmp/release-radar-sqlite23-repair-brief.md:201`. Capture the full blocker row (for example, `SELECT *`) before granting a passing QA result.

## Independent focused result

Fresh disposable command:

```sh
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug \
  -derivedDataPath /tmp/release-radar-sqlite23-qa-rereview-fix1 \
  -resultBundlePath /tmp/release-radar-sqlite23-qa-rereview-fix1.xcresult \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests/testInitializeProjectTrackingAllowsLegacyForeignKeyAuditReadWithoutAllowingAuditMutation
```

Result: **1 passed / 0 failed / 0 skipped**. No new critical or important runtime test breakage was observed in the fix hunks. The remaining Required item is an assertion-coverage omission, not a failing product behavior in this run.

No repository files were edited; all test outputs are under `/tmp`. No stage, install, launch, `/Applications`, or owner-data action was performed.
