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
