# Release Radar delivery state

## Current outcome

Phase 6 is merged through the actual default branch at
`5e7b9b86e55cd8aed192fb116bbe0bcae9bea66a`. The delivered scope follows the
[Phase 6 controlling plan](plans/2026-09-10-phase6-outcomes-tasks-history.md):
History and attention, distinct Delivery and Execution Goals, revision-bound
evidence, generic task adoption, workspace Search, saved views, and shared Help.

| Slice | Merged endpoint | Canonical evidence |
| --- | --- | --- |
| 6A History | [PR #44](https://github.com/joeroberts/release-radar/pull/44), merge `4f917b0c76fa74ebf4e0f4615cbf7e7dd4ac8597` | [6A evidence](evidence/2026-09-10-phase6a-history.md) |
| 6B Goals | [PR #45](https://github.com/joeroberts/release-radar/pull/45), merge `1e03d9ad8a36c7c7ec80525233df6a5e7c3217e8` | [6B evidence](evidence/2026-09-10-phase6b-goals.md) |
| 6C Evidence | [PR #46](https://github.com/joeroberts/release-radar/pull/46), merge `fbb0ab5da811ad0db51f1441492aa8c5531e3ce3` | [6C evidence](evidence/2026-09-10-phase6c-evidence.md) |
| 6D Adoption | [PR #47](https://github.com/joeroberts/release-radar/pull/47), merge `f0c9e42af4a5eb19d739979e7dfa33239a8e4a3a` | [6D evidence](evidence/2026-09-10-phase6d-adoption.md) |
| 6E Search and Help | [PR #48](https://github.com/joeroberts/release-radar/pull/48), merge `5e7b9b86e55cd8aed192fb116bbe0bcae9bea66a` | [6E evidence](evidence/2026-09-10-phase6e-search.md) |

The [Historical Phase 6 record](archive/2026-09-11-phase6-delivery-history.md)
preserves closed checkpoints, review history, and earlier task identities.

## Owner acceptance candidate

The prior `dist/ReleaseRadar-0.1.7-fb2ff3b.dmg` is stale: its embedded 0.1.7 app
was signed September 7 and predates the September 8–11 delivery range. A fresh
side-by-side owner candidate was built from the clean Phase 6 merged baseline:

- DMG: `dist/ReleaseRadar-0.1.9-5e7b9b8.dmg`
- Version/build: `0.1.9 (1)`
- DMG SHA-256: `49aafc6ea49caff78539858ecabdca056188168d1a30580df34f647b23919454`
- Main executable SHA-256: `721f86100acb5c7521f3f0275d9a9f82c13e2670f09cd5c7ab69db07928b537a`
- CodeDirectory hash: `3239875711bc9957418f8c322f5d27cd904fafd7`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The DMG verifies, mounts read-only, contains `ReleaseRadar.app` and an
`Applications` link, and its mounted app passes strict deep signature validation.
The mounted executable and CodeResources are byte-identical to the verified build
candidate. The build is not notarized, so it is an owner-only local acceptance
artifact rather than a generally distributable release.

The [owner acceptance guide](evidence/2026-09-11-phase6-owner-acceptance-guide.md)
covers the complete merged range from Phase 3A/3B through Phase 6E, including
install/migration preparation, a quick read-only pass, disposable-project mutation
checks, optional destructive checks, and bug-report evidence.

Packaging verification is green, but product acceptance is not. A focused
Phase 4–6 contract run executed 197 tests: 192 passed and 5 failed. Three failures
reproduced individually. One is a material planning-policy regression: canonically
equivalent but byte-distinct Delivery Goal IDs are both reported incomplete during
proposal finalization and successor transfers, contrary to the established
byte-exact identity contract. Two are stale migration fixtures that lower a
schema-26 store's version without removing newer evidence tables. The remaining
two are no-follow harness failures caused by XCTest resolving its temporary root
through the macOS `/var` symlink. Signed plugin lifecycle transport tests passed
14 of 14; the signed agent-bridge aggregate remains non-green because of stale
tool-count/schema expectations, isolated-broker setup requirements, and one
callback that reaches the newly enforced plan-incomplete behavior.

## Authorization, limitations, and next work

The current authorized endpoint is a local owner-acceptance branch, verified DMG,
manual acceptance guide, repository records, and a scoped local commit. No push,
PR, merge, installation, app launch, owner SQLite access, external publication, or
cleanup is authorized for this acceptance task.

Application inventory, catalog binding/acceptance, and managed readback remain
unauthorized. The last recorded inventory was `bindingMissing`, `isComplete:false`
for `project-fffdc0e0b15b9b86`; local documentation checks do not establish managed
application synchronization. Owner acceptance has not yet been performed, and the
0.1.9 candidate must not be recorded as accepted while the byte-exact identity
regression remains unresolved. It may be used for bounded manual diagnosis after
the backup precautions in the guide.

Phase 7 planning is independently approved at
`a0f22d965395248be6ec5928d2932d3a7ce5166d`, but Phase 7 implementation is not
authorized and remains paused. The next eligible engineering action is an
explicitly authorized bounded correction of the byte-exact planning regression
and stale automated test fixtures/expectations, followed by focused retesting and
a rebuilt candidate. Owner manual diagnosis may proceed in parallel, but normal
upgrade/acceptance should wait. Phase 7 requires separate explicit authorization.

The release staging bundle and repository `DerivedData` remain temporary build
outputs. Earlier per-slice temporary diagnostics listed in the historical Phase 6
record also remain. No cleanup was performed; any cleanup requires explicit owner
authorization.
