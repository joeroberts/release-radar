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
    private(set) var agentBridgeStartupError: AgentBridgeApplicationError?
    private let codexPluginPackage: CodexPluginPackage?
    private var agentBridgeHost: AgentBridgeApplicationHost?
    private var executionAssignmentPreparer: ProjectExecutionAssignmentCoordinator?
    private var agentBridgeHealthSnapshot: AgentBridgeHealthSnapshot?
    private var agentBridgeHealthObserver: (@MainActor (AgentBridgeHealthSnapshot) -> Void)?
    private var agentBridgeHostID: UUID?
    private var agentBridgeHealthGeneration: UInt64 = 0
    private var agentBridgeSourceHealthGeneration: UInt64?
    private var afterAgentBridgeHealthRefresh: (@MainActor () async -> Void)?

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
            ? DeliveryStore(databaseURL: databaseURL, executionAssignmentRoot: ProjectExecutionFileStore.applicationRoot)
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

    func adoptRecoveredStore(_ store: DeliveryStore) async throws {
        try await store.observeExecutionAssignments(root: ProjectExecutionFileStore.applicationRoot)
        self.store = store
        executionAssignmentPreparer = nil
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
        try await store.observeExecutionAssignments(root: ProjectExecutionFileStore.applicationRoot)
        let preparer = executionAssignmentPreparer ?? ProjectExecutionSetupClient.assignments(plugin: codexPluginCoordinator)
        executionAssignmentPreparer = preparer
        let coordinator = notificationCoordinator
        agentBridgeHealthSnapshot = nil
        agentBridgeSourceHealthGeneration = nil
        let hostID = UUID()
        agentBridgeHostID = hostID
        do {
            agentBridgeHost = try await AgentBridgeApplicationHost.start(
                databaseURL: DeliveryStore.applicationSupportDatabaseURL(),
                executionAssignments: preparer,
                executionAssignmentRoot: ProjectExecutionFileStore.applicationRoot,
                afterReply: { envelope, result in
                    await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
                },
                connectionHealthChanged: { [weak self] snapshot in
                    Task { @MainActor [weak self] in
                        self?.receiveAgentBridgeHealth(snapshot, from: hostID)
                    }
                }
            )
            agentBridgeStartupError = nil
        } catch {
            let startupError = (error as? AgentBridgeApplicationError)
                ?? .connectFailed(error.localizedDescription)
            agentBridgeHostID = nil
            agentBridgeStartupError = startupError
            throw startupError
        }
    }

    func refreshAgentBridgeHealth() async throws -> AgentBridgeHealthSnapshot {
        guard let agentBridgeHost, let agentBridgeHostID else {
            if let agentBridgeStartupError { throw agentBridgeStartupError }
            throw AgentBridgeApplicationError.connectFailed("Release Radar is not connected to its bridge")
        }
        let sourceSnapshot = try await agentBridgeHost.refreshConnectionHealth()
        if let published = receiveAgentBridgeHealth(sourceSnapshot, from: agentBridgeHostID) {
            await afterAgentBridgeHealthRefresh?()
            return published
        }
        guard let agentBridgeHealthSnapshot else {
            throw AgentBridgeApplicationError.connectFailed("Bridge health reply is stale")
        }
        return agentBridgeHealthSnapshot
    }

    func observeAgentBridgeHealth(_ observer: @escaping @MainActor (AgentBridgeHealthSnapshot) -> Void) {
        agentBridgeHealthObserver = observer
        if let agentBridgeHealthSnapshot { observer(agentBridgeHealthSnapshot) }
    }

    func stopSharedServices() async {
        await notificationCoordinator.stopAndDrain()
        await agentBridgeHost?.stopAndDrain()
        agentBridgeHost = nil
    }

    @discardableResult
    func receiveAgentBridgeHealth(_ snapshot: AgentBridgeHealthSnapshot, from hostID: UUID) -> AgentBridgeHealthSnapshot? {
        guard agentBridgeHostID == hostID else { return nil }
        guard (agentBridgeSourceHealthGeneration ?? 0) <= snapshot.generation else { return nil }
        agentBridgeSourceHealthGeneration = snapshot.generation
        agentBridgeHealthGeneration &+= 1
        let published = AgentBridgeHealthSnapshot(
            generation: agentBridgeHealthGeneration,
            observedAt: snapshot.observedAt,
            health: snapshot.health
        )
        agentBridgeHealthSnapshot = published
        agentBridgeHealthObserver?(published)
        return published
    }

#if DEBUG
    init(
        testingStore store: DeliveryStore,
        agentBridgeHost: AgentBridgeApplicationHost,
        agentBridgeHostID: UUID,
        afterAgentBridgeHealthRefresh: (@MainActor () async -> Void)? = nil
    ) {
        self.store = store
        keychain = PushoverKeychainStore()
        notificationCoordinator = AppNotificationCoordinator(
            store: store,
            dispatcher: PushoverNotificationDispatcher(store: store, credentials: keychain)
        )
        codexPluginCoordinator = nil
        codexPluginShippedVersion = "Unknown"
        codexPluginShippedCapability = nil
        recoveryStartupError = nil
        recoveryResumedAtLaunch = false
        agentBridgeStartupError = nil
        codexPluginPackage = nil
        self.agentBridgeHost = agentBridgeHost
        self.agentBridgeHostID = agentBridgeHostID
        self.afterAgentBridgeHealthRefresh = afterAgentBridgeHealthRefresh
    }
#endif
}
