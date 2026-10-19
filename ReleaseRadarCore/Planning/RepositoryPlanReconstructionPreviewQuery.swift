import CryptoKit
import Foundation

public enum RepositoryPlanReconstructionPreviewQuery {
    public static func preview(
        source: RepositoryPlanReconstructionSourceSnapshot,
        reviewedProjection: RepositoryPlanProjection,
        corrections: [RepositoryPlanReconstructionCorrection],
        explicitMappings: [RepositoryPlanReconstructionMappingSelection],
        from store: DeliveryStore
    ) async throws -> RepositoryPlanReconstructionPreview {
        try await store.read { connection in
            try preview(
                source: source,
                reviewedProjection: reviewedProjection,
                corrections: corrections,
                explicitMappings: explicitMappings,
                connection: connection
            )
        }
    }

    private static func preview(
        source: RepositoryPlanReconstructionSourceSnapshot,
        reviewedProjection: RepositoryPlanProjection,
        corrections: [RepositoryPlanReconstructionCorrection],
        explicitMappings: [RepositoryPlanReconstructionMappingSelection],
        connection: SQLiteConnection
    ) throws -> RepositoryPlanReconstructionPreview {
        try validateSource(
            source,
            reviewedProjection: reviewedProjection,
            corrections: corrections,
            connection: connection
        )
        let subjects = RepositoryPlanReconstructionPolicy.subjects(in: reviewedProjection)
        let subjectSet = Set(subjects)
        let selected = Dictionary(grouping: explicitMappings, by: \.subject)
        guard selected.values.allSatisfy({ $0.count == 1 }),
              selected.keys.allSatisfy(subjectSet.contains) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Explicit reconstruction mappings must name each reviewed subject at most once."
            )
        }

        let priorMappings = try priorMappings(
            source: source,
            projectID: source.projectID,
            connection: connection
        )
        var comparisons: [RepositoryPlanReconstructionComparison] = []
        var blockers: [RepositoryPlanReconstructionBlocker] = []

        for subject in subjects {
            if let mapping = selected[subject]?.first {
                comparisons.append(try mappedComparison(
                    subject: subject,
                    destinationID: mapping.destinationID,
                    source: source,
                    connection: connection,
                    blockers: &blockers
                ))
                continue
            }

            let prior = Set(priorMappings[subject] ?? [])
            if prior.count == 1, let destinationID = prior.first {
                comparisons.append(try mappedComparison(
                    subject: subject,
                    destinationID: destinationID,
                    source: source,
                    connection: connection,
                    blockers: &blockers
                ))
                continue
            }
            if prior.count > 1 {
                comparisons.append(comparison(subject, destinationID: nil, disposition: .blocked))
                blockers.append(.init(
                    code: "ambiguous_prior_mapping",
                    subject: subject,
                    message: "Persisted reconstruction provenance names more than one destination; select one explicitly."
                ))
                continue
            }

            if try RepositoryPlanReconstructionPolicy.destinationExists(
                kind: subject.kind,
                destinationID: subject.sourceID,
                projectID: source.projectID,
                connection: connection
            ) {
                comparisons.append(comparison(
                    subject,
                    destinationID: subject.sourceID,
                    disposition: .blocked
                ))
                blockers.append(.init(
                    code: "raw_source_id_candidate",
                    subject: subject,
                    message: "An existing record has the raw source identity; confirm that mapping explicitly before reuse."
                ))
                continue
            }

            let destinationID = RepositoryPlanReconstructionIdentity.destinationID(
                source: source,
                subject: subject
            )
            if try RepositoryPlanReconstructionPolicy.destinationExists(
                kind: subject.kind,
                destinationID: destinationID,
                projectID: source.projectID,
                connection: connection
            ) {
                comparisons.append(comparison(
                    subject,
                    destinationID: destinationID,
                    disposition: .conflicting
                ))
                blockers.append(.init(
                    code: "deterministic_destination_occupied",
                    subject: subject,
                    message: "The deterministic reconstruction destination is already occupied without reusable provenance."
                ))
            } else {
                comparisons.append(comparison(
                    subject,
                    destinationID: destinationID,
                    disposition: .new
                ))
            }
        }

        for index in comparisons.indices
            where comparisons[index].disposition == .new
                || comparisons[index].disposition == .unchanged {
            let subject = comparisons[index].subject
            if let authority = RepositoryPlanReconstructionPolicy.authorityClass(
                for: subject,
                projection: reviewedProjection
            ), authority != .currentApproved {
                comparisons[index] = comparison(
                    subject,
                    destinationID: comparisons[index].destinationID,
                    disposition: .blocked
                )
                blockers.append(.init(
                    code: "source_authority_unresolved",
                    subject: subject,
                    message: "Only source records explicitly resolved as current approved may enter the live plan."
                ))
            }
        }

        for index in comparisons.indices where comparisons[index].disposition == .unchanged {
            if try !RepositoryPlanReconstructionPolicy.exactMatch(
                comparisons[index],
                projection: reviewedProjection,
                comparisons: comparisons,
                source: source,
                projectID: source.projectID,
                connection: connection
            ) {
                let subject = comparisons[index].subject
                comparisons[index] = comparison(
                    subject,
                    destinationID: comparisons[index].destinationID,
                    disposition: .conflicting
                )
                blockers.append(.init(
                    code: "mapped_destination_conflict",
                    subject: subject,
                    message: "The selected destination does not exactly match the reviewed source fields and relationships."
                ))
            }
        }

        for index in comparisons.indices where comparisons[index].disposition == .new {
            if let message = try RepositoryPlanReconstructionPolicy.protectedAdditionMessage(
                for: comparisons[index],
                projection: reviewedProjection,
                comparisons: comparisons,
                projectID: source.projectID,
                connection: connection
            ) {
                let subject = comparisons[index].subject
                comparisons[index] = comparison(
                    subject,
                    destinationID: comparisons[index].destinationID,
                    disposition: .blocked
                )
                blockers.append(.init(
                    code: "protected_destination_addition",
                    subject: subject,
                    message: message
                ))
            }
        }

        for index in comparisons.indices
            where comparisons[index].kind == .task
                && (comparisons[index].disposition == .new
                    || comparisons[index].disposition == .unchanged) {
            let subject = comparisons[index].subject
            guard let parent = subject.parentSourceID,
                  let parentComparison = comparisons.first(where: {
                      $0.kind == .ticket && exact($0.sourceID, parent)
                  }), parentComparison.disposition != .new
                    && parentComparison.disposition != .unchanged else { continue }
            comparisons[index] = comparison(
                subject,
                destinationID: comparisons[index].destinationID,
                disposition: .blocked
            )
            blockers.append(.init(
                code: "unresolved_parent_destination",
                subject: subject,
                message: "An included task requires an included destination ticket."
            ))
        }

        let destinationSnapshots = try comparisons.compactMap { comparison in
            try destinationSnapshot(
                comparison,
                projectID: source.projectID,
                comparisons: comparisons,
                connection: connection
            )
        }
        return .init(
            comparisons: comparisons,
            blockers: blockers,
            destinationSnapshots: destinationSnapshots
        )
    }

    private static func destinationSnapshot(
        _ comparison: RepositoryPlanReconstructionComparison,
        projectID: ProjectID,
        comparisons: [RepositoryPlanReconstructionComparison],
        connection: SQLiteConnection
    ) throws -> RepositoryPlanReconstructionDestinationSnapshot? {
        guard let destinationID = comparison.destinationID else { return nil }
        let bindings: [SQLiteValue] = [.text(projectID.rawValue), .text(destinationID)]
        let fields: [String: Any]
        switch comparison.kind {
        case .phase:
            guard let row = try connection.row(
                """
                SELECT phases.name,phase_lifecycles.lifecycle,
                       phase_lifecycles.revision AS lifecycle_revision,
                       phase_lifecycles.completion_baseline_digest,
                       phase_plans.state AS plan_state,
                       phase_plans.revision AS plan_revision,
                       phase_plans.ready_revision
                FROM phases
                JOIN phase_lifecycles
                  ON phase_lifecycles.project_id=phases.project_id
                 AND phase_lifecycles.phase_id=phases.id
                LEFT JOIN phase_plans
                  ON phase_plans.project_id=phases.project_id
                 AND phase_plans.phase_id=phases.id
                WHERE phases.project_id=? AND phases.id=?
                """,
                bindings: bindings
            ) else { return nil }
            fields = jsonObject(row)
        case .ticket:
            guard let row = try connection.row(
                "SELECT outcome,phase_id,lane,plan_legacy_continuation FROM tickets WHERE project_id=? AND id=?",
                bindings: bindings
            ) else { return nil }
            var object = jsonObject(row)
            if let plan = try connection.row(
                "SELECT revision,created_at,updated_at FROM ticket_task_plans WHERE project_id=? AND ticket_id=?",
                bindings: bindings
            ) {
                object["task_plan"] = jsonObject(plan)
                object["tasks"] = try connection.rows(
                    """
                    SELECT id,label,title,sort_order,completion,lifecycle,completed_at,superseded_at
                    FROM ticket_tasks WHERE project_id=? AND ticket_id=?
                    ORDER BY sort_order,id COLLATE BINARY
                    """,
                    bindings: bindings,
                    maximum: 5_000
                ).map(jsonObject)
            }
            fields = object
        case .task:
            guard let parent = comparison.parentSourceID,
                  let destinationTicketID = comparisons.first(where: {
                      $0.kind == .ticket && exact($0.sourceID, parent)
                  }).flatMap({ $0.destinationID }),
                  let row = try connection.row(
                    """
                    SELECT label,title,sort_order,completion,lifecycle,completed_at,superseded_at
                    FROM ticket_tasks WHERE project_id=? AND ticket_id=? AND id=?
                    """,
                    bindings: [
                        .text(projectID.rawValue), .text(destinationTicketID), .text(destinationID),
                    ]
                  ) else { return nil }
            fields = jsonObject(row)
        case .phaseDependency:
            guard let row = try connection.row(
                "SELECT phase_id,depends_on_phase_id FROM phase_dependencies WHERE project_id=? AND id=?",
                bindings: bindings
            ) else { return nil }
            fields = jsonObject(row)
        case .ticketDependency:
            guard let row = try connection.row(
                "SELECT ticket_id,depends_on_ticket_id FROM ticket_dependencies WHERE project_id=? AND id=?",
                bindings: bindings
            ) else { return nil }
            fields = jsonObject(row)
        }
        return .init(
            subject: comparison.subject,
            destinationID: destinationID,
            fields: try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        )
    }

    private static func jsonObject(_ row: [String: SQLiteValue]) -> [String: Any] {
        row.reduce(into: [:]) { result, item in
            switch item.value {
            case let .integer(value): result[item.key] = value
            case let .real(value): result[item.key] = value
            case let .text(value): result[item.key] = value
            case let .blob(value): result[item.key] = value.base64EncodedString()
            case .null: result[item.key] = NSNull()
            }
        }
    }

    private static func mappedComparison(
        subject: RepositoryPlanReconstructionSubject,
        destinationID: String,
        source: RepositoryPlanReconstructionSourceSnapshot,
        connection: SQLiteConnection,
        blockers: inout [RepositoryPlanReconstructionBlocker]
    ) throws -> RepositoryPlanReconstructionComparison {
        guard !destinationID.isEmpty,
              try RepositoryPlanReconstructionPolicy.destinationExists(
                  kind: subject.kind,
                  destinationID: destinationID,
                  projectID: source.projectID,
                  connection: connection
              ) else {
            blockers.append(.init(
                code: "mapped_destination_missing",
                subject: subject,
                message: "The selected reconstruction destination no longer exists."
            ))
            return comparison(subject, destinationID: destinationID, disposition: .blocked)
        }
        return comparison(subject, destinationID: destinationID, disposition: .unchanged)
    }

    private static func comparison(
        _ subject: RepositoryPlanReconstructionSubject,
        destinationID: String?,
        disposition: RepositoryPlanReconstructionComparisonDisposition
    ) -> RepositoryPlanReconstructionComparison {
        .init(
            kind: subject.kind,
            parentSourceID: subject.parentSourceID,
            sourceID: subject.sourceID,
            destinationID: destinationID,
            disposition: disposition
        )
    }

    private static func priorMappings(
        source: RepositoryPlanReconstructionSourceSnapshot,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> [RepositoryPlanReconstructionSubject: [String]] {
        let readbacks = try RepositoryPlanReconstructionQuery.load(
            from: connection,
            projectID: projectID
        )
        var result: [RepositoryPlanReconstructionSubject: [String]] = [:]
        for readback in readbacks
            where exact(readback.payload.source.repositoryID, source.repositoryID)
                && readback.payload.source.projectionID == source.projectionID {
            for record in readback.provenance {
                guard let destinationID = record.comparison.destinationID else { continue }
                result[record.comparison.subject, default: []].append(destinationID)
            }
        }
        return result
    }

    private static func validateSource(
        _ source: RepositoryPlanReconstructionSourceSnapshot,
        reviewedProjection: RepositoryPlanProjection,
        corrections: [RepositoryPlanReconstructionCorrection],
        connection: SQLiteConnection
    ) throws {
        guard source.capturedSourceManifest.projectID == source.projectID,
              source.capturedSourceManifest.registration == source.registration,
              exact(source.rootID, source.capturedSourceManifest.rootID),
              exact(source.repositoryID, source.capturedSourceManifest.repositoryID),
              source.acceptedCatalogVersion == source.capturedSourceManifest.acceptedCatalogVersion,
              exact(source.acceptedCatalogDigest, source.capturedSourceManifest.acceptedCatalogDigest),
              digest(source.projectionBytes) == source.projectionSHA256,
              let registration = try connection.row(
                  "SELECT registration_id,request_generation FROM project_registrations WHERE project_id=?",
                  bindings: [.text(source.projectID.rawValue)]
              ),
              registration["registration_id"] == .text(source.registration.registrationID),
              registration["request_generation"] == .integer(source.registration.requestGeneration),
              let binding = try connection.row(
                  """
                  SELECT root_id,repository_id,accepted_catalog_version,accepted_catalog_digest
                  FROM project_documentation_bindings WHERE project_id=?
                  """,
                  bindings: [.text(source.projectID.rawValue)]
              ),
              binding["root_id"] == .text(source.rootID),
              binding["repository_id"] == .text(source.repositoryID),
              binding["accepted_catalog_version"] == .integer(Int64(source.acceptedCatalogVersion)),
              binding["accepted_catalog_digest"] == .text(source.acceptedCatalogDigest)
        else { throw RepositoryPlanReconstructionError.staleSource }

        let original = try RepositoryPlanProjectionValidator.validate(
            source.projectionBytes,
            against: source.capturedSourceManifest
        )
        let derived = try RepositoryPlanReconstructionCorrections.apply(
            corrections,
            to: original.projection
        )
        guard original.contentSHA256 == source.projectionSHA256,
              derived == reviewedProjection,
              source.projectionRevision == reviewedProjection.projectionRevision,
              exact(source.repositoryID, reviewedProjection.repositoryID),
              exact(
                  source.projectionID.uuidString.lowercased(),
                  reviewedProjection.projectionID.lowercased()
              ) else { throw RepositoryPlanReconstructionError.staleSource }
        try RepositoryPlanReconstructionPolicy.validateReviewedProjection(
            reviewedProjection,
            manifest: source.capturedSourceManifest
        )
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func exact(_ lhs: String, _ rhs: String) -> Bool {
        Data(lhs.utf8) == Data(rhs.utf8)
    }
}
