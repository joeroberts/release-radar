# Architecture Gate — Existing-Project Onboarding

## Overall decision

**Combined implementation: NO-GO.**

The two workflows are architecturally distinct and must remain explicitly labelled:

1. **Attach Folder to Existing Project**
2. **Import Existing Project**

The current Rekon importer is a partial seed importer, not a portable project-restoration source. Arbitrary Markdown remains non-authoritative.

## Attach Folder to Existing Project

**Architecture: GO. Implementation release: BLOCKED until the current RR-R7 writer closes or Delivery Management explicitly reprioritizes it.**

Required contract:

- Candidate projects must have an established delivery project, no open onboarding marker, zero roots, and zero bookmarks.
- UI confirmation must name both the selected project and canonical folder.
- The application boundary must expose a typed operation equivalent to:

```swift
func attachFolder(
    _ folder: URL,
    to projectID: ProjectID
) async throws -> AttachFolderOutcome
```

- `AttachFolderOutcome` must distinguish `.attached` from `.attachedNeedsReload`; a post-commit refresh failure must never be thrown as an attachment failure.
- The operation must directly call [associateFirstProjectRoot](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Onboarding/ProjectOnboarding.swift:351). It must not call onboarding `prepare`/`finish`, either importer, Markdown discovery, or marker creation.
- On success, refresh only the dashboard/workspace/activity projections, set the target as the current project, and remain on Projects. Do not navigate through a dashboard route, change `first_dashboard_opened`, create a dashboard-open audit, or trigger unrelated notification delivery.
- The only durable additions are:
  - one canonical `project_roots` row;
  - one fresh local `project_bookmarks` row;
  - one audit event.
- Every pre-existing delivery, goal, dependency, review, completion, notification, and audit record must remain unchanged.
- Authorization must retain current canonicalization, directory validation, bookmark creation/resolution, active security-scope verification, global root ownership checks, and transactional rechecks.
- Error behavior:
  - owned root: actionable rejection; no ownership transfer;
  - root already present: Attach is unavailable; use same-root reauthorization if needed;
  - bookmark without a root: inconsistent local state; fail closed rather than infer or repair;
  - invalid, stale, mismatched, denied, or missing authorization: no mutation;
  - committed refresh failure: “Folder attached; refresh needed—do not retry.”
- Cancellation before confirmation makes no service call. Dismissal is disabled while the confirmed transaction is in flight.
- Audit remains exactly:
  - actor: `release-radar-owner`;
  - reason: `Associate first project folder authorization`;
  - scope: target project/project ID.
- No ADR change is required for Attach; [ADR-001 already authorizes this boundary](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/architecture/ADR-001-release-radar-boundaries.md:20).

## Import Existing Project — Source finding

**Current source: NOT AUTHORITATIVE; workflow remains blocked.**

[ImportPreview](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/ReleaseRadarCore/Import/DeliveryArtifactImporter.swift:9) carries only active phase, phases, phase dependencies, tickets, ticket dependencies, evidence, and generated reviews. The Rekon schema contains only `schemaVersion`, `activePhaseId`, phases, and tasks. It does not represent the complete Release Radar graph.

The repository contains no portable Release Radar archive and no authoritative `docs/delivery/dashboard-status.json`; only the synthetic Rekon test fixture exists. Repository Markdown, the progress ledger, and a copied SQLite database are not portable import sources.

## Approved portable project archive contract

**Contract definition: GO and architecturally approved as version 1.** It must be recorded in ADR-001 before implementation.

The source is one bounded JSON file with extension `.release-radar-project.json`:

- `format: "com.rekonlabs.release-radar.project-archive"`
- `schemaVersion: 1`
- `exportedAt`
- producer bundle/app/store-schema metadata
- exactly one project

All portable record IDs are preserved without remapping:

- Project: `id`, `name`, nullable `activePhaseID`.
- Phases and phase-dependency records.
- Tickets, lanes, outcomes, and ticket-dependency records.
- Blockers, including `resolvedAt`.
- Evidence IDs, optional ticket links, and root-relative paths; availability is recomputed locally.
- Thread exclusions.
- Observed threads and goals, including status/text/last-observed timestamps.
- Thread links and ticket-goal links.
- Review items, including kind, summary, optional ticket, and status.
- Completion records and timestamps.

Imported observations are historical last-known context, never live state.

Version 1 supports exactly one source project root and one newly selected destination root. A source project with multiple roots or evidence outside its single root is not representable and export must fail rather than omit records.

Not portable:

- absolute roots, root IDs, security-scoped bookmark bytes, or stale flags;
- `first_dashboard_opened`—it resets to false;
- audit events;
- notification events, occurrences, receipts, acknowledgement, or attempt history;
- alert rules, agent-command replay records, credentials, Keychain data;
- live connection/freshness state;
- evidence `is_available`;
- onboarding markers.

## Import behavior

- Import creates a new project only. It never attaches to, merges with, replaces, or updates an existing project.
- Existing project ID, any same-table record-ID collision, duplicate archive ID, duplicate logical edge, dangling/cross-project reference, invalid lane/status, dependency cycle, or reserved onboarding marker blocks confirmation.
- No automatic remapping, upsert, partial seed, or generated Needs Review fallback is permitted. Reviews already present in the archive are restored as records.
- Reimport of an existing project is rejected with zero mutation and zero audit.
- Preview must show exact graph counts, project identity, active phase, non-portable omissions, root requirements, and every blocking validation result.
- Apply must re-read and revalidate the same source bytes before committing.
- Bookmark validation occurs before persistence. Root ownership and all collisions are rechecked inside one `DeliveryStore.transact`.
- Project, graph, destination root, bookmark, and one audit commit atomically; any failure rolls back everything.
- Import audit:
  - actor: `release-radar-owner`;
  - reason: `Import portable Release Radar project archive`;
  - scope: imported project/project ID.
- Historical audits are never restored or fabricated.
- Source handling must use an owner-selected, bounded regular file; reject symlinks, duplicate/unknown JSON fields, unsupported versions, traversal, absolute evidence paths, and oversized input. Read through a descriptor-anchored no-follow path, perform no network access, execute no content, infer nothing from Markdown, and leave source bytes unchanged.

## Eligibility decisions

- **Archive contract definition:** **GO**, subject to durable ADR/design recording.
- **Authoritative exporter and exporter-produced fixture:** **BLOCKED** until separately planned and approved.
- **Portable importer implementation:** **BLOCKED** until RR-R7 closes or is reprioritized, ADR/design amendments land, and the authoritative exporter produces the acceptance fixture.
- **Importing the Release Radar repository:** **BLOCKED** because no compliant archive exists. Repository documents cannot substitute for one.
- **Current Rekon importer:** remains the RR-08 one-time seed importer and must not be broadened.

## Required ADR changes

Add a new “Portable project archive v1” decision to ADR-001 recording:

- the two labelled workflows and their non-overlapping purposes;
- the exact portable graph and stable-ID rule;
- the complete non-portable list;
- single fresh destination-root/bookmark requirements;
- reject-without-remapping collision and existing-project behavior;
- strict preview validation and source-security boundary;
- all-or-nothing store transaction;
- one new owner audit with no historical-audit restoration;
- prohibition on treating Rekon JSON, Markdown, repository state, or SQLite copies as complete archives.

Also amend the design onboarding section to distinguish complete archive restoration from the existing Rekon seed flow. Gate status and evidence must eventually be recorded only in [docs/delivery/progress.md](/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/docs/delivery/progress.md:27); no competing delivery ledger is authorized.