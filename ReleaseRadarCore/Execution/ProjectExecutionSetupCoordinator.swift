import CryptoKit
import Foundation

public enum ProjectExecutionHookStorage: Sendable {
    case projectFile
    case inline(Data)
}

public protocol ProjectExecutionConfiguring: Sendable {
    func selectedCodexContextID() async throws -> UUID?
    func useCodexContext(_ expected: UUID?) async throws
    func validateInstallation(handlerPath: String) async throws
    func validateHandlerIdentity(handlerPath: String) async throws
    func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage
    func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws
    func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws
    func finishConfiguration() async throws
    func recoverConfigurationConnection() async throws
    func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws
    func workerProfileExists(primaryRoot: String, profileID: String) async throws -> Bool
    func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws
    func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws
}

public extension ProjectExecutionConfiguring {
    func selectedCodexContextID() async throws -> UUID? { throw CodexExecutionContextError.selectionRequired }
    func useCodexContext(_ expected: UUID?) async throws { throw CodexExecutionContextError.selectionRequired }
    func validateHandlerIdentity(handlerPath: String) async throws { try await validateInstallation(handlerPath: handlerPath) }
    func workerProfileExists(primaryRoot: String, profileID: String) async throws -> Bool { throw ProjectExecutionError.unavailable }
    func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws { throw ProjectExecutionError.unavailable }
    func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {
        try await beforeWrite()
        try await removeWorkerProfile(primaryRoot: primaryRoot, profileID: profileID, expected: expected)
    }
    func recoverConfigurationConnection() async throws { try await finishConfiguration() }
}

public enum ProjectExecutionHookAction: String, Sendable { case update, remove, resume }

public enum ProjectExecutionHookRemovalError: Error, LocalizedError {
    case workersNotClosed
    public var errorDescription: String? {
        "The workflow is disabled. Close every known worker before removing its admission hook. Uncertain launches require exact recovery; they are never redispatched."
    }
}

/// Native onboarding operation. Authority remains in protected app-owned policy;
/// this type has no public agent endpoint and never starts a work turn.
public actor ProjectExecutionSetupCoordinator: ProjectExecutionSettingUp {
    private let root: @Sendable () throws -> URL
    private let configuration: any ProjectExecutionConfiguring
    private let handlerPath: String
    private var storage: ProjectExecutionFileStore?

    public init(root: @escaping @Sendable () throws -> URL = ProjectExecutionFileStore.applicationRoot,
                configuration: any ProjectExecutionConfiguring, handlerPath: String) {
        self.root = root; self.configuration = configuration; self.handlerPath = handlerPath
    }

    private func store() throws -> ProjectExecutionFileStore {
        if let storage { return storage }
        let value = try ProjectExecutionFileStore(root: root(), create: true)
        storage = value; return value
    }

    private func identity(_ project: AuthorizedProject) throws -> ProjectRegistration {
        guard let registration = project.registration,
              project.canonicalRoot.resolvingSymlinksInPath().path == project.canonicalRoot.path else { throw ProjectExecutionError.identityMismatch }
        return registration
    }

    private func digest(_ data: Data?) -> String? {
        data.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    }

    public func prepare(project: AuthorizedProject) async throws {
        try await prepare(project: project, removedRegistrations: [], beforeWrite: {})
    }

    public func prepare(project: AuthorizedProject, removedRegistrations: [ProjectRegistration], beforeWrite: @escaping @Sendable () async throws -> Void) async throws {
        do { try await prepareOperation(project: project, removedRegistrations: removedRegistrations, beforeWrite: beforeWrite) }
        catch {
            let failure = error
            try await configuration.finishConfiguration()
            throw failure
        }
        try await configuration.finishConfiguration()
    }

    private func prepareOperation(project: AuthorizedProject, permitHandlerUpdate: Bool = false, permitOwnerResume: Bool = false,
                                  removedRegistrations: [ProjectRegistration] = [],
                                  beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws {
        let registration = try identity(project)
        let contextID = try await configuration.selectedCodexContextID()
        try await configuration.useCodexContext(contextID)
        try await configuration.validateInstallation(handlerPath: handlerPath)
        try await beforeWrite()
        let store = try store()
        let command = "\"" + handlerPath + "\" --hook"
        guard handlerPath.hasPrefix("/"), !handlerPath.contains("\""), !handlerPath.contains("\n") else { throw ProjectExecutionError.invalidAssignment }
        try recoverBinding(project: project, registration: registration, store: store, removedRegistrations: removedRegistrations)
        var policy: ProjectExecutionPolicy
        if let existing = try store.policyIfPresent(projectID: project.projectID.rawValue) {
            if permitHandlerUpdate, !permitOwnerResume, !existing.enabled,
               existing.registration == registration, existing.primaryRoot == project.canonicalRoot.path,
               existing.appServerExecutable == CodexExecutionIdentity.executable,
               existing.hookRemovalReceipt?.completed == true,
               existing.consent == ProjectExecutionPolicy.Consent() {
                throw ProjectExecutionError.workflowDisabled
            }
            if permitOwnerResume {
                guard !existing.enabled else { throw StoreError.unavailable("The project workflow is already enabled. Existing stopped or uncertain workers still require their own recovery.") }
                guard existing.hookRemovalReceipt == nil || existing.hookRemovalReceipt?.completed == true else { throw StoreError.unavailable("Finish hook removal and resolve its conflicting edits before resuming the project workflow.") }
            }
            guard existing.registration == registration, existing.primaryRoot == project.canonicalRoot.path,
                  (existing.handlerPath == handlerPath || permitHandlerUpdate), existing.appServerExecutable == CodexExecutionIdentity.executable,
                  !permitOwnerResume || !existing.enabled,
                  (existing.enabled && existing.hookRemovalReceipt == nil || permitOwnerResume && !existing.enabled && (existing.hookRemovalReceipt == nil || existing.hookRemovalReceipt?.completed == true)),
                  existing.consent == ProjectExecutionPolicy.Consent() else { throw ProjectExecutionError.assignmentNotAuthorized }
            policy = existing
            if existing.handlerPath != handlerPath {
                let owned = existing.hookReceipt ?? existing.relocatedHookReceipt
                guard owned?.installed == true,
                      owned?.command == "\"" + existing.handlerPath + "\" --hook" else { throw ProjectExecutionError.conflict }
                policy = .init(registration: registration, primaryRoot: existing.primaryRoot,
                    appServerExecutable: existing.appServerExecutable, handlerPath: handlerPath, enabled: existing.enabled)
                policy.codexContextID = existing.codexContextID
                policy.consent = existing.consent; policy.hookReceipt = existing.hookReceipt; policy.hookRemovalReceipt = existing.hookRemovalReceipt
                policy.previousProjectIDs = existing.previousProjectIDs
                policy.bindingRecoveryPending = true
                policy.relocatedHookReceipt = existing.relocatedHookReceipt
                try store.savePolicy(policy, expected: existing)
            }
        } else {
            guard !permitOwnerResume else { throw ProjectExecutionError.assignmentNotAuthorized }
            policy = .init(registration: registration, primaryRoot: project.canonicalRoot.path,
                           appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handlerPath)
            policy.consent = ProjectExecutionPolicy.Consent()
            try store.savePolicy(policy, expected: nil)
        }
        if policy.codexContextID != contextID {
            guard policy.codexContextID == nil && policy.hookReceipt == nil || permitHandlerUpdate || permitOwnerResume else { throw CodexExecutionContextError.changed }
            var bound = policy; bound.codexContextID = contextID
            try store.savePolicy(bound, expected: policy); policy = bound
        }
        let mode = try await configuration.hookStorage(primaryRoot: policy.primaryRoot)
        let inline: Bool
        let current: Data?
        let repository = try ProjectExecutionFileStore(root: project.canonicalRoot, create: false)
        switch mode {
        case .projectFile: inline = false; current = try repository.hookConfiguration()
        case let .inline(data): inline = true; current = data
        }
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        let output: Data
        if permitOwnerResume, let removal = policy.hookRemovalReceipt,
           policy.hookReceipt?.beforeDigest != removal.intendedDigest {
            guard removal.inline == inline, digest(current) == removal.intendedDigest,
                  try ProjectExecutionHookRegistration.removeIfPresent(current, previousCommand: removal.command) == current else { throw ProjectExecutionError.conflict }
            output = try ProjectExecutionHookRegistration.merge(current, command: command, previousCommand: nil)
            var intent = policy
            intent.hookReceipt = .init(command: command, inline: inline, beforeDigest: digest(current), intendedDigest: digest(output)!)
            try store.savePolicy(intent, expected: policy); policy = intent
        } else if let receipt = policy.hookReceipt, !receipt.installed {
            guard receipt.inline == inline, receipt.command == command else { throw ProjectExecutionError.conflict }
            if digest(current) == receipt.intendedDigest {
                // Confirm the exact owned definition, not merely a matching path.
                output = try ProjectExecutionHookRegistration.merge(current, command: command, previousCommand: command)
            } else {
                guard digest(current) == receipt.beforeDigest else { throw ProjectExecutionError.conflict }
                output = try ProjectExecutionHookRegistration.merge(current, command: command, previousCommand: receipt.previousCommand)
                guard digest(output) == receipt.intendedDigest else { throw ProjectExecutionError.conflict }
            }
        } else {
            if let receipt = policy.hookReceipt {
                guard receipt.inline == inline else { throw ProjectExecutionError.conflict }
            }
            var previousCommand = policy.hookReceipt?.command
            if previousCommand == nil, let relocated = policy.relocatedHookReceipt {
                guard relocated.installed, relocated.inline == inline else { throw ProjectExecutionError.conflict }
                let without = try ProjectExecutionHookRegistration.removeIfPresent(current, previousCommand: relocated.command)
                if without != current { previousCommand = relocated.command }
            }
            output = try ProjectExecutionHookRegistration.merge(current, command: command, previousCommand: previousCommand)
            var intent = policy
            intent.hookReceipt = .init(command: command, inline: inline, beforeDigest: digest(current), intendedDigest: digest(output)!, previousCommand: previousCommand)
            try store.savePolicy(intent, expected: policy); policy = intent
        }
        let writePolicy = policy
        let validateMutation: @Sendable () async throws -> Void = {
            try await beforeWrite()
            guard try store.policy(projectID: project.projectID.rawValue) == writePolicy else { throw ProjectExecutionError.conflict }
        }
        try await validateMutation()
        if current != output {
            if inline {
                guard let current else { throw ProjectExecutionError.conflict }
                try await configuration.saveInlineHook(primaryRoot: policy.primaryRoot, data: output, expected: current, beforeWrite: validateMutation)
            } else { try repository.saveHookConfiguration(output, expected: current) }
        }
        try await configuration.verifyHook(primaryRoot: policy.primaryRoot, checkout: policy.primaryRoot, command: command, permitOwnedTrust: true, beforeWrite: validateMutation)
        try await validateMutation()
        // Preserve a concurrent disablement or identity change instead of marking it ready.
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        if permitOwnerResume {
            for value in try store.assignments(projectID: project.projectID.rawValue) where [.authorized, .preparing].contains(value.state) {
                var revoked = value; revoked.state = .revoked; revoked.finalizationFailed = nil
                if value.sessionID != nil { revoked.launchReserved = true }
                try store.saveAssignment(revoked, expected: value)
            }
        }
        var installed = policy; installed.hookReceipt?.installed = true; installed.bindingRecoveryPending = nil
        installed.relocatedHookReceipt = nil
        if permitOwnerResume { installed.enabled = true; installed.hookRemovalReceipt = nil }
        try store.savePolicy(installed, expected: policy)
    }

    /// Called only with the application's current bookmark-held binding. Old
    /// outcomes and resources remain historical; they never receive the new lease.
    private func recoverBinding(project: AuthorizedProject, registration: ProjectRegistration,
                                store: ProjectExecutionFileStore, removedRegistrations: [ProjectRegistration]) throws {
        let existing = try store.policyIfPresent(projectID: project.projectID.rawValue)
        if let existing, existing.registration != registration || existing.primaryRoot != project.canonicalRoot.path {
            guard existing.version == 1, existing.registration.registrationID == registration.registrationID,
                  existing.registration.requestGeneration <= registration.requestGeneration,
                  existing.consent == ProjectExecutionPolicy.Consent() else { throw ProjectExecutionError.identityMismatch }
            try revokeOldAssignments(store: store, projectID: project.projectID.rawValue)
            var rebound = ProjectExecutionPolicy(registration: registration, primaryRoot: project.canonicalRoot.path,
                appServerExecutable: existing.appServerExecutable, handlerPath: existing.handlerPath, enabled: existing.enabled)
            rebound.codexContextID = existing.codexContextID
            rebound.consent = existing.consent; rebound.previousProjectIDs = existing.previousProjectIDs
            rebound.bindingRecoveryPending = true
            if existing.primaryRoot == project.canonicalRoot.path {
                rebound.hookReceipt = existing.hookReceipt; rebound.hookRemovalReceipt = existing.hookRemovalReceipt
                rebound.relocatedHookReceipt = existing.relocatedHookReceipt
            } else if existing.hookRemovalReceipt == nil, existing.hookReceipt?.installed == true {
                rebound.relocatedHookReceipt = existing.hookReceipt
            }
            try store.savePolicy(rebound, expected: existing)
        }
        let current = try store.policyIfPresent(projectID: project.projectID.rawValue)
        guard current?.hookReceipt == nil, current?.hookRemovalReceipt == nil else { return }
        for removed in removedRegistrations {
            guard removed.projectID != project.projectID,
                  let prior = try store.policyIfPresent(projectID: removed.projectID.rawValue),
                  prior.version == 1, prior.registration.registrationID == removed.registrationID,
                  prior.registration.requestGeneration <= removed.requestGeneration,
                  prior.primaryRoot == project.canonicalRoot.path,
                  prior.consent == ProjectExecutionPolicy.Consent(), let hook = prior.hookReceipt, hook.installed,
                  hook.command == "\"" + prior.handlerPath + "\" --hook",
                  prior.hookRemovalReceipt == nil else { continue }
            try revokeOldAssignments(store: store, projectID: removed.projectID.rawValue)
            if prior.enabled { var disabled = prior; disabled.enabled = false; try store.savePolicy(disabled, expected: prior) }
            var adopted = current ?? ProjectExecutionPolicy(registration: registration, primaryRoot: project.canonicalRoot.path,
                appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handlerPath)
            adopted.codexContextID = prior.codexContextID
            adopted.consent = ProjectExecutionPolicy.Consent(); adopted.hookReceipt = hook
            adopted.bindingRecoveryPending = true
            adopted.previousProjectIDs = Array(Set((prior.previousProjectIDs ?? []) + [removed.projectID.rawValue])).sorted()
            try store.savePolicy(adopted, expected: current)
            return
        }
    }

    private func revokeOldAssignments(store: ProjectExecutionFileStore, projectID: String) throws {
        for value in try store.assignments(projectID: projectID) where [.authorized, .preparing].contains(value.state) {
            var revoked = value; revoked.state = .revoked; revoked.finalizationFailed = nil
            if value.sessionID != nil { revoked.launchReserved = true }
            try store.saveAssignment(revoked, expected: value)
        }
    }

    public func update(project: AuthorizedProject, beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws {
        do { try await prepareOperation(project: project, permitHandlerUpdate: true, beforeWrite: beforeWrite) }
        catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
        try await configuration.finishConfiguration()
    }

    public func removeHook(project: AuthorizedProject, beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws {
        do { try await removeHookOperation(project: project, beforeWrite: beforeWrite) }
        catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
        try await configuration.finishConfiguration()
    }

    public func resume(project: AuthorizedProject, beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws {
        do { try await prepareOperation(project: project, permitOwnerResume: true, beforeWrite: beforeWrite) }
        catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
        try await configuration.finishConfiguration()
    }

    private func removeHookOperation(project: AuthorizedProject, beforeWrite: @escaping @Sendable () async throws -> Void) async throws {
        let registration = try identity(project)
        try await beforeWrite()
        let store = try store()
        var policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.version == 1, policy.registration == registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.consent == ProjectExecutionPolicy.Consent(), let owned = policy.hookReceipt,
              owned.command == "\"" + policy.handlerPath + "\" --hook" else { throw ProjectExecutionError.identityMismatch }
        if policy.enabled {
            var disabled = policy; disabled.enabled = false
            try store.savePolicy(disabled, expected: policy); policy = disabled
        }
        // Keep the admission hook until known sessions are closed. Removing it
        // while an uncertain/live task remains would open an unmanaged prompt route.
        guard try store.assignments(projectID: project.projectID.rawValue).allSatisfy({ value in
            (value.state != .unknown && value.uncertainOutcome != true || value.state == .superseded && value.retirement?.completed == true) && (value.state == .closed || value.connectionClosed == true || value.sessionID == nil && value.launchReserved != true)
        }) else { throw ProjectExecutionHookRemovalError.workersNotClosed }
        try await configuration.useCodexContext(policy.codexContextID)
        try await configuration.validateHandlerIdentity(handlerPath: handlerPath)
        let mode = try await configuration.hookStorage(primaryRoot: policy.primaryRoot)
        let repository = try ProjectExecutionFileStore(root: project.canonicalRoot, create: false)
        let current: Data?
        switch mode {
        case .projectFile: guard !owned.inline else { throw ProjectExecutionError.conflict }; current = try repository.hookConfiguration()
        case let .inline(data): guard owned.inline else { throw ProjectExecutionError.conflict }; current = data
        }
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        let output: Data?
        if let intent = policy.hookRemovalReceipt {
            guard intent.command == owned.command, intent.inline == owned.inline else { throw ProjectExecutionError.conflict }
            if digest(current) == intent.intendedDigest {
                guard try ProjectExecutionHookRegistration.removeIfPresent(current, previousCommand: owned.command) == current else { throw ProjectExecutionError.conflict }
                output = current
            } else {
                guard !intent.completed, digest(current) == intent.beforeDigest else { throw ProjectExecutionError.conflict }
                output = try ProjectExecutionHookRegistration.removeIfPresent(current, previousCommand: owned.command)
                guard digest(output) == intent.intendedDigest else { throw ProjectExecutionError.conflict }
            }
        } else {
            output = try ProjectExecutionHookRegistration.removeIfPresent(current, previousCommand: owned.command)
            var intent = policy
            intent.hookRemovalReceipt = .init(command: owned.command, inline: owned.inline,
                beforeDigest: digest(current), intendedDigest: digest(output))
            try store.savePolicy(intent, expected: policy); policy = intent
        }
        guard try store.assignments(projectID: project.projectID.rawValue).allSatisfy({ value in
            (value.state != .unknown && value.uncertainOutcome != true || value.state == .superseded && value.retirement?.completed == true) && (value.state == .closed || value.connectionClosed == true || value.sessionID == nil && value.launchReserved != true)
        }) else { throw ProjectExecutionHookRemovalError.workersNotClosed }
        let writePolicy = policy
        let validateMutation: @Sendable () async throws -> Void = {
            try await beforeWrite()
            guard try store.policy(projectID: project.projectID.rawValue) == writePolicy else { throw ProjectExecutionError.conflict }
        }
        try await validateMutation()
        if current != output {
            guard let output else { throw ProjectExecutionError.conflict }
            if owned.inline {
                guard let current else { throw ProjectExecutionError.conflict }
                try await configuration.saveInlineHook(primaryRoot: policy.primaryRoot, data: output, expected: current, beforeWrite: validateMutation)
            } else { try repository.saveHookConfiguration(output, expected: current) }
        }
        let actual: Data?
        if owned.inline {
            guard case let .inline(data) = try await configuration.hookStorage(primaryRoot: policy.primaryRoot) else { throw ProjectExecutionError.conflict }
            actual = data
        } else { actual = try repository.hookConfiguration() }
        try await validateMutation()
        guard actual == output, try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        var removed = policy; removed.hookReceipt?.installed = false; removed.hookRemovalReceipt?.completed = true
        try store.savePolicy(removed, expected: policy)
    }

    public func verify(project: AuthorizedProject) async throws {
        do { try await verifyOperation(project: project) }
        catch {
            let failure = error
            try await configuration.finishConfiguration()
            throw failure
        }
        try await configuration.finishConfiguration()
    }

    private func verifyOperation(project: AuthorizedProject) async throws {
        let registration = try identity(project)
        try await configuration.validateInstallation(handlerPath: handlerPath)
        let store = try store()
        let policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.registration == registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.enabled, policy.bindingRecoveryPending != true, policy.consent == ProjectExecutionPolicy.Consent(), let receipt = policy.hookReceipt, receipt.installed,
              receipt.command == "\"" + handlerPath + "\" --hook" else { throw ProjectExecutionError.assignmentNotAuthorized }
        try await configuration.useCodexContext(policy.codexContextID)
        try await configuration.verifyHook(primaryRoot: policy.primaryRoot, checkout: policy.primaryRoot, command: receipt.command, permitOwnedTrust: false, beforeWrite: {})
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
    }
}
