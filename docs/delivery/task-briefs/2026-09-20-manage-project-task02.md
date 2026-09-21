# P6 Manage Project — Task02: consolidate existing project controls

## Objective and scope

Deliver the approved `rr-p6-manage-project-task-02`: documentation activation,
shared-execution compatibility, repository access and project evidence belong in
Manage Project for the selected project. Overview retains delivery progress and
attention. Preserve Task01's immediate exact-identity opening and independently
loading, recoverable sections.

Move existing behavior rather than creating replacement authority or services.
Include repository health/root recovery and documentation guidance actions where
they share these controls' state. Preserve informational attention feedback on
Overview where useful, but keep management actions in Manage Project. Archive and
Remove belong to the separate Navigation ticket; do not move them in this slice.
Do not implement guided setup, change persistence/public contracts, alter RDS,
modify permissions or governance, or change RR delivery state.

## Authority and dependencies

- Owner explicitly selected this ticket before Navigation and Guided Setup and
  authorized continued implementation, verification and local delivery.
- [Selected design](../../design/phase6-workspace-toolbar-proposal.md), including
  its linked wide/compact screenshots; preserve near-black navy surfaces and
  restrained borders rather than obsolete bright mockup colors.
- [ADR-001](../../architecture/ADR-001-release-radar-boundaries.md) and existing
  typed registration, documentation, root and evidence authorization contracts.
  No architecture decision or public/persistence contract change is required.
- Task01 reviewed candidate `236f2265`, integrated without source differences at
  canonical `e9ef9c55`. The assigned committed baseline must include this behavior
  and this brief. RR Task01 completion recording is pending an oversized evidence
  inventory; that recording limitation does not invalidate the verified source.

## Implementation boundaries and material risks

The existing controls are composed by `ProjectOverviewView`; `SidebarView` owns
AppModel callbacks and current projections. `ManageProjectView` currently owns
settings/execution sections. Carry the required state and callbacks into the
identity-bound management surface using existing composition patterns.

- Documentation activation uses an exact preview and a separate explicit action.
  Preserve local errors, audit feedback, keyboard focus, scroll-to-error and
  accessibility announcements after relocation.
- Shared-execution compatibility refresh is read-only and distinct from the
  existing execution-hook mutation controls. Preserve checking/disabled states.
- Health, folder reauthorization and root recovery share registration/root
  identity, generation guards and success refresh propagation. Keep one coherent
  state path rather than independent copies that can diverge. Preserve exact
  saved-worktree recovery and typed preview/confirmation operations.
- Evidence previews retain their existing coordinator cancellation/freshness
  rules, exact evidence identity and authorized-root checks. A failed section
  must not hide other management sections or substitute another project's data.
- Switching/replacing registrations must not let a late response update the new
  selection or let a stale preview perform a mutation. Preserve active, archived
  and removed access boundaries and existing typed service checks.

## Direct checks and acceptance

Use test-first focused native tests for the changed composition and recovery
journeys. Prove that the four control groups are discoverable in Manage Project,
removed from their old management location, and still invoke the same exact-target
callbacks. Exercise delayed/failed section loading, activation error focus,
read-only compatibility refresh, repository recovery and evidence freshness at
their changed integration boundaries. Keep Task01 immediate-opening and recovery
tests passing.

Select directly affected existing tests from ProjectDocumentationRenderingTests,
ManagedEvidenceRenderingTests and EvidencePreviewTests; do not automatically rerun
an exhaustive matrix. Existing root-service tests need repetition only if their
behavior changes. Verify the actual management surface at relevant wide/compact
widths, including scrolling and recovery actions, against the design references.
Prefer direct window observation if bitmap capture cannot reliably show a sheet;
do not build another screenshot harness. Use original-resolution image viewing
when a resized tool rendering appears incomplete.

Acceptance requires working relocated controls, retained explicit authority and
error recovery, immediate exact identity, coherent refresh propagation, accessible
navigation and relevant tests plus independent review. No completed ticket or
owner acceptance follows merely from a commit or test pass.

## Assignment, review and endpoint

RR managed delivery writer owns only affected app composition, focused tests and
necessary mutable design documentation. Start with the app-assigned Terra/medium
profile; request scoped escalation to Sol/high only for a named unresolved
cross-component issue. Ultra is prohibited. Main owns the progress ledger and
brief/catalog metadata. Established Build Agent owns compilation, integration and
Git commits. Serialize edits and compilation in the assigned checkout.

One independent reviewer covers UX/recovery and the concrete authorization/data
risks of relocating folder and evidence controls. Review the implementation and
direct evidence, classify Required/Optional/Out of scope, and repeat only affected
checks/review for required corrections. No public contract change is intended;
surface one if demonstrated rather than inventing an architecture expansion.

Endpoint: focused implementation, relevant docs, direct checks, independent review
and scoped local commit/integration. Preserve branches, worktrees and artifacts.
This intermediate slice does not authorize a release/install, push, PR, merge,
permission change or owner-data mutation; the completed authorized batch retains
its separately established local release endpoint and publication boundaries.
