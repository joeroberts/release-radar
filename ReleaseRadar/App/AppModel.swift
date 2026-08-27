import Foundation
import Observation
import ReleaseRadarCore

enum AttachFolderOutcome: Equatable, Sendable {
    case attached
    case attachedNeedsReload
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
    var selectedReviewItemID: ReviewItemID?
    var pushoverAppToken = ""
    var pushoverUserKey = ""
    var isPushoverConfigured = false
    var pushoverSettingsMessage: String?
    var alertRules: AlertRuleSnapshot?
    var alertRuleUpdateInFlight: AlertRuleKind?

    private let store: DeliveryStore
    private let seedSampleData: Bool
    private let externalServicesSuppressed: Bool
    private let codexObserver: any CodexObserver
    private let pushoverKeychain: PushoverKeychainStore
    private let notificationCoordinator: AppNotificationCoordinator
    private let projectOnboarding: FolderProjectOnboarding
    private let reviewInboxLoader: @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection
    private let dashboardLoader: @Sendable (DeliveryStore) async throws -> DashboardProjection
    private(set) var selectedProjectID: ProjectID?
    private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
    private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
    private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
    private var reviewActionStates: [ProjectID: ReviewActionState] = [:]
    private var performingReviewActionProjectIDs: Set<ProjectID> = []
    private var alertRulesFailureState: AlertRulesFailureState?

    init(
        store: DeliveryStore,
        codexObserver: any CodexObserver = UnavailableCodexObserver(),
        pushoverKeychain: PushoverKeychainStore? = nil,
        notificationCoordinator: AppNotificationCoordinator? = nil,
        projectOnboarding: FolderProjectOnboarding? = nil,
        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
            try await ReviewInboxProjection.load(from: $0, projectID: $1)
        },
        dashboardLoader: @escaping @Sendable (DeliveryStore) async throws -> DashboardProjection = {
            try await DashboardProjection.load(from: $0)
        },
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false
    ) {
        let resolvedKeychain = pushoverKeychain ?? PushoverKeychainStore()
        self.store = store
        self.seedSampleData = seedSampleData
        self.externalServicesSuppressed = externalServicesSuppressed
        self.codexObserver = codexObserver
        self.pushoverKeychain = resolvedKeychain
        self.projectOnboarding = projectOnboarding ?? FolderProjectOnboarding(store: store)
        self.reviewInboxLoader = reviewInboxLoader
        self.dashboardLoader = dashboardLoader
        self.notificationCoordinator = notificationCoordinator
            ?? AppNotificationCoordinator(
                store: store,
                dispatcher: PushoverNotificationDispatcher(store: store, credentials: resolvedKeychain)
            )
    }

    var currentProjectID: ProjectID {
        selection.projectID
            ?? selectedProjectID
            ?? dashboard?.projects.first?.id
            ?? DashboardSampleData.projectID
    }

    var currentProject: ProjectDashboardProjection? {
        dashboard?.projects.first { $0.id == currentProjectID }
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
        reviewInbox(for: currentProjectID)?.openItems.count ?? 0
    }

    var notificationCount: Int {
        activity(for: currentProjectID)?.items.filter { $0.source == .notification }.count ?? 0
    }

    func openProject(_ projectID: ProjectID) async {
        await navigate(to: .projectOverview(projectID))
    }

    func navigate(to route: AppRoute) async {
        if let projectID = route.projectID {
            guard dashboard?.projects.contains(where: { $0.id == projectID }) == true else {
                selection = .projects
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

    func loadDashboard() async {
        await loadAlertRules()
        do {
            await notificationCoordinator.setActivityRefreshHandler { [weak self] projectID in
                await self?.refreshNotificationActivity(for: projectID)
            }
            if seedSampleData {
                try await DashboardSampleData.seedIfNeeded(in: store)
            }
            let loadedDashboard = try await dashboardLoader(store)
            dashboard = loadedDashboard
            try await loadWorkspace(for: loadedDashboard)
            if !externalServicesSuppressed {
                await loadPushoverConfiguration()
                await notificationCoordinator.dispatchPending()
            }
            try await refreshActivities(for: loadedDashboard)
            dashboardError = nil
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
        do {
            try await reloadProjectProjections()
            return .attached
        } catch {
            return .attachedNeedsReload
        }
    }

    func reloadAfterFolderAttachment(_ projectID: ProjectID) async -> Bool {
        selection = .projects
        selectedProjectID = projectID
        do {
            try await reloadProjectProjections()
            return true
        } catch {
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
            do {
                let loadedDashboard = try await DashboardProjection.load(from: store)
                dashboard = loadedDashboard
                try await loadWorkspace(for: loadedDashboard)
                try await refreshActivities(for: loadedDashboard)
            } catch {
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
            completedItems: inbox.completedItems.filter { $0.id != item.id } + [committed]
        )
    }

    private func loadWorkspace(for dashboard: DashboardProjection) async throws {
        for project in dashboard.projects {
            reviewInboxes[project.id] = try await reviewInboxLoader(store, project.id)
            projectActivities[project.id] = try await ProjectActivityProjection.load(from: store, projectID: project.id)
            guard let board = dashboard.board(for: project.id) else { continue }
            let preferredID = board.detail(for: selectedTicketID) == nil
                ? board.lanes.flatMap(\.cards).first?.id
                : selectedTicketID
            guard let preferredID else { continue }
            dependencyGraphs[project.id] = try await DependencyGraphProjection.load(
                from: store,
                projectID: project.id,
                phaseID: board.phaseID,
                selectedTicketID: preferredID
            )
        }
        selectedReviewItemID = reviewInboxes[currentProjectID]?.openItems.first?.id
    }

    private func reloadProjectProjections() async throws {
        let loadedDashboard = try await dashboardLoader(store)
        dashboard = loadedDashboard
        try await loadWorkspace(for: loadedDashboard)
        try await refreshActivities(for: loadedDashboard)
        dashboardError = nil
    }

    private func refreshActivities(for dashboard: DashboardProjection) async throws {
        for project in dashboard.projects {
            projectActivities[project.id] = try await ProjectActivityProjection.load(
                from: store,
                projectID: project.id
            )
        }
    }

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
