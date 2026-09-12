import Darwin
import Foundation
import Security
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
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.asynchronousUnregisterCallCount, 1)
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
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.asynchronousUnregisterCallCount, 1)
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
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.asynchronousUnregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(remote.operations, [.status, .status])
    }

    func testClientExplicitRestartRecoversAStaleEnabledHelperWithoutPluginMutation() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        let unregisterStarted = expectation(description: "asynchronous helper teardown started")
        service.onAsynchronousUnregisterStarted = { unregisterStarted.fulfill() }
        service.holdsAsynchronousUnregisterCompletion = true
        let remote = PluginLifecycleRemoteStub(replies: [
            .init(
                wireVersion: 1,
                observedState: .needsRepair(.integrityInvalid),
                error: nil
            ),
            .init(
                wireVersion: 1,
                observedState: .clean(version: "0.1.9", digest: "current"),
                error: nil
            ),
        ])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let staleReply = await client.status()
        let restart = Task { await client.restartHelper() }

        await fulfillment(of: [unregisterStarted], timeout: 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.asynchronousUnregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(remote.operations, [.status])

        service.completeAsynchronousUnregister()
        let reply = await restart.value

        XCTAssertEqual(staleReply.observedState, .needsRepair(.integrityInvalid))
        XCTAssertNil(staleReply.error)
        XCTAssertEqual(
            reply.observedState,
            .clean(version: "0.1.9", digest: "current")
        )
        XCTAssertNil(reply.error)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.asynchronousUnregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(remote.operations, [.status, .status])
    }

    @MainActor
    func testSettingsRestartHandsOffAnIsolatedLegacyHelperProcessToTheCurrentHelper() async throws {
        let fixture = try IsolatedLifecycleFixture.make()
        defer { fixture.service.forceBootout() }
        print("ISOLATED_RESTART_HELPER_ROOT=\(fixture.root.path)")
        XCTAssertNotEqual(fixture.currentCDHash, fixture.legacyCDHash)

        let package = try CodexPluginPackage(rootURL: fixture.marketplaceRoot)
        let store = DeliveryStore(databaseURL: fixture.root.appendingPathComponent("store.sqlite"))
        let lifecycleStore = CodexPluginLifecycleStore(store: store)
        let client = CodexPluginLifecycleClient(
            service: fixture.service,
            machServiceName: fixture.machService,
            helperCodeSigningRequirement: "identifier \"com.rekonlabs.ReleaseRadarPluginLifecycleHelper\""
        )
        let coordinator = CodexPluginLifecycleCoordinator(
            manager: client,
            store: lifecycleStore,
            shippedVersion: package.version,
            shippedDigest: package.digest
        )
        let model = AppModel(
            store: store,
            codexPluginCoordinator: coordinator,
            codexPluginShippedVersion: package.version,
            externalServicesSuppressed: true
        )

        try fixture.service.bootstrap()
        await model.installCodexPlugin()
        XCTAssertEqual(
            model.codexPluginState,
            CodexPluginPresentationState.installed(version: package.version)
        )
        let installedReceipt = try await lifecycleStore.load()
        XCTAssertEqual(installedReceipt.intent, .managedInstalled)
        XCTAssertEqual(installedReceipt.managedVersion, package.version)
        XCTAssertEqual(installedReceipt.managedDigest, package.digest)

        client.unregister()
        XCTAssertEqual(fixture.service.status, .notRegistered)
        try fixture.service.bootstrap(executableURL: fixture.legacyHelperURL)
        await model.loadCodexPluginStatus()
        let legacyPID = try fixture.service.requirePID()
        XCTAssertEqual(try processCDHash(legacyPID), fixture.legacyCDHash)
        XCTAssertEqual(model.codexPluginState, CodexPluginPresentationState.needsRepair)
        let staleReceipt = try await lifecycleStore.load()
        XCTAssertEqual(staleReceipt.intent, CodexPluginIntent.attentionRequired)

        try fixture.service.prepareCurrentRegistration()
        await model.restartCodexPluginHelper()

        let currentPID = try fixture.service.requirePID()
        XCTAssertNotEqual(currentPID, legacyPID)
        XCTAssertEqual(kill(legacyPID, 0), -1)
        XCTAssertEqual(errno, ESRCH)
        XCTAssertEqual(try processExecutablePath(currentPID), fixture.currentHelperURL.path)
        XCTAssertEqual(try processCDHash(currentPID), fixture.currentCDHash)
        XCTAssertEqual(
            fixture.service.events,
            [.asynchronousUnregisterStarted(legacyPID), .oldProcessTerminated(legacyPID), .registerStarted]
        )
        XCTAssertEqual(
            model.codexPluginState,
            CodexPluginPresentationState.installed(version: package.version)
        )
        XCTAssertEqual(model.codexPluginSettingsMessage, "Lifecycle helper restarted. Plugin status refreshed.")
        XCTAssertNil(model.codexPluginOperation)
        let recoveredReceipt = try await lifecycleStore.load()
        XCTAssertEqual(recoveredReceipt, installedReceipt)

        let fresh = await client.statusReadOnly()
        XCTAssertEqual(fresh.error, nil)
        XCTAssertEqual(
            fresh.observedState,
            CodexPluginObservedState.clean(version: package.version, digest: package.digest)
        )
    }

    func testClientRestartSurfacesAsynchronousUnregisterFailureWithoutRegisterOrStatus() async {
        let service = PluginLifecycleServiceStub(status: .enabled)
        service.asynchronousUnregisterError = NSError(domain: "test", code: 1)
        let remote = PluginLifecycleRemoteStub(replies: [])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.restartHelper()

        XCTAssertEqual(reply.error, .codexUnavailable)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.asynchronousUnregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertTrue(remote.operations.isEmpty)
    }

    func testClientRestartSurfacesApprovalRequirementWithoutCallingHelper() async {
        let service = PluginLifecycleServiceStub(status: .requiresApproval)
        let remote = PluginLifecycleRemoteStub(replies: [])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.restartHelper()

        XCTAssertEqual(reply.error, .unauthorizedPeer)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertTrue(remote.operations.isEmpty)
    }

    func testClientRestartSurfacesRegistrationFailureWithoutCallingHelper() async {
        let service = PluginLifecycleServiceStub(status: .notRegistered)
        service.registerError = NSError(domain: "SMAppServiceErrorDomain", code: 1)
        let remote = PluginLifecycleRemoteStub(replies: [])
        let client = CodexPluginLifecycleClient(
            service: service,
            invokeRemote: remote.invoke
        )

        let reply = await client.restartHelper()

        XCTAssertEqual(reply.error, .unauthorizedPeer)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertTrue(remote.operations.isEmpty)
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
    var registerError: Error?
    var asynchronousUnregisterError: Error?
    var holdsAsynchronousUnregisterCompletion = false
    var onAsynchronousUnregisterStarted: (@Sendable () -> Void)?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var asynchronousUnregisterCallCount = 0
    private var pendingAsynchronousUnregister: (@Sendable (Error?) -> Void)?

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .notRegistered
    }

    func unregister(completionHandler handler: @Sendable @escaping (Error?) -> Void) {
        asynchronousUnregisterCallCount += 1
        onAsynchronousUnregisterStarted?()
        if holdsAsynchronousUnregisterCompletion {
            pendingAsynchronousUnregister = handler
            return
        }
        finishAsynchronousUnregister(handler)
    }

    func completeAsynchronousUnregister() {
        guard let handler = pendingAsynchronousUnregister else { return }
        pendingAsynchronousUnregister = nil
        finishAsynchronousUnregister(handler)
    }

    private func finishAsynchronousUnregister(_ handler: @Sendable (Error?) -> Void) {
        let error = asynchronousUnregisterError
        if error == nil { status = .notRegistered }
        handler(error)
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

private struct IsolatedLifecycleFixture {
    let root: URL
    let marketplaceRoot: URL
    let currentHelperURL: URL
    let legacyHelperURL: URL
    let currentCDHash: Data
    let legacyCDHash: Data
    let machService: String
    let service: IsolatedLifecycleLaunchdService

    static func make() throws -> Self {
        let identifier = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReleaseRadar-IsolatedHelper-\(identifier)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("release-radar-isolated-helper-current", isDirectory: true)
            .resolvingSymlinksInPath()
        let currentHelperURL = fixtureRoot.appendingPathComponent(
            "Current.app/Contents/Resources/ReleaseRadarPluginLifecycleHelper"
        )
        let legacyHelperURL = fixtureRoot.appendingPathComponent(
            "Legacy.app/Contents/Resources/ReleaseRadarPluginLifecycleHelper"
        )
        let activeHelperURL = fixtureRoot.appendingPathComponent(
            "Active.app/Contents/Resources/ReleaseRadarPluginLifecycleHelper"
        )
        let currentMarketplaceURL = currentHelperURL.deletingLastPathComponent()
            .appendingPathComponent("CodexPluginMarketplace", isDirectory: true)
        let legacyMarketplaceURL = legacyHelperURL.deletingLastPathComponent()
            .appendingPathComponent("CodexPluginMarketplace", isDirectory: true)
        let activeMarketplaceURL = activeHelperURL.deletingLastPathComponent()
            .appendingPathComponent("CodexPluginMarketplace", isDirectory: true)
        guard FileManager.default.fileExists(atPath: fixtureRoot.path)
        else { throw XCTSkip("Run script/test_isolated_helper_restart.sh to exercise the real helper handoff") }
        let marketplaceRoot = currentMarketplaceURL
        guard FileManager.default.isExecutableFile(atPath: currentHelperURL.path),
              FileManager.default.isExecutableFile(atPath: legacyHelperURL.path),
              FileManager.default.fileExists(atPath: currentMarketplaceURL.path),
              FileManager.default.fileExists(atPath: legacyMarketplaceURL.path),
              FileManager.default.fileExists(atPath: activeMarketplaceURL.path)
        else { throw IsolatedLifecycleTestError("The isolated helper fixture is incomplete") }

        let machService = "2UA854NLX4.com.rekonlabs.ReleaseRadar.isolated-restart-test"
        let service = IsolatedLifecycleLaunchdService(
            label: "com.rekonlabs.ReleaseRadar.IsolatedLifecycleHelper.test",
            currentExecutableURL: currentHelperURL,
            activeExecutableURL: activeHelperURL,
            currentMarketplaceURL: currentMarketplaceURL,
            legacyMarketplaceURL: legacyMarketplaceURL,
            activeMarketplaceURL: activeMarketplaceURL,
            shutdownFileURL: fixtureRoot.appendingPathComponent("shutdown")
        )
        guard service.isJobLoaded else {
            throw XCTSkip("Run script/test_isolated_helper_restart.sh to exercise the real helper handoff")
        }
        return .init(
            root: root,
            marketplaceRoot: marketplaceRoot,
            currentHelperURL: currentHelperURL,
            legacyHelperURL: legacyHelperURL,
            currentCDHash: try staticCDHash(currentHelperURL),
            legacyCDHash: try staticCDHash(legacyHelperURL),
            machService: machService,
            service: service
        )
    }
}

private final class IsolatedLifecycleLaunchdService: PluginLifecycleServiceManaging, @unchecked Sendable {
    enum Event: Equatable {
        case asynchronousUnregisterStarted(pid_t)
        case oldProcessTerminated(pid_t)
        case registerStarted
    }

    private let label: String
    private let currentExecutableURL: URL
    private let activeExecutableURL: URL
    private let currentMarketplaceURL: URL
    private let legacyMarketplaceURL: URL
    private let activeMarketplaceURL: URL
    private let shutdownFileURL: URL
    private let domain = "gui/\(geteuid())"
    private let lock = NSLock()
    private var recordedEvents: [Event] = []
    private var isRegistered = true

    init(
        label: String,
        currentExecutableURL: URL,
        activeExecutableURL: URL,
        currentMarketplaceURL: URL,
        legacyMarketplaceURL: URL,
        activeMarketplaceURL: URL,
        shutdownFileURL: URL
    ) {
        self.label = label
        self.currentExecutableURL = currentExecutableURL
        self.activeExecutableURL = activeExecutableURL
        self.currentMarketplaceURL = currentMarketplaceURL
        self.legacyMarketplaceURL = legacyMarketplaceURL
        self.activeMarketplaceURL = activeMarketplaceURL
        self.shutdownFileURL = shutdownFileURL
    }

    var isJobLoaded: Bool { (try? jobDescription()) != nil }

    var status: SMAppService.Status {
        lock.withLock { isRegistered ? .enabled : .notRegistered }
    }

    var events: [Event] {
        lock.withLock { recordedEvents }
    }

    func bootstrap() throws {
        try selectExecutable(currentExecutableURL, marketplaceURL: currentMarketplaceURL)
        try kickstart()
        lock.withLock { isRegistered = true }
    }

    func bootstrap(executableURL: URL) throws {
        let marketplaceURL = executableURL == currentExecutableURL
            ? currentMarketplaceURL
            : legacyMarketplaceURL
        try selectExecutable(executableURL, marketplaceURL: marketplaceURL)
        try kickstart()
        lock.withLock { isRegistered = true }
    }

    func prepareCurrentRegistration() throws {
        try selectExecutable(currentExecutableURL, marketplaceURL: currentMarketplaceURL)
    }

    func register() throws {
        lock.withLock { recordedEvents.append(.registerStarted) }
        try clearShutdownRequest()
        try kickstart()
        lock.withLock { isRegistered = true }
    }

    func unregister() throws {
        let priorPID = try? currentPID()
        if priorPID != nil { try requestShutdown() }
        if let priorPID { try waitForTermination(priorPID) }
        lock.withLock { isRegistered = false }
    }

    func unregister(completionHandler handler: @Sendable @escaping (Error?) -> Void) {
        let priorPID = try? currentPID()
        if let priorPID {
            lock.withLock { recordedEvents.append(.asynchronousUnregisterStarted(priorPID)) }
        }
        DispatchQueue.global().async { [self] in
            do {
                if priorPID != nil { try requestShutdown() }
                if let priorPID {
                    try waitForTermination(priorPID)
                    lock.withLock { recordedEvents.append(.oldProcessTerminated(priorPID)) }
                }
                lock.withLock { isRegistered = false }
                handler(nil)
            } catch {
                handler(error)
            }
        }
    }

    func forceBootout() {
        _ = FileManager.default.createFile(atPath: shutdownFileURL.path, contents: Data())
    }

    func requirePID() throws -> pid_t {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if let pid = try? currentPID() { return pid }
            usleep(20_000)
        } while Date() < deadline
        throw IsolatedLifecycleTestError("Isolated launchd helper did not start")
    }

    private func currentPID() throws -> pid_t {
        let description = try jobDescription()
        let expression = try NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)$"#)
        let range = NSRange(description.startIndex..<description.endIndex, in: description)
        guard let match = expression.firstMatch(in: description, range: range),
              let pidRange = Range(match.range(at: 1), in: description),
              let pid = pid_t(description[pidRange])
        else { throw IsolatedLifecycleTestError("Isolated launchd helper has no running PID") }
        return pid
    }

    private func selectExecutable(_ executableURL: URL, marketplaceURL: URL) throws {
        try clearShutdownRequest()
        try FileManager.default.removeItem(at: activeExecutableURL)
        try FileManager.default.createSymbolicLink(
            at: activeExecutableURL,
            withDestinationURL: executableURL
        )
        try FileManager.default.removeItem(at: activeMarketplaceURL)
        try FileManager.default.copyItem(at: marketplaceURL, to: activeMarketplaceURL)
    }

    private func kickstart() throws {
        _ = try Self.runLaunchctl(["kickstart", "\(domain)/\(label)"])
    }

    private func requestShutdown() throws {
        guard FileManager.default.createFile(atPath: shutdownFileURL.path, contents: Data()) else {
            throw IsolatedLifecycleTestError("Could not request isolated helper shutdown")
        }
    }

    private func clearShutdownRequest() throws {
        if FileManager.default.fileExists(atPath: shutdownFileURL.path) {
            try FileManager.default.removeItem(at: shutdownFileURL)
        }
    }

    private func jobDescription() throws -> String {
        try Self.runLaunchctl(["print", "\(domain)/\(label)"])
    }

    private func waitForTermination(_ pid: pid_t) throws {
        let deadline = Date().addingTimeInterval(5)
        while kill(pid, 0) == 0 || errno == EPERM {
            guard Date() < deadline else {
                throw IsolatedLifecycleTestError("Old isolated helper PID \(pid) did not terminate")
            }
            usleep(20_000)
        }
        guard errno == ESRCH else {
            throw IsolatedLifecycleTestError("Could not verify termination of isolated helper PID \(pid)")
        }
    }

    private static func runLaunchctl(_ arguments: [String]) throws -> String {
        try runProcess("/bin/launchctl", arguments)
    }
}

private struct IsolatedLifecycleTestError: LocalizedError {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

@discardableResult
private func runProcess(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    let output = stdout.fileHandleForReading.readDataToEndOfFile()
    let error = stderr.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
        throw IsolatedLifecycleTestError(
            "\(executable) \(arguments.joined(separator: " ")) failed (\(process.terminationStatus)): "
                + String(decoding: error, as: UTF8.self)
        )
    }
    return String(decoding: output, as: UTF8.self)
}

private func staticCDHash(_ executable: URL) throws -> Data {
    var code: SecStaticCode?
    var information: CFDictionary?
    guard SecStaticCodeCreateWithPath(executable as CFURL, [], &code) == errSecSuccess,
          let code,
          SecCodeCopySigningInformation(code, [], &information) == errSecSuccess,
          let values = information as? [String: Any],
          let hash = values[kSecCodeInfoUnique as String] as? Data
    else { throw IsolatedLifecycleTestError("Could not read static code identity for \(executable.path)") }
    return hash
}

private func processCDHash(_ pid: pid_t) throws -> Data {
    var code: SecCode?
    var staticCode: SecStaticCode?
    var information: CFDictionary?
    let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
    guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
          let code,
          SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
          let staticCode,
          SecCodeCopySigningInformation(staticCode, [], &information) == errSecSuccess,
          let values = information as? [String: Any],
          let hash = values[kSecCodeInfoUnique as String] as? Data
    else { throw IsolatedLifecycleTestError("Could not read dynamic code identity for PID \(pid)") }
    return hash
}

private func processExecutablePath(_ pid: pid_t) throws -> String {
    var code: SecCode?
    var staticCode: SecStaticCode?
    var path: CFURL?
    let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
    guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
          let code,
          SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
          let staticCode,
          SecCodeCopyPath(staticCode, [], &path) == errSecSuccess,
          let path
    else { throw IsolatedLifecycleTestError("Could not resolve executable path for PID \(pid)") }
    return (path as URL).path
}
