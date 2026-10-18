import Foundation

public struct DependencyGraphPresentationLayout: Codable, Equatable, Sendable {
    public struct Rank: Codable, Equatable, Sendable {
        public let depth: Int
        public let ticketIDs: [TicketID]

        public init(depth: Int, ticketIDs: [TicketID]) {
            self.depth = depth
            self.ticketIDs = ticketIDs
        }
    }

    public let ranks: [Rank]

    public init(ranks: [Rank]) {
        self.ranks = ranks
    }
}

public enum DependencyGraphPresentationRecord: Equatable, Sendable {
    case none
    case supported(DependencyGraphPresentationLayout)
    case unsupported(payloadVersion: Int64, payloadData: Data)
}

public enum DependencyGraphPresentationError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedPayload(payloadVersion: Int64)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedPayload(version):
            "The saved dependency graph arrangement uses unsupported payload version \(version) and was not changed."
        }
    }
}

public struct DependencyGraphPresentationRepository: Sendable {
    public static let payloadVersion: Int64 = 1

    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func load(
        registration: ProjectRegistration,
        focusTicketID: TicketID
    ) async throws -> DependencyGraphPresentationRecord {
        try await store.read { connection in
            guard try Self.isCurrent(registration, connection: connection) else { return .none }
            return try Self.storedRecord(
                registration: registration,
                focusTicketID: focusTicketID,
                connection: connection
            )
        }
    }

    public func save(
        _ layout: DependencyGraphPresentationLayout,
        registration: ProjectRegistration,
        focusTicketID: TicketID
    ) async throws {
        guard layout.isValid else {
            throw StoreError.unavailable("The dependency graph arrangement is invalid and was not saved.")
        }
        let payload = try Self.encoder.encode(layout)
        let now = ISO8601DateFormatter().string(from: Date())
        try await store.transact(actor: .init(id: "release-radar"), reason: "Save dependency graph presentation") { connection in
            try Self.requireCurrent(registration, connection: connection)
            if case let .unsupported(version, _) = try Self.storedRecord(
                registration: registration,
                focusTicketID: focusTicketID,
                connection: connection
            ) {
                throw DependencyGraphPresentationError.unsupportedPayload(payloadVersion: version)
            }
            try connection.execute(
                """
                INSERT INTO dependency_graph_presentations (
                    project_id, registration_id, focus_ticket_id,
                    payload_version, payload_data, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(project_id, registration_id, focus_ticket_id, payload_version)
                DO UPDATE SET payload_data = excluded.payload_data, updated_at = excluded.updated_at
                """,
                bindings: [
                    .text(registration.projectID.rawValue),
                    .text(registration.registrationID),
                    .text(focusTicketID.rawValue),
                    .integer(Self.payloadVersion),
                    .blob(payload),
                    .text(now),
                ]
            )
        }
    }

    public func reset(
        registration: ProjectRegistration,
        focusTicketID: TicketID
    ) async throws {
        try await store.transact(actor: .init(id: "release-radar"), reason: "Reset dependency graph presentation") { connection in
            try Self.requireCurrent(registration, connection: connection)
            switch try Self.storedRecord(
                registration: registration,
                focusTicketID: focusTicketID,
                connection: connection
            ) {
            case let .unsupported(version, _):
                throw DependencyGraphPresentationError.unsupportedPayload(payloadVersion: version)
            case .none:
                return
            case .supported:
                break
            }
            try connection.execute(
                """
                DELETE FROM dependency_graph_presentations
                WHERE project_id = ? AND registration_id = ? AND focus_ticket_id = ?
                  AND payload_version = ?
                """,
                bindings: [
                    .text(registration.projectID.rawValue),
                    .text(registration.registrationID),
                    .text(focusTicketID.rawValue),
                    .integer(Self.payloadVersion),
                ]
            )
        }
    }

    private static func storedRecord(
        registration: ProjectRegistration,
        focusTicketID: TicketID,
        connection: SQLiteConnection
    ) throws -> DependencyGraphPresentationRecord {
        guard let row = try connection.row(
            """
            SELECT payload_version, payload_data
            FROM dependency_graph_presentations
            WHERE project_id = ? AND registration_id = ? AND focus_ticket_id = ?
            ORDER BY payload_version DESC
            LIMIT 1
            """,
            bindings: [
                .text(registration.projectID.rawValue),
                .text(registration.registrationID),
                .text(focusTicketID.rawValue),
            ]
        ) else { return .none }
        guard case let .integer(version)? = row["payload_version"],
              case let .blob(payload)? = row["payload_data"] else {
            throw StoreError.unavailable("Saved dependency graph presentation has an invalid storage shape")
        }
        guard version == Self.payloadVersion,
              let layout = try? decoder.decode(DependencyGraphPresentationLayout.self, from: payload),
              layout.isValid
        else { return .unsupported(payloadVersion: version, payloadData: payload) }
        return .supported(layout)
    }

    private static func isCurrent(
        _ registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws -> Bool {
        try connection.scalarInt(
            """
            SELECT COUNT(*) FROM project_registrations
            WHERE project_id = ? AND registration_id = ?
              AND request_generation = ? AND setup_state = 'complete'
            """,
            bindings: [
                .text(registration.projectID.rawValue),
                .text(registration.registrationID),
                .integer(registration.requestGeneration),
            ]
        ) == 1
    }

    private static func requireCurrent(
        _ registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws {
        guard try isCurrent(registration, connection: connection) else {
            throw StoreError.unavailable(
                "The dependency graph presentation belongs to an earlier project registration and was not changed."
            )
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder { JSONDecoder() }
}

private extension DependencyGraphPresentationLayout {
    var isValid: Bool {
        guard ranks.allSatisfy({ $0.depth >= 0 && !$0.ticketIDs.isEmpty }),
              Set(ranks.map(\.depth)).count == ranks.count else { return false }
        let ticketIDs = ranks.flatMap(\.ticketIDs)
        return ticketIDs.allSatisfy { !$0.rawValue.isEmpty }
            && Set(ticketIDs).count == ticketIDs.count
    }
}
