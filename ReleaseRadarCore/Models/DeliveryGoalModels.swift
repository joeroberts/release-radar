import Foundation

public struct DeliveryGoalID: DeliveryRecordID {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum PhasePlanState: String, Codable, CaseIterable, Sendable {
    case legacyUnassessed = "legacy_unassessed"
    case draft
    case ready
}

public enum DeliveryGoalLifecycle: String, Codable, CaseIterable, Sendable {
    case draft
    case planned
    case active
    case awaitingAcceptance = "awaiting_acceptance"
    case accepted
    case superseded
}

public struct DeliveryGoalDraft: Codable, Equatable, Sendable {
    public let id: DeliveryGoalID
    public let title: String
    public let outcome: String
    public let doneCriteria: [String]
    public let sortOrder: Int

    public init(
        id: DeliveryGoalID,
        title: String,
        outcome: String,
        doneCriteria: [String],
        sortOrder: Int
    ) {
        self.id = id
        self.title = title
        self.outcome = outcome
        self.doneCriteria = doneCriteria
        self.sortOrder = sortOrder
    }
}

public struct DeliveryGoalAssignment: Codable, Equatable, Sendable {
    public let goalID: DeliveryGoalID
    public let ticketID: TicketID

    public init(goalID: DeliveryGoalID, ticketID: TicketID) {
        self.goalID = goalID
        self.ticketID = ticketID
    }
}

public struct PhasePlanRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let state: PhasePlanState
    public let revision: Int64
    public let readyRevision: Int64?
    public let createdAt: Date
    public let updatedAt: Date
    public let finalizedAt: Date?

    public init(
        projectID: ProjectID,
        phaseID: PhaseID,
        state: PhasePlanState,
        revision: Int64,
        readyRevision: Int64?,
        createdAt: Date,
        updatedAt: Date,
        finalizedAt: Date?
    ) {
        self.projectID = projectID
        self.phaseID = phaseID
        self.state = state
        self.revision = revision
        self.readyRevision = readyRevision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finalizedAt = finalizedAt
    }
}

public struct DeliveryGoalRecord: Codable, Equatable, Sendable {
    public let id: DeliveryGoalID
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let title: String
    public let outcome: String
    public let lifecycle: DeliveryGoalLifecycle
    public let sortOrder: Int
    public let createdAt: Date
    public let updatedAt: Date
    public let activatedAt: Date?
    public let acceptedAt: Date?

    public init(
        id: DeliveryGoalID,
        projectID: ProjectID,
        phaseID: PhaseID,
        title: String,
        outcome: String,
        lifecycle: DeliveryGoalLifecycle,
        sortOrder: Int,
        createdAt: Date,
        updatedAt: Date,
        activatedAt: Date?,
        acceptedAt: Date?
    ) {
        self.id = id
        self.projectID = projectID
        self.phaseID = phaseID
        self.title = title
        self.outcome = outcome
        self.lifecycle = lifecycle
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.activatedAt = activatedAt
        self.acceptedAt = acceptedAt
    }
}

public struct DeliveryGoalCriterionRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let goalID: DeliveryGoalID
    public let sortOrder: Int
    public let text: String

    public init(
        projectID: ProjectID,
        phaseID: PhaseID,
        goalID: DeliveryGoalID,
        sortOrder: Int,
        text: String
    ) {
        self.projectID = projectID
        self.phaseID = phaseID
        self.goalID = goalID
        self.sortOrder = sortOrder
        self.text = text
    }
}

public struct DeliveryGoalAssignmentRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let goalID: DeliveryGoalID
    public let ticketID: TicketID

    public init(
        projectID: ProjectID,
        phaseID: PhaseID,
        goalID: DeliveryGoalID,
        ticketID: TicketID
    ) {
        self.projectID = projectID
        self.phaseID = phaseID
        self.goalID = goalID
        self.ticketID = ticketID
    }
}

public struct DeliveryGoalAssignmentEventRecord: Codable, Equatable, Sendable {
    public let auditEventID: AuditEventID
    public let projectID: ProjectID
    public let phaseID: PhaseID
    public let ticketID: TicketID
    public let previousGoalID: DeliveryGoalID?
    public let currentGoalID: DeliveryGoalID?
    public let revision: Int64
    public let action: String

    public init(
        auditEventID: AuditEventID,
        projectID: ProjectID,
        phaseID: PhaseID,
        ticketID: TicketID,
        previousGoalID: DeliveryGoalID?,
        currentGoalID: DeliveryGoalID?,
        revision: Int64,
        action: String
    ) {
        self.auditEventID = auditEventID
        self.projectID = projectID
        self.phaseID = phaseID
        self.ticketID = ticketID
        self.previousGoalID = previousGoalID
        self.currentGoalID = currentGoalID
        self.revision = revision
        self.action = action
    }
}

public struct PhasePlanReadinessFailure: Codable, Equatable, Sendable {
    public let unassignedTicketIDs: [TicketID]
    public let incompleteGoalIDs: [DeliveryGoalID]
    public let conflictingTicketIDs: [TicketID]

    public init(
        unassignedTicketIDs: [TicketID],
        incompleteGoalIDs: [DeliveryGoalID],
        conflictingTicketIDs: [TicketID]
    ) {
        self.unassignedTicketIDs = unassignedTicketIDs.sorted { $0.rawValue < $1.rawValue }
        self.incompleteGoalIDs = incompleteGoalIDs.sorted { $0.rawValue < $1.rawValue }
        self.conflictingTicketIDs = conflictingTicketIDs.sorted { $0.rawValue < $1.rawValue }
    }
}
