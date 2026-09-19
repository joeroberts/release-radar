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

### September 16 inventory checkpoint

Fresh RO task `01a0a87f-60c9-7500-925c-0b77f10da62e` directly enumerated
15 ignored entries under `.superpowers/sdd`: its `.gitignore` and these 14
Markdown files. These are candidate records, not an approved migration set.

- `2026-08-27-codex-plugin-lifecycle/task-1-brief.md`
- `2026-08-29-delivery-goals-roadmap-readiness/ledger.md`
- `2026-08-29-delivery-goals-roadmap-readiness/task-1-plan-excerpt.md`
- Under `2026-08-29-release-radar-active-phase-selection/`:
  `progress.md`, `task-1-report.md`, `task-1-review-package.md`,
  `task-2-report.md`, `task-2-review-fix-1-package.md`,
  `task-2-review-package.md`, `task-2-security-fix-package.md`,
  `task-3-report.md`, `task-3-test-host-isolation-correction-report.md`,
  `task-3-test-host-isolation-correction-review-package.md`, and
  `task-3-test-host-isolation-qa-report.md`.

Bounded comparisons found no byte-identical replacement among the related
canonical records: completed task brief `3fb8fea0-9ffa-4d47-abcb-5a5c26ae5a4b`,
archived plugin plan `0ff7a384-fbb1-4ff1-bb0b-fbbd27b466a3`, active roadmap
`cd044b85-6519-4330-ae3c-dc0d9c20a65e`, and archived active-phase plan
`7d88279f-a192-4b4e-83ab-36e144a734dd`. Related records are not safe deletion
substitutes. No content moved; no IDs allocated or changed. Accepted ADRs and
current controlling records remain available and unchanged.

The worker could read/search historical files and Git history. Denying only an
archive directory would leave historical content reachable through readable shared
Git objects. Chief advice must resolve the minimum usable boundary before exact
destinations, catalog transitions, or permission changes are proposed. Fresh RO
and RW startup evidence is recorded in the current progress ledger; it does not
establish history exclusion.

### September 16 boundary advice — proposed, not authorized configuration

Read-only chief `01a0a884-aec5-7161-a2dc-dc17084da7dc` recommends preserving
existing branches, linked worktrees and original Git lineage while separating
ordinary file work from trusted Git operations. An ordinary worker would edit or
review current files with all original Git metadata denied; the coordinator or
Build Agent would perform scoped Git inspection, commits and separately authorized
publication. This supersedes the chief's earlier incomplete choice between merely
advisory exclusion and an independent current-only Git repository. No new Git store
or runtime manager is needed for the preferred candidate.

The proposed worker boundary denies the worktree `.git` pointer, the resolved
common Git directory (including objects, packs and worktree metadata), selected
historical files, and indexes that disclose them. Denying only the pointer or
archive directory is insufficient. Keep canonical archive content and catalog IDs
in place; a physical move is unnecessary for this candidate. Active ADRs and
controlling inputs stay readable. Historical passages inside those readable inputs
remain visible; path permissions cannot redact paragraphs.

The [official permission specification](https://learn.chatgpt.com/docs/permissions)
supports narrower deny rules within broader grants, but defines command sandboxing
separately from MCP, connectors, browser and computer-use controls. Effective roots
and all actually exposed history-reading routes therefore need verification;
native task creation exposes no profile or tool selector. No worker-only control
for every brokered route has yet been established. Do not claim all-route isolation.

Before implementation, propose exact worker-only settings and selected historical
paths for owner authorization. Verify current-input reads/scoped edits, denied
history reads/searches/Git retrieval, applicable non-shell denial, and deliberate
Main retrieval. Git/catalog-dependent checks belong to the trusted owner; do not
pretend the ordinary worker ran them. Build Agent must not execute arbitrary
worker-supplied commands with history access and relay their output. The existing
no-main-merges and external-action authorization boundaries remain unchanged.

This advice made no configuration or application change and ran no boundary test.
Both skill access and actual model/effort readback were unavailable to the chief;
the task used repository-local instructions with verified read-only roots.

### Owner-authorized existing-profile inheritance test — September 16

The owner subsequently approved changing only `rr-project-ro` and
`rr-project-restricted` to test inherited history restrictions. Main applied the
test to `/Users/jroberts/.codex/config.toml`, not the two proposed new profiles
below. Both existing profiles now deny canonical `.git`, `docs/delivery/archive`,
`.superpowers/sdd`, and `.codegraph`, plus those same workspace-relative paths.
Restricted's narrower shared-Git write grants were removed so they cannot override
the parent denial. Other build, network, default and profile settings are preserved.

Main deliberately read the
named historical file `2026-08-27-codex-plugin-lifecycle/task-1-brief.md` under
`.superpowers/sdd` successfully (17,851 bytes; contents suppressed). Build Agent
retained unrestricted runtime access and directly read canonical `.git/HEAD`.
No history is moved,
catalog identity changed or complete isolation claimed by this configuration edit.

Fresh RO worker `01a0a90c-dc2d-7263-b7d9-6429a6566ad2` inherited all four
specific denials and zero writable roots. Current `docs/README.md` was readable;
direct historical-file read/search, `.git/HEAD` read and `.git/objects` listing
were denied with `Operation not permitted`. This passed the bounded RO probes
despite the coordinator's initially stale supplied permission metadata.

Fresh RW worker `01a0a90c-e3a3-7931-adf6-e97455fb6711` inherited the denials
in worktree `/Users/jroberts/.codex/worktrees/8258/release_radar`. Current docs
were readable and an owned five-byte marker passed write/readback/removal.
Its initial history probes used metadata stat with discarded error details;
they do not establish read/search denial. Automatic approval review rejected
dispatch of a corrected direct-read/listing probe because those paths are
explicitly denied. No reroute, escalation or retry followed. RW history denial
therefore remains unverified by direct read/search. No suitable content-suppressing
non-shell reader was tested by either worker; no all-route isolation claim is made.

The app created the RW checkout detached at `8cd8cd8`; after the marker was removed,
Build Agent attached `codex/history-permission-probe-20260916` at unchanged HEAD
with clean status. This demonstrates trusted Git operation while worker Git is
denied, but does not erase the initial detached-start limitation. No commit or
publication occurred. The test branch/worktree are retained.

Read-only rejection investigation identified the failed action as coordinator02's
`send_message_to_thread` correction dispatch, before worker execution. The installed
desktop app includes an **Approve** slash-menu entry (command ID `autoreview`) for
recent auto-review denials, calling the supported one-action approval operation.
The documented semantics permit one retry through auto-review; they do not change
filesystem permissions or guarantee approval. The owner must select the specific
denial in the original coordinator task. Menu visibility for that retained denial
has not been inspected. No override, retry, policy edit or sandbox diagnostic was
executed during this investigation. Reference:
[Auto-review denial handling](https://learn.chatgpt.com/docs/sandboxing/auto-review).

Rollback removes the added absolute and workspace-relative deny entries from both
profiles, restoring RO to its prior workspace read grant. Restricted's previous
canonical shared-Git permissions were `.git = read` and writes to `.git/objects`,
`.git/refs/heads/codex`, `.git/logs/refs/heads/codex`, and `.git/worktrees`, under
`~/Documents/dev/joeroberts/RekonLabs/release_radar`. Preserve all unrelated settings
and any subsequent owner edits when restoring those exact entries.

### Earlier filesystem-only candidate — not installed

Main withdrew the premature approval request. Automatic native profile selection
and worker-only controls for other history-reading tools are unresolved. The
snippet below is retained as a proposed local-command boundary, not an actionable
installation request, approved solution, or blocker attributed to missing owner
approval. Complete those feasibility details before proposing any settings change.

Readback of the installed named profiles confirmed `rr-project-ro` grants all
workspace reads and `rr-project-restricted` separately grants shared Git reads and
selected writes. Preserve both existing profiles. The exact proposed addition to
`/Users/jroberts/.codex/config.toml` is two new profiles below. No default selection,
coordinator permission, application state or existing profile would change.

```toml
[permissions.rr-history-worker-ro.filesystem]
":root" = "deny"
":minimal" = "read"
"/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/.git" = "deny"

[permissions.rr-history-worker-ro.filesystem.":workspace_roots"]
"." = "read"
".git" = "deny"
"docs/delivery/archive" = "deny"
".superpowers/sdd" = "deny"
".codegraph" = "deny"

[permissions.rr-history-worker-ro.network]
enabled = false

[permissions.rr-history-worker-rw.filesystem]
":root" = "deny"
":minimal" = "read"
"/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar/.git" = "deny"

[permissions.rr-history-worker-rw.filesystem.":workspace_roots"]
"." = "write"
".codex" = "read"
"AGENTS.md" = "read"
".git" = "deny"
"docs/delivery/archive" = "deny"
".superpowers/sdd" = "deny"
".codegraph" = "deny"

[permissions.rr-history-worker-rw.network]
enabled = false
```

This is an initial boundary experiment, not the complete history selection or a
build-capable replacement profile. Native dispatch cannot select these profiles
through its exposed API; a supported selection route must be established before
launching a probe and claiming inheritance. Do not change a coordinator's profile
or launch under a different profile to pretend this prerequisite passed.

After authorization and effective-profile selection, a fresh assigned-worktree
probe would test current file reads, one reversible RW marker, archive and common
Git denial, and applicable brokered reads of one named historical record with
contents suppressed. Main would retrieve that exact record. No real history moves,
commits, builds or publication are part of this experiment. Final isolation still
requires exact selection of other completed/superseded records, necessary check
access, and verified controls on every applicable non-shell history-reading route.

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
