import Foundation

public struct WorkspaceSavedQuery: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var definition: WorkspaceSearchDefinition

    public init(id: String, name: String, definition: WorkspaceSearchDefinition) {
        self.id = id
        self.name = name
        self.definition = definition
    }
}

public struct UnsupportedWorkspaceSavedQuery: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let payloadVersion: Int64
    public let payloadData: Data

    public init(id: String, name: String, payloadVersion: Int64, payloadData: Data) {
        self.id = id
        self.name = name
        self.payloadVersion = payloadVersion
        self.payloadData = payloadData
    }
}

public enum WorkspaceSavedQueryRecord: Equatable, Hashable, Sendable, Identifiable {
    case supported(WorkspaceSavedQuery)
    case unsupported(UnsupportedWorkspaceSavedQuery)

    public var id: String {
        switch self {
        case let .supported(query): query.id
        case let .unsupported(query): query.id
        }
    }

    public var name: String {
        switch self {
        case let .supported(query): query.name
        case let .unsupported(query): query.name
        }
    }
}

public enum WorkspaceSearchPreferenceRecord: Equatable, Sendable {
    case none
    case supported(WorkspaceSearchDefinition)
    case unsupported(payloadVersion: Int64, payloadData: Data)
}

public struct WorkspaceSearchPreferencesRepository: Sendable {
    public static let payloadVersion: Int64 = 1

    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func loadWorkingDefinition() async throws -> WorkspaceSearchPreferenceRecord {
        try await store.read { connection in
            guard let row = try connection.row(
                "SELECT payload_version, payload_data FROM workspace_search_preferences WHERE singleton_id = 1"
            ) else { return .none }
            guard case let .integer(version)? = row["payload_version"],
                  case let .blob(payload)? = row["payload_data"] else {
                throw StoreError.unavailable("Saved search preferences have an invalid storage shape")
            }
            guard version == Self.payloadVersion,
                  let definition = try? Self.decoder.decode(WorkspaceSearchDefinition.self, from: payload)
            else { return .unsupported(payloadVersion: version, payloadData: payload) }
            return .supported(definition)
        }
    }

    public func saveWorkingDefinition(_ definition: WorkspaceSearchDefinition) async throws {
        let bound = try await WorkspaceSearchQuery.boundToCurrentAuthority(store: store, definition: definition)
        let payload = try Self.encoder.encode(bound)
        let now = ISO8601DateFormatter().string(from: Date())
        try await store.transact(actor: .init(id: "release-radar"), reason: "Save workspace search preferences") { connection in
            try connection.execute(
                """
                INSERT INTO workspace_search_preferences (singleton_id, payload_version, payload_data, updated_at)
                VALUES (1, ?, ?, ?)
                ON CONFLICT(singleton_id) DO UPDATE SET
                    payload_version = excluded.payload_version,
                    payload_data = excluded.payload_data,
                    updated_at = excluded.updated_at
                """,
                bindings: [.integer(Self.payloadVersion), .blob(payload), .text(now)]
            )
        }
    }

    public func loadSavedQueries() async throws -> [WorkspaceSavedQueryRecord] {
        try await store.read { connection in
            try connection.rows(
                "SELECT id, name, payload_version, payload_data FROM workspace_saved_queries ORDER BY lower(name), id",
                maximum: 1_000
            ).map { row in
                guard case let .text(id)? = row["id"],
                      case let .text(name)? = row["name"],
                      case let .integer(version)? = row["payload_version"],
                      case let .blob(payload)? = row["payload_data"] else {
                    throw StoreError.unavailable("A saved query has an invalid storage shape")
                }
                guard version == Self.payloadVersion,
                      let definition = try? Self.decoder.decode(WorkspaceSearchDefinition.self, from: payload)
                else {
                    return .unsupported(.init(
                        id: id,
                        name: name,
                        payloadVersion: version,
                        payloadData: payload
                    ))
                }
                return .supported(.init(id: id, name: name, definition: definition))
            }
        }
    }

    @discardableResult
    public func saveQuery(
        id: String = UUID().uuidString,
        name: String,
        definition: WorkspaceSearchDefinition
    ) async throws -> WorkspaceSavedQuery {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.utf8.count <= 128,
              !normalizedName.isEmpty, normalizedName.utf8.count <= 128 else {
            throw WorkspaceSearchError.invalidDefinition("Saved query names and identities must contain 1–128 bytes.")
        }
        let bound = try await WorkspaceSearchQuery.boundToCurrentAuthority(store: store, definition: definition)
        let payload = try Self.encoder.encode(bound)
        let now = ISO8601DateFormatter().string(from: Date())
        try await store.transact(actor: .init(id: "release-radar"), reason: "Save workspace query") { connection in
            try connection.execute(
                """
                INSERT INTO workspace_saved_queries (id, name, payload_version, payload_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    payload_version = excluded.payload_version,
                    payload_data = excluded.payload_data,
                    updated_at = excluded.updated_at
                """,
                bindings: [
                    .text(id), .text(normalizedName), .integer(Self.payloadVersion),
                    .blob(payload), .text(now), .text(now),
                ]
            )
        }
        return .init(id: id, name: normalizedName, definition: bound)
    }

    public func deleteQuery(id: String) async throws {
        try await store.transact(actor: .init(id: "release-radar"), reason: "Delete workspace query") { connection in
            try connection.execute("DELETE FROM workspace_saved_queries WHERE id = ?", bindings: [.text(id)])
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder { JSONDecoder() }
}
