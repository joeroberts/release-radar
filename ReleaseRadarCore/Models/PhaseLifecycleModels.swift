import Foundation

public enum PhaseLifecycle: String, Codable, CaseIterable, Sendable {
    case unassessed
    case upcoming
    case inDelivery = "in_delivery"
    case completed
}

public enum PhaseLifecycleAction: String, Codable, CaseIterable, Sendable {
    case moveToUpcoming = "move_upcoming"
    case beginDelivery = "begin_delivery"
    case complete
    case reopenInDelivery = "reopen_in_delivery"
    case reopenUpcoming = "reopen_upcoming"

    public var intendedLifecycle: PhaseLifecycle {
        switch self {
        case .moveToUpcoming, .reopenUpcoming: .upcoming
        case .beginDelivery, .reopenInDelivery: .inDelivery
        case .complete: .completed
        }
    }
}

public struct PhaseLifecycleRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let lifecycle: PhaseLifecycle
    public let revision: Int64
    public let completionBaselineDigest: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        projectID: ProjectID,
        phaseID: PhaseID,
        lifecycle: PhaseLifecycle,
        revision: Int64,
        completionBaselineDigest: String?,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?
    ) {
        self.projectID = projectID
        self.phaseID = phaseID
        self.lifecycle = lifecycle
        self.revision = revision
        self.completionBaselineDigest = completionBaselineDigest
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

public struct PhaseLifecycleEventRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let revision: Int64
    public let previousLifecycle: PhaseLifecycle
    public let currentLifecycle: PhaseLifecycle
    public let action: PhaseLifecycleAction
    public let reason: String
    public let auditEventID: AuditEventID
    public let registration: ProjectRegistration
    public let planningBaselineDigest: String?
    public let createdAt: Date
}

public enum PhaseCompletionBlockerKind: String, Codable, CaseIterable, Sendable {
    case planNotReady = "plan_not_ready"
    case goalNotAccepted = "goal_not_accepted"
    case goalCoverageUnresolved = "goal_coverage_unresolved"
    case ticketNotAccepted = "ticket_not_accepted"
    case noDeliveredOutcome = "no_delivered_outcome"
}

public struct PhaseCompletionBlocker: Codable, Equatable, Sendable, Identifiable {
    public let kind: PhaseCompletionBlockerKind
    public let entityID: String?
    public let message: String

    public var id: String { "\(kind.rawValue):\(entityID ?? "phase")" }

    public init(kind: PhaseCompletionBlockerKind, entityID: String?, message: String) {
        self.kind = kind
        self.entityID = entityID
        self.message = message
    }
}

public struct PhaseCompletionAssessment: Codable, Equatable, Sendable {
    public let phaseID: PhaseID
    public let planningBaselineDigest: String
    public let blockers: [PhaseCompletionBlocker]

    public var isEligible: Bool { blockers.isEmpty }

    public init(
        phaseID: PhaseID,
        planningBaselineDigest: String,
        blockers: [PhaseCompletionBlocker]
    ) {
        self.phaseID = phaseID
        self.planningBaselineDigest = planningBaselineDigest
        self.blockers = blockers
    }
}

public enum PhaseLifecyclePolicyError: Error, LocalizedError, Equatable, Sendable {
    case notFound(PhaseID)
    case revisionConflict(expected: Int64, current: Int64)
    case invalidTransition(from: PhaseLifecycle, action: PhaseLifecycleAction)
    case ownerAuthorityRequired
    case registrationRequired
    case planningBaselineRequired
    case planningBaselineConflict
    case completionBlocked([PhaseCompletionBlocker])
    case completedPhaseReadOnly(PhaseID)
    case invalidStoredLifecycle

    public var errorDescription: String? {
        switch self {
        case .notFound: "The phase lifecycle does not exist. Refresh the project."
        case .revisionConflict: "The phase lifecycle changed. Refresh before retrying."
        case .invalidTransition: "That phase lifecycle transition is not permitted."
        case .ownerAuthorityRequired: "Only the owner application can decide phase lifecycle."
        case .registrationRequired: "Refresh the project registration before deciding phase lifecycle."
        case .planningBaselineRequired: "Refresh completion readiness before completing the phase."
        case .planningBaselineConflict: "Planning changed after completion readiness was assessed. Refresh and retry."
        case .completionBlocked: "Resolve the listed phase completion blockers before completing the phase."
        case .completedPhaseReadOnly: "Completed phases are read-only for delivery work. Reopen the phase before making changes."
        case .invalidStoredLifecycle: "Stored phase lifecycle data is invalid."
        }
    }
}
