import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class WorkspaceGoalsProjectionTests: XCTestCase {
    func testExecutionDiscoveryRetainsLinkedAndUnlinkedPersistedGoalsWithExactIdentity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoals-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Record an unlinked persisted execution observation") { connection in
            try connection.execute(
                "INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES (?, ?, ?, ?)",
                bindings: [.text("unlinked-thread"), .text(DashboardSampleData.projectID.rawValue), .text("completed"), .text("2026-09-10T12:00:00Z")]
            )
            try connection.execute(
                "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES (?, ?, ?, ?, ?, ?)",
                bindings: [.text("unlinked-goal"), .text(DashboardSampleData.projectID.rawValue), .text("unlinked-thread"), .text("Completed"), .text("Persisted without an exact work link."), .text("2026-09-10T12:00:00Z")]
            )
        }

        let dashboard = try await DashboardProjection.load(from: store)
        let goals = dashboard.workspaceGoals

        XCTAssertEqual(goals.execution.count, 2)
        XCTAssertEqual(goals.execution.first(where: { $0.goalID == "unlinked-goal" })?.threadID, "unlinked-thread")
        XCTAssertEqual(goals.execution.first(where: { $0.goalID == "unlinked-goal" })?.link, .unlinked)
        XCTAssertEqual(goals.execution.first(where: { $0.goalID == "rr06-goal-vd2-07c" })?.link.ticketID, .init(rawValue: "VD2-07c"))
    }

    func testGoalsRouteIsAWorkspaceDestination() {
        XCTAssertEqual(AppRoute.goals.title, "Goals")
        XCTAssertNil(AppRoute.goals.projectID)
        XCTAssertTrue(AppRoute.primaryRoutes.contains(.goals))
    }
}
