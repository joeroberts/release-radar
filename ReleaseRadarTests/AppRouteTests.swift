import AppKit
import ApplicationServices
import RekonDesignSystem
import SwiftUI
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

private enum SyntheticBackupScopeError: Error {
    case expected
}

final class AppRouteTests: XCTestCase {
    @MainActor
    func testAddProjectWindowUsesRekonChrome() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AddProjectChrome-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: databaseURL) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: databaseURL),
            externalServicesSuppressed: true
        )
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        for (width, height, captureName) in [
            (760.0, 560.0, "add-project-rds-default-window"),
            (680.0, 500.0, "add-project-rds-minimum-window"),
        ] {
            let hosting = NSHostingView(rootView: AddProjectWindowView(model: model))
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            let window = NSWindow(
                contentRect: hosting.frame,
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            defer { window.close() }

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .milliseconds(150))
            hosting.layoutSubtreeIfNeeded()

            XCTAssertTrue(window.titlebarAppearsTransparent)
            XCTAssertEqual(window.titleVisibility, .hidden)
            try fullWindowCapture(window, name: captureName)
        }
    }

    @MainActor
    func testAddProjectLaterWorkflowWindowsUseRekonStyles() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AddProjectLaterWindows-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: databaseURL) }
        let store = DeliveryStore(databaseURL: databaseURL)
        let folder = URL(fileURLWithPath: "/tmp/Release Radar Visual Fixture", isDirectory: true)
        let project = ProjectRecord(id: ProjectID(rawValue: "visual-fixture-project"), name: "Visual Fixture")
        let preview = OnboardingPreview(
            selectedFolder: folder,
            gitRoot: folder,
            includedTaskDescriptors: [],
            rejectedTaskDescriptors: [],
            authorizedWorktreeURLs: [],
            worktreesRequiringAuthorization: [],
            savedProjectName: "Visual Fixture"
        )
        let fixtures: [(String, OnboardingView)] = [
            ("initialize", OnboardingView(
                store: store,
                onOpenExisting: { _ in },
                initialWorkflow: .initialize,
                onFinished: { _ in }
            )),
            ("initialize-confirmation", OnboardingView(
                store: store,
                onOpenExisting: { _ in },
                initialPreview: preview,
                onFinished: { _ in }
            )),
            ("attach-confirmation", OnboardingView(
                store: store,
                onOpenExisting: { _ in },
                initialWorkflow: .attach,
                initialAttachableProjects: [project],
                initialSelectedAttachableProjectID: project.id,
                initialAttachmentFolder: folder,
                onFinished: { _ in }
            )),
            ("attach-empty", OnboardingView(
                store: store,
                onOpenExisting: { _ in },
                initialWorkflow: .attach,
                onFinished: { _ in }
            )),
        ]
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }

        for (width, height, sizeName) in [(760.0, 560.0, "default"), (680.0, 500.0, "minimum")] {
            for (fixtureName, fixture) in fixtures {
                let hosting = NSHostingView(rootView: fixture.rekonWindowChrome())
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let window = NSWindow(
                    contentRect: hosting.frame,
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.isReleasedWhenClosed = false
                window.contentView = hosting
                defer { window.close() }

                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                try await Task.sleep(for: .milliseconds(100))
                hosting.layoutSubtreeIfNeeded()

                XCTAssertTrue(window.titlebarAppearsTransparent)
                XCTAssertEqual(window.titleVisibility, .hidden)
                try fullWindowCapture(window, name: "add-project-\(fixtureName)-\(sizeName)-window")
            }
        }
    }

    @MainActor
    func testNativeNavigationHistoryControlsExposeBoundariesAndPerformBackForward() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NativeHistory-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: databaseURL) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: databaseURL),
            externalServicesSuppressed: true
        )
        await model.navigate(to: .settings)
        let hosting = NSHostingView(rootView: NavigationHistoryControls(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 180, height: 60)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.isReleasedWhenClosed = false
        window.title = "Phase 4 Navigation History — isolated native acceptance"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(100))
        hosting.layoutSubtreeIfNeeded()

        XCTAssertTrue(window.isVisible)
        try taskCapture(hosting, name: "phase4-navigation-history-controls")
        let externalCheckMarker = URL(
            fileURLWithPath: "/tmp/release-radar-phase4-external-history-check",
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: externalCheckMarker.path) {
            try? FileManager.default.removeItem(at: externalCheckMarker)
            print("PHASE4 HISTORY READY: activate Back")
            for _ in 0..<300 where model.selection != .projects {
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertEqual(model.selection, .projects)
            print("PHASE4 HISTORY BACK COMPLETE: activate Forward")
            for _ in 0..<300 where model.selection != .settings {
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertEqual(model.selection, .settings)
        } else {
            await model.goBack()
            XCTAssertEqual(model.selection, .projects)
            XCTAssertFalse(model.canNavigateBack)
            XCTAssertTrue(model.canNavigateForward)
            await model.goForward()
            XCTAssertEqual(model.selection, .settings)
        }
    }

    @MainActor
    func testBackupDestinationPanelSelectsOneExistingFolderAndGeneratesItsPackageInside() throws {
        let panel = ApplicationRecoveryFilePanels.makeBackupDestinationPanel()

        XCTAssertFalse(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canCreateDirectories)
        XCTAssertFalse(panel.resolvesAliases)

        let folder = URL(fileURLWithPath: "/Users/Shared/Synthetic Backup Destination", isDirectory: true)
        let identifier = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let package = ApplicationRecoveryFilePanels.backupPackageURL(
            in: folder,
            identifier: identifier
        )
        XCTAssertEqual(package.deletingLastPathComponent(), folder)
        XCTAssertEqual(package.pathExtension, "release-radar-backup")
        XCTAssertEqual(
            package.lastPathComponent,
            "Release Radar Backup 11111111-2222-3333-4444-555555555555.release-radar-backup"
        )
    }

    @MainActor
    func testBackupSecurityScopeIsBalancedForSuccessAndFailure() async throws {
        let folder = URL(fileURLWithPath: "/Users/Shared/Synthetic Backup Destination", isDirectory: true)
        var starts = 0
        var stops = 0
        let value = try await ApplicationRecoverySecurityScope.withAccess(
            to: folder,
            start: { _ in starts += 1; return true },
            stop: { _ in stops += 1 }
        ) {
            "complete"
        }
        XCTAssertEqual(value, "complete")
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 1)

        do {
            _ = try await ApplicationRecoverySecurityScope.withAccess(
                to: folder,
                start: { _ in starts += 1; return true },
                stop: { _ in stops += 1 }
            ) {
                throw SyntheticBackupScopeError.expected
            } as String
            XCTFail("The synthetic failure must propagate")
        } catch SyntheticBackupScopeError.expected {}
        XCTAssertEqual(starts, 2)
        XCTAssertEqual(stops, 2)
    }

    @MainActor
    func testSignedNativeBackupPickerWritesValidatedPackageInSelectedExternalFolder() async throws {
        guard let expectedFolderPath = ProcessInfo.processInfo.environment["C7_SIGNED_PICKER_FOLDER"] else {
            throw XCTSkip("Run only for the signed native picker verification.")
        }
        let expectedFolder = URL(fileURLWithPath: expectedFolderPath, isDirectory: true).standardizedFileURL
        let packageURL = try XCTUnwrap(ApplicationRecoveryFilePanels.chooseBackupDestination())
        XCTAssertEqual(packageURL.deletingLastPathComponent().standardizedFileURL, expectedFolder)

        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-C7-SignedPicker-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: databaseURL) }
        let store = DeliveryStore(databaseURL: databaseURL)
        let model = AppModel(
            store: store,
            databaseURL: databaseURL,
            externalServicesSuppressed: true
        )
        let preview = try await model.previewApplicationBackup(destinationURL: packageURL)
        await model.createApplicationBackup(preview)

        XCTAssertNil(model.applicationRecoveryFailure)
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.path))
        let manifest = try ApplicationBackupManifest.load(from: packageURL)
        XCTAssertEqual(manifest.databaseSHA256.count, 64)
    }

    func testMainWindowConsumesSharedRDSChromeWithoutALocalAppKitBridge() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("ReleaseRadar/App/ReleaseRadarApp.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".rekonWindowChrome()"))
        XCTAssertFalse(source.contains("ReleaseRadarWindowChrome"))
        XCTAssertFalse(source.contains(".windowStyle(.hiddenTitleBar)"))
    }

    func testResponsiveSettingsContentUsesTheAvailableWidth() {
        XCTAssertEqual(SettingsLayout.contentWidth(for: 1_400), 1_344)
        XCTAssertEqual(SettingsLayout.contentWidth(for: 620), 564)
        XCTAssertEqual(SettingsLayout.contentWidth(for: 40), 0)
    }

    func testWorkspaceShellLayoutForcesCompactAtTheApprovedMinimumWidth() {
        XCTAssertFalse(WorkspaceShellLayout.isForcedCompact(width: 1_280))
        XCTAssertFalse(WorkspaceShellLayout.isCompact(width: 1_280, userCollapsed: false))
        XCTAssertTrue(WorkspaceShellLayout.isCompact(width: 1_280, userCollapsed: true))
        XCTAssertTrue(WorkspaceShellLayout.isForcedCompact(width: 760))
        XCTAssertTrue(WorkspaceShellLayout.isCompact(width: 760, userCollapsed: false))
    }

    func testEmptyReviewLayoutSuppressesTheListAndZeroBadge() {
        XCTAssertFalse(NeedsReviewLayout.showsInboxList(openItems: 0, deliveryGoals: 0, completedItems: 0))
        XCTAssertTrue(NeedsReviewLayout.showsInboxList(openItems: 0, deliveryGoals: 0, completedItems: 1))
        XCTAssertFalse(NeedsReviewLayout.showsCountBadge(openCount: 0))
        XCTAssertTrue(NeedsReviewLayout.showsCountBadge(openCount: 1))
        XCTAssertTrue(NeedsReviewLayout.usesCompactLayout(availableWidth: 539))
        XCTAssertFalse(NeedsReviewLayout.usesCompactLayout(availableWidth: 1_380))
    }

    func testApplicationHealthActionsLeadToTheRelevantRecoverySurface() {
        let attention: ProjectHealthSnapshot.Check.State = .attention
        XCTAssertEqual(
            ApplicationHealthAction.recommended(forCheckID: "folder", state: attention, hasProjectTarget: true),
            .openProject
        )
        XCTAssertEqual(
            ApplicationHealthAction.recommended(forCheckID: "documentation", state: attention, hasProjectTarget: true),
            .openProject
        )
        XCTAssertEqual(
            ApplicationHealthAction.recommended(forCheckID: "plugin", state: attention, hasProjectTarget: true),
            .reviewConnections
        )
        XCTAssertEqual(
            ApplicationHealthAction.recommended(forCheckID: "observer", state: attention, hasProjectTarget: true),
            .reviewConnections
        )
        XCTAssertEqual(
            ApplicationHealthAction.recommended(forCheckID: "storage", state: .unavailable, hasProjectTarget: false),
            .checkAgain
        )
        XCTAssertEqual(ApplicationHealthAction.recommended(forCheckID: "root:worktree", state: attention, hasProjectTarget: true), .openProject)
        XCTAssertEqual(ApplicationHealthAction.recommended(forCheckID: "roots", state: .unavailable, hasProjectTarget: false), .checkAgain)
        XCTAssertNil(ApplicationHealthAction.recommended(forCheckID: "plugin", state: .ready, hasProjectTarget: true))
        XCTAssertNil(ApplicationHealthAction.recommended(forCheckID: "folder", state: attention, hasProjectTarget: false))
    }

    @MainActor
    func testSettingsEntryPointsUseTheInShellSettingsRoute() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SettingsCommand-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            externalServicesSuppressed: true
        )

        await ReleaseRadarSettingsCommands.navigateToSettings(model: model)

        XCTAssertEqual(model.selection, .settings)
    }

    @MainActor
    func testApplicationHealthRemainsReachableWhenStoreIsUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-Health-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        try Data("not-a-sqlite-database".utf8).write(to: databaseURL)
        let model = AppModel(store: DeliveryStore(databaseURL: databaseURL))

        let health = await model.applicationHealth()

        XCTAssertNil(health.projectTarget)
        XCTAssertEqual(health.checks.map(\.id), ["storage", "recovery", "folder", "documentation", "plugin", "observer"])
        XCTAssertEqual(health.checks.first?.state, .unavailable)
        let recovery = try XCTUnwrap(health.checks.first { $0.id == "recovery" })
        XCTAssertTrue(recovery.detail.contains(databaseURL.path))
        XCTAssertEqual(
            ApplicationHealthAction.recommended(
                forCheckID: recovery.id,
                state: recovery.state,
                hasProjectTarget: false
            ),
            .restoreBackup
        )
        XCTAssertTrue(health.checks.dropFirst().contains { $0.state != .ready })
    }

    @MainActor
    func testProjectHealthKeepsManagedFailureAndCachedObservationTimesTruthful() async throws {
        let fixture = try await makeRR9OwnerFixture(hasActivePointer: false)
        let documents = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid/docs", isDirectory: true)
        try FileManager.default.copyItem(at: documents, to: fixture.projectRoot.appendingPathComponent("docs"))
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: fixture.projectRoot.appendingPathComponent("AGENTS.md"))
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed health registration") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'health-registration', 2, 'complete')",
                bindings: [.text(fixture.projectID.rawValue)]
            )
        }
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Unavailable worktree fixture") { connection in
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('missing-worktree', ?, ?)", bindings: [.text(fixture.projectID.rawValue), .text(fixture.projectRoot.appendingPathComponent("missing-worktree").path)])
        }
        let lastObservedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        model.codexPluginState = .installed(version: "0.1.7")
        model.codexSnapshot = .init(
            capturedAt: lastObservedAt,
            freshness: .init(state: .stale, lastObservedAt: lastObservedAt, reason: "Cached fixture"),
            threads: []
        )

        let health = await model.projectHealth(for: fixture.projectID)
        let documentation = try XCTUnwrap(health.checks.first { $0.id == "documentation" })
        let plugin = try XCTUnwrap(health.checks.first { $0.id == "plugin" })
        let observer = try XCTUnwrap(health.checks.first { $0.id == "observer" })

        XCTAssertEqual(documentation.state, .attention)
        XCTAssertTrue(documentation.title.contains("unavailable"))
        XCTAssertEqual(plugin.state, .attention)
        XCTAssertTrue(plugin.detail.contains("time unavailable"))
        XCTAssertEqual(observer.state, .attention)
        XCTAssertTrue(observer.detail.contains("Last seen"))
        XCTAssertGreaterThan(health.checkedAt, lastObservedAt)
        let worktree = try XCTUnwrap(health.checks.first { $0.id == "root:missing-worktree" })
        XCTAssertEqual(worktree.state, .attention)
        XCTAssertTrue(worktree.detail.contains("missing-worktree"))
    }

    @MainActor
    func testProjectHealthReauthorizesOnlyTheExactSavedFolderAndRetainsCatalogFailure() async throws {
        let fixture = try await makeRR9OwnerFixture(hasActivePointer: false)
        try FileManager.default.createDirectory(
            at: fixture.projectRoot.appendingPathComponent("docs"),
            withIntermediateDirectories: true
        )
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: fixture.projectRoot.appendingPathComponent("AGENTS.md"))
        try Data("{ invalid catalog".utf8)
            .write(to: fixture.projectRoot.appendingPathComponent("docs/catalog.json"))
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed stale phase-less health fixture") { connection in
            try connection.execute("DELETE FROM ticket_dependencies WHERE project_id = ?", bindings: [.text(fixture.projectID.rawValue)])
            try connection.execute("DELETE FROM tickets WHERE project_id = ?", bindings: [.text(fixture.projectID.rawValue)])
            try connection.execute("DELETE FROM phases WHERE project_id = ?", bindings: [.text(fixture.projectID.rawValue)])
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'health-recovery-registration', 1, 'complete')",
                bindings: [.text(fixture.projectID.rawValue)]
            )
            try connection.execute(
                "UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = ?",
                bindings: [.text(fixture.projectID.rawValue)]
            )
        }
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding, externalServicesSuppressed: true)
        await model.loadDashboard()

        do {
            _ = try await model.reauthorizeProjectHealthRoot(at: fixture.projectRoot.deletingLastPathComponent(), projectID: fixture.projectID)
            XCTFail("A different folder must be rejected")
        } catch {
            XCTAssertEqual(error as? ProjectAuthorizationError, .projectRootMismatch)
        }
        for (mode, expected) in [
            (RR9BookmarkFailureMode.accessDenied, ProjectAuthorizationError.securityScopeAccessDenied),
            (.stale, .bookmarkStale),
        ] {
            fixture.bookmarks.setFailureMode(mode)
            do {
                _ = try await model.reauthorizeProjectHealthRoot(at: fixture.projectRoot, projectID: fixture.projectID)
                XCTFail("Expected \(mode) to be rejected")
            } catch {
                XCTAssertEqual(error as? ProjectAuthorizationError, expected)
            }
        }
        fixture.bookmarks.setFailureMode(.none)

        let recovered = try await model.reauthorizeProjectHealthRoot(at: fixture.projectRoot, projectID: fixture.projectID)

        XCTAssertTrue(model.dashboard?.projects.first(where: { $0.id == fixture.projectID })?.phases.isEmpty == true)
        XCTAssertEqual(recovered.checks.first(where: { $0.id == "folder" })?.state, .ready)
        XCTAssertEqual(recovered.checks.first(where: { $0.id == "documentation" })?.state, .attention)
        XCTAssertTrue(recovered.checks.first(where: { $0.id == "documentation" })?.title.contains("unavailable") == true)
    }

    @MainActor
    func testTask10ViewedPhaseDoesNotChangeActivePhaseOrAuditAndSurvivesReload() async throws {
        let fixture = try await makeRR9OwnerFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Independent project browsing fixture") { c in
            try c.execute("INSERT INTO projects (id,name) VALUES ('other-project','Other')")
            try c.execute("INSERT INTO phases (id,project_id,name) VALUES ('other-current','other-project','Current'),('other-next','other-project','Next')")
        }
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding,
                             externalServicesSuppressed: true)
        await model.loadDashboard()
        let before = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(model.dashboard?.board(for: fixture.projectID)?.phaseID, fixture.currentPhaseID)
        XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
        let otherProject = ProjectID(rawValue: "other-project")
        model.viewPhase(projectID: otherProject, phaseID: .init(rawValue: "other-next"))
        XCTAssertEqual(model.viewedBoard(for: otherProject)?.phaseID.rawValue, "other-next")
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.viewPhase(projectID: fixture.projectID, phaseID: .init(rawValue: "unknown"))
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
        XCTAssertEqual(model.viewedBoard(for: otherProject)?.phaseID.rawValue, "other-next")
        let after = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
        XCTAssertEqual(after, before)

        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        let committed = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
        XCTAssertEqual(committed.activePhaseID, "phase-roadmap")
        XCTAssertEqual(committed.selectionAudits, 1)
        XCTAssertEqual(committed.actorID, "release-radar-owner")
    }

    @MainActor
    func testTask10BrowsingWithoutActivePointerDoesNotEstablishOne() async throws {
        let fixture = try await makeRR9OwnerFixture(hasActivePointer: false)
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()
        let before = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        XCTAssertNil(model.dashboard?.board(for: fixture.projectID))
        let after = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
        XCTAssertEqual(after, before)
    }

    @MainActor
    func testProjectPlanAllPhaseBoardAndDependenciesRestoreExactScopeAndUnassignedSelection() async throws {
        let fixture = try await makeTask10PlanningFixture()
        try await fixture.store.transact(actor: .init(id: "phase5a-fixture"), reason: "Recorded planning navigation") { connection in
            try connection.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('PLAN-ONLY',?,NULL,'Retain this planned ticket',NULL)",
                bindings: [.text(fixture.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES ('plan-only-dependency',?,'PLAN-ONLY','ROAD-1')",
                bindings: [.text(fixture.projectID.rawValue)]
            )
        }
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()
        XCTAssertNil(model.dashboardError)
        XCTAssertNotNil(model.dashboard?.plan(for: fixture.projectID))

        await model.navigate(to: .projectPlan(fixture.projectID))
        model.selectTicket(.init(rawValue: "PLAN-ONLY"))
        await model.navigate(to: .dependencies(fixture.projectID))
        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID)?.selected.ticket.id.rawValue, "PLAN-ONLY")
        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID)?.selected.ticket.phaseName, "Unassigned")

        await model.goBack()
        XCTAssertEqual(model.selection, .projectPlan(fixture.projectID))
        XCTAssertEqual(model.selectedTicketID.rawValue, "PLAN-ONLY")
        XCTAssertEqual(model.navigationFocus, .ticket(.init(rawValue: "PLAN-ONLY")))

        model.viewAllPhases(projectID: fixture.projectID)
        await model.navigate(to: .phaseBoard(fixture.projectID))
        let boardTicket = try XCTUnwrap(model.viewedAllPhaseBoard(for: fixture.projectID)?.lanes.flatMap(\.cards).first?.id)
        model.selectTicket(boardTicket)
        await model.navigate(to: .activity(fixture.projectID))
        await model.goBack()

        XCTAssertEqual(model.selection, .phaseBoard(fixture.projectID))
        XCTAssertNotNil(model.viewedAllPhaseBoard(for: fixture.projectID))
        XCTAssertEqual(model.selectedTicketID, boardTicket)
        XCTAssertEqual(model.navigationFocus, .ticket(boardTicket))
    }

    @MainActor
    func testNativeProjectPlanAndAllPhaseBoardRenderWideAndCompactWithTruthfulMembership() async throws {
        let fixture = try await makeTask10PlanningFixture()
        try await fixture.store.transact(
            actor: .init(id: "phase5a-fixture"), reason: "Native recorded planning fixture",
            auditEventID: .init(rawValue: "phase5d-native-plan-audit"),
            auditScope: .init(projectID: fixture.projectID, entityType: .ticket, entityID: "RETIRED")
        ) { connection in
            try connection.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('PLAN-ONLY',?,NULL,'Retain planning without execution',NULL)",
                bindings: [.text(fixture.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('RETIRED',?,?,'Retained original scope','backlog')",
                bindings: [.text(fixture.projectID.rawValue), .text(fixture.roadmapPhaseID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES (?, 'RETIRED','replaced','Superseded by the retained successor',?,'backlog','phase5d-native-plan-audit','2026-09-10T00:00:00Z')",
                bindings: [.text(fixture.projectID.rawValue), .text(fixture.roadmapPhaseID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO ticket_successor_links (project_id,original_ticket_id,successor_ticket_id,relation,sort_order,audit_event_id,created_at) VALUES (?,'RETIRED','ROAD-1','replacement',0,'phase5d-native-plan-audit','2026-09-10T00:00:00Z')",
                bindings: [.text(fixture.projectID.rawValue)]
            )
        }
        let dashboard = try await DashboardProjection.load(from: fixture.store)
        let plan = try XCTUnwrap(dashboard.plan(for: fixture.projectID))
        let allBoard = try XCTUnwrap(dashboard.allPhaseBoard(for: fixture.projectID))
        XCTAssertEqual(plan.unassignedTickets.map(\.id.rawValue), ["PLAN-ONLY"])
        XCTAssertEqual(plan.retiredTickets.map(\.id.rawValue), ["RETIRED"])
        XCTAssertEqual(plan.retiredTickets.first?.successorTicketIDs.map(\.rawValue), ["ROAD-1"])
        XCTAssertEqual(allBoard.lanes.map(\.lane), TicketLane.allCases)
        XCTAssertFalse(allBoard.lanes.flatMap(\.cards).contains { $0.id.rawValue == "PLAN-ONLY" })
        XCTAssertTrue(allBoard.lanes.flatMap(\.cards).allSatisfy { $0.phaseName?.isEmpty == false })
        let selectionFilteredOut = allBoard.filtered(by: .goal(.init(rawValue: "road-goal-2")))
        XCTAssertFalse(selectionFilteredOut.details.isEmpty)
        XCTAssertNil(AllPhaseBoardView.inspectorDetail(
            in: selectionFilteredOut,
            selectedTicketID: .init(rawValue: "ROAD-1")
        ), "Filtering out the selection must not silently display another ticket")
        XCTAssertFalse(ProjectPlanLayout.usesStackedInspector(forWidth: 1_500))
        XCTAssertTrue(ProjectPlanLayout.usesStackedInspector(forWidth: 760))
        XCTAssertFalse(AllPhaseBoardLayout.usesStackedInspector(forWidth: 1_500))
        XCTAssertTrue(AllPhaseBoardLayout.usesStackedInspector(forWidth: 760))

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5A recorded planning — isolated native acceptance"
        defer { window.close() }

        for width in [1_500.0, 760.0] {
            let planHosting = NSHostingView(rootView: ProjectPlanView(
                plan: plan, selectedTicketID: .constant(.init(rawValue: "PLAN-ONLY")),
                openAllPhases: {}, openPhase: { _ in },
                requestedFocus: .ticket(.init(rawValue: "PLAN-ONLY"))
            ).environment(\.colorScheme, .dark))
            planHosting.appearance = window.appearance
            planHosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
            window.contentView = planHosting
            window.setContentSize(NSSize(width: width, height: 900))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .milliseconds(200))
            planHosting.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(planHosting.frame.width, width, accuracy: 1)
            try taskCapture(planHosting, name: "phase5a-project-plan-\(Int(width))")

            let selected = allBoard.lanes.flatMap(\.cards).first?.id ?? .init(rawValue: "")
            let boardHosting = NSHostingView(rootView: AllPhaseBoardView(
                board: allBoard, selectedTicketID: .constant(selected), filter: .constant(.all),
                viewPhase: { _ in }, requestedFocus: .ticket(selected)
            ).environment(\.colorScheme, .dark))
            boardHosting.appearance = window.appearance
            boardHosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
            window.contentView = boardHosting
            window.setContentSize(NSSize(width: width, height: 900))
            try await Task.sleep(for: .milliseconds(200))
            boardHosting.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(boardHosting.frame.width, width, accuracy: 1)
            try taskCapture(boardHosting, name: "phase5a-all-phase-board-\(Int(width))")
        }

        let interactionMarker = URL(fileURLWithPath: "/tmp/release-radar-phase5a-interaction-check")
        let completionMarker = URL(fileURLWithPath: "/tmp/release-radar-phase5a-interaction-complete")
        if FileManager.default.fileExists(atPath: interactionMarker.path),
           !FileManager.default.fileExists(atPath: completionMarker.path) {
            let model = AppModel(
                store: fixture.store,
                projectOnboarding: fixture.onboarding,
                externalServicesSuppressed: true
            )
            await model.loadDashboard()
            await model.navigate(to: .projectPlan(fixture.projectID))
            model.selectTicket(.init(rawValue: "PLAN-ONLY"))
            let interactionHosting = NSHostingView(rootView: SidebarView(model: model)
                .environment(\.colorScheme, .dark))
            interactionHosting.appearance = window.appearance
            interactionHosting.frame = NSRect(x: 0, y: 0, width: 1_500, height: 900)
            window.contentView = interactionHosting
            window.setContentSize(NSSize(width: 1_500, height: 900))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .milliseconds(500))
            interactionHosting.layoutSubtreeIfNeeded()
            print("PHASE5A INTERACTION READY: exercise Plan, all-phase board, Dependencies, Back, and Forward")
            for _ in 0..<900 where !FileManager.default.fileExists(atPath: completionMarker.path) {
                try await Task.sleep(for: .milliseconds(200))
            }
            XCTAssertEqual(model.selection, .dependencies(fixture.projectID))
            XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
            XCTAssertEqual(model.navigationFocus, .route(.dependencies(fixture.projectID)))
            try taskCapture(interactionHosting, name: "phase5a-interaction-final")
        }
    }

    @MainActor
    func testNativeRetiredOriginalRowOpensRetainedDetailAndRestoresFocusWideAndCompact() async throws {
        let fixture = try await makeTask10PlanningFixture(
            temporaryRoot: URL(
                fileURLWithPath: "/private/tmp/release-radar-phase5d-writer",
                isDirectory: true
            ),
            preserveDirectory: true
        )
        let retiredTicketID = TicketID(rawValue: "RETIRED")
        let evidenceURL = fixture.projectRoot.appendingPathComponent("retired-evidence.txt")
        try Data("Retained Phase 5D evidence\n".utf8).write(to: evidenceURL)
        try await fixture.store.transact(
            actor: .init(id: "phase5d-native-fixture"),
            reason: "Seed retained original native journey",
            auditEventID: .init(rawValue: "phase5d-native-journey-audit"),
            auditScope: .init(
                projectID: fixture.projectID,
                entityType: .ticket,
                entityID: retiredTicketID.rawValue
            )
        ) { connection in
            try connection.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('RETIRED',?,?,'Retained original scope','backlog')",
                bindings: [.text(fixture.projectID.rawValue), .text(fixture.roadmapPhaseID.rawValue)]
            )
            try connection.execute("INSERT INTO ticket_task_plans (project_id,ticket_id,revision,created_at,updated_at) VALUES (?,'RETIRED',1,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')", bindings: [.text(fixture.projectID.rawValue)])
            try connection.execute("INSERT INTO ticket_tasks (project_id,ticket_id,id,label,title,sort_order,completion,lifecycle,created_at,updated_at) VALUES (?,'RETIRED','retired-task','Retained','Retained original task',0,'pending','active','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')", bindings: [.text(fixture.projectID.rawValue)])
            try connection.execute("INSERT INTO evidence (id,project_id,ticket_id,path,is_available) VALUES ('retired-evidence',?,'RETIRED',?,1)", bindings: [.text(fixture.projectID.rawValue), .text(evidenceURL.path)])
            try connection.execute("INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES (?,'RETIRED','replaced','Superseded by the retained successor',?,'backlog','phase5d-native-journey-audit','2026-09-10T00:00:00Z')", bindings: [.text(fixture.projectID.rawValue), .text(fixture.roadmapPhaseID.rawValue)])
            try connection.execute("INSERT INTO ticket_successor_links (project_id,original_ticket_id,successor_ticket_id,relation,sort_order,audit_event_id,created_at) VALUES (?,'RETIRED','ROAD-1','replacement',0,'phase5d-native-journey-audit','2026-09-10T00:00:00Z')", bindings: [.text(fixture.projectID.rawValue)])
        }

        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await model.navigate(to: .projectPlan(fixture.projectID))
        model.selectTicket(.init(rawValue: "ROAD-1"))
        model.setNavigationFocus(.ticket(retiredTicketID))

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5D retired original — isolated native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.frame = window.contentView?.bounds ?? .zero
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(500))
        hosting.layoutSubtreeIfNeeded()

        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let nativeWindow = try XCTUnwrap(
            accessibilityWindow(application, title: window.title),
            "The isolated Phase 5D native window must be available to AX."
        )
        let retiredRowCandidate = await scrollToAccessibilityElement(
            nativeWindow, identifier: "retired-ticket-RETIRED"
        )
        let retiredRow = try XCTUnwrap(
            retiredRowCandidate,
            "The requested retained original must be brought into the native viewport."
        )
        try taskCapture(hosting, name: "phase5d-retired-original-wide-row")
        XCTAssertEqual(AXUIElementPerformAction(retiredRow, kAXPressAction as CFString), .success)
        for _ in 0..<30 where model.selectedTicketID != retiredTicketID {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(model.selectedTicketID, retiredTicketID)
        XCTAssertEqual(model.navigationFocus, .ticket(retiredTicketID))
        let wideInspector = await scrollToAccessibilityElement(
            nativeWindow, identifier: "project-plan-inspector"
        )
        _ = try XCTUnwrap(
            wideInspector,
            "The retained original inspector must be reachable after native activation."
        )
        let wideText = accessibilityText(nativeWindow)
        XCTAssertTrue(wideText.contains("Last placement: \(fixture.roadmapPhaseID.rawValue) · Backlog"))
        XCTAssertTrue(wideText.contains("Retained original task"))
        XCTAssertTrue(wideText.contains("retired-evidence.txt"))
        try taskCapture(hosting, name: "phase5d-retired-original-wide-detail")

        await model.navigate(to: .activity(fixture.projectID))
        await model.goBack()
        XCTAssertEqual(model.selection, .projectPlan(fixture.projectID))
        XCTAssertEqual(model.selectedTicketID, retiredTicketID)
        XCTAssertEqual(model.navigationFocus, .ticket(retiredTicketID))
        try await Task.sleep(for: .milliseconds(300))
        hosting.layoutSubtreeIfNeeded()
        let restoredRetiredRow = accessibilityElement(
            nativeWindow, identifier: "retired-ticket-RETIRED"
        )
        XCTAssertNotNil(
            restoredRetiredRow,
            "Back must reveal the retained row without requiring manual scrolling."
        )
        if let restoredRetiredRow {
            var restoredRowIsFocused: CFTypeRef?
            XCTAssertEqual(
                AXUIElementCopyAttributeValue(
                    restoredRetiredRow, kAXFocusedAttribute as CFString, &restoredRowIsFocused
                ),
                .success
            )
            XCTAssertEqual(restoredRowIsFocused as? Bool, true)
        }
        await model.goForward()
        XCTAssertEqual(model.selection, .activity(fixture.projectID))
        XCTAssertEqual(model.selectedTicketID, retiredTicketID)
        XCTAssertNil(
            model.navigationRecoveryMessage,
            "A retained ticket remains valid context on Activity history entries."
        )
        await model.goBack()

        window.setContentSize(NSSize(width: 760, height: 900))
        try await Task.sleep(for: .milliseconds(500))
        hosting.layoutSubtreeIfNeeded()
        let compactRowCandidate = await scrollToAccessibilityElement(
            nativeWindow, identifier: "retired-ticket-RETIRED"
        )
        let compactRow = try XCTUnwrap(
            compactRowCandidate,
            "The retained original must remain AX-reachable at compact width."
        )
        XCTAssertEqual(
            AXUIElementSetAttributeValue(compactRow, kAXFocusedAttribute as CFString, kCFBooleanTrue),
            .success
        )
        var isFocused: CFTypeRef?
        XCTAssertEqual(
            AXUIElementCopyAttributeValue(compactRow, kAXFocusedAttribute as CFString, &isFocused),
            .success
        )
        XCTAssertEqual(isFocused as? Bool, true)
        XCTAssertEqual(model.navigationFocus, .ticket(retiredTicketID))
        try taskCapture(hosting, name: "phase5d-retired-original-compact-row")
        let compactInspector = await scrollToAccessibilityElement(
            nativeWindow, identifier: "project-plan-inspector"
        )
        _ = try XCTUnwrap(
            compactInspector,
            "The retained original inspector must remain reachable at compact width."
        )
        let compactText = accessibilityText(nativeWindow)
        XCTAssertTrue(compactText.contains("Last placement: \(fixture.roadmapPhaseID.rawValue) · Backlog"))
        XCTAssertTrue(compactText.contains("Retained original task"))
        XCTAssertTrue(compactText.contains("retired-evidence.txt"))
        try taskCapture(hosting, name: "phase5d-retired-original-compact-detail")

        let externalInspectionMarker = URL(
            fileURLWithPath: "/private/tmp/release-radar-phase5d-writer/24-retired-native-external-6C0D43D8-enable"
        )
        let externalCompletionMarker = URL(
            fileURLWithPath: "/private/tmp/release-radar-phase5d-writer/24-retired-native-external-6C0D43D8-complete"
        )
        if FileManager.default.fileExists(atPath: externalInspectionMarker.path),
           !FileManager.default.fileExists(atPath: externalCompletionMarker.path) {
            window.title = "Phase 5D retained detail — external native acceptance 6C0D43D8"
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("PHASE5D EXTERNAL READY: inspect compact retained detail, then exercise Activity, Back, Forward, and Back; finish on the Project Plan with RETIRED focused")
            for _ in 0..<900 where !FileManager.default.fileExists(atPath: externalCompletionMarker.path) {
                try await Task.sleep(for: .milliseconds(200))
            }
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: externalCompletionMarker.path),
                "External inspection must signal completion within three minutes."
            )
            XCTAssertEqual(model.selection, .projectPlan(fixture.projectID))
            XCTAssertEqual(model.selectedTicketID, retiredTicketID)
            XCTAssertEqual(model.navigationFocus, .ticket(retiredTicketID))
        }
    }

    @MainActor
    func testNativeSuccessorProposalApprovesRelaunchesAppliesAndRestoresCompactRetiredFocus() async throws {
        let fixture = try await makeTask10PlanningFixture(
            temporaryRoot: URL(fileURLWithPath: "/private/tmp/release-radar-phase5d-writer", isDirectory: true),
            preserveDirectory: true
        )
        let originalID = TicketID(rawValue: "ROAD-1")
        let successorID = TicketID(rawValue: "ROAD-1-NEXT")
        let evidenceURL = fixture.projectRoot.appendingPathComponent("phase5d-native-owner-evidence.txt")
        try Data("Phase 5D owner journey evidence\n".utf8).write(to: evidenceURL)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed owner journey evidence") { connection in
            try connection.execute(
                "INSERT INTO evidence (id,project_id,ticket_id,path,is_available) VALUES ('phase5d-owner-evidence',?,'ROAD-1',?,1)",
                bindings: [.text(fixture.projectID.rawValue), .text(evidenceURL.path)]
            )
        }
        let registration = ProjectRegistration(
            projectID: fixture.projectID,
            registrationID: "phase5d-native-owner-registration",
            requestGeneration: 1
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Register native successor owner journey") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES (?, ?, 1, 'complete')",
                bindings: [.text(fixture.projectID.rawValue), .text(registration.registrationID)]
            )
        }
        let approvalModel = AppModel(
            store: fixture.store, projectOnboarding: fixture.onboarding, externalServicesSuppressed: true
        )
        await approvalModel.loadDashboard()
        await approvalModel.navigate(to: .projectPlan(fixture.projectID))
        let dispatcher = AgentCommandDispatcher(
            store: fixture.store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot])
            ])
        )
        let saved = await dispatcher.dispatch(.init(
            version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path,
            expectedRegistration: registration,
            reason: "Save native successor owner journey", command: .savePlanChangeProposal(
                proposalID: "phase5d-native-successor", expectedPreviousVersion: nil,
                rationale: "Replace retained scope through the owner workflow.", operations: [
                    .addUnassignedTicket(id: successorID, outcome: "Deliver the explicit successor"),
                    .addPendingTicketTasks(ticketID: successorID, tasks: [
                        .init(id: .init(rawValue: "phase5d-successor-task"), label: "Successor", title: "Deliver replacement scope", sortOrder: 0),
                    ]),
                    .placeTicket(ticketID: successorID, phaseID: fixture.roadmapPhaseID),
                    .assignTicketToGoal(ticketID: successorID, phaseID: fixture.roadmapPhaseID, goalID: .init(rawValue: "road-goal-1")),
                    .retireTicket(ticketID: originalID, disposition: .replaced, reason: "Use the explicit replacement", successorTicketIDs: [successorID]),
                    .carryGoalObligation(
                        source: .init(phaseID: fixture.roadmapPhaseID, goalID: .init(rawValue: "road-goal-1"), ticketID: originalID),
                        descendants: [.init(phaseID: fixture.roadmapPhaseID, goalID: .init(rawValue: "road-goal-1"), ticketID: successorID)],
                        reason: "The successor retains the original delivery scope"
                    ),
                ]
            )
        ))
        XCTAssertNil(saved.error)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }

        await approvalModel.loadDashboard()
        let approvalWindow = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        approvalWindow.isReleasedWhenClosed = false
        approvalWindow.appearance = NSAppearance(named: .darkAqua)
        approvalWindow.title = "Phase 5D successor approval — isolated native acceptance"
        let approvalHosting = NSHostingView(rootView: SidebarView(model: approvalModel).environment(\.colorScheme, .dark))
        approvalWindow.contentView = approvalHosting
        approvalWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { approvalWindow.close() }
        try await Task.sleep(for: .milliseconds(500))
        approvalHosting.layoutSubtreeIfNeeded()
        let approvalApplication = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let approvalNativeWindow = try XCTUnwrap(accessibilityWindow(approvalApplication, title: approvalWindow.title))
        for scrollBar in accessibilityElements(approvalNativeWindow, role: kAXScrollBarRole) {
            _ = AXUIElementSetAttributeValue(
                scrollBar, kAXValueAttribute as CFString, NSNumber(value: 1.0)
            )
        }
        try await Task.sleep(for: .milliseconds(200))
        let approvalText = accessibilityText(approvalNativeWindow)
        XCTAssertTrue(approvalText.contains("Before: \(fixture.roadmapPhaseID.rawValue) Backlog"))
        XCTAssertTrue(approvalText.contains("Original scope: Roadmap backlog one."))
        XCTAssertTrue(approvalText.contains("ROAD-1-NEXT → road-goal-1 in \(fixture.roadmapPhaseID.rawValue)"))
        let approveCandidate = await scrollToAccessibilityElement(
            approvalNativeWindow, identifier: "approve-plan-change-proposal"
        )
        let approve = try XCTUnwrap(approveCandidate)
        XCTAssertEqual(AXUIElementPerformAction(approve, kAXPressAction as CFString), .success)
        for _ in 0..<50 {
            let decisionCount = try await fixture.store.read {
                try $0.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_decisions WHERE proposal_id='phase5d-native-successor'") ?? 0
            }
            if decisionCount == 1 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let approvalState = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM plan_change_proposal_decisions WHERE proposal_id='phase5d-native-successor'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_retirements WHERE ticket_id='ROAD-1'")
            )
        }
        XCTAssertEqual(approvalState.0, 1)
        XCTAssertEqual(approvalState.1, 0, "Approval alone must not apply the successor package.")
        guard approvalState.0 == 1 else { return }
        approvalWindow.close()

        let relaunchedModel = AppModel(
            store: fixture.store, projectOnboarding: fixture.onboarding, externalServicesSuppressed: true
        )
        await relaunchedModel.loadDashboard()
        await relaunchedModel.navigate(to: .projectPlan(fixture.projectID))
        let applyWindow = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        applyWindow.isReleasedWhenClosed = false
        applyWindow.appearance = NSAppearance(named: .darkAqua)
        applyWindow.title = "Phase 5D successor apply — isolated native acceptance"
        let applyHosting = NSHostingView(rootView: SidebarView(model: relaunchedModel).environment(\.colorScheme, .dark))
        applyWindow.contentView = applyHosting
        applyWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { applyWindow.close() }
        try await Task.sleep(for: .milliseconds(500))
        applyHosting.layoutSubtreeIfNeeded()
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: applyWindow.title))
        for scrollBar in accessibilityElements(nativeWindow, role: kAXScrollBarRole) {
            _ = AXUIElementSetAttributeValue(
                scrollBar, kAXValueAttribute as CFString, NSNumber(value: 1.0)
            )
        }
        try await Task.sleep(for: .milliseconds(200))
        let applyCandidate = await scrollToAccessibilityElement(
            nativeWindow, identifier: "apply-plan-change-proposal"
        )
        let apply = try XCTUnwrap(applyCandidate)
        XCTAssertEqual(AXUIElementPerformAction(apply, kAXPressAction as CFString), .success)
        for _ in 0..<50 {
            let retirementCount = try await fixture.store.read {
                try $0.scalarInt("SELECT COUNT(*) FROM ticket_retirements WHERE ticket_id='ROAD-1'") ?? 0
            }
            if retirementCount == 1 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let appliedRetirementCount = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM ticket_retirements WHERE ticket_id='ROAD-1'")
        }
        XCTAssertEqual(appliedRetirementCount, 1)

        relaunchedModel.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        let phaseBoard = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "sidebar-phase-board"))
        XCTAssertEqual(AXUIElementPerformAction(phaseBoard, kAXPressAction as CFString), .success)
        for _ in 0..<30 where relaunchedModel.selection != .phaseBoard(fixture.projectID) {
            try await Task.sleep(for: .milliseconds(100))
        }
        let successorCandidate = await scrollToAccessibilityElement(
            nativeWindow, identifier: "ticket-ROAD-1-NEXT"
        )
        let successor = try XCTUnwrap(successorCandidate)
        XCTAssertEqual(AXUIElementPerformAction(successor, kAXPressAction as CFString), .success)
        XCTAssertEqual(relaunchedModel.selectedTicketID, successorID)

        let projectPlan = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "sidebar-project-plan"))
        XCTAssertEqual(AXUIElementPerformAction(projectPlan, kAXPressAction as CFString), .success)
        for _ in 0..<30 where relaunchedModel.selection != .projectPlan(fixture.projectID) {
            try await Task.sleep(for: .milliseconds(100))
        }
        let originalCandidate = await scrollToAccessibilityElement(
            nativeWindow, identifier: "retired-ticket-ROAD-1"
        )
        let original = try XCTUnwrap(originalCandidate)
        XCTAssertEqual(AXUIElementPerformAction(original, kAXPressAction as CFString), .success)
        let retainedText = accessibilityText(nativeWindow)
        XCTAssertTrue(retainedText.contains("Last placement: \(fixture.roadmapPhaseID.rawValue) · Backlog"))
        XCTAssertTrue(retainedText.contains("Verify the complete outcome"))
        XCTAssertTrue(retainedText.contains("phase5d-native-owner-evidence.txt"))

        applyWindow.setContentSize(NSSize(width: 760, height: 900))
        try await Task.sleep(for: .milliseconds(500))
        let activity = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "sidebar-activity"))
        XCTAssertEqual(AXUIElementPerformAction(activity, kAXPressAction as CFString), .success)
        for _ in 0..<30 where relaunchedModel.selection != .activity(fixture.projectID) {
            try await Task.sleep(for: .milliseconds(100))
        }
        let back = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "navigation-back"))
        XCTAssertEqual(AXUIElementPerformAction(back, kAXPressAction as CFString), .success)
        for _ in 0..<30 where relaunchedModel.selection != .projectPlan(fixture.projectID) {
            try await Task.sleep(for: .milliseconds(100))
        }
        try await Task.sleep(for: .milliseconds(300))
        applyHosting.layoutSubtreeIfNeeded()
        let automaticallyRestoredRow = accessibilityElement(nativeWindow, identifier: "retired-ticket-ROAD-1")
        XCTAssertNotNil(automaticallyRestoredRow, "Compact Back must reveal the retained row without manual scrolling.")
        if let automaticallyRestoredRow {
            var focused: CFTypeRef?
            XCTAssertEqual(AXUIElementCopyAttributeValue(
                automaticallyRestoredRow, kAXFocusedAttribute as CFString, &focused
            ), .success)
            XCTAssertEqual(focused as? Bool, true)
        }
        XCTAssertNil(relaunchedModel.navigationRecoveryMessage)
    }

    @MainActor
    func testTask10OwnerAcceptanceUsesTrustedOriginAndCannotRepeatFromStaleInbox() async throws {
        let fixture = try await makeTask10AwaitingGoalFixture()
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding,
                             externalServicesSuppressed: true)
        await model.loadDashboard()
        model.selection = .phaseBoard(fixture.projectID)
        let item = try XCTUnwrap(model.reviewInbox(for: fixture.projectID)?.deliveryGoalAcceptances.first)
        XCTAssertEqual(model.needsReviewCount, 1)
        let before = try await task10GoalState(fixture.store)
        await model.acceptDeliveryGoal(item)
        let after = try await task10GoalState(fixture.store)
        XCTAssertEqual(after.lifecycle, "accepted")
        XCTAssertEqual(after.ownerAudits, before.ownerAudits + 1)
        XCTAssertEqual(after.requests, before.requests + 1)
        XCTAssertEqual(after.notifications, before.notifications)
        XCTAssertEqual(model.needsReviewCount, 0)
        await model.acceptDeliveryGoal(item)
        let repeated = try await task10GoalState(fixture.store)
        XCTAssertEqual(repeated, after)
    }

    @MainActor
    func testTask10AcceptanceFailsClosedOnAuthorizationAndRevisionConflict() async throws {
        let fixture = try await makeTask10AwaitingGoalFixture()
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding,
                             externalServicesSuppressed: true)
        await model.loadDashboard()
        let item = try XCTUnwrap(model.reviewInbox(for: fixture.projectID)?.deliveryGoalAcceptances.first)
        let before = try await task10GoalState(fixture.store)
        fixture.bookmarks.setFailureMode(.accessDenied)
        await model.acceptDeliveryGoal(item)
        XCTAssertNotNil(model.scopedReviewAuthorizationRecovery(for: fixture.projectID))
        let denied = try await task10GoalState(fixture.store)
        XCTAssertEqual(denied, before)
        fixture.bookmarks.setFailureMode(.none)
        await model.recoverReviewAuthorization(at: fixture.projectRoot, for: fixture.projectID)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Concurrent structural revision") { c in
            try c.execute("UPDATE phase_plans SET revision = revision + 1, state = 'draft', ready_revision = NULL WHERE phase_id = 'phase-empty'")
        }
        await model.acceptDeliveryGoal(item)
        XCTAssertTrue(model.deliveryGoalAcceptanceNeedsReload(for: fixture.projectID))
        XCTAssertTrue(model.scopedReviewActionFailure(for: fixture.projectID)?.detail.contains("revision") == true)
        let conflicted = try await task10GoalState(fixture.store)
        XCTAssertEqual(conflicted, before)
        await model.reloadDeliveryGoalAcceptance(projectID: fixture.projectID)
        XCTAssertFalse(model.deliveryGoalAcceptanceNeedsReload(for: fixture.projectID))
        XCTAssertEqual(model.reviewInbox(for: fixture.projectID)?.deliveryGoalAcceptances.first?.expectedPlanRevision, item.expectedPlanRevision + 1)
    }

    @MainActor
    func testTask10SavedAcceptanceRefreshFailureBlocksDuplicateAndPreservesViewedPhase() async throws {
        let fixture = try await makeTask10AwaitingGoalFixture()
        let loader = RouteDashboardLoader(failingCalls: [2])
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding,
            dashboardLoader: { try await loader.load(from: $0) }, externalServicesSuppressed: true)
        await model.loadDashboard()
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        let item = try XCTUnwrap(model.reviewInbox(for: fixture.projectID)?.deliveryGoalAcceptances.first)
        await model.acceptDeliveryGoal(item)
        XCTAssertTrue(model.deliveryGoalAcceptanceNeedsReload(for: fixture.projectID))
        XCTAssertTrue(model.scopedReviewActionFailure(for: fixture.projectID)?.detail.contains("saved") == true)
        let saved = try await task10GoalState(fixture.store)
        await model.acceptDeliveryGoal(item)
        let duplicate = try await task10GoalState(fixture.store)
        XCTAssertEqual(duplicate, saved)
        await model.reloadDeliveryGoalAcceptance(projectID: fixture.projectID)
        XCTAssertFalse(model.deliveryGoalAcceptanceNeedsReload(for: fixture.projectID))
        XCTAssertTrue(model.reviewInbox(for: fixture.projectID)?.deliveryGoalAcceptances.isEmpty == true)
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
    }

    @MainActor
    private func makeTask10AwaitingGoalFixture(
        temporaryRoot: URL = FileManager.default.temporaryDirectory,
        preserveDirectory: Bool = false
    ) async throws -> RR9OwnerFixture {
        let fixture = try await makeRR9OwnerFixture(
            temporaryRoot: temporaryRoot,
            preserveDirectory: preserveDirectory
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Synthetic completed work") { c in
            try c.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('DONE-1','rr9-owner-project','phase-empty','Complete the owner outcome','backlog')")
        }
        let dispatcher = AgentCommandDispatcher(store: fixture.store, projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: fixture.projectID, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot])
        ]))
        let commands: [AgentCommand] = [
            .applyPhasePlanRevision(projectID: fixture.projectID.rawValue, phaseID: "phase-empty", expectedRevision: 0,
                goalUpserts: [.init(id: .init(rawValue: "complete-goal"), title: "Owner outcome", outcome: "Complete the owner outcome",
                                   doneCriteria: ["Owner can verify the complete outcome"], sortOrder: 0)],
                assignments: [.init(goalID: .init(rawValue: "complete-goal"), ticketID: .init(rawValue: "DONE-1"))],
                unassignedTicketIDs: [], supersededGoalIDs: []),
            .finalizePhasePlan(projectID: fixture.projectID.rawValue, phaseID: "phase-empty", expectedRevision: 1),
            .transitionTicket(ticketID: "DONE-1", lane: .inProgress),
            .transitionTicket(ticketID: "DONE-1", lane: .needsReview),
            .transitionTicket(ticketID: "DONE-1", lane: .accepted),
            .transitionDeliveryGoal(projectID: fixture.projectID.rawValue, phaseID: "phase-empty", goalID: "complete-goal", expectedPlanRevision: 1, lifecycle: .awaitingAcceptance)
        ]
        for command in commands {
            let result = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path,
                reason: "Prepare synthetic owner acceptance", command: command))
            XCTAssertNil(result.error)
        }
        return fixture
    }

    @MainActor
    func testPlanChangeProposalProjectionOwnerWorkflowAndNavigationPreserveExactVersion() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let registration = ProjectRegistration(
            projectID: fixture.projectID,
            registrationID: "proposal-registration",
            requestGeneration: 1
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Register proposal UI fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, 1, 'complete')",
                bindings: [.text(fixture.projectID.rawValue), .text(registration.registrationID)]
            )
        }
        let dispatcher = AgentCommandDispatcher(
            store: fixture.store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot])
            ])
        )
        let save = await dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: fixture.projectRoot.path,
            expectedRegistration: registration,
            reason: "Save native proposal fixture",
            command: .savePlanChangeProposal(
                proposalID: "proposal-native",
                expectedPreviousVersion: nil,
                rationale: "Add a pending verification task without starting the ticket.",
                operations: [
                    .addPendingTicketTasks(
                        ticketID: .init(rawValue: "ROAD-1"),
                        tasks: [.init(
                            id: .init(rawValue: "proposal-task"),
                            label: "Proposal task",
                            title: "Verify the proposal workflow",
                            sortOrder: 0
                        )]
                    )
                ]
            )
        ))
        XCTAssertNil(save.error)

        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        let projected = try XCTUnwrap(model.dashboard?.plan(for: fixture.projectID)?.proposals.first)
        let version = try XCTUnwrap(projected.versions.first)
        XCTAssertEqual(projected.id.rawValue, "proposal-native")
        XCTAssertEqual(version.version, 1)

        await model.navigate(to: .projectPlan(fixture.projectID))
        model.setNavigationFocus(.planChangeProposal(
            proposalID: projected.id.rawValue,
            version: version.version,
            ticketID: .init(rawValue: "ROAD-1")
        ))
        await model.navigate(to: .activity(fixture.projectID))
        await model.goBack()
        XCTAssertEqual(model.selection, .projectPlan(fixture.projectID))
        XCTAssertEqual(model.navigationFocus, .planChangeProposal(
            proposalID: "proposal-native",
            version: 1,
            ticketID: .init(rawValue: "ROAD-1")
        ))

        let refresh = await model.refreshPlanChangeProposal(
            projectID: fixture.projectID,
            proposalID: projected.id,
            previousVersion: version.version,
            rationale: version.rationale,
            operations: version.operations
        )
        XCTAssertNil(refresh.error)
        XCTAssertEqual(refresh.planChangeProposalVersion, 2)
        let refreshedProposal = try XCTUnwrap(model.dashboard?.plan(for: fixture.projectID)?.proposals.first)
        XCTAssertEqual(refreshedProposal.currentVersion, 2)
        XCTAssertNil(refreshedProposal.versions.first(where: { $0.version == 1 })?.decision)
        let refreshed = try XCTUnwrap(refreshedProposal.versions.first(where: { $0.version == 2 }))

        let approval = await model.decidePlanChangeProposal(
            projectID: fixture.projectID,
            proposalID: projected.id,
            version: refreshed.version,
            baselineDigest: refreshed.baselineDigest,
            disposition: .approved
        )
        XCTAssertNil(approval.error)
        let taskCountAfterApproval = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE id = 'proposal-task'")
        }
        XCTAssertEqual(taskCountAfterApproval, 0)
        let approved = try XCTUnwrap(model.dashboard?.plan(for: fixture.projectID)?.proposals.first?.versions.first)
        XCTAssertEqual(approved.decision?.disposition, .approved)

        let application = await model.applyPlanChangeProposal(
            projectID: fixture.projectID,
            proposalID: projected.id,
            version: approved.version,
            baselineDigest: approved.baselineDigest,
            decisionID: try XCTUnwrap(approved.decision?.id)
        )
        XCTAssertNil(application.error)
        let applied = try XCTUnwrap(model.dashboard?.plan(for: fixture.projectID)?.proposals.first?.versions.first)
        XCTAssertNotNil(applied.application)
        let appliedTaskState = try await fixture.store.read {
            try $0.scalarText("SELECT completion || '|' || lifecycle FROM ticket_tasks WHERE id = 'proposal-task'")
        }
        XCTAssertEqual(appliedTaskState, "pending|active")
    }

    @MainActor
    func testNativePlanChangeProposalRendersWideAndCompactWithExactVersionFocus() async throws {
        let scenario = try await makePlanChangeProposalRenderScenario()
        let plan = scenario.plan
        let impact = scenario.impact
        XCTAssertEqual(impact.ticketID, TicketID(rawValue: "ROAD-1"))

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5C proposals — isolated native acceptance"
        defer { window.close() }

        for width in [1_500.0, 760.0] {
            let hosting = NSHostingView(rootView: ProjectPlanView(
                plan: plan,
                selectedTicketID: .constant(.init(rawValue: "")),
                openAllPhases: {},
                openPhase: { _ in },
                decideProposal: { _, _, _, _ in
                    .init(entityIDs: [], auditEventID: nil, error: nil)
                },
                applyProposal: { _, _, _, _ in
                    .init(entityIDs: [], auditEventID: nil, error: nil)
                },
                refreshProposal: { _, _, _, _ in
                    .init(entityIDs: [], auditEventID: nil, error: nil, planChangeProposalVersion: 2)
                },
                requestedFocus: .planChangeProposal(
                    proposalID: "proposal-render",
                    version: 1,
                    ticketID: .init(rawValue: "PROPOSED-1")
                )
            ).environment(\.colorScheme, .dark))
            hosting.appearance = window.appearance
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
            window.contentView = hosting
            window.setContentSize(NSSize(width: width, height: 900))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .milliseconds(200))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(hosting.frame.width, width, accuracy: 1)
            try taskCapture(hosting, name: "phase5c-proposal-\(Int(width))")
        }
    }

    @MainActor
    func testLivePlanChangeProposalJourneyRestoresExactSourceFocusWideAndCompact() async throws {
        let enableMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5c-writer/23-live-focus-enabled")
        guard FileManager.default.fileExists(atPath: enableMarker.path) else {
            throw XCTSkip("Create the one-shot Phase 5C interaction marker to run this isolated native journey.")
        }
        let wideCompleteMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5c-writer/23-live-focus-wide-complete")
        let compactCompleteMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5c-writer/23-live-focus-compact-complete")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wideCompleteMarker.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: compactCompleteMarker.path))

        let scenario = try await makePlanChangeProposalRenderScenario()
        let model = AppModel(
            store: scenario.fixture.store,
            projectOnboarding: scenario.fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await model.navigate(to: .projectPlan(scenario.fixture.projectID))
        let exactFocus = NavigationFocus.planChangeProposal(
            proposalID: scenario.proposalID.rawValue,
            version: 1,
            ticketID: scenario.impact.ticketID
        )
        model.setNavigationFocus(exactFocus)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5C proposals — isolated native interaction"
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(model.navigationFocus, exactFocus)
        print("PHASE5C WIDE READY: verify initial source focus; select proposal/source; Back and Forward")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: wideCompleteMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: wideCompleteMarker.path))
        XCTAssertEqual(
            model.selection,
            .referenceSource(
                projectID: scenario.fixture.projectID,
                ticketID: scenario.impact.ticketID,
                linkID: scenario.impact.linkID,
                version: scenario.impact.version
            )
        )
        await model.goBack()
        XCTAssertEqual(model.selection, .projectPlan(scenario.fixture.projectID))
        XCTAssertEqual(model.navigationFocus, exactFocus)
        window.setContentSize(NSSize(width: 760, height: 900))
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        print("PHASE5C COMPACT READY: verify initial source focus and scroll; select proposal/source; Back and Forward")

        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactCompleteMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactCompleteMarker.path))
        XCTAssertEqual(
            model.selection,
            .referenceSource(
                projectID: scenario.fixture.projectID,
                ticketID: scenario.impact.ticketID,
                linkID: scenario.impact.linkID,
                version: scenario.impact.version
            )
        )
        XCTAssertEqual(
            model.navigationFocus,
            .referenceSource(linkID: scenario.impact.linkID, version: scenario.impact.version)
        )
        try taskCapture(hosting, name: "phase5c-proposal-live-journey-final")
    }

    @MainActor
    private func makePlanChangeProposalRenderScenario() async throws -> PlanChangeProposalRenderScenario {
        let fixture = try await makeRR9OwnerFixture(
            temporaryRoot: URL(fileURLWithPath: "/Users/Shared", isDirectory: true),
            preserveDirectory: true
        )
        let documents = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid/docs", isDirectory: true)
        try FileManager.default.copyItem(at: documents, to: fixture.projectRoot.appendingPathComponent("docs"))
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: fixture.projectRoot.appendingPathComponent("AGENTS.md"))
        let registration = ProjectRegistration(
            projectID: fixture.projectID,
            registrationID: "proposal-render-registration",
            requestGeneration: 1
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Register proposal render fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, 1, 'complete')",
                bindings: [.text(fixture.projectID.rawValue), .text(registration.registrationID)]
            )
        }
        let dispatcher = AgentCommandDispatcher(
            store: fixture.store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot])
            ]),
            bookmarkStore: fixture.bookmarks
        )
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: fixture.projectRoot)
        let target = DocumentationTarget(
            projectID: fixture.projectID.rawValue,
            rootID: "rr9-owner-root",
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
        func envelope(_ command: AgentCommand, reason: String) -> AgentCommandEnvelope {
            .init(
                version: 1,
                requestID: UUID(),
                projectRoot: fixture.projectRoot.path,
                expectedRegistration: registration,
                reason: reason,
                command: command
            )
        }
        let bound = await dispatcher.dispatch(envelope(
            .bindDocumentationRepository(target: target),
            reason: "Bind proposal render documentation"
        ))
        XCTAssertNil(bound.error)
        let artifact = try XCTUnwrap(snapshot.catalog.artifacts.first { $0.artifactID == "current" })
        let source = fixture.projectRoot.appendingPathComponent(artifact.path)
        let linked = await dispatcher.dispatch(envelope(
            .upsertTicketReference(
                target: target,
                ticketID: "ROAD-1",
                linkID: "proposal-requirement",
                kind: .requirement,
                artifactID: artifact.artifactID,
                sourceLocalID: nil,
                locator: nil,
                expectedContentDigest: documentationDigest(try Data(contentsOf: source)),
                expectedLinkSetRevision: 0
            ),
            reason: "Record proposal render requirement"
        ))
        XCTAssertNil(linked.error)
        let proposalID = PlanChangeProposalID(rawValue: "proposal-render")
        let save = await dispatcher.dispatch(envelope(
            .savePlanChangeProposal(
                proposalID: proposalID.rawValue,
                expectedPreviousVersion: nil,
                rationale: "Show a bounded proposal with grouped changes and deliberate owner actions.",
                operations: [
                    .addPhase(id: .init(rawValue: "phase-proposed"), name: "Proposed phase"),
                    .addUnassignedTicket(id: .init(rawValue: "PROPOSED-1"), outcome: "Deliver proposed work"),
                    .addPendingTicketTasks(
                        ticketID: .init(rawValue: "ROAD-1"),
                        tasks: [.init(
                            id: .init(rawValue: "proposal-render-task"),
                            label: "Proposal render task",
                            title: "Keep recorded requirement focus",
                            sortOrder: 0
                        )]
                    )
                ]
            ),
            reason: "Save proposal render fixture"
        ))
        XCTAssertNil(save.error)
        let dashboard = try await DashboardProjection.load(from: fixture.store)
        let plan = try XCTUnwrap(dashboard.plan(for: fixture.projectID))
        let impact = try XCTUnwrap(plan.proposals.first?.versions.first?.sourceImpacts.first)
        return .init(fixture: fixture, proposalID: proposalID, plan: plan, impact: impact)
    }

    @MainActor
    private func task10GoalState(_ store: DeliveryStore) async throws -> Task10GoalState {
        try await store.read { c in
            Task10GoalState(lifecycle: try c.scalarText("SELECT lifecycle FROM delivery_goals WHERE id='complete-goal'"),
                ownerAudits: try c.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id='release-radar-owner' AND entity_type='delivery_goal'") ?? -1,
                requests: try c.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
                notifications: try c.scalarInt("SELECT COUNT(*) FROM notification_events") ?? -1)
        }
    }

    @MainActor
    private func makeTask10PlanningFixture(
        temporaryRoot: URL = FileManager.default.temporaryDirectory,
        preserveDirectory: Bool = false
    ) async throws -> RR9OwnerFixture {
        let fixture = try await makeTask10AwaitingGoalFixture(
            temporaryRoot: temporaryRoot,
            preserveDirectory: preserveDirectory
        )
        _ = try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Task 10 read-only task regression") { c in
            try TicketTaskPlanningPolicy.revisePlan(projectID: fixture.projectID,
                ticketID: .init(rawValue: "ROAD-1"), expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "road-task"), label: "Task 1", title: "Verify the complete outcome", sortOrder: 0)],
                definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let dispatcher = AgentCommandDispatcher(store: fixture.store, projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: fixture.projectID, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot])
        ]))
        let organized = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path,
            reason: "Organize synthetic roadmap for filter verification", command: .applyPhasePlanRevision(
                projectID: fixture.projectID.rawValue, phaseID: fixture.roadmapPhaseID.rawValue, expectedRevision: 0,
                goalUpserts: ["road-goal-1", "road-goal-2"].enumerated().map { index, id in
                    .init(id: .init(rawValue: id), title: "Roadmap outcome \(index + 1)", outcome: "Deliver roadmap outcome \(index + 1)",
                          doneCriteria: ["Verify roadmap outcome \(index + 1)"], sortOrder: index)
                }, assignments: [.init(goalID: .init(rawValue: "road-goal-1"), ticketID: .init(rawValue: "ROAD-1")),
                                  .init(goalID: .init(rawValue: "road-goal-2"), ticketID: .init(rawValue: "ROAD-2"))],
                unassignedTicketIDs: [], supersededGoalIDs: [])))
        XCTAssertNil(organized.error)
        return fixture
    }

    @MainActor
    func testNonactivePhaseTicketDependenciesBackRestoresContextAndNativeFocus() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()
        let ticketID = TicketID(rawValue: "ROAD-1")
        let filter = DeliveryGoalFilter.goal(.init(rawValue: "road-goal-1"))
        await model.navigate(to: .phaseBoard(fixture.projectID))
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.setBoardFilter(filter, projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.selectTicket(ticketID)
        await model.navigate(to: .dependencies(fixture.projectID))

        await model.goBack()

        XCTAssertEqual(model.selection, .phaseBoard(fixture.projectID))
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
        XCTAssertEqual(model.boardFilter(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID), filter)
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertEqual(model.navigationFocus, .ticket(ticketID))

        let hosting = NSHostingView(rootView: Task10BoardTestView(
            model: model,
            projectID: fixture.projectID,
            initialFilter: filter
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: 1_420, height: 860)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.isReleasedWhenClosed = false
        window.title = "Phase 4 Restored Focus — isolated native acceptance"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)
        try taskCapture(hosting, name: "phase4-restored-nonactive-board-focus")
        let marker = URL(fileURLWithPath: "/tmp/release-radar-phase4-restored-focus-check", isDirectory: true)
        if FileManager.default.fileExists(atPath: marker.path) {
            try? FileManager.default.removeItem(at: marker)
            print("PHASE4 RESTORED FOCUS READY: verify ROAD-1 focus")
            try await Task.sleep(for: .seconds(30))
        }
    }

    @MainActor
    func testFirstOpenedBoardRestoresTheActuallyRenderedPhaseAfterActivePhaseChanges() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(fixture.projectID))

        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.currentPhaseID)
        await model.navigate(to: .dependencies(fixture.projectID))
        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)

        await model.goBack()

        XCTAssertEqual(model.selection, .phaseBoard(fixture.projectID))
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, fixture.currentPhaseID)
        XCTAssertNil(model.navigationRecoveryMessage)
    }

    @MainActor
    func testReloadRecoversToProjectOverviewWhenTheViewedPhaseDisappears() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let disappearingPhaseID = PhaseID(rawValue: "phase-disappearing")
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Add removable viewed phase") { connection in
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, 'Disappearing')",
                bindings: [.text(disappearingPhaseID.rawValue), .text(fixture.projectID.rawValue)]
            )
        }
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(fixture.projectID))
        model.viewPhase(projectID: fixture.projectID, phaseID: disappearingPhaseID)
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.phaseID, disappearingPhaseID)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Remove the viewed phase") { connection in
            try connection.execute(
                "DELETE FROM phases WHERE project_id = ? AND id = ?",
                bindings: [.text(fixture.projectID.rawValue), .text(disappearingPhaseID.rawValue)]
            )
        }

        await model.reloadDashboardAfterCommittedAgentCommand()

        XCTAssertEqual(model.selection, .projectOverview(fixture.projectID))
        XCTAssertNil(model.viewedBoard(for: fixture.projectID))
        XCTAssertTrue(model.navigationRecoveryMessage?.contains("previously viewed phase is unavailable") == true)
    }

    @MainActor
    func testBoardReloadPreservesUnavailableTicketIdentityWithoutSelectingAnotherTicket() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let ticketID = TicketID(rawValue: "STALE-BOARD")
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Add stale board selection fixture") { connection in
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, 'Moves out of the viewed board.', 'backlog')",
                bindings: [.text(ticketID.rawValue), .text(fixture.projectID.rawValue), .text(fixture.roadmapPhaseID.rawValue)]
            )
        }
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(fixture.projectID))
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.selectTicket(ticketID)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Move selected ticket out of viewed phase") { connection in
            try connection.execute(
                "UPDATE tickets SET phase_id = ? WHERE project_id = ? AND id = ?",
                bindings: [.text(fixture.currentPhaseID.rawValue), .text(fixture.projectID.rawValue), .text(ticketID.rawValue)]
            )
        }

        await model.reloadDashboardAfterCommittedAgentCommand()

        XCTAssertEqual(model.selection, .phaseBoard(fixture.projectID))
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertNil(model.viewedBoard(for: fixture.projectID)?.detail(for: ticketID))
        XCTAssertTrue(model.navigationRecoveryMessage?.contains(ticketID.rawValue) == true)
    }

    @MainActor
    func testDependenciesReloadPreservesUnavailableTicketIdentityWithoutUnrelatedGraph() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let ticketID = TicketID(rawValue: "STALE-DEPENDENCIES")
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Add stale dependency selection fixture") { connection in
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, 'Disappears while dependencies are open.', 'backlog')",
                bindings: [.text(ticketID.rawValue), .text(fixture.projectID.rawValue), .text(fixture.roadmapPhaseID.rawValue)]
            )
        }
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(fixture.projectID))
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.selectTicket(ticketID)
        await model.navigate(to: .dependencies(fixture.projectID))
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Remove selected dependency ticket") { connection in
            try connection.execute(
                "DELETE FROM tickets WHERE project_id = ? AND id = ?",
                bindings: [.text(fixture.projectID.rawValue), .text(ticketID.rawValue)]
            )
        }

        await model.reloadDashboardAfterCommittedAgentCommand()

        XCTAssertEqual(model.selection, .dependencies(fixture.projectID))
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertNil(model.dependencyGraph(for: fixture.projectID))
        XCTAssertTrue(model.navigationRecoveryMessage?.contains(ticketID.rawValue) == true)
    }

    @MainActor
    func testInitialEmptySelectionStillChoosesTheExistingDefaultTicketAndGraph() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        model.selectedTicketID = TicketID(rawValue: "")

        await model.loadDashboard()

        XCTAssertEqual(model.selectedTicketID.rawValue, "CURRENT-1")
        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID)?.selected.ticket.id.rawValue, "CURRENT-1")
    }

    @MainActor
    func testTask10PhaseSwitchResetsFilterWithoutClearingNewSelection() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let model = AppModel(store: fixture.store, externalServicesSuppressed: true)
        await model.loadDashboard()
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        let hosting = NSHostingView(rootView: Task10BoardTestView(model: model, projectID: fixture.projectID,
            initialFilter: .goal(.init(rawValue: "road-goal-1"))))
        let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 1600, height: 900),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.currentPhaseID)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(model.selectedTicketID.rawValue, "CURRENT-1")
    }

    @MainActor
    func testTask10FilteredSelectionReconcilesAfterSamePhaseReload() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding,
                             externalServicesSuppressed: true)
        await model.loadDashboard()
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.selectedTicketID = .init(rawValue: "ROAD-1")
        let hosting = NSHostingView(rootView: Task10BoardTestView(model: model, projectID: fixture.projectID,
            initialFilter: .goal(.init(rawValue: "road-goal-1"))))
        let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 1600, height: 900),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        // An unchanged reload must preserve the still-visible selected ticket and its task data.
        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
        XCTAssertEqual(model.viewedBoard(for: fixture.projectID)?.lane(.backlog)?.cards.first { $0.id == model.selectedTicketID }?.activeTaskCount, 1)
        let dispatcher = AgentCommandDispatcher(store: fixture.store, projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: fixture.projectID, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot])
        ]))
        let result = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path,
            reason: "Synthetic concurrent reassignment", command: .applyPhasePlanRevision(
                projectID: fixture.projectID.rawValue, phaseID: fixture.roadmapPhaseID.rawValue, expectedRevision: 1,
                goalUpserts: [], assignments: [.init(goalID: .init(rawValue: "road-goal-2"), ticketID: .init(rawValue: "ROAD-1"))],
                unassignedTicketIDs: [], supersededGoalIDs: [])))
        XCTAssertNil(result.error)
        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
        for _ in 0..<20 where !model.selectedTicketID.rawValue.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(model.selectedTicketID.rawValue, "", "A reload that hides selection must clear it instead of showing a different inspector")
        XCTAssertNotNil(model.viewedBoard(for: fixture.projectID)?.detail(for: .init(rawValue: "ROAD-1")))
    }

    @MainActor
    func testTask10NativePlanningControlsAndInspectorWideCompact() async throws {
        let fixture = try await makeTask10PlanningFixture()
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding,
                             externalServicesSuppressed: true)
        await model.loadDashboard()
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let widths = ProcessInfo.processInfo.environment["RR_TASK10_INSPECT_WIDTH"] == "760"
            ? [760.0] : [1600.0, 760.0]
        for width in widths {
            let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: width, height: 900),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = "RR-R10 Task 10 — isolated native acceptance"
            window.appearance = NSAppearance(named: .darkAqua)
            defer { window.close() }
            model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
            model.selectedTicketID = .init(rawValue: "ROAD-1")
            let hosting = NSHostingView(rootView: Task10BoardTestView(model: model, projectID: fixture.projectID)
                .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
            hosting.appearance = NSAppearance(named: .darkAqua)
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
            window.contentView = hosting
            window.setContentSize(NSSize(width: width, height: 900))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Activation is asynchronous; wait for the actual window readiness condition.
            for _ in 0..<20 where !window.isKeyWindow {
                try await Task.sleep(for: .milliseconds(100))
            }
            hosting.layoutSubtreeIfNeeded()
            print("Task10 window visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow) applicationActive=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue) windows=\(NSApp.windows.count) nativeChildren=\(hosting.accessibilityChildren()?.count ?? 0)")
            try taskCapture(hosting, name: "task10-planning-\(Int(width))")
            if let seconds = ProcessInfo.processInfo.environment["RR_TASK10_INSPECT_SECONDS"].flatMap(Double.init), seconds > 0 {
                print("Task10 isolated inspection PID \(ProcessInfo.processInfo.processIdentifier), width \(width)")
                try await Task.sleep(for: .seconds(min(seconds, 60)))
            }
            // Cross-process AX/keyboard checks are performed with Computer Use.
            // In-process AXWindows returns [] in this isolated host; do not claim otherwise.
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(hosting.frame.width, width, accuracy: 1)
            let board = try XCTUnwrap(model.viewedBoard(for: fixture.projectID))
            XCTAssertEqual(board.lanes.map(\.lane), [.backlog, .inProgress, .needsReview, .blocked, .accepted])
            XCTAssertEqual(model.dashboard?.board(for: fixture.projectID, phaseID: fixture.roadmapPhaseID)?
                .lane(.backlog)?.cards.first { $0.id.rawValue == "ROAD-1" }?.activeTaskCount, 1)
            try taskCapture(hosting, name: "task10-planning-\(Int(width))")
        }
    }

    @MainActor
    func testTask10NativeNeedsReviewAcceptance() async throws {
        let fixture = try await makeTask10AwaitingGoalFixture()
        let model = AppModel(store: fixture.store, projectOnboarding: fixture.onboarding, externalServicesSuppressed: true)
        await model.loadDashboard()
        model.selection = .needsReview
        let inbox = try XCTUnwrap(model.reviewInbox(for: fixture.projectID))
        let hosting = NSHostingView(rootView: Task10ReviewTestView(model: model, projectID: fixture.projectID)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
        let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 1100, height: 850),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.title = "RR-R10 Task 10 — isolated Needs Review"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { window.close(); NSApp.setActivationPolicy(previousPolicy) }
        try await Task.sleep(for: .milliseconds(250))
        try taskCapture(hosting, name: "task10-needs-review")
        XCTAssertEqual(inbox.deliveryGoalAcceptances.count, 1)
        if let seconds = ProcessInfo.processInfo.environment["RR_TASK10_INSPECT_SECONDS"].flatMap(Double.init), seconds > 0 {
            print("Task10 Needs Review inspection PID \(ProcessInfo.processInfo.processIdentifier)")
            try await Task.sleep(for: .seconds(min(seconds, 60)))
        }
    }

    @MainActor
    func testTaskPlanNativeBoardRendering() async throws {
        let nativeSession: (id: String, ready: URL, complete: URL)?
        if let sessionID = ProcessInfo.processInfo.environment["RELEASE_RADAR_PHASE6D_NATIVE_SESSION"] {
            guard !sessionID.isEmpty,
                  sessionID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
                  let markerRootPath = ProcessInfo.processInfo.environment["RELEASE_RADAR_PHASE6D_NATIVE_MARKER_ROOT"],
                  markerRootPath.hasPrefix("/private/tmp/") else {
                XCTFail("The Phase 6D native session requires a safe session ID and marker root.")
                return
            }
            let markerRoot = URL(fileURLWithPath: markerRootPath, isDirectory: true).standardizedFileURL
            let enable = markerRoot.appendingPathComponent("phase6d-native-\(sessionID)-enabled")
            let ready = markerRoot.appendingPathComponent("phase6d-native-\(sessionID)-compact-ready")
            let complete = markerRoot.appendingPathComponent("phase6d-native-\(sessionID)-compact-complete")
            guard FileManager.default.fileExists(atPath: enable.path) else {
                throw XCTSkip("The external controller must create the fresh Phase 6D enable marker.")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: ready.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: complete.path))
            try FileManager.default.removeItem(at: enable)
            nativeSession = (sessionID, ready, complete)
        } else {
            nativeSession = nil
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-TaskUI-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let ticketID = TicketID(rawValue: "VD2-07c")
        let fault = TaskPlanQueryFault()
        _ = try await store.transact(actor: .init(id: "fixture"), reason: "Create native task UI fixture") { c in
            let plan = try TicketTaskPlanningPolicy.revisePlan(projectID: projectID, ticketID: ticketID, expectedRevision: nil,
                additions: (1...16).map { index in
                    .init(id: .init(rawValue: "task-\(index)"), label: "Task \(index)",
                          title: index == 1 ? "Verify the complete long task title wraps below its own text while preserving its label and checked state at compact widths" : "Verify delivery checkpoint \(index)",
                          sortOrder: index)
                }, definitionRevisions: [], supersededTaskIDs: [], connection: c)
            _ = try TicketTaskPlanningPolicy.completeTask(projectID: projectID, ticketID: ticketID, taskID: .init(rawValue: "task-1"), expectedRevision: plan.revision, connection: c)
            return try TicketTaskPlanningPolicy.revisePlan(projectID: projectID, ticketID: .init(rawValue: "VD2-08"), expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "single"), label: "Task 1", title: "Inspect one active task", sortOrder: 0)],
                definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let model = AppModel(store: store, dashboardLoader: { store in
                try await DashboardProjection.load(from: store, taskRows: { c, project, phase, ticket in
                    if fault.isFailing && (ticket == nil || ticket == ticketID) {
                        return try c.rows("SELECT * FROM missing_task_ui_table")
                    }
                    return try TicketTaskPlanProjection.queryRows(c, projectID: project, phaseID: phase, ticketID: ticket)
                })
            }, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        model.selectedTicketID = ticketID
        let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 1600, height: 900),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        let priorActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(priorActivationPolicy) }
        window.isReleasedWhenClosed = false
        window.title = "RR-R10 Task 5 — isolated native acceptance"
        window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }
        for width in [1600.0, 760.0] {
            for enhanced in [false, true] {
                model.selectedTicketID = ticketID
                let content = TaskPlanBoardTestView(model: model, projectID: projectID)
                    .environment(\.colorScheme, .dark)
                    .environment(\.dynamicTypeSize, enhanced ? .accessibility3 : .large)
                let hosting = NSHostingView(rootView: content)
                window.appearance = NSAppearance(named: enhanced ? .accessibilityHighContrastDarkAqua : .darkAqua)
                hosting.appearance = window.appearance
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
                window.contentView = hosting
                window.setContentSize(NSSize(width: width, height: 900))
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                try await Task.sleep(for: .milliseconds(250))
                hosting.layoutSubtreeIfNeeded()
                if let duration = ProcessInfo.processInfo.environment["RR_TASK5_INSPECT_SECONDS"].flatMap(Double.init), duration > 0 {
                    print("TASK5 INSPECTION PID \(ProcessInfo.processInfo.processIdentifier) width \(width) enhanced \(enhanced)")
                    try await Task.sleep(for: .seconds(min(duration, 300)))
                }
                let board = try XCTUnwrap(model.dashboard?.board(for: projectID))
                XCTAssertEqual(board.lane(.blocked)?.cards.first?.activeTaskCount, 16)
                if !enhanced {
                    let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
                    let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))
                    let card = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "ticket-VD2-07c"))
                    XCTAssertTrue(accessibilityText(card).contains("16 tasks"))
                    XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-inspector"))
                    XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "task-row-task-1"))
                    if width == 760, let nativeSession {
                        try Data().write(to: nativeSession.ready, options: .atomic)
                        print(
                            "PHASE6D ADOPTION COMPACT READY: pid \(ProcessInfo.processInfo.processIdentifier); "
                                + "product \(Bundle.main.bundleURL.path); window \(window.title); "
                                + "ready \(nativeSession.ready.path); complete \(nativeSession.complete.path). "
                                + "Scroll until Tasks and Help are visibly readable without activating Help, "
                                + "then write the complete marker."
                        )
                        for _ in 0..<900 where !FileManager.default.fileExists(atPath: nativeSession.complete.path) {
                            try await Task.sleep(for: .milliseconds(200))
                        }
                        XCTAssertTrue(FileManager.default.fileExists(atPath: nativeSession.complete.path))
                        hosting.layoutSubtreeIfNeeded()
                    }
                    if width == 760, case .none = nativeSession {
                        try taskCapture(hosting, name: "phase6d-integrated-tasks-\(Int(width))")
                        try taskCapture(hosting, name: "task5-loaded-\(Int(width))-standard")
                        continue
                    }
                    let helpCandidate = await scrollToAccessibilityElement(
                        nativeWindow,
                        identifier: "task-adoption-help-button"
                    )
                    let help = try XCTUnwrap(helpCandidate)
                    func accessibilityFrame(_ element: AXUIElement) throws -> CGRect {
                        var positionValue: CFTypeRef?
                        var sizeValue: CFTypeRef?
                        XCTAssertEqual(AXUIElementCopyAttributeValue(
                            element, kAXPositionAttribute as CFString, &positionValue
                        ), .success)
                        XCTAssertEqual(AXUIElementCopyAttributeValue(
                            element, kAXSizeAttribute as CFString, &sizeValue
                        ), .success)
                        let position = try XCTUnwrap(positionValue)
                        let size = try XCTUnwrap(sizeValue)
                        var point = CGPoint.zero
                        var dimensions = CGSize.zero
                        XCTAssertTrue(AXValueGetValue(position as! AXValue, .cgPoint, &point))
                        XCTAssertTrue(AXValueGetValue(size as! AXValue, .cgSize, &dimensions))
                        return CGRect(origin: point, size: dimensions)
                    }
                    XCTAssertTrue(try accessibilityFrame(help).intersects(accessibilityFrame(nativeWindow)))
                    XCTAssertEqual(AXUIElementPerformAction(help, kAXPressAction as CFString), .success)
                    var helpText = ""
                    for _ in 0..<20 {
                        helpText = accessibilityText(application)
                        if helpText.contains(TaskAdoptionHelpContent.title) { break }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    XCTAssertTrue(helpText.contains(TaskAdoptionHelpContent.title))
                    try taskCapture(hosting, name: "phase6d-integrated-tasks-\(Int(width))")
                    let done = try XCTUnwrap(
                        accessibilityElement(application, identifier: "task-adoption-help-done")
                    )
                    XCTAssertEqual(AXUIElementPerformAction(done, kAXPressAction as CFString), .success)
                    for _ in 0..<20 {
                        helpText = accessibilityText(application)
                        if !helpText.contains(TaskAdoptionHelpContent.title) { break }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    XCTAssertFalse(helpText.contains(TaskAdoptionHelpContent.title))
                }
                try taskCapture(hosting, name: "task5-loaded-\(Int(width))-\(enhanced ? "accessible" : "standard")")
            }
        }
        for width in [1600.0, 760.0] {
            let hosting = NSHostingView(rootView: TaskPlanBoardTestView(model: model, projectID: projectID)
                .environment(\.colorScheme, .dark))
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
            window.contentView = hosting
            window.setContentSize(NSSize(width: width, height: 900))
            model.selectedTicketID = .init(rawValue: "DESIGN-V2")
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(model.dashboard?.board(for: projectID)?.detail(for: model.selectedTicketID)?.taskPlan, .noPlan)
            try taskCapture(hosting, name: "task5-no-plan-\(Int(width))")
            model.selectedTicketID = ticketID
            fault.isFailing = true
            await model.reloadAfterActivePhaseSelection(projectID: projectID)
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            guard case .unavailable = model.dashboard?.board(for: projectID)?.detail(for: ticketID)?.taskPlan else {
                return XCTFail("Expected unavailable task projection")
            }
            try taskCapture(hosting, name: "task5-unavailable-\(Int(width))")
            fault.isFailing = false
            if let duration = ProcessInfo.processInfo.environment["RR_TASK5_INSPECT_SECONDS"].flatMap(Double.init), duration > 0 {
                print("TASK5 RECOVERY INSPECTION PID \(ProcessInfo.processInfo.processIdentifier) width \(width); press Reload")
                try await Task.sleep(for: .seconds(min(duration, 300)))
            } else {
                await model.reloadAfterActivePhaseSelection(projectID: projectID)
            }
            XCTAssertEqual(model.dashboard?.board(for: projectID)?.lane(.blocked)?.cards.first?.activeTaskCount, 16)
        }
    }

    @MainActor
    func testCompactTicketInspectorExposesFirstAndLastTaskRowsForKeyboardTraversal() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-Phase4CompactTasks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let ticketID = TicketID(rawValue: "VD2-07c")
        try await store.transact(actor: .init(id: "phase4-fixture"), reason: "Create compact task traversal fixture") { connection in
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: DashboardSampleData.projectID,
                ticketID: ticketID,
                expectedRevision: nil,
                additions: (1...16).map { index in
                    .init(
                        id: .init(rawValue: "task-\(index)"),
                        label: "Task \(index)",
                        title: "Verify compact delivery checkpoint \(index)",
                        sortOrder: index
                    )
                },
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true)
        await model.loadDashboard()
        let detail = try XCTUnwrap(model.dashboard?.board(for: DashboardSampleData.projectID)?.detail(for: ticketID))
        guard case let .loaded(plan) = detail.taskPlan else { return XCTFail("Expected loaded task plan") }
        XCTAssertEqual(plan.tasks.first?.label, "Task 1")
        XCTAssertEqual(plan.tasks.last?.label, "Task 16")

        let hosting = NSHostingView(rootView: TicketDetailView(detail: detail))
        hosting.frame = NSRect(x: 0, y: 0, width: 720, height: 780)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.isReleasedWhenClosed = false
        window.title = "Phase 4 Compact Tasks — isolated native acceptance"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)
        try taskCapture(hosting, name: "phase4-compact-ticket-tasks")

        let marker = URL(fileURLWithPath: "/tmp/release-radar-phase4-compact-task-check", isDirectory: true)
        if FileManager.default.fileExists(atPath: marker.path) {
            try? FileManager.default.removeItem(at: marker)
            print("PHASE4 COMPACT TASKS READY: verify first-to-last keyboard traversal")
            try await Task.sleep(for: .seconds(45))
        }
    }

    @MainActor
    func testProjectDependencyMapRendersWideAndCompactInNativeHost() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-Phase4Dependencies-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            externalServicesSuppressed: true,
            seedSampleData: true
        )
        await model.loadDashboard()
        let graph = try XCTUnwrap(model.dependencyGraph(for: DashboardSampleData.projectID))
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_420, height: 860),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Phase 4 Project Dependencies — isolated native acceptance"
        window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }

        for width in [1_420.0, 760.0] {
            let hosting = NSHostingView(rootView: DependencyGraphView(
                graph: graph,
                selectedTicketID: Binding(
                    get: { model.selectedTicketID },
                    set: { model.selectTicket($0) }
                ),
                freshness: model.codexSnapshot.freshness
            ).environment(\.colorScheme, .dark))
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: 860)
            hosting.appearance = window.appearance
            window.contentView = hosting
            window.setContentSize(NSSize(width: width, height: 860))
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            hosting.layoutSubtreeIfNeeded()

            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(graph.selected.ticket.id, TicketID(rawValue: "VD2-08"))
            XCTAssertTrue(graph.nodes.allSatisfy { !$0.phaseName.isEmpty })
            try taskCapture(hosting, name: "phase4-project-dependencies-\(Int(width))")
        }
    }

    @MainActor
    private func taskCapture<V: View>(_ hosting: NSHostingView<V>, name: String) throws {
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

    }

    private func fullWindowCapture(_ window: NSWindow, name: String) throws {
        let image = try XCTUnwrap(CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            .bestResolution
        ))
        let bitmap = NSBitmapImageRep(cgImage: image)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func accessibilityWindow(_ application: AXUIElement, title: String) -> AXUIElement? {
        func matches(_ element: AXUIElement) -> Bool {
            var candidateTitle: CFTypeRef?
            return AXUIElementCopyAttributeValue(
                element, kAXTitleAttribute as CFString, &candidateTitle
            ) == .success && (candidateTitle as? String) == title
        }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
           let window = (value as? [AXUIElement])?.first(where: matches) {
            return window
        }
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var candidate: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                application, attribute as CFString, &candidate
            ) == .success,
                  let candidate,
                  CFGetTypeID(candidate) == AXUIElementGetTypeID() else { continue }
            let element = candidate as! AXUIElement
            if matches(element) { return element }
        }
        return nil
    }

    private func accessibilityFrame(_ element: AXUIElement) throws -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as CFString, &positionValue
        ), .success)
        XCTAssertEqual(AXUIElementCopyAttributeValue(
            element, kAXSizeAttribute as CFString, &sizeValue
        ), .success)
        let position = try XCTUnwrap(positionValue)
        let size = try XCTUnwrap(sizeValue)
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        XCTAssertTrue(AXValueGetValue(position as! AXValue, .cgPoint, &point))
        XCTAssertTrue(AXValueGetValue(size as! AXValue, .cgSize, &dimensions))
        return CGRect(origin: point, size: dimensions)
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var inspected = 0
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element, kAXIdentifierAttribute as CFString, &value
            ) == .success,
               (value as? String) == identifier {
                return element
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element, kAXChildrenAttribute as CFString, &children
            ) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }

    private struct AccessibilityRouteState: CustomStringConvertible {
        let role: String?
        let selected: Bool?
        let value: String?
        let focused: Bool?

        var isSelected: Bool {
            if let selected { return selected }
            return role == kAXButtonRole && value?.caseInsensitiveCompare("selected") == .orderedSame
        }

        var description: String {
            "role=\(role ?? "nil"), selected=\(selected.map(String.init) ?? "nil"), "
                + "value=\(value ?? "nil"), focused=\(focused.map(String.init) ?? "nil")"
        }
    }

    private func accessibilityRouteState(_ root: AXUIElement, identifier: String) -> AccessibilityRouteState? {
        guard let element = accessibilityElement(root, identifier: identifier) else { return nil }
        func attribute(_ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value
        }
        let rawValue = attribute(kAXValueAttribute)
        return .init(
            role: attribute(kAXRoleAttribute) as? String,
            selected: (attribute(kAXSelectedAttribute) as? NSNumber)?.boolValue,
            value: (rawValue as? String) ?? (rawValue as? NSNumber)?.stringValue,
            focused: (attribute(kAXFocusedAttribute) as? NSNumber)?.boolValue
        )
    }

    private func accessibilityFocusedIdentifier(_ application: AXUIElement) -> String? {
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        let focusedElement = focusedValue as! AXUIElement
        var identifierValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXIdentifierAttribute as CFString,
            &identifierValue
        ) == .success else { return nil }
        return identifierValue as? String
    }

    private func accessibilityVerticalScrollValue(_ root: AXUIElement) -> Double? {
        for scrollBar in accessibilityElements(root, role: kAXScrollBarRole) {
            var orientationValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                scrollBar,
                kAXOrientationAttribute as CFString,
                &orientationValue
            ) == .success,
                  (orientationValue as? String) == kAXVerticalOrientationValue else { continue }
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                scrollBar,
                kAXValueAttribute as CFString,
                &value
            ) == .success else { continue }
            if let number = value as? NSNumber { return number.doubleValue }
        }
        return nil
    }

    @MainActor
    private func scrollToAccessibilityElement(
        _ root: AXUIElement,
        identifier: String
    ) async -> AXUIElement? {
        if let element = accessibilityElement(root, identifier: identifier) {
            _ = AXUIElementPerformAction(element, "AXScrollToVisible" as CFString)
            try? await Task.sleep(for: .milliseconds(150))
            return accessibilityElement(root, identifier: identifier) ?? element
        }
        let verticalScrollBars = accessibilityElements(root, role: kAXScrollBarRole).filter { element in
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(
                element, kAXOrientationAttribute as CFString, &value
            ) == .success && (value as? String) == kAXVerticalOrientationValue
        }
        for position in stride(from: 0.0, through: 1.0, by: 0.1) {
            for scrollBar in verticalScrollBars {
                _ = AXUIElementSetAttributeValue(
                    scrollBar, kAXValueAttribute as CFString, NSNumber(value: position)
                )
            }
            try? await Task.sleep(for: .milliseconds(100))
            if let element = accessibilityElement(root, identifier: identifier) {
                _ = AXUIElementPerformAction(element, "AXScrollToVisible" as CFString)
                try? await Task.sleep(for: .milliseconds(150))
                return accessibilityElement(root, identifier: identifier) ?? element
            }
        }
        return nil
    }

    private func accessibilityElements(_ root: AXUIElement, role: String) -> [AXUIElement] {
        var pending = [root]
        var matches: [AXUIElement] = []
        var inspected = 0
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element, kAXRoleAttribute as CFString, &value
            ) == .success,
               (value as? String) == role {
                matches.append(element)
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element, kAXChildrenAttribute as CFString, &children
            ) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return matches
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var text: [String] = []
        var inspected = 0
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(
                    element, attribute as CFString, &value
                ) == .success,
                   let value = value as? String {
                    text.append(value)
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element, kAXChildrenAttribute as CFString, &children
            ) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return text.joined(separator: "\n")
    }

    @MainActor
    func testTaskPlanReloadPreservesPhaseSelectionFailure() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-TaskReloadFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let projectID = DashboardSampleData.projectID
        await model.setActivePhase(projectID: projectID, phaseID: .init(rawValue: "unavailable-phase"))
        let failure = model.activePhaseSelectionStatus(for: projectID)
        guard case .mutationFailed = failure else { return XCTFail("Expected phase selection failure") }
        try await store.transact(actor: .init(id: "fixture"), reason: "Change canonical outcome before recovery") { c in
            try c.execute("UPDATE tickets SET outcome = 'Recovered canonical ticket.' WHERE id = 'VD2-07c'")
        }
        await model.reloadAfterActivePhaseSelection(projectID: projectID)
        XCTAssertEqual(model.dashboard?.board(for: projectID)?.detail(for: .init(rawValue: "VD2-07c"))?.outcome,
                       "Recovered canonical ticket.")
        XCTAssertEqual(model.activePhaseSelectionStatus(for: projectID), failure)
    }

    @MainActor
    func testTaskPlanReloadWorksWhenPhaseSelectionIsIdle() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-TaskReload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let ticketID = TicketID(rawValue: "VD2-07c")
        try await store.transact(actor: .init(id: "fixture"), reason: "Change canonical outcome before reload") { c in
            try c.execute("UPDATE tickets SET outcome = 'Reloaded canonical ticket.' WHERE id = ?", bindings: [.text(ticketID.rawValue)])
        }
        await model.reloadAfterActivePhaseSelection(projectID: DashboardSampleData.projectID)
        XCTAssertEqual(model.dashboard?.board(for: DashboardSampleData.projectID)?.detail(for: ticketID)?.outcome,
                       "Reloaded canonical ticket.")
        XCTAssertEqual(model.activePhaseSelectionStatus(for: DashboardSampleData.projectID), .idle)
    }

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

    func testAddProjectLaterWorkflowActionsUseRekonStyles() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("ReleaseRadar/Projects/OnboardingView.swift"),
            encoding: .utf8
        )

        for action in [
            "Button(\"Back\", action: backToLanding)\n                .buttonStyle(RekonSecondaryButtonStyle())",
            "Button(\"Choose Project Folder…\", action: chooseFolder)\n                .buttonStyle(RekonPrimaryButtonStyle())",
            "Button(\"Open existing project\") {\n                openExisting(completedProjectID)\n            }\n            .buttonStyle(RekonPrimaryButtonStyle())",
            "Button(\"Authorize Worktree…\", action: authorizeWorktree)\n                        .buttonStyle(RekonSecondaryButtonStyle())",
            "Button(OnboardingWorkflowPresentation.initializeTitle, action: initializeProject)\n                        .buttonStyle(RekonPrimaryButtonStyle())",
            "Button(\"Finish Initialization\", action: finish)\n                    .buttonStyle(RekonPrimaryButtonStyle())",
            "Button(\"Choose Folder…\", action: chooseAttachmentFolder)\n                .buttonStyle(RekonPrimaryButtonStyle())",
            "Button(\"Attach Folder\", action: confirmFolderAttachment)\n                            .buttonStyle(RekonPrimaryButtonStyle())",
        ] {
            XCTAssertTrue(source.contains(action), "Missing RDS style for \(action)")
        }
        XCTAssertTrue(source.contains(".buttonStyle(RekonBorderlessIconButtonStyle())"))
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
            .outdated(installed: 0, current: 3)
        )
        XCTAssertEqual(model.projectRoot(for: attachmentRouteProjectID), folder)
        XCTAssertEqual(try String(contentsOf: agentsURL, encoding: .utf8), outdated)

        let current = "# Owner instructions\n\n\(ProjectGuidanceInspection.managedBlock)\n"
        try Data(current.utf8).write(to: agentsURL)
        await model.loadDashboard()

        XCTAssertEqual(
            model.projectGuidanceState(for: attachmentRouteProjectID),
            .handoffIncomplete(version: 3)
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

        XCTAssertEqual(model.projectGuidanceState(for: attachmentRouteProjectID), .current(version: 3))
        XCTAssertEqual(try String(contentsOf: agentsURL, encoding: .utf8), current)
        XCTAssertEqual(bookmarks.accessStarts, bookmarks.accessStops)
    }

    @MainActor
    func testRecoverySupersedesPendingDocumentationFolderRenewalBeforeReplacingServices() async throws {
        let fixture = try await makeRR9OwnerFixture(blockAuthorization: true)
        let registration = ProjectRegistration(
            projectID: fixture.projectID,
            registrationID: "documentation-recovery-registration",
            requestGeneration: 7
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed folder recovery identity") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, ?, ?, 'complete')",
                bindings: [
                    .text(registration.projectID.rawValue),
                    .text(registration.registrationID),
                    .integer(registration.requestGeneration),
                ]
            )
            try connection.execute(
                "UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = ? AND path = ?",
                bindings: [.text(fixture.projectID.rawValue), .text(fixture.projectRoot.path)]
            )
        }
        let replacementURL = fixture.databaseURL.deletingLastPathComponent()
            .appendingPathComponent("replacement.sqlite")
        try await fixture.store.createSnapshot(at: replacementURL)
        let replacementStore = DeliveryStore(databaseURL: replacementURL)
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await fixture.bookmarks.armAccessGate()
        let identity = DocumentationObservationIdentity(
            projectID: fixture.projectID,
            registration: registration,
            rootID: .init(rawValue: "rr9-owner-root"),
            rootPath: fixture.projectRoot.path,
            binding: nil
        )

        let renewal = Task { () -> Result<ProjectHealthSnapshot, Error> in
            do {
                return .success(try await model.restoreDocumentationFolderAccess(
                    at: fixture.projectRoot,
                    identity: identity
                ))
            } catch {
                return .failure(error)
            }
        }
        await fixture.bookmarks.waitUntilAccessEntered()
        let adoption = Task {
            try await model.adoptRecovery(.init(
                store: replacementStore,
                operationID: UUID(),
                requiresFreshServiceGraph: true,
                newerHistoryWasReconciled: false
            ))
        }
        while model.documentationServiceGeneration == 0 {
            await Task.yield()
        }
        try await adoption.value
        await fixture.bookmarks.releaseAccess()

        switch await renewal.value {
        case .success:
            XCTFail("The retired folder renewal must not report success")
        case let .failure(error):
            XCTAssertEqual(error as? ProjectRootManagementError, .stale)
        }
        let retiredState = try await documentationRecoveryMutationState(
            store: DeliveryStore(databaseURL: fixture.databaseURL)
        )
        let activeState = try await documentationRecoveryMutationState(store: replacementStore)
        XCTAssertEqual(retiredState, .init(isStale: 1, restorationAudits: 0))
        XCTAssertEqual(activeState, .init(isStale: 1, restorationAudits: 0))
        XCTAssertNil(model.applicationRecoveryMessage)
    }

    @MainActor
    func testActivationRefreshSupersedesInvalidatedProjectionPreparation() async throws {
        let fixture = try await makeRR9OwnerFixture()
        let loader = RouteDocumentationObservationLoader(projectID: fixture.projectID)
        let observer = DocumentationObservationCoordinator { projectID in
            await loader.load(projectID: projectID)
        }
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true,
            documentationObserver: observer
        )
        await model.loadDashboard()
        let olderReload = Task { await model.loadDashboard() }
        await loader.waitUntilOlderObservationEntered()

        await model.recheckDocumentationAfterActivation()
        let currentState = model.projectDocumentationState(for: fixture.projectID)
        let currentEvidence = model.dashboard?.projects.first?.evidence
        guard case .managed = currentState else {
            return XCTFail("Activation must publish the newer documentation observation")
        }
        XCTAssertEqual(currentEvidence?.map(\.id.rawValue), ["new-documentation-evidence"])

        await loader.releaseOlderObservation()
        await olderReload.value

        XCTAssertEqual(model.projectDocumentationState(for: fixture.projectID), currentState)
        XCTAssertEqual(model.dashboard?.projects.first?.evidence, currentEvidence)
        XCTAssertNil(model.dashboardError)
        guard case let .observed(observation) = model.documentationObservationStatus(for: fixture.projectID) else {
            return XCTFail("The newer documentation observation must remain current")
        }
        XCTAssertEqual(observation.checkedAt, Date(timeIntervalSince1970: 2))
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
            "Goals",
            "Needs Review",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "folder",
            "target",
            "checkmark.bubble",
        ])
    }

    func testSaveQueryAttemptStateKeepsTheEnteredNameAndExposesFailure() {
        var state = WorkspaceToolbarSaveState(name: "Existing query")

        let shouldDismiss = state.resolve(.failed("Delivery store is closed"))

        XCTAssertFalse(shouldDismiss)
        XCTAssertEqual(state.name, "Existing query")
        XCTAssertEqual(state.failure, "Delivery store is closed")
    }

    @MainActor
    func testSaveQueryFailurePopoverExposesAccessibleRecovery() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 360, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "RDS save failure popover — isolated native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: WorkspaceSaveQueryPopover(
            name: .constant("Existing query"),
            failure: "Delivery store is closed",
            onCancel: {},
            onSave: {}
        ).environment(\.colorScheme, .dark))
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()

        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))
        let failure = try XCTUnwrap(accessibilityElement(
            nativeWindow,
            identifier: "workspace-search-save-error"
        ))
        XCTAssertTrue(accessibilityText(failure).contains("Delivery store is closed"))
        XCTAssertTrue(accessibilityText(failure).contains("try again"))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-save-name"))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-save-confirm"))
    }

    @MainActor
    func testPersistentToolbarAndResponsiveSidebarExposeOneAccessibleEntryPointPerAction() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ToolbarNative-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .projectOverview(DashboardSampleData.projectID))

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 1_280, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "RDS toolbar adoption — isolated native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        for width in [1_280.0, 760.0] {
            model.isSidebarCompact = false
            window.setContentSize(NSSize(width: width, height: 720))
            hosting.frame = window.contentView?.bounds ?? .zero
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()

            let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
            let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))
            let nativeWindowFrame = try accessibilityFrame(nativeWindow)
            for identifier in [
                "workspace-toolbar",
                "workspace-toolbar-sidebar-toggle",
                "navigation-back",
                "navigation-forward",
                "workspace-search-field",
                "workspace-search-run",
                "workspace-search-save",
                "workspace-toolbar-help",
                "workspace-toolbar-settings",
                "workspace-toolbar-notifications",
            ] {
                let element = try XCTUnwrap(
                    accessibilityElement(nativeWindow, identifier: identifier),
                    "Expected \(identifier) at width \(Int(width))"
                )
                let elementFrame = try accessibilityFrame(element)
                XCTAssertTrue(
                    nativeWindowFrame.contains(elementFrame),
                    "Expected \(identifier) to remain fully visible at width \(Int(width)); window=\(nativeWindowFrame), element=\(elementFrame)"
                )
            }
            for duplicate in ["sidebar-search", "sidebar-help", "sidebar-settings", "sidebar-notifications"] {
                XCTAssertNil(accessibilityElement(nativeWindow, identifier: duplicate))
            }
            XCTAssertFalse(accessibilityText(nativeWindow).contains("Persisted locally"))
            try taskCapture(hosting, name: width == 760 ? "rds-toolbar-compact" : "rds-toolbar-wide")
        }

        window.setContentSize(NSSize(width: 1_280, height: 720))
        hosting.frame = window.contentView?.bounds ?? .zero
        try await Task.sleep(for: .milliseconds(250))
        hosting.layoutSubtreeIfNeeded()
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))

        model.setWorkspaceSearchText("VD2-08")
        let sourceHistoryCount = model.navigationHistory.entries.count
        XCTAssertEqual(
            AXUIElementPerformAction(
                try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "workspace-search-run")),
                kAXPressAction as CFString
            ),
            .success
        )
        for _ in 0..<40 where model.selection != .search {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(model.selection, .search)
        XCTAssertEqual(model.workspaceSearchDefinition.text, "VD2-08")
        XCTAssertEqual(model.navigationHistory.entries.count, sourceHistoryCount + 1)

        await model.goBack()
        XCTAssertEqual(model.selection, .projectOverview(DashboardSampleData.projectID))

        let enableURL = URL(fileURLWithPath: "/private/tmp/release-radar-rds-toolbar-native-enable")
        if FileManager.default.fileExists(atPath: enableURL.path) {
            try FileManager.default.removeItem(at: enableURL)
            let readyURL = URL(fileURLWithPath: "/private/tmp/release-radar-rds-toolbar-native-ready")
            let completeURL = URL(fileURLWithPath: "/private/tmp/release-radar-rds-toolbar-native-complete")
            let identity = "pid=\(ProcessInfo.processInfo.processIdentifier)\nwindow=\(window.title)\n"
            try Data(identity.utf8).write(to: readyURL, options: .atomic)
            print("RDS TOOLBAR READY: use native keyboard input to submit with Return; verify Back; save a different visible draft as Native toolbar query without running; dismiss a second Save popover with Escape; inspect wide and compact layouts; finish on the project Overview")
            for _ in 0..<900 where !FileManager.default.fileExists(atPath: completeURL.path) {
                try await Task.sleep(for: .milliseconds(200))
            }
            _ = try String(contentsOf: completeURL, encoding: .utf8)
            XCTAssertEqual(model.selection, .projectOverview(DashboardSampleData.projectID))
            XCTAssertTrue(model.workspaceSearchSavedQueries.contains { $0.name == "Native toolbar query" })
            try FileManager.default.removeItem(at: readyURL)
            try FileManager.default.removeItem(at: completeURL)
        }
    }

    func testProjectRoutesRetainTheirProjectAndExposeExpectedLabels() {
        let projectID = ProjectID(rawValue: "project-42")
        let routes = AppRoute.projectRoutes(for: projectID)

        XCTAssertEqual(routes, [
            .projectOverview(projectID),
            .projectPlan(projectID),
            .phaseBoard(projectID),
            .dependencies(projectID),
            .activity(projectID),
        ])
        XCTAssertEqual(routes.map(\.title), [
            "Overview",
            "Project Plan",
            "Phase Board",
            "Dependencies",
            "History",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "rectangle.grid.1x2",
            "list.bullet.rectangle.portrait",
            "rectangle.split.3x1",
            "arrow.triangle.branch",
            "clock",
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
            .projectPlan(second.id),
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
            try Self.seedActionableGoal(projectID: "project-direct", phaseID: "phase-direct", ticketID: "DIRECT-1", connection: connection)
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
        XCTAssertTrue(CodexPluginSettingsPresentation(state: .installed(version: "0.1.0")).canRestartHelper)
        XCTAssertFalse(
            CodexPluginSettingsPresentation(
                state: .installed(version: "0.1.0"),
                operation: .restartHelper
            ).canRestartHelper
        )
        XCTAssertEqual(CodexPluginOperation.restartHelper.announcement, "Restarting lifecycle helper")
    }

    @MainActor
    func testRestartPluginHelperPublishesProgressSuccessAndSerializesLifecycleActions() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RestartHelper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        try await lifecycleStore.recordVerified(
            .init(
                intent: .managedInstalled,
                managedVersion: "0.1.9",
                managedDigest: "current",
                verifiedAt: Date(timeIntervalSince1970: 1)
            ),
            reason: "Restart helper fixture"
        )
        let manager = AppLifecycleManager(replies: [
            .init(
                wireVersion: 1,
                observedState: .clean(version: "0.1.9", digest: "current"),
                error: nil
            ),
        ])
        let model = AppModel(
            store: store,
            codexPluginCoordinator: .init(
                manager: manager,
                store: lifecycleStore,
                shippedVersion: "0.1.9",
                shippedDigest: "current"
            ),
            codexPluginShippedVersion: "0.1.9",
            externalServicesSuppressed: true
        )

        await model.restartCodexPluginHelper()
        let operationsAfterRestart = await manager.operations()

        XCTAssertEqual(operationsAfterRestart, [.restartHelper])
        XCTAssertEqual(model.codexPluginState, .installed(version: "0.1.9"))
        XCTAssertEqual(model.codexPluginSettingsMessage, "Lifecycle helper restarted. Plugin status refreshed.")
        XCTAssertEqual(model.codexPluginAnnouncement, "Lifecycle helper restarted. Plugin status refreshed.")
        XCTAssertNil(model.codexPluginOperation)

        model.codexPluginOperation = .install
        await model.restartCodexPluginHelper()
        let operationsWhileBusy = await manager.operations()
        XCTAssertEqual(operationsWhileBusy, [.restartHelper])
        XCTAssertEqual(model.codexPluginOperation, .install)
    }

    @MainActor
    func testRestartPluginHelperPresentsActionablePermissionFailure() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RestartHelperFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let manager = AppLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: nil, error: .unauthorizedPeer),
        ])
        let model = AppModel(
            store: store,
            codexPluginCoordinator: .init(
                manager: manager,
                store: CodexPluginLifecycleStore(store: store),
                shippedVersion: "0.1.9",
                shippedDigest: "current"
            ),
            externalServicesSuppressed: true
        )

        await model.restartCodexPluginHelper()

        XCTAssertEqual(model.codexPluginState, .failed(.unauthorizedPeer))
        XCTAssertEqual(
            model.codexPluginSettingsMessage,
            "macOS did not authorize the Release Radar lifecycle helper. Review Login Items, then try again."
        )
        XCTAssertEqual(model.codexPluginAnnouncement, "Failed")
        XCTAssertNil(model.codexPluginOperation)
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
    func testPluginStatusRefreshesActiveProjectCompatibilityObservation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginCompatibilityRefresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let loader = PluginCompatibilityObservationLoader(projectID: DashboardSampleData.projectID)
        let observer = DocumentationObservationCoordinator { projectID in
            await loader.load(projectID: projectID)
        }
        let currentDigest = "ecc221b2ca91ac8913e73555b6ed310bce63d7f1ac9462d05b025478173d5a40"
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        try await lifecycleStore.recordVerified(
            .init(
                intent: .managedInstalled,
                managedVersion: "0.1.8",
                managedDigest: currentDigest,
                verifiedAt: Date(timeIntervalSince1970: 1)
            ),
            reason: "Plugin compatibility refresh fixture"
        )
        let manager = AppLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .absent, error: nil),
        ])
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: lifecycleStore,
            shippedVersion: "0.1.8",
            shippedDigest: currentDigest
        )
        let capability = try XCTUnwrap(RecognizedPluginCapability.recognize(
            manifestVersion: "0.1.8",
            normalizedPackageDigest: currentDigest
        ))
        let model = AppModel(
            store: store,
            codexPluginCoordinator: coordinator,
            codexPluginShippedVersion: "0.1.8",
            codexPluginShippedCapability: capability,
            externalServicesSuppressed: true,
            documentationObserver: observer
        )

        await model.loadDashboard()
        let initialObservationCount = await loader.count()
        XCTAssertEqual(initialObservationCount, 1)

        await model.loadCodexPluginStatus()

        let pluginOperations = await manager.operations()
        let refreshedObservationCount = await loader.count()
        XCTAssertEqual(pluginOperations, [.status])
        XCTAssertEqual(refreshedObservationCount, 2)
        guard case let .observed(observation) = model.documentationObservationStatus(
            for: DashboardSampleData.projectID
        ) else {
            return XCTFail("Plugin status must republish the active project's compatibility observation")
        }
        XCTAssertEqual(observation.generation, 2)
    }

    @MainActor
    func testPluginStatusInvalidatesAnOlderInFlightCompatibilityObservation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PluginCompatibilityRace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let gate = SequencedDocumentationObservationGate()
        let observer = DocumentationObservationCoordinator { projectID in
            await gate.load(projectID: projectID)
        }
        let manager = AppLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .absent, error: nil),
        ])
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: manager,
            store: lifecycleStore,
            shippedVersion: "0.1.8",
            shippedDigest: "ecc221b2ca91ac8913e73555b6ed310bce63d7f1ac9462d05b025478173d5a40"
        )
        let model = AppModel(
            store: store,
            codexPluginCoordinator: coordinator,
            codexPluginShippedVersion: "0.1.8",
            externalServicesSuppressed: true,
            documentationObserver: observer
        )

        let initialLoad = Task { await model.loadDashboard() }
        await gate.waitUntilCallCount(1)
        await gate.release(call: 1, with: .fixture(
            projectID: DashboardSampleData.projectID,
            checkedAt: 1,
            compatibilityState: .compatibleV1
        ))
        await initialLoad.value

        let olderRefresh = Task {
            await model.refreshProjectDocumentation(DashboardSampleData.projectID)
        }
        await gate.waitUntilCallCount(2)
        let pluginRefresh = Task { await model.loadCodexPluginStatus() }
        await gate.waitUntilCallCount(3)
        await gate.release(call: 3, with: .fixture(
            projectID: DashboardSampleData.projectID,
            checkedAt: 3,
            compatibilityState: .incompatible
        ))
        await gate.release(call: 2, with: .fixture(
            projectID: DashboardSampleData.projectID,
            checkedAt: 2,
            compatibilityState: .compatibleV1
        ))
        await pluginRefresh.value
        await olderRefresh.value

        guard case let .observed(observation) = model.documentationObservationStatus(
            for: DashboardSampleData.projectID
        ) else {
            return XCTFail("Plugin refresh must publish its fresh compatibility observation")
        }
        XCTAssertEqual(observation.generation, 3)
        XCTAssertEqual(observation.sharedExecutionCompatibility.state, .incompatible)
    }

    @MainActor
    func testRecoveryResumedLaunchUsesReadOnlyPluginStatus() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RecoveryPluginLaunch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let manager = AppLifecycleManager(replies: [
            .init(wireVersion: 1, observedState: .absent, error: nil),
        ])
        let model = AppModel(
            store: store,
            codexPluginCoordinator: .init(
                manager: manager,
                store: CodexPluginLifecycleStore(store: store),
                shippedVersion: "0.1.3",
                shippedDigest: "current"
            ),
            recoveryResumedAtLaunch: true
        )

        await model.initializeCodexPluginLifecycleForLaunch()

        let calls = await manager.operations()
        XCTAssertEqual(calls, [AppLifecycleManager.Operation.statusReadOnly])
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
            ("phase-lifecycle", .phaseLifecycle),
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
    func testRDSPlanningPickersPreserveByteDistinctPhaseAndGoalSelection() async throws {
        let composed = "\u{e9}"
        let decomposed = "e\u{301}"
        let phases = [
            ProjectPhaseProjection(id: .init(rawValue: composed), name: "Same phase"),
            ProjectPhaseProjection(id: .init(rawValue: decomposed), name: "Same phase"),
        ]
        let goals = [
            DeliveryGoalSummaryProjection(
                goalID: .init(rawValue: composed), title: "First goal", outcome: "First", lifecycle: .draft,
                doneCriteria: [], ticketIDs: []
            ),
            DeliveryGoalSummaryProjection(
                goalID: .init(rawValue: decomposed), title: "Second goal", outcome: "Second", lifecycle: .draft,
                doneCriteria: [], ticketIDs: []
            ),
        ]
        let project = ProjectDashboardProjection(
            id: .init(rawValue: "byte-project"), name: "Byte project", activePhaseID: phases[0].id,
            activePhaseName: phases[0].name, phases: phases,
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0, attentionCount: 0
        )
        let board = PhaseBoardProjection(
            project: project, phaseID: phases[0].id, phaseName: phases[0].name,
            phasePlan: .init(state: .draft, revision: 0, readyRevision: nil, upcomingCount: 0,
                             coveredUpcomingCount: 0, unassignedUpcomingCount: 0),
            phaseLifecycle: nil, completionAssessment: nil,
            deliveryGoals: goals, lanes: [], details: [:]
        )
        var viewedPhaseID: PhaseID?
        var filter: DeliveryGoalFilter = .all
        let view = PhaseBoardPlanningControls(
            board: board,
            filter: Binding(get: { filter }, set: { filter = $0 }),
            phaseSelectionStatus: .idle,
            viewPhase: { viewedPhaseID = $0 },
            makeActive: { _ in }, reload: {}, reauthorize: { _ in }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 1_400, height: 360)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        hosting.layoutSubtreeIfNeeded()

        let phasePicker = try XCTUnwrap(nativePopup(in: hosting, identifier: "viewed-phase-selector"))
        phasePicker.selectItem(at: 1)
        phasePicker.sendAction(phasePicker.action, to: phasePicker.target)
        XCTAssertEqual(Data(try XCTUnwrap(viewedPhaseID).rawValue.utf8), Data(decomposed.utf8))

        let goalPicker = try XCTUnwrap(nativePopup(in: hosting, identifier: "delivery-goal-filter"))
        goalPicker.selectItem(at: 2)
        goalPicker.sendAction(goalPicker.action, to: goalPicker.target)
        guard case let .goal(selectedGoalID) = filter else { return XCTFail("Expected goal filter") }
        XCTAssertEqual(Data(selectedGoalID.rawValue.utf8), Data(decomposed.utf8))
    }

    @MainActor
    func testRDSActivePhasePickerNativeControlCannotActWhileSavingOrAwaitingReload() async throws {
        let composed = "\u{e9}"
        let decomposed = "e\u{301}"
        let phases = [
            ProjectPhaseProjection(id: .init(rawValue: composed), name: "Same phase"),
            ProjectPhaseProjection(id: .init(rawValue: decomposed), name: "Same phase"),
        ]
        let project = ProjectDashboardProjection(
            id: .init(rawValue: "disabled-project"), name: "Disabled project", activePhaseID: phases[0].id,
            activePhaseName: phases[0].name, phases: phases,
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0, attentionCount: 0
        )

        var idleSelection: PhaseID?
        let idleHosting = NSHostingView(rootView: ActivePhaseSelector(
            project: project, surface: .overview, status: .idle,
            onSelect: { idleSelection = $0 }, onReload: {}, onReauthorize: { _ in }
        ))
        idleHosting.frame = NSRect(x: 0, y: 0, width: 600, height: 220)
        let idleWindow = NSWindow(contentRect: idleHosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        idleWindow.isReleasedWhenClosed = false
        idleWindow.contentView = idleHosting
        idleWindow.orderFront(nil)
        defer { idleWindow.close() }
        try await Task.sleep(for: .milliseconds(100))
        idleHosting.layoutSubtreeIfNeeded()
        let idlePicker = try XCTUnwrap(nativePopup(in: idleHosting, identifier: "active-phase-selector-overview"))
        idlePicker.selectItem(at: 1)
        idlePicker.sendAction(idlePicker.action, to: idlePicker.target)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(Data(try XCTUnwrap(idleSelection).rawValue.utf8), Data(decomposed.utf8))

        for status in [ActivePhaseSelectionStatus.saving(phases[1].id), .savedNeedsReload(phases[1].id, phases[1].name)] {
            var selectedIDs: [PhaseID] = []
            let view = ActivePhaseSelector(
                project: project, surface: .overview, status: status,
                onSelect: { selectedIDs.append($0) }, onReload: {}, onReauthorize: { _ in }
            )
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 220)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            window.orderFront(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(100))
            hosting.layoutSubtreeIfNeeded()

            let picker = try XCTUnwrap(nativePopup(in: hosting, identifier: "active-phase-selector-overview"))
            XCTAssertFalse(picker.isEnabled, "The represented native picker must be disabled, not just visually styled")
            picker.selectItem(at: 1)
            picker.sendAction(picker.action, to: picker.target)
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertTrue(selectedIDs.isEmpty)
        }
    }

    @MainActor
    private func nativePopup(in view: NSView, identifier: String) -> NSPopUpButton? {
        if let popup = view as? NSPopUpButton, popup.accessibilityIdentifier() == identifier {
            return popup
        }
        for subview in view.subviews {
            if let popup = nativePopup(in: subview, identifier: identifier) {
                return popup
            }
        }
        return nil
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
            Scenario(name: "backlog direct acceptance", lane: .backlog, plan: .none, revision: nil, succeeds: false),
            Scenario(name: "no plan omitted", lane: .needsReview, plan: .none, revision: nil, succeeds: true),
            Scenario(name: "no plan present", lane: .needsReview, plan: .none, revision: 1, succeeds: false),
            Scenario(name: "loaded plan omitted", lane: .needsReview, plan: .pending, revision: nil, succeeds: false),
            Scenario(name: "loaded plan stale", lane: .needsReview, plan: .pending, revision: 2, succeeds: false),
            Scenario(name: "pending exact", lane: .needsReview, plan: .pending, revision: 1, succeeds: false),
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
    func testOwnerActionRejectsTheRegistrationCapturedBeforeRecovery() async throws {
        let fixture = try await makeRR9OwnerFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed recovery authority") { connection in
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('rr9-owner-project', 'registration-before-recovery', 1, 'complete')")
        }
        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Simulate recovery authority rotation") { connection in
            try connection.execute("UPDATE project_registrations SET registration_id = 'registration-after-recovery', request_generation = 2 WHERE project_id = 'rr9-owner-project'")
            try connection.execute("UPDATE application_recovery_state SET requires_scoped_commands = 1 WHERE singleton_id = 1")
        }

        let result = try await model.transitionTicket(
            projectID: fixture.projectID,
            ticketID: .init(rawValue: "ROAD-1"),
            to: .inProgress
        )

        XCTAssertEqual(result.error, .staleProjectRegistration)
        let persisted = try await fixture.store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'ROAD-1' AND lane = 'backlog'") ?? -1,
            ]
        }
        XCTAssertEqual(persisted, [0, 1])
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
    func testExternalCommittedRefreshRechecksGuidanceWithoutBookmarkOrAuditMutation() async throws {
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
            XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), .unavailable, "Failure: \(failure)")
            XCTAssertEqual(model.projectRoot(for: fixture.projectID), rootBefore, "Failure: \(failure)")
            XCTAssertEqual(requestIDs.count, 0, "Failure: \(failure)")
        }
    }

    @MainActor
    func testOwnerSavedRefreshRechecksGuidanceWithoutBookmarkAuditOrCommandRetry() async throws {
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
            XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), .unavailable, "Failure: \(failure)")
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
        let planning = try await store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phase_plans p WHERE EXISTS (SELECT 1 FROM tickets t WHERE t.project_id = p.project_id AND t.phase_id = p.phase_id) AND (p.state <> 'ready' OR p.ready_revision <> p.revision)"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets t LEFT JOIN delivery_goal_ticket_assignments a ON a.project_id = t.project_id AND a.phase_id = t.phase_id AND a.ticket_id = t.id WHERE a.ticket_id IS NULL"),
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE plan_legacy_continuation <> 0")
            )
        }
        XCTAssertEqual(planning.0, 0)
        XCTAssertEqual(planning.1, 0)
        XCTAssertEqual(planning.2, 0)
        XCTAssertEqual(firstSeedState.seedAuditRows, [
            "rr9-capture-seed-audit|release-radar.rr9-capture-seed||none|Seed RR-R9 active phase capture fixture|rr9-capture-primary|phase|phase-current",
        ])
        XCTAssertEqual(secondSeedState, firstSeedState)
        XCTAssertFalse(model.dashboard?.projects.contains { $0.id == DashboardSampleData.projectID } == true)
    }

    @MainActor
    func testPhaseLifecycleCaptureShowsConcurrentDeliveryCompletedHistoryAndOwnerTransition() async throws {
        let fixture = try await makeRR9CaptureModel(scenario: .phaseLifecycle)
        let model = fixture.model
        XCTAssertEqual(model.selection, .projectPlan(RR9ActivePhaseCaptureFixture.primaryProjectID))
        XCTAssertEqual(
            model.currentProject?.activePhaseID,
            RR9ActivePhaseCaptureFixture.currentPhaseID
        )
        let phases = try XCTUnwrap(
            model.dashboard?.plan(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?.phases
        )
        XCTAssertEqual(phases.filter { $0.lifecycle.lifecycle == .inDelivery }.count, 2)
        XCTAssertEqual(
            phases.first(where: { $0.id.rawValue == "phase-history" })?.lifecycle.lifecycle,
            .completed
        )
        let empty = try XCTUnwrap(phases.first(where: { $0.id == RR9ActivePhaseCaptureFixture.emptyPhaseID }))
        let result = await model.transitionPhaseLifecycle(
            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
            phaseID: empty.id,
            expectedRevision: empty.lifecycle.revision,
            action: .moveToUpcoming,
            planningBaselineDigest: nil,
            reason: "Owner schedules the empty synthetic phase"
        )
        XCTAssertNil(result.error)
        await model.reloadPhaseLifecycle()
        XCTAssertEqual(
            model.dashboard?.plan(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?
                .phases.first(where: { $0.id == empty.id })?.lifecycle.lifecycle,
            .upcoming
        )
        XCTAssertEqual(model.selectedTicketID, RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID)
        XCTAssertNil(model.navigationRecoveryMessage)
        XCTAssertEqual(model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.currentPhaseID)
    }

    @MainActor
    func testLivePhaseLifecycleJourneyUsesNativeControlsReloadsAndPreservesActivePhase() async throws {
        let enableMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5e-writer/phase5e-live-01a08a7d-v2-enabled")
        guard FileManager.default.fileExists(atPath: enableMarker.path) else {
            throw XCTSkip("The external controller must create the fresh Phase 5E enable marker.")
        }
        let wideMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5e-writer/phase5e-live-01a08a7d-v2-wide-complete")
        let compactMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5e-writer/phase5e-live-01a08a7d-v2-compact-complete")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wideMarker.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: compactMarker.path))

        let fixture = try await makeRR9CaptureModel(scenario: .phaseLifecycle)
        let model = fixture.model
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 940),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5E lifecycle — isolated native interaction 01a08a7d-v2"
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.frame = .init(x: 0, y: 0, width: 1_500, height: 940)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)
        print("PHASE5E WIDE READY: verify exact state and blockers; move Empty to Upcoming; reopen History in delivery; complete History again; verify reason focus and reload")

        for _ in 0..<900 where !FileManager.default.fileExists(atPath: wideMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: wideMarker.path))
        let widePhases = try XCTUnwrap(
            model.dashboard?.plan(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?.phases
        )
        XCTAssertEqual(
            widePhases.first(where: { $0.id == RR9ActivePhaseCaptureFixture.emptyPhaseID })?.lifecycle.lifecycle,
            .upcoming
        )
        let persistedHistory = try await fixture.store.read {
            try PhaseLifecyclePolicy.current(
                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
                phaseID: .init(rawValue: "phase-history"), connection: $0
            )
        }
        XCTAssertEqual(
            widePhases.first(where: { $0.id.rawValue == "phase-history" })?.lifecycle,
            persistedHistory
        )
        XCTAssertEqual(
            widePhases.first(where: { $0.id.rawValue == "phase-history" })?.lifecycle.lifecycle,
            .completed
        )
        XCTAssertEqual(
            widePhases.first(where: { $0.id.rawValue == "phase-history" })?.lifecycle.revision,
            3
        )
        XCTAssertEqual(model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.currentPhaseID)

        window.setContentSize(NSSize(width: 760, height: 940))
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        print("PHASE5E COMPACT READY: verify the Completed guard and responsive layout; begin delivery for Empty; verify reason focus and persisted reload")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactMarker.path))
        let compactPhases = try XCTUnwrap(
            model.dashboard?.plan(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?.phases
        )
        XCTAssertEqual(
            compactPhases.first(where: { $0.id == RR9ActivePhaseCaptureFixture.emptyPhaseID })?.lifecycle.lifecycle,
            .inDelivery
        )
        XCTAssertEqual(compactPhases.filter { $0.lifecycle.lifecycle == .inDelivery }.count, 3)
        XCTAssertEqual(model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.currentPhaseID)
        try taskCapture(hosting, name: "phase5e-lifecycle-live-journey-final")
    }

    @MainActor
    func testLiveWorkspaceGoalsJourneyUsesNativeWideAndCompactControlsAndRestoresExactContext() async throws {
        guard let sessionID = ProcessInfo.processInfo.environment["RELEASE_RADAR_PHASE6B_NATIVE_SESSION"] else {
            throw XCTSkip("The external controller must supply a unique Phase 6B native session.")
        }
        guard !sessionID.isEmpty,
              sessionID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            XCTFail("The Phase 6B native session must contain only letters, numbers, hyphens and underscores.")
            return
        }
        let markerRoot = URL(fileURLWithPath: "/private/tmp/release-radar-phase6b.PTQwNy", isDirectory: true)
        let enableMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-enabled")
        guard FileManager.default.fileExists(atPath: enableMarker.path) else {
            throw XCTSkip("The external controller must create the fresh Phase 6B enable marker.")
        }
        try FileManager.default.removeItem(at: enableMarker)
        let emptyMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-empty-complete")
        let wideMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-wide-complete")
        let compactSelectionMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-compact-selection-complete")
        let compactOpenAllowedMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-compact-open-allowed")
        let compactBoardMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-compact-board-ready")
        let compactClearAllowedMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-compact-clear-allowed")
        let compactMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-compact-complete")
        let recoveryMarker = markerRoot.appendingPathComponent("phase6b-native-\(sessionID)-recovery-complete")
        for marker in [
            emptyMarker, wideMarker, compactSelectionMarker, compactOpenAllowedMarker,
            compactBoardMarker, compactClearAllowedMarker, compactMarker, recoveryMarker,
        ] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        }

        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-Phase6BGoals-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixtureDirectory) }
        let store = DeliveryStore(databaseURL: fixtureDirectory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let nonactivePhaseID = PhaseID(rawValue: "phase6b-goals-nonactive")
        let deliveryGoalID = DeliveryGoalID(rawValue: "phase6b-goals-delivery")
        try await store.transact(actor: .init(id: "phase6b-native-fixture"), reason: "Create isolated Goals native fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'phase6b-goals-registration', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: projectID,
                phaseID: nonactivePhaseID,
                name: "Goals nonactive phase",
                mode: .governed,
                connection: connection
            )
            for index in 0..<14 {
                let suffix = String(format: "%02d", index)
                let ticketID = "GOALS-LINK-\(suffix)"
                let threadID = "phase6b-linked-thread-\(suffix)"
                let goalID = "phase6b-linked-goal-\(suffix)"
                try connection.execute(
                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, 'backlog')",
                    bindings: [.text(ticketID), .text(projectID.rawValue), .text(nonactivePhaseID.rawValue), .text("Linked nonactive work \(suffix)")]
                )
                try connection.execute(
                    "INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES (?, ?, 'completed', '2026-09-10T12:00:00Z')",
                    bindings: [.text(threadID), .text(projectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES (?, ?, ?, 'Completed', ?, '2026-09-10T12:00:00Z')",
                    bindings: [.text(goalID), .text(projectID.rawValue), .text(threadID), .text("Linked execution goal \(suffix)")]
                )
                try connection.execute(
                    "INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES (?, ?, ?, ?)",
                    bindings: [.text("phase6b-thread-link-\(suffix)"), .text(projectID.rawValue), .text(ticketID), .text(threadID)]
                )
                try connection.execute(
                    "INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES (?, ?, ?, ?, ?)",
                    bindings: [.text("phase6b-goal-link-\(suffix)"), .text(projectID.rawValue), .text(ticketID), .text(threadID), .text(goalID)]
                )
            }
            try connection.execute(
                "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at, activated_at) VALUES (?, ?, ?, 'Nonactive delivery outcome', 'Deliver work from a stored nonactive phase.', 'active', 0, '2026-09-10T00:00:00Z', '2026-09-10T00:00:00Z', '2026-09-10T00:00:00Z')",
                bindings: [.text(projectID.rawValue), .text(nonactivePhaseID.rawValue), .text(deliveryGoalID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES (?, ?, ?, 0, 'Nonactive linked work is inspectable')",
                bindings: [.text(projectID.rawValue), .text(nonactivePhaseID.rawValue), .text(deliveryGoalID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES (?, ?, ?, 'GOALS-LINK-00')",
                bindings: [.text(projectID.rawValue), .text(nonactivePhaseID.rawValue), .text(deliveryGoalID.rawValue)]
            )
            for index in 0..<14 {
                let suffix = String(format: "%02d", index)
                let threadID = "phase6b-unlinked-thread-\(suffix)"
                try connection.execute(
                    "INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES (?, ?, 'completed', '2026-09-10T11:00:00Z')",
                    bindings: [.text(threadID), .text(projectID.rawValue)]
                )
                try connection.execute(
                    "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES (?, ?, ?, 'Completed', ?, '2026-09-10T11:00:00Z')",
                    bindings: [.text("phase6b-unlinked-goal-\(suffix)"), .text(projectID.rawValue), .text(threadID), .text("Unlinked execution goal \(suffix)")]
                )
            }
        }

        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .goals)
        model.setWorkspaceGoalsDomain(.execution)
        model.setWorkspaceGoalsExecutionStatus("No stored match")
        let linkedTarget = try XCTUnwrap(model.dashboard?.workspaceGoals.execution.first {
            $0.goalID == "phase6b-linked-goal-12"
        })
        let unlinkedTarget = try XCTUnwrap(model.dashboard?.workspaceGoals.execution.first {
            $0.goalID == "phase6b-unlinked-goal-12"
        })
        let activePhaseBefore = model.currentProject?.activePhaseID
        let laneBefore = try XCTUnwrap(model.dashboard?.allPhaseBoard(for: projectID)?.lanes.first {
            $0.cards.contains { $0.id.rawValue.utf8.elementsEqual("GOALS-LINK-12".utf8) }
        }?.lane)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 940),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 6B Goals — isolated native interaction \(sessionID)"
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.frame = .init(x: 0, y: 0, width: 1_500, height: 940)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)
        let nativeApplication = AXUIElementCreateApplication(getpid())
        let nativeWindow = try XCTUnwrap(accessibilityWindow(nativeApplication, title: window.title))
        let goalsRouteState = try XCTUnwrap(accessibilityRouteState(nativeWindow, identifier: "sidebar-goals"))
        let needsReviewRouteState = try XCTUnwrap(accessibilityRouteState(nativeWindow, identifier: "sidebar-needs-review"))
        XCTAssertTrue(goalsRouteState.isSelected, goalsRouteState.description)
        XCTAssertFalse(needsReviewRouteState.isSelected, needsReviewRouteState.description)
        XCTAssertTrue(accessibilityText(nativeWindow).contains("No persisted goals match these filters"))
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Codex desktop observation unavailable"))
        print("PHASE6B GOALS FILTER-ZERO READY: activate Show All Projects · All states, switch to Delivery, open Nonactive delivery outcome, verify the all-phase typed filter, clear to All goals, Back, then switch to Execution; select Unlinked execution goal 12 with Completed + Unlinked observations, open and close Help, and write the empty and wide markers")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: emptyMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: emptyMarker.path))
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: wideMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: wideMarker.path))
        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(model.workspaceGoalsDomain, .execution)
        XCTAssertEqual(model.workspaceGoalsExecutionStatus, "Completed")
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .unlinked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, unlinkedTarget.id)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(unlinkedTarget.id))
        XCTAssertNotNil(model.workspaceGoalsViewportOffset)
        XCTAssertEqual(model.currentProject?.activePhaseID, activePhaseBefore)
        try taskCapture(hosting, name: "phase6b-goals-wide-return")

        window.setContentSize(NSSize(width: 760, height: 900))
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        print("PHASE6B GOALS COMPACT READY: choose Linked work, select Linked execution goal 12, scroll until View associated work is visibly actionable while retaining the goal focus, then write compact-selection-complete and wait for compact-open-allowed before activating it; on the board verify the explicit Execution Goal filter and GOALS-LINK-12, then write compact-board-ready and wait for compact-clear-allowed; choose All goals, use Back, and write compact-complete")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactSelectionMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactSelectionMarker.path))
        let compactViewport = try XCTUnwrap(model.workspaceGoalsViewportOffset)
        let compactScrollValue = try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow))
        XCTAssertGreaterThan(compactScrollValue, 0.05)
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .linked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, linkedTarget.id)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(linkedTarget.id))
        try Data().write(to: compactOpenAllowedMarker, options: .atomic)
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactBoardMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactBoardMarker.path))
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertEqual(
            model.allPhaseBoardFilter(projectID: projectID),
            .execution(.init(
                threadID: linkedTarget.threadID,
                goalID: linkedTarget.goalID,
                ticketID: .init(rawValue: "GOALS-LINK-12")
            ))
        )
        XCTAssertEqual(
            model.viewedAllPhaseBoard(for: projectID)?.filtered(by: model.allPhaseBoardFilter(projectID: projectID))
                .lanes.flatMap(\.cards).map(\.id.rawValue),
            ["GOALS-LINK-12"]
        )
        try Data().write(to: compactClearAllowedMarker, options: .atomic)
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactMarker.path))
        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .linked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, linkedTarget.id)
        XCTAssertEqual(try XCTUnwrap(model.workspaceGoalsViewportOffset), compactViewport, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow)), compactScrollValue, accuracy: 0.01)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(linkedTarget.id))
        XCTAssertEqual(model.currentProject?.activePhaseID, activePhaseBefore)
        XCTAssertEqual(try XCTUnwrap(model.dashboard?.allPhaseBoard(for: projectID)?.lanes.first {
            $0.cards.contains { $0.id.rawValue.utf8.elementsEqual("GOALS-LINK-12".utf8) }
        }?.lane), laneBefore)
        try taskCapture(hosting, name: "phase6b-goals-compact-return")

        await model.goForward()
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertNotNil(model.viewedAllPhaseBoard(for: projectID))
        XCTAssertEqual(model.allPhaseBoardFilter(projectID: projectID), .all)
        XCTAssertEqual(model.selectedTicketID.rawValue, "GOALS-LINK-12")
        await model.goBack()
        try await Task.sleep(for: .milliseconds(350))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(try XCTUnwrap(model.workspaceGoalsViewportOffset), compactViewport, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow)), compactScrollValue, accuracy: 0.01)
        XCTAssertEqual(accessibilityFocusedIdentifier(nativeApplication), "workspace-goal-\(linkedTarget.id.base64EncodedString())")

        await model.navigate(to: .phaseBoard(projectID))
        try await store.transact(actor: .init(id: "phase6b-native-fixture"), reason: "Replace isolated Goals registration") { connection in
            try connection.execute(
                "UPDATE project_registrations SET registration_id = 'phase6b-replaced-registration', request_generation = 2 WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
        await model.reloadDashboardAfterCommittedAgentCommand()
        await model.goBack()
        try await Task.sleep(for: .milliseconds(350))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(model.selection, .projects)
        XCTAssertEqual(model.navigationFocus, .recovery)
        XCTAssertTrue(model.navigationRecoveryMessage?.contains("different registration was not substituted") == true)
        XCTAssertTrue(accessibilityText(nativeWindow).contains("different registration was not substituted"))
        print("PHASE6B GOALS RECOVERY READY: verify the accessible replaced-registration recovery and write recovery-complete")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: recoveryMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryMarker.path))
        try taskCapture(hosting, name: "phase6b-goals-registration-recovery")
    }

    @MainActor
    func testLiveHistoryJourneyUsesNativeWideAndCompactControlsAndRestoresExactContext() async throws {
        guard let sessionID = ProcessInfo.processInfo.environment["RELEASE_RADAR_PHASE6A_NATIVE_SESSION"] else {
            throw XCTSkip("The external controller must supply a unique Phase 6A native session.")
        }
        guard !sessionID.isEmpty,
              sessionID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            XCTFail("The Phase 6A native session must contain only letters, numbers, hyphens and underscores.")
            return
        }
        let markerRoot = URL(fileURLWithPath: "/private/tmp/release-radar-phase6a.eJzQ2M", isDirectory: true)
        let enableMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-enabled")
        guard FileManager.default.fileExists(atPath: enableMarker.path) else {
            throw XCTSkip("The external controller must create the fresh Phase 6A enable marker.")
        }
        try FileManager.default.removeItem(at: enableMarker)
        let wideSelectionMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-wide-selection-complete")
        let wideOpenReadyMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-wide-open-ready")
        let wideMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-wide-complete")
        let compactSelectionMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-compact-selection-complete")
        let compactOpenReadyMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-compact-open-ready")
        let compactMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-compact-complete")
        let removedWideMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-removed-wide-complete")
        let removedCompactMarker = markerRoot.appendingPathComponent("phase6a-native-\(sessionID)-removed-compact-complete")
        for marker in [
            wideSelectionMarker,
            wideOpenReadyMarker,
            wideMarker,
            compactSelectionMarker,
            compactOpenReadyMarker,
            compactMarker,
            removedWideMarker,
            removedCompactMarker,
        ] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        }

        let fixture = try await makeRR9CaptureModel(scenario: .phaseLifecycle)
        let model = fixture.model
        let projectID = RR9ActivePhaseCaptureFixture.primaryProjectID
        let ticketID = TicketID(rawValue: "RR9-HISTORY")
        try await fixture.store.transact(
            actor: .init(id: "phase6a-native-fixture", threadID: "phase6a-asserted-thread"),
            reason: "Open the nonactive History ticket\nRecorded detail line two remains visible.\nRecorded detail line three remains visible.\nRecorded detail final line remains visible.",
            auditEventID: .init(rawValue: "phase6a-native-history-target"),
            auditScope: .init(projectID: projectID, entityType: .ticket, entityID: ticketID.rawValue)
        ) { _ in }
        for index in 0..<18 {
            try await fixture.store.transact(
                actor: .init(id: "phase6a-native-fixture", threadID: "phase6a-asserted-thread"),
                reason: "Viewport fixture event \(index)",
                auditEventID: .init(rawValue: "phase6a-native-viewport-\(index)"),
                auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
            ) { _ in }
        }
        await model.reloadDashboardAfterCommittedAgentCommand()
        await model.navigate(to: .activity(projectID))
        model.setHistoryFilter(.audit, projectID: projectID)

        let items = try XCTUnwrap(model.activity(for: projectID)?.filtered(by: .audit).items)
        XCTAssertGreaterThanOrEqual(items.count, 2)
        let first = try XCTUnwrap(items.first)
        let last = try XCTUnwrap(items.last)
        let target = try XCTUnwrap(items.first { $0.identity.sourceID == "phase6a-native-history-target" })
        model.selectHistoryEvent(target.identity, projectID: projectID)

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 30, y: 30, width: 1_500, height: 940),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 6A History — isolated native interaction \(sessionID)"
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.frame = .init(x: 0, y: 0, width: 1_500, height: 940)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)

        let nativeApplication = AXUIElementCreateApplication(getpid())
        let nativeWindow = try XCTUnwrap(accessibilityWindow(nativeApplication, title: window.title))
        let wideAccessibilityText = accessibilityText(nativeWindow)
        XCTAssertTrue(wideAccessibilityText.contains("Event source"))
        XCTAssertTrue(wideAccessibilityText.contains("EVENT DETAIL"))
        for item in [first, last] {
            let candidate = await scrollToAccessibilityElement(
                nativeWindow,
                identifier: "history-event-\(item.source.rawValue)-\(item.identity.sourceID)"
            )
            let element = try XCTUnwrap(candidate)
            XCTAssertEqual(
                AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue),
                .success
            )
        }
        try taskCapture(hosting, name: "phase6a-history-wide-before-external")
        print("PHASE6A HISTORY WIDE READY: use native History filter and rows; select RR9-HISTORY and leave Open visible at a non-edge scroll position; wait for the wide-open-ready marker before activating Open")

        for _ in 0..<900 where !FileManager.default.fileExists(atPath: wideSelectionMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: wideSelectionMarker.path))
        let wideViewport = try XCTUnwrap(model.historyViewportOffset(for: projectID))
        let wideScrollValue = try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow))
        XCTAssertGreaterThan(wideScrollValue, 0.05)
        XCTAssertLessThan(wideScrollValue, 0.95)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), target.identity)
        XCTAssertEqual(model.navigationFocus, .historyEvent(target.identity))
        try Data().write(to: wideOpenReadyMarker, options: .atomic)

        for _ in 0..<900 where !FileManager.default.fileExists(atPath: wideMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: wideMarker.path))
        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), target.identity)
        XCTAssertEqual(try XCTUnwrap(model.historyViewportOffset(for: projectID)), wideViewport, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow)), wideScrollValue, accuracy: 0.01)
        XCTAssertEqual(model.navigationFocus, .historyDetail(target.identity))
        XCTAssertEqual(accessibilityFocusedIdentifier(nativeApplication), "history-open-entity")
        XCTAssertNil(model.navigationRecoveryMessage)

        window.setContentSize(NSSize(width: 760, height: 900))
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        try taskCapture(hosting, name: "phase6a-history-compact-before-external")
        print("PHASE6A HISTORY COMPACT READY: verify stacked detail; select RR9-HISTORY, confirm the full recorded detail and scroll to the absolute bottom with Open visible; wait for the compact-open-ready marker before activating Open")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactSelectionMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactSelectionMarker.path))
        XCTAssertNotNil(model.historyViewportOffset(for: projectID))
        let compactScrollValue = try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow))
        XCTAssertEqual(compactScrollValue, 1, accuracy: 0.001)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), target.identity)
        XCTAssertEqual(model.navigationFocus, .historyEvent(target.identity))
        let detailRecord = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "history-detail-record"))
        XCTAssertTrue(accessibilityText(detailRecord).contains("Recorded detail final line remains visible."))
        try Data().write(to: compactOpenReadyMarker, options: .atomic)
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: compactMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: compactMarker.path))
        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), target.identity)
        let capturedCompactViewport = try XCTUnwrap(model.navigationHistory.current.historyViewportOffset)
        XCTAssertEqual(
            try XCTUnwrap(model.historyViewportOffset(for: projectID)),
            capturedCompactViewport,
            accuracy: 1
        )
        XCTAssertEqual(try XCTUnwrap(accessibilityVerticalScrollValue(nativeWindow)), compactScrollValue, accuracy: 0.01)
        XCTAssertEqual(model.navigationFocus, .historyDetail(target.identity))
        XCTAssertEqual(accessibilityFocusedIdentifier(nativeApplication), "history-open-entity")
        XCTAssertNil(model.navigationRecoveryMessage)

        let removalPreview = try await model.previewProjectRemoval(projectID: projectID)
        let removed = try await model.applyProjectRemoval(removalPreview)
        XCTAssertEqual(model.selection, .removedProject(removed.id))
        window.setContentSize(NSSize(width: 1_500, height: 940))
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        try taskCapture(hosting, name: "phase6a-history-removed-wide-before-external")
        print("PHASE6A REMOVED HISTORY WIDE READY: use the local source filter and event rows; select RR9-HISTORY; confirm the full recorded detail and that no Open action exists")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: removedWideMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: removedWideMarker.path))
        XCTAssertEqual(model.selection, .removedProject(removed.id))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "history-open-entity"))
        let removedWideDetail = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "history-detail-record"))
        XCTAssertTrue(accessibilityText(removedWideDetail).contains("Recorded detail final line remains visible."))

        window.setContentSize(NSSize(width: 760, height: 900))
        try await Task.sleep(for: .milliseconds(750))
        hosting.layoutSubtreeIfNeeded()
        try taskCapture(hosting, name: "phase6a-history-removed-compact-before-external")
        print("PHASE6A REMOVED HISTORY COMPACT READY: use the local source filter and event rows; verify stacked full detail and read-only behavior")
        for _ in 0..<900 where !FileManager.default.fileExists(atPath: removedCompactMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: removedCompactMarker.path))
        XCTAssertEqual(model.selection, .removedProject(removed.id))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "history-open-entity"))
        let removedCompactDetail = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "history-detail-record"))
        XCTAssertTrue(accessibilityText(removedCompactDetail).contains("Recorded detail final line remains visible."))
        try taskCapture(hosting, name: "phase6a-history-removed-compact-final")
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
            try seedActionableGoal(projectID: "rr9-owner-project", phaseID: "phase-roadmap", ticketID: "ROAD-1", connection: connection)
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

    private static func seedActionableGoal(projectID: String, phaseID: String, ticketID: String, connection: SQLiteConnection) throws {
        let goalID = "fixture-goal-" + phaseID
        try connection.execute("""
            INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at, activated_at)
            VALUES (?, ?, ?, 'Fixture goal', 'Complete fixture', 'active', 0, '2026-09-02T12:00:00Z', '2026-09-02T12:00:00Z', '2026-09-02T12:00:00Z')
            """, bindings: [.text(projectID), .text(phaseID), .text(goalID)])
        try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES (?, ?, ?, 0, 'Delivered')",
                               bindings: [.text(projectID), .text(phaseID), .text(goalID)])
        try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES (?, ?, ?, ?)",
                               bindings: [.text(projectID), .text(phaseID), .text(goalID), .text(ticketID)])
        try connection.execute("UPDATE phase_plans SET state = 'ready', ready_revision = revision, finalized_at = '2026-09-02T12:00:00Z' WHERE project_id = ? AND phase_id = ?",
                               bindings: [.text(projectID), .text(phaseID)])
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
    func testPhase6CIntegratedTicketEvidenceJourneyIsResponsiveAndOpensHelp() async throws {
        let nativeSession: (id: String, ready: URL, complete: URL)?
        if let sessionID = ProcessInfo.processInfo.environment["RELEASE_RADAR_PHASE6C_NATIVE_SESSION"] {
            guard !sessionID.isEmpty,
                  sessionID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
                XCTFail("The Phase 6C native session must contain only letters, numbers, hyphens and underscores.")
                return
            }
            let markerRoot = URL(
                fileURLWithPath: "/private/tmp/release-radar-phase6c.7kHIve",
                isDirectory: true
            )
            let enable = markerRoot.appendingPathComponent("phase6c-native-\(sessionID)-enabled")
            let ready = markerRoot.appendingPathComponent("phase6c-native-\(sessionID)-compact-ready")
            let complete = markerRoot.appendingPathComponent("phase6c-native-\(sessionID)-compact-complete")
            guard FileManager.default.fileExists(atPath: enable.path) else {
                throw XCTSkip("The external controller must create the fresh Phase 6C enable marker.")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: ready.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: complete.path))
            try FileManager.default.removeItem(at: enable)
            nativeSession = (sessionID, ready, complete)
        } else {
            nativeSession = nil
        }

        // Repository document validation intentionally rejects symlinked root
        // ancestors; macOS's default test temporary directory traverses /var.
        let fixture = try await makeTask10PlanningFixture(
            temporaryRoot: URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
        )
        let documents = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid/docs", isDirectory: true)
        try FileManager.default.copyItem(
            at: documents,
            to: fixture.projectRoot.appendingPathComponent("docs", isDirectory: true)
        )
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: fixture.projectRoot.appendingPathComponent("AGENTS.md"))
        let documentSnapshot = try RepositoryDocumentValidator()
            .validateCurrent(authorizedRoot: fixture.projectRoot)
        let target = DocumentationTarget(
            projectID: fixture.projectID.rawValue,
            rootID: "rr9-owner-root",
            repositoryID: documentSnapshot.catalog.repositoryID.lowercased(),
            catalogVersion: documentSnapshot.version,
            catalogDigest: documentSnapshot.digest
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed Phase 6C route registration") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'phase6c-route-registration', 1, 'complete')",
                bindings: [.text(fixture.projectID.rawValue)]
            )
        }
        let registrationTuple = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT registration_id FROM project_registrations WHERE project_id=?", bindings: [.text(fixture.projectID.rawValue)]),
                try connection.scalarInt("SELECT request_generation FROM project_registrations WHERE project_id=?", bindings: [.text(fixture.projectID.rawValue)])
            )
        }
        let registration = ProjectRegistration(
            projectID: fixture.projectID,
            registrationID: try XCTUnwrap(registrationTuple.0),
            requestGeneration: try XCTUnwrap(registrationTuple.1)
        )
        let dispatcher = AgentCommandDispatcher(
            store: fixture.store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: fixture.projectRoot, authorizedRoots: [fixture.projectRoot]),
            ]),
            bookmarkStore: fixture.bookmarks
        )
        func envelope(_ command: AgentCommand) -> AgentCommandEnvelope {
            .init(
                version: 1,
                requestID: UUID(),
                projectRoot: fixture.projectRoot.path,
                assertedThreadID: "phase6c-integrated-route",
                expectedRegistration: registration,
                reason: "Seed integrated Phase 6C evidence journey",
                command: command
            )
        }
        let bound = await dispatcher.dispatch(envelope(.bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)
        let revision = DeliveryEvidenceRevision(
            commitSHA: String(repeating: "a", count: 40),
            checkoutState: .dirty,
            dirtySnapshotID: "route-snapshot"
        )
        let recorded = await dispatcher.dispatch(envelope(.recordDeliveryEvidenceTarget(
            target: target,
            ticketID: "ROAD-1",
            revision: revision,
            expectations: [
                .init(category: .build, scope: "unit"),
                .init(category: .installation, scope: nil),
                .init(category: .document, scope: nil),
            ],
            expectedEvidenceRevision: 0
        )))
        XCTAssertNil(recorded.error)
        let currentArtifact = try XCTUnwrap(
            documentSnapshot.catalog.artifacts.first(where: { $0.artifactID == "current" })
        )
        let currentBytes = try Data(contentsOf: fixture.projectRoot.appendingPathComponent(currentArtifact.path))
        let observations: [DeliveryEvidenceObservation] = [
            .init(
                id: "route-build", targetVersion: 1,
                fact: .build(.init(repositoryID: target.repositoryID, revision: revision, buildID: "build-route-42", scope: "unit")),
                source: .init(kind: .localObservation, label: "Integrated focused test"),
                sourceAvailability: .available, outcome: .passed,
                observedAt: "2026-09-10T18:10:00Z", recordedAt: "2026-09-10T18:11:00Z"
            ),
            .init(
                id: "route-installation", targetVersion: 1,
                fact: .installation(.init(repositoryID: nil, revision: nil, installationID: nil, buildID: nil, context: "Local application")),
                source: .init(kind: .recordedClaim, label: "Installation identity unavailable"),
                sourceAvailability: .unknown, outcome: .unknown,
                observedAt: "2026-09-10T18:12:00Z", recordedAt: "2026-09-10T18:13:00Z"
            ),
            .init(
                id: "route-document", targetVersion: 1,
                fact: .document(.init(
                    repositoryID: target.repositoryID,
                    revision: revision,
                    artifactID: currentArtifact.artifactID,
                    contentDigest: documentationDigest(currentBytes),
                    catalogVersion: documentSnapshot.version,
                    catalogDigest: documentSnapshot.digest
                )),
                source: .init(kind: .managedDocument, label: currentArtifact.artifactID),
                sourceAvailability: .available, outcome: .observed,
                observedAt: "2026-09-10T18:14:00Z", recordedAt: "2026-09-10T18:15:00Z"
            ),
        ]
        for (offset, observation) in observations.enumerated() {
            let result = await dispatcher.dispatch(envelope(.appendDeliveryEvidenceObservation(
                target: target,
                ticketID: "ROAD-1",
                observation: observation,
                expectedEvidenceRevision: Int64(offset + 1)
            )))
            XCTAssertNil(result.error)
        }

        let model = AppModel(
            store: fixture.store,
            projectOnboarding: fixture.onboarding,
            externalServicesSuppressed: true,
            deliveryEvidenceBookmarkStore: fixture.bookmarks
        )
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(fixture.projectID))
        model.viewPhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
        model.selectTicket(.init(rawValue: "ROAD-1"))

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: .init(x: 30, y: 30, width: 1_500, height: 940),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = nativeSession.map {
            "Phase 6C evidence — native session \($0.id)"
        } ?? "Phase 6C evidence — integrated application journey"
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.frame = .init(x: 0, y: 0, width: 1_500, height: 940)
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        try await Task.sleep(for: .milliseconds(600))
        hosting.layoutSubtreeIfNeeded()

        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "phase-board"))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-inspector"))
        let widePanel = await scrollToAccessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence")
        XCTAssertNotNil(widePanel)
        var wideText = accessibilityText(nativeWindow)
        for expected in ["Recorded target", "Dirty snapshot route-snapshot", "build-route-42", "Unknown installation identity", "Owner acceptance: Not accepted"] {
            XCTAssertTrue(wideText.contains(expected), "Wide integrated evidence omitted: \(expected)")
        }
        try taskCapture(hosting, name: "phase6c-integrated-evidence-wide")

        func textAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
                return nil
            }
            return value as? String
        }
        let buttons = accessibilityElements(nativeWindow, role: kAXButtonRole)
        guard let help = buttons.first(where: { element in
            textAttribute(element, kAXTitleAttribute) == "Help"
                || textAttribute(element, kAXDescriptionAttribute) == "Help"
        }) else {
            let diagnostics = buttons.map { element in
                "title=\(textAttribute(element, kAXTitleAttribute) ?? "nil"), "
                    + "description=\(textAttribute(element, kAXDescriptionAttribute) ?? "nil"), "
                    + "identifier=\(textAttribute(element, kAXIdentifierAttribute) ?? "nil")"
            }.joined(separator: " | ")
            XCTFail("Help AXButton unavailable. Candidates: \(diagnostics)")
            return
        }
        _ = AXUIElementPerformAction(help, "AXScrollToVisible" as CFString)
        XCTAssertEqual(AXUIElementSetAttributeValue(help, kAXFocusedAttribute as CFString, kCFBooleanTrue), .success)
        var isFocused: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(help, kAXFocusedAttribute as CFString, &isFocused), .success)
        XCTAssertEqual((isFocused as? NSNumber)?.boolValue, true)
        XCTAssertEqual(AXUIElementPerformAction(help, kAXPressAction as CFString), .success)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(accessibilityText(application).contains("Recorded is not live"))
        let done = try XCTUnwrap(accessibilityElement(application, identifier: "delivery-evidence-help-done"))
        XCTAssertEqual(AXUIElementPerformAction(done, kAXPressAction as CFString), .success)
        try await Task.sleep(for: .milliseconds(150))

        window.setContentSize(.init(width: 760, height: 940))
        hosting.frame = window.contentView?.bounds ?? hosting.frame
        try await Task.sleep(for: .milliseconds(500))
        hosting.layoutSubtreeIfNeeded()
        if let nativeSession {
            try Data().write(to: nativeSession.ready, options: .atomic)
            print("PHASE6C EVIDENCE COMPACT READY: scroll the mounted ticket inspector until Delivery Evidence is visibly readable, then write the matching compact-complete marker")
            for _ in 0..<900 where !FileManager.default.fileExists(atPath: nativeSession.complete.path) {
                try await Task.sleep(for: .milliseconds(200))
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: nativeSession.complete.path))
        }
        let compactPanelCandidate: AXUIElement? = if nativeSession == nil {
            await scrollToAccessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence")
        } else {
            accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence")
        }
        XCTAssertNotNil(compactPanelCandidate)
        wideText = accessibilityText(nativeWindow)
        XCTAssertTrue(wideText.contains("Recorded target"))
        XCTAssertTrue(wideText.contains("build-route-42"))
        XCTAssertEqual(model.selection, .phaseBoard(fixture.projectID))
        XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
        try taskCapture(hosting, name: "phase6c-integrated-evidence-compact")
    }

    @MainActor
    private func makeRR9OwnerFixture(
        hasBookmark: Bool = true,
        blockAuthorization: Bool = false,
        hasActivePointer: Bool = true,
        temporaryRoot: URL = FileManager.default.temporaryDirectory,
        preserveDirectory: Bool = false
    ) async throws -> RR9OwnerFixture {
        let directory = temporaryRoot
            .appendingPathComponent("ReleaseRadar-RR9Owner-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        if !preserveDirectory {
            addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        }
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

private struct Task10GoalState: Equatable {
    let lifecycle: String?
    let ownerAudits: Int64
    let requests: Int64
    let notifications: Int64
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

private struct PlanChangeProposalRenderScenario {
    let fixture: RR9OwnerFixture
    let proposalID: PlanChangeProposalID
    let plan: ProjectPlanProjection
    let impact: PlanChangeRecordedSourceImpact
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

private struct DocumentationRecoveryMutationState: Equatable {
    let isStale: Int64?
    let restorationAudits: Int64
}

private func documentationRecoveryMutationState(
    store: DeliveryStore
) async throws -> DocumentationRecoveryMutationState {
    try await store.read { connection in
        DocumentationRecoveryMutationState(
            isStale: try connection.scalarInt(
                "SELECT is_stale FROM project_bookmarks WHERE project_id = 'rr9-owner-project'"
            ),
            restorationAudits: try connection.scalarInt(
                "SELECT COUNT(*) FROM audit_events WHERE reason = 'Restore project folder access'"
            ) ?? -1
        )
    }
}

private actor RouteDocumentationObservationLoader {
    private let projectID: ProjectID
    private var callCount = 0
    private var olderObservationEntered = false
    private var olderObservationReleased = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    init(projectID: ProjectID) {
        self.projectID = projectID
    }

    func load(projectID: ProjectID) async -> DocumentationObservationPayload {
        precondition(projectID == self.projectID)
        callCount += 1
        if callCount == 2 {
            olderObservationEntered = true
            enteredContinuations.forEach { $0.resume() }
            enteredContinuations.removeAll()
            if !olderObservationReleased {
                await withCheckedContinuation { releaseContinuations.append($0) }
            }
            return payload(checkedAt: 1, current: false)
        }
        return payload(checkedAt: callCount == 1 ? 0 : 2, current: callCount > 1)
    }

    func waitUntilOlderObservationEntered() async {
        guard !olderObservationEntered else { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func releaseOlderObservation() {
        olderObservationReleased = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }

    private func payload(
        checkedAt: TimeInterval,
        current: Bool
    ) -> DocumentationObservationPayload {
        let identity = DocumentationObservationIdentity(
            projectID: projectID,
            registration: nil,
            rootID: nil,
            rootPath: nil,
            binding: nil
        )
        guard current else {
            return .init(
                identity: identity,
                checkedAt: Date(timeIntervalSince1970: checkedAt),
                documentationState: .legacy(.unavailable),
                evidence: []
            )
        }
        return .init(
            identity: identity,
            checkedAt: Date(timeIntervalSince1970: checkedAt),
            documentationState: .managed(
                hasAuditedHandoff: true,
                catalogVersion: 1,
                catalogDigest: String(repeating: "a", count: 64)
            ),
            evidence: [
                EvidenceReadback(
                    evidence: LocatedEvidenceRecord(
                        id: EvidenceID(rawValue: "new-documentation-evidence"),
                        projectID: projectID,
                        ticketID: nil,
                        locator: EvidenceLocator.managedDocument(artifactID: "current-plan"),
                        isAvailable: true
                    ),
                    managedDocument: ResolvedManagedDocument(
                        artifactID: "current-plan",
                        resolvedPath: "docs/plans/current.md",
                        label: "Current plan",
                        lifecycle: RepositoryDocumentArtifact.Lifecycle.active,
                        authority: RepositoryDocumentArtifact.Authority.controlling,
                        authorityRole: "delivery-plan",
                        failure: nil
                    )
                ),
            ]
        )
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
    func restartHelper() async -> CodexPluginHelperReply { await status() }
}

private actor AppLifecycleManager: CodexPluginLifecycleManaging {
    enum Operation: Equatable { case status, statusReadOnly, install, remove, reinstall, restartHelper }
    private var replies: [CodexPluginHelperReply]
    private var calls: [Operation] = []

    init(replies: [CodexPluginHelperReply]) {
        self.replies = replies
    }

    func status() async -> CodexPluginHelperReply { next(.status) }
    func statusReadOnly() async -> CodexPluginHelperReply { next(.statusReadOnly) }
    func install() async -> CodexPluginHelperReply { next(.install) }
    func remove() async -> CodexPluginHelperReply { next(.remove) }
    func reinstall() async -> CodexPluginHelperReply { next(.reinstall) }
    func restartHelper() async -> CodexPluginHelperReply { next(.restartHelper) }
    func operations() -> [Operation] { calls }

    private func next(_ operation: Operation) -> CodexPluginHelperReply {
        calls.append(operation)
        return replies.isEmpty
            ? .init(wireVersion: 1, observedState: nil, error: .malformedResult)
            : replies.removeFirst()
    }
}

private actor PluginCompatibilityObservationLoader {
    private let projectID: ProjectID
    private var calls = 0

    init(projectID: ProjectID) {
        self.projectID = projectID
    }

    func load(projectID: ProjectID) -> DocumentationObservationPayload {
        precondition(projectID == self.projectID)
        calls += 1
        return .init(
            identity: .init(
                projectID: projectID,
                registration: nil,
                rootID: nil,
                rootPath: "/synthetic/plugin-refresh",
                binding: nil
            ),
            checkedAt: Date(timeIntervalSince1970: TimeInterval(calls)),
            documentationState: .legacy(.unavailable),
            evidence: [],
            sharedExecutionCompatibility: .init(state: .unknown, directResults: [])
        )
    }

    func count() -> Int { calls }
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


private final class TaskPlanQueryFault: @unchecked Sendable {
    private let lock = NSLock()
    private var failing = false
    var isFailing: Bool {
        get { lock.withLock { failing } }
        set { lock.withLock { failing = newValue } }
    }
}

@MainActor
private struct Task10ReviewTestView: View {
    @Bindable var model: AppModel
    let projectID: ProjectID

    var body: some View {
        if let inbox = model.reviewInbox(for: projectID) {
            NeedsReviewView(inbox: inbox, selectedItemID: $model.selectedReviewItemID,
                isPerformingAction: model.scopedIsPerformingReviewAction(for: projectID),
                actionFailure: model.scopedReviewActionFailure(for: projectID), projectName: "RR-R9 Owner",
                authorizationRecovery: model.scopedReviewAuthorizationRecovery(for: projectID),
                onDecision: { _, _ in XCTFail("Not an import review action") },
                onRecoverAuthorization: { _, _ in XCTFail("No authorization change during inspection") },
                onAcceptDeliveryGoal: { await model.acceptDeliveryGoal($0) },
                onReload: { await model.reloadDeliveryGoalAcceptance(projectID: projectID) },
                acceptanceNeedsReload: model.deliveryGoalAcceptanceNeedsReload(for: projectID))
        }
    }
}

private struct Task10BoardTestView: View {
    @Bindable var model: AppModel
    let projectID: ProjectID
    var initialFilter: DeliveryGoalFilter = .all
    @State private var didApplyInitialFilter = false

    var body: some View {
        if let board = model.viewedBoard(for: projectID) {
            PhaseBoardView(
                board: board,
                selectedTicketID: $model.selectedTicketID,
                filter: Binding(
                    get: { model.boardFilter(projectID: projectID, phaseID: board.phaseID) },
                    set: { model.setBoardFilter($0, projectID: projectID, phaseID: board.phaseID) }
                ),
                phaseSelectionStatus: model.activePhaseSelectionStatus(for: projectID),
                selectActivePhase: { await model.setActivePhase(projectID: projectID, phaseID: $0) },
                reloadActivePhase: { await model.reloadAfterActivePhaseSelection(projectID: projectID) },
                reauthorizeActivePhase: { _ in XCTFail("No authorization change in render check") },
                viewPhase: { model.viewPhase(projectID: projectID, phaseID: $0) },
                requestedFocus: model.navigationFocus,
                focusChanged: { model.setNavigationFocus($0) })
                .onAppear {
                    guard !didApplyInitialFilter else { return }
                    didApplyInitialFilter = true
                    model.setBoardFilter(initialFilter, projectID: projectID, phaseID: board.phaseID)
                }
        }
    }
}

private struct TaskPlanBoardTestView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .subheadline) private var metric = 12.0
    @Bindable var model: AppModel
    let projectID: ProjectID
    var body: some View {
        if let board = model.dashboard?.board(for: projectID) {
            PhaseBoardView(board: board, selectedTicketID: $model.selectedTicketID, filter: .constant(.all),
                phaseSelectionStatus: model.activePhaseSelectionStatus(for: projectID),
                selectActivePhase: { _ in XCTFail("Task UI must not select an active phase") },
                reloadActivePhase: { await model.reloadAfterActivePhaseSelection(projectID: projectID) },
                reauthorizeActivePhase: { _ in XCTFail("Task UI must not authorize folders") })
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear { print("TASK5 ENV dynamicType=\(typeSize) metric=\(metric) contrast=\(contrast)") }
        }
    }
}
