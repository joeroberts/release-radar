import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionPackageTests: XCTestCase {
    private func fixture() throws -> URL {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/CodexPluginLifecycle/v2")
        let target = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: target)
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let skill = repository.appendingPathComponent("ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/shared-execution/SKILL.md")
        let destination = target.appendingPathComponent("plugins/release-radar/skills/shared-execution/SKILL.md")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: skill, to: destination)
        try writeMCP(root: target, coordinator: ["command": "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator", "args": ["--mcp"]])
        return target
    }
    private func writeMCP(root: URL, coordinator: [String: Any], extraServer: Bool = false) throws {
        var servers: [String: Any] = [
            "release_radar": ["command": "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools", "args": []],
            "coordinator_workers": coordinator,
        ]
        if extraServer { servers["other"] = ["command": "/tmp/other", "args": []] }
        try JSONSerialization.data(withJSONObject: servers, options: [.sortedKeys]).write(to: root.appendingPathComponent("plugins/release-radar/.mcp.json"))
    }
    func testOneManagedPackageRecognizesBothFixedServersWithMatchingDigest() throws {
        let root = try fixture()
        let package = try CodexPluginPackage(rootURL: root)
        XCTAssertEqual(package.relativeFiles.count, 4)
        XCTAssertEqual(package.digest, try PluginDigester.marketplacePackage(at: root).digest)
    }
    func testCoordinatorNearMissesAndThirdServerFailClosed() throws {
        let root = try fixture()
        let coordinators: [[String: Any]] = [
            ["command": "/tmp/runner", "args": ["--mcp"]],
            ["command": "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator", "args": ["--hook"]],
            ["command": "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator", "args": ["--mcp"], "env": ["OVERRIDE": "value"]],
        ]
        for coordinator in coordinators {
            try writeMCP(root: root, coordinator: coordinator)
            XCTAssertThrowsError(try CodexPluginPackage(rootURL: root))
            XCTAssertThrowsError(try PluginDigester.marketplacePackage(at: root))
        }
        try writeMCP(root: root, coordinator: ["command": "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator", "args": ["--mcp"]], extraServer: true)
        XCTAssertThrowsError(try CodexPluginPackage(rootURL: root))
        XCTAssertThrowsError(try PluginDigester.marketplacePackage(at: root))
    }
}
