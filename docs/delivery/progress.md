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

## Phase 6 extension design review — September 12

The owner requests separate feature-architecture, chief-architecture and UX reviews
of the [toolbar and project-management proposal](../design/phase6-workspace-toolbar-proposal.md)
and its linked static mockup. Requirements include persistent search/navigation,
RDS reuse, Manage Project relocation, guided shared-execution setup and metric
alignment. These are required Phase 6 scope, not implementation authorization.
Metric implementation was explicitly stopped and remains stopped. The proposal
preserves the owner's 6F/6G/6H assignments and flags the earlier guided-setup naming
for reconciliation. No app state or catalog acceptance is changed by this review.

All three reviews and their requested options have concluded. The owner accepted
the wide and corrected compact mockups as visual references and selected toolbar
search with results-page filters/saved queries, the compact icon sidebar with
direct Help/Settings/Notifications and bookmark Save, immediate Manage Project
loading with in-place recovery, and Codex-task-mediated guided setup. The proposal
records those selections. RDS API details and the guided-setup slice label remain
proposed; product implementation has not been released.

The separate RekonUI Library versioning/toolbar prerequisite has now passed its
independent review with no remaining findings. Its plan is recorded on
`codex/rds-versioning-toolbar-plan` in
`docs/delivery/plans/2026-09-12-rds-versioning-toolbar-plan.md`; RDS closeout commit
`09dd3a8` records the final disposition and passing canonical documentation check.
The existing missing historical catalog artifact was restored unchanged. Both
bounded RDS planning/review tasks are stopped and archived; monitoring is paused.
The owner subsequently approved RDS toolbar/search implementation. The fresh
RekonUI Library task “Implement reusable RDS toolbar and search controls” is active
from the reviewed baseline, with package/native-window verification and independent
review required. Monitoring now follows that implementation. Historical tag creation
and Release Radar consumer adoption remain separate actions. No tags or consumer
adoption occurred.

## Pursuit plan reconstruction — design only

The owner approved the [one-time reconstruction decisions and entry reference](../design/repository-plan-reconstruction-design.md)
and delegated durable persistence, review and sequencing to Master Delivery Thread.
The package is recorded with its approved mockup and catalog identities; independent
architecture/security-recovery/UX design review is pending. Implementation follows
the final currently planned Phase 6 extension through 6H, not merged 6E. The
separately proposed guided-setup 6I label is not an added dependency by inference.
Reconstruction uses only a supported versioned structured snapshot, preserves
explicit current lanes, and never fabricates historical activity. Atomic approved
application remains provisional on a usable blocker-resolution/exclusion journey.
No implementation, live recovery, database write, installation or publication is
authorized. Source schema and exact execution/recovery contracts remain to resolve
before implementation; no current snapshot is declared import-ready.

## Release 0.1.11 package details

The reviewed RDS treatment for the main Search input, saved-query name input and
Help search input is packaged as Release Radar `0.1.11 (1)`. Version/source commit
`fbf93e515a5dac4d35c54f463dee3692d7486de8` adds the matching app and bundled
plugin versions and exact recognized plugin digest on branch
`codex/release-0.1.11`. The annotated local tag `v0.1.11` identifies the containing
release commit.

- DMG: `dist/ReleaseRadar-0.1.11.dmg`
- Durable owner copy: `/Users/jroberts/Downloads/ReleaseRadar-0.1.11.dmg`
- DMG SHA-256: `06891ba3fdfc3730bcb3348c45255c474b53cac348f68ceedfbb03c16adb62f2`
- Main executable SHA-256: `a093bbdccff161ecbbc46d74adbb3b518e8ad45233288e8bc0271f63a6a9ab9a`
- CodeResources SHA-256: `dee39d94d9ba1e0ccd7a4f6181dd0d29099fa9d44acd23aa68af7cb1e41da7bf`
- CodeDirectory hash: `85cef76aef01baae60d9b1e1a5606b1943c5ec00`
- Plugin digest: `2677797fd17f0091821cca09653f9951ab9007ef578a1226458faf632d319a9d`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The [0.1.11 packaging evidence](evidence/2026-09-12-release-0.1.11-packaging.md)
records the previously completed 12/12 correction checks and independent code-and-UX
approval, focused version/resource verification, strict signed staging, read-only
DMG mounting, staged/mounted identity and the matching Downloads copy. The installed
app and helper process identities were preserved. The package is not notarized or
generally distributable, and no installation, app launch, helper/plugin action,
owner-state access, push, PR, merge or publication occurred.

## Active navigation responsiveness correction

The owner authorized a bounded correction for project-navigation clicks that
appeared inert while Release Radar awaited the dashboard-open audit and a full
documentation observation. The local `codex/navigation-responsive-validation`
candidate is based on the verified Phase 8 documentation baseline
`c2962d9374306a7db0a36985aba1a681fd48177c`; source and tests are committed at
`43b4617`, with the navigation-specific failure-state correction at `140487d`.

Overview, Project Plan and Phase Board now publish their selected route, focus and
history entry before awaiting the existing audit and read-only documentation
validation. Validation still withdraws stale evidence while checking, so existing
evidence-dependent action guards remain fail-closed. Rapid navigation retains the
latest requested destination, and a dashboard-open failure appears in an
actionable inline banner without replacing that destination. The project sidebar
shows a native animated progress indicator with accessible **Checking project
documentation** text while validation is pending. No polling interval, persistence
schema, data-loading architecture, authorization rule or external integration was
changed.

Direct verification currently passes 62 tests with 2 signed native-picker tests
skipped and no failures across navigation history, documentation observation,
native wide/compact rendering, Help and the first-dashboard-open notification
boundary. The new status was visually inspected at 280- and 86-point widths
against the approved Phase Board sidebar language. Independent reviewer task
`01a0937b-4d46-7c30-8292-663c1e5de0bc` approved the exact candidate through
`1da1427b336ca2c89f18c7f155da6aeef6fe9703` with no Required or Optional
findings; its independent focused selection passed 7 of 7 tests. The bounded local
implementation and review endpoint is complete. The later package authorization
covered the scoped 0.1.10 version metadata, signed local DMG, release evidence,
local commits and annotated local version tag only.

The installed `0.1.10` build now has bounded owner manual acceptance for the
reported responsiveness defect. The owner's screenshot showed Pursuit Overview
loaded with documentation and catalog status current; the owner confirmed that
Overview, Project Plan, Phase Board, and the Pursuit project-card route to Overview
all opened promptly, and that the loading animation appeared while validation ran.
Rapid switching and latest-destination retention, fault injection, the complete
Phase 6 owner guide, and the Phase 8 stale-helper scenario were not explicitly
confirmed and remain outstanding.

The Phase 8 stale production-helper acceptance scenario remains deferred and
unchanged.

## Release 0.1.10 package candidate

The reviewed responsive-navigation and loading-animation correction is packaged
as Release Radar `0.1.10 (1)`. Version/source commit
`130e90846cd59ed3a181cf3665bbd27cd50d03cd` adds the matching app and bundled
plugin versions and the exact recognized plugin digest while preserving earlier
recognized identities. The annotated local tag `v0.1.10` identifies the containing
release commit.

- DMG: `dist/ReleaseRadar-0.1.10.dmg`
- Durable owner copy: `/Users/jroberts/Downloads/ReleaseRadar-0.1.10.dmg`
- DMG SHA-256: `a28ee8e47c92fc7256f274448ffc3083a442a09b8eee4a70c89e06ed67d4617b`
- Main executable SHA-256: `1493df3303c00e78ae9affb8aef44e9d2d7cf705a09034a2c2530a342396057e`
- CodeResources SHA-256: `e246a98214fc7f60eb04cf93c05249e5f8ba14ed3188648b3e72e30fafdca606`
- CodeDirectory hash: `d6c7a7dbbfa4fef6934cb8709f2b7e2f38581619`
- Plugin digest: `7f70bcd7a4fac4fe038dc00945b8fb56d3cdd472ec7f7816c40812631107939c`
- Signature: Apple Development team `2UA854NLX4`, Hardened Runtime enabled

The [0.1.10 packaging evidence](evidence/2026-09-11-release-0.1.10-packaging.md)
records focused version tests, strict nested-code and entitlement checks, read-only
DMG mounting, staged/mounted identity and the matching Downloads copy. Under later
explicit owner authorization, the verified Downloads DMG was installed in place.
The prior `0.1.9 (1)` application remains available at
`/Users/jroberts/Documents/Release Radar Backups/Pre-0.1.10-2026-09-11.ReleaseRadarAppOnly.V5Ojxa/ReleaseRadar.app`.
The installed application is now `0.1.10 (1)`, matches the package's signed
executable, `CodeResources`, and CodeDirectory identity, and reopened the existing
Pursuit workspace. Normal startup replaced both service processes with executables
from the new `/Applications/ReleaseRadar.app` and reported the Codex plugin as
**Installed** at `0.1.10`; no manual plugin or helper action was used. The local tag
remains on the original release commit. This package is not notarized or generally
distributable. Full manual acceptance and the Phase 8 stale production-helper
scenario remain outstanding.

## Earlier owner acceptance candidate

The earlier owner candidate includes the merged Phase 6 baseline plus the
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

Owner-authorized task `01a092d8-9831-76c0-ba7c-c899f195bee5` built and verified
`dist/ReleaseRadar-0.1.9-a60b1fd.dmg` from reviewed closeout `07d8f877` (product
source `a60b1fd`) and committed the package at
`69f939563f2e4044b00b91a0c1c22424aecb84a8`. The locally signed
0.1.9 (1) bundle passed strict nested-code, Hardened Runtime, entitlement, DMG,
mounted-identity and installed-identity checks. The previously installed `acc7401`
app and the earlier 0.1.7 app remain preserved in separate rollback directories.

The stale 0.1.7 helper PID `48996` survived application replacement, but existing
startup recovery replaced it from the newly installed app before the Settings
action was activated. The task did not manufacture the stale condition. One
**Restart helper** activation then exposed the in-progress accessibility state,
replaced current helper PID `67535` with PID `67987` executing from
`/Applications/ReleaseRadar.app`, and finished with the success message and enabled
actions. Plugin inventory and bytes remained unchanged and Pursuit remained
visible. Final status is honestly **Modified**, not **Installed**, because the
installed bytes differ from the last managed receipt. The
[signed installation evidence](evidence/2026-09-11-restart-helper-signed-installation.md)
records the result and limitation.

A later owner-supplied Settings screenshot shows plugin version `0.1.9` as
**Installed**. It is recorded as a later observation without inferring which
intervening action changed the earlier **Modified** state.

An attempted isolated process harness on `codex/restart-helper-dmg-live-test` used
an alternate launchd/Mach service, custom adapter, ad hoc unsandboxed helpers and a
sentinel exit. Independent review rejected it as evidence because it did not
exercise production `SMAppService` unregister/register and duplicated explicitly
rejected test machinery. The harness and its production-source seams were
withdrawn. Existing tests continue to cover asynchronous service ordering, exact
stale-to-clean receipt restoration and AppModel presentation; the installed check
covers the actual button and production service with an already-current helper.
The exact stale production `SMAppService` plus installed Settings button combination
remains unexercised.

## Authorization, limitations, and next work

The authorized Restart helper package, installation, and bounded live-check endpoint
is complete. No push, PR, merge, plugin installation/removal, owner SQLite access,
unrelated application mutation, external publication, notarization, Phase 7 work,
or cleanup was authorized or performed.

Application inventory, catalog binding/acceptance, and managed readback remain
unauthorized. The last recorded inventory was `bindingMissing`, `isComplete:false`
for `project-fffdc0e0b15b9b86`; local documentation checks do not establish managed
application synchronization. Full owner manual acceptance remains outstanding.

Phase 7 planning is independently approved at
`a0f22d965395248be6ec5928d2932d3a7ce5166d`. Phase 7 implementation remains paused
and requires separate explicit authorization. The next eligible owner work remains
the broader manual acceptance guide.

The owner explicitly deferred the stale production-helper acceptance scenario to
[Phase 8 production packaging and release readiness](plans/2026-09-06-full-product-architecture-and-delivery-plan.md#phase-8-deferred-stale-helper-acceptance--owner-decision-2026-09-11).
It remains outstanding rather than passed and does not block current manual
acceptance or Phase 7. Before broader distribution, Phase 8 must verify the real
fixed `SMAppService` stale-helper upgrade handoff through the installed Settings
button, including awaited old-process termination, current installed-helper
identity, fresh exact-identity plugin/receipt status, unchanged plugin/project data
and actionable failures. The [signed installation evidence](evidence/2026-09-11-restart-helper-signed-installation.md#remaining-stale-helper-gap)
retains the accepted evidence and precise limitation.

A faithful isolated stale-helper check would require a separately provisioned,
logged-in macOS account or VM with its own GUI launchd domain, Codex home, Release
Radar store and installed signed app versions. None was created or configured.
This account's fixed service label and Mach service are occupied by the owner's live
helper, so manufacturing the precondition here would alter the working service and
owner state beyond the authorization granted. Provisioning that environment remains
separate future work and is not currently authorized.

Any future DMG containing changes after the recorded 0.1.10 package must use a
strictly newer semantic version with matching application, bundled plugin and DMG
versions. The current authorization does not extend to another package.

The release staging bundle and repository `DerivedData` remain temporary build
outputs. Earlier per-slice temporary diagnostics listed in the historical Phase 6
record also remain. No cleanup was performed; any cleanup requires explicit owner
authorization.
