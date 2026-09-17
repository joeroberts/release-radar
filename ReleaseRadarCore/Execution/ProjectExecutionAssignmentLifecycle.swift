import Darwin
import Foundation

/// App store transactions invalidate obsolete leases before committing changed
/// work. Revocation may survive a later SQL rollback; it can never authorize work.
enum ProjectExecutionAssignmentLifecycle {
    static func reconcile(root: URL, projectIDs: [ProjectID], connection: SQLiteConnection) throws {
        var metadata = stat()
        if lstat(root.path, &metadata) != 0 {
            if errno == ENOENT { return }
            throw ProjectExecutionError.unavailable
        }
        let assignments = try ProjectExecutionFileStore(root: root, create: false)
        for projectID in projectIDs {
            let policy = try assignments.policyIfPresent(projectID: projectID.rawValue)
            for value in try assignments.assignments(projectID: projectID.rawValue) {
                guard [.authorized, .preparing, .unknown].contains(value.state), let work = value.work else { continue }
                let current: ProjectExecutionWork?
                do {
                    try ProjectLifecycleManager.requireCurrentAuthorization(projectID: projectID, registration: value.registration, connection: connection)
                    guard let policy, policy.enabled, policy.registration == value.registration,
                          try connection.scalarInt("SELECT COUNT(*) FROM project_roots r JOIN project_bookmarks b ON b.project_id=r.project_id AND b.path=r.path WHERE r.project_id=? AND r.path=? AND b.is_stale=0",
                            bindings: [.text(projectID.rawValue), .text(policy.primaryRoot)]) == 1 else { throw ProjectExecutionError.assignmentNotAuthorized }
                    current = try ProjectExecutionWork.read(projectID: projectID, ticketID: work.ticketID, taskID: work.taskID,
                        taskPlanRevision: work.taskPlanRevision, phaseRevision: work.phaseRevision, connection: connection)
                } catch let error as ProjectExecutionError {
                    guard error == .assignmentNotAuthorized else { throw error }; current = nil
                } catch is ProjectLifecycleError { current = nil }
                if current != work {
                    var revoked = value; revoked.state = .revoked
                    if value.state == .unknown || value.sessionID != nil { revoked.launchReserved = true }
                    if value.state == .unknown { revoked.uncertainOutcome = true }
                    try assignments.saveAssignment(revoked, expected: value)
                }
            }
        }
    }
}
