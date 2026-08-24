import Foundation

public protocol DeliveryRecordID: RawRepresentable, Codable, Hashable, Sendable where RawValue == String {}

public struct ProjectRootID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct PhaseID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct TicketID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct PhaseDependencyID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct TicketDependencyID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct BlockerID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct EvidenceID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ThreadLinkID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ThreadExclusionID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ObservedThreadID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ObservedGoalID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ReviewItemID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct AuditEventID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct NotificationEventID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }

extension ProjectID: DeliveryRecordID {}

public enum TicketLane: String, Codable, CaseIterable, Sendable {
    case backlog
    case inProgress = "in_progress"
    case needsReview = "needs_review"
    case blocked
    case accepted
}

public struct DeliveryActor: Codable, Equatable, Sendable {
    public let id: String
    public let threadID: String?

    public init(id: String, threadID: String? = nil) {
        self.id = id
        self.threadID = threadID
    }
}

public struct ProjectRecord: Codable, Equatable, Sendable { public let id: ProjectID; public let name: String }
public struct ProjectRootRecord: Codable, Equatable, Sendable { public let id: ProjectRootID; public let projectID: ProjectID; public let path: String }
public struct PhaseRecord: Codable, Equatable, Sendable { public let id: PhaseID; public let projectID: ProjectID; public let name: String }
public struct TicketRecord: Codable, Equatable, Sendable { public let id: TicketID; public let projectID: ProjectID; public let phaseID: PhaseID; public let outcome: String; public let lane: TicketLane }
public struct PhaseDependencyRecord: Codable, Equatable, Sendable { public let id: PhaseDependencyID; public let projectID: ProjectID; public let phaseID: PhaseID; public let dependsOnPhaseID: PhaseID }
public struct TicketDependencyRecord: Codable, Equatable, Sendable { public let id: TicketDependencyID; public let projectID: ProjectID; public let ticketID: TicketID; public let dependsOnTicketID: TicketID }
public struct BlockerRecord: Codable, Equatable, Sendable { public let id: BlockerID; public let projectID: ProjectID; public let ticketID: TicketID; public let summary: String }
public struct EvidenceRecord: Codable, Equatable, Sendable { public let id: EvidenceID; public let projectID: ProjectID; public let ticketID: TicketID?; public let path: String; public let isAvailable: Bool }
public struct ThreadLinkRecord: Codable, Equatable, Sendable { public let id: ThreadLinkID; public let projectID: ProjectID; public let ticketID: TicketID; public let threadID: ObservedThreadID }
public struct ThreadExclusionRecord: Codable, Equatable, Sendable { public let id: ThreadExclusionID; public let projectID: ProjectID; public let threadID: String; public let reason: String }
public struct ObservedThreadRecord: Codable, Equatable, Sendable { public let id: ObservedThreadID; public let projectID: ProjectID; public let status: String; public let lastObservedAt: Date }
public struct ObservedGoalRecord: Codable, Equatable, Sendable { public let id: ObservedGoalID; public let projectID: ProjectID; public let threadID: ObservedThreadID; public let status: String; public let text: String; public let lastObservedAt: Date }
public struct ReviewItemRecord: Codable, Equatable, Sendable { public let id: ReviewItemID; public let projectID: ProjectID; public let ticketID: TicketID?; public let kind: String; public let summary: String }
public struct AuditEventRecord: Codable, Equatable, Sendable { public let id: AuditEventID; public let actorID: String; public let threadID: String?; public let reason: String; public let createdAt: Date }
public struct NotificationEventRecord: Codable, Equatable, Sendable { public let id: NotificationEventID; public let fingerprint: String; public let state: String; public let ticketID: TicketID?; public let goalID: ObservedGoalID? }
