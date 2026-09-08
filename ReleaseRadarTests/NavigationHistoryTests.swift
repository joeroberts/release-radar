import XCTest
@testable import ReleaseRadar
import ReleaseRadarCore

final class NavigationHistoryTests: XCTestCase {
    func testNavigationIdentityAllowsLifecycleGenerationAdvanceButRejectsReaddedRegistration() {
        let projectID = ProjectID(rawValue: "project-a")
        let recorded = ProjectRegistration(projectID: projectID, registrationID: "registration-a", requestGeneration: 4)

        XCTAssertTrue(recorded.hasSameNavigationIdentity(as: .init(
            projectID: projectID,
            registrationID: "registration-a",
            requestGeneration: 5
        )))
        XCTAssertFalse(recorded.hasSameNavigationIdentity(as: .init(
            projectID: projectID,
            registrationID: "registration-b",
            requestGeneration: 1
        )))
    }

    @MainActor
    func testBackRestoresExactBoardPhaseFilterSelectionAndFocus() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationHistory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(
            actor: .init(id: "navigation-history-test"),
            reason: "Add a synthetic registration for lifecycle restoration coverage"
        ) { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'navigation-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        await model.loadDashboard()
        let ticketID = TicketID(rawValue: "VD2-08")
        let filter = DeliveryGoalFilter.goal(.init(rawValue: "rr10-sample-refinement"))

        await model.navigate(to: .phaseBoard(DashboardSampleData.projectID))
        model.viewPhase(projectID: DashboardSampleData.projectID, phaseID: DashboardSampleData.phaseID)
        model.setBoardFilter(filter, projectID: DashboardSampleData.projectID, phaseID: DashboardSampleData.phaseID)
        model.selectTicket(ticketID)
        await model.navigate(to: .dependencies(DashboardSampleData.projectID))

        await model.goBack()

        XCTAssertEqual(model.selection, .phaseBoard(DashboardSampleData.projectID))
        XCTAssertEqual(model.viewedBoard(for: DashboardSampleData.projectID)?.phaseID, DashboardSampleData.phaseID)
        XCTAssertEqual(model.boardFilter(projectID: DashboardSampleData.projectID, phaseID: DashboardSampleData.phaseID), filter)
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertEqual(model.navigationFocus, .ticket(ticketID))
        XCTAssertNil(model.navigationRecoveryMessage)
    }

    @MainActor
    func testHistoryUsesExactRegistrationWhenProjectBecomesArchived() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationArchive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(
            actor: .init(id: "navigation-history-test"),
            reason: "Add a synthetic registration for lifecycle restoration coverage"
        ) { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'navigation-registration', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            seedSampleData: false
        )
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(DashboardSampleData.projectID))
        await model.navigate(to: .dependencies(DashboardSampleData.projectID))
        let preview = try await model.previewProjectLifecycle(
            projectID: DashboardSampleData.projectID,
            transition: .archive
        )
        try await model.applyProjectLifecycle(preview)

        await model.goBack()

        XCTAssertEqual(model.selection, .archivedProject(DashboardSampleData.projectID))
        XCTAssertEqual(
            model.navigationRecoveryMessage,
            "The project was archived after this history entry was recorded."
        )
    }

    @MainActor
    func testSettingsHistoryRemainsGlobalWhenProjectBecomesArchived() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationGlobalArchive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "navigation-history-test"), reason: "Register archive fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'navigation-global-archive', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(DashboardSampleData.projectID))
        _ = model.viewedBoard(for: DashboardSampleData.projectID)
        await model.navigate(to: .settings)
        let preview = try await model.previewProjectLifecycle(
            projectID: DashboardSampleData.projectID,
            transition: .archive
        )
        try await model.applyProjectLifecycle(preview)

        await model.goBack()
        XCTAssertEqual(model.selection, .archivedProject(DashboardSampleData.projectID))

        await model.goForward()
        XCTAssertEqual(model.selection, .settings)
        XCTAssertNil(model.navigationRecoveryMessage)
    }

    @MainActor
    func testProjectsHistoryRemainsGlobalWhenProjectIsRemoved() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationGlobalRemoval-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "navigation-history-test"), reason: "Register removal fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'navigation-global-removal', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(DashboardSampleData.projectID))
        _ = model.viewedBoard(for: DashboardSampleData.projectID)
        await model.navigate(to: .projects)
        let preview = try await model.previewProjectRemoval(projectID: DashboardSampleData.projectID)
        let removed = try await model.applyProjectRemoval(preview)

        await model.goBack()
        XCTAssertEqual(model.selection, .removedProject(removed.id))

        await model.goForward()
        XCTAssertEqual(model.selection, .projects)
        XCTAssertNil(model.navigationRecoveryMessage)
    }

    @MainActor
    func testProjectScopedPrimaryRoutesRestoreTheirNonFirstProjectContext() async throws {
        for route in [AppRoute.needsReview, .notifications] {
            let fixture = try await makeProjectScopedPrimaryRouteFixture(route: route)
            XCTAssertEqual(fixture.model.currentProjectID, fixture.firstProjectID)

            await fixture.model.navigate(to: .projectOverview(DashboardSampleData.projectID))
            await fixture.model.navigate(to: route)
            await fixture.model.navigate(to: .projectOverview(fixture.firstProjectID))
            await fixture.model.goBack()

            XCTAssertEqual(fixture.model.selection, route)
            XCTAssertEqual(fixture.model.currentProjectID, DashboardSampleData.projectID)
            XCTAssertEqual(fixture.model.navigationHistory.current.registration?.projectID, DashboardSampleData.projectID)
            XCTAssertNil(fixture.model.navigationRecoveryMessage)
        }
    }

    @MainActor
    func testProjectScopedPrimaryRoutesFollowArchivedRegistrationIdentity() async throws {
        for route in [AppRoute.needsReview, .notifications] {
            let fixture = try await makeProjectScopedPrimaryRouteFixture(route: route)
            await fixture.model.navigate(to: .projectOverview(DashboardSampleData.projectID))
            await fixture.model.navigate(to: route)
            let preview = try await fixture.model.previewProjectLifecycle(
                projectID: DashboardSampleData.projectID,
                transition: .archive
            )
            try await fixture.model.applyProjectLifecycle(preview)

            await fixture.model.goBack()
            await fixture.model.goForward()

            XCTAssertEqual(fixture.model.selection, .archivedProject(DashboardSampleData.projectID))
            XCTAssertTrue(fixture.model.navigationRecoveryMessage?.contains("project was archived") == true)
        }
    }

    @MainActor
    func testProjectScopedPrimaryRoutesFollowRemovedRegistrationIdentity() async throws {
        for route in [AppRoute.needsReview, .notifications] {
            let fixture = try await makeProjectScopedPrimaryRouteFixture(route: route)
            await fixture.model.navigate(to: .projectOverview(DashboardSampleData.projectID))
            await fixture.model.navigate(to: route)
            let preview = try await fixture.model.previewProjectRemoval(projectID: DashboardSampleData.projectID)
            let removed = try await fixture.model.applyProjectRemoval(preview)

            await fixture.model.goBack()
            await fixture.model.goForward()

            XCTAssertEqual(fixture.model.selection, .removedProject(removed.id))
            XCTAssertTrue(fixture.model.navigationRecoveryMessage?.contains("project was removed") == true)
        }
    }

    @MainActor
    func testRemovedHistoryEntryDoesNotRedirectToReaddedProjectWithSameProjectID() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationReadd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        try await store.transact(actor: .init(id: "navigation-history-test"), reason: "Register removal fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'registration-before-removal', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true)
        await model.loadDashboard()
        await model.navigate(to: .phaseBoard(DashboardSampleData.projectID))
        await model.navigate(to: .settings)
        let preview = try await model.previewProjectRemoval(projectID: DashboardSampleData.projectID)
        let removed = try await model.applyProjectRemoval(preview)
        try await store.transact(actor: .init(id: "navigation-history-test"), reason: "Re-add a different registration") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Re-added project', 0)",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'registration-after-removal', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        await model.reloadDashboardAfterCommittedAgentCommand()

        await model.goBack()

        XCTAssertEqual(model.selection, .removedProject(removed.id))
        XCTAssertTrue(model.navigationRecoveryMessage?.contains("project was removed") == true)
        XCTAssertNotEqual(model.selection, .projectOverview(DashboardSampleData.projectID))
    }

    @MainActor
    func testRelaunchStartsAtProjectsWithEmptyHistory() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationRelaunch-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: databaseURL) }
        let model = AppModel(store: DeliveryStore(databaseURL: databaseURL), externalServicesSuppressed: true)

        XCTAssertEqual(model.selection, .projects)
        XCTAssertEqual(model.navigationHistory.entries.map(\.route), [.projects])
        XCTAssertFalse(model.canNavigateBack)
        XCTAssertFalse(model.canNavigateForward)
    }

    @MainActor
    func testLateProjectNavigationCannotReplaceNewerRouteOrAppendStaleHistory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationRace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let loader = BlockingNavigationObservationLoader(projectID: DashboardSampleData.projectID)
        let observer = DocumentationObservationCoordinator { projectID in
            await loader.load(projectID: projectID)
        }
        let model = AppModel(
            store: store,
            externalServicesSuppressed: true,
            documentationObserver: observer
        )
        await model.loadDashboard()

        let older = Task { await model.navigate(to: .phaseBoard(DashboardSampleData.projectID)) }
        await loader.waitUntilBlockedNavigationEntered()
        await model.navigate(to: .settings)
        await loader.releaseBlockedNavigation()
        await older.value

        XCTAssertEqual(model.selection, .settings)
        XCTAssertEqual(model.navigationHistory.current.route, .settings)
        XCTAssertFalse(model.navigationHistory.entries.dropLast().contains {
            $0.route == .phaseBoard(DashboardSampleData.projectID)
        })
    }

    @MainActor
    func testCrossProjectNavigationDoesNotCarrySelectionAndBackRestoresOriginalProjectContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NavigationCrossProject-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let otherProjectID = ProjectID(rawValue: "other-project")
        let otherPhaseID = PhaseID(rawValue: "other-phase")
        try await store.transact(
            actor: .init(id: "navigation-history-test"),
            reason: "Add a second synthetic project for cross-project history coverage",
            auditScope: .init(projectID: otherProjectID, entityType: .project, entityID: otherProjectID.rawValue)
        ) { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'Other project', 0)",
                bindings: [.text(otherProjectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: otherProjectID,
                phaseID: otherPhaseID,
                name: "Other phase",
                mode: .governed,
                connection: connection
            )
            try connection.execute(
                "INSERT INTO project_active_phases (phase_id, project_id) VALUES (?, ?)",
                bindings: [.text(otherPhaseID.rawValue), .text(otherProjectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertTicket(
                projectID: otherProjectID,
                ticketID: .init(rawValue: "OTHER-1"),
                phaseID: otherPhaseID,
                outcome: "Other project work",
                lane: .backlog,
                auditEventID: .init(rawValue: "navigation-cross-project-audit"),
                connection: connection
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true)
        await model.loadDashboard()
        let originalTicketID = TicketID(rawValue: "VD2-08")
        await model.navigate(to: .phaseBoard(DashboardSampleData.projectID))
        model.viewPhase(projectID: DashboardSampleData.projectID, phaseID: DashboardSampleData.phaseID)
        model.selectTicket(originalTicketID)

        await model.navigate(to: .phaseBoard(otherProjectID))
        XCTAssertEqual(model.selection, .phaseBoard(otherProjectID))
        XCTAssertTrue(model.selectedTicketID.rawValue.isEmpty)

        await model.goBack()
        XCTAssertEqual(model.selection, .phaseBoard(DashboardSampleData.projectID))
        XCTAssertEqual(model.selectedTicketID, originalTicketID)
        XCTAssertEqual(model.navigationFocus, .ticket(originalTicketID))
    }

    func testEntryCarriesExactRegistrationFilterSelectionAndFocusContext() {
        let projectID = ProjectID(rawValue: "project-a")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-a",
            requestGeneration: 4
        )
        var history = NavigationHistory(initial: .projects)

        history.navigate(to: .init(
            route: .phaseBoard(projectID),
            registration: registration,
            phaseID: .init(rawValue: "phase-a"),
            filter: .goal(.init(rawValue: "goal-a")),
            selectedTicketID: .init(rawValue: "A-1"),
            focus: .ticket(.init(rawValue: "A-1"))
        ))

        XCTAssertEqual(history.current.registration, registration)
        XCTAssertEqual(history.current.filter, .goal(.init(rawValue: "goal-a")))
        XCTAssertEqual(history.current.selectedTicketID?.rawValue, "A-1")
        XCTAssertEqual(history.current.focus, .ticket(.init(rawValue: "A-1")))
    }

    func testFilterAndFocusUpdatesReplaceCurrentEntryWithoutCreatingSteps() {
        let projectID = ProjectID(rawValue: "project-a")
        var history = NavigationHistory(initial: .projects)
        history.navigate(to: .init(route: .phaseBoard(projectID)))

        history.updateCurrent(
            phaseID: .init(rawValue: "phase-a"),
            filter: .unassigned,
            selectedTicketID: nil,
            focus: .filterSummary
        )

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(history.current.filter, .unassigned)
        XCTAssertEqual(history.current.focus, .filterSummary)
    }

    func testNewNavigationAfterBackDiscardsForwardContext() {
        var history = NavigationHistory(initial: .projects)
        history.navigate(to: .projectOverview(.init(rawValue: "project-a")))
        history.navigate(to: .phaseBoard(.init(rawValue: "project-a")), phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-1"))
        XCTAssertTrue(history.goBack())

        history.navigate(to: .dependencies(.init(rawValue: "project-a")), phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-1"))

        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.current.route, .dependencies(.init(rawValue: "project-a")))
    }

    func testUpdatingCurrentContextDoesNotCreateBackStep() {
        var history = NavigationHistory(initial: .projects)
        history.navigate(to: .phaseBoard(.init(rawValue: "project-a")), phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-1"))
        history.updateCurrent(phaseID: .init(rawValue: "phase-a"), selectedTicketID: .init(rawValue: "A-2"))

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertTrue(history.goBack())
        XCTAssertEqual(history.current.route, .projects)
    }

    @MainActor
    private func makeProjectScopedPrimaryRouteFixture(
        route: AppRoute
    ) async throws -> (model: AppModel, firstProjectID: ProjectID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ReleaseRadar-NavigationScopedPrimary-\(route.title)-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let firstProjectID = ProjectID(rawValue: "first-project")
        try await store.transact(actor: .init(id: "navigation-history-test"), reason: "Seed scoped primary route fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'navigation-scoped-primary', 1, 'complete')",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, 'AAA First Project', 0)",
                bindings: [.text(firstProjectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'navigation-first-project', 1, 'complete')",
                bindings: [.text(firstProjectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        return (model, firstProjectID)
    }
}

private actor BlockingNavigationObservationLoader {
    private let projectID: ProjectID
    private var loadCount = 0
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(projectID: ProjectID) {
        self.projectID = projectID
    }

    func load(projectID: ProjectID) async -> DocumentationObservationPayload {
        loadCount += 1
        if loadCount > 1 {
            enteredContinuation?.resume()
            enteredContinuation = nil
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        return DocumentationObservationPayload(
            identity: .init(
                projectID: projectID,
                registration: nil,
                rootID: nil,
                rootPath: nil,
                binding: nil
            ),
            checkedAt: Date(timeIntervalSince1970: TimeInterval(loadCount)),
            documentationState: .legacy(.unavailable),
            evidence: []
        )
    }

    func waitUntilBlockedNavigationEntered() async {
        guard loadCount < 2 else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func releaseBlockedNavigation() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
