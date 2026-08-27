**Required**
None.

The prior NO-GO does not remain a Required defect. Current source keeps the Existing Project slice on the attach path only:
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:169),
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:230),
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:320),
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:337),
[ReleaseRadar/App/AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:205),
[ReleaseRadar/App/AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:209),
[ReleaseRadarCore/Onboarding/ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351).

That matches the approved boundary in
[docs/architecture/ADR-001-release-radar-boundaries.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:34)
and
[docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:391).

**Optional**
[docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:402): durable ledger evidence for the final post-copy/title focused rerun is not recorded in the repo lines I reviewed. I found accepted earlier focused evidence at
[docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:296),
and current source has direct string/title coverage at
[ReleaseRadarTests/AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:394)
plus attach-route behavior coverage at
[ReleaseRadarTests/AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:406),
so this is evidence hygiene, not a release blocker.

**Out-of-scope**
Portable `Import Existing Project` remains blocked and unimplemented for this slice, per
[docs/architecture/ADR-001-release-radar-boundaries.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:41),
[docs/architecture/ADR-001-release-radar-boundaries.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:81),
[docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:392),
[docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:401).

The pre-approved Rekon importer is still only a new-project seed path:
[ReleaseRadarCore/Import/RekonArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/RekonArtifactImporter.swift:5),
[ReleaseRadarCore/Onboarding/ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:231),
[ReleaseRadarCore/Onboarding/ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:442),
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:562),
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:570),
[ReleaseRadar/Projects/OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:604).

Tests also support the split:
[ReleaseRadarTests/OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:505),
[ReleaseRadarTests/OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:554),
[ReleaseRadarTests/AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:399),
[ReleaseRadarTests/RekonImportAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/RekonImportAcceptanceTests.swift:8).

GO.