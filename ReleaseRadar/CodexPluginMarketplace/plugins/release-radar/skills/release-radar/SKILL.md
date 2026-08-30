---
name: release-radar
description: Use when working in a repository tracked by Release Radar or when the owner asks to initialize or synchronize Release Radar tracking.
---

# Release Radar Tracking

Current project-guidance version: `1`.

For initialization, a guidance update, or an audited repair, continue only when the owner explicitly authorizes the repository handoff and the copied Release Radar prompt names the exact authorized repository root. Canonicalize that stated root and the current Codex task root before any repository write or Release Radar call. Continue only when they match exactly. If the prompt omits the exact root, or the current task is rooted at a parent, child, or different folder, report the mismatch and stop before writing any file or calling Release Radar. Do not substitute another root, create, delegate, or hand off to another task. Read all applicable repository instructions and durable tracking documents first. Codex may write the permitted repository documentation only under that exact owner authorization; Release Radar remains the only SQLite writer.

Before any write, inspect every existing path component from the selected repository root through the root `AGENTS.md` and `docs/delivery/progress.md` with no-follow filesystem metadata. The selected root and existing `docs` and `docs/delivery` components must be real directories, not symlinks; each existing final file must be regular, not a symlink or other non-regular file. Report any discrepancy and stop without writing or calling Release Radar.

Prepare and write the permitted repository files first:

- Keep `docs/delivery/progress.md` as the durable delivery ledger. Preserve it byte-for-byte when it exists. When it is absent, create only this truthful, state-neutral handoff record; do not infer delivery state:

  ```text
  # Delivery progress

  ## Release Radar handoff

  - Guidance version: `1`
  - Release Radar audit: Pending
  ```

- Manage only the exact block below in the selected repository's root `AGENTS.md`. If the file is absent, create it with this block. If the file exists without a Release Radar marker, append this block and preserve every existing byte. If exactly one managed block exists, replace only from its start marker through its end marker. If markers are malformed, duplicated, or newer than version `1`, report the discrepancy and stop before any write or Release Radar call.

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

Directly read the permitted files back after writing. If no repository change was required and the owner's copied prompt does not explicitly report the handoff incomplete even though the managed block already matches, report that the guidance is already current and do not send a mutation. If the copied prompt explicitly reports that handoff-incomplete state, do not rewrite either repository file; continue only with the audited repair below.

When the handoff changed either permitted repository file, or when the owner's copied repair prompt explicitly reports the handoff incomplete while the managed block already matches, create one evidence ID exactly as `release-radar-handoff:v1:<fresh UUID>` and one fresh UUID `requestID`, retain the complete original request, and call the existing `release_radar_add_evidence` mutation for the exact root `AGENTS.md` that was read back. Omit `ticketID`; include the selected project root, evidence path, concise handoff or audit-repair reason, current task attribution, evidence ID, and request ID. Never use `release_radar_upsert_phase` or any other delivery-state mutation merely to obtain an audit.

After a successful audited result, if this handoff created the ledger, replace only `Pending` in its Release Radar audit line with the returned audit event ID. Read the files back again and pair that readback with the successful audited result. If the existing ledger was preserved, do not add or infer an audit field there. Never use direct SQLite access or invent repository reads through MCP.

On `appUnavailable`, leave the already-written repository files in place with the audit pending, tell the owner to open Release Radar, and replay the complete original request verbatim. On `outcomeUnknown`, preserve the same pending state and replay the complete original request verbatim through the existing idempotent request receipt after availability is restored. The complete request includes the exact command, `requestID`, evidence ID, selected project root, evidence path, reason, task attribution, and omitted `ticketID`; do not regenerate or partially reconstruct it.

A failed file postcondition, failed mutation, missing audited result, or mismatch is a discrepancy, never success. If the final ledger update or readback fails after the audited result, report the repository discrepancy and repair only the permitted documentation without a second mutation. Never fabricate completion, review, acceptance, authority, or synchronization.
