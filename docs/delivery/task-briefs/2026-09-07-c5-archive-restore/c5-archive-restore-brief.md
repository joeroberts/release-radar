# C5 reversible project archive and restore

## Objective and outcome

Deliver a complete, persistent archive/restore journey with associated C12 health
actions. Archive retains the complete project graph, historical identity, registration
and repository association; hides the project from default active views; and suspends
app-owned operational admission/monitoring/notification eligibility. Restore changes
lifecycle and exposes access or documentation problems without silently repairing them.
Neither local lifecycle action requires a valid current repository catalog.

## Scope, dependencies and authority

Use the merged C4 product baseline `32bb2cee59f34f7dfc9eae4b7a86391f77bf742d`, plus
this committed brief and coordination ledger; the dispatch supplies the exact commit.
Reuse existing project/registration store operations, migrations, typed owner actions,
projection/health services and RDS components. Inspect current services before choosing
changes. A fresh architecture consultation already confirmed C4 → C5 → C6 → C7 with
no new owner product decision; schema layout and callback coordination are engineering.

Follow [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md), and C5/C12
and D1/D3/D7 in the [full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md).
Preserve accepted five lanes, phase-less setup, domain/registration identity, retained
history, Mac/repository authority and unchanged RDS appearance. C6 removal and C7
backup/reset must later consume the lifecycle without losing attribution or allowing
old work to target a replaced registration. Future History/search and complete portable
records/documents/evidence retain archived records. Do not implement those future
features in C5, nor reopen observer/hooks/companion discoveries or shared RDS.

Exclude removal, data erasure, reset/backup, portable format changes, broader navigation
or document watching, real owner-data operations, installation and cloud work. Archive
is reversible lifecycle management, not removal or proof that external execution stopped.

## Acceptance and risks

- A visible, accessible, exact-project archive action previews its effects and can be
  cancelled without mutation. Archived projects remain discoverable through an explicit
  archived view/filter and offer restore; active default views/counts stay consistent.
- Archive/restore persists across store reopen and app relaunch. Local lifecycle works
  with lost folder permission, invalid/pending catalog and zero phases. A failed store
  write produces actionable error and no partial graph/lifecycle/audit/receipt change.
- Preserve graph, roots/bookmarks/binding, exclusions, phases, goals, tasks, evidence and
  event history. Existing projects migrate to active without changing legacy identities.
- App-owned mutations, monitoring, notification scheduling and late callbacks cannot
  continue operational work against archived projects. Restore does not replay stale
  requests, notifications or external actions; already-sent/unknown effects stay truthful.
  Keep generation/revision checks within existing registration semantics.
- Define archived read-only navigation and error/health behavior so old routes and
  callbacks cannot silently act as active or retarget another project. Restore preserves
  the graph/registration and reports access problems; it grants no folder capability,
  accepts no catalog and does not alter repository files. Other projects are preserved.
- Use approved settings/board visual references and existing RDS appearance. Verify
  compact/wide, keyboard/AX, cancellation, empty/error and successful readback journeys.

## Test strategy and review

Test first at existing store/service layers: migration, graph/history preservation,
atomic failure/replay, stale callbacks, active/archived projection/notification scope,
restore with unavailable access/catalog and lifecycle restart. Exercise the actual UI
with synthetic stores; compare relevant approved screenshots before implementation
and at review. Use native documentation and diff checks. No custom validation harness.

One fresh independent reviewer covers persistence/authorization/notification recovery
and UI/QA risks; only Required findings block. Do not repeat unrelated transport tests
or claim the whole suite green. Disclose that XCTest may inject read-only `/`; synthetic
checks do not prove real owner grants under shipping entitlements. No installation or
owner database mutation is authorized.

## Assignment and delivery endpoint

Delivery owner: fresh task dispatched by recovery orchestrator, sole writer of its
fresh worktree and new `codex/c5-archive-restore` branch/upstream. Explicit model/effort
Sol High, justified by persistence/admission/notification recovery; ceiling Astra High,
no Ultra. Report effective settings only if exposed. Own necessary C5 source/tests,
this brief and affected product documentation. Orchestrator exclusively owns progress
and shared catalog/index integration; report required metadata changes before touching
shared files. Persist any controlling refinement here before product implementation.

Endpoint: scoped verified commits, published branch and PR against
`codex/release-radar-mvp`, required independent review/corrections. Each merge needs
owner approval. Real archive/restore against owner state, installation, notifications
to real recipients and all reserved external actions require exact separate authority.
Report candidate, checks/limits, temporary files and stopped processes; orchestrator
preserves the outcome and promptly archives the bounded task.

## Bounded implementation refinement

Schema v16 adds one constrained `projects.lifecycle` value (`active` or `archived`),
defaulting every existing project to `active`. The existing project ID, registration ID,
roots/bookmarks, documentation binding, graph and history remain in their current tables.
Each successful archive or restore increments the existing registration request generation
inside the same store-owned transaction; the registration identity itself is preserved.
The preview captures the exact registration/generation, source lifecycle and graph counts,
and commit revalidates them before changing anything. Generation overflow, stale previews,
wrong lifecycle and store failure reject the whole transaction without a lifecycle, audit,
receipt or notification partial write.

Archive atomically deactivates the project's notification occurrences, marks queued
notifications `suppressed`, and marks an `attempt_started` notification `unknown` with an
archive-specific ambiguity code. Sent, failed and already-unknown history remains factual.
Restore never requeues suppressed or unknown work. New notification creation, pending
dispatch, persisted root admission, in-transaction agent-command admission and observation
callbacks all require `active`; the dispatcher recheck closes the race after root resolution.
Fresh work after restore uses the newly incremented generation and ordinary occurrence
deduplication rather than replaying pre-archive work.

`DashboardProjection` loads only active projects and their authorized evidence readback;
it separately loads a catalog-agnostic archived summary without opening bookmarks.
Projects gains an explicit Active/Archived scope. Archived rows navigate only to a
read-only archived detail with retained graph/history counts, last-check health and a
previewed Restore action. Old operational routes for an archived project resolve to that
archived detail rather than another project. The active Overview exposes a previewed
Archive action. Both confirmations name the exact project, summarize effects, support
Cancel/Escape without mutation and retain actionable errors after a failed commit.

Focused tests cover the v15→v16 default, full graph/registration preservation, transaction
rollback, generation-stale previews and callbacks, active-only admission/projections,
notification suppression/ambiguity/no-replay, zero-phase and unavailable-access/catalog
restore, route recovery, and native compact/wide confirmation, empty, success and error
states. Synthetic UI and service checks do not exercise real owner grants, recipients,
installation or the shipping entitlement boundary.
