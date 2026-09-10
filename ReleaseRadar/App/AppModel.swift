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
    let unavailableSelectedTicketID: TicketID?
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
    private(set) var navigationHistory = NavigationHistory(initial: .projects)
    private(set) var navigationRecoveryMessage: String?
    private(set) var navigationFocus: NavigationFocus? = .route(.projects)
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
    private let codexPluginShippedCapability: RecognizedPluginCapability?
    private let pushoverKeychain: PushoverKeychainStore
    private var notificationCoordinator: AppNotificationCoordinator
    private var projectOnboarding: FolderProjectOnboarding
    private let recoveryServices: ReleaseRadarAppServices?
    private var recoveryStartupError: String?
    private var recoveryResumedAtLaunch: Bool
    private let reviewInboxLoader: @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection
    private let dashboardLoader: @Sendable (DeliveryStore, [ProjectID: [EvidenceReadback]]) async throws -> DashboardProjection
    private var documentationObserver: DocumentationObservationCoordinator
    private let evidencePreviewLoader: @Sendable (DeliveryStore, ProjectID, EvidenceID) async -> EvidencePreview
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
    private var allPhaseBoardProjectIDs: Set<Data> = []
    private var boardFilters: [PhaseBoardKey: DeliveryGoalFilter] = [:]
    private var allPhaseBoardFilters: [Data: DeliveryGoalFilter] = [:]
    private var deliveryGoalReloadRequired: Set<Data> = []
    private var performingReviewActionProjectIDs: Set<ProjectID> = []
    private var alertRulesFailureState: AlertRulesFailureState?
    private var didInitializeCodexPluginLifecycle = false
    private var codexPluginObservedAt: Date?
    private var projectionReloadGeneration: UInt64 = 0
    private var navigationGeneration: UInt64 = 0
    private(set) var documentationServiceGeneration: UInt64 = 0
    @ObservationIgnored private var documentationMonitoringTask: Task<Void, Never>?
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
        codexPluginShippedCapability: RecognizedPluginCapability? = nil,
        pushoverKeychain: PushoverKeychainStore? = nil,
        notificationCoordinator: AppNotificationCoordinator? = nil,
        projectOnboarding: FolderProjectOnboarding? = nil,
        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
            try await ReviewInboxProjection.load(from: $0, projectID: $1)
        },
        dashboardLoader: (@Sendable (DeliveryStore) async throws -> DashboardProjection)? = nil,
        requestIDGenerator: @escaping () -> UUID = { UUID() },
        recoveryServices: ReleaseRadarAppServices? = nil,
        recoveryStartupError: String? = nil,
        recoveryResumedAtLaunch: Bool = false,
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false,
        documentationObserver: DocumentationObservationCoordinator? = nil,
        evidencePreviewLoader: (@Sendable (DeliveryStore, ProjectID, EvidenceID) async -> EvidencePreview)? = nil
    ) {
        let resolvedKeychain = pushoverKeychain ?? PushoverKeychainStore()
        self.store = store
        self.databaseURL = databaseURL ?? store.databaseURL
        self.seedSampleData = seedSampleData
        self.externalServicesSuppressed = externalServicesSuppressed
        self.codexObserver = codexObserver
        self.codexPluginCoordinator = codexPluginCoordinator
        self.codexPluginShippedVersion = codexPluginShippedVersion
        self.codexPluginShippedCapability = codexPluginShippedCapability
        self.pushoverKeychain = resolvedKeychain
        let resolvedOnboarding = projectOnboarding ?? FolderProjectOnboarding(store: store)
        self.projectOnboarding = resolvedOnboarding
        self.reviewInboxLoader = reviewInboxLoader
        self.dashboardLoader = if let dashboardLoader {
            { store, _ in try await dashboardLoader(store) }
        } else {
            { store, evidence in
                try await DashboardProjection.load(from: store, evidenceReadbacks: evidence)
            }
        }
        self.documentationObserver = documentationObserver
            ?? Self.makeDocumentationObserver(
                onboarding: resolvedOnboarding,
                pluginCoordinator: codexPluginCoordinator,
                shippedCapability: codexPluginShippedCapability
            )
        self.evidencePreviewLoader = evidencePreviewLoader ?? { store, projectID, evidenceID in
            await store.previewEvidence(projectID: projectID, evidenceID: evidenceID)
        }
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
        codexPluginShippedCapability: RecognizedPluginCapability? = nil,
        pushoverKeychain: PushoverKeychainStore? = nil,
        notificationCoordinator: AppNotificationCoordinator? = nil,
        projectOnboarding: FolderProjectOnboarding? = nil,
        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
            try await ReviewInboxProjection.load(from: $0, projectID: $1)
        },
        dashboardLoader: (@Sendable (DeliveryStore) async throws -> DashboardProjection)? = nil,
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
            codexPluginShippedCapability: codexPluginShippedCapability,
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

    var canNavigateBack: Bool { navigationHistory.canGoBack }
    var canNavigateForward: Bool { navigationHistory.canGoForward }

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
        captureCurrentNavigationContext()
        let previousProjectID = selection.projectID ?? selectedProjectID
        navigationGeneration &+= 1
        let generation = navigationGeneration
        let resolvedRoute = resolvedRouteForNavigation(route)
        navigationRecoveryMessage = resolvedRoute == route ? nil : "The requested destination changed with the project lifecycle. Its current location is shown."

        if let projectID = resolvedRoute.projectID,
           dashboard?.projects.contains(where: { $0.id == projectID }) == true {
            do {
                try await MeaningfulDeliveryEventRecorder(store: store).markDashboardOpened(projectID: projectID)
            } catch {
                guard generation == navigationGeneration else { return }
                dashboardError = error.localizedDescription
                return
            }
            guard generation == navigationGeneration else { return }
            documentationObserver.invalidate(projectID: projectID)
        }
        if let destinationProjectID = resolvedRoute.projectID,
           destinationProjectID != previousProjectID {
            selectedTicketID = TicketID(rawValue: "")
        }
        if let projectID = resolvedRoute.projectID {
            _ = await refreshDocumentationObservation(projectID: projectID, withdrawCurrent: true)
            guard generation == navigationGeneration else { return }
        }
        selection = resolvedRoute
        guard generation == navigationGeneration else { return }
        navigationFocus = .route(resolvedRoute)
        navigationHistory.navigate(to: historyEntry(for: resolvedRoute, focus: navigationFocus))
    }

    func goBack() async { await restoreNavigation(step: .back) }
    func goForward() async { await restoreNavigation(step: .forward) }

    private enum NavigationStep { case back, forward }

    private func restoreNavigation(step: NavigationStep) async {
        captureCurrentNavigationContext()
        navigationGeneration &+= 1
        let moved = switch step {
        case .back: navigationHistory.goBack()
        case .forward: navigationHistory.goForward()
        }
        guard moved else { return }
        let entry = navigationHistory.current
        navigationRecoveryMessage = nil
        restore(entry)
    }

    private func captureCurrentNavigationContext() {
        let route = navigationHistory.current.route
        let projectID = route.projectID
        let phaseID = projectID.flatMap { viewedPhaseIDs[Data($0.rawValue.utf8)] }
        let showsAllPhases = if case .phaseBoard = route {
            projectID.map { allPhaseBoardProjectIDs.contains(Data($0.rawValue.utf8)) } ?? false
        } else { false }
        let filter = projectID.flatMap { projectID in
            showsAllPhases ? (allPhaseBoardFilters[Data(projectID.rawValue.utf8)] ?? .all)
                : phaseID.map { boardFilters[PhaseBoardKey(projectID: projectID, phaseID: $0)] ?? .all }
        }
        navigationHistory.updateCurrent(
            registration: registration(for: route),
            phaseID: phaseID,
            showsAllPhases: showsAllPhases,
            filter: filter,
            selectedTicketID: projectID == nil || selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
            focus: navigationFocus
        )
    }

    private func historyEntry(for route: AppRoute, focus: NavigationFocus?) -> NavigationHistoryEntry {
        let projectID = route.projectID
        let phaseID = projectID.flatMap { viewedPhaseIDs[Data($0.rawValue.utf8)] }
        let showsAllPhases = if case .phaseBoard = route {
            projectID.map { allPhaseBoardProjectIDs.contains(Data($0.rawValue.utf8)) } ?? false
        } else { false }
        let filter = projectID.flatMap { projectID in
            showsAllPhases ? (allPhaseBoardFilters[Data(projectID.rawValue.utf8)] ?? .all)
                : phaseID.map { boardFilters[PhaseBoardKey(projectID: projectID, phaseID: $0)] ?? .all }
        }
        return .init(
            route: route,
            registration: registration(for: route),
            phaseID: phaseID,
            showsAllPhases: showsAllPhases,
            filter: filter,
            selectedTicketID: projectID == nil || selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
            focus: focus
        )
    }

    private func registration(for route: AppRoute) -> ProjectRegistration? {
        if case let .removedProject(removalID) = route {
            return dashboard?.removedProjects.first(where: { $0.id == removalID })?.registration
        }
        let projectID = switch route {
        case .needsReview, .notifications:
            selectedProjectID ?? (selection == route ? dashboard?.projects.first?.id : nil)
        default:
            route.projectID
        }
        guard let projectID else { return nil }
        return dashboard?.projects.first(where: { $0.id == projectID })?.registration
            ?? dashboard?.archivedProjects.first(where: { $0.id == projectID })?.registration
            ?? dashboard?.removedProjects.first(where: { $0.projectID == projectID })?.registration
    }

    private func resolvedRouteForNavigation(_ route: AppRoute) -> AppRoute {
        if case let .removedProject(removalID) = route {
            return dashboard?.removedProjects.contains(where: { $0.id == removalID }) == true ? route : .projects
        }
        guard let projectID = route.projectID else { return route }
        if dashboard?.projects.contains(where: { $0.id == projectID }) == true {
            return if case .archivedProject = route { .projectOverview(projectID) } else { route }
        }
        if dashboard?.archivedProjects.contains(where: { $0.id == projectID }) == true {
            return .archivedProject(projectID)
        }
        if let removed = dashboard?.removedProjects.first(where: { $0.projectID == projectID }) {
            return .removedProject(removed.id)
        }
        return .projects
    }

    private func restore(_ entry: NavigationHistoryEntry) {
        var route = entry.route
        var recovery: [String] = []
        var restoredProjectID = route.projectID

        if let registration = entry.registration {
            if dashboard?.projects.first(where: {
                $0.registration?.hasSameNavigationIdentity(as: registration) == true
            }) != nil {
                restoredProjectID = registration.projectID
                if case .archivedProject = route { route = .projectOverview(registration.projectID) }
                if case .removedProject = route { route = .projectOverview(registration.projectID) }
            } else if dashboard?.archivedProjects.contains(where: {
                $0.registration.hasSameNavigationIdentity(as: registration)
            }) == true {
                restoredProjectID = registration.projectID
                route = .archivedProject(registration.projectID)
                recovery.append("The project was archived after this history entry was recorded.")
            } else if let removed = dashboard?.removedProjects.first(where: {
                $0.registration.hasSameNavigationIdentity(as: registration)
            }) {
                restoredProjectID = nil
                route = .removedProject(removed.id)
                recovery.append("The project was removed after this history entry was recorded.")
            } else {
                restoredProjectID = nil
                route = .projects
                recovery.append("The exact project registration in this history entry is unavailable; a different registration was not substituted.")
            }
        } else {
            route = resolvedRouteForNavigation(route)
            restoredProjectID = route.projectID
        }

        if let projectID = restoredProjectID,
           let phaseID = entry.phaseID,
           dashboard?.board(for: projectID, phaseID: phaseID) != nil {
            viewedPhaseIDs[Data(projectID.rawValue.utf8)] = phaseID
            boardFilters[PhaseBoardKey(projectID: projectID, phaseID: phaseID)] = entry.filter ?? .all
        } else if entry.phaseID != nil, case let .phaseBoard(projectID) = route {
            route = .projectOverview(projectID)
            recovery.append("The previously viewed phase is unavailable; the project overview is retained.")
        }
        if let projectID = restoredProjectID, entry.showsAllPhases, case .phaseBoard = route,
           dashboard?.allPhaseBoard(for: projectID) != nil {
            let key = Data(projectID.rawValue.utf8)
            allPhaseBoardProjectIDs.insert(key)
            allPhaseBoardFilters[key] = entry.filter ?? .all
        } else if let projectID = restoredProjectID {
            allPhaseBoardProjectIDs.remove(Data(projectID.rawValue.utf8))
        }

        selectedProjectID = restoredProjectID
        selection = route
        let ticketIsAvailable = entry.selectedTicketID.map { ticketID in
            guard let projectID = restoredProjectID else { return false }
            if case .phaseBoard = route, entry.showsAllPhases {
                return dashboard?.allPhaseBoard(for: projectID)?.filtered(by: entry.filter ?? .all).detail(for: ticketID) != nil
            }
            if case .phaseBoard = route, let phaseID = entry.phaseID {
                return dashboard?.board(for: projectID, phaseID: phaseID)?
                    .filtered(by: entry.filter ?? .all)
                    .detail(for: ticketID) != nil
            }
            if case .projectPlan = route {
                return dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil
            }
            if case .activity = route {
                return dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil
            }
            if case let .referenceSource(_, routeTicketID, _, _) = route {
                return routeTicketID == ticketID
                    && dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil
            }
            if case .recordedImpacts = route {
                return dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil
            }
            return dashboard?.boards.contains(where: {
                $0.key.projectID == projectID && $0.value.detail(for: ticketID) != nil
            }) == true
        } ?? false
        selectedTicketID = ticketIsAvailable ? entry.selectedTicketID! : TicketID(rawValue: "")
        if entry.selectedTicketID != nil, !ticketIsAvailable {
            recovery.append("The previously selected ticket is unavailable; no other ticket was selected.")
        }
        var focusIsAvailable = true
        if case let .planChangeProposal(proposalID, version, ticketID)? = entry.focus {
            let proposalVersion = restoredProjectID
                .flatMap { dashboard?.plan(for: $0)?.proposals.first(where: {
                    Data($0.id.rawValue.utf8) == Data(proposalID.utf8)
                }) }
                .flatMap { proposal in
                    proposal.versions.first(where: { $0.version == version })
                }
            focusIsAvailable = proposalVersion.map { versionRecord in
                ticketID.map { Self.proposalVersion(versionRecord, references: $0) } ?? true
            } ?? false
            if !focusIsAvailable {
                recovery.append("The exact proposal version or ticket focus is unavailable; no other proposal was substituted.")
            }
        }
        navigationFocus = focusIsAvailable && (ticketIsAvailable || entry.selectedTicketID == nil)
            ? entry.focus
            : (recovery.isEmpty ? entry.focus : .recovery)
        navigationRecoveryMessage = recovery.isEmpty ? nil : recovery.joined(separator: " ")
    }

    private static func proposalVersion(
        _ version: PlanChangeProposalVersionRecord,
        references ticketID: TicketID
    ) -> Bool {
        if version.sourceImpacts.contains(where: { $0.ticketID == ticketID }) { return true }
        return version.operations.contains { operation in
            switch operation {
            case let .addUnassignedTicket(id, _),
                 let .addPendingTicketTasks(id, _),
                 let .placeTicket(id, _),
                 let .assignTicketToGoal(id, _, _),
                 let .addTicketDependency(_, id, _):
                id == ticketID
            case let .retireTicket(id, _, _, successors):
                id == ticketID || successors.contains(ticketID)
            case let .moveBacklogTicket(id, _, _),
                 let .reassignTicketToGoal(id, _, _, _):
                id == ticketID
            case let .carryGoalObligation(source, descendants, _):
                source.ticketID == ticketID || descendants.contains(where: { $0.ticketID == ticketID })
            case let .dropGoalObligation(obligation, _):
                obligation.ticketID == ticketID
            case let .retargetTicketDependency(_, id, from, to):
                id == ticketID || from == ticketID || to == ticketID
            case let .removeTicketDependency(_, id, dependency):
                id == ticketID || dependency == ticketID
            case .addPhase, .addDeliveryGoal, .addPhaseDependency, .supersedeDeliveryGoal:
                false
            }
        }
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
        try await ApplicationRecoverySecurityScope.withAccess(
            to: destinationURL.deletingLastPathComponent()
        ) {
            try await ApplicationBackupManager(
                store: self.store,
                databaseURL: self.databaseURL
            ).previewBackup(destinationURL: destinationURL)
        }
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
            let receipt = try await ApplicationRecoverySecurityScope.withAccess(
                to: preview.destinationURL.deletingLastPathComponent()
            ) {
                try await ApplicationBackupManager(
                    store: self.store,
                    databaseURL: self.databaseURL
                ).createBackup(preview)
            }
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

    func adoptRecovery(_ result: ApplicationRecoveryResult) async throws {
        documentationServiceGeneration &+= 1
        projectionReloadGeneration &+= 1
        let retiredStore = store
        let retiredOnboarding = projectOnboarding
        retiredOnboarding.retireDocumentationAuthorizations()
        if retiredStore === result.store {
            await retiredOnboarding.waitForDocumentationAuthorizationsToDrain()
        } else {
            await retiredStore.sealForRecovery()
        }
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
        documentationObserver = Self.makeDocumentationObserver(
            onboarding: projectOnboarding,
            pluginCoordinator: codexPluginCoordinator,
            shippedCapability: codexPluginShippedCapability
        )
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
        allPhaseBoardProjectIDs.removeAll()
        boardFilters.removeAll()
        allPhaseBoardFilters.removeAll()
        navigationHistory.reset()
        navigationRecoveryMessage = nil
        navigationFocus = .route(.projects)
        selectedTicketID = TicketID(rawValue: "")
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
        guard let graph = dependencyGraphs[projectID] else { return nil }
        return graph.selecting(selectedTicketID) ?? graph
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

    func documentationObservationStatus(for projectID: ProjectID) -> DocumentationObservationStatus? {
        documentationObserver.status(for: projectID)
    }

    func previewEvidence(projectID: ProjectID, evidenceID: EvidenceID) async -> EvidencePreview {
        let serviceGeneration = documentationServiceGeneration
        let currentStore = store
        let currentObserver = documentationObserver
        guard case let .observed(observation) = documentationObserver.status(for: projectID),
              observation.evidence.contains(where: { $0.evidence.id == evidenceID }) else {
            return .init(identity: .filePath(""), path: nil, status: .rejected, content: nil)
        }
        let preview = await evidencePreviewLoader(currentStore, projectID, evidenceID)
        guard serviceGeneration == documentationServiceGeneration,
              currentStore === store,
              currentObserver === documentationObserver,
              currentObserver.status(for: projectID) == .observed(observation) else {
            return .init(identity: preview.identity, path: nil, status: .rejected, content: nil)
        }
        return preview
    }

    func loadTicketReferences(
        projectID: ProjectID,
        ticketID: TicketID
    ) async -> ReferenceLoadResult<TicketReferenceSet> {
        await loadReferenceQuery(
            projectID: projectID,
            query: { rootID in
                .ticketReferences(
                    projectID: projectID.rawValue,
                    rootID: rootID,
                    ticketID: ticketID.rawValue
                )
            },
            value: \.ticketReferences
        )
    }

    func referenceQueryIdentity(projectID: ProjectID) -> String {
        let status = documentationObserver.status(for: projectID)
        let generation: UInt64
        let identity: DocumentationObservationIdentity?
        let readiness: String
        switch status {
        case let .checking(value, valueGeneration):
            identity = value
            generation = valueGeneration
            readiness = "checking"
        case let .observed(observation):
            identity = observation.identity
            generation = observation.generation
            readiness = "observed"
        case nil:
            identity = nil
            generation = 0
            readiness = "unavailable"
        }
        let registration = identity?.registration
        let binding = identity?.binding
        return [
            projectID.rawValue,
            String(documentationServiceGeneration),
            readiness,
            String(generation),
            registration?.registrationID ?? "no-registration",
            registration.map { String($0.requestGeneration) } ?? "no-request-generation",
            identity?.rootID?.rawValue ?? "no-root",
            identity?.rootPath ?? projectRoots[projectID]?.path ?? "no-root-path",
            binding?.repositoryID ?? "no-repository",
            binding.map { String($0.acceptedCatalogVersion) } ?? "no-catalog-version",
            binding?.acceptedCatalogDigest ?? "no-catalog-digest",
        ].joined(separator: ":")
    }

    func loadRecordedImpacts(
        projectID: ProjectID,
        repositoryID: String,
        artifactID: String
    ) async -> ReferenceLoadResult<RecordedImpacts> {
        await loadReferenceQuery(
            projectID: projectID,
            query: { rootID in
                .recordedImpacts(
                    projectID: projectID.rawValue,
                    rootID: rootID,
                    repositoryID: repositoryID,
                    artifactID: artifactID
                )
            },
            value: \.recordedImpacts
        )
    }

    private func loadReferenceQuery<Value: Sendable>(
        projectID: ProjectID,
        query: (String) -> AgentQuery,
        value: KeyPath<AgentCommandResult, Value?>
    ) async -> ReferenceLoadResult<Value> {
        let serviceGeneration = documentationServiceGeneration
        let currentStore = store
        let currentObserver = documentationObserver
        guard let root = projectRoots[projectID],
              case let .observed(observation) = currentObserver.status(for: projectID),
              let rootID = observation.identity.rootID?.rawValue else {
            return .failed(.init(
                title: "References unavailable",
                detail: "Restore this project's exact documentation root and reload before browsing recorded references.",
                systemImage: "questionmark.folder",
                tone: .warning,
                accessibilityID: "reference-query-unavailable"
            ))
        }
        let result = await AgentQueryDispatcher(store: currentStore).dispatch(.init(
            version: 1,
            projectRoot: root.path,
            query: query(rootID)
        ))
        guard !Task.isCancelled,
              serviceGeneration == documentationServiceGeneration,
              currentStore === store,
              currentObserver === documentationObserver,
              currentObserver.status(for: projectID) == .observed(observation),
              projectRoots[projectID]?.path == root.path else {
            return .failed(.init(
                title: "Reference context changed",
                detail: "The project registration, root, or selection changed while this source was loading. Reload the current ticket; no alternate source was selected.",
                systemImage: "arrow.clockwise",
                tone: .warning,
                accessibilityID: "reference-query-withdrawn"
            ))
        }
        if let loaded = result[keyPath: value] { return .loaded(loaded) }
        if let error = result.error, let presentation = FailureStatePresentation(agentError: error) {
            return .failed(presentation)
        }
        return .failed(.init(
            title: "References unavailable",
            detail: "The exact recorded reference could not be read. No replacement source or ticket was selected.",
            systemImage: "exclamationmark.triangle",
            tone: .warning,
            accessibilityID: "reference-query-failed"
        ))
    }

    func openReferenceSource(
        projectID: ProjectID,
        ticketID: TicketID,
        linkID: String,
        version: Int64
    ) async {
        await navigate(to: .referenceSource(
            projectID: projectID,
            ticketID: ticketID,
            linkID: linkID,
            version: version
        ))
        setNavigationFocus(.referenceSource(linkID: linkID, version: version))
    }

    func openRecordedImpacts(
        projectID: ProjectID,
        repositoryID: String,
        artifactID: String
    ) async {
        await navigate(to: .recordedImpacts(
            projectID: projectID,
            repositoryID: repositoryID,
            artifactID: artifactID
        ))
        setNavigationFocus(.recordedImpacts)
    }

    func openRecordedImpactTicket(projectID: ProjectID, impact: RecordedImpact) async {
        setNavigationFocus(.recordedImpact(rowID: impact.id))
        let ticketID = TicketID(rawValue: impact.ticketID)
        if dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil {
            await navigate(to: .projectPlan(projectID))
            selectTicket(ticketID)
        } else if let board = dashboard?.boards.values.first(where: {
            $0.project.id == projectID && $0.detail(for: ticketID) != nil
        }) {
            await navigate(to: .phaseBoard(projectID))
            viewPhase(projectID: projectID, phaseID: board.phaseID)
            selectTicket(ticketID)
        } else {
            navigationRecoveryMessage = "The recorded ticket is unavailable; no other ticket was selected."
            navigationFocus = .recovery
        }
    }

    func projectRoot(for projectID: ProjectID) -> URL? {
        projectRoots[projectID]
    }

    func startDocumentationMonitoring() {
        guard documentationMonitoringTask == nil else { return }
        documentationMonitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard let self else { return }
                await self.refreshActiveDocumentationObservations(withdrawCurrent: false)
            }
        }
    }

    func stopDocumentationMonitoring() {
        documentationMonitoringTask?.cancel()
        documentationMonitoringTask = nil
    }

    func recheckDocumentationAfterActivation() async {
        guard let dashboard else { return }
        projectionReloadGeneration &+= 1
        for project in dashboard.projects {
            documentationObserver.invalidate(projectID: project.id)
        }
        await refreshActiveDocumentationObservations(withdrawCurrent: true)
    }

    func refreshProjectDocumentation(_ projectID: ProjectID) async {
        guard dashboard?.projects.contains(where: { $0.id == projectID }) == true else { return }
        documentationObserver.invalidate(projectID: projectID)
        _ = await refreshDocumentationObservation(
            projectID: projectID,
            withdrawCurrent: true
        )
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

        let documentation = await refreshDocumentationObservation(
            projectID: projectID,
            withdrawCurrent: true
        )
        var checks: [ProjectHealthSnapshot.Check] = [
            .init(id: "storage", title: "Local storage ready", detail: "The current Release Radar schema is available.", state: .ready),
        ]
        if let rootPath = documentation?.identity.rootPath,
           !Self.documentationRootIsUnavailable(documentation?.documentationState) {
            checks.append(.init(id: "folder", title: "Folder access ready", detail: rootPath, state: .ready))
        } else {
            checks.append(.init(id: "folder", title: "Folder access needs attention", detail: "The saved authorization could not be resolved. Reauthorize the same project folder, then check again.", state: .attention))
        }

        let documentationState = documentation?.documentationState ?? .legacy(.unavailable)
        let documentationPresentation = ProjectGuidancePresentation(documentationState: documentationState)
        let documentationReady: Bool
        switch documentationState {
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
            if !current || roots.registration != documentation?.identity.registration ||
                (documentation?.identity.rootPath != nil && roots.roots.first(where: { $0.role == .primary })?.path != documentation?.identity.rootPath) {
                return .init(projectID: projectID, registration: nil, rootPath: nil, checkedAt: checkedAt,
                    checks: [.init(id: "roots", title: "Project roots changed during checking", detail: "Check health again for the current saved registration and roots. Earlier results are no longer current.", state: .unavailable)])
            }
        }
        return .init(
            projectID: projectID,
            registration: documentation?.identity.registration,
            rootPath: documentation?.identity.rootPath ?? projectRoots[projectID]?.path,
            checkedAt: documentation?.checkedAt ?? checkedAt,
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
        let key = Data(projectID.rawValue.utf8)
        if let phaseID = viewedPhaseIDs[key] {
            return dashboard.board(for: projectID, phaseID: phaseID)
        }
        guard let board = defaultBoard(in: dashboard, for: projectID) else { return nil }
        viewedPhaseIDs[key] = board.phaseID
        if selection == .phaseBoard(projectID) {
            navigationHistory.updateCurrent(
                registration: registration(for: selection),
                phaseID: board.phaseID,
                filter: boardFilter(projectID: projectID, phaseID: board.phaseID),
                selectedTicketID: selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
                focus: navigationFocus
            )
        }
        return board
    }

    func viewedAllPhaseBoard(for projectID: ProjectID) -> AllPhaseBoardProjection? {
        guard allPhaseBoardProjectIDs.contains(Data(projectID.rawValue.utf8)) else { return nil }
        return dashboard?.allPhaseBoard(for: projectID)
    }

    func allPhaseBoardFilter(projectID: ProjectID) -> DeliveryGoalFilter {
        allPhaseBoardFilters[Data(projectID.rawValue.utf8)] ?? .all
    }

    func setAllPhaseBoardFilter(_ filter: DeliveryGoalFilter, projectID: ProjectID) {
        let key = Data(projectID.rawValue.utf8)
        allPhaseBoardFilters[key] = filter
        navigationFocus = .filterSummary
        navigationHistory.updateCurrent(
            registration: registration(for: selection), phaseID: viewedPhaseIDs[key], showsAllPhases: true,
            filter: filter, selectedTicketID: selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
            focus: navigationFocus
        )
    }

    func boardFilter(projectID: ProjectID, phaseID: PhaseID) -> DeliveryGoalFilter {
        boardFilters[PhaseBoardKey(projectID: projectID, phaseID: phaseID)] ?? .all
    }

    func setBoardFilter(_ filter: DeliveryGoalFilter, projectID: ProjectID, phaseID: PhaseID) {
        boardFilters[PhaseBoardKey(projectID: projectID, phaseID: phaseID)] = filter
        navigationFocus = .filterSummary
        navigationHistory.updateCurrent(
            registration: registration(for: selection),
            phaseID: phaseID,
            filter: filter,
            selectedTicketID: selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
            focus: navigationFocus
        )
    }

    func setNavigationFocus(_ focus: NavigationFocus?) {
        navigationFocus = focus
        captureCurrentNavigationContext()
    }

    private func viewedBoard(in dashboard: DashboardProjection, for projectID: ProjectID) -> PhaseBoardProjection? {
        if let phaseID = viewedPhaseIDs[Data(projectID.rawValue.utf8)] {
            return dashboard.board(for: projectID, phaseID: phaseID)
        }
        return defaultBoard(in: dashboard, for: projectID)
    }

    private func defaultBoard(in dashboard: DashboardProjection, for projectID: ProjectID) -> PhaseBoardProjection? {
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
        allPhaseBoardProjectIDs.remove(Data(projectID.rawValue.utf8))
        if board.detail(for: selectedTicketID) == nil {
            selectedTicketID = board.lanes.flatMap(\.cards).map(\.id)
                .min { $0.rawValue < $1.rawValue } ?? TicketID(rawValue: "")
        }
        navigationHistory.updateCurrent(
            registration: registration(for: selection),
            phaseID: phaseID,
            filter: boardFilter(projectID: projectID, phaseID: phaseID),
            selectedTicketID: selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
            focus: selectedTicketID.rawValue.isEmpty ? .filterSummary : .ticket(selectedTicketID)
        )
    }

    func viewAllPhases(projectID: ProjectID) {
        guard dashboardError == nil, let board = dashboard?.allPhaseBoard(for: projectID) else { return }
        let key = Data(projectID.rawValue.utf8)
        allPhaseBoardProjectIDs.insert(key)
        if board.detail(for: selectedTicketID) == nil {
            selectedTicketID = board.lanes.flatMap(\.cards).map(\.id)
                .min { $0.rawValue < $1.rawValue } ?? TicketID(rawValue: "")
        }
        navigationHistory.updateCurrent(
            registration: registration(for: selection), phaseID: viewedPhaseIDs[key], showsAllPhases: true,
            filter: allPhaseBoardFilter(projectID: projectID),
            selectedTicketID: selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID,
            focus: selectedTicketID.rawValue.isEmpty ? .filterSummary : .ticket(selectedTicketID)
        )
    }

    func selectTicket(_ ticketID: TicketID) {
        selectedTicketID = ticketID
        navigationFocus = ticketID.rawValue.isEmpty ? .filterSummary : .ticket(ticketID)
        let key = Data(currentProjectID.rawValue.utf8)
        let phaseID = viewedPhaseIDs[key]
        let showsAllPhases = allPhaseBoardProjectIDs.contains(key)
        navigationHistory.updateCurrent(
            registration: registration(for: selection),
            phaseID: phaseID,
            showsAllPhases: showsAllPhases,
            filter: showsAllPhases ? allPhaseBoardFilter(projectID: currentProjectID)
                : phaseID.map { boardFilter(projectID: currentProjectID, phaseID: $0) },
            selectedTicketID: ticketID.rawValue.isEmpty ? nil : ticketID,
            focus: navigationFocus
        )
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

    func decidePlanChangeProposal(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        baselineDigest: String,
        disposition: PlanChangeDecisionDisposition
    ) async -> AgentCommandResult {
        let requestID = requestIDGenerator()
        return await dispatchOwnerPlanChange(
            projectID: projectID,
            requestID: requestID,
            reason: "Owner \(disposition.rawValue) plan-change proposal \(proposalID.rawValue) version \(version)",
            command: .decidePlanChangeProposal(
                proposalID: proposalID.rawValue,
                version: version,
                baselineDigest: baselineDigest,
                decisionID: "decision-\(requestID.uuidString.lowercased())",
                disposition: disposition
            )
        )
    }

    func applyPlanChangeProposal(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        version: Int64,
        baselineDigest: String,
        decisionID: String
    ) async -> AgentCommandResult {
        let requestID = requestIDGenerator()
        return await dispatchOwnerPlanChange(
            projectID: projectID,
            requestID: requestID,
            reason: "Owner applied plan-change proposal \(proposalID.rawValue) version \(version)",
            command: .applyPlanChangeProposal(
                proposalID: proposalID.rawValue,
                version: version,
                baselineDigest: baselineDigest,
                decisionID: decisionID,
                applicationID: "application-\(requestID.uuidString.lowercased())"
            )
        )
    }

    func refreshPlanChangeProposal(
        projectID: ProjectID,
        proposalID: PlanChangeProposalID,
        previousVersion: Int64,
        rationale: String,
        operations: [PlanChangeOperation]
    ) async -> AgentCommandResult {
        await dispatchOwnerPlanChange(
            projectID: projectID,
            requestID: requestIDGenerator(),
            reason: "Owner refreshed plan-change proposal \(proposalID.rawValue) after version \(previousVersion)",
            command: .savePlanChangeProposal(
                proposalID: proposalID.rawValue,
                expectedPreviousVersion: previousVersion,
                rationale: rationale,
                operations: operations
            )
        )
    }

    func transitionPhaseLifecycle(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        action: PhaseLifecycleAction,
        planningBaselineDigest: String?,
        reason: String
    ) async -> AgentCommandResult {
        guard let expectedRegistration = dashboard?.projects
            .first(where: { $0.id == projectID })?.registration else {
            return .init(entityIDs: [], auditEventID: nil, error: .staleProjectRegistration)
        }
        let requestID = requestIDGenerator()
        do {
            let store = self.store
            return try await projectOnboarding.withAuthorizedProject(projectID: projectID) { project in
                await AgentCommandDispatcher(
                    store: store,
                    projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                ).dispatch(
                    AgentCommandEnvelope(
                        version: AgentCommandDispatcher.commandEnvelopeVersion,
                        requestID: requestID,
                        projectRoot: project.canonicalRoot.path,
                        expectedRegistration: expectedRegistration,
                        reason: reason,
                        command: .transitionPhaseLifecycle(
                            projectID: projectID.rawValue,
                            phaseID: phaseID.rawValue,
                            expectedRevision: expectedRevision,
                            action: action,
                            planningBaselineDigest: planningBaselineDigest
                        )
                    ),
                    origin: .ownerApp
                )
            }
        } catch {
            return .init(entityIDs: [], auditEventID: nil, error: .unauthorizedProjectRoot)
        }
    }

    func reloadPhaseLifecycle() async {
        _ = await reloadProjectProjections()
    }

    private func dispatchOwnerPlanChange(
        projectID: ProjectID,
        requestID: UUID,
        reason: String,
        command: AgentCommand
    ) async -> AgentCommandResult {
        guard let expectedRegistration = dashboard?.projects.first(where: { $0.id == projectID })?.registration else {
            return .init(entityIDs: [], auditEventID: nil, error: .planChangeProposalRegistrationRequired)
        }
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
                        reason: reason,
                        command: command
                    ),
                    origin: .ownerApp
                )
            }
            _ = await reloadProjectProjections()
            return result
        } catch {
            return .init(
                entityIDs: [], auditEventID: nil,
                error: .unauthorizedProjectRoot
            )
        }
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
             .emptyPhase, .noActivePointer, .crossPhaseDetail, .phaseLifecycle, nil:
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
        documentationObserver.invalidate(projectID: projectID)
        _ = await reloadProjectProjections()
        return await projectHealth(for: projectID)
    }

    func restoreDocumentationFolderAccess(
        at folder: URL,
        identity: DocumentationObservationIdentity
    ) async throws -> ProjectHealthSnapshot {
        guard let registration = identity.registration,
              let rootID = identity.rootID,
              let rootPath = identity.rootPath else {
            throw ProjectRootManagementError.stale
        }
        let documentationServiceGeneration = self.documentationServiceGeneration
        let projectOnboarding = self.projectOnboarding
        let documentationObserver = self.documentationObserver
        try await projectOnboarding.reauthorizeProjectRoot(
            folder,
            target: .init(
                registration: registration,
                rootID: rootID,
                rootPath: rootPath,
                binding: identity.binding
            )
        )
        guard documentationServiceGeneration == self.documentationServiceGeneration,
              projectOnboarding === self.projectOnboarding,
              documentationObserver === self.documentationObserver else {
            throw ProjectRootManagementError.stale
        }
        projectionReloadGeneration &+= 1
        documentationObserver.invalidate(projectID: identity.projectID)
        guard await refreshDocumentationObservation(
            projectID: identity.projectID,
            withdrawCurrent: true
        ) != nil,
        documentationServiceGeneration == self.documentationServiceGeneration,
        projectOnboarding === self.projectOnboarding,
        documentationObserver === self.documentationObserver else {
            throw ProjectRootManagementError.stale
        }
        let health = await projectHealth(for: identity.projectID)
        guard documentationServiceGeneration == self.documentationServiceGeneration,
              projectOnboarding === self.projectOnboarding,
              documentationObserver === self.documentationObserver else {
            throw ProjectRootManagementError.stale
        }
        return health
    }

    func reloadDashboardAfterCommittedAgentCommand() async {
        _ = await reloadProjectProjections(context: .agentCommandCommitted)
    }

    func reloadAfterRepositoryRelocation() async {
        // Root relocation must re-observe authorization and guidance instead of
        // reusing the pre-relocation cache. This does not rerun app startup.
        if let dashboard {
            for project in dashboard.projects {
                documentationObserver.invalidate(projectID: project.id)
            }
        }
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
        let documentationServiceGeneration = self.documentationServiceGeneration
        let documentationObserver = self.documentationObserver
        let store = self.store
        let activeProjectIDs = try await store.read { connection in
            var ids: [ProjectID] = []
            var offset: Int64 = 0
            while let id = try connection.scalarText(
                "SELECT id FROM projects WHERE lifecycle = 'active' ORDER BY id LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                ids.append(.init(rawValue: id))
                offset += 1
            }
            return ids
        }
        guard documentationServiceGeneration == self.documentationServiceGeneration,
              documentationObserver === self.documentationObserver,
              store === self.store else { throw CancellationError() }
        var observations: [ProjectID: ProjectDocumentationObservation] = [:]
        for projectID in activeProjectIDs {
            guard let observation = await documentationObserver.refresh(projectID: projectID),
                  documentationServiceGeneration == self.documentationServiceGeneration,
                  documentationObserver === self.documentationObserver,
                  store === self.store else { throw CancellationError() }
            observations[projectID] = observation
        }
        let evidence = observations.mapValues(\.evidence)
        let dashboard = try await dashboardLoader(store, evidence)
        var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
        var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
        var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
        var removedActivities: [ProjectRemovalID: ProjectActivityProjection] = [:]
        var projectDocumentationStates: [ProjectID: ProjectDocumentationState] = [:]
        var projectRoots: [ProjectID: URL] = [:]
        var selectedTicketID = self.selectedTicketID
        var unavailableSelectedTicketID: TicketID?
        let visibleProjectID = selection.projectID
            ?? selectedProjectID
            ?? dashboard.projects.first?.id
            ?? DashboardSampleData.projectID

        for project in dashboard.projects {
            reviewInboxes[project.id] = try await reviewInboxLoader(store, project.id)
            projectActivities[project.id] = try await ProjectActivityProjection.load(from: store, projectID: project.id)
            let observation = observations[project.id]
            projectDocumentationStates[project.id] = observation?.documentationState ?? .legacy(.unavailable)
            projectRoots[project.id] = observation?.identity.rootPath.map(URL.init(fileURLWithPath:))
            guard let board = dashboard.board(for: project.id) ?? defaultBoard(in: dashboard, for: project.id) else { continue }
            let plan = dashboard.plan(for: project.id)
            let allPhaseBoard = dashboard.allPhaseBoard(for: project.id)
            var preferredID = board.lanes.flatMap(\.cards).map(\.id).min { $0.rawValue < $1.rawValue }
                ?? plan?.unassignedTickets.map(\.id).min { $0.rawValue < $1.rawValue }
            if project.id == visibleProjectID {
                let visibleBoard = viewedBoard(in: dashboard, for: project.id)
                let selectedTicketExists: Bool
                if selection == .dependencies(project.id) {
                    selectedTicketExists = plan?.detail(for: self.selectedTicketID) != nil || dashboard.boards.contains {
                        $0.key.projectID == project.id && $0.value.detail(for: self.selectedTicketID) != nil
                    }
                } else if selection == .projectPlan(project.id) {
                    selectedTicketExists = plan?.detail(for: self.selectedTicketID) != nil || dashboard.boards.contains {
                        $0.key.projectID == project.id && $0.value.detail(for: self.selectedTicketID) != nil
                    }
                } else if selection == .phaseBoard(project.id),
                          allPhaseBoardProjectIDs.contains(Data(project.id.rawValue.utf8)) {
                    selectedTicketExists = allPhaseBoard?.detail(for: self.selectedTicketID) != nil
                } else {
                    selectedTicketExists = visibleBoard?.detail(for: self.selectedTicketID) != nil
                }
                let canChooseDefault: Bool
                if self.dashboard == nil {
                    canChooseDefault = true
                } else if case let .ownerActivePhaseCommitted(projectID, _, _) = context {
                    canChooseDefault = projectID == project.id
                } else {
                    canChooseDefault = false
                }
                if selectedTicketExists {
                    selectedTicketID = self.selectedTicketID
                    preferredID = self.selectedTicketID
                } else if canChooseDefault {
                    if selection == .projectPlan(project.id) {
                        selectedTicketID = plan?.unassignedTickets.map(\.id).min { $0.rawValue < $1.rawValue }
                            ?? TicketID(rawValue: "")
                    } else if selection == .phaseBoard(project.id),
                              allPhaseBoardProjectIDs.contains(Data(project.id.rawValue.utf8)) {
                        selectedTicketID = allPhaseBoard?.lanes.flatMap(\.cards).map(\.id)
                            .min { $0.rawValue < $1.rawValue } ?? TicketID(rawValue: "")
                    } else {
                        selectedTicketID = visibleBoard?.lanes.flatMap(\.cards).map(\.id)
                            .min { $0.rawValue < $1.rawValue } ?? TicketID(rawValue: "")
                    }
                    preferredID = selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID
                } else if selection == .projectPlan(project.id) || selection == .phaseBoard(project.id) || selection == .dependencies(project.id) {
                    selectedTicketID = self.selectedTicketID
                    preferredID = nil
                    if !self.selectedTicketID.rawValue.isEmpty {
                        unavailableSelectedTicketID = self.selectedTicketID
                    }
                }
            }
            guard let preferredID else { continue }
            if let graph = try? await DependencyGraphProjection.load(
                from: store,
                projectID: project.id,
                phaseID: board.phaseID,
                selectedTicketID: preferredID
            ) {
                dependencyGraphs[project.id] = graph
            }
        }
        for removed in dashboard.removedProjects {
            removedActivities[removed.id] = try await ProjectActivityProjection.loadRemoved(
                from: store, removalID: removed.id
            )
        }
        guard documentationServiceGeneration == self.documentationServiceGeneration,
              documentationObserver === self.documentationObserver,
              store === self.store else { throw CancellationError() }
        return PreparedProjectProjections(
            dashboard: dashboard,
            reviewInboxes: reviewInboxes,
            dependencyGraphs: dependencyGraphs,
            projectActivities: projectActivities,
            removedActivities: removedActivities,
            projectDocumentationStates: projectDocumentationStates,
            projectRoots: projectRoots,
            selectedTicketID: selectedTicketID,
            unavailableSelectedTicketID: unavailableSelectedTicketID,
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
        var navigationRecovery: [String] = []
        if case let .phaseBoard(projectID) = selection,
           let phaseID = viewedPhaseIDs[Data(projectID.rawValue.utf8)],
           prepared.dashboard.board(for: projectID, phaseID: phaseID) == nil {
            selection = .projectOverview(projectID)
            navigationRecovery.append("The previously viewed phase is unavailable; the project overview is retained.")
        }
        if let ticketID = prepared.unavailableSelectedTicketID {
            navigationRecovery.append("The previously selected ticket \(ticketID.rawValue) is unavailable; no other ticket was selected.")
        }
        if !navigationRecovery.isEmpty {
            navigationRecoveryMessage = navigationRecovery.joined(separator: " ")
            navigationFocus = .recovery
        }
        let activeProjectIDs = Set(prepared.dashboard.projects.map(\.id))
        documentationObserver.retain(projectIDs: activeProjectIDs)
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
        } catch is CancellationError {
            return .superseded
        } catch {
            guard generation == projectionReloadGeneration else { return .superseded }
            publishFailure(error, context: context)
            return .failed
        }
    }

    @discardableResult
    private func refreshDocumentationObservation(
        projectID: ProjectID,
        withdrawCurrent: Bool
    ) async -> ProjectDocumentationObservation? {
        let documentationServiceGeneration = self.documentationServiceGeneration
        let documentationObserver = self.documentationObserver
        guard let observation = await documentationObserver.refresh(
            projectID: projectID,
            withdrawCurrent: withdrawCurrent
        ), documentationServiceGeneration == self.documentationServiceGeneration,
           documentationObserver === self.documentationObserver else { return nil }
        projectDocumentationStates[projectID] = observation.documentationState
        projectRoots[projectID] = observation.identity.rootPath.map(URL.init(fileURLWithPath:))
        if dashboard?.projects.contains(where: { $0.id == projectID }) == true {
            dashboard = dashboard?.replacingDocumentation(for: projectID, with: observation.evidence)
        }
        return observation
    }

    private func refreshActiveDocumentationObservations(withdrawCurrent: Bool) async {
        guard let dashboard else { return }
        for project in dashboard.projects {
            _ = await refreshDocumentationObservation(
                projectID: project.id,
                withdrawCurrent: withdrawCurrent
            )
        }
    }

    private static func makeDocumentationObserver(
        onboarding: FolderProjectOnboarding,
        pluginCoordinator: CodexPluginLifecycleCoordinator?,
        shippedCapability: RecognizedPluginCapability?
    ) -> DocumentationObservationCoordinator {
        DocumentationObservationCoordinator { projectID in
            for _ in 0..<2 {
                do {
                    let snapshot = try await onboarding.inspectProjectDocumentation(
                        projectID: projectID
                    )
                    return DocumentationObservationPayload(
                        snapshot,
                        pluginObservation: await sharedExecutionPluginObservation(
                            coordinator: pluginCoordinator,
                            shippedCapability: shippedCapability
                        )
                    )
                } catch ProjectDocumentationObservationError.staleContext {
                    continue
                } catch {
                    break
                }
            }
            return .init(
                identity: .init(
                    projectID: projectID,
                    registration: nil,
                    rootID: nil,
                    rootPath: nil,
                    binding: nil
                ),
                checkedAt: Date(),
                documentationState: .legacy(.unavailable),
                evidence: [],
                sharedExecutionCompatibility: .init(state: .rootUnknown, directResults: [])
            )
        }
    }

    private static func sharedExecutionPluginObservation(
        coordinator: CodexPluginLifecycleCoordinator?,
        shippedCapability: RecognizedPluginCapability?
    ) async -> SharedExecutionPluginObservation {
        guard let shippedCapability else {
            return .unavailable("The bundled plugin capability is unavailable.")
        }
        guard let coordinator else {
            return .unavailable("The plugin lifecycle service is unavailable.")
        }
        let snapshot = await coordinator.recoveryStatus()
        if let error = snapshot.error {
            return .unavailable(error.rawValue)
        }
        guard let observed = snapshot.observedState else {
            return .unknown("The plugin observation did not return a state.")
        }
        switch observed {
        case .absent:
            return .absent
        case let .clean(version, digest):
            guard let installed = RecognizedPluginCapability.recognize(
                manifestVersion: version,
                normalizedPackageDigest: digest
            ) else {
                return .unrecognized(
                    manifestVersion: version,
                    normalizedPackageDigest: digest
                )
            }
            return .clean(installed: installed, shipped: shippedCapability)
        case .modified:
            return .modified
        case let .needsRepair(error):
            return .unavailable(error.rawValue)
        }
    }

    private static func documentationRootIsUnavailable(
        _ state: ProjectDocumentationState?
    ) -> Bool {
        switch state {
        case .legacy(.unavailable), .managedUnavailable(_, .rootUnavailable, _),
             .managedUnavailable(_, .staleRoot, _), .managedUnavailable(_, .rootMismatch, _), nil:
            true
        default:
            false
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
        case .phaseLifecycle:
            selection = .projectPlan(projectID)
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
        await applyCodexPluginResult(result, operation: .checking)
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
        await applyCodexPluginResult(result, operation: operation)
    }

    func installCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.install)
        await applyCodexPluginResult(await codexPluginCoordinator.install(), operation: .install)
    }

    func updateCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.update)
        await applyCodexPluginResult(await codexPluginCoordinator.update(), operation: .update)
    }

    func removeCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.remove)
        await applyCodexPluginResult(await codexPluginCoordinator.remove(), operation: .remove)
    }

    func reinstallCodexPlugin() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.reinstall)
        await applyCodexPluginResult(await codexPluginCoordinator.reinstall(), operation: .reinstall)
    }

    private func beginCodexPluginOperation(_ operation: CodexPluginOperation) {
        codexPluginOperation = operation
        codexPluginSettingsMessage = nil
        codexPluginAnnouncement = operation.announcement
    }

    private func applyCodexPluginResult(
        _ result: CodexPluginLifecycleResult,
        operation: CodexPluginOperation
    ) async {
        codexPluginState = result.state
        codexPluginObservedAt = Date()
        codexPluginAnnouncement = CodexPluginSettingsPresentation(state: result.state).status
        if result.changedInstallation {
            codexPluginSettingsMessage = "Start a new Codex task to load the plugin change."
        } else if case .failed = result.state {
            codexPluginSettingsMessage = CodexPluginSettingsPresentation(state: result.state).detail
        } else if operation == .tryAgain {
            codexPluginSettingsMessage = nil
        }
        if let dashboard {
            for project in dashboard.projects {
                documentationObserver.invalidate(projectID: project.id)
            }
        }
        await refreshActiveDocumentationObservations(withdrawCurrent: true)
        codexPluginOperation = nil
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
