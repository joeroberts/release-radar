import Foundation
import ReleaseRadarCore

actor AppNotificationCoordinator {
    typealias ActivityRefreshHandler = @Sendable (ProjectID) async -> Void

    private let store: DeliveryStore
    private let dispatcher: PushoverNotificationDispatcher
    private var activityRefreshHandler: ActivityRefreshHandler?

    init(store: DeliveryStore, dispatcher: PushoverNotificationDispatcher) {
        self.store = store
        self.dispatcher = dispatcher
    }

    func setActivityRefreshHandler(_ handler: @escaping ActivityRefreshHandler) {
        activityRefreshHandler = handler
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
        await dispatchPending()
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

    private init() {
        let store = DeliveryStore(databaseURL: DeliveryStore.applicationSupportDatabaseURL())
        let keychain = PushoverKeychainStore()
        self.store = store
        self.keychain = keychain
        notificationCoordinator = AppNotificationCoordinator(
            store: store,
            dispatcher: PushoverNotificationDispatcher(store: store, credentials: keychain)
        )
    }
}
