import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ProjectDocumentationRenderingTests: XCTestCase {
    // Inspect only this isolated test process and its own titled native windows.
    func testOverviewDocumentationStateAtWideAndCompactWidths() async throws {
        let project = ProjectDashboardProjection(
            id: .init(rawValue: "m2c-rendering"),
            name: "Documentation Preview",
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 0
        )
        for (name, state) in states {
            for width in [1100.0, 620.0] {
                let view = ProjectOverviewView(
                    project: project,
                    board: nil,
                    documentationState: state,
                    projectRoot: URL(fileURLWithPath: "/Synthetic/DocumentationPreview"),
                    phaseSelectionStatus: .idle,
                    openBoard: {},
                    selectActivePhase: { _ in },
                    reloadActivePhase: {},
                    reauthorizeActivePhase: { _ in }
                )
                try await render(view, name: "m5-overview-\(name)-\(Int(width))", width: width, expected: ProjectGuidancePresentation(documentationState: state))
            }
        }
    }

    func testOnboardingDocumentationPreviewAtWideAndCompactWidths() async throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-M5-Rendering-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        print("M5 isolated rendering store: \(output.path)")
        let store = DeliveryStore(databaseURL: output.appendingPathComponent("rendering.sqlite"))
        for (name, state) in states {
            let preview = OnboardingPreview(
                selectedFolder: URL(fileURLWithPath: "/Synthetic/DocumentationPreview"),
                gitRoot: nil,
                includedTaskDescriptors: [],
                rejectedTaskDescriptors: [],
                authorizedWorktreeURLs: [],
                worktreesRequiringAuthorization: [],
                documentationState: state
            )
            for width in [1100.0, 620.0] {
                let captureName = "m5-onboarding-\(name)-\(Int(width))"
                let view = OnboardingView(
                    store: store,
                    navigationTitle: captureName,
                    onOpenExisting: { _ in },
                    pasteboardWriter: { _ in XCTFail("Rendering must not write to the clipboard"); return false },
                    initialPreview: preview,
                    onFinished: { _ in XCTFail("Rendering must not initialize a project") }
                )
                try await render(view, name: captureName, width: width, expected: ProjectGuidancePresentation(documentationState: state))
            }
        }
    }

    func testUsableLifecycleOverviewAtWideAndCompactWidths() async throws {
        let projectID = ProjectID(rawValue: "project-rendering-opaque")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-rendering-opaque",
            requestGeneration: 3
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Usable Lifecycle",
            activePhaseName: "No active phase",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 0,
            attentionCount: 1
        )
        let health = ProjectHealthSnapshot(
            projectID: projectID,
            registration: registration,
            rootPath: "/Synthetic/UsableLifecycle",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [
                .init(id: "storage", title: "Local storage ready", detail: "The current Release Radar schema is available.", state: .ready),
                .init(id: "folder", title: "Folder access ready", detail: "/Synthetic/UsableLifecycle", state: .ready),
                .init(id: "documentation", title: "Release Radar guidance not installed", detail: "Repository preparation remains explicit.", state: .attention),
                .init(id: "plugin", title: "Codex workflow ready", detail: "The installed workflow matches.", state: .ready),
                .init(id: "observer", title: "Codex observation unavailable", detail: "Retry observation separately.", state: .attention),
            ]
        )
        for width in [1100.0, 620.0] {
            let view = ProjectOverviewView(
                project: project,
                board: nil,
                documentationState: .legacy(.missing),
                projectRoot: URL(fileURLWithPath: "/Synthetic/UsableLifecycle"),
                phaseSelectionStatus: .idle,
                openBoard: {},
                selectActivePhase: { _ in },
                reloadActivePhase: {},
                reauthorizeActivePhase: { _ in },
                loadProjectSettings: {
                    .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                saveProjectSettings: { _, _, _ in
                    XCTFail("Rendering must not save settings")
                    return .init(registration: registration, projectName: project.name, excludedTaskIDs: [])
                },
                loadProjectHealth: { health },
                previewDocumentationSetup: { _ in
                    XCTFail("Rendering must not preview documentation")
                    throw ProjectDocumentationSetupError.catalogUnavailable
                }
            )
            try await render(
                view,
                name: "lifecycle-overview-\(Int(width))",
                width: width,
                expected: ProjectGuidancePresentation(documentationState: .legacy(.missing)),
                expectedText: [
                    "Ready for a first phase",
                    "Manage Project",
                    "Help",
                    "Documentation activation",
                    "Project health",
                    "registration-rendering-opaque",
                    "generation 3",
                    "Local storage ready",
                    "Folder access ready",
                    "Codex workflow ready",
                    "Codex observation unavailable",
                ]
            )
        }
    }

    func testRDSApplicationRoutesAtWideAndCompactWidths() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RDS-Routes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()

        let projectID = DashboardSampleData.projectID
        let routes: [(String, AppRoute, String)] = [
            ("projects", .projects, "Projects"),
            ("needs-review", .needsReview, "Needs Review"),
            ("notifications", .notifications, "Notifications"),
            ("settings", .settings, "Connections"),
            ("overview", .projectOverview(projectID), "Overview"),
            ("phase-board", .phaseBoard(projectID), "Phase Board"),
            ("dependencies", .dependencies(projectID), "Dependencies"),
            ("activity", .activity(projectID), "Activity"),
        ]

        for width in [1100.0, 620.0] {
            model.isSidebarCompact = width <= 620
            for (name, route, expectedTitle) in routes {
                model.selection = route
                try await render(
                    SidebarView(model: model),
                    name: "rds-\(name)-\(Int(width))",
                    width: width,
                    expected: nil,
                    expectedText: width <= 620
                        ? [expectedTitle]
                        : [expectedTitle, "Delivery", "Persisted locally"]
                )
            }
        }
    }

    func testRDSLifecycleSheetsAndPluginConflictRenderInExistingHost() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RDS-Sheets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        model.codexPluginState = .failed(.marketplaceConflict)
        model.codexPluginSettingsMessage = CodexPluginSettingsPresentation(state: model.codexPluginState).detail
        try await render(
            SettingsView(model: model),
            name: "rds-plugin-conflict-settings",
            width: 760,
            expected: nil,
            expectedText: [
                "Release Radar Codex Plugin",
                "A different Release Radar plugin or MCP entry already owns this name.",
                "Resolve or rename the conflicting plugin or MCP entry in Codex, then try again.",
            ]
        )

        model.alertRules = try AlertRuleSnapshot(values: Dictionary(
            uniqueKeysWithValues: AlertRuleKind.allCases.map { ($0, true) }
        ))
        try await render(
            SettingsView(model: model),
            name: "rds-notification-settings",
            width: 760,
            expected: nil,
            pressIdentifiers: ["settings-notifications"]
        )

        let registration = ProjectRegistration(
            projectID: .init(rawValue: "rds-sheet-project"),
            registrationID: "rds-sheet-registration",
            requestGeneration: 1
        )
        try await render(
            ProjectSettingsEditor(
                initial: .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: []),
                tasks: [.init(id: "task-1", workingDirectory: directory, title: "RDS adoption")],
                save: { _, _ in
                    XCTFail("Rendering must not save project settings")
                    return .init(registration: registration, projectName: "RDS Project", excludedTaskIDs: [])
                }
            ),
            name: "rds-project-settings-sheet",
            width: 620,
            expected: nil,
            expectedText: ["Project settings", "Observed Codex tasks", "RDS adoption", "Save"]
        )

        try await render(
            ProjectLifecycleHelpView(),
            name: "rds-project-lifecycle-help",
            width: 620,
            expected: nil,
            expectedText: ["Project lifecycle help", "Initialize locally", "Prepare repository documentation", "Recover safely"]
        )
    }

    func testPhaseLessRoutesRenderAsSupportedRDSStatesAtWideAndCompactWidths() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RDS-PhaseLess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed phase-less RDS rendering fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('phase-less-rds', 'Phase-less Project')")
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let projectID = ProjectID(rawValue: "phase-less-rds")

        for width in [1100.0, 620.0] {
            model.isSidebarCompact = width <= 620
            for (name, route, expectedTitle) in [
                ("phase-board", AppRoute.phaseBoard(projectID), "Ready for a first phase"),
                ("dependencies", AppRoute.dependencies(projectID), "No phase dependencies yet"),
            ] {
                model.selection = route
                try await render(
                    SidebarView(model: model),
                    name: "rds-phase-less-\(name)-\(Int(width))",
                    width: width,
                    expected: nil,
                    expectedText: [expectedTitle]
                )
            }
        }
    }

    func testProjectHealthFolderRecoveryButtonInvokesItsAuthorizedAction() async throws {
        var invocationCount = 0
        let projectID = ProjectID(rawValue: "project-recovery")
        let snapshot = ProjectHealthSnapshot(
            projectID: projectID,
            registration: .init(projectID: projectID, registrationID: "registration-recovery", requestGeneration: 1),
            rootPath: "/Synthetic/Recovery",
            checkedAt: Date(timeIntervalSince1970: 1_788_000_000),
            checks: [
                .init(id: "folder", title: "Folder access expired", detail: "Select the same saved folder again.", state: .attention),
                .init(id: "documentation", title: "Managed documentation unavailable", detail: "Catalog remains invalid.", state: .attention),
            ]
        )
        try await render(
            ProjectHealthView(snapshot: snapshot, isRefreshing: false, refresh: {}, reauthorize: { invocationCount += 1 }),
            name: "lifecycle-folder-recovery",
            width: 620,
            expected: nil,
            expectedText: ["Reauthorize Saved Folder…", "Catalog remains invalid."],
            pressIdentifiers: ["project-health-reauthorize"]
        )
        XCTAssertEqual(invocationCount, 1)
    }

    func testOnboardingNativeCopyUsesTheSameExistingDocumentationBootstrapShownInPreview() async throws {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".release-radar-copy-action-test-\(UUID().uuidString)", isDirectory: true)
        let root = directory.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        try Data("# Existing owner documentation\n".utf8).write(to: root.appendingPathComponent("README.md"))
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let preview = OnboardingPreview(
            selectedFolder: root,
            gitRoot: nil,
            includedTaskDescriptors: [],
            rejectedTaskDescriptors: [],
            authorizedWorktreeURLs: [],
            worktreesRequiringAuthorization: [],
            documentationState: .legacy(.outdated(installed: 1, current: 2))
        )
        var copied = ""
        let view = OnboardingView(
            store: store,
            navigationTitle: "lifecycle-native-copy",
            onOpenExisting: { _ in XCTFail("Must remain in initialization") },
            pasteboardWriter: { copied = $0; return true },
            initialPreview: preview,
            onFinished: { _ in XCTFail("Copy does not finish initialization") }
        )

        try await render(
            view,
            name: "lifecycle-native-copy",
            width: 620,
            expected: ProjectGuidancePresentation(documentationState: preview.documentationState),
            pressIdentifiers: ["onboarding-initialize-confirm", "onboarding-copy-codex-prompt"]
        )

        XCTAssertTrue(copied.localizedCaseInsensitiveContains("lifecycle bootstrap"))
        XCTAssertTrue(copied.localizedCaseInsensitiveContains("existing documentation"))
        XCTAssertFalse(copied.contains("Require an existing catalogued"))
    }

    private var states: [(String, ProjectDocumentationState)] {
        [
            ("v1-update", .legacy(.outdated(installed: 1, current: 2))),
            ("managed-current", .managed(hasAuditedHandoff: true, catalogVersion: 1, catalogDigest: "test-only")),
            ("managed-unavailable", .managedUnavailable(hasAuditedHandoff: true, reason: .catalogUnaccepted, validationError: nil))
        ]
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root], result: [String] = [], count = 0
        while let element = pending.popLast(), count < 1000 {
            count += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value = value as? String { result.append(value) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success, let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return result.joined(separator: "\n")
    }

    private func render<V: View>(
        _ view: V,
        name: String,
        width: Double,
        expected: ProjectGuidancePresentation?,
        expectedText: [String] = [],
        pressIdentifiers: [String] = []
    ) async throws {
        let frame = NSRect(x: 30, y: 30, width: width, height: 850)
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = name
        let priorActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { window.close(); NSApp.setActivationPolicy(priorActivationPolicy) }
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
        window.title = name
        if let seconds = ProcessInfo.processInfo.environment["RR_TASK7A_INSPECT_SECONDS"].flatMap(Double.init), seconds > 0 {
            print("Task 7A external inspection: \(name), \(Int(width))×850, PID \(ProcessInfo.processInfo.processIdentifier)")
            try await Task.sleep(for: .seconds(min(seconds, 60)))
        }
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value), .success)
        func matchesTestWindow(_ element: AXUIElement) -> Bool {
            var pid: pid_t = 0
            var title: CFTypeRef?
            var role: CFTypeRef?
            return AXUIElementGetPid(element, &pid) == .success
                && pid == ProcessInfo.processInfo.processIdentifier
                && AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success
                && (role as? String) == kAXWindowRole
                && AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success
                && (title as? String) == name
        }
        var ownWindow = (value as? [AXUIElement] ?? []).first(where: matchesTestWindow)
        // XCTest can expose its window through focused/main attributes while AXWindows is empty.
        if ownWindow == nil {
            for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
                var candidate: CFTypeRef?
                guard AXUIElementCopyAttributeValue(application, attribute as CFString, &candidate) == .success,
                      let candidate, CFGetTypeID(candidate) == AXUIElementGetTypeID() else { continue }
                let element = candidate as! AXUIElement
                if matchesTestWindow(element) {
                    ownWindow = element
                    break
                }
            }
        }
        let actual = accessibilityText(try XCTUnwrap(ownWindow))
        if let expected {
            XCTAssertTrue(actual.contains(expected.status), "Missing actual guidance status: \(expected.status)")
        }
        for text in expectedText {
            XCTAssertTrue(actual.contains(text), "Missing actual lifecycle content: \(text)")
        }
        if name.contains("managed-unavailable") {
            XCTAssertTrue(actual.contains("catalog acceptance"), "Missing actual pending-catalog recovery")
            XCTAssertFalse(actual.contains("Copy setup prompt"))
            XCTAssertFalse(actual.contains("Copy repair prompt"))
        }
        if name.hasPrefix("m5-overview"), let action = expected?.actionTitle { XCTAssertTrue(actual.contains(action)) }
        for pressIdentifier in pressIdentifiers {
            let button = try XCTUnwrap(accessibilityElement(try XCTUnwrap(ownWindow), identifier: pressIdentifier))
            XCTAssertEqual(AXUIElementPerformAction(button, kAXPressAction as CFString), .success)
            try await Task.sleep(for: .milliseconds(300))
        }
        print("M5 isolated render PID \(ProcessInfo.processInfo.processIdentifier): actual AX status and recovery verified; capture \(name)")
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root], count = 0
        while let element = pending.popLast(), count < 1000 {
            count += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier {
                return element
            }
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
               role as? String == kAXButtonRole {
                for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                    if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                       (value as? String)?.contains("Reauthorize Saved Folder") == true {
                        return element
                    }
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }
}
