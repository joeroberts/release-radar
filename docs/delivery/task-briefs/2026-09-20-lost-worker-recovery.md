# Exact lost-worker recovery for Task02

Status: completed and non-authoritative. Recovery was delivered in 0.1.32,
verified for the named assignment, independently reviewed, and locally installed.
Current work and authorization are recorded in [progress](../progress.md).


## Objective and authority

The owner approved an app-owned Recover lost worker action to unblock the exact
Manage Project Task02 assignment without losing its committed tests or checkout.
Recover safely through typed application operations, then return to Task02. Main
coordinates; Build Agent owns compilation and Git. Shared-execution/1 applies;
installed skills are available to Main, with repository fallback if a worker
cannot access them. No unrelated connector redesign is authorized.

## Scope and exclusions

Inspect and change only the existing assignment/worker lifecycle, required native
management UI, immediate IPC boundary if needed, focused tests and owning mutable
documentation. Preserve signed peer verification, sandbox, permission profiles,
registration/generation checks, STOP, uncertain outcomes and owner acceptance.
No direct database/managed-file edits, bulk cleanup, hook/configuration changes,
ticket-definition changes, new service, broad process termination, or worktree
removal. Accepted ADRs and governing instructions remain untouched.

## Exact retained work and dependencies

- Root: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`.
- Project: `project-fffdc0e0b15b9b86`; registration
  `8edc840e-2847-4eeb-af68-282d5ed12b11`, generation 1.
- Assignment: `delivery-f913b890-7149-450c-bf8c-2b515cce75a0`.
- Lost worker handle: `FC3954DD-14A3-418C-A655-63C036492ABE`.
- Codex task: `01a0c1c3-71e6-7171-8b50-e6e00cae5f04`.
- Preserved tests-only commit: `0a51ee1d8484d960effe1d55c71e510e162cf2ab`.
- Causal RED: `.build/native-checks/manage-project-task02-red-4.xcresult`,
  `project-health-refresh` absent, one failed test against unchanged production.
- Exact continuation request and observed `blockingAssignment` refusal are retained
  in [progress](../progress.md); do not regenerate or retry unchanged requests.

The observed UI says authorized. The old turn completed, but closure is unverified.
Worker handles exist only in the coordinator's memory. A bounded OS scan found no
matching assignment launch argument; this observation alone is not a closure receipt.
Existing retirement requires closure and removes the checkout, so it is unsuitable.

## Recovery contract and material risks

Before production edits, identify a concrete, supported source of exact process
identity and closure evidence usable for this existing assignment. Do not design
only for future workers or invent historical PID/exit records. If legacy evidence
cannot establish safe recovery, report that precise limitation before implementation;
do not weaken a check to promise an unblock.

The owner action must validate exact current project/root/registration/assignment,
revalidate before writing, and preserve uncertain or unavailable evidence. A stale,
live, reused PID, inaccessible process inventory, mismatched identity or concurrent
operation must not authorize replacement. A completed turn, absent session, timeout
or missing connector handle is not proof of physical closure.

On proven safe recovery, record the bounded action and its actual evidence through
existing app-owned lifecycle/audit patterns, preserve branch/checkout/test commit,
and permit ordinary continuation validation. Do not fabricate task completion,
review, acceptance or publication. Recovery must remain idempotent or have explicit
replay semantics, and interruption must retain a truthful recoverable state.

[ADR-001](../../architecture/ADR-001-release-radar-boundaries.md) retains app-owned
state, signed/sandboxed boundaries and exact authorization. The existing Manage
Project UI and future managed workers consume this recovery path. Any additive
persistence or IPC change must preserve old records and fail safely when legacy
identity evidence is absent; no data migration or accepted-ADR edit is presumed.

## Direct checks and acceptance

Use focused repository-native tests first for the reported lost-handle case, exact
identity rejection, live/unknown worker refusal, stale/concurrent requests,
interruption/replay and preservation of committed work. Build Agent runs native
checks with established offline dependencies and canonical `.build/` output.
Verify the actual action and recovery feedback against the current Manage Project
surface and relevant approved design at compact/wide sizes; use existing UI tools.
No new harness or broad suite. Successful unchanged checks are not repeated.

Acceptance requires a working safe recovery for the retained assignment (or an
honest evidence blocker), direct test evidence, independent review and a normal
continuation path preserving the Task02 tests. A future-only prevention change
does not satisfy this repair.

## Assignment, review and endpoint

Main owns this brief/catalog/progress. Delivery writer: fresh isolated task, proposed
Sol/high for uncertain process ownership and recovery; ceiling Astra/high for a
named unresolved issue. No Ultra. Owner explicitly approved a fresh isolated Codex repair task outside the blocked
RR launcher. This exception applies only to this repair; RR remains authoritative
for assignment recovery and the subsequent normal Task02 continuation.
Baseline: committed canonical branch `codex/manage-project-context-recovery` with
this brief; Build Agent supplies its exact revision before launch. Delivery owns
only the scoped source/tests/mutable design; Build Agent serializes tests and Git.

One fresh independent Sol/high reviewer covers recovery/architecture, security and
UX risks; only Required findings block. No self-review or recursive review.
Endpoint: reviewed scoped local commit and integration, then the standing signed
local delivery workflow when this recovery must run in the installed app. Exact
live recovery is limited to the named assignment and must preserve its resources.
No branch push, PR, merge, permission expansion or broader owner-state mutation.
Catalog acceptance remains a separate explicit approval of the validated transition.
