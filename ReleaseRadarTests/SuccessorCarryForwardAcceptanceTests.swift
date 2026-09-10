import Foundation
import XCTest
@testable import ReleaseRadarCore

final class SuccessorCarryForwardAcceptanceTests: XCTestCase {
    func testSchemaTwentyTwoBackfillsCurrentCoverageAndMarksHistoricalLossUnassessed() async throws {
        let root = try makeFixtureRoot()
        let databaseURL = root.appendingPathComponent("store.sqlite")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SchemaV12/release-radar-v12.sqlite")
        try FileManager.default.copyItem(at: source, to: databaseURL)

        let legacy = try SQLiteConnection(url: databaseURL)
        try legacy.execute(
            "INSERT INTO audit_events (id,actor_id,reason,created_at,thread_attribution,project_id,entity_type,entity_id) VALUES ('audit-unassigned','fixture','Remove membership','2026-09-10T00:00:00Z','none','project-main','phase_plan','phase-2')"
        )
        try legacy.execute(
            "INSERT INTO delivery_goal_assignment_events (audit_event_id,project_id,phase_id,ticket_id,previous_goal_id,current_goal_id,revision,action) VALUES ('audit-unassigned','project-main','phase-2','ticket-blocked','goal-2',NULL,1,'unassigned')"
        )
        legacy.close()

        let store = DeliveryStore(databaseURL: databaseURL)
        let facts = try await store.read { connection in
            (
                try connection.rows(
                    "SELECT phase_id,goal_id,ticket_id,assessment FROM delivery_goal_obligations WHERE project_id='project-main' ORDER BY phase_id,ticket_id"
                ),
                try connection.rows(
                    "SELECT name FROM sqlite_schema WHERE type='table' AND name IN ('ticket_retirements','ticket_successor_links','delivery_goal_obligation_lineage','delivery_goal_obligation_drops') ORDER BY name"
                )
            )
        }
        let verifier = try SQLiteConnection(url: databaseURL, immutableReadOnly: true)

        XCTAssertEqual(try verifier.scalarInt("PRAGMA user_version"), 22)
        XCTAssertEqual(facts.0, [
            ["phase_id": .text("phase-1"), "goal_id": .text("goal-1"), "ticket_id": .text("ticket-active"), "assessment": .text("current")],
            ["phase_id": .text("phase-2"), "goal_id": .text("goal-2"), "ticket_id": .text("ticket-blocked"), "assessment": .text("unassessed")],
        ])
        XCTAssertEqual(facts.1.compactMap { row in
            guard case let .text(value)? = row["name"] else { return nil }
            return value
        }, [
            "delivery_goal_obligation_drops",
            "delivery_goal_obligation_lineage",
            "ticket_retirements",
            "ticket_successor_links",
        ])
    }

    func testPackagedSuccessorOperationsDecodeWithoutOwnerDecisionOrApplicationFields() throws {
        let json = """
        [
          {"retireTicket":{"ticketID":"OLD","disposition":"split","reason":"Split the outcome","successorTicketIDs":["NEW-A","NEW-B"]}},
          {"moveBacklogTicket":{"ticketID":"MOVE","fromPhaseID":"PHASE-A","toPhaseID":"PHASE-B"}},
          {"reassignTicketToGoal":{"ticketID":"MOVE","phaseID":"PHASE-B","fromGoalID":"GOAL-A","toGoalID":"GOAL-B"}},
          {"supersedeDeliveryGoal":{"phaseID":"PHASE-A","goalID":"GOAL-A"}},
          {"carryGoalObligation":{"source":{"phaseID":"PHASE-A","goalID":"GOAL-A","ticketID":"OLD"},"descendants":[{"phaseID":"PHASE-B","goalID":"GOAL-B","ticketID":"NEW-A"},{"phaseID":"PHASE-B","goalID":"GOAL-B","ticketID":"NEW-B"}],"reason":"Carry every required child"}},
          {"dropGoalObligation":{"obligation":{"phaseID":"PHASE-A","goalID":"GOAL-A","ticketID":"WITHDRAWN"},"reason":"Owner removed this scope"}},
          {"retargetTicketDependency":{"id":"DEP","ticketID":"CONSUMER","fromDependsOnTicketID":"OLD","toDependsOnTicketID":"NEW-A"}},
          {"removeTicketDependency":{"id":"DEP-REMOVE","ticketID":"CONSUMER","dependsOnTicketID":"OLD"}}
        ]
        """

        let operations = try JSONDecoder().decode([PlanChangeOperation].self, from: Data(json.utf8))
        XCTAssertEqual(operations.count, 8)

        let encoded = try JSONEncoder().encode(operations)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        XCTAssertEqual(object.compactMap { $0.keys.first }, [
            "retireTicket", "moveBacklogTicket", "reassignTicketToGoal", "supersedeDeliveryGoal",
            "carryGoalObligation", "dropGoalObligation", "retargetTicketDependency", "removeTicketDependency",
        ])
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("decision"))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("application"))
    }

    func testCoverageAssessmentDistinguishesCarriedLeavesDropAndUnassessedDebt() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("coverage.sqlite"))
        let auditID = AuditEventID(rawValue: "audit-coverage")
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed coverage states",
            auditEventID: auditID,
            auditScope: .init(projectID: .init(rawValue: "p"), entityType: .phasePlan, entityID: "phase-a")
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('p','Coverage',1)")
            try DeliveryPlanningPolicy.upsertPhase(projectID: .init(rawValue: "p"), phaseID: .init(rawValue: "phase-a"), name: "A", mode: .governed, connection: connection)
            for (id, lane) in [("old", "backlog"), ("a", "accepted"), ("b", "backlog"), ("drop", "backlog"), ("unknown", "backlog")] {
                try connection.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','phase-a',?,?)",
                    bindings: [.text(id), .text("Scope \(id)"), .text(lane)]
                )
            }
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('p','phase-a','goal','Goal','Outcome','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            for (ticket, assessment) in [("old", "current"), ("a", "current"), ("b", "current"), ("drop", "current"), ("unknown", "unassessed")] {
                try connection.execute(
                    "INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('p','phase-a','goal',?,?,?,'2026-09-10T00:00:00Z')",
                    bindings: [.text(ticket), .text("Scope \(ticket)"), .text(assessment)]
                )
            }
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p','phase-a','goal','b')")
            for descendant in ["a", "b"] {
                try connection.execute(
                    "INSERT INTO delivery_goal_obligation_lineage (project_id,source_phase_id,source_goal_id,source_ticket_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id,reason,audit_event_id,created_at) VALUES ('p','phase-a','goal','old','phase-a','goal',?,'Split scope','audit-coverage','2026-09-10T00:00:00Z')",
                    bindings: [.text(descendant)]
                )
            }
            try connection.execute("INSERT INTO delivery_goal_obligation_drops (project_id,phase_id,goal_id,ticket_id,reason,audit_event_id,created_at) VALUES ('p','phase-a','goal','drop','Removed scope','audit-coverage','2026-09-10T00:00:00Z')")
        }

        let assessment = try await store.read {
            try DeliveryGoalCoveragePolicy.assess(
                projectID: .init(rawValue: "p"),
                phaseID: .init(rawValue: "phase-a"),
                goalID: .init(rawValue: "goal"),
                connection: $0
            )
        }
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: assessment.obligations.map { ($0.key.ticketID.rawValue, $0.state) }), [
            "a": .delivered,
            "b": .required,
            "drop": .dropped,
            "old": .carried,
            "unknown": .unassessed,
        ])
        XCTAssertEqual(assessment.requiredLeafCount, 2)
        XCTAssertEqual(assessment.deliveredLeafCount, 1)
        XCTAssertFalse(assessment.isResolved)
        XCTAssertTrue(assessment.hasDeliveredOutcome)
        XCTAssertFalse(assessment.isAcceptanceEligible)
    }

    func testCarriedDeliveredOutcomeLetsSourcePlanRefinalizeWithoutUpcomingMembership() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("refinalize.sqlite"))
        let projectID = ProjectID(rawValue: "p")
        let sourcePhase = PhaseID(rawValue: "source")
        let sourceGoal = DeliveryGoalID(rawValue: "source-goal")
        try await store.transact(
            actor: .init(id: "fixture"), reason: "Seed delivered carry",
            auditEventID: .init(rawValue: "audit-refinalize"),
            auditScope: .init(projectID: projectID, entityType: .phasePlan, entityID: sourcePhase.rawValue)
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('p','Project')")
            try DeliveryPlanningPolicy.upsertPhase(projectID: projectID, phaseID: sourcePhase, name: "Source", mode: .governed, connection: connection)
            try DeliveryPlanningPolicy.upsertPhase(projectID: projectID, phaseID: .init(rawValue: "destination"), name: "Destination", mode: .governed, connection: connection)
            try DeliveryPlanningPolicy.upsertPhase(projectID: projectID, phaseID: .init(rawValue: "consumer"), name: "Consumer", mode: .governed, connection: connection)
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('original','p','source','Original','backlog'),('successor','p','destination','Successor','backlog'),('consumer','p','consumer','Consumer','backlog')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at,activated_at) VALUES ('p','source','source-goal','Source goal','Deliver source','active',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z'),('p','destination','destination-goal','Destination goal','Deliver successor','active',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z'),('p','consumer','consumer-goal','Consumer goal','Use resolved source','planned',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z',NULL)")
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES ('p','source','source-goal',0,'Accepted'),('p','destination','destination-goal',0,'Accepted'),('p','consumer','consumer-goal',0,'Dependencies resolved')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p','consumer','consumer-goal','consumer')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('p','source','source-goal','original','Original','current','2026-09-10T00:00:00Z'),('p','destination','destination-goal','successor','Successor','current','2026-09-10T00:00:00Z'),('p','consumer','consumer-goal','consumer','Consumer','current','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES ('p','original','replaced','Replaced','source','backlog','audit-refinalize','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO ticket_successor_links (project_id,original_ticket_id,successor_ticket_id,relation,sort_order,audit_event_id,created_at) VALUES ('p','original','successor','replacement',0,'audit-refinalize','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligation_lineage (project_id,source_phase_id,source_goal_id,source_ticket_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id,reason,audit_event_id,created_at) VALUES ('p','source','source-goal','original','destination','destination-goal','successor','Carry','audit-refinalize','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO phase_dependencies (id,project_id,phase_id,depends_on_phase_id) VALUES ('consumer-requires-source','p','consumer','source')")
            try connection.execute("UPDATE phase_plans SET state='ready',ready_revision=revision WHERE project_id='p' AND phase_id='consumer'")
        }

        do {
            try await store.transact(actor: .init(id: "fixture"), reason: "Verify carried work blocks phase dependency") { connection in
                try DeliveryPlanningPolicy.transitionTicket(
                    projectID: projectID, ticketID: .init(rawValue: "consumer"),
                    to: .inProgress, connection: connection
                )
            }
            XCTFail("A carried but incomplete obligation must keep the dependent phase blocked.")
        } catch {
            guard case DeliveryPlanningPolicyError.invalidPlanMutation = error else { throw error }
        }

        try await store.transact(actor: .init(id: "fixture"), reason: "Complete carried successor") {
            try $0.execute("UPDATE tickets SET lane='accepted' WHERE project_id='p' AND id='successor'")
        }

        let states = try await store.transact(
            actor: .init(id: "owner"), reason: "Finalize delivered carry",
            auditScope: .init(projectID: projectID, entityType: .deliveryGoal, entityID: sourceGoal.rawValue)
        ) { connection in
            let ready = try DeliveryPlanningPolicy.finalizePlan(
                projectID: projectID, phaseID: sourcePhase, expectedRevision: 0, connection: connection
            )
            let awaiting = try DeliveryPlanningPolicy.transitionGoal(
                projectID: projectID, phaseID: sourcePhase, goalID: sourceGoal,
                expectedPlanRevision: ready.revision, to: .awaitingAcceptance,
                origin: .externalAgent, connection: connection
            )
            let accepted = try DeliveryPlanningPolicy.transitionGoal(
                projectID: projectID, phaseID: sourcePhase, goalID: sourceGoal,
                expectedPlanRevision: ready.revision, to: .accepted,
                origin: .ownerApp, connection: connection
            )
            return (ready, awaiting, accepted)
        }
        XCTAssertEqual(states.0.state, .ready)
        XCTAssertEqual(states.1.lifecycle, .awaitingAcceptance)
        XCTAssertEqual(states.2.lifecycle, .accepted)

        try await store.transact(actor: .init(id: "fixture"), reason: "Start work after carried dependency resolves") { connection in
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: projectID, ticketID: .init(rawValue: "consumer"),
                to: .inProgress, connection: connection
            )
        }
        let consumerLane = try await store.read {
            try $0.scalarText("SELECT lane FROM tickets WHERE project_id='p' AND id='consumer'")
        }
        XCTAssertEqual(consumerLane, TicketLane.inProgress.rawValue)
    }

    private func makeFixtureRoot() throws -> URL {
        let root = try XCTUnwrap(
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ).appendingPathComponent("ReleaseRadarPhase5DSuccessorTests/fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
