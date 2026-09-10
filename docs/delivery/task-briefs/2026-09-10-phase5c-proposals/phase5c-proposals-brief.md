# Phase 5C — Saved proposals, approval and atomic application

## Objective and outcome

Deliver persisted, version-specific plan-change proposals with exact baseline,
derived diff, rationale and disposition. Explicit approval binds one proposal
version and baseline; a separate deliberate apply atomically changes the app-owned
planning graph. Stale state changes nothing and requires a refreshed version and
approval. The [approved Phase 5 sequence](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md#remaining-phase-5-delivery-sequence--2026-09-09)
controls this complete slice. No new product choice is outstanding.

## Scope and exclusions

Support one coherent additive work package: new phases, phase-owned goals,
unassigned/Backlog tickets, pending task additions, first placement, initial goal
assignment and new dependency edges. Existing ticket subjects must be unassigned
or Backlog and satisfy existing unstarted-work protections. Reject identity
replacement, dependency retargeting/removal, assignment removal/transfer and any
implicit readiness, lifecycle, execution or acceptance change. Do not wrap existing
upsert/plan-revision methods in ways that remove obligations. Existing low-level
operations retain their public behavior; successor/withdrawal/split and complete
carry-forward reconciliation belong to Phase 5D, full phase lifecycle to Phase 5E.

Include typed save/query/decision/apply, native Project Plan proposal list/detail,
audit and recovery. No proposal generator, execution engine, generic graph patch,
repository mutation, distributed transaction, new broad History/Goals screen,
export/import, consumer change, package update or shared-feature expansion.

## Dependencies and contracts

Baseline is preserved local shared closeout `28d323a284f29d447a44f9aad4c304dac2644a5d`
plus this committed handoff. Phase 5B is merged in PR39; shared source is locally
reviewed and must remain unpublished. Read [ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-004](../../../architecture/ADR-004-delivery-goals-and-phase-plan-readiness.md),
[ADR-005](../../../architecture/ADR-005-ticket-task-work-plans.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md)
and the [dashboard design](../../../design/agent-driven-delivery-dashboard-design.md).
Read-only chief architect `01a088a9-bdc4-74c1-889a-6ee00d7cafb4` assessed the baseline;
its contract findings are incorporated here, with no owner choice or source writes.

- Persist immutable proposal versions, separate decisions and unique application
  records. Save includes bounded operations, server-captured authoritative baseline,
  derived before/after diff, recorded reference impacts and rationale. Refresh makes
  a new version and preserves old decisions; it never approves automatically.
- Owner decisions bind exact proposal/version, baseline digest and current project
  registration, with actor/disposition. Use trusted owner-app origin, checked before
  replay, following the existing owner acceptance boundary. Native Approve and Apply
  are separate deliberate controls. An apply request names the approved version and
  decision, accepts no replacement operation body and grants no external authority.
- Use a bounded project-scoped planning snapshot rather than a new dependency-closure
  engine. Include registration/recovery authority; phase-plan presence/revisions,
  readiness/membership; ticket identities/outcomes/placement/lanes/continuation;
  goal definitions/criteria/lifecycle/assignments; task-plan presence/revisions and
  task definition/completion/lifecycle; phase/ticket dependency topology and absence
  of proposed IDs; reference link sets/versions/retirement and exact source facts.
  Compare stable identity byte-exactly. Exclude navigation and volatile execution
  observations. Capture current phase facts without inventing Phase 5E semantics.
- Reuse safe bounded reference readers and expected source digests. Distinguish
  accepted catalog metadata from current bytes and missing access. Never claim
  historical content matches different current bytes. Revalidate authority after
  awaits and before publication/commit. External reads do not make SQLite and
  repository state a distributed atomic transaction.
- Reuse DeliveryStore.transact and existing planning policies. Recheck current
  admission, exact version/decision, baseline and each eligibility rule; commit all
  graph changes, application record, audit and receipt together. A forced late
  failure leaves none. Successful exact replay follows current authorization but
  precedes baseline comparison; lost replies recover without double application.
  Conflicting replay, stale approval/apply and second application requests reject
  without unintended records, audits or graph changes.

## Recovery, compatibility and future consumers

Add schema 21 after current 20 with no inferred proposals/approvals. Include schema
validation, ownership and immutable history constraints. Preserve actual new records
through relaunch, archive/restore, removal/reset retention and full backup. Reconcile
newer proposal versions/decisions/applications when restoring an older backup;
rotated registration means retained approvals remain history, never live authority.
Re-add cannot reconnect by path/name. Preserve existing public wire/portable v1
semantics; define future complete export representation without implementing it.
Phase 5D extends this proposal path with successors and obligation reconciliation;
Phase 5E consumes resolved obligations. No temporary acceptance shortcut is allowed.

## Native workflow and verification

Use existing Project Plan/RDS composition for proposal list/detail, version,
rationale, grouped diff, source impacts, decision and application state. Support
explicit rejection and refresh/review; loading or changed context withdraws stale
actions. Reuse source/recorded-impact navigation and Activity. Preserve exact
proposal/version/ticket focus through Back/Forward. Compare the running isolated
view with [Phase Board](../../../design/mockups/phase_board.png) and current Plan
composition at wide/compact sizes; document the new proposal workflow in dashboard
design without treating historical mockups as additional product scope.

Test first using repository-native XCTest. Directly exercise save/relaunch/history;
approval without graph mutation; full approved work-package apply; rollback after an
intermediate operation; stale changes in every baseline category; competing decisions
and applies; exact/conflicting replay and wrong-origin rejection; started/Accepted
and obligation guards; migration, removal/reset and older-backup reconciliation.
Native verification covers inspect → approve → relaunch → apply, stale refresh and
reapproval, rejection, lost-reply recovery, unavailable sources, real keyboard/AX
focus and readable scrolling. Extend existing tests; no new validation framework.

All builds/tests/native hosts require a reservation with the orchestrator. Verify
synthetic XCTest/AppLaunchConfiguration with default services suppressed, sanitized
`env -i` and only known required signing/package variables. No normal owner app,
credentials, real service registration or external calls. Preserve raw bundles
outside rolling logs, canonical `/private/tmp` safe roots where needed, and external
controller ownership of markers (host reads only). Do not delete temporary files.

## Assignment, risk-triggered reviews and endpoint

Orchestrator `01a086bd-7970-70f0-80e8-8c044ee8ef4a` owns ledger/catalog/generated
indexes and integration on local `codex/phase5c-orchestrator`. One fresh delivery
writer owns source/tests, this brief, affected ADR/design detail and canonical
evidence. Assign Sol High for persisted approval authority, cross-component graph
transactions and recovery; ceiling Astra High for a named unresolved issue, never
Ultra or unapproved xhigh/max. Dispatch supplies exact committed baseline and task ID.
One fresh independent Astra High reviewer covers contract/security/recovery/native
QA risks, with original outcome and immutable candidate. Only Required defects block;
no extra review layers or review of review. Report runtime settings only if exposed.

Endpoint: complete local source, relevant docs, direct tests, independent review and
scoped local commits. **No push or PR while inherited shared commits lack explicit
owner publication authorization.** Every merge also needs separate approval.
No installation, owner state, binding/catalog acceptance, direct SQLite edits,
consumer writes, notifications, packaging or cleanup. Report retained temporary
paths and process quiescence. Preserve the named local branch before archiving.
