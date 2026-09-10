import Foundation

public struct PlanChangeProposalID: DeliveryRecordID {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum PlanChangeOperation: Codable, Equatable, Sendable {
    case addPhase(id: PhaseID, name: String)
    case addDeliveryGoal(phaseID: PhaseID, goal: DeliveryGoalDraft)
    case addUnassignedTicket(id: TicketID, outcome: String)
    case addPendingTicketTasks(ticketID: TicketID, tasks: [TicketTaskDraft])
    case placeTicket(ticketID: TicketID, phaseID: PhaseID)
    case assignTicketToGoal(ticketID: TicketID, phaseID: PhaseID, goalID: DeliveryGoalID)
    case addPhaseDependency(
        id: PhaseDependencyID,
        phaseID: PhaseID,
        dependsOnPhaseID: PhaseID
    )
    case addTicketDependency(
        id: TicketDependencyID,
        ticketID: TicketID,
        dependsOnTicketID: TicketID
    )
}

public enum PlanChangeDiffKind: String, Codable, Equatable, Sendable {
    case phases
    case goals
    case tickets
    case tasks
    case assignments
    case dependencies
}

public struct PlanChangeDiffItem: Codable, Equatable, Sendable {
    public let summary: String

    public init(summary: String) {
        self.summary = summary
    }
}

public struct PlanChangeDiffGroup: Codable, Equatable, Sendable {
    public let kind: PlanChangeDiffKind
    public let items: [PlanChangeDiffItem]

    public init(kind: PlanChangeDiffKind, items: [PlanChangeDiffItem]) {
        self.kind = kind
        self.items = items
    }
}

public struct PlanChangeDiff: Codable, Equatable, Sendable {
    public let groups: [PlanChangeDiffGroup]

    public init(groups: [PlanChangeDiffGroup]) {
        self.groups = groups
    }
}

public struct PlanChangeRecordedSourceImpact: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(ticketID.rawValue):\(linkID):\(version)" }
    public let ticketID: TicketID
    public let linkID: String
    public let kind: TicketReferenceKind
    public let repositoryID: String
    public let artifactID: String
    public let version: Int64
    public let contentDigest: String
    public let sourceLocalID: String?
    public let observedPath: String
    public let observedLifecycle: RepositoryDocumentArtifact.Lifecycle
    public let observedAuthority: RepositoryDocumentArtifact.Authority

    public init(
        ticketID: TicketID,
        linkID: String,
        kind: TicketReferenceKind,
        repositoryID: String,
        artifactID: String,
        version: Int64,
        contentDigest: String,
        sourceLocalID: String?,
        observedPath: String,
        observedLifecycle: RepositoryDocumentArtifact.Lifecycle,
        observedAuthority: RepositoryDocumentArtifact.Authority
    ) {
        self.ticketID = ticketID
        self.linkID = linkID
        self.kind = kind
        self.repositoryID = repositoryID
        self.artifactID = artifactID
        self.version = version
        self.contentDigest = contentDigest
        self.sourceLocalID = sourceLocalID
        self.observedPath = observedPath
        self.observedLifecycle = observedLifecycle
        self.observedAuthority = observedAuthority
    }
}

public enum PlanChangeBaselineCategory: String, Codable, Equatable, CaseIterable, Sendable {
    case project
    case registration
    case activePhase = "active_phase"
    case phases
    case phasePlans = "phase_plans"
    case goals
    case goalCriteria = "goal_criteria"
    case goalAssignments = "goal_assignments"
    case tickets
    case taskPlans = "task_plans"
    case tasks
    case phaseDependencies = "phase_dependencies"
    case ticketDependencies = "ticket_dependencies"
    case referenceSets = "reference_sets"
    case referenceLinks = "reference_links"
    case referenceVersions = "reference_versions"
    case documentationBinding = "documentation_binding"
    case recoveryAuthority = "recovery_authority"
}

public enum PlanChangeDecisionDisposition: String, Codable, Equatable, Sendable {
    case approved
    case rejected
}

public struct PlanChangeDecisionRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let disposition: PlanChangeDecisionDisposition
    public let actorID: String
    public let baselineDigest: String
    public let registration: ProjectRegistration
    public let createdAt: Date
}

public struct PlanChangeApplicationRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let decisionID: String
    public let auditEventID: AuditEventID
    public let appliedAt: Date
}

public struct PlanChangeProposalVersionRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: Int64 { version }
    public let version: Int64
    public let registration: ProjectRegistration
    public let baselineDigest: String
    public let baseline: Data
    public let operations: [PlanChangeOperation]
    public let diff: PlanChangeDiff
    public let sourceImpacts: [PlanChangeRecordedSourceImpact]
    public let rationale: String
    public let createdAt: Date
    public let decision: PlanChangeDecisionRecord?
    public let application: PlanChangeApplicationRecord?
}

public struct PlanChangeProposalRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: PlanChangeProposalID
    public let projectID: ProjectID
    public let currentVersion: Int64
    public let versions: [PlanChangeProposalVersionRecord]
}

public enum PlanChangeProposalError: Error, LocalizedError, Equatable, Sendable {
    case registrationRequired
    case notFound
    case versionConflict(expected: Int64?, current: Int64?)
    case invalidOperation(String)
    case ownerAuthorityRequired
    case decisionConflict
    case decisionNotApproved
    case decisionMismatch
    case alreadyApplied
    case stale([PlanChangeBaselineCategory])
    case invalidStoredProposal

    public var errorDescription: String? {
        switch self {
        case .registrationRequired:
            "A current project registration is required for plan-change proposals."
        case .notFound:
            "The plan-change proposal is unavailable. Refresh Project Plan and try again."
        case let .versionConflict(expected, current):
            "The proposal version changed (expected \(expected.map(String.init) ?? "none"), current \(current.map(String.init) ?? "none")). Refresh before saving."
        case let .invalidOperation(message):
            message
        case .ownerAuthorityRequired:
            "Only the owner application can decide or apply a plan-change proposal."
        case .decisionConflict:
            "This proposal version already has a decision. Refresh its history."
        case .decisionNotApproved:
            "Approve this exact proposal version before applying it."
        case .decisionMismatch:
            "The proposal decision, baseline, or registration no longer matches. Refresh before applying."
        case .alreadyApplied:
            "This proposal version was already applied. Refresh its application record."
        case let .stale(categories):
            "The proposal baseline changed in: \(categories.map(\.rawValue).joined(separator: ", ")). Refresh and approve a new version."
        case .invalidStoredProposal:
            "The saved plan-change proposal is invalid."
        }
    }
}
