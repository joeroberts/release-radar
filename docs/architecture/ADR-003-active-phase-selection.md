# ADR-003: Active-phase selection authority and projection publication

- Status: Accepted
- Date: 2026-08-29
- Delivery: RR-R9

## Context

Release Radar already persists zero or one explicit active phase per project in
`project_active_phases`. The active phase selects the project's current board
projection; it does not own phase, ticket, dependency, review, evidence, or
audit history.

ADR-001 assigns delivery-structure mutation to agents through the app's typed
bridge and prohibits owner-facing manual ticket transitions. RR-R9 adds a
narrow owner decision that ADR-001 does not yet describe: the owner may choose
which existing phase is the project's current working context. RR-R9 also
requires an authorized agent to make the same choice through one typed MCP
command.

## Decision

`project_active_phases` remains the sole active-phase authority. It continues
to represent zero or one selected phase per project and requires the selected
phase to belong to that project. RR-R9 adds no schema or second active-phase
state.

Active-phase selection is a working-context decision, not a manual delivery
transition or a phase-management surface. The owner may select an existing
phase from Project Overview or Phase Board. This exception does not authorize
owner phase creation, deletion, rename, reorder, ticket editing, or lane
transitions; those boundaries from ADR-001 remain unchanged.

Owner and agent entry points use the same additive
`AgentCommand.setActivePhase(phaseID:)` dispatcher case. The app process remains
the only SQLite opener and writer. An owner command executes only while the
existing exact-root security-scoped bookmark is resolved and active. An agent
command retains the existing signed same-user transport and exact authorized
project-root resolution. Both paths validate same-project phase ownership in
the app transaction, then atomically persist the pointer, durable request
receipt, and one project/phase-scoped audit. Owner and agent actors remain
`release-radar-owner` and `release-radar-agent`, respectively.

The command is additive within command-envelope version 1 and bridge wire
version 2. Existing payload, deadline, signing, strict input, durable replay,
request-ID-reuse, unavailable, and outcome-unknown contracts remain unchanged.
No mutation is retried automatically.

Dashboard refresh is a read-only postcondition of a committed command. For an
agent request, the bridge returns the committed result before post-reply work;
the dashboard refresh begins before outbound notification draining. A refresh
failure never changes the successful command result and exposes only a
read-only reload recovery.

The app prepares the selected project's dashboard, workspace, dependency,
activity, and visible-selection values before publishing them as one coherent
main-actor state change. Overlapping reloads must not allow an older prepared
snapshot to publish after a newer reload has begun. The owner model creates no
request when the selected phase is already active, while a selection is saving,
or while its committed result still needs a read-only refresh. UI disablement
is not the authority for those guards. The agent command may still audit a
fresh assignment of the already-active phase as explicit agent intent.

A project with phases and no active pointer is a valid persisted state. Its
project projection exposes phase choices while its board remains absent until
one phase is selected. A zero-phase project retains the existing tracking-state
recovery.

RR-R9 does not change ticket-dependency semantics. Ticket dependencies remain
valid across phases within the same project. Board cards and dependency-graph
nodes remain scoped to the selected phase, while the selected ticket's detail
may continue to truthfully reference its existing cross-phase dependencies.
Changing the active pointer never rewrites or hides that history.

## Consequences

- Owner active-phase selection is the only new owner delivery-structure
  control authorized by this decision.
- UI filtering is never trusted as validation; the dispatcher and composite
  foreign key remain the enforcement boundary.
- Projection loaders need current-request publication ordering in addition to
  preparing all values before assignment.
- A saved-but-not-refreshed selection cannot dispatch a replacement mutation;
  recovery reads the authoritative pointer.
- RR-R9 acceptance must preserve existing cross-phase ticket-dependency
  references and every historical phase and ticket record.

## Prohibited alternatives

- Direct owner or agent writes to `project_active_phases`
- A second active-phase field, cache, preference, or schema migration
- Treating a picker selection as committed before the audited dispatcher result
- Publishing a new phase label with stale board, dependency, activity, or
  selected-ticket state
- Allowing an older overlapping reload to overwrite a newer requested refresh
- Retrying `setActivePhase` after a committed result or uncertain outcome with
  a replacement request ID
- Removing or suppressing valid cross-phase dependency references as a side
  effect of active-phase selection
