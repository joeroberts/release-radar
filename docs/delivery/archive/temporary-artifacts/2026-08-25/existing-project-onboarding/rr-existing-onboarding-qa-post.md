**Findings**

**Required**
- Live acceptance is still short of a full close. The implementation and tests cover the committed attach path and the saved-but-refresh-failed recovery, but the fresh UI evidence you supplied stops when `NSOpenPanel` closes, so I do not have direct observation of the final committed Projects refresh/target selection or the required responsive states at about `900x650` and `760x520` that the ledger calls for. See [docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:395) and [OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:109).
- Dismissal/no-write behavior is implemented but not fully closed by automated evidence. Source shows `Cancel`, `Escape`, native panel cancel/close, and in-flight dismissal protection via `.keyboardShortcut(.cancelAction)`, `guard response == .OK`, and `.interactiveDismissDisabled(...)`, but I did not find XCTest coverage proving no durable write on cancel/escape/native close. See [OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:109), [OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:144), and [OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:323).

**Optional**
- Add a narrow UI/route test for cancel/close/no-write so this gate does not depend as heavily on Computer Use for dismissal semantics.

**Out of scope**
- Portable Import. Current source and ADR still keep complete-project import blocked without an authoritative structured archive/exporter fixture, and I found no evidence of Markdown inference being promoted into that path. The existing Rekon importer remains the partial seed importer only. See [ADR-001-release-radar-boundaries.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:32) and [RekonArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/RekonArtifactImporter.swift:1).

**Assessment**
- Source matches the required attach architecture: `AppModel.attachFolder` calls `associateFirstProjectRoot` directly, stays on Projects, selects the target, and distinguishes committed success from committed-but-refresh-failed. See [AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:209).
- Persistence/audit behavior looks correct: one canonical root, one fresh bookmark, one owner audit, with fail-closed rejection for owned/already-associated cases. See [ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351) and [OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:554).
- Eligible rootless-project filtering is covered and matches the requirement. See [ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:395) and [OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:505).
- Refresh/reload recovery is covered in tests. See [AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:406).
- I did not rerun the suite; I inspected the current source/tests and used the supplied fresh results for the focused `39` and full `154/154` passes.

**Verdict**

CONDITIONAL GO. The code and test coverage are consistent with the requested behavior, but the gate still needs final live evidence for post-commit refresh/selection and the required responsive states, and I will not claim that unobserved UI commit occurred.