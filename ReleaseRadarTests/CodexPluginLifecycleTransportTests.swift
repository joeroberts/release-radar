import Foundation
import ServiceManagement
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class CodexPluginLifecycleTransportTests: XCTestCase {
    func testReplyEnvelopeIsVersionedBoundedAndPrivacySafe() throws {
        let reply = CodexPluginHelperReply(
            wireVersion: ReleaseRadarPluginLifecycleTransport.wireVersion,
            observedState: .clean(version: "0.1.0", digest: "abc"),
            error: nil
        )
        let encoded = try ReleaseRadarPluginLifecycleTransport.encode(reply)
        XCTAssertLessThanOrEqual(encoded.count, ReleaseRadarPluginLifecycleTransport.maximumReplyBytes)
        XCTAssertEqual(try ReleaseRadarPluginLifecycleTransport.decode(encoded), reply)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("/Users/"))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("stdout"))
    }

    func testXPCContractHasOnlyFourNoArgumentOperations() {
        let selectors = [
            #selector(ReleaseRadarPluginLifecycleXPC.status(withReply:)),
            #selector(ReleaseRadarPluginLifecycleXPC.install(withReply:)),
            #selector(ReleaseRadarPluginLifecycleXPC.remove(withReply:)),
            #selector(ReleaseRadarPluginLifecycleXPC.reinstall(withReply:)),
        ]
        XCTAssertEqual(Set(selectors.map(NSStringFromSelector)), Set([
            "statusWithReply:", "installWithReply:", "removeWithReply:", "reinstallWithReply:",
        ]))
    }

    func testPackagedLifecycleHelperCanRegisterFromSandboxedApp() throws {
        let service = SMAppService.agent(
            plistName: ReleaseRadarPluginLifecycleTransport.launchAgentPlistName
        )
        switch service.status {
        case .notRegistered, .notFound:
            break
        case .enabled:
            return
        case .requiresApproval:
            XCTFail("The packaged lifecycle helper requires approval")
            return
        @unknown default:
            XCTFail("Unexpected packaged lifecycle helper status: \(service.status)")
            return
        }

        try service.register()
        defer { try? service.unregister() }

        XCTAssertEqual(service.status, .enabled)
    }

    func testRecognizedDirectAndLegacyEntriesFailClosedOnNearMisses() {
        let exact = CodexMCPEntry(
            name: "release_radar",
            enabled: true,
            disabledReason: nil,
            command: ReleaseRadarPluginLifecycleTransport.packagedAgentToolsPath,
            arguments: [],
            environment: [:],
            workingDirectory: nil
        )
        XCTAssertTrue(ReleaseRadarPluginLifecycleTransport.isRecognizedDirectEntry(exact))
        XCTAssertTrue(ReleaseRadarPluginLifecycleTransport.isRecognizedLegacyEntry(
            CodexMCPEntry(
                name: "release-radar",
                enabled: true,
                disabledReason: nil,
                command: ReleaseRadarPluginLifecycleTransport.packagedAgentToolsPath,
                arguments: [],
                environment: [:],
                workingDirectory: nil
            )
        ))

        let nearMisses = [
            CodexMCPEntry(name: "release_radar", enabled: false, disabledReason: nil, command: exact.command, arguments: [], environment: [:], workingDirectory: nil),
            CodexMCPEntry(name: "release_radar", enabled: true, disabledReason: "disabled", command: exact.command, arguments: [], environment: [:], workingDirectory: nil),
            CodexMCPEntry(name: "release_radar", enabled: true, disabledReason: nil, command: "/tmp/tool", arguments: [], environment: [:], workingDirectory: nil),
            CodexMCPEntry(name: "release_radar", enabled: true, disabledReason: nil, command: exact.command, arguments: ["--extra"], environment: [:], workingDirectory: nil),
            CodexMCPEntry(name: "release_radar", enabled: true, disabledReason: nil, command: exact.command, arguments: [], environment: ["TOKEN": "value"], workingDirectory: nil),
            CodexMCPEntry(name: "release_radar", enabled: true, disabledReason: nil, command: exact.command, arguments: [], environment: [:], workingDirectory: "/tmp"),
        ]
        XCTAssertTrue(nearMisses.allSatisfy { !ReleaseRadarPluginLifecycleTransport.isRecognizedDirectEntry($0) })
    }

    func testPinnedAbsenceRequiresExactExitAndOutputTuple() {
        let stderr = "Error: No MCP server named 'release_radar' found.\n"
        XCTAssertTrue(ReleaseRadarPluginLifecycleTransport.isExactAbsence(
            name: "release_radar", exitStatus: 1, stdout: Data(), stderr: Data(stderr.utf8)
        ))
        XCTAssertFalse(ReleaseRadarPluginLifecycleTransport.isExactAbsence(
            name: "release_radar", exitStatus: 0, stdout: Data(), stderr: Data(stderr.utf8)
        ))
        XCTAssertFalse(ReleaseRadarPluginLifecycleTransport.isExactAbsence(
            name: "release_radar", exitStatus: 1, stdout: Data("x".utf8), stderr: Data(stderr.utf8)
        ))
        XCTAssertFalse(ReleaseRadarPluginLifecycleTransport.isExactAbsence(
            name: "release_radar", exitStatus: 1, stdout: Data(), stderr: Data(stderr.dropLast().utf8)
        ))
        XCTAssertFalse(ReleaseRadarPluginLifecycleTransport.isExactAbsence(
            name: "release_radar", exitStatus: 1, stdout: Data(), stderr: Data((stderr + "\n").utf8)
        ))
    }

    func testPackagedHelperUsesOneBoundedDelayedRecheckForMCPPropagation() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let helperURL = repositoryRoot.appendingPathComponent("ReleaseRadarPluginLifecycleHelper/main.swift")
        let source = try String(contentsOf: helperURL, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "    private func verifiedShippedState() throws -> HelperReply {"))
        let end = try XCTUnwrap(source.range(
            of: "    private func observeInstalled() throws -> ObservedState {",
            range: start.upperBound..<source.endIndex
        ))
        let implementation = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertEqual(implementation.components(separatedBy: "mcpState(name: \"release_radar\")").count - 1, 2)
        XCTAssertEqual(implementation.components(separatedBy: "usleep(250_000)").count - 1, 1)
        XCTAssertTrue(implementation.contains("guard initialMCPState == .absent else"))
        XCTAssertFalse(implementation.contains("while "))
        XCTAssertFalse(implementation.contains("for "))
    }

    func testClientPreservesKnownLifecycleErrorsFromRegistration() {
        XCTAssertEqual(
            CodexPluginLifecycleClient.failureReply(
                for: CodexPluginLifecycleError.unauthorizedPeer
            ).error,
            .unauthorizedPeer
        )
        XCTAssertEqual(
            CodexPluginLifecycleClient.failureReply(
                for: NSError(domain: "SMAppServiceErrorDomain", code: 1)
            ).error,
            .unauthorizedPeer
        )
        XCTAssertEqual(
            CodexPluginLifecycleClient.failureReply(
                for: NSError(domain: "test", code: 1)
            ).error,
            .codexUnavailable
        )
    }
}
