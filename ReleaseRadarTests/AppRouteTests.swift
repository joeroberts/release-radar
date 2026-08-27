import AppKit
import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class AppRouteTests: XCTestCase {
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
        let expectedPrompt = "Define the current Release Radar tracking state for this project. Through Release Radar's existing typed inbound bridge, create or update the active phase and the work currently in scope. Record truthful ticket outcomes, lanes, dependencies, blockers, evidence, and Codex links only when known. Do not create or edit repository dashboard files, do not infer canonical state from arbitrary Markdown, and send uncertain items to Needs Review instead of guessing."
        let pasteboard = NSPasteboard(name: .init("release-radar-tests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        addTeardownBlock { pasteboard.clearContents() }

        let result = CodexPromptHandoff.copy { prompt in
            pasteboard.clearContents()
            return pasteboard.setString(prompt, forType: .string)
        }

        let copied = try XCTUnwrap(pasteboard.string(forType: .string))
        XCTAssertEqual(Data(copied.utf8), Data(expectedPrompt.utf8))
        XCTAssertEqual(Data(copied.utf8), Data(CodexPromptHandoff.prompt.utf8))
        XCTAssertEqual(result, .copied)
        XCTAssertEqual(result.announcement, "Codex prompt copied")
        XCTAssertEqual(result.accessibilityAnnouncement, "Codex prompt copied")
        XCTAssertEqual(CodexPromptHandoff.copyButtonAccessibilityLabel, "Copy Codex prompt")
        XCTAssertEqual(CodexPromptHandoff.copyButtonAccessibilityIdentifier, "onboarding-copy-codex-prompt")
        XCTAssertTrue(CodexPromptHandoff.clipboardDisclosure.localizedCaseInsensitiveContains("only the prompt"))
        XCTAssertTrue(CodexPromptHandoff.clipboardDisclosure.localizedCaseInsensitiveContains("until replaced"))
        XCTAssertFalse(copied.contains("/tmp/Delivery Workspace"))
    }

    @MainActor
    func testCodexPromptCopyFailureReplacesPriorSuccessWithoutReportingCopied() {
        let firstResult = CodexPromptHandoff.copy { _ in true }
        let secondResult = CodexPromptHandoff.copy { _ in false }

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
}

private actor RouteCountingTransport: PushoverTransport {
    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        .init(requestID: "unused")
    }
}
