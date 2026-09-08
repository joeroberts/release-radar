import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
import ReleaseRadarCore

@MainActor
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verify: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
        verify(error)
    }
}

final class DocumentationObservationTests: XCTestCase {
    @MainActor
    func testFolderAccessPanelSelectsOneExistingFolderWithoutRelocationControls() {
        let panel = ProjectFolderAccessPanel.make()
        XCTAssertFalse(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canCreateDirectories)
        XCTAssertFalse(panel.resolvesAliases)
        XCTAssertEqual(panel.prompt, "Restore Access")
    }

    @MainActor
    func testSignedNativeFolderPickerOpensFromDocumentationErrorViaAX() async throws {
        guard let expectedPath = ProcessInfo.processInfo.environment["PHASE3A_SIGNED_PICKER_FOLDER"] else {
            throw XCTSkip("Run only for the signed Phase 3A native picker verification.")
        }
        let expectedRoot = URL(fileURLWithPath: expectedPath, isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        let database = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-Phase3A-SignedPicker-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: database) }
        let store = DeliveryStore(databaseURL: database)
        let projectID = ProjectID(rawValue: "phase3a-native-picker")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "phase3a-native-picker-registration",
            requestGeneration: 1
        )
        let rootID = ProjectRootID(rawValue: "phase3a-native-picker-root")
        try await store.transact(actor: .init(id: "fixture"), reason: "Native picker fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Native Picker')", bindings: [.text(projectID.rawValue)])
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation) VALUES (?, ?, ?)",
                bindings: [.text(projectID.rawValue), .text(registration.registrationID), .integer(registration.requestGeneration)]
            )
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                bindings: [.text(rootID.rawValue), .text(projectID.rawValue), .text(expectedRoot.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 1)",
                bindings: [.text(projectID.rawValue), .text(expectedRoot.path), .blob(Data([0]))]
            )
        }
        let beforeAuditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let identity = DocumentationObservationIdentity(
            projectID: projectID,
            registration: registration,
            rootID: rootID,
            rootPath: expectedRoot.path,
            binding: nil
        )
        let unavailable = ProjectDocumentationState.managedUnavailable(
            hasAuditedHandoff: true,
            reason: .rootUnavailable,
            validationError: nil
        )
        let project = ProjectDashboardProjection(
            id: projectID,
            name: "Native Folder Recovery",
            registration: registration,
            activePhaseName: "Current delivery",
            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
            currentWorkCount: 1,
            attentionCount: 1
        )
        let recoveryResult = NativeFolderAccessResult()
        let view = ProjectOverviewView(
            project: project,
            board: nil,
            documentationState: unavailable,
            documentationStatus: .observed(
                .init(
                    identity: identity,
                    generation: 1,
                    checkedAt: Date(),
                    documentationState: unavailable,
                    evidence: []
                )
            ),
            projectRoot: expectedRoot,
            phaseSelectionStatus: .idle,
            openBoard: {},
            selectActivePhase: { _ in },
            reloadActivePhase: {},
            reauthorizeActivePhase: { _ in },
            reauthorizeProjectHealth: { _, _ in
                XCTFail("Cancelling the native picker must not invoke folder renewal.")
                throw CancellationError()
            },
            documentationFolderChooser: {
                let panel = ProjectFolderAccessPanel.make()
                panel.directoryURL = expectedRoot
                recoveryResult.panel = panel
                panel.begin { response in
                    recoveryResult.panelResponse = response
                }
                return nil
            }
        )
        let frame = NSRect(x: 40, y: 40, width: 720, height: 820)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Phase 3A Signed Folder Recovery"
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        let priorActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            window.close()
            NSApp.setActivationPolicy(priorActivationPolicy)
        }
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(300))

        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        let ownWindow = try XCTUnwrap(accessibilityWindow(application, title: window.title))
        let button = try XCTUnwrap(
            accessibilityButton(ownWindow, title: "Restore folder access"),
            "The documentation recovery action must be exposed as an accessibility button."
        )
        FileHandle.standardOutput.write(
            Data("Phase3A native picker ready, PID \(ProcessInfo.processInfo.processIdentifier)\n".utf8)
        )
        XCTAssertEqual(AXUIElementPerformAction(button, kAXPressAction as CFString), .success)
        for _ in 0..<20 where recoveryResult.panel?.isVisible != true {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(recoveryResult.panel?.isVisible == true)
        recoveryResult.panel?.cancel(nil)
        for _ in 0..<20 where recoveryResult.panelResponse == nil {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(recoveryResult.panelResponse, .cancel)
        let result = try await store.read { connection in
            (
                try connection.scalarInt("SELECT is_stale FROM project_bookmarks WHERE project_id = ?", bindings: [.text(projectID.rawValue)]),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarText("SELECT reason FROM audit_events ORDER BY rowid DESC LIMIT 1")
            )
        }
        XCTAssertEqual(result.0, 1)
        XCTAssertEqual(result.1, beforeAuditCount)
        XCTAssertEqual(result.2, "Native picker fixture")
    }

    @MainActor
    func testSharedObservationRefreshesManagedGuidanceAndEvidenceWithoutPersistenceWrites() async throws {
        let root = try managedFixture()
        let database = root.deletingLastPathComponent()
            .appendingPathComponent("ReleaseRadar-ObservationDB-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: database) }
        let store = DeliveryStore(databaseURL: database)
        let projectID = ProjectID(rawValue: "freshness-project")
        let rootID = ProjectRootID(rawValue: "freshness-root")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "freshness-registration",
            requestGeneration: 4
        )
        let binding = try ProjectDocumentationBinding(
            projectID: projectID,
            rootID: rootID,
            acceptedSnapshot: RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Observation fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Freshness')", bindings: [.text(projectID.rawValue)])
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation) VALUES (?, ?, ?)",
                bindings: [.text(projectID.rawValue), .text(registration.registrationID), .integer(registration.requestGeneration)]
            )
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                bindings: [.text(rootID.rawValue), .text(projectID.rawValue), .text(root.path)]
            )
            try connection.execute(
                "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
                bindings: [.text(projectID.rawValue), .text(root.path), .blob(Data(root.path.utf8))]
            )
            try connection.execute(
                "INSERT INTO project_documentation_bindings VALUES (?, ?, ?, ?, ?, ?)",
                bindings: [.text(projectID.rawValue), .text(rootID.rawValue), .text(binding.repositoryID), .integer(Int64(binding.acceptedCatalogVersion)), .text(binding.acceptedCatalogDigest), .blob(binding.acceptedCatalog)]
            )
            try connection.execute(
                "INSERT INTO evidence (id, project_id, artifact_id, is_available) VALUES ('managed-evidence', ?, 'evidence', 0)",
                bindings: [.text(projectID.rawValue)]
            )
        }
        let bookmarks = ObservationBookmarkStore(root: root)
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
        let auditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }

        let current = try await onboarding.inspectProjectDocumentation(projectID: projectID)
        XCTAssertEqual(current.registration, registration)
        XCTAssertEqual(current.rootID, rootID)
        XCTAssertEqual(current.rootPath, root.path)
        XCTAssertEqual(current.binding, binding)
        XCTAssertEqual(current.documentationState, .managed(hasAuditedHandoff: false, catalogVersion: 1, catalogDigest: binding.acceptedCatalogDigest))
        XCTAssertTrue(try XCTUnwrap(current.evidence.first?.managedDocument).isAvailable)

        let evidenceFile = root.appendingPathComponent("docs/plans/evidence.md")
        let original = try Data(contentsOf: evidenceFile)
        try Data("changed outside Release Radar".utf8).write(to: evidenceFile)
        let invalid = try await onboarding.inspectProjectDocumentation(projectID: projectID)
        guard case .managedUnavailable(_, .catalogInvalid, .checksumMismatch) = invalid.documentationState else {
            return XCTFail("External invalidation must withdraw current documentation")
        }
        XCTAssertEqual(invalid.evidence.first?.managedDocument?.failure, .checksumInvalid)

        let target = ProjectRootAuthorizationTarget(
            registration: registration,
            rootID: rootID,
            rootPath: root.path,
            binding: binding
        )
        await XCTAssertThrowsErrorAsync(
            try await onboarding.reauthorizeProjectRoot(
                root.appendingPathComponent("different"),
                target: target
            )
        ) { XCTAssertEqual($0 as? ProjectAuthorizationError, .projectRootMismatch) }
        try await onboarding.reauthorizeProjectRoot(root, target: target)
        let renewedInvalid = try await onboarding.inspectProjectDocumentation(projectID: projectID)
        XCTAssertEqual(renewedInvalid.registration, invalid.registration)
        XCTAssertEqual(renewedInvalid.rootID, invalid.rootID)
        XCTAssertEqual(renewedInvalid.binding, invalid.binding)
        guard case .managedUnavailable(_, .catalogInvalid, .checksumMismatch) = renewedInvalid.documentationState else {
            return XCTFail("Folder renewal must not accept or repair an invalid catalog")
        }

        try original.write(to: evidenceFile)
        let repaired = try await onboarding.inspectProjectDocumentation(projectID: projectID)
        guard case .managed = repaired.documentationState else {
            return XCTFail("A repaired accepted catalog must recover automatically")
        }
        XCTAssertTrue(try XCTUnwrap(repaired.evidence.first?.managedDocument).isAvailable)
        let accessCount = await bookmarks.accessCount
        let releaseCount = await bookmarks.releaseCount
        XCTAssertEqual(accessCount, 5)
        XCTAssertEqual(releaseCount, 5)
        let finalAuditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let storedAvailability = try await store.read {
            try $0.scalarInt("SELECT is_available FROM evidence WHERE id = 'managed-evidence'")
        }
        XCTAssertEqual(finalAuditCount, auditCount.map { $0 + 1 })
        XCTAssertEqual(storedAvailability, 0)

        let appModel = AppModel(
            store: store,
            projectOnboarding: onboarding,
            externalServicesSuppressed: true
        )
        await appModel.loadDashboard()
        let initialFailure = appModel.dashboard?.projects.first?.evidence.first?.managedDocument?.failure
        XCTAssertNil(initialFailure)
        try Data("changed while the app is open".utf8).write(to: evidenceFile)
        await appModel.recheckDocumentationAfterActivation()
        let activatedState = appModel.projectDocumentationState(for: projectID)
        guard case .managedUnavailable(_, .catalogInvalid, .checksumMismatch) = activatedState else {
            return XCTFail("Activation must replace the shared Overview observation")
        }
        let activatedFailure = appModel.dashboard?.projects.first?.evidence.first?.managedDocument?.failure
        XCTAssertEqual(activatedFailure, .checksumInvalid)
        let health = await appModel.projectHealth(for: projectID)
        XCTAssertTrue(health.checks.contains { $0.id == "documentation" && $0.state == .attention })
        let healthObservationTime = appModel.documentationObservationStatus(for: projectID)?.observation?.checkedAt
        XCTAssertEqual(health.checkedAt, healthObservationTime)

        try original.write(to: evidenceFile)
        appModel.startDocumentationMonitoring()
        let recovered = await waitUntil {
            guard case .managed = appModel.projectDocumentationState(for: projectID) else { return false }
            return appModel.dashboard?.projects.first?.evidence.first?.managedDocument?.isAvailable == true
        }
        appModel.stopDocumentationMonitoring()
        XCTAssertTrue(recovered, "The active monitor must recover after an external repair")

        try await store.transact(actor: .init(id: "fixture"), reason: "Replace registration") { connection in
            try connection.execute(
                "UPDATE project_registrations SET request_generation = request_generation + 1 WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
        await XCTAssertThrowsErrorAsync(
            try await onboarding.reauthorizeProjectRoot(root, target: target)
        ) {
            guard case .stale = $0 as? ProjectRootManagementError else {
                return XCTFail("A replaced registration must reject the captured picker target")
            }
        }
    }

    @MainActor
    func testConcurrentRefreshesCoalesceAndWithdrawCurrentStatusWhileChecking() async throws {
        let projectID = ProjectID(rawValue: "freshness-project")
        let gate = DocumentationObservationGate()
        let coordinator = DocumentationObservationCoordinator { requestedProjectID in
            await gate.load(projectID: requestedProjectID)
        }

        let first = Task { await coordinator.refresh(projectID: projectID) }
        await gate.waitUntilEntered()

        guard case let .checking(identity, generation) = coordinator.status(for: projectID) else {
            return XCTFail("Refreshing must immediately withdraw a prior current result")
        }
        XCTAssertNil(identity)
        XCTAssertEqual(generation, 1)

        let second = Task { await coordinator.refresh(projectID: projectID) }
        await Task.yield()
        let callsWhileChecking = await gate.callCount
        XCTAssertEqual(callsWhileChecking, 1)

        await gate.release(with: .fixture(projectID: projectID))
        let firstObservation = await first.value
        let secondObservation = await second.value

        XCTAssertEqual(firstObservation, secondObservation)
        XCTAssertEqual(firstObservation?.generation, 1)
        let finalCallCount = await gate.callCount
        XCTAssertEqual(finalCallCount, 1)
        XCTAssertEqual(coordinator.status(for: projectID), firstObservation.map(DocumentationObservationStatus.observed))
    }

    @MainActor
    func testInvalidationRejectsOlderResultAndRemovalStopsPublication() async throws {
        let projectID = ProjectID(rawValue: "freshness-project")
        let gate = SequencedDocumentationObservationGate()
        let coordinator = DocumentationObservationCoordinator { requestedProjectID in
            await gate.load(projectID: requestedProjectID)
        }

        let first = Task { await coordinator.refresh(projectID: projectID) }
        await gate.waitUntilCallCount(1)
        coordinator.invalidate(projectID: projectID)

        let second = Task { await coordinator.refresh(projectID: projectID) }
        await gate.waitUntilCallCount(2)
        await gate.release(call: 2, with: .fixture(projectID: projectID, checkedAt: 2))
        let current = await second.value

        await gate.release(call: 1, with: .fixture(projectID: projectID, checkedAt: 1))
        let stale = await first.value
        XCTAssertNil(stale)
        XCTAssertEqual(current?.generation, 2)
        XCTAssertEqual(current?.checkedAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(coordinator.status(for: projectID), current.map(DocumentationObservationStatus.observed))

        coordinator.remove(projectID: projectID)
        XCTAssertNil(coordinator.status(for: projectID))
    }
}

private extension DocumentationObservationStatus {
    var observation: ProjectDocumentationObservation? {
        if case let .observed(value) = self { value } else { nil }
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(3),
    condition: () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return condition()
}

private actor ObservationBookmarkStore: ProjectBookmarkStoring {
    private let root: URL
    private(set) var accessCount = 0
    private(set) var releaseCount = 0

    init(root: URL) { self.root = root }

    nonisolated func makeBookmark(for folder: URL) throws -> Data { Data(folder.path.utf8) }
    nonisolated func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { .init(url: root, isStale: false) }
    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        accessCount += 1
        defer { releaseCount += 1 }
        return try await body(.init(url: root, isStale: false))
    }
}

private extension DocumentationObservationTests {
    func managedFixture() throws -> URL {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        let testFixtures = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".release-radar-observation-tests", isDirectory: true)
        try FileManager.default.createDirectory(at: testFixtures, withIntermediateDirectories: true)
        let root = testFixtures
            .appendingPathComponent("ReleaseRadar-Observation-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent("AGENTS.md"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
}

@MainActor
private final class NativeFolderAccessResult {
    var panel: NSOpenPanel?
    var panelResponse: NSApplication.ModalResponse?
}

private func accessibilityWindow(_ application: AXUIElement, title: String) -> AXUIElement? {
    func matches(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success
            && value as? String == title
    }

    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
       let window = (value as? [AXUIElement])?.first(where: matches) {
        return window
    }
    for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
        guard AXUIElementCopyAttributeValue(application, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
        let window = value as! AXUIElement
        if matches(window) { return window }
    }
    return nil
}

private func accessibilityButton(_ root: AXUIElement, title: String) -> AXUIElement? {
    var pending = [root]
    var visited = 0
    while let element = pending.popLast(), visited < 1_000 {
        visited += 1
        var role: CFTypeRef?
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           role as? String == kAXButtonRole {
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   (value as? String)?.contains(title) == true {
                    return element
                }
            }
        }
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
           let children = value as? [AXUIElement] {
            pending.append(contentsOf: children)
        }
    }
    return nil
}

private actor DocumentationObservationGate {
    private var calls = 0
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var loadContinuation: CheckedContinuation<DocumentationObservationPayload, Never>?

    var callCount: Int { calls }

    func load(projectID: ProjectID) async -> DocumentationObservationPayload {
        calls += 1
        enteredContinuation?.resume()
        enteredContinuation = nil
        return await withCheckedContinuation { loadContinuation = $0 }
    }

    func waitUntilEntered() async {
        if calls > 0 { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release(with payload: DocumentationObservationPayload) {
        loadContinuation?.resume(returning: payload)
        loadContinuation = nil
    }
}

private actor SequencedDocumentationObservationGate {
    private var calls = 0
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var loads: [Int: CheckedContinuation<DocumentationObservationPayload, Never>] = [:]

    func load(projectID: ProjectID) async -> DocumentationObservationPayload {
        calls += 1
        let call = calls
        let ready = waiters.filter { calls >= $0.count }
        waiters.removeAll { calls >= $0.count }
        ready.forEach { $0.continuation.resume() }
        return await withCheckedContinuation { loads[call] = $0 }
    }

    func waitUntilCallCount(_ count: Int) async {
        if calls >= count { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func release(call: Int, with payload: DocumentationObservationPayload) {
        loads.removeValue(forKey: call)?.resume(returning: payload)
    }
}

private extension DocumentationObservationPayload {
    static func fixture(projectID: ProjectID, checkedAt: TimeInterval = 1_700_000_000) -> Self {
        .init(
            identity: .init(
                projectID: projectID,
                registration: .init(projectID: projectID, registrationID: "registration", requestGeneration: 3),
                rootID: .init(rawValue: "root"),
                rootPath: "/synthetic/freshness",
                binding: nil
            ),
            checkedAt: Date(timeIntervalSince1970: checkedAt),
            documentationState: .managed(
                hasAuditedHandoff: true,
                catalogVersion: 1,
                catalogDigest: String(repeating: "a", count: 64)
            ),
            evidence: []
        )
    }
}
