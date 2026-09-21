# P6 Navigation — lifecycle controls and remaining navigation

## Objective and authority

Deliver the existing `rr-p6-navigation` outcome after Manage Project 0.1.34:
Archive/Remove belong in Manage Project, with remaining approved navigation
complete and independently verified. The owner explicitly resumed Navigation on
September 21 after PR #115 merged. Task-plan revision 1 retains both existing
task definitions; no task adoption or definition change is authorized here.

Use shared-execution/1 (installed standard v1 and guidance v3), the
[selected design](../../design/phase6-workspace-toolbar-proposal.md), its
[wide](../../design/mockups/phase6-persistent-workspace-toolbar-proposal.png) and
[compact](../../design/mockups/phase6-compact-workspace-toolbar-proposal.png)
references, and [ADR-001](../../architecture/ADR-001-release-radar-boundaries.md).
Main inspected both references. Text selections control over obsolete raster
colors or Save-query text. Preserve existing near-black navy/RDS presentation.
The [current ledger](../progress.md) controls authorization and delivery state.

## Scope and dependencies

- Task01: relocate Archive and Remove from Overview into exact-identity Manage
  Project. Reuse the existing typed previews, confirmations and operations.
  Preserve cancellation, retained history, authorization, monitoring suspension,
  recovery, repository files and other projects. Archive is reversible; removal
  retains read-only history and creates a new registration when re-added.
- Task02: assess the remaining approved sidebar/navigation behavior against the
  selected design, implement only demonstrated gaps, and verify the completed
  navigation with independent UI review. The fixed documentation-checking footer
  is already present; do not rewrite working behavior. Preserve accessible status,
  global/project routes, compact icon navigation and wide labels.
- Exclude delivered toolbar/search/save-query changes, metrics, guided setup,
  documentation reconciliation, plan reconstruction, RDS API changes, worker
  cleanup, permissions/configuration, new persistence or public contracts.

The owner's September 21 closeout correction explicitly excludes all compact
Overview layout changes and their containment regression test. They are tracked
separately in [GitHub #116](https://github.com/joeroberts/release-radar/issues/116),
which must start fresh when authorized; its experimental implementation is not
to be retained for reuse. Integrate only the valid Navigation test corrections,
verify that exact candidate and finish its independent review/local release.
After the owner's Codex restart, record verified evidence, complete the two
existing tasks and move Navigation to Needs review through supported operations.
Final owner acceptance remains separate. Worktree cleanup is separate closeout work.

The baseline is merged main `f1e8d48da1e138b75c78b9ae763130e90df5ccb9` plus the
committed preparation containing this brief and catalog/index updates. Each
dependent assignment starts from a committed baseline containing its prerequisite.
Task01 precedes Task02. Guided Setup consumes the result later and is not part
of this assignment. Existing accepted lifecycle policy is unchanged, so no new
migration, compatibility or recovery contract is intended.

## Ownership and material risks

Main owns coordination, ledger, brief and catalog metadata. Build task
`01a0c4b1-e429-78f0-8142-c85a134b4913` owns compilation, Git integration and release
operations. The RR-managed delivery writer owns only affected app composition,
focused tests and necessary mutable design clarification in its isolated checkout.
Likely touchpoints are ProjectOverviewView, ManageProjectView in
ProjectLifecycleSupport, and their SidebarView callbacks; discover precisely
with CodeGraph. No simultaneous writers to those files or build outputs.

Start ordinary implementation at Terra/medium. Escalate a named unresolved issue
to Sol/high only when needed; ceiling Astra/high. Independent review starts at
Terra/high, with Sol/high available for difficult recovery/authority analysis.
Verify effective settings through worker status. Ultra is prohibited.

Concrete risks are selecting the wrong project after a delayed preview,
registration changes while a sheet is open, inaccessible nested confirmations,
loss of error/cancellation recovery, and accidental changes to archive/removal
semantics. Preserve Manage Project independent section loading and local retry.
Use disposable fixtures; no archive/removal of owner projects or live data tests.

## Direct checks, review and acceptance

Use test-first repository-native tests for changed behavior. Prove controls moved
out of Overview and are reachable in Manage Project, invoke the same exact-target
operations, preserve confirmation/cancel paths, reject stale registrations and
recover from failed previews/actions. Check the immediate integration boundary,
retained history and access behavior where relocation changes it; do not repeat
unaffected service suites solely for procedure.

Build selects focused existing lifecycle/Manage Project/native rendering tests
and supplies direct results. Inspect the running or native-rendered actual
surface at wide/compact widths against the references, including scrolling,
keyboard reachability, focus and error feedback. Existing synthetic fixtures are
preferred over exposing owner rows; do not create another capture harness.
Report unavailable runtime coverage honestly.

One fresh independent reviewer, who authored neither implementation, covers
the final Navigation candidate and direct evidence for UI, authority and recovery.
Classify findings Required, Optional or Out of scope. Correct Required findings
and repeat only affected checks/review; no review of a review.

## Delivery endpoint

Complete both task scopes, necessary docs, direct verification, independent review
and scoped local integration commits. Then perform one standing-authorized local
patch release: matching metadata/tag, versioned signed DMG in dist and Downloads,
verified installation, and exact tag push. Preserve existing release tags and
installers. After installation, preserve the handoff and wait for the owner's
Codex restart before connector calls. No branch push, PR, merge, public release,
notarization, owner acceptance, or unrelated owner-state mutation is granted by
this brief. The later explicit owner goal above authorizes verified evidence,
the two existing task completions and Needs review after restart. Managed
assignment preparation/launch remains within the
existing onboarding authorization for this exact registered work.
