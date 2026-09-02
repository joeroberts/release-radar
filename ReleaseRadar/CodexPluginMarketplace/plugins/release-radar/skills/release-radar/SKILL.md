---
name: release-radar
description: Use when working in a repository tracked by Release Radar or when the owner asks to initialize or synchronize Release Radar tracking.
---

# Release Radar Tracking

Current project-guidance version: `2`.

For initialization, a guidance update, or an audited repair, continue only when the owner explicitly authorizes the repository handoff and the copied Release Radar prompt names the exact authorized repository root. Canonicalize that stated root and the current Codex task root before any repository write or Release Radar call. Continue only when they match exactly. If the prompt omits the exact root, or the current task is rooted at a parent, child, or different folder, report the mismatch and stop before writing any file or calling Release Radar. Do not substitute another root, create, delegate, or hand off to another task. Read all applicable repository instructions and durable tracking documents first. Codex may write the permitted repository documentation only under that exact owner authorization; Release Radar remains the only SQLite writer.

Before any write, inspect every existing path component from the selected repository root through the root `AGENTS.md` and `docs/delivery/progress.md` with no-follow filesystem metadata. The selected root and existing `docs` and `docs/delivery` components must be real directories, not symlinks; each existing final file must be regular, not a symlink or other non-regular file. Report any discrepancy and stop without writing or calling Release Radar.

Before changing guidance, require an existing catalogued `docs/delivery/progress.md`, a valid `docs/catalog.json` v1, and matching generated indexes. Run the accepted `ReleaseRadarDocumentationTool check --root <exact authorized root>`; if the tool, ledger, or required catalog/indexes are missing, corrupt, unsafe, or stale, report the prerequisite and stop before any handoff write. Missing documentation must be prepared through separately owner-authorized work. This handoff does not authorize ledger or catalog creation, document moves, repository binding, catalog acceptance, or evidence adoption.

Use `release_radar_inventory_evidence` to obtain a complete read-only inventory for the exact authorized root and project before choosing a handoff identity. Require `isComplete`, matching project/root identity, and exact persisted evidence rows; never guess from a basename, path prefix, checksum, or generated ID. A missing managed binding makes an already-v2 inventory incomplete even if legacy rows are returned; stop for separately authorized binding recovery before the handoff. Obtain the complete v1 inventory before upgrading guidance. Find the exact ticketless legacy `AGENTS.md` path and any `release-radar-handoff:v1:` IDs. If there is exactly one matching row with that prefix, reuse its existing handoff evidence ID unchanged. If no matching path or handoff ID exists, create one ID as `release-radar-handoff:v1:<fresh UUID>`. Multiple, mismatched, ticket-associated, managed-locator, incomplete, or unavailable results require recovery before any write. The `v1` evidence namespace remains stable across guidance upgrades; it is not the installed guidance version.

Prepare and write the permitted guidance first:

- Keep the existing `docs/delivery/progress.md` as the durable delivery ledger and preserve it byte-for-byte throughout this handoff.

- Manage only the exact block below in the selected repository's root `AGENTS.md`. If the file is absent, create it with this block. If the file exists without a Release Radar marker, append this block and preserve every existing byte. If exactly one older managed block exists, replace only from its start marker through its end marker. Exact v1 guidance is upgradeable. Preserve an exact current v2 block; do not overwrite a modified current block. If markers are malformed, duplicated, or newer than version `2`, report the discrepancy and stop before any write or mutation.

```markdown
<!-- release-radar-guidance:v2:start -->
## Release Radar tracking

This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

- Read `docs/catalog.json` and begin documentation discovery at `docs/README.md`. Follow generated local indexes before broad search and load only task-relevant controlling artifacts.
- The catalog owns documentation identity, lifecycle, authority, and navigation. `docs/delivery/progress.md` remains the durable delivery source of truth; the catalog and indexes never authorize or infer ticket or phase state.
- Under owner authorization, update the catalog, collection/index metadata, active references, and applicable checksums in the same change as any durable add, move, rename, supersession, closeout, restoration, or deletion. Preserve stable artifact IDs and never reuse retired IDs.
- Keep only active operational detail in `docs/delivery/progress.md`; move closed detail to `docs/delivery/archive/` and label it historical and non-authoritative. Place implementation plans in `docs/delivery/plans/` and controlling task briefs in `docs/delivery/task-briefs/`.
- Add no new content under `docs/superpowers/` during transition and never recreate it after cutover.
- Release Radar is the only SQLite writer. Never edit that database or repair a managed evidence path directly. Use supported read-only inventory and typed, audited evidence operations with exact artifact IDs and request identities.
- Managed operations require the exact authorized root and accepted repository ID, catalog version, and digest. Only explicit repository binding establishes a missing binding; only catalog acceptance advances an accepted snapshot. Treat a changed catalog as pending until Release Radar accepts its validated transition.
- Run the repository documentation check and read back the resulting repository and application state before completion. Do not claim completion while catalog, indexes, lifecycle, authority, references, applicable checksums, evidence resolution, or application readback disagree. Preserve exact requests across uncertain outcomes.
- Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state. Repository-local rules outside this block may narrow this contract but must not weaken or duplicate it.
<!-- release-radar-guidance:end -->
```

Directly read the permitted files back after writing. If no repository change was required and the owner's copied prompt does not explicitly report the handoff incomplete even though the managed block already matches, report that the guidance is already current and do not send a mutation. If the copied prompt explicitly reports that handoff-incomplete state, do not rewrite either repository file; continue only with the audited repair below.

When the handoff changed the managed guidance block, or when the owner's copied repair prompt explicitly reports the handoff incomplete while the managed block already matches, use the exact evidence ID selected from inventory above and one fresh UUID `requestID`, retain the complete original request, and call the existing `release_radar_add_evidence` mutation for the exact root `AGENTS.md` that was read back. Omit `ticketID`; include the selected project root, evidence path, concise handoff or audit-repair reason, current task attribution, evidence ID, and request ID. A v1-to-v2 upgrade still requires this fresh audited request even when its evidence ID already exists; the existing mutation updates that exact row without creating duplicate evidence. Never use `release_radar_upsert_phase` or any other delivery-state mutation merely to obtain an audit.

After a successful audited result, read the files back again and pair that readback with the successful audited result. Preserve the ledger byte-for-byte; do not add or infer an audit field there. Never use direct SQLite access or invent repository reads through MCP.

On `appUnavailable`, leave the already-written repository files in place with the audit pending, tell the owner to open Release Radar, and replay the complete original request verbatim. On `outcomeUnknown`, preserve the same pending state and replay the complete original request verbatim through the existing idempotent request receipt after availability is restored. The complete request includes the exact command, `requestID`, evidence ID, selected project root, evidence path, reason, task attribution, and omitted `ticketID`; do not regenerate or partially reconstruct it.

A failed file postcondition, failed mutation, missing audited result, or mismatch is a discrepancy, never success. If readback fails after the audited result, report the repository discrepancy and recover readback without a second mutation. Never fabricate completion, review, acceptance, authority, or synchronization.


For ongoing managed documentation work, read the catalog and root/local indexes first and load only task-relevant controlling artifacts. Keep catalog metadata, indexes, active links, lifecycle/authority, and applicable immutable-evidence checksums consistent in the same authorized change. Do not add checksums for mutable plans, briefs, review reports, indexes, or progress. Preserve accepted historical manifests. Keep active progress separate from closed historical detail, use `docs/delivery/plans/` and `docs/delivery/task-briefs/`, add nothing under `docs/superpowers/`, and never recreate that tree after cutover.

Managed operations require the exact accepted repository/root/version/digest. Only an explicitly authorized `release_radar_bind_documentation_repository` establishes a missing binding; `release_radar_accept_documentation_catalog` validates and advances a prior accepted snapshot. A filesystem catalog change stays pending until acceptance. Use `release_radar_add_managed_evidence` for artifact-ID evidence, `release_radar_adopt_managed_evidence` only for an explicitly approved exact adoption set, and `release_radar_relocate_legacy_evidence` only for explicitly named arbitrary legacy paths. Never repair managed paths directly, infer evidence identity, or edit SQLite. These operations are separate owner-authorized work, not implicit handoff steps.

Before completion, run the repository documentation check and compare repository readback with the supported application inventory/readback. Missing or mismatched bindings, unaccepted catalogs, unavailable roots, invalid catalogs/checksums, and unresolved evidence are recovery states. Report them without claiming managed-current status or delivery synchronization. Preserve the complete original mutation request for exact replay after an uncertain outcome.
