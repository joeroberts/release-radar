# Phase 3A — Current documentation and same-folder recovery

## Objective and outcome

Deliver C8/#18 and contextual #19/C12 recovery: one truthful documentation
observation shared by Overview, evidence and project health, automatically refreshed
after authorized filesystem changes, activation, reopening and recovery. Restore folder
access directly from documentation and evidence errors without accepting or repairing
the catalog. Phase 3B will add content preview on this committed observation contract.

## Scope, dependencies and accepted boundaries

Start from `cd16df1b0226aa8a08bd167364779103ebe86278` plus this committed brief;
dispatch supplies the exact revision. Preserve merged C4–C7 and the completed narrow
regular-`.DS_Store` repair. Follow the owner's Phase 3 authorization,
[full-product plan](../../plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
[managed-documentation contract](../../../design/managed-repository-documentation-contract.md),
[ADR-001](../../../architecture/ADR-001-release-radar-boundaries.md),
[ADR-006](../../../architecture/ADR-006-managed-repository-documentation-contract.md) and
[ADR-007](../../../architecture/ADR-007-proportional-delivery-validation.md).

Fresh Astra High architecture assessment `01a07e76-a1c5-7e02-a534-d237eec8c309`
confirmed no new custody or identity policy is needed. Overview currently caches
guidance, health inspects separately, and evidence independently resolves catalogs.
Existing managed locators, accepted binding, bounded reader and failure/lifecycle
models are reusable. Ordinary guidance observation can mark bookmarks stale and audit;
automatic observation must instead use the read-only authorization path. Same-folder
reauthorization is catalog-independent but needs captured registration/root protection
through picker and commit. Source assessment is not runtime acceptance evidence.

Planning/history, portable export/import and companion publication remain future
consumers only. Preserve repositoryID/artifactID and accepted snapshot custody. No
persistence migration is expected; any necessary change must remain bounded to these
acceptance criteria. Never treat a resolved or cached path as managed identity.

## Acceptance criteria and material risks

- One root/registration-scoped observation supplies Overview, evidence and documentation
  health. Carry the exact registration/generation, root and binding identity, observation
  generation and meaningful check time. Other health failures remain independently visible.
- Show checking, current, invalid, pending acceptance and inaccessible states accurately.
  Immediately withdraw prior success when invalidated; coalesce reads and reject results
  from an older project/root/registration, catalog context or service graph.
- Detect relevant authorized filesystem changes, including nested documentation edits,
  and recheck after activation/reopening and recovery. Recover automatically through
  valid → changed/invalid → repaired. Stop monitoring and release scopes on archive,
  removal and service replacement. Archived detail remains truthful and read-only.
- Observation uses existing bounded no-follow validation and read-only authorization.
  Checking/watching must not write documents, accept catalogs, update persisted evidence
  availability, audit bookmark status or mutate delivery state. Preserve existing limits
  and the exact metadata exception; no new broad exclusions.
- Documentation and evidence rootUnavailable/staleRoot errors expose an accessible
  “Restore folder access” native picker using the existing audited same-folder operation.
  Verify exact saved root and captured registration/root authority at commit. Reject stale
  picker requests after lifecycle, root, registration or store replacement.
- Successful renewal preserves project/root/repository/evidence/ticket/phase/goal identity
  and accepted catalog state, even when the catalog remains invalid or pending. Refresh
  the shared observation afterward and display the remaining problem honestly.
- Cancellation, wrong folder, denial, failure and unavailable store preserve association
  and offer useful accessible recovery. Actual relocation stays separately available with
  its accepted-catalog checks. Investigate the reported picker timeout only if reproduced.
- Use RDS components/appearance as supplied. Verify visible status changes, compact/wide
  layouts, keyboard operation and accessibility. Inspect relevant approved mockups first;
  no light/dark feature work or design-system change.

## Test strategy and execution isolation

Use test-first repository-native tests for changed behavior: external edit/repair,
pending acceptance, burst/coalescing and stale-result races, activation/reopening,
access loss, invalid-catalog renewal, lifecycle transitions, wrong root, cancel/denial,
transaction failure and unavailable/replaced store. Assert zero observation side effects
and identity/snapshot preservation. Existing unrelated passing checks stay closed.

Before launching any app/test runner, inspect the supported XCTest isolation path in
`ReleaseRadarApp.swift`: PID-specific synthetic store, inert failure, suppressed normal
startup and termination services. Inject synthetic stores and credentials throughout;
never initialize `ReleaseRadarAppServices.shared` or owner services through a test.
Do not use diagnostic commands that dump inherited environment values.

Native recovery verification requires a signed isolated synthetic host with actual
production filesystem entitlements and no broad XCTest filesystem exception. Inspect
actual entitlements before/after; use numeric-PID UI targeting, never app-path targeting
that can launch a normal app. The C7 evidence describes the supported prior route:
[C7 execution evidence](../../evidence/2026-09-07-c7-backup-reset-recovery.md).
Source entitlement changes are excluded. If the isolated route cannot be established,
report the concrete limitation before launch; broad hosted access is not shipping proof.

The prior accidental normal launch and credential exposure remain unresolved separate
work. No installation, real project-data operation, application binding/catalog acceptance,
plugin/cloud mutation, real notification, additional entitlement change, credential or
owner-state repair, or cleanup is authorized. Synthetic product tests are authorized;
agents never edit SQLite directly. Preserve unrelated files and retained builds.

## Assignment, reviews and endpoint

Delivery: fresh Sol High task/worktree, ceiling Astra High for a named unresolved risk;
Ultra prohibited. One writer owns necessary product source, focused tests, this brief,
affected product documentation and verification evidence. Orchestrator owns progress,
catalog/index integration and merge coordination. No concurrent product writer overlaps.

One fresh independent reviewer covers code, authorization/security and UX/QA risks of
the material candidate, including direct native evidence. Only Required findings block;
repeat only affected checks and correction review. The writer is not its own reviewer.

Endpoint: direct verification, scoped local commits, pushed branch and PR against
`codex/release-radar-mvp`, followed by independent review/corrections. Ask the owner
before merge. Report changed behavior, commit/PR, direct results, remaining limitations,
and exact temporary files/processes. Persist durable evidence in the repository before
completion; do not delete retained outputs. Phase 3B begins from committed 3A after its
required review and approved merge, and does not implement future portability features.
