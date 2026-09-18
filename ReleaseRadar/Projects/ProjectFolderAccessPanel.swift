import AppKit

enum ProjectFolderAccessPanel {
    @MainActor
    static func make() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = false
        panel.prompt = "Restore Access"
        panel.message = "Choose this project's exact saved folder."
        return panel
    }

    @MainActor
    static func choose() -> URL? {
        let panel = make()
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// UI adapter; the protected context contract lives in ReleaseRadarCore.
enum CodexFolderAccessPanel {
    @MainActor
    static func make() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = false
        panel.showsHiddenFiles = true
        panel.prompt = "Use Codex Folder"
        panel.message = "Choose your existing Codex home (usually .codex), used by your current ChatGPT account. This grants Release Radar access to that folder, including authentication and history. Nothing is copied and your login is preserved."
        return panel
    }
    @MainActor
    static func choose() -> URL? {
        let panel = make()
        return panel.runModal() == .OK ? panel.url : nil
    }
}
