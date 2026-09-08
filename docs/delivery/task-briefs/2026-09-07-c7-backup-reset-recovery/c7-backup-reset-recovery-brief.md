# C7 coordinated backup, reset and recovery

## Objective and complete outcome

Deliver full local backup and restoration, distinct preference and tracking-data reset
journeys, coordinated app-owned connection/service recovery, plugin-state reconciliation
and associated C12 recovery actions. Repository-only reconstruction stays explicitly
incomplete. A backup is not portable project import and cannot restore credentials or
device permissions merely by copying SQLite.

## Dependencies and controlling boundaries

Start from merged C6 `df7157bb377985f085903647c709c8c818d7efe9` plus this committed brief;
dispatch supplies the exact baseline. Follow C7/C12, D1/D3/D7/D8 and migration/recovery
sections of the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) and
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md).
Preserve C5/C6 historical identity, terminal notification facts and stale-action rejection;
never recreate grants or infer plugin absence from lost receipts. Full erasure is not the
selected lifecycle policy. Do not silently equate preference reset, tracking reset and
backup restore or invent authority from files.

A bounded read-only architecture consultation precedes implementation to identify current
connections, callbacks, configuration and supported plugin inspection, and settle a minimal
recovery sequence consistent with accepted policy. Record actionable refinement here
before the writer begins; surface only truly unresolved owner policy decisions. No new
workflow engine, second delivery database, notification service or plugin platform.

## Acceptance and material risks

- Explicit previews distinguish affected preferences, tracking records and full backup
  contents, retained history, permission requirements and recovery limits. Cancel is
  non-mutating; stale/invalid backup, unavailable folder and interrupted operations have
  actionable, recoverable errors. No UI silently performs a reset or restore.
- Full backup is a consistent app-owned snapshot of supported local store/history/audits/
  receipts, notification history and configuration. Version/compatibility/integrity and
  safe file placement are checked without secrets or inferred credentials. Repository
  documents remain repository-owned; backup is distinct from complete portable package.
- Quiesce admission, pending work and bridge callbacks, close every app-owned connection,
  perform supported app-owned replacement/reset, reopen/rebuild dependent services and
  provide authoritative recovery readback. Never unlink a live store or leave stale service
  references operating. Partial failure preserves a usable prior state or explicit recovery.
- Invalidate pre-recovery identities/generations and prepared owner actions. Restoring an
  older backup cannot resend already-sent or ambiguous notifications or revive removed
  authority silently. Retained historical facts/provenance stay truthful across recovery.
- Revalidate bookmarks and surface missing permissions. Inspect actual plugin state via
  supported read-only means, distinguish absent/modified/inconsistent/unavailable and do
  not reinstall/remove or change external configuration as a recovery side effect.
- Verify relaunch, multi-connection failure/recovery, complete supported snapshot contents,
  distinct reset effects, stale callbacks, notification nonreplay and other-project scope.
  Use existing native tests and synthetic app-owned data; directly exercise changed
  persistence/recovery boundaries, not compilation-only evidence.
- Inspect approved screenshots before UI work; verify native compact/wide, accessibility,
  cancellation, failure/retry and successful recovery readback. RDS appearance unchanged.

## Assignment, scope and endpoint

Consultation: fresh Astra High peer, read-only current-source recommendations to parent,
no subagents or owner-state inspection. Delivery: fresh Sol High task/worktree/named branch
from a committed baseline containing the refined brief; ceiling Astra High, no Ultra.
Writer owns necessary source/tests/brief/product docs/evidence; parent owns ledger/catalog/
indexes and one fresh independent combined architecture/security/recovery/QA reviewer.
Only Required findings block; repeat only affected checks/correction review.

Excluded: real owner backup/reset/restore, installation, cloud/companion implementation,
portable format/export/import, credential/config/security changes, real notifications,
unrelated fixture repair and direct SQLite tools. Product implementations and synthetic
recovery tests are authorized; actual destructive owner actions are not.

Endpoint is scoped commits, pushed branch and PR against `codex/release-radar-mvp`, direct
verification and required independent review/corrections. Separate owner approval for each
merge; prior C6 approval does not extend. Preserve canonical evidence and report precise
temporary/process inventory before bounded task retirement. The architecture handoff is
preparation, not a claim of delivered C7 runtime behavior.

## Current-source architecture handoff

The read-only C7 consultation at `3503793` found no unresolved owner policy decision.
One Sol High writer owns the complete coupled outcome, with sequential checkpoints
for backup/reopen, reset retention, and integrated Settings/health. These are verification
checkpoints, not permission to omit part of C7. The writer may choose simpler equivalent
engineering mechanisms while preserving the following acceptance boundaries.

- Preference reset restores existing four alert-rule defaults (blocked, completion-review
  and needs-review enabled; paused disabled) and ephemeral view state. Preserve project
  setup/exclusions, capabilities, plugin intent/receipts, history and Keychain. Tracking
  reset removes every live active/archived registration with C6 retained-history semantics,
  preserving existing/new removal records, read-only audits/history and global preferences/
  plugin receipts. It is not whole-database deletion. Full backup covers supported whole
  local store/configuration, not source repositories or portable document packages.
- `ReleaseRadarAppServices.shared` owns the UI store and notification/plugin services;
  `AgentBridgeApplicationHost.start` opens another store. Current stores close only at
  deinit, and XPC disconnection does not drain callback tasks/after-reply work. Establish
  explicit stop-admission, drain and close across app-owned connections, then publish a
  fresh service graph. Old store instances stay invalid. Recovery startup precedes normal
  open/migration/notification/plugin work, including crash relaunch; ordinary launch
  initialization can drain notifications and auto-update plugins and is not recovery resume.
- Use rollback-safe staging with exact source revalidation, bounded no-follow placement,
  SQLite-sidecar handling and minimal durable recovery/rollback state. Each destructive
  step has a recoverable prior state; do not unlink a live store. Existing `VACUUM INTO`
  can be an internal snapshot primitive, not arbitrary-SQLite import authorization or the
  complete backup format. Preserve recognized-schema and migration validation.
- Test a pre-recovery command absent from restored receipts, not only committed replay.
  Root-only envelopes currently resolve today's registration, so generation increment
  alone does not reject late external work. Carry expected identity/incarnation through
  applicable request and prepared-action boundaries; reject ambiguous legacy requests
  after recovery. Repeated restoration of the same old backup must not recreate a prior
  accepted authority tuple. Preserve domain IDs and historical source attribution.
- Never drain backed-up queues as fresh sends. Retain locally known sent/unknown terminal
  facts and relevant C6 notification identity across replacement; uncertain restored pending
  work is explicitly non-sendable. Prevent occurrence-counter rewind or observation refresh
  from manufacturing alerts. Preserve unknown external outcomes without querying/sending to
  Pushover. C6 retained rows alone lack fingerprint/provider-receipt/attempt detail and must
  not be treated as a complete nonreplay record.
- Preserve newer removal/audit facts when restoring older operational state. Preview names
  restored/displaced registrations; historical links never resolve by path/name. Exercise
  restore-before-removal then remove-again against the historical project/registration
  uniqueness constraint. Resolve fresh recovery incarnation and history linkage without
  rewriting historical IDs. An unreadable original stays recoverable; unavailable newer
  history is disclosed, not fabricated.
- Recovery plugin inspection must use read-only status through an already enabled helper,
  not the normal client path that may register/rebind/unregister. Report unavailable if
  that service is not enabled; no automatic updates. Missing receipts mean unverified
  management, not absent installation. Compare observed digest only with an actual known
  receipt/package; otherwise integrity stays unknown/inconsistent. C12 works even when the
  store cannot open, with check target/time and exact supported recovery actions.

Existing verification entry points: `StoreAcceptanceTests` and
`AgentBridgeTransportAcceptanceTests` for connection/drain/reopen;
`ProjectArchiveAcceptanceTests`/`ProjectRemovalAcceptanceTests` for reset retention;
`NotificationAcceptanceTests` suspended-send/relaunch cases for nonreplay;
plugin lifecycle acceptance/transport tests for receipt-loss and zero-mutation status;
`AppRouteTests`, `OnboardingAcceptanceTests` and `ProjectDocumentationRenderingTests`
for `AppModel.applicationHealth()`, Settings and bookmark recovery. Use synthetic
transports rather than enabling the owner's disabled launch agent to make tests pass.

## Writer source assessment and implementation refinement

The C7 writer confirmed the consultation against baseline `872fb3e`. The existing
`DeliveryStore` owns one `SQLiteConnection`, the application service graph owns a
second store through `AgentBridgeApplicationHost`, callback tasks outlive XPC
invalidation, and plugin `status()` can currently register or rebind its helper.
Implementation therefore uses these bounded additions rather than a new service layer:

- A versioned `.release-radar-backup` package contains a manifest and one app-created
  `VACUUM INTO` snapshot of the complete supported store. Alert rules, lifecycle
  receipts, audits and notification history remain in that store; Keychain,
  repositories, credentials and device permission grants remain explicitly excluded.
- One app-owned recovery coordinator uses adjacent no-follow staging, rollback and a
  minimal durable marker/journal. It validates the exact package bytes and recognized
  schema, closes every app-owned store, replaces the database and sidecars only after
  staging succeeds, carries unreadable-original preservation policy through the
  replacement-installed crash marker, and resolves interrupted replacement before normal
  app services start. A fresh graph is published after recovery; old stores and callbacks
  remain closed.
- Preference reset is a store transaction that restores the four existing alert-rule
  defaults and clears only ephemeral `AppModel` view state. Tracking reset prepares a
  replacement snapshot and applies `ProjectRemovalManager` semantics to every live
  active or archived registration before the coordinated replacement. Neither path
  deletes the database, credentials, plugin receipts or retained history.
- Restore rotates every live local registration, records a fresh recovery incarnation,
  rejects root-only legacy external requests after recovery, and requires the expected
  project/registration identity on subsequent external mutations. Restored queued work
  is suppressed and restored in-flight work becomes unknown; locally newer terminal
  notification facts, occurrence counters, removal records and historical audits are
  retained for every displaced registration, including projects absent from the backup,
  when the original is readable. An unreadable original can still be replaced with the
  preview naming unavailable newer-history reconciliation.
- Recovery plugin inspection uses a new read-only status entry point only when the
  lifecycle helper is already enabled. It performs no registration, rebinding,
  installation, removal, update or receipt mutation. Missing receipts produce unknown
  management rather than a claim that Codex has no installation.

Settings keeps the accepted tab and RDS structure: full backup/restore and preference
reset are presented in General, tracking reset remains project-data management, and the
existing application-health panel reports recovery target, check time, limitations and
the exact supported next action. Native confirmation and file panels provide cancel and
retry paths without adding another navigation or workflow subsystem.

The R7 correction grants the shipping app user-selected read/write access while retaining
the sandbox, application group and network-client entitlements. Backup creation uses a
single-selection, directories-only native picker for one existing folder; Release Radar
generates the package name inside that folder and keeps its adjacent staging directory
there. Preview and creation each hold only a balanced temporary security scope on the
selected folder, including the failure path. Restore remains read-only and unchanged.
The synthetic native-picker host uses its PID-isolated temporary store and returns before
shared application services on both launch and termination.
