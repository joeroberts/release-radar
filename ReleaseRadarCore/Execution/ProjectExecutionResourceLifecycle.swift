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
        return try ([project.projectID.rawValue] + (policy.previousProjectIDs ?? [])).flatMap { try store.assignments(projectID: $0) }
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
        if expected.retirement?.profileRemoved != true {
            guard let definition = expected.permissionProfileDefinition else { throw ProjectExecutionError.unavailable }
            do {
                try await configuration.validateHandlerIdentity(handlerPath: policy.handlerPath)
                try await configuration.removeWorkerProfile(primaryRoot: project.canonicalRoot.path, profileID: expected.permissionProfile, expected: definition, beforeWrite: validate)
            } catch { let failure = error; try await configuration.finishConfiguration(); throw failure }
            try await configuration.finishConfiguration() // Only this new configuration helper.
        }
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
