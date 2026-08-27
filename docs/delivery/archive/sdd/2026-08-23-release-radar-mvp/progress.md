# SDD ledger — plan: docs/superpowers/plans/2026-08-23-release-radar-mvp.md

## Preflight

Ruling: This new standalone repository is the isolated workspace; all agents write serially on `codex/release-radar-mvp` without a worktree, per explicit owner direction — if wrong, isolation must be restored before overlapping work begins.

| Tasks/interfaces | Producer → consumer | Finding |
| --- | --- | --- |
| RR-01 internal | Xcode targets, routes, signing, ADR match its build check | Consistent. |
| RR-02 internal | Store records/invariants match atomicity and relaunch scenario | Consistent after migration-recovery correction. |
| RR-03 internal | Typed envelope/dispatcher match rollback and unavailable-app scenario | Consistent after signed-peer and canonical-root correction. |
| RR-04 internal | Bookmark/worktree discovery matches phase-one gate | Consistent after external-worktree authorization correction. |
| RR-06 internal | Five-lane projection matches latest approved mockup | Consistent. |
| RR-05 internal | Read-only observer matches bounded feasibility and stale mode | Consistent. |
| RR-07 internal | Review/graph/activity/settings match seeded UI flow | Consistent. |
| RR-08 internal | One-time importer matches fixture/idempotency/source-preservation checks | Consistent. |
| RR-09 internal | Atomic event/audit/outbox matches fake-transport deduplication checks | Consistent. |
| RR-10 internal | Integrated failure states match final signed acceptance | Consistent. |
| RR-01 → all later tasks | Synchronized project groups and shared app shell accept later files | RR-01 must configure filesystem-synchronized target groups so later tasks do not hand-edit project membership repeatedly. |
| RR-02 → RR-03/RR-04/RR-06/RR-08/RR-09 | `DeliveryStore` and domain records | Consistent; app remains sole writer. |
| RR-03 → RR-04/RR-07 | Typed agent actions | Consistent; onboarding and review decisions use the same bridge. |
| RR-04 → RR-05/RR-06/RR-08 | Canonical projects/bookmarks/worktrees | Consistent. |
| RR-06 → RR-05/RR-07/RR-10 | Recognizable persisted UI baseline | Consistent; live-state enhancement follows visible local board. |
| RR-05 → RR-07/RR-09/RR-10 | Live-or-degraded runtime semantics | Consistent; failure does not block stale/unavailable successors. |
| RR-07 → RR-08/RR-09/RR-10 | Review/activity/settings surfaces | Consistent. |
| RR-08/RR-09 → RR-10 | Imported data and notification history | Consistent. |

## Task status

- Task 1 / RR-01: fix round 1/5 (1 addressed, 0 open — focused route tests now complete; commits 50dab32..c3e5f79).
- Task 1 / RR-01: complete (commits 7a37012..c3e5f79, review clean).
- Task 2 / RR-02: complete (commits 6126178..f49dde9, final code/QA/architecture/security reviews clean; 15/15 focused tests and signed Debug build verified).
- Task 3 / RR-03: fix round 2 implemented (commits `6b7262c`, `fa8eea0`, `abb92ef`, `6cbfcb4`); the residual store-queue deadline contract is addressed under a direct RED→GREEN cycle; exact-package combined proof green at 24/24; pending scoped code/QA re-review, then architecture/security review before acceptance.
- Task 4 / RR-04: fix round 1 implemented (`af5dd0a`); the first-phase request is now app-owned Needs Review state, only a typed bridge command can create the phase, bookmarks fail closed with balanced injected scope access, cross-project root ownership is rejected, and editable exclusions reconcile at finish. Focused Onboarding + Store proof: 19/19; signed Debug build and strict signature verification passed. Pending fresh independent code, QA, architecture, and security/privacy review; RR-04 remains unaccepted.
- Task 4 / RR-04: fix round 2 implemented (`f545034`); denied security-scoped access now throws an actionable bookmark authorization error before the body runs, with no stop after a failed start. A focused injected non-stale bookmark test proves no discovery or persisted root authorization. Focused Onboarding + Store proof: 20/20; signed Debug build and strict signature verification passed. RR-04 remains unaccepted pending fresh independent review.
- Tasks 4–10: pending dependency release; RR-04 remains closed until the RR-03 release gate accepts the complete slice.
