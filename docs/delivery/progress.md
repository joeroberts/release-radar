# Release Radar delivery state

## Current outcome

Phase 3 product delivery is merged: C8 documentation freshness and maintenance,
C9 bounded evidence preview and identity/lifecycle handling, and their associated
C12 health and same-folder recovery. Phase 3 documentation closeout is the active
remaining task; its independent documentation review and owner-approved merge
are pending. Phase 4 is not authorized.

The scope remains slice 3 of the
[full-product plan](plans/2026-09-06-full-product-architecture-and-delivery-plan.md),
including reported failures [#18](https://github.com/joeroberts/release-radar/issues/18)
and [#19](https://github.com/joeroberts/release-radar/issues/19).
Management and recovery C4–C7 remains complete through PRs #28–#32. The narrow
C8 regular-`.DS_Store` validator repair remains complete and is not reopened.

## Delivered behavior and verification

- **Phase 3A:** shared registration/root/binding-scoped observation supplies
  Overview, evidence and documentation health. External monitoring and activation
  invalidate stale success; watching never repairs, accepts a catalog or mutates
  delivery state. Direct exact-folder recovery preserves identities and the
  accepted catalog while exposing remaining validation problems.
  [PR #33](https://github.com/joeroberts/release-radar/pull/33) merged at
  `7c4511dbab2762111d1b287efbceb148843dcccd` after owner approval.
  [Verification](evidence/2026-09-07-phase3a-documentation-freshness.md) records
  94 focused passes and 2 intentional native-only skips, then 7 affected
  race-correction passes and 1 intentional skip. Independent review closed the
  retired-store renewal and stale-projection races. The final owner-assisted
  signed native run passed with real Space input and exact synthetic folder
  selection: stale bookmark 1→0, exactly one restore audit, identities and
  catalog preserved. Focus was established by the test; this is not proof of
  Tab navigation. No broad filesystem exception was used.
- **Phase 3B:** transient bounded UTF-8 text and raster previews retain managed
  repository/artifact identity, lifecycle and authority. Legacy paths remain
  distinct and readable only within existing same-project primary/worktree
  grants. Limits and failure states are explicit; reads are bounded and
  no-follow. Preview success is withdrawn on observation/selection/identity
  changes, including live maintenance updates without Reload. Recovery routes
  distinguish primary access, saved worktrees and outside-root legacy paths.
  [PR #34](https://github.com/joeroberts/release-radar/pull/34) merged at
  `92027e1a129c4ae0ce9fa99caa0e58783ab7f88b` after owner approval of reviewed
  candidate `977656391fdd54ac02f278e0d71a39a023ad602f`.
  [Verification](evidence/2026-09-08-phase3b-evidence-preview.md) records
  75 passed, 2 unchanged native-picker skips and 0 failed. Direct result readback
  confirmed native Preview activation in Overview, ticket detail and maintenance,
  recovery/refresh/retry, and automatic withdrawal of rendered stale bytes.
  Independent Sol High review closed all four Required findings on the final
  candidate; no Required findings remain. Compact/wide captures are retained.

The completed [3A brief](task-briefs/2026-09-07-phase3a-freshness/phase3a-freshness-brief.md)
and [3B brief](task-briefs/2026-09-07-phase3b-evidence/phase3b-evidence-brief.md)
retain the delivered acceptance scope. Test results establish their named scopes,
not a passing whole suite or an installed-owner-app acceptance run. This closeout
changes documentation only; it does not transfer test results to a new binary.

## Authorization and ownership

The owner authorized Phase 3 source, tests, documentation, scoped commits, pushes,
PR creation and separate delivery/review tasks. PR #33 and PR #34 have explicit
merge approval and are merged. The documentation closeout merge needs its own
owner approval. Orchestrator `01a07e75-b254-72a1-be2a-3e97ac23baeb` owns this
ledger/catalog integration on `codex/phase3-documentation-evidence` in `f703`.
Completed Phase 3 writers, independent reviewer tasks and architecture assessment
are archived after results were preserved and completion read back. Requested
models/efforts and correction history are in the
[Historical record](archive/2026-09-08-phase3-delivery-history.md); actual runtime
settings were not exposed for independent confirmation.

No installation, owner-project data operation, application binding/catalog
acceptance, external service/notification or plugin mutation, credential repair,
entitlement change or cleanup is authorized. SQLite remains exclusively app-owned.
Phase 4, RDS appearance changes and light/dark feature work remain excluded.

## Material limitations and retained history

The last authorized canonical application inventory reported `bindingMissing`
and `isComplete:false` for `project-fffdc0e0b15b9b86`. No new application readback
or catalog acceptance is authorized. Repository documentation validation does not
claim application synchronization or repair that binding.

Earlier C7 launch/credential incidents remain unresolved as to owner-state effects:
a normal app launch may have initialized default services, and a test-runner help
command exposed Jira/Pushover credentials in a writer transcript. The owner was
informed; no secret values are recorded here and no repair or rotation was performed.
See [C7 evidence](evidence/2026-09-07-c7-backup-reset-recovery.md).
During the initial Phase 3A review, a reviewer initiated an unauthorized prompt-only
external security scan/preflight; external calls stopped, with no further mutation
or cancellation performed. Subsequent correction reviews remained local.

Some historical Phase 3A raw bundles disappeared with earlier worktree archival;
committed evidence and screenshots remain. Final Phase 3B raw results are cited
under `/tmp/release-radar-phase3b-*`; temporary builds, exports and synthetic
fixtures were retained, with no cleanup. Their deletion requires exact owner
authorization. Canonical checkout and unrelated files remain preserved.

[Historical Phase 3 record](archive/2026-09-08-phase3-delivery-history.md) and
[Historical C7 record](archive/2026-09-07-c7-delivery-history.md) retain closed coordination,
prior checks and temporary-output reports. Current next work is documentation
closeout review and its owner-approved merge; no later product slice is opened.
