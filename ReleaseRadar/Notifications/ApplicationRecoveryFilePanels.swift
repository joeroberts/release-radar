import AppKit
import Foundation

@MainActor
enum ApplicationRecoveryFilePanels {
    static func chooseBackupDestination() -> URL? {
        let panel = makeBackupDestinationPanel()
        guard panel.runModal() == .OK, let folder = panel.url else { return nil }
        return backupPackageURL(in: folder)
    }

    static func makeBackupDestinationPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Create Release Radar Backup"
        panel.prompt = "Review Backup"
        panel.message = "Choose one existing folder. Release Radar will create a new backup package inside it."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = false
        return panel
    }

    static func backupPackageURL(in folder: URL, identifier: UUID = UUID()) -> URL {
        folder.appendingPathComponent(
            "Release Radar Backup \(identifier.uuidString).release-radar-backup",
            isDirectory: true
        )
    }

    static func chooseRestorePackage() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Release Radar Backup"
        panel.prompt = "Review Restore"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              url.pathExtension == "release-radar-backup" else { return nil }
        return url
    }
}

enum ApplicationRecoverySecurityScopeError: Error, LocalizedError {
    case accessDenied

    var errorDescription: String? {
        "Release Radar could not access the selected backup folder. Choose the folder again and retry."
    }
}

@MainActor
enum ApplicationRecoverySecurityScope {
    static func withAccess<T>(
        to folder: URL,
        start: (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stop: (URL) -> Void = { $0.stopAccessingSecurityScopedResource() },
        operation: () async throws -> T
    ) async throws -> T {
        guard start(folder) else { throw ApplicationRecoverySecurityScopeError.accessDenied }
        defer { stop(folder) }
        return try await operation()
    }
}
