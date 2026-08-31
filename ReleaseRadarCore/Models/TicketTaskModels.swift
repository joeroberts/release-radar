import Foundation

public struct TicketTaskID: DeliveryRecordID {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum TicketTaskCompletion: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
}

public enum TicketTaskLifecycle: String, Codable, CaseIterable, Sendable {
    case active
    case superseded
}

public struct TicketTaskDraft: Codable, Equatable, Sendable {
    public let id: TicketTaskID
    public let label: String
    public let title: String
    public let sortOrder: Int

    public init(
        id: TicketTaskID,
        label: String,
        title: String,
        sortOrder: Int
    ) {
        self.id = id
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
    }
}

public struct TicketTaskDefinitionRevision: Codable, Equatable, Sendable {
    public let id: TicketTaskID
    public let title: String?
    public let sortOrder: Int?

    public init(
        id: TicketTaskID,
        title: String?,
        sortOrder: Int?
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
    }
}

public struct TicketTaskPlanRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let ticketID: TicketID
    public let revision: Int64
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        projectID: ProjectID,
        ticketID: TicketID,
        revision: Int64,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.projectID = projectID
        self.ticketID = ticketID
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TicketTaskRecord: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let ticketID: TicketID
    public let id: TicketTaskID
    public let label: String
    public let title: String
    public let sortOrder: Int
    public let completion: TicketTaskCompletion
    public let lifecycle: TicketTaskLifecycle
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?
    public let supersededAt: Date?

    public init(
        projectID: ProjectID,
        ticketID: TicketID,
        id: TicketTaskID,
        label: String,
        title: String,
        sortOrder: Int,
        completion: TicketTaskCompletion,
        lifecycle: TicketTaskLifecycle,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?,
        supersededAt: Date?
    ) {
        self.projectID = projectID
        self.ticketID = ticketID
        self.id = id
        self.label = label
        self.title = title
        self.sortOrder = sortOrder
        self.completion = completion
        self.lifecycle = lifecycle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.supersededAt = supersededAt
    }
}
