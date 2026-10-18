import CryptoKit
import Foundation

public enum RepositoryPlanReconstructionRecordKind: String, Codable, Equatable, Hashable, Sendable {
    case phase
    case ticket
    case task
    case phaseDependency = "phase_dependency"
    case ticketDependency = "ticket_dependency"
}

public enum RepositoryPlanReconstructionComparisonDisposition: String, Codable, Equatable, Sendable {
    case new
    case unchanged
    case conflicting
    case blocked
    case excluded
}

public struct RepositoryPlanReconstructionSubject: Codable, Equatable, Hashable, Sendable {
    public let kind: RepositoryPlanReconstructionRecordKind
    public let parentSourceID: String?
    public let sourceID: String

    public init(
        kind: RepositoryPlanReconstructionRecordKind,
        parentSourceID: String?,
        sourceID: String
    ) {
        self.kind = kind
        self.parentSourceID = parentSourceID
        self.sourceID = sourceID
    }
}

public enum RepositoryPlanReconstructionIdentity {
    public static func destinationID(
        source: RepositoryPlanReconstructionSourceSnapshot,
        subject: RepositoryPlanReconstructionSubject
    ) -> String {
        let components = [
            source.repositoryID,
            source.projectionID.uuidString.lowercased(),
            subject.kind.rawValue,
            subject.parentSourceID ?? "",
            subject.sourceID,
        ]
        let bytes = Data(components.joined(separator: "\0").utf8)
        return "rpr-" + SHA256.hash(data: bytes)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public struct RepositoryPlanReconstructionComparison: Codable, Equatable, Sendable {
    public let kind: RepositoryPlanReconstructionRecordKind
    public let parentSourceID: String?
    public let sourceID: String
    public let destinationID: String?
    public let disposition: RepositoryPlanReconstructionComparisonDisposition

    public init(
        kind: RepositoryPlanReconstructionRecordKind,
        parentSourceID: String?,
        sourceID: String,
        destinationID: String?,
        disposition: RepositoryPlanReconstructionComparisonDisposition
    ) {
        self.kind = kind
        self.parentSourceID = parentSourceID
        self.sourceID = sourceID
        self.destinationID = destinationID
        self.disposition = disposition
    }

    public var subject: RepositoryPlanReconstructionSubject {
        .init(kind: kind, parentSourceID: parentSourceID, sourceID: sourceID)
    }
}

public struct RepositoryPlanReconstructionMappingSelection: Codable, Equatable, Sendable {
    public let subject: RepositoryPlanReconstructionSubject
    public let destinationID: String

    public init(subject: RepositoryPlanReconstructionSubject, destinationID: String) {
        self.subject = subject
        self.destinationID = destinationID
    }
}

public struct RepositoryPlanReconstructionPreview: Codable, Equatable, Sendable {
    public let comparisons: [RepositoryPlanReconstructionComparison]
    public let blockers: [RepositoryPlanReconstructionBlocker]

    public init(
        comparisons: [RepositoryPlanReconstructionComparison],
        blockers: [RepositoryPlanReconstructionBlocker]
    ) {
        self.comparisons = comparisons
        self.blockers = blockers
    }
}

public struct RepositoryPlanReconstructionCorrection: Codable, Equatable, Sendable {
    public let subject: RepositoryPlanReconstructionSubject
    public let field: String
    public let sourceValue: Data?
    public let chosenValue: Data

    public init(
        subject: RepositoryPlanReconstructionSubject,
        field: String,
        sourceValue: Data?,
        chosenValue: Data
    ) {
        self.subject = subject
        self.field = field
        self.sourceValue = sourceValue
        self.chosenValue = chosenValue
    }
}

public struct RepositoryPlanReconstructionExclusion: Codable, Equatable, Sendable {
    public let subject: RepositoryPlanReconstructionSubject
    public let reason: String

    public init(subject: RepositoryPlanReconstructionSubject, reason: String) {
        self.subject = subject
        self.reason = reason
    }
}

public enum RepositoryPlanTerminalState: String, Codable, Equatable, Sendable {
    case accepted
    case completed
    case superseded
    case unassessed
    case upcoming
    case inDelivery = "in_delivery"
}

public struct RepositoryPlanStateTaskSubject: Codable, Equatable, Sendable {
    public let ticketSourceID: String
    public let sourceID: String
    public let label: String
    public let title: String
    public let sortOrder: Int

    public init(
        ticketSourceID: String,
        sourceID: String,
        label: String,
        title: String,
        sortOrder: Int
    ) {
        self.ticketSourceID = ticketSourceID
        self.sourceID = sourceID
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
    }
}

public struct RepositoryPlanStateTaskSnapshot: Codable, Equatable, Sendable {
    public let sourceID: String
    public let label: String
    public let title: String
    public let sortOrder: Int
    public let completion: TicketTaskCompletion
    public let lifecycle: TicketTaskLifecycle

    public init(
        sourceID: String,
        label: String,
        title: String,
        sortOrder: Int,
        completion: TicketTaskCompletion,
        lifecycle: TicketTaskLifecycle
    ) {
        self.sourceID = sourceID
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
        self.completion = completion
        self.lifecycle = lifecycle
    }
}

public struct RepositoryPlanStateTicketTaskPlan: Codable, Equatable, Sendable {
    public let sourceRevision: Int
    public let tasks: [RepositoryPlanStateTaskSnapshot]

    public init(sourceRevision: Int, tasks: [RepositoryPlanStateTaskSnapshot]) {
        self.sourceRevision = sourceRevision
        self.tasks = tasks
    }
}

public struct RepositoryPlanStateTicketSubject: Codable, Equatable, Sendable {
    public let sourceID: String
    public let outcome: String
    public let phaseSourceID: String?
    public let taskPlan: RepositoryPlanStateTicketTaskPlan?

    public init(
        sourceID: String,
        outcome: String,
        phaseSourceID: String?,
        taskPlan: RepositoryPlanStateTicketTaskPlan?
    ) {
        self.sourceID = sourceID
        self.outcome = outcome
        self.phaseSourceID = phaseSourceID
        self.taskPlan = taskPlan
    }
}

public struct RepositoryPlanStatePhaseSubject: Codable, Equatable, Sendable {
    public let sourceID: String
    public let name: String

    public init(sourceID: String, name: String) {
        self.sourceID = sourceID
        self.name = name
    }
}

public struct RepositoryPlanStateGoalSubject: Codable, Equatable, Sendable {
    public let phaseSourceID: String
    public let sourceGoalID: String

    public init(phaseSourceID: String, sourceGoalID: String) {
        self.phaseSourceID = phaseSourceID
        self.sourceGoalID = sourceGoalID
    }
}

public enum RepositoryPlanStateSubject: Codable, Equatable, Sendable {
    case task(RepositoryPlanStateTaskSubject)
    case ticket(RepositoryPlanStateTicketSubject)
    case phase(RepositoryPlanStatePhaseSubject)
    case goal(RepositoryPlanStateGoalSubject)

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: RepositoryPlanStateSubjectCodingKey.self)
        let keys = Set(values.allKeys.map(\.stringValue))
        if keys.contains("ticketSourceID") {
            guard keys == ["ticketSourceID", "sourceID", "label", "title", "sortOrder"] else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Task state subjects have an exact field set."
                )
            }
            self = .task(.init(
                ticketSourceID: try values.decode(String.self, forKey: .ticketSourceID),
                sourceID: try values.decode(String.self, forKey: .sourceID),
                label: try values.decode(String.self, forKey: .label),
                title: try values.decode(String.self, forKey: .title),
                sortOrder: try values.decode(Int.self, forKey: .sortOrder)
            ))
        } else if keys.contains("outcome") {
            guard keys == ["sourceID", "outcome", "phaseSourceID", "taskPlan"] else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Ticket state subjects have an exact field set."
                )
            }
            self = .ticket(.init(
                sourceID: try values.decode(String.self, forKey: .sourceID),
                outcome: try values.decode(String.self, forKey: .outcome),
                phaseSourceID: try values.decodeIfPresent(String.self, forKey: .phaseSourceID),
                taskPlan: try values.decodeIfPresent(RepositoryPlanStateTicketTaskPlan.self, forKey: .taskPlan)
            ))
        } else if keys.contains("name") {
            guard keys == ["sourceID", "name"] else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Phase state subjects have an exact field set."
                )
            }
            self = .phase(.init(
                sourceID: try values.decode(String.self, forKey: .sourceID),
                name: try values.decode(String.self, forKey: .name)
            ))
        } else {
            guard keys == ["phaseSourceID", "sourceGoalID"] else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Goal state subjects have an exact field set."
                )
            }
            self = .goal(.init(
                phaseSourceID: try values.decode(String.self, forKey: .phaseSourceID),
                sourceGoalID: try values.decode(String.self, forKey: .sourceGoalID)
            ))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: RepositoryPlanStateSubjectCodingKey.self)
        switch self {
        case let .task(subject):
            try values.encode(subject.ticketSourceID, forKey: .ticketSourceID)
            try values.encode(subject.sourceID, forKey: .sourceID)
            try values.encode(subject.label, forKey: .label)
            try values.encode(subject.title, forKey: .title)
            try values.encode(subject.sortOrder, forKey: .sortOrder)
        case let .ticket(subject):
            try values.encode(subject.sourceID, forKey: .sourceID)
            try values.encode(subject.outcome, forKey: .outcome)
            try values.encode(subject.phaseSourceID, forKey: .phaseSourceID)
            try values.encode(subject.taskPlan, forKey: .taskPlan)
        case let .phase(subject):
            try values.encode(subject.sourceID, forKey: .sourceID)
            try values.encode(subject.name, forKey: .name)
        case let .goal(subject):
            try values.encode(subject.phaseSourceID, forKey: .phaseSourceID)
            try values.encode(subject.sourceGoalID, forKey: .sourceGoalID)
        }
    }
}

private enum RepositoryPlanStateSubjectCodingKey: String, CodingKey, CaseIterable {
    case ticketSourceID
    case sourceID
    case label
    case title
    case sortOrder
    case outcome
    case phaseSourceID
    case taskPlan
    case name
    case sourceGoalID
}

public struct RepositoryPlanPhaseCompletionTicket: Codable, Equatable, Sendable {
    public let sourceTicketID: String
    public let lane: TicketLane
    public let acceptanceProof: RepositoryPlanSourceReference?

    public init(
        sourceTicketID: String,
        lane: TicketLane,
        acceptanceProof: RepositoryPlanSourceReference?
    ) {
        self.sourceTicketID = sourceTicketID
        self.lane = lane
        self.acceptanceProof = acceptanceProof
    }
}

public struct RepositoryPlanPhaseCompletionGoal: Codable, Equatable, Sendable {
    public enum Lifecycle: String, Codable, Equatable, Sendable {
        case draft
        case accepted
        case superseded
    }

    public let sourceGoalID: String
    public let required: Bool
    public let lifecycle: Lifecycle
    public let remainingDebt: Bool

    public init(
        sourceGoalID: String,
        required: Bool,
        lifecycle: Lifecycle,
        remainingDebt: Bool
    ) {
        self.sourceGoalID = sourceGoalID
        self.required = required
        self.lifecycle = lifecycle
        self.remainingDebt = remainingDebt
    }
}

public struct RepositoryPlanPhaseCompletionReference: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case ticket
        case goal
    }

    public let kind: Kind
    public let phaseSourceID: String
    public let sourceID: String
    public let proofRef: RepositoryPlanSourceReference?

    public init(
        kind: Kind,
        phaseSourceID: String,
        sourceID: String,
        proofRef: RepositoryPlanSourceReference?
    ) {
        self.kind = kind
        self.phaseSourceID = phaseSourceID
        self.sourceID = sourceID
        self.proofRef = proofRef
    }
}

public struct RepositoryPlanPhaseCompletionObligation: Codable, Equatable, Sendable {
    public enum Disposition: String, Codable, Equatable, Sendable {
        case fulfilled
        case explicitlyDropped = "explicitly_dropped"
        case supersededDebtFree = "superseded_debt_free"
        case unresolved
        case unassessed
    }

    public let sourceObligationID: String
    public let disposition: Disposition
    public let descendants: [RepositoryPlanPhaseCompletionReference]

    public init(
        sourceObligationID: String,
        disposition: Disposition,
        descendants: [RepositoryPlanPhaseCompletionReference]
    ) {
        self.sourceObligationID = sourceObligationID
        self.disposition = disposition
        self.descendants = descendants
    }
}

public struct RepositoryPlanPhaseCompletionCertificate: Codable, Equatable, Sendable {
    public let membershipComplete: Bool
    public let tickets: [RepositoryPlanPhaseCompletionTicket]
    public let goals: [RepositoryPlanPhaseCompletionGoal]
    public let obligations: [RepositoryPlanPhaseCompletionObligation]
    public let deliveredBy: [RepositoryPlanPhaseCompletionReference]

    public init(
        membershipComplete: Bool,
        tickets: [RepositoryPlanPhaseCompletionTicket],
        goals: [RepositoryPlanPhaseCompletionGoal],
        obligations: [RepositoryPlanPhaseCompletionObligation],
        deliveredBy: [RepositoryPlanPhaseCompletionReference]
    ) {
        self.membershipComplete = membershipComplete
        self.tickets = tickets
        self.goals = goals
        self.obligations = obligations
        self.deliveredBy = deliveredBy
    }
}

public struct RepositoryPlanStateRecord: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case ticketAcceptance = "ticket_acceptance"
        case taskCompletion = "task_completion"
        case taskSupersession = "task_supersession"
        case phaseLifecycle = "phase_lifecycle"
        case goalAcceptance = "goal_acceptance"
    }

    public let format: String
    public let schemaVersion: Int
    public let recordID: String
    public let repositoryID: String
    public let kind: Kind
    public let subject: RepositoryPlanStateSubject
    public let state: RepositoryPlanTerminalState
    public let occurredAt: Date?
    public let actorID: String?
    public let phaseCompletion: RepositoryPlanPhaseCompletionCertificate?

    public init(
        format: String = "release-radar.state-record",
        schemaVersion: Int = 1,
        recordID: String,
        repositoryID: String,
        kind: Kind,
        subject: RepositoryPlanStateSubject,
        state: RepositoryPlanTerminalState,
        occurredAt: Date?,
        actorID: String?,
        phaseCompletion: RepositoryPlanPhaseCompletionCertificate?
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.recordID = recordID
        self.repositoryID = repositoryID
        self.kind = kind
        self.subject = subject
        self.state = state
        self.occurredAt = occurredAt
        self.actorID = actorID
        self.phaseCompletion = phaseCompletion
    }
}

public struct RepositoryPlanOwnerAttestation: Codable, Equatable, Sendable {
    public let id: String
    public let subject: RepositoryPlanStateSubject
    public let state: RepositoryPlanTerminalState
    public let phaseCompletion: RepositoryPlanPhaseCompletionCertificate?
    public let decisionID: String
    public let attestedAt: Date
    public let originalOccurredAt: Date?
    public let originalActorID: String?

    public init(
        id: String,
        subject: RepositoryPlanStateSubject,
        state: RepositoryPlanTerminalState,
        phaseCompletion: RepositoryPlanPhaseCompletionCertificate?,
        decisionID: String,
        attestedAt: Date,
        originalOccurredAt: Date?,
        originalActorID: String?
    ) {
        self.id = id
        self.subject = subject
        self.state = state
        self.phaseCompletion = phaseCompletion
        self.decisionID = decisionID
        self.attestedAt = attestedAt
        self.originalOccurredAt = originalOccurredAt
        self.originalActorID = originalActorID
    }
}

public enum RepositoryPlanTerminalEvidence: Codable, Equatable, Sendable {
    case original(sourceRef: RepositoryPlanSourceReference, record: RepositoryPlanStateRecord)
    case ownerAttestation(RepositoryPlanOwnerAttestation)
}

public struct RepositoryPlanReconstructionBlocker: Codable, Equatable, Sendable, Identifiable {
    public let code: String
    public let subject: RepositoryPlanReconstructionSubject?
    public let message: String

    public var id: String {
        [code, subject?.kind.rawValue, subject?.parentSourceID, subject?.sourceID]
            .compactMap { $0 }
            .joined(separator: ":")
    }

    public init(
        code: String,
        subject: RepositoryPlanReconstructionSubject?,
        message: String
    ) {
        self.code = code
        self.subject = subject
        self.message = message
    }
}

public struct RepositoryPlanReconstructionSourceSnapshot: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let rootID: String
    public let registration: ProjectRegistration
    public let repositoryID: String
    public let projectionID: UUID
    public let projectionRevision: Int
    public let projectionBytes: Data
    public let projectionSHA256: String
    public let acceptedCatalogVersion: Int
    public let acceptedCatalogDigest: String
    public let capturedSourceManifest: RepositoryPlanSourceManifest
    public let observedGitHEAD: String?

    public init(
        projectID: ProjectID,
        rootID: String,
        registration: ProjectRegistration,
        repositoryID: String,
        projectionID: UUID,
        projectionRevision: Int,
        projectionBytes: Data,
        projectionSHA256: String,
        acceptedCatalogVersion: Int,
        acceptedCatalogDigest: String,
        capturedSourceManifest: RepositoryPlanSourceManifest,
        observedGitHEAD: String?
    ) {
        self.projectID = projectID
        self.rootID = rootID
        self.registration = registration
        self.repositoryID = repositoryID
        self.projectionID = projectionID
        self.projectionRevision = projectionRevision
        self.projectionBytes = projectionBytes
        self.projectionSHA256 = projectionSHA256
        self.acceptedCatalogVersion = acceptedCatalogVersion
        self.acceptedCatalogDigest = acceptedCatalogDigest
        self.capturedSourceManifest = capturedSourceManifest
        self.observedGitHEAD = observedGitHEAD
    }
}

public struct RepositoryPlanReconstructionPayload: Codable, Equatable, Sendable {
    public let source: RepositoryPlanReconstructionSourceSnapshot
    public let reviewedProjection: RepositoryPlanProjection
    public let comparisons: [RepositoryPlanReconstructionComparison]
    public let corrections: [RepositoryPlanReconstructionCorrection]
    public let exclusions: [RepositoryPlanReconstructionExclusion]
    public let terminalEvidence: [RepositoryPlanTerminalEvidence]
    public let blockers: [RepositoryPlanReconstructionBlocker]

    public init(
        source: RepositoryPlanReconstructionSourceSnapshot,
        reviewedProjection: RepositoryPlanProjection,
        comparisons: [RepositoryPlanReconstructionComparison],
        corrections: [RepositoryPlanReconstructionCorrection],
        exclusions: [RepositoryPlanReconstructionExclusion],
        terminalEvidence: [RepositoryPlanTerminalEvidence],
        blockers: [RepositoryPlanReconstructionBlocker]
    ) {
        self.source = source
        self.reviewedProjection = reviewedProjection
        self.comparisons = comparisons
        self.corrections = corrections
        self.exclusions = exclusions
        self.terminalEvidence = terminalEvidence
        self.blockers = blockers
    }
}

public enum RepositoryPlanReconstructionApplicationAttemptState: String, Codable, Equatable, Sendable {
    case pending
    case outcomeUnknown = "outcome_unknown"
    case applied
    case refused
}

public final class RepositoryPlanReconstructionApplicationAttemptRecord: Codable, @unchecked Sendable, Equatable {
    public let projectID: ProjectID
    public let proposalID: PlanChangeProposalID
    public let version: Int64
    public let applicationID: String
    public let requestID: UUID
    public let registration: ProjectRegistration
    public let envelopeBytes: Data
    public let state: RepositoryPlanReconstructionApplicationAttemptState
    public let result: AgentCommandResult?

    public init(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        applicationID: String,
        requestID: UUID,
        registration: ProjectRegistration,
        envelopeBytes: Data,
        state: RepositoryPlanReconstructionApplicationAttemptState,
        result: AgentCommandResult?
    ) {
        self.projectID = projectID
        self.proposalID = proposalID
        self.version = version
        self.applicationID = applicationID
        self.requestID = requestID
        self.registration = registration
        self.envelopeBytes = envelopeBytes
        self.state = state
        self.result = result
    }

    public static func == (
        lhs: RepositoryPlanReconstructionApplicationAttemptRecord,
        rhs: RepositoryPlanReconstructionApplicationAttemptRecord
    ) -> Bool {
        lhs.projectID == rhs.projectID
            && lhs.proposalID == rhs.proposalID
            && lhs.version == rhs.version
            && lhs.applicationID == rhs.applicationID
            && lhs.requestID == rhs.requestID
            && lhs.registration == rhs.registration
            && lhs.envelopeBytes == rhs.envelopeBytes
            && lhs.state == rhs.state
            && lhs.result == rhs.result
    }
}

public struct RepositoryPlanReconstructionProvenanceRecord: Codable, Equatable, Sendable {
    public let proposalID: PlanChangeProposalID
    public let version: Int64
    public let applicationID: String
    public let comparison: RepositoryPlanReconstructionComparison
    public let sourceFields: Data
    public let sourceRefs: [RepositoryPlanSourceReference]
    public let evidence: [RepositoryPlanTerminalEvidence]
    public let originalOccurredAt: Date?
    public let originalActorID: String?

    public init(
        proposalID: PlanChangeProposalID,
        version: Int64,
        applicationID: String,
        comparison: RepositoryPlanReconstructionComparison,
        sourceFields: Data,
        sourceRefs: [RepositoryPlanSourceReference],
        evidence: [RepositoryPlanTerminalEvidence],
        originalOccurredAt: Date?,
        originalActorID: String?
    ) {
        self.proposalID = proposalID
        self.version = version
        self.applicationID = applicationID
        self.comparison = comparison
        self.sourceFields = sourceFields
        self.sourceRefs = sourceRefs
        self.evidence = evidence
        self.originalOccurredAt = originalOccurredAt
        self.originalActorID = originalActorID
    }
}

public struct RepositoryPlanReconstructionReadback: Codable, Equatable, Sendable {
    public let proposalID: PlanChangeProposalID
    public let version: PlanChangeProposalVersionRecord
    public let payload: RepositoryPlanReconstructionPayload
    public let applicationAttempt: RepositoryPlanReconstructionApplicationAttemptRecord?
    public let provenance: [RepositoryPlanReconstructionProvenanceRecord]
    public let remainingSetup: [String]

    public init(
        proposalID: PlanChangeProposalID,
        version: PlanChangeProposalVersionRecord,
        payload: RepositoryPlanReconstructionPayload,
        applicationAttempt: RepositoryPlanReconstructionApplicationAttemptRecord?,
        provenance: [RepositoryPlanReconstructionProvenanceRecord],
        remainingSetup: [String]
    ) {
        self.proposalID = proposalID
        self.version = version
        self.payload = payload
        self.applicationAttempt = applicationAttempt
        self.provenance = provenance
        self.remainingSetup = remainingSetup
    }
}

public struct RepositoryPlanPreparationRecord: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let request: RepositoryPlanPreparationRequest
    public let revision: Int64
    public let state: RepositoryPlanPreparationState
    public let threadID: String?
    public let turnID: String?
    public let draftBytes: Data?
    public let error: String?
    public let isCurrent: Bool
    public let replacedByAttemptID: UUID?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        requestID: UUID,
        request: RepositoryPlanPreparationRequest,
        revision: Int64,
        state: RepositoryPlanPreparationState,
        threadID: String?,
        turnID: String?,
        draftBytes: Data?,
        error: String?,
        isCurrent: Bool,
        replacedByAttemptID: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.requestID = requestID
        self.request = request
        self.revision = revision
        self.state = state
        self.threadID = threadID
        self.turnID = turnID
        self.draftBytes = draftBytes
        self.error = error
        self.isCurrent = isCurrent
        self.replacedByAttemptID = replacedByAttemptID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum RepositoryPlanReconstructionError: Error, LocalizedError, Equatable, Sendable {
    case invalidPayload(String)
    case blocked([RepositoryPlanReconstructionBlocker])
    case staleSource
    case applicationAttemptConflict
    case applicationOutcomeUnknown
    case preparationConflict
    case preparationRevisionConflict(expected: Int64, current: Int64)
    case invalidPreparationTransition

    public var errorDescription: String? {
        switch self {
        case let .invalidPayload(message): message
        case .blocked: "Resolve or explicitly exclude every repository-plan blocker before approval or Apply."
        case .staleSource: "The repository-plan source or destination changed. Prepare and approve a new version."
        case .applicationAttemptConflict: "A different repository-plan Apply attempt is already recorded for this proposal version."
        case .applicationOutcomeUnknown: "The repository-plan Apply outcome is unknown. Reconcile the exact recorded attempt before retrying."
        case .preparationConflict: "A repository-plan preparation attempt is already current. Reconcile or finish it before replacing it."
        case let .preparationRevisionConflict(expected, current):
            "The repository-plan preparation changed (expected revision \(expected), current \(current)). Refresh before continuing."
        case .invalidPreparationTransition: "That repository-plan preparation state transition is not permitted."
        }
    }
}
