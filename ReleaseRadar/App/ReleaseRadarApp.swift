import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ReleaseRadarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Release Radar", id: "main") {
            SidebarView(model: model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Release Radar By Rekon Labs") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Release Radar By Rekon Labs",
                    ])
                }
            }
        }

        MenuBarExtra("Release Radar", systemImage: "dot.radiowaves.left.and.right") {
            MenuBarContent()
        }

        Settings {
            SettingsPlaceholderView()
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Release Radar") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        SettingsLink {
            Text("Settings")
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
