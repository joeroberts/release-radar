import Foundation

/// A fresh selected-context observation supplied by the configuration owner.
/// This type deliberately performs no configuration or store access itself.
public enum ProjectExecutionProfileObservation: Equatable, Sendable {
    case unavailable
    case missing
    case present(Data)
}

/// Conservative, non-persistent classification of one profile candidate.
public enum ProjectExecutionProfileAssociation {
    public enum Category: Equatable, Sendable {
        case owned
        case outsideAssignmentCleanup
        case unknown
    }

    public enum Reason: Equatable, Sendable {
        case reservedProfile
        case missingAssignmentDefinition
        case missingProvisioningReceipt
        case configurationUnavailable
        case profileMissing
        case definitionMismatch
        case selectedContextMismatch
        case duplicateOwnership
        case missingWorktreeIdentity
        case legacyWorkerIdentityUnavailable
    }

    public enum OwnershipProvenance: Equatable, Sendable {
        case verifiedProvisioningReceipt
        case pendingProvisioningReceipt
        case legacyProtectedAssignment
    }

    public enum InstallationEvidence: Equatable, Sendable {
        case verified
        case pending
        case unrecorded
    }

    public struct Result: Equatable, Sendable {
        public let category: Category
        public let assignmentID: String?
        public let reason: Reason?
        public let ownershipProvenance: OwnershipProvenance?
        public let installationEvidence: InstallationEvidence?
        public let requiresInstallationRecovery: Bool

        public init(category: Category, assignmentID: String? = nil, reason: Reason? = nil,
                    ownershipProvenance: OwnershipProvenance? = nil,
                    installationEvidence: InstallationEvidence? = nil,
                    requiresInstallationRecovery: Bool = false) {
            self.category = category
            self.assignmentID = assignmentID
            self.reason = reason
            self.ownershipProvenance = ownershipProvenance
            self.installationEvidence = installationEvidence
            self.requiresInstallationRecovery = requiresInstallationRecovery
        }
    }

    public static func classify(
        assignment: ProjectExecutionAssignment?,
        selectedCodexContextID: UUID?,
        observation: ProjectExecutionProfileObservation,
        candidateProfileID: String,
        duplicateAssignmentIDs: Set<String> = []
    ) -> Result {
        if ["rr-project-ro", "rr-project-restricted", "rr-command-read-probe"].contains(candidateProfileID) {
            return .init(category: .outsideAssignmentCleanup, reason: .reservedProfile)
        }
        guard let assignment else {
            return .init(category: .unknown, reason: .missingAssignmentDefinition)
        }
        guard assignment.permissionProfile == candidateProfileID else {
            return .init(category: .outsideAssignmentCleanup)
        }
        guard let worktree = assignment.worktree, worktree.checkout == assignment.checkoutPath else {
            return .init(category: .unknown, assignmentID: assignment.id, reason: .missingWorktreeIdentity)
        }
        guard let assignmentContextID = assignment.codexContextID,
              assignmentContextID == selectedCodexContextID else {
            return .init(category: .unknown, assignmentID: assignment.id, reason: .selectedContextMismatch)
        }
        guard !duplicateAssignmentIDs.contains(assignment.id) else {
            return .init(category: .unknown, assignmentID: assignment.id, reason: .duplicateOwnership)
        }
        guard let expected = assignment.permissionProfileDefinition else {
            return .init(category: .unknown, assignmentID: assignment.id, reason: .missingAssignmentDefinition)
        }
        if assignment.workerAttemptID == nil,
           assignment.launchReserved == true || assignment.sessionID != nil {
            return .init(category: .unknown, assignmentID: assignment.id, reason: .legacyWorkerIdentityUnavailable)
        }
        switch observation {
        case .unavailable:
            return .init(category: .unknown, assignmentID: assignment.id, reason: .configurationUnavailable)
        case .missing:
            return .init(category: .unknown, assignmentID: assignment.id, reason: .profileMissing)
        case let .present(actual):
            guard sameDefinition(actual, expected) else {
                return .init(category: .unknown, assignmentID: assignment.id, reason: .definitionMismatch)
            }
            switch assignment.profileProvisioningReceipt?.state {
            case .some(.verified):
                return .init(category: .owned, assignmentID: assignment.id,
                    ownershipProvenance: .verifiedProvisioningReceipt, installationEvidence: .verified)
            case .some(.pending):
                return .init(category: .owned, assignmentID: assignment.id,
                    ownershipProvenance: .pendingProvisioningReceipt, installationEvidence: .pending,
                    requiresInstallationRecovery: true)
            case .none:
                return .init(category: .owned, assignmentID: assignment.id,
                    ownershipProvenance: .legacyProtectedAssignment, installationEvidence: .unrecorded,
                    requiresInstallationRecovery: true)
            }
        }
    }

    private static func sameDefinition(_ lhs: Data, _ rhs: Data) -> Bool {
        guard let left = try? JSONSerialization.jsonObject(with: lhs) as? [String: Any],
              let right = try? JSONSerialization.jsonObject(with: rhs) as? [String: Any] else {
            return false
        }
        return NSDictionary(dictionary: left).isEqual(to: right)
    }
}
