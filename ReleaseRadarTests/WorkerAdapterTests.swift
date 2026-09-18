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
        var accountType = "chatgpt"
        var modelProvider = "openai"
        var returnedModelProvider = "openai"
        var completesImmediately = false
        var closeFailure = false
        var closeCount = 0
        var sendFailure = false
        var lostFollowup = false
        var delayedHooks: Gate?
        var delayedThreadStart: Gate?
        var instructionSources: [String]?
        var beforeThreadStartReturn: (() throws -> Void)?
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
            if method == "account/read" { return try RPCObject(["account": ["type": accountType]]) }
            if method == "config/read" {
                let paths = try ProjectExecutionPaths(storageRoot: policy.store.root, projectID: selected.registration.projectID.rawValue, taskID: selected.id)
                var fs = try ProjectExecutionPermissionProfile(assignment: selected, policy: policy.policy, paths: paths).filesystemObject
                if broadWrite { fs[policy.store.root.path] = "write" }
                if broadRead { fs["/Users"] = "read" }
                return try RPCObject(["config": ["model_provider": modelProvider, "permissions": [selected.permissionProfile: ["filesystem": fs, "network": ["enabled": false]]]]])
            }
            if method == "thread/start" {
                if let delayedThreadStart { self.delayedThreadStart = nil; await delayedThreadStart.pause() }
                if lostStart { throw AppServerTransportError(message: "Unknown start", outcomeUnknown: true) }
                try beforeThreadStartReturn?()
                return try RPCObject(["thread": ["id": "session-one", "modelProvider": returnedModelProvider], "cwd": selected.checkoutPath,
                    "runtimeWorkspaceRoots": [selected.checkoutPath], "model": selected.model, "reasoningEffort": selected.effort,
                    "activePermissionProfile": ["id": selected.permissionProfile], "sandbox": ["networkAccess": false],
                    "approvalPolicy": "on-request", "instructionSources": instructionSources ?? [selected.checkoutPath + "/AGENTS.md"]])
            }
            if method == "mcpServerStatus/list" { return try RPCObject(["data": []]) }
            if method == "hooks/list" {
                if let delayedHooks { self.delayedHooks = nil; await delayedHooks.pause() }
                return try RPCObject(["data": [["cwd": selected.checkoutPath, "errors": [], "warnings": [], "hooks": [["command": "\"" + policy.policy.handlerPath + "\" --hook", "handlerType": "command", "source": "project", "sourcePath": try CodexExecutionContext.canonicalPath(policy.policy.primaryRoot) + "/.codex/hooks.json", "eventName": "userPromptSubmit", "enabled": true, "timeoutSec": 10, "trustStatus": "trusted", "key": "owned-key", "currentHash": "owned-hash"]]]]])
            }
            if method == "turn/start" {
                if lostFollowup { throw AppServerTransportError(message: "Fixture uncertain follow-up", outcomeUnknown: true) }
                return try RPCObject(["turn": ["id": "turn-one", "status": completesImmediately ? "completed" : "inProgress"]])
            }
            return try RPCObject([:])
        }
    }
    private func fixture(primaryRoot: String? = nil, includeProgress: Bool = false) throws -> (store: ProjectExecutionFileStore, policy: WorkerPolicy) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: "task-one")
        try FileManager.default.createDirectory(at: paths.checkout, withIntermediateDirectories: true)
        let context = Data("Current applicable instructions".utf8)
        try context.write(to: paths.checkout.appendingPathComponent("AGENTS.md"))
        var contexts: [ProjectExecutionAssignment.Context] = [.init(path: "AGENTS.md", digest: SHA256.hash(data: context).map { String(format: "%02x", $0) }.joined())]
        if includeProgress {
            let progress = Data("Current bounded delivery context".utf8)
            let url = paths.checkout.appendingPathComponent("docs/delivery/progress.md")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try progress.write(to: url)
            contexts.append(.init(path: "docs/delivery/progress.md", digest: SHA256.hash(data: progress).map { String(format: "%02x", $0) }.joined()))
        }
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let handler = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator"
        let primary = primaryRoot ?? root.appendingPathComponent("Primary").path
        if primaryRoot == nil { try FileManager.default.createDirectory(atPath: primary, withIntermediateDirectories: true) }
        let codex = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(codex, expected: nil)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: primary, appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handler)
        policy.consent = .init(); policy.hookReceipt = .init(command: "\"" + handler + "\" --hook", inline: false, beforeDigest: nil, intendedDigest: String(repeating: "a", count: 64), installed: true)
        policy.codexContextID = codex.id
        try store.savePolicy(policy, expected: nil)
        var assignment = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .delivery,
            permissionProfile: "rr-worker", model: "gpt-5.6-sol", effort: "high", authorization: "Implement the approved slice",
            context: contexts,
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            worktree: .init(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40), branch: "codex/rr-project-one-task-one", commonGitDirectory: primary + "/.git", primaryRoot: primary))
        assignment.codexContextID = codex.id
        try store.saveAssignment(assignment, expected: nil)
        return (store, try WorkerPolicy(store: store, projectID: "project-one", taskID: "task-one"))
    }
    func testSelectedHomeGlobalAndProjectGuidanceAdmitFirstTurnWithoutProgressInstructionSource() async throws {
        let valid = try fixture(includeProgress: true)
        let global = valid.store.root.appendingPathComponent("AGENTS.md")
        try Data("Owner global guidance".utf8).write(to: global)
        let peer = Peer(policy: valid.policy)
        peer.instructionSources = [global.path, valid.policy.assignment.checkoutPath + "/AGENTS.md"]
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "inProgress")
        XCTAssertTrue(peer.calls.contains { $0.0 == "turn/start" })
        _ = try await adapter.interrupt(workerID: try XCTUnwrap(started["workerId"] as? String))
        await adapter.event(try XCTUnwrap(started["workerId"] as? String), try RPCObject(["method": "turn/completed",
            "params": ["threadId": "session-one", "turn": ["id": "turn-one", "status": "interrupted"]]]))
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
    }

    func testGlobalGuidanceUsesFirstNonEmptyOverrideOrBase() async throws {
        for override in [nil, "Override guidance", "", " \n\t"] as [String?] {
            let valid = try fixture()
            let base = valid.store.root.appendingPathComponent("AGENTS.md")
            let replacement = valid.store.root.appendingPathComponent("AGENTS.override.md")
            try Data("Base guidance".utf8).write(to: base)
            if let override { try Data(override.utf8).write(to: replacement) }
            let expected = override?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? replacement : base
            let peer = Peer(policy: valid.policy)
            peer.instructionSources = [expected.path, valid.policy.assignment.checkoutPath + "/AGENTS.md"]
            let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
            let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
            XCTAssertEqual(started["status"] as? String, "inProgress")
            XCTAssertTrue(peer.calls.contains { $0.0 == "turn/start" })
            _ = try await adapter.interrupt(workerID: try XCTUnwrap(started["workerId"] as? String))
            await adapter.event(try XCTUnwrap(started["workerId"] as? String), try RPCObject(["method": "turn/completed",
                "params": ["threadId": "session-one", "turn": ["id": "turn-one", "status": "interrupted"]]]))
            _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
        }
    }

    func testGlobalGuidanceRejectsForeignArbitraryAndUnselectedSources() async throws {
        for kind in ["foreign", "prefix", "arbitrary", "base-with-override", "both", "empty"] {
            let valid = try fixture()
            let home = valid.store.root.path
            try Data((kind == "empty" ? "" : "Base guidance").utf8).write(to: valid.store.root.appendingPathComponent("AGENTS.md"))
            if ["base-with-override", "both"].contains(kind) {
                try Data("Override guidance".utf8).write(to: valid.store.root.appendingPathComponent("AGENTS.override.md"))
            }
            let sources: [String]
            switch kind {
            case "foreign": sources = [home + "/Foreign/AGENTS.md"]
            case "prefix": sources = [home + "-other/AGENTS.md"]
            case "arbitrary": sources = [home + "/other.md"]
            case "both": sources = [home + "/AGENTS.md", home + "/AGENTS.override.md"]
            default: sources = [home + "/AGENTS.md"]
            }
            let peer = Peer(policy: valid.policy)
            peer.instructionSources = sources + [valid.policy.assignment.checkoutPath + "/AGENTS.md"]
            let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
            let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
            XCTAssertEqual(started["status"] as? String, "failed", kind)
            XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" }, kind)
            _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
        }
    }

    func testGlobalGuidanceSymlinkEscapeCannotAdmitFirstTurn() async throws {
        let valid = try fixture()
        let outside = valid.store.root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + "-AGENTS.md")
        try Data("Outside guidance".utf8).write(to: outside)
        let global = valid.store.root.appendingPathComponent("AGENTS.override.md")
        try FileManager.default.createSymbolicLink(atPath: global.path, withDestinationPath: outside.path)
        let peer = Peer(policy: valid.policy)
        peer.instructionSources = [global.path, valid.policy.assignment.checkoutPath + "/AGENTS.md"]
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "failed")
        XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" })
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
    }

    func testChangedSelectedHomeReceiptBlocksGlobalGuidanceDespiteSameContextID() async throws {
        let valid = try fixture()
        let original = try XCTUnwrap(valid.store.codexContext())
        let global = URL(fileURLWithPath: original.homePath).appendingPathComponent("AGENTS.md")
        try Data("Owner guidance".utf8).write(to: global)
        let peer = Peer(policy: valid.policy)
        peer.instructionSources = [global.path, valid.policy.assignment.checkoutPath + "/AGENTS.md"]
        peer.beforeThreadStartReturn = {
            let changed = try CodexExecutionContext(home: URL(fileURLWithPath: original.homePath), bookmark: Data([2]), id: original.id)
            try valid.store.saveCodexContext(changed, expected: original)
        }
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "failed")
        XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" })
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
    }

    func testEffectiveProfileNormalizationKeepsExactFilesystemAndNetworkCeiling() throws {
        let fixture = try fixture()
        let assignment = fixture.policy.assignment
        let paths = try ProjectExecutionPaths(storageRoot: fixture.store.root, projectID: "project-one", taskID: "task-one")
        let fs = try ProjectExecutionPermissionProfile(assignment: assignment, policy: fixture.policy.policy, paths: paths).filesystemObject
        let normalized: [String: Any] = ["description": NSNull(), "extends": NSNull(), "workspace_roots": [],
            "filesystem": fs, "network": ["enabled": false]]
        try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: normalized]])
        for metadata in [["extends": [":workspace"]], ["workspace_roots": ["/Users"]], ["unexpected": false]] as [[String: Any]] {
            let broadened = normalized.merging(metadata) { _, replacement in replacement }
            XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: broadened]]))
        }
        var broadened = normalized
        broadened["network"] = ["enabled": true]
        XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: broadened]]))
        var addedRoot = fs; addedRoot["/Users"] = "read"; broadened = normalized; broadened["filesystem"] = addedRoot
        XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: broadened]]))
        for routing in [["model_provider": "custom"], ["openai_base_url": "https://provider.invalid/v1"],
                        ["chatgpt_base_url": "https://provider.invalid/backend-api/"]] {
            var config: [String: Any] = ["permissions": [assignment.permissionProfile: normalized]]
            for (key, value) in routing { config[key] = value }
            XCTAssertThrowsError(try fixture.policy.validate(config: config)) {
                XCTAssertEqual($0 as? CodexExecutionContextError, .routingUnsupported)
            }
        }
    }

    func testEffectiveProfileAcceptsCodexConfigReadNullMetadataOnly() throws {
        let fixture = try fixture()
        let assignment = fixture.policy.assignment
        let paths = try ProjectExecutionPaths(storageRoot: fixture.store.root, projectID: "project-one", taskID: "task-one")
        var fs = try ProjectExecutionPermissionProfile(assignment: assignment, policy: fixture.policy.policy, paths: paths).filesystemObject
        fs["glob_scan_max_depth"] = NSNull()
        let optionalNetworkFields = ["proxy_url", "enable_socks5", "socks_url", "enable_socks5_udp",
            "allow_upstream_proxy", "dangerously_allow_non_loopback_proxy", "dangerously_allow_all_unix_sockets",
            "mode", "domains", "unix_sockets", "allow_local_binding", "mitm"]
        var network: [String: Any] = ["enabled": false]
        for key in optionalNetworkFields { network[key] = NSNull() }
        let normalized: [String: Any] = ["description": NSNull(), "extends": NSNull(), "workspace_roots": NSNull(),
            "filesystem": fs, "network": network]
        let config: [String: Any] = ["permissions": [assignment.permissionProfile: normalized]]
        // Match the JSON-normalized installed Codex 0.155.0-alpha.9 config/read response.
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: config)) as? [String: Any])
        XCTAssertNoThrow(try fixture.policy.validate(config: decoded))

        for key in optionalNetworkFields {
            for value in [true, false, "full", [:], []] as [Any] {
                var changedNetwork = network; changedNetwork[key] = value
                var changed = normalized; changed["network"] = changedNetwork
                XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: changed]]), key)
            }
        }
        for value in [true, NSNull(), "false"] as [Any] {
            var changedNetwork = network; changedNetwork["enabled"] = value
            var changed = normalized; changed["network"] = changedNetwork
            XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: changed]]))
        }
        var unknownNetwork = network; unknownNetwork["unexpected"] = NSNull()
        var changed = normalized; changed["network"] = unknownNetwork
        XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: changed]]))
        for value in [1, 0, "read", [:]] as [Any] {
            var changedFS = fs; changedFS["glob_scan_max_depth"] = value
            changed = normalized; changed["filesystem"] = changedFS
            XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: changed]]))
        }
        for addition in [["/Users": "read"], ["unexpected": NSNull()]] as [[String: Any]] {
            changed = normalized; changed["filesystem"] = fs.merging(addition) { _, replacement in replacement }
            XCTAssertThrowsError(try fixture.policy.validate(config: ["permissions": [assignment.permissionProfile: changed]]))
        }
    }

    func testSelectedContextCannotSilentlySwitchWorkerToApiBilling() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.accountType = "apiKey"
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "failed")
        XCTAssertFalse(peer.calls.contains { $0.0 == "thread/start" || $0.0 == "turn/start" || $0.0 == "account/login/start" })
        let account = try XCTUnwrap(peer.calls.first { $0.0 == "account/read" }).1.object()
        XCTAssertEqual(account["refreshToken"] as? Bool, false)
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
        XCTAssertThrowsError(try WorkerPolicy(store: valid.store, projectID: "project-one", taskID: "task-one"))
    }

    func testChatGPTAccountWithCustomProviderCannotStartThreadOrGeneration() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.modelProvider = "custom"
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "failed")
        XCTAssertFalse(peer.calls.contains { $0.0 == "thread/start" || $0.0 == "turn/start" })
        XCTAssertEqual(try valid.store.assignment(projectID: "project-one", taskID: "task-one").uncertainOutcome, true)
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
    }

    func testReturnedProviderMismatchCannotBindAssignmentOrStartGeneration() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.returnedModelProvider = "custom"
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "failed")
        XCTAssertFalse(peer.calls.contains { $0.0 == "turn/start" })
        let retained = try valid.store.assignment(projectID: "project-one", taskID: "task-one")
        XCTAssertNil(retained.sessionID); XCTAssertEqual(retained.uncertainOutcome, true)
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
    }

    func testCanonicalPrimarySourceIsUsedForWorkerStartupAndFollowup() async throws {
        let valid = try fixture(primaryRoot: "/var"); let peer = Peer(policy: valid.policy); peer.completesImmediately = true
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        XCTAssertEqual(started["status"] as? String, "completed")
        _ = try await adapter.followUp(workerID: try XCTUnwrap(started["workerId"] as? String), prompt: "Continue")
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/start" }.count, 2)
    }

    func testUnboundOrChangedContextBlocksStartupAndFollowupWithoutReplay() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy); peer.completesImmediately = true
        var unbound = valid.policy.assignment; unbound.codexContextID = nil
        try valid.store.saveAssignment(unbound, expected: valid.policy.assignment)
        XCTAssertThrowsError(try WorkerPolicy(store: valid.store, projectID: "project-one", taskID: "task-one"))
        try valid.store.saveAssignment(valid.policy.assignment, expected: unbound)
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let original = try XCTUnwrap(valid.store.codexContext())
        let replacement = try CodexExecutionContext(home: URL(fileURLWithPath: original.homePath), bookmark: Data([2]))
        try valid.store.saveCodexContext(replacement, expected: original)
        do { _ = try await adapter.followUp(workerID: try XCTUnwrap(started["workerId"] as? String), prompt: "Continue"); XCTFail("Changed context must block followup") } catch {}
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/start" }.count, 1)
        XCTAssertThrowsError(try WorkerPolicy(store: valid.store, projectID: "project-one", taskID: "task-one"))
        _ = try await adapter.close(workerID: try XCTUnwrap(started["workerId"] as? String))
        XCTAssertEqual(peer.closeCount, 1, "Physical close remains available after context loss")
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

    func testUnrelatedProvisioningCannotDelayDurableStopOrInterrupt() async throws {
        let valid = try fixture(); let peer = Peer(policy: valid.policy)
        let adapter = WorkerAdapter(store: valid.store, serverFactory: { _, _, _ in peer })
        let started = try await adapter.start(projectID: "project-one", assignmentID: "task-one", prompt: "Begin").object()
        let workerID = try XCTUnwrap(started["workerId"] as? String)
        let entered = expectation(description: "Unrelated checkout provisioning is paused")
        let interrupted = expectation(description: "STOP and interrupt finish while provisioning remains paused")
        let release = DispatchSemaphore(value: 0)
        let creationStore = valid.store
        let contextID = valid.policy.assignment.codexContextID
        let creation = Task.detached {
            do {
                _ = try creationStore.createAssignment(codexContextID: contextID) {
                    entered.fulfill()
                    release.wait()
                    throw ProjectExecutionError.unavailable // No unrelated resources were created.
                }
                return false
            } catch { return error as? ProjectExecutionError == .unavailable }
        }
        await fulfillment(of: [entered], timeout: 5)
        let stopping = Task {
            let result = try await adapter.interrupt(workerID: workerID)
            interrupted.fulfill()
            return result
        }
        await fulfillment(of: [interrupted], timeout: 2)
        release.signal() // Always unblock the negative run before awaiting its tasks.
        let cancelledCreation = await creation.value
        XCTAssertTrue(cancelledCreation)
        _ = try await stopping.value
        XCTAssertEqual(try valid.store.assignment(projectID: "project-one", taskID: "task-one").state, .stopped)
        XCTAssertEqual(peer.calls.filter { $0.0 == "turn/interrupt" }.count, 1)
        await adapter.event(workerID, try RPCObject(["method": "turn/completed", "params": ["threadId": "session-one", "turn": ["id": "turn-one", "status": "interrupted"]]]))
        _ = try await adapter.close(workerID: workerID)
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
        let primary = valid.policy.policy.primaryRoot
        try await sql.transact(actor: .init(id: "fixture"), reason: "Seed current startup work") { c in
            try c.execute("INSERT INTO projects(id,name) VALUES ('project-one','Fixture')")
            try c.execute("INSERT INTO project_roots(id,project_id,path) VALUES ('root-one','project-one',?)", bindings: [.text(primary)])
            try c.execute("INSERT INTO project_bookmarks(project_id,path,bookmark_data,is_stale) VALUES ('project-one',?,?,0)", bindings: [.text(primary), .blob(Data([1]))])
            try c.execute("INSERT INTO project_registrations(project_id,registration_id,request_generation,setup_state) VALUES ('project-one','registration-one',1,'complete')")
            try DeliveryPlanningPolicy.upsertPhase(projectID: .init(rawValue: "project-one"), phaseID: .init(rawValue: "phase-one"), name: "Phase", mode: .governed, connection: c)
            try c.execute("UPDATE phase_lifecycles SET lifecycle='in_delivery',revision=2 WHERE project_id='project-one' AND phase_id='phase-one'")
            try c.execute("INSERT INTO tickets(id,project_id,phase_id,outcome,lane) VALUES ('ticket-one','project-one','phase-one','Approved outcome','in_progress')")
            _ = try TicketTaskPlanningPolicy.revisePlan(projectID: .init(rawValue: "project-one"), ticketID: .init(rawValue: "ticket-one"), expectedRevision: nil,
                additions: [.init(id: .init(rawValue: "work-one"), label: "A", title: "Approved task", sortOrder: 0)], definitionRevisions: [], supersededTaskIDs: [], connection: c)
        }
        let work = try await sql.read { try ProjectExecutionWork.read(projectID: .init(rawValue: "project-one"), ticketID: "ticket-one", taskID: "work-one", taskPlanRevision: 1, phaseRevision: 2, connection: $0) }
        let initial = valid.policy.assignment
        var assigned = ProjectExecutionAssignment(id: initial.id, registration: initial.registration, checkoutPath: initial.checkoutPath, role: initial.role,
            permissionProfile: initial.permissionProfile, model: initial.model, effort: initial.effort, authorization: initial.authorization,
            context: initial.context, excludedPaths: initial.excludedPaths, worktree: initial.worktree, work: work)
        assigned.codexContextID = initial.codexContextID
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
