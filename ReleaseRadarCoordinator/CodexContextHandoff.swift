import Foundation
import ReleaseRadarCore

struct CodexContextTransfer: Codable, Sendable {
    let id: UUID
    let contextID: UUID
    let attemptID: UUID
    let expiresAt: Date
    let bookmark: Data
}
struct CodexContextHandoffReply: Codable, Sendable {
    let transfer: CodexContextTransfer?
    let failure: CodexExecutionContextAccessFailure?
}

@objc(ReleaseRadarCodexContextXPC)
protocol ReleaseRadarCodexContextXPC {
    func acquire(_ projectID: String, assignmentID: String, contextID: String, attemptID: String,
                 withReply reply: @escaping (Data) -> Void)
    func validate(_ grantID: String, attemptID: String, withReply reply: @escaping (Data) -> Void)
    func confirmedClosed(_ grantID: String, attemptID: String, withReply reply: @escaping (Data) -> Void)
}

// Shared only by RR's native App Server transport and its separately signed
// Coordinator. This interface is not an MCP capability or persistent receipt.
protocol ExecutionContextLease: Sendable {
    var homePath: String { get }
    func validate() throws
    func physicallyClosed() throws
    func onInvalidation(_ handler: @escaping @Sendable () -> Void)
}
extension CodexExecutionContextLease: ExecutionContextLease {
    var homePath: String { context.homePath }
    func physicallyClosed() throws { release() }
    func onInvalidation(_ handler: @escaping @Sendable () -> Void) { }
}

private final class ContextReply<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private let signal = DispatchSemaphore(value: 0)
    private var result: Result<Value, Error>?
    func finish(_ value: Result<Value, Error>) {
        lock.withLock { if result == nil { result = value; signal.signal() } }
    }
    func wait() throws -> Value {
        guard signal.wait(timeout: .now() + 5) == .success else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        return try lock.withLock { try result!.get() }
    }
}

final class CodexContextHandoffClient: @unchecked Sendable {
    private let connection: NSXPCConnection
    private let lock = NSLock()
    private var available = true
    private var invalidated: (@Sendable () -> Void)?

    static func discover() throws -> NSXPCListenerEndpoint {
        guard let requirement = ReleaseRadarBridgeTransport.brokerRequirement else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        let connection = NSXPCConnection(machServiceName: ReleaseRadarBridgeTransport.appMachService, options: [])
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarContextDiscoveryXPC.self)
        connection.resume(); defer { connection.invalidate() }
        let gate = ContextReply<NSXPCListenerEndpoint>()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            gate.finish(.failure(CodexExecutionContextAccessFailure(stage: .handoff, error: error)))
        }) as? ReleaseRadarContextDiscoveryXPC else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        proxy.contextEndpoint(ReleaseRadarBridgeTransport.wireVersion) { endpoint in
            if let endpoint { gate.finish(.success(endpoint)) }
            else { gate.finish(.failure(CodexExecutionContextAccessFailure(stage: .handoff))) }
        }
        return try gate.wait()
    }
    init(endpoint: NSXPCListenerEndpoint) throws {
        guard let requirement = ReleaseRadarBridgeTransport.appRequirement else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarCodexContextXPC.self)
        connection.invalidationHandler = { [weak self] in self?.lost() }
        connection.interruptionHandler = { [weak self] in self?.lost() }
        connection.resume()
    }
    private func lost() {
        let handler = lock.withLock { available = false; return invalidated }
        handler?()
    }
    func onInvalidation(_ handler: @escaping @Sendable () -> Void) {
        let alreadyLost = lock.withLock { invalidated = handler; return !available }
        if alreadyLost { handler() }
    }
    private func request(_ operation: (ReleaseRadarCodexContextXPC, @escaping (Data) -> Void) -> Void) throws -> CodexContextHandoffReply {
        guard lock.withLock({ available }) else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        let gate = ContextReply<Data>()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            gate.finish(.failure(CodexExecutionContextAccessFailure(stage: .handoff, error: error)))
        }) as? ReleaseRadarCodexContextXPC else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        operation(proxy) { gate.finish(.success($0)) }
        let data = try gate.wait()
        guard data.count <= 512_000, let result = try? JSONDecoder().decode(CodexContextHandoffReply.self, from: data) else {
            throw CodexExecutionContextAccessFailure(stage: .handoff)
        }
        if let failure = result.failure { throw failure }
        return result
    }
    func acquire(projectID: String, assignmentID: String, contextID: UUID, attemptID: UUID) throws -> CodexContextTransfer {
        let reply = try request { $0.acquire(projectID, assignmentID: assignmentID,
            contextID: contextID.uuidString, attemptID: attemptID.uuidString, withReply: $1) }
        guard let transfer = reply.transfer, transfer.contextID == contextID, transfer.attemptID == attemptID,
              transfer.expiresAt > Date(), transfer.expiresAt.timeIntervalSinceNow <= 15,
              !transfer.bookmark.isEmpty, transfer.bookmark.count <= 256_000 else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        return transfer
    }
    func validate(_ transfer: CodexContextTransfer) throws {
        _ = try request { $0.validate(transfer.id.uuidString, attemptID: transfer.attemptID.uuidString, withReply: $1) }
    }
    func physicallyClosed(_ transfer: CodexContextTransfer) throws {
        _ = try request { $0.confirmedClosed(transfer.id.uuidString, attemptID: transfer.attemptID.uuidString, withReply: $1) }
        lock.withLock { invalidated = nil; available = false }
        connection.invalidate()
    }
    deinit { connection.invalidate() }
}

/// Deferred ephemeral scope acquisition has explicit, balanced ownership. There
/// is no false-start fallback based on the helper being unsandboxed.
final class CoordinatorCodexContextLease: ExecutionContextLease, @unchecked Sendable {
    private let context: CodexExecutionContext
    private let current: @Sendable () throws -> CodexExecutionContext?
    private let client: CodexContextHandoffClient
    private let transfer: CodexContextTransfer
    private let resolved: NSURL
    private let lock = NSLock()
    private var active = true
    var homePath: String { context.homePath }

    init(context: CodexExecutionContext, current: @escaping @Sendable () throws -> CodexExecutionContext?,
         client: CodexContextHandoffClient, transfer: CodexContextTransfer) throws {
        guard transfer.contextID == context.id, transfer.expiresAt > Date() else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
        var stale = ObjCBool(false)
        let url: NSURL
        do {
            url = try NSURL(resolvingBookmarkData: transfer.bookmark,
                options: [.withoutImplicitStartAccessing, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        } catch { throw CodexExecutionContextAccessFailure(stage: .resolve, error: error) }
        guard !stale.boolValue else { throw CodexExecutionContextAccessFailure(stage: .stale) }
        guard url.startAccessingSecurityScopedResource() else { throw CodexExecutionContextAccessFailure(stage: .start) }
        do {
            guard let path = url.path, try CodexExecutionContext.canonicalPath(path) == context.homePath,
                  try current() == context else { throw CodexExecutionContextAccessFailure(stage: .identity) }
            try context.validateFolder()
        } catch { url.stopAccessingSecurityScopedResource(); throw CodexExecutionContextAccessFailure(stage: .identity) }
        self.context = context; self.current = current; self.client = client; self.transfer = transfer; resolved = url
    }
    static func acquire(store: ProjectExecutionFileStore, projectID: String, assignmentID: String,
                        contextID: UUID, attemptID: UUID, endpoint: NSXPCListenerEndpoint? = nil) throws -> CoordinatorCodexContextLease {
        guard let context = try store.codexContext(), context.id == contextID else { throw CodexExecutionContextAccessFailure(stage: .identity) }
        let client = try CodexContextHandoffClient(endpoint: endpoint ?? CodexContextHandoffClient.discover())
        let transfer = try client.acquire(projectID: projectID, assignmentID: assignmentID, contextID: contextID, attemptID: attemptID)
        do { return try .init(context: context, current: { try store.codexContext() }, client: client, transfer: transfer) }
        catch {
            // No child exists yet. Cleanup is grant-bound and does not clear the
            // protected assignment. If acknowledgement fails, RR retains it.
            do { try client.physicallyClosed(transfer) }
            catch { throw CodexExecutionContextAccessFailure(stage: .handoff) }
            throw error
        }
    }
    func validate() throws {
        try lock.withLock {
            do {
                guard active, try current() == context else { throw CodexExecutionContextAccessFailure(stage: .identity) }
                try context.validateFolder()
            } catch { throw CodexExecutionContextAccessFailure(stage: .identity) }
            try client.validate(transfer)
        }
    }
    func onInvalidation(_ handler: @escaping @Sendable () -> Void) { client.onInvalidation(handler) }
    func physicallyClosed() throws {
        lock.withLock { if active { resolved.stopAccessingSecurityScopedResource(); active = false } }
        try client.physicallyClosed(transfer)
    }
    // Losing this object is not evidence that an existing child closed. The
    // App Server transport retains it until its process and reader exit.
}
