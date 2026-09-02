import AppKit
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ProjectDocumentationRenderingTests: XCTestCase {
    // Native captures support manual layout review. They do not assert VoiceOver
    // behavior; the isolated host does not expose the SwiftUI accessibility tree.
    func testOverviewDocumentationStateAtWideAndCompactWidths() throws {
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
                try render(view, name: "overview-\(name)-\(Int(width))", width: width)
            }
        }
    }

    func testOnboardingDocumentationPreviewAtWideAndCompactWidths() throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-M2C-Rendering-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        print("M2C isolated rendering store: \(output.path)")
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
                let view = OnboardingView(
                    store: store,
                    onOpenExisting: { _ in },
                    pasteboardWriter: { _ in XCTFail("Rendering must not write to the clipboard"); return false },
                    initialPreview: preview,
                    onFinished: { _ in XCTFail("Rendering must not initialize a project") }
                )
                try render(view, name: "onboarding-\(name)-\(Int(width))", width: width)
            }
        }
    }

    private var states: [(String, ProjectDocumentationState)] {
        [
            ("legacy", .legacy(.current(version: 1))),
            ("staged", .stagedCatalog(hasAuditedHandoff: true, preview: .valid(version: 1, digest: "test-only"))),
            ("repair", .stagedCatalog(hasAuditedHandoff: false, preview: .invalid(.init(.malformedCatalog))))
        ]
    }

    private func render<V: View>(
        _ view: V,
        name: String,
        width: Double
    ) throws {
        let frame = NSRect(x: 30, y: 30, width: width, height: 850)
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
