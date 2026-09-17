import Foundation

/// Current app-owned work identity captured before preparing any worker paths.
public struct ProjectExecutionWork: Codable, Equatable, Sendable {
    public let projectID: ProjectID
    public let ticketID: String
    public let taskID: String
    public let outcome: String
    public let title: String
    public let taskPlanRevision: Int64
    public let phaseID: String
    public let phaseRevision: Int64
    public let incarnationID: String?

    static func read(projectID: ProjectID, ticketID: String, taskID: String,
                     taskPlanRevision: Int64, phaseRevision: Int64, connection c: SQLiteConnection) throws -> Self {
        guard let row = try c.row("""
            SELECT t.outcome,t.phase_id,t.lane,k.title,k.completion,k.lifecycle,p.revision
            FROM tickets t JOIN ticket_tasks k ON k.project_id=t.project_id AND k.ticket_id=t.id
            JOIN ticket_task_plans p ON p.project_id=t.project_id AND p.ticket_id=t.id
            WHERE t.project_id=? AND t.id=? AND k.id=?
            """, bindings: [.text(projectID.rawValue), .text(ticketID), .text(taskID)]),
              case let .text(outcome)? = row["outcome"], case let .text(title)? = row["title"],
              case let .text(phase)? = row["phase_id"], case let .text(lane)? = row["lane"],
              [TicketLane.backlog.rawValue, TicketLane.inProgress.rawValue, TicketLane.needsReview.rawValue].contains(lane),
              row["lifecycle"] == .text(TicketTaskLifecycle.active.rawValue),
              row["completion"] == .text(TicketTaskCompletion.pending.rawValue),
              row["revision"] == .integer(taskPlanRevision) else { throw ProjectExecutionError.assignmentNotAuthorized }
        let lifecycle = try PhaseLifecyclePolicy.current(projectID: projectID, phaseID: .init(rawValue: phase), connection: c)
        guard lifecycle.lifecycle == .inDelivery, lifecycle.revision == phaseRevision else { throw ProjectExecutionError.assignmentNotAuthorized }
        return .init(projectID: projectID, ticketID: ticketID, taskID: taskID, outcome: outcome, title: title,
                     taskPlanRevision: taskPlanRevision, phaseID: phase, phaseRevision: phaseRevision,
                     incarnationID: try c.scalarText("SELECT incarnation_id FROM application_recovery_state WHERE singleton_id=1"))
    }

    public init(projectID: ProjectID, ticketID: String, taskID: String, outcome: String, title: String,
                taskPlanRevision: Int64, phaseID: String, phaseRevision: Int64, incarnationID: String? = nil) {
        self.projectID = projectID; self.ticketID = ticketID; self.taskID = taskID
        self.outcome = outcome; self.title = title; self.taskPlanRevision = taskPlanRevision
        self.phaseID = phaseID; self.phaseRevision = phaseRevision
        self.incarnationID = incarnationID
    }
}

public protocol ProjectExecutionAssignmentPreparing: Sendable {
    func admitPrepared(_ assignment: ProjectExecutionAssignment) throws -> ProjectExecutionAssignment
    func revokePreparation(_ assignment: ProjectExecutionAssignment) throws
    func readCurrent(project: AuthorizedProject, assignmentID: String) async throws -> ProjectExecutionAssignment
    func prepare(project: AuthorizedProject, work: ProjectExecutionWork, requestID: UUID,
                 reviewOfAssignmentID: String?, baselineFromAssignmentID: String?, contextPaths: [String]) async throws -> ProjectExecutionAssignment
}
