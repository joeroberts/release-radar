import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class DocumentationCallbackTests: XCTestCase {
    func testReadOnlyCallbackQueriesAndRejectsMutationsWithoutEffects() async throws {
        let f = try await fixture()
        let before = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let callback = AgentBridgeAppCallback(dispatcher: f.dispatcher, queries: f.queries, maintenanceMode: .readOnly,
                                              beforeDispatch: { _ in XCTFail("Read-only callback entered mutation hooks") }, afterDispatchBeforeReply: { _, _ in }, afterReply: { _, _ in })
        let query = AgentQueryEnvelope(version: 1, projectRoot: f.root.path, query: .inventoryEvidence(projectID: nil, rootID: nil))
        let result = try await send(callback, data: JSONEncoder().encode(query))
        XCTAssertEqual(result.inventory?.projectID, "p")
        let mutation = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.root.path, reason: "Disallowed", command: .upsertPhase(phaseID: "bad", name: "Bad"))
        let rejected = try await send(callback, data: JSONEncoder().encode(mutation))
        XCTAssertEqual(rejected.error, .appUnavailable)
        var mixed = try JSONSerialization.jsonObject(with: JSONEncoder().encode(query)) as! [String: Any]
        mixed["command"] = ["upsertPhase": ["phaseID": "bad", "name": "Bad"]]
        let mixedResult = try await send(callback, data: JSONSerialization.data(withJSONObject: mixed))
        XCTAssertEqual(mixedResult.error, .appUnavailable)
        let after = try await f.store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(after, before)
    }

    func testLostDocumentationReplyRecoversThroughExactReplay() async throws {
        let f = try await fixture()
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: f.root)
        let target = DocumentationTarget(projectID: "p", rootID: "root", repositoryID: snapshot.catalog.repositoryID.lowercased(), catalogVersion: snapshot.version, catalogDigest: snapshot.digest)
        let request = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.root.path, reason: "Approve binding", command: .bindDocumentationRepository(target: target))
        let callback = AgentBridgeAppCallback(dispatcher: f.dispatcher, queries: f.queries, maintenanceMode: .commands,
                                              beforeDispatch: { _ in }, afterDispatchBeforeReply: { _, _ in }, afterReply: { _, _ in })
        let received = expectation(description: "Committed reply intentionally discarded")
        callback.dispatch(ReleaseRadarBridgeTransport.wireVersion, envelope: try JSONEncoder().encode(request), admissionDeadline: Date().addingTimeInterval(10).timeIntervalSince1970) { _ in received.fulfill() }
        await fulfillment(of: [received], timeout: 2)
        let firstReplay = try await send(callback, data: JSONEncoder().encode(request))
        XCTAssertNil(firstReplay.error)
        let secondReplay = try await send(callback, data: JSONEncoder().encode(request))
        XCTAssertEqual(secondReplay, firstReplay)
        let counts = try await f.store.read { c in [try c.scalarInt("SELECT COUNT(*) FROM agent_command_requests"), try c.scalarInt("SELECT COUNT(*) FROM project_documentation_bindings")] }
        XCTAssertEqual(counts, [1, 1])
        let normal = AgentCommandEnvelope(version: 1, requestID: UUID(), projectRoot: f.root.path, reason: "Disallowed maintenance", command: .upsertPhase(phaseID: "bad", name: "Bad"))
        let rejection = try await send(callback, data: JSONEncoder().encode(normal))
        XCTAssertEqual(rejection.error, .appUnavailable)
    }

    func testPackagedHelperPublishesSixExactAdditiveSchemasWithoutConnecting() throws {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
        let process = Process(); process.executableURL = helper
        let input = Pipe(); let output = Pipe(); process.standardInput = input; process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data("{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\"}\n{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}\n".utf8))
        try input.fileHandleForWriting.close()
        // Drain before waiting: the complete schema list may exceed a pipe buffer.
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let response = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(data.split(separator: 10).last))) as! [String: Any]
        let tools = (response["result"] as! [String: Any])["tools"] as! [[String: Any]]
        let names = Set(tools.compactMap { $0["name"] as? String })
        let expected: Set<String> = ["release_radar_inventory_evidence", "release_radar_bind_documentation_repository", "release_radar_accept_documentation_catalog", "release_radar_add_managed_evidence", "release_radar_adopt_managed_evidence", "release_radar_relocate_legacy_evidence"]
        XCTAssertTrue(expected.isSubset(of: names))
        XCTAssertTrue(names.contains("release_radar_add_evidence"))
        XCTAssertTrue(names.contains("release_radar_revise_ticket_task_plan"))
        XCTAssertTrue(names.contains("release_radar_complete_ticket_task"))
        XCTAssertEqual(names.count, 24)
        let inventory = try XCTUnwrap(tools.first { $0["name"] as? String == "release_radar_inventory_evidence" })
        XCTAssertEqual((inventory["inputSchema"] as? [String: Any])?["required"] as? [String], ["version", "projectRoot"])
    }
    private func send(_ callback: AgentBridgeAppCallback, data: Data) async throws -> AgentCommandResult {
        let response = await withCheckedContinuation { continuation in
            callback.dispatch(ReleaseRadarBridgeTransport.wireVersion, envelope: data, admissionDeadline: Date().addingTimeInterval(10).timeIntervalSince1970) { continuation.resume(returning: $0) }
        }
        return try JSONDecoder().decode(AgentCommandResult.self, from: response)
    }
    private func fixture() async throws -> (store: DeliveryStore, root: URL, dispatcher: AgentCommandDispatcher, queries: AgentQueryDispatcher) {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-M3B-Callback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("repository")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid"), to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES ('p', 'Project')")
            try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root', 'p', ?)", bindings: [.text(root.path)])
            try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data) VALUES ('p', ?, ?)", bindings: [.text(root.path), .blob(Data([1]))])
        }
        let bookmarks = ProjectBookmarkStore(resolver: { _ in .init(url: root, isStale: false) }, startAccessing: { _ in true }, stopAccessing: { _ in })
        return (store, root, AgentCommandDispatcher(store: store, projectRegistry: PersistedAuthorizedProjectRegistry(store: store), bookmarkStore: bookmarks), AgentQueryDispatcher(store: store, bookmarkStore: bookmarks))
    }
}
