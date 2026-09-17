import CryptoKit
import Foundation

/// One app-owned producer. Work and context come from the registered command
/// route; public callers cannot choose a filesystem ceiling or authorize a prompt.
public actor ProjectExecutionAssignmentCoordinator: ProjectExecutionAssignmentPreparing {
    private let root: @Sendable () throws -> URL
    private let configuration: any ProjectExecutionConfiguring
    private let provisioning: any ExecutionWorktreeProvisioning
    private let handlerPath: String
    private var preparing: Set<String> = []

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
        guard policy.registration == project.registration, policy.enabled, policy.consent == ProjectExecutionPolicy.Consent(),
              value.registration == project.registration, value.checkoutPath == paths.checkout.path else { throw ProjectExecutionError.assignmentNotAuthorized }
        return value
    }

    public func prepare(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                        reviewOfAssignmentID: String?, baselineFromAssignmentID: String?, contextPaths: [String]) async throws -> ProjectExecutionAssignment {
        let key = work.projectID.rawValue + "/" + work.ticketID + "/" + work.taskID
        guard preparing.insert(key).inserted else { throw ProjectExecutionError.conflict }
        defer { preparing.remove(key) }
        do {
            let result = try await prepareOperation(project: project, work: work, requestID: requestID,
                reviewOfAssignmentID: reviewOfAssignmentID, baselineFromAssignmentID: baselineFromAssignmentID, contextPaths: contextPaths)
            try await configuration.finishConfiguration()
            return result
        } catch {
            let failure = error; try await configuration.finishConfiguration(); throw failure
        }
    }

    private func prepareOperation(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                                  reviewOfAssignmentID: String?, baselineFromAssignmentID: String?, contextPaths: [String]) async throws -> ProjectExecutionAssignment {
        guard let registration = project.registration, work.projectID == project.projectID,
              reviewOfAssignmentID == nil || baselineFromAssignmentID == nil,
              !contextPaths.isEmpty, contextPaths.count <= 64, Set(contextPaths).count == contextPaths.count else { throw ProjectExecutionError.invalidAssignment }
        let store = try ProjectExecutionFileStore(root: root(), create: false)
        let policy = try store.policy(projectID: project.projectID.rawValue)
        guard policy.version == 1, policy.registration == registration, policy.primaryRoot == project.canonicalRoot.path,
              policy.handlerPath == handlerPath, policy.appServerExecutable == CodexExecutionIdentity.executable,
              policy.enabled, policy.consent == ProjectExecutionPolicy.Consent(), policy.hookReceipt?.installed == true,
              policy.hookReceipt?.command == "\"" + handlerPath + "\" --hook" else { throw ProjectExecutionError.assignmentNotAuthorized }
        try await configuration.validateInstallation(handlerPath: handlerPath)
        let role: ProjectExecutionAssignment.Role = reviewOfAssignmentID == nil ? .delivery : .review
        let id = role.rawValue + "-" + requestID.uuidString.lowercased()
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: id)
        let inventory = try store.assignments(projectID: project.projectID.rawValue)
        if let existing = inventory.first(where: { $0.id == id }) {
            guard existing.work == work, existing.registration == registration, existing.role == role,
                  existing.reviewOfAssignmentID == reviewOfAssignmentID, existing.baselineFromAssignmentID == baselineFromAssignmentID,
                  existing.state == .authorized || existing.state == .preparing else { throw ProjectExecutionError.assignmentNotAuthorized }
            try existing.verifyContext()
            if existing.state == .authorized { return existing }
            guard let tree = existing.worktree, try provisioning.candidateRevision(worktree: tree) == tree.baseline else { throw ProjectExecutionError.identityMismatch }
            return try await configure(existing, paths: paths, policy: policy, store: store)
        }
        // Another request identity cannot silently replace an uncertain/live worker.
        guard !inventory.contains(where: {
            $0.registration == registration && $0.work?.ticketID == work.ticketID && $0.work?.taskID == work.taskID && $0.role == role
                && ($0.state == .authorized || $0.state == .preparing || $0.state == .unknown || $0.state == .stopped)
        }) else { throw ProjectExecutionError.conflict }
        let source: URL
        let baseline: String
        if let parentID = reviewOfAssignmentID ?? baselineFromAssignmentID {
            let parent = try store.assignment(projectID: project.projectID.rawValue, taskID: parentID)
            let parentPaths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: parentID)
            guard parent.registration == registration, parent.work == work, parent.state == .closed, parent.sessionID != nil,
                  parent.checkoutPath == parentPaths.checkout.path, let tree = parent.worktree,
                  tree.primaryRoot == policy.primaryRoot, reviewOfAssignmentID == nil || parent.role == .delivery else { throw ProjectExecutionError.assignmentNotAuthorized }
            baseline = try provisioning.candidateRevision(worktree: tree)
            if parent.role == .review, baseline != tree.baseline { throw ProjectExecutionError.identityMismatch }
            source = parentPaths.checkout
        } else {
            // First assignment records the verified selected repository's committed
            // baseline; unrelated dirty primary files are never copied into it.
            baseline = try provisioning.revision(at: project.canonicalRoot, requireClean: false)
            source = project.canonicalRoot
        }
        let reader = try RepositoryDocumentReader(rootURL: source, limits: .init(maximumFileBytes: 16 * 1_048_576), afterRead: nil)
        let contexts = try contextPaths.map { path -> ProjectExecutionAssignment.Context in
            let bytes = try reader.read(path)
            return .init(path: path, digest: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
        }
        let tree = try provisioning.prepare(primaryRoot: project.canonicalRoot, checkout: paths.checkout,
            projectID: project.projectID.rawValue, taskID: id, baseline: baseline)
        let authorization = "Project onboarding authorizes the recorded bounded work \(work.ticketID)/\(work.taskID): \(work.outcome). Task: \(work.title)."
        var assignment = ProjectExecutionAssignment(id: id, registration: registration, checkoutPath: paths.checkout.path, role: role,
            permissionProfile: "rr-" + id, model: "gpt-5.6-terra", effort: role == .review ? "high" : "medium",
            authorization: authorization, context: contexts,
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive", tree.commonGitDirectory, policy.primaryRoot],
            worktree: tree, work: work, reviewOfAssignmentID: reviewOfAssignmentID, baselineFromAssignmentID: baselineFromAssignmentID)
        try assignment.verifyContext() // Pins must match committed checkout, not dirty primary edits.
        try reader.verifyStable()
        assignment.state = .preparing
        try store.saveAssignment(assignment, expected: nil)
        return try await configure(assignment, paths: paths, policy: policy, store: store)
    }

    private func configure(_ intent: ProjectExecutionAssignment, paths: ProjectExecutionPaths,
                           policy: ProjectExecutionPolicy, store: ProjectExecutionFileStore) async throws -> ProjectExecutionAssignment {
        let assignment = intent
        let profile = try ProjectExecutionPermissionProfile(assignment: assignment, policy: policy, paths: paths)
        try await configuration.prepareWorkerProfile(primaryRoot: policy.primaryRoot, profile: profile)
        try await configuration.verifyHook(primaryRoot: policy.primaryRoot, checkout: paths.checkout.path,
            command: "\"" + handlerPath + "\" --hook", permitOwnedTrust: false)
        try assignment.verifyContext()
        if let parentID = assignment.reviewOfAssignmentID ?? assignment.baselineFromAssignmentID {
            let parent = try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: parentID)
            guard parent.state == .closed, parent.registration == assignment.registration, parent.work == assignment.work,
                  let tree = parent.worktree, try provisioning.candidateRevision(worktree: tree) == assignment.worktree?.baseline else { throw ProjectExecutionError.assignmentNotAuthorized }
        }
        guard try store.policy(projectID: assignment.registration.projectID.rawValue) == policy else { throw ProjectExecutionError.assignmentNotAuthorized }
        var authorized = assignment; authorized.state = .authorized
        try store.saveAssignment(authorized, expected: assignment)
        return authorized
    }
}
