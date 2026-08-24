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
                let services = ReleaseRadarAppServices.shared
                await services.notificationCoordinator.initializeForLaunch()
                _ = try await self?.startAgentBridge(
                    databaseURL: DeliveryStore.applicationSupportDatabaseURL(),
                    afterReply: { envelope, result in
                        await services.notificationCoordinator.dispatchAfterCommittedCommand(
                            envelope,
                            result: result
                        )
                    }
                )
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
        afterDispatchBeforeReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in },
        afterReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in }
    ) async throws -> AgentBridgeApplicationHost {
        if let agentBridgeHost {
            return agentBridgeHost
        }
        let host = try await AgentBridgeApplicationHost.start(
            databaseURL: databaseURL,
            beforeDispatch: beforeDispatch,
            afterDispatchBeforeReply: afterDispatchBeforeReply,
            afterReply: afterReply
        )
        agentBridgeHost = host
        return host
    }
}

@main
struct ReleaseRadarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let services = ReleaseRadarAppServices.shared
        _model = State(initialValue: AppModel(
            store: services.store,
            pushoverKeychain: services.keychain,
            notificationCoordinator: services.notificationCoordinator
        ))
    }

    var body: some Scene {
        WindowGroup("Release Radar", id: "main") {
            SidebarView(model: model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1600, height: 820)
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
            MenuBarContent(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: AppModel

    private var recentNotifications: [ProjectActivityItem] {
        model.activity(for: model.currentProjectID)?.items
            .filter { $0.source == .notification }
            .prefix(3)
            .map { $0 } ?? []
    }

    var body: some View {
        Button("Open Release Radar") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        if recentNotifications.isEmpty {
            Text("No notification history")
                .foregroundStyle(.secondary)
        } else {
            Divider()
            ForEach(recentNotifications) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.headline)
                    Text(item.notificationStatusText ?? "Persisted delivery status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
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
