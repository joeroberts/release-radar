import Foundation
import Security
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class NotificationAcceptanceTests: XCTestCase {
    func testAgentReviewOccurrenceIsAtomicAndReplayDoesNotDuplicateIt() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let requestID = UUID(uuidString: "90909090-9090-4090-8090-909090909001")!
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            assertedThreadID: "agent-thread",
            reason: "Request owner review",
            command: .requestReview(
                id: "review-1",
                ticketID: "RR-09",
                kind: "agent_request",
                summary: "raw reason that must not become notification text"
            )
        )

        let first = await fixture.dispatcher.dispatch(envelope)
        let replay = await AgentCommandDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            projectRegistry: fixture.registry
        ).dispatch(envelope)

        XCTAssertNil(first.error)
        XCTAssertEqual(replay, first)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'review-1' AND status = 'open'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Request owner review'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'review_requested' AND state = 'queued'"),
                try connection.scalarInt("SELECT COUNT(DISTINCT fingerprint) FROM notification_events"),
                try connection.scalarText("SELECT title FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT message FROM notification_events LIMIT 1")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, 1)
        XCTAssertEqual(state.3, 1)
        XCTAssertEqual(state.4, "RR-09 needs review")
        XCTAssertEqual(state.5, "An agent requested owner review in Release Radar.")
    }

    func testTicketNeedsReviewCreatesNewOccurrenceOnlyAfterLeavingAndReentering() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)

        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909011", fixture: fixture)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909012", fixture: fixture)
        try await transition(.inProgress, requestID: "90909090-9090-4090-8090-909090909013", fixture: fixture)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909014", fixture: fixture)

        let rows = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'ticket_needs_review'"),
                try connection.scalarInt("SELECT COUNT(DISTINCT fingerprint) FROM notification_events WHERE event_kind = 'ticket_needs_review'"),
                try connection.scalarInt("SELECT MAX(occurrence) FROM notification_events WHERE event_kind = 'ticket_needs_review'")
            )
        }
        XCTAssertEqual(rows.0, 2)
        XCTAssertEqual(rows.1, 2)
        XCTAssertEqual(rows.2, 2)
    }

    func testAgentCompletionCreatesOneSanitizedOccurrenceWhileUnrelatedUpdatesDoNot() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let completion = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909015")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Secret completion reason",
            command: .recordCompletion(id: "completion-1", ticketID: "RR-09", summary: "Raw evidence path and completion body")
        ))
        let unrelated = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909016")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Rename phase",
            command: .upsertPhase(phaseID: "phase-1", name: "MVP renamed")
        ))
        XCTAssertNil(completion.error)
        XCTAssertNil(unrelated.error)

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events"),
                try connection.scalarText("SELECT event_kind FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT title FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT message FROM notification_events LIMIT 1")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, MeaningfulDeliveryEventKind.agentCompleted.rawValue)
        XCTAssertEqual(state.2, "RR-09 completed")
        XCTAssertEqual(state.3, "An agent recorded completed delivery work in Release Radar.")
    }

    func testLinkedGoalBlockedEntryAlertsOncePausedSuppressesAndReentryAlertsAgain() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await fixture.store.transact(actor: .init(id: "fixture"), reason: "Seed linked runtime") { connection in
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-1', 'project-1', 'active', '2026-08-24T10:00:00Z')")
            try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('link-1', 'project-1', 'RR-09', 'thread-1')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: fixture.store)

        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .paused, observedAt: Date(timeIntervalSince1970: 1))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 2))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 3))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .active, observedAt: Date(timeIntervalSince1970: 4))
        try await recorder.recordGoalObservation(projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "goal-1", status: .blocked, observedAt: Date(timeIntervalSince1970: 5))

        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT status FROM observed_goals WHERE id = 'goal-1'"),
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE event_kind = 'goal_blocked'"),
                try connection.scalarInt("SELECT MAX(occurrence) FROM notification_events WHERE event_kind = 'goal_blocked'")
            )
        }
        XCTAssertEqual(state.0, "blocked")
        XCTAssertEqual(state.1, 2)
        XCTAssertEqual(state.2, 2)
    }

    func testPreFirstDashboardOpenSuppressesOnboardingAndImportStyleReviewAlerts() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: false)
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909021")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Create onboarding review",
            command: .requestReview(id: "onboarding-review", ticketID: nil, kind: "unmatched_import", summary: "Uncertain mapping")
        ))
        XCTAssertNil(result.error)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909022", fixture: fixture)

        let count = try await fixture.store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM notification_events")
        }
        XCTAssertEqual(count, 0)
    }

    func testAttemptIsDurableBeforeTransportAndFailureIsVisibleWithoutRawBodies() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909031", fixture: fixture)
        let transport = InspectingFailingTransport(store: fixture.store)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await dispatcher.dispatchPending()

        let observedState = await transport.observedState
        XCTAssertEqual(observedState, .attemptStarted)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events LIMIT 1"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT failure_code FROM notification_events LIMIT 1"),
                try connection.scalarText("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'notification_events'")
            )
        }
        XCTAssertEqual(state.0, NotificationDeliveryState.failed.rawValue)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, "transport_unavailable")
        XCTAssertFalse(try XCTUnwrap(state.3).contains("request_body"))
        XCTAssertFalse(try XCTUnwrap(state.3).contains("response_body"))
    }

    func testRelaunchMarksAmbiguousAttemptUnknownAndNeverRetriesIt() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909041", fixture: fixture)
        try await fixture.store.transact(actor: .init(id: "notification-dispatcher"), reason: "Start notification attempt") { connection in
            try connection.execute("UPDATE notification_events SET state = 'attempt_started', attempt_count = 1, attempt_started_at = '2026-08-24T10:00:00Z'")
        }
        let transport = CountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await dispatcher.prepareForLaunch()
        await dispatcher.dispatchPending()
        await dispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 0)
        let state = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(state, NotificationDeliveryState.unknown.rawValue)
    }

    func testOrdinaryDispatchDoesNotRecoverPreexistingAttemptAsIfItWereRelaunch() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909044", fixture: fixture)
        try await fixture.store.transact(actor: .init(id: "notification-dispatcher"), reason: "Start notification attempt") { connection in
            try connection.execute("UPDATE notification_events SET state = 'attempt_started', attempt_count = 1, attempt_started_at = '2026-08-24T10:00:00Z'")
        }
        let transport = CountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: DeliveryStore(databaseURL: fixture.databaseURL),
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await dispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 0)
        let state = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(state, NotificationDeliveryState.attemptStarted.rawValue)
    }

    func testConcurrentDispatchDoesNotReclassifyLiveAttemptAndSendsOnce() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909042", fixture: fixture)
        let transport = BlockingCountingTransport()
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        let first = Task { await dispatcher.dispatchPending() }
        await transport.waitUntilEntered()
        let second = Task { await dispatcher.dispatchPending() }
        await second.value
        let stateWhileBlocked = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(stateWhileBlocked, NotificationDeliveryState.attemptStarted.rawValue)
        await transport.release()
        await first.value

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 1)
        let state = try await fixture.store.read { connection in
            (
                try connection.scalarText("SELECT state FROM notification_events LIMIT 1"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events LIMIT 1")
            )
        }
        XCTAssertEqual(state.0, NotificationDeliveryState.sent.rawValue)
        XCTAssertEqual(state.1, 1)
    }

    func testSuccessfulSendRemainsExactlyOneAcrossReplayAndRelaunch() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let requestID = UUID(uuidString: "90909090-9090-4090-8090-909090909043")!
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: requestID,
            projectRoot: fixture.projectRoot.path,
            reason: "Request owner review once",
            command: .requestReview(id: "review-send-once", ticketID: "RR-09", kind: "agent_request", summary: "Review")
        )
        let firstResult = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(firstResult.error)
        let transport = CountingTransport()
        let firstDispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )

        await firstDispatcher.dispatchPending()
        let relaunchedStore = DeliveryStore(databaseURL: fixture.databaseURL)
        let replay = await AgentCommandDispatcher(store: relaunchedStore, projectRegistry: fixture.registry).dispatch(envelope)
        XCTAssertNil(replay.error)
        let relaunchedDispatcher = PushoverNotificationDispatcher(
            store: relaunchedStore,
            credentials: StaticPushoverCredentialsProvider(credentials: .init(appToken: "app-secret", userKey: "user-secret")),
            transport: transport
        )
        await relaunchedDispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 1)
        let state = try await relaunchedStore.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE fingerprint LIKE '%review-send-once%'"),
                try connection.scalarInt("SELECT attempt_count FROM notification_events WHERE subject_id = 'review-send-once'"),
                try connection.scalarText("SELECT state FROM notification_events WHERE subject_id = 'review-send-once'")
            )
        }
        XCTAssertEqual(state.0, 1)
        XCTAssertEqual(state.1, 1)
        XCTAssertEqual(state.2, NotificationDeliveryState.sent.rawValue)
    }

    func testProjectScopedOccurrenceAllowsTheSameLogicalSubjectInTwoProjects() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NotificationProjectScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))

        let events = try await store.transact(actor: .init(id: "fixture"), reason: "Seed project-scoped notification occurrences") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'One', 1)")
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-2', 'Two', 1)")
            let first = try MeaningfulDeliveryEvent.enqueue(
                projectID: .init(rawValue: "project-1"), kind: .importNeedsReview,
                subjectID: "shared-review", ticketID: nil, goalID: nil, connection: connection
            )
            let second = try MeaningfulDeliveryEvent.enqueue(
                projectID: .init(rawValue: "project-2"), kind: .importNeedsReview,
                subjectID: "shared-review", ticketID: nil, goalID: nil, connection: connection
            )
            return [first, second]
        }

        XCTAssertNotNil(events[0])
        XCTAssertNotNil(events[1])
        XCTAssertNotEqual(events[0]?.fingerprint, events[1]?.fingerprint)
        let projectCounts = try await store.read { connection in
            [
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-1'") ?? -1,
                try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE project_id = 'project-2'") ?? -1,
            ]
        }
        XCTAssertEqual(projectCounts, [1, 1])
    }

    func testGoalObservationRejectsExistingGoalOwnedByAnotherProject() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-GoalProjectScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed project-scoped goals") { connection in
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'One', 1)")
            try connection.execute("INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-2', 'Two', 1)")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-1', 'project-1', 'active', '2026-08-24T10:00:00Z')")
            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-2', 'project-2', 'active', '2026-08-24T10:00:00Z')")
        }
        let recorder = MeaningfulDeliveryEventRecorder(store: store)
        try await recorder.recordGoalObservation(
            projectID: .init(rawValue: "project-1"), threadID: "thread-1", goalID: "shared-goal",
            status: .active, observedAt: Date(timeIntervalSince1970: 1)
        )

        do {
            try await recorder.recordGoalObservation(
                projectID: .init(rawValue: "project-2"), threadID: "thread-2", goalID: "shared-goal",
                status: .blocked, observedAt: Date(timeIntervalSince1970: 2)
            )
            XCTFail("Expected cross-project goal ownership to be rejected")
        } catch {
            // The persisted project must remain the original owner regardless of the concrete error surface.
        }

        let projectID = try await store.read { connection in
            try connection.scalarText("SELECT project_id FROM observed_goals WHERE id = 'shared-goal'")
        }
        XCTAssertEqual(projectID, "project-1")
    }

    func testKeychainItemsAreDeviceOnlyNonSynchronizingAndAppScoped() {
        for account in PushoverKeychainStore.Account.allCases {
            let attributes = PushoverKeychainStore.itemAttributes(account: account)
            XCTAssertEqual(attributes[kSecClass as String] as? String, kSecClassGenericPassword as String)
            XCTAssertEqual(attributes[kSecAttrService as String] as? String, PushoverKeychainStore.service)
            XCTAssertEqual(attributes[kSecAttrAccount as String] as? String, account.rawValue)
            XCTAssertEqual(attributes[kSecAttrSynchronizable as String] as? Bool, false)
            XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
            XCTAssertNil(attributes[kSecAttrAccessGroup as String])
        }
    }

    func testDefaultPushoverSessionRejectsRedirectsFromFixedHTTPSEndpoint() async throws {
        XCTAssertEqual(PushoverClient.endpoint.scheme, "https")
        XCTAssertEqual(PushoverClient.endpoint.host, "api.pushover.net")
        XCTAssertEqual(PushoverClient.endpoint.path, "/1/messages.json")

        let delegate = PushoverClient.defaultSessionDelegate
        let redirected = URLRequest(url: URL(string: "https://example.invalid/capture")!)
        let response = HTTPURLResponse(
            url: PushoverClient.endpoint,
            statusCode: 307,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": redirected.url!.absoluteString]
        )!
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: PushoverClient.endpoint)
        let decision = await withCheckedContinuation { continuation in
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: redirected
            ) { continuation.resume(returning: $0) }
        }
        XCTAssertNil(decision)
        session.invalidateAndCancel()
    }

    func testNotificationHistoryProjectsSanitizedCopyAndVisibleFailureState() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        try await transition(.needsReview, requestID: "90909090-9090-4090-8090-909090909051", fixture: fixture)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: CountingTransport()
        )
        await dispatcher.dispatchPending()

        let projection = try await ProjectActivityProjection.load(
            from: fixture.store,
            projectID: .init(rawValue: "project-1")
        )
        let notification = try XCTUnwrap(projection.items.first { $0.source == .notification })
        XCTAssertEqual(notification.title, "RR-09 needs review")
        XCTAssertEqual(notification.detail, "A ticket entered Needs Review in Release Radar.")
        XCTAssertEqual(notification.notificationState, .failed)
        XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
        XCTAssertFalse(notification.title.contains("Transition"))
    }

    func testNotificationHistoryIncludesTicketlessProjectEventAndFailure() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909052")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Request project-level import review",
            command: .requestReview(id: "ticketless-review", ticketID: nil, kind: "unmatched_import", summary: "Uncertain mapping")
        ))
        XCTAssertNil(result.error)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: CountingTransport()
        )
        await dispatcher.dispatchPending()

        let projection = try await ProjectActivityProjection.load(
            from: fixture.store,
            projectID: .init(rawValue: "project-1")
        )
        let notification = try XCTUnwrap(projection.items.first {
            $0.source == .notification && $0.id.contains("notification-")
        })
        XCTAssertNil(notification.ticketID)
        XCTAssertEqual(notification.title, "Delivery item needs review")
        XCTAssertEqual(notification.notificationState, .failed)
        XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
    }

    func testCoordinatorRefreshesVisibleNotificationCountAndFailureAfterBridgeCommit() async throws {
        let fixture = try await makeFixture(firstDashboardOpened: true)
        let dispatcher = PushoverNotificationDispatcher(
            store: fixture.store,
            credentials: StaticPushoverCredentialsProvider(credentials: nil),
            transport: CountingTransport()
        )
        let coordinator = AppNotificationCoordinator(store: fixture.store, dispatcher: dispatcher)
        let model = await AppModel(store: fixture.store, notificationCoordinator: coordinator)
        await model.loadDashboard()
        await model.navigate(to: .projectOverview(.init(rawValue: "project-1")))
        let initialCount = await model.notificationCount
        let envelope = AgentCommandEnvelope(
            version: 1,
            requestID: UUID(uuidString: "90909090-9090-4090-8090-909090909053")!,
            projectRoot: fixture.projectRoot.path,
            reason: "Request owner review and refresh",
            command: .requestReview(id: "reactive-review", ticketID: nil, kind: "agent_request", summary: "Review")
        )
        let result = await fixture.dispatcher.dispatch(envelope)
        XCTAssertNil(result.error)

        await coordinator.dispatchAfterCommittedCommand(envelope, result: result)

        let updatedCount = await model.notificationCount
        let activity = await model.activity(for: .init(rawValue: "project-1"))
        XCTAssertEqual(updatedCount, initialCount + 1)
        let notification = try XCTUnwrap(activity?.items.first {
            $0.source == .notification && $0.title == "Delivery item needs review"
        })
        XCTAssertEqual(notification.notificationState, .failed)
        XCTAssertEqual(notification.notificationStatusText, "Delivery failed · Credentials missing")
    }

    private func transition(_ lane: TicketLane, requestID: String, fixture: Fixture) async throws {
        let result = await fixture.dispatcher.dispatch(.init(
            version: 1,
            requestID: UUID(uuidString: requestID)!,
            projectRoot: fixture.projectRoot.path,
            reason: "Transition RR-09 to \(lane.rawValue)",
            command: .transitionTicket(ticketID: "RR-09", lane: lane)
        ))
        XCTAssertNil(result.error)
    }

    private struct Fixture {
        let databaseURL: URL
        let projectRoot: URL
        let store: DeliveryStore
        let registry: InMemoryAuthorizedProjectRegistry
        let dispatcher: AgentCommandDispatcher
    }

    private func makeFixture(firstDashboardOpened: Bool) async throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-NotificationTests-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("store.sqlite")
        let store = DeliveryStore(databaseURL: databaseURL)
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed notification fixture") { connection in
            try connection.execute(
                "INSERT INTO projects (id, name, first_dashboard_opened) VALUES ('project-1', 'Release Radar', ?)",
                bindings: [.integer(firstDashboardOpened ? 1 : 0)]
            )
            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)", bindings: [.text(projectRoot.path)])
            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-09', 'project-1', 'phase-1', 'Durable alerts', 'in_progress')")
        }
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
    }
}

private actor CountingTransport: PushoverTransport {
    private(set) var sendCount = 0

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        sendCount += 1
        return .init(requestID: "provider-request")
    }
}

private actor BlockingCountingTransport: PushoverTransport {
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var entered = false
    private var released = false
    private(set) var sendCount = 0

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        sendCount += 1
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        if !released {
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        return .init(requestID: "provider-request")
    }
}

private actor InspectingFailingTransport: PushoverTransport {
    private let store: DeliveryStore
    private(set) var observedState: NotificationDeliveryState?

    init(store: DeliveryStore) {
        self.store = store
    }

    func send(_ message: PushoverMessage, credentials: PushoverCredentials) async throws -> PushoverProviderReceipt {
        let rawState = try await store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        observedState = rawState.flatMap(NotificationDeliveryState.init(rawValue:))
        throw PushoverTransportError.transportUnavailable
    }
}
