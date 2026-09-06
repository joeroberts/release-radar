# Historical C8 and merged-baseline closeout

Historical and non-authoritative. This preserves the prior progress ledger at
`acfaeed`; its authorization statements describe completed work only. Current
authorization and sequencing belong to [the progress ledger](../progress.md).
Relative links in the preserved record were originally relative to `docs/delivery/`.

# Release Radar delivery state

## Remote starting baseline

The owner authorized committing, pushing and merging the complete reviewed baseline.
[PR #21](https://github.com/joeroberts/release-radar/pull/21) is its remote delivery
record: C8, the approved operating model and full-product plan, RekonDesignSystem
scope clarification, and approved continuity decisions. Use that PR's merge commit
on `origin/codex/release-radar-mvp` as the next task's starting baseline.

Publication checks on the reviewed source passed: **46 tests, 0 failures, 0 skipped**
using the focused C8 command recorded in its brief, plus native documentation and
scoped diff checks.
The application connector again returned `appUnavailable`; Git delivery does not
establish repository binding or catalog acceptance. Retained installation files and
unrelated canonical changes are excluded. “Kick off C8 repair pilot”
(`01a0782d-75da-7653-a5ce-3023c738d499`) was idle/completed and is now archived;
its outcome and stopped worker records remain below.

The next task should settle the remaining shared architecture contracts and deliver
the usable project lifecycle under the approved plan and operating model. This
publication does not launch that task or authorize the entire roadmap's implementation.
Temporary verification output remains at `/tmp/release-radar-c8-merge-verification`,
`/tmp/release-radar-c8-merge-verification.log`, and
`/tmp/release-radar-reviewed-baseline-pr.md`; prior retained paths remain in the C8
brief. No cleanup was performed.

## Approved continuity decisions

The owner selected removal from tracking with retained read-only history;
self-contained portable project records, managed documents and evidence; and
Mac/repository authority with read-only cloud publication to the companion.
ADR-001 records these policies. The full-product plan, companion draft and affected
controlling designs are reconciled without changing v1 archive behavior or claiming
new implementation. Remaining schemas, migration/file recovery and publication
details remain to be designed. Project-editing additions were not selected by these
answers, and RekonDesignSystem's existing appearance scope is unchanged.

The documentation candidate `8f82b46` and bounded correction `62d41eb` pass native
documentation and scoped diff checks; all six canonical copies are verified.
“Review approved continuity policies” (`01a0788a-d5cb-7bb2-99d9-e18ddf585d18`),
confirmed Sol High, found one ambiguity between removal and restore. The correction
separates remove/re-add, archive/restore and full-backup recovery; the same reviewer
confirmed it resolved, with no remaining findings. The review task was archived
after work stopped and its result was preserved here. Connector readback still reports
`appUnavailable`; no managed-current tracking is claimed. These decisions authorize
no implementation, external publication or app-state mutation.

## RekonDesignSystem scope clarification

The owner reaffirmed RekonDesignSystem adoption and excluded adding or changing
light/dark support. The full-product plan and controlling dashboard design now
require using its existing components, tokens and appearance as provided. The
previous theme-decision prerequisite is removed; brand asset variants do not
authorize app theme work. Candidate `251c7e9` passed the repository documentation
check and scoped diff check. “Review RekonDesignSystem scope clarification”
(`01a0787e-0ba2-70e3-8b84-37a4659843c1`), confirmed Terra High, completed with no
findings and was archived after its result was preserved and work stopped. Canonical
copies are verified. The connector still returns `appUnavailable`; no managed-current
tracking or app-state change is claimed. This correction does not open implementation.

## Current outcome and authorization

C8's bounded `.DS_Store` repair is closed: source delivery is independently
reviewed, and installed-reader/checker verification passed on 2026-09-06.
The owner launched this pilot from handoff `69d62b0`, following approved operating
baseline `44dc75b`, and explicitly resumed it with Astra Medium after a model-change
pause. The [C8 brief and installation handoff](task-briefs/2026-09-06-c8-source-repair/c8-source-repair-brief.md)
retains the completed scope, direct checks, exact candidate and executed installation
sequence as a non-authoritative completed task record; this ledger owns status.

Source implementation: `35e2ef60347e366ab43f8131ab5d99a99af6a6d8`.
Reviewed source/handoff candidate: `5fd353960617c0e70dcc39a7d2d813567b83bb24`,
locally integrated on `codex/full-product-architecture-plan`. The source handoff
worktree contains the reviewed code and native installer. The older canonical
checkout's unrelated changes remain preserved; the previous native default staged
bundle is retained at the backup path recorded below.

The explicit orchestrator execution goal covers this reviewed source checkpoint,
durable results, local commits, task archival and installation handoff. It does
not change Release Radar Delivery Goals or owner acceptance. At that source checkpoint no push, PR, remote merge, installation, app/owner-state
mutation, repository binding, catalog acceptance, audit reconstruction, metadata
deletion or hooks were performed. The subsequently approved no-launch installation
is recorded below.

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

## Installed follow-through and C8 closure

After source closeout, the owner explicitly approved the documented no-launch
installation. On 2026-09-06 the exact candidate was prepared through the reviewed
sequence and installed with `script/build_and_run.sh install-staged-release-no-launch`
into `/Applications/ReleaseRadar.app`. The native installer returned success after
its signature/identity checks and verified promotion. The installed main binary
matches the approved candidate hash; version is 0.1.6, build 1.

The installed bundled documentation checker then passed against the canonical
repository with `.DS_Store` retained. No GUI launch occurred, and an exact process
check found the installed app executable was not running. The prior default staged
bundle remains at `build/product-architecture-plan-worktree/dist/ReleaseRadar.pre-C8-source-35e2ef6.app`.
This retained staging artifact is not an installed-app backup. The handoff worktree
tracks its default `dist/ReleaseRadar.app`, so the approved staging operation leaves
local binary changes and the retained prior-stage directory there. They were not
committed as source changes or reverted. Earlier temporary
build/test paths remain listed in the brief; no discretionary cleanup was performed.

The owner subsequently authorized launch, installed-reader/checker verification,
and supported read-only application readback. `/Applications/ReleaseRadar.app`
launched successfully; the exact installed executable was running and its Projects
window was inspected. The installed bundled documentation checker again passed
against the canonical root with actual `.DS_Store` retained.

The Codex connector's inventory call returned `appUnavailable` both immediately
and after startup. Using the installed app's supported
`Contents/Helpers/ReleaseRadarAgentTools` MCP stdio entrypoint for the same
`release_radar_inventory_evidence` query succeeded without a mutation. The app
reader returned catalog version 1, repository ID
`e7475429-ef51-4368-ad9e-61d9073d5a4f`, managed guidance v2 and a validated catalog
digest. It no longer rejected `.DS_Store`; the remaining catalog status was
`bindingMissing`, with zero project bindings and `isComplete: false`.

This establishes agreement between the installed app reader and installed checker
on the actual metadata-bearing repository. Combined with the reviewed source and
46 passing focused regressions, the bounded C8 metadata repair meets its acceptance
criteria and is closed. The app remains launched. No delivery-state mutation,
repository binding, catalog acceptance, audit reconstruction, reset or recovery
was performed. The original source execution goal remains complete.

Separate remaining problems are the missing project repository binding and the
Codex connector's `appUnavailable` result despite successful installed-helper
readback. Their cause/recovery is outside C8; no plugin/configuration repair was
attempted. Catalog edits remain unaccepted in application tracking. Neither C8
closure nor a valid catalog implies managed-current synchronization or acceptance
of broader C8 freshness work.

The [full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
retains all 40 capability rows and their accepted/proposed distinctions. Broader
C8 freshness, lifecycle/recovery, portability, future planning and I9 remain outside
this pilot. Do not start the next slice automatically. The
[Historical operating-baseline closeout](archive/2026-09-06-operating-baseline-closeout.md)
preserves earlier approvals and limitations; it does not control current status.
