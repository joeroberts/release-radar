import Foundation

public enum RepositoryPlanPreparationPersistence {
    public static func begin(
        request: RepositoryPlanPreparationRequest,
        requestID: UUID,
        in store: DeliveryStore
    ) async throws -> RepositoryPlanPreparationRecord {
        try validate(request)
        let requestData = try encode(request)
        return try await store.transactRepositoryPlanRecovery { connection in
            let identity = request.identity
            try ProjectLifecycleManager.requireCurrentAuthorization(
                projectID: identity.registration.projectID,
                registration: identity.registration,
                connection: connection
            )
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM project_roots WHERE project_id=? AND id=?",
                bindings: [
                    .text(identity.registration.projectID.rawValue), .text(identity.rootID),
                ]
            ) == 1 else { throw RepositoryPlanReconstructionError.preparationConflict }
            if let existing = try connection.row(
                """
                SELECT * FROM repository_plan_preparation_attempts
                WHERE project_id=? AND proposal_id=? AND is_current=1
                """,
                bindings: [
                    .text(identity.registration.projectID.rawValue),
                    .text(identity.proposalID.rawValue),
                ]
            ) {
                if existing["attempt_id"] == .text(identity.attemptID.uuidString),
                   existing["request_id"] == .text(requestID.uuidString),
                   existing["request_data"] == .blob(requestData) {
                    return try decode(existing)
                }
                guard case let .text(rawState)? = existing["state"],
                      let state = RepositoryPlanPreparationState(rawValue: rawState),
                      [.readyForReview, .failed, .cancelled].contains(state),
                      case let .text(previousAttempt)? = existing["attempt_id"] else {
                    throw RepositoryPlanReconstructionError.preparationConflict
                }
                try connection.execute(
                    """
                    UPDATE repository_plan_preparation_attempts
                    SET is_current=0,replaced_by_attempt_id=?,revision=revision+1,updated_at=?
                    WHERE project_id=? AND proposal_id=? AND attempt_id=? AND is_current=1
                    """,
                    bindings: [
                        .text(identity.attemptID.uuidString), .text(timestamp()),
                        .text(identity.registration.projectID.rawValue),
                        .text(identity.proposalID.rawValue), .text(previousAttempt),
                    ]
                )
            }
            let now = timestamp()
            try connection.execute(
                """
                INSERT INTO repository_plan_preparation_attempts (
                    project_id,proposal_id,attempt_id,request_id,registration_id,
                    request_generation,root_id,request_data,revision,state,thread_id,
                    turn_id,draft_data,error,is_current,replaced_by_attempt_id,created_at,updated_at
                ) VALUES (?,?,?,?,?,?,?,?,1,'queued',NULL,NULL,NULL,NULL,1,NULL,?,?)
                """,
                bindings: [
                    .text(identity.registration.projectID.rawValue),
                    .text(identity.proposalID.rawValue), .text(identity.attemptID.uuidString),
                    .text(requestID.uuidString), .text(identity.registration.registrationID),
                    .integer(identity.registration.requestGeneration), .text(identity.rootID),
                    .blob(requestData), .text(now), .text(now),
                ]
            )
            guard let row = try connection.row(
                "SELECT * FROM repository_plan_preparation_attempts WHERE request_id=?",
                bindings: [.text(requestID.uuidString)]
            ) else { throw RepositoryPlanReconstructionError.preparationConflict }
            return try decode(row)
        }
    }

    public static func record(
        identity: RepositoryPlanPreparationIdentity,
        expectedRevision: Int64,
        readback: RepositoryPlanPreparationReadback,
        in store: DeliveryStore
    ) async throws -> RepositoryPlanPreparationRecord {
        guard readback.identity == identity else {
            throw RepositoryPlanReconstructionError.invalidPreparationTransition
        }
        if let draft = readback.draftBytes,
           readback.state != .readyForReview || draft.count > RepositoryPlanProjectionValidator.maximumProjectionBytes {
            throw RepositoryPlanReconstructionError.invalidPreparationTransition
        }
        if readback.state == .readyForReview, readback.draftBytes == nil {
            throw RepositoryPlanReconstructionError.invalidPreparationTransition
        }
        return try await store.transactRepositoryPlanRecovery { connection in
            guard let current = try connection.row(
                """
                SELECT * FROM repository_plan_preparation_attempts
                WHERE project_id=? AND proposal_id=? AND attempt_id=?
                """,
                bindings: [
                    .text(identity.registration.projectID.rawValue),
                    .text(identity.proposalID.rawValue), .text(identity.attemptID.uuidString),
                ]
            ) else { throw RepositoryPlanReconstructionError.preparationConflict }
            let record = try decode(current)
            try ProjectLifecycleManager.requireCurrentAuthorization(
                projectID: identity.registration.projectID,
                registration: identity.registration,
                connection: connection
            )
            guard record.isCurrent, record.replacedByAttemptID == nil,
                  record.request.identity == identity else {
                throw RepositoryPlanReconstructionError.preparationConflict
            }
            guard record.revision == expectedRevision else {
                throw RepositoryPlanReconstructionError.preparationRevisionConflict(
                    expected: expectedRevision,
                    current: record.revision
                )
            }
            guard permits(from: record.state, to: readback.state) else {
                throw RepositoryPlanReconstructionError.invalidPreparationTransition
            }
            try connection.execute(
                """
                UPDATE repository_plan_preparation_attempts
                SET revision=revision+1,state=?,thread_id=?,turn_id=?,draft_data=?,error=?,updated_at=?
                WHERE project_id=? AND proposal_id=? AND attempt_id=? AND revision=? AND is_current=1
                """,
                bindings: [
                    .text(readback.state.rawValue),
                    readback.threadID.map(SQLiteValue.text) ?? .null,
                    readback.turnID.map(SQLiteValue.text) ?? .null,
                    readback.draftBytes.map(SQLiteValue.blob) ?? .null,
                    readback.error.map(SQLiteValue.text) ?? .null, .text(timestamp()),
                    .text(identity.registration.projectID.rawValue),
                    .text(identity.proposalID.rawValue), .text(identity.attemptID.uuidString),
                    .integer(expectedRevision),
                ]
            )
            guard let updated = try connection.row(
                """
                SELECT * FROM repository_plan_preparation_attempts
                WHERE project_id=? AND proposal_id=? AND attempt_id=?
                """,
                bindings: [
                    .text(identity.registration.projectID.rawValue),
                    .text(identity.proposalID.rawValue), .text(identity.attemptID.uuidString),
                ]
            ) else { throw RepositoryPlanReconstructionError.preparationConflict }
            return try decode(updated)
        }
    }

    public static func load(
        projectID: ProjectID,
        from store: DeliveryStore
    ) async throws -> [RepositoryPlanPreparationRecord] {
        try await store.read { connection in
            try connection.rows(
                """
                SELECT * FROM repository_plan_preparation_attempts
                WHERE project_id=? ORDER BY created_at,proposal_id,attempt_id
                """,
                bindings: [.text(projectID.rawValue)],
                maximum: 10_000
            ).map(decode)
        }
    }

    private static func validate(_ request: RepositoryPlanPreparationRequest) throws {
        let identity = request.identity
        let manifest = request.sourceManifest
        guard identity.registration.projectID == manifest.projectID,
              identity.registration == manifest.registration,
              identity.rootID == manifest.rootID,
              request.projectionRevision > 0,
              request.snapshot.rootPath.hasPrefix("/"),
              request.snapshot.workingPath.hasPrefix(request.snapshot.rootPath + "/"),
              !request.model.isEmpty, !request.effort.isEmpty else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The preparation request identity or source snapshot is invalid."
            )
        }
    }

    private static func permits(
        from: RepositoryPlanPreparationState,
        to: RepositoryPlanPreparationState
    ) -> Bool {
        if from == to { return true }
        return switch from {
        case .queued:
            [.running, .readyForReview, .failed, .cancelled, .outcomeUnknown].contains(to)
        case .running:
            [.awaitingResolution, .readyForReview, .failed, .cancelled, .outcomeUnknown].contains(to)
        case .awaitingResolution:
            [.running, .readyForReview, .failed, .cancelled, .outcomeUnknown].contains(to)
        case .outcomeUnknown:
            [.failed, .cancelled].contains(to)
        case .readyForReview, .failed, .cancelled:
            false
        }
    }

    private static func decode(_ row: [String: SQLiteValue]) throws -> RepositoryPlanPreparationRecord {
        guard case let .blob(requestData)? = row["request_data"],
              let request = try? JSONDecoder().decode(RepositoryPlanPreparationRequest.self, from: requestData),
              case let .text(requestID)? = row["request_id"], let requestUUID = UUID(uuidString: requestID),
              case let .integer(revision)? = row["revision"],
              case let .text(rawState)? = row["state"], let state = RepositoryPlanPreparationState(rawValue: rawState),
              case let .integer(isCurrent)? = row["is_current"],
              case let .text(createdAt)? = row["created_at"], let created = date(createdAt),
              case let .text(updatedAt)? = row["updated_at"], let updated = date(updatedAt)
        else { throw RepositoryPlanReconstructionError.preparationConflict }
        return .init(
            requestID: requestUUID,
            request: request,
            revision: revision,
            state: state,
            threadID: text(row["thread_id"]),
            turnID: text(row["turn_id"]),
            draftBytes: blob(row["draft_data"]),
            error: text(row["error"]),
            isCurrent: isCurrent == 1,
            replacedByAttemptID: text(row["replaced_by_attempt_id"]).flatMap { UUID(uuidString: $0) },
            createdAt: created,
            updatedAt: updated
        )
    }

    private static func encode(_ value: RepositoryPlanPreparationRequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func text(_ value: SQLiteValue?) -> String? {
        guard case let .text(value)? = value else { return nil }
        return value
    }

    private static func blob(_ value: SQLiteValue?) -> Data? {
        guard case let .blob(value)? = value else { return nil }
        return value
    }

    private static func timestamp() -> String { timestamp(Date()) }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
