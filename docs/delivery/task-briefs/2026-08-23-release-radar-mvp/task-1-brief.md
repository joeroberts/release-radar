### Task 1 (RR-01): Scaffold the signed standalone application

**Dependencies:** none.

**Files:**

- Create: `ReleaseRadar.xcodeproj/project.pbxproj`
- Create: `ReleaseRadar/App/ReleaseRadarApp.swift`
- Create: `ReleaseRadar/App/AppModel.swift`
- Create: `ReleaseRadar/Navigation/AppRoute.swift`
- Create: `ReleaseRadar/Navigation/SidebarView.swift`
- Create: `ReleaseRadar/ReleaseRadar.entitlements`
- Create: `ReleaseRadar/Info.plist`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`
- Create: `docs/architecture/ADR-001-release-radar-boundaries.md`
- Create: `docs/delivery/progress.md`

**Interfaces produced:**

```swift
enum AppRoute: Hashable, Sendable {
    case projects, needsReview, notifications, settings
    case projectOverview(ProjectID), phaseBoard(ProjectID)
    case dependencies(ProjectID), activity(ProjectID)
}
```

- [ ] Record ADR-001 with the standalone bundle/data namespace, app-only database authority, separate read-only observer and typed mutation bridge, sandbox/signing boundary, five-lane supersession, and prohibited alternatives. Backfill the Planning, Architect, TPM, QA, Delivery Manager, and security preimplementation gates in the ledger.
- [ ] Create the Xcode targets `ReleaseRadar`, `ReleaseRadarCore`, `ReleaseRadarAgentTools`, `ReleaseRadarTests`, and `ReleaseRadarUITests` without third-party dependencies.
- [ ] Implement `ReleaseRadarApp` with `WindowGroup`, `MenuBarExtra`, and `Settings`, plus a `NavigationSplitView` shell whose sidebar is 220 points expanded and 96 points collapsed. Keep regular Dock/window activation; the menu extra opens the main window rather than replacing it.
- [ ] Add the primary and per-project routes with consistent thin SF Symbol icons and accessible labels. Use `Release Radar` in app chrome and `Release Radar By Rekon Labs` in About/onboarding presentation.
- [ ] Add the project-local `script/build_and_run.sh` kill/build/launch entrypoint with run, debug, logs, telemetry, and verify modes, plus the canonical `.codex/environments/environment.toml` Run action.
- [ ] Run `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` and `./script/build_and_run.sh --verify`; record the resolved signing identity in `docs/delivery/progress.md`.
- [ ] Commit the accepted foundation: `git commit -am "feat: scaffold Release Radar macOS app"` after staging the new files.

