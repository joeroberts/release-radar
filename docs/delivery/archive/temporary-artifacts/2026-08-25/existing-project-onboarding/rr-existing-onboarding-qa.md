# QA Gate — Existing-Project Onboarding

## Slice decisions

| Slice | Decision | Gate |
| --- | --- | --- |
| **Attach Folder to Existing Project** | **QA GO** | Test plan is sufficient with the corrections below. Implementation remains **release NO-GO** until RR-R7 closes or TPM/Delivery Manager explicitly reprioritize the sole writer. |
| **Portable archive contract/exporter** | **NO-GO** | No approved complete-graph schema, authoritative exporter, or exporter-produced fixture exists. QA must not invent the contract. |
| **Import Existing Project importer/UI** | **NO-GO** | The current Rekon importer is a partial one-time seed, not a portable restore path. Do not add the workflow button, importer, or inferred fallback yet. |
| **Combined two-labelled-workflow acceptance** | **NO-GO** | Final verification of both exact labels—“Attach Folder to Existing Project” and “Import Existing Project”—waits for the portable-import gate. Do not add a nonfunctional placeholder. |

The ledger currently releases only RR-R7 as the next writer ([progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:27)).

## Required QA correction to the brief

The new preservation tests around `associateFirstProjectRoot` are characterization/regression tests, not necessarily RED: the service already exists and has basic coverage ([ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351), [OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:445)). They must pass before UI implementation and remain GREEN.

The legitimate RED cases are the missing general onboarding workflow, explicit workflow label and confirmation, target-project selection after refresh, and committed-but-refresh-failed presentation. Do not manufacture a service RED by changing established behavior.

## Minimum attachment fixtures

Use only the current XCTest target and existing temporary-store patterns:

- `OnboardingAcceptanceTests`: reuse `FolderFixture`, bookmark fakes, and `DashboardSampleData.seedIfNeeded`.
- Make the target project rootless but populated. Add only records missing from the sample that are necessary to represent every current project relationship: a second phase and phase dependency, thread exclusion, and project-scoped notification occurrence/history.
- Seed one unrelated project owning a canonical folder and address it through a symlink-equivalent URL.
- Add one local snapshot helper in the test file—not a generalized harness—that captures ordered values for projects, active phases, phases, tickets, both dependency types, blockers, evidence, exclusions, observed threads/goals, thread/ticket-goal links, reviews, completions, notifications/occurrences, prior audits, unrelated-project rows, command-request counts, and global alert rules.
- `AppRouteTests`: use the existing temporary `DeliveryStore`/`AppModel` pattern. A small injected dashboard-loading closure, analogous to `RouteReviewInboxLoader`, is acceptable solely to force post-commit refresh failure. No coordinator or UI-test harness.

## Attachment test-first acceptance

### Baseline characterization

`testAttachFolderPreservesExistingProjectGraphAndAddsOnlyAuthorization`

- Call `associateFirstProjectRoot` directly.
- Every pre-existing snapshot value remains equal.
- The only additions are:

  - one canonical `project_roots` row;
  - one non-stale, nonempty bookmark for that path;
  - one audit with actor `release-radar-owner`, reason `Associate first project folder authorization`, project scope, entity type `project`, and the target project ID.

- `withAuthorizedProject` succeeds after association and scope starts/stops remain balanced.
- No prepare, first-phase request, finish, Rekon-import, dashboard-open, review-decision, command-request, notification, or delivery-record duplication occurs.
- The same state survives store relaunch.

### Rollback characterization

Use table-driven cases where practical:

- Canonical or symlink-equivalent folder already owned → `.rootAlreadyOwned`.
- Target has root only, bookmark only, or both → `.projectRootAlreadyAssociated`.
- Missing project → `.projectNotFound`.
- Invalid folder, bookmark creation/resolution failure, stale or mismatched bookmark, or denied scope → corresponding typed authorization error.

For every failure:

- The entire pre/post snapshot is equal.
- No root, bookmark, audit, onboarding marker, importer record, or partial repair is created.
- Security-scope accounting is balanced.

### True application-boundary RED cases

`testAppModelAttachRefreshesProjectsAndSelectsTargetWithoutOnboardingOrImport`

- Seed at least two projected projects so the target is not the first fallback.
- Confirm attachment through the application boundary.
- Assert `selection == .projects`, `currentProjectID` and `currentProject` identify the target, and the refreshed projection retains the complete graph.
- Assert exactly the one authorization audit and no onboarding/import/dashboard-open audit.

`testCommittedAttachmentIsNotPresentedForRetryWhenProjectionRefreshFails`

- Allow association to commit, then force the injected projection reload to fail.
- Assert the root/bookmark/audit exist exactly once.
- Present a warning equivalent to “Folder attached; refresh needed — do not retry,” with an explicit Reload action.
- Never present the operation as an attachment failure or offer attachment retry.
- Explicit Reload restores the Projects surface with the target selected.

Focused GREEN command:

```text
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-existing-attach \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests
```

Then require the current full suite and configured non-launching Debug build.

## Conditional portable-import acceptance

Do not write contract-dependent RED tests until Product and Architecture approve the schema and an authoritative exporter produces the fixture. When eligible, the minimum cases are:

- Recognize only the approved versioned archive; explicitly reject arbitrary Markdown and Rekon `dashboard-status.json` as complete-project sources.
- Preserve archive bytes and reject unknown versions, missing sections, duplicate identities, oversized input, symlink substitution, unauthorized paths, and malformed relationships.
- Export then import into an isolated store; after relaunch compare every contract-defined node, edge, status, and history record.
- Apply the approved ID collision/remapping policy and roll back the entire project, authorization, and import audit on any invalid reference, cycle, collision, or truncated section.
- Generate fresh destination authorization. Never deserialize stored roots, bookmark bytes, credentials, or other device-local material.
- Preview exact counts and exclusions; Cancel/Escape/standard close create no project/root/bookmark/audit.
- Successful import refreshes and selects the new project. Post-commit refresh failure is saved/non-retryable.

The existing no-Markdown-inference regression remains mandatory GREEN ([RekonImportAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/RekonImportAcceptanceTests.swift:6)). Its current `ImportPreview` covers only phases, dependencies, tickets, evidence, and generated review items ([DeliveryArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/DeliveryArtifactImporter.swift:9)).

## Live isolated macOS QA

### Attachment slice

Use a never-before-used alternate Debug bundle identifier with `--rr10-capture`; this supplies the existing populated rootless sample while suppressing external services. Never launch the owner bundle or inspect owner data.

Verify through accessibility and screenshots:

- Exact visible label **“Attach Folder to Existing Project.”**
- Only eligible rootless projects are selectable.
- Preview/confirmation names the target project and chosen folder and clearly states that existing records are preserved.
- Click Cancel, Escape, folder-chooser cancellation, and standard close before confirmation each cause zero durable changes and reopen cleanly.
- During a confirmed in-flight transaction, Cancel, Escape, and standard close cannot dismiss into an unknown result.
- Already-rooted/owned-folder rejection is actionable and keeps the workflow open without mutation.
- Success returns to Projects, selects the target as current, refreshes its card/sidebar context, and does not auto-open Overview or add a dashboard-open audit.
- Relaunch retains the attachment and complete graph.

Capture at the mockup’s wide size, a compact size around 900×650, and the supported minimum 760×520. Compare with [onboarding_state.png](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/design/mockups/onboarding_state.png) for hierarchy, restrained recovery language, visible minimum decision, spacing, typography, borders, responsive scrolling, and absence of clipped actions. This is a visual/accessibility comparison, not a pixel-diff gate.

### Portable-import slice

Live verification is blocked. Once eligible, use `--rr10-capture --rr10-empty-store` and an exporter-produced disposable archive. Verify both exact workflow labels, archive preview counts/exclusions, actionable malformed-version failure, all cancellation paths, success/refresh/selection, responsive layout, and unchanged source bytes.

## Currently unverifiable

Release Radar contains no portable project archive or authoritative exporter; the only `dashboard-status.json` is a partial test fixture. Therefore QA cannot currently verify:

- Complete-graph archive coverage or round-trip fidelity.
- Audit-history and notification-history portability.
- ID collision/remapping behavior.
- Evidence-path rebasing.
- Device-local field exclusion and fresh-bookmark restoration.
- Unsupported portable-version behavior.
- Portable importer atomic rollback.
- Portable-import preview, success, relaunch, or combined two-label live flow.

All eventual decisions, RED/GREEN results, live evidence, and independent outcomes must be recorded only in [docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md). No competing durable ledger is permitted.