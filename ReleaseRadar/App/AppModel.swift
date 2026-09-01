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
    case agentCommandCommitted
}

private struct PreparedProjectProjections: Sendable {
    let dashboard: DashboardProjection
    let reviewInboxes: [ProjectID: ReviewInboxProjection]
    let dependencyGraphs: [ProjectID: DependencyGraphProjection]
    let projectActivities: [ProjectID: ProjectActivityProjection]
    let projectGuidanceStates: [ProjectID: ProjectGuidanceState]
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

    private let store: DeliveryStore
    private let seedSampleData: Bool
    private let externalServicesSuppressed: Bool
    private let codexObserver: any CodexObserver
    private let codexPluginCoordinator: CodexPluginLifecycleCoordinator?
    let codexPluginShippedVersion: String
    private let pushoverKeychain: PushoverKeychainStore
    private let notificationCoordinator: AppNotificationCoordinator
    private let projectOnboarding: FolderProjectOnboarding
    private let reviewInboxLoader: @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection
    private let dashboardLoader: @Sendable (DeliveryStore) async throws -> DashboardProjection
    private let requestIDGenerator: () -> UUID
    private(set) var selectedProjectID: ProjectID?
    private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
    private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
    private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
    private var projectGuidanceStates: [ProjectID: ProjectGuidanceState] = [:]
    private var projectRoots: [ProjectID: URL] = [:]
    private var reviewActionStates: [ProjectID: ReviewActionState] = [:]
    private var activePhaseSelectionStatuses: [ProjectID: ActivePhaseSelectionStatus] = [:]
    private var performingReviewActionProjectIDs: Set<ProjectID> = []
    private var alertRulesFailureState: AlertRulesFailureState?
    private var didInitializeCodexPluginLifecycle = false
    private var projectionReloadGeneration: UInt64 = 0
#if DEBUG
    private var rr9ActivePhaseCaptureScenario: RR9ActivePhaseCaptureScenario?
    private var rr9ActivePhaseCaptureRootDirectory: URL?
    private var rr9SavedRefreshFailureConsumed = false
#endif

    init(
        store: DeliveryStore,
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
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false
    ) {
        let resolvedKeychain = pushoverKeychain ?? PushoverKeychainStore()
        self.store = store
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
        self.notificationCoordinator = notificationCoordinator
            ?? AppNotificationCoordinator(
                store: store,
                dispatcher: PushoverNotificationDispatcher(store: store, credentials: resolvedKeychain)
            )
    }

#if DEBUG
    convenience init(
        store: DeliveryStore,
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
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false,
        rr9ActivePhaseCaptureScenario: RR9ActivePhaseCaptureScenario?,
        rr9ActivePhaseCaptureRootDirectory: URL? = nil
    ) {
        self.init(
            store: store,
            codexObserver: codexObserver,
            codexPluginCoordinator: codexPluginCoordinator,
            codexPluginShippedVersion: codexPluginShippedVersion,
            pushoverKeychain: pushoverKeychain,
            notificationCoordinator: notificationCoordinator,
            projectOnboarding: projectOnboarding,
            reviewInboxLoader: reviewInboxLoader,
            dashboardLoader: dashboardLoader,
            requestIDGenerator: requestIDGenerator,
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

    func projectGuidanceState(for projectID: ProjectID) -> ProjectGuidanceState {
        projectGuidanceStates[projectID] ?? .unavailable
    }

    func projectRoot(for projectID: ProjectID) -> URL? {
        projectRoots[projectID]
    }

    func activePhaseSelectionStatus(for projectID: ProjectID) -> ActivePhaseSelectionStatus {
        activePhaseSelectionStatuses[projectID] ?? .idle
    }

    func transitionTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        to lane: TicketLane,
        ticketTaskPlanRevision: Int64? = nil
    ) async throws -> AgentCommandResult {
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
        guard case let .savedNeedsReload(phaseID, phaseName) = activePhaseSelectionStatuses[projectID] else {
            return
        }
        _ = await reloadProjectProjections(
            context: .ownerActivePhaseCommitted(projectID, phaseID, phaseName)
        )
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

    func reloadDashboardAfterCommittedAgentCommand() async {
        _ = await reloadProjectProjections(context: .agentCommandCommitted)
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
            completedItems: inbox.completedItems.filter { $0.id != item.id } + [committed]
        )
    }

    private func prepareProjectProjections(
        context: ProjectionReloadContext
    ) async throws -> PreparedProjectProjections {
        let dashboard = try await dashboardLoader(store)
        var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
        var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
        var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
        var projectGuidanceStates: [ProjectID: ProjectGuidanceState] = [:]
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
                projectGuidanceStates[project.id] = guidance.state
                projectRoots[project.id] = guidance.projectRoot
            case .ownerActivePhaseCommitted, .agentCommandCommitted:
                projectGuidanceStates[project.id] = self.projectGuidanceStates[project.id] ?? .unavailable
                projectRoots[project.id] = self.projectRoots[project.id]
            }
            guard let board = dashboard.board(for: project.id) else { continue }
            let preferredID = board.detail(for: self.selectedTicketID) == nil
                ? board.lanes.flatMap(\.cards).map(\.id).min { $0.rawValue < $1.rawValue }
                : self.selectedTicketID
            if project.id == visibleProjectID, let preferredID {
                selectedTicketID = preferredID
            }
            guard let preferredID else { continue }
            dependencyGraphs[project.id] = try await DependencyGraphProjection.load(
                from: store,
                projectID: project.id,
                phaseID: board.phaseID,
                selectedTicketID: preferredID
            )
        }
        return PreparedProjectProjections(
            dashboard: dashboard,
            reviewInboxes: reviewInboxes,
            dependencyGraphs: dependencyGraphs,
            projectActivities: projectActivities,
            projectGuidanceStates: projectGuidanceStates,
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
        projectGuidanceStates = prepared.projectGuidanceStates
        projectRoots = prepared.projectRoots
        selectedTicketID = prepared.selectedTicketID
        selectedReviewItemID = prepared.selectedReviewItemID
        dashboardError = nil

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
            return
        }
        codexPluginOperation = .checking
        codexPluginAnnouncement = CodexPluginOperation.checking.announcement
        let result = await codexPluginCoordinator.performAutomaticUpdateIfEligible()
        applyCodexPluginResult(result, operation: .checking)
    }

    func loadCodexPluginStatus(retrying: Bool = false) async {
        guard codexPluginOperation == nil else { return }
        guard let codexPluginCoordinator else {
            codexPluginState = .failed(.integrityInvalid)
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
