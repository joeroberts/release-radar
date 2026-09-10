import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class PhaseLifecycleAcceptanceTests: XCTestCase {
    func testSchemaTwentyThreeBackfillsExistingPhasesWithoutInventingHistory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarPhaseLifecycleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let databaseURL = root.appendingPathComponent("store.sqlite")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SchemaV12/release-radar-v12.sqlite")
        try FileManager.default.copyItem(at: source, to: databaseURL)

        let store = DeliveryStore(databaseURL: databaseURL)
        let availability = await store.availability
        XCTAssertEqual(availability, .available)

        let facts = try await store.read { connection in
            (
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM phases WHERE NOT EXISTS (SELECT 1 FROM phase_lifecycles WHERE phase_lifecycles.project_id = phases.project_id AND phase_lifecycles.phase_id = phases.id AND phase_lifecycles.lifecycle = 'unassessed' AND phase_lifecycles.revision = 0)"
                ),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_lifecycle_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_phase_lifecycles"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_phase_lifecycle_events")
            )
        }

        XCTAssertEqual(facts.0, 0)
        XCTAssertEqual(facts.1, 0)
        XCTAssertEqual(facts.2, 0)
        XCTAssertEqual(facts.3, 0)
        XCTAssertEqual(try SQLiteConnection(url: databaseURL).scalarInt("PRAGMA user_version"), 23)
    }

    func testLifecycleDecisionsRequireOwnerExactRegistrationAndReplayWithOneHistoryEvent() async throws {
        let fixture = try await makeFixture()
        let requestID = UUID(uuidString: "00000000-0000-4000-8000-000000000501")!
        let request = envelope(
            fixture,
            requestID: requestID,
            command: .transitionPhaseLifecycle(
                projectID: fixture.registration.projectID.rawValue,
                phaseID: "phase-a",
                expectedRevision: 0,
                action: .moveToUpcoming,
                planningBaselineDigest: nil
            )
        )

        let external = await fixture.dispatcher.dispatch(request)
        XCTAssertEqual(external.error, .phaseLifecycleOwnerAuthorityRequired)

        let owner = await fixture.dispatcher.dispatch(request, origin: .ownerApp)
        XCTAssertNil(owner.error)
        XCTAssertEqual(owner.phaseLifecycle?.lifecycle, .upcoming)
        XCTAssertEqual(owner.phaseLifecycle?.revision, 1)

        let replay = await fixture.dispatcher.dispatch(request, origin: .ownerApp)
        XCTAssertEqual(replay, owner)
        let externalReplay = await fixture.dispatcher.dispatch(request)
        XCTAssertEqual(externalReplay.error, .phaseLifecycleOwnerAuthorityRequired)

        let missingRegistration = AgentCommandEnvelope(
            version: request.version,
            requestID: UUID(),
            projectRoot: request.projectRoot,
            reason: "Missing exact registration",
            command: request.command
        )
        let missing = await fixture.dispatcher.dispatch(missingRegistration, origin: .ownerApp)
        XCTAssertEqual(missing.error, .staleProjectRegistration)

        let staleRegistration = AgentCommandEnvelope(
            version: request.version,
            requestID: UUID(),
            projectRoot: request.projectRoot,
            expectedRegistration: .init(
                projectID: fixture.registration.projectID,
                registrationID: "stale-registration",
                requestGeneration: fixture.registration.requestGeneration
            ),
            reason: "Stale exact registration",
            command: request.command
        )
        let stale = await fixture.dispatcher.dispatch(staleRegistration, origin: .ownerApp)
        XCTAssertEqual(stale.error, .staleProjectRegistration)

        let facts = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT lifecycle FROM phase_lifecycles WHERE project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarInt("SELECT revision FROM phase_lifecycles WHERE project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_lifecycle_events WHERE project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarText("SELECT actor_id FROM audit_events WHERE id=?", bindings: [.text(try XCTUnwrap(owner.auditEventID).rawValue)])
            )
        }
        XCTAssertEqual(facts.0, "upcoming")
        XCTAssertEqual(facts.1, 1)
        XCTAssertEqual(facts.2, 1)
        XCTAssertEqual(facts.3, "release-radar-owner")
    }

    func testConcurrentLifecycleDecisionsCommitExactlyOneRevision() async throws {
        let fixture = try await makeFixture()
        let upcoming = envelope(
            fixture,
            requestID: UUID(),
            command: .transitionPhaseLifecycle(
                projectID: fixture.registration.projectID.rawValue,
                phaseID: "phase-a",
                expectedRevision: 0,
                action: .moveToUpcoming,
                planningBaselineDigest: nil
            )
        )
        let delivery = envelope(
            fixture,
            requestID: UUID(),
            command: .transitionPhaseLifecycle(
                projectID: fixture.registration.projectID.rawValue,
                phaseID: "phase-a",
                expectedRevision: 0,
                action: .beginDelivery,
                planningBaselineDigest: nil
            )
        )

        async let first = fixture.dispatcher.dispatch(upcoming, origin: .ownerApp)
        async let second = fixture.dispatcher.dispatch(delivery, origin: .ownerApp)
        let (firstResult, secondResult) = await (first, second)
        let results = [firstResult, secondResult]

        XCTAssertEqual(results.filter { $0.error == nil }.count, 1)
        XCTAssertEqual(
            results.compactMap(\.error),
            [.phaseLifecycleRevisionConflict(expected: 0, current: 1)]
        )
        let facts = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT revision FROM phase_lifecycles WHERE project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarInt("SELECT COUNT(*) FROM phase_lifecycle_events WHERE project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }
        XCTAssertEqual(facts.0, 1)
        XCTAssertEqual(facts.1, 1)
        XCTAssertEqual(facts.2, 1)
    }

    func testMultiplePhasesCanBeInDeliveryWhileActivePhaseRemainsIndependent() async throws {
        let fixture = try await makeFixture()
        for phaseID in ["phase-a", "phase-b"] {
            let result = await fixture.dispatcher.dispatch(
                envelope(
                    fixture,
                    requestID: UUID(),
                    command: .transitionPhaseLifecycle(
                        projectID: fixture.registration.projectID.rawValue,
                        phaseID: phaseID,
                        expectedRevision: 0,
                        action: .beginDelivery,
                        planningBaselineDigest: nil
                    )
                ),
                origin: .ownerApp
            )
            XCTAssertNil(result.error)
            XCTAssertEqual(result.phaseLifecycle?.lifecycle, .inDelivery)
        }

        let active = await fixture.dispatcher.dispatch(
            envelope(fixture, requestID: UUID(), command: .setActivePhase(phaseID: "phase-b"))
        )
        XCTAssertNil(active.error)
        let facts = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM phase_lifecycles WHERE project_id='lifecycle-project' AND lifecycle='in_delivery'"),
                try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id='lifecycle-project'")
            )
        }
        XCTAssertEqual(facts.0, 2)
        XCTAssertEqual(facts.1, "phase-b")
    }

    func testCompletionRequiresDeliveredWorkUsesRelevantBaselineAndReopensExplicitly() async throws {
        let fixture = try await makeFixture()
        let empty = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        XCTAssertFalse(empty.isEligible)
        XCTAssertEqual(empty.blockers.map(\.kind), [.noDeliveredOutcome])

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed delivered legacy scope") {
            try $0.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('accepted-work','lifecycle-project','phase-a','Delivered result','accepted')")
        }
        let eligible = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        XCTAssertTrue(eligible.isEligible)

        // Browsing context is independent of lifecycle and is not part of the
        // relevant completion baseline.
        let selected = await fixture.dispatcher.dispatch(
            envelope(fixture, requestID: UUID(), command: .setActivePhase(phaseID: "phase-b"))
        )
        XCTAssertNil(selected.error)
        let completed = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 0,
                    action: .complete,
                    planningBaselineDigest: eligible.planningBaselineDigest
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(completed.error)
        XCTAssertEqual(completed.phaseLifecycle?.lifecycle, .completed)

        let invalid = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 1,
                    action: .beginDelivery,
                    planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(
            invalid.error,
            .invalidPhaseLifecycleTransition(from: .completed, action: .beginDelivery)
        )

        let reopened = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 1,
                    action: .reopenInDelivery,
                    planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(reopened.error)
        XCTAssertEqual(reopened.phaseLifecycle?.lifecycle, .inDelivery)
        XCTAssertNil(reopened.phaseLifecycle?.completionBaselineDigest)

        let history = try await fixture.store.read {
            try PhaseLifecyclePolicy.history(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        XCTAssertEqual(history.map(\.action), [.complete, .reopenInDelivery])
        XCTAssertEqual(history.first?.planningBaselineDigest, eligible.planningBaselineDigest)
        XCTAssertNil(history.last?.planningBaselineDigest)
    }

    func testCompletionRejectsStaleBaselineAndSurfacesGoalCoverageBlockers() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed goal coverage") { connection in
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('goal-work','lifecycle-project','phase-a','Goal result','accepted')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at) VALUES ('lifecycle-project','phase-a','goal-a','Goal A','Outcome','draft',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('lifecycle-project','phase-a','goal-a','goal-work','Delivered scope','current','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('lifecycle-project','phase-a','goal-a','goal-work')")
        }
        let blocked = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        XCTAssertEqual(blocked.blockers.map(\.kind), [.goalNotAccepted])
        let blockedResult = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 0,
                    action: .complete,
                    planningBaselineDigest: blocked.planningBaselineDigest
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(blockedResult.error, .phaseCompletionBlocked(blocked.blockers))

        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Accept goal") {
            try $0.execute("UPDATE delivery_goals SET lifecycle='accepted',accepted_at='2026-09-10T00:01:00Z' WHERE project_id='lifecycle-project' AND phase_id='phase-a' AND id='goal-a'")
        }
        let eligible = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        XCTAssertTrue(eligible.isEligible)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Change unrelated planning fact") {
            try $0.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('unrelated','lifecycle-project','phase-b','Unrelated work','backlog')")
        }
        let unchanged = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        XCTAssertEqual(unchanged.planningBaselineDigest, eligible.planningBaselineDigest)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Change relevant planning fact") {
            try $0.execute("UPDATE tickets SET outcome='Changed delivered result' WHERE project_id='lifecycle-project' AND id='goal-work'")
        }
        let stale = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 0,
                    action: .complete,
                    planningBaselineDigest: eligible.planningBaselineDigest
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(stale.error, .phaseLifecyclePlanningBaselineConflict)
    }

    func testCompletionCreditsDeliveredCarriedDescendantsButRejectsAllDroppedScope() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Seed carried completion coverage",
            auditEventID: .init(rawValue: "phase-lifecycle-carry-audit")
        ) { connection in
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,accepted_at,created_at,updated_at) VALUES ('lifecycle-project','phase-a','source-goal','Source goal','Outcome','accepted',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,accepted_at,created_at,updated_at) VALUES ('lifecycle-project','phase-b','descendant-goal','Descendant goal','Outcome','accepted',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('source-ticket','lifecycle-project','phase-a','Original work','accepted'),('descendant-ticket','lifecycle-project','phase-b','Delivered successor','accepted')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('lifecycle-project','phase-a','source-goal','source-ticket','Original scope','current','2026-09-10T00:00:00Z'),('lifecycle-project','phase-b','descendant-goal','descendant-ticket','Carried scope','current','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('lifecycle-project','phase-b','descendant-goal','descendant-ticket')")
            try connection.execute("INSERT INTO delivery_goal_obligation_lineage (project_id,source_phase_id,source_goal_id,source_ticket_id,descendant_phase_id,descendant_goal_id,descendant_ticket_id,reason,audit_event_id,created_at) VALUES ('lifecycle-project','phase-a','source-goal','source-ticket','phase-b','descendant-goal','descendant-ticket','Carry scope','phase-lifecycle-carry-audit','2026-09-10T00:00:00Z')")
        }
        let carried = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"), connection: $0
            )
        }
        XCTAssertTrue(carried.isEligible)

        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Drop every delivered leaf",
            auditEventID: .init(rawValue: "phase-lifecycle-drop-audit")
        ) { connection in
            try connection.execute("INSERT INTO delivery_goal_obligation_drops (project_id,phase_id,goal_id,ticket_id,reason,audit_event_id,created_at) VALUES ('lifecycle-project','phase-b','descendant-goal','descendant-ticket','Scope no longer applies','phase-lifecycle-drop-audit','2026-09-10T00:01:00Z')")
        }
        let dropped = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"), connection: $0
            )
        }
        XCTAssertEqual(
            dropped.blockers.map(\.kind),
            [.noDeliveredOutcome]
        )
    }

    func testCompletionAllowsFullyDroppedGoalAlongsideAcceptedDelivery() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(
            actor: .init(id: "fixture"), reason: "Seed delivered and explicitly removed scope",
            auditEventID: .init(rawValue: "phase-lifecycle-mixed-scope-audit")
        ) { connection in
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,accepted_at,created_at,updated_at) VALUES ('lifecycle-project','phase-a','delivered-goal','Delivered goal','Delivered outcome','accepted',0,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,activated_at,created_at,updated_at) VALUES ('lifecycle-project','phase-a','dropped-goal','Dropped goal','Removed outcome','active',1,'2026-09-10T00:00:00Z','2026-09-10T00:00:00Z','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('delivered-ticket','lifecycle-project','phase-a','Delivered work','accepted'),('dropped-ticket','lifecycle-project','phase-a','Removed work','backlog')")
            try connection.execute("INSERT INTO delivery_goal_obligations (project_id,phase_id,goal_id,ticket_id,scope,assessment,created_at) VALUES ('lifecycle-project','phase-a','delivered-goal','delivered-ticket','Delivered scope','current','2026-09-10T00:00:00Z'),('lifecycle-project','phase-a','dropped-goal','dropped-ticket','Removed scope','current','2026-09-10T00:00:00Z')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('lifecycle-project','phase-a','delivered-goal','delivered-ticket'),('lifecycle-project','phase-a','dropped-goal','dropped-ticket')")
            try connection.execute("INSERT INTO ticket_retirements (project_id,ticket_id,disposition,reason,last_phase_id,last_lane,audit_event_id,retired_at) VALUES ('lifecycle-project','dropped-ticket','withdrawn','Scope no longer applies','phase-a','backlog','phase-lifecycle-mixed-scope-audit','2026-09-10T00:01:00Z')")
            try connection.execute("INSERT INTO delivery_goal_obligation_drops (project_id,phase_id,goal_id,ticket_id,reason,audit_event_id,created_at) VALUES ('lifecycle-project','phase-a','dropped-goal','dropped-ticket','Owner intentionally removed this scope','phase-lifecycle-mixed-scope-audit','2026-09-10T00:01:00Z')")
        }

        let assessment = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }

        XCTAssertTrue(assessment.isEligible)
        XCTAssertTrue(assessment.blockers.isEmpty)
    }

    func testCompletedPhaseBlocksDeliveryWritersButAllowsBrowsingAndOpenWorkReferences() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed completed work") {
            try $0.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('completed-ticket','lifecycle-project','phase-a','Delivered result','accepted')")
            try $0.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('open-ticket','lifecycle-project','phase-b','Open result','backlog')")
            try $0.execute("INSERT INTO review_items (id,project_id,ticket_id,kind,summary,status) VALUES ('completed-review','lifecycle-project','completed-ticket','import','Resolve only after reopening','open')")
        }
        let assessment = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                connection: $0
            )
        }
        let completion = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 0,
                    action: .complete,
                    planningBaselineDigest: assessment.planningBaselineDigest
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(completion.error)

        let rejected: [AgentCommand] = [
            .upsertPhase(phaseID: "phase-a", name: "Renamed completed phase"),
            .upsertTicket(ticketID: "new-completed-work", phaseID: "phase-a", outcome: "Must reopen", lane: .backlog),
            .upsertTicket(ticketID: "completed-ticket", phaseID: "phase-b", outcome: "Cannot rehome from completed", lane: .backlog),
            .upsertTicket(ticketID: "open-ticket", phaseID: "phase-a", outcome: "Cannot rehome into completed", lane: .backlog),
            .applyPhasePlanRevision(projectID: "lifecycle-project", phaseID: "phase-a", expectedRevision: 0),
            .setDependency(id: "completed-subject", kind: .phase, subjectID: "phase-a", dependsOnID: "phase-b"),
            .recordBlocker(id: "late-blocker", ticketID: "completed-ticket", summary: "Must reopen"),
            .resolveImportReview(reviewItemID: "completed-review"),
            .savePlanChangeProposal(
                proposalID: "late-proposal",
                expectedPreviousVersion: nil,
                rationale: "Must not target completed work",
                operations: [.addDeliveryGoal(
                    phaseID: .init(rawValue: "phase-a"),
                    goal: .init(
                        id: .init(rawValue: "late-goal"),
                        title: "Late goal",
                        outcome: "Out of lifecycle",
                        doneCriteria: ["Must reopen"],
                        sortOrder: 0
                    )
                )]
            ),
        ]
        for command in rejected {
            let result = await fixture.dispatcher.dispatch(
                envelope(fixture, requestID: UUID(), command: command)
            )
            XCTAssertEqual(
                result.error,
                .completedPhaseReadOnly(.init(rawValue: "phase-a")),
                "Expected completed-phase guard for \(command)"
            )
        }

        let browse = await fixture.dispatcher.dispatch(
            envelope(fixture, requestID: UUID(), command: .setActivePhase(phaseID: "phase-a"))
        )
        XCTAssertNil(browse.error)
        let openReference = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .setDependency(
                    id: "open-references-completed",
                    kind: .phase,
                    subjectID: "phase-b",
                    dependsOnID: "phase-a"
                )
            )
        )
        XCTAssertNil(openReference.error)
    }

    func testLifecycleChangesStaleProposalApprovalAndCompletedPhaseBlocksPreviouslyApprovedApply() async throws {
        let fixture = try await makeFixture()
        let saved = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(),
            command: .savePlanChangeProposal(
                proposalID: "lifecycle-baseline",
                expectedPreviousVersion: nil,
                rationale: "Capture lifecycle facts",
                operations: [.addPhaseDependency(
                    id: .init(rawValue: "phase-a-needs-b"),
                    phaseID: .init(rawValue: "phase-a"),
                    dependsOnPhaseID: .init(rawValue: "phase-b")
                )]
            )
        ))
        XCTAssertNil(saved.error)
        let proposal = try await fixture.store.read {
            try XCTUnwrap(PlanChangeProposalQuery.load(
                from: $0, projectID: fixture.registration.projectID
            ).first?.versions.first)
        }
        let lifecycleChange = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a",
                    expectedRevision: 0,
                    action: .moveToUpcoming,
                    planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(lifecycleChange.error)
        let staleDecision = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: "lifecycle-baseline", version: 1,
                    baselineDigest: proposal.baselineDigest,
                    decisionID: "stale-decision", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(
            staleDecision.error,
            .planChangeProposalStale([.phaseLifecycles, .phaseLifecycleEvents])
        )

        let refreshed = await fixture.dispatcher.dispatch(envelope(
            fixture,
            requestID: UUID(),
            command: .savePlanChangeProposal(
                proposalID: "lifecycle-baseline",
                expectedPreviousVersion: 1,
                rationale: "Refresh after lifecycle decision",
                operations: [.addPhaseDependency(
                    id: .init(rawValue: "phase-a-needs-b"),
                    phaseID: .init(rawValue: "phase-a"),
                    dependsOnPhaseID: .init(rawValue: "phase-b")
                )]
            )
        ))
        XCTAssertNil(refreshed.error)
        let current = try await fixture.store.read {
            try XCTUnwrap(PlanChangeProposalQuery.load(
                from: $0, projectID: fixture.registration.projectID
            ).first?.versions.first(where: { $0.version == 2 }))
        }
        let approved = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .decidePlanChangeProposal(
                    proposalID: "lifecycle-baseline", version: 2,
                    baselineDigest: current.baselineDigest,
                    decisionID: "approved-before-completion", disposition: .approved
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(approved.error)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed delivered work") {
            try $0.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('proposal-work','lifecycle-project','phase-a','Delivered','accepted')")
        }
        let assessment = try await fixture.store.read {
            try PhaseLifecyclePolicy.assessCompletion(
                projectID: fixture.registration.projectID,
                phaseID: .init(rawValue: "phase-a"), connection: $0)
        }
        let completed = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a", expectedRevision: 1, action: .complete,
                    planningBaselineDigest: assessment.planningBaselineDigest
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(completed.error)
        let apply = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .applyPlanChangeProposal(
                    proposalID: "lifecycle-baseline", version: 2,
                    baselineDigest: current.baselineDigest,
                    decisionID: "approved-before-completion", applicationID: "blocked-apply"
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(apply.error, .completedPhaseReadOnly(.init(rawValue: "phase-a")))
    }

    func testReadOnlyLifecycleQueryReturnsAllStatesAndEligibilityWithoutMutation() async throws {
        let fixture = try await makeFixture()
        let transition = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a", expectedRevision: 0,
                    action: .moveToUpcoming, planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(transition.error)
        let before = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }
        let result = await AgentQueryDispatcher(store: fixture.store).dispatch(.init(
            version: 1,
            projectRoot: fixture.root.path,
            query: .phaseLifecycles(projectID: fixture.registration.projectID.rawValue)
        ))
        XCTAssertNil(result.error)
        XCTAssertEqual(result.phaseLifecycles?.map(\.phaseID.rawValue), ["phase-a", "phase-b"])
        XCTAssertEqual(result.phaseLifecycles?.map(\.lifecycle), [.upcoming, .unassessed])
        XCTAssertEqual(result.phaseLifecycleEvents?.map(\.action), [.moveToUpcoming])
        XCTAssertEqual(result.phaseLifecycleEvents?.first?.registration, fixture.registration)
        XCTAssertEqual(result.phaseCompletionAssessments?.count, 2)
        let after = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events")
        }
        XCTAssertEqual(after, before)
    }

    func testRemovalRetainsCurrentLifecycleAndImmutableTransitionHistory() async throws {
        let fixture = try await makeFixture()
        let moved = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a", expectedRevision: 0,
                    action: .beginDelivery, planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(moved.error)
        try await Task.sleep(for: .milliseconds(10))
        let movedAgain = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a", expectedRevision: 1,
                    action: .moveToUpcoming, planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertNil(movedAgain.error)
        let liveLifecycle = try await fixture.store.read { connection in
            (
                try PhaseLifecyclePolicy.current(
                    projectID: fixture.registration.projectID,
                    phaseID: .init(rawValue: "phase-a"),
                    connection: connection
                ),
                try PhaseLifecyclePolicy.history(
                    projectID: fixture.registration.projectID,
                    phaseID: .init(rawValue: "phase-a"),
                    connection: connection
                )
            )
        }
        let manager = ProjectRemovalManager(store: fixture.store)
        let preview = try await manager.preview(projectID: fixture.registration.projectID)
        let removed = try await manager.apply(preview)
        let retained = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT lifecycle FROM retained_phase_lifecycles WHERE historical_project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarInt("SELECT revision FROM retained_phase_lifecycles WHERE historical_project_id='lifecycle-project' AND phase_id='phase-a'"),
                try connection.scalarInt("SELECT COUNT(*) FROM retained_phase_lifecycle_events WHERE historical_project_id='lifecycle-project' AND phase_id='phase-a'")
            )
        }
        XCTAssertEqual(retained.0, "upcoming")
        XCTAssertEqual(retained.1, 2)
        XCTAssertEqual(retained.2, 2)

        let history = try await ProjectActivityProjection.loadRemoved(
            from: fixture.store,
            removalID: removed.id
        )
        let current = try XCTUnwrap(history.items.first {
            $0.id == "phase-lifecycle-current-phase-a"
        })
        XCTAssertEqual(current.phaseID?.rawValue, "phase-a")
        XCTAssertEqual(current.title, "Phase lifecycle · Phase A")
        XCTAssertEqual(current.detail, "Current · Upcoming · revision 2")
        XCTAssertEqual(current.observedAt, liveLifecycle.0.updatedAt)
        XCTAssertEqual(current.retainedPhaseLifecycle?.kind, .current)
        XCTAssertEqual(current.retainedPhaseLifecycle?.removalID, removed.id)
        XCTAssertEqual(current.retainedPhaseLifecycle?.historicalProjectID, fixture.registration.projectID)
        XCTAssertEqual(current.retainedPhaseLifecycle?.lifecycle, .upcoming)
        XCTAssertEqual(current.retainedPhaseLifecycle?.revision, 2)
        let firstEvent = try XCTUnwrap(history.items.first {
            $0.id == "phase-lifecycle-event-phase-a-1"
        })
        XCTAssertEqual(firstEvent.phaseID?.rawValue, "phase-a")
        XCTAssertEqual(firstEvent.title, "Phase lifecycle transition · Phase A")
        XCTAssertEqual(
            firstEvent.detail,
            "Unassessed → In delivery · Begin delivery · revision 1 · Exercise owner phase lifecycle"
        )
        XCTAssertEqual(firstEvent.observedAt, liveLifecycle.1[0].createdAt)
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.kind, .transition)
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.previousLifecycle, .unassessed)
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.lifecycle, .inDelivery)
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.action, .beginDelivery)
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.reason, "Exercise owner phase lifecycle")
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.auditEventID, moved.auditEventID)
        XCTAssertEqual(firstEvent.retainedPhaseLifecycle?.registration, fixture.registration)
        XCTAssertNil(firstEvent.retainedPhaseLifecycle?.planningBaselineDigest)
        let secondEvent = try XCTUnwrap(history.items.first {
            $0.id == "phase-lifecycle-event-phase-a-2"
        })
        XCTAssertEqual(secondEvent.observedAt, liveLifecycle.1[1].createdAt)
        XCTAssertEqual(secondEvent.retainedPhaseLifecycle?.previousLifecycle, .inDelivery)
        XCTAssertEqual(secondEvent.retainedPhaseLifecycle?.lifecycle, .upcoming)
        XCTAssertEqual(secondEvent.retainedPhaseLifecycle?.action, .moveToUpcoming)
        XCTAssertEqual(secondEvent.retainedPhaseLifecycle?.auditEventID, movedAgain.auditEventID)
        XCTAssertEqual(
            history.items.filter { $0.retainedPhaseLifecycle != nil }.map(\.id),
            [
                "phase-lifecycle-current-phase-a",
                "phase-lifecycle-event-phase-a-2",
                "phase-lifecycle-event-phase-a-1",
                "phase-lifecycle-current-phase-b",
            ]
        )

        let rejected = await fixture.dispatcher.dispatch(
            envelope(
                fixture,
                requestID: UUID(),
                command: .transitionPhaseLifecycle(
                    projectID: fixture.registration.projectID.rawValue,
                    phaseID: "phase-a", expectedRevision: 2,
                    action: .beginDelivery, planningBaselineDigest: nil
                )
            ),
            origin: .ownerApp
        )
        XCTAssertEqual(rejected.error, .unauthorizedProjectRoot)
        let historyAfterRejectedMutation = try await ProjectActivityProjection.loadRemoved(
            from: fixture.store,
            removalID: removed.id
        )
        XCTAssertEqual(historyAfterRejectedMutation, history)
    }

    private struct Fixture {
        let store: DeliveryStore
        let dispatcher: AgentCommandDispatcher
        let root: URL
        let registration: ProjectRegistration
    }

    private func makeFixture() async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadarPhaseLifecycleFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("store.sqlite"))
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "lifecycle-project"),
            registrationID: "lifecycle-registration",
            requestGeneration: 1
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed lifecycle fixture") { connection in
            try connection.execute("INSERT INTO projects (id,name,first_dashboard_opened) VALUES ('lifecycle-project','Lifecycle Project',1)")
            try connection.execute(
                "INSERT INTO project_roots (id,project_id,path) VALUES ('root','lifecycle-project',?)",
                bindings: [.text(root.path)]
            )
            try connection.execute("INSERT INTO project_registrations (project_id,registration_id,request_generation,setup_state) VALUES ('lifecycle-project','lifecycle-registration',1,'complete')")
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: registration.projectID,
                phaseID: .init(rawValue: "phase-a"),
                name: "Phase A",
                mode: .governed,
                connection: connection
            )
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: registration.projectID,
                phaseID: .init(rawValue: "phase-b"),
                name: "Phase B",
                mode: .governed,
                connection: connection
            )
        }
        let project = AuthorizedProject(
            registration: registration,
            canonicalRoot: root,
            authorizedRoots: [root]
        )
        return .init(
            store: store,
            dispatcher: .init(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
            ),
            root: root,
            registration: registration
        )
    }

    private func envelope(
        _ fixture: Fixture,
        requestID: UUID,
        command: AgentCommand
    ) -> AgentCommandEnvelope {
        .init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: fixture.root.path,
            expectedRegistration: fixture.registration,
            reason: "Exercise owner phase lifecycle",
            command: command
        )
    }
}
