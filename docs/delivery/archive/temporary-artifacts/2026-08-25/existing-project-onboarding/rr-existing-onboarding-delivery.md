# Delivery Manager Gate — Existing-Project Onboarding

**Overall release decision: NO-GO for a new writer now.**

The owner’s priority makes onboarding the next product work, superseding RR-R7 sequencing. However, single-writer safety is not currently established:

- The ledger still releases RR-R7 as the sole writer and says its implementation has not begun ([progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:379)).
- The dirty worktree already contains RR-R7-shaped changes in [AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:120), [SidebarView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Navigation/SidebarView.swift:73), and [AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:521).
- Those files overlap the proposed Attach implementation. The worktree has 35 modified tracked files plus untracked remediation assets/artifacts, and no evidence establishes that the current writer has stopped.
- Required Architect, TPM, QA, and Security/Privacy onboarding gates are not yet durable in `docs/delivery/progress.md`.

## Workflow 1 — Attach Folder to Existing Project

**NO-GO now; designated next sole-writer slice.**

The slice is otherwise dependency-ready:

- ADR-001 authorizes project-named first-root association to a globally unowned canonical root ([ADR-001](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:20)).
- `associateFirstProjectRoot` already performs the bounded root/bookmark/audit transaction and must be reused directly ([ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351)).
- Existing coverage proves one rootless project can receive one unowned root, but does not yet prove preservation of a populated delivery graph ([OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:445)).
- The current UI remains folder-first and has no labelled Attach workflow ([OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:44)).

Before release, `docs/delivery/progress.md` must record the owner reprioritization, disposition of the already-present RR-R7 changes, confirmation of no concurrent writer, and all required independent preimplementation gates. No competing ledger or new process artifact is authorized.

The slice remains strictly bounded to the labelled Attach workflow, project selection, folder selection, project-named confirmation, and direct `associateFirstProjectRoot` use. It must not call onboarding prepare/finish, invoke any importer, infer Markdown, create markers, or duplicate delivery records.

## Workflow 2 — Import Existing Project

### Archive-contract documentation

**NO-GO.**

Product and architecture have not approved the portable complete-graph contract, authoritative exporter, ID collision/remapping policy, audit/history treatment, evidence-path rebasing, notification-history treatment, atomicity, or unsupported-version behavior.

### Portable importer

**NO-GO.**

It depends on the accepted archive contract and an exporter-produced fixture. No portable Release Radar artifact or exporter currently exists.

### Release Radar import workflow

**NO-GO.**

It depends on the portable importer’s acceptance. The existing Rekon importer is only a partial one-time seed covering phases, tickets, dependencies, evidence, and review items ([DeliveryArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/DeliveryArtifactImporter.swift:9)). It must not be relabelled as complete-project restoration. Markdown remains evidence-only, with no inference, and no Import workflow control should be enabled prematurely.

## Next sole writer

**Attach Folder to Existing Project**, after the RR-R7 ownership/ledger mismatch is reconciled and the missing independent gates are recorded. No archive, importer, or Release Radar import work may run concurrently.

Completion evidence must be recorded only in `docs/delivery/progress.md`: RED/GREEN results, complete-graph preservation, exact root/bookmark/audit delta, rollback cases, no importer/prepare/finish calls, cancellation behavior, committed-versus-refresh-failed handling, relaunch authorization, isolated accessibility/screenshots against `onboarding_state.png`, and independent postimplementation decisions.