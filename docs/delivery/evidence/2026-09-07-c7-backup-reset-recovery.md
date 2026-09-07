# C7 backup, reset and recovery evidence

## Outcome

The C7 candidate provides a versioned full local backup package, separate preference and
tracking resets, rollback-safe restore/relaunch recovery, stale-command invalidation,
notification nonreplay, read-only plugin reconciliation and the related C12 Settings and
Application health actions. Product verification used synthetic app-owned stores and
transports and did not intentionally target an owner database, credentials, repositories,
plugin installation or notification service. Effects from the accidentally launched normal
test-built process remain unknown as recorded under Verification execution notes, so this is
not a categorical claim that owner application state was untouched during the task.

## Direct checks

The bounded verification run passed all 76 selected tests (76 passed, 0 failed, 0 skipped),
and the integrated Debug build completed successfully.

- `RecoveryAcceptanceTests`: backup inventory/integrity and symlink rejection; preference and
  tracking-reset preservation; unreadable-source restore; authority rotation; repeated restore;
  notification nonreplay; rollback; crash-marker relaunch; and fail-closed recovery singleton.
- `AgentBridgeTransportAcceptanceTests` and `NotificationAcceptanceTests`: stop-admission and
  drain behavior for admitted callback/after-reply work and an in-flight notification attempt.
- `CodexPluginLifecycleAcceptanceTests` and `CodexPluginLifecycleTransportTests`: missing receipt
  remains unknown with zero writes, and recovery status never registers or rebinds the helper.
- `StoreAcceptanceTests`: current schema migration and the historical migration suite account
  for the schema-18 recovery authority singleton.
- `ProjectDocumentationRenderingTests`: wide and compact RDS rendering, readable recovery copy,
  accessibility-visible actions and the Application health Restore Backup action.
- A Debug `ReleaseRadar` build verifies the integrated app, core, bridge, helper and tool targets.

### R7 backup-destination correction

The R7 command reported 19 passing cases: 17 recovery cases emitted by `xcodebuild` plus
the native-panel configuration/package-placement case and the balanced security-scope
success/failure case. It did not establish coverage of every method in the then-18-method
`RecoveryAcceptanceTests` source file. A separate gated test exercised the actual
`NSOpenPanel` in a signed, isolated XCTest host, selected a fresh existing folder under
`/Users/Shared`, and passed after creating and validating one generated
`.release-radar-backup` package there. The selected folder contained only the final package,
`manifest.json` and `release-radar.sqlite` after the operation; no adjacent staging directory
remained.

The signed Release build passed strict deep code-signature validation. Its actual app
entitlements retain the app sandbox, application group and network client, replace only the
source user-selected read-only entitlement with user-selected read/write, and contain no
broad filesystem exception. Apple Development signing also injects `get-task-allow`; that
generated development entitlement is not present in the shipping entitlement source.

The initial native-picker XCTest host was signed and sandboxed with user-selected read/write,
but Xcode injected a broad read-only `/` test exception and test-manager Mach exceptions.
That initial run is therefore only evidence for the native folder-selection flow, generated
package placement and selected-folder write. A later corrective run re-signed a fresh
build-for-testing output from the production entitlement source, adding only `get-task-allow`
and the three XCTest-required Mach lookup names. Strict signature validation and entitlement
readback immediately before launch and after the test both confirmed no absolute-path
filesystem exception. The single gated picker test then selected a fresh existing folder
at `/Users/Shared/ReleaseRadar-C7-SignedPicker-Corrective.Po4gPJ`, created and validated
`Release Radar Backup 3B5D4333-6401-4B1E-8CD7-3ABB1247142D.release-radar-backup` there,
left no staging directory and exited successfully. The PID-isolated host suppressed launch
services, and an XCTest-only termination guard returned before shared application services
could initialize. This run used the temporary test output at
`build/c7-corrective-signed-host/Build/Products/Debug/ReleaseRadar.app`, derived entitlement
input `build/c7-corrective-signed-host/c7-test-runtime.entitlements` and allowlisted
`ReleaseRadar-C7-no-broad-filesystem.xctestrun`. These are retained temporary verification
artifacts, not durable product inputs. The run began from integrated source `ab53f1b` plus
the bounded R1/R5 and termination-isolation working-tree corrections.

### R1 and R5 corrective review

Two reviewer regressions failed against integrated candidate `ab53f1b` and passed after the
bounded corrections. A legacy `replacementInstalled` marker now preserves an unreadable
rollback, while new markers carry the explicit preservation policy through every phase.
Restore reconciliation now retains the displaced registration and attributed audit history
for a newer project absent from the selected backup. The complete directly affected
`RecoveryAcceptanceTests` run then passed 20 of 20 cases.

### Verification execution notes

An initial accessibility attempt bound by application path and launched the test-built
`ReleaseRadar` executable as a normal process (PID 48085) instead of attaching to an XCTest
panel. It was terminated immediately by exact PID. Because a normal launch can initialize
default application services, reads or mutations by that short-lived process are unknown;
no owner data was inspected, repaired or used as evidence, and the pre-existing installed
application process was not targeted. The successful retry used the isolated XCTest route
and numeric-PID accessibility targeting, which cannot launch another app.

A diagnostic `xcrun xctest -h` invocation unexpectedly printed inherited Jira and Pushover
credential values into the task tool transcript. They were not used or copied into repository
artifacts; rotation is required outside this repository.

## Visual comparison

The render evidence was compared with the approved
[Settings reference](../../design/mockups/settings.png) and retains its dark RDS surface,
four-tab information architecture, blue outlined panels, hierarchy and responsive stacking.
Recovery is added to General and Projects rather than introducing another navigation system.

- [General Settings — wide](c7-settings-general-wide.png)
- [General Settings — compact](c7-settings-general-compact.png)
- [Projects Settings — wide](c7-settings-projects-wide.png)
- [Projects Settings — compact](c7-settings-projects-compact.png)
- [Application health recovery action](c7-application-health-recovery.png)

The two general Application health width renders are retained in the same canonical screenshot
directory for independent QA inspection.

## Limits

This is full local application continuity, not portable project export/import. Repositories,
Keychain credentials and device permissions remain outside the backup and require their
existing authorization paths. When the prior store is unreadable, the UI truthfully reports
that newer local history cannot be reconciled.
