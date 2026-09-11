import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

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
    func testSearchResultNavigationRestoresExactSearchStateWithoutChangingActivePhase() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchNavigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let nonactivePhaseID = PhaseID(rawValue: "search-nonactive-phase")
        let ticketID = TicketID(rawValue: "SEARCH-NONACTIVE-1")
        try await store.transact(actor: .init(id: "search-navigation-test"), reason: "Seed exact Search navigation target") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'search-navigation-registration', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: projectID,
                phaseID: nonactivePhaseID,
                name: "Search nonactive phase",
                mode: .governed,
                connection: connection
            )
            try DeliveryPlanningPolicy.upsertTicket(
                projectID: projectID,
                ticketID: ticketID,
                phaseID: nonactivePhaseID,
                outcome: "Open exact Search navigation target",
                lane: .backlog,
                auditEventID: .init(rawValue: "search-navigation-audit"),
                connection: connection
            )
        }
        let activePhaseBefore = try await store.read {
            try $0.scalarText(
                "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()

        await model.navigate(to: .search)
        model.setWorkspaceSearchText(ticketID.rawValue)
        for domain in WorkspaceSearchDomain.allCases where domain != .ticket {
            model.setWorkspaceSearchDomain(domain, enabled: false)
        }
        model.setWorkspaceSearchSort(.newest)
        await model.runWorkspaceSearch()
        let result = try XCTUnwrap(model.workspaceSearchProjection?.results.first)
        model.selectWorkspaceSearchResult(result.id)
        model.setWorkspaceSearchViewportOffset(287.5)

        await model.openWorkspaceSearchResult(result)

        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertEqual(model.viewedBoard(for: projectID)?.phaseID, nonactivePhaseID)
        XCTAssertEqual(model.selectedTicketID, ticketID)
        let activePhaseAfterOpen = try await store.read {
            try $0.scalarText(
                "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
        XCTAssertEqual(activePhaseAfterOpen, activePhaseBefore)

        await model.goBack()

        XCTAssertEqual(model.selection, .search)
        XCTAssertEqual(model.workspaceSearchDefinition.text, ticketID.rawValue)
        XCTAssertEqual(model.workspaceSearchDefinition.domains, [.ticket])
        XCTAssertEqual(model.workspaceSearchDefinition.sort, .newest)
        XCTAssertEqual(model.selectedWorkspaceSearchResultID, result.id)
        XCTAssertEqual(model.workspaceSearchViewportOffset, 287.5)
        XCTAssertEqual(model.navigationFocus, .workspaceSearchResult(result.id))
        XCTAssertNil(model.navigationRecoveryMessage)

        await model.goForward()

        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertEqual(model.viewedBoard(for: projectID)?.phaseID, nonactivePhaseID)
        XCTAssertEqual(model.selectedTicketID, ticketID)
        let activePhaseAfterForward = try await store.read {
            try $0.scalarText(
                "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
        XCTAssertEqual(activePhaseAfterForward, activePhaseBefore)
    }

    @MainActor
    func testUnsupportedWorkingSearchSurvivesHelpBackAndOrdinarySearchWithoutReplacingBytes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-UnsupportedWorkingSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let opaquePayload = Data([0x00, 0xff, 0x7c, 0x10, 0x80])
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed newer working search") { connection in
            try connection.execute(
                "INSERT INTO workspace_search_preferences (singleton_id, payload_version, payload_data, updated_at) VALUES (1, 99, ?, '2026-09-10T12:00:00Z')",
                bindings: [.blob(opaquePayload)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadWorkspaceSearchPreferences(runSearch: false)

        await model.navigate(to: .search)
        await model.navigate(to: .help)
        await model.goBack()
        model.setWorkspaceSearchText("ordinary replacement")
        await model.runWorkspaceSearch()
        await model.saveCurrentWorkspaceSearch(name: "Must not save")

        XCTAssertEqual(model.selection, .search)
        XCTAssertTrue(model.workspaceSearchPreferenceIsUnsupported)
        let stored = try await store.read { connection -> (Int64, Data) in
            let row = try XCTUnwrap(try connection.row(
                "SELECT payload_version, payload_data FROM workspace_search_preferences WHERE singleton_id = 1"
            ))
            guard case let .integer(version)? = row["payload_version"],
                  case let .blob(payload)? = row["payload_data"] else {
                throw StoreError.unavailable("Unexpected working-search fixture shape")
            }
            return (version, payload)
        }
        XCTAssertEqual(stored.0, 99)
        XCTAssertEqual(stored.1, opaquePayload)
        XCTAssertFalse(model.workspaceSearchSavedQueries.contains { $0.name == "Must not save" })
    }

    @MainActor
    func testRestoredSavedQueryRequiresExplicitExactScopeChoiceBeforeRunAndSave() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-RestoredSavedSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "restored-search-project")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed restored Search project") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name) VALUES (?, 'Restored Search project')",
                bindings: [.text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'registration-before', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
        }
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        let saved = try await repository.saveQuery(
            id: "restored-query",
            name: "Restored query",
            definition: .init(
                text: "Restored",
                scope: .registrations([.init(projectID: projectID, registrationID: "registration-before")]),
                domains: [.project]
            )
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Rotate restored Search authority") { connection in
            try connection.execute(
                "UPDATE application_recovery_state SET incarnation_id = '22222222-2222-4222-8222-222222222222' WHERE singleton_id = 1"
            )
            try connection.execute(
                "UPDATE project_registrations SET registration_id = 'registration-after' WHERE project_id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()

        await model.loadWorkspaceSavedQuery(.supported(saved))
        await model.saveCurrentWorkspaceSearch(name: "Blocked ordinary save")

        XCTAssertTrue(model.workspaceSearchFailure?.contains("earlier authorization state") == true)
        XCTAssertFalse(model.workspaceSearchSavedQueries.contains { $0.name == "Blocked ordinary save" })
        let currentProject = try XCTUnwrap(model.availableWorkspaceSearchProjects.first)
        model.setWorkspaceSearchProject(currentProject, enabled: true)
        XCTAssertEqual(
            model.workspaceSearchDefinition.scope,
            .registrations([.init(projectID: projectID, registrationID: "registration-after")])
        )
        XCTAssertNil(model.workspaceSearchDefinition.authorityIncarnationID)

        await model.runWorkspaceSearch()
        await model.saveCurrentWorkspaceSearch(name: "Rescoped query")

        XCTAssertEqual(model.workspaceSearchProjection?.results.count, 1)
        XCTAssertTrue(model.workspaceSearchSavedQueries.contains { $0.name == "Rescoped query" })
    }

    @MainActor
    func testEditingDefinitionInvalidatesPendingSearchBeforeItCanPublishOrPersist() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PendingSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed pending Search project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('pending-project', 'Old needle project')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('pending-project', 'pending-registration', 1, 'complete')")
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        let gate = BlockingStoreReadGate()
        let blocker = Task {
            try await store.read { _ in
                gate.entered.signal()
                gate.release.wait()
            }
        }
        await gate.waitUntilEntered()
        model.setWorkspaceSearchText("Old needle")
        let pending = Task { await model.runWorkspaceSearch() }
        await Task.yield()
        XCTAssertTrue(model.workspaceSearchIsLoading)

        model.setWorkspaceSearchText("New query")
        gate.release.signal()
        try await blocker.value
        await pending.value

        XCTAssertEqual(model.workspaceSearchDefinition.text, "New query")
        XCTAssertNil(model.workspaceSearchProjection)
        XCTAssertFalse(model.workspaceSearchIsLoading)
        guard case .none = try await WorkspaceSearchPreferencesRepository(store: store).loadWorkingDefinition() else {
            return XCTFail("A stale pending definition must not be persisted")
        }
    }

    @MainActor
    func testAdoptingRecoveryInvalidatesPendingSearchBeforeClearingEphemeralState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-PendingRecoverySearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed pending recovery Search") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('pending-recovery-project', 'Old recovery needle')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('pending-recovery-project', 'pending-recovery-registration', 1, 'complete')")
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .search)
        model.setWorkspaceSearchText("Old recovery needle")
        let gate = BlockingStoreReadGate()
        let blocker = Task {
            try await store.read { _ in
                gate.entered.signal()
                gate.release.wait()
            }
        }
        await gate.waitUntilEntered()
        let pending = Task {
            await model.runWorkspaceSearch(persist: false, captureNavigation: false)
        }
        while !model.workspaceSearchIsLoading { await Task.yield() }

        let recovery = Task {
            try await model.adoptRecovery(.init(
                store: store,
                operationID: UUID(),
                requiresFreshServiceGraph: false,
                newerHistoryWasReconciled: false
            ))
        }
        while model.selection != .projects { await Task.yield() }
        gate.release.signal()
        try await blocker.value
        try await recovery.value
        await pending.value

        XCTAssertEqual(model.workspaceSearchDefinition, .init())
        XCTAssertNil(model.workspaceSearchProjection)
        XCTAssertFalse(model.workspaceSearchIsLoading)
        XCTAssertNil(model.workspaceSearchFailure)
    }

    @MainActor
    func testSearchAuditResultOverridesConflictingHistoryFilterAndForwardRestoresExactEvent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchAuditNavigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "search-audit-project")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed Search audit project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Search audit project')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'search-audit-registration', 1, 'complete')", bindings: [.text(projectID.rawValue)])
        }
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Audit description without identity",
            auditEventID: .init(rawValue: "search-audit-identity"),
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { _ in }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        model.setHistoryFilter(.notifications, projectID: projectID)
        await model.navigate(to: .search)
        model.setWorkspaceSearchText("search-audit-identity")
        for domain in WorkspaceSearchDomain.allCases where domain != .history {
            model.setWorkspaceSearchDomain(domain, enabled: false)
        }
        await model.runWorkspaceSearch()
        let result = try XCTUnwrap(model.workspaceSearchProjection?.results.first)

        await model.openWorkspaceSearchResult(result)

        guard case let .history(_, _, _, sourceID) = result.identity else {
            return XCTFail("Expected History result")
        }
        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID)?.sourceID, sourceID)

        await model.goBack()
        XCTAssertEqual(model.selection, .search)
        await model.goForward()
        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID)?.sourceID, sourceID)
    }

    @MainActor
    func testSearchUnlinkedExecutionGoalOverridesConflictingFiltersAndForwardRestoresExactGoal() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-SearchGoalNavigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "search-goal-project")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed Search goal project") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES (?, 'Search goal project')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'search-goal-registration', 1, 'complete')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('search-goal-thread', ?, 'completed', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('search-unlinked-goal', ?, 'search-goal-thread', 'Completed', 'Unlinked exact Search goal', '2026-09-10T12:00:00Z')", bindings: [.text(projectID.rawValue)])
        }
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        let goal = try XCTUnwrap(model.dashboard?.workspaceGoals.execution.first)
        model.setWorkspaceGoalsDomain(.execution)
        model.setWorkspaceGoalsExecutionStatus("Waiting")
        model.setWorkspaceGoalsExecutionScope(.linked)
        await model.navigate(to: .search)
        model.setWorkspaceSearchText("search-unlinked-goal")
        for domain in WorkspaceSearchDomain.allCases where domain != .executionGoal {
            model.setWorkspaceSearchDomain(domain, enabled: false)
        }
        await model.runWorkspaceSearch()
        let result = try XCTUnwrap(model.workspaceSearchProjection?.results.first)

        await model.openWorkspaceSearchResult(result)

        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(model.workspaceGoalsDomain, .execution)
        XCTAssertEqual(model.workspaceGoalsProjectID, projectID)
        XCTAssertNil(model.workspaceGoalsExecutionStatus)
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .unlinked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, goal.id)

        await model.goBack()
        XCTAssertEqual(model.selection, .search)
        await model.goForward()
        XCTAssertEqual(model.selection, .goals)
        XCTAssertEqual(model.workspaceGoalsProjectID, projectID)
        XCTAssertNil(model.workspaceGoalsExecutionStatus)
        XCTAssertEqual(model.workspaceGoalsExecutionScope, .unlinked)
        XCTAssertEqual(model.selectedWorkspaceExecutionGoalID, goal.id)
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
    func testProjectScopedPrimaryRoutesRecordFirstDisplayedProjectBeforeExplicitSelection() async throws {
        for route in [AppRoute.needsReview, .notifications] {
            let fixture = try await makeProjectScopedPrimaryRouteFixture(route: route)
            XCTAssertNil(fixture.model.selectedProjectID)
            XCTAssertEqual(fixture.model.currentProjectID, fixture.firstProjectID)

            await fixture.model.navigate(to: route)

            XCTAssertEqual(fixture.model.selection, route)
            XCTAssertEqual(fixture.model.navigationHistory.current.registration?.projectID, fixture.firstProjectID)

            let preview = try await fixture.model.previewProjectRemoval(projectID: fixture.firstProjectID)
            let removed = try await fixture.model.applyProjectRemoval(preview)
            await fixture.model.goBack()
            await fixture.model.goForward()

            XCTAssertEqual(fixture.model.selection, .removedProject(removed.id))
            XCTAssertTrue(fixture.model.navigationRecoveryMessage?.contains("project was removed") == true)
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

    func testEntryCarriesExactHistoryFilterSelectionAndFocusContext() {
        let projectID = ProjectID(rawValue: "project-a")
        let eventID = HistoryEventIdentity(
            projectID: projectID,
            registrationID: "registration-a",
            source: .audit,
            sourceID: "audit-a"
        )
        var history = NavigationHistory(initial: .projects)

        history.navigate(to: .init(
            route: .activity(projectID),
            historyFilter: .audit,
            selectedHistoryEventID: eventID,
            historyViewportOffset: 347.25,
            focus: .historyDetail(eventID)
        ))

        XCTAssertEqual(history.current.historyFilter, .audit)
        XCTAssertEqual(history.current.selectedHistoryEventID, eventID)
        XCTAssertEqual(history.current.historyViewportOffset, 347.25)
        XCTAssertEqual(history.current.focus, .historyDetail(eventID))
    }

    @MainActor
    func testHistoryEntityNavigationAndBackRestoreExactNonactiveEventContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-HistoryEntityNavigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let phaseID = PhaseID(rawValue: "history-nonactive-phase")
        let ticketID = TicketID(rawValue: "HISTORY-NONACTIVE-1")
        try await store.transact(actor: .init(id: "history-navigation-fixture"), reason: "Register History fixture") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'history-navigation-registration', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: projectID,
                phaseID: phaseID,
                name: "History nonactive phase",
                mode: .governed,
                connection: connection
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, 'Open this retained event target', 'needs_review')",
                bindings: [.text(ticketID.rawValue), .text(projectID.rawValue), .text(phaseID.rawValue)]
            )
        }
        try await store.transact(
            actor: .init(id: "history-navigation-fixture", threadID: "history-navigation-thread"),
            reason: "Record exact nonactive History target",
            auditEventID: .init(rawValue: "history-target-event"),
            auditScope: .init(projectID: projectID, entityType: .ticket, entityID: ticketID.rawValue)
        ) { _ in }
        try await store.transact(
            actor: .init(id: "legacy-fixture"),
            reason: "Legacy event without immutable facts",
            auditEventID: .init(rawValue: "history-legacy-event"),
            auditScope: .init(projectID: projectID, entityType: .ticket, entityID: ticketID.rawValue)
        ) { _ in }
        await store.close()
        let legacy = try SQLiteConnection(url: directory.appendingPathComponent("store.sqlite"))
        try legacy.execute("UPDATE audit_events SET event_facts_recorded = 0 WHERE id = 'history-legacy-event'")
        legacy.close()

        let reopenedStore = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let model = AppModel(store: reopenedStore, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()

        await model.navigate(to: .activity(projectID))
        let legacyItem = try XCTUnwrap(model.activity(for: projectID)?.items.first {
            $0.identity.sourceID == "history-legacy-event"
        })
        XCTAssertNil(legacyItem.eventFacts)
        await model.openHistoryEntity(legacyItem)
        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.navigationFocus, .recovery)
        XCTAssertEqual(
            model.navigationRecoveryMessage,
            "The event target identity was not recorded; current project state was not substituted for the past."
        )

        let item = try XCTUnwrap(model.activity(for: projectID)?.items.first {
            $0.identity.sourceID == "history-target-event"
        })
        model.setHistoryFilter(.audit, projectID: projectID)
        model.selectHistoryEvent(item.identity, projectID: projectID)
        model.setHistoryViewportOffset(347.25, projectID: projectID)
        model.setNavigationFocus(.historyDetail(item.identity))
        await model.openHistoryEntity(item)

        XCTAssertEqual(model.selection, .phaseBoard(projectID))
        XCTAssertEqual(model.viewedBoard(for: projectID)?.phaseID, phaseID)
        XCTAssertEqual(model.selectedTicketID, ticketID)
        XCTAssertEqual(model.navigationFocus, .ticket(ticketID))

        await model.goBack()

        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), item.identity)
        XCTAssertEqual(model.historyViewportOffset(for: projectID), 347.25)
        XCTAssertEqual(model.navigationFocus, .historyDetail(item.identity))
        XCTAssertNil(model.navigationRecoveryMessage)

        try await reopenedStore.transact(actor: .init(id: "history-navigation-fixture"), reason: "Remove exact synthetic target") { connection in
            try connection.execute(
                "DELETE FROM tickets WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
            )
        }
        await model.reloadDashboardAfterCommittedAgentCommand()
        await model.openHistoryEntity(item)

        XCTAssertEqual(model.selection, .activity(projectID))
        XCTAssertEqual(model.navigationFocus, .recovery)
        XCTAssertEqual(
            model.navigationRecoveryMessage,
            "The exact event target is unavailable; no replacement entity was opened."
        )
    }

    @MainActor
    func testPreferenceResetClearsHistoryViewStateBeforeReopeningSameProject() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-HistoryPreferenceReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: store)
        let projectID = DashboardSampleData.projectID
        let staleEvent = HistoryEventIdentity(
            projectID: projectID,
            registrationID: "history-preference-reset-registration",
            source: .audit,
            sourceID: "history-preference-reset-event"
        )
        let model = AppModel(store: store, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .activity(projectID))
        model.setHistoryFilter(.audit, projectID: projectID)
        model.selectHistoryEvent(staleEvent, projectID: projectID)
        model.setHistoryViewportOffset(412.75, projectID: projectID)
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), staleEvent)
        XCTAssertEqual(model.historyViewportOffset(for: projectID), 412.75)

        await model.resetApplicationPreferences()

        XCTAssertEqual(model.historyFilter(for: projectID), .all)
        XCTAssertNil(model.selectedHistoryEventID(for: projectID))
        XCTAssertNil(model.historyViewportOffset(for: projectID))
        await model.navigate(to: .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .all)
        XCTAssertNil(model.selectedHistoryEventID(for: projectID))
        XCTAssertNil(model.historyViewportOffset(for: projectID))
    }

    @MainActor
    func testAdoptingRecoveryClearsHistoryViewStateBeforeReopeningSameProject() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-HistoryRecoveryReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let originalStore = DeliveryStore(databaseURL: directory.appendingPathComponent("original.sqlite"))
        let replacementStore = DeliveryStore(databaseURL: directory.appendingPathComponent("replacement.sqlite"))
        try await DashboardSampleData.seedIfNeeded(in: originalStore)
        try await DashboardSampleData.seedIfNeeded(in: replacementStore)
        let projectID = DashboardSampleData.projectID
        try await replacementStore.transact(
            actor: .init(id: "history-recovery-reset-fixture"),
            reason: "Register the recovered project generation"
        ) { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'history-recovered-registration', 1, 'complete')",
                bindings: [.text(projectID.rawValue)]
            )
        }
        let staleEvent = HistoryEventIdentity(
            projectID: projectID,
            registrationID: "history-retired-registration",
            source: .audit,
            sourceID: "history-retired-event"
        )
        let model = AppModel(store: originalStore, externalServicesSuppressed: true, seedSampleData: false)
        await model.loadDashboard()
        await model.navigate(to: .activity(projectID))
        model.setHistoryFilter(.audit, projectID: projectID)
        model.selectHistoryEvent(staleEvent, projectID: projectID)
        model.setHistoryViewportOffset(412.75, projectID: projectID)
        XCTAssertEqual(model.historyFilter(for: projectID), .audit)
        XCTAssertEqual(model.selectedHistoryEventID(for: projectID), staleEvent)
        XCTAssertEqual(model.historyViewportOffset(for: projectID), 412.75)

        try await model.adoptRecovery(.init(
            store: replacementStore,
            operationID: UUID(),
            requiresFreshServiceGraph: true,
            newerHistoryWasReconciled: false
        ))

        XCTAssertEqual(model.historyFilter(for: projectID), .all)
        XCTAssertNil(model.selectedHistoryEventID(for: projectID))
        XCTAssertNil(model.historyViewportOffset(for: projectID))
        await model.navigate(to: .activity(projectID))
        XCTAssertEqual(model.historyFilter(for: projectID), .all)
        XCTAssertNil(model.selectedHistoryEventID(for: projectID))
        XCTAssertNil(model.historyViewportOffset(for: projectID))
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

private final class BlockingStoreReadGate: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)

    func waitUntilEntered() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.entered.wait()
                continuation.resume()
            }
        }
    }
}
