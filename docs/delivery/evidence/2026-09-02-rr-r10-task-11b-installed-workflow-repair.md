# Task 11B installed-workflow repair evidence

Non-authoritative verification evidence for the owner-authorized repair after
PR #16. The [repair brief](../task-briefs/2026-08-29-delivery-goals-roadmap-readiness/task-11b-installed-workflow-repair-brief.md)
defines scope; [progress](../progress.md) records current delivery state.
Prior installation, goal operations, replay results and owner overrides remain
in the original Task 11B evidence; no prior completion/acceptance was repeated.

## Defects and direct tests

- Confirmed installed app lacked the checker and catalog reference. Source
  built the tool but omitted it from the app's Copy Helpers phase and lacked
  its installed framework runpath. Both are corrected without new dependencies.
- Confirmed live RekonUILib AGENTS.md evidence resolved successfully yet returned
  `evidenceConflict`. Inventory now returns no rejection after successful legacy
  path validation; missing managed IDs still reject before that branch.
- Fresh RED: two selected tests failed for those exact defects. Fresh GREEN:
  five tests passed, zero failures/skips: valid legacy/no mutation, missing
  managed artifact, existing aliases/missing/outside paths, packaged helper
  discovered from copied app prompt with readable help reference, and retained
  exact-root/guidance-only prompt contract.
- Native Xcode Debug test and signed Release build succeeded. Existing compiler
  warnings about optional `.none`, actor isolation and deprecated string
  construction were not expanded into unrelated maintenance work.
- Documentation write/check succeeded. Existing unaffected integration,
  rendering, goal/replay and independent evidence is reused, not rerun.

## Installed outcome

- Replaced only `/Applications/ReleaseRadar.app` after exact app/helper
  quiescence. No new backup, restore rehearsal, configuration edit or cleanup.
  Release app CDHash: `79ed0fff8e93bc5486f3c532b188e7493d99d40c`.
  Checker CDHash: `65af12dec7f18429067da995966cca96a9ff6afb`.
  Signing team `2UA854NLX4`; hardened runtime and strict deep signature checks
  passed. Main app and bridge entitlements equal the prior installed app.
  Installed signed resource manifest equals the candidate's; the app relaunched
  from `/Applications/ReleaseRadar.app/Contents/MacOS/ReleaseRadar`.
- Installed checker runs at `Contents/Helpers/ReleaseRadarDocumentationTool`.
  `--help` locates the shipped `Contents/Resources/catalog-v1.md`. The reference
  contains fields, enums, authority/lifecycle rules, safe preparation guidance
  and a usable catalog example. Copied app prompts expose actual bundle paths.
- Extracted the installed reference's example into an isolated synthetic tree.
  Installed `write` generated its index and `check` passed without source/Xcode
  dependencies. A `/tmp` symlink-root invocation correctly rejected; the exact
  canonical `/private/tmp` root succeeded. The installed checker also validates
  this repair's repository documentation.
- RekonUILib inventory is complete. Existing handoff evidence
  `release-radar-handoff:v1:5005c325-0ab1-4713-b113-290e50be7972` still uses its
  original AGENTS.md file-path locator, resolves available and has no rejection
  or inferred catalog identity. Binding/catalog digest
  `4a39d91560d2e00f3c5f8ab85d600887f499ff8dc1604e8e17415a6b3b807d9c`, roots,
  all preservation groups, 464 audits and 138 receipts were unchanged across
  installation. Neither RekonUILib nor Pursuit was edited or rebound.
- Release Radar's inventory remains complete at schema 14. All preservation
  groups, roots, bindings and 138 receipts were unchanged across installation;
  all 464 prior audits were preserved, with one background addition retained
  and not attributed to this repair. Valid AGENTS.md and source-file legacy
  evidence now resolve without conflict. The pre-existing RR-R7 evidence
  pointing at a `.app` directory still rejects as `unsafePath`; it is not a
  regular file and was not rewritten to hide that condition.
- Actual pre/post-install accessibility readback confirms RR-R10 remains
  Accepted, its card announces 16 tasks, all 16 original rows including 11B are
  checked, RR-DG-R10 is Active, and Established product roadmap stays active.
  Roadmap view remains Ready, revision 1, 11/11 covered, 0 unassigned; first
  roadmap goal is Planned. Unchanged planning preservation and prior evidence
  cover the remaining goal definitions and exact assignments.

## Review, scope and retained output

Independent source and installed-outcome review accepted: Required 0, Optional 0.
The reviewer independently inspected installed process identity, signing,
entitlements, framework linkage, reference bytes and current task/goal UI.
Terminal managed-document reconciliation follows before handoff.
No full-suite or layout matrix was repeated; issue #9 remains
deferred. No new owner task/goal/acceptance operation or direct SQLite access.

Durable deliverables are source/tests, the shipped reference, this record and
the catalogued brief/ledger in the repository, plus the installed app. Temporary
outputs retained without cleanup: task-worktree DerivedData; `/tmp/rr11b-repair-`
red/green logs and xcresults; `/tmp/rr11b-repair-release.log`; synthetic example
`/private/tmp/rr11b-catalog-example.6CxqVC`; computer-use screenshots in the
tool-managed temporary directory. Prior task output and backups remain intact.
