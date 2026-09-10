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
    public let restoredTargets: [ApplicationRecoveryTarget]
    public let displacedTargets: [ApplicationRecoveryTarget]
    public let newerHistoryReconciliationAvailable: Bool
    let databaseSHA256: String

    public var restoredRegistrations: [ProjectRegistration] { restoredTargets.map(\.registration) }
    public var displacedRegistrations: [ProjectRegistration] { displacedTargets.map(\.registration) }
}

public struct ApplicationRecoveryTarget: Equatable, Sendable {
    public let name: String
    public let registration: ProjectRegistration
}

public struct ApplicationRecoveryResult: Sendable {
    public let store: DeliveryStore
    public let operationID: UUID
    public let requiresFreshServiceGraph: Bool
    public let newerHistoryWasReconciled: Bool
    public let preservedOriginalURL: URL?

    public init(
        store: DeliveryStore,
        operationID: UUID,
        requiresFreshServiceGraph: Bool,
        newerHistoryWasReconciled: Bool,
        preservedOriginalURL: URL? = nil
    ) {
        self.store = store
        self.operationID = operationID
        self.requiresFreshServiceGraph = requiresFreshServiceGraph
        self.newerHistoryWasReconciled = newerHistoryWasReconciled
        self.preservedOriginalURL = preservedOriginalURL
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
    case leaveInterruptedAfterRollbackCopied
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
            return try await install(
                stagingURL: stagingURL,
                operationID: operationID,
                historyReconciled: true,
                preserveRollback: false
            )
        } catch let failure as ApplicationRecoveryInstallFailure {
            throw failure
        } catch {
            if faultInjection == .leaveInterruptedAfterOriginalMoved
                || faultInjection == .leaveInterruptedAfterRollbackCopied { throw error }
            await store.resumeAfterRecoveryFailure()
            throw ApplicationRecoveryInstallFailure(cause: Self.recoveryCause(error), recoveredStore: store)
        }
    }

    public func previewRestore(packageURL: URL) async throws -> ApplicationRestorePreview {
        let validated = try Self.validateBackupPackage(packageURL)
        let backupConnection = try SQLiteConnection(url: validated.databaseURL, immutableReadOnly: true, createIfMissing: false)
        defer { backupConnection.close() }
        let restored = try Self.recoveryTargets(in: backupConnection)
        let displaced: [ApplicationRecoveryTarget]
        let canReconcile: Bool
        do {
            displaced = try await store.read { try Self.recoveryTargets(in: $0) }
            canReconcile = true
        } catch {
            displaced = []
            canReconcile = false
        }
        return .init(
            packageURL: packageURL,
            backupID: validated.manifest.backupID,
            restoredTargets: restored,
            displacedTargets: displaced,
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
                let currentConnection = try SQLiteConnection(
                    url: currentSnapshotURL,
                    immutableReadOnly: true,
                    createIfMissing: false
                )
                let currentTargets: [ApplicationRecoveryTarget]
                do {
                    currentTargets = try Self.recoveryTargets(in: currentConnection)
                    currentConnection.close()
                } catch {
                    currentConnection.close()
                    throw error
                }
                guard currentTargets == preview.displacedTargets else {
                    throw ApplicationRecoveryError.stalePreview
                }
                try Self.prepareRestoredStore(
                    at: stagingURL,
                    operationID: operationID,
                    registrationsRetainedFromCurrentSnapshot: currentTargets.map(\.registration)
                )
                try Self.reconcileNewerFacts(from: currentSnapshotURL, into: stagingURL)
                historyReconciled = true
            } else {
                await store.sealForRecovery()
                try Self.prepareRestoredStore(at: stagingURL, operationID: operationID)
            }
            return try await install(
                stagingURL: stagingURL,
                operationID: operationID,
                historyReconciled: historyReconciled,
                preserveRollback: !preview.newerHistoryReconciliationAvailable
            )
        } catch let failure as ApplicationRecoveryInstallFailure {
            throw failure
        } catch {
            if faultInjection == .leaveInterruptedAfterOriginalMoved
                || faultInjection == .leaveInterruptedAfterRollbackCopied { throw error }
            await store.resumeAfterRecoveryFailure()
            throw ApplicationRecoveryInstallFailure(cause: Self.recoveryCause(error), recoveredStore: store)
        }
    }

    @discardableResult
    public static func resolveInterruptedOperation(databaseURL: URL) throws -> Bool {
        try validateStoreLocation(databaseURL)
        let markerURL = markerURL(for: databaseURL)
        guard FileManager.default.fileExists(atPath: markerURL.path) else { return false }
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
            if !FileManager.default.fileExists(atPath: databaseURL.path),
               FileManager.default.fileExists(atPath: rollbackURL.path) {
                removeStoreFiles(at: databaseURL)
                try restoreRollback(rollbackURL: rollbackURL, databaseURL: databaseURL)
            } else {
                removeStoreFiles(at: rollbackURL)
            }
            removeStoreFiles(at: stagingURL)
        case .originalMoved:
            removeStoreFiles(at: databaseURL)
            try restoreRollback(rollbackURL: rollbackURL, databaseURL: databaseURL)
            removeStoreFiles(at: stagingURL)
        case .replacementInstalled:
            if storeIsValid(at: databaseURL) {
                let preserveRollback = marker.preserveRollback
                    ?? !storeIsValid(at: rollbackURL)
                if !preserveRollback {
                    removeStoreFiles(at: rollbackURL)
                }
                removeStoreFiles(at: stagingURL)
            } else {
                removeStoreFiles(at: databaseURL)
                try restoreRollback(rollbackURL: rollbackURL, databaseURL: databaseURL)
            }
        }
        try FileManager.default.removeItem(at: markerURL)
        return true
    }

    static func markerURL(for databaseURL: URL) -> URL {
        databaseURL.deletingLastPathComponent().appendingPathComponent(".release-radar-recovery.json")
    }

    private func install(
        stagingURL: URL,
        operationID: UUID,
        historyReconciled: Bool,
        preserveRollback: Bool
    ) async throws -> ApplicationRecoveryResult {
        try Self.validateStoreLocation(databaseURL)
        let rollbackURL = adjacentURL(label: "rollback-\(operationID.uuidString).sqlite")
        let markerURL = Self.markerURL(for: databaseURL)
        let prepared = RecoveryMarker(
            operationID: operationID,
            phase: .prepared,
            rollbackPath: rollbackURL.path,
            stagingPath: stagingURL.path,
            preserveRollback: preserveRollback
        )
        try Self.writeMarker(prepared, to: markerURL)
        var rollbackReady = false
        do {
            await store.close()
            try Self.copyStoreFiles(from: databaseURL, to: rollbackURL, requireDatabase: true)
            rollbackReady = true
            if faultInjection == .leaveInterruptedAfterRollbackCopied {
                throw ApplicationRecoveryError.injectedFailure
            }
            try Self.writeMarker(prepared.withPhase(.originalMoved), to: markerURL)
            Self.removeStoreFiles(at: databaseURL)
            if faultInjection == .failAfterOriginalMoved || faultInjection == .leaveInterruptedAfterOriginalMoved {
                throw ApplicationRecoveryError.injectedFailure
            }
            try Self.moveStoreFiles(from: stagingURL, to: databaseURL, requireDatabase: true)
            try Self.writeMarker(prepared.withPhase(.replacementInstalled), to: markerURL)
            guard Self.storeIsValid(at: databaseURL) else {
                throw ApplicationRecoveryError.replacementFailed
            }
            if !preserveRollback {
                Self.removeStoreFiles(at: rollbackURL)
            }
            try FileManager.default.removeItem(at: markerURL)
            let freshStore = DeliveryStore(databaseURL: databaseURL)
            guard await freshStore.availability == .available else {
                throw ApplicationRecoveryError.replacementFailed
            }
            return .init(
                store: freshStore,
                operationID: operationID,
                requiresFreshServiceGraph: true,
                newerHistoryWasReconciled: historyReconciled,
                preservedOriginalURL: preserveRollback ? rollbackURL : nil
            )
        } catch {
            if faultInjection == .leaveInterruptedAfterOriginalMoved
                || faultInjection == .leaveInterruptedAfterRollbackCopied {
                throw error
            }
            var recoveredPriorState = false
            if rollbackReady && FileManager.default.fileExists(atPath: rollbackURL.path) {
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

    private static func prepareRestoredStore(
        at databaseURL: URL,
        operationID: UUID,
        registrationsRetainedFromCurrentSnapshot: [ProjectRegistration] = []
    ) throws {
        let connection = try SQLiteConnection(url: databaseURL, createIfMissing: false)
        defer { connection.close() }
        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let now = ISO8601DateFormatter().string(from: Date())
            try retainProposalHistoryBeforeAuthorityRotation(
                connection: connection,
                removedAt: now,
                excluding: Set(registrationsRetainedFromCurrentSnapshot.map(registrationKey))
            )
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

    private static func retainProposalHistoryBeforeAuthorityRotation(
        connection: SQLiteConnection,
        removedAt: String,
        excluding registrations: Set<String> = []
    ) throws {
        let rows = try connection.rows(
            """
            SELECT projects.id, projects.name, projects.lifecycle,
                   registrations.registration_id, registrations.request_generation
            FROM projects
            JOIN project_registrations registrations ON registrations.project_id = projects.id
            WHERE EXISTS (
                SELECT 1 FROM plan_change_proposals proposals WHERE proposals.project_id = projects.id
            )
               OR EXISTS (SELECT 1 FROM ticket_retirements WHERE project_id = projects.id)
               OR EXISTS (SELECT 1 FROM delivery_goal_obligations WHERE project_id = projects.id)
               OR EXISTS (SELECT 1 FROM phase_lifecycle_events WHERE project_id = projects.id)
            ORDER BY projects.id
            """
        )
        for row in rows {
            guard case let .text(projectID)? = row["id"],
                  case let .text(projectName)? = row["name"],
                  case let .text(lifecycle)? = row["lifecycle"],
                  case let .text(registrationID)? = row["registration_id"],
                  case let .integer(generation)? = row["request_generation"] else {
                throw ApplicationRecoveryError.invalidBackup("proposal history ownership is invalid")
            }
            let lifecycleRetainedFromCurrentSnapshot = registrations.contains(registrationKey(
                .init(
                    projectID: .init(rawValue: projectID),
                    registrationID: registrationID,
                    requestGeneration: generation
                )
            ))
            let removalID = UUID().uuidString.lowercased()
            let project = SQLiteValue.text(projectID)
            let removal = SQLiteValue.text(removalID)
            func count(_ table: String) throws -> Int64 {
                try connection.scalarInt(
                    "SELECT COUNT(*) FROM \(table) WHERE project_id = ?",
                    bindings: [project]
                ) ?? 0
            }
            try connection.execute(
                """
                INSERT INTO removed_projects (
                    removal_id, historical_project_id, project_name, original_lifecycle,
                    registration_id, request_generation, removed_at, phase_count,
                    ticket_count, evidence_count, history_count
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    removal, project, .text(projectName), .text(lifecycle),
                    .text(registrationID), .integer(generation), .text(removedAt),
                    .integer(try count("phases")), .integer(try count("tickets")),
                    .integer(try count("evidence")), .integer(try count("audit_events")),
                ]
            )
            try connection.execute(
                "INSERT INTO project_removal_authorizations (project_id, registration_id, removal_id) VALUES (?, ?, ?)",
                bindings: [project, .text(registrationID), removal]
            )
            if !lifecycleRetainedFromCurrentSnapshot {
                try connection.execute(
                    "INSERT INTO retained_phase_lifecycles SELECT ?, lifecycles.project_id, lifecycles.phase_id, phases.name, lifecycles.lifecycle, lifecycles.revision, lifecycles.completion_baseline_digest, lifecycles.created_at, lifecycles.updated_at, lifecycles.completed_at FROM phase_lifecycles lifecycles JOIN phases ON phases.project_id=lifecycles.project_id AND phases.id=lifecycles.phase_id WHERE lifecycles.project_id=?",
                    bindings: [removal, project]
                )
                try connection.execute(
                    "INSERT INTO retained_phase_lifecycle_events SELECT ?, project_id, phase_id, revision, previous_lifecycle, current_lifecycle, action, reason, audit_event_id, registration_id, request_generation, planning_baseline_digest, created_at FROM phase_lifecycle_events WHERE project_id=?",
                    bindings: [removal, project]
                )
            }
            try connection.execute(
                "INSERT INTO retained_plan_change_proposals SELECT ?, project_id, id, current_version, created_at, updated_at FROM plan_change_proposals WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_ticket_retirements SELECT ?, retirements.project_id, retirements.ticket_id, tickets.outcome, retirements.disposition, retirements.reason, retirements.last_phase_id, retirements.last_lane, retirements.audit_event_id, retirements.retired_at FROM ticket_retirements retirements JOIN tickets ON tickets.project_id=retirements.project_id AND tickets.id=retirements.ticket_id WHERE retirements.project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_ticket_successor_links SELECT ?, project_id, original_ticket_id, successor_ticket_id, relation, sort_order, audit_event_id, created_at FROM ticket_successor_links WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_delivery_goal_obligations SELECT ?, project_id, phase_id, goal_id, ticket_id, scope, assessment, created_at FROM delivery_goal_obligations WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_delivery_goal_obligation_lineage SELECT ?, project_id, source_phase_id, source_goal_id, source_ticket_id, descendant_phase_id, descendant_goal_id, descendant_ticket_id, reason, audit_event_id, created_at FROM delivery_goal_obligation_lineage WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_delivery_goal_obligation_drops SELECT ?, project_id, phase_id, goal_id, ticket_id, reason, audit_event_id, created_at FROM delivery_goal_obligation_drops WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_plan_change_proposal_versions SELECT ?, project_id, proposal_id, version, registration_id, request_generation, baseline_digest, baseline_data, operations_data, diff_data, source_impacts_data, rationale, created_at FROM plan_change_proposal_versions WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_plan_change_proposal_decisions SELECT ?, project_id, proposal_id, version, id, disposition, baseline_digest, registration_id, request_generation, actor_id, created_at FROM plan_change_proposal_decisions WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute(
                "INSERT INTO retained_plan_change_proposal_applications SELECT ?, project_id, proposal_id, version, id, decision_id, audit_event_id, applied_at FROM plan_change_proposal_applications WHERE project_id = ?",
                bindings: [removal, project]
            )
            try connection.execute("DELETE FROM plan_change_proposal_applications WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM plan_change_proposal_decisions WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM plan_change_proposal_versions WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM plan_change_proposals WHERE project_id = ?", bindings: [project])
            try connection.execute("DELETE FROM project_removal_authorizations WHERE project_id = ?", bindings: [project])
        }
    }

    private static func registrationKey(_ registration: ProjectRegistration) -> String {
        "\(registration.projectID.rawValue)\u{1F}\(registration.registrationID)\u{1F}\(registration.requestGeneration)"
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
            INSERT OR IGNORE INTO retained_ticket_retirements
                SELECT * FROM current_state.retained_ticket_retirements;
            INSERT OR IGNORE INTO retained_ticket_successor_links
                SELECT * FROM current_state.retained_ticket_successor_links;
            INSERT OR IGNORE INTO retained_delivery_goal_obligations
                SELECT * FROM current_state.retained_delivery_goal_obligations;
            INSERT OR IGNORE INTO retained_delivery_goal_obligation_lineage
                SELECT * FROM current_state.retained_delivery_goal_obligation_lineage;
            INSERT OR IGNORE INTO retained_delivery_goal_obligation_drops
                SELECT * FROM current_state.retained_delivery_goal_obligation_drops;
            INSERT OR IGNORE INTO retained_phase_lifecycles
                SELECT * FROM current_state.retained_phase_lifecycles;
            INSERT OR IGNORE INTO retained_phase_lifecycle_events
                SELECT * FROM current_state.retained_phase_lifecycle_events;
            INSERT OR IGNORE INTO retained_project_activity_events
                SELECT * FROM current_state.retained_project_activity_events;
            INSERT OR IGNORE INTO retained_delivery_goal_assignment_events
                SELECT * FROM current_state.retained_delivery_goal_assignment_events;
            INSERT OR IGNORE INTO retained_ticket_reference_links
                SELECT * FROM current_state.retained_ticket_reference_links;
            INSERT OR IGNORE INTO retained_ticket_reference_versions
                SELECT * FROM current_state.retained_ticket_reference_versions;
            INSERT OR IGNORE INTO retained_plan_change_proposals
                SELECT * FROM current_state.retained_plan_change_proposals;
            INSERT OR IGNORE INTO retained_plan_change_proposal_versions
                SELECT * FROM current_state.retained_plan_change_proposal_versions;
            INSERT OR IGNORE INTO retained_plan_change_proposal_decisions
                SELECT * FROM current_state.retained_plan_change_proposal_decisions;
            INSERT OR IGNORE INTO retained_plan_change_proposal_applications
                SELECT * FROM current_state.retained_plan_change_proposal_applications;
            INSERT OR IGNORE INTO audit_events
                SELECT * FROM current_state.audit_events
                WHERE historical_project_id IS NOT NULL AND project_id IS NULL;

            INSERT OR IGNORE INTO removed_projects (
                removal_id, historical_project_id, project_name, original_lifecycle,
                registration_id, request_generation, removed_at, phase_count,
                ticket_count, evidence_count, history_count
            )
            SELECT lower(hex(randomblob(16))), projects.id, projects.name, projects.lifecycle,
                registrations.registration_id, registrations.request_generation,
                strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                (SELECT COUNT(*) FROM current_state.phases WHERE project_id = projects.id),
                (SELECT COUNT(*) FROM current_state.tickets WHERE project_id = projects.id),
                (SELECT COUNT(*) FROM current_state.evidence WHERE project_id = projects.id),
                (SELECT COUNT(*) FROM current_state.audit_events WHERE project_id = projects.id)
            FROM current_state.projects projects
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = projects.id;

            INSERT OR IGNORE INTO audit_events (
                id, actor_id, thread_id, reason, created_at, thread_attribution,
                project_id, entity_type, entity_id,
                historical_project_id, historical_registration_id,
                event_facts_recorded, event_provenance, event_occurred_at,
                event_recorded_at, event_project_name, event_registration_id,
                event_request_generation, event_ticket_id, event_phase_id,
                event_phase_name, event_ticket_outcome, event_previous_lane,
                event_current_lane, event_previous_phase_id, event_current_phase_id
            )
            SELECT audit.id, audit.actor_id, audit.thread_id, audit.reason, audit.created_at,
                audit.thread_attribution, NULL, audit.entity_type, audit.entity_id,
                audit.project_id, registrations.registration_id,
                audit.event_facts_recorded, audit.event_provenance,
                audit.event_occurred_at, audit.event_recorded_at,
                audit.event_project_name, audit.event_registration_id,
                audit.event_request_generation, audit.event_ticket_id,
                audit.event_phase_id, audit.event_phase_name,
                audit.event_ticket_outcome, audit.event_previous_lane,
                audit.event_current_lane, audit.event_previous_phase_id,
                audit.event_current_phase_id
            FROM current_state.audit_events audit
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = audit.project_id;

            INSERT OR IGNORE INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, observed_at, ticket_id,
                delivery_goal_id, originating_thread_id, runtime_state
            )
            SELECT removed.removal_id, 'runtime', goals.thread_id || '|' || goals.id, goals.status, goals.text,
                goals.last_observed_at, links.ticket_id, goals.id, goals.thread_id, goals.status
            FROM current_state.observed_goals goals
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = goals.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = goals.project_id
             AND removed.registration_id = registrations.registration_id
            LEFT JOIN current_state.ticket_goal_links links
              ON links.project_id = goals.project_id
             AND links.goal_id = goals.id AND links.thread_id = goals.thread_id;

            INSERT OR IGNORE INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, recorded_at, ticket_id
            )
            SELECT removed.removal_id, 'review', reviews.id, 'Review ' || reviews.status,
                reviews.summary,
                (SELECT MAX(created_at) FROM current_state.audit_events audit
                 WHERE audit.project_id = reviews.project_id
                   AND audit.entity_type = 'review_item' AND audit.entity_id = reviews.id),
                reviews.ticket_id
            FROM current_state.review_items reviews
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = reviews.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = reviews.project_id
             AND removed.registration_id = registrations.registration_id
            WHERE reviews.status <> 'open';

            INSERT OR IGNORE INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, occurred_at, ticket_id, runtime_state
            )
            SELECT removed.removal_id, 'completion', completions.id, 'Completed',
                completions.summary, completions.created_at, completions.ticket_id, 'completed'
            FROM current_state.completion_records completions
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = completions.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = completions.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_project_activity_events (
                removal_id, source, source_id, title, detail, occurred_at, recorded_at,
                ticket_id, notification_state, notification_status_text
            )
            SELECT removed.removal_id, 'notification', notifications.id,
                COALESCE(notifications.title, notifications.fingerprint),
                COALESCE(notifications.message, 'Persisted notification delivery event.'),
                notifications.created_at, notifications.completed_at, notifications.ticket_id,
                notifications.state, 'Preserved from the displaced application registration'
            FROM current_state.notification_events notifications
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = notifications.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = notifications.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_delivery_goal_assignment_events (
                removal_id, audit_event_id, project_id, phase_id, ticket_id,
                previous_goal_id, current_goal_id, revision, action
            )
            SELECT removed.removal_id, assignments.audit_event_id, assignments.project_id,
                assignments.phase_id, assignments.ticket_id, assignments.previous_goal_id,
                assignments.current_goal_id, assignments.revision, assignments.action
            FROM current_state.delivery_goal_assignment_events assignments
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = assignments.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = assignments.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_phase_lifecycles
            SELECT removed.removal_id, lifecycles.project_id, lifecycles.phase_id,
                phases.name, lifecycles.lifecycle, lifecycles.revision,
                lifecycles.completion_baseline_digest, lifecycles.created_at,
                lifecycles.updated_at, lifecycles.completed_at
            FROM current_state.phase_lifecycles lifecycles
            JOIN current_state.phases phases
              ON phases.project_id=lifecycles.project_id AND phases.id=lifecycles.phase_id
            JOIN current_state.project_registrations registrations
              ON registrations.project_id=lifecycles.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id=lifecycles.project_id
             AND removed.registration_id=registrations.registration_id;

            INSERT OR IGNORE INTO retained_phase_lifecycle_events
            SELECT removed.removal_id, events.project_id, events.phase_id, events.revision,
                events.previous_lifecycle, events.current_lifecycle, events.action,
                events.reason, events.audit_event_id, events.registration_id,
                events.request_generation, events.planning_baseline_digest,
                events.created_at
            FROM current_state.phase_lifecycle_events events
            JOIN current_state.project_registrations registrations
              ON registrations.project_id=events.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id=events.project_id
             AND removed.registration_id=registrations.registration_id;

            INSERT OR IGNORE INTO retained_ticket_retirements
            SELECT removed.removal_id, retirements.project_id, retirements.ticket_id,
                tickets.outcome, retirements.disposition, retirements.reason, retirements.last_phase_id,
                retirements.last_lane, retirements.audit_event_id, retirements.retired_at
            FROM current_state.ticket_retirements retirements
            JOIN current_state.tickets tickets
              ON tickets.project_id=retirements.project_id AND tickets.id=retirements.ticket_id
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = retirements.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = retirements.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_ticket_successor_links
            SELECT removed.removal_id, links.project_id, links.original_ticket_id,
                links.successor_ticket_id, links.relation, links.sort_order,
                links.audit_event_id, links.created_at
            FROM current_state.ticket_successor_links links
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = links.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = links.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_delivery_goal_obligations
            SELECT removed.removal_id, obligations.project_id, obligations.phase_id,
                obligations.goal_id, obligations.ticket_id, obligations.scope,
                obligations.assessment, obligations.created_at
            FROM current_state.delivery_goal_obligations obligations
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = obligations.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = obligations.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_delivery_goal_obligation_lineage
            SELECT removed.removal_id, lineage.project_id, lineage.source_phase_id,
                lineage.source_goal_id, lineage.source_ticket_id,
                lineage.descendant_phase_id, lineage.descendant_goal_id,
                lineage.descendant_ticket_id, lineage.reason,
                lineage.audit_event_id, lineage.created_at
            FROM current_state.delivery_goal_obligation_lineage lineage
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = lineage.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = lineage.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_delivery_goal_obligation_drops
            SELECT removed.removal_id, drops.project_id, drops.phase_id, drops.goal_id,
                drops.ticket_id, drops.reason, drops.audit_event_id, drops.created_at
            FROM current_state.delivery_goal_obligation_drops drops
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = drops.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = drops.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_ticket_reference_links (
                removal_id, historical_project_id, ticket_id, link_id, kind,
                repository_id, artifact_id, current_version, relationship,
                retired_version, retired_at, retirement_reason, link_set_revision,
                created_at, updated_at
            )
            SELECT removed.removal_id, links.project_id, links.ticket_id, links.id,
                links.kind, links.repository_id, links.artifact_id, links.current_version,
                links.relationship, links.retired_version, links.retired_at,
                links.retirement_reason, sets.revision, links.created_at, links.updated_at
            FROM current_state.ticket_reference_links links
            JOIN current_state.ticket_reference_link_sets sets
              ON sets.project_id = links.project_id AND sets.ticket_id = links.ticket_id
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = links.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = links.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_ticket_reference_versions (
                removal_id, historical_project_id, ticket_id, link_id, version,
                content_digest, source_local_id, locator, catalog_version,
                catalog_digest, observed_path, observed_lifecycle,
                observed_authority, created_at
            )
            SELECT removed.removal_id, versions.project_id, versions.ticket_id,
                versions.link_id, versions.version, versions.content_digest,
                versions.source_local_id, versions.locator, versions.catalog_version,
                versions.catalog_digest, versions.observed_path,
                versions.observed_lifecycle, versions.observed_authority,
                versions.created_at
            FROM current_state.ticket_reference_versions versions
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = versions.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = versions.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_plan_change_proposals (
                removal_id, historical_project_id, proposal_id, current_version,
                created_at, updated_at
            )
            SELECT removed.removal_id, proposals.project_id, proposals.id,
                proposals.current_version, proposals.created_at, proposals.updated_at
            FROM current_state.plan_change_proposals proposals
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = proposals.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = proposals.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_plan_change_proposal_versions (
                removal_id, historical_project_id, proposal_id, version,
                registration_id, request_generation, baseline_digest, baseline_data,
                operations_data, diff_data, source_impacts_data, rationale, created_at
            )
            SELECT removed.removal_id, versions.project_id, versions.proposal_id,
                versions.version, versions.registration_id, versions.request_generation,
                versions.baseline_digest, versions.baseline_data, versions.operations_data,
                versions.diff_data, versions.source_impacts_data, versions.rationale,
                versions.created_at
            FROM current_state.plan_change_proposal_versions versions
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = versions.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = versions.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_plan_change_proposal_decisions (
                removal_id, historical_project_id, proposal_id, version, id,
                disposition, baseline_digest, registration_id, request_generation,
                actor_id, created_at
            )
            SELECT removed.removal_id, decisions.project_id, decisions.proposal_id,
                decisions.version, decisions.id, decisions.disposition,
                decisions.baseline_digest, decisions.registration_id,
                decisions.request_generation, decisions.actor_id, decisions.created_at
            FROM current_state.plan_change_proposal_decisions decisions
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = decisions.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = decisions.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT OR IGNORE INTO retained_plan_change_proposal_applications (
                removal_id, historical_project_id, proposal_id, version, id,
                decision_id, audit_event_id, applied_at
            )
            SELECT removed.removal_id, applications.project_id,
                applications.proposal_id, applications.version, applications.id,
                applications.decision_id, applications.audit_event_id,
                applications.applied_at
            FROM current_state.plan_change_proposal_applications applications
            JOIN current_state.project_registrations registrations
              ON registrations.project_id = applications.project_id
            JOIN removed_projects removed
              ON removed.historical_project_id = applications.project_id
             AND removed.registration_id = registrations.registration_id;

            INSERT INTO observed_threads (id, project_id, status, last_observed_at)
            SELECT id, project_id, status, last_observed_at
            FROM current_state.observed_threads
            WHERE project_id IN (SELECT id FROM projects)
            ON CONFLICT(id) DO UPDATE SET
                status = excluded.status,
                last_observed_at = excluded.last_observed_at
            WHERE observed_threads.project_id = excluded.project_id
              AND excluded.last_observed_at > observed_threads.last_observed_at;

            INSERT INTO observed_goals (id, project_id, thread_id, status, text, last_observed_at)
            SELECT goals.id, goals.project_id, goals.thread_id, goals.status,
                goals.text, goals.last_observed_at
            FROM current_state.observed_goals goals
            WHERE goals.project_id IN (SELECT id FROM projects)
              AND EXISTS (
                SELECT 1 FROM observed_threads threads
                WHERE threads.id = goals.thread_id AND threads.project_id = goals.project_id
              )
            ON CONFLICT(id) DO UPDATE SET
                thread_id = excluded.thread_id,
                status = excluded.status,
                text = excluded.text,
                last_observed_at = excluded.last_observed_at
            WHERE observed_goals.project_id = excluded.project_id
              AND excluded.last_observed_at > observed_goals.last_observed_at;

            INSERT INTO notification_occurrences (
                subject_key, project_id, event_kind, subject_id, generation, is_active
            )
            SELECT subject_key, project_id, event_kind, subject_id, generation, is_active
            FROM current_state.notification_occurrences
            WHERE project_id IN (SELECT id FROM projects)
            ON CONFLICT(subject_key) DO UPDATE SET
                generation = excluded.generation,
                is_active = excluded.is_active;

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

            """)
            try connection.execute("COMMIT")
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    private static func recoveryTargets(in connection: SQLiteConnection) throws -> [ApplicationRecoveryTarget] {
        try connection.rows(
            """
            SELECT projects.name, registrations.project_id,
                registrations.registration_id, registrations.request_generation
            FROM project_registrations registrations
            JOIN projects ON projects.id = registrations.project_id
            ORDER BY projects.name, registrations.project_id
            """
        ).compactMap { row in
            guard case let .text(name)? = row["name"],
                  case let .text(projectID)? = row["project_id"],
                  case let .text(registrationID)? = row["registration_id"],
                  case let .integer(generation)? = row["request_generation"] else { return nil }
            return ApplicationRecoveryTarget(
                name: name,
                registration: .init(
                    projectID: .init(rawValue: projectID),
                    registrationID: registrationID,
                    requestGeneration: generation
                )
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

    private static func copyStoreFiles(from source: URL, to destination: URL, requireDatabase: Bool) throws {
        for suffix in sidecarSuffixes {
            let sourceURL = URL(fileURLWithPath: source.path + suffix)
            let destinationURL = URL(fileURLWithPath: destination.path + suffix)
            var metadata = stat()
            if lstat(sourceURL.path, &metadata) != 0 {
                if suffix.isEmpty && requireDatabase { throw ApplicationRecoveryError.replacementFailed }
                continue
            }
            guard metadata.st_mode & S_IFMT == S_IFREG else {
                throw ApplicationRecoveryError.unsafeStorePlacement
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
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
    let preserveRollback: Bool?

    func withPhase(_ phase: Phase) -> Self {
        .init(
            operationID: operationID,
            phase: phase,
            rollbackPath: rollbackPath,
            stagingPath: stagingPath,
            preserveRollback: preserveRollback
        )
    }
}
