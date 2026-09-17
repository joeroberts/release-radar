import CryptoKit
import Foundation

public enum ProjectExecutionHookStorage: Sendable {
    case projectFile
    case inline(Data)
}

public protocol ProjectExecutionConfiguring: Sendable {
    func validateInstallation(handlerPath: String) async throws
    func validateHandlerIdentity(handlerPath: String) async throws
    func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage
    func saveInlineHook(primaryRoot: String, data: Data, expected: Data) async throws
    func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool) async throws
    func finishConfiguration() async throws
    func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws
}

public extension ProjectExecutionConfiguring {
    func validateHandlerIdentity(handlerPath: String) async throws { try await validateInstallation(handlerPath: handlerPath) }
}

public enum ProjectExecutionHookAction: String, Sendable { case update, remove }

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
        do { try await prepareOperation(project: project) }
        catch {
            let failure = error
            try await configuration.finishConfiguration()
            throw failure
        }
        try await configuration.finishConfiguration()
    }

    private func prepareOperation(project: AuthorizedProject, permitHandlerUpdate: Bool = false,
                                  beforeWrite: @Sendable () async throws -> Void = {}) async throws {
        let registration = try identity(project)
        try await configuration.validateInstallation(handlerPath: handlerPath)
        try await beforeWrite()
        let store = try store()
        let command = "\"" + handlerPath + "\" --hook"
        guard handlerPath.hasPrefix("/"), !handlerPath.contains("\""), !handlerPath.contains("\n") else { throw ProjectExecutionError.invalidAssignment }
        var policy: ProjectExecutionPolicy
        if let existing = try store.policyIfPresent(projectID: project.projectID.rawValue) {
            guard existing.registration == registration, existing.primaryRoot == project.canonicalRoot.path,
                  (existing.handlerPath == handlerPath || permitHandlerUpdate), existing.appServerExecutable == CodexExecutionIdentity.executable,
                  existing.enabled, existing.hookRemovalReceipt == nil, existing.consent == ProjectExecutionPolicy.Consent() else { throw ProjectExecutionError.assignmentNotAuthorized }
            policy = existing
            if existing.handlerPath != handlerPath {
                guard existing.hookReceipt?.installed == true,
                      existing.hookReceipt?.command == "\"" + existing.handlerPath + "\" --hook" else { throw ProjectExecutionError.conflict }
                policy = .init(registration: registration, primaryRoot: existing.primaryRoot,
                    appServerExecutable: existing.appServerExecutable, handlerPath: handlerPath)
                policy.consent = existing.consent; policy.hookReceipt = existing.hookReceipt
                try store.savePolicy(policy, expected: existing)
            }
        } else {
            policy = .init(registration: registration, primaryRoot: project.canonicalRoot.path,
                           appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handlerPath)
            policy.consent = ProjectExecutionPolicy.Consent()
            try store.savePolicy(policy, expected: nil)
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
        if let receipt = policy.hookReceipt, !receipt.installed {
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
            output = try ProjectExecutionHookRegistration.merge(current, command: command, previousCommand: policy.hookReceipt?.command)
            var intent = policy
            intent.hookReceipt = .init(command: command, inline: inline, beforeDigest: digest(current), intendedDigest: digest(output)!, previousCommand: policy.hookReceipt?.command)
            try store.savePolicy(intent, expected: policy); policy = intent
        }
        if current != output {
            if inline {
                guard let current else { throw ProjectExecutionError.conflict }
                try await configuration.saveInlineHook(primaryRoot: policy.primaryRoot, data: output, expected: current)
            } else { try repository.saveHookConfiguration(output, expected: current) }
        }
        try await configuration.verifyHook(primaryRoot: policy.primaryRoot, checkout: policy.primaryRoot, command: command, permitOwnedTrust: true)
        // Preserve a concurrent disablement or identity change instead of marking it ready.
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        var installed = policy; installed.hookReceipt?.installed = true
        try store.savePolicy(installed, expected: policy)
    }

    public func update(project: AuthorizedProject, beforeWrite: @Sendable () async throws -> Void = {}) async throws {
        do { try await prepareOperation(project: project, permitHandlerUpdate: true, beforeWrite: beforeWrite) }
        catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
        try await configuration.finishConfiguration()
    }

    public func removeHook(project: AuthorizedProject, beforeWrite: @Sendable () async throws -> Void = {}) async throws {
        do { try await removeHookOperation(project: project, beforeWrite: beforeWrite) }
        catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
        try await configuration.finishConfiguration()
    }

    private func removeHookOperation(project: AuthorizedProject, beforeWrite: @Sendable () async throws -> Void) async throws {
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
            value.state != .unknown && value.uncertainOutcome != true && (value.state == .closed || value.connectionClosed == true || value.sessionID == nil)
        }) else { throw ProjectExecutionHookRemovalError.workersNotClosed }
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
            value.state != .unknown && value.uncertainOutcome != true && (value.state == .closed || value.connectionClosed == true || value.sessionID == nil)
        }) else { throw ProjectExecutionHookRemovalError.workersNotClosed }
        if current != output {
            guard let output else { throw ProjectExecutionError.conflict }
            if owned.inline {
                guard let current else { throw ProjectExecutionError.conflict }
                try await configuration.saveInlineHook(primaryRoot: policy.primaryRoot, data: output, expected: current)
            } else { try repository.saveHookConfiguration(output, expected: current) }
        }
        let actual: Data?
        if owned.inline {
            guard case let .inline(data) = try await configuration.hookStorage(primaryRoot: policy.primaryRoot) else { throw ProjectExecutionError.conflict }
            actual = data
        } else { actual = try repository.hookConfiguration() }
        try await beforeWrite()
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
              policy.enabled, policy.consent == ProjectExecutionPolicy.Consent(), let receipt = policy.hookReceipt, receipt.installed,
              receipt.command == "\"" + handlerPath + "\" --hook" else { throw ProjectExecutionError.assignmentNotAuthorized }
        try await configuration.verifyHook(primaryRoot: policy.primaryRoot, checkout: policy.primaryRoot, command: receipt.command, permitOwnedTrust: false)
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
    }
}
