import Foundation

public enum RepositoryPlanReconstructionQuery {
    public static func load(
        from store: DeliveryStore,
        projectID: ProjectID,
        proposalID: PlanChangeProposalID? = nil
    ) async throws -> [RepositoryPlanReconstructionReadback] {
        try await store.read { connection in
            try load(from: connection, projectID: projectID, proposalID: proposalID)
        }
    }

    static func load(
        from connection: SQLiteConnection,
        projectID: ProjectID,
        proposalID: PlanChangeProposalID? = nil
    ) throws -> [RepositoryPlanReconstructionReadback] {
            let proposals = try PlanChangeProposalQuery.load(from: connection, projectID: projectID)
            let selected = proposalID.map { id in
                proposals.filter { $0.id == id }
            } ?? proposals
            var readbacks: [RepositoryPlanReconstructionReadback] = []
            for proposal in selected {
                for version in proposal.versions {
                    guard version.operations.count == 1,
                          case let .reconstructRepositoryPlan(payload) = version.operations[0]
                    else { continue }
                    let attempt = try loadAttempt(
                        connection,
                        projectID: projectID,
                        proposalID: proposal.id,
                        version: version.version
                    )
                    let provenance = try loadProvenance(
                        connection,
                        projectID: projectID,
                        proposalID: proposal.id,
                        version: version.version
                    )
                    readbacks.append(.init(
                        proposalID: proposal.id,
                        version: version,
                        payload: payload,
                        applicationAttempt: attempt,
                        provenance: provenance,
                        remainingSetup: payload.blockers.map(\.message)
                    ))
                }
            }
            return readbacks
    }

    private static func loadAttempt(
        _ connection: SQLiteConnection,
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64
    ) throws -> RepositoryPlanReconstructionApplicationAttemptRecord? {
        guard let row = try connection.row(
            """
            SELECT * FROM repository_plan_reconstruction_application_attempts
            WHERE project_id=? AND proposal_id=? AND version=?
            """,
            bindings: [
                .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
            ]
        ) else { return nil }
        guard case let .text(applicationID)? = row["application_id"],
              case let .text(requestID)? = row["request_id"], let requestUUID = UUID(uuidString: requestID),
              case let .text(registrationID)? = row["registration_id"],
              case let .integer(generation)? = row["request_generation"],
              case let .blob(envelope)? = row["envelope_data"],
              case let .text(rawState)? = row["state"],
              let state = RepositoryPlanReconstructionApplicationAttemptState(rawValue: rawState)
        else { throw RepositoryPlanReconstructionError.applicationAttemptConflict }
        let result: AgentCommandResult?
        if case let .blob(data)? = row["result_data"] {
            result = try JSONDecoder().decode(AgentCommandResult.self, from: data)
        } else { result = nil }
        return .init(
            projectID: projectID,
            proposalID: proposalID,
            version: version,
            applicationID: applicationID,
            requestID: requestUUID,
            registration: .init(
                projectID: projectID,
                registrationID: registrationID,
                requestGeneration: generation
            ),
            envelopeBytes: envelope,
            state: state,
            result: result
        )
    }

    private static func loadProvenance(
        _ connection: SQLiteConnection,
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64
    ) throws -> [RepositoryPlanReconstructionProvenanceRecord] {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        return try connection.rows(
            """
            SELECT * FROM repository_plan_reconstruction_provenance
            WHERE project_id=? AND proposal_id=? AND version=?
            ORDER BY record_kind,parent_source_id,source_id
            """,
            bindings: [
                .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
            ],
            maximum: 30_000
        ).map { row in
            guard case let .text(applicationID)? = row["application_id"],
                  case let .text(rawKind)? = row["record_kind"],
                  let kind = RepositoryPlanReconstructionRecordKind(rawValue: rawKind),
                  case let .text(parent)? = row["parent_source_id"],
                  case let .text(sourceID)? = row["source_id"],
                  case let .text(rawDisposition)? = row["disposition"],
                  let disposition = RepositoryPlanReconstructionComparisonDisposition(rawValue: rawDisposition),
                  case let .blob(sourceFields)? = row["source_fields_data"],
                  case let .blob(sourceRefsData)? = row["source_refs_data"],
                  case let .blob(evidenceData)? = row["evidence_data"]
            else { throw RepositoryPlanReconstructionError.staleSource }
            let destinationID: String?
            if case let .text(value)? = row["destination_id"] { destinationID = value }
            else { destinationID = nil }
            let occurredAt: Date?
            if case let .text(value)? = row["original_occurred_at"] {
                occurredAt = formatter.date(from: value)
            } else { occurredAt = nil }
            let actorID: String?
            if case let .text(value)? = row["original_actor_id"] { actorID = value }
            else { actorID = nil }
            return .init(
                proposalID: proposalID,
                version: version,
                applicationID: applicationID,
                comparison: .init(
                    kind: kind,
                    parentSourceID: parent.isEmpty ? nil : parent,
                    sourceID: sourceID,
                    destinationID: destinationID,
                    disposition: disposition
                ),
                sourceFields: sourceFields,
                sourceRefs: try decoder.decode([RepositoryPlanSourceReference].self, from: sourceRefsData),
                evidence: try decoder.decode([RepositoryPlanTerminalEvidence].self, from: evidenceData),
                originalOccurredAt: occurredAt,
                originalActorID: actorID
            )
        }
    }
}
