# RR-R9B attributable review package

Generated from the exact pre-edit Git blobs recorded before the serialized RR-R9B Implementer began. This package isolates RR-R9B changes from the accepted dirty baseline; reviewers must evaluate the canonical task brief and current source, not the repository HEAD diff.

## Authority

- Brief: `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-2-brief.md`
- Implementer report: `.superpowers/sdd/2026-08-29-release-radar-active-phase-selection/task-2-report.md`
- RR-R9A is accepted; RR-R9B is implemented but not accepted; RR-R9C/live activation remain closed.

## Exact attributable patch

### `ReleaseRadar/Projects/DashboardProjection.swift`

Pre-edit blob: `dd22d4420bbec72d72c6af862764b3683bb9ffa8`  
Current blob: `a3641b3b45e4a0e7f2483b7a8d547ba168f1c793`

```diff
--- a/ReleaseRadar/Projects/DashboardProjection.swift
+++ b/ReleaseRadar/Projects/DashboardProjection.swift
@@ -41,29 +41,40 @@
                 """,
                 bindings: [.text(OnboardingReviewMarkerKind.pending.rawValue)]
             )
             var projects: [ProjectDashboardProjection] = []
             var boards: [ProjectID: PhaseBoardProjection] = [:]
 
             for projectRow in projectRows {
                 let projectID = ProjectID(rawValue: try projectRow.text("id"))
                 let projectName = try projectRow.text("name")
                 let goalContext = try connection.projectGoalContext(projectID: projectID)
+                let phases = try connection.dashboardRows(
+                    "SELECT id, name FROM phases WHERE project_id = ? ORDER BY name COLLATE NOCASE, id",
+                    bindings: [.text(projectID.rawValue)]
+                ).map {
+                    ProjectPhaseProjection(
+                        id: PhaseID(rawValue: try $0.text("id")),
+                        name: try $0.text("name")
+                    )
+                }
                 guard let activePhaseID = try projectRow.nullableText("active_phase_id"),
                       let phaseRow = try connection.row(
                         "SELECT id, name FROM phases WHERE project_id = ? AND id = ?",
                         bindings: [.text(projectID.rawValue), .text(activePhaseID)]
                       ) else {
                     projects.append(.init(
                         id: projectID,
                         name: projectName,
+                        activePhaseID: nil,
                         activePhaseName: "No active phase",
+                        phases: phases,
                         goalContext: goalContext,
                         currentWorkCount: 0,
                         attentionCount: 0
                     ))
                     continue
                 }
 
                 let phaseID = PhaseID(rawValue: try phaseRow.text("id"))
                 let ticketRows = try connection.dashboardRows(
                     "SELECT id, outcome, lane FROM tickets WHERE project_id = ? AND phase_id = ? ORDER BY rowid",
@@ -105,46 +116,75 @@
                 }
                 let currentWorkCount = lanes
                     .filter { $0.lane != .accepted }
                     .reduce(0) { $0 + $1.count }
                 let attentionCount = lanes
                     .filter { $0.lane == .needsReview || $0.lane == .blocked }
                     .reduce(0) { $0 + $1.count }
                 let project = ProjectDashboardProjection(
                     id: projectID,
                     name: projectName,
+                    activePhaseID: phaseID,
                     activePhaseName: try phaseRow.text("name"),
+                    phases: phases,
                     goalContext: goalContext,
                     currentWorkCount: currentWorkCount,
                     attentionCount: attentionCount
                 )
                 projects.append(project)
                 boards[projectID] = PhaseBoardProjection(
                     project: project,
                     phaseID: phaseID,
                     lanes: lanes,
                     details: details
                 )
             }
 
             return DashboardProjection(projects: projects, boards: boards)
         }
     }
 }
 
+struct ProjectPhaseProjection: Equatable, Sendable, Identifiable {
+    let id: PhaseID
+    let name: String
+}
+
 struct ProjectDashboardProjection: Equatable, Sendable, Identifiable {
     let id: ProjectID
     let name: String
+    let activePhaseID: PhaseID?
     let activePhaseName: String
+    let phases: [ProjectPhaseProjection]
     let goalContext: GoalContextProjection
     let currentWorkCount: Int
     let attentionCount: Int
+
+    init(
+        id: ProjectID,
+        name: String,
+        activePhaseID: PhaseID? = nil,
+        activePhaseName: String,
+        phases: [ProjectPhaseProjection] = [],
+        goalContext: GoalContextProjection,
+        currentWorkCount: Int,
+        attentionCount: Int
+    ) {
+        self.id = id
+        self.name = name
+        self.activePhaseID = activePhaseID
+        self.activePhaseName = activePhaseName
+        self.phases = phases
+        self.goalContext = goalContext
+        self.currentWorkCount = currentWorkCount
+        self.attentionCount = attentionCount
+    }
 }
 
 struct PhaseBoardProjection: Equatable, Sendable {
     let project: ProjectDashboardProjection
     let phaseID: PhaseID
     let lanes: [DashboardLaneProjection]
     let details: [TicketID: TicketDetailProjection]
 
     func lane(_ lane: TicketLane) -> DashboardLaneProjection? {
         lanes.first { $0.lane == lane }
```

### `ReleaseRadar/App/ReleaseRadarApp.swift`

Pre-edit blob: `a9456643bfb74951c369de3a29d3eeed50ac7aed`  
Current blob: `640233363d2dd1081c41510a244470b5124b3da6`

```diff
--- a/ReleaseRadar/App/ReleaseRadarApp.swift
+++ b/ReleaseRadar/App/ReleaseRadarApp.swift
@@ -5,20 +5,37 @@
 
 enum AppLaunchConfiguration {
     static func externalServicesSuppressed(arguments: [String], isDebugBuild: Bool) -> Bool {
         isDebugBuild && arguments.contains("--rr10-capture")
     }
 
     static func shouldSeedSampleData(arguments: [String], isDebugBuild: Bool) -> Bool {
         externalServicesSuppressed(arguments: arguments, isDebugBuild: isDebugBuild)
             && !arguments.contains("--rr10-empty-store")
     }
+
+#if DEBUG
+    static func rr9ActivePhaseCaptureScenario(
+        arguments: [String],
+        isDebugBuild: Bool
+    ) -> RR9ActivePhaseCaptureScenario? {
+        guard isDebugBuild,
+              arguments.contains("--rr10-capture"),
+              arguments.contains("--rr10-empty-store") else { return nil }
+        let prefix = "--rr9-active-phase-fixture="
+        let scenarioArguments = arguments.filter { $0.hasPrefix(prefix) }
+        guard scenarioArguments.count == 1 else { return nil }
+        return RR9ActivePhaseCaptureScenario(
+            rawValue: String(scenarioArguments[0].dropFirst(prefix.count))
+        )
+    }
+#endif
 }
 
 @MainActor
 final class AppDelegate: NSObject, NSApplicationDelegate {
     private let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "AgentBridge")
     private var agentBridgeHost: AgentBridgeApplicationHost?
 
     func applicationDidFinishLaunching(_ notification: Notification) {
         NSApp.setActivationPolicy(.regular)
         NSApp.activate(ignoringOtherApps: true)
@@ -91,29 +108,46 @@
 #endif
         let arguments = ProcessInfo.processInfo.arguments
         let externalServicesSuppressed = AppLaunchConfiguration.externalServicesSuppressed(
             arguments: arguments,
             isDebugBuild: isDebugBuild
         )
         let seedSampleData = AppLaunchConfiguration.shouldSeedSampleData(
             arguments: arguments,
             isDebugBuild: isDebugBuild
         )
-        _model = State(initialValue: AppModel(
+#if DEBUG
+        let model = AppModel(
             store: services.store,
             codexPluginCoordinator: services.codexPluginCoordinator,
             codexPluginShippedVersion: services.codexPluginShippedVersion,
             pushoverKeychain: services.keychain,
             notificationCoordinator: services.notificationCoordinator,
             externalServicesSuppressed: externalServicesSuppressed,
+            seedSampleData: seedSampleData,
+            rr9ActivePhaseCaptureScenario: AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+                arguments: arguments,
+                isDebugBuild: true
+            )
+        )
+#else
+        let model = AppModel(
+            store: services.store,
+            codexPluginCoordinator: services.codexPluginCoordinator,
+            codexPluginShippedVersion: services.codexPluginShippedVersion,
+            pushoverKeychain: services.keychain,
+            notificationCoordinator: services.notificationCoordinator,
+            externalServicesSuppressed: externalServicesSuppressed,
             seedSampleData: seedSampleData
-        ))
+        )
+#endif
+        _model = State(initialValue: model)
     }
 
     var body: some Scene {
         WindowGroup("Release Radar", id: "main") {
             SidebarView(model: model)
                 .frame(minWidth: 760, minHeight: 520)
         }
         .defaultSize(width: 1600, height: 820)
         .commands {
             CommandGroup(replacing: .appInfo) {
```

### `ReleaseRadar/App/AppModel.swift`

Pre-edit blob: `a9f656c802eecc5e1f15bee111d4c07b717ec2f0`  
Current blob: `76ccd276c6c9a076fba1f4334fcb1daa7451b777`

```diff
--- a/ReleaseRadar/App/AppModel.swift
+++ b/ReleaseRadar/App/AppModel.swift
@@ -1,19 +1,49 @@
 import Foundation
 import Observation
 import ReleaseRadarCore
 
 enum AttachFolderOutcome: Equatable, Sendable {
     case attached
     case attachedNeedsReload
 }
 
+enum ActivePhaseSelectionStatus: Equatable, Sendable {
+    case idle
+    case saving(PhaseID)
+    case mutationFailed(FailureStatePresentation, canReauthorize: Bool)
+    case savedNeedsReload(PhaseID, String)
+}
+
+private enum ProjectionReloadOutcome: Equatable, Sendable {
+    case published
+    case failed
+    case superseded
+}
+
+private enum ProjectionReloadContext: Equatable, Sendable {
+    case ordinary
+    case ownerActivePhaseCommitted(ProjectID, PhaseID, String)
+    case agentCommandCommitted
+}
+
+private struct PreparedProjectProjections: Sendable {
+    let dashboard: DashboardProjection
+    let reviewInboxes: [ProjectID: ReviewInboxProjection]
+    let dependencyGraphs: [ProjectID: DependencyGraphProjection]
+    let projectActivities: [ProjectID: ProjectActivityProjection]
+    let projectGuidanceStates: [ProjectID: ProjectGuidanceState]
+    let projectRoots: [ProjectID: URL]
+    let selectedTicketID: TicketID
+    let selectedReviewItemID: ReviewItemID?
+}
+
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
@@ -38,66 +68,116 @@
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
+    private let requestIDGenerator: () -> UUID
     private(set) var selectedProjectID: ProjectID?
     private var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
     private var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
     private var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
     private var projectGuidanceStates: [ProjectID: ProjectGuidanceState] = [:]
     private var projectRoots: [ProjectID: URL] = [:]
     private var reviewActionStates: [ProjectID: ReviewActionState] = [:]
+    private var activePhaseSelectionStatuses: [ProjectID: ActivePhaseSelectionStatus] = [:]
     private var performingReviewActionProjectIDs: Set<ProjectID> = []
     private var alertRulesFailureState: AlertRulesFailureState?
     private var didInitializeCodexPluginLifecycle = false
+    private var projectionReloadGeneration: UInt64 = 0
+#if DEBUG
+    private var rr9ActivePhaseCaptureScenario: RR9ActivePhaseCaptureScenario?
+    private var rr9ActivePhaseCaptureRootDirectory: URL?
+    private var rr9SavedRefreshFailureConsumed = false
+#endif
 
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
+        requestIDGenerator: @escaping () -> UUID = { UUID() },
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
+        self.requestIDGenerator = requestIDGenerator
         self.notificationCoordinator = notificationCoordinator
             ?? AppNotificationCoordinator(
                 store: store,
                 dispatcher: PushoverNotificationDispatcher(store: store, credentials: resolvedKeychain)
             )
     }
 
+#if DEBUG
+    convenience init(
+        store: DeliveryStore,
+        codexObserver: any CodexObserver = UnavailableCodexObserver(),
+        codexPluginCoordinator: CodexPluginLifecycleCoordinator? = nil,
+        codexPluginShippedVersion: String = "0.1.0",
+        pushoverKeychain: PushoverKeychainStore? = nil,
+        notificationCoordinator: AppNotificationCoordinator? = nil,
+        projectOnboarding: FolderProjectOnboarding? = nil,
+        reviewInboxLoader: @escaping @Sendable (DeliveryStore, ProjectID) async throws -> ReviewInboxProjection = {
+            try await ReviewInboxProjection.load(from: $0, projectID: $1)
+        },
+        dashboardLoader: @escaping @Sendable (DeliveryStore) async throws -> DashboardProjection = {
+            try await DashboardProjection.load(from: $0)
+        },
+        requestIDGenerator: @escaping () -> UUID = { UUID() },
+        externalServicesSuppressed: Bool = false,
+        seedSampleData: Bool = false,
+        rr9ActivePhaseCaptureScenario: RR9ActivePhaseCaptureScenario?,
+        rr9ActivePhaseCaptureRootDirectory: URL? = nil
+    ) {
+        self.init(
+            store: store,
+            codexObserver: codexObserver,
+            codexPluginCoordinator: codexPluginCoordinator,
+            codexPluginShippedVersion: codexPluginShippedVersion,
+            pushoverKeychain: pushoverKeychain,
+            notificationCoordinator: notificationCoordinator,
+            projectOnboarding: projectOnboarding,
+            reviewInboxLoader: reviewInboxLoader,
+            dashboardLoader: dashboardLoader,
+            requestIDGenerator: requestIDGenerator,
+            externalServicesSuppressed: externalServicesSuppressed,
+            seedSampleData: seedSampleData
+        )
+        self.rr9ActivePhaseCaptureScenario = rr9ActivePhaseCaptureScenario
+        self.rr9ActivePhaseCaptureRootDirectory = rr9ActivePhaseCaptureRootDirectory
+    }
+#endif
+
     var currentProjectID: ProjectID {
         selection.projectID
             ?? selectedProjectID
             ?? dashboard?.projects.first?.id
             ?? DashboardSampleData.projectID
     }
 
     var currentProject: ProjectDashboardProjection? {
         dashboard?.projects.first { $0.id == currentProjectID }
     }
@@ -151,39 +231,53 @@
             } catch {
                 dashboardError = error.localizedDescription
                 return
             }
         }
         selection = route
     }
 
     func loadDashboard() async {
         await loadAlertRules()
+        await notificationCoordinator.setActivityRefreshHandler { [weak self] projectID in
+            await self?.refreshNotificationActivity(for: projectID)
+        }
+        await notificationCoordinator.setDashboardRefreshHandler { [weak self] in
+            await self?.reloadDashboardAfterCommittedAgentCommand()
+        }
         do {
-            await notificationCoordinator.setActivityRefreshHandler { [weak self] projectID in
-                await self?.refreshNotificationActivity(for: projectID)
-            }
-            await notificationCoordinator.setDashboardRefreshHandler { [weak self] in
-                await self?.refreshDashboardAfterAgentCommit()
-            }
             if seedSampleData {
                 try await DashboardSampleData.seedIfNeeded(in: store)
             }
-            let loadedDashboard = try await dashboardLoader(store)
-            dashboard = loadedDashboard
-            try await loadWorkspace(for: loadedDashboard)
+#if DEBUG
+            if let rr9ActivePhaseCaptureScenario {
+                try await RR9ActivePhaseCaptureFixture.seedIfNeeded(
+                    in: store,
+                    rootDirectory: rr9ActivePhaseCaptureRootDirectory
+                        ?? DeliveryStore.applicationSupportDatabaseURL()
+                            .deletingLastPathComponent()
+                            .appendingPathComponent("RR9ActivePhaseCaptureRoots", isDirectory: true),
+                    scenario: rr9ActivePhaseCaptureScenario
+                )
+            }
+#endif
+            let outcome = await reloadProjectProjections()
+            guard outcome != .failed else { return }
+#if DEBUG
+            if let rr9ActivePhaseCaptureScenario {
+                applyRR9InitialRoute(for: rr9ActivePhaseCaptureScenario)
+            }
+#endif
             if !externalServicesSuppressed {
                 await loadPushoverConfiguration()
                 await notificationCoordinator.dispatchPending()
             }
-            try await refreshActivities(for: loadedDashboard)
-            dashboardError = nil
         } catch {
             dashboardError = error.localizedDescription
         }
     }
 
     func loadAlertRules() async {
         do {
             alertRules = try await AlertRuleStore(store: store).load()
             alertRulesFailureState = nil
         } catch {
@@ -219,35 +313,35 @@
     }
 
     func eligibleProjectsForFolderAttachment() async throws -> [ProjectRecord] {
         try await projectOnboarding.eligibleProjectsForFirstRootAssociation()
     }
 
     func attachFolder(_ folder: URL, to projectID: ProjectID) async throws -> AttachFolderOutcome {
         try await projectOnboarding.associateFirstProjectRoot(folder, for: projectID)
         selection = .projects
         selectedProjectID = projectID
-        do {
-            try await reloadProjectProjections()
+        switch await reloadProjectProjections() {
+        case .published, .superseded:
             return .attached
-        } catch {
+        case .failed:
             return .attachedNeedsReload
         }
     }
 
     func reloadAfterFolderAttachment(_ projectID: ProjectID) async -> Bool {
         selection = .projects
         selectedProjectID = projectID
-        do {
-            try await reloadProjectProjections()
+        switch await reloadProjectProjections() {
+        case .published, .superseded:
             return true
-        } catch {
+        case .failed:
             return false
         }
     }
 
     func reviewInbox(for projectID: ProjectID) -> ReviewInboxProjection? {
         reviewInboxes[projectID]
     }
 
     func dependencyGraph(for projectID: ProjectID) -> DependencyGraphProjection? {
         dependencyGraphs[projectID]
@@ -258,20 +352,136 @@
     }
 
     func projectGuidanceState(for projectID: ProjectID) -> ProjectGuidanceState {
         projectGuidanceStates[projectID] ?? .unavailable
     }
 
     func projectRoot(for projectID: ProjectID) -> URL? {
         projectRoots[projectID]
     }
 
+    func activePhaseSelectionStatus(for projectID: ProjectID) -> ActivePhaseSelectionStatus {
+        activePhaseSelectionStatuses[projectID] ?? .idle
+    }
+
+    func setActivePhase(projectID: ProjectID, phaseID: PhaseID) async {
+        guard dashboard?.projects.first(where: { $0.id == projectID })?.activePhaseID != phaseID else {
+            return
+        }
+        switch activePhaseSelectionStatuses[projectID] ?? .idle {
+        case .saving, .savedNeedsReload:
+            return
+        case .idle, .mutationFailed:
+            break
+        }
+        activePhaseSelectionStatuses[projectID] = .saving(phaseID)
+        let requestID = requestIDGenerator()
+
+#if DEBUG
+        switch rr9ActivePhaseCaptureScenario {
+        case .busy:
+            return
+        case .mutationFailure:
+            activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                FailureStatePresentation(activePhaseAgentError: .invalidReference("The selected phase is unavailable.")),
+                canReauthorize: false
+            )
+            return
+        case .unavailable:
+            activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                FailureStatePresentation(activePhaseAgentError: .appUnavailable),
+                canReauthorize: false
+            )
+            return
+        case .happy, .noAlternative, .authorizationFailure, .savedRefresh,
+             .emptyPhase, .noActivePointer, .crossPhaseDetail, nil:
+            break
+        }
+#endif
+
+        let phaseName = dashboard?.projects
+            .first(where: { $0.id == projectID })?
+            .phases.first(where: { $0.id == phaseID })?
+            .name ?? phaseID.rawValue
+        do {
+            let store = self.store
+            let result = try await projectOnboarding.withAuthorizedProject(projectID: projectID) { project in
+                await AgentCommandDispatcher(
+                    store: store,
+                    projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
+                ).dispatch(
+                    AgentCommandEnvelope(
+                        version: AgentCommandDispatcher.commandEnvelopeVersion,
+                        requestID: requestID,
+                        projectRoot: project.canonicalRoot.path,
+                        reason: "Owner selected active phase \(phaseID.rawValue)",
+                        command: .setActivePhase(phaseID: phaseID.rawValue)
+                    ),
+                    origin: .ownerApp
+                )
+            }
+            if let error = result.error {
+                activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                    FailureStatePresentation(activePhaseAgentError: error),
+                    canReauthorize: false
+                )
+                return
+            }
+            let outcome = await reloadProjectProjections(
+                context: .ownerActivePhaseCommitted(projectID, phaseID, phaseName)
+            )
+            guard outcome != .superseded else { return }
+        } catch let error as ProjectAuthorizationError {
+            activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                FailureStatePresentation(activePhaseAuthorizationError: error),
+                canReauthorize: Self.canReauthorizeActivePhase(after: error)
+            )
+        } catch {
+            activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                FailureStatePresentation(activePhaseAgentError: .internalFailure(error.localizedDescription)),
+                canReauthorize: false
+            )
+        }
+    }
+
+    func reloadAfterActivePhaseSelection(projectID: ProjectID) async {
+        guard case let .savedNeedsReload(phaseID, phaseName) = activePhaseSelectionStatuses[projectID] else {
+            return
+        }
+        _ = await reloadProjectProjections(
+            context: .ownerActivePhaseCommitted(projectID, phaseID, phaseName)
+        )
+    }
+
+    func reauthorizeActivePhaseProject(at folder: URL, projectID: ProjectID) async {
+        guard case let .mutationFailed(_, canReauthorize) = activePhaseSelectionStatuses[projectID],
+              canReauthorize else { return }
+        do {
+            try await projectOnboarding.reauthorizeProjectRoot(folder, for: projectID)
+            activePhaseSelectionStatuses[projectID] = .idle
+        } catch let error as ProjectAuthorizationError {
+            activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                FailureStatePresentation(activePhaseAuthorizationError: error),
+                canReauthorize: Self.canReauthorizeActivePhase(after: error)
+            )
+        } catch {
+            activePhaseSelectionStatuses[projectID] = .mutationFailed(
+                FailureStatePresentation(activePhaseAgentError: .internalFailure(error.localizedDescription)),
+                canReauthorize: true
+            )
+        }
+    }
+
+    func reloadDashboardAfterCommittedAgentCommand() async {
+        _ = await reloadProjectProjections(context: .agentCommandCommitted)
+    }
+
     func scopedReviewActionFailure(for projectID: ProjectID) -> FailureStatePresentation? {
         reviewActionStates[projectID]?.failure
     }
 
     func scopedReviewAuthorizationRecovery(for projectID: ProjectID) -> ReviewAuthorizationRecovery? {
         reviewActionStates[projectID]?.recovery
     }
 
     func scopedIsPerformingReviewAction(for projectID: ProjectID) -> Bool {
         performingReviewActionProjectIDs.contains(projectID)
@@ -346,26 +556,21 @@
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
-            do {
-                let loadedDashboard = try await DashboardProjection.load(from: store)
-                dashboard = loadedDashboard
-                try await loadWorkspace(for: loadedDashboard)
-                try await refreshActivities(for: loadedDashboard)
-            } catch {
+            if await reloadProjectProjections() == .failed {
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
@@ -420,66 +625,164 @@
             summary: item.summary,
             status: decision == .resolve ? .resolved : .dismissed
         )
         reviewInboxes[item.projectID] = ReviewInboxProjection(
             projectID: inbox.projectID,
             openItems: inbox.openItems.filter { $0.id != item.id },
             completedItems: inbox.completedItems.filter { $0.id != item.id } + [committed]
         )
     }
 
-    private func loadWorkspace(for dashboard: DashboardProjection) async throws {
+    private func prepareProjectProjections() async throws -> PreparedProjectProjections {
+        let dashboard = try await dashboardLoader(store)
+        var reviewInboxes: [ProjectID: ReviewInboxProjection] = [:]
+        var dependencyGraphs: [ProjectID: DependencyGraphProjection] = [:]
+        var projectActivities: [ProjectID: ProjectActivityProjection] = [:]
+        var projectGuidanceStates: [ProjectID: ProjectGuidanceState] = [:]
+        var projectRoots: [ProjectID: URL] = [:]
+        var selectedTicketID = self.selectedTicketID
+        let visibleProjectID = selection.projectID
+            ?? selectedProjectID
+            ?? dashboard.projects.first?.id
+            ?? DashboardSampleData.projectID
+
         for project in dashboard.projects {
             reviewInboxes[project.id] = try await reviewInboxLoader(store, project.id)
             projectActivities[project.id] = try await ProjectActivityProjection.load(from: store, projectID: project.id)
             let guidance = await projectOnboarding.observeProjectGuidanceContext(projectID: project.id)
             projectGuidanceStates[project.id] = guidance.state
             projectRoots[project.id] = guidance.projectRoot
             guard let board = dashboard.board(for: project.id) else { continue }
-            let preferredID = board.detail(for: selectedTicketID) == nil
-                ? board.lanes.flatMap(\.cards).first?.id
-                : selectedTicketID
+            let preferredID = board.detail(for: self.selectedTicketID) == nil
+                ? board.lanes.flatMap(\.cards).map(\.id).min { $0.rawValue < $1.rawValue }
+                : self.selectedTicketID
+            if project.id == visibleProjectID, let preferredID {
+                selectedTicketID = preferredID
+            }
             guard let preferredID else { continue }
             dependencyGraphs[project.id] = try await DependencyGraphProjection.load(
                 from: store,
                 projectID: project.id,
                 phaseID: board.phaseID,
                 selectedTicketID: preferredID
             )
         }
-        selectedReviewItemID = reviewInboxes[currentProjectID]?.openItems.first?.id
+        return PreparedProjectProjections(
+            dashboard: dashboard,
+            reviewInboxes: reviewInboxes,
+            dependencyGraphs: dependencyGraphs,
+            projectActivities: projectActivities,
+            projectGuidanceStates: projectGuidanceStates,
+            projectRoots: projectRoots,
+            selectedTicketID: selectedTicketID,
+            selectedReviewItemID: reviewInboxes[visibleProjectID]?.openItems.first?.id
+        )
     }
 
-    private func reloadProjectProjections() async throws {
-        let loadedDashboard = try await dashboardLoader(store)
-        dashboard = loadedDashboard
-        try await loadWorkspace(for: loadedDashboard)
-        try await refreshActivities(for: loadedDashboard)
+    private func publish(_ prepared: PreparedProjectProjections) {
+        dashboard = prepared.dashboard
+        reviewInboxes = prepared.reviewInboxes
+        dependencyGraphs = prepared.dependencyGraphs
+        projectActivities = prepared.projectActivities
+        projectGuidanceStates = prepared.projectGuidanceStates
+        projectRoots = prepared.projectRoots
+        selectedTicketID = prepared.selectedTicketID
+        selectedReviewItemID = prepared.selectedReviewItemID
         dashboardError = nil
+
+        for projectID in Array(activePhaseSelectionStatuses.keys) {
+            let activePhaseID = prepared.dashboard.projects.first { $0.id == projectID }?.activePhaseID
+            switch activePhaseSelectionStatuses[projectID] {
+            case let .saving(target), let .savedNeedsReload(target, _):
+                if activePhaseID == target {
+                    activePhaseSelectionStatuses[projectID] = .idle
+                }
+            case .idle, .mutationFailed, nil:
+                break
+            }
+        }
     }
 
-    private func refreshDashboardAfterAgentCommit() async {
+    private func publishFailure(_ error: Error, context: ProjectionReloadContext) {
+        switch context {
+        case let .ownerActivePhaseCommitted(projectID, phaseID, phaseName):
+            activePhaseSelectionStatuses[projectID] = .savedNeedsReload(phaseID, phaseName)
+        case .agentCommandCommitted:
+            dashboardError = "The agent action was saved, but Release Radar could not refresh the latest project view. Reload the dashboard to see the change."
+        case .ordinary:
+            dashboardError = error.localizedDescription
+        }
+    }
+
+    private func reloadProjectProjections(
+        context: ProjectionReloadContext = .ordinary
+    ) async -> ProjectionReloadOutcome {
+        projectionReloadGeneration += 1
+        let generation = projectionReloadGeneration
+#if DEBUG
+        if case .ownerActivePhaseCommitted = context,
+           rr9ActivePhaseCaptureScenario == .savedRefresh,
+           !rr9SavedRefreshFailureConsumed {
+            rr9SavedRefreshFailureConsumed = true
+            guard generation == projectionReloadGeneration else { return .superseded }
+            publishFailure(RR9ActivePhaseCaptureError.savedRefresh, context: context)
+            return .failed
+        }
+#endif
         do {
-            try await reloadProjectProjections()
+            let prepared = try await prepareProjectProjections()
+            guard generation == projectionReloadGeneration else { return .superseded }
+            publish(prepared)
+            return .published
         } catch {
-            dashboardError = "The agent action was saved, but Release Radar could not refresh the latest project view. Reload the dashboard to see the change."
+            guard generation == projectionReloadGeneration else { return .superseded }
+            publishFailure(error, context: context)
+            return .failed
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
+
+    private static func canReauthorizeActivePhase(after error: ProjectAuthorizationError) -> Bool {
+        switch error {
+        case .bookmarkMissing, .bookmarkStale, .bookmarkResolutionFailed,
+             .securityScopeAccessDenied, .bookmarkRootMismatch:
+            true
+        case .projectNotFound, .projectRootMissing, .projectRootAlreadyAssociated,
+             .projectRootMismatch, .rootAlreadyOwned, .invalidFolder:
+            false
+        }
+    }
+
+#if DEBUG
+    private func applyRR9InitialRoute(for scenario: RR9ActivePhaseCaptureScenario) {
+        let projectID = RR9ActivePhaseCaptureFixture.projectID(for: scenario)
+        selectedProjectID = projectID
+        switch scenario {
+        case .emptyPhase:
+            selection = .phaseBoard(projectID)
+        case .crossPhaseDetail:
+            selectedTicketID = RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID
+            selection = .phaseBoard(projectID)
+        case .happy, .busy, .noAlternative, .mutationFailure, .unavailable,
+             .authorizationFailure, .savedRefresh, .noActivePointer:
+            selection = .projectOverview(projectID)
+        }
+    }
+#endif
 
     private func refreshNotificationActivity(for projectID: ProjectID) async {
         do {
             projectActivities[projectID] = try await ProjectActivityProjection.load(
                 from: store,
                 projectID: projectID
             )
         } catch {
             dashboardError = error.localizedDescription
         }
```

### `ReleaseRadar/Projects/ProjectOverviewView.swift`

Pre-edit blob: `59f5f8d31c23bc2d6ab7295fddabd5eb9c382c78`  
Current blob: `2b65f5cad8523413b92238b2cebfde45abcc4c87`

```diff
--- a/ReleaseRadar/Projects/ProjectOverviewView.swift
+++ b/ReleaseRadar/Projects/ProjectOverviewView.swift
@@ -1,77 +1,114 @@
 import SwiftUI
 import ReleaseRadarCore
 
 struct ProjectOverviewView: View {
-    let board: PhaseBoardProjection
+    let project: ProjectDashboardProjection
+    let board: PhaseBoardProjection?
     let guidanceState: ProjectGuidanceState
     let projectRoot: URL?
+    let phaseSelectionStatus: ActivePhaseSelectionStatus
     let openBoard: () -> Void
+    let selectActivePhase: (PhaseID) async -> Void
+    let reloadActivePhase: () async -> Void
+    let reauthorizeActivePhase: (URL) async -> Void
     @State private var promptCopyResult: CodexPromptCopyResult?
 
     var body: some View {
         ScrollView {
             VStack(alignment: .leading, spacing: 24) {
                 VStack(alignment: .leading, spacing: 6) {
-                    Text(board.project.name)
+                    Text(project.name)
                         .font(.largeTitle.weight(.semibold))
                     Text("Project overview")
                         .foregroundStyle(.secondary)
                 }
 
                 HStack(spacing: 14) {
-                    summaryCard("Active phase", value: board.project.activePhaseName, systemImage: "flag")
-                    summaryCard("Current work", value: "\(board.project.currentWorkCount)", systemImage: "rectangle.stack")
-                    summaryCard("Owner attention", value: "\(board.project.attentionCount)", systemImage: "person.crop.circle.badge.exclamationmark")
+                    summaryCard("Active phase", value: project.activePhaseName, systemImage: "flag")
+                    summaryCard("Current work", value: "\(project.currentWorkCount)", systemImage: "rectangle.stack")
+                    summaryCard("Owner attention", value: "\(project.attentionCount)", systemImage: "person.crop.circle.badge.exclamationmark")
                 }
 
-                ProjectGoalSummaryView(context: board.project.goalContext)
+                ProjectGoalSummaryView(context: project.goalContext)
                     .padding(18)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
 
                 guidanceCard
 
                 VStack(alignment: .leading, spacing: 14) {
-                    HStack {
-                        VStack(alignment: .leading, spacing: 3) {
-                            Text(board.project.activePhaseName)
-                                .font(.title2.weight(.semibold))
-                            Text("Delivery state is derived from persisted lane membership.")
-                                .foregroundStyle(.secondary)
+                    ViewThatFits(in: .horizontal) {
+                        HStack(alignment: .center, spacing: 16) {
+                            deliveryHeading
+                            Spacer()
+                            phaseControls
                         }
-                        Spacer()
-                        Button("Open phase board", action: openBoard)
-                            .buttonStyle(.borderedProminent)
-                            .accessibilityIdentifier("open-phase-board")
+                        VStack(alignment: .leading, spacing: 12) {
+                            deliveryHeading
+                            phaseControls
+                        }
                     }
 
-                    HStack(spacing: 10) {
-                        ForEach(board.lanes) { lane in
-                            VStack(alignment: .leading, spacing: 5) {
-                                Text(lane.lane.dashboardTitle)
-                                    .font(.caption)
-                                    .foregroundStyle(.secondary)
-                                Text("\(lane.count)")
-                                    .font(.title2.weight(.medium))
+                    if let board {
+                        HStack(spacing: 10) {
+                            ForEach(board.lanes) { lane in
+                                VStack(alignment: .leading, spacing: 5) {
+                                    Text(lane.lane.dashboardTitle)
+                                        .font(.caption)
+                                        .foregroundStyle(.secondary)
+                                    Text("\(lane.count)")
+                                        .font(.title2.weight(.medium))
+                                }
+                                .padding(12)
+                                .frame(maxWidth: .infinity, alignment: .leading)
+                                .background(lane.lane.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                             }
-                            .padding(12)
-                            .frame(maxWidth: .infinity, alignment: .leading)
-                            .background(lane.lane.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                         }
+                    } else {
+                        Text("Choose an existing active phase to load its five-lane board. The persisted phase and ticket history remains unchanged.")
+                            .font(.subheadline)
+                            .foregroundStyle(.secondary)
                     }
                 }
                 .padding(20)
                 .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
             }
             .padding(28)
             .frame(maxWidth: .infinity, alignment: .leading)
+        }
+    }
+
+    private var deliveryHeading: some View {
+        VStack(alignment: .leading, spacing: 3) {
+            Text(project.activePhaseName)
+                .font(.title2.weight(.semibold))
+            Text("Delivery state is derived from persisted lane membership.")
+                .foregroundStyle(.secondary)
+        }
+    }
+
+    private var phaseControls: some View {
+        HStack(alignment: .top, spacing: 12) {
+            ActivePhaseSelector(
+                project: project,
+                surface: .overview,
+                status: phaseSelectionStatus,
+                onSelect: selectActivePhase,
+                onReload: reloadActivePhase,
+                onReauthorize: reauthorizeActivePhase
+            )
+            if board != nil {
+                Button("Open phase board", action: openBoard)
+                    .buttonStyle(.borderedProminent)
+                    .accessibilityIdentifier("open-phase-board")
+            }
         }
     }
 
     private var guidanceCard: some View {
         let presentation = ProjectGuidancePresentation(state: guidanceState)
         return VStack(alignment: .leading, spacing: 8) {
             Label(presentation.status, systemImage: presentation.systemImage)
                 .font(.headline)
             Text(presentation.detail)
                 .foregroundStyle(.secondary)
```

### `ReleaseRadar/Projects/PhaseBoardView.swift`

Pre-edit blob: `deb27fa71c2e79ef137465721e58968c84a05cf3`  
Current blob: `04fd1741bddfc4c4ed1370b625391a3be3c3fe5e`

```diff
--- a/ReleaseRadar/Projects/PhaseBoardView.swift
+++ b/ReleaseRadar/Projects/PhaseBoardView.swift
@@ -42,20 +42,24 @@
     private static let sideInspectorMinimumWidth: CGFloat = 1_260
 
     static func usesVerticallyScrollableStack(forWidth width: CGFloat) -> Bool {
         width < sideInspectorMinimumWidth
     }
 }
 
 struct PhaseBoardView: View {
     let board: PhaseBoardProjection
     @Binding var selectedTicketID: TicketID
+    let phaseSelectionStatus: ActivePhaseSelectionStatus
+    let selectActivePhase: (PhaseID) async -> Void
+    let reloadActivePhase: () async -> Void
+    let reauthorizeActivePhase: (URL) async -> Void
     @State private var density: BoardDensity = .fullOutcomes
 
     private let minimumLaneWidth: CGFloat = 112
     private let laneSpacing: CGFloat = 8
 
     var body: some View {
         GeometryReader { geometry in
             let showsSideInspector = !PhaseBoardLayout.usesVerticallyScrollableStack(
                 forWidth: geometry.size.width
             )
@@ -103,34 +107,56 @@
                     .accessibilityIdentifier("phase-board-vertical-recovery")
                 }
             }
             .padding(24)
             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
         }
         .accessibilityIdentifier("phase-board")
     }
 
     private func boardHeader(laneWidth: CGFloat) -> some View {
-        HStack(alignment: .firstTextBaseline) {
-            VStack(alignment: .leading, spacing: 4) {
-                Text(board.project.name)
-                    .font(.caption.weight(.medium))
-                    .foregroundStyle(.secondary)
-                Text(board.project.activePhaseName)
-                    .font(.title2.weight(.semibold))
-                Text("Lane position communicates delivery state; cards show work and constraints.")
-                    .font(.subheadline)
-                    .foregroundStyle(.secondary)
+        ViewThatFits(in: .horizontal) {
+            HStack(alignment: .top, spacing: 18) {
+                boardContext
+                Spacer(minLength: 12)
+                boardControls(laneWidth: laneWidth)
             }
+            VStack(alignment: .leading, spacing: 12) {
+                boardContext
+                boardControls(laneWidth: laneWidth)
+            }
+        }
+    }
 
-            Spacer()
+    private var boardContext: some View {
+        VStack(alignment: .leading, spacing: 4) {
+            Text(board.project.name)
+                .font(.caption.weight(.medium))
+                .foregroundStyle(.secondary)
+            Text(board.project.activePhaseName)
+                .font(.title2.weight(.semibold))
+            Text("Lane position communicates delivery state; cards show work and constraints.")
+                .font(.subheadline)
+                .foregroundStyle(.secondary)
+        }
+    }
 
+    private func boardControls(laneWidth: CGFloat) -> some View {
+        HStack(alignment: .top, spacing: 12) {
+            ActivePhaseSelector(
+                project: board.project,
+                surface: .board,
+                status: phaseSelectionStatus,
+                onSelect: selectActivePhase,
+                onReload: reloadActivePhase,
+                onReauthorize: reauthorizeActivePhase
+            )
             Picker("Card density", selection: $density) {
                 ForEach(BoardDensity.allCases) { option in
                     Text(option.displayName)
                         .accessibilityLabel(
                             option.accessibilityOptionLabel(
                                 isSelected: density == option,
                                 forLaneWidth: laneWidth
                             )
                         )
                         .tag(option)
```

### `ReleaseRadar/Navigation/SidebarView.swift`

Pre-edit blob: `206f919fb9b914e0ec51e48f224fefe6e66d6b61`  
Current blob: `e1b4f0e2bd2a9bd3108e00c826bd5b581866a8ac`

```diff
--- a/ReleaseRadar/Navigation/SidebarView.swift
+++ b/ReleaseRadar/Navigation/SidebarView.swift
@@ -163,21 +163,25 @@
     private var detail: some View {
         if let error = model.dashboardError {
             FailureStateView(
                 presentation: .init(
                     title: "Delivery data unavailable",
                     detail: error,
                     systemImage: "externaldrive.badge.exclamationmark",
                     tone: .error,
                     accessibilityID: "failure-delivery-data"
                 ),
-                style: .full
+                style: .full,
+                actionTitle: "Reload dashboard",
+                action: {
+                    Task { await model.reloadDashboardAfterCommittedAgentCommand() }
+                }
             )
         } else if let dashboard = model.dashboard {
             switch model.selection {
             case .projects:
                 ProjectsView(
                     projection: dashboard,
                     onboardingStore: model.onboardingStore,
                     openProject: { projectID in
                         Task { await model.openProject(projectID) }
                     },
@@ -205,34 +209,75 @@
                     DetailUnavailableView(title: "Needs Review", image: "checkmark.bubble")
                 }
             case .notifications:
                 if let activity = model.activity(for: model.currentProjectID),
                    let project = dashboard.projects.first(where: { $0.id == model.currentProjectID }) {
                     NotificationsView(activity: activity, projectName: project.name)
                 } else {
                     DetailUnavailableView(title: "Notifications", image: "bell")
                 }
             case let .projectOverview(projectID):
-                if let board = dashboard.board(for: projectID) {
+                if let project = dashboard.projects.first(where: { $0.id == projectID }),
+                   !project.phases.isEmpty {
                     ProjectOverviewView(
-                        board: board,
+                        project: project,
+                        board: dashboard.board(for: projectID),
                         guidanceState: model.projectGuidanceState(for: projectID),
-                        projectRoot: model.projectRoot(for: projectID)
-                    ) {
-                        Task { await model.navigate(to: .phaseBoard(projectID)) }
-                    }
+                        projectRoot: model.projectRoot(for: projectID),
+                        phaseSelectionStatus: model.activePhaseSelectionStatus(for: projectID),
+                        openBoard: {
+                            Task { await model.navigate(to: .phaseBoard(projectID)) }
+                        },
+                        selectActivePhase: { phaseID in
+                            await model.setActivePhase(projectID: projectID, phaseID: phaseID)
+                        },
+                        reloadActivePhase: {
+                            await model.reloadAfterActivePhaseSelection(projectID: projectID)
+                        },
+                        reauthorizeActivePhase: { folder in
+                            await model.reauthorizeActivePhaseProject(at: folder, projectID: projectID)
+                        }
+                    )
                 } else {
                     FailureStateView(presentation: .firstPhaseRequired, style: .full)
                 }
             case let .phaseBoard(projectID):
                 if let board = dashboard.board(for: projectID) {
-                    PhaseBoardView(board: board, selectedTicketID: $model.selectedTicketID)
+                    PhaseBoardView(
+                        board: board,
+                        selectedTicketID: $model.selectedTicketID,
+                        phaseSelectionStatus: model.activePhaseSelectionStatus(for: projectID),
+                        selectActivePhase: { phaseID in
+                            await model.setActivePhase(projectID: projectID, phaseID: phaseID)
+                        },
+                        reloadActivePhase: {
+                            await model.reloadAfterActivePhaseSelection(projectID: projectID)
+                        },
+                        reauthorizeActivePhase: { folder in
+                            await model.reauthorizeActivePhaseProject(at: folder, projectID: projectID)
+                        }
+                    )
+                } else if let project = dashboard.projects.first(where: { $0.id == projectID }),
+                          !project.phases.isEmpty {
+                    ActivePhaseBoardRecoveryView(
+                        project: project,
+                        status: model.activePhaseSelectionStatus(for: projectID),
+                        onSelect: { phaseID in
+                            await model.setActivePhase(projectID: projectID, phaseID: phaseID)
+                        },
+                        onReload: {
+                            await model.reloadAfterActivePhaseSelection(projectID: projectID)
+                        },
+                        onReauthorize: { folder in
+                            await model.reauthorizeActivePhaseProject(at: folder, projectID: projectID)
+                        }
+                    )
                 } else {
                     FailureStateView(presentation: .firstPhaseRequired, style: .full)
                 }
             case let .dependencies(projectID):
                 if let graph = model.dependencyGraph(for: projectID) {
                     DependencyGraphView(
                         graph: graph,
                         selectedTicketID: $model.selectedTicketID,
                         freshness: model.codexSnapshot.freshness
                     )
```

### `ReleaseRadar/Shared/FailureStateView.swift`

Pre-edit blob: `6752094749f9c667c5a5b1bf017e9fe168266f26`  
Current blob: `609f294f5a780764a10cb0e7bdf8205e26f6cc97`

```diff
--- a/ReleaseRadar/Shared/FailureStateView.swift
+++ b/ReleaseRadar/Shared/FailureStateView.swift
@@ -264,43 +264,86 @@
             false
         }
         self.init(
             title: recoverable ? "Project folder authorization required" : "Project folder not accepted",
             detail: "\(projectAuthorizationError.localizedDescription) The review remains open; retry Resolve or Dismiss only after access is restored.",
             systemImage: "folder.badge.questionmark",
             tone: recoverable ? .warning : .error,
             accessibilityID: recoverable ? "review-locate-authorization" : "review-folder-authorization-error"
         )
     }
+
+    init(activePhaseAuthorizationError error: ProjectAuthorizationError) {
+        self.init(
+            title: "Active phase authorization required",
+            detail: "\(error.localizedDescription) Locate the same project folder to restore access, then select the phase again.",
+            systemImage: "folder.badge.questionmark",
+            tone: .warning,
+            accessibilityID: "active-phase-authorization-failed"
+        )
+    }
+
+    init(activePhaseAgentError error: AgentCommandError) {
+        switch error {
+        case .appUnavailable:
+            self.init(
+                title: "Active phase unavailable",
+                detail: "Release Radar could not accept the phase change. The active phase and current board did not change. Reopen or reload Release Radar before trying again.",
+                systemImage: "app.badge.checkmark",
+                tone: .error,
+                accessibilityID: "active-phase-unavailable"
+            )
+        case .outcomeUnknown:
+            self.init(
+                title: "Active phase outcome unknown",
+                detail: "Refresh persisted state before deciding what to do next. Release Radar will not retry the phase change automatically.",
+                systemImage: "questionmark.diamond",
+                tone: .warning,
+                accessibilityID: "active-phase-outcome-unknown"
+            )
+        default:
+            let base = FailureStatePresentation(agentError: error)
+            self.init(
+                title: "Active phase change failed",
+                detail: base?.detail ?? "The phase change failed and no partial delivery state was kept.",
+                systemImage: base?.systemImage ?? "exclamationmark.triangle",
+                tone: base?.tone ?? .error,
+                accessibilityID: "active-phase-mutation-failed"
+            )
+        }
+    }
 }
 
 enum FailureStateViewStyle: Sendable {
     case full
     case inline
     case compact
 }
 
 struct FailureStateView: View {
     let presentation: FailureStatePresentation
     var style: FailureStateViewStyle = .inline
     var actionTitle: String? = nil
     var action: (() -> Void)? = nil
 
     var body: some View {
         Group {
             switch style {
             case .full:
-                ContentUnavailableView(
-                    presentation.title,
-                    systemImage: presentation.systemImage,
-                    description: Text(presentation.detail)
-                )
+                VStack(spacing: 12) {
+                    ContentUnavailableView(
+                        presentation.title,
+                        systemImage: presentation.systemImage,
+                        description: Text(presentation.detail)
+                    )
+                    actionButton
+                }
             case .inline:
                 HStack(alignment: .top, spacing: 12) {
                     stateIcon
                     stateCopy
                 }
                 .padding(14)
                 .frame(maxWidth: .infinity, alignment: .leading)
                 .background(presentation.tone.color.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                 .overlay {
                     RoundedRectangle(cornerRadius: 11)
@@ -325,20 +368,25 @@
     }
 
     private var stateCopy: some View {
         VStack(alignment: .leading, spacing: 3) {
             Text(presentation.title)
                 .font(.subheadline.weight(.semibold))
             Text(presentation.detail)
                 .font(.caption)
                 .foregroundStyle(.secondary)
                 .fixedSize(horizontal: false, vertical: true)
-            if let actionTitle, let action {
-                Button(actionTitle, action: action)
-                    .buttonStyle(.bordered)
-                    .controlSize(.small)
-                    .padding(.top, 4)
-                    .accessibilityIdentifier("\(presentation.accessibilityID)-action")
-            }
+            actionButton
+        }
+    }
+
+    @ViewBuilder
+    private var actionButton: some View {
+        if let actionTitle, let action {
+            Button(actionTitle, action: action)
+                .buttonStyle(.bordered)
+                .controlSize(.small)
+                .padding(.top, 4)
+                .accessibilityIdentifier("\(presentation.accessibilityID)-action")
         }
     }
 }
```

### `ReleaseRadar/App/AppNotificationCoordinator.swift`

Pre-edit blob: `47ff177ad47b1cc2d157912b2ec848707dd74958`  
Current blob: `e021f51be497c0aac13feb103e8b872241de9b7a`

```diff
--- a/ReleaseRadar/App/AppNotificationCoordinator.swift
+++ b/ReleaseRadar/App/AppNotificationCoordinator.swift
@@ -2,51 +2,70 @@
 import ReleaseRadarCore
 
 actor AppNotificationCoordinator {
     typealias ActivityRefreshHandler = @Sendable (ProjectID) async -> Void
     typealias DashboardRefreshHandler = @Sendable () async -> Void
 
     private let store: DeliveryStore
     private let dispatcher: PushoverNotificationDispatcher
     private var activityRefreshHandler: ActivityRefreshHandler?
     private var dashboardRefreshHandler: DashboardRefreshHandler?
+    private var pendingSuccessfulCommandRefresh = false
+    private var successfulCommandRefreshDrainInProgress = false
 
     init(store: DeliveryStore, dispatcher: PushoverNotificationDispatcher) {
         self.store = store
         self.dispatcher = dispatcher
     }
 
     func setActivityRefreshHandler(_ handler: @escaping ActivityRefreshHandler) {
         activityRefreshHandler = handler
     }
 
-    func setDashboardRefreshHandler(_ handler: @escaping DashboardRefreshHandler) {
+    func setDashboardRefreshHandler(_ handler: @escaping DashboardRefreshHandler) async {
         dashboardRefreshHandler = handler
+        await drainSuccessfulCommandRefreshIfPossible()
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
-        await dispatchPending()
-        await dashboardRefreshHandler?()
+        pendingSuccessfulCommandRefresh = true
+        await drainSuccessfulCommandRefreshIfPossible()
+    }
+
+    private func drainSuccessfulCommandRefreshIfPossible() async {
+        guard !successfulCommandRefreshDrainInProgress,
+              pendingSuccessfulCommandRefresh,
+              let dashboardRefreshHandler else { return }
+        successfulCommandRefreshDrainInProgress = true
+        defer { successfulCommandRefreshDrainInProgress = false }
+        while true {
+            repeat {
+                pendingSuccessfulCommandRefresh = false
+                await dashboardRefreshHandler()
+            } while pendingSuccessfulCommandRefresh
+            await dispatchPending()
+            guard pendingSuccessfulCommandRefresh else { return }
+        }
     }
 
     private func refreshProjectsWithNotifications() async {
         guard let projectIDs = try? await store.read({ connection in
             var projectIDs: [ProjectID] = []
             var offset: Int64 = 0
             while let rawID = try connection.scalarText(
                 "SELECT DISTINCT project_id FROM notification_events WHERE project_id IS NOT NULL ORDER BY project_id LIMIT 1 OFFSET ?",
                 bindings: [.integer(offset)]
             ) {
```

### `ReleaseRadarTests/DashboardProjectionTests.swift`

Pre-edit blob: `b12a1427e7d972f7c26ea7b4eb4971ffe70a916d`  
Current blob: `309aa500f5e70e02fab6572706fa69492aa21486`

```diff
--- a/ReleaseRadarTests/DashboardProjectionTests.swift
+++ b/ReleaseRadarTests/DashboardProjectionTests.swift
@@ -190,35 +190,145 @@
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-active', 'project-explicit', 'Current delivery')")
             try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-explicit', 'phase-active')")
             try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ACTIVE-1', 'project-explicit', 'phase-active', 'Current work', 'in_progress')")
         }
 
         let projection = try await DashboardProjection.load(from: store)
         let project = try XCTUnwrap(projection.projects.first { $0.id.rawValue == "project-explicit" })
         let board = try XCTUnwrap(projection.board(for: project.id))
 
         XCTAssertEqual(project.activePhaseName, "Current delivery")
+        XCTAssertEqual(project.activePhaseID?.rawValue, "phase-active")
+        XCTAssertEqual(project.phases.map(\.id.rawValue), ["phase-active", "phase-history"])
         XCTAssertEqual(board.phaseID.rawValue, "phase-active")
         XCTAssertEqual(board.lane(.inProgress)?.cards.map(\.id.rawValue), ["ACTIVE-1"])
     }
 
+    func testActivePhaseSelectionKeepsOptionsDeterministicAndBoardMembershipScopedAcrossRelaunch() async throws {
+        let store = DeliveryStore(databaseURL: databaseURL)
+        let projectID = ProjectID(rawValue: "phase-selection-project")
+        let projectRoot = databaseURL.deletingLastPathComponent()
+        try await store.transact(
+            actor: .init(id: "dashboard-test"),
+            reason: "Seed active phase projection fixture"
+        ) { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('phase-selection-project', 'Phase Selection')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'phase-selection-project', 'Current')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-history', 'phase-selection-project', 'History')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-roadmap', 'phase-selection-project', 'Roadmap delivery')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-order-z', 'phase-selection-project', 'ROADMAP')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-order-a', 'phase-selection-project', 'Roadmap')")
+            try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('phase-selection-project', 'phase-current')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-A', 'phase-selection-project', 'phase-current', 'Current ticket keeps cross phase truth.', 'backlog')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-B', 'phase-selection-project', 'phase-current', 'Current ticket keeps local dependency.', 'in_progress')")
+            for index in 1...8 {
+                try connection.execute(
+                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, 'phase-selection-project', 'phase-roadmap', ?, 'backlog')",
+                    bindings: [.text("ROAD-B\(index)"), .text("Roadmap backlog outcome \(index).")]
+                )
+            }
+            for index in 1...3 {
+                try connection.execute(
+                    "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, 'phase-selection-project', 'phase-roadmap', ?, 'blocked')",
+                    bindings: [.text("ROAD-X\(index)"), .text("Roadmap blocked outcome \(index).")]
+                )
+            }
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('HISTORY-A', 'phase-selection-project', 'phase-history', 'Historical accepted outcome.', 'accepted')")
+            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-cross', 'phase-selection-project', 'CURRENT-A', 'ROAD-B1')")
+            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-current', 'phase-selection-project', 'CURRENT-B', 'CURRENT-A')")
+            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-roadmap', 'phase-selection-project', 'ROAD-X1', 'ROAD-B2')")
+        }
+
+        let initial = try await DashboardProjection.load(from: store)
+        let initialProject = try XCTUnwrap(initial.projects.first { $0.id == projectID })
+        let initialBoard = try XCTUnwrap(initial.board(for: projectID))
+        XCTAssertEqual(initialProject.activePhaseID?.rawValue, "phase-current")
+        XCTAssertEqual(initialProject.phases.map(\.id.rawValue), [
+            "phase-current", "phase-history", "phase-order-a", "phase-order-z", "phase-roadmap",
+        ])
+        XCTAssertEqual(Set(initialBoard.details.keys.map(\.rawValue)), ["CURRENT-A", "CURRENT-B"])
+        XCTAssertEqual(initialBoard.detail(for: .init(rawValue: "CURRENT-A"))?.requires.map(\.id.rawValue), ["ROAD-B1"])
+        let initialGraph = try await DependencyGraphProjection.load(
+            from: store,
+            projectID: projectID,
+            phaseID: .init(rawValue: "phase-current"),
+            selectedTicketID: .init(rawValue: "CURRENT-A")
+        )
+        XCTAssertEqual(Set(initialGraph.nodes.map(\.id.rawValue)), ["CURRENT-A", "CURRENT-B"])
+        XCTAssertNil(initialGraph.node(id: .init(rawValue: "ROAD-B1")))
+
+        let before = try await store.read { connection in
+            (
+                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'phase-selection-project'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'phase-selection-project'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'phase-selection-project'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        let result = await AgentCommandDispatcher(
+            store: store,
+            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
+                .init(projectID: projectID, canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
+            ])
+        ).dispatch(.init(
+            version: AgentCommandDispatcher.commandEnvelopeVersion,
+            requestID: UUID(uuidString: "29292929-2929-4929-8929-292929292929")!,
+            projectRoot: projectRoot.path,
+            reason: "Select roadmap projection",
+            command: .setActivePhase(phaseID: "phase-roadmap")
+        ))
+        XCTAssertNil(result.error)
+
+        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
+        let reloaded = try await DashboardProjection.load(from: relaunchedStore)
+        let reloadedProject = try XCTUnwrap(reloaded.projects.first { $0.id == projectID })
+        let reloadedBoard = try XCTUnwrap(reloaded.board(for: projectID))
+        XCTAssertEqual(reloadedProject.activePhaseID?.rawValue, "phase-roadmap")
+        XCTAssertEqual(reloadedProject.phases, initialProject.phases)
+        XCTAssertEqual(reloadedBoard.lanes.map(\.count), [8, 0, 0, 3, 0])
+        XCTAssertEqual(Set(reloadedBoard.details.keys.map(\.rawValue)), Set((1...8).map { "ROAD-B\($0)" } + (1...3).map { "ROAD-X\($0)" }))
+        XCTAssertEqual(reloadedBoard.detail(for: .init(rawValue: "ROAD-B1"))?.unlocks.map(\.id.rawValue), ["CURRENT-A"])
+        XCTAssertNil(reloadedBoard.detail(for: .init(rawValue: "CURRENT-A")))
+        let roadmapGraph = try await DependencyGraphProjection.load(
+            from: relaunchedStore,
+            projectID: projectID,
+            phaseID: .init(rawValue: "phase-roadmap"),
+            selectedTicketID: .init(rawValue: "ROAD-B1")
+        )
+        XCTAssertNil(roadmapGraph.node(id: .init(rawValue: "CURRENT-A")))
+        let after = try await relaunchedStore.read { connection in
+            (
+                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'phase-selection-project'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'phase-selection-project'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'phase-selection-project'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(after.0, before.0)
+        XCTAssertEqual(after.1, before.1)
+        XCTAssertEqual(after.2, before.2)
+        XCTAssertEqual(after.3, (before.3 ?? 0) + 1)
+    }
+
     func testProjectWithMultiplePhasesAndNoExplicitActivePhaseHasNoGuessedBoard() async throws {
         let store = DeliveryStore(databaseURL: databaseURL)
         try await store.transact(actor: .init(id: "dashboard-test"), reason: "Seed ambiguous project") { connection in
             try connection.execute("INSERT INTO projects (id, name) VALUES ('project-ambiguous', 'Ambiguous')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-a', 'project-ambiguous', 'Historical')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-b', 'project-ambiguous', 'Planned')")
         }
 
         let projection = try await DashboardProjection.load(from: store)
         let project = try XCTUnwrap(projection.projects.first { $0.id.rawValue == "project-ambiguous" })
 
+        XCTAssertNil(project.activePhaseID)
+        XCTAssertEqual(project.phases.map(\.id.rawValue), ["phase-a", "phase-b"])
         XCTAssertEqual(project.activePhaseName, "No active phase")
         XCTAssertNil(projection.board(for: project.id))
         XCTAssertEqual(project.currentWorkCount, 0)
         XCTAssertEqual(project.attentionCount, 0)
     }
 
     func testRequestedBoardDensityUsesCompactCardsAtOrBelowTheLaneWidthBoundary() {
         XCTAssertEqual(BoardDensity.fullOutcomes.displayName, "Full outcomes")
         XCTAssertEqual(BoardDensity.compact.displayName, "Compact density")
         XCTAssertEqual(BoardDensity.fullOutcomes.presentation(forLaneWidth: 181), .fullOutcome)
```

### `ReleaseRadarTests/AppRouteTests.swift`

Pre-edit blob: `1a342f4081286ead06b8206ba110525fd3a28db2`  
Current blob: `9597624eb01f53af7d4038a38ac78eff51c36e24`

```diff
--- a/ReleaseRadarTests/AppRouteTests.swift
+++ b/ReleaseRadarTests/AppRouteTests.swift
@@ -1078,20 +1078,1094 @@
                 return DashboardProjection(projects: [], boards: [:])
             }
         )
 
         await model.initializeForLaunch()
 
         let recordedEvents = await events.snapshot()
         XCTAssertEqual(recordedEvents, [.codexObservation, .dashboard, .pluginStatus])
     }
 
+    func testRR9CapturePolicyRequiresDebugCaptureEmptyStoreAndOneKnownScenario() {
+        let required = ["--rr10-capture", "--rr10-empty-store"]
+        let recognized: [(String, RR9ActivePhaseCaptureScenario)] = [
+            ("happy", .happy),
+            ("busy", .busy),
+            ("no-alternative", .noAlternative),
+            ("mutation-failure", .mutationFailure),
+            ("unavailable", .unavailable),
+            ("authorization-failure", .authorizationFailure),
+            ("saved-refresh", .savedRefresh),
+            ("empty-phase", .emptyPhase),
+            ("no-active-pointer", .noActivePointer),
+            ("cross-phase-detail", .crossPhaseDetail),
+        ]
+        for (argument, scenario) in recognized {
+            XCTAssertEqual(
+                AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+                    arguments: required + ["--rr9-active-phase-fixture=\(argument)"],
+                    isDebugBuild: true
+                ),
+                scenario
+            )
+        }
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: ["--rr10-empty-store", "--rr9-active-phase-fixture=happy"],
+            isDebugBuild: true
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: ["--rr10-capture", "--rr9-active-phase-fixture=happy"],
+            isDebugBuild: true
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: required + ["--rr9-active-phase-fixture=unknown"],
+            isDebugBuild: true
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: required + [
+                "--rr9-active-phase-fixture=happy",
+                "--rr9-active-phase-fixture=busy",
+            ],
+            isDebugBuild: true
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: required + ["--rr9-active-phase-fixture=happy"],
+            isDebugBuild: false
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: required,
+            isDebugBuild: true
+        ))
+    }
+
+    func testActivePhaseSelectorPresentationDistinguishesSelectionBusyAndNoAlternative() {
+        let phase = ProjectPhaseProjection(id: .init(rawValue: "phase-only"), name: "Roadmap")
+        let project = ProjectDashboardProjection(
+            id: .init(rawValue: "selector-project"),
+            name: "Selector",
+            activePhaseID: phase.id,
+            activePhaseName: phase.name,
+            phases: [phase],
+            goalContext: .init(linkQuality: .unavailable, text: nil, status: nil, lastObservedAt: nil),
+            currentWorkCount: 0,
+            attentionCount: 0
+        )
+
+        XCTAssertEqual(ActivePhaseSelectorSurface.overview.accessibilityIdentifier, "active-phase-selector-overview")
+        XCTAssertEqual(ActivePhaseSelectorSurface.board.accessibilityIdentifier, "active-phase-selector-board")
+        XCTAssertEqual(
+            ActivePhaseSelectorPresentation(project: project, status: .idle).accessibilityValue,
+            "Roadmap (phase-only)"
+        )
+        XCTAssertEqual(
+            ActivePhaseSelectorPresentation(project: project, status: .idle).accessibilityHelp,
+            "No other phases are available for this project."
+        )
+        XCTAssertTrue(ActivePhaseSelectorPresentation(project: project, status: .idle).isDisabled)
+        XCTAssertEqual(
+            ActivePhaseSelectorPresentation(project: project, status: .saving(phase.id)).accessibilityValue,
+            "Saving active phase"
+        )
+
+        let unselected = ProjectDashboardProjection(
+            id: project.id,
+            name: project.name,
+            activePhaseID: nil,
+            activePhaseName: "No active phase",
+            phases: [phase],
+            goalContext: project.goalContext,
+            currentWorkCount: 0,
+            attentionCount: 0
+        )
+        XCTAssertEqual(
+            ActivePhaseSelectorPresentation(project: unselected, status: .idle).accessibilityValue,
+            "No active phase"
+        )
+        XCTAssertFalse(ActivePhaseSelectorPresentation(project: unselected, status: .idle).isDisabled)
+    }
+
+    @MainActor
+    func testOwnerActivePhaseSelectionPublishesCoherentProjectionAndPersistsAcrossModelRelaunch() async throws {
+        let fixture = try await makeRR9OwnerFixture()
+        let requestIDs = RR9RequestIDCounter()
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            requestIDGenerator: { requestIDs.next() },
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+        model.selectedTicketID = .init(rawValue: "CURRENT-1")
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+        XCTAssertEqual(requestIDs.count, 1)
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
+        XCTAssertEqual(model.dashboard?.board(for: fixture.projectID)?.lanes.map(\.count), [2, 0, 0, 1, 0])
+        XCTAssertEqual(model.selectedTicketID.rawValue, "ROAD-1")
+        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID)?.phaseID, fixture.roadmapPhaseID)
+        XCTAssertEqual(model.activity(for: fixture.projectID)?.items.first?.detail, "Owner selected active phase phase-roadmap")
+        let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(state.activePhaseID, fixture.roadmapPhaseID.rawValue)
+        XCTAssertEqual(state.commandRequests, 1)
+        XCTAssertEqual(state.selectionAudits, 1)
+        XCTAssertEqual(state.actorID, "release-radar-owner")
+
+        let relaunched = AppModel(
+            store: DeliveryStore(databaseURL: fixture.databaseURL),
+            projectOnboarding: fixture.onboarding,
+            externalServicesSuppressed: true
+        )
+        await relaunched.loadDashboard()
+        XCTAssertEqual(relaunched.currentProject?.activePhaseID, fixture.roadmapPhaseID)
+        XCTAssertEqual(relaunched.dashboard?.board(for: fixture.projectID)?.lanes.map(\.count), [2, 0, 0, 1, 0])
+    }
+
+    @MainActor
+    func testAlreadyActiveOwnerCallReturnsBeforeUUIDAuthorizationRequestAndAudit() async throws {
+        let fixture = try await makeRR9OwnerFixture()
+        let requestIDs = RR9RequestIDCounter()
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            requestIDGenerator: { requestIDs.next() },
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+        let before = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.currentPhaseID)
+
+        let after = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(requestIDs.count, 0)
+        XCTAssertEqual(after, before)
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+    }
+
+    @MainActor
+    func testSavingOwnerCallRejectsDuplicateBeforeSecondUUIDRequestAndAudit() async throws {
+        let fixture = try await makeRR9OwnerFixture(blockAuthorization: true)
+        let requestIDs = RR9RequestIDCounter()
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            requestIDGenerator: { requestIDs.next() },
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+        await fixture.bookmarks.armAccessGate()
+
+        let first = Task {
+            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+        }
+        await fixture.bookmarks.waitUntilAccessEntered()
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .saving(fixture.roadmapPhaseID))
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.emptyPhaseID)
+
+        XCTAssertEqual(requestIDs.count, 1)
+        let whileSaving = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(whileSaving.commandRequests, 0)
+        XCTAssertEqual(whileSaving.selectionAudits, 0)
+        await fixture.bookmarks.releaseAccess()
+        await first.value
+        let final = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(final.commandRequests, 1)
+        XCTAssertEqual(final.selectionAudits, 1)
+    }
+
+    @MainActor
+    func testSavedNeedsReloadRejectsMutationAndRecoversThroughReadOnlyReload() async throws {
+        let fixture = try await makeRR9OwnerFixture()
+        let requestIDs = RR9RequestIDCounter()
+        let loader = RouteDashboardLoader(failingCalls: [2])
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            dashboardLoader: { store in try await loader.load(from: store) },
+            requestIDGenerator: { requestIDs.next() },
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+        XCTAssertEqual(
+            model.activePhaseSelectionStatus(for: fixture.projectID),
+            .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
+        )
+        let committed = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(committed.commandRequests, 1)
+        XCTAssertEqual(committed.selectionAudits, 1)
+        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.emptyPhaseID)
+
+        XCTAssertEqual(requestIDs.count, 1)
+        let afterRejectedSelection = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(afterRejectedSelection, committed)
+        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
+        XCTAssertEqual(requestIDs.count, 1)
+        let afterReload = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(afterReload, committed)
+    }
+
+    @MainActor
+    func testPostCommitWorkspacePreparationFailurePublishesNoPartialDashboardBeforeReadOnlyRecovery() async throws {
+        let fixture = try await makeRR9OwnerFixture()
+        let reviewLoader = RR9SequencedReviewInboxLoader(failingCalls: [2])
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            reviewInboxLoader: { store, projectID in
+                try await reviewLoader.load(from: store, projectID: projectID)
+            },
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+        let dashboard = model.dashboard
+        let graph = model.dependencyGraph(for: fixture.projectID)
+        let activity = model.activity(for: fixture.projectID)
+        let guidance = model.projectGuidanceState(for: fixture.projectID)
+        let root = model.projectRoot(for: fixture.projectID)
+        let selectedTicketID = model.selectedTicketID
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+        XCTAssertEqual(
+            model.activePhaseSelectionStatus(for: fixture.projectID),
+            .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
+        )
+        XCTAssertEqual(model.dashboard, dashboard)
+        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID), graph)
+        XCTAssertEqual(model.activity(for: fixture.projectID), activity)
+        XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), guidance)
+        XCTAssertEqual(model.projectRoot(for: fixture.projectID), root)
+        XCTAssertEqual(model.selectedTicketID, selectedTicketID)
+
+        await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
+
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
+        let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(state.commandRequests, 1)
+        XCTAssertEqual(state.selectionAudits, 1)
+    }
+
+    @MainActor
+    func testAuthorizationRecoveryRestoresOnlyExactRootAndNeverRetriesSelection() async throws {
+        let fixture = try await makeRR9OwnerFixture(hasBookmark: false)
+        let requestIDs = RR9RequestIDCounter()
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            requestIDGenerator: { requestIDs.next() },
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+        guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(for: fixture.projectID) else {
+            return XCTFail("Expected phase authorization recovery")
+        }
+        XCTAssertEqual(presentation.accessibilityID, "active-phase-authorization-failed")
+        XCTAssertTrue(canReauthorize)
+        XCTAssertEqual(requestIDs.count, 1)
+        let failedSelection = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(failedSelection.commandRequests, 0)
+
+        await model.reauthorizeActivePhaseProject(at: fixture.projectRoot, projectID: fixture.projectID)
+
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
+        let reauthorized = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(reauthorized.commandRequests, 0)
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+        XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
+        XCTAssertEqual(requestIDs.count, 2)
+    }
+
+    @MainActor
+    func testEveryRecoverableBookmarkFailureFailsClosedBeforePhaseMutation() async throws {
+        let mismatchedRoot = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9-Mismatched-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
+        let failures: [RR9BookmarkFailureMode] = [
+            .stale,
+            .resolutionFailure,
+            .accessDenied,
+            .mismatchedRoot(mismatchedRoot),
+        ]
+
+        for failure in failures {
+            let fixture = try await makeRR9OwnerFixture()
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+            fixture.bookmarks.setFailureMode(failure)
+
+            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+            guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(for: fixture.projectID) else {
+                return XCTFail("Expected recoverable authorization failure for \(failure)")
+            }
+            XCTAssertEqual(presentation.accessibilityID, "active-phase-authorization-failed")
+            XCTAssertTrue(canReauthorize)
+            let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+            XCTAssertEqual(state.activePhaseID, fixture.currentPhaseID.rawValue)
+            XCTAssertEqual(state.commandRequests, 0)
+            XCTAssertEqual(state.selectionAudits, 0)
+        }
+    }
+
+    @MainActor
+    func testDirectInvalidTargetShowsTypedFailureWithoutChangingCoherentProjection() async throws {
+        let fixture = try await makeRR9OwnerFixture()
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+        let dashboard = model.dashboard
+        let dependencyGraph = model.dependencyGraph(for: fixture.projectID)
+
+        await model.setActivePhase(
+            projectID: fixture.projectID,
+            phaseID: PhaseID(rawValue: "phase-does-not-exist")
+        )
+
+        guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(for: fixture.projectID) else {
+            return XCTFail("Expected a typed mutation failure")
+        }
+        XCTAssertEqual(presentation.accessibilityID, "active-phase-mutation-failed")
+        XCTAssertFalse(canReauthorize)
+        XCTAssertEqual(model.dashboard, dashboard)
+        XCTAssertEqual(model.dependencyGraph(for: fixture.projectID), dependencyGraph)
+        let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+        XCTAssertEqual(state.activePhaseID, fixture.currentPhaseID.rawValue)
+        XCTAssertEqual(state.commandRequests, 0)
+        XCTAssertEqual(state.selectionAudits, 0)
+    }
+
+    @MainActor
+    func testProjectWithoutActivePointerCanEstablishItFromEitherOwnerRoute() async throws {
+        let routes: [(ProjectID) -> AppRoute] = [
+            { .projectOverview($0) },
+            { .phaseBoard($0) },
+        ]
+
+        for route in routes {
+            let fixture = try await makeRR9OwnerFixture(hasActivePointer: false)
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+            model.selection = route(fixture.projectID)
+            XCTAssertNil(model.currentProject?.activePhaseID)
+            XCTAssertNil(model.dashboard?.board(for: fixture.projectID))
+
+            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.currentPhaseID)
+
+            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
+            XCTAssertEqual(model.dashboard?.board(for: fixture.projectID)?.phaseID, fixture.currentPhaseID)
+            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+            let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+            XCTAssertEqual(state.commandRequests, 1)
+            XCTAssertEqual(state.selectionAudits, 1)
+        }
+    }
+
+    @MainActor
+    func testEmptyTargetRemovesVisibleDetailAndDependencyGraphWithoutStaleBoardState() async throws {
+        let fixture = try await makeRR9OwnerFixture()
+        let model = AppModel(
+            store: fixture.store,
+            projectOnboarding: fixture.onboarding,
+            externalServicesSuppressed: true
+        )
+        await model.loadDashboard()
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+        XCTAssertNotNil(model.dependencyGraph(for: fixture.projectID))
+
+        await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.emptyPhaseID)
+
+        let board = try XCTUnwrap(model.dashboard?.board(for: fixture.projectID))
+        XCTAssertEqual(board.phaseID, fixture.emptyPhaseID)
+        XCTAssertEqual(board.lanes.map(\.count), [0, 0, 0, 0, 0])
+        XCTAssertTrue(board.details.isEmpty)
+        XCTAssertNil(board.detail(for: model.selectedTicketID))
+        XCTAssertNil(model.dependencyGraph(for: fixture.projectID))
+        XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+    }
+
+    @MainActor
+    func testCurrentGenerationTargetMismatchPreservesSavingAndSavedRecoveryStatus() async throws {
+        for failingCommittedReload in [false, true] {
+            let fixture = try await makeRR9OwnerFixture()
+            let loader = RR9TargetMismatchDashboardLoader(failCommittedReload: failingCommittedReload)
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                dashboardLoader: { store in try await loader.load(from: store) },
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+
+            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+            if failingCommittedReload {
+                XCTAssertEqual(
+                    model.activePhaseSelectionStatus(for: fixture.projectID),
+                    .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
+                )
+                await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
+                XCTAssertEqual(
+                    model.activePhaseSelectionStatus(for: fixture.projectID),
+                    .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
+                )
+            } else {
+                XCTAssertEqual(
+                    model.activePhaseSelectionStatus(for: fixture.projectID),
+                    .saving(fixture.roadmapPhaseID)
+                )
+                await model.reloadDashboardAfterCommittedAgentCommand()
+                XCTAssertEqual(
+                    model.activePhaseSelectionStatus(for: fixture.projectID),
+                    .saving(fixture.roadmapPhaseID)
+                )
+            }
+            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
+            let state = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
+            XCTAssertEqual(state.activePhaseID, fixture.roadmapPhaseID.rawValue)
+            XCTAssertEqual(state.commandRequests, 1)
+            XCTAssertEqual(state.selectionAudits, 1)
+        }
+    }
+
+    @MainActor
+    func testNewerAgentReloadWinsOverOlderOwnerReloadSuccessOrFailure() async throws {
+        for staleCompletion in RR9StaleCompletion.allCases {
+            let fixture = try await makeRR9OwnerFixture()
+            let loader = RR9InterleavingDashboardLoader(staleCompletion: staleCompletion)
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                dashboardLoader: { store in try await loader.load(from: store) },
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+            let ownerReload = Task {
+                await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+            }
+            await loader.waitUntilOlderReloadEntered()
+
+            await model.reloadDashboardAfterCommittedAgentCommand()
+
+            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
+            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+            XCTAssertNil(model.dashboardError)
+            let publishedDashboard = model.dashboard
+            let publishedReviewInbox = model.reviewInbox(for: fixture.projectID)
+            let publishedGraph = model.dependencyGraph(for: fixture.projectID)
+            let publishedActivity = model.activity(for: fixture.projectID)
+            let publishedGuidance = model.projectGuidanceState(for: fixture.projectID)
+            let publishedRoot = model.projectRoot(for: fixture.projectID)
+            let publishedTicketID = model.selectedTicketID
+            let publishedReviewItemID = model.selectedReviewItemID
+            await loader.releaseOlderReload()
+            await ownerReload.value
+            XCTAssertEqual(model.dashboard, publishedDashboard)
+            XCTAssertEqual(model.reviewInbox(for: fixture.projectID), publishedReviewInbox)
+            XCTAssertEqual(model.dependencyGraph(for: fixture.projectID), publishedGraph)
+            XCTAssertEqual(model.activity(for: fixture.projectID), publishedActivity)
+            XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), publishedGuidance)
+            XCTAssertEqual(model.projectRoot(for: fixture.projectID), publishedRoot)
+            XCTAssertEqual(model.selectedTicketID, publishedTicketID)
+            XCTAssertEqual(model.selectedReviewItemID, publishedReviewItemID)
+            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+            XCTAssertNil(model.dashboardError)
+        }
+    }
+
+    @MainActor
+    func testRR9DebugFixtureSeedsIdempotentlyAndSelectsScenarioRouteWithoutOrdinarySampleData() async throws {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9Capture-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
+        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
+        let model = AppModel(
+            store: store,
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: .crossPhaseDetail,
+            rr9ActivePhaseCaptureRootDirectory: directory.appendingPathComponent("RR9ActivePhaseCaptureRoots")
+        )
+
+        await model.loadDashboard()
+        let first = model.dashboard
+        await model.loadDashboard()
+
+        XCTAssertEqual(model.dashboard, first)
+        XCTAssertEqual(model.selection, .phaseBoard(RR9ActivePhaseCaptureFixture.primaryProjectID))
+        XCTAssertEqual(model.currentProject?.phases.count, 6)
+        XCTAssertEqual(
+            model.dashboard?.board(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?
+                .detail(for: RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID)?
+                .requires.map(\.id),
+            [RR9ActivePhaseCaptureFixture.crossPhaseTargetTicketID]
+        )
+        let state = try await store.read { connection in
+            (
+                try connection.scalarInt("SELECT COUNT(*) FROM projects"),
+                try connection.scalarInt("SELECT COUNT(*) FROM project_bookmarks"),
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests")
+            )
+        }
+        XCTAssertEqual(state.0, 7)
+        XCTAssertEqual(state.1, 6)
+        XCTAssertEqual(state.2, 0)
+        XCTAssertFalse(model.dashboard?.projects.contains { $0.id == DashboardSampleData.projectID } == true)
+    }
+
+    @MainActor
+    func testRR9DebugFixtureScenariosExposeDeterministicRoutesStatusesAndOneShotRecovery() async throws {
+        let noAlternative = try await makeRR9CaptureModel(scenario: .noAlternative)
+        XCTAssertEqual(noAlternative.model.selection, .projectOverview(RR9ActivePhaseCaptureFixture.soleProjectID))
+        let soleProject = try XCTUnwrap(noAlternative.model.currentProject)
+        let solePresentation = ActivePhaseSelectorPresentation(project: soleProject, status: .idle)
+        XCTAssertTrue(solePresentation.isDisabled)
+        XCTAssertEqual(solePresentation.accessibilityHelp, "No other phases are available for this project.")
+
+        let noPointer = try await makeRR9CaptureModel(scenario: .noActivePointer)
+        XCTAssertEqual(noPointer.model.selection, .projectOverview(RR9ActivePhaseCaptureFixture.noPointerProjectID))
+        XCTAssertNil(noPointer.model.currentProject?.activePhaseID)
+        XCTAssertEqual(noPointer.model.currentProject?.phases.count, 2)
+        XCTAssertNil(noPointer.model.dashboard?.board(for: RR9ActivePhaseCaptureFixture.noPointerProjectID))
+        XCTAssertEqual(
+            ActivePhaseSelectorPresentation(
+                project: try XCTUnwrap(noPointer.model.currentProject),
+                status: .idle
+            ).accessibilityValue,
+            "No active phase"
+        )
+
+        let empty = try await makeRR9CaptureModel(scenario: .emptyPhase)
+        XCTAssertEqual(empty.model.selection, .phaseBoard(RR9ActivePhaseCaptureFixture.emptyProjectID))
+        XCTAssertEqual(empty.model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyCurrentPhaseID)
+        await empty.model.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.emptyProjectID,
+            phaseID: RR9ActivePhaseCaptureFixture.emptyTargetPhaseID
+        )
+        XCTAssertEqual(empty.model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyTargetPhaseID)
+        XCTAssertEqual(
+            empty.model.dashboard?.board(for: RR9ActivePhaseCaptureFixture.emptyProjectID)?.lanes.map(\.count),
+            [0, 0, 0, 0, 0]
+        )
+        XCTAssertNil(empty.model.dependencyGraph(for: RR9ActivePhaseCaptureFixture.emptyProjectID))
+
+        let faultCases: [(RR9ActivePhaseCaptureScenario, String)] = [
+            (.mutationFailure, "active-phase-mutation-failed"),
+            (.unavailable, "active-phase-unavailable"),
+        ]
+        for (scenario, expectedAccessibilityID) in faultCases {
+            let fixture = try await makeRR9CaptureModel(scenario: scenario)
+            await fixture.model.setActivePhase(
+                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
+                phaseID: RR9ActivePhaseCaptureFixture.roadmapPhaseID
+            )
+            guard case let .mutationFailed(presentation, canReauthorize) = fixture.model.activePhaseSelectionStatus(
+                for: RR9ActivePhaseCaptureFixture.primaryProjectID
+            ) else {
+                return XCTFail("Expected Debug fault presentation for \(scenario)")
+            }
+            XCTAssertEqual(presentation.accessibilityID, expectedAccessibilityID)
+            XCTAssertFalse(canReauthorize)
+            let state = try await rr9SelectionState(
+                store: fixture.store,
+                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID
+            )
+            XCTAssertEqual(state.commandRequests, 0)
+            XCTAssertEqual(state.selectionAudits, 0)
+        }
+
+        let busy = try await makeRR9CaptureModel(scenario: .busy)
+        await busy.model.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
+            phaseID: RR9ActivePhaseCaptureFixture.roadmapPhaseID
+        )
+        XCTAssertEqual(
+            busy.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
+            .saving(RR9ActivePhaseCaptureFixture.roadmapPhaseID)
+        )
+        let busyState = try await rr9SelectionState(
+            store: busy.store,
+            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID
+        )
+        XCTAssertEqual(busyState.commandRequests, 0)
+        XCTAssertEqual(busyState.selectionAudits, 0)
+
+        let authorization = try await makeRR9CaptureModel(scenario: .authorizationFailure)
+        let authorizationTarget = PhaseID(rawValue: "rr9-authorization-target")
+        await authorization.model.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.authorizationProjectID,
+            phaseID: authorizationTarget
+        )
+        guard case let .mutationFailed(authorizationFailure, canReauthorize) = authorization.model.activePhaseSelectionStatus(
+            for: RR9ActivePhaseCaptureFixture.authorizationProjectID
+        ) else {
+            return XCTFail("Expected missing-bookmark recovery")
+        }
+        XCTAssertEqual(authorizationFailure.accessibilityID, "active-phase-authorization-failed")
+        XCTAssertTrue(canReauthorize)
+
+        let happy = try await makeRR9CaptureModel(scenario: .happy)
+        await happy.model.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.happyProjectID,
+            phaseID: RR9ActivePhaseCaptureFixture.happyTargetPhaseID
+        )
+        XCTAssertEqual(happy.model.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.happyTargetPhaseID)
+        XCTAssertEqual(
+            happy.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.happyProjectID),
+            .idle
+        )
+
+        let saved = try await makeRR9CaptureModel(scenario: .savedRefresh)
+        let savedTarget = PhaseID(rawValue: "rr9-saved-target")
+        await saved.model.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID,
+            phaseID: savedTarget
+        )
+        XCTAssertEqual(
+            saved.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.savedRefreshProjectID),
+            .savedNeedsReload(savedTarget, "Saved target")
+        )
+        let committed = try await rr9SelectionState(
+            store: saved.store,
+            projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID
+        )
+        XCTAssertEqual(committed.commandRequests, 1)
+        XCTAssertEqual(committed.selectionAudits, 1)
+        await saved.model.reloadAfterActivePhaseSelection(projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID)
+        XCTAssertEqual(
+            saved.model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.savedRefreshProjectID),
+            .idle
+        )
+        XCTAssertEqual(saved.model.currentProject?.activePhaseID, savedTarget)
+        let recovered = try await rr9SelectionState(
+            store: saved.store,
+            projectID: RR9ActivePhaseCaptureFixture.savedRefreshProjectID
+        )
+        XCTAssertEqual(recovered, committed)
+    }
+
+    @MainActor
+    func testRR9MutatingCaptureScenariosStayIsolatedAcrossSameContainerRelaunches() async throws {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9Capture-Relaunch-\(UUID().uuidString)", isDirectory: true)
+        let roots = directory.appendingPathComponent("RR9ActivePhaseCaptureRoots", isDirectory: true)
+        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
+        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
+
+        let happy = AppModel(
+            store: store,
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: .happy,
+            rr9ActivePhaseCaptureRootDirectory: roots
+        )
+        await happy.loadDashboard()
+        await happy.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.happyProjectID,
+            phaseID: RR9ActivePhaseCaptureFixture.happyTargetPhaseID
+        )
+        XCTAssertEqual(happy.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.happyTargetPhaseID)
+
+        let empty = AppModel(
+            store: store,
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: .emptyPhase,
+            rr9ActivePhaseCaptureRootDirectory: roots
+        )
+        await empty.loadDashboard()
+        XCTAssertEqual(empty.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyCurrentPhaseID)
+        await empty.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.emptyProjectID,
+            phaseID: RR9ActivePhaseCaptureFixture.emptyTargetPhaseID
+        )
+        XCTAssertEqual(empty.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.emptyTargetPhaseID)
+
+        let noPointer = AppModel(
+            store: store,
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: .noActivePointer,
+            rr9ActivePhaseCaptureRootDirectory: roots
+        )
+        await noPointer.loadDashboard()
+        let pointerTarget = try XCTUnwrap(noPointer.currentProject?.phases.first?.id)
+        await noPointer.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.noPointerProjectID,
+            phaseID: pointerTarget
+        )
+        XCTAssertEqual(noPointer.currentProject?.activePhaseID, pointerTarget)
+
+        let crossPhase = AppModel(
+            store: store,
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: .crossPhaseDetail,
+            rr9ActivePhaseCaptureRootDirectory: roots
+        )
+        await crossPhase.loadDashboard()
+        XCTAssertEqual(crossPhase.currentProject?.activePhaseID, RR9ActivePhaseCaptureFixture.currentPhaseID)
+        XCTAssertEqual(
+            crossPhase.dashboard?.board(for: RR9ActivePhaseCaptureFixture.primaryProjectID)?
+                .detail(for: RR9ActivePhaseCaptureFixture.crossPhaseSourceTicketID)?
+                .requires.map(\.id),
+            [RR9ActivePhaseCaptureFixture.crossPhaseTargetTicketID]
+        )
+    }
+
+    @MainActor
+    private func makeRR9CaptureModel(
+        scenario: RR9ActivePhaseCaptureScenario
+    ) async throws -> (model: AppModel, store: DeliveryStore) {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9Capture-\(scenario.rawValue)-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
+        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
+        let model = AppModel(
+            store: store,
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: scenario,
+            rr9ActivePhaseCaptureRootDirectory: directory.appendingPathComponent("RR9ActivePhaseCaptureRoots")
+        )
+        await model.loadDashboard()
+        return (model, store)
+    }
+
+    @MainActor
+    private func makeRR9OwnerFixture(
+        hasBookmark: Bool = true,
+        blockAuthorization: Bool = false,
+        hasActivePointer: Bool = true
+    ) async throws -> RR9OwnerFixture {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9Owner-\(UUID().uuidString)", isDirectory: true)
+        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
+        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
+        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
+        let bookmarks = RR9RouteBookmarkStore(blocksAccess: blockAuthorization)
+        let bookmark = try bookmarks.makeBookmark(for: projectRoot)
+        try await store.transact(actor: .init(id: "fixture"), reason: "Seed RR-R9 owner fixture") { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('rr9-owner-project', 'RR-R9 Owner')")
+            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('rr9-owner-root', 'rr9-owner-project', ?)", bindings: [.text(projectRoot.path)])
+            if hasBookmark {
+                try connection.execute(
+                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('rr9-owner-project', ?, ?, 0)",
+                    bindings: [.text(projectRoot.path), .blob(bookmark)]
+                )
+            }
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'rr9-owner-project', 'Current')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-roadmap', 'rr9-owner-project', 'Roadmap')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-empty', 'rr9-owner-project', 'Empty')")
+            if hasActivePointer {
+                try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('rr9-owner-project', 'phase-current')")
+            }
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-1', 'rr9-owner-project', 'phase-current', 'Current work remains coherent.', 'in_progress')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROAD-1', 'rr9-owner-project', 'phase-roadmap', 'Roadmap backlog one.', 'backlog')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROAD-2', 'rr9-owner-project', 'phase-roadmap', 'Roadmap backlog two.', 'backlog')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ROAD-X', 'rr9-owner-project', 'phase-roadmap', 'Roadmap blocker.', 'blocked')")
+            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('road-dependency', 'rr9-owner-project', 'ROAD-X', 'ROAD-1')")
+        }
+        let projectID = ProjectID(rawValue: "rr9-owner-project")
+        return RR9OwnerFixture(
+            databaseURL: directory.appendingPathComponent("store.sqlite"),
+            projectRoot: projectRoot,
+            projectID: projectID,
+            currentPhaseID: .init(rawValue: "phase-current"),
+            roadmapPhaseID: .init(rawValue: "phase-roadmap"),
+            emptyPhaseID: .init(rawValue: "phase-empty"),
+            store: store,
+            bookmarks: bookmarks,
+            onboarding: FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
+        )
+    }
+
+    @MainActor
+    private func rr9SelectionState(
+        store: DeliveryStore,
+        projectID: ProjectID
+    ) async throws -> RR9SelectionState {
+        try await store.read { connection in
+            RR9SelectionState(
+                activePhaseID: try connection.scalarText(
+                    "SELECT phase_id FROM project_active_phases WHERE project_id = ?",
+                    bindings: [.text(projectID.rawValue)]
+                ),
+                commandRequests: try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
+                selectionAudits: try connection.scalarInt(
+                    "SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Owner selected active phase %'"
+                ) ?? -1,
+                actorID: try connection.scalarText(
+                    "SELECT actor_id FROM audit_events WHERE reason LIKE 'Owner selected active phase %' ORDER BY rowid DESC LIMIT 1"
+                )
+            )
+        }
+    }
+
+}
+
+private struct RR9OwnerFixture {
+    let databaseURL: URL
+    let projectRoot: URL
+    let projectID: ProjectID
+    let currentPhaseID: PhaseID
+    let roadmapPhaseID: PhaseID
+    let emptyPhaseID: PhaseID
+    let store: DeliveryStore
+    let bookmarks: RR9RouteBookmarkStore
+    let onboarding: FolderProjectOnboarding
+}
+
+private struct RR9SelectionState: Equatable {
+    let activePhaseID: String?
+    let commandRequests: Int64
+    let selectionAudits: Int64
+    let actorID: String?
+}
+
+private final class RR9RequestIDCounter: @unchecked Sendable {
+    private let lock = NSLock()
+    private var generated = 0
+
+    var count: Int { lock.withLock { generated } }
+
+    func next() -> UUID {
+        lock.withLock { generated += 1 }
+        return UUID()
+    }
+}
+
+private final class RR9RouteBookmarkStore: @unchecked Sendable, ProjectBookmarkStoring {
+    private let gate: RR9RouteAccessGate?
+    private let lock = NSLock()
+    private var failureMode = RR9BookmarkFailureMode.none
+
+    init(blocksAccess: Bool) {
+        gate = blocksAccess ? RR9RouteAccessGate() : nil
+    }
+
+    func makeBookmark(for url: URL) throws -> Data {
+        Data(url.standardizedFileURL.resolvingSymlinksInPath().path.utf8)
+    }
+
+    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
+        let url = URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self))
+        return try lock.withLock {
+            switch failureMode {
+            case .none, .accessDenied:
+                return ResolvedProjectBookmark(url: url, isStale: false)
+            case .stale:
+                return ResolvedProjectBookmark(url: url, isStale: true)
+            case .resolutionFailure:
+                throw ProjectBookmarkError.bookmarkResolutionFailed
+            case let .mismatchedRoot(root):
+                return ResolvedProjectBookmark(url: root, isStale: false)
+            }
+        }
+    }
+
+    func withSecurityScopedAccess<T: Sendable>(
+        bookmark: Data,
+        _ body: @Sendable (ResolvedProjectBookmark) async throws -> T
+    ) async throws -> T {
+        let resolved = try resolve(bookmark)
+        if lock.withLock({ failureMode == .accessDenied }) {
+            throw ProjectBookmarkError.securityScopeAccessDenied
+        }
+        if let gate { await gate.enterAndWait() }
+        return try await body(resolved)
+    }
+
+    func setFailureMode(_ mode: RR9BookmarkFailureMode) {
+        lock.withLock { failureMode = mode }
+    }
+
+    func waitUntilAccessEntered() async {
+        await gate?.waitUntilEntered()
+    }
+
+    func armAccessGate() async {
+        await gate?.arm()
+    }
+
+    func releaseAccess() async {
+        await gate?.release()
+    }
+}
+
+private enum RR9BookmarkFailureMode: Equatable, CustomStringConvertible {
+    case none
+    case stale
+    case resolutionFailure
+    case accessDenied
+    case mismatchedRoot(URL)
+
+    var description: String {
+        switch self {
+        case .none: "none"
+        case .stale: "stale"
+        case .resolutionFailure: "resolution failure"
+        case .accessDenied: "access denied"
+        case .mismatchedRoot: "mismatched root"
+        }
+    }
+}
+
+private actor RR9RouteAccessGate {
+    private var armed = false
+    private var entered = false
+    private var released = false
+    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
+    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
+
+    func enterAndWait() async {
+        guard armed else { return }
+        entered = true
+        enteredContinuations.forEach { $0.resume() }
+        enteredContinuations.removeAll()
+        guard !released else { return }
+        await withCheckedContinuation { releaseContinuations.append($0) }
+    }
+
+    func arm() {
+        armed = true
+    }
+
+    func waitUntilEntered() async {
+        guard !entered else { return }
+        await withCheckedContinuation { enteredContinuations.append($0) }
+    }
+
+    func release() {
+        released = true
+        releaseContinuations.forEach { $0.resume() }
+        releaseContinuations.removeAll()
+    }
+}
+
+private enum RR9StaleCompletion: CaseIterable {
+    case success
+    case failure
+}
+
+private actor RR9InterleavingDashboardLoader {
+    private let staleCompletion: RR9StaleCompletion
+    private var callCount = 0
+    private var initialProjection: DashboardProjection?
+    private var olderEntered = false
+    private var olderReleased = false
+    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
+    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
+
+    init(staleCompletion: RR9StaleCompletion) {
+        self.staleCompletion = staleCompletion
+    }
+
+    func load(from store: DeliveryStore) async throws -> DashboardProjection {
+        callCount += 1
+        if callCount == 1 {
+            let projection = try await DashboardProjection.load(from: store)
+            initialProjection = projection
+            return projection
+        }
+        if callCount == 2 {
+            olderEntered = true
+            enteredContinuations.forEach { $0.resume() }
+            enteredContinuations.removeAll()
+            if !olderReleased {
+                await withCheckedContinuation { releaseContinuations.append($0) }
+            }
+            if staleCompletion == .failure { throw RouteProjectionError.forcedRefreshFailure }
+            return initialProjection ?? DashboardProjection(projects: [], boards: [:])
+        }
+        return try await DashboardProjection.load(from: store)
+    }
+
+    func waitUntilOlderReloadEntered() async {
+        guard !olderEntered else { return }
+        await withCheckedContinuation { enteredContinuations.append($0) }
+    }
+
+    func releaseOlderReload() {
+        olderReleased = true
+        releaseContinuations.forEach { $0.resume() }
+        releaseContinuations.removeAll()
+    }
+}
+
+private actor RR9TargetMismatchDashboardLoader {
+    private let failCommittedReload: Bool
+    private var callCount = 0
+    private var initialProjection: DashboardProjection?
+
+    init(failCommittedReload: Bool) {
+        self.failCommittedReload = failCommittedReload
+    }
+
+    func load(from store: DeliveryStore) async throws -> DashboardProjection {
+        callCount += 1
+        if callCount == 1 {
+            let projection = try await DashboardProjection.load(from: store)
+            initialProjection = projection
+            return projection
+        }
+        if callCount == 2, failCommittedReload {
+            throw RouteProjectionError.forcedRefreshFailure
+        }
+        return initialProjection ?? DashboardProjection(projects: [], boards: [:])
+    }
+}
+
+private actor RR9SequencedReviewInboxLoader {
+    private let failingCalls: Set<Int>
+    private var callCount = 0
+
+    init(failingCalls: Set<Int>) {
+        self.failingCalls = failingCalls
+    }
+
+    func load(from store: DeliveryStore, projectID: ProjectID) async throws -> ReviewInboxProjection {
+        callCount += 1
+        guard !failingCalls.contains(callCount) else {
+            throw RouteProjectionError.forcedRefreshFailure
+        }
+        return try await ReviewInboxProjection.load(from: store, projectID: projectID)
+    }
 }
 
 private actor LaunchOrderRecorder {
     enum Event: Equatable { case codexObservation, dashboard, pluginStatus }
     private var events: [Event] = []
 
     func record(_ event: Event) { events.append(event) }
     func snapshot() -> [Event] { events }
 }
 
```

### `ReleaseRadarTests/NotificationAcceptanceTests.swift`

Pre-edit blob: `203c7ad6ba89648a77c143f36928a2b8b206f1f2`  
Current blob: `d4595db72e52425484e07c47cc14c0bb45ac56c0`

```diff
--- a/ReleaseRadarTests/NotificationAcceptanceTests.swift
+++ b/ReleaseRadarTests/NotificationAcceptanceTests.swift
@@ -757,20 +757,149 @@
         let updatedCount = await model.notificationCount
         let activity = await model.activity(for: .init(rawValue: "project-1"))
         XCTAssertEqual(updatedCount, initialCount + 1)
         let notification = try XCTUnwrap(activity?.items.first {
             $0.source == .notification && $0.title == "Delivery item needs review"
         })
         XCTAssertEqual(notification.notificationState, .failed)
         XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
     }
 
+    func testSuccessfulCallbacksBeforeDashboardRegistrationCoalesceRefreshBeforeNotificationDrain() async throws {
+        let fixture = try await makeFixture(firstDashboardOpened: true)
+        let coordinator = AppNotificationCoordinator(
+            store: fixture.store,
+            dispatcher: PushoverNotificationDispatcher(
+                store: fixture.store,
+                credentials: StaticPushoverCredentialsProvider(credentials: nil),
+                transport: CountingTransport()
+            )
+        )
+        let order = RR9CoordinatorOrderRecorder()
+        await coordinator.setActivityRefreshHandler { _ in
+            await order.recordNotificationDrain()
+        }
+        let envelope = AgentCommandEnvelope(
+            version: 1,
+            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909071")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Queue refresh before handler registration",
+            command: .requestReview(
+                id: "pre-registration-review",
+                ticketID: nil,
+                kind: "agent_request",
+                summary: "Review"
+            )
+        )
+        let result = await fixture.dispatcher.dispatch(envelope)
+        XCTAssertNil(result.error)
+
+        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
+        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
+
+        let beforeRegistration = await order.snapshot()
+        let beforeRegistrationState = try await notificationState(
+            for: "pre-registration-review",
+            store: fixture.store
+        )
+        XCTAssertEqual(beforeRegistration.refreshCount, 0)
+        XCTAssertEqual(beforeRegistration.notificationDrainCount, 0)
+        XCTAssertEqual(beforeRegistrationState, .queued)
+
+        let registration = Task {
+            await coordinator.setDashboardRefreshHandler {
+                await order.beginRefreshAndWait()
+            }
+        }
+        await order.waitUntilRefreshEntered()
+        let duringRefresh = await order.snapshot()
+        let duringRefreshState = try await notificationState(
+            for: "pre-registration-review",
+            store: fixture.store
+        )
+        XCTAssertEqual(duringRefresh.refreshCount, 1)
+        XCTAssertEqual(duringRefresh.notificationDrainCount, 0)
+        XCTAssertEqual(duringRefreshState, .queued)
+
+        await order.releaseRefresh()
+        await registration.value
+        let afterDrain = await order.snapshot()
+        let afterDrainState = try await notificationState(
+            for: "pre-registration-review",
+            store: fixture.store
+        )
+        XCTAssertEqual(afterDrain.refreshCount, 1)
+        XCTAssertEqual(afterDrain.notificationDrainCount, 1)
+        XCTAssertEqual(afterDrainState, .failed)
+    }
+
+    func testRegisteredSuccessfulCallbackRefreshesBeforeNotificationDrainAndFailedResultQueuesNothing() async throws {
+        let fixture = try await makeFixture(firstDashboardOpened: true)
+        let coordinator = AppNotificationCoordinator(
+            store: fixture.store,
+            dispatcher: PushoverNotificationDispatcher(
+                store: fixture.store,
+                credentials: StaticPushoverCredentialsProvider(credentials: nil),
+                transport: CountingTransport()
+            )
+        )
+        let order = RR9CoordinatorOrderRecorder()
+        await coordinator.setActivityRefreshHandler { _ in
+            await order.recordNotificationDrain()
+        }
+        await coordinator.setDashboardRefreshHandler {
+            await order.beginRefreshAndWait()
+        }
+        let envelope = AgentCommandEnvelope(
+            version: 1,
+            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909072")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Queue registered refresh",
+            command: .requestReview(
+                id: "registered-refresh-review",
+                ticketID: nil,
+                kind: "agent_request",
+                summary: "Review"
+            )
+        )
+        let result = await fixture.dispatcher.dispatch(envelope)
+        XCTAssertNil(result.error)
+        let callback = Task {
+            await coordinator.dispatchAfterCommittedCommand(envelope, result: result)
+        }
+
+        await order.waitUntilRefreshEntered()
+        let duringRefresh = await order.snapshot()
+        let duringRefreshState = try await notificationState(
+            for: "registered-refresh-review",
+            store: fixture.store
+        )
+        XCTAssertEqual(duringRefresh.refreshCount, 1)
+        XCTAssertEqual(duringRefresh.notificationDrainCount, 0)
+        XCTAssertEqual(duringRefreshState, .queued)
+        await order.releaseRefresh()
+        await callback.value
+        let afterDrain = await order.snapshot()
+        let afterDrainState = try await notificationState(
+            for: "registered-refresh-review",
+            store: fixture.store
+        )
+        XCTAssertEqual(afterDrain.notificationDrainCount, 1)
+        XCTAssertEqual(afterDrainState, .failed)
+
+        let failed = AgentCommandResult(entityIDs: [], auditEventID: nil, error: .appUnavailable)
+        await coordinator.dispatchAfterCommittedCommand(envelope, result: failed)
+        let afterFailedResult = await order.snapshot()
+        XCTAssertEqual(afterFailedResult.refreshCount, 1)
+        XCTAssertEqual(afterFailedResult.notificationDrainCount, 1)
+    }
+
     func testCoordinatorRefreshesDashboardAfterBridgeCommit() async throws {
         let fixture = try await makeFixture(firstDashboardOpened: true)
         try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Select active phase") { connection in
             try connection.execute(
                 "INSERT INTO project_active_phases (project_id, phase_id) VALUES ('project-1', 'phase-1')"
             )
         }
         let coordinator = AppNotificationCoordinator(
             store: fixture.store,
             dispatcher: PushoverNotificationDispatcher(
@@ -812,20 +941,33 @@
         let result = await fixture.dispatcher.dispatch(.init(
             version: 1,
             requestID: UUID(uuidString: requestID)!,
             projectRoot: fixture.projectRoot.path,
             reason: "Transition RR-09 to \(lane.rawValue)",
             command: .transitionTicket(ticketID: "RR-09", lane: lane)
         ))
         XCTAssertNil(result.error)
     }
 
+    private func notificationState(
+        for subjectID: String,
+        store: DeliveryStore
+    ) async throws -> NotificationDeliveryState? {
+        let rawState = try await store.read { connection in
+            try connection.scalarText(
+                "SELECT state FROM notification_events WHERE subject_id = ?",
+                bindings: [.text(subjectID)]
+            )
+        }
+        return rawState.flatMap(NotificationDeliveryState.init(rawValue:))
+    }
+
     private struct Fixture {
         let databaseURL: URL
         let projectRoot: URL
         let store: DeliveryStore
         let registry: InMemoryAuthorizedProjectRegistry
         let dispatcher: AgentCommandDispatcher
     }
 
     private func makeFixture(firstDashboardOpened: Bool) async throws -> Fixture {
         let directory = FileManager.default.temporaryDirectory
@@ -847,20 +989,57 @@
         let registry = InMemoryAuthorizedProjectRegistry(projects: [
             .init(projectID: .init(rawValue: "project-1"), canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
         ])
         return Fixture(
             databaseURL: databaseURL,
             projectRoot: projectRoot,
             store: store,
             registry: registry,
             dispatcher: AgentCommandDispatcher(store: store, projectRegistry: registry)
         )
+    }
+}
+
+private actor RR9CoordinatorOrderRecorder {
+    private(set) var refreshCount = 0
+    private(set) var notificationDrainCount = 0
+    private var refreshEntered = false
+    private var refreshReleased = false
+    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
+    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
+
+    func beginRefreshAndWait() async {
+        refreshCount += 1
+        refreshEntered = true
+        enteredContinuations.forEach { $0.resume() }
+        enteredContinuations.removeAll()
+        guard !refreshReleased else { return }
+        await withCheckedContinuation { releaseContinuations.append($0) }
+    }
+
+    func waitUntilRefreshEntered() async {
+        guard !refreshEntered else { return }
+        await withCheckedContinuation { enteredContinuations.append($0) }
+    }
+
+    func releaseRefresh() {
+        refreshReleased = true
+        releaseContinuations.forEach { $0.resume() }
+        releaseContinuations.removeAll()
+    }
+
+    func recordNotificationDrain() {
+        notificationDrainCount += 1
+    }
+
+    func snapshot() -> (refreshCount: Int, notificationDrainCount: Int) {
+        (refreshCount, notificationDrainCount)
     }
 }
 
 private actor CountingTransport: PushoverTransport {
     private(set) var sendCount = 0
 
     func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
         sendCount += 1
         return .init(requestID: "provider-request")
     }
```

### `ReleaseRadar/Projects/ActivePhaseSelector.swift`

Pre-edit state: absent  
Current blob: `3bccd435b3d22d32a0c52654579d9cf5d31b7f77`

```diff
--- /dev/null
+++ b/ReleaseRadar/Projects/ActivePhaseSelector.swift
@@ -0,0 +1,185 @@
+import AppKit
+import ReleaseRadarCore
+import SwiftUI
+
+enum ActivePhaseSelectorSurface: String, Sendable {
+    case overview
+    case board
+
+    var accessibilityIdentifier: String {
+        "active-phase-selector-\(rawValue)"
+    }
+}
+
+struct ActivePhaseSelectorPresentation: Equatable, Sendable {
+    let project: ProjectDashboardProjection
+    let status: ActivePhaseSelectionStatus
+
+    var isSaving: Bool {
+        if case .saving = status { return true }
+        return false
+    }
+
+    var isDisabled: Bool {
+        if project.phases.isEmpty { return true }
+        switch status {
+        case .saving, .savedNeedsReload:
+            return true
+        case .idle, .mutationFailed:
+            return project.phases.count == 1 && project.phases.first?.id == project.activePhaseID
+        }
+    }
+
+    var accessibilityValue: String {
+        if isSaving { return "Saving active phase" }
+        guard let activePhaseID = project.activePhaseID,
+              let phase = project.phases.first(where: { $0.id == activePhaseID }) else {
+            return "No active phase"
+        }
+        return "\(phase.name) (\(phase.id.rawValue))"
+    }
+
+    var accessibilityHelp: String {
+        if project.phases.count == 1, project.phases.first?.id == project.activePhaseID {
+            return "No other phases are available for this project."
+        }
+        switch status {
+        case .saving:
+            return "Wait for the active phase change and dashboard refresh to finish."
+        case .savedNeedsReload:
+            return "The phase was saved. Reload the dashboard before making another selection."
+        case .idle, .mutationFailed:
+            return "Choose the persisted phase shown on this project's active board."
+        }
+    }
+}
+
+struct ActivePhaseSelector: View {
+    let project: ProjectDashboardProjection
+    let surface: ActivePhaseSelectorSurface
+    let status: ActivePhaseSelectionStatus
+    let onSelect: (PhaseID) async -> Void
+    let onReload: () async -> Void
+    let onReauthorize: (URL) async -> Void
+
+    private var presentation: ActivePhaseSelectorPresentation {
+        ActivePhaseSelectorPresentation(project: project, status: status)
+    }
+
+    var body: some View {
+        VStack(alignment: .leading, spacing: 8) {
+            Picker("Active phase", selection: selection) {
+                Text("No active phase")
+                    .tag(Optional<PhaseID>.none)
+                    .disabled(true)
+                ForEach(project.phases) { phase in
+                    Text(optionLabel(for: phase))
+                        .tag(Optional(phase.id))
+                }
+            }
+            .pickerStyle(.menu)
+            .fixedSize()
+            .disabled(presentation.isDisabled)
+            .accessibilityIdentifier(surface.accessibilityIdentifier)
+            .accessibilityValue(presentation.accessibilityValue)
+            .accessibilityHint(presentation.accessibilityHelp)
+
+            statusView
+        }
+    }
+
+    private var selection: Binding<PhaseID?> {
+        Binding(
+            get: { project.activePhaseID },
+            set: { phaseID in
+                guard let phaseID, phaseID != project.activePhaseID else { return }
+                Task { await onSelect(phaseID) }
+            }
+        )
+    }
+
+    private func optionLabel(for phase: ProjectPhaseProjection) -> String {
+        let duplicateName = project.phases.filter {
+            $0.name.compare(phase.name, options: .caseInsensitive) == .orderedSame
+        }.count > 1
+        return duplicateName ? "\(phase.name) · \(phase.id.rawValue)" : phase.name
+    }
+
+    @ViewBuilder
+    private var statusView: some View {
+        switch status {
+        case .idle:
+            EmptyView()
+        case .saving:
+            ProgressView("Saving active phase")
+                .controlSize(.small)
+                .accessibilityIdentifier("active-phase-saving")
+        case let .mutationFailed(failure, canReauthorize):
+            if canReauthorize {
+                FailureStateView(
+                    presentation: failure,
+                    style: .inline,
+                    actionTitle: "Locate / Reauthorize…",
+                    action: locateAndReauthorize
+                )
+            } else {
+                FailureStateView(presentation: failure, style: .inline)
+            }
+        case let .savedNeedsReload(_, phaseName):
+            FailureStateView(
+                presentation: FailureStatePresentation(
+                    title: "Active phase saved; refresh needed",
+                    detail: "\(phaseName) was saved as the active phase, but the visible dashboard has not refreshed. Reload the dashboard; do not select the phase again.",
+                    systemImage: "arrow.clockwise.circle",
+                    tone: .warning,
+                    accessibilityID: "active-phase-saved-refresh-needed"
+                ),
+                style: .inline,
+                actionTitle: "Reload dashboard",
+                action: { Task { await onReload() } }
+            )
+        }
+    }
+
+    private func locateAndReauthorize() {
+        let panel = NSOpenPanel()
+        panel.title = "Locate Project Folder"
+        panel.prompt = "Reauthorize"
+        panel.canChooseDirectories = true
+        panel.canChooseFiles = false
+        panel.allowsMultipleSelection = false
+        guard panel.runModal() == .OK, let folder = panel.url else { return }
+        Task { await onReauthorize(folder) }
+    }
+}
+
+struct ActivePhaseBoardRecoveryView: View {
+    let project: ProjectDashboardProjection
+    let status: ActivePhaseSelectionStatus
+    let onSelect: (PhaseID) async -> Void
+    let onReload: () async -> Void
+    let onReauthorize: (URL) async -> Void
+
+    var body: some View {
+        VStack(alignment: .leading, spacing: 18) {
+            Text(project.name)
+                .font(.caption.weight(.medium))
+                .foregroundStyle(.secondary)
+            Text("No active phase")
+                .font(.title2.weight(.semibold))
+            Text("Choose an existing phase to establish this project's active board. No phase or ticket history will be changed.")
+                .foregroundStyle(.secondary)
+            ActivePhaseSelector(
+                project: project,
+                surface: .board,
+                status: status,
+                onSelect: onSelect,
+                onReload: onReload,
+                onReauthorize: onReauthorize
+            )
+        }
+        .padding(28)
+        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
+        .accessibilityIdentifier("active-phase-board-recovery")
+    }
+}
```

### `ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift`

Pre-edit state: absent  
Current blob: `e9b973bf799781b0c236adfa009a599736b77271`

```diff
--- /dev/null
+++ b/ReleaseRadar/Projects/RR9ActivePhaseCaptureFixture.swift
@@ -0,0 +1,311 @@
+#if DEBUG
+import Foundation
+import ReleaseRadarCore
+
+enum RR9ActivePhaseCaptureScenario: String, Sendable {
+    case happy
+    case busy
+    case noAlternative = "no-alternative"
+    case mutationFailure = "mutation-failure"
+    case unavailable
+    case authorizationFailure = "authorization-failure"
+    case savedRefresh = "saved-refresh"
+    case emptyPhase = "empty-phase"
+    case noActivePointer = "no-active-pointer"
+    case crossPhaseDetail = "cross-phase-detail"
+}
+
+enum RR9ActivePhaseCaptureError: Error, LocalizedError {
+    case savedRefresh
+
+    var errorDescription: String? {
+        "The active phase was saved, but the dashboard refresh failed."
+    }
+}
+
+enum RR9ActivePhaseCaptureFixture {
+    static let primaryProjectID = ProjectID(rawValue: "rr9-capture-primary")
+    static let happyProjectID = ProjectID(rawValue: "rr9-capture-happy")
+    static let emptyProjectID = ProjectID(rawValue: "rr9-capture-empty")
+    static let soleProjectID = ProjectID(rawValue: "rr9-capture-sole")
+    static let noPointerProjectID = ProjectID(rawValue: "rr9-capture-no-pointer")
+    static let authorizationProjectID = ProjectID(rawValue: "rr9-capture-authorization")
+    static let savedRefreshProjectID = ProjectID(rawValue: "rr9-capture-saved-refresh")
+
+    static let currentPhaseID = PhaseID(rawValue: "phase-current")
+    static let roadmapPhaseID = PhaseID(rawValue: "phase-roadmap")
+    static let emptyPhaseID = PhaseID(rawValue: "phase-empty")
+    static let happyCurrentPhaseID = PhaseID(rawValue: "rr9-happy-current")
+    static let happyTargetPhaseID = PhaseID(rawValue: "rr9-happy-target")
+    static let emptyCurrentPhaseID = PhaseID(rawValue: "rr9-empty-current")
+    static let emptyTargetPhaseID = PhaseID(rawValue: "rr9-empty-target")
+    static let crossPhaseSourceTicketID = TicketID(rawValue: "RR9-CURRENT-CROSS")
+    static let crossPhaseTargetTicketID = TicketID(rawValue: "RR9-ROADMAP-TARGET")
+
+    private struct AuthorizedRoot: Sendable {
+        let projectID: ProjectID
+        let rootID: String
+        let folderName: String
+    }
+
+    static func projectID(for scenario: RR9ActivePhaseCaptureScenario) -> ProjectID {
+        switch scenario {
+        case .happy:
+            happyProjectID
+        case .emptyPhase:
+            emptyProjectID
+        case .noAlternative:
+            soleProjectID
+        case .authorizationFailure:
+            authorizationProjectID
+        case .savedRefresh:
+            savedRefreshProjectID
+        case .noActivePointer:
+            noPointerProjectID
+        case .busy, .mutationFailure, .unavailable, .crossPhaseDetail:
+            primaryProjectID
+        }
+    }
+
+    static func seedIfNeeded(
+        in store: DeliveryStore,
+        rootDirectory: URL,
+        scenario: RR9ActivePhaseCaptureScenario
+    ) async throws {
+        let exists = try await store.read { connection in
+            try connection.scalarInt(
+                "SELECT COUNT(*) FROM projects WHERE id = ?",
+                bindings: [.text(primaryProjectID.rawValue)]
+            ) == 1
+        }
+        guard !exists else { return }
+
+        let rootDirectory = canonical(rootDirectory)
+        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
+        let authorizedRoots = [
+            AuthorizedRoot(projectID: primaryProjectID, rootID: "rr9-capture-primary-root", folderName: "primary"),
+            AuthorizedRoot(projectID: happyProjectID, rootID: "rr9-capture-happy-root", folderName: "happy"),
+            AuthorizedRoot(projectID: emptyProjectID, rootID: "rr9-capture-empty-root", folderName: "empty"),
+            AuthorizedRoot(projectID: soleProjectID, rootID: "rr9-capture-sole-root", folderName: "sole"),
+            AuthorizedRoot(projectID: noPointerProjectID, rootID: "rr9-capture-no-pointer-root", folderName: "no-pointer"),
+            AuthorizedRoot(projectID: savedRefreshProjectID, rootID: "rr9-capture-saved-refresh-root", folderName: "saved-refresh"),
+        ]
+        let bookmarkStore = ProjectBookmarkStore()
+        var bookmarkFixtures: [(AuthorizedRoot, URL, Data)] = []
+        for root in authorizedRoots {
+            let url = canonical(rootDirectory.appendingPathComponent(root.folderName, isDirectory: true))
+            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
+            bookmarkFixtures.append((root, url, try bookmarkStore.makeBookmark(for: url)))
+        }
+        let authorizationRoot = canonical(
+            rootDirectory.appendingPathComponent("authorization", isDirectory: true)
+        )
+        try FileManager.default.createDirectory(at: authorizationRoot, withIntermediateDirectories: true)
+        let preparedBookmarkFixtures = bookmarkFixtures
+
+        try await store.transact(
+            actor: DeliveryActor(id: "release-radar.rr9-capture-seed"),
+            reason: "Seed RR-R9 active phase capture fixture",
+            auditEventID: AuditEventID(rawValue: "rr9-capture-seed-audit"),
+            auditScope: AuditScope(projectID: primaryProjectID, entityType: .phase, entityID: currentPhaseID.rawValue)
+        ) { connection in
+            try insertProject(primaryProjectID, name: "RR-R9 Active Phase", connection: connection)
+            try insertProject(happyProjectID, name: "RR-R9 Happy Path", connection: connection)
+            try insertProject(emptyProjectID, name: "RR-R9 Empty Target", connection: connection)
+            try insertProject(soleProjectID, name: "RR-R9 No Alternative", connection: connection)
+            try insertProject(noPointerProjectID, name: "RR-R9 No Active Pointer", connection: connection)
+            try insertProject(authorizationProjectID, name: "RR-R9 Authorization Recovery", connection: connection)
+            try insertProject(savedRefreshProjectID, name: "RR-R9 Saved Refresh", connection: connection)
+
+            for (root, url, bookmark) in preparedBookmarkFixtures {
+                try connection.execute(
+                    "INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)",
+                    bindings: [.text(root.rootID), .text(root.projectID.rawValue), .text(url.path)]
+                )
+                try connection.execute(
+                    "INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)",
+                    bindings: [.text(root.projectID.rawValue), .text(url.path), .blob(bookmark)]
+                )
+            }
+            try connection.execute(
+                "INSERT INTO project_roots (id, project_id, path) VALUES ('rr9-capture-authorization-root', ?, ?)",
+                bindings: [.text(authorizationProjectID.rawValue), .text(authorizationRoot.path)]
+            )
+
+            try insertPhase(currentPhaseID, projectID: primaryProjectID, name: "Current", connection: connection)
+            try insertPhase(PhaseID(rawValue: "phase-history"), projectID: primaryProjectID, name: "History", connection: connection)
+            try insertPhase(roadmapPhaseID, projectID: primaryProjectID, name: "Roadmap delivery", connection: connection)
+            try insertPhase(PhaseID(rawValue: "phase-order-z"), projectID: primaryProjectID, name: "ROADMAP", connection: connection)
+            try insertPhase(PhaseID(rawValue: "phase-order-a"), projectID: primaryProjectID, name: "Roadmap", connection: connection)
+            try insertPhase(emptyPhaseID, projectID: primaryProjectID, name: "Empty phase", connection: connection)
+            try insertActivePhase(currentPhaseID, projectID: primaryProjectID, connection: connection)
+
+            try insertTicket(
+                crossPhaseSourceTicketID,
+                projectID: primaryProjectID,
+                phaseID: currentPhaseID,
+                outcome: "Keeps a valid cross-phase requirement visible in ticket detail.",
+                lane: .inProgress,
+                connection: connection
+            )
+            try insertTicket(
+                TicketID(rawValue: "RR9-CURRENT-READY"),
+                projectID: primaryProjectID,
+                phaseID: currentPhaseID,
+                outcome: "Keeps the current board scoped to current work.",
+                lane: .backlog,
+                connection: connection
+            )
+            for index in 1...8 {
+                let id = index == 1 ? crossPhaseTargetTicketID : TicketID(rawValue: "RR9-ROADMAP-B\(index)")
+                try insertTicket(
+                    id,
+                    projectID: primaryProjectID,
+                    phaseID: roadmapPhaseID,
+                    outcome: "Roadmap backlog outcome \(index).",
+                    lane: .backlog,
+                    connection: connection
+                )
+            }
+            for index in 1...3 {
+                try insertTicket(
+                    TicketID(rawValue: "RR9-ROADMAP-X\(index)"),
+                    projectID: primaryProjectID,
+                    phaseID: roadmapPhaseID,
+                    outcome: "Roadmap blocked outcome \(index).",
+                    lane: .blocked,
+                    connection: connection
+                )
+            }
+            try insertTicket(
+                TicketID(rawValue: "RR9-HISTORY"),
+                projectID: primaryProjectID,
+                phaseID: PhaseID(rawValue: "phase-history"),
+                outcome: "Preserves accepted historical work.",
+                lane: .accepted,
+                connection: connection
+            )
+            try connection.execute(
+                "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('rr9-capture-cross-dependency', ?, ?, ?)",
+                bindings: [
+                    .text(primaryProjectID.rawValue),
+                    .text(crossPhaseSourceTicketID.rawValue),
+                    .text(crossPhaseTargetTicketID.rawValue),
+                ]
+            )
+            try connection.execute(
+                "INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('rr9-capture-roadmap-dependency', ?, 'RR9-ROADMAP-X1', ?)",
+                bindings: [.text(primaryProjectID.rawValue), .text(crossPhaseTargetTicketID.rawValue)]
+            )
+            try connection.execute(
+                "INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('rr9-capture-phase-dependency', ?, ?, ?)",
+                bindings: [.text(primaryProjectID.rawValue), .text(roadmapPhaseID.rawValue), .text(currentPhaseID.rawValue)]
+            )
+
+            try insertPhase(happyCurrentPhaseID, projectID: happyProjectID, name: "Current", connection: connection)
+            try insertPhase(happyTargetPhaseID, projectID: happyProjectID, name: "Roadmap delivery", connection: connection)
+            try insertActivePhase(happyCurrentPhaseID, projectID: happyProjectID, connection: connection)
+            try insertTicket(
+                TicketID(rawValue: "RR9-HAPPY-CURRENT"),
+                projectID: happyProjectID,
+                phaseID: happyCurrentPhaseID,
+                outcome: "Shows the happy-path current board before selection.",
+                lane: .inProgress,
+                connection: connection
+            )
+            try insertTicket(
+                TicketID(rawValue: "RR9-HAPPY-TARGET"),
+                projectID: happyProjectID,
+                phaseID: happyTargetPhaseID,
+                outcome: "Shows the coherently refreshed happy-path target board.",
+                lane: .backlog,
+                connection: connection
+            )
+
+            try insertPhase(emptyCurrentPhaseID, projectID: emptyProjectID, name: "Current", connection: connection)
+            try insertPhase(emptyTargetPhaseID, projectID: emptyProjectID, name: "Empty phase", connection: connection)
+            try insertActivePhase(emptyCurrentPhaseID, projectID: emptyProjectID, connection: connection)
+            try insertTicket(
+                TicketID(rawValue: "RR9-EMPTY-CURRENT"),
+                projectID: emptyProjectID,
+                phaseID: emptyCurrentPhaseID,
+                outcome: "Shows work clearing when the empty target becomes active.",
+                lane: .inProgress,
+                connection: connection
+            )
+
+            let solePhaseID = PhaseID(rawValue: "rr9-sole-phase")
+            try insertPhase(solePhaseID, projectID: soleProjectID, name: "Only phase", connection: connection)
+            try insertActivePhase(solePhaseID, projectID: soleProjectID, connection: connection)
+
+            try insertPhase(PhaseID(rawValue: "rr9-pointer-first"), projectID: noPointerProjectID, name: "First candidate", connection: connection)
+            try insertPhase(PhaseID(rawValue: "rr9-pointer-second"), projectID: noPointerProjectID, name: "Second candidate", connection: connection)
+
+            let authorizationCurrent = PhaseID(rawValue: "rr9-authorization-current")
+            try insertPhase(authorizationCurrent, projectID: authorizationProjectID, name: "Current", connection: connection)
+            try insertPhase(PhaseID(rawValue: "rr9-authorization-target"), projectID: authorizationProjectID, name: "Target", connection: connection)
+            try insertActivePhase(authorizationCurrent, projectID: authorizationProjectID, connection: connection)
+
+            let savedCurrent = PhaseID(rawValue: "rr9-saved-current")
+            try insertPhase(savedCurrent, projectID: savedRefreshProjectID, name: "Current", connection: connection)
+            try insertPhase(PhaseID(rawValue: "rr9-saved-target"), projectID: savedRefreshProjectID, name: "Saved target", connection: connection)
+            try insertActivePhase(savedCurrent, projectID: savedRefreshProjectID, connection: connection)
+        }
+    }
+
+    private static func canonical(_ url: URL) -> URL {
+        url.standardizedFileURL.resolvingSymlinksInPath()
+    }
+
+    private static func insertProject(
+        _ projectID: ProjectID,
+        name: String,
+        connection: SQLiteConnection
+    ) throws {
+        try connection.execute(
+            "INSERT INTO projects (id, name, first_dashboard_opened) VALUES (?, ?, 1)",
+            bindings: [.text(projectID.rawValue), .text(name)]
+        )
+    }
+
+    private static func insertPhase(
+        _ phaseID: PhaseID,
+        projectID: ProjectID,
+        name: String,
+        connection: SQLiteConnection
+    ) throws {
+        try connection.execute(
+            "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
+            bindings: [.text(phaseID.rawValue), .text(projectID.rawValue), .text(name)]
+        )
+    }
+
+    private static func insertActivePhase(
+        _ phaseID: PhaseID,
+        projectID: ProjectID,
+        connection: SQLiteConnection
+    ) throws {
+        try connection.execute(
+            "INSERT INTO project_active_phases (project_id, phase_id) VALUES (?, ?)",
+            bindings: [.text(projectID.rawValue), .text(phaseID.rawValue)]
+        )
+    }
+
+    private static func insertTicket(
+        _ ticketID: TicketID,
+        projectID: ProjectID,
+        phaseID: PhaseID,
+        outcome: String,
+        lane: TicketLane,
+        connection: SQLiteConnection
+    ) throws {
+        try connection.execute(
+            "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
+            bindings: [
+                .text(ticketID.rawValue), .text(projectID.rawValue), .text(phaseID.rawValue),
+                .text(outcome), .text(lane.rawValue),
+            ]
+        )
+    }
+}
+#endif
```


