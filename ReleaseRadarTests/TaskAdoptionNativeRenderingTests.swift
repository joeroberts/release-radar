import AppKit
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class TaskAdoptionNativeRenderingTests: XCTestCase {
    func testTasksHelpIsAvailableAndRendersAtWideAndCompactWidths() async throws {
        let detail = TicketDetailProjection(
            id: .init(rawValue: "ADOPT-1"),
            outcome: "Adopt explicit generic tasks",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            requires: [],
            unlocks: [],
            ownerAttention: [],
            evidence: [],
            auditHistory: [],
            notificationHistory: [],
            taskPlan: .loaded(plan: .init(revision: 4, tasks: [
                .init(id: .init(rawValue: "task-current"), label: "Task 1", title: "Keep exact current definition", completion: .pending),
            ]))
        )

        for width in [520.0, 320.0] {
            let inspector = NSHostingView(rootView: TicketDetailView(detail: detail))
            inspector.frame = NSRect(x: 0, y: 0, width: width, height: 780)
            let window = NSWindow(contentRect: inspector.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = "Phase 6D task adoption — \(Int(width))"
            window.contentView = inspector
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            defer { window.close() }
            defer { NSApp.setActivationPolicy(previousPolicy) }
            try await Task.sleep(for: .milliseconds(250))
            inspector.layoutSubtreeIfNeeded()

            let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
            let nativeWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))
            let helpButton = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "task-adoption-help-button"))
            XCTAssertEqual(accessibilityAttribute(helpButton, kAXRoleAttribute), kAXButtonRole)
            XCTAssertEqual(AXUIElementPerformAction(helpButton, kAXPressAction as CFString), .success)
            try await Task.sleep(for: .milliseconds(150))
            let helpText = accessibilityText(application)
            XCTAssertTrue(helpText.contains(TaskAdoptionHelpContent.title))
            XCTAssertTrue(helpText.contains(TaskAdoptionHelpContent.evidence))
            let done = try XCTUnwrap(accessibilityElement(application, identifier: "task-adoption-help-done"))
            XCTAssertEqual(AXUIElementPerformAction(done, kAXPressAction as CFString), .success)
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertFalse(accessibilityText(application).contains(TaskAdoptionHelpContent.title))
            try capture(inspector, name: "phase6d-tasks-inspector-\(Int(width))")

            let help = NSHostingView(rootView: TaskAdoptionHelpView())
            help.frame = NSRect(x: 0, y: 0, width: width, height: 620)
            window.contentView = help
            try await Task.sleep(for: .milliseconds(50))
            help.layoutSubtreeIfNeeded()
            XCTAssertEqual(TaskAdoptionHelpContent.title, "Adopting ticket tasks")
            XCTAssertTrue(TaskAdoptionHelpContent.evidence.contains("explicitly applicable"))
            XCTAssertTrue(TaskAdoptionHelpContent.recovery.contains("exact request"))
            try capture(help, name: "phase6d-task-help-\(Int(width))")
        }
    }

    private func accessibilityWindow(_ application: AXUIElement, title: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application, kAXWindowsAttribute as CFString, &value
        ) == .success else { return nil }
        return (value as? [AXUIElement])?.first { window in
            accessibilityAttribute(window, kAXTitleAttribute) == title
        }
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var inspected = 0
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            if accessibilityAttribute(element, kAXIdentifierAttribute) == identifier {
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
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                if let value = accessibilityAttribute(element, attribute) {
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
