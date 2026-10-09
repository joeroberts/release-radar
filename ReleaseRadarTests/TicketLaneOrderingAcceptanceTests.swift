import Foundation
import XCTest
@testable import ReleaseRadarCore

final class TicketLaneOrderingAcceptanceTests: XCTestCase {
    func testVersionTwentySevenMigrationSeedsCanonicalOrderAndPreservesExistingState() async throws {
        XCTAssertEqual(StoreMigrations.currentVersion, 27)
        let databaseURL = try makeDatabaseURL()
        let legacy = DeliveryStore(databaseURL: databaseURL)
        let legacyAvailability = await legacy.availability
        XCTAssertEqual(legacyAvailability, .available)

        let proposalBaseline = Data("preserve-the-existing-planning-baseline".utf8)
        try await legacy.transact(
            actor: .init(id: "fixture"),
            reason: "Seed schema-v26 ordering migration fixture",
            auditEventID: .init(rawValue: "seed-v26-ordering")
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('ordering-project','Ordering',1)")
            try connection.execute("INSERT INTO project_roots (id,project_id,path) VALUES ('root-1','ordering-project','/fixture/ordering')")
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('ordering-project','registration-1',1,'complete')")
            try connection.execute("""
                INSERT INTO phases (id,project_id,name) VALUES
                ('phase-b','ordering-project','alpha'),
                ('phase-a','ordering-project','Alpha'),
                ('phase-c','ordering-project','Beta')
                """)
            try connection.execute("""
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                ('ticket-b1','ordering-project','phase-b','B1','backlog'),
                ('ticket-a1','ordering-project','phase-a','A1','backlog'),
                ('ticket-a2','ordering-project','phase-a','A2','backlog'),
                ('ticket-c1','ordering-project','phase-c','C1','backlog'),
                ('ticket-review','ordering-project','phase-a','Review','needs_review'),
                ('ticket-retired','ordering-project','phase-a','Retired','backlog'),
                ('ticket-unassigned','ordering-project',NULL,'Unassigned',NULL)
                """)
            try connection.execute("""
                INSERT INTO ticket_retirements (
                    project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at
                ) VALUES (
                    'ordering-project','ticket-retired','withdrawn','Retired fixture work',
                    'phase-a','backlog','seed-v26-ordering','2026-10-09T00:00:00Z'
                )
                """)
            try connection.execute("""
                INSERT INTO plan_change_proposals (
                    project_id,id,current_version,created_at,updated_at
                ) VALUES (
                    'ordering-project','existing-proposal',1,
                    '2026-10-09T00:00:00Z','2026-10-09T00:00:00Z'
                )
                """)
            try connection.execute("""
                INSERT INTO plan_change_proposal_versions (
                    project_id,proposal_id,version,registration_id,request_generation,
                    baseline_digest,baseline_data,operations_data,diff_data,source_impacts_data,
                    rationale,created_at
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
                """, bindings: [
                    .text("ordering-project"), .text("existing-proposal"), .integer(1),
                    .text("registration-1"), .integer(1), .text(String(repeating: "a", count: 64)),
                    .blob(proposalBaseline), .blob(Data("[]".utf8)), .blob(Data("{}".utf8)),
                    .blob(Data("[]".utf8)), .text("Preserve this saved proposal exactly."),
                    .text("2026-10-09T00:00:00Z"),
                ])
        }

        let ticketsBefore = try await legacy.read { connection in
            try connection.rows(
                "SELECT id,phase_id,outcome,lane,plan_legacy_continuation FROM tickets WHERE project_id='ordering-project' ORDER BY id COLLATE BINARY"
            )
        }
        let proposalBefore = try await legacy.read { connection in
            try XCTUnwrap(connection.row(
                "SELECT * FROM plan_change_proposal_versions WHERE project_id='ordering-project' AND proposal_id='existing-proposal' AND version=1"
            ))
        }
        await legacy.close()

        let versionTwentySix = try SQLiteConnection(url: databaseURL)
        try versionTwentySix.execute("DROP TABLE ticket_lane_order")
        try versionTwentySix.execute("PRAGMA user_version = 26")
        versionTwentySix.close()

        let migrated = DeliveryStore(databaseURL: databaseURL)
        let migratedAvailability = await migrated.availability
        XCTAssertEqual(migratedAvailability, .available)
        let facts = try await migrated.read { connection in
            let backlogRows = try connection.rows(
                "SELECT ticket_id,order_key FROM ticket_lane_order WHERE project_id='ordering-project' AND lane='backlog' ORDER BY order_key COLLATE BINARY"
            )
            let reviewRows = try connection.rows(
                "SELECT ticket_id,order_key FROM ticket_lane_order WHERE project_id='ordering-project' AND lane='needs_review' ORDER BY order_key COLLATE BINARY"
            )
            return (
                version: try connection.scalarInt("PRAGMA user_version"),
                backlogRows: backlogRows,
                reviewRows: reviewRows,
                tickets: try connection.rows(
                    "SELECT id,phase_id,outcome,lane,plan_legacy_continuation FROM tickets WHERE project_id='ordering-project' ORDER BY id COLLATE BINARY"
                ),
                proposal: try XCTUnwrap(connection.row(
                    "SELECT * FROM plan_change_proposal_versions WHERE project_id='ordering-project' AND proposal_id='existing-proposal' AND version=1"
                )),
                orphanOrderCount: try connection.scalarInt("""
                    SELECT COUNT(*) FROM ticket_lane_order
                    WHERE project_id='ordering-project'
                      AND ticket_id IN ('ticket-retired','ticket-unassigned')
                    """),
            )
        }

        XCTAssertEqual(facts.version, 27)
        XCTAssertEqual(facts.backlogRows.compactMap { orderingText($0["ticket_id"]) }, [
            "ticket-a1", "ticket-a2", "ticket-b1", "ticket-c1",
        ])
        XCTAssertEqual(facts.reviewRows.compactMap { orderingText($0["ticket_id"]) }, ["ticket-review"])
        let backlogKeys = facts.backlogRows.compactMap { orderingText($0["order_key"]) }
        XCTAssertEqual(Set(backlogKeys).count, 4)
        XCTAssertEqual(Set(backlogKeys.map(\.count)).count, 1, "Migration keys must use one sufficient fixed width per lane")
        XCTAssertTrue(backlogKeys.allSatisfy { !$0.isEmpty && $0.last == "1" && $0.allSatisfy { $0 == "0" || $0 == "1" } })
        XCTAssertEqual(facts.orphanOrderCount, 0)
        XCTAssertEqual(facts.tickets, ticketsBefore)
        XCTAssertEqual(facts.proposal, proposalBefore)
        XCTAssertEqual(facts.proposal["baseline_data"], .blob(proposalBaseline))

        await migrated.close()
        let reopened = DeliveryStore(databaseURL: databaseURL)
        let reopenedAvailability = await reopened.availability
        XCTAssertEqual(reopenedAvailability, .available)
        let reopenedOrder = try await reopened.read { connection in
            try connection.rows(
                "SELECT ticket_id,lane,order_key FROM ticket_lane_order WHERE project_id='ordering-project' ORDER BY lane,order_key COLLATE BINARY"
            )
        }
        XCTAssertEqual(reopenedOrder.count, 5)
    }

    func testExactPrefixAllocationMovesOnlyTargetAndPreservesProtectedAnchorsAndProposalBaseline() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("store.sqlite"))
        let storeAvailability = await store.availability
        XCTAssertEqual(storeAvailability, .available)
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "ordering-project"),
            registrationID: "registration-1",
            requestGeneration: 1
        )

        try await store.transact(actor: .init(id: "fixture"), reason: "Seed exact rank fixture") { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('ordering-project','Ordering',1)")
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('root-1','ordering-project',?)",
                bindings: [.text(root.path)]
            )
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('ordering-project','registration-1',1,'complete')")
            try connection.execute("""
                INSERT INTO phases (id,project_id,name) VALUES
                ('phase-left','ordering-project','Left protected'),
                ('phase-open','ordering-project','Open'),
                ('phase-right','ordering-project','Right protected')
                """)
            try connection.execute("""
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                ('left-anchor','ordering-project','phase-left','Left','backlog'),
                ('moving','ordering-project','phase-open','Moving','backlog'),
                ('right-anchor','ordering-project','phase-right','Right','backlog')
                """)
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='completed',revision=1,completion_baseline_digest=?,completed_at='2026-10-09T00:00:00Z',updated_at='2026-10-09T00:00:00Z' WHERE project_id='ordering-project' AND phase_id IN ('phase-left','phase-right')", bindings: [.text(String(repeating: "b", count: 64))])
            try connection.execute("DELETE FROM ticket_lane_order WHERE project_id='ordering-project'")
            try connection.execute("""
                INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key) VALUES
                ('ordering-project','moving','backlog','001'),
                ('ordering-project','left-anchor','backlog','01'),
                ('ordering-project','right-anchor','backlog','011')
                """)
        }

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: root, authorizedRoots: [root]),
            ])
        )
        let before = try await orderingState(store)
        let planningBaselineBefore = try await store.read {
            try PlanningBaseline.capture(projectID: registration.projectID, connection: $0)
        }
        let snapshot = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0)
        }
        XCTAssertEqual(snapshot.ticketIDs(in: .backlog), [
            .init(rawValue: "moving"), .init(rawValue: "left-anchor"), .init(rawValue: "right-anchor"),
        ])

        let requestID = UUID(uuidString: "00000000-0000-4000-8000-000000000124")!
        let envelope = AgentCommandEnvelope(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: root.path,
            expectedRegistration: registration,
            reason: "Place moving after left-anchor",
            command: .reorderTicket(
                projectID: registration.projectID.rawValue,
                ticketID: "moving",
                expectedLane: .backlog,
                anchor: .after(.init(rawValue: "left-anchor")),
                expectedOrderingContext: snapshot.context
            )
        )
        let result = await dispatcher.dispatch(envelope, origin: .ownerApp)
        XCTAssertNil(result.error)
        let auditEventID = try XCTUnwrap(result.auditEventID)

        let after = try await orderingState(store)
        XCTAssertEqual(after.orderByTicket["left-anchor"], "01")
        XCTAssertEqual(after.orderByTicket["moving"], "0101")
        XCTAssertEqual(after.orderByTicket["right-anchor"], "011")
        XCTAssertEqual(after.orderByTicket.filter { $0.key != "moving" }, before.orderByTicket.filter { $0.key != "moving" })
        XCTAssertEqual(after.protectedTicketRows, before.protectedTicketRows)
        XCTAssertEqual(after.protectedLifecycleRows, before.protectedLifecycleRows)
        XCTAssertEqual(after.nonOrderState, before.nonOrderState)

        let planningBaselineAfter = try await store.read {
            try PlanningBaseline.capture(projectID: registration.projectID, connection: $0)
        }
        XCTAssertEqual(planningBaselineAfter, planningBaselineBefore, "Ordering stays outside PlanningBaseline v1")
        let committed = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0)
        }
        XCTAssertEqual(committed.ticketIDs(in: .backlog), [
            .init(rawValue: "left-anchor"), .init(rawValue: "moving"), .init(rawValue: "right-anchor"),
        ])
        XCTAssertEqual(result.ticketOrderingContext, committed.context)
        XCTAssertNotEqual(committed.context, snapshot.context)

        let replay = await dispatcher.dispatch(envelope, origin: .ownerApp)
        XCTAssertEqual(replay, result)
        let atomicFacts = try await store.read { connection in
            (
                receipts: try connection.scalarInt(
                    "SELECT COUNT(*) FROM agent_command_requests WHERE request_id=?",
                    bindings: [.text(requestID.uuidString)]
                ),
                audits: try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE id=?",
                    bindings: [.text(auditEventID.rawValue)]
                ),
                orderRows: try connection.scalarInt(
                    "SELECT COUNT(*) FROM ticket_lane_order WHERE project_id='ordering-project' AND lane='backlog'"
                )
            )
        }
        XCTAssertEqual(atomicFacts.receipts, 1)
        XCTAssertEqual(atomicFacts.audits, 1)
        XCTAssertEqual(atomicFacts.orderRows, 3)
    }

    private struct OrderingState: Sendable {
        let orderByTicket: [String: String]
        let protectedTicketRows: [[String: SQLiteValue]]
        let protectedLifecycleRows: [[String: SQLiteValue]]
        let nonOrderState: [[String: SQLiteValue]]
    }

    private func orderingState(_ store: DeliveryStore) async throws -> OrderingState {
        try await store.read { connection in
            let orderRows = try connection.rows(
                "SELECT ticket_id,order_key FROM ticket_lane_order WHERE project_id='ordering-project' ORDER BY ticket_id COLLATE BINARY"
            )
            return OrderingState(
                orderByTicket: Dictionary(uniqueKeysWithValues: try orderRows.map { row in
                    guard let ticket = orderingText(row["ticket_id"]), let key = orderingText(row["order_key"]) else {
                        throw StoreError.unavailable("Malformed ordering test row")
                    }
                    return (ticket, key)
                }),
                protectedTicketRows: try connection.rows(
                    "SELECT * FROM tickets WHERE project_id='ordering-project' AND id IN ('left-anchor','right-anchor') ORDER BY id COLLATE BINARY"
                ),
                protectedLifecycleRows: try connection.rows(
                    "SELECT * FROM phase_lifecycles WHERE project_id='ordering-project' AND phase_id IN ('phase-left','phase-right') ORDER BY phase_id COLLATE BINARY"
                ),
                nonOrderState: try connection.rows("""
                    SELECT 'ticket' AS kind,id AS identity,phase_id AS value1,lane AS value2
                    FROM tickets WHERE project_id='ordering-project'
                    UNION ALL
                    SELECT 'registration',registration_id,CAST(request_generation AS TEXT),setup_state
                    FROM project_registrations WHERE project_id='ordering-project'
                    ORDER BY kind,identity
                    """)
            )
        }
    }

    private func makeDatabaseURL() throws -> URL {
        try makeFixtureRoot().appendingPathComponent("store.sqlite")
    }

    private func makeFixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-ticket-ordering-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

}

private func orderingText(_ value: SQLiteValue?) -> String? {
    guard case let .text(value)? = value else { return nil }
    return value
}
