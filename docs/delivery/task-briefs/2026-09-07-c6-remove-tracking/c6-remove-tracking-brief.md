# C6 remove tracking with retained history

## Objective and outcome

Deliver complete remove-from-tracking and associated C12 recovery behavior. Remove the
operational project graph and local capabilities atomically while retaining attributable,
read-only audit/activity history and an explicit removal record. Every repository file
and every other project remains untouched. Full erasure is not selected.

## Scope, dependencies and accepted boundaries

Begin from merged C5 `c8cba4b223eeeba2f5a0b03d1f649fe5bc51eff9` plus this committed
brief; dispatch supplies the exact baseline containing the operating documents.
Follow C6/C12 and D1/D3/D7 in the
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md) and
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md).
Inspect current store relationships, admission, notifications, history projections,
roots and UI before selecting the narrow migration. Persist any controlling refinement
here before implementation. Schema/layout and callback coordination are engineering
choices within the accepted retention policy, not a new owner policy decision.

Retained events must identify the historical project and registration independently
of live foreign keys. Preserve event-time facts and provenance; unknown facts remain
unknown. Re-add creates fresh identity/registration and never resurrects old graph,
bookmarks, bindings, requests or monitoring. History links must not match a replacement
by path/name. C5 archive remains reversible and distinct from removal. C7 backup/restore,
future History/search, portable continuity and read-only companion consumers must be
able to retain these historical records without treating them as operational authority.
Do not implement those future capabilities here.

Exclude full erasure, reset/backup, export/import format work, external execution
cancellation, companion/cloud/plugin work, unrelated navigation and shared RDS changes.
No repository file deletion or relocation is part of removal. No real owner-data removal,
installation or external notifications are authorized; use synthetic app-owned stores.

## Controlling implementation refinement

Schema v17 will separate retained history from live authority. A removal record owns the
historical project ID, project name, original lifecycle, registration ID/generation,
removal time and preview counts without a foreign key to `projects`. Existing scoped
audits gain historical project/registration identity that survives the live foreign key;
non-audit activity and complete Delivery Goal assignment events are copied into retained
history tables whose only parent is the removal record. Event occurrence, observation and
recording timestamps remain distinct nullable facts, so the migration does not invent a
missing time, actor, lane or provenance.

New durable command receipts carry the exact project/registration/generation that created
them. A replay is valid only for that same registration; legacy unscoped receipts are not
retargeted or backfilled. Removal updates queued notification outcomes to suppressed and
in-flight outcomes to unknown before retaining them, then invalidates occurrences and
deletes the live notification rows so relaunch cannot replay them.

One store-owned transaction creates the removal record and retained snapshots, authorizes
the exact project for the otherwise-protected task-history deletes, removes dependent plan
and task rows in foreign-key order, deletes the live project row and capabilities, clears
the transient authorization, and records the owner audit against historical identity. Any
failure rolls back all of those changes. The existing archive lifecycle remains unchanged.
Projects adds a separate Removed scope and read-only removed-project detail/history route;
active and archived detail expose the exact-project removal preview, while removed detail
offers neither operational controls nor restore. A stale route resolves to the matching
removed registration when present and otherwise returns to Projects.

## Acceptance and material risks

- Accessible exact-project preview names what is removed and what history/files remain.
  Cancel/Escape changes nothing; stale preview, already removed, missing access and store
  failures have recoverable messages. Removal works for active/archived and zero-phase
  projects without requiring a valid catalog or folder access.
- One app-owned transaction invalidates operational admission and late work, removes the
  operational graph and root/bookmark capabilities, and preserves attributable history
  and removal record. Audits, assignment/activity history and notification outcomes must
  survive without live-row foreign keys or blanket weakening of audit protection.
- Receipt/retry behavior is deterministic and correctly scoped to removed registration.
  Failed writes roll back all changes. Concurrent or pre-resolved requests, documentation
  mutations and app-owned callbacks cannot apply after removal or target a re-added project.
- Monitoring and pending notifications stop being eligible. Sent/unknown outcomes stay
  truthful and old work never replays. Do not claim external execution was cancelled.
- Removed records are discoverable as read-only retained history/removal information.
  Active/archived counts and stale routes recover honestly; operational controls and
  restore are unavailable for removed registrations. Re-add remains an explicit new
  onboarding journey, never a hidden restoration or implicit grant.
- Reopen/relaunch preserves retained history and removal state. Other projects and exact
  synthetic repository contents remain unchanged. Preserve legacy IDs in retained history;
  do not rewrite existing IDs or fabricate actor attribution.

## Verification and review

Use test-first repository-native migration/service/transaction tests for complete graph
removal, retained history, fault rollback, receipt replay, stale generations/callbacks,
re-add isolation, notification suppression/ambiguity, unavailable catalog/access and
restart. Exercise directly affected historical migrations and schema recognition;
update only fixtures changed by C6. No custom harness or unrelated fixture repair.

Inspect approved settings/board screenshots and C5 lifecycle evidence before UI design.
Verify native compact/wide, AX/keyboard, cancellation, failure, history readback and
re-add separation with synthetic data. Disclose XCTest permission limitations. One
fresh independent combined Astra High reviewer covers persistence/authority/recovery
and UI/QA, including future historical identity boundaries. Only Required findings
block; corrections repeat only affected checks/review. No recursive review.

## Assignment and endpoint

Fresh delivery task, sole writer of a dedicated worktree and named
`codex/c6-remove-tracking` branch/upstream. Explicit Sol High for retention/migration
and stale-authority risks, ceiling Astra High; Ultra prohibited. Confirm actual revision,
worktree/upstream and runtime settings only where exposed. Own necessary source/tests,
this brief and affected product docs/evidence. Orchestrator owns progress/catalog/index;
report new artifact metadata requirements before touching shared files.

Deliver scoped verified commits, pushed branch and PR against `codex/release-radar-mvp`.
Independent review and required corrections precede completion. PR merge needs separate
owner approval; C5 merge approval does not authorize C6 merge. No installation, real
owner-data operation, notifications, managed app catalog acceptance or other reserved
mutation. Report exact candidate, behavior, checks/limits and temporary/process inventory;
parent preserves results and promptly archives completed bounded tasks.
