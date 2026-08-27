# TPM gate — Existing-project onboarding

**Decision:** Scope GO; implementation NO-GO until the dirty RR-R7 state is reconciled. “Attach Folder to Existing Project” is the next conditionally releasable writer. “Import Existing Project” remains blocked.

## Dependency-safe sequence

| Slice | TPM gate | Decision |
| --- | --- | --- |
| RR-R7 reconciliation | **RELEASED — administrative only** | The ledger says no RR-R7 code exists, but the route guard, conditional sidebar, and regression tests are already present in [AppModel.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/App/AppModel.swift:120), [SidebarView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Navigation/SidebarView.swift:73), and [AppRouteTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/AppRouteTests.swift:522). Preserve these changes. Delivery Management must reconcile [progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:379) as implemented-but-unaccepted and record the owner-priority sequencing change. |
| Attach Folder to Existing Project | **BLOCKED NOW; next writer after reconciliation** | TPM approves the bounded brief. Release one fresh Implementer only after RR-R7 source acceptance and independent Architect, QA, Delivery Manager, and Security/Privacy preimplementation approvals. Defer the RR-R7 Release installation/handoff until this prioritized onboarding slice is accepted. |
| Import Existing Project contract | **BLOCKED** | Product and Architecture must first define a versioned, authoritative portable complete-project artifact, graph/history scope, collision behavior, atomicity, and local-authorization handling. |
| Import Existing Project implementation/UI | **BLOCKED** | Do not expose the label or build an importer until the contract gate closes. Do not relabel the partial RR-08 importer as complete-project restoration. |

## Roadmap mapping

“Attach Folder to Existing Project” is a narrow post-remediation continuation of:

- RR-R1 for cancellable Add Project behavior and opening an already-owned folder without duplicates.
- RR-R2 for the approved first-root authorization contract. Implementation must call `associateFirstProjectRoot` directly; its current mutation is limited to one root, one bookmark, and one owner audit ([ProjectOnboarding.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351)).
- RR-04 for folder-backed onboarding boundaries.
- RR-R7 only as an integration baseline because the dirty guard work overlaps `AppModel`, `SidebarView`, and `AppRouteTests`.

It does not reopen RR-04 or RR-08 and does not resolve the separately blocked structure-less-project decision.

“Import Existing Project” maps beyond RR-08. RR-08 is explicitly a one-time Rekon seed importer ([MVP plan](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/superpowers/plans/2026-08-23-release-radar-mvp.md:279)). Its preview contains only phases, tickets, dependencies, evidence, and generated review items ([DeliveryArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/DeliveryArtifactImporter.swift:9)). It cannot restore the complete persisted project graph.

## Required findings

- Reconcile the ledger/source contradiction before another writer touches the overlapping files. Do not revert or absorb the existing RR-R7 changes.
- The Add Project sheet must expose exactly two distinct labels: **Attach Folder to Existing Project** and **Import Existing Project**. The current UI exposes only the folder-first path ([OnboardingView.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadar/Projects/OnboardingView.swift:44)).
- Attachment must select a rootless existing project first, require project-named confirmation, and reuse `associateFirstProjectRoot`. It must never invoke `prepare`, `finish`, or an importer.
- Add a targeted preservation regression proving every pre-existing delivery node, relationship, status, history, unrelated-project record, and alert rule remains unchanged. Only one root, one bookmark, and one authorization audit may be added. Current coverage proves ownership and second-root rejection but not complete-graph preservation ([OnboardingAcceptanceTests.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarTests/OnboardingAcceptanceTests.swift:445)).
- Preserve cancellation, actionable fail-closed errors, and truthful committed-but-refresh-failed wording. Success returns to Projects with the target current/selected, without opening its dashboard or creating a dashboard-open audit.
- Preserve the mockup’s “minimum decision needed” and “no silent recovery” behavior. The mockup does not define the new chooser’s exact composition, so independent QA must accept the labelled flow rather than claim pixel-equivalent reproduction.
- Keep arbitrary Markdown non-authoritative. The existing importer decodes only `dashboard-status.json`; recognized Markdown is retained as evidence paths, not parsed for delivery state ([RekonArtifactImporter.swift](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/RekonArtifactImporter.swift:27), [evidence collection](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/RekonArtifactImporter.swift:530)).
- Record all eventual status, evidence, reviews, and sequencing decisions only in `docs/delivery/progress.md`.

## Optional

- A dedicated chooser mockup or design-document refinement, provided it does not delay the explicitly labelled, bounded attachment workflow.
- Broader portable-project design work after Product and Architecture close the import-contract gate.

## Out of scope

- Reverting dirty RR-R7 or other user changes.
- Creating, renaming, merging, deleting, or replacing projects.
- Reauthorizing already-rooted projects through the new attachment flow.
- Markdown inference, repository-backed manifests, database copying, or broadening RR-08.
- New schema, migration, coordinator, test harness, or competing delivery ledger for the attachment slice.
- Owner-data inspection or repair, packaging, installation, notarization, or distribution during this read-only gate.

No files were edited and no runtime/test acceptance is claimed.