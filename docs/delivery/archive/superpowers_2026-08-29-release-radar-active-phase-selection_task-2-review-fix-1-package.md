# RR-R9B review-loop 1 attributable correction package

This package isolates the four Required-review corrections from the exact first-review RR-R9B file blobs. Review it together with `task-2-review-package.md`, the current source, and the canonical task brief.

## Exact correction patch

### `ReleaseRadar/App/AppModel.swift`

Review-1 blob: `76ccd276c6c9a076fba1f4334fcb1daa7451b777`  
Corrected blob: `6680d2c2f7a651da98e8f2ff4fc11b100579166a`

```diff
--- review-1/ReleaseRadar/App/AppModel.swift
+++ corrected/ReleaseRadar/App/AppModel.swift
@@ -254,21 +254,21 @@
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
-            guard outcome != .failed else { return }
+            guard outcome == .published else { return }
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
@@ -454,21 +454,21 @@
 
     func reauthorizeActivePhaseProject(at folder: URL, projectID: ProjectID) async {
         guard case let .mutationFailed(_, canReauthorize) = activePhaseSelectionStatuses[projectID],
               canReauthorize else { return }
         do {
             try await projectOnboarding.reauthorizeProjectRoot(folder, for: projectID)
             activePhaseSelectionStatuses[projectID] = .idle
         } catch let error as ProjectAuthorizationError {
             activePhaseSelectionStatuses[projectID] = .mutationFailed(
                 FailureStatePresentation(activePhaseAuthorizationError: error),
-                canReauthorize: Self.canReauthorizeActivePhase(after: error)
+                canReauthorize: true
             )
         } catch {
             activePhaseSelectionStatuses[projectID] = .mutationFailed(
                 FailureStatePresentation(activePhaseAgentError: .internalFailure(error.localizedDescription)),
                 canReauthorize: true
             )
         }
     }
 
     func reloadDashboardAfterCommittedAgentCommand() async {
```

### `ReleaseRadar/App/ReleaseRadarApp.swift`

Review-1 blob: `640233363d2dd1081c41510a244470b5124b3da6`  
Corrected blob: `916e18c67469f60079fc8b829bdfbe6582de203b`

```diff
--- review-1/ReleaseRadar/App/ReleaseRadarApp.swift
+++ corrected/ReleaseRadar/App/ReleaseRadarApp.swift
@@ -11,23 +11,25 @@
     static func shouldSeedSampleData(arguments: [String], isDebugBuild: Bool) -> Bool {
         externalServicesSuppressed(arguments: arguments, isDebugBuild: isDebugBuild)
             && !arguments.contains("--rr10-empty-store")
     }
 
 #if DEBUG
     static func rr9ActivePhaseCaptureScenario(
         arguments: [String],
         isDebugBuild: Bool
     ) -> RR9ActivePhaseCaptureScenario? {
+        let captureFlag = "--rr10-capture"
+        let emptyStoreFlag = "--rr10-empty-store"
         guard isDebugBuild,
-              arguments.contains("--rr10-capture"),
-              arguments.contains("--rr10-empty-store") else { return nil }
+              arguments.filter({ $0 == captureFlag }).count == 1,
+              arguments.filter({ $0 == emptyStoreFlag }).count == 1 else { return nil }
         let prefix = "--rr9-active-phase-fixture="
         let scenarioArguments = arguments.filter { $0.hasPrefix(prefix) }
         guard scenarioArguments.count == 1 else { return nil }
         return RR9ActivePhaseCaptureScenario(
             rawValue: String(scenarioArguments[0].dropFirst(prefix.count))
         )
     }
 #endif
 }
 
```

### `ReleaseRadarTests/AppRouteTests.swift`

Review-1 blob: `9597624eb01f53af7d4038a38ac78eff51c36e24`  
Corrected blob: `e65f8ed50a9ace02be0914626300da96e7c9d871`

```diff
--- review-1/ReleaseRadarTests/AppRouteTests.swift
+++ corrected/ReleaseRadarTests/AppRouteTests.swift
@@ -1110,20 +1110,28 @@
         }
         XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
             arguments: ["--rr10-empty-store", "--rr9-active-phase-fixture=happy"],
             isDebugBuild: true
         ))
         XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
             arguments: ["--rr10-capture", "--rr9-active-phase-fixture=happy"],
             isDebugBuild: true
         ))
         XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: required + ["--rr10-capture", "--rr9-active-phase-fixture=happy"],
+            isDebugBuild: true
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
+            arguments: required + ["--rr10-empty-store", "--rr9-active-phase-fixture=happy"],
+            isDebugBuild: true
+        ))
+        XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
             arguments: required + ["--rr9-active-phase-fixture=unknown"],
             isDebugBuild: true
         ))
         XCTAssertNil(AppLaunchConfiguration.rr9ActivePhaseCaptureScenario(
             arguments: required + [
                 "--rr9-active-phase-fixture=happy",
                 "--rr9-active-phase-fixture=busy",
             ],
             isDebugBuild: true
         ))
@@ -1382,20 +1390,95 @@
         XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
         XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
         let reauthorized = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
         XCTAssertEqual(reauthorized.commandRequests, 0)
         await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
         XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
         XCTAssertEqual(requestIDs.count, 2)
     }
 
     @MainActor
+    func testRejectedReauthorizationFoldersFailClosedAndPreserveLocateRecovery() async throws {
+        for rejectedFolderKind in ["parent", "child", "different"] {
+            let fixture = try await makeRR9OwnerFixture(hasBookmark: false)
+            let child = fixture.projectRoot.appendingPathComponent("child", isDirectory: true)
+            let different = fixture.projectRoot.deletingLastPathComponent()
+                .appendingPathComponent("different", isDirectory: true)
+            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
+            try FileManager.default.createDirectory(at: different, withIntermediateDirectories: true)
+            let rejectedFolder = switch rejectedFolderKind {
+            case "parent": fixture.projectRoot.deletingLastPathComponent()
+            case "child": child
+            default: different
+            }
+            let requestIDs = RR9RequestIDCounter()
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                requestIDGenerator: { requestIDs.next() },
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+            let beforeRejectedAttempt = try await rr9SelectionState(
+                store: fixture.store,
+                projectID: fixture.projectID
+            )
+            let auditCountBeforeRejectedAttempt = try await fixture.store.read { connection in
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1
+            }
+
+            await model.reauthorizeActivePhaseProject(
+                at: rejectedFolder,
+                projectID: fixture.projectID
+            )
+
+            guard case let .mutationFailed(presentation, canReauthorize) = model.activePhaseSelectionStatus(
+                for: fixture.projectID
+            ) else {
+                XCTFail("Expected rejected \(rejectedFolderKind) folder to remain recoverable")
+                continue
+            }
+            XCTAssertEqual(presentation.accessibilityID, "active-phase-authorization-failed")
+            guard canReauthorize else {
+                XCTFail("Expected Locate to remain actionable after rejected \(rejectedFolderKind) folder")
+                continue
+            }
+            XCTAssertEqual(requestIDs.count, 1)
+            let afterRejectedAttempt = try await rr9SelectionState(
+                store: fixture.store,
+                projectID: fixture.projectID
+            )
+            let auditCountAfterRejectedAttempt = try await fixture.store.read { connection in
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1
+            }
+            XCTAssertEqual(afterRejectedAttempt, beforeRejectedAttempt)
+            XCTAssertEqual(auditCountAfterRejectedAttempt, auditCountBeforeRejectedAttempt)
+
+            await model.reauthorizeActivePhaseProject(
+                at: fixture.projectRoot,
+                projectID: fixture.projectID
+            )
+
+            XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
+            XCTAssertEqual(requestIDs.count, 1)
+            let afterRecovery = try await rr9SelectionState(
+                store: fixture.store,
+                projectID: fixture.projectID
+            )
+            XCTAssertEqual(afterRecovery.activePhaseID, fixture.currentPhaseID.rawValue)
+            XCTAssertEqual(afterRecovery.commandRequests, 0)
+            XCTAssertEqual(afterRecovery.selectionAudits, 0)
+        }
+    }
+
+    @MainActor
     func testEveryRecoverableBookmarkFailureFailsClosedBeforePhaseMutation() async throws {
         let mismatchedRoot = FileManager.default.temporaryDirectory
             .appendingPathComponent("ReleaseRadar-RR9-Mismatched-\(UUID().uuidString)", isDirectory: true)
         try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
         addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
         let failures: [RR9BookmarkFailureMode] = [
             .stale,
             .resolutionFailure,
             .accessDenied,
             .mismatchedRoot(mismatchedRoot),
@@ -1591,20 +1674,87 @@
             XCTAssertEqual(model.projectGuidanceState(for: fixture.projectID), publishedGuidance)
             XCTAssertEqual(model.projectRoot(for: fixture.projectID), publishedRoot)
             XCTAssertEqual(model.selectedTicketID, publishedTicketID)
             XCTAssertEqual(model.selectedReviewItemID, publishedReviewItemID)
             XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
             XCTAssertNil(model.dashboardError)
         }
     }
 
     @MainActor
+    func testSupersededLoadDashboardReturnsBeforeDebugRouteAndPublishedStateMutation() async throws {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9SupersededLoad-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
+        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
+        let loader = RR9SupersededLoadDashboardLoader()
+        let model = AppModel(
+            store: store,
+            dashboardLoader: { store in try await loader.load(from: store) },
+            externalServicesSuppressed: true,
+            seedSampleData: false,
+            rr9ActivePhaseCaptureScenario: .busy,
+            rr9ActivePhaseCaptureRootDirectory: directory.appendingPathComponent("RR9ActivePhaseCaptureRoots")
+        )
+        await model.loadDashboard()
+        let initialActivity = model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID)
+
+        let olderLoad = Task { await model.loadDashboard() }
+        await loader.waitUntilOlderLoadEntered()
+        try await store.transact(
+            actor: .init(id: "agent"),
+            reason: "Newer agent activity",
+            auditEventID: .init(rawValue: "rr9-newer-agent-audit"),
+            auditScope: AuditScope(
+                projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
+                entityType: .phase,
+                entityID: RR9ActivePhaseCaptureFixture.roadmapPhaseID.rawValue
+            )
+        ) { _ in }
+
+        await model.reloadDashboardAfterCommittedAgentCommand()
+        XCTAssertNotEqual(
+            model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
+            initialActivity
+        )
+        model.selection = .phaseBoard(RR9ActivePhaseCaptureFixture.primaryProjectID)
+        await model.setActivePhase(
+            projectID: RR9ActivePhaseCaptureFixture.primaryProjectID,
+            phaseID: RR9ActivePhaseCaptureFixture.roadmapPhaseID
+        )
+
+        let publishedDashboard = model.dashboard
+        let publishedActivity = model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID)
+        let publishedError = model.dashboardError
+        let publishedStatus = model.activePhaseSelectionStatus(
+            for: RR9ActivePhaseCaptureFixture.primaryProjectID
+        )
+        await loader.releaseOlderLoad()
+        await olderLoad.value
+
+        XCTAssertEqual(model.selection, .phaseBoard(RR9ActivePhaseCaptureFixture.primaryProjectID))
+        XCTAssertEqual(model.dashboard, publishedDashboard)
+        XCTAssertEqual(
+            model.activity(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
+            publishedActivity
+        )
+        XCTAssertEqual(model.dashboardError, publishedError)
+        XCTAssertNil(model.dashboardError)
+        XCTAssertEqual(
+            model.activePhaseSelectionStatus(for: RR9ActivePhaseCaptureFixture.primaryProjectID),
+            publishedStatus
+        )
+        XCTAssertEqual(publishedStatus, .saving(RR9ActivePhaseCaptureFixture.roadmapPhaseID))
+    }
+
+    @MainActor
     func testRR9DebugFixtureSeedsIdempotentlyAndSelectsScenarioRouteWithoutOrdinarySampleData() async throws {
         let directory = FileManager.default.temporaryDirectory
             .appendingPathComponent("ReleaseRadar-RR9Capture-\(UUID().uuidString)", isDirectory: true)
         try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
         addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
         let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
         let model = AppModel(
             store: store,
             externalServicesSuppressed: true,
             seedSampleData: false,
@@ -2108,20 +2258,52 @@
         }
         return try await DashboardProjection.load(from: store)
     }
 
     func waitUntilOlderReloadEntered() async {
         guard !olderEntered else { return }
         await withCheckedContinuation { enteredContinuations.append($0) }
     }
 
     func releaseOlderReload() {
+        olderReleased = true
+        releaseContinuations.forEach { $0.resume() }
+        releaseContinuations.removeAll()
+    }
+}
+
+private actor RR9SupersededLoadDashboardLoader {
+    private var callCount = 0
+    private var olderEntered = false
+    private var olderReleased = false
+    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
+    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
+
+    func load(from store: DeliveryStore) async throws -> DashboardProjection {
+        callCount += 1
+        let projection = try await DashboardProjection.load(from: store)
+        guard callCount == 2 else { return projection }
+        olderEntered = true
+        enteredContinuations.forEach { $0.resume() }
+        enteredContinuations.removeAll()
+        if !olderReleased {
+            await withCheckedContinuation { releaseContinuations.append($0) }
+        }
+        return projection
+    }
+
+    func waitUntilOlderLoadEntered() async {
+        guard !olderEntered else { return }
+        await withCheckedContinuation { enteredContinuations.append($0) }
+    }
+
+    func releaseOlderLoad() {
         olderReleased = true
         releaseContinuations.forEach { $0.resume() }
         releaseContinuations.removeAll()
     }
 }
 
 private actor RR9TargetMismatchDashboardLoader {
     private let failCommittedReload: Bool
     private var callCount = 0
     private var initialProjection: DashboardProjection?
```

### `ReleaseRadarTests/DashboardProjectionTests.swift`

Review-1 blob: `309aa500f5e70e02fab6572706fa69492aa21486`  
Corrected blob: `f1ca4e7de8ec63bcb7e5f66eda489c6c8eda25af`

```diff
--- review-1/ReleaseRadarTests/DashboardProjectionTests.swift
+++ corrected/ReleaseRadarTests/DashboardProjectionTests.swift
@@ -202,21 +202,27 @@
         XCTAssertEqual(board.phaseID.rawValue, "phase-active")
         XCTAssertEqual(board.lane(.inProgress)?.cards.map(\.id.rawValue), ["ACTIVE-1"])
     }
 
     func testActivePhaseSelectionKeepsOptionsDeterministicAndBoardMembershipScopedAcrossRelaunch() async throws {
         let store = DeliveryStore(databaseURL: databaseURL)
         let projectID = ProjectID(rawValue: "phase-selection-project")
         let projectRoot = databaseURL.deletingLastPathComponent()
         try await store.transact(
             actor: .init(id: "dashboard-test"),
-            reason: "Seed active phase projection fixture"
+            reason: "Seed active phase projection fixture",
+            auditEventID: .init(rawValue: "phase-selection-seed-audit"),
+            auditScope: .init(
+                projectID: projectID,
+                entityType: .phase,
+                entityID: "phase-current"
+            )
         ) { connection in
             try connection.execute("INSERT INTO projects (id, name) VALUES ('phase-selection-project', 'Phase Selection')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-current', 'phase-selection-project', 'Current')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-history', 'phase-selection-project', 'History')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-roadmap', 'phase-selection-project', 'Roadmap delivery')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-order-z', 'phase-selection-project', 'ROADMAP')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-order-a', 'phase-selection-project', 'Roadmap')")
             try connection.execute("INSERT INTO project_active_phases (project_id, phase_id) VALUES ('phase-selection-project', 'phase-current')")
             try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-A', 'phase-selection-project', 'phase-current', 'Current ticket keeps cross phase truth.', 'backlog')")
             try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('CURRENT-B', 'phase-selection-project', 'phase-current', 'Current ticket keeps local dependency.', 'in_progress')")
@@ -226,20 +232,21 @@
                     bindings: [.text("ROAD-B\(index)"), .text("Roadmap backlog outcome \(index).")]
                 )
             }
             for index in 1...3 {
                 try connection.execute(
                     "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, 'phase-selection-project', 'phase-roadmap', ?, 'blocked')",
                     bindings: [.text("ROAD-X\(index)"), .text("Roadmap blocked outcome \(index).")]
                 )
             }
             try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('HISTORY-A', 'phase-selection-project', 'phase-history', 'Historical accepted outcome.', 'accepted')")
+            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dep-roadmap', 'phase-selection-project', 'phase-roadmap', 'phase-current')")
             try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-cross', 'phase-selection-project', 'CURRENT-A', 'ROAD-B1')")
             try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-current', 'phase-selection-project', 'CURRENT-B', 'CURRENT-A')")
             try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dep-roadmap', 'phase-selection-project', 'ROAD-X1', 'ROAD-B2')")
         }
 
         let initial = try await DashboardProjection.load(from: store)
         let initialProject = try XCTUnwrap(initial.projects.first { $0.id == projectID })
         let initialBoard = try XCTUnwrap(initial.board(for: projectID))
         XCTAssertEqual(initialProject.activePhaseID?.rawValue, "phase-current")
         XCTAssertEqual(initialProject.phases.map(\.id.rawValue), [
@@ -249,36 +256,34 @@
         XCTAssertEqual(initialBoard.detail(for: .init(rawValue: "CURRENT-A"))?.requires.map(\.id.rawValue), ["ROAD-B1"])
         let initialGraph = try await DependencyGraphProjection.load(
             from: store,
             projectID: projectID,
             phaseID: .init(rawValue: "phase-current"),
             selectedTicketID: .init(rawValue: "CURRENT-A")
         )
         XCTAssertEqual(Set(initialGraph.nodes.map(\.id.rawValue)), ["CURRENT-A", "CURRENT-B"])
         XCTAssertNil(initialGraph.node(id: .init(rawValue: "ROAD-B1")))
 
-        let before = try await store.read { connection in
-            (
-                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'phase-selection-project'"),
-                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'phase-selection-project'"),
-                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'phase-selection-project'"),
-                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
-            )
-        }
+        let before = try await Self.phaseSelectionPersistenceSnapshot(store)
+        XCTAssertEqual(before.activeRows, ["phase-selection-project|phase-current"])
+        XCTAssertEqual(before.phaseDependencies, [
+            "phase-dep-roadmap|phase-selection-project|phase-roadmap|phase-current",
+        ])
+        let requestID = UUID(uuidString: "29292929-2929-4929-8929-292929292929")!
         let result = await AgentCommandDispatcher(
             store: store,
             projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [
                 .init(projectID: projectID, canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
             ])
         ).dispatch(.init(
             version: AgentCommandDispatcher.commandEnvelopeVersion,
-            requestID: UUID(uuidString: "29292929-2929-4929-8929-292929292929")!,
+            requestID: requestID,
             projectRoot: projectRoot.path,
             reason: "Select roadmap projection",
             command: .setActivePhase(phaseID: "phase-roadmap")
         ))
         XCTAssertNil(result.error)
 
         let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
         let reloaded = try await DashboardProjection.load(from: relaunchedStore)
         let reloadedProject = try XCTUnwrap(reloaded.projects.first { $0.id == projectID })
         let reloadedBoard = try XCTUnwrap(reloaded.board(for: projectID))
@@ -288,32 +293,45 @@
         XCTAssertEqual(Set(reloadedBoard.details.keys.map(\.rawValue)), Set((1...8).map { "ROAD-B\($0)" } + (1...3).map { "ROAD-X\($0)" }))
         XCTAssertEqual(reloadedBoard.detail(for: .init(rawValue: "ROAD-B1"))?.unlocks.map(\.id.rawValue), ["CURRENT-A"])
         XCTAssertNil(reloadedBoard.detail(for: .init(rawValue: "CURRENT-A")))
         let roadmapGraph = try await DependencyGraphProjection.load(
             from: relaunchedStore,
             projectID: projectID,
             phaseID: .init(rawValue: "phase-roadmap"),
             selectedTicketID: .init(rawValue: "ROAD-B1")
         )
         XCTAssertNil(roadmapGraph.node(id: .init(rawValue: "CURRENT-A")))
-        let after = try await relaunchedStore.read { connection in
-            (
-                try connection.scalarInt("SELECT COUNT(*) FROM phases WHERE project_id = 'phase-selection-project'"),
-                try connection.scalarInt("SELECT COUNT(*) FROM tickets WHERE project_id = 'phase-selection-project'"),
-                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE project_id = 'phase-selection-project'"),
-                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
-            )
+        let after = try await Self.phaseSelectionPersistenceSnapshot(relaunchedStore)
+        XCTAssertEqual(after.phases, before.phases)
+        XCTAssertEqual(after.tickets, before.tickets)
+        XCTAssertEqual(after.phaseDependencies, before.phaseDependencies)
+        XCTAssertEqual(after.ticketDependencies, before.ticketDependencies)
+        XCTAssertEqual(after.activeRows, ["phase-selection-project|phase-roadmap"])
+
+        let auditEventID = try XCTUnwrap(result.auditEventID)
+        let selectionAuditPrefix = "\(auditEventID.rawValue)|"
+        let selectionAudits = after.auditRows.filter { $0.hasPrefix(selectionAuditPrefix) }
+        XCTAssertEqual(selectionAudits.count, 1)
+        XCTAssertEqual(
+            after.auditRows.filter { !$0.hasPrefix(selectionAuditPrefix) },
+            before.auditRows
+        )
+
+        let receiptPrefix = "\(requestID.uuidString.lowercased())|"
+        let durableReceipts = after.requestRows.filter {
+            $0.lowercased().hasPrefix(receiptPrefix)
         }
-        XCTAssertEqual(after.0, before.0)
-        XCTAssertEqual(after.1, before.1)
-        XCTAssertEqual(after.2, before.2)
-        XCTAssertEqual(after.3, (before.3 ?? 0) + 1)
+        XCTAssertEqual(durableReceipts.count, 1)
+        XCTAssertEqual(
+            after.requestRows.filter { !$0.lowercased().hasPrefix(receiptPrefix) },
+            before.requestRows
+        )
     }
 
     func testProjectWithMultiplePhasesAndNoExplicitActivePhaseHasNoGuessedBoard() async throws {
         let store = DeliveryStore(databaseURL: databaseURL)
         try await store.transact(actor: .init(id: "dashboard-test"), reason: "Seed ambiguous project") { connection in
             try connection.execute("INSERT INTO projects (id, name) VALUES ('project-ambiguous', 'Ambiguous')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-a', 'project-ambiguous', 'Historical')")
             try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-b', 'project-ambiguous', 'Planned')")
         }
 
@@ -346,11 +364,81 @@
         XCTAssertEqual(
             BoardDensity.compact.accessibilityOptionLabel(isSelected: true, forLaneWidth: 180),
             "Compact density"
         )
         XCTAssertTrue(PhaseBoardLayout.usesVerticallyScrollableStack(forWidth: 760))
         XCTAssertTrue(PhaseBoardLayout.usesVerticallyScrollableStack(forWidth: 900))
         XCTAssertFalse(PhaseBoardLayout.usesVerticallyScrollableStack(forWidth: 1_260))
         XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: false), 220)
         XCTAssertEqual(DashboardLayout.sidebarWidth(isCompact: true), 96)
     }
+
+    private struct PhaseSelectionPersistenceSnapshot: Equatable {
+        let phases: [String]
+        let tickets: [String]
+        let phaseDependencies: [String]
+        let ticketDependencies: [String]
+        let activeRows: [String]
+        let auditRows: [String]
+        let requestRows: [String]
+    }
+
+    private static func phaseSelectionPersistenceSnapshot(
+        _ store: DeliveryStore
+    ) async throws -> PhaseSelectionPersistenceSnapshot {
+        try await store.read { connection in
+            PhaseSelectionPersistenceSnapshot(
+                phases: try textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || name AS value FROM phases ORDER BY project_id, id"
+                ),
+                tickets: try textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || outcome || '|' || lane AS value FROM tickets ORDER BY project_id, id"
+                ),
+                phaseDependencies: try textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || phase_id || '|' || depends_on_phase_id AS value FROM phase_dependencies ORDER BY project_id, id"
+                ),
+                ticketDependencies: try textRows(
+                    connection,
+                    sql: "SELECT id || '|' || project_id || '|' || ticket_id || '|' || depends_on_ticket_id AS value FROM ticket_dependencies ORDER BY project_id, id"
+                ),
+                activeRows: try textRows(
+                    connection,
+                    sql: "SELECT project_id || '|' || phase_id AS value FROM project_active_phases ORDER BY project_id"
+                ),
+                auditRows: try textRows(
+                    connection,
+                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') || '|' || created_at AS value FROM audit_events ORDER BY id"
+                ),
+                requestRows: try textRows(
+                    connection,
+                    sql: "SELECT request_id || '|' || hex(request_body) || '|' || hex(result_data) || '|' || created_at AS value FROM agent_command_requests ORDER BY request_id"
+                )
+            )
+        }
+    }
+
+    private static func textRows(
+        _ connection: SQLiteConnection,
+        sql: String
+    ) throws -> [String] {
+        var values: [String] = []
+        var offset: Int64 = 0
+        while let row = try connection.row(
+            "\(sql) LIMIT 1 OFFSET ?",
+            bindings: [.integer(offset)]
+        ) {
+            guard case let .text(value)? = row["value"] else {
+                throw DashboardProjectionTestError.missingSnapshotText
+            }
+            values.append(value)
+            offset += 1
+        }
+        return values
+    }
+}
+
+private enum DashboardProjectionTestError: Error {
+    case missingSnapshotText
 }
```


