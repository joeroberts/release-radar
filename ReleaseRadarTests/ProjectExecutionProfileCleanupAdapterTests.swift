import Foundation
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class ProjectExecutionProfileCleanupAdapterTests: XCTestCase {
    func testDefaultConfirmedRemovalFailsClosedWithoutCallingPreWriteHook() async throws {
        let configuration = InertConfiguration()
        let calls = CallCounter()
        let request = ProjectExecutionConfirmedProfileRemoval(profileID: "rr-delivery-cleanup",
            selectedCodexContextID: UUID(), configurationVersion: "before-v1",
            expectedDefinition: Data(#"{"network":{"enabled":false}}"#.utf8))

        do {
            _ = try await configuration.removeConfirmedWorkerProfile(primaryRoot: "/Primary", request: request,
                beforeWrite: { await calls.increment() })
            XCTFail("An adapter without a concrete verified writer must not report removal")
        } catch let error as ProjectExecutionError {
            XCTAssertEqual(error, .unavailable)
        }
        let callCount = await calls.value
        XCTAssertEqual(callCount, 0)
    }

    func testSyntheticAdapterEmitsOneQuotedNullEditWithConfirmedVersionAndChecksReadback() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let initial = configurationLayer(root: root, version: "before-v1", includeTarget: true, preserveOther: true)
        let readback = configurationLayer(root: root, version: "after-v2", includeTarget: false, preserveOther: true)
        let peer = ConfigurationPeer(replies: [initial, readback])
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
            contextAccessFactory: { selected, files in
                try CodexExecutionContextLease(context: selected, current: { try files.codexContext() },
                    resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
            }, configurationRPC: { method, params, readback in
                try await peer.reply(method: method, params: params, readback: readback)
            })
        let request = ProjectExecutionConfirmedProfileRemoval(profileID: "rr-delivery-cleanup",
            selectedCodexContextID: context.id, configurationVersion: "before-v1",
            expectedDefinition: Data(#"{"network":{"enabled":false}}"#.utf8))

        let result = try await client.removeConfirmedWorkerProfile(primaryRoot: "/Primary", request: request, beforeWrite: {})

        XCTAssertEqual(result.configurationVersion, "after-v2")
        let capturedWrite = await peer.write
        let write = try XCTUnwrap(capturedWrite)
        XCTAssertEqual(write.method, "config/batchWrite")
        XCTAssertFalse(write.readback)
        XCTAssertEqual(write.expectedVersion, "before-v1")
        XCTAssertEqual(write.reloadUserConfig, true)
        let edit = try XCTUnwrap(write.edit)
        XCTAssertEqual(edit.keyPath, #"permissions."rr-delivery-cleanup""#)
        XCTAssertTrue(edit.valueIsNull)
        XCTAssertEqual(edit.mergeStrategy, "replace")
    }

    func testSyntheticAdapterRejectsReadbackThatChangesAnUnrelatedSetting() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let peer = ConfigurationPeer(replies: [configurationLayer(root: root, version: "before-v1", includeTarget: true, preserveOther: true),
                                                configurationLayer(root: root, version: "after-v2", includeTarget: false, preserveOther: false)])
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
            contextAccessFactory: { selected, files in
                try CodexExecutionContextLease(context: selected, current: { try files.codexContext() },
                    resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
            }, configurationRPC: { method, params, readback in
                try await peer.reply(method: method, params: params, readback: readback)
            })
        let request = ProjectExecutionConfirmedProfileRemoval(profileID: "rr-delivery-cleanup",
            selectedCodexContextID: context.id, configurationVersion: "before-v1",
            expectedDefinition: Data(#"{"network":{"enabled":false}}"#.utf8))

        do {
            _ = try await client.removeConfirmedWorkerProfile(primaryRoot: "/Primary", request: request, beforeWrite: {})
            XCTFail("A changed non-target setting must not be accepted as a successful cleanup")
        } catch let error as ProjectExecutionError {
            XCTAssertEqual(error, .conflict)
        }
        let write = await peer.write
        XCTAssertNotNil(write)
    }

    private actor CallCounter {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    private struct CapturedEdit: Sendable {
        let keyPath: String?
        let valueIsNull: Bool
        let mergeStrategy: String?
    }

    private struct CapturedRequest: Sendable {
        let method: String
        let expectedVersion: String?
        let reloadUserConfig: Bool?
        let edit: CapturedEdit?
        let readback: Bool
    }

    private actor ConfigurationPeer {
        private var replies: [[String: Any]]
        private(set) var write: CapturedRequest?

        init(replies: [[String: Any]]) { self.replies = replies }
        func reply(method: String, params: ReleaseRadar.RPCObject,
                   readback: Bool) throws -> ReleaseRadar.RPCObject {
            let object = try params.object()
            if method == "config/batchWrite" {
                let edit = (object["edits"] as? [[String: Any]])?.first
                write = .init(method: method,
                    expectedVersion: object["expectedVersion"] as? String,
                    reloadUserConfig: object["reloadUserConfig"] as? Bool,
                    edit: edit.map { .init(keyPath: $0["keyPath"] as? String,
                        valueIsNull: $0["value"] is NSNull,
                        mergeStrategy: $0["mergeStrategy"] as? String) },
                    readback: readback)
            }
            guard method == "config/read", !replies.isEmpty else { return try ReleaseRadar.RPCObject([:]) }
            return try ReleaseRadar.RPCObject(replies.removeFirst())
        }
    }

    private func configurationLayer(root: URL, version: String, includeTarget: Bool, preserveOther: Bool) -> [String: Any] {
        var permissions: [String: Any] = ["rr-other": ["network": ["enabled": true]]]
        if includeTarget { permissions["rr-delivery-cleanup"] = ["network": ["enabled": false]] }
        var config: [String: Any] = ["permissions": permissions, "theme": "dark"]
        if !preserveOther { config["theme"] = "changed" }
        return ["layers": [["name": ["type": "user", "file": root.appendingPathComponent("config.toml").path],
                             "version": version, "config": config]]]
    }

    private actor InertConfiguration: ProjectExecutionConfiguring {
        func selectedCodexContextID() async throws -> UUID? { nil }
        func useCodexContext(_ expected: UUID?) async throws {}
        func validateInstallation(handlerPath: String) async throws {}
        func sharedExecutionSkill() async throws -> ProjectExecutionSharedExecutionSkill { throw ProjectExecutionError.unavailable }
        func validateHandlerIdentity(handlerPath: String) async throws {}
        func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage { .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {}
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws {}
        func finishConfiguration() async throws {}
        func recoverConfigurationConnection() async throws {}
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws {}
        func workerProfileExists(primaryRoot: String, profileID: String) async throws -> Bool { false }
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws {}
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {}
        func observeWorkerProfiles(primaryRoot: String) async throws -> ProjectExecutionWorkerProfileObservation { throw ProjectExecutionError.unavailable }
    }
}
