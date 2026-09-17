import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionReadinessTests: XCTestCase {
    private func response(trust: String = "trusted", enabled: Bool = true, command: String = "\"/RR/runner\" --hook", source: String = "project", inline: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": [["cwd": "/Worker", "errors": [], "warnings": [], "hooks": [[
            "command": command, "handlerType": "command", "async": false, "source": source,
            "sourcePath": inline ? "/Primary/.codex/config.toml" : "/Primary/.codex/hooks.json", "eventName": "userPromptSubmit", "enabled": enabled,
            "trustStatus": trust, "key": "/Primary/.codex/hooks.json:user_prompt_submit:0:0", "currentHash": "verified-definition", "timeoutSec": 10,
        ]]]]])
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
