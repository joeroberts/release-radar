import Foundation
import Observation
import ReleaseRadarCore

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
    var reviewActionError: String?
    var reviewActionFailure: FailureStatePresentation?
    var isPerformingReviewAction = false
    var pushoverAppToken = ""
    var pushoverUserKey = ""
    var isPushoverConfigured = false
    var pushoverSettingsMessage: String?

    private let store: DeliveryStore
    private let seedSampleData: Bool
    private let codexObserver: any CodexObserver
    private let pushoverKeychain: PushoverKeychainStore
    private let notificationCoordinator: AppNotificationCoordinator
    private(set) var selectedProjectID: ProjectID?
    private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
    private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
    private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]

    init(
        store: DeliveryStore,
        codexObserver: any CodexObserver = UnavailableCodexObserver(),
        pushoverKeychain: PushoverKeychainStore? = nil,
        notificationCoordinator: AppNotificationCoordinator? = nil,
        seedSampleData: Bool = true
    ) {
        let resolvedKeychain = pushoverKeychain ?? PushoverKeychainStore()
        self.store = store
        self.seedSampleData = seedSampleData
        self.codexObserver = codexObserver
        self.pushoverKeychain = resolvedKeychain
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
        do {
            await notificationCoordinator.setActivityRefreshHandler { [weak self] projectID in
                await self?.refreshNotificationActivity(for: projectID)
            }
            if seedSampleData {
                try await DashboardSampleData.seedIfNeeded(in: store)
            }
            let loadedDashboard = try await DashboardProjection.load(from: store)
            dashboard = loadedDashboard
            try await loadWorkspace(for: loadedDashboard)
            await loadPushoverConfiguration()
            await notificationCoordinator.dispatchPending()
            try await refreshActivities(for: loadedDashboard)
            dashboardError = nil
        } catch {
            dashboardError = error.localizedDescription
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

    func performReviewDecision(_ decision: ReviewDecision, item: ReviewItemProjection) async {
        isPerformingReviewAction = true
        reviewActionError = nil
        reviewActionFailure = nil
        defer { isPerformingReviewAction = false }
        do {
            let rootPaths = try await store.read { connection in
                var paths: [String] = []
                var offset: Int64 = 0
                while let path = try connection.scalarText(
                    "SELECT path FROM project_roots WHERE project_id = ? ORDER BY rowid LIMIT 1 OFFSET ?",
                    bindings: [.text(item.projectID.rawValue), .integer(offset)]
                ) {
                    paths.append(path)
                    offset += 1
                }
                return paths
            }
            guard let selectedRootPath = rootPaths.first else {
                reviewActionError = "Review action failed: no authorized project root is available."
                reviewActionFailure = FailureStatePresentation(agentError: .unauthorizedProjectRoot)
                return
            }
            let selectedRoot = URL(fileURLWithPath: selectedRootPath)
            let project = AuthorizedProject(
                projectID: item.projectID,
                canonicalRoot: selectedRoot,
                authorizedRoots: rootPaths.map { URL(fileURLWithPath: $0) }
            )
            let dispatcher = AgentCommandDispatcher(
                store: store,
                projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
            )
            let command: AgentCommand = switch decision {
            case .resolve: .resolveImportReview(reviewItemID: item.id.rawValue)
            case .dismiss: .dismissImportReview(reviewItemID: item.id.rawValue)
            }
            let verb = decision == .resolve ? "Resolve" : "Dismiss"
            let result = await dispatcher.dispatch(
                AgentCommandEnvelope(
                    version: AgentCommandDispatcher.commandEnvelopeVersion,
                    requestID: UUID(),
                    projectRoot: selectedRootPath,
                    reason: "\(verb) review \(item.id.rawValue)",
                    command: command
                ),
                origin: .ownerApp
            )
            if let error = result.error {
                reviewActionError = "Review action failed: \(String(describing: error))"
                reviewActionFailure = FailureStatePresentation(agentError: error)
                return
            }
            reviewInboxes[item.projectID] = try await ReviewInboxProjection.load(
                from: store,
                projectID: item.projectID
            )
            projectActivities[item.projectID] = try await ProjectActivityProjection.load(
                from: store,
                projectID: item.projectID
            )
            selectedReviewItemID = reviewInboxes[item.projectID]?.openItems.first?.id
            await notificationCoordinator.dispatchPending()
        } catch {
            reviewActionError = "Review action failed: \(error.localizedDescription)"
            reviewActionFailure = FailureStatePresentation(
                agentError: .internalFailure(error.localizedDescription)
            )
        }
    }

    private func loadWorkspace(for dashboard: DashboardProjection) async throws {
        for project in dashboard.projects {
            reviewInboxes[project.id] = try await ReviewInboxProjection.load(from: store, projectID: project.id)
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
