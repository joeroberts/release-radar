import Foundation

public struct RepositoryPlanPreparationIdentity: Codable, Equatable, Sendable {
    public let registration: ProjectRegistration
    public let rootID: String
    public let proposalID: PlanChangeProposalID
    public let attemptID: UUID

    public init(
        registration: ProjectRegistration,
        rootID: String,
        proposalID: PlanChangeProposalID,
        attemptID: UUID
    ) {
        self.registration = registration
        self.rootID = rootID
        self.proposalID = proposalID
        self.attemptID = attemptID
    }
}

/// An app-owned copy of the selected source set. The working directory is kept
/// below the snapshot root so selected AGENTS-like documents remain input data,
/// rather than becoming discovered instruction sources.
public struct RepositoryPlanPreparationSnapshot: Codable, Equatable, Sendable {
    public let rootPath: String
    public let workingPath: String
    public let manifestSHA256: String

    public init(rootPath: String, workingPath: String, manifestSHA256: String) {
        self.rootPath = rootPath
        self.workingPath = workingPath
        self.manifestSHA256 = manifestSHA256
    }
}

/// App-produced preparation authority. It contains no delivery task,
/// assignment, phase, worker or mutation identity.
public struct RepositoryPlanPreparationRequest: Codable, Equatable, Sendable {
    public var identity: RepositoryPlanPreparationIdentity
    public var sourceManifest: RepositoryPlanSourceManifest
    public var snapshot: RepositoryPlanPreparationSnapshot
    public var projectionID: UUID
    public var projectionRevision: Int
    public var codexContextID: UUID
    public var model: String
    public var effort: String

    public init(
        identity: RepositoryPlanPreparationIdentity,
        sourceManifest: RepositoryPlanSourceManifest,
        snapshot: RepositoryPlanPreparationSnapshot,
        projectionID: UUID,
        projectionRevision: Int,
        codexContextID: UUID,
        model: String,
        effort: String
    ) {
        self.identity = identity
        self.sourceManifest = sourceManifest
        self.snapshot = snapshot
        self.projectionID = projectionID
        self.projectionRevision = projectionRevision
        self.codexContextID = codexContextID
        self.model = model
        self.effort = effort
    }
}

public enum RepositoryPlanPreparationState: String, Codable, Equatable, Sendable {
    case queued
    case running
    case awaitingResolution = "awaiting_resolution"
    case readyForReview = "ready_for_review"
    case failed
    case cancelled
    case outcomeUnknown = "outcome_unknown"
}

public struct RepositoryPlanPreparationReadback: Codable, Equatable, Sendable {
    public let identity: RepositoryPlanPreparationIdentity
    public let state: RepositoryPlanPreparationState
    public let threadID: String?
    public let turnID: String?
    public let draftBytes: Data?
    public let error: String?

    public init(
        identity: RepositoryPlanPreparationIdentity,
        state: RepositoryPlanPreparationState,
        threadID: String?,
        turnID: String?,
        draftBytes: Data?,
        error: String?
    ) {
        self.identity = identity
        self.state = state
        self.threadID = threadID
        self.turnID = turnID
        self.draftBytes = draftBytes
        self.error = error
    }
}

public struct RepositoryPlanPreparationError: Error, LocalizedError, Equatable, Sendable {
    public enum Code: String, Codable, Equatable, Sendable {
        case invalidRequest
        case identityMismatch
        case unsupportedRuntime
        case outputLimitExceeded
        case outputTruncated
        case outcomeUnknown
        case sourceChanged
    }

    public let code: Code
    public let detail: String?

    public init(code: Code, detail: String? = nil) {
        self.code = code
        self.detail = detail
    }

    public var errorDescription: String? {
        let message: String = switch code {
        case .invalidRequest:
            "The repository plan preparation request is invalid."
        case .identityMismatch:
            "Repository plan preparation no longer matches its project, source snapshot or selected Codex context."
        case .unsupportedRuntime:
            "The selected Codex runtime cannot enforce the required read-only preparation boundary."
        case .outputLimitExceeded:
            "The prepared repository plan exceeds the 1 MiB limit. Narrow the selected sources and try again."
        case .outputTruncated:
            "The prepared repository plan was truncated and cannot be reviewed or applied."
        case .outcomeUnknown:
            "The preparation outcome is unknown. Reconcile the existing attempt before starting another."
        case .sourceChanged:
            "The selected repository sources changed. Review the current source disclosure before preparing again."
        }
        guard let detail, !detail.isEmpty else { return message }
        return message + " " + detail
    }
}
