import Foundation
import Security
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionAppServerTests: XCTestCase {
    func testSetupTransportReadsPermissionTablesWithoutChangingOwnerDefault() async throws {
        let home = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let codex = home.appendingPathComponent("codex")
        let project = home.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let configFile = codex.appendingPathComponent("config.toml")
        let original = Data("""
        [permissions.fixture-readonly.filesystem]
        ":root" = "deny"
        ":minimal" = "read"
        [permissions.fixture-readonly.filesystem.":workspace_roots"]
        "." = "read"
        [permissions.fixture-readonly.network]
        enabled = false
        """.utf8)
        try original.write(to: configFile)
        let sandbox = SecTaskCreateFromSelf(nil).flatMap {
            SecTaskCopyValueForEntitlement($0, "com.apple.security.app-sandbox" as CFString, nil)
        }
        XCTAssertEqual(sandbox as? Bool, true, "A privileged XCTest runner is not sandbox evidence")
        let transport = try AppServerTransport(fixtureHome: home, onMessage: { _ in })
        defer {
            do { try transport.close() }
            catch { XCTFail("Setup transport cleanup failed: \(error.localizedDescription)") }
        }
        _ = try await transport.call("initialize", RPCObject(["clientInfo": ["name": "release-radar-setup-fixture", "version": "1"], "capabilities": ["experimentalApi": true]]))
        try transport.send(["method": "initialized"])
        do {
            let response = try await transport.call("config/read", RPCObject(["cwd": project.path, "includeLayers": true])).object()
            let config = try XCTUnwrap(response["config"] as? [String: Any])
            XCTAssertEqual(config["default_permissions"] as? String, ":read-only")
            let profiles = try XCTUnwrap(config["permissions"] as? [String: Any])
            let profile = try XCTUnwrap(profiles["fixture-readonly"] as? [String: Any])
            XCTAssertEqual((profile["network"] as? [String: Any])?["enabled"] as? Bool, false)
            XCTAssertEqual((profile["filesystem"] as? [String: Any])?[":root"] as? String, "deny")
        } catch let failure as AppServerTransportError {
            XCTAssertTrue(failure.message.contains("failed to resolve feature override precedence"), "Unexpected configuration failure: \(failure.localizedDescription)")
            XCTAssertTrue(failure.message.contains("does not set `default_permissions`"))
            XCTFail("Setup config/read must resolve an explicit process-local profile: \(failure.localizedDescription)")
        }
        XCTAssertEqual(try Data(contentsOf: configFile), original, "Setup must preserve the owner configuration bytes")
    }

    func testExecutionSetupErrorContextIdentifiesOperationAndKnownTarget() throws {
        let failure = "failed to resolve feature override precedence: configuration rejected"
        let root = "/fixture/project"
        let file = "/fixture/codex/config.toml"
        let cases: [(String, RPCObject?, Bool, String)] = [
            ("initialize", nil, false, "Execution setup initialize: " + failure),
            ("initialized", nil, false, "Execution setup initialized: " + failure),
            ("config/read", try RPCObject(["cwd": root]), false, "Execution setup config/read (cwd: \(root)): " + failure),
            ("config/batchWrite", try RPCObject(["filePath": file]), false, "Execution setup config/batchWrite (file: \(file)): " + failure),
            ("config/read", try RPCObject(["cwd": root]), true, "Execution setup config/read readback (cwd: \(root)): " + failure),
        ]
        for (method, parameters, readback, expected) in cases {
            for unknown in [false, true] {
                let error = AppServerTransportError(message: failure, outcomeUnknown: unknown)
                    .addingSetupContext(method: method, parameters: parameters, readback: readback)
                XCTAssertEqual(error.localizedDescription, expected)
                XCTAssertEqual(error.outcomeUnknown, unknown)
            }
        }
    }

    func testExecutionSetupErrorContextExcludesSensitivePayloadsAndUnknownTargets() throws {
        let secret = "sensitive-payload-must-not-appear"
        let parameters = try RPCObject([
            "filePath": "/fixture/codex/config.toml", "cwd": secret,
            "edits": [["value": secret]], "config": ["token": secret],
            "environment": ["HOME": secret], "prompt": secret, "hooks": ["command": secret],
        ])
        let error = AppServerTransportError(message: "Original failure", outcomeUnknown: true)
            .addingSetupContext(method: "config/batchWrite", parameters: parameters)
        XCTAssertEqual(error.message, "Execution setup config/batchWrite (file: /fixture/codex/config.toml): Original failure")
        XCTAssertFalse(error.message.contains(secret))
        let missing = AppServerTransportError(message: "Original failure", outcomeUnknown: false)
            .addingSetupContext(method: "config/read", parameters: try RPCObject(["config": ["cwd": secret]]))
        XCTAssertEqual(missing.message, "Execution setup config/read: Original failure")
        XCTAssertFalse(missing.message.contains(secret))
        for target in ["relative/config.toml", "/fixture/config.toml\n" + secret] {
            let invalid = AppServerTransportError(message: "Original failure", outcomeUnknown: true)
                .addingSetupContext(method: "config/batchWrite", parameters: try RPCObject(["filePath": target]))
            XCTAssertEqual(invalid.message, "Execution setup config/batchWrite: Original failure")
        }
    }

    func testSignedHostedAppCanInitializeRealTransportWithIsolatedHome() async throws {
        // Container fixture proves only this launch/protocol boundary, not access
        // to an external repository under a security-scoped bookmark.
        let home = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("codex"), withIntermediateDirectories: true)
        let project = home.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        var current: SecTask?
        current = SecTaskCreateFromSelf(nil)
        let sandbox = current.flatMap { SecTaskCopyValueForEntitlement($0, "com.apple.security.app-sandbox" as CFString, nil) }
        print("RR AppServer fixture host=\(Bundle.main.bundleURL.path) appSandbox=\(String(describing: sandbox)) executable=\(CodexExecutionIdentity.executable); container fixture only, no external bookmark proof")
        XCTAssertEqual(sandbox as? Bool, true, "A privileged XCTest runner is not sandbox evidence")
        let transport = try AppServerTransport(fixtureHome: home, onMessage: { _ in })
        defer {
            do { try transport.close() }
            catch { XCTFail("Real transport cleanup failed: \(error.localizedDescription)") }
        }
        print("RR AppServer fixture phase=initialize request")
        let initialized = try await transport.call("initialize", RPCObject(["clientInfo": ["name": "release-radar-fixture", "version": "1"], "capabilities": ["experimentalApi": true]]))
        XCTAssertFalse(try initialized.object().isEmpty)
        print("RR AppServer fixture phase=initialize replied")
        try transport.send(["method": "initialized"])
        print("RR AppServer fixture phase=hooks/list request")
        let hooks = try await transport.call("hooks/list", RPCObject(["cwds": [project.path]])).object()
        XCTAssertNotNil(hooks["data"] as? [[String: Any]])
    }
}
