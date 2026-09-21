import Darwin
import Foundation
import Security

public protocol ProjectExecutionWorkerProcessObserving: Sendable {
    func verifiedAbsence(for assignment: ProjectExecutionAssignment) throws
        -> ProjectExecutionAssignment.LostWorkerProcessEvidence
}

public protocol ProjectExecutionContextGrantReconciling: Sendable {
    func reconcileLostWorkerGrant(for assignment: ProjectExecutionAssignment) throws
        -> ProjectExecutionAssignment.LostWorkerRecovery.GrantDisposition
}

public struct UnavailableProjectExecutionContextGrantReconciler: ProjectExecutionContextGrantReconciling {
    public init() {}
    public func reconcileLostWorkerGrant(for assignment: ProjectExecutionAssignment) throws
        -> ProjectExecutionAssignment.LostWorkerRecovery.GrantDisposition {
        throw ProjectExecutionError.unavailable
    }
}

/// A fail-closed same-user process snapshot. Recovery is permitted only when
/// every observable process is stable and no live process carries this exact
/// assignment's kernel-enforced permission marker.
public struct ProjectExecutionWorkerProcessInventory: ProjectExecutionWorkerProcessObserving, Sendable {
    public struct Process: Equatable, Sendable {
        public enum Identity: Equatable, Sendable { case expected, unexpected, unavailable, unrelated }
        public let processID: Int32
        public let startTime: UInt64
        public let executablePath: String
        public let arguments: [String]?
        public let identity: Identity
        public let stable: Bool

        public init(processID: Int32, startTime: UInt64, executablePath: String,
                    arguments: [String]?, identity: Identity, stable: Bool) {
            self.processID = processID; self.startTime = startTime
            self.executablePath = executablePath; self.arguments = arguments
            self.identity = identity; self.stable = stable
        }
    }

    public struct Snapshot: Equatable, Sendable {
        public let isComplete: Bool
        public let processes: [Process]
        public init(isComplete: Bool, processes: [Process]) {
            self.isComplete = isComplete; self.processes = processes
        }
    }

    public init() {}

    public func verifiedAbsence(for assignment: ProjectExecutionAssignment) throws
        -> ProjectExecutionAssignment.LostWorkerProcessEvidence {
        let observedAt = Date()
        return try Self.verifiedAbsence(for: assignment, snapshot: snapshot(), observedAt: observedAt)
    }

    public static func verifiedAbsence(for assignment: ProjectExecutionAssignment,
                                       snapshot: Snapshot, observedAt: Date)
        throws -> ProjectExecutionAssignment.LostWorkerProcessEvidence {
        let marker = "permissions.\(assignment.permissionProfile).network.enabled=false"
        guard snapshot.isComplete, snapshot.processes.allSatisfy(\.stable) else {
            throw StoreError.unavailable("Worker recovery could not obtain a complete, stable same-user process inventory. Quit any remaining worker for this assignment and retry. Its checkout, grant and uncertain outcome were preserved.")
        }
        for process in snapshot.processes {
            let containsMarker = process.arguments?.contains(marker) == true
            if containsMarker {
                // Even a correctly signed exact worker is still live. A marker on
                // any other identity is suspicious and therefore equally blocking.
                let reason = process.executablePath == CodexExecutionIdentity.executable
                    && process.identity == .expected
                    ? "The exact signed worker is still running. Stop it through its existing task connection before retrying recovery."
                    : "A process with this assignment marker has an unexpected or unverifiable identity. Recovery is unavailable until that process is resolved."
                throw StoreError.unavailable("\(reason) No assignment state or resource was changed.")
            }
            if process.executablePath == CodexExecutionIdentity.executable,
               process.arguments == nil || process.identity != .expected {
                throw StoreError.unavailable("Worker recovery could not verify a running Codex process or read its arguments. No assignment state or resource was changed; retry only after process visibility is restored.")
            }
        }
        return .init(version: 1, observedAt: observedAt,
            executablePath: CodexExecutionIdentity.executable,
            permissionProfile: assignment.permissionProfile, argumentMarker: marker)
    }

    private func snapshot() -> Snapshot {
        let capacity = max(Int(proc_listallpids(nil, 0)) + 32, 32)
        var identifiers = [Int32](repeating: 0, count: capacity)
        let count = identifiers.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard count >= 0 else { return .init(isComplete: false, processes: []) }
        var complete = Int(count) < capacity
        var processes: [Process] = []
        for processID in identifiers.prefix(Int(count))
            where processID > 0 && processID != getpid() {
            guard let first = processInfo(processID) else {
                if processExists(processID) { complete = false }
                continue
            }
            guard first.userID == geteuid() else { continue }
            guard let path = processPath(processID), let arguments = processArguments(processID) else {
                if processExists(processID) { complete = false }
                continue
            }
            guard let second = processInfo(processID) else {
                if processExists(processID) { complete = false }
                continue
            }
            let stable = first.userID == second.userID && first.startTime == second.startTime
            let identity: Process.Identity
            if path == CodexExecutionIdentity.executable {
                identity = runningCodexIsTrusted(processID) ? .expected : .unavailable
            } else if arguments.contains(where: { $0.hasPrefix("permissions.") && $0.hasSuffix(".network.enabled=false") }) {
                identity = .unexpected
            } else {
                identity = .unrelated
            }
            processes.append(.init(processID: processID, startTime: first.startTime,
                executablePath: path, arguments: arguments, identity: identity, stable: stable))
        }
        return .init(isComplete: complete, processes: processes)
    }

    private func processInfo(_ processID: Int32) -> (userID: uid_t, startTime: UInt64)? {
        var information = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(processID, PROC_PIDTBSDINFO, 0, &information, Int32(size)) == Int32(size) else { return nil }
        let seconds = UInt64(information.pbi_start_tvsec)
        let microseconds = UInt64(information.pbi_start_tvusec)
        return (information.pbi_uid, seconds &* 1_000_000 &+ microseconds)
    }

    private func processPath(_ processID: Int32) -> String? {
        // proc_pidpath's documented ceiling is four Darwin PATH_MAX values.
        // The compound SDK macro is not imported into Swift, while PATH_MAX is.
        var bytes = [CChar](repeating: 0, count: Int(PATH_MAX) * 4)
        let count = proc_pidpath(processID, &bytes, UInt32(bytes.count))
        guard count > 0, Int(count) < bytes.count, bytes[Int(count)] == 0 else { return nil }
        return String(cString: bytes)
    }

    private func processArguments(_ processID: Int32) -> [String]? {
        var command = [CTL_KERN, KERN_PROCARGS2, processID]
        var size = 0
        guard sysctl(&command, UInt32(command.count), nil, &size, nil, 0) == 0,
              size >= MemoryLayout<Int32>.size, size <= 4 * 1_048_576 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctl(&command, UInt32(command.count), &bytes, &size, nil, 0) == 0 else { return nil }
        return bytes.withUnsafeBytes { raw -> [String]? in
            guard let base = raw.baseAddress else { return nil }
            let argumentCount = Int(base.loadUnaligned(as: Int32.self))
            guard argumentCount >= 0 && argumentCount <= 16_384 else { return nil }
            var index = MemoryLayout<Int32>.size
            func skipString() {
                while index < size && bytes[index] != 0 { index += 1 }
                while index < size && bytes[index] == 0 { index += 1 }
            }
            skipString() // executable path
            var result: [String] = []
            for _ in 0..<argumentCount {
                guard index < size else { return nil }
                let start = index
                while index < size && bytes[index] != 0 { index += 1 }
                guard index < size, let value = String(bytes: bytes[start..<index], encoding: .utf8) else { return nil }
                result.append(value)
                while index < size && bytes[index] == 0 { index += 1 }
            }
            return result
        }
    }

    private func processExists(_ processID: Int32) -> Bool {
        errno = 0
        return kill(processID, 0) == 0 || errno != ESRCH
    }

    private func runningCodexIsTrusted(_ processID: Int32) -> Bool {
        let attributes = [kSecGuestAttributePid as String: NSNumber(value: processID)] as CFDictionary
        var code: SecCode?
        var requirement: SecRequirement?
        let identity = "anchor apple generic and identifier \"codex\" and certificate leaf[subject.OU] = \"2DC432GLL2\""
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              SecRequirementCreateWithString(identity as CFString, [], &requirement) == errSecSuccess,
              let code, let requirement else { return false }
        return SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess
    }
}

/// Owner-only resource retirement. It never completes work or launches a worker.
public actor ProjectExecutionResourceLifecycle {
    private let root: @Sendable () throws -> URL
    private let configuration: any ProjectExecutionConfiguring
    private let provisioning: any ExecutionWorktreeProvisioning
    private let processObserver: any ProjectExecutionWorkerProcessObserving
    private let grantReconciler: any ProjectExecutionContextGrantReconciling
    private var retiring = false
    private var pendingClose: (projectID: String, assignmentID: String, requestID: UUID)?

    public init(root: @escaping @Sendable () throws -> URL = ProjectExecutionFileStore.applicationRoot,
                configuration: any ProjectExecutionConfiguring,
                provisioning: any ExecutionWorktreeProvisioning = LibGit2WorktreeProvisioner(),
                processObserver: any ProjectExecutionWorkerProcessObserving = ProjectExecutionWorkerProcessInventory(),
                grantReconciler: any ProjectExecutionContextGrantReconciling = UnavailableProjectExecutionContextGrantReconciler()) {
        self.root = root; self.configuration = configuration; self.provisioning = provisioning
        self.processObserver = processObserver; self.grantReconciler = grantReconciler
    }

    public func assignments(project: AuthorizedProject) throws -> [ProjectExecutionAssignment] {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.registration == project.registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.consent == ProjectExecutionPolicy.Consent() else { throw ProjectExecutionError.identityMismatch }
        return try ([project.projectID.rawValue] + (policy.previousProjectIDs ?? [])).flatMap { try store.assignments(projectID: $0) }
    }

    public func recoverLostWorker(project: AuthorizedProject, expected: ProjectExecutionAssignment,
                                  requestID: UUID,
                                  beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws
        -> ProjectExecutionAssignment {
        try await beforeWrite()
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        let paths = try ProjectExecutionPaths(storageRoot: store.root,
            projectID: project.projectID.rawValue, taskID: expected.id)
        let stored = try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id)
        if stored.lostWorkerRecovery?.requestID == requestID {
            guard policy.registration == project.registration,
                  policy.primaryRoot == project.canonicalRoot.path,
                  policy.consent == ProjectExecutionPolicy.Consent(),
                  stored.registration == project.registration,
                  stored.codexContextID == policy.codexContextID,
                  stored.role == .delivery, stored.work != nil,
                  stored.worktree?.primaryRoot == project.canonicalRoot.path,
                  stored.checkoutPath == paths.checkout.path else {
                throw ProjectExecutionError.identityMismatch
            }
            return try stored.validated()
        }
        guard policy.registration == project.registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.consent == ProjectExecutionPolicy.Consent(), expected.registration == project.registration,
              expected.codexContextID == policy.codexContextID,
              expected.role == .delivery, expected.work != nil,
              expected.worktree?.primaryRoot == project.canonicalRoot.path,
              expected.checkoutPath == expected.worktree?.checkout,
              expected.checkoutPath == paths.checkout.path,
              expected.retirement == nil, expected.lostWorkerRecovery == nil,
              [.authorized, .stopped, .unknown].contains(expected.state),
              expected.launchReserved == true, expected.connectionClosed != true,
              expected.sessionID?.isEmpty == false,
              stored == expected,
              let tree = expected.worktree else { throw ProjectExecutionError.assignmentNotAuthorized }

        _ = try processObserver.verifiedAbsence(for: expected)
        let candidateRevision = try provisioning.candidateRevision(worktree: tree)
        guard try store.policy(projectID: project.projectID.rawValue) == policy,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else {
            throw ProjectExecutionError.conflict
        }
        let grantDisposition = try grantReconciler.reconcileLostWorkerGrant(for: expected)
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else {
            throw ProjectExecutionError.conflict
        }
        let process = try processObserver.verifiedAbsence(for: expected)
        var recovered = expected
        recovered.state = .stopped
        recovered.connectionClosed = true
        recovered.uncertainOutcome = true
        recovered.lostWorkerRecovery = .init(requestID: requestID, priorState: expected.state,
            candidateRevision: candidateRevision, process: process, grantDisposition: grantDisposition)
        try recovered.validated()
        try store.saveAssignment(recovered, expected: expected)
        return recovered
    }

    func completeLostWorkerRecoveryAudit(project: AuthorizedProject,
                                         expected: ProjectExecutionAssignment,
                                         requestID: UUID,
                                         beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws
        -> ProjectExecutionAssignment {
        try await beforeWrite()
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        let paths = try ProjectExecutionPaths(storageRoot: store.root,
            projectID: project.projectID.rawValue, taskID: expected.id)
        let stored = try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id)
        guard policy.registration == project.registration,
              policy.primaryRoot == project.canonicalRoot.path,
              policy.consent == ProjectExecutionPolicy.Consent(),
              stored == expected,
              stored.registration == project.registration,
              stored.codexContextID == policy.codexContextID,
              stored.role == .delivery, stored.work != nil,
              stored.worktree?.primaryRoot == project.canonicalRoot.path,
              stored.checkoutPath == paths.checkout.path,
              var receipt = stored.lostWorkerRecovery,
              receipt.requestID == requestID else {
            throw ProjectExecutionError.identityMismatch
        }
        if receipt.auditCompleted == true { return try stored.validated() }
        try await beforeWrite()
        var completed = stored
        receipt.auditCompleted = true
        completed.lostWorkerRecovery = receipt
        try completed.validated()
        do {
            try store.saveAssignment(completed, expected: stored)
        } catch {
            guard let concurrent = try? store.assignment(
                projectID: project.projectID.rawValue, taskID: expected.id
            ), concurrent == completed else { throw error }
            return try concurrent.validated()
        }
        return completed
    }

    public func retire(project: AuthorizedProject, expected: ProjectExecutionAssignment, requestID: UUID,
                       beforeWrite: @escaping @Sendable () async throws -> Void = {}) async throws -> ProjectExecutionAssignment {
        try await beforeWrite()
        let control = try ProjectExecutionFileStore(root: root(), create: false)
        let ownerPolicy = try control.policy(projectID: project.projectID.rawValue)
        guard let resourcePath = expected.worktree?.primaryRoot,
              project.authorizedRoots.contains(where: { $0.path == resourcePath }) else { throw StoreError.unavailable("Restore access to this worker's exact original repository folder before retiring its resources. The old checkout and outcome were preserved.") }
        let resourceRoot = URL(fileURLWithPath: resourcePath)
        guard let ownerRegistration = project.registration, ownerPolicy.registration == ownerRegistration, ownerPolicy.primaryRoot == project.canonicalRoot.path,
              ownerPolicy.consent == ProjectExecutionPolicy.Consent(),
              expected.registration.projectID == project.projectID || ownerPolicy.previousProjectIDs?.contains(expected.registration.projectID.rawValue) == true else { throw ProjectExecutionError.identityMismatch }
        let resourcePolicy: ProjectExecutionPolicy
        if expected.registration.projectID == project.projectID { resourcePolicy = ownerPolicy }
        else { resourcePolicy = try control.policy(projectID: expected.registration.projectID.rawValue) }
        guard resourcePolicy.registration.projectID == expected.registration.projectID,
              resourcePolicy.registration.registrationID == expected.registration.registrationID,
              expected.registration.requestGeneration <= resourcePolicy.registration.requestGeneration,
              resourcePolicy.consent == ProjectExecutionPolicy.Consent(),
              expected.registration.projectID == project.projectID || !resourcePolicy.enabled else { throw ProjectExecutionError.identityMismatch }
        // The policy identifies the retained project incarnation. Exact stored
        // assignment, original folder grant, tree and pinned profile identify its
        // historical resources; a later binding never rewrites that ownership.
        let resourceProject = AuthorizedProject(registration: resourcePolicy.registration,
            canonicalRoot: resourceRoot, authorizedRoots: [resourceRoot])
        let validate: @Sendable () async throws -> Void = {
            try await beforeWrite()
            guard try control.policy(projectID: project.projectID.rawValue) == ownerPolicy,
                  try control.policy(projectID: expected.registration.projectID.rawValue) == resourcePolicy else { throw ProjectExecutionError.conflict }
        }
        return try await retireBound(project: resourceProject, expected: expected, requestID: requestID, beforeWrite: validate)
    }

    private func retireBound(project: AuthorizedProject, expected: ProjectExecutionAssignment, requestID: UUID,
                             beforeWrite: @escaping @Sendable () async throws -> Void) async throws -> ProjectExecutionAssignment {
        guard !retiring else { throw ProjectExecutionError.conflict }
        retiring = true; defer { retiring = false }
        var attemptedClose = false
        var previouslyPending = pendingClose != nil
        do {
            try await beforeWrite()
            var currentExpected = expected
            let ownsConnection = pendingClose.map { $0.projectID == project.projectID.rawValue && $0.assignmentID == expected.id && $0.requestID == requestID } ?? false
            guard pendingClose == nil || ownsConnection else { throw StoreError.unavailable("Resume the outstanding retirement request before retiring another assignment.") }
            if expected.retirement?.connectionCloseUncertain == true {
                if !ownsConnection {
                    return try await allowReplacementAfterHandleLoss(project: project, expected: expected, requestID: requestID, beforeWrite: beforeWrite)
                }
                let control = try ProjectExecutionFileStore(root: root(), create: false)
                guard expected.registration.projectID == project.projectID,
                      try control.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else { throw ProjectExecutionError.conflict }
                attemptedClose = true
                try await configuration.recoverConfigurationConnection()
                currentExpected = try recordConfirmedClose(projectID: project.projectID.rawValue, assignmentID: expected.id, requestID: requestID)
                attemptedClose = false
                previouslyPending = false
            }
            let result = try await retireOperation(project: project, expected: currentExpected, requestID: requestID, beforeWrite: beforeWrite)
            let store = try ProjectExecutionFileStore(root: root(), create: false)
            let policy = try store.policy(projectID: project.projectID.rawValue)
            attemptedClose = true
            try await configuration.finishConfiguration()
            let closed = try recordConfirmedClose(projectID: project.projectID.rawValue, assignmentID: result.id, requestID: requestID)
            try await beforeWrite()
            guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
            var retired = closed; retired.state = .superseded; retired.retirement?.completed = true
            try store.saveAssignment(retired, expected: closed)
            return retired // Replacement still requires fresh current-work admission.
        } catch {
            let failure = error
            if !attemptedClose, !previouslyPending, pendingClose == nil {
                do { try await configuration.finishConfiguration() }
                catch { throw StoreError.unavailable("Resource retirement failed: \(failure.localizedDescription). Context cleanup failed: \(error.localizedDescription). Preserve the original request.") }
            }
            if !attemptedClose, !previouslyPending, let pendingClose, pendingClose.projectID == project.projectID.rawValue,
               pendingClose.assignmentID == expected.id, pendingClose.requestID == requestID {
                do {
                    try await configuration.finishConfiguration()
                    _ = try recordConfirmedClose(projectID: project.projectID.rawValue, assignmentID: expected.id, requestID: requestID)
                } catch { throw StoreError.unavailable("Resource retirement failed: \(failure.localizedDescription). Connection cleanup also failed: \(error.localizedDescription). Resume the exact retirement request.") }
            }
            throw failure
        }
    }

    private func allowReplacementAfterHandleLoss(project: AuthorizedProject, expected: ProjectExecutionAssignment, requestID: UUID,
                                                beforeWrite: @escaping @Sendable () async throws -> Void) async throws -> ProjectExecutionAssignment {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.registration == project.registration, expected.worktree?.primaryRoot == project.canonicalRoot.path,
              expected.registration.projectID == project.projectID, expected.retirement?.requestID == requestID,
              expected.retirement?.worktreeRemoved == true,
              expected.connectionClosed == true || expected.state == .closed || expected.sessionID == nil && expected.launchReserved != true,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else {
            throw StoreError.unavailable("The original configuration connection is unavailable. Confirm exact owned worktree and profile cleanup, and close the old worker, before allowing replacement. Its cleanup outcome remains unresolved.")
        }
        let validate: @Sendable () async throws -> Void = {
            try await beforeWrite()
            guard try store.policy(projectID: project.projectID.rawValue) == policy,
                  try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else { throw ProjectExecutionError.conflict }
        }
        try await configuration.useCodexContext(expected.codexContextID)
        if expected.retirement?.profileRemoved != true {
            guard let definition = expected.permissionProfileDefinition else { throw ProjectExecutionError.unavailable }
            do {
                try await configuration.validateHandlerIdentity(handlerPath: policy.handlerPath)
                try await configuration.removeWorkerProfile(primaryRoot: project.canonicalRoot.path, profileID: expected.permissionProfile, expected: definition, beforeWrite: validate)
            } catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
            try await configuration.finishConfiguration() // Only this new configuration helper.
        }
        try await configuration.finishConfiguration() // Release this request's folder grant, never the lost original handle.
        try await validate()
        var recovered = expected; recovered.retirement?.profileRemoved = true; recovered.retirement?.replacementAllowed = true
        try store.saveAssignment(recovered, expected: expected)
        return recovered // Do not close a new client or claim that the old one closed.
    }

    private func recordConfirmedClose(projectID: String, assignmentID: String, requestID: UUID) throws -> ProjectExecutionAssignment {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let current = try store.assignment(projectID: projectID, taskID: assignmentID)
        guard current.retirement?.requestID == requestID else { throw ProjectExecutionError.conflict }
        var closed = current; closed.retirement?.connectionCloseUncertain = false
        try store.saveAssignment(closed, expected: current)
        pendingClose = nil
        return closed
    }

    private func retireOperation(project: AuthorizedProject, expected: ProjectExecutionAssignment, requestID: UUID,
                                 beforeWrite: @escaping @Sendable () async throws -> Void) async throws -> ProjectExecutionAssignment {
        try await beforeWrite()
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: expected.id)
        guard policy.registration == project.registration,
              policy.consent == ProjectExecutionPolicy.Consent(), expected.registration.projectID == policy.registration.projectID,
              expected.checkoutPath == paths.checkout.path,
              expected.connectionClosed == true || expected.state == .closed || expected.sessionID == nil && expected.launchReserved != true,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected,
              let tree = expected.worktree, tree.primaryRoot == project.canonicalRoot.path else { throw ProjectExecutionError.assignmentNotAuthorized }
        if let receipt = expected.retirement {
            guard receipt.requestID == requestID else { throw ProjectExecutionError.conflict }
            if receipt.completed { return expected }
        }
        let inventory = try store.assignments(projectID: project.projectID.rawValue)
        guard !inventory.contains(where: {
            $0.id != expected.id && ($0.reviewOfAssignmentID == expected.id || $0.baselineFromAssignmentID == expected.id)
                && $0.retirement?.completed != true
        }) else { throw StoreError.unavailable("Another assignment still references this candidate. Retire its dependent resources first; the checkout was preserved.") }
        let definition: Data
        if let recorded = expected.permissionProfileDefinition { definition = recorded }
        else {
            guard tree.primaryRoot == policy.primaryRoot else { throw StoreError.unavailable("The original permission profile definition is unavailable. Preserve the old resources and resolve their ownership before retirement.") }
            definition = try ProjectExecutionPermissionProfile(assignment: expected, policy: policy, paths: paths).definition
        }
        try await configuration.useCodexContext(expected.codexContextID)
        try await configuration.validateHandlerIdentity(handlerPath: policy.handlerPath)
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else { throw ProjectExecutionError.conflict }
        var current = expected
        if current.retirement == nil {
            current.retirement = .init(requestID: requestID, priorState: expected.state)
            current.permissionProfileDefinition = definition
            if [.authorized, .preparing, .closed].contains(current.state) { current.state = .revoked }
            try store.saveAssignment(current, expected: expected)
        }
        // Prune only the exact clean owned checkout; libgit2 retains its branch
        // and committed history. A dirty checkout prevents any profile mutation.
        if current.retirement?.worktreeRemoved != true {
            try await configuration.useCodexContext(expected.codexContextID)
            guard try !store.assignments(projectID: project.projectID.rawValue).contains(where: {
                $0.id != current.id && ($0.reviewOfAssignmentID == current.id || $0.baselineFromAssignmentID == current.id) && $0.retirement?.completed != true
            }) else { throw ProjectExecutionError.conflict }
            try provisioning.remove(primaryRoot: project.canonicalRoot, worktree: tree, projectID: project.projectID.rawValue, taskID: current.id)
            var removed = current; removed.retirement?.worktreeRemoved = true
            try store.saveAssignment(removed, expected: current); current = removed
        }
        if current.retirement?.profileRemoved != true {
            try await configuration.useCodexContext(expected.codexContextID)
            try await beforeWrite()
            guard try store.policy(projectID: project.projectID.rawValue) == policy,
                  try store.assignment(projectID: project.projectID.rawValue, taskID: current.id) == current else { throw ProjectExecutionError.conflict }
            var outstanding = current; outstanding.retirement?.connectionCloseUncertain = true
            try store.saveAssignment(outstanding, expected: current); current = outstanding
            pendingClose = (project.projectID.rawValue, current.id, requestID)
            let writeAssignment = current
            let validateProfileMutation: @Sendable () async throws -> Void = {
                try await beforeWrite()
                guard try store.policy(projectID: project.projectID.rawValue) == policy,
                      try store.assignment(projectID: project.projectID.rawValue, taskID: writeAssignment.id) == writeAssignment else { throw ProjectExecutionError.conflict }
            }
            try await configuration.removeWorkerProfile(primaryRoot: project.canonicalRoot.path, profileID: current.permissionProfile, expected: definition, beforeWrite: validateProfileMutation)
            try await beforeWrite()
            var removed = current; removed.retirement?.profileRemoved = true
            try store.saveAssignment(removed, expected: current); current = removed
        }
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        return current // Keep the receipt visible and replacement blocked until confirmed close.
    }
}
