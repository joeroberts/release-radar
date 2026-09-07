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
