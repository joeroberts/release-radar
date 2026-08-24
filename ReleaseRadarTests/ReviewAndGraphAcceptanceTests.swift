import XCTest
import ReleaseRadarCore
@testable import ReleaseRadar

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
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open')",
                bindings: [
                    .text("duplicate-review"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .text("VD2-08"),
                    .text("duplicate"),
                    .text("Possible duplicate delivery item"),
                ]
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open')",
                bindings: [
                    .text("excluded-review"),
                    .text(DashboardSampleData.projectID.rawValue),
                    .null,
                    .text("excluded_task"),
                    .text("Excluded task needs confirmation"),
                ]
            )
        }
        return store
    }

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
