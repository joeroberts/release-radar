import CryptoKit
import Darwin
import Foundation

public enum ApplicationBackupInclusion: String, Codable, Equatable, Sendable {
    case localStore
    case preferences
    case history
    case pluginReceipts
    case notificationHistory
}

public enum ApplicationBackupExclusion: String, Codable, Equatable, Sendable {
    case credentials
    case devicePermissions
    case repositories
    case portableProjectFiles
}

public enum ApplicationBackupError: Error, LocalizedError, Equatable, Sendable {
    case unsafePlacement
    case destinationExists
    case stalePreview
    case invalidPackage(String)

    public var errorDescription: String? {
        switch self {
        case .unsafePlacement:
            "Choose an existing local folder that does not pass through a symbolic link."
        case .destinationExists:
            "A backup already exists at the selected location. Choose a new name."
        case .stalePreview:
            "The application data changed after confirmation. Review the current backup preview and try again."
        case let .invalidPackage(message):
            "The backup package is invalid: \(message)"
        }
    }
}

public struct ApplicationBackupPreview: Equatable, Sendable {
    public let destinationURL: URL
    public let projectCount: Int
    public let includes: [ApplicationBackupInclusion]
    public let excludes: [ApplicationBackupExclusion]
}

public struct ApplicationBackupReceipt: Equatable, Sendable {
    public let backupID: UUID
    public let packageURL: URL
    public let createdAt: Date
}

public struct ApplicationBackupManifest: Codable, Equatable, Sendable {
    public static let formatIdentifier = "com.rekonlabs.release-radar.full-backup.v1"
    public static let manifestFileName = "manifest.json"
    public static let databaseFileName = "release-radar.sqlite"

    public let format: String
    public let backupID: UUID
    public let createdAt: Date
    public let schemaVersion: Int
    public let databaseSHA256: String
    public let includes: [ApplicationBackupInclusion]
    public let excludes: [ApplicationBackupExclusion]

    public static func load(from packageURL: URL) throws -> ApplicationBackupManifest {
        try BackupPathValidator.validateExistingPackage(packageURL)
        let contents = try FileManager.default.contentsOfDirectory(
            at: packageURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        guard Set(contents.map(\.lastPathComponent)) == [manifestFileName, databaseFileName] else {
            throw ApplicationBackupError.invalidPackage("the package inventory is unsupported")
        }
        let manifestURL = packageURL.appendingPathComponent(manifestFileName)
        let databaseURL = packageURL.appendingPathComponent(databaseFileName)
        guard try BackupPathValidator.isRegularFileWithoutFollowingLinks(manifestURL),
              try BackupPathValidator.isRegularFileWithoutFollowingLinks(databaseURL)
        else { throw ApplicationBackupError.invalidPackage("required files are missing or unsafe") }
        let manifestData = try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        let allowedKeys: Set<String> = [
            "format", "backupID", "createdAt", "schemaVersion", "databaseSHA256", "includes", "excludes",
        ]
        guard let object = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              Set(object.keys) == allowedKeys else {
            throw ApplicationBackupError.invalidPackage("the manifest fields are unsupported")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(Self.self, from: manifestData)
        guard manifest.format == formatIdentifier,
              manifest.includes == ApplicationBackupManager.supportedInclusions,
              manifest.excludes == ApplicationBackupManager.supportedExclusions
        else { throw ApplicationBackupError.invalidPackage("the manifest format is unsupported") }
        return manifest
    }
}

public actor ApplicationBackupManager {
    static let supportedInclusions: [ApplicationBackupInclusion] = [
        .localStore, .preferences, .history, .pluginReceipts, .notificationHistory,
    ]
    static let supportedExclusions: [ApplicationBackupExclusion] = [
        .credentials, .devicePermissions, .repositories, .portableProjectFiles,
    ]

    private let store: DeliveryStore
    private let databaseURL: URL

    public init(store: DeliveryStore, databaseURL: URL) {
        self.store = store
        self.databaseURL = databaseURL
    }

    public func previewBackup(destinationURL: URL) async throws -> ApplicationBackupPreview {
        try BackupPathValidator.validateNewPackageDestination(destinationURL)
        let projectCount = try await store.read {
            Int(try $0.scalarInt("SELECT COUNT(*) FROM projects") ?? 0)
        }
        return .init(
            destinationURL: destinationURL,
            projectCount: projectCount,
            includes: Self.supportedInclusions,
            excludes: Self.supportedExclusions
        )
    }

    public func createBackup(_ preview: ApplicationBackupPreview) async throws -> ApplicationBackupReceipt {
        try BackupPathValidator.validateNewPackageDestination(preview.destinationURL)
        let currentProjectCount = try await store.read {
            Int(try $0.scalarInt("SELECT COUNT(*) FROM projects") ?? 0)
        }
        guard currentProjectCount == preview.projectCount,
              preview.includes == Self.supportedInclusions,
              preview.excludes == Self.supportedExclusions else {
            throw ApplicationBackupError.stalePreview
        }
        let parent = preview.destinationURL.deletingLastPathComponent()
        let stagingURL = parent.appendingPathComponent(".release-radar-backup-\(UUID().uuidString).staging", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: false)
        var keepStaging = false
        defer { if !keepStaging { try? FileManager.default.removeItem(at: stagingURL) } }

        _ = try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Create full application backup"
        ) { _ in () }

        let snapshotURL = stagingURL.appendingPathComponent(ApplicationBackupManifest.databaseFileName)
        try await store.createSnapshot(at: snapshotURL)
        let validationConnection = try SQLiteConnection(url: snapshotURL, immutableReadOnly: true, createIfMissing: false)
        defer { validationConnection.close() }
        guard try validationConnection.scalarText("PRAGMA quick_check") == "ok",
              try validationConnection.scalarInt("PRAGMA user_version") == StoreMigrations.currentVersion
        else { throw ApplicationBackupError.invalidPackage("the store snapshot failed validation") }

        let createdAt = Date()
        let backupID = UUID()
        let databaseDigest = SHA256.hash(data: try Data(contentsOf: snapshotURL, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }
            .joined()
        let manifest = ApplicationBackupManifest(
            format: ApplicationBackupManifest.formatIdentifier,
            backupID: backupID,
            createdAt: createdAt,
            schemaVersion: Int(StoreMigrations.currentVersion),
            databaseSHA256: databaseDigest,
            includes: Self.supportedInclusions,
            excludes: Self.supportedExclusions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(
            to: stagingURL.appendingPathComponent(ApplicationBackupManifest.manifestFileName),
            options: [.atomic, .completeFileProtection]
        )
        guard rename(stagingURL.path, preview.destinationURL.path) == 0 else {
            if errno == EEXIST { throw ApplicationBackupError.destinationExists }
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: preview.destinationURL.path])
        }
        keepStaging = true
        return .init(backupID: backupID, packageURL: preview.destinationURL, createdAt: createdAt)
    }
}

public struct ApplicationPreferenceReset: Sendable {
    private let store: DeliveryStore

    public init(store: DeliveryStore) {
        self.store = store
    }

    public func apply() async throws -> AlertRuleSnapshot {
        try await store.transact(
            actor: .init(id: "release-radar-owner"),
            reason: "Reset application preferences"
        ) { connection in
            try connection.execute(
                """
                UPDATE alert_rules SET is_enabled = CASE kind
                    WHEN 'paused_goals' THEN 0
                    ELSE 1
                END
                """
            )
            return try AlertRuleSnapshot.load(from: connection)
        }
    }
}

enum BackupPathValidator {
    static func validateExistingPackage(_ packageURL: URL) throws {
        guard packageURL.isFileURL,
              packageURL.pathExtension == "release-radar-backup",
              try isDirectoryWithoutFollowingLinks(packageURL) else {
            throw ApplicationBackupError.invalidPackage("the package is not a supported regular directory")
        }
        do {
            try validateExistingComponentsDoNotContainLinks(packageURL)
        } catch {
            throw ApplicationBackupError.invalidPackage("the package path contains a symbolic link")
        }
    }

    static func validateNewPackageDestination(_ destinationURL: URL) throws {
        guard destinationURL.isFileURL,
              destinationURL.pathExtension == "release-radar-backup",
              destinationURL.lastPathComponent != ".release-radar-backup"
        else { throw ApplicationBackupError.unsafePlacement }
        let parent = destinationURL.deletingLastPathComponent()
        guard try isDirectoryWithoutFollowingLinks(parent) else {
            throw ApplicationBackupError.unsafePlacement
        }
        try validateExistingComponentsDoNotContainLinks(parent)
        var metadata = stat()
        if lstat(destinationURL.path, &metadata) == 0 {
            throw ApplicationBackupError.destinationExists
        }
        guard errno == ENOENT else { throw ApplicationBackupError.unsafePlacement }
    }

    static func isDirectoryWithoutFollowingLinks(_ url: URL) throws -> Bool {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else { return false }
        return metadata.st_mode & S_IFMT == S_IFDIR
    }

    static func isRegularFileWithoutFollowingLinks(_ url: URL) throws -> Bool {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else { return false }
        return metadata.st_mode & S_IFMT == S_IFREG
    }

    private static func validateExistingComponentsDoNotContainLinks(_ url: URL) throws {
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        for component in url.standardizedFileURL.pathComponents.dropFirst() {
            current.appendPathComponent(component)
            var metadata = stat()
            guard lstat(current.path, &metadata) == 0,
                  metadata.st_mode & S_IFMT != S_IFLNK
            else { throw ApplicationBackupError.unsafePlacement }
        }
    }
}
