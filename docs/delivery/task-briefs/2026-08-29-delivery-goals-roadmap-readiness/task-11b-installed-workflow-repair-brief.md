# RR-R10 Task 11B installed-workflow repair

Completed implementation and installed verification; non-authoritative retained
scope. Five focused tests, signed Release build, installed checker/example and
UI/inventory checks passed. Independent source and installed review accepted
with Required 0, Optional 0. Current terminal reconciliation is in
[progress](../../progress.md); the [evidence](../../evidence/2026-09-02-rr-r10-task-11b-installed-workflow-repair.md)
records the corrected installed app and preserved owner state.

## Objective and authorization

The owner explicitly authorized this dedicated task on 2026-09-02 to review
Task 11B against its actual requirements, repair unfinished installed behavior,
install the corrected app, and complete focused validation, documentation,
commit, push, PR and merge into `codex/release-radar-mvp`.
PR #16 (`dbe18bd`) is the completed-work baseline. This authorization supersedes
the old closeout hold; it does not reopen or repeat completed app operations.

## Scope and exclusions

Package the existing documentation checker and a usable catalog-v1 reference,
make installed paths discoverable, and correct successful legacy file-path
inventory so uncatalogued evidence does not falsely report `evidenceConflict`.
Preserve missing/unsafe path and missing managed-artifact rejection. Verify the
installed result, including RekonUILib's existing AGENTS.md evidence readback.
Reconcile this brief, the original brief, progress and required catalog/indexes.

Work only in the dedicated `codex/rr-r10-task-11b-installed-repair` worktree.
Preserve the canonical checkout's pre-existing dirty files and all governing
instructions, guidance-v2 bytes, configuration, identities and owner history.
No other repository changes, rebinding, evidence rewriting, task reopening,
acceptance/completion replay, backup, restore rehearsal, cleanup or issue #9 work.

## Dependencies and material risks

The integrated source is available. Existing Task 11B completion is revision 17,
audit `B16E76CE-65E5-45E2-9D72-9E2D56D5F156`. Subsequent owner-override acceptance
of RR-R10 is audit `76F82263-C066-42C3-A991-1D0220F1AA6C`; RR-DG-R10 stays Active.
These states do not prove product correctness. No unsupported reopening occurs.
Owner storage remains exclusively app-owned; use supported read-only inventory
and UI. The installed signed helper is the fallback for the closed connector.
Preserve signatures, entitlements, framework loading and owner-state boundaries
when replacing only `/Applications/ReleaseRadar.app`.

## Tests and acceptance

- Reproduce false legacy rejection and absent packaged tooling before changes.
- Focused synthetic tests cover valid legacy evidence, missing/unsafe evidence,
  missing managed identity, packaged checker execution and shipped reference.
- Signed Release app includes a runnable checker with usable installed help and
  reference; checker validates a prepared catalog without a source checkout.
- Installed inventory resolves RekonUILib's unchanged AGENTS.md without conflict;
  relevant owner state and identities remain unchanged across replacement.
- Reuse unaffected prior results. No full-suite or repeated visual matrix.
- Native documentation/index checks and diff checks pass; record precise limits.
- One independent code/QA reviewer also examines the concrete security boundary
  and installed guidance; successful direct checks and review are terminal.

No new delivery feature, schema migration, public mutation or security-policy
change is intended. The review must challenge unnecessary scope or machinery.
