import Foundation

private func commandEvidenceText(_ value: SQLiteValue?) -> String? {
    guard case let .text(text)? = value else { return nil }
    return text
}

private func commandEvidenceInteger(_ value: SQLiteValue?) -> Int64? {
    guard case let .integer(integer)? = value else { return nil }
    return integer
}

private func commandEvidenceBlob(_ value: SQLiteValue?) -> Data? {
    guard case let .blob(data)? = value else { return nil }
    return data
}

struct DeliveryEvidenceCommandDispatcher: Sendable {
    let store: DeliveryStore
    let bookmarkStore: any ProjectBookmarkStoring

    func dispatch(
        _ envelope: AgentCommandEnvelope,
        requestBody: Data,
        origin: AgentCommandOrigin,
        admissionDeadline: TimeInterval?,
        expectedRegistration: ProjectRegistration?
    ) async -> AgentCommandResult {
        do {
            guard let identity = envelope.command.deliveryEvidenceProjectRootAndTicket,
                  let registration = expectedRegistration else {
                throw DeliveryEvidenceMutationError.invalid("A current project registration is required")
            }
            let context = try await store.documentationRead {
                try DocumentationRootContext.read(
                    $0,
                    path: envelope.projectRoot,
                    projectID: identity.projectID,
                    rootID: identity.rootID,
                    schemaVersion: Int(StoreMigrations.currentVersion)
                )
            }
            return try await bookmarkStore.withSecurityScopedAccess(bookmark: context.bookmark) { resolved in
                try context.verifyAuthorization(resolved)
                if let replay = try await store.documentationRead({ connection in
                    try Self.requireCurrentAuthorization(registration, connection: connection)
                    return try Self.replay(
                        connection,
                        requestID: envelope.requestID,
                        body: requestBody,
                        registration: registration
                    )
                }) {
                    return replay
                }
                try await store.documentationRead {
                    try PhaseLifecyclePolicy.requireTicketPhaseOpen(
                        projectID: .init(rawValue: identity.projectID),
                        ticketID: .init(rawValue: identity.ticketID),
                        connection: $0
                    )
                }
                let preparedDocumentDigest = try Self.prepare(envelope.command, context: context)
                let auditID = AuditEventID(rawValue: UUID().uuidString)
                let actor: DeliveryActor = origin == .ownerApp
                    ? .init(id: "release-radar-owner")
                    : .init(
                        id: "release-radar-agent",
                        threadID: envelope.assertedThreadID,
                        threadAttribution: envelope.assertedThreadID == nil ? .none : .asserted
                    )
                do {
                    return try await store.transact(
                        actor: actor,
                        reason: envelope.reason,
                        auditEventID: auditID,
                        auditScope: .init(
                            projectID: .init(rawValue: identity.projectID),
                            entityType: .ticket,
                            entityID: identity.ticketID
                        )
                    ) { connection in
                        if let admissionDeadline, admissionDeadline <= Date().timeIntervalSince1970 {
                            throw DeliveryEvidenceControl.expired
                        }
                        try Self.requireCurrentAuthorization(registration, connection: connection)
                        if let replay = try Self.replay(
                            connection,
                            requestID: envelope.requestID,
                            body: requestBody,
                            registration: registration
                        ) {
                            throw DeliveryEvidenceControl.replay(replay)
                        }
                        try PhaseLifecyclePolicy.requireTicketPhaseOpen(
                            projectID: .init(rawValue: identity.projectID),
                            ticketID: .init(rawValue: identity.ticketID),
                            connection: connection
                        )
                        try context.verifyPersisted(connection)
                        guard try Self.prepare(envelope.command, context: context) == preparedDocumentDigest else {
                            throw DocumentationOperationError.staleEvidence
                        }
                        let revision = try Self.apply(
                            envelope.command,
                            registration: registration,
                            connection: connection
                        )
                        let result = AgentCommandResult(
                            entityIDs: [identity.ticketID],
                            auditEventID: auditID,
                            error: nil,
                            deliveryEvidenceRevision: revision
                        )
                        try connection.execute(
                            "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at, registration_project_id, registration_id, request_generation) VALUES (?, ?, ?, ?, ?, ?, ?)",
                            bindings: [
                                .text(envelope.requestID.uuidString),
                                .blob(requestBody),
                                .blob(try JSONEncoder().encode(result)),
                                .text(Self.timestamp()),
                                .text(registration.projectID.rawValue),
                                .text(registration.registrationID),
                                .integer(registration.requestGeneration),
                            ]
                        )
                        return result
                    }
                } catch let DeliveryEvidenceControl.replay(result) {
                    return result
                }
            }
        } catch DeliveryEvidenceControl.requestIDReused {
            return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused)
        } catch DeliveryEvidenceControl.expired {
            return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
        } catch let error as DeliveryEvidenceMutationError {
            return .init(entityIDs: [], auditEventID: nil, error: Self.map(error))
        } catch let error as PhaseLifecyclePolicyError {
            if case let .completedPhaseReadOnly(phaseID) = error {
                return .init(entityIDs: [], auditEventID: nil, error: .completedPhaseReadOnly(phaseID))
            }
            return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription))
        } catch let error as DocumentationOperationError {
            return .init(entityIDs: [], auditEventID: nil, error: .documentation(error))
        } catch let error as StoreError {
            if case .unavailable = error {
                return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
            }
            return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription))
        } catch {
            return .init(
                entityIDs: [],
                auditEventID: nil,
                error: .documentation(DocumentationCatalogContext.map(error))
            )
        }
    }

    /// Reads managed document bytes only for a document fact. Every command is
    /// still scoped by the accepted catalog tuple; non-document facts remain
    /// explicit recorded observations and never trigger repository or network IO.
    private static func prepare(
        _ command: AgentCommand,
        context: DocumentationRootContext
    ) throws -> String? {
        let target: DocumentationTarget
        switch command {
        case let .recordDeliveryEvidenceTarget(value, _, _, _, _),
             let .appendDeliveryEvidenceObservation(value, _, _, _):
            target = value
        default:
            throw DocumentationOperationError.invalidRequest
        }
        let catalog = try DocumentationCatalogContext(root: context.root)
        let snapshot = try catalog.managedSnapshot(target: target)
        try context.requireAccepted(snapshot)
        guard case let .appendDeliveryEvidenceObservation(_, _, observation, _) = command,
              case let .document(fact) = observation.fact else {
            return nil
        }
        guard fact.repositoryID == snapshot.catalog.repositoryID.lowercased(),
              let artifact = snapshot.catalog.artifacts.first(where: { $0.artifactID == fact.artifactID }) else {
            throw DocumentationOperationError.bindingMismatch
        }
        let digest = documentationDigest(try catalog.reader.read(artifact.path))
        try catalog.reader.verifyStable()
        guard digest == fact.contentDigest,
              fact.catalogVersion == snapshot.version,
              fact.catalogDigest == snapshot.digest else {
            throw DocumentationOperationError.staleEvidence
        }
        return digest
    }

    private static func apply(
        _ command: AgentCommand,
        registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws -> Int64 {
        guard let identity = command.deliveryEvidenceProjectRootAndTicket else {
            throw DeliveryEvidenceMutationError.invalid("Evidence identity is missing")
        }
        guard let ticket = try connection.row(
            "SELECT lane FROM tickets WHERE project_id=? AND id=?",
            bindings: [.text(identity.projectID), .text(identity.ticketID)]
        ) else {
            throw DeliveryEvidenceMutationError.notFound
        }
        if ticket["lane"] == .text(TicketLane.accepted.rawValue) {
            throw DeliveryEvidenceMutationError.ticketAccepted
        }
        guard try connection.scalarInt(
            "SELECT COUNT(*) FROM ticket_retirements WHERE project_id=? AND ticket_id=?",
            bindings: [.text(identity.projectID), .text(identity.ticketID)]
        ) == 0 else {
            throw DeliveryEvidenceMutationError.ticketRetired
        }

        let set = try connection.row(
            "SELECT revision, current_target_version FROM ticket_delivery_evidence_sets WHERE project_id=? AND ticket_id=?",
            bindings: [.text(identity.projectID), .text(identity.ticketID)]
        )
        let currentRevision = commandEvidenceInteger(set?["revision"]) ?? 0
        let expectedRevision: Int64 = switch command {
        case let .recordDeliveryEvidenceTarget(_, _, _, _, expected): expected
        case let .appendDeliveryEvidenceObservation(_, _, _, expected): expected
        default: throw DeliveryEvidenceMutationError.invalid("Evidence command is invalid")
        }
        guard currentRevision == expectedRevision else {
            throw DeliveryEvidenceMutationError.revisionConflict(
                expected: expectedRevision,
                current: currentRevision
            )
        }
        let nextRevision = currentRevision + 1
        let now = timestamp()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        switch command {
        case let .recordDeliveryEvidenceTarget(target, _, revision, expectations, _):
            let nextTargetVersion = Int((commandEvidenceInteger(set?["current_target_version"]) ?? 0) + 1)
            if set == nil {
                try connection.execute(
                    "INSERT INTO ticket_delivery_evidence_sets (project_id,ticket_id,revision,current_target_version,created_at,updated_at) VALUES (?,?,?,?,?,?)",
                    bindings: [
                        .text(identity.projectID), .text(identity.ticketID), .integer(nextRevision),
                        .integer(Int64(nextTargetVersion)), .text(now), .text(now),
                    ]
                )
            } else {
                try connection.execute(
                    "UPDATE ticket_delivery_evidence_sets SET revision=?,current_target_version=?,updated_at=? WHERE project_id=? AND ticket_id=?",
                    bindings: [
                        .integer(nextRevision), .integer(Int64(nextTargetVersion)), .text(now),
                        .text(identity.projectID), .text(identity.ticketID),
                    ]
                )
            }
            try connection.execute(
                "INSERT INTO ticket_delivery_evidence_targets (project_id,ticket_id,version,repository_id,root_id,revision_data,expectations_data,registration_id,request_generation,recorded_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                bindings: [
                    .text(identity.projectID), .text(identity.ticketID), .integer(Int64(nextTargetVersion)),
                    .text(target.repositoryID), .text(target.rootID), .blob(try encoder.encode(revision)),
                    .blob(try encoder.encode(expectations)), .text(registration.registrationID),
                    .integer(registration.requestGeneration), .text(now),
                ]
            )
        case let .appendDeliveryEvidenceObservation(_, _, observation, _):
            guard let currentTarget = commandEvidenceInteger(set?["current_target_version"]),
                  currentTarget == Int64(observation.targetVersion) else {
                throw DeliveryEvidenceMutationError.invalid("Observation target is not current")
            }
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM ticket_delivery_evidence_observations WHERE project_id=? AND ticket_id=? AND id=?",
                bindings: [.text(identity.projectID), .text(identity.ticketID), .text(observation.id)]
            ) == 0 else {
                throw DeliveryEvidenceMutationError.invalid("Observation identity already exists")
            }
            if let predecessor = observation.supersedesObservationID {
                guard try connection.scalarInt(
                    "SELECT COUNT(*) FROM ticket_delivery_evidence_observations WHERE project_id=? AND ticket_id=? AND id=? AND target_version=?",
                    bindings: [
                        .text(identity.projectID), .text(identity.ticketID), .text(predecessor),
                        .integer(Int64(observation.targetVersion)),
                    ]
                ) == 1,
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM ticket_delivery_evidence_observations WHERE project_id=? AND ticket_id=? AND supersedes_observation_id=?",
                    bindings: [.text(identity.projectID), .text(identity.ticketID), .text(predecessor)]
                ) == 0 else {
                    throw DeliveryEvidenceMutationError.invalid("Superseded observation is unavailable")
                }
            }
            if let attachment = observation.attachmentEvidenceID {
                guard try connection.scalarInt(
                    "SELECT COUNT(*) FROM evidence WHERE project_id=? AND id=? AND (ticket_id IS NULL OR ticket_id=?)",
                    bindings: [.text(identity.projectID), .text(attachment), .text(identity.ticketID)]
                ) == 1 else {
                    throw DeliveryEvidenceMutationError.invalid("Evidence attachment is unavailable")
                }
            }
            try connection.execute(
                "INSERT INTO ticket_delivery_evidence_observations (project_id,ticket_id,id,target_version,fact_data,source_data,source_availability,outcome,observed_at,recorded_at,attachment_evidence_id,supersedes_observation_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                bindings: [
                    .text(identity.projectID), .text(identity.ticketID), .text(observation.id),
                    .integer(Int64(observation.targetVersion)), .blob(try encoder.encode(observation.fact)),
                    .blob(try encoder.encode(observation.source)), .text(observation.sourceAvailability.rawValue),
                    .text(observation.outcome.rawValue), .text(observation.observedAt), .text(observation.recordedAt),
                    observation.attachmentEvidenceID.map(SQLiteValue.text) ?? .null,
                    observation.supersedesObservationID.map(SQLiteValue.text) ?? .null,
                ]
            )
            try connection.execute(
                "UPDATE ticket_delivery_evidence_sets SET revision=?,updated_at=? WHERE project_id=? AND ticket_id=?",
                bindings: [
                    .integer(nextRevision), .text(now), .text(identity.projectID), .text(identity.ticketID),
                ]
            )
        default:
            throw DeliveryEvidenceMutationError.invalid("Evidence command is invalid")
        }
        return nextRevision
    }

    private static func requireCurrentAuthorization(
        _ registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws {
        guard try connection.scalarInt(
            "SELECT COUNT(*) FROM project_registrations WHERE project_id=? AND registration_id=? AND request_generation=?",
            bindings: [
                .text(registration.projectID.rawValue), .text(registration.registrationID),
                .integer(registration.requestGeneration),
            ]
        ) == 1 else {
            throw DocumentationOperationError.staleRegistration
        }
    }

    private static func replay(
        _ connection: SQLiteConnection,
        requestID: UUID,
        body: Data,
        registration: ProjectRegistration
    ) throws -> AgentCommandResult? {
        guard let row = try connection.row(
            "SELECT request_body,result_data,registration_project_id,registration_id,request_generation FROM agent_command_requests WHERE request_id=?",
            bindings: [.text(requestID.uuidString)]
        ) else {
            return nil
        }
        guard commandEvidenceBlob(row["request_body"]) == body,
              commandEvidenceText(row["registration_project_id"]) == registration.projectID.rawValue,
              commandEvidenceText(row["registration_id"]) == registration.registrationID,
              commandEvidenceInteger(row["request_generation"]) == registration.requestGeneration,
              let result = commandEvidenceBlob(row["result_data"]),
              let decoded = try? JSONDecoder().decode(AgentCommandResult.self, from: result) else {
            throw DeliveryEvidenceControl.requestIDReused
        }
        return decoded
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func map(_ error: DeliveryEvidenceMutationError) -> AgentCommandError {
        switch error {
        case let .revisionConflict(expected, current):
            .deliveryEvidenceRevisionConflict(expected: expected, current: current)
        case .notFound: .deliveryEvidenceNotFound
        case .ticketAccepted, .ticketRetired: .deliveryEvidenceTicketAccepted
        case let .invalid(message): .invalidDeliveryEvidence(message)
        }
    }
}

private enum DeliveryEvidenceControl: Error {
    case requestIDReused
    case expired
    case replay(AgentCommandResult)
}
