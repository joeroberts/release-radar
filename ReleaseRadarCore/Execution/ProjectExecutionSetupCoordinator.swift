import CryptoKit
import Foundation

public enum ProjectExecutionHookStorage: Sendable {
    case projectFile
    case inline(Data)
}

public protocol ProjectExecutionConfiguring: Sendable {
    func validateInstallation(handlerPath: String) async throws
    func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage
    func saveInlineHook(primaryRoot: String, data: Data, expected: Data) async throws
    func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool) async throws
    func finishConfiguration() async throws
    func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws
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

    private func prepareOperation(project: AuthorizedProject) async throws {
        let registration = try identity(project)
        try await configuration.validateInstallation(handlerPath: handlerPath)
        let store = try store()
        let command = "\"" + handlerPath + "\" --hook"
        guard handlerPath.hasPrefix("/"), !handlerPath.contains("\""), !handlerPath.contains("\n") else { throw ProjectExecutionError.invalidAssignment }
        var policy: ProjectExecutionPolicy
        if let existing = try store.policyIfPresent(projectID: project.projectID.rawValue) {
            guard existing.registration == registration, existing.primaryRoot == project.canonicalRoot.path,
                  existing.handlerPath == handlerPath, existing.appServerExecutable == CodexExecutionIdentity.executable,
                  existing.enabled, existing.consent == ProjectExecutionPolicy.Consent() else { throw ProjectExecutionError.assignmentNotAuthorized }
            policy = existing
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
