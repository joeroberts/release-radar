# RR-R9B security review-loop attributable correction package

This package isolates the Security/Privacy Required correction from the exact pre-fix file blobs. Review it with both earlier RR-R9B packages, current source, the updated implementer report, ADR-003, and the canonical task brief.

## Exact correction patch

### `ReleaseRadar/App/AppModel.swift`

Security-review blob: `6680d2c2f7a651da98e8f2ff4fc11b100579166a`  
Corrected blob: `cb4a9d98ad7b135104d87e1319b8cdbe9054ebef`

```diff
--- security-review/ReleaseRadar/App/AppModel.swift
+++ security-corrected/ReleaseRadar/App/AppModel.swift
@@ -625,39 +625,47 @@
             summary: item.summary,
             status: decision == .resolve ? .resolved : .dismissed
         )
         reviewInboxes[item.projectID] = ReviewInboxProjection(
             projectID: inbox.projectID,
             openItems: inbox.openItems.filter { $0.id != item.id },
             completedItems: inbox.completedItems.filter { $0.id != item.id } + [committed]
         )
     }
 
-    private func prepareProjectProjections() async throws -> PreparedProjectProjections {
+    private func prepareProjectProjections(
+        context: ProjectionReloadContext
+    ) async throws -> PreparedProjectProjections {
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
-            let guidance = await projectOnboarding.observeProjectGuidanceContext(projectID: project.id)
-            projectGuidanceStates[project.id] = guidance.state
-            projectRoots[project.id] = guidance.projectRoot
+            switch context {
+            case .ordinary:
+                let guidance = await projectOnboarding.observeProjectGuidanceContext(projectID: project.id)
+                projectGuidanceStates[project.id] = guidance.state
+                projectRoots[project.id] = guidance.projectRoot
+            case .ownerActivePhaseCommitted, .agentCommandCommitted:
+                projectGuidanceStates[project.id] = self.projectGuidanceStates[project.id] ?? .unavailable
+                projectRoots[project.id] = self.projectRoots[project.id]
+            }
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
@@ -722,21 +730,21 @@
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
-            let prepared = try await prepareProjectProjections()
+            let prepared = try await prepareProjectProjections(context: context)
             guard generation == projectionReloadGeneration else { return .superseded }
             publish(prepared)
             return .published
         } catch {
             guard generation == projectionReloadGeneration else { return .superseded }
             publishFailure(error, context: context)
             return .failed
         }
     }
 
```

### `ReleaseRadarTests/AppRouteTests.swift`

Security-review blob: `e65f8ed50a9ace02be0914626300da96e7c9d871`  
Corrected blob: `cd926cbdadaa49902d8282bd79dcd1bf401a013d`

```diff
--- security-review/ReleaseRadarTests/AppRouteTests.swift
+++ security-corrected/ReleaseRadarTests/AppRouteTests.swift
@@ -1314,20 +1314,154 @@
         XCTAssertEqual(afterRejectedSelection, committed)
         await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
         XCTAssertEqual(model.activePhaseSelectionStatus(for: fixture.projectID), .idle)
         XCTAssertEqual(model.currentProject?.activePhaseID, fixture.roadmapPhaseID)
         XCTAssertEqual(requestIDs.count, 1)
         let afterReload = try await rr9SelectionState(store: fixture.store, projectID: fixture.projectID)
         XCTAssertEqual(afterReload, committed)
     }
 
     @MainActor
+    func testExternalCommittedRefreshReusesCachedGuidanceWithoutBookmarkOrAuditMutation() async throws {
+        let mismatchedRoot = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9-ExternalRefreshMismatch-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
+        let failures: [RR9BookmarkFailureMode] = [
+            .resolutionFailure,
+            .stale,
+            .mismatchedRoot(mismatchedRoot),
+            .accessDenied,
+        ]
+
+        for failure in failures {
+            let fixture = try await makeRR9OwnerFixture()
+            let requestIDs = RR9RequestIDCounter()
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                requestIDGenerator: { requestIDs.next() },
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+
+            let storeBefore = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
+            let dashboardBefore = model.dashboard
+            let activityBefore = model.activity(for: fixture.projectID)
+            let errorBefore = model.dashboardError
+            let statusBefore = model.activePhaseSelectionStatus(for: fixture.projectID)
+            let guidanceBefore = model.projectGuidanceState(for: fixture.projectID)
+            let rootBefore = model.projectRoot(for: fixture.projectID)
+            XCTAssertEqual(guidanceBefore, .missing)
+            XCTAssertEqual(rootBefore, fixture.projectRoot)
+            fixture.bookmarks.setFailureMode(failure)
+
+            await model.reloadDashboardAfterCommittedAgentCommand()
+
+            let storeAfter = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
+            XCTAssertEqual(storeAfter, storeBefore, "Failure: \(failure)")
+            XCTAssertEqual(model.dashboard, dashboardBefore, "Failure: \(failure)")
+            XCTAssertEqual(model.activity(for: fixture.projectID), activityBefore, "Failure: \(failure)")
+            XCTAssertEqual(model.dashboardError, errorBefore, "Failure: \(failure)")
+            XCTAssertEqual(
+                model.activePhaseSelectionStatus(for: fixture.projectID),
+                statusBefore,
+                "Failure: \(failure)"
+            )
+            XCTAssertEqual(
+                model.projectGuidanceState(for: fixture.projectID),
+                guidanceBefore,
+                "Failure: \(failure)"
+            )
+            XCTAssertEqual(model.projectRoot(for: fixture.projectID), rootBefore, "Failure: \(failure)")
+            XCTAssertEqual(requestIDs.count, 0, "Failure: \(failure)")
+        }
+    }
+
+    @MainActor
+    func testOwnerSavedRefreshReusesCachedGuidanceWithoutBookmarkAuditOrCommandRetry() async throws {
+        let mismatchedRoot = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-RR9-SavedRefreshMismatch-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: mismatchedRoot, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: mismatchedRoot) }
+        let failures: [RR9BookmarkFailureMode] = [
+            .resolutionFailure,
+            .stale,
+            .mismatchedRoot(mismatchedRoot),
+            .accessDenied,
+        ]
+
+        for failure in failures {
+            let fixture = try await makeRR9OwnerFixture()
+            let requestIDs = RR9RequestIDCounter()
+            let loader = RouteDashboardLoader(failingCalls: [2])
+            let model = AppModel(
+                store: fixture.store,
+                projectOnboarding: fixture.onboarding,
+                dashboardLoader: { store in try await loader.load(from: store) },
+                requestIDGenerator: { requestIDs.next() },
+                externalServicesSuppressed: true
+            )
+            await model.loadDashboard()
+            let guidanceBefore = model.projectGuidanceState(for: fixture.projectID)
+            let rootBefore = model.projectRoot(for: fixture.projectID)
+            XCTAssertEqual(guidanceBefore, .missing)
+            XCTAssertEqual(rootBefore, fixture.projectRoot)
+
+            await model.setActivePhase(projectID: fixture.projectID, phaseID: fixture.roadmapPhaseID)
+
+            XCTAssertEqual(
+                model.activePhaseSelectionStatus(for: fixture.projectID),
+                .savedNeedsReload(fixture.roadmapPhaseID, "Roadmap")
+            )
+            XCTAssertEqual(model.currentProject?.activePhaseID, fixture.currentPhaseID)
+            let dashboardBefore = model.dashboard
+            let activityBefore = model.activity(for: fixture.projectID)
+            let errorBefore = model.dashboardError
+            let storeBefore = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
+            let expectedDashboard = try await DashboardProjection.load(from: fixture.store)
+            let expectedActivity = try await ProjectActivityProjection.load(
+                from: fixture.store,
+                projectID: fixture.projectID
+            )
+            fixture.bookmarks.setFailureMode(failure)
+
+            await model.reloadAfterActivePhaseSelection(projectID: fixture.projectID)
+
+            let storeAfter = try await Self.rr9ReadOnlyReloadStoreSnapshot(fixture.store)
+            XCTAssertEqual(storeAfter, storeBefore, "Failure: \(failure)")
+            XCTAssertNotEqual(model.dashboard, dashboardBefore, "Failure: \(failure)")
+            XCTAssertEqual(model.dashboard, expectedDashboard, "Failure: \(failure)")
+            XCTAssertNotEqual(model.activity(for: fixture.projectID), activityBefore, "Failure: \(failure)")
+            XCTAssertEqual(
+                model.activity(for: fixture.projectID),
+                expectedActivity,
+                "Failure: \(failure)"
+            )
+            XCTAssertEqual(model.dashboardError, errorBefore, "Failure: \(failure)")
+            XCTAssertNil(model.dashboardError, "Failure: \(failure)")
+            XCTAssertEqual(
+                model.activePhaseSelectionStatus(for: fixture.projectID),
+                .idle,
+                "Failure: \(failure)"
+            )
+            XCTAssertEqual(
+                model.projectGuidanceState(for: fixture.projectID),
+                guidanceBefore,
+                "Failure: \(failure)"
+            )
+            XCTAssertEqual(model.projectRoot(for: fixture.projectID), rootBefore, "Failure: \(failure)")
+            XCTAssertEqual(requestIDs.count, 1, "Failure: \(failure)")
+        }
+    }
+
+    @MainActor
     func testPostCommitWorkspacePreparationFailurePublishesNoPartialDashboardBeforeReadOnlyRecovery() async throws {
         let fixture = try await makeRR9OwnerFixture()
         let reviewLoader = RR9SequencedReviewInboxLoader(failingCalls: [2])
         let model = AppModel(
             store: fixture.store,
             projectOnboarding: fixture.onboarding,
             reviewInboxLoader: { store, projectID in
                 try await reviewLoader.load(from: store, projectID: projectID)
             },
             externalServicesSuppressed: true
@@ -2073,20 +2207,64 @@
                 selectionAudits: try connection.scalarInt(
                     "SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Owner selected active phase %'"
                 ) ?? -1,
                 actorID: try connection.scalarText(
                     "SELECT actor_id FROM audit_events WHERE reason LIKE 'Owner selected active phase %' ORDER BY rowid DESC LIMIT 1"
                 )
             )
         }
     }
 
+    private static func rr9ReadOnlyReloadStoreSnapshot(
+        _ store: DeliveryStore
+    ) async throws -> RR9ReadOnlyReloadStoreSnapshot {
+        try await store.read { connection in
+            RR9ReadOnlyReloadStoreSnapshot(
+                bookmarkRows: try Self.rr9TextRows(
+                    connection,
+                    sql: "SELECT project_id || '|' || path || '|' || hex(bookmark_data) || '|' || is_stale AS value FROM project_bookmarks ORDER BY project_id, path"
+                ),
+                auditRows: try Self.rr9TextRows(
+                    connection,
+                    sql: "SELECT id || '|' || actor_id || '|' || COALESCE(thread_id, '') || '|' || thread_attribution || '|' || reason || '|' || COALESCE(project_id, '') || '|' || COALESCE(entity_type, '') || '|' || COALESCE(entity_id, '') || '|' || created_at AS value FROM audit_events ORDER BY id"
+                ),
+                requestRows: try Self.rr9TextRows(
+                    connection,
+                    sql: "SELECT request_id || '|' || hex(request_body) || '|' || hex(result_data) || '|' || created_at AS value FROM agent_command_requests ORDER BY request_id"
+                ),
+                activeRows: try Self.rr9TextRows(
+                    connection,
+                    sql: "SELECT project_id || '|' || phase_id AS value FROM project_active_phases ORDER BY project_id"
+                )
+            )
+        }
+    }
+
+    private static func rr9TextRows(
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
+                throw RouteProjectionError.missingSnapshotText
+            }
+            values.append(value)
+            offset += 1
+        }
+        return values
+    }
+
 }
 
 private struct RR9OwnerFixture {
     let databaseURL: URL
     let projectRoot: URL
     let projectID: ProjectID
     let currentPhaseID: PhaseID
     let roadmapPhaseID: PhaseID
     let emptyPhaseID: PhaseID
     let store: DeliveryStore
@@ -2094,20 +2272,27 @@
     let onboarding: FolderProjectOnboarding
 }
 
 private struct RR9SelectionState: Equatable {
     let activePhaseID: String?
     let commandRequests: Int64
     let selectionAudits: Int64
     let actorID: String?
 }
 
+private struct RR9ReadOnlyReloadStoreSnapshot: Equatable {
+    let bookmarkRows: [String]
+    let auditRows: [String]
+    let requestRows: [String]
+    let activeRows: [String]
+}
+
 private final class RR9RequestIDCounter: @unchecked Sendable {
     private let lock = NSLock()
     private var generated = 0
 
     var count: Int { lock.withLock { generated } }
 
     func next() -> UUID {
         lock.withLock { generated += 1 }
         return UUID()
     }
@@ -2464,17 +2649,18 @@
 
     func load(from store: DeliveryStore) async throws -> DashboardProjection {
         callCount += 1
         guard !failingCalls.contains(callCount) else { throw RouteProjectionError.forcedRefreshFailure }
         return try await DashboardProjection.load(from: store)
     }
 }
 
 private enum RouteProjectionError: Error {
     case forcedRefreshFailure
+    case missingSnapshotText
 }
 
 private actor RouteCountingTransport: PushoverTransport {
     func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
         .init(requestID: "unused")
     }
 }
```


