import CryptoKit
import Foundation

/// One app-owned producer. Work and context come from the registered command
/// route; public callers cannot choose a filesystem ceiling or authorize a prompt.
public actor ProjectExecutionAssignmentCoordinator: ProjectExecutionAssignmentPreparing {
    private let root: @Sendable () throws -> URL
    private let configuration: any ProjectExecutionConfiguring
    private let provisioning: any ExecutionWorktreeProvisioning
    private let handlerPath: String
    private var preparing: [String: UUID] = [:]

    public init(root: @escaping @Sendable () throws -> URL = ProjectExecutionFileStore.applicationRoot,
                configuration: any ProjectExecutionConfiguring, handlerPath: String,
                provisioning: any ExecutionWorktreeProvisioning = LibGit2WorktreeProvisioner()) {
        self.root = root; self.configuration = configuration; self.handlerPath = handlerPath; self.provisioning = provisioning
    }

    public func readCurrent(project: AuthorizedProject, assignmentID: String) throws -> ProjectExecutionAssignment {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        let value = try store.assignment(projectID: project.projectID.rawValue, taskID: assignmentID)
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: assignmentID)
        guard policy.registration == project.registration, policy.enabled, policy.bindingRecoveryPending != true, policy.consent == ProjectExecutionPolicy.Consent(),
              value.registration == project.registration, value.checkoutPath == paths.checkout.path else { throw ProjectExecutionError.assignmentNotAuthorized }
        return value
    }

    private nonisolated static func policyDigest(_ policy: ProjectExecutionPolicy) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(policy)).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func isClosedTaskMismatch(
        parent: ProjectExecutionAssignment,
        requestedWork: ProjectExecutionWork,
        registration: ProjectRegistration,
        parentCheckoutPath: String,
        primaryRoot: String,
        reviewOfAssignmentID: String?
    ) -> Bool {
        guard let parentWork = parent.work else { return false }
        return parent.registration == registration
            && parentWork.projectID == requestedWork.projectID
            && parentWork.ticketID == requestedWork.ticketID
            && parentWork.taskID != requestedWork.taskID
            && parent.state == .closed
            && parent.retirement == nil
            && parent.sessionID != nil
            && parent.checkoutPath == parentCheckoutPath
            && parent.worktree?.primaryRoot == primaryRoot
            && (reviewOfAssignmentID == nil || parent.role == .delivery)
    }

    private nonisolated static func isEligibleClosedParent(
        parent: ProjectExecutionAssignment,
        requestedWork: ProjectExecutionWork,
        registration: ProjectRegistration,
        parentCheckoutPath: String,
        primaryRoot: String,
        reviewOfAssignmentID: String?
    ) -> Bool {
        parent.registration == registration
            && parent.work == requestedWork
            && parent.state == .closed
            && parent.retirement == nil
            && parent.sessionID != nil
            && parent.checkoutPath == parentCheckoutPath
            && parent.worktree?.primaryRoot == primaryRoot
            && (reviewOfAssignmentID == nil || parent.role == .delivery)
    }

    /// Called synchronously by the app while its final current-work transaction
    /// is held. Configuration preparation alone never makes an assignment usable.
    public nonisolated func admitPrepared(_ value: ProjectExecutionAssignment) throws -> ProjectExecutionAssignment {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: value.registration.projectID.rawValue)
        guard value.state == .preparing, value.sessionID == nil, value.launchReserved != true, value.uncertainOutcome != true,
              value.codexContextID == policy.codexContextID,
              value.preparedPolicyDigest == (try Self.policyDigest(policy)), policy.enabled, policy.bindingRecoveryPending != true,
              policy.registration == value.registration, policy.handlerPath == handlerPath,
              policy.hookReceipt?.installed == true,
              try store.assignment(projectID: value.registration.projectID.rawValue, taskID: value.id) == value else { throw ProjectExecutionError.assignmentNotAuthorized }
        guard let contextID = value.codexContextID,
              try store.codexContext()?.id == contextID else { throw CodexExecutionContextError.changed }
        try value.verifyContext()
        var admitted = value; admitted.state = .authorized; admitted.finalizationFailed = nil
        try store.saveAssignment(admitted, expected: value)
        return admitted
    }

    public nonisolated func revokePreparation(_ value: ProjectExecutionAssignment) throws {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let current = try store.assignment(projectID: value.registration.projectID.rawValue, taskID: value.id)
        guard current.id == value.id, current.registration == value.registration, current.work == value.work,
              current.checkoutPath == value.checkoutPath, current.role == value.role,
              current.permissionProfile == value.permissionProfile, current.model == value.model,
              current.effort == value.effort, current.authorization == value.authorization,
              current.excludedPaths == value.excludedPaths,
              current.codexContextID == value.codexContextID,
              current.context == value.context, current.worktree == value.worktree,
              current.reviewOfAssignmentID == value.reviewOfAssignmentID, current.baselineFromAssignmentID == value.baselineFromAssignmentID else { throw ProjectExecutionError.identityMismatch }
        guard [.preparing, .authorized, .unknown].contains(current.state) else { return }
        var revoked = current; revoked.state = .revoked
        revoked.finalizationFailed = current.state != .unknown && current.sessionID == nil && current.launchReserved != true
        if current.state == .unknown { revoked.launchReserved = true; revoked.uncertainOutcome = true }
        try store.saveAssignment(revoked, expected: current)
    }

    public func prepare(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                        reviewOfAssignmentID: String?, baselineFromAssignmentID: String?, contextPaths: [String]) async throws -> ProjectExecutionAssignment {
        let key = work.projectID.rawValue + "/" + work.ticketID + "/" + work.taskID
        guard preparing[key] == nil else {
            throw ProjectExecutionPreparationConflict(diagnostic: .init(
                kind: .preparationInProgress,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
        preparing[key] = requestID
        do {
            let result = try await prepareOperation(project: project, work: work, requestID: requestID,
                reviewOfAssignmentID: reviewOfAssignmentID, baselineFromAssignmentID: baselineFromAssignmentID, contextPaths: contextPaths)
            try await configuration.finishConfiguration()
            return result
        } catch {
            let failure = error
            do { try await configuration.finishConfiguration() }
            catch {
                if preparing[key] == requestID { preparing.removeValue(forKey: key) }
                throw error
            }
            if !(failure is ProjectExecutionPreparationFailure), preparing[key] == requestID {
                preparing.removeValue(forKey: key)
            }
            throw failure
        }
    }

    public func finishPreparation(work: ProjectExecutionWork, requestID: UUID) async {
        let key = work.projectID.rawValue + "/" + work.ticketID + "/" + work.taskID
        if preparing[key] == requestID { preparing.removeValue(forKey: key) }
    }

    public func verifyNoPreparationEffects(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                                           reviewOfAssignmentID: String?, baselineFromAssignmentID: String?) async throws -> Bool {
        let key = work.projectID.rawValue + "/" + work.ticketID + "/" + work.taskID
        guard preparing[key] == requestID, let registration = project.registration,
              work.projectID == project.projectID,
              reviewOfAssignmentID == nil || baselineFromAssignmentID == nil else { return false }
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.registration == registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.enabled, policy.bindingRecoveryPending != true else { return false }
        let role: ProjectExecutionAssignment.Role = reviewOfAssignmentID == nil ? .delivery : .review
        let id = role.rawValue + "-" + requestID.uuidString.lowercased()
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: id)
        guard try store.assignmentIfPresent(projectID: project.projectID.rawValue, taskID: id) == nil,
              try !provisioning.hasPreparedResources(primaryRoot: project.canonicalRoot, checkout: paths.checkout,
                projectID: project.projectID.rawValue, taskID: id) else { return false }
        if let parentID = reviewOfAssignmentID ?? baselineFromAssignmentID {
            let parent = try store.assignment(projectID: project.projectID.rawValue, taskID: parentID)
            let parentPaths = try ProjectExecutionPaths(storageRoot: store.root,
                projectID: project.projectID.rawValue, taskID: parentID)
            let retiredParent = parent.registration == registration && parent.work == work && parent.state == .superseded
                && parent.retirement?.completed == true && parent.retirement?.connectionCloseUncertain != true
                && parent.checkoutPath == parentPaths.checkout.path && parent.worktree?.primaryRoot == policy.primaryRoot
                && (reviewOfAssignmentID == nil || parent.role == .delivery)
            guard retiredParent
                    || Self.isEligibleClosedParent(parent: parent, requestedWork: work,
                        registration: registration, parentCheckoutPath: parentPaths.checkout.path,
                        primaryRoot: policy.primaryRoot, reviewOfAssignmentID: reviewOfAssignmentID)
                    || Self.isClosedTaskMismatch(parent: parent, requestedWork: work,
                        registration: registration, parentCheckoutPath: parentPaths.checkout.path,
                        primaryRoot: policy.primaryRoot, reviewOfAssignmentID: reviewOfAssignmentID)
            else { return false }
        }
        do {
            try await configuration.useCodexContext(policy.codexContextID)
            let profileExists = try await configuration.workerProfileExists(primaryRoot: policy.primaryRoot,
                profileID: "rr-" + id)
            try await configuration.finishConfiguration()
            return !profileExists
        } catch {
            let failure = error
            try await configuration.finishConfiguration()
            throw failure
        }
    }

    private func prepareOperation(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                                  reviewOfAssignmentID: String?, baselineFromAssignmentID: String?, contextPaths: [String]) async throws -> ProjectExecutionAssignment {
        guard let registration = project.registration, work.projectID == project.projectID,
              reviewOfAssignmentID == nil || baselineFromAssignmentID == nil,
              !contextPaths.isEmpty, contextPaths.count <= 64, Set(contextPaths).count == contextPaths.count else { throw ProjectExecutionError.invalidAssignment }
        let store = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try ProjectExecutionFileStore(root: root(), create: false)
        }
        let policy = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try store.policy(projectID: project.projectID.rawValue)
        }
        guard policy.version == 1, policy.registration == registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.handlerPath == handlerPath, policy.appServerExecutable == CodexExecutionIdentity.executable,
              policy.enabled, policy.bindingRecoveryPending != true, policy.consent == ProjectExecutionPolicy.Consent(), policy.hookReceipt?.installed == true,
              policy.hookReceipt?.command == "\"" + handlerPath + "\" --hook" else { throw ProjectExecutionError.assignmentNotAuthorized }
        if let parentID = reviewOfAssignmentID ?? baselineFromAssignmentID {
            let parent = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
                try store.assignment(projectID: project.projectID.rawValue, taskID: parentID)
            }
            let parentPaths = try ProjectExecutionPaths(storageRoot: store.root,
                projectID: project.projectID.rawValue, taskID: parentID)
            if Self.isClosedTaskMismatch(parent: parent, requestedWork: work, registration: registration,
                parentCheckoutPath: parentPaths.checkout.path, primaryRoot: policy.primaryRoot,
                reviewOfAssignmentID: reviewOfAssignmentID) {
                throw ProjectExecutionPreparationFailure.noEffectsCandidate(.assignmentNotAuthorized)
            }
        }
        try await configuration.useCodexContext(policy.codexContextID)
        try await configuration.validateInstallation(handlerPath: handlerPath)
        let role: ProjectExecutionAssignment.Role = reviewOfAssignmentID == nil ? .delivery : .review
        let id = role.rawValue + "-" + requestID.uuidString.lowercased()
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: id)
        let inventory = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try store.assignments(projectID: project.projectID.rawValue)
        }
        let historical = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try (policy.previousProjectIDs ?? []).flatMap { try store.assignments(projectID: $0) }
        } + inventory.filter { $0.registration != registration }
        guard !historical.contains(where: {
            $0.retirement?.completed != true && $0.retirement?.replacementAllowed != true &&
            ($0.uncertainOutcome == true || $0.state == .unknown || ($0.sessionID != nil || $0.launchReserved == true) && $0.connectionClosed != true && $0.state != .closed)
        }) else { throw StoreError.unavailable("Close and explicitly retire the previous registration's worker resources in project settings before preparing replacement work. Its unresolved outcome is preserved.") }
        if let parentID = reviewOfAssignmentID ?? baselineFromAssignmentID {
            let parent = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
                try store.assignment(projectID: project.projectID.rawValue, taskID: parentID)
            }
            let parentPaths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: parentID)
            if parent.registration == registration, parent.work == work, parent.state == .superseded,
               parent.retirement?.completed == true, parent.retirement?.connectionCloseUncertain != true,
               parent.checkoutPath == parentPaths.checkout.path, parent.worktree?.primaryRoot == policy.primaryRoot,
               reviewOfAssignmentID == nil || parent.role == .delivery {
                throw ProjectExecutionPreparationFailure.noEffectsCandidate(.assignmentNotAuthorized)
            }
        }
        if let existing = inventory.first(where: { $0.id == id }) {
            guard existing.codexContextID == policy.codexContextID, existing.work == work, existing.registration == registration, existing.role == role,
                  existing.reviewOfAssignmentID == reviewOfAssignmentID, existing.baselineFromAssignmentID == baselineFromAssignmentID,
                  existing.uncertainOutcome != true, existing.retirement == nil,
                  existing.state == .preparing || (existing.state == .revoked && existing.finalizationFailed == true && existing.sessionID == nil && existing.launchReserved != true) else { throw ProjectExecutionError.assignmentNotAuthorized }
            try existing.verifyContext()
            guard let tree = existing.worktree,
                  try withProjectExecutionPreparationStage(.targetProvisioning, {
                      try provisioning.candidateRevision(worktree: tree)
                  }) == tree.baseline else { throw ProjectExecutionError.identityMismatch }
            var pending = existing
            if pending.state == .revoked {
                pending.state = .preparing; pending.finalizationFailed = nil; pending.preparedPolicyDigest = nil
                try withProjectExecutionPreparationStage(.assignmentStoreCompareAndSwap) {
                    try store.saveAssignment(pending, expected: existing)
                }
            }
            return try await configure(pending, paths: paths, policy: policy, store: store)
        }
        // Another request identity cannot silently replace an uncertain/live worker.
        if let blocking = inventory.first(where: {
            $0.registration == registration && $0.work?.ticketID == work.ticketID && $0.work?.taskID == work.taskID && $0.role == role
                && !($0.state == .superseded && $0.retirement?.completed == true || $0.retirement?.replacementAllowed == true)
                && ($0.state == .authorized || $0.state == .preparing || $0.state == .unknown || $0.state == .stopped || $0.uncertainOutcome == true || $0.finalizationFailed == true || $0.retirement != nil || ($0.launchReserved == true && $0.connectionClosed != true && $0.state != .closed))
        }) {
            let safelyScoped = blocking.work == work
            throw ProjectExecutionPreparationConflict(diagnostic: .init(
                kind: safelyScoped ? .blockingAssignment : .causeUnavailable,
                blockingRequestID: nil,
                blockingAssignmentID: safelyScoped ? blocking.id : nil,
                evidence: .observedAtFailure
            ))
        }
        let source: URL
        let baseline: String
        let usesEligibleClosedParent: Bool
        if let parentID = reviewOfAssignmentID ?? baselineFromAssignmentID {
            let parent = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
                try store.assignment(projectID: project.projectID.rawValue, taskID: parentID)
            }
            let parentPaths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: parentID)
            guard Self.isEligibleClosedParent(parent: parent, requestedWork: work,
                      registration: registration, parentCheckoutPath: parentPaths.checkout.path,
                      primaryRoot: policy.primaryRoot, reviewOfAssignmentID: reviewOfAssignmentID),
                  let tree = parent.worktree else { throw ProjectExecutionError.assignmentNotAuthorized }
            baseline = try withProjectExecutionPreparationStage(.parentCandidateValidation) {
                try provisioning.candidateRevision(worktree: tree)
            }
            if parent.role == .review, baseline != tree.baseline { throw ProjectExecutionError.identityMismatch }
            source = parentPaths.checkout
            usesEligibleClosedParent = true
        } else {
            // First assignment records the verified selected repository's committed
            // baseline; unrelated dirty primary files are never copied into it.
            baseline = try withProjectExecutionPreparationStage(.targetProvisioning) {
                try provisioning.revision(at: project.canonicalRoot, requireClean: false)
            }
            source = project.canonicalRoot
            usesEligibleClosedParent = false
        }
        let reader = try RepositoryDocumentReader(rootURL: source, limits: .init(maximumFileBytes: 16 * 1_048_576), afterRead: nil)
        let contexts: [ProjectExecutionAssignment.Context]
        do {
            contexts = try contextPaths.map { path -> ProjectExecutionAssignment.Context in
                let bytes = try reader.read(path)
                return .init(path: path,
                    digest: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
            }
        } catch let error as RepositoryDocumentError where usesEligibleClosedParent && error.code == .missingFile {
            throw ProjectExecutionPreparationFailure.noEffectsCandidate(.assignmentNotAuthorized)
        }
        let assignment = try store.createAssignment(codexContextID: policy.codexContextID) {
            let tree = try withProjectExecutionPreparationStage(.targetProvisioning) {
                try provisioning.prepare(primaryRoot: project.canonicalRoot, checkout: paths.checkout,
                    projectID: project.projectID.rawValue, taskID: id, baseline: baseline)
            }
            let authorization = "Project onboarding authorizes the recorded bounded work \(work.ticketID)/\(work.taskID): \(work.outcome). Task: \(work.title)."
            var assignment = ProjectExecutionAssignment(id: id, registration: registration, checkoutPath: paths.checkout.path, role: role,
                permissionProfile: "rr-" + id, model: "gpt-5.6-terra", effort: role == .review ? "high" : "medium",
                authorization: authorization, context: contexts,
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive", tree.commonGitDirectory, policy.primaryRoot],
                worktree: tree, work: work, reviewOfAssignmentID: reviewOfAssignmentID, baselineFromAssignmentID: baselineFromAssignmentID,
                reviewScratchVersion: role == .review ? ProjectExecutionAssignment.xcodeBuildScratchVersion : nil)
            assignment.codexContextID = policy.codexContextID
            try assignment.verifyContext() // Pins must match committed checkout, not dirty primary edits.
            try reader.verifyStable()
            assignment.state = .preparing
            return assignment
        }
        return try await configure(assignment, paths: paths, policy: policy, store: store)
    }

    private func configure(_ intent: ProjectExecutionAssignment, paths: ProjectExecutionPaths,
                           policy: ProjectExecutionPolicy, store: ProjectExecutionFileStore) async throws -> ProjectExecutionAssignment {
        var assignment = intent
        guard assignment.codexContextID == policy.codexContextID else { throw CodexExecutionContextError.changed }
        guard assignment.state == .preparing, assignment.sessionID == nil,
              assignment.launchReserved != true, assignment.uncertainOutcome != true else {
            throw ProjectExecutionError.assignmentNotAuthorized
        }
        try await configuration.useCodexContext(policy.codexContextID)
        let profile = try ProjectExecutionPermissionProfile(assignment: assignment, policy: policy, paths: paths)
        let definition = try profile.definition
        if let prior = assignment.permissionProfileDefinition {
            try withProjectExecutionPreparationStage(.preparedAssignmentConfiguration) {
                guard prior == definition else { throw ProjectExecutionError.conflict }
            }
        } else {
            assignment.permissionProfileDefinition = definition
            try withProjectExecutionPreparationStage(.assignmentStoreCompareAndSwap) {
                try store.saveAssignment(assignment, expected: intent)
            }
        }
        do {
            try await configuration.prepareWorkerProfile(primaryRoot: policy.primaryRoot, profile: profile)
        } catch let conflict as ProjectExecutionPreparationConflict {
            throw conflict
        } catch let error as ProjectExecutionError where error == .conflict {
            throw ProjectExecutionPreparationConflict(diagnostic: .init(
                kind: .causeUnavailable,
                stage: .preparedAssignmentConfiguration,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
        guard let tree = assignment.worktree, tree.checkout == paths.checkout.path,
              assignment.checkoutPath == paths.checkout.path, tree.primaryRoot == policy.primaryRoot else {
            throw ProjectExecutionError.identityMismatch
        }
        let checkout = try RepositoryDocumentReader(rootURL: paths.checkout,
            limits: .init(maximumFileBytes: 16 * 1_048_576), afterRead: nil)
        guard try withProjectExecutionPreparationStage(.targetProvisioning, {
            try provisioning.candidateRevision(worktree: tree)
        }) == tree.baseline else {
            throw ProjectExecutionError.identityMismatch
        }
        let currentPolicy = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try store.policy(projectID: assignment.registration.projectID.rawValue)
        }
        let currentAssignment = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        }
        guard currentPolicy == policy, currentAssignment == assignment else {
            throw ProjectExecutionError.assignmentNotAuthorized
        }
        if let contextID = assignment.codexContextID {
            let currentContext = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
                try store.codexContext()
            }
            guard currentContext?.id == contextID else { throw CodexExecutionContextError.changed }
        }
        try withProjectExecutionPreparationStage(.preparedAssignmentConfiguration) {
            try checkout.ensureProjectLayerDirectory()
        }
        do {
            try await configuration.verifyHook(primaryRoot: policy.primaryRoot, checkout: paths.checkout.path,
                command: "\"" + handlerPath + "\" --hook", permitOwnedTrust: false, beforeWrite: {})
        } catch let conflict as ProjectExecutionPreparationConflict {
            throw conflict
        } catch let error as ProjectExecutionError where error == .conflict {
            throw ProjectExecutionPreparationConflict(diagnostic: .init(
                kind: .causeUnavailable,
                stage: .preparedAssignmentConfiguration,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
        try assignment.verifyContext()
        if let parentID = assignment.reviewOfAssignmentID ?? assignment.baselineFromAssignmentID {
            let parent = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
                try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: parentID)
            }
            guard parent.state == .closed, parent.retirement == nil, parent.registration == assignment.registration,
                  parent.work == assignment.work, let tree = parent.worktree,
                  try withProjectExecutionPreparationStage(.parentCandidateValidation, {
                      try provisioning.candidateRevision(worktree: tree)
                  }) == assignment.worktree?.baseline else { throw ProjectExecutionError.assignmentNotAuthorized }
        }
        let finalPolicy = try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try store.policy(projectID: assignment.registration.projectID.rawValue)
        }
        guard finalPolicy == policy else { throw ProjectExecutionError.assignmentNotAuthorized }
        var prepared = assignment; prepared.preparedPolicyDigest = try Self.policyDigest(policy)
        try withProjectExecutionPreparationStage(.assignmentStoreCompareAndSwap) {
            try store.saveAssignment(prepared, expected: assignment)
        }
        return prepared
    }
}
