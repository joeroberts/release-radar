import Foundation
import Security
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionAppServerTests: XCTestCase {
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
