# Outcome 3: simple coordinator-managed workspace

## Owner correction and outcome

On September 14 the owner rejected the oversized runtime-manager proposal and
instructed the coordinator to do the work: the coordinator creates tasks with the
correct settings; historical files move where delivery/review agents cannot read
or search them; current work remains usable; the coordinator retrieves specific
history when needed. Do not ask the owner to create tasks or select profiles.

The owner also requires chief-architect review before changes. This fresh bounded
assignment establishes the exact simple arrangement and its implementation steps.
It is not another whole-runtime research project. RR app-controlled task creation,
new authentication/grant systems, VMs and a separate worker client are not required
by this correction and must not be introduced as prerequisites.

## Completed read-only checkpoint (historical scope)

A fresh chief architect (Astra/high; ceiling Astra/high) owns the concrete boundary
assessment. Start at the committed kickoff revision named by the coordinator.
Read the catalog/root index, current ledger and only relevant existing assessment
facts. Coordinator is the existing Codex coordination task, not a new RR service.
Read only relevant permission-profile and supported task-creation configuration.
Return the exact supported creation/configuration route the coordinator can use,
proposed active/history paths and migration selection, and direct allowed/denied
checks. State an exact blocker only if those simple controls cannot be composed.
Do not require defenses against owner-authorized changes or hypothetical future
interfaces. Check actual exposed reading routes insofar as they reach these files.

Do not edit source, accepted ADRs, AGENTS, runtime permissions, config, app state,
SQLite or historical files at this checkpoint. No new server or permission probes,
publication, installation or deletion. Return concise findings to the coordinator;
no new report hierarchy or generalized framework. The coordinator records the result
in the current ledger and prepares the exact bounded delivery from it. Retain
unrelated dirty proposal files and existing fixtures. No subagents or archived reuse.

## Checks and decision

Required properties: coordinator-created task uses correct settings before work;
current inputs readable and scoped outputs writable; historical location read/search
denied; deliberate coordinator retrieval remains usable. File moves must preserve
content and catalog identities; active ADRs stay available unchanged. Classify
completed supporting evidence separately from obsolete instructions. Before any
real migration/configuration write, resolve exact targets and chief-architect advice.
Do not declare enforcement from a folder name, profile label or prose alone.

## Authorized implementation continuation — September 14

The owner's subsequent instruction opens the bounded setup below and supersedes
only the checkpoint's no-configuration-write endpoint. Standard: shared-execution/1;
the installed 0.1.16 skill exposes standard 1. The replacement coordinator owns
canonical main at `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
from `e80ab27` (workingTree: unrelated pending proposal preserved).

Outcome: coordinator-created workers use a reusable restricted profile tied to
their assigned workspace, with obsolete history outside their read/search access.
The profile correction is an independently deliverable part; it does not establish
the full outcome or authorize migration without a working boundary.

Exact authorized configuration change in `/Users/jroberts/.codex/config.toml`:
replace the canonical absolute-path write entry with this workspace-relative table,
preserving the existing root/minimal/network rules and all unrelated bytes:

```toml
[permissions.rr-project-restricted.filesystem]
":root" = "deny"
":minimal" = "read"

[permissions.rr-project-restricted.filesystem.":workspace_roots"]
"." = "write"

[permissions.rr-project-restricted.network]
enabled = false
```

The [official permissions specification](https://learn.chatgpt.com/docs/permissions)
defines these rules for every effective runtime and profile-defined workspace root,
which may include auxiliary roots. No global default, legacy sandbox setting,
other profile, runtime manager, private IPC or desktop bundle change is authorized.
The recorded Codex Computer Use denial must not be bypassed.

Assignment: fresh chief architect Astra/high reviews this exact change before the
write; fresh delivery owner Terra/medium owns only the named profile edit and its
direct checks, from the coordinator's committed continuation baseline. The delivery
root is the fresh assigned worktree reported at startup; the configuration file is
a serialized shared resource. The coordinator alone owns this brief, catalog/index
and progress changes. Fresh independent reviewer Sol/high covers configuration and
security scope plus the small documentation candidate; ceiling Astra/high. No
subagents. Do not claim these setup/review tasks themselves have restricted startup.

Direct checks: parse TOML before/after; verify the exact expected named-profile
structure and byte preservation outside the single replacement; read back the
installed configuration. Run the installed documentation tool check on the exact
repository root and inspect the scoped diff. Static configuration checks cannot
prove runtime restrictions. Supported per-task profile selection and effective-root
readback must precede runtime allowed/denied tests and any real history migration.
Test actual available shell, Git and non-shell reading routes before claiming
history exclusion. Do not create new probe infrastructure while selection is blocked.

Acceptance: the profile contains no fixed checkout/worktree grant; other settings
are preserved; direct checks and independent review pass; current records distinguish
the delivered correction from the unresolved startup/history boundary. The complete
workspace outcome additionally requires verified restricted startup and history
exclusion. Migration targets remain unselected; no record moves are authorized yet.

Architecture: preserve [ADR-001](../../architecture/ADR-001-release-radar-boundaries.md)
and [ADR-006](../../architecture/ADR-006-managed-repository-documentation-contract.md).
No app persistence/schema change; configuration selection compatibility is the named
risk. Restore the old single path grant only under explicit recovery direction.
Local scoped documentation commits are authorized. No push, PR, merge, release,
installation, deletion, SQLite, binding or application catalog acceptance.

## Authorized approval-prompt test — September 14

After the restricted coordinator's child launch failed under `approval_policy =
"never"`, the owner authorized changing approval behavior to `on-request` and
retrying the same daisy chain. Chief `01a0a048-221f-7f50-b051-de09934a5f59`
confirmed the supported bounded next test. The canonical coordinator owns the
single-key `.codex/config.toml` addition: `approval_policy = "on-request"`.
This is a trusted Release Radar repository default, not a per-task override;
other sessions loading this repository layer may inherit it. Global configuration,
named permission profiles, filesystem/network grants and autoapproval are unchanged.

Check TOML/readback, then ask existing restricted coordinator
`01a0a03e-8a7e-7c03-983b-42a5aab0c239` to retry the single child-launch test.
Main must not launch that child. Read effective turn policy; a retained `never`
override is a blocker, not permission to bypass it. If a prompt appears, await its
actual approval. If a child starts, test the previously authorized harmless
workspace read/write, canonical README read, archive enumeration and Git availability
with contents suppressed. No real history migration or other mutations. One fresh
independent review covers the exact config addition and direct results. Local commit
is authorized; no publication or changes to other project defaults. This supersedes
only the prior prohibition on this exact repository approval-default change.
