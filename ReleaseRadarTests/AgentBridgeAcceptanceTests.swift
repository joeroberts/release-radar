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

    private func makeFixture() async throws -> Fixture {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-AgentBridgeTests-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = temporaryDirectory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let databaseURL = temporaryDirectory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed bridge fixture") { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)", bindings: [.text(projectRoot.path)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Typed bridge', 'backlog')")
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

}
