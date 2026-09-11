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

The current owner candidate includes the merged Phase 6 baseline plus the
independently approved acceptance corrections at
`acc740113d1e7e056b5e7f1b2e3a0e3e21f24c27`:

- DMG: `dist/ReleaseRadar-0.1.9-acc7401.dmg`
- Version/build: `0.1.9 (1)`
- Package artifact commit: `09caafe0108496297684089603aa04c0cfffe361`
- DMG SHA-256: `bfb3e769f7f5acea37aeca0573a8a53ad484795fcbe2f36c07010c8f6fe7b046`
- Main executable SHA-256: `52a4a1a8015fde064582c8768828d60907b641d09d827c15806919c2b283e428`
- CodeDirectory hash: `cf90e9252c9b56e1699041d098987b37dea340ce`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The DMG verifies and mounts read-only; its bundle and nested code pass strict
signature and entitlement checks. Mounted executable and CodeResources match the
staged app. It is locally signed, not notarized or a generally distributable release.
Earlier 0.1.7 and diagnostic 0.1.9 packages remain preserved, not current candidates.

The [owner acceptance guide](evidence/2026-09-11-phase6-owner-acceptance-guide.md)
covers the September 8–11 merged Phase 3A/3B–6E changes, backup and migration
preparation, low-risk navigation with disclosed Search preference writes,
disposable-project mutation checks, optional recovery checks and bug reporting.
Guide and signed-test closeout are committed at
`c9ca97f42d57ea6566bbc55c02f5271c09282d55`.

Under later explicit owner authorization, acceptance task
`01a091aa-e8bc-7d53-8005-dd59de3ee38b` completed an in-place installation of the
`acc7401` 0.1.9 candidate. It verified `/Applications/ReleaseRadar.app` signature,
version and executable identity against the candidate, and verified Pursuit startup
without a schema banner. The original 0.1.7 application remains preserved for
rollback. This bounded installation and startup check did not complete the full
manual acceptance guide and grants no authority for another installation, app
launch, or live helper restart.

The initial diagnostic run was 192/197. Its byte-exact goal identity regression
and fixture failures are corrected; six targeted tests and 114 affected tests pass.
Independent review approved the correction source with no Required findings.
Under subsequent explicit owner authorization for temporary signed test-service
registration, the corrected AgentBridgeTransportAcceptanceTests passed 16/16 and
CodexPluginLifecycleTransportTests passed 14/14. Post-run BridgeAgent was absent;
the pre-existing PluginLifecycleHelper retained PID 48996. Two earlier signed
Debug attempts lacked the XCTest debug entitlement and stopped before test loading;
they are not passing evidence. The normal signed Debug test host completed both
suites. Retained results and limitations are recorded in the guide.

Scoped automated correction and package verification are complete. The authorized
in-place installation and startup check are complete, while full owner manual
acceptance remains outstanding. The acceptance commits are local and unpublished.

## Restart helper recovery

The local `codex/restart-plugin-helper` candidate at
`a60b1fd2f5c56d145bcbc634fd0e3f75a8765f26` adds the Settings **Restart helper**
recovery action. It waits for asynchronous helper teardown before re-registering,
refreshes status without an install/remove/reinstall command, and restores managed
intent only after an exact clean match to the retained verified version and digest.

The author-produced focused run passed 54 of 54 tests with no failures or skips;
the app build and repository documentation check passed. Independent reviewer task
`01a092a5-95b6-7630-a9e9-8b77404f3d0f` approved the corrected candidate with no
remaining findings and is archived. Delivery-author task
`01a09295-0d2a-7cf2-a7c5-08a8bfb20d8a` completed its local closeout and is pending
archive after parent confirmation. No package, installation, or live helper
verification was performed for this newer change.

## Authorization, limitations, and next work

The current authorized endpoint for Restart helper recovery is its local branch,
repository records, focused checks, independent review, and scoped local commits.
No push, PR, merge, DMG creation, further installation, app launch, owner SQLite
access, live helper restart, external publication, or cleanup is authorized. The
owner separately authorized the completed `acc7401` in-place installation/startup
check and the earlier temporary signed test-service registration and teardown;
neither authorization carries forward to this newer change.

Application inventory, catalog binding/acceptance, and managed readback remain
unauthorized. The last recorded inventory was `bindingMissing`, `isComplete:false`
for `project-fffdc0e0b15b9b86`; local documentation checks do not establish managed
application synchronization. The installed application reflects `acc7401` and
predates the Restart helper candidate. Full owner manual acceptance remains
outstanding.

Phase 7 planning is independently approved at
`a0f22d965395248be6ec5928d2932d3a7ce5166d`. Phase 7 implementation remains paused
and requires separate explicit authorization. The next step is an owner decision
on integrating and packaging the approved local Restart helper candidate; any
further installation or manual acceptance requires separate explicit authorization.

The release staging bundle and repository `DerivedData` remain temporary build
outputs. Earlier per-slice temporary diagnostics listed in the historical Phase 6
record also remain. No cleanup was performed; any cleanup requires explicit owner
authorization.
