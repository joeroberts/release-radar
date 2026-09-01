import Foundation

public enum InvalidTicketTaskMutationReason: Equatable, Sendable {
    case ticketNotFound
    case acceptedTicket
    case emptyOperationSet
    case invalidCreationOperations
    case operationLimitExceeded(actual: Int, maximum: Int)
    case duplicateOperationTaskID(TicketTaskID)
    case invalidTaskID(TicketTaskID)
    case invalidLabel(taskID: TicketTaskID)
    case invalidTitle(taskID: TicketTaskID)
    case invalidSortOrder(taskID: TicketTaskID)
    case emptyDefinitionRevision(TicketTaskID)
    case noEffectiveDefinitionRevision(TicketTaskID)
    case taskIDAlreadyUsed(TicketTaskID)
    case labelAlreadyUsed(String)
    case revisionExhausted
}

public enum TicketTaskPlanningPolicyError: Error, LocalizedError, Equatable, Sendable {
    case ticketTaskPlanNotFound
    case ticketTaskPlanAlreadyExists
    case ticketTaskPlanRevisionConflict(expected: Int64?, current: Int64)
    case ticketTaskNotFound(TicketTaskID)
    case ticketTaskImmutable(TicketTaskID)
    case ticketTaskIncomplete(pendingTaskIDs: [TicketTaskID])
    case ticketTaskReplacementRequired
    case invalidTicketTaskMutation(InvalidTicketTaskMutationReason)

    public var errorDescription: String? {
        switch self {
        case .ticketTaskPlanNotFound:
            "The ticket task plan does not exist. Refresh the ticket before retrying."
        case .ticketTaskPlanAlreadyExists:
            "The ticket already has a task plan. Refresh and submit a revision instead."
        case .ticketTaskPlanRevisionConflict:
            "The ticket task plan changed. Refresh it before retrying."
        case .ticketTaskNotFound:
            "A targeted ticket task does not exist. Refresh the plan before retrying."
        case .ticketTaskImmutable:
            "A targeted ticket task is immutable and cannot perform this operation."
        case .ticketTaskIncomplete:
            "Complete every active ticket task before accepting the ticket."
        case .ticketTaskReplacementRequired:
            "A task plan must retain at least one active task. Add a replacement in the same revision."
        case .invalidTicketTaskMutation:
            "The ticket task change is invalid. Correct the request and retry."
        }
    }
}

public enum TicketTaskPlanningPolicy {
    public static let maximumOperationsPerRevision = 64
    public static let maximumTaskIDUTF8Bytes = 256
    public static let maximumTaskLabelUTF8Bytes = 256
    public static let maximumTaskTitleUTF8Bytes = 4_096

    public static func revisePlan(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedRevision: Int64?,
        additions: [TicketTaskDraft],
        definitionRevisions: [TicketTaskDefinitionRevision],
        supersededTaskIDs: [TicketTaskID],
        connection: SQLiteConnection
    ) throws -> TicketTaskPlanRecord {
        try validateOwnerIdentities(projectID: projectID, ticketID: ticketID)
        try requireMutableTicket(projectID: projectID, ticketID: ticketID, connection: connection)

        let operationCount = additions.count + definitionRevisions.count + supersededTaskIDs.count
        guard operationCount > 0 else {
            throw invalid(.emptyOperationSet)
        }
        guard operationCount <= maximumOperationsPerRevision else {
            throw invalid(.operationLimitExceeded(actual: operationCount, maximum: maximumOperationsPerRevision))
        }
        try validateOperationIdentities(
            additions: additions,
            definitionRevisions: definitionRevisions,
            supersededTaskIDs: supersededTaskIDs
        )
        try validateAdditionLabelsAreDistinct(additions)
        try additions.forEach(validateAddition)
        try definitionRevisions.forEach(validateDefinitionRevision)
        try supersededTaskIDs.forEach(validateTaskID)

        let currentPlan = try loadPlan(projectID: projectID, ticketID: ticketID, connection: connection)
        if expectedRevision == nil {
            guard currentPlan == nil else {
                throw TicketTaskPlanningPolicyError.ticketTaskPlanAlreadyExists
            }
            guard !additions.isEmpty, definitionRevisions.isEmpty, supersededTaskIDs.isEmpty else {
                throw invalid(.invalidCreationOperations)
            }
            try validateHistoricalReuse(
                projectID: projectID,
                ticketID: ticketID,
                additions: additions,
                connection: connection
            )
            let timestamp = operationTimestamp()
            try connection.execute(
                """
                INSERT INTO ticket_task_plans
                    (project_id, ticket_id, revision, created_at, updated_at)
                VALUES (?, ?, 1, ?, ?)
                """,
                bindings: [
                    .text(projectID.rawValue), .text(ticketID.rawValue),
                    .text(timestamp), .text(timestamp),
                ]
            )
            for addition in additions {
                try insert(addition, projectID: projectID, ticketID: ticketID, timestamp: timestamp, connection: connection)
            }
            return try requirePlan(projectID: projectID, ticketID: ticketID, connection: connection)
        }

        guard let currentPlan else {
            throw TicketTaskPlanningPolicyError.ticketTaskPlanNotFound
        }
        guard currentPlan.revision == expectedRevision else {
            throw TicketTaskPlanningPolicyError.ticketTaskPlanRevisionConflict(
                expected: expectedRevision,
                current: currentPlan.revision
            )
        }
        try requireRevisionAdvance(currentPlan.revision)
        try validateHistoricalReuse(
            projectID: projectID,
            ticketID: ticketID,
            additions: additions,
            connection: connection
        )

        var revisedTasks: [(revision: TicketTaskDefinitionRevision, task: TaskState)] = []
        for revision in definitionRevisions {
            guard let task = try loadTask(
                projectID: projectID,
                ticketID: ticketID,
                taskID: revision.id,
                connection: connection
            ) else {
                throw TicketTaskPlanningPolicyError.ticketTaskNotFound(revision.id)
            }
            guard task.lifecycle == .active, task.completion == .pending else {
                throw TicketTaskPlanningPolicyError.ticketTaskImmutable(revision.id)
            }
            let resultingTitle = revision.title ?? task.title
            let resultingSortOrder = revision.sortOrder ?? task.sortOrder
            guard resultingTitle != task.title || resultingSortOrder != task.sortOrder else {
                throw invalid(.noEffectiveDefinitionRevision(revision.id))
            }
            revisedTasks.append((revision, task))
        }

        var supersededTasks: [TaskState] = []
        for taskID in supersededTaskIDs {
            guard let task = try loadTask(
                projectID: projectID,
                ticketID: ticketID,
                taskID: taskID,
                connection: connection
            ) else {
                throw TicketTaskPlanningPolicyError.ticketTaskNotFound(taskID)
            }
            guard task.lifecycle == .active else {
                throw TicketTaskPlanningPolicyError.ticketTaskImmutable(taskID)
            }
            supersededTasks.append(task)
        }

        let timestamp = operationTimestamp()
        for addition in additions {
            try insert(addition, projectID: projectID, ticketID: ticketID, timestamp: timestamp, connection: connection)
        }
        for pair in revisedTasks {
            try connection.execute(
                """
                UPDATE ticket_tasks
                SET title = ?, sort_order = ?, updated_at = ?
                WHERE project_id = ? AND ticket_id = ? AND id = ?
                  AND completion = 'pending' AND lifecycle = 'active'
                """,
                bindings: [
                    .text(pair.revision.title ?? pair.task.title),
                    .integer(Int64(pair.revision.sortOrder ?? pair.task.sortOrder)),
                    .text(timestamp), .text(projectID.rawValue), .text(ticketID.rawValue),
                    .text(pair.task.id.rawValue),
                ]
            )
            try requireOneChangedRow(connection)
        }
        for task in supersededTasks {
            try connection.execute(
                """
                UPDATE ticket_tasks
                SET lifecycle = 'superseded', superseded_at = ?, updated_at = ?
                WHERE project_id = ? AND ticket_id = ? AND id = ? AND lifecycle = 'active'
                """,
                bindings: [
                    .text(timestamp), .text(timestamp), .text(projectID.rawValue),
                    .text(ticketID.rawValue), .text(task.id.rawValue),
                ]
            )
            try requireOneChangedRow(connection)
        }

        let activeCount = try connection.scalarInt(
            "SELECT COUNT(*) FROM ticket_tasks WHERE project_id = ? AND ticket_id = ? AND lifecycle = 'active'",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ) ?? 0
        guard activeCount > 0 else {
            throw TicketTaskPlanningPolicyError.ticketTaskReplacementRequired
        }

        try advancePlan(
            projectID: projectID,
            ticketID: ticketID,
            expectedRevision: currentPlan.revision,
            timestamp: timestamp,
            connection: connection
        )
        return try requirePlan(projectID: projectID, ticketID: ticketID, connection: connection)
    }

    public static func completeTask(
        projectID: ProjectID,
        ticketID: TicketID,
        taskID: TicketTaskID,
        expectedRevision: Int64,
        connection: SQLiteConnection
    ) throws -> TicketTaskPlanRecord {
        try validateOwnerIdentities(projectID: projectID, ticketID: ticketID)
        try requireMutableTicket(projectID: projectID, ticketID: ticketID, connection: connection)
        guard let currentPlan = try loadPlan(projectID: projectID, ticketID: ticketID, connection: connection) else {
            throw TicketTaskPlanningPolicyError.ticketTaskPlanNotFound
        }
        guard currentPlan.revision == expectedRevision else {
            throw TicketTaskPlanningPolicyError.ticketTaskPlanRevisionConflict(
                expected: expectedRevision,
                current: currentPlan.revision
            )
        }
        try requireRevisionAdvance(currentPlan.revision)
        try validateTaskID(taskID)
        guard let task = try loadTask(
            projectID: projectID,
            ticketID: ticketID,
            taskID: taskID,
            connection: connection
        ) else {
            throw TicketTaskPlanningPolicyError.ticketTaskNotFound(taskID)
        }
        guard task.lifecycle == .active, task.completion == .pending else {
            throw TicketTaskPlanningPolicyError.ticketTaskImmutable(taskID)
        }

        let timestamp = operationTimestamp()
        try connection.execute(
            """
            UPDATE ticket_tasks
            SET completion = 'completed', completed_at = ?, updated_at = ?
            WHERE project_id = ? AND ticket_id = ? AND id = ?
              AND completion = 'pending' AND lifecycle = 'active'
            """,
            bindings: [
                .text(timestamp), .text(timestamp), .text(projectID.rawValue),
                .text(ticketID.rawValue), .text(taskID.rawValue),
            ]
        )
        try requireOneChangedRow(connection)
        try advancePlan(
            projectID: projectID,
            ticketID: ticketID,
            expectedRevision: currentPlan.revision,
            timestamp: timestamp,
            connection: connection
        )
        return try requirePlan(projectID: projectID, ticketID: ticketID, connection: connection)
    }

    public static func assertCanAcceptTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedRevision: Int64?,
        connection: SQLiteConnection
    ) throws {
        try validateOwnerIdentities(projectID: projectID, ticketID: ticketID)
        try requireMutableTicket(projectID: projectID, ticketID: ticketID, connection: connection)
        guard let plan = try loadPlan(projectID: projectID, ticketID: ticketID, connection: connection) else {
            guard expectedRevision == nil else {
                throw TicketTaskPlanningPolicyError.ticketTaskPlanNotFound
            }
            return
        }
        guard expectedRevision == plan.revision else {
            throw TicketTaskPlanningPolicyError.ticketTaskPlanRevisionConflict(
                expected: expectedRevision,
                current: plan.revision
            )
        }

        var pendingIDs: [TicketTaskID] = []
        var offset: Int64 = 0
        while let row = try connection.row(
            """
            SELECT id FROM ticket_tasks
            WHERE project_id = ? AND ticket_id = ?
              AND lifecycle = 'active' AND completion = 'pending'
            ORDER BY sort_order, label COLLATE BINARY, id COLLATE BINARY
            LIMIT 1 OFFSET ?
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .integer(offset)]
        ) {
            guard case let .text(id)? = row["id"] else {
                throw invalidRow("Invalid pending ticket task row")
            }
            pendingIDs.append(.init(rawValue: id))
            offset += 1
        }
        guard pendingIDs.isEmpty else {
            throw TicketTaskPlanningPolicyError.ticketTaskIncomplete(pendingTaskIDs: pendingIDs)
        }
    }

    private struct TaskState {
        let id: TicketTaskID
        let title: String
        let sortOrder: Int
        let completion: TicketTaskCompletion
        let lifecycle: TicketTaskLifecycle
    }

    private static func validateOwnerIdentities(projectID: ProjectID, ticketID: TicketID) throws {
        guard !projectID.rawValue.contains("\0"), !ticketID.rawValue.contains("\0") else {
            throw invalid(.ticketNotFound)
        }
    }

    private static func requireMutableTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        connection: SQLiteConnection
    ) throws {
        guard let row = try connection.row(
            "SELECT lane FROM tickets WHERE project_id = ? AND id = ?",
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ), case let .text(lane)? = row["lane"] else {
            throw invalid(.ticketNotFound)
        }
        guard lane != TicketLane.accepted.rawValue else {
            throw invalid(.acceptedTicket)
        }
    }

    private static func validateOperationIdentities(
        additions: [TicketTaskDraft],
        definitionRevisions: [TicketTaskDefinitionRevision],
        supersededTaskIDs: [TicketTaskID]
    ) throws {
        var seen: Set<Data> = []
        for id in additions.map(\.id) + definitionRevisions.map(\.id) + supersededTaskIDs {
            guard seen.insert(Data(id.rawValue.utf8)).inserted else {
                throw invalid(.duplicateOperationTaskID(id))
            }
        }
    }

    private static func validateAdditionLabelsAreDistinct(_ additions: [TicketTaskDraft]) throws {
        var seen: Set<Data> = []
        for addition in additions {
            guard seen.insert(Data(addition.label.utf8)).inserted else {
                throw invalid(.labelAlreadyUsed(addition.label))
            }
        }
    }

    private static func validateAddition(_ addition: TicketTaskDraft) throws {
        try validateTaskID(addition.id)
        guard isValidText(addition.label, maximumUTF8Bytes: maximumTaskLabelUTF8Bytes) else {
            throw invalid(.invalidLabel(taskID: addition.id))
        }
        guard isValidText(addition.title, maximumUTF8Bytes: maximumTaskTitleUTF8Bytes) else {
            throw invalid(.invalidTitle(taskID: addition.id))
        }
        guard addition.sortOrder >= 0 else {
            throw invalid(.invalidSortOrder(taskID: addition.id))
        }
    }

    private static func validateDefinitionRevision(_ revision: TicketTaskDefinitionRevision) throws {
        try validateTaskID(revision.id)
        guard revision.title != nil || revision.sortOrder != nil else {
            throw invalid(.emptyDefinitionRevision(revision.id))
        }
        if let title = revision.title,
           !isValidText(title, maximumUTF8Bytes: maximumTaskTitleUTF8Bytes) {
            throw invalid(.invalidTitle(taskID: revision.id))
        }
        if let sortOrder = revision.sortOrder, sortOrder < 0 {
            throw invalid(.invalidSortOrder(taskID: revision.id))
        }
    }

    private static func validateTaskID(_ taskID: TicketTaskID) throws {
        guard isValidText(taskID.rawValue, maximumUTF8Bytes: maximumTaskIDUTF8Bytes) else {
            throw invalid(.invalidTaskID(taskID))
        }
    }

    private static func isValidText(_ text: String, maximumUTF8Bytes: Int) -> Bool {
        let byteCount = text.utf8.count
        return byteCount > 0
            && byteCount <= maximumUTF8Bytes
            && !text.contains("\0")
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func validateHistoricalReuse(
        projectID: ProjectID,
        ticketID: TicketID,
        additions: [TicketTaskDraft],
        connection: SQLiteConnection
    ) throws {
        for addition in additions {
            if try connection.scalarInt(
                "SELECT COUNT(*) FROM ticket_tasks WHERE project_id = ? AND ticket_id = ? AND id = ? COLLATE BINARY",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .text(addition.id.rawValue)]
            ) ?? 0 > 0 {
                throw invalid(.taskIDAlreadyUsed(addition.id))
            }
            if try connection.scalarInt(
                "SELECT COUNT(*) FROM ticket_tasks WHERE project_id = ? AND ticket_id = ? AND label = ? COLLATE BINARY",
                bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .text(addition.label)]
            ) ?? 0 > 0 {
                throw invalid(.labelAlreadyUsed(addition.label))
            }
        }
    }

    private static func insert(
        _ addition: TicketTaskDraft,
        projectID: ProjectID,
        ticketID: TicketID,
        timestamp: String,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            """
            INSERT INTO ticket_tasks
                (project_id, ticket_id, id, label, title, sort_order, completion, lifecycle,
                 created_at, updated_at, completed_at, superseded_at)
            VALUES (?, ?, ?, ?, ?, ?, 'pending', 'active', ?, ?, NULL, NULL)
            """,
            bindings: [
                .text(projectID.rawValue), .text(ticketID.rawValue), .text(addition.id.rawValue),
                .text(addition.label), .text(addition.title), .integer(Int64(addition.sortOrder)),
                .text(timestamp), .text(timestamp),
            ]
        )
    }

    private static func loadPlan(
        projectID: ProjectID,
        ticketID: TicketID,
        connection: SQLiteConnection
    ) throws -> TicketTaskPlanRecord? {
        guard let row = try connection.row(
            """
            SELECT revision, created_at, updated_at
            FROM ticket_task_plans WHERE project_id = ? AND ticket_id = ?
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue)]
        ) else {
            return nil
        }
        guard case let .integer(revision)? = row["revision"],
              case let .text(createdAt)? = row["created_at"],
              case let .text(updatedAt)? = row["updated_at"],
              let createdDate = parseDate(createdAt),
              let updatedDate = parseDate(updatedAt) else {
            throw invalidRow("Invalid ticket task plan row")
        }
        return .init(
            projectID: projectID,
            ticketID: ticketID,
            revision: revision,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }

    private static func requirePlan(
        projectID: ProjectID,
        ticketID: TicketID,
        connection: SQLiteConnection
    ) throws -> TicketTaskPlanRecord {
        guard let plan = try loadPlan(projectID: projectID, ticketID: ticketID, connection: connection) else {
            throw TicketTaskPlanningPolicyError.ticketTaskPlanNotFound
        }
        return plan
    }

    private static func loadTask(
        projectID: ProjectID,
        ticketID: TicketID,
        taskID: TicketTaskID,
        connection: SQLiteConnection
    ) throws -> TaskState? {
        guard let row = try connection.row(
            """
            SELECT title, sort_order, completion, lifecycle
            FROM ticket_tasks WHERE project_id = ? AND ticket_id = ? AND id = ?
            """,
            bindings: [.text(projectID.rawValue), .text(ticketID.rawValue), .text(taskID.rawValue)]
        ) else {
            return nil
        }
        guard case let .text(title)? = row["title"],
              case let .integer(sortOrder)? = row["sort_order"],
              case let .text(completionRaw)? = row["completion"],
              case let .text(lifecycleRaw)? = row["lifecycle"],
              let completion = TicketTaskCompletion(rawValue: completionRaw),
              let lifecycle = TicketTaskLifecycle(rawValue: lifecycleRaw),
              let order = Int(exactly: sortOrder) else {
            throw invalidRow("Invalid ticket task row")
        }
        return .init(
            id: taskID,
            title: title,
            sortOrder: order,
            completion: completion,
            lifecycle: lifecycle
        )
    }

    private static func advancePlan(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedRevision: Int64,
        timestamp: String,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            """
            UPDATE ticket_task_plans
            SET revision = revision + 1, updated_at = ?
            WHERE project_id = ? AND ticket_id = ? AND revision = ?
            """,
            bindings: [
                .text(timestamp), .text(projectID.rawValue), .text(ticketID.rawValue),
                .integer(expectedRevision),
            ]
        )
        try requireOneChangedRow(connection)
    }

    private static func requireOneChangedRow(_ connection: SQLiteConnection) throws {
        guard try connection.scalarInt("SELECT changes()") == 1 else {
            throw invalidRow("Ticket task state changed concurrently")
        }
    }

    private static func requireRevisionAdvance(_ revision: Int64) throws {
        guard revision < Int64.max else {
            throw invalid(.revisionExhausted)
        }
    }

    private static func operationTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) {
            return date
        }
        return ISO8601DateFormatter().date(from: text)
    }

    private static func invalid(
        _ reason: InvalidTicketTaskMutationReason
    ) -> TicketTaskPlanningPolicyError {
        .invalidTicketTaskMutation(reason)
    }

    private static func invalidRow(_ message: String) -> SQLiteError {
        SQLiteError(code: 20, message: message)
    }
}
