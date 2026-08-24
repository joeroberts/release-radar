import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

final class AppRouteTests: XCTestCase {
    @MainActor
    func testCaptureOnlyEmptyStoreModeDoesNotSeedSampleDeliveryData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-EmptyCapture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            seedSampleData: false
        )

        await model.loadDashboard()

        XCTAssertEqual(model.dashboard?.projects.count, 0)
        XCTAssertEqual(model.selection, .projects)
    }

    @MainActor
    func testAppModelLoadsExplicitUnavailableCodexRuntimeState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-CodexState-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let observer = UnavailableCodexObserver(reason: "Shared desktop observation unavailable")
        let model = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite")),
            codexObserver: observer
        )

        await model.loadCodexRuntime()

        XCTAssertEqual(model.codexSnapshot.freshness.state, .unavailable)
        XCTAssertEqual(model.codexSnapshot.freshness.reason, "Shared desktop observation unavailable")
        XCTAssertTrue(model.codexSnapshot.threads.isEmpty)
    }

    func testPrimaryRoutesExposeTheExpectedAccessibleLabelsAndSymbols() {
        let routes = AppRoute.primaryRoutes

        XCTAssertEqual(routes.map(\.title), [
            "Projects",
            "Needs Review",
            "Notifications",
            "Settings",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "folder",
            "checkmark.bubble",
            "bell",
            "gearshape",
        ])
    }

    func testProjectRoutesRetainTheirProjectAndExposeExpectedLabels() {
        let projectID = ProjectID(rawValue: "project-42")
        let routes = AppRoute.projectRoutes(for: projectID)

        XCTAssertEqual(routes, [
            .projectOverview(projectID),
            .phaseBoard(projectID),
            .dependencies(projectID),
            .activity(projectID),
        ])
        XCTAssertEqual(routes.map(\.title), [
            "Overview",
            "Phase Board",
            "Dependencies",
            "Activity",
        ])
        XCTAssertEqual(routes.map(\.systemImage), [
            "rectangle.grid.1x2",
            "rectangle.split.3x1",
            "arrow.triangle.branch",
            "clock.arrow.circlepath",
        ])
    }

    @MainActor
    func testOpeningNonFirstProjectKeepsEveryProjectRouteInThatContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-ProjectRoutes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed route projects") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-a', 'Alpha')")
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-b', 'Beta')")
        }
        let first = ProjectDashboardProjection(
            id: ProjectID(rawValue: "project-a"),
            name: "Alpha",
            activePhaseName: "Alpha phase",
            goalContext: GoalContextProjection(
                linkQuality: .unavailable,
                text: nil,
                status: nil,
                lastObservedAt: nil
            ),
            currentWorkCount: 1,
            attentionCount: 0
        )
        let second = ProjectDashboardProjection(
            id: ProjectID(rawValue: "project-b"),
            name: "Beta",
            activePhaseName: "Beta phase",
            goalContext: GoalContextProjection(
                linkQuality: .verified,
                text: "Ship Beta",
                status: "In progress",
                lastObservedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            currentWorkCount: 2,
            attentionCount: 1
        )
        let model = AppModel(store: store)
        model.dashboard = DashboardProjection(projects: [first, second], boards: [:])

        XCTAssertEqual(model.currentProjectID, first.id)

        await model.openProject(second.id)

        XCTAssertEqual(model.currentProjectID, second.id)
        XCTAssertEqual(model.currentProject?.name, "Beta")
        XCTAssertEqual(AppRoute.projectRoutes(for: model.currentProjectID), [
            .projectOverview(second.id),
            .phaseBoard(second.id),
            .dependencies(second.id),
            .activity(second.id),
        ])

        for route in [
            AppRoute.phaseBoard(second.id),
            .dependencies(second.id),
            .activity(second.id),
        ] {
            model.selection = route
            XCTAssertEqual(model.currentProjectID, second.id)
            XCTAssertEqual(model.currentProject?.name, "Beta")
        }

        model.selection = .projects
        XCTAssertEqual(model.currentProjectID, second.id)
    }

    @MainActor
    func testDirectProjectRoutePersistsDashboardOpenBeforeNotificationEligibility() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-DirectRoute-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "project-direct")
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed direct-route project") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-direct', 'Direct', 0)")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-direct', 'project-direct', ?)", bindings: [.text(projectRoot.path)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-direct', 'project-direct', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('DIRECT-1', 'project-direct', 'phase-direct', 'Direct navigation', 'in_progress')")
        }
        let notificationDispatcher = PushoverNotificationDispatcher(
            store: store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: RouteCountingTransport()
        )
        let coordinator = AppNotificationCoordinator(store: store, dispatcher: notificationDispatcher)
        let model = AppModel(store: store, notificationCoordinator: coordinator)

        await model.navigate(to: .phaseBoard(projectID))
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: projectID, canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
        ])
        let result = await AgentCommandDispatcher(store: store, projectRegistry: registry).dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "91919191-9191-4191-8191-919191919191")!,
            projectRoot: projectRoot.path,
            reason: "Request review after direct navigation",
            command: .requestReview(id: "direct-review", ticketID: "DIRECT-1", kind: "agent_request", summary: "Review")
        ))
        XCTAssertNil(result.error)

        let state = try await store.read { connection in
            (
                try connection.scalarInt("SELECT first_dashboard_opened FROM projects WHERE id = 'project-direct'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-direct'")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(model.selection, .phaseBoard(projectID))
    }
}

private actor RouteCountingTransport: PushoverTransport {
    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        .init(requestID: "unused")
    }
}
