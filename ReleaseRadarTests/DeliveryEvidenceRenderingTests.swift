import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class DeliveryEvidenceRenderingTests: XCTestCase {
    func testPanelRendersRecordedTargetObservationsAndHelpAtWideAndCompactWidths() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        var retainedWindows: [NSWindow] = []
        defer {
            retainedWindows.forEach { $0.orderOut(nil) }
            NSApp.setActivationPolicy(previousPolicy)
        }

        for width in [760.0, 330.0] {
            let hosting = NSHostingView(rootView: ScrollView {
                TicketDeliveryEvidenceSection(
                    identity: "project:registration:ticket",
                    load: { .loaded(Self.evidence(ticketID: "RR-6C", sourceLabel: "Focused XCTest run")) }
                )
                .padding(16)
            }.environment(\.colorScheme, .dark))
            hosting.frame = .init(x: 0, y: 0, width: width, height: 900)
            let window = makeWindow(
                title: "Phase 6C evidence — isolated native acceptance \(Int(width))",
                content: hosting,
                width: width,
                height: 900
            )
            retainedWindows.append(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .milliseconds(180))
            hosting.layoutSubtreeIfNeeded()

            let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
            let text = accessibilityText(nativeWindow)
            XCTAssertTrue(text.contains("Recorded target"))
            XCTAssertTrue(text.contains("Dirty snapshot snapshot-a"))
            XCTAssertTrue(text.contains("Focused XCTest run"))
            XCTAssertTrue(text.contains("Passed"))
            XCTAssertTrue(text.contains("Unknown installation identity"))
            XCTAssertTrue(text.contains("Document content changed"))
            XCTAssertTrue(text.contains("Owner acceptance: Not accepted"))
            XCTAssertTrue(text.contains("Help"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "delivery-evidence-observation-build"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "delivery-evidence-observation-installation"))
            XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "delivery-evidence-observation-document"))
            try capture(hosting, name: "phase6c-delivery-evidence-\(Int(width))")
        }

        let helpHosting = NSHostingView(rootView: DeliveryEvidenceHelpView()
            .environment(\.colorScheme, .dark))
        helpHosting.frame = .init(x: 0, y: 0, width: 640, height: 620)
        let helpWindow = makeWindow(
            title: "Phase 6C evidence help — isolated native acceptance",
            content: helpHosting,
            width: 640,
            height: 620
        )
        retainedWindows.append(helpWindow)
        helpWindow.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(180))

        let nativeWindow = try XCTUnwrap(accessibilityWindow(title: helpWindow.title))
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Recorded is not live"))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "delivery-evidence-help-sheet"))
    }

    private func makeWindow<V: View>(
        title: String,
        content: NSHostingView<V>,
        width: CGFloat,
        height: CGFloat
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: .init(x: 40, y: 40, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = content
        return window
    }

    func testPanelDistinguishesEmptyAndUnavailableStates() async throws {
        let empty = NSHostingView(rootView: TicketDeliveryEvidenceSection(
            identity: "empty",
            load: { .loaded(Self.emptyEvidence) }
        ))
        empty.frame = .init(x: 0, y: 0, width: 500, height: 400)
        let emptyWindow = NSWindow(contentRect: empty.frame, styleMask: [.titled], backing: .buffered, defer: false)
        emptyWindow.title = "Phase 6C evidence empty"
        emptyWindow.contentView = empty
        emptyWindow.makeKeyAndOrderFront(nil)
        defer { emptyWindow.close() }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(accessibilityText(AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier))
            .contains("No revision-bound delivery evidence recorded"))

        let unavailable = NSHostingView(rootView: TicketDeliveryEvidenceSection(
            identity: "unavailable",
            load: { .failed(.init(
                title: "Delivery evidence unavailable",
                detail: "Restore this project's exact documentation root and reload.",
                systemImage: "questionmark.folder",
                tone: .warning,
                accessibilityID: "delivery-evidence-unavailable"
            )) }
        ))
        unavailable.frame = .init(x: 0, y: 0, width: 500, height: 400)
        let unavailableWindow = NSWindow(contentRect: unavailable.frame, styleMask: [.titled], backing: .buffered, defer: false)
        unavailableWindow.title = "Phase 6C evidence unavailable"
        unavailableWindow.contentView = unavailable
        unavailableWindow.makeKeyAndOrderFront(nil)
        defer { unavailableWindow.close() }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(accessibilityText(AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier))
            .contains("Delivery evidence unavailable"))
    }

    func testPanelWithdrawsLateResultAfterTicketIdentityChanges() async throws {
        let notification = Notification.Name("phase6c-switch-ticket-\(UUID().uuidString)")
        let gate = DeliveryEvidenceLoadGate()
        let hosting = NSHostingView(rootView: DeliveryEvidenceSwitchHarness(notification: notification, gate: gate))
        hosting.frame = .init(x: 0, y: 0, width: 500, height: 700)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Phase 6C evidence identity switch"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        await gate.waitUntilOldLoadEntered()
        NotificationCenter.default.post(name: notification, object: nil)
        try await Task.sleep(for: .milliseconds(120))
        await gate.releaseOldLoad()
        try await Task.sleep(for: .milliseconds(160))

        let text = accessibilityText(AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier))
        XCTAssertTrue(text.contains("Ticket B current"))
        XCTAssertFalse(text.contains("Ticket A stale"))
    }

    fileprivate static var emptyEvidence: TicketDeliveryEvidence {
        .init(
            projectID: "project", ticketID: "ticket", phaseID: "phase", phaseLabel: "Phase",
            revision: 0, currentTargetVersion: nil, targets: [], observations: [], expectations: [],
            ownerAcceptance: .notAccepted
        )
    }

    nonisolated fileprivate static func evidence(ticketID: String, sourceLabel: String) -> TicketDeliveryEvidence {
        let repositoryID = "11111111-1111-1111-1111-111111111111"
        let revision = DeliveryEvidenceRevision(
            commitSHA: String(repeating: "a", count: 40),
            checkoutState: .dirty,
            dirtySnapshotID: "snapshot-a"
        )
        let target = DeliveryEvidenceTargetVersion(
            version: 2, repositoryID: repositoryID, rootID: "root", revision: revision,
            expectations: [
                .init(category: .build, scope: "unit"),
                .init(category: .installation, scope: nil),
                .init(category: .document, scope: nil),
            ],
            registrationID: "registration", requestGeneration: 1,
            recordedAt: "2026-09-10T17:00:00Z"
        )
        func resolved(
            id: String,
            fact: DeliveryEvidenceFact,
            outcome: DeliveryEvidenceOutcome,
            applicability: DeliveryEvidenceApplicability,
            currentSourceAvailability: DeliveryEvidenceSourceAvailability = .available,
            currentDocumentDigest: String? = nil
        ) -> DeliveryEvidenceResolvedObservation {
            .init(
                observation: .init(
                    id: id, targetVersion: 2, fact: fact,
                    source: .init(kind: .localObservation, label: sourceLabel),
                    sourceAvailability: .available, outcome: outcome,
                    observedAt: "2026-09-10T17:10:00Z", recordedAt: "2026-09-10T17:11:00Z"
                ),
                applicability: applicability,
                currentSourceAvailability: currentSourceAvailability,
                currentDocumentDigest: currentDocumentDigest
            )
        }
        return .init(
            projectID: "project", ticketID: ticketID, phaseID: "phase", phaseLabel: "Phase",
            revision: 5, currentTargetVersion: 2, targets: [target],
            observations: [
                resolved(
                    id: "build",
                    fact: .build(.init(repositoryID: repositoryID, revision: revision, buildID: "build-42", scope: "unit")),
                    outcome: .passed,
                    applicability: .init(state: .applicable, reasons: [])
                ),
                resolved(
                    id: "installation",
                    fact: .installation(.init(repositoryID: nil, revision: nil, installationID: nil, buildID: nil, context: "Local app")),
                    outcome: .unknown,
                    applicability: .init(state: .unknown, reasons: [.repositoryUnknown, .revisionUnknown, .installationIdentityUnknown])
                ),
                resolved(
                    id: "document",
                    fact: .document(.init(
                        repositoryID: repositoryID, revision: revision, artifactID: "plan",
                        contentDigest: String(repeating: "b", count: 64), catalogVersion: 1,
                        catalogDigest: String(repeating: "c", count: 64)
                    )),
                    outcome: .observed,
                    applicability: .init(state: .stale, reasons: [.documentContentChanged]),
                    currentDocumentDigest: String(repeating: "d", count: 64)
                ),
            ],
            expectations: [
                .init(expectation: .init(category: .build, scope: "unit"), status: .satisfied, observationID: "build"),
                .init(expectation: .init(category: .installation, scope: nil), status: .unknown, observationID: "installation"),
                .init(expectation: .init(category: .document, scope: nil), status: .satisfied, observationID: "document"),
            ],
            ownerAcceptance: .notAccepted
        )
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

    private func accessibilityWindow(title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        return windows.first { window in
            var titleValue: CFTypeRef?
            return AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success
                && titleValue as? String == title
        }
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var text: [String] = []
        var count = 0
        while let element = pending.popLast(), count < 2_000 {
            count += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   let value = value as? String { text.append(value) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return text.joined(separator: "\n")
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var count = 0
        while let element = pending.popLast(), count < 2_000 {
            count += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier { return element }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return nil
    }

}

private struct DeliveryEvidenceSwitchHarness: View {
    let notification: Notification.Name
    let gate: DeliveryEvidenceLoadGate
    @State private var ticketID = "ticket-a"

    var body: some View {
        let capturedTicketID = ticketID
        TicketDeliveryEvidenceSection(
            identity: "project:registration:\(capturedTicketID)",
            load: { await gate.load(ticketID: capturedTicketID) }
        )
        .id(capturedTicketID)
        .onReceive(NotificationCenter.default.publisher(for: notification)) { _ in ticketID = "ticket-b" }
    }
}

private actor DeliveryEvidenceLoadGate {
    private var oldLoadEntered = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func load(ticketID: String) async -> ReferenceLoadResult<TicketDeliveryEvidence> {
        if ticketID == "ticket-a" {
            oldLoadEntered = true
            entryWaiters.forEach { $0.resume() }
            entryWaiters.removeAll()
            await withCheckedContinuation { releaseContinuation = $0 }
            return .loaded(DeliveryEvidenceRenderingTests.evidence(ticketID: ticketID, sourceLabel: "Ticket A stale"))
        }
        return .loaded(DeliveryEvidenceRenderingTests.evidence(ticketID: ticketID, sourceLabel: "Ticket B current"))
    }

    func waitUntilOldLoadEntered() async {
        if oldLoadEntered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func releaseOldLoad() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
