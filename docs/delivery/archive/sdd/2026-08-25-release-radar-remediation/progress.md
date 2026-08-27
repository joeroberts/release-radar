# SDD ledger — plan: docs/superpowers/plans/2026-08-25-release-radar-remediation.md

Baseline: `575d62cc6160fc9ed65e944bbe667ee6bbf79d27`

## Preflight conflict table

| Task | Shared files / semantic overlap | Serialization decision |
| --- | --- | --- |
| RR-R1 | Onboarding service and Projects sheet | First writer; no concurrent edits. |
| RR-R2 | Onboarding service, AppModel, Needs Review | Runs after RR-R1 writer completes; preserve RR-R1 interfaces. |
| RR-R3 | StoreMigrations, bridge, projections, notifications | Runs after RR-R2 writer; ADR amendment precedes code. |
| RR-R4 | StoreMigrations, AppModel, notifications/settings | Runs after RR-R3 because v9 follows v8 and notification semantics overlap. |
| RR-R5 | Dependency/board views and projection tests | Separate UI subsystem, still serialized to keep one writer. |
| RR-R6 | Asset catalog and project build settings | Separate packaging subsystem, serialized last by owner priority. |

Each implementer owns one bounded task and its focused tests. Reviewers do not edit implementation files. No implementer reviews or verifies its own completed task.

## Status

- Plan review: Planning complete; Architecture GO; QA GO; TPM GO; Delivery Manager GO.
- Current task: RR-R1 through RR-R6 are accepted with all Required findings closed; the bounded remediation milestone is complete in the current uncommitted working diff.
- Gated decision: structure-less onboarding requires later owner choice; it does not block RR-R1 through RR-R6.

## RR-R1

- Implementer: completed focused RED/GREEN; no commit.
- Controller: 11/11 `OnboardingAcceptanceTests` passed from `/tmp/release-radar-rr-r1-controller`; pre-existing compiler/signing warnings only.
- Code review: ACCEPT after one Required fix removed the inert Cancel from inline empty-project onboarding.
- QA: ACCEPT in isolated bundle `com.rekonlabs.ReleaseRadar.RR1QA`; sheet Cancel/Escape, clean reopen, and Open Existing routing verified live; no owner folder/database touched.
- Architecture: APPROVED; no ADR.
- Security/privacy: PASS; Cancel is no-write, stale-bookmark fail-closed behavior remains, and Open Existing preserves the existing bounded first-dashboard-open audit without changing delivery state.
- Gate: Accepted. Delivery Manager GO recorded durably; TPM GO released RR-R2 as the next serialized writer.

## RR-R2

- Preimplementation: Architect recorded the bookmark/recovery contract in ADR-001; Security/Privacy GO with Required 0; TPM and Delivery Manager released the slice.
- Implementation: original implementer completed 36 focused cases but violated runtime isolation by launching the normal owner bundle; identified fixture mutations were reversed, key counts/integrity match the prior baseline, but the database file changed and unrelated-change absence is not provable. That runtime evidence is invalid and the incident is durable in `docs/delivery/progress.md`.
- Review fix round 1: fresh `/root/rr_r2_fix1` closed project-state leakage and post-commit refresh false-failure/duplicate-retry findings without launching an app or touching a container.
- Controller: 38/38 focused tests passed at `/tmp/release-radar-rr-r2-controller`; existing warnings only.
- Code review: ACCEPT, Required 0.
- QA: ACCEPT; isolated live bundle `com.rekonlabs.ReleaseRadar.RR2QA` verified fail-closed recovery and explicit retry, and fresh current-source 38/38 rerun passed without owner-container access.
- Architecture: APPROVED against ADR-001.
- Security/privacy: PASS, Required 0; invalid original runtime remains excluded.
- Gate: Accepted. Delivery Manager GO and TPM GO recorded; RR-R3 released as the next serialized writer.

## RR-R3

- Preimplementation: Architect recorded exact one-to-one ticket/goal identity in ADR-001; Security/Privacy GO after adding project-local goal uniqueness and shared-goal ambiguity rejection; TPM/Delivery Manager released the slice.
- Implementation: schema v8 persists one exact `(project, ticket, thread, goal)` relationship with composite integrity and project-local ticket/goal uniqueness; ambiguity-safe backfill leaves uncertain legacy records unlinked; the typed bridge command and ticket detail, Activity, and blocked-notification projections consume only the approved identity; fresh seed outcomes are descriptive without rewriting persisted owner outcomes.
- Required fix round 1: independent review found that an existing link ID could be reassigned to a different valid ticket. A fresh fixer made link identity stable by requiring an existing ID to retain its original project and ticket while preserving same-ticket goal updates. The compact regression observed RED then GREEN and proves rejected reassignment leaves link, audit, and replay state unchanged.
- Controller: 71/71 Store, Agent Bridge, Dashboard Projection, Notification, and End-to-End acceptance cases passed at `/tmp/release-radar-rr-r3-controller`; configured Debug build and diff check passed with only existing warnings.
- Code review: ACCEPT, Required 0; stable-link finding closed.
- QA: ACCEPT, Required 0; current-source 71/71 passed. Alternate isolated bundle `com.rekonlabs.ReleaseRadar.RR3QA` verified descriptive outcomes, exact goal identity in detail/Activity/Notifications, and truthful unlinked state; owner data was untouched.
- Architecture: APPROVED against the RR-R3 ADR contract; Required 0.
- Security/privacy: PASS, Required 0; invalid identity and reassignment writes fail transactionally, and owner-authored outcomes remain unchanged.
- TPM: GO, Required blockers 0.
- Gate: Accepted. Delivery Manager GO recorded durably; RR-R4 is dependency-safe.

## RR-R4

- Preimplementation: corrected test-first brief at `task-4-brief.md` limits work to four persisted local alert-rule controls, exhaustive six-event suppression mapping, reciprocal blocked/paused occurrence lifecycle, authoritative Settings state, exact owner audit semantics, and isolated failure/relaunch verification.
- Planning: GO.
- Architecture: GO, Required 0; additive v9 and app-owned notification/settings boundaries approved.
- QA: GO, Required 0; defaults/reopen, all event mappings, suppression boundaries, delivery/audit preservation, lifecycle transitions, UI failure/relaunch/accessibility, and alternate-bundle runtime evidence are covered proportionally.
- Security/privacy: GO, Required 0; local non-secret owner settings only, exact unscoped audit on actual change, no bridge mutation, and no notification artifacts when disabled.
- TPM: GO, Required blockers 0.
- Implementation: additive schema v9 owns the exact constrained four-rule set with defaults on/on/on/off for blocked linked goals, completion/review, Needs Review, and paused goals. The exhaustive six-event mapping suppresses notification occurrence/event/attempt/Activity writes before creation while retaining the underlying delivery mutation and audit; actual owner changes alone create the exact bounded unscoped audit. Reciprocal blocked/paused state remains authoritative even when either alert is disabled.
- TDD/controller: initial missing-contract RED, then 57/57 Store, Notification, and App Route GREEN. Independent review found one Required retroactive-alert defect: enabling after a disabled stable entry could alert without a new transition. A fresh fix moved producer calls behind genuine creation/entry checks while preserving unconditional delivery mutation, audit, and exit deactivation; focused RED then GREEN passed 3/3, preservation passed 71/71, and fresh current-source affected verification passed 85/85 with zero failures/skips.
- QA: ACCEPT, Required 0. Computer Use verified all four accessibility values, persisted toggle state over relaunch, serialized in-flight disabling, and recoverable update failure without UI drift in alternate bundle `com.rekonlabs.ReleaseRadar.RR4QA` at `/tmp/release-radar-rr-r4-qa-build.sL7zrK/Build/Products/Debug/ReleaseRadar.app`. Final capture: `/tmp/release-radar-rr-r4-qa-settings-final.png`.
- Reviews: Code Reviewer ACCEPT, Required 0; Architect APPROVED, Required 0/no ADR; Security/privacy PASS, Required 0; TPM GO, Required blockers 0. The retroactive-alert finding is closed without bridge, credential, provider, or settings-authority expansion.
- Isolation: no normal owner-bundle launch or owner-data access occurred during implementation, controller verification, remediation, or live QA. The earlier RR-R2 incident and residual uncertainty remain unchanged in the durable delivery ledger.
- Gate: Accepted. Delivery Manager GO; RR-R5 may enter planning and independent plan review only. RR-R5 implementation and RR-R6 remain closed.

## RR-R5 planning/review gate

- Status: Preimplementation gate accepted; implementation GO to one fresh serialized Implementer.
- Brief: `task-5-brief.md` is the accepted granular test-first contract. Planning and Delivery Management inspected `dependencies.png` and `phase_board.png` directly at 1586 x 992 and accepted the mockup-derived selected-path hierarchy, phase count/legend, four columns/connectors, selected and non-color-only blocking treatments, right-side inspector, five-lane board, and explicit `Full outcomes` / `Compact density` control.
- Responsive matrix: 1586 x 992 wide with a 220-point sidebar and right inspector; 900 x 650 compact with a stacked inspector, retained full selected path, five recoverable lanes, and truthful width-forced compact cards at lane width <= 180; 760 x 520 minimum with keyboard/scroll recovery and an extra capture only if behavior differs from compact. The accessibility checklist requires semantic node/relationship equivalents, complete compact-card outcome labels, and disclosure of the temporary width override.
- Planning: GO.
- Architecture: GO, Required 0; existing read-only dependency projection and view-local density boundaries remain unchanged.
- QA/test: GO, Required 0; the two focused regressions, exact visual sizes, accessibility/keyboard checks, no-path/narrow recovery, alternate-bundle live evidence, and no-write check are sufficient and proportional.
- TPM: GO, Required blockers 0; RR-R4 is accepted and this remains the sole serialized writer.
- Security/privacy: separate preimplementation review not required because the accepted scope is presentation-only over existing in-memory projections and local view state, with no persistence, bridge, bookmark, notification, credential, permission, or owner-data access. Any expansion into those boundaries returns the task to NO-GO and requires Security/Privacy review.
- Delivery Manager: GO. Release RR-R5 to one fresh Implementer only; no normal owner-bundle launch or owner-data access, no concurrent writer, and no persistence, graph mutation, screenshot-test infrastructure, or automatic delivery transition. Independent Code Review, QA visual/responsive/accessibility verification, Architecture, TPM, and Delivery Management remain required for acceptance. RR-R6 remains closed.

## RR-R5 implementation and final gate

- Implementation: the Dependencies surface now renders the selected ticket's deterministic four-column prerequisite/unlock path and responsive inspector; Phase Board owns exact view-local `Full outcomes` and `Compact density` choices with a truthful lane-width override and automatic restoration after widening. No persistence, audit, notification, bridge, permission, credential, projection, graph mutation, or owner-data behavior changed.
- TDD/controller: initial missing-contract RED, then 20/20 focused Review/Graph and Dashboard Projection GREEN. After the Required fix, fresh current-source verification passed 20/20 with zero failures/skips at `/tmp/release-radar-rr-r5-fix1-final-tests.log`; the isolated alternate build, strict codesign, and `git diff --check` passed.
- Required fix round 1: independent review found two Required defects: selected-ticket detail was clipped at 760 x 520, and the density Picker did not truthfully expose that requested full cards were compacted at narrow width. A fresh fixer added vertical board/detail recovery scrolling while retaining horizontal five-lane recovery and added the effective compact override plus restoration semantics to accessibility value/help. The regression observed RED at `/tmp/release-radar-rr-r5-fix1-red.log`, then passed in the final 20/20 run. Both findings are closed.
- Live QA: ACCEPT, Required 0, using isolated bundle `com.rekonlabs.ReleaseRadar.RR5FixQA`. Wide 1586 x 992 captures: `/tmp/release-radar-rr-r5-wide-dependencies-1586x992.jpeg`, `/tmp/release-radar-rr-r5-wide-board-full-1586x992.jpeg`, and `/tmp/release-radar-rr-r5-wide-board-compact-1586x992.jpeg`. Compact 900 x 650 captures: `/tmp/release-radar-rr-r5-dependencies-900x650.jpeg` and `/tmp/release-radar-rr-r5-fix-board-900x650.jpeg`. Minimum 760 x 520 top/detail recovery captures: `/tmp/release-radar-rr-r5-fix-board-min-top.jpeg` and `/tmp/release-radar-rr-r5-fix-board-min-detail.jpeg`. QA verified selected-path/inspector content, both density choices, the truthful forced-compact accessibility value, widening restoration, and recoverable lane/detail scrolling.
- Reviews: Code Reviewer ACCEPT, Required 0; Architecture APPROVED, Required 0/no ADR; QA ACCEPT, Required 0; TPM GO, Required blockers 0.
- Security/privacy and isolation: the approved no-separate-security-review disposition remains valid because the implementation is read-only presentation plus view-local state and creates no durable or protected-data effect. The normal owner bundle was not launched and owner application data was not accessed. The prior RR-R2 incident remains unchanged in the durable ledger.
- Gate: Delivery Manager GO. RR-R5 is accepted. RR-R6 planning and independent plan review may open; RR-R6 implementation remains closed until those gates are accepted.

## RR-R6 planning/review gate

- Status: Corrected preimplementation gate accepted; implementation GO to one fresh serialized Implementer only. RR-R5 is accepted and no concurrent writer is authorized.
- Brief and references: `task-6-brief.md` is the accepted granular artifact-first contract. The controlling icon and mockup remain byte-identical 1254 x 1254 PNGs with SHA-256 `b94fb5b029dd262cfb9e196efdf089fb3d72aee76d433ebfd448cc26691f7ddd`; `full_logo.png` remains 1968 x 799 with SHA-256 `cb7ba41ca0aeb58e7cbd1d680b4fca10d84facaaf38550a72b0f9105ed56ba78`. Any reference-hash change returns the slice to Planning/Design review.
- Exact scope: one hand-authored deterministic SVG; seven SVG-derived lossless PNGs supplying the exact ten macOS AppIcon 1x/2x rows; one `Contents.json`; explicit app-only asset-catalog/project wiring; the Debug-capture external-service predicate and two guarded dashboard startup calls; and one compact existing `AppRouteTests` regression. No wordmark, reference-raster bundling, new dependency/export script, generalized capture or collaborator infrastructure, persistence/audit, bridge/folder behavior, packaging, or unrelated product change is authorized.
- Resource-wiring contract: add the unused file/build IDs `A10000000000000000000018` and `B10000000000000000000007`, exclude `Assets.xcassets` from implicit synchronized membership through exception set `A90000000000000000000001`, place the explicit build file only in app Resources phase `C10000000000000000000003`, and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` only in app Debug/Release configurations `A50000000000000000000053` and `A50000000000000000000054`. Core, helpers, bridge, tests, `Info.plist`, and entitlements must not gain the resource or setting.
- Artifact gate: source pixel dimensions alone are insufficient. The configured bundle must contain `CFBundleIconFile = AppIcon`, `Assets.car`, and a parseable `AppIcon.icns`; filtered `assetutil` output must contain exactly ten `Icon Image` AppIcon tuples mapping the seven source filenames across the required physical dimensions/scales, excluding the `MultiSized Image` summary. Generated raster references must not ship, and strict deep signing plus the effective identity/team/runtime/entitlements must remain unchanged.
- Debug capture privacy seam: an alternate bundle identifier does not isolate traditional Keychain items without an access group. `AppLaunchConfiguration.externalServicesSuppressed` is therefore true only for Debug plus `--rr10-capture`, defaults false, and is reused for the existing AppDelegate capture guard. `AppModel` may skip only Pushover configuration loading and pending notification dispatch when suppression is true; dashboard/store/UI loading and ordinary Debug/Release startup remain unchanged. The compact regression must prove the predicate matrix and that a queued event/attempt remains untouched. Independent live QA alone may launch a fresh alternate bundle with `--rr10-capture --rr10-empty-store`, after proving the container is new and before confirming its notification tables remain empty; no owner bundle, Keychain item, container, database, folder authorization, or delivery may be accessed.
- Planning: GO; the corrected brief is test-first, bounded, and contains explicit RED/GREEN, provenance, failure, small-size fidelity, signing, visual, and isolation evidence without a screenshot harness or new test machinery.
- Architecture: GO, Required 0; explicit app-only PBX resource wiring, filtered ten-CAR-tuple verification, and the narrow default-false capture seam preserve existing target/runtime boundaries. No ADR is required.
- QA/test: GO, Required 0; the focused launch-policy/coordinator regression, exact seven-source/ten-CAR matrix, configured bundle checks, and isolated Computer Use inspection of Finder, Dock, and About are sufficient and proportional.
- Security/privacy: GO, Required 0; Debug plus `--rr10-capture` deterministically suppresses both the remaining Pushover Keychain lookup and pending dispatch, while normal Debug/Release remain unchanged. Independent post-implementation verification of strict nested signing, effective entitlements, and owner-data non-access remains required.
- TPM: GO, Required blockers 0; RR-R5 is accepted, reference hashes and PBX tripwires were revalidated, the catalog is absent at baseline, and RR-R6 remains the sole serialized writer.
- Delivery Manager: GO. Release one fresh Implementer for only the scope above. The Implementer may run source tests and configured non-launching builds but must not launch any bundle or access owner data; live visual/privacy acceptance belongs to independent QA. Any signing, entitlement, Info.plist, bundle identity/default startup, Keychain/coordinator API, packaging, owner-data, or broader source change is a stop condition and returns RR-R6 to NO-GO. Independent Code Review, QA, Architecture, Security/Privacy, TPM, and Delivery Management remain required before final remediation acceptance.

## RR-R6 implementation and final remediation gate

- Implementation: one deterministic SVG, seven lossless SVG-derived PNGs, a ten-row macOS AppIcon catalog, and explicit app-only target/resource wiring now deliver the approved V1 production identity. The narrowly approved Debug capture predicate suppresses only Pushover configuration lookup and pending dispatch for `Debug + --rr10-capture`; normal Debug/Release and dashboard/store/UI loading remain unchanged. No source Info.plist, entitlement, persistence, bridge/folder, Keychain/notification implementation, packaging, or unrelated product behavior changed.
- Asset provenance and compiled evidence: `task-6-report.md` is the detailed evidence record. SHA-256 is SVG `83058fa6702b530f5ccd1a8851615db046aea45607c1e254cec920013e1e15fc`; PNG 16 `96f728e31ac046ad67e41b83c76e348a204cb0e78d977e5bb03fa1ba42df9303`; PNG 32 `ca1d66664a36007c512edc6001e802fc732b7ac2358c7008d945d94ea942004a`; PNG 64 `24126e45d935f4966bca80adfa7f1cbdadbf87267ae57fe585babe5f0db37c31`; PNG 128 `2465ed35531ee4e0e43e003563d4d5f8bc7e4c1489efe51920ba3ae8d88c672a`; PNG 256 `20e24cdd1a469c41d4195c1f7e83424b54950bbb001870d8661f3eefed91208c`; PNG 512 `455892a0384c1cb5b854ae2cb1ceedf16c64a171dee6b36db9581aeaa76af7c9`; PNG 1024 `fc2e48cf435a4b6015843a2770872da7033f0a3020a63e8311e408589bddaaa1`. The configured bundle contains `Assets.car`, parseable `AppIcon.icns`, compiled `CFBundleIconFile = AppIcon`, and exactly ten filtered CAR `Icon Image` tuples over those seven source files; exact tuples and PBX checks are in the report.
- Verification: focused capture-policy/coordinator tests passed 15/15 at `/tmp/release-radar-rr-r6-final-test.2YeUco/Logs/Test/Test-ReleaseRadar-2026.08.25_02-51-34--0400.xcresult`. Final current-source controller verification passed 146/146 with zero failures/skips at `/tmp/release-radar-remediation-final/Logs/Test/Test-ReleaseRadar-2026.08.25_03-05-31--0400.xcresult`. Strict nested signing and effective identity/team/runtime/sandbox/app-group/read-only-folder/network/Debug entitlements remained unchanged.
- Live QA: ACCEPT, Required 0, using only `/tmp/release-radar-rr-r6-qa-alt/Build/Products/Debug/ReleaseRadar.app`, identifier `com.rekonlabs.ReleaseRadar.RR6QA`, with fresh isolated container and empty notification state. Finder/About production-icon evidence is `/tmp/rr-r6-finder-list.png`, `/tmp/rr-r6-finder-icon-24.png`, `/tmp/rr-r6-finder-icon-64b.png`, and `/tmp/rr-r6-about.png`. Direct Dock targeting timed out; no Dock screenshot is claimed. QA/TPM classify the tooling limitation as nonblocking given the live Finder/About evidence and exact signed compiled-icon matrix, with no demonstrated Dock defect.
- Reviews: Code Reviewer ACCEPT, Required 0; QA ACCEPT, Required 0; Architecture APPROVED, Required 0/no ADR; Security/Privacy PASS, Required 0; TPM GO, Required blockers 0.
- Isolation and residuals: no normal owner-bundle launch or owner-data access occurred in RR-R6. Structure-less onboarding remains a separate explicit owner-decision/design/ADR gate. The historical RR-R2 owner-database incident remains recorded; byte-for-byte restoration and proof of no unrelated state change are unavailable.
- Gate: Delivery Manager GO. RR-R6 is accepted and the RR-R1-through-RR-R6 remediation milestone is closed in the current working diff. No commit, packaged release, Developer ID distribution, or notarization is claimed.
