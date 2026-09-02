import Foundation
import Security
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class NotificationAcceptanceTests: XCTestCase {
    func testTask11ADeliveryGoalAndTaskCommandsPreserveRealCodexBlockedNotificationsAcrossReplay() async throws {
        let f = try await makeFixture(firstDashboardOpened: true)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed linked execution context") { c in
            try c.execute("INSERT INTO observed_threads (id,project_id,status,last_observed_at) VALUES ('thread','project-1','active','2026-09-02T12:00:00Z')")
            try c.execute("INSERT INTO thread_links (id,project_id,ticket_id,thread_id) VALUES ('thread-link','project-1','RR-09','thread')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: f.store)
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread", goalID: "codex-goal", status: .active, observedAt: Date(timeIntervalSince1970: 1))
        let linked = await f.dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path,
                                                     reason: "Approve exact execution goal", command: .linkGoal(id: "goal-link", ticketID: "RR-09", goalID: "codex-goal")))
        XCTAssertNil(linked.error)
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread", goalID: "codex-goal", status: .blocked, observedAt: Date(timeIntervalSince1970: 2))
        func context(_ store: DeliveryStore) async throws -> [String: [[String: SQLiteValue]]] {
            try await store.read { c in
                var rows: [String: [[String: SQLiteValue]]] = [:]
                for table in ["notification_events", "notification_occurrences", "alert_rules", "observed_goals", "ticket_goal_links"] {
                    rows[table] = try c.rows("SELECT * FROM \(table) ORDER BY rowid")
                }
                return rows
            }
        }
        let before = try await context(f.store)
        XCTAssertEqual(before["notification_events"]?.count, 1, "The real linked Codex blocked event must still be emitted")
        XCTAssertEqual(before["notification_events"]?.first?["event_kind"], .text("goal_blocked"))
        let commands: [AgentCommand] = [
            .applyPhasePlanRevision(projectID: "project-1", phaseID: "phase-1", expectedRevision: 0,
                                    goalUpserts: [.init(id: .init(rawValue: "fixture-goal"), title: "Updated delivery goal",
                                                       outcome: "Deliver the scoped outcome", doneCriteria: ["Scoped ticket accepted"], sortOrder: 0)]),
            .finalizePhasePlan(projectID: "project-1", phaseID: "phase-1", expectedRevision: 1),
            .reviseTicketTaskPlan(ticketID: "RR-09", additions: [.init(id: .init(rawValue: "one"), label: "One", title: "Verify delivery", sortOrder: 0)]),
            .completeTicketTask(ticketID: "RR-09", taskID: "one", expectedRevision: 1),
        ]
        var requests: [(AgentCommandEnvelope, AgentCommandResult)] = []
        for command in commands {
            let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path,
                                               reason: "Delivery planning is not a Codex event", command: command)
            let result = await f.dispatcher.dispatch(request)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.auditEventID)
            requests.append((request, result))
            let after = try await context(f.store)
            XCTAssertEqual(after, before)
        }
        // Progress/acceptance is a separate formal action. Its legitimate review
        // occurrence changes are not attributed to task or Delivery Goal edits.
        try await transition(.needsReview, requestID: UUID().uuidString, fixture: f)
        try await transition(.accepted, requestID: UUID().uuidString, ticketTaskPlanRevision: 2, fixture: f)
        let evidence = f.projectRoot.appendingPathComponent("proof.txt")
        try Data("Synthetic acceptance evidence".utf8).write(to: evidence)
        let added = await f.dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path,
                                                     reason: "Attach acceptance evidence", command: .addEvidence(id: "proof", ticketID: "RR-09", path: evidence.path)))
        XCTAssertNil(added.error)
        let beforeGoal = try await context(f.store)
        let awaiting = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path,
                                             reason: "Request Delivery Goal acceptance", command: .transitionDeliveryGoal(projectID: "project-1", phaseID: "phase-1", goalID: "fixture-goal", expectedPlanRevision: 1, lifecycle: .awaitingAcceptance))
        let result = await f.dispatcher.dispatch(awaiting)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.auditEventID)
        requests.append((awaiting, result))
        let afterGoal = try await context(f.store)
        XCTAssertEqual(afterGoal, beforeGoal, "Delivery Goal attention must not impersonate a Codex notification")
        let relaunched = DeliveryStore(databaseURL: f.databaseURL)
        let dispatcher = AgentCommandDispatcher(store: relaunched, projectRegistry: f.registry)
        let countsBeforeReplay = try await relaunched.read { c in
            try ["audit_events", "agent_command_requests"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") }
        }
        for (request, original) in requests {
            let replay = await dispatcher.dispatch(request)
            XCTAssertEqual(replay, original)
        }
        let replayed = try await context(relaunched)
        XCTAssertEqual(replayed, beforeGoal)
        let countsAfterReplay = try await relaunched.read { c in
            try ["audit_events", "agent_command_requests"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") }
        }
        XCTAssertEqual(countsAfterReplay, countsBeforeReplay)
    }

    func testTaskOnlyCommandsLeaveAttentionNotificationsAndDeliveryContextUnchanged() async throws {
        let f = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: UUID().uuidString, fixture: f)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed unrelated delivery context") { c in
            try c.execute("INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES ('proof', 'project-1', 'RR-09', '/fixture/proof', 1)")
            try c.execute("INSERT INTO review_items (id, project_id, ticket_id, kind, summary) VALUES ('review', 'project-1', 'RR-09', 'agent_request', 'Review delivery')")
            try c.execute("UPDATE phase_plans SET state = 'draft', revision = 1, ready_revision = NULL, finalized_at = NULL WHERE project_id = 'project-1' AND phase_id = 'phase-1'")
            try c.execute("INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at) VALUES ('project-1', 'phase-1', 'goal', 'Goal', 'Deliver', 'planned', 0, '2026-09-02T00:00:00Z', '2026-09-02T00:00:00Z')")
        }
        let before = try await task4ANotificationSnapshot(f.store)
        let context = try await task4BDeliveryContext(f.store)
        let commands: [AgentCommand] = [
            .reviseTicketTaskPlan(ticketID: "RR-09", additions: [.init(id: .init(rawValue: "one"), label: "One", title: "Implement command", sortOrder: 0)]),
            .reviseTicketTaskPlan(ticketID: "RR-09", expectedRevision: 1, additions: [.init(id: .init(rawValue: "two"), label: "Two", title: "Complete replacement", sortOrder: 0)], supersededTaskIDs: [.init(rawValue: "one")]),
            .reviseTicketTaskPlan(ticketID: "RR-09", expectedRevision: 2, definitionRevisions: [.init(id: .init(rawValue: "two"), title: "Verify replacement", sortOrder: nil)]),
            .completeTicketTask(ticketID: "RR-09", taskID: "two", expectedRevision: 3),
        ]
        for (index, command) in commands.enumerated() {
            let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path, reason: "Change task only", command: command)
            let result = await f.dispatcher.dispatch(request)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.ticketTaskPlanRevision, Int64(index + 1))
            let replay = await f.dispatcher.dispatch(request)
            XCTAssertEqual(replay, result)
            let after = try await task4ANotificationSnapshot(f.store)
            XCTAssertEqual(after.lane, before.lane)
            XCTAssertEqual(after.isOccurrenceActive, before.isOccurrenceActive)
            XCTAssertEqual(after.occurrenceGeneration, before.occurrenceGeneration)
            XCTAssertEqual(after.notificationCount, before.notificationCount)
            let currentContext = try await task4BDeliveryContext(f.store)
            XCTAssertEqual(currentContext, context)
        }
        let complete = try await task4ANotificationSnapshot(f.store)
        let rejection = await f.dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path, reason: "Reject repeated completion", command: .completeTicketTask(ticketID: "RR-09", taskID: "two", expectedRevision: 4)))
        XCTAssertNotNil(rejection.error)
        let unchanged = try await task4ANotificationSnapshot(f.store)
        XCTAssertEqual(unchanged, complete)
    }

    private func task4BDeliveryContext(_ store: DeliveryStore) async throws -> [String] {
        try await store.read { c in
            [try c.scalarText("SELECT state || '|' || revision || '|' || COALESCE(ready_revision, -1) FROM phase_plans WHERE phase_id = 'phase-1'") ?? "missing",
             try c.scalarText("SELECT title || '|' || outcome || '|' || lifecycle FROM delivery_goals WHERE id = 'goal'") ?? "missing",
             try c.scalarText("SELECT path || '|' || ticket_id || '|' || is_available FROM evidence WHERE id = 'proof'") ?? "missing",
             try c.scalarText("SELECT kind || '|' || summary || '|' || status FROM review_items WHERE id = 'review'") ?? "missing"]
        }
    }

    func testAcceptedUpsertCreatesNoAttentionNotificationAuditOrReceiptEffects() async throws {
        for ticketID in ["RR-NEW", "RR-09"] {
            let fixture = try await makeFixture(firstDashboardOpened: true)
            let before = try await fixture.store.read { connection in
                (
                    try connection.scalarInt("SELECT COUNT(*) FROM tickets"),
                    try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-09'"),
                    try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
                    try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                    try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
                )
            }
            let result = await fixture.dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(),
                projectRoot: fixture.projectRoot.path,
                reason: "Reject Accepted upsert without effects",
                command: .upsertTicket(
                    ticketID: ticketID,
                    phaseID: "phase-1",
                    outcome: "Must remain unchanged",
                    lane: .accepted
                )
            ))
            guard case .invalidEnvelope? = result.error else {
                XCTFail("Expected invalidEnvelope, got \(String(describing: result.error))")
                continue
            }
            let after = try await fixture.store.read { connection in
                (
                    try connection.scalarInt("SELECT COUNT(*) FROM tickets"),
                    try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-09'"),
                    try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
                    try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                    try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                    try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
                )
            }
            XCTAssertEqual(after.0, before.0)
            XCTAssertEqual(after.1, before.1)
            XCTAssertEqual(after.2, before.2)
            XCTAssertEqual(after.3, before.3)
            XCTAssertEqual(after.4, before.4)
            XCTAssertEqual(after.5, before.5)
        }
    }

    func testGuardedAcceptancePreservesOccurrenceOnRejectionAndDeactivatesOnceOnSuccess() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(
            .needsReview,
            requestID: "90909090-9090-4090-8090-909090909071",
            fixture: fixture
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed completed notification task plan") { connection in
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: .init(rawValue: "project-1"),
                ticketID: .init(rawValue: "RR-09"),
                expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "notification-task"), label: "Notify", title: "Complete guarded acceptance", sortOrder: 0)],
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
            _ = try TicketTaskPlanningPolicy.completeTask(
                projectID: .init(rawValue: "project-1"),
                ticketID: .init(rawValue: "RR-09"),
                taskID: .init(rawValue: "notification-task"),
                expectedRevision: 1,
                connection: connection
            )
        }
        let beforeRejected = try await task4ANotificationSnapshot(fixture.store)

        let rejected = await fixture.dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909072")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Reject stale guarded acceptance",
            command: .transitionTicket(
                ticketID: "RR-09",
                lane: .accepted,
                ticketTaskPlanRevision: 1
            )
        ))

        XCTAssertNotNil(rejected.error)
        let afterRejected = try await task4ANotificationSnapshot(fixture.store)
        XCTAssertEqual(afterRejected, beforeRejected)

        let requestID = "90909090-9090-4090-8090-909090909073"
        try await transition(
            .accepted,
            requestID: requestID,
            ticketTaskPlanRevision: 2,
            fixture: fixture
        )
        let afterAccepted = try await task4ANotificationSnapshot(fixture.store)
        XCTAssertEqual(afterAccepted.lane, TicketLane.accepted.rawValue)
        XCTAssertEqual(afterAccepted.planRevision, beforeRejected.planRevision)
        XCTAssertEqual(afterAccepted.taskRows, beforeRejected.taskRows)
        XCTAssertEqual(afterAccepted.isOccurrenceActive, 0)
        XCTAssertEqual(afterAccepted.occurrenceGeneration, beforeRejected.occurrenceGeneration)
        XCTAssertEqual(afterAccepted.notificationCount, beforeRejected.notificationCount)
        XCTAssertEqual(afterAccepted.auditCount, beforeRejected.auditCount + 1)
        XCTAssertEqual(afterAccepted.requestCount, beforeRejected.requestCount + 1)

        try await transition(
            .accepted,
            requestID: requestID,
            ticketTaskPlanRevision: 2,
            fixture: fixture
        )
        let afterReplay = try await task4ANotificationSnapshot(fixture.store)
        XCTAssertEqual(afterReplay, afterAccepted)
    }

    func testAgentReviewOccurrenceIsAtomicAndReplayDoesNotDuplicateIt() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let requestID = UUID(uuidString: "90909090-9090-4090-8090-909090909001")!
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            assertedThreadID: "agent-thread",
            reason: "Request owner review",
            command: .requestReview(
                id: "review-1",
                ticketID: "RR-09",
                kind: "agent_request",
                summary: "raw reason that must not become notification text"
            )
        )

        let first = await fixture.dispatcher.dispatch(envelope)
        let replay = await AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectRegistry: fixture.registry
        ).dispatch(envelope)

        XCTAssertNil(first.error)
        XCTAssertEqual(replay, first)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'review-1' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Request owner review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'review_requested' AND state = 'queued'"),
                try connection.scalarInt("SELECT COUNT(DISTINCT fingerprint) FROM notification_events"),
                try connection.scalarText("SELECT title FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT message FROM notification_events LIMIT 1")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, "RR-09 needs review")
        XCTAssertEqual(state.5, "An agent requested owner review in Release Radar.")
    }

    func testTicketNeedsReviewCreatesNewOccurrenceOnlyAfterLeavingAndReentering() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)

        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909011", fixture: fixture)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909012", fixture: fixture)
        try await transition(.inProgress, requestID: "90909090-9090-4090-8090-909090909013", fixture: fixture)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909014", fixture: fixture)

        let rows = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'ticket_needs_review'"),
                try connection.scalarInt("SELECT COUNT(DISTINCT fingerprint) FROM notification_events WHERE event_kind = 'ticket_needs_review'"),
                try connection.scalarInt("SELECT MAX(occurrence) FROM notification_events WHERE event_kind = 'ticket_needs_review'")
            )
        }
        XCTAssertEqual(rows.0, 2)
        XCTAssertEqual(rows.1, 2)
        XCTAssertEqual(rows.2, 2)
    }

    func testAgentCompletionCreatesOneSanitizedOccurrenceWhileUnrelatedUpdatesDoNot() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let completion = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909015")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Secret completion reason",
            command: .recordCompletion(id: "completion-1", ticketID: "RR-09", summary: "Raw evidence path and completion body")
        ))
        let unrelated = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909016")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Rename phase",
            command: .upsertPhase(phaseID: "phase-1", name: "MVP renamed")
        ))
        XCTAssertNil(completion.error)
        XCTAssertNil(unrelated.error)

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                try connection.scalarText("SELECT event_kind FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT title FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT message FROM notification_events LIMIT 1")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, MeaningfulDeliveryEventKind.agentCompleted.rawValue)
        XCTAssertEqual(state.2, "RR-09 completed")
        XCTAssertEqual(state.3, "An agent recorded completed delivery work in Release Radar.")
    }

    func testLinkedGoalBlockedAndPausedOccurrencesAreReciprocalAcrossSuppressedTransitions() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed linked runtime") { connection in
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-1', 'project-1', 'active', '2026-08-24T10:00:00Z')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('link-1', 'project-1', 'RR-09', 'thread-1')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: fixture.store)

        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .active, observedAt: Date(timeIntervalSince1970: 1))
        let linkResult = await fixture.dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909017")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Approve linked goal",
            command: .linkGoal(id: "goal-link-1", ticketID: "RR-09", goalID: "goal-1")
        ))
        XCTAssertNil(linkResult.error)
        let rules = AlertRuleStore(store: fixture.store)
        _ = try await rules.set(.blockedLinkedGoals, enabled: false)
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 2))
        _ = try await rules.set(.blockedLinkedGoals, enabled: true)
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 2.5))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .active, observedAt: Date(timeIntervalSince1970: 3))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 4))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .paused, observedAt: Date(timeIntervalSince1970: 5))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 6))
        _ = try await rules.set(.pausedGoals, enabled: true)
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .paused, observedAt: Date(timeIntervalSince1970: 7))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 8))

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT status FROM observed_goals WHERE id = 'goal-1'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'goal_blocked'"),
                try connection.scalarInt("SELECT MAX(occurrence) FROM notification_events WHERE event_kind = 'goal_blocked'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'goal_paused'"),
                try connection.scalarInt("SELECT is_active FROM notification_occurrences WHERE event_kind = 'goal_blocked'"),
                try connection.scalarInt("SELECT is_active FROM notification_occurrences WHERE event_kind = 'goal_paused'")
            )
        }
        XCTAssertEqual(state.0, "blocked")
        XCTAssertEqual(state.1, 3)
        XCTAssertEqual(state.2, 3)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, 1)
        XCTAssertEqual(state.5, 0)
    }

    func testDisabledEntriesDoNotAlertAfterReenableUntilStableBridgeRecordsEnterAgain() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let rules = AlertRuleStore(store: fixture.store)
        _ = try await rules.set(.agentCompletionAndReview, enabled: false)
        _ = try await rules.set(.needsReviewEntry, enabled: false)

        let review = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909061")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Suppressed review still commits",
            command: .requestReview(id: "suppressed-review", ticketID: "RR-09", kind: "agent_request", summary: "Review")
        ))
        let completion = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909062")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Suppressed completion still commits",
            command: .recordCompletion(id: "suppressed-completion", ticketID: "RR-09", summary: "Done")
        ))
        XCTAssertNil(review.error)
        XCTAssertNil(completion.error)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909063", fixture: fixture)

        let suppressed = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'suppressed-review' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM completion_records WHERE id = 'suppressed-completion'"),
                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-09'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Suppressed % still commits' OR reason LIKE 'Transition RR-09 %'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
            )
        }
        XCTAssertEqual(suppressed.0, 1)
        XCTAssertEqual(suppressed.1, 1)
        XCTAssertEqual(suppressed.2, TicketLane.needsReview.rawValue)
        XCTAssertEqual(suppressed.3, 3)
        XCTAssertEqual(suppressed.4, 0)
        XCTAssertEqual(suppressed.5, 0)
        let activity = try await ProjectActivityProjection.load(from: fixture.store, projectID: .init(rawValue: "project-1"))
        XCTAssertFalse(activity.items.contains { $0.source == .notification })

        _ = try await rules.set(.agentCompletionAndReview, enabled: true)
        _ = try await rules.set(.needsReviewEntry, enabled: true)
        let stableReview = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909064")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Observe the same open review",
            command: .requestReview(id: "suppressed-review", ticketID: "RR-09", kind: "agent_request", summary: "Review again")
        ))
        let stableCompletion = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909065")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Observe the same completion",
            command: .recordCompletion(id: "suppressed-completion", ticketID: "RR-09", summary: "Still done")
        ))
        XCTAssertNil(stableReview.error)
        XCTAssertNil(stableCompletion.error)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909066", fixture: fixture)
        let retroactiveCount = try await fixture.store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
        }
        XCTAssertEqual(retroactiveCount, 0)

        let resolved = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909067")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Resolve review before a later request",
            command: .resolveImportReview(reviewItemID: "suppressed-review")
        ))
        let reenteredReview = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909068")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Request review after resolution",
            command: .requestReview(id: "suppressed-review", ticketID: "RR-09", kind: "agent_request", summary: "Review after resolution")
        ))
        let laterCompletion = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909069")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Record a later completion",
            command: .recordCompletion(id: "later-completion", ticketID: "RR-09", summary: "Later work done")
        ))
        XCTAssertNil(resolved.error)
        XCTAssertNil(reenteredReview.error)
        XCTAssertNil(laterCompletion.error)
        try await transition(.inProgress, requestID: "90909090-9090-4090-8090-909090909070", fixture: fixture)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909071", fixture: fixture)

        let laterEntries = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'review_requested'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'agent_completed'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'ticket_needs_review'")
            )
        }
        XCTAssertEqual(laterEntries.0, 1)
        XCTAssertEqual(laterEntries.1, 1)
        XCTAssertEqual(laterEntries.2, 1)

        XCTAssertEqual(MeaningfulDeliveryEventKind.goalBlocked.alertRuleKind, .blockedLinkedGoals)
        XCTAssertEqual(MeaningfulDeliveryEventKind.goalPaused.alertRuleKind, .pausedGoals)
        XCTAssertEqual(MeaningfulDeliveryEventKind.agentCompleted.alertRuleKind, .agentCompletionAndReview)
        XCTAssertEqual(MeaningfulDeliveryEventKind.reviewRequested.alertRuleKind, .agentCompletionAndReview)
        XCTAssertEqual(MeaningfulDeliveryEventKind.ticketNeedsReview.alertRuleKind, .needsReviewEntry)
        XCTAssertEqual(MeaningfulDeliveryEventKind.importNeedsReview.alertRuleKind, .needsReviewEntry)
    }

    func testNewerGoalOnLinkedThreadCannotStealApprovedGoalBlockedAlert() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed linked runtime") { connection in
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-identity', 'project-1', 'active', '2026-08-25T10:00:00Z')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('thread-link-identity', 'project-1', 'RR-09', 'thread-identity')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: fixture.store)
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-identity", goalID: "goal-approved", status: .active, observedAt: Date(timeIntervalSince1970: 1))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-identity", goalID: "goal-newer", status: .active, observedAt: Date(timeIntervalSince1970: 2))
        let linkResult = await fixture.dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909018")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Approve older goal identity",
            command: .linkGoal(id: "goal-link-approved", ticketID: "RR-09", goalID: "goal-approved")
        ))
        XCTAssertNil(linkResult.error)

        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-identity", goalID: "goal-approved", status: .blocked, observedAt: Date(timeIntervalSince1970: 3))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-identity", goalID: "goal-newer", status: .blocked, observedAt: Date(timeIntervalSince1970: 4))

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'goal_blocked'"),
                try connection.scalarText("SELECT ticket_id FROM notification_events WHERE event_kind = 'goal_blocked'"),
                try connection.scalarText("SELECT goal_id FROM notification_events WHERE event_kind = 'goal_blocked'"),
                try connection.scalarText("SELECT subject_id FROM notification_events WHERE event_kind = 'goal_blocked'")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, "RR-09")
        XCTAssertEqual(state.2, "goal-approved")
        XCTAssertEqual(state.3, "goal-approved")
    }

    func testPreFirstDashboardOpenSuppressesOnboardingAndImportStyleReviewAlerts() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: false)
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909021")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Create onboarding review",
            command: .requestReview(id: "onboarding-review", ticketID: nil, kind: "unmatched_import", summary: "Uncertain mapping")
        ))
        XCTAssertNil(result.error)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909022", fixture: fixture)

        let count = try await fixture.store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
        }
        XCTAssertEqual(count, 0)
    }

    func testAttemptIsDurableBeforeTransportAndFailureIsVisibleWithoutRawBodies() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909031", fixture: fixture)
        let transport = InspectingFailingTransport(store: fixture.store)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await dispatcher.dispatchPending()

        let observedState = await transport.observedState
        XCTAssertEqual(observedState, .attemptStarted)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events LIMIT 1"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT failure_code FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'notification_events'")
            )
        }
        XCTAssertEqual(state.0, NotificationDeliveryState.failed.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, "transport_unavailable")
        XCTAssertFalse(try XCTUnwrap(state.3).contains("request_body"))
        XCTAssertFalse(try XCTUnwrap(state.3).contains("response_body"))
    }

    func testRelaunchMarksAmbiguousAttemptUnknownAndNeverRetriesIt() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909041", fixture: fixture)
        try await fixture.store.transact(actor: .init(id: "notification-dispatcher"), reason: "Start notification attempt") { connection in
            try connection.execute("UPDATE notification_events SET state = 'attempt_started', attempt_count = 1, attempt_started_at = '2026-08-24T10:00:00Z'")
        }
        let transport = CountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await dispatcher.prepareForLaunch()
        await dispatcher.dispatchPending()
        await dispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 0)
        let state = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(state, NotificationDeliveryState.unknown.rawValue)
    }

    func testOrdinaryDispatchDoesNotRecoverPreexistingAttemptAsIfItWereRelaunch() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909044", fixture: fixture)
        try await fixture.store.transact(actor: .init(id: "notification-dispatcher"), reason: "Start notification attempt") { connection in
            try connection.execute("UPDATE notification_events SET state = 'attempt_started', attempt_count = 1, attempt_started_at = '2026-08-24T10:00:00Z'")
        }
        let transport = CountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await dispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 0)
        let state = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(state, NotificationDeliveryState.attemptStarted.rawValue)
    }

    func testConcurrentDispatchDoesNotReclassifyLiveAttemptAndSendsOnce() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909042", fixture: fixture)
        let transport = BlockingCountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        let first = Task { await dispatcher.dispatchPending() }
        await transport.waitUntilEntered()
        let second = Task { await dispatcher.dispatchPending() }
        await second.value
        let stateWhileBlocked = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(stateWhileBlocked, NotificationDeliveryState.attemptStarted.rawValue)
        await transport.release()
        await first.value

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 1)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events LIMIT 1"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events LIMIT 1")
            )
        }
        XCTAssertEqual(state.0, NotificationDeliveryState.sent.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testLaunchRecoverySerializesWithDispatchThatStartsDuringRecovery() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed recovery overlap") { connection in
            let interrupted = try XCTUnwrap(MeaningfulDeliveryEvent.enqueue(
                projectID: .init(rawValue: "project-1"), kind: .reviewRequested,
                subjectID: "interrupted-review", ticketID: .init(rawValue: "RR-09"), goalID: nil,
                connection: connection
            ))
            _ = try XCTUnwrap(MeaningfulDeliveryEvent.enqueue(
                projectID: .init(rawValue: "project-1"), kind: .reviewRequested,
                subjectID: "new-review", ticketID: .init(rawValue: "RR-09"), goalID: nil,
                connection: connection
            ))
            try connection.execute(
                "UPDATE notification_events SET state = 'attempt_started', attempt_count = 1 WHERE id = ?",
                bindings: [.text(interrupted.id.rawValue)]
            )
        }
        let recoveryGate = AsyncTestGate()
        let firstOutcome = FirstDispatchOutcomeGate()
        let transport = SignalingBlockingTransport(firstOutcome: firstOutcome)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport,
            beforeLaunchRecovery: { await recoveryGate.enterAndWait() }
        )

        let preparation = Task { await dispatcher.prepareForLaunch() }
        await recoveryGate.waitUntilEntered()
        let ordinaryDispatch = Task {
            await dispatcher.dispatchPending()
            await firstOutcome.signal(.dispatchReturned)
        }
        let overlapOutcome = await firstOutcome.wait()
        await recoveryGate.release()

        if overlapOutcome == .dispatchReturned {
            await transport.waitUntilEntered()
        } else {
            await preparation.value
        }
        let overlappingStates = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events WHERE subject_id = 'interrupted-review'"),
                try connection.scalarText("SELECT state FROM notification_events WHERE subject_id = 'new-review'")
            )
        }
        XCTAssertEqual(overlappingStates.0, NotificationDeliveryState.unknown.rawValue)
        XCTAssertEqual(overlappingStates.1, NotificationDeliveryState.attemptStarted.rawValue)

        await transport.release()
        await preparation.value
        await ordinaryDispatch.value
        let finalNewState = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events WHERE subject_id = 'new-review'"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events WHERE subject_id = 'new-review'")
            )
        }
        XCTAssertEqual(finalNewState.0, NotificationDeliveryState.sent.rawValue)
        XCTAssertEqual(finalNewState.1, 1)
    }

    func testDispatchRequestDuringBlockedSendDrainsNewlyQueuedEventWithoutAnotherTrigger() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909045", fixture: fixture)
        let transport = BlockingCountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        let firstDispatch = Task { await dispatcher.dispatchPending() }
        await transport.waitUntilEntered()
        let secondResult = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909046")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Queue a distinct review while delivery is blocked",
            command: .requestReview(
                id: "review-queued-during-send", ticketID: "RR-09",
                kind: "agent_request", summary: "Review"
            )
        ))
        XCTAssertNil(secondResult.error)
        await dispatcher.dispatchPending()
        await transport.release()
        await firstDispatch.value

        let sendCount = await transport.sendCount
        let states = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE state = 'sent' AND attempt_count = 1"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE state = 'queued'")
            )
        }
        XCTAssertEqual(sendCount, 2)
        XCTAssertEqual(states.0, 2)
        XCTAssertEqual(states.1, 0)
    }

    func testSuccessfulSendRemainsExactlyOneAcrossReplayAndRelaunch() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let requestID = UUID(uuidString: "90909090-9090-4090-8090-909090909043")!
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Request owner review once",
            command: .requestReview(id: "review-send-once", ticketID: "RR-09", kind: "agent_request", summary: "Review")
        )
        let firstResult = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(firstResult.error)
        let transport = CountingTransport()
        let firstDispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await firstDispatcher.dispatchPending()
        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let replay = await AgentCommandDispatcher(store: relaunchedStore, projectRegistry: fixture.registry).dispatch(envelope)
        XCTAssertNil(replay.error)
        let relaunchedDispatcher = PushoverNotificationDispatcher(
            store: relaunchedStore,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )
        await relaunchedDispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 1)
        let state = try await relaunchedStore.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE fingerprint LIKE '%review-send-once%'"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events WHERE subject_id = 'review-send-once'"),
                try connection.scalarText("SELECT state FROM notification_events WHERE subject_id = 'review-send-once'")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, NotificationDeliveryState.sent.rawValue)
    }

    func testProjectScopedOccurrenceAllowsTheSameLogicalSubjectInTwoProjects() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NotificationProjectScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))

        let events = try await store.transact(actor: .init(id: "fixture"), reason: "Seed project-scoped notification occurrences") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'One', 1)")
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-2', 'Two', 1)")
            let first = try MeaningfulDeliveryEvent.enqueue(
                projectID: .init(rawValue: "project-1"), kind: .importNeedsReview,
                subjectID: "shared-review", ticketID: nil, goalID: nil, connection: connection
            )
            let second = try MeaningfulDeliveryEvent.enqueue(
                projectID: .init(rawValue: "project-2"), kind: .importNeedsReview,
                subjectID: "shared-review", ticketID: nil, goalID: nil, connection: connection
            )
            return [first, second]
        }

        XCTAssertNotNil(events[0])
        XCTAssertNotNil(events[1])
        XCTAssertNotEqual(events[0]?.fingerprint, events[1]?.fingerprint)
        let projectCounts = try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-1'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-2'") ?? -1,
            ]
        }
        XCTAssertEqual(projectCounts, [1, 1])
    }

    func testGoalObservationRejectsExistingGoalOwnedByAnotherProject() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GoalProjectScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed project-scoped goals") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'One', 1)")
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-2', 'Two', 1)")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-1', 'project-1', 'active', '2026-08-24T10:00:00Z')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-2', 'project-2', 'active', '2026-08-24T10:00:00Z')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: store)
        try await recorder.recordGoalObservation(
            projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "shared-goal",
            status: .active, observedAt: Date(timeIntervalSince1970: 1)
        )

        do {
            try await recorder.recordGoalObservation(
                projectID: .init(rawValue: "project-2"), threadID: "thread-2", goalID: "shared-goal",
                status: .blocked, observedAt: Date(timeIntervalSince1970: 2)
            )
            XCTFail("Expected cross-project goal ownership to be rejected")
        } catch {
            // The persisted project must remain the original owner regardless of the concrete error surface.
        }

        let projectID = try await store.read { connection in
            try connection.scalarText("SELECT project_id FROM observed_goals WHERE id = 'shared-goal'")
        }
        XCTAssertEqual(projectID, "project-1")
    }

    func testKeychainItemsAreDeviceOnlyNonSynchronizingAndAppScoped() {
        for account in PushoverKeychainStore.Account.allCases {
            let attributes = PushoverKeychainStore.itemAttributes(account: account)
            XCTAssertEqual(attributes[kSecClass as String] as? String, kSecClassGenericPassword as String)
            XCTAssertEqual(attributes[kSecAttrService as String] as? String, PushoverKeychainStore.service)
            XCTAssertEqual(attributes[kSecAttrAccount as String] as? String, account.rawValue)
            XCTAssertEqual(attributes[kSecAttrSynchronizable as String] as? Bool, false)
            XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
            XCTAssertNil(attributes[kSecAttrAccessGroup as String])
        }
    }

    func testDefaultPushoverSessionRejectsRedirectsFromFixedHTTPSEndpoint() async throws {
        XCTAssertEqual(PushoverClient.endpoint.scheme, "https")
        XCTAssertEqual(PushoverClient.endpoint.host, "api.pushover.net")
        XCTAssertEqual(PushoverClient.endpoint.path, "/1/messages.json")

        let delegate = PushoverClient.defaultSessionDelegate
        let redirected = URLRequest(url: URL(string: "https://example.invalid/capture")!)
        let response = HTTPURLResponse(
            url: PushoverClient.endpoint,
            statusCode: 307,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": redirected.url!.absoluteString]
        )!
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: PushoverClient.endpoint)
        let decision = await withCheckedContinuation { continuation in
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: redirected
            ) { continuation.resume(returning: $0) }
        }
        XCTAssertNil(decision)
        session.invalidateAndCancel()
    }

    func testNotificationHistoryProjectsSanitizedCopyAndVisibleFailureState() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909051", fixture: fixture)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: CountingTransport()
        )
        await dispatcher.dispatchPending()

        let projection = try await ProjectActivityProjection.load(
            from: fixture.store,
            projectID: .init(rawValue: "project-1")
        )
        let notification = try XCTUnwrap(projection.items.first { $0.source == .notification })
        XCTAssertEqual(notification.title, "RR-09 needs review")
        XCTAssertEqual(notification.detail, "A ticket entered Needs Review in Release Radar.")
        XCTAssertEqual(notification.notificationState, .failed)
        XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
        XCTAssertFalse(notification.title.contains("Transition"))
    }

    func testNotificationHistoryIncludesTicketlessProjectEventAndFailure() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909052")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Request project-level import review",
            command: .requestReview(id: "ticketless-review", ticketID: nil, kind: "unmatched_import", summary: "Uncertain mapping")
        ))
        XCTAssertNil(result.error)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: CountingTransport()
        )
        await dispatcher.dispatchPending()

        let projection = try await ProjectActivityProjection.load(
            from: fixture.store,
            projectID: .init(rawValue: "project-1")
        )
        let notification = try XCTUnwrap(projection.items.first {
            $0.source == .notification && $0.id.contains("notification-")
        })
        XCTAssertNil(notification.ticketID)
        XCTAssertEqual(notification.title, "Delivery item needs review")
        XCTAssertEqual(notification.notificationState, .failed)
        XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
    }

    func testCoordinatorRefreshesVisibleNotificationCountAndFailureAfterBridgeCommit() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: CountingTransport()
        )
        let coordinator = AppNotificationCoordinator(store: fixture.store, dispatcher: dispatcher)
        let model = await AppModel(store: fixture.store, notificationCoordinator: coordinator)
        await model.loadDashboard()
        await model.navigate(to: .projectOverview(.init(rawValue: "project-1")))
        let initialCount = await model.notificationCount
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909053")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Request owner review and refresh",
            command: .requestReview(id: "reactive-review", ticketID: nil, kind: "agent_request", summary: "Review")
        )
        let result = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(result.error)

        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)

        let updatedCount = await model.notificationCount
        let activity = await model.activity(for: .init(rawValue: "project-1"))
        XCTAssertEqual(updatedCount, initialCount + 1)
        let notification = try XCTUnwrap(activity?.items.first {
            $0.source == .notification && $0.title == "Delivery item needs review"
        })
        XCTAssertEqual(notification.notificationState, .failed)
        XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
    }

    func testSuccessfulCallbacksBeforeDashboardRegistrationCoalesceRefreshBeforeNotificationDrain() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let coordinator = AppNotificationCoordinator(
            store: fixture.store,
            dispatcher: PushoverNotificationDispatcher(
                store: fixture.store,
                credentials: StaticPushoverCredentialsProvider(credentials: nil),
                transport: CountingTransport()
            )
        )
        let order = RR9CoordinatorOrderRecorder()
        await coordinator.setActivityRefreshHandler { _ in
            await order.recordNotificationDrain()
        }
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909071")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Queue refresh before handler registration",
            command: .requestReview(
                id: "pre-registration-review",
                ticketID: nil,
                kind: "agent_request",
                summary: "Review"
            )
        )
        let result = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(result.error)

        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)

        let beforeRegistration = await order.snapshot()
        let beforeRegistrationState = try await notificationState(
            for: "pre-registration-review",
            store: fixture.store
        )
        XCTAssertEqual(beforeRegistration.refreshCount, 0)
        XCTAssertEqual(beforeRegistration.notificationDrainCount, 0)
        XCTAssertEqual(beforeRegistrationState, .queued)

        let registration = Task {
            await coordinator.setDashboardRefreshHandler {
                await order.beginRefreshAndWait()
            }
        }
        await order.waitUntilRefreshEntered()
        let duringRefresh = await order.snapshot()
        let duringRefreshState = try await notificationState(
            for: "pre-registration-review",
            store: fixture.store
        )
        XCTAssertEqual(duringRefresh.refreshCount, 1)
        XCTAssertEqual(duringRefresh.notificationDrainCount, 0)
        XCTAssertEqual(duringRefreshState, .queued)

        await order.releaseRefresh()
        await registration.value
        let afterDrain = await order.snapshot()
        let afterDrainState = try await notificationState(
            for: "pre-registration-review",
            store: fixture.store
        )
        XCTAssertEqual(afterDrain.refreshCount, 1)
        XCTAssertEqual(afterDrain.notificationDrainCount, 1)
        XCTAssertEqual(afterDrainState, .failed)
    }

    func testRegisteredSuccessfulCallbackRefreshesBeforeNotificationDrainAndFailedResultQueuesNothing() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let coordinator = AppNotificationCoordinator(
            store: fixture.store,
            dispatcher: PushoverNotificationDispatcher(
                store: fixture.store,
                credentials: StaticPushoverCredentialsProvider(credentials: nil),
                transport: CountingTransport()
            )
        )
        let order = RR9CoordinatorOrderRecorder()
        await coordinator.setActivityRefreshHandler { _ in
            await order.recordNotificationDrain()
        }
        await coordinator.setDashboardRefreshHandler {
            await order.beginRefreshAndWait()
        }
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909072")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Queue registered refresh",
            command: .requestReview(
                id: "registered-refresh-review",
                ticketID: nil,
                kind: "agent_request",
                summary: "Review"
            )
        )
        let result = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(result.error)
        let callback = Task {
            await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
        }

        await order.waitUntilRefreshEntered()
        let duringRefresh = await order.snapshot()
        let duringRefreshState = try await notificationState(
            for: "registered-refresh-review",
            store: fixture.store
        )
        XCTAssertEqual(duringRefresh.refreshCount, 1)
        XCTAssertEqual(duringRefresh.notificationDrainCount, 0)
        XCTAssertEqual(duringRefreshState, .queued)
        await order.releaseRefresh()
        await callback.value
        let afterDrain = await order.snapshot()
        let afterDrainState = try await notificationState(
            for: "registered-refresh-review",
            store: fixture.store
        )
        XCTAssertEqual(afterDrain.notificationDrainCount, 1)
        XCTAssertEqual(afterDrainState, .failed)

        let failed = AgentCommandResult(entityIDs: [], auditEventID: nil, error: .appUnavailable)
        await coordinator.dispatchAfterCommittedCommand(envelope, result: failed)
        let afterFailedResult = await order.snapshot()
        XCTAssertEqual(afterFailedResult.refreshCount, 1)
        XCTAssertEqual(afterFailedResult.notificationDrainCount, 1)
    }

    func testCoordinatorRefreshesDashboardAfterBridgeCommit() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Select active phase") { connection in
            try connection.execute(
                "INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')"
            )
        }
        let coordinator = AppNotificationCoordinator(
            store: fixture.store,
            dispatcher: PushoverNotificationDispatcher(
                store: fixture.store,
                credentials: StaticPushoverCredentialsProvider(credentials: nil),
                transport: CountingTransport()
            )
        )
        let model = await AppModel(store: fixture.store, notificationCoordinator: coordinator)
        await model.loadDashboard()
        let projectID = ProjectID(rawValue: "project-1")
        let ticketID = TicketID(rawValue: "RR-09")
        let initiallyInProgress = await model.dashboard?
            .board(for: projectID)?
            .lane(.inProgress)?
            .cards.contains { $0.id == ticketID }
        XCTAssertEqual(initiallyInProgress, true)

        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909054")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Accept the ticket and refresh the dashboard",
            command: .transitionTicket(ticketID: ticketID.rawValue, lane: .accepted)
        )
        let result = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(result.error)

        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)

        let acceptedAfterCommit = await model.dashboard?
            .board(for: projectID)?
            .lane(.accepted)?
            .cards.contains { $0.id == ticketID }
        XCTAssertEqual(acceptedAfterCommit, true)
    }

    private func transition(
        _ lane: TicketLane,
        requestID: String,
        ticketTaskPlanRevision: Int64? = nil,
        fixture: Fixture
    ) async throws {
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: requestID)!,
            projectRoot: fixture.projectRoot.path,
            reason: "Transition RR-09 to \(lane.rawValue)",
            command: .transitionTicket(
                ticketID: "RR-09",
                lane: lane,
                ticketTaskPlanRevision: ticketTaskPlanRevision
            )
        ))
        if let error = result.error {
            throw NSError(domain: "NotificationAcceptanceTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Required notification transition failed: \(error)",
            ])
        }
    }

    private func task4ANotificationSnapshot(_ store: DeliveryStore) async throws -> Task4ANotificationSnapshot {
        try await store.read { connection in
            var taskRows: [String] = []
            var offset: Int64 = 0
            while let value = try connection.scalarText(
                "SELECT id || '|' || completion || '|' || lifecycle || '|' || updated_at || '|' || COALESCE(completed_at, '') || '|' || COALESCE(superseded_at, '') FROM ticket_tasks WHERE project_id = 'project-1' AND ticket_id = 'RR-09' ORDER BY id LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                taskRows.append(value)
                offset += 1
            }
            return Task4ANotificationSnapshot(
                lane: try connection.scalarText("SELECT lane FROM tickets WHERE project_id = 'project-1' AND id = 'RR-09'"),
                planRevision: try connection.scalarInt("SELECT revision FROM ticket_task_plans WHERE project_id = 'project-1' AND ticket_id = 'RR-09'"),
                taskRows: taskRows,
                isOccurrenceActive: try connection.scalarInt("SELECT is_active FROM notification_occurrences WHERE project_id = 'project-1' AND event_kind = 'ticket_needs_review' AND subject_id = 'RR-09'"),
                occurrenceGeneration: try connection.scalarInt("SELECT generation FROM notification_occurrences WHERE project_id = 'project-1' AND event_kind = 'ticket_needs_review' AND subject_id = 'RR-09'"),
                notificationCount: try connection.scalarInt("SELECT COUNT(*) FROM notification_events") ?? -1,
                auditCount: try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                requestCount: try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1
            )
        }
    }

    private func notificationState(
        for subjectID: String,
        store: DeliveryStore
    ) async throws -> NotificationDeliveryState? {
        let rawState = try await store.read { connection in
            try connection.scalarText(
                "SELECT state FROM notification_events WHERE subject_id = ?",
                bindings: [.text(subjectID)]
            )
        }
        return rawState.flatMap(NotificationDeliveryState.init(rawValue:))
    }

    private struct Fixture {
        let databaseURL: URL
        let projectRoot: URL
        let store: DeliveryStore
        let registry: InMemoryAuthorizedProjectRegistry
        let dispatcher: AgentCommandDispatcher
    }

    private func makeFixture(firstDashboardOpened: Bool) async throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NotificationTests-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed notification fixture") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'Release Radar', ?)",
                bindings: [.integer(firstDashboardOpened ? 1 : 0)]
            )
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)", bindings: [.text(projectRoot.path)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-09', 'project-1', 'phase-1', 'Durable alerts', 'in_progress')")
            try connection.execute("""
                INSERT INTO delivery_goals (project_id, phase_id, id, title, outcome, lifecycle, sort_order, created_at, updated_at, activated_at)
                VALUES ('project-1', 'phase-1', 'fixture-goal', 'Fixture goal', 'Complete fixture', 'active', 0, '2026-09-02T12:00:00Z', '2026-09-02T12:00:00Z', '2026-09-02T12:00:00Z')
                """)
            try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id, phase_id, goal_id, sort_order, criterion) VALUES ('project-1', 'phase-1', 'fixture-goal', 0, 'Delivered')")
            try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id, phase_id, goal_id, ticket_id) VALUES ('project-1', 'phase-1', 'fixture-goal', 'RR-09')")
            try connection.execute("UPDATE phase_plans SET state = 'ready', ready_revision = revision, finalized_at = '2026-09-02T12:00:00Z' WHERE project_id = 'project-1' AND phase_id = 'phase-1'")
        }
        let registry = InMemoryAuthorizedProjectRegistry(projects: [
            .init(projectID: .init(rawValue: "project-1"), canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
        ])
        return Fixture(
            databaseURL: databaseURL,
            projectRoot: projectRoot,
            store: store,
            registry: registry,
            dispatcher: AgentCommandDispatcher(store: store, projectRegistry: registry)
        )
    }
}

private struct Task4ANotificationSnapshot: Equatable {
    let lane: String?
    let planRevision: Int64?
    let taskRows: [String]
    let isOccurrenceActive: Int64?
    let occurrenceGeneration: Int64?
    let notificationCount: Int64
    let auditCount: Int64
    let requestCount: Int64
}

private actor RR9CoordinatorOrderRecorder {
    private(set) var refreshCount = 0
    private(set) var notificationDrainCount = 0
    private var refreshEntered = false
    private var refreshReleased = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func beginRefreshAndWait() async {
        refreshCount += 1
        refreshEntered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        guard !refreshReleased else { return }
        await withCheckedContinuation { releaseContinuations.append($0) }
    }

    func waitUntilRefreshEntered() async {
        guard !refreshEntered else { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func releaseRefresh() {
        refreshReleased = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }

    func recordNotificationDrain() {
        notificationDrainCount += 1
    }

    func snapshot() -> (refreshCount: Int, notificationDrainCount: Int) {
        (refreshCount, notificationDrainCount)
    }
}

private actor CountingTransport: PushoverTransport {
    private(set) var sendCount = 0

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        sendCount += 1
        return .init(requestID: "provider-request")
    }
}

private actor BlockingCountingTransport: PushoverTransport {
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var entered = false
    private var released = false
    private(set) var sendCount = 0

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        sendCount += 1
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        if !released {
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        return .init(requestID: "provider-request")
    }
}

private actor AsyncTestGate {
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var entered = false
    private var released = false

    func enterAndWait() async {
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        guard !released else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private enum FirstDispatchOutcome: Equatable, Sendable {
    case dispatchReturned
    case transportEntered
}

private actor FirstDispatchOutcomeGate {
    private var outcome: FirstDispatchOutcome?
    private var continuation: CheckedContinuation<FirstDispatchOutcome, Never>?

    func signal(_ value: FirstDispatchOutcome) {
        guard outcome == nil else { return }
        outcome = value
        continuation?.resume(returning: value)
        continuation = nil
    }

    func wait() async -> FirstDispatchOutcome {
        if let outcome { return outcome }
        return await withCheckedContinuation { continuation = $0 }
    }
}

private actor SignalingBlockingTransport: PushoverTransport {
    private let firstOutcome: FirstDispatchOutcomeGate
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var entered = false
    private var released = false

    init(firstOutcome: FirstDispatchOutcomeGate) {
        self.firstOutcome = firstOutcome
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        await firstOutcome.signal(.transportEntered)
        if !released {
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        return .init(requestID: "provider-request")
    }
}

private actor InspectingFailingTransport: PushoverTransport {
    private let store: DeliveryStore
    private(set) var observedState: NotificationDeliveryState?

    init(store: DeliveryStore) {
        self.store = store
    }

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        let rawState = try await store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        observedState = rawState.flatMap(NotificationDeliveryState.init(rawValue:))
        throw PushoverTransportError.transportUnavailable
    }
}
