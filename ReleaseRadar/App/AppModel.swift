import AppKit
import Foundation
import Observation
import ReleaseRadarCore

enum AttachFolderOutcome: Equatable, Sendable {
    case attached
    case attachedNeedsReload
}

enum WorkspaceSearchSaveOutcome: Equatable, Sendable {
    case saved(WorkspaceSavedQuery)
    case failed(String)
}

enum PermanentProjectPurgeRefreshError: Error, LocalizedError {
    case committedNeedsRefresh

    var errorDescription: String? {
        "The history was permanently purged, but Release Radar could not refresh the latest views. Reload the dashboard to finish refreshing; do not repeat the purge."
    }
}

private extension WorkspaceSearchHistorySource {
    var activitySource: ActivitySource {
        switch self {
        case .audit: .audit
        case .review: .review
        case .completion: .completion
        case .observation: .runtime
        case .notification: .notification
        }
    }
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

private struct DeliveryGoalDraftSaveKey: Hashable, Sendable {
    let projectID: ProjectID
    let phaseID: PhaseID
}

private struct PendingDeliveryGoalDraftSave: Sendable {
    let envelope: AgentCommandEnvelope
    let projectID: ProjectID
    let phaseID: PhaseID
    let registration: ProjectRegistration
    let draft: DeliveryGoalDraft
    let expectedRevision: Int64
    var error: AgentCommandError
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

private struct DependencySessionKey: Hashable {
    let projectID: ProjectID
    let registration: ProjectRegistration?
}

struct DependencyGraphPresentationIdentity: Hashable {
    let projectID: ProjectID
    let registration: ProjectRegistration?
    let focusTicketID: TicketID
}

struct DependencyGraphPresentationPersistence: Sendable {
    let load: @Sendable (
        DeliveryStore, ProjectRegistration, TicketID
    ) async throws -> DependencyGraphPresentationRecord
    let save: @Sendable (
        DeliveryStore, DependencyGraphPresentationLayout, ProjectRegistration, TicketID
    ) async throws -> Void
    let reset: @Sendable (
        DeliveryStore, ProjectRegistration, TicketID
    ) async throws -> Void

    static let live = DependencyGraphPresentationPersistence(
        load: { store, registration, ticketID in
            try await DependencyGraphPresentationRepository(store: store).load(
                registration: registration,
                focusTicketID: ticketID
            )
        },
        save: { store, layout, registration, ticketID in
            try await DependencyGraphPresentationRepository(store: store).save(
                layout,
                registration: registration,
                focusTicketID: ticketID
            )
        },
        reset: { store, registration, ticketID in
            try await DependencyGraphPresentationRepository(store: store).reset(
                registration: registration,
                focusTicketID: ticketID
            )
        }
    )
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
    private(set) var workspaceGoalsDomain: WorkspaceGoalsDomain = .delivery
    private(set) var workspaceGoalsProjectID: ProjectID?
    private(set) var workspaceGoalsDeliveryLifecycle: DeliveryGoalLifecycle?
    private(set) var workspaceGoalsExecutionStatus: String?
    private(set) var workspaceGoalsExecutionScope: WorkspaceExecutionScope = .all
    private(set) var selectedWorkspaceDeliveryGoalID: Data?
    private(set) var selectedWorkspaceExecutionGoalID: Data?
    private(set) var workspaceGoalsViewportOffset: Double?
    private var workspaceDeliveryGoalPlanningTargets: [ProjectID: DeliveryGoalEditorTarget] = [:]
    private(set) var workspaceSearchDraft = ""
    private(set) var workspaceSearchDefinition = WorkspaceSearchDefinition()
    private(set) var workspaceSearchProjection: WorkspaceSearchProjection?
    private(set) var workspaceSearchSavedQueries: [WorkspaceSavedQueryRecord] = []
    private(set) var workspaceSearchIsLoading = false
    private(set) var workspaceSearchFailure: String?
    private(set) var workspaceSearchPreferenceIsUnsupported = false
    private(set) var workspaceSearchNeedsScopeReselection = false
    private(set) var selectedWorkspaceSearchResultID: Data?
    private(set) var workspaceSearchViewportOffset: Double?
    private(set) var workspaceSearchPersistenceMessage: String?
    private(set) var navigationHistory = NavigationHistory(initial: .projects)
    private(set) var navigationRecoveryMessage: String?
    private(set) var navigationFailureMessage: String?
    private(set) var navigationFocus: NavigationFocus? = .route(.projects)
    var dashboardError: String?
    private(set) var permanentPurgeNeedsRefresh = false
    var codexContextPath: String?
    var codexContextSelectedAt: Date?
    var codexContextStatus = "Selection required"
    var codexContextFailure: String?
    var codexContextMessage: String?
    var codexContextSelectionInFlight = false
    var codexSnapshot = CodexSnapshot.unavailable(reason: UnavailableCodexObserver.defaultReason)
    var codexPluginState: CodexPluginPresentationState = .checking
    var codexPluginOperation: CodexPluginOperation?
    var codexPluginSettingsMessage: String?
    var codexPluginAnnouncement: String?
    var connectorHealthStatus = "Not yet checked"
    var connectorHealthDetail = "Check the app bridge to see its current local connection state."
    var connectorLastContact = "Not yet observed"
    var connectorHealthChecking = false
    var connectorHealthAnnouncement: String?
    private(set) var connectorHealthSnapshotGeneration: UInt64?
    private(set) var connectorHealthObservedAt: Date?
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
    private var executionResourceLifecycle: ProjectExecutionResourceLifecycle?
    let codexPluginShippedVersion: String
    private let codexPluginShippedCapability: RecognizedPluginCapability?
    private let pushoverKeychain: PushoverKeychainStore
    private var notificationCoordinator: AppNotificationCoordinator
    private var projectOnboarding: FolderProjectOnboarding
    private let recoveryServices: ReleaseRadarAppServices?
    private let connectorHealthLoader: (() async throws -> AgentBridgeHealthSnapshot)?
    private var recoveryStartupError: String?
    private var recoveryResumedAtLaunch: Bool
    private let reviewInboxLoader: @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection
    private let dashboardLoader: @Sendable (DeliveryStore, [ProjectID: [EvidenceReadback]]) async throws -> DashboardProjection
    private let dependencyGraphLoader: @Sendable (DeliveryStore, ProjectID) async throws -> DependencyGraphProjection
    private let dependencyGraphPresentationPersistence: DependencyGraphPresentationPersistence
    private let permanentPurgeExecutionRoot: () throws -> URL
    private let workspaceSearchLoader: @Sendable (DeliveryStore, WorkspaceSearchDefinition) async throws -> WorkspaceSearchProjection
    private var documentationObserver: DocumentationObservationCoordinator
    private let deliveryEvidenceBookmarkStore: any ProjectBookmarkStoring
    private let evidencePreviewLoader: @Sendable (DeliveryStore, ProjectID, EvidenceID) async -> EvidencePreview
    private let requestIDGenerator: () -> UUID
    private let repositoryPlanSourceLoader: @Sendable (
        DeliveryStore,
        FolderProjectOnboarding,
        ProjectID
    ) async throws -> RepositoryPlanSourceInventory
    private let repositoryPlanPreparationService: any RepositoryPlanPreparationServicing
    private let repositoryPlanPreviewer: @Sendable (
        RepositoryPlanReconstructionSourceSnapshot,
        RepositoryPlanProjection,
        [RepositoryPlanReconstructionCorrection],
        [RepositoryPlanReconstructionMappingSelection]
    ) async throws -> RepositoryPlanReconstructionPreview
    private let repositoryPlanOwnerCommandDispatch: @Sendable (
        ProjectID,
        ProjectRegistration,
        UUID,
        AgentCommand
    ) async -> AgentCommandResult
    private let deliveryGoalDraftOwnerCommandDispatch: @Sendable (
        ProjectID,
        ProjectRegistration,
        UUID,
        AgentCommand
    ) async -> AgentCommandResult
    private var pendingDeliveryGoalDraftSaves: [UUID: PendingDeliveryGoalDraftSave] = [:]
    private var pendingDeliveryGoalDraftSaveIDs: [DeliveryGoalDraftSaveKey: UUID] = [:]
    private let repositoryPlanReadbackLoader: @Sendable (
        DeliveryStore,
        ProjectID,
        PlanChangeProposalID?
    ) async throws -> [RepositoryPlanReconstructionReadback]
    private let repositoryPlanApplyReconciler: @Sendable (
        RepositoryPlanReconstructionApplicationAttemptRecord
    ) async throws -> RepositoryPlanReconstructionApplicationAttemptRecord
    private let repositoryPlanApplyReplayer: @Sendable (
        RepositoryPlanReconstructionApplicationAttemptRecord
    ) async -> AgentCommandResult
    private(set) var selectedProjectID: ProjectID?
    private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
    private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
    private var dependencyFocusIDs: [DependencySessionKey: TicketID] = [:]
    private var dependencyPresentationOrders: [DependencyGraphPresentationIdentity: DependencyGraphRankOrder] = [:]
    private var dependencyPresentationStatuses: [DependencyGraphPresentationIdentity: DependencyGraphArrangementStatus] = [:]
    private var loadedDependencyPresentations: Set<DependencyGraphPresentationIdentity> = []
    private var dependencyPresentationOperationGenerations: [DependencyGraphPresentationIdentity: UInt64] = [:]
    private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
    private var removedActivities: [ProjectRemovalID: ProjectActivityProjection] = [:]
    private var projectDocumentationStates: [ProjectID: ProjectDocumentationState] = [:]
    private var projectRoots: [ProjectID: URL] = [:]
    private var reviewActionStates: [ProjectID: ReviewActionState] = [:]
    private var activePhaseSelectionStatuses: [ProjectID: ActivePhaseSelectionStatus] = [:]
    private var repositoryPlanReconstructions: [ProjectID: RepositoryPlanReconstructionPresentation] = [:]
    private var repositoryPlanReconstructionGenerations: [ProjectID: UInt64] = [:]
    private var repositoryPlanPreparationOperationGenerations: [ProjectID: UInt64] = [:]
    // View preferences are ephemeral, byte-exact identities, never another active pointer.
    private var viewedPhaseIDs: [Data: PhaseID] = [:]
    private var allPhaseBoardProjectIDs: Set<Data> = []
    private var boardFilters: [PhaseBoardKey: DeliveryGoalFilter] = [:]
    private var allPhaseBoardFilters: [Data: DeliveryGoalFilter] = [:]
    private var historyFilters: [Data: HistoryFilter] = [:]
    private var selectedHistoryEventIDs: [Data: HistoryEventIdentity] = [:]
    private var historyViewportOffsets: [Data: Double] = [:]
    private var deliveryGoalReloadRequired: Set<Data> = []
    private var performingReviewActionProjectIDs: Set<ProjectID> = []
    private var alertRulesFailureState: AlertRulesFailureState?
    private var didInitializeCodexPluginLifecycle = false
    private var codexPluginObservedAt: Date?
    private var projectionReloadGeneration: UInt64 = 0
    private var navigationGeneration: UInt64 = 0
    private var lastCommittedNavigationGeneration: UInt64 = 0
    private var workspaceSearchGeneration: UInt64 = 0
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
        permanentPurgeExecutionRoot: @escaping () throws -> URL = { try ProjectExecutionFileStore.applicationRoot() },
        workspaceSearchLoader: @escaping @Sendable (DeliveryStore, WorkspaceSearchDefinition) async throws -> WorkspaceSearchProjection = {
            try await WorkspaceSearchQuery.search(store: $0, definition: $1)
        },
        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
            try await ReviewInboxProjection.load(from: $0, projectID: $1)
        },
        dashboardLoader: (@Sendable (DeliveryStore) async throws -> DashboardProjection)? = nil,
        dependencyGraphLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> DependencyGraphProjection = {
            try await DependencyGraphProjection.load(from: $0, projectID: $1)
        },
        dependencyGraphPresentationPersistence: DependencyGraphPresentationPersistence = .live,
        requestIDGenerator: @escaping () -> UUID = { UUID() },
        recoveryServices: ReleaseRadarAppServices? = nil,
        connectorHealthLoader: (() async throws -> AgentBridgeHealthSnapshot)? = nil,
        recoveryStartupError: String? = nil,
        recoveryResumedAtLaunch: Bool = false,
        externalServicesSuppressed: Bool = false,
        seedSampleData: Bool = false,
        documentationObserver: DocumentationObservationCoordinator? = nil,
        deliveryEvidenceBookmarkStore: any ProjectBookmarkStoring = ProjectBookmarkStore(),
        evidencePreviewLoader: (@Sendable (DeliveryStore, ProjectID, EvidenceID) async -> EvidencePreview)? = nil,
        repositoryPlanSourceLoader: @escaping @Sendable (
            DeliveryStore,
            FolderProjectOnboarding,
            ProjectID
        ) async throws -> RepositoryPlanSourceInventory = { store, onboarding, projectID in
            try await onboarding.withAuthorizedProject(projectID: projectID) { project in
                try await RepositoryPlanSourceSelection.availableSources(
                    from: store,
                    project: project
                )
            }
        },
        repositoryPlanPreparationService: (any RepositoryPlanPreparationServicing)? = nil,
        repositoryPlanPreviewer: (@Sendable (
            RepositoryPlanReconstructionSourceSnapshot,
            RepositoryPlanProjection,
            [RepositoryPlanReconstructionCorrection],
            [RepositoryPlanReconstructionMappingSelection]
        ) async throws -> RepositoryPlanReconstructionPreview)? = nil,
        repositoryPlanOwnerCommandDispatch: (@Sendable (
            ProjectID,
            ProjectRegistration,
            UUID,
            AgentCommand
        ) async -> AgentCommandResult)? = nil,
        deliveryGoalDraftOwnerCommandDispatch: (@Sendable (
            ProjectID,
            ProjectRegistration,
            UUID,
            AgentCommand
        ) async -> AgentCommandResult)? = nil,
        repositoryPlanReadbackLoader: @escaping @Sendable (
            DeliveryStore,
            ProjectID,
            PlanChangeProposalID?
        ) async throws -> [RepositoryPlanReconstructionReadback] = {
            try await RepositoryPlanReconstructionQuery.load(
                from: $0,
                projectID: $1,
                proposalID: $2
            )
        },
        repositoryPlanApplyReconciler: (@Sendable (
            RepositoryPlanReconstructionApplicationAttemptRecord
        ) async throws -> RepositoryPlanReconstructionApplicationAttemptRecord)? = nil,
        repositoryPlanApplyReplayer: (@Sendable (
            RepositoryPlanReconstructionApplicationAttemptRecord
        ) async -> AgentCommandResult)? = nil
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
        self.permanentPurgeExecutionRoot = permanentPurgeExecutionRoot
        self.workspaceSearchLoader = workspaceSearchLoader
        self.reviewInboxLoader = reviewInboxLoader
        self.dashboardLoader = if let dashboardLoader {
            { store, _ in try await dashboardLoader(store) }
        } else {
            { store, evidence in
                try await DashboardProjection.load(from: store, evidenceReadbacks: evidence)
            }
        }
        self.dependencyGraphLoader = dependencyGraphLoader
        self.dependencyGraphPresentationPersistence = dependencyGraphPresentationPersistence
        self.documentationObserver = documentationObserver
            ?? Self.makeDocumentationObserver(
                onboarding: resolvedOnboarding,
                pluginCoordinator: codexPluginCoordinator,
                shippedCapability: codexPluginShippedCapability
            )
        self.deliveryEvidenceBookmarkStore = deliveryEvidenceBookmarkStore
        self.evidencePreviewLoader = evidencePreviewLoader ?? { store, projectID, evidenceID in
            await store.previewEvidence(projectID: projectID, evidenceID: evidenceID)
        }
        self.requestIDGenerator = requestIDGenerator
        self.repositoryPlanSourceLoader = repositoryPlanSourceLoader
        self.repositoryPlanPreparationService = repositoryPlanPreparationService
            ?? RepositoryPlanPreparationService(
                store: store,
                onboarding: resolvedOnboarding,
                plugin: codexPluginCoordinator
            )
        self.repositoryPlanPreviewer = repositoryPlanPreviewer ?? { source, projection, corrections, mappings in
            try await RepositoryPlanReconstructionPreviewQuery.preview(
                source: source,
                reviewedProjection: projection,
                corrections: corrections,
                explicitMappings: mappings,
                from: store
            )
        }
        self.repositoryPlanOwnerCommandDispatch = repositoryPlanOwnerCommandDispatch
            ?? { projectID, registration, requestID, command in
                do {
                    return try await resolvedOnboarding.withAuthorizedProject(projectID: projectID) { project in
                        let dispatcher = AgentCommandDispatcher(
                            store: store,
                            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                        )
                        let envelope = AgentCommandEnvelope(
                            version: AgentCommandDispatcher.commandEnvelopeVersion,
                            requestID: requestID,
                            projectRoot: project.canonicalRoot.path,
                            expectedRegistration: registration,
                            reason: "Owner reviewed repository plan reconstruction",
                            command: command
                        )
                        if case .applyPlanChangeProposal = command {
                            return await dispatcher.dispatchReconstructionApply(
                                envelope,
                                origin: .ownerApp
                            )
                        }
                        return await dispatcher.dispatch(envelope, origin: .ownerApp)
                    }
                } catch {
                    return .init(
                        entityIDs: [],
                        auditEventID: nil,
                        error: .unauthorizedProjectRoot
                    )
                }
            }
        self.deliveryGoalDraftOwnerCommandDispatch = deliveryGoalDraftOwnerCommandDispatch
            ?? { projectID, registration, requestID, command in
                do {
                    return try await resolvedOnboarding.withAuthorizedProject(projectID: projectID) { project in
                        guard project.registration == registration else {
                            return .init(entityIDs: [], auditEventID: nil, error: .staleProjectRegistration)
                        }
                        return await AgentCommandDispatcher(
                            store: store,
                            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                        ).dispatch(
                            .init(
                                version: AgentCommandDispatcher.commandEnvelopeVersion,
                                requestID: requestID,
                                projectRoot: project.canonicalRoot.path,
                                expectedRegistration: registration,
                                reason: "Owner saved Delivery Goal draft",
                                command: command
                            ),
                            origin: .ownerApp
                        )
                    }
                } catch {
                    return .init(entityIDs: [], auditEventID: nil, error: .unauthorizedProjectRoot)
                }
            }
        self.repositoryPlanReadbackLoader = repositoryPlanReadbackLoader
        self.repositoryPlanApplyReconciler = repositoryPlanApplyReconciler
            ?? { attempt in
                try await resolvedOnboarding.withAuthorizedProject(projectID: attempt.projectID) { project in
                    guard project.registration == attempt.registration else {
                        throw RepositoryPlanReconstructionError.applicationAttemptConflict
                    }
                    return try await AgentCommandDispatcher(
                        store: store,
                        projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                    ).reconcileReconstructionApply(
                        projectID: attempt.projectID,
                        proposalID: attempt.proposalID,
                        version: attempt.version,
                        applicationID: attempt.applicationID,
                        requestID: attempt.requestID
                    )
                }
            }
        self.repositoryPlanApplyReplayer = repositoryPlanApplyReplayer
            ?? { attempt in
                guard let envelope = try? JSONDecoder().decode(
                    AgentCommandEnvelope.self,
                    from: attempt.envelopeBytes
                ), envelope.requestID == attempt.requestID,
                   envelope.expectedRegistration == attempt.registration,
                   case let .applyPlanChangeProposal(
                       proposalID,
                       version,
                       _,
                       _,
                       applicationID
                   ) = envelope.command,
                   proposalID == attempt.proposalID.rawValue,
                   version == attempt.version,
                   applicationID == attempt.applicationID else {
                    return .init(
                        entityIDs: [attempt.proposalID.rawValue],
                        auditEventID: nil,
                        error: .repositoryPlanReconstructionApplicationAttemptConflict
                    )
                }
                do {
                    return try await resolvedOnboarding.withAuthorizedProject(
                        projectID: attempt.projectID
                    ) { project in
                        guard project.registration == attempt.registration,
                              project.canonicalRoot.path == envelope.projectRoot else {
                            return .init(
                                entityIDs: [attempt.proposalID.rawValue],
                                auditEventID: nil,
                                error: .repositoryPlanReconstructionApplicationAttemptConflict
                            )
                        }
                        return await AgentCommandDispatcher(
                            store: store,
                            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
                        ).dispatchReconstructionApply(envelope, origin: .ownerApp)
                    }
                } catch {
                    return .init(
                        entityIDs: [attempt.proposalID.rawValue],
                        auditEventID: nil,
                        error: .unauthorizedProjectRoot
                    )
                }
            }
        self.recoveryServices = recoveryServices
        self.connectorHealthLoader = connectorHealthLoader
        self.recoveryStartupError = recoveryStartupError
        self.recoveryResumedAtLaunch = recoveryResumedAtLaunch
        self.notificationCoordinator = notificationCoordinator
            ?? AppNotificationCoordinator(
                store: store,
                dispatcher: PushoverNotificationDispatcher(store: store, credentials: resolvedKeychain)
            )
        recoveryServices?.observeAgentBridgeHealth { [weak self] snapshot in
            self?.applyConnectorHealthSnapshot(snapshot)
        }
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
        connectorHealthLoader: (() async throws -> AgentBridgeHealthSnapshot)? = nil,
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
            connectorHealthLoader: connectorHealthLoader,
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
        navigationFailureMessage = nil
        let previousProjectID = selection.projectID ?? selectedProjectID
        navigationGeneration &+= 1
        let generation = navigationGeneration
        let resolvedRoute = resolvedRouteForNavigation(route)
        navigationRecoveryMessage = resolvedRoute == route ? nil : "The requested destination changed with the project lifecycle. Its current location is shown."

        if let destinationProjectID = resolvedRoute.projectID,
           destinationProjectID != previousProjectID {
            selectedTicketID = TicketID(rawValue: "")
        }
        selection = resolvedRoute
        if resolvedRoute == .goals, let goalID = reconcileWorkspaceGoalsSelection() {
            navigationFocus = .workspaceGoal(goalID)
        } else if resolvedRoute == .goals {
            navigationFocus = .workspaceGoalsFilter
        } else if resolvedRoute == .search {
            navigationFocus = .workspaceSearchField
        } else {
            navigationFocus = .route(resolvedRoute)
        }
        navigationHistory.navigate(to: historyEntry(for: resolvedRoute, focus: navigationFocus))
        lastCommittedNavigationGeneration = generation

        if let projectID = resolvedRoute.projectID,
           dashboard?.projects.contains(where: { $0.id == projectID }) == true {
            documentationObserver.invalidate(projectID: projectID)
            do {
                try await MeaningfulDeliveryEventRecorder(store: store).markDashboardOpened(projectID: projectID)
            } catch {
                guard generation == navigationGeneration else { return }
                navigationFailureMessage = error.localizedDescription
            }
            guard generation == navigationGeneration else { return }
        }
        if let projectID = resolvedRoute.projectID {
            _ = await refreshDocumentationObservation(projectID: projectID, withdrawCurrent: true)
            guard generation == navigationGeneration else { return }
        }
    }

    func goBack() async { await restoreNavigation(step: .back) }
    func goForward() async { await restoreNavigation(step: .forward) }

    private enum NavigationStep { case back, forward }

    private func restoreNavigation(step: NavigationStep) async {
        captureCurrentNavigationContext()
        navigationFailureMessage = nil
        navigationGeneration &+= 1
        let moved = switch step {
        case .back: navigationHistory.goBack()
        case .forward: navigationHistory.goForward()
        }
        guard moved else { return }
        let entry = navigationHistory.current
        navigationRecoveryMessage = nil
        restore(entry)
        if entry.route == .search {
            await runWorkspaceSearch(persist: false, captureNavigation: false)
            if let selected = entry.workspaceSearch?.selectedResultID,
               workspaceSearchProjection?.results.contains(where: { $0.id == selected }) == true {
                selectedWorkspaceSearchResultID = selected
                navigationFocus = .workspaceSearchResult(selected)
                navigationRecoveryMessage = nil
            }
        }
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
        let historyFilter = projectID.flatMap { projectID in
            if case .activity = route { historyFilters[Data(projectID.rawValue.utf8)] ?? .all } else { nil }
        }
        let selectedHistoryEventID = projectID.flatMap { projectID in
            if case .activity = route { selectedHistoryEventIDs[Data(projectID.rawValue.utf8)] } else { nil }
        }
        let historyViewportOffset = projectID.flatMap { projectID in
            if case .activity = route { historyViewportOffsets[Data(projectID.rawValue.utf8)] } else { nil }
        }
        let workspaceGoals = route == .goals ? workspaceGoalsNavigationState : nil
        let workspaceSearch = route == .search ? workspaceSearchNavigationState : nil
        let selectedNavigationTicketID: TicketID? = navigationTicketID(for: route, projectID: projectID)
        navigationHistory.updateCurrent(
            registration: registration(for: route),
            phaseID: phaseID,
            showsAllPhases: showsAllPhases,
            filter: filter,
            selectedTicketID: selectedNavigationTicketID,
            historyFilter: historyFilter,
            selectedHistoryEventID: selectedHistoryEventID,
            historyViewportOffset: historyViewportOffset,
            workspaceGoals: workspaceGoals,
            workspaceSearch: workspaceSearch,
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
        let historyFilter = projectID.flatMap { projectID in
            if case .activity = route { historyFilters[Data(projectID.rawValue.utf8)] ?? .all } else { nil }
        }
        let selectedHistoryEventID = projectID.flatMap { projectID in
            if case .activity = route { selectedHistoryEventIDs[Data(projectID.rawValue.utf8)] } else { nil }
        }
        let historyViewportOffset = projectID.flatMap { projectID in
            if case .activity = route { historyViewportOffsets[Data(projectID.rawValue.utf8)] } else { nil }
        }
        let workspaceGoals = route == .goals ? workspaceGoalsNavigationState : nil
        let workspaceSearch = route == .search ? workspaceSearchNavigationState : nil
        let selectedNavigationTicketID: TicketID? = navigationTicketID(for: route, projectID: projectID)
        return .init(
            route: route,
            registration: registration(for: route),
            phaseID: phaseID,
            showsAllPhases: showsAllPhases,
            filter: filter,
            selectedTicketID: selectedNavigationTicketID,
            historyFilter: historyFilter,
            selectedHistoryEventID: selectedHistoryEventID,
            historyViewportOffset: historyViewportOffset,
            workspaceGoals: workspaceGoals,
            workspaceSearch: workspaceSearch,
            focus: focus
        )
    }

    private func navigationTicketID(for route: AppRoute, projectID: ProjectID?) -> TicketID? {
        if case .activity = route { return nil }
        if case .dependencies = route, let key = dependencySessionKey(for: route) {
            return dependencyFocusIDs[key]
        }
        return projectID == nil || selectedTicketID.rawValue.isEmpty ? nil : selectedTicketID
    }

    private func registration(for route: AppRoute) -> ProjectRegistration? {
        if case let .removedProject(removalID) = route {
            return dashboard?.removedProjects.first(where: { $0.id == removalID })?.registration
        }
        let projectID = switch route {
        case .goals:
            workspaceGoalsProjectID ?? workspaceGoalsSelectedProjectID
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

    private func dependencySessionKey(for route: AppRoute) -> DependencySessionKey? {
        guard let projectID = route.projectID,
              let project = dashboard?.projects.first(where: { $0.id == projectID }) else {
            return nil
        }
        return DependencySessionKey(projectID: projectID, registration: project.registration)
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
        if case .goals = route, let goalsState = entry.workspaceGoals {
            workspaceGoalsDomain = goalsState.domain
            workspaceGoalsProjectID = goalsState.projectID
            workspaceGoalsDeliveryLifecycle = goalsState.deliveryLifecycle
            workspaceGoalsExecutionStatus = goalsState.executionStatus
            workspaceGoalsExecutionScope = goalsState.executionScope
            workspaceGoalsViewportOffset = goalsState.viewportOffset.map { max(0, $0) }

            if let selected = goalsState.selectedDeliveryID,
               filteredWorkspaceDeliveryGoals().contains(where: { $0.id == selected }) {
                selectedWorkspaceDeliveryGoalID = selected
            } else {
                selectedWorkspaceDeliveryGoalID = nil
                if goalsState.selectedDeliveryID != nil {
                    recovery.append("The exact Delivery Goal is unavailable; no replacement goal was selected.")
                }
            }
            if let selected = goalsState.selectedExecutionID,
               filteredWorkspaceExecutionGoals().contains(where: { $0.id == selected }) {
                selectedWorkspaceExecutionGoalID = selected
            } else {
                selectedWorkspaceExecutionGoalID = nil
                if goalsState.selectedExecutionID != nil {
                    recovery.append("The exact Execution Goal observation is unavailable; no replacement observation was selected.")
                }
            }
        }
        if case .search = route, let searchState = entry.workspaceSearch {
            invalidateWorkspaceSearchRun()
            workspaceSearchDefinition = searchState.definition
            workspaceSearchDraft = searchState.definition.text
            workspaceSearchViewportOffset = searchState.viewportOffset.map { max(0, $0) }
            workspaceSearchPreferenceIsUnsupported = searchState.preferenceIsUnsupported
            workspaceSearchNeedsScopeReselection = searchState.needsScopeReselection
            if let selected = searchState.selectedResultID,
               workspaceSearchProjection?.results.contains(where: { $0.id == selected }) == true {
                selectedWorkspaceSearchResultID = selected
            } else {
                selectedWorkspaceSearchResultID = nil
                if searchState.selectedResultID != nil {
                    recovery.append("The exact Search result is unavailable; no replacement result was selected.")
                }
            }
        }
        if case let .activity(projectID) = route {
            let key = Data(projectID.rawValue.utf8)
            historyFilters[key] = entry.historyFilter ?? .all
            if let eventID = entry.selectedHistoryEventID,
               projectActivities[projectID]?.items.contains(where: { $0.identity == eventID }) == true {
                selectedHistoryEventIDs[key] = eventID
            } else {
                selectedHistoryEventIDs.removeValue(forKey: key)
                if entry.selectedHistoryEventID != nil {
                    recovery.append("The exact History event is unavailable; no replacement event was selected.")
                }
            }
            if let viewportOffset = entry.historyViewportOffset {
                historyViewportOffsets[key] = max(0, viewportOffset)
            } else {
                historyViewportOffsets.removeValue(forKey: key)
            }
        }
        if let projectID = restoredProjectID,
           case .phaseBoard = route,
           entry.showsAllPhases,
           case let .execution(identity) = entry.filter ?? .all,
           dashboard?.allPhaseBoard(for: projectID)?.hasExactExecutionGoalLink(identity) != true {
            recovery.append("The exact Execution Goal link is unavailable or was replaced; its ticket was not substituted.")
        }
        let ticketIsAvailable = entry.selectedTicketID.map { ticketID in
            guard let projectID = restoredProjectID else { return false }
            if case .dependencies = route {
                return dependencyGraphs[projectID]?.node(id: ticketID) != nil
                    || dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil
            }
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
        if case let .dependencies(projectID) = route {
            if let key = dependencySessionKey(for: .dependencies(projectID)) {
                if ticketIsAvailable, let ticketID = entry.selectedTicketID {
                    dependencyFocusIDs[key] = ticketID
                } else {
                    dependencyFocusIDs.removeValue(forKey: key)
                }
            }
        }
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
        if case let .historyEvent(eventID)? = entry.focus {
            focusIsAvailable = restoredProjectID.map { projectID in
                projectActivities[projectID]?.items.contains(where: { $0.identity == eventID }) == true
            } ?? false
            if !focusIsAvailable, entry.selectedHistoryEventID == nil {
                recovery.append("The exact History event focus is unavailable; no replacement event was selected.")
            }
        }
        if case let .historyDetail(eventID)? = entry.focus {
            focusIsAvailable = restoredProjectID.map { projectID in
                projectActivities[projectID]?.items.contains(where: { $0.identity == eventID }) == true
            } ?? false
            if !focusIsAvailable {
                recovery.append("The exact History detail focus is unavailable; no replacement event was selected.")
            }
        }
        if case let .workspaceGoal(goalID)? = entry.focus {
            focusIsAvailable = switch workspaceGoalsDomain {
            case .delivery:
                filteredWorkspaceDeliveryGoals().contains(where: { $0.id == goalID })
            case .execution:
                filteredWorkspaceExecutionGoals().contains(where: { $0.id == goalID })
            }
            if !focusIsAvailable,
               !recovery.contains(where: { $0.contains("exact Delivery Goal") || $0.contains("exact Execution Goal") }) {
                recovery.append("The exact Goals focus is unavailable; no replacement goal was selected.")
            }
        }
        if case let .workspaceSearchResult(resultID)? = entry.focus {
            focusIsAvailable = workspaceSearchProjection?.results.contains(where: { $0.id == resultID }) == true
            if !focusIsAvailable, entry.workspaceSearch?.selectedResultID == nil {
                recovery.append("The exact Search result focus is unavailable; no replacement result was selected.")
            }
        }
        navigationFocus = if !recovery.isEmpty, route != entry.route {
            .recovery
        } else if focusIsAvailable && (ticketIsAvailable || entry.selectedTicketID == nil) {
            entry.focus
        } else {
            recovery.isEmpty ? entry.focus : .recovery
        }
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
            case let .reconstructRepositoryPlan(payload):
                payload.comparisons.contains { comparison in
                    guard comparison.kind == .ticket else { return false }
                    let destinationID = comparison.destinationID
                        ?? (comparison.disposition == .new
                            ? RepositoryPlanReconstructionIdentity.destinationID(
                                source: payload.source,
                                subject: comparison.subject
                            )
                            : nil)
                    return destinationID == ticketID.rawValue
                }
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

    func previewPermanentProjectPurge(removalID: ProjectRemovalID) async throws -> ProjectPermanentPurgePreview {
        let executionStore = try ProjectExecutionFileStore(
            root: permanentPurgeExecutionRoot(),
            create: true
        )
        return try await ProjectPermanentPurgeManager(store: store, executionStore: executionStore)
            .preview(removalID: removalID)
    }

    func applyPermanentProjectPurge(_ preview: ProjectPermanentPurgePreview) async throws {
        let executionStore = try ProjectExecutionFileStore(
            root: permanentPurgeExecutionRoot(),
            create: true
        )
        _ = try await ProjectPermanentPurgeManager(store: store, executionStore: executionStore)
            .apply(preview)
        // Withdraw committed data synchronously before any refresh can suspend.
        // Earlier reads must not republish the identity after this boundary.
        projectionReloadGeneration &+= 1
        navigationGeneration &+= 1
        invalidateWorkspaceSearchRun(clearProjection: false)
        let registration = ProjectRegistration(
            projectID: preview.projectID,
            registrationID: preview.registrationID,
            requestGeneration: preview.requestGeneration
        )
        removedActivities[preview.removalID] = nil
        if let current = dashboard {
            dashboard = DashboardProjection(
                projects: current.projects,
                archivedProjects: current.archivedProjects,
                removedProjects: current.removedProjects.filter { $0.id != preview.removalID },
                boards: current.boards,
                projectPlans: current.projectPlans,
                allPhaseBoards: current.allPhaseBoards,
                ticketOrderingContexts: current.ticketOrderingContexts,
                ticketOrderingFailures: current.ticketOrderingFailures,
                workspaceGoals: current.workspaceGoals
            )
        }
        workspaceSearchDefinition = workspaceSearchDefinition.removing(registration)
        if let projection = workspaceSearchProjection {
            let results = projection.results.filter {
                !registrationIdentity(
                    .init(projectID: $0.project.projectID, registrationID: $0.project.registrationID),
                    matches: .init(projectID: preview.projectID, registrationID: preview.registrationID)
                )
            }
            workspaceSearchProjection = .init(
                definition: projection.definition.removing(registration),
                results: results,
                omissions: projection.omissions
            )
            if let selectedWorkspaceSearchResultID,
               !results.contains(where: { $0.id == selectedWorkspaceSearchResultID }) {
                self.selectedWorkspaceSearchResultID = nil
            }
        }
        workspaceSearchSavedQueries = workspaceSearchSavedQueries.map { record in
            guard case var .supported(query) = record else { return record }
            query.definition = query.definition.removing(registration)
            return .supported(query)
        }
        navigationHistory.removePurgedRegistration(registration, removalID: preview.removalID)
        navigationFocus = .recovery
        permanentPurgeNeedsRefresh = true
        try await refreshAfterPermanentProjectPurge()
    }

    func reloadAfterPermanentProjectPurge() async {
        do {
            try await refreshAfterPermanentProjectPurge()
        } catch {
            dashboardError = error.localizedDescription
        }
    }

    private func refreshAfterPermanentProjectPurge() async throws {
        let dashboardOutcome = await reloadProjectProjections()
        let dashboardGeneration = projectionReloadGeneration
        let searchRefreshed = await loadWorkspaceSearchPreferences(runSearch: true)
        guard dashboardOutcome == .published,
              dashboardGeneration == projectionReloadGeneration,
              searchRefreshed else {
            permanentPurgeNeedsRefresh = true
            dashboardError = PermanentProjectPurgeRefreshError.committedNeedsRefresh.localizedDescription
            throw PermanentProjectPurgeRefreshError.committedNeedsRefresh
        }
        permanentPurgeNeedsRefresh = false
        selectedProjectID = nil
        selection = .projects
        navigationFocus = .route(.projects)
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
            await self.loadWorkspaceSearchPreferences(runSearch: false)
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
        invalidateWorkspaceSearchRun()
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
        if let recoveryServices { try await recoveryServices.adoptRecoveredStore(result.store) }
        store = result.store
        recoveryStartupError = nil
        recoveryResumedAtLaunch = false
        if let recoveryServices {
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
        await loadWorkspaceSearchPreferences(runSearch: false)
        if !externalServicesSuppressed {
            await notificationCoordinator.initializeForLaunch()
            try await recoveryServices?.startSharedAgentBridge()
        }
    }

    private func clearEphemeralViewState() {
        invalidateWorkspaceSearchRun()
        permanentPurgeNeedsRefresh = false
        workspaceGoalsDomain = .delivery
        workspaceGoalsProjectID = nil
        workspaceGoalsDeliveryLifecycle = nil
        workspaceGoalsExecutionStatus = nil
        workspaceGoalsExecutionScope = .all
        selectedWorkspaceDeliveryGoalID = nil
        selectedWorkspaceExecutionGoalID = nil
        workspaceGoalsViewportOffset = nil
        workspaceSearchDefinition = .init()
        workspaceSearchDraft = ""
        workspaceSearchProjection = nil
        workspaceSearchSavedQueries = []
        workspaceSearchIsLoading = false
        workspaceSearchFailure = nil
        workspaceSearchPreferenceIsUnsupported = false
        workspaceSearchNeedsScopeReselection = false
        selectedWorkspaceSearchResultID = nil
        workspaceSearchViewportOffset = nil
        workspaceSearchPersistenceMessage = nil
        viewedPhaseIDs.removeAll()
        allPhaseBoardProjectIDs.removeAll()
        boardFilters.removeAll()
        allPhaseBoardFilters.removeAll()
        historyFilters.removeAll()
        selectedHistoryEventIDs.removeAll()
        historyViewportOffsets.removeAll()
        navigationHistory.reset()
        navigationRecoveryMessage = nil
        navigationFocus = .route(.projects)
        selectedTicketID = TicketID(rawValue: "")
        dependencyFocusIDs.removeAll()
        dependencyPresentationOrders.removeAll()
        dependencyPresentationStatuses.removeAll()
        loadedDependencyPresentations.removeAll()
        dependencyPresentationOperationGenerations.removeAll()
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
        repositoryPlanReconstructions.removeAll()
        repositoryPlanReconstructionGenerations.removeAll()
        repositoryPlanPreparationOperationGenerations.removeAll()
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

    func reloadAfterOnboarding(projectID: ProjectID) async {
        await loadDashboard()
        guard dashboard?.projects.contains(where: { $0.id == projectID }) == true else {
            selection = .projects
            return
        }
        await navigate(to: .projectPlan(projectID))
    }

    func repositoryPlanReconstruction(
        for projectID: ProjectID
    ) -> RepositoryPlanReconstructionPresentation? {
        repositoryPlanReconstructions[projectID]
    }

    func openRepositoryPlanReconstruction(projectID: ProjectID) async {
        if let existing = repositoryPlanReconstructions[projectID] {
            if existing.stage == .reviewLoadFailed {
                await retryRepositoryPlanReview(projectID: projectID)
                return
            }
            guard existing.stage == .failed else { return }
            if let state = existing.preparation?.state,
               ![.failed, .cancelled].contains(state) {
                return
            }
        }
        let persistedReadbacks: [RepositoryPlanReconstructionReadback]
        do {
            persistedReadbacks = try await repositoryPlanReadbackLoader(store, projectID, nil)
        } catch {
            repositoryPlanReconstructions[projectID] = .failed(
                projectID: projectID,
                message: "Saved repository-plan state is unavailable: \(error.localizedDescription). Retry before starting a new preparation."
            )
            return
        }
        let recoveredPreparation: RepositoryPlanPreparationReadback?
        do {
            recoveredPreparation = try await repositoryPlanPreparationService.recover(
                projectID: projectID
            ).last
        } catch {
            repositoryPlanReconstructions[projectID] = .failed(
                projectID: projectID,
                message: "Saved repository-plan preparation is unavailable: \(error.localizedDescription). Retry before starting a replacement."
            )
            return
        }
        if let recoveredPreparation,
           [.queued, .running, .awaitingResolution, .outcomeUnknown]
            .contains(recoveredPreparation.state) {
            var presentation = RepositoryPlanReconstructionPresentation.loading(
                projectID: projectID
            )
            presentation.proposalID = recoveredPreparation.identity.proposalID
            presentation.preparation = recoveredPreparation
            presentation.apply(recoveredPreparation)
            repositoryPlanReconstructions[projectID] = presentation
            return
        }
        let latestPersisted = persistedReadbacks.max(by: { lhs, rhs in
            if lhs.version.createdAt != rhs.version.createdAt {
                return lhs.version.createdAt < rhs.version.createdAt
            }
            return lhs.version.version < rhs.version.version
        })
        if let recoveredPreparation,
           recoveredPreparation.state == .readyForReview {
            if let latestPersisted,
               latestPersisted.proposalID == recoveredPreparation.identity.proposalID,
               latestPersisted.payload.source.registration
                == recoveredPreparation.identity.registration,
               latestPersisted.payload.source.rootID == recoveredPreparation.identity.rootID,
               recoveredPreparation.draftBytes
                == latestPersisted.payload.source.projectionBytes,
               let persisted = try? await repositoryPlanPersistedPresentation(
                   from: latestPersisted
               ) {
                repositoryPlanReconstructions[projectID] = persisted
                return
            }
            var presentation = RepositoryPlanReconstructionPresentation.loading(
                projectID: projectID
            )
            presentation.proposalID = recoveredPreparation.identity.proposalID
            presentation.preparation = recoveredPreparation
            do {
                presentation = try await repositoryPlanReviewPresentation(
                    applying: recoveredPreparation,
                    to: presentation
                )
            } catch {
                presentation.stage = .reviewLoadFailed
                presentation.message = "The prepared draft is safe, but its review could not be loaded: \(error.localizedDescription). Retry the review without preparing again."
                repositoryPlanReconstructions[projectID] = presentation
                return
            }
            repositoryPlanReconstructions[projectID] = presentation
            return
        }
        if let latestPersisted {
            do {
                repositoryPlanReconstructions[projectID] = try await repositoryPlanPersistedPresentation(
                    from: latestPersisted
                )
                return
            } catch {
                repositoryPlanReconstructions[projectID] = .failed(
                    projectID: projectID,
                    message: "Saved repository-plan state could not be restored: \(error.localizedDescription). No saved decision or Apply attempt was changed."
                )
                return
            }
        }
        if let recoveredPreparation {
            var presentation = RepositoryPlanReconstructionPresentation.loading(
                projectID: projectID
            )
            presentation.proposalID = recoveredPreparation.identity.proposalID
            presentation.preparation = recoveredPreparation
            if recoveredPreparation.state == .readyForReview {
                do {
                    presentation = try await repositoryPlanReviewPresentation(
                        applying: recoveredPreparation,
                        to: presentation
                    )
                } catch {
                    presentation.stage = .reviewLoadFailed
                    presentation.message = "The prepared draft is safe, but its review could not be loaded: \(error.localizedDescription). Retry the review without preparing again."
                }
            } else {
                presentation.apply(recoveredPreparation)
            }
            repositoryPlanReconstructions[projectID] = presentation
            return
        }
        let generation = (repositoryPlanReconstructionGenerations[projectID] ?? 0) &+ 1
        repositoryPlanReconstructionGenerations[projectID] = generation
        repositoryPlanReconstructions[projectID] = .loading(projectID: projectID)
        do {
            async let inventory = repositoryPlanSourceLoader(store, projectOnboarding, projectID)
            async let target = repositoryPlanPreparationService.target()
            let loadedInventory = try await inventory
            let loadedTarget = try await target
            guard repositoryPlanReconstructionGenerations[projectID] == generation else { return }
            repositoryPlanReconstructions[projectID] = .selecting(
                projectID: projectID,
                inventory: loadedInventory,
                target: loadedTarget
            )
        } catch {
            guard repositoryPlanReconstructionGenerations[projectID] == generation else { return }
            repositoryPlanReconstructions[projectID] = .failed(
                projectID: projectID,
                message: error.localizedDescription
            )
        }
    }

    func setRepositoryPlanSourceSelected(
        projectID: ProjectID,
        artifactID: String,
        selected: Bool
    ) {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .selectingSources,
              presentation.sources.contains(where: { $0.artifactID == artifactID }) else {
            return
        }
        if selected {
            presentation.selectedArtifactIDs.insert(artifactID)
        } else {
            presentation.selectedArtifactIDs.remove(artifactID)
        }
        repositoryPlanReconstructions[projectID] = presentation
    }

    func startRepositoryPlanPreparation(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              let inventory = presentation.inventory,
              let target = presentation.target,
              !presentation.selectedArtifactIDs.isEmpty,
              Self.canStartRepositoryPlanPreparation(from: presentation.stage) else {
            return
        }
        let selectedSources = inventory.sources.filter {
            presentation.selectedArtifactIDs.contains($0.artifactID)
        }.sorted {
            Data($0.artifactID.utf8).lexicographicallyPrecedes(Data($1.artifactID.utf8))
        }
        guard selectedSources.count == presentation.selectedArtifactIDs.count else { return }
        let operationGeneration = nextRepositoryPlanPreparationOperationGeneration(projectID)
        presentation.stage = .starting
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        do {
            let readback = try await repositoryPlanPreparationService.start(
                consent: .init(
                    inventory: inventory,
                    selectedSources: selectedSources,
                    target: target
                )
            )
            guard readback.identity.registration.projectID == projectID else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            if readback.state == .readyForReview {
                presentation.preparation = readback
                presentation.proposalID = readback.identity.proposalID
            }
            presentation = try await repositoryPlanReviewPresentation(
                applying: readback,
                to: presentation
            )
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.stage == .starting else { return }
            repositoryPlanReconstructions[projectID] = presentation
        } catch {
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration else {
                return
            }
            if presentation.preparation?.state == .readyForReview {
                presentation.stage = .reviewLoadFailed
                presentation.review = nil
                presentation.message = "The prepared draft is safe, but its review could not be loaded: \(error.localizedDescription). Retry the review without preparing again."
                repositoryPlanReconstructions[projectID] = presentation
                return
            }
            if let preparation = error as? RepositoryPlanPreparationError,
               preparation.code == .sourceChanged {
                await reloadRepositoryPlanSourceDisclosure(
                    projectID: projectID,
                    target: target,
                    message: preparation.localizedDescription,
                    operationGeneration: operationGeneration
                )
                return
            }
            presentation.stage = .failed
            presentation.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = presentation
        }
    }

    func refreshRepositoryPlanPreparation(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              let identity = presentation.preparation?.identity else {
            return
        }
        let operationGeneration = nextRepositoryPlanPreparationOperationGeneration(projectID)
        do {
            let readback = try await repositoryPlanPreparationService.status(identity: identity)
            guard readback.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            if readback.state == .readyForReview {
                presentation.preparation = readback
                presentation.proposalID = readback.identity.proposalID
            }
            presentation = try await repositoryPlanReviewPresentation(
                applying: readback,
                to: presentation
            )
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == identity else {
                return
            }
        } catch {
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == identity else {
                return
            }
            if presentation.preparation?.state == .readyForReview {
                presentation.stage = .reviewLoadFailed
                presentation.review = nil
                presentation.message = "The prepared draft is safe, but its review could not be loaded: \(error.localizedDescription). Retry the review without preparing again."
            } else {
                presentation.stage = .outcomeUnknown
                presentation.message = error.localizedDescription
            }
        }
        repositoryPlanReconstructions[projectID] = presentation
    }

    func cancelRepositoryPlanPreparation(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              let identity = presentation.preparation?.identity,
              case let .preparing(state) = presentation.stage,
              [.queued, .running, .awaitingResolution].contains(state) else {
            return
        }
        let operationGeneration = nextRepositoryPlanPreparationOperationGeneration(projectID)
        do {
            let readback = try await repositoryPlanPreparationService.cancel(identity: identity)
            guard readback.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            if readback.state == .readyForReview {
                presentation.preparation = readback
                presentation.proposalID = readback.identity.proposalID
            }
            presentation = try await repositoryPlanReviewPresentation(
                applying: readback,
                to: presentation
            )
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == identity else {
                return
            }
        } catch {
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == identity else {
                return
            }
            if presentation.preparation?.state == .readyForReview {
                presentation.stage = .reviewLoadFailed
                presentation.review = nil
                presentation.message = "The prepared draft is safe, but its review could not be loaded: \(error.localizedDescription). Retry the review without preparing again."
            } else {
                presentation.stage = .outcomeUnknown
                presentation.message = error.localizedDescription
            }
        }
        repositoryPlanReconstructions[projectID] = presentation
    }

    func reconcileRepositoryPlanPreparation(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .outcomeUnknown,
              let identity = presentation.preparation?.identity else {
            return
        }
        let operationGeneration = nextRepositoryPlanPreparationOperationGeneration(projectID)
        do {
            let readback = try await repositoryPlanPreparationService.reconcile(identity: identity)
            guard readback.identity == identity else {
                throw RepositoryPlanPreparationError(code: .identityMismatch)
            }
            if readback.state == .readyForReview {
                presentation.preparation = readback
                presentation.proposalID = readback.identity.proposalID
            }
            presentation = try await repositoryPlanReviewPresentation(
                applying: readback,
                to: presentation
            )
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == identity else {
                return
            }
        } catch {
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == identity else {
                return
            }
            if presentation.preparation?.state == .readyForReview {
                presentation.stage = .reviewLoadFailed
                presentation.review = nil
                presentation.message = "The prepared draft is safe, but its review could not be loaded: \(error.localizedDescription). Retry the review without preparing again."
            } else {
                presentation.stage = .outcomeUnknown
                presentation.message = error.localizedDescription
            }
        }
        repositoryPlanReconstructions[projectID] = presentation
    }

    func retryRepositoryPlanReview(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewLoadFailed,
              let readback = presentation.preparation,
              readback.state == .readyForReview else { return }
        let operationGeneration = nextRepositoryPlanPreparationOperationGeneration(projectID)
        do {
            presentation = try await repositoryPlanReviewPresentation(
                applying: readback,
                to: presentation
            )
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == readback.identity else {
                return
            }
            repositoryPlanReconstructions[projectID] = presentation
        } catch {
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration,
                  repositoryPlanReconstructions[projectID]?.preparation?.identity == readback.identity else {
                return
            }
            presentation.stage = .reviewLoadFailed
            presentation.review = nil
            presentation.message = "The prepared draft is still safe, but its review could not be loaded: \(error.localizedDescription). Retry without preparing again."
            repositoryPlanReconstructions[projectID] = presentation
        }
    }

    func restartRepositoryPlanPreparation(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewLoadFailed,
              presentation.preparation?.state == .readyForReview else { return }
        let reconstructionGeneration = (repositoryPlanReconstructionGenerations[projectID] ?? 0) &+ 1
        repositoryPlanReconstructionGenerations[projectID] = reconstructionGeneration
        _ = nextRepositoryPlanPreparationOperationGeneration(projectID)
        presentation.stage = .loadingSources
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        do {
            async let inventory = repositoryPlanSourceLoader(store, projectOnboarding, projectID)
            async let target = repositoryPlanPreparationService.target()
            let loadedInventory = try await inventory
            let loadedTarget = try await target
            guard repositoryPlanReconstructionGenerations[projectID] == reconstructionGeneration else {
                return
            }
            repositoryPlanReconstructions[projectID] = .selecting(
                projectID: projectID,
                inventory: loadedInventory,
                target: loadedTarget
            )
        } catch {
            guard repositoryPlanReconstructionGenerations[projectID] == reconstructionGeneration else {
                return
            }
            presentation.stage = .reviewLoadFailed
            presentation.message = "The prepared draft remains safe, but fresh source disclosure could not be loaded: \(error.localizedDescription). Retry the existing review or restart preparation again."
            repositoryPlanReconstructions[projectID] = presentation
        }
    }

    func beginFreshRepositoryPlanPreparation(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .applied
                || (presentation.stage == .reviewing
                    && presentation.review?.savedReadback != nil
                    && presentation.review?.isSaving == false
                    && presentation.review?.isUpdating == false
                    && presentation.review?.isDeciding == false) else { return }
        let priorStage = presentation.stage
        let reconstructionGeneration = (repositoryPlanReconstructionGenerations[projectID] ?? 0) &+ 1
        repositoryPlanReconstructionGenerations[projectID] = reconstructionGeneration
        _ = nextRepositoryPlanPreparationOperationGeneration(projectID)
        presentation.stage = .loadingSources
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        do {
            async let inventory = repositoryPlanSourceLoader(store, projectOnboarding, projectID)
            async let target = repositoryPlanPreparationService.target()
            let loadedInventory = try await inventory
            let loadedTarget = try await target
            guard repositoryPlanReconstructionGenerations[projectID] == reconstructionGeneration else {
                return
            }
            repositoryPlanReconstructions[projectID] = .selecting(
                projectID: projectID,
                inventory: loadedInventory,
                target: loadedTarget
            )
        } catch {
            guard repositoryPlanReconstructionGenerations[projectID] == reconstructionGeneration else {
                return
            }
            presentation.stage = priorStage
            presentation.message = "The existing reviewed plan is unchanged, but fresh source disclosure could not be loaded: \(error.localizedDescription). Retry when the sources are available."
            repositoryPlanReconstructions[projectID] = presentation
        }
    }

    func setRepositoryPlanAuthorityConfirmed(
        projectID: ProjectID,
        confirmed: Bool
    ) {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review else { return }
        review.authorityConfirmed = confirmed
        presentation.review = review
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
    }

    func setRepositoryPlanCorrection(
        projectID: ProjectID,
        subject: RepositoryPlanReconstructionSubject,
        field: String,
        chosenValue: Data
    ) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review else { return }
        do {
            let sourceValue = try Self.repositoryPlanSourceValue(
                subject: subject,
                field: field,
                projection: review.originalProjection
            )
            let correction = RepositoryPlanReconstructionCorrection(
                subject: subject,
                field: field,
                sourceValue: sourceValue,
                chosenValue: chosenValue
            )
            review.corrections.removeAll {
                $0.subject == subject && Data($0.field.utf8) == Data(field.utf8)
            }
            review.corrections.append(correction)
            review.reviewedProjection = try RepositoryPlanReconstructionCorrections.apply(
                review.corrections,
                to: review.originalProjection
            )
            review.authorityConfirmed = false
            review.savedReadback = nil
            review.isDeciding = false
            review.revision &+= 1
            review.isUpdating = true
            let revision = review.revision
            presentation.review = review
            presentation.message = nil
            repositoryPlanReconstructions[projectID] = presentation
            let preview = try await repositoryPlanPreviewer(
                review.source,
                review.reviewedProjection,
                review.corrections,
                review.explicitMappings
            )
            guard var current = repositoryPlanReconstructions[projectID],
                  current.stage == .reviewing,
                  var currentReview = current.review,
                  currentReview.revision == revision,
                  currentReview.source == review.source else { return }
            Self.applyRepositoryPlanExclusions(
                currentReview.exclusions,
                preview: preview,
                to: &currentReview
            )
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = nil
            repositoryPlanReconstructions[projectID] = current
        } catch {
            guard var current = repositoryPlanReconstructions[projectID],
                  let currentReview = current.review,
                  currentReview.source == review.source,
                  currentReview.revision == review.revision else { return }
            current.review = currentReview
            current.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = current
        }
    }

    func setRepositoryPlanExclusion(
        projectID: ProjectID,
        subject: RepositoryPlanReconstructionSubject,
        reason: String
    ) async {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review else { return }
        do {
            review.exclusions.removeAll { $0.subject == subject }
            review.exclusions.append(.init(subject: subject, reason: trimmed))
            review.savedReadback = nil
            review.isDeciding = false
            review.revision &+= 1
            review.isUpdating = true
            let revision = review.revision
            presentation.review = review
            presentation.message = nil
            repositoryPlanReconstructions[projectID] = presentation
            let preview = try await repositoryPlanPreviewer(
                review.source,
                review.reviewedProjection,
                review.corrections,
                review.explicitMappings
            )
            guard var current = repositoryPlanReconstructions[projectID],
                  current.stage == .reviewing,
                  var currentReview = current.review,
                  currentReview.revision == revision,
                  currentReview.source == review.source else { return }
            Self.applyRepositoryPlanExclusions(
                currentReview.exclusions,
                preview: preview,
                to: &currentReview
            )
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = nil
            repositoryPlanReconstructions[projectID] = current
        } catch {
            guard var current = repositoryPlanReconstructions[projectID],
                  let currentReview = current.review,
                  currentReview.source == review.source,
                  currentReview.revision == review.revision else { return }
            current.review = currentReview
            current.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = current
        }
    }

    func removeRepositoryPlanExclusion(
        projectID: ProjectID,
        subject: RepositoryPlanReconstructionSubject
    ) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review,
              review.exclusions.contains(where: { $0.subject == subject }) else { return }
        review.exclusions.removeAll { $0.subject == subject }
        review.authorityConfirmed = false
        review.savedReadback = nil
        review.isDeciding = false
        review.revision &+= 1
        review.isUpdating = true
        let revision = review.revision
        presentation.review = review
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        do {
            let preview = try await repositoryPlanPreviewer(
                review.source,
                review.reviewedProjection,
                review.corrections,
                review.explicitMappings
            )
            guard var current = repositoryPlanReconstructions[projectID],
                  current.stage == .reviewing,
                  var currentReview = current.review,
                  currentReview.revision == revision,
                  currentReview.source == review.source else { return }
            Self.applyRepositoryPlanExclusions(
                currentReview.exclusions,
                preview: preview,
                to: &currentReview
            )
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = nil
            repositoryPlanReconstructions[projectID] = current
        } catch {
            guard var current = repositoryPlanReconstructions[projectID],
                  var currentReview = current.review,
                  currentReview.source == review.source,
                  currentReview.revision == revision else { return }
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = current
        }
    }

    func setRepositoryPlanMapping(
        projectID: ProjectID,
        subject: RepositoryPlanReconstructionSubject,
        destinationID: String?
    ) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review else { return }
        let trimmedDestination = destinationID?.trimmingCharacters(in: .whitespacesAndNewlines)
        review.explicitMappings.removeAll { $0.subject == subject }
        if let trimmedDestination, !trimmedDestination.isEmpty {
            review.explicitMappings.append(.init(
                subject: subject,
                destinationID: trimmedDestination
            ))
        }
        review.authorityConfirmed = false
        review.savedReadback = nil
        review.isDeciding = false
        review.revision &+= 1
        review.isUpdating = true
        let revision = review.revision
        presentation.review = review
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        do {
            let preview = try await repositoryPlanPreviewer(
                review.source,
                review.reviewedProjection,
                review.corrections,
                review.explicitMappings
            )
            guard var current = repositoryPlanReconstructions[projectID],
                  current.stage == .reviewing,
                  var currentReview = current.review,
                  currentReview.revision == revision,
                  currentReview.source == review.source else { return }
            Self.applyRepositoryPlanExclusions(
                currentReview.exclusions,
                preview: preview,
                to: &currentReview
            )
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = nil
            repositoryPlanReconstructions[projectID] = current
        } catch {
            guard var current = repositoryPlanReconstructions[projectID],
                  var currentReview = current.review,
                  currentReview.source == review.source,
                  currentReview.revision == revision else { return }
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = current
        }
    }

    func saveRepositoryPlanReconstruction(
        projectID: ProjectID,
        rationale: String
    ) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review,
              review.authorityConfirmed,
              !review.isSaving,
              !review.isUpdating,
              let proposalID = presentation.proposalID
                ?? presentation.preparation?.identity.proposalID,
              !rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let revision = review.revision
        review.isSaving = true
        presentation.review = review
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        let payload = RepositoryPlanReconstructionPayload(
            source: review.source,
            reviewedProjection: review.reviewedProjection,
            comparisons: review.comparisons,
            corrections: review.corrections,
            exclusions: review.exclusions,
            terminalEvidence: review.terminalEvidence,
            blockers: review.blockers
        )
        let result = await repositoryPlanOwnerCommandDispatch(
            projectID,
            review.source.registration,
            requestIDGenerator(),
            .saveRepositoryPlanReconstruction(
                proposalID: proposalID.rawValue,
                expectedPreviousVersion: review.persistedVersion,
                rationale: rationale,
                payload: payload
            )
        )
        guard var current = repositoryPlanReconstructions[projectID],
              current.stage == .reviewing,
              var currentReview = current.review,
              currentReview.source == review.source else { return }
        currentReview.isSaving = false
        if let error = result.error {
            current.message = Self.repositoryPlanSaveFailureMessage(error)
        } else if let readback = result.repositoryPlanReconstruction,
                  readback.proposalID == proposalID,
                  readback.payload == payload {
            currentReview.persistedVersion = readback.version.version
            if currentReview.revision == revision {
                currentReview.savedReadback = readback
                current.message = "Saved proposal version \(readback.version.version). Approve and Apply remain separate owner actions."
            } else {
                current.message = "Saved version \(readback.version.version); newer review edits remain unsaved."
            }
        } else {
            current.message = "The reviewed proposal was not returned. Refresh the review before continuing."
        }
        current.review = currentReview
        repositoryPlanReconstructions[projectID] = current
    }

    func setRepositoryPlanTerminalEvidence(
        projectID: ProjectID,
        evidence: [RepositoryPlanTerminalEvidence]
    ) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review else { return }
        guard evidence.allSatisfy({ item in
            guard case let .ownerAttestation(attestation) = item else { return true }
            return Data(attestation.decisionID.utf8) == Data(review.decisionID.utf8)
        }) else {
            presentation.message = "Every owner attestation must bind this review's exact approval decision."
            repositoryPlanReconstructions[projectID] = presentation
            return
        }
        guard evidence != review.terminalEvidence else { return }
        review.terminalEvidence = evidence
        review.authorityConfirmed = false
        review.savedReadback = nil
        review.isDeciding = false
        review.revision &+= 1
        review.isUpdating = true
        let revision = review.revision
        presentation.review = review
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        do {
            let preview = try await repositoryPlanPreviewer(
                review.source,
                review.reviewedProjection,
                review.corrections,
                review.explicitMappings
            )
            guard var current = repositoryPlanReconstructions[projectID],
                  current.stage == .reviewing,
                  var currentReview = current.review,
                  currentReview.revision == revision,
                  currentReview.source == review.source else { return }
            Self.applyRepositoryPlanExclusions(
                currentReview.exclusions,
                preview: preview,
                to: &currentReview
            )
            currentReview.isUpdating = false
            current.review = currentReview
            current.message = nil
            repositoryPlanReconstructions[projectID] = current
        } catch {
            guard var current = repositoryPlanReconstructions[projectID],
                  let currentReview = current.review,
                  currentReview.source == review.source,
                  currentReview.revision == revision else { return }
            current.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = current
        }
    }

    func addRepositoryPlanOriginalEvidence(
        projectID: ProjectID,
        sourceRef: RepositoryPlanSourceReference
    ) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              let review = presentation.review else { return }
        do {
            let evidence = try RepositoryPlanTerminalEvidenceResolver.original(
                sourceRef: sourceRef,
                source: review.source
            )
            guard !review.terminalEvidence.contains(evidence) else { return }
            await setRepositoryPlanTerminalEvidence(
                projectID: projectID,
                evidence: review.terminalEvidence + [evidence]
            )
        } catch {
            presentation.message = error.localizedDescription
            repositoryPlanReconstructions[projectID] = presentation
        }
    }

    func approveRepositoryPlanReconstruction(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              var review = presentation.review,
              review.authorityConfirmed,
              !review.isUpdating,
              !review.isSaving,
              !review.isDeciding,
              review.blockers.isEmpty,
              !review.comparisons.contains(where: {
                  $0.disposition == .blocked || $0.disposition == .conflicting
              }),
              let saved = review.savedReadback,
              saved.payload == Self.repositoryPlanPayload(from: review),
              saved.version.decision == nil else { return }
        let revision = review.revision
        review.isDeciding = true
        presentation.review = review
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        let result = await repositoryPlanOwnerCommandDispatch(
            projectID,
            review.source.registration,
            requestIDGenerator(),
            .decidePlanChangeProposal(
                proposalID: saved.proposalID.rawValue,
                version: saved.version.version,
                baselineDigest: saved.version.baselineDigest,
                decisionID: review.decisionID,
                disposition: .approved
            )
        )
        guard var current = repositoryPlanReconstructions[projectID],
              current.stage == .reviewing,
              var currentReview = current.review,
              currentReview.revision == revision,
              currentReview.source == review.source else { return }
        currentReview.isDeciding = false
        if let error = result.error {
            current.message = "The reviewed repository plan could not be approved: \(String(describing: error))"
        } else if let readback = result.repositoryPlanReconstruction,
                  readback.proposalID == saved.proposalID,
                  readback.version.version == saved.version.version,
                  readback.payload == saved.payload,
                  readback.version.decision?.id == review.decisionID,
                  readback.version.decision?.disposition == .approved {
            currentReview.savedReadback = readback
            current.message = "Approved proposal version \(readback.version.version). Apply remains a separate owner action."
        } else {
            current.message = "The exact approved reconstruction readback was unavailable. Refresh before applying."
        }
        current.review = currentReview
        repositoryPlanReconstructions[projectID] = current
    }

    func applyRepositoryPlanReconstruction(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .reviewing,
              let review = presentation.review,
              review.authorityConfirmed,
              !review.isUpdating,
              !review.isSaving,
              !review.isDeciding,
              review.blockers.isEmpty,
              let saved = review.savedReadback,
              saved.payload == Self.repositoryPlanPayload(from: review),
              let decision = saved.version.decision,
              decision.disposition == .approved,
              decision.id == review.decisionID,
              saved.version.application == nil else { return }
        let requestID = requestIDGenerator()
        let applicationID = "application-\(requestID.uuidString.lowercased())"
        var applyingReview = review
        applyingReview.pendingApplyIdentity = .init(
            proposalID: saved.proposalID,
            version: saved.version.version,
            applicationID: applicationID,
            requestID: requestID
        )
        presentation.stage = .applying
        presentation.review = applyingReview
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        let result = await repositoryPlanOwnerCommandDispatch(
            projectID,
            review.source.registration,
            requestID,
            .applyPlanChangeProposal(
                proposalID: saved.proposalID.rawValue,
                version: saved.version.version,
                baselineDigest: saved.version.baselineDigest,
                decisionID: decision.id,
                applicationID: applicationID
            )
        )
        let exactReadback: RepositoryPlanReconstructionReadback?
        do {
            exactReadback = try await repositoryPlanReadbackLoader(
                store,
                projectID,
                saved.proposalID
            ).first { $0.version.version == saved.version.version }
        } catch {
            exactReadback = nil
        }
        guard var current = repositoryPlanReconstructions[projectID],
              current.stage == .applying,
              var currentReview = current.review,
              currentReview.revision == review.revision,
              currentReview.source == review.source else { return }
        if let exactReadback {
            currentReview.savedReadback = exactReadback
        }
        current.review = currentReview
        let readback = exactReadback ?? result.repositoryPlanReconstruction
        if let readback,
           readback.version.application != nil,
           readback.applicationAttempt?.state == .applied {
            currentReview.savedReadback = readback
            currentReview.pendingApplyIdentity = nil
            current.review = currentReview
            current.stage = .applied
            current.message = "Applied proposal version \(readback.version.version). Refreshing the latest local project projections…"
            repositoryPlanReconstructions[projectID] = current
            await refreshAfterRepositoryPlanApplication(
                projectID: projectID,
                version: readback.version.version,
                recovered: false
            )
            return
        }
        if exactReadback == nil {
            current.stage = .outcomeUnknown
            current.message = "Apply may have committed, but its authoritative readback is unavailable. Recover this exact recorded attempt; no new Apply will be created."
        } else if result.error == .repositoryPlanReconstructionApplicationOutcomeUnknown
            || result.error == .outcomeUnknown
            || readback?.applicationAttempt?.state == .pending
            || readback?.applicationAttempt?.state == .outcomeUnknown {
            current.stage = .outcomeUnknown
            current.message = "Apply outcome is unknown. Reconcile the exact recorded attempt before retrying."
        } else if let error = result.error {
            current.stage = .reviewing
            current.message = "The approved repository plan was not applied: \(String(describing: error))"
        } else {
            current.stage = .outcomeUnknown
            current.message = "Apply did not return an exact terminal readback. Reconcile the recorded attempt."
        }
        repositoryPlanReconstructions[projectID] = current
    }

    func recoverRepositoryPlanReconstructionApply(projectID: ProjectID) async {
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .outcomeUnknown,
              let review = presentation.review,
              let saved = review.savedReadback else { return }
        let pendingIdentity = review.pendingApplyIdentity
        let loadedBeforeRecovery: RepositoryPlanReconstructionReadback
        do {
            guard let loaded = try await repositoryPlanReadbackLoader(
                store,
                projectID,
                saved.proposalID
            ).first(where: { $0.version.version == saved.version.version }) else {
                presentation.message = "The exact Apply readback is still unavailable. Retry recovery without creating a new Apply."
                repositoryPlanReconstructions[projectID] = presentation
                return
            }
            loadedBeforeRecovery = loaded
        } catch {
            presentation.message = "The exact Apply readback is still unavailable: \(error.localizedDescription). Retry recovery without creating a new Apply."
            repositoryPlanReconstructions[projectID] = presentation
            return
        }
        if loadedBeforeRecovery.version.application != nil,
           loadedBeforeRecovery.applicationAttempt?.state == .applied {
            var recoveredReview = review
            recoveredReview.savedReadback = loadedBeforeRecovery
            recoveredReview.pendingApplyIdentity = nil
            presentation.review = recoveredReview
            presentation.stage = .applied
            presentation.message = "Recovered the applied proposal version \(loadedBeforeRecovery.version.version). Refreshing the latest local project projections…"
            repositoryPlanReconstructions[projectID] = presentation
            await refreshAfterRepositoryPlanApplication(
                projectID: projectID,
                version: loadedBeforeRecovery.version.version,
                recovered: true
            )
            return
        }
        guard let attempt = loadedBeforeRecovery.applicationAttempt,
              attempt.state == .pending || attempt.state == .outcomeUnknown,
              pendingIdentity.map({ identity in
                  identity.proposalID == attempt.proposalID
                      && identity.version == attempt.version
                      && identity.applicationID == attempt.applicationID
                      && identity.requestID == attempt.requestID
              }) ?? true else {
            presentation.message = "The persisted Apply attempt does not match the submitted owner action. No replay was performed."
            repositoryPlanReconstructions[projectID] = presentation
            return
        }
        presentation.stage = .applying
        presentation.message = nil
        repositoryPlanReconstructions[projectID] = presentation
        let reconciled: RepositoryPlanReconstructionApplicationAttemptRecord
        do {
            reconciled = try await repositoryPlanApplyReconciler(attempt)
        } catch {
            guard var current = repositoryPlanReconstructions[projectID],
                  current.stage == .applying else { return }
            current.stage = .outcomeUnknown
            current.message = "The exact Apply attempt could not be reconciled: \(error.localizedDescription)"
            repositoryPlanReconstructions[projectID] = current
            return
        }
        if reconciled.state == .pending || reconciled.state == .outcomeUnknown {
            _ = await repositoryPlanApplyReplayer(reconciled)
        }
        let exactReadback: RepositoryPlanReconstructionReadback?
        do {
            exactReadback = try await repositoryPlanReadbackLoader(
                store,
                projectID,
                saved.proposalID
            ).first { $0.version.version == saved.version.version }
        } catch {
            exactReadback = nil
        }
        guard var current = repositoryPlanReconstructions[projectID],
              current.stage == .applying,
              var currentReview = current.review,
              currentReview.source == review.source else { return }
        guard let exactReadback else {
            current.stage = .outcomeUnknown
            current.message = "The exact Apply attempt was reconciled, but its persisted readback is unavailable. Retry recovery without creating a new Apply."
            repositoryPlanReconstructions[projectID] = current
            return
        }
        currentReview.savedReadback = exactReadback
        current.review = currentReview
        if exactReadback.version.application != nil,
           exactReadback.applicationAttempt?.state == .applied {
            current.stage = .applied
            currentReview.pendingApplyIdentity = nil
            current.review = currentReview
            current.message = "Recovered the applied proposal version \(exactReadback.version.version). Refreshing the latest local project projections…"
            repositoryPlanReconstructions[projectID] = current
            await refreshAfterRepositoryPlanApplication(
                projectID: projectID,
                version: exactReadback.version.version,
                recovered: true
            )
        } else if exactReadback.applicationAttempt?.state == .refused {
            current.stage = .reviewing
            current.message = "The recorded Apply attempt was refused. Review the exact saved version before taking another owner action."
            repositoryPlanReconstructions[projectID] = current
        } else {
            current.stage = .outcomeUnknown
            current.message = "Apply outcome remains unknown. Reconcile this exact recorded attempt again; no new Apply was created."
            repositoryPlanReconstructions[projectID] = current
        }
    }

    private func refreshAfterRepositoryPlanApplication(
        projectID: ProjectID,
        version: Int64,
        recovered: Bool
    ) async {
        let outcome = await reloadProjectProjections()
        guard var presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .applied else { return }
        let action = recovered ? "Recovered the applied" : "Applied"
        switch outcome {
        case .published:
            presentation.message = "\(action) proposal version \(version). The latest local project projections reloaded successfully; open Project Plan, Phase Board, or History to inspect current state and remaining work."
        case .failed:
            presentation.message = "\(action) proposal version \(version), but the project view refresh failed. Reload the dashboard before relying on Project Plan, Phase Board, or History."
        case .superseded:
            presentation.message = "\(action) proposal version \(version). Another projection reload superseded this refresh; reload the dashboard before relying on Project Plan, Phase Board, or History."
        }
        repositoryPlanReconstructions[projectID] = presentation
    }

    func retryRepositoryPlanProjectionRefresh(projectID: ProjectID) async {
        guard let presentation = repositoryPlanReconstructions[projectID],
              presentation.stage == .applied,
              let version = presentation.review?.savedReadback?.version.version else { return }
        await refreshAfterRepositoryPlanApplication(
            projectID: projectID,
            version: version,
            recovered: false
        )
    }

    private func repositoryPlanReviewPresentation(
        applying readback: RepositoryPlanPreparationReadback,
        to presentation: RepositoryPlanReconstructionPresentation
    ) async throws -> RepositoryPlanReconstructionPresentation {
        var updated = presentation
        guard readback.state == .readyForReview else {
            updated.apply(readback)
            return updated
        }
        let draft = try await repositoryPlanPreparationService.reviewDraft(
            identity: readback.identity
        )
        guard draft.source.projectID == presentation.projectID,
              draft.source.registration == readback.identity.registration,
              draft.source.rootID == readback.identity.rootID,
              draft.source.projectionBytes == readback.draftBytes else {
            throw RepositoryPlanPreparationError(code: .identityMismatch)
        }
        let preview = try await repositoryPlanPreviewer(
            draft.source,
            draft.originalProjection,
            [],
            []
        )
        let inferredMappings: [RepositoryPlanReconstructionMappingSelection] = preview.comparisons.compactMap { comparison in
            guard comparison.disposition == .unchanged,
                  let destinationID = comparison.destinationID else { return nil }
            return RepositoryPlanReconstructionMappingSelection(
                subject: comparison.subject,
                destinationID: destinationID
            )
        }
        let persistedVersion = try await repositoryPlanReadbackLoader(
            store,
            presentation.projectID,
            readback.identity.proposalID
        ).map(\.version.version).max()
        updated.preparation = readback
        updated.proposalID = readback.identity.proposalID
        updated.review = .init(
            source: draft.source,
            originalProjection: draft.originalProjection,
            reviewedProjection: draft.originalProjection,
            comparisons: preview.comparisons,
            blockers: preview.blockers,
            corrections: [],
            exclusions: [],
            explicitMappings: inferredMappings,
            destinationSnapshots: preview.destinationSnapshots,
            terminalEvidence: [],
            decisionID: "decision-\(requestIDGenerator().uuidString.lowercased())",
            authorityConfirmed: false,
            savedReadback: nil,
            persistedVersion: persistedVersion,
            revision: 0,
            isUpdating: false,
            isSaving: false,
            isDeciding: false
        )
        updated.stage = .reviewing
        updated.message = nil
        return updated
    }

    private func repositoryPlanPersistedPresentation(
        from readback: RepositoryPlanReconstructionReadback
    ) async throws -> RepositoryPlanReconstructionPresentation {
        let originalProjection = try JSONDecoder().decode(
            RepositoryPlanProjection.self,
            from: readback.payload.source.projectionBytes
        )
        let attestationDecisionIDs: Set<String> = Set(
            readback.payload.terminalEvidence.compactMap { evidence -> String? in
            guard case let .ownerAttestation(attestation) = evidence else { return nil }
            return attestation.decisionID
            }
        )
        guard attestationDecisionIDs.count <= 1 else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Persisted owner attestations bind more than one reconstruction decision."
            )
        }
        let decisionID = readback.version.decision?.id
            ?? attestationDecisionIDs.first
            ?? "decision-\(requestIDGenerator().uuidString.lowercased())"
        guard attestationDecisionIDs.allSatisfy({ Data($0.utf8) == Data(decisionID.utf8) }) else {
            throw RepositoryPlanReconstructionError.invalidPayload(
                "Persisted owner attestations do not bind the recorded reconstruction decision."
            )
        }
        let explicitMappings: [RepositoryPlanReconstructionMappingSelection] = readback.payload.comparisons.compactMap { comparison in
            guard comparison.disposition == .unchanged,
                  let destinationID = comparison.destinationID else { return nil }
            return RepositoryPlanReconstructionMappingSelection(
                subject: comparison.subject,
                destinationID: destinationID
            )
        }
        let destinationSnapshots: [RepositoryPlanReconstructionDestinationSnapshot]
        let comparisonWarning: String?
        do {
            let preview = try await repositoryPlanPreviewer(
                readback.payload.source,
                readback.payload.reviewedProjection,
                readback.payload.corrections,
                explicitMappings
            )
            destinationSnapshots = preview.destinationSnapshots
            comparisonWarning = nil
        } catch {
            destinationSnapshots = []
            comparisonWarning = "The saved review and exact Apply state were restored, but the current destination comparison is unavailable: \(error.localizedDescription)."
        }
        let stage: RepositoryPlanReconstructionStage
        if readback.version.application != nil
            || readback.applicationAttempt?.state == .applied {
            stage = .applied
        } else if readback.applicationAttempt?.state == .pending
            || readback.applicationAttempt?.state == .outcomeUnknown {
            stage = .outcomeUnknown
        } else {
            stage = .reviewing
        }
        let persistedMessage = [
            stage == .outcomeUnknown
                ? "A recorded Apply attempt needs exact reconciliation before any new Apply."
                : nil,
            comparisonWarning,
        ].compactMap { $0 }.joined(separator: " ")
        return .init(
            projectID: readback.payload.source.projectID,
            proposalID: readback.proposalID,
            stage: stage,
            inventory: nil,
            target: nil,
            selectedArtifactIDs: [],
            preparation: nil,
            review: .init(
                source: readback.payload.source,
                originalProjection: originalProjection,
                reviewedProjection: readback.payload.reviewedProjection,
                comparisons: readback.payload.comparisons,
                blockers: readback.payload.blockers,
                corrections: readback.payload.corrections,
                exclusions: readback.payload.exclusions,
                explicitMappings: explicitMappings,
                destinationSnapshots: destinationSnapshots,
                terminalEvidence: readback.payload.terminalEvidence,
                decisionID: decisionID,
                authorityConfirmed: readback.version.decision?.disposition == .approved,
                savedReadback: readback,
                persistedVersion: readback.version.version,
                revision: 0,
                isUpdating: false,
                isSaving: false,
                isDeciding: false,
                pendingApplyIdentity: readback.applicationAttempt.map {
                    .init(
                        proposalID: $0.proposalID,
                        version: $0.version,
                        applicationID: $0.applicationID,
                        requestID: $0.requestID
                    )
                }
            ),
            message: persistedMessage.isEmpty ? nil : persistedMessage
        )
    }

    private static func applyRepositoryPlanExclusions(
        _ exclusions: [RepositoryPlanReconstructionExclusion],
        preview: RepositoryPlanReconstructionPreview,
        to review: inout RepositoryPlanReconstructionReviewPresentation
    ) {
        review.destinationSnapshots = preview.destinationSnapshots
        let excluded = Set(exclusions.map(\.subject))
        review.comparisons = preview.comparisons.map { comparison in
            guard excluded.contains(comparison.subject) else { return comparison }
            return .init(
                kind: comparison.kind,
                parentSourceID: comparison.parentSourceID,
                sourceID: comparison.sourceID,
                destinationID: comparison.destinationID,
                disposition: .excluded
            )
        }
        review.blockers = preview.blockers.filter { blocker in
            blocker.subject.map { !excluded.contains($0) } ?? true
        }
        func block(_ subject: RepositoryPlanReconstructionSubject, message: String) {
            guard !excluded.contains(subject),
                  let index = review.comparisons.firstIndex(where: { $0.subject == subject }) else {
                return
            }
            let comparison = review.comparisons[index]
            review.comparisons[index] = .init(
                kind: comparison.kind,
                parentSourceID: comparison.parentSourceID,
                sourceID: comparison.sourceID,
                destinationID: comparison.destinationID,
                disposition: .blocked
            )
            let blocker = RepositoryPlanReconstructionBlocker(
                code: "excluded_required_record",
                subject: subject,
                message: message
            )
            if !review.blockers.contains(where: { $0.id == blocker.id }) {
                review.blockers.append(blocker)
            }
        }

        func nonincludedSourceIDs(
            kind: RepositoryPlanReconstructionRecordKind
        ) -> Set<String> {
            Set(review.comparisons.compactMap { comparison in
                guard comparison.kind == kind,
                      comparison.disposition != .new,
                      comparison.disposition != .unchanged else { return nil }
                return comparison.sourceID
            })
        }

        let nonincludedPhases = nonincludedSourceIDs(kind: .phase)
        for ticket in review.reviewedProjection.tickets {
            guard let phase = ticket.phaseSourceID, nonincludedPhases.contains(phase) else { continue }
            block(
                .init(kind: .ticket, parentSourceID: nil, sourceID: ticket.sourceID),
                message: "This included ticket requires a nonincluded phase. Explicitly exclude the ticket or restore the phase."
            )
        }

        let nonincludedTickets = nonincludedSourceIDs(kind: .ticket)
        let tasks = review.comparisons.filter { $0.kind == .task }
        for comparison in tasks {
            if let parent = comparison.parentSourceID, nonincludedTickets.contains(parent) {
                block(
                    comparison.subject,
                    message: "This included task requires a nonincluded parent ticket. Explicitly exclude the task or restore the parent."
                )
            }
        }
        for dependency in review.reviewedProjection.phaseDependencies
            where nonincludedPhases.contains(dependency.subjectSourceID)
                || nonincludedPhases.contains(dependency.dependsOnSourceID) {
            block(
                .init(
                    kind: .phaseDependency,
                    parentSourceID: dependency.subjectSourceID,
                    sourceID: dependency.sourceID
                ),
                message: "This phase dependency references a nonincluded phase. Explicitly exclude the dependency or restore both phases."
            )
        }
        for dependency in review.reviewedProjection.ticketDependencies
            where nonincludedTickets.contains(dependency.subjectSourceID)
                || nonincludedTickets.contains(dependency.dependsOnSourceID) {
            block(
                .init(
                    kind: .ticketDependency,
                    parentSourceID: dependency.subjectSourceID,
                    sourceID: dependency.sourceID
                ),
                message: "This ticket dependency references a nonincluded ticket. Explicitly exclude the dependency or restore both tickets."
            )
        }
    }

    private static func repositoryPlanSourceValue(
        subject: RepositoryPlanReconstructionSubject,
        field: String,
        projection: RepositoryPlanProjection
    ) throws -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        switch subject.kind {
        case .phase:
            guard let value = projection.phases.first(where: { $0.sourceID == subject.sourceID }) else {
                throw RepositoryPlanReconstructionError.invalidPayload("The phase correction source is unavailable.")
            }
            switch field {
            case "name": return try encoder.encode(value.name)
            case "lifecycle": return try encoder.encode(value.lifecycle)
            case "authorityClass": return try encoder.encode(value.authorityClass)
            default: break
            }
        case .ticket:
            guard let value = projection.tickets.first(where: { $0.sourceID == subject.sourceID }) else {
                throw RepositoryPlanReconstructionError.invalidPayload("The ticket correction source is unavailable.")
            }
            switch field {
            case "outcome": return try encoder.encode(value.outcome)
            case "phaseSourceID": return try encoder.encode(value.phaseSourceID)
            case "lane": return try encoder.encode(value.lane)
            case "authorityClass": return try encoder.encode(value.authorityClass)
            default: break
            }
        case .task:
            guard let parent = subject.parentSourceID,
                  let value = projection.tickets.first(where: { $0.sourceID == parent })?
                    .taskPlan?.tasks.first(where: { $0.sourceID == subject.sourceID }) else {
                throw RepositoryPlanReconstructionError.invalidPayload("The task correction source is unavailable.")
            }
            switch field {
            case "authorityClass": return try encoder.encode(value.authorityClass)
            case "label": return try encoder.encode(value.label)
            case "title": return try encoder.encode(value.title)
            case "sortOrder": return try encoder.encode(value.sortOrder)
            case "completion": return try encoder.encode(value.completion)
            case "lifecycle": return try encoder.encode(value.lifecycle)
            default: break
            }
        case .phaseDependency, .ticketDependency:
            let values = subject.kind == .phaseDependency
                ? projection.phaseDependencies : projection.ticketDependencies
            guard let value = values.first(where: { $0.sourceID == subject.sourceID }) else {
                throw RepositoryPlanReconstructionError.invalidPayload("The dependency correction source is unavailable.")
            }
            switch field {
            case "subjectSourceID": return try encoder.encode(value.subjectSourceID)
            case "dependsOnSourceID": return try encoder.encode(value.dependsOnSourceID)
            default: break
            }
        }
        throw RepositoryPlanReconstructionError.invalidPayload(
            "The requested reconstruction correction field is not editable."
        )
    }

    private static func repositoryPlanSaveFailureMessage(_ error: AgentCommandError) -> String {
        switch error {
        case .repositoryPlanReconstructionStaleSource:
            "The repository source or destination changed. Prepare or review a fresh version before saving."
        default:
            "The reviewed repository plan could not be saved: \(String(describing: error))"
        }
    }

    private static func repositoryPlanPayload(
        from review: RepositoryPlanReconstructionReviewPresentation
    ) -> RepositoryPlanReconstructionPayload {
        .init(
            source: review.source,
            reviewedProjection: review.reviewedProjection,
            comparisons: review.comparisons,
            corrections: review.corrections,
            exclusions: review.exclusions,
            terminalEvidence: review.terminalEvidence,
            blockers: review.blockers
        )
    }

    private func reloadRepositoryPlanSourceDisclosure(
        projectID: ProjectID,
        target: RepositoryPlanPreparationTarget,
        message: String,
        operationGeneration: UInt64
    ) async {
        do {
            let inventory = try await repositoryPlanSourceLoader(store, projectOnboarding, projectID)
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration else {
                return
            }
            repositoryPlanReconstructions[projectID] = .selecting(
                projectID: projectID,
                inventory: inventory,
                target: target,
                message: message
            )
        } catch {
            guard repositoryPlanPreparationOperationGenerations[projectID] == operationGeneration else {
                return
            }
            repositoryPlanReconstructions[projectID] = .failed(
                projectID: projectID,
                message: error.localizedDescription
            )
        }
    }

    private func nextRepositoryPlanPreparationOperationGeneration(_ projectID: ProjectID) -> UInt64 {
        let generation = (repositoryPlanPreparationOperationGenerations[projectID] ?? 0) &+ 1
        repositoryPlanPreparationOperationGenerations[projectID] = generation
        return generation
    }

    private static func canStartRepositoryPlanPreparation(
        from stage: RepositoryPlanReconstructionStage
    ) -> Bool {
        switch stage {
        case .selectingSources, .failed, .preparing(.failed), .preparing(.cancelled):
            true
        case .loadingSources, .starting, .preparing, .reviewing, .reviewLoadFailed,
             .applying, .outcomeUnknown, .applied:
            false
        }
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
        guard let key = dependencySessionKey(for: .dependencies(projectID)),
              let ticketID = dependencyFocusIDs[key] else {
            return graph.clearingSelection()
        }
        return graph.selecting(ticketID)
    }

    func dependencyFocusID(for projectID: ProjectID) -> TicketID {
        guard let key = dependencySessionKey(for: .dependencies(projectID)) else {
            return TicketID(rawValue: "")
        }
        return dependencyFocusIDs[key] ?? TicketID(rawValue: "")
    }

    func selectDependencyTicket(_ ticketID: TicketID, projectID: ProjectID) {
        guard let key = dependencySessionKey(for: .dependencies(projectID)) else { return }
        if ticketID.rawValue.isEmpty {
            dependencyFocusIDs.removeValue(forKey: key)
        } else {
            dependencyFocusIDs[key] = ticketID
        }
        selectedTicketID = ticketID
        navigationFocus = ticketID.rawValue.isEmpty ? .route(.dependencies(projectID)) : .ticket(ticketID)
        captureCurrentNavigationContext()
    }

    func reloadDependencyData() async {
        _ = await reloadProjectProjections()
    }

    func dependencyGraphPresentationIdentity(
        for projectID: ProjectID
    ) -> DependencyGraphPresentationIdentity? {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID),
              identity.registration != nil else { return nil }
        return identity
    }

    func dependencyGraphPresentationLoadIdentity(
        for projectID: ProjectID
    ) -> DependencyGraphPresentationIdentity? {
        dependencyGraphPresentationStateIdentity(for: projectID)
    }

    private func dependencyGraphPresentationStateIdentity(
        for projectID: ProjectID
    ) -> DependencyGraphPresentationIdentity? {
        guard let sessionKey = dependencySessionKey(for: .dependencies(projectID)),
              let focusTicketID = dependencyFocusIDs[sessionKey],
              !focusTicketID.rawValue.isEmpty else { return nil }
        return .init(
            projectID: projectID,
            registration: sessionKey.registration,
            focusTicketID: focusTicketID
        )
    }

    func dependencyGraphRankOrder(for projectID: ProjectID) -> DependencyGraphRankOrder? {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID) else { return nil }
        return dependencyPresentationOrders[identity]
    }

    func dependencyGraphArrangementStatus(for projectID: ProjectID) -> DependencyGraphArrangementStatus {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID) else { return .automatic }
        return dependencyPresentationStatuses[identity] ?? .automatic
    }

    func loadDependencyGraphPresentation(projectID: ProjectID, force: Bool = false) async {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID) else { return }
        if !force, loadedDependencyPresentations.contains(identity) { return }
        loadedDependencyPresentations.insert(identity)
        guard let registration = identity.registration else {
            dependencyPresentationStatuses[identity] = .sessionOnly
            return
        }
        let generation = nextDependencyPresentationOperationGeneration(for: identity)
        dependencyPresentationStatuses[identity] = .loading
        do {
            let record = try await dependencyGraphPresentationPersistence.load(
                store, registration, identity.focusTicketID
            )
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            switch record {
            case .none:
                dependencyPresentationOrders.removeValue(forKey: identity)
                dependencyPresentationStatuses[identity] = .automatic
            case let .supported(layout):
                dependencyPresentationOrders[identity] = .init(presentation: layout)
                dependencyPresentationStatuses[identity] = .saved
            case let .unsupported(version, _):
                dependencyPresentationOrders.removeValue(forKey: identity)
                dependencyPresentationStatuses[identity] = .unsupported(version)
            }
        } catch {
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            dependencyPresentationStatuses[identity] = .loadFailed(error.localizedDescription)
        }
    }

    func saveDependencyGraphPresentation(
        _ order: DependencyGraphRankOrder,
        projectID: ProjectID
    ) async {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID),
              !(dependencyPresentationStatuses[identity] ?? .automatic).blocksAdjustment else { return }
        dependencyPresentationOrders[identity] = order
        loadedDependencyPresentations.insert(identity)
        guard let registration = identity.registration else {
            dependencyPresentationStatuses[identity] = .sessionOnly
            return
        }
        let generation = nextDependencyPresentationOperationGeneration(for: identity)
        dependencyPresentationStatuses[identity] = .saving
        do {
            try await dependencyGraphPresentationPersistence.save(
                store, order.presentation, registration, identity.focusTicketID
            )
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            dependencyPresentationStatuses[identity] = .saved
        } catch let error as DependencyGraphPresentationError {
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            dependencyPresentationOrders.removeValue(forKey: identity)
            switch error {
            case let .unsupportedPayload(version):
                dependencyPresentationStatuses[identity] = .unsupported(version)
            }
        } catch {
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            dependencyPresentationStatuses[identity] = .saveFailed(error.localizedDescription)
        }
    }

    func resetDependencyGraphPresentation(projectID: ProjectID) async {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID) else { return }
        guard !dependencyGraphArrangementStatus(for: projectID).blocksAdjustment else { return }
        guard let registration = identity.registration else {
            dependencyPresentationOrders.removeValue(forKey: identity)
            dependencyPresentationStatuses[identity] = .automatic
            loadedDependencyPresentations.insert(identity)
            return
        }
        let generation = nextDependencyPresentationOperationGeneration(for: identity)
        dependencyPresentationStatuses[identity] = .saving
        do {
            try await dependencyGraphPresentationPersistence.reset(
                store, registration, identity.focusTicketID
            )
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            dependencyPresentationOrders.removeValue(forKey: identity)
            dependencyPresentationStatuses[identity] = .automatic
            loadedDependencyPresentations.insert(identity)
        } catch let error as DependencyGraphPresentationError {
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            switch error {
            case let .unsupportedPayload(version):
                dependencyPresentationOrders.removeValue(forKey: identity)
                dependencyPresentationStatuses[identity] = .unsupported(version)
            }
        } catch {
            guard dependencyPresentationOperationGenerations[identity] == generation else { return }
            dependencyPresentationStatuses[identity] = .resetFailed(error.localizedDescription)
        }
    }

    func retryDependencyGraphPresentation(projectID: ProjectID) async {
        guard let identity = dependencyGraphPresentationStateIdentity(for: projectID) else { return }
        switch dependencyPresentationStatuses[identity] ?? .automatic {
        case .loadFailed:
            await loadDependencyGraphPresentation(projectID: projectID, force: true)
        case .saveFailed:
            guard let order = dependencyPresentationOrders[identity] else { return }
            await saveDependencyGraphPresentation(order, projectID: projectID)
        case .resetFailed:
            await resetDependencyGraphPresentation(projectID: projectID)
        default:
            return
        }
    }

    private func nextDependencyPresentationOperationGeneration(
        for identity: DependencyGraphPresentationIdentity
    ) -> UInt64 {
        let generation = (dependencyPresentationOperationGenerations[identity] ?? 0) &+ 1
        dependencyPresentationOperationGenerations[identity] = generation
        return generation
    }

    func activity(for projectID: ProjectID) -> ProjectActivityProjection? {
        projectActivities[projectID]
    }

    func historyFilter(for projectID: ProjectID) -> HistoryFilter {
        historyFilters[Data(projectID.rawValue.utf8)] ?? .all
    }

    private var workspaceGoalsSelectedProjectID: ProjectID? {
        switch workspaceGoalsDomain {
        case .delivery:
            return selectedWorkspaceDeliveryGoalID.flatMap { selected in
                dashboard?.workspaceGoals.delivery.first(where: { $0.id == selected })?.project.id
            }
        case .execution:
            return selectedWorkspaceExecutionGoalID.flatMap { selected in
                dashboard?.workspaceGoals.execution.first(where: { $0.id == selected })?.project.id
            }
        }
    }

    private var workspaceGoalsNavigationState: WorkspaceGoalsNavigationState {
        .init(
            domain: workspaceGoalsDomain,
            projectID: workspaceGoalsProjectID,
            deliveryLifecycle: workspaceGoalsDeliveryLifecycle,
            executionStatus: workspaceGoalsExecutionStatus,
            executionScope: workspaceGoalsExecutionScope,
            selectedDeliveryID: selectedWorkspaceDeliveryGoalID,
            selectedExecutionID: selectedWorkspaceExecutionGoalID,
            viewportOffset: workspaceGoalsViewportOffset
        )
    }

    private var workspaceSearchNavigationState: WorkspaceSearchNavigationState {
        .init(
            definition: workspaceSearchDefinition,
            selectedResultID: selectedWorkspaceSearchResultID,
            viewportOffset: workspaceSearchViewportOffset,
            preferenceIsUnsupported: workspaceSearchPreferenceIsUnsupported,
            needsScopeReselection: workspaceSearchNeedsScopeReselection
        )
    }

    var availableWorkspaceSearchProjects: [WorkspaceSearchProjectIdentity] {
        let active = dashboard?.projects.compactMap { project -> WorkspaceSearchProjectIdentity? in
            guard let registration = project.registration else { return nil }
            return .init(
                projectID: project.id,
                registrationID: registration.registrationID,
                name: project.name,
                lifecycle: .active
            )
        } ?? []
        let archived = dashboard?.archivedProjects.map { project in
            WorkspaceSearchProjectIdentity(
                projectID: project.id,
                registrationID: project.registration.registrationID,
                name: project.name,
                lifecycle: .archived
            )
        } ?? []
        return (active + archived).sorted {
            ($0.name.localizedLowercase, $0.projectID.rawValue, $0.registrationID)
                < ($1.name.localizedLowercase, $1.projectID.rawValue, $1.registrationID)
        }
    }

    func setWorkspaceSearchText(_ text: String) {
        guard workspaceSearchDraft != text else { return }
        invalidateWorkspaceSearchRun(clearProjection: false)
        workspaceSearchDraft = text
        workspaceSearchFailure = nil
        navigationFocus = .workspaceSearchField
    }

    func setWorkspaceSearchSort(_ sort: WorkspaceSearchSort) {
        guard canEditSupportedWorkspaceSearch else { return }
        invalidateWorkspaceSearchRun()
        workspaceSearchDefinition.sort = sort
        navigationFocus = .workspaceSearchFilters
        captureCurrentNavigationContext()
    }

    func setWorkspaceSearchDomain(_ domain: WorkspaceSearchDomain, enabled: Bool) {
        guard canEditSupportedWorkspaceSearch else { return }
        invalidateWorkspaceSearchRun()
        if enabled { workspaceSearchDefinition.domains.insert(domain) }
        else { workspaceSearchDefinition.domains.remove(domain) }
        navigationFocus = .workspaceSearchFilters
        captureCurrentNavigationContext()
    }

    func updateWorkspaceSearchDomain(_ domain: WorkspaceSearchDomain, enabled: Bool) async {
        guard canEditSupportedWorkspaceSearch else { return }
        setWorkspaceSearchDomain(domain, enabled: enabled)
        await runWorkspaceSearch()
    }

    func setWorkspaceSearchAllAuthorizedScope() {
        guard canEditSupportedWorkspaceSearch else { return }
        invalidateWorkspaceSearchRun()
        workspaceSearchDefinition.scope = .allAuthorized
        workspaceSearchDefinition.authorityIncarnationID = nil
        workspaceSearchNeedsScopeReselection = false
        workspaceSearchFailure = nil
        navigationFocus = .workspaceSearchFilters
        captureCurrentNavigationContext()
    }

    func setWorkspaceSearchProject(_ project: WorkspaceSearchProjectIdentity, enabled: Bool) {
        guard canEditSupportedWorkspaceSearch else { return }
        var registrations: [WorkspaceSearchRegistrationIdentity]
        switch (workspaceSearchNeedsScopeReselection, workspaceSearchDefinition.scope) {
        case (true, _) where enabled:
            registrations = []
        case (_, .allAuthorized):
            registrations = availableWorkspaceSearchProjects.map {
                .init(projectID: $0.projectID, registrationID: $0.registrationID)
            }
        case let (_, .registrations(selected)):
            registrations = selected
        }
        let identity = WorkspaceSearchRegistrationIdentity(
            projectID: project.projectID,
            registrationID: project.registrationID
        )
        registrations.removeAll { registrationIdentity($0, matches: identity) }
        if enabled { registrations.append(identity) }
        guard !workspaceSearchNeedsScopeReselection || enabled else { return }
        invalidateWorkspaceSearchRun()
        registrations.sort { ($0.projectID.rawValue, $0.registrationID) < ($1.projectID.rawValue, $1.registrationID) }
        workspaceSearchDefinition.scope = .registrations(registrations)
        workspaceSearchDefinition.authorityIncarnationID = nil
        workspaceSearchNeedsScopeReselection = false
        workspaceSearchFailure = nil
        navigationFocus = .workspaceSearchFilters
        captureCurrentNavigationContext()
    }

    func workspaceSearchIncludes(_ project: WorkspaceSearchProjectIdentity) -> Bool {
        switch workspaceSearchDefinition.scope {
        case .allAuthorized:
            true
        case let .registrations(registrations):
            registrations.contains {
                registrationIdentity(
                    $0,
                    matches: .init(projectID: project.projectID, registrationID: project.registrationID)
                )
            }
        }
    }

    @discardableResult
    func runWorkspaceSearch(persist: Bool = true, captureNavigation: Bool = true) async -> Bool {
        if captureNavigation {
            captureCurrentNavigationContext()
        }
        let submittedNewDraft = workspaceSearchDefinition.text != workspaceSearchDraft
        if !workspaceSearchPreferenceIsUnsupported, submittedNewDraft {
            invalidateWorkspaceSearchRun()
            workspaceSearchDefinition.text = workspaceSearchDraft
            workspaceSearchFailure = nil
        }
        if captureNavigation {
            if selection == .search {
                if submittedNewDraft, !workspaceSearchPreferenceIsUnsupported {
                    navigationFocus = .workspaceSearchField
                    navigationHistory.navigate(to: historyEntry(for: .search, focus: navigationFocus))
                }
            } else {
                await navigate(to: .search)
            }
        }
        guard canExecuteWorkspaceSearch else { return false }
        workspaceSearchGeneration &+= 1
        let generation = workspaceSearchGeneration
        workspaceSearchIsLoading = true
        workspaceSearchFailure = nil
        workspaceSearchPersistenceMessage = nil
        do {
            let definition = if workspaceSearchDefinition.authorityIncarnationID == nil {
                try await WorkspaceSearchQuery.boundToCurrentAuthority(
                    store: store,
                    definition: workspaceSearchDefinition
                )
            } else {
                workspaceSearchDefinition
            }
            guard generation == workspaceSearchGeneration else { return false }
            let projection = try await workspaceSearchLoader(store, definition)
            guard generation == workspaceSearchGeneration else { return false }
            workspaceSearchDefinition = definition
            workspaceSearchProjection = projection
            workspaceSearchNeedsScopeReselection = false
            if let selectedWorkspaceSearchResultID,
               !projection.results.contains(where: { $0.id == selectedWorkspaceSearchResultID }) {
                self.selectedWorkspaceSearchResultID = nil
            }
            if persist {
                do {
                    try await WorkspaceSearchPreferencesRepository(store: store)
                        .saveWorkingDefinition(definition)
                } catch {
                    workspaceSearchPersistenceMessage = "Results are current, but the working search could not be saved: \(error.localizedDescription)"
                }
            }
        } catch {
            guard generation == workspaceSearchGeneration else { return false }
            workspaceSearchProjection = nil
            selectedWorkspaceSearchResultID = nil
            workspaceSearchFailure = error.localizedDescription
            if (error as? WorkspaceSearchError) == .authorizationRequired {
                workspaceSearchNeedsScopeReselection = true
            }
        }
        guard generation == workspaceSearchGeneration else { return false }
        workspaceSearchIsLoading = false
        if captureNavigation { captureCurrentNavigationContext() }
        return workspaceSearchFailure == nil && workspaceSearchProjection != nil
    }

    @discardableResult
    func loadWorkspaceSearchPreferences(runSearch: Bool) async -> Bool {
        let repository = WorkspaceSearchPreferencesRepository(store: store)
        invalidateWorkspaceSearchRun(clearProjection: false)
        let generation = workspaceSearchGeneration
        do {
            let savedQueries = try await repository.loadSavedQueries()
            let workingDefinition = try await repository.loadWorkingDefinition()
            guard generation == workspaceSearchGeneration else { return false }
            workspaceSearchSavedQueries = savedQueries
            workspaceSearchFailure = nil
            switch workingDefinition {
            case .none:
                workspaceSearchPreferenceIsUnsupported = false
                workspaceSearchNeedsScopeReselection = false
            case let .supported(definition):
                if workspaceSearchProjection?.definition != definition {
                    workspaceSearchProjection = nil
                    selectedWorkspaceSearchResultID = nil
                }
                workspaceSearchDefinition = definition
                workspaceSearchDraft = definition.text
                workspaceSearchPreferenceIsUnsupported = false
                workspaceSearchNeedsScopeReselection = false
            case .unsupported:
                workspaceSearchPreferenceIsUnsupported = true
                workspaceSearchNeedsScopeReselection = false
                workspaceSearchProjection = nil
                selectedWorkspaceSearchResultID = nil
                workspaceSearchPersistenceMessage = "The saved working search was created by a newer Release Radar. Its filters remain stored and were not replaced."
            }
            if runSearch, !workspaceSearchPreferenceIsUnsupported {
                return await runWorkspaceSearch(persist: false, captureNavigation: false)
            }
            return !workspaceSearchPreferenceIsUnsupported
        } catch {
            guard generation == workspaceSearchGeneration else { return false }
            workspaceSearchFailure = error.localizedDescription
            return false
        }
    }

    func loadWorkspaceSavedQuery(_ record: WorkspaceSavedQueryRecord) async {
        switch record {
        case let .supported(query):
            invalidateWorkspaceSearchRun()
            workspaceSearchDefinition = query.definition
            workspaceSearchDraft = query.definition.text
            workspaceSearchPreferenceIsUnsupported = false
            workspaceSearchNeedsScopeReselection = false
            selectedWorkspaceSearchResultID = nil
            workspaceSearchViewportOffset = nil
            await runWorkspaceSearch()
        case .unsupported:
            workspaceSearchFailure = "This saved query was created by a newer Release Radar. It remains stored and can be deleted, but its filters cannot be safely interpreted."
        }
    }

    @discardableResult
    func saveCurrentWorkspaceSearch(name: String) async -> WorkspaceSearchSaveOutcome {
        guard canExecuteWorkspaceSearch else {
            return .failed(
                workspaceSearchFailure
                    ?? workspaceSearchPersistenceMessage
                    ?? "The query could not be saved."
            )
        }
        let generation = workspaceSearchGeneration
        do {
            var definition = workspaceSearchDefinition
            definition.text = workspaceSearchDraft
            let repository = WorkspaceSearchPreferencesRepository(store: store)
            let saved = try await repository.saveQuery(name: name, definition: definition)
            guard generation == workspaceSearchGeneration else { return .saved(saved) }
            do {
                let queries = try await repository.loadSavedQueries()
                guard generation == workspaceSearchGeneration else { return .saved(saved) }
                workspaceSearchSavedQueries = queries
            } catch {
                guard generation == workspaceSearchGeneration else { return .saved(saved) }
                workspaceSearchSavedQueries.removeAll { $0.id == saved.id }
                workspaceSearchSavedQueries.append(.supported(saved))
                workspaceSearchSavedQueries.sort {
                    ($0.name.localizedLowercase, $0.id) < ($1.name.localizedLowercase, $1.id)
                }
            }
            workspaceSearchPersistenceMessage = "Saved query “\(saved.name)”."
            return .saved(saved)
        } catch {
            let message = error.localizedDescription
            guard generation == workspaceSearchGeneration else { return .failed(message) }
            workspaceSearchPersistenceMessage = message
            if (error as? WorkspaceSearchError) == .authorizationRequired {
                workspaceSearchNeedsScopeReselection = true
            }
            return .failed(message)
        }
    }

    func deleteWorkspaceSavedQuery(id: String) async {
        let generation = workspaceSearchGeneration
        do {
            let repository = WorkspaceSearchPreferencesRepository(store: store)
            try await repository.deleteQuery(id: id)
            let queries = try await repository.loadSavedQueries()
            guard generation == workspaceSearchGeneration else { return }
            workspaceSearchSavedQueries = queries
        } catch {
            guard generation == workspaceSearchGeneration else { return }
            workspaceSearchPersistenceMessage = error.localizedDescription
        }
    }

    func resetUnsupportedWorkspaceSearch() {
        guard workspaceSearchPreferenceIsUnsupported else { return }
        invalidateWorkspaceSearchRun()
        workspaceSearchDefinition = .init()
        workspaceSearchDraft = ""
        workspaceSearchPreferenceIsUnsupported = false
        workspaceSearchNeedsScopeReselection = false
        workspaceSearchFailure = nil
        workspaceSearchPersistenceMessage = "New Search ready. The newer-version working search will be replaced only after you run this new definition."
        navigationFocus = .workspaceSearchField
        captureCurrentNavigationContext()
    }

    func selectWorkspaceSearchResult(_ id: Data?) {
        selectedWorkspaceSearchResultID = id
        navigationFocus = id.map(NavigationFocus.workspaceSearchResult) ?? .workspaceSearchField
        captureCurrentNavigationContext()
    }

    func setWorkspaceSearchViewportOffset(_ offset: Double?) {
        workspaceSearchViewportOffset = offset.map { max(0, $0) }
        captureCurrentNavigationContext()
    }

    func openWorkspaceSearchResult(_ result: WorkspaceSearchResult) async {
        guard let registration = registrationMatchingSearchResult(result) else {
            navigationRecoveryMessage = "The exact project registration for this result is unavailable; a different registration was not substituted."
            navigationFocus = .recovery
            captureCurrentNavigationContext()
            return
        }
        if let removed = dashboard?.removedProjects.first(where: {
            $0.registration.hasSameNavigationIdentity(as: registration)
        }) {
            await navigate(to: .removedProject(removed.id))
            return
        }
        if dashboard?.archivedProjects.contains(where: {
            $0.registration.hasSameNavigationIdentity(as: registration)
        }) == true {
            await navigate(to: .archivedProject(registration.projectID))
            return
        }

        switch result.identity {
        case let .project(projectID, _):
            await navigate(to: .projectOverview(projectID))
        case let .deliveryGoal(projectID, _, phaseID, goalID):
            guard dashboard?.board(for: projectID, phaseID: phaseID)?.deliveryGoals.contains(where: {
                Data($0.goalID.rawValue.utf8) == Data(goalID.utf8)
            }) == true else { return searchDestinationUnavailable("Delivery Goal") }
            let expectedNavigationGeneration = navigationGeneration &+ 1
            await navigate(to: .phaseBoard(projectID))
            guard lastCommittedNavigationGeneration == expectedNavigationGeneration,
                  selection == .phaseBoard(projectID) else { return }
            viewPhase(projectID: projectID, phaseID: phaseID)
            setBoardFilter(.goal(.init(rawValue: goalID)), projectID: projectID, phaseID: phaseID)
        case let .executionGoal(projectID, _, threadID, goalID):
            guard let item = dashboard?.workspaceGoals.execution.first(where: {
                $0.project.id == projectID
                    && Data($0.threadID.utf8) == Data(threadID.rawValue.utf8)
                    && Data($0.goalID.utf8) == Data(goalID.rawValue.utf8)
            }) else { return searchDestinationUnavailable("Execution Goal observation") }
            if item.link.ticketID != nil {
                await openWorkspaceExecutionGoal(item)
            } else {
                workspaceGoalsDomain = .execution
                workspaceGoalsProjectID = item.project.id
                workspaceGoalsExecutionStatus = nil
                workspaceGoalsExecutionScope = .unlinked
                selectedWorkspaceDeliveryGoalID = nil
                await navigate(to: .goals)
                guard selection == .goals else { return }
                setWorkspaceGoalsDomain(.execution)
                selectWorkspaceExecutionGoal(item.id)
            }
        case let .ticket(projectID, _, ticketID, phaseID):
            if let phaseID, dashboard?.board(for: projectID, phaseID: phaseID)?.detail(for: ticketID) != nil {
                let expectedNavigationGeneration = navigationGeneration &+ 1
                await navigate(to: .phaseBoard(projectID))
                guard lastCommittedNavigationGeneration == expectedNavigationGeneration,
                      selection == .phaseBoard(projectID) else { return }
                viewPhase(projectID: projectID, phaseID: phaseID)
                selectTicket(ticketID)
            } else if dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil {
                let expectedNavigationGeneration = navigationGeneration &+ 1
                await navigate(to: .projectPlan(projectID))
                guard lastCommittedNavigationGeneration == expectedNavigationGeneration,
                      selection == .projectPlan(projectID) else { return }
                selectTicket(ticketID)
            } else {
                searchDestinationUnavailable("ticket")
            }
        case let .decisionReference(projectID, _, ticketID, linkID, version, _, _):
            guard dashboard?.plan(for: projectID)?.detail(for: ticketID) != nil
                    || dashboard?.boards.values.contains(where: {
                        $0.project.id == projectID && $0.detail(for: ticketID) != nil
                    }) == true else { return searchDestinationUnavailable("decision reference") }
            await openReferenceSource(projectID: projectID, ticketID: ticketID, linkID: linkID, version: version)
        case let .history(projectID, registrationID, source, sourceID):
            guard let item = projectActivities[projectID]?.items.first(where: {
                $0.identity.registrationID == registrationID
                    && $0.identity.source == source.activitySource
                    && Data($0.identity.sourceID.utf8) == Data(sourceID.utf8)
            }) else { return searchDestinationUnavailable("History event") }
            historyFilters[Data(projectID.rawValue.utf8)] = historyFilter(for: source)
            await navigate(to: .activity(projectID))
            guard selection == .activity(projectID) else { return }
            selectHistoryEvent(item.identity, projectID: projectID)
        }
    }

    private var canEditSupportedWorkspaceSearch: Bool {
        guard !workspaceSearchPreferenceIsUnsupported else {
            workspaceSearchPersistenceMessage = "Reset the newer-version working search or open a supported saved query before changing its filters."
            return false
        }
        return true
    }

    private var canExecuteWorkspaceSearch: Bool {
        guard !workspaceSearchPreferenceIsUnsupported else {
            workspaceSearchPersistenceMessage = "Reset the newer-version working search or open a supported saved query before running or saving it."
            return false
        }
        guard !workspaceSearchNeedsScopeReselection else {
            workspaceSearchFailure = WorkspaceSearchError.authorizationRequired.localizedDescription
            return false
        }
        return true
    }

    private func invalidateWorkspaceSearchRun(clearProjection: Bool = true) {
        workspaceSearchGeneration &+= 1
        workspaceSearchIsLoading = false
        if clearProjection {
            workspaceSearchProjection = nil
            selectedWorkspaceSearchResultID = nil
        }
    }

    private func registrationIdentity(
        _ lhs: WorkspaceSearchRegistrationIdentity,
        matches rhs: WorkspaceSearchRegistrationIdentity
    ) -> Bool {
        lhs.projectID.rawValue.utf8.elementsEqual(rhs.projectID.rawValue.utf8)
            && lhs.registrationID.utf8.elementsEqual(rhs.registrationID.utf8)
    }

    private func historyFilter(for source: WorkspaceSearchHistorySource) -> HistoryFilter {
        switch source {
        case .audit: .audit
        case .review: .reviews
        case .completion: .completions
        case .observation: .observations
        case .notification: .notifications
        }
    }

    func openWorkspaceHelpDestination(_ destination: WorkspaceHelpDestination) async {
        switch destination {
        case .projects: await navigate(to: .projects)
        case .settings: await navigate(to: .settings)
        case .search: await navigate(to: .search)
        case .goals: await navigate(to: .goals)
        case .projectOverview: await navigate(to: .projectOverview(currentProjectID))
        case .projectPlan: await navigate(to: .projectPlan(currentProjectID))
        case .phaseBoard: await navigate(to: .phaseBoard(currentProjectID))
        case .history: await navigate(to: .activity(currentProjectID))
        }
    }

    private func registrationMatchingSearchResult(_ result: WorkspaceSearchResult) -> ProjectRegistration? {
        let expected = ProjectRegistration(
            projectID: result.project.projectID,
            registrationID: result.project.registrationID,
            requestGeneration: 0
        )
        return dashboard?.projects.compactMap(\.registration).first(where: {
            $0.hasSameNavigationIdentity(as: expected)
        }) ?? dashboard?.archivedProjects.map(\.registration).first(where: {
            $0.hasSameNavigationIdentity(as: expected)
        }) ?? dashboard?.removedProjects.map(\.registration).first(where: {
            $0.hasSameNavigationIdentity(as: expected)
        })
    }

    private func searchDestinationUnavailable(_ kind: String) {
        navigationRecoveryMessage = "The exact \(kind) is unavailable; a different record was not substituted."
        navigationFocus = .recovery
        captureCurrentNavigationContext()
    }

    func setWorkspaceGoalsDomain(_ domain: WorkspaceGoalsDomain) {
        workspaceGoalsDomain = domain
        navigationFocus = reconcileWorkspaceGoalsSelection().map(NavigationFocus.workspaceGoal)
            ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    func setWorkspaceGoalsProjectID(_ projectID: ProjectID?) {
        workspaceGoalsProjectID = projectID
        navigationFocus = reconcileWorkspaceGoalsSelection().map(NavigationFocus.workspaceGoal)
            ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    func setWorkspaceGoalsDeliveryLifecycle(_ lifecycle: DeliveryGoalLifecycle?) {
        workspaceGoalsDeliveryLifecycle = lifecycle
        navigationFocus = reconcileWorkspaceGoalsSelection().map(NavigationFocus.workspaceGoal)
            ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    func setWorkspaceGoalsExecutionStatus(_ status: String?) {
        workspaceGoalsExecutionStatus = status
        navigationFocus = reconcileWorkspaceGoalsSelection().map(NavigationFocus.workspaceGoal)
            ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    func setWorkspaceGoalsExecutionScope(_ scope: WorkspaceExecutionScope) {
        workspaceGoalsExecutionScope = scope
        navigationFocus = reconcileWorkspaceGoalsSelection().map(NavigationFocus.workspaceGoal)
            ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    private func reconcileWorkspaceGoalsSelection() -> Data? {
        switch workspaceGoalsDomain {
        case .delivery:
            let goals = filteredWorkspaceDeliveryGoals()
            let selected = selectedWorkspaceDeliveryGoalID.flatMap { selected in
                goals.first(where: { $0.id == selected })?.id
            } ?? goals.first?.id
            selectedWorkspaceDeliveryGoalID = selected
            return selected
        case .execution:
            let goals = filteredWorkspaceExecutionGoals()
            let selected = selectedWorkspaceExecutionGoalID.flatMap { selected in
                goals.first(where: { $0.id == selected })?.id
            } ?? goals.first?.id
            selectedWorkspaceExecutionGoalID = selected
            return selected
        }
    }

    private func filteredWorkspaceDeliveryGoals() -> [WorkspaceDeliveryGoalProjection] {
        guard let goals = dashboard?.workspaceGoals.delivery else { return [] }
        return goals.filter { goal in
            (workspaceGoalsProjectID == nil || workspaceGoalsProjectID.map {
                $0.rawValue.utf8.elementsEqual(goal.project.id.rawValue.utf8)
            } == true)
                && (workspaceGoalsDeliveryLifecycle == nil
                    || goal.goal.lifecycle == workspaceGoalsDeliveryLifecycle)
        }
    }

    private func filteredWorkspaceExecutionGoals() -> [WorkspaceExecutionGoalProjection] {
        guard let goals = dashboard?.workspaceGoals.execution else { return [] }
        return goals.filter { goal in
            let projectMatches = workspaceGoalsProjectID == nil || workspaceGoalsProjectID.map {
                $0.rawValue.utf8.elementsEqual(goal.project.id.rawValue.utf8)
            } == true
            let statusMatches = workspaceGoalsExecutionStatus == nil
                || goal.status == workspaceGoalsExecutionStatus
            let linkMatches = workspaceGoalsExecutionScope == .all
                || (workspaceGoalsExecutionScope == .linked) == (goal.link.ticketID != nil)
            return projectMatches && statusMatches && linkMatches
        }
    }

    func selectWorkspaceDeliveryGoal(_ id: Data?) {
        selectedWorkspaceDeliveryGoalID = id
        navigationFocus = id.map(NavigationFocus.workspaceGoal) ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    func selectWorkspaceExecutionGoal(_ id: Data?) {
        selectedWorkspaceExecutionGoalID = id
        navigationFocus = id.map(NavigationFocus.workspaceGoal) ?? .workspaceGoalsFilter
        captureCurrentNavigationContext()
    }

    func setWorkspaceGoalsViewportOffset(_ offset: Double?) {
        workspaceGoalsViewportOffset = offset.map { max(0, $0) }
        captureCurrentNavigationContext()
    }

    func openWorkspaceDeliveryGoal(_ item: WorkspaceDeliveryGoalProjection) async {
        await navigate(to: .phaseBoard(item.project.id))
        viewAllPhases(projectID: item.project.id)
        setAllPhaseBoardFilter(.goal(item.goal.goalID), projectID: item.project.id)
        if let ticketID = item.goal.ticketIDs.first {
            selectTicket(ticketID)
        }
    }

    func openWorkspaceDeliveryGoalPlanning(_ item: WorkspaceDeliveryGoalProjection) async {
        workspaceDeliveryGoalPlanningTargets[item.project.id] = .init(
            phaseID: item.phaseID, goalID: item.goal.goalID
        )
        await navigate(to: .projectPlan(item.project.id))
    }

    func openWorkspaceProjectPlanning(_ projectID: ProjectID) async {
        await navigate(to: .projectPlan(projectID))
    }

    func takeWorkspaceDeliveryGoalPlanningTarget(for projectID: ProjectID) -> DeliveryGoalEditorTarget? {
        workspaceDeliveryGoalPlanningTargets.removeValue(forKey: projectID)
    }

    func openWorkspaceUnassignedWork(_ item: WorkspaceUnassignedDeliveryWorkProjection) async {
        if item.phaseID == nil {
            await navigate(to: .projectPlan(item.project.id))
        } else {
            await navigate(to: .phaseBoard(item.project.id))
            viewAllPhases(projectID: item.project.id)
            setAllPhaseBoardFilter(.unassigned, projectID: item.project.id)
        }
        if let ticketID = item.tickets.first?.id {
            selectTicket(ticketID)
        }
    }

    func openWorkspaceExecutionGoal(_ item: WorkspaceExecutionGoalProjection) async {
        guard let ticketID = item.link.ticketID else { return }
        await navigate(to: .phaseBoard(item.project.id))
        viewAllPhases(projectID: item.project.id)
        setAllPhaseBoardFilter(
            .execution(.init(threadID: item.threadID, goalID: item.goalID, ticketID: ticketID)),
            projectID: item.project.id
        )
        selectTicket(ticketID)
    }

    func selectedHistoryEventID(for projectID: ProjectID) -> HistoryEventIdentity? {
        selectedHistoryEventIDs[Data(projectID.rawValue.utf8)]
    }

    func historyViewportOffset(for projectID: ProjectID) -> Double? {
        historyViewportOffsets[Data(projectID.rawValue.utf8)]
    }

    func setHistoryViewportOffset(_ offset: Double?, projectID: ProjectID) {
        let key = Data(projectID.rawValue.utf8)
        if let offset { historyViewportOffsets[key] = max(0, offset) }
        else { historyViewportOffsets.removeValue(forKey: key) }
        captureCurrentNavigationContext()
    }

    func setHistoryFilter(_ filter: HistoryFilter, projectID: ProjectID) {
        let key = Data(projectID.rawValue.utf8)
        historyFilters[key] = filter
        if let selected = selectedHistoryEventIDs[key],
           activity(for: projectID)?.items.first(where: { $0.identity == selected }).map({ !filter.includes($0.source) }) == true {
            selectedHistoryEventIDs.removeValue(forKey: key)
        }
        navigationFocus = selectedHistoryEventIDs[key].map(NavigationFocus.historyEvent) ?? .filterSummary
        captureCurrentNavigationContext()
    }

    func selectHistoryEvent(_ eventID: HistoryEventIdentity?, projectID: ProjectID) {
        let key = Data(projectID.rawValue.utf8)
        if let eventID {
            selectedHistoryEventIDs[key] = eventID
            navigationFocus = .historyEvent(eventID)
        } else {
            selectedHistoryEventIDs.removeValue(forKey: key)
            navigationFocus = .filterSummary
        }
        captureCurrentNavigationContext()
    }

    func openHistoryEntity(_ item: ProjectActivityItem) async {
        let projectID = item.identity.projectID
        guard let currentRegistration = registration(for: .activity(projectID)),
              item.identity.registrationID == currentRegistration.registrationID else {
            navigationRecoveryMessage = "The event belongs to an unavailable project registration; a replacement registration was not opened."
            navigationFocus = .recovery
            captureCurrentNavigationContext()
            return
        }
        if item.source == .audit, item.eventFacts == nil {
            navigationRecoveryMessage = "The event target identity was not recorded; current project state was not substituted for the past."
            navigationFocus = .recovery
            captureCurrentNavigationContext()
            return
        }
        let ticketID = item.eventFacts?.ticketID ?? item.ticketID
        let preferredPhaseID = item.eventFacts?.currentPhaseID ?? item.eventFacts?.phaseID ?? item.phaseID
        let target: (phaseID: PhaseID, ticketID: TicketID)? = ticketID.flatMap { ticketID in
            if let preferredPhaseID,
               dashboard?.board(for: projectID, phaseID: preferredPhaseID)?.detail(for: ticketID) != nil {
                return (preferredPhaseID, ticketID)
            }
            return dashboard?.boards.first(where: {
                $0.key.projectID == projectID && $0.value.detail(for: ticketID) != nil
            }).map { ($0.key.phaseID, ticketID) }
        }
        guard let target else {
            navigationRecoveryMessage = "The exact event target is unavailable; no replacement entity was opened."
            navigationFocus = .recovery
            captureCurrentNavigationContext()
            return
        }
        await navigate(to: .phaseBoard(projectID))
        guard selection == .phaseBoard(projectID) else { return }
        viewPhase(projectID: projectID, phaseID: target.phaseID)
        selectTicket(target.ticketID)
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

    func loadTicketDeliveryEvidence(
        projectID: ProjectID,
        ticketID: TicketID
    ) async -> ReferenceLoadResult<TicketDeliveryEvidence> {
        let serviceGeneration = documentationServiceGeneration
        let currentStore = store
        let currentObserver = documentationObserver
        guard let root = projectRoots[projectID],
              case let .observed(observation) = currentObserver.status(for: projectID),
              let rootID = observation.identity.rootID?.rawValue else {
            return .failed(.init(
                title: "Delivery evidence unavailable",
                detail: "Restore this project's exact documentation root and reload before reading revision-bound evidence.",
                systemImage: "questionmark.folder",
                tone: .warning,
                accessibilityID: "delivery-evidence-query-unavailable"
            ))
        }
        let result = await AgentQueryDispatcher(
            store: currentStore,
            bookmarkStore: deliveryEvidenceBookmarkStore
        ).dispatch(.init(
            version: 1,
            projectRoot: root.path,
            query: .ticketDeliveryEvidence(
                projectID: projectID.rawValue,
                rootID: rootID,
                ticketID: ticketID.rawValue
            )
        ))
        guard !Task.isCancelled,
              serviceGeneration == documentationServiceGeneration,
              currentStore === store,
              currentObserver === documentationObserver,
              currentObserver.status(for: projectID) == .observed(observation),
              projectRoots[projectID]?.path == root.path else {
            return .failed(.init(
                title: "Delivery evidence context changed",
                detail: "The project registration, root, or selected ticket changed while evidence was loading. Reload the current ticket; no alternate evidence was selected.",
                systemImage: "arrow.clockwise",
                tone: .warning,
                accessibilityID: "delivery-evidence-query-withdrawn"
            ))
        }
        if let evidence = result.deliveryEvidence { return .loaded(evidence) }
        if let error = result.error, let presentation = FailureStatePresentation(agentError: error) {
            return .failed(presentation)
        }
        return .failed(.init(
            title: "Delivery evidence unavailable",
            detail: "The exact recorded evidence could not be read. No replacement target, source, or ticket was selected.",
            systemImage: "exclamationmark.triangle",
            tone: .warning,
            accessibilityID: "delivery-evidence-query-failed"
        ))
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

    func referenceQueryContextIdentity(projectID: ProjectID) -> String {
        let identity = documentationObserver.status(for: projectID)?.identity
        let registration = identity?.registration
        let binding = identity?.binding
        return [projectID.rawValue, String(documentationServiceGeneration),
                registration?.registrationID ?? "no-registration",
                registration.map { String($0.requestGeneration) } ?? "no-request-generation",
                identity?.rootID?.rawValue ?? "no-root",
                identity?.rootPath ?? projectRoots[projectID]?.path ?? "no-root-path",
                binding?.repositoryID ?? "no-repository",
                binding.map { String($0.acceptedCatalogVersion) } ?? "no-catalog-version",
                binding?.acceptedCatalogDigest ?? "no-catalog-digest"].joined(separator: ":")
    }

    func isReferenceQueryReady(projectID: ProjectID) -> Bool {
        guard let root = projectRoots[projectID],
              case let .observed(observation) = documentationObserver.status(for: projectID),
              observation.identity.rootID != nil,
              observation.identity.rootPath == root.path else { return false }
        return true
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

    func loadCodexExecutionContext() {
        codexContextFailure = nil
        do {
            let files = try ProjectExecutionFileStore(root: ProjectExecutionFileStore.applicationRoot(), create: false)
            guard let context = try files.codexContext() else {
                codexContextPath = nil; codexContextSelectedAt = nil; codexContextStatus = "Selection required"
                return
            }
            codexContextPath = context.homePath; codexContextSelectedAt = context.selectedAt
            let access = try CodexExecutionContextLease(context: context, current: { try files.codexContext() })
            defer { access.release() }
            try access.validate()
            codexContextStatus = "Folder access ready"
        } catch {
            codexContextStatus = "Access needs attention"
            codexContextFailure = CodexExecutionContextError.accessRequired.localizedDescription
        }
    }

    /// Explicit folder selection writes only the machine-local protected receipt.
    func selectCodexExecutionContext(folder: URL) async {
        guard !codexContextSelectionInFlight else { return }
        codexContextSelectionInFlight = true; defer { codexContextSelectionInFlight = false }
        codexContextMessage = nil; codexContextFailure = nil
        guard folder.startAccessingSecurityScopedResource() else {
            codexContextStatus = "Access needs attention"
            codexContextFailure = CodexExecutionContextError.accessRequired.localizedDescription
            return
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let bookmark = try ProjectBookmarkStore().makeBookmark(for: folder)
            let files = try ProjectExecutionFileStore(root: ProjectExecutionFileStore.applicationRoot(), create: true)
            let previous = try files.codexContext()
            let candidate = try CodexExecutionContext(home: folder, bookmark: bookmark, previousContextID: previous?.id)
            // Reselecting the same physical folder restores its grant without migrating assignments.
            let selected = if let previous, previous.identifiesSameFolder(as: candidate) {
                try CodexExecutionContext(home: folder, bookmark: bookmark, id: previous.id, previousContextID: previous.previousContextID)
            } else { candidate }
            try await store.transact(actor: .init(id: "owner"), reason: "Owner authorized Codex context selection request \(selected.id.uuidString); protected folder receipt save pending.") { _ in }
            try files.saveCodexContext(selected, expected: previous)
            loadCodexExecutionContext()
            codexContextMessage = "Codex folder selection saved on this Mac. Review each project's execution hook setup to regenerate Release Radar configuration. Existing reserved or uncertain assignments remain blocked."
        } catch {
            codexContextStatus = "Access needs attention"
            codexContextFailure = "Codex folder selection could not be saved. \(error.localizedDescription)"
        }
    }

    func executionSetupForOnboarding() -> ProjectExecutionSetupCoordinator {
        ProjectExecutionSetupClient.setup(plugin: codexPluginCoordinator)
    }

    func manageExecutionHook(registration: ProjectRegistration, action: ProjectExecutionHookAction) async throws {
        try await projectOnboarding.manageExecutionHook(registration: registration, action: action, setup: executionSetupForOnboarding())
        _ = await reloadProjectProjections()
    }

    func executionAssignments(registration: ProjectRegistration) async throws -> [ProjectExecutionAssignment] {
        try await projectOnboarding.executionAssignments(registration: registration, resources: executionResourcesForOwner())
    }

    func retireExecutionAssignment(registration: ProjectRegistration, expected: ProjectExecutionAssignment) async throws {
        let folder: URL?
        if try await projectOnboarding.executionResourcesNeedOriginalFolder(registration: registration, expected: expected) {
            guard let originalRoot = expected.worktree?.primaryRoot else { throw ProjectExecutionError.invalidAssignment }
            let panel = ProjectFolderAccessPanel.make()
            panel.message = "Restore access to this worker's exact original repository to retire its owned resources: \(originalRoot). The project's current folder will remain unchanged."
            panel.prompt = "Authorize Cleanup"
            guard panel.runModal() == .OK, let selected = panel.url else { throw StoreError.unavailable("Resource retirement was cancelled. The old resources and outcome were preserved.") }
            folder = selected
        } else { folder = nil }
        try await projectOnboarding.retireExecutionAssignment(registration: registration, expected: expected, resourceFolder: folder, resources: executionResourcesForOwner())
        _ = await reloadProjectProjections()
    }

    func recoverLostWorker(registration: ProjectRegistration,
                           expected: ProjectExecutionAssignment) async throws {
        try await projectOnboarding.recoverLostWorker(registration: registration,
            expected: expected, resources: executionResourcesForOwner())
        _ = await reloadProjectProjections()
    }

    private func executionResourcesForOwner() -> ProjectExecutionResourceLifecycle {
        if let executionResourceLifecycle { return executionResourceLifecycle }
        let resources = ProjectExecutionSetupClient.resources(plugin: codexPluginCoordinator)
        executionResourceLifecycle = resources
        return resources
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
        if let key = dependencySessionKey(for: selection) {
            if ticketID.rawValue.isEmpty {
                dependencyFocusIDs.removeValue(forKey: key)
            } else {
                dependencyFocusIDs[key] = ticketID
            }
        }
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

    func loadDeliveryGoalEditor(
        projectID: ProjectID,
        phaseID: PhaseID,
        goalID: DeliveryGoalID?
    ) async -> DeliveryGoalEditorLoadOutcome {
        do {
            let generator = requestIDGenerator
            let snapshot = try await store.read { connection -> DeliveryGoalEditorSnapshot in
                guard let plan = try DeliveryPlanningPolicy.loadPlan(
                    projectID: projectID, phaseID: phaseID, connection: connection
                ) else { throw DeliveryPlanningPolicyError.phasePlanNotFound }
                let phaseLifecycle = try PhaseLifecyclePolicy.current(
                    projectID: projectID, phaseID: phaseID, connection: connection
                )
                guard phaseLifecycle.lifecycle != .completed else {
                    throw PhaseLifecyclePolicyError.completedPhaseReadOnly(phaseID)
                }
                let goals = try DeliveryPlanningPolicy.loadGoals(
                    projectID: projectID, phaseID: phaseID, connection: connection
                )
                if let goalID {
                    guard let goal = try DeliveryPlanningPolicy.loadGoal(
                        projectID: projectID, goalID: goalID, connection: connection
                    ), goal.phaseID == phaseID else {
                        throw DeliveryPlanningPolicyError.goalNotFound(goalID)
                    }
                    guard goal.lifecycle != .accepted, goal.lifecycle != .superseded else {
                        throw DeliveryPlanningPolicyError.goalNotActionable(goalID)
                    }
                    let criteria = try DeliveryPlanningPolicy.loadCriteria(
                        projectID: projectID, phaseID: phaseID, goalID: goalID, connection: connection
                    ).map(\.text)
                    return .init(
                        projectID: projectID, phaseID: phaseID, planRevision: plan.revision,
                        phaseLifecycle: phaseLifecycle.lifecycle, goalLifecycle: goal.lifecycle,
                        draft: .init(id: goalID, title: goal.title, outcome: goal.outcome,
                                     doneCriteria: criteria, sortOrder: goal.sortOrder)
                    )
                }
                let maximum = goals.map(\.sortOrder).max()
                let order: Int
                if let maximum {
                    guard maximum < Int.max else {
                        throw DeliveryPlanningPolicyError.invalidPlanMutation(
                            "Delivery Goal order cannot advance further. Edit an existing goal instead."
                        )
                    }
                    order = maximum + 1
                } else {
                    order = 0
                }
                return .init(
                    projectID: projectID, phaseID: phaseID, planRevision: plan.revision,
                    phaseLifecycle: phaseLifecycle.lifecycle, goalLifecycle: nil,
                    draft: .init(id: .init(rawValue: generator().uuidString.lowercased()), title: "", outcome: "",
                                 doneCriteria: [""], sortOrder: order)
                )
            }
            return .loaded(snapshot)
        } catch {
            return .failed(deliveryGoalEditorError(error))
        }
    }

    func saveDeliveryGoalDraft(
        projectID: ProjectID,
        phaseID: PhaseID,
        expectedRevision: Int64,
        draft: DeliveryGoalDraft
    ) async -> DeliveryGoalDraftSaveOutcome {
        let attemptID = requestIDGenerator()
        let key = DeliveryGoalDraftSaveKey(projectID: projectID, phaseID: phaseID)
        guard pendingDeliveryGoalDraftSaveIDs[key] == nil else {
            return .init(attemptID: attemptID, status: .unconfirmed(error: .outcomeUnknown))
        }
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draft.doneCriteria.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else {
            return .init(attemptID: attemptID, status: .rejected(
                error: .invalidPlanMutation("Enter a title, intended outcome, and at least one done criterion."),
                refreshedEditor: nil
            ))
        }
        guard let registration = dashboard?.projects.first(where: { $0.id == projectID })?.registration else {
            return .init(attemptID: attemptID, status: .rejected(error: .staleProjectRegistration, refreshedEditor: nil))
        }
        let command: AgentCommand = .applyPhasePlanRevision(
            projectID: projectID.rawValue, phaseID: phaseID.rawValue, expectedRevision: expectedRevision,
            goalUpserts: [draft]
        )
        let root: String
        do {
            root = try await projectOnboarding.withAuthorizedProject(projectID: projectID) { $0.canonicalRoot.path }
        } catch {
            return .init(attemptID: attemptID, status: .rejected(error: .unauthorizedProjectRoot, refreshedEditor: nil))
        }
        let pending = PendingDeliveryGoalDraftSave(
            envelope: .init(
                version: AgentCommandDispatcher.commandEnvelopeVersion, requestID: attemptID,
                projectRoot: root, expectedRegistration: registration,
                reason: "Owner saved Delivery Goal draft", command: command
            ),
            projectID: projectID, phaseID: phaseID, registration: registration,
            draft: draft, expectedRevision: expectedRevision, error: .outcomeUnknown
        )
        return await resolveDeliveryGoalDraftSave(pending, key: key)
    }

    func reconcileDeliveryGoalDraftSave(attemptID: UUID) async -> DeliveryGoalDraftSaveOutcome {
        guard let pending = pendingDeliveryGoalDraftSaves[attemptID] else {
            return .init(attemptID: attemptID, status: .rejected(error: .outcomeUnknown, refreshedEditor: nil))
        }
        let key = DeliveryGoalDraftSaveKey(projectID: pending.projectID, phaseID: pending.phaseID)
        guard dashboard?.projects.first(where: { $0.id == key.projectID })?.registration == pending.registration else {
            removePendingDeliveryGoalDraftSave(attemptID, key: key)
            return .init(attemptID: attemptID, status: .rejected(error: .staleProjectRegistration, refreshedEditor: nil))
        }
        return await resolveDeliveryGoalDraftSave(pending, key: key)
    }

    func deliveryGoalDraftSaveRecovery(
        projectID: ProjectID,
        phaseID: PhaseID
    ) -> DeliveryGoalDraftSaveRecovery? {
        let key = DeliveryGoalDraftSaveKey(projectID: projectID, phaseID: phaseID)
        guard let attemptID = pendingDeliveryGoalDraftSaveIDs[key],
              let pending = pendingDeliveryGoalDraftSaves[attemptID] else { return nil }
        return .init(attemptID: attemptID, draft: pending.draft,
                     expectedRevision: pending.expectedRevision, error: pending.error)
    }

    private func resolveDeliveryGoalDraftSave(
        _ pending: PendingDeliveryGoalDraftSave,
        key: DeliveryGoalDraftSaveKey
    ) async -> DeliveryGoalDraftSaveOutcome {
        let attemptID = pending.envelope.requestID
        let result = await deliveryGoalDraftOwnerCommandDispatch(
            key.projectID, pending.registration, attemptID, pending.envelope.command
        )
        if let error = result.error {
            if error == .outcomeUnknown || error == .appUnavailable {
                var retained = pending
                retained.error = error
                pendingDeliveryGoalDraftSaves[attemptID] = retained
                pendingDeliveryGoalDraftSaveIDs[key] = attemptID
                return .init(attemptID: attemptID, status: .unconfirmed(error: error))
            }
            let refreshed = await currentDeliveryGoalEditor(projectID: key.projectID, phaseID: key.phaseID,
                                                             goalID: pending.draft.id)
            removePendingDeliveryGoalDraftSave(attemptID, key: key)
            return .init(attemptID: attemptID, status: .rejected(error: error, refreshedEditor: refreshed))
        }
        guard let revision = result.phasePlanRevision, let auditEventID = result.auditEventID else {
            removePendingDeliveryGoalDraftSave(attemptID, key: key)
            return .init(attemptID: attemptID, status: .rejected(
                error: .internalFailure("Delivery Goal save returned no revision or audit receipt."),
                refreshedEditor: nil
            ))
        }
        removePendingDeliveryGoalDraftSave(attemptID, key: key)
        guard await reloadProjectProjections(context: .ownerDeliveryGoalCommitted(key.projectID)) == .published,
              let readback = await currentDeliveryGoalEditor(projectID: key.projectID, phaseID: key.phaseID,
                                                              goalID: pending.draft.id) else {
            return .init(attemptID: attemptID, status: .savedNeedsReload(savedRevision: revision, auditEventID: auditEventID))
        }
        return .init(attemptID: attemptID, status: .confirmed(
            savedRevision: revision, auditEventID: auditEventID, readback: readback
        ))
    }

    private func currentDeliveryGoalEditor(
        projectID: ProjectID, phaseID: PhaseID, goalID: DeliveryGoalID
    ) async -> DeliveryGoalEditorSnapshot? {
        guard case let .loaded(snapshot) = await loadDeliveryGoalEditor(
            projectID: projectID, phaseID: phaseID, goalID: goalID
        ) else { return nil }
        return snapshot
    }

    private func removePendingDeliveryGoalDraftSave(_ attemptID: UUID, key: DeliveryGoalDraftSaveKey) {
        pendingDeliveryGoalDraftSaves.removeValue(forKey: attemptID)
        pendingDeliveryGoalDraftSaveIDs.removeValue(forKey: key)
    }

    private func deliveryGoalEditorError(_ error: Error) -> AgentCommandError {
        if let error = error as? DeliveryPlanningPolicyError {
            switch error {
            case .phasePlanNotFound: return .phasePlanNotFound
            case let .planRevisionConflict(expected, current): return .planRevisionConflict(expected: expected, current: current)
            case let .goalNotFound(id): return .goalNotFound(id)
            case let .goalNotActionable(id): return .goalNotActionable(id)
            case let .invalidPlanMutation(message): return .invalidPlanMutation(message)
            default: return .internalFailure(error.localizedDescription)
            }
        }
        if let error = error as? PhaseLifecyclePolicyError,
           case let .completedPhaseReadOnly(phaseID) = error {
            return .completedPhaseReadOnly(phaseID)
        }
        return .internalFailure(error.localizedDescription)
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

    func reorderTicket(
        projectID: ProjectID,
        ticketID: TicketID,
        expectedLane: TicketLane,
        anchor: TicketOrderAnchor,
        expectedOrderingContext: TicketOrderingContext
    ) async -> AgentCommandResult {
        let projectIdentity = Data(projectID.rawValue.utf8)
        guard let expectedRegistration = dashboard?.projects.first(where: {
            Data($0.id.rawValue.utf8) == projectIdentity
        })?.registration else {
            return .init(
                entityIDs: [], auditEventID: nil,
                error: .ticketOrdering(.unavailable(
                    .invalidStoredState("The current project registration is unavailable.")
                ))
            )
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
                        reason: "Owner reordered ticket \(ticketID.rawValue) in \(expectedLane.rawValue)",
                        command: .reorderTicket(
                            projectID: projectID.rawValue,
                            ticketID: ticketID.rawValue,
                            expectedLane: expectedLane,
                            anchor: anchor,
                            expectedOrderingContext: expectedOrderingContext
                        )
                    ),
                    origin: .ownerApp
                )
            }
        } catch {
            return .init(
                entityIDs: [], auditEventID: nil,
                error: .ticketOrdering(.unavailable(
                    .invalidStoredState("The authorized project root is unavailable.")
                ))
            )
        }
    }

    func reloadTicketOrdering(projectID: ProjectID) async -> TicketOrderingContext? {
        guard await reloadProjectProjections() == .published else { return nil }
        return dashboard?.ticketOrderingContext(for: projectID)
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

    func reloadAfterNavigationFailure() async {
        navigationFailureMessage = nil
        await reloadDashboardAfterCommittedAgentCommand()
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
            dependencyGraphs[project.id] = try await dependencyGraphLoader(store, project.id)
            guard let board = dashboard.board(for: project.id) ?? defaultBoard(in: dashboard, for: project.id) else { continue }
            let plan = dashboard.plan(for: project.id)
            let allPhaseBoard = dashboard.allPhaseBoard(for: project.id)
            if project.id == visibleProjectID, selection != .dependencies(project.id) {
                let visibleBoard = viewedBoard(in: dashboard, for: project.id)
                let selectedTicketExists: Bool
                if selection == .projectPlan(project.id) {
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
                } else if selection == .projectPlan(project.id) || selection == .phaseBoard(project.id) {
                    selectedTicketID = self.selectedTicketID
                    if !self.selectedTicketID.rawValue.isEmpty {
                        unavailableSelectedTicketID = self.selectedTicketID
                    }
                }
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
        let previousGoalsSelection: Data? = switch workspaceGoalsDomain {
        case .delivery: selectedWorkspaceDeliveryGoalID
        case .execution: selectedWorkspaceExecutionGoalID
        }
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
        if selection == .goals {
            let selectedIsAvailable = previousGoalsSelection.map { selected in
                switch workspaceGoalsDomain {
                case .delivery: filteredWorkspaceDeliveryGoals().contains(where: { $0.id == selected })
                case .execution: filteredWorkspaceExecutionGoals().contains(where: { $0.id == selected })
                }
            }
            if previousGoalsSelection != nil, selectedIsAvailable == false {
                switch workspaceGoalsDomain {
                case .delivery:
                    selectedWorkspaceDeliveryGoalID = nil
                    navigationRecovery.append("The exact Delivery Goal is unavailable; no replacement goal was selected.")
                case .execution:
                    selectedWorkspaceExecutionGoalID = nil
                    navigationRecovery.append("The exact Execution Goal observation is unavailable; no replacement observation was selected.")
                }
            } else if previousGoalsSelection == nil, let selected = reconcileWorkspaceGoalsSelection() {
                navigationFocus = .workspaceGoal(selected)
            }
        }
        if case let .phaseBoard(projectID) = selection,
           allPhaseBoardProjectIDs.contains(Data(projectID.rawValue.utf8)),
           case let .execution(identity) = allPhaseBoardFilters[Data(projectID.rawValue.utf8)] ?? .all,
           prepared.dashboard.allPhaseBoard(for: projectID)?.hasExactExecutionGoalLink(identity) != true {
            navigationRecovery.append("The exact Execution Goal link is unavailable or was replaced; its ticket was not substituted.")
        }
        if !navigationRecovery.isEmpty {
            navigationRecoveryMessage = navigationRecovery.joined(separator: " ")
            navigationFocus = .recovery
        }
        let activeProjectIDs = Set(prepared.dashboard.projects.map(\.id))
        let activeDependencySessionKeys = Set(prepared.dashboard.projects.map {
            DependencySessionKey(projectID: $0.id, registration: $0.registration)
        })
        dependencyFocusIDs = dependencyFocusIDs.filter { activeDependencySessionKeys.contains($0.key) }
        var retainedDependencyPresentationIdentities = Set(dependencyPresentationOrders.keys)
        retainedDependencyPresentationIdentities.formUnion(dependencyPresentationStatuses.keys)
        retainedDependencyPresentationIdentities.formUnion(loadedDependencyPresentations)
        retainedDependencyPresentationIdentities = Set(retainedDependencyPresentationIdentities.filter { identity in
            activeDependencySessionKeys.contains(.init(
                projectID: identity.projectID,
                registration: identity.registration
            ))
        })
        dependencyPresentationOrders = dependencyPresentationOrders.filter {
            retainedDependencyPresentationIdentities.contains($0.key)
        }
        dependencyPresentationStatuses = dependencyPresentationStatuses.filter {
            retainedDependencyPresentationIdentities.contains($0.key)
        }
        loadedDependencyPresentations = loadedDependencyPresentations.intersection(
            retainedDependencyPresentationIdentities
        )
        dependencyPresentationOperationGenerations = dependencyPresentationOperationGenerations.filter {
            retainedDependencyPresentationIdentities.contains($0.key)
        }
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
        await loadWorkspaceSearchPreferences(runSearch: true)
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

    func restartCodexPluginHelper() async {
        guard codexPluginOperation == nil, let codexPluginCoordinator else { return }
        beginCodexPluginOperation(.restartHelper)
        let result = await codexPluginCoordinator.restartHelper()
        await applyCodexPluginResult(result, operation: .restartHelper)
        guard case .failed = result.state else {
            let message = "Plugin helper restarted. Plugin status refreshed."
            codexPluginSettingsMessage = message
            codexPluginAnnouncement = message
            return
        }
    }

    func refreshConnectorHealth() async {
        guard !connectorHealthChecking else { return }
        connectorHealthChecking = true
        defer { connectorHealthChecking = false }
        do {
            let snapshot: AgentBridgeHealthSnapshot?
            if let connectorHealthLoader {
                snapshot = try await connectorHealthLoader()
            } else {
                snapshot = try await recoveryServices?.refreshAgentBridgeHealth()
            }
            guard let snapshot else {
                applyConnectorConnectionFailure()
                return
            }
            applyConnectorHealthSnapshot(snapshot)
        } catch {
            applyConnectorFailure(error)
        }
    }

    func applyConnectorHealthSnapshot(_ snapshot: AgentBridgeHealthSnapshot) {
        guard connectorHealthSnapshotGeneration ?? 0 <= snapshot.generation else { return }
        connectorHealthSnapshotGeneration = snapshot.generation
        connectorHealthObservedAt = snapshot.observedAt
        if let health = snapshot.health, health.isRegisteredAppConnection {
            applyConnectorHealth(health)
        } else {
            applyConnectorConnectionFailure()
        }
    }

    private func applyConnectorHealth(_ health: BridgeConnectionHealth) {
        connectorHealthStatus = "App bridge: Available"
        connectorHealthDetail = "The app can reach its local bridge. This does not certify every Codex client."
        connectorLastContact = health.lastAuthenticatedToolsContact.map {
            "Last authenticated connector contact: \($0.formatted(date: .abbreviated, time: .shortened))"
        } ?? "Not yet observed"
        connectorHealthAnnouncement = "App bridge available. \(connectorLastContact)"
    }

    private func applyConnectorConnectionFailure() {
        connectorHealthStatus = "Connection failed"
        connectorHealthDetail = "Release Radar is not connected to its bridge. Reopen Release Radar, then check again."
        connectorLastContact = "Not yet observed"
        connectorHealthAnnouncement = "Connection failed. \(connectorHealthDetail)"
    }

    private func applyConnectorFailure(_ error: Error) {
        let mismatch = error.localizedDescription.localizedCaseInsensitiveContains("version mismatch")
        connectorHealthStatus = mismatch ? "Version mismatch" : "Connection failed"
        connectorHealthDetail = mismatch
            ? "The Release Radar app and bridge use different versions. Reopen Release Radar, then check the connection again."
            : "The Release Radar connector could not connect. After updating Release Radar, quit and reopen Codex, then check the connection again. Existing tasks should first reach a safe stopping point."
        connectorLastContact = "Not yet observed"
        connectorHealthAnnouncement = "\(connectorHealthStatus). \(connectorHealthDetail)"
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
