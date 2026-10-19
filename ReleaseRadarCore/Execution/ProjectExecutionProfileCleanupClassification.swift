import Foundation

/// Pure cleanup-preview policy. Callers must supply a validated assignment and
/// a fresh association observation for the selected Codex context; this type
/// never reads protected state, configuration, or runtime services itself.
public enum ProjectExecutionProfileCleanupClassification {
    public enum Category: Equatable, Sendable {
        case active
        case recoveryRetained
        case cleanupEligible
        case unknown
        case alreadyRemoved
        case outsideAssignmentCleanup
    }

    public enum Reason: Equatable, Sendable {
        case association(ProjectExecutionProfileAssociation.Reason)
        case activeAssignment
        case pendingApproval
        case identityMismatch
        case incompleteProvisioning
        case uncertainOutcome
        case finalizationFailed
        case lostWorkerRecovery
        case incompleteRetirement
        case profileReappearedAfterRemoval
        case missingTerminalClosure
    }

    /// An authenticated, observation-time runtime result. A nil value means no
    /// live adapter was available; it neither proves nor vetoes durable closure.
    public enum LiveState: Equatable, Sendable {
        case active
        case pendingApproval
        case unavailable
    }

    public struct Input: Equatable, Sendable {
        public let assignment: ProjectExecutionAssignment
        public let association: ProjectExecutionProfileAssociation.Result
        public let configurationObservation: ProjectExecutionProfileObservation
        public let configurationBaseline: ConfigurationBaseline?
        public let liveState: LiveState?

        public init(assignment: ProjectExecutionAssignment,
                    association: ProjectExecutionProfileAssociation.Result,
                    configurationObservation: ProjectExecutionProfileObservation,
                    configurationBaseline: ConfigurationBaseline?,
                    liveState: LiveState? = nil) {
            self.assignment = assignment
            self.association = association
            self.configurationObservation = configurationObservation
            self.configurationBaseline = configurationBaseline
            self.liveState = liveState
        }
    }

    /// Exact selected-context configuration evidence compared by the caller.
    /// Its provenance and freshness remain caller preconditions; this value is
    /// retained unchanged for #196's mutation-boundary revalidation.
    public struct ConfigurationBaseline: Equatable, Sendable {
        public let candidateProfileID: String
        public let selectedCodexContextID: UUID
        public let observedDefinition: Data

        public init(candidateProfileID: String, selectedCodexContextID: UUID,
                    observedDefinition: Data) {
            self.candidateProfileID = candidateProfileID
            self.selectedCodexContextID = selectedCodexContextID
            self.observedDefinition = observedDefinition
        }
    }

    public struct Result: Equatable, Sendable {
        public let category: Category
        public let assignmentID: String
        public let reason: Reason?
        public let configurationBaseline: ConfigurationBaseline?
        public let assignmentBaseline: ProjectExecutionAssignment?

        public init(category: Category, assignmentID: String, reason: Reason? = nil,
                    configurationBaseline: ConfigurationBaseline? = nil,
                    assignmentBaseline: ProjectExecutionAssignment? = nil) {
            self.category = category
            self.assignmentID = assignmentID
            self.reason = reason
            self.configurationBaseline = configurationBaseline
            self.assignmentBaseline = assignmentBaseline
        }
    }

    public static func classify(_ input: Input) -> Result {
        let assignment = input.assignment
        let association = input.association

        if association.category == .outsideAssignmentCleanup {
            return .init(category: .outsideAssignmentCleanup, assignmentID: assignment.id,
                reason: association.reason.map(Reason.association))
        }
        guard association.assignmentID == nil || association.assignmentID == assignment.id else {
            return .init(category: .unknown, assignmentID: assignment.id, reason: .identityMismatch)
        }
        let hasPresentConfiguration: Bool
        switch input.configurationObservation {
        case let .present(observedDefinition):
            guard let baseline = input.configurationBaseline,
                  baseline.candidateProfileID == assignment.permissionProfile,
                  assignment.codexContextID == Optional(baseline.selectedCodexContextID),
                  matchesDefinition(baseline.observedDefinition, observedDefinition),
                  matchesDefinition(observedDefinition, assignment.permissionProfileDefinition) else {
                return .init(category: .unknown, assignmentID: assignment.id, reason: .identityMismatch)
            }
            hasPresentConfiguration = true
        case .missing, .unavailable:
            guard input.configurationBaseline == nil else {
                return .init(category: .unknown, assignmentID: assignment.id, reason: .identityMismatch)
            }
            hasPresentConfiguration = false
        }
        if assignment.retirement?.profileRemoved == true {
            if association.category == .unknown, association.reason == .profileMissing,
               input.configurationObservation == .missing {
                return .init(category: .alreadyRemoved, assignmentID: assignment.id)
            }
            return .init(category: .unknown, assignmentID: assignment.id,
                reason: .profileReappearedAfterRemoval)
        }

        switch association.category {
        case .unknown:
            return .init(category: .unknown, assignmentID: assignment.id,
                reason: association.reason.map(Reason.association))
        case .owned:
            guard hasPresentConfiguration else {
                return .init(category: .unknown, assignmentID: assignment.id, reason: .identityMismatch)
            }
        case .outsideAssignmentCleanup:
            break
        }

        if assignment.retirement != nil {
            return .init(category: .recoveryRetained, assignmentID: assignment.id,
                reason: .incompleteRetirement)
        }
        if assignment.profileProvisioningReceipt?.state == .pending
            || association.installationEvidence == .pending {
            return .init(category: .recoveryRetained, assignmentID: assignment.id,
                reason: .incompleteProvisioning)
        }
        if assignment.uncertainOutcome == true {
            return .init(category: .recoveryRetained, assignmentID: assignment.id,
                reason: .uncertainOutcome)
        }
        if assignment.finalizationFailed == true {
            return .init(category: .recoveryRetained, assignmentID: assignment.id,
                reason: .finalizationFailed)
        }
        if assignment.lostWorkerRecovery != nil {
            return .init(category: .recoveryRetained, assignmentID: assignment.id,
                reason: .lostWorkerRecovery)
        }
        switch input.liveState {
        case .active:
            return .init(category: .active, assignmentID: assignment.id, reason: .activeAssignment)
        case .pendingApproval:
            return .init(category: .recoveryRetained, assignmentID: assignment.id, reason: .pendingApproval)
        case .unavailable, nil:
            break
        }
        guard assignment.state == .closed,
              assignment.connectionClosed == true,
              assignment.workerAttemptID != nil,
              assignment.launchReserved == true,
              assignment.sessionID?.isEmpty == false else {
            if [.authorized, .preparing].contains(assignment.state) {
                return .init(category: .active, assignmentID: assignment.id, reason: .activeAssignment)
            }
            if [.stopped, .revoked].contains(assignment.state) {
                return .init(category: .recoveryRetained, assignmentID: assignment.id,
                    reason: .missingTerminalClosure)
            }
            return .init(category: .unknown, assignmentID: assignment.id, reason: .missingTerminalClosure)
        }
        return .init(category: .cleanupEligible, assignmentID: assignment.id,
            configurationBaseline: input.configurationBaseline, assignmentBaseline: assignment)
    }

    private static func matchesDefinition(_ observed: Data, _ expected: Data?) -> Bool {
        guard let expected,
              let observedObject = try? JSONSerialization.jsonObject(with: observed) as? [String: Any],
              let expectedObject = try? JSONSerialization.jsonObject(with: expected) as? [String: Any] else {
            return false
        }
        return NSDictionary(dictionary: observedObject).isEqual(to: expectedObject)
    }
}
