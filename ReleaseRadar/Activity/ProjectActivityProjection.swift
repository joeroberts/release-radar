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
                       observed_goals.last_observed_at, thread_links.ticket_id
                FROM observed_goals
                LEFT JOIN thread_links
                  ON thread_links.project_id = observed_goals.project_id
                 AND thread_links.thread_id = observed_goals.thread_id
                WHERE observed_goals.project_id = ?
                ORDER BY observed_goals.last_observed_at DESC
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let notificationRows = try connection.activityRows(
                """
                SELECT notification_events.id, notification_events.fingerprint,
                       notification_events.state, notification_events.ticket_id
                FROM notification_events
                LEFT JOIN tickets ON tickets.id = notification_events.ticket_id
                WHERE tickets.project_id = ?
                ORDER BY notification_events.rowid DESC
                """,
                bindings: [.text(projectID.rawValue)]
            )
            let auditRows = try connection.activityRows(
                "SELECT id, reason, created_at FROM audit_events ORDER BY created_at DESC",
                bindings: []
            )
            let tokens = Set(ticketLanes.keys.map(\.rawValue) + reviewRows.compactMap { try? $0.activityText("id") })
            let relevantAudits = try auditRows.filter { row in
                let reason = try row.activityText("reason")
                return tokens.contains { reason.localizedCaseInsensitiveContains($0) }
            }
            let formatter = ISO8601DateFormatter()
            func lane(for ticketID: TicketID?) -> TicketLane? {
                ticketID.flatMap { ticketLanes[$0] }
            }
            func auditDate(for reviewID: String) -> Date? {
                auditRows.first { row in
                    (try? row.activityText("reason"))?.localizedCaseInsensitiveContains(reviewID) == true
                }.flatMap { row in
                    (try? row.activityText("created_at")).flatMap(formatter.date(from:))
                }
            }

            var items = try relevantAudits.map { row in
                ProjectActivityItem(
                    id: "audit-\(try row.activityText("id"))",
                    source: .audit,
                    title: "Delivery record updated",
                    detail: try row.activityText("reason"),
                    observedAt: formatter.date(from: try row.activityText("created_at")),
                    ticketID: ticketLanes.keys.first {
                        (try? row.activityText("reason"))?.localizedCaseInsensitiveContains($0.rawValue) == true
                    },
                    deliveryLane: nil,
                    runtimeState: nil
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
                    runtimeState: state
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
                    observedAt: auditDate(for: reviewID),
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil
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
                    runtimeState: RuntimeStateLanguage(storedValue: "completed")
                )
            }
            items += try notificationRows.map { row in
                let ticketID = row.activityOptionalText("ticket_id").map(TicketID.init(rawValue:))
                return ProjectActivityItem(
                    id: "notification-\(try row.activityText("id"))",
                    source: .notification,
                    title: try row.activityText("fingerprint"),
                    detail: try row.activityText("state"),
                    observedAt: nil,
                    ticketID: ticketID,
                    deliveryLane: lane(for: ticketID),
                    runtimeState: nil
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
