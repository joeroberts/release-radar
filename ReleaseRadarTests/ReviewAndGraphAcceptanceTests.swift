import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

@MainActor
final class ReviewAndGraphAcceptanceTests: XCTestCase {
    private var databaseURL: URL!
    private var projectRoot: URL!

    override func setUpWithError() throws {
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-review-graph-\(UUID().uuidString).sqlite")
        projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("pre-migration"))
        try? FileManager.default.removeItem(at: projectRoot)
        databaseURL = nil
        projectRoot = nil
    }

    func testTypedBridgeResolvesAndDismissesSupportedReviewKindsWithAuditAndNoLaneMutation() async throws {
        let store = try await seededStore()
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            AuthorizedProject(
                projectID: DashboardSampleData.projectID,
                canonicalRoot: projectRoot,
                authorizedRoots: [projectRoot]
            ),
        ])
        let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: registry)

        let resolved = await dispatcher.dispatch(envelope(
            reason: "Resolve duplicate review duplicate-review",
            command: .resolveImportReview(reviewItemID: "duplicate-review")
        ))
        let dismissed = await dispatcher.dispatch(envelope(
            reason: "Dismiss excluded task review excluded-review",
            command: .dismissImportReview(reviewItemID: "excluded-review")
        ))

        XCTAssertNil(resolved.error)
        XCTAssertNotNil(resolved.auditEventID)
        XCTAssertNil(dismissed.error)
        XCTAssertNotNil(dismissed.auditEventID)
        let state = try await store.read { connection in
            (
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'duplicate-review'"),
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'excluded-review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE actor_id = 'release-radar-agent'"),
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'VD2-08'")
            )
        }
        XCTAssertEqual(state.0, "resolved")
        XCTAssertEqual(state.1, "dismissed")
        XCTAssertEqual(state.2, 2)
        XCTAssertEqual(state.3, TicketLane.inProgress.rawValue)
    }

    func testPersistedInboxProjectsEverySupportedOpenReviewKindAcrossRelaunch() async throws {
        _ = try await seededStore()

        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
        let inbox = try await ReviewInboxProjection.load(
            from: relaunchedStore,
            projectID: DashboardSampleData.projectID
        )

        XCTAssertEqual(inbox.openItems.map(\.kind), [
            .uncertainImport,
            .duplicate,
            .unresolvedDependency,
            .unmatchedTask,
            .excludedTask,
            .agentReviewRequest,
        ])
        XCTAssertEqual(inbox.openItems.map(\.ticketID?.rawValue), [
            nil, "VD2-08", "UX-D12", nil, nil, "VD2-07c",
        ])
        XCTAssertTrue(inbox.completedItems.isEmpty)
        XCTAssertEqual(inbox.openItems.first?.summary, "Import mapping needs owner confirmation")
    }

    func testFreshSampleSeedSuppliesTheSupportedReviewInbox() async throws {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)

        let inbox = try await ReviewInboxProjection.load(
            from: store,
            projectID: DashboardSampleData.projectID
        )

        XCTAssertEqual(inbox.openItems.map(\.kind), [
            .uncertainImport,
            .duplicate,
            .unresolvedDependency,
            .unmatchedTask,
            .excludedTask,
            .agentReviewRequest,
        ])
    }

    func testDependencyGraphProjectsTransitiveDirectionAndPreciseMultiEdgeEndpoints() async throws {
        let store = try await seededStore()
        let selectedID = TicketID(rawValue: "VD2-08")

        let graph = try await DependencyGraphProjection.load(
            from: store,
            projectID: DashboardSampleData.projectID,
            phaseID: DashboardSampleData.phaseID,
            selectedTicketID: selectedID
        )

        XCTAssertEqual(graph.selected.directRequires.map(\.id.rawValue), ["VD2-06", "VD2-07"])
        XCTAssertEqual(graph.selected.indirectRequires.map(\.id.rawValue), ["VD2-03", "VD2-04", "VD2-05"])
        XCTAssertEqual(graph.selected.unlocks.map(\.id.rawValue), ["DESIGN-V2", "P2A-1", "UX-D12"])
        XCTAssertEqual(graph.node(id: TicketID(rawValue: "UX-D12"))?.blockerCount, 1)
        XCTAssertEqual(graph.node(id: selectedID)?.lane, .inProgress)

        let layout = DependencyGraphLayout.makeLayout(
            graph: graph,
            size: CGSize(width: 960, height: 520)
        )
        XCTAssertEqual(layout.connectors.count, graph.edges.count)
        let selectedConnectors = layout.connectors.filter { $0.targetID == selectedID }
        XCTAssertEqual(selectedConnectors.count, 4)
        XCTAssertEqual(Set(selectedConnectors.map(\.sourceID.rawValue)), ["VD2-03", "VD2-04", "VD2-06", "VD2-07"])
        for connector in layout.connectors {
            let sourceFrame = try XCTUnwrap(layout.frames[connector.sourceID])
            let targetFrame = try XCTUnwrap(layout.frames[connector.targetID])
            XCTAssertEqual(connector.start, CGPoint(x: sourceFrame.maxX, y: sourceFrame.midY))
            XCTAssertEqual(connector.end, CGPoint(x: targetFrame.minX, y: targetFrame.midY))
        }
    }

    func testDependencyGraphExcludesCrossPhaseEdgesFromRelationshipsAndConnectors() async throws {
        let store = try await seededStore()
        try await store.transact(
            actor: DeliveryActor(id: "rr07-test"),
            reason: "Seed permitted cross-phase dependency bridge"
        ) { connection in
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
                bindings: [
                    .text("rr07-other-phase"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .text("Later phase"),
                ]
            )
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
                bindings: [
                    .text("CROSS-BRIDGE"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .text("rr07-other-phase"),
                    .text("Bridge work across phases"),
                    .text(TicketLane.backlog.rawValue),
                ]
            )
            try connection.execute(
                "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES (?, ?, ?, ?)",
                bindings: [
                    .text("rr07-cross-in"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .text("CROSS-BRIDGE"),
                    .text("VD2-06"),
                ]
            )
            try connection.execute(
                "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES (?, ?, ?, ?)",
                bindings: [
                    .text("rr07-cross-out"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .text("VD2-07"),
                    .text("CROSS-BRIDGE"),
                ]
            )
        }

        let graph = try await DependencyGraphProjection.load(
            from: store,
            projectID: DashboardSampleData.projectID,
            phaseID: DashboardSampleData.phaseID,
            selectedTicketID: TicketID(rawValue: "VD2-08")
        )
        let nodeIDs = Set(graph.nodes.map(\.id))
        let layout = DependencyGraphLayout.makeLayout(
            graph: graph,
            size: CGSize(width: 960, height: 520)
        )

        XCTAssertTrue(graph.edges.allSatisfy {
            nodeIDs.contains($0.sourceID) && nodeIDs.contains($0.targetID)
        })
        XCTAssertEqual(graph.selected.directRequires.map(\.id.rawValue), ["VD2-06", "VD2-07"])
        XCTAssertEqual(graph.selected.indirectRequires.map(\.id.rawValue), ["VD2-03", "VD2-04", "VD2-05"])
        XCTAssertEqual(graph.selected.unlocks.map(\.id.rawValue), ["DESIGN-V2", "P2A-1", "UX-D12"])
        XCTAssertEqual(layout.connectors.count, graph.edges.count)
        XCTAssertTrue(layout.connectors.allSatisfy {
            layout.frames[$0.sourceID] != nil && layout.frames[$0.targetID] != nil
        })
    }

    func testActivityCombinesPersistedSourcesAndKeepsRuntimeSeparateFromDeliveryLane() async throws {
        let store = try await seededStore()
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            AuthorizedProject(
                projectID: DashboardSampleData.projectID,
                canonicalRoot: projectRoot,
                authorizedRoots: [projectRoot]
            ),
        ])
        let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: registry)
        _ = await dispatcher.dispatch(envelope(
            reason: "Resolve agent-review after owner validation",
            command: .resolveImportReview(reviewItemID: "agent-review")
        ))
        _ = await dispatcher.dispatch(envelope(
            reason: "Record UX-D10 completion",
            command: .recordCompletion(
                id: "rr07-completion",
                ticketID: "UX-D10",
                summary: "Agent completed export confirmation"
            )
        ))

        let activity = try await ProjectActivityProjection.load(
            from: store,
            projectID: DashboardSampleData.projectID
        )

        XCTAssertTrue(activity.items.contains { $0.source == .audit })
        XCTAssertTrue(activity.items.contains { $0.source == .runtime })
        XCTAssertTrue(activity.items.contains { $0.source == .review })
        XCTAssertTrue(activity.items.contains { $0.source == .completion })
        XCTAssertTrue(activity.items.contains { $0.source == .notification })
        let runtime = try XCTUnwrap(activity.items.first { $0.source == .runtime && $0.ticketID?.rawValue == "VD2-07c" })
        XCTAssertEqual(runtime.runtimeState?.title, "Blocked")
        XCTAssertEqual(runtime.deliveryLane, .blocked)
        XCTAssertTrue(runtime.freshnessText?.hasPrefix("Last seen ") == true)
        XCTAssertFalse(activity.items.contains {
            $0.title.lowercased().split(separator: " ").contains("live")
        })
        XCTAssertEqual(RuntimeStateLanguage(storedValue: "active").title, "Active")
        XCTAssertEqual(RuntimeStateLanguage(storedValue: "paused").title, "Paused")
        XCTAssertEqual(RuntimeStateLanguage(storedValue: "awaiting_input").title, "Awaiting input")
        XCTAssertEqual(RuntimeStateLanguage(storedValue: "completed").title, "Completed")
        XCTAssertEqual(RuntimeStateLanguage(storedValue: "missing").title, "Unavailable")
    }

    func testSettingsTabsAndNavigationExposeTruthfulAccessibleSurfacesWithoutDuplicateNotificationBadge() {
        XCTAssertEqual(SettingsTab.allCases.map(\.title), [
            "General", "Connections", "Notifications", "Projects",
        ])
        XCTAssertEqual(Set(SettingsTab.allCases.map(\.accessibilityID)).count, 4)
        let unavailable = CodexConnectionPresentation(
            freshness: CodexObservationFreshness(
                state: .unavailable,
                lastObservedAt: nil,
                reason: "No supported attachment"
            )
        )
        let stale = CodexConnectionPresentation(
            freshness: CodexObservationFreshness(
                state: .stale,
                lastObservedAt: Date(timeIntervalSince1970: 1_700_000_000),
                reason: "Codex is offline"
            )
        )
        XCTAssertEqual(unavailable.status, "Unavailable")
        XCTAssertEqual(unavailable.detail, "No supported attachment")
        XCTAssertEqual(stale.status, "Stale")
        XCTAssertTrue(stale.detail.hasPrefix("Last seen "))
        XCTAssertEqual(AppRoute.phaseBoard(DashboardSampleData.projectID).systemImage, "rectangle.split.3x1")
        XCTAssertEqual(AppRoute.notifications.systemImage, "bell")
        XCTAssertEqual(SidebarBadgePolicy.badgedRoutes, [.needsReview, .notifications])
        XCTAssertEqual(SidebarBadgePolicy.notificationBadgeSurfaceCount, 1)
    }

    @MainActor
    func testAppModelLoadsProjectWorkspaceAndSurfacesReviewActionFailure() async throws {
        let store = try await seededStore()
        let model = AppModel(store: store)

        await model.loadDashboard()

        XCTAssertEqual(model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.count, 6)
        XCTAssertEqual(model.dependencyGraph(for: DashboardSampleData.projectID)?.selected.ticket.id.rawValue, "VD2-08")
        XCTAssertFalse(model.activity(for: DashboardSampleData.projectID)?.items.isEmpty == true)

        try await store.transact(
            actor: DeliveryActor(id: "rr07-test"),
            reason: "Remove root to exercise visible failure"
        ) { connection in
            try connection.execute(
                "DELETE FROM project_roots WHERE project_id = ?",
                bindings: [.text(DashboardSampleData.projectID.rawValue)]
            )
        }
        let item = try XCTUnwrap(model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.first)
        await model.performReviewDecision(.resolve, item: item)

        XCTAssertTrue(model.reviewActionError?.localizedCaseInsensitiveContains("authorized project root") == true)
        XCTAssertEqual(model.reviewInbox(for: DashboardSampleData.projectID)?.openItems.count, 6)
    }

    @MainActor
    private func seededStore() async throws -> DeliveryStore {
        let store = DeliveryStore(databaseURL: databaseURL)
        try await DashboardSampleData.seedIfNeeded(in: store)
        let rootPath = projectRoot.path
        try await store.transact(
            actor: DeliveryActor(id: "rr07-test-seed"),
            reason: "Seed supported review kinds"
        ) { connection in
            try connection.execute(
                "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
                bindings: [
                    .text("rr07-test-root"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .text(rootPath),
                ]
            )
            let reviews: [(String, String?, String, String)] = [
                ("import-review", nil, "uncertain_import", "Import mapping needs owner confirmation"),
                ("duplicate-review", "VD2-08", "duplicate", "Possible duplicate delivery item"),
                ("dependency-review", "UX-D12", "unresolved_dependency", "Dependency target could not be resolved"),
                ("unmatched-review", nil, "unmatched_task", "Task does not match this project"),
                ("excluded-review", nil, "excluded_task", "Excluded task needs confirmation"),
                ("agent-review", "VD2-07c", "agent_review_request", "Agent requested owner validation"),
            ]
            for review in reviews {
                try connection.execute(
                    "INSERT OR IGNORE INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open')",
                    bindings: [
                        .text(review.0),
                        .text(DashboardSampleData.projectID.rawValue),
                        review.1.map(SQLiteValue.text) ?? .null,
                        .text(review.2),
                        .text(review.3),
                    ]
                )
            }
        }
        return store
    }

    @MainActor
    private func envelope(reason: String, command: AgentCommand) -> AgentCommandEnvelope {
        AgentCommandEnvelope(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(),
            projectRoot: projectRoot.path,
            assertedThreadID: "rr07-review-thread",
            reason: reason,
            command: command
        )
    }
}
