import Foundation

public protocol NotificationDispatcher: Sendable {
    func enqueue(_ event: MeaningfulDeliveryEvent) async
}

public actor PushoverNotificationDispatcher: NotificationDispatcher {
    private let store: DeliveryStore
    private let credentials: any PushoverCredentialsProvider
    private let transport: any PushoverTransport
    private let beforeLaunchRecovery: @Sendable () async -> Void
    private var didPrepareForLaunch = false
    private var workInProgress = false
    private var launchRecoveryRequested = false
    private var dispatchRequested = false

    public init(
        store: DeliveryStore,
        credentials: any PushoverCredentialsProvider = PushoverKeychainStore(),
        transport: any PushoverTransport = PushoverClient()
    ) {
        self.store = store
        self.credentials = credentials
        self.transport = transport
        beforeLaunchRecovery = {}
    }

    init(
        store: DeliveryStore,
        credentials: any PushoverCredentialsProvider,
        transport: any PushoverTransport,
        beforeLaunchRecovery: @escaping @Sendable () async -> Void
    ) {
        self.store = store
        self.credentials = credentials
        self.transport = transport
        self.beforeLaunchRecovery = beforeLaunchRecovery
    }

    public func enqueue(_ event: MeaningfulDeliveryEvent) async {
        await dispatchPending()
    }

    public func prepareForLaunch() async {
        guard !didPrepareForLaunch else { return }
        didPrepareForLaunch = true
        launchRecoveryRequested = true
        await runRequestedWork()
    }

    public func dispatchPending() async {
        dispatchRequested = true
        await runRequestedWork()
    }

    private func runRequestedWork() async {
        guard !workInProgress else { return }
        workInProgress = true
        defer { workInProgress = false }

        while launchRecoveryRequested || dispatchRequested {
            if launchRecoveryRequested {
                launchRecoveryRequested = false
                try? await recoverAmbiguousAttempts()
            }
            if dispatchRequested {
                dispatchRequested = false
                await dispatchPendingBatch()
            }
        }
    }

    private func dispatchPendingBatch() async {
        guard let ids = try? await pendingEventIDs() else {
            // Store unavailability is already surfaced by the app and must not block dashboard use.
            return
        }
        for id in ids {
            await dispatch(id: id)
        }
    }

    private func recoverAmbiguousAttempts() async throws {
        let count = try await store.read { connection in
            try connection.scalarInt("SELECT COUNT(*) FROM notification_events WHERE state = 'attempt_started'") ?? 0
        }
        guard count > 0 else { return }
        await beforeLaunchRecovery()
        try await store.transact(
            actor: .init(id: "notification-dispatcher"),
            reason: "Mark interrupted notification attempts unknown"
        ) { connection in
            try connection.execute(
                """
                UPDATE notification_events
                SET state = 'unknown', completed_at = ?, failure_code = 'ambiguous_attempt'
                WHERE state = 'attempt_started'
                """,
                bindings: [.text(ISO8601DateFormatter().string(from: Date()))]
            )
        }
    }

    private func pendingEventIDs() async throws -> [String] {
        try await store.read { connection in
            var ids: [String] = []
            var offset: Int64 = 0
            while let id = try connection.scalarText(
                "SELECT id FROM notification_events WHERE state = 'queued' ORDER BY created_at, rowid LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                ids.append(id)
                offset += 1
            }
            return ids
        }
    }

    private func dispatch(id: String) async {
        let loadedCredentials: PushoverCredentials
        do {
            guard let credentials = try credentials.loadCredentials() else {
                try await recordFailure(id: id, code: PushoverTransportError.credentialsMissing.sanitizedCode)
                return
            }
            loadedCredentials = credentials
        } catch {
            try? await recordFailure(id: id, code: PushoverTransportError.credentialsMissing.sanitizedCode)
            return
        }

        do {
            let event = try await markAttemptStarted(id: id)
            let receipt = try await transport.send(
                PushoverMessage(title: event.title, message: event.message),
                credentials: loadedCredentials
            )
            try await recordSuccess(id: id, receipt: receipt.requestID)
        } catch NotificationDispatchError.notQueued {
            return
        } catch let error as PushoverTransportError {
            try? await recordFailure(id: id, code: error.sanitizedCode)
        } catch {
            try? await recordFailure(id: id, code: PushoverTransportError.transportUnavailable.sanitizedCode)
        }
    }

    private func markAttemptStarted(id: String) async throws -> MeaningfulDeliveryEvent {
        try await store.transact(
            actor: .init(id: "notification-dispatcher"),
            reason: "Start notification attempt"
        ) { connection in
            guard let row = try connection.row(
                """
                SELECT id, project_id, event_kind, subject_id, occurrence, fingerprint,
                       title, message, ticket_id, goal_id
                FROM notification_events
                WHERE id = ? AND state = 'queued'
                """,
                bindings: [.text(id)]
            ) else {
                throw NotificationDispatchError.notQueued
            }
            try connection.execute(
                """
                UPDATE notification_events
                SET state = 'attempt_started', attempt_count = attempt_count + 1,
                    attempt_started_at = ?, failure_code = NULL
                WHERE id = ? AND state = 'queued'
                """,
                bindings: [.text(ISO8601DateFormatter().string(from: Date())), .text(id)]
            )
            return try Self.event(from: row)
        }
    }

    private func recordSuccess(id: String, receipt: String?) async throws {
        let sanitizedReceipt = receipt.flatMap(Self.sanitizedReceipt)
        try await store.transact(
            actor: .init(id: "notification-dispatcher"),
            reason: "Record notification delivery"
        ) { connection in
            try connection.execute(
                """
                UPDATE notification_events
                SET state = 'sent', provider_receipt = ?, completed_at = ?, failure_code = NULL
                WHERE id = ? AND state = 'attempt_started'
                """,
                bindings: [
                    sanitizedReceipt.map(SQLiteValue.text) ?? .null,
                    .text(ISO8601DateFormatter().string(from: Date())),
                    .text(id),
                ]
            )
        }
    }

    private func recordFailure(id: String, code: String) async throws {
        try await store.transact(
            actor: .init(id: "notification-dispatcher"),
            reason: "Record notification failure"
        ) { connection in
            try connection.execute(
                """
                UPDATE notification_events
                SET state = 'failed', completed_at = ?, failure_code = ?
                WHERE id = ? AND state IN ('queued', 'attempt_started')
                """,
                bindings: [
                    .text(ISO8601DateFormatter().string(from: Date())),
                    .text(code), .text(id),
                ]
            )
        }
    }

    private static func event(from row: [String: SQLiteValue]) throws -> MeaningfulDeliveryEvent {
        guard
            case let .text(id)? = row["id"],
            case let .text(projectID)? = row["project_id"],
            case let .text(rawKind)? = row["event_kind"],
            let kind = MeaningfulDeliveryEventKind(rawValue: rawKind),
            case let .text(subjectID)? = row["subject_id"],
            case let .integer(occurrence)? = row["occurrence"],
            case let .text(fingerprint)? = row["fingerprint"],
            case let .text(title)? = row["title"],
            case let .text(message)? = row["message"]
        else { throw NotificationDispatchError.invalidEvent }
        let ticketID: TicketID? = if case let .text(value)? = row["ticket_id"] { .init(rawValue: value) } else { nil }
        let goalID: ObservedGoalID? = if case let .text(value)? = row["goal_id"] { .init(rawValue: value) } else { nil }
        return MeaningfulDeliveryEvent(
            id: .init(rawValue: id), projectID: .init(rawValue: projectID), kind: kind,
            subjectID: subjectID, occurrence: occurrence, fingerprint: fingerprint,
            title: title, message: message, ticketID: ticketID, goalID: goalID
        )
    }

    private static func sanitizedReceipt(_ receipt: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let value = String(receipt.unicodeScalars.filter(allowed.contains).prefix(256))
        return value.isEmpty ? nil : value
    }
}

private enum NotificationDispatchError: Error {
    case notQueued
    case invalidEvent
}
