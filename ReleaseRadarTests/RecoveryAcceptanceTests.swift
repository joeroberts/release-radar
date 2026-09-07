import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class RecoveryAcceptanceTests: XCTestCase {
    func testClosingOneStoreInvalidatesItWithoutClosingAnotherConnection() async throws {
        let databaseURL = try makeDatabaseURL()
        let first = DeliveryStore(databaseURL: databaseURL)
        let second = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: first, id: "project-one", registrationID: "registration-one")

        await first.close()

        do {
            _ = try await first.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
            XCTFail("A closed store must fail closed")
        } catch let error as StoreError {
            XCTAssertEqual(error, .unavailable("Delivery store is closed"))
        }
        let secondProjectCount = try await second.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        XCTAssertEqual(secondProjectCount, 1)
    }

    func testMissingRecoveryAuthoritySingletonFailsClosedOnRelaunch() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Damage recovery authority fixture") {
            try $0.execute("DELETE FROM application_recovery_state")
        }
        await store.close()

        let reopened = DeliveryStore(databaseURL: databaseURL)

        guard case let .unavailable(recovery) = await reopened.availability else {
            return XCTFail("A missing recovery authority singleton must fail closed")
        }
        XCTAssertEqual(recovery.kind, .migration)
    }

    func testPreferenceResetRestoresOnlyExistingDefaultsAndPreservesTrackingHistoryAndPluginReceipts() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        try await store.transact(actor: .init(id: "fixture"), reason: "Change preferences") { connection in
            try connection.execute("UPDATE alert_rules SET is_enabled = 0")
            try connection.execute("UPDATE alert_rules SET is_enabled = 1 WHERE kind = 'paused_goals'")
            try connection.execute(
                "UPDATE codex_plugin_lifecycle SET intent = 'managedInstalled', managed_version = '1.2.3', managed_digest = 'known', verified_at = '2026-09-07T12:00:00Z' WHERE plugin_id = 'release-radar'"
            )
        }
        let before = try await tableCounts(in: store)

        let snapshot = try await ApplicationPreferenceReset(store: store).apply()

        XCTAssertTrue(snapshot[.blockedLinkedGoals])
        XCTAssertTrue(snapshot[.agentCompletionAndReview])
        XCTAssertTrue(snapshot[.needsReviewEntry])
        XCTAssertFalse(snapshot[.pausedGoals])
        let after = try await tableCounts(in: store)
        XCTAssertEqual(after["audit_events"], before["audit_events", default: 0] + 1)
        XCTAssertEqual(after.filter { $0.key != "audit_events" }, before.filter { $0.key != "audit_events" })
        let plugin = try await CodexPluginLifecycleStore(store: store).load()
        XCTAssertEqual(plugin.intent, .managedInstalled)
        XCTAssertEqual(plugin.managedVersion, "1.2.3")
        XCTAssertEqual(plugin.managedDigest, "known")
    }

    func testFullBackupContainsCompleteSupportedStoreAndRejectsSymlinkPlacement() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed supported backup state") { connection in
            try connection.execute(
                "UPDATE codex_plugin_lifecycle SET intent = 'managedInstalled', managed_version = '1.2.3', managed_digest = 'known', verified_at = '2026-09-07T12:00:00Z' WHERE plugin_id = 'release-radar'"
            )
            try connection.execute(
                "INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES ('completion-one', 'project-one', 'ticket-one', 'Done', '2026-09-07T12:01:00Z')"
            )
        }
        let packageURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("complete.release-radar-backup", isDirectory: true)
        let manager = ApplicationBackupManager(store: store, databaseURL: databaseURL)

        let countsBeforePreview = try await tableCounts(in: store)
        let preview = try await manager.previewBackup(destinationURL: packageURL)
        let countsAfterPreview = try await tableCounts(in: store)
        XCTAssertEqual(countsAfterPreview, countsBeforePreview)
        XCTAssertEqual(preview.projectCount, 1)
        XCTAssertEqual(preview.includes, [.localStore, .preferences, .history, .pluginReceipts, .notificationHistory])
        XCTAssertEqual(preview.excludes, [.credentials, .devicePermissions, .repositories, .portableProjectFiles])
        let receipt = try await manager.createBackup(preview)

        XCTAssertEqual(receipt.packageURL, packageURL)
        let manifest = try ApplicationBackupManifest.load(from: packageURL)
        XCTAssertEqual(manifest.format, ApplicationBackupManifest.formatIdentifier)
        XCTAssertEqual(manifest.schemaVersion, Int(StoreMigrations.currentVersion))
        XCTAssertEqual(manifest.databaseSHA256.count, 64)
        let backupStore = DeliveryStore(databaseURL: packageURL.appendingPathComponent(ApplicationBackupManifest.databaseFileName))
        let backupCounts = try await tableCounts(in: backupStore)
        let sourceCounts = try await tableCounts(in: store)
        XCTAssertEqual(backupCounts, sourceCounts)
        let backedUpPlugin = try await CodexPluginLifecycleStore(store: backupStore).load()
        XCTAssertEqual(backedUpPlugin.intent, .managedInstalled)

        let realParent = databaseURL.deletingLastPathComponent().appendingPathComponent("real-parent", isDirectory: true)
        let linkedParent = databaseURL.deletingLastPathComponent().appendingPathComponent("linked-parent", isDirectory: true)
        try FileManager.default.createDirectory(at: realParent, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: linkedParent, withDestinationURL: realParent)
        let unsafeDestination = linkedParent.appendingPathComponent("unsafe.release-radar-backup", isDirectory: true)
        do {
            _ = try await manager.previewBackup(destinationURL: unsafeDestination)
            XCTFail("Backup placement through a symlink must fail closed")
        } catch let error as ApplicationBackupError {
            XCTAssertEqual(error, .unsafePlacement)
        }
    }

    func testTrackingResetRemovesActiveAndArchivedRegistrationsButPreservesGlobalConfigurationAndHistory() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "active-project", registrationID: "active-registration", ticketID: "active-ticket")
        try await seedProject(in: store, id: "archived-project", registrationID: "archived-registration", ticketID: "archived-ticket")
        try await store.transact(actor: .init(id: "fixture"), reason: "Archive fixture") { connection in
            try connection.execute("UPDATE projects SET lifecycle = 'archived' WHERE id = 'archived-project'")
            try connection.execute("UPDATE alert_rules SET is_enabled = 1 WHERE kind = 'paused_goals'")
            try connection.execute(
                "UPDATE codex_plugin_lifecycle SET intent = 'managedInstalled', managed_version = '1.2.3', managed_digest = 'known', verified_at = '2026-09-07T12:00:00Z' WHERE plugin_id = 'release-radar'"
            )
        }
        let reset = ApplicationTrackingReset(store: store, databaseURL: databaseURL)

        let preview = try await reset.preview()
        XCTAssertEqual(Set(preview.projects.map(\.projectID.rawValue)), ["active-project", "archived-project"])
        XCTAssertEqual(preview.preserved, [.preferences, .pluginReceipts, .retainedHistory, .auditHistory])
        let result = try await reset.apply(preview)

        let liveProjectCount = try await result.store.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        let removedProjectCount = try await result.store.read { try $0.scalarInt("SELECT COUNT(*) FROM removed_projects") }
        XCTAssertEqual(liveProjectCount, 0)
        XCTAssertEqual(removedProjectCount, 2)
        let rules = try await AlertRuleStore(store: result.store).load()
        XCTAssertTrue(rules[.pausedGoals])
        let pluginReceipt = try await CodexPluginLifecycleStore(store: result.store).load()
        XCTAssertEqual(pluginReceipt.intent, .managedInstalled)
        XCTAssertTrue(result.requiresFreshServiceGraph)
    }

    func testRestoreRotatesAuthorityPreservesNewerFactsAndNeverReplaysBackedUpNotifications() async throws {
        let databaseURL = try makeDatabaseURL()
        let originalStore = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: originalStore, id: "project-one", registrationID: "old-registration", ticketID: "ticket-one")
        try await seedNotification(in: originalStore, state: "queued", generation: 1)
        let originalRegistration = try await ProjectLifecycleManager(store: originalStore)
            .snapshot(projectID: .init(rawValue: "project-one")).registration
        let packageURL = databaseURL.deletingLastPathComponent().appendingPathComponent("old.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: originalStore, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))

        try await originalStore.transact(actor: .init(id: "fixture"), reason: "Record newer terminal fact") { connection in
            try connection.execute(
                "UPDATE notification_events SET state = 'sent', provider_receipt = 'provider-1', completed_at = '2026-09-07T13:00:00Z' WHERE id = 'notification-one'"
            )
            try connection.execute("UPDATE notification_occurrences SET generation = 7 WHERE subject_key = 'project-one|subject-one'")
        }
        let recovery = ApplicationRecoveryManager(store: originalStore, databaseURL: databaseURL)
        let preview = try await recovery.previewRestore(packageURL: packageURL)
        XCTAssertTrue(preview.newerHistoryReconciliationAvailable)
        let firstRestore = try await recovery.restore(preview)

        let firstRegistration = try await ProjectLifecycleManager(store: firstRestore.store)
            .snapshot(projectID: .init(rawValue: "project-one")).registration
        XCTAssertNotEqual(firstRegistration, originalRegistration)
        let firstNotificationState = try await notificationState(in: firstRestore.store)
        let occurrenceGeneration = try await firstRestore.store.read { try $0.scalarInt("SELECT generation FROM notification_occurrences WHERE subject_key = 'project-one|subject-one'") }
        XCTAssertEqual(firstNotificationState, "sent")
        XCTAssertEqual(occurrenceGeneration, 7)

        let dispatcher = AgentCommandDispatcher(
            store: firstRestore.store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: firstRestore.store)
        )
        let legacy = AgentCommandEnvelope(
            version: 1, requestID: UUID(), projectRoot: "/synthetic/project-one",
            reason: "Late pre-recovery command", command: .upsertPhase(phaseID: "late", name: "Late")
        )
        let legacyResult = await dispatcher.dispatch(legacy)
        XCTAssertEqual(legacyResult.error, .staleProjectRegistration)
        let oldScoped = AgentCommandEnvelope(
            version: 1, requestID: UUID(), projectRoot: "/synthetic/project-one",
            expectedRegistration: originalRegistration, reason: "Late scoped command",
            command: .upsertPhase(phaseID: "late", name: "Late")
        )
        let oldScopedResult = await dispatcher.dispatch(oldScoped)
        XCTAssertEqual(oldScopedResult.error, .staleProjectRegistration)
        let currentScoped = AgentCommandEnvelope(
            version: 1, requestID: UUID(), projectRoot: "/synthetic/project-one",
            expectedRegistration: firstRegistration, reason: "Current scoped command",
            command: .upsertPhase(phaseID: "current", name: "Current")
        )
        let currentScopedResult = await dispatcher.dispatch(currentScoped)
        XCTAssertNil(currentScopedResult.error)

        let removal = ProjectRemovalManager(store: firstRestore.store)
        _ = try await removal.apply(try await removal.preview(projectID: .init(rawValue: "project-one")))
        let secondRecovery = ApplicationRecoveryManager(store: firstRestore.store, databaseURL: databaseURL)
        let secondRestore = try await secondRecovery.restore(try await secondRecovery.previewRestore(packageURL: packageURL))
        let secondRegistration = try await ProjectLifecycleManager(store: secondRestore.store)
            .snapshot(projectID: .init(rawValue: "project-one")).registration
        XCTAssertNotEqual(secondRegistration, firstRegistration)
        XCTAssertNotEqual(secondRegistration, originalRegistration)
        let secondNotificationState = try await notificationState(in: secondRestore.store)
        let retainedRemovalCount = try await secondRestore.store.read { try $0.scalarInt("SELECT COUNT(*) FROM removed_projects") }
        XCTAssertEqual(secondNotificationState, "suppressed")
        XCTAssertEqual(retainedRemovalCount, 2)
        let transport = RecoveryRecordingPushoverTransport()
        let notificationDispatcher = PushoverNotificationDispatcher(
            store: secondRestore.store,
            credentials: StaticPushoverCredentialsProvider(
                credentials: .init(appToken: "synthetic-token", userKey: "synthetic-user")
            ),
            transport: transport
        )
        await notificationDispatcher.prepareForLaunch()
        let sendCount = await transport.sendCount()
        XCTAssertEqual(sendCount, 0)

        let secondRemoval = ProjectRemovalManager(store: secondRestore.store)
        _ = try await secondRemoval.apply(try await secondRemoval.preview(projectID: .init(rawValue: "project-one")))
        let repeatedRemovalCount = try await secondRestore.store.read { try $0.scalarInt("SELECT COUNT(*) FROM removed_projects") }
        XCTAssertEqual(repeatedRemovalCount, 3)
    }

    func testRestorePreservesTheCurrentBlockedObservationWithoutSendingItAgain() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed linked goal") { connection in
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-one', 'project-one', 'active', '2026-09-07T12:00:00Z')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-one', 'project-one', 'ticket-one', 'thread-one')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: store)
        try await recorder.recordGoalObservation(
            projectID: .init(rawValue: "project-one"), threadID: "thread-one", goalID: "goal-one",
            status: .active, observedAt: Date(timeIntervalSince1970: 1)
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Link observed goal") { connection in
            try connection.execute("INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES ('goal-link-one', 'project-one', 'ticket-one', 'thread-one', 'goal-one')")
        }
        let packageURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("active-goal.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))

        try await recorder.recordGoalObservation(
            projectID: .init(rawValue: "project-one"), threadID: "thread-one", goalID: "goal-one",
            status: .blocked, observedAt: Date(timeIntervalSince1970: 2)
        )
        let transport = RecoveryRecordingPushoverTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: store,
            credentials: StaticPushoverCredentialsProvider(
                credentials: .init(appToken: "synthetic-token", userKey: "synthetic-user")
            ),
            transport: transport
        )
        await dispatcher.prepareForLaunch()
        await dispatcher.dispatchPending()
        let initialSendCount = await transport.sendCount()
        XCTAssertEqual(initialSendCount, 1)

        let recovery = ApplicationRecoveryManager(store: store, databaseURL: databaseURL)
        let result = try await recovery.restore(try await recovery.previewRestore(packageURL: packageURL))
        try await MeaningfulDeliveryEventRecorder(store: result.store).recordGoalObservation(
            projectID: .init(rawValue: "project-one"), threadID: "thread-one", goalID: "goal-one",
            status: .blocked, observedAt: Date(timeIntervalSince1970: 3)
        )
        let restoredDispatcher = PushoverNotificationDispatcher(
            store: result.store,
            credentials: StaticPushoverCredentialsProvider(
                credentials: .init(appToken: "synthetic-token", userKey: "synthetic-user")
            ),
            transport: transport
        )
        await restoredDispatcher.prepareForLaunch()
        await restoredDispatcher.dispatchPending()

        let finalSendCount = await transport.sendCount()
        XCTAssertEqual(finalSendCount, 1)
        let restoredStatus = try await result.store.read {
            try $0.scalarText("SELECT status FROM observed_goals WHERE id = 'goal-one'")
        }
        let occurrenceActive = try await result.store.read {
            try $0.scalarInt("SELECT is_active FROM notification_occurrences WHERE subject_key = 'project-one|goal_blocked|goal-one'")
        }
        XCTAssertEqual(restoredStatus, "blocked")
        XCTAssertEqual(occurrenceActive, 1)
    }

    func testRestoreRetainsCurrentAttributedHistoryUnderItsDisplacedRegistration() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        let packageURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("historical-provenance.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))

        try await store.transact(
            actor: .init(id: "fixture"), reason: "Record newer attributable facts",
            auditEventID: .init(rawValue: "newer-assignment-audit"),
            auditScope: .init(projectID: .init(rawValue: "project-one"), entityType: .deliveryGoal, entityID: "newer-goal")
        ) { connection in
            try connection.execute("INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES ('newer-completion', 'project-one', 'ticket-one', 'Newer completion', '2026-09-07T13:00:00Z')")
            try connection.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('project-one', 'phase-project-one', 'newer-goal', 'Newer goal', 'Retain it', 'draft', 0, '2026-09-07T13:00:00Z', '2026-09-07T13:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_assignment_events (audit_event_id, project_id, phase_id, ticket_id, previous_goal_id, current_goal_id, revision, action) VALUES ('newer-assignment-audit', 'project-one', 'phase-project-one', 'ticket-one', NULL, 'newer-goal', 0, 'assigned')")
        }

        let recovery = ApplicationRecoveryManager(store: store, databaseURL: databaseURL)
        let result = try await recovery.restore(try await recovery.previewRestore(packageURL: packageURL))
        let facts = try await result.store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM removed_projects WHERE historical_project_id = 'project-one' AND registration_id = 'registration-one'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE id = 'newer-assignment-audit' AND project_id IS NULL AND historical_project_id = 'project-one' AND historical_registration_id = 'registration-one'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM retained_project_activity_events WHERE source = 'completion' AND source_id = 'newer-completion'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM retained_delivery_goal_assignment_events assignments JOIN removed_projects removed USING (removal_id) WHERE assignments.audit_event_id = 'newer-assignment-audit' AND removed.registration_id = 'registration-one'") ?? -1,
            ]
        }
        XCTAssertEqual(facts, [1, 1, 1, 1])
    }

    func testRecoveryRollsBackIfReplacementFailsAfterMovingTheOriginal() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one", ticketID: "ticket-one")
        let packageURL = databaseURL.deletingLastPathComponent().appendingPathComponent("rollback.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))
        let recovery = ApplicationRecoveryManager(
            store: store,
            databaseURL: databaseURL,
            faultInjection: .failAfterOriginalMoved
        )

        do {
            _ = try await recovery.restore(try await recovery.previewRestore(packageURL: packageURL))
            XCTFail("Injected replacement failure must surface")
        } catch let failure as ApplicationRecoveryInstallFailure {
            XCTAssertEqual(failure.cause, .injectedFailure)
            let reopenedProjectCount = try await failure.recoveredStore.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
            XCTAssertEqual(reopenedProjectCount, 1)
            XCTAssertFalse(FileManager.default.fileExists(atPath: ApplicationRecoveryManager.markerURL(for: databaseURL).path))
        }
    }

    func testTrackingResetRejectsAChangedSourceAfterQuiescingAndResumesThePriorStore() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        let recovery = ApplicationRecoveryManager(store: store, databaseURL: databaseURL)
        let preview = try await recovery.previewTrackingReset()
        try await seedProject(in: store, id: "project-two", registrationID: "registration-two", ticketID: "ticket-two")

        do {
            _ = try await recovery.resetTracking(preview)
            XCTFail("A reset preview cannot apply to a changed source")
        } catch let failure as ApplicationRecoveryInstallFailure {
            XCTAssertEqual(failure.cause, .stalePreview)
            let projectCount = try await failure.recoveredStore.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
            XCTAssertEqual(projectCount, 2)
        }
    }

    func testRestoreRejectsAChangedRegistrationSetAfterPreviewAndResumesThePriorStore() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        let packageURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("stale-restore.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))
        let recovery = ApplicationRecoveryManager(store: store, databaseURL: databaseURL)
        let preview = try await recovery.previewRestore(packageURL: packageURL)
        let confirmation = RecoveryConfirmation.restore(preview).message
        XCTAssertTrue(confirmation.contains("project-one (project-one, registration-one)"))
        try await seedProject(
            in: store,
            id: "project-two",
            registrationID: "registration-two",
            ticketID: "ticket-two"
        )

        do {
            _ = try await recovery.restore(preview)
            XCTFail("A restore preview cannot displace a registration added after confirmation")
        } catch let failure as ApplicationRecoveryInstallFailure {
            XCTAssertEqual(failure.cause, .stalePreview)
            let projectCount = try await failure.recoveredStore.read {
                try $0.scalarInt("SELECT COUNT(*) FROM projects")
            }
            XCTAssertEqual(projectCount, 2)
        }
    }

    func testInterruptedRecoveryMarkerRestoresOriginalStoreOnNextLaunch() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        let packageURL = databaseURL.deletingLastPathComponent().appendingPathComponent("crash.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))
        let recovery = ApplicationRecoveryManager(
            store: store,
            databaseURL: databaseURL,
            faultInjection: .leaveInterruptedAfterOriginalMoved
        )

        do {
            _ = try await recovery.restore(try await recovery.previewRestore(packageURL: packageURL))
            XCTFail("The synthetic crash boundary must interrupt replacement")
        } catch ApplicationRecoveryError.injectedFailure {
            XCTAssertTrue(FileManager.default.fileExists(atPath: ApplicationRecoveryManager.markerURL(for: databaseURL).path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))
        }

        try ApplicationRecoveryManager.resolveInterruptedOperation(databaseURL: databaseURL)
        let reopened = DeliveryStore(databaseURL: databaseURL)
        let reopenedProjectCount = try await reopened.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        XCTAssertEqual(reopenedProjectCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ApplicationRecoveryManager.markerURL(for: databaseURL).path))
    }

    func testInterruptedRecoveryBeforeOriginalRemovalKeepsTheLiveStoreOnNextLaunch() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        let packageURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("copy-crash.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))
        let recovery = ApplicationRecoveryManager(
            store: store,
            databaseURL: databaseURL,
            faultInjection: .leaveInterruptedAfterRollbackCopied
        )

        do {
            _ = try await recovery.restore(try await recovery.previewRestore(packageURL: packageURL))
            XCTFail("The synthetic copy boundary must interrupt replacement")
        } catch ApplicationRecoveryError.injectedFailure {
            XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        }

        try ApplicationRecoveryManager.resolveInterruptedOperation(databaseURL: databaseURL)
        let reopened = DeliveryStore(databaseURL: databaseURL)
        let projectCount = try await reopened.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        XCTAssertEqual(projectCount, 1)
    }

    func testRecoveryMarkerCannotRedirectRollbackOutsideTheStoreDirectory() throws {
        let databaseURL = try makeDatabaseURL()
        let victimURL = databaseURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ReleaseRadar-C7-Unaffected-\(UUID().uuidString).sqlite")
        try Data("unrelated".utf8).write(to: victimURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: victimURL) }
        let operationID = UUID()
        let marker: [String: Any] = [
            "operationID": operationID.uuidString,
            "phase": "originalMoved",
            "rollbackPath": victimURL.path,
            "stagingPath": databaseURL.deletingLastPathComponent()
                .appendingPathComponent(".release-radar-restore-\(operationID.uuidString).staging.sqlite").path,
        ]
        try JSONSerialization.data(withJSONObject: marker).write(
            to: ApplicationRecoveryManager.markerURL(for: databaseURL),
            options: .atomic
        )

        XCTAssertThrowsError(try ApplicationRecoveryManager.resolveInterruptedOperation(databaseURL: databaseURL)) {
            XCTAssertEqual($0 as? ApplicationRecoveryError, .unsafeStorePlacement)
        }
        XCTAssertEqual(try Data(contentsOf: victimURL), Data("unrelated".utf8))
    }

    func testOriginalMovedMarkerRestoresRollbackAcrossAPartialSidecarRemoval() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        await store.close()
        let operationID = UUID()
        let rollbackURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent(".release-radar-rollback-\(operationID.uuidString).sqlite")
        let stagingURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent(".release-radar-restore-\(operationID.uuidString).staging.sqlite")
        try FileManager.default.copyItem(at: databaseURL, to: rollbackURL)
        let rollbackJournal = URL(fileURLWithPath: rollbackURL.path + "-journal")
        let liveJournal = URL(fileURLWithPath: databaseURL.path + "-journal")
        try Data("rollback-sidecar".utf8).write(to: rollbackJournal)
        try Data("partially-removed-live-sidecar".utf8).write(to: liveJournal)
        let marker: [String: Any] = [
            "operationID": operationID.uuidString,
            "phase": "originalMoved",
            "rollbackPath": rollbackURL.path,
            "stagingPath": stagingURL.path,
        ]
        try JSONSerialization.data(withJSONObject: marker).write(
            to: ApplicationRecoveryManager.markerURL(for: databaseURL),
            options: .atomic
        )
        try FileManager.default.removeItem(at: databaseURL)

        try ApplicationRecoveryManager.resolveInterruptedOperation(databaseURL: databaseURL)

        XCTAssertEqual(try Data(contentsOf: liveJournal), Data("rollback-sidecar".utf8))
        let reopened = DeliveryStore(databaseURL: databaseURL)
        let projectCount = try await reopened.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        XCTAssertEqual(projectCount, 1)
    }

    func testRestoreCanReplaceUnreadableOriginalWithoutClaimingHistoryReconciliation() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")
        let packageURL = databaseURL.deletingLastPathComponent().appendingPathComponent("unreadable.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))
        await store.close()
        try Data("not a sqlite store".utf8).write(to: databaseURL, options: .atomic)
        let unavailable = DeliveryStore(databaseURL: databaseURL)
        guard case .unavailable = await unavailable.availability else {
            return XCTFail("The corrupt fixture must be unavailable")
        }
        let recovery = ApplicationRecoveryManager(store: unavailable, databaseURL: databaseURL)

        let preview = try await recovery.previewRestore(packageURL: packageURL)
        XCTAssertFalse(preview.newerHistoryReconciliationAvailable)
        let result = try await recovery.restore(preview)

        XCTAssertFalse(result.newerHistoryWasReconciled)
        let preservedOriginalURL = try XCTUnwrap(result.preservedOriginalURL)
        XCTAssertEqual(try Data(contentsOf: preservedOriginalURL), Data("not a sqlite store".utf8))
        let restoredProjectCount = try await result.store.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
        XCTAssertEqual(restoredProjectCount, 1)
    }

    func testBackupRejectsUnexpectedInventoryAndDatabaseTampering() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let packageURL = databaseURL.deletingLastPathComponent().appendingPathComponent("tamper.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        _ = try await backup.createBackup(try await backup.previewBackup(destinationURL: packageURL))
        let extraURL = packageURL.appendingPathComponent("unexpected.txt")
        try Data("unexpected".utf8).write(to: extraURL)

        XCTAssertThrowsError(try ApplicationBackupManifest.load(from: packageURL))
        try FileManager.default.removeItem(at: extraURL)
        let backupDatabaseURL = packageURL.appendingPathComponent(ApplicationBackupManifest.databaseFileName)
        let handle = try FileHandle(forWritingTo: backupDatabaseURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("tampered".utf8))
        try handle.close()
        let recovery = ApplicationRecoveryManager(store: store, databaseURL: databaseURL)

        do {
            _ = try await recovery.previewRestore(packageURL: packageURL)
            XCTFail("A changed database must fail checksum validation")
        } catch let error as ApplicationRecoveryError {
            guard case .invalidBackup = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testBackupRejectsAStalePreviewWithoutCreatingAPackage() async throws {
        let databaseURL = try makeDatabaseURL()
        let store = DeliveryStore(databaseURL: databaseURL)
        let packageURL = databaseURL.deletingLastPathComponent().appendingPathComponent("stale.release-radar-backup", isDirectory: true)
        let backup = ApplicationBackupManager(store: store, databaseURL: databaseURL)
        let preview = try await backup.previewBackup(destinationURL: packageURL)
        try await seedProject(in: store, id: "project-one", registrationID: "registration-one")

        do {
            _ = try await backup.createBackup(preview)
            XCTFail("A stale backup preview must not create a package")
        } catch let error as ApplicationBackupError {
            XCTAssertEqual(error, .stalePreview)
            XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
        }
    }

    private func seedProject(
        in store: DeliveryStore,
        id: String,
        registrationID: String,
        ticketID: String = "ticket-one"
    ) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed recovery project") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 1)", bindings: [.text(id), .text(id)])
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation) VALUES (?, ?, 1)",
                bindings: [.text(id), .text(registrationID)]
            )
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)", bindings: [.text("root-\(id)"), .text(id), .text("/synthetic/\(id)")])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES (?, ?, 'Phase')", bindings: [.text("phase-\(id)"), .text(id)])
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, 'Outcome', 'accepted')",
                bindings: [.text(ticketID), .text(id), .text("phase-\(id)")]
            )
        }
    }

    private func seedNotification(in store: DeliveryStore, state: String, generation: Int64) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed notification") { connection in
            try connection.execute(
                "INSERT INTO notification_occurrences (subject_key, project_id, event_kind, subject_id, generation, is_active) VALUES ('project-one|subject-one', 'project-one', 'blocked_linked_goals', 'subject-one', ?, 1)",
                bindings: [.integer(generation)]
            )
            try connection.execute(
                """
                INSERT INTO notification_events (
                    id, fingerprint, state, project_id, event_kind, subject_id, occurrence,
                    title, message, created_at, attempt_count
                ) VALUES ('notification-one', 'project-one:fingerprint-one', ?, 'project-one',
                    'blocked_linked_goals', 'subject-one', 1, 'Title', 'Message',
                    '2026-09-07T12:00:00Z', 0)
                """,
                bindings: [.text(state)]
            )
        }
    }

    private func notificationState(in store: DeliveryStore) async throws -> String? {
        try await store.read { try $0.scalarText("SELECT state FROM notification_events WHERE id = 'notification-one'") }
    }

    private func tableCounts(in store: DeliveryStore) async throws -> [String: Int64] {
        try await store.read { connection in
            var result: [String: Int64] = [:]
            for table in [
                "projects", "project_registrations", "project_roots", "phases", "tickets",
                "completion_records", "audit_events", "removed_projects",
            ] {
                result[table] = try connection.scalarInt("SELECT COUNT(*) FROM \(table)") ?? -1
            }
            return result
        }
    }

    private func makeDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-C7-RecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("release-radar.sqlite")
    }
}

private actor RecoveryRecordingPushoverTransport: PushoverTransport {
    private var sends = 0

    func send(_: PushoverMessage, credentials _: PushoverCredentials) async throws -> PushoverProviderReceipt {
        sends += 1
        return .init(requestID: "unexpected")
    }

    func sendCount() -> Int { sends }
}
