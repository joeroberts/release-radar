import Foundation
import XCTest

@testable import ReleaseRadarCore

final class DeliveryPlanningPolicyAcceptanceTests: XCTestCase {
    private static let project = ProjectID(rawValue: "p")
    private static let phase = PhaseID(rawValue: "phase")
    private let actor = DeliveryActor(id: "delivery-policy-test")

    func testRevisionFinalizationAndStructuralInvalidationPreserveOmittedGoals() async throws {
        let store = try await fixture()
        let initial = try await plan(store)
        XCTAssertEqual(initial.state, .legacyUnassessed)
        XCTAssertEqual(initial.revision, 0)
        _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
        let ready = try await finalize(store, revision: 1)
        XCTAssertEqual(ready.state, .ready)
        XCTAssertEqual(ready.readyRevision, 1)
        let planned = try await goals(store)
        XCTAssertEqual(planned.map(\.lifecycle), [.planned])
        XCTAssertNil(planned[0].activatedAt)
        let draft = try await revise(store, revision: 1, goals: [goal("g2")])
        XCTAssertEqual(draft.state, .draft)
        XCTAssertEqual(draft.revision, 2)
        XCTAssertNil(draft.readyRevision)
        XCTAssertNil(draft.finalizedAt)
        let retained = try await goals(store)
        XCTAssertEqual(retained.map(\.id.rawValue), ["g", "g2"])
        let criteria = try await store.read {
            try DeliveryPlanningPolicy.loadCriteria(
                projectID: Self.project, phaseID: Self.phase, goalID: .init(rawValue: "g"), connection: $0)
        }
        XCTAssertEqual(criteria.map(\.text), ["Delivered"])
    }

    func testDraftDefinitionsMayBeIncompleteButFinalizationReportsTheirIdentity() async throws {
        let store = try await fixture()
        _ = try await revise(
            store, goals: [goal("g", title: "", outcome: "", criteria: [])], assignments: [assignment("t", "g")])
        try await rejected(
            store,
            expected: .phasePlanIncomplete(
                .init(unassignedTicketIDs: [], incompleteGoalIDs: [.init(rawValue: "g")], conflictingTicketIDs: []))
        ) {
            _ = try await self.finalize(store, revision: 1)
        }
        _ = try await revise(store, revision: 1, goals: [goal("g")])
        _ = try await finalize(store, revision: 2)
    }

    func testFinalizationRejectsEmptyUncoveredAndUnassignedGoals() async throws {
        let empty = try await fixture(ticketCount: 0)
        try await rejected(empty) { _ = try await self.finalize(empty, revision: 0) }
        let uncovered = try await fixture()
        try await rejected(
            uncovered,
            expected: .phasePlanIncomplete(
                .init(unassignedTicketIDs: [.init(rawValue: "t")], incompleteGoalIDs: [], conflictingTicketIDs: []))
        ) {
            _ = try await self.finalize(uncovered, revision: 0)
        }
        _ = try await revise(uncovered, goals: [goal("g"), goal("empty")], assignments: [assignment("t", "g")])
        try await rejected(
            uncovered,
            expected: .phasePlanIncomplete(
                .init(unassignedTicketIDs: [], incompleteGoalIDs: [.init(rawValue: "empty")], conflictingTicketIDs: []))
        ) {
            _ = try await self.finalize(uncovered, revision: 1)
        }
    }

    func testReadyIsStructuralAndCompletedDeliveryRemainsReady() async throws {
        let store = try await fixture()
        _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
        try await seed(store, "INSERT INTO blockers (id,project_id,ticket_id,summary) VALUES ('b','p','t','Blocked')")
        try await seed(
            store,
            "INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES ('d','p','t','other-phase-ticket')"
        )
        _ = try await finalize(store, revision: 1)
        let before = try await plan(store)
        try await seed(store, "UPDATE tickets SET lane='accepted' WHERE id='t'")
        let after = try await plan(store)
        XCTAssertEqual(before, after)
        let repeated = try await finalize(store, revision: 1)
        XCTAssertEqual(repeated, before)
    }

    func testRevisionConflictsEmptyOperationsDuplicateAndCrossBoundaryRequestsRollback() async throws {
        let store = try await fixture()
        try await rejected(store) { _ = try await self.revise(store) }
        try await rejected(store, expected: .planRevisionConflict(expected: 1, current: 0)) {
            _ = try await self.revise(store, revision: 1, goals: [self.goal("g")])
        }
        try await rejected(store) { _ = try await self.revise(store, goals: [self.goal("g"), self.goal("g")]) }
        try await rejected(store) {
            _ = try await self.revise(
                store, goals: [self.goal("g")], assignments: [self.assignment("t", "g"), self.assignment("t", "g")])
        }
        try await rejected(store) {
            _ = try await self.revise(
                store, goals: [self.goal("g")], assignments: [self.assignment("t", "g")], unassigned: ["t"])
        }
        for ticket in ["missing", "other-phase-ticket", "foreign-ticket"] {
            try await rejected(store) {
                _ = try await self.revise(store, goals: [self.goal("g")], assignments: [self.assignment(ticket, "g")])
            }
        }
        _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
        try await rejected(store) {
            _ = try await self.revise(store, revision: 1, goals: [self.goal("g")], superseded: ["g"])
        }
        try await rejected(store, expected: .goalPhaseMismatch(.init(rawValue: "g"))) {
            let draft = self.goal("g")
            try await store.transact(actor: self.actor, reason: "Wrong phase") {
                _ = try DeliveryPlanningPolicy.applyRevision(
                    projectID: Self.project, phaseID: .init(rawValue: "other"), expectedRevision: 0,
                    goalUpserts: [draft], assignments: [], unassignedTicketIDs: [], supersededGoalIDs: [],
                    auditEventID: .init(rawValue: "unused"), connection: $0)
            }
        }
    }

    func testAssignmentHistoryUsesOneAuditPerRevisionAndRetainsPreviousOwners() async throws {
        let store = try await fixture()
        _ = try await revise(
            store, goals: [goal("g"), goal("h")], assignments: [assignment("t", "g")], audit: "assign")
        _ = try await revise(store, revision: 1, assignments: [assignment("t", "h")], audit: "transfer")
        _ = try await revise(store, revision: 2, unassigned: ["t"], audit: "remove")
        let history = try await store.read {
            try DeliveryPlanningPolicy.loadAssignmentHistory(
                projectID: Self.project, ticketID: .init(rawValue: "t"), connection: $0)
        }
        XCTAssertEqual(history.map(\.action), ["assigned", "reassigned", "unassigned"])
        XCTAssertEqual(history.map(\.revision), [1, 2, 3])
        XCTAssertEqual(history.map(\.auditEventID.rawValue), ["assign", "transfer", "remove"])
        XCTAssertEqual(history.map { $0.previousGoalID?.rawValue }, [nil, "g", "h"])
        XCTAssertEqual(history.map { $0.currentGoalID?.rawValue }, ["g", "h", nil])
        let auditCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE entity_type='phase_plan'")
        }
        XCTAssertEqual(auditCount, 3)
    }

    func testSupersessionRequiresExplicitDispositionAndUnstartedDraftOrPlannedGoal() async throws {
        for finalized in [false, true] {
            let store = try await fixture()
            _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
            if finalized { _ = try await finalize(store, revision: 1) }
            try await rejected(store) { _ = try await self.revise(store, revision: 1, superseded: ["g"]) }
            _ = try await revise(
                store, revision: 1, goals: [goal("h")], assignments: [assignment("t", "h")], superseded: ["g"])
            let result = try await goals(store)
            XCTAssertEqual(result.first { $0.id.rawValue == "g" }?.lifecycle, .superseded)
            try await rejected(store) { _ = try await self.revise(store, revision: 2, goals: [self.goal("g")]) }
            try await rejected(store) {
                _ = try await self.revise(store, revision: 2, assignments: [self.assignment("t", "g")])
            }
        }
        for lifecycle in ["active", "awaiting_acceptance", "accepted", "superseded"] {
            let store = try await fixture()
            _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
            try await seed(store, "UPDATE delivery_goals SET lifecycle='\(lifecycle)' WHERE id='g'")
            try await rejected(store) {
                _ = try await self.revise(store, revision: 1, unassigned: ["t"], superseded: ["g"])
            }
            if ["accepted", "superseded"].contains(lifecycle) {
                try await rejected(store) {
                    _ = try await self.revise(store, revision: 1, goals: [self.goal("g", title: "Changed")])
                }
            }
        }
    }

    func testStartedAndAcceptedAssignmentsCannotBeRemovedTransferredOrInvented() async throws {
        for lane in ["in_progress", "needs_review", "blocked", "accepted"] {
            let store = try await fixture()
            _ = try await revise(store, goals: [goal("g"), goal("h")], assignments: [assignment("t", "g")])
            try await seed(store, "UPDATE tickets SET lane='\(lane)' WHERE id='t'")
            try await rejected(store) { _ = try await self.revise(store, revision: 1, unassigned: ["t"]) }
            try await rejected(store) {
                _ = try await self.revise(store, revision: 1, assignments: [self.assignment("t", "h")])
            }
            try await rejected(store) {
                _ = try await self.revise(store, revision: 1, unassigned: ["t"], superseded: ["g"])
            }
            if lane == "blocked" { continue }
            let unassigned = try await fixture()
            try await seed(unassigned, "UPDATE tickets SET lane='\(lane)' WHERE id='t'")
            try await rejected(unassigned) {
                _ = try await self.revise(unassigned, goals: [self.goal("g")], assignments: [self.assignment("t", "g")])
            }
        }
    }

    func testCompleteStandaloneLifecycleMatrixAndTrustedOwnerOrigin() async throws {
        for from in DeliveryGoalLifecycle.allCases {
            for to in DeliveryGoalLifecycle.allCases {
                let store = try await readyFixture()
                try await seed(store, "UPDATE tickets SET lane='accepted' WHERE id='t'")
                try await seed(store, "UPDATE delivery_goals SET lifecycle='\(from.rawValue)' WHERE id='g'")
                let allowed =
                    (from == .active && to == .awaitingAcceptance) || (from == .awaitingAcceptance && to == .accepted)
                if allowed {
                    let updated = try await transition(store, to: to, origin: .ownerApp)
                    XCTAssertEqual(updated.lifecycle, to)
                    XCTAssertEqual(updated.acceptedAt != nil, to == .accepted)
                    let unchangedPlan = try await plan(store)
                    XCTAssertEqual(unchangedPlan.revision, 1)
                    XCTAssertEqual(unchangedPlan.state, .ready)
                } else {
                    try await rejected(store, expected: .invalidGoalTransition(from: from, to: to)) {
                        _ = try await self.transition(store, to: to, origin: .ownerApp)
                    }
                }
            }
        }
        let store = try await readyFixture()
        try await seed(store, "UPDATE tickets SET lane='accepted' WHERE id='t'")
        try await seed(store, "UPDATE delivery_goals SET lifecycle='active' WHERE id='g'")
        _ = try await transition(store, to: .awaitingAcceptance, origin: .externalAgent)
        try await rejected(store, expected: .ownerAcceptanceRequired) {
            // Actor text cannot turn an external-origin operation into owner authority.
            _ = try await self.transition(
                store, to: .accepted, origin: .externalAgent, actor: .init(id: "release-radar-owner"))
        }
        _ = try await transition(store, to: .accepted, origin: .ownerApp)
    }

    func testLifecycleRequiresAcceptedChildrenAndAvailableExistingEvidence() async throws {
        for target in [DeliveryGoalLifecycle.awaitingAcceptance, .accepted] {
            let store = try await readyFixture()
            try await seed(
                store,
                "UPDATE delivery_goals SET lifecycle='\(target == .accepted ? "awaiting_acceptance" : "active")' WHERE id='g'"
            )
            try await rejected(store) { _ = try await self.transition(store, to: target, origin: .ownerApp) }
            try await seed(store, "UPDATE tickets SET lane='accepted' WHERE id='t'")
            try await seed(
                store,
                "INSERT INTO evidence (id,project_id,ticket_id,path,is_available) VALUES ('e','p','t','unused',0)")
            try await rejected(store, expected: .goalAcceptanceEvidenceUnavailable([.init(rawValue: "t")])) {
                _ = try await self.transition(store, to: target, origin: .ownerApp)
            }
            try await seed(store, "UPDATE evidence SET is_available=1 WHERE id='e'")
            _ = try await transition(store, to: target, origin: .ownerApp)
        }
    }

    func testLifecycleRejectsCurrentRevisionDraftThenSucceedsAfterRefinalization() async throws {
        for target in [DeliveryGoalLifecycle.awaitingAcceptance, .accepted] {
            let store = try await readyFixture(ticketCount: 2)
            try await seed(store, "UPDATE tickets SET lane='accepted' WHERE id='t'")
            try await seed(
                store,
                "UPDATE delivery_goals SET lifecycle='\(target == .accepted ? "awaiting_acceptance" : "active")' WHERE id='g'"
            )
            _ = try await revise(store, revision: 1, goals: [goal("h", title: "Revised")])
            try await rejected(store, expected: .phasePlanNotReady) {
                _ = try await self.transition(store, to: target, revision: 2, origin: .ownerApp)
            }
            _ = try await finalize(store, revision: 2)
            _ = try await transition(store, to: target, revision: 2, origin: .ownerApp)
        }
    }

    func testFinalizationRejectsUpcomingAssignmentsToTerminalGoals() async throws {
        for lifecycle in ["accepted", "superseded"] {
            let store = try await fixture()
            _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
            try await seed(store, "UPDATE delivery_goals SET lifecycle='\(lifecycle)' WHERE id='g'")
            try await rejected(store) { _ = try await self.finalize(store, revision: 1) }
        }
    }

    func testGoalAndAssignmentOperationLimitsUseCombinedCounts() async throws {
        for count in [63, 64, 65] {
            let store = try await fixture()
            _ = try await revise(store, goals: [goal("old")])
            let operation = {
                _ = try await self.revise(
                    store, revision: 1, goals: (0..<(count - 1)).map { self.goal("g\($0)") }, superseded: ["old"])
            }
            if count <= 64 { try await operation() } else { try await rejected(store, operation: operation) }
        }
        for count in [511, 512, 513] {
            let store = try await fixture(ticketCount: count)
            _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")])
            let operation = {
                _ = try await self.revise(
                    store, revision: 1, assignments: (1..<count).map { self.assignment("t\($0)", "g") },
                    unassigned: ["t"])
            }
            if count <= 512 { try await operation() } else { try await rejected(store, operation: operation) }
        }
    }

    func testMalformedInputAndExhaustedRevisionFailWithoutEffects() async throws {
        let store = try await fixture()
        for bad in [goal(""), goal("bad\0id"), goal("g", criteria: [" "]), goal("g", order: -1)] {
            try await rejected(store) { _ = try await self.revise(store, goals: [bad]) }
        }
        try await seed(store, "UPDATE phase_plans SET revision=9223372036854775807 WHERE phase_id='phase'")
        try await rejected(store) { _ = try await self.revise(store, revision: Int64.max, goals: [self.goal("g")]) }
    }

    func testPartialMutationAndAuditFailureRollBackEveryPolicyTable() async throws {
        let store = try await fixture()
        try await rejected(store) {
            _ = try await self.revise(store, goals: [self.goal("g")], assignments: [self.assignment("t", "missing")])
        }
        try await rejected(store) {
            let drafts = [self.goal("g")]
            let assignments = [self.assignment("t", "g")]
            try await store.transact(
                actor: self.actor, reason: "Audit mismatch", auditEventID: .init(rawValue: "actual")
            ) { db in
                _ = try DeliveryPlanningPolicy.applyRevision(
                    projectID: Self.project, phaseID: Self.phase, expectedRevision: 0, goalUpserts: drafts,
                    assignments: assignments, unassignedTicketIDs: [], supersededGoalIDs: [],
                    auditEventID: .init(rawValue: "missing-audit"), connection: db)
            }
        }
        _ = try await revise(store, goals: [goal("g")], assignments: [assignment("t", "g")], audit: "existing-audit")
        try await rejected(store) {
            _ = try await self.revise(
                store, revision: 1, goals: [self.goal("g", title: "Changed")], audit: "existing-audit")
        }
    }

    func testMigrationContinuationAdoptsOnlyExplicitDraftGoalAndPersistsOnRelaunch() async throws {
        for (phase, ticket) in [("phase-1", "ticket-active"), ("phase-2", "ticket-review")] {
            let (store, url) = try migratedFixture()
            let project = ProjectID(rawValue: "project-main")
            let phaseID = PhaseID(rawValue: phase)
            let tickets = try await store.read {
                try $0.rows(
                    "SELECT id FROM tickets WHERE project_id='project-main' AND phase_id=? AND lane<>'accepted' ORDER BY id",
                    bindings: [.text(phase)])
            }
            let assignments = tickets.map {
                assignment(Self.text($0["id"])!, Self.text($0["id"]) == ticket ? "adopted" : "planned")
            }
            try await rejected(store) {
                try await store.transact(actor: self.actor, reason: "No inference") {
                    _ = try DeliveryPlanningPolicy.finalizePlan(
                        projectID: project, phaseID: phaseID, expectedRevision: 0, connection: $0)
                }
            }
            let audit = AuditEventID(rawValue: UUID().uuidString)
            let drafts = [goal("adopted"), goal("planned")]
            try await store.transact(actor: actor, reason: "Explicit legacy assignment", auditEventID: audit) { db in
                _ = try DeliveryPlanningPolicy.applyRevision(
                    projectID: project, phaseID: phaseID, expectedRevision: 0, goalUpserts: drafts,
                    assignments: assignments, unassignedTicketIDs: [], supersededGoalIDs: [], auditEventID: audit,
                    connection: db)
            }
            try await store.transact(actor: actor, reason: "Finalize adoption") { db in
                _ = try DeliveryPlanningPolicy.finalizePlan(
                    projectID: project, phaseID: phaseID, expectedRevision: 1, connection: db)
            }
            let reopened = DeliveryStore(databaseURL: url)
            let result = try await reopened.read {
                try DeliveryPlanningPolicy.loadGoals(projectID: project, phaseID: phaseID, connection: $0)
            }
            XCTAssertEqual(result.first { $0.id.rawValue == "adopted" }?.lifecycle, .active)
            XCTAssertNotNil(result.first { $0.id.rawValue == "adopted" }?.activatedAt)
            XCTAssertEqual(result.first { $0.id.rawValue == "planned" }?.lifecycle, .planned)
            XCTAssertNil(result.first { $0.id.rawValue == "planned" }?.activatedAt)
            let continuation = try await reopened.read {
                try $0.scalarInt("SELECT plan_legacy_continuation FROM tickets WHERE id=?", bindings: [.text(ticket)])
            }
            XCTAssertEqual(continuation, 0)
            try await rejected(reopened) {
                try await reopened.transact(actor: self.actor, reason: "No standalone activation") {
                    _ = try DeliveryPlanningPolicy.transitionGoal(
                        projectID: project, phaseID: phaseID, goalID: .init(rawValue: "planned"),
                        expectedPlanRevision: 1, to: .active, origin: .ownerApp, connection: $0)
                }
            }
        }
    }

    func testMigrationAdoptionRejectsAmbiguousNonDraftAndRetroactiveAssignmentsAndRollsBack() async throws {
        let (store, _) = try migratedFixture()
        let project = ProjectID(rawValue: "project-main")
        let phase = PhaseID(rawValue: "phase-1")
        let drafts = [goal("g"), goal("h")]
        for assignments in [
            [assignment("ticket-active", "g"), assignment("ticket-active", "h")],
            [assignment("ticket-accepted", "g")],
        ] {
            try await rejected(store) {
                try await store.transact(actor: self.actor, reason: "Reject invalid adoption") { db in
                    _ = try DeliveryPlanningPolicy.applyRevision(
                        projectID: project, phaseID: phase, expectedRevision: 0, goalUpserts: drafts,
                        assignments: assignments, unassignedTicketIDs: [], supersededGoalIDs: [],
                        auditEventID: .init(rawValue: "invalid"), connection: db)
                }
            }
        }
        let assignments = [assignment("ticket-active", "g"), assignment("ticket-backlog", "h")]
        try await store.transact(
            actor: actor, reason: "Assign explicit adoption", auditEventID: .init(rawValue: "adoption")
        ) { db in
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: project, phaseID: phase, expectedRevision: 0, goalUpserts: drafts, assignments: assignments,
                unassignedTicketIDs: [], supersededGoalIDs: [], auditEventID: .init(rawValue: "adoption"),
                connection: db)
        }
        try await rejected(store) {
            try await store.transact(
                actor: self.actor, reason: "Finalization audit failure", auditEventID: .init(rawValue: "adoption")
            ) { db in
                _ = try DeliveryPlanningPolicy.finalizePlan(
                    projectID: project, phaseID: phase, expectedRevision: 1, connection: db)
            }
        }
        try await seed(store, "UPDATE delivery_goals SET lifecycle='planned' WHERE id='g'")
        try await rejected(store) {
            try await store.transact(actor: self.actor, reason: "Non-Draft cannot adopt") { db in
                _ = try DeliveryPlanningPolicy.finalizePlan(
                    projectID: project, phaseID: phase, expectedRevision: 1, connection: db)
            }
        }
    }

    private func migratedFixture() throws -> (DeliveryStore, URL) {
        let url = try databaseURL()
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
            "Fixtures/SchemaV10/release-radar-v10.sqlite")
        try FileManager.default.copyItem(at: source, to: url)
        // The frozen v10 fixture contains the schema. Seed only its synthetic copy
        // before migration; never grant the continuation flag in v11+ SQL.
        do {
            let legacy = try SQLiteConnection(url: url)
            try legacy.execute("INSERT INTO projects (id,name) VALUES ('project-main','Migration')")
            try legacy.execute(
                "INSERT INTO phases (id,project_id,name) VALUES ('phase-1','project-main','One'),('phase-2','project-main','Two')"
            )
            try legacy.execute(
                """
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES
                    ('ticket-active','project-main','phase-1','Active','in_progress'),
                    ('ticket-backlog','project-main','phase-1','Backlog','backlog'),
                    ('ticket-accepted','project-main','phase-1','Accepted history','accepted'),
                    ('ticket-review','project-main','phase-2','Review','needs_review'),
                    ('ticket-blocked','project-main','phase-2','Blocked','blocked')
                """)
        }
        return (DeliveryStore(databaseURL: url), url)
    }

    func testCanonicalEquivalentIdentitiesRemainByteDistinctThroughFinalizationAndTransfers() async throws {
        let store = try await fixture(ticketCount: 0)
        let composed = "\u{e9}"
        let decomposed = "e\u{301}"
        try await store.transact(actor: actor, reason: "Byte-distinct fixture identities") { db in
            for id in [composed, decomposed] {
                try db.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','phase','Unicode','backlog')",
                    bindings: [.text(id)])
            }
        }
        _ = try await revise(
            store, goals: [goal(composed), goal(decomposed)],
            assignments: [assignment(composed, composed), assignment(decomposed, decomposed)])
        _ = try await finalize(store, revision: 1)
        let storedGoals = try await goals(store)
        XCTAssertEqual(
            Set(storedGoals.map { Data($0.id.rawValue.utf8) }), Set([Data(composed.utf8), Data(decomposed.utf8)]))
        _ = try await revise(
            store, revision: 1, assignments: [assignment(composed, decomposed), assignment(decomposed, composed)])
        let assignments = try await store.read {
            try DeliveryPlanningPolicy.loadAssignments(projectID: Self.project, phaseID: Self.phase, connection: $0)
        }
        let byTicket = Dictionary(
            uniqueKeysWithValues: assignments.map { (Data($0.ticketID.rawValue.utf8), Data($0.goalID.rawValue.utf8)) })
        XCTAssertEqual(byTicket[Data(composed.utf8)], Data(decomposed.utf8))
        XCTAssertEqual(byTicket[Data(decomposed.utf8)], Data(composed.utf8))
        let history = try await store.read {
            try DeliveryPlanningPolicy.loadAssignmentHistory(
                projectID: Self.project, ticketID: .init(rawValue: composed), connection: $0)
        }
        XCTAssertEqual(history.map(\.action), ["assigned", "reassigned"])
        _ = try await finalize(store, revision: 2)
    }

    func testCanonicalEquivalentPhasesDoNotPermitGoalOwnershipBypass() async throws {
        let store = try await fixture()
        let composed = "\u{e9}"
        let decomposed = "e\u{301}"
        let draft = goal("unicode-phase-goal", criteria: [])
        try await store.transact(actor: actor, reason: "Byte-distinct phase fixture") { db in
            for id in [composed, decomposed] {
                try db.execute(
                    "INSERT INTO phases (id,project_id,name) VALUES (?,'p','Unicode phase')", bindings: [.text(id)])
            }
            _ = try DeliveryPlanningPolicy.applyRevision(
                projectID: Self.project, phaseID: .init(rawValue: composed), expectedRevision: 0, goalUpserts: [draft],
                assignments: [], unassignedTicketIDs: [], supersededGoalIDs: [],
                auditEventID: .init(rawValue: "unused"), connection: db)
        }
        try await rejected(store, expected: .goalPhaseMismatch(draft.id)) {
            try await store.transact(actor: self.actor, reason: "Reject equivalent spelling") { db in
                _ = try DeliveryPlanningPolicy.applyRevision(
                    projectID: Self.project, phaseID: .init(rawValue: decomposed), expectedRevision: 0,
                    goalUpserts: [draft], assignments: [], unassignedTicketIDs: [], supersededGoalIDs: [],
                    auditEventID: .init(rawValue: "unused"), connection: db)
            }
        }
    }

    // These SQL fixtures establish otherwise-unreachable lifecycle preconditions;
    // production ticket writer routing belongs to Task 7.
    private func fixture(ticketCount: Int = 1) async throws -> DeliveryStore {
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await store.transact(actor: actor, reason: "Synthetic fixture") { db in
            try db.execute("INSERT INTO projects (id,name) VALUES ('p','Project'),('foreign','Foreign')")
            try db.execute(
                "INSERT INTO phases (id,project_id,name) VALUES ('phase','p','Phase'),('other','p','Other'),('foreign-phase','foreign','Foreign')"
            )
            for index in 0..<ticketCount {
                try db.execute(
                    "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES (?,'p','phase','Outcome','backlog')",
                    bindings: [.text(index == 0 ? "t" : "t\(index)")])
            }
            try db.execute(
                "INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('other-phase-ticket','p','other','Other','backlog'),('foreign-ticket','foreign','foreign-phase','Foreign','backlog')"
            )
        }
        return store
    }

    private func readyFixture(ticketCount: Int = 1) async throws -> DeliveryStore {
        let store = try await fixture(ticketCount: ticketCount)
        _ = try await revise(
            store, goals: ticketCount == 1 ? [goal("g")] : [goal("g"), goal("h")],
            assignments: (0..<ticketCount).map { assignment($0 == 0 ? "t" : "t\($0)", $0 == 0 ? "g" : "h") })
        _ = try await finalize(store, revision: 1)
        return store
    }

    private func databaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "RR-R10-Task6-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("test.sqlite")
    }

    private func goal(
        _ id: String, title: String = "Goal", outcome: String = "Complete outcome", criteria: [String] = ["Delivered"],
        order: Int = 0
    ) -> DeliveryGoalDraft {
        .init(id: .init(rawValue: id), title: title, outcome: outcome, doneCriteria: criteria, sortOrder: order)
    }
    private func assignment(_ ticket: String, _ goal: String) -> DeliveryGoalAssignment {
        .init(goalID: .init(rawValue: goal), ticketID: .init(rawValue: ticket))
    }
    private func seed(_ store: DeliveryStore, _ sql: String) async throws {
        try await store.transact(actor: actor, reason: "Synthetic precondition") { try $0.execute(sql) }
    }
    private func revise(
        _ store: DeliveryStore, revision: Int64 = 0, goals: [DeliveryGoalDraft] = [],
        assignments: [DeliveryGoalAssignment] = [], unassigned: [String] = [], superseded: [String] = [],
        audit: String = UUID().uuidString
    ) async throws -> PhasePlanRecord {
        try await store.transact(
            actor: actor, reason: "Revise plan", auditEventID: .init(rawValue: audit),
            auditScope: .init(projectID: Self.project, entityType: .phasePlan, entityID: Self.phase.rawValue)
        ) {
            try DeliveryPlanningPolicy.applyRevision(
                projectID: Self.project, phaseID: Self.phase, expectedRevision: revision, goalUpserts: goals,
                assignments: assignments, unassignedTicketIDs: unassigned.map { .init(rawValue: $0) },
                supersededGoalIDs: superseded.map { .init(rawValue: $0) }, auditEventID: .init(rawValue: audit),
                connection: $0)
        }
    }
    private func finalize(_ store: DeliveryStore, revision: Int64) async throws -> PhasePlanRecord {
        try await store.transact(actor: actor, reason: "Finalize plan") {
            try DeliveryPlanningPolicy.finalizePlan(
                projectID: Self.project, phaseID: Self.phase, expectedRevision: revision, connection: $0)
        }
    }
    private func transition(
        _ store: DeliveryStore, to: DeliveryGoalLifecycle, revision: Int64 = 1,
        origin: AgentCommandOrigin = .externalAgent, actor: DeliveryActor? = nil
    ) async throws -> DeliveryGoalRecord {
        try await store.transact(actor: actor ?? self.actor, reason: "Goal lifecycle") {
            try DeliveryPlanningPolicy.transitionGoal(
                projectID: Self.project, phaseID: Self.phase, goalID: .init(rawValue: "g"),
                expectedPlanRevision: revision, to: to, origin: origin, connection: $0)
        }
    }
    private func plan(_ store: DeliveryStore) async throws -> PhasePlanRecord {
        try await store.read {
            try XCTUnwrap(DeliveryPlanningPolicy.loadPlan(projectID: Self.project, phaseID: Self.phase, connection: $0))
        }
    }
    private func goals(_ store: DeliveryStore) async throws -> [DeliveryGoalRecord] {
        try await store.read {
            try DeliveryPlanningPolicy.loadGoals(projectID: Self.project, phaseID: Self.phase, connection: $0)
        }
    }
    private func snapshot(_ store: DeliveryStore) async throws -> [[[String: SQLiteValue]]] {
        try await store.read { db in
            try [
                "phase_plans", "delivery_goals", "delivery_goal_done_criteria", "delivery_goal_ticket_assignments",
                "delivery_goal_assignment_events", "tickets", "ticket_task_plans", "ticket_tasks", "audit_events",
                "agent_command_requests", "notification_events", "review_items", "observed_goals", "ticket_goal_links",
            ].map { try db.rows("SELECT * FROM \($0) ORDER BY rowid") }
        }
    }
    private func rejected(
        _ store: DeliveryStore, expected: DeliveryPlanningPolicyError? = nil, file: StaticString = #filePath,
        line: UInt = #line, operation: () async throws -> Void
    ) async throws {
        let before = try await snapshot(store)
        do {
            try await operation()
            XCTFail("Expected rejection", file: file, line: line)
        } catch {
            if let expected { XCTAssertEqual(error as? DeliveryPlanningPolicyError, expected, file: file, line: line) }
        }
        let after = try await snapshot(store)
        XCTAssertEqual(before, after, file: file, line: line)
    }
    private static func text(_ value: SQLiteValue?) -> String? {
        if case .text(let value) = value { return value }
        return nil
    }
}
