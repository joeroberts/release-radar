import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class WorkerAdapterTests: XCTestCase {
    final class Peer: ExecutionPeer, @unchecked Sendable {
        let policy: WorkerPolicy
        var calls: [(String, RPCObject)] = []
        var sent: [RPCObject] = []
        var lostStart = false
        var broadWrite = false
        var broadRead = false
        var completesImmediately = false
        var closeFailure = false
        init(policy: WorkerPolicy) { self.policy = policy }
        func send(_ object: [String: Any]) throws { sent.append(try RPCObject(object)) }
        func close() throws {
            if closeFailure { throw AppServerTransportError(message: "Fixture residual process", outcomeUnknown: true) }
        }
        func call(_ method: String, _ parameters: RPCObject) async throws -> RPCObject {
            calls.append((method, parameters))
            let selected = policy.assignment
            if method == "config/read" {
                let paths = try ProjectExecutionPaths(storageRoot: policy.store.root, projectID: selected.registration.projectID.rawValue, taskID: selected.id)
                var fs = try ProjectExecutionPermissionProfile(assignment: selected, policy: policy.policy, paths: paths).filesystemObject
                if broadWrite { fs[policy.store.root.path] = "write" }
                if broadRead { fs["/Users"] = "read" }
                return try RPCObject(["config": ["permissions": [selected.permissionProfile: ["filesystem": fs, "network": ["enabled": false]]]]])
            }
            if method == "thread/start" {
                if lostStart { throw AppServerTransportError(message: "Unknown start", outcomeUnknown: true) }
                return try RPCObject(["thread": ["id": "session-one"], "cwd": selected.checkoutPath,
                    "runtimeWorkspaceRoots": [selected.checkoutPath], "model": selected.model, "reasoningEffort": selected.effort,
                    "activePermissionProfile": ["id": selected.permissionProfile], "sandbox": ["networkAccess": false],
                    "approvalPolicy": "on-request", "instructionSources": [selected.checkoutPath + "/AGENTS.md"]])
            }
            if method == "mcpServerStatus/list" { return try RPCObject(["data": []]) }
            if method == "hooks/list" {
                return try RPCObject(["data": [["cwd": selected.checkoutPath, "errors": [], "warnings": [], "hooks": [["command": "\"" + policy.policy.handlerPath + "\" --hook", "handlerType": "command", "source": "project", "sourcePath": "/Primary/.codex/hooks.json", "eventName": "userPromptSubmit", "enabled": true, "timeoutSec": 10, "trustStatus": "trusted", "key": "owned-key", "currentHash": "owned-hash"]]]]])
            }
            if method == "turn/start" { return try RPCObject(["turn": ["id": "turn-one", "status": completesImmediately ? "completed" : "inProgress"]]) }
            return try RPCObject([:])
        }
    }
    private func fixture() throws -> (store: ProjectExecutionFileStore, policy: WorkerPolicy) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: "task-one")
        try FileManager.default.createDirectory(at: paths.checkout, withIntermediateDirectories: true)
        let context = Data("Current applicable instructions".utf8)
        try context.write(to: paths.checkout.appendingPathComponent("AGENTS.md"))
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let handler = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator"
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Primary", appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handler)
        policy.consent = .init(); policy.hookReceipt = .init(command: "\"" + handler + "\" --hook", inline: false, beforeDigest: nil, intendedDigest: String(repeating: "a", count: 64), installed: true)
        try store.savePolicy(policy, expected: nil)
        let assignment = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .delivery,
            permissionProfile: "rr-worker", model: "gpt-5.6-sol", effort: "high", authorization: "Implement the approved slice",
            context: [.init(path: "AGENTS.md", digest: SHA256.hash(data: context).map { String(format: "%02x", $0) }.joined())],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            worktree: .init(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40), branch: "codex/rr-project-one-task-one", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary"))
        try store.saveAssignment(assignment, expected: nil)
        return (store, try WorkerPolicy(store: store, projectID: "project-one", taskID: "task-one"))
    }
    func testVerifiedDelegationCarriesAuthorizationOnceAndPreservesRuntimeApproval() async throws {
        let fixture = try fixture(); let peer = Peer(policy: fixture.policy)
        let adapter = WorkerAdapter(store: fixture.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin the approved work").object()
        XCTAssertEqual(started["status"] as? String, "inProgress")
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/start" }.count, 1)
        let turn = try XCTUnwrap(peer.calls.first { $0.0 == "turn/start" }).1.object()
        let input = try XCTUnwrap((turn["input"] as? [[String: Any]])?.first?["text"] as? String)
        XCTAssertTrue(input.contains("Implement the approved slice")); XCTAssertTrue(input.contains("Runtime approval"))
        XCTAssertFalse(peer.calls.contains { $0.0 == "config/batchWrite" })
        XCTAssertTrue(peer.sent.isEmpty || peer.sent.allSatisfy { (try? $0.object()["result"]) == nil })
        let bound = try fixture.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(bound.sessionID, "session-one")
    }
    func testUncertainStartPersistsUnknownAndNewConnectionCannotRedispatch() async throws {
        let fixture = try fixture(); let peer = Peer(policy: fixture.policy); peer.lostStart = true
        let adapter = WorkerAdapter(store: fixture.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "unknown")
        XCTAssertEqual(try fixture.store.assignment(projectID: "project-one", taskID: "task-one").state, .unknown)
        let replacement = WorkerAdapter(store: fixture.store, serverFactory: { _, _, _ in peer })
        do { _ = try await replacement.start(projectID: "project-one", assignmentID: "task-one", prompt: "Try again"); XCTFail("Unknown must not redispatch") } catch {}
        XCTAssertEqual(peer.calls.filter { $0.0 == "thread/start" }.count, 1)
        XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" })
    }
    func testBroadWriteProfileCannotReachFirstTurn() async throws {
        let fixture = try fixture(); let peer = Peer(policy: fixture.policy); peer.broadWrite = true
        let adapter = WorkerAdapter(store: fixture.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "failed")
        XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" })
    }
    func testCleanupFailureRetainsUnknownWorkerAndDoesNotClaimClosed() async throws {
        let fixture = try fixture(); let peer = Peer(policy: fixture.policy)
        peer.completesImmediately = true; peer.closeFailure = true
        let adapter = WorkerAdapter(store: fixture.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        XCTAssertEqual(started["status"] as? String, "completed")
        do { _ = try await adapter.close(workerID: id); XCTFail("Residual process must not claim closed") } catch {}
        let remaining = try await adapter.status(workerID: id).object()
        XCTAssertEqual(remaining["status"] as? String, "unknown")
        XCTAssertTrue((remaining["error"] as? String)?.contains("residual process") == true)
        XCTAssertEqual(try fixture.store.assignment(projectID: "project-one", taskID: "task-one").state, .unknown)
    }
    func testBroadReadCannotReachFirstTurnAndSuccessfulCloseRecordsStoppedWriter() async throws {
        let denied = try fixture(); let broad = Peer(policy: denied.policy); broad.broadRead = true
        let refused = WorkerAdapter(store: denied.store, serverFactory: { _, _, _ in broad })
        let result = try await refused.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(result["status"] as? String, "failed")
        XCTAssertFalse(broad.calls.contains { $0.0 == "turn/start" })
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.completesImmediately = true
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
        XCTAssertEqual(try valid.store.assignment(projectID: "project-one", taskID: "task-one").state, .closed)
    }
    func testStopRevokesFollowupAdmissionBeforeInterruptAcknowledgement() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy)
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        _ = try await adapter.interrupt(workerID: id)
        XCTAssertEqual(try valid.store.assignment(projectID: "project-one", taskID: "task-one").state, .stopped)
        do { _ = try await adapter.followUp(workerID: id, prompt: "Continue"); XCTFail("STOP must prevent continuation") } catch {}
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/start" }.count, 1)
    }

    func testConnectionLossPersistsUnknownAndLateCompletionCannotCloseCandidate() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy)
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        await adapter.event(id, try RPCObject(["method": "adapter/connectionLost"]))
        await adapter.event(id, try RPCObject(["method": "turn/completed", "params": ["threadId": "session-one", "turn": ["id": "turn-one", "status": "completed"]]]))
        let status = try await adapter.status(workerID: id).object()
        XCTAssertEqual(status["status"] as? String, "unknown")
        XCTAssertEqual(try valid.store.assignment(projectID: "project-one", taskID: "task-one").state, .unknown)
        do { _ = try await adapter.close(workerID: id); XCTFail("Unknown process cannot become a closed review candidate") } catch {}
    }
}
