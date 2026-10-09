import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class TicketReferenceNativeRenderingTests: XCTestCase {
    func testTicketDetailKeepsDrawerSectionsStableWhenOnlyObservationGenerationChanges() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let notification = Notification.Name("ticket-drawer-observer-generation-\(UUID().uuidString)")
        let counter = TicketDrawerLoadCounter()
        let hosting = NSHostingView(rootView: TicketDrawerContextReloadHarness(
            notification: notification,
            counter: counter
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 760)
        let window = makeWindow(
            title: "Ticket drawer observation generation stability",
            content: hosting,
            width: 620,
            height: 760
        )
        defer {
            window.orderOut(nil)
            NSApp.setActivationPolicy(previousPolicy)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hosting.layoutSubtreeIfNeeded()

        try await Task.sleep(for: .milliseconds(180))
        hosting.layoutSubtreeIfNeeded()
        let initialCounts = await counter.counts()
        XCTAssertEqual(initialCounts.references, 1)
        XCTAssertEqual(initialCounts.evidence, 1)

        NotificationCenter.default.post(name: notification, object: nil)
        try await Task.sleep(for: .milliseconds(180))

        // #120 regression: a completed selected-ticket load must not restart when
        // only observation generation changes inside the same structural context.
        let observerChangedCounts = await counter.counts()
        XCTAssertEqual(observerChangedCounts.references, 1)
        XCTAssertEqual(observerChangedCounts.evidence, 1)
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

    func testReferenceRoutesRetainExactIdentityAndFocusInHistory() {
        let projectID = ProjectID(rawValue: "project")
        let ticketID = TicketID(rawValue: "RR-5B")
        let source = AppRoute.referenceSource(
            projectID: projectID,
            ticketID: ticketID,
            linkID: "requirement-main",
            version: 2
        )
        let impacts = AppRoute.recordedImpacts(
            projectID: projectID,
            repositoryID: "repository",
            artifactID: "requirements"
        )

        XCTAssertEqual(source.projectID, projectID)
        XCTAssertEqual(source.title, "Reference source")
        XCTAssertEqual(impacts.projectID, projectID)
        XCTAssertEqual(impacts.title, "Recorded impacts")

        var history = NavigationHistory(initial: .projectPlan(projectID))
        history.navigate(to: source, selectedTicketID: ticketID, focus: .referenceSource(linkID: "requirement-main", version: 2))
        let exactImpactFocus = NavigationFocus.recordedImpact(rowID: "RR-5B:requirement-main:2")
        history.navigate(to: impacts, selectedTicketID: ticketID, focus: exactImpactFocus)
        XCTAssertTrue(history.goBack())
        XCTAssertEqual(history.current.route, source)
        XCTAssertEqual(history.current.focus, .referenceSource(linkID: "requirement-main", version: 2))
        XCTAssertTrue(history.goForward())
        XCTAssertEqual(history.current.route, impacts)
        XCTAssertEqual(history.current.focus, exactImpactFocus)
    }

    func testProjectRoutesAreNotPresentedWhileTheirDocumentationObservationIsChecking() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-reference-route-ordering-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let payload = DocumentationObservationPayload(
            identity: .init(
                projectID: projectID,
                registration: nil,
                rootID: .init(rawValue: "root"),
                rootPath: directory.path,
                binding: nil
            ),
            checkedAt: Date(),
            documentationState: .legacy(.unavailable),
            evidence: []
        )
        let gate = ReferenceObservationGate()
        let observer = DocumentationObservationCoordinator { _ in
            await gate.load(payload)
        }
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            documentationObserver: observer
        )
        await model.loadDashboard()
        await model.navigate(to: .projectPlan(projectID))
        await gate.armNextLoad()

        let navigation = Task {
            await model.openReferenceSource(
                projectID: projectID,
                ticketID: .init(rawValue: "VD2-08"),
                linkID: "requirement-main",
                version: 1
            )
        }
        await gate.waitUntilPaused()
        let checkingReferenceIdentity = model.referenceQueryIdentity(projectID: projectID)
        XCTAssertEqual(model.selection, .projectPlan(projectID))
        await gate.resume()
        await navigation.value
        let observedReferenceIdentity = model.referenceQueryIdentity(projectID: projectID)
        XCTAssertNotEqual(checkingReferenceIdentity, observedReferenceIdentity)
        XCTAssertEqual(
            model.selection,
            .referenceSource(
                projectID: projectID,
                ticketID: .init(rawValue: "VD2-08"),
                linkID: "requirement-main",
                version: 1
            )
        )
        XCTAssertEqual(model.navigationFocus, .referenceSource(linkID: "requirement-main", version: 1))

        await model.goBack()
        XCTAssertEqual(model.selection, .projectPlan(projectID))
        await gate.armNextLoad()
        let boardNavigation = Task { await model.navigate(to: .phaseBoard(projectID)) }
        await gate.waitUntilPaused()
        XCTAssertEqual(model.selection, .projectPlan(projectID))
        await gate.resume()
        await boardNavigation.value
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
    }

    func testSourceAndRecordedImpactsRenderAtWideAndCompactWidths() async throws {
        let version = TicketReferenceVersion(
            version: 2,
            contentDigest: String(repeating: "a", count: 64),
            sourceLocalID: "REQ-5B",
            locator: "Reference behavior",
            catalogVersion: 4,
            catalogDigest: String(repeating: "b", count: 64),
            observedPath: "docs/requirements.md",
            observedLifecycle: .active,
            observedAuthority: .controlling,
            createdAt: "2026-09-09T12:00:00Z",
            resolution: .init(
                facts: [.changed, .moved],
                currentPath: "docs/current-requirements.md",
                currentDigest: String(repeating: "c", count: 64),
                currentLifecycle: .active,
                currentAuthority: .controlling
            ),
            historicalPreview: "The exact historical source content.",
            previewIsTruncated: false
        )
        let link = TicketReference(
            id: "requirement-main",
            kind: .requirement,
            repositoryID: "repository",
            artifactID: "requirements",
            currentVersion: 2,
            relationship: .current,
            retiredVersion: nil,
            retiredAt: nil,
            retirementReason: nil,
            versions: [version],
            resolution: .init(
                facts: [.changed, .moved],
                currentPath: "docs/current-requirements.md",
                currentDigest: String(repeating: "c", count: 64),
                currentLifecycle: .active,
                currentAuthority: .controlling
            )
        )
        let impacts = RecordedImpacts(
            title: "Recorded impacts",
            projectID: "project",
            repositoryID: "repository",
            artifactID: "requirements",
            rows: [
                .init(ticketID: "RR-5B", phaseID: "phase", phaseLabel: "Delivery", linkID: link.id,
                      kind: .requirement, sourceLocalID: "REQ-5B",
                      contentDigest: String(repeating: "a", count: 64), version: 2, isCurrent: true),
                .init(ticketID: "RR-OLD", phaseID: nil, phaseLabel: "Not placed", linkID: link.id,
                      kind: .requirement, sourceLocalID: "REQ-5B",
                      contentDigest: String(repeating: "d", count: 64), version: 1, isCurrent: false),
            ]
        )

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: .init(x: 30, y: 30, width: 1_180, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5B references — isolated native acceptance"
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }

        for width in [1_180.0, 620.0] {
            var sourceFocus: NavigationFocus?
            let sourceHost = NSHostingView(rootView: TicketReferenceSourceView(
                ticketID: .init(rawValue: "RR-5B"), link: link, selectedVersion: version,
                requestedFocus: .referenceSource(linkID: link.id, version: version.version),
                focusChanged: { sourceFocus = $0 }, openRecordedImpacts: {}
            ).environment(\.colorScheme, .dark))
            sourceHost.frame = .init(x: 0, y: 0, width: width, height: 760)
            window.contentView = sourceHost
            window.setContentSize(.init(width: width, height: 760))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .milliseconds(150))
            sourceHost.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.isVisible)
            XCTAssertGreaterThan(sourceHost.fittingSize.height, 0)
            XCTAssertEqual(sourceFocus, .referenceSource(linkID: link.id, version: version.version))
            try capture(sourceHost, name: "phase5b-reference-source-\(Int(width))")

            var impactsFocus: NavigationFocus?
            let impactsHost = NSHostingView(rootView: RecordedImpactsView(
                impacts: impacts, requestedFocus: .recordedImpacts,
                focusChanged: { impactsFocus = $0 }, openTicket: { _ in }
            ).environment(\.colorScheme, .dark))
            impactsHost.frame = .init(x: 0, y: 0, width: width, height: 760)
            window.contentView = impactsHost
            window.setContentSize(.init(width: width, height: 760))
            try await Task.sleep(for: .milliseconds(150))
            impactsHost.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(impactsHost.fittingSize.height, 0)
            XCTAssertEqual(impactsFocus, .recordedImpact(rowID: impacts.rows[0].id))
            try capture(impactsHost, name: "phase5b-recorded-impacts-\(Int(width))")
        }
    }

    func testRecordedImpactTicketJourneyRestoresImpactAndTicketFocus() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-reference-navigation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let model = AppModel(store: store, externalServicesSuppressed: true)
        await model.loadDashboard()
        let projectID = DashboardSampleData.projectID
        let ticketID = TicketID(rawValue: "VD2-08")

        await model.openRecordedImpacts(
            projectID: projectID,
            repositoryID: "repository",
            artifactID: "requirements"
        )
        let impact = RecordedImpact(
            ticketID: ticketID.rawValue,
            phaseID: "phase",
            phaseLabel: "Phase",
            linkID: "requirement-main",
            kind: .requirement,
            sourceLocalID: "REQ-5B",
            contentDigest: String(repeating: "a", count: 64),
            version: 1,
            isCurrent: false
        )
        await model.openRecordedImpactTicket(projectID: projectID, impact: impact)
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertEqual(model.navigationFocus, .ticket(ticketID))

        await model.goBack()
        XCTAssertEqual(
            model.selection,
            .recordedImpacts(projectID: projectID, repositoryID: "repository", artifactID: "requirements")
        )
        XCTAssertEqual(model.navigationFocus, .recordedImpact(rowID: impact.id))
        await model.goForward()
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertEqual(model.navigationFocus, .ticket(ticketID))
    }

    func testRecordedImpactsRestoresExactNonFirstVersionForDuplicateTicket() async throws {
        let current = RecordedImpact(
            ticketID: "RR-DUPLICATE", phaseID: "phase", phaseLabel: "Phase",
            linkID: "requirement-main", kind: .requirement, sourceLocalID: "REQ-5B",
            contentDigest: String(repeating: "a", count: 64), version: 2, isCurrent: true
        )
        let historical = RecordedImpact(
            ticketID: "RR-DUPLICATE", phaseID: "phase", phaseLabel: "Phase",
            linkID: "requirement-main", kind: .requirement, sourceLocalID: "REQ-5B",
            contentDigest: String(repeating: "b", count: 64), version: 1, isCurrent: false
        )
        let impacts = RecordedImpacts(
            title: "Recorded impacts", projectID: "project", repositoryID: "repository",
            artifactID: "requirements", rows: [current, historical]
        )
        var restoredFocus: NavigationFocus?
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let hosting = NSHostingView(rootView: RecordedImpactsView(
            impacts: impacts,
            requestedFocus: .recordedImpact(rowID: historical.id),
            focusChanged: { restoredFocus = $0 },
            openTicket: { _ in }
        ))
        hosting.frame = .init(x: 0, y: 0, width: 700, height: 700)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Phase 5B exact recorded-impact focus"
        window.isReleasedWhenClosed = false
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(restoredFocus, .recordedImpact(rowID: historical.id))
        XCTAssertNotEqual(current.id, historical.id)
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        XCTAssertNotNil(accessibilityElement(application, identifier: "recorded-impact-\(current.id)"))
        XCTAssertNotNil(accessibilityElement(application, identifier: "recorded-impact-\(historical.id)"))
    }

    func testTicketReferenceSectionWithdrawsLateResultWhenTicketChangesInPlace() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let notification = Notification.Name("phase5b-switch-ticket-\(UUID().uuidString)")
        let gate = TicketReferenceSectionLoadGate()
        let hosting = NSHostingView(rootView: TicketReferenceSectionSwitchHarness(
            notification: notification,
            gate: gate
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 700)
        let window = makeWindow(
            title: "Phase 5B reference identity switch",
            content: hosting,
            width: 620,
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
        try await Task.sleep(for: .milliseconds(150))
        await gate.releaseOldLoad()
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()

        let nativeWindow = try XCTUnwrap(accessibilityWindow(title: window.title))
        let text = accessibilityText(nativeWindow)
        XCTAssertTrue(text.contains("Ticket B current"))
        XCTAssertTrue(text.contains("REQ-B"))
        XCTAssertFalse(text.contains("Ticket A stale"))
        XCTAssertFalse(text.contains("REQ-A"))
    }

    func testMountedTicketReferencesReloadWhenObservationBecomesReadyInSameGeneration() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let notification = Notification.Name("phase5b-observation-ready-\(UUID().uuidString)")
        let counter = TicketDrawerReadinessCounter()
        let hosting = NSHostingView(rootView: TicketDrawerReadinessHarness(
            notification: notification,
            counter: counter
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 700)
        let window = makeWindow(
            title: "Phase 5B reference readiness transition",
            content: hosting,
            width: 620,
            height: 700
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
        let checkingText = accessibilityText(nativeWindow)
        XCTAssertTrue(checkingText.localizedCaseInsensitiveContains("checking"))
        XCTAssertFalse(checkingText.contains("Loading reference links"))
        XCTAssertFalse(checkingText.contains("Loading delivery evidence"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-delivery-evidence-refresh-progress"))
        let initialCounts = await counter.counts()
        XCTAssertEqual(initialCounts.references, 0)
        XCTAssertEqual(initialCounts.evidence, 0)

        NotificationCenter.default.post(name: notification, object: nil)
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()

        let recoveredText = accessibilityText(nativeWindow)
        XCTAssertTrue(recoveredText.contains("Ticket ready"))
        XCTAssertTrue(recoveredText.contains("REQ-READY"))
        XCTAssertTrue(recoveredText.contains("No revision-bound delivery evidence recorded"))
        XCTAssertFalse(recoveredText.localizedCaseInsensitiveContains("checking"))
        let readyCounts = await counter.counts()
        XCTAssertEqual(readyCounts.references, 1)
        XCTAssertEqual(readyCounts.evidence, 1)
    }

    func testReferenceUnavailableReadinessDoesNotLoadUntilExplicitRefresh() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let gate = TicketReferenceUnavailableGate()
        let hosting = NSHostingView(rootView: TicketReferencesSection(
            ticketID: .init(rawValue: "ticket-unavailable"),
            contextIdentity: "project:registration:missing-root",
            isContextReady: false,
            load: { await gate.load() },
            openSource: { _, _ in }
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 700)
        let window = makeWindow(
            title: "Reference unavailable readiness",
            content: hosting,
            width: 620,
            height: 700
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
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-references-unavailable"))
        let unavailableText = accessibilityText(nativeWindow)
        XCTAssertTrue(unavailableText.localizedCaseInsensitiveContains("root"))
        XCTAssertFalse(unavailableText.contains("Loading reference links"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))
        let initialLoadCount = await gate.loadCount()
        XCTAssertEqual(initialLoadCount, 0)

        let refresh = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "refresh-ticket-references"))
        XCTAssertEqual(AXUIElementPerformAction(refresh, kAXPressAction as CFString), .success)
        await gate.waitUntilEntered()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))

        await gate.releaseFailure()
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "reference-explicit-unavailable"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))
        let finalLoadCount = await gate.loadCount()
        XCTAssertEqual(finalLoadCount, 1)
    }

    func testReferenceRefreshRetainsContentAndFocusThroughFailureThenRetry() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let gate = TicketReferenceRefreshGate()
        let hosting = NSHostingView(rootView: TicketReferencesSection(
            ticketID: .init(rawValue: "ticket-refresh"),
            contextIdentity: "context-a",
            isContextReady: true,
            load: { await gate.load() },
            openSource: { _, _ in }
        ))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 700)
        let window = makeWindow(
            title: "Reference refresh retention",
            content: hosting,
            width: 620,
            height: 700
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
        let source = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "reference-source-link-ticket-refresh-1"))
        XCTAssertEqual(AXUIElementSetAttributeValue(source, kAXFocusedAttribute as CFString, kCFBooleanTrue), .success)
        let refresh = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "refresh-ticket-references"))
        XCTAssertEqual(AXUIElementPerformAction(refresh, kAXPressAction as CFString), .success)
        await gate.waitUntilRefreshEntered()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Initial references"))

        await gate.releaseRefreshFailure()
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertNotNil(accessibilityElement(nativeWindow, identifier: "ticket-references-previously-loaded"))
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Initial references"))
        var focused: CFTypeRef?
        XCTAssertEqual(AXUIElementCopyAttributeValue(source, kAXFocusedAttribute as CFString, &focused), .success)
        XCTAssertEqual((focused as? NSNumber)?.boolValue, true)

        let retry = try XCTUnwrap(accessibilityElement(nativeWindow, title: "Retry"))
        XCTAssertEqual(AXUIElementPerformAction(retry, kAXPressAction as CFString), .success)
        try await Task.sleep(for: .milliseconds(150))
        let retryLoadCount = await gate.loadCount()
        XCTAssertEqual(retryLoadCount, 3)
        XCTAssertTrue(accessibilityText(nativeWindow).contains("Retry references"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-references-previously-loaded"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))
    }

    func testReferenceContextChangeClearsContentAndRejectsLateRefresh() async throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let notification = Notification.Name("reference-context-change-\(UUID().uuidString)")
        let gate = TicketReferenceContextGate()
        let hosting = NSHostingView(rootView: TicketReferenceContextHarness(notification: notification, gate: gate))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 700)
        let window = makeWindow(
            title: "Reference context change",
            content: hosting,
            width: 620,
            height: 700
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
        let refresh = try XCTUnwrap(accessibilityElement(nativeWindow, identifier: "refresh-ticket-references"))
        XCTAssertEqual(AXUIElementPerformAction(refresh, kAXPressAction as CFString), .success)
        await gate.waitUntilRefreshEntered()
        NotificationCenter.default.post(name: notification, object: nil)
        try await Task.sleep(for: .milliseconds(80))
        await gate.releaseLateResult()
        try await Task.sleep(for: .milliseconds(120))

        let text = accessibilityText(nativeWindow)
        XCTAssertTrue(text.contains("Reference context changed"))
        XCTAssertFalse(text.contains("Late old-context references"))
        XCTAssertNil(accessibilityElement(nativeWindow, identifier: "ticket-references-refresh-progress"))
        let contextLoadCount = await gate.loadCount()
        XCTAssertEqual(contextLoadCount, 2)
    }

    func testLiveReferenceJourneyUsesNativeControlsAndRestoresFocus() async throws {
        let enableMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5b-live-journey-01a087a0-v5-enabled")
        guard FileManager.default.fileExists(atPath: enableMarker.path) else {
            throw XCTSkip("Create the one-shot Phase 5B interaction marker to run this isolated native journey.")
        }
        let completionMarker = URL(fileURLWithPath: "/private/tmp/release-radar-phase5b-live-journey-01a087a0-v5-complete")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-reference-interaction-\(UUID().uuidString)")
        let root = directory.appendingPathComponent("repository")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent("AGENTS.md"))
        let bookmarkData = try ProjectBookmarkStore().makeBookmark(for: root)

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed native reference journey") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('p', 'Reference journey')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('p', 'reference-registration', 1, 'complete')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)",
                bindings: [.text(root.path), .blob(bookmarkData)]
            )
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase', 'p', 'Delivery')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('p', 'phase')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('placed', 'p', 'phase', 'Placed ticket', 'backlog')")
            try connection.execute("INSERT INTO tickets (id, project_id, outcome) VALUES ('unassigned', 'p', 'Unassigned ticket')")
        }
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "p"),
            registrationID: "reference-registration",
            requestGeneration: 1
        )
        let bookmarks = ProjectBookmarkStore(
            resolver: { _ in .init(url: root, isStale: false) },
            startAccessing: { _ in true },
            stopAccessing: { _ in }
        )
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: root, authorizedRoots: [root]),
            ]),
            bookmarkStore: bookmarks
        )
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let target = DocumentationTarget(
            projectID: "p",
            rootID: "root",
            repositoryID: snapshot.catalog.repositoryID.lowercased(),
            catalogVersion: snapshot.version,
            catalogDigest: snapshot.digest
        )
        func envelope(_ command: AgentCommand) -> AgentCommandEnvelope {
            .init(
                version: 1,
                requestID: UUID(),
                projectRoot: root.path,
                reason: "Prepare isolated native reference journey",
                command: command
            )
        }
        let bound = await dispatcher.dispatch(envelope(.bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)
        for (ticketID, linkID) in [("placed", "placed-reference"), ("unassigned", "unassigned-reference")] {
            let result = await dispatcher.dispatch(envelope(.upsertTicketReference(
                target: target,
                ticketID: ticketID,
                linkID: linkID,
                kind: .requirement,
                artifactID: "current",
                sourceLocalID: "REQ-5B",
                locator: "Native journey",
                expectedContentDigest: documentationDigest(
                    try Data(contentsOf: root.appendingPathComponent("docs/plans/current.md"))
                ),
                expectedLinkSetRevision: 0
            )))
            XCTAssertNil(result.error)
        }
        let revisedPlaced = await dispatcher.dispatch(envelope(.upsertTicketReference(
            target: target,
            ticketID: "placed",
            linkID: "placed-reference",
            kind: .requirement,
            artifactID: "current",
            sourceLocalID: "REQ-5B",
            locator: "Native journey current version",
            expectedContentDigest: documentationDigest(
                try Data(contentsOf: root.appendingPathComponent("docs/plans/current.md"))
            ),
            expectedLinkSetRevision: 1
        )))
        XCTAssertNil(revisedPlaced.error)

        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
        let model = AppModel(
            store: store,
            projectOnboarding: onboarding,
            externalServicesSuppressed: true
        )
        await model.loadDashboard()
        await model.navigate(to: .projectPlan(.init(rawValue: "p")))
        model.selectTicket(.init(rawValue: "unassigned"))

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: .init(x: 30, y: 30, width: 1_500, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Phase 5B references — isolated native interaction"
        let hosting = NSHostingView(rootView: SidebarView(model: model).environment(\.colorScheme, .dark))
        hosting.frame = .init(x: 0, y: 0, width: 1_500, height: 900)
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
        print("PHASE5B INTERACTION READY: select unassigned reference source, Recorded impacts, placed ticket, Back, and Forward")

        for _ in 0..<900 where !FileManager.default.fileExists(atPath: completionMarker.path) {
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: completionMarker.path))
        XCTAssertEqual(model.selection, .phaseBoard(.init(rawValue: "p")))
        XCTAssertEqual(model.selectedTicketID, .init(rawValue: "placed"))
        XCTAssertEqual(model.navigationFocus, .ticket(.init(rawValue: "placed")))
        XCTAssertTrue(model.canNavigateBack)
        try capture(hosting, name: "phase5b-reference-live-journey-final")
    }

    func testUnavailableEmptyAndIncompleteReferenceStatesRenderHonestly() async throws {
        let unavailableVersion = TicketReferenceVersion(
            version: 1,
            contentDigest: String(repeating: "a", count: 64),
            sourceLocalID: nil,
            locator: "Historical requirement",
            catalogVersion: 1,
            catalogDigest: String(repeating: "b", count: 64),
            observedPath: "docs/requirements.md",
            observedLifecycle: .active,
            observedAuthority: .controlling,
            createdAt: "2026-09-09T12:00:00Z",
            resolution: .init(
                facts: [.unavailable, .unchecked], currentPath: nil, currentDigest: nil,
                currentLifecycle: nil, currentAuthority: nil
            ),
            historicalPreview: nil,
            previewIsTruncated: false
        )
        let unavailableLink = TicketReference(
            id: "requirement-history",
            kind: .requirement,
            repositoryID: "repository",
            artifactID: "requirements",
            currentVersion: 1,
            relationship: .current,
            retiredVersion: nil,
            retiredAt: nil,
            retirementReason: nil,
            versions: [unavailableVersion],
            resolution: .init(
                facts: [.unavailable, .unchecked],
                currentPath: nil,
                currentDigest: nil,
                currentLifecycle: nil,
                currentAuthority: nil
            )
        )
        let emptySet = TicketReferenceSet(
            projectID: "project",
            ticketID: "RR-MISSING",
            phaseID: nil,
            phaseLabel: "Not placed",
            linkSetRevision: 0,
            links: []
        )
        let emptyImpacts = RecordedImpacts(
            title: "Recorded impacts",
            projectID: "project",
            repositoryID: "repository",
            artifactID: "requirements",
            rows: []
        )
        let failure = FailureStatePresentation(
            title: "Recorded impacts unavailable",
            detail: "The exact project-scoped query could not be completed. No broader scope was substituted.",
            systemImage: "exclamationmark.triangle",
            tone: .warning,
            accessibilityID: "recorded-impacts-unavailable"
        )

        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: .init(x: 30, y: 30, width: 620, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        defer {
            window.close()
            NSApp.setActivationPolicy(previousPolicy)
        }

        try await renderState(
            TicketReferenceSourceView(
                ticketID: .init(rawValue: "RR-HISTORY"),
                link: unavailableLink,
                selectedVersion: unavailableVersion,
                openRecordedImpacts: {}
            ),
            in: window,
            name: "phase5b-reference-source-unavailable"
        )
        try await renderState(
            RecordedImpactsView(impacts: emptyImpacts, openTicket: { _ in }),
            in: window,
            name: "phase5b-recorded-impacts-empty"
        )
        try await renderState(
            TicketReferenceSourceRouteView(
                identity: "project:root:registration",
                ticketID: .init(rawValue: "RR-MISSING"),
                linkID: "missing-link",
                version: 1,
                requestedFocus: nil,
                focusChanged: { _ in },
                load: { .loaded(emptySet) },
                openRecordedImpacts: { _, _ in }
            ),
            in: window,
            name: "phase5b-reference-source-incomplete"
        )
        try await renderState(
            RecordedImpactsRouteView(
                identity: "project:repository:requirements",
                requestedFocus: nil,
                focusChanged: { _ in },
                load: { .failed(failure) },
                openTicket: { _ in }
            ),
            in: window,
            name: "phase5b-recorded-impacts-error"
        )
    }

    private func renderState<V: View>(
        _ view: V,
        in window: NSWindow,
        name: String
    ) async throws {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        hosting.frame = .init(x: 0, y: 0, width: 620, height: 760)
        window.contentView = hosting
        window.setContentSize(.init(width: 620, height: 760))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(hosting.bounds.width, 620, accuracy: 1)
        XCTAssertEqual(hosting.bounds.height, 760, accuracy: 1)
        XCTAssertGreaterThan(hosting.fittingSize.height, 0)
        try capture(hosting, name: name)
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

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var text: [String] = []
        var count = 0
        while let element = pending.popLast(), count < 1_000 {
            count += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   let value = value as? String {
                    text.append(value)
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return text.joined(separator: "\n")
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var count = 0
        while let element = pending.popLast(), count < 1_000 {
            count += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
               value as? String == identifier {
                return element
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] {
                pending.append(contentsOf: children)
            }
        }
        return nil
    }

    private func accessibilityElement(_ root: AXUIElement, title: String) -> AXUIElement? {
        var pending = [root]
        var count = 0
        while let element = pending.popLast(), count < 1_000 {
            count += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success,
               value as? String == title { return element }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return nil
    }
}

private struct TicketDrawerContextReloadHarness: View {
    let notification: Notification.Name
    let counter: TicketDrawerLoadCounter
    @State private var observationGeneration = 1

    var body: some View {
        let _ = observationGeneration
        TicketDetailView(
            detail: .init(
                id: .init(rawValue: "RR-DRAWER"),
                outcome: "Keep the selected ticket stable",
                goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
                requires: [], unlocks: [], ownerAttention: [], evidence: [],
                auditHistory: [], notificationHistory: []
            ),
            loadReferences: { await counter.loadReferences() },
            loadDeliveryEvidence: { await counter.loadEvidence() },
            openReferenceSource: { _, _ in },
            referenceQueryContextIdentity: "service:registration:root:binding",
            isReferenceQueryReady: true
        )
        .onReceive(NotificationCenter.default.publisher(for: notification)) { _ in
            observationGeneration += 1
        }
    }
}

private actor TicketDrawerLoadCounter {
    private var referenceLoads = 0
    private var evidenceLoads = 0

    func loadReferences() -> ReferenceLoadResult<TicketReferenceSet> {
        referenceLoads += 1
        return .loaded(.init(
            projectID: "project", ticketID: "RR-DRAWER", phaseID: nil,
            phaseLabel: "Drawer phase", linkSetRevision: 1, links: []
        ))
    }

    func loadEvidence() -> ReferenceLoadResult<TicketDeliveryEvidence> {
        evidenceLoads += 1
        return .loaded(.init(
            projectID: "project", ticketID: "RR-DRAWER", phaseID: nil,
            phaseLabel: "Drawer phase", revision: 1, currentTargetVersion: nil,
            targets: [], observations: [], expectations: [], ownerAcceptance: .notAccepted
        ))
    }

    func counts() -> (references: Int, evidence: Int) {
        (referenceLoads, evidenceLoads)
    }
}

private actor TicketReferenceRefreshGate {
    private var count = 0
    private var refreshEntered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?

    func load() async -> ReferenceLoadResult<TicketReferenceSet> {
        count += 1
        if count == 2 {
            refreshEntered = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
            await withCheckedContinuation { release = $0 }
            return .failed(Self.failure)
        }
        return .loaded(TicketReferenceSectionLoadGate.referenceSet(
            ticketID: "ticket-refresh",
            phaseLabel: count == 1 ? "Initial references" : "Retry references",
            sourceLocalID: count == 1 ? "REQ-INITIAL" : "REQ-RETRY"
        ))
    }

    func waitUntilRefreshEntered() async {
        if refreshEntered { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func releaseRefreshFailure() { release?.resume(); release = nil }
    func loadCount() -> Int { count }

    private static let failure = FailureStatePresentation(
        title: "Reference refresh failed", detail: "Retry the current ticket.",
        systemImage: "exclamationmark.triangle", tone: .warning,
        accessibilityID: "reference-refresh-failed"
    )
}

private struct TicketReferenceContextHarness: View {
    let notification: Notification.Name
    let gate: TicketReferenceContextGate
    @State private var contextIdentity = "context-a"

    var body: some View {
        TicketReferencesSection(
            ticketID: .init(rawValue: "ticket-context"), contextIdentity: contextIdentity,
            isContextReady: true, load: { await gate.load() }, openSource: { _, _ in }
        )
        .onReceive(NotificationCenter.default.publisher(for: notification)) { _ in contextIdentity = "context-b" }
    }
}

private actor TicketReferenceContextGate {
    private var count = 0
    private var refreshEntered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?

    func load() async -> ReferenceLoadResult<TicketReferenceSet> {
        count += 1
        if count == 2 {
            refreshEntered = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
            await withCheckedContinuation { release = $0 }
            return .loaded(TicketReferenceSectionLoadGate.referenceSet(
                ticketID: "ticket-context", phaseLabel: "Late old-context references", sourceLocalID: "REQ-LATE"
            ))
        }
        return .loaded(TicketReferenceSectionLoadGate.referenceSet(
            ticketID: "ticket-context", phaseLabel: "Current references", sourceLocalID: "REQ-CURRENT"
        ))
    }

    func waitUntilRefreshEntered() async {
        if refreshEntered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func releaseLateResult() { release?.resume(); release = nil }
    func loadCount() -> Int { count }
}

private struct TicketReferenceSectionSwitchHarness: View {
    let notification: Notification.Name
    let gate: TicketReferenceSectionLoadGate
    @State private var ticketID = "ticket-a"

    var body: some View {
        let capturedTicketID = ticketID
        TicketReferencesSection(
            ticketID: .init(rawValue: capturedTicketID), contextIdentity: "project:registration:root", isContextReady: true,
            load: { await gate.load(ticketID: capturedTicketID) },
            openSource: { _, _ in }
        )
        .id(capturedTicketID)
        .onReceive(NotificationCenter.default.publisher(for: notification)) { _ in
            ticketID = "ticket-b"
        }
    }
}

private struct TicketDrawerReadinessHarness: View {
    let notification: Notification.Name
    let counter: TicketDrawerReadinessCounter
    @State private var isReady = false

    var body: some View {
        let capturedIsReady = isReady
        TicketDetailView(
            detail: .init(
                id: .init(rawValue: "ticket-ready"),
                outcome: "Keep deferred drawer loading stable",
                goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
                requires: [], unlocks: [], ownerAttention: [], evidence: [],
                auditHistory: [], notificationHistory: []
            ),
            documentationStatus: capturedIsReady ? nil : .checking(identity: nil, generation: 1),
            loadReferences: { await counter.loadReferences() },
            loadDeliveryEvidence: { await counter.loadEvidence() },
            openReferenceSource: { _, _ in },
            referenceQueryContextIdentity: "project:service-1",
            isReferenceQueryReady: capturedIsReady
        )
        .onReceive(NotificationCenter.default.publisher(for: notification)) { _ in
            isReady = true
        }
    }
}

private actor TicketDrawerReadinessCounter {
    private var referenceLoads = 0
    private var evidenceLoads = 0

    func loadReferences() -> ReferenceLoadResult<TicketReferenceSet> {
        referenceLoads += 1
        return .loaded(TicketReferenceSectionLoadGate.referenceSet(
            ticketID: "ticket-ready",
            phaseLabel: "Ticket ready",
            sourceLocalID: "REQ-READY"
        ))
    }

    func loadEvidence() -> ReferenceLoadResult<TicketDeliveryEvidence> {
        evidenceLoads += 1
        return .loaded(.init(
            projectID: "project", ticketID: "ticket-ready", phaseID: nil,
            phaseLabel: "Ticket ready", revision: 1, currentTargetVersion: nil,
            targets: [], observations: [], expectations: [], ownerAcceptance: .notAccepted
        ))
    }

    func counts() -> (references: Int, evidence: Int) {
        (referenceLoads, evidenceLoads)
    }
}

private actor TicketReferenceUnavailableGate {
    private var count = 0
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?

    func load() async -> ReferenceLoadResult<TicketReferenceSet> {
        count += 1
        entered = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
        await withCheckedContinuation { release = $0 }
        return .failed(.init(
            title: "Reference query unavailable",
            detail: "Restore the exact project root and retry.",
            systemImage: "questionmark.folder",
            tone: .warning,
            accessibilityID: "reference-explicit-unavailable"
        ))
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func releaseFailure() { release?.resume(); release = nil }
    func loadCount() -> Int { count }
}

private actor TicketReferenceSectionLoadGate {
    private var oldLoadEntered = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func load(ticketID: String) async -> ReferenceLoadResult<TicketReferenceSet> {
        if ticketID == "ticket-a" {
            oldLoadEntered = true
            entryWaiters.forEach { $0.resume() }
            entryWaiters.removeAll()
            await withCheckedContinuation { releaseContinuation = $0 }
            return .loaded(Self.referenceSet(
                ticketID: ticketID,
                phaseLabel: "Ticket A stale",
                sourceLocalID: "REQ-A"
            ))
        }
        return .loaded(Self.referenceSet(
            ticketID: ticketID,
            phaseLabel: "Ticket B current",
            sourceLocalID: "REQ-B"
        ))
    }

    func waitUntilOldLoadEntered() async {
        if oldLoadEntered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func releaseOldLoad() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    fileprivate static func referenceSet(
        ticketID: String,
        phaseLabel: String,
        sourceLocalID: String
    ) -> TicketReferenceSet {
        let resolution = TicketReferenceResolution(
            facts: [], currentPath: "docs/current.md",
            currentDigest: String(repeating: "a", count: 64),
            currentLifecycle: .active, currentAuthority: .controlling
        )
        let version = TicketReferenceVersion(
            version: 1, contentDigest: String(repeating: "a", count: 64),
            sourceLocalID: sourceLocalID, locator: nil, catalogVersion: 1,
            catalogDigest: String(repeating: "b", count: 64), observedPath: "docs/current.md",
            observedLifecycle: .active, observedAuthority: .controlling,
            createdAt: "2026-09-09T12:00:00Z", resolution: resolution,
            historicalPreview: "Current", previewIsTruncated: false
        )
        return .init(
            projectID: "project", ticketID: ticketID, phaseID: nil,
            phaseLabel: phaseLabel, linkSetRevision: 1,
            links: [.init(
                id: "link-\(ticketID)", kind: .requirement, repositoryID: "repository",
                artifactID: "requirements", currentVersion: 1, relationship: .current,
                retiredVersion: nil, retiredAt: nil, retirementReason: nil,
                versions: [version], resolution: resolution
            )]
        )
    }
}

private actor ReferenceObservationGate {
    private var shouldPauseNextLoad = false
    private var isPaused = false
    private var pauseWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    func armNextLoad() {
        shouldPauseNextLoad = true
    }

    func load(_ payload: DocumentationObservationPayload) async -> DocumentationObservationPayload {
        guard shouldPauseNextLoad else { return payload }
        shouldPauseNextLoad = false
        isPaused = true
        let waiters = pauseWaiters
        pauseWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        await withCheckedContinuation { resumeContinuation = $0 }
        isPaused = false
        return payload
    }

    func waitUntilPaused() async {
        guard !isPaused else { return }
        await withCheckedContinuation { pauseWaiters.append($0) }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}
