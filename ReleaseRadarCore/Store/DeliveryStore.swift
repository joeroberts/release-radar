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
    case phaseLifecycle = "phase_lifecycle"
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
    case ticketReference = "ticket_reference"
    case planChangeProposal = "plan_change_proposal"
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

private struct AuditEventSnapshot {
    let projectName: String?
    let registrationID: String?
    let requestGeneration: Int64?
    let ticketID: String?
    let phaseID: String?
    let phaseName: String?
    let ticketOutcome: String?
    let lane: String?
}

public actor DeliveryStore {
    private var connection: SQLiteConnection?
    private var readOnlyFiles: ExistingDocumentationStoreFiles?
    public nonisolated let databaseURL: URL
    private var acceptsOperations = true
    public private(set) var availability: DeliveryStoreAvailability
    public let schemaVersionForDocumentation: Int

    public init(databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()) {
        self.init(databaseURL: databaseURL, createIfMissing: true)
    }

    public init(unavailableDatabaseURL: URL, message: String) {
        databaseURL = unavailableDatabaseURL
        schemaVersionForDocumentation = Int(StoreMigrations.currentVersion)
        connection = nil
        availability = .unavailable(.init(
            kind: .corruption,
            originalDatabaseURL: unavailableDatabaseURL,
            preMigrationSnapshotURL: nil,
            message: message
        ))
    }

    private init(databaseURL: URL, createIfMissing: Bool) {
        self.databaseURL = databaseURL
        schemaVersionForDocumentation = Int(StoreMigrations.currentVersion)
        let databaseExisted = FileManager.default.fileExists(atPath: databaseURL.path)
        let snapshotURL = Self.preMigrationSnapshotURL(for: databaseURL)
        let openedConnection: SQLiteConnection
        do {
            openedConnection = try SQLiteConnection(url: databaseURL, createIfMissing: createIfMissing)
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

    public static func documentationMaintenance(databaseURL: URL) throws -> DeliveryStore {
        _ = try ExistingDocumentationStoreFiles(url: databaseURL)
        return DeliveryStore(databaseURL: databaseURL, createIfMissing: false)
    }

    public static func existingApplicationSupportDatabaseURL(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.rekonlabs.ReleaseRadar/release-radar.sqlite")
    }

    /// Existing, quiesced v10...v13 storage only. Does not create, repair or migrate.
    public init(existingReadOnlyDatabaseURL: URL) throws {
        databaseURL = existingReadOnlyDatabaseURL
        let files = try ExistingDocumentationStoreFiles(url: existingReadOnlyDatabaseURL)
        let opened = try SQLiteConnection(url: existingReadOnlyDatabaseURL, immutableReadOnly: true)
        let version = try opened.scalarInt("PRAGMA user_version") ?? 0
        guard try StoreMigrations.recognizesDocumentationPreflightSchema(opened, version: version) else {
            throw StoreError.unsupportedSchemaVersion(found: version, supported: 13)
        }
        guard try opened.scalarText("PRAGMA quick_check") == "ok" else {
            throw StoreError.unavailable("Existing documentation store is invalid")
        }
        try files.verify()
        connection = opened; readOnlyFiles = files; availability = .available
        schemaVersionForDocumentation = Int(version)
    }

    /// One database snapshot for a complete fixed-purpose inventory. The read-only
    /// preflight additionally rejects any source/sidecar change before or after it.
    func documentationRead<T: Sendable>(_ body: @Sendable (SQLiteConnection) throws -> T) throws -> T {
        try readOnlyFiles?.verify()
        let connection = try availableConnection()
        try connection.execute("BEGIN DEFERRED TRANSACTION")
        do {
            let result = try read(body)
            try connection.execute("COMMIT")
            try readOnlyFiles?.verify()
            return result
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
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

    func transactRemovingProject<T: Sendable>(
        projectID: ProjectID,
        registrationID: String,
        removalID: ProjectRemovalID,
        actor: DeliveryActor,
        reason: String,
        _ body: @Sendable (SQLiteConnection) throws -> T
    ) throws -> T {
        guard readOnlyFiles == nil else { throw StoreError.unavailable("Documentation preflight is read-only") }
        let connection = try availableConnection()
        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
        let scopedConnection = connection.makeScopedConnection(access: .transaction)
        defer { scopedConnection.invalidate() }
        let auditEventID = AuditEventID(rawValue: UUID().uuidString)
        do {
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM project_registrations WHERE project_id = ? AND registration_id = ?",
                bindings: [.text(projectID.rawValue), .text(registrationID)]
            ) == 1 else { throw ProjectRemovalError.stalePreview }
            let auditScope = AuditScope(
                projectID: projectID,
                entityType: .project,
                entityID: projectID.rawValue
            )
            let eventSnapshot = try Self.auditEventSnapshot(connection: connection, scope: auditScope)
            try connection.execute(
                "INSERT INTO project_removal_authorizations (project_id, registration_id, removal_id) VALUES (?, ?, ?)",
                bindings: [.text(projectID.rawValue), .text(registrationID), .text(removalID.rawValue)]
            )
            let result = try connection.withTransactionCallbackRestrictions(allowProjectRemovalHistoryWrites: true) {
                try body(scopedConnection)
            }
            guard connection.isInTransaction else {
                throw SQLiteError(code: SQLITE_MISUSE, message: "The transaction callback ended the store-owned transaction")
            }
            guard try connection.scalarInt(
                "SELECT COUNT(*) FROM project_removal_authorizations WHERE project_id = ? AND registration_id = ? AND removal_id = ?",
                bindings: [.text(projectID.rawValue), .text(registrationID), .text(removalID.rawValue)]
            ) == 1 else {
                throw StoreError.unavailable("Project removal was not authorized for the current registration")
            }
            try connection.execute("DELETE FROM projects WHERE id = ?", bindings: [.text(projectID.rawValue)])
            try connection.execute("DELETE FROM project_removal_authorizations WHERE project_id = ?", bindings: [.text(projectID.rawValue)])
            let eventTimestamp = ISO8601DateFormatter().string(from: Date())
            try connection.execute(
                """
                INSERT INTO audit_events (
                    id, actor_id, thread_id, thread_attribution, project_id, entity_type,
                    entity_id, reason, created_at, historical_project_id, historical_registration_id,
                    event_facts_recorded, event_provenance, event_occurred_at, event_recorded_at,
                    event_project_name, event_registration_id, event_request_generation
                ) VALUES (?, ?, ?, ?, NULL, 'project', ?, ?, ?, ?, ?, 1, 'local_audit', ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(auditEventID.rawValue), .text(actor.id),
                    actor.threadID.map(SQLiteValue.text) ?? .null,
                    .text(actor.threadAttribution.rawValue), .text(projectID.rawValue),
                    .text(reason), .text(eventTimestamp),
                    .text(projectID.rawValue), .text(registrationID),
                    .text(eventTimestamp), .text(eventTimestamp),
                    eventSnapshot.projectName.map(SQLiteValue.text) ?? .null,
                    .text(registrationID),
                    eventSnapshot.requestGeneration.map(SQLiteValue.integer) ?? .null,
                ]
            )
            try connection.execute("COMMIT")
            return result
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    public func transact<T: Sendable>(
        actor: DeliveryActor,
        reason: String,
        auditEventID: AuditEventID,
        auditScope: AuditScope? = nil,
        _ body: @Sendable (SQLiteConnection) throws -> T
    ) throws -> T {
        guard readOnlyFiles == nil else { throw StoreError.unavailable("Documentation preflight is read-only") }
        let connection = try availableConnection()
        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
        let scopedConnection = connection.makeScopedConnection(access: .transaction)
        defer { scopedConnection.invalidate() }
        do {
            let snapshotBefore = try auditScope.map {
                try Self.auditEventSnapshot(connection: connection, scope: $0)
            }
            let result = try connection.withTransactionCallbackRestrictions {
                try body(scopedConnection)
            }
            guard connection.isInTransaction else {
                throw SQLiteError(code: SQLITE_MISUSE, message: "The transaction callback ended the store-owned transaction")
            }
            let snapshotAfter = try auditScope.map {
                try Self.auditEventSnapshot(connection: connection, scope: $0)
            }
            let liveProjectID: SQLiteValue
            if let auditScope,
               try connection.scalarInt(
                   "SELECT COUNT(*) FROM projects WHERE id = ?",
                   bindings: [.text(auditScope.projectID.rawValue)]
               ) == 1 {
                liveProjectID = .text(auditScope.projectID.rawValue)
            } else {
                liveProjectID = .null
            }
            let eventTimestamp = ISO8601DateFormatter().string(from: Date())
            let recordedFacts = auditScope != nil
            let projectName = snapshotAfter?.projectName ?? snapshotBefore?.projectName
            let registrationID = snapshotAfter?.registrationID ?? snapshotBefore?.registrationID
            let requestGeneration = snapshotAfter?.requestGeneration ?? snapshotBefore?.requestGeneration
            let ticketID = snapshotAfter?.ticketID ?? snapshotBefore?.ticketID
            let phaseID = snapshotAfter?.phaseID ?? snapshotBefore?.phaseID
            let phaseName = snapshotAfter?.phaseName ?? snapshotBefore?.phaseName
            let ticketOutcome = snapshotAfter?.ticketOutcome ?? snapshotBefore?.ticketOutcome
            try connection.execute(
                """
                INSERT INTO audit_events (
                    id, actor_id, thread_id, thread_attribution, project_id, entity_type, entity_id,
                    reason, created_at, historical_project_id, historical_registration_id,
                    event_facts_recorded, event_provenance, event_occurred_at, event_recorded_at,
                    event_project_name, event_registration_id, event_request_generation,
                    event_ticket_id, event_phase_id, event_phase_name, event_ticket_outcome,
                    event_previous_lane, event_current_lane,
                    event_previous_phase_id, event_current_phase_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(auditEventID.rawValue),
                    .text(actor.id),
                    actor.threadID.map(SQLiteValue.text) ?? .null,
                    .text(actor.threadAttribution.rawValue),
                    liveProjectID,
                    auditScope.map { .text($0.entityType.rawValue) } ?? .null,
                    auditScope.map { .text($0.entityID) } ?? .null,
                    .text(reason),
                    .text(eventTimestamp),
                    auditScope.map { .text($0.projectID.rawValue) } ?? .null,
                    registrationID.map(SQLiteValue.text) ?? .null,
                    .integer(recordedFacts ? 1 : 0),
                    recordedFacts ? .text("local_audit") : .null,
                    recordedFacts ? .text(eventTimestamp) : .null,
                    recordedFacts ? .text(eventTimestamp) : .null,
                    projectName.map(SQLiteValue.text) ?? .null,
                    registrationID.map(SQLiteValue.text) ?? .null,
                    requestGeneration.map(SQLiteValue.integer) ?? .null,
                    ticketID.map(SQLiteValue.text) ?? .null,
                    phaseID.map(SQLiteValue.text) ?? .null,
                    phaseName.map(SQLiteValue.text) ?? .null,
                    ticketOutcome.map(SQLiteValue.text) ?? .null,
                    snapshotBefore?.lane.map(SQLiteValue.text) ?? .null,
                    snapshotAfter?.lane.map(SQLiteValue.text) ?? .null,
                    snapshotBefore?.phaseID.map(SQLiteValue.text) ?? .null,
                    snapshotAfter?.phaseID.map(SQLiteValue.text) ?? .null,
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

    public func createSnapshot(at destinationURL: URL) throws {
        try availableConnection().createSnapshot(at: destinationURL)
    }

    public func createRecoverySnapshot(at destinationURL: URL) throws {
        let connection = try availableConnection()
        try connection.createSnapshot(at: destinationURL)
        acceptsOperations = false
    }

    public func sealForRecovery() {
        acceptsOperations = false
    }

    public func resumeAfterRecoveryFailure() {
        if connection != nil { acceptsOperations = true }
    }

    public func close() {
        connection?.close()
        connection = nil
        availability = .unavailable(.init(
            kind: .corruption,
            originalDatabaseURL: databaseURL,
            preMigrationSnapshotURL: nil,
            message: "Delivery store is closed"
        ))
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
        guard acceptsOperations else {
            throw StoreError.unavailable("Delivery store is quiesced for recovery")
        }
        guard let connection else {
            if case let .unavailable(recovery) = availability {
                throw StoreError.unavailable(recovery.message)
            }
            throw StoreError.unavailable("Database could not be opened")
        }
        return connection
    }

    private static func auditEventSnapshot(
        connection: SQLiteConnection,
        scope: AuditScope
    ) throws -> AuditEventSnapshot {
        let projectName = try connection.scalarText(
            "SELECT name FROM projects WHERE id = ?",
            bindings: [.text(scope.projectID.rawValue)]
        )
        let registration = try connection.row(
            "SELECT registration_id, request_generation FROM project_registrations WHERE project_id = ?",
            bindings: [.text(scope.projectID.rawValue)]
        )
        let registrationID: String? = if case let .text(value)? = registration?["registration_id"] { value } else { nil }
        let requestGeneration: Int64? = if case let .integer(value)? = registration?["request_generation"] { value } else { nil }

        let ticketID: String? = switch scope.entityType {
        case .ticket, .ticketTaskPlan:
            scope.entityID
        case .reviewItem:
            try connection.scalarText(
                "SELECT ticket_id FROM review_items WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .completion:
            try connection.scalarText(
                "SELECT ticket_id FROM completion_records WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .blocker:
            try connection.scalarText(
                "SELECT ticket_id FROM blockers WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .evidence:
            try connection.scalarText(
                "SELECT ticket_id FROM evidence WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .threadLink:
            try connection.scalarText(
                "SELECT ticket_id FROM thread_links WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .ticketReference:
            try connection.scalarText(
                "SELECT ticket_id FROM ticket_reference_links WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .ticketDependency:
            try connection.scalarText(
                "SELECT ticket_id FROM ticket_dependencies WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .project, .phase, .phaseLifecycle, .phasePlan, .deliveryGoal,
             .phaseDependency, .planChangeProposal:
            nil
        }

        let ticket = try ticketID.flatMap {
            try connection.row(
                "SELECT phase_id, outcome, lane FROM tickets WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text($0)]
            )
        }
        let ticketPhaseID: String? = if case let .text(value)? = ticket?["phase_id"] { value } else { nil }
        let phaseID: String? = switch scope.entityType {
        case .phase, .phaseLifecycle, .phasePlan:
            scope.entityID
        case .deliveryGoal:
            try connection.scalarText(
                "SELECT phase_id FROM delivery_goals WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        case .phaseDependency:
            try connection.scalarText(
                "SELECT phase_id FROM phase_dependencies WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text(scope.entityID)]
            )
        default:
            ticketPhaseID
        }
        let phaseName = try phaseID.flatMap {
            try connection.scalarText(
                "SELECT name FROM phases WHERE project_id = ? AND id = ?",
                bindings: [.text(scope.projectID.rawValue), .text($0)]
            )
        }
        let ticketOutcome: String? = if case let .text(value)? = ticket?["outcome"] { value } else { nil }
        let lane: String? = if case let .text(value)? = ticket?["lane"] { value } else { nil }
        return .init(
            projectName: projectName,
            registrationID: registrationID,
            requestGeneration: requestGeneration,
            ticketID: ticketID,
            phaseID: phaseID,
            phaseName: phaseName,
            ticketOutcome: ticketOutcome,
            lane: lane
        )
    }
}
