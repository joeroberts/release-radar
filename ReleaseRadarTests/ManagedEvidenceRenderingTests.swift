import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ManagedEvidenceRenderingTests: XCTestCase {
    func testEvidenceStatesAtWideAndCompactWidths() async throws {
        let cases: [(String, RepositoryDocumentArtifact.Lifecycle?, RepositoryDocumentArtifact.Authority?, ManagedDocumentResolutionFailure?)] = [
            ("proposed", .proposed, .supporting, nil), ("current", .active, .controlling, nil),
            ("completed", .completed, .nonAuthoritative, nil), ("superseded", .superseded, .nonAuthoritative, nil),
            ("archived", .archived, .nonAuthoritative, nil), ("missing", .active, .supporting, .missingDocument),
            ("pending", nil, nil, .catalogUnaccepted), ("unbound", nil, nil, .rootNotBound),
            ("checksum", .active, .supporting, .checksumInvalid)
        ]
        let rows = cases.map { name, lifecycle, authority, failure in
            EvidenceProjection(EvidenceReadback(evidence: .init(id: .init(rawValue: name), projectID: .init(rawValue: "p"), ticketID: nil,
                locator: .managedDocument(artifactID: name), isAvailable: true),
                managedDocument: .init(artifactID: name, resolvedPath: lifecycle == nil ? nil : "docs/plans/\(name).md", label: name.capitalized,
                    lifecycle: lifecycle, authority: authority, authorityRole: authority == .controlling ? "delivery-plan" : nil, failure: failure)))
        }
        for width in [1100.0, 620.0] {
            try await render(VStack(alignment: .leading, spacing: 12) {
                Text("Evidence").font(.largeTitle.weight(.semibold))
                ForEach(rows) { row in EvidenceDetailView(evidence: row); Divider() }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading), name: "m3c-evidence-\(Int(width))", width: width, height: 1350)
        }
    }

    func testOwnerPreparationConfirmationRecoveryAndNativeLayout() async throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("M3C-UI-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("original"), next = directory.appendingPathComponent("relocated")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        try FileManager.default.copyItem(at: root, to: next)
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let database = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: database)
        try await store.transact(actor: .init(id: "fixture"), reason: "UI fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Documentation Project')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(root.path), .blob(Data(root.path.utf8))])
            try c.execute("INSERT INTO project_documentation_bindings VALUES ('p', 'root', ?, 1, ?, ?)", bindings: [.text(snapshot.catalog.repositoryID), .text(snapshot.digest), .blob(snapshot.canonicalCatalog)])
            try c.execute("INSERT INTO evidence (id, project_id, artifact_id) VALUES ('draft', 'p', 'draft')")
        }
        let model = RepositoryRecoveryModel(store: store, projectID: .init(rawValue: "p"), allowsRelocation: true, bookmarkStore: RelocationBookmarks())
        await model.load()
        let appModel = AppModel(store: store,
            projectOnboarding: FolderProjectOnboarding(store: store, bookmarkStore: RelocationBookmarks()),
            dashboardLoader: { try await DashboardProjection.load(from: $0, bookmarkStore: RelocationBookmarks()) },
            externalServicesSuppressed: true)
        appModel.dashboard = try await DashboardProjection.load(from: store, bookmarkStore: RelocationBookmarks())
        appModel.selection = .projectOverview(.init(rawValue: "p"))
        await appModel.repositoryRecovery(for: .init(rawValue: "p")).load()
        try await render(SidebarView(model: appModel), name: "m3c-phase-less-overview", width: 1100, height: 1100)
        await model.prepare(folder: next)
        XCTAssertNotNil(model.prepared)
        XCTAssertFalse(model.recoveryTokenText.contains(next.path))
        for width in [1100.0, 620.0] {
            try await render(RepositoryRecoveryView(model: model).padding(28), name: "m3c-confirmation-\(Int(width))", width: width, height: 950)
        }
        let token = model.recoveryTokenText
        // Cache the unavailable old folder before the owner confirms its relocation.
        try FileManager.default.removeItem(at: root)
        await appModel.loadDashboard()
        XCTAssertEqual(appModel.projectRoot(for: .init(rawValue: "p"))?.path, root.path)
        let oldDocumentation = appModel.projectDocumentationState(for: .init(rawValue: "p"))
        let committed = await model.confirm()
        XCTAssertTrue(committed)
        XCTAssertEqual(model.savedRoot, next.path)
        let auditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        await appModel.reloadAfterRepositoryRelocation()
        XCTAssertEqual(appModel.projectRoot(for: .init(rawValue: "p"))?.path, next.path, "Post-relocation refresh retained the revoked root")
        XCTAssertNotEqual(appModel.projectDocumentationState(for: .init(rawValue: "p")), oldDocumentation, "Post-relocation refresh retained unavailable guidance")
        guard case .managed(hasAuditedHandoff: false, catalogVersion: 1, catalogDigest: snapshot.digest) = appModel.projectDocumentationState(for: .init(rawValue: "p")) else { return XCTFail("Relocated project must use its exact accepted binding") }
        XCTAssertEqual(appModel.selection, .projectOverview(.init(rawValue: "p")))
        let refreshedAuditCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(refreshedAuditCount, auditCount)
        let restarted = RepositoryRecoveryModel(store: DeliveryStore(databaseURL: database), projectID: .init(rawValue: "p"), allowsRelocation: true, bookmarkStore: RelocationBookmarks())
        restarted.recoveryTokenText = token
        await restarted.recoverReceipt()
        XCTAssertEqual(restarted.savedRoot, next.path)
        XCTAssertEqual(restarted.message, "The exact relocation committed. The saved repository binding is shown above.")
        let session = try DocumentationMaintenanceSession(databaseURL: database, mode: .readOnly)
        await session.load()
        XCTAssertEqual(session.projects.count, 1)
        XCTAssertEqual(session.recovery?.allowsRelocation, false)
        XCTAssertNotNil(session.recovery?.binding)
        XCTAssertEqual(session.recovery?.evidence.count, 1)
        try await render(DocumentationMaintenanceView(session: session), name: "m3c-maintenance-read-only", width: 900, height: 850)
        XCTAssertNotNil(session.recovery?.binding)
        XCTAssertEqual(session.recovery?.evidence.count, 1)
        try await store.transact(actor: .init(id: "fixture"), reason: "Invalid binding fixture") { c in
            try c.execute("UPDATE project_documentation_bindings SET accepted_catalog = ? WHERE project_id = 'p'", bindings: [.blob(Data("{}".utf8))])
        }
        await model.load()
        XCTAssertFalse(model.evidence.first!.isAvailable, "Invalid binding must replace prior available readback")
        XCTAssertEqual(model.evidence.first?.managedDocument?.failure, .bindingMismatch)
    }

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root], text: [String] = [], count = 0
        while let element = pending.popLast(), count < 1000 {
            count += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value = value as? String { text.append(value) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success, let children = children as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return text.joined(separator: "\n")
    }

    private func render<V: View>(_ view: V, name: String, width: Double, height: Double) async throws {
        let frame = NSRect(x: 30, y: 30, width: width, height: height)
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = name
        let priorActivationPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        window.isReleasedWhenClosed = false; window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        defer { window.close(); NSApp.setActivationPolicy(priorActivationPolicy) }
        hosting.layoutSubtreeIfNeeded()
        // Yield the main actor so the view's existing async load tasks settle.
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
        if let seconds = ProcessInfo.processInfo.environment["RR_TASK7A_INSPECT_SECONDS"].flatMap(Double.init), seconds > 0 {
            print("Task 7A external inspection: \(name), \(Int(width))×\(Int(height)), PID \(ProcessInfo.processInfo.processIdentifier)")
            try await Task.sleep(for: .seconds(min(seconds, 60)))
        }
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
        let childCount = hosting.accessibilityChildren()?.count ?? 0
        let windows = value as? [AXUIElement] ?? []
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
        var ownWindow = windows.first(where: matchesTestWindow)
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
        let axText = ownWindow.map { accessibilityText($0) } ?? ""
        XCTAssertEqual(status, .success, "Isolated host accessibility API unavailable")
        XCTAssertNotNil(ownWindow, "Own titled test window not found in AX")
        if name.hasPrefix("m3c-evidence") {
            for label in ["Proposed", "Current", "Completed", "Superseded", "Archived", "Non-controlling", "Available", "pending acceptance", "not bound", "checksum"] {
                XCTAssertTrue(axText.contains(label), "Missing actual AX state: \(label)")
            }
        } else if name == "m3c-maintenance-read-only" {
            XCTAssertTrue(axText.contains("Accepted repository"))
            XCTAssertTrue(axText.contains("Artifact ID: draft"))
            XCTAssertTrue(axText.contains("Folder relocation is disabled"))
            XCTAssertFalse(axText.contains("No evidence recorded"))
            XCTAssertFalse(axText.contains("Select relocated repository"))
            XCTAssertFalse(axText.contains("Confirm relocation"))
        } else if name == "m3c-phase-less-overview" {
            XCTAssertTrue(axText.contains("Repository folder"), "Phase-less project lost folder recovery")
            XCTAssertTrue(axText.contains("Artifact ID: draft"), "Phase-less project lost evidence readback")
        } else if name.hasPrefix("m3c-confirmation") {
            XCTAssertTrue(axText.contains("Confirm relocation"))
            XCTAssertTrue(axText.contains("Cancel"))
            XCTAssertTrue(axText.contains("Accepted catalog"))
        }
        print("M3C isolated render PID \(ProcessInfo.processInfo.processIdentifier): AX status \(status.rawValue), native hosting children \(childCount), capture \(name)")
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
