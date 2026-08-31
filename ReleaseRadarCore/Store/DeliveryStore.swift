import Foundation
import SQLite3

public enum StoreError: Error, LocalizedError, Equatable, Sendable {
    case unavailable(String)
    case unsupportedSchemaVersion(found: Int64, supported: Int64)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(message): message
        case let .unsupportedSchemaVersion(found, supported):
            "Database schema version \(found) is newer than supported version \(supported)"
        }
    }
}

public enum StoreRecoveryFailureKind: Equatable, Sendable {
    case corruption
    case migration
}

public struct StoreRecoveryState: Equatable, Sendable {
    public let kind: StoreRecoveryFailureKind
    public let originalDatabaseURL: URL
    public let preMigrationSnapshotURL: URL?
    public let message: String
}

public enum DeliveryStoreAvailability: Equatable, Sendable {
    case available
    case unavailable(StoreRecoveryState)
}

public enum AuditEntityType: String, Equatable, Sendable {
    case project
    case phase
    case phasePlan = "phase_plan"
    case deliveryGoal = "delivery_goal"
    case ticketTaskPlan = "ticket_task_plan"
    case ticket
    case phaseDependency = "phase_dependency"
    case ticketDependency = "ticket_dependency"
    case blocker
    case evidence
    case threadLink = "thread_link"
    case reviewItem = "review_item"
    case completion
}

public struct AuditScope: Equatable, Sendable {
    public let projectID: ProjectID
    public let entityType: AuditEntityType
    public let entityID: String

    public init(projectID: ProjectID, entityType: AuditEntityType, entityID: String) {
        self.projectID = projectID
        self.entityType = entityType
        self.entityID = entityID
    }
}

public actor DeliveryStore {
    private let connection: SQLiteConnection?
    public let availability: DeliveryStoreAvailability

    public init(databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()) {
        let databaseExisted = FileManager.default.fileExists(atPath: databaseURL.path)
        let snapshotURL = Self.preMigrationSnapshotURL(for: databaseURL)
        let openedConnection: SQLiteConnection
        do {
            openedConnection = try SQLiteConnection(url: databaseURL)
            guard try openedConnection.scalarText("PRAGMA integrity_check") == "ok" else {
                throw StoreError.unavailable("Database integrity check failed")
            }
        } catch {
            connection = nil
            availability = .unavailable(.init(
                kind: .corruption,
                originalDatabaseURL: databaseURL,
                preMigrationSnapshotURL: nil,
                message: error.localizedDescription
            ))
            return
        }

        do {
            if databaseExisted, try StoreMigrations.requiresMigrationOrRepair(openedConnection) {
                try openedConnection.createSnapshot(at: snapshotURL)
            }
            try StoreMigrations.migrate(openedConnection)
            connection = openedConnection
            availability = .available
        } catch {
            connection = nil
            availability = .unavailable(.init(
                kind: .migration,
                originalDatabaseURL: databaseURL,
                preMigrationSnapshotURL: FileManager.default.fileExists(atPath: snapshotURL.path) ? snapshotURL : nil,
                message: error.localizedDescription
            ))
        }
    }

    public func transact<T: Sendable>(
        actor: DeliveryActor,
        reason: String,
        auditScope: AuditScope? = nil,
        _ body: @Sendable (SQLiteConnection) throws -> T
    ) throws -> T {
        try transact(
            actor: actor,
            reason: reason,
            auditEventID: .init(rawValue: UUID().uuidString),
            auditScope: auditScope,
            body
        )
    }

    public func transact<T: Sendable>(
        actor: DeliveryActor,
        reason: String,
        auditEventID: AuditEventID,
        auditScope: AuditScope? = nil,
        _ body: @Sendable (SQLiteConnection) throws -> T
    ) throws -> T {
        let connection = try availableConnection()
        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
        let scopedConnection = connection.makeScopedConnection(access: .transaction)
        defer { scopedConnection.invalidate() }
        do {
            let result = try connection.withTransactionCallbackRestrictions {
                try body(scopedConnection)
            }
            guard connection.isInTransaction else {
                throw SQLiteError(code: SQLITE_MISUSE, message: "The transaction callback ended the store-owned transaction")
            }
            try connection.execute(
                "INSERT INTO audit_events (id, actor_id, thread_id, thread_attribution, project_id, entity_type, entity_id, reason, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                bindings: [
                    .text(auditEventID.rawValue),
                    .text(actor.id),
                    actor.threadID.map(SQLiteValue.text) ?? .null,
                    .text(actor.threadAttribution.rawValue),
                    auditScope.map { .text($0.projectID.rawValue) } ?? .null,
                    auditScope.map { .text($0.entityType.rawValue) } ?? .null,
                    auditScope.map { .text($0.entityID) } ?? .null,
                    .text(reason),
                    .text(ISO8601DateFormatter().string(from: Date())),
                ]
            )
            try connection.execute("COMMIT")
            return result
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    public func read<T: Sendable>(
        _ body: @Sendable (SQLiteConnection) throws -> T
    ) throws -> T {
        let connection = try availableConnection()
        let scopedConnection = connection.makeScopedConnection(access: .readOnly)
        defer { scopedConnection.invalidate() }
        return try connection.withReadCallbackRestrictions {
            try body(scopedConnection)
        }
    }

    public static func applicationSupportDatabaseURL(
        fileManager: FileManager = .default
    ) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = baseURL.appendingPathComponent("com.rekonlabs.ReleaseRadar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("release-radar.sqlite")
    }

    public static func preMigrationSnapshotURL(for databaseURL: URL) -> URL {
        databaseURL.appendingPathExtension("pre-migration")
    }

    private func availableConnection() throws -> SQLiteConnection {
        guard let connection else {
            if case let .unavailable(recovery) = availability {
                throw StoreError.unavailable(recovery.message)
            }
            throw StoreError.unavailable("Database could not be opened")
        }
        return connection
    }
}
