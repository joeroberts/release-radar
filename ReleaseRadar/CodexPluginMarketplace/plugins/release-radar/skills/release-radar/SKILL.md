---
name: release-radar
description: Use when working in a repository tracked by Release Radar or when the owner asks to initialize or synchronize Release Radar tracking.
---

# Release Radar Tracking

Current project-guidance version: `3`.

For initialization, a guidance update, or an audited repair, continue only when the owner explicitly authorizes the repository handoff and the copied Release Radar prompt names the exact authorized repository root. Canonicalize that stated root and the current Codex task root before any repository write or Release Radar call. Continue only when they match exactly. If the prompt omits the exact root, or the current task is rooted at a parent, child, or different folder, report the mismatch and stop before writing any file or calling Release Radar. Do not substitute another root, create, delegate, or hand off to another task. Read all applicable repository instructions and durable tracking documents first. Codex may write the permitted repository documentation only under that exact owner authorization; Release Radar remains the only SQLite writer.

Before any write, inspect every existing path component from the selected repository root through the root `AGENTS.md` and `docs/delivery/progress.md` with no-follow filesystem metadata. The selected root and existing `docs` and `docs/delivery` components must be real directories, not symlinks; each existing final file must be regular, not a symlink or other non-regular file. Report any discrepancy and stop without writing or calling Release Radar.

## Lifecycle bootstrap

When the copied prompt explicitly names the lifecycle bootstrap path and includes an exact project ID, separate registration ID, positive request generation, and exact authorized root, repository preparation is the only authorized outcome of this run. Treat that tuple as indivisible and stop on any missing or mismatched value.

Inspect the exact root before proposing changes and distinguish these cases in the preview:

- For a blank repository, propose the minimum `docs/catalog.json` v1, generated collection indexes, `docs/delivery/progress.md` source of truth, and exact legacy staging guidance v1 block needed for the packaged documentation check.
- For a repository with existing documentation, preserve its content and instructions, catalog the existing durable documents, add only missing generated indexes, and append or preserve the exact legacy staging guidance v1 block. Never overwrite an existing progress ledger or reinterpret existing content as delivery state.
- For unsafe paths, malformed guidance, ambiguous existing ledgers, invalid catalogs, or content that cannot be preserved within the catalog contract, report the discrepancy and stop.

Show the complete proposed file set and intended changes before writing. After the owner-confirmed repository write, run `ReleaseRadarDocumentationTool write --root <exact authorized root>` only to generate the previewed indexes, then `check --root <exact authorized root>`, and read back every changed file. Report the exact repository ID, catalog version and digest. Stop there: lifecycle bootstrap does not authorize a Release Radar call, repository binding, catalog acceptance, v3 guidance installation, evidence mutation, phase creation, or any other delivery-state mutation. The owner must return to Release Radar to separately preview and confirm binding or catalog acceptance, then copy the subsequent audited-handoff prompt.

The exact legacy staging block is:

```markdown
<!-- release-radar-guidance:v1:start -->
## Release Radar tracking

This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

- `docs/delivery/progress.md` is the repository's durable delivery source of truth.
- Codex may update repository tracking documents under owner authorization.
- Release Radar is the only writer of its SQLite database. Use its existing typed MCP mutations; never edit that database directly.
- Do not claim synchronization without both a successful audited MCP result and direct readback of the corresponding repository files.
- Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state.
<!-- release-radar-guidance:end -->
```

The packaged catalog reference defines the accepted catalog shape and limits. Do not copy reference identities or paths blindly; create one fresh repository UUID for a genuinely new repository and preserve an existing valid repository ID.

Before changing guidance, require an existing catalogued `docs/delivery/progress.md`, a valid `docs/catalog.json` v1, and matching generated indexes. Run the accepted `ReleaseRadarDocumentationTool check --root <exact authorized root>`; if the tool, ledger, or required catalog/indexes are missing, corrupt, unsafe, or stale, report the prerequisite and stop before any handoff write. Missing documentation must be prepared through separately owner-authorized work. This handoff does not authorize ledger or catalog creation, document moves, repository binding, catalog acceptance, or evidence adoption.

Use `release_radar_inventory_evidence` to obtain a complete read-only inventory for the exact authorized root and project before choosing a handoff identity. Require `isComplete`, matching project/root identity, and exact persisted evidence rows; never guess from a basename, path prefix, checksum, or generated ID. A missing managed binding makes an already-managed inventory incomplete even if legacy rows are returned; stop for separately authorized binding recovery before the handoff. Obtain the complete pre-upgrade inventory before upgrading guidance. Find the exact ticketless legacy `AGENTS.md` path and any `release-radar-handoff:v1:` IDs. If there is exactly one matching row with that prefix, reuse its existing handoff evidence ID unchanged. If no matching path or handoff ID exists, create one ID as `release-radar-handoff:v1:<fresh UUID>`. Multiple, mismatched, ticket-associated, managed-locator, incomplete, or unavailable results require recovery before any write. The `v1` evidence namespace remains stable across guidance upgrades; it is not the installed guidance version.

Prepare and write the permitted guidance first:

- Keep the existing `docs/delivery/progress.md` as the durable delivery ledger and preserve it byte-for-byte throughout this handoff.

- Manage only the exact block below in the selected repository's root `AGENTS.md`. If the file is absent, create it with this block. If the file exists without a Release Radar marker, append this block and preserve every existing byte. If exactly one older managed block exists, replace only from its start marker through its end marker. Exact v1 and v2 guidance are upgradeable through the narrow v2-to-v3 path. Preserve an exact current v3 block; do not overwrite a modified current block. If markers are malformed, duplicated, or newer than version `3`, report the discrepancy and stop before any write or mutation.

```markdown
<!-- release-radar-guidance:v3:start -->
## Release Radar tracking

This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, changing tracked delivery state, or adopting generic ticket tasks, invoke the installed `release-radar` skill and follow it.

- Read `docs/catalog.json` and begin documentation discovery at `docs/README.md`. Follow generated local indexes before broad search and load only task-relevant controlling artifacts.
- The catalog owns documentation identity, lifecycle, authority, and navigation. `docs/delivery/progress.md` remains the durable delivery source of truth; the catalog and indexes never authorize or infer ticket or phase state.
- Under owner authorization, update the catalog, collection/index metadata, active references, and applicable checksums in the same change as any durable add, move, rename, supersession, closeout, restoration, or deletion. Preserve stable artifact IDs and never reuse retired IDs.
- Keep only active operational detail in `docs/delivery/progress.md`; move closed detail to `docs/delivery/archive/` and label it historical and non-authoritative. Place implementation plans in `docs/delivery/plans/` and controlling task briefs in `docs/delivery/task-briefs/`.
- Add no new content under `docs/superpowers/` during transition and never recreate it after cutover.
- Release Radar is the only SQLite writer. Never edit that database or repair a managed evidence path directly. Use supported read-only inventory and typed, audited operations with exact project identity, request identity, expected revision, and task identity.
- Managed operations require the exact authorized root and accepted repository ID, catalog version, and digest. Only explicit repository binding establishes a missing binding; only catalog acceptance advances an accepted snapshot. Treat a changed catalog as pending until Release Radar accepts its validated transition.
- Before generic task adoption, require a complete `release_radar_delivery_inventory` result for the exact authorized project and root. Prepare one exact reconciliation for every scoped non-Accepted ticket, classifying it as atomic, non-atomic, already-planned, or blocked, with rationale, exact plan baseline, additions, definition revisions, supersessions, and unchanged rows. Owner approval must identify that exact reconciliation. General approval of code or a delivery task is not approval to mutate Release Radar state.
- Apply an approved reconciliation only through `release_radar_revise_ticket_task_plan` and `release_radar_complete_ticket_task`. Preserve the exact command envelope for replay after an uncertain outcome, chain subsequent operations from the returned `ticketTaskPlanRevision`, and stop for refreshed inventory and approval if the baseline changes. Omission never deletes a task; Accepted or retired tickets and completed phases are not mutable, and unassigned tickets may receive definitions but cannot complete tasks until placed.
- Prior completion is explicit only when an applicable Release Radar delivery-evidence target has an explicitly applicable, available, successful observation for the same ticket and task scope. A failed, stale, superseded, unavailable, unknown, or generic observation does not imply task completion. Keep uncertain work pending; runtime commands enforce normal authority, lifecycle, revision, and replay rules rather than conversational approval or evidence sufficiency.
- Run the repository documentation check and read back the resulting repository and application state before completion. Do not claim completion while catalog, indexes, lifecycle, authority, references, applicable checksums, evidence resolution, task history, or application readback disagree. Preserve exact requests across uncertain outcomes.
- Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state. Repository-local rules outside this block may narrow this contract but must not weaken or duplicate it.
<!-- release-radar-guidance:end -->
```

## Generic task adoption

Task adoption is a separate owner-authorized workflow. First call `release_radar_delivery_inventory` with the exact project ID, root ID, and authorized root. Continue only when `isComplete` is true and the returned project, root, registration, phases, tickets, retirements, plan revisions, full task histories, eligibility fields, and active-task count form the complete intended scope. An unavailable, oversized, partial, failed, stale, or identity-mismatched inventory is a recovery state, never a basis for a reconciliation.

Prepare one exact reconciliation for every scoped non-Accepted ticket:

- `atomic`: no durable decomposition is useful; explain why and leave the plan absent.
- `non-atomic`: name the exact baseline revision (`null` for no plan), every addition, permitted pending-task title/order revision, supersession, and unchanged row. New plans use `expectedRevision: null`; existing plans use their exact positive revision. Omission does not delete or supersede anything.
- `already-planned`: retain the current plan unchanged and show its exact revision and active/history rows.
- `blocked`: explain the lifecycle, retirement, evidence, authorization, identity, scope, or ambiguity that prevents a safe change. Accepted and retired tickets and tickets in completed phases are not mutable. Unassigned tickets can receive definitions but cannot complete tasks until placement.

Prior completion must be established explicitly from `release_radar_ticket_delivery_evidence` for the same ticket and the exact task scope. A candidate is eligible only when the target is current and the observation is explicitly applicable, available, and successful. Failed, skipped, unknown, unavailable, stale-target, superseded, unrelated, and generic observations remain visible but do not imply task completion. If the evidence cannot establish the exact scope, keep the task Pending and say why.

Show the complete reconciliation before mutation. Owner approval must identify that exact reconciliation; general approval of code, a plan, or a delivery task is not runtime approval. After approval, re-read the inventory and require every baseline and identity to remain exact. Use only `release_radar_revise_ticket_task_plan` for additions, permitted definition revisions, and supersessions, and `release_radar_complete_ticket_task` for each explicitly evidenced completion. Chain each subsequent command from the returned `ticketTaskPlanRevision`.

For every mutation, choose one fresh UUID request ID, retain the complete exact command envelope, and do not regenerate or partially reconstruct it. On `appUnavailable`, do not assume execution; restore availability and send the exact command envelope. On `outcomeUnknown`, replay that exact envelope through the existing idempotent receipt. A revision conflict or changed registration/root/baseline invalidates the reconciliation: stop, refresh, and obtain approval for the revised exact reconciliation. After success, read back the Tasks card and History in Release Radar; the task definitions, completions, superseded history, revision, and activity must match the approved reconciliation.

Directly read the permitted files back after writing. If no repository change was required and the owner's copied prompt does not explicitly report the handoff incomplete even though the managed block already matches, report that the guidance is already current and do not send a mutation. If the copied prompt explicitly reports that handoff-incomplete state, do not rewrite either repository file; continue only with the audited repair below.

When the handoff changed the managed guidance block, or when the owner's copied repair prompt explicitly reports the handoff incomplete while the managed block already matches, use the exact evidence ID selected from inventory above and one fresh UUID `requestID`, retain the complete original request, and call the existing `release_radar_add_evidence` mutation for the exact root `AGENTS.md` that was read back. Omit `ticketID`; include the selected project root, evidence path, concise handoff or audit-repair reason, current task attribution, evidence ID, and request ID. The prior v1-to-v2 upgrade and the current v2-to-v3 upgrade both require this fresh audited request even when the evidence ID already exists; the existing mutation updates that exact row without creating duplicate evidence. Never use `release_radar_upsert_phase` or any other delivery-state mutation merely to obtain an audit.

After a successful audited result, read the files back again and pair that readback with the successful audited result. Preserve the ledger byte-for-byte; do not add or infer an audit field there. Never use direct SQLite access or invent repository reads through MCP.

On `appUnavailable`, leave the already-written repository files in place with the audit pending, tell the owner to open Release Radar, and replay the complete original request verbatim. On `outcomeUnknown`, preserve the same pending state and replay the complete original request verbatim through the existing idempotent request receipt after availability is restored. The complete request includes the exact command, `requestID`, evidence ID, selected project root, evidence path, reason, task attribution, and omitted `ticketID`; do not regenerate or partially reconstruct it.

A failed file postcondition, failed mutation, missing audited result, or mismatch is a discrepancy, never success. If readback fails after the audited result, report the repository discrepancy and recover readback without a second mutation. Never fabricate completion, review, acceptance, authority, or synchronization.


For ongoing managed documentation work, read the catalog and root/local indexes first and load only task-relevant controlling artifacts. Keep catalog metadata, indexes, active links, lifecycle/authority, and applicable immutable-evidence checksums consistent in the same authorized change. Do not add checksums for mutable plans, briefs, review reports, indexes, or progress. Preserve accepted historical manifests. Keep active progress separate from closed historical detail, use `docs/delivery/plans/` and `docs/delivery/task-briefs/`, add nothing under `docs/superpowers/`, and never recreate that tree after cutover.

Managed operations require the exact accepted repository/root/version/digest. Only an explicitly authorized `release_radar_bind_documentation_repository` establishes a missing binding; `release_radar_accept_documentation_catalog` validates and advances a prior accepted snapshot. A filesystem catalog change stays pending until acceptance. Use `release_radar_add_managed_evidence` for artifact-ID evidence, `release_radar_adopt_managed_evidence` only for an explicitly approved exact adoption set, and `release_radar_relocate_legacy_evidence` only for explicitly named arbitrary legacy paths. Never repair managed paths directly, infer evidence identity, or edit SQLite. These operations are separate owner-authorized work, not implicit handoff steps.

Before completion, run the repository documentation check and compare repository readback with the supported application inventory/readback. Missing or mismatched bindings, unaccepted catalogs, unavailable roots, invalid catalogs/checksums, and unresolved evidence are recovery states. Report them without claiming managed-current status or delivery synchronization. Preserve the complete original mutation request for exact replay after an uncertain outcome.
