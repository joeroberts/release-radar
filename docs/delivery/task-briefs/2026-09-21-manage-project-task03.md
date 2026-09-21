# P6 Manage Project — Task03: verify access and recovery

## Outcome and scope

Complete the existing `rr-p6-manage-project-task-03`: verify authorization,
archived and removed project access, partial failures and accessible navigation
with independent UI and recovery review. Preserve the approved task definition.
Task01 and Task02 are implemented and reviewed; this assignment covers remaining
acceptance properties, not a repeat of their successful checks.

Use [Task02](2026-09-20-manage-project-task02.md) for relocated-control boundaries,
the [selected design](../../design/phase6-workspace-toolbar-proposal.md) and its
wide/compact references, and [ADR-001](../../architecture/ADR-001-release-radar-boundaries.md)
for retained authority boundaries. The [ledger](../progress.md) controls current
authorization and evidence. No public contract, persistence, migration or recovery
policy change is intended. Navigation consumes this management surface next;
Archive/Remove relocation and Guided Setup remain separate tasks.

## Dependencies and assignment

Start from canonical `codex/manage-project-context-recovery`, including integrated
Task02 `5ab10618` and ledger `3e97b67f`, plus the committed preparation of this brief.
RR must return a baseline containing that integration and this brief before work
starts. Use shared-execution/1 and the exact canonical project identity; the app
assigns an isolated checkout. Confirm effective worker model/effort from supported
worker status, not merely this document.

Assign an independent QA/recovery worker that authored neither Task01 nor Task02.
Defined-scenario coverage starts at Terra/medium; named exploratory recovery
ambiguity may escalate to Sol/high, with Astra/high as the ceiling. No Ultra.
One independent worker can cover UI, authorization and recovery risks; do not
create separate reviewers for the same properties or review this review.
Main owns ledger/catalog metadata. Existing Build Agent owns compilation, tests
and Git. The worker owns bounded test selection, direct scenario assessment and
findings. No product edits during this verification assignment; return any
Required defect to Main for a bounded correction and affected recheck.

## Direct verification and material risks

First map existing direct evidence to the remaining properties. Run only checks
that resolve a named uncovered property; source inspection alone does not prove
an authorization or recovery boundary.

- Exact registration/root identity and stale selection: a late response or stale
  preview must not update or mutate another selected project.
- Archived/removed access: management availability and callbacks must retain the
  existing lifecycle policy. Exercise disposable fixtures, not owner projects.
- Partial failures: independently loaded sections remain usable; retry targets
  the failed section and retains exact identity and actionable errors.
- Accessible navigation: moved controls are reachable in sensible keyboard order;
  error focus/announcement and root/worktree recovery remain within the presented
  management surface. Retain the completed wide/compact visual and focus evidence
  unless a newly identified defect affects those properties.
- Evidence and folder controls retain existing freshness, authorized-root and
  preview/confirmation protections at their changed integration boundaries.

Use repository-native focused tests and existing synthetic rendering fixtures.
Build supplies test results and images; inspect actual rendered images against
the selected references where a remaining visual property needs evidence. Do not
repeat the held-app inspection route that exposed live owner rows, create a new
capture harness, weaken tests or change permissions/configuration. Preserve all
existing source, branches, worktrees, installers and temporary artifacts.

## Acceptance and endpoint

Return concise passed/failed/unavailable results for the properties above with
exact source basis and useful result paths. Classify findings Required, Optional
or Out of scope. Only correctness, authority, recovery or explicit acceptance
defects block; optional polish does not. Missing direct evidence remains explicit.

Completion means remaining Manage Project acceptance properties have direct
evidence and independent assessment, or a precisely identified Required defect
has been corrected and checked. Main records results in the existing ledger;
Build commits scoped test/documentation changes if any. Do not produce a separate
review-report artifact solely to restate messages or test results.

No owner data mutation, RR task completion/acceptance, permission change, branch
push, PR, merge or installation is authorized by this verification assignment.
The completed app batch retains the owner's separate standing local-release
authorization; Main releases that endpoint only after Manage Project is complete.
