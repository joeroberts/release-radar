import CryptoKit
import Foundation

/// Immutable owner-confirmed input for one bounded profile-cleanup request.
/// The native presentation layer maps its preview evidence into this Core type.
public struct ProjectExecutionProfileCleanupConfirmation: Codable, Equatable, Sendable {
    public struct Target: Codable, Equatable, Sendable {
        public let profileID: String
        public let assignmentID: String
        public let expectedDefinition: Data
        public let assignmentBaseline: ProjectExecutionAssignment

        public init(profileID: String, assignmentID: String, expectedDefinition: Data,
                    assignmentBaseline: ProjectExecutionAssignment) {
            self.profileID = profileID
            self.assignmentID = assignmentID
            self.expectedDefinition = expectedDefinition
            self.assignmentBaseline = assignmentBaseline
        }
    }

    public let requestID: UUID
    public let registration: ProjectRegistration
    public let selectedCodexContextID: UUID
    public let configurationVersion: String
    public let targets: [Target]

    public init(requestID: UUID, registration: ProjectRegistration,
                selectedCodexContextID: UUID, configurationVersion: String,
                targets: [Target]) {
        self.requestID = requestID
        self.registration = registration
        self.selectedCodexContextID = selectedCodexContextID
        self.configurationVersion = configurationVersion
        self.targets = targets
    }

    func validates() throws {
        guard !configurationVersion.isEmpty, !targets.isEmpty, targets.count <= 256,
              Set(targets.map(\.profileID)).count == targets.count,
              Set(targets.map(\.assignmentID)).count == targets.count else {
            throw ProjectExecutionError.conflict
        }
        for target in targets {
            try ProjectExecutionPaths.component(target.profileID)
            guard target.assignmentID == target.assignmentBaseline.id,
                  target.profileID == target.assignmentBaseline.permissionProfile,
                  registration == target.assignmentBaseline.registration,
                  target.expectedDefinition == target.assignmentBaseline.permissionProfileDefinition,
                  target.assignmentBaseline.codexContextID == selectedCodexContextID else {
                throw ProjectExecutionError.conflict
            }
        }
    }
}

/// The exact configuration precondition for one named-key deletion.
public struct ProjectExecutionConfirmedProfileRemoval: Equatable, Sendable {
    public let profileID: String
    public let selectedCodexContextID: UUID
    public let configurationVersion: String
    public let expectedDefinition: Data

    public init(profileID: String, selectedCodexContextID: UUID,
                configurationVersion: String, expectedDefinition: Data) {
        self.profileID = profileID
        self.selectedCodexContextID = selectedCodexContextID
        self.configurationVersion = configurationVersion
        self.expectedDefinition = expectedDefinition
    }
}

/// A successful named-key deletion readback. Transport uncertainty never creates this result.
public struct ProjectExecutionConfirmedProfileRemovalResult: Equatable, Sendable {
    public let configurationVersion: String

    public init(configurationVersion: String) {
        self.configurationVersion = configurationVersion
    }
}

/// Per-assignment receipt for a confirmed cleanup request. It is intentionally
/// separate from retirement: profile cleanup never retires the assignment.
public struct ProjectExecutionProfileCleanupReceipt: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case intentRecorded, removalVerified, outcomeUnknown }
    public enum TargetPresence: String, Codable, Sendable { case present, absent, unavailable }
    public enum Acknowledgement: String, Codable, Sendable { case notAttempted, acknowledged, unknown }
    public enum HelperClosureState: String, Codable, Sendable { case pending, verified, unknown }

    public let version: Int
    public let requestID: UUID
    public let profileID: String
    public let selectedCodexContextID: UUID
    /// Immutable outer preview version confirmed by the owner.
    public let configurationVersion: String
    /// Stable position of this target in the complete confirmed request.
    public let targetIndex: Int
    public let targetCount: Int
    /// Exact configuration version supplied to the named-key writer, if attempted.
    public var attemptedConfigurationVersion: String?
    /// Complete immutable target snapshot. Persisting it in every receipt makes
    /// recovery possible even if a process stops while recording later intents.
    public var confirmedTargets: [ProjectExecutionProfileCleanupConfirmation.Target]?
    public let expectedDefinitionDigest: String
    public var state: State
    public var acknowledgement: Acknowledgement
    public var observedTargetPresence: TargetPresence
    public var observedConfigurationVersion: String?
    /// Nil is legacy/absent evidence and must be treated as unknown, never as
    /// proof that the original request-owned configuration helper closed.
    public var helperClosureState: HelperClosureState?
    public var configurationSessionID: UUID?
    public var finalizationPending: Bool

    public init(requestID: UUID, profileID: String, selectedCodexContextID: UUID,
                configurationVersion: String, expectedDefinition: Data,
                targetIndex: Int = 0, targetCount: Int = 1,
                attemptedConfigurationVersion: String? = nil,
                confirmedTargets: [ProjectExecutionProfileCleanupConfirmation.Target]? = nil,
                state: State = .intentRecorded,
                acknowledgement: Acknowledgement = .notAttempted,
                observedTargetPresence: TargetPresence = .present,
                observedConfigurationVersion: String? = nil,
                helperClosureState: HelperClosureState? = nil,
                configurationSessionID: UUID? = nil,
                finalizationPending: Bool = false) {
        version = 1
        self.requestID = requestID
        self.profileID = profileID
        self.selectedCodexContextID = selectedCodexContextID
        self.configurationVersion = configurationVersion
        self.targetIndex = targetIndex
        self.targetCount = targetCount
        self.attemptedConfigurationVersion = attemptedConfigurationVersion
        self.confirmedTargets = confirmedTargets
        expectedDefinitionDigest = Self.digest(expectedDefinition)
        self.state = state
        self.acknowledgement = acknowledgement
        self.observedTargetPresence = observedTargetPresence
        self.observedConfigurationVersion = observedConfigurationVersion
        self.helperClosureState = helperClosureState
        self.configurationSessionID = configurationSessionID
        self.finalizationPending = finalizationPending
    }

    public func validates(for assignment: ProjectExecutionAssignment) -> Bool {
        guard version == 1, profileID == assignment.permissionProfile,
              selectedCodexContextID == assignment.codexContextID,
              let definition = assignment.permissionProfileDefinition,
              expectedDefinitionDigest == Self.digest(definition),
              !configurationVersion.isEmpty,
              targetCount > 0, targetCount <= 256,
              targetIndex >= 0, targetIndex < targetCount,
              attemptedConfigurationVersion?.isEmpty != true,
              (helperClosureState == nil) == (configurationSessionID == nil),
              (confirmedTargets?.count == targetCount || confirmedTargets == nil) else { return false }
        if let confirmedTargets {
            guard Set(confirmedTargets.map(\.profileID)).count == confirmedTargets.count,
                  Set(confirmedTargets.map(\.assignmentID)).count == confirmedTargets.count,
                  confirmedTargets.allSatisfy({ target in
                      target.assignmentBaseline.profileCleanupReceipt == nil
                        && target.profileID == target.assignmentBaseline.permissionProfile
                        && target.assignmentID == target.assignmentBaseline.id
                        && target.selectedContextMatches(selectedCodexContextID)
                        && target.expectedDefinition == target.assignmentBaseline.permissionProfileDefinition
                  }) else { return false }
        }
        switch state {
        case .removalVerified:
            return observedTargetPresence == .absent && observedConfigurationVersion?.isEmpty == false
        case .intentRecorded, .outcomeUnknown:
            return true
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension ProjectExecutionProfileCleanupConfirmation.Target {
    func selectedContextMatches(_ contextID: UUID) -> Bool {
        assignmentBaseline.codexContextID == contextID
    }
}

public struct ProjectExecutionProfileCleanupOutcome: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case removed, observedAbsentUnattributed, replayed, skipped, conflict, unresolved }
    public enum FinalizationStatus: Equatable, Sendable { case notApplicable, pending, complete }

    public let profileID: String
    public let assignmentID: String
    public let kind: Kind
    public let detail: String
    public let finalizationStatus: FinalizationStatus

    public init(profileID: String, assignmentID: String, kind: Kind, detail: String,
                finalizationStatus: FinalizationStatus = .notApplicable) {
        self.profileID = profileID
        self.assignmentID = assignmentID
        self.kind = kind
        self.detail = detail
        self.finalizationStatus = finalizationStatus
    }
}

public struct ProjectExecutionProfileCleanupRun: Equatable, Sendable {
    public let outcomes: [ProjectExecutionProfileCleanupOutcome]
    public let configurationFinalized: Bool

    public init(outcomes: [ProjectExecutionProfileCleanupOutcome], configurationFinalized: Bool) {
        self.outcomes = outcomes
        self.configurationFinalized = configurationFinalized
    }
}

/// Serializes only the protected-record and configuration checks required for
/// a confirmed cleanup. It neither retires assignments nor creates authority.
public actor ProjectExecutionProfileCleanupCoordinator {
    private let root: @Sendable () throws -> URL
    private let configuration: any ProjectExecutionConfiguring
    private let configurationSessionID: UUID
    private var storage: ProjectExecutionFileStore?
    private var configurationConnectionClosureConfirmed = false

    public init(root: @escaping @Sendable () throws -> URL = ProjectExecutionFileStore.applicationRoot,
                configuration: any ProjectExecutionConfiguring,
                configurationSessionID: UUID = UUID()) {
        self.root = root
        self.configuration = configuration
        self.configurationSessionID = configurationSessionID
    }

    private func store() throws -> ProjectExecutionFileStore {
        if let storage { return storage }
        let value = try ProjectExecutionFileStore(root: root(), create: false)
        storage = value
        return value
    }

    /// Rebuilds only complete immutable confirmations represented by protected
    /// receipt groups. Recovery behavior is implemented with the cleanup flow.
    public func recoverableConfirmations(project: AuthorizedProject) throws -> [ProjectExecutionProfileCleanupConfirmation] {
        guard let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
        let assignments = try store().assignments(projectID: registration.projectID.rawValue)
        guard assignments.allSatisfy({ $0.registration == registration }) else {
            throw ProjectExecutionError.identityMismatch
        }
        let groups = Dictionary(grouping: assignments.compactMap { assignment in
            assignment.profileCleanupReceipt.map { (assignment, $0) }
        }, by: { $0.1.requestID })
        return try groups.keys.sorted { $0.uuidString < $1.uuidString }.compactMap { requestID in
            guard let group = groups[requestID], let seed = group.first,
                  let targets = seed.1.confirmedTargets else {
                throw ProjectExecutionError.conflict
            }
            if group.count == targets.count,
               Set(group.map { $0.1.targetIndex }) == Set(targets.indices),
               group.allSatisfy({ $0.1.state == .removalVerified
                   && $0.1.helperClosureState == .verified && !$0.1.finalizationPending }) {
                return nil
            }
            let normalizedTargets = targets.map(normalizedTarget)
            guard !normalizedTargets.isEmpty else { throw ProjectExecutionError.conflict }
            let confirmation = ProjectExecutionProfileCleanupConfirmation(
                requestID: requestID, registration: registration,
                selectedCodexContextID: seed.1.selectedCodexContextID,
                configurationVersion: seed.1.configurationVersion,
                targets: normalizedTargets)
            try confirmation.validates()
            for (assignment, receipt) in group {
                guard receipt.requestID == requestID,
                      receipt.targetCount == normalizedTargets.count,
                      normalizedTargets.indices.contains(receipt.targetIndex),
                      receipt.confirmedTargets?.map(normalizedTarget) == normalizedTargets,
                      normalizedTargets[receipt.targetIndex].assignmentID == assignment.id else {
                    throw ProjectExecutionError.conflict
                }
                try validateReceipt(receipt, target: normalizedTargets[receipt.targetIndex],
                                    targetIndex: receipt.targetIndex, confirmation: confirmation)
            }
            for target in normalizedTargets {
                let current = try store().assignment(projectID: registration.projectID.rawValue,
                                                     taskID: target.assignmentID)
                guard baseline(current) == target.assignmentBaseline else {
                    throw ProjectExecutionError.conflict
                }
            }
            let receiptIndices = Set(group.map { $0.1.targetIndex })
            guard receiptIndices.count == group.count else { throw ProjectExecutionError.conflict }
            // A complete snapshot in every persisted receipt is the authority
            // for targets whose individual intent file was not yet written.
            return confirmation
        }
    }

    public func cleanup(project: AuthorizedProject, confirmation: ProjectExecutionProfileCleanupConfirmation,
                        beforeWrite: @escaping @Sendable () async throws -> Void) async throws -> [ProjectExecutionProfileCleanupOutcome] {
        let run = try await cleanupRun(project: project, confirmation: confirmation, beforeWrite: beforeWrite)
        return run.outcomes
    }

    public func cleanupRun(project: AuthorizedProject, confirmation: ProjectExecutionProfileCleanupConfirmation,
                           beforeWrite: @escaping @Sendable () async throws -> Void) async throws -> ProjectExecutionProfileCleanupRun {
        if try requiresRetainedConnectionRecovery(project: project, confirmation: confirmation) {
            do {
                if !configurationConnectionClosureConfirmed {
                    guard try await configuration.recoverRetainedConfigurationConnection() else {
                        return .init(outcomes: try pendingRecoveryOutcomes(project: project, confirmation: confirmation),
                                     configurationFinalized: false)
                    }
                    configurationConnectionClosureConfirmed = true
                }
                try markHelperClosure(.verified, project: project, confirmation: confirmation,
                                      matchingSessionOnly: true)
            } catch {
                return .init(outcomes: try pendingRecoveryOutcomes(project: project, confirmation: confirmation),
                             configurationFinalized: false)
            }
        }
        let reopenedVerifiedClosure = try prepareConfigurationHelperUse(
            project: project, confirmation: confirmation)
        do {
            let results = try await cleanupOperation(project: project, confirmation: confirmation, beforeWrite: beforeWrite)
            // A verified profile effect stays replay-safe even if this request's
            // helper cleanup cannot be confirmed. Its receipt retains pending
            // finalization; a retry must not remove the profile again.
            do {
                try await configuration.finishConfiguration()
                configurationConnectionClosureConfirmed = true
                try markHelperClosure(.verified, project: project, confirmation: confirmation,
                                      matchingSessionOnly: true)
                let complete = try helperClosureIsVerified(project: project, confirmation: confirmation)
                return .init(outcomes: results, configurationFinalized: complete)
            } catch {
                if reopenedVerifiedClosure {
                    try? markHelperClosure(.unknown, project: project, confirmation: confirmation,
                                           matchingSessionOnly: true)
                }
                return .init(outcomes: results, configurationFinalized: false)
            }
        } catch {
            let failure = error
            do {
                try await configuration.finishConfiguration()
                configurationConnectionClosureConfirmed = true
                try markHelperClosure(.verified, project: project, confirmation: confirmation,
                                      matchingSessionOnly: true)
            } catch {
                if reopenedVerifiedClosure {
                    try? markHelperClosure(.unknown, project: project, confirmation: confirmation,
                                           matchingSessionOnly: true)
                }
            }
            throw failure
        }
    }

    private func prepareConfigurationHelperUse(
        project: AuthorizedProject,
        confirmation: ProjectExecutionProfileCleanupConfirmation
    ) throws -> Bool {
        guard let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
        var reopenedVerifiedClosure = false
        for target in confirmation.targets {
            let expected = try store().assignment(projectID: registration.projectID.rawValue,
                                                  taskID: target.assignmentID)
            guard var receipt = expected.profileCleanupReceipt,
                  receipt.requestID == confirmation.requestID else { continue }
            if receipt.configurationSessionID != configurationSessionID {
                guard receipt.helperClosureState == .verified else { continue }
                receipt.configurationSessionID = configurationSessionID
            }
            reopenedVerifiedClosure = reopenedVerifiedClosure || receipt.helperClosureState == .verified
            receipt.helperClosureState = .pending
            var updated = expected
            updated.profileCleanupReceipt = receipt
            if updated != expected { try store().saveAssignment(updated, expected: expected) }
        }
        configurationConnectionClosureConfirmed = false
        return reopenedVerifiedClosure
    }

    private func requiresRetainedConnectionRecovery(
        project: AuthorizedProject,
        confirmation: ProjectExecutionProfileCleanupConfirmation
    ) throws -> Bool {
        guard let registration = project.registration,
              registration == confirmation.registration else {
            throw ProjectExecutionError.identityMismatch
        }
        for target in confirmation.targets {
            let assignment = try store().assignment(projectID: registration.projectID.rawValue,
                                                     taskID: target.assignmentID)
            guard let receipt = assignment.profileCleanupReceipt,
                  receipt.requestID == confirmation.requestID else { continue }
            if receipt.helperClosureState != .verified,
               receipt.configurationSessionID == configurationSessionID {
                return true
            }
        }
        return false
    }

    private func helperClosureIsVerified(
        project: AuthorizedProject,
        confirmation: ProjectExecutionProfileCleanupConfirmation
    ) throws -> Bool {
        guard let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
        for target in confirmation.targets {
            let assignment = try store().assignment(projectID: registration.projectID.rawValue,
                                                     taskID: target.assignmentID)
            guard let receipt = assignment.profileCleanupReceipt,
                  receipt.requestID == confirmation.requestID else { continue }
            if receipt.state == .removalVerified, receipt.helperClosureState != .verified {
                return false
            }
        }
        return true
    }

    private func markHelperClosure(
        _ state: ProjectExecutionProfileCleanupReceipt.HelperClosureState,
        project: AuthorizedProject,
        confirmation: ProjectExecutionProfileCleanupConfirmation,
        matchingSessionOnly: Bool
    ) throws {
        guard let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
        for target in confirmation.targets {
            let expected = try store().assignment(projectID: registration.projectID.rawValue,
                                                  taskID: target.assignmentID)
            guard var receipt = expected.profileCleanupReceipt,
                  receipt.requestID == confirmation.requestID,
                  !matchingSessionOnly || receipt.configurationSessionID == configurationSessionID else { continue }
            var updated = expected
            receipt.helperClosureState = state
            updated.profileCleanupReceipt = receipt
            if updated != expected { try store().saveAssignment(updated, expected: expected) }
        }
    }

    private func pendingRecoveryOutcomes(
        project: AuthorizedProject,
        confirmation: ProjectExecutionProfileCleanupConfirmation
    ) throws -> [ProjectExecutionProfileCleanupOutcome] {
        guard let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
        return try confirmation.targets.map { target in
            let assignment = try store().assignment(projectID: registration.projectID.rawValue,
                                                     taskID: target.assignmentID)
            if assignment.profileCleanupReceipt?.state == .removalVerified {
                return .init(profileID: target.profileID, assignmentID: target.assignmentID,
                             kind: .replayed,
                             detail: "The removal remains verified; the original configuration helper still needs recovery.",
                             finalizationStatus: .pending)
            }
            return .init(profileID: target.profileID, assignmentID: target.assignmentID,
                         kind: .unresolved,
                         detail: "The confirmed cleanup remains recoverable; the original configuration helper still needs recovery.",
                         finalizationStatus: .pending)
        }
    }

    /// Clears only post-effect bookkeeping after the owner audit and
    /// configuration connection have both completed. It never writes config.
    public func completeFinalization(project: AuthorizedProject,
                                     confirmation: ProjectExecutionProfileCleanupConfirmation,
                                     beforeWrite: @escaping @Sendable () async throws -> Void) async throws {
        try confirmation.validates()
        guard project.registration == confirmation.registration else {
            throw ProjectExecutionError.identityMismatch
        }
        var pending: [(ProjectExecutionAssignment, ProjectExecutionProfileCleanupReceipt)] = []
        for (index, target) in confirmation.targets.map(normalizedTarget).enumerated() {
            let assignment = try validateRecord(target: target, project: project,
                                                contextID: confirmation.selectedCodexContextID)
            guard let receipt = assignment.profileCleanupReceipt else { continue }
            try validateReceipt(receipt, target: target, targetIndex: index, confirmation: confirmation)
            if receipt.state == .removalVerified, receipt.finalizationPending {
                guard receipt.helperClosureState == .verified else {
                    throw ProjectExecutionError.conflict
                }
                pending.append((assignment, receipt))
            }
        }
        guard !pending.isEmpty else { return }
        try await beforeWrite()
        for (assignment, receipt) in pending {
            var updated = assignment
            var finalized = receipt
            finalized.finalizationPending = false
            updated.profileCleanupReceipt = finalized
            try store().saveAssignment(updated, expected: assignment)
        }
    }

    private func cleanupOperation(project: AuthorizedProject, confirmation: ProjectExecutionProfileCleanupConfirmation,
                                  beforeWrite: @escaping @Sendable () async throws -> Void) async throws -> [ProjectExecutionProfileCleanupOutcome] {
        try confirmation.validates()
        guard project.registration == confirmation.registration,
              try await configuration.selectedCodexContextID() == confirmation.selectedCodexContextID else {
            throw ProjectExecutionError.identityMismatch
        }
        let observation = try await configuration.observeWorkerProfiles(primaryRoot: project.canonicalRoot.path)
        guard observation.selectedCodexContextID == confirmation.selectedCodexContextID else {
            return confirmation.targets.map {
                .init(profileID: $0.profileID, assignmentID: $0.assignmentID, kind: .conflict,
                      detail: "Configuration evidence changed after confirmation; refresh and confirm again.")
            }
        }
        let observedDefinitions = Dictionary(uniqueKeysWithValues: observation.entries.map { ($0.profileID, $0.observedDefinition) })
        let normalizedTargets = confirmation.targets.map(normalizedTarget)
        let normalizedConfirmation = ProjectExecutionProfileCleanupConfirmation(
            requestID: confirmation.requestID, registration: confirmation.registration,
            selectedCodexContextID: confirmation.selectedCodexContextID,
            configurationVersion: confirmation.configurationVersion,
            targets: normalizedTargets)
        var assignments = try normalizedTargets.enumerated().map { index, target in
            let assignment = try validateRecord(target: target, project: project,
                                                contextID: confirmation.selectedCodexContextID)
            if let receipt = assignment.profileCleanupReceipt {
                try validateReceipt(receipt, target: target, targetIndex: index,
                                    confirmation: normalizedConfirmation)
            }
            return assignment
        }

        let hasPersistedRequest = assignments.contains { $0.profileCleanupReceipt != nil }
        let presentTargets = normalizedTargets.indices.filter {
            observedDefinitions[normalizedTargets[$0].profileID] != nil
        }
        if hasPersistedRequest {
            assignments = try persistReceiptBindings(assignments: assignments,
                confirmation: normalizedConfirmation)
        } else if !presentTargets.isEmpty,
                  observation.configurationVersion == confirmation.configurationVersion,
                  presentTargets.allSatisfy({ index in
                      (try? validateEligibility(assignment: assignments[index], target: normalizedTargets[index],
                                                contextID: confirmation.selectedCodexContextID,
                                                observedDefinition: observedDefinitions[normalizedTargets[index].profileID])) != nil
                  }) {
            assignments = try persistReceiptBindings(assignments: assignments,
                confirmation: normalizedConfirmation)
        }

        var expectedVersion = confirmation.configurationVersion
        var outcomes: [ProjectExecutionProfileCleanupOutcome] = []
        var mayContinue = true
        var performedWrite = false
        for (targetIndex, target) in normalizedTargets.enumerated() {
            guard mayContinue else {
                outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                      kind: .unresolved,
                                      detail: "A prior target has an unresolved outcome; this target was not attempted."))
                continue
            }
            do {
            var assignment = try validateRecord(target: target, project: project,
                                                contextID: confirmation.selectedCodexContextID)
            var receipt = assignment.profileCleanupReceipt
            if let receipt {
                try validateReceipt(receipt, target: target, targetIndex: targetIndex,
                                    confirmation: normalizedConfirmation)
                if receipt.state == .removalVerified {
                    if observedDefinitions[target.profileID] != nil {
                        outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                              kind: .conflict, detail: "A profile previously recorded as removed is present again; no prior confirmation was reused."))
                        mayContinue = false
                        continue
                    }
                    let attemptedVersion = receipt.attemptedConfigurationVersion ?? receipt.configurationVersion
                    guard attemptedVersion == expectedVersion,
                          let observedVersion = receipt.observedConfigurationVersion,
                          !observedVersion.isEmpty else {
                        throw ProjectExecutionError.conflict
                    }
                    outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                          kind: .replayed,
                                          detail: receipt.helperClosureState == .verified && !receipt.finalizationPending
                                            ? "The recorded removal and cleanup finalization remain complete; no configuration write was attempted."
                                            : "The recorded removal remains verified; cleanup finalization is pending and no configuration write was attempted.",
                                          finalizationStatus: receipt.helperClosureState == .verified && !receipt.finalizationPending
                                            ? .complete : .pending))
                    expectedVersion = observedVersion
                    continue
                }
            }
            if observedDefinitions[target.profileID] == nil {
                guard let receipt else {
                    outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                          kind: .skipped,
                                          detail: "The profile is absent without a matching cleanup receipt; no removal was attributed."))
                    continue
                }
                var reconciled = assignment
                var updatedReceipt = receipt
                updatedReceipt.observedTargetPresence = .absent
                updatedReceipt.observedConfigurationVersion = observation.configurationVersion
                reconciled.profileCleanupReceipt = updatedReceipt
                try store().saveAssignment(reconciled, expected: assignment)
                outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                      kind: .observedAbsentUnattributed,
                                      detail: "The pending cleanup receipt observed absence without proving write attribution; no removal was retried."))
                mayContinue = false
                continue
            }
            try validateEligibility(assignment: assignment, target: target,
                                    contextID: confirmation.selectedCodexContextID,
                                    observedDefinition: observedDefinitions[target.profileID],
                                    receiptConfirmation: normalizedConfirmation,
                                    targetIndex: targetIndex)
            guard performedWrite || observation.configurationVersion == expectedVersion else {
                outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                      kind: .conflict,
                                      detail: "Configuration evidence changed after confirmation; refresh and confirm again."))
                mayContinue = false
                continue
            }
            guard var pendingReceipt = receipt else { throw ProjectExecutionError.conflict }
            if let attemptedVersion = pendingReceipt.attemptedConfigurationVersion,
               attemptedVersion != expectedVersion { throw ProjectExecutionError.conflict }
            pendingReceipt.attemptedConfigurationVersion = expectedVersion
            pendingReceipt.observedTargetPresence = .present
            var pendingAssignment = assignment
            pendingAssignment.profileCleanupReceipt = pendingReceipt
            if pendingAssignment != assignment {
                try store().saveAssignment(pendingAssignment, expected: assignment)
                assignment = pendingAssignment
                receipt = pendingReceipt
            }

            let request = ProjectExecutionConfirmedProfileRemoval(profileID: target.profileID,
                selectedCodexContextID: confirmation.selectedCodexContextID,
                configurationVersion: expectedVersion, expectedDefinition: target.expectedDefinition)
            let result: ProjectExecutionConfirmedProfileRemovalResult
            do {
                result = try await configuration.removeConfirmedWorkerProfile(primaryRoot: project.canonicalRoot.path,
                    request: request, beforeWrite: { [weak self] in
                        guard let self else { throw ProjectExecutionError.unavailable }
                        let current = try await self.validateRecord(target: target, project: project,
                                                                   contextID: confirmation.selectedCodexContextID)
                        try await self.validateEligibility(assignment: current, target: target,
                                                           contextID: confirmation.selectedCodexContextID,
                                                           observedDefinition: observedDefinitions[target.profileID],
                                                           receiptConfirmation: normalizedConfirmation,
                                                           targetIndex: targetIndex)
                        try await beforeWrite()
                    })
            } catch {
                var pending = try store().assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
                let expectedPending = pending
                guard var receipt = pending.profileCleanupReceipt, receipt.requestID == confirmation.requestID else { throw error }
                receipt.state = .outcomeUnknown
                receipt.acknowledgement = .unknown
                receipt.observedTargetPresence = .unavailable
                pending.profileCleanupReceipt = receipt
                try store().saveAssignment(pending, expected: expectedPending)
                throw error
            }
            var removed = try store().assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
            let expectedRemoved = removed
            guard var receipt = removed.profileCleanupReceipt, receipt.requestID == confirmation.requestID else {
                throw ProjectExecutionError.conflict
            }
            receipt.state = .removalVerified
            receipt.acknowledgement = .acknowledged
            receipt.observedTargetPresence = .absent
            receipt.observedConfigurationVersion = result.configurationVersion
            receipt.finalizationPending = true
            removed.profileCleanupReceipt = receipt
            try store().saveAssignment(removed, expected: expectedRemoved)
            outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                  kind: .removed,
                                  detail: "The confirmed profile section was removed; cleanup finalization remains pending.",
                                  finalizationStatus: .pending))
            expectedVersion = result.configurationVersion
            performedWrite = true
            } catch {
                outcomes.append(.init(profileID: target.profileID, assignmentID: target.assignmentID,
                                      kind: .unresolved,
                                      detail: "The target remains recoverable; its configuration effect was not treated as complete."))
                mayContinue = false
            }
        }
        return outcomes
    }

    private func validateRecord(target: ProjectExecutionProfileCleanupConfirmation.Target,
                                project: AuthorizedProject, contextID: UUID) throws -> ProjectExecutionAssignment {
        guard let registration = project.registration else { throw ProjectExecutionError.identityMismatch }
        let current = try store().assignment(projectID: registration.projectID.rawValue, taskID: target.assignmentID)
        guard baseline(current) == baseline(target.assignmentBaseline),
              current.registration == registration else {
            throw ProjectExecutionError.conflict
        }
        let claims = try store().profileOwnershipClaims(candidateProfileIDs: [target.profileID], selectedCodexContextID: contextID)
        guard claims.count == 1, claims[0].assignmentID == current.id,
              claims[0].projectID == current.registration.projectID.rawValue,
              claims[0].registrationID == current.registration.registrationID,
              claims[0].registrationGeneration == current.registration.requestGeneration,
              claims[0].codexContextID == contextID else { throw ProjectExecutionError.conflict }
        return current
    }

    private func validateEligibility(assignment current: ProjectExecutionAssignment,
                                     target: ProjectExecutionProfileCleanupConfirmation.Target,
                                     contextID: UUID, observedDefinition: Data?,
                                     receiptConfirmation: ProjectExecutionProfileCleanupConfirmation? = nil,
                                     targetIndex: Int? = nil) throws {
        var classificationAssignment = current
        if let receipt = current.profileCleanupReceipt {
            guard let receiptConfirmation, let targetIndex else {
                throw ProjectExecutionError.assignmentNotAuthorized
            }
            try validateReceipt(receipt, target: target, targetIndex: targetIndex,
                                confirmation: receiptConfirmation)
            classificationAssignment.profileCleanupReceipt = nil
        }
        let configurationObservation: ProjectExecutionProfileObservation = observedDefinition.map {
            ProjectExecutionProfileObservation.present($0)
        } ?? .missing
        let association = ProjectExecutionProfileAssociation.classify(assignment: current,
            selectedCodexContextID: contextID, observation: configurationObservation,
            candidateProfileID: target.profileID)
        let classification = ProjectExecutionProfileCleanupClassification.classify(.init(assignment: classificationAssignment,
            association: association, configurationObservation: configurationObservation,
            configurationBaseline: observedDefinition.map { .init(candidateProfileID: target.profileID,
                selectedCodexContextID: contextID, observedDefinition: $0) }, liveState: .unavailable))
        guard classification.category == .cleanupEligible else { throw ProjectExecutionError.assignmentNotAuthorized }
    }

    private func persistReceiptBindings(assignments: [ProjectExecutionAssignment],
                                        confirmation: ProjectExecutionProfileCleanupConfirmation) throws -> [ProjectExecutionAssignment] {
        let targets = confirmation.targets.map(normalizedTarget)
        var result = assignments
        for index in targets.indices {
            let target = targets[index]
            let expected = result[index]
            var updated = expected
            if var receipt = expected.profileCleanupReceipt {
                try validateReceipt(receipt, target: target, targetIndex: index, confirmation: confirmation)
                receipt.confirmedTargets = targets
                updated.profileCleanupReceipt = receipt
            } else {
                updated.profileCleanupReceipt = .init(requestID: confirmation.requestID,
                    profileID: target.profileID,
                    selectedCodexContextID: confirmation.selectedCodexContextID,
                    configurationVersion: confirmation.configurationVersion,
                    expectedDefinition: target.expectedDefinition,
                    targetIndex: index, targetCount: targets.count,
                    confirmedTargets: targets,
                    helperClosureState: .pending,
                    configurationSessionID: configurationSessionID)
            }
            if updated != expected {
                try store().saveAssignment(updated, expected: expected)
                result[index] = updated
            }
        }
        return result
    }

    private func validateReceipt(_ receipt: ProjectExecutionProfileCleanupReceipt,
                                 target: ProjectExecutionProfileCleanupConfirmation.Target,
                                 targetIndex: Int,
                                 confirmation: ProjectExecutionProfileCleanupConfirmation) throws {
        guard receipt.requestID == confirmation.requestID,
              receipt.profileID == target.profileID,
              receipt.selectedCodexContextID == confirmation.selectedCodexContextID,
              receipt.configurationVersion == confirmation.configurationVersion,
              receipt.expectedDefinitionDigest == digest(target.expectedDefinition),
              receipt.targetIndex == targetIndex,
              receipt.targetCount == confirmation.targets.count,
              (receipt.confirmedTargets?.map(normalizedTarget) == confirmation.targets.map(normalizedTarget)
                || receipt.confirmedTargets == nil) else {
            throw ProjectExecutionError.conflict
        }
    }

    private func baseline(_ assignment: ProjectExecutionAssignment) -> ProjectExecutionAssignment {
        var value = assignment
        value.profileCleanupReceipt = nil
        return value
    }

    private func normalizedTarget(_ target: ProjectExecutionProfileCleanupConfirmation.Target) -> ProjectExecutionProfileCleanupConfirmation.Target {
        .init(profileID: target.profileID, assignmentID: target.assignmentID,
              expectedDefinition: target.expectedDefinition,
              assignmentBaseline: baseline(target.assignmentBaseline))
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
