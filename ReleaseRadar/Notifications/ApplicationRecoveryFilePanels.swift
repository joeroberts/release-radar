import AppKit
import Foundation

@MainActor
enum ApplicationRecoveryFilePanels {
    static func chooseBackupDestination() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Create Release Radar Backup"
        panel.prompt = "Review Backup"
        panel.nameFieldStringValue = "Release Radar Backup.release-radar-backup"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, var url = panel.url else { return nil }
        if url.pathExtension != "release-radar-backup" {
            url.appendPathExtension("release-radar-backup")
        }
        return url
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
