import Foundation
import ReleaseRadarCore

actor AppNotificationCoordinator {
    typealias ActivityRefreshHandler = @Sendable (ProjectID) async -> Void
    typealias DashboardRefreshHandler = @Sendable () async -> Void

    private let store: DeliveryStore
    private let dispatcher: PushoverNotificationDispatcher
    private var activityRefreshHandler: ActivityRefreshHandler?
    private var dashboardRefreshHandler: DashboardRefreshHandler?
    private var pendingSuccessfulCommandRefresh = false
    private var successfulCommandRefreshDrainInProgress = false
    private var acceptsWork = true

    init(store: DeliveryStore, dispatcher: PushoverNotificationDispatcher) {
        self.store = store
        self.dispatcher = dispatcher
    }

    func setActivityRefreshHandler(_ handler: @escaping ActivityRefreshHandler) {
        activityRefreshHandler = handler
    }

    func setDashboardRefreshHandler(_ handler: @escaping DashboardRefreshHandler) async {
        dashboardRefreshHandler = handler
        await drainSuccessfulCommandRefreshIfPossible()
    }

    func initializeForLaunch() async {
        guard acceptsWork else { return }
        await dispatcher.prepareForLaunch()
        await dispatchPending()
    }

    func dispatchPending() async {
        guard acceptsWork else { return }
        await dispatcher.dispatchPending()
        await refreshProjectsWithNotifications()
    }

    func dispatchAfterCommittedCommand(
        _: AgentCommandEnvelope,
        result: AgentCommandResult
    ) async {
        guard acceptsWork else { return }
        guard result.error == nil else { return }
        pendingSuccessfulCommandRefresh = true
        await drainSuccessfulCommandRefreshIfPossible()
    }

    func stopAndDrain() async {
        acceptsWork = false
        pendingSuccessfulCommandRefresh = false
        await dispatcher.stopAndDrain()
    }

    private func drainSuccessfulCommandRefreshIfPossible() async {
        guard !successfulCommandRefreshDrainInProgress,
              pendingSuccessfulCommandRefresh,
              let dashboardRefreshHandler else { return }
        successfulCommandRefreshDrainInProgress = true
        defer { successfulCommandRefreshDrainInProgress = false }
        while true {
            repeat {
                pendingSuccessfulCommandRefresh = false
                await dashboardRefreshHandler()
            } while pendingSuccessfulCommandRefresh
            await dispatchPending()
            guard pendingSuccessfulCommandRefresh else { return }
        }
    }

    private func refreshProjectsWithNotifications() async {
        guard let projectIDs = try? await store.read({ connection in
            var projectIDs: [ProjectID] = []
            var offset: Int64 = 0
            while let rawID = try connection.scalarText(
                "SELECT DISTINCT project_id FROM notification_events WHERE project_id IS NOT NULL ORDER BY project_id LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                projectIDs.append(ProjectID(rawValue: rawID))
                offset += 1
            }
            return projectIDs
        }) else { return }
        for projectID in projectIDs {
            await activityRefreshHandler?(projectID)
        }
    }
}

@MainActor
final class ReleaseRadarAppServices: @unchecked Sendable {
    static let shared = ReleaseRadarAppServices()

    private(set) var store: DeliveryStore
    let keychain: PushoverKeychainStore
    private(set) var notificationCoordinator: AppNotificationCoordinator
    private(set) var codexPluginCoordinator: CodexPluginLifecycleCoordinator?
    let codexPluginShippedVersion: String
    let codexPluginShippedCapability: RecognizedPluginCapability?
    private(set) var recoveryStartupError: String?
    private(set) var recoveryResumedAtLaunch = false
    private let codexPluginPackage: CodexPluginPackage?
    private var agentBridgeHost: AgentBridgeApplicationHost?

    private init() {
        let databaseURL = DeliveryStore.applicationSupportDatabaseURL()
        let startupError: String?
        do {
            recoveryResumedAtLaunch = try ApplicationRecoveryManager.resolveInterruptedOperation(databaseURL: databaseURL)
            startupError = nil
        } catch {
            startupError = error.localizedDescription
        }
        recoveryStartupError = startupError
        let store = startupError == nil
            ? DeliveryStore(databaseURL: databaseURL)
            : DeliveryStore(unavailableDatabaseURL: databaseURL, message: startupError!)
        let keychain = PushoverKeychainStore()
        self.store = store
        self.keychain = keychain
        notificationCoordinator = AppNotificationCoordinator(
            store: store,
            dispatcher: PushoverNotificationDispatcher(store: store, credentials: keychain)
        )
        if let packageURL = Bundle.main.resourceURL?
            .appendingPathComponent("CodexPluginMarketplace", isDirectory: true),
           let package = try? CodexPluginPackage(rootURL: packageURL)
        {
            codexPluginPackage = package
            codexPluginShippedVersion = package.version
            codexPluginShippedCapability = RecognizedPluginCapability.recognize(
                manifestVersion: package.version,
                normalizedPackageDigest: package.digest
            )
            codexPluginCoordinator = CodexPluginLifecycleCoordinator(
                manager: CodexPluginLifecycleClient(),
                store: CodexPluginLifecycleStore(store: store),
                shippedVersion: package.version,
                shippedDigest: package.digest
            )
        } else {
            codexPluginPackage = nil
            codexPluginShippedVersion = "Unknown"
            codexPluginShippedCapability = nil
            codexPluginCoordinator = nil
        }
    }

    func stopAndDrainForRecovery() async throws {
        await notificationCoordinator.stopAndDrain()
        await agentBridgeHost?.stopAndDrain()
        agentBridgeHost = nil
    }

    func adoptRecoveredStore(_ store: DeliveryStore) {
        self.store = store
        recoveryStartupError = nil
        recoveryResumedAtLaunch = false
        notificationCoordinator = AppNotificationCoordinator(
            store: store,
            dispatcher: PushoverNotificationDispatcher(store: store, credentials: keychain)
        )
        if let package = codexPluginPackage {
            codexPluginCoordinator = CodexPluginLifecycleCoordinator(
                manager: CodexPluginLifecycleClient(),
                store: CodexPluginLifecycleStore(store: store),
                shippedVersion: package.version,
                shippedDigest: package.digest
            )
        } else {
            codexPluginCoordinator = nil
        }
    }

    func startSharedAgentBridge() async throws {
        guard recoveryStartupError == nil else { return }
        guard agentBridgeHost == nil else { return }
        let coordinator = notificationCoordinator
        agentBridgeHost = try await AgentBridgeApplicationHost.start(
            databaseURL: DeliveryStore.applicationSupportDatabaseURL(),
            afterReply: { envelope, result in
                await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
            }
        )
    }

    func stopSharedServices() async {
        await notificationCoordinator.stopAndDrain()
        await agentBridgeHost?.stopAndDrain()
        agentBridgeHost = nil
    }
}
