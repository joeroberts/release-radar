import Foundation

public enum MeaningfulDeliveryEventKind: String, Codable, Equatable, Sendable {
    case goalBlocked = "goal_blocked"
    case agentCompleted = "agent_completed"
    case reviewRequested = "review_requested"
    case ticketNeedsReview = "ticket_needs_review"
    case importNeedsReview = "import_needs_review"
}

public enum NotificationDeliveryState: String, Codable, Equatable, Sendable {
    case queued
    case attemptStarted = "attempt_started"
    case unknown
    case sent
    case failed
}

public struct MeaningfulDeliveryEvent: Equatable, Sendable {
    public let id: NotificationEventID
    public let projectID: ProjectID
    public let kind: MeaningfulDeliveryEventKind
    public let subjectID: String
    public let occurrence: Int64
    public let fingerprint: String
    public let title: String
    public let message: String
    public let ticketID: TicketID?
    public let goalID: ObservedGoalID?

    init(
        id: NotificationEventID,
        projectID: ProjectID,
        kind: MeaningfulDeliveryEventKind,
        subjectID: String,
        occurrence: Int64,
        fingerprint: String,
        title: String,
        message: String,
        ticketID: TicketID?,
        goalID: ObservedGoalID?
    ) {
        self.id = id
        self.projectID = projectID
        self.kind = kind
        self.subjectID = subjectID
        self.occurrence = occurrence
        self.fingerprint = fingerprint
        self.title = title
        self.message = message
        self.ticketID = ticketID
        self.goalID = goalID
    }
}

public actor MeaningfulDeliveryEventRecorder {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func recordGoalObservation(
        projectID: ProjectID,
        threadID: String,
        goalID: String,
        status: CodexGoalRuntimeStatus,
        observedAt: Date
    ) async throws {
        try await store.transact(
            actor: .init(id: "release-radar-observer"),
            reason: "Record linked goal runtime state",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM observed_threads WHERE id = ? AND project_id = ?",
                bindings: [.text(threadID), .text(projectID.rawValue)]
            ) == 1 else {
                throw MeaningfulDeliveryEventError.unknownThread
            }
            try connection.execute(
                """
                INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at)
                VALUES (?, ?, ?, ?, 'Goal status observed', ?)
                ON CONFLICT(id) DO UPDATE SET
                    project_id = excluded.project_id,
                    thread_id = excluded.thread_id,
                    status = excluded.status,
                    text = excluded.text,
                    last_observed_at = excluded.last_observed_at
                """,
                bindings: [
                    .text(goalID),
                    .text(projectID.rawValue),
                    .text(threadID),
                    .text(status.rawValue),
                    .text(ISO8601DateFormatter().string(from: observedAt)),
                ]
            )
            let ticketID = try connection.scalarText(
                "SELECT ticket_id FROM thread_links WHERE project_id = ? AND thread_id = ? ORDER BY rowid LIMIT 1",
                bindings: [.text(projectID.rawValue), .text(threadID)]
            )
            if status == .blocked, let ticketID {
                _ = try MeaningfulDeliveryEvent.enqueue(
                    projectID: projectID,
                    kind: .goalBlocked,
                    subjectID: goalID,
                    ticketID: TicketID(rawValue: ticketID),
                    goalID: ObservedGoalID(rawValue: goalID),
                    connection: connection
                )
            } else {
                try MeaningfulDeliveryEvent.deactivate(
                    kind: .goalBlocked,
                    subjectID: goalID,
                    connection: connection
                )
            }
        }
    }

    public func markDashboardOpened(projectID: ProjectID) async throws {
        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Open project dashboard",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            try connection.execute(
                "UPDATE projects SET first_dashboard_opened = 1 WHERE id = ?",
                bindings: [.text(projectID.rawValue)]
            )
        }
    }
}

enum MeaningfulDeliveryEventError: Error {
    case unknownThread
}

extension MeaningfulDeliveryEvent {
    @discardableResult
    static func enqueue(
        projectID: ProjectID,
        kind: MeaningfulDeliveryEventKind,
        subjectID: String,
        ticketID: TicketID?,
        goalID: ObservedGoalID?,
        connection: SQLiteConnection
    ) throws -> MeaningfulDeliveryEvent? {
        guard try connection.scalarInt(
            "SELECT first_dashboard_opened FROM projects WHERE id = ?",
            bindings: [.text(projectID.rawValue)]
        ) == 1 else { return nil }

        let subjectKey = "\(kind.rawValue)|\(subjectID)"
        if try connection.scalarInt(
            "SELECT is_active FROM notification_occurrences WHERE subject_key = ?",
            bindings: [.text(subjectKey)]
        ) == 1 {
            return nil
        }
        let occurrence = (try connection.scalarInt(
            "SELECT generation FROM notification_occurrences WHERE subject_key = ?",
            bindings: [.text(subjectKey)]
        ) ?? 0) + 1
        let eventID = NotificationEventID(rawValue: UUID().uuidString)
        let fingerprint = "\(kind.rawValue):\(subjectID):\(occurrence)"
        let copy = sanitizedCopy(kind: kind, ticketID: ticketID)
        let createdAt = ISO8601DateFormatter().string(from: Date())

        try connection.execute(
            """
            INSERT INTO notification_occurrences
                (subject_key, project_id, event_kind, subject_id, generation, is_active)
            VALUES (?, ?, ?, ?, ?, 1)
            ON CONFLICT(subject_key) DO UPDATE SET
                project_id = excluded.project_id,
                generation = excluded.generation,
                is_active = 1
            """,
            bindings: [
                .text(subjectKey), .text(projectID.rawValue), .text(kind.rawValue),
                .text(subjectID), .integer(occurrence),
            ]
        )
        try connection.execute(
            """
            INSERT INTO notification_events
                (id, fingerprint, state, ticket_id, goal_id, provider_receipt,
                 acknowledged_at, project_id, event_kind, subject_id, occurrence,
                 title, message, created_at, attempt_count)
            VALUES (?, ?, 'queued', ?, ?, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, 0)
            """,
            bindings: [
                .text(eventID.rawValue), .text(fingerprint),
                ticketID.map { .text($0.rawValue) } ?? .null,
                goalID.map { .text($0.rawValue) } ?? .null,
                .text(projectID.rawValue), .text(kind.rawValue), .text(subjectID),
                .integer(occurrence), .text(copy.title), .text(copy.message), .text(createdAt),
            ]
        )
        return MeaningfulDeliveryEvent(
            id: eventID,
            projectID: projectID,
            kind: kind,
            subjectID: subjectID,
            occurrence: occurrence,
            fingerprint: fingerprint,
            title: copy.title,
            message: copy.message,
            ticketID: ticketID,
            goalID: goalID
        )
    }

    static func deactivate(
        kind: MeaningfulDeliveryEventKind,
        subjectID: String,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            "UPDATE notification_occurrences SET is_active = 0 WHERE subject_key = ?",
            bindings: [.text("\(kind.rawValue)|\(subjectID)")]
        )
    }

    private static func sanitizedCopy(
        kind: MeaningfulDeliveryEventKind,
        ticketID: TicketID?
    ) -> (title: String, message: String) {
        let identifier = sanitizedIdentifier(ticketID?.rawValue) ?? "Delivery item"
        switch kind {
        case .goalBlocked:
            return ("\(identifier) is blocked", "A linked goal is blocked in Release Radar.")
        case .agentCompleted:
            return ("\(identifier) completed", "An agent recorded completed delivery work in Release Radar.")
        case .reviewRequested:
            return ("\(identifier) needs review", "An agent requested owner review in Release Radar.")
        case .ticketNeedsReview:
            return ("\(identifier) needs review", "A ticket entered Needs Review in Release Radar.")
        case .importNeedsReview:
            return ("Import needs review", "An imported delivery item needs owner review in Release Radar.")
        }
    }

    private static func sanitizedIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = String(value.unicodeScalars.filter(allowed.contains).prefix(64))
        return sanitized.isEmpty ? nil : sanitized
    }
}
