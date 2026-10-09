import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

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
        let migratedVersionConnection = try SQLiteConnection(url: databaseURL, createIfMissing: false)
        let migratedVersion = try migratedVersionConnection.scalarInt("PRAGMA user_version")
        migratedVersionConnection.close()
        let facts = try await migrated.read { connection in
            let backlogRows = try connection.rows(
                "SELECT ticket_id,order_key FROM ticket_lane_order WHERE project_id='ordering-project' AND lane='backlog' ORDER BY order_key COLLATE BINARY"
            )
            let reviewRows = try connection.rows(
                "SELECT ticket_id,order_key FROM ticket_lane_order WHERE project_id='ordering-project' AND lane='needs_review' ORDER BY order_key COLLATE BINARY"
            )
            return (
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

        XCTAssertEqual(migratedVersion, 27)
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
        let store = DeliveryStore(
            databaseURL: root.appendingPathComponent("store.sqlite"),
            executionAssignmentRoot: {
                throw StoreError.unavailable("Ordering must not invoke execution reconciliation")
            }
        )
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

        let staleOrderRequest = UUID(uuidString: "00000000-0000-4000-8000-000000000128")!
        let staleOrderResult = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: staleOrderRequest,
            reason: "Reject changed order context",
            ticketID: "moving",
            anchor: .after(.init(rawValue: "right-anchor")),
            context: snapshot.context
        ), origin: .ownerApp)
        XCTAssertEqual(staleOrderResult.error, .ticketOrdering(.staleContext))
        try await assertNoCommandCommit(store, requestID: staleOrderRequest, reason: "Reject changed order context")

        let replay = await dispatcher.dispatch(envelope, origin: .ownerApp)
        XCTAssertEqual(replay, result)
        let externalReplay = await dispatcher.dispatch(envelope)
        XCTAssertEqual(externalReplay.error, .ticketOrdering(.ownerAuthorityRequired))
        let unauthorizedRootReplay = await dispatcher.dispatch(.init(
            version: envelope.version,
            requestID: envelope.requestID,
            projectRoot: root.appendingPathComponent("outside").path,
            expectedRegistration: registration,
            reason: envelope.reason,
            command: envelope.command
        ), origin: .ownerApp)
        XCTAssertEqual(unauthorizedRootReplay.error, .unauthorizedProjectRoot)
        let staleRegistrationReplay = await dispatcher.dispatch(.init(
            version: envelope.version,
            requestID: envelope.requestID,
            projectRoot: root.path,
            expectedRegistration: .init(
                projectID: registration.projectID,
                registrationID: "stale-registration",
                requestGeneration: registration.requestGeneration
            ),
            reason: envelope.reason,
            command: envelope.command
        ), origin: .ownerApp)
        XCTAssertEqual(staleRegistrationReplay.error, .staleProjectRegistration)
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

    func testDependencyValidationUsesAffectedPositionsAndTheCompleteStoredGraph() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("store.sqlite"))
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "ordering-project"),
            registrationID: "registration-1",
            requestGeneration: 1
        )
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed dependency ordering fixture",
            auditEventID: .init(rawValue: "seed-dependency-ordering")
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('ordering-project','Ordering',1)")
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('root-1','ordering-project',?)",
                bindings: [.text(root.path)]
            )
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('ordering-project','registration-1',1,'complete')")
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase-open','ordering-project','Open')")
            try connection.execute("""
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                ('free-start','ordering-project','phase-open','Free start','backlog'),
                ('satisfied-prerequisite','ordering-project','phase-open','Satisfied path start','backlog'),
                ('satisfied-dependent','ordering-project','phase-open','Satisfied path end','backlog'),
                ('direct-prerequisite','ordering-project','phase-open','Direct prerequisite','backlog'),
                ('direct-dependent','ordering-project','phase-open','Direct dependent','backlog'),
                ('indirect-prerequisite','ordering-project','phase-open','Indirect prerequisite','backlog'),
                ('indirect-dependent','ordering-project','phase-open','Indirect dependent','backlog'),
                ('retired-prerequisite','ordering-project','phase-open','Retired path start','backlog'),
                ('retired-dependent','ordering-project','phase-open','Retired path end','backlog'),
                ('null-prerequisite','ordering-project','phase-open','Null path start','backlog'),
                ('null-dependent','ordering-project','phase-open','Null path end','backlog'),
                ('untouched-dependent','ordering-project','phase-open','Legacy invalid dependent','backlog'),
                ('untouched-prerequisite','ordering-project','phase-open','Legacy invalid prerequisite','backlog'),
                ('free-one','ordering-project','phase-open','Free one','backlog'),
                ('offlane-dependent','ordering-project','phase-open','Off-lane dependent','backlog'),
                ('free-two','ordering-project','phase-open','Free two','backlog'),
                ('accepted-middle','ordering-project','phase-open','Accepted middle','accepted'),
                ('indirect-middle','ordering-project','phase-open','Indirect middle','blocked'),
                ('offlane-prerequisite','ordering-project','phase-open','Off-lane prerequisite','blocked'),
                ('retired-middle','ordering-project','phase-open','Retired middle','backlog'),
                ('null-middle','ordering-project',NULL,'Unassigned middle',NULL)
                """)
            try connection.execute("""
                INSERT INTO ticket_retirements (
                    project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at
                ) VALUES (
                    'ordering-project','retired-middle','withdrawn','Retired dependency evidence',
                    'phase-open','backlog','seed-dependency-ordering','2026-10-09T00:00:00Z'
                )
                """)
            try connection.execute("""
                INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES
                ('direct','ordering-project','direct-dependent','direct-prerequisite'),
                ('indirect-1','ordering-project','indirect-middle','indirect-prerequisite'),
                ('indirect-2','ordering-project','indirect-dependent','indirect-middle'),
                ('accepted-1','ordering-project','accepted-middle','satisfied-prerequisite'),
                ('accepted-2','ordering-project','satisfied-dependent','accepted-middle'),
                ('retired-1','ordering-project','retired-middle','retired-prerequisite'),
                ('retired-2','ordering-project','retired-dependent','retired-middle'),
                ('null-1','ordering-project','null-middle','null-prerequisite'),
                ('null-2','ordering-project','null-dependent','null-middle'),
                ('untouched','ordering-project','untouched-dependent','untouched-prerequisite'),
                ('offlane','ordering-project','offlane-dependent','offlane-prerequisite')
                """)
            try connection.execute("DELETE FROM ticket_lane_order WHERE project_id='ordering-project'")
            try connection.execute("""
                INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key) VALUES
                ('ordering-project','free-start','backlog','00001'),
                ('ordering-project','satisfied-prerequisite','backlog','00011'),
                ('ordering-project','satisfied-dependent','backlog','00101'),
                ('ordering-project','direct-prerequisite','backlog','00111'),
                ('ordering-project','direct-dependent','backlog','01001'),
                ('ordering-project','indirect-prerequisite','backlog','01011'),
                ('ordering-project','indirect-dependent','backlog','01101'),
                ('ordering-project','retired-prerequisite','backlog','01111'),
                ('ordering-project','retired-dependent','backlog','10001'),
                ('ordering-project','null-prerequisite','backlog','10011'),
                ('ordering-project','null-dependent','backlog','10101'),
                ('ordering-project','untouched-dependent','backlog','10111'),
                ('ordering-project','untouched-prerequisite','backlog','11001'),
                ('ordering-project','free-one','backlog','11011'),
                ('ordering-project','offlane-dependent','backlog','11101'),
                ('ordering-project','free-two','backlog','11111'),
                ('ordering-project','accepted-middle','accepted','1'),
                ('ordering-project','indirect-middle','blocked','01'),
                ('ordering-project','offlane-prerequisite','blocked','11')
                """)
        }
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: root, authorizedRoots: [root]),
            ])
        )
        let initial = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0)
        }
        let originalOrder = try await orderRows(store)

        struct ConflictScenario {
            let requestID: UUID
            let ticketID: String
            let anchor: TicketOrderAnchor
            let prerequisite: String
            let dependent: String
            let chain: [String]
        }
        let conflicts = [
            ConflictScenario(
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000130")!,
                ticketID: "direct-dependent", anchor: .before(.init(rawValue: "direct-prerequisite")),
                prerequisite: "direct-prerequisite", dependent: "direct-dependent",
                chain: ["direct-prerequisite", "direct-dependent"]
            ),
            ConflictScenario(
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000131")!,
                ticketID: "direct-prerequisite", anchor: .after(.init(rawValue: "direct-dependent")),
                prerequisite: "direct-prerequisite", dependent: "direct-dependent",
                chain: ["direct-prerequisite", "direct-dependent"]
            ),
            ConflictScenario(
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000132")!,
                ticketID: "indirect-dependent", anchor: .before(.init(rawValue: "indirect-prerequisite")),
                prerequisite: "indirect-prerequisite", dependent: "indirect-dependent",
                chain: ["indirect-prerequisite", "indirect-middle", "indirect-dependent"]
            ),
            ConflictScenario(
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000133")!,
                ticketID: "retired-dependent", anchor: .before(.init(rawValue: "retired-prerequisite")),
                prerequisite: "retired-prerequisite", dependent: "retired-dependent",
                chain: ["retired-prerequisite", "retired-middle", "retired-dependent"]
            ),
            ConflictScenario(
                requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000134")!,
                ticketID: "null-dependent", anchor: .before(.init(rawValue: "null-prerequisite")),
                prerequisite: "null-prerequisite", dependent: "null-dependent",
                chain: ["null-prerequisite", "null-middle", "null-dependent"]
            ),
        ]
        for scenario in conflicts {
            let reason = "Reject dependency conflict \(scenario.requestID.uuidString)"
            let result = await dispatcher.dispatch(orderEnvelope(
                root: root,
                registration: registration,
                requestID: scenario.requestID,
                reason: reason,
                ticketID: scenario.ticketID,
                anchor: scenario.anchor,
                context: initial.context
            ), origin: .ownerApp)
            guard case let .ticketOrdering(.dependencyConflict(conflict))? = result.error else {
                XCTFail("Expected typed dependency conflict, got \(String(describing: result.error))")
                continue
            }
            XCTAssertEqual(conflict.prerequisiteTicketID, .init(rawValue: scenario.prerequisite))
            XCTAssertEqual(conflict.dependentTicketID, .init(rawValue: scenario.dependent))
            XCTAssertEqual(conflict.witnessChain, scenario.chain.map(TicketID.init(rawValue:)))
            XCTAssertEqual(conflict.lane, .backlog)
            XCTAssertEqual(conflict.prerequisitePhaseID, .init(rawValue: "phase-open"))
            XCTAssertEqual(conflict.prerequisitePhaseName, "Open")
            XCTAssertEqual(conflict.dependentPhaseID, .init(rawValue: "phase-open"))
            XCTAssertEqual(conflict.dependentPhaseName, "Open")
            try await assertNoCommandCommit(store, requestID: scenario.requestID, reason: reason)
        }
        let orderAfterRejections = try await orderRows(store)
        XCTAssertEqual(orderAfterRejections, originalOrder)

        let satisfiedMove = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000135")!,
            reason: "Allow explicitly Accepted prerequisite path",
            ticketID: "satisfied-dependent",
            anchor: .before(.init(rawValue: "satisfied-prerequisite")),
            context: initial.context
        ), origin: .ownerApp)
        XCTAssertNil(satisfiedMove.error)
        let afterSatisfied = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0)
        }
        let satisfiedIDs = afterSatisfied.ticketIDs(in: .backlog)
        XCTAssertLessThan(
            try XCTUnwrap(satisfiedIDs.firstIndex(of: .init(rawValue: "satisfied-dependent"))),
            try XCTUnwrap(satisfiedIDs.firstIndex(of: .init(rawValue: "satisfied-prerequisite")))
        )

        let offlaneMove = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000136")!,
            reason: "Keep direct off-lane prerequisite as an execution gate",
            ticketID: "offlane-dependent",
            anchor: .after(.init(rawValue: "free-two")),
            context: afterSatisfied.context
        ), origin: .ownerApp)
        XCTAssertNil(offlaneMove.error, "A direct off-lane unmet prerequisite must not invent a cross-lane ordinal")
        let final = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0)
        }
        let finalIDs = final.ticketIDs(in: .backlog)
        XCTAssertGreaterThan(
            try XCTUnwrap(finalIDs.firstIndex(of: .init(rawValue: "offlane-dependent"))),
            try XCTUnwrap(finalIDs.firstIndex(of: .init(rawValue: "free-two")))
        )
        XCTAssertLessThan(
            try XCTUnwrap(finalIDs.firstIndex(of: .init(rawValue: "untouched-dependent"))),
            try XCTUnwrap(finalIDs.firstIndex(of: .init(rawValue: "untouched-prerequisite"))),
            "An untouched legacy inversion remains evidence but does not authorize auto-repair or block an unrelated move"
        )
    }

    func testStaleUnavailableAndLateWriteFailureRejectWithoutPartialCommit() async throws {
        let root = try makeFixtureRoot()
        let databaseURL = root.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "ordering-project"),
            registrationID: "registration-1",
            requestGeneration: 1
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed rejection fixture") { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('ordering-project','Ordering',1)")
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('root-1','ordering-project',?)",
                bindings: [.text(root.path)]
            )
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('ordering-project','registration-1',1,'complete')")
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase-open','ordering-project','Open')")
            try connection.execute("""
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                ('a','ordering-project','phase-open','A','backlog'),
                ('b','ordering-project','phase-open','B','backlog'),
                ('c','ordering-project','phase-open','C','backlog')
                """)
            try connection.execute("DELETE FROM ticket_lane_order WHERE project_id='ordering-project'")
            try connection.execute("""
                INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key) VALUES
                ('ordering-project','a','backlog','001'),
                ('ordering-project','b','backlog','01'),
                ('ordering-project','c','backlog','011')
                """)
        }
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: root, authorizedRoots: [root]),
            ])
        )
        let original = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0)
        }
        let orderBefore = try await orderRows(store)

        try await store.transact(actor: .init(id: "fixture"), reason: "Change dependency context") { connection in
            try connection.execute("""
                INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id)
                VALUES ('dependency-c-a','ordering-project','c','a')
                """)
        }
        let staleRequest = UUID(uuidString: "00000000-0000-4000-8000-000000000125")!
        let staleResult = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: staleRequest,
            reason: "Reject changed dependency context",
            ticketID: "b",
            anchor: .after(.init(rawValue: "c")),
            context: original.context
        ), origin: .ownerApp)
        XCTAssertEqual(staleResult.error, .ticketOrdering(.staleContext))
        let orderAfterStaleRejection = try await orderRows(store)
        XCTAssertEqual(orderAfterStaleRejection, orderBefore)
        try await assertNoCommandCommit(store, requestID: staleRequest, reason: "Reject changed dependency context")

        let completeContext = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0).context
        }
        try await store.transact(actor: .init(id: "fixture"), reason: "Make ordering context unavailable") {
            try $0.execute("DELETE FROM ticket_lane_order WHERE project_id='ordering-project' AND ticket_id='b'")
        }
        let unavailableRequest = UUID(uuidString: "00000000-0000-4000-8000-000000000126")!
        let unavailableResult = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: unavailableRequest,
            reason: "Reject unavailable ordering context",
            ticketID: "c",
            anchor: .before(.init(rawValue: "a")),
            context: completeContext
        ), origin: .ownerApp)
        XCTAssertEqual(
            unavailableResult.error,
            .ticketOrdering(.unavailable(.missingOrderRow(.init(rawValue: "b"))))
        )
        try await assertNoCommandCommit(store, requestID: unavailableRequest, reason: "Reject unavailable ordering context")

        try await store.transact(actor: .init(id: "fixture"), reason: "Restore isolated order fixture") {
            try $0.execute("""
                INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key)
                VALUES ('ordering-project','b','backlog','01')
                """)
        }
        let restoredContext = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: registration.projectID, connection: $0).context
        }
        try await store.transact(actor: .init(id: "fixture"), reason: "Inject late ordering write failure") {
            try $0.execute("""
                CREATE TRIGGER ticket_ordering_late_failure
                BEFORE UPDATE OF order_key ON ticket_lane_order
                WHEN OLD.project_id='ordering-project' AND OLD.ticket_id='b'
                BEGIN
                    SELECT RAISE(ABORT, 'injected ticket ordering failure');
                END
                """)
        }
        let beforeFailure = try await orderRows(store)
        let failedRequest = UUID(uuidString: "00000000-0000-4000-8000-000000000127")!
        let failed = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: failedRequest,
            reason: "Fail after validated order write",
            ticketID: "b",
            anchor: .after(.init(rawValue: "c")),
            context: restoredContext
        ), origin: .ownerApp)
        XCTAssertNotNil(failed.error)
        XCTAssertNil(failed.auditEventID)
        XCTAssertNil(failed.ticketOrderingContext)
        let orderAfterFailure = try await orderRows(store)
        XCTAssertEqual(orderAfterFailure, beforeFailure)
        try await assertNoCommandCommit(store, requestID: failedRequest, reason: "Fail after validated order write")
    }

    func testOrderingPreservesByteDistinctCanonicalEquivalentTicketAndPhaseIDs() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "ordering-project")
        let registration = ProjectRegistration(
            projectID: projectID,
            registrationID: "registration-1",
            requestGeneration: 1
        )
        let protectedPhase = "phase-\u{e9}"
        let openPhase = "phase-e\u{301}"
        let protectedTicket = "ticket-\u{e9}"
        let movableTicket = "ticket-e\u{301}"
        XCTAssertNotEqual(Data(protectedPhase.utf8), Data(openPhase.utf8))
        XCTAssertNotEqual(Data(protectedTicket.utf8), Data(movableTicket.utf8))

        try await store.transact(actor: .init(id: "fixture"), reason: "Seed byte-exact identity fixture") { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('ordering-project','Ordering',1)")
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('root-1','ordering-project',?)",
                bindings: [.text(root.path)]
            )
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('ordering-project','registration-1',1,'complete')")
            try connection.execute(
                "INSERT INTO phases (id,project_id,name) VALUES (?,'ordering-project','Protected'),(?,'ordering-project','Open')",
                bindings: [.text(protectedPhase), .text(openPhase)]
            )
            try connection.execute(
                "INSERT INTO project_active_phases (project_id,phase_id) VALUES ('ordering-project',?)",
                bindings: [.text(openPhase)]
            )
            try connection.execute(
                """
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                (?,'ordering-project',?,'Protected ticket','backlog'),
                (?,'ordering-project',?,'Movable ticket','backlog'),
                ('anchor','ordering-project',?,'Dependent anchor','backlog')
                """,
                bindings: [
                    .text(protectedTicket), .text(protectedPhase),
                    .text(movableTicket), .text(openPhase),
                    .text(openPhase),
                ]
            )
            try connection.execute(
                "UPDATE phase_lifecycles SET lifecycle='completed',revision=1,completion_baseline_digest=?,completed_at='2026-10-09T00:00:00Z',updated_at='2026-10-09T00:00:00Z' WHERE project_id='ordering-project' AND phase_id=?",
                bindings: [.text(String(repeating: "c", count: 64)), .text(protectedPhase)]
            )
            try connection.execute(
                "INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES ('byte-exact-dependency','ordering-project','anchor',?)",
                bindings: [.text(movableTicket)]
            )
            try connection.execute("DELETE FROM ticket_lane_order WHERE project_id='ordering-project'")
            try connection.execute(
                """
                INSERT INTO ticket_lane_order (project_id,ticket_id,lane,order_key) VALUES
                ('ordering-project',?,'backlog','001'),
                ('ordering-project',?,'backlog','01'),
                ('ordering-project','anchor','backlog','011')
                """,
                bindings: [.text(protectedTicket), .text(movableTicket)]
            )
        }

        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                .init(registration: registration, canonicalRoot: root, authorizedRoots: [root]),
            ])
        )
        let initial = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: projectID, connection: $0)
        }
        XCTAssertEqual(initial.ticketIDs(in: .backlog).map { Data($0.rawValue.utf8) }, [
            Data(protectedTicket.utf8), Data(movableTicket.utf8), Data("anchor".utf8),
        ])

        let dependencyResult = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000140")!,
            reason: "Bind the decomposed prerequisite exactly",
            ticketID: "anchor",
            anchor: .before(.init(rawValue: movableTicket)),
            context: initial.context
        ), origin: .ownerApp)
        guard case let .ticketOrdering(.dependencyConflict(conflict))? = dependencyResult.error else {
            return XCTFail("Expected the byte-exact dependency conflict")
        }
        XCTAssertEqual(Data(conflict.prerequisiteTicketID.rawValue.utf8), Data(movableTicket.utf8))
        XCTAssertEqual(Data(conflict.dependentTicketID.rawValue.utf8), Data("anchor".utf8))

        let moveResult = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000141")!,
            reason: "Move only the decomposed ticket",
            ticketID: movableTicket,
            anchor: .before(.init(rawValue: protectedTicket)),
            context: initial.context
        ), origin: .ownerApp)
        XCTAssertNil(moveResult.error)
        let moved = try await store.read {
            try TicketLaneOrderingPolicy.snapshot(projectID: projectID, connection: $0)
        }
        XCTAssertEqual(moved.ticketIDs(in: .backlog).map { Data($0.rawValue.utf8) }, [
            Data(movableTicket.utf8), Data(protectedTicket.utf8), Data("anchor".utf8),
        ])

        let protectedOrder = try await orderRows(store)
        let protectedResult = await dispatcher.dispatch(orderEnvelope(
            root: root,
            registration: registration,
            requestID: UUID(uuidString: "00000000-0000-4000-8000-000000000142")!,
            reason: "Reject only the completed-phase composed ticket",
            ticketID: protectedTicket,
            anchor: .after(.init(rawValue: "anchor")),
            context: moved.context
        ), origin: .ownerApp)
        XCTAssertEqual(protectedResult.error, .ticketOrdering(.targetIneligible(.completedPhase)))
        let afterProtectedRejection = try await orderRows(store)
        XCTAssertEqual(afterProtectedRejection, protectedOrder)

        let dashboard = try await DashboardProjection.load(from: store)
        let allPhases = try XCTUnwrap(dashboard.allPhaseBoard(for: projectID))
        XCTAssertEqual(allPhases.lane(.backlog)?.cards.map { Data($0.id.rawValue.utf8) }, [
            Data(movableTicket.utf8), Data(protectedTicket.utf8), Data("anchor".utf8),
        ])
        XCTAssertEqual(
            dashboard.board(for: projectID, phaseID: .init(rawValue: protectedPhase))?
                .lane(.backlog)?.cards.map { Data($0.id.rawValue.utf8) },
            [Data(protectedTicket.utf8)]
        )
        XCTAssertEqual(
            dashboard.board(for: projectID, phaseID: .init(rawValue: openPhase))?
                .lane(.backlog)?.cards.map { Data($0.id.rawValue.utf8) },
            [Data(movableTicket.utf8), Data("anchor".utf8)]
        )
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

    private func orderEnvelope(
        root: URL,
        registration: ProjectRegistration,
        requestID: UUID,
        reason: String,
        ticketID: String,
        anchor: TicketOrderAnchor,
        context: TicketOrderingContext
    ) -> AgentCommandEnvelope {
        .init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: root.path,
            expectedRegistration: registration,
            reason: reason,
            command: .reorderTicket(
                projectID: registration.projectID.rawValue,
                ticketID: ticketID,
                expectedLane: .backlog,
                anchor: anchor,
                expectedOrderingContext: context
            )
        )
    }

    private func orderRows(_ store: DeliveryStore) async throws -> [[String: SQLiteValue]] {
        try await store.read {
            try $0.rows(
                "SELECT ticket_id,lane,order_key FROM ticket_lane_order WHERE project_id='ordering-project' ORDER BY lane,order_key COLLATE BINARY"
            )
        }
    }

    private func assertNoCommandCommit(
        _ store: DeliveryStore,
        requestID: UUID,
        reason: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let counts = try await store.read { connection in
            (
                receipts: try connection.scalarInt(
                    "SELECT COUNT(*) FROM agent_command_requests WHERE request_id=?",
                    bindings: [.text(requestID.uuidString)]
                ),
                audits: try connection.scalarInt(
                    "SELECT COUNT(*) FROM audit_events WHERE reason=?",
                    bindings: [.text(reason)]
                )
            )
        }
        XCTAssertEqual(counts.receipts, 0, file: file, line: line)
        XCTAssertEqual(counts.audits, 0, file: file, line: line)
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
