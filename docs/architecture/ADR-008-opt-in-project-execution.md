# ADR-008: Opt-in project execution

- Status: Recorded owner-approved decision; extracted from the September 16–17, 2026 Outcome 3 authorization.
- Recorded: September 22, 2026.

## Context

The approved Outcome 3 work added project execution to Release Radar. The decision
was recorded in a delivery brief rather than an ADR. Neither the read-only observer
boundary in [ADR-001](ADR-001-release-radar-boundaries.md) nor the fixed installer
helper in [ADR-002](ADR-002-codex-plugin-lifecycle.md) defines this separate capability.
This record preserves the existing decision before removal of the inactive brief;
it does not approve a new architecture or alter those existing ADRs.

## Decision

Execution is an opt-in, app-owned capability integrated with project onboarding
and the existing Release Radar plugin. The app derives protected assignments,
bounded context, role settings and permissions from exact registered work. It owns
its generated worktrees and authorizes a separate signed Coordinator to run the
assigned work through the supported local App Server. Existing desktop sessions
and unrelated worktrees do not become app-owned merely because they are observable.
The installer helper retains only its fixed status/install/remove/reinstall role.

The owner explicitly selects one existing Codex home, used consistently for setup,
verification, preparation, startup, follow-up and retirement. This uses the existing
account; credentials and history are not copied. Folder grants, bookmarks and trust
remain machine-local. Another machine requires selection of its own existing
context and regeneration only of RR-owned configuration. Prompt-supplied paths or
settings cannot override that selection or confer authority.

Assignments bind exact project/root, registration/generation, work revisions,
candidate and selected-context identity. App-owned protected state determines
admission. Workers receive only their bounded checkout and permitted inputs, with
history, sibling and management access excluded. A review uses a separately assigned
candidate; a role label or claimed thread identity does not prove independence.
Signed internal XPC carries the narrowly scoped context capability to Coordinator;
the installer helper gains no project, Git, credential or general command authority.

Project hooks supplement assignment admission; they are not a universal sandbox
or immediate STOP mechanism. STOP has its own control path. Owner disablement and
conflicting configuration are preserved. Uncertain starts, lost connections and
partial setup remain uncertain and block replacement until supported recovery
establishes the required facts. Closure, retirement, delivery result and owner
acceptance remain separate. Retirement preserves dirty work and committed history.

## Consequences and limits

The app can prepare and control work it owns without pretending it has attached to
an unrelated desktop runtime. It must preserve exact request replay, failure
recovery, revocation and physical-closure evidence across component boundaries.
No global home entitlement, credential migration, separate authentication engine,
generic executor, new execution dashboard or headless deployment follows from this
decision. Runtime details belong in the mutable
[project execution specification](../design/project-execution-design.md).

This record grants no permission to onboard a repository, install hooks, alter
configuration, launch work or mutate owner data. Release Radar's own repository
remains offboarded. It claims no new verification or owner acceptance; deferred
second-Mac and signed-upgrade checks remain in
[#91](https://github.com/joeroberts/release-radar/issues/91) and
[#106](https://github.com/joeroberts/release-radar/issues/106).

## Decision provenance

The [historical Outcome 3 setup brief](https://github.com/joeroberts/release-radar/blob/c521851730ba9be5d51c012489ea049bdd402022/docs/delivery/task-briefs/2026-09-16-outcome3-execution-setup/brief.md)
records the September 16 implementation authorization under “Scope, authority and
dependencies” and the September 17 owner-approved existing-home selection under
“September 17 approved shared Codex context correction.” Later implementation and
recovery details are specifications, not additional authority granted by this ADR.
