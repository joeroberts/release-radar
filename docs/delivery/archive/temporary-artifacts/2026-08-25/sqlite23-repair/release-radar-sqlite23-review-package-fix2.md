# SQLite-23 fix-round-2 scoped review package

- Requirements: `/tmp/release-radar-sqlite23-repair-brief.md`
- Implementer report with appended fix round: `/tmp/release-radar-sqlite23-implementer-report.md`
- Prior reviewed package: `/tmp/release-radar-sqlite23-review-package-fix1.md`
- Scope: one test-oracle query change; production and script files are unchanged.

```diff
--- ReleaseRadarTests/OnboardingAcceptanceTests.swift (fix round 1)
+++ ReleaseRadarTests/OnboardingAcceptanceTests.swift (fix round 2)
@@
-                let blocker = try connection.row("SELECT id, project_id, ticket_id, summary FROM blockers WHERE id = 'existing-blocker'"),
+                let blocker = try connection.row("SELECT * FROM blockers WHERE id = 'existing-blocker'"),
```

Current location: `ReleaseRadarTests/OnboardingAcceptanceTests.swift:166`.

Verification reported in the appended fix report:

- Populated v9 regression: `/tmp/release-radar-sqlite23-fixround2-onboarding.xcresult` — 1 passed, 0 failed, 0 skipped.
- Focused Store + Onboarding: `/tmp/release-radar-sqlite23-fixround2-focused.xcresult` — 51 passed, 0 failed, 0 skipped.
