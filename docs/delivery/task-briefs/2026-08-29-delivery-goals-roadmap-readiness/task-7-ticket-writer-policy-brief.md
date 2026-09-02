# RR-R10 Task 7: Ticket writer and planning policy composition

## Objective and outcome

Deliver current [Task 7](../../plans/2026-08-29-delivery-goals-roadmap-readiness.md#task-7-route-every-ticket-writer-and-compose-planning-policy): every shipping and debug phase/ticket writer uses the store-owned DeliveryPlanningPolicy. Preserve the [ADR-004 contract](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md), [ticket-task gate](../../../architecture/ADR-005-ticket-task-work-plans.md), and [proportional review policy](../../../architecture/ADR-007-proportional-delivery-validation.md).

The coordinator accepted this canonical brief and initial sequencing on 2026-09-02 under owner delegation before implementation. This is delegated acceptance, not personal human inspection.

## Scope and exclusions

Add policy-owned upsertPhase, upsertTicket, transitionTicket and assertCanRecordReviewOrCompletion. Route dispatcher, Rekon importer, DashboardSampleData and RR9 capture writers through them. Keep caller-owned transactions/audits/receipts and existing notification behavior. Update focused tests and only required documentation/catalog/index metadata. Only the accepted one-table forward v14 schema correction below is included; no model changes, Task 8 commands, exporter/exportability helper/error, archive v2, UI redesign, owner install/bootstrap, live catalog acceptance, shared-service mutation or Task 7A work.

## Dependencies

Task 6 PR #7 merged into codex/release-radar-mvp at 2026-09-02T11:57:19Z, commit 16c81a318672ad1e66c14a75e943992441768234. This isolated branch codex/rr-r10-task-7 starts there. The existing v11 policy/model, v12 exact task acceptance gate and v13 managed documentation transaction remain controlling. Preserve the old/dirty bound checkout and live app/plugin 0.1.6 baseline. Coordinator 01a06184-6387-7c42-878e-695db0481a18 has owner-delegated routine brief/sequencing and delivery approval authority.

## Material risks

Readiness, exact UTF-8 identity, assignment/actionability, dependency/blocker and task-revision gates must compose in one transaction. A rejected write must preserve lane, goal, plan, assignment history, receipt, audit and notification state. Moving Backlog work revises both plans exactly once and removes the old assignment. Migration continuation cannot be manufactured or regained. Import authorization, security-scoped bookmark access, bound-root/accepted-catalog validation and managed artifact identity must precede delivery writes and remain atomic; legacy evidence semantics remain intact.

## Test strategy

Use test-first focused native XCTest cases with inert hosts and synthetic stores. Cover policy/dispatcher operation rows and rollback, importer source-lane reconciliation, managed-import authorization/identity regressions, onboarding and sample/capture. Select safe individual tests for any transport/lifecycle class; never run those whole classes. Build-for-testing and run relevant selectors, native DocumentationTool write/check, and git diff --check. Existing unrelated successful Task 6 checks stay terminal unless the changed boundary affects them. Temporary build/test/PR output stays in .build/rr-r10-task7 and synthetic fixture directories, retained without cleanup. No live inventory/state mutation is implicit verification.

## Acceptance criteria

- Governed phase creation has a Draft plan; newly imported phases remain Legacy unassessed as real ticket changes advance their revisions, until an explicit plan revision. Import or replay never resets existing Draft/Ready plans to Legacy; real structural changes invalidate Ready. Phase rename preserves structural readiness. New tickets are Backlog-only and advance their plan revision. Changed outcomes invalidate structurally; same-value upsert does not. Only Backlog moves phases, remains Backlog, removes assignment and revises both plans once.
- Exercise every ticket operation row: Backlog cannot skip start; starting/resuming requires current Ready, exact actionable assignment, no unresolved blocker and Accepted ticket/phase prerequisites. First work activates Planned goals; explicit rework starts reactivate Awaiting acceptance. Ordinary progress preserves revisions. Post-v11 continuing work still requires assignment/actionability when its plan becomes Draft.
- Only migration-granted In-progress/Needs-review continuation may complete unassigned. Returning to Backlog permanently clears it; Blocked cannot use it to resume. Work under terminal goals rejects. Accepted tickets remain immutable; every Accepted upsert create/update rejects. Accepted transitions retain the exact ticket-task revision check in the same transaction. Task-only mutation never invalidates a phase plan.
- Ticket-scoped completion/review rejects unstarted Backlog; blocker, dependency, evidence and thread operations retain their existing nonstructural behavior. Rejections and audit failure roll back all affected state; replay returns the original result without duplication.
- Import creates only Backlog tickets, no continuation or task plans, with a stable review fact for each non-Backlog source lane. Existing authorized transaction and bookmark/binding/catalog checks, managed IDs and legacy evidence are preserved. Sample/capture paths establish real valid plans before governed transitions; setup-only test SQL remains test-only.
- Focused direct checks and independent Code/QA, Architecture and Security/Privacy review pass with no Required finding. Commit, push, create and merge the Task 7 PR into codex/release-radar-mvp; report actual result to the coordinator and stop before Task 7A.

## Risk-triggered reviews

The coordinator reviews brief/sequencing under owner delegation. One qualified independent reviewer may cover Code/QA, Architecture, Security/Privacy and documentation, with specific attention to writer and import transaction boundaries. No review of reviews. Development catalog changes remain repository-prepared and pending separate bound-root deployment/acceptance; preserve Task 5 physical-keyboard/spoken-VoiceOver and native macOS Dynamic Type limits. No personal human inspection or managed-current synchronization is claimed.

## Accepted bounded amendment: preserve assignment history across phase moves

The coordinator accepted this bounded amendment on 2026-09-02 under owner delegation and released repository-only implementation, synthetic validation, independent review and Task 7 delivery. No live migration or installation is authorized.

The synthetic `testGovernedBacklogPhaseMovePreservesAssignmentHistory` reproduces SQLite foreign-key error 787 after a Backlog ticket is assigned, finalized, and explicitly unassigned. Its current assignment is gone, but both historical assignment/removal rows remain. Updating the ticket's phase rejects because the v11 event table references `(project_id, phase_id, ticket_id)` against the mutable ticket phase. This prevents a required Task 7 operation. The test host remained inert and used only a synthetic store.

Minimum correction: add forward schema v14, leaving historical v11/v12/v13 migration definitions and frozen fixtures unchanged. Rebuild only `delivery_goal_assignment_events` inside the existing exclusive migration transaction. Retain every column and row exactly (including audit ID, original phase, ticket ID, previous/current goal IDs, revision and action), the `(audit_event_id, ticket_id)` primary key, the unique `(project_id, phase_id, ticket_id, revision)` index, action/revision checks, deferred audit foreign key, and historical phase/goal foreign keys. Change only the event-to-ticket foreign key to `(project_id, ticket_id) REFERENCES tickets(project_id, id)` with existing NO ACTION behavior. Current assignments keep their stricter phase-local foreign key. No foreign-key disabling, history rewriting/deletion, ticket duplication, table-column/model change, or owner operation is permitted.

Follow the existing v13 rebuild convention: rename the old event table to a migration-local name, create the corrected event table, copy its explicit columns, drop the old table only after the copy, and recreate the existing named unique index. Rollback restores the entire original schema and rows on any failure; `user_version` advances only after native manifest/foreign-key validation succeeds. The existing DeliveryStore pre-migration snapshot and unavailable/recovery behavior remain the recovery mechanism. No custom backup framework is introduced.

Additional affected files are `ReleaseRadarCore/Store/StoreMigrations.swift`, `ReleaseRadarTests/StoreAcceptanceTests.swift`, and `ReleaseRadarTests/DocumentationPreflightTests.swift`, plus this brief/progress/catalog/index metadata. Version-sensitive table and foreign-key manifest checks select the historical event shape for versions 11–13 and the corrected shape for v14. Existing version-sensitive test expectations/fixtures are adjusted only where the current version changes; immutable fixture files and their manifests remain untouched. No application/protocol API changes are needed.

Direct tests cover: populated v13 to v14 migration with exact historical events, plans, goals, task rows, managed bindings/evidence, delivery/audit/receipt/notification data preserved; required assigned and previously-unassigned Backlog moves with original history still readable and new source-phase unassignment history; unchanged index/check/deferred-audit and cross-project/goal/phase constraints; foreign_key_check; reopened v14 idempotence; unchanged accepted v11/v12 fixture migration; and an injected late index-creation collision proving original v13 schema/data/user_version and pre-migration snapshot survive, followed by disposable-copy recovery. Documentation preflight recognizes genuine v13 without writing and genuine v14, rejects malformed/unsupported schemas, and preserves managed import authorization/identity checks.

Compatibility: the installed 0.1.6 app remains schema v13 and is not touched. The development candidate will produce v14 stores and older binaries must fail closed on them. Downgrade recovery requires the existing consistent pre-migration snapshot, not a down migration. Task 7A must account for this v13→v14 transition in its separately authorized install/backup/restore package; this amendment authorizes no installation. Architecture and Security/Privacy independent review must cover the new stable ticket/history boundary and transactional preservation as part of the existing Task 7 review.

This completed brief is retained as non-authoritative delivery history. The
[progress ledger](../../progress.md) records direct validation and independent
Code/QA, Architecture, Security/Privacy and documentation review, with no
Required findings. Native synthetic-store checks cover the complete writer
integration and v14 amendment. Commit/push/PR/merge remains authorized; the
coordinator owns integration verification and opening Task 7A. Durable files
are repository source, tests, this brief and catalog/index/ledger records.
Temporary build logs, result bundles, DerivedData and the PR body remain in
`.build/rr-r10-task7`; remaining synthetic fixture/host directories are retained.
No cleanup, live migration, installation or catalog acceptance was performed.
