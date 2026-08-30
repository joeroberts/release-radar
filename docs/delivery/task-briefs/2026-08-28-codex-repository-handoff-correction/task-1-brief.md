# Product Task 2 correction: Codex repository handoff

**Status:** Implementation and live acceptance active. This is the single
owner-approved Product Task 2 acceptance correction, amended after the
installed `0.1.2` live handoff
exposed a self-referential prompt, an ambiguous project status, a non-semantic
`upsert_phase` audit, and refresh ordering that left the UI stale.

## Objective and user-visible outcome

The onboarding UI tells the owner to paste its prompt into a Codex task already
rooted at the selected repository. The copied prompt operates in that task and
explicitly invokes the installed `$release-radar:release-radar` skill; it never
creates or delegates to another task.
For an owner-authorized initialization, update, or repair, Codex manages one
exact versioned Release Radar block in the repository-root `AGENTS.md` while
preserving every unrelated instruction, and creates `docs/delivery/progress.md`
only when absent without inferring delivery state. Release Radar read-only
inspects the root instruction file through the existing project bookmark and
reports statuses explicitly scoped to **Release Radar guidance**. For a
guidance-only handoff, Codex writes and reads back the permitted repository
files first, then records the existing `AGENTS.md` as ticketless evidence with
`release_radar_add_evidence`. Completion requires final repository-file
readback plus that successful audited MCP result.
Settings labels a missing attachment **Codex desktop observation unavailable**;
it does not call Codex unavailable merely because no desktop observer attaches.

## Controlling references and release gate

- `docs/delivery/progress.md` — reopened Product Task 2 gate
- `docs/design/release-radar-codex-plugin-lifecycle-design.md`
- `docs/design/agent-driven-delivery-dashboard-design.md` (Onboarding)
- `docs/architecture/ADR-001-release-radar-boundaries.md`
- `docs/architecture/ADR-002-codex-plugin-lifecycle.md`
- `docs/superpowers/plans/2026-08-27-codex-plugin-lifecycle.md` (Task 3)

This correction retains all accepted lifecycle-helper, signing, package,
exact-entry migration, typed-MCP runtime, and `default.profraw` evidence. It is
one local, single-user slice and has no independent implementation dependency
beyond the fresh review/release gate above.

## Scope and authority

The correction may modify only the existing plugin/lifecycle and onboarding
surfaces needed for this behavior:

- `ReleaseRadar.xcodeproj/project.pbxproj` — both `ReleaseRadar`
  `MARKETING_VERSION` values change from `0.1.2` to `0.1.3`
- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json`
  — plugin manifest version changes from `0.1.2` to `0.1.3`
- `ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md`
- `ReleaseRadarCore/Onboarding/ProjectGuidanceInspection.swift`
- `ReleaseRadarCore/Onboarding/ProjectOnboarding.swift`
- `ReleaseRadar/App/AppModel.swift`
- `ReleaseRadar/Projects/OnboardingView.swift` (`CodexPromptHandoff.prompt`)
- `ReleaseRadar/Projects/ProjectOverviewView.swift`
- `ReleaseRadar/Navigation/SidebarView.swift`
- `ReleaseRadar/Shared/FailureStateView.swift`
- `ReleaseRadarTests/ProjectGuidanceAcceptanceTests.swift`
- `ReleaseRadarTests/OnboardingAcceptanceTests.swift`
- `ReleaseRadarTests/FailureStatePresentationTests.swift`
- `ReleaseRadarTests/CodexPluginLifecycleAcceptanceTests.swift`
  — add only the focused bundled-skill semantic assertions required below and
  update `testBundledPackageMatchesAppVersionAndCanonicalDigest` only for its
  established bundled package version/digest expectation
- `ReleaseRadarTests/AppRouteTests.swift`
  (`testPluginLaunchUpdateRunsOnceAndSuppressedLaunchNeverCallsHelper`) — prove
  the existing clean managed `0.1.2` to shipped `0.1.3` automatic-update path

The `0.1.3` app and plugin manifest bump is required because same-version clean
managed installation will not update its skill. After the signed app is
installed, use only the existing clean-managed automatic update at launch or
the existing explicit Update action to install the managed plugin. Do not add a
same-version overwrite, updater, XPC operation, CLI/configuration path, or
other installation mechanism.

Codex, under normal owner authorization, writes documentation in the observed
repository. The app and lifecycle helper do not write repository files. The app
may only read the root `AGENTS.md` through the existing security-scoped project
bookmark and store its in-memory classification for presentation. Release Radar
remains the only SQLite writer and accepts only its existing typed MCP
mutations. Repository verification is Codex's direct file readback; the MCP
result supplies mutation/audit evidence. No MCP repository-read operation is
created, assumed, or emulated.

For a guidance-only initialization, update, or repair, Codex validates the
managed markers, writes only the permitted repository files, and directly reads
them back before calling MCP. When `docs/delivery/progress.md` is absent, Codex
creates it with a minimal Release Radar handoff section that records guidance
version `1` and a pending audit without inferring delivery state. Codex then
uses only `release_radar_add_evidence`, with no ticket ID, a fresh evidence ID,
the repository-root `AGENTS.md` path, and one UUID `requestID`. It never uses
`upsert_phase` or another delivery-state mutation merely to obtain an audit.
After success, Codex replaces only the pending audit value in a ledger created
by this handoff with the returned audit-event ID and performs final readback.
If no repository change is required, it does not manufacture a mutation.
Before either write, Codex uses a no-follow filesystem check and refuses a
symlink or non-regular `AGENTS.md` or `docs/delivery/progress.md` path; the app's
read-only guidance inspection likewise classifies a symlink or non-regular root
`AGENTS.md` as unavailable.

When the app is closed or has no callback, `appUnavailable` leaves the already
written repository guidance durable and the Release Radar audit pending. Codex
tells the owner to open Release Radar and retries the same evidence request;
`outcomeUnknown` likewise replays the complete original request verbatim—not
only its UUID—including root, reason, attribution, collision-resistant evidence
ID, path, command, and the exact same `requestID`, relying on the existing
idempotent request receipt. A successful audit followed by a
failure to update or read back the newly created ledger is a reported
repository discrepancy repaired without a second distinct mutation. The
existing post-mutation dashboard reload observes the already-written guidance.

Out of scope: any new MCP operation or schema; direct SQLite/Codex-config access;
app or helper repository-write authority; a live observer transport; HTTP,
polling, sync/reconciliation, watchers, or generalized initialization
framework; a new route/mockup; multi-user behavior; and changes to accepted
lifecycle, signing, migration, bridge, or delivery behavior.

## Test-first implementation and verification

1. Write focused RED tests before implementation:
   - `OnboardingAcceptanceTests` requires the copied prompt to operate in the
     current rooted task, never request or delegate another task, and explicitly
     invoke the installed `$release-radar:release-radar` skill;
   - the package-skill test requires explicit owner-requested preservation of
     every unrelated repository instruction; exact byte-for-byte agreement
     between the versioned block the app recognizes and the block the skill
     installs; safe create, append, bounded replacement, and malformed-marker
     refusal behavior; `docs/delivery/progress.md` creation only when absent;
     direct repository readback; use of
     the exact ticketless `release_radar_add_evidence` mutation for the written
     `AGENTS.md`, successful audit-result pairing, and discrepancy reporting—not
     `upsert_phase` or an invented MCP API;
   - the same package-skill assertion requires repository write/readback before
     the evidence mutation, a truthful pending handoff ledger only when absent,
     repo-ahead `appUnavailable` recovery, exact-UUID `outcomeUnknown` replay
     of the complete original evidence request through the existing idempotent
     request receipt, no-follow refusal for symlink/non-regular target paths,
     and ledger repair with no second mutation;
   - `FailureStatePresentationTests` requires unavailable observation copy to
     say **Codex desktop observation unavailable** and rejects **Codex
     unavailable** for that state.
   - `ProjectGuidanceAcceptanceTests` requires read-only classification of
     missing, current, outdated, malformed, and unavailable project guidance
     without changing repository bytes;
   - `testBundledPackageMatchesAppVersionAndCanonicalDigest` requires the
     `0.1.3` manifest/app-version match and its recomputed digest; the existing
     AppRoute launch-update test requires a clean managed `0.1.2` receipt to
     reach verified `0.1.3` through the existing update operation.
2. Run the four focused test targets and record the expected RED failure.
3. Implement only the copied prompt, installed skill instructions, read-only
   guidance inspector, existing onboarding/project overview presentation, and
   shared observation presentation necessary for GREEN. The skill preserves
   existing repository instructions and manages only its exact marked block; it
   creates neither replacement instructions nor inferred delivery state. A
   failed file postcondition, failed mutation,
   missing audit result, or mismatch reports a discrepancy and never success.
   It writes and reads back repository guidance before the exact ticketless
   evidence mutation; `appUnavailable` leaves a truthful repo-ahead pending
   state, `outcomeUnknown` reuses the complete original request verbatim, and an
   after-audit ledger failure repairs only that newly created ledger. The app
   and skill fail closed before writes when the target instruction or ledger
   path is a symlink or non-regular file.
   Change both ReleaseRadar `MARKETING_VERSION` values and the plugin manifest
   together to `0.1.3`, then update only the established package-digest
   expectation; do not change lifecycle semantics or unrelated test fixtures.
4. Re-run the focused suites GREEN with fresh temporary DerivedData. Run the
   established package inventory/digest and clean-managed update acceptance
   tests, a signed build/package validation, and `git diff --check`.
5. Build and install signed `0.1.3`. Beginning with clean managed `0.1.2`, use
   the existing clean-managed automatic update at launch or the existing Update
   action and verify the `0.1.3` version/digest postcondition. In an
   owner-authorized repository, use one Codex task already rooted there, copy
the app prompt, explicitly invoke the installed skill, and request
initialization. Verify it validates, writes, and reads back the applicable
guidance and `docs/delivery/progress.md`, then receives the successful audited ticketless
evidence mutation and reaches the scoped **Release Radar guidance current · v1**
state through the existing refresh. Verify `appUnavailable` preserves the
repository files with audit pending and asks the owner to open the app; verify
`outcomeUnknown` replays the complete original request with the same UUID
`requestID`; verify an after-audit ledger failure is repaired without a distinct
mutation. Confirm Settings says unavailable
desktop observation. This is a one-shot acceptance proof, not a polling or
synchronization mechanism.

## Acceptance criteria

- The copied prompt operates in the current task rooted at the owner-selected
  repository, explicitly invokes `$release-radar:release-radar`, and never asks
  that task to create or delegate another task.
- For explicit owner-authorized initialization, update, or repair, every
  unrelated repository instruction is preserved and only the exact versioned
  Release Radar managed block plus an absent `docs/delivery/progress.md` may be
  created or changed in the observed repository.
- Release Radar read-only classifies each onboarded repository's root guidance
  through statuses explicitly scoped to **Release Radar guidance** as missing,
  current, update available, needs repair, or unavailable through
  the existing project bookmark. The app exposes a copied owner-action prompt
  but never writes the instruction file.
- Repository readback and a successful audited result from each corresponding
  existing typed MCP mutation are both required before a synchronization claim.
- Guidance is written and read back before a ticketless `add_evidence` mutation
  records the actual `AGENTS.md`; `upsert_phase` is never used for this handoff.
  An absent ledger receives only the handoff version and pending-audit state,
  followed by the returned audit ID. `appUnavailable` preserves that repo-ahead
  state; `outcomeUnknown` replays the exact UUID `requestID`; ledger repair
  requires no second mutation. Every replay preserves the complete request
  body, and symlink/non-regular instruction or ledger targets fail closed
  before writing.
- Missing/failed/unaudited/mismatched conditions produce a clear discrepancy;
  no MCP read API, app repository writer, or generalized reconciler exists.
- Unavailable observation copy is observation-specific and does not imply
  Codex itself is unavailable.
- The signed app and plugin manifest are both `0.1.3`; their established
  package-digest expectation is updated, and clean managed `0.1.2` reaches
  verified `0.1.3` only through the existing automatic-update or Update path.
- Existing accepted lifecycle/signing/migration/MCP evidence and unrelated
  working-tree changes remain untouched.

## Required independent reviews and ledger evidence

A fresh Implementer completes the slice. Fresh independent Code Review, QA/Test,
Architecture, Security/Privacy, TPM, and Delivery Management review it; the
Implementer cannot perform those roles. After acceptance, Delivery Management
records focused RED/GREEN command results, package/signing validation, current
already-rooted task repository-readback plus audited-MCP proof, Settings copy evidence, scope
confirmation, role decisions, residual risks, and next eligible work in
`docs/delivery/progress.md`. Do not update that ledger during planning.

## 2026-08-29 live-acceptance amendment

The installed `0.1.3` app falsely reported Rekon Pursuit as **Release Radar
guidance current · v1** because it treated the exact managed block as sufficient
proof. That block came from the rejected `0.1.2` flow, whose `upsert_phase`
mutation did not record the file through ticketless evidence. The same
file-only check hid the repair prompt, while the `0.1.3` skill's no-change rule
prevented the missing audit from being repaired.

This required correction is bounded to the existing evidence contract:

- an audited handoff evidence ID is `release-radar-handoff:v1:<UUID>`, ticketless,
  available, and scoped to the exact root `AGENTS.md`;
- current status requires both that record and the exact v1 managed block;
- an exact block without that record is **Release Radar guidance handoff
  incomplete · v1** and exposes **Copy repair prompt**;
- that state-specific prompt authorizes the skill to read back the already-
  matching file and send the existing ticketless `add_evidence` mutation
  without changing delivery state or rewriting repository files;
- the existing post-mutation dashboard refresh observes the new evidence row
  and immediately reports current.

The coordinated app/plugin target is `0.1.4`, updated from clean managed
`0.1.3` through the existing lifecycle. This amendment supersedes earlier
version-specific `0.1.3` acceptance lines. It adds no schema, MCP operation,
repository writer, watcher, polling, or reconciliation machinery.

## 2026-08-29 exact-root amendment

The first handoff attempted after `0.1.4` acceptance exposed one remaining
onboarding defect. Release Radar had authorized
`/Users/jroberts/Documents/UILib/RekonDesignSystem`, but the copied prompt did
not name that path. Codex therefore ran at the unauthorized parent
`/Users/jroberts/Documents/UILib`, wrote the two permitted repository files
there, and only then received `unauthorizedProjectRoot` from the typed bridge.
The bridge rejection was correct; the prompt and skill write precondition were
not.

This final correction is bounded to exact root binding:

- Project Overview shows the exact canonical Release Radar-authorized root next
  to the setup, update, or repair action.
- Every copied setup, update, or repair prompt embeds that exact root.
- Before any repository write or Release Radar mutation, the installed skill
  canonicalizes the prompt's stated root and the current Codex task root and
  requires an exact match. A missing root, parent, child, or different root is
  reported and stops without a file write or MCP call.
- The signed app and plugin manifest advance together from `0.1.4` to `0.1.5`.
- The signed local installer stops the running Release Radar app, bridge, and
  lifecycle helper before replacing the bundle so an older helper cannot
  survive the update and compare the new package against stale in-memory
  metadata.

Acceptance requires focused prompt/model/package regression tests, installed
`0.1.5` package and Settings proof, exact-root UI and clipboard proof, and one
owner-started Codex task rooted exactly at RekonDesignSystem that completes the
audited handoff and immediately changes the running UI to **Release Radar
guidance current · v1**. The mistakenly created parent-directory files remain
outside this task and are not modified here.
