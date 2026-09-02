import Foundation

public enum AgentCommandOrigin: Sendable {
    case externalAgent
    case ownerApp
}

public actor AgentCommandDispatcher {
    public static let commandEnvelopeVersion = 1

    private let store: DeliveryStore
    private let projectRegistry: any AuthorizedProjectRegistry
    private let bookmarkStore: any ProjectBookmarkStoring

    public init(store: DeliveryStore, projectRegistry: any AuthorizedProjectRegistry, bookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore()) {
        self.store = store
        self.projectRegistry = projectRegistry
        self.bookmarkStore = bookmarkStore
    }

    /// Fixed maintenance admits documentation operations and the existing exact
    /// root-guidance handoff only; ordinary delivery commands have no route here.
    public func dispatchDocumentationMaintenance(_ envelope: AgentCommandEnvelope, admissionDeadline: TimeInterval? = nil) async -> AgentCommandResult {
        if envelope.command.isDocumentationMutation { return await dispatch(envelope, admissionDeadline: admissionDeadline) }
        guard case let .addEvidence(id, ticket, path) = envelope.command,
              ticket == nil, id.hasPrefix(RepositoryDocumentContract.handoffEvidenceIDPrefix),
              id.count > RepositoryDocumentContract.handoffEvidenceIDPrefix.count,
              path == URL(fileURLWithPath: envelope.projectRoot).appendingPathComponent(RepositoryDocumentContract.guidancePath).path else {
            return .init(entityIDs: [], auditEventID: nil, error: .documentation(.invalidRequest))
        }
        do {
            let context = try await store.documentationRead { try DocumentationRootContext.read($0, path: envelope.projectRoot) }
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: context.bookmark) { resolved in
                try context.verifyAuthorization(resolved)
                let reader = try RepositoryDocumentReader(rootURL: resolved.url, limits: .init(), afterRead: nil)
                _ = try reader.read(RepositoryDocumentContract.guidancePath)
                try reader.verifyStable()
                return await self.dispatch(envelope, admissionDeadline: admissionDeadline)
            }
        } catch { return .init(entityIDs: [], auditEventID: nil, error: .documentation(DocumentationCatalogContext.map(error))) }
    }

    public func dispatch(
        _ envelope: AgentCommandEnvelope,
        origin: AgentCommandOrigin = .externalAgent,
        admissionDeadline: TimeInterval? = nil
    ) async -> AgentCommandResult {
        if let error = validate(envelope) {
            return .init(entityIDs: [], auditEventID: nil, error: error)
        }
        // Owner acceptance must be authorized before consulting durable receipts.
        if case .transitionDeliveryGoal(_, _, _, _, .accepted) = envelope.command,
           case .externalAgent = origin {
            return .init(entityIDs: [], auditEventID: nil, error: .ownerAcceptanceRequired)
        }
        if envelope.command.isDocumentationMutation {
            guard let body = try? canonicalRequestBody(envelope) else {
                return .init(entityIDs: [], auditEventID: nil, error: .documentation(.invalidRequest))
            }
            return await DocumentationCommandDispatcher(store: store, bookmarkStore: bookmarkStore)
                .dispatch(envelope, requestBody: body, origin: origin, admissionDeadline: admissionDeadline)
        }
        guard let project = await projectRegistry.resolve(projectRoot: envelope.projectRoot) else {
            return .init(entityIDs: [], auditEventID: nil, error: .unauthorizedProjectRoot)
        }

        do {
            let requestBody = try canonicalRequestBody(envelope)
            let auditEventID = AuditEventID(rawValue: UUID().uuidString)
            let auditScope = Self.auditScope(for: envelope.command, projectID: project.projectID)
            let actor: DeliveryActor = switch origin {
            case .externalAgent:
                .init(
                    id: "release-radar-agent",
                    threadID: envelope.assertedThreadID,
                    threadAttribution: envelope.assertedThreadID == nil ? .none : .asserted
                )
            case .ownerApp:
                .init(id: "release-radar-owner")
            }
            do {
                return try await store.transact(
                    actor: actor,
                    reason: envelope.reason,
                    auditEventID: auditEventID,
                    auditScope: auditScope
                ) { connection in
                    if let admissionDeadline,
                       admissionDeadline <= Date().timeIntervalSince1970 {
                        throw DispatchControl.expired
                    }
                    if let prior = try connection.row(
                        "SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?",
                        bindings: [.text(envelope.requestID.uuidString)]
                    ) {
                        guard prior["request_body"] == .blob(requestBody),
                              case let .blob(priorResultData)? = prior["result_data"],
                              let priorResult = try? JSONDecoder().decode(AgentCommandResult.self, from: priorResultData)
                        else {
                            throw DispatchControl.requestIDReused
                        }
                        if case .transitionDeliveryGoal = envelope.command {
                            guard priorResult.error == nil, let priorAuditID = priorResult.auditEventID,
                                  let audit = try connection.row(
                                    "SELECT actor_id,project_id,entity_type,entity_id FROM audit_events WHERE id=?",
                                    bindings: [.text(priorAuditID.rawValue)]),
                                  audit["actor_id"] == .text(actor.id),
                                  audit["project_id"] == .text(auditScope.projectID.rawValue),
                                  audit["entity_type"] == .text(auditScope.entityType.rawValue),
                                  audit["entity_id"] == .text(auditScope.entityID)
                            else { throw DispatchControl.requestIDReused }
                        }
                        throw DispatchControl.replay(priorResult)
                    }

                    let revision = try Self.apply(envelope.command, project: project, origin: origin, auditEventID: auditEventID, connection: connection)
                    let result = Self.resultForCommand(envelope.command, auditEventID: auditEventID, revision: revision)
                    let resultData = try JSONEncoder().encode(result)
                    try connection.execute(
                        "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, ?)",
                        bindings: [
                            .text(envelope.requestID.uuidString),
                            .blob(requestBody),
                            .blob(resultData),
                            .text(ISO8601DateFormatter().string(from: Date())),
                        ]
                    )
                    return result
                }
            } catch let control as DispatchControl {
                switch control {
                case let .replay(result): return result
                case .expired:
                    return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
                case .requestIDReused:
                    return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused)
                }
            }
        } catch let error as StoreError {
            if case .unavailable = error {
                return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
            }
            return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription))
        } catch {
            return .init(entityIDs: [], auditEventID: nil, error: Self.map(error, command: envelope.command))
        }
    }

    private func validate(_ envelope: AgentCommandEnvelope) -> AgentCommandError? {
        guard envelope.version == Self.commandEnvelopeVersion else {
            return .unsupportedVersion(found: envelope.version, supported: Self.commandEnvelopeVersion)
        }
        guard !envelope.projectRoot.isEmpty, envelope.projectRoot.utf8.count <= 4_096 else {
            return .invalidEnvelope("projectRoot must contain 1...4096 UTF-8 bytes")
        }
        guard !envelope.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              envelope.reason.utf8.count <= 1_000 else {
            return .invalidEnvelope("reason must contain 1...1000 UTF-8 bytes")
        }
        if let threadID = envelope.assertedThreadID,
           threadID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || threadID.utf8.count > 1_024 {
            return .invalidEnvelope("assertedThreadID must contain 1...1024 UTF-8 bytes when present")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(envelope.command), data.count <= 65_536 else {
            return .invalidEnvelope("command payload must not exceed 65536 bytes")
        }
        func valid(_ value: String, maximum: Int = 4_096) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && value.utf8.count <= maximum
        }
        let commandFieldsAreValid: Bool
        switch envelope.command {
        case let .applyPhasePlanRevision(projectID, phaseID, revision, goals, assignments, unassigned, superseded):
            commandFieldsAreValid = valid(projectID, maximum: 256) && !projectID.contains("\0")
                && valid(phaseID, maximum: 256) && !phaseID.contains("\0") && revision >= 0
                && (goals?.count ?? 0) + (superseded?.count ?? 0) <= DeliveryPlanningPolicy.maximumGoalOperationsPerRevision
                && (assignments?.count ?? 0) + (unassigned?.count ?? 0) <= DeliveryPlanningPolicy.maximumAssignmentOperationsPerRevision
        case let .finalizePhasePlan(projectID, phaseID, revision), let .transitionDeliveryGoal(projectID, phaseID, _, revision, _):
            commandFieldsAreValid = valid(projectID, maximum: 256) && !projectID.contains("\0")
                && valid(phaseID, maximum: 256) && !phaseID.contains("\0") && revision >= 0
        case .bindDocumentationRepository, .acceptDocumentationCatalog, .addManagedEvidence, .adoptManagedEvidence, .relocateLegacyEvidence:
            commandFieldsAreValid = (try? envelope.command.validateDocumentation()) != nil
        case let .upsertPhase(phaseID, name):
            commandFieldsAreValid = valid(phaseID, maximum: 256) && valid(name)
        case let .upsertTicket(ticketID, phaseID, outcome, _):
            commandFieldsAreValid = valid(ticketID, maximum: 256) && valid(phaseID, maximum: 256) && valid(outcome)
        case let .transitionTicket(ticketID, lane, ticketTaskPlanRevision):
            if lane == .accepted, ticketID.contains("\0") {
                return .invalidEnvelope("Accepted transition ticketID is invalid")
            }
            if let ticketTaskPlanRevision {
                guard lane == .accepted else {
                    return .invalidEnvelope("ticketTaskPlanRevision is valid only for Accepted transitions")
                }
                guard ticketTaskPlanRevision >= 1 else {
                    return .invalidEnvelope("ticketTaskPlanRevision must be at least 1")
                }
            }
            commandFieldsAreValid = valid(ticketID, maximum: 256)
        case let .reviseTicketTaskPlan(ticketID, expectedRevision, additions, definitionRevisions, supersededTaskIDs):
            let additions = additions ?? []
            let definitions = definitionRevisions ?? []
            let supersessions = supersededTaskIDs ?? []
            commandFieldsAreValid = valid(ticketID, maximum: 256) && !ticketID.contains("\0")
                && expectedRevision.map { $0 > 0 } != false
                && additions.count + definitions.count + supersessions.count <= TicketTaskPlanningPolicy.maximumOperationsPerRevision
                && additions.allSatisfy {
                    valid($0.id.rawValue, maximum: 256) && !$0.id.rawValue.contains("\0")
                        && valid($0.label, maximum: 256) && !$0.label.contains("\0")
                        && valid($0.title) && !$0.title.contains("\0") && $0.sortOrder >= 0
                }
                && definitions.allSatisfy {
                    valid($0.id.rawValue, maximum: 256) && !$0.id.rawValue.contains("\0")
                        && $0.title.map { valid($0) && !$0.contains("\0") } != false
                        && $0.sortOrder.map { $0 >= 0 } != false
                }
                && supersessions.allSatisfy { valid($0.rawValue, maximum: 256) && !$0.rawValue.contains("\0") }
        case let .completeTicketTask(ticketID, taskID, expectedRevision):
            commandFieldsAreValid = valid(ticketID, maximum: 256) && !ticketID.contains("\0")
                && valid(taskID, maximum: 256) && !taskID.contains("\0") && expectedRevision > 0
        case let .setActivePhase(phaseID):
            commandFieldsAreValid = valid(phaseID, maximum: 256)
        case let .setDependency(id, _, subjectID, dependsOnID):
            commandFieldsAreValid = valid(id, maximum: 256)
                && valid(subjectID, maximum: 256)
                && valid(dependsOnID, maximum: 256)
        case let .recordBlocker(id, ticketID, summary):
            commandFieldsAreValid = valid(id, maximum: 256) && valid(ticketID, maximum: 256) && valid(summary)
        case let .resolveBlocker(blockerID):
            commandFieldsAreValid = valid(blockerID, maximum: 256)
        case let .addEvidence(id, ticketID, path):
            commandFieldsAreValid = valid(id, maximum: 256)
                && ticketID.map { valid($0, maximum: 256) } != false
                && valid(path)
        case let .linkThread(id, ticketID, threadID):
            commandFieldsAreValid = valid(id, maximum: 256)
                && valid(ticketID, maximum: 256)
                && valid(threadID, maximum: 1_024)
        case let .linkGoal(id, ticketID, goalID):
            commandFieldsAreValid = valid(id, maximum: 256)
                && valid(ticketID, maximum: 256)
                && valid(goalID, maximum: 256)
        case let .requestReview(id, ticketID, kind, summary):
            commandFieldsAreValid = valid(id, maximum: 256)
                && ticketID.map { valid($0, maximum: 256) } != false
                && valid(kind, maximum: 256)
                && valid(summary)
        case let .recordCompletion(id, ticketID, summary):
            commandFieldsAreValid = valid(id, maximum: 256) && valid(ticketID, maximum: 256) && valid(summary)
        case let .resolveImportReview(reviewItemID), let .dismissImportReview(reviewItemID):
            commandFieldsAreValid = valid(reviewItemID, maximum: 256)
        }
        guard commandFieldsAreValid else {
            return .invalidEnvelope("command identifiers and text must be non-empty and bounded")
        }
        if case let .upsertTicket(_, _, _, lane) = envelope.command, lane == .accepted {
            return .invalidEnvelope("Accepted tickets must use transitionTicket")
        }
        return nil
    }

    private func canonicalRequestBody(_ envelope: AgentCommandEnvelope) throws -> Data {
        struct Body: Codable {
            let version: Int
            let projectRoot: String
            let assertedThreadID: String?
            let reason: String
            let command: AgentCommand
        }
        let body = Body(
            version: envelope.version,
            projectRoot: envelope.projectRoot,
            assertedThreadID: envelope.assertedThreadID,
            reason: envelope.reason,
            command: envelope.command
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(body)
    }

    private static func resultForCommand(_ command: AgentCommand, auditEventID: AuditEventID, revision: Int64?) -> AgentCommandResult {
        switch command {
        case let .applyPhasePlanRevision(_, phaseID, _, _, _, _, _), let .finalizePhasePlan(_, phaseID, _):
            return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil, phasePlanRevision: revision)
        case let .transitionDeliveryGoal(_, _, goalID, _, _):
            return .init(entityIDs: [goalID], auditEventID: auditEventID, error: nil, phasePlanRevision: revision)
        case let .reviseTicketTaskPlan(ticketID, _, _, _, _):
            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil, ticketTaskPlanRevision: revision)
        case let .completeTicketTask(ticketID, taskID, _):
            return .init(entityIDs: [ticketID, taskID], auditEventID: auditEventID, error: nil, ticketTaskPlanRevision: revision)
        case .bindDocumentationRepository, .acceptDocumentationCatalog, .addManagedEvidence, .adoptManagedEvidence, .relocateLegacyEvidence:
            return .init(entityIDs: command.documentationIDs, auditEventID: auditEventID, error: nil)
        case let .upsertPhase(phaseID, _):
            return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil)
        case let .upsertTicket(ticketID, _, _, _):
            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
        case let .transitionTicket(ticketID, _, _):
            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
        case let .setActivePhase(phaseID):
            return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil)
        case let .setDependency(id, _, _, _),
             let .recordBlocker(id, _, _),
             let .addEvidence(id, _, _),
             let .linkThread(id, _, _),
             let .linkGoal(id, _, _),
             let .requestReview(id, _, _, _),
             let .recordCompletion(id, _, _):
            return .init(entityIDs: [id], auditEventID: auditEventID, error: nil)
        case let .resolveBlocker(blockerID):
            return .init(entityIDs: [blockerID], auditEventID: auditEventID, error: nil)
        case let .resolveImportReview(reviewItemID), let .dismissImportReview(reviewItemID):
            return .init(entityIDs: [reviewItemID], auditEventID: auditEventID, error: nil)
        }
    }

    private static func auditScope(for command: AgentCommand, projectID: ProjectID) -> AuditScope {
        let entity: (AuditEntityType, String) = switch command {
        case let .applyPhasePlanRevision(_, phaseID, _, _, _, _, _), let .finalizePhasePlan(_, phaseID, _): (.phasePlan, phaseID)
        case let .transitionDeliveryGoal(_, _, goalID, _, _): (.deliveryGoal, goalID)
        case .bindDocumentationRepository, .acceptDocumentationCatalog, .addManagedEvidence, .adoptManagedEvidence, .relocateLegacyEvidence: (.project, projectID.rawValue)
        case let .upsertPhase(phaseID, _): (.phase, phaseID)
        case let .setActivePhase(phaseID): (.phase, phaseID)
        case let .upsertTicket(ticketID, _, _, _), let .transitionTicket(ticketID, _, _): (.ticket, ticketID)
        case let .reviseTicketTaskPlan(ticketID, _, _, _, _), let .completeTicketTask(ticketID, _, _): (.ticketTaskPlan, ticketID)
        case let .setDependency(id, kind, _, _):
            (kind == .ticket ? .ticketDependency : .phaseDependency, id)
        case let .recordBlocker(id, _, _), let .resolveBlocker(id): (.blocker, id)
        case let .addEvidence(id, _, _): (.evidence, id)
        case let .linkThread(id, _, _): (.threadLink, id)
        case let .linkGoal(_, ticketID, _): (.ticket, ticketID)
        case let .requestReview(id, _, _, _),
             let .resolveImportReview(id),
             let .dismissImportReview(id): (.reviewItem, id)
        case let .recordCompletion(id, _, _): (.completion, id)
        }
        return AuditScope(projectID: projectID, entityType: entity.0, entityID: entity.1)
    }

    private static func apply(
        _ command: AgentCommand,
        project: AuthorizedProject,
        origin: AgentCommandOrigin,
        auditEventID: AuditEventID,
        connection: SQLiteConnection
    ) throws -> Int64? {
        let projectID = project.projectID
        switch command {
        case let .applyPhasePlanRevision(assertedProjectID, phaseID, expectedRevision, goals, assignments, unassigned, superseded):
            guard Data(assertedProjectID.utf8) == Data(projectID.rawValue.utf8) else {
                throw CommandValidation.crossProject("The phase plan belongs to another project.")
            }
            return try DeliveryPlanningPolicy.applyRevision(
                projectID: projectID, phaseID: .init(rawValue: phaseID), expectedRevision: expectedRevision,
                goalUpserts: goals ?? [], assignments: assignments ?? [], unassignedTicketIDs: unassigned ?? [],
                supersededGoalIDs: superseded ?? [], auditEventID: auditEventID, connection: connection).revision
        case let .finalizePhasePlan(assertedProjectID, phaseID, expectedRevision):
            guard Data(assertedProjectID.utf8) == Data(projectID.rawValue.utf8) else {
                throw CommandValidation.crossProject("The phase plan belongs to another project.")
            }
            return try DeliveryPlanningPolicy.finalizePlan(
                projectID: projectID, phaseID: .init(rawValue: phaseID), expectedRevision: expectedRevision,
                connection: connection).revision
        case let .transitionDeliveryGoal(assertedProjectID, phaseID, goalID, expectedPlanRevision, lifecycle):
            guard Data(assertedProjectID.utf8) == Data(projectID.rawValue.utf8) else {
                throw CommandValidation.crossProject("The Delivery Goal belongs to another project.")
            }
            _ = try DeliveryPlanningPolicy.transitionGoal(
                projectID: projectID, phaseID: .init(rawValue: phaseID), goalID: .init(rawValue: goalID),
                expectedPlanRevision: expectedPlanRevision, to: lifecycle, origin: origin, connection: connection)
            return expectedPlanRevision
        case let .reviseTicketTaskPlan(ticketID, expectedRevision, additions, definitionRevisions, supersededTaskIDs):
            return try TicketTaskPlanningPolicy.revisePlan(
                projectID: projectID, ticketID: .init(rawValue: ticketID), expectedRevision: expectedRevision,
                additions: additions ?? [], definitionRevisions: definitionRevisions ?? [],
                supersededTaskIDs: supersededTaskIDs ?? [], connection: connection
            ).revision
        case let .completeTicketTask(ticketID, taskID, expectedRevision):
            return try TicketTaskPlanningPolicy.completeTask(
                projectID: projectID, ticketID: .init(rawValue: ticketID), taskID: .init(rawValue: taskID),
                expectedRevision: expectedRevision, connection: connection
            ).revision
        case .bindDocumentationRepository, .acceptDocumentationCatalog, .addManagedEvidence, .adoptManagedEvidence, .relocateLegacyEvidence:
            throw DocumentationOperationError.invalidRequest
        case let .upsertPhase(phaseID, name):
            try requireWritableID(phaseID, table: "phases", projectID: projectID, connection: connection)
            try DeliveryPlanningPolicy.upsertPhase(
                projectID: projectID, phaseID: .init(rawValue: phaseID), name: name,
                mode: .governed, connection: connection)
            try connection.execute(
                """
                INSERT INTO project_active_phases (project_id, phase_id)
                SELECT ?, ?
                WHERE NOT EXISTS (SELECT 1 FROM project_active_phases WHERE project_id = ?)
                  AND (SELECT COUNT(*) FROM phases WHERE project_id = ?) = 1
                """,
                bindings: [.text(projectID.rawValue), .text(phaseID), .text(projectID.rawValue), .text(projectID.rawValue)]
            )
        case let .upsertTicket(ticketID, phaseID, outcome, lane):
            try requireProjectEntity(phaseID, table: "phases", projectID: projectID, connection: connection)
            try requireWritableID(ticketID, table: "tickets", projectID: projectID, connection: connection)
            let previousLane = try connection.scalarText(
                "SELECT lane FROM tickets WHERE id = ? AND project_id = ?",
                bindings: [.text(ticketID), .text(projectID.rawValue)]
            )
            try DeliveryPlanningPolicy.upsertTicket(
                projectID: projectID, ticketID: .init(rawValue: ticketID), phaseID: .init(rawValue: phaseID),
                outcome: outcome, lane: lane, auditEventID: auditEventID, connection: connection)
            try updateNeedsReviewOccurrence(
                ticketID: ticketID,
                lane: lane,
                enteredNeedsReview: previousLane != TicketLane.needsReview.rawValue,
                projectID: projectID,
                connection: connection
            )
        case let .transitionTicket(ticketID, lane, ticketTaskPlanRevision):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            let previousLane = try connection.scalarText(
                "SELECT lane FROM tickets WHERE id = ? AND project_id = ?",
                bindings: [.text(ticketID), .text(projectID.rawValue)]
            )
            try DeliveryPlanningPolicy.transitionTicket(
                projectID: projectID, ticketID: .init(rawValue: ticketID), to: lane,
                ticketTaskPlanRevision: ticketTaskPlanRevision, connection: connection)
            try updateNeedsReviewOccurrence(
                ticketID: ticketID,
                lane: lane,
                enteredNeedsReview: previousLane != TicketLane.needsReview.rawValue,
                projectID: projectID,
                connection: connection
            )
        case let .setActivePhase(phaseID):
            try requireProjectEntity(phaseID, table: "phases", projectID: projectID, connection: connection)
            try connection.execute(
                """
                INSERT INTO project_active_phases (project_id, phase_id)
                VALUES (?, ?)
                ON CONFLICT(project_id) DO UPDATE SET phase_id = excluded.phase_id;
                """,
                bindings: [.text(projectID.rawValue), .text(phaseID)]
            )
        case let .setDependency(id, kind, subjectID, dependsOnID):
            let table = kind == .ticket ? "tickets" : "phases"
            try requireProjectEntity(subjectID, table: table, projectID: projectID, connection: connection)
            try requireProjectEntity(dependsOnID, table: table, projectID: projectID, connection: connection)
            let dependencyTable = kind == .ticket ? "ticket_dependencies" : "phase_dependencies"
            let subjectColumn = kind == .ticket ? "ticket_id" : "phase_id"
            let dependencyColumn = kind == .ticket ? "depends_on_ticket_id" : "depends_on_phase_id"
            try requireWritableID(id, table: dependencyTable, projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO \(dependencyTable) (id, project_id, \(subjectColumn), \(dependencyColumn)) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET \(subjectColumn) = excluded.\(subjectColumn), \(dependencyColumn) = excluded.\(dependencyColumn)",
                bindings: [.text(id), .text(projectID.rawValue), .text(subjectID), .text(dependsOnID)]
            )
        case let .recordBlocker(id, ticketID, summary):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            try requireWritableID(id, table: "blockers", projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO blockers (id, project_id, ticket_id, summary, resolved_at) VALUES (?, ?, ?, ?, NULL) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, summary = excluded.summary, resolved_at = NULL",
                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(summary)]
            )
        case let .resolveBlocker(blockerID):
            try requireProjectEntity(blockerID, table: "blockers", projectID: projectID, connection: connection)
            try connection.execute(
                "UPDATE blockers SET resolved_at = ? WHERE id = ? AND project_id = ?",
                bindings: [.text(ISO8601DateFormatter().string(from: Date())), .text(blockerID), .text(projectID.rawValue)]
            )
        case let .addEvidence(id, ticketID, path):
            if let ticketID {
                try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            }
            let resolvedPath = try authorizedEvidencePath(path, project: project)
            try rejectCataloguedLegacyPath(resolvedPath, project: project)
            try requireWritableID(id, table: "evidence", projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES (?, ?, ?, ?, 1) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, path = excluded.path, is_available = 1",
                bindings: [.text(id), .text(projectID.rawValue), ticketID.map(SQLiteValue.text) ?? .null, .text(resolvedPath)]
            )
        case let .linkThread(id, ticketID, threadID):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            try requireProjectEntity(threadID, table: "observed_threads", projectID: projectID, connection: connection)
            try requireWritableID(id, table: "thread_links", projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, thread_id = excluded.thread_id",
                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(threadID)]
            )
        case let .linkGoal(id, ticketID, goalID):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            try requireProjectEntity(goalID, table: "observed_goals", projectID: projectID, connection: connection)
            try requireWritableID(id, table: "ticket_goal_links", projectID: projectID, connection: connection)
            if let existingTicketID = try connection.scalarText(
                "SELECT ticket_id FROM ticket_goal_links WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(id)]
            ), existingTicketID != ticketID {
                throw CommandValidation.invalidReference("Goal link \(id) belongs to ticket \(existingTicketID)")
            }
            guard let threadID = try connection.scalarText(
                "SELECT thread_id FROM observed_goals WHERE project_id = ? AND id = ?",
                bindings: [.text(projectID.rawValue), .text(goalID)]
            ) else {
                throw CommandValidation.invalidReference("Unknown observed_goals record \(goalID)")
            }
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM thread_links WHERE project_id = ? AND ticket_id = ? AND thread_id = ?",
                bindings: [.text(projectID.rawValue), .text(ticketID), .text(threadID)]
            ) == 1 else {
                throw CommandValidation.invalidReference("Goal \(goalID) does not belong to a thread linked to ticket \(ticketID)")
            }
            if let existingID = try connection.scalarText(
                "SELECT id FROM ticket_goal_links WHERE project_id = ? AND ticket_id = ?",
                bindings: [.text(projectID.rawValue), .text(ticketID)]
            ), existingID != id {
                throw CommandValidation.invalidReference("Ticket \(ticketID) already has an approved goal")
            }
            if let existingTicketID = try connection.scalarText(
                "SELECT ticket_id FROM ticket_goal_links WHERE project_id = ? AND goal_id = ?",
                bindings: [.text(projectID.rawValue), .text(goalID)]
            ), existingTicketID != ticketID {
                throw CommandValidation.invalidReference("Goal \(goalID) is already approved for another ticket")
            }
            try connection.execute(
                "INSERT INTO ticket_goal_links (id, project_id, ticket_id, thread_id, goal_id) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, thread_id = excluded.thread_id, goal_id = excluded.goal_id",
                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(threadID), .text(goalID)]
            )
        case let .requestReview(id, ticketID, kind, summary):
            if let ticketID {
                try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
                try DeliveryPlanningPolicy.assertCanRecordReviewOrCompletion(
                    projectID: projectID, ticketID: .init(rawValue: ticketID), connection: connection)
            }
            try requireWritableID(id, table: "review_items", projectID: projectID, connection: connection)
            try requireAgentWritableReview(id: id, kind: kind, projectID: projectID, connection: connection)
            let previousStatus = try connection.scalarText(
                "SELECT status FROM review_items WHERE id = ? AND project_id = ?",
                bindings: [.text(id), .text(projectID.rawValue)]
            )
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open') ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, kind = excluded.kind, summary = excluded.summary, status = 'open'",
                bindings: [.text(id), .text(projectID.rawValue), ticketID.map(SQLiteValue.text) ?? .null, .text(kind), .text(summary)]
            )
            if previousStatus != "open" {
                _ = try MeaningfulDeliveryEvent.enqueue(
                    projectID: projectID,
                    kind: .reviewRequested,
                    subjectID: id,
                    ticketID: ticketID.map(TicketID.init(rawValue:)),
                    goalID: nil,
                    connection: connection
                )
            }
        case let .recordCompletion(id, ticketID, summary):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            try DeliveryPlanningPolicy.assertCanRecordReviewOrCompletion(
                projectID: projectID, ticketID: .init(rawValue: ticketID), connection: connection)
            try requireWritableID(id, table: "completion_records", projectID: projectID, connection: connection)
            let isNewCompletion = try connection.scalarText(
                "SELECT id FROM completion_records WHERE id = ? AND project_id = ?",
                bindings: [.text(id), .text(projectID.rawValue)]
            ) == nil
            try connection.execute(
                "INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, summary = excluded.summary",
                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(summary), .text(ISO8601DateFormatter().string(from: Date()))]
            )
            if isNewCompletion {
                _ = try MeaningfulDeliveryEvent.enqueue(
                    projectID: projectID,
                    kind: .agentCompleted,
                    subjectID: id,
                    ticketID: TicketID(rawValue: ticketID),
                    goalID: nil,
                    connection: connection
                )
            }
        case let .resolveImportReview(reviewItemID):
            try updateReview(reviewItemID, status: "resolved", projectID: projectID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .reviewRequested, subjectID: reviewItemID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .importNeedsReview, subjectID: reviewItemID, connection: connection)
        case let .dismissImportReview(reviewItemID):
            try updateReview(reviewItemID, status: "dismissed", projectID: projectID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .reviewRequested, subjectID: reviewItemID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .importNeedsReview, subjectID: reviewItemID, connection: connection)
        }
        return nil
    }

    private static func updateNeedsReviewOccurrence(
        ticketID: String,
        lane: TicketLane,
        enteredNeedsReview: Bool,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        if lane == .needsReview, enteredNeedsReview {
            _ = try MeaningfulDeliveryEvent.enqueue(
                projectID: projectID,
                kind: .ticketNeedsReview,
                subjectID: ticketID,
                ticketID: TicketID(rawValue: ticketID),
                goalID: nil,
                connection: connection
            )
        } else if lane != .needsReview {
            try MeaningfulDeliveryEvent.deactivate(
                projectID: projectID,
                kind: .ticketNeedsReview,
                subjectID: ticketID,
                connection: connection
            )
        }
    }

    private static func requireWritableID(
        _ id: String,
        table: String,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        guard let existingProject = try connection.scalarText(
            "SELECT project_id FROM \(table) WHERE id = ?",
            bindings: [.text(id)]
        ) else { return }
        guard existingProject == projectID.rawValue else {
            throw CommandValidation.crossProject("\(table) record \(id) belongs to another project")
        }
    }

    private static func requireProjectEntity(
        _ id: String,
        table: String,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        guard let existingProject = try connection.scalarText(
            "SELECT project_id FROM \(table) WHERE id = ?",
            bindings: [.text(id)]
        ) else {
            throw CommandValidation.invalidReference("Unknown \(table) record \(id)")
        }
        guard existingProject == projectID.rawValue else {
            throw CommandValidation.crossProject("\(table) record \(id) belongs to another project")
        }
    }

    private static func authorizedEvidencePath(_ path: String, project: AuthorizedProject) throws -> String {
        guard path.utf8.count <= 4_096 else {
            throw CommandValidation.invalidReference("Evidence path exceeds 4096 UTF-8 bytes")
        }
        let rawURL = URL(fileURLWithPath: path, relativeTo: project.canonicalRoot)
        let resolved = AuthorizedProject.canonicalize(rawURL)
        guard FileManager.default.fileExists(atPath: resolved.path),
              project.authorizedRoots.contains(where: { contains(resolved, within: $0) }) else {
            throw CommandValidation.crossProject("Evidence must resolve inside an authorized project root")
        }
        return resolved.path
    }

    private static func rejectCataloguedLegacyPath(_ path: String, project: AuthorizedProject) throws {
        // Genuinely arbitrary evidence keeps its established behavior. This guard
        // only closes the legacy route into the managed documentation namespace.
        for root in project.authorizedRoots where path.hasPrefix(root.path + "/docs/") {
            let catalog = try DocumentationCatalogContext(root: root)
            switch catalog.mode {
            case .legacy: return
            case .unavailable: throw DocumentationOperationError.guidanceUnavailable
            case .managedV2:
                guard let snapshot = catalog.snapshot else { throw DocumentationOperationError.catalogInvalid }
                let relative = String(path.dropFirst(root.path.count + 1))
                if snapshot.catalog.artifacts.contains(where: { $0.path == relative }) {
                    throw DocumentationOperationError.managedCommandRequired
                }
            }
            try catalog.reader.verifyStable()
        }
    }

    private static func contains(_ candidate: URL, within root: URL) -> Bool {
        let candidateComponents = candidate.pathComponents
        let rootComponents = root.pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }

    private static func updateReview(
        _ id: String,
        status: String,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        try requireProjectEntity(id, table: "review_items", projectID: projectID, connection: connection)
        let kind = try connection.scalarText(
            "SELECT kind FROM review_items WHERE id = ? AND project_id = ?",
            bindings: [.text(id), .text(projectID.rawValue)]
        )
        guard !OnboardingReviewMarkerKind.isReserved(id: id),
              kind.map({ !OnboardingReviewMarkerKind.isReserved(kind: $0) }) == true
        else {
            throw CommandValidation.invalidReference("Onboarding review markers are reserved for the owner onboarding flow")
        }
        try connection.execute(
            "UPDATE review_items SET status = ? WHERE id = ? AND project_id = ?",
            bindings: [.text(status), .text(id), .text(projectID.rawValue)]
        )
    }

    private static func requireAgentWritableReview(
        id: String,
        kind: String,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        let existingKind = try connection.scalarText(
            "SELECT kind FROM review_items WHERE id = ? AND project_id = ?",
            bindings: [.text(id), .text(projectID.rawValue)]
        )
        guard !OnboardingReviewMarkerKind.isReserved(kind: kind),
              !OnboardingReviewMarkerKind.isReserved(id: id),
              existingKind.map({ !OnboardingReviewMarkerKind.isReserved(kind: $0) }) ?? true
        else {
            throw CommandValidation.invalidReference("Onboarding review markers are reserved for the owner onboarding flow")
        }
    }

    private static func map(_ error: Error, command: AgentCommand) -> AgentCommandError {
        // Preserve the existing Accepted-transition error contract. Only the
        // additive task commands expose these task-policy rejection categories.
        switch command {
        case .applyPhasePlanRevision, .finalizePhasePlan, .transitionDeliveryGoal:
            if let error = error as? DeliveryPlanningPolicyError {
                switch error {
                case .phasePlanNotFound: return .phasePlanNotFound
                case let .planRevisionConflict(expected, current): return .planRevisionConflict(expected: expected, current: current)
                case .phasePlanNotReady: return .phasePlanNotReady
                case let .ticketGoalRequired(id): return .ticketGoalRequired(id)
                case let .phasePlanIncomplete(failure): return .phasePlanIncomplete(failure)
                case let .goalPhaseMismatch(id): return .goalPhaseMismatch(id)
                case let .goalNotFound(id): return .goalNotFound(id)
                case let .goalNotActionable(id): return .goalNotActionable(id)
                case let .invalidGoalTransition(from, to): return .invalidGoalTransition(from: from, to: to)
                case .ownerAcceptanceRequired: return .ownerAcceptanceRequired
                case let .goalAcceptanceEvidenceUnavailable(ids): return .goalAcceptanceEvidenceUnavailable(ids)
                case let .invalidPlanMutation(message): return .invalidPlanMutation(message)
                }
            }
        case .reviseTicketTaskPlan, .completeTicketTask:
            if let error = error as? TicketTaskPlanningPolicyError {
                switch error {
                case .ticketTaskPlanNotFound: return .ticketTaskPlanNotFound
                case .ticketTaskPlanAlreadyExists: return .ticketTaskPlanAlreadyExists
                case let .ticketTaskPlanRevisionConflict(expected, current): return .ticketTaskPlanRevisionConflict(expected: expected, current: current)
                case let .ticketTaskNotFound(id): return .ticketTaskNotFound(id)
                case let .ticketTaskImmutable(id): return .ticketTaskImmutable(id)
                case let .ticketTaskIncomplete(ids): return .ticketTaskIncomplete(pendingTaskIDs: ids)
                case .ticketTaskReplacementRequired: return .ticketTaskReplacementRequired
                case let .invalidTicketTaskMutation(reason): return .invalidTicketTaskMutation(String(describing: reason))
                }
            }
        default: break
        }
        if let error = error as? DocumentationOperationError { return .documentation(error) }
        if let validation = error as? CommandValidation {
            switch validation {
            case let .invalidReference(message): return .invalidReference(message)
            case let .crossProject(message): return .crossProjectReference(message)
            case let .cycle(message): return .dependencyCycle(message)
            }
        }
        if let sqlite = error as? SQLiteError {
            if sqlite.message.localizedCaseInsensitiveContains("cycle") {
                return .dependencyCycle(sqlite.message)
            }
            if sqlite.message.localizedCaseInsensitiveContains("foreign key") {
                return .invalidReference(sqlite.message)
            }
        }
        return .internalFailure(error.localizedDescription)
    }
}

private enum DispatchControl: Error, Sendable {
    case expired
    case replay(AgentCommandResult)
    case requestIDReused
}

private enum CommandValidation: Error, Sendable {
    case invalidReference(String)
    case crossProject(String)
    case cycle(String)
}
