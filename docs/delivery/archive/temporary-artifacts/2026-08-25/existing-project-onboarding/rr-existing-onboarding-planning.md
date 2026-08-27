# Independent Planning Report — Existing-Project Onboarding

## Verified baseline

- [OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:5) currently implements one folder-first onboarding path. It supports a visible Cancel action and Escape shortcut in the Add Project sheet, opening a project when the chosen folder already belongs to a completed project, and optional recognized-artifact import. It does not let the owner select an existing rootless project and attach a folder to it.
- [FolderProjectOnboarding.associateFirstProjectRoot](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351) already provides the correct bounded mutation: canonical directory validation, project existence checks, rejection when any root/bookmark already exists, global root-ownership rejection, validated security-scoped bookmark creation, one root and bookmark insertion, and one project-scoped owner audit.
- Existing coverage in [OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:445) proves one rootless project can attach one unowned root, rejects an owned or second root, and records the expected audit. It does not prove preservation of a populated delivery graph or expose this as general onboarding UI.
- The accepted ADR already authorizes first-root association as a project-named owner action on a globally unowned canonical root and requires fail-closed, history-preserving behavior ([ADR-001](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:20)).
- The recognized importer is explicitly a one-time seed path. Its [ImportPreview](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/DeliveryArtifactImporter.swift:9) contains only active phase, phases, phase dependencies, tickets, ticket dependencies, evidence, and generated review items. [RekonArtifactImporter](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/RekonArtifactImporter.swift:4) reads only schema-version-1 `docs/delivery/dashboard-status.json`; roadmap, task-brief, handoff, and ledger Markdown are retained only as evidence links.
- No repository `docs/delivery/dashboard-status.json`, portable Release Radar project export, or complete-graph artifact exists. The only matching JSON is a test fixture. The design describes the Rekon import as seeding confident records, not restoring a complete project ([design document](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/design/agent-driven-delivery-dashboard-design.md:100)).
- The current ledger releases only RR-R7 as the next serialized writer ([progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:27)). Any new implementation must wait for RR-R7 closure or an explicit TPM/Delivery Manager reprioritization.

---

## Workflow 1 — Attach Folder to Existing Project

**Classification: ELIGIBLE.** The product and architecture contract exists and the core mutation is implemented. Implementation remains release-closed until RR-R7 finishes or is explicitly reprioritized.

### Objective and user-visible outcome

From Add Project, the owner selects an existing Release Radar project, chooses its local folder, confirms the project-named association, and returns to a refreshed Projects surface with that project selected. All existing delivery structure and history remain intact.

### Roadmap mapping

Treat this as the smallest post-RR-R7 follow-on to:

- RR-R1: cancellable/reset-safe Add Project behavior.
- RR-R2: first-root association, bookmark security, actionable ownership rejection, and truthful post-commit refresh behavior.

Do not reopen RR-04 onboarding or RR-08 importing, and do not add a new persistence format.

### Scope

In scope:

- An explicit “Attach Folder to Existing Project” choice in the existing Add Project sheet.
- Selection of an existing project before folder selection.
- Project-named confirmation.
- Direct reuse of `associateFirstProjectRoot`.
- Cancel, Escape, and sheet/window close behavior.
- Refreshing the dashboard and selecting the target project after success.
- Actionable errors and a truthful committed-but-refresh-failed state.

Out of scope:

- Creating, renaming, merging, deleting, or replacing a project.
- Reauthorizing a project that already has a root; that remains the existing RR-R2 recovery path.
- Importing artifacts, rescanning Markdown, calling `prepare`/`finish`, or creating onboarding markers.
- Adding worktrees, changing phases/tickets, or altering store schema.
- Opening or testing against owner application data.

### Dependencies and release gate

1. RR-R7 must be accepted, or TPM/Delivery Manager must explicitly reprioritize this slice as the sole writer.
2. Architect, TPM, QA, Delivery Manager, and Security/Privacy must approve the brief before implementation.
3. Live verification must use a never-before-used alternate bundle and isolated temporary database because of the recorded RR-R2 isolation incident.
4. A fresh Implementer may change only this bounded flow. Independent Code Review, QA, Architecture, and Security/Privacy acceptance remain required afterward.

### Test-first execution

1. Extend `OnboardingAcceptanceTests` with RED service regressions:

   - `testAttachFolderPreservesCompleteExistingProjectGraphAndAddsOnlyAuthorization`
     - Seed a rootless project with representative project-scoped records across active phase, phases, tickets, both dependency types, blocker, evidence, exclusion, observed thread/goal, thread and ticket-goal links, review item/status, completion, notification occurrence/history, and prior audit history.
     - Snapshot those rows plus unrelated-project and global alert-rule state.
     - Call `associateFirstProjectRoot`.
     - Assert every pre-existing row is byte/value-equivalent afterward.
     - Assert only one canonical root, one fresh bookmark, and one new `release-radar-owner` / `Associate first project folder authorization` project audit were added.

   - `testAttachFolderRejectsOwnedRootWithoutAnyMutation`
     - Seed another project owning the canonical or symlink-equivalent root.
     - Assert `.rootAlreadyOwned`, no bookmark, no audit, and unchanged graphs for both projects.

   - `testAttachFolderRejectsProjectThatAlreadyHasRootOrBookmark`
     - Cover root-only, bookmark-only, and both-present states.
     - Assert `.projectRootAlreadyAssociated` and no repair, replacement, or partial write.

   - Preserve existing invalid-folder, stale bookmark, denied security-scope, and balanced start/stop coverage; add only missing attachment-specific assertions.

2. Add RED `AppRouteTests` for the application boundary:

   - Successful association reloads `DashboardProjection`, keeps `selection == .projects`, and makes the target the selected/current project without invoking `prepare`, importer, or onboarding completion.
   - A post-commit projection-refresh failure is presented as “Folder attached; refresh needed — do not retry,” never as an association failure.
   - Before-confirmation cancellation performs no service call or durable mutation.
   - Use the existing AppModel injection pattern; do not introduce a coordinator or UI-test harness solely for this slice.

3. Implement the minimum behavior:

   - Pass a bounded async attachment callback from `AppModel` through `SidebarView` and `ProjectsView` to `OnboardingView`.
   - Keep `FolderProjectOnboarding` as the sole attachment service and call `associateFirstProjectRoot` directly.
   - Require a selected project and show its name in confirmation.
   - Before confirmation, Cancel, Escape, and interactive/window close share one reset-and-dismiss path.
   - While the confirmed transaction is in flight, prevent interactive dismissal so the owner cannot close onto an unknown result.
   - On failure, keep the sheet open with the typed actionable message.
   - On committed success, refresh projections, select the target project, then dismiss. Do not automatically open the dashboard or create an additional dashboard-open audit.

4. Run GREEN:

```text
xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/release-radar-existing-attach \
  -only-testing:ReleaseRadarTests/OnboardingAcceptanceTests \
  -only-testing:ReleaseRadarTests/AppRouteTests
```

Then run the current full suite and a configured non-launching Debug build.

### Happy and non-happy behavior

- Happy path: rootless project → unowned folder → explicit confirmation → one root/bookmark/audit → refreshed Projects surface with the same project selected.
- Cancel/Escape/window close before confirmation: dismiss and reset; zero durable changes.
- Folder chooser cancellation: remain in the workflow; zero durable changes.
- Owned root: identify that the folder belongs to another project and ask the owner to choose another; never transfer ownership.
- Target already rooted/bookmarked: explain that Attach is unavailable and direct the owner to existing reauthorization recovery.
- Missing project, invalid folder, stale/mismatched bookmark, or denied scope: fail closed with no partial write.
- Refresh failure after commit: state clearly that attachment was saved and must not be retried; offer Reload.

### Anticipated files

- Modify `ReleaseRadar/Projects/OnboardingView.swift`
- Modify `ReleaseRadar/Projects/ProjectsView.swift`
- Modify `ReleaseRadar/Navigation/SidebarView.swift`
- Modify `ReleaseRadar/App/AppModel.swift`
- Modify `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- Modify `ReleaseRadarTests/AppRouteTests.swift`
- Modify `ReleaseRadar/Shared/FailureStateView.swift` only if existing typed authorization presentations cannot provide the required saved-versus-failed wording

No migration, importer, model-contract, or ADR change is anticipated.

### Acceptance and ledger evidence

- RED/GREEN commands and results.
- Complete pre/post graph comparison.
- Exact root, bookmark, and audit rows.
- Owned-root and rooted-project rollback evidence.
- Relaunch persistence and successful `withAuthorizedProject` access.
- Isolated wide/compact accessibility and screenshot evidence against `onboarding_state.png`.
- Click, Escape, and window-close cancellation evidence with unchanged counts.
- Successful refresh/current-project selection evidence.
- Independent Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery Manager decisions.

---

## Workflow 2 — Import Existing Project

**Classification: BLOCKED.** No approved portable complete-graph source exists.

### Objective

If later authorized, this flow would create a Release Radar project from a versioned portable Release Radar artifact, restore every relationship defined by that approved contract without inference, create fresh local folder authorization, and select the imported project.

### Why the current importer cannot be reused as the source

The current Rekon contract is a partial seed:

- It covers active phase, phases, tickets, phase/ticket dependencies, evidence links, and ambiguity-generated review items.
- It does not carry blockers, exclusions, observed threads/goals, thread links, ticket-goal identity, existing review status/history, completion records, audit history, notification occurrence/history, or portable authorization.
- Fixed-path Markdown is linked as evidence but its contents are not interpreted.
- The app database is app-owned Application Support state spanning local operational data; it is not an approved project-portable artifact.
- `DeliveryStore.transact` protects `audit_events` from callback writes and appends its own audit, so restoring historical audits would require an explicit store-owned import contract or an approved decision that audit history is outside “complete graph.”
- Globally unique record IDs create an unresolved collision/remapping question when importing into a store that already contains projects.

Calling the Rekon JSON “Import Existing Project” would therefore misrepresent a partial, lossy seed as a complete restoration.

### Roadmap mapping and unblock gate

RR-08 remains the accepted one-time Rekon seed importer and must not be broadened.

The smallest necessary addition is a separate post-remediation portable-project task, blocked until:

1. Product approves what “complete graph” includes.
2. Architecture records a versioned portable schema and authoritative producer/exporter.
3. The contract defines ID collision behavior, atomicity, audit/history treatment, evidence-path rebasing, notification-history treatment, and unsupported-version behavior.
4. Security/Privacy defines handling for device-local material. Security-scoped bookmark bytes and stored absolute roots must never be imported; the selected destination folder must receive a new local bookmark.
5. QA approves a fixture produced by the authoritative exporter rather than hand-authored Markdown or the partial Rekon fixture.

Until those gates pass, do not add an Import Existing Project button, importer type, placeholder records, or inferred fallback.

### Test-first brief after the gate is approved

Do not write these tests until the artifact contract is controlling:

1. Source-recognition RED tests:

   - Accept only the exact versioned portable artifact.
   - Explicitly reject arbitrary Markdown and current Rekon `dashboard-status.json` as complete-project sources.
   - Reject missing required sections, unknown versions, duplicate identities, oversized input, symlink substitution, and unauthorized paths.
   - Leave source bytes unchanged.

2. Complete-graph RED tests:

   - Import an exporter-produced fixture into an isolated empty store.
   - Compare every contract-defined node, edge, status, and history record after relaunch.
   - Prove project and relationship IDs follow the approved collision/remapping rule.
   - Prove any invalid reference, cycle, collision, or truncated section rolls back the entire import and its audit.
   - Generate a fresh destination root/bookmark; never deserialize authorization material.

3. UI/model RED tests:

   - Preview exact counts and omissions before confirmation.
   - Cancel/Escape/window close before confirmation produces no project, root, bookmark, or audit.
   - Successful import refreshes and selects the new project.
   - A committed import followed by refresh failure is reported as saved and not retryable.

### Anticipated files after unblock

- Amend `docs/design/agent-driven-delivery-dashboard-design.md`
- Amend ADR-001 or add a narrowly scoped portable-artifact ADR
- Create `ReleaseRadarCore/Import/PortableProjectArtifact.swift`
- Create `ReleaseRadarCore/Import/PortableProjectArtifactImporter.swift`
- Create `ReleaseRadarTests/PortableProjectImportAcceptanceTests.swift`
- Create an exporter-produced fixture under `ReleaseRadarTests/Fixtures/PortableProjectImport/`
- Modify `OnboardingView.swift`, `ProjectsView.swift`, `SidebarView.swift`, and `AppModel.swift`
- Modify `DeliveryStore` only if the approved contract requires a bounded store-owned history-import path

No `StoreMigrations` change should be assumed without an approved schema need.

### Required acceptance evidence after unblock

- Approved schema and authoritative producer provenance.
- Complete-graph round-trip/relaunch comparison.
- Atomic rollback and collision-policy evidence.
- Fresh-bookmark and no-imported-authorization evidence.
- Generic-Markdown and Rekon-partial-artifact rejection.
- Source-byte preservation.
- Isolated UI cancellation, preview, success, refresh, and selection evidence.
- Independent Architecture, Security/Privacy, QA, Code Review, TPM, and Delivery Manager acceptance recorded in the progress ledger.