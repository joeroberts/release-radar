import Foundation
import Observation
import ReleaseRadarCore

enum AttachFolderOutcome: Equatable, Sendable {
    case attached
    case attachedNeedsReload
}

enum ActivePhaseSelectionStatus: Equatable, Sendable {
    case idle
    case saving(PhaseID)
    case mutationFailed(FailureStatePresentation, canReauthorize: Bool)
    case savedNeedsReload(PhaseID, String)
}

private enum ProjectionReloadOutcome: Equatable, Sendable {
    case published
    case failed
    case superseded
}

private enum ProjectionReloadContext: Equatable, Sendable {
    case ordinary
    case ownerActivePhaseCommitted(ProjectID, PhaseID, String)
    case ownerDeliveryGoalCommitted(ProjectID)
    case agentCommandCommitted
}

private struct PreparedProjectProjections: Sendable {
    let dashboard: DashboardProjection
    let reviewInboxes: [ProjectID: ReviewInboxProjection]
    let dependencyGraphs: [ProjectID: DependencyGraphProjection]
    let projectActivities: [ProjectID: ProjectActivityProjection]
    let removedActivities: [ProjectRemovalID: ProjectActivityProjection]
    let projectDocumentationStates: [ProjectID: ProjectDocumentationState]
    let projectRoots: [ProjectID: URL]
    let selectedTicketID: TicketID
    let selectedReviewItemID: ReviewItemID?
}

@MainActor
@Observable
final class AppModel {
    var selection: AppRoute = .projects {
        didSet {
            if let projectID = selection.projectID {
                selectedProjectID = projectID
            }
        }
    }
    var isSidebarCompact = false
    var dashboard: DashboardProjection?
    var selectedTicketID = TicketID(rawValue: "VD2-08")
    var dashboardError: String?
    var codexSnapshot = CodexSnapshot.unavailable(reason: UnavailableCodexObserver.defaultReason)
    var codexPluginState: CodexPluginPresentationState = .checking
    var codexPluginOperation: CodexPluginOperation?
    var codexPluginSettingsMessage: String?
    var codexPluginAnnouncement: String?
    var selectedReviewItemID: ReviewItemID?
    var pushoverAppToken = ""
    var pushoverUserKey = ""
    var isPushoverConfigured = false
    var pushoverSettingsMessage: String?
    var alertRules: AlertRuleSnapshot?
    var alertRuleUpdateInFlight: AlertRuleKind?
    var applicationRecoveryInFlight = false
    var applicationRecoveryMessage: String?
    var applicationRecoveryFailure: FailureStatePresentation?
    var applicationRecoveryCheckedAt: Date?

    private var repositoryRecoveries: [ProjectID: RepositoryRecoveryModel] = [:]
    private var store: DeliveryStore
    private let databaseURL: URL
    private let seedSampleData: Bool
    private let externalServicesSuppressed: Bool
    private let codexObserver: any CodexObserver
    private var codexPluginCoordinator: CodexPluginLifecycleCoordinator?
    let codexPluginShippedVersion: String
    private let pushoverKeychain: PushoverKeychainStore
    private var notificationCoordinator: AppNotificationCoordinator
    private var projectOnboarding: FolderProjectOnboarding
    private let recoveryServices: ReleaseRadarAppServices?
    private var recoveryStartupError: String?
    private var recoveryResumedAtLaunch: Bool
    private let reviewInboxLoader: @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection
    private let dashboardLoader: @Sendable (DeliveryStore) async throws -> DashboardProjection
    private let requestIDGenerator: () -> UUID
    private(set) var selectedProjectID: ProjectID?
    private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
    private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
    private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
    private var removedActivities: [ProjectRemovalID: ProjectActivityProjection] = [:]
    private var projectDocumentationStates: [ProjectID: ProjectDocumentationState] = [:]
    private var projectRoots: [ProjectID: URL] = [:]
    private var reviewActionStates: [ProjectID: ReviewActionState] = [:]
    private var activePhaseSelectionStatuses: [ProjectID: ActivePhaseSelectionStatus] = [:]
    // View preferences are ephemeral, byte-exact identities, never another active pointer.
    private var viewedPhaseIDs: [Data: PhaseID] = [:]
    private var deliveryGoalReloadRequired: Set<Data> = []
    private var performingReviewActionProjectIDs: Set<ProjectID> = []
    private var alertRulesFailureState: AlertRulesFailureState?
    private var didInitializeCodexPluginLifecycle = false
    private var codexPluginObservedAt: Date?
    private var projectionReloadGeneration: UInt64 = 0
#if DEBUG
    private var rr9ActivePhaseCaptureScenario: RR9ActivePhaseCaptureScenario?
    private var rr9ActivePhaseCaptureRootDirectory: URL?
    private var rr9SavedRefreshFailureConsumed = false
#endif

    init(
        store: DeliveryStore,
        databaseURL: URL? = nil,
        codexObserver: any CodexObserver = UnavailableCodexObserver(),
        codexPluginCoordinator: CodexPluginLifecycleCoordinator? = nil,
        codexPluginShippedVersion: String = "0.1.0",
        pushoverKeychain: PushoverKeychainStore? = nil,
        notificationCoordinator: AppNotificationCoordinator? = nil,
        projectOnboarding: FolderProjectOnboarding? = nil,
        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
            try await ReviewInboxProjection.load(from: $0, projectID: $1)
        },
        dashboardLoader: @escaping @Sendable (DeliveryStore) async throws -> DashboardProjection = {
            try await DashboardProjection.load(from: $0)
        },
        requestIDGenerator: @escaping () -> UUID = { UUID() },
        recoveryServices: ReleaseRadarAppServices? = nil,
        recoveryStartupError: String? = nil,
        recoveryResumedAtLaunch: Bool = false,
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false
    ) {
        let resolvedKeychain = pushoverKeychain ?? PushoverKeychainStore()
        self.store = store
        self.databaseURL = databaseURL ?? store.databaseURL
        self.seedSampleData = seedSampleData
        self.externalServicesSuppressed = externalServicesSuppressed
        self.codexObserver = codexObserver
        self.codexPluginCoordinator = codexPluginCoordinator
        self.codexPluginShippedVersion = codexPluginShippedVersion
        self.pushoverKeychain = resolvedKeychain
        self.projectOnboarding = projectOnboarding ?? FolderProjectOnboarding(store: store)
        self.reviewInboxLoader = reviewInboxLoader
        self.dashboardLoader = dashboardLoader
        self.requestIDGenerator = requestIDGenerator
        self.recoveryServices = recoveryServices
        self.recoveryStartupError = recoveryStartupError
        self.recoveryResumedAtLaunch = recoveryResumedAtLaunch
        self.notificationCoordinator = notificationCoordinator
            ?? AppNotificationCoordinator(
                store: store,
                dispatcher: PushoverNotificationDispatcher(store: store, credentials: resolvedKeychain)
            )
    }

#if DEBUG
    convenience init(
        store: DeliveryStore,
        databaseURL: URL? = nil,
        codexObserver: any CodexObserver = UnavailableCodexObserver(),
        codexPluginCoordinator: CodexPluginLifecycleCoordinator? = nil,
        codexPluginShippedVersion: String = "0.1.0",
        pushoverKeychain: PushoverKeychainStore? = nil,
        notificationCoordinator: AppNotificationCoordinator? = nil,
        projectOnboarding: FolderProjectOnboarding? = nil,
        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
            try await ReviewInboxProjection.load(from: $0, projectID: $1)
        },
        dashboardLoader: @escaping @Sendable (DeliveryStore) async throws -> DashboardProjection = {
            try await DashboardProjection.load(from: $0)
        },
        requestIDGenerator: @escaping () -> UUID = { UUID() },
        recoveryServices: ReleaseRadarAppServices? = nil,
        recoveryStartupError: String? = nil,
        recoveryResumedAtLaunch: Bool = false,
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false,
        rr9ActivePhaseCaptureScenario: RR9ActivePhaseCaptureScenario?,
        rr9ActivePhaseCaptureRootDirectory: URL? = nil
    ) {
        self.init(
            store: store,
            databaseURL: databaseURL,
            codexObserver: codexObserver,
            codexPluginCoordinator: codexPluginCoordinator,
            codexPluginShippedVersion: codexPluginShippedVersion,
            pushoverKeychain: pushoverKeychain,
            notificationCoordinator: notificationCoordinator,
            projectOnboarding: projectOnboarding,
            reviewInboxLoader: reviewInboxLoader,
            dashboardLoader: dashboardLoader,
            requestIDGenerator: requestIDGenerator,
            recoveryServices: recoveryServices,
            recoveryStartupError: recoveryStartupError,
            recoveryResumedAtLaunch: recoveryResumedAtLaunch,
            externalServicesSuppressed: externalServicesSuppressed,
            seedSampleData: seedSampleData
        )
        self.rr9ActivePhaseCaptureScenario = rr9ActivePhaseCaptureScenario
        self.rr9ActivePhaseCaptureRootDirectory = rr9ActivePhaseCaptureRootDirectory
    }
#endif

    var currentProjectID: ProjectID {
        selection.projectID
            ?? selectedProjectID
            ?? dashboard?.projects.first?.id
            ?? DashboardSampleData.projectID
    }

    var currentProject: ProjectDashboardProjection? {
        dashboard?.projects.first { $0.id == currentProjectID }
    }

    func repositoryRecovery(for projectID: ProjectID) -> RepositoryRecoveryModel {
        if let model = repositoryRecoveries[projectID] { return model }
        let model = RepositoryRecoveryModel(store: store, projectID: projectID, allowsRelocation: true)
        repositoryRecoveries[projectID] = model
        return model
    }

    var onboardingStore: DeliveryStore { store }

    var alertRulesFailure: FailureStatePresentation? {
        alertRulesFailureState?.presentation
    }

    var alertRuleControlsDisabled: Bool {
        alertRuleUpdateInFlight != nil || alertRulesFailureState?.retry == .load
    }

    var reviewActionError: String? {
        reviewActionStates[currentProjectID]?.message
    }

    var reviewActionFailure: FailureStatePresentation? {
        scopedReviewActionFailure(for: currentProjectID)
    }

    var reviewAuthorizationRecovery: ReviewAuthorizationRecovery? {
        scopedReviewAuthorizationRecovery(for: currentProjectID)
    }

    var isPerformingReviewAction: Bool {
        scopedIsPerformingReviewAction(for: currentProjectID)
    }

    var needsReviewCount: Int {
        guard let inbox = reviewInbox(for: currentProjectID) else { return 0 }
        return inbox.openItems.count + inbox.deliveryGoalAcceptances.count
    }

    var notificationCount: Int {
        activity(for: currentProjectID)?.items.filter { $0.source == .notification }.count ?? 0
    }

    func openProject(_ projectID: ProjectID) async {
        await navigate(to: .projectOverview(projectID))
    }

    func navigate(to route: AppRoute) async {
        if case let .removedProject(removalID) = route {
            selectedProjectID = nil
            selection = dashboard?.removedProjects.contains(where: { $0.id == removalID }) == true
                ? route : .projects
            return
        }
        if case let .archivedProject(projectID) = route,
           dashboard?.projects.contains(where: { $0.id == projectID }) == true {
            await navigate(to: .projectOverview(projectID))
            return
        }
        if let projectID = route.projectID {
            if dashboard?.archivedProjects.contains(where: { $0.id == projectID }) == true {
                selection = .archivedProject(projectID)
                return
            }
            guard dashboard?.projects.contains(where: { $0.id == projectID }) == true else {
                if let removed = dashboard?.removedProjects.first(where: { $0.projectID == projectID }) {
                    selectedProjectID = nil
                    selection = .removedProject(removed.id)
                } else {
                    selection = .projects
                }
                return
            }
            do {
                try await MeaningfulDeliveryEventRecorder(store: store).markDashboardOpened(projectID: projectID)
            } catch {
                dashboardError = error.localizedDescription
                return
            }
        }
        selection = route
    }

    func previewProjectLifecycle(
        projectID: ProjectID,
        transition: ProjectLifecycleTransition
    ) async throws -> ProjectLifecyclePreview {
        try await ProjectLifecycleManager(store: store).preview(projectID: projectID, transition: transition)
    }

    func applyProjectLifecycle(_ preview: ProjectLifecyclePreview) async throws {
        let snapshot = try await ProjectLifecycleManager(store: store).apply(preview)
        selectedProjectID = snapshot.projectID
        _ = await reloadProjectProjections()
        selection = snapshot.lifecycle == .archived
            ? .archivedProject(snapshot.projectID)
            : .projectOverview(snapshot.projectID)
    }

    func previewProjectRemoval(projectID: ProjectID) async throws -> ProjectRemovalPreview {
        try await ProjectRemovalManager(store: store).preview(projectID: projectID)
    }

    @discardableResult
    func applyProjectRemoval(_ preview: ProjectRemovalPreview) async throws -> RemovedProjectRecord {
        let record = try await ProjectRemovalManager(store: store).apply(preview)
        selectedProjectID = nil
        _ = await reloadProjectProjections()
        selection = .removedProject(record.id)
        return record
    }

    func loadDashboard() async {
        await loadAlertRules()
        await notificationCoordinator.setActivityRefreshHandler { [weak self] projectID in
            await self?.refreshNotificationActivity(for: projectID)
        }
        await notificationCoordinator.setDashboardRefreshHandler { [weak self] in
            await self?.reloadDashboardAfterCommittedAgentCommand()
        }
        do {
            if seedSampleData {
                try await DashboardSampleData.seedIfNeeded(in: store)
            }
#if DEBUG
            if let rr9ActivePhaseCaptureScenario {
                try await RR9ActivePhaseCaptureFixture.seedIfNeeded(
                    in: store,
                    rootDirectory: rr9ActivePhaseCaptureRootDirectory
                        ?? DeliveryStore.applicationSupportDatabaseURL()
                            .deletingLastPathComponent()
                            .appendingPathComponent("RR9ActivePhaseCaptureRoots", isDirectory: true),
                    scenario: rr9ActivePhaseCaptureScenario
                )
            }
#endif
            let outcome = await reloadProjectProjections()
            guard outcome == .published else { return }
#if DEBUG
            if let rr9ActivePhaseCaptureScenario {
                applyRR9InitialRoute(for: rr9ActivePhaseCaptureScenario)
            }
#endif
            if !externalServicesSuppressed {
                await loadPushoverConfiguration()
                await notificationCoordinator.dispatchPending()
            }
        } catch {
            dashboardError = error.localizedDescription
        }
    }

    func loadAlertRules() async {
        do {
            alertRules = try await AlertRuleStore(store: store).load()
            alertRulesFailureState = nil
        } catch {
            alertRulesFailureState = .load
        }
    }

    func setAlertRule(_ kind: AlertRuleKind, enabled: Bool) async {
        guard alertRules != nil, alertRuleUpdateInFlight == nil else { return }
        alertRuleUpdateInFlight = kind
        defer { alertRuleUpdateInFlight = nil }
        do {
            alertRules = try await AlertRuleStore(store: store).set(kind, enabled: enabled)
            alertRulesFailureState = nil
        } catch {
            alertRulesFailureState = .update(kind, enabled: enabled)
        }
    }

    func retryAlertRules() async {
        guard let retry = alertRulesFailureState?.retry else { return }
        switch retry {
        case .load:
            await loadAlertRules()
        case let .update(kind, enabled):
            await setAlertRule(kind, enabled: enabled)
        }
    }

    func previewApplicationBackup(destinationURL: URL) async throws -> ApplicationBackupPreview {
        try await ApplicationBackupManager(
            store: store,
            databaseURL: databaseURL
        ).previewBackup(destinationURL: destinationURL)
    }

    func presentApplicationRecoveryFailure(_ error: Error) {
        applicationRecoveryMessage = nil
        applicationRecoveryCheckedAt = Date()
        applicationRecoveryFailure = .init(
            title: "Recovery preview unavailable",
            detail: error.localizedDescription,
            systemImage: "exclamationmark.arrow.triangle.2.circlepath",
            tone: .error,
            accessibilityID: "application-recovery-failure"
        )
    }

    func createApplicationBackup(_ preview: ApplicationBackupPreview) async {
        await performRecoveryOperation {
            let receipt = try await ApplicationBackupManager(
                store: self.store,
                databaseURL: self.databaseURL
            ).createBackup(preview)
            self.applicationRecoveryMessage = "Backup created at \(receipt.packageURL.lastPathComponent). Credentials, repositories and device permissions were not included."
        }
    }

    func resetApplicationPreferences() async {
        await performRecoveryOperation {
            self.alertRules = try await ApplicationPreferenceReset(store: self.store).apply()
            self.clearEphemeralViewState()
            _ = await self.reloadProjectProjections()
            self.applicationRecoveryMessage = "Application preferences were reset. Projects, tracking history, plugin management and credentials were preserved."
        }
    }

    func previewTrackingReset() async throws -> ApplicationTrackingResetPreview {
        try await makeRecoveryManager().previewTrackingReset()
    }

    func resetTracking(_ preview: ApplicationTrackingResetPreview) async {
        await performRecoveryOperation {
            let result = try await self.makeRecoveryManager().resetTracking(preview)
            try await self.adoptRecovery(result)
            self.applicationRecoveryMessage = "Tracking data was reset for \(preview.projects.count) project registration\(preview.projects.count == 1 ? "" : "s"). Retained history and global preferences remain available."
        }
    }

    func previewApplicationRestore(packageURL: URL) async throws -> ApplicationRestorePreview {
        try await makeRecoveryManager().previewRestore(packageURL: packageURL)
    }

    func restoreApplicationBackup(_ preview: ApplicationRestorePreview) async {
        await performRecoveryOperation {
            let result = try await self.makeRecoveryManager().restore(preview)
            try await self.adoptRecovery(result)
            let history = result.newerHistoryWasReconciled
                ? "Newer local removal, audit and terminal notification facts were retained."
                : "The prior store was unreadable, so newer local history could not be reconciled. Its original bytes were preserved at \(result.preservedOriginalURL?.path ?? "an unavailable location")."
            self.applicationRecoveryMessage = "Backup restored. \(history) Folder permissions require reauthorization and queued backup notifications will not be sent."
        }
    }

    private func makeRecoveryManager() -> ApplicationRecoveryManager {
        let services = recoveryServices
        return ApplicationRecoveryManager(
            store: store,
            databaseURL: databaseURL,
            quiesce: {
                try await services?.stopAndDrainForRecovery()
            }
        )
    }

    private func performRecoveryOperation(_ operation: () async throws -> Void) async {
        guard !applicationRecoveryInFlight else { return }
        applicationRecoveryInFlight = true
        applicationRecoveryMessage = nil
        applicationRecoveryFailure = nil
        defer {
            applicationRecoveryInFlight = false
            applicationRecoveryCheckedAt = Date()
        }
        do {
            try await operation()
        } catch let failure as ApplicationRecoveryInstallFailure {
            var detail = failure.localizedDescription
            do {
                try await adoptRecovery(.init(
                    store: failure.recoveredStore,
                    operationID: UUID(),
                    requiresFreshServiceGraph: true,
                    newerHistoryWasReconciled: false
                ))
            } catch {
                detail += " The prior data was restored, but application services could not resume: \(error.localizedDescription)"
            }
            applicationRecoveryFailure = .init(
                title: "Recovery action failed",
                detail: detail,
                systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                tone: .error,
                accessibilityID: "application-recovery-failure"
            )
        } catch {
            applicationRecoveryFailure = .init(
                title: "Recovery action failed",
                detail: error.localizedDescription,
                systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                tone: .error,
                accessibilityID: "application-recovery-failure"
            )
        }
    }

    private func adoptRecovery(_ result: ApplicationRecoveryResult) async throws {
        store = result.store
        recoveryStartupError = nil
        recoveryResumedAtLaunch = false
        if let recoveryServices {
            recoveryServices.adoptRecoveredStore(result.store)
            notificationCoordinator = recoveryServices.notificationCoordinator
            codexPluginCoordinator = recoveryServices.codexPluginCoordinator
        } else {
            notificationCoordinator = AppNotificationCoordinator(
                store: result.store,
                dispatcher: PushoverNotificationDispatcher(store: result.store, credentials: pushoverKeychain)
            )
            codexPluginCoordinator = nil
        }
        projectOnboarding = FolderProjectOnboarding(store: result.store)
        clearEphemeralViewState()
        selection = .projects
        selectedProjectID = nil
        dashboard = nil
        dashboardError = nil

        if let codexPluginCoordinator {
            let recovery = await codexPluginCoordinator.recoveryStatus()
            applyRecoveryCodexStatus(recovery)
        }
        await loadDashboard()
        if !externalServicesSuppressed {
            await notificationCoordinator.initializeForLaunch()
            try await recoveryServices?.startSharedAgentBridge()
        }
    }

    private func clearEphemeralViewState() {
        viewedPhaseIDs.removeAll()
        deliveryGoalReloadRequired.removeAll()
        repositoryRecoveries.removeAll()
        reviewInboxes.removeAll()
        dependencyGraphs.removeAll()
        projectActivities.removeAll()
        removedActivities.removeAll()
        projectDocumentationStates.removeAll()
        projectRoots.removeAll()
        reviewActionStates.removeAll()
        activePhaseSelectionStatuses.removeAll()
        selectedReviewItemID = nil
    }

    private func applyRecoveryCodexStatus(_ recovery: CodexPluginRecoverySnapshot) {
        switch (recovery.management, recovery.observedState, recovery.error) {
        case let (.known(receipt), .some(observed), nil):
            codexPluginState = CodexPluginLifecycleReducer.presentation(
                receipt: receipt,
                observed: observed,
                shippedVersion: codexPluginShippedVersion
            )
        case (_, _, let error?):
            codexPluginState = .failed(error)
        case (.unknown, _, nil):
            codexPluginState = .failed(.integrityUnknown)
        case (.known, nil, nil):
            codexPluginState = .failed(.malformedResult)
        }
        codexPluginObservedAt = recovery.checkedAt
    }

    func reloadAfterOnboarding() async {
        selection = .projects
        await loadDashboard()
    }

    func eligibleProjectsForFolderAttachment() async throws -> [ProjectRecord] {
        try await projectOnboarding.eligibleProjectsForFirstRootAssociation()
    }

    func attachFolder(_ folder: URL, to projectID: ProjectID) async throws -> AttachFolderOutcome {
        try await projectOnboarding.associateFirstProjectRoot(folder, for: projectID)
        selection = .projects
        selectedProjectID = projectID
        switch await reloadProjectProjections() {
        case .published, .superseded:
            return .attached
        case .failed:
            return .attachedNeedsReload
        }
    }

    func reloadAfterFolderAttachment(_ projectID: ProjectID) async -> Bool {
        selection = .projects
        selectedProjectID = projectID
        switch await reloadProjectProjections() {
        case .published, .superseded:
            return true
        case .failed:
            return false
        }
    }

    func reviewInbox(for projectID: ProjectID) -> ReviewInboxProjection? {
        reviewInboxes[projectID]
    }

    func dependencyGraph(for projectID: ProjectID) -> DependencyGraphProjection? {
        dependencyGraphs[projectID]
    }

    func activity(for projectID: ProjectID) -> ProjectActivityProjection? {
        projectActivities[projectID]
    }

    func removedActivity(for removalID: ProjectRemovalID) -> ProjectActivityProjection? {
        removedActivities[removalID]
    }

    func projectGuidanceState(for projectID: ProjectID) -> ProjectGuidanceState {
        projectDocumentationState(for: projectID).guidanceState
    }

    func projectDocumentationState(for projectID: ProjectID) -> ProjectDocumentationState {
        projectDocumentationStates[projectID] ?? .legacy(.unavailable)
    }

    func projectRoot(for projectID: ProjectID) -> URL? {
        projectRoots[projectID]
    }

    func projectSettings(for projectID: ProjectID) async throws -> ProjectSettingsSnapshot {
        try await projectOnboarding.projectSettings(projectID: projectID)
    }

    func updateProjectSettings(
        registration: ProjectRegistration,
        projectName: String,
        excludedTaskIDs: Set<String>
    ) async throws -> ProjectSettingsSnapshot {
        let updated = try await projectOnboarding.updateProjectSettings(
            registration: registration,
            projectName: projectName,
            excludedTaskIDs: excludedTaskIDs
        )
        _ = await reloadProjectProjections()
        return updated
    }

    func codexTasks(for projectID: ProjectID) -> [CodexTaskDescriptor] {
        guard let root = projectRoots[projectID] else { return [] }
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        return codexSnapshot.threads.compactMap { thread in
            let workingDirectory = thread.workingDirectory.standardizedFileURL.resolvingSymlinksInPath()
            let rootComponents = canonicalRoot.pathComponents
            let candidateComponents = workingDirectory.pathComponents
            guard candidateComponents.count >= rootComponents.count,
                  Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
            else { return nil }
            return CodexTaskDescriptor(
                id: thread.id,
                workingDirectory: workingDirectory,
                title: thread.goal?.objective ?? thread.id
            )
        }
    }

    func codexTasksForOnboarding() -> [CodexTaskDescriptor] {
        codexSnapshot.threads.map {
            .init(
                id: $0.id,
                workingDirectory: $0.workingDirectory,
                title: $0.goal?.objective ?? $0.id
            )
        }
    }

    func projectHealth(for projectID: ProjectID) async -> ProjectHealthSnapshot {
        let checkedAt = Date()
        guard case .available = await store.availability else {
            return .init(
                projectID: projectID,
                registration: nil,
                rootPath: projectRoots[projectID]?.path,
                checkedAt: checkedAt,
                checks: [
                    .init(id: "storage", title: "Local storage unavailable", detail: "Release Radar could not open its local store. Use the recovery information shown by the app before retrying.", state: .unavailable),
                    .init(id: "folder", title: "Folder access not checked", detail: "Folder authorization cannot be verified while local storage is unavailable.", state: .unavailable),
                    .init(id: "documentation", title: "Documentation not checked", detail: "Repository documentation cannot be verified while local storage is unavailable.", state: .unavailable),
                ]
            )
        }

        let settings = try? await projectOnboarding.projectSettings(projectID: projectID)
        var checks: [ProjectHealthSnapshot.Check] = [
            .init(id: "storage", title: "Local storage ready", detail: "The current Release Radar schema is available.", state: .ready),
        ]
        let documentation = await projectOnboarding.inspectProjectGuidanceContext(projectID: projectID)
        if let root = documentation.projectRoot {
            checks.append(.init(id: "folder", title: "Folder access ready", detail: root.path, state: .ready))
        } else {
            checks.append(.init(id: "folder", title: "Folder access needs attention", detail: "The saved authorization could not be resolved. Reauthorize the same project folder, then check again.", state: .attention))
        }

        let documentationPresentation = ProjectGuidancePresentation(documentationState: documentation.documentationState)
        let documentationReady: Bool
        switch documentation.documentationState {
        case .managed(hasAuditedHandoff: true, _, _), .legacy(.current): documentationReady = true
        default: documentationReady = false
        }
        checks.append(.init(
            id: "documentation",
            title: documentationPresentation.status,
            detail: documentationPresentation.detail,
            state: documentationReady ? .ready : .attention
        ))

        let roots = try? await projectOnboarding.rootSnapshot(projectID: projectID)
        if let roots {
            for root in roots.roots where root.role == .worktree {
                checks.append(.init(id: "root:\(root.id.rawValue)", title: "Worktree access: \(root.isAccessible ? "ready" : "needs attention")",
                    detail: "\(root.path) · \(root.accessDetail)", state: root.isAccessible ? .ready : .attention))
            }
        } else {
            checks.append(.init(id: "roots", title: "Saved roots not checked", detail: "Reload repository roots to verify the current registration and each worktree authorization.", state: .unavailable))
        }

        let plugin = CodexPluginSettingsPresentation(state: codexPluginState)
        let pluginReady: Bool
        if case .installed = codexPluginState, codexPluginObservedAt != nil { pluginReady = true } else { pluginReady = false }
        let pluginObservation = codexPluginObservedAt.map {
            "Observed \($0.formatted(date: .abbreviated, time: .shortened))."
        } ?? "Observation time unavailable."
        checks.append(.init(id: "plugin", title: "Codex workflow: \(plugin.status)", detail: "\(plugin.detail) \(pluginObservation)", state: pluginReady ? .ready : .attention))

        let connection = CodexConnectionPresentation(freshness: codexSnapshot.freshness)
        checks.append(.init(
            id: "observer",
            title: "Codex observation: \(connection.status)",
            detail: connection.detail,
            state: codexSnapshot.freshness.state == .live ? .ready : .attention
        ))
        if let roots {
            let current = (try? await projectOnboarding.rootSnapshotIsCurrent(roots)) == true
            if !current || roots.registration != settings?.registration ||
                (documentation.projectRoot != nil && roots.roots.first(where: { $0.role == .primary })?.path != documentation.projectRoot?.path) {
                return .init(projectID: projectID, registration: nil, rootPath: nil, checkedAt: checkedAt,
                    checks: [.init(id: "roots", title: "Project roots changed during checking", detail: "Check health again for the current saved registration and roots. Earlier results are no longer current.", state: .unavailable)])
            }
        }
        return .init(
            projectID: projectID,
            registration: settings?.registration,
            rootPath: documentation.projectRoot?.path ?? projectRoots[projectID]?.path,
            checkedAt: checkedAt,
            checks: checks
        )
    }

    func applicationHealth() async -> ApplicationHealthSnapshot {
        let storeAvailability = await store.availability
        if case .available = storeAvailability,
           let projectID = dashboard?.projects.first?.id {
            let project = await projectHealth(for: projectID)
            var checks = project.checks
            if let applicationRecoveryMessage {
                checks.insert(.init(
                    id: "recovery-result",
                    title: "Latest recovery action completed",
                    detail: applicationRecoveryMessage,
                    state: .ready
                ), at: 0)
            }
            return .init(
                projectTarget: project.registration,
                rootPath: project.rootPath,
                checkedAt: project.checkedAt,
                checks: checks
            )
        }

        let storageAvailable: Bool
        if case .available = storeAvailability { storageAvailable = true }
        else { storageAvailable = false }
        let plugin = CodexPluginSettingsPresentation(state: codexPluginState)
        let pluginReady: Bool
        if case .installed = codexPluginState, codexPluginObservedAt != nil { pluginReady = true } else { pluginReady = false }
        let pluginObservation = codexPluginObservedAt.map {
            "Observed \($0.formatted(date: .abbreviated, time: .shortened))."
        } ?? "Observation time unavailable."
        let observer = CodexConnectionPresentation(freshness: codexSnapshot.freshness)
        var checks: [ProjectHealthSnapshot.Check] = [
            .init(
                id: "storage",
                title: storageAvailable ? "Local storage ready" : "Local storage unavailable",
                detail: storageAvailable
                    ? "The current Release Radar schema is available."
                    : "Release Radar could not open its local store. Project records remain unavailable until storage recovery succeeds.",
                state: storageAvailable ? .ready : .unavailable
            ),
            .init(id: "folder", title: "Folder access not checked", detail: "Open a saved project to check its exact folder authorization.", state: .unavailable),
            .init(id: "documentation", title: "Documentation not checked", detail: "Open a saved project to check its exact repository documentation target.", state: .unavailable),
            .init(id: "plugin", title: "Codex workflow: \(plugin.status)", detail: "\(plugin.detail) \(pluginObservation)", state: pluginReady ? .ready : .attention),
            .init(id: "observer", title: "Codex observation: \(observer.status)", detail: observer.detail, state: codexSnapshot.freshness.state == .live ? .ready : .attention),
        ]
        let recoveryDetail: String? = switch storeAvailability {
        case .available:
            recoveryStartupError
        case let .unavailable(recovery):
            "\(recovery.message) Original database: \(recovery.originalDatabaseURL.path)."
        }
        if let recoveryDetail {
            checks.insert(.init(
                id: "recovery",
                title: "Recovery requires attention",
                detail: "Target: \(databaseURL.path). \(recoveryDetail) Choose Restore Backup to validate and recover from a supported full backup; no plugin, permission or notification side effect occurs during inspection.",
                state: .unavailable
            ), at: 1)
        } else if let applicationRecoveryMessage {
            checks.insert(.init(
                id: "recovery-result",
                title: "Latest recovery action completed",
                detail: applicationRecoveryMessage,
                state: .ready
            ), at: 1)
        }
        return .init(
            projectTarget: nil,
            rootPath: nil,
            checkedAt: Date(),
            checks: checks
        )
    }

    func previewDocumentationSetup(
        registration: ProjectRegistration
    ) async throws -> ProjectDocumentationSetupPreview {
        try await ProjectDocumentationSetupCoordinator(store: store).preview(registration: registration)
    }

    func performDocumentationSetup(
        _ preview: ProjectDocumentationSetupPreview
    ) async throws -> AuditEventID? {
        let audit = try await ProjectDocumentationSetupCoordinator(store: store).perform(preview)
        _ = await reloadProjectProjections()
        return audit
    }

    func activePhaseSelectionStatus(for projectID: ProjectID) -> ActivePhaseSelectionStatus {
        activePhaseSelectionStatuses[projectID] ?? .idle
    }

    func viewedBoard(for projectID: ProjectID) -> PhaseBoardProjection? {
        guard let dashboard else { return nil }
        return viewedBoard(in: dashboard, for: projectID)
    }

    private func viewedBoard(in dashboard: DashboardProjection, for projectID: ProjectID) -> PhaseBoardProjection? {
        if let phaseID = viewedPhaseIDs[Data(projectID.rawValue.utf8)],
           let board = dashboard.board(for: projectID, phaseID: phaseID) {
            return board
        }
        if let active = dashboard.board(for: projectID) { return active }
        guard let phase = dashboard.projects.first(where: {
            $0.id.rawValue.utf8.elementsEqual(projectID.rawValue.utf8)
        })?.phases.first else { return nil }
        return dashboard.board(for: projectID, phaseID: phase.id)
    }

    func viewPhase(projectID: ProjectID, phaseID: PhaseID) {
        guard dashboardError == nil,
              let board = dashboard?.board(for: projectID, phaseID: phaseID) else { return }
        viewedPhaseIDs[Data(projectID.rawValue.utf8)] = phaseID
        if board.detail(for: selectedTicketID) == nil {
            selectedTicketID = board.lanes.flatMap(\.cards).map(\.id)
                .min { $0.rawValue < $1.rawValue } ?? TicketID(rawValue: "")
        }
    }

    func deliveryGoalAcceptanceNeedsReload(for projectID: ProjectID) -> Bool {
        deliveryGoalReloadRequired.contains(Data(projectID.rawValue.utf8))
    }

    func acceptDeliveryGoal(_ item: DeliveryGoalAcceptanceReviewProjection) async {
        let projectID = item.projectID
        let expectedRegistration = dashboard?.projects.first { $0.id == projectID }?.registration
        guard dashboardError == nil,
              !scopedIsPerformingReviewAction(for: projectID),
              !deliveryGoalAcceptanceNeedsReload(for: projectID),
              scopedReviewAuthorizationRecovery(for: projectID) == nil,
              reviewInboxes[projectID]?.deliveryGoalAcceptances.contains(where: { $0.id == item.id }) == true else { return }
        performingReviewActionProjectIDs.insert(projectID)
        reviewActionStates[projectID] = nil
        defer { performingReviewActionProjectIDs.remove(projectID) }
        let requestID = requestIDGenerator()
        do {
            let store = self.store
            let result = try await projectOnboarding.withAuthorizedProject(projectID: projectID) { project in
                await AgentCommandDispatcher(store: store,
                    projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project]))
                    .dispatch(.init(version: AgentCommandDispatcher.commandEnvelopeVersion,
                        requestID: requestID, projectRoot: project.canonicalRoot.path,
                        expectedRegistration: expectedRegistration,
                        reason: "Owner accepted Delivery Goal \(item.goalID.rawValue)",
                        command: .transitionDeliveryGoal(projectID: projectID.rawValue,
                            phaseID: item.phaseID.rawValue, goalID: item.goalID.rawValue,
                            expectedPlanRevision: item.expectedPlanRevision, lifecycle: .accepted)), origin: .ownerApp)
            }
            if let error = result.error {
                reviewActionStates[projectID] = ReviewActionState(
                    message: "Delivery Goal acceptance failed: \(String(describing: error))",
                    failure: FailureStatePresentation(agentError: error), recovery: nil)
                deliveryGoalReloadRequired.insert(Data(projectID.rawValue.utf8))
                return
            }
            // Remove the committed decision immediately, even if the subsequent read fails.
            if let inbox = reviewInboxes[projectID] {
                reviewInboxes[projectID] = ReviewInboxProjection(projectID: inbox.projectID,
                    openItems: inbox.openItems, completedItems: inbox.completedItems,
                    deliveryGoalAcceptances: inbox.deliveryGoalAcceptances.filter { $0.id != item.id })
            }
            deliveryGoalReloadRequired.insert(Data(projectID.rawValue.utf8))
            _ = await reloadProjectProjections(context: .ownerDeliveryGoalCommitted(projectID))
        } catch let error as ProjectAuthorizationError {
            presentReviewAuthorizationFailure(error, projectID: projectID)
        } catch {
            reviewActionStates[projectID] = ReviewActionState(
                message: "Delivery Goal acceptance failed: \(error.localizedDescription)",
                failure: FailureStatePresentation(agentError: .internalFailure(error.localizedDescription)), recovery: nil)
        }
    }

    func reloadDeliveryGoalAcceptance(projectID: ProjectID) async {
        guard !scopedIsPerformingReviewAction(for: projectID) else { return }
        _ = await reloadProjectProjections()
    }

    func transitionTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        to lane: TicketLane,
        ticketTaskPlanRevision: Int64? = nil
    ) async throws -> AgentCommandResult {
        let expectedRegistration = dashboard?.projects.first { $0.id == projectID }?.registration
        if lane == .accepted, ticketID.rawValue.contains("\0") {
            return .init(
                entityIDs: [],
                auditEventID: nil,
                error: .invalidEnvelope("Accepted transition ticketID is invalid")
            )
        }
        let requestID = requestIDGenerator()
        let store = self.store
        let result = try await projectOnboarding.withAuthorizedProject(projectID: projectID) { project in
            await AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
            ).dispatch(
                AgentCommandEnvelope(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: requestID,
                    projectRoot: project.canonicalRoot.path,
                    expectedRegistration: expectedRegistration,
                    reason: "Owner transitioned ticket \(ticketID.rawValue) to \(lane.rawValue)",
                    command: .transitionTicket(
                        ticketID: ticketID.rawValue,
                        lane: lane,
                        ticketTaskPlanRevision: ticketTaskPlanRevision
                    )
                ),
                origin: .ownerApp
            )
        }
        if result.error == nil {
            await reloadDashboardAfterCommittedAgentCommand()
        }
        return result
    }

    func setActivePhase(projectID: ProjectID, phaseID: PhaseID) async {
        let expectedRegistration = dashboard?.projects.first { $0.id == projectID }?.registration
        guard dashboard?.projects.first(where: { $0.id == projectID })?.activePhaseID != phaseID else {
            return
        }
        switch activePhaseSelectionStatuses[projectID] ?? .idle {
        case .saving, .savedNeedsReload:
            return
        case .idle, .mutationFailed:
            break
        }
        activePhaseSelectionStatuses[projectID] = .saving(phaseID)
        let requestID = requestIDGenerator()

#if DEBUG
        switch rr9ActivePhaseCaptureScenario {
        case .busy:
            return
        case .mutationFailure:
            activePhaseSelectionStatuses[projectID] = .mutationFailed(
                FailureStatePresentation(activePhaseAgentError: .invalidReference("The selected phase is unavailable.")),
                canReauthorize: false
            )
            return
        case .unavailable:
            activePhaseSelectionStatuses[projectID] = .mutationFailed(
                FailureStatePresentation(activePhaseAgentError: .appUnavailable),
                canReauthorize: false
            )
            return
        case .happy, .noAlternative, .authorizationFailure, .savedRefresh,
             .emptyPhase, .noActivePointer, .crossPhaseDetail, nil:
            break
        }
#endif

        let phaseName = dashboard?.projects
            .first(where: { $0.id == projectID })?
            .phases.first(where: { $0.id == phaseID })?
            .name ?? phaseID.rawValue
        do {
            let store = self.store
            let result = try await projectOnboarding.withAuthorizedProject(projectID: projectID) { project in
                await AgentCommandDispatcher(
                    store: store,
                    projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                ).dispatch(
                    AgentCommandEnvelope(
                        version: AgentCommandDispatcher.commandEnvelopeVersion,
                        requestID: requestID,
                        projectRoot: project.canonicalRoot.path,
                        expectedRegistration: expectedRegistration,
                        reason: "Owner selected active phase \(phaseID.rawValue)",
                        command: .setActivePhase(phaseID: phaseID.rawValue)
                    ),
                    origin: .ownerApp
                )
            }
            if let error = result.error {
                activePhaseSelectionStatuses[projectID] = .mutationFailed(
                    FailureStatePresentation(activePhaseAgentError: error),
                    canReauthorize: false
                )
                return
            }
            let outcome = await reloadProjectProjections(
                context: .ownerActivePhaseCommitted(projectID, phaseID, phaseName)
            )
            guard outcome != .superseded else { return }
        } catch let error as ProjectAuthorizationError {
            activePhaseSelectionStatuses[projectID] = .mutationFailed(
                FailureStatePresentation(activePhaseAuthorizationError: error),
                canReauthorize: Self.canReauthorizeActivePhase(after: error)
            )
        } catch {
            activePhaseSelectionStatuses[projectID] = .mutationFailed(
                FailureStatePresentation(activePhaseAgentError: .internalFailure(error.localizedDescription)),
                canReauthorize: false
            )
        }
    }

    func reloadAfterActivePhaseSelection(projectID: ProjectID) async {
        switch activePhaseSelectionStatus(for: projectID) {
        case let .savedNeedsReload(phaseID, phaseName):
            _ = await reloadProjectProjections(
                context: .ownerActivePhaseCommitted(projectID, phaseID, phaseName)
            )
        case .idle, .mutationFailed:
            _ = await reloadProjectProjections()
        case .saving:
            break
        }
    }

    func reauthorizeActivePhaseProject(at folder: URL, projectID: ProjectID) async {
        guard case let .mutationFailed(_, canReauthorize) = activePhaseSelectionStatuses[projectID],
              canReauthorize else { return }
        do {
            try await projectOnboarding.reauthorizeProjectRoot(folder, for: projectID)
            activePhaseSelectionStatuses[projectID] = .idle
        } catch let error as ProjectAuthorizationError {
            activePhaseSelectionStatuses[projectID] = .mutationFailed(
                FailureStatePresentation(activePhaseAuthorizationError: error),
                canReauthorize: true
            )
        } catch {
            activePhaseSelectionStatuses[projectID] = .mutationFailed(
                FailureStatePresentation(activePhaseAgentError: .internalFailure(error.localizedDescription)),
                canReauthorize: true
            )
        }
    }

    func reauthorizeProjectHealthRoot(at folder: URL, projectID: ProjectID) async throws -> ProjectHealthSnapshot {
        try await projectOnboarding.reauthorizeProjectRoot(folder, for: projectID)
        _ = await reloadProjectProjections()
        return await projectHealth(for: projectID)
    }

    func reloadDashboardAfterCommittedAgentCommand() async {
        _ = await reloadProjectProjections(context: .agentCommandCommitted)
    }

    func reloadAfterRepositoryRelocation() async {
        // Root relocation must re-observe authorization and guidance instead of
        // reusing the pre-relocation cache. This does not rerun app startup.
        _ = await reloadProjectProjections()
    }

    func scopedReviewActionFailure(for projectID: ProjectID) -> FailureStatePresentation? {
        reviewActionStates[projectID]?.failure
    }

    func scopedReviewAuthorizationRecovery(for projectID: ProjectID) -> ReviewAuthorizationRecovery? {
        reviewActionStates[projectID]?.recovery
    }

    func scopedIsPerformingReviewAction(for projectID: ProjectID) -> Bool {
        performingReviewActionProjectIDs.contains(projectID)
    }

    func performReviewDecision(_ decision: ReviewDecision, item: ReviewItemProjection) async {
        let expectedRegistration = dashboard?.projects.first { $0.id == item.projectID }?.registration
        performingReviewActionProjectIDs.insert(item.projectID)
        reviewActionStates[item.projectID] = nil
        defer { performingReviewActionProjectIDs.remove(item.projectID) }
        do {
            let command: AgentCommand = switch decision {
            case .resolve: .resolveImportReview(reviewItemID: item.id.rawValue)
            case .dismiss: .dismissImportReview(reviewItemID: item.id.rawValue)
            }
            let verb = decision == .resolve ? "Resolve" : "Dismiss"
            let store = self.store
            let result = try await projectOnboarding.withAuthorizedProject(projectID: item.projectID) { project in
                await AgentCommandDispatcher(
                    store: store,
                    projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                ).dispatch(
                    AgentCommandEnvelope(
                        version: AgentCommandDispatcher.commandEnvelopeVersion,
                        requestID: UUID(),
                        projectRoot: project.canonicalRoot.path,
                        expectedRegistration: expectedRegistration,
                        reason: "\(verb) review \(item.id.rawValue)",
                        command: command
                    ),
                    origin: .ownerApp
                )
            }
            if let error = result.error {
                reviewActionStates[item.projectID] = ReviewActionState(
                    message: "Review action failed: \(String(describing: error))",
                    failure: FailureStatePresentation(agentError: error),
                    recovery: nil
                )
                return
            }
            applyCommittedReviewDecision(decision, item: item)
            selectedReviewItemID = reviewInboxes[item.projectID]?.openItems.first?.id
            do {
                reviewInboxes[item.projectID] = try await reviewInboxLoader(store, item.projectID)
                projectActivities[item.projectID] = try await ProjectActivityProjection.load(
                    from: store,
                    projectID: item.projectID
                )
                selectedReviewItemID = reviewInboxes[item.projectID]?.openItems.first?.id
            } catch {
                presentReviewRefreshFailure(
                    projectID: item.projectID,
                    detail: "The review decision was saved, but Release Radar could not refresh the latest project view. Do not retry the decision; reload the dashboard."
                )
            }
            await notificationCoordinator.dispatchPending()
        } catch let error as ProjectAuthorizationError {
            presentReviewAuthorizationFailure(error, projectID: item.projectID)
        } catch {
            reviewActionStates[item.projectID] = ReviewActionState(
                message: "Review action failed: \(error.localizedDescription)",
                failure: FailureStatePresentation(
                    agentError: .internalFailure(error.localizedDescription)
                ),
                recovery: nil
            )
        }
    }

    func recoverReviewAuthorization(at folder: URL, for projectID: ProjectID) async {
        guard let recovery = scopedReviewAuthorizationRecovery(for: projectID) else { return }
        performingReviewActionProjectIDs.insert(projectID)
        reviewActionStates[projectID] = nil
        defer { performingReviewActionProjectIDs.remove(projectID) }
        do {
            switch recovery {
            case .reauthorizeProjectRoot:
                try await projectOnboarding.reauthorizeProjectRoot(folder, for: projectID)
            case .associateFirstProjectRoot:
                try await projectOnboarding.associateFirstProjectRoot(folder, for: projectID)
            }
            reviewActionStates[projectID] = nil
            if await reloadProjectProjections() == .failed {
                presentReviewRefreshFailure(
                    projectID: projectID,
                    detail: "Folder access was restored, but Release Radar could not refresh the latest project view. Reload the dashboard before continuing."
                )
            }
        } catch let error as ProjectAuthorizationError {
            reviewActionStates[projectID] = ReviewActionState(
                message: "Folder authorization failed: \(error.localizedDescription)",
                failure: FailureStatePresentation(projectAuthorizationError: error),
                recovery: recovery
            )
        } catch {
            reviewActionStates[projectID] = ReviewActionState(
                message: "Folder authorization failed: \(error.localizedDescription)",
                failure: FailureStatePresentation(
                    agentError: .internalFailure(error.localizedDescription)
                ),
                recovery: recovery
            )
        }
    }

    private func presentReviewAuthorizationFailure(_ error: ProjectAuthorizationError, projectID: ProjectID) {
        let recovery: ReviewAuthorizationRecovery? = switch error {
        case .projectRootMissing: .associateFirstProjectRoot
        case .bookmarkMissing, .bookmarkStale, .bookmarkResolutionFailed,
             .securityScopeAccessDenied, .bookmarkRootMismatch: .reauthorizeProjectRoot
        case .projectNotFound, .projectRootAlreadyAssociated, .projectRootMismatch,
             .rootAlreadyOwned, .invalidFolder: nil
        }
        reviewActionStates[projectID] = ReviewActionState(
            message: "Review action blocked: \(error.localizedDescription)",
            failure: FailureStatePresentation(projectAuthorizationError: error),
            recovery: recovery
        )
    }

    private func presentReviewRefreshFailure(projectID: ProjectID, detail: String) {
        reviewActionStates[projectID] = ReviewActionState(
            message: detail,
            failure: FailureStatePresentation(
                title: "Saved; refresh needed",
                detail: detail,
                systemImage: "arrow.clockwise.circle",
                tone: .warning,
                accessibilityID: "review-refresh-failed"
            ),
            recovery: nil
        )
    }

    private func applyCommittedReviewDecision(_ decision: ReviewDecision, item: ReviewItemProjection) {
        guard let inbox = reviewInboxes[item.projectID] else { return }
        let committed = ReviewItemProjection(
            id: item.id,
            projectID: item.projectID,
            ticketID: item.ticketID,
            kind: item.kind,
            summary: item.summary,
            status: decision == .resolve ? .resolved : .dismissed
        )
        reviewInboxes[item.projectID] = ReviewInboxProjection(
            projectID: inbox.projectID,
            openItems: inbox.openItems.filter { $0.id != item.id },
            completedItems: inbox.completedItems.filter { $0.id != item.id } + [committed],
            deliveryGoalAcceptances: inbox.deliveryGoalAcceptances
        )
    }

    private func prepareProjectProjections(
        context: ProjectionReloadContext
    ) async throws -> PreparedProjectProjections {
        let dashboard = try await dashboardLoader(store)
        var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
        var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
        var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
        var removedActivities: [ProjectRemovalID: ProjectActivityProjection] = [:]
        var projectDocumentationStates: [ProjectID: ProjectDocumentationState] = [:]
        var projectRoots: [ProjectID: URL] = [:]
        var selectedTicketID = self.selectedTicketID
        let visibleProjectID = selection.projectID
            ?? selectedProjectID
            ?? dashboard.projects.first?.id
            ?? DashboardSampleData.projectID

        for project in dashboard.projects {
            reviewInboxes[project.id] = try await reviewInboxLoader(store, project.id)
            projectActivities[project.id] = try await ProjectActivityProjection.load(from: store, projectID: project.id)
            switch context {
            case .ordinary:
                let guidance = await projectOnboarding.observeProjectGuidanceContext(projectID: project.id)
                projectDocumentationStates[project.id] = guidance.documentationState
                projectRoots[project.id] = guidance.projectRoot
            case .ownerActivePhaseCommitted, .ownerDeliveryGoalCommitted, .agentCommandCommitted:
                projectDocumentationStates[project.id] = self.projectDocumentationStates[project.id] ?? .legacy(.unavailable)
                projectRoots[project.id] = self.projectRoots[project.id]
            }
            guard let board = dashboard.board(for: project.id) else { continue }
            let preferredID = board.detail(for: self.selectedTicketID) == nil
                ? board.lanes.flatMap(\.cards).map(\.id).min { $0.rawValue < $1.rawValue }
                : self.selectedTicketID
            if project.id == visibleProjectID {
                let visibleBoard = viewedBoard(in: dashboard, for: project.id)
                selectedTicketID = visibleBoard?.detail(for: self.selectedTicketID) != nil
                    ? self.selectedTicketID
                    : visibleBoard?.lanes.flatMap(\.cards).map(\.id).min { $0.rawValue < $1.rawValue }
                        ?? TicketID(rawValue: "")
            }
            guard let preferredID else { continue }
            dependencyGraphs[project.id] = try await DependencyGraphProjection.load(
                from: store,
                projectID: project.id,
                phaseID: board.phaseID,
                selectedTicketID: preferredID
            )
        }
        for removed in dashboard.removedProjects {
            removedActivities[removed.id] = try await ProjectActivityProjection.loadRemoved(
                from: store, removalID: removed.id
            )
        }
        return PreparedProjectProjections(
            dashboard: dashboard,
            reviewInboxes: reviewInboxes,
            dependencyGraphs: dependencyGraphs,
            projectActivities: projectActivities,
            removedActivities: removedActivities,
            projectDocumentationStates: projectDocumentationStates,
            projectRoots: projectRoots,
            selectedTicketID: selectedTicketID,
            selectedReviewItemID: reviewInboxes[visibleProjectID]?.openItems.first?.id
        )
    }

    private func publish(_ prepared: PreparedProjectProjections) {
        dashboard = prepared.dashboard
        reviewInboxes = prepared.reviewInboxes
        dependencyGraphs = prepared.dependencyGraphs
        projectActivities = prepared.projectActivities
        removedActivities = prepared.removedActivities
        projectDocumentationStates = prepared.projectDocumentationStates
        projectRoots = prepared.projectRoots
        selectedTicketID = prepared.selectedTicketID
        selectedReviewItemID = prepared.selectedReviewItemID
        dashboardError = nil
        for projectID in prepared.reviewInboxes.keys where deliveryGoalAcceptanceNeedsReload(for: projectID) {
            deliveryGoalReloadRequired.remove(Data(projectID.rawValue.utf8))
            reviewActionStates[projectID] = nil
        }

        for projectID in Array(activePhaseSelectionStatuses.keys) {
            let activePhaseID = prepared.dashboard.projects.first { $0.id == projectID }?.activePhaseID
            switch activePhaseSelectionStatuses[projectID] {
            case let .saving(target), let .savedNeedsReload(target, _):
                if activePhaseID == target {
                    activePhaseSelectionStatuses[projectID] = .idle
                }
            case .idle, .mutationFailed, nil:
                break
            }
        }
    }

    private func publishFailure(_ error: Error, context: ProjectionReloadContext) {
        switch context {
        case let .ownerActivePhaseCommitted(projectID, phaseID, phaseName):
            activePhaseSelectionStatuses[projectID] = .savedNeedsReload(phaseID, phaseName)
        case let .ownerDeliveryGoalCommitted(projectID):
            let detail = "Delivery Goal acceptance was saved, but the latest project view could not be refreshed. Reload the dashboard; do not submit acceptance again."
            presentReviewRefreshFailure(projectID: projectID, detail: detail)
            dashboardError = detail
        case .agentCommandCommitted:
            dashboardError = "The agent action was saved, but Release Radar could not refresh the latest project view. Reload the dashboard to see the change."
        case .ordinary:
            dashboardError = error.localizedDescription
        }
    }

    private func reloadProjectProjections(
        context: ProjectionReloadContext = .ordinary
    ) async -> ProjectionReloadOutcome {
        projectionReloadGeneration += 1
        let generation = projectionReloadGeneration
#if DEBUG
        if case .ownerActivePhaseCommitted = context,
           rr9ActivePhaseCaptureScenario == .savedRefresh,
           !rr9SavedRefreshFailureConsumed {
            rr9SavedRefreshFailureConsumed = true
            guard generation == projectionReloadGeneration else { return .superseded }
            publishFailure(RR9ActivePhaseCaptureError.savedRefresh, context: context)
            return .failed
        }
#endif
        do {
            let prepared = try await prepareProjectProjections(context: context)
            guard generation == projectionReloadGeneration else { return .superseded }
            publish(prepared)
            return .published
        } catch {
            guard generation == projectionReloadGeneration else { return .superseded }
            publishFailure(error, context: context)
            return .failed
        }
    }

    private func refreshActivities(for dashboard: DashboardProjection) async throws {
        for project in dashboard.projects {
            projectActivities[project.id] = try await ProjectActivityProjection.load(
                from: store,
                projectID: project.id
            )
        }
    }

    private static func canReauthorizeActivePhase(after error: ProjectAuthorizationError) -> Bool {
        switch error {
        case .bookmarkMissing, .bookmarkStale, .bookmarkResolutionFailed,
             .securityScopeAccessDenied, .bookmarkRootMismatch:
            true
        case .projectNotFound, .projectRootMissing, .projectRootAlreadyAssociated,
             .projectRootMismatch, .rootAlreadyOwned, .invalidFolder:
            false
        }
    }

#if DEBUG
    private func applyRR9InitialRoute(for scenario: RR9ActivePhaseCaptureScenario) {
        let projectID = RR9ActivePhaseCaptureFixture.projectID(for: scenario)
        selectedProjectID = projectID
        switch scenario {
        case .emptyPhase:
            selection = .phaseBoard(projectID)
        case .crossPhaseDetail:
            selectedTicketID = RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID
            selection = .phaseBoard(projectID)
        case .happy, .busy, .noAlternative, .mutationFailure, .unavailable,
             .authorizationFailure, .savedRefresh, .noActivePointer:
            selection = .projectOverview(projectID)
        }
    }
#endif

    private func refreshNotificationActivity(for projectID: ProjectID) async {
        do {
            projectActivities[projectID] = try await ProjectActivityProjection.load(
                from: store,
                projectID: projectID
            )
        } catch {
            dashboardError = error.localizedDescription
        }
    }

    func loadPushoverConfiguration() async {
        do {
            isPushoverConfigured = try pushoverKeychain.loadCredentials() != nil
            pushoverSettingsMessage = nil
        } catch {
            isPushoverConfigured = false
            pushoverSettingsMessage = "Keychain access is unavailable."
        }
    }

    func savePushoverCredentials() async {
        let token = pushoverAppToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = pushoverUserKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !user.isEmpty else {
            pushoverSettingsMessage = "Enter both the application token and user key."
            return
        }
        do {
            try pushoverKeychain.save(.init(appToken: token, userKey: user))
            pushoverAppToken = ""
            pushoverUserKey = ""
            isPushoverConfigured = true
            pushoverSettingsMessage = "Credentials saved to this device."
            await notificationCoordinator.dispatchPending()
        } catch {
            isPushoverConfigured = false
            pushoverSettingsMessage = "Credentials could not be saved to Keychain."
        }
    }

    func removePushoverCredentials() async {
        do {
            try pushoverKeychain.deleteCredentials()
            isPushoverConfigured = false
            pushoverSettingsMessage = "Credentials removed from this device."
        } catch {
            pushoverSettingsMessage = "Credentials could not be removed from Keychain."
        }
    }

    func loadCodexRuntime() async {
        do {
            codexSnapshot = try await codexObserver.snapshot()
        } catch {
            codexSnapshot = .unavailable(reason: error.localizedDescription)
        }
    }

    func initializeForLaunch() async {
        await loadCodexRuntime()
        if dashboard == nil {
            await loadDashboard()
        }
        await initializeCodexPluginLifecycleForLaunch()
    }

    func initializeCodexPluginLifecycleForLaunch() async {
        guard !didInitializeCodexPluginLifecycle else { return }
        didInitializeCodexPluginLifecycle = true
        guard !externalServicesSuppressed else {
            codexPluginState = .notInstalled
            return
        }
        guard let codexPluginCoordinator else {
            codexPluginState = .failed(.integrityInvalid)
            codexPluginObservedAt = Date()
            return
        }
        codexPluginOperation = .checking
        codexPluginAnnouncement = CodexPluginOperation.checking.announcement
        if recoveryStartupError != nil || recoveryResumedAtLaunch {
            applyRecoveryCodexStatus(await codexPluginCoordinator.recoveryStatus())
            codexPluginOperation = nil
            return
        }
        let result = await codexPluginCoordinator.performAutomaticUpdateIfEligible()
        applyCodexPluginResult(result, operation: .checking)
    }

    func loadCodexPluginStatus(retrying: Bool = false) async {
        guard codexPluginOperation == nil else { return }
        guard let codexPluginCoordinator else {
            codexPluginState = .failed(.integrityInvalid)
            codexPluginObservedAt = Date()
            return
        }
        let operation: CodexPluginOperation = retrying ? .tryAgain : .checking
        beginCodexPluginOperation(operation)
        let result = await codexPluginCoordinator.status()
        applyCodexPluginResult(result, operation: operation)
    }

    func installCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.install)
        applyCodexPluginResult(await codexPluginCoordinator.install(), operation: .install)
    }

    func updateCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.update)
        applyCodexPluginResult(await codexPluginCoordinator.update(), operation: .update)
    }

    func removeCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.remove)
        applyCodexPluginResult(await codexPluginCoordinator.remove(), operation: .remove)
    }

    func reinstallCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.reinstall)
        applyCodexPluginResult(await codexPluginCoordinator.reinstall(), operation: .reinstall)
    }

    private func beginCodexPluginOperation(_ operation: CodexPluginOperation) {
        codexPluginOperation = operation
        codexPluginSettingsMessage = nil
        codexPluginAnnouncement = operation.announcement
    }

    private func applyCodexPluginResult(
        _ result: CodexPluginLifecycleResult,
        operation: CodexPluginOperation
    ) {
        codexPluginState = result.state
        codexPluginObservedAt = Date()
        codexPluginOperation = nil
        codexPluginAnnouncement = CodexPluginSettingsPresentation(state: result.state).status
        if result.changedInstallation {
            codexPluginSettingsMessage = "Start a new Codex task to load the plugin change."
        } else if case .failed = result.state {
            codexPluginSettingsMessage = CodexPluginSettingsPresentation(state: result.state).detail
        } else if operation == .tryAgain {
            codexPluginSettingsMessage = nil
        }
    }
}

enum ReviewDecision: Equatable, Sendable {
    case resolve
    case dismiss
}

enum ReviewAuthorizationRecovery: Equatable, Sendable {
    case reauthorizeProjectRoot
    case associateFirstProjectRoot

    var actionTitle: String {
        switch self {
        case .reauthorizeProjectRoot: "Locate / Reauthorize…"
        case .associateFirstProjectRoot: "Associate project folder…"
        }
    }
}

private struct ReviewActionState {
    let message: String
    let failure: FailureStatePresentation?
    let recovery: ReviewAuthorizationRecovery?
}
