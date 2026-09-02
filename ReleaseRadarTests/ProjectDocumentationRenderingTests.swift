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
        expected: ProjectGuidancePresentation
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
        XCTAssertTrue(actual.contains(expected.status), "Missing actual guidance status: \(expected.status)")
        if name.contains("managed-unavailable") {
            XCTAssertTrue(actual.contains("catalog acceptance"), "Missing actual pending-catalog recovery")
            XCTAssertFalse(actual.contains("Copy setup prompt"))
            XCTAssertFalse(actual.contains("Copy repair prompt"))
        }
        if name.hasPrefix("m5-overview"), let action = expected.actionTitle { XCTAssertTrue(actual.contains(action)) }
        print("M5 isolated render PID \(ProcessInfo.processInfo.processIdentifier): actual AX status and recovery verified; capture \(name)")
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
