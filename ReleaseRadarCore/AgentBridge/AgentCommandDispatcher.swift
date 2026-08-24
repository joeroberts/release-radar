import Foundation

public enum AgentCommandOrigin: Sendable {
    case externalAgent
    case ownerApp
}

public actor AgentCommandDispatcher {
    public static let commandEnvelopeVersion = 1

    private let store: DeliveryStore
    private let projectRegistry: any AuthorizedProjectRegistry

    public init(store: DeliveryStore, projectRegistry: any AuthorizedProjectRegistry) {
        self.store = store
        self.projectRegistry = projectRegistry
    }

    public func dispatch(
        _ envelope: AgentCommandEnvelope,
        origin: AgentCommandOrigin = .externalAgent,
        admissionDeadline: TimeInterval? = nil
    ) async -> AgentCommandResult {
        if let error = validate(envelope) {
            return .init(entityIDs: [], auditEventID: nil, error: error)
        }
        guard let project = await projectRegistry.resolve(projectRoot: envelope.projectRoot) else {
            return .init(entityIDs: [], auditEventID: nil, error: .unauthorizedProjectRoot)
        }

        do {
            let requestBody = try canonicalRequestBody(envelope)
            let auditEventID = AuditEventID(rawValue: UUID().uuidString)
            let result = resultForCommand(envelope.command, auditEventID: auditEventID)
            let resultData = try JSONEncoder().encode(result)
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
                        throw DispatchControl.replay(priorResult)
                    }

                    try Self.apply(envelope.command, project: project, connection: connection)
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
            return .init(entityIDs: [], auditEventID: nil, error: Self.map(error))
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
        guard let data = try? JSONEncoder().encode(envelope.command), data.count <= 65_536 else {
            return .invalidEnvelope("command payload must not exceed 65536 bytes")
        }
        func valid(_ value: String, maximum: Int = 4_096) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && value.utf8.count <= maximum
        }
        let commandFieldsAreValid: Bool
        switch envelope.command {
        case let .upsertPhase(phaseID, name):
            commandFieldsAreValid = valid(phaseID, maximum: 256) && valid(name)
        case let .upsertTicket(ticketID, phaseID, outcome, _):
            commandFieldsAreValid = valid(ticketID, maximum: 256) && valid(phaseID, maximum: 256) && valid(outcome)
        case let .transitionTicket(ticketID, _):
            commandFieldsAreValid = valid(ticketID, maximum: 256)
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

    private func resultForCommand(_ command: AgentCommand, auditEventID: AuditEventID) -> AgentCommandResult {
        switch command {
        case let .upsertPhase(phaseID, _):
            return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil)
        case let .upsertTicket(ticketID, _, _, _):
            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
        case let .transitionTicket(ticketID, _):
            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
        case let .setDependency(id, _, _, _),
             let .recordBlocker(id, _, _),
             let .addEvidence(id, _, _),
             let .linkThread(id, _, _),
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
        case let .upsertPhase(phaseID, _): (.phase, phaseID)
        case let .upsertTicket(ticketID, _, _, _), let .transitionTicket(ticketID, _): (.ticket, ticketID)
        case let .setDependency(id, kind, _, _):
            (kind == .ticket ? .ticketDependency : .phaseDependency, id)
        case let .recordBlocker(id, _, _), let .resolveBlocker(id): (.blocker, id)
        case let .addEvidence(id, _, _): (.evidence, id)
        case let .linkThread(id, _, _): (.threadLink, id)
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
        connection: SQLiteConnection
    ) throws {
        let projectID = project.projectID
        switch command {
        case let .upsertPhase(phaseID, name):
            try requireWritableID(phaseID, table: "phases", projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name",
                bindings: [.text(phaseID), .text(projectID.rawValue), .text(name)]
            )
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
            try connection.execute(
                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET phase_id = excluded.phase_id, outcome = excluded.outcome, lane = excluded.lane",
                bindings: [.text(ticketID), .text(projectID.rawValue), .text(phaseID), .text(outcome), .text(lane.rawValue)]
            )
            try updateNeedsReviewOccurrence(ticketID: ticketID, lane: lane, projectID: projectID, connection: connection)
        case let .transitionTicket(ticketID, lane):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            try connection.execute(
                "UPDATE tickets SET lane = ? WHERE project_id = ? AND id = ?",
                bindings: [.text(lane.rawValue), .text(projectID.rawValue), .text(ticketID)]
            )
            try updateNeedsReviewOccurrence(ticketID: ticketID, lane: lane, projectID: projectID, connection: connection)
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
        case let .requestReview(id, ticketID, kind, summary):
            if let ticketID {
                try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            }
            try requireWritableID(id, table: "review_items", projectID: projectID, connection: connection)
            try requireAgentWritableReview(id: id, kind: kind, projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open') ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, kind = excluded.kind, summary = excluded.summary, status = 'open'",
                bindings: [.text(id), .text(projectID.rawValue), ticketID.map(SQLiteValue.text) ?? .null, .text(kind), .text(summary)]
            )
            _ = try MeaningfulDeliveryEvent.enqueue(
                projectID: projectID,
                kind: .reviewRequested,
                subjectID: id,
                ticketID: ticketID.map(TicketID.init(rawValue:)),
                goalID: nil,
                connection: connection
            )
        case let .recordCompletion(id, ticketID, summary):
            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
            try requireWritableID(id, table: "completion_records", projectID: projectID, connection: connection)
            try connection.execute(
                "INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, summary = excluded.summary",
                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(summary), .text(ISO8601DateFormatter().string(from: Date()))]
            )
            _ = try MeaningfulDeliveryEvent.enqueue(
                projectID: projectID,
                kind: .agentCompleted,
                subjectID: id,
                ticketID: TicketID(rawValue: ticketID),
                goalID: nil,
                connection: connection
            )
        case let .resolveImportReview(reviewItemID):
            try updateReview(reviewItemID, status: "resolved", projectID: projectID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .reviewRequested, subjectID: reviewItemID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .importNeedsReview, subjectID: reviewItemID, connection: connection)
        case let .dismissImportReview(reviewItemID):
            try updateReview(reviewItemID, status: "dismissed", projectID: projectID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .reviewRequested, subjectID: reviewItemID, connection: connection)
            try MeaningfulDeliveryEvent.deactivate(projectID: projectID, kind: .importNeedsReview, subjectID: reviewItemID, connection: connection)
        }
    }

    private static func updateNeedsReviewOccurrence(
        ticketID: String,
        lane: TicketLane,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        if lane == .needsReview {
            _ = try MeaningfulDeliveryEvent.enqueue(
                projectID: projectID,
                kind: .ticketNeedsReview,
                subjectID: ticketID,
                ticketID: TicketID(rawValue: ticketID),
                goalID: nil,
                connection: connection
            )
        } else {
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
        guard !OnboardingReviewMarkerKind.isReserved(id: id, projectID: projectID),
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
              !OnboardingReviewMarkerKind.isReserved(id: id, projectID: projectID),
              existingKind.map({ !OnboardingReviewMarkerKind.isReserved(kind: $0) }) ?? true
        else {
            throw CommandValidation.invalidReference("Onboarding review markers are reserved for the owner onboarding flow")
        }
    }

    private static func map(_ error: Error) -> AgentCommandError {
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
