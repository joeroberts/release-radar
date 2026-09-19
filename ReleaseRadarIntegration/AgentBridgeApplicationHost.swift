import Foundation
import ReleaseRadarCore
import ServiceManagement

enum AgentBridgeApplicationError: Error, LocalizedError, Equatable {
    case requiresApproval
    case launchDenied
    case notFound
    case registrationFailed(String)
    case connectFailed(String)

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            "Release Radar Bridge Agent requires owner approval in System Settings > General > Login Items & Extensions."
        case .launchDenied:
            "Release Radar Bridge Agent launch is denied; enable it in System Settings > General > Login Items & Extensions."
        case .notFound:
            "Release Radar Bridge Agent is unavailable because its packaged LaunchAgent plist was not found."
        case let .registrationFailed(message):
            "Release Radar Bridge Agent registration failed: \(message)"
        case let .connectFailed(message):
            "Release Radar Bridge Agent connection failed: \(message)"
        }
    }
}

struct AgentBridgeHealthSnapshot: Equatable, Sendable {
    let generation: UInt64
    let observedAt: Date
    let health: BridgeConnectionHealth?
}

final class AgentBridgeApplicationHost: @unchecked Sendable {
    private let service: SMAppService
    private let callback: AgentBridgeAppCallback
    private let ownedStore: DeliveryStore?
    private let contextHandoff: CodexContextHandoffHost?
    private let connectionHealthChanged: @Sendable (AgentBridgeHealthSnapshot) -> Void
    private let requestedWireVersion: Int
    private var connection: NSXPCConnection?
    private var registeredHere = false
    private let healthLock = NSLock()
    private var healthGeneration: UInt64 = 0

    private init(
        dispatcher: AgentCommandDispatcher?,
        queries: AgentQueryDispatcher,
        ownedStore: DeliveryStore? = nil,
        contextHandoff: CodexContextHandoffHost? = nil,
        maintenanceMode: DocumentationMaintenanceMode? = nil,
        requestedWireVersion: Int = ReleaseRadarBridgeTransport.wireVersion,
        connectionHealthChanged: @escaping @Sendable (AgentBridgeHealthSnapshot) -> Void = { _ in },
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void,
        afterDispatchBeforeReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void,
        afterReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void
    ) {
        service = .agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName)
        callback = AgentBridgeAppCallback(
            dispatcher: dispatcher,
            queries: queries,
            maintenanceMode: maintenanceMode,
            beforeDispatch: beforeDispatch,
            afterDispatchBeforeReply: afterDispatchBeforeReply,
            afterReply: afterReply
        )
        self.ownedStore = ownedStore
        self.contextHandoff = contextHandoff
        self.connectionHealthChanged = connectionHealthChanged
        self.requestedWireVersion = requestedWireVersion
    }

    static func start(
        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL(),
        executionAssignments: (any ProjectExecutionAssignmentPreparing)? = nil,
        executionAssignmentRoot: (@Sendable () throws -> URL)? = nil,
        requestedWireVersion: Int = ReleaseRadarBridgeTransport.wireVersion,
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void = { _ in },
        afterDispatchBeforeReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in },
        afterReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in },
        connectionHealthChanged: @escaping @Sendable (AgentBridgeHealthSnapshot) -> Void = { _ in }
    ) async throws -> AgentBridgeApplicationHost {
        guard executionAssignments == nil || executionAssignmentRoot != nil else { throw ProjectExecutionError.unavailable }
        let store = DeliveryStore(databaseURL: databaseURL, executionAssignmentRoot: executionAssignmentRoot)
        if let executionAssignmentRoot { try await store.observeExecutionAssignments(root: executionAssignmentRoot) }
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store),
            executionAssignments: executionAssignments
        )
        let host = AgentBridgeApplicationHost(
            dispatcher: dispatcher,
            queries: AgentQueryDispatcher(store: store),
            ownedStore: store,
            contextHandoff: .production,
            requestedWireVersion: requestedWireVersion,
            connectionHealthChanged: connectionHealthChanged,
            beforeDispatch: beforeDispatch,
            afterDispatchBeforeReply: afterDispatchBeforeReply,
            afterReply: afterReply
        )
        do {
            try host.registerIfNeeded()
            try await host.connect()
            return host
        } catch {
            host.disconnectCallback()
            try? host.rollbackRegistration()
            throw error
        }
    }

    static func startDocumentationMaintenance(store: DeliveryStore, mode: DocumentationMaintenanceMode) async throws -> AgentBridgeApplicationHost {
        let dispatcher = mode == .readOnly ? nil : AgentCommandDispatcher(store: store, projectRegistry: PersistedAuthorizedProjectRegistry(store: store))
        let host = AgentBridgeApplicationHost(dispatcher: dispatcher, queries: AgentQueryDispatcher(store: store), maintenanceMode: mode,
                                               beforeDispatch: { _ in }, afterDispatchBeforeReply: { _, _ in }, afterReply: { _, _ in })
        // Maintenance never registers, installs, unregisters or repairs a service.
        guard host.service.status == .enabled else { throw AgentBridgeApplicationError.notFound }
        try await host.connect()
        return host
    }

    func disconnectCallback() {
        publishStaleHealth()
        connection?.invalidate()
        connection = nil
    }

    func refreshConnectionHealth() async throws -> BridgeConnectionHealth {
        let generation = healthLock.withLock { healthGeneration }
        guard let connection else { throw AgentBridgeApplicationError.connectFailed("Bridge connection is not registered") }
        return try await withCheckedThrowingContinuation { continuation in
            let gate = AgentBridgeHealthContinuationGate(continuation)
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.resume(throwing: AgentBridgeApplicationError.connectFailed(error.localizedDescription))
            }) as? ReleaseRadarAppBrokerXPC else {
                gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker health proxy unavailable")); return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker health check timed out"))
            }
            proxy.connectionHealth(ReleaseRadarBridgeTransport.wireVersion) { data in
                guard self.healthLock.withLock({ self.healthGeneration == generation }) else {
                    gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Bridge health reply is stale")); return
                }
                guard let health = try? JSONDecoder().decode(BridgeConnectionHealth.self, from: data) else {
                    gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker health response was invalid")); return
                }
                guard health.wireVersion == ReleaseRadarBridgeTransport.wireVersion else {
                    gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Bridge version mismatch")); return
                }
                self.publishHealth(health, generation: generation)
                gate.resume(returning: health)
            }
        }
    }

    func stopAndDrain() async {
        await callback.stopAndDrain()
        disconnectCallback()
        await ownedStore?.close()
    }

    func unregister() throws {
        try unregisterService()
    }

    private func rollbackRegistration() throws {
        guard registeredHere else { return }
        try unregisterService()
    }

    private func unregisterService() throws {
        do {
            try service.unregister()
            registeredHere = false
        } catch {
            throw AgentBridgeApplicationError.registrationFailed(error.localizedDescription)
        }
    }

    private func registerIfNeeded() throws {
        switch service.status {
        case .notRegistered, .notFound:
            do {
                try service.register()
                registeredHere = true
            } catch {
                throw AgentBridgeApplicationError.registrationFailed(error.localizedDescription)
            }
        case .enabled:
            break
        case .requiresApproval:
            throw AgentBridgeApplicationError.requiresApproval
        @unknown default:
            throw AgentBridgeApplicationError.registrationFailed("Unknown ServiceManagement status")
        }

        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            throw AgentBridgeApplicationError.requiresApproval
        case .notFound:
            throw AgentBridgeApplicationError.notFound
        case .notRegistered:
            throw AgentBridgeApplicationError.registrationFailed("Service remained unregistered")
        @unknown default:
            throw AgentBridgeApplicationError.registrationFailed("Unknown ServiceManagement status")
        }
    }

    private func connect() async throws {
        guard let brokerRequirement = ReleaseRadarBridgeTransport.brokerRequirement else {
            throw AgentBridgeApplicationError.connectFailed("Invalid broker signing requirement")
        }
        let connection = NSXPCConnection(
            machServiceName: ReleaseRadarBridgeTransport.appMachService,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarAppBrokerXPC.self)
        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarAppCallbackXPC.self)
        connection.exportedObject = callback
        connection.setCodeSigningRequirement(brokerRequirement)
        connection.invalidationHandler = { [weak self] in
            self?.publishStaleHealth()
        }
        connection.interruptionHandler = { [weak self] in
            self?.publishStaleHealth()
        }
        self.connection = connection
        connection.resume()

        do {
            let returnedVersion = try await awaitRegistration(on: connection)
            guard returnedVersion == ReleaseRadarBridgeTransport.wireVersion else {
                throw AgentBridgeApplicationError.connectFailed("Bridge version mismatch")
            }
            if let contextHandoff {
                let endpoint = try contextHandoff.endpoint()
                // The endpoint has no folder capability. Its direct listener
                // independently authenticates exact Coordinator signing.
                let version: Int = try await withCheckedThrowingContinuation { continuation in
                    let response = AgentBridgeContinuationGate(continuation)
                    guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                        response.resume(throwing: CodexExecutionContextAccessFailure(stage: .handoff))
                    }) as? ReleaseRadarAppBrokerXPC else {
                        response.resume(throwing: CodexExecutionContextAccessFailure(stage: .handoff)); return
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        response.resume(throwing: CodexExecutionContextAccessFailure(stage: .handoff))
                    }
                    proxy.registerContextEndpoint(ReleaseRadarBridgeTransport.wireVersion, endpoint: endpoint) {
                        response.resume(returning: $0)
                    }
                }
                guard version == ReleaseRadarBridgeTransport.wireVersion else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
            }
        } catch {
            connection.invalidate()
            self.connection = nil
            switch service.status {
            case .requiresApproval:
                throw AgentBridgeApplicationError.launchDenied
            case .notFound:
                throw AgentBridgeApplicationError.notFound
            default:
                if let applicationError = error as? AgentBridgeApplicationError {
                    throw applicationError
                }
                throw AgentBridgeApplicationError.connectFailed(error.localizedDescription)
            }
        }
    }

    private func publishStaleHealth() {
        let snapshot = healthLock.withLock { () -> AgentBridgeHealthSnapshot in
            healthGeneration &+= 1
            return .init(generation: healthGeneration, observedAt: Date(), health: nil)
        }
        connectionHealthChanged(snapshot)
    }

    private func publishHealth(_ health: BridgeConnectionHealth, generation: UInt64) {
        let snapshot = healthLock.withLock { () -> AgentBridgeHealthSnapshot? in
            guard healthGeneration == generation else { return nil }
            return .init(generation: generation, observedAt: Date(), health: health)
        }
        if let snapshot { connectionHealthChanged(snapshot) }
    }

    private func awaitRegistration(on connection: NSXPCConnection) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let gate = AgentBridgeContinuationGate(continuation)
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.resume(throwing: AgentBridgeApplicationError.connectFailed(error.localizedDescription))
            }) as? ReleaseRadarAppBrokerXPC else {
                gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker proxy unavailable"))
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker registration timed out"))
            }
            proxy.registerApp(requestedWireVersion) { version in
                gate.resume(returning: version)
            }
        }
    }

}

private final class AgentBridgeHealthContinuationGate: @unchecked Sendable {
    private let lock = NSLock(); private var continuation: CheckedContinuation<BridgeConnectionHealth, Error>?
    init(_ continuation: CheckedContinuation<BridgeConnectionHealth, Error>) { self.continuation = continuation }
    func resume(returning value: BridgeConnectionHealth) { lock.withLock { continuation?.resume(returning: value); continuation = nil } }
    func resume(throwing error: Error) { lock.withLock { continuation?.resume(throwing: error); continuation = nil } }
}

final class AgentBridgeAppCallback: NSObject, ReleaseRadarAppCallbackXPC, @unchecked Sendable {
    private let dispatcher: AgentCommandDispatcher?
    private let queries: AgentQueryDispatcher
    private let maintenanceMode: DocumentationMaintenanceMode?
    private let beforeDispatch: @Sendable (AgentCommandEnvelope) async -> Void
    private let afterDispatchBeforeReply: @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void
    private let afterReply: @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void
    private let workGate = AgentBridgeCallbackWorkGate()

    init(
        dispatcher: AgentCommandDispatcher?,
        queries: AgentQueryDispatcher,
        maintenanceMode: DocumentationMaintenanceMode? = nil,
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void,
        afterDispatchBeforeReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void,
        afterReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void
    ) {
        self.dispatcher = dispatcher
        self.queries = queries
        self.maintenanceMode = maintenanceMode
        self.beforeDispatch = beforeDispatch
        self.afterDispatchBeforeReply = afterDispatchBeforeReply
        self.afterReply = afterReply
    }

    private static func permitsExecutionEnvelopeFields(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commands = object["command"] as? [String: Any],
              let fields = commands["prepareExecutionAssignment"] as? [String: Any] else { return true }
        guard commands.count == 1,
              Set(object.keys).isSubset(of: ["version", "requestID", "projectRoot", "assertedThreadID", "expectedRegistration", "reason", "command"]),
              Set(fields.keys).isSubset(of: ["projectID", "ticketID", "taskID", "expectedTaskPlanRevision", "expectedPhaseRevision", "reviewOfAssignmentID", "baselineFromAssignmentID"]) else { return false }
        if let registration = object["expectedRegistration"] as? [String: Any] {
            guard Set(registration.keys) == ["projectID", "registrationID", "requestGeneration"],
                  registration["projectID"] is String else { return false }
        }
        return true
    }

    func dispatch(
        _ wireVersion: Int,
        envelope data: Data,
        admissionDeadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    ) {
        let replyGate = AgentBridgeDataReply(reply)
        guard workGate.begin() else {
            replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
            return
        }
        var handedOff = false
        defer { if !handedOff { workGate.end() } }
        let now = Date().timeIntervalSince1970
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["query"] != nil {
            guard wireVersion == ReleaseRadarBridgeTransport.wireVersion, data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
                  admissionDeadline > now, admissionDeadline - now <= ReleaseRadarBridgeTransport.maximumDeadlineInterval,
                  Set(object.keys).isSubset(of: ["version", "projectRoot", "query"]),
                  let query = try? JSONDecoder().decode(AgentQueryEnvelope.self, from: data) else {
                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData()); return
            }
            Task {
                defer { workGate.end() }
                let result = await queries.dispatch(query, admissionDeadline: admissionDeadline)
                replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.appUnavailableResultData())
            }
            handedOff = true
            return
        }
        guard wireVersion == ReleaseRadarBridgeTransport.wireVersion,
              data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
              admissionDeadline > now,
              admissionDeadline - now <= ReleaseRadarBridgeTransport.maximumDeadlineInterval,
              ReleaseRadarBridgeTransport.envelopeVersion(in: data) == ReleaseRadarBridgeTransport.commandEnvelopeVersion,
              Self.permitsExecutionEnvelopeFields(data),
              let envelope = try? JSONDecoder().decode(AgentCommandEnvelope.self, from: data)
        else {
            if let found = ReleaseRadarBridgeTransport.envelopeVersion(in: data),
               found != ReleaseRadarBridgeTransport.commandEnvelopeVersion {
                replyGate.send(ReleaseRadarBridgeTransport.unsupportedVersionResultData(found: found))
            } else {
                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
            }
            return
        }

        guard let dispatcher, maintenanceMode != .readOnly,
              maintenanceMode == nil || Self.permitsDocumentationMaintenance(envelope) else {
            replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData()); return
        }
        Task {
            defer { workGate.end() }
            await beforeDispatch(envelope)
            guard admissionDeadline > Date().timeIntervalSince1970 else {
                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
                return
            }
            let result = maintenanceMode == .commands
                ? await dispatcher.dispatchDocumentationMaintenance(envelope, admissionDeadline: admissionDeadline)
                : await dispatcher.dispatch(envelope, admissionDeadline: admissionDeadline)
            await afterDispatchBeforeReply(envelope, result)
            replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.outcomeUnknownResultData())
            await afterReply(envelope, result)
        }
        handedOff = true
    }

    func stopAndDrain() async {
        await workGate.stopAndDrain()
    }
    static func permitsDocumentationMaintenance(_ envelope: AgentCommandEnvelope) -> Bool {
        if envelope.command.isDocumentationMutation { return true }
        if case let .addEvidence(id, ticket, path) = envelope.command {
            let root = URL(fileURLWithPath: envelope.projectRoot)
            let exactPath = root.appendingPathComponent(RepositoryDocumentContract.guidancePath).path
            return ticket == nil && path == exactPath
                && id.hasPrefix(RepositoryDocumentContract.handoffEvidenceIDPrefix)
                && id.count > RepositoryDocumentContract.handoffEvidenceIDPrefix.count
        }
        return false
    }

}

private final class AgentBridgeCallbackWorkGate: @unchecked Sendable {
    private let lock = NSLock()
    private var acceptsWork = true
    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func begin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard acceptsWork else { return false }
        inFlight += 1
        return true
    }

    func end() {
        lock.lock()
        precondition(inFlight > 0)
        inFlight -= 1
        let completed = inFlight == 0 ? waiters : []
        if inFlight == 0 { waiters.removeAll() }
        lock.unlock()
        for waiter in completed { waiter.resume() }
    }

    func stopAndDrain() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            acceptsWork = false
            if inFlight == 0 {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}

private final class AgentBridgeDataReply: @unchecked Sendable {
    private let callback: (Data) -> Void

    init(_ callback: @escaping (Data) -> Void) {
        self.callback = callback
    }

    func send(_ data: Data) {
        callback(data)
    }
}

private final class AgentBridgeContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int, Error>?

    init(_ continuation: CheckedContinuation<Int, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Int) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Int, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let result = continuation
        continuation = nil
        return result
    }
}
