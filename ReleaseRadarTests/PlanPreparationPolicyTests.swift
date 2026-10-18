import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class PlanPreparationPolicyTests: XCTestCase {
    func testAcceptsExactIdentityProfileAndReadbackContract() throws {
        let fixture = try Fixture()
        let policy = try PlanPreparationPolicy(request: fixture.request)

        let overrides = try policy.processOverrides(config: [
            "mcp_servers": ["owner-server": [:]],
            "plugins": ["owner-plugin": [:]]
        ])
        XCTAssertEqual(PlanPreparationPolicy.permissionProfileID, "rr-plan-preparation")
        XCTAssertEqual(overrides["permissions.rr-plan-preparation.network.enabled"] as? Bool, false)
        XCTAssertEqual(overrides["mcp_servers.owner-server.enabled"] as? Bool, false)
        XCTAssertEqual(overrides["plugins.owner-plugin.enabled"] as? Bool, false)
        XCTAssertEqual(overrides["agents.enabled"] as? Bool, false)
        XCTAssertEqual(overrides["model_reasoning_effort"] as? String, "high")

        let profile = fixture.normalizedProfile()
        XCTAssertNoThrow(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))
        let readback = RepositoryPlanPreparationReadback(
            identity: fixture.request.identity, state: .readyForReview,
            threadID: "thread-101", turnID: "turn-101", draftBytes: Data("draft".utf8), error: nil
        )
        XCTAssertEqual(readback.identity, fixture.request.identity)
        XCTAssertEqual(readback.state, .readyForReview)
        XCTAssertEqual(readback.draftBytes, Data("draft".utf8))
    }

    func testRejectsManifestRegistrationRootAndProjectMismatches() throws {
        let fixture = try Fixture()
        var request = fixture.request
        request.identity = .init(registration: .init(projectID: .init(rawValue: "other-project"), registrationID: "registration-101", requestGeneration: 1),
            rootID: "root-101", proposalID: .init(rawValue: "proposal-101"), attemptID: fixture.request.identity.attemptID)
        XCTAssertThrowsError(try PlanPreparationPolicy(request: request))

        request = fixture.request
        request.identity = .init(registration: fixture.request.identity.registration, rootID: "other-root",
            proposalID: fixture.request.identity.proposalID, attemptID: fixture.request.identity.attemptID)
        XCTAssertThrowsError(try PlanPreparationPolicy(request: request))

        request = fixture.request
        request.sourceManifest = .init(projectID: .init(rawValue: "other-project"), rootID: "root-101", rootPath: fixture.sourceRoot.path,
            registration: fixture.request.identity.registration, repositoryID: "repository-101", acceptedCatalogVersion: 1,
            acceptedCatalogDigest: String(repeating: "a", count: 64), sources: [])
        XCTAssertThrowsError(try PlanPreparationPolicy(request: request))
    }

    func testRejectsSnapshotAliasesAndWorkingPathMismatches() throws {
        let fixture = try Fixture()
        for path in [fixture.sourceRoot.path, fixture.sourceRoot.appendingPathComponent("child").path,
                     fixture.sourceRoot.deletingLastPathComponent().path] {
            var request = fixture.request
            request.snapshot = .init(rootPath: path, workingPath: path + "/session", manifestSHA256: String(repeating: "b", count: 64))
            XCTAssertThrowsError(try PlanPreparationPolicy(request: request), path)
        }
        var request = fixture.request
        request.snapshot = .init(rootPath: fixture.snapshotRoot.path, workingPath: fixture.snapshotRoot.appendingPathComponent("other").path,
            manifestSHA256: String(repeating: "b", count: 64))
        XCTAssertThrowsError(try PlanPreparationPolicy(request: request))
    }

    func testRejectsFilesystemRootAsAContainingSourceRoot() throws {
        let fixture = try Fixture()
        XCTAssertThrowsError(try PlanPreparationPolicy(request: try fixture.request(sourceRoot: "/")))
    }

    func testRejectsEmptySelectionAndChangedBoundManifestDigest() throws {
        let fixture = try Fixture()
        var request = fixture.request
        request.sourceManifest = .init(projectID: fixture.request.sourceManifest.projectID, rootID: fixture.request.sourceManifest.rootID,
            rootPath: fixture.request.sourceManifest.rootPath, registration: fixture.request.sourceManifest.registration,
            repositoryID: fixture.request.sourceManifest.repositoryID, acceptedCatalogVersion: fixture.request.sourceManifest.acceptedCatalogVersion,
            acceptedCatalogDigest: fixture.request.sourceManifest.acceptedCatalogDigest, sources: [])
        XCTAssertThrowsError(try PlanPreparationPolicy(request: request))

        request = fixture.request
        request.snapshot = .init(rootPath: fixture.request.snapshot.rootPath, workingPath: fixture.request.snapshot.workingPath,
            manifestSHA256: String(repeating: "f", count: 64))
        XCTAssertThrowsError(try PlanPreparationPolicy(request: request))
    }

    func testRejectsAdditionalFilesystemWritesAndNetworkMetadata() throws {
        let fixture = try Fixture(); let policy = try PlanPreparationPolicy(request: fixture.request)
        var profile = fixture.profile()
        var filesystem = try XCTUnwrap(profile["filesystem"] as? [String: Any])
        filesystem["/Users"] = "read"; profile["filesystem"] = filesystem
        XCTAssertThrowsError(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))

        profile = fixture.profile(); filesystem = try XCTUnwrap(profile["filesystem"] as? [String: Any])
        filesystem[":workspace_roots"] = [".": "write"]; profile["filesystem"] = filesystem
        XCTAssertThrowsError(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))

        profile = fixture.profile(); profile["network"] = ["enabled": false, "proxy_url": "https://proxy.invalid"]
        XCTAssertThrowsError(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))
    }

    func testAcceptsOnlyDocumentedUnsetConfigReadMetadata() throws {
        let fixture = try Fixture(); let policy = try PlanPreparationPolicy(request: fixture.request)
        XCTAssertNoThrow(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: fixture.normalizedProfile()]]))

        var profile = fixture.normalizedProfile()
        profile["description"] = "inherited profile"
        XCTAssertThrowsError(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))

        profile = fixture.normalizedProfile()
        var filesystem = try XCTUnwrap(profile["filesystem"] as? [String: Any])
        filesystem["glob_scan_max_depth"] = 1; profile["filesystem"] = filesystem
        XCTAssertThrowsError(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))

        profile = fixture.normalizedProfile()
        var network = try XCTUnwrap(profile["network"] as? [String: Any])
        network["unexpected"] = NSNull(); profile["network"] = network
        XCTAssertThrowsError(try policy.validateConfiguration(["permissions": [PlanPreparationPolicy.permissionProfileID: profile]]))
    }

    func testOverridesDisableEveryConfiguredExtensionAndRejectUnsafeKeys() throws {
        let fixture = try Fixture(); let policy = try PlanPreparationPolicy(request: fixture.request)
        let overrides = try policy.processOverrides(config: ["mcp_servers": ["one": [:], "two": [:]], "plugins": ["three": [:]]])
        XCTAssertEqual(overrides["mcp_servers.one.enabled"] as? Bool, false)
        XCTAssertEqual(overrides["mcp_servers.two.enabled"] as? Bool, false)
        XCTAssertEqual(overrides["plugins.three.enabled"] as? Bool, false)
        for key in ["mcp.server", "plugin\"name"] {
            XCTAssertThrowsError(try policy.processOverrides(config: ["mcp_servers": [key: [:]]]), key)
        }
    }

    func testThreadStartHasNoFallbackAndUsesExactRuntimeRoots() throws {
        let fixture = try Fixture(); let policy = try PlanPreparationPolicy(request: fixture.request)
        let parameters = try policy.threadStartParameters(config: ["permissions": [PlanPreparationPolicy.permissionProfileID: fixture.profile()]])
        XCTAssertEqual(parameters["cwd"] as? String, fixture.request.snapshot.workingPath)
        XCTAssertEqual(parameters["runtimeWorkspaceRoots"] as? [String], [fixture.request.snapshot.workingPath])
        XCTAssertEqual(parameters["model"] as? String, fixture.request.model)
        XCTAssertEqual(parameters["permissions"] as? String, PlanPreparationPolicy.permissionProfileID)
        XCTAssertEqual(parameters["allowProviderModelFallback"] as? Bool, false)
        XCTAssertEqual((parameters["config"] as? [String: Any])?["model_reasoning_effort"] as? String, fixture.request.effort)
    }

    func testRejectsMismatchedThreadReadbackAndInstructionSources() throws {
        let fixture = try Fixture(); let policy = try PlanPreparationPolicy(request: fixture.request)
        let permitted = ["/selected-codex/AGENTS.md"]
        var thread: [String: Any] = [
            "cwd": fixture.request.snapshot.workingPath, "runtimeWorkspaceRoots": [fixture.request.snapshot.workingPath],
            "model": fixture.request.model, "reasoningEffort": fixture.request.effort,
            "thread": ["id": "thread-101", "modelProvider": "openai"],
            "activePermissionProfile": ["id": PlanPreparationPolicy.permissionProfileID],
            "sandbox": ["networkAccess": false], "approvalPolicy": "never", "instructionSources": permitted
        ]
        XCTAssertNoThrow(try policy.validateThreadStart(thread, allowedInstructionSources: permitted))
        for change in [["thread": ["id": "thread-101", "modelProvider": "custom"]], ["model": "fallback"], ["reasoningEffort": "low"],
                       ["cwd": fixture.sourceRoot.path], ["activePermissionProfile": ["id": "other"]], ["sandbox": ["networkAccess": true]],
                       ["approvalPolicy": "on-request"], ["approvalsReviewer": "owner"],
                       ["instructionSources": ["/untrusted/AGENTS.md"]]] as [[String: Any]] {
            for (key, value) in change { thread[key] = value }
            XCTAssertThrowsError(try policy.validateThreadStart(thread, allowedInstructionSources: permitted), change.keys.joined(separator: ","))
            thread["cwd"] = fixture.request.snapshot.workingPath; thread["runtimeWorkspaceRoots"] = [fixture.request.snapshot.workingPath]
            thread["model"] = fixture.request.model; thread["reasoningEffort"] = fixture.request.effort
            thread["activePermissionProfile"] = ["id": PlanPreparationPolicy.permissionProfileID]; thread["thread"] = ["id": "thread-101", "modelProvider": "openai"]
            thread["sandbox"] = ["networkAccess": false]; thread["approvalPolicy"] = "never"; thread.removeValue(forKey: "approvalsReviewer"); thread["instructionSources"] = permitted
        }
        thread.removeValue(forKey: "thread")
        thread["modelProvider"] = "openai"
        XCTAssertThrowsError(try policy.validateThreadStart(thread, allowedInstructionSources: permitted))
    }

    func testModelsRoundTripWithoutDeliveryIdentity() throws {
        let fixture = try Fixture()
        let encoded = try JSONEncoder().encode(fixture.request)
        XCTAssertEqual(try JSONDecoder().decode(RepositoryPlanPreparationRequest.self, from: encoded), fixture.request)
        XCTAssertFalse(String(reflecting: RepositoryPlanPreparationRequest.self).contains("ProjectExecutionAssignment"))
        XCTAssertFalse(String(reflecting: RepositoryPlanPreparationRequest.self).contains("Worker"))
    }
}

private struct Fixture {
    let sourceRoot: URL
    let snapshotRoot: URL
    let request: RepositoryPlanPreparationRequest

    init() throws {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        sourceRoot = base.appendingPathComponent("source")
        snapshotRoot = base.appendingPathComponent("snapshot")
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: snapshotRoot.appendingPathComponent("session"), withIntermediateDirectories: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-101"), registrationID: "registration-101", requestGeneration: 1)
        let sourceBytes = Data("# Current approved plan\n".utf8)
        let source = RepositoryPlanCapturedSource(artifactID: "current-plan", path: "docs/plans/current.md",
            contentSHA256: Self.sha256(sourceBytes), lifecycle: .active, authority: .controlling, bytes: sourceBytes)
        let manifest = RepositoryPlanSourceManifest(projectID: registration.projectID, rootID: "root-101", rootPath: sourceRoot.path,
            registration: registration, repositoryID: "repository-101", acceptedCatalogVersion: 1,
            acceptedCatalogDigest: String(repeating: "a", count: 64), sources: [source])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let manifestSHA256 = Self.sha256(try encoder.encode(manifest))
        request = .init(identity: .init(registration: registration, rootID: "root-101", proposalID: .init(rawValue: "proposal-101"),
                attemptID: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!), sourceManifest: manifest,
            snapshot: .init(rootPath: snapshotRoot.path, workingPath: snapshotRoot.appendingPathComponent("session").path,
                manifestSHA256: manifestSHA256),
            projectionID: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!, projectionRevision: 1,
            codexContextID: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!, model: "gpt-6-astra", effort: "high")
    }

    func profile() -> [String: Any] {
        ["filesystem": [":root": "deny", ":minimal": "read", ":workspace_roots": [".": "read"]], "network": ["enabled": false]]
    }

    func normalizedProfile() -> [String: Any] {
        var filesystem = profile()["filesystem"] as! [String: Any]
        filesystem["glob_scan_max_depth"] = NSNull()
        var network: [String: Any] = ["enabled": false]
        for key in ["proxy_url", "enable_socks5", "socks_url", "enable_socks5_udp", "allow_upstream_proxy",
                    "dangerously_allow_non_loopback_proxy", "dangerously_allow_all_unix_sockets", "mode", "domains",
                    "unix_sockets", "allow_local_binding", "mitm"] {
            network[key] = NSNull()
        }
        return ["description": NSNull(), "extends": NSNull(), "workspace_roots": NSNull(), "filesystem": filesystem, "network": network]
    }

    func request(sourceRoot: String) throws -> RepositoryPlanPreparationRequest {
        let sourceManifest = RepositoryPlanSourceManifest(projectID: self.request.sourceManifest.projectID, rootID: self.request.sourceManifest.rootID,
            rootPath: sourceRoot, registration: self.request.sourceManifest.registration, repositoryID: self.request.sourceManifest.repositoryID,
            acceptedCatalogVersion: self.request.sourceManifest.acceptedCatalogVersion,
            acceptedCatalogDigest: self.request.sourceManifest.acceptedCatalogDigest, sources: self.request.sourceManifest.sources)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return .init(identity: self.request.identity, sourceManifest: sourceManifest,
            snapshot: .init(rootPath: self.request.snapshot.rootPath, workingPath: self.request.snapshot.workingPath,
                manifestSHA256: Self.sha256(try encoder.encode(sourceManifest))), projectionID: self.request.projectionID,
            projectionRevision: self.request.projectionRevision, codexContextID: self.request.codexContextID, model: self.request.model, effort: self.request.effort)
    }

    private static func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
