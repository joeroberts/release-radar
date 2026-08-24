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

        await dispatcher.dispatchPending()
        await dispatcher.dispatchPending()

        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 0)
        let state = try await fixture.store.read { connection in
            try connection.scalarText("SELECT state FROM notification_events LIMIT 1")
        }
        XCTAssertEqual(state, NotificationDeliveryState.unknown.rawValue)
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
