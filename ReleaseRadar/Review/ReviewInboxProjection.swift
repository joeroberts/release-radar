import Foundation
import ReleaseRadarCore

enum ReviewItemKind: Equatable, Sendable {
    case uncertainImport
    case duplicate
    case unresolvedDependency
    case unmatchedTask
    case excludedTask
    case agentReviewRequest
    case unsupported(String)

    init(storedValue: String) {
        switch storedValue {
        case "import", "uncertain_import": self = .uncertainImport
        case "duplicate": self = .duplicate
        case "unresolved_dependency": self = .unresolvedDependency
        case "unmatched_task": self = .unmatchedTask
        case "excluded_task": self = .excludedTask
        case "agent_review_request": self = .agentReviewRequest
        default: self = .unsupported(storedValue)
        }
    }

    var title: String {
        switch self {
        case .uncertainImport: "Uncertain import"
        case .duplicate: "Possible duplicate"
        case .unresolvedDependency: "Unresolved dependency"
        case .unmatchedTask: "Unmatched task"
        case .excludedTask: "Excluded task"
        case .agentReviewRequest: "Agent review request"
        case let .unsupported(value): value.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .uncertainImport: "tray.and.arrow.down"
        case .duplicate: "square.on.square"
        case .unresolvedDependency: "arrow.triangle.branch"
        case .unmatchedTask: "questionmark.folder"
        case .excludedTask: "eye.slash"
        case .agentReviewRequest: "checkmark.bubble"
        case .unsupported: "questionmark.circle"
        }
    }
}

enum ReviewItemStatus: String, Equatable, Sendable {
    case open
    case resolved
    case dismissed
}

struct ReviewItemProjection: Equatable, Identifiable, Sendable {
    let id: ReviewItemID
    let projectID: ProjectID
    let ticketID: TicketID?
    let kind: ReviewItemKind
    let summary: String
    let status: ReviewItemStatus
}

struct ReviewInboxProjection: Equatable, Sendable {
    let projectID: ProjectID
    let openItems: [ReviewItemProjection]
    let completedItems: [ReviewItemProjection]

    static func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ReviewInboxProjection {
        try await store.read { connection in
            let rows = try connection.reviewRows(projectID: projectID)
            let items = try rows.map { row in
                guard let status = ReviewItemStatus(rawValue: try row.reviewText("status")) else {
                    throw ReviewInboxProjectionError.invalidStatus(try row.reviewText("status"))
                }
                return ReviewItemProjection(
                    id: ReviewItemID(rawValue: try row.reviewText("id")),
                    projectID: projectID,
                    ticketID: row.reviewOptionalText("ticket_id").map(TicketID.init(rawValue:)),
                    kind: ReviewItemKind(storedValue: try row.reviewText("kind")),
                    summary: try row.reviewText("summary"),
                    status: status
                )
            }
            return ReviewInboxProjection(
                projectID: projectID,
                openItems: items.filter { $0.status == .open },
                completedItems: items.filter { $0.status != .open }
            )
        }
    }
}

enum ReviewInboxProjectionError: Error, Equatable {
    case missingColumn(String)
    case invalidColumn(String)
    case invalidStatus(String)
}

private extension SQLiteConnection {
    func reviewRows(projectID: ProjectID) throws -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var offset: Int64 = 0
        while let row = try row(
            "SELECT id, ticket_id, kind, summary, status FROM review_items WHERE project_id = ? ORDER BY rowid LIMIT 1 OFFSET ?",
            bindings: [.text(projectID.rawValue), .integer(offset)]
        ) {
            rows.append(row)
            offset += 1
        }
        return rows
    }
}

private extension Dictionary where Key == String, Value == SQLiteValue {
    func reviewText(_ column: String) throws -> String {
        guard let value = self[column] else { throw ReviewInboxProjectionError.missingColumn(column) }
        guard case let .text(text) = value else { throw ReviewInboxProjectionError.invalidColumn(column) }
        return text
    }

    func reviewOptionalText(_ column: String) -> String? {
        guard case let .text(text)? = self[column] else { return nil }
        return text
    }
}
