# One-time reconstruction of a current project plan

Status: owner-approved product decisions and entry-screen reference; independent
architecture/security-recovery/UX design review passed with no findings.
Documentation persistence and review are authorized.
Implementation, publication and live Pursuit recovery are not authorized.

## Outcome and sequence

Allow an owner whose registered project has no recorded plan to preview and approve
a one-time reconstruction of its current operational plan from one identified,
supported, versioned repository planning projection. Preserve the existing project
registration and current application data. This is not database restoration or
recurring repository synchronization.

The owner corrected the sequencing request: implementation follows the final
currently planned Phase 6 extension, currently through 6H, not the already-merged
6E. Preserve the existing 6F metric, 6G management and 6H toolbar/lifecycle outcomes
in the [Phase 6 proposal](phase6-workspace-toolbar-proposal.md). The separately
proposed guided-setup label 6I is not accepted or a silently added recovery
dependency. Do not assign a recovery slice number or resume Phase 7 by inference.

## Approved source and state rules

- The sole machine-readable reconstruction source is a supported, versioned
  structured planning projection. Markdown roadmaps, ledgers and prose may explain
  the project, but must never be interpreted into operational state.
- Identify one repository snapshot for preview. Display its repository/project
  association, source revision/version and the intended registered destination.
  Recognition of a file or a count is not validation or mutation authority.
- Include the explicitly recorded phases, task identities, dependencies and current
  ticket lanes from that snapshot. Do not infer missing lanes or statuses from prose,
  titles, acceptance evidence or dependency order.
- Record truthful provenance: reconstructed from the identified repository snapshot.
  Preserve source identifiers and distinguish the reconstruction event from any
  historical work events. Do not fabricate prior transitions, acceptance events,
  timestamps, actors, receipts or notifications. Never replay completion notifications.
- Keep the current application store and registration. Do not overwrite the store
  with an old backup or directly edit SQLite. Existing backups remain recovery
  evidence, not a hidden alternative ingestion path.

The diagnosis reported a Pursuit projection with 6 phases and 49 tasks. These counts
are the approved example shown in the entry mockup, not constants or proof that any
particular live file is ready to import. Fresh supported validation determines the
actual preview. The complete supported projection schema/version and identity/lane
mapping must be specified and checked before implementation; this design does not
declare an arbitrary JSON file to be supported.

## Owner journey

1. On the empty Project Plan page, offer **Rebuild current plan** when a supported
   snapshot is recognized. Show its source summary, phase/task counts and whether
   dependencies and current lanes are included. The example has 6 phases and 49
   tasks. Explain that nothing changes until review and approval.
2. **Review reconstruction** opens a preview of the exact source, destination and
   proposed set. **Not now** dismisses the offer without writes. Opening either the
   page or preview never starts reconstruction.
3. Preview exposes conflicts, unsupported values, unresolved references and blockers
   with understandable resolution or explicit exclusion. Exclusions produce a new
   concrete preview; dependency validity must still hold. Never silently omit rows.
4. Explicit owner approval identifies the final source snapshot and proposed set.
   Apply that approved set atomically through supported typed, audited app operations.
   A changed source or destination invalidates the preview rather than authorizing
   a revised import automatically.
5. Show verified completion and the resulting current plan with reconstruction
   provenance, or an actionable failure/recovery state. Cancellation and failed
   validation leave operational state unchanged. An uncertain outcome is reconciled
   through the existing operation receipt/readback contract, not blind resubmission.

**Atomic application is provisional.** The owner accepted all-or-nothing only if
blockers are easy to resolve or explicitly exclude. Usability validation must prove
the owner can complete a coherent reconstruction without being trapped by one bad
row. If this fails, return for a bounded product decision before shipping rather
than silently switching to partial application or expanding the feature.

## Visual reference

[Approved reconstruction entry mockup](mockups/repository-plan-reconstruction-entry.png)
records the owner-approved entry hierarchy, source/safety disclosure and actions.
It is generated design reference, not running-app evidence or a production asset.

Use the current Phase 6 persistent workspace toolbar and approved Release Radar
identity. Search/Save query and Help/Settings/Notifications belong in the toolbar,
not the sidebar. Keep the toolbar divider inset from both boundaries. The sidebar
reserves a fixed **Checking project documentation…** footer and omits **Persisted
locally**. Follow the current RDS near-black surfaces, cyan accents, restrained blue
borders and cyan-to-violet primary action. Generated image colors/lettering do not
override the current design tokens or require shipping a generated wordmark.
Compact layout follows the accepted toolbar design; the wide entry reference does
not establish compact or accessible correctness.

## Boundaries and validation before implementation

Architecture and security/recovery review must establish the supported source
schema, source/destination identity validation, safe reference/root handling,
current-state mapping, atomic operation and uncertain-outcome recovery without
introducing a second database writer or automatic synchronization. Use existing
typed application capabilities when sufficient; name any necessary new public or
persistence contract explicitly before authorizing its implementation.

Future acceptance checks cover supported/unsupported versions, stale source or
destination, invalid lanes, duplicate identities, unresolved dependencies, preview
exclusions and cancellation, atomic failure, retry after uncertain outcome, truthful
provenance, and absence of synthetic historical events or completion notifications.
Rehearse against disposable data before any separately authorized live recovery.
Verify the owner can resolve a blocked preview, understands current lanes versus
historical evidence, and can operate the preview at compact width with keyboard and
accessible controls.

One independent reviewer may cover documentation, architecture, security/recovery
and UX if qualified for those concrete risks. Review this design and its original
owner requirements; do not review other reviews. Only Required findings block.
Any unresolved implementation contract remains explicit rather than implied by
approval of the entry screen. The current endpoint is a reviewed, locally committed
documentation package, with catalog/index consistency and no app-state mutation.

Independent review of this design package confirmed faithful preservation of the
owner decisions, sequencing and visual reference. Documentation and diff checks
passed. Supported schema/mapping, exact mutation/receipt contracts and disposable
usability/runtime validation remain implementation-stage work. The review did not
authorize implementation or assess live application/catalog acceptance. The bounded
review completed without app-state changes and its task was archived after recording
the result.

Related boundaries: [application architecture](../architecture/ADR-001-release-radar-boundaries.md),
[delivery readiness](../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[managed documentation](../architecture/ADR-006-managed-repository-documentation-contract.md).
