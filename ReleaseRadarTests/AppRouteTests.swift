import AppKit
import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class AppRouteTests: XCTestCase {
#if DEBUG
    func testRR9AcceptedHistoryRollsBackWhenAPlanAppearsAfterStagedInsertion() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9Task4A-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        _ = await store.availability
        try await store.transact(actor: .init(id: "test-trigger"), reason: "Install scoped trigger") { connection in
            try connection.execute(
                """
                CREATE TRIGGER task4a_rr9_plan_after_insert
                AFTER INSERT ON tickets WHEN NEW.id = 'RR9-HISTORY'
                BEGIN
                    INSERT INTO ticket_task_plans (project_id, ticket_id, revision, created_at, updated_at)
                    VALUES (NEW.project_id, NEW.id, 1, '2026-08-31T12:00:00Z', '2026-08-31T12:00:00Z');
                    INSERT INTO ticket_tasks
                        (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle, created_at, updated_at)
                    VALUES
                        (NEW.project_id, NEW.id, 'injected-task', 'Injected', 'Injected pending task', 0,
                         'pending', 'active', '2026-08-31T12:00:00Z', '2026-08-31T12:00:00Z');
                END
                """
            )
        }
        let before = try await Self.task4ARR9Snapshot(store)

        do {
            try await RR9ActivePhaseCaptureFixture.seedIfNeeded(
                in: store,
                rootDirectory: directory.appendingPathComponent("roots", isDirectory: true),
                scenario: .crossPhaseDetail
            )
            XCTFail("Expected the injected plan to reject the Accepted RR9 history")
        } catch {
            XCTAssertEqual(
                error as? TicketTaskPlanningPolicyError,
                .ticketTaskPlanRevisionConflict(expected: nil, current: 1)
            )
        }

        let after = try await Self.task4ARR9Snapshot(store)
        XCTAssertEqual(after, before)
    }
#endif

    func testSampleLaunchPolicyRequiresExplicitNonEmptyDebugCapture() {
        XCTAssertFalse(AppLaunchConfiguration.shouldSeedSampleData(arguments: [], isDebugBuild: true))
        XCTAssertFalse(AppLaunchConfiguration.shouldSeedSampleData(
            arguments: ["--rr10-capture", "--rr10-empty-store"],
            isDebugBuild: true
        ))
        XCTAssertFalse(AppLaunchConfiguration.shouldSeedSampleData(
            arguments: ["--rr10-capture"],
            isDebugBuild: false
        ))
        XCTAssertTrue(AppLaunchConfiguration.shouldSeedSampleData(
            arguments: ["--rr10-capture"],
            isDebugBuild: true
        ))
        XCTAssertFalse(AppLaunchConfiguration.externalServicesSuppressed(
            arguments: [],
            isDebugBuild: true
        ))
        XCTAssertFalse(AppLaunchConfiguration.externalServicesSuppressed(
            arguments: ["--rr10-capture"],
            isDebugBuild: false
        ))
        XCTAssertFalse(AppLaunchConfiguration.externalServicesSuppressed(
            arguments: [],
            isDebugBuild: false
        ))
        XCTAssertTrue(AppLaunchConfiguration.externalServicesSuppressed(
            arguments: ["--rr10-capture"],
            isDebugBuild: true
        ))
        XCTAssertTrue(AppLaunchConfiguration.externalServicesSuppressed(
            arguments: ["--rr10-capture", "--rr10-empty-store"],
            isDebugBuild: true
        ))
    }

    func testXCTestHostPreparationCreatesFreshPIDScopedStoreAndOverridesCapture() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-XCTestHostPreparation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let xctestEnvironment = ["XCTestConfigurationFilePath": "/tmp/ReleaseRadarTests.xctestconfiguration"]
        let emptyXCTestEnvironment = ["XCTestConfigurationFilePath": ""]
        let firstPID: Int32 = 4_201
        let secondPID: Int32 = 4_202
        let expectedFirstURL = root.standardizedFileURL
            .appendingPathComponent("ReleaseRadar-XCTestHost-\(firstPID)", isDirectory: true)
            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
            .standardizedFileURL

        XCTAssertEqual(
            AppLaunchConfiguration.hostMode(
                environment: [:],
                temporaryDirectory: root,
                processIdentifier: firstPID
            ),
            .application
        )
        guard case let .xctestHost(databaseURL: firstDatabaseURL, store: _) = AppLaunchConfiguration.prepareXCTestHost(
            environment: xctestEnvironment,
            temporaryDirectory: root,
            processIdentifier: firstPID
        ) else {
            return XCTFail("Expected the fresh XCTest host store")
        }
        guard case let .xctestHost(databaseURL: secondDatabaseURL, store: _) = AppLaunchConfiguration.prepareXCTestHost(
            environment: emptyXCTestEnvironment,
            temporaryDirectory: root,
            processIdentifier: secondPID
        ) else {
            return XCTFail("Expected the empty XCTest value to create an isolated store")
        }
        XCTAssertEqual(firstDatabaseURL, expectedFirstURL)
        XCTAssertNotEqual(firstDatabaseURL.deletingLastPathComponent(), root)
        XCTAssertNotEqual(firstDatabaseURL, secondDatabaseURL)
        XCTAssertEqual(secondDatabaseURL.deletingLastPathComponent().lastPathComponent, "ReleaseRadar-XCTestHost-\(secondPID)")
        XCTAssertEqual(expectedFirstURL.lastPathComponent, "release-radar.sqlite")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedFirstURL.deletingLastPathComponent().path))
        XCTAssertTrue(AppLaunchConfiguration.isXCTestHost(environment: xctestEnvironment))
        XCTAssertTrue(AppLaunchConfiguration.isXCTestHost(environment: emptyXCTestEnvironment))
        XCTAssertFalse(AppLaunchConfiguration.isXCTestHost(environment: [:]))
        XCTAssertTrue(AppLaunchConfiguration.externalServicesSuppressed(
            arguments: ["--rr10-capture", "--rr10-empty-store"],
            isDebugBuild: true
        ))
    }

    func testXCTestHostPreparationRejectsExistingDirectoryWithoutInvokingStoreFactory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-XCTestHostExistingDirectory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let processIdentifier: Int32 = 8_451
        let pidDirectory = root.standardizedFileURL
            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
        try FileManager.default.createDirectory(at: pidDirectory, withIntermediateDirectories: true)
        let staleSentinel = pidDirectory.appendingPathComponent("stale-sentinel")
        let sentinelContents = Data("stale XCTest state".utf8)
        try sentinelContents.write(to: staleSentinel)
        let expectedURL = pidDirectory
            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
            .standardizedFileURL

        let preparation = AppLaunchConfiguration.prepareXCTestHost(
            environment: ["XCTestConfigurationFilePath": "present"],
            temporaryDirectory: root,
            processIdentifier: processIdentifier,
            storeFactory: { _ in
                XCTFail("The store factory must not run for a pre-existing PID directory")
                fatalError("Unexpected store factory invocation")
            }
        )

        guard case let .xctestHostUnavailable(databaseURL) = preparation else {
            return XCTFail("Expected the existing PID directory to keep the host unavailable")
        }
        XCTAssertEqual(databaseURL, expectedURL)
        XCTAssertEqual(expectedURL.lastPathComponent, "release-radar.sqlite")
        XCTAssertEqual(try Data(contentsOf: staleSentinel), sentinelContents)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pidDirectory.path))
    }

    func testXCTestHostPreparationRejectsExistingFileWithoutInvokingStoreFactory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-XCTestHostExistingFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let processIdentifier: Int32 = 8_452
        let pidEntry = root.standardizedFileURL
            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
        let fileContents = Data("PID entry is a file".utf8)
        try fileContents.write(to: pidEntry)
        let expectedURL = pidEntry
            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
            .standardizedFileURL

        let preparation = AppLaunchConfiguration.prepareXCTestHost(
            environment: ["XCTestConfigurationFilePath": "present"],
            temporaryDirectory: root,
            processIdentifier: processIdentifier,
            storeFactory: { _ in
                XCTFail("The store factory must not run for a pre-existing PID file")
                fatalError("Unexpected store factory invocation")
            }
        )

        guard case let .xctestHostUnavailable(databaseURL) = preparation else {
            return XCTFail("Expected the existing PID file to keep the host unavailable")
        }
        XCTAssertEqual(databaseURL, expectedURL)
        XCTAssertEqual(try Data(contentsOf: pidEntry), fileContents)
    }

    func testXCTestHostPreparationRejectsExistingSymlinkWithoutInvokingStoreFactory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-XCTestHostSymlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let processIdentifier: Int32 = 8_453
        let targetDirectory = root.appendingPathComponent("symlink-target", isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetSentinel = targetDirectory.appendingPathComponent("target-sentinel")
        let targetContents = Data("symlink target remains untouched".utf8)
        try targetContents.write(to: targetSentinel)
        let pidDirectory = root.standardizedFileURL
            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: pidDirectory, withDestinationURL: targetDirectory)
        let expectedURL = pidDirectory
            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
            .standardizedFileURL

        let preparation = AppLaunchConfiguration.prepareXCTestHost(
            environment: ["XCTestConfigurationFilePath": "present"],
            temporaryDirectory: root,
            processIdentifier: processIdentifier,
            storeFactory: { _ in
                XCTFail("The store factory must not run for a pre-existing PID symlink")
                fatalError("Unexpected store factory invocation")
            }
        )

        guard case let .xctestHostUnavailable(databaseURL) = preparation else {
            return XCTFail("Expected the existing PID symlink to keep the host unavailable")
        }
        XCTAssertEqual(databaseURL, expectedURL)
        XCTAssertEqual(try Data(contentsOf: targetSentinel), targetContents)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: pidDirectory.path), targetDirectory.path)
    }

    @MainActor
    func testSuppressedCaptureLoadLeavesQueuedNotificationUntouched() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SuppressedCapture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed suppressed capture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('capture-project', 'Capture')")
            try connection.execute(
                """
                INSERT INTO notification_events
                    (id, fingerprint, state, project_id, event_kind, subject_id, occurrence,
                     title, message, created_at, attempt_count)
                VALUES
                    ('capture-event', 'capture:event:1', 'queued', 'capture-project',
                     'review_requested', 'capture-review', 1, 'Review', 'Review requested',
                     '2026-08-25T00:00:00Z', 0)
                """
            )
        }
        let dispatcher = PushoverNotificationDispatcher(
            store: store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil)
        )
        let coordinator = AppNotificationCoordinator(store: store, dispatcher: dispatcher)
        let model = AppModel(
            store: store,
            notificationCoordinator: coordinator,
            externalServicesSuppressed: true
        )

        await model.loadDashboard()

        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events WHERE id = 'capture-event'"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events WHERE id = 'capture-event'")
            )
        }
        XCTAssertEqual(state.0, NotificationDeliveryState.queued.rawValue)
        XCTAssertEqual(state.1, 0)
    }

    @MainActor
    func testNormalModelStartupDoesNotSeedSampleDeliveryData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NormalStartup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")))

        await model.loadDashboard()

        XCTAssertEqual(model.dashboard?.projects.count, 0)
        XCTAssertEqual(model.selection, .projects)
    }

    @MainActor
    func testExplicitCaptureModelSeedsSampleDeliveryData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SeededCapture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            seedSampleData: true
        )

        await model.loadDashboard()

        XCTAssertEqual(model.dashboard?.projects.map(\.id), [DashboardSampleData.projectID])
    }

    @MainActor
    func testAlertRuleModelLoadsPersistedValuesAndSuccessfulChangeSurvivesRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AlertRuleModel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        _ = try await AlertRuleStore(store: store).set(.pausedGoals, enabled: true)
        let model = AppModel(store: store)

        await model.loadDashboard()
        XCTAssertTrue(try XCTUnwrap(model.alertRules)[.pausedGoals])
        await model.setAlertRule(.blockedLinkedGoals, enabled: false)
        XCTAssertFalse(try XCTUnwrap(model.alertRules)[.blockedLinkedGoals])
        XCTAssertNil(model.alertRulesFailure)

        let relaunched = AppModel(store: DeliveryStore(databaseURL: databaseURL))
        await relaunched.loadAlertRules()
        XCTAssertTrue(try XCTUnwrap(relaunched.alertRules)[.pausedGoals])
        XCTAssertFalse(try XCTUnwrap(relaunched.alertRules)[.blockedLinkedGoals])
    }

    @MainActor
    func testAlertRuleModelFailsTruthfullyWithoutGuessingOrChangingLastGoodValue() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AlertRuleFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        let model = AppModel(store: store)
        await model.loadAlertRules()
        let authoritative = try XCTUnwrap(model.alertRules)

        try await store.transact(actor: .init(id: "fixture"), reason: "Force alert update failure") { connection in
            try connection.execute("DROP TABLE alert_rules")
        }
        await model.setAlertRule(.blockedLinkedGoals, enabled: false)

        XCTAssertEqual(model.alertRules, authoritative)
        XCTAssertEqual(model.alertRulesFailure?.accessibilityID, "alert-rules-failure")
        XCTAssertNil(model.alertRuleUpdateInFlight)

        let malformedStore = DeliveryStore(databaseURL: directory.appendingPathComponent("malformed.sqlite"))
        try await malformedStore.transact(actor: .init(id: "fixture"), reason: "Break alert rules") { connection in
            try connection.execute("DELETE FROM alert_rules WHERE kind = 'needs_review_entry'")
        }
        let malformedModel = AppModel(store: malformedStore)
        await malformedModel.loadDashboard()
        XCTAssertNil(malformedModel.alertRules)
        XCTAssertEqual(malformedModel.alertRulesFailure?.accessibilityID, "alert-rules-failure")
        XCTAssertNotNil(malformedModel.dashboard)
    }

    @MainActor
    func testStaleReviewAuthorizationRequiresRecoveryAndExplicitRetryBeforeSingleDispatch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ReviewAuthorization-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let bookmarks = RouteBookmarkStore()
        let bookmark = try bookmarks.makeBookmark(for: projectRoot)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed stale review authorization") { connection in
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('rr-r2-root', ?, ?)",
                bindings: [.text(DashboardSampleData.projectID.rawValue), .text(projectRoot.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 1)",
                bindings: [
                    .text(DashboardSampleData.projectID.rawValue),
                    .text(projectRoot.path),
                    .blob(bookmark),
                ]
            )
        }
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
        let model = AppModel(store: store, projectOnboarding: onboarding)
        await model.loadDashboard()
        let item = try XCTUnwrap(
            model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.first {
                $0.id.rawValue == "duplicate-review"
            }
        )

        await model.performReviewDecision(.resolve, item: item)

        XCTAssertEqual(model.reviewActionFailure?.accessibilityID, "review-locate-authorization")
        XCTAssertEqual(model.reviewAuthorizationRecovery, .reauthorizeProjectRoot)
        XCTAssertTrue(model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.contains(item) == true)
        var persisted = try await reviewRecoveryState(store: store)
        XCTAssertEqual(persisted.status, "open")
        XCTAssertEqual(persisted.decisionAudits, 0)
        XCTAssertEqual(persisted.commandRows, 0)

        await model.recoverReviewAuthorization(at: projectRoot, for: DashboardSampleData.projectID)

        XCTAssertNil(model.reviewActionFailure)
        XCTAssertNil(model.reviewAuthorizationRecovery)
        XCTAssertTrue(model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.contains(item) == true)
        persisted = try await reviewRecoveryState(store: store)
        XCTAssertEqual(persisted.status, "open")
        XCTAssertEqual(persisted.decisionAudits, 0)
        XCTAssertEqual(persisted.commandRows, 0)

        await model.performReviewDecision(.resolve, item: item)

        persisted = try await reviewRecoveryState(store: store)
        XCTAssertEqual(persisted.status, "resolved")
        XCTAssertEqual(persisted.decisionAudits, 1)
        XCTAssertEqual(persisted.commandRows, 1)
        XCTAssertEqual(bookmarks.accessStarts, bookmarks.accessStops)
    }

    @MainActor
    func testReviewAuthorizationRecoveryIgnoresCallbackFromAnotherProject() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ReviewAuthorizationScope-\(UUID().uuidString)", isDirectory: true)
        let firstRoot = directory.appendingPathComponent("first", isDirectory: true)
        let secondRoot = directory.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let bookmarks = RouteBookmarkStore()
        let secondProjectID = ProjectID(rawValue: "project-second")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed scoped review authorization") { connection in
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('rr-r2-first-root', ?, ?)",
                bindings: [.text(DashboardSampleData.projectID.rawValue), .text(firstRoot.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 1)",
                bindings: [
                    .text(DashboardSampleData.projectID.rawValue),
                    .text(firstRoot.path),
                    .blob(try bookmarks.makeBookmark(for: firstRoot)),
                ]
            )
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-second', 'Second')")
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('rr-r2-second-root', 'project-second', ?)",
                bindings: [.text(secondRoot.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('project-second', ?, ?, 0)",
                bindings: [
                    .text(secondRoot.path),
                    .blob(try bookmarks.makeBookmark(for: secondRoot)),
                ]
            )
        }
        let model = AppModel(
            store: store,
            projectOnboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
        )
        await model.loadDashboard()
        let item = try XCTUnwrap(
            model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.first {
                $0.id.rawValue == "duplicate-review"
            }
        )

        await model.performReviewDecision(.resolve, item: item)

        XCTAssertEqual(
            model.scopedReviewAuthorizationRecovery(for: DashboardSampleData.projectID),
            .reauthorizeProjectRoot
        )
        XCTAssertNil(model.scopedReviewAuthorizationRecovery(for: secondProjectID))
        XCTAssertNotNil(model.scopedReviewActionFailure(for: DashboardSampleData.projectID))
        XCTAssertNil(model.scopedReviewActionFailure(for: secondProjectID))

        await model.recoverReviewAuthorization(at: secondRoot, for: secondProjectID)

        let state = try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT is_stale FROM project_bookmarks WHERE project_id = ?",
                    bindings: [.text(DashboardSampleData.projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE project_id = 'project-second' AND reason = 'Reauthorize project folder access'"
                )
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(
            model.scopedReviewAuthorizationRecovery(for: DashboardSampleData.projectID),
            .reauthorizeProjectRoot
        )
    }

    @MainActor
    func testCommittedReviewDecisionIsNotPresentedForRetryWhenProjectionRefreshFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ReviewRefreshFailure-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let bookmarks = RouteBookmarkStore()
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed review refresh failure") { connection in
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES ('rr-r2-refresh-root', ?, ?)",
                bindings: [.text(DashboardSampleData.projectID.rawValue), .text(projectRoot.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
                bindings: [
                    .text(DashboardSampleData.projectID.rawValue),
                    .text(projectRoot.path),
                    .blob(try bookmarks.makeBookmark(for: projectRoot)),
                ]
            )
        }
        let loader = RouteReviewInboxLoader(failAfterSuccessfulLoads: 1)
        let model = AppModel(
            store: store,
            projectOnboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks),
            reviewInboxLoader: { store, projectID in
                try await loader.load(from: store, projectID: projectID)
            }
        )
        await model.loadDashboard()
        let item = try XCTUnwrap(
            model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.first {
                $0.id.rawValue == "duplicate-review"
            }
        )

        await model.performReviewDecision(.resolve, item: item)

        let persisted = try await reviewRecoveryState(store: store)
        XCTAssertEqual(persisted.status, "resolved")
        XCTAssertEqual(persisted.decisionAudits, 1)
        XCTAssertEqual(persisted.commandRows, 1)
        XCTAssertFalse(
            model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.contains { $0.id == item.id } == true
        )
        XCTAssertTrue(
            model.reviewInbox(for: DashboardSampleData.projectID)?.completedItems.contains { $0.id == item.id } == true
        )
        XCTAssertEqual(
            model.scopedReviewActionFailure(for: DashboardSampleData.projectID)?.accessibilityID,
            "review-refresh-failed"
        )
        XCTAssertTrue(
            model.scopedReviewActionFailure(for: DashboardSampleData.projectID)?.detail.localizedCaseInsensitiveContains("saved") == true
        )
        XCTAssertNil(model.scopedReviewAuthorizationRecovery(for: DashboardSampleData.projectID))
    }

    @MainActor
    func testOnboardingCompletionReloadsPersistedProjectAndReturnsToProjects() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-OnboardingCompletion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let model = AppModel(store: store)
        await model.loadDashboard()
        try await DashboardSampleData.seedIfNeeded(in: store)
        model.selection = .phaseBoard(DashboardSampleData.projectID)

        await model.reloadAfterOnboarding()

        XCTAssertEqual(model.dashboard?.projects.map(\.id), [DashboardSampleData.projectID])
        XCTAssertEqual(model.selection, .projects)
    }

    func testAttachFolderWorkflowUsesRequiredLabelAndNamesProjectAndFolder() throws {
        let project = ProjectRecord(id: ProjectID(rawValue: "existing-project"), name: "Existing Project")
        let folder = URL(fileURLWithPath: "/tmp/Existing Project", isDirectory: true)
        let confirmation = AttachFolderConfirmation(project: project, folder: folder)

        XCTAssertEqual(AttachFolderConfirmation.workflowLabel, "Attach Folder to Existing Project")
        XCTAssertTrue(confirmation.title.contains(project.name))
        XCTAssertTrue(confirmation.title.contains(folder.lastPathComponent))
        XCTAssertTrue(confirmation.detail.localizedCaseInsensitiveContains("preserved"))
    }

    func testAddProjectLandingExposesOnlyInitializeAndAttachWorkflows() {
        XCTAssertEqual(OnboardingWorkflowPresentation.landingActionTitles, [
            "Initialize Project Tracking",
            "Attach Folder to Existing Project",
        ])
        XCTAssertFalse(OnboardingWorkflowPresentation.landingActionTitles.contains("Import Existing Project"))
        XCTAssertFalse(OnboardingWorkflowPresentation.landingActionTitles.contains("Help"))
    }

    func testInitializeConfirmationNamesProjectAndFolderAndPromisesNoRepositoryWrites() {
        let folder = URL(fileURLWithPath: "/tmp/Delivery Workspace", isDirectory: true)
        let confirmation = InitializeProjectConfirmation(
            projectName: "Delivery Workspace",
            folder: folder
        )

        XCTAssertTrue(confirmation.title.contains("Delivery Workspace"))
        XCTAssertTrue(confirmation.title.contains(folder.lastPathComponent))
        XCTAssertTrue(confirmation.detail.localizedCaseInsensitiveContains("saved locally"))
        XCTAssertTrue(confirmation.detail.localizedCaseInsensitiveContains("does not modify repository files"))
    }

    @MainActor
    func testCodexPromptCopyWritesExactApprovedBytesAndReturnsAccessibleSuccess() throws {
        let projectRoot = URL(fileURLWithPath: "/tmp/Delivery Workspace", isDirectory: true)
        let pasteboard = NSPasteboard(name: .init("release-radar-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        addTeardownBlock { pasteboard.clearContents() }

        let result = CodexPromptHandoff.copy(for: .missing, projectRoot: projectRoot) { prompt in
            pasteboard.clearContents()
            return pasteboard.setString(prompt, forType: .string)
        }

        let copied = try XCTUnwrap(pasteboard.string(forType: .string))
        XCTAssertEqual(
            Data(copied.utf8),
            Data(CodexPromptHandoff.prompt(for: .missing, projectRoot: projectRoot).utf8)
        )
        XCTAssertEqual(result, .copied)
        XCTAssertEqual(result.announcement, "Codex prompt copied")
        XCTAssertEqual(result.accessibilityAnnouncement, "Codex prompt copied")
        XCTAssertEqual(CodexPromptHandoff.copyButtonAccessibilityLabel, "Copy Codex prompt")
        XCTAssertEqual(CodexPromptHandoff.copyButtonAccessibilityIdentifier, "onboarding-copy-codex-prompt")
        XCTAssertTrue(CodexPromptHandoff.clipboardDisclosure.localizedCaseInsensitiveContains("only the prompt"))
        XCTAssertTrue(CodexPromptHandoff.clipboardDisclosure.localizedCaseInsensitiveContains("until replaced"))
        XCTAssertTrue(copied.contains(projectRoot.path))
        XCTAssertTrue(copied.contains("stop before writing any file or calling Release Radar"))
    }

    @MainActor
    func testCodexPromptCopyUsesRepairPromptForIncompleteHandoff() {
        var copiedPrompt: String?
        let projectRoot = URL(fileURLWithPath: "/Users/example/RekonDesignSystem", isDirectory: true)

        let result = CodexPromptHandoff.copy(
            for: .handoffIncomplete(version: 1),
            projectRoot: projectRoot
        ) { prompt in
            copiedPrompt = prompt
            return true
        }

        XCTAssertEqual(result, .copied)
        XCTAssertEqual(
            copiedPrompt,
            CodexPromptHandoff.prompt(for: .handoffIncomplete(version: 1), projectRoot: projectRoot)
        )
        XCTAssertTrue(copiedPrompt?.contains(projectRoot.path) == true)
        XCTAssertTrue(copiedPrompt?.contains("stop before writing any file or calling Release Radar") == true)
    }

    func testProjectGuidancePresentationOffersOwnerMediatedRecoveryOnlyWhenNeeded() {
        XCTAssertEqual(ProjectGuidancePresentation(state: .current(version: 1)).status, "Release Radar guidance current · v1")
        XCTAssertNil(ProjectGuidancePresentation(state: .current(version: 1)).actionTitle)
        XCTAssertEqual(
            ProjectGuidancePresentation(state: .handoffIncomplete(version: 1)).status,
            "Release Radar guidance handoff incomplete · v1"
        )
        XCTAssertEqual(
            ProjectGuidancePresentation(state: .handoffIncomplete(version: 1)).actionTitle,
            "Copy repair prompt"
        )
        XCTAssertEqual(ProjectGuidancePresentation(state: .missing).status, "Release Radar guidance not installed")
        XCTAssertEqual(ProjectGuidancePresentation(state: .missing).actionTitle, "Copy setup prompt")
        XCTAssertEqual(
            ProjectGuidancePresentation(state: .outdated(installed: 0, current: 1)).status,
            "Release Radar guidance update required · v0 → v1"
        )
        XCTAssertEqual(
            ProjectGuidancePresentation(state: .outdated(installed: 0, current: 1)).actionTitle,
            "Copy update prompt"
        )
        XCTAssertEqual(ProjectGuidancePresentation(state: .needsRepair).status, "Release Radar guidance needs repair")
        XCTAssertEqual(ProjectGuidancePresentation(state: .unavailable).status, "Release Radar guidance unavailable")
    }

    @MainActor
    func testAppModelRefreshesReadOnlyProjectGuidanceAfterFolderContentChanges() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GuidanceRoute-\(UUID().uuidString)", isDirectory: true)
        let folder = directory.appendingPathComponent("attached-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let agentsURL = folder.appendingPathComponent("AGENTS.md")
        let outdated = "# Owner instructions\n\n<!-- release-radar-guidance:v0:start -->\nold\n<!-- release-radar-guidance:end -->\n"
        try Data(outdated.utf8).write(to: agentsURL)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await seedAttachmentRouteProjects(in: store)
        let bookmarks = RouteBookmarkStore()
        let model = AppModel(
            store: store,
            projectOnboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks),
            externalServicesSuppressed: true
        )

        await model.loadDashboard()
        _ = try await model.attachFolder(folder, to: attachmentRouteProjectID)

        XCTAssertEqual(
            model.projectGuidanceState(for: attachmentRouteProjectID),
            .outdated(installed: 0, current: 1)
        )
        XCTAssertEqual(model.projectRoot(for: attachmentRouteProjectID), folder)
        XCTAssertEqual(try String(contentsOf: agentsURL, encoding: .utf8), outdated)

        let current = "# Owner instructions\n\n\(ProjectGuidanceInspection.managedBlock)\n"
        try Data(current.utf8).write(to: agentsURL)
        await model.loadDashboard()

        XCTAssertEqual(
            model.projectGuidanceState(for: attachmentRouteProjectID),
            .handoffIncomplete(version: 1)
        )

        let handoff = await AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(
                    projectID: attachmentRouteProjectID,
                    canonicalRoot: folder,
                    authorizedRoots: [folder]
                ),
            ])
        ).dispatch(.init(
            version: 1,
            requestID: UUID(),
            projectRoot: folder.path,
            reason: "Complete Release Radar repository handoff",
            command: .addEvidence(
                id: ProjectGuidanceInspection.handoffEvidenceIDPrefix + UUID().uuidString,
                ticketID: nil,
                path: agentsURL.path
            )
        ))
        XCTAssertNil(handoff.error)
        XCTAssertNotNil(handoff.auditEventID)

        await model.loadDashboard()

        XCTAssertEqual(model.projectGuidanceState(for: attachmentRouteProjectID), .current(version: 1))
        XCTAssertEqual(try String(contentsOf: agentsURL, encoding: .utf8), current)
        XCTAssertEqual(bookmarks.accessStarts, bookmarks.accessStops)
    }

    @MainActor
    func testCodexPromptCopyFailureReplacesPriorSuccessWithoutReportingCopied() {
        let firstResult = CodexPromptHandoff.copy(prompt: "first") { _ in true }
        let secondResult = CodexPromptHandoff.copy(prompt: "second") { _ in false }

        XCTAssertEqual(firstResult, .copied)
        XCTAssertEqual(secondResult, .failed)
        XCTAssertEqual(secondResult.announcement, "Codex prompt could not be copied")
        XCTAssertEqual(secondResult.accessibilityAnnouncement, "Codex prompt could not be copied")
        XCTAssertNotEqual(secondResult.announcement, firstResult.announcement)
    }

    @MainActor
    func testAppModelAttachRefreshesProjectsAndSelectsTargetWithoutDashboardOpen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AttachRoute-\(UUID().uuidString)", isDirectory: true)
        let folder = directory.appendingPathComponent("attached-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await seedAttachmentRouteProjects(in: store)
        let bookmarks = RouteBookmarkStore()
        let model = AppModel(
            store: store,
            projectOnboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks),
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        XCTAssertEqual(model.currentProjectID, DashboardSampleData.projectID)

        let outcome = try await model.attachFolder(folder, to: attachmentRouteProjectID)

        XCTAssertEqual(outcome, .attached)
        XCTAssertEqual(model.selection, .projects)
        XCTAssertEqual(model.currentProjectID, attachmentRouteProjectID)
        XCTAssertEqual(model.currentProject?.name, "Zulu Attach Target")
        let state = try await attachmentRouteState(store: store)
        XCTAssertEqual(state.roots, 1)
        XCTAssertEqual(state.bookmarks, 1)
        XCTAssertEqual(state.attachmentAudits, 1)
        XCTAssertEqual(state.dashboardOpenAudits, 0)
        XCTAssertEqual(state.firstDashboardOpened, 0)
        XCTAssertEqual(state.onboardingOrImportAudits, 0)
    }

    @MainActor
    func testCommittedAttachmentIsNotPresentedForRetryWhenProjectionRefreshFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AttachRefreshFailure-\(UUID().uuidString)", isDirectory: true)
        let folder = directory.appendingPathComponent("attached-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await seedAttachmentRouteProjects(in: store)
        let bookmarks = RouteBookmarkStore()
        let loader = RouteDashboardLoader(failingCalls: [2])
        let model = AppModel(
            store: store,
            projectOnboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks),
            dashboardLoader: { store in try await loader.load(from: store) },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()

        let outcome = try await model.attachFolder(folder, to: attachmentRouteProjectID)

        XCTAssertEqual(outcome, .attachedNeedsReload)
        XCTAssertEqual(model.selection, .projects)
        XCTAssertEqual(model.currentProjectID, attachmentRouteProjectID)
        XCTAssertEqual(AttachFolderConfirmation.savedNeedsReload.accessibilityID, "attachment-refresh-failed")
        XCTAssertTrue(AttachFolderConfirmation.savedNeedsReload.detail.localizedCaseInsensitiveContains("saved"))
        XCTAssertTrue(AttachFolderConfirmation.savedNeedsReload.detail.localizedCaseInsensitiveContains("do not retry"))
        var state = try await attachmentRouteState(store: store)
        XCTAssertEqual(state.roots, 1)
        XCTAssertEqual(state.bookmarks, 1)
        XCTAssertEqual(state.attachmentAudits, 1)
        XCTAssertEqual(state.dashboardOpenAudits, 0)

        let didReload = await model.reloadAfterFolderAttachment(attachmentRouteProjectID)
        XCTAssertTrue(didReload)

        state = try await attachmentRouteState(store: store)
        XCTAssertEqual(state.roots, 1)
        XCTAssertEqual(state.bookmarks, 1)
        XCTAssertEqual(state.attachmentAudits, 1)
        XCTAssertEqual(state.dashboardOpenAudits, 0)
        XCTAssertEqual(model.selection, .projects)
        XCTAssertEqual(model.currentProjectID, attachmentRouteProjectID)
    }

    @MainActor
    func testAppModelLoadsExplicitUnavailableCodexRuntimeState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-CodexState-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let observer = UnavailableCodexObserver(reason: "Shared desktop observation unavailable")
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            codexObserver: observer
        )

        await model.loadCodexRuntime()

        XCTAssertEqual(model.codexSnapshot.freshness.state, .unavailable)
        XCTAssertEqual(model.codexSnapshot.freshness.reason, "Shared desktop observation unavailable")
        XCTAssertTrue(model.codexSnapshot.threads.isEmpty)
    }

    func testPrimaryRoutesExposeTheExpectedAccessibleLabelsAndSymbols() {
        let routes = AppRoute.primaryRoutes

        XCTAssertEqual(routes.map(\.title), [
            "Projects",
            "Needs Review",
            "Notifications",
            "Settings",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "folder",
            "checkmark.bubble",
            "bell",
            "gearshape",
        ])
    }

    func testProjectRoutesRetainTheirProjectAndExposeExpectedLabels() {
        let projectID = ProjectID(rawValue: "project-42")
        let routes = AppRoute.projectRoutes(for: projectID)

        XCTAssertEqual(routes, [
            .projectOverview(projectID),
            .phaseBoard(projectID),
            .dependencies(projectID),
            .activity(projectID),
        ])
        XCTAssertEqual(routes.map(\.title), [
            "Overview",
            "Phase Board",
            "Dependencies",
            "Activity",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "rectangle.grid.1x2",
            "rectangle.split.3x1",
            "arrow.triangle.branch",
            "clock.arrow.circlepath",
        ])
    }

    @MainActor
    func testOpeningNonFirstProjectKeepsEveryProjectRouteInThatContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ProjectRoutes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed route projects") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-a', 'Alpha')")
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-b', 'Beta')")
        }
        let first = ProjectDashboardProjection(
            id: ProjectID(rawValue: "project-a"),
            name: "Alpha",
            activePhaseName: "Alpha phase",
            goalContext: GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            ),
            currentWorkCount: 1,
            attentionCount: 0
        )
        let second = ProjectDashboardProjection(
            id: ProjectID(rawValue: "project-b"),
            name: "Beta",
            activePhaseName: "Beta phase",
            goalContext: GoalContextProjection(
                linkQuality: .verified,
                text: "Ship Beta",
                status: "In progress",
                lastObservedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            currentWorkCount: 2,
            attentionCount: 1
        )
        let model = AppModel(store: store)
        model.dashboard = DashboardProjection(projects: [first, second], boards: [:])

        XCTAssertEqual(model.currentProjectID, first.id)

        await model.openProject(second.id)

        XCTAssertEqual(model.currentProjectID, second.id)
        XCTAssertEqual(model.currentProject?.name, "Beta")
        XCTAssertEqual(AppRoute.projectRoutes(for: model.currentProjectID), [
            .projectOverview(second.id),
            .phaseBoard(second.id),
            .dependencies(second.id),
            .activity(second.id),
        ])

        for route in [
            AppRoute.phaseBoard(second.id),
            .dependencies(second.id),
            .activity(second.id),
        ] {
            model.selection = route
            XCTAssertEqual(model.currentProjectID, second.id)
            XCTAssertEqual(model.currentProject?.name, "Beta")
        }

        model.selection = .projects
        XCTAssertEqual(model.currentProjectID, second.id)
    }

    @MainActor
    func testEmptyDashboardRejectsFabricatedProjectNavigationWithoutAuditOrGlobalError() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-EmptyRoute-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false
        )

        await model.loadDashboard()

        XCTAssertEqual(model.dashboard?.projects.count, 0)
        XCTAssertNil(model.currentProject)
        let auditCountBefore = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }

        await model.navigate(to: .projectOverview(DashboardSampleData.projectID))

        let auditCountAfter = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }
        XCTAssertEqual(model.selection, .projects)
        XCTAssertNil(model.dashboardError)
        XCTAssertEqual(auditCountAfter, auditCountBefore)
    }

    @MainActor
    func testDirectProjectRoutePersistsDashboardOpenBeforeNotificationEligibility() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-DirectRoute-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "project-direct")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed direct-route project") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-direct', 'Direct', 0)")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-direct', 'project-direct', ?)", bindings: [.text(projectRoot.path)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-direct', 'project-direct', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('DIRECT-1', 'project-direct', 'phase-direct', 'Direct navigation', 'in_progress')")
        }
        let notificationDispatcher = PushoverNotificationDispatcher(
            store: store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: RouteCountingTransport()
        )
        let coordinator = AppNotificationCoordinator(store: store, dispatcher: notificationDispatcher)
        let model = AppModel(
            store: store,
            notificationCoordinator: coordinator,
            externalServicesSuppressed: true
        )

        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(projectID))
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: projectID, canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
        ])
        let result = await AgentCommandDispatcher(store: store, projectRegistry: registry).dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "91919191-9191-4191-8191-919191919191")!,
            projectRoot: projectRoot.path,
            reason: "Request review after direct navigation",
            command: .requestReview(id: "direct-review", ticketID: "DIRECT-1", kind: "agent_request", summary: "Review")
        ))
        XCTAssertNil(result.error)

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = 'project-direct'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-direct'"),
                try connection.scalarInt(
                    """
                    SELECT COUNT(*) FROM audit_events
                    WHERE actor_id = 'release-radar-owner'
                      AND reason = 'Open project dashboard'
                      AND project_id = 'project-direct'
                    """
                )
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
    }

    @MainActor
    private func reviewRecoveryState(
        store: DeliveryStore
    ) async throws -> (status: String?, decisionAudits: Int64?, commandRows: Int64?) {
        try await store.read { connection in
            (
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'duplicate-review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Resolve review duplicate-review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
    }

    @MainActor
    private var attachmentRouteProjectID: ProjectID {
        ProjectID(rawValue: "project-attach-target")
    }

    @MainActor
    private func seedAttachmentRouteProjects(in store: DeliveryStore) async throws {
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = attachmentRouteProjectID
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed attachment route target") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Zulu Attach Target', 0)",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES ('attach-route-phase', ?, 'Attach Phase')",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO project_active_phases (project_id, phase_id) VALUES (?, 'attach-route-phase')",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ATTACH-1', ?, 'attach-route-phase', 'Attach an existing project folder.', 'in_progress')",
                bindings: [.text(projectID.rawValue)]
            )
        }
    }

    @MainActor
    private func attachmentRouteState(
        store: DeliveryStore
    ) async throws -> (
        roots: Int64?, bookmarks: Int64?, attachmentAudits: Int64?, dashboardOpenAudits: Int64?,
        firstDashboardOpened: Int64?, onboardingOrImportAudits: Int64?
    ) {
        let projectID = attachmentRouteProjectID
        return try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM project_roots WHERE project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM project_bookmarks WHERE project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE project_id = ? AND actor_id = 'release-radar-owner' AND reason = 'Associate first project folder authorization'",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE project_id = ? AND reason = 'Open project dashboard'",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT first_dashboard_opened FROM projects WHERE id = ?",
                    bindings: [.text(projectID.rawValue)]
                ),
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE project_id = ? AND (reason LIKE '%onboarding%' OR reason LIKE 'Import%')",
                    bindings: [.text(projectID.rawValue)]
                )
            )
        }
    }

    func testPluginSettingsActionHierarchyAndBusyCopy() {
        XCTAssertEqual(CodexPluginSettingsPresentation(state: .notInstalled).actions, [.install])
        XCTAssertEqual(CodexPluginSettingsPresentation(state: .installed(version: "0.1.0")).actions, [.remove])
        XCTAssertEqual(
            CodexPluginSettingsPresentation(state: .updateAvailable(installed: "0.0.9", shipped: "0.1.0")).actions,
            [.update, .remove]
        )
        XCTAssertEqual(CodexPluginSettingsPresentation(state: .modified(version: "0.1.0")).actions, [.reinstall, .remove])
        XCTAssertEqual(CodexPluginSettingsPresentation(state: .needsRepair).actions, [.reinstall, .remove])
        XCTAssertEqual(CodexPluginSettingsPresentation(state: .failed(.timeout)).actions, [.tryAgain])
        XCTAssertEqual(CodexPluginSettingsPresentation(state: .checking).actions, [])
        XCTAssertEqual(
            CodexPluginSettingsPresentation(state: .installed(version: "0.1.0"), operation: .reinstall).status,
            "Reinstalling plugin"
        )
        XCTAssertEqual(
            CodexPluginSettingsPresentation(state: .installed(version: "0.1.0"), operation: .reinstall).actions,
            []
        )
    }

    func testPluginSettingsKeepsLiveObservationSeparate() {
        let plugin = CodexPluginSettingsPresentation(state: .installed(version: "0.1.0"))
        let observation = CodexConnectionPresentation(
            freshness: CodexSnapshot.unavailable(reason: "No live attachment").freshness
        )
        XCTAssertEqual(plugin.status, "Installed")
        XCTAssertEqual(observation.status, "Unavailable")
    }

    @MainActor
    func testPluginLaunchUpdateRunsOnceAndSuppressedLaunchNeverCallsHelper() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AppPluginLaunch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        try await lifecycleStore.recordVerified(
            .init(
                intent: .managedInstalled,
                managedVersion: "0.1.2",
                managedDigest: "old",
                verifiedAt: Date(timeIntervalSince1970: 1)
            ),
            reason: "Install Release Radar Codex plugin"
        )
        let manager = AppLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .clean(version: "0.1.2", digest: "old"), error: nil),
            .init(wireVersion: 1, observedState: .clean(version: "0.1.3", digest: "current"), error: nil),
            .init(wireVersion: 1, observedState: .clean(version: "0.1.3", digest: "current"), error: nil),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: lifecycleStore,
            shippedVersion: "0.1.3",
            shippedDigest: "current"
        )
        let model = AppModel(
            store: store,
            codexPluginCoordinator: coordinator,
            codexPluginShippedVersion: "0.1.3"
        )

        await model.initializeCodexPluginLifecycleForLaunch()
        await model.initializeCodexPluginLifecycleForLaunch()

        let calls = await manager.operations()
        XCTAssertEqual(calls, [.status, .install, .status])
        XCTAssertEqual(model.codexPluginState, .installed(version: "0.1.3"))
        XCTAssertEqual(model.codexPluginSettingsMessage, "Start a new Codex task to load the plugin change.")

        let suppressedManager = AppLifecycleManager(replies: [])
        let suppressedModel = AppModel(
            store: store,
            codexPluginCoordinator: .init(
                manager: suppressedManager,
                store: lifecycleStore,
                shippedVersion: "0.1.3",
                shippedDigest: "current"
            ),
            externalServicesSuppressed: true
        )
        await suppressedModel.initializeCodexPluginLifecycleForLaunch()
        let suppressedCalls = await suppressedManager.operations()
        XCTAssertEqual(suppressedCalls, [])
        XCTAssertEqual(suppressedModel.codexPluginState, .notInstalled)
    }

    @MainActor
    func testAppLaunchChecksPluginOnlyAfterDashboardLoad() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AppPluginLaunchOrder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        try await lifecycleStore.recordVerified(
            .init(
                intent: .managedInstalled,
                managedVersion: "0.1.0",
                managedDigest: "current",
                verifiedAt: Date(timeIntervalSince1970: 1)
            ),
            reason: "Install Release Radar Codex plugin"
        )
        let events = LaunchOrderRecorder()
        let model = AppModel(
            store: store,
            codexObserver: LaunchOrderCodexObserver(events: events),
            codexPluginCoordinator: .init(
                manager: LaunchOrderLifecycleManager(events: events),
                store: lifecycleStore,
                shippedVersion: "0.1.0",
                shippedDigest: "current"
            ),
            dashboardLoader: { _ in
                await events.record(.dashboard)
                return DashboardProjection(projects: [], boards: [:])
            }
        )

        await model.initializeForLaunch()

        let recordedEvents = await events.snapshot()
        XCTAssertEqual(recordedEvents, [.codexObservation, .dashboard, .pluginStatus])
    }

    func testRR9CapturePolicyRequiresDebugCaptureEmptyStoreAndOneKnownScenario() {
        let required = ["--rr10-capture", "--rr10-empty-store"]
        let recognized: [(String, RR9ActivePhaseCaptureScenario)] = [
            ("happy", .happy),
            ("busy", .busy),
            ("no-alternative", .noAlternative),
            ("mutation-failure", .mutationFailure),
            ("unavailable", .unavailable),
            ("authorization-failure", .authorizationFailure),
            ("saved-refresh", .savedRefresh),
            ("empty-phase", .emptyPhase),
            ("no-active-pointer", .noActivePointer),
            ("cross-phase-detail", .crossPhaseDetail),
        ]
        for (argument, scenario) in recognized {
            XCTAssertEqual(
                AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
                    arguments: required + ["--rr9-active-phase-fixture=\(argument)"],
                    isDebugBuild: true
                ),
                scenario
            )
        }
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: ["--rr10-empty-store", "--rr9-active-phase-fixture=happy"],
            isDebugBuild: true
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: ["--rr10-capture", "--rr9-active-phase-fixture=happy"],
            isDebugBuild: true
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: required + ["--rr10-capture", "--rr9-active-phase-fixture=happy"],
            isDebugBuild: true
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: required + ["--rr10-empty-store", "--rr9-active-phase-fixture=happy"],
            isDebugBuild: true
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: required + ["--rr9-active-phase-fixture=unknown"],
            isDebugBuild: true
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: required + [
                "--rr9-active-phase-fixture=happy",
                "--rr9-active-phase-fixture=busy",
            ],
            isDebugBuild: true
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: required + ["--rr9-active-phase-fixture=happy"],
            isDebugBuild: false
        ))
        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
            arguments: required,
            isDebugBuild: true
        ))
    }

    func testActivePhaseSelectorPresentationDistinguishesSelectionBusyAndNoAlternative() {
        let phase = ProjectPhaseProjection(id: .init(rawValue: "phase-only"), name: "Roadmap")
        let project = ProjectDashboardProjection(
            id: .init(rawValue: "selector-project"),
            name: "Selector",
            activePhaseID: phase.id,
            activePhaseName: phase.name,
            phases: [phase],
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )

        XCTAssertEqual(ActivePhaseSelectorSurface.overview.accessibilityIdentifier, "active-phase-selector-overview")
        XCTAssertEqual(ActivePhaseSelectorSurface.board.accessibilityIdentifier, "active-phase-selector-board")
        XCTAssertEqual(
            ActivePhaseSelectorPresentation(project: project, status: .idle).accessibilityValue,
            "Roadmap (phase-only)"
        )
        XCTAssertEqual(
            ActivePhaseSelectorPresentation(project: project, status: .idle).accessibilityHelp,
            "No other phases are available for this project."
        )
        XCTAssertTrue(ActivePhaseSelectorPresentation(project: project, status: .idle).isDisabled)
        XCTAssertEqual(
            ActivePhaseSelectorPresentation(project: project, status: .saving(phase.id)).accessibilityValue,
            "Saving active phase"
        )

        let unselected = ProjectDashboardProjection(
            id: project.id,
            name: project.name,
            activePhaseID: nil,
            activePhaseName: "No active phase",
            phases: [phase],
            goalContext: project.goalContext,
            currentWorkCount: 0,
            attentionCount: 0
        )
        XCTAssertEqual(
            ActivePhaseSelectorPresentation(project: unselected, status: .idle).accessibilityValue,
            "No active phase"
        )
        XCTAssertFalse(ActivePhaseSelectorPresentation(project: unselected, status: .idle).isDisabled)
    }

    @MainActor
    func testOwnerTicketTransitionAppliesAcceptanceMatrixAndReloadsOnlyAfterSuccess() async throws {
        struct Scenario {
            let name: String
            let lane: TicketLane
            let plan: Task4AOwnerPlanState
            let revision: Int64?
            let succeeds: Bool
        }
        let scenarios = [
            Scenario(name: "no plan omitted", lane: .backlog, plan: .none, revision: nil, succeeds: true),
            Scenario(name: "no plan present", lane: .backlog, plan: .none, revision: 1, succeeds: false),
            Scenario(name: "loaded plan omitted", lane: .backlog, plan: .pending, revision: nil, succeeds: false),
            Scenario(name: "loaded plan stale", lane: .backlog, plan: .pending, revision: 2, succeeds: false),
            Scenario(name: "pending exact", lane: .backlog, plan: .pending, revision: 1, succeeds: false),
            Scenario(name: "completed exact", lane: .needsReview, plan: .completed, revision: 2, succeeds: true),
            Scenario(name: "terminal", lane: .accepted, plan: .none, revision: nil, succeeds: false),
        ]

        for scenario in scenarios {
            let fixture = try await makeRR9OwnerFixture()
            try await Self.prepareTask4AOwnerTicket(
                store: fixture.store,
                lane: scenario.lane,
                plan: scenario.plan
            )
            let requestIDs = RR9RequestIDCounter()
            let dashboardLoads = RR9DashboardLoadCounter()
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                dashboardLoader: { store in
                    dashboardLoads.record()
                    return try await DashboardProjection.load(from: store)
                },
                requestIDGenerator: { requestIDs.next() },
                externalServicesSuppressed: true
            )
            let before = try await Self.task4AOwnerTransitionState(fixture.store)

            let result = try await model.transitionTicket(
                projectID: fixture.projectID,
                ticketID: .init(rawValue: "ROAD-1"),
                to: .accepted,
                ticketTaskPlanRevision: scenario.revision
            )
            let after = try await Self.task4AOwnerTransitionState(fixture.store)

            XCTAssertEqual(requestIDs.count, 1, scenario.name)
            if scenario.succeeds {
                XCTAssertNil(result.error, scenario.name)
                XCTAssertEqual(after.lane, TicketLane.accepted.rawValue, scenario.name)
                XCTAssertEqual(after.requestCount, before.requestCount + 1, scenario.name)
                XCTAssertEqual(after.auditCount, before.auditCount + 1, scenario.name)
                XCTAssertEqual(after.actorID, "release-radar-owner", scenario.name)
                XCTAssertEqual(dashboardLoads.count, 1, scenario.name)
            } else {
                XCTAssertNotNil(result.error, scenario.name)
                XCTAssertEqual(after, before, scenario.name)
                XCTAssertEqual(dashboardLoads.count, 0, scenario.name)
            }
        }
    }

    @MainActor
    func testOwnerTicketTransitionPreflightsEmbeddedNULBeforeRequestAuthorizationAndReload() async throws {
        let fixture = try await makeRR9OwnerFixture(hasBookmark: false)
        let requestIDs = RR9RequestIDCounter()
        let dashboardLoads = RR9DashboardLoadCounter()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            dashboardLoader: { store in
                dashboardLoads.record()
                return try await DashboardProjection.load(from: store)
            },
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        let before = try await Self.task4AOwnerTransitionState(fixture.store)
        var errors: [AgentCommandError] = []

        for ticketID in ["ROAD-1\0suffix", "OTHER-TICKET\0suffix", "MISSING\0suffix"] {
            let result = try await model.transitionTicket(
                projectID: fixture.projectID,
                ticketID: .init(rawValue: ticketID),
                to: .accepted
            )
            if let error = result.error {
                errors.append(error)
            } else {
                XCTFail("Expected embedded-NUL owner transition to reject")
            }
        }

        let after = try await Self.task4AOwnerTransitionState(fixture.store)
        XCTAssertEqual(errors.count, 3)
        XCTAssertTrue(errors.allSatisfy { $0 == errors.first })
        guard case .invalidEnvelope? = errors.first else {
            return XCTFail("Expected identical invalidEnvelope errors, got \(errors)")
        }
        XCTAssertEqual(requestIDs.count, 0)
        XCTAssertEqual(dashboardLoads.count, 0)
        XCTAssertEqual(after, before)
    }

    @MainActor
    func testOwnerTicketTransitionAuthorizationFailureCreatesNoCommandOrReload() async throws {
        let fixture = try await makeRR9OwnerFixture(hasBookmark: false)
        let requestIDs = RR9RequestIDCounter()
        let dashboardLoads = RR9DashboardLoadCounter()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            dashboardLoader: { store in
                dashboardLoads.record()
                return try await DashboardProjection.load(from: store)
            },
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        let before = try await Self.task4AOwnerTransitionState(fixture.store)

        do {
            _ = try await model.transitionTicket(
                projectID: fixture.projectID,
                ticketID: .init(rawValue: "ROAD-1"),
                to: .accepted
            )
            XCTFail("Expected missing bookmark authorization failure")
        } catch {
            XCTAssertEqual(error as? ProjectAuthorizationError, .bookmarkMissing)
        }

        let after = try await Self.task4AOwnerTransitionState(fixture.store)
        XCTAssertEqual(requestIDs.count, 1)
        XCTAssertEqual(dashboardLoads.count, 0)
        XCTAssertEqual(after, before)
    }

    @MainActor
    func testOwnerActivePhaseSelectionPublishesCoherentProjectionAndPersistsAcrossModelRelaunch() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let requestIDs = RR9RequestIDCounter()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        model.selectedTicketID = .init(rawValue: "CURRENT-1")

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

        XCTAssertEqual(requestIDs.count, 1)
        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(model.dashboard?.board(for: fixture.projectID)?.lanes.map(\.count), [2, 0, 0, 1, 0])
        XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(model.activity(for: fixture.projectID)?.items.first?.detail, "Owner selected active phase phase-roadmap")
        let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(state.activePhaseID, fixture.roadmapPhaseID.rawValue)
        XCTAssertEqual(state.commandRequests, 1)
        XCTAssertEqual(state.selectionAudits, 1)
        XCTAssertEqual(state.actorID, "release-radar-owner")

        let relaunched = AppModel(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await relaunched.loadDashboard()
        XCTAssertEqual(relaunched.currentProject?.activePhaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(relaunched.dashboard?.board(for: fixture.projectID)?.lanes.map(\.count), [2, 0, 0, 1, 0])
    }

    @MainActor
    func testAlreadyActiveOwnerCallReturnsBeforeUUIDAuthorizationRequestAndAudit() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let requestIDs = RR9RequestIDCounter()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        let before = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.currentPhaseID)

        let after = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(requestIDs.count, 0)
        XCTAssertEqual(after, before)
        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
    }

    @MainActor
    func testSavingOwnerCallRejectsDuplicateBeforeSecondUUIDRequestAndAudit() async throws {
        let fixture = try await makeRR9OwnerFixture(blockAuthorization: true)
        let requestIDs = RR9RequestIDCounter()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await fixture.bookmarks.armAccessGate()

        let first = Task {
            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        }
        await fixture.bookmarks.waitUntilAccessEntered()
        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .saving(fixture.roadmapPhaseID))

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.emptyPhaseID)

        XCTAssertEqual(requestIDs.count, 1)
        let whileSaving = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(whileSaving.commandRequests, 0)
        XCTAssertEqual(whileSaving.selectionAudits, 0)
        await fixture.bookmarks.releaseAccess()
        await first.value
        let final = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(final.commandRequests, 1)
        XCTAssertEqual(final.selectionAudits, 1)
    }

    @MainActor
    func testSavedNeedsReloadRejectsMutationAndRecoversThroughReadOnlyReload() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let requestIDs = RR9RequestIDCounter()
        let loader = RouteDashboardLoader(failingCalls: [2])
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            dashboardLoader: { store in try await loader.load(from: store) },
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

        XCTAssertEqual(
            model.activePhaseSelectionStatus(for: fixture.projectID),
            .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
        )
        let committed = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(committed.commandRequests, 1)
        XCTAssertEqual(committed.selectionAudits, 1)
        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.emptyPhaseID)

        XCTAssertEqual(requestIDs.count, 1)
        let afterRejectedSelection = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(afterRejectedSelection, committed)
        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(requestIDs.count, 1)
        let afterReload = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(afterReload, committed)
    }

    @MainActor
    func testExternalCommittedRefreshReusesCachedGuidanceWithoutBookmarkOrAuditMutation() async throws {
        let mismatchedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9-ExternalRefreshMismatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
        let failures: [RR9BookmarkFailureMode] = [
            .resolutionFailure,
            .stale,
            .mismatchedRoot(mismatchedRoot),
            .accessDenied,
        ]

        for failure in failures {
            let fixture = try await makeRR9OwnerFixture()
            let requestIDs = RR9RequestIDCounter()
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                requestIDGenerator: { requestIDs.next() },
                externalServicesSuppressed: true
            )
            await model.loadDashboard()

            let storeBefore = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
            let dashboardBefore = model.dashboard
            let activityBefore = model.activity(for: fixture.projectID)
            let errorBefore = model.dashboardError
            let statusBefore = model.activePhaseSelectionStatus(for: fixture.projectID)
            let guidanceBefore = model.projectGuidanceState(for: fixture.projectID)
            let rootBefore = model.projectRoot(for: fixture.projectID)
            XCTAssertEqual(guidanceBefore, .missing)
            XCTAssertEqual(rootBefore, fixture.projectRoot)
            fixture.bookmarks.setFailureMode(failure)

            await model.reloadDashboardAfterCommittedAgentCommand()

            let storeAfter = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
            XCTAssertEqual(storeAfter, storeBefore, "Failure: \(failure)")
            XCTAssertEqual(model.dashboard, dashboardBefore, "Failure: \(failure)")
            XCTAssertEqual(model.activity(for: fixture.projectID), activityBefore, "Failure: \(failure)")
            XCTAssertEqual(model.dashboardError, errorBefore, "Failure: \(failure)")
            XCTAssertEqual(
                model.activePhaseSelectionStatus(for: fixture.projectID),
                statusBefore,
                "Failure: \(failure)"
            )
            XCTAssertEqual(
                model.projectGuidanceState(for: fixture.projectID),
                guidanceBefore,
                "Failure: \(failure)"
            )
            XCTAssertEqual(model.projectRoot(for: fixture.projectID), rootBefore, "Failure: \(failure)")
            XCTAssertEqual(requestIDs.count, 0, "Failure: \(failure)")
        }
    }

    @MainActor
    func testOwnerSavedRefreshReusesCachedGuidanceWithoutBookmarkAuditOrCommandRetry() async throws {
        let mismatchedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9-SavedRefreshMismatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
        let failures: [RR9BookmarkFailureMode] = [
            .resolutionFailure,
            .stale,
            .mismatchedRoot(mismatchedRoot),
            .accessDenied,
        ]

        for failure in failures {
            let fixture = try await makeRR9OwnerFixture()
            let requestIDs = RR9RequestIDCounter()
            let loader = RouteDashboardLoader(failingCalls: [2])
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                dashboardLoader: { store in try await loader.load(from: store) },
                requestIDGenerator: { requestIDs.next() },
                externalServicesSuppressed: true
            )
            await model.loadDashboard()
            let guidanceBefore = model.projectGuidanceState(for: fixture.projectID)
            let rootBefore = model.projectRoot(for: fixture.projectID)
            XCTAssertEqual(guidanceBefore, .missing)
            XCTAssertEqual(rootBefore, fixture.projectRoot)

            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

            XCTAssertEqual(
                model.activePhaseSelectionStatus(for: fixture.projectID),
                .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
            )
            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
            let dashboardBefore = model.dashboard
            let activityBefore = model.activity(for: fixture.projectID)
            let errorBefore = model.dashboardError
            let storeBefore = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
            let expectedDashboard = try await DashboardProjection.load(from: fixture.store)
            let expectedActivity = try await ProjectActivityProjection.load(
                from: fixture.store,
                projectID: fixture.projectID
            )
            fixture.bookmarks.setFailureMode(failure)

            await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)

            let storeAfter = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
            XCTAssertEqual(storeAfter, storeBefore, "Failure: \(failure)")
            XCTAssertNotEqual(model.dashboard, dashboardBefore, "Failure: \(failure)")
            XCTAssertEqual(model.dashboard, expectedDashboard, "Failure: \(failure)")
            XCTAssertNotEqual(model.activity(for: fixture.projectID), activityBefore, "Failure: \(failure)")
            XCTAssertEqual(
                model.activity(for: fixture.projectID),
                expectedActivity,
                "Failure: \(failure)"
            )
            XCTAssertEqual(model.dashboardError, errorBefore, "Failure: \(failure)")
            XCTAssertNil(model.dashboardError, "Failure: \(failure)")
            XCTAssertEqual(
                model.activePhaseSelectionStatus(for: fixture.projectID),
                .idle,
                "Failure: \(failure)"
            )
            XCTAssertEqual(
                model.projectGuidanceState(for: fixture.projectID),
                guidanceBefore,
                "Failure: \(failure)"
            )
            XCTAssertEqual(model.projectRoot(for: fixture.projectID), rootBefore, "Failure: \(failure)")
            XCTAssertEqual(requestIDs.count, 1, "Failure: \(failure)")
        }
    }

    @MainActor
    func testPostCommitWorkspacePreparationFailurePublishesNoPartialDashboardBeforeReadOnlyRecovery() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let reviewLoader = RR9SequencedReviewInboxLoader(failingCalls: [2])
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            reviewInboxLoader: { store, projectID in
                try await reviewLoader.load(from: store, projectID: projectID)
            },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        let dashboard = model.dashboard
        let graph = model.dependencyGraph(for: fixture.projectID)
        let activity = model.activity(for: fixture.projectID)
        let guidance = model.projectGuidanceState(for: fixture.projectID)
        let root = model.projectRoot(for: fixture.projectID)
        let selectedTicketID = model.selectedTicketID

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

        XCTAssertEqual(
            model.activePhaseSelectionStatus(for: fixture.projectID),
            .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
        )
        XCTAssertEqual(model.dashboard, dashboard)
        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID), graph)
        XCTAssertEqual(model.activity(for: fixture.projectID), activity)
        XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), guidance)
        XCTAssertEqual(model.projectRoot(for: fixture.projectID), root)
        XCTAssertEqual(model.selectedTicketID, selectedTicketID)

        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)

        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
        let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(state.commandRequests, 1)
        XCTAssertEqual(state.selectionAudits, 1)
    }

    @MainActor
    func testAuthorizationRecoveryRestoresOnlyExactRootAndNeverRetriesSelection() async throws {
        let fixture = try await makeRR9OwnerFixture(hasBookmark: false)
        let requestIDs = RR9RequestIDCounter()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            requestIDGenerator: { requestIDs.next() },
            externalServicesSuppressed: true
        )
        await model.loadDashboard()

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

        guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(for: fixture.projectID) else {
            return XCTFail("Expected phase authorization recovery")
        }
        XCTAssertEqual(presentation.accessibilityID, "active-phase-authorization-failed")
        XCTAssertTrue(canReauthorize)
        XCTAssertEqual(requestIDs.count, 1)
        let failedSelection = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(failedSelection.commandRequests, 0)

        await model.reauthorizeActivePhaseProject(at: fixture.projectRoot, projectID: fixture.projectID)

        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
        let reauthorized = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(reauthorized.commandRequests, 0)
        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(requestIDs.count, 2)
    }

    @MainActor
    func testRejectedReauthorizationFoldersFailClosedAndPreserveLocateRecovery() async throws {
        for rejectedFolderKind in ["parent", "child", "different"] {
            let fixture = try await makeRR9OwnerFixture(hasBookmark: false)
            let child = fixture.projectRoot.appendingPathComponent("child", isDirectory: true)
            let different = fixture.projectRoot.deletingLastPathComponent()
                .appendingPathComponent("different", isDirectory: true)
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: different, withIntermediateDirectories: true)
            let rejectedFolder = switch rejectedFolderKind {
            case "parent": fixture.projectRoot.deletingLastPathComponent()
            case "child": child
            default: different
            }
            let requestIDs = RR9RequestIDCounter()
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                requestIDGenerator: { requestIDs.next() },
                externalServicesSuppressed: true
            )
            await model.loadDashboard()
            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
            let beforeRejectedAttempt = try await rr9SelectionState(
                store: fixture.store,
                projectID: fixture.projectID
            )
            let auditCountBeforeRejectedAttempt = try await fixture.store.read { connection in
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1
            }

            await model.reauthorizeActivePhaseProject(
                at: rejectedFolder,
                projectID: fixture.projectID
            )

            guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(
                for: fixture.projectID
            ) else {
                XCTFail("Expected rejected \(rejectedFolderKind) folder to remain recoverable")
                continue
            }
            XCTAssertEqual(presentation.accessibilityID, "active-phase-authorization-failed")
            guard canReauthorize else {
                XCTFail("Expected Locate to remain actionable after rejected \(rejectedFolderKind) folder")
                continue
            }
            XCTAssertEqual(requestIDs.count, 1)
            let afterRejectedAttempt = try await rr9SelectionState(
                store: fixture.store,
                projectID: fixture.projectID
            )
            let auditCountAfterRejectedAttempt = try await fixture.store.read { connection in
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1
            }
            XCTAssertEqual(afterRejectedAttempt, beforeRejectedAttempt)
            XCTAssertEqual(auditCountAfterRejectedAttempt, auditCountBeforeRejectedAttempt)

            await model.reauthorizeActivePhaseProject(
                at: fixture.projectRoot,
                projectID: fixture.projectID
            )

            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
            XCTAssertEqual(requestIDs.count, 1)
            let afterRecovery = try await rr9SelectionState(
                store: fixture.store,
                projectID: fixture.projectID
            )
            XCTAssertEqual(afterRecovery.activePhaseID, fixture.currentPhaseID.rawValue)
            XCTAssertEqual(afterRecovery.commandRequests, 0)
            XCTAssertEqual(afterRecovery.selectionAudits, 0)
        }
    }

    @MainActor
    func testEveryRecoverableBookmarkFailureFailsClosedBeforePhaseMutation() async throws {
        let mismatchedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9-Mismatched-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
        let failures: [RR9BookmarkFailureMode] = [
            .stale,
            .resolutionFailure,
            .accessDenied,
            .mismatchedRoot(mismatchedRoot),
        ]

        for failure in failures {
            let fixture = try await makeRR9OwnerFixture()
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                externalServicesSuppressed: true
            )
            await model.loadDashboard()
            fixture.bookmarks.setFailureMode(failure)

            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

            guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(for: fixture.projectID) else {
                return XCTFail("Expected recoverable authorization failure for \(failure)")
            }
            XCTAssertEqual(presentation.accessibilityID, "active-phase-authorization-failed")
            XCTAssertTrue(canReauthorize)
            let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
            XCTAssertEqual(state.activePhaseID, fixture.currentPhaseID.rawValue)
            XCTAssertEqual(state.commandRequests, 0)
            XCTAssertEqual(state.selectionAudits, 0)
        }
    }

    @MainActor
    func testDirectInvalidTargetShowsTypedFailureWithoutChangingCoherentProjection() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        let dashboard = model.dashboard
        let dependencyGraph = model.dependencyGraph(for: fixture.projectID)

        await model.setActivePhase(
            projectID: fixture.projectID,
            phaseID: PhaseID(rawValue: "phase-does-not-exist")
        )

        guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(for: fixture.projectID) else {
            return XCTFail("Expected a typed mutation failure")
        }
        XCTAssertEqual(presentation.accessibilityID, "active-phase-mutation-failed")
        XCTAssertFalse(canReauthorize)
        XCTAssertEqual(model.dashboard, dashboard)
        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID), dependencyGraph)
        let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(state.activePhaseID, fixture.currentPhaseID.rawValue)
        XCTAssertEqual(state.commandRequests, 0)
        XCTAssertEqual(state.selectionAudits, 0)
    }

    @MainActor
    func testProjectWithoutActivePointerCanEstablishItFromEitherOwnerRoute() async throws {
        let routes: [(ProjectID) -> AppRoute] = [
            { .projectOverview($0) },
            { .phaseBoard($0) },
        ]

        for route in routes {
            let fixture = try await makeRR9OwnerFixture(hasActivePointer: false)
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                externalServicesSuppressed: true
            )
            await model.loadDashboard()
            model.selection = route(fixture.projectID)
            XCTAssertNil(model.currentProject?.activePhaseID)
            XCTAssertNil(model.dashboard?.board(for: fixture.projectID))

            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.currentPhaseID)

            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
            XCTAssertEqual(model.dashboard?.board(for: fixture.projectID)?.phaseID, fixture.currentPhaseID)
            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
            let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
            XCTAssertEqual(state.commandRequests, 1)
            XCTAssertEqual(state.selectionAudits, 1)
        }
    }

    @MainActor
    func testEmptyTargetRemovesVisibleDetailAndDependencyGraphWithoutStaleBoardState() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        XCTAssertNotNil(model.dependencyGraph(for: fixture.projectID))

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.emptyPhaseID)

        let board = try XCTUnwrap(model.dashboard?.board(for: fixture.projectID))
        XCTAssertEqual(board.phaseID, fixture.emptyPhaseID)
        XCTAssertEqual(board.lanes.map(\.count), [0, 0, 0, 0, 0])
        XCTAssertTrue(board.details.isEmpty)
        XCTAssertNil(board.detail(for: model.selectedTicketID))
        XCTAssertNil(model.dependencyGraph(for: fixture.projectID))
        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
    }

    @MainActor
    func testCurrentGenerationTargetMismatchPreservesSavingAndSavedRecoveryStatus() async throws {
        for failingCommittedReload in [false, true] {
            let fixture = try await makeRR9OwnerFixture()
            let loader = RR9TargetMismatchDashboardLoader(failCommittedReload: failingCommittedReload)
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                dashboardLoader: { store in try await loader.load(from: store) },
                externalServicesSuppressed: true
            )
            await model.loadDashboard()

            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

            if failingCommittedReload {
                XCTAssertEqual(
                    model.activePhaseSelectionStatus(for: fixture.projectID),
                    .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
                )
                await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
                XCTAssertEqual(
                    model.activePhaseSelectionStatus(for: fixture.projectID),
                    .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
                )
            } else {
                XCTAssertEqual(
                    model.activePhaseSelectionStatus(for: fixture.projectID),
                    .saving(fixture.roadmapPhaseID)
                )
                await model.reloadDashboardAfterCommittedAgentCommand()
                XCTAssertEqual(
                    model.activePhaseSelectionStatus(for: fixture.projectID),
                    .saving(fixture.roadmapPhaseID)
                )
            }
            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
            let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
            XCTAssertEqual(state.activePhaseID, fixture.roadmapPhaseID.rawValue)
            XCTAssertEqual(state.commandRequests, 1)
            XCTAssertEqual(state.selectionAudits, 1)
        }
    }

    @MainActor
    func testNewerAgentReloadWinsOverOlderOwnerReloadSuccessOrFailure() async throws {
        for staleCompletion in RR9StaleCompletion.allCases {
            let fixture = try await makeRR9OwnerFixture()
            let loader = RR9InterleavingDashboardLoader(staleCompletion: staleCompletion)
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                dashboardLoader: { store in try await loader.load(from: store) },
                externalServicesSuppressed: true
            )
            await model.loadDashboard()
            let ownerReload = Task {
                await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
            }
            await loader.waitUntilOlderReloadEntered()

            await model.reloadDashboardAfterCommittedAgentCommand()

            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
            XCTAssertNil(model.dashboardError)
            let publishedDashboard = model.dashboard
            let publishedReviewInbox = model.reviewInbox(for: fixture.projectID)
            let publishedGraph = model.dependencyGraph(for: fixture.projectID)
            let publishedActivity = model.activity(for: fixture.projectID)
            let publishedGuidance = model.projectGuidanceState(for: fixture.projectID)
            let publishedRoot = model.projectRoot(for: fixture.projectID)
            let publishedTicketID = model.selectedTicketID
            let publishedReviewItemID = model.selectedReviewItemID
            await loader.releaseOlderReload()
            await ownerReload.value
            XCTAssertEqual(model.dashboard, publishedDashboard)
            XCTAssertEqual(model.reviewInbox(for: fixture.projectID), publishedReviewInbox)
            XCTAssertEqual(model.dependencyGraph(for: fixture.projectID), publishedGraph)
            XCTAssertEqual(model.activity(for: fixture.projectID), publishedActivity)
            XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), publishedGuidance)
            XCTAssertEqual(model.projectRoot(for: fixture.projectID), publishedRoot)
            XCTAssertEqual(model.selectedTicketID, publishedTicketID)
            XCTAssertEqual(model.selectedReviewItemID, publishedReviewItemID)
            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
            XCTAssertNil(model.dashboardError)
        }
    }

    @MainActor
    func testSupersededLoadDashboardReturnsBeforeDebugRouteAndPublishedStateMutation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9SupersededLoad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let loader = RR9SupersededLoadDashboardLoader()
        let model = AppModel(
            store: store,
            dashboardLoader: { store in try await loader.load(from: store) },
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: .busy,
            rr9ActivePhaseCaptureRootDirectory: directory.appendingPathComponent("RR9ActivePhaseCaptureRoots")
        )
        await model.loadDashboard()
        let initialActivity = model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID)

        let olderLoad = Task { await model.loadDashboard() }
        await loader.waitUntilOlderLoadEntered()
        try await store.transact(
            actor: .init(id: "agent"),
            reason: "Newer agent activity",
            auditEventID: .init(rawValue: "rr9-newer-agent-audit"),
            auditScope: AuditScope(
                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
                entityType: .phase,
                entityID: RR9ActivePhaseCaptureFixture.roadmapPhaseID.rawValue
            )
        ) { _ in }

        await model.reloadDashboardAfterCommittedAgentCommand()
        XCTAssertNotEqual(
            model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
            initialActivity
        )
        model.selection = .phaseBoard(RR9ActivePhaseCaptureFixture.primaryProjectID)
        await model.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
            phaseID: RR9ActivePhaseCaptureFixture.roadmapPhaseID
        )

        let publishedDashboard = model.dashboard
        let publishedActivity = model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID)
        let publishedError = model.dashboardError
        let publishedStatus = model.activePhaseSelectionStatus(
            for: RR9ActivePhaseCaptureFixture.primaryProjectID
        )
        await loader.releaseOlderLoad()
        await olderLoad.value

        XCTAssertEqual(model.selection, .phaseBoard(RR9ActivePhaseCaptureFixture.primaryProjectID))
        XCTAssertEqual(model.dashboard, publishedDashboard)
        XCTAssertEqual(
            model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
            publishedActivity
        )
        XCTAssertEqual(model.dashboardError, publishedError)
        XCTAssertNil(model.dashboardError)
        XCTAssertEqual(
            model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
            publishedStatus
        )
        XCTAssertEqual(publishedStatus, .saving(RR9ActivePhaseCaptureFixture.roadmapPhaseID))
    }

    @MainActor
    func testRR9DebugFixtureSeedsIdempotentlyAndSelectsScenarioRouteWithoutOrdinarySampleData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9Capture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: .crossPhaseDetail,
            rr9ActivePhaseCaptureRootDirectory: directory.appendingPathComponent("RR9ActivePhaseCaptureRoots")
        )

        await model.loadDashboard()
        let first = model.dashboard
        let firstSeedState = try await Self.task4ARR9NormalAcceptanceState(store)
        await model.loadDashboard()
        let secondSeedState = try await Self.task4ARR9NormalAcceptanceState(store)

        XCTAssertEqual(model.dashboard, first)
        XCTAssertEqual(model.selection, .phaseBoard(RR9ActivePhaseCaptureFixture.primaryProjectID))
        XCTAssertEqual(model.currentProject?.phases.count, 6)
        XCTAssertEqual(
            model.dashboard?.board(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?
                .detail(for: RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID)?
                .requires.map(\.id),
            [RR9ActivePhaseCaptureFixture.crossPhaseTargetTicketID]
        )
        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM projects"),
                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(state.0, 7)
        XCTAssertEqual(state.1, 6)
        XCTAssertEqual(state.2, 0)
        XCTAssertEqual(firstSeedState.acceptedTicketIDs, ["RR9-HISTORY"])
        XCTAssertTrue(firstSeedState.planRows.isEmpty)
        XCTAssertTrue(firstSeedState.taskRows.isEmpty)
        XCTAssertEqual(firstSeedState.seedAuditRows, [
            "rr9-capture-seed-audit|release-radar.rr9-capture-seed||none|Seed RR-R9 active phase capture fixture|rr9-capture-primary|phase|phase-current",
        ])
        XCTAssertEqual(secondSeedState, firstSeedState)
        XCTAssertFalse(model.dashboard?.projects.contains { $0.id == DashboardSampleData.projectID } == true)
    }

    @MainActor
    func testRR9DebugFixtureScenariosExposeDeterministicRoutesStatusesAndOneShotRecovery() async throws {
        let noAlternative = try await makeRR9CaptureModel(scenario: .noAlternative)
        XCTAssertEqual(noAlternative.model.selection, .projectOverview(RR9ActivePhaseCaptureFixture.soleProjectID))
        let soleProject = try XCTUnwrap(noAlternative.model.currentProject)
        let solePresentation = ActivePhaseSelectorPresentation(project: soleProject, status: .idle)
        XCTAssertTrue(solePresentation.isDisabled)
        XCTAssertEqual(solePresentation.accessibilityHelp, "No other phases are available for this project.")

        let noPointer = try await makeRR9CaptureModel(scenario: .noActivePointer)
        XCTAssertEqual(noPointer.model.selection, .projectOverview(RR9ActivePhaseCaptureFixture.noPointerProjectID))
        XCTAssertNil(noPointer.model.currentProject?.activePhaseID)
        XCTAssertEqual(noPointer.model.currentProject?.phases.count, 2)
        XCTAssertNil(noPointer.model.dashboard?.board(for: RR9ActivePhaseCaptureFixture.noPointerProjectID))
        XCTAssertEqual(
            ActivePhaseSelectorPresentation(
                project: try XCTUnwrap(noPointer.model.currentProject),
                status: .idle
            ).accessibilityValue,
            "No active phase"
        )

        let empty = try await makeRR9CaptureModel(scenario: .emptyPhase)
        XCTAssertEqual(empty.model.selection, .phaseBoard(RR9ActivePhaseCaptureFixture.emptyProjectID))
        XCTAssertEqual(empty.model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyCurrentPhaseID)
        await empty.model.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.emptyProjectID,
            phaseID: RR9ActivePhaseCaptureFixture.emptyTargetPhaseID
        )
        XCTAssertEqual(empty.model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyTargetPhaseID)
        XCTAssertEqual(
            empty.model.dashboard?.board(for: RR9ActivePhaseCaptureFixture.emptyProjectID)?.lanes.map(\.count),
            [0, 0, 0, 0, 0]
        )
        XCTAssertNil(empty.model.dependencyGraph(for: RR9ActivePhaseCaptureFixture.emptyProjectID))

        let faultCases: [(RR9ActivePhaseCaptureScenario, String)] = [
            (.mutationFailure, "active-phase-mutation-failed"),
            (.unavailable, "active-phase-unavailable"),
        ]
        for (scenario, expectedAccessibilityID) in faultCases {
            let fixture = try await makeRR9CaptureModel(scenario: scenario)
            await fixture.model.setActivePhase(
                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
                phaseID: RR9ActivePhaseCaptureFixture.roadmapPhaseID
            )
            guard case let .mutationFailed(presentation, canReauthorize) = fixture.model.activePhaseSelectionStatus(
                for: RR9ActivePhaseCaptureFixture.primaryProjectID
            ) else {
                return XCTFail("Expected Debug fault presentation for \(scenario)")
            }
            XCTAssertEqual(presentation.accessibilityID, expectedAccessibilityID)
            XCTAssertFalse(canReauthorize)
            let state = try await rr9SelectionState(
                store: fixture.store,
                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID
            )
            XCTAssertEqual(state.commandRequests, 0)
            XCTAssertEqual(state.selectionAudits, 0)
        }

        let busy = try await makeRR9CaptureModel(scenario: .busy)
        await busy.model.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
            phaseID: RR9ActivePhaseCaptureFixture.roadmapPhaseID
        )
        XCTAssertEqual(
            busy.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
            .saving(RR9ActivePhaseCaptureFixture.roadmapPhaseID)
        )
        let busyState = try await rr9SelectionState(
            store: busy.store,
            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID
        )
        XCTAssertEqual(busyState.commandRequests, 0)
        XCTAssertEqual(busyState.selectionAudits, 0)

        let authorization = try await makeRR9CaptureModel(scenario: .authorizationFailure)
        let authorizationTarget = PhaseID(rawValue: "rr9-authorization-target")
        await authorization.model.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.authorizationProjectID,
            phaseID: authorizationTarget
        )
        guard case let .mutationFailed(authorizationFailure, canReauthorize) = authorization.model.activePhaseSelectionStatus(
            for: RR9ActivePhaseCaptureFixture.authorizationProjectID
        ) else {
            return XCTFail("Expected missing-bookmark recovery")
        }
        XCTAssertEqual(authorizationFailure.accessibilityID, "active-phase-authorization-failed")
        XCTAssertTrue(canReauthorize)

        let happy = try await makeRR9CaptureModel(scenario: .happy)
        await happy.model.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.happyProjectID,
            phaseID: RR9ActivePhaseCaptureFixture.happyTargetPhaseID
        )
        XCTAssertEqual(happy.model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.happyTargetPhaseID)
        XCTAssertEqual(
            happy.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.happyProjectID),
            .idle
        )

        let saved = try await makeRR9CaptureModel(scenario: .savedRefresh)
        let savedTarget = PhaseID(rawValue: "rr9-saved-target")
        await saved.model.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID,
            phaseID: savedTarget
        )
        XCTAssertEqual(
            saved.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.savedRefreshProjectID),
            .savedNeedsReload(savedTarget, "Saved target")
        )
        let committed = try await rr9SelectionState(
            store: saved.store,
            projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID
        )
        XCTAssertEqual(committed.commandRequests, 1)
        XCTAssertEqual(committed.selectionAudits, 1)
        await saved.model.reloadAfterActivePhaseSelection(projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID)
        XCTAssertEqual(
            saved.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.savedRefreshProjectID),
            .idle
        )
        XCTAssertEqual(saved.model.currentProject?.activePhaseID, savedTarget)
        let recovered = try await rr9SelectionState(
            store: saved.store,
            projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID
        )
        XCTAssertEqual(recovered, committed)
    }

    @MainActor
    func testRR9MutatingCaptureScenariosStayIsolatedAcrossSameContainerRelaunches() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9Capture-Relaunch-\(UUID().uuidString)", isDirectory: true)
        let roots = directory.appendingPathComponent("RR9ActivePhaseCaptureRoots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))

        let happy = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: .happy,
            rr9ActivePhaseCaptureRootDirectory: roots
        )
        await happy.loadDashboard()
        await happy.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.happyProjectID,
            phaseID: RR9ActivePhaseCaptureFixture.happyTargetPhaseID
        )
        XCTAssertEqual(happy.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.happyTargetPhaseID)

        let empty = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: .emptyPhase,
            rr9ActivePhaseCaptureRootDirectory: roots
        )
        await empty.loadDashboard()
        XCTAssertEqual(empty.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyCurrentPhaseID)
        await empty.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.emptyProjectID,
            phaseID: RR9ActivePhaseCaptureFixture.emptyTargetPhaseID
        )
        XCTAssertEqual(empty.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyTargetPhaseID)

        let noPointer = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: .noActivePointer,
            rr9ActivePhaseCaptureRootDirectory: roots
        )
        await noPointer.loadDashboard()
        let pointerTarget = try XCTUnwrap(noPointer.currentProject?.phases.first?.id)
        await noPointer.setActivePhase(
            projectID: RR9ActivePhaseCaptureFixture.noPointerProjectID,
            phaseID: pointerTarget
        )
        XCTAssertEqual(noPointer.currentProject?.activePhaseID, pointerTarget)

        let crossPhase = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: .crossPhaseDetail,
            rr9ActivePhaseCaptureRootDirectory: roots
        )
        await crossPhase.loadDashboard()
        XCTAssertEqual(crossPhase.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.currentPhaseID)
        XCTAssertEqual(
            crossPhase.dashboard?.board(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?
                .detail(for: RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID)?
                .requires.map(\.id),
            [RR9ActivePhaseCaptureFixture.crossPhaseTargetTicketID]
        )
    }

    @MainActor
    private func makeRR9CaptureModel(
        scenario: RR9ActivePhaseCaptureScenario
    ) async throws -> (model: AppModel, store: DeliveryStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9Capture-\(scenario.rawValue)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false,
            rr9ActivePhaseCaptureScenario: scenario,
            rr9ActivePhaseCaptureRootDirectory: directory.appendingPathComponent("RR9ActivePhaseCaptureRoots")
        )
        await model.loadDashboard()
        return (model, store)
    }

#if DEBUG
    private static func task4ARR9Snapshot(_ store: DeliveryStore) async throws -> [String] {
        try await store.read { connection in
            var rows: [String] = []
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'projects|' || quote(id) || '|' || quote(name) || '|' || quote(first_dashboard_opened) AS value FROM projects ORDER BY id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'project_roots|' || quote(id) || '|' || quote(project_id) || '|' || quote(path) AS value FROM project_roots ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'project_bookmarks|' || quote(project_id) || '|' || quote(path) || '|' || quote(bookmark_data) || '|' || quote(is_stale) AS value FROM project_bookmarks ORDER BY project_id, path"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'phases|' || quote(id) || '|' || quote(project_id) || '|' || quote(name) AS value FROM phases ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'project_active_phases|' || quote(project_id) || '|' || quote(phase_id) AS value FROM project_active_phases ORDER BY project_id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'tickets|' || quote(id) || '|' || quote(project_id) || '|' || quote(phase_id) || '|' || quote(outcome) || '|' || quote(lane) AS value FROM tickets ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'ticket_task_plans|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(revision) || '|' || quote(created_at) || '|' || quote(updated_at) AS value FROM ticket_task_plans ORDER BY project_id, ticket_id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'ticket_tasks|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(id) || '|' || quote(label) || '|' || quote(title) || '|' || quote(sort_order) || '|' || quote(completion) || '|' || quote(lifecycle) || '|' || quote(created_at) || '|' || quote(updated_at) || '|' || quote(completed_at) || '|' || quote(superseded_at) AS value FROM ticket_tasks ORDER BY project_id, ticket_id, id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'phase_dependencies|' || quote(id) || '|' || quote(project_id) || '|' || quote(phase_id) || '|' || quote(depends_on_phase_id) AS value FROM phase_dependencies ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'ticket_dependencies|' || quote(id) || '|' || quote(project_id) || '|' || quote(ticket_id) || '|' || quote(depends_on_ticket_id) AS value FROM ticket_dependencies ORDER BY project_id, id"
            ))
            rows.append(contentsOf: try Self.rr9TextRows(
                connection,
                sql: "SELECT 'audit_events|' || quote(id) || '|' || quote(actor_id) || '|' || quote(thread_id) || '|' || quote(thread_attribution) || '|' || quote(reason) || '|' || quote(created_at) || '|' || quote(project_id) || '|' || quote(entity_type) || '|' || quote(entity_id) AS value FROM audit_events ORDER BY id"
            ))
            return rows
        }
    }
#endif

    private static func task4ARR9NormalAcceptanceState(
        _ store: DeliveryStore
    ) async throws -> Task4ARR9NormalAcceptanceState {
        try await store.read { connection in
            Task4ARR9NormalAcceptanceState(
                acceptedTicketIDs: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT id AS value FROM tickets WHERE lane = 'accepted' ORDER BY project_id, id"
                ),
                planRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT project_id || '|' || ticket_id || '|' || revision AS value FROM ticket_task_plans ORDER BY project_id, ticket_id"
                ),
                taskRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT project_id || '|' || ticket_id || '|' || id AS value FROM ticket_tasks ORDER BY project_id, ticket_id, id"
                ),
                seedAuditRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') AS value FROM audit_events WHERE id = 'rr9-capture-seed-audit' ORDER BY id"
                )
            )
        }
    }

    private static func prepareTask4AOwnerTicket(
        store: DeliveryStore,
        lane: TicketLane,
        plan: Task4AOwnerPlanState
    ) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Prepare owner acceptance matrix") { connection in
            try connection.execute(
                "UPDATE tickets SET lane = ? WHERE project_id = 'rr9-owner-project' AND id = 'ROAD-1'",
                bindings: [.text(lane.rawValue)]
            )
            guard plan != .none else { return }
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: .init(rawValue: "rr9-owner-project"),
                ticketID: .init(rawValue: "ROAD-1"),
                expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "owner-task"), label: "Owner", title: "Complete owner task", sortOrder: 0)],
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
            if plan == .completed {
                _ = try TicketTaskPlanningPolicy.completeTask(
                    projectID: .init(rawValue: "rr9-owner-project"),
                    ticketID: .init(rawValue: "ROAD-1"),
                    taskID: .init(rawValue: "owner-task"),
                    expectedRevision: 1,
                    connection: connection
                )
            }
        }
    }

    private static func task4AOwnerTransitionState(_ store: DeliveryStore) async throws -> Task4AOwnerTransitionState {
        try await store.read { connection in
            Task4AOwnerTransitionState(
                lane: try connection.scalarText("SELECT lane FROM tickets WHERE project_id = 'rr9-owner-project' AND id = 'ROAD-1'"),
                planRevision: try connection.scalarInt("SELECT revision FROM ticket_task_plans WHERE project_id = 'rr9-owner-project' AND ticket_id = 'ROAD-1'"),
                pendingTaskCount: try connection.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE project_id = 'rr9-owner-project' AND ticket_id = 'ROAD-1' AND completion = 'pending'") ?? -1,
                completedTaskCount: try connection.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE project_id = 'rr9-owner-project' AND ticket_id = 'ROAD-1' AND completion = 'completed'") ?? -1,
                auditCount: try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                requestCount: try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
                actorID: try connection.scalarText("SELECT actor_id FROM audit_events WHERE entity_type = 'ticket' AND entity_id = 'ROAD-1' ORDER BY rowid DESC LIMIT 1")
            )
        }
    }

    @MainActor
    private func makeRR9OwnerFixture(
        hasBookmark: Bool = true,
        blockAuthorization: Bool = false,
        hasActivePointer: Bool = true
    ) async throws -> RR9OwnerFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RR9Owner-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let bookmarks = RR9RouteBookmarkStore(blocksAccess: blockAuthorization)
        let bookmark = try bookmarks.makeBookmark(for: projectRoot)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed RR-R9 owner fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('rr9-owner-project', 'RR-R9 Owner')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('rr9-owner-root', 'rr9-owner-project', ?)", bindings: [.text(projectRoot.path)])
            if hasBookmark {
                try connection.execute(
                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('rr9-owner-project', ?, ?, 0)",
                    bindings: [.text(projectRoot.path), .blob(bookmark)]
                )
            }
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'rr9-owner-project', 'Current')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-roadmap', 'rr9-owner-project', 'Roadmap')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-empty', 'rr9-owner-project', 'Empty')")
            if hasActivePointer {
                try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('rr9-owner-project', 'phase-current')")
            }
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-1', 'rr9-owner-project', 'phase-current', 'Current work remains coherent.', 'in_progress')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROAD-1', 'rr9-owner-project', 'phase-roadmap', 'Roadmap backlog one.', 'backlog')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROAD-2', 'rr9-owner-project', 'phase-roadmap', 'Roadmap backlog two.', 'backlog')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROAD-X', 'rr9-owner-project', 'phase-roadmap', 'Roadmap blocker.', 'blocked')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('road-dependency', 'rr9-owner-project', 'ROAD-X', 'ROAD-1')")
        }
        let projectID = ProjectID(rawValue: "rr9-owner-project")
        return RR9OwnerFixture(
            databaseURL: directory.appendingPathComponent("store.sqlite"),
            projectRoot: projectRoot,
            projectID: projectID,
            currentPhaseID: .init(rawValue: "phase-current"),
            roadmapPhaseID: .init(rawValue: "phase-roadmap"),
            emptyPhaseID: .init(rawValue: "phase-empty"),
            store: store,
            bookmarks: bookmarks,
            onboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
        )
    }

    @MainActor
    private func rr9SelectionState(
        store: DeliveryStore,
        projectID: ProjectID
    ) async throws -> RR9SelectionState {
        try await store.read { connection in
            RR9SelectionState(
                activePhaseID: try connection.scalarText(
                    "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
                    bindings: [.text(projectID.rawValue)]
                ),
                commandRequests: try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
                selectionAudits: try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Owner selected active phase %'"
                ) ?? -1,
                actorID: try connection.scalarText(
                    "SELECT actor_id FROM audit_events WHERE reason LIKE 'Owner selected active phase %' ORDER BY rowid DESC LIMIT 1"
                )
            )
        }
    }

    private static func rr9ReadOnlyReloadStoreSnapshot(
        _ store: DeliveryStore
    ) async throws -> RR9ReadOnlyReloadStoreSnapshot {
        try await store.read { connection in
            RR9ReadOnlyReloadStoreSnapshot(
                bookmarkRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT project_id || '|' || path || '|' || hex(bookmark_data) || '|' || is_stale AS value FROM project_bookmarks ORDER BY project_id, path"
                ),
                auditRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') || '|' || created_at AS value FROM audit_events ORDER BY id"
                ),
                requestRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT request_id || '|' || hex(request_body) || '|' || hex(result_data) || '|' || created_at AS value FROM agent_command_requests ORDER BY request_id"
                ),
                activeRows: try Self.rr9TextRows(
                    connection,
                    sql: "SELECT project_id || '|' || phase_id AS value FROM project_active_phases ORDER BY project_id"
                )
            )
        }
    }

    private static func rr9TextRows(
        _ connection: SQLiteConnection,
        sql: String
    ) throws -> [String] {
        var values: [String] = []
        var offset: Int64 = 0
        while let row = try connection.row(
            "\(sql) LIMIT 1 OFFSET ?",
            bindings: [.integer(offset)]
        ) {
            guard case let .text(value)? = row["value"] else {
                throw RouteProjectionError.missingSnapshotText
            }
            values.append(value)
            offset += 1
        }
        return values
    }

}

private struct Task4ARR9NormalAcceptanceState: Equatable {
    let acceptedTicketIDs: [String]
    let planRows: [String]
    let taskRows: [String]
    let seedAuditRows: [String]
}

private struct RR9OwnerFixture {
    let databaseURL: URL
    let projectRoot: URL
    let projectID: ProjectID
    let currentPhaseID: PhaseID
    let roadmapPhaseID: PhaseID
    let emptyPhaseID: PhaseID
    let store: DeliveryStore
    let bookmarks: RR9RouteBookmarkStore
    let onboarding: FolderProjectOnboarding
}

private enum Task4AOwnerPlanState: Equatable, Sendable {
    case none
    case pending
    case completed
}

private struct Task4AOwnerTransitionState: Equatable {
    let lane: String?
    let planRevision: Int64?
    let pendingTaskCount: Int64
    let completedTaskCount: Int64
    let auditCount: Int64
    let requestCount: Int64
    let actorID: String?
}

private struct RR9SelectionState: Equatable {
    let activePhaseID: String?
    let commandRequests: Int64
    let selectionAudits: Int64
    let actorID: String?
}

private struct RR9ReadOnlyReloadStoreSnapshot: Equatable {
    let bookmarkRows: [String]
    let auditRows: [String]
    let requestRows: [String]
    let activeRows: [String]
}

private final class RR9RequestIDCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var generated = 0

    var count: Int { lock.withLock { generated } }

    func next() -> UUID {
        lock.withLock { generated += 1 }
        return UUID()
    }
}

private final class RR9DashboardLoadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var loads = 0

    var count: Int { lock.withLock { loads } }

    func record() {
        lock.withLock { loads += 1 }
    }
}

private final class RR9RouteBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let gate: RR9RouteAccessGate?
    private let lock = NSLock()
    private var failureMode = RR9BookmarkFailureMode.none

    init(blocksAccess: Bool) {
        gate = blocksAccess ? RR9RouteAccessGate() : nil
    }

    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.resolvingSymlinksInPath().path.utf8)
    }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        let url = URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self))
        return try lock.withLock {
            switch failureMode {
            case .none, .accessDenied:
                return ResolvedProjectBookmark(url: url, isStale: false)
            case .stale:
                return ResolvedProjectBookmark(url: url, isStale: true)
            case .resolutionFailure:
                throw ProjectBookmarkError.bookmarkResolutionFailed
            case let .mismatchedRoot(root):
                return ResolvedProjectBookmark(url: root, isStale: false)
            }
        }
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        let resolved = try resolve(bookmark)
        if lock.withLock({ failureMode == .accessDenied }) {
            throw ProjectBookmarkError.securityScopeAccessDenied
        }
        if let gate { await gate.enterAndWait() }
        return try await body(resolved)
    }

    func setFailureMode(_ mode: RR9BookmarkFailureMode) {
        lock.withLock { failureMode = mode }
    }

    func waitUntilAccessEntered() async {
        await gate?.waitUntilEntered()
    }

    func armAccessGate() async {
        await gate?.arm()
    }

    func releaseAccess() async {
        await gate?.release()
    }
}

private enum RR9BookmarkFailureMode: Equatable, CustomStringConvertible {
    case none
    case stale
    case resolutionFailure
    case accessDenied
    case mismatchedRoot(URL)

    var description: String {
        switch self {
        case .none: "none"
        case .stale: "stale"
        case .resolutionFailure: "resolution failure"
        case .accessDenied: "access denied"
        case .mismatchedRoot: "mismatched root"
        }
    }
}

private actor RR9RouteAccessGate {
    private var armed = false
    private var entered = false
    private var released = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func enterAndWait() async {
        guard armed else { return }
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        guard !released else { return }
        await withCheckedContinuation { releaseContinuations.append($0) }
    }

    func arm() {
        armed = true
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

private enum RR9StaleCompletion: CaseIterable {
    case success
    case failure
}

private actor RR9InterleavingDashboardLoader {
    private let staleCompletion: RR9StaleCompletion
    private var callCount = 0
    private var initialProjection: DashboardProjection?
    private var olderEntered = false
    private var olderReleased = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    init(staleCompletion: RR9StaleCompletion) {
        self.staleCompletion = staleCompletion
    }

    func load(from store: DeliveryStore) async throws -> DashboardProjection {
        callCount += 1
        if callCount == 1 {
            let projection = try await DashboardProjection.load(from: store)
            initialProjection = projection
            return projection
        }
        if callCount == 2 {
            olderEntered = true
            enteredContinuations.forEach { $0.resume() }
            enteredContinuations.removeAll()
            if !olderReleased {
                await withCheckedContinuation { releaseContinuations.append($0) }
            }
            if staleCompletion == .failure { throw RouteProjectionError.forcedRefreshFailure }
            return initialProjection ?? DashboardProjection(projects: [], boards: [:])
        }
        return try await DashboardProjection.load(from: store)
    }

    func waitUntilOlderReloadEntered() async {
        guard !olderEntered else { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func releaseOlderReload() {
        olderReleased = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

private actor RR9SupersededLoadDashboardLoader {
    private var callCount = 0
    private var olderEntered = false
    private var olderReleased = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func load(from store: DeliveryStore) async throws -> DashboardProjection {
        callCount += 1
        let projection = try await DashboardProjection.load(from: store)
        guard callCount == 2 else { return projection }
        olderEntered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        if !olderReleased {
            await withCheckedContinuation { releaseContinuations.append($0) }
        }
        return projection
    }

    func waitUntilOlderLoadEntered() async {
        guard !olderEntered else { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func releaseOlderLoad() {
        olderReleased = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

private actor RR9TargetMismatchDashboardLoader {
    private let failCommittedReload: Bool
    private var callCount = 0
    private var initialProjection: DashboardProjection?

    init(failCommittedReload: Bool) {
        self.failCommittedReload = failCommittedReload
    }

    func load(from store: DeliveryStore) async throws -> DashboardProjection {
        callCount += 1
        if callCount == 1 {
            let projection = try await DashboardProjection.load(from: store)
            initialProjection = projection
            return projection
        }
        if callCount == 2, failCommittedReload {
            throw RouteProjectionError.forcedRefreshFailure
        }
        return initialProjection ?? DashboardProjection(projects: [], boards: [:])
    }
}

private actor RR9SequencedReviewInboxLoader {
    private let failingCalls: Set<Int>
    private var callCount = 0

    init(failingCalls: Set<Int>) {
        self.failingCalls = failingCalls
    }

    func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ReviewInboxProjection {
        callCount += 1
        guard !failingCalls.contains(callCount) else {
            throw RouteProjectionError.forcedRefreshFailure
        }
        return try await ReviewInboxProjection.load(from: store, projectID: projectID)
    }
}

private actor LaunchOrderRecorder {
    enum Event: Equatable { case codexObservation, dashboard, pluginStatus }
    private var events: [Event] = []

    func record(_ event: Event) { events.append(event) }
    func snapshot() -> [Event] { events }
}

private struct LaunchOrderCodexObserver: CodexObserver {
    let recorder: LaunchOrderRecorder

    init(events: LaunchOrderRecorder) {
        recorder = events
    }

    func snapshot() async throws -> CodexSnapshot {
        await recorder.record(.codexObservation)
        return .unavailable(reason: "No live attachment")
    }

    func events() -> AsyncThrowingStream<CodexRuntimeEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private actor LaunchOrderLifecycleManager: CodexPluginLifecycleManaging {
    let events: LaunchOrderRecorder

    init(events: LaunchOrderRecorder) {
        self.events = events
    }

    func status() async -> CodexPluginHelperReply {
        await events.record(.pluginStatus)
        return .init(
            wireVersion: 1,
            observedState: .clean(version: "0.1.0", digest: "current"),
            error: nil
        )
    }

    func install() async -> CodexPluginHelperReply { await status() }
    func remove() async -> CodexPluginHelperReply { await status() }
    func reinstall() async -> CodexPluginHelperReply { await status() }
}

private actor AppLifecycleManager: CodexPluginLifecycleManaging {
    enum Operation: Equatable { case status, install, remove, reinstall }
    private var replies: [CodexPluginHelperReply]
    private var calls: [Operation] = []

    init(replies: [CodexPluginHelperReply]) {
        self.replies = replies
    }

    func status() async -> CodexPluginHelperReply { next(.status) }
    func install() async -> CodexPluginHelperReply { next(.install) }
    func remove() async -> CodexPluginHelperReply { next(.remove) }
    func reinstall() async -> CodexPluginHelperReply { next(.reinstall) }
    func operations() -> [Operation] { calls }

    private func next(_ operation: Operation) -> CodexPluginHelperReply {
        calls.append(operation)
        return replies.isEmpty
            ? .init(wireVersion: 1, observedState: nil, error: .malformedResult)
            : replies.removeFirst()
    }
}

private final class RouteBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0

    var accessStarts: Int { lock.withLock { starts } }
    var accessStops: Int { lock.withLock { stops } }

    func makeBookmark(for url: URL) throws -> Data {
        Data(url.standardizedFileURL.resolvingSymlinksInPath().path.utf8)
    }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        let resolved = try resolve(bookmark)
        lock.withLock { starts += 1 }
        defer { lock.withLock { stops += 1 } }
        return try await body(resolved)
    }
}

private actor RouteReviewInboxLoader {
    private let failAfterSuccessfulLoads: Int
    private var successfulLoads = 0

    init(failAfterSuccessfulLoads: Int) {
        self.failAfterSuccessfulLoads = failAfterSuccessfulLoads
    }

    func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ReviewInboxProjection {
        guard successfulLoads < failAfterSuccessfulLoads else { throw RouteProjectionError.forcedRefreshFailure }
        successfulLoads += 1
        return try await ReviewInboxProjection.load(from: store, projectID: projectID)
    }
}

private actor RouteDashboardLoader {
    private let failingCalls: Set<Int>
    private var callCount = 0

    init(failingCalls: Set<Int>) {
        self.failingCalls = failingCalls
    }

    func load(from store: DeliveryStore) async throws -> DashboardProjection {
        callCount += 1
        guard !failingCalls.contains(callCount) else { throw RouteProjectionError.forcedRefreshFailure }
        return try await DashboardProjection.load(from: store)
    }
}

private enum RouteProjectionError: Error {
    case forcedRefreshFailure
    case missingSnapshotText
}

private actor RouteCountingTransport: PushoverTransport {
    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        .init(requestID: "unused")
    }
}
