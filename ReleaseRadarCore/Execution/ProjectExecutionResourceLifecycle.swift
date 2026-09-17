import Foundation

/// Owner-only resource retirement. It never completes work or launches a worker.
public actor ProjectExecutionResourceLifecycle {
    private let root: @Sendable () throws -> URL
    private let configuration: any ProjectExecutionConfiguring
    private let provisioning: any ExecutionWorktreeProvisioning
    private var retiring = false
    private var pendingClose: (projectID: String, assignmentID: String, requestID: UUID)?

    public init(root: @escaping @Sendable () throws -> URL = ProjectExecutionFileStore.applicationRoot,
                configuration: any ProjectExecutionConfiguring,
                provisioning: any ExecutionWorktreeProvisioning = LibGit2WorktreeProvisioner()) {
        self.root = root; self.configuration = configuration; self.provisioning = provisioning
    }

    public func assignments(project: AuthorizedProject) throws -> [ProjectExecutionAssignment] {
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.registration == project.registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.consent == ProjectExecutionPolicy.Consent() else { throw ProjectExecutionError.identityMismatch }
        return try store.assignments(projectID: project.projectID.rawValue).filter { $0.registration == policy.registration }
    }

    public func retire(project: AuthorizedProject, expected: ProjectExecutionAssignment, requestID: UUID,
                       beforeWrite: @Sendable () async throws -> Void = {}) async throws -> ProjectExecutionAssignment {
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
                guard ownsConnection else { throw StoreError.unavailable("The original configuration connection is unavailable. Retirement remains incomplete; do not replace this assignment or infer closure from a new client.") }
                let control = try ProjectExecutionFileStore(root: root(), create: false)
                guard expected.registration == project.registration,
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
                                 beforeWrite: @Sendable () async throws -> Void) async throws -> ProjectExecutionAssignment {
        try await beforeWrite()
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: expected.id)
        guard policy.registration == project.registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.consent == ProjectExecutionPolicy.Consent(), expected.registration == policy.registration,
              expected.checkoutPath == paths.checkout.path,
              expected.connectionClosed == true || expected.state == .closed || expected.sessionID == nil && expected.launchReserved != true,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected,
              let tree = expected.worktree, tree.primaryRoot == policy.primaryRoot else { throw ProjectExecutionError.assignmentNotAuthorized }
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
        else { definition = try ProjectExecutionPermissionProfile(assignment: expected, policy: policy, paths: paths).definition }
        try await configuration.validateHandlerIdentity(handlerPath: policy.handlerPath)
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy,
              try store.assignment(projectID: project.projectID.rawValue, taskID: expected.id) == expected else { throw ProjectExecutionError.conflict }
        var current = expected
        if current.retirement == nil {
            current.retirement = .init(requestID: requestID, priorState: expected.state)
            if [.authorized, .preparing, .closed].contains(current.state) { current.state = .revoked }
            try store.saveAssignment(current, expected: expected)
        }
        // Prune only the exact clean owned checkout; libgit2 retains its branch
        // and committed history. A dirty checkout prevents any profile mutation.
        if current.retirement?.worktreeRemoved != true {
            guard try !store.assignments(projectID: project.projectID.rawValue).contains(where: {
                $0.id != current.id && ($0.reviewOfAssignmentID == current.id || $0.baselineFromAssignmentID == current.id) && $0.retirement?.completed != true
            }) else { throw ProjectExecutionError.conflict }
            try provisioning.remove(primaryRoot: project.canonicalRoot, worktree: tree, projectID: project.projectID.rawValue, taskID: current.id)
            var removed = current; removed.retirement?.worktreeRemoved = true
            try store.saveAssignment(removed, expected: current); current = removed
        }
        if current.retirement?.profileRemoved != true {
            try await beforeWrite()
            guard try store.policy(projectID: project.projectID.rawValue) == policy,
                  try store.assignment(projectID: project.projectID.rawValue, taskID: current.id) == current else { throw ProjectExecutionError.conflict }
            var outstanding = current; outstanding.retirement?.connectionCloseUncertain = true
            try store.saveAssignment(outstanding, expected: current); current = outstanding
            pendingClose = (project.projectID.rawValue, current.id, requestID)
            try await configuration.removeWorkerProfile(primaryRoot: policy.primaryRoot, profileID: current.permissionProfile, expected: definition)
            try await beforeWrite()
            var removed = current; removed.retirement?.profileRemoved = true
            try store.saveAssignment(removed, expected: current); current = removed
        }
        try await beforeWrite()
        guard try store.policy(projectID: project.projectID.rawValue) == policy else { throw ProjectExecutionError.conflict }
        return current // Keep the receipt visible and replacement blocked until confirmed close.
    }
}
