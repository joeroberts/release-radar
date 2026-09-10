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
            for (id, lane) in [("old", "backlog"), ("a", "accepted"), ("b", "backlog"), ("detached", "accepted"), ("drop", "backlog"), ("unknown", "backlog")] {
                try connection.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','phase-a',?,?)",
                    bindings: [.text(id), .text("Scope \(id)"), .text(lane)]
                )
            }
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('p','phase-a','goal','Goal','Outcome','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            for (ticket, assessment) in [("old", "current"), ("a", "current"), ("b", "current"), ("detached", "current"), ("drop", "current"), ("unknown", "unassessed")] {
                try connection.execute(
                    "INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('p','phase-a','goal',?,?,?,'2026-09-10T00:00:00Z')",
                    bindings: [.text(ticket), .text("Scope \(ticket)"), .text(assessment)]
                )
            }
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p','phase-a','goal','a'),('p','phase-a','goal','b')")
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
            "detached": .uncovered,
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
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p','destination','destination-goal','successor'),('p','consumer','consumer-goal','consumer')")
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

    func testReassignmentDoesNotLetLaterAcceptanceDeliverTheAbandonedGoal() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("reassignment.sqlite"))
        let projectID = ProjectID(rawValue: "p")
        let phaseID = PhaseID(rawValue: "phase")
        let ticketID = TicketID(rawValue: "ticket")
        let firstGoal = DeliveryGoalID(rawValue: "goal-one")
        let secondGoal = DeliveryGoalID(rawValue: "goal-two")
        try await store.transact(
            actor: .init(id: "fixture"), reason: "Reassign actual backlog work",
            auditEventID: .init(rawValue: "reassignment-audit"),
            auditScope: .init(projectID: projectID, entityType: .phasePlan, entityID: phaseID.rawValue)
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('p','Project')")
            try DeliveryPlanningPolicy.upsertPhase(projectID: projectID, phaseID: phaseID, name: "Phase", mode: .governed, connection: connection)
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('ticket','p','phase','Deliver scope','backlog')")
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: projectID, ticketID: ticketID, expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "task"), label: "Task", title: "Complete scope", sortOrder: 0)],
                definitionRevisions: [], supersededTaskIDs: [], connection: connection
            )
            _ = try TicketTaskPlanningPolicy.completeTask(
                projectID: projectID, ticketID: ticketID, taskID: .init(rawValue: "task"),
                expectedRevision: 1, connection: connection
            )
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: phaseID, expectedRevision: 0,
                goalUpserts: [
                    .init(id: firstGoal, title: "First", outcome: "First scope", doneCriteria: ["Accepted"], sortOrder: 0),
                    .init(id: secondGoal, title: "Second", outcome: "Second scope", doneCriteria: ["Accepted"], sortOrder: 1),
                ],
                assignments: [.init(goalID: firstGoal, ticketID: ticketID)],
                unassignedTicketIDs: [], supersededGoalIDs: [],
                auditEventID: .init(rawValue: "reassignment-audit"), connection: connection
            )
        }
        try await store.transact(
            actor: .init(id: "fixture"), reason: "Reassign exact backlog work",
            auditEventID: .init(rawValue: "reassignment-audit-2"),
            auditScope: .init(projectID: projectID, entityType: .phasePlan, entityID: phaseID.rawValue)
        ) { connection in
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: phaseID, expectedRevision: 1,
                goalUpserts: [], assignments: [.init(goalID: secondGoal, ticketID: ticketID)],
                unassignedTicketIDs: [], supersededGoalIDs: [],
                auditEventID: .init(rawValue: "reassignment-audit-2"), connection: connection
            )
            try connection.execute("UPDATE phase_plans SET state='ready',ready_revision=revision WHERE project_id='p' AND phase_id='phase'")
            try connection.execute("UPDATE delivery_goals SET lifecycle='planned' WHERE project_id='p' AND phase_id='phase'")
            try DeliveryPlanningPolicy.transitionTicket(projectID: projectID, ticketID: ticketID, to: .inProgress, connection: connection)
            try DeliveryPlanningPolicy.transitionTicket(projectID: projectID, ticketID: ticketID, to: .needsReview, connection: connection)
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: projectID, ticketID: ticketID, to: .accepted,
                ticketTaskPlanRevision: 2, connection: connection
            )
        }

        let coverage = try await store.read { connection in
            (
                try DeliveryGoalCoveragePolicy.assess(projectID: projectID, phaseID: phaseID, goalID: firstGoal, connection: connection),
                try DeliveryGoalCoveragePolicy.assess(projectID: projectID, phaseID: phaseID, goalID: secondGoal, connection: connection)
            )
        }
        XCTAssertEqual(coverage.0.obligations.first?.state, .uncovered)
        XCTAssertFalse(coverage.0.isAcceptanceEligible)
        XCTAssertEqual(coverage.1.obligations.first?.state, .delivered)
        XCTAssertTrue(coverage.1.isAcceptanceEligible)
    }

    func testSupersededDebtAndUnassignedLiveWorkRemainPhasePrerequisitesWhileCompletedLegacyPhasesPass() async throws {
        let root = try makeFixtureRoot()
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("phase-dependencies.sqlite"))
        let projectID = ProjectID(rawValue: "p")
        try await store.transact(
            actor: .init(id: "fixture"), reason: "Seed canonical prerequisite states",
            auditEventID: .init(rawValue: "dependency-audit"),
            auditScope: .init(projectID: projectID, entityType: .phasePlan, entityID: "source")
        ) { connection in
            try connection.execute("INSERT INTO projects (id,name) VALUES ('p','Project')")
            for phase in [
                "source", "legacy", "empty", "dropped",
                "consumer-one", "consumer-two", "consumer-three", "consumer-four", "consumer-five",
            ] {
                try DeliveryPlanningPolicy.upsertPhase(projectID: projectID, phaseID: .init(rawValue: phase), name: phase, mode: .governed, connection: connection)
            }
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('old','p','source','Old debt','backlog'),('delivered','p','source','Delivered','accepted'),('legacy-done','p','legacy','Legacy done','accepted'),('dropped-work','p','dropped','Dropped work','backlog'),('consumer-one','p','consumer-one','Consumer one','backlog'),('consumer-two','p','consumer-two','Consumer two','backlog'),('consumer-three','p','consumer-three','Consumer three','backlog'),('consumer-four','p','consumer-four','Consumer four','backlog'),('consumer-five','p','consumer-five','Consumer five','backlog')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('p','source','old-goal','Old','Old debt','superseded',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z'),('p','source','unused-goal','Unused','No assigned scope','superseded',1,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z'),('p','source','live-goal','Live','Delivered','active',2,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z'),('p','dropped','dropped-goal','Dropped','Removed scope','superseded',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES ('p','source','live-goal',0,'Accepted')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p','source','live-goal','delivered')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('p','source','old-goal','old','Old debt','current','2026-09-10T00:00:00Z'),('p','source','live-goal','delivered','Delivered','current','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('p','dropped','dropped-goal','dropped-work','Removed scope','current','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES ('p','old','withdrawn','Await explicit resolution','source','backlog','dependency-audit','2026-09-10T00:00:00Z'),('p','dropped-work','withdrawn','Removed without delivery','dropped','backlog','dependency-audit','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligation_drops (project_id,phase_id,goal_id,ticket_id,reason,audit_event_id,created_at) VALUES ('p','dropped','dropped-goal','dropped-work','Removed scope','dependency-audit','2026-09-10T00:00:00Z')")
            for consumer in ["consumer-one", "consumer-two", "consumer-three", "consumer-four", "consumer-five"] {
                try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('p',?,?,'Consumer','Consume','planned',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')", bindings: [.text(consumer), .text("goal-\(consumer)")])
                try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('p',?,?,?)", bindings: [.text(consumer), .text("goal-\(consumer)"), .text(consumer)])
                try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('p',?,?,?,'Consume','current','2026-09-10T00:00:00Z')", bindings: [.text(consumer), .text("goal-\(consumer)"), .text(consumer)])
                try connection.execute("UPDATE phase_plans SET state='ready',ready_revision=revision WHERE project_id='p' AND phase_id=?", bindings: [.text(consumer)])
            }
            try connection.execute("INSERT INTO phase_dependencies (id,project_id,phase_id,depends_on_phase_id) VALUES ('dep-one','p','consumer-one','source'),('dep-two','p','consumer-two','source'),('dep-three','p','consumer-three','legacy'),('dep-four','p','consumer-four','empty'),('dep-five','p','consumer-five','dropped')")
        }

        do {
            _ = try await store.transact(actor: .init(id: "fixture"), reason: "Superseded debt blocks readiness") {
                try DeliveryPlanningPolicy.finalizePlan(
                    projectID: projectID, phaseID: .init(rawValue: "source"),
                    expectedRevision: 0, connection: $0
                )
            }
            XCTFail("Unresolved superseded debt must block source plan readiness.")
        } catch { guard case DeliveryPlanningPolicyError.phasePlanIncomplete = error else { throw error } }

        do {
            try await store.transact(actor: .init(id: "fixture"), reason: "Superseded debt blocks") {
                try DeliveryPlanningPolicy.transitionTicket(projectID: projectID, ticketID: .init(rawValue: "consumer-one"), to: .inProgress, connection: $0)
            }
            XCTFail("Unresolved superseded debt must block a dependent phase.")
        } catch { guard case DeliveryPlanningPolicyError.invalidPlanMutation = error else { throw error } }

        for (consumer, reason) in [
            ("consumer-four", "An empty prerequisite has no delivered outcome."),
            ("consumer-five", "An entirely dropped prerequisite has no delivered outcome."),
        ] {
            do {
                try await store.transact(actor: .init(id: "fixture"), reason: reason) {
                    try DeliveryPlanningPolicy.transitionTicket(
                        projectID: projectID, ticketID: .init(rawValue: consumer),
                        to: .inProgress, connection: $0
                    )
                }
                XCTFail("A prerequisite without delivered work must block \(consumer).")
            } catch { guard case DeliveryPlanningPolicyError.invalidPlanMutation = error else { throw error } }
        }

        try await store.transact(actor: .init(id: "fixture"), reason: "Resolve debt then add unassigned live work") { connection in
            try connection.execute("INSERT INTO delivery_goal_obligation_drops (project_id,phase_id,goal_id,ticket_id,reason,audit_event_id,created_at) VALUES ('p','source','old-goal','old','Removed scope','dependency-audit','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('unassigned-work','p','source','Still live','backlog')")
        }
        do {
            try await store.transact(actor: .init(id: "fixture"), reason: "Unassigned live work blocks") {
                try DeliveryPlanningPolicy.transitionTicket(projectID: projectID, ticketID: .init(rawValue: "consumer-two"), to: .inProgress, connection: $0)
            }
            XCTFail("Unassigned live work must block a dependent phase.")
        } catch { guard case DeliveryPlanningPolicyError.invalidPlanMutation = error else { throw error } }

        try await store.transact(actor: .init(id: "fixture"), reason: "Complete legacy prerequisites") { connection in
            try connection.execute("UPDATE tickets SET lane='accepted' WHERE project_id='p' AND id='unassigned-work'")
            _ = try DeliveryPlanningPolicy.finalizePlan(
                projectID: projectID, phaseID: .init(rawValue: "source"),
                expectedRevision: 0, connection: connection
            )
            try DeliveryPlanningPolicy.transitionTicket(projectID: projectID, ticketID: .init(rawValue: "consumer-two"), to: .inProgress, connection: connection)
            try DeliveryPlanningPolicy.transitionTicket(projectID: projectID, ticketID: .init(rawValue: "consumer-three"), to: .inProgress, connection: connection)
        }
        let lanes = try await store.read {
            try $0.rows("SELECT id,lane FROM tickets WHERE project_id='p' AND id IN ('consumer-two','consumer-three') ORDER BY id")
        }
        XCTAssertEqual(lanes.map { $0["lane"] }, [.text("in_progress"), .text("in_progress")])
    }

    private func makeFixtureRoot() throws -> URL {
        let root = try XCTUnwrap(
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ).appendingPathComponent("ReleaseRadarPhase5DSuccessorTests/fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
