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
    let sharedExecutionCompatibility: SharedExecutionCompatibilityResult

    init(
        identity: DocumentationObservationIdentity,
        checkedAt: Date,
        documentationState: ProjectDocumentationState,
        evidence: [EvidenceReadback],
        sharedExecutionCompatibility: SharedExecutionCompatibilityResult = .init(
            state: .unknown,
            directResults: []
        )
    ) {
        self.identity = identity
        self.checkedAt = checkedAt
        self.documentationState = documentationState
        self.evidence = evidence
        self.sharedExecutionCompatibility = sharedExecutionCompatibility
    }
}

extension DocumentationObservationPayload {
    init(
        _ snapshot: ProjectDocumentationSnapshot,
        pluginObservation: SharedExecutionPluginObservation = .unknown("Plugin status was not observed.")
    ) {
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
            evidence: snapshot.evidence,
            sharedExecutionCompatibility: Self.compatibility(
                snapshot: snapshot,
                pluginObservation: pluginObservation
            )
        )
    }

    private static func compatibility(
        snapshot: ProjectDocumentationSnapshot,
        pluginObservation: SharedExecutionPluginObservation
    ) -> SharedExecutionCompatibilityResult {
        let root: SharedExecutionRootObservation = snapshot.rootPath.map(
            SharedExecutionRootObservation.exact
        ) ?? .unknown
        let checker: SharedExecutionCheckerObservation = snapshot.repositoryDiagnostic.map {
            .result(.init($0))
        } ?? .unavailable("The repository documentation diagnostic was unavailable.")
        let repository = repositoryObservation(snapshot)
        let rows = directResults(snapshot: snapshot, pluginObservation: pluginObservation)
        return SharedExecutionCompatibilityReducer.reduce(.init(
            root: root,
            declaration: snapshot.sharedExecutionDeclaration,
            plugin: pluginObservation,
            checker: checker,
            repository: repository,
            directResults: rows
        ))
    }

    private static func repositoryObservation(
        _ snapshot: ProjectDocumentationSnapshot
    ) -> SharedExecutionRepositoryObservation {
        guard let diagnostic = snapshot.repositoryDiagnostic,
              let identity = SharedExecutionCheckerResult(diagnostic).target else {
            return snapshot.rootPath == nil
                ? .unavailable("The exact repository root is unavailable.")
                : .unknown("The repository identity could not be attributed.")
        }
        switch snapshot.documentationState {
        case let .managed(_, catalogVersion, catalogDigest):
            guard diagnostic.status == .passed else {
                return .invalid(diagnostic.error?.code ?? "Repository documentation failed validation.")
            }
            guard let binding = snapshot.binding,
                  let rootID = snapshot.rootID,
                  binding.projectID == snapshot.projectID,
                  binding.rootID == rootID,
                  binding.acceptedCatalogVersion == catalogVersion,
                  binding.acceptedCatalogDigest == catalogDigest else {
                return .identityMismatch
            }
            let acceptedIdentity = SharedExecutionRepositoryIdentity(
                repositoryID: binding.repositoryID,
                catalogVersion: binding.acceptedCatalogVersion,
                catalogDigest: binding.acceptedCatalogDigest
            )
            return identity == acceptedIdentity
                ? .accepted(acceptedIdentity)
                : .identityMismatch
        case .stagedCatalog:
            return diagnostic.status == .passed
                ? .pendingAcceptance(identity)
                : .invalid(diagnostic.error?.code ?? "Repository documentation failed validation.")
        case let .managedUnavailable(_, reason, _):
            switch reason {
            case .rootUnavailable, .staleRoot:
                return .unavailable(reason.rawValue)
            case .bindingMissing, .catalogUnaccepted:
                return diagnostic.status == .passed
                    ? .pendingAcceptance(identity)
                    : .invalid(diagnostic.error?.code ?? reason.rawValue)
            default:
                return .invalid(reason.rawValue)
            }
        case .legacy:
            return diagnostic.status == .passed
                ? .pendingAcceptance(identity)
                : .invalid(diagnostic.error?.code ?? "Repository documentation failed validation.")
        }
    }

    private static func directResults(
        snapshot: ProjectDocumentationSnapshot,
        pluginObservation: SharedExecutionPluginObservation
    ) -> [SharedExecutionDirectResult] {
        let root = snapshot.rootPath ?? "exact root unavailable"
        let diagnostic = snapshot.repositoryDiagnostic
        let documentationStatus: SharedExecutionDirectResult.Status = switch diagnostic?.status {
        case .passed: .passed
        case .failed: .failed
        case nil: .unavailable
        }
        let pluginStatus: SharedExecutionDirectResult.Status = switch pluginObservation {
        case .clean: .passed
        case .modified, .unrecognized: .failed
        case .absent, .unavailable: .unavailable
        case .unknown: .unknown
        }
        let documentationRunner = diagnostic.map {
            "Release Radar repository checker contract v\($0.checker.contractVersion)"
        } ?? "Release Radar repository checker unavailable"
        return [
            .init(
                check: "documentation",
                runner: documentationRunner,
                scope: root,
                source: "local observation; Git source unknown",
                applicability: .unknown,
                status: documentationStatus,
                directResult: documentationDirectResult(diagnostic),
                limitation: "This app observation does not establish a tested Git revision or owner acceptance."
            ),
            .init(
                check: "plugin-capability",
                runner: "Release Radar plugin lifecycle",
                scope: "release-radar plugin package",
                source: "local read-only plugin observation",
                applicability: .unknown,
                status: pluginStatus,
                directResult: pluginDirectResult(pluginObservation),
                limitation: "A lifecycle receipt does not prove that the current task loaded the skill."
            ),
        ]
    }

    private static func documentationDirectResult(
        _ diagnostic: RepositoryDocumentDiagnostic?
    ) -> String {
        guard let diagnostic else { return "diagnostic unavailable" }
        guard diagnostic.status == .failed else { return diagnostic.status.rawValue }
        guard let code = diagnostic.error?.code,
              RepositoryDocumentError.Code(rawValue: code) != nil
                || RepositoryDocumentIndexError.Code(rawValue: code) != nil else {
            return diagnostic.status.rawValue
        }
        return "failed (\(code))"
    }

    private static func pluginDirectResult(
        _ observation: SharedExecutionPluginObservation
    ) -> String {
        switch observation {
        case .clean:
            "recognized capability installed"
        case .absent:
            "plugin absent"
        case .modified:
            "plugin package modified"
        case .unrecognized:
            "plugin capability unrecognized"
        case .unavailable:
            "plugin observation unavailable"
        case .unknown:
            "plugin observation unknown"
        }
    }
}

struct ProjectDocumentationObservation: Equatable, Sendable {
    let identity: DocumentationObservationIdentity
    let generation: UInt64
    let checkedAt: Date
    let documentationState: ProjectDocumentationState
    let evidence: [EvidenceReadback]
    let sharedExecutionCompatibility: SharedExecutionCompatibilityResult

    init(
        identity: DocumentationObservationIdentity,
        generation: UInt64,
        checkedAt: Date,
        documentationState: ProjectDocumentationState,
        evidence: [EvidenceReadback],
        sharedExecutionCompatibility: SharedExecutionCompatibilityResult = .init(
            state: .unknown,
            directResults: []
        )
    ) {
        self.identity = identity
        self.generation = generation
        self.checkedAt = checkedAt
        self.documentationState = documentationState
        self.evidence = evidence
        self.sharedExecutionCompatibility = sharedExecutionCompatibility
    }
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
            evidence: payload.evidence,
            sharedExecutionCompatibility: payload.sharedExecutionCompatibility
        )
        statuses[projectID] = .observed(observation)
        return observation
    }
}
