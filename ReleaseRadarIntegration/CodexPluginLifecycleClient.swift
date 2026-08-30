import Foundation
import ReleaseRadarCore
import ServiceManagement

final class CodexPluginLifecycleClient: CodexPluginLifecycleManaging, @unchecked Sendable {
    private let service = SMAppService.agent(plistName: ReleaseRadarPluginLifecycleTransport.launchAgentPlistName)
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    func status() async -> CodexPluginHelperReply { await call(.status) }
    func install() async -> CodexPluginHelperReply { await call(.install) }
    func remove() async -> CodexPluginHelperReply { await call(.remove) }
    func reinstall() async -> CodexPluginHelperReply { await call(.reinstall) }

    func unregister() {
        lock.withLock {
            connection?.invalidate()
            connection = nil
        }
        try? service.unregister()
    }

    private enum Operation {
        case status
        case install
        case remove
        case reinstall
    }

    private func call(_ operation: Operation) async -> CodexPluginHelperReply {
        do {
            try registerIfNeeded()
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

    private func connected() throws -> NSXPCConnection {
        lock.lock()
        let existing = connection
        lock.unlock()
        if let existing { return existing }
        let connection = NSXPCConnection(
            machServiceName: ReleaseRadarPluginLifecycleTransport.machService,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarPluginLifecycleXPC.self)
        connection.setCodeSigningRequirement(ReleaseRadarPluginLifecycleTransport.helperRequirement)
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
