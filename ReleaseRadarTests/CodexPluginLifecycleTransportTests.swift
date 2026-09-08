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

    func testClientRebindsAStaleEnabledServiceBeforeInstalling() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 1, observedState: nil, error: .marketplaceConflict),
            .init(wireVersion: 1, observedState: .absent, error: nil),
            .init(
                wireVersion: 1,
                observedState: .clean(version: "0.1.7", digest: "shipped"),
                error: nil
            ),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.install()

        XCTAssertEqual(
            reply.observedState,
            .clean(version: "0.1.7", digest: "shipped")
        )
        XCTAssertNil(reply.error)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(remote.operations, [.status, .status, .install])
    }

    func testClientDoesNotInstallWhenConflictPersistsAfterOneRebind() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 1, observedState: nil, error: .marketplaceConflict),
            .init(wireVersion: 1, observedState: nil, error: .marketplaceConflict),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.install()

        XCTAssertEqual(reply.error, .marketplaceConflict)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(remote.operations, [.status, .status])
    }

    func testClientRebindsAnUnavailableEnabledServiceBeforeReportingStatus() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 1, observedState: nil, error: .codexUnavailable),
            .init(wireVersion: 1, observedState: .absent, error: nil),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.status()

        XCTAssertEqual(reply.observedState, .absent)
        XCTAssertNil(reply.error)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(remote.operations, [.status, .status])
    }

    func testRecoveryStatusIsReadOnlyAndNeverRegistersOrRebindsHelper() async {
        let disabledService = PluginLifecycleServiceStub(status: .notRegistered)
        let disabledRemote = PluginLifecycleRemoteStub(replies: [])
        let disabledClient = CodexPluginLifecycleClient(service: disabledService, invokeRemote: disabledRemote.invoke)

        let unavailable = await disabledClient.statusReadOnly()

        XCTAssertEqual(unavailable.error, .codexUnavailable)
        XCTAssertEqual(disabledService.registerCallCount, 0)
        XCTAssertEqual(disabledService.unregisterCallCount, 0)
        XCTAssertTrue(disabledRemote.operations.isEmpty)

        let enabledService = PluginLifecycleServiceStub(status: .enabled)
        let enabledRemote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 1, observedState: nil, error: .marketplaceConflict),
        ])
        let enabledClient = CodexPluginLifecycleClient(service: enabledService, invokeRemote: enabledRemote.invoke)

        let observed = await enabledClient.statusReadOnly()

        XCTAssertEqual(observed.error, .marketplaceConflict)
        XCTAssertEqual(enabledService.registerCallCount, 0)
        XCTAssertEqual(enabledService.unregisterCallCount, 0)
        XCTAssertEqual(enabledRemote.operations, [.status])
    }

    func testClientNeverRetriesAnInstallAfterAnUncertainMutationReply() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 1, observedState: .absent, error: nil),
            .init(wireVersion: 1, observedState: nil, error: .codexUnavailable),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.install()

        XCTAssertEqual(reply.error, .codexUnavailable)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(remote.operations, [.status, .install])
    }

    func testClientDoesNotRecoverOrInstallAfterAnUnsupportedStatusReply() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 2, observedState: nil, error: .marketplaceConflict),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.install()

        XCTAssertEqual(reply.error, .malformedResult)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(remote.operations, [.status])
    }

    func testClientDoesNotInstallAfterAStatusReplyWithoutObservedState() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(wireVersion: 1, observedState: nil, error: nil),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.install()

        XCTAssertEqual(reply.error, .malformedResult)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(remote.operations, [.status])
    }
}

private final class PluginLifecycleServiceStub: PluginLifecycleServiceManaging {
    var status: SMAppService.Status
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .notRegistered
    }
}

private final class PluginLifecycleRemoteStub: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [CodexPluginHelperReply]
    private(set) var operations: [CodexPluginLifecycleClient.Operation] = []

    init(replies: [CodexPluginHelperReply]) {
        self.replies = replies
    }

    func invoke(
        _ operation: CodexPluginLifecycleClient.Operation
    ) async -> CodexPluginHelperReply {
        lock.withLock {
            operations.append(operation)
            return replies.removeFirst()
        }
    }
}
