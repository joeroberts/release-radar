import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionHookTests: XCTestCase {
    private let command = "\"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator\" --hook"

    func testMergePreservesUnrelatedHooksAndRepeatedSetupIsIdempotent() throws {
        let initial = Data(#"{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"user-hook"}]}]},"other":true}"#.utf8)
        let first = try ProjectExecutionHookRegistration.merge(initial, command: command, previousCommand: nil)
        let second = try ProjectExecutionHookRegistration.merge(first, command: command, previousCommand: command)
        XCTAssertEqual(first, second)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: first) as? [String: Any])
        XCTAssertEqual(object["other"] as? Bool, true)
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let groups = try XCTUnwrap(hooks["UserPromptSubmit"] as? [[String: Any]])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual((groups[0]["hooks"] as? [[String: Any]])?[0]["command"] as? String, "user-hook")
    }

    func testModifiedOwnedHookOrExplicitDisablementIsNeverSilentlyReenabled() throws {
        let first = try ProjectExecutionHookRegistration.merge(nil, command: command, previousCommand: nil)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: first) as? [String: Any])
        var hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        var groups = try XCTUnwrap(hooks["UserPromptSubmit"] as? [[String: Any]])
        groups[0]["hooks"] = [["type": "command", "command": "changed-by-owner"]]
        hooks["UserPromptSubmit"] = groups; object["hooks"] = hooks
        let changed = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ProjectExecutionHookRegistration.merge(changed, command: command, previousCommand: command))
        XCTAssertThrowsError(try ProjectExecutionHookRegistration.merge(Data(#"{"hooks":{"UserPromptSubmit":[]}}"#.utf8), command: command, previousCommand: command))
    }

    func testRemovalOnlyRemovesExactOwnedDefinitionAndRejectsMalformedInput() throws {
        let first = try ProjectExecutionHookRegistration.merge(nil, command: command, previousCommand: nil)
        let removed = try ProjectExecutionHookRegistration.remove(first, previousCommand: command)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? [String: Any])
        XCTAssertEqual((object["hooks"] as? [String: Any])?["UserPromptSubmit"] as? [[String: String]], [])
        XCTAssertThrowsError(try ProjectExecutionHookRegistration.merge(Data("broken".utf8), command: command, previousCommand: nil))
    }
}
