import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionReadinessTests: XCTestCase {
    private func response(trust: String = "trusted", enabled: Bool = true, command: String = "\"/RR/runner\" --hook", source: String = "project", inline: Bool = false,
                          cwd: String = "/Worker", primaryRoot: String = "/Primary", key: String = "/Primary/.codex/hooks.json:user_prompt_submit:0:0", hash: String = "verified-definition") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": [["cwd": cwd, "errors": [], "warnings": [], "hooks": [[
            "command": command, "handlerType": "command", "async": false, "source": source,
            "sourcePath": primaryRoot + (inline ? "/.codex/config.toml" : "/.codex/hooks.json"), "eventName": "userPromptSubmit", "enabled": enabled,
            "trustStatus": trust, "key": key, "currentHash": hash, "timeoutSec": 10,
        ]]]]])
    }
    func testCanonicalPrimaryAndLinkedDiscoveryRequireExactCwdAndCanonicalSource() throws {
        let alias = "/var/fixture", canonical = "/private/var/fixture", linked = "/Worker"
        let key = canonical + "/.codex/hooks.json:user_prompt_submit:0:0"
        for cwd in [canonical, linked] {
            let data = try response(trust: "untrusted", cwd: cwd, primaryRoot: canonical, key: key)
            let owned = try ProjectExecutionHookReadiness.resolve(data, checkout: cwd, primaryRoot: canonical,
                command: "\"/RR/runner\" --hook", requireTrusted: false)
            XCTAssertEqual(owned.key, key)
            XCTAssertEqual((owned.trustEdit["value"] as? [String: [String: String]])?[key]?["trusted_hash"], "verified-definition")
            XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(data, checkout: alias, primaryRoot: canonical,
                command: "\"/RR/runner\" --hook", requireTrusted: false))
            XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(
                response(cwd: cwd, primaryRoot: alias, key: key), checkout: cwd, primaryRoot: canonical,
                command: "\"/RR/runner\" --hook", requireTrusted: false))
            XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(data, checkout: cwd, primaryRoot: canonical,
                command: "\"/RR/runner\" --hook", requireTrusted: true), "Read-only verification cannot trust the canonical definition")
        }
    }

    func testCanonicalInlineSourceIsExactAndStorageKindsCannotSubstitute() throws {
        let canonical = "/private/var/fixture"
        let data = try response(inline: true, cwd: canonical, primaryRoot: canonical)
        _ = try ProjectExecutionHookReadiness.resolve(data, checkout: canonical, primaryRoot: canonical,
            command: "\"/RR/runner\" --hook", requireTrusted: true, inline: true)
        XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(data, checkout: canonical, primaryRoot: canonical,
            command: "\"/RR/runner\" --hook", requireTrusted: true))
        XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(data, checkout: canonical, primaryRoot: "/var/fixture",
            command: "\"/RR/runner\" --hook", requireTrusted: true, inline: true))
    }

    func testTrustedReadbackRequiresTheDiscoveredCanonicalKeyAndActualHash() throws {
        let canonical = "/private/var/fixture", key = "/private/var/fixture/.codex/hooks.json:user_prompt_submit:0:0"
        func resolve(trust: String, key: String, hash: String) throws -> ProjectExecutionHookReadiness {
            try ProjectExecutionHookReadiness.resolve(response(trust: trust, primaryRoot: canonical, key: key, hash: hash),
                checkout: "/Worker", primaryRoot: canonical, command: "\"/RR/runner\" --hook", requireTrusted: false)
        }
        let owned = try resolve(trust: "untrusted", key: key, hash: "actual-definition")
        try owned.verifyTrustedReadback(resolve(trust: "trusted", key: key, hash: "actual-definition"))
        for observed in [try resolve(trust: "untrusted", key: key, hash: "actual-definition"),
                         try resolve(trust: "trusted", key: "/var/fixture/.codex/hooks.json:user_prompt_submit:0:0", hash: "actual-definition"),
                         try resolve(trust: "trusted", key: key, hash: "changed-definition")] {
            XCTAssertThrowsError(try owned.verifyTrustedReadback(observed)) {
                XCTAssertEqual($0 as? ProjectExecutionError, .hookNotReady)
            }
        }
    }
    func testInlineReadinessRequiresTheOwnedStorageKind() throws {
        XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(response(inline: true), checkout: "/Worker", primaryRoot: "/Primary", command: "\"/RR/runner\" --hook", requireTrusted: true))
        _ = try ProjectExecutionHookReadiness.resolve(response(inline: true), checkout: "/Worker", primaryRoot: "/Primary", command: "\"/RR/runner\" --hook", requireTrusted: true, inline: true)
        XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(response(), checkout: "/Worker", primaryRoot: "/Primary", command: "\"/RR/runner\" --hook", requireTrusted: true, inline: true))
    }
    func testExactInstalledSchemaReadinessAndTrustMutationScope() throws {
        let value = try ProjectExecutionHookReadiness.resolve(response(), checkout: "/Worker", primaryRoot: "/Primary", command: "\"/RR/runner\" --hook", requireTrusted: true)
        XCTAssertEqual(value.key, "/Primary/.codex/hooks.json:user_prompt_submit:0:0")
        let edit = value.trustEdit
        XCTAssertEqual(edit["keyPath"] as? String, "hooks.state")
        XCTAssertEqual((edit["value"] as? [String: [String: String]])?.count, 1)
    }
    func testDisabledModifiedWrongCommandOrSourceNeverAuthorizesLaunchOrTrust() throws {
        for data in [try response(trust: "modified"), try response(enabled: false), try response(command: "unrelated"), try response(source: "plugin")] {
            XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(data, checkout: "/Worker", primaryRoot: "/Primary", command: "\"/RR/runner\" --hook", requireTrusted: true))
        }
        XCTAssertThrowsError(try ProjectExecutionHookReadiness.resolve(Data(#"{"hooks":[]}"#.utf8), checkout: "/Worker", primaryRoot: "/Primary", command: "\"/RR/runner\" --hook", requireTrusted: true))
    }
}
