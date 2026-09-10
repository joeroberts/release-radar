import Foundation

public enum DeliveryGoalObligationCoverageState: String, Codable, Equatable, Sendable {
    case required
    case uncovered
    case carried
    case dropped
    case delivered
    case unassessed
}

public struct DeliveryGoalObligationCoverage: Codable, Equatable, Sendable, Identifiable {
    public var id: DeliveryGoalObligationKey { key }
    public let key: DeliveryGoalObligationKey
    public let scope: String
    public let state: DeliveryGoalObligationCoverageState
    public let reason: String?
    public let descendants: [DeliveryGoalObligationKey]

    public init(
        key: DeliveryGoalObligationKey,
        scope: String,
        state: DeliveryGoalObligationCoverageState,
        reason: String?,
        descendants: [DeliveryGoalObligationKey]
    ) {
        self.key = key
        self.scope = scope
        self.state = state
        self.reason = reason
        self.descendants = descendants
    }
}

public struct DeliveryGoalCoverageAssessment: Codable, Equatable, Sendable {
    public let phaseID: PhaseID
    public let goalID: DeliveryGoalID
    public let obligations: [DeliveryGoalObligationCoverage]
    public let requiredLeafCount: Int
    public let deliveredLeafCount: Int
    public let isResolved: Bool
    public let hasDeliveredOutcome: Bool

    public var isAcceptanceEligible: Bool { isResolved && hasDeliveredOutcome }
    public var isReadyCovered: Bool {
        !obligations.isEmpty && !obligations.contains {
            $0.state == .uncovered || $0.state == .unassessed
        }
    }

    public init(
        phaseID: PhaseID,
        goalID: DeliveryGoalID,
        obligations: [DeliveryGoalObligationCoverage],
        requiredLeafCount: Int,
        deliveredLeafCount: Int,
        isResolved: Bool,
        hasDeliveredOutcome: Bool
    ) {
        self.phaseID = phaseID
        self.goalID = goalID
        self.obligations = obligations
        self.requiredLeafCount = requiredLeafCount
        self.deliveredLeafCount = deliveredLeafCount
        self.isResolved = isResolved
        self.hasDeliveredOutcome = hasDeliveredOutcome
    }
}
