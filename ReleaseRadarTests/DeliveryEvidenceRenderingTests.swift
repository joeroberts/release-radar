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
                    ticketID: .init(rawValue: "RR-6C"), contextIdentity: "project:registration", isContextReady: true,
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
            ticketID: .init(rawValue: "empty"), contextIdentity: "empty", isContextReady: true,
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
            ticketID: .init(rawValue: "unavailable"), contextIdentity: "unavailable", isContextReady: true,
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
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let notification = Notification.Name("phase6c-switch-ticket-\(UUID().uuidString)")
        let gate = DeliveryEvidenceLoadGate()
        let hosting = NSHostingView(rootView: DeliveryEvidenceSwitchHarness(notification: notification, gate: gate))
        hosting.frame = .init(x: 0, y: 0, width: 500, height: 700)
        let window = makeWindow(
            title: "Phase 6C evidence identity switch",
            content: hosting,
            width: 500,
            height: 700
        )
        defer {
            window.orderOut(nil)
            NSApp.setActivationPolicy(previousPolicy)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hosting.layoutSubtreeIfNeeded()

        await gate.waitUntilOldLoadEntered()
        NotificationCenter.default.post(name: notification, object: nil)
        try await Task.sleep(for: .milliseconds(120))
        await gate.releaseOldLoad()
        try await Task.sleep(for: .milliseconds(160))
        hosting.layoutSubtreeIfNeeded()

        let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        let text = accessibilityText(nativeWindow)
        XCTAssertTrue(text.contains("Ticket B current"))
        XCTAssertFalse(text.contains("Ticket A stale"))
    }

    func testDeliveryEvidenceRefreshRetainsContentAndFocusThroughFailureThenRetry() async throws {
        let nativeSession: (id: String, pauseSeconds: Double)?
        if let sessionID = ProcessInfo.processInfo.environment["RELEASE_RADAR_EVIDENCE_REFRESH_NATIVE_SESSION"] {
            guard !sessionID.isEmpty,
                  sessionID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
                XCTFail("The delivery evidence refresh native session must contain only letters, numbers, hyphens and underscores.")
                return
            }
            guard let pauseSeconds = ProcessInfo.processInfo.environment["RR_EVIDENCE_REFRESH_INSPECT_SECONDS"]
                .flatMap(Double.init), pauseSeconds > 0 else {
                XCTFail("The delivery evidence refresh native session requires a positive RR_EVIDENCE_REFRESH_INSPECT_SECONDS value.")
                return
            }
            nativeSession = (sessionID, min(pauseSeconds, 60))
        } else {
            nativeSession = nil
        }

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let gate = DeliveryEvidenceRefreshGate()
        let hosting = NSHostingView(rootView: TicketDeliveryEvidenceSection(
            ticketID: .init(rawValue: "ticket-refresh"),
            contextIdentity: "context-a",
            isContextReady: true,
            load: { await gate.load() }
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 780)
        let window = makeWindow(
            title: nativeSession.map { "Delivery evidence refresh retention — native session \($0.id)" }
                ?? "Delivery evidence refresh retention",
            content: hosting,
            width: 620,
            height: 780
        )
        defer {
            window.orderOut(nil)
            NSApp.setActivationPolicy(previousPolicy)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()

        if let nativeSession {
            func waitForStage(_ stage: String) async throws {
                let fileManager = FileManager.default
                let configurationPath = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]
                let configurationPresent = configurationPath != nil
                guard configurationPresent else {
                    XCTFail("The external delivery evidence journey requires the XCTest configuration environment key.")
                    throw NSError(domain: "DeliveryEvidenceRefreshNativeSession", code: 1)
                }
                let configurationNonempty = configurationPath?.isEmpty == false
                let configurationExists = configurationPath.map {
                    !$0.isEmpty && fileManager.fileExists(atPath: $0)
                } ?? false
                let controlDirectory = fileManager.temporaryDirectory
                    .appendingPathComponent("release-radar-evidence-refresh", isDirectory: true)
                    .appendingPathComponent("native-\(nativeSession.id)", isDirectory: true)
                try fileManager.createDirectory(at: controlDirectory, withIntermediateDirectories: true)
                let ready = controlDirectory.appendingPathComponent("\(stage)-ready")
                let complete = controlDirectory.appendingPathComponent("\(stage)-complete")
                XCTAssertFalse(fileManager.fileExists(atPath: ready.path))
                XCTAssertFalse(fileManager.fileExists(atPath: complete.path))
                let identity = "token=\(nativeSession.id)\nstage=\(stage)\npid=\(ProcessInfo.processInfo.processIdentifier)\nwindow=\(window.title)\nxctest_configuration_present=\(configurationPresent)\nxctest_configuration_nonempty=\(configurationNonempty)\nxctest_configuration_exists=\(configurationExists)\n"
                XCTAssertTrue(fileManager.createFile(atPath: ready.path, contents: Data(identity.utf8)))
                print("DELIVERY EVIDENCE REFRESH \(stage.uppercased()) READY: \(identity.replacingOccurrences(of: "\n", with: " "))")
                let attempts = max(1, Int((nativeSession.pauseSeconds * 5).rounded(.up)))
                for _ in 0..<attempts where !fileManager.fileExists(atPath: complete.path) {
                    try await Task.sleep(for: .milliseconds(200))
                }
                let completion = try String(contentsOf: complete, encoding: .utf8)
                XCTAssertEqual(completion.trimmingCharacters(in: .whitespacesAndNewlines), nativeSession.id)
            }

            try await waitForStage("initial")
            let refreshLoadCount = await gate.loadCount()
            guard refreshLoadCount == 2 else {
                XCTFail("Expected one external delivery evidence Refresh press; observed \(refreshLoadCount - 1).")
                return
            }

            try await waitForStage("pending")
            await gate.releaseRefreshFailure()
            try await Task.sleep(for: .milliseconds(120))

            try await waitForStage("failure")
            let retryLoadCount = await gate.loadCount()
            XCTAssertEqual(retryLoadCount, 3)
            return
        }

        let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        let help = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "delivery-evidence-help"))
        XCTAssertEqual(AXUIElementSetAttributeValue(help, kAXFocusedAttribute as CFString, kCFBooleanTrue), .success)
        let refresh = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "refresh-ticket-delivery-evidence"))
        XCTAssertEqual(AXUIElementPerformAction(refresh, kAXPressAction as CFString), .success)
        await gate.waitUntilRefreshEntered()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-refresh-progress"))
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Initial evidence"))

        await gate.releaseRefreshFailure()
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-previously-loaded"))
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Initial evidence"))
        var focused: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(help, kAXFocusedAttribute as CFString, &focused), .success)
        XCTAssertEqual((focused as? NSNumber)?.boolValue, true)

        let retry = try XCTUnwrap(accessibilityElement(nativeWindow, title: "Retry"))
        XCTAssertEqual(AXUIElementPerformAction(retry, kAXPressAction as CFString), .success)
        try await Task.sleep(for: .milliseconds(150))
        let retryLoadCount = await gate.loadCount()
        XCTAssertEqual(retryLoadCount, 3)
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Retry evidence"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-previously-loaded"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-refresh-progress"))
    }

    func testDeliveryEvidenceUnavailableReadinessDoesNotLoadUntilExplicitRefresh() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let gate = DeliveryEvidenceUnavailableGate()
        let hosting = NSHostingView(rootView: TicketDeliveryEvidenceSection(
            ticketID: .init(rawValue: "ticket-unavailable"),
            contextIdentity: "project:registration:missing-root",
            isContextReady: false,
            load: { await gate.load() }
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 780)
        let window = makeWindow(
            title: "Delivery evidence unavailable readiness",
            content: hosting,
            width: 620,
            height: 780
        )
        defer {
            window.orderOut(nil)
            NSApp.setActivationPolicy(previousPolicy)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()

        let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-unavailable"))
        let unavailableText = accessibilityText(nativeWindow)
        XCTAssertTrue(unavailableText.localizedCaseInsensitiveContains("root"))
        XCTAssertFalse(unavailableText.contains("Loading delivery evidence"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-refresh-progress"))
        let initialLoadCount = await gate.loadCount()
        XCTAssertEqual(initialLoadCount, 0)

        let refresh = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "refresh-ticket-delivery-evidence"))
        XCTAssertEqual(AXUIElementPerformAction(refresh, kAXPressAction as CFString), .success)
        await gate.waitUntilEntered()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-refresh-progress"))

        await gate.releaseFailure()
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "delivery-evidence-explicit-unavailable"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-refresh-progress"))
        let finalLoadCount = await gate.loadCount()
        XCTAssertEqual(finalLoadCount, 1)
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
        func matches(_ element: AXUIElement) -> Bool {
            var titleValue: CFTypeRef?
            return AXUIElementCopyAttributeValue(
                element, kAXTitleAttribute as CFString, &titleValue
            ) == .success && titleValue as? String == title
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

    private func accessibilityElement(_ root: AXUIElement, title: String) -> AXUIElement? {
        var pending = [root]
        var count = 0
        while let element = pending.popLast(), count < 2_000 {
            count += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   value as? String == title { return element }
            }
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
            ticketID: .init(rawValue: capturedTicketID), contextIdentity: "project:registration", isContextReady: true,
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

private actor DeliveryEvidenceRefreshGate {
    private var count = 0
    private var refreshEntered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?

    func load() async -> ReferenceLoadResult<TicketDeliveryEvidence> {
        count += 1
        if count == 2 {
            refreshEntered = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
            await withCheckedContinuation { release = $0 }
            return .failed(.init(
                title: "Delivery evidence refresh failed", detail: "Retry the current ticket.",
                systemImage: "exclamationmark.triangle", tone: .warning,
                accessibilityID: "delivery-evidence-refresh-failed"
            ))
        }
        return .loaded(DeliveryEvidenceRenderingTests.evidence(
            ticketID: "ticket-refresh",
            sourceLabel: count == 1 ? "Initial evidence" : "Retry evidence"
        ))
    }

    func waitUntilRefreshEntered() async {
        if refreshEntered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func releaseRefreshFailure() { release?.resume(); release = nil }
    func loadCount() -> Int { count }
}

private actor DeliveryEvidenceUnavailableGate {
    private var count = 0
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?

    func load() async -> ReferenceLoadResult<TicketDeliveryEvidence> {
        count += 1
        entered = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
        await withCheckedContinuation { release = $0 }
        return .failed(.init(
            title: "Delivery evidence unavailable",
            detail: "Restore the exact project root and retry.",
            systemImage: "questionmark.folder",
            tone: .warning,
            accessibilityID: "delivery-evidence-explicit-unavailable"
        ))
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func releaseFailure() { release?.resume(); release = nil }
    func loadCount() -> Int { count }
}
