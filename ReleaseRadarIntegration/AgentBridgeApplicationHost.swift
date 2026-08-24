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
        dispatcher: AgentCommandDispatcher,
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void
    ) {
        service = .agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName)
        callback = AgentBridgeAppCallback(dispatcher: dispatcher, beforeDispatch: beforeDispatch)
    }

    static func start(
        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL(),
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void = { _ in }
    ) async throws -> AgentBridgeApplicationHost {
        let store = DeliveryStore(databaseURL: databaseURL)
        let projects = try await loadAuthorizedProjects(from: store)
        let dispatcher = AgentCommandDispatcher(
            store: store,
            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: projects)
        )
        let host = AgentBridgeApplicationHost(dispatcher: dispatcher, beforeDispatch: beforeDispatch)
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
            guard returnedVersion == ReleaseRadarBridgeTransport.version else {
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
            proxy.registerApp(ReleaseRadarBridgeTransport.version) { version in
                gate.resume(returning: version)
            }
        }
    }

    private static func loadAuthorizedProjects(from store: DeliveryStore) async throws -> [AuthorizedProject] {
        try await store.read { connection in
            var rootsByProject: [String: [URL]] = [:]
            var offset: Int64 = 0
            while let row = try connection.row(
                "SELECT project_id, path FROM project_roots ORDER BY project_id, id LIMIT 1 OFFSET ?",
                bindings: [.integer(offset)]
            ) {
                guard case let .text(projectID)? = row["project_id"],
                      case let .text(path)? = row["path"]
                else {
                    throw AgentBridgeApplicationError.connectFailed("Invalid persisted project root")
                }
                rootsByProject[projectID, default: []].append(URL(fileURLWithPath: path))
                offset += 1
            }
            return rootsByProject.compactMap { projectID, roots in
                guard let canonicalRoot = roots.first else { return nil }
                return AuthorizedProject(
                    projectID: ProjectID(rawValue: projectID),
                    canonicalRoot: canonicalRoot,
                    authorizedRoots: roots
                )
            }
        }
    }
}

private final class AgentBridgeAppCallback: NSObject, ReleaseRadarAppCallbackXPC, @unchecked Sendable {
    private let dispatcher: AgentCommandDispatcher
    private let beforeDispatch: @Sendable (AgentCommandEnvelope) async -> Void

    init(
        dispatcher: AgentCommandDispatcher,
        beforeDispatch: @escaping @Sendable (AgentCommandEnvelope) async -> Void
    ) {
        self.dispatcher = dispatcher
        self.beforeDispatch = beforeDispatch
    }

    func dispatch(
        _ version: Int,
        envelope data: Data,
        deadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    ) {
        let replyGate = AgentBridgeDataReply(reply)
        let now = Date().timeIntervalSince1970
        guard version == ReleaseRadarBridgeTransport.version,
              data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
              deadline > now,
              deadline - now <= ReleaseRadarBridgeTransport.maximumDeadlineInterval,
              ReleaseRadarBridgeTransport.envelopeVersion(in: data) == ReleaseRadarBridgeTransport.version,
              let envelope = try? JSONDecoder().decode(AgentCommandEnvelope.self, from: data)
        else {
            if let found = ReleaseRadarBridgeTransport.envelopeVersion(in: data),
               found != ReleaseRadarBridgeTransport.version {
                replyGate.send(ReleaseRadarBridgeTransport.unsupportedVersionResultData(found: found))
            } else {
                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
            }
            return
        }

        Task {
            await beforeDispatch(envelope)
            guard deadline > Date().timeIntervalSince1970 else {
                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
                return
            }
            let result = await dispatcher.dispatch(envelope, deadline: deadline)
            replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.appUnavailableResultData())
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
