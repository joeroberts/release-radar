import Darwin
import Foundation
import ReleaseRadarCore

/// RR owns durable scope restoration. Caller IDs correlate a request; only the
/// protected current selection/policy/assignment supply its authority.
final class CodexContextHandoffAuthority: @unchecked Sendable {
    private struct Grant {
        let transfer: CodexContextTransfer
        let connection: UUID
        let attempt: UUID
        let assignment: ProjectExecutionAssignment
        let policy: ProjectExecutionPolicy
        let lease: CodexExecutionContextLease
        var consumed = false
        var available = true
        var boundSession: String?
    }
    private let lock = NSLock()
    private let store: @Sendable () throws -> ProjectExecutionFileStore
    private let now: @Sendable () -> Date
    private let interval: TimeInterval
    private let lease: @Sendable (CodexExecutionContext, @escaping @Sendable () throws -> CodexExecutionContext?) throws -> CodexExecutionContextLease
    private var grants: [UUID: Grant] = [:]

    init(store: @escaping @Sendable () throws -> ProjectExecutionFileStore,
         now: @escaping @Sendable () -> Date = { Date() }, admissionInterval: TimeInterval = 15,
         lease: @escaping @Sendable (CodexExecutionContext, @escaping @Sendable () throws -> CodexExecutionContext?) throws -> CodexExecutionContextLease = {
             try CodexExecutionContextLease(context: $0, current: $1)
         }) {
        self.store = store; self.now = now; interval = admissionInterval; self.lease = lease
    }
    var activeGrantCount: Int { lock.withLock { grants.count } }

    func acquire(connection: UUID, projectID: String, assignmentID: String,
                 contextID: UUID, attemptID: UUID) throws -> CodexContextTransfer {
        try lock.withLock {
            let store = try store()
            let policy = try store.policy(projectID: projectID)
            let assignment = try store.assignment(projectID: projectID, taskID: assignmentID)
            guard let context = try store.codexContext(), context.id == contextID,
                  policy.codexContextID == contextID, assignment.codexContextID == contextID,
                  policy.version == 1, policy.enabled, policy.bindingRecoveryPending != true,
                  policy.consent == .init(), policy.hookReceipt?.installed == true,
                  policy.appServerExecutable == CodexExecutionIdentity.executable,
                  policy.registration == assignment.registration,
                  assignment.registration.projectID.rawValue == projectID, assignment.id == assignmentID,
                  assignment.state == .authorized, assignment.sessionID == nil,
                  assignment.launchReserved != true, assignment.uncertainOutcome != true,
                  assignment.connectionClosed != true,
                  !grants.values.contains(where: { $0.assignment.registration == assignment.registration && $0.assignment.id == assignmentID })
            else { throw CodexExecutionContextAccessFailure(stage: .identity) }
            let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: projectID, taskID: assignmentID)
            guard assignment.checkoutPath == paths.checkout.path,
                  paths.checkout.resolvingSymlinksInPath().path == paths.checkout.path else {
                throw CodexExecutionContextAccessFailure(stage: .identity)
            }
            try assignment.verifyContext()
            let retained = try lease(context, { try store.codexContext() })
            do {
                let bookmark = try retained.makeTemporaryTransferBookmark()
                guard !bookmark.isEmpty, bookmark.count <= 256_000 else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
                // Re-read after restoration/creation; no stale protected snapshot
                // may authorize a transfer while owner revocation races it.
                guard try store.policy(projectID: projectID) == policy,
                      try store.assignment(projectID: projectID, taskID: assignmentID) == assignment else {
                    throw CodexExecutionContextAccessFailure(stage: .identity)
                }
                try retained.validate()
                let transfer = CodexContextTransfer(id: UUID(), contextID: contextID, attemptID: attemptID,
                    expiresAt: now().addingTimeInterval(interval), bookmark: bookmark)
                grants[transfer.id] = Grant(transfer: transfer, connection: connection,
                    attempt: attemptID, assignment: assignment, policy: policy, lease: retained)
                return transfer
            } catch { retained.release(); throw error }
        }
    }

    func validate(connection: UUID, grantID: UUID, attemptID: UUID) throws {
        try lock.withLock {
            guard var grant = grants[grantID], grant.connection == connection, grant.attempt == attemptID,
                  grant.available, grant.consumed || now() < grant.transfer.expiresAt else {
                throw CodexExecutionContextAccessFailure(stage: .handoff)
            }
            try grant.lease.validate()
            let store = try store()
            let project = grant.assignment.registration.projectID.rawValue
            guard try store.policy(projectID: project) == grant.policy else { throw CodexExecutionContextAccessFailure(stage: .identity) }
            let current = try store.assignment(projectID: project, taskID: grant.assignment.id)
            var reserved = grant.assignment
            reserved.state = .unknown; reserved.launchReserved = true; reserved.uncertainOutcome = true
            if current != reserved {
                guard grant.consumed, let session = current.sessionID,
                      grant.boundSession == nil || grant.boundSession == session else {
                    throw CodexExecutionContextAccessFailure(stage: .identity)
                }
                var bound = grant.assignment; bound.sessionID = session; bound.launchReserved = true
                guard current == bound else { throw CodexExecutionContextAccessFailure(stage: .identity) }
                grant.boundSession = session
            }
            try current.verifyContext()
            grant.consumed = true; grants[grantID] = grant
        }
    }

    func confirmedClosed(connection: UUID, grantID: UUID, attemptID: UUID) throws {
        try lock.withLock {
            guard let grant = grants[grantID], grant.connection == connection, grant.attempt == attemptID,
                  grant.available else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
            // Receipt/authorization loss cannot prevent physical cleanup. This
            // acknowledgement never edits reservation or uncertainty records.
            grant.lease.release(); grants.removeValue(forKey: grantID)
        }
    }
    func connectionLost(_ connection: UUID) {
        lock.withLock {
            for id in grants.keys where grants[id]?.connection == connection { grants[id]?.available = false }
        }
        // Keep unresolved leases owned by this process. No timeout, replacement
        // connection or absent session establishes physical child closure.
    }
}

final class CodexContextHandoffHost: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    // Retain unresolved production leases even if the command bridge disconnects.
    // Process termination ends in-memory scopes; protected reservations remain.
    static let production = CodexContextHandoffHost(authority: CodexContextHandoffAuthority(store: {
        try ProjectExecutionFileStore(root: ProjectExecutionFileStore.applicationRoot(), create: false)
    }))
    let authority: CodexContextHandoffAuthority
    private let listener = NSXPCListener.anonymous()
    private let lock = NSLock()
    private var started = false
    init(authority: CodexContextHandoffAuthority) { self.authority = authority; super.init() }
    func endpoint() throws -> NSXPCListenerEndpoint {
        try lock.withLock {
            guard let requirement = ReleaseRadarBridgeTransport.coordinatorRequirement else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
            if !started {
                // Foundation rejects mismatched code BEFORE delegate admission.
                listener.setConnectionCodeSigningRequirement(requirement)
                listener.delegate = self; listener.resume(); started = true
            }
            return listener.endpoint
        }
    }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == getuid(),
              let requirement = ReleaseRadarBridgeTransport.coordinatorRequirement else { return false }
        let id = UUID()
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarCodexContextXPC.self)
        connection.exportedObject = CodexContextHandoffEndpoint(authority: authority, connection: id)
        connection.invalidationHandler = { [authority] in authority.connectionLost(id) }
        connection.interruptionHandler = { [authority] in authority.connectionLost(id) }
        connection.resume(); return true
    }
}

private final class CodexContextHandoffEndpoint: NSObject, ReleaseRadarCodexContextXPC, @unchecked Sendable {
    private let authority: CodexContextHandoffAuthority
    private let connection: UUID
    init(authority: CodexContextHandoffAuthority, connection: UUID) { self.authority = authority; self.connection = connection }
    private func respond(_ reply: (Data) -> Void, _ body: () throws -> CodexContextTransfer?) {
        let result: CodexContextHandoffReply
        do { result = .init(transfer: try body(), failure: nil) }
        catch { result = .init(transfer: nil, failure: (error as? CodexExecutionContextAccessFailure) ?? .init(stage: .identity)) }
        reply((try? JSONEncoder().encode(result)) ?? Data())
    }
    func acquire(_ projectID: String, assignmentID: String, contextID: String, attemptID: String,
                 withReply reply: @escaping (Data) -> Void) {
        respond(reply) {
            guard let context = UUID(uuidString: contextID), let attempt = UUID(uuidString: attemptID) else {
                throw CodexExecutionContextAccessFailure(stage: .identity)
            }
            return try authority.acquire(connection: connection, projectID: projectID, assignmentID: assignmentID, contextID: context, attemptID: attempt)
        }
    }
    func validate(_ grantID: String, attemptID: String, withReply reply: @escaping (Data) -> Void) {
        respond(reply) {
            guard let grant = UUID(uuidString: grantID), let attempt = UUID(uuidString: attemptID) else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
            try authority.validate(connection: connection, grantID: grant, attemptID: attempt); return nil
        }
    }
    func confirmedClosed(_ grantID: String, attemptID: String, withReply reply: @escaping (Data) -> Void) {
        respond(reply) {
            guard let grant = UUID(uuidString: grantID), let attempt = UUID(uuidString: attemptID) else { throw CodexExecutionContextAccessFailure(stage: .handoff) }
            try authority.confirmedClosed(connection: connection, grantID: grant, attemptID: attempt); return nil
        }
    }
}
