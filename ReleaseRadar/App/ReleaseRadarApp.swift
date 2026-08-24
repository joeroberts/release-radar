import AppKit
import OSLog
import ReleaseRadarCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "AgentBridge")
    private var agentBridgeHost: AgentBridgeApplicationHost?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        Task { [weak self] in
            do {
                _ = try await self?.startAgentBridge()
            } catch {
                self?.logger.error("Agent bridge startup failed: \(error.localizedDescription)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        agentBridgeHost?.disconnectCallback()
        agentBridgeHost = nil
    }

    func startAgentBridge(
        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL(),
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void = { _ in },
        afterDispatchBeforeReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in }
    ) async throws -> AgentBridgeApplicationHost {
        if let agentBridgeHost {
            return agentBridgeHost
        }
        let host = try await AgentBridgeApplicationHost.start(
            databaseURL: databaseURL,
            beforeDispatch: beforeDispatch,
            afterDispatchBeforeReply: afterDispatchBeforeReply
        )
        agentBridgeHost = host
        return host
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
