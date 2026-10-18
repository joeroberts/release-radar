import CryptoKit
import Foundation

enum RepositoryPlanReconstructionPolicy {
    private static let ownerActorID = "release-radar-owner"

    static func exactMatch(
        _ comparison: RepositoryPlanReconstructionComparison,
        projection: RepositoryPlanProjection,
        comparisons: [RepositoryPlanReconstructionComparison],
        source: RepositoryPlanReconstructionSourceSnapshot,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> Bool {
        do {
            try requireExactMatch(
                comparison,
                projection: projection,
                comparisons: comparisons,
                source: source,
                projectID: projectID,
                connection: connection
            )
            return true
        } catch RepositoryPlanReconstructionError.staleSource {
            return false
        }
    }

    static func destinationExists(
        kind: RepositoryPlanReconstructionRecordKind,
        destinationID: String,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> Bool {
        let table = switch kind {
        case .phase: "phases"
        case .ticket: "tickets"
        case .task: "ticket_tasks"
        case .phaseDependency: "phase_dependencies"
        case .ticketDependency: "ticket_dependencies"
        }
        return try connection.scalarInt(
            "SELECT COUNT(*) FROM \(table) WHERE project_id=? AND id=?",
            bindings: [.text(projectID.rawValue), .text(destinationID)]
        ) == 1
    }

    static func protectedAdditionMessage(
        for comparison: RepositoryPlanReconstructionComparison,
        projection: RepositoryPlanProjection,
        comparisons: [RepositoryPlanReconstructionComparison],
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> String? {
        guard comparison.disposition == .new else { return nil }
        switch comparison.kind {
        case .ticket:
            guard let ticket = projection.tickets.first(where: {
                exact($0.sourceID, comparison.sourceID)
            }), let phaseSourceID = ticket.phaseSourceID,
            let phaseComparison = comparisonFor(
                phaseSourceID,
                kind: .phase,
                in: comparisons
            ), phaseComparison.disposition == .unchanged,
            let phaseID = phaseComparison.destinationID else { return nil }
            if try connection.scalarText(
                "SELECT lifecycle FROM phase_lifecycles WHERE project_id=? AND phase_id=?",
                bindings: [.text(projectID.rawValue), .text(phaseID)]
            ) == PhaseLifecycle.completed.rawValue {
                return "Repository reconstruction cannot add a ticket to a completed destination phase."
            }
        case .task:
            guard let parentSourceID = comparison.parentSourceID,
                  let ticketComparison = comparisonFor(
                      parentSourceID,
                      kind: .ticket,
                      in: comparisons
                  ), ticketComparison.disposition == .unchanged else { return nil }
            return "Repository reconstruction cannot append tasks to an existing destination ticket; use the ordinary reviewed task-plan revision path."
        case .phase, .phaseDependency, .ticketDependency:
            return nil
        }
        return nil
    }

    static func diff(for payload: RepositoryPlanReconstructionPayload) -> PlanChangeDiff {
        let items = payload.comparisons.map {
            PlanChangeDiffItem(summary: "\($0.disposition.rawValue.capitalized) \($0.kind.rawValue) \($0.sourceID)" +
                ($0.destinationID.map { " → \($0)" } ?? ""))
        }
        return .init(groups: items.isEmpty ? [] : [.init(kind: .tickets, items: items)])
    }

    static func validateForSave(
        _ payload: RepositoryPlanReconstructionPayload,
        projectID: ProjectID,
        registration: ProjectRegistration,
        actorID: String,
        connection: SQLiteConnection
    ) throws {
        let source = payload.source
        guard source.projectID == projectID,
              source.registration == registration,
              source.capturedSourceManifest.projectID == projectID,
              source.capturedSourceManifest.registration == registration,
              exact(source.rootID, source.capturedSourceManifest.rootID),
              exact(source.repositoryID, source.capturedSourceManifest.repositoryID),
              source.acceptedCatalogVersion == source.capturedSourceManifest.acceptedCatalogVersion,
              exact(source.acceptedCatalogDigest, source.capturedSourceManifest.acceptedCatalogDigest),
              source.projectionRevision == payload.reviewedProjection.projectionRevision,
              source.projectionRevision > 0,
              exact(source.repositoryID, payload.reviewedProjection.repositoryID),
              exact(source.projectionID.uuidString.lowercased(), payload.reviewedProjection.projectionID.lowercased()),
              digest(source.projectionBytes) == source.projectionSHA256
        else { throw RepositoryPlanReconstructionError.staleSource }

        let validated = try RepositoryPlanProjectionValidator.validate(
            source.projectionBytes,
            against: source.capturedSourceManifest
        )
        let reviewedProjection = try RepositoryPlanReconstructionCorrections.apply(
            payload.corrections,
            to: validated.projection
        )
        guard reviewedProjection == payload.reviewedProjection,
              validated.contentSHA256 == source.projectionSHA256,
              let binding = try connection.row(
                """
                SELECT root_id,repository_id,accepted_catalog_version,accepted_catalog_digest
                FROM project_documentation_bindings WHERE project_id=?
                """,
                bindings: [.text(projectID.rawValue)]
              ),
              binding["root_id"] == .text(source.rootID),
              binding["repository_id"] == .text(source.repositoryID),
              binding["accepted_catalog_version"] == .integer(Int64(source.acceptedCatalogVersion)),
              binding["accepted_catalog_digest"] == .text(source.acceptedCatalogDigest)
        else { throw RepositoryPlanReconstructionError.staleSource }
        try validateReviewedProjection(reviewedProjection, manifest: source.capturedSourceManifest)

        let expected = expectedSubjects(payload.reviewedProjection)
        let comparisons = Dictionary(grouping: payload.comparisons, by: \.subject)
        guard comparisons.count == expected.count,
              comparisons.values.allSatisfy({ $0.count == 1 }),
              Set(comparisons.keys) == expected
        else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "The exact comparison must classify every projected phase, ticket, task, and dependency once."
            )
        }
        let exclusions = Dictionary(grouping: payload.exclusions, by: \.subject)
        guard exclusions.values.allSatisfy({ $0.count == 1 }) else {
            throw RepositoryPlanReconstructionError.invalidPayload("Each excluded record needs one reason.")
        }
        var correctedFields = Set<String>()
        for correction in payload.corrections {
            let key = "\(correction.subject.kind.rawValue)\0\(correction.subject.parentSourceID ?? "")\0\(correction.subject.sourceID)\0\(correction.field)"
            guard expected.contains(correction.subject), !correction.field.isEmpty,
                  correction.field.utf8.count <= 256,
                  correction.chosenValue.count <= RepositoryPlanProjectionValidator.maximumProjectionBytes,
                  correctedFields.insert(key).inserted else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Corrections must be unique, bounded, and name a reviewed source field."
                )
            }
        }

        for comparison in payload.comparisons {
            if comparison.disposition == .new || comparison.disposition == .unchanged,
               let authority = authorityClass(
                   for: comparison.subject,
                   projection: payload.reviewedProjection
               ), authority != .currentApproved {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Only explicitly current-approved source records may enter the live plan."
                )
            }
            switch comparison.disposition {
            case .new:
                let expectedDestination = RepositoryPlanReconstructionIdentity.destinationID(
                    source: source, subject: comparison.subject
                )
                guard comparison.destinationID == nil || comparison.destinationID == expectedDestination else {
                    throw RepositoryPlanReconstructionError.invalidPayload(
                        "New reconstruction records must use their deterministic destination identity."
                    )
                }
                try requireAbsent(
                    destinationID: expectedDestination,
                    kind: comparison.kind,
                    projectID: projectID,
                    connection: connection
                )
            case .unchanged:
                guard comparison.destinationID != nil else {
                    throw RepositoryPlanReconstructionError.invalidPayload("Unchanged records require a destination identity.")
                }
                try requireExactMatch(
                    comparison,
                    projection: payload.reviewedProjection,
                    comparisons: payload.comparisons,
                    source: source,
                    projectID: projectID,
                    connection: connection
                )
            case .conflicting, .blocked:
                guard payload.blockers.contains(where: { $0.subject == comparison.subject }) else {
                    throw RepositoryPlanReconstructionError.invalidPayload(
                        "Every conflicting or blocked comparison requires a matching blocker."
                    )
                }
            case .excluded:
                guard exclusions[comparison.subject]?.first?.reason
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw RepositoryPlanReconstructionError.invalidPayload(
                        "Every excluded comparison requires a nonempty reason."
                    )
                }
            }
        }

        let phaseDestinations = destinationMap(payload.comparisons, kind: .phase, source: source)
        let ticketDestinations = destinationMap(payload.comparisons, kind: .ticket, source: source)
        for ticket in payload.reviewedProjection.tickets {
            let ticketSubject = RepositoryPlanReconstructionSubject(
                kind: .ticket, parentSourceID: nil, sourceID: ticket.sourceID
            )
            if !isIncluded(ticketSubject, comparisons: payload.comparisons),
               (ticket.taskPlan?.tasks ?? []).contains(where: { task in
                   isIncluded(
                       .init(
                           kind: .task,
                           parentSourceID: ticket.sourceID,
                           sourceID: task.sourceID
                       ),
                       comparisons: payload.comparisons
                   )
               }) {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "An included reconstructed task requires its destination ticket to be included."
                )
            }
            guard let ticketComparison = comparisonFor(
                ticket.sourceID,
                kind: .ticket,
                in: payload.comparisons
            ), ticketComparison.disposition == .new || ticketComparison.disposition == .unchanged
            else { continue }
            if let phaseSourceID = ticket.phaseSourceID,
               phaseDestinations[phaseSourceID] == nil {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "A reconstructed ticket cannot target an excluded or unresolved phase."
                )
            }
            if ticket.taskPlan != nil, ticketDestinations[ticket.sourceID] == nil {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "A reconstructed task plan requires a mapped destination ticket."
                )
            }
            if ticketComparison.disposition == .new,
               let phaseSourceID = ticket.phaseSourceID,
               let phaseComparison = comparisonFor(
                   phaseSourceID,
                   kind: .phase,
                   in: payload.comparisons
               ), phaseComparison.disposition == .unchanged,
               let phaseID = phaseComparison.destinationID,
               try connection.scalarText(
                   "SELECT lifecycle FROM phase_lifecycles WHERE project_id=? AND phase_id=?",
                   bindings: [.text(projectID.rawValue), .text(phaseID)]
               ) == PhaseLifecycle.completed.rawValue {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Repository reconstruction cannot add a ticket to a completed destination phase."
                )
            }
            if ticketComparison.disposition == .unchanged,
               ticket.taskPlan?.tasks.contains(where: { task in
                   comparisonFor(
                       task.sourceID,
                       parentSourceID: ticket.sourceID,
                       kind: .task,
                       in: payload.comparisons
                   )?.disposition == .new
               }) == true {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Repository reconstruction cannot append tasks to an existing destination ticket."
                )
            }
        }
        for dependency in payload.reviewedProjection.phaseDependencies
            where comparisonFor(dependency.sourceID, kind: .phaseDependency, in: payload.comparisons)?.disposition == .new {
            guard phaseDestinations[dependency.subjectSourceID] != nil,
                  phaseDestinations[dependency.dependsOnSourceID] != nil else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "A reconstructed phase dependency requires both mapped phases."
                )
            }
        }
        for dependency in payload.reviewedProjection.ticketDependencies
            where comparisonFor(dependency.sourceID, kind: .ticketDependency, in: payload.comparisons)?.disposition == .new {
            guard ticketDestinations[dependency.subjectSourceID] != nil,
                  ticketDestinations[dependency.dependsOnSourceID] != nil else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "A reconstructed ticket dependency requires both mapped tickets."
                )
            }
        }

        if payload.terminalEvidence.contains(where: {
            if case .ownerAttestation = $0 { return true }
            return false
        }), actorID != ownerActorID {
            throw PlanChangeProposalError.ownerAuthorityRequired
        }
        try validateSuppliedTerminalEvidence(payload, connection: connection)
    }

    static func validateForDecision(
        _ payload: RepositoryPlanReconstructionPayload,
        decisionID: String,
        connection: SQLiteConnection
    ) throws {
        guard payload.blockers.isEmpty,
              !payload.comparisons.contains(where: {
                  $0.disposition == .blocked || $0.disposition == .conflicting
              }) else {
            throw RepositoryPlanReconstructionError.blocked(payload.blockers)
        }
        guard payload.terminalEvidence.allSatisfy({ evidence in
            guard case let .ownerAttestation(attestation) = evidence else { return true }
            return exact(attestation.decisionID, decisionID)
        }) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Every owner attestation must bind the exact reconstruction decision."
            )
        }
        try validateTerminalEvidenceForApply(payload, connection: connection)
    }

    static func apply(
        _ payload: RepositoryPlanReconstructionPayload,
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        decisionID: String,
        applicationID: String,
        registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws {
        try validateForDecision(payload, decisionID: decisionID, connection: connection)
        guard try connection.scalarInt(
            """
            SELECT COUNT(*) FROM repository_plan_reconstruction_application_attempts
            WHERE project_id=? AND proposal_id=? AND version=? AND application_id=?
              AND registration_id=? AND request_generation=?
              AND state IN ('pending','outcome_unknown')
            """,
            bindings: [
                .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
                .text(applicationID), .text(registration.registrationID),
                .integer(registration.requestGeneration),
            ]
        ) == 1 else {
            throw RepositoryPlanReconstructionError.applicationAttemptConflict
        }
        try validateForSave(
            payload,
            projectID: projectID,
            registration: registration,
            actorID: ownerActorID,
            connection: connection
        )

        let comparisonBySubject = Dictionary(
            uniqueKeysWithValues: payload.comparisons.map { ($0.subject, $0) }
        )
        let phaseIDs = destinationMap(payload.comparisons, kind: .phase, source: payload.source)
        let ticketIDs = destinationMap(payload.comparisons, kind: .ticket, source: payload.source)
        let evidenceBySubject = Dictionary(grouping: payload.terminalEvidence, by: evidenceSubject)
        let now = timestamp()

        for phase in payload.reviewedProjection.phases {
            let subject = RepositoryPlanReconstructionSubject(
                kind: .phase, parentSourceID: nil, sourceID: phase.sourceID
            )
            guard comparisonBySubject[subject]?.disposition == .new,
                  let phaseID = phaseIDs[phase.sourceID] else { continue }
            try connection.execute(
                "INSERT INTO phases (id,project_id,name) VALUES (?,?,?)",
                bindings: [.text(phaseID), .text(projectID.rawValue), .text(phase.name)]
            )
            let occurredAt = originalOccurrence(
                evidenceBySubject[subject] ?? [], state: .completed
            )
            try connection.execute(
                """
                UPDATE phase_lifecycles
                SET lifecycle=?, revision=0, completion_baseline_digest=NULL,
                    updated_at=?, completed_at=?, record_origin='reconstruction'
                WHERE project_id=? AND phase_id=?
                """,
                bindings: [
                    .text(phase.lifecycle.rawValue), .text(now),
                    occurredAt.map { .text(timestamp($0)) } ?? .null,
                    .text(projectID.rawValue), .text(phaseID),
                ]
            )
        }

        for ticket in payload.reviewedProjection.tickets {
            let subject = RepositoryPlanReconstructionSubject(
                kind: .ticket, parentSourceID: nil, sourceID: ticket.sourceID
            )
            guard comparisonBySubject[subject]?.disposition == .new,
                  let ticketID = ticketIDs[ticket.sourceID] else { continue }
            let phaseID = ticket.phaseSourceID.flatMap { phaseIDs[$0] }
            try connection.execute(
                """
                INSERT INTO tickets (id,project_id,phase_id,outcome,lane,plan_legacy_continuation)
                VALUES (?,?,?,?,?,0)
                """,
                bindings: [
                    .text(ticketID), .text(projectID.rawValue),
                    phaseID.map(SQLiteValue.text) ?? .null,
                    .text(ticket.outcome), ticket.lane.map { .text($0.rawValue) } ?? .null,
                ]
            )
            if let lane = ticket.lane {
                try TicketLaneOrderingPolicy.maintainPlacedTicket(
                    projectID: projectID,
                    ticketID: .init(rawValue: ticketID),
                    lane: lane,
                    connection: connection
                )
            }
        }

        for ticket in payload.reviewedProjection.tickets {
            guard let ticketID = ticketIDs[ticket.sourceID], let taskPlan = ticket.taskPlan else { continue }
            if try connection.scalarInt(
                "SELECT COUNT(*) FROM ticket_task_plans WHERE project_id=? AND ticket_id=?",
                bindings: [.text(projectID.rawValue), .text(ticketID)]
            ) == 0 {
                try connection.execute(
                    "INSERT INTO ticket_task_plans (project_id,ticket_id,revision,created_at,updated_at) VALUES (?,?,?,?,?)",
                    bindings: [
                        .text(projectID.rawValue), .text(ticketID),
                        .integer(1), .text(now), .text(now),
                    ]
                )
            }
            for task in taskPlan.tasks {
                let subject = RepositoryPlanReconstructionSubject(
                    kind: .task, parentSourceID: ticket.sourceID, sourceID: task.sourceID
                )
                guard comparisonBySubject[subject]?.disposition == .new,
                      let comparison = comparisonBySubject[subject] else { continue }
                let taskID = resolvedDestinationID(comparison, source: payload.source)
                let subjectEvidence = evidenceBySubject[subject] ?? []
                let completedAt = task.completion == .completed
                    ? originalOccurrence(subjectEvidence, state: .completed) : nil
                let supersededAt = task.lifecycle == .superseded
                    ? originalOccurrence(subjectEvidence, state: .superseded) : nil
                try connection.execute(
                    """
                    INSERT INTO ticket_tasks (
                        project_id,ticket_id,id,label,title,sort_order,completion,lifecycle,
                        created_at,updated_at,completed_at,superseded_at,record_origin
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?, 'reconstruction')
                    """,
                    bindings: [
                        .text(projectID.rawValue), .text(ticketID), .text(taskID),
                        .text(task.label), .text(task.title), .integer(Int64(task.sortOrder)),
                        .text(task.completion.rawValue), .text(task.lifecycle.rawValue),
                        .text(now), .text(now),
                        completedAt.map { .text(timestamp($0)) } ?? .null,
                        supersededAt.map { .text(timestamp($0)) } ?? .null,
                    ]
                )
            }
        }

        for dependency in payload.reviewedProjection.phaseDependencies {
            let subject = RepositoryPlanReconstructionSubject(
                kind: .phaseDependency, parentSourceID: dependency.subjectSourceID,
                sourceID: dependency.sourceID
            )
            guard comparisonBySubject[subject]?.disposition == .new,
                  let comparison = comparisonBySubject[subject],
                  let phaseID = phaseIDs[dependency.subjectSourceID],
                  let dependsOnID = phaseIDs[dependency.dependsOnSourceID] else { continue }
            let id = resolvedDestinationID(comparison, source: payload.source)
            try connection.execute(
                "INSERT INTO phase_dependencies (id,project_id,phase_id,depends_on_phase_id) VALUES (?,?,?,?)",
                bindings: [.text(id), .text(projectID.rawValue), .text(phaseID), .text(dependsOnID)]
            )
        }
        for dependency in payload.reviewedProjection.ticketDependencies {
            let subject = RepositoryPlanReconstructionSubject(
                kind: .ticketDependency, parentSourceID: dependency.subjectSourceID,
                sourceID: dependency.sourceID
            )
            guard comparisonBySubject[subject]?.disposition == .new,
                  let comparison = comparisonBySubject[subject],
                  let ticketID = ticketIDs[dependency.subjectSourceID],
                  let dependsOnID = ticketIDs[dependency.dependsOnSourceID] else { continue }
            let id = resolvedDestinationID(comparison, source: payload.source)
            try connection.execute(
                "INSERT INTO ticket_dependencies (id,project_id,ticket_id,depends_on_ticket_id) VALUES (?,?,?,?)",
                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(dependsOnID)]
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for comparison in payload.comparisons {
            let fields = try sourceFields(
                comparison.subject, projection: payload.reviewedProjection, encoder: encoder
            )
            let refs = sourceReferences(
                comparison.subject, projection: payload.reviewedProjection
            )
            let evidence = evidenceBySubject[comparison.subject] ?? []
            let provenanceDestination = comparison.disposition == .new
                ? resolvedDestinationID(comparison, source: payload.source)
                : comparison.destinationID
            try connection.execute(
                """
                INSERT INTO repository_plan_reconstruction_provenance (
                    project_id,proposal_id,version,application_id,record_kind,
                    parent_source_id,source_id,destination_id,disposition,
                    source_fields_data,source_refs_data,evidence_data,
                    original_occurred_at,original_actor_id
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                bindings: [
                    .text(projectID.rawValue), .text(proposalID.rawValue), .integer(version),
                    .text(applicationID), .text(comparison.kind.rawValue),
                    .text(comparison.parentSourceID ?? ""), .text(comparison.sourceID),
                    provenanceDestination.map(SQLiteValue.text) ?? .null,
                    .text(comparison.disposition.rawValue), .blob(fields),
                    .blob(try encoder.encode(refs)), .blob(try encoder.encode(evidence)),
                    originalOccurrence(evidence).map { .text(timestamp($0)) } ?? .null,
                    originalActor(evidence).map(SQLiteValue.text) ?? .null,
                ]
            )
        }
    }

    static func subjects(
        in projection: RepositoryPlanProjection
    ) -> [RepositoryPlanReconstructionSubject] {
        var result = projection.phases.map {
            RepositoryPlanReconstructionSubject(kind: .phase, parentSourceID: nil, sourceID: $0.sourceID)
        }
        result.append(contentsOf: projection.tickets.map {
            RepositoryPlanReconstructionSubject(kind: .ticket, parentSourceID: nil, sourceID: $0.sourceID)
        })
        for ticket in projection.tickets {
            result.append(contentsOf: (ticket.taskPlan?.tasks ?? []).map {
                RepositoryPlanReconstructionSubject(
                    kind: .task, parentSourceID: ticket.sourceID, sourceID: $0.sourceID
                )
            })
        }
        result.append(contentsOf: projection.phaseDependencies.map {
            RepositoryPlanReconstructionSubject(
                kind: .phaseDependency, parentSourceID: $0.subjectSourceID, sourceID: $0.sourceID
            )
        })
        result.append(contentsOf: projection.ticketDependencies.map {
            RepositoryPlanReconstructionSubject(
                kind: .ticketDependency, parentSourceID: $0.subjectSourceID, sourceID: $0.sourceID
            )
        })
        return result
    }

    private static func expectedSubjects(
        _ projection: RepositoryPlanProjection
    ) -> Set<RepositoryPlanReconstructionSubject> {
        Set(subjects(in: projection))
    }

    private static func destinationMap(
        _ comparisons: [RepositoryPlanReconstructionComparison],
        kind: RepositoryPlanReconstructionRecordKind,
        source: RepositoryPlanReconstructionSourceSnapshot
    ) -> [String: String] {
        Dictionary(uniqueKeysWithValues: comparisons.compactMap {
            guard $0.kind == kind,
                  $0.disposition == .new || $0.disposition == .unchanged else { return nil }
            return ($0.sourceID, resolvedDestinationID($0, source: source))
        })
    }

    private static func resolvedDestinationID(
        _ comparison: RepositoryPlanReconstructionComparison,
        source: RepositoryPlanReconstructionSourceSnapshot
    ) -> String {
        comparison.destinationID ?? RepositoryPlanReconstructionIdentity.destinationID(
            source: source,
            subject: comparison.subject
        )
    }

    private static func validateTerminalEvidenceForApply(
        _ payload: RepositoryPlanReconstructionPayload,
        connection: SQLiteConnection
    ) throws {
        try validateSuppliedTerminalEvidence(payload, connection: connection)
        let grouped = Dictionary(
            grouping: payload.terminalEvidence.filter { !isGoalEvidence($0) },
            by: evidenceSubject
        )
        let expected = expectedSubjects(payload.reviewedProjection)
        guard grouped.keys.allSatisfy(expected.contains) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Terminal evidence names a record outside the reviewed reconstruction."
            )
        }
        func require(_ subject: RepositoryPlanReconstructionSubject, _ state: RepositoryPlanTerminalState) throws {
            if state == .accepted, subject.kind == .ticket,
               try exactAcceptedDestinationFact(
                   subject: subject,
                   payload: payload,
                   connection: connection
               ) {
                return
            }
            guard let evidence = grouped[subject],
                  evidence.contains(where: { evidenceState($0) == state }) else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Terminal state \(state.rawValue) for \(subject.sourceID) requires matching original evidence or an owner attestation."
                )
            }
        }
        for phase in payload.reviewedProjection.phases where phase.lifecycle == .completed {
            let subject = RepositoryPlanReconstructionSubject(
                kind: .phase, parentSourceID: nil, sourceID: phase.sourceID
            )
            guard isIncluded(subject, comparisons: payload.comparisons) else { continue }
            try require(subject, .completed)
            let expectedTickets = payload.reviewedProjection.tickets.compactMap {
                let ticketSubject = RepositoryPlanReconstructionSubject(
                    kind: .ticket, parentSourceID: nil, sourceID: $0.sourceID
                )
                return exact($0.phaseSourceID ?? "", phase.sourceID)
                    && isIncluded(ticketSubject, comparisons: payload.comparisons)
                    ? $0.sourceID : nil
            }
            guard let evidence = grouped[subject], evidence.allSatisfy({ item in
                guard let certificate = phaseCompletion(item) else { return false }
                return (try? validatePhaseCompletionCertificate(
                    certificate,
                    phase: phase,
                    expectedTickets: expectedTickets,
                    payload: payload,
                    connection: connection
                )) != nil
            }) else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Completed phases require a complete, debt-free membership certificate."
                )
            }
        }
        for ticket in payload.reviewedProjection.tickets {
            let ticketSubject = RepositoryPlanReconstructionSubject(
                kind: .ticket, parentSourceID: nil, sourceID: ticket.sourceID
            )
            guard isIncluded(ticketSubject, comparisons: payload.comparisons) else { continue }
            if ticket.lane == .accepted {
                try require(ticketSubject, .accepted)
            }
            for task in ticket.taskPlan?.tasks ?? [] {
                let subject = RepositoryPlanReconstructionSubject(
                    kind: .task, parentSourceID: ticket.sourceID, sourceID: task.sourceID
                )
                guard isIncluded(subject, comparisons: payload.comparisons) else { continue }
                if task.completion == .completed { try require(subject, .completed) }
                if task.lifecycle == .superseded { try require(subject, .superseded) }
            }
        }
    }

    private static func exactAcceptedDestinationFact(
        subject: RepositoryPlanReconstructionSubject,
        payload: RepositoryPlanReconstructionPayload,
        connection: SQLiteConnection
    ) throws -> Bool {
        guard let comparison = payload.comparisons.first(where: {
            $0.subject == subject
        }), comparison.disposition == .unchanged,
        let destinationID = comparison.destinationID else { return false }
        return try connection.scalarText(
            "SELECT lane FROM tickets WHERE project_id=? AND id=?",
            bindings: [
                .text(payload.source.projectID.rawValue), .text(destinationID),
            ]
        ) == TicketLane.accepted.rawValue
    }

    private static func validatePhaseCompletionCertificate(
        _ certificate: RepositoryPlanPhaseCompletionCertificate,
        phase: RepositoryPlanProjectionPhase,
        expectedTickets: [String],
        payload: RepositoryPlanReconstructionPayload,
        connection: SQLiteConnection
    ) throws {
        guard certificate.membershipComplete,
              !certificate.deliveredBy.isEmpty,
              exactIdentitySet(certificate.tickets.map(\.sourceTicketID))
                == exactIdentitySet(Array(expectedTickets)),
              certificate.tickets.count == expectedTickets.count,
              exactIdentitySet(certificate.goals.map(\.sourceGoalID)).count
                == certificate.goals.count,
              exactIdentitySet(certificate.obligations.map(\.sourceObligationID)).count
                == certificate.obligations.count,
              uniqueCompletionReferences(certificate.deliveredBy),
              certificate.goals.allSatisfy({ goal in
                  !goal.remainingDebt && (!goal.required
                      || goal.lifecycle == .accepted || goal.lifecycle == .superseded)
              }),
              certificate.obligations.allSatisfy({
                  ![.unresolved, .unassessed].contains($0.disposition)
                      && ($0.disposition != .fulfilled || !$0.descendants.isEmpty)
              }) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Completed phase evidence does not prove complete debt-free delivery."
            )
        }

        let projectedTickets = payload.reviewedProjection.tickets.filter {
            exact($0.phaseSourceID ?? "", phase.sourceID)
                && isIncluded(
                    .init(kind: .ticket, parentSourceID: nil, sourceID: $0.sourceID),
                    comparisons: payload.comparisons
                )
        }
        for ticket in projectedTickets {
            guard ticket.lane == .accepted,
                  let membership = certificate.tickets.first(where: {
                      exact($0.sourceTicketID, ticket.sourceID)
                  }), membership.lane == ticket.lane else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Completed phase membership must preserve each accepted ticket lane."
                )
            }
            try validateTicketAcceptanceProof(
                membership.acceptanceProof,
                ticket: ticket,
                payload: payload,
                connection: connection
            )
        }

        if let phaseComparison = comparisonFor(
            phase.sourceID,
            kind: .phase,
            in: payload.comparisons
        ), phaseComparison.disposition == .unchanged,
           let destinationPhaseID = phaseComparison.destinationID {
            let liveIDs = try connection.rows(
                """
                SELECT tickets.id FROM tickets
                LEFT JOIN ticket_retirements
                  ON ticket_retirements.project_id=tickets.project_id
                 AND ticket_retirements.ticket_id=tickets.id
                WHERE tickets.project_id=? AND tickets.phase_id=?
                  AND ticket_retirements.ticket_id IS NULL
                """,
                bindings: [
                    .text(payload.source.projectID.rawValue), .text(destinationPhaseID),
                ],
                maximum: 5_000
            ).compactMap { row -> String? in
                guard case let .text(id)? = row["id"] else { return nil }
                return id
            }
            let retainedIDs = projectedTickets.compactMap { ticket in
                comparisonFor(ticket.sourceID, kind: .ticket, in: payload.comparisons)
            }.filter { $0.disposition == .unchanged }.compactMap(\.destinationID)
            guard exactIdentitySet(liveIDs) == exactIdentitySet(retainedIDs) else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Completed phase evidence omits retained destination membership."
                )
            }
            let destinationAssessment = try PhaseLifecyclePolicy.assessCompletion(
                projectID: payload.source.projectID,
                phaseID: .init(rawValue: destinationPhaseID),
                connection: connection
            )
            guard destinationAssessment.blockers.isEmpty else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Completed phase evidence cannot override unresolved destination coverage."
                )
            }
        }

        for reference in certificate.deliveredBy {
            switch reference.kind {
            case .ticket:
                guard certificate.tickets.contains(where: {
                    exact($0.sourceTicketID, reference.sourceID)
                }) else {
                    throw RepositoryPlanReconstructionError.invalidPayload(
                        "Delivered ticket credit must name a declared phase member."
                    )
                }
            case .goal:
                guard certificate.goals.contains(where: {
                    exact($0.sourceGoalID, reference.sourceID)
                }) else {
                    throw RepositoryPlanReconstructionError.invalidPayload(
                        "Delivered goal credit must name a declared assessed goal."
                    )
                }
            }
            try validateCompletionReference(
                reference,
                phase: phase,
                payload: payload,
                allowCrossPhase: false,
                connection: connection
            )
        }
        for obligation in certificate.obligations {
            guard uniqueCompletionReferences(obligation.descendants) else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "Completed phase obligation descendants must be unique."
                )
            }
            for descendant in obligation.descendants {
                try validateCompletionReference(
                    descendant,
                    phase: phase,
                    payload: payload,
                    allowCrossPhase: true,
                    connection: connection
                )
            }
        }
    }

    private static func validateTicketAcceptanceProof(
        _ proof: RepositoryPlanSourceReference?,
        ticket: RepositoryPlanProjectionTicket,
        payload: RepositoryPlanReconstructionPayload,
        connection: SQLiteConnection
    ) throws {
        if let proof {
            guard ticket.stateEvidence.contains(where: { sourceReferenceExact($0, proof) }),
                  case let .original(_, record) = try RepositoryPlanTerminalEvidenceResolver.original(
                      sourceRef: proof,
                      source: payload.source
                  ) else { throw invalidCompletionProof() }
            try requireStateRecordHeader(record, source: payload.source)
            guard record.kind == .ticketAcceptance, record.state == .accepted,
                  case let .ticket(subject) = record.subject,
                  exactTicketSubject(subject, projectionTicket: ticket) else {
                throw invalidCompletionProof()
            }
            return
        }
        if payload.terminalEvidence.contains(where: { evidence in
            guard case let .ownerAttestation(attestation) = evidence,
                  attestation.state == .accepted,
                  case let .ticket(subject) = attestation.subject else { return false }
            return exactTicketSubject(subject, projectionTicket: ticket)
        }) { return }
        if let comparison = comparisonFor(
            ticket.sourceID,
            kind: .ticket,
            in: payload.comparisons
        ), comparison.disposition == .unchanged,
           let destinationID = comparison.destinationID,
           try connection.scalarText(
               "SELECT lane FROM tickets WHERE project_id=? AND id=?",
               bindings: [
                   .text(payload.source.projectID.rawValue), .text(destinationID),
               ]
           ) == TicketLane.accepted.rawValue {
            return
        }
        throw invalidCompletionProof()
    }

    private static func validateCompletionReference(
        _ reference: RepositoryPlanPhaseCompletionReference,
        phase: RepositoryPlanProjectionPhase,
        payload: RepositoryPlanReconstructionPayload,
        allowCrossPhase: Bool,
        connection: SQLiteConnection
    ) throws {
        guard allowCrossPhase || exact(reference.phaseSourceID, phase.sourceID) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Delivered phase credit must name the completed phase."
            )
        }
        switch reference.kind {
        case .ticket:
            guard let ticket = payload.reviewedProjection.tickets.first(where: {
                exact($0.sourceID, reference.sourceID)
                    && exact($0.phaseSourceID ?? "", reference.phaseSourceID)
            }) else {
                throw RepositoryPlanReconstructionError.invalidPayload(
                    "A delivered ticket reference is outside the reviewed reconstruction."
                )
            }
            try validateTicketAcceptanceProof(
                reference.proofRef,
                ticket: ticket,
                payload: payload,
                connection: connection
            )
        case .goal:
            if let proof = reference.proofRef {
                guard case let .original(_, record) = try RepositoryPlanTerminalEvidenceResolver.original(
                    sourceRef: proof,
                    source: payload.source
                ) else { throw invalidCompletionProof() }
                try requireStateRecordHeader(record, source: payload.source)
                guard record.kind == .goalAcceptance, record.state == .accepted,
                      case let .goal(subject) = record.subject,
                      exact(subject.phaseSourceID, reference.phaseSourceID),
                      exact(subject.sourceGoalID, reference.sourceID) else {
                    throw invalidCompletionProof()
                }
                return
            }
            let hasOwnerAttestation = payload.terminalEvidence.contains(where: { evidence in
                guard case let .ownerAttestation(attestation) = evidence,
                      attestation.state == .accepted,
                      case let .goal(subject) = attestation.subject else { return false }
                return exact(subject.phaseSourceID, reference.phaseSourceID)
                    && exact(subject.sourceGoalID, reference.sourceID)
            })
            let hasAcceptedDestination = try exactAcceptedDestinationGoal(
                phaseSourceID: reference.phaseSourceID,
                sourceGoalID: reference.sourceID,
                payload: payload,
                connection: connection
            )
            guard hasOwnerAttestation || hasAcceptedDestination else {
                throw invalidCompletionProof()
            }
        }
    }

    private static func exactAcceptedDestinationGoal(
        phaseSourceID: String,
        sourceGoalID: String,
        payload: RepositoryPlanReconstructionPayload,
        connection: SQLiteConnection
    ) throws -> Bool {
        guard let phaseComparison = comparisonFor(
            phaseSourceID,
            kind: .phase,
            in: payload.comparisons
        ), phaseComparison.disposition == .unchanged,
        let destinationPhaseID = phaseComparison.destinationID,
        try connection.scalarText(
            "SELECT lifecycle FROM delivery_goals WHERE project_id=? AND phase_id=? AND id=?",
            bindings: [
                .text(payload.source.projectID.rawValue),
                .text(destinationPhaseID), .text(sourceGoalID),
            ]
        ) == DeliveryGoalLifecycle.accepted.rawValue else { return false }
        let coverage = try DeliveryGoalCoveragePolicy.assess(
            projectID: payload.source.projectID,
            phaseID: .init(rawValue: destinationPhaseID),
            goalID: .init(rawValue: sourceGoalID),
            connection: connection
        )
        return coverage.isAcceptanceEligible
    }

    private static func requireStateRecordHeader(
        _ record: RepositoryPlanStateRecord,
        source: RepositoryPlanReconstructionSourceSnapshot
    ) throws {
        guard record.format == "release-radar.state-record",
              record.schemaVersion == 1,
              !record.recordID.isEmpty,
              exact(record.repositoryID, source.repositoryID) else {
            throw invalidCompletionProof()
        }
    }

    private static func invalidCompletionProof() -> RepositoryPlanReconstructionError {
        .invalidPayload(
            "Completed phase credit must resolve to an exact original record, owner attestation, or accepted destination fact."
        )
    }

    private static func exactIdentitySet(_ values: [String]) -> Set<Data> {
        Set(values.map { Data($0.utf8) })
    }

    private static func uniqueCompletionReferences(
        _ references: [RepositoryPlanPhaseCompletionReference]
    ) -> Bool {
        Set(references.map(completionReferenceKey)).count == references.count
    }

    private static func completionReferenceKey(
        _ reference: RepositoryPlanPhaseCompletionReference
    ) -> Data {
        var bytes = Data(reference.kind.rawValue.utf8)
        bytes.append(0)
        bytes.append(contentsOf: reference.phaseSourceID.utf8)
        bytes.append(0)
        bytes.append(contentsOf: reference.sourceID.utf8)
        return bytes
    }

    private static func sourceReferenceExact(
        _ lhs: RepositoryPlanSourceReference,
        _ rhs: RepositoryPlanSourceReference
    ) -> Bool {
        sourceReferenceBytes(lhs) == sourceReferenceBytes(rhs)
    }

    private static func sourceReferenceBytes(_ reference: RepositoryPlanSourceReference) -> Data {
        var bytes = Data()
        switch reference {
        case let .projection(pointer):
            bytes.append(contentsOf: "projection".utf8)
            bytes.append(0)
            bytes.append(contentsOf: pointer.utf8)
        case let .document(documentID, locator):
            bytes.append(contentsOf: "document".utf8)
            bytes.append(0)
            bytes.append(contentsOf: documentID.utf8)
            bytes.append(0)
            bytes.append(contentsOf: locator.utf8)
        }
        return bytes
    }

    private static func validateSuppliedTerminalEvidence(
        _ payload: RepositoryPlanReconstructionPayload,
        connection: SQLiteConnection
    ) throws {
        let expected = expectedSubjects(payload.reviewedProjection)
        guard payload.terminalEvidence.allSatisfy({ evidence in
            expected.contains(evidenceSubject(evidence))
                || goalEvidenceIsReferenced(evidence, payload: payload)
        }) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Terminal evidence names a record outside the reviewed reconstruction."
            )
        }
        for evidence in payload.terminalEvidence {
            switch evidence {
            case let .original(sourceRef, record):
                if case let .goal(goal) = record.subject {
                    try requireStateRecordHeader(record, source: payload.source)
                    guard record.kind == .goalAcceptance, record.state == .accepted,
                          goalIsReferenced(
                              phaseSourceID: goal.phaseSourceID,
                              sourceGoalID: goal.sourceGoalID,
                              payload: payload
                          ) else { throw invalidCompletionProof() }
                    try RepositoryPlanTerminalEvidenceResolver.requireExact(
                        record,
                        sourceRef: sourceRef,
                        projection: payload.reviewedProjection,
                        source: payload.source
                    )
                    continue
                }
                let subject = evidenceSubject(evidence)
                guard exact(record.repositoryID, payload.source.repositoryID),
                      record.format == "release-radar.state-record", record.schemaVersion == 1,
                      !record.recordID.isEmpty,
                      stateEvidenceReferences(subject, projection: payload.reviewedProjection)
                        .contains(sourceRef) else {
                    throw RepositoryPlanReconstructionError.invalidPayload("Original terminal evidence does not match the reviewed source.")
                }
                try RepositoryPlanTerminalEvidenceResolver.requireExact(
                    record,
                    sourceRef: sourceRef,
                    projection: payload.reviewedProjection,
                    source: payload.source
                )
                try requireRecordMatchesProjection(
                    record,
                    subject: subject,
                    projection: payload.reviewedProjection
                )
            case let .ownerAttestation(attestation):
                guard !attestation.id.isEmpty, !attestation.decisionID.isEmpty,
                      attestation.originalOccurredAt == nil,
                      attestation.originalActorID == nil,
                      attestation.attestedAt <= Date().addingTimeInterval(300) else {
                    throw RepositoryPlanReconstructionError.invalidPayload("Owner attestations require immutable identities.")
                }
                if case let .goal(goal) = attestation.subject {
                    guard attestation.state == .accepted,
                          attestation.phaseCompletion == nil,
                          goalIsReferenced(
                              phaseSourceID: goal.phaseSourceID,
                              sourceGoalID: goal.sourceGoalID,
                              payload: payload
                          ) else { throw invalidCompletionProof() }
                    continue
                }
                try requireAttestationMatchesProjection(
                    attestation,
                    subject: evidenceSubject(evidence),
                    projection: payload.reviewedProjection
                )
            }
        }
        for evidence in payload.terminalEvidence {
            let subject = evidenceSubject(evidence)
            guard subject.kind == .phase,
                  let certificate = phaseCompletion(evidence),
                  let phase = payload.reviewedProjection.phases.first(where: {
                      exact($0.sourceID, subject.sourceID)
                  }) else { continue }
            let expectedTickets = payload.reviewedProjection.tickets.compactMap { ticket in
                let ticketSubject = RepositoryPlanReconstructionSubject(
                    kind: .ticket, parentSourceID: nil, sourceID: ticket.sourceID
                )
                return exact(ticket.phaseSourceID ?? "", phase.sourceID)
                    && isIncluded(ticketSubject, comparisons: payload.comparisons)
                    ? ticket.sourceID : nil
            }
            try validatePhaseCompletionCertificate(
                certificate,
                phase: phase,
                expectedTickets: expectedTickets,
                payload: payload,
                connection: connection
            )
        }
    }

    private static func goalEvidenceIsReferenced(
        _ evidence: RepositoryPlanTerminalEvidence,
        payload: RepositoryPlanReconstructionPayload
    ) -> Bool {
        let subject: RepositoryPlanStateSubject = switch evidence {
        case let .original(_, record): record.subject
        case let .ownerAttestation(attestation): attestation.subject
        }
        guard case let .goal(goal) = subject else { return false }
        return goalIsReferenced(
            phaseSourceID: goal.phaseSourceID,
            sourceGoalID: goal.sourceGoalID,
            payload: payload
        )
    }

    private static func isGoalEvidence(_ evidence: RepositoryPlanTerminalEvidence) -> Bool {
        let subject: RepositoryPlanStateSubject = switch evidence {
        case let .original(_, record): record.subject
        case let .ownerAttestation(attestation): attestation.subject
        }
        if case .goal = subject { return true }
        return false
    }

    private static func goalIsReferenced(
        phaseSourceID: String,
        sourceGoalID: String,
        payload: RepositoryPlanReconstructionPayload
    ) -> Bool {
        payload.terminalEvidence.contains { evidence in
            guard let certificate = phaseCompletion(evidence) else { return false }
            if certificate.goals.contains(where: {
                exact($0.sourceGoalID, sourceGoalID)
                    && evidenceSubject(evidence).kind == .phase
                    && exact(evidenceSubject(evidence).sourceID, phaseSourceID)
            }) { return true }
            let references = certificate.deliveredBy
                + certificate.obligations.flatMap(\.descendants)
            return references.contains(where: {
                $0.kind == .goal
                    && exact($0.phaseSourceID, phaseSourceID)
                    && exact($0.sourceID, sourceGoalID)
            })
        }
    }

    private static func requireRecordMatchesProjection(
        _ record: RepositoryPlanStateRecord,
        subject: RepositoryPlanReconstructionSubject,
        projection: RepositoryPlanProjection
    ) throws {
        let valid: Bool
        switch (record.kind, record.subject, subject.kind) {
        case let (.phaseLifecycle, .phase(value), .phase):
            valid = projection.phases.contains(where: {
                exact($0.sourceID, value.sourceID) && exact($0.name, value.name)
                    && terminalState($0.lifecycle) == record.state
            })
        case let (.ticketAcceptance, .ticket(value), .ticket):
            valid = record.state == .accepted
                && projection.tickets.contains(where: {
                    exactTicketSubject(value, projectionTicket: $0) && $0.lane == .accepted
                })
        case let (.taskCompletion, .task(value), .task):
            valid = record.state == .completed
                && projectionTask(matching: value, in: projection)?.completion == .completed
        case let (.taskSupersession, .task(value), .task):
            valid = record.state == .superseded
                && projectionTask(matching: value, in: projection)?.lifecycle == .superseded
        default:
            valid = false
        }
        guard valid else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Original terminal evidence kind, state, and subject must exactly match the reviewed projection."
            )
        }
    }

    private static func requireAttestationMatchesProjection(
        _ attestation: RepositoryPlanOwnerAttestation,
        subject: RepositoryPlanReconstructionSubject,
        projection: RepositoryPlanProjection
    ) throws {
        let record = RepositoryPlanStateRecord(
            recordID: attestation.id,
            repositoryID: projection.repositoryID,
            kind: attestationKind(attestation.subject, state: attestation.state),
            subject: attestation.subject,
            state: attestation.state,
            occurredAt: nil,
            actorID: nil,
            phaseCompletion: attestation.phaseCompletion
        )
        try requireRecordMatchesProjection(record, subject: subject, projection: projection)
    }

    private static func attestationKind(
        _ subject: RepositoryPlanStateSubject,
        state: RepositoryPlanTerminalState
    ) -> RepositoryPlanStateRecord.Kind {
        switch subject {
        case .phase: .phaseLifecycle
        case .ticket: .ticketAcceptance
        case .task: state == .superseded ? .taskSupersession : .taskCompletion
        case .goal: .goalAcceptance
        }
    }

    private static func terminalState(_ lifecycle: PhaseLifecycle) -> RepositoryPlanTerminalState {
        switch lifecycle {
        case .unassessed: .unassessed
        case .upcoming: .upcoming
        case .inDelivery: .inDelivery
        case .completed: .completed
        }
    }

    private static func exactTicketSubject(
        _ subject: RepositoryPlanStateTicketSubject,
        projectionTicket: RepositoryPlanProjectionTicket
    ) -> Bool {
        guard exact(subject.sourceID, projectionTicket.sourceID),
              exact(subject.outcome, projectionTicket.outcome),
              optionalExact(subject.phaseSourceID, projectionTicket.phaseSourceID) else { return false }
        switch (subject.taskPlan, projectionTicket.taskPlan) {
        case (nil, nil): return true
        case let (.some(subjectPlan), .some(projectionPlan)):
            guard subjectPlan.sourceRevision == projectionPlan.sourceRevision,
                  subjectPlan.tasks.count == projectionPlan.tasks.count else { return false }
            var byID: [Data: RepositoryPlanStateTaskSnapshot] = [:]
            for task in subjectPlan.tasks {
                guard byID.updateValue(task, forKey: Data(task.sourceID.utf8)) == nil else {
                    return false
                }
            }
            return projectionPlan.tasks.allSatisfy { task in
                guard let proof = byID[Data(task.sourceID.utf8)] else { return false }
                return exact(proof.sourceID, task.sourceID)
                    && exact(proof.label, task.label)
                    && exact(proof.title, task.title)
                    && proof.sortOrder == task.sortOrder
                    && proof.completion == task.completion
                    && proof.lifecycle == task.lifecycle
            }
        default: return false
        }
    }

    private static func projectionTask(
        matching subject: RepositoryPlanStateTaskSubject,
        in projection: RepositoryPlanProjection
    ) -> RepositoryPlanProjectionTask? {
        projection.tickets.first(where: { exact($0.sourceID, subject.ticketSourceID) })?
            .taskPlan?.tasks.first(where: {
                exact($0.sourceID, subject.sourceID)
                    && exact($0.label, subject.label)
                    && exact($0.title, subject.title)
                    && $0.sortOrder == subject.sortOrder
            })
    }

    private static func requireAbsent(
        destinationID id: String,
        kind: RepositoryPlanReconstructionRecordKind,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        let table = switch kind {
        case .phase: "phases"
        case .ticket: "tickets"
        case .task: "ticket_tasks"
        case .phaseDependency: "phase_dependencies"
        case .ticketDependency: "ticket_dependencies"
        }
        guard try connection.scalarInt(
            "SELECT COUNT(*) FROM \(table) WHERE project_id=? AND id=?",
            bindings: [.text(projectID.rawValue), .text(id)]
        ) == 0 else {
            throw RepositoryPlanReconstructionError.invalidPayload("A deterministic destination identity is already occupied.")
        }
    }

    private static func requireExactMatch(
        _ comparison: RepositoryPlanReconstructionComparison,
        projection: RepositoryPlanProjection,
        comparisons: [RepositoryPlanReconstructionComparison],
        source: RepositoryPlanReconstructionSourceSnapshot,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws {
        guard let id = comparison.destinationID else { throw RepositoryPlanReconstructionError.staleSource }
        let matches: Bool
        switch comparison.kind {
        case .phase:
            guard let source = projection.phases.first(where: { exact($0.sourceID, comparison.sourceID) }),
                  let row = try connection.row(
                    """
                    SELECT phases.name,phase_lifecycles.lifecycle FROM phases
                    JOIN phase_lifecycles ON phase_lifecycles.project_id=phases.project_id
                      AND phase_lifecycles.phase_id=phases.id
                    WHERE phases.project_id=? AND phases.id=?
                    """, bindings: [.text(projectID.rawValue), .text(id)]
                  ) else { throw RepositoryPlanReconstructionError.staleSource }
            matches = row["name"] == .text(source.name)
                && row["lifecycle"] == .text(source.lifecycle.rawValue)
        case .ticket:
            guard let projectedTicket = projection.tickets.first(where: { exact($0.sourceID, comparison.sourceID) }),
                  let row = try connection.row(
                    "SELECT outcome,phase_id,lane FROM tickets WHERE project_id=? AND id=?",
                    bindings: [.text(projectID.rawValue), .text(id)]
                  ) else { throw RepositoryPlanReconstructionError.staleSource }
            let expectedPhaseID = projectedTicket.phaseSourceID.flatMap { sourceID in
                comparisons.first(where: {
                    $0.kind == .phase && exact($0.sourceID, sourceID)
                        && ($0.disposition == .new || $0.disposition == .unchanged)
                }).map { resolvedDestinationID($0, source: source) }
            }
            let taskPlanMatches = try ticketTaskPlanMatches(
                projectedTicket.taskPlan,
                sourceTicketID: projectedTicket.sourceID,
                destinationTicketID: id,
                comparisons: comparisons,
                source: source,
                projectID: projectID,
                connection: connection
            )
            matches = row["outcome"] == .text(projectedTicket.outcome)
                && row["phase_id"] == (expectedPhaseID.map(SQLiteValue.text) ?? .null)
                && row["lane"] == (projectedTicket.lane.map { .text($0.rawValue) } ?? .null)
                && taskPlanMatches
        case .task:
            guard let parent = comparison.parentSourceID,
                  let task = projection.tickets.first(where: { exact($0.sourceID, parent) })?
                    .taskPlan?.tasks.first(where: { exact($0.sourceID, comparison.sourceID) }),
                  let ticketComparison = comparisons.first(where: {
                    $0.kind == .ticket && exact($0.sourceID, parent)
                        && ($0.disposition == .new || $0.disposition == .unchanged)
                  }),
                  let row = try connection.row(
                    "SELECT label,title,sort_order,completion,lifecycle FROM ticket_tasks WHERE project_id=? AND ticket_id=? AND id=?",
                    bindings: [
                        .text(projectID.rawValue),
                        .text(resolvedDestinationID(ticketComparison, source: source)),
                        .text(id),
                    ]
                  ) else { throw RepositoryPlanReconstructionError.staleSource }
            matches = row["label"] == .text(task.label) && row["title"] == .text(task.title)
                && row["sort_order"] == .integer(Int64(task.sortOrder))
                && row["completion"] == .text(task.completion.rawValue)
                && row["lifecycle"] == .text(task.lifecycle.rawValue)
        case .phaseDependency:
            guard let dependency = projection.phaseDependencies.first(where: { exact($0.sourceID, comparison.sourceID) }),
                  let row = try connection.row(
                    "SELECT phase_id,depends_on_phase_id FROM phase_dependencies WHERE project_id=? AND id=?",
                    bindings: [.text(projectID.rawValue), .text(id)]
                  ) else { throw RepositoryPlanReconstructionError.staleSource }
            let phaseIDs = destinationMap(comparisons, kind: .phase, source: source)
            matches = row["phase_id"] == phaseIDs[dependency.subjectSourceID].map(SQLiteValue.text)
                && row["depends_on_phase_id"] == phaseIDs[dependency.dependsOnSourceID].map(SQLiteValue.text)
        case .ticketDependency:
            guard let dependency = projection.ticketDependencies.first(where: { exact($0.sourceID, comparison.sourceID) }),
                  let row = try connection.row(
                    "SELECT ticket_id,depends_on_ticket_id FROM ticket_dependencies WHERE project_id=? AND id=?",
                    bindings: [.text(projectID.rawValue), .text(id)]
                  ) else { throw RepositoryPlanReconstructionError.staleSource }
            let ticketIDs = destinationMap(comparisons, kind: .ticket, source: source)
            matches = row["ticket_id"] == ticketIDs[dependency.subjectSourceID].map(SQLiteValue.text)
                && row["depends_on_ticket_id"] == ticketIDs[dependency.dependsOnSourceID].map(SQLiteValue.text)
        }
        guard matches else { throw RepositoryPlanReconstructionError.staleSource }
    }

    private static func ticketTaskPlanMatches(
        _ sourcePlan: RepositoryPlanProjectionTaskPlan?,
        sourceTicketID: String,
        destinationTicketID: String,
        comparisons: [RepositoryPlanReconstructionComparison],
        source: RepositoryPlanReconstructionSourceSnapshot,
        projectID: ProjectID,
        connection: SQLiteConnection
    ) throws -> Bool {
        let planRow = try connection.row(
            "SELECT revision FROM ticket_task_plans WHERE project_id=? AND ticket_id=?",
            bindings: [.text(projectID.rawValue), .text(destinationTicketID)]
        )
        let destinationTasks = try connection.rows(
            """
            SELECT id,label,title,sort_order,completion,lifecycle
            FROM ticket_tasks WHERE project_id=? AND ticket_id=?
            """,
            bindings: [.text(projectID.rawValue), .text(destinationTicketID)],
            maximum: 5_000
        )
        guard let sourcePlan else { return planRow == nil && destinationTasks.isEmpty }
        guard planRow != nil,
              destinationTasks.count == sourcePlan.tasks.count else { return false }

        for task in sourcePlan.tasks {
            guard let taskComparison = comparisonFor(
                task.sourceID,
                parentSourceID: sourceTicketID,
                kind: .task,
                in: comparisons
            ), taskComparison.disposition == .unchanged,
                  let row = destinationTasks.first(where: {
                      $0["id"] == .text(resolvedDestinationID(taskComparison, source: source))
                  }),
                  row["label"] == .text(task.label),
                  row["title"] == .text(task.title),
                  row["sort_order"] == .integer(Int64(task.sortOrder)),
                  row["completion"] == .text(task.completion.rawValue),
                  row["lifecycle"] == .text(task.lifecycle.rawValue) else { return false }
        }
        return true
    }

    private static func sourceFields(
        _ subject: RepositoryPlanReconstructionSubject,
        projection: RepositoryPlanProjection,
        encoder: JSONEncoder
    ) throws -> Data {
        switch subject.kind {
        case .phase:
            guard let value = projection.phases.first(where: { exact($0.sourceID, subject.sourceID) }) else { throw RepositoryPlanReconstructionError.staleSource }
            return try encoder.encode(value)
        case .ticket:
            guard let value = projection.tickets.first(where: { exact($0.sourceID, subject.sourceID) }) else { throw RepositoryPlanReconstructionError.staleSource }
            return try encoder.encode(value)
        case .task:
            guard let parent = subject.parentSourceID,
                  let value = projection.tickets.first(where: { exact($0.sourceID, parent) })?
                    .taskPlan?.tasks.first(where: { exact($0.sourceID, subject.sourceID) }) else { throw RepositoryPlanReconstructionError.staleSource }
            return try encoder.encode(value)
        case .phaseDependency:
            guard let value = projection.phaseDependencies.first(where: { exact($0.sourceID, subject.sourceID) }) else { throw RepositoryPlanReconstructionError.staleSource }
            return try encoder.encode(value)
        case .ticketDependency:
            guard let value = projection.ticketDependencies.first(where: { exact($0.sourceID, subject.sourceID) }) else { throw RepositoryPlanReconstructionError.staleSource }
            return try encoder.encode(value)
        }
    }

    private static func sourceReferences(
        _ subject: RepositoryPlanReconstructionSubject,
        projection: RepositoryPlanProjection
    ) -> [RepositoryPlanSourceReference] {
        switch subject.kind {
        case .phase:
            guard let value = projection.phases.first(where: { exact($0.sourceID, subject.sourceID) }) else { return [] }
            return value.sourceRefs + value.stateEvidence
        case .ticket:
            guard let value = projection.tickets.first(where: { exact($0.sourceID, subject.sourceID) }) else { return [] }
            return value.sourceRefs + value.stateEvidence + value.evidenceRefs
        case .task:
            guard let value = projection.tickets.first(where: { exact($0.sourceID, subject.parentSourceID ?? "") })?
                .taskPlan?.tasks.first(where: { exact($0.sourceID, subject.sourceID) }) else { return [] }
            return value.sourceRefs + value.stateEvidence
        case .phaseDependency:
            return projection.phaseDependencies.first(where: { exact($0.sourceID, subject.sourceID) })?.sourceRefs ?? []
        case .ticketDependency:
            return projection.ticketDependencies.first(where: { exact($0.sourceID, subject.sourceID) })?.sourceRefs ?? []
        }
    }

    private static func stateEvidenceReferences(
        _ subject: RepositoryPlanReconstructionSubject,
        projection: RepositoryPlanProjection
    ) -> [RepositoryPlanSourceReference] {
        switch subject.kind {
        case .phase:
            return projection.phases.first(where: {
                exact($0.sourceID, subject.sourceID)
            })?.stateEvidence ?? []
        case .ticket:
            return projection.tickets.first(where: {
                exact($0.sourceID, subject.sourceID)
            })?.stateEvidence ?? []
        case .task:
            return projection.tickets.first(where: {
                exact($0.sourceID, subject.parentSourceID ?? "")
            })?.taskPlan?.tasks.first(where: {
                exact($0.sourceID, subject.sourceID)
            })?.stateEvidence ?? []
        case .phaseDependency, .ticketDependency:
            return []
        }
    }

    private static func evidenceSubject(_ evidence: RepositoryPlanTerminalEvidence) -> RepositoryPlanReconstructionSubject {
        let subject: RepositoryPlanStateSubject = switch evidence {
        case let .original(_, record): record.subject
        case let .ownerAttestation(attestation): attestation.subject
        }
        return switch subject {
        case let .phase(value): .init(kind: .phase, parentSourceID: nil, sourceID: value.sourceID)
        case let .ticket(value): .init(kind: .ticket, parentSourceID: nil, sourceID: value.sourceID)
        case let .task(value): .init(kind: .task, parentSourceID: value.ticketSourceID, sourceID: value.sourceID)
        case let .goal(value): .init(kind: .phase, parentSourceID: value.phaseSourceID, sourceID: value.sourceGoalID)
        }
    }

    private static func evidenceState(_ evidence: RepositoryPlanTerminalEvidence) -> RepositoryPlanTerminalState {
        switch evidence {
        case let .original(_, record): record.state
        case let .ownerAttestation(attestation): attestation.state
        }
    }

    private static func phaseCompletion(
        _ evidence: RepositoryPlanTerminalEvidence
    ) -> RepositoryPlanPhaseCompletionCertificate? {
        switch evidence {
        case let .original(_, record): record.phaseCompletion
        case let .ownerAttestation(attestation): attestation.phaseCompletion
        }
    }

    private static func originalOccurrence(_ evidence: [RepositoryPlanTerminalEvidence]) -> Date? {
        evidence.compactMap {
            switch $0 {
            case let .original(_, record): record.occurredAt
            case let .ownerAttestation(attestation): attestation.originalOccurredAt
            }
        }.sorted().first
    }

    private static func originalOccurrence(
        _ evidence: [RepositoryPlanTerminalEvidence],
        state: RepositoryPlanTerminalState
    ) -> Date? {
        originalOccurrence(evidence.filter { evidenceState($0) == state })
    }

    private static func originalActor(_ evidence: [RepositoryPlanTerminalEvidence]) -> String? {
        evidence.compactMap {
            switch $0 {
            case let .original(_, record): record.actorID
            case let .ownerAttestation(attestation): attestation.originalActorID
            }
        }.first
    }

    private static func exact(_ lhs: String, _ rhs: String) -> Bool {
        Data(lhs.utf8) == Data(rhs.utf8)
    }

    private static func comparisonFor(
        _ sourceID: String,
        kind: RepositoryPlanReconstructionRecordKind,
        in comparisons: [RepositoryPlanReconstructionComparison]
    ) -> RepositoryPlanReconstructionComparison? {
        comparisons.first { $0.kind == kind && exact($0.sourceID, sourceID) }
    }

    private static func comparisonFor(
        _ sourceID: String,
        parentSourceID: String?,
        kind: RepositoryPlanReconstructionRecordKind,
        in comparisons: [RepositoryPlanReconstructionComparison]
    ) -> RepositoryPlanReconstructionComparison? {
        comparisons.first {
            $0.kind == kind && exact($0.sourceID, sourceID)
                && optionalExact($0.parentSourceID, parentSourceID)
        }
    }

    static func authorityClass(
        for subject: RepositoryPlanReconstructionSubject,
        projection: RepositoryPlanProjection
    ) -> RepositoryPlanAuthorityClass? {
        switch subject.kind {
        case .phase:
            projection.phases.first(where: {
                exact($0.sourceID, subject.sourceID)
            })?.authorityClass
        case .ticket:
            projection.tickets.first(where: {
                exact($0.sourceID, subject.sourceID)
            })?.authorityClass
        case .task:
            projection.tickets.first(where: {
                exact($0.sourceID, subject.parentSourceID ?? "")
            })?.taskPlan?.tasks.first(where: {
                exact($0.sourceID, subject.sourceID)
            })?.authorityClass
        case .phaseDependency, .ticketDependency:
            nil
        }
    }

    private static func isIncluded(
        _ subject: RepositoryPlanReconstructionSubject,
        comparisons: [RepositoryPlanReconstructionComparison]
    ) -> Bool {
        guard let disposition = comparisons.first(where: {
            $0.subject == subject
        })?.disposition else { return false }
        return disposition == .new || disposition == .unchanged
    }

    private static func optionalExact(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (.some(lhs), .some(rhs)): exact(lhs, rhs)
        default: false
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func validateReviewedProjection(
        _ projection: RepositoryPlanProjection,
        manifest: RepositoryPlanSourceManifest
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(projection)
        let validationManifest = RepositoryPlanSourceManifest(
            projectID: manifest.projectID,
            rootID: manifest.rootID,
            rootPath: manifest.rootPath,
            registration: manifest.registration,
            repositoryID: manifest.repositoryID,
            acceptedCatalogVersion: manifest.acceptedCatalogVersion,
            acceptedCatalogDigest: manifest.acceptedCatalogDigest,
            sources: manifest.sources.filter {
                Data($0.path.utf8) != Data("docs/delivery/reconstruction-plan.json".utf8)
            }
        )
        _ = try RepositoryPlanProjectionValidator.validate(bytes, against: validationManifest)
    }

    private static func timestamp(_ date: Date = Date()) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
