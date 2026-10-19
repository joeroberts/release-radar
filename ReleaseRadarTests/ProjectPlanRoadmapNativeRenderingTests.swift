import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

@MainActor
final class ProjectPlanRoadmapNativeRenderingTests: XCTestCase {
    func testRoadmapShowsLifecycleAndReadinessAtWideAndCompactWidths() async throws {
        let fixture = RoadmapFixture.populated

        for width in [1_500.0, 760.0] {
            let window = try await host(
                ProjectPlanView(
                    plan: fixture.plan,
                    selectedTicketID: .constant(.init(rawValue: "")),
                    openAllPhases: {},
                    openPhase: { _ in },
                    openRepositoryPlanReconstruction: {}
                ),
                width: width,
                title: "Project Plan roadmap semantics \(Int(width))"
            )
            defer { window.close() }

            let text = accessibilityText(window)
            for expected in [
                "Current delivery",
                "In delivery",
                "Draft",
                "Needs goal",
                "Prepare from repository",
            ] {
                XCTAssertTrue(text.contains(expected), "Roadmap must expose \(expected) at \(Int(width))pt")
            }
            XCTAssertNotNil(accessibilityElement(window, identifier: "project-plan"))
            XCTAssertNotNil(accessibilityElement(window, identifier: "prepare-repository-plan"))
            XCTAssertNotNil(accessibilityElement(window, identifier: "open-all-phase-board"))
        }
    }

    func testRoadmapEmptyStateIsDistinctFromProgressAndKeepsPreparationAction() async throws {
        let fixture = RoadmapFixture.empty
        let window = try await host(
            ProjectPlanView(
                plan: fixture.plan,
                selectedTicketID: .constant(.init(rawValue: "")),
                openAllPhases: {},
                openPhase: { _ in },
                openRepositoryPlanReconstruction: {}
            ),
            width: 760,
            title: "Project Plan roadmap empty"
        )
        defer { window.close() }

        let text = accessibilityText(window)
        XCTAssertTrue(text.contains("No phases yet"))
        XCTAssertTrue(text.contains("Prepare from repository"))
        XCTAssertFalse(text.contains("0 of 0 tickets delivered"))
        XCTAssertNotNil(accessibilityElement(window, identifier: "prepare-repository-plan"))
    }

    // Current ProjectPlanPhaseProjection has ticketCount but no delivered-or-accepted count,
    // so delivery-progress assertions wait for the #193 projection handoff. Selection, compact
    // Back/focus/scroll restoration, ticket drill-in, refresh recovery, #192 assignment, and
    // #193 finalization likewise need their integrated public contracts.

    private func host<V: View>(
        _ view: V,
        width: CGFloat,
        title: String
    ) async throws -> AXUIElement {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = title
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(150))
        hosting.layoutSubtreeIfNeeded()
        return try XCTUnwrap(accessibilityWindow(title: title))
    }

    private func accessibilityWindow(title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windows) == .success,
              let candidates = windows as? [AXUIElement] else { return nil }
        return candidates.first { element in
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success
                && (value as? String) == title
        }
    }

    private func accessibilityElement(_ root: AXUIElement, identifier: String) -> AXUIElement? {
        var pending = [root]
        var inspected = 0
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            var identifierValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifierValue) == .success,
               (identifierValue as? String) == identifier {
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

    private func accessibilityText(_ root: AXUIElement) -> String {
        var pending = [root]
        var text: [String] = []
        var inspected = 0
        while let element = pending.popLast(), inspected < 2_000 {
            inspected += 1
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   let string = value as? String {
                    text.append(string)
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
}

private enum RoadmapFixture {
    static let populated = make(phases: [
        phase(id: "delivery", name: "Current delivery", lifecycle: .inDelivery, readiness: .draft, tickets: 5, goals: 1),
        phase(id: "upcoming", name: "Upcoming work", lifecycle: .upcoming, readiness: .ready, tickets: 3, goals: 1),
        phase(id: "unassessed", name: "Needs goal", lifecycle: .unassessed, readiness: .legacyUnassessed, tickets: 2, goals: 0),
        phase(id: "completed", name: "Completed delivery", lifecycle: .completed, readiness: .ready, tickets: 4, goals: 1),
    ])

    static let empty = make(phases: [])

    private static func make(phases: [ProjectPlanPhaseProjection]) -> (plan: ProjectPlanProjection) {
        let projectID = ProjectID(rawValue: "roadmap-fixture")
        return (
            .init(
                project: .init(
                    id: projectID,
                    name: "Roadmap fixture",
                    activePhaseName: "Current delivery",
                    goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
                    currentWorkCount: 3,
                    attentionCount: 0
                ),
                phases: phases,
                unassignedTickets: [],
                unassignedDetails: []
            )
        )
    }

    private static func phase(
        id: String,
        name: String,
        lifecycle: PhaseLifecycle,
        readiness: PhasePlanState,
        tickets: Int,
        goals: Int
    ) -> ProjectPlanPhaseProjection {
        let projectID = ProjectID(rawValue: "roadmap-fixture")
        let phaseID = PhaseID(rawValue: id)
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        return .init(
            id: phaseID,
            name: name,
            readiness: .init(
                state: readiness,
                revision: 1,
                readyRevision: readiness == .ready ? 1 : nil,
                upcomingCount: tickets - 3,
                coveredUpcomingCount: max(0, tickets - 3),
                unassignedUpcomingCount: 0
            ),
            lifecycle: .init(
                projectID: projectID,
                phaseID: phaseID,
                lifecycle: lifecycle,
                revision: 1,
                completionBaselineDigest: nil,
                createdAt: timestamp,
                updatedAt: timestamp,
                completedAt: lifecycle == .completed ? timestamp : nil
            ),
            completionAssessment: .init(phaseID: phaseID, planningBaselineDigest: "fixture", blockers: []),
            deliveryGoals: (0..<goals).map { index in
                .init(
                    goalID: .init(rawValue: "\(id)-goal-\(index)"),
                    title: "Goal \(index + 1)",
                    outcome: "Deliver \(name)",
                    lifecycle: .draft,
                    doneCriteria: ["Observed outcome"],
                    ticketIDs: [.init(rawValue: "\(id)-ticket")]
                )
            },
            ticketCount: tickets
        )
    }
}
