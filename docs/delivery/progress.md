# Release Radar delivery state

## Current outcome and authorization

C8's bounded local source checkpoint is delivered and independently reviewed.
The owner launched this pilot from handoff `69d62b0`, following approved operating
baseline `44dc75b`, and explicitly resumed it with Astra Medium after a model-change
pause. The [C8 brief and installation handoff](task-briefs/2026-09-06-c8-source-repair/c8-source-repair-brief.md)
retains the complete scope, direct checks, exact candidate and future installation
sequence. It remains active as supporting handoff material; this ledger owns status.

Source implementation: `35e2ef60347e366ab43f8131ab5d99a99af6a6d8`.
Reviewed source/handoff candidate: `5fd353960617c0e70dcc39a7d2d813567b83bb24`,
locally integrated on `codex/full-product-architecture-plan`. The source handoff
worktree contains the reviewed code and native installer. The older canonical
checkout's unrelated changes and native default staged bundle remain preserved.

The explicit orchestrator execution goal covers this reviewed source checkpoint,
durable results, local commits, task archival and installation handoff. It does
not change Release Radar Delivery Goals or owner acceptance. No push, PR, merge
to a remote branch, installation, app/owner-state mutation, repository binding,
catalog acceptance, audit reconstruction, metadata deletion or hooks were performed.

## Changed behavior and direct verification

Only exact case-sensitive `.DS_Store` regular files are excluded after descriptor-
relative no-follow type inspection. Discovery and index-write stability share the
rule. Directories, symlinks, catalog registrations, other prohibited paths and
unregistered documents retain rejection. Catalog schema v1, guidance v2, digest
encoding, artifact/evidence identity and conservative read stability are preserved.
The shared version is `discoveryExclusionVersion = 1`; the design and shipped
reference document its compatibility boundary.

The focused Xcode result bundle reports **46 passed, 0 failed, 0 skipped** across
reader/catalog, index and shipped-reference checks. Existing suites cover root/
nested metadata invariance and rejection/containment cases. Release build and
source/bundled-helper check/write checks passed on disposable repository copies
with root/nested metadata, with zero generated-index changes. The exact test
command is in the brief. The orchestrator also directly ran the canonical staged
helper against the actual repository with `.DS_Store` retained: documentation
validation passed. The integration owner repeated the relevant documentation check
on the integrated source worktree; no unchanged source tests or build were rerun.

The unlaunched canonical candidate is
`dist/ReleaseRadar-C8-source-35e2ef6.app`, version 0.1.6 build 1. Its deep strict
signature and recorded main-binary hash were verified after persistence. The
brief records exact identity, future safe staging/native installation commands,
and the retained temporary build/test/fixture paths. No temporary cleanup occurred.

## Independent review and bounded tasks

- “Resolve C8 compatibility contract” (`01a0782e-d28d-71b1-990c-50d909bb150b`),
  confirmed Astra High, produced `28b0792`; decision preserved and task archived.
- “Deliver C8 metadata reader repair” (`01a07833-8c69-78a0-9dde-4c4674e345eb`),
  confirmed Terra Medium, delivered implementation, tests, handoff corrections and
  local integration. It confirmed its work and candidate/helper processes stopped;
  the task is archived after preserving its result.
- “Review C8 source candidate” (`01a0783c-c2a5-7b83-9f26-05ace1cbb6fe`), confirmed
  Sol High, reviewed reader correctness, contract and filesystem safety together.
  Its one Required finding concerned direct installation copying in `14ec778`.
  The same reviewer confirmed `5fd3539` resolves it through the native verified
  installer with preservation of prior staging. No Required or Optional findings
  remain. Source needed no correction. Review finished, processes stopped and
  the task was archived after its result was preserved.

The pilot followed through to local commits and a concrete handoff. One handoff
finding needed two bounded documentation corrections; source checks were terminal.
Task-list omissions were resolved through narrow task-ID diagnostics without
creating duplicates. Runtime metadata exposed inherited orchestrator Extra High
at startup; Astra Medium was subsequently applied and confirmed, including the
owner's explicit resume. Architect/delivery/reviewer settings were confirmed as
assigned. No Ultra or new worker goal was used. Role choice and observed rework
are recorded here; they are not a model-quality comparison or a new scorecard.

## Remaining installed acceptance and next authorized decision

**C8 installed acceptance remains outstanding.** The concrete next decision is
owner authorization for the exact brief's preparation and native no-launch
installation of the canonical C8 candidate into `/Applications/ReleaseRadar.app`,
followed by separately authorized installed-reader/checker and supported app
readback. The proposed sequence preserves the previous default staged bundle and
uses the existing installer's verification, atomic promotion and rollback.
None of that installation sequence has been executed.

The installed bundle was not changed. Final supported application readback
returned `appUnavailable`. The last successful readback during this pilot reported
`isComplete: false`, `catalogInvalid` / `prohibitedContent`, and zero project
repository bindings; it is not a fresh claim of current application state. Final
canonical documentation validation with the candidate helper passes. Passing source
validation does not repair installed state or establish application availability. Binding, pending catalog acceptance and post-reset recovery remain
separate owner-authorized operations; no managed-current synchronization is claimed.

The [full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capability rows and their accepted/proposed distinctions. Broader
C8 freshness, lifecycle/recovery, portability, future planning and I9 remain outside
this pilot. Do not start the next slice automatically. The
[Historical operating-baseline closeout](archive/2026-09-06-operating-baseline-closeout.md)
preserves earlier approvals and limitations; it does not control current status.
