# C7 backup, reset and recovery evidence

## Outcome

The C7 candidate provides a versioned full local backup package, separate preference and
tracking resets, rollback-safe restore/relaunch recovery, stale-command invalidation,
notification nonreplay, read-only plugin reconciliation and the related C12 Settings and
Application health actions. Verification used only synthetic app-owned stores and transports;
no owner database, credentials, repositories, plugin installation or notification service was
mutated.

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
