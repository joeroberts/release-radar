import CryptoKit
import Foundation

public enum ProjectExecutionError: Error, LocalizedError, Codable, Equatable, Sendable {
    case invalidAssignment
    case unavailable
    case assignmentNotAuthorized
    case identityMismatch
    case conflict
    case hookNotReady

    public var errorDescription: String? {
        switch self {
        case .invalidAssignment: "The execution assignment is invalid. Ask the coordinator to prepare a new bounded assignment."
        case .unavailable: "Project execution setup is unavailable. Resume setup in Release Radar before launching work."
        case .assignmentNotAuthorized: "This assignment is stopped, revoked or no longer current. Return to the coordinator; no work turn is authorized."
        case .identityMismatch: "The execution assignment does not match this project, checkout or session. Return to the coordinator."
        case .conflict: "Release Radar execution setup conflicts with an existing edit. Preserve the edit and resolve it in project setup."
        case .hookNotReady: "The project hook is missing, disabled, changed or untrusted. Resume execution setup in Release Radar."
        }
    }
}

public struct ProjectExecutionPaths: Sendable {
    public let checkout: URL
    public let assignment: URL
    public let projectPolicy: URL

    public init(storageRoot: URL, projectID: String, taskID: String) throws {
        let project = try Self.component(projectID)
        let task = try Self.component(taskID)
        checkout = storageRoot.appendingPathComponent("Worktrees/\(project)/\(task)", isDirectory: true)
        assignment = storageRoot.appendingPathComponent("Assignments/\(project)/\(task)/assignment.json")
        projectPolicy = storageRoot.appendingPathComponent("Projects/\(project)/policy.json")
    }

    @discardableResult public static func component(_ value: String) throws -> String {
        guard !value.isEmpty, value.utf8.count <= 160,
              value.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9_-]*$"#, options: .regularExpression) != nil else {
            throw ProjectExecutionError.invalidAssignment
        }
        return value
    }
}

/// Application-produced authority. Prompts and asserted roles are never inputs to admission.
public struct ProjectExecutionAssignment: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case authorized, preparing, stopped, revoked, superseded, unknown, closed }
    public enum Role: String, Codable, Sendable { case delivery, review }
    public var codexContextID: UUID? = nil
    public var connectionClosed: Bool? = nil
    public var launchReserved: Bool? = nil
    public var finalizationFailed: Bool? = nil
    public var preparedPolicyDigest: String? = nil
    public var uncertainOutcome: Bool? = nil
    public var permissionProfileDefinition: Data? = nil
    public var retirement: Retirement? = nil
    public struct Retirement: Codable, Equatable, Sendable {
        public let requestID: UUID
        public let priorState: State
        public var worktreeRemoved: Bool = false
        public var profileRemoved: Bool = false
        public var completed: Bool = false
        public var connectionCloseUncertain: Bool? = nil
        public var replacementAllowed: Bool? = nil
        public init(requestID: UUID, priorState: State) { self.requestID = requestID; self.priorState = priorState }
    }
    public struct Context: Codable, Equatable, Sendable {
        public let path: String
        public let digest: String
        public init(path: String, digest: String) { self.path = path; self.digest = digest }
    }
    public let version: Int
    public let id: String
    public let registration: ProjectRegistration
    public let checkoutPath: String
    public let role: Role
    public let permissionProfile: String
    public let model: String
    public let effort: String
    public let authorization: String
    public let context: [Context]
    public let excludedPaths: [String]
    public let worktree: ExecutionWorktree?
    public let work: ProjectExecutionWork?
    public let reviewOfAssignmentID: String?
    public let baselineFromAssignmentID: String?
    public var state: State
    public var sessionID: String?

    public init(id: String, registration: ProjectRegistration, checkoutPath: String, role: Role,
                permissionProfile: String, model: String, effort: String, authorization: String,
                context: [Context], excludedPaths: [String], state: State = .authorized, sessionID: String? = nil,
                worktree: ExecutionWorktree? = nil, work: ProjectExecutionWork? = nil,
                reviewOfAssignmentID: String? = nil, baselineFromAssignmentID: String? = nil) {
        version = 1; self.id = id; self.registration = registration; self.checkoutPath = checkoutPath
        self.role = role; self.permissionProfile = permissionProfile; self.model = model; self.effort = effort
        self.authorization = authorization; self.context = context; self.excludedPaths = excludedPaths
        self.state = state; self.sessionID = sessionID
        self.worktree = worktree
        self.work = work; self.reviewOfAssignmentID = reviewOfAssignmentID; self.baselineFromAssignmentID = baselineFromAssignmentID
    }

    @discardableResult public func validated(effort override: String? = nil) throws -> Self {
        try ProjectExecutionPaths.component(id)
        try ProjectExecutionPaths.component(registration.projectID.rawValue)
        try ProjectExecutionPaths.component(permissionProfile)
        guard version == 1, !registration.registrationID.isEmpty, registration.requestGeneration > 0,
              checkoutPath.hasPrefix("/"), checkoutPath == URL(fileURLWithPath: checkoutPath).standardizedFileURL.path,
              !checkoutPath.utf8.contains(0), !model.isEmpty,
              ["low", "medium", "high", "xhigh", "max"].contains(override ?? effort),
              !authorization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              authorization.utf8.count <= 64_000, !context.isEmpty,
              Set(context.map(\.path)).count == context.count,
              [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"].allSatisfy(excludedPaths.contains)
        else { throw ProjectExecutionError.invalidAssignment }
        if connectionClosed == true, ![State.closed, .stopped, .revoked, .superseded, .unknown].contains(state) {
            throw ProjectExecutionError.invalidAssignment
        }
        if let preparedPolicyDigest, preparedPolicyDigest.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) == nil { throw ProjectExecutionError.invalidAssignment }
        if let definition = permissionProfileDefinition {
            guard definition.count <= 32_768,
                  let object = try JSONSerialization.jsonObject(with: definition) as? [String: Any],
                  Set(object.keys) == ["filesystem", "network"], object["filesystem"] is [String: Any],
                  let network = object["network"] as? [String: Any], Set(network.keys) == ["enabled"],
                  network["enabled"] as? Bool == false else { throw ProjectExecutionError.invalidAssignment }
        }
        if let retirement {
            guard state != .authorized, state != .preparing,
                  retirement.replacementAllowed != true || (retirement.worktreeRemoved && retirement.profileRemoved && (connectionClosed == true || state == .closed || sessionID == nil && launchReserved != true)),
                  !retirement.completed || (state == .superseded && retirement.worktreeRemoved && retirement.profileRemoved && retirement.connectionCloseUncertain != true) else { throw ProjectExecutionError.invalidAssignment }
        }
        for source in context {
            guard !source.path.hasPrefix("/"), !source.path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                  source.digest.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil,
                  !excludedPaths.contains(where: { source.path == $0 || source.path.hasPrefix($0 + "/") })
            else { throw ProjectExecutionError.invalidAssignment }
        }
        if let worktree {
            guard worktree.checkout == checkoutPath,
                  worktree.baseline.range(of: #"^[a-f0-9]{40}$"#, options: .regularExpression) != nil,
                  worktree.primaryRoot.hasPrefix("/"), worktree.commonGitDirectory.hasPrefix("/"),
                  worktree.primaryRoot == URL(fileURLWithPath: worktree.primaryRoot).standardizedFileURL.path,
                  worktree.commonGitDirectory == URL(fileURLWithPath: worktree.commonGitDirectory).standardizedFileURL.path,
                  !worktree.commonGitDirectory.hasPrefix(checkoutPath + "/"), worktree.primaryRoot != checkoutPath else {
                throw ProjectExecutionError.invalidAssignment
            }
        }
        if let work {
            guard work.projectID == registration.projectID, work.taskPlanRevision > 0, work.phaseRevision > 0,
                  !work.ticketID.isEmpty, !work.taskID.isEmpty, !work.outcome.isEmpty, !work.title.isEmpty,
                  !work.phaseID.isEmpty else { throw ProjectExecutionError.invalidAssignment }
        }
        if let reviewOfAssignmentID { try ProjectExecutionPaths.component(reviewOfAssignmentID) }
        if let baselineFromAssignmentID { try ProjectExecutionPaths.component(baselineFromAssignmentID) }
        return self
    }

    public func admit(registration expected: ProjectRegistration, checkoutPath: String,
                      sessionID: String, boundSessionID: String?) throws {
        try validated()
        guard state == .authorized, uncertainOutcome != true, connectionClosed != true else { throw ProjectExecutionError.assignmentNotAuthorized }
        guard registration == expected, self.checkoutPath == checkoutPath,
              !sessionID.isEmpty, boundSessionID == sessionID else { throw ProjectExecutionError.identityMismatch }
    }

    public func verifyContext() throws {
        let reader = try RepositoryDocumentReader(rootURL: URL(fileURLWithPath: checkoutPath),
            limits: .init(maximumFileBytes: 16 * 1_048_576), afterRead: nil)
        for source in context {
            let bytes = try reader.read(source.path)
            guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == source.digest else {
                throw ProjectExecutionError.identityMismatch
            }
        }
        try reader.verifyStable()
    }

    public var workerInstructions: String {
        """
        Release Radar verified assignment \(id), project \(registration.projectID.rawValue), role \(role.rawValue).
        Existing owner authorization for this bounded outcome: \(authorization)
        Work only in \(checkoutPath) under \(permissionProfile), model \(model), effort \(effort).
        Current context: \(context.map(\.path).joined(separator: ", ")). Historical retrieval remains a separate Main operation.
        Runtime approval policies remain in force. This assignment carries scoped authorization; it grants no broader access or external effects.
        STOP and cancellation require no additional work. A scope change returns to the coordinator for a new assignment.
        """
    }
}

public struct ProjectExecutionPolicy: Codable, Equatable, Sendable {
    public struct HookRemovalReceipt: Codable, Equatable, Sendable {
        public let command: String
        public let inline: Bool
        public let beforeDigest: String?
        public let intendedDigest: String?
        public var completed: Bool
        public init(command: String, inline: Bool, beforeDigest: String?, intendedDigest: String?, completed: Bool = false) {
            self.command = command; self.inline = inline; self.beforeDigest = beforeDigest
            self.intendedDigest = intendedDigest; self.completed = completed
        }
    }
    public struct Consent: Codable, Equatable, Sendable {
        public enum Source: String, Codable, Sendable { case onboardingOwner }
        public let source: Source
        public let version: Int
        public init() { source = .onboardingOwner; version = 1 }
    }
    public struct HookReceipt: Codable, Equatable, Sendable {
        public let command: String
        public let inline: Bool
        public let beforeDigest: String?
        public let intendedDigest: String
        public let previousCommand: String?
        public var installed: Bool
        public init(command: String, inline: Bool, beforeDigest: String?, intendedDigest: String, previousCommand: String? = nil, installed: Bool = false) {
            self.command = command; self.inline = inline; self.beforeDigest = beforeDigest
            self.intendedDigest = intendedDigest; self.installed = installed
            self.previousCommand = previousCommand
        }
    }
    public let version: Int
    public let registration: ProjectRegistration
    public let primaryRoot: String
    public let appServerExecutable: String
    public let handlerPath: String
    public var enabled: Bool
    public var consent: Consent?
    public var hookReceipt: HookReceipt?
    public var hookRemovalReceipt: HookRemovalReceipt?
    public var previousProjectIDs: [String]? = nil
    public var codexContextID: UUID? = nil
    public var bindingRecoveryPending: Bool? = nil
    public var relocatedHookReceipt: HookReceipt? = nil
    public init(registration: ProjectRegistration, primaryRoot: String, appServerExecutable: String, handlerPath: String, enabled: Bool = true) {
        version = 1; self.registration = registration; self.primaryRoot = primaryRoot
        self.appServerExecutable = appServerExecutable; self.handlerPath = handlerPath; self.enabled = enabled
    }
}

public protocol ProjectExecutionSettingUp: Sendable {
    func prepare(project: AuthorizedProject) async throws
    func prepare(project: AuthorizedProject, removedRegistrations: [ProjectRegistration], beforeWrite: @escaping @Sendable () async throws -> Void) async throws
    func verify(project: AuthorizedProject) async throws
}

public extension ProjectExecutionSettingUp {
    func prepare(project: AuthorizedProject, removedRegistrations: [ProjectRegistration], beforeWrite: @escaping @Sendable () async throws -> Void) async throws {
        try await beforeWrite()
        try await prepare(project: project)
    }
}
