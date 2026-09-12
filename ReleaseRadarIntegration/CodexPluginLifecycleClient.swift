import Foundation
import ReleaseRadarCore
import ServiceManagement

protocol PluginLifecycleServiceManaging: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func unregister(completionHandler handler: @Sendable @escaping (Error?) -> Void)
}

extension SMAppService: PluginLifecycleServiceManaging {}

final class CodexPluginLifecycleClient: CodexPluginLifecycleManaging, @unchecked Sendable {
    typealias RemoteInvoker = @Sendable (Operation) async -> CodexPluginHelperReply

    enum Operation: Equatable {
        case status
        case install
        case remove
        case reinstall
    }

    private let service: any PluginLifecycleServiceManaging
    private let invokeRemote: RemoteInvoker?
    private let machServiceName: String
    private let helperCodeSigningRequirement: String
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    init(
        service: any PluginLifecycleServiceManaging = SMAppService.agent(
            plistName: ReleaseRadarPluginLifecycleTransport.launchAgentPlistName
        ),
        invokeRemote: RemoteInvoker? = nil,
        machServiceName: String = ReleaseRadarPluginLifecycleTransport.machService,
        helperCodeSigningRequirement: String = ReleaseRadarPluginLifecycleTransport.helperRequirement
    ) {
        self.service = service
        self.invokeRemote = invokeRemote
        self.machServiceName = machServiceName
        self.helperCodeSigningRequirement = helperCodeSigningRequirement
    }

    func status() async -> CodexPluginHelperReply { await call(.status) }
    func statusReadOnly() async -> CodexPluginHelperReply {
        guard service.status == .enabled else {
            return .init(
                wireVersion: ReleaseRadarPluginLifecycleTransport.wireVersion,
                observedState: nil,
                error: .codexUnavailable
            )
        }
        return validatedReply(await invoke(.status))
    }
    func install() async -> CodexPluginHelperReply { await call(.install) }
    func remove() async -> CodexPluginHelperReply { await call(.remove) }
    func reinstall() async -> CodexPluginHelperReply { await call(.reinstall) }
    func restartHelper() async -> CodexPluginHelperReply {
        do {
            try await rebindService()
            return validatedReply(await invoke(.status))
        } catch {
            return Self.failureReply(for: error)
        }
    }

    func unregister() {
        invalidateConnection()
        try? service.unregister()
    }

    private func call(_ operation: Operation) async -> CodexPluginHelperReply {
        do {
            try registerIfNeeded()
            let initialStatus = validatedReply(await invoke(.status))
            let currentStatus = try await recoverRegistrationIfNeeded(after: initialStatus)
            guard currentStatus.error == nil, operation != .status else { return currentStatus }
            return validatedReply(await invoke(operation))
        } catch {
            return Self.failureReply(for: error)
        }
    }

    static func failureReply(for error: Error) -> CodexPluginHelperReply {
        let serviceError = error as NSError
        let lifecycleError: CodexPluginLifecycleError
        if let known = error as? CodexPluginLifecycleError {
            lifecycleError = known
        } else if serviceError.domain == "SMAppServiceErrorDomain", serviceError.code == 1 {
            lifecycleError = .unauthorizedPeer
        } else {
            lifecycleError = .codexUnavailable
        }
        return .init(
            wireVersion: ReleaseRadarPluginLifecycleTransport.wireVersion,
            observedState: nil,
            error: lifecycleError
        )
    }

    private func registerIfNeeded() throws {
        switch service.status {
        case .notRegistered, .notFound:
            try service.register()
        case .enabled:
            break
        case .requiresApproval:
            throw CodexPluginLifecycleError.unauthorizedPeer
        @unknown default:
            throw CodexPluginLifecycleError.codexUnavailable
        }
    }

    private func recoverRegistrationIfNeeded(
        after reply: CodexPluginHelperReply
    ) async throws -> CodexPluginHelperReply {
        guard reply.error == .codexUnavailable || reply.error == .marketplaceConflict else {
            return reply
        }
        try await rebindService()
        return validatedReply(await invoke(.status))
    }

    private func validatedReply(_ reply: CodexPluginHelperReply) -> CodexPluginHelperReply {
        guard reply.wireVersion == ReleaseRadarPluginLifecycleTransport.wireVersion else {
            return malformedReply()
        }
        switch (reply.observedState, reply.error) {
        case (.some, nil), (nil, .some):
            return reply
        default:
            return malformedReply()
        }
    }

    private func malformedReply() -> CodexPluginHelperReply {
        .init(
            wireVersion: ReleaseRadarPluginLifecycleTransport.wireVersion,
            observedState: nil,
            error: .malformedResult
        )
    }

    private func rebindService() async throws {
        invalidateConnection()
        switch service.status {
        case .enabled:
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                service.unregister { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        case .notRegistered, .notFound:
            break
        case .requiresApproval:
            throw CodexPluginLifecycleError.unauthorizedPeer
        @unknown default:
            throw CodexPluginLifecycleError.codexUnavailable
        }
        try service.register()
    }

    private func invoke(_ operation: Operation) async -> CodexPluginHelperReply {
        if let invokeRemote {
            return await invokeRemote(operation)
        }
        do {
            let connection = try connected()
            return await withCheckedContinuation { continuation in
                let gate = PluginLifecycleReplyGate(continuation)
                guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                    gate.resume(.init(wireVersion: 1, observedState: nil, error: .codexUnavailable))
                }) as? ReleaseRadarPluginLifecycleXPC else {
                    gate.resume(.init(wireVersion: 1, observedState: nil, error: .codexUnavailable))
                    return
                }
                let reply: (Data) -> Void = { data in
                    let decoded = (try? ReleaseRadarPluginLifecycleTransport.decode(data))
                        ?? .init(wireVersion: 1, observedState: nil, error: .malformedResult)
                    gate.resume(decoded)
                }
                switch operation {
                case .status: proxy.status(withReply: reply)
                case .install: proxy.install(withReply: reply)
                case .remove: proxy.remove(withReply: reply)
                case .reinstall: proxy.reinstall(withReply: reply)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 16) {
                    gate.resume(.init(wireVersion: 1, observedState: nil, error: .timeout))
                }
            }
        } catch {
            return Self.failureReply(for: error)
        }
    }

    private func invalidateConnection() {
        lock.withLock {
            connection?.invalidate()
            connection = nil
        }
    }

    private func connected() throws -> NSXPCConnection {
        lock.lock()
        let existing = connection
        lock.unlock()
        if let existing { return existing }
        let connection = NSXPCConnection(
            machServiceName: machServiceName,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarPluginLifecycleXPC.self)
        connection.setCodeSigningRequirement(helperCodeSigningRequirement)
        connection.invalidationHandler = { [weak self, weak connection] in
            self?.lock.withLock {
                if self?.connection === connection { self?.connection = nil }
            }
        }
        connection.resume()
        lock.withLock { self.connection = connection }
        return connection
    }
}

private final class PluginLifecycleReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CodexPluginHelperReply, Never>?

    init(_ continuation: CheckedContinuation<CodexPluginHelperReply, Never>) {
        self.continuation = continuation
    }

    func resume(_ reply: CodexPluginHelperReply) {
        lock.withLock {
            continuation?.resume(returning: reply)
            continuation = nil
        }
    }
}
