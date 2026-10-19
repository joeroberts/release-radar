import CryptoKit
import Foundation

public enum ProjectCompanionPublicationScope: Equatable, Sendable {
    case current(ProjectRegistration)
    case removed(removalID: ProjectRemovalID, registration: ProjectRegistration)
}

public enum ProjectCompanionPublicationCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case deliveryGraph
    case reviewMetadata
    case historyMetadata
    case documentation
    case evidence
}

public enum ProjectCompanionPublicationError: Error, Equatable, Sendable {
    case staleRegistration
    case staleRemovedRegistration
    case inactiveRegistration
    case withdrawnIncarnation(String)
    case activeIncarnationExists(String)
    case missingIncarnation(String)
    case invalidItemID
}

public struct ProjectCompanionPublicationProjection: Equatable, Sendable {
    public let registrationID: String
    public let items: [CompanionItem]
    public let classInventories: [CompanionClassInventory]

    public init(registrationID: String, items: [CompanionItem], classInventories: [CompanionClassInventory]) {
        self.registrationID = registrationID
        self.items = items
        self.classInventories = classInventories
    }

    public static func load(
        store: DeliveryStore,
        scope: ProjectCompanionPublicationScope,
        selectedCategories: Set<ProjectCompanionPublicationCategory>
    ) async throws -> Self {
        let result = try await store.read { connection -> (ProjectRegistration, CompanionItemLifecycle, [SourceItem], [String: UUID]) in
            let registration = try validate(scope: scope, connection: connection)
            let lifecycle = try lifecycle(scope: scope, connection: connection)
            let sources = try sourceItems(registration: registration, scope: scope, selectedCategories: selectedCategories, connection: connection)
            let identities = try activeIdentities(registration: registration, connection: connection)
            return (registration, lifecycle, sources, identities)
        }
        let includedSources = result.2.filter { selectedCategories.contains($0.category) }
        let items = includedSources.compactMap { source -> CompanionItem? in
            guard let incarnation = result.3[source.itemID] else { return nil }
            let digest = SHA256.hash(data: source.payload).map { String(format: "%02x", $0) }.joined()
            let versionData = source.payload + Data(result.1.rawValue.utf8)
            let versionID = SHA256.hash(data: versionData).map { String(format: "%02x", $0) }.joined()
            return .init(
                identity: .init(itemID: source.itemID, publicationIncarnationID: incarnation, versionID: versionID),
                classID: source.category.rawValue,
                lifecycle: result.1,
                provenance: .init(sourceIdentity: source.itemID, sourceOccurredAt: source.occurredAt, publishedAt: nil, contentSHA256: digest),
                derivedFrom: [],
                payload: source.payload
            )
        }.sorted { $0.identity.itemID < $1.identity.itemID }
        let inventories = selectedCategories.sorted { $0.rawValue < $1.rawValue }.map { category in
            if category == .documentation || category == .evidence {
                return CompanionClassInventory(classID: category.rawValue, coverage: .init(status: .unavailable, itemCount: nil, reason: .init(rawValue: category.unavailabilityReason)))
            }
            if case .removed = scope {
                return CompanionClassInventory(classID: category.rawValue, coverage: .init(status: .unavailable, itemCount: nil, reason: .init(rawValue: "retained-projection-not-yet-implemented")))
            }
            let sourceCount = includedSources.filter { $0.category == category }.count
            let itemCount = items.filter { $0.classID == category.rawValue }.count
            if sourceCount == 0 {
                return CompanionClassInventory(classID: category.rawValue, coverage: .init(status: .empty, itemCount: 0, reason: nil))
            }
            if sourceCount != itemCount {
                return CompanionClassInventory(classID: category.rawValue, coverage: .init(status: .unavailable, itemCount: nil, reason: .init(rawValue: "publication-identity-not-established")))
            }
            return CompanionClassInventory(classID: category.rawValue, coverage: .init(status: .complete, itemCount: itemCount, reason: nil))
        }
        return .init(registrationID: result.0.registrationID, items: items, classInventories: inventories)
    }

    private struct SourceItem {
        let category: ProjectCompanionPublicationCategory
        let itemID: String
        let payload: Data
        let occurredAt: Date?
    }

    private static func lifecycle(scope: ProjectCompanionPublicationScope, connection: SQLiteConnection) throws -> CompanionItemLifecycle {
        switch scope {
        case let .current(registration):
            let value = try connection.scalarText("SELECT lifecycle FROM projects WHERE id = ?", bindings: [.text(registration.projectID.rawValue)])
            return value == ProjectLifecycle.archived.rawValue ? .archived : .active
        case .removed:
            return .removed
        }
    }

    private static func sourceItems(registration: ProjectRegistration, scope: ProjectCompanionPublicationScope, selectedCategories: Set<ProjectCompanionPublicationCategory>, connection: SQLiteConnection) throws -> [SourceItem] {
        guard case .current = scope else { return [] }
        let projectID = registration.projectID.rawValue
        func payload(_ object: [String: Any]) throws -> Data {
            try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        var result: [SourceItem] = []
        if selectedCategories.contains(.deliveryGraph) { for row in try connection.rows("SELECT id FROM phases WHERE project_id = ? ORDER BY id", bindings: [.text(projectID)]) {
            guard case let .text(id)? = row["id"] else { throw StoreError.unavailable("Invalid phase projection row") }
            result.append(.init(category: .deliveryGraph, itemID: "delivery.phase:\(id)", payload: try payload(["kind": "phase", "id": id]), occurredAt: nil))
        } }
        if selectedCategories.contains(.deliveryGraph) { for row in try connection.rows("SELECT id, phase_id, lane FROM tickets WHERE project_id = ? ORDER BY id", bindings: [.text(projectID)]) {
            guard case let .text(id)? = row["id"] else { throw StoreError.unavailable("Invalid ticket projection row") }
            var value: [String: Any] = ["kind": "ticket", "id": id]
            if case let .text(phaseID)? = row["phase_id"] { value["phaseID"] = phaseID }
            if case let .text(lane)? = row["lane"] { value["lane"] = lane }
            result.append(.init(category: .deliveryGraph, itemID: "delivery.ticket:\(id)", payload: try payload(value), occurredAt: nil))
        } }
        if selectedCategories.contains(.reviewMetadata) { for row in try connection.rows("SELECT id, ticket_id, kind, status FROM review_items WHERE project_id = ? ORDER BY id", bindings: [.text(projectID)]) {
            guard case let .text(id)? = row["id"], case let .text(kind)? = row["kind"], case let .text(status)? = row["status"] else { throw StoreError.unavailable("Invalid review projection row") }
            var value: [String: Any] = ["kind": "review", "id": id, "reviewKind": kind, "status": status]
            if case let .text(ticketID)? = row["ticket_id"] { value["ticketID"] = ticketID }
            result.append(.init(category: .reviewMetadata, itemID: "review:\(id)", payload: try payload(value), occurredAt: nil))
        } }
        if selectedCategories.contains(.historyMetadata) { for row in try connection.rows("SELECT id, entity_type, created_at FROM audit_events WHERE project_id = ? ORDER BY id", bindings: [.text(projectID)]) {
            guard case let .text(id)? = row["id"], case let .text(createdAt)? = row["created_at"] else { throw StoreError.unavailable("Invalid history projection row") }
            var value: [String: Any] = ["kind": "history", "id": id, "createdAt": createdAt]
            if case let .text(entityType)? = row["entity_type"] { value["entityType"] = entityType }
            result.append(.init(category: .historyMetadata, itemID: "history:\(id)", payload: try payload(value), occurredAt: ISO8601DateFormatter().date(from: createdAt)))
        } }
        return result
    }

    private static func activeIdentities(registration: ProjectRegistration, connection: SQLiteConnection) throws -> [String: UUID] {
        var result: [String: UUID] = [:]
        for row in try connection.rows("SELECT item_id, publication_incarnation_id FROM companion_publication_incarnations WHERE project_id = ? AND registration_id = ? AND withdrawn_at IS NULL", bindings: [.text(registration.projectID.rawValue), .text(registration.registrationID)]) {
            guard case let .text(itemID)? = row["item_id"], case let .text(rawID)? = row["publication_incarnation_id"], let incarnation = UUID(uuidString: rawID) else { throw StoreError.unavailable("Invalid companion publication identity") }
            result[itemID] = incarnation
        }
        return result
    }

    fileprivate static func validate(
        scope: ProjectCompanionPublicationScope,
        connection: SQLiteConnection
    ) throws -> ProjectRegistration {
        switch scope {
        case let .current(registration):
            guard try connection.scalarInt(
                """
                SELECT COUNT(*) FROM projects
                JOIN project_registrations ON project_registrations.project_id = projects.id
                WHERE projects.id = ? AND project_registrations.registration_id = ?
                  AND project_registrations.request_generation = ?
                  AND projects.lifecycle IN ('active', 'archived')
                """,
                bindings: [.text(registration.projectID.rawValue), .text(registration.registrationID), .integer(registration.requestGeneration)]
            ) == 1 else {
                throw ProjectCompanionPublicationError.staleRegistration
            }
            return registration
        case let .removed(removalID, registration):
            guard try connection.scalarInt(
                """
                SELECT COUNT(*) FROM removed_projects
                WHERE removal_id = ? AND historical_project_id = ? AND registration_id = ?
                  AND request_generation = ?
                """,
                bindings: [.text(removalID.rawValue), .text(registration.projectID.rawValue), .text(registration.registrationID), .integer(registration.requestGeneration)]
            ) == 1 else {
                throw ProjectCompanionPublicationError.staleRemovedRegistration
            }
            return registration
        }
    }
}

public actor ProjectCompanionPublicationIdentityStore {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func ensureActiveIncarnations(
        registration: ProjectRegistration,
        itemIDs: [String],
        actor: DeliveryActor
    ) async throws -> [String: UUID] {
        try Self.validate(itemIDs: itemIDs)
        return try await store.transact(actor: actor, reason: "Ensure companion publication identities") { connection in
            try Self.requireActive(registration: registration, connection: connection)
            var result: [String: UUID] = [:]
            for itemID in itemIDs.sorted() {
                if let value = try Self.activeIncarnation(registration: registration, itemID: itemID, connection: connection) {
                    result[itemID] = value
                    continue
                }
                if try Self.hasIncarnation(registration: registration, itemID: itemID, connection: connection) {
                    throw ProjectCompanionPublicationError.withdrawnIncarnation(itemID)
                }
                let incarnation = UUID()
                try Self.insert(incarnation: incarnation, registration: registration, itemID: itemID, connection: connection)
                result[itemID] = incarnation
            }
            return result
        }
    }

    public func reintroduce(
        registration: ProjectRegistration,
        itemIDs: [String],
        actor: DeliveryActor
    ) async throws -> [String: UUID] {
        try Self.validate(itemIDs: itemIDs)
        return try await store.transact(actor: actor, reason: "Reintroduce companion publication identities") { connection in
            try Self.requireActive(registration: registration, connection: connection)
            var result: [String: UUID] = [:]
            for itemID in itemIDs.sorted() {
                guard try Self.activeIncarnation(registration: registration, itemID: itemID, connection: connection) == nil else {
                    throw ProjectCompanionPublicationError.activeIncarnationExists(itemID)
                }
                let incarnation = UUID()
                try Self.insert(incarnation: incarnation, registration: registration, itemID: itemID, connection: connection)
                result[itemID] = incarnation
            }
            return result
        }
    }

    public func withdraw(
        scope: ProjectCompanionPublicationScope,
        itemIDs: [String],
        actor: DeliveryActor
    ) async throws {
        try Self.validate(itemIDs: itemIDs)
        _ = try await store.transact(actor: actor, reason: "Withdraw companion publication identities") { connection in
            let registration = try ProjectCompanionPublicationProjection.validate(scope: scope, connection: connection)
            let withdrawnAt = ISO8601DateFormatter().string(from: Date())
            for itemID in itemIDs.sorted() {
                guard try Self.activeIncarnation(registration: registration, itemID: itemID, connection: connection) != nil else {
                    throw ProjectCompanionPublicationError.missingIncarnation(itemID)
                }
                try connection.execute(
                    """
                    UPDATE companion_publication_incarnations SET withdrawn_at = ?
                    WHERE project_id = ? AND registration_id = ? AND item_id = ? AND withdrawn_at IS NULL
                    """,
                    bindings: [.text(withdrawnAt), .text(registration.projectID.rawValue), .text(registration.registrationID), .text(itemID)]
                )
            }
        }
    }

    private nonisolated static func validate(itemIDs: [String]) throws {
        guard !itemIDs.isEmpty,
              Set(itemIDs).count == itemIDs.count,
              itemIDs.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 }) else {
            throw ProjectCompanionPublicationError.invalidItemID
        }
    }

    private nonisolated static func requireActive(
        registration: ProjectRegistration,
        connection: SQLiteConnection
    ) throws {
        guard let lifecycle = try connection.scalarText(
            """
            SELECT projects.lifecycle FROM projects
            JOIN project_registrations ON project_registrations.project_id = projects.id
            WHERE projects.id = ? AND project_registrations.registration_id = ?
              AND project_registrations.request_generation = ?
            """,
            bindings: [.text(registration.projectID.rawValue), .text(registration.registrationID), .integer(registration.requestGeneration)]
        ) else {
            throw ProjectCompanionPublicationError.staleRegistration
        }
        guard lifecycle == ProjectLifecycle.active.rawValue else {
            throw ProjectCompanionPublicationError.inactiveRegistration
        }
    }

    private nonisolated static func activeIncarnation(
        registration: ProjectRegistration,
        itemID: String,
        connection: SQLiteConnection
    ) throws -> UUID? {
        guard let rawValue = try connection.scalarText(
            """
            SELECT publication_incarnation_id FROM companion_publication_incarnations
            WHERE project_id = ? AND registration_id = ? AND item_id = ? AND withdrawn_at IS NULL
            """,
            bindings: [.text(registration.projectID.rawValue), .text(registration.registrationID), .text(itemID)]
        ) else { return nil }
        guard let incarnation = UUID(uuidString: rawValue) else {
            throw ProjectCompanionPublicationError.missingIncarnation(itemID)
        }
        return incarnation
    }

    private nonisolated static func hasIncarnation(
        registration: ProjectRegistration,
        itemID: String,
        connection: SQLiteConnection
    ) throws -> Bool {
        try connection.scalarInt(
            """
            SELECT COUNT(*) FROM companion_publication_incarnations
            WHERE project_id = ? AND registration_id = ? AND item_id = ?
            """,
            bindings: [.text(registration.projectID.rawValue), .text(registration.registrationID), .text(itemID)]
        ) != 0
    }

    private nonisolated static func insert(
        incarnation: UUID,
        registration: ProjectRegistration,
        itemID: String,
        connection: SQLiteConnection
    ) throws {
        try connection.execute(
            """
            INSERT INTO companion_publication_incarnations (
                project_id, registration_id, item_id, publication_incarnation_id, created_at
            ) VALUES (?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(registration.projectID.rawValue), .text(registration.registrationID), .text(itemID),
                .text(incarnation.uuidString), .text(ISO8601DateFormatter().string(from: Date())),
            ]
        )
    }
}

private extension ProjectCompanionPublicationCategory {
    var unavailabilityReason: String {
        switch self {
        case .documentation, .evidence:
            "derived-artifact-projection-not-yet-implemented"
        case .deliveryGraph, .reviewMetadata, .historyMetadata:
            "structured-projection-not-yet-implemented"
        }
    }
}
