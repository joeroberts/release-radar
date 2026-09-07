import CryptoKit
import Darwin
import Foundation

public enum ApplicationRecoveryPreservation: String, Codable, Equatable, Sendable {
    case preferences
    case pluginReceipts
    case retainedHistory
    case auditHistory
}

public struct ApplicationTrackingResetPreview: Equatable, Sendable {
    public let projects: [ProjectRemovalPreview]
    public let preserved: [ApplicationRecoveryPreservation]
}

public struct ApplicationRestorePreview: Equatable, Sendable {
    public let packageURL: URL
    public let backupID: UUID
    public let restoredRegistrations: [ProjectRegistration]
    public let displacedRegistrations: [ProjectRegistration]
    public let newerHistoryReconciliationAvailable: Bool
    let databaseSHA256: String
}

public struct ApplicationRecoveryResult: Sendable {
    public let store: DeliveryStore
    public let operationID: UUID
    public let requiresFreshServiceGraph: Bool
    public let newerHistoryWasReconciled: Bool

    public init(
        store: DeliveryStore,
        operationID: UUID,
        requiresFreshServiceGraph: Bool,
        newerHistoryWasReconciled: Bool
    ) {
        self.store = store
        self.operationID = operationID
        self.requiresFreshServiceGraph = requiresFreshServiceGraph
        self.newerHistoryWasReconciled = newerHistoryWasReconciled
    }
}

public struct ApplicationRecoveryInstallFailure: Error, LocalizedError, Sendable {
    public let cause: ApplicationRecoveryError
    public let recoveredStore: DeliveryStore

    public var errorDescription: String? { cause.errorDescription }
}

public enum ApplicationRecoveryError: Error, LocalizedError, Equatable, Sendable {
    case stalePreview
    case invalidBackup(String)
    case unsafeStorePlacement
    case replacementFailed
    case injectedFailure

    public var errorDescription: String? {
        switch self {
        case .stalePreview:
            "The data changed after confirmation. Review the current recovery preview and try again."
        case let .invalidBackup(message):
            "The selected backup cannot be restored: \(message)"
        case .unsafeStorePlacement:
            "Recovery stopped because the application store or one of its parent folders is unsafe."
        case .replacementFailed:
            "Recovery could not install the replacement. The prior application data was restored."
        case .injectedFailure:
            "Synthetic recovery failure after moving the original store."
        }
    }
}

enum ApplicationRecoveryFaultInjection: Equatable, Sendable {
    case none
    case failAfterOriginalMoved
    case leaveInterruptedAfterOriginalMoved
}

public actor ApplicationTrackingReset {
    private let recovery: ApplicationRecoveryManager

    public init(
        store: DeliveryStore,
        databaseURL: URL,
        quiesce: @escaping @Sendable () async throws -> Void = {}
    ) {
        recovery = ApplicationRecoveryManager(store: store, databaseURL: databaseURL, quiesce: quiesce)
    }

    public func preview() async throws -> ApplicationTrackingResetPreview {
        try await recovery.previewTrackingReset()
    }

    public func apply(_ preview: ApplicationTrackingResetPreview) async throws -> ApplicationRecoveryResult {
        try await recovery.resetTracking(preview)
    }
}

public actor ApplicationRecoveryManager {
    private let store: DeliveryStore
    private let databaseURL: URL
    private let quiesce: @Sendable () async throws -> Void
    private let faultInjection: ApplicationRecoveryFaultInjection

    public init(
        store: DeliveryStore,
        databaseURL: URL,
        quiesce: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.store = store
        self.databaseURL = databaseURL
        self.quiesce = quiesce
        faultInjection = .none
    }

    init(
        store: DeliveryStore,
        databaseURL: URL,
        quiesce: @escaping @Sendable () async throws -> Void = {},
        faultInjection: ApplicationRecoveryFaultInjection
    ) {
        self.store = store
        self.databaseURL = databaseURL
        self.quiesce = quiesce
        self.faultInjection = faultInjection
    }

    public func previewTrackingReset() async throws -> ApplicationTrackingResetPreview {
        let projectIDs = try await store.read { connection in
            try connection.rows("SELECT id FROM projects ORDER BY name, id").compactMap { row in
                if case let .text(id)? = row["id"] { ProjectID(rawValue: id) } else { nil }
            }
        }
        let manager = ProjectRemovalManager(store: store)
        var projects: [ProjectRemovalPreview] = []
        for projectID in projectIDs {
            projects.append(try await manager.preview(projectID: projectID))
        }
        return .init(
            projects: projects,
            preserved: [.preferences, .pluginReceipts, .retainedHistory, .auditHistory]
        )
    }

    public func resetTracking(_ preview: ApplicationTrackingResetPreview) async throws -> ApplicationRecoveryResult {
        guard preview.preserved == [.preferences, .pluginReceipts, .retainedHistory, .auditHistory]
        else { throw ApplicationRecoveryError.stalePreview }
        try Self.validateStoreLocation(databaseURL)
        let operationID = UUID()
        let stagingURL = adjacentURL(label: "tracking-reset-\(operationID.uuidString).staging.sqlite")
        defer { Self.removeStoreFiles(at: stagingURL) }
        try await quiesce()
        do {
            try await store.createRecoverySnapshot(at: stagingURL)
            let stagingStore = DeliveryStore(databaseURL: stagingURL)
            guard await stagingStore.availability == .available else {
                await stagingStore.close()
                throw ApplicationRecoveryError.replacementFailed
            }
            let removal = ProjectRemovalManager(store: stagingStore)
            for expected in preview.projects {
                let current = try await removal.preview(projectID: expected.projectID)
                guard current == expected else {
                    await stagingStore.close()
                    throw ApplicationRecoveryError.stalePreview
                }
                _ = try await removal.apply(current)
            }
            let remaining = try await stagingStore.read { try $0.scalarInt("SELECT COUNT(*) FROM projects") }
            guard remaining == 0 else {
                await stagingStore.close()
                throw ApplicationRecoveryError.stalePreview
            }
            try await stagingStore.transact(
                actor: .init(id: "release-radar-owner"),
                reason: "Reset all tracking data"
            ) { connection in
                try Self.markRecovery(operationID: operationID, kind: "tracking_reset", connection: connection)
            }
            await stagingStore.close()
            return try await install(stagingURL: stagingURL, operationID: operationID, historyReconciled: true)
        } catch let failure as ApplicationRecoveryInstallFailure {
            throw failure
        } catch {
            if faultInjection == .leaveInterruptedAfterOriginalMoved { throw error }
            await store.resumeAfterRecoveryFailure()
            throw ApplicationRecoveryInstallFailure(cause: Self.recoveryCause(error), recoveredStore: store)
        }
    }

    public func previewRestore(packageURL: URL) async throws -> ApplicationRestorePreview {
        let validated = try Self.validateBackupPackage(packageURL)
        let backupConnection = try SQLiteConnection(url: validated.databaseURL, immutableReadOnly: true, createIfMissing: false)
        defer { backupConnection.close() }
        let restored = try Self.registrations(in: backupConnection)
        let displaced: [ProjectRegistration]
        let canReconcile: Bool
        do {
            displaced = try await store.read { try Self.registrations(in: $0) }
            canReconcile = true
        } catch {
            displaced = []
            canReconcile = false
        }
        return .init(
            packageURL: packageURL,
            backupID: validated.manifest.backupID,
            restoredRegistrations: restored,
            displacedRegistrations: displaced,
            newerHistoryReconciliationAvailable: canReconcile,
            databaseSHA256: validated.manifest.databaseSHA256
        )
    }

    public func restore(_ preview: ApplicationRestorePreview) async throws -> ApplicationRecoveryResult {
        try Self.validateStoreLocation(databaseURL)
        let validated = try Self.validateBackupPackage(preview.packageURL)
        guard validated.manifest.backupID == preview.backupID,
              validated.manifest.databaseSHA256 == preview.databaseSHA256
        else { throw ApplicationRecoveryError.stalePreview }

        let operationID = UUID()
        let stagingURL = adjacentURL(label: "restore-\(operationID.uuidString).staging.sqlite")
        let currentSnapshotURL = adjacentURL(label: "restore-\(operationID.uuidString).current.sqlite")
        defer {
            Self.removeStoreFiles(at: stagingURL)
            Self.removeStoreFiles(at: currentSnapshotURL)
        }
        try FileManager.default.copyItem(at: validated.databaseURL, to: stagingURL)
        let stagedDigest = SHA256.hash(data: try Data(contentsOf: stagingURL, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }.joined()
        guard stagedDigest == validated.manifest.databaseSHA256 else {
            throw ApplicationRecoveryError.stalePreview
        }
        let migratedStore = DeliveryStore(databaseURL: stagingURL)
        guard await migratedStore.availability == .available else {
            await migratedStore.close()
            throw ApplicationRecoveryError.invalidBackup("the database schema could not be migrated")
        }
        await migratedStore.close()

        try await quiesce()
        do {
            var historyReconciled = false
            if preview.newerHistoryReconciliationAvailable {
                try await store.createRecoverySnapshot(at: currentSnapshotURL)
                try Self.reconcileNewerFacts(from: currentSnapshotURL, into: stagingURL)
                historyReconciled = true
            } else {
                await store.sealForRecovery()
            }
            try Self.prepareRestoredStore(at: stagingURL, operationID: operationID)
            return try await install(
                stagingURL: stagingURL,
                operationID: operationID,
                historyReconciled: historyReconciled
            )
        } catch let failure as ApplicationRecoveryInstallFailure {
            throw failure
        } catch {
            if faultInjection == .leaveInterruptedAfterOriginalMoved { throw error }
            await store.resumeAfterRecoveryFailure()
            throw ApplicationRecoveryInstallFailure(cause: Self.recoveryCause(error), recoveredStore: store)
        }
    }

    public static func resolveInterruptedOperation(databaseURL: URL) throws {
        try validateStoreLocation(databaseURL)
        let markerURL = markerURL(for: databaseURL)
        guard FileManager.default.fileExists(atPath: markerURL.path) else { return }
        guard try BackupPathValidator.isRegularFileWithoutFollowingLinks(markerURL) else {
            throw ApplicationRecoveryError.unsafeStorePlacement
        }
        let decoder = JSONDecoder()
        let marker = try decoder.decode(RecoveryMarker.self, from: Data(contentsOf: markerURL))
        let rollbackURL = URL(fileURLWithPath: marker.rollbackPath)
        let stagingURL = URL(fileURLWithPath: marker.stagingPath)
        try validate(marker: marker, rollbackURL: rollbackURL, stagingURL: stagingURL, databaseURL: databaseURL)
        switch marker.phase {
        case .prepared:
            removeStoreFiles(at: stagingURL)
        case .originalMoved:
            try restoreRollback(rollbackURL: rollbackURL, databaseURL: databaseURL)
            removeStoreFiles(at: stagingURL)
        case .replacementInstalled:
            if storeIsValid(at: databaseURL) {
                removeStoreFiles(at: rollbackURL)
                removeStoreFiles(at: stagingURL)
            } else {
                removeStoreFiles(at: databaseURL)
                try restoreRollback(rollbackURL: rollbackURL, databaseURL: databaseURL)
            }
        }
        try FileManager.default.removeItem(at: markerURL)
    }

    static func markerURL(for databaseURL: URL) -> URL {
        databaseURL.deletingLastPathComponent().appendingPathComponent(".release-radar-recovery.json")
    }

    private func install(
        stagingURL: URL,
        operationID: UUID,
        historyReconciled: Bool
    ) async throws -> ApplicationRecoveryResult {
        try Self.validateStoreLocation(databaseURL)
        let rollbackURL = adjacentURL(label: "rollback-\(operationID.uuidString).sqlite")
        let markerURL = Self.markerURL(for: databaseURL)
        let prepared = RecoveryMarker(
            operationID: operationID,
            phase: .prepared,
            rollbackPath: rollbackURL.path,
            stagingPath: stagingURL.path
        )
        try Self.writeMarker(prepared, to: markerURL)
        do {
            await store.close()
            try Self.moveStoreFiles(from: databaseURL, to: rollbackURL, requireDatabase: true)
            try Self.writeMarker(prepared.withPhase(.originalMoved), to: markerURL)
            if faultInjection == .failAfterOriginalMoved || faultInjection == .leaveInterruptedAfterOriginalMoved {
                throw ApplicationRecoveryError.injectedFailure
            }
            try Self.moveStoreFiles(from: stagingURL, to: databaseURL, requireDatabase: true)
            try Self.writeMarker(prepared.withPhase(.replacementInstalled), to: markerURL)
            guard Self.storeIsValid(at: databaseURL) else {
                throw ApplicationRecoveryError.replacementFailed
            }
            Self.removeStoreFiles(at: rollbackURL)
            try FileManager.default.removeItem(at: markerURL)
            let freshStore = DeliveryStore(databaseURL: databaseURL)
            guard await freshStore.availability == .available else {
                throw ApplicationRecoveryError.replacementFailed
            }
            return .init(
                store: freshStore,
                operationID: operationID,
                requiresFreshServiceGraph: true,
                newerHistoryWasReconciled: historyReconciled
            )
        } catch {
            if faultInjection == .leaveInterruptedAfterOriginalMoved {
                throw error
            }
            var recoveredPriorState = false
            if FileManager.default.fileExists(atPath: rollbackURL.path) {
                Self.removeStoreFiles(at: databaseURL)
                if (try? Self.restoreRollback(rollbackURL: rollbackURL, databaseURL: databaseURL)) != nil {
                    recoveredPriorState = Self.storeIsValid(at: databaseURL)
                }
            } else {
                recoveredPriorState = Self.storeIsValid(at: databaseURL)
            }
            Self.removeStoreFiles(at: stagingURL)
            guard recoveredPriorState else { throw ApplicationRecoveryError.replacementFailed }
            try? FileManager.default.removeItem(at: markerURL)
            let recoveredStore = DeliveryStore(databaseURL: databaseURL)
            guard await recoveredStore.availability == .available else {
                throw ApplicationRecoveryError.replacementFailed
            }
            throw ApplicationRecoveryInstallFailure(
                cause: Self.recoveryCause(error),
                recoveredStore: recoveredStore
            )
        }
    }

    private func adjacentURL(label: String) -> URL {
        databaseURL.deletingLastPathComponent().appendingPathComponent(".release-radar-\(label)")
    }

    private static func validateBackupPackage(_ packageURL: URL) throws -> (manifest: ApplicationBackupManifest, databaseURL: URL) {
        let manifest = try ApplicationBackupManifest.load(from: packageURL)
        let databaseURL = packageURL.appendingPathComponent(ApplicationBackupManifest.databaseFileName)
        let digest = SHA256.hash(data: try Data(contentsOf: databaseURL, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.databaseSHA256 else {
            throw ApplicationRecoveryError.invalidBackup("the database checksum does not match the manifest")
        }
        let connection = try SQLiteConnection(url: databaseURL, immutableReadOnly: true, createIfMissing: false)
        defer { connection.close() }
        let version = try connection.scalarInt("PRAGMA user_version") ?? 0
        guard version == Int64(manifest.schemaVersion),
              version <= StoreMigrations.currentVersion,
              try StoreMigrations.recognizesDocumentationPreflightSchema(connection, version: version),
              try connection.scalarText("PRAGMA quick_check") == "ok"
        else { throw ApplicationRecoveryError.invalidBackup("the schema or integrity check is unsupported") }
        return (manifest, databaseURL)
    }

    private static func prepareRestoredStore(at databaseURL: URL, operationID: UUID) throws {
        let connection = try SQLiteConnection(url: databaseURL, createIfMissing: false)
        defer { connection.close() }
        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let now = ISO8601DateFormatter().string(from: Date())
            try connection.execute(
                "UPDATE notification_events SET state = 'suppressed', completed_at = ?, failure_code = 'recovery_restored_pending' WHERE state = 'queued'",
                bindings: [.text(now)]
            )
            try connection.execute(
                "UPDATE notification_events SET state = 'unknown', completed_at = ?, failure_code = 'recovery_ambiguous_attempt' WHERE state = 'attempt_started'",
                bindings: [.text(now)]
            )
            try connection.execute("UPDATE notification_occurrences SET is_active = 0")
            try connection.execute("UPDATE project_bookmarks SET is_stale = 1")
            for row in try connection.rows("SELECT project_id, request_generation FROM project_registrations ORDER BY project_id") {
                guard case let .text(projectID)? = row["project_id"],
                      case let .integer(generation)? = row["request_generation"],
                      generation < Int64.max else { throw ApplicationRecoveryError.invalidBackup("a project generation cannot be advanced") }
                try connection.execute(
                    "UPDATE project_registrations SET registration_id = ?, request_generation = ? WHERE project_id = ?",
                    bindings: [.text(UUID().uuidString.lowercased()), .integer(generation + 1), .text(projectID)]
                )
            }
            try markRecovery(operationID: operationID, kind: "restore", connection: connection)
            try connection.execute("COMMIT")
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    private static func markRecovery(operationID: UUID, kind: String, connection: SQLiteConnection) throws {
        try connection.execute(
            """
            UPDATE application_recovery_state
            SET incarnation_id = ?, requires_scoped_commands = 1,
                last_operation_kind = ?, last_operation_id = ?, completed_at = ?
            WHERE singleton_id = 1
            """,
            bindings: [
                .text(UUID().uuidString.lowercased()), .text(kind),
                .text(operationID.uuidString.lowercased()),
                .text(ISO8601DateFormatter().string(from: Date())),
            ]
        )
    }

    private static func reconcileNewerFacts(from currentURL: URL, into restoredURL: URL) throws {
        let connection = try SQLiteConnection(url: restoredURL, createIfMissing: false)
        defer { connection.close() }
        try connection.execute("ATTACH DATABASE ? AS current_state", bindings: [.text(currentURL.path)])
        defer { try? connection.execute("DETACH DATABASE current_state") }
        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try connection.executeScript("""
            INSERT OR IGNORE INTO removed_projects
                SELECT * FROM current_state.removed_projects;
            INSERT OR IGNORE INTO retained_project_activity_events
                SELECT * FROM current_state.retained_project_activity_events;
            INSERT OR IGNORE INTO retained_delivery_goal_assignment_events
                SELECT * FROM current_state.retained_delivery_goal_assignment_events;
            INSERT OR IGNORE INTO audit_events
                SELECT * FROM current_state.audit_events
                WHERE historical_project_id IS NOT NULL AND project_id IS NULL;

            INSERT OR IGNORE INTO notification_occurrences (
                subject_key, project_id, event_kind, subject_id, generation, is_active
            )
            SELECT subject_key, project_id, event_kind, subject_id, generation, 0
            FROM current_state.notification_occurrences
            WHERE project_id IN (SELECT id FROM projects);

            INSERT OR IGNORE INTO notification_events (
                id, fingerprint, state, ticket_id, goal_id, provider_receipt,
                acknowledged_at, project_id, event_kind, subject_id, occurrence,
                title, message, created_at, attempt_count, attempt_started_at,
                completed_at, failure_code
            )
            SELECT id, fingerprint, state, NULL, NULL, provider_receipt,
                acknowledged_at, project_id, event_kind, subject_id, occurrence,
                title, message, created_at, attempt_count, attempt_started_at,
                completed_at, failure_code
            FROM current_state.notification_events
            WHERE state IN ('sent', 'unknown', 'failed', 'suppressed')
              AND project_id IN (SELECT id FROM projects);

            UPDATE notification_events
            SET state = (SELECT state FROM current_state.notification_events current WHERE current.id = notification_events.id),
                provider_receipt = (SELECT provider_receipt FROM current_state.notification_events current WHERE current.id = notification_events.id),
                acknowledged_at = (SELECT acknowledged_at FROM current_state.notification_events current WHERE current.id = notification_events.id),
                attempt_count = MAX(attempt_count, (SELECT attempt_count FROM current_state.notification_events current WHERE current.id = notification_events.id)),
                attempt_started_at = (SELECT attempt_started_at FROM current_state.notification_events current WHERE current.id = notification_events.id),
                completed_at = (SELECT completed_at FROM current_state.notification_events current WHERE current.id = notification_events.id),
                failure_code = (SELECT failure_code FROM current_state.notification_events current WHERE current.id = notification_events.id)
            WHERE id IN (
                SELECT id FROM current_state.notification_events
                WHERE state IN ('sent', 'unknown', 'failed', 'suppressed')
            );

            UPDATE notification_occurrences
            SET generation = MAX(generation, COALESCE((
                    SELECT generation FROM current_state.notification_occurrences current
                    WHERE current.subject_key = notification_occurrences.subject_key
                ), generation)),
                is_active = 0
            WHERE subject_key IN (SELECT subject_key FROM current_state.notification_occurrences);
            """)
            try connection.execute("COMMIT")
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    private static func registrations(in connection: SQLiteConnection) throws -> [ProjectRegistration] {
        try connection.rows(
            "SELECT project_id, registration_id, request_generation FROM project_registrations ORDER BY project_id"
        ).compactMap { row in
            guard case let .text(projectID)? = row["project_id"],
                  case let .text(registrationID)? = row["registration_id"],
                  case let .integer(generation)? = row["request_generation"] else { return nil }
            return ProjectRegistration(
                projectID: .init(rawValue: projectID),
                registrationID: registrationID,
                requestGeneration: generation
            )
        }
    }

    private static func validateStoreLocation(_ databaseURL: URL) throws {
        guard databaseURL.isFileURL,
              try BackupPathValidator.isDirectoryWithoutFollowingLinks(databaseURL.deletingLastPathComponent())
        else { throw ApplicationRecoveryError.unsafeStorePlacement }
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        for component in databaseURL.deletingLastPathComponent().standardizedFileURL.pathComponents.dropFirst() {
            current.appendPathComponent(component)
            var metadata = stat()
            guard lstat(current.path, &metadata) == 0,
                  metadata.st_mode & S_IFMT != S_IFLNK else {
                throw ApplicationRecoveryError.unsafeStorePlacement
            }
        }
    }

    private static func validate(
        marker: RecoveryMarker,
        rollbackURL: URL,
        stagingURL: URL,
        databaseURL: URL
    ) throws {
        let parent = databaseURL.deletingLastPathComponent().standardizedFileURL
        guard rollbackURL.deletingLastPathComponent().standardizedFileURL == parent,
              stagingURL.deletingLastPathComponent().standardizedFileURL == parent else {
            throw ApplicationRecoveryError.unsafeStorePlacement
        }
        let operationID = marker.operationID.uuidString
        let expectedRollback = ".release-radar-rollback-\(operationID).sqlite"
        let expectedRestore = ".release-radar-restore-\(operationID).staging.sqlite"
        let expectedReset = ".release-radar-tracking-reset-\(operationID).staging.sqlite"
        guard rollbackURL.lastPathComponent == expectedRollback,
              stagingURL.lastPathComponent == expectedRestore || stagingURL.lastPathComponent == expectedReset else {
            throw ApplicationRecoveryError.unsafeStorePlacement
        }
    }

    private static let sidecarSuffixes = ["", "-wal", "-shm", "-journal"]

    private static func moveStoreFiles(from source: URL, to destination: URL, requireDatabase: Bool) throws {
        for suffix in sidecarSuffixes {
            let sourcePath = source.path + suffix
            let destinationPath = destination.path + suffix
            var metadata = stat()
            if lstat(sourcePath, &metadata) != 0 {
                if suffix.isEmpty && requireDatabase { throw ApplicationRecoveryError.replacementFailed }
                continue
            }
            guard metadata.st_mode & S_IFMT == S_IFREG,
                  rename(sourcePath, destinationPath) == 0 else {
                throw ApplicationRecoveryError.unsafeStorePlacement
            }
        }
    }

    private static func restoreRollback(rollbackURL: URL, databaseURL: URL) throws {
        try moveStoreFiles(from: rollbackURL, to: databaseURL, requireDatabase: true)
    }

    private static func removeStoreFiles(at url: URL) {
        for suffix in sidecarSuffixes {
            let candidate = URL(fileURLWithPath: url.path + suffix)
            var metadata = stat()
            guard lstat(candidate.path, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFREG else { continue }
            try? FileManager.default.removeItem(at: candidate)
        }
    }

    private static func storeIsValid(at url: URL) -> Bool {
        guard let connection = try? SQLiteConnection(url: url, immutableReadOnly: true, createIfMissing: false) else { return false }
        defer { connection.close() }
        return (try? connection.scalarText("PRAGMA quick_check")) == "ok"
            && (try? connection.scalarInt("PRAGMA user_version")) == StoreMigrations.currentVersion
            && (try? StoreMigrations.recognizesDocumentationPreflightSchema(
                connection,
                version: StoreMigrations.currentVersion
            )) == true
    }

    private static func recoveryCause(_ error: Error) -> ApplicationRecoveryError {
        if let error = error as? ApplicationRecoveryError { return error }
        return .invalidBackup(error.localizedDescription)
    }

    private static func writeMarker(_ marker: RecoveryMarker, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(marker)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

private struct RecoveryMarker: Codable {
    enum Phase: String, Codable {
        case prepared
        case originalMoved
        case replacementInstalled
    }

    let operationID: UUID
    let phase: Phase
    let rollbackPath: String
    let stagingPath: String

    func withPhase(_ phase: Phase) -> Self {
        .init(operationID: operationID, phase: phase, rollbackPath: rollbackPath, stagingPath: stagingPath)
    }
}
