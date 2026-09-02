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

final class AgentBridgeApplicationHost: @unchecked Sendable {
    private let service: SMAppService
    private let callback: AgentBridgeAppCallback
    private var connection: NSXPCConnection?
    private var registeredHere = false

    private init(
        dispatcher: AgentCommandDispatcher?,
        queries: AgentQueryDispatcher,
        maintenanceMode: DocumentationMaintenanceMode? = nil,
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
    }

    static func start(
        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL(),
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void = { _ in },
        afterDispatchBeforeReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in },
        afterReply: @escaping @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void = { _, _ in }
    ) async throws -> AgentBridgeApplicationHost {
        let store = DeliveryStore(databaseURL: databaseURL)
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: PersistedAuthorizedProjectRegistry(store: store)
        )
        let host = AgentBridgeApplicationHost(
            dispatcher: dispatcher,
            queries: AgentQueryDispatcher(store: store),
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
        connection?.invalidate()
        connection = nil
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
        connection.resume()
        self.connection = connection

        do {
            let returnedVersion = try await awaitRegistration(on: connection)
            guard returnedVersion == ReleaseRadarBridgeTransport.wireVersion else {
                throw AgentBridgeApplicationError.connectFailed("Bridge version mismatch")
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
            proxy.registerApp(ReleaseRadarBridgeTransport.wireVersion) { version in
                gate.resume(returning: version)
            }
        }
    }

}

final class AgentBridgeAppCallback: NSObject, ReleaseRadarAppCallbackXPC, @unchecked Sendable {
    private let dispatcher: AgentCommandDispatcher?
    private let queries: AgentQueryDispatcher
    private let maintenanceMode: DocumentationMaintenanceMode?
    private let beforeDispatch: @Sendable (AgentCommandEnvelope) async -> Void
    private let afterDispatchBeforeReply: @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void
    private let afterReply: @Sendable (AgentCommandEnvelope, AgentCommandResult) async -> Void

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

    func dispatch(
        _ wireVersion: Int,
        envelope data: Data,
        admissionDeadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    ) {
        let replyGate = AgentBridgeDataReply(reply)
        let now = Date().timeIntervalSince1970
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["query"] != nil {
            guard wireVersion == ReleaseRadarBridgeTransport.wireVersion, data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
                  admissionDeadline > now, admissionDeadline - now <= ReleaseRadarBridgeTransport.maximumDeadlineInterval,
                  Set(object.keys).isSubset(of: ["version", "projectRoot", "query"]),
                  let query = try? JSONDecoder().decode(AgentQueryEnvelope.self, from: data) else {
                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData()); return
            }
            Task {
                let result = await queries.dispatch(query, admissionDeadline: admissionDeadline)
                replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.appUnavailableResultData())
            }
            return
        }
        guard wireVersion == ReleaseRadarBridgeTransport.wireVersion,
              data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
              admissionDeadline > now,
              admissionDeadline - now <= ReleaseRadarBridgeTransport.maximumDeadlineInterval,
              ReleaseRadarBridgeTransport.envelopeVersion(in: data) == ReleaseRadarBridgeTransport.commandEnvelopeVersion,
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
            Task {
                await afterReply(envelope, result)
            }
        }
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
