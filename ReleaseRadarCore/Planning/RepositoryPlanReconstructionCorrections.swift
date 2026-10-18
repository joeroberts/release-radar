import Foundation

enum RepositoryPlanReconstructionCorrections {
    static func apply(
        _ corrections: [RepositoryPlanReconstructionCorrection],
        to original: RepositoryPlanProjection
    ) throws -> RepositoryPlanProjection {
        var phases = original.phases
        var tickets = original.tickets
        var phaseDependencies = original.phaseDependencies
        var ticketDependencies = original.ticketDependencies

        for correction in corrections {
            switch correction.subject.kind {
            case .phase:
                guard correction.subject.parentSourceID == nil,
                      let index = phases.firstIndex(where: {
                          exact($0.sourceID, correction.subject.sourceID)
                      }) else { throw invalid(correction) }
                phases[index] = try corrected(phases[index], with: correction)
            case .ticket:
                guard correction.subject.parentSourceID == nil,
                      let index = tickets.firstIndex(where: {
                          exact($0.sourceID, correction.subject.sourceID)
                      }) else { throw invalid(correction) }
                tickets[index] = try corrected(tickets[index], with: correction)
            case .task:
                guard let parent = correction.subject.parentSourceID,
                      let ticketIndex = tickets.firstIndex(where: { exact($0.sourceID, parent) }),
                      let taskPlan = tickets[ticketIndex].taskPlan,
                      let taskIndex = taskPlan.tasks.firstIndex(where: {
                          exact($0.sourceID, correction.subject.sourceID)
                      }) else { throw invalid(correction) }
                var tasks = taskPlan.tasks
                tasks[taskIndex] = try corrected(tasks[taskIndex], with: correction)
                tickets[ticketIndex] = copy(
                    tickets[ticketIndex],
                    taskPlan: .init(sourceRevision: taskPlan.sourceRevision, tasks: tasks)
                )
            case .phaseDependency:
                guard let index = phaseDependencies.firstIndex(where: {
                    exact($0.sourceID, correction.subject.sourceID)
                }) else { throw invalid(correction) }
                phaseDependencies[index] = try corrected(phaseDependencies[index], with: correction)
            case .ticketDependency:
                guard let index = ticketDependencies.firstIndex(where: {
                    exact($0.sourceID, correction.subject.sourceID)
                }) else { throw invalid(correction) }
                ticketDependencies[index] = try corrected(ticketDependencies[index], with: correction)
            }
        }

        return .init(
            format: original.format,
            schemaVersion: original.schemaVersion,
            repositoryID: original.repositoryID,
            projectionID: original.projectionID,
            projectionRevision: original.projectionRevision,
            documents: original.documents,
            phases: phases,
            tickets: tickets,
            phaseDependencies: phaseDependencies,
            ticketDependencies: ticketDependencies
        )
    }

    private static func corrected(
        _ value: RepositoryPlanProjectionPhase,
        with correction: RepositoryPlanReconstructionCorrection
    ) throws -> RepositoryPlanProjectionPhase {
        switch correction.field {
        case "name":
            return .init(
                sourceID: value.sourceID,
                authorityClass: value.authorityClass,
                sourceRefs: value.sourceRefs,
                name: try replacement(correction, original: value.name),
                lifecycle: value.lifecycle,
                stateEvidence: value.stateEvidence
            )
        case "lifecycle":
            return .init(
                sourceID: value.sourceID,
                authorityClass: value.authorityClass,
                sourceRefs: value.sourceRefs,
                name: value.name,
                lifecycle: try replacement(correction, original: value.lifecycle),
                stateEvidence: value.stateEvidence
            )
        case "authorityClass":
            return .init(
                sourceID: value.sourceID,
                authorityClass: try replacement(correction, original: value.authorityClass),
                sourceRefs: value.sourceRefs,
                name: value.name,
                lifecycle: value.lifecycle,
                stateEvidence: value.stateEvidence
            )
        default: throw invalid(correction)
        }
    }

    private static func corrected(
        _ value: RepositoryPlanProjectionTicket,
        with correction: RepositoryPlanReconstructionCorrection
    ) throws -> RepositoryPlanProjectionTicket {
        switch correction.field {
        case "outcome":
            return copy(value, outcome: try replacement(correction, original: value.outcome))
        case "phaseSourceID":
            return copy(value, phaseSourceID: try replacement(correction, original: value.phaseSourceID))
        case "lane":
            return copy(value, lane: try replacement(correction, original: value.lane))
        case "authorityClass":
            return copy(value, authorityClass: try replacement(correction, original: value.authorityClass))
        default: throw invalid(correction)
        }
    }

    private static func corrected(
        _ value: RepositoryPlanProjectionTask,
        with correction: RepositoryPlanReconstructionCorrection
    ) throws -> RepositoryPlanProjectionTask {
        let authorityClass: RepositoryPlanAuthorityClass = correction.field == "authorityClass"
            ? try replacement(correction, original: value.authorityClass) : value.authorityClass
        let label: String = correction.field == "label"
            ? try replacement(correction, original: value.label) : value.label
        let title: String = correction.field == "title"
            ? try replacement(correction, original: value.title) : value.title
        let sortOrder: Int = correction.field == "sortOrder"
            ? try replacement(correction, original: value.sortOrder) : value.sortOrder
        let completion: TicketTaskCompletion = correction.field == "completion"
            ? try replacement(correction, original: value.completion) : value.completion
        let lifecycle: TicketTaskLifecycle = correction.field == "lifecycle"
            ? try replacement(correction, original: value.lifecycle) : value.lifecycle
        guard ["authorityClass", "label", "title", "sortOrder", "completion", "lifecycle"]
            .contains(correction.field) else { throw invalid(correction) }
        return .init(
            sourceID: value.sourceID,
            authorityClass: authorityClass,
            sourceRefs: value.sourceRefs,
            label: label,
            title: title,
            sortOrder: sortOrder,
            completion: completion,
            lifecycle: lifecycle,
            stateEvidence: value.stateEvidence
        )
    }

    private static func corrected(
        _ value: RepositoryPlanProjectionDependency,
        with correction: RepositoryPlanReconstructionCorrection
    ) throws -> RepositoryPlanProjectionDependency {
        guard ["subjectSourceID", "dependsOnSourceID"].contains(correction.field) else {
            throw invalid(correction)
        }
        return .init(
            sourceID: value.sourceID,
            subjectSourceID: correction.field == "subjectSourceID"
                ? try replacement(correction, original: value.subjectSourceID) : value.subjectSourceID,
            dependsOnSourceID: correction.field == "dependsOnSourceID"
                ? try replacement(correction, original: value.dependsOnSourceID) : value.dependsOnSourceID,
            sourceRefs: value.sourceRefs
        )
    }

    private static func copy(
        _ value: RepositoryPlanProjectionTicket,
        authorityClass: RepositoryPlanAuthorityClass? = nil,
        outcome: String? = nil,
        phaseSourceID: String?? = nil,
        lane: TicketLane?? = nil,
        taskPlan: RepositoryPlanProjectionTaskPlan?? = nil
    ) -> RepositoryPlanProjectionTicket {
        .init(
            sourceID: value.sourceID,
            authorityClass: authorityClass ?? value.authorityClass,
            sourceRefs: value.sourceRefs,
            outcome: outcome ?? value.outcome,
            phaseSourceID: phaseSourceID ?? value.phaseSourceID,
            lane: lane ?? value.lane,
            taskPlan: taskPlan ?? value.taskPlan,
            stateEvidence: value.stateEvidence,
            evidenceRefs: value.evidenceRefs
        )
    }

    private static func replacement<T: Codable & Equatable>(
        _ correction: RepositoryPlanReconstructionCorrection,
        original: T
    ) throws -> T {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedOriginal = try encoder.encode(original)
        guard correction.sourceValue == encodedOriginal,
              let chosen = try? JSONDecoder().decode(T.self, from: correction.chosenValue) else {
            throw invalid(correction)
        }
        return chosen
    }

    private static func invalid(
        _ correction: RepositoryPlanReconstructionCorrection
    ) -> RepositoryPlanReconstructionError {
        .invalidPayload(
            "Correction \(correction.field) for \(correction.subject.sourceID) does not exactly match a supported source field."
        )
    }

    private static func exact(_ lhs: String, _ rhs: String) -> Bool {
        Data(lhs.utf8) == Data(rhs.utf8)
    }
}
