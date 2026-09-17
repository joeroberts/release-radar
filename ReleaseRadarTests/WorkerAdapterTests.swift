import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class WorkerAdapterTests: XCTestCase {
    final class StoreProbe: @unchecked Sendable {
        let root: URL
        private let lock = NSLock()
        private var attempts = 0
        init(root: URL) { self.root = root }
        var count: Int { lock.withLock { attempts } }
        func adapter() throws -> WorkerAdapter {
            lock.withLock { attempts += 1 }
            return WorkerAdapter(store: try ProjectExecutionFileStore(root: root, create: false),
                serverFactory: { _, _, _ in
                    XCTFail("An unavailable execution store must not launch a worker.")
                    throw ProjectExecutionError.unavailable
                })
        }
    }

    func testMCPDiscoveryWithoutExecutionStoreDoesNotProvisionOrAuthorizeWork() async throws {
        let parent = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let invalid = parent.appendingPathComponent("invalid-store")
        try Data("not a directory".utf8).write(to: invalid)
        let missing = parent.appendingPathComponent("missing-store")
        let calls: [(String, [String: String])] = [
            ("worker_start", ["projectId": "project-one", "assignmentId": "task-one", "prompt": "Begin"]),
            ("worker_status", ["workerId": "unknown"]),
            ("worker_follow_up", ["workerId": "unknown", "prompt": "Continue"]),
            ("worker_interrupt", ["workerId": "unknown"]),
            ("worker_respond", ["workerId": "unknown", "requestKey": "unknown", "decision": "accept"]),
            ("worker_close", ["workerId": "unknown"]),
        ]
        for root in [missing, invalid] {
            let probe = StoreProbe(root: root)
            let service = CoordinatorMCP(adapterFactory: { try probe.adapter() })
            let initialized = try await service.dispatch(RPCObject(["method": "initialize"])).object()
            XCTAssertEqual((initialized["serverInfo"] as? [String: String])?["name"], "release_radar_coordinator")
            let listed = try await service.dispatch(RPCObject(["method": "tools/list"])).object()
            let names = try XCTUnwrap(listed["tools"] as? [[String: Any]]).compactMap { $0["name"] as? String }
            XCTAssertEqual(Set(names), Set(calls.map { $0.0 }))
            XCTAssertEqual(probe.count, 0, "Discovery must not resolve or open execution storage.")
            for (name, arguments) in calls {
                do {
                    _ = try await service.dispatch(RPCObject([
                        "method": "tools/call", "params": ["name": name, "arguments": arguments],
                    ]))
                    XCTFail("Unavailable execution storage must fail closed for \(name).")
                } catch {
                    XCTAssertEqual(error as? ProjectExecutionError, .unavailable)
                }
            }
            XCTAssertEqual(probe.count, calls.count)
            _ = try await service.dispatch(RPCObject(["method": "initialize"]))
            _ = try await service.dispatch(RPCObject(["method": "tools/list"]))
            try await service.disconnect()
            XCTAssertEqual(probe.count, calls.count, "Discovery and unused disconnect must not provision storage.")
            XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
            XCTAssertEqual(try Data(contentsOf: invalid), Data("not a directory".utf8))
        }
    }

    func testMCPUsesTheSameVerifiedAdapterForWorkAndDisconnect() async throws {
        let fixture = try fixture(); let peer = Peer(policy: fixture.policy)
        let adapter = WorkerAdapter(store: fixture.store, serverFactory: { _, _, _ in peer })
        let service = CoordinatorMCP(adapterFactory: { adapter })
        _ = try await service.dispatch(RPCObject(["method": "initialize"]))
        _ = try await service.dispatch(RPCObject(["method": "tools/list"]))
        XCTAssertTrue(peer.calls.isEmpty)
        let result = try await service.dispatch(RPCObject([
            "method": "tools/call", "params": ["name": "worker_start", "arguments": [
                "projectId": "project-one", "assignmentId": "task-one", "prompt": "Begin the approved work",
            ]],
        ])).object()
        let text = try XCTUnwrap((result["content"] as? [[String: String]])?.first?["text"])
        let started = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let workerID = try XCTUnwrap(started["workerId"] as? String)
        _ = try await service.dispatch(RPCObject([
            "method": "tools/call", "params": ["name": "worker_status", "arguments": ["workerId": workerID]],
        ]))
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/start" }.count, 1)
        try await service.disconnect()
        XCTAssertEqual(peer.closeCount, 1)
        XCTAssertEqual(try fixture.store.assignment(projectID: "project-one", taskID: "task-one").connectionClosed, true)
    }

    actor Gate {
        private var entered = false
        private var waiter: CheckedContinuation<Void, Never>?
        private var observers: [CheckedContinuation<Void, Never>] = []
        func pause() async {
            entered = true; observers.forEach { $0.resume() }; observers.removeAll()
            await withCheckedContinuation { waiter = $0 }
        }
        func waitUntilEntered() async {
            if entered { return }
            await withCheckedContinuation { observers.append($0) }
        }
        func release() { waiter?.resume(); waiter = nil }
    }
    final class Peer: ExecutionPeer, @unchecked Sendable {
        let policy: WorkerPolicy
        var calls: [(String, RPCObject)] = []
        var sent: [RPCObject] = []
        var lostStart = false
        var broadWrite = false
        var broadRead = false
        var completesImmediately = false
        var closeFailure = false
        var closeCount = 0
        var sendFailure = false
        var lostFollowup = false
        var delayedHooks: Gate?
        var delayedThreadStart: Gate?
        init(policy: WorkerPolicy) { self.policy = policy }
        func send(_ object: [String: Any]) throws {
            if sendFailure { throw AppServerTransportError(message: "Fixture uncertain approval response", outcomeUnknown: true) }
            sent.append(try RPCObject(object))
        }
        func close() throws {
            closeCount += 1
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
                if let delayedThreadStart { self.delayedThreadStart = nil; await delayedThreadStart.pause() }
                if lostStart { throw AppServerTransportError(message: "Unknown start", outcomeUnknown: true) }
                return try RPCObject(["thread": ["id": "session-one"], "cwd": selected.checkoutPath,
                    "runtimeWorkspaceRoots": [selected.checkoutPath], "model": selected.model, "reasoningEffort": selected.effort,
                    "activePermissionProfile": ["id": selected.permissionProfile], "sandbox": ["networkAccess": false],
                    "approvalPolicy": "on-request", "instructionSources": [selected.checkoutPath + "/AGENTS.md"]])
            }
            if method == "mcpServerStatus/list" { return try RPCObject(["data": []]) }
            if method == "hooks/list" {
                if let delayedHooks { self.delayedHooks = nil; await delayedHooks.pause() }
                return try RPCObject(["data": [["cwd": selected.checkoutPath, "errors": [], "warnings": [], "hooks": [["command": "\"" + policy.policy.handlerPath + "\" --hook", "handlerType": "command", "source": "project", "sourcePath": "/Primary/.codex/hooks.json", "eventName": "userPromptSubmit", "enabled": true, "timeoutSec": 10, "trustStatus": "trusted", "key": "owned-key", "currentHash": "owned-hash"]]]]])
            }
            if method == "turn/start" {
                if lostFollowup { throw AppServerTransportError(message: "Fixture uncertain follow-up", outcomeUnknown: true) }
                return try RPCObject(["turn": ["id": "turn-one", "status": completesImmediately ? "completed" : "inProgress"]])
            }
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
        _ = try await adapter.close(workerID: id)
        let closed = try valid.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(closed.state, .unknown); XCTAssertEqual(closed.connectionClosed, true)
    }

    func testConfirmedClosePreservesStopAndRecordsClosureForOwnedCleanup() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy)
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        _ = try await adapter.interrupt(workerID: id)
        await adapter.event(id, try RPCObject(["method": "turn/completed", "params": ["threadId": "session-one", "turn": ["id": "turn-one", "status": "interrupted"]]]))
        _ = try await adapter.close(workerID: id)
        let stopped = try valid.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertEqual(stopped.connectionClosed, true)
        XCTAssertThrowsError(try WorkerPolicy(store: valid.store, projectID: "project-one", taskID: "task-one"))
    }

    func testDelayedReadinessReservesFollowupBeforeAwaitAndBlocksConcurrentClose() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.completesImmediately = true
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        let gate = Gate(); peer.delayedHooks = gate
        let first = Task { try await adapter.followUp(workerID: id, prompt: "Continue") }
        await gate.waitUntilEntered()
        do { _ = try await adapter.followUp(workerID: id, prompt: "Duplicate"); XCTFail("Concurrent followup must be rejected before readiness") } catch {}
        do { _ = try await adapter.close(workerID: id); XCTFail("Close must not race the reserved followup") } catch {}
        XCTAssertEqual(peer.closeCount, 0)
        await gate.release(); _ = try await first.value
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/start" }.count, 2)
    }

    func testKnownUncertainApprovalRunCanBeStoppedAndPhysicallyClosedWithoutClaimingOutcome() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy)
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        await adapter.event(id, try RPCObject(["id": 42, "method": "item/commandExecution/requestApproval", "params": ["threadId": "session-one", "turnId": "turn-one", "availableDecisions": ["accept", "decline", "cancel"]]]))
        let pending = try await adapter.status(workerID: id).object()
        let key = try XCTUnwrap((pending["pendingRequests"] as? [[String: Any]])?.first?["requestKey"] as? String)
        peer.sendFailure = true
        do { _ = try await adapter.respond(workerID: id, requestKey: key, decision: "accept"); XCTFail("Lost approval send must remain uncertain") } catch {}
        let stopped = try await adapter.interrupt(workerID: id).object()
        XCTAssertEqual(stopped["status"] as? String, "unknown")
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/interrupt" }.count, 1)
        XCTAssertEqual(try valid.store.assignment(projectID: "project-one", taskID: "task-one").state, .unknown)
        _ = try await adapter.close(workerID: id)
        let snapshot = try valid.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(snapshot.state, .unknown); XCTAssertEqual(snapshot.connectionClosed, true)
        XCTAssertThrowsError(try WorkerPolicy(store: valid.store, projectID: "project-one", taskID: "task-one"))
    }

    func testWorkMutationDuringPausedThreadStartRevokesReservationAndPreventsFirstTurn() async throws {
        let valid = try fixture()
        let sql = DeliveryStore(databaseURL: valid.store.root.appendingPathComponent("startup.sqlite"))
        try await sql.transact(actor: .init(id: "fixture"), reason: "Seed current startup work") { c in
            try c.execute("INSERT INTO projects(id,name) VALUES ('project-one','Fixture')")
            try c.execute("INSERT INTO project_roots(id,project_id,path) VALUES ('root-one','project-one','/Primary')")
            try c.execute("INSERT INTO project_bookmarks(project_id,path,bookmark_data,is_stale) VALUES ('project-one','/Primary',?,0)", bindings: [.blob(Data([1]))])
            try c.execute("INSERT INTO project_registrations(project_id,registration_id,request_generation,setup_state) VALUES ('project-one','registration-one',1,'complete')")
            try DeliveryPlanningPolicy.upsertPhase(projectID: .init(rawValue: "project-one"), phaseID: .init(rawValue: "phase-one"), name: "Phase", mode: .governed, connection: c)
            try c.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=2 WHERE project_id='project-one' AND phase_id='phase-one'")
            try c.execute("INSERT INTO tickets(id,project_id,phase_id,outcome,lane) VALUES ('ticket-one','project-one','phase-one','Approved outcome','in_progress')")
            _ = try TicketTaskPlanningPolicy.revisePlan(projectID: .init(rawValue: "project-one"), ticketID: .init(rawValue: "ticket-one"), expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "work-one"), label: "A", title: "Approved task", sortOrder: 0)], definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let work = try await sql.read { try ProjectExecutionWork.read(projectID: .init(rawValue: "project-one"), ticketID: "ticket-one", taskID: "work-one", taskPlanRevision: 1, phaseRevision: 2, connection: $0) }
        let initial = valid.policy.assignment
        let assigned = ProjectExecutionAssignment(id: initial.id, registration: initial.registration, checkoutPath: initial.checkoutPath, role: initial.role,
            permissionProfile: initial.permissionProfile, model: initial.model, effort: initial.effort, authorization: initial.authorization,
            context: initial.context, excludedPaths: initial.excludedPaths, worktree: initial.worktree, work: work)
        try valid.store.saveAssignment(assigned, expected: initial)
        let root = valid.store.root; try await sql.observeExecutionAssignments(root: { root })
        let peer = Peer(policy: try WorkerPolicy(store: valid.store, projectID: "project-one", taskID: "task-one"))
        let gate = Gate(); peer.delayedThreadStart = gate
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let operation = Task { try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin") }
        await gate.waitUntilEntered()
        try await sql.transact(actor: .init(id: "fixture"), reason: "Revise work during thread start",
            auditScope: .init(projectID: assigned.registration.projectID, entityType: .ticketTaskPlan, entityID: "ticket-one")) {
            try $0.execute("UPDATE ticket_tasks SET title='Changed task' WHERE project_id='project-one' AND ticket_id='ticket-one'")
        }
        await gate.release(); _ = try await operation.value
        let revoked = try valid.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(revoked.state, .revoked); XCTAssertEqual(revoked.launchReserved, true)
        XCTAssertEqual(revoked.uncertainOutcome, true)
        XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" })
    }

    func testUncertainFollowupRevokesAdmissionWithoutPreventingKnownRunStop() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.completesImmediately = true
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let id = try XCTUnwrap(started["workerId"] as? String)
        peer.lostFollowup = true
        do { _ = try await adapter.followUp(workerID: id, prompt: "Continue"); XCTFail("Lost follow-up must remain uncertain") } catch {}
        let snapshot = try valid.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(snapshot.state, .unknown); XCTAssertEqual(snapshot.uncertainOutcome, true)
        XCTAssertThrowsError(try valid.policy.current(sessionID: "session-one"))
        _ = try await adapter.interrupt(workerID: id)
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/interrupt" }.count, 1)
    }
}
