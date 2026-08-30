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
        await dispatcher.prepareForLaunch()
        await dispatchPending()
    }

    func dispatchPending() async {
        await dispatcher.dispatchPending()
        await refreshProjectsWithNotifications()
    }

    func dispatchAfterCommittedCommand(
        _: AgentCommandEnvelope,
        result: AgentCommandResult
    ) async {
        guard result.error == nil else { return }
        pendingSuccessfulCommandRefresh = true
        await drainSuccessfulCommandRefreshIfPossible()
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

struct ReleaseRadarAppServices: Sendable {
    static let shared = ReleaseRadarAppServices()

    let store: DeliveryStore
    let keychain: PushoverKeychainStore
    let notificationCoordinator: AppNotificationCoordinator
    let codexPluginCoordinator: CodexPluginLifecycleCoordinator?
    let codexPluginShippedVersion: String

    private init() {
        let store = DeliveryStore(databaseURL: DeliveryStore.applicationSupportDatabaseURL())
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
            codexPluginShippedVersion = package.version
            codexPluginCoordinator = CodexPluginLifecycleCoordinator(
                manager: CodexPluginLifecycleClient(),
                store: CodexPluginLifecycleStore(store: store),
                shippedVersion: package.version,
                shippedDigest: package.digest
            )
        } else {
            codexPluginShippedVersion = "Unknown"
            codexPluginCoordinator = nil
        }
    }
}
