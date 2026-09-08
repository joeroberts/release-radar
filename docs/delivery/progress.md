# Release Radar delivery state

## Current outcome and active task

**Phase 4 source delivery is complete.** The owner approved
[PR #36](https://github.com/joeroberts/release-radar/pull/36), merged on 2026-09-08
at `356e13400043f25724d79c95be381e8582c68980`.

RM2/P7/P8 and issue #9 now provide one session Back/Forward history, exact viewed
phase/filter/selection/focus and registration recovery, project-wide Dependencies
focused on the ticket with phase labels, and accessible compact Ticket Details.
Relaunch starts at Projects with empty history. Persisted active phase, task counts,
completion and acceptance semantics remain separate and unchanged. RDS is consumed
as supplied; no appearance or shared-library work was included.

The [completed brief](task-briefs/2026-09-08-phase4-navigation/phase4-navigation-brief.md)
records the delivered scope. The [verification record](evidence/2026-09-08-phase4-navigation.md)
contains candidate-specific 35-test/native interaction evidence, the 24-test
correction run and final 17-test navigation run, all passing without failures/skips
on arm64 macOS 26.5.2. Independent review closed all Required findings. Delivery and
review tasks are stopped and archived; no isolated test/build processes remain.

The [full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md)
contains the already-authorized Phase 5 decision preparation and handoff.
**Phase 5 implementation remains unopened.** Its proposed decisions and the shared
execution assessment are not new implementation authorization or a prerequisite.
No further Phase 4 product work is active; this closeout reconciles repository
status and artifact lifecycle with the approved merge.

## Current authorization and ownership

Orchestrator `01a08261-fa9d-7dc1-854f-b2a3b739c3a8` owns this ledger and catalog
integration in fresh worktree `bfc2`, branch `codex/phase4-orchestrator`, established
from the current merged default at `6f528c5`. The canonical checkout and retained
builds remain untouched. Requested orchestrator profile is Astra Medium.
Chief architect
`01a08262-ffdf-7120-896b-0252ce2f8a30` completed its read-only assessment; findings
are preserved in the plan and no processes remain. The bounded task is archived.

The owner authorizes affected source/tests/docs, scoped commits, pushes, PRs and
fresh bounded delivery and independent-review peer tasks. Each merge requires
separate owner approval. Use one implementation stream. Chief architecture is
requested at Astra High; ordinary implementation starts Terra Medium; independent
review covers the actual navigation, UX and boundary risks. Default escalation
ceiling is Astra High; no unapproved xhigh/max and never Ultra. Actual runtime
settings are not exposed for independent confirmation.

No installation, real owner-data operation, SQLite edit, application binding or
catalog acceptance, credential change, notification, plugin/cloud mutation,
entitlement change, publication or cleanup is authorized. Repository documentation
work does not imply application synchronization. Inspect side-effecting scripts
before use; use proven isolated synthetic execution and never normal app launch
or owner credentials merely to arrange testing.

Independent Phase 5 decision-preparation peer `01a08269-0c66-7d61-bd3d-f9963383471e`
(requested Astra High) completed read-only preparation; its proposed decisions and
bounded handoff are preserved in the roadmap. No processes remain; the bounded task is archived.
It did not implement or select product choices. Owner questions and merge approvals are relayed through the
visible parent task while this task is omitted from the owner's task list.

Repository documentation check passed after the accepted contract, brief and
proposed Phase 5 handoff updates. New catalog metadata remains unaccepted in the
application; no application readback/acceptance is authorized. Independent combined
Phase 4 review and required-correction rechecks passed.

## Verification and sequencing

The Mac is available for builds, automated tests and isolated native UI/keyboard/
accessibility inspection. Only the owner's hands-on acceptance testing on other
Macs is unavailable until at least Friday, September 11, 2026. Perform independent
source and native checks now; report any specifically owner-dependent acceptance
as pending without making it a prerequisite for source delivery.

The next eligible work is owner selection of unresolved Phase 5 readiness
decisions, followed by a separately authorized bounded assignment. Preparation covers
P1–P4/P15/P16/P18 and D4/D5/D6/D12, preserving current phase-owned Delivery Goals
and separate execution-goal semantics unless the owner selects a documented change.
Present only unresolved consequential decisions in small phone-friendly batches.

The private versioned test DMG and other-Mac testing wait until Friday or later.
Packaging remains unstarted; target architectures and macOS versions are unknown.
Private testing is the requested packaging scope, with no packaging, notarization
or distribution work authorized by this continuation.

Completed source-delivery evidence remains in the
[Historical Phase 3 record](archive/2026-09-08-phase3-delivery-history.md),
[3A verification](evidence/2026-09-07-phase3a-documentation-freshness.md) and
[3B verification](evidence/2026-09-08-phase3b-evidence-preview.md).
Those results cover their stated candidates and scenarios, not a whole-suite
pass or installed-owner acceptance of a future Phase 4 binary.

## Material limitations and retained history

The last authorized canonical application inventory reported `bindingMissing`
and `isComplete:false` for `project-fffdc0e0b15b9b86`. No new application readback
or catalog acceptance is authorized. Repository documentation validation does not
claim application synchronization or repair that binding.

Earlier C7 launch/credential incidents remain unresolved as to owner-state effects:
a normal app launch may have initialized default services, and a test-runner help
command exposed Jira/Pushover credentials in a writer transcript. The owner was
informed; no secret values are recorded here and no repair or rotation was performed.
See [C7 evidence](evidence/2026-09-07-c7-backup-reset-recovery.md).
During the initial Phase 3A review, a reviewer initiated an unauthorized prompt-only
external security scan/preflight; external calls stopped, with no further mutation
or cancellation performed. Subsequent correction reviews remained local.

Some historical Phase 3A raw bundles disappeared with earlier worktree archival;
committed evidence and screenshots remain. Final Phase 3B raw results are cited
under `/tmp/release-radar-phase3b-*`; temporary builds, exports and synthetic
fixtures were retained, with no cleanup. Their deletion requires exact owner
authorization. Canonical checkout and unrelated files remain preserved.

[Historical Phase 3 record](archive/2026-09-08-phase3-delivery-history.md) and
[Historical C7 record](archive/2026-09-07-c7-delivery-history.md) retain closed coordination,
prior checks and temporary-output reports.
