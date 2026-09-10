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

    func testExecutionGoalBoardFilterKeepsExactIdentityAndOnlyAssociatedTicket() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceExecutionGoalFilter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let dashboard = try await DashboardProjection.load(from: store)
        let goal = try XCTUnwrap(dashboard.workspaceGoals.execution.first { $0.link.ticketID != nil })
        let ticketID = try XCTUnwrap(goal.link.ticketID)
        let filter = DeliveryGoalFilter.execution(.init(
            threadID: goal.threadID,
            goalID: goal.goalID,
            ticketID: ticketID
        ))
        let board = try XCTUnwrap(dashboard.allPhaseBoard(for: goal.project.id))

        XCTAssertEqual(
            board.filtered(by: filter).lanes.flatMap(\.cards).map(\.id),
            [ticketID]
        )
        XCTAssertEqual(board.filtered(by: .all).lanes.flatMap(\.cards).count, board.lanes.flatMap(\.cards).count)
        XCTAssertNotEqual(
            filter,
            .execution(.init(threadID: goal.threadID, goalID: "\(goal.goalID)\u{301}", ticketID: ticketID))
        )
    }

    func testGoalsRouteIsAWorkspaceDestination() {
        XCTAssertEqual(AppRoute.goals.title, "Goals")
        XCTAssertNil(AppRoute.goals.projectID)
        XCTAssertTrue(AppRoute.primaryRoutes.contains(.goals))
    }

    func testDeliveryDiscoveryKeepsSameGoalIDsDistinctAcrossProjects() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalFilter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let secondProject = ProjectID(rawValue: "same-identities-second-project")
        let secondPhase = PhaseID(rawValue: "same-identities-second-phase")
        let sharedGoal = DeliveryGoalID(rawValue: "rr10-sample-refinement")
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Add colliding project-scoped identities") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Second project', 0)",
                bindings: [.text(secondProject.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: secondProject,
                phaseID: secondPhase,
                name: "Second phase",
                mode: .governed,
                connection: connection
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('SECOND-1', ?, ?, 'Second phase work', 'backlog')",
                bindings: [.text(secondProject.rawValue), .text(secondPhase.rawValue)]
            )
            try connection.execute(
                "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES (?, ?, ?, 'Same ID in another phase', 'Second phase outcome', 'draft', 0, '2026-09-10T00:00:00Z', '2026-09-10T00:00:00Z')",
                bindings: [.text(secondProject.rawValue), .text(secondPhase.rawValue), .text(sharedGoal.rawValue)]
            )
            try connection.execute(
                "INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES (?, ?, ?, 'SECOND-1')",
                bindings: [.text(secondProject.rawValue), .text(secondPhase.rawValue), .text(sharedGoal.rawValue)]
            )
        }

        let dashboard = try await DashboardProjection.load(from: store)
        let matches = dashboard.workspaceGoals.delivery.filter { $0.goal.goalID.rawValue == sharedGoal.rawValue }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(Set(matches.map(\.id)).count, 2)
        XCTAssertEqual(Set(matches.map { $0.project.id.rawValue }), [DashboardSampleData.projectID.rawValue, secondProject.rawValue])
    }

    func testGoalsNavigationEntryCarriesDomainFiltersSelectionViewportAndFocus() {
        let selectedID = Data("project\0phase\0goal".utf8)
        let state = WorkspaceGoalsNavigationState(
            domain: .execution,
            projectID: .init(rawValue: "project-a"),
            deliveryLifecycle: .accepted,
            executionStatus: "Completed",
            executionScope: .unlinked,
            selectedDeliveryID: nil,
            selectedExecutionID: selectedID,
            viewportOffset: 284.5
        )
        var history = NavigationHistory(initial: .goals)

        history.updateCurrent(
            phaseID: nil,
            selectedTicketID: nil,
            workspaceGoals: state,
            focus: .workspaceGoal(selectedID)
        )

        XCTAssertEqual(history.current.workspaceGoals, state)
        XCTAssertEqual(history.current.focus, .workspaceGoal(selectedID))
    }

    @MainActor
    func testBackRestoresExecutionGoalsFiltersSelectionViewportAndFocus() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalsNavigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Register exact Goals navigation identity") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'workspace-goals-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let goal = try XCTUnwrap(model.dashboard?.workspaceGoals.execution.first)

        await model.navigate(to: .goals)
        model.setWorkspaceGoalsDomain(.execution)
        model.setWorkspaceGoalsProjectID(goal.project.id)
        model.setWorkspaceGoalsExecutionStatus(goal.status)
        model.setWorkspaceGoalsExecutionScope(.linked)
        model.selectWorkspaceExecutionGoal(goal.id)
        model.setWorkspaceGoalsViewportOffset(284.5)
        model.setNavigationFocus(.workspaceGoal(goal.id))
        await model.navigate(to: .phaseBoard(goal.project.id))

        await model.goBack()

        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(model.workspaceGoalsDomain, .execution)
        XCTAssertEqual(model.workspaceGoalsProjectID?.rawValue, goal.project.id.rawValue)
        XCTAssertEqual(model.workspaceGoalsExecutionStatus, goal.status)
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .linked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, goal.id)
        XCTAssertEqual(model.workspaceGoalsViewportOffset, 284.5)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(goal.id))
        XCTAssertNil(model.navigationRecoveryMessage)
    }

    @MainActor
    func testOpeningAssociatedExecutionWorkPreservesGoalsHistoryContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalsAssociatedWork-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Register exact Goals navigation identity") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'workspace-goals-associated-work-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let goal = try XCTUnwrap(model.dashboard?.workspaceGoals.execution.first { $0.link.ticketID != nil })

        await model.navigate(to: .goals)
        model.setWorkspaceGoalsDomain(.execution)
        model.setWorkspaceGoalsExecutionStatus(goal.status)
        model.setWorkspaceGoalsExecutionScope(.linked)
        model.selectWorkspaceExecutionGoal(goal.id)
        model.setWorkspaceGoalsViewportOffset(284.5)

        await model.openWorkspaceExecutionGoal(goal)
        XCTAssertEqual(model.selection, .phaseBoard(goal.project.id))
        XCTAssertEqual(
            model.allPhaseBoardFilter(projectID: goal.project.id),
            .execution(.init(
                threadID: goal.threadID,
                goalID: goal.goalID,
                ticketID: try XCTUnwrap(goal.link.ticketID)
            ))
        )

        await model.goBack()
        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(model.workspaceGoalsDomain, .execution)
        XCTAssertEqual(model.workspaceGoalsExecutionStatus, goal.status)
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .linked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, goal.id)
        XCTAssertEqual(model.workspaceGoalsViewportOffset, 284.5)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(goal.id))
    }
}
