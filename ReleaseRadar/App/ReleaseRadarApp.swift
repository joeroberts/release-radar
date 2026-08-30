import AppKit
import Darwin
import OSLog
import ReleaseRadarCore
import SwiftUI

enum AppHostMode: Equatable {
    case application
    case xctestHost(databaseURL: URL)
    case xctestHostUnavailable(databaseURL: URL)

}

enum XCTestHostPreparation {
    case application
    case xctestHost(databaseURL: URL, store: DeliveryStore)
    case xctestHostUnavailable(databaseURL: URL)
}

enum AppLaunchConfiguration {
    static func isXCTestHost(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    static func hostMode(
        environment: [String: String],
        temporaryDirectory: URL,
        processIdentifier: Int32,
        fileManager: FileManager = .default
    ) -> AppHostMode {
        switch prepareXCTestHost(
            environment: environment,
            temporaryDirectory: temporaryDirectory,
            processIdentifier: processIdentifier,
            fileManager: fileManager
        ) {
        case .application:
            .application
        case let .xctestHost(databaseURL, _):
            .xctestHost(databaseURL: databaseURL)
        case let .xctestHostUnavailable(databaseURL):
            .xctestHostUnavailable(databaseURL: databaseURL)
        }
    }

    static func prepareXCTestHost(
        environment: [String: String],
        temporaryDirectory: URL,
        processIdentifier: Int32,
        fileManager _: FileManager = .default,
        storeFactory: (URL) -> DeliveryStore = { DeliveryStore(databaseURL: $0) }
    ) -> XCTestHostPreparation {
        guard isXCTestHost(environment: environment) else { return .application }

        let hostDirectory = temporaryDirectory.standardizedFileURL
            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
            .standardizedFileURL
        let databaseURL = hostDirectory
            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
            .standardizedFileURL
        guard exclusiveCreateDirectory(at: hostDirectory) else {
            return .xctestHostUnavailable(databaseURL: databaseURL)
        }

        return .xctestHost(databaseURL: databaseURL, store: storeFactory(databaseURL))
    }

    private static func exclusiveCreateDirectory(at url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return mkdir(path, S_IRWXU) == 0
        }
    }

    static func externalServicesSuppressed(arguments: [String], isDebugBuild: Bool) -> Bool {
        isDebugBuild && arguments.contains("--rr10-capture")
    }

    static func shouldSeedSampleData(arguments: [String], isDebugBuild: Bool) -> Bool {
        externalServicesSuppressed(arguments: arguments, isDebugBuild: isDebugBuild)
            && !arguments.contains("--rr10-empty-store")
    }

#if DEBUG
    static func rr9ActivePhaseCaptureScenario(
        arguments: [String],
        isDebugBuild: Bool
    ) -> RR9ActivePhaseCaptureScenario? {
        let captureFlag = "--rr10-capture"
        let emptyStoreFlag = "--rr10-empty-store"
        guard isDebugBuild,
              arguments.filter({ $0 == captureFlag }).count == 1,
              arguments.filter({ $0 == emptyStoreFlag }).count == 1 else { return nil }
        let prefix = "--rr9-active-phase-fixture="
        let scenarioArguments = arguments.filter { $0.hasPrefix(prefix) }
        guard scenarioArguments.count == 1 else { return nil }
        return RR9ActivePhaseCaptureScenario(
            rawValue: String(scenarioArguments[0].dropFirst(prefix.count))
        )
    }
#endif
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "AgentBridge")
    private var agentBridgeHost: AgentBridgeApplicationHost?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppLaunchConfiguration.isXCTestHost(environment: ProcessInfo.processInfo.environment) else {
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
#if DEBUG
        guard !AppLaunchConfiguration.externalServicesSuppressed(
            arguments: ProcessInfo.processInfo.arguments,
            isDebugBuild: true
        ) else {
            return
        }
#endif
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
    @State private var model: AppModel?
    private let xctestHostStore: DeliveryStore?

    init() {
        let processInfo = ProcessInfo.processInfo
        let hostPreparation = AppLaunchConfiguration.prepareXCTestHost(
            environment: processInfo.environment,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            processIdentifier: processInfo.processIdentifier
        )
        let xctestLogger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "XCTestHostIsolation")

        switch hostPreparation {
        case let .xctestHost(databaseURL, store):
            xctestHostStore = store
            _model = State(initialValue: nil)
            xctestLogger.notice(
                "Using isolated XCTest host database \(databaseURL.path, privacy: .public) for PID \(processInfo.processIdentifier)"
            )
            return
        case let .xctestHostUnavailable(databaseURL):
            xctestHostStore = nil
            _model = State(initialValue: nil)
            xctestLogger.error(
                "XCTest host directory preparation unavailable for \(databaseURL.path, privacy: .public) for PID \(processInfo.processIdentifier); rendering inert host"
            )
            return
        case .application:
            xctestHostStore = nil
            break
        }

        let services = ReleaseRadarAppServices.shared
#if DEBUG
        let isDebugBuild = true
#else
        let isDebugBuild = false
#endif
        let arguments = ProcessInfo.processInfo.arguments
        let externalServicesSuppressed = AppLaunchConfiguration.externalServicesSuppressed(
            arguments: arguments,
            isDebugBuild: isDebugBuild
        )
        let seedSampleData = AppLaunchConfiguration.shouldSeedSampleData(
            arguments: arguments,
            isDebugBuild: isDebugBuild
        )
#if DEBUG
        let model = AppModel(
            store: services.store,
            codexPluginCoordinator: services.codexPluginCoordinator,
            codexPluginShippedVersion: services.codexPluginShippedVersion,
            pushoverKeychain: services.keychain,
            notificationCoordinator: services.notificationCoordinator,
            externalServicesSuppressed: externalServicesSuppressed,
            seedSampleData: seedSampleData,
            rr9ActivePhaseCaptureScenario: AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
                arguments: arguments,
                isDebugBuild: true
            )
        )
#else
        let model = AppModel(
            store: services.store,
            codexPluginCoordinator: services.codexPluginCoordinator,
            codexPluginShippedVersion: services.codexPluginShippedVersion,
            pushoverKeychain: services.keychain,
            notificationCoordinator: services.notificationCoordinator,
            externalServicesSuppressed: externalServicesSuppressed,
            seedSampleData: seedSampleData
        )
#endif
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup("Release Radar", id: "main") {
            if let model {
                SidebarView(model: model)
                    .frame(minWidth: 760, minHeight: 520)
            } else {
                Text("Release Radar XCTest host is isolated")
            }
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

        Window("Add Project", id: "add-project") {
            if let model {
                AddProjectWindowView(model: model)
                    .frame(minWidth: 680, minHeight: 500)
            } else {
                Text("Release Radar XCTest host is isolated")
            }
        }
        .defaultSize(width: 760, height: 560)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Release Radar", systemImage: "dot.radiowaves.left.and.right") {
            if let model {
                MenuBarContent(model: model)
            } else {
                Text("Release Radar XCTest host is isolated")
            }
        }

        Settings {
            if let model {
                SettingsView(model: model)
            } else {
                Text("Release Radar XCTest host is isolated")
            }
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
