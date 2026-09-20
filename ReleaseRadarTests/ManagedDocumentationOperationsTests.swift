import Darwin
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ManagedDocumentationOperationsTests: XCTestCase {
    private actor ExecutionPreparer: ProjectExecutionAssignmentPreparing {
        private final class Storage: @unchecked Sendable {
            let lock = NSLock()
            var value: ProjectExecutionAssignment?
        }
        private nonisolated let storage = Storage()
        var prepares = 0
        var preparesByRequestID: [UUID: Int] = [:]
        var definiteRefusals: Set<UUID> = []
        var partialRefusals: Set<UUID> = []
        var unattributedConflicts: Set<UUID> = []
        var acceptedReviewParents: Set<String> = []
        var activePreparation: UUID?
        var gate: DocumentationCommitGate?
        var noEffectsGate: DocumentationCommitGate?
        var value: ProjectExecutionAssignment? {
            get { storage.lock.withLock { storage.value } }
            set { storage.lock.withLock { storage.value = newValue } }
        }
        func setGate(_ gate: DocumentationCommitGate) { self.gate = gate }
        func setNoEffectsGate(_ gate: DocumentationCommitGate) { noEffectsGate = gate }
        func refuseBeforeEffects(_ requestID: UUID) { definiteRefusals.insert(requestID) }
        func refuseAfterPreparing(_ requestID: UUID) { partialRefusals.insert(requestID) }
        func conflictWithoutKnownCause(_ requestID: UUID) { unattributedConflicts.insert(requestID) }
        func allowReview(parentID: String) { acceptedReviewParents.insert(parentID) }
        func prepare(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID, reviewOfAssignmentID: String?, baselineFromAssignmentID: String?, contextPaths: [String]) async throws -> ProjectExecutionAssignment {
            guard activePreparation == nil else { throw ProjectExecutionError.conflict }
            activePreparation = requestID
            prepares += 1
            preparesByRequestID[requestID, default: 0] += 1
            if unattributedConflicts.contains(requestID) { throw ProjectExecutionError.conflict }
            if definiteRefusals.contains(requestID) {
                throw ProjectExecutionPreparationFailure.noEffectsCandidate(.assignmentNotAuthorized)
            }
            guard baselineFromAssignmentID == nil else { throw ProjectExecutionError.assignmentNotAuthorized }
            if let reviewOfAssignmentID {
                guard acceptedReviewParents.contains(reviewOfAssignmentID) else { throw ProjectExecutionError.assignmentNotAuthorized }
            }
            if let gate { await gate.enterAndWait(); self.gate = nil }
            let role: ProjectExecutionAssignment.Role = reviewOfAssignmentID == nil ? .delivery : .review
            var assignment = ProjectExecutionAssignment(id: role.rawValue + "-" + requestID.uuidString.lowercased(), registration: project.registration!,
                checkoutPath: "/Fixture/Checkout", role: role, permissionProfile: "rr-fixture", model: "gpt-5.6-terra", effort: "medium",
                authorization: "Existing bounded work", context: contextPaths.map { .init(path: $0, digest: String(repeating: "a", count: 64)) },
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], work: work,
                reviewOfAssignmentID: reviewOfAssignmentID)
            assignment.state = .preparing; value = assignment
            if partialRefusals.contains(requestID) { throw ProjectExecutionError.assignmentNotAuthorized }
            return assignment
        }
        func finishPreparation(work: ProjectExecutionWork, requestID: UUID) async {
            if activePreparation == requestID { activePreparation = nil }
        }
        func verifyNoPreparationEffects(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                                        reviewOfAssignmentID: String?, baselineFromAssignmentID: String?) async -> Bool {
            if let noEffectsGate { await noEffectsGate.enterAndWait(); self.noEffectsGate = nil }
            return definiteRefusals.contains(requestID) && !partialRefusals.contains(requestID)
        }
        nonisolated func admitPrepared(_ assignment: ProjectExecutionAssignment) throws -> ProjectExecutionAssignment {
            try storage.lock.withLock {
                guard storage.value == assignment, assignment.state == .preparing else { throw ProjectExecutionError.assignmentNotAuthorized }
                var admitted = assignment; admitted.state = .authorized; storage.value = admitted; return admitted
            }
        }
        nonisolated func revokePreparation(_ assignment: ProjectExecutionAssignment) throws {
            try storage.lock.withLock {
                guard var current = storage.value, current.id == assignment.id, current.work == assignment.work else { throw ProjectExecutionError.identityMismatch }
                current.state = .revoked; current.finalizationFailed = true; storage.value = current
            }
        }
        func readCurrent(project: AuthorizedProject, assignmentID: String) throws -> ProjectExecutionAssignment {
            guard let value, value.id == assignmentID, value.registration == project.registration else { throw ProjectExecutionError.identityMismatch }; return value
        }
        func stop() { value?.state = .stopped }
    }

    private func executionFixture() async throws -> (DeliveryStore, URL, ProjectRegistration, AgentCommandDispatcher, ExecutionPreparer) {
        let f = try await makeFixture()
        let registration = ProjectRegistration(projectID: .init(rawValue: "p"), registrationID: "execution-registration", requestGeneration: 1)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed authorized execution work") { c in
            try c.execute("INSERT INTO project_registrations(project_id,registration_id,request_generation,setup_state) VALUES ('p','execution-registration',1,'complete')")
            try DeliveryPlanningPolicy.upsertPhase(projectID: registration.projectID, phaseID: .init(rawValue: "phase"), name: "Phase", mode: .governed, connection: c)
            try c.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=2 WHERE project_id='p' AND phase_id='phase'")
            try c.execute("INSERT INTO tickets(id,project_id,phase_id,outcome,lane) VALUES ('ticket','p','phase','Bounded outcome','in_progress')")
            _ = try TicketTaskPlanningPolicy.revisePlan(projectID: registration.projectID, ticketID: .init(rawValue: "ticket"), expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "task"), label: "A", title: "Approved task", sortOrder: 0)], definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let registry = PersistedAuthorizedProjectRegistry(store: f.store)
        let preparer = ExecutionPreparer()
        let dispatcher = AgentCommandDispatcher(store: f.store, projectRegistry: registry, bookmarkStore: bookmarks(f.root), executionAssignments: preparer)
        let binding = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: f.root.path, expectedRegistration: registration,
            reason: "Bind fixture catalog", command: .bindDocumentationRepository(target: try target(f.root))))
        XCTAssertNil(binding.error)
        return (f.store, f.root, registration, dispatcher, preparer)
    }

    func testExecutionCommandAuditsExactRequestAndReplayReadsCurrentStoppedAuthority() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: root.path, expectedRegistration: registration, reason: "Existing authorized work",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task", expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil))
        let result = await dispatcher.dispatch(request)
        XCTAssertNil(result.error); XCTAssertNotNil(result.auditEventID)
        XCTAssertEqual(result.executionAssignment?.work?.title, "Approved task")
        XCTAssertEqual(result.executionAssignment?.role, .delivery)
        await preparer.stop()
        let replay = await dispatcher.dispatch(request)
        XCTAssertNil(replay.error); XCTAssertEqual(replay.auditEventID, result.auditEventID)
        XCTAssertEqual(replay.executionAssignment?.state, .stopped)
        let count = await preparer.prepares; XCTAssertEqual(count, 1)
        let audits = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE id=?", bindings: [.text(result.auditEventID!.rawValue)]) }
        XCTAssertEqual(audits, 1)
        let changed = AgentCommandEnvelope(version: 1, requestID: request.requestID, projectRoot: root.path, expectedRegistration: registration, reason: "Changed request", command: request.command)
        let reused = await dispatcher.dispatch(changed); XCTAssertEqual(reused.error, .requestIDReused)
    }

    func testExecutionCommandRejectsMissingProducerStaleWorkRootAndUnknownReviewCandidate() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let command = AgentCommand.prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task", expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil)
        let missing = AgentCommandDispatcher(store: store, projectRegistry: PersistedAuthorizedProjectRegistry(store: store), bookmarkStore: bookmarks(root))
        let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: root.path, expectedRegistration: registration, reason: "Main assertion alone", command: command)
        let unavailable = await missing.dispatch(request); XCTAssertEqual(unavailable.error, .execution(.unavailable))
        let wrongRoot = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: root.path + "-other", expectedRegistration: registration, reason: "Wrong root", command: command))
        XCTAssertEqual(wrongRoot.error, .unauthorizedProjectRoot)
        let stale = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: root.path, expectedRegistration: registration, reason: "Stale work",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task", expectedTaskPlanRevision: 2, expectedPhaseRevision: 2, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil)))
        XCTAssertEqual(stale.error, .execution(.assignmentNotAuthorized))
        let count = await preparer.prepares; XCTAssertEqual(count, 0)
        let review = await dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: root.path, expectedRegistration: registration, reason: "Unknown review candidate",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task", expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: "delivery-unknown", baselineFromAssignmentID: nil)))
        XCTAssertEqual(review.error, .execution(.assignmentNotAuthorized))
    }

    func testPausedPreparationCannotPublishAuthorityAfterWorkChangedBeforeAssignmentExists() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let gate = DocumentationCommitGate(); await preparer.setGate(gate)
        let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: root.path, expectedRegistration: registration, reason: "Existing work",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task", expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil))
        let operation = Task { await dispatcher.dispatch(request) }
        await gate.waitUntilEntered()
        try await store.transact(actor: .init(id: "fixture"), reason: "Change work during installation validation",
            auditScope: .init(projectID: registration.projectID, entityType: .ticketTaskPlan, entityID: "ticket")) {
            try $0.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='p' AND ticket_id='ticket'")
        }
        await gate.release()
        let result = await operation.value
        XCTAssertEqual(result.error, .execution(.assignmentNotAuthorized))
        let value = await preparer.value; XCTAssertEqual(value?.state, .revoked)
        XCTAssertNil(result.executionAssignment)
    }

    func testExpiredFinalAdmissionRevokesPreparedAuthorityAndExactRequestCanRecover() async throws {
        let (_, root, registration, dispatcher, preparer) = try await executionFixture()
        let gate = DocumentationCommitGate(); await preparer.setGate(gate)
        let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: root.path, expectedRegistration: registration, reason: "Existing work",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task", expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil))
        let deadline = Date().addingTimeInterval(5).timeIntervalSince1970
        let operation = Task { await dispatcher.dispatch(request, admissionDeadline: deadline) }
        await gate.waitUntilEntered()
        try await Task.sleep(nanoseconds: UInt64(max(0, deadline - Date().timeIntervalSince1970 + 0.05) * 1_000_000_000))
        await gate.release()
        let result = await operation.value
        XCTAssertEqual(result.error, .execution(.unavailable))
        let value = await preparer.value; XCTAssertEqual(value?.state, .revoked)
        let recovered = await dispatcher.dispatch(request)
        XCTAssertNil(recovered.error); XCTAssertEqual(recovered.executionAssignment?.state, .authorized)
    }

    func testDefinitePreparationRefusalSettlesExactReceiptAndDoesNotStrandFreshWork() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let refusedRequestID = UUID()
        await preparer.refuseBeforeEffects(refusedRequestID)
        let refused = AgentCommandEnvelope(version: 1, requestID: refusedRequestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Retired parent cannot authorize a new assignment",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: "delivery-retired"))

        let first = await dispatcher.dispatch(refused)
        XCTAssertEqual(first.error, .execution(.assignmentNotAuthorized))
        let refusalAuditID = try XCTUnwrap(first.auditEventID, "A definite refusal needs an audited terminal receipt")

        let replay = await dispatcher.dispatch(refused)
        XCTAssertEqual(replay, first)
        let refusedPrepares = await preparer.preparesByRequestID[refusedRequestID]
        XCTAssertEqual(refusedPrepares, 1, "Exact replay must not rerun a terminal refusal")

        let changed = AgentCommandEnvelope(version: 1, requestID: refusedRequestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Changed body", command: refused.command)
        let changedResult = await dispatcher.dispatch(changed)
        XCTAssertEqual(changedResult.error, .requestIDReused)

        let freshRequestID = UUID()
        let fresh = AgentCommandEnvelope(version: 1, requestID: freshRequestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Fresh canonical baseline",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: nil))
        let recovered = await dispatcher.dispatch(fresh)
        XCTAssertNil(recovered.error)
        XCTAssertEqual(recovered.executionAssignment?.state, .authorized)
        let freshPrepares = await preparer.preparesByRequestID[freshRequestID]
        XCTAssertEqual(freshPrepares, 1)

        let auditCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE id=?", bindings: [.text(refusalAuditID.rawValue)])
        }
        XCTAssertEqual(auditCount, 1)
    }

    func testHistoricalTaskMismatchReplaySettlesOnlyExactReceiptAndAllowsCorrectedReview() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        await preparer.refuseBeforeEffects(requestID)
        let mismatch = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Historical task mismatch",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2,
                reviewOfAssignmentID: "delivery-wrong-task", baselineFromAssignmentID: nil))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(mismatch)
        let pending = AgentCommandResult(entityIDs: ["ticket", "task"], auditEventID: nil, error: .outcomeUnknown)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed historical task-mismatch receipt") { connection in
            try connection.execute("""
                INSERT INTO agent_command_requests
                    (request_id,request_body,result_data,created_at,registration_project_id,registration_id,request_generation)
                VALUES (?,?,?,?,?,?,?)
                """, bindings: [
                    .text(requestID.uuidString), .blob(body), .blob(try JSONEncoder().encode(pending)),
                    .text("2026-09-19T12:00:00Z"), .text(registration.projectID.rawValue),
                    .text(registration.registrationID), .integer(registration.requestGeneration)
                ])
        }

        let terminal = await dispatcher.dispatch(mismatch)
        XCTAssertEqual(terminal.error, .execution(.assignmentNotAuthorized))
        let auditID = try XCTUnwrap(terminal.auditEventID)
        let replay = await dispatcher.dispatch(mismatch)
        XCTAssertEqual(replay, terminal)
        let mismatchPrepares = await preparer.preparesByRequestID[requestID]
        XCTAssertEqual(mismatchPrepares, 1)

        let changed = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Changed historical body", command: mismatch.command)
        let changedResult = await dispatcher.dispatch(changed)
        XCTAssertEqual(changedResult.error, .requestIDReused)

        await preparer.allowReview(parentID: "delivery-correct-task")
        let correctedRequestID = UUID()
        let corrected = AgentCommandEnvelope(version: 1, requestID: correctedRequestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Corrected review parent",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2,
                reviewOfAssignmentID: "delivery-correct-task", baselineFromAssignmentID: nil))
        let recovered = await dispatcher.dispatch(corrected)
        XCTAssertNil(recovered.error)
        XCTAssertEqual(recovered.executionAssignment?.role, .review)
        XCTAssertEqual(recovered.executionAssignment?.reviewOfAssignmentID, "delivery-correct-task")
        let correctedPrepares = await preparer.preparesByRequestID[correctedRequestID]
        XCTAssertEqual(correctedPrepares, 1)

        let auditCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM audit_events WHERE id=?", bindings: [.text(auditID.rawValue)])
        }
        XCTAssertEqual(auditCount, 1)
    }

    func testStaleRegistrationPendingReviewReceiptDoesNotBlockCurrentAuthorizedReview() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let staleRegistration = ProjectRegistration(
            projectID: registration.projectID,
            registrationID: "stale-execution-registration",
            requestGeneration: 1
        )
        let staleRequestID = UUID()
        let stale = AgentCommandEnvelope(
            version: 1,
            requestID: staleRequestID,
            projectRoot: root.path,
            expectedRegistration: staleRegistration,
            reason: "Historical review preparation",
            command: .prepareExecutionAssignment(
                projectID: "p",
                ticketID: "ticket",
                taskID: "task",
                expectedTaskPlanRevision: 1,
                expectedPhaseRevision: 2,
                reviewOfAssignmentID: "delivery-stale",
                baselineFromAssignmentID: nil
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let pending = AgentCommandResult(
            entityIDs: ["ticket", "task"],
            auditEventID: nil,
            error: .outcomeUnknown
        )
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed stale registration review receipt") { connection in
            try connection.execute(
                """
                INSERT INTO agent_command_requests
                    (request_id,request_body,result_data,created_at,registration_project_id,registration_id,request_generation)
                VALUES (?,?,?,?,?,?,?)
                """,
                bindings: [
                    .text(staleRequestID.uuidString),
                    .blob(try encoder.encode(stale)),
                    .blob(try JSONEncoder().encode(pending)),
                    .text("2026-09-19T12:00:00Z"),
                    .text(staleRegistration.projectID.rawValue),
                    .text(staleRegistration.registrationID),
                    .integer(staleRegistration.requestGeneration),
                ]
            )
        }

        let currentParent = "delivery-current"
        await preparer.allowReview(parentID: currentParent)
        let currentRequestID = UUID()
        let current = AgentCommandEnvelope(
            version: 1,
            requestID: currentRequestID,
            projectRoot: root.path,
            expectedRegistration: registration,
            reason: "Current authorized review preparation",
            command: .prepareExecutionAssignment(
                projectID: "p",
                ticketID: "ticket",
                taskID: "task",
                expectedTaskPlanRevision: 1,
                expectedPhaseRevision: 2,
                reviewOfAssignmentID: currentParent,
                baselineFromAssignmentID: nil
            )
        )

        let result = await dispatcher.dispatch(current)

        XCTAssertNil(result.error)
        XCTAssertNil(result.preparationDiagnostic)
        XCTAssertEqual(result.executionAssignment?.role, .review)
        XCTAssertEqual(result.executionAssignment?.reviewOfAssignmentID, currentParent)
        let currentPrepares = await preparer.preparesByRequestID[currentRequestID]
        XCTAssertEqual(currentPrepares, 1)
        let persistedStale = try await store.read { connection -> AgentCommandResult in
            guard case let .blob(data)? = try connection.row(
                "SELECT result_data FROM agent_command_requests WHERE request_id=?",
                bindings: [.text(staleRequestID.uuidString)]
            )?["result_data"] else {
                throw ProjectExecutionError.unavailable
            }
            return try JSONDecoder().decode(AgentCommandResult.self, from: data)
        }
        XCTAssertEqual(persistedStale, pending, "Stale uncertainty remains retained under its original registration")
    }

    func testTerminalPreparationRefusalReplaySurvivesLaterWorkIneligibility() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        await preparer.refuseBeforeEffects(requestID)
        let request = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Retired parent cannot authorize a new assignment",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: "delivery-retired"))
        let terminal = await dispatcher.dispatch(request)
        XCTAssertEqual(terminal.error, .execution(.assignmentNotAuthorized))
        XCTAssertNotNil(terminal.auditEventID)

        try await store.transact(actor: .init(id: "fixture"), reason: "Complete work after terminal refusal",
            auditScope: .init(projectID: registration.projectID, entityType: .ticketTaskPlan, entityID: "ticket")) {
                try $0.execute("UPDATE ticket_tasks SET completion='completed',completed_at=created_at WHERE project_id='p' AND ticket_id='ticket' AND id='task'")
                try $0.execute("UPDATE phase_lifecycles SET revision=3 WHERE project_id='p' AND phase_id='phase'")
            }

        let replay = await dispatcher.dispatch(request)
        XCTAssertEqual(replay, terminal, "Exact terminal replay must not depend on later mutable work eligibility")
        let prepares = await preparer.preparesByRequestID[requestID]
        XCTAssertEqual(prepares, 1)
        let changed = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Changed body after completion", command: request.command)
        let reused = await dispatcher.dispatch(changed)
        XCTAssertEqual(reused.error, .requestIDReused)
    }

    func testConcurrentExactAndFreshRequestsStayBlockedDuringTerminalSettlement() async throws {
        let (_, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        await preparer.refuseBeforeEffects(requestID)
        let gate = DocumentationCommitGate()
        await preparer.setNoEffectsGate(gate)
        let request = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Retired parent refusal",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: "delivery-retired"))
        let settlement = Task { await dispatcher.dispatch(request) }
        await gate.waitUntilEntered()

        let exact = await dispatcher.dispatch(request)
        XCTAssertEqual(exact.error, .execution(.conflict))
        let fresh = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: root.path,
            expectedRegistration: registration, reason: "Fresh request during settlement",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: nil))
        let freshResult = await dispatcher.dispatch(fresh)
        XCTAssertEqual(freshResult.error, .execution(.conflict))

        await gate.release()
        let terminal = await settlement.value
        XCTAssertEqual(terminal.error, .execution(.assignmentNotAuthorized))
        XCTAssertNotNil(terminal.auditEventID)
        let replay = await dispatcher.dispatch(request)
        XCTAssertEqual(replay, terminal)
        let prepares = await preparer.preparesByRequestID[requestID]
        XCTAssertEqual(prepares, 1)
    }

    func testPartiallyPreparedRefusalKeepsOutcomeUnknownAndBlocksReplacement() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        await preparer.refuseAfterPreparing(requestID)
        let request = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Preparation may have effects",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: nil))

        let uncertain = await dispatcher.dispatch(request)
        XCTAssertEqual(uncertain.error, .execution(.assignmentNotAuthorized))
        XCTAssertNil(uncertain.auditEventID)
        let partialState = await preparer.value?.state
        XCTAssertEqual(partialState, .preparing)
        let persisted = try await store.read { connection -> AgentCommandResult in
            let bytes = try XCTUnwrap(connection.row(
                "SELECT result_data FROM agent_command_requests WHERE request_id=?",
                bindings: [.text(requestID.uuidString)])?["result_data"])
            guard case let .blob(data) = bytes else { throw ProjectExecutionError.unavailable }
            return try JSONDecoder().decode(AgentCommandResult.self, from: data)
        }
        XCTAssertEqual(persisted.error, .outcomeUnknown)

        let replacement = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: root.path,
            expectedRegistration: registration, reason: "Replacement must remain blocked",
            command: request.command)
        let blocked = await dispatcher.dispatch(replacement)
        XCTAssertEqual(blocked.error, .execution(.conflict))
        XCTAssertEqual(blocked.preparationDiagnostic, .init(
            kind: .pendingPreparationRequest,
            blockingRequestID: requestID,
            blockingAssignmentID: nil,
            evidence: .observedAtFailure
        ))
    }

    func testUnattributedPreparationConflictReportsUnknownCauseWithoutSettlingReceipt() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        await preparer.conflictWithoutKnownCause(requestID)
        let request = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: root.path,
            expectedRegistration: registration,
            reason: "Synthetic unattributed preparation conflict",
            command: .prepareExecutionAssignment(
                projectID: "p",
                ticketID: "ticket",
                taskID: "task",
                expectedTaskPlanRevision: 1,
                expectedPhaseRevision: 2,
                reviewOfAssignmentID: nil,
                baselineFromAssignmentID: nil
            )
        )

        let result = await dispatcher.dispatch(request)

        XCTAssertEqual(result.error, .execution(.conflict))
        XCTAssertEqual(result.preparationDiagnostic, .init(
            kind: .causeUnavailable,
            blockingRequestID: nil,
            blockingAssignmentID: nil,
            evidence: .observedAtFailure
        ))
        XCTAssertNil(result.auditEventID)
        let persisted = try await store.read { connection -> AgentCommandResult in
            guard case let .blob(data)? = try connection.row(
                "SELECT result_data FROM agent_command_requests WHERE request_id=?",
                bindings: [.text(requestID.uuidString)]
            )?["result_data"] else {
                throw ProjectExecutionError.unavailable
            }
            return try JSONDecoder().decode(AgentCommandResult.self, from: data)
        }
        XCTAssertEqual(persisted.error, .outcomeUnknown)
        XCTAssertNil(persisted.preparationDiagnostic)
    }

    func testPreparationDiagnosticIsAdditiveForLegacyJSONAndRoundTrips() throws {
        let legacy = Data(#"{"entityIDs":[],"auditEventID":null,"error":null}"#.utf8)
        let decoded = try JSONDecoder().decode(AgentCommandResult.self, from: legacy)
        XCTAssertNil(decoded.preparationDiagnostic)

        let requestID = UUID()
        let current = AgentCommandResult(
            entityIDs: [],
            auditEventID: nil,
            error: .execution(.conflict),
            preparationDiagnostic: .init(
                kind: .pendingPreparationRequest,
                blockingRequestID: requestID,
                blockingAssignmentID: nil,
                evidence: .recordedFailure
            )
        )
        XCTAssertEqual(try JSONDecoder().decode(AgentCommandResult.self, from: JSONEncoder().encode(current)), current)
    }

    func testStoredPreparationDiagnosticReplaysAsRecordedWithoutRecomputingOrDisclosureOnChangedBody() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        let request = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: root.path,
            expectedRegistration: registration,
            reason: "Stored diagnostic fixture",
            command: .prepareExecutionAssignment(
                projectID: "p",
                ticketID: "ticket",
                taskID: "task",
                expectedTaskPlanRevision: 1,
                expectedPhaseRevision: 2,
                reviewOfAssignmentID: nil,
                baselineFromAssignmentID: nil
            )
        )
        let stored = AgentCommandResult(
            entityIDs: [],
            auditEventID: nil,
            error: .execution(.conflict),
            preparationDiagnostic: .init(
                kind: .preparationInProgress,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(request)
        let storedBytes = try JSONEncoder().encode(stored)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed stored preparation diagnostic") { connection in
            try connection.execute(
                """
                INSERT INTO agent_command_requests
                    (request_id,request_body,result_data,created_at,registration_project_id,registration_id,request_generation)
                VALUES (?,?,?,?,?,?,?)
                """,
                bindings: [
                    .text(requestID.uuidString), .blob(body), .blob(storedBytes),
                    .text("2026-09-20T12:00:00Z"), .text(registration.projectID.rawValue),
                    .text(registration.registrationID), .integer(registration.requestGeneration),
                ]
            )
        }

        let replay = await dispatcher.dispatch(request)

        XCTAssertEqual(replay.error, stored.error)
        XCTAssertEqual(replay.preparationDiagnostic, .init(
            kind: .preparationInProgress,
            blockingRequestID: nil,
            blockingAssignmentID: nil,
            evidence: .recordedFailure
        ))
        let prepares = await preparer.prepares
        XCTAssertEqual(prepares, 0)
        let persistedBytes = try await store.read { connection -> Data in
            guard case let .blob(data)? = try connection.row(
                "SELECT result_data FROM agent_command_requests WHERE request_id=?",
                bindings: [.text(requestID.uuidString)]
            )?["result_data"] else {
                throw ProjectExecutionError.unavailable
            }
            return data
        }
        XCTAssertEqual(persistedBytes, storedBytes, "Replay must not rewrite recorded evidence")

        let changed = AgentCommandEnvelope(
            version: request.version,
            requestID: request.requestID,
            projectRoot: request.projectRoot,
            expectedRegistration: request.expectedRegistration,
            reason: "Changed body",
            command: request.command
        )
        let rejected = await dispatcher.dispatch(changed)
        XCTAssertEqual(rejected.error, .requestIDReused)
        XCTAssertNil(rejected.preparationDiagnostic)
    }

    func testChangedWorkBeforeRefusalSettlementPreservesOutcomeUnknown() async throws {
        let (store, root, registration, dispatcher, preparer) = try await executionFixture()
        let requestID = UUID()
        await preparer.refuseBeforeEffects(requestID)
        let gate = DocumentationCommitGate()
        await preparer.setNoEffectsGate(gate)
        let request = AgentCommandEnvelope(version: 1, requestID: requestID, projectRoot: root.path,
            expectedRegistration: registration, reason: "Retired parent refusal",
            command: .prepareExecutionAssignment(projectID: "p", ticketID: "ticket", taskID: "task",
                expectedTaskPlanRevision: 1, expectedPhaseRevision: 2, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: "delivery-retired"))
        let operation = Task { await dispatcher.dispatch(request) }
        await gate.waitUntilEntered()
        try await store.transact(actor: .init(id: "fixture"), reason: "Change work before refusal settlement",
            auditScope: .init(projectID: registration.projectID, entityType: .ticketTaskPlan, entityID: "ticket")) {
                try $0.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='p' AND ticket_id='ticket' AND id='task'")
            }
        await gate.release()

        let result = await operation.value
        XCTAssertEqual(result.error, .execution(.assignmentNotAuthorized))
        XCTAssertNil(result.auditEventID)
        let persisted = try await store.read { connection -> AgentCommandResult in
            guard case let .blob(data)? = try connection.row(
                "SELECT result_data FROM agent_command_requests WHERE request_id=?",
                bindings: [.text(requestID.uuidString)])?["result_data"] else {
                throw ProjectExecutionError.unavailable
            }
            return try JSONDecoder().decode(AgentCommandResult.self, from: data)
        }
        XCTAssertEqual(persisted.error, .outcomeUnknown)
    }

    func testManagedEvidenceWriterRejectsCompletedTicketAssociation() async throws {
        let fixture = try await makeFixture()
        let documentation = try target(fixture.root)
        let binding = await fixture.dispatcher.dispatch(
            envelope(fixture.root, .bindDocumentationRepository(target: documentation))
        )
        XCTAssertNil(binding.error)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed completed evidence owner") { connection in
            try connection.execute("INSERT INTO phases (id,project_id,name) VALUES ('phase','p','Completed phase')")
            try connection.execute("INSERT INTO tickets (id,project_id,phase_id,outcome,lane) VALUES ('ticket','p','phase','Delivered','accepted')")
            try connection.execute("UPDATE phase_lifecycles SET lifecycle='completed',revision=1,completion_baseline_digest='fixture-baseline',completed_at='2026-09-10T00:00:00Z' WHERE project_id='p' AND phase_id='phase'")
        }

        let result = await fixture.dispatcher.dispatch(envelope(
            fixture.root,
            .addManagedEvidence(
                target: documentation,
                id: "blocked-managed-evidence",
                ticketID: "ticket",
                artifactID: "current"
            )
        ))

        XCTAssertEqual(result.error, .completedPhaseReadOnly(.init(rawValue: "phase")))
        let count = try await fixture.store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM evidence WHERE id='blocked-managed-evidence'")
        }
        XCTAssertEqual(count, 0)
    }

    func testProjectDocumentationPreviewKeepsSecurityScopeOpenForCatalogReadAndReleasesIt() async throws {
        let fixture = try await makeFixture()
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "p"),
            registrationID: "scope-gated-registration",
            requestGeneration: 1
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed scoped lifecycle registration") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('p', ?, 1, 'complete')",
                bindings: [.text(registration.registrationID)]
            )
        }
        let bookmarks = ScopeGatedBookmarkStore(root: fixture.root)
        XCTAssertEqual(chmod(fixture.root.path, 0), 0)
        defer { XCTAssertEqual(chmod(fixture.root.path, 0o700), 0) }
        let coordinator = ProjectDocumentationSetupCoordinator(
            store: fixture.store,
            bookmarkStore: bookmarks
        )

        let preview = try await coordinator.preview(registration: registration)

        XCTAssertEqual(preview.action, .bind)
        XCTAssertFalse(bookmarks.isScopeActive)
        var metadata = stat()
        XCTAssertEqual(lstat(fixture.root.path, &metadata), 0)
        XCTAssertEqual(metadata.st_mode & mode_t(0o777), 0)
    }

    func testProjectLifecycleDocumentationSetupPreviewsThenPerformsOneAuditedBinding() async throws {
        let fixture = try await makeFixture()
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "p"),
            registrationID: UUID().uuidString.lowercased(),
            requestGeneration: 1
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed lifecycle registration") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('p', ?, 1, 'complete')",
                bindings: [.text(registration.registrationID)]
            )
        }
        let coordinator = ProjectDocumentationSetupCoordinator(
            store: fixture.store,
            bookmarkStore: bookmarks(fixture.root)
        )

        let preview = try await coordinator.preview(registration: registration)
        XCTAssertEqual(preview.registration, registration)
        XCTAssertEqual(preview.rootPath, fixture.root.path)
        XCTAssertEqual(preview.action, .bind)
        let before = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
            )
        }

        let auditID = try await coordinator.perform(preview)

        XCTAssertNotNil(auditID)
        let current = try await coordinator.preview(registration: registration)
        XCTAssertEqual(current.action, .current)
        let after = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarText("SELECT actor_id FROM audit_events WHERE id = ?", bindings: [.text(auditID!.rawValue)])
            )
        }
        XCTAssertEqual(before.0, 0)
        XCTAssertEqual(before.1, 0)
        XCTAssertEqual(after.0, 1)
        XCTAssertEqual(after.1, 1)
        XCTAssertEqual(after.2, "release-radar-owner")
    }

    func testStagedLifecycleBindingPreservesLegacyAuthorityUntilAuditedGuidanceUpgrade() async throws {
        let f = try await makeFixture()
        let ownerInstructions = "# Owner instructions\n\nPreserve this content.\n\n"
        let guidance = f.root.appendingPathComponent("AGENTS.md")
        let staged = Data((ownerInstructions + RepositoryDocumentContract.legacyManagedGuidanceBlock).utf8)
        try staged.write(to: guidance)
        let catalog = try Data(contentsOf: f.root.appendingPathComponent("docs/catalog.json"))
        let registration = ProjectRegistration(projectID: .init(rawValue: "p"), registrationID: UUID().uuidString.lowercased(), requestGeneration: 1)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed lifecycle registration") { c in
            try c.execute("INSERT INTO project_registrations(project_id,registration_id,request_generation,setup_state) VALUES ('p',?,1,'complete')", bindings: [.text(registration.registrationID)])
        }
        let registeredProject = AuthorizedProject(registration: registration, canonicalRoot: f.root, authorizedRoots: [f.root])
        let dispatcher = AgentCommandDispatcher(store: f.store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [registeredProject]), bookmarkStore: bookmarks(f.root))
        func request(_ command: AgentCommand) -> AgentCommandEnvelope {
            .init(version: 1, requestID: UUID(), projectRoot: f.root.path, expectedRegistration: registration,
                  reason: "Authorized lifecycle fixture documentation", command: command)
        }
        let coordinator = ProjectDocumentationSetupCoordinator(store: f.store, bookmarkStore: bookmarks(f.root))
        let initial = await inventory(f.store, f.root)
        let before = try XCTUnwrap(initial)
        let preview = try await coordinator.preview(registration: registration)
        XCTAssertEqual(preview.action, .bind)
        let performed = try await coordinator.perform(preview)
        let audit = try XCTUnwrap(performed)
        let boundResult = await inventory(f.store, f.root)
        let bound = try XCTUnwrap(boundResult)
        XCTAssertTrue(bound.isComplete)
        XCTAssertNotNil(bound.binding)
        XCTAssertEqual(bound.catalog.guidance, .legacy)
        XCTAssertEqual(bound.evidence, before.evidence)
        XCTAssertEqual(bound.roots, before.roots)
        XCTAssertEqual(bound.preservation.filter { $0.key != "project.bindingsV13" }, before.preservation.filter { $0.key != "project.bindingsV13" })
        XCTAssertEqual(bound.audits.count, before.audits.count + 1)
        XCTAssertEqual(bound.receipts.count, before.receipts.count + 1)
        let actor = try await f.store.read { try $0.scalarText("SELECT actor_id FROM audit_events WHERE id=?", bindings: [.text(audit.rawValue)]) }
        XCTAssertEqual(actor, "release-radar-owner")
        XCTAssertEqual(try Data(contentsOf: guidance), staged)
        XCTAssertEqual(try Data(contentsOf: f.root.appendingPathComponent("docs/catalog.json")), catalog)

        for command in [AgentCommand.addManagedEvidence(target: preview.target, id: "managed", ticketID: nil, artifactID: "draft"),
                        .acceptDocumentationCatalog(target: preview.target, priorCatalogVersion: preview.target.catalogVersion, priorCatalogDigest: preview.target.catalogDigest)] {
            let denied = await dispatcher.dispatch(request(command))
            XCTAssertEqual(denied.error, .documentation(.guidanceUnavailable))
        }
        let afterDenied = await inventory(f.store, f.root)
        XCTAssertEqual(afterDenied, bound)

        // Model the separately authorized guidance handoff after owner binding.
        try Data((ownerInstructions + RepositoryDocumentContract.managedGuidanceBlock).utf8).write(to: guidance)
        let handoff = request(.addEvidence(id: "release-radar-handoff:v1:staged", ticketID: nil, path: guidance.path))
        let upgraded = await dispatcher.dispatchDocumentationMaintenance(handoff)
        XCTAssertNil(upgraded.error)
        XCTAssertNotNil(upgraded.auditEventID)
        let replay = await dispatcher.dispatchDocumentationMaintenance(handoff)
        XCTAssertEqual(replay, upgraded)
        let currentResult = await inventory(f.store, f.root)
        let current = try XCTUnwrap(currentResult)
        XCTAssertTrue(current.isComplete)
        XCTAssertEqual(current.catalog.guidance, .managedV3)
        XCTAssertEqual(current.binding, bound.binding)
        XCTAssertEqual(current.evidence.map { $0.evidence.id.rawValue }, ["release-radar-handoff:v1:staged"])
        XCTAssertEqual(try Data(contentsOf: guidance), Data((ownerInstructions + RepositoryDocumentContract.managedGuidanceBlock).utf8))
    }

    func testStagedBindingRejectsMissingModifiedAndMalformedGuidanceWithoutEffects() async throws {
        let legacy = RepositoryDocumentContract.legacyManagedGuidanceBlock
        for contents in [nil, "# Owner instructions\n", legacy.replacingOccurrences(of: "durable", with: "modified"),
                         legacy + "\n" + legacy, "<!-- release-radar-guidance:v1:start -->\n<!-- release-radar-guidance:end -->"] as [String?] {
            let f = try await makeFixture()
            let guidance = f.root.appendingPathComponent("AGENTS.md")
            if let contents { try Data(contents.utf8).write(to: guidance) }
            else { try FileManager.default.removeItem(at: guidance) }
            let before = await inventory(f.store, f.root)
            let result = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
            XCTAssertEqual(result.error, .documentation(.guidanceUnavailable))
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before)
        }
    }

    func testStagedBindingRetainsExactCatalogTargetRollbackAndReplayChecks() async throws {
        let f = try await makeFixture()
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let valid = try target(f.root)
        for invalid in [DocumentationTarget(projectID: valid.projectID, rootID: valid.rootID, repositoryID: UUID().uuidString.lowercased(), catalogVersion: valid.catalogVersion, catalogDigest: valid.catalogDigest),
                        .init(projectID: valid.projectID, rootID: valid.rootID, repositoryID: valid.repositoryID, catalogVersion: valid.catalogVersion, catalogDigest: String(repeating: "a", count: 64))] {
            let before = await inventory(f.store, f.root)
            let rejected = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: invalid)))
            XCTAssertEqual(rejected.error, .documentation(.catalogUnaccepted))
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before)
        }
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Inject staged binding receipt failure") { c in
            try c.execute("CREATE TRIGGER staged_fail_receipt BEFORE INSERT ON agent_command_requests BEGIN SELECT RAISE(ABORT, 'Injected receipt failure'); END")
        }
        let before = await inventory(f.store, f.root)
        let request = envelope(f.root, .bindDocumentationRepository(target: valid))
        let failed = await f.dispatcher.dispatch(request)
        XCTAssertNotNil(failed.error)
        XCTAssertNotEqual(failed.error, .documentation(.guidanceUnavailable))
        let after = await inventory(f.store, f.root)
        XCTAssertEqual(after, before)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Remove fixture receipt failure") { try $0.execute("DROP TRIGGER staged_fail_receipt") }
        let committed = await f.dispatcher.dispatch(request)
        XCTAssertNil(committed.error)
        XCTAssertNotNil(committed.auditEventID)
        let replay = await f.dispatcher.dispatch(request)
        XCTAssertEqual(replay, committed)
    }

    func testDocumentationSetupRejectsGenerationChangedBetweenPreviewAndTransactionalCommit() async throws {
        let fixture = try await makeFixture()
        let registration = ProjectRegistration(
            projectID: .init(rawValue: "p"),
            registrationID: "interleaved-registration",
            requestGeneration: 1
        )
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed interleaved registration") { connection in
            try connection.execute(
                "INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('p', ?, 1, 'complete')",
                bindings: [.text(registration.registrationID)]
            )
        }
        let gate = DocumentationCommitGate()
        let coordinator = ProjectDocumentationSetupCoordinator(
            store: fixture.store,
            bookmarkStore: bookmarks(fixture.root),
            beforeTransactionalDispatch: { await gate.enterAndWait() }
        )
        let preview = try await coordinator.preview(registration: registration)
        let before = try await fixture.store.read { connection in
            try ["project_documentation_bindings", "agent_command_requests", "audit_events"].map {
                try connection.scalarInt("SELECT COUNT(*) FROM \($0)")
            }
        }

        let operation = Task { try await coordinator.perform(preview) }
        await gate.waitUntilEntered()
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Advance registration generation") { connection in
            try connection.execute(
                "UPDATE project_registrations SET request_generation = 2 WHERE project_id = 'p'"
            )
        }
        await gate.release()

        do {
            _ = try await operation.value
            XCTFail("A stale generation must not commit documentation state")
        } catch {
            XCTAssertEqual(error as? ProjectDocumentationSetupError, .command(.documentation(.staleRegistration)))
        }
        let after = try await fixture.store.read { connection in
            try ["project_documentation_bindings", "agent_command_requests", "audit_events"].map {
                try connection.scalarInt("SELECT COUNT(*) FROM \($0)")
            }
        }
        XCTAssertEqual(after[0], before[0])
        XCTAssertEqual(after[1], before[1])
        XCTAssertEqual(after[2], (before[2] ?? 0) + 1, "Only the fixture generation advance is audited")
    }

    func testValidUncataloguedLegacyEvidenceResolvesWithoutConflictOrMutation() async throws {
        let f = try await makeFixture()
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        XCTAssertNil(bound.error)
        let path = f.root.appendingPathComponent("AGENTS.md").path
        let added = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: "handoff", ticketID: nil, path: path)))
        XCTAssertNil(added.error)
        let before = try await f.store.read { c in
            try ["evidence", "audit_events", "agent_command_requests"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") }
        }
        let result = await inventory(f.store, f.root)
        let row = try XCTUnwrap(result?.evidence.first)
        XCTAssertTrue(result?.isComplete == true)
        XCTAssertEqual(row.evidence.locator, .filePath(path))
        XCTAssertEqual(row.resolvedPath, "AGENTS.md")
        XCTAssertTrue(row.resolvedAvailable)
        XCTAssertNil(row.rejection)
        XCTAssertNil(row.candidateArtifactID)
        XCTAssertNil(row.lifecycle)
        XCTAssertNil(row.authority)
        let after = try await f.store.read { c in
            try ["evidence", "audit_events", "agent_command_requests"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") }
        }
        XCTAssertEqual(after, before)
    }

    func testMissingManagedArtifactStillRejectsInventory() async throws {
        let f = try await makeFixture()
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        XCTAssertNil(bound.error)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed missing managed identity") { c in
            try c.execute("INSERT INTO evidence (id, project_id, artifact_id, is_available) VALUES ('missing-managed', 'p', 'absent', 1)")
        }
        let result = await inventory(f.store, f.root)
        let row = try XCTUnwrap(result?.evidence.first)
        XCTAssertFalse(row.resolvedAvailable)
        XCTAssertEqual(row.rejection, .evidenceConflict)
        XCTAssertNil(row.resolvedPath)
    }

    func testLegacyInventoryReadsAuthorizedRootBelowSearchOnlyAncestorWithoutMutation() async throws {
        let f = try await makeFixture(rootPath: "search-only/repository")
        let ancestor = f.root.deletingLastPathComponent()
        let guidance = f.root.appendingPathComponent("AGENTS.md")
        let evidence = f.root.appendingPathComponent("docs/plans/draft.md")
        let guidanceBytes = Data("# Synthetic repository instructions\n".utf8)
        try guidanceBytes.write(to: guidance)
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("docs/catalog.json"))
        let evidenceBytes = try Data(contentsOf: evidence)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed readable legacy evidence") { c in
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('legacy', 'p', ?, 0)", bindings: [.text(evidence.path)])
        }
        let initial = await inventory(f.store, f.root)
        let before = try XCTUnwrap(initial)
        XCTAssertTrue(before.isComplete)
        XCTAssertEqual(before.catalog.guidance, .legacy)
        XCTAssertEqual(before.catalog.validationError, .missingFile)

        XCTAssertEqual(chmod(ancestor.path, 0o100), 0)
        defer { XCTAssertEqual(chmod(ancestor.path, 0o700), 0) }
        let directory = open(ancestor.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        let openError = errno
        if directory >= 0 { close(directory) }
        XCTAssertEqual(directory, -1, "The fixture ancestor must forbid directory reads")
        XCTAssertEqual(openError, EACCES)
        XCTAssertEqual(try Data(contentsOf: guidance), guidanceBytes, "Authorized leaf reads still succeed")
        XCTAssertEqual(try Data(contentsOf: evidence), evidenceBytes)

        let observed = await inventory(f.store, f.root)
        let after = try XCTUnwrap(observed)
        XCTAssertTrue(after.isComplete)
        XCTAssertEqual(after.catalog.guidance, .legacy)
        XCTAssertEqual(after.catalog.validationError, .missingFile)
        XCTAssertEqual(after.evidence.first?.resolvedAvailable, true)
        XCTAssertEqual(after.evidence.first?.evidence.isAvailable, false)
        XCTAssertEqual(after, before, "Repository observation and every stored preservation domain remain unchanged")
    }

    func testGuidanceUpgradeReusesExactLegacyHandoffAndReplaysFreshAudit() async throws {
        let f = try await makeFixture()
        let path = f.root.appendingPathComponent("AGENTS.md").path
        let id = "release-radar-handoff:v1:existing"
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let initial = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: id, ticketID: nil, path: path)))
        XCTAssertNil(initial.error)
        let before = try await f.store.read { c in try ["evidence", "audit_events", "agent_command_requests", "notification_events"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") } }
        let captured = await inventory(f.store, f.root)
        let observed = try XCTUnwrap(captured)
        XCTAssertTrue(observed.isComplete)
        let exact = observed.evidence.filter { $0.evidence.ticketID == nil && $0.evidence.locator == .filePath(path) }
        XCTAssertEqual(exact.map { $0.evidence.id.rawValue }, [id])
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let request = envelope(f.root, .addEvidence(id: exact[0].evidence.id.rawValue, ticketID: nil, path: path))
        let upgraded = await f.dispatcher.dispatchDocumentationMaintenance(request)
        XCTAssertNil(upgraded.error); XCTAssertNotNil(upgraded.auditEventID)
        XCTAssertNotEqual(upgraded.auditEventID, initial.auditEventID)
        let replay = await f.dispatcher.dispatchDocumentationMaintenance(request)
        XCTAssertEqual(replay, upgraded)
        let after = try await f.store.read { c in try ["evidence", "audit_events", "agent_command_requests", "notification_events"].map { try c.scalarInt("SELECT COUNT(*) FROM \($0)") } }
        XCTAssertEqual(after, [before[0], before[1]! + 1, before[2]! + 1, before[3]])
        let row = try await f.store.locatedEvidence(projectID: .init(rawValue: "p"), evidenceID: .init(rawValue: id))
        XCTAssertEqual(row?.locator, .filePath(path)); XCTAssertNil(row?.ticketID)
    }

    func testFiveTypedDocumentationCommandsDecode() throws {
        let target: [String: Any] = ["projectID": "p", "rootID": "root", "repositoryID": "11111111-1111-1111-1111-111111111111", "catalogVersion": 1, "catalogDigest": String(repeating: "a", count: 64)]
        let commands: [[String: Any]] = [
            ["bindDocumentationRepository": ["target": target]],
            ["acceptDocumentationCatalog": ["target": target, "priorCatalogVersion": 1, "priorCatalogDigest": String(repeating: "b", count: 64)]],
            ["addManagedEvidence": ["target": target, "id": "new", "artifactID": "draft"]],
            ["adoptManagedEvidence": ["target": target, "adoptions": [["evidenceID": "e", "expectedPath": "/repo/docs/plans/draft.md", "artifactID": "draft", "expectedTicketID": NSNull()]]]],
            ["relocateLegacyEvidence": ["projectID": "p", "rootID": "root", "evidenceID": "e", "expectedPath": "/old", "newPath": "new.md"]],
        ]
        for command in commands {
            let data = try JSONSerialization.data(withJSONObject: command)
            XCTAssertNoThrow(try JSONDecoder().decode(AgentCommand.self, from: data))
        }
    }

    func testLegacyCommandRejectsCataloguedV2PathWithoutMutation() async throws {
        let fixture = try await makeFixture()
        let before = try await fixture.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let result = await fixture.dispatcher.dispatch(.init(version: 1, requestID: UUID(), projectRoot: fixture.root.path,
            reason: "Catalogued path must use managed creation", command: .addEvidence(id: "bad", ticketID: nil, path: "docs/plans/draft.md")))
        XCTAssertNotNil(result.error)
        let after = try await fixture.store.read { connection in
            [try connection.scalarInt("SELECT COUNT(*) FROM audit_events"), try connection.scalarInt("SELECT COUNT(*) FROM evidence")]
        }
        XCTAssertEqual(after, [before, 0])
    }

    func testInventoryBindAdoptReplayAndRelaunch() async throws {
        let f = try await makeFixture()
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed all evidence") { c in
            try c.execute("INSERT INTO phases (id, project_id, name) VALUES ('inactive', 'p', 'Inactive')")
            try c.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('t', 'p', 'inactive', 'Existing', 'backlog')")
            try c.execute("INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES ('e', 'p', 't', ?, 0)", bindings: [.text(f.root.appendingPathComponent("docs/plans/draft.md").path)])
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('arbitrary', 'p', ?, 1)", bindings: [.text(f.root.appendingPathComponent("arbitrary.md").path)])
        }
        let query = AgentQueryEnvelope(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: nil, rootID: nil))
        let queries = AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root))
        let before = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let unbound = await queries.dispatch(query)
        XCTAssertEqual(unbound.inventory?.projectID, "p")
        XCTAssertEqual(unbound.inventory?.rootID, "root")
        XCTAssertEqual(unbound.inventory?.evidence.count, 2)
        XCTAssertNil(unbound.inventory?.binding)
        XCTAssertEqual(unbound.inventory?.catalog.error, .bindingMissing)
        let after = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(before, after)
        let target = try target(f.root)
        let bind = envelope(f.root, .bindDocumentationRepository(target: target))
        let bound = await f.dispatcher.dispatch(bind)
        XCTAssertNil(bound.error)
        let repeated = await f.dispatcher.dispatch(bind)
        XCTAssertEqual(repeated, bound)
        let inventory = await queries.dispatch(query)
        XCTAssertTrue(inventory.inventory?.isComplete == true)
        XCTAssertEqual(inventory.inventory?.evidence.first(where: { $0.evidence.id.rawValue == "e" })?.candidateArtifactID, "draft")
        let adopt = envelope(f.root, .adoptManagedEvidence(target: target, adoptions: [.init(evidenceID: "e", expectedPath: f.root.appendingPathComponent("docs/plans/draft.md").path, expectedTicketID: "t", artifactID: "draft")]))
        let adopted = await f.dispatcher.dispatch(adopt)
        XCTAssertNil(adopted.error)
        let record = try await f.store.locatedEvidence(projectID: .init(rawValue: "p"), evidenceID: .init(rawValue: "e"))
        XCTAssertEqual(record?.locator, .managedDocument(artifactID: "draft"))
        XCTAssertEqual(record?.ticketID?.rawValue, "t")
        XCTAssertFalse(record!.isAvailable)
        let reopened = DeliveryStore(databaseURL: f.root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
        let replay = await dispatcher(reopened, f.root).dispatch(adopt)
        XCTAssertEqual(replay, adopted)
        let receipts = try await f.store.read { c in try c.row("SELECT request_body FROM agent_command_requests WHERE request_id = ?", bindings: [.text(adopt.requestID.uuidString)]) }
        guard case let .blob(bytes) = receipts?["request_body"] else { return XCTFail("Receipt missing") }
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains(f.root.path))
    }

    func testStaleCatalogAndChangedAssociationRejectAtomicSet() async throws {
        let f = try await makeFixture()
        let target = try target(f.root)
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: target)))
        XCTAssertNil(bound.error)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed") { c in
            for (id, path) in [("a", "docs/plans/draft.md"), ("b", "docs/plans/current.md")] {
                try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text(id), .text(f.root.appendingPathComponent(path).path)])
            }
        }
        let before = await AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root)).dispatch(.init(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: "p", rootID: "root")))
        let bad = await f.dispatcher.dispatch(envelope(f.root, .adoptManagedEvidence(target: target, adoptions: [
            .init(evidenceID: "a", expectedPath: f.root.appendingPathComponent("docs/plans/draft.md").path, expectedTicketID: nil, artifactID: "draft"),
            .init(evidenceID: "b", expectedPath: f.root.appendingPathComponent("docs/plans/current.md").path, expectedTicketID: "changed", artifactID: "current")
        ])))
        XCTAssertNotNil(bad.error)
        let after = await AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root)).dispatch(.init(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: "p", rootID: "root")))
        XCTAssertEqual(after.inventory, before.inventory)
    }

    func testManagedV2ImporterFailsBeforeDeliveryMutationWhenCatalogIsUnavailable() async throws {
        let f = try await makeFixture()
        let delivery = f.root.appendingPathComponent("docs/delivery")
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let seed = #"{"schemaVersion":1,"activePhaseId":"phase","phases":[{"id":"phase","label":"Imported"}],"tasks":[]}"#
        try Data(seed.utf8).write(to: delivery.appendingPathComponent("dashboard-status.json"))
        let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]))
        let before = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        do {
            let preview = try importer.preview(f.root)
            try await importer.apply(preview, to: .init(rawValue: "p"))
            XCTFail("Unavailable managed catalog must reject before import")
        } catch { }
        let after = try await f.store.read { c in [try c.scalarInt("SELECT COUNT(*) FROM audit_events"), try c.scalarInt("SELECT COUNT(*) FROM phases")] }
        XCTAssertEqual(after, [before, 0])
    }

    func testEveryDocumentationMutationReplaysAndRejectsRequestReuseAcrossRelaunch() async throws {
        for kind in 0..<5 {
            let f = try await makeFixture()
            let command = try await preparedCommand(kind, fixture: f)
            let request = envelope(f.root, command)
            let result = await f.dispatcher.dispatch(request)
            XCTAssertNil(result.error, "kind \(kind)")
            let before = await inventory(f.store, f.root)
            let reopened = DeliveryStore(databaseURL: f.root.deletingLastPathComponent().appendingPathComponent("store.sqlite"))
            let replayed = await dispatcher(reopened, f.root).dispatch(request)
            XCTAssertEqual(replayed, result)
            let changed = AgentCommandEnvelope(version: 1, requestID: request.requestID, projectRoot: f.root.path, reason: "Changed request body", command: command)
            let rejected = await dispatcher(reopened, f.root).dispatch(changed)
            XCTAssertEqual(rejected.error, .requestIDReused)
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before)
        }
    }

    func testEveryDocumentationMutationRollsBackAfterLateReceiptFailure() async throws {
        for kind in 0..<5 {
            let f = try await makeFixture()
            let command = try await preparedCommand(kind, fixture: f)
            try await f.store.transact(actor: .init(id: "fixture"), reason: "Inject late receipt failure") { c in
                try c.execute("CREATE TRIGGER m3b_fail_receipt BEFORE INSERT ON agent_command_requests BEGIN SELECT RAISE(ABORT, 'Injected receipt failure'); END")
            }
            let before = await inventory(f.store, f.root)
            let result = await f.dispatcher.dispatch(envelope(f.root, command))
            XCTAssertNotNil(result.error, "kind \(kind)")
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before, "kind \(kind)")
        }
    }

    func testPendingAndInvalidCatalogRetainBindingWithoutResolvingRows() async throws {
        let f = try await makeFixture()
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        _ = await f.dispatcher.dispatch(envelope(f.root, .addManagedEvidence(target: try target(f.root), id: "managed", ticketID: nil, artifactID: "draft")))
        let accepted = await inventory(f.store, f.root)
        try editCatalog(f.root) { catalog in
            var items = catalog["artifacts"] as! [[String: Any]]
            items[3]["lifecycle"] = "active"; catalog["artifacts"] = items
        }
        let pending = await inventory(f.store, f.root)
        XCTAssertEqual(pending?.binding, accepted?.binding)
        XCTAssertEqual(pending?.catalog.error, .catalogUnaccepted)
        XCTAssertNil(pending?.evidence.first?.resolvedPath)
        XCTAssertFalse(pending!.isComplete)
        let target = try target(f.root)
        let stale = await f.dispatcher.dispatch(envelope(f.root, .addManagedEvidence(target: target, id: "blocked", ticketID: nil, artifactID: "current")))
        XCTAssertEqual(stale.error, .documentation(.catalogUnaccepted))
        try Data("{bad".utf8).write(to: f.root.appendingPathComponent("docs/catalog.json"))
        let invalid = await inventory(f.store, f.root)
        XCTAssertEqual(invalid?.binding, accepted?.binding)
        XCTAssertEqual(invalid?.catalog.error, .catalogInvalid)
        XCTAssertNil(invalid?.evidence.first?.resolvedPath)
    }

    func testExactCandidateClassificationRejectsAliasesMissingAndOutsidePaths() async throws {
        let f = try await makeFixture()
        try Data("arbitrary".utf8).write(to: f.root.appendingPathComponent("arbitrary.md"))
        try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("alias.md"), withDestinationURL: f.root.appendingPathComponent("docs/plans/draft.md"))
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed classification") { c in
            for (id, path) in [("exact", "docs/plans/draft.md"), ("arbitrary", "arbitrary.md"), ("missing", "missing.md"), ("alias", "alias.md"), ("basename", "draft.md")] {
                try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text(id), .text(f.root.appendingPathComponent(path).path)])
            }
            try c.execute("INSERT INTO evidence (id, project_id, path) VALUES ('outside', 'p', '/outside/draft.md')")
        }
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        let result = await inventory(f.store, f.root)
        XCTAssertEqual(result?.evidence.count, 6)
        XCTAssertEqual(result?.evidence.filter { $0.candidateArtifactID != nil }.map { $0.evidence.id.rawValue }, ["exact"])
        XCTAssertEqual(result?.evidence.first { $0.evidence.id.rawValue == "alias" }?.rejection, .unsafePath)
        XCTAssertEqual(result?.evidence.first { $0.evidence.id.rawValue == "missing" }?.rejection, .missingFile)
    }

    func testBoundsRejectWholeRequestAndOversizedInventory() async throws {
        let f = try await makeFixture()
        let target = try target(f.root)
        for count in [0, 129] {
            let items = (0..<count).map { DocumentationAdoption(evidenceID: "e\($0)", expectedPath: "x", expectedTicketID: nil, artifactID: "a\($0)") }
            let result = await f.dispatcher.dispatch(envelope(f.root, .adoptManagedEvidence(target: target, adoptions: items)))
            XCTAssertNotNil(result.error)
        }
        let large = (0..<30).map { DocumentationAdoption(evidenceID: "e\($0)", expectedPath: String(repeating: "x", count: 4000), expectedTicketID: nil, artifactID: "a\($0)") }
        let tooManyBytes = await f.dispatcher.dispatch(envelope(f.root, .adoptManagedEvidence(target: target, adoptions: large)))
        XCTAssertNotNil(tooManyBytes.error)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed bounded inventory limit") { c in
            for index in 0..<100 {
                try c.execute("INSERT INTO evidence (id, project_id, path) VALUES (?, 'p', ?)", bindings: [.text("e\(index)"), .text(f.root.path + "/" + String(repeating: "x", count: 1500) + String(index))])
            }
        }
        let query = await AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root)).dispatch(.init(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: nil, rootID: nil)))
        XCTAssertEqual(query.error, .documentation(.inventoryTooLarge))
        XCTAssertNil(query.inventory)
    }

    func testBindingUsesLowercaseUUIDAndRejectsRootAndProjectCollisions() async throws {
        let f = try await makeFixture()
        try editCatalog(f.root) { $0["repositoryID"] = ($0["repositoryID"] as! String).uppercased() }
        let observedInventory = await inventory(f.store, f.root)
        let observed = try XCTUnwrap(observedInventory)
        let t = DocumentationTarget(projectID: observed.projectID, rootID: observed.rootID, repositoryID: try XCTUnwrap(observed.catalog.repositoryID), catalogVersion: try XCTUnwrap(observed.catalog.version), catalogDigest: try XCTUnwrap(observed.catalog.digest))
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
        XCTAssertNil(bound.error)
        let result = await inventory(f.store, f.root)
        XCTAssertEqual(result?.binding?.repositoryID, t.repositoryID)
        XCTAssertTrue(result!.isComplete)
        let other = DocumentationTarget(projectID: "other", rootID: "root", repositoryID: t.repositoryID, catalogVersion: t.catalogVersion, catalogDigest: t.catalogDigest)
        let rejected = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: other)))
        XCTAssertEqual(rejected.error, .documentation(.rootMismatch))
    }

    func testManagedImporterRequiresAcceptedBindingAndClassifiesOnlyExactDocuments() async throws {
        let f = try await makeFixture()
        try prepareImportTree(f.root)
        let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]), bookmarkStore: bookmarks(f.root))
        let preview = try importer.preview(f.root)
        XCTAssertNotNil(preview.documentationCatalogDigest)
        do { try await importer.apply(preview, to: .init(rawValue: "p")); XCTFail("Unbound import must reject") }
        catch { XCTAssertEqual(error as? RekonImportError, .documentation(.bindingMissing)) }
        let empty = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM phases") }
        XCTAssertEqual(empty, 0)
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root))))
        XCTAssertNil(bound.error)
        try await importer.apply(preview, to: .init(rawValue: "p"))
        let rows = try await f.store.read { try $0.rows("SELECT ticket_id, path, artifact_id FROM evidence ORDER BY ticket_id") }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["artifact_id"], .text("draft"))
        XCTAssertEqual(rows[0]["path"], .null)
        XCTAssertEqual(rows[1]["artifact_id"], .null)
        XCTAssertEqual(rows[1]["path"], .text(f.root.appendingPathComponent("arbitrary.md").path))
        let before = await inventory(f.store, f.root)
        try editCatalog(f.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "active"; catalog["artifacts"] = artifacts
        }
        let pendingPreview = try importer.preview(f.root)
        do { try await importer.apply(pendingPreview, to: .init(rawValue: "p")); XCTFail("Pending import must reject") }
        catch { XCTAssertEqual(error as? RekonImportError, .documentation(.catalogUnaccepted)) }
        let after = await inventory(f.store, f.root)
        XCTAssertEqual(after?.preservation, before?.preservation)
        XCTAssertEqual(after?.audits, before?.audits)
    }

    func testStagedV1ImporterRetainsLegacyIdentityAndLegacyArbitraryCommandIsCompatible() async throws {
        let f = try await makeFixture()
        try prepareImportTree(f.root)
        try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]))
        let preview = try importer.preview(f.root)
        XCTAssertNil(preview.documentationCatalogDigest)
        try await importer.apply(preview, to: .init(rawValue: "p"))
        let managed = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM evidence WHERE artifact_id IS NOT NULL") }
        XCTAssertEqual(managed, 0)
        let arbitrary = f.root.appendingPathComponent("other%file.md")
        try Data("arbitrary".utf8).write(to: arbitrary)
        let result = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: "other", ticketID: nil, path: arbitrary.path)))
        XCTAssertNil(result.error)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
        let underV2 = await f.dispatcher.dispatch(envelope(f.root, .addEvidence(id: "other", ticketID: nil, path: arbitrary.path)))
        XCTAssertNil(underV2.error)
    }

    func testGuidanceDeclarationRejectsMalformedUnknownAndDuplicateMarkers() {
        let prefix = RepositoryDocumentContract.guidanceStartPrefix
        let suffix = RepositoryDocumentContract.guidanceStartSuffix
        let end = RepositoryDocumentContract.guidanceEndMarker
        XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: nil), .legacy)
        XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: RepositoryDocumentContract.legacyManagedGuidanceBlock), .legacy)
        for contents in ["\(prefix)3\(suffix)\n\(end)", "\(prefix)2\(suffix)", "\(prefix)2\(suffix)\n\(end)\n\(end)", " \(prefix)2\(suffix)\n\(end)"] {
            XCTAssertEqual(RepositoryDocumentationMode.inspect(contents: contents), .unavailable)
        }
    }

    func testCatalogAcceptanceRejectsStalePriorAndIllegalLifecycleWithoutEffects() async throws {
        let f = try await makeFixture()
        let accepted = try target(f.root)
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: accepted)))
        try editCatalog(f.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "archived"; artifacts[3]["authorityLevel"] = "nonAuthoritative"; catalog["artifacts"] = artifacts
        }
        // Remove an active prose link to the now historical fixture artifact.
        try Data("# Current\n".utf8).write(to: f.root.appendingPathComponent("docs/plans/current.md"))
        let candidate = try target(f.root)
        let before = await inventory(f.store, f.root)
        let illegal = await f.dispatcher.dispatch(envelope(f.root, .acceptDocumentationCatalog(target: candidate, priorCatalogVersion: 1, priorCatalogDigest: accepted.catalogDigest)))
        XCTAssertEqual(illegal.error, .documentation(.invalidTransition))
        XCTAssertEqual(illegal.documentationCatalogTransition?.validationError, .invalidTransition)
        XCTAssertEqual(illegal.documentationCatalogTransition?.artifactID, "draft")
        XCTAssertEqual(illegal.documentationCatalogTransition?.artifactPath, "docs/plans/draft.md")
        let stale = await f.dispatcher.dispatch(envelope(f.root, .acceptDocumentationCatalog(target: candidate, priorCatalogVersion: 1, priorCatalogDigest: String(repeating: "0", count: 64))))
        XCTAssertEqual(stale.error, .documentation(.catalogUnaccepted))
        let after = await inventory(f.store, f.root)
        XCTAssertEqual(after, before)
    }

    func testCatalogAcceptancePreservesRepositoryBindingMismatchWithoutEffects() async throws {
        let f = try await makeFixture()
        let accepted = try target(f.root)
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: accepted)))
        try editCatalog(f.root) { catalog in
            catalog["repositoryID"] = "22222222-2222-4222-8222-222222222222"
        }
        let candidate = try target(f.root)
        let before = await inventory(f.store, f.root)

        let result = await f.dispatcher.dispatch(envelope(
            f.root,
            .acceptDocumentationCatalog(
                target: candidate,
                priorCatalogVersion: accepted.catalogVersion,
                priorCatalogDigest: accepted.catalogDigest
            )
        ))

        XCTAssertEqual(result.error, .documentation(.bindingMismatch))
        XCTAssertNil(result.documentationCatalogTransition)
        let after = await inventory(f.store, f.root)
        XCTAssertEqual(after, before)
    }

    func testCatalogTransitionDiagnosticIsAuthorizedReadOnlyBoundedAndReportsValidAndInvalidTransitions() async throws {
        let f = try await makeFixture()
        let accepted = try target(f.root)
        let binding = await f.dispatcher.dispatch(
            envelope(f.root, .bindDocumentationRepository(target: accepted))
        )
        XCTAssertNil(binding.error)
        let before = try await f.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarText("SELECT accepted_catalog_digest FROM project_documentation_bindings WHERE project_id='p'")
            )
        }
        try editCatalog(f.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "active"
            catalog["artifacts"] = artifacts
        }
        let queries = AgentQueryDispatcher(store: f.store, bookmarkStore: bookmarks(f.root))
        let valid = await queries.dispatch(.init(
            version: 1,
            projectRoot: f.root.path,
            query: .documentationCatalogTransition(projectID: "p", rootID: "root")
        ))
        XCTAssertNil(valid.error)
        XCTAssertEqual(valid.documentationCatalogTransition?.isValid, true)
        XCTAssertEqual(valid.documentationCatalogTransition?.acceptedCatalogDigest, accepted.catalogDigest)
        XCTAssertNil(valid.documentationCatalogTransition?.validationError)

        try editCatalog(f.root) { catalog in
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts[3]["lifecycle"] = "archived"
            artifacts[3]["authorityLevel"] = "nonAuthoritative"
            catalog["artifacts"] = artifacts
        }
        try Data("# Current\n".utf8).write(to: f.root.appendingPathComponent("docs/plans/current.md"))
        let invalid = await queries.dispatch(.init(
            version: 1,
            projectRoot: f.root.path,
            query: .documentationCatalogTransition(projectID: "p", rootID: "root")
        ))
        XCTAssertNil(invalid.error)
        XCTAssertEqual(invalid.documentationCatalogTransition?.isValid, false)
        XCTAssertEqual(invalid.documentationCatalogTransition?.validationError, .invalidTransition)
        XCTAssertEqual(invalid.documentationCatalogTransition?.artifactID, "draft")
        XCTAssertEqual(invalid.documentationCatalogTransition?.artifactPath, "docs/plans/draft.md")
        XCTAssertEqual(invalid.documentationCatalogTransition?.candidateCatalogDigest, try target(f.root).catalogDigest)

        try editCatalog(f.root) { catalog in
            catalog["repositoryID"] = "22222222-2222-4222-8222-222222222222"
        }
        let changedIdentity = await queries.dispatch(.init(
            version: 1,
            projectRoot: f.root.path,
            query: .documentationCatalogTransition(projectID: "p", rootID: "root")
        ))
        XCTAssertNil(changedIdentity.error)
        XCTAssertEqual(changedIdentity.documentationCatalogTransition?.isValid, false)
        XCTAssertEqual(changedIdentity.documentationCatalogTransition?.validationError, .repositoryIdentityChanged)
        XCTAssertNil(changedIdentity.documentationCatalogTransition?.artifactID)
        XCTAssertNil(changedIdentity.documentationCatalogTransition?.artifactPath)

        let wrongRoot = await queries.dispatch(.init(
            version: 1,
            projectRoot: f.root.path,
            query: .documentationCatalogTransition(projectID: "p", rootID: "other-root")
        ))
        XCTAssertEqual(wrongRoot.error, .documentation(.rootMismatch))
        XCTAssertNil(wrongRoot.documentationCatalogTransition)

        try Data("{".utf8).write(to: f.root.appendingPathComponent("docs/catalog.json"))
        let malformed = await queries.dispatch(.init(
            version: 1,
            projectRoot: f.root.path,
            query: .documentationCatalogTransition(projectID: "p", rootID: "root")
        ))
        XCTAssertEqual(malformed.error, .documentation(.catalogInvalid))
        XCTAssertNil(malformed.documentationCatalogTransition)

        let after = try await f.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests"),
                try connection.scalarText("SELECT accepted_catalog_digest FROM project_documentation_bindings WHERE project_id='p'")
            )
        }
        XCTAssertEqual(after.0, before.0)
        XCTAssertEqual(after.1, before.1)
        XCTAssertEqual(after.2, before.2)
    }

    func testAuthorizationFailuresAndCrossProjectRepositoryCollisionAreZeroEffect() async throws {
        let f = try await makeFixture()
        let t = try target(f.root)
        for stale in [false, true] {
            let denied = ProjectBookmarkStore(resolver: { _ in .init(url: f.root, isStale: stale) }, startAccessing: { _ in stale }, stopAccessing: { _ in })
            let badDispatcher = AgentCommandDispatcher(store: f.store, projectRegistry: PersistedAuthorizedProjectRegistry(store: f.store), bookmarkStore: denied)
            let result = await badDispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
            XCTAssertEqual(result.error, .documentation(stale ? .staleRoot : .rootUnavailable))
        }
        _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
        let other = f.root.deletingLastPathComponent().appendingPathComponent("other")
        try FileManager.default.copyItem(at: f.root, to: other)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Second authorized project") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('other', 'Other')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('other-root', 'other', ?)", bindings: [.text(other.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('other', ?, ?)", bindings: [.text(other.path), .blob(Data([1]))])
        }
        let second = AgentCommandDispatcher(store: f.store, projectRegistry: PersistedAuthorizedProjectRegistry(store: f.store), bookmarkStore: bookmarks(other))
        let collision = DocumentationTarget(projectID: "other", rootID: "other-root", repositoryID: t.repositoryID, catalogVersion: t.catalogVersion, catalogDigest: t.catalogDigest)
        let result = await second.dispatch(envelope(other, .bindDocumentationRepository(target: collision)))
        XCTAssertEqual(result.error, .documentation(.bindingConflict))
        let count = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings") }
        XCTAssertEqual(count, 1)
    }

    func testManagedEvidenceCannotRelocateAndReplayDoesNotConsumeLaterCatalog() async throws {
        let f = try await makeFixture()
        let t = try target(f.root)
        let bindRequest = envelope(f.root, .bindDocumentationRepository(target: t))
        let bound = await f.dispatcher.dispatch(bindRequest)
        let created = await f.dispatcher.dispatch(envelope(f.root, .addManagedEvidence(target: t, id: "managed", ticketID: nil, artifactID: "draft")))
        XCTAssertNil(created.error)
        try Data("arbitrary".utf8).write(to: f.root.appendingPathComponent("arbitrary.md"))
        let relocated = await f.dispatcher.dispatch(envelope(f.root, .relocateLegacyEvidence(projectID: "p", rootID: "root", evidenceID: "managed", expectedPath: f.root.appendingPathComponent("docs/plans/draft.md").path, newPath: "arbitrary.md")))
        XCTAssertEqual(relocated.error, .documentation(.staleEvidence))
        try Data("bad catalog".utf8).write(to: f.root.appendingPathComponent("docs/catalog.json"))
        let replay = await f.dispatcher.dispatch(bindRequest)
        XCTAssertEqual(replay, bound)
    }

    func testSavedV1PreviewRejectsAfterV2ActivationForUnboundAcceptedAndPendingRoots() async throws {
        for state in ["unbound", "accepted", "pending"] {
            let f = try await makeFixture()
            try prepareImportTree(f.root)
            try Data(RepositoryDocumentContract.legacyManagedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
            let importer = RekonArtifactImporter(store: f.store, project: .init(projectID: .init(rawValue: "p"), canonicalRoot: f.root, authorizedRoots: [f.root]), bookmarkStore: bookmarks(f.root))
            let v1 = try importer.preview(f.root)
            XCTAssertNil(v1.documentationCatalogDigest)
            try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: f.root.appendingPathComponent("AGENTS.md"))
            if state != "unbound" { _ = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: try target(f.root)))) }
            if state == "pending" {
                try editCatalog(f.root) { catalog in
                    var artifacts = catalog["artifacts"] as! [[String: Any]]
                    artifacts[3]["lifecycle"] = "active"; catalog["artifacts"] = artifacts
                }
            }
            let before = await inventory(f.store, f.root)
            do { try await importer.apply(v1, to: .init(rawValue: "p")); XCTFail("Saved v1 preview applied under v2 \(state)") }
            catch { XCTAssertEqual(error as? RekonImportError, .malformedArtifact) }
            let after = await inventory(f.store, f.root)
            XCTAssertEqual(after, before, state)
        }
    }

    func testPreservationIncludesUnattributedHistoricalNotifications() async throws {
        let f = try await makeFixture()
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed historical notification") { c in
            try c.execute("INSERT INTO notification_events (id, fingerprint, state, project_id) VALUES ('historical', 'historical', 'sent', NULL)")
        }
        let before = await inventory(f.store, f.root)
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Change historical notification") { c in
            try c.execute("UPDATE notification_events SET state = 'unknown' WHERE id = 'historical'")
        }
        let after = await inventory(f.store, f.root)
        XCTAssertNotEqual(after?.preservation["other.deliveryV10"], before?.preservation["other.deliveryV10"])
        XCTAssertEqual(after?.preservation["project.deliveryV10"], before?.preservation["project.deliveryV10"])
    }

    private func prepareImportTree(_ root: URL) throws {
        let delivery = root.appendingPathComponent("docs/delivery")
        try FileManager.default.createDirectory(at: delivery, withIntermediateDirectories: true)
        let seed = #"{"schemaVersion":1,"activePhaseId":"phase","phases":[{"id":"phase","label":"Imported"}],"tasks":[{"id":"t1","title":"Managed","phaseId":"phase","status":"backlog","evidence":{"href":"../../plans/draft.md"}},{"id":"t2","title":"Arbitrary","phaseId":"phase","status":"backlog","evidence":{"href":"../../../arbitrary.md"}}]}"#
        try Data(seed.utf8).write(to: delivery.appendingPathComponent("dashboard-status.json"))
        try Data("arbitrary".utf8).write(to: root.appendingPathComponent("arbitrary.md"))
        try editCatalog(root) { catalog in
            var collections = catalog["collections"] as! [[String: Any]]
            collections.append(["collectionID": "delivery", "path": "docs/delivery", "parentCollection": "docs", "purpose": "Delivery", "allowedContents": ["seed"], "prohibitedContents": ["temp"], "firstRead": "seed", "isLeaf": true])
            catalog["collections"] = collections
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            artifacts.append(["artifactID": "seed", "path": "docs/delivery/dashboard-status.json", "kind": "document", "lifecycle": "active", "authorityLevel": "supporting", "parentCollection": "delivery", "supersedes": [], "applicationSensitivity": ["importer"], "checksum": ["policy": "notApplicable"]])
            catalog["artifacts"] = artifacts
        }
        _ = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
    }

    private func inventory(_ store: DeliveryStore, _ root: URL) async -> EvidenceInventory? {
        await AgentQueryDispatcher(store: store, bookmarkStore: bookmarks(root)).dispatch(.init(version: 1, projectRoot: root.path, query: .inventoryEvidence(projectID: nil, rootID: nil))).inventory
    }
    private func preparedCommand(_ kind: Int, fixture f: (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher)) async throws -> AgentCommand {
        let t = try target(f.root)
        if kind == 0 { return .bindDocumentationRepository(target: t) }
        let bound = await f.dispatcher.dispatch(envelope(f.root, .bindDocumentationRepository(target: t)))
        XCTAssertNil(bound.error)
        if kind == 1 {
            try editCatalog(f.root) { catalog in
                var items = catalog["artifacts"] as! [[String: Any]]
                items[3]["lifecycle"] = "active"; catalog["artifacts"] = items
            }
            return .acceptDocumentationCatalog(target: try target(f.root), priorCatalogVersion: t.catalogVersion, priorCatalogDigest: t.catalogDigest)
        }
        if kind == 2 { return .addManagedEvidence(target: t, id: "new", ticketID: nil, artifactID: "draft") }
        let old = f.root.appendingPathComponent("docs/plans/draft.md").path
        try await f.store.transact(actor: .init(id: "fixture"), reason: "Seed exact evidence") { c in
            try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES ('e', 'p', ?, 0)", bindings: [.text(old)])
        }
        if kind == 3 { return .adoptManagedEvidence(target: t, adoptions: [.init(evidenceID: "e", expectedPath: old, expectedTicketID: nil, artifactID: "draft")]) }
        try Data("arbitrary".utf8).write(to: f.root.appendingPathComponent("arbitrary.md"))
        return .relocateLegacyEvidence(projectID: "p", rootID: "root", evidenceID: "e", expectedPath: old, newPath: "arbitrary.md")
    }
    private func editCatalog(_ root: URL, mutate: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("docs/catalog.json")
        var catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutate(&catalog)
        try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys]).write(to: url)
    }

    private func target(_ root: URL) throws -> DocumentationTarget {
        let s = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        return .init(projectID: "p", rootID: "root", repositoryID: s.catalog.repositoryID.lowercased(), catalogVersion: s.version, catalogDigest: s.digest)
    }
    private func envelope(_ root: URL, _ command: AgentCommand, requestID: UUID = UUID()) -> AgentCommandEnvelope {
        .init(version: 1, requestID: requestID, projectRoot: root.path, reason: "Approved documentation operation", command: command)
    }
    private func bookmarks(_ root: URL) -> ProjectBookmarkStore {
        ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: false) }, startAccessing: { _ in true }, stopAccessing: { _ in })
    }
    private func dispatcher(_ store: DeliveryStore, _ root: URL) -> AgentCommandDispatcher {
        AgentCommandDispatcher(store: store, projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [.init(projectID: .init(rawValue: "p"), canonicalRoot: root, authorizedRoots: [root])]), bookmarkStore: bookmarks(root))
    }

    private func makeFixture(rootPath: String = "repository") async throws -> (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher) {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".release-radar-managed-docs-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent(rootPath)
        try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        let block = RepositoryDocumentContract.managedGuidanceBlock
        try Data(block.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed authorized project") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(root.path), .blob(Data([1]))])
        }
        let registry = InMemoryAuthorizedProjectRegistry(projects: [.init(projectID: .init(rawValue: "p"), canonicalRoot: root, authorizedRoots: [root])])
        return (store, root, AgentCommandDispatcher(store: store, projectRegistry: registry, bookmarkStore: bookmarks(root)))
    }
}

private final class ScopeGatedBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
    private let root: URL
    private let lock = NSLock()
    private var active = false

    init(root: URL) { self.root = root }

    var isScopeActive: Bool { lock.withLock { active } }

    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }

    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: root, isStale: false)
    }

    func withSecurityScopedAccess<T: Sendable>(
        bookmark: Data,
        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
    ) async throws -> T {
        XCTAssertEqual(chmod(root.path, 0o700), 0)
        lock.withLock { active = true }
        defer {
            lock.withLock { active = false }
            XCTAssertEqual(chmod(root.path, 0), 0)
        }
        return try await body(.init(url: root, isStale: false))
    }
}

private actor DocumentationCommitGate {
    private var entered = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func enterAndWait() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func release() {
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}
