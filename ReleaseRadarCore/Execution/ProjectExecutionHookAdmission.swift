import Foundation

public enum ProjectExecutionHookAdmission {
    /// Outside owned storage means an ordinary native/manual session. Inside it,
    /// only the exact project/task checkout is admissible; no repository marker
    /// or caller-asserted role can identify a Release Radar worker.
    public static func resolve(store: ProjectExecutionFileStore, checkout: URL, sessionID: String) throws -> ProjectExecutionAssignment? {
        let prefix = store.root.appendingPathComponent("Worktrees").path + "/"
        guard checkout.path.hasPrefix(prefix) else { return nil }
        let parts = checkout.path.dropFirst(prefix.count).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, checkout.standardizedFileURL.path == checkout.path,
              checkout.resolvingSymlinksInPath().path == checkout.path else { throw ProjectExecutionError.identityMismatch }
        let project = try ProjectExecutionPaths.component(String(parts[0]))
        let task = try ProjectExecutionPaths.component(String(parts[1]))
        let policy = try store.policy(projectID: project)
        let assignment = try store.assignment(projectID: project, taskID: task)
        guard policy.version == 1, policy.enabled, policy.consent == ProjectExecutionPolicy.Consent(),
              policy.hookReceipt?.installed == true,
              policy.hookReceipt?.command == "\"" + policy.handlerPath + "\" --hook" else { throw ProjectExecutionError.assignmentNotAuthorized }
        try assignment.admit(registration: policy.registration, checkoutPath: checkout.path,
                             sessionID: sessionID, boundSessionID: assignment.sessionID)
        try assignment.verifyContext()
        guard try store.policy(projectID: project) == policy,
              try store.assignment(projectID: project, taskID: task) == assignment else { throw ProjectExecutionError.assignmentNotAuthorized }
        return assignment
    }
}
