import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

@MainActor
final class ProjectArchiveAcceptanceTests: XCTestCase {
    func testVersionFifteenProjectsMigrateActiveWithoutChangingIdentity() async throws {
        let url = try databaseURL()
        do {
            let store = DeliveryStore(databaseURL: url)
            try await seedProject(in: store)
        }
        let legacy = try SQLiteConnection(url: url)
        try legacy.execute("ALTER TABLE projects DROP COLUMN lifecycle")
        try legacy.execute("PRAGMA user_version = 15")

        let reopened = DeliveryStore(databaseURL: url)
        guard case .available = await reopened.availability else {
            return XCTFail("Expected the v15 store to migrate")
        }
        let state = try await ProjectLifecycleManager(store: reopened).snapshot(projectID: projectID)
        XCTAssertEqual(state.lifecycle, .active)
        XCTAssertEqual(state.registration.registrationID, "registration-one")
        XCTAssertEqual(state.registration.requestGeneration, 4)
    }

    func testArchiveAndRestorePreserveCompleteGraphRegistrationAndRestartState() async throws {
        let url = try databaseURL()
        let store = DeliveryStore(databaseURL: url)
        try await seedProject(in: store)
        let manager = ProjectLifecycleManager(store: store)
        let before = try await preservedRows(store)

        let archivePreview = try await manager.preview(projectID: projectID, transition: .archive)
        XCTAssertEqual(archivePreview.projectName, "Project One")
        XCTAssertEqual(archivePreview.counts.phases, 1)
        XCTAssertEqual(archivePreview.counts.tickets, 1)
        XCTAssertEqual(archivePreview.counts.evidence, 1)
        XCTAssertEqual(archivePreview.counts.history, 1)
        let archived = try await manager.apply(archivePreview)
        XCTAssertEqual(archived.lifecycle, .archived)
        XCTAssertEqual(archived.registration.registrationID, "registration-one")
        XCTAssertEqual(archived.registration.requestGeneration, 5)
        let afterArchiveRows = try await preservedRows(store)
        XCTAssertEqual(afterArchiveRows, before)

        let restorePreview = try await manager.preview(projectID: projectID, transition: .restore)
        let restored = try await manager.apply(restorePreview)
        XCTAssertEqual(restored.lifecycle, .active)
        XCTAssertEqual(restored.registration.registrationID, "registration-one")
        XCTAssertEqual(restored.registration.requestGeneration, 6)
        let afterRestoreRows = try await preservedRows(store)
        XCTAssertEqual(afterRestoreRows, before)

        let relaunched = DeliveryStore(databaseURL: url)
        let relaunchedState = try await ProjectLifecycleManager(store: relaunched).snapshot(projectID: projectID)
        XCTAssertEqual(relaunchedState, restored)
    }

    func testArchiveFailureRollsBackLifecycleGenerationNotificationsAndAudit() async throws {
        let url = try databaseURL()
        let store = DeliveryStore(databaseURL: url)
        try await seedProject(in: store)
        try await seedNotifications(in: store)
        let manager = ProjectLifecycleManager(store: store)
        let preview = try await manager.preview(projectID: projectID, transition: .archive)
        let before = try await lifecycleMutationRows(store)
        let faultConnection = try SQLiteConnection(url: url)
        try faultConnection.execute("""
            CREATE TRIGGER reject_test_archive
            BEFORE UPDATE OF lifecycle ON projects
            WHEN NEW.lifecycle = 'archived'
            BEGIN SELECT RAISE(ABORT, 'injected archive failure'); END
            """)
        let afterTrigger = try await lifecycleMutationRows(store)

        do {
            _ = try await manager.apply(preview)
            XCTFail("Expected the archive transaction to fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("injected archive failure"))
        }
        let afterFailure = try await lifecycleMutationRows(store)
        XCTAssertEqual(afterFailure, afterTrigger)
        XCTAssertEqual(afterTrigger.auditCount, before.auditCount)
    }

    func testStaleArchivePreviewCannotChangeLifecycleOrCreateAudit() async throws {
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await seedProject(in: store)
        let manager = ProjectLifecycleManager(store: store)
        let preview = try await manager.preview(projectID: projectID, transition: .archive)
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: ArchiveBookmarkStore())
        _ = try await onboarding.updateProjectSettings(
            registration: preview.registration,
            projectName: "Renamed Project",
            excludedTaskIDs: []
        )
        let before = try await lifecycleMutationRows(store)

        await XCTAssertThrowsErrorAsync(try await manager.apply(preview))
        let afterFailure = try await lifecycleMutationRows(store)
        let lifecycle = try await manager.snapshot(projectID: projectID).lifecycle
        XCTAssertEqual(afterFailure, before)
        XCTAssertEqual(lifecycle, .active)
    }

    func testArchiveSuppressesQueuedNotificationsMarksInflightUnknownAndRestoreNeverReplays() async throws {
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await seedProject(in: store)
        try await seedNotifications(in: store)
        let manager = ProjectLifecycleManager(store: store)
        _ = try await manager.apply(try await manager.preview(projectID: projectID, transition: .archive))

        let archived = try await notificationState(store)
        XCTAssertEqual(archived.events["queued"], NotificationDeliveryState.suppressed.rawValue)
        XCTAssertEqual(archived.events["attempt"], NotificationDeliveryState.unknown.rawValue)
        XCTAssertEqual(archived.events["sent"], NotificationDeliveryState.sent.rawValue)
        XCTAssertEqual(archived.activeOccurrences, 0)

        _ = try await manager.apply(try await manager.preview(projectID: projectID, transition: .restore))
        let transport = ArchiveNotificationTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: store,
            credentials: ArchiveCredentials(),
            transport: transport,
            beforeLaunchRecovery: {}
        )
        await dispatcher.prepareForLaunch()
        await dispatcher.dispatchPending()
        let sendCount = await transport.sendCount
        let restoredNotificationState = try await notificationState(store)
        XCTAssertEqual(sendCount, 0)
        XCTAssertEqual(restoredNotificationState, archived)
    }

    func testArchivedProjectRejectsPersistedAndLateInMemoryMutationAdmission() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-C5-Root-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await seedProject(in: store, root: root)
        let project = AuthorizedProject(projectID: projectID, canonicalRoot: root, authorizedRoots: [root])
        let rootManagement = ProjectRootManagement(store: store, bookmarkStore: ArchiveBookmarkStore())
        let rootSnapshot = try await rootManagement.snapshot(projectID: projectID)
        let manager = ProjectLifecycleManager(store: store)
        let archived = try await manager.apply(try await manager.preview(projectID: projectID, transition: .archive))

        let persistedResolution = await PersistedAuthorizedProjectRegistry(store: store).resolve(projectRoot: root.path)
        XCTAssertNil(persistedResolution)
        await XCTAssertThrowsErrorAsync(
            try await FolderProjectOnboarding(store: store, bookmarkStore: ArchiveBookmarkStore()).updateProjectSettings(
                registration: archived.registration,
                projectName: "Must not change",
                excludedTaskIDs: []
            )
        )
        await XCTAssertThrowsErrorAsync(
            try await rootManagement.prepare(.revoke, folder: root, snapshot: rootSnapshot)
        )
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: [project])
        )
        let before = try await lifecycleMutationRows(store)
        let result = await dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(),
            projectRoot: root.path,
            reason: "Late archived callback",
            command: .upsertPhase(phaseID: "late-phase", name: "Must not exist")
        ))
        XCTAssertEqual(result.error, .unauthorizedProjectRoot)
        let after = try await lifecycleMutationRows(store)
        let latePhaseCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM phases WHERE id = 'late-phase'") }
        XCTAssertEqual(after, before)
        XCTAssertEqual(latePhaseCount, 0)
    }

    func testArchivedObservationCallbackCannotMutateOrQueueNotification() async throws {
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await seedProject(in: store)
        let manager = ProjectLifecycleManager(store: store)
        _ = try await manager.apply(try await manager.preview(projectID: projectID, transition: .archive))
        let before = try await lifecycleMutationRows(store)

        await XCTAssertThrowsErrorAsync(
            try await MeaningfulDeliveryEventRecorder(store: store).recordGoalObservation(
                projectID: projectID,
                threadID: "thread-one",
                goalID: "goal-late",
                status: .blocked,
                observedAt: Date(timeIntervalSince1970: 20)
            )
        )
        let after = try await lifecycleMutationRows(store)
        let lateGoalCount = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM observed_goals WHERE id = 'goal-late'") }
        XCTAssertEqual(after, before)
        XCTAssertEqual(lateGoalCount, 0)
    }

    func testDashboardSeparatesArchivedProjectsWithoutReadingTheirEvidence() async throws {
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await seedProject(in: store)
        let manager = ProjectLifecycleManager(store: store)
        _ = try await manager.apply(try await manager.preview(projectID: projectID, transition: .archive))

        let dashboard = try await DashboardProjection.load(from: store, bookmarkStore: AlwaysFailArchiveBookmarkStore())
        XCTAssertTrue(dashboard.projects.isEmpty)
        let archived = try XCTUnwrap(dashboard.archivedProjects.first)
        XCTAssertEqual(archived.id, projectID)
        XCTAssertEqual(archived.name, "Project One")
        XCTAssertEqual(archived.registration.registrationID, "registration-one")
        XCTAssertEqual(archived.counts.phases, 1)
        XCTAssertEqual(archived.counts.tickets, 1)
        XCTAssertEqual(archived.counts.evidence, 1)
    }

    @MainActor
    func testArchivedProjectRouteRecoversAndRestoreReturnsToActiveOverview() async throws {
        let store = DeliveryStore(databaseURL: try databaseURL())
        try await seedProject(in: store)
        let manager = ProjectLifecycleManager(store: store)
        _ = try await manager.apply(try await manager.preview(projectID: projectID, transition: .archive))
        let model = AppModel(store: store, externalServicesSuppressed: true)
        await model.loadDashboard()

        await model.navigate(to: .phaseBoard(projectID))
        XCTAssertEqual(model.selection, .archivedProject(projectID))

        let preview = try await model.previewProjectLifecycle(projectID: projectID, transition: .restore)
        try await model.applyProjectLifecycle(preview)
        XCTAssertEqual(model.selection, .projectOverview(projectID))
        XCTAssertEqual(model.dashboard?.projects.first?.id, projectID)
        XCTAssertTrue(model.dashboard?.archivedProjects.isEmpty == true)

        await model.navigate(to: .archivedProject(projectID))
        XCTAssertEqual(model.selection, .projectOverview(projectID))
    }

    func testZeroPhaseArchiveAndRestoreIgnoreLostAccessAndInvalidCatalog() async throws {
        let store = DeliveryStore(databaseURL: try databaseURL())
        let id = ProjectID(rawValue: "zero-phase")
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed zero-phase inaccessible project",
            auditScope: .init(projectID: id, entityType: .project, entityID: id.rawValue)
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name) VALUES ('zero-phase', 'Zero Phase')")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('zero-phase', 'registration-zero', 2, 'complete')")
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('zero-root', 'zero-phase', '/missing/zero-phase')")
            try connection.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES ('zero-phase', '/missing/zero-phase', X'00', 1)")
            try connection.execute("INSERT INTO project_documentation_bindings (project_id, root_id, repository_id, accepted_catalog_version, accepted_catalog_digest, accepted_catalog) VALUES ('zero-phase', 'zero-root', '11111111-1111-1111-1111-111111111111', 1, ?, X'00')", bindings: [.text(String(repeating: "0", count: 64))])
        }
        let manager = ProjectLifecycleManager(store: store)
        let archived = try await manager.apply(try await manager.preview(projectID: id, transition: .archive))
        XCTAssertEqual(archived.lifecycle, .archived)
        XCTAssertEqual(archived.counts.phases, 0)
        let restored = try await manager.apply(try await manager.preview(projectID: id, transition: .restore))
        XCTAssertEqual(restored.lifecycle, .active)
        let retainedBindingCount = try await store.read {
            try $0.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings WHERE project_id = 'zero-phase'")
        }
        XCTAssertEqual(retainedBindingCount, 1)
    }

    private let projectID = ProjectID(rawValue: "project-one")

    private func databaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-C5-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("store.sqlite")
    }

    private func seedProject(in store: DeliveryStore, root: URL? = nil) async throws {
        let projectID = projectID
        try await store.transact(
            actor: .init(id: "fixture"),
            reason: "Seed archived project graph",
            auditScope: .init(projectID: projectID, entityType: .project, entityID: projectID.rawValue)
        ) { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-one', 'Project One', 1)")
            try connection.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES ('project-one', 'registration-one', 4, 'complete')")
            if let root {
                try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-one', 'project-one', ?)", bindings: [.text(root.path)])
            }
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-one', 'project-one', 'Phase One')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('ticket-one', 'project-one', 'phase-one', 'Deliver', 'in_progress')")
            try connection.execute("INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES ('evidence-one', 'project-one', 'ticket-one', '/unavailable/evidence', 1)")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-one', 'project-one', 'active', '2026-09-07T00:00:00Z')")
        }
    }

    private func seedNotifications(in store: DeliveryStore) async throws {
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed notification lifecycle") { connection in
            for (id, state) in [("queued", "queued"), ("attempt", "attempt_started"), ("sent", "sent")] {
                try connection.execute(
                    "INSERT INTO notification_events (id, fingerprint, state, project_id, event_kind, subject_id, occurrence, title, message, created_at, attempt_count) VALUES (?, ?, ?, 'project-one', 'review_requested', ?, 1, 'Title', 'Message', '2026-09-07T00:00:00Z', ?)",
                    bindings: [.text(id), .text("fingerprint-\(id)"), .text(state), .text(id), .integer(state == "attempt_started" ? 1 : 0)]
                )
                try connection.execute(
                    "INSERT INTO notification_occurrences (subject_key, project_id, event_kind, subject_id, generation, is_active) VALUES (?, 'project-one', 'review_requested', ?, 1, 1)",
                    bindings: [.text("project-one|review_requested|\(id)"), .text(id)]
                )
            }
        }
    }

    private func preservedRows(_ store: DeliveryStore) async throws -> [String: [[String: SQLiteValue]]] {
        let projectID = projectID
        return try await store.read { connection in
            var result: [String: [[String: SQLiteValue]]] = [:]
            for table in [
                "project_roots", "project_bookmarks", "project_documentation_bindings", "phases",
                "phase_plans", "tickets", "evidence", "thread_exclusions", "observed_threads",
                "observed_goals", "thread_links", "ticket_goal_links", "review_items",
                "completion_records", "delivery_goals", "delivery_goal_done_criteria",
                "delivery_goal_ticket_assignments", "delivery_goal_assignment_events",
                "ticket_task_plans", "ticket_tasks",
            ] {
                result[table] = try connection.rows("SELECT * FROM \(table) WHERE project_id = ? ORDER BY rowid", bindings: [.text(projectID.rawValue)])
            }
            return result
        }
    }

    private func lifecycleMutationRows(_ store: DeliveryStore) async throws -> LifecycleMutationRows {
        try await store.read { connection in
            LifecycleMutationRows(
                lifecycle: try connection.scalarText("SELECT lifecycle FROM projects WHERE id = 'project-one'") ?? "missing",
                generation: try connection.scalarInt("SELECT request_generation FROM project_registrations WHERE project_id = 'project-one'") ?? -1,
                notificationRows: try connection.rows("SELECT id, state, failure_code, completed_at FROM notification_events ORDER BY id"),
                occurrenceRows: try connection.rows("SELECT subject_key, generation, is_active FROM notification_occurrences ORDER BY subject_key"),
                auditCount: try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
                requestCount: try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1
            )
        }
    }

    private func notificationState(_ store: DeliveryStore) async throws -> ArchiveNotificationState {
        try await store.read { connection in
            ArchiveNotificationState(
                events: Dictionary(uniqueKeysWithValues: try connection.rows("SELECT id, state FROM notification_events ORDER BY id").map {
                    guard case let .text(id)? = $0["id"], case let .text(state)? = $0["state"] else {
                        throw SQLiteError(code: 20, message: "Expected notification id and state")
                    }
                    return (id, state)
                }),
                activeOccurrences: try connection.scalarInt("SELECT COUNT(*) FROM notification_occurrences WHERE is_active = 1") ?? -1
            )
        }
    }
}

private struct LifecycleMutationRows: Equatable {
    let lifecycle: String
    let generation: Int64
    let notificationRows: [[String: SQLiteValue]]
    let occurrenceRows: [[String: SQLiteValue]]
    let auditCount: Int64
    let requestCount: Int64
}

private struct ArchiveNotificationState: Equatable {
    let events: [String: String]
    let activeOccurrences: Int64
}

private struct ArchiveBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false) }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        try await body(try resolve(bookmark))
    }
}

private struct AlwaysFailArchiveBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { throw ProjectBookmarkError.bookmarkCreationFailed }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { throw ProjectBookmarkError.bookmarkResolutionFailed }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        throw ProjectBookmarkError.securityScopeAccessDenied
    }
}

private struct ArchiveCredentials: PushoverCredentialsProvider {
    func loadCredentials() throws -> PushoverCredentials? { .init(appToken: "token", userKey: "user") }
}

private actor ArchiveNotificationTransport: PushoverTransport {
    private(set) var sendCount = 0
    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        sendCount += 1
        return .init(requestID: "receipt")
    }
}

@MainActor
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
