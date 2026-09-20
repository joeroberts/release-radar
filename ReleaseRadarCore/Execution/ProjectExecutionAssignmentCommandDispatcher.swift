import Foundation

struct ProjectExecutionAssignmentCommandDispatcher: Sendable {
    let store: DeliveryStore
    let bookmarkStore: any ProjectBookmarkStoring
    let preparer: any ProjectExecutionAssignmentPreparing

    func dispatch(_ envelope: AgentCommandEnvelope, project: AuthorizedProject, origin: AgentCommandOrigin,
                  admissionDeadline: TimeInterval?) async -> AgentCommandResult {
        do {
            guard case let .prepareExecutionAssignment(projectID, ticketID, taskID, taskRevision, phaseRevision, review, baseline) = envelope.command,
                  projectID == project.projectID.rawValue, let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
            let context = try await store.documentationRead {
                try DocumentationRootContext.read($0, path: envelope.projectRoot, projectID: projectID, schemaVersion: Int(StoreMigrations.currentVersion))
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let body = try encoder.encode(envelope)
            let actor: DeliveryActor = origin == .ownerApp ? .init(id: "release-radar-owner")
                : .init(id: "release-radar-agent", threadID: envelope.assertedThreadID,
                        threadAttribution: envelope.assertedThreadID == nil ? .none : .asserted)
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: context.bookmark) { resolved in
                try context.verifyAuthorization(resolved)
                let catalog = try DocumentationCatalogContext(root: resolved.url)
                let snapshot = try catalog.managedSnapshot(); try context.requireAccepted(snapshot)
                let paths = Array(Set([RepositoryDocumentContract.guidancePath, RepositoryDocumentContract.progressPath] + snapshot.catalog.artifacts.filter {
                    $0.lifecycle == .active && $0.authorityLevel == .controlling && $0.kind == .document
                        && !$0.path.hasPrefix(RepositoryDocumentContract.archiveCollectionPath + "/")
                }.map(\.path))).sorted()
                let capture: (ProjectExecutionWork?, AgentCommandResult?) = try await store.documentationRead { c in
                    try ProjectLifecycleManager.requireCurrentAuthorization(projectID: project.projectID, registration: registration, connection: c)
                    try context.verifyPersisted(c)
                    let prior = try replay(c, envelope: envelope, body: body, registration: registration)
                    if prior?.error != nil, prior?.error != .outcomeUnknown { return (nil, prior) }
                    let work = try ProjectExecutionWork.read(projectID: project.projectID, ticketID: ticketID, taskID: taskID,
                        taskPlanRevision: taskRevision, phaseRevision: phaseRevision, connection: c)
                    return (work, prior)
                }
                if var prior = capture.1, prior.error != .outcomeUnknown {
                    if let diagnostic = prior.preparationDiagnostic {
                        prior.preparationDiagnostic = .init(
                            kind: diagnostic.kind,
                            stage: diagnostic.stage,
                            blockingRequestID: diagnostic.blockingRequestID,
                            blockingAssignmentID: diagnostic.blockingAssignmentID,
                            evidence: .recordedFailure
                        )
                    }
                    if prior.error == nil, let priorAssignment = prior.executionAssignment {
                        prior.executionAssignment = try await preparer.readCurrent(project: project, assignmentID: priorAssignment.id)
                    }
                    return prior
                }
                guard let work = capture.0 else { throw ProjectExecutionError.assignmentNotAuthorized }
                let intent = AgentCommandResult(entityIDs: [ticketID, taskID], auditEventID: nil, error: .outcomeUnknown)
                try await store.transact(actor: actor, reason: "Prepare registered project execution assignment",
                    auditScope: .init(projectID: project.projectID, entityType: .ticketTaskPlan, entityID: ticketID)) { c in
                    try checkDeadline(admissionDeadline)
                    try ProjectLifecycleManager.requireCurrentAuthorization(projectID: project.projectID, registration: registration, connection: c)
                    try context.verifyPersisted(c)
                    guard try ProjectExecutionWork.read(projectID: project.projectID, ticketID: ticketID, taskID: taskID,
                        taskPlanRevision: taskRevision, phaseRevision: phaseRevision, connection: c) == work else { throw ProjectExecutionError.assignmentNotAuthorized }
                    if try replay(c, envelope: envelope, body: body, registration: registration) != nil { return }
                    // A different request cannot replace an uncertain preparation of
                    // this work. Resume its exact request and read back its effects.
                    for row in try c.rows("SELECT request_id,request_body,result_data,registration_project_id,registration_id,request_generation FROM agent_command_requests WHERE registration_project_id=? AND CAST(request_body AS TEXT) LIKE ?", bindings: [.text(projectID), .text("%prepareExecutionAssignment%")], maximum: 10000) {
                        guard ProjectLifecycleManager.receiptScopeMatches(row, registration: registration),
                              case let .blob(bytes)? = row["request_body"],
                              let priorEnvelope = try? JSONDecoder().decode(AgentCommandEnvelope.self, from: bytes),
                              case let .prepareExecutionAssignment(priorProject, priorTicket, priorTask, priorTaskRevision, priorPhaseRevision, priorReview, _) = priorEnvelope.command,
                              priorTicket == ticketID, priorTask == taskID, (priorReview == nil) == (review == nil),
                              case let .blob(resultBytes)? = row["result_data"],
                              let result = try? JSONDecoder().decode(AgentCommandResult.self, from: resultBytes) else { continue }
                        if result.error == .outcomeUnknown {
                            let safelyScoped = row["request_id"] == .text(priorEnvelope.requestID.uuidString)
                                && priorEnvelope.projectRoot == envelope.projectRoot
                                && priorEnvelope.expectedRegistration == registration
                                && priorProject == projectID
                                && priorTaskRevision == taskRevision
                                && priorPhaseRevision == phaseRevision
                            throw ProjectExecutionPreparationConflict(diagnostic: .init(
                                kind: safelyScoped ? .pendingPreparationRequest : .causeUnavailable,
                                blockingRequestID: safelyScoped ? priorEnvelope.requestID : nil,
                                blockingAssignmentID: nil,
                                evidence: .observedAtFailure
                            ))
                        }
                    }
                    try c.execute("INSERT INTO agent_command_requests (request_id,request_body,result_data,created_at,registration_project_id,registration_id,request_generation) VALUES (?,?,?,?,?,?,?)",
                        bindings: [.text(envelope.requestID.uuidString), .blob(body), .blob(try JSONEncoder().encode(intent)), .text(ISO8601DateFormatter().string(from: Date()))] + ProjectLifecycleManager.receiptScopeBindings(registration))
                }
                let assignment: ProjectExecutionAssignment
                do {
                    assignment = try await preparer.prepare(project: project, work: work, requestID: envelope.requestID,
                        reviewOfAssignmentID: review, baselineFromAssignmentID: baseline, contextPaths: paths)
                } catch let failure as ProjectExecutionPreparationFailure {
                    do {
                        guard try await preparer.verifyNoPreparationEffects(project: project, work: work,
                            requestID: envelope.requestID, reviewOfAssignmentID: review,
                            baselineFromAssignmentID: baseline) else { throw failure.error }
                        let auditID = AuditEventID(rawValue: UUID().uuidString)
                        let terminal = AgentCommandResult(entityIDs: [ticketID, taskID], auditEventID: auditID,
                            error: .execution(failure.error))
                        let result = try await store.transact(actor: actor,
                            reason: "Project execution preparation refused without effects", auditEventID: auditID,
                            auditScope: .init(projectID: project.projectID, entityType: .ticketTaskPlan, entityID: ticketID)) { c in
                                try checkDeadline(admissionDeadline)
                                try ProjectLifecycleManager.requireCurrentAuthorization(projectID: project.projectID,
                                    registration: registration, connection: c)
                                try context.verifyPersisted(c)
                                guard try ProjectExecutionWork.read(projectID: project.projectID, ticketID: ticketID,
                                    taskID: taskID, taskPlanRevision: taskRevision, phaseRevision: phaseRevision,
                                    connection: c) == work,
                                      let row = try c.row("SELECT request_body,result_data,registration_project_id,registration_id,request_generation FROM agent_command_requests WHERE request_id=?",
                                        bindings: [.text(envelope.requestID.uuidString)]),
                                      ProjectLifecycleManager.receiptScopeMatches(row, registration: registration),
                                      row["request_body"] == .blob(body),
                                      case let .blob(pendingBytes)? = row["result_data"],
                                      let pending = try? JSONDecoder().decode(AgentCommandResult.self, from: pendingBytes),
                                      pending.error == .outcomeUnknown else { throw ProjectExecutionError.assignmentNotAuthorized }
                                try c.execute("UPDATE agent_command_requests SET result_data=? WHERE request_id=? AND request_body=? AND registration_project_id=? AND registration_id=? AND request_generation=? AND result_data=?",
                                    bindings: [.blob(try JSONEncoder().encode(terminal)), .text(envelope.requestID.uuidString), .blob(body)]
                                        + ProjectLifecycleManager.receiptScopeBindings(registration) + [.blob(pendingBytes)])
                                guard try c.scalarInt("SELECT changes()") == 1 else { throw ProjectExecutionError.assignmentNotAuthorized }
                                return terminal
                            }
                        await preparer.finishPreparation(work: work, requestID: envelope.requestID)
                        return result
                    } catch {
                        await preparer.finishPreparation(work: work, requestID: envelope.requestID)
                        throw error
                    }
                }
                let auditID = AuditEventID(rawValue: UUID().uuidString)
                do {
                    let result = try await store.transact(actor: actor, reason: "Project execution assignment prepared",
                    auditEventID: auditID, auditScope: .init(projectID: project.projectID, entityType: .ticketTaskPlan, entityID: ticketID)) { c in
                    try checkDeadline(admissionDeadline)
                    try ProjectLifecycleManager.requireCurrentAuthorization(projectID: project.projectID, registration: registration, connection: c)
                    try context.verifyPersisted(c)
                    guard try ProjectExecutionWork.read(projectID: project.projectID, ticketID: ticketID, taskID: taskID,
                        taskPlanRevision: taskRevision, phaseRevision: phaseRevision, connection: c) == work,
                          try replay(c, envelope: envelope, body: body, registration: registration)?.error == .outcomeUnknown else { throw ProjectExecutionError.assignmentNotAuthorized }
                    let admitted = try preparer.admitPrepared(assignment)
                    var completed = AgentCommandResult(entityIDs: [projectID, admitted.id], auditEventID: auditID, error: nil)
                    completed.executionAssignment = admitted
                    try c.execute("UPDATE agent_command_requests SET result_data=? WHERE request_id=? AND request_body=?",
                        bindings: [.blob(try JSONEncoder().encode(completed)), .text(envelope.requestID.uuidString), .blob(body)])
                    return completed
                    }
                    await preparer.finishPreparation(work: work, requestID: envelope.requestID)
                    return result
                } catch {
                    let failure = error
                    do { try preparer.revokePreparation(assignment) }
                    catch {
                        await preparer.finishPreparation(work: work, requestID: envelope.requestID)
                        throw StoreError.unavailable("Execution finalization failed: \(failure.localizedDescription). Protected revocation failed: \(error.localizedDescription). Do not launch; recover the exact request.")
                    }
                    await preparer.finishPreparation(work: work, requestID: envelope.requestID)
                    throw failure
                }
            }
        } catch Control.reused { return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused) }
        catch let conflict as ProjectExecutionPreparationConflict {
            return .init(entityIDs: [], auditEventID: nil, error: .execution(.conflict), preparationDiagnostic: conflict.diagnostic)
        }
        catch let error as ProjectExecutionError {
            return .init(entityIDs: [], auditEventID: nil, error: .execution(error),
                preparationDiagnostic: error == .conflict ? .init(
                    kind: .causeUnavailable, blockingRequestID: nil, blockingAssignmentID: nil,
                    evidence: .observedAtFailure
                ) : nil)
        }
        catch let error as DocumentationOperationError { return .init(entityIDs: [], auditEventID: nil, error: .documentation(error)) }
        catch { return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription)) }
    }

    private func checkDeadline(_ deadline: TimeInterval?) throws {
        if let deadline, deadline <= Date().timeIntervalSince1970 { throw ProjectExecutionError.unavailable }
    }
    private func replay(_ c: SQLiteConnection, envelope: AgentCommandEnvelope, body: Data, registration: ProjectRegistration) throws -> AgentCommandResult? {
        guard let row = try c.row("SELECT request_body,result_data,registration_project_id,registration_id,request_generation FROM agent_command_requests WHERE request_id=?", bindings: [.text(envelope.requestID.uuidString)]) else { return nil }
        guard ProjectLifecycleManager.receiptScopeMatches(row, registration: registration), row["request_body"] == .blob(body),
              case let .blob(bytes)? = row["result_data"], let result = try? JSONDecoder().decode(AgentCommandResult.self, from: bytes) else { throw Control.reused }
        return result
    }
    private enum Control: Error { case reused }
}
