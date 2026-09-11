import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class WorkspaceSearchNativeRenderingTests: XCTestCase {
    func testSearchSavedViewsAndHelpRenderWideAndCompact() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchNative-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        try await store.transact(actor: .init(id: "search-native-test"), reason: "Register isolated Search fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'search-native-registration', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
        }
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        let savedDefinition = WorkspaceSearchDefinition(
            text: "VD2-08",
            scope: .allAuthorized,
            domains: [.ticket],
            sort: .title
        )
        _ = try await repository.saveQuery(id: "native-ticket", name: "Ticket review", definition: savedDefinition)
        _ = try await repository.saveQuery(id: "native-newer", name: "Future filters", definition: savedDefinition)
        try await store.transact(actor: .init(id: "search-native-test"), reason: "Seed recoverable newer-version Search state") { connection in
            try connection.execute(
                "UPDATE workspace_saved_queries SET payload_version = 99, payload_data = ? WHERE id = 'native-newer'",
                bindings: [.blob(Data("future-saved-query".utf8))]
            )
        }

        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .search)
        model.setWorkspaceSearchText(savedDefinition.text)
        for domain in WorkspaceSearchDomain.allCases where domain != .ticket {
            model.setWorkspaceSearchDomain(domain, enabled: false)
        }
        model.setWorkspaceSearchSort(.title)
        await model.runWorkspaceSearch()
        await model.loadWorkspaceSearchPreferences(runSearch: false)
        let result = try XCTUnwrap(model.workspaceSearchProjection?.results.first)
        model.selectWorkspaceSearchResult(result.id)
        model.setWorkspaceSearchViewportOffset(42)
        try await store.transact(actor: .init(id: "search-native-test"), reason: "Seed recoverable newer-version working Search state") { connection in
            try connection.execute(
                "UPDATE workspace_search_preferences SET payload_version = 99, payload_data = ? WHERE singleton_id = 1",
                bindings: [.blob(Data("future-working-query".utf8))]
            )
        }
        await model.loadWorkspaceSearchPreferences(runSearch: false)

        let activePhaseBefore = try await activePhase(in: store, projectID: projectID)
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
        let token = ProcessInfo.processInfo.environment["RR_PHASE6E_NATIVE_SESSION"]
        window.title = token.map { "Phase 6E Search — isolated native acceptance — \($0)" }
            ?? "Phase 6E Search — isolated native acceptance"
        defer { window.close() }
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.appearance = window.appearance
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        for width in [1_500.0, 760.0] {
            window.setContentSize(NSSize(width: width, height: 900))
            hosting.frame = window.contentView?.bounds ?? .zero
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-field"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-filters"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-search-detail"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-saved-query-native-ticket"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-saved-query-native-newer"))
            XCTAssertTrue(accessibilityText(nativeWindow).contains("Newer version"))
            try capture(hosting, name: "phase6e-search-\(Int(width))")
        }

        await model.navigate(to: .help)
        for width in [1_500.0, 760.0] {
            window.setContentSize(NSSize(width: width, height: 900))
            hosting.frame = window.contentView?.bounds ?? .zero
            try await Task.sleep(for: .milliseconds(250))
            hosting.layoutSubtreeIfNeeded()
            let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "workspace-help"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-search-field"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-action-saved-query-recovery"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "help-action-search-navigation"))
            try capture(hosting, name: "phase6e-help-\(Int(width))")
        }
        await model.goBack()
        window.setContentSize(NSSize(width: 1_500, height: 900))
        hosting.frame = window.contentView?.bounds ?? .zero
        try await Task.sleep(for: .milliseconds(250))
        hosting.layoutSubtreeIfNeeded()

        if let token {
            try await waitForExternalNativeJourney(token: token, window: window)
        }

        let activePhaseAfter = try await activePhase(in: store, projectID: projectID)
        XCTAssertEqual(activePhaseAfter, activePhaseBefore)
        XCTAssertNil(model.dashboardError)
    }

    private func activePhase(in store: DeliveryStore, projectID: ProjectID) async throws -> String? {
        try await store.read {
            try $0.scalarText(
                "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
    }

    private func waitForExternalNativeJourney(token: String, window: NSWindow) async throws {
        XCTAssertFalse(token.isEmpty)
        let controlDirectory = URL(
            fileURLWithPath: "/private/tmp/release-radar-phase6e-writer-01a08dee/native-\(token)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: controlDirectory, withIntermediateDirectories: true)
        let readyURL = controlDirectory.appendingPathComponent("ready")
        let completeURL = controlDirectory.appendingPathComponent("complete")
        XCTAssertFalse(FileManager.default.fileExists(atPath: readyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: completeURL.path))
        let identity = "token=\(token)\npid=\(ProcessInfo.processInfo.processIdentifier)\nwindow=\(window.title)\n"
        XCTAssertTrue(FileManager.default.createFile(atPath: readyURL.path, contents: Data(identity.utf8)))
        print("PHASE6E NATIVE READY: \(identity.replacingOccurrences(of: "\n", with: " "))")

        for _ in 0..<1_200 where !FileManager.default.fileExists(atPath: completeURL.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        let completion = try String(contentsOf: completeURL, encoding: .utf8)
        XCTAssertEqual(completion.trimmingCharacters(in: .whitespacesAndNewlines), token)
    }

    private func accessibilityWindow(title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success else {
            return nil
        }
        return (value as? [AXUIElement])?.first {
            accessibilityAttribute($0, kAXTitleAttribute) == title
        }
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var inspected = 0
        while let element = pending.popLast(), inspected < 3_000 {
            inspected += 1
            if accessibilityAttribute(element, kAXIdentifierAttribute) == identifier { return element }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }

    private func accessibilityAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var text: [String] = []
        var inspected = 0
        while let element = pending.popLast(), inspected < 3_000 {
            inspected += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                if let value = accessibilityAttribute(element, attribute) { text.append(value) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return text.joined(separator: "\n")
    }

    private func capture<V: View>(_ hosting: NSHostingView<V>, name: String) throws {
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
