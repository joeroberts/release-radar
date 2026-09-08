import Foundation
import Observation
import ReleaseRadarCore

struct DocumentationObservationIdentity: Equatable, Sendable {
    let projectID: ProjectID
    let registration: ProjectRegistration?
    let rootID: ProjectRootID?
    let rootPath: String?
    let binding: ProjectDocumentationBinding?
}

struct DocumentationObservationPayload: Equatable, Sendable {
    let identity: DocumentationObservationIdentity
    let checkedAt: Date
    let documentationState: ProjectDocumentationState
    let evidence: [EvidenceReadback]
}

extension DocumentationObservationPayload {
    init(_ snapshot: ProjectDocumentationSnapshot) {
        self.init(
            identity: .init(
                projectID: snapshot.projectID,
                registration: snapshot.registration,
                rootID: snapshot.rootID,
                rootPath: snapshot.rootPath,
                binding: snapshot.binding
            ),
            checkedAt: snapshot.checkedAt,
            documentationState: snapshot.documentationState,
            evidence: snapshot.evidence
        )
    }
}

struct ProjectDocumentationObservation: Equatable, Sendable {
    let identity: DocumentationObservationIdentity
    let generation: UInt64
    let checkedAt: Date
    let documentationState: ProjectDocumentationState
    let evidence: [EvidenceReadback]
}

enum DocumentationObservationStatus: Equatable, Sendable {
    case checking(identity: DocumentationObservationIdentity?, generation: UInt64)
    case observed(ProjectDocumentationObservation)

    var identity: DocumentationObservationIdentity? {
        switch self {
        case let .checking(identity, _): identity
        case let .observed(observation): observation.identity
        }
    }
}

@MainActor
@Observable
final class DocumentationObservationCoordinator {
    typealias Loader = @Sendable (ProjectID) async -> DocumentationObservationPayload

    private struct PendingObservation {
        let generation: UInt64
        let task: Task<DocumentationObservationPayload, Never>
    }

    private let loader: Loader
    private var statuses: [ProjectID: DocumentationObservationStatus] = [:]
    private var generations: [ProjectID: UInt64] = [:]
    private var inFlight: [ProjectID: PendingObservation] = [:]

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    func status(for projectID: ProjectID) -> DocumentationObservationStatus? {
        statuses[projectID]
    }

    func invalidate(projectID: ProjectID) {
        let generation = (generations[projectID] ?? 0) &+ 1
        generations[projectID] = generation
        inFlight.removeValue(forKey: projectID)?.task.cancel()
        statuses[projectID] = .checking(
            identity: statuses[projectID]?.identity,
            generation: generation
        )
    }

    func remove(projectID: ProjectID) {
        generations[projectID] = (generations[projectID] ?? 0) &+ 1
        inFlight.removeValue(forKey: projectID)?.task.cancel()
        statuses[projectID] = nil
    }

    func retain(projectIDs: Set<ProjectID>) {
        for projectID in statuses.keys where !projectIDs.contains(projectID) {
            remove(projectID: projectID)
        }
    }

    @discardableResult
    func refresh(
        projectID: ProjectID,
        withdrawCurrent: Bool = true
    ) async -> ProjectDocumentationObservation? {
        if let pending = inFlight[projectID] {
            let payload = await pending.task.value
            return publish(
                payload,
                projectID: projectID,
                generation: pending.generation
            )
        }

        let generation: UInt64
        if case let .checking(_, currentGeneration) = statuses[projectID],
           generations[projectID] == currentGeneration {
            generation = currentGeneration
        } else {
            generation = (generations[projectID] ?? 0) &+ 1
            generations[projectID] = generation
        }
        if withdrawCurrent {
            statuses[projectID] = .checking(
                identity: statuses[projectID]?.identity,
                generation: generation
            )
        }
        let task = Task { await loader(projectID) }
        inFlight[projectID] = PendingObservation(generation: generation, task: task)
        let payload = await task.value
        return publish(payload, projectID: projectID, generation: generation)
    }

    private func publish(
        _ payload: DocumentationObservationPayload,
        projectID: ProjectID,
        generation: UInt64
    ) -> ProjectDocumentationObservation? {
        if case let .observed(observation) = statuses[projectID],
           observation.generation == generation,
           observation.identity == payload.identity {
            return observation
        }
        guard generations[projectID] == generation,
              inFlight[projectID]?.generation == generation else { return nil }
        inFlight[projectID] = nil
        let observation = ProjectDocumentationObservation(
            identity: payload.identity,
            generation: generation,
            checkedAt: payload.checkedAt,
            documentationState: payload.documentationState,
            evidence: payload.evidence
        )
        statuses[projectID] = .observed(observation)
        return observation
    }
}
