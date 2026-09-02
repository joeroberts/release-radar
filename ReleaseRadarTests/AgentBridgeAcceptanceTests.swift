import Foundation
import XCTest
@testable import ReleaseRadarCore

final class AgentBridgeAcceptanceTests: XCTestCase {
    private final class StoreQueueGate: @unchecked Sendable {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
    }

    func testTicketTaskCommandsDecodeAndReturnTheCommittedRevision() async throws {
        let fixture = try await makeFixture()
        let commands = [
            #"{"reviseTicketTaskPlan":{"ticketID":"RR-03","additions":[{"id":"task-1","label":"Task 1","title":"Implement command","sortOrder":0}]}}"#,
            #"{"completeTicketTask":{"ticketID":"RR-03","taskID":"task-1","expectedRevision":1}}"#,
        ]
        for (index, json) in commands.enumerated() {
            let command = try XCTUnwrap(try? JSONDecoder().decode(AgentCommand.self, from: Data(json.utf8)), "The task command must decode")
            let envelope = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path,
                                                assertedThreadID: "task-4b", reason: "Deliver task command", command: command)
            let result = await fixture.dispatcher.dispatch(envelope)
            XCTAssertNil(result.error)
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as! [String: Any]
            XCTAssertEqual(object["ticketTaskPlanRevision"] as? Int, index + 1)
            let replay = await fixture.dispatcher.dispatch(envelope)
            XCTAssertEqual(replay, result)
            let persisted = try await fixture.store.read { c in
                (try c.scalarInt("SELECT revision FROM ticket_task_plans WHERE ticket_id = 'RR-03'"),
                 try c.scalarInt("SELECT COUNT(*) FROM audit_events WHERE entity_type = 'ticket_task_plan'"),
                 try c.scalarInt("SELECT COUNT(*) FROM agent_command_requests"))
            }
            XCTAssertEqual(persisted.0, Int64(index + 1))
            XCTAssertEqual(persisted.1, Int64(index + 1))
            XCTAssertEqual(persisted.2, Int64(index + 1))
        }
    }

    func testTaskPlanRevisionsPersistAuditReceiptsAndReplayAcrossRelaunch() async throws {
        let f = try await makeFixture()
        let commands: [AgentCommand] = [
            .reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("one"), taskDraft("two", order: 1)]),
            .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1,
                                  additions: [taskDraft("three", order: 2)],
                                  definitionRevisions: [.init(id: .init(rawValue: "one"), title: "Revise definition", sortOrder: 3)],
                                  supersededTaskIDs: [.init(rawValue: "two")]),
            .completeTicketTask(ticketID: "RR-03", taskID: "one", expectedRevision: 2),
            .completeTicketTask(ticketID: "RR-03", taskID: "three", expectedRevision: 3),
        ]
        var requests: [(AgentCommandEnvelope, AgentCommandResult)] = []
        for (index, command) in commands.enumerated() {
            XCTAssertEqual(try JSONDecoder().decode(AgentCommand.self, from: JSONEncoder().encode(command)), command)
            let request = taskEnvelope(f, command)
            let result = await f.dispatcher.dispatch(request)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.ticketTaskPlanRevision, Int64(index + 1))
            let stored = try await f.store.read { c in
                let row = try c.row("SELECT result_data FROM agent_command_requests WHERE request_id = ?", bindings: [.text(request.requestID.uuidString)])
                guard case let .blob(data)? = row?["result_data"] else { throw ActivePhaseTestError.missingTextValue }
                let audit = try c.row("SELECT actor_id, thread_id, thread_attribution, project_id, entity_type, entity_id FROM audit_events WHERE id = ?", bindings: [.text(result.auditEventID!.rawValue)])
                return (try JSONDecoder().decode(AgentCommandResult.self, from: data), audit)
            }
            XCTAssertEqual(stored.0, result)
            XCTAssertEqual(stored.1?["actor_id"], .text("release-radar-agent"))
            XCTAssertEqual(stored.1?["thread_id"], .text("task-4b"))
            XCTAssertEqual(stored.1?["thread_attribution"], .text("asserted"))
            XCTAssertEqual(stored.1?["project_id"], .text("project-1"))
            XCTAssertEqual(stored.1?["entity_type"], .text("ticket_task_plan"))
            XCTAssertEqual(stored.1?["entity_id"], .text("RR-03"))
            requests.append((request, result))
        }
        let before = try await Self.task4AAcceptanceSnapshot(f.store)
        let reopened = AgentCommandDispatcher(store: DeliveryStore(databaseURL: f.databaseURL), projectRegistry: f.registry)
        for (request, result) in requests {
            let replay = await reopened.dispatch(request)
            XCTAssertEqual(replay, result)
            let reused = AgentCommandEnvelope(version: 1, requestID: request.requestID, projectRoot: request.projectRoot,
                                               assertedThreadID: request.assertedThreadID, reason: "Changed intent", command: request.command)
            let rejection = await reopened.dispatch(reused)
            XCTAssertEqual(rejection.error, .requestIDReused)
        }
        let after = try await Self.task4AAcceptanceSnapshot(f.store)
        XCTAssertEqual(after, before)
        XCTAssertEqual(after.ticketLanes["RR-03"], "backlog")
        let history = try await f.store.read { c in
            try Self.textRows(c, sql: "SELECT id || '|' || label || '|' || completion || '|' || lifecycle AS value FROM ticket_tasks ORDER BY id")
        }
        XCTAssertEqual(history, ["one|one|completed|active", "three|three|completed|active", "two|two|pending|superseded"])
    }

    func testTaskCommandRejectionsHaveTypedErrorsAndNoEffects() async throws {
        let f = try await makeFixture()
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed foreign ticket") { c in
            try c.execute("INSERT INTO phases (id, project_id, name) VALUES ('foreign-phase', 'project-2', 'Foreign')")
            try c.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('FOREIGN', 'project-2', 'foreign-phase', 'Foreign', 'backlog')")
        }
        for ticket in ["missing", "FOREIGN"] {
            let before = try await Self.task4AAcceptanceSnapshot(f.store)
            let result = await f.dispatcher.dispatch(taskEnvelope(f, .reviseTicketTaskPlan(ticketID: ticket, additions: [taskDraft("one")])))
            XCTAssertEqual(result.error, .invalidTicketTaskMutation("ticketNotFound"))
            let after = try await Self.task4AAcceptanceSnapshot(f.store)
            XCTAssertEqual(after, before)
        }
        let missingPlan = await f.dispatcher.dispatch(taskEnvelope(f, .completeTicketTask(ticketID: "RR-03", taskID: "one", expectedRevision: 1)))
        XCTAssertEqual(missingPlan.error, .ticketTaskPlanNotFound)
        let created = await f.dispatcher.dispatch(taskEnvelope(f, .reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("one"), taskDraft("two") ])))
        XCTAssertNil(created.error)
        let cases: [(AgentCommand, AgentCommandError)] = [
            (.reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("new")]), .ticketTaskPlanAlreadyExists),
            (.completeTicketTask(ticketID: "RR-03", taskID: "two", expectedRevision: 2), .ticketTaskPlanRevisionConflict(expected: 2, current: 1)),
            (.reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 2, additions: [taskDraft("new")]), .ticketTaskPlanRevisionConflict(expected: 2, current: 1)),
            (.completeTicketTask(ticketID: "RR-03", taskID: "missing", expectedRevision: 1), .ticketTaskNotFound(.init(rawValue: "missing"))),
            (.reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1), .invalidTicketTaskMutation("emptyOperationSet")),
            (.reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, supersededTaskIDs: [.init(rawValue: "one"), .init(rawValue: "two")]), .ticketTaskReplacementRequired),
        ]
        for (command, expected) in cases {
            let before = try await Self.task4AAcceptanceSnapshot(f.store)
            let result = await f.dispatcher.dispatch(taskEnvelope(f, command))
            XCTAssertEqual(result.error, expected)
            XCTAssertNil(result.auditEventID)
            XCTAssertNil(result.ticketTaskPlanRevision)
            XCTAssertEqual(try JSONDecoder().decode(AgentCommandResult.self, from: JSONEncoder().encode(result)), result)
            let after = try await Self.task4AAcceptanceSnapshot(f.store)
            XCTAssertEqual(after, before)
        }
        let invalidOperations: [AgentCommand] = [
            .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, additions: [taskDraft("duplicate"), taskDraft("duplicate")]),
            .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, definitionRevisions: [.init(id: .init(rawValue: "one"), title: "Changed", sortOrder: nil)], supersededTaskIDs: [.init(rawValue: "one")]),
            .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, definitionRevisions: [.init(id: .init(rawValue: "one"), title: "Implement one", sortOrder: nil)]),
            .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, additions: [taskDraft("one")]),
        ]
        for command in invalidOperations {
            let before = try await Self.task4AAcceptanceSnapshot(f.store)
            let result = await f.dispatcher.dispatch(taskEnvelope(f, command))
            guard case .invalidTicketTaskMutation? = result.error else { return XCTFail("Expected task rejection: \(result)") }
            let after = try await Self.task4AAcceptanceSnapshot(f.store)
            XCTAssertEqual(after, before)
        }
        let complete = await f.dispatcher.dispatch(taskEnvelope(f, .completeTicketTask(ticketID: "RR-03", taskID: "one", expectedRevision: 1)))
        XCTAssertEqual(complete.ticketTaskPlanRevision, 2)
        let before = try await Self.task4AAcceptanceSnapshot(f.store)
        for command in [AgentCommand.completeTicketTask(ticketID: "RR-03", taskID: "one", expectedRevision: 2),
                        .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 2, definitionRevisions: [.init(id: .init(rawValue: "one"), title: "Rewrite history", sortOrder: nil)])] {
            let result = await f.dispatcher.dispatch(taskEnvelope(f, command))
            XCTAssertEqual(result.error, .ticketTaskImmutable(.init(rawValue: "one")))
        }
        let after = try await Self.task4AAcceptanceSnapshot(f.store)
        XCTAssertEqual(after, before)
    }

    func testTaskCommandBoundsAtAggregateAndEncodedByteLimits() async throws {
        for count in [63, 64, 65] {
            let f = try await makeFixture()
            let command = AgentCommand.reviseTicketTaskPlan(ticketID: "RR-03", additions: (0..<count).map { taskDraft("task-\($0)") })
            let result = await f.dispatcher.dispatch(taskEnvelope(f, command))
            XCTAssertEqual(result.error == nil, count <= 64)
            let rows = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM ticket_tasks") }
            XCTAssertEqual(rows, count <= 64 ? Int64(count) : 0)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for limit in [65_535, 65_536, 65_537] {
            let f = try await makeFixture()
            var additions = (0..<16).map { taskDraft("task-\($0)", title: String(repeating: "x", count: 4_096)) }
            let full = AgentCommand.reviseTicketTaskPlan(ticketID: "RR-03", additions: additions)
            let excess = try encoder.encode(full).count - limit
            XCTAssertTrue((1..<4_096).contains(excess))
            additions[15] = taskDraft("task-15", title: String(repeating: "x", count: 4_096 - excess))
            let command = AgentCommand.reviseTicketTaskPlan(ticketID: "RR-03", additions: additions)
            XCTAssertEqual(try encoder.encode(command).count, limit)
            let result = await f.dispatcher.dispatch(taskEnvelope(f, command))
            XCTAssertEqual(result.error == nil, limit <= 65_536)
            let rows = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM ticket_tasks") }
            XCTAssertEqual(rows, limit <= 65_536 ? 16 : 0)
        }
    }

    func testTaskCommandUTF8BoundsAndMalformedTypedFieldsRejectWithoutEffects() async throws {
        for multibyte in [false, true] {
            for field in ["id", "label", "title"] {
                let maximum = field == "title" ? 4_096 : 256
                for bytes in [maximum - 1, maximum, maximum + 1] {
                    let f = try await makeFixture()
                    let value = multibyte ? String(repeating: "é", count: bytes / 2) + (bytes % 2 == 1 ? "a" : "") : String(repeating: "a", count: bytes)
                    XCTAssertEqual(value.utf8.count, bytes)
                    let draft = TicketTaskDraft(id: .init(rawValue: field == "id" ? value : "one"), label: field == "label" ? value : "One", title: field == "title" ? value : "Implement task", sortOrder: 0)
                    let result = await f.dispatcher.dispatch(taskEnvelope(f, .reviseTicketTaskPlan(ticketID: "RR-03", additions: [draft])))
                    XCTAssertEqual(result.error == nil, bytes <= maximum, "\(field) \(bytes) multibyte=\(multibyte)")
                    let rows = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM ticket_tasks") }
                    XCTAssertEqual(rows, bytes <= maximum ? 1 : 0)
                }
            }
        }
        let f = try await makeFixture()
        let before = try await Self.task4AAcceptanceSnapshot(f.store)
        for command in [AgentCommand.completeTicketTask(ticketID: "RR-03", taskID: "one", expectedRevision: 0),
                        .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: -1, additions: [taskDraft("one")]),
                        .reviseTicketTaskPlan(ticketID: "RR-03\0suffix", additions: [taskDraft("one")]),
                        .reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("one", order: -1)])] {
            let result = await f.dispatcher.dispatch(taskEnvelope(f, command))
            XCTAssertNotNil(result.error)
        }
        let denied = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.projectRoot.deletingLastPathComponent().path,
                                         reason: "Reject unauthorized root", command: .reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("one")]))
        let result = await f.dispatcher.dispatch(denied)
        XCTAssertEqual(result.error, .unauthorizedProjectRoot)
        let after = try await Self.task4AAcceptanceSnapshot(f.store)
        XCTAssertEqual(after, before)
    }

    func testTaskMutationsRollBackAfterLateReceiptFailure() async throws {
        for kind in 0..<3 {
            let f = try await makeFixture()
            if kind > 0 {
                let result = await f.dispatcher.dispatch(taskEnvelope(f, .reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("one")])))
                XCTAssertNil(result.error)
            }
            try await f.store.transact(actor: .init(id: "fixture"), reason: "Inject late failure") { c in
                try c.execute("CREATE TRIGGER task4b_fail BEFORE INSERT ON agent_command_requests BEGIN SELECT RAISE(ABORT, 'Injected late failure'); END")
            }
            let before = try await Self.task4AAcceptanceSnapshot(f.store)
            let commands: [AgentCommand] = [.reviseTicketTaskPlan(ticketID: "RR-03", additions: [taskDraft("one")]),
                .reviseTicketTaskPlan(ticketID: "RR-03", expectedRevision: 1, additions: [taskDraft("two")]),
                .completeTicketTask(ticketID: "RR-03", taskID: "one", expectedRevision: 1)]
            let result = await f.dispatcher.dispatch(taskEnvelope(f, commands[kind]))
            guard case .internalFailure? = result.error else { return XCTFail("Expected injected late failure: \(result)") }
            XCTAssertNil(result.ticketTaskPlanRevision)
            let after = try await Self.task4AAcceptanceSnapshot(f.store)
            XCTAssertEqual(after, before)
        }
    }

    func testLegacyResultJSONOmitsTaskRevision() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = Data(#"{"auditEventID":"audit","entityIDs":["ticket"]}"#.utf8)
        let result = try JSONDecoder().decode(AgentCommandResult.self, from: data)
        XCTAssertNil(result.ticketTaskPlanRevision)
        XCTAssertEqual(try encoder.encode(result), data)
    }

    func testConcurrentAcceptanceAndTaskCommandsCommitOneCoherentWinner() async throws {
        for scenario in 0..<5 {
            let f = try await makeFixture()
            let initialPlan: Task4APlanState = scenario == 0 ? .none : scenario == 1 ? .completed : .pending
            try await seedAcceptanceTicket(store: f.store, ticketID: "RACE", lane: .needsReview, plan: initialPlan)
            let revision: Int64 = scenario == 1 ? 2 : 1
            let first: AgentCommand = scenario >= 3
                ? (scenario == 3
                   ? .reviseTicketTaskPlan(ticketID: "RACE", expectedRevision: revision, additions: [taskDraft("left")])
                   : .completeTicketTask(ticketID: "RACE", taskID: "task-1", expectedRevision: revision))
                : .transitionTicket(ticketID: "RACE", lane: .accepted, ticketTaskPlanRevision: scenario == 0 ? nil : revision)
            let second: AgentCommand = switch scenario {
            case 0: .reviseTicketTaskPlan(ticketID: "RACE", additions: [taskDraft("right")])
            case 1: .reviseTicketTaskPlan(ticketID: "RACE", expectedRevision: revision, additions: [taskDraft("right")], supersededTaskIDs: [.init(rawValue: "task-1")])
            case 2, 4: .completeTicketTask(ticketID: "RACE", taskID: "task-1", expectedRevision: revision)
            default: .reviseTicketTaskPlan(ticketID: "RACE", expectedRevision: revision, additions: [taskDraft("right")])
            }
            let before = try await Self.task4AAcceptanceSnapshot(f.store)
            let gate = StoreQueueGate()
            let store = f.store
            let blocker = Task.detached {
                try await store.read { _ in
                    gate.entered.signal()
                    guard gate.release.wait(timeout: .now() + 5) == .success else { throw ActivePhaseTestError.missingTextValue }
                }
            }
            XCTAssertEqual(gate.entered.wait(timeout: .now() + 2), .success)
            let other = AgentCommandDispatcher(store: store, projectRegistry: f.registry)
            let firstRequest = taskEnvelope(f, first), secondRequest = taskEnvelope(f, second)
            async let left = f.dispatcher.dispatch(firstRequest)
            async let right = other.dispatch(secondRequest)
            gate.release.signal()
            let results = await [left, right]
            try await blocker.value
            XCTAssertEqual(results.filter { $0.error == nil }.count, 1, "scenario \(scenario): \(results)")
            let winner = try XCTUnwrap(results.first { $0.error == nil })
            let loser = try XCTUnwrap(results.first { $0.error != nil })
            XCTAssertNil(loser.auditEventID)
            XCTAssertNil(loser.ticketTaskPlanRevision)
            let after = try await Self.task4AAcceptanceSnapshot(store)
            XCTAssertEqual(after.auditCount, before.auditCount + 1)
            XCTAssertEqual(after.requestCount, before.requestCount + 1)
            XCTAssertEqual(after.phasePlanRows, before.phasePlanRows)
            XCTAssertEqual(after.goalRows, before.goalRows)
            XCTAssertEqual(after.goalAssignmentRows, before.goalAssignmentRows)
            XCTAssertEqual(after.occurrenceRows, before.occurrenceRows)
            XCTAssertEqual(after.notificationRows, before.notificationRows)
            let state = try await store.read { c in
                (try c.scalarInt("SELECT revision FROM ticket_task_plans WHERE ticket_id = 'RACE'"),
                 try c.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE ticket_id = 'RACE'"),
                 try c.scalarInt("SELECT COUNT(*) FROM ticket_tasks WHERE ticket_id = 'RACE' AND lifecycle = 'active' AND completion = 'pending'"),
                 try c.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?", bindings: [.text((results[0].error == nil ? secondRequest : firstRequest).requestID.uuidString)]))
            }
            XCTAssertEqual(state.3, 0)
            if winner.ticketTaskPlanRevision == nil {
                XCTAssertEqual(after.ticketLanes["RACE"], "accepted")
                XCTAssertEqual(state.0, scenario == 0 ? nil : revision)
                XCTAssertEqual(state.1, scenario == 0 ? 0 : 1)
            } else {
                XCTAssertEqual(after.ticketLanes["RACE"], "needs_review")
                XCTAssertEqual(state.0, scenario == 0 ? 1 : revision + 1)
                XCTAssertEqual(state.1, scenario == 0 || scenario == 2 || scenario == 4 ? 1 : 2)
                XCTAssertEqual(state.2, scenario == 2 || scenario == 4 ? 0 : scenario == 3 ? 2 : 1)
            }
            // Replaying the loser after observing the winner still cannot
            // acquire a receipt or change the winning transaction's state.
            let rejected = await other.dispatch(results[0].error == nil ? secondRequest : firstRequest)
            XCTAssertNotNil(rejected.error)
            let afterRetry = try await Self.task4AAcceptanceSnapshot(store)
            XCTAssertEqual(afterRetry, after)
        }
    }

    private func taskDraft(_ id: String, title: String? = nil, order: Int = 0) -> TicketTaskDraft {
        .init(id: .init(rawValue: id), label: id, title: title ?? "Implement \(id)", sortOrder: order)
    }

    private func taskEnvelope(_ f: Fixture, _ command: AgentCommand) -> AgentCommandEnvelope {
        .init(version: 1, requestID: UUID(), projectRoot: f.projectRoot.path, assertedThreadID: "task-4b", reason: "Deliver task command", command: command)
    }

    func testAcceptedUpsertRejectsAbsentAndExistingTicketsBeforeEffects() async throws {
        enum Scenario {
            case absent
            case existingNoPlan
            case existingPlan
        }

        for scenario in [Scenario.absent, .existingNoPlan, .existingPlan] {
            let fixture = try await makeFixture()
            if case .existingPlan = scenario {
                try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed task plan") { connection in
                    _ = try TicketTaskPlanningPolicy.revisePlan(
                        projectID: .init(rawValue: "project-1"),
                        ticketID: .init(rawValue: "RR-03"),
                        expectedRevision: nil,
                        additions: [
                            .init(id: .init(rawValue: "task-1"), label: "Task 1", title: "Complete task", sortOrder: 0),
                        ],
                        definitionRevisions: [],
                        supersededTaskIDs: [],
                        connection: connection
                    )
                }
            }
            let before = try await Self.activePhaseSnapshot(fixture.store)
            let ticketID: String
            if case .absent = scenario {
                ticketID = "RR-NEW"
            } else {
                ticketID = "RR-03"
            }
            let result = await fixture.dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(),
                projectRoot: fixture.projectRoot.path,
                reason: "Reject Accepted upsert",
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
            let after = try await Self.activePhaseSnapshot(fixture.store)
            XCTAssertEqual(after, before)
        }
    }

    func testAcceptedTransitionEmbeddedNULPrefixesRejectBeforeProjectLookupWithIdenticalError() async throws {
        let fixture = try await makeFixture()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed cross-project ticket") { connection in
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('other-phase', 'project-2', 'Other')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('OTHER-TICKET', 'project-2', 'other-phase', 'Other', 'backlog')")
        }
        let registry = CountingAuthorizedProjectRegistry(project: .init(
            projectID: .init(rawValue: "project-1"),
            canonicalRoot: fixture.projectRoot,
            authorizedRoots: [fixture.projectRoot]
        ))
        let dispatcher = AgentCommandDispatcher(store: fixture.store, projectRegistry: registry)
        let before = try await Self.activePhaseSnapshot(fixture.store)
        var errors: [AgentCommandError] = []

        for ticketID in ["RR-03\0suffix", "OTHER-TICKET\0suffix", "MISSING\0suffix"] {
            let result = await dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(),
                projectRoot: fixture.projectRoot.path,
                reason: "Reject malformed Accepted ticket ID",
                command: .transitionTicket(ticketID: ticketID, lane: .accepted)
            ))
            if let error = result.error {
                errors.append(error)
            } else {
                XCTFail("Expected malformed Accepted ticket ID to reject")
            }
        }

        XCTAssertEqual(errors.count, 3)
        XCTAssertTrue(errors.allSatisfy { $0 == errors.first })
        guard case .invalidEnvelope? = errors.first else {
            return XCTFail("Expected identical invalidEnvelope errors, got \(errors)")
        }
        let resolveCount = await registry.resolveCount()
        let after = try await Self.activePhaseSnapshot(fixture.store)
        XCTAssertEqual(resolveCount, 0)
        XCTAssertEqual(after, before)
    }

    func testAcceptedTransitionAppliesTaskPlanRevisionMatrixAtomically() async throws {
        struct Scenario {
            let name: String
            let lane: TicketLane
            let plan: Task4APlanState
            let revision: Int64?
            let succeeds: Bool
        }
        let scenarios = [
            Scenario(name: "no plan omitted", lane: .needsReview, plan: .none, revision: nil, succeeds: true),
            Scenario(name: "no plan present", lane: .needsReview, plan: .none, revision: 1, succeeds: false),
            Scenario(name: "loaded plan omitted", lane: .needsReview, plan: .pending, revision: nil, succeeds: false),
            Scenario(name: "loaded plan stale", lane: .needsReview, plan: .pending, revision: 2, succeeds: false),
            Scenario(name: "pending exact", lane: .needsReview, plan: .pending, revision: 1, succeeds: false),
            Scenario(name: "completed exact", lane: .needsReview, plan: .completed, revision: 2, succeeds: true),
            Scenario(name: "terminal", lane: .accepted, plan: .none, revision: nil, succeeds: false),
        ]

        for (index, scenario) in scenarios.enumerated() {
            let fixture = try await makeFixture()
            try await seedAcceptanceTicket(
                store: fixture.store,
                ticketID: "TASK4A-\(index)",
                lane: scenario.lane,
                plan: scenario.plan
            )
            let before = try await Self.task4AAcceptanceSnapshot(fixture.store)
            let requestID = UUID()
            let result = await fixture.dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: requestID,
                projectRoot: fixture.projectRoot.path,
                reason: "Task 4A matrix \(scenario.name)",
                command: .transitionTicket(
                    ticketID: "TASK4A-\(index)",
                    lane: .accepted,
                    ticketTaskPlanRevision: scenario.revision
                )
            ))
            let after = try await Self.task4AAcceptanceSnapshot(fixture.store)

            if scenario.succeeds {
                XCTAssertNil(result.error, scenario.name)
                XCTAssertEqual(after.ticketLanes["TASK4A-\(index)"], TicketLane.accepted.rawValue, scenario.name)
                XCTAssertEqual(after.planRows, before.planRows, scenario.name)
                XCTAssertEqual(after.taskRows, before.taskRows, scenario.name)
                XCTAssertEqual(after.auditCount, before.auditCount + 1, scenario.name)
                XCTAssertEqual(after.requestCount, before.requestCount + 1, scenario.name)
            } else {
                XCTAssertNotNil(result.error, scenario.name)
                XCTAssertEqual(after, before, scenario.name)
            }
        }
    }

    func testTransitionRevisionMisuseRejectsBeforeProjectLookup() async throws {
        let fixture = try await makeFixture()
        let registry = CountingAuthorizedProjectRegistry(project: .init(
            projectID: .init(rawValue: "project-1"),
            canonicalRoot: fixture.projectRoot,
            authorizedRoots: [fixture.projectRoot]
        ))
        let dispatcher = AgentCommandDispatcher(store: fixture.store, projectRegistry: registry)
        let before = try await Self.task4AAcceptanceSnapshot(fixture.store)

        for (lane, revision) in [(TicketLane.backlog, Int64(1)), (.inProgress, 1), (.needsReview, 1), (.blocked, 1), (.accepted, 0), (.accepted, -1)] {
            let result = await dispatcher.dispatch(.init(
                version: AgentCommandDispatcher.commandEnvelopeVersion,
                requestID: UUID(),
                projectRoot: fixture.projectRoot.path,
                reason: "Reject structurally invalid revision",
                command: .transitionTicket(
                    ticketID: "RR-03",
                    lane: lane,
                    ticketTaskPlanRevision: revision
                )
            ))
            guard case .invalidEnvelope? = result.error else {
                XCTFail("Expected invalidEnvelope for \(lane.rawValue)/\(revision)")
                continue
            }
        }

        let after = try await Self.task4AAcceptanceSnapshot(fixture.store)
        let resolveCount = await registry.resolveCount()
        XCTAssertEqual(resolveCount, 0)
        XCTAssertEqual(after, before)
    }

    func testLegacyTransitionCodableAndCanonicalReceiptReplayRemainCompatible() async throws {
        let fixture = try await makeFixture()
        let legacyCommandData = Data(#"{"transitionTicket":{"ticketID":"RR-03","lane":"backlog"}}"#.utf8)
        let decoded = try JSONDecoder().decode(AgentCommand.self, from: legacyCommandData)
        XCTAssertEqual(
            decoded,
            .transitionTicket(ticketID: "RR-03", lane: .backlog, ticketTaskPlanRevision: nil)
        )
        let encoded = try JSONEncoder().encode(decoded)
        let encodedObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let transitionObject = try XCTUnwrap(encodedObject["transitionTicket"] as? [String: Any])
        XCTAssertNil(transitionObject["ticketTaskPlanRevision"])

        let requestID = UUID(uuidString: "11111111-1111-4111-8111-111111111119")!
        let originalResult = AgentCommandResult(
            entityIDs: ["RR-03"],
            auditEventID: .init(rawValue: "legacy-transition-audit"),
            error: nil
        )
        let legacyBody = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "projectRoot": fixture.projectRoot.path,
            "reason": "Replay legacy canonical transition",
            "command": [
                "transitionTicket": ["ticketID": "RR-03", "lane": "backlog"],
            ],
        ], options: [.sortedKeys])
        let originalResultData = try JSONEncoder().encode(originalResult)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed legacy receipt") { connection in
            try connection.execute(
                "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, '2026-08-31T12:00:00Z')",
                bindings: [.text(requestID.uuidString), .blob(legacyBody), .blob(originalResultData)]
            )
        }
        let before = try await Self.task4AAcceptanceSnapshot(fixture.store)

        let replay = await fixture.dispatcher.dispatch(.init(
            version: AgentCommandDispatcher.commandEnvelopeVersion,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Replay legacy canonical transition",
            command: decoded
        ))

        let after = try await Self.task4AAcceptanceSnapshot(fixture.store)
        XCTAssertEqual(replay, originalResult)
        XCTAssertEqual(after, before)
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
            if index == 7 {
                try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed review-ready work") { connection in
                    try Self.seedGovernedAssignment("RR-04", phase: "phase-2", connection: connection)
                    try connection.execute("UPDATE tickets SET lane='in_progress' WHERE id='RR-04'")
                }
            }
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
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed started work") {
            try $0.execute("UPDATE tickets SET lane='needs_review' WHERE id='RR-03'")
        }
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
        let taskPlans: [String]
        let ticketTasks: [String]
        let phaseDependencies: [String]
        let ticketDependencies: [String]
        let activeRows: [String]
        let auditRows: [String]
        let requestRows: [String]
    }

    private struct Task4AAcceptanceSnapshot: Equatable {
        let ticketLanes: [String: String]
        let planRows: [String]
        let taskRows: [String]
        let phasePlanRows: [String]
        let goalRows: [String]
        let goalAssignmentRows: [String]
        let occurrenceRows: [String]
        let notificationRows: [String]
        let auditCount: Int64
        let requestCount: Int64
    }

    private enum Task4APlanState: Equatable, Sendable {
        case none
        case pending
        case completed
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
                // Test-only structural precondition: bridge behavior is exercised
                // against a valid plan; these rows do not grant legacy continuation.
                try Self.seedGovernedAssignment("RR-03", phase: "phase-1", connection: connection)
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

    private func seedAcceptanceTicket(
        store: DeliveryStore,
        ticketID: String,
        lane: TicketLane,
        plan: Task4APlanState
    ) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed Task 4A matrix ticket") { connection in
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, 'project-1', 'phase-1', 'Task 4A matrix', ?)",
                bindings: [.text(ticketID), .text(lane.rawValue)]
            )
            try Self.seedGovernedAssignment(ticketID, phase: "phase-1", connection: connection)
            guard plan != .none else { return }
            _ = try TicketTaskPlanningPolicy.revisePlan(
                projectID: .init(rawValue: "project-1"),
                ticketID: .init(rawValue: ticketID),
                expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "task-1"), label: "Task 1", title: "Complete task", sortOrder: 0)],
                definitionRevisions: [],
                supersededTaskIDs: [],
                connection: connection
            )
            if plan == .completed {
                _ = try TicketTaskPlanningPolicy.completeTask(
                    projectID: .init(rawValue: "project-1"),
                    ticketID: .init(rawValue: ticketID),
                    taskID: .init(rawValue: "task-1"),
                    expectedRevision: 1,
                    connection: connection
                )
            }
        }
    }

    private static func seedGovernedAssignment(_ ticket: String, phase: String, connection: SQLiteConnection) throws {
        let goal = "fixture-goal-" + phase
        try connection.execute("""
            INSERT INTO delivery_goals (project_id,phase_id,id,title,outcome,lifecycle,sort_order,created_at,updated_at,activated_at)
            VALUES ('project-1',?,?,'Fixture goal','Complete fixture','active',0,'2026-09-02T12:00:00Z','2026-09-02T12:00:00Z','2026-09-02T12:00:00Z')
            ON CONFLICT(project_id,id) DO NOTHING
            """, bindings: [.text(phase), .text(goal)])
        try connection.execute("INSERT INTO delivery_goal_done_criteria (project_id,phase_id,goal_id,sort_order,criterion) VALUES ('project-1',?,?,0,'Delivered') ON CONFLICT DO NOTHING",
                               bindings: [.text(phase), .text(goal)])
        try connection.execute("INSERT INTO delivery_goal_ticket_assignments (project_id,phase_id,goal_id,ticket_id) VALUES ('project-1',?,?,?)",
                               bindings: [.text(phase), .text(goal), .text(ticket)])
        try connection.execute("UPDATE phase_plans SET state='ready',ready_revision=revision,finalized_at='2026-09-02T12:00:00Z' WHERE project_id='project-1' AND phase_id=?", bindings: [.text(phase)])
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
                taskPlans: try Self.textRows(
                    connection,
                    sql: "SELECT project_id || '|' || ticket_id || '|' || revision || '|' || created_at || '|' || updated_at AS value FROM ticket_task_plans ORDER BY project_id, ticket_id"
                ),
                ticketTasks: try Self.textRows(
                    connection,
                    sql: "SELECT project_id || '|' || ticket_id || '|' || id || '|' || label || '|' || title || '|' || sort_order || '|' || completion || '|' || lifecycle || '|' || created_at || '|' || updated_at || '|' || COALESCE(completed_at, '') || '|' || COALESCE(superseded_at, '') AS value FROM ticket_tasks ORDER BY project_id, ticket_id, id"
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

    private static func task4AAcceptanceSnapshot(_ store: DeliveryStore) async throws -> Task4AAcceptanceSnapshot {
        try await store.read { connection in
            var ticketLanes: [String: String] = [:]
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT id, lane FROM tickets WHERE project_id = 'project-1' ORDER BY id LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                guard case let .text(id)? = row["id"], case let .text(lane)? = row["lane"] else {
                    throw ActivePhaseTestError.missingTextValue
                }
                ticketLanes[id] = lane
                offset += 1
            }
            return Task4AAcceptanceSnapshot(
                ticketLanes: ticketLanes,
                planRows: try textRows(connection, sql: "SELECT project_id || '|' || ticket_id || '|' || revision || '|' || created_at || '|' || updated_at AS value FROM ticket_task_plans ORDER BY project_id, ticket_id"),
                taskRows: try textRows(connection, sql: "SELECT project_id || '|' || ticket_id || '|' || id || '|' || label || '|' || title || '|' || sort_order || '|' || completion || '|' || lifecycle || '|' || created_at || '|' || updated_at || '|' || COALESCE(completed_at, '') || '|' || COALESCE(superseded_at, '') AS value FROM ticket_tasks ORDER BY project_id, ticket_id, id"),
                phasePlanRows: try textRows(connection, sql: "SELECT project_id || '|' || phase_id || '|' || state || '|' || revision || '|' || COALESCE(ready_revision, -1) AS value FROM phase_plans ORDER BY project_id, phase_id"),
                goalRows: try textRows(connection, sql: "SELECT project_id || '|' || phase_id || '|' || id || '|' || title || '|' || outcome || '|' || lifecycle || '|' || sort_order AS value FROM delivery_goals ORDER BY project_id, phase_id, id"),
                goalAssignmentRows: try textRows(connection, sql: "SELECT project_id || '|' || phase_id || '|' || goal_id || '|' || ticket_id AS value FROM delivery_goal_ticket_assignments ORDER BY project_id, ticket_id"),
                occurrenceRows: try textRows(connection, sql: "SELECT subject_key || '|' || project_id || '|' || event_kind || '|' || subject_id || '|' || generation || '|' || is_active AS value FROM notification_occurrences ORDER BY subject_key"),
                notificationRows: try textRows(connection, sql: "SELECT id || '|' || fingerprint || '|' || state || '|' || COALESCE(project_id, '') || '|' || COALESCE(event_kind, '') || '|' || COALESCE(subject_id, '') || '|' || COALESCE(occurrence, -1) AS value FROM notification_events ORDER BY id"),
                auditCount: try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                requestCount: try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1
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

private actor CountingAuthorizedProjectRegistry: AuthorizedProjectRegistry {
    private let project: AuthorizedProject
    private var count = 0

    init(project: AuthorizedProject) {
        self.project = project
    }

    func resolve(projectRoot: String) async -> AuthorizedProject? {
        count += 1
        return project
    }

    func resolveCount() -> Int {
        count
    }
}

private enum ActivePhaseTestError: Error {
    case missingTextValue
}
