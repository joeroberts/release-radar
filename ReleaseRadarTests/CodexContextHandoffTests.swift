import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class CodexContextHandoffTests: XCTestCase {
    final class Scope: @unchecked Sendable {
        private let lock = NSLock()
        private var stops = 0
        var count: Int { lock.withLock { stops } }
        func stop(_ url: URL) { lock.withLock { stops += 1 } }
    }
    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Date()
        func now() -> Date { lock.withLock { value } }
        func advance() { lock.withLock { value += 60 } }
    }
    static func fixture(root: URL, realBookmark: Bool = false,
                        tasks: [String] = ["first"]) throws -> (ProjectExecutionFileStore, CodexExecutionContext) {
        let home = root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Data("synthetic-context-marker".utf8).write(to: home.appendingPathComponent("marker.txt"))
        let bookmark = realBookmark ? try ProjectBookmarkStore().makeBookmark(for: home) : Data([1])
        let context = try CodexExecutionContext(home: home, bookmark: bookmark)
        let store = try ProjectExecutionFileStore(root: root.appendingPathComponent("Execution"), create: true)
        try store.saveCodexContext(context, expected: nil)
        let registration = ProjectRegistration(projectID: .init(rawValue: "handoff-fixture"), registrationID: "synthetic-registration", requestGeneration: 1)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: root.path,
            appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator")
        policy.consent = .init(); policy.codexContextID = context.id
        policy.hookReceipt = .init(command: "synthetic-owned-hook", inline: false, beforeDigest: nil,
            intendedDigest: String(repeating: "a", count: 64), installed: true)
        try store.savePolicy(policy, expected: nil)
        for task in tasks {
            let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: "handoff-fixture", taskID: task)
            try FileManager.default.createDirectory(at: paths.checkout, withIntermediateDirectories: true)
            let instructions = Data("Synthetic applicable instructions".utf8)
            try instructions.write(to: paths.checkout.appendingPathComponent("AGENTS.md"))
            var assignment = ProjectExecutionAssignment(id: task, registration: registration,
                checkoutPath: paths.checkout.path, role: .delivery, permissionProfile: "rr-synthetic",
                model: "gpt-5.6-sol", effort: "high", authorization: "Synthetic context handoff verification",
                context: [.init(path: "AGENTS.md", digest: SHA256.hash(data: instructions).map { String(format: "%02x", $0) }.joined())],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"])
            assignment.codexContextID = context.id
            try store.saveAssignment(assignment, expected: nil)
        }
        return (store, context)
    }
    private func fixture() throws -> (ProjectExecutionFileStore, CodexExecutionContext, Scope, Clock, CodexContextHandoffAuthority) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let (store, context) = try Self.fixture(root: root)
        let scope = Scope(); let clock = Clock()
        let authority = CodexContextHandoffAuthority(store: { store }, now: clock.now,
            lease: { context, current in
                try CodexExecutionContextLease(context: context, current: current,
                    resolve: { _ in .init(url: URL(fileURLWithPath: context.homePath), isStale: false) },
                    start: { _ in true }, stop: scope.stop)
            })
        return (store, context, scope, clock, authority)
    }
    func testFreshHandoffBindsReceiptConnectionAndAttemptAndExpiresOnlyAdmission() throws {
        let (store, context, scope, clock, authority) = try fixture()
        let connection = UUID(); let attempt = UUID()
        let grant = try authority.acquire(connection: connection, projectID: "handoff-fixture", assignmentID: "first", contextID: context.id, attemptID: attempt)
        XCTAssertThrowsError(try authority.acquire(connection: UUID(), projectID: "handoff-fixture", assignmentID: "first", contextID: context.id, attemptID: UUID()))
        XCTAssertThrowsError(try authority.validate(connection: UUID(), grantID: grant.id, attemptID: attempt))
        XCTAssertThrowsError(try authority.validate(connection: connection, grantID: grant.id, attemptID: UUID()))
        XCTAssertThrowsError(try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt), "Consumption requires the exact reserved snapshot")
        let policy = try WorkerPolicy(store: store, projectID: "handoff-fixture", taskID: "first")
        try policy.reserve()
        try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt)
        clock.advance()
        try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt)
        XCTAssertEqual(scope.count, 0, "Admission expiry must not release an active grant")
        try policy.bind(sessionID: "synthetic-session")
        try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt)
        let before = try store.assignment(projectID: "handoff-fixture", taskID: "first")
        try authority.confirmedClosed(connection: connection, grantID: grant.id, attemptID: attempt)
        XCTAssertEqual(scope.count, 1)
        XCTAssertEqual(try store.assignment(projectID: "handoff-fixture", taskID: "first"), before)
    }
    func testPreTransportAccessFailureReportsOnlySanitizedStageAndPreservesReservation() async throws {
        let (store, _, _, _, _) = try fixture()
        let foundation = NSError(domain: NSCocoaErrorDomain, code: 256,
            userInfo: [NSLocalizedDescriptionKey: "synthetic-private-bookmark-auth"])
        let adapter = WorkerAdapter(store: store, serverFactory: { _, _, _ in
            throw CodexExecutionContextAccessFailure(stage: .resolve, error: foundation)
        })
        let result = try await adapter.start(projectID: "handoff-fixture", assignmentID: "first", prompt: "Synthetic start").object()
        XCTAssertEqual(result["transportReached"] as? Bool, false)
        let diagnostic = try XCTUnwrap(result["accessFailure"] as? [String: Any])
        XCTAssertEqual(diagnostic["stage"] as? String, "resolve")
        XCTAssertEqual(diagnostic["domain"] as? String, NSCocoaErrorDomain)
        XCTAssertEqual(diagnostic["code"] as? Int, 256)
        XCTAssertEqual(Set(diagnostic.keys), ["stage", "domain", "code"])
        let encoded = String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        XCTAssertFalse(encoded.contains("synthetic-private"))
        let reserved = try store.assignment(projectID: "handoff-fixture", taskID: "first")
        XCTAssertEqual(reserved.state, .unknown); XCTAssertEqual(reserved.launchReserved, true)
        XCTAssertEqual(reserved.uncertainOutcome, true); XCTAssertNil(reserved.sessionID)
        _ = try await adapter.close(workerID: try XCTUnwrap(result["workerId"] as? String))
        var expected = reserved; expected.connectionClosed = true
        XCTAssertEqual(try store.assignment(projectID: "handoff-fixture", taskID: "first"), expected)
    }
    func testExpiredRestartedOrUncertainLaunchNeverGetsAnotherGrant() throws {
        let (store, context, scope, clock, authority) = try fixture()
        let connection = UUID(); let attempt = UUID()
        let grant = try authority.acquire(connection: connection, projectID: "handoff-fixture", assignmentID: "first", contextID: context.id, attemptID: attempt)
        let policy = try WorkerPolicy(store: store, projectID: "handoff-fixture", taskID: "first")
        try policy.reserve(); clock.advance()
        XCTAssertThrowsError(try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt))
        let reserved = try store.assignment(projectID: "handoff-fixture", taskID: "first")
        let restarted = CodexContextHandoffAuthority(store: { store })
        XCTAssertThrowsError(try restarted.acquire(connection: UUID(), projectID: "handoff-fixture", assignmentID: "first", contextID: context.id, attemptID: UUID()))
        XCTAssertEqual(try store.assignment(projectID: "handoff-fixture", taskID: "first"), reserved)
        XCTAssertEqual(scope.count, 0)
        try authority.confirmedClosed(connection: connection, grantID: grant.id, attemptID: attempt)
        XCTAssertEqual(scope.count, 1)
        XCTAssertEqual(try store.assignment(projectID: "handoff-fixture", taskID: "first"), reserved)
    }
    func testChangedReceiptOrConnectionLossPreservesGrantUntilExactPhysicalClosure() throws {
        let (store, context, scope, _, authority) = try fixture()
        let connection = UUID(); let attempt = UUID()
        XCTAssertThrowsError(try authority.acquire(connection: connection, projectID: "handoff-fixture", assignmentID: "first", contextID: UUID(), attemptID: attempt))
        let grant = try authority.acquire(connection: connection, projectID: "handoff-fixture", assignmentID: "first", contextID: context.id, attemptID: attempt)
        try WorkerPolicy(store: store, projectID: "handoff-fixture", taskID: "first").reserve()
        try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt)
        let recovered = try CodexExecutionContext(home: URL(fileURLWithPath: context.homePath), bookmark: Data([2]), id: context.id)
        try store.saveCodexContext(recovered, expected: context)
        XCTAssertThrowsError(try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt))
        XCTAssertEqual(scope.count, 0)
        XCTAssertThrowsError(try authority.confirmedClosed(connection: UUID(), grantID: grant.id, attemptID: attempt))
        try authority.confirmedClosed(connection: connection, grantID: grant.id, attemptID: attempt)
        XCTAssertEqual(scope.count, 1, "Close stays available after validation fails")
        // A lost connection's bare replacement closure is never accepted.
        let (otherStore, otherContext, otherScope, _, other) = try fixture()
        let lost = UUID(); let lostAttempt = UUID()
        let lostGrant = try other.acquire(connection: lost, projectID: "handoff-fixture", assignmentID: "first", contextID: otherContext.id, attemptID: lostAttempt)
        try WorkerPolicy(store: otherStore, projectID: "handoff-fixture", taskID: "first").reserve()
        other.connectionLost(lost)
        XCTAssertThrowsError(try other.validate(connection: lost, grantID: lostGrant.id, attemptID: lostAttempt))
        XCTAssertThrowsError(try other.confirmedClosed(connection: UUID(), grantID: lostGrant.id, attemptID: lostAttempt))
        XCTAssertEqual(otherScope.count, 0)
        XCTAssertEqual(other.activeGrantCount, 1)
    }

    func testLostWorkerRecoveryReleasesOnlyExactBoundGrantAndReplaySeesNoGrant() throws {
        let (store, context, scope, _, authority) = try fixture()
        let connection = UUID(); let attempt = UUID()
        let grant = try authority.acquire(connection: connection, projectID: "handoff-fixture",
            assignmentID: "first", contextID: context.id, attemptID: attempt)
        let policy = try WorkerPolicy(store: store, projectID: "handoff-fixture", taskID: "first")
        try policy.reserve()
        try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt)
        try policy.bind(sessionID: "lost-session")
        try authority.validate(connection: connection, grantID: grant.id, attemptID: attempt)
        authority.connectionLost(connection)

        XCTAssertThrowsError(try authority.reconcileLostWorkerGrant(projectID: "handoff-fixture",
            assignmentID: "first", sessionID: "another-session"))
        XCTAssertEqual(scope.count, 0)
        XCTAssertEqual(authority.activeGrantCount, 1)

        XCTAssertEqual(try authority.reconcileLostWorkerGrant(projectID: "handoff-fixture",
            assignmentID: "first", sessionID: "lost-session"), .matchingGrantReleased)
        XCTAssertEqual(scope.count, 1)
        XCTAssertEqual(authority.activeGrantCount, 0)
        XCTAssertEqual(try authority.reconcileLostWorkerGrant(projectID: "handoff-fixture",
            assignmentID: "first", sessionID: "lost-session"), .noMatchingGrant)
        XCTAssertEqual(scope.count, 1, "Replay must not release a second scope or invent a prior write")
    }
}
