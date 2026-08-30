import Foundation
import XCTest
@testable import ReleaseRadarCore

final class AgentBridgeAcceptanceTests: XCTestCase {
    private final class StoreQueueGate: @unchecked Sendable {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
    }

    func testValidTransitionCommitsAuditAndDurableReplayReturnsOriginalResult() async throws {
        let fixture = try await makeFixture()
        let requestID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            assertedThreadID: "asserted-thread",
            reason: "Move RR-03 into implementation",
            command: .transitionTicket(ticketID: "RR-03", lane: .inProgress)
        )

        let first = await fixture.dispatcher.dispatch(envelope)
        let relaunchedDispatcher = AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectRegistry: fixture.registry
        )
        let replay = await relaunchedDispatcher.dispatch(envelope)

        XCTAssertNil(first.error)
        XCTAssertEqual(first.entityIDs, ["RR-03"])
        XCTAssertNotNil(first.auditEventID)
        XCTAssertEqual(replay, first)

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Move RR-03 into implementation'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?", bindings: [.text(requestID.uuidString)]),
                try connection.scalarText("SELECT thread_attribution FROM audit_events WHERE reason = 'Move RR-03 into implementation'"),
                try connection.scalarText("SELECT project_id FROM audit_events WHERE reason = 'Move RR-03 into implementation'"),
                try connection.scalarText("SELECT entity_type FROM audit_events WHERE reason = 'Move RR-03 into implementation'"),
                try connection.scalarText("SELECT entity_id FROM audit_events WHERE reason = 'Move RR-03 into implementation'")
            )
        }
        XCTAssertEqual(state.0, TicketLane.inProgress.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, ThreadAttribution.asserted.rawValue)
        XCTAssertEqual(state.4, "project-1")
        XCTAssertEqual(state.5, AuditEntityType.ticket.rawValue)
        XCTAssertEqual(state.6, "RR-03")
    }

    func testSetActivePhaseCommitsOnlyPointerAuditAndReceiptAndDurablyReplays() async throws {
        let fixture = try await makeActivePhaseFixture()
        let before = try await Self.activePhaseSnapshot(fixture.store)
        let requestID = UUID(uuidString: "19191919-1919-4919-8919-191919191911")!
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            assertedThreadID: "asserted-phase-thread",
            reason: "Select roadmap phase",
            command: .setActivePhase(phaseID: "RR-ROADMAP")
        )

        let first = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(first.error)
        XCTAssertEqual(first.entityIDs, ["RR-ROADMAP"])
        let auditEventID = try XCTUnwrap(first.auditEventID)

        let afterFirst = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(afterFirst.activeRows, ["project-1|RR-ROADMAP"])
        XCTAssertEqual(afterFirst.phases, before.phases)
        XCTAssertEqual(afterFirst.tickets, before.tickets)
        XCTAssertEqual(afterFirst.phaseDependencies, before.phaseDependencies)
        XCTAssertEqual(afterFirst.ticketDependencies, before.ticketDependencies)
        XCTAssertEqual(afterFirst.auditRows.count, before.auditRows.count + 1)
        XCTAssertTrue(Set(afterFirst.auditRows).isSuperset(of: Set(before.auditRows)))
        XCTAssertEqual(afterFirst.requestRows.count, before.requestRows.count + 1)
        XCTAssertTrue(Set(afterFirst.requestRows).isSuperset(of: Set(before.requestRows)))

        let auditMatches = try await fixture.store.read { connection in
            try connection.scalarInt(
                """
                SELECT COUNT(*) FROM audit_events
                WHERE id = ?
                  AND actor_id = 'release-radar-agent'
                  AND thread_id = 'asserted-phase-thread'
                  AND thread_attribution = 'asserted'
                  AND reason = 'Select roadmap phase'
                  AND project_id = 'project-1'
                  AND entity_type = 'phase'
                  AND entity_id = 'RR-ROADMAP'
                  AND created_at <> ''
                """,
                bindings: [.text(auditEventID.rawValue)]
            )
        }
        XCTAssertEqual(auditMatches, 1)

        let replay = await AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectRegistry: fixture.registry
        ).dispatch(envelope)
        XCTAssertEqual(replay, first)
        let afterReplay = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(afterReplay, afterFirst)
    }

    func testSetActivePhaseOwnerOriginUsesOwnerAttributionWithoutAssertedThread() async throws {
        let fixture = try await makeActivePhaseFixture()
        let result = await fixture.dispatcher.dispatch(
            .init(
                version: 1,
                requestID: UUID(uuidString: "19191919-1919-4919-8919-191919191912")!,
                projectRoot: fixture.projectRoot.path,
                assertedThreadID: "must-not-be-recorded-for-owner",
                reason: "Owner selected roadmap phase",
                command: .setActivePhase(phaseID: "RR-ROADMAP")
            ),
            origin: .ownerApp
        )

        XCTAssertNil(result.error)
        XCTAssertEqual(result.entityIDs, ["RR-ROADMAP"])
        let auditEventID = try XCTUnwrap(result.auditEventID)
        let state = try await fixture.store.read { connection in
            [
                try connection.scalarInt(
                    """
                    SELECT COUNT(*) FROM audit_events
                    WHERE id = ?
                      AND actor_id = 'release-radar-owner'
                      AND thread_id IS NULL
                      AND thread_attribution = 'none'
                      AND reason = 'Owner selected roadmap phase'
                      AND project_id = 'project-1'
                      AND entity_type = 'phase'
                      AND entity_id = 'RR-ROADMAP'
                      AND created_at <> ''
                    """,
                    bindings: [.text(auditEventID.rawValue)]
                ) ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '19191919-1919-4919-8919-191919191912'") ?? -1,
            ]
        }
        XCTAssertEqual(state, [1, 1])
    }

    func testSetActivePhaseRejectsMissingCrossProjectAndUnauthorizedTargetsWithoutWrites() async throws {
        let fixture = try await makeActivePhaseFixture()
        let baseline = try await Self.activePhaseSnapshot(fixture.store)
        let cases: [(String, String, String, (AgentCommandError) -> Bool)] = [
            (
                "19191919-1919-4919-8919-191919191913",
                fixture.projectRoot.path,
                "missing-phase",
                { if case .invalidReference = $0 { return true }; return false }
            ),
            (
                "19191919-1919-4919-8919-191919191914",
                fixture.projectRoot.path,
                "other-project-phase",
                { if case .crossProjectReference = $0 { return true }; return false }
            ),
            (
                "19191919-1919-4919-8919-191919191915",
                fixture.projectRoot.deletingLastPathComponent().path,
                "RR-ROADMAP",
                { $0 == .unauthorizedProjectRoot }
            ),
            (
                "19191919-1919-4919-8919-191919191916",
                fixture.projectRoot.path,
                "",
                { if case .invalidEnvelope = $0 { return true }; return false }
            ),
        ]

        for (requestID, projectRoot, phaseID, matches) in cases {
            let result = await fixture.dispatcher.dispatch(.init(
                version: 1,
                requestID: UUID(uuidString: requestID)!,
                projectRoot: projectRoot,
                reason: "Reject invalid active phase",
                command: .setActivePhase(phaseID: phaseID)
            ))
            guard let error = result.error, matches(error) else {
                return XCTFail("Unexpected active-phase validation result for \(phaseID): \(result)")
            }
            let after = try await Self.activePhaseSnapshot(fixture.store)
            XCTAssertEqual(after, baseline)
        }
    }

    func testSetActivePhaseRejects258ByteIdentifierBeforeAnyWrite() async throws {
        let fixture = try await makeActivePhaseFixture()
        let baseline = try await Self.activePhaseSnapshot(fixture.store)
        let oversizedPhaseID = String(repeating: "é", count: 129)
        XCTAssertEqual(oversizedPhaseID.utf8.count, 258)

        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "19191919-1919-4919-8919-191919191917")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject oversized phase identity",
            command: .setActivePhase(phaseID: oversizedPhaseID)
        ))

        guard case .invalidEnvelope? = result.error else {
            return XCTFail("Expected invalidEnvelope, got \(String(describing: result.error))")
        }
        let after = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(after, baseline)
    }

    func testSetActivePhaseFreshAlreadyActiveIntentAuditsOnceAndReplayAddsNothing() async throws {
        let fixture = try await makeActivePhaseFixture()
        let before = try await Self.activePhaseSnapshot(fixture.store)
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(uuidString: "19191919-1919-4919-8919-191919191918")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Confirm current phase intent",
            command: .setActivePhase(phaseID: "phase-current")
        )

        let first = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(first.error)
        XCTAssertEqual(first.entityIDs, ["phase-current"])
        XCTAssertNotNil(first.auditEventID)
        let afterFirst = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(afterFirst.activeRows, before.activeRows)
        XCTAssertEqual(afterFirst.phases, before.phases)
        XCTAssertEqual(afterFirst.tickets, before.tickets)
        XCTAssertEqual(afterFirst.phaseDependencies, before.phaseDependencies)
        XCTAssertEqual(afterFirst.ticketDependencies, before.ticketDependencies)
        XCTAssertEqual(afterFirst.auditRows.count, before.auditRows.count + 1)
        XCTAssertEqual(afterFirst.requestRows.count, before.requestRows.count + 1)

        let replay = await AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectRegistry: fixture.registry
        ).dispatch(envelope)
        XCTAssertEqual(replay, first)
        let afterReplay = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(afterReplay, afterFirst)
    }

    func testSetActivePhaseChangedBodyRequestIDReusePreservesOriginalSelection() async throws {
        let fixture = try await makeActivePhaseFixture()
        let requestID = UUID(uuidString: "19191919-1919-4919-8919-191919191919")!
        let first = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Select active phase with stable request",
            command: .setActivePhase(phaseID: "RR-ROADMAP")
        ))
        XCTAssertNil(first.error)
        let afterFirst = try await Self.activePhaseSnapshot(fixture.store)

        let reused = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Select active phase with stable request",
            command: .setActivePhase(phaseID: "phase-historical")
        ))

        XCTAssertEqual(reused.error, .requestIDReused)
        let afterReuse = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(afterReuse, afterFirst)
        XCTAssertEqual(afterFirst.activeRows, ["project-1|RR-ROADMAP"])
    }

    func testLinkGoalPersistsTicketScopedAuditAndDurableReplay() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed approved goal candidate") { connection in
            try connection.execute(
                "INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-approved', 'project-1', 'verified-thread', 'active', 'Ship the approved identity', '2026-08-25T10:00:00Z')"
            )
            try connection.execute(
                "INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-approved', 'project-1', 'RR-03', 'verified-thread')"
            )
        }
        let envelope = AgentCommandEnvelope(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "12121212-1212-4212-8212-121212121212")!,
            projectRoot: fixture.projectRoot.path,
            assertedThreadID: "verified-thread",
            reason: "Approve RR-03 goal identity",
            command: .linkGoal(id: "goal-link-approved", ticketID: "RR-03", goalID: "goal-approved")
        )

        let first = await fixture.dispatcher.dispatch(envelope)
        let replay = await AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectRegistry: fixture.registry
        ).dispatch(envelope)

        XCTAssertNil(first.error)
        XCTAssertEqual(first.entityIDs, ["goal-link-approved"])
        XCTAssertEqual(replay, first)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT project_id || '|' || ticket_id || '|' || thread_id || '|' || goal_id FROM ticket_goal_links WHERE id = 'goal-link-approved'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Approve RR-03 goal identity'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '12121212-1212-4212-8212-121212121212'"),
                try connection.scalarText("SELECT entity_type FROM audit_events WHERE reason = 'Approve RR-03 goal identity'"),
                try connection.scalarText("SELECT entity_id FROM audit_events WHERE reason = 'Approve RR-03 goal identity'"),
                try connection.scalarText("SELECT thread_id FROM audit_events WHERE reason = 'Approve RR-03 goal identity'"),
                try connection.scalarText("SELECT thread_attribution FROM audit_events WHERE reason = 'Approve RR-03 goal identity'")
            )
        }
        XCTAssertEqual(state.0, "project-1|RR-03|verified-thread|goal-approved")
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, AuditEntityType.ticket.rawValue)
        XCTAssertEqual(state.4, "RR-03")
        XCTAssertEqual(state.5, "verified-thread")
        XCTAssertEqual(state.6, ThreadAttribution.asserted.rawValue)
    }

    func testLinkGoalRejectsMissingCrossProjectWrongThreadAndCrossTicketReuseWithoutWrites() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed goal validation boundaries") { connection in
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-04', 'project-1', 'phase-1', 'Second ticket', 'backlog')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('local-other-thread', 'project-1', 'active', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-approved', 'project-1', 'verified-thread', 'active', 'Approved goal', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-unused', 'project-1', 'verified-thread', 'active', 'Unused valid goal', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-wrong-thread', 'project-1', 'local-other-thread', 'active', 'Wrong thread goal', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at) VALUES ('goal-other-project', 'project-2', 'other-thread', 'active', 'Other project goal', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-3', 'project-1', 'RR-03', 'verified-thread')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-4', 'project-1', 'RR-04', 'verified-thread')")
        }
        let approved = await fixture.dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "13131313-1313-4313-8313-131313131310")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Approve first ticket goal",
            command: .linkGoal(id: "goal-link-approved", ticketID: "RR-03", goalID: "goal-approved")
        ))
        XCTAssertNil(approved.error)
        let baseline = try await fixture.store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_goal_links") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
            ]
        }

        let cases: [(String, String, AgentCommand, (AgentCommandError) -> Bool)] = [
            (
                "13131313-1313-4313-8313-131313131311",
                "Reject missing goal",
                .linkGoal(id: "goal-link-missing", ticketID: "RR-03", goalID: "missing-goal"),
                { if case .invalidReference = $0 { return true }; return false }
            ),
            (
                "13131313-1313-4313-8313-131313131312",
                "Reject cross-project goal",
                .linkGoal(id: "goal-link-cross-project", ticketID: "RR-03", goalID: "goal-other-project"),
                { if case .crossProjectReference = $0 { return true }; return false }
            ),
            (
                "13131313-1313-4313-8313-131313131313",
                "Reject wrong-thread goal",
                .linkGoal(id: "goal-link-wrong-thread", ticketID: "RR-03", goalID: "goal-wrong-thread"),
                { if case .invalidReference = $0 { return true }; return false }
            ),
            (
                "13131313-1313-4313-8313-131313131314",
                "Reject cross-ticket goal reuse",
                .linkGoal(id: "goal-link-reused", ticketID: "RR-04", goalID: "goal-approved"),
                { if case .invalidReference = $0 { return true }; return false }
            ),
            (
                "13131313-1313-4313-8313-131313131315",
                "Reject cross-ticket link ID reassignment",
                .linkGoal(id: "goal-link-approved", ticketID: "RR-04", goalID: "goal-unused"),
                { if case .invalidReference = $0 { return true }; return false }
            ),
        ]

        for (requestID, reason, command, matches) in cases {
            let result = await fixture.dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(uuidString: requestID)!,
                projectRoot: fixture.projectRoot.path,
                reason: reason,
                command: command
            ))
            guard let error = result.error, matches(error) else {
                return XCTFail("Unexpected linkGoal validation result for \(reason): \(result)")
            }
            let state = try await fixture.store.read { connection in
                [
                    try connection.scalarInt("SELECT COUNT(*) FROM ticket_goal_links") ?? -1,
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                    try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
                ]
            }
            XCTAssertEqual(state, baseline)
        }

        let persisted = try await fixture.store.read { connection in
            try connection.scalarText("SELECT ticket_id || '|' || goal_id FROM ticket_goal_links WHERE id = 'goal-link-approved'")
        }
        XCTAssertEqual(persisted, "RR-03|goal-approved")
    }

    func testApprovedCommandsPersistOnlyTheirBoundedDeliveryRecords() async throws {
        let fixture = try await makeFixture()
        let evidenceURL = fixture.projectRoot.appendingPathComponent("evidence.txt")
        try Data("proof".utf8).write(to: evidenceURL)
        let commands: [AgentCommand] = [
            .upsertPhase(phaseID: "phase-2", name: "Launch"),
            .upsertTicket(ticketID: "RR-04", phaseID: "phase-2", outcome: "Onboard projects", lane: .backlog),
            .setDependency(id: "dependency-1", kind: .ticket, subjectID: "RR-04", dependsOnID: "RR-03"),
            .recordBlocker(id: "blocker-1", ticketID: "RR-04", summary: "Needs owner folder"),
            .resolveBlocker(blockerID: "blocker-1"),
            .addEvidence(id: "evidence-1", ticketID: "RR-04", path: evidenceURL.path),
            .linkThread(id: "link-1", ticketID: "RR-04", threadID: "verified-thread"),
            .requestReview(id: "review-1", ticketID: "RR-04", kind: "agent_request", summary: "Validate folder scope"),
            .recordCompletion(id: "completion-1", ticketID: "RR-04", summary: "Onboarding implemented"),
            .resolveImportReview(reviewItemID: "import-review-resolve"),
            .dismissImportReview(reviewItemID: "import-review-dismiss"),
        ]

        for (index, command) in commands.enumerated() {
            let result = await fixture.dispatcher.dispatch(.init(
                version: 1,
                requestID: UUID(uuidString: String(format: "22222222-2222-4222-8222-%012d", index + 1))!,
                projectRoot: fixture.projectRoot.path,
                reason: "Exercise approved command \(index + 1)",
                command: command
            ))
            XCTAssertNil(result.error, "Command \(index + 1) failed: \(String(describing: result.error))")
            XCTAssertNotNil(result.auditEventID)
        }

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT name FROM phases WHERE id = 'phase-2'"),
                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-04'"),
                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE id = 'dependency-1'"),
                try connection.scalarInt("SELECT COUNT(*) FROM blockers WHERE id = 'blocker-1' AND resolved_at IS NOT NULL"),
                try connection.scalarText("SELECT path FROM evidence WHERE id = 'evidence-1'"),
                try connection.scalarInt("SELECT COUNT(*) FROM thread_links WHERE id = 'link-1'"),
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'review-1' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM completion_records WHERE id = 'completion-1'"),
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'import-review-resolve'"),
                try connection.scalarText("SELECT status FROM review_items WHERE id = 'import-review-dismiss'")
            )
        }
        XCTAssertEqual(state.0, "Launch")
        XCTAssertEqual(state.1, "Onboard projects")
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, evidenceURL.path)
        XCTAssertEqual(state.5, 1)
        XCTAssertEqual(state.6, 1)
        XCTAssertEqual(state.7, 1)
        XCTAssertEqual(state.8, "resolved")
        XCTAssertEqual(state.9, "dismissed")
    }

    func testReviewCommandsCannotCreateOverwriteResolveOrDismissOnboardingMarkers() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed onboarding markers") { connection in
            try connection.execute(
                "INSERT INTO review_items (id, project_id, kind, summary, status) VALUES ('project-1-onboarding-pending', 'project-1', 'onboarding_pending', 'Pending', 'open')"
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, kind, summary, status) VALUES ('project-1-first-phase-request', 'project-1', 'onboarding_phase_request', 'Phase request', 'open')"
            )
        }

        let commands: [AgentCommand] = [
            .requestReview(id: "agent-reserved-create", ticketID: nil, kind: "onboarding_pending", summary: "Create reserved marker"),
            .requestReview(id: "agent-reserved-phase-create", ticketID: nil, kind: "onboarding_phase_request", summary: "Create reserved phase marker"),
            .requestReview(id: "project-1-onboarding-pending", ticketID: nil, kind: "agent_request", summary: "Overwrite reserved marker"),
            .resolveImportReview(reviewItemID: "project-1-onboarding-pending"),
            .dismissImportReview(reviewItemID: "project-1-first-phase-request"),
        ]

        for (index, command) in commands.enumerated() {
            let result = await fixture.dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(uuidString: String(format: "24242424-2424-4242-8242-%012d", index + 1))!,
                projectRoot: fixture.projectRoot.path,
                reason: "Reject onboarding marker mutation \(index + 1)",
                command: command
            ))
            guard case .invalidReference? = result.error else {
                return XCTFail("Expected invalidReference for command \(index + 1), got \(String(describing: result.error))")
            }
        }

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id IN ('agent-reserved-create', 'agent-reserved-phase-create')"),
                try connection.scalarText("SELECT kind || '|' || summary || '|' || status FROM review_items WHERE id = 'project-1-onboarding-pending'"),
                try connection.scalarText("SELECT kind || '|' || summary || '|' || status FROM review_items WHERE id = 'project-1-first-phase-request'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id LIKE '24242424-2424-4242-8242-%'")
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, "onboarding_pending|Pending|open")
        XCTAssertEqual(state.2, "onboarding_phase_request|Phase request|open")
        XCTAssertEqual(state.3, 0)
    }

    func testAgentCannotPreclaimAnotherProjectsOnboardingMarkerID() async throws {
        let fixture = try await makeFixture()
        let requestID = UUID(uuidString: "25252525-2525-4252-8252-252525252525")!

        let result = await fixture.dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject cross-project onboarding marker preclaim",
            command: .requestReview(
                id: "project-2-onboarding-pending",
                ticketID: nil,
                kind: "agent_request",
                summary: "Preclaim another project's marker"
            )
        ))

        guard case .invalidReference? = result.error else {
            return XCTFail("Expected invalidReference, got \(String(describing: result.error))")
        }
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'project-2-onboarding-pending'"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?", bindings: [.text(requestID.uuidString)]),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Reject cross-project onboarding marker preclaim'")
            )
        }
        XCTAssertEqual(state.0, 0)
        XCTAssertEqual(state.1, 0)
        XCTAssertEqual(state.2, 0)
    }

    func testFirstAgentPhaseBecomesActiveOnlyWhileItIsTheSolePhase() async throws {
        let fixture = try await makeFixture(seedDelivery: false)
        let first = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "23232323-2323-4232-8232-232323232321")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Define first phase",
            command: .upsertPhase(phaseID: "phase-first", name: "First")
        ))
        let second = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "23232323-2323-4232-8232-232323232322")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Define later phase",
            command: .upsertPhase(phaseID: "phase-later", name: "Later")
        ))

        XCTAssertNil(first.error)
        XCTAssertNil(second.error)
        let activePhaseID = try await fixture.store.read { connection in
            try connection.scalarText("SELECT phase_id FROM project_active_phases WHERE project_id = 'project-1'")
        }
        XCTAssertEqual(activePhaseID, "phase-first")
    }

    func testEmptyCommandIdentifierIsRejectedBeforeAnyWrite() async throws {
        let fixture = try await makeFixture()
        let before = try await counts(fixture.store)
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Must reject empty identifier",
            command: .upsertPhase(phaseID: "", name: "Invalid")
        ))

        guard case .invalidEnvelope? = result.error else {
            return XCTFail("Expected invalidEnvelope, got \(String(describing: result.error))")
        }
        let after = try await counts(fixture.store)
        XCTAssertEqual(after, before)
    }

    func testInvalidCrossProjectAndCycleCommandsReturnStructuredErrorsWithFullRollback() async throws {
        let fixture = try await makeFixture()
        let baseline = try await counts(fixture.store)

        let invalid = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "44444444-4444-4444-8444-444444444441")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject missing ticket",
            command: .transitionTicket(ticketID: "missing", lane: .blocked)
        ))
        guard case .invalidReference? = invalid.error else {
            return XCTFail("Expected invalidReference, got \(String(describing: invalid.error))")
        }
        var after = try await counts(fixture.store)
        XCTAssertEqual(after, baseline)

        let crossProject = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "44444444-4444-4444-8444-444444444442")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject another project's thread",
            command: .linkThread(id: "bad-link", ticketID: "RR-03", threadID: "other-thread")
        ))
        guard case .crossProjectReference? = crossProject.error else {
            return XCTFail("Expected crossProjectReference, got \(String(describing: crossProject.error))")
        }
        after = try await counts(fixture.store)
        XCTAssertEqual(after, baseline)

        for (id, command) in [
            ("44444444-4444-4444-8444-444444444443", AgentCommand.upsertTicket(ticketID: "RR-04", phaseID: "phase-1", outcome: "Onboard", lane: .backlog)),
            ("44444444-4444-4444-8444-444444444444", AgentCommand.setDependency(id: "dependency-1", kind: .ticket, subjectID: "RR-04", dependsOnID: "RR-03")),
        ] {
            let result = await fixture.dispatcher.dispatch(.init(
                version: 1,
                requestID: UUID(uuidString: id)!,
                projectRoot: fixture.projectRoot.path,
                reason: "Seed cycle boundary",
                command: command
            ))
            XCTAssertNil(result.error)
        }
        let beforeCycle = try await counts(fixture.store)
        let cycle = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "44444444-4444-4444-8444-444444444445")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject dependency cycle",
            command: .setDependency(id: "dependency-2", kind: .ticket, subjectID: "RR-03", dependsOnID: "RR-04")
        ))
        guard case .dependencyCycle? = cycle.error else {
            return XCTFail("Expected dependencyCycle, got \(String(describing: cycle.error))")
        }
        after = try await counts(fixture.store)
        XCTAssertEqual(after, beforeCycle)
        let dependencyCount = try await fixture.store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies")
        }
        XCTAssertEqual(dependencyCount, 1)
    }

    func testDifferingRequestIDReuseFailsWithoutChangingOriginalMutation() async throws {
        let fixture = try await makeFixture()
        let requestID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let accepted = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Accept ticket",
            command: .transitionTicket(ticketID: "RR-03", lane: .accepted)
        )
        let changedReuse = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Reuse ID for different command",
            command: .transitionTicket(ticketID: "RR-03", lane: .backlog)
        )

        let acceptedResult = await fixture.dispatcher.dispatch(accepted)
        XCTAssertNil(acceptedResult.error)
        let beforeReuse = try await counts(fixture.store)
        let rejected = await fixture.dispatcher.dispatch(changedReuse)

        XCTAssertEqual(rejected.error, .requestIDReused)
        let afterReuse = try await counts(fixture.store)
        XCTAssertEqual(afterReuse, beforeReuse)
        let lane = try await fixture.store.read { connection in
            try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'")
        }
        XCTAssertEqual(lane, TicketLane.accepted.rawValue)
    }

    func testVersionSizeRootAndEvidenceValidationRejectBeforeWriting() async throws {
        let fixture = try await makeFixture()
        let outsideFile = fixture.projectRoot.deletingLastPathComponent().appendingPathComponent("outside.txt")
        try Data("outside".utf8).write(to: outsideFile)
        let baseline = try await counts(fixture.store)
        let cases: [(AgentCommandEnvelope, (AgentCommandError) -> Bool)] = [
            (.init(version: 99, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "Wrong version", command: .transitionTicket(ticketID: "RR-03", lane: .blocked)), {
                if case .unsupportedVersion = $0 { return true }; return false
            }),
            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "x", command: .upsertTicket(ticketID: "large", phaseID: "phase-1", outcome: String(repeating: "x", count: 70_000), lane: .backlog)), {
                if case .invalidEnvelope = $0 { return true }; return false
            }),
            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, assertedThreadID: "", reason: "Empty asserted thread", command: .transitionTicket(ticketID: "RR-03", lane: .blocked)), {
                if case .invalidEnvelope = $0 { return true }; return false
            }),
            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "Invalid goal link", command: .linkGoal(id: " ", ticketID: "RR-03", goalID: "goal")), {
                if case .invalidEnvelope = $0 { return true }; return false
            }),
            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.deletingLastPathComponent().path, reason: "Outside root", command: .transitionTicket(ticketID: "RR-03", lane: .blocked)), {
                $0 == .unauthorizedProjectRoot
            }),
            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "Outside evidence", command: .addEvidence(id: "outside-evidence", ticketID: "RR-03", path: outsideFile.path)), {
                if case .crossProjectReference = $0 { return true }; return false
            }),
        ]

        for (envelope, matches) in cases {
            let result = await fixture.dispatcher.dispatch(envelope)
            guard let error = result.error, matches(error) else {
                return XCTFail("Unexpected validation result: \(result)")
            }
            let after = try await counts(fixture.store)
            XCTAssertEqual(after, baseline)
        }
    }

    func testUnavailableAppStoreReturnsAppUnavailableAndPreservesOriginalBytes() async throws {
        let fixture = try await makeFixture()
        let corruptURL = fixture.databaseURL.deletingLastPathComponent().appendingPathComponent("corrupt.sqlite")
        let bytes = Data("not sqlite".utf8)
        try bytes.write(to: corruptURL)
        let dispatcher = AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: corruptURL),
            projectRegistry: fixture.registry
        )

        let result = await dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(),
            projectRoot: fixture.projectRoot.path,
            reason: "Must not write without app store",
            command: .transitionTicket(ticketID: "RR-03", lane: .blocked)
        ))

        XCTAssertEqual(result.error, .appUnavailable)
        XCTAssertEqual(try Data(contentsOf: corruptURL), bytes)
    }

    func testAdmissionDeadlineExpiresWhileQueuedForStoreThenIdenticalReplayWritesOnce() async throws {
        let fixture = try await makeFixture()
        let baseline = try await counts(fixture.store)
        let gate = StoreQueueGate()
        let store = fixture.store
        let blocker = Task.detached {
            try await store.read { _ in
                gate.entered.signal()
                gate.release.wait()
            }
        }
        XCTAssertEqual(gate.entered.wait(timeout: .now() + 2), .success)

        let deadline = Date().addingTimeInterval(0.1).timeIntervalSince1970
        let dispatch = Task {
            await fixture.dispatcher.dispatch(
                .init(
                    version: 1,
                    requestID: UUID(uuidString: "77777777-7777-4777-8777-777777777777")!,
                    projectRoot: fixture.projectRoot.path,
                    reason: "Reject after store queue deadline",
                    command: .transitionTicket(ticketID: "RR-03", lane: .inProgress)
                ),
                admissionDeadline: deadline
            )
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            gate.release.signal()
        }

        let result = await dispatch.value
        try await blocker.value

        XCTAssertEqual(result.error, .appUnavailable)
        let after = try await counts(fixture.store)
        XCTAssertEqual(after, baseline)
        let lane = try await fixture.store.read { connection in
            try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'")
        }
        XCTAssertEqual(lane, TicketLane.backlog.rawValue)

        let replay = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "77777777-7777-4777-8777-777777777777")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject after store queue deadline",
            command: .transitionTicket(ticketID: "RR-03", lane: .inProgress)
        ))
        XCTAssertNil(replay.error)
        let replayState = try await fixture.store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Reject after store queue deadline'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '77777777-7777-4777-8777-777777777777'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE id = 'RR-03' AND lane = 'in_progress'") ?? -1,
            ]
        }
        XCTAssertEqual(replayState, [1, 1, 1])
    }

    private struct Fixture {
        let databaseURL: URL
        let projectRoot: URL
        let store: DeliveryStore
        let registry: InMemoryAuthorizedProjectRegistry
        let dispatcher: AgentCommandDispatcher
    }

    private struct ActivePhaseSnapshot: Equatable {
        let phases: [String]
        let tickets: [String]
        let phaseDependencies: [String]
        let ticketDependencies: [String]
        let activeRows: [String]
        let auditRows: [String]
        let requestRows: [String]
    }

    private func makeActivePhaseFixture() async throws -> Fixture {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed active-phase history") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'project-1', 'Current')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('RR-ROADMAP', 'project-1', 'Roadmap')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-historical', 'project-1', 'Historical')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-1', 'project-1', 'phase-current', 'Current delivery', 'in_progress')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROADMAP-1', 'project-1', 'RR-ROADMAP', 'Roadmap delivery', 'backlog')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('HISTORY-1', 'project-1', 'phase-historical', 'Historical delivery', 'accepted')")
            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-history', 'project-1', 'RR-ROADMAP', 'phase-current')")
            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('ticket-dependency-history', 'project-1', 'ROADMAP-1', 'CURRENT-1')")
            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-current')")
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('other-project-phase', 'project-2', 'Other project')")
        }
        return fixture
    }

    private func makeFixture(seedDelivery: Bool = true) async throws -> Fixture {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AgentBridgeTests-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = temporaryDirectory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let databaseURL = temporaryDirectory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed bridge fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)", bindings: [.text(projectRoot.path)])
            if seedDelivery {
                try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
                try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Typed bridge', 'backlog')")
            }
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('verified-thread', 'project-1', 'running', '2026-08-23T12:00:00Z')")
            try connection.execute("INSERT INTO review_items (id, project_id, kind, summary) VALUES ('import-review-resolve', 'project-1', 'import', 'Resolve me')")
            try connection.execute("INSERT INTO review_items (id, project_id, kind, summary) VALUES ('import-review-dismiss', 'project-1', 'import', 'Dismiss me')")
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-2', 'Other')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('other-thread', 'project-2', 'running', '2026-08-23T12:00:00Z')")
        }
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: .init(rawValue: "project-1"), canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
        ])
        let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: registry)
        return Fixture(databaseURL: databaseURL, projectRoot: projectRoot, store: store, registry: registry, dispatcher: dispatcher)
    }

    private func counts(_ store: DeliveryStore) async throws -> [Int64] {
        try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM phases") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM tickets") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
            ]
        }
    }

    private static func activePhaseSnapshot(_ store: DeliveryStore) async throws -> ActivePhaseSnapshot {
        try await store.read { connection in
            ActivePhaseSnapshot(
                phases: try Self.textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || name AS value FROM phases ORDER BY project_id, id"
                ),
                tickets: try Self.textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || outcome || '|' || lane AS value FROM tickets ORDER BY project_id, id"
                ),
                phaseDependencies: try Self.textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || depends_on_phase_id AS value FROM phase_dependencies ORDER BY project_id, id"
                ),
                ticketDependencies: try Self.textRows(
                    connection,
                    sql: "SELECT id || '|' || project_id || '|' || ticket_id || '|' || depends_on_ticket_id AS value FROM ticket_dependencies ORDER BY project_id, id"
                ),
                activeRows: try Self.textRows(
                    connection,
                    sql: "SELECT project_id || '|' || phase_id AS value FROM project_active_phases ORDER BY project_id"
                ),
                auditRows: try Self.textRows(
                    connection,
                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') || '|' || created_at AS value FROM audit_events ORDER BY id"
                ),
                requestRows: try Self.textRows(
                    connection,
                    sql: "SELECT request_id || '|' || hex(request_body) || '|' || hex(result_data) || '|' || created_at AS value FROM agent_command_requests ORDER BY request_id"
                )
            )
        }
    }

    private static func textRows(_ connection: SQLiteConnection, sql: String) throws -> [String] {
        var values: [String] = []
        var offset: Int64 = 0
        while let row = try connection.row("\(sql) LIMIT 1 OFFSET ?", bindings: [.integer(offset)]) {
            guard case let .text(value)? = row["value"] else {
                throw ActivePhaseTestError.missingTextValue
            }
            values.append(value)
            offset += 1
        }
        return values
    }

}

private enum ActivePhaseTestError: Error {
    case missingTextValue
}
