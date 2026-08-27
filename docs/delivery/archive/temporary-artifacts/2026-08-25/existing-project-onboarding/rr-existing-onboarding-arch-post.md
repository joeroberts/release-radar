**Required**
None.

**Optional**
None.

**Out of scope**
None material.

Architect review notes:
- Workflow separation is correct. The existing-project path goes straight through `AppModel.attachFolder` to `FolderProjectOnboarding.associateFirstProjectRoot` and does not reuse `inspect` / `prepare` / `finish` or either importer for attachment: [AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:205), [ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351), [progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:392).
- Canonical transaction reuse is preserved. `associateFirstProjectRoot` is the sole bounded owner transaction for first-root association, adding exactly one root, one bookmark, and one project-scoped audit: [ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351). The graph-preservation and rollback coverage is explicit in [OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:554).
- Scene/state ownership is clean. Attachment UI state stays local to `OnboardingView`; durable effects stay in `AppModel`/store; success returns to Projects and reselects the target without opening a dashboard: [OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:223), [AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:209), [AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:405).
- Portable archive v1 boundary remains compliant. ADR-001 keeps portable import blocked pending an authoritative exporter fixture, and current code still exposes only the partial Rekon seed importer for new-project onboarding, not an existing-project import path: [ADR-001-release-radar-boundaries.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:36), [progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:393), [RekonArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/RekonArtifactImporter.swift:567).

Fresh evidence is consistent with that structure: focused `OnboardingAcceptanceTests` + `AppRouteTests` and the full 154/154 suite passed, and the attach-flow source matches the newly recorded ADR/progress boundary.

**Verdict**
GO