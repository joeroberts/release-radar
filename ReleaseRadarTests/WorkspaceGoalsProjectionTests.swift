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

    func testDocumentationReplacementPreservesExactExecutionGoalLinks() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceDocumentationReplacement-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let dashboard = try await DashboardProjection.load(from: store)
        let goal = try XCTUnwrap(dashboard.workspaceGoals.execution.first { $0.link.ticketID != nil })
        let filter = DeliveryGoalFilter.execution(try XCTUnwrap(goal.boardFilter))

        let replaced = dashboard.replacingDocumentation(for: goal.project.id, with: [])
        let board = try XCTUnwrap(replaced.allPhaseBoard(for: goal.project.id))

        XCTAssertTrue(board.hasExactExecutionGoalLink(try XCTUnwrap(goal.boardFilter)))
        XCTAssertEqual(
            board.filtered(by: filter).lanes.flatMap(\.cards).map(\.id),
            [try XCTUnwrap(goal.link.ticketID)]
        )
    }

    func testRemainingWorkspaceRowCollisionsReceiveStableIdentityCuesOnlyWhenNeeded() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalRowCollisions-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let dashboard = try await DashboardProjection.load(from: store)
        let project = try XCTUnwrap(dashboard.projects.first)
        let duplicateProject = ProjectDashboardProjection(
            id: .init(rawValue: "workspace-collision-project"),
            name: project.name,
            activePhaseName: project.activePhaseName,
            goalContext: project.goalContext,
            currentWorkCount: 1,
            attentionCount: 0
        )
        let firstExecution = WorkspaceExecutionGoalProjection(
            project: project, goalID: "collision-goal-a", threadID: "collision-thread-a",
            status: "Completed", text: "Identical visible execution outcome", observedAt: nil,
            link: .unlinked
        )
        let secondExecution = WorkspaceExecutionGoalProjection(
            project: duplicateProject, goalID: "collision-goal-b", threadID: "collision-thread-b",
            status: firstExecution.status, text: firstExecution.text, observedAt: nil,
            link: .unlinked
        )
        let executions = [firstExecution, secondExecution]

        XCTAssertNil(workspaceExecutionIdentityCue(for: firstExecution, among: [firstExecution]))
        XCTAssertEqual(
            Set(executions.compactMap { workspaceExecutionIdentityCue(for: $0, among: executions) }).count,
            2
        )

        let firstUnassigned = WorkspaceUnassignedDeliveryWorkProjection(
            project: project,
            phaseID: .init(rawValue: "collision-phase-a"),
            phaseName: "Same phase name",
            tickets: [.init(id: .init(rawValue: "COLLISION-A"), outcome: "A", dependencyCount: 0, blockerCount: 0)]
        )
        let secondUnassigned = WorkspaceUnassignedDeliveryWorkProjection(
            project: duplicateProject,
            phaseID: .init(rawValue: "collision-phase-b"),
            phaseName: firstUnassigned.phaseName,
            tickets: [.init(id: .init(rawValue: "COLLISION-B"), outcome: "B", dependencyCount: 0, blockerCount: 0)]
        )
        let unassigned = [firstUnassigned, secondUnassigned]

        XCTAssertNil(workspaceUnassignedIdentityCue(for: firstUnassigned, among: [firstUnassigned]))
        XCTAssertEqual(
            Set(unassigned.compactMap { workspaceUnassignedIdentityCue(for: $0, among: unassigned) }).count,
            2
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
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Rekon Pursuit', 0)",
                bindings: [.text(secondProject.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: secondProject,
                phaseID: secondPhase,
                name: "Post-MVP refinement",
                mode: .governed,
                connection: connection
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('SECOND-1', ?, ?, 'Second phase work', 'backlog')",
                bindings: [.text(secondProject.rawValue), .text(secondPhase.rawValue)]
            )
            try connection.execute(
                "INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES (?, ?, ?, 'Post-MVP refinement', 'Second phase outcome', 'draft', 0, '2026-09-10T00:00:00Z', '2026-09-10T00:00:00Z')",
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
        let projectChoices = workspaceGoalsProjectChoices(matches.map(\.project))
        XCTAssertEqual(Set(projectChoices.map(\.label)).count, 2)
        XCTAssertTrue(projectChoices.allSatisfy { $0.label.contains("ID bytes") })
        XCTAssertEqual(Set(matches.compactMap { workspaceDeliveryIdentityCue(for: $0, among: matches) }).count, 2)
    }

    @MainActor
    func testUnplacedWorkIsDiscoveredAndOpensTheProjectPlan() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceUnplacedGoals-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Record unplaced Goals work") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'workspace-unplaced-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertUnassignedTicket(
                projectID: DashboardSampleData.projectID,
                ticketID: .init(rawValue: "UNPLACED-GOALS"),
                outcome: "Retain project-level work without inventing a phase or goal",
                connection: connection
            )
        }

        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let item = try XCTUnwrap(model.dashboard?.workspaceGoals.unassignedDeliveryWork.first {
            $0.tickets.contains(where: { $0.id.rawValue == "UNPLACED-GOALS" })
        })

        await model.navigate(to: .goals)
        await model.openWorkspaceUnassignedWork(item)

        XCTAssertEqual(model.selection, .projectPlan(DashboardSampleData.projectID))
        XCTAssertEqual(model.selectedTicketID.rawValue, "UNPLACED-GOALS")
    }

    @MainActor
    func testInitialAndFilteredGoalsReconcileDisplayedSelectionAndRegistration() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalSelection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Register displayed Goals identity") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'workspace-selection-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()

        await model.navigate(to: .goals)
        let initialDeliveryID = try XCTUnwrap(model.selectedWorkspaceDeliveryGoalID)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(initialDeliveryID))
        XCTAssertEqual(model.navigationHistory.current.workspaceGoals?.selectedDeliveryID, initialDeliveryID)
        XCTAssertEqual(model.navigationHistory.current.registration?.registrationID, "workspace-selection-registration")

        model.setWorkspaceGoalsDomain(.execution)
        let executionID = try XCTUnwrap(model.selectedWorkspaceExecutionGoalID)
        XCTAssertEqual(model.navigationFocus, .workspaceGoal(executionID))
        XCTAssertEqual(model.navigationHistory.current.workspaceGoals?.selectedExecutionID, executionID)
        XCTAssertEqual(model.navigationHistory.current.registration?.registrationID, "workspace-selection-registration")

        model.setWorkspaceGoalsExecutionStatus("No stored match")
        XCTAssertNil(model.selectedWorkspaceExecutionGoalID)
        XCTAssertEqual(model.navigationFocus, .workspaceGoalsFilter)
        model.setWorkspaceGoalsExecutionStatus(nil)
        XCTAssertNotNil(model.selectedWorkspaceExecutionGoalID)
        XCTAssertEqual(model.navigationFocus, model.selectedWorkspaceExecutionGoalID.map(NavigationFocus.workspaceGoal))
    }

    @MainActor
    func testRemovedExactExecutionLinkCannotKeepShowingItsTicket() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalRemovedLink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Register exact execution-link recovery") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'workspace-link-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let goal = try XCTUnwrap(model.dashboard?.workspaceGoals.execution.first { $0.link.ticketID != nil })
        let ticketID = try XCTUnwrap(goal.link.ticketID)

        await model.navigate(to: .goals)
        model.setWorkspaceGoalsDomain(.execution)
        model.selectWorkspaceExecutionGoal(goal.id)
        await model.openWorkspaceExecutionGoal(goal)
        try await store.transact(actor: .init(id: "workspace-goals-test"), reason: "Remove exact execution link") { connection in
            try connection.execute(
                "DELETE FROM ticket_goal_links WHERE project_id = ? AND ticket_id = ? AND thread_id = ? AND goal_id = ?",
                bindings: [
                    .text(goal.project.id.rawValue), .text(ticketID.rawValue),
                    .text(goal.threadID), .text(goal.goalID),
                ]
            )
        }

        await model.reloadDashboardAfterCommittedAgentCommand()

        let filter = model.allPhaseBoardFilter(projectID: goal.project.id)
        XCTAssertTrue(model.viewedAllPhaseBoard(for: goal.project.id)?.filtered(by: filter).lanes.flatMap(\.cards).isEmpty == true)
        XCTAssertTrue(model.navigationRecoveryMessage?.contains("exact Execution Goal link") == true)
        XCTAssertEqual(model.navigationFocus, .recovery)
    }

    func testDeliveryFactsKeepFormalStatePhaseLifecycleAndAcceptanceDistinct() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-WorkspaceGoalFacts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let dashboard = try await DashboardProjection.load(from: store)
        let goal = try XCTUnwrap(dashboard.workspaceGoals.delivery.first)
        let facts = workspaceDeliveryGoalFacts(goal)

        XCTAssertEqual(facts.formalState, "Formal Delivery Goal state: \(goal.goal.lifecycle.displayName)")
        XCTAssertEqual(facts.phaseLifecycle, "Phase lifecycle: \(goal.phaseLifecycle?.lifecycle.displayName ?? "Unavailable")")
        XCTAssertTrue(facts.structuralReadiness.hasPrefix("Structural readiness:"))
        XCTAssertTrue(facts.coverage.hasPrefix("Carried-obligation coverage:"))
        XCTAssertEqual(
            facts.ownerAcceptance,
            goal.goal.lifecycle == .accepted
                ? "Owner acceptance: Recorded"
                : "Owner acceptance: Not recorded"
        )
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
