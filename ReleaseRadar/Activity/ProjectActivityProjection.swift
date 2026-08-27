import Foundation
import ReleaseRadarCore

enum ActivitySource: String, Equatable, Sendable {
    case audit
    case runtime
    case review
    case completion
    case notification
}

struct RuntimeStateLanguage: Equatable, Sendable {
    let title: String

    init(storedValue: String) {
        switch storedValue.lowercased().replacingOccurrences(of: " ", with: "_") {
        case "active", "in_progress": title = "Active"
        case "paused": title = "Paused"
        case "awaiting_input", "waiting": title = "Awaiting input"
        case "blocked": title = "Blocked"
        case "completed", "completed_ready_for_review": title = "Completed"
        default: title = "Unavailable"
        }
    }
}

struct ProjectActivityItem: Equatable, Identifiable, Sendable {
    let id: String
    let source: ActivitySource
    let title: String
    let detail: String
    let observedAt: Date?
    let ticketID: TicketID?
    let deliveryLane: TicketLane?
    let runtimeState: RuntimeStateLanguage?
    let notificationState: NotificationDeliveryState?
    let notificationStatusText: String?

    var freshnessText: String? {
        observedAt.map { "Last seen \($0.formatted(date: .abbreviated, time: .shortened))" }
    }
}

struct ProjectActivityProjection: Equatable, Sendable {
    let projectID: ProjectID
    let items: [ProjectActivityItem]

    static func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ProjectActivityProjection {
        try await store.read { connection in
            let ticketRows = try connection.activityRows(
                "SELECT id, lane FROM tickets WHERE project_id = ? ORDER BY rowid",
                bindings: [.text(projectID.rawValue)]
            )
            let ticketLanes: [TicketID: TicketLane] = try Dictionary(
                uniqueKeysWithValues: ticketRows.map { row in
                    let id = TicketID(rawValue: try row.activityText("id"))
                    guard let lane = TicketLane(rawValue: try row.activityText("lane")) else {
                        throw ProjectActivityProjectionError.invalidLane(try row.activityText("lane"))
                    }
                    return (id, lane)
                }
            )
            let reviewRows = try connection.activityRows(
                "SELECT id, ticket_id, summary, status FROM review_items WHERE project_id = ? AND status <> 'open' ORDER BY rowid",
                bindings: [.text(projectID.rawValue)]
            )
            let completionRows = try connection.activityRows(
                "SELECT id, ticket_id, summary, created_at FROM completion_records WHERE project_id = ? ORDER BY created_at DESC",
                bindings: [.text(projectID.rawValue)]
            )
            let runtimeRows = try connection.activityRows(
                """
                SELECT observed_goals.id, observed_goals.status, observed_goals.text,
                       observed_goals.last_observed_at, ticket_goal_links.ticket_id
                FROM observed_goals
                LEFT JOIN ticket_goal_links
                  ON ticket_goal_links.project_id = observed_goals.project_id
                 AND ticket_goal_links.goal_id = observed_goals.id
                 AND ticket_goal_links.thread_id = observed_goals.thread_id
                WHERE observed_goals.project_id = ?
                ORDER BY observed_goals.last_observed_at DESC
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let notificationRows = try connection.activityRows(
                """
                SELECT notification_events.id, notification_events.fingerprint,
                       notification_events.state, notification_events.ticket_id,
                       notification_events.title, notification_events.message,
                       notification_events.created_at, notification_events.failure_code
                FROM notification_events
                LEFT JOIN tickets ON tickets.id = notification_events.ticket_id
                WHERE notification_events.project_id = ?
                   OR (notification_events.project_id IS NULL AND tickets.project_id = ?)
                ORDER BY notification_events.rowid DESC
                """,
                bindings: [.text(projectID.rawValue), .text(projectID.rawValue)]
            )
            let auditRows = try connection.activityRows(
                """
                SELECT id, reason, created_at, entity_type, entity_id
                FROM audit_events
                WHERE project_id = ?
                ORDER BY created_at DESC
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let reviewTicketIDs = try Dictionary(
                uniqueKeysWithValues: reviewRows.compactMap { row -> (String, TicketID)? in
                    guard let ticketID = row.activityOptionalText("ticket_id") else { return nil }
                    return (try row.activityText("id"), TicketID(rawValue: ticketID))
                }
            )
            let formatter = ISO8601DateFormatter()
            func lane(for ticketID: TicketID?) -> TicketLane? {
                ticketID.flatMap { ticketLanes[$0] }
            }
            func ticketID(for auditRow: [String: SQLiteValue]) -> TicketID? {
                guard
                    let rawType = auditRow.activityOptionalText("entity_type"),
                    let entityType = AuditEntityType(rawValue: rawType),
                    let entityID = auditRow.activityOptionalText("entity_id")
                else { return nil }

                switch entityType {
                case .ticket:
                    return TicketID(rawValue: entityID)
                case .reviewItem:
                    return reviewTicketIDs[entityID]
                default:
                    return nil
                }
            }
            var reviewObservedAt: [String: Date] = [:]
            for row in auditRows where row.activityOptionalText("entity_type") == AuditEntityType.reviewItem.rawValue {
                guard
                    let reviewID = row.activityOptionalText("entity_id"),
                    reviewObservedAt[reviewID] == nil,
                    let observedAt = formatter.date(from: try row.activityText("created_at"))
                else { continue }
                reviewObservedAt[reviewID] = observedAt
            }

            var items = try auditRows.map { row in
                let ticketID = ticketID(for: row)
                return ProjectActivityItem(
                    id: "audit-\(try row.activityText("id"))",
                    source: .audit,
                    title: "Delivery record updated",
                    detail: try row.activityText("reason"),
                    observedAt: formatter.date(from: try row.activityText("created_at")),
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil,
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try runtimeRows.map { row in
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                let state = RuntimeStateLanguage(storedValue: try row.activityText("status"))
                return ProjectActivityItem(
                    id: "runtime-\(try row.activityText("id"))",
                    source: .runtime,
                    title: state.title,
                    detail: try row.activityText("text"),
                    observedAt: formatter.date(from: try row.activityText("last_observed_at")),
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: state,
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try reviewRows.map { row in
                let reviewID = try row.activityText("id")
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                return ProjectActivityItem(
                    id: "review-\(reviewID)",
                    source: .review,
                    title: "Review \(try row.activityText("status"))",
                    detail: try row.activityText("summary"),
                    observedAt: reviewObservedAt[reviewID],
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil,
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try completionRows.map { row in
                let ticketID = TicketID(rawValue: try row.activityText("ticket_id"))
                return ProjectActivityItem(
                    id: "completion-\(try row.activityText("id"))",
                    source: .completion,
                    title: "Completed",
                    detail: try row.activityText("summary"),
                    observedAt: formatter.date(from: try row.activityText("created_at")),
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: RuntimeStateLanguage(storedValue: "completed"),
                    notificationState: nil,
                    notificationStatusText: nil
                )
            }
            items += try notificationRows.map { row in
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                let rawState = try row.activityText("state")
                let fallbackTitle = try row.activityText("fingerprint")
                let state = NotificationDeliveryState(rawValue: rawState)
                    ?? (rawState.lowercased() == "delivered" ? .sent : nil)
                return ProjectActivityItem(
                    id: "notification-\(try row.activityText("id"))",
                    source: .notification,
                    title: row.activityOptionalText("title") ?? fallbackTitle,
                    detail: row.activityOptionalText("message") ?? "Persisted notification delivery event.",
                    observedAt: row.activityOptionalText("created_at").flatMap(formatter.date(from:)),
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil,
                    notificationState: state,
                    notificationStatusText: Self.notificationStatus(
                        state: state,
                        failureCode: row.activityOptionalText("failure_code")
                    )
                )
            }
            items.sort {
                switch ($0.observedAt, $1.observedAt) {
                case let (lhs?, rhs?): lhs > rhs
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): $0.id < $1.id
                }
            }
            return ProjectActivityProjection(projectID: projectID, items: items)
        }
    }

    private static func notificationStatus(
        state: NotificationDeliveryState?,
        failureCode: String?
    ) -> String {
        switch state {
        case .queued: "Queued"
        case .attemptStarted: "Sending"
        case .unknown: "Delivery unknown · Not retried automatically"
        case .sent: "Pushover delivered"
        case .failed:
            switch failureCode {
            case "credentials_missing": "Delivery failed · Credentials missing"
            case "provider_rejected": "Delivery failed · Provider rejected"
            case "invalid_provider_response": "Delivery failed · Invalid provider response"
            default: "Delivery failed · Transport unavailable"
            }
        case nil: "Persisted delivery status"
        }
    }
}

enum ProjectActivityProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidLane(String)
}

private extension SQLiteConnection {
    func activityRows(_ sql: String, bindings: [SQLiteValue]) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row("\(sql) LIMIT 1 OFFSET ?", bindings: bindings + [.integer(offset)]) {
            rows.append(row)
            offset += 1
        }
        return rows
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func activityText(_ column: String) throws -> String {
        guard let value = self[column] else { throw ProjectActivityProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw ProjectActivityProjectionError.invalidColumn(column) }
        return text
    }

    func activityOptionalText(_ column: String) -> String? {
        guard case let .text(text)? = self[column] else { return nil }
        return text
    }
}
