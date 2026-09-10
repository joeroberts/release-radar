import Foundation

private func evidenceText(_ value: SQLiteValue?) -> String? {
    guard case let .text(text)? = value else { return nil }
    return text
}

private func evidenceInteger(_ value: SQLiteValue?) -> Int64? {
    guard case let .integer(integer)? = value else { return nil }
    return integer
}

private func evidenceBlob(_ value: SQLiteValue?) -> Data? {
    guard case let .blob(data)? = value else { return nil }
    return data
}

struct DeliveryEvidenceCapture: Sendable {
    let context: DocumentationRootContext
    private let projectID: String
    private let ticketID: String
    private let phaseID: String?
    private let phaseLabel: String
    private let ownerAcceptance: DeliveryEvidenceOwnerAcceptance
    private let revision: Int64
    private let currentTargetVersion: Int?
    private let targets: [DeliveryEvidenceTargetVersion]
    private let observations: [DeliveryEvidenceObservation]

    init(_ connection: SQLiteConnection, context: DocumentationRootContext, ticketID: String) throws {
        guard let ticket = try connection.row(
            "SELECT tickets.phase_id,tickets.lane,phases.name FROM tickets LEFT JOIN phases ON phases.project_id=tickets.project_id AND phases.id=tickets.phase_id WHERE tickets.project_id=? AND tickets.id=?",
            bindings: [.text(context.projectID), .text(ticketID)]
        ) else {
            throw DeliveryEvidenceMutationError.notFound
        }
        self.context = context
        projectID = context.projectID
        self.ticketID = ticketID
        phaseID = evidenceText(ticket["phase_id"])
        phaseLabel = evidenceText(ticket["name"]) ?? "Not placed"
        ownerAcceptance = evidenceText(ticket["lane"]) == TicketLane.accepted.rawValue ? .accepted : .notAccepted

        let set = try connection.row(
            "SELECT revision,current_target_version FROM ticket_delivery_evidence_sets WHERE project_id=? AND ticket_id=?",
            bindings: [.text(context.projectID), .text(ticketID)]
        )
        revision = evidenceInteger(set?["revision"]) ?? 0
        currentTargetVersion = evidenceInteger(set?["current_target_version"]).map(Int.init)

        let decoder = JSONDecoder()
        targets = try connection.rows(
            "SELECT * FROM ticket_delivery_evidence_targets WHERE project_id=? AND ticket_id=? ORDER BY version DESC",
            bindings: [.text(context.projectID), .text(ticketID)],
            maximum: 1024
        ).map { row in
            guard let version = evidenceInteger(row["version"]),
                  let repositoryID = evidenceText(row["repository_id"]),
                  let rootID = evidenceText(row["root_id"]),
                  let revisionData = evidenceBlob(row["revision_data"]),
                  let expectationsData = evidenceBlob(row["expectations_data"]),
                  let registrationID = evidenceText(row["registration_id"]),
                  let requestGeneration = evidenceInteger(row["request_generation"]),
                  let recordedAt = evidenceText(row["recorded_at"]) else {
                throw DeliveryEvidenceMutationError.invalid("Stored evidence target is invalid")
            }
            return .init(
                version: Int(version),
                repositoryID: repositoryID,
                rootID: rootID,
                revision: try decoder.decode(DeliveryEvidenceRevision.self, from: revisionData),
                expectations: try decoder.decode([DeliveryEvidenceExpectation].self, from: expectationsData),
                registrationID: registrationID,
                requestGeneration: Int(requestGeneration),
                recordedAt: recordedAt
            )
        }
        observations = try connection.rows(
            "SELECT * FROM ticket_delivery_evidence_observations WHERE project_id=? AND ticket_id=? ORDER BY recorded_at,id",
            bindings: [.text(context.projectID), .text(ticketID)],
            maximum: 4096
        ).map { row in
            guard let id = evidenceText(row["id"]),
                  let targetVersion = evidenceInteger(row["target_version"]),
                  let factData = evidenceBlob(row["fact_data"]),
                  let sourceData = evidenceBlob(row["source_data"]),
                  let sourceAvailability = evidenceText(row["source_availability"]).flatMap(DeliveryEvidenceSourceAvailability.init(rawValue:)),
                  let outcome = evidenceText(row["outcome"]).flatMap(DeliveryEvidenceOutcome.init(rawValue:)),
                  let observedAt = evidenceText(row["observed_at"]),
                  let recordedAt = evidenceText(row["recorded_at"]) else {
                throw DeliveryEvidenceMutationError.invalid("Stored evidence observation is invalid")
            }
            return .init(
                id: id,
                targetVersion: Int(targetVersion),
                fact: try decoder.decode(DeliveryEvidenceFact.self, from: factData),
                source: try decoder.decode(DeliveryEvidenceSource.self, from: sourceData),
                sourceAvailability: sourceAvailability,
                outcome: outcome,
                observedAt: observedAt,
                recordedAt: recordedAt,
                attachmentEvidenceID: evidenceText(row["attachment_evidence_id"]),
                supersedesObservationID: evidenceText(row["supersedes_observation_id"])
            )
        }
    }

    func resolve() -> TicketDeliveryEvidence {
        let currentTarget = currentTargetVersion.flatMap { version in
            targets.first(where: { $0.version == version })
        }
        var currentDocuments: [String: (availability: DeliveryEvidenceSourceAvailability, digest: String?, catalogVersion: Int?, catalogDigest: String?)] = [:]
        do {
            let catalog = try DocumentationCatalogContext(root: context.root)
            let snapshot = try catalog.managedSnapshot()
            try context.requireAccepted(snapshot)
            for observation in observations {
                guard case let .document(fact) = observation.fact else { continue }
                guard fact.repositoryID == snapshot.catalog.repositoryID.lowercased(),
                      let artifact = snapshot.catalog.artifacts.first(where: { $0.artifactID == fact.artifactID }) else {
                    currentDocuments[observation.id] = (.unavailable, nil, snapshot.version, snapshot.digest)
                    continue
                }
                do {
                    let bytes = try catalog.reader.read(artifact.path)
                    currentDocuments[observation.id] = (
                        .available, documentationDigest(bytes), snapshot.version, snapshot.digest
                    )
                } catch {
                    currentDocuments[observation.id] = (.unavailable, nil, snapshot.version, snapshot.digest)
                }
            }
            try catalog.reader.verifyStable()
        } catch {
            for observation in observations where observation.fact.category == .document {
                currentDocuments[observation.id] = (.unavailable, nil, nil, nil)
            }
        }

        let resolved = observations.map { observation -> DeliveryEvidenceResolvedObservation in
            var applicability = currentTarget.map {
                DeliveryEvidenceApplicabilityEvaluator.evaluate(observation, against: $0)
            } ?? .init(state: .unknown, reasons: [.revisionUnknown])
            var currentAvailability = observation.sourceAvailability
            var digest: String?
            if case let .document(fact) = observation.fact,
               let current = currentDocuments[observation.id] {
                currentAvailability = current.availability
                digest = current.digest
                if current.availability == .available {
                    var reasons = applicability.reasons
                    if current.digest != fact.contentDigest {
                        reasons.append(.documentContentChanged)
                    }
                    if current.catalogVersion != fact.catalogVersion || current.catalogDigest != fact.catalogDigest {
                        reasons.append(.documentCatalogChanged)
                    }
                    if !reasons.isEmpty {
                        applicability = .init(state: .stale, reasons: reasons)
                    }
                }
            }
            return .init(
                observation: observation,
                applicability: applicability,
                currentSourceAvailability: currentAvailability,
                currentDocumentDigest: digest
            )
        }
        return .init(
            projectID: projectID,
            ticketID: ticketID,
            phaseID: phaseID,
            phaseLabel: phaseLabel,
            revision: revision,
            currentTargetVersion: currentTargetVersion,
            targets: targets,
            observations: resolved,
            expectations: currentTarget.map {
                DeliveryEvidenceApplicabilityEvaluator.assessExpectations(
                    target: $0,
                    resolvedObservations: resolved
                )
            } ?? [],
            ownerAcceptance: ownerAcceptance
        )
    }
}
