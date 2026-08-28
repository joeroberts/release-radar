import AppKit
import CryptoKit
import Darwin
import Foundation
import Security

enum ProbeOperation: String, Codable {
    case status
    case install
    case remove
    case reinstall
}

struct ProbeResult: Codable {
    let cliVersion: String
    let operation: ProbeOperation
    let exitStatus: Int32
    let stdout: Data
    let stderr: Data
    let elapsedMilliseconds: Int
}

struct ProbeFailure: Error, Equatable {
    enum Kind: String, Codable, Equatable {
        case unavailable
        case untrusted
        case timeout
        case outputOverflow
        case malformedJSON
        case conflict
        case postcondition
    }

    let kind: Kind
}

private struct BooleanDocument: Decodable, Equatable {
    let ok: Bool
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private struct SelfTestContext {
    let runtimeRoot: URL
    let root: URL
    let fixtureRoot: URL
    let cliURL: URL
    let executableURL: URL

    init(runtimeRoot: URL, fixtureRoot: URL, cliURL: URL) throws {
        let manager = FileManager.default
        let root = runtimeRoot.appendingPathComponent("self-test-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: false)
        self.runtimeRoot = runtimeRoot.standardizedFileURL
        self.root = root.standardizedFileURL
        self.fixtureRoot = fixtureRoot.standardizedFileURL
        self.cliURL = cliURL.standardizedFileURL
        self.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    }

    func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    func workingDirectory(_ name: String) throws -> URL {
        try directory("cwd-\(name)-\(UUID().uuidString)")
    }

    var fixedEnvironment: [String: String] {
        [
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        ]
    }
}

private enum SelfTests {
    static func run(context: SelfTestContext) -> Int32 {
        let cases: [(String, () throws -> Void)] = [
            ("strict-json", { try strictJSON(context: context) }),
            ("path-confinement", { try pathConfinement(context: context) }),
            ("marketplace-manifest-layout", { try marketplaceManifestLayout(context: context) }),
            ("marketplace-preflight", { try marketplacePreflight(context: context) }),
            ("empty-plugin-status", { try emptyPluginStatus() }),
            ("exact-mutation-shapes", { try exactMutationShapes(context: context) }),
            ("controller-operation-modes", { try controllerOperationModes(context: context) }),
            ("primary-lifecycle-failure-cleanup", { try primaryLifecycleFailureCleanup(context: context) }),
            ("controller-argument-boundary", { try controllerArgumentBoundary(context: context) }),
            ("reinstall-transaction-controller", { try reinstallTransactionController(context: context) }),
            ("cli-version-output", { try cliVersionOutput() }),
            ("package-digest", { try packageDigest(context: context) }),
            ("installed-integrity-home-version", { try installedIntegrityHomeAndVersion(context: context) }),
            ("installed-integrity-clean", { try installedIntegrityClean(context: context) }),
            ("installed-integrity-modified", { try installedIntegrityModified(context: context) }),
            ("installed-integrity-malformed", { try installedIntegrityMalformed(context: context) }),
            ("installed-integrity-entry-types", { try installedIntegrityEntryTypes(context: context) }),
            ("installed-integrity-resource-bounds", { try installedIntegrityResourceBounds(context: context) }),
            ("installed-integrity-unknown", { try installedIntegrityUnknown(context: context) }),
            ("installed-integrity-races", { try installedIntegrityRaces(context: context) }),
            ("installed-integrity-access-boundary", { try installedIntegrityAccessBoundary(context: context) }),
            ("installed-integrity-path-free-output", { try installedIntegrityPathFreeOutput(context: context) }),
            ("installed-integrity-controller", { try installedIntegrityController(context: context) }),
            ("executable-identity", { try executableIdentity(context: context) }),
            ("fixed-operation-boundary", { try fixedOperationBoundary(context: context) }),
            ("legacy-mcp-recognition", { try legacyMCPRecognition() }),
            ("legacy-mcp-known-optional-fields", { try legacyMCPKnownOptionalFields() }),
            ("legacy-mcp-absence-contract", { try legacyMCPAbsenceContract() }),
            ("bundled-mcp-absence-controller", { try bundledMCPAbsenceController() }),
            ("legacy-mcp-fixed-controller", { try legacyMCPFixedController(context: context) }),
            ("legacy-mcp-failure-restoration", { try legacyMCPFailureRestoration() }),
            ("legacy-mcp-post-remove-observation", { try legacyMCPPostRemoveObservation() }),
            ("fixture-root-confinement", { try fixtureRootConfinement(context: context) }),
            ("step7-controller-boundary", { try step7ControllerBoundary(context: context) }),
            ("step7-build-plan", { try step7BuildPlan(context: context) }),
            ("step7-derived-fixture", { try step7DerivedFixture(context: context) }),
            ("step7-bridge-preflight-reduction", { try step7BridgePreflightReduction() }),
            ("step7-owned-cli-cancellation-plan", { try step7OwnedCLICancellationPlan() }),
            ("step7-expectations-and-report", { try step7ExpectationsAndReport(context: context) }),
            ("timeout", { try timeout(context: context) }),
            ("output-overflow", { try outputOverflow(context: context) }),
            ("buffered-exit-overflow", { try bufferedExitOverflow(context: context) }),
            ("pipe-read-error", { try pipeReadError() }),
            ("whole-process-group-termination", { try processGroupTermination(context: context) }),
            ("descendant-reaping", { try descendantReaping(context: context) }),
        ]

        var failures = 0
        for (name, body) in cases {
            do {
                try body()
                print("PASS \(name)")
            } catch {
                failures += 1
                print("FAIL \(name): \(error)")
            }
        }
        print("SELF-TEST \(failures == 0 ? "PASS" : "FAIL") \(cases.count - failures)/\(cases.count)")
        return failures == 0 ? 0 : 1
    }

    private static func strictJSON(context: SelfTestContext) throws {
        let directory = try context.directory("json")
        let valid = directory.appendingPathComponent("valid.json")
        let malformed = directory.appendingPathComponent("malformed.json")
        let multiple = directory.appendingPathComponent("multiple.json")
        let unknown = directory.appendingPathComponent("unknown.json")
        let nonUTF8 = directory.appendingPathComponent("non-utf8.json")
        try Data(#"{"ok":true}"#.utf8).write(to: valid)
        try Data(#"{"ok":"#.utf8).write(to: malformed)
        try Data("{\"ok\":true}\n{\"ok\":false}".utf8).write(to: multiple)
        try Data(#"{"ok":true,"extra":1}"#.utf8).write(to: unknown)
        try Data([0x7b, 0x22, 0x6f, 0x6b, 0x22, 0x3a, 0xff, 0x7d]).write(to: nonUTF8)

        let decoded: BooleanDocument = try decodeStrictJSONObject(
            Data(contentsOf: valid),
            allowedKeys: ["ok"]
        )
        try require(decoded == BooleanDocument(ok: true), "valid JSON decoded incorrectly")
        try expectFailure(.malformedJSON) {
            let _: BooleanDocument = try decodeStrictJSONObject(Data(contentsOf: malformed), allowedKeys: ["ok"])
        }
        try expectFailure(.malformedJSON) {
            let _: BooleanDocument = try decodeStrictJSONObject(Data(contentsOf: multiple), allowedKeys: ["ok"])
        }
        try expectFailure(.malformedJSON) {
            let _: BooleanDocument = try decodeStrictJSONObject(Data(contentsOf: unknown), allowedKeys: ["ok"])
        }
        try expectFailure(.malformedJSON) {
            let _: BooleanDocument = try decodeStrictJSONObject(Data(contentsOf: nonUTF8), allowedKeys: ["ok"])
        }
    }

    private static func pathConfinement(context: SelfTestContext) throws {
        let allowedRoot = try context.directory("allowed-root")
        let confined = allowedRoot.appendingPathComponent("nested/item")
        try FileManager.default.createDirectory(at: confined, withIntermediateDirectories: true)
        let escapeTarget = context.root.appendingPathComponent("escape-target")
        try FileManager.default.createDirectory(at: escapeTarget, withIntermediateDirectories: false)
        let escaping = allowedRoot.appendingPathComponent("../escape-target")

        let accepted = try requireConfinedPath(confined, allowedRoots: [allowedRoot])
        let expectedConfined = try canonicalExistingURL(confined)
        try require(accepted.path == expectedConfined.path, "confined path changed")
        try expectFailure(.untrusted) {
            _ = try requireConfinedPath(escaping, allowedRoots: [allowedRoot])
        }
    }

    private static func marketplaceManifestLayout(context: SelfTestContext) throws {
        let manifest = try supportedMarketplaceManifestURL(in: context.fixtureRoot)
        let expected = context.fixtureRoot
            .appendingPathComponent(".agents/plugins/marketplace.json")
            .standardizedFileURL
        try require(manifest == expected, "marketplace manifest did not use the supported nested path")

        for fixtureRoot in [
            context.fixtureRoot,
            context.fixtureRoot.deletingLastPathComponent().appendingPathComponent(
                "v2",
                isDirectory: true
            ),
        ] {
            let mcpURL = fixtureRoot.appendingPathComponent(
                "plugins/release-radar/.mcp.json"
            )
            let object = try required(
                try strictJSONValue(Data(contentsOf: mcpURL)) as? [String: Any],
                "canonical MCP manifest was not an object"
            )
            try require(
                Set(object.keys) == ["release_radar"],
                "canonical MCP machine key was not release_radar"
            )
        }
    }

    private static func marketplacePreflight(context: SelfTestContext) throws {
        let absent = Data(#"{"marketplaces":[{"marketplaceSource":{"z":2,"a":[3,1]},"root":"/unrelated","name":"alpha"},{"root":"/another","name":"beta"}]}"#.utf8)
        let reordered = Data(#"{"marketplaces":[{"name":"beta","root":"/another"},{"name":"alpha","root":"/unrelated","marketplaceSource":{"a":[3,1],"z":2}}]}"#.utf8)
        let nestedOrderChanged = Data(#"{"marketplaces":[{"name":"beta","root":"/another"},{"name":"alpha","root":"/unrelated","marketplaceSource":{"a":[1,3],"z":2}}]}"#.utf8)
        let first = try parseMarketplaceSnapshot(absent)
        let second = try parseMarketplaceSnapshot(reordered)
        let changed = try parseMarketplaceSnapshot(nestedOrderChanged)
        try require(first.targetRoot == nil, "absent target was reported present")
        try require(second.unrelatedFingerprint == first.unrelatedFingerprint, "fingerprint depended on top-level marketplace order")
        try require(changed.unrelatedFingerprint != first.unrelatedFingerprint, "fingerprint erased unknown nested array order")
        try requireAbsentTarget(first)

        let present = marketplaceListJSON(root: context.fixtureRoot.path, unrelatedRoot: nil)
        let presentSnapshot = try parseMarketplaceSnapshot(
            present,
            expectedTargetRoot: context.fixtureRoot.path
        )
        try require(presentSnapshot.targetRoot == context.fixtureRoot.path, "target root was not classified")
        try expectFailure(.conflict) { try requireAbsentTarget(presentSnapshot) }

        let duplicate = Data(#"{"marketplaces":[{"name":"release-radar","root":"/one","marketplaceSource":{"sourceType":"local","source":"/one"}},{"name":"release-radar","root":"/two","marketplaceSource":{"sourceType":"local","source":"/two"}}]}"#.utf8)
        try expectFailure(.conflict) { _ = try parseMarketplaceSnapshot(duplicate) }
        let unknownEnvelope = Data(#"{"marketplaces":[],"extra":true}"#.utf8)
        try expectFailure(.malformedJSON) { _ = try parseMarketplaceSnapshot(unknownEnvelope) }
        let targetWithoutRoot = Data(#"{"marketplaces":[{"name":"release-radar"}]}"#.utf8)
        try expectFailure(.malformedJSON) { _ = try parseMarketplaceSnapshot(targetWithoutRoot) }
    }

    private static func emptyPluginStatus() throws {
        let empty = Data(#"{"installed":[],"available":[]}"#.utf8)
        let observation = try parsePluginList(
            empty,
            expectedRoot: "/fixture",
            expectedVersion: "1.0.0"
        )
        try require(observation == .absent, "empty targeted plugin list was not accepted")
        let installedUnknownShape = Data(#"{"installed":[{"name":"release-radar"}],"available":[]}"#.utf8)
        try expectFailure(.malformedJSON) {
            _ = try parsePluginList(
                installedUnknownShape,
                expectedRoot: "/fixture",
                expectedVersion: "1.0.0"
            )
        }
        let unknownEnvelope = Data(#"{"installed":[],"available":[],"extra":[]}"#.utf8)
        try expectFailure(.malformedJSON) {
            _ = try parsePluginList(
                unknownEnvelope,
                expectedRoot: "/fixture",
                expectedVersion: "1.0.0"
            )
        }
    }

    private static func exactMutationShapes(context: SelfTestContext) throws {
        let root = context.fixtureRoot.path
        try parseMarketplaceAddResponse(marketplaceAddJSON(root: root), expectedRoot: root)
        try parsePluginAddResponse(pluginAddJSON(version: "1.0.0"), expectedVersion: "1.0.0")
        try parsePluginRemoveResponse(pluginRemoveJSON())
        try parseMarketplaceRemoveResponse(marketplaceRemoveJSON())

        try expectFailure(.malformedJSON) {
            try parseMarketplaceAddResponse(
                Data("{\"marketplaceName\":\"release-radar\",\"installedRoot\":\"\(root)\",\"alreadyAdded\":false,\"extra\":true}".utf8),
                expectedRoot: root
            )
        }
        try expectFailure(.malformedJSON) {
            try parsePluginAddResponse(
                Data(#"{"pluginId":"release-radar@release-radar","name":"release-radar","marketplaceName":"release-radar","version":"1.0.0","installedPath":"/Users/test/.codex/plugins/cache/release-radar/release-radar/1.0.0","authPolicy":"ON_INSTALL","extra":true}"#.utf8),
                expectedVersion: "1.0.0"
            )
        }
        try expectFailure(.malformedJSON) {
            try parsePluginRemoveResponse(
                Data(#"{"pluginId":"release-radar@release-radar","name":"release-radar","marketplaceName":"release-radar","extra":true}"#.utf8)
            )
        }
        try expectFailure(.malformedJSON) {
            try parseMarketplaceRemoveResponse(
                Data(#"{"marketplaceName":"release-radar","installedRoot":null,"extra":true}"#.utf8)
            )
        }
    }

    private static func controllerOperationModes(context: SelfTestContext) throws {
        let absentJSON = Data(#"{"marketplaces":[{"name":"other","root":"/other"}]}"#.utf8)
        let root = ValidatedMarketplaceRoot(
            url: context.fixtureRoot,
            pluginRoot: context.fixtureRoot.appendingPathComponent("plugins/release-radar"),
            version: "1.0.0",
            digest: "426c849972c27cd2c76981da54ff1a917e9bb87e4d9f9bc0e2f99dd9ff839abd"
        )

        var preflightCommands = [[String]]()
        let preflight = try runControllerMode(
            .preflight,
            marketplaceRoot: root,
            cliVersion: "codex-cli self-test",
            invoke: { arguments, operation in
                preflightCommands.append(arguments)
                return fakeResult(stdout: absentJSON, operation: operation)
            }
        )
        try require(preflight.operation == .preflight, "preflight report operation changed")
        try require(preflight.targetState == .absent, "preflight did not report absent")
        try require(preflightCommands == [["plugin", "marketplace", "list", "--json"]], "preflight command was not fixed")

        let lifecycleCLI = FakeLifecycleCLI(root: root)
        let lifecycle = try runControllerMode(
            .lifecycle,
            marketplaceRoot: root,
            cliVersion: "codex-cli self-test",
            invoke: lifecycleCLI.invoke
        )
        try require(lifecycle.operation == .lifecycle, "lifecycle report operation changed")
        try require(lifecycle.targetState == .absent, "lifecycle did not restore absent target")
        try require(lifecycleCLI.commands == [
            ["plugin", "marketplace", "list", "--json"],
            ["plugin", "marketplace", "add", context.fixtureRoot.path, "--json"],
            ["plugin", "marketplace", "list", "--json"],
            ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ["plugin", "add", "release-radar@release-radar", "--json"],
            ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ["plugin", "remove", "release-radar@release-radar", "--json"],
            ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ["plugin", "add", "release-radar@release-radar", "--json"],
            ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ["plugin", "marketplace", "list", "--json"],
            ["plugin", "remove", "release-radar@release-radar", "--json"],
            ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ["plugin", "marketplace", "remove", "release-radar", "--json"],
            ["plugin", "marketplace", "list", "--json"],
            ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
        ], "lifecycle command sequence was not fixed")

        for failure in [
            FakeLifecycleCLI.Failure.cleanupPluginRemoveStillInstalled,
            .cleanupMarketplaceRemoveStillPresent,
            .finalTargetedList,
            .unrelatedFingerprintChange,
        ] {
            let cli = FakeLifecycleCLI(root: root, failure: failure)
            try expectFailure(.postcondition) {
                _ = try runControllerMode(
                    .lifecycle,
                    marketplaceRoot: root,
                    cliVersion: "codex-cli self-test",
                    invoke: cli.invoke
                )
            }
        }
        for failure in [
            FakeLifecycleCLI.Failure.cleanupPluginMalformedButAbsent,
            .cleanupMarketplaceMalformedButAbsent,
        ] {
            let cli = FakeLifecycleCLI(root: root, failure: failure)
            let report = try runControllerMode(
                .lifecycle,
                marketplaceRoot: root,
                cliVersion: "codex-cli self-test",
                invoke: cli.invoke
            )
            try require(report.targetState == .absent, "readback-proven cleanup error was not tolerated")
        }
    }

    private static func fakeResult(stdout: Data, operation: ProbeOperation) -> ProbeResult {
        ProbeResult(
            cliVersion: "codex-cli self-test",
            operation: operation,
            exitStatus: 0,
            stdout: stdout,
            stderr: Data(),
            elapsedMilliseconds: 1
        )
    }

    private static func primaryLifecycleFailureCleanup(context: SelfTestContext) throws {
        let root = ValidatedMarketplaceRoot(
            url: context.fixtureRoot,
            pluginRoot: context.fixtureRoot.appendingPathComponent("plugins/release-radar"),
            version: "1.0.0",
            digest: "426c849972c27cd2c76981da54ff1a917e9bb87e4d9f9bc0e2f99dd9ff839abd"
        )
        let cases: [(FakeLifecycleCLI.Failure, ProbeFailure.Kind)] = [
            (.primaryMarketplaceAdd, .timeout),
            (.primaryInitialPluginAdd, .outputOverflow),
            (.primaryFirstPluginRemove, .unavailable),
            (.primaryReinstallPluginAdd, .untrusted),
        ]
        for (injection, expectedFailure) in cases {
            let cli = FakeLifecycleCLI(root: root, failure: injection)
            try expectFailure(expectedFailure) {
                _ = try runControllerMode(
                    .lifecycle,
                    marketplaceRoot: root,
                    cliVersion: "codex-cli self-test",
                    invoke: cli.invoke
                )
            }
            try require(!cli.marketplacePresent, "primary failure cleanup left marketplace present")
            try require(!cli.pluginInstalled, "primary failure cleanup left plugin installed")
            try require(cli.finalTargetedAbsenceObserved, "primary failure cleanup did not verify targeted absence")
            try require(
                cli.absentMarketplaceResponses.count >= 2
                    && cli.absentMarketplaceResponses.first == cli.absentMarketplaceResponses.last,
                "primary failure cleanup did not preserve the unrelated marketplace snapshot"
            )
        }
    }

    private final class FakeLifecycleCLI {
        enum Failure: Equatable {
            case none
            case cleanupPluginRemoveStillInstalled
            case cleanupMarketplaceRemoveStillPresent
            case finalTargetedList
            case unrelatedFingerprintChange
            case cleanupPluginMalformedButAbsent
            case cleanupMarketplaceMalformedButAbsent
            case primaryMarketplaceAdd
            case primaryInitialPluginAdd
            case primaryFirstPluginRemove
            case primaryReinstallPluginAdd
        }

        let root: ValidatedMarketplaceRoot
        let failure: Failure
        var commands = [[String]]()
        var marketplacePresent = false
        var pluginInstalled = false
        var pluginAddCount = 0
        var pluginRemoveCount = 0
        var finalTargetedAbsenceObserved = false
        var absentMarketplaceResponses = [Data]()

        init(root: ValidatedMarketplaceRoot, failure: Failure = .none) {
            self.root = root
            self.failure = failure
        }

        func invoke(arguments: [String], operation: ProbeOperation) throws -> ProbeResult {
            commands.append(arguments)
            let marketplaceList = ["plugin", "marketplace", "list", "--json"]
            let targetedList = ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"]
            if arguments == marketplaceList {
                let unrelatedRoot = !marketplacePresent && failure == .unrelatedFingerprintChange && commands.count > 2
                    ? "/changed"
                    : "/other"
                let output = marketplacePresent
                    ? marketplaceListJSON(root: root.url.path, unrelatedRoot: unrelatedRoot)
                    : Data("{\"marketplaces\":[{\"name\":\"other\",\"root\":\"\(unrelatedRoot)\"}]}".utf8)
                if !marketplacePresent {
                    absentMarketplaceResponses.append(output)
                }
                return fakeResult(stdout: output, operation: operation)
            }
            if arguments == ["plugin", "marketplace", "add", root.url.path, "--json"] {
                marketplacePresent = true
                if failure == .primaryMarketplaceAdd {
                    throw ProbeFailure(kind: .timeout)
                }
                return fakeResult(stdout: marketplaceAddJSON(root: root.url.path), operation: operation)
            }
            if arguments == targetedList {
                if !marketplacePresent {
                    if failure == .finalTargetedList && commands.count > 10 {
                        throw ProbeFailure(kind: .postcondition)
                    }
                    finalTargetedAbsenceObserved = true
                    return fakeResult(stdout: Data(#"{"installed":[],"available":[]}"#.utf8), operation: operation)
                }
                return fakeResult(
                    stdout: pluginListJSON(
                        root: root.url.path,
                        version: root.version,
                        installed: pluginInstalled
                    ),
                    operation: operation
                )
            }
            if arguments == ["plugin", "add", "release-radar@release-radar", "--json"] {
                pluginAddCount += 1
                pluginInstalled = true
                if failure == .primaryInitialPluginAdd && pluginAddCount == 1 {
                    throw ProbeFailure(kind: .outputOverflow)
                }
                if failure == .primaryReinstallPluginAdd && pluginAddCount == 2 {
                    throw ProbeFailure(kind: .untrusted)
                }
                return fakeResult(
                    stdout: pluginAddJSON(version: root.version),
                    operation: operation
                )
            }
            if arguments == ["plugin", "remove", "release-radar@release-radar", "--json"] {
                pluginRemoveCount += 1
                if failure == .primaryFirstPluginRemove && pluginRemoveCount == 1 {
                    throw ProbeFailure(kind: .unavailable)
                }
                if failure == .cleanupPluginRemoveStillInstalled && pluginRemoveCount == 2 {
                    throw ProbeFailure(kind: .postcondition)
                }
                pluginInstalled = false
                if failure == .cleanupPluginMalformedButAbsent && pluginRemoveCount == 2 {
                    return fakeResult(stdout: Data(#"{"unexpected":true}"#.utf8), operation: operation)
                }
                return fakeResult(stdout: pluginRemoveJSON(), operation: operation)
            }
            if arguments == ["plugin", "marketplace", "remove", "release-radar", "--json"] {
                if failure == .cleanupMarketplaceRemoveStillPresent {
                    throw ProbeFailure(kind: .postcondition)
                }
                marketplacePresent = false
                pluginInstalled = false
                if failure == .cleanupMarketplaceMalformedButAbsent {
                    return fakeResult(stdout: Data(#"{"unexpected":true}"#.utf8), operation: operation)
                }
                return fakeResult(stdout: marketplaceRemoveJSON(), operation: operation)
            }
            throw TestFailure(description: "unexpected fake CLI arguments")
        }
    }

    private static func marketplaceListJSON(root: String, unrelatedRoot: String?) -> Data {
        let unrelated = unrelatedRoot.map {
            "{\"name\":\"other\",\"root\":\"\($0)\"},"
        } ?? ""
        return Data(
            "{\"marketplaces\":[\(unrelated){\"name\":\"release-radar\",\"root\":\"\(root)\",\"marketplaceSource\":{\"sourceType\":\"local\",\"source\":\"\(root)\"}}]}".utf8
        )
    }

    private static func marketplaceAddJSON(root: String) -> Data {
        Data(
            "{\"marketplaceName\":\"release-radar\",\"installedRoot\":\"\(root)\",\"alreadyAdded\":false}".utf8
        )
    }

    private static func pluginListJSON(
        root: String,
        version: String,
        installed: Bool
    ) -> Data {
        let entry = "{\"pluginId\":\"release-radar@release-radar\",\"name\":\"release-radar\",\"marketplaceName\":\"release-radar\",\"version\":\"\(version)\",\"installed\":\(installed),\"enabled\":\(installed),\"source\":{\"source\":\"local\",\"path\":\"\(root)/plugins/release-radar\"},\"marketplaceSource\":{\"sourceType\":\"local\",\"source\":\"\(root)\"},\"installPolicy\":\"AVAILABLE\",\"authPolicy\":\"ON_INSTALL\"}"
        let json = installed
            ? "{\"installed\":[\(entry)],\"available\":[]}"
            : "{\"installed\":[],\"available\":[\(entry)]}"
        return Data(json.utf8)
    }

    private static func pluginAddJSON(version: String) -> Data {
        Data(
            "{\"pluginId\":\"release-radar@release-radar\",\"name\":\"release-radar\",\"marketplaceName\":\"release-radar\",\"version\":\"\(version)\",\"installedPath\":\"/Users/test/.codex/plugins/cache/release-radar/release-radar/\(version)\",\"authPolicy\":\"ON_INSTALL\"}".utf8
        )
    }

    private static func pluginRemoveJSON() -> Data {
        Data(
            #"{"pluginId":"release-radar@release-radar","name":"release-radar","marketplaceName":"release-radar"}"#.utf8
        )
    }

    private static func marketplaceRemoveJSON() -> Data {
        Data(
            #"{"marketplaceName":"release-radar","installedRoot":null}"#.utf8
        )
    }

    private static func controllerArgumentBoundary(context: SelfTestContext) throws {
        let invocation = try parseControllerInvocation([
            "lifecycle", "--fixture-root", context.fixtureRoot.path,
        ])
        try require(invocation.mode == .lifecycle, "controller mode changed")
        try require(invocation.fixtureRoot == context.fixtureRoot.path, "fixture root changed")
        try expectFailure(.untrusted) {
            _ = try parseControllerInvocation([
                "lifecycle", "--fixture-root", context.fixtureRoot.path,
                "--cli", context.cliURL.path,
            ])
        }
        try expectFailure(.untrusted) {
            _ = try parseControllerInvocation([
                "install", "--fixture-root", context.fixtureRoot.path,
            ])
        }
        try expectFailure(.untrusted) {
            _ = try parseControllerInvocation([
                "status", "--fixture-root", context.fixtureRoot.path,
            ])
        }
        try expectFailure(.untrusted) {
            _ = try parseControllerInvocation([
                "arbitrary", "--fixture-root", context.fixtureRoot.path,
            ])
        }
    }

    private static func reinstallTransactionController(context: SelfTestContext) throws {
        let invocation = try parseControllerInvocation(["reinstall"])
        try require(invocation.mode == .reinstall, "reinstall controller mode changed")
        try require(invocation.fixtureRoot == nil, "reinstall controller accepted a fixture root")
        for arguments in [
            ["reinstall", "--fixture-root", context.fixtureRoot.path],
            ["reinstall", "--version", "1.0.0"],
            ["reinstall", "release-radar@release-radar"],
            ["reinstall", "--", "plugin", "add"],
        ] {
            try expectFailure(.untrusted) {
                _ = try parseControllerInvocation(arguments)
            }
        }

        let targetedList = [
            "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
        ]
        let pluginRemove = ["plugin", "remove", "release-radar@release-radar", "--json"]
        let pluginAdd = ["plugin", "add", "release-radar@release-radar", "--json"]

        var absentCommands = [[String]]()
        try expectFailure(.postcondition) {
            _ = try runReinstallController { arguments, operation in
                absentCommands.append(arguments)
                try require(operation == .status, "reinstall precondition operation changed")
                try require(arguments == targetedList, "reinstall precondition command changed")
                return fakeResult(
                    stdout: pluginListJSON(
                        root: context.fixtureRoot.path,
                        version: "1.0.0",
                        installed: false
                    ),
                    operation: operation
                )
            }
        }
        try require(absentCommands == [targetedList], "absent target was mutated")

        var removeFailureCommands = [[String]]()
        try expectFailure(.unavailable) {
            _ = try runReinstallController { arguments, operation in
                removeFailureCommands.append(arguments)
                if arguments == targetedList {
                    try require(operation == .status, "reinstall precondition operation changed")
                    return fakeResult(
                        stdout: pluginListJSON(
                            root: context.fixtureRoot.path,
                            version: "1.0.0",
                            installed: true
                        ),
                        operation: operation
                    )
                }
                if arguments == pluginRemove {
                    try require(operation == .remove, "reinstall remove operation changed")
                    throw ProbeFailure(kind: .unavailable)
                }
                throw TestFailure(description: "remove failure invoked an unexpected command")
            }
        }
        try require(
            removeFailureCommands == [targetedList, pluginRemove],
            "remove failure did not stop before add"
        )

        var addFailureCommands = [[String]]()
        let partial = try runReinstallController { arguments, operation in
            addFailureCommands.append(arguments)
            if arguments == targetedList {
                try require(operation == .status, "reinstall precondition operation changed")
                return fakeResult(
                    stdout: pluginListJSON(
                        root: context.fixtureRoot.path,
                        version: "1.0.0",
                        installed: true
                    ),
                    operation: operation
                )
            }
            if arguments == pluginRemove {
                try require(operation == .remove, "reinstall remove operation changed")
                return fakeResult(stdout: pluginRemoveJSON(), operation: operation)
            }
            if arguments == pluginAdd {
                try require(operation == .reinstall, "reinstall add operation changed")
                throw ProbeFailure(kind: .timeout)
            }
            throw TestFailure(description: "add failure invoked an unexpected command")
        }
        try require(
            addFailureCommands == [targetedList, pluginRemove, pluginAdd],
            "partial reinstall command sequence changed"
        )
        try require(!partial.ok, "partial reinstall was reported successful")
        try require(partial.observedState == .needsRepair, "partial reinstall state changed")
        try require(partial.error == .partialReinstall, "partial reinstall error changed")
        try require(partial.removeSucceeded, "partial reinstall lost remove evidence")
        try require(partial.addAttemptCount == 1, "partial reinstall add count changed")
        try require(!partial.retryAttempted, "partial reinstall retried automatically")
        let encodedPartial = String(
            decoding: try JSONEncoder().encode(partial),
            as: UTF8.self
        )
        try require(!encodedPartial.contains(context.fixtureRoot.path), "partial report disclosed fixture path")
        try require(!encodedPartial.contains("/Users/test"), "partial report disclosed CLI cache path")

        var successCommands = [[String]]()
        let success = try runReinstallController { arguments, operation in
            successCommands.append(arguments)
            if arguments == targetedList {
                return fakeResult(
                    stdout: pluginListJSON(
                        root: context.fixtureRoot.path,
                        version: "1.0.0",
                        installed: true
                    ),
                    operation: operation
                )
            }
            if arguments == pluginRemove {
                return fakeResult(stdout: pluginRemoveJSON(), operation: operation)
            }
            if arguments == pluginAdd {
                return fakeResult(stdout: pluginAddJSON(version: "1.0.0"), operation: operation)
            }
            throw TestFailure(description: "successful reinstall invoked an unexpected command")
        }
        try require(
            successCommands == [targetedList, pluginRemove, pluginAdd],
            "successful reinstall command sequence changed"
        )
        try require(success.ok, "successful reinstall was reported failed")
        try require(success.observedState == .installed, "successful reinstall state changed")
        try require(success.error == nil, "successful reinstall was mislabeled partial")
        try require(success.removeSucceeded, "successful reinstall lost remove evidence")
        try require(success.addAttemptCount == 1, "successful reinstall add count changed")
        try require(!success.retryAttempted, "successful reinstall reported a retry")
    }

    private static func cliVersionOutput() throws {
        let parsed = try parseCLIVersion(Data("codex-cli 0.149.0-alpha.4.3\n".utf8))
        try require(parsed == "codex-cli 0.149.0-alpha.4.3", "CLI version changed")
        try expectFailure(.malformedJSON) {
            _ = try parseCLIVersion(Data("codex-cli 1\nsecond line\n".utf8))
        }
        try expectFailure(.malformedJSON) {
            _ = try parseCLIVersion(Data([0xff]))
        }
    }

    private static func packageDigest(context: SelfTestContext) throws {
        let directory = try context.directory("digest")
        let expectedDigests = [
            "v1": "426c849972c27cd2c76981da54ff1a917e9bb87e4d9f9bc0e2f99dd9ff839abd",
            "v2": "fafb0d2027077c8f4a5efe2c9b422912d5a92c635417bb475d682c5c1f1c29b8",
        ]
        for (fixture, expected) in expectedDigests {
            let source = context.fixtureRoot
                .deletingLastPathComponent()
                .appendingPathComponent(fixture, isDirectory: true)
                .appendingPathComponent("plugins/release-radar", isDirectory: true)
            let clean = directory.appendingPathComponent("clean-\(fixture)", isDirectory: true)
            try FileManager.default.copyItem(at: source, to: clean)
            let cleanDigest = try deterministicPackageDigest(at: clean, expectedDigest: expected)
            try require(cleanDigest == expected, "\(fixture) digest differs from independent literal")
        }

        let source = context.fixtureRoot.appendingPathComponent(
            "plugins/release-radar",
            isDirectory: true
        )
        let edited = directory.appendingPathComponent("edited", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: edited)
        let editedSkill = edited.appendingPathComponent("skills/release-radar/SKILL.md")
        let handle = try FileHandle(forWritingTo: editedSkill)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x0a]))
        try handle.close()

        try expectFailure(.postcondition) {
            _ = try deterministicPackageDigest(
                at: edited,
                expectedDigest: expectedDigests["v1"]!
            )
        }
    }

    private static let recognizedInstalledDigests = recognizedInstalledPluginDigests

    private static func installedIntegrityHomeAndVersion(context: SelfTestContext) throws {
        let originalHome = ProcessInfo.processInfo.environment["HOME"]
        guard setenv("HOME", "/definitely/not/the/effective/user/home", 1) == 0 else {
            throw TestFailure(description: "could not set derived HOME test value")
        }
        defer {
            if let originalHome {
                _ = setenv("HOME", originalHome, 1)
            } else {
                unsetenv("HOME")
            }
        }

        var account = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16 * 1024)
        let status = getpwuid_r(geteuid(), &account, &buffer, buffer.count, &result)
        guard status == 0, result != nil, let directory = account.pw_dir else {
            throw TestFailure(description: "independent effective-user lookup failed")
        }
        let expectedHome = String(cString: directory)
        let resolvedHome = try effectiveUserHomeDirectory()
        try require(resolvedHome.path == expectedHome, "effective home resolver used process environment")

        let home = try context.directory("installed-version-home")
        var openedFiles = [String]()
        let invalidVersions = [
            "", "1", "1.0", "01.0.0", "1.01.0", "1.0.01", "1.0.0-01",
            "1.0.0-", "1.0.0+", "1.0.0-alpha..1", "1.0.0+build..1",
            "1.0.0/../../config.toml", ".", "..", "1.0.0\u{0}escape",
            String(repeating: "1", count: 129), "1.0.0-é",
        ]
        for version in invalidVersions {
            let before = try snapshotTree(home)
            let state = InstalledPluginDigester(
                homeDirectory: home,
                version: version,
                expectedDigests: recognizedInstalledDigests,
                accessObserver: { access in
                    if case .file(let path) = access { openedFiles.append(path) }
                }
            ).classify()
            let after = try snapshotTree(home)
            try require(before == after, "invalid-version status changed derived tree")
            try require(
                state == .needsRepair(.integrityInvalid),
                "invalid version was not integrityInvalid"
            )
        }
        try require(openedFiles.isEmpty, "invalid version attempted a target file open")
        try require(
            isStrictSemVer("0.0.0")
                && isStrictSemVer("1.2.3-alpha.1+build.9")
                && isStrictSemVer("1.2.3-0A-a-b+001"),
            "valid strict SemVer was rejected"
        )
    }

    private static func installedIntegrityClean(context: SelfTestContext) throws {
        for (fixture, version) in [("v1", "1.0.0"), ("v2", "1.1.0")] {
            let installed = try derivedInstalledPlugin(
                context: context,
                name: "clean-\(fixture)",
                fixture: fixture,
                version: version
            )
            let before = try snapshotTree(installed.home)
            let state = InstalledPluginDigester(
                homeDirectory: installed.home,
                version: version,
                expectedDigests: recognizedInstalledDigests
            ).classify()
            let after = try snapshotTree(installed.home)
            try require(before == after, "clean status changed the derived tree")
            try require(
                state == .clean(version: version, digest: recognizedInstalledDigests[version]!),
                "recognized \(fixture) bytes were not clean: \(state)"
            )
        }
    }

    private static func installedIntegrityModified(context: SelfTestContext) throws {
        let skillEdit = try derivedInstalledPlugin(
            context: context,
            name: "modified-skill",
            fixture: "v1",
            version: "1.0.0"
        )
        let skill = skillEdit.target.appendingPathComponent("skills/release-radar/SKILL.md")
        let skillHandle = try FileHandle(forWritingTo: skill)
        try skillHandle.seekToEnd()
        try skillHandle.write(contentsOf: Data([0x0a]))
        try skillHandle.close()
        try requireReadOnlyClassification(
            home: skillEdit.home,
            version: "1.0.0",
            expected: { state in
                if case .modified(version: "1.0.0", observedDigest: let digest) = state {
                    return digest != nil && digest != recognizedInstalledDigests["1.0.0"]
                }
                return false
            },
            failure: "one-byte skill edit was not modified"
        )

        let mcpEdit = try derivedInstalledPlugin(
            context: context,
            name: "modified-mcp",
            fixture: "v1",
            version: "1.0.0"
        )
        try Data(
            #"{"release_radar":{"command":"/not/installed/release-radar-agent-tools","args":[]}}"#.utf8
        ).write(to: mcpEdit.target.appendingPathComponent(".mcp.json"))
        try requireReadOnlyClassification(
            home: mcpEdit.home,
            version: "1.0.0",
            expected: { state in
                if case .modified(version: "1.0.0", observedDigest: let digest) = state {
                    return digest != nil && digest != recognizedInstalledDigests["1.0.0"]
                }
                return false
            },
            failure: "valid changed MCP command was not modified"
        )
    }

    private static func installedIntegrityMalformed(context: SelfTestContext) throws {
        let cases: [(String, (URL) throws -> Void)] = [
            ("missing-manifest", { target in
                try FileManager.default.removeItem(
                    at: target.appendingPathComponent(".codex-plugin/plugin.json")
                )
            }),
            ("extra-entry", { target in
                try Data("extra".utf8).write(to: target.appendingPathComponent("unexpected.txt"))
            }),
            ("malformed-manifest", { target in
                try Data(#"{"name":"release-radar""#.utf8).write(
                    to: target.appendingPathComponent(".codex-plugin/plugin.json")
                )
            }),
            ("malformed-mcp", { target in
                try Data(#"{"release_radar":{"command":1}}"#.utf8).write(
                    to: target.appendingPathComponent(".mcp.json")
                )
            }),
            ("partial-metadata", { target in
                try Data(#"{"name":"release-radar","version":"1.0.0"}"#.utf8).write(
                    to: target.appendingPathComponent(".codex-plugin/plugin.json")
                )
            }),
            ("wrong-version", { target in
                let manifest = target.appendingPathComponent(".codex-plugin/plugin.json")
                let data = try Data(contentsOf: manifest)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw TestFailure(description: "fixture manifest was not UTF-8")
                }
                try Data(text.replacingOccurrences(of: "1.0.0", with: "1.1.0").utf8)
                    .write(to: manifest)
            }),
        ]
        for (name, mutate) in cases {
            let installed = try derivedInstalledPlugin(
                context: context,
                name: "malformed-\(name)",
                fixture: "v1",
                version: "1.0.0"
            )
            try mutate(installed.target)
            try requireReadOnlyClassification(
                home: installed.home,
                version: "1.0.0",
                expected: { $0 == .needsRepair(.integrityInvalid) },
                failure: "\(name) was not integrityInvalid"
            )
        }
    }

    private static func installedIntegrityEntryTypes(context: SelfTestContext) throws {
        let source = context.fixtureRoot.appendingPathComponent("plugins/release-radar", isDirectory: true)
        let symlinkHome = try context.directory("installed-symlink-root")
        let symlinkParent = installedVersionParent(in: symlinkHome)
        try FileManager.default.createDirectory(at: symlinkParent, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: symlinkParent.appendingPathComponent("1.0.0", isDirectory: true),
            withDestinationURL: source
        )
        try requireReadOnlyClassification(
            home: symlinkHome,
            version: "1.0.0",
            expected: { $0 == .needsRepair(.integrityInvalid) },
            failure: "target-root symlink was not integrityInvalid"
        )

        let nonRegular = try derivedInstalledPlugin(
            context: context,
            name: "installed-nonregular",
            fixture: "v1",
            version: "1.0.0"
        )
        let mcp = nonRegular.target.appendingPathComponent(".mcp.json")
        try FileManager.default.removeItem(at: mcp)
        guard mkfifo(mcp.path, 0o600) == 0 else {
            throw TestFailure(description: "mkfifo failed: \(errno)")
        }
        try requireReadOnlyClassification(
            home: nonRegular.home,
            version: "1.0.0",
            expected: { $0 == .needsRepair(.integrityInvalid) },
            failure: "non-regular allowlisted entry was not integrityInvalid"
        )

        let partial = try context.directory("installed-partial-tree")
        let partialTarget = installedTarget(in: partial, version: "1.0.0")
        try FileManager.default.createDirectory(
            at: partialTarget.appendingPathComponent(".codex-plugin", isDirectory: true),
            withIntermediateDirectories: true
        )
        try requireReadOnlyClassification(
            home: partial,
            version: "1.0.0",
            expected: { $0 == .needsRepair(.integrityInvalid) },
            failure: "partial target tree was not integrityInvalid"
        )
    }

    private static func installedIntegrityResourceBounds(context: SelfTestContext) throws {
        let oversized = try derivedInstalledPlugin(
            context: context,
            name: "installed-oversized-file",
            fixture: "v1",
            version: "1.0.0"
        )
        try Data(repeating: 0x41, count: (256 * 1024) + 1).write(
            to: oversized.target.appendingPathComponent("skills/release-radar/SKILL.md")
        )
        try requireReadOnlyClassification(
            home: oversized.home,
            version: "1.0.0",
            expected: { $0 == .needsRepair(.integrityInvalid) },
            failure: "oversized installed package file was not integrityInvalid"
        )
    }

    private static func installedIntegrityUnknown(context: SelfTestContext) throws {
        let unknownDigest = try derivedInstalledPlugin(
            context: context,
            name: "installed-unknown-digest",
            fixture: "v1",
            version: "1.0.0"
        )
        var openedFiles = [String]()
        let beforeUnknown = try snapshotTree(unknownDigest.home)
        let unknownState = InstalledPluginDigester(
            homeDirectory: unknownDigest.home,
            version: "1.0.0",
            expectedDigests: [:],
            accessObserver: { access in
                if case .file(let path) = access { openedFiles.append(path) }
            }
        ).classify()
        try require(
            unknownState == .needsRepair(.integrityUnknown),
            "unavailable recognized digest was not integrityUnknown"
        )
        try require(openedFiles.isEmpty, "missing expected digest opened target files")
        let afterUnknown = try snapshotTree(unknownDigest.home)
        try require(beforeUnknown == afterUnknown, "unknown digest status changed tree")

        let denied = try derivedInstalledPlugin(
            context: context,
            name: "installed-read-denied",
            fixture: "v1",
            version: "1.0.0"
        )
        let deniedBefore = try snapshotTree(denied.home)
        let state = InstalledPluginDigester(
            homeDirectory: denied.home,
            version: "1.0.0",
            expectedDigests: recognizedInstalledDigests,
            testReadFailure: .file(".mcp.json")
        ).classify()
        let deniedAfter = try snapshotTree(denied.home)
        try require(deniedBefore == deniedAfter, "read failure handling changed tree")
        try require(
            state == .needsRepair(.integrityUnknown),
            "operating-system read failure was not integrityUnknown"
        )
    }

    private static func installedIntegrityRaces(context: SelfTestContext) throws {
        let ancestor = try derivedInstalledPlugin(
            context: context,
            name: "installed-ancestor-replacement",
            fixture: "v1",
            version: "1.0.0"
        )
        let plugins = ancestor.home.appendingPathComponent(".codex/plugins", isDirectory: true)
        let cache = plugins.appendingPathComponent("cache", isDirectory: true)
        let alternateCache = plugins.appendingPathComponent("alternate-cache", isDirectory: true)
        try FileManager.default.copyItem(at: cache, to: alternateCache)
        let ancestorBefore = try snapshotTree(ancestor.home)
        var didReplaceAncestor = false
        let ancestorState = InstalledPluginDigester(
            homeDirectory: ancestor.home,
            version: "1.0.0",
            expectedDigests: recognizedInstalledDigests,
            testEvent: { event in
                guard event == .openedFixedDirectory(2), !didReplaceAncestor else { return }
                didReplaceAncestor = true
                let parked = plugins.appendingPathComponent("parked-cache", isDirectory: true)
                try FileManager.default.moveItem(at: cache, to: parked)
                try FileManager.default.moveItem(at: alternateCache, to: cache)
                try FileManager.default.moveItem(at: cache, to: alternateCache)
                try FileManager.default.moveItem(at: parked, to: cache)
            }
        ).classify()
        let ancestorAfter = try snapshotTree(ancestor.home)
        try require(didReplaceAncestor, "ancestor replacement hook did not run")
        try require(
            ancestorState == .needsRepair(.integrityInvalid),
            "non-version ancestor replacement was not integrityInvalid"
        )
        try require(
            ancestorBefore == ancestorAfter,
            "ancestor replacement proof did not restore tree bytes/inventory"
        )

        let replacement = try derivedInstalledPlugin(
            context: context,
            name: "installed-component-replacement",
            fixture: "v1",
            version: "1.0.0"
        )
        let parent = installedVersionParent(in: replacement.home)
        let alternate = parent.appendingPathComponent("replacement", isDirectory: true)
        try FileManager.default.copyItem(at: replacement.target, to: alternate)
        let replacementBefore = try snapshotTree(replacement.home)
        var didReplace = false
        let replacementState = InstalledPluginDigester(
            homeDirectory: replacement.home,
            version: "1.0.0",
            expectedDigests: recognizedInstalledDigests,
            testEvent: { event in
                guard event == .openedTargetRoot, !didReplace else { return }
                didReplace = true
                let parked = parent.appendingPathComponent("parked", isDirectory: true)
                try FileManager.default.moveItem(at: replacement.target, to: parked)
                try FileManager.default.moveItem(at: alternate, to: replacement.target)
                try FileManager.default.moveItem(at: replacement.target, to: alternate)
                try FileManager.default.moveItem(at: parked, to: replacement.target)
            }
        ).classify()
        try require(didReplace, "component replacement hook did not run")
        try require(
            replacementState == .needsRepair(.integrityInvalid),
            "component replacement was not integrityInvalid"
        )
        let replacementAfter = try snapshotTree(replacement.home)
        try require(
            replacementBefore == replacementAfter,
            "component replacement proof did not restore tree bytes/inventory"
        )

        let changing = try derivedInstalledPlugin(
            context: context,
            name: "installed-change-while-read",
            fixture: "v1",
            version: "1.0.0"
        )
        let skill = changing.target.appendingPathComponent("skills/release-radar/SKILL.md")
        let changingBefore = try snapshotTree(changing.home)
        var didChange = false
        let changingState = InstalledPluginDigester(
            homeDirectory: changing.home,
            version: "1.0.0",
            expectedDigests: recognizedInstalledDigests,
            testEvent: { event in
                guard event == .readFile("skills/release-radar/SKILL.md"), !didChange else { return }
                didChange = true
                let descriptor = open(skill.path, O_WRONLY | O_APPEND)
                guard descriptor >= 0 else {
                    throw TestFailure(description: "change-while-read open failed: \(errno)")
                }
                defer { close(descriptor) }
                var byte: UInt8 = 0x0a
                guard write(descriptor, &byte, 1) == 1,
                      ftruncate(descriptor, off_t(changingBefore.regularFileSize(at: "skills/release-radar/SKILL.md"))) == 0,
                      fsync(descriptor) == 0 else {
                    throw TestFailure(description: "change-while-read mutation failed: \(errno)")
                }
            }
        ).classify()
        try require(didChange, "change-while-read hook did not run")
        try require(
            changingState == .needsRepair(.integrityInvalid),
            "change while read was not integrityInvalid"
        )
        let changingAfter = try snapshotTree(changing.home)
        try require(
            changingBefore == changingAfter,
            "change-while-read proof did not preserve tree bytes/inventory"
        )
    }

    private static func installedIntegrityAccessBoundary(context: SelfTestContext) throws {
        let installed = try derivedInstalledPlugin(
            context: context,
            name: "installed-access-boundary",
            fixture: "v1",
            version: "1.0.0"
        )
        try Data("model = \"never-read\"".utf8).write(
            to: installed.home.appendingPathComponent(".codex/config.toml")
        )
        let siblingPlugin = installed.home.appendingPathComponent(
            ".codex/plugins/cache/another/another/9.9.9",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: siblingPlugin, withIntermediateDirectories: true)
        try Data("never-read".utf8).write(to: siblingPlugin.appendingPathComponent("secret"))
        let siblingVersion = installedVersionParent(in: installed.home)
            .appendingPathComponent("9.9.9", isDirectory: true)
        try FileManager.default.createDirectory(at: siblingVersion, withIntermediateDirectories: false)
        try Data("never-read".utf8).write(to: siblingVersion.appendingPathComponent("secret"))

        var accesses = [InstalledPluginAccess]()
        let before = try snapshotTree(installed.home)
        let state = InstalledPluginDigester(
            homeDirectory: installed.home,
            version: "1.0.0",
            expectedDigests: recognizedInstalledDigests,
            accessObserver: { accesses.append($0) }
        ).classify()
        try require(
            state == .clean(version: "1.0.0", digest: recognizedInstalledDigests["1.0.0"]!),
            "unrelated state affected target classification: \(state)"
        )
        let expectedAccesses: [InstalledPluginAccess] = [
            .homeDirectory,
            .fixedDirectory(0), .fixedDirectory(1), .fixedDirectory(2),
            .fixedDirectory(3), .fixedDirectory(4), .fixedDirectory(5),
            .inventory(""),
            .packageDirectory(".codex-plugin"),
            .inventory(".codex-plugin"),
            .packageDirectory("skills"),
            .inventory("skills"),
            .packageDirectory("skills/release-radar"),
            .inventory("skills/release-radar"),
            .file(".codex-plugin/plugin.json"),
            .file(".mcp.json"),
            .file("skills/release-radar/SKILL.md"),
            .inventory(""),
            .inventory(".codex-plugin"),
            .inventory("skills"),
            .inventory("skills/release-radar"),
        ]
        try require(
            accesses == expectedAccesses,
            "access trace exceeded the fixed installed-target boundary"
        )
        let after = try snapshotTree(installed.home)
        try require(before == after, "access-boundary status changed tree")
    }

    private static func installedIntegrityPathFreeOutput(context: SelfTestContext) throws {
        let installed = try derivedInstalledPlugin(
            context: context,
            name: "installed-path-free",
            fixture: "v1",
            version: "1.0.0"
        )
        let before = try snapshotTree(installed.home)
        let captured = try captureOutput {
            InstalledPluginDigester(
                homeDirectory: installed.home,
                version: "1.0.0",
                expectedDigests: recognizedInstalledDigests
            ).classify()
        }
        let after = try snapshotTree(installed.home)
        let encoded = try JSONEncoder().encode(captured.value)
        let serialized = String(decoding: encoded, as: UTF8.self)
        try require(captured.stdout.isEmpty && captured.stderr.isEmpty, "integrity status emitted logs")
        try require(before == after, "path-free status changed derived tree")
        try require(!serialized.contains(installed.home.path), "structured output disclosed home path")
        try require(!serialized.contains(".codex/plugins/cache"), "structured output disclosed cache path")
        try require(
            captured.value == .clean(
                version: "1.0.0",
                digest: recognizedInstalledDigests["1.0.0"]!
            ),
            "path-free status changed classification"
        )
    }

    private static func installedIntegrityController(context: SelfTestContext) throws {
        let invocation = try parseControllerInvocation(["installed-integrity"])
        try require(invocation.mode == .installedIntegrity, "read-only controller mode changed")
        try require(invocation.fixtureRoot == nil, "read-only controller accepted a fixture root")
        for arguments in [
            ["installed-integrity", "--fixture-root", context.fixtureRoot.path],
            ["installed-integrity", "--version", "1.0.0"],
            ["installed-integrity", context.root.path],
        ] {
            try expectFailure(.untrusted) {
                _ = try parseControllerInvocation(arguments)
            }
        }

        let installed = try derivedInstalledPlugin(
            context: context,
            name: "installed-read-only-controller",
            fixture: "v1",
            version: "1.0.0"
        )
        let before = try snapshotTree(installed.home)
        var commands = [[String]]()
        var resolvedHome = false
        let report = try runInstalledIntegrityController(
            invoke: { arguments, operation in
                commands.append(arguments)
                try require(operation == .status, "read-only controller changed operation")
                return fakeResult(
                    stdout: pluginListJSON(
                        root: context.fixtureRoot.path,
                        version: "1.0.0",
                        installed: true
                    ),
                    operation: operation
                )
            },
            resolveHome: {
                resolvedHome = true
                return installed.home
            }
        )
        let after = try snapshotTree(installed.home)
        try require(before == after, "read-only controller changed derived target")
        try require(resolvedHome, "read-only controller bypassed production home resolution")
        try require(commands == [[
            "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
        ]], "read-only controller command was not fixed and targeted")
        try require(
            report == InstalledIntegrityControllerReport(
                wireVersion: 1,
                ok: true,
                classification: .clean,
                version: "1.0.0",
                digest: recognizedInstalledDigests["1.0.0"],
                error: nil
            ),
            "read-only controller report changed"
        )
        let encoded = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
        try require(!encoded.contains(installed.home.path), "controller output disclosed home path")
        try require(!encoded.contains(context.fixtureRoot.path), "controller output disclosed CLI source path")

        let absent = try parseInstalledIntegrityTargetedList(
            Data(#"{"installed":[],"available":[]}"#.utf8)
        )
        try require(absent == .absent, "strict targeted parser rejected absence")
        try expectFailure(.malformedJSON) {
            _ = try parseInstalledIntegrityTargetedList(
                Data(#"{"installed":[{"name":"release-radar"}],"available":[]}"#.utf8)
            )
        }
        try expectFailure(.malformedJSON) {
            _ = try parseInstalledIntegrityTargetedList(
                Data(#"{"installed":[],"available":[],"version":"1.0.0"}"#.utf8)
            )
        }
        try expectFailure(.malformedJSON) {
            _ = try parseInstalledIntegrityTargetedList(
                pluginListJSON(
                    root: context.fixtureRoot.path,
                    version: "01.0.0",
                    installed: true
                )
            )
        }
    }

    private struct DerivedInstalledPlugin {
        let home: URL
        let target: URL
    }

    private static func derivedInstalledPlugin(
        context: SelfTestContext,
        name: String,
        fixture: String,
        version: String
    ) throws -> DerivedInstalledPlugin {
        let home = try context.directory(name)
        let target = installedTarget(in: home, version: version)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let source = context.fixtureRoot
            .deletingLastPathComponent()
            .appendingPathComponent(fixture, isDirectory: true)
            .appendingPathComponent("plugins/release-radar", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: target)
        return DerivedInstalledPlugin(home: home, target: target)
    }

    private static func installedVersionParent(in home: URL) -> URL {
        home.appendingPathComponent(
            ".codex/plugins/cache/release-radar/release-radar",
            isDirectory: true
        )
    }

    private static func installedTarget(in home: URL, version: String) -> URL {
        installedVersionParent(in: home).appendingPathComponent(version, isDirectory: true)
    }

    private static func requireReadOnlyClassification(
        home: URL,
        version: String,
        expected: (InstalledPluginIntegrityState) -> Bool,
        failure: String
    ) throws {
        let before = try snapshotTree(home)
        let state = InstalledPluginDigester(
            homeDirectory: home,
            version: version,
            expectedDigests: recognizedInstalledDigests
        ).classify()
        let after = try snapshotTree(home)
        try require(before == after, "\(failure): status changed tree")
        try require(expected(state), "\(failure): \(state)")
    }

    private struct TreeSnapshot: Equatable {
        struct Entry: Equatable {
            let path: String
            let type: mode_t
            let bytes: Data?
            let linkDestination: String?
        }

        let entries: [Entry]

        func regularFileSize(at suffix: String) -> Int {
            entries.first(where: { $0.path.hasSuffix(suffix) })?.bytes?.count ?? -1
        }
    }

    private static func snapshotTree(_ root: URL) throws -> TreeSnapshot {
        var entries = [TreeSnapshot.Entry]()
        func visit(_ url: URL, relativePath: String) throws {
            var metadata = stat()
            guard lstat(url.path, &metadata) == 0 else {
                throw TestFailure(description: "snapshot lstat failed: \(errno)")
            }
            let type = metadata.st_mode & S_IFMT
            if type == S_IFDIR {
                entries.append(.init(path: relativePath, type: type, bytes: nil, linkDestination: nil))
                for name in try FileManager.default.contentsOfDirectory(atPath: url.path).sorted() {
                    let child = url.appendingPathComponent(name)
                    let childPath = relativePath.isEmpty ? name : "\(relativePath)/\(name)"
                    try visit(child, relativePath: childPath)
                }
            } else if type == S_IFREG {
                entries.append(
                    .init(
                        path: relativePath,
                        type: type,
                        bytes: try Data(contentsOf: url),
                        linkDestination: nil
                    )
                )
            } else if type == S_IFLNK {
                entries.append(
                    .init(
                        path: relativePath,
                        type: type,
                        bytes: nil,
                        linkDestination: try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
                    )
                )
            } else {
                entries.append(.init(path: relativePath, type: type, bytes: nil, linkDestination: nil))
            }
        }
        try visit(root, relativePath: "")
        return TreeSnapshot(entries: entries)
    }

    private static func captureOutput<Value>(
        _ body: () throws -> Value
    ) throws -> (value: Value, stdout: Data, stderr: Data) {
        fflush(nil)
        let originalStdout = dup(STDOUT_FILENO)
        let originalStderr = dup(STDERR_FILENO)
        var stdoutPipe = [Int32](repeating: -1, count: 2)
        var stderrPipe = [Int32](repeating: -1, count: 2)
        guard originalStdout >= 0,
              originalStderr >= 0,
              pipe(&stdoutPipe) == 0,
              pipe(&stderrPipe) == 0,
              dup2(stdoutPipe[1], STDOUT_FILENO) >= 0,
              dup2(stderrPipe[1], STDERR_FILENO) >= 0 else {
            throw TestFailure(description: "could not capture integrity output")
        }
        close(stdoutPipe[1])
        close(stderrPipe[1])
        defer {
            fflush(nil)
            _ = dup2(originalStdout, STDOUT_FILENO)
            _ = dup2(originalStderr, STDERR_FILENO)
            close(originalStdout)
            close(originalStderr)
            close(stdoutPipe[0])
            close(stderrPipe[0])
        }
        let value = try body()
        fflush(nil)
        _ = dup2(originalStdout, STDOUT_FILENO)
        _ = dup2(originalStderr, STDERR_FILENO)
        let stdout = readAllForSelfTest(stdoutPipe[0])
        let stderr = readAllForSelfTest(stderrPipe[0])
        return (value, stdout, stderr)
    }

    private static func readAllForSelfTest(_ descriptor: Int32) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                return data
            }
            data.append(buffer, count: count)
        }
    }

    private static func executableIdentity(context: SelfTestContext) throws {
        let candidates = try context.directory("identity")
        let writableCopy = candidates.appendingPathComponent("codex-writable")
        let symlink = candidates.appendingPathComponent("codex-symlink")
        let wrongIdentity = candidates.appendingPathComponent("wrong-identity")

        try FileManager.default.copyItem(at: context.cliURL, to: writableCopy)
        guard chmod(writableCopy.path, 0o775) == 0 else {
            throw TestFailure(description: "chmod writable candidate failed: \(errno)")
        }
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: context.cliURL)
        try FileManager.default.copyItem(at: context.executableURL, to: wrongIdentity)

        do {
            try verifyFixedCodexExecutable(context.cliURL)
        } catch {
            throw TestFailure(description: "fixed CLI identity check failed: \(error)")
        }
        try expectFailure(.untrusted) { try verifyCodexCandidate(writableCopy) }
        guard chmod(writableCopy.path, 0o755) == 0 else {
            throw TestFailure(description: "chmod signed copy failed: \(errno)")
        }
        let signedNonFixedCopy = try canonicalExistingURL(writableCopy)
        do {
            try verifyCodexCandidate(signedNonFixedCopy)
        } catch {
            throw TestFailure(description: "signed non-fixed CLI candidate check failed: \(error)")
        }
        try expectFailure(.untrusted) { try verifyFixedCodexExecutable(signedNonFixedCopy) }
        try expectFailure(.untrusted) { try verifyCodexCandidate(symlink) }
        try expectFailure(.untrusted) { try verifyCodexCandidate(wrongIdentity) }
    }

    private static func fixedOperationBoundary(context: SelfTestContext) throws {
        let validatedRoot = try validateFixtureRootArgument(
            context.fixtureRoot.path,
            runtimeRoot: context.runtimeRoot,
            invocationWorkingRoot: URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath,
                isDirectory: true
            )
        )
        let root = context.fixtureRoot.path
        let expected: [ProbeOperation: [[String]]] = [
            .status: [
                ["plugin", "marketplace", "list", "--json"],
                ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ],
            .install: [
                ["plugin", "marketplace", "add", root, "--json"],
                ["plugin", "add", "release-radar@release-radar", "--json"],
                ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ],
            .remove: [
                ["plugin", "remove", "release-radar@release-radar", "--json"],
                ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ],
            .reinstall: [
                ["plugin", "remove", "release-radar@release-radar", "--json"],
                ["plugin", "marketplace", "add", root, "--json"],
                ["plugin", "add", "release-radar@release-radar", "--json"],
                ["plugin", "list", "--marketplace", "release-radar", "--available", "--json"],
            ],
        ]

        for operation in [ProbeOperation.status, .install, .remove, .reinstall] {
            let expectedVectors = try required(expected[operation], "missing literal vectors")
            let vectors = try fixedCommandVectors(for: operation, marketplaceRoot: validatedRoot)
            try require(vectors == expectedVectors, "unexpected \(operation.rawValue) vectors")

            var events = [String]()
            _ = try executeFixedOperation(
                operation,
                marketplaceRoot: validatedRoot,
                runtimeRoot: context.root,
                cliVersion: "self-test",
                verifyExecutable: { url in
                    events.append("verify:\(url.path)")
                },
                spawn: { executable, arguments, cwd, environment, operation, cliVersion in
                    try require(executable.path == "/Applications/ChatGPT.app/Contents/Resources/codex", "spawn executable was not fixed")
                    try require(cwd.path.hasPrefix(context.root.path + "/"), "cwd was caller-controlled")
                    try require((try? FileManager.default.contentsOfDirectory(atPath: cwd.path))?.isEmpty == true, "cwd was not empty")
                    try require(environment == context.fixedEnvironment, "environment was not fixed")
                    events.append("spawn:\(arguments.joined(separator: " "))")
                    return ProbeResult(
                        cliVersion: cliVersion,
                        operation: operation,
                        exitStatus: 0,
                        stdout: Data(),
                        stderr: Data(),
                        elapsedMilliseconds: 0
                    )
                }
            )
            var expectedEvents = [String]()
            for vector in expectedVectors {
                expectedEvents.append("verify:/Applications/ChatGPT.app/Contents/Resources/codex")
                expectedEvents.append("spawn:\(vector.joined(separator: " "))")
            }
            try require(events == expectedEvents, "identity verification was not coupled immediately before spawn")
        }

        var spawnCount = 0
        try expectFailure(.untrusted) {
            _ = try executeFixedOperation(
                .status,
                marketplaceRoot: validatedRoot,
                runtimeRoot: context.root,
                cliVersion: "self-test",
                verifyExecutable: { _ in throw ProbeFailure(kind: .untrusted) },
                spawn: { _, _, _, _, _, _ in
                    spawnCount += 1
                    throw TestFailure(description: "spawn ran after identity rejection")
                }
            )
        }
        try require(spawnCount == 0, "identity rejection did not prevent spawn")
    }

    private static func legacyMCPRecognition() throws {
        let exact = Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#.utf8)
        let currentShape = Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":{},"env_vars":[],"cwd":null},"enabled_tools":null,"disabled_tools":null,"startup_timeout_sec":null,"tool_timeout_sec":null}"#.utf8)
        let nullableEnvironmentVariables = Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"env_vars":null,"cwd":null}}"#.utf8)
        let harmlessMetadata = Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null},"metadata":{"source":"codex-cli"}}"#.utf8)
        let exactObservation = try parseLegacyMCPObservation(legacyMCPResult(stdout: exact))
        try require(
            exactObservation == .exactLegacy,
            "exact legacy MCP entry was not recognized"
        )
        let currentObservation = try parseLegacyMCPObservation(
            legacyMCPResult(stdout: currentShape)
        )
        try require(
            currentObservation == .exactLegacy,
            "noncontradictory current CLI fields were rejected"
        )
        let nullableEnvironmentObservation = try parseLegacyMCPObservation(
            legacyMCPResult(stdout: nullableEnvironmentVariables)
        )
        try require(
            nullableEnvironmentObservation == .exactLegacy,
            "nullable environment-variable list was rejected"
        )
        let harmlessMetadataObservation = try parseLegacyMCPObservation(
            legacyMCPResult(stdout: harmlessMetadata)
        )
        try require(
            harmlessMetadataObservation == .exactLegacy,
            "harmless unknown metadata was rejected"
        )

        let contradictions = [
            #"{"name":"other","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":false,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":"disabled","transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"streamable_http","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/tmp/other","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":["other"],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":{"TOKEN":"value"},"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":[],"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"env_vars":["TOKEN"],"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"env_vars":{},"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":"/tmp"}}"#,
        ]
        for json in contradictions {
            try expectFailure(.conflict) {
                _ = try parseLegacyMCPObservation(
                    legacyMCPResult(stdout: Data(json.utf8))
                )
            }
        }

        for json in [
            #"{"name":"release-radar","name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio""#,
        ] {
            try expectFailure(.malformedJSON) {
                _ = try parseLegacyMCPObservation(
                    legacyMCPResult(stdout: Data(json.utf8))
                )
            }
        }
    }

    private static func legacyMCPKnownOptionalFields() throws {
        let contradictions = [
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null},"enabled_tools":[]}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null},"disabled_tools":[]}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null},"startup_timeout_sec":10}"#,
            #"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null},"tool_timeout_sec":10}"#,
        ]
        for json in contradictions {
            try expectFailure(.conflict) {
                _ = try parseLegacyMCPObservation(
                    legacyMCPResult(stdout: Data(json.utf8))
                )
            }
        }
    }

    private static func legacyMCPAbsenceContract() throws {
        let exactError = Data("Error: No MCP server named 'release-radar' found.\n".utf8)
        let exactObservation = try parseLegacyMCPObservation(
            legacyMCPResult(exitStatus: 1, stderr: exactError)
        )
        try require(
            exactObservation == .absent,
            "exact pinned-CLI absence was rejected"
        )
        let nearMisses = [
            legacyMCPResult(exitStatus: 2, stderr: exactError),
            legacyMCPResult(exitStatus: 1, stdout: Data("unexpected".utf8), stderr: exactError),
            legacyMCPResult(
                exitStatus: 1,
                stderr: Data("Error: No MCP server named 'release-radar' found.".utf8)
            ),
            legacyMCPResult(
                exitStatus: 1,
                stderr: Data("Error: No MCP server named 'release-radar' found.\n\n".utf8)
            ),
        ]
        for result in nearMisses {
            try expectFailure(.postcondition) {
                _ = try parseLegacyMCPObservation(result)
            }
        }
    }

    private static func bundledMCPAbsenceController() throws {
        let invocation = try parseControllerInvocation(["bundled-mcp-preflight"])
        try require(
            invocation.mode.rawValue == "bundled-mcp-preflight",
            "bundled MCP preflight mode changed"
        )
        try require(invocation.fixtureRoot == nil, "bundled MCP preflight accepted a fixture")

        let get = ["mcp", "get", "release_radar", "--json"]
        let exactError = Data("Error: No MCP server named 'release_radar' found.\n".utf8)
        var commands = [[String]]()
        let report = try runLegacyMCPController(invocation.mode) { arguments, operation in
            commands.append(arguments)
            try require(operation == .status, "bundled MCP preflight operation changed")
            return legacyMCPResult(exitStatus: 1, stderr: exactError, operation: operation)
        }
        try require(commands == [get], "bundled MCP preflight command was not fixed")
        try require(report.state == .absent, "exact bundled MCP absence was rejected")
        try require(!report.removalIssued, "bundled MCP preflight reported removal")
        try require(!report.restorationIssued, "bundled MCP preflight reported restoration")

        let nearMisses = [
            legacyMCPResult(exitStatus: 0),
            legacyMCPResult(exitStatus: 2, stderr: exactError),
            legacyMCPResult(exitStatus: 1, stdout: Data("unexpected".utf8), stderr: exactError),
            legacyMCPResult(
                exitStatus: 1,
                stderr: Data("Error: No MCP server named 'release_radar' found.".utf8)
            ),
            legacyMCPResult(
                exitStatus: 1,
                stderr: Data("Error: No MCP server named 'release_radar' found.\n\n".utf8)
            ),
        ]
        for result in nearMisses {
            try expectFailure(.postcondition) {
                _ = try runLegacyMCPController(invocation.mode) { arguments, operation in
                    try require(arguments == get, "bundled MCP preflight issued another command")
                    return ProbeResult(
                        cliVersion: result.cliVersion,
                        operation: operation,
                        exitStatus: result.exitStatus,
                        stdout: result.stdout,
                        stderr: result.stderr,
                        elapsedMilliseconds: result.elapsedMilliseconds
                    )
                }
            }
        }
    }

    private static func legacyMCPFixedController(context: SelfTestContext) throws {
        for (rawMode, expectedMode) in [
            ("legacy-mcp-preflight", ControllerMode.legacyMCPPreflight),
            ("legacy-mcp-remove", ControllerMode.legacyMCPRemove),
            ("legacy-mcp-restore", ControllerMode.legacyMCPRestore),
        ] {
            let invocation = try parseControllerInvocation([rawMode])
            try require(invocation.mode == expectedMode, "legacy MCP controller mode changed")
            try require(invocation.fixtureRoot == nil, "legacy MCP controller accepted a fixture root")
            try expectFailure(.untrusted) {
                _ = try parseControllerInvocation([rawMode, "--", "arbitrary"])
            }
        }

        let get = ["mcp", "get", "release-radar", "--json"]
        let remove = ["mcp", "remove", "release-radar"]
        let add = [
            "mcp", "add", "release-radar", "--",
            "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools",
        ]
        let exact = legacyMCPExactJSON()

        var preflightCommands = [[String]]()
        let preflight = try runLegacyMCPController(.legacyMCPPreflight) { arguments, operation in
            preflightCommands.append(arguments)
            try require(operation == .status, "legacy MCP preflight operation changed")
            return legacyMCPResult(stdout: exact, operation: operation)
        }
        try require(preflightCommands == [get], "legacy MCP preflight command was not fixed")
        try require(preflight.state == .exactLegacy, "legacy MCP preflight state changed")
        try require(!preflight.removalIssued, "legacy MCP preflight reported removal")
        try require(!preflight.restorationIssued, "legacy MCP preflight reported restoration")

        var absentCommands = [[String]]()
        let absent = try runLegacyMCPController(.legacyMCPRemove) { arguments, operation in
            absentCommands.append(arguments)
            return legacyMCPResult(
                exitStatus: 1,
                stderr: Data("Error: No MCP server named 'release-radar' found.\n".utf8),
                operation: operation
            )
        }
        try require(absentCommands == [get], "initially absent MCP entry was mutated")
        try require(absent.state == .absent, "initially absent MCP state changed")
        try require(!absent.removalIssued, "initially absent MCP reported removal")

        var state = LegacyMCPState.exactLegacy
        var removeCommands = [[String]]()
        let removed = try runLegacyMCPController(.legacyMCPRemove) { arguments, operation in
            removeCommands.append(arguments)
            if arguments == get {
                return state == .exactLegacy
                    ? legacyMCPResult(stdout: exact, operation: operation)
                    : legacyMCPResult(
                        exitStatus: 1,
                        stderr: Data("Error: No MCP server named 'release-radar' found.\n".utf8),
                        operation: operation
                    )
            }
            if arguments == remove {
                try require(operation == .remove, "legacy MCP remove operation changed")
                state = .absent
                return legacyMCPResult(operation: operation)
            }
            throw TestFailure(description: "remove invoked an unexpected command")
        }
        try require(removeCommands == [get, remove, get], "legacy MCP remove sequence changed")
        try require(removed.state == .absent, "legacy MCP removal state changed")
        try require(removed.removalIssued, "legacy MCP removal was not reported")
        try require(!removed.restorationIssued, "legacy MCP removal reported restoration")

        var restoreCommands = [[String]]()
        let restored = try runLegacyMCPController(.legacyMCPRestore) { arguments, operation in
            restoreCommands.append(arguments)
            if arguments == get {
                return state == .exactLegacy
                    ? legacyMCPResult(stdout: exact, operation: operation)
                    : legacyMCPResult(
                        exitStatus: 1,
                        stderr: Data("Error: No MCP server named 'release-radar' found.\n".utf8),
                        operation: operation
                    )
            }
            if arguments == add {
                try require(operation == .install, "legacy MCP restore operation changed")
                state = .exactLegacy
                return legacyMCPResult(operation: operation)
            }
            throw TestFailure(description: "restore invoked an unexpected command")
        }
        try require(restoreCommands == [get, add, get], "legacy MCP restore sequence changed")
        try require(restored.state == .exactLegacy, "legacy MCP restoration state changed")
        try require(!restored.removalIssued, "legacy MCP restoration reported removal")
        try require(restored.restorationIssued, "legacy MCP restoration was not reported")

        var alreadyRestoredCommands = [[String]]()
        let alreadyRestored = try runLegacyMCPController(.legacyMCPRestore) { arguments, operation in
            alreadyRestoredCommands.append(arguments)
            return legacyMCPResult(stdout: exact, operation: operation)
        }
        try require(alreadyRestoredCommands == [get], "exact legacy MCP entry was added twice")
        try require(!alreadyRestored.restorationIssued, "existing legacy MCP entry reported an add")

        let encoded = String(decoding: try JSONEncoder().encode(restored), as: UTF8.self)
        try require(!encoded.contains(context.fixtureRoot.path), "legacy MCP report disclosed fixture path")
        try require(!encoded.contains("/Applications"), "legacy MCP report disclosed command path")
    }

    private static func legacyMCPFailureRestoration() throws {
        let get = ["mcp", "get", "release-radar", "--json"]
        let remove = ["mcp", "remove", "release-radar"]
        let add = [
            "mcp", "add", "release-radar", "--",
            "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools",
        ]
        let exact = legacyMCPExactJSON()
        let absent = legacyMCPResult(
            exitStatus: 1,
            stderr: Data("Error: No MCP server named 'release-radar' found.\n".utf8)
        )

        var intactCommands = [[String]]()
        try expectFailure(.unavailable) {
            _ = try runLegacyMCPController(.legacyMCPRemove) { arguments, operation in
                intactCommands.append(arguments)
                if arguments == get {
                    return legacyMCPResult(stdout: exact, operation: operation)
                }
                if arguments == remove {
                    throw ProbeFailure(kind: .unavailable)
                }
                throw TestFailure(description: "intact removal failure invoked an unexpected command")
            }
        }
        try require(intactCommands == [get, remove, get], "intact removal failure attempted an add")

        var removedState = LegacyMCPState.exactLegacy
        var absentCommands = [[String]]()
        try expectFailure(.unavailable) {
            _ = try runLegacyMCPController(.legacyMCPRemove) { arguments, operation in
                absentCommands.append(arguments)
                if arguments == get {
                    return removedState == .exactLegacy
                        ? legacyMCPResult(stdout: exact, operation: operation)
                        : ProbeResult(
                            cliVersion: absent.cliVersion,
                            operation: operation,
                            exitStatus: absent.exitStatus,
                            stdout: absent.stdout,
                            stderr: absent.stderr,
                            elapsedMilliseconds: absent.elapsedMilliseconds
                        )
                }
                if arguments == remove {
                    removedState = .absent
                    throw ProbeFailure(kind: .unavailable)
                }
                if arguments == add {
                    removedState = .exactLegacy
                    return legacyMCPResult(operation: operation)
                }
                throw TestFailure(description: "absent removal failure invoked an unexpected command")
            }
        }
        try require(
            absentCommands == [get, remove, get, add, get],
            "failed removal did not restore an observed absence"
        )

        let unrecognized = Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/tmp/other","args":[],"env":null,"cwd":null}}"#.utf8)
        var unrecognizedCommands = [[String]]()
        var getCount = 0
        try expectFailure(.conflict) {
            _ = try runLegacyMCPController(.legacyMCPRemove) { arguments, operation in
                unrecognizedCommands.append(arguments)
                if arguments == get {
                    getCount += 1
                    return legacyMCPResult(
                        stdout: getCount == 1 ? exact : unrecognized,
                        operation: operation
                    )
                }
                if arguments == remove {
                    throw ProbeFailure(kind: .unavailable)
                }
                throw TestFailure(description: "unrecognized cleanup invoked an unexpected command")
            }
        }
        try require(
            unrecognizedCommands == [get, remove, get],
            "unrecognized cleanup state was overwritten"
        )
    }

    private static func legacyMCPPostRemoveObservation() throws {
        let get = ["mcp", "get", "release-radar", "--json"]
        let remove = ["mcp", "remove", "release-radar"]
        let exact = legacyMCPExactJSON()
        let observations: [(String, ProbeFailure.Kind, ProbeResult)] = [
            (
                "unrecognized",
                .conflict,
                legacyMCPResult(
                    stdout: Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/tmp/other","args":[],"env":null,"cwd":null}}"#.utf8)
                )
            ),
            (
                "malformed",
                .malformedJSON,
                legacyMCPResult(stdout: Data(#"{"name":"release-radar""#.utf8))
            ),
        ]

        for (name, expectedFailure, postRemoveResult) in observations {
            var commands = [[String]]()
            var getCount = 0
            try expectFailure(expectedFailure) {
                _ = try runLegacyMCPController(.legacyMCPRemove) { arguments, operation in
                    commands.append(arguments)
                    if arguments == get {
                        getCount += 1
                        if getCount == 1 {
                            return legacyMCPResult(stdout: exact, operation: operation)
                        }
                        return ProbeResult(
                            cliVersion: postRemoveResult.cliVersion,
                            operation: operation,
                            exitStatus: postRemoveResult.exitStatus,
                            stdout: postRemoveResult.stdout,
                            stderr: postRemoveResult.stderr,
                            elapsedMilliseconds: postRemoveResult.elapsedMilliseconds
                        )
                    }
                    if arguments == remove {
                        return legacyMCPResult(operation: operation)
                    }
                    throw TestFailure(description: "\(name) post-remove failure invoked an add")
                }
            }
            try require(
                commands == [get, remove, get],
                "\(name) post-remove observation was read or mutated again"
            )
        }
    }

    private static func legacyMCPExactJSON() -> Data {
        Data(#"{"name":"release-radar","enabled":true,"disabled_reason":null,"transport":{"type":"stdio","command":"/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools","args":[],"env":null,"cwd":null}}"#.utf8)
    }

    private static func legacyMCPResult(
        exitStatus: Int32 = 0,
        stdout: Data = Data(),
        stderr: Data = Data(),
        operation: ProbeOperation = .status
    ) -> ProbeResult {
        ProbeResult(
            cliVersion: "codex-cli self-test",
            operation: operation,
            exitStatus: exitStatus,
            stdout: stdout,
            stderr: stderr,
            elapsedMilliseconds: 1
        )
    }

    private static func fixtureRootConfinement(context: SelfTestContext) throws {
        let invocationRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let canonical: ValidatedMarketplaceRoot
        do {
            canonical = try validateFixtureRootArgument(
                context.fixtureRoot.path,
                runtimeRoot: context.runtimeRoot,
                invocationWorkingRoot: invocationRoot
            )
        } catch {
            throw TestFailure(description: "canonical fixture root validation failed: \(error)")
        }
        let expectedCanonical = try canonicalExistingURL(context.fixtureRoot)
        try require(
            canonical.url.path == expectedCanonical.path,
            "canonical fixture root changed"
        )
        try require(canonical.version == "1.0.0", "fixture version was not validated")
        try require(
            canonical.digest == "426c849972c27cd2c76981da54ff1a917e9bb87e4d9f9bc0e2f99dd9ff839abd",
            "fixture digest was not validated before controller use"
        )

        let symlinkRoot = context.root.appendingPathComponent("fixture-symlink")
        try FileManager.default.createSymbolicLink(
            at: symlinkRoot,
            withDestinationURL: context.fixtureRoot
        )
        try expectFailure(.untrusted) {
            _ = try validateFixtureRootArgument(
                symlinkRoot.path,
                runtimeRoot: context.runtimeRoot,
                invocationWorkingRoot: invocationRoot
            )
        }

        let runtimeCopy = context.root.appendingPathComponent("runtime-fixture", isDirectory: true)
        try FileManager.default.copyItem(at: context.fixtureRoot, to: runtimeCopy)
        let validatedRuntimeCopy: ValidatedMarketplaceRoot
        do {
            validatedRuntimeCopy = try validateFixtureRootArgument(
                runtimeCopy.path,
                runtimeRoot: context.runtimeRoot,
                invocationWorkingRoot: invocationRoot
            )
        } catch {
            throw TestFailure(description: "runtime fixture copy validation failed: \(error)")
        }
        let expectedRuntimeCopy = try canonicalExistingURL(runtimeCopy)
        try require(
            validatedRuntimeCopy.url.path == expectedRuntimeCopy.path,
            "runtime fixture root changed"
        )

        let externalContainer = context.runtimeRoot
            .deletingLastPathComponent()
            .appendingPathComponent("external-fixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalContainer,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: externalContainer) }
        let externalByteIdenticalLocation = externalContainer.appendingPathComponent(
            "v1",
            isDirectory: true
        )
        try FileManager.default.copyItem(at: context.fixtureRoot, to: externalByteIdenticalLocation)
        try expectFailure(.untrusted) {
            _ = try validateFixtureRootArgument(
                externalByteIdenticalLocation.path,
                runtimeRoot: context.runtimeRoot,
                invocationWorkingRoot: invocationRoot
            )
        }
    }

    private static func step7ControllerBoundary(context: SelfTestContext) throws {
        let v2 = context.fixtureRoot
            .deletingLastPathComponent()
            .appendingPathComponent("v2", isDirectory: true)
        let preparation = try parseControllerInvocation([
            "step7-prepare", "--fixture-root", v2.path,
        ])
        try require(preparation.mode == .step7Prepare, "Step 7 preparation mode changed")
        try require(preparation.fixtureRoot == v2.path, "Step 7 fixture root changed")

        let preflight = try parseControllerInvocation(["bridge-preflight"])
        try require(preflight.mode == .bridgePreflight, "bridge preflight mode changed")
        try require(preflight.fixtureRoot == nil, "bridge preflight accepted a fixture")

        let cancellation = try parseControllerInvocation(["live-owned-cli-cancellation"])
        try require(
            cancellation.mode == .ownedCLICancellation,
            "owned CLI cancellation mode changed"
        )
        try require(cancellation.fixtureRoot == nil, "owned CLI cancellation accepted a fixture")

        for arguments in [
            ["step7-prepare"],
            ["step7-prepare", "--fixture-root", v2.path, "--identity", "-"],
            ["step7-prepare", "--runtime-root", context.root.path],
            ["bridge-preflight", "--fixture-root", v2.path],
            ["live-owned-cli-cancellation", "--retry"],
        ] {
            try expectFailure(.untrusted) {
                _ = try parseControllerInvocation(arguments)
            }
        }
    }

    private static func step7BuildPlan(context: SelfTestContext) throws {
        let packageRoot = try context.directory("step7-build-plan")
        let repositoryRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let layout = try Step7PreparationLayout(
            packageRoot: packageRoot,
            repositoryRoot: repositoryRoot,
            artifactID: UUID(uuidString: "00000000-0000-4000-8000-000000000007")!
        )
        let plan = try makeStep7BuildPlan(layout: layout)
        try require(
            plan.executable == URL(fileURLWithPath: "/usr/bin/xcodebuild"),
            "xcodebuild was not fixed"
        )
        try require(
            plan.arguments == [
                "build",
                "-project", repositoryRoot.appendingPathComponent("ReleaseRadar.xcodeproj").path,
                "-scheme", "ReleaseRadar",
                "-configuration", "Debug",
                "-destination", "platform=macOS",
                "-derivedDataPath", layout.derivedDataRoot.path,
            ],
            "Step 7 build arguments changed"
        )
        try require(plan.environment == context.fixedEnvironment, "Step 7 build environment changed")
        try require(
            plan.workingDirectory.path.hasPrefix(layout.packageRoot.path + "/"),
            "Step 7 build cwd escaped"
        )
        try require(plan.expectedApp == layout.builtApp, "Step 7 expected app changed")
        try require(plan.expectedAgentTool == layout.builtAgentTool, "Step 7 expected tool changed")
    }

    private static func step7DerivedFixture(context: SelfTestContext) throws {
        let packageRoot = try context.directory("step7-derived-fixture")
        let repositoryRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let layout = try Step7PreparationLayout(
            packageRoot: packageRoot,
            repositoryRoot: repositoryRoot,
            artifactID: UUID(uuidString: "00000000-0000-4000-8000-000000000008")!
        )
        try FileManager.default.createDirectory(
            at: layout.builtAgentTool.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("signed-tool-placeholder".utf8).write(to: layout.builtAgentTool)
        guard chmod(layout.builtAgentTool.path, 0o755) == 0 else {
            throw TestFailure(description: "chmod Step 7 tool placeholder failed: \(errno)")
        }

        let v1 = context.fixtureRoot
        let v2 = v1.deletingLastPathComponent().appendingPathComponent("v2", isDirectory: true)
        let v1Before = try snapshotTree(v1)
        let v2Before = try snapshotTree(v2)
        let result = try deriveStep7Marketplace(
            canonicalMarketplace: v2,
            builtAgentTool: layout.builtAgentTool,
            layout: layout
        )
        let derivedPlugin = result.marketplaceRoot.appendingPathComponent(
            "plugins/release-radar",
            isDirectory: true
        )
        try require(result.version == "1.1.0", "derived fixture version changed")
        let recomputedDigest = try deterministicPackageDigest(
            at: derivedPlugin,
            expectedDigest: nil
        )
        try require(
            result.digest == recomputedDigest,
            "derived fixture digest was not its own bytes"
        )
        let mcp = try strictJSONValue(
            Data(contentsOf: derivedPlugin.appendingPathComponent(".mcp.json"))
        )
        let releaseRadar = try required(
            (mcp as? [String: Any])?["release_radar"] as? [String: Any],
            "derived MCP entry missing"
        )
        try require(
            releaseRadar["command"] as? String == layout.builtAgentTool.path,
            "derived MCP command changed"
        )
        try require(releaseRadar["args"] as? [String] == [], "derived MCP args were not empty")
        let derivedHome = try context.directory("step7-derived-installed")
        let derivedTarget = installedTarget(in: derivedHome, version: result.version)
        try FileManager.default.createDirectory(
            at: derivedTarget.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: derivedPlugin, to: derivedTarget)
        let installedState = InstalledPluginDigester(
            homeDirectory: derivedHome,
            version: result.version,
            expectedDigests: [result.version: result.digest]
        ).classify()
        try require(
            installedState == .clean(version: result.version, digest: result.digest),
            "derived installed v2 digest did not equal the derived package digest"
        )
        let v1After = try snapshotTree(v1)
        let v2After = try snapshotTree(v2)
        try require(v1After == v1Before, "canonical v1 changed during derivation")
        try require(v2After == v2Before, "canonical v2 changed during derivation")
    }

    private static func step7BridgePreflightReduction() throws {
        let stopped = bridgePreflightReport(applicationRunning: false)
        try require(
            stopped == BridgePreflightReport(
                wireVersion: 1,
                ok: true,
                operation: .bridgePreflight,
                applicationRunning: false
            ),
            "stopped normal application did not pass preflight"
        )
        let running = bridgePreflightReport(applicationRunning: true)
        try require(
            running == BridgePreflightReport(
                wireVersion: 1,
                ok: false,
                operation: .bridgePreflight,
                applicationRunning: true
            ),
            "running normal app did not fail closed"
        )
    }

    private static func step7OwnedCLICancellationPlan() throws {
        let plan = Step7OwnedCLICancellationPlan.fixed
        try require(
            plan.executable.path == "/Applications/ChatGPT.app/Contents/Resources/codex",
            "owned cancellation executable changed"
        )
        try require(
            plan.arguments == [
                "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
            ],
            "owned cancellation arguments were not the fixed read-only query"
        )
        try require(plan.environment == [
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        ], "owned cancellation environment changed")
        try require(plan.startsSuspended, "owned cancellation no longer starts suspended")
        try require(plan.createsDedicatedProcessGroup, "owned cancellation lost its process group")
        try require(plan.maximumCleanupSeconds == 2, "owned cancellation cleanup bound changed")

        let report = OwnedCLICancellationReport(
            wireVersion: 1,
            ok: true,
            operation: .ownedCLICancellation,
            executableVerified: true,
            command: "fixedReadOnlyReleaseRadarPluginList",
            childPID: 321,
            processGroupID: 321,
            directChildVerified: true,
            dedicatedProcessGroupVerified: true,
            termSent: true,
            continueSent: true,
            killRequired: false,
            childReaped: true,
            processAbsent: true,
            processGroupAbsent: true
        )
        let object = try required(
            try strictJSONValue(JSONEncoder().encode(report)) as? [String: Any],
            "owned cancellation report was not an object"
        )
        try require((object["childPID"] as? NSNumber)?.intValue == 321, "child PID was not numeric")
        try require(
            (object["processGroupID"] as? NSNumber)?.intValue == 321,
            "process group ID was not numeric"
        )
    }

    private static func step7ExpectationsAndReport(context: SelfTestContext) throws {
        try require(
            Step7RuntimeExpectations.fixed == Step7RuntimeExpectations(
                skill: "release-radar",
                server: "release_radar",
                protocolVersion: "2025-06-18",
                serverName: "Release Radar",
                serverVersion: "1",
                tool: "release_radar_transition_ticket",
                acceptanceTest:
                    "AgentBridgeTransportAcceptanceTests."
                    + "testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp"
            ),
            "Step 7 runtime expectations changed"
        )
        let report = Step7PreparationReport(
            wireVersion: 1,
            ok: true,
            operation: .step7Prepare,
            artifactID: "00000000-0000-4000-8000-000000000009",
            fixtureVersion: "1.1.0",
            canonicalDigest: "fafb0d2027077c8f4a5efe2c9b422912d5a92c635417bb475d682c5c1f1c29b8",
            derivedDigest: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            canonicalFixturesUnchanged: true,
            builtAppVerified: true,
            builtAgentToolVerified: true,
            mcpTargetsBuiltAgentTool: true,
            nextAction: .controllerInstallDerivedPlugin,
            expectations: .fixed
        )
        let data = try JSONEncoder().encode(report)
        let text = try required(String(data: data, encoding: .utf8), "Step 7 report was not UTF-8")
        for forbidden in [
            context.runtimeRoot.path,
            "/Users/",
            "/.codex/",
            "/Applications/",
            "stdout",
            "stderr",
        ] {
            try require(!text.contains(forbidden), "Step 7 report exposed forbidden output")
        }
    }

    private static func timeout(context: SelfTestContext) throws {
        let pidFile = context.root.appendingPathComponent("timeout-pids")
        let started = DispatchTime.now().uptimeNanoseconds
        try expectFailure(.timeout) {
            _ = try runBoundedExecutable(
                executableURL: context.executableURL,
                arguments: ["internal-child", "timeout", "--pid-file", pidFile.path],
                currentDirectoryURL: try context.workingDirectory("timeout"),
                environment: context.fixedEnvironment,
                operation: .status,
                cliVersion: "self-test"
            )
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000
        try require(elapsed >= 14.5 && elapsed < 17.0, "timeout deadline was \(elapsed) seconds")
        try assertRecordedPIDsGone(pidFile)
    }

    private static func outputOverflow(context: SelfTestContext) throws {
        for stream in ["overflow-stdout", "overflow-stderr"] {
            let pidFile = context.root.appendingPathComponent("\(stream)-pids")
            try expectFailure(.outputOverflow) {
                _ = try runBoundedExecutable(
                    executableURL: context.executableURL,
                    arguments: ["internal-child", stream, "--pid-file", pidFile.path],
                    currentDirectoryURL: try context.workingDirectory(stream),
                    environment: context.fixedEnvironment,
                    operation: .status,
                    cliVersion: "self-test"
                )
            }
            try assertRecordedPIDsGone(pidFile)
        }
    }

    private static func bufferedExitOverflow(context: SelfTestContext) throws {
        for stream in ["fast-overflow-stdout", "fast-overflow-stderr"] {
            try expectFailure(.outputOverflow) {
                _ = try runBoundedExecutable(
                    executableURL: context.executableURL,
                    arguments: ["internal-child", stream, "--pid-file", context.root.appendingPathComponent("unused-\(stream)").path],
                    currentDirectoryURL: try context.workingDirectory(stream),
                    environment: context.fixedEnvironment,
                    operation: .status,
                    cliVersion: "self-test"
                )
            }
        }
    }

    private static func pipeReadError() throws {
        let capture = BoundedOutputCapture(limit: 1_048_576)
        readOutput(descriptor: -1, stream: .stdout, capture: capture)
        try expectFailure(.postcondition) {
            _ = try finalizedOutput(capture)
        }
    }

    private static func processGroupTermination(context: SelfTestContext) throws {
        let pidFile = context.root.appendingPathComponent("abnormal-pids")
        try expectFailure(.postcondition) {
            _ = try runBoundedExecutable(
                executableURL: context.executableURL,
                arguments: ["internal-child", "abnormal", "--pid-file", pidFile.path],
                currentDirectoryURL: try context.workingDirectory("abnormal"),
                environment: context.fixedEnvironment,
                operation: .status,
                cliVersion: "self-test"
            )
        }
        let pids = try recordedPIDs(pidFile)
        guard let groupLeader = pids.first else {
            throw TestFailure(description: "missing process group leader PID")
        }
        errno = 0
        let result = kill(-groupLeader, 0)
        try require(result == -1 && errno == ESRCH, "process group \(groupLeader) remains alive")
    }

    private static func descendantReaping(context: SelfTestContext) throws {
        let pidFile = context.root.appendingPathComponent("reaping-pids")
        try expectFailure(.postcondition) {
            _ = try runBoundedExecutable(
                executableURL: context.executableURL,
                arguments: ["internal-child", "abnormal", "--pid-file", pidFile.path],
                currentDirectoryURL: try context.workingDirectory("reaping"),
                environment: context.fixedEnvironment,
                operation: .status,
                cliVersion: "self-test"
            )
        }
        try assertRecordedPIDsGone(pidFile)
    }

    private static func recordedPIDs(_ file: URL) throws -> [pid_t] {
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: file.path), Date() < deadline {
            usleep(10_000)
        }
        let text = try String(contentsOf: file, encoding: .utf8)
        let pids = text.split(separator: "\n").compactMap { pid_t($0) }
        try require(pids.count == 2, "expected child and grandchild PIDs")
        return pids
    }

    private static func assertRecordedPIDsGone(_ file: URL) throws {
        let pids = try recordedPIDs(file)
        let deadline = Date().addingTimeInterval(2)
        for pid in pids {
            while processExists(pid), Date() < deadline {
                usleep(10_000)
            }
            try require(!processExists(pid), "PID \(pid) was not reaped")
        }
    }

    private static func processExists(_ pid: pid_t) -> Bool {
        errno = 0
        return kill(pid, 0) == 0 || errno == EPERM
    }

    private static func expectFailure(
        _ kind: ProbeFailure.Kind,
        _ body: () throws -> Void
    ) throws {
        do {
            try body()
        } catch let failure as ProbeFailure where failure.kind == kind {
            return
        } catch {
            throw TestFailure(description: "expected \(kind.rawValue), got \(error)")
        }
        throw TestFailure(description: "expected \(kind.rawValue), got success")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw TestFailure(description: message)
        }
    }

    private static func required<Value>(_ value: Value?, _ message: String) throws -> Value {
        guard let value else { throw TestFailure(description: message) }
        return value
    }
}

private struct ValidatedMarketplaceRoot: Equatable {
    let url: URL
    let pluginRoot: URL
    let version: String
    let digest: String
}

private struct MarketplaceSnapshot: Equatable {
    let targetRoot: String?
    let unrelatedFingerprint: String
}

private enum ControllerMode: String, Codable, Equatable {
    case preflight
    case lifecycle
    case reinstall
    case installedIntegrity = "installed-integrity"
    case legacyMCPPreflight = "legacy-mcp-preflight"
    case legacyMCPRemove = "legacy-mcp-remove"
    case legacyMCPRestore = "legacy-mcp-restore"
    case bundledMCPPreflight = "bundled-mcp-preflight"
    case step7Prepare = "step7-prepare"
    case bridgePreflight = "bridge-preflight"
    case ownedCLICancellation = "live-owned-cli-cancellation"
}

private enum ControllerTargetState: String, Codable, Equatable {
    case absent
}

private struct ControllerReport: Codable, Equatable {
    let wireVersion: Int
    let cliVersion: String
    let operation: ControllerMode
    let targetState: ControllerTargetState
    let unrelatedFingerprint: String
    let fixtureVersion: String
    let fixtureDigest: String
}

private enum LegacyMCPState: String, Codable, Equatable {
    case absent
    case exactLegacy = "exact-legacy"
}

private struct LegacyMCPControllerReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let operation: ControllerMode
    let state: LegacyMCPState
    let removalIssued: Bool
    let restorationIssued: Bool
}

private struct ControllerInvocation: Equatable {
    let mode: ControllerMode
    let fixtureRoot: String?
}

private enum Step7Constants {
    static let teamIdentifier = "2UA854NLX4"
    static let applicationBundleIdentifier = "com.rekonlabs.ReleaseRadar"
    static let agentToolBundleIdentifier = "com.rekonlabs.ReleaseRadarAgentTools"
    static let cliPath = "/Applications/ChatGPT.app/Contents/Resources/codex"
}

private struct Step7PreparationLayout {
    let packageRoot: URL
    let repositoryRoot: URL
    let artifactID: UUID

    init(packageRoot: URL, repositoryRoot: URL, artifactID: UUID) throws {
        let packageRoot = try canonicalExistingURL(packageRoot)
        let repositoryRoot = try canonicalExistingURL(repositoryRoot)
        try verifyPathComponents(packageRoot, finalType: S_IFDIR)
        try verifyPathComponents(repositoryRoot, finalType: S_IFDIR)
        guard FileManager.default.fileExists(
            atPath: repositoryRoot.appendingPathComponent("ReleaseRadar.xcodeproj").path
        ) else {
            throw ProbeFailure(kind: .untrusted)
        }
        self.packageRoot = packageRoot
        self.repositoryRoot = repositoryRoot
        self.artifactID = artifactID
    }

    var derivedDataRoot: URL {
        packageRoot.appendingPathComponent("DerivedData", isDirectory: true)
    }

    var buildWorkingDirectory: URL {
        packageRoot.appendingPathComponent("build-cwd", isDirectory: true)
    }

    var builtApp: URL {
        derivedDataRoot.appendingPathComponent(
            "Build/Products/Debug/ReleaseRadar.app",
            isDirectory: true
        )
    }

    var builtAgentTool: URL {
        builtApp.appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
    }

    var derivedMarketplaceRoot: URL {
        packageRoot.appendingPathComponent("derived-marketplace-v2", isDirectory: true)
    }
}

private struct Step7BuildPlan: Equatable {
    let executable: URL
    let arguments: [String]
    let environment: [String: String]
    let workingDirectory: URL
    let expectedApp: URL
    let expectedAgentTool: URL
}

private func makeStep7BuildPlan(layout: Step7PreparationLayout) throws -> Step7BuildPlan {
    if !FileManager.default.fileExists(atPath: layout.buildWorkingDirectory.path) {
        try FileManager.default.createDirectory(
            at: layout.buildWorkingDirectory,
            withIntermediateDirectories: false
        )
    }
    guard (try? FileManager.default.contentsOfDirectory(
        atPath: layout.buildWorkingDirectory.path
    ))?.isEmpty == true else {
        throw ProbeFailure(kind: .untrusted)
    }
    return Step7BuildPlan(
        executable: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
        arguments: [
            "build",
            "-project", layout.repositoryRoot.appendingPathComponent("ReleaseRadar.xcodeproj").path,
            "-scheme", "ReleaseRadar",
            "-configuration", "Debug",
            "-destination", "platform=macOS",
            "-derivedDataPath", layout.derivedDataRoot.path,
        ],
        environment: ["LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"],
        workingDirectory: layout.buildWorkingDirectory,
        expectedApp: layout.builtApp,
        expectedAgentTool: layout.builtAgentTool
    )
}

private struct Step7DerivedMarketplace: Equatable {
    let marketplaceRoot: URL
    let version: String
    let digest: String
}

private func deriveStep7Marketplace(
    canonicalMarketplace: URL,
    builtAgentTool: URL,
    layout: Step7PreparationLayout
) throws -> Step7DerivedMarketplace {
    let canonicalMarketplace = try canonicalExistingURL(canonicalMarketplace)
    try verifyPathComponents(canonicalMarketplace, finalType: S_IFDIR)
    _ = try supportedMarketplaceManifestURL(in: canonicalMarketplace)
    let canonicalPlugin = canonicalMarketplace.appendingPathComponent(
        "plugins/release-radar",
        isDirectory: true
    )
    try verifyPathComponents(canonicalPlugin, finalType: S_IFDIR)
    guard try fixturePluginVersion(at: canonicalPlugin) == "1.1.0" else {
        throw ProbeFailure(kind: .untrusted)
    }

    try verifyNoSymlinkBelowAllowedRoot(
        builtAgentTool,
        allowedRoots: [layout.derivedDataRoot],
        finalType: S_IFREG
    )
    let builtAgentTool = try requireConfinedPath(
        builtAgentTool,
        allowedRoots: [layout.derivedDataRoot]
    )
    var toolMetadata = stat()
    guard lstat(builtAgentTool.path, &toolMetadata) == 0,
          toolMetadata.st_mode & S_IFMT == S_IFREG,
          toolMetadata.st_mode & 0o111 != 0 else {
        throw ProbeFailure(kind: .untrusted)
    }

    guard !FileManager.default.fileExists(atPath: layout.derivedMarketplaceRoot.path) else {
        throw ProbeFailure(kind: .conflict)
    }
    do {
        try FileManager.default.copyItem(
            at: canonicalMarketplace,
            to: layout.derivedMarketplaceRoot
        )
    } catch {
        throw ProbeFailure(kind: .unavailable)
    }
    let derivedPlugin = layout.derivedMarketplaceRoot.appendingPathComponent(
        "plugins/release-radar",
        isDirectory: true
    )
    let mcp = derivedPlugin.appendingPathComponent(".mcp.json")
    let mcpObject: [String: Any] = [
        "release_radar": [
            "command": builtAgentTool.path,
            "args": [String](),
        ] as [String: Any],
    ]
    let mcpData: Data
    do {
        var data = try JSONSerialization.data(
            withJSONObject: mcpObject,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0a)
        mcpData = data
    } catch {
        throw ProbeFailure(kind: .postcondition)
    }
    do {
        try mcpData.write(to: mcp, options: .atomic)
    } catch {
        throw ProbeFailure(kind: .unavailable)
    }

    let written = try strictJSONValue(readStableRegularFile(mcp))
    guard let servers = written as? [String: Any],
          servers.count == 1,
          let releaseRadar = servers["release_radar"] as? [String: Any],
          releaseRadar.count == 2,
          releaseRadar["command"] as? String == builtAgentTool.path,
          releaseRadar["args"] as? [String] == [] else {
        throw ProbeFailure(kind: .postcondition)
    }
    return Step7DerivedMarketplace(
        marketplaceRoot: layout.derivedMarketplaceRoot,
        version: "1.1.0",
        digest: try deterministicPackageDigest(at: derivedPlugin, expectedDigest: nil)
    )
}

private struct Step7RuntimeExpectations: Codable, Equatable {
    let skill: String
    let server: String
    let protocolVersion: String
    let serverName: String
    let serverVersion: String
    let tool: String
    let acceptanceTest: String

    static let fixed = Step7RuntimeExpectations(
        skill: "release-radar",
        server: "release_radar",
        protocolVersion: "2025-06-18",
        serverName: "Release Radar",
        serverVersion: "1",
        tool: "release_radar_transition_ticket",
        acceptanceTest:
            "AgentBridgeTransportAcceptanceTests."
            + "testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp"
    )
}

private enum Step7NextAction: String, Codable, Equatable {
    case controllerInstallDerivedPlugin
}

private struct Step7PreparationReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let operation: ControllerMode
    let artifactID: String
    let fixtureVersion: String
    let canonicalDigest: String
    let derivedDigest: String
    let canonicalFixturesUnchanged: Bool
    let builtAppVerified: Bool
    let builtAgentToolVerified: Bool
    let mcpTargetsBuiltAgentTool: Bool
    let nextAction: Step7NextAction
    let expectations: Step7RuntimeExpectations
}

private struct BridgePreflightReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let operation: ControllerMode
    let applicationRunning: Bool
}

private func bridgePreflightReport(applicationRunning: Bool) -> BridgePreflightReport {
    BridgePreflightReport(
        wireVersion: 1,
        ok: !applicationRunning,
        operation: .bridgePreflight,
        applicationRunning: applicationRunning
    )
}

private struct Step7OwnedCLICancellationPlan: Equatable {
    let executable: URL
    let arguments: [String]
    let environment: [String: String]
    let startsSuspended: Bool
    let createsDedicatedProcessGroup: Bool
    let maximumCleanupSeconds: Int

    static let fixed = Step7OwnedCLICancellationPlan(
        executable: URL(fileURLWithPath: Step7Constants.cliPath),
        arguments: [
            "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
        ],
        environment: ["LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"],
        startsSuspended: true,
        createsDedicatedProcessGroup: true,
        maximumCleanupSeconds: 2
    )
}

private struct OwnedCLICancellationReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let operation: ControllerMode
    let executableVerified: Bool
    let command: String
    let childPID: pid_t
    let processGroupID: pid_t
    let directChildVerified: Bool
    let dedicatedProcessGroupVerified: Bool
    let termSent: Bool
    let continueSent: Bool
    let killRequired: Bool
    let childReaped: Bool
    let processAbsent: Bool
    let processGroupAbsent: Bool
}

private struct ControllerFailureReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let error: ProbeFailure.Kind
}

private typealias ControllerInvoke = ([String], ProbeOperation) throws -> ProbeResult

private enum ReinstallControllerObservedState: String, Codable, Equatable {
    case installed
    case needsRepair
}

private enum ReinstallControllerError: String, Codable, Equatable {
    case partialReinstall
}

private struct ReinstallControllerReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let operation: ControllerMode
    let observedState: ReinstallControllerObservedState
    let error: ReinstallControllerError?
    let removeSucceeded: Bool
    let addAttemptCount: Int
    let retryAttempted: Bool
}

private enum InstalledIntegrityControllerClassification: String, Codable, Equatable {
    case absent
    case clean
    case modified
    case needsRepair
}

private struct InstalledIntegrityControllerReport: Codable, Equatable {
    let wireVersion: Int
    let ok: Bool
    let classification: InstalledIntegrityControllerClassification
    let version: String?
    let digest: String?
    let error: InstalledPluginIntegrityError?
}

private enum InstalledIntegrityTargetObservation: Equatable {
    case absent
    case installed(version: String)
}

private func parseControllerInvocation(_ arguments: [String]) throws -> ControllerInvocation {
    if arguments.count == 1,
       let mode = ControllerMode(rawValue: arguments[0]),
       [
           ControllerMode.installedIntegrity,
           .reinstall,
           .legacyMCPPreflight,
           .legacyMCPRemove,
           .legacyMCPRestore,
           .bundledMCPPreflight,
           .bridgePreflight,
           .ownedCLICancellation,
       ].contains(mode) {
        return ControllerInvocation(mode: mode, fixtureRoot: nil)
    }
    guard arguments.count == 3,
          let mode = ControllerMode(rawValue: arguments[0]),
          mode != .installedIntegrity,
          mode != .reinstall,
          mode != .legacyMCPPreflight,
          mode != .legacyMCPRemove,
          mode != .legacyMCPRestore,
          mode != .bundledMCPPreflight,
          mode != .bridgePreflight,
          mode != .ownedCLICancellation,
          arguments[1] == "--fixture-root",
          !arguments[2].isEmpty,
          !arguments[2].utf8.contains(0) else {
        throw ProbeFailure(kind: .untrusted)
    }
    return ControllerInvocation(mode: mode, fixtureRoot: arguments[2])
}

private let legacyMCPGetCommand = ["mcp", "get", "release-radar", "--json"]
private let legacyMCPRemoveCommand = ["mcp", "remove", "release-radar"]
private let legacyMCPAddCommand = [
    "mcp", "add", "release-radar", "--",
    "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools",
]
private let legacyMCPAbsenceError = Data(
    "Error: No MCP server named 'release-radar' found.\n".utf8
)
private let bundledMCPGetCommand = ["mcp", "get", "release_radar", "--json"]
private let bundledMCPAbsenceError = Data(
    "Error: No MCP server named 'release_radar' found.\n".utf8
)

private func parseBundledMCPAbsence(_ result: ProbeResult) throws -> LegacyMCPState {
    guard result.exitStatus == 1,
          result.stdout.isEmpty,
          result.stderr == bundledMCPAbsenceError else {
        throw ProbeFailure(kind: .postcondition)
    }
    return .absent
}

private func parseLegacyMCPObservation(_ result: ProbeResult) throws -> LegacyMCPState {
    if result.exitStatus == 1,
       result.stdout.isEmpty,
       result.stderr == legacyMCPAbsenceError {
        return .absent
    }
    guard result.exitStatus == 0,
          result.stderr.isEmpty else {
        throw ProbeFailure(kind: .postcondition)
    }

    try rejectDuplicateJSONKeys(result.stdout)
    let value = try strictJSONValue(result.stdout)
    guard let entry = value as? [String: Any],
          entry["name"] != nil,
          entry["enabled"] != nil,
          entry["disabled_reason"] != nil,
          entry["transport"] != nil else {
        throw ProbeFailure(kind: .conflict)
    }
    guard entry["name"] as? String == "release-radar",
          let enabled = entry["enabled"] as? NSNumber,
          CFGetTypeID(enabled) == CFBooleanGetTypeID(),
          enabled.boolValue,
          entry["disabled_reason"] is NSNull,
          let transport = entry["transport"] as? [String: Any],
          transport["type"] as? String == "stdio",
          transport["command"] as? String
            == "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools",
          let arguments = transport["args"] as? [Any],
          arguments.isEmpty,
          let environment = transport["env"],
          isNullOrEmptyLegacyMCPEnvironmentObject(environment),
          transport["cwd"] is NSNull else {
        throw ProbeFailure(kind: .conflict)
    }
    if let environmentVariables = transport["env_vars"],
       !isNullOrEmptyLegacyMCPEnvironmentVariableList(environmentVariables) {
        throw ProbeFailure(kind: .conflict)
    }
    for field in [
        "enabled_tools",
        "disabled_tools",
        "startup_timeout_sec",
        "tool_timeout_sec",
    ] where entry[field] != nil && !(entry[field] is NSNull) {
        throw ProbeFailure(kind: .conflict)
    }
    return .exactLegacy
}

private func isNullOrEmptyLegacyMCPEnvironmentObject(_ value: Any) -> Bool {
    if value is NSNull {
        return true
    }
    if let dictionary = value as? [String: Any] {
        return dictionary.isEmpty
    }
    return false
}

private func isNullOrEmptyLegacyMCPEnvironmentVariableList(_ value: Any) -> Bool {
    if value is NSNull {
        return true
    }
    if let array = value as? [Any] {
        return array.isEmpty
    }
    return false
}

private func runLegacyMCPController(
    _ mode: ControllerMode,
    invoke: ControllerInvoke
) throws -> LegacyMCPControllerReport {
    guard [
        ControllerMode.legacyMCPPreflight,
        .legacyMCPRemove,
        .legacyMCPRestore,
        .bundledMCPPreflight,
    ].contains(mode) else {
        throw ProbeFailure(kind: .untrusted)
    }

    if mode == .bundledMCPPreflight {
        return LegacyMCPControllerReport(
            wireVersion: 1,
            ok: true,
            operation: mode,
            state: try parseBundledMCPAbsence(
                invoke(bundledMCPGetCommand, .status)
            ),
            removalIssued: false,
            restorationIssued: false
        )
    }

    let initial = try parseLegacyMCPObservation(
        invoke(legacyMCPGetCommand, .status)
    )
    if mode == .legacyMCPPreflight || (mode == .legacyMCPRemove && initial == .absent) {
        return LegacyMCPControllerReport(
            wireVersion: 1,
            ok: true,
            operation: mode,
            state: initial,
            removalIssued: false,
            restorationIssued: false
        )
    }
    if mode == .legacyMCPRestore {
        let restorationIssued = try restoreLegacyMCP(
            from: initial,
            invoke: invoke
        )
        return LegacyMCPControllerReport(
            wireVersion: 1,
            ok: true,
            operation: mode,
            state: .exactLegacy,
            removalIssued: false,
            restorationIssued: restorationIssued
        )
    }

    do {
        _ = try invoke(legacyMCPRemoveCommand, .remove)
    } catch {
        let primaryFailure = error
        let cleanupObservation = try parseLegacyMCPObservation(
            invoke(legacyMCPGetCommand, .status)
        )
        _ = try restoreLegacyMCP(from: cleanupObservation, invoke: invoke)
        throw primaryFailure
    }
    guard try parseLegacyMCPObservation(
        invoke(legacyMCPGetCommand, .status)
    ) == .absent else {
        throw ProbeFailure(kind: .postcondition)
    }
    return LegacyMCPControllerReport(
        wireVersion: 1,
        ok: true,
        operation: mode,
        state: .absent,
        removalIssued: true,
        restorationIssued: false
    )
}

private func restoreLegacyMCP(
    from observation: LegacyMCPState,
    invoke: ControllerInvoke
) throws -> Bool {
    if observation == .exactLegacy {
        return false
    }
    _ = try invoke(legacyMCPAddCommand, .install)
    guard try parseLegacyMCPObservation(
        invoke(legacyMCPGetCommand, .status)
    ) == .exactLegacy else {
        throw ProbeFailure(kind: .postcondition)
    }
    return true
}

private func runReinstallController(
    invoke: ControllerInvoke
) throws -> ReinstallControllerReport {
    let targetedPluginList = [
        "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
    ]
    let pluginRemove = ["plugin", "remove", "release-radar@release-radar", "--json"]
    let pluginAdd = ["plugin", "add", "release-radar@release-radar", "--json"]

    let observation = try parseInstalledIntegrityTargetedList(
        invoke(targetedPluginList, .status).stdout
    )
    guard case .installed(let version) = observation else {
        throw ProbeFailure(kind: .postcondition)
    }

    try parsePluginRemoveResponse(
        invoke(pluginRemove, .remove).stdout
    )

    do {
        try parsePluginAddResponse(
            invoke(pluginAdd, .reinstall).stdout,
            expectedVersion: version
        )
    } catch {
        return ReinstallControllerReport(
            wireVersion: 1,
            ok: false,
            operation: .reinstall,
            observedState: .needsRepair,
            error: .partialReinstall,
            removeSucceeded: true,
            addAttemptCount: 1,
            retryAttempted: false
        )
    }

    return ReinstallControllerReport(
        wireVersion: 1,
        ok: true,
        operation: .reinstall,
        observedState: .installed,
        error: nil,
        removeSucceeded: true,
        addAttemptCount: 1,
        retryAttempted: false
    )
}

private func runInstalledIntegrityController(
    invoke: ControllerInvoke,
    resolveHome: () throws -> URL = effectiveUserHomeDirectory
) throws -> InstalledIntegrityControllerReport {
    let targetedPluginList = [
        "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
    ]
    let observation = try parseInstalledIntegrityTargetedList(
        invoke(targetedPluginList, .status).stdout
    )
    guard case .installed(let version) = observation else {
        return InstalledIntegrityControllerReport(
            wireVersion: 1,
            ok: true,
            classification: .absent,
            version: nil,
            digest: nil,
            error: nil
        )
    }

    let state: InstalledPluginIntegrityState
    do {
        state = InstalledPluginDigester(
            homeDirectory: try resolveHome(),
            version: version,
            expectedDigests: recognizedInstalledPluginDigests
        ).classify()
    } catch {
        state = .needsRepair(.integrityUnknown)
    }
    switch state {
    case .clean(let observedVersion, let digest):
        return InstalledIntegrityControllerReport(
            wireVersion: 1,
            ok: true,
            classification: .clean,
            version: observedVersion,
            digest: digest,
            error: nil
        )
    case .modified(let observedVersion, let digest):
        return InstalledIntegrityControllerReport(
            wireVersion: 1,
            ok: true,
            classification: .modified,
            version: observedVersion,
            digest: digest,
            error: nil
        )
    case .needsRepair(let error):
        return InstalledIntegrityControllerReport(
            wireVersion: 1,
            ok: false,
            classification: .needsRepair,
            version: nil,
            digest: nil,
            error: error
        )
    }
}

private func runControllerMode(
    _ mode: ControllerMode,
    marketplaceRoot: ValidatedMarketplaceRoot,
    cliVersion: String,
    invoke: ControllerInvoke
) throws -> ControllerReport {
    guard mode == .preflight || mode == .lifecycle else {
        throw ProbeFailure(kind: .untrusted)
    }
    let marketplaceList = ["plugin", "marketplace", "list", "--json"]
    let targetedPluginList = [
        "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
    ]
    let before = try parseMarketplaceSnapshot(
        invoke(marketplaceList, .status).stdout
    )
    try requireAbsentTarget(before)

    if mode == .preflight {
        return ControllerReport(
            wireVersion: 1,
            cliVersion: cliVersion,
            operation: mode,
            targetState: .absent,
            unrelatedFingerprint: before.unrelatedFingerprint,
            fixtureVersion: marketplaceRoot.version,
            fixtureDigest: marketplaceRoot.digest
        )
    }
    var primaryFailure: Error?
    do {
        try parseMarketplaceAddResponse(
            invoke(
                ["plugin", "marketplace", "add", marketplaceRoot.url.path, "--json"],
                .install
            ).stdout,
            expectedRoot: marketplaceRoot.url.path
        )
        let afterAdd = try parseMarketplaceSnapshot(
            invoke(marketplaceList, .status).stdout,
            expectedTargetRoot: marketplaceRoot.url.path
        )
        guard afterAdd.targetRoot == marketplaceRoot.url.path else {
            throw ProbeFailure(kind: .postcondition)
        }
        try requirePluginObservation(
            .available,
            data: invoke(targetedPluginList, .status).stdout,
            marketplaceRoot: marketplaceRoot
        )
        try parsePluginAddResponse(
            invoke(
                ["plugin", "add", "release-radar@release-radar", "--json"],
                .install
            ).stdout,
            expectedVersion: marketplaceRoot.version
        )
        try requirePluginObservation(
            .installed,
            data: invoke(targetedPluginList, .status).stdout,
            marketplaceRoot: marketplaceRoot
        )
        try parsePluginRemoveResponse(
            invoke(
                ["plugin", "remove", "release-radar@release-radar", "--json"],
                .remove
            ).stdout
        )
        try requirePluginObservation(
            .available,
            data: invoke(targetedPluginList, .status).stdout,
            marketplaceRoot: marketplaceRoot
        )
        try parsePluginAddResponse(
            invoke(
                ["plugin", "add", "release-radar@release-radar", "--json"],
                .reinstall
            ).stdout,
            expectedVersion: marketplaceRoot.version
        )
        try requirePluginObservation(
            .installed,
            data: invoke(targetedPluginList, .status).stdout,
            marketplaceRoot: marketplaceRoot
        )
    } catch {
        primaryFailure = error
    }

    try cleanupControllerTarget(
        before: before,
        marketplaceRoot: marketplaceRoot,
        invoke: invoke
    )
    if let primaryFailure {
        throw primaryFailure
    }
    return ControllerReport(
        wireVersion: 1,
        cliVersion: cliVersion,
        operation: mode,
        targetState: .absent,
        unrelatedFingerprint: before.unrelatedFingerprint,
        fixtureVersion: marketplaceRoot.version,
        fixtureDigest: marketplaceRoot.digest
    )
}

private func cleanupControllerTarget(
    before: MarketplaceSnapshot,
    marketplaceRoot: ValidatedMarketplaceRoot,
    invoke: ControllerInvoke
) throws {
    let marketplaceList = ["plugin", "marketplace", "list", "--json"]
    let targetedPluginList = [
        "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
    ]
    let current = try parseMarketplaceSnapshot(
        invoke(marketplaceList, .status).stdout,
        expectedTargetRoot: marketplaceRoot.url.path
    )
    if current.targetRoot != nil {
        do {
            let removeResult = try invoke(
                ["plugin", "remove", "release-radar@release-radar", "--json"],
                .remove
            )
            try parsePluginRemoveResponse(removeResult.stdout)
        } catch {}
        try requirePluginObservation(
            .available,
            data: invoke(targetedPluginList, .status).stdout,
            marketplaceRoot: marketplaceRoot
        )
        do {
            let removeResult = try invoke(
                ["plugin", "marketplace", "remove", "release-radar", "--json"],
                .remove
            )
            try parseMarketplaceRemoveResponse(removeResult.stdout)
        } catch {}
    }
    let finalResult = try invoke(
        marketplaceList,
        .status
    )
    let after = try parseMarketplaceSnapshot(finalResult.stdout)
    guard after.targetRoot == nil,
          after.unrelatedFingerprint == before.unrelatedFingerprint else {
        throw ProbeFailure(kind: .postcondition)
    }
    try requirePluginObservation(
        .absent,
        data: invoke(targetedPluginList, .status).stdout,
        marketplaceRoot: marketplaceRoot
    )
}

private func parseMarketplaceSnapshot(
    _ data: Data,
    expectedTargetRoot: String? = nil
) throws -> MarketplaceSnapshot {
    let object = try strictJSONValue(data)
    guard let envelope = object as? [String: Any],
          Set(envelope.keys) == ["marketplaces"],
          let marketplaces = envelope["marketplaces"] as? [Any] else {
        throw ProbeFailure(kind: .malformedJSON)
    }

    var targetRoot: String?
    var unrelated = [Any]()
    for value in marketplaces {
        guard let entry = value as? [String: Any],
              Set(entry.keys).isSubset(of: ["name", "root", "marketplaceSource"]),
              let name = entry["name"] as? String,
              !name.isEmpty,
              let root = entry["root"] as? String,
              !root.isEmpty else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        if let source = entry["marketplaceSource"], !(source is [String: Any]) {
            throw ProbeFailure(kind: .malformedJSON)
        }
        if name == "release-radar" {
            guard targetRoot == nil else {
                throw ProbeFailure(kind: .conflict)
            }
            guard Set(entry.keys) == ["name", "root", "marketplaceSource"],
                  let marketplaceSource = entry["marketplaceSource"] as? [String: Any],
                  Set(marketplaceSource.keys) == ["sourceType", "source"],
                  marketplaceSource["sourceType"] as? String == "local",
                  marketplaceSource["source"] as? String == root else {
                throw ProbeFailure(kind: .malformedJSON)
            }
            if let expectedTargetRoot, root != expectedTargetRoot {
                throw ProbeFailure(kind: .conflict)
            }
            targetRoot = root
        } else {
            unrelated.append(entry)
        }
    }
    let canonicalUnrelated = try canonicalUnorderedArrayData(unrelated)
    let fingerprint = SHA256.hash(data: canonicalUnrelated)
        .map { String(format: "%02x", $0) }
        .joined()
    return MarketplaceSnapshot(
        targetRoot: targetRoot,
        unrelatedFingerprint: fingerprint
    )
}

private func requireAbsentTarget(_ snapshot: MarketplaceSnapshot) throws {
    guard snapshot.targetRoot == nil else {
        throw ProbeFailure(kind: .conflict)
    }
}

private enum PluginObservation: Equatable {
    case absent
    case available
    case installed
}

private func parseInstalledIntegrityTargetedList(
    _ data: Data
) throws -> InstalledIntegrityTargetObservation {
    let object = try strictJSONValue(data)
    guard let envelope = object as? [String: Any],
          Set(envelope.keys) == ["installed", "available"],
          let installed = envelope["installed"] as? [Any],
          let available = envelope["available"] as? [Any] else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    if installed.isEmpty, available.isEmpty {
        return .absent
    }
    if installed.isEmpty, available.count == 1 {
        _ = try installedIntegrityPluginVersion(available[0], expectedInstalled: false)
        return .absent
    }
    guard installed.count == 1, available.isEmpty else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    return .installed(
        version: try installedIntegrityPluginVersion(installed[0], expectedInstalled: true)
    )
}

private func installedIntegrityPluginVersion(
    _ value: Any,
    expectedInstalled: Bool
) throws -> String {
    guard let plugin = value as? [String: Any],
          Set(plugin.keys) == [
              "pluginId", "name", "marketplaceName", "version", "installed",
              "enabled", "source", "marketplaceSource", "installPolicy", "authPolicy",
          ],
          plugin["pluginId"] as? String == "release-radar@release-radar",
          plugin["name"] as? String == "release-radar",
          plugin["marketplaceName"] as? String == "release-radar",
          let version = plugin["version"] as? String,
          isStrictSemVer(version),
          plugin["installed"] as? Bool == expectedInstalled,
          plugin["enabled"] as? Bool == expectedInstalled,
          plugin["installPolicy"] as? String == "AVAILABLE",
          plugin["authPolicy"] as? String == "ON_INSTALL",
          let source = plugin["source"] as? [String: Any],
          Set(source.keys) == ["source", "path"],
          source["source"] as? String == "local",
          let sourcePath = source["path"] as? String,
          let marketplaceSource = plugin["marketplaceSource"] as? [String: Any],
          Set(marketplaceSource.keys) == ["sourceType", "source"],
          marketplaceSource["sourceType"] as? String == "local",
          let marketplaceRoot = marketplaceSource["source"] as? String,
          marketplaceRoot.hasPrefix("/"),
          sourcePath == "\(marketplaceRoot)/plugins/release-radar" else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    return version
}

private func parsePluginList(
    _ data: Data,
    expectedRoot: String,
    expectedVersion: String
) throws -> PluginObservation {
    let object = try strictJSONValue(data)
    guard let envelope = object as? [String: Any],
          Set(envelope.keys) == ["installed", "available"],
          let installed = envelope["installed"] as? [Any],
          let available = envelope["available"] as? [Any] else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    if installed.isEmpty, available.isEmpty {
        return .absent
    }
    let observation: PluginObservation
    let entry: Any
    if installed.count == 1, available.isEmpty {
        observation = .installed
        entry = installed[0]
    } else if installed.isEmpty, available.count == 1 {
        observation = .available
        entry = available[0]
    } else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    guard let plugin = entry as? [String: Any],
          Set(plugin.keys) == [
              "pluginId", "name", "marketplaceName", "version", "installed",
              "enabled", "source", "marketplaceSource", "installPolicy", "authPolicy",
          ],
          plugin["pluginId"] as? String == "release-radar@release-radar",
          plugin["name"] as? String == "release-radar",
          plugin["marketplaceName"] as? String == "release-radar",
          plugin["version"] as? String == expectedVersion,
          plugin["installed"] as? Bool == (observation == .installed),
          plugin["enabled"] as? Bool == (observation == .installed),
          plugin["installPolicy"] as? String == "AVAILABLE",
          plugin["authPolicy"] as? String == "ON_INSTALL",
          let source = plugin["source"] as? [String: Any],
          Set(source.keys) == ["source", "path"],
          source["source"] as? String == "local",
          source["path"] as? String == "\(expectedRoot)/plugins/release-radar",
          let marketplaceSource = plugin["marketplaceSource"] as? [String: Any],
          Set(marketplaceSource.keys) == ["sourceType", "source"],
          marketplaceSource["sourceType"] as? String == "local",
          marketplaceSource["source"] as? String == expectedRoot else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    return observation
}

private func requirePluginObservation(
    _ expected: PluginObservation,
    data: Data,
    marketplaceRoot: ValidatedMarketplaceRoot
) throws {
    guard try parsePluginList(
        data,
        expectedRoot: marketplaceRoot.url.path,
        expectedVersion: marketplaceRoot.version
    ) == expected else {
        throw ProbeFailure(kind: .postcondition)
    }
}

private func parseMarketplaceAddResponse(_ data: Data, expectedRoot: String) throws {
    let object = try strictJSONValue(data)
    guard let response = object as? [String: Any],
          Set(response.keys) == ["marketplaceName", "installedRoot", "alreadyAdded"],
          response["marketplaceName"] as? String == "release-radar",
          response["installedRoot"] as? String == expectedRoot,
          response["alreadyAdded"] as? Bool == false else {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func parsePluginAddResponse(_ data: Data, expectedVersion: String) throws {
    let object = try strictJSONValue(data)
    guard let response = object as? [String: Any],
          Set(response.keys) == [
              "pluginId", "name", "marketplaceName", "version", "installedPath", "authPolicy",
          ],
          response["pluginId"] as? String == "release-radar@release-radar",
          response["name"] as? String == "release-radar",
          response["marketplaceName"] as? String == "release-radar",
          response["version"] as? String == expectedVersion,
          response["authPolicy"] as? String == "ON_INSTALL",
          let installedPath = response["installedPath"] as? String,
          installedPath.hasPrefix("/"),
          installedPath.hasSuffix("/release-radar/release-radar/\(expectedVersion)") else {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func parsePluginRemoveResponse(_ data: Data) throws {
    let object = try strictJSONValue(data)
    guard let response = object as? [String: Any],
          Set(response.keys) == ["pluginId", "name", "marketplaceName"],
          response["pluginId"] as? String == "release-radar@release-radar",
          response["name"] as? String == "release-radar",
          response["marketplaceName"] as? String == "release-radar" else {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func parseMarketplaceRemoveResponse(_ data: Data) throws {
    let object = try strictJSONValue(data)
    guard let response = object as? [String: Any],
          Set(response.keys) == ["marketplaceName", "installedRoot"],
          response["marketplaceName"] as? String == "release-radar",
          response["installedRoot"] is NSNull else {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func rejectDuplicateJSONKeys(_ data: Data) throws {
    var scanner = DuplicateJSONKeyScanner(data: data)
    try scanner.validate()
}

private struct DuplicateJSONKeyScanner {
    private let bytes: [UInt8]
    private var index = 0

    init(data: Data) {
        bytes = Array(data)
    }

    mutating func validate() throws {
        try parseValue()
        skipWhitespace()
        guard index == bytes.count else {
            throw ProbeFailure(kind: .malformedJSON)
        }
    }

    private mutating func parseValue() throws {
        skipWhitespace()
        guard let byte = current else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        switch byte {
        case 0x7b:
            try parseObject()
        case 0x5b:
            try parseArray()
        case 0x22:
            _ = try parseString()
        case 0x74:
            try consumeLiteral("true")
        case 0x66:
            try consumeLiteral("false")
        case 0x6e:
            try consumeLiteral("null")
        case 0x2d, 0x30...0x39:
            try parseNumber()
        default:
            throw ProbeFailure(kind: .malformedJSON)
        }
    }

    private mutating func parseObject() throws {
        index += 1
        skipWhitespace()
        if consume(0x7d) { return }
        var keys = Set<String>()
        while true {
            let key = try parseString()
            guard keys.insert(key).inserted else {
                throw ProbeFailure(kind: .malformedJSON)
            }
            skipWhitespace()
            guard consume(0x3a) else {
                throw ProbeFailure(kind: .malformedJSON)
            }
            try parseValue()
            skipWhitespace()
            if consume(0x7d) { return }
            guard consume(0x2c) else {
                throw ProbeFailure(kind: .malformedJSON)
            }
            skipWhitespace()
        }
    }

    private mutating func parseArray() throws {
        index += 1
        skipWhitespace()
        if consume(0x5d) { return }
        while true {
            try parseValue()
            skipWhitespace()
            if consume(0x5d) { return }
            guard consume(0x2c) else {
                throw ProbeFailure(kind: .malformedJSON)
            }
        }
    }

    private mutating func parseString() throws -> String {
        skipWhitespace()
        guard current == 0x22 else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        let start = index
        index += 1
        while let byte = current {
            if byte == 0x22 {
                index += 1
                let literal = Data(bytes[start..<index])
                do {
                    guard let value = try JSONSerialization.jsonObject(
                        with: literal,
                        options: [.fragmentsAllowed]
                    ) as? String else {
                        throw ProbeFailure(kind: .malformedJSON)
                    }
                    return value
                } catch let failure as ProbeFailure {
                    throw failure
                } catch {
                    throw ProbeFailure(kind: .malformedJSON)
                }
            }
            if byte < 0x20 {
                throw ProbeFailure(kind: .malformedJSON)
            }
            if byte == 0x5c {
                index += 1
                guard current != nil else {
                    throw ProbeFailure(kind: .malformedJSON)
                }
            }
            index += 1
        }
        throw ProbeFailure(kind: .malformedJSON)
    }

    private mutating func parseNumber() throws {
        _ = consume(0x2d)
        if consume(0x30) {
            if let byte = current, (0x30...0x39).contains(byte) {
                throw ProbeFailure(kind: .malformedJSON)
            }
        } else {
            try consumeDigits(firstRange: 0x31...0x39)
        }
        if consume(0x2e) {
            try consumeDigits(firstRange: 0x30...0x39)
        }
        if current == 0x65 || current == 0x45 {
            index += 1
            if current == 0x2b || current == 0x2d {
                index += 1
            }
            try consumeDigits(firstRange: 0x30...0x39)
        }
    }

    private mutating func consumeDigits(firstRange: ClosedRange<UInt8>) throws {
        guard let first = current, firstRange.contains(first) else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        index += 1
        while let byte = current, (0x30...0x39).contains(byte) {
            index += 1
        }
    }

    private mutating func consumeLiteral(_ literal: StaticString) throws {
        let expected = Array(String(describing: literal).utf8)
        guard index + expected.count <= bytes.count,
              Array(bytes[index..<(index + expected.count)]) == expected else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        index += expected.count
    }

    private mutating func skipWhitespace() {
        while let byte = current, [0x20, 0x09, 0x0a, 0x0d].contains(byte) {
            index += 1
        }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard current == byte else { return false }
        index += 1
        return true
    }

    private var current: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }
}

private func strictJSONValue(_ data: Data) throws -> Any {
    do {
        guard String(data: data, encoding: .utf8) != nil else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        return try JSONSerialization.jsonObject(with: data, options: [])
    } catch let failure as ProbeFailure {
        throw failure
    } catch {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func parseCLIVersion(_ data: Data) throws -> String {
    guard data.count <= 256,
          let text = String(data: data, encoding: .utf8) else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    let version = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !version.isEmpty,
          version.hasPrefix("codex"),
          !version.contains("\n"),
          !version.contains("\r"),
          version.utf8.allSatisfy({ $0 >= 0x20 && $0 <= 0x7e }) else {
        throw ProbeFailure(kind: .malformedJSON)
    }
    return version
}

private func canonicalJSONData(_ value: Any) throws -> Data {
    let canonical = try canonicalJSONValue(value)
    do {
        return try JSONSerialization.data(
            withJSONObject: canonical,
            options: [.sortedKeys, .fragmentsAllowed]
        )
    } catch {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func canonicalUnorderedArrayData(_ values: [Any]) throws -> Data {
    let canonicalValues = try values.map(canonicalJSONValue)
    let sortedValues = try canonicalValues.sorted { left, right in
        let leftData = try canonicalJSONData(left)
        let rightData = try canonicalJSONData(right)
        return leftData.lexicographicallyPrecedes(rightData)
    }
    return try canonicalJSONData(sortedValues)
}

private func canonicalJSONValue(_ value: Any) throws -> Any {
    if let dictionary = value as? [String: Any] {
        var result = [String: Any]()
        for key in dictionary.keys.sorted() {
            guard let child = dictionary[key] else {
                throw ProbeFailure(kind: .malformedJSON)
            }
            result[key] = try canonicalJSONValue(child)
        }
        return result
    }
    if let array = value as? [Any] {
        return try array.map(canonicalJSONValue)
    }
    if value is String || value is NSNumber || value is NSNull {
        return value
    }
    throw ProbeFailure(kind: .malformedJSON)
}

private typealias FixedSpawn = (
    URL,
    [String],
    URL,
    [String: String],
    ProbeOperation,
    String
) throws -> ProbeResult

private func fixedCommandVectors(
    for operation: ProbeOperation,
    marketplaceRoot: ValidatedMarketplaceRoot
) throws -> [[String]] {
    let targetedStatus = [
        "plugin", "list", "--marketplace", "release-radar", "--available", "--json",
    ]
    switch operation {
    case .status:
        return [
            ["plugin", "marketplace", "list", "--json"],
            targetedStatus,
        ]
    case .install:
        return [
            ["plugin", "marketplace", "add", marketplaceRoot.url.path, "--json"],
            ["plugin", "add", "release-radar@release-radar", "--json"],
            targetedStatus,
        ]
    case .remove:
        return [
            ["plugin", "remove", "release-radar@release-radar", "--json"],
            targetedStatus,
        ]
    case .reinstall:
        return [
            ["plugin", "remove", "release-radar@release-radar", "--json"],
            ["plugin", "marketplace", "add", marketplaceRoot.url.path, "--json"],
            ["plugin", "add", "release-radar@release-radar", "--json"],
            targetedStatus,
        ]
    }
}

private func executeFixedOperation(
    _ operation: ProbeOperation,
    marketplaceRoot: ValidatedMarketplaceRoot,
    runtimeRoot: URL,
    cliVersion: String,
    verifyExecutable: (URL) throws -> Void,
    spawn: FixedSpawn
) throws -> [ProbeResult] {
    let fixedExecutable = URL(
        fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"
    )
    let fixedEnvironment = [
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]
    let vectors = try fixedCommandVectors(for: operation, marketplaceRoot: marketplaceRoot)
    var results = [ProbeResult]()
    for vector in vectors {
        let cwd = runtimeRoot.appendingPathComponent(
            "fixed-\(operation.rawValue)-\(UUID().uuidString)",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: false)
        } catch {
            throw ProbeFailure(kind: .unavailable)
        }
        try verifyExecutable(fixedExecutable)
        results.append(
            try spawn(
                fixedExecutable,
                vector,
                cwd,
                fixedEnvironment,
                operation,
                cliVersion
            )
        )
    }
    return results
}

private func validateFixtureRootArgument(
    _ argument: String,
    runtimeRoot: URL,
    invocationWorkingRoot: URL
) throws -> ValidatedMarketplaceRoot {
    guard !argument.isEmpty, !argument.utf8.contains(0) else {
        throw ProbeFailure(kind: .untrusted)
    }
    let candidate: URL
    if argument.hasPrefix("/") {
        candidate = URL(fileURLWithPath: argument, isDirectory: true)
    } else {
        candidate = invocationWorkingRoot.appendingPathComponent(argument, isDirectory: true)
    }
    let lexicalCandidate = candidate.standardizedFileURL
    let canonicalFixtureRoot = invocationWorkingRoot
        .appendingPathComponent("ReleaseRadarTests/Fixtures/CodexPluginLifecycle", isDirectory: true)
    try verifyNoSymlinkBelowAllowedRoot(
        lexicalCandidate,
        allowedRoots: [runtimeRoot, canonicalFixtureRoot],
        finalType: S_IFDIR
    )
    let confined = try requireConfinedPath(
        lexicalCandidate,
        allowedRoots: [runtimeRoot, canonicalFixtureRoot]
    )

    let marketplace = try supportedMarketplaceManifestURL(in: confined)
    let object: Any
    do {
        let data = try Data(contentsOf: marketplace)
        guard String(data: data, encoding: .utf8) != nil else {
            throw ProbeFailure(kind: .untrusted)
        }
        object = try JSONSerialization.jsonObject(with: data, options: [])
    } catch let failure as ProbeFailure {
        throw failure
    } catch {
        throw ProbeFailure(kind: .untrusted)
    }
    guard let dictionary = object as? [String: Any],
          dictionary["name"] as? String == "release-radar",
          let plugins = dictionary["plugins"] as? [[String: Any]],
          plugins.count == 1,
          plugins[0]["name"] as? String == "release-radar",
          let source = plugins[0]["source"] as? [String: Any],
          source["source"] as? String == "local",
          source["path"] as? String == "./plugins/release-radar" else {
        throw ProbeFailure(kind: .untrusted)
    }
    let lexicalPluginRoot = confined.appendingPathComponent(
        "plugins/release-radar",
        isDirectory: true
    )
    try verifyPathComponents(lexicalPluginRoot, finalType: S_IFDIR)
    let pluginRoot = try requireConfinedPath(
        lexicalPluginRoot,
        allowedRoots: [confined]
    )
    let version = try fixturePluginVersion(at: pluginRoot)
    let digest = try deterministicPackageDigest(at: pluginRoot, expectedDigest: nil)
    return ValidatedMarketplaceRoot(
        url: confined,
        pluginRoot: pluginRoot,
        version: version,
        digest: digest
    )
}

private func verifyNoSymlinkBelowAllowedRoot(
    _ candidate: URL,
    allowedRoots: [URL],
    finalType: mode_t
) throws {
    let candidatePath = candidate.standardizedFileURL.path
    for allowedRoot in allowedRoots {
        let rootPath = allowedRoot.standardizedFileURL.path
        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/") else {
            continue
        }
        let suffix = String(candidatePath.dropFirst(rootPath.count))
        let components = suffix.split(separator: "/").map(String.init)
        guard !components.isEmpty else {
            throw ProbeFailure(kind: .untrusted)
        }
        var current = allowedRoot.standardizedFileURL
        for (index, component) in components.enumerated() {
            current.appendPathComponent(component)
            var metadata = stat()
            guard lstat(current.path, &metadata) == 0,
                  metadata.st_mode & S_IFMT != S_IFLNK else {
                throw ProbeFailure(kind: .untrusted)
            }
            let expectedType = index == components.count - 1 ? finalType : S_IFDIR
            guard metadata.st_mode & S_IFMT == expectedType else {
                throw ProbeFailure(kind: .untrusted)
            }
        }
        return
    }
    throw ProbeFailure(kind: .untrusted)
}

private func fixturePluginVersion(at pluginRoot: URL) throws -> String {
    let manifest = pluginRoot.appendingPathComponent(".codex-plugin/plugin.json")
    try verifyPathComponents(manifest, finalType: S_IFREG)
    let object = try strictJSONValue(readStableRegularFile(manifest))
    guard let dictionary = object as? [String: Any],
          let version = dictionary["version"] as? String,
          !version.isEmpty,
          version.utf8.allSatisfy({
              ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x2e || $0 == 0x2d
          }) else {
        throw ProbeFailure(kind: .untrusted)
    }
    return version
}

private func supportedMarketplaceManifestURL(in marketplaceRoot: URL) throws -> URL {
    let agentsDirectory = marketplaceRoot.appendingPathComponent(".agents", isDirectory: true)
    let pluginsDirectory = agentsDirectory.appendingPathComponent("plugins", isDirectory: true)
    let manifest = pluginsDirectory.appendingPathComponent("marketplace.json")
    try verifyPathComponents(agentsDirectory, finalType: S_IFDIR)
    try verifyPathComponents(pluginsDirectory, finalType: S_IFDIR)
    try verifyPathComponents(manifest, finalType: S_IFREG)
    return manifest.standardizedFileURL
}

private func runFixedLifecycleOperation(
    _ operation: ProbeOperation,
    marketplaceRoot: ValidatedMarketplaceRoot,
    cliVersion: String
) throws -> [ProbeResult] {
    guard let runtimePath = ProcessInfo.processInfo.environment["RR_PLUGIN_PROBE_ROOT"] else {
        throw ProbeFailure(kind: .unavailable)
    }
    let runtimeRoot = URL(fileURLWithPath: runtimePath, isDirectory: true)
        .standardizedFileURL
        .resolvingSymlinksInPath()
    return try executeFixedOperation(
        operation,
        marketplaceRoot: marketplaceRoot,
        runtimeRoot: runtimeRoot,
        cliVersion: cliVersion,
        verifyExecutable: verifyFixedCodexExecutable,
        spawn: { executable, arguments, cwd, environment, operation, cliVersion in
            try runBoundedExecutable(
                executableURL: executable,
                arguments: arguments,
                currentDirectoryURL: cwd,
                environment: environment,
                operation: operation,
                cliVersion: cliVersion
            )
        }
    )
}

private func runLiveControllerInvocation(
    _ invocation: ControllerInvocation,
    runtimeRoot: URL,
    invocationWorkingRoot: URL
) throws -> ControllerReport {
    guard invocation.mode != .installedIntegrity,
          invocation.mode != .reinstall,
          let fixtureRoot = invocation.fixtureRoot else {
        throw ProbeFailure(kind: .untrusted)
    }
    let canonicalRuntimeRoot = try canonicalExistingURL(runtimeRoot)
    try verifyPathComponents(canonicalRuntimeRoot, finalType: S_IFDIR)
    let marketplaceRoot = try validateFixtureRootArgument(
        fixtureRoot,
        runtimeRoot: canonicalRuntimeRoot,
        invocationWorkingRoot: invocationWorkingRoot
    )
    let executable = URL(
        fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"
    )
    let environment = [
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]

    try verifyFixedCodexExecutable(executable)
    let versionWorkingDirectory = try freshWorkingDirectory(
        in: canonicalRuntimeRoot,
        prefix: "controller-version"
    )
    let versionResult = try runBoundedExecutable(
        executableURL: executable,
        arguments: ["--version"],
        currentDirectoryURL: versionWorkingDirectory,
        environment: environment,
        operation: .status,
        cliVersion: "unverified"
    )
    let cliVersion = try parseCLIVersion(versionResult.stdout)

    return try runControllerMode(
        invocation.mode,
        marketplaceRoot: marketplaceRoot,
        cliVersion: cliVersion,
        invoke: { arguments, operation in
            try verifyFixedCodexExecutable(executable)
            let workingDirectory = try freshWorkingDirectory(
                in: canonicalRuntimeRoot,
                prefix: "controller-\(operation.rawValue)"
            )
            return try runBoundedExecutable(
                executableURL: executable,
                arguments: arguments,
                currentDirectoryURL: workingDirectory,
                environment: environment,
                operation: operation,
                cliVersion: cliVersion
            )
        }
    )
}

private func runLiveLegacyMCPController(
    _ mode: ControllerMode,
    runtimeRoot: URL
) throws -> LegacyMCPControllerReport {
    let canonicalRuntimeRoot = try canonicalExistingURL(runtimeRoot)
    try verifyPathComponents(canonicalRuntimeRoot, finalType: S_IFDIR)
    let executable = URL(
        fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"
    )
    let environment = [
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]
    return try runLegacyMCPController(mode) { arguments, operation in
        try verifyFixedCodexExecutable(executable)
        let workingDirectory = try freshWorkingDirectory(
            in: canonicalRuntimeRoot,
            prefix: "controller-legacy-mcp"
        )
        return try runBoundedExecutable(
            executableURL: executable,
            arguments: arguments,
            currentDirectoryURL: workingDirectory,
            environment: environment,
            operation: operation,
            cliVersion: "fixed-legacy-mcp",
            acceptedExitStatuses: [legacyMCPGetCommand, bundledMCPGetCommand]
                .contains(arguments) ? [0, 1] : [0]
        )
    }
}

private func runLiveReinstallController(
    runtimeRoot: URL
) throws -> ReinstallControllerReport {
    let canonicalRuntimeRoot = try canonicalExistingURL(runtimeRoot)
    try verifyPathComponents(canonicalRuntimeRoot, finalType: S_IFDIR)
    let executable = URL(
        fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"
    )
    let environment = [
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]
    return try runReinstallController { arguments, operation in
        try verifyFixedCodexExecutable(executable)
        let workingDirectory = try freshWorkingDirectory(
            in: canonicalRuntimeRoot,
            prefix: "controller-reinstall"
        )
        return try runBoundedExecutable(
            executableURL: executable,
            arguments: arguments,
            currentDirectoryURL: workingDirectory,
            environment: environment,
            operation: operation,
            cliVersion: "fixed-reinstall"
        )
    }
}

private func runLiveInstalledIntegrityController(
    runtimeRoot: URL
) throws -> InstalledIntegrityControllerReport {
    let canonicalRuntimeRoot = try canonicalExistingURL(runtimeRoot)
    try verifyPathComponents(canonicalRuntimeRoot, finalType: S_IFDIR)
    let executable = URL(
        fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"
    )
    let environment = [
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]
    return try runInstalledIntegrityController { arguments, operation in
        try verifyFixedCodexExecutable(executable)
        let workingDirectory = try freshWorkingDirectory(
            in: canonicalRuntimeRoot,
            prefix: "controller-installed-integrity"
        )
        return try runBoundedExecutable(
            executableURL: executable,
            arguments: arguments,
            currentDirectoryURL: workingDirectory,
            environment: environment,
            operation: operation,
            cliVersion: "targeted-read-only"
        )
    }
}

private func runLiveStep7PreparationController(
    invocation: ControllerInvocation,
    runtimeRoot: URL,
    invocationWorkingRoot: URL
) throws -> Step7PreparationReport {
    guard invocation.mode == .step7Prepare,
          let fixtureRoot = invocation.fixtureRoot else {
        throw ProbeFailure(kind: .untrusted)
    }
    let runtimeRoot = try canonicalExistingURL(runtimeRoot)
    let repositoryRoot = try canonicalExistingURL(invocationWorkingRoot)
    try verifyPathComponents(runtimeRoot, finalType: S_IFDIR)
    try verifyPathComponents(repositoryRoot, finalType: S_IFDIR)

    let canonicalV2 = repositoryRoot.appendingPathComponent(
        "ReleaseRadarTests/Fixtures/CodexPluginLifecycle/v2",
        isDirectory: true
    )
    let validated = try validateFixtureRootArgument(
        fixtureRoot,
        runtimeRoot: runtimeRoot,
        invocationWorkingRoot: repositoryRoot
    )
    let canonicalV2URL = try canonicalExistingURL(canonicalV2)
    guard validated.url == canonicalV2URL,
          validated.version == "1.1.0" else {
        throw ProbeFailure(kind: .untrusted)
    }
    let canonicalV1 = canonicalV2.deletingLastPathComponent().appendingPathComponent(
        "v1",
        isDirectory: true
    )
    let v1Before = try step7TreeFingerprint(canonicalV1)
    let v2Before = try step7TreeFingerprint(canonicalV2)
    let canonicalDigest = try deterministicPackageDigest(
        at: validated.pluginRoot,
        expectedDigest: nil
    )

    let artifactID = UUID()
    let packageRoot = runtimeRoot.appendingPathComponent(
        "step7-preparation-\(artifactID.uuidString)",
        isDirectory: true
    )
    do {
        try FileManager.default.createDirectory(at: packageRoot, withIntermediateDirectories: false)
    } catch {
        throw ProbeFailure(kind: .unavailable)
    }
    let layout = try Step7PreparationLayout(
        packageRoot: packageRoot,
        repositoryRoot: repositoryRoot,
        artifactID: artifactID
    )
    let buildPlan = try makeStep7BuildPlan(layout: layout)
    _ = try runBoundedExecutable(
        executableURL: buildPlan.executable,
        arguments: buildPlan.arguments,
        currentDirectoryURL: buildPlan.workingDirectory,
        environment: buildPlan.environment,
        operation: .status,
        cliVersion: "step7-preparation",
        outputLimit: 33_554_432,
        timeoutNanoseconds: 600_000_000_000
    )
    try validateStep7BuiltProducts(layout: layout)

    let derived = try deriveStep7Marketplace(
        canonicalMarketplace: validated.url,
        builtAgentTool: layout.builtAgentTool,
        layout: layout
    )
    let fixturesUnchanged =
        try step7TreeFingerprint(canonicalV1) == v1Before
        && step7TreeFingerprint(canonicalV2) == v2Before
    guard fixturesUnchanged else {
        throw ProbeFailure(kind: .postcondition)
    }

    return Step7PreparationReport(
        wireVersion: 1,
        ok: true,
        operation: .step7Prepare,
        artifactID: artifactID.uuidString,
        fixtureVersion: derived.version,
        canonicalDigest: canonicalDigest,
        derivedDigest: derived.digest,
        canonicalFixturesUnchanged: true,
        builtAppVerified: true,
        builtAgentToolVerified: true,
        mcpTargetsBuiltAgentTool: true,
        nextAction: .controllerInstallDerivedPlugin,
        expectations: .fixed
    )
}

private func runBridgePreflightController() -> BridgePreflightReport {
    let applicationRunning = !NSRunningApplication.runningApplications(
        withBundleIdentifier: Step7Constants.applicationBundleIdentifier
    ).isEmpty
    return bridgePreflightReport(applicationRunning: applicationRunning)
}

private func runOwnedCLICancellationController(
    runtimeRoot: URL
) throws -> OwnedCLICancellationReport {
    let plan = Step7OwnedCLICancellationPlan.fixed
    let runtimeRoot = try canonicalExistingURL(runtimeRoot)
    try verifyPathComponents(runtimeRoot, finalType: S_IFDIR)
    let workingDirectory = try freshWorkingDirectory(
        in: runtimeRoot,
        prefix: "owned-cli-cancellation"
    )

    var fileActions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?
    guard posix_spawn_file_actions_init(&fileActions) == 0,
          posix_spawnattr_init(&attributes) == 0 else {
        throw ProbeFailure(kind: .unavailable)
    }
    defer {
        posix_spawn_file_actions_destroy(&fileActions)
        posix_spawnattr_destroy(&attributes)
    }
    guard posix_spawn_file_actions_addopen(
        &fileActions,
        STDIN_FILENO,
        "/dev/null",
        O_RDONLY,
        0
    ) == 0,
    posix_spawn_file_actions_addopen(
        &fileActions,
        STDOUT_FILENO,
        "/dev/null",
        O_WRONLY,
        0
    ) == 0,
    posix_spawn_file_actions_addopen(
        &fileActions,
        STDERR_FILENO,
        "/dev/null",
        O_WRONLY,
        0
    ) == 0,
    addSpawnChdirAction(&fileActions, path: workingDirectory.path) == 0 else {
        throw ProbeFailure(kind: .unavailable)
    }

    var emptySignals = sigset_t()
    sigemptyset(&emptySignals)
    var defaultSignals = sigset_t()
    sigemptyset(&defaultSignals)
    sigaddset(&defaultSignals, SIGTERM)
    sigaddset(&defaultSignals, SIGINT)
    let spawnFlags = Int16(
        POSIX_SPAWN_SETPGROUP
            | POSIX_SPAWN_SETSIGMASK
            | POSIX_SPAWN_SETSIGDEF
            | POSIX_SPAWN_START_SUSPENDED
    )
    guard posix_spawnattr_setflags(&attributes, spawnFlags) == 0,
          posix_spawnattr_setpgroup(&attributes, 0) == 0,
          posix_spawnattr_setsigmask(&attributes, &emptySignals) == 0,
          posix_spawnattr_setsigdefault(&attributes, &defaultSignals) == 0 else {
        throw ProbeFailure(kind: .unavailable)
    }

    let argv = [plan.executable.path] + plan.arguments
    let environment = plan.environment.keys.sorted().map {
        "\($0)=\(plan.environment[$0]!)"
    }
    var childPID = pid_t()
    try verifyFixedCodexExecutable(plan.executable)
    let spawnStatus = withMutableCStringArray(argv) { argvPointer in
        withMutableCStringArray(environment) { environmentPointer in
            posix_spawn(
                &childPID,
                plan.executable.path,
                &fileActions,
                &attributes,
                argvPointer,
                environmentPointer
            )
        }
    }
    guard spawnStatus == 0, childPID > 0 else {
        throw ProbeFailure(kind: .unavailable)
    }

    let processGroupID = childPID
    let cleanupDeadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    var waitStatus = Int32()
    var childReaped = false
    var cleanupConfirmed = false

    enum ChildObservation {
        case unreaped(groupVerified: Bool)
        case reaped
        case uncertain
    }

    func observeChild() -> ChildObservation {
        if childReaped {
            return .reaped
        }
        repeat {
            errno = 0
            let waited = waitpid(childPID, &waitStatus, WNOHANG)
            if waited == childPID {
                childReaped = true
                return .reaped
            }
            if waited == 0 {
                return .unreaped(groupVerified: getpgid(childPID) == processGroupID)
            }
            if waited == -1, errno == EINTR {
                continue
            }
            return .uncertain
        } while DispatchTime.now().uptimeNanoseconds < cleanupDeadline
        return .uncertain
    }

    func signalOwnedChild(_ signal: Int32) throws -> Bool {
        switch observeChild() {
        case .reaped:
            return false
        case .uncertain:
            throw ProbeFailure(kind: .postcondition)
        case .unreaped(groupVerified: true):
            guard kill(-processGroupID, signal) == 0 else {
                throw ProbeFailure(kind: .postcondition)
            }
            return true
        case .unreaped(groupVerified: false):
            // Recheck direct-child ownership immediately before falling back to
            // the exact PID. An unverified process group is never signalled.
            switch observeChild() {
            case .reaped:
                return false
            case .uncertain:
                throw ProbeFailure(kind: .postcondition)
            case .unreaped:
                guard kill(childPID, signal) == 0 else {
                    throw ProbeFailure(kind: .postcondition)
                }
                return true
            }
        }
    }

    func pollForReap(until deadline: UInt64) throws -> Bool {
        while DispatchTime.now().uptimeNanoseconds < deadline {
            switch observeChild() {
            case .reaped:
                return true
            case .unreaped:
                usleep(10_000)
            case .uncertain:
                throw ProbeFailure(kind: .postcondition)
            }
        }
        return childReaped
    }

    func observeFinalAbsence() -> Bool {
        guard childReaped else { return false }
        repeat {
            if !exactProcessExists(childPID), !processGroupExists(processGroupID) {
                return true
            }
            usleep(10_000)
        } while DispatchTime.now().uptimeNanoseconds < cleanupDeadline
        return false
    }

    defer {
        if !cleanupConfirmed {
            if !childReaped {
                _ = try? signalOwnedChild(SIGKILL)
                _ = try? pollForReap(until: cleanupDeadline)
            }
            if childReaped {
                cleanupConfirmed = observeFinalAbsence()
            }
        }
    }

    guard case .unreaped(groupVerified: true) = observeChild() else {
        throw ProbeFailure(kind: .postcondition)
    }

    let termSent = try signalOwnedChild(SIGTERM)
    guard termSent else {
        throw ProbeFailure(kind: .postcondition)
    }
    let continueSent = try signalOwnedChild(SIGCONT)

    let termDeadline = min(
        DispatchTime.now().uptimeNanoseconds + 500_000_000,
        cleanupDeadline
    )

    var killRequired = false
    if try !pollForReap(until: termDeadline) {
        killRequired = try signalOwnedChild(SIGKILL)
        guard killRequired || childReaped else {
            throw ProbeFailure(kind: .postcondition)
        }
        guard try pollForReap(until: cleanupDeadline) else {
            throw ProbeFailure(kind: .postcondition)
        }
    }

    guard childReaped, observeFinalAbsence() else {
        throw ProbeFailure(kind: .postcondition)
    }
    cleanupConfirmed = true

    return OwnedCLICancellationReport(
        wireVersion: 1,
        ok: true,
        operation: .ownedCLICancellation,
        executableVerified: true,
        command: "fixedReadOnlyReleaseRadarPluginList",
        childPID: childPID,
        processGroupID: processGroupID,
        directChildVerified: true,
        dedicatedProcessGroupVerified: true,
        termSent: termSent,
        continueSent: continueSent,
        killRequired: killRequired,
        childReaped: true,
        processAbsent: true,
        processGroupAbsent: true
    )
}

private func exactProcessExists(_ pid: pid_t) -> Bool {
    errno = 0
    return kill(pid, 0) == 0 || errno == EPERM
}

private func step7TreeFingerprint(_ root: URL) throws -> String {
    let root = try canonicalExistingURL(root)
    try verifyPathComponents(root, finalType: S_IFDIR)
    var hasher = SHA256()
    func visit(_ url: URL, relative: String) throws {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0,
              metadata.st_mode & S_IFMT != S_IFLNK else {
            throw ProbeFailure(kind: .untrusted)
        }
        let type = metadata.st_mode & S_IFMT
        if type == S_IFDIR {
            hasher.update(data: Data("D\(relative)\u{0}".utf8))
            let names = try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
            for name in names {
                guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
                    throw ProbeFailure(kind: .untrusted)
                }
                try visit(
                    url.appendingPathComponent(name),
                    relative: relative.isEmpty ? name : "\(relative)/\(name)"
                )
            }
        } else if type == S_IFREG {
            let data = try readStableRegularFile(url)
            hasher.update(data: Data("F\(relative)\u{0}".utf8))
            var length = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
            hasher.update(data: data)
        } else {
            throw ProbeFailure(kind: .untrusted)
        }
    }
    try visit(root, relative: "")
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

private func validateStep7BuiltProducts(layout: Step7PreparationLayout) throws {
    try verifyNoSymlinkBelowAllowedRoot(
        layout.builtApp,
        allowedRoots: [layout.derivedDataRoot],
        finalType: S_IFDIR
    )
    try verifyNoSymlinkBelowAllowedRoot(
        layout.builtAgentTool,
        allowedRoots: [layout.derivedDataRoot],
        finalType: S_IFREG
    )
    try runStep7CodesignVerification(
        layout.builtApp,
        deep: true,
        workingRoot: layout.packageRoot
    )
    try runStep7CodesignVerification(
        layout.builtAgentTool,
        deep: false,
        workingRoot: layout.packageRoot
    )
    try validateSigningIdentity(
        layout.builtApp,
        identifier: Step7Constants.applicationBundleIdentifier,
        teamIdentifier: Step7Constants.teamIdentifier,
        requireHardenedRuntime: true
    )
    try validateSigningIdentity(
        layout.builtAgentTool,
        identifier: Step7Constants.agentToolBundleIdentifier,
        teamIdentifier: Step7Constants.teamIdentifier,
        requireHardenedRuntime: true
    )
    let appEntitlements = try step7CodeEntitlements(layout.builtApp)
    let toolEntitlements = try step7CodeEntitlements(layout.builtAgentTool)
    guard appEntitlements["com.apple.security.app-sandbox"] as? Bool == true,
          appEntitlements["com.apple.security.application-groups"] as? [String]
            == ["2UA854NLX4.com.rekonlabs.ReleaseRadar"],
          toolEntitlements["com.apple.security.app-sandbox"] == nil,
          toolEntitlements["com.apple.security.application-groups"] == nil else {
        throw ProbeFailure(kind: .untrusted)
    }
}

private func runStep7CodesignVerification(
    _ artifact: URL,
    deep: Bool,
    workingRoot: URL
) throws {
    var arguments = ["--verify", "--strict"]
    if deep { arguments.append("--deep") }
    arguments.append(artifact.path)
    let workingDirectory = try freshWorkingDirectory(
        in: workingRoot,
        prefix: "codesign-verify"
    )
    _ = try runBoundedExecutable(
        executableURL: URL(fileURLWithPath: "/usr/bin/codesign"),
        arguments: arguments,
        currentDirectoryURL: workingDirectory,
        environment: ["LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"],
        operation: .status,
        cliVersion: "step7-preparation",
        outputLimit: 1_048_576,
        timeoutNanoseconds: 30_000_000_000
    )
}

private func step7CodeEntitlements(_ artifact: URL) throws -> [String: Any] {
    let information = try step7CodeSigningInformation(artifact)
    return information[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
}

private func step7CodeSigningInformation(_ artifact: URL) throws -> [String: Any] {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(artifact as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
          let staticCode else {
        throw ProbeFailure(kind: .untrusted)
    }
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(
        staticCode,
        SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)),
        &information
    ) == errSecSuccess,
          let dictionary = information as? [String: Any] else {
        throw ProbeFailure(kind: .untrusted)
    }
    return dictionary
}

private func freshWorkingDirectory(in root: URL, prefix: String) throws -> URL {
    let directory = root.appendingPathComponent(
        "\(prefix)-\(UUID().uuidString)",
        isDirectory: true
    )
    do {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
    } catch {
        throw ProbeFailure(kind: .unavailable)
    }
    return directory
}

private func writeJSON<Value: Encodable>(_ value: Value, to handle: FileHandle) throws {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(value)
        data.append(0x0a)
        try handle.write(contentsOf: data)
    } catch {
        throw ProbeFailure(kind: .postcondition)
    }
}

private func exitWithControllerFailure(_ kind: ProbeFailure.Kind) -> Never {
    let report = ControllerFailureReport(wireVersion: 1, ok: false, error: kind)
    if var data = try? JSONEncoder().encode(report) {
        data.append(0x0a)
        FileHandle.standardOutput.write(data)
    }
    exit(1)
}

private func decodeStrictJSONObject<Value: Decodable>(
    _ data: Data,
    allowedKeys: Set<String>
) throws -> Value {
    do {
        guard String(data: data, encoding: .utf8) != nil else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        guard Set(dictionary.keys).subtracting(allowedKeys).isEmpty else {
            throw ProbeFailure(kind: .malformedJSON)
        }
        return try JSONDecoder().decode(Value.self, from: data)
    } catch let failure as ProbeFailure {
        throw failure
    } catch {
        throw ProbeFailure(kind: .malformedJSON)
    }
}

private func requireConfinedPath(_ candidate: URL, allowedRoots: [URL]) throws -> URL {
    guard candidate.isFileURL, !allowedRoots.isEmpty else {
        throw ProbeFailure(kind: .untrusted)
    }
    let resolvedCandidate = try canonicalExistingURL(candidate)
    let accepted = try allowedRoots.contains { root in
        let resolvedRoot = try canonicalExistingURL(root)
        return resolvedCandidate.path == resolvedRoot.path
            || resolvedCandidate.path.hasPrefix(resolvedRoot.path + "/")
    }
    guard accepted else {
        throw ProbeFailure(kind: .untrusted)
    }
    return resolvedCandidate
}

private func canonicalExistingURL(_ url: URL) throws -> URL {
    guard url.isFileURL else {
        throw ProbeFailure(kind: .untrusted)
    }
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    let resolvedPath = url.path.withCString { pathPointer in
        buffer.withUnsafeMutableBufferPointer { bufferPointer -> String? in
            guard realpath(pathPointer, bufferPointer.baseAddress) != nil else {
                return nil
            }
            return String(cString: bufferPointer.baseAddress!)
        }
    }
    guard let resolvedPath else {
        throw ProbeFailure(kind: .untrusted)
    }
    return URL(fileURLWithPath: resolvedPath, isDirectory: url.hasDirectoryPath)
}

private let recognizedInstalledPluginDigests = [
    "1.0.0": "426c849972c27cd2c76981da54ff1a917e9bb87e4d9f9bc0e2f99dd9ff839abd",
    "1.1.0": "fafb0d2027077c8f4a5efe2c9b422912d5a92c635417bb475d682c5c1f1c29b8",
]

private enum InstalledPluginIntegrityError: String, Codable, Equatable {
    case integrityInvalid
    case integrityUnknown
}

private enum InstalledPluginIntegrityState: Codable, Equatable {
    case clean(version: String, digest: String)
    case modified(version: String?, observedDigest: String?)
    case needsRepair(InstalledPluginIntegrityError)
}

private enum InstalledPluginDigesterTestEvent: Equatable {
    case openedFixedDirectory(Int)
    case openedTargetRoot
    case readFile(String)
}

private enum InstalledPluginReadFailure: Error {
    case invalid
    case unknown
}

private enum InstalledPluginAccess: Equatable {
    case homeDirectory
    case fixedDirectory(Int)
    case packageDirectory(String)
    case inventory(String)
    case file(String)
}

private struct InstalledPluginFileSystem {
    let observer: ((InstalledPluginAccess) -> Void)?
    let injectedReadFailure: InstalledPluginAccess?

    func openHome(_ homeDirectory: URL) throws -> Int32 {
        try prepare(.homeDirectory)
        let descriptor = Darwin.open(
            homeDirectory.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw installedPluginFailureForCurrentErrno()
        }
        return descriptor
    }

    func openDirectory(
        _ name: String,
        relativeTo parentDescriptor: Int32,
        access: InstalledPluginAccess
    ) throws -> Int32 {
        try prepare(access)
        let descriptor = Darwin.openat(
            parentDescriptor,
            name,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw installedPluginFailureForCurrentErrno()
        }
        return descriptor
    }

    func openFile(
        _ name: String,
        relativeTo parentDescriptor: Int32,
        relativePath: String
    ) throws -> Int32 {
        try prepare(.file(relativePath))
        let descriptor = Darwin.openat(
            parentDescriptor,
            name,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw installedPluginFailureForCurrentErrno()
        }
        return descriptor
    }

    func openInventory(
        _ descriptor: Int32,
        relativeDirectory: String
    ) throws -> Int32 {
        try prepare(.inventory(relativeDirectory))
        let independentDescriptor = Darwin.openat(
            descriptor,
            ".",
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard independentDescriptor >= 0 else {
            throw installedPluginFailureForCurrentErrno()
        }
        return independentDescriptor
    }

    private func prepare(_ access: InstalledPluginAccess) throws {
        observer?(access)
        if access == injectedReadFailure {
            throw InstalledPluginReadFailure.unknown
        }
    }
}

private func installedPluginFailureForCurrentErrno() -> InstalledPluginReadFailure {
    switch errno {
    case ENOENT, ENOTDIR, ELOOP, EINVAL, ENAMETOOLONG:
        return .invalid
    default:
        return .unknown
    }
}

private struct InstalledPluginMetadata {
    let device: dev_t
    let inode: ino_t
    let mode: mode_t
    let size: off_t
    let modificationSeconds: Int
    let modificationNanoseconds: Int
    let changeSeconds: Int
    let changeNanoseconds: Int

    init(_ value: stat) {
        device = value.st_dev
        inode = value.st_ino
        mode = value.st_mode
        size = value.st_size
        modificationSeconds = value.st_mtimespec.tv_sec
        modificationNanoseconds = value.st_mtimespec.tv_nsec
        changeSeconds = value.st_ctimespec.tv_sec
        changeNanoseconds = value.st_ctimespec.tv_nsec
    }

    var fileType: mode_t { mode & S_IFMT }

    func hasSameIdentity(as other: InstalledPluginMetadata) -> Bool {
        device == other.device
            && inode == other.inode
            && fileType == other.fileType
    }

    func isStable(as other: InstalledPluginMetadata) -> Bool {
        hasSameIdentity(as: other)
            && mode == other.mode
            && size == other.size
            && modificationSeconds == other.modificationSeconds
            && modificationNanoseconds == other.modificationNanoseconds
            && changeSeconds == other.changeSeconds
            && changeNanoseconds == other.changeNanoseconds
    }
}

private struct InstalledPluginDirectoryLink {
    let parentDescriptor: Int32
    let name: String
    let descriptor: Int32
    let before: InstalledPluginMetadata
    let requireStableMetadata: Bool
}

private struct InstalledPluginDigester {
    // Fixed feasibility bounds; current signed fixtures remain below 16 KiB total.
    private static let maximumFileByteCount = 256 * 1024
    private static let maximumPackageByteCount = 512 * 1024
    private static let fixedDirectoryComponents = [
        ".codex",
        "plugins",
        "cache",
        "release-radar",
        "release-radar",
    ]
    private static let requiredFiles = [
        ".codex-plugin/plugin.json",
        ".mcp.json",
        "skills/release-radar/SKILL.md",
    ]

    let homeDirectory: URL
    let version: String
    let expectedDigests: [String: String]
    let fileSystem: InstalledPluginFileSystem
    var testEvent: ((InstalledPluginDigesterTestEvent) throws -> Void)?

    init(
        homeDirectory: URL,
        version: String,
        expectedDigests: [String: String],
        accessObserver: ((InstalledPluginAccess) -> Void)? = nil,
        testReadFailure: InstalledPluginAccess? = nil,
        testEvent: ((InstalledPluginDigesterTestEvent) throws -> Void)? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.version = version
        self.expectedDigests = expectedDigests
        self.fileSystem = InstalledPluginFileSystem(
            observer: accessObserver,
            injectedReadFailure: testReadFailure
        )
        self.testEvent = testEvent
    }

    func classify() -> InstalledPluginIntegrityState {
        guard isStrictSemVer(version) else {
            return .needsRepair(.integrityInvalid)
        }
        guard let expectedDigest = expectedDigests[version],
              isLowercaseSHA256(expectedDigest) else {
            return .needsRepair(.integrityUnknown)
        }
        do {
            let digest = try readAndValidateTarget()
            if digest == expectedDigest {
                return .clean(version: version, digest: digest)
            }
            return .modified(version: version, observedDigest: digest)
        } catch InstalledPluginReadFailure.invalid {
            return .needsRepair(.integrityInvalid)
        } catch {
            return .needsRepair(.integrityUnknown)
        }
    }

    private func readAndValidateTarget() throws -> String {
        guard homeDirectory.isFileURL, homeDirectory.path.hasPrefix("/") else {
            throw InstalledPluginReadFailure.invalid
        }
        let homeDescriptor = try fileSystem.openHome(homeDirectory)
        var descriptors = [homeDescriptor]
        var links = [InstalledPluginDirectoryLink]()
        defer {
            for descriptor in descriptors.reversed() {
                close(descriptor)
            }
        }

        var parentDescriptor = homeDescriptor
        for (index, component) in (Self.fixedDirectoryComponents + [version]).enumerated() {
            let link = try openDirectory(
                component,
                relativeTo: parentDescriptor,
                access: .fixedDirectory(index),
                requireStableMetadata: true
            )
            descriptors.append(link.descriptor)
            links.append(link)
            parentDescriptor = link.descriptor
            try testEvent?(.openedFixedDirectory(index))
        }
        try testEvent?(.openedTargetRoot)

        let targetDescriptor = parentDescriptor
        let packageLinks = try openAndValidatePackageDirectories(
            targetDescriptor: targetDescriptor,
            descriptors: &descriptors
        )
        let contents = try readRequiredFiles(
            targetDescriptor: targetDescriptor,
            packageLinks: packageLinks
        )
        try requireExactPackageInventory(
            targetDescriptor: targetDescriptor,
            packageLinks: packageLinks
        )
        for link in packageLinks.reversed() {
            try validateDirectoryLink(link)
        }
        for link in links.reversed() {
            try validateDirectoryLink(link)
        }

        guard let manifest = contents[".codex-plugin/plugin.json"],
              let mcp = contents[".mcp.json"],
              let skill = contents["skills/release-radar/SKILL.md"] else {
            throw InstalledPluginReadFailure.invalid
        }
        try validatePluginManifest(manifest)
        try validateMCPManifest(mcp)
        guard !skill.isEmpty, String(data: skill, encoding: .utf8) != nil else {
            throw InstalledPluginReadFailure.invalid
        }
        return deterministicInstalledDigest(contents)
    }

    private func openAndValidatePackageDirectories(
        targetDescriptor: Int32,
        descriptors: inout [Int32]
    ) throws -> [InstalledPluginDirectoryLink] {
        try requireExactDirectoryEntries(
            targetDescriptor,
            expected: [".codex-plugin", ".mcp.json", "skills"],
            relativeDirectory: ""
        )
        let pluginMetadata = try openDirectory(
            ".codex-plugin",
            relativeTo: targetDescriptor,
            access: .packageDirectory(".codex-plugin"),
            requireStableMetadata: true
        )
        descriptors.append(pluginMetadata.descriptor)
        try requireExactDirectoryEntries(
            pluginMetadata.descriptor,
            expected: ["plugin.json"],
            relativeDirectory: ".codex-plugin"
        )

        let skills = try openDirectory(
            "skills",
            relativeTo: targetDescriptor,
            access: .packageDirectory("skills"),
            requireStableMetadata: true
        )
        descriptors.append(skills.descriptor)
        try requireExactDirectoryEntries(
            skills.descriptor,
            expected: ["release-radar"],
            relativeDirectory: "skills"
        )

        let releaseRadarSkill = try openDirectory(
            "release-radar",
            relativeTo: skills.descriptor,
            access: .packageDirectory("skills/release-radar"),
            requireStableMetadata: true
        )
        descriptors.append(releaseRadarSkill.descriptor)
        try requireExactDirectoryEntries(
            releaseRadarSkill.descriptor,
            expected: ["SKILL.md"],
            relativeDirectory: "skills/release-radar"
        )
        return [pluginMetadata, skills, releaseRadarSkill]
    }

    private func requireExactPackageInventory(
        targetDescriptor: Int32,
        packageLinks: [InstalledPluginDirectoryLink]
    ) throws {
        guard packageLinks.count == 3 else {
            throw InstalledPluginReadFailure.invalid
        }
        try requireExactDirectoryEntries(
            targetDescriptor,
            expected: [".codex-plugin", ".mcp.json", "skills"],
            relativeDirectory: ""
        )
        try requireExactDirectoryEntries(
            packageLinks[0].descriptor,
            expected: ["plugin.json"],
            relativeDirectory: ".codex-plugin"
        )
        try requireExactDirectoryEntries(
            packageLinks[1].descriptor,
            expected: ["release-radar"],
            relativeDirectory: "skills"
        )
        try requireExactDirectoryEntries(
            packageLinks[2].descriptor,
            expected: ["SKILL.md"],
            relativeDirectory: "skills/release-radar"
        )
    }

    private func readRequiredFiles(
        targetDescriptor: Int32,
        packageLinks: [InstalledPluginDirectoryLink]
    ) throws -> [String: Data] {
        let descriptorsByPath = [
            ".codex-plugin/plugin.json": (packageLinks[0].descriptor, "plugin.json"),
            ".mcp.json": (targetDescriptor, ".mcp.json"),
            "skills/release-radar/SKILL.md": (packageLinks[2].descriptor, "SKILL.md"),
        ]
        var result = [String: Data]()
        var aggregateByteCount = 0
        for relativePath in Self.requiredFiles.sorted() {
            guard let (parent, name) = descriptorsByPath[relativePath] else {
                throw InstalledPluginReadFailure.invalid
            }
            let contents = try readStableFile(
                name,
                relativeTo: parent,
                relativePath: relativePath,
                remainingAggregateByteCount: Self.maximumPackageByteCount - aggregateByteCount
            )
            aggregateByteCount += contents.count
            result[relativePath] = contents
        }
        return result
    }

    private func readStableFile(
        _ name: String,
        relativeTo parentDescriptor: Int32,
        relativePath: String,
        remainingAggregateByteCount: Int
    ) throws -> Data {
        let beforeEntry = try metadata(
            for: name,
            relativeTo: parentDescriptor,
            noFollow: true
        )
        guard beforeEntry.fileType == S_IFREG else {
            throw InstalledPluginReadFailure.invalid
        }
        let descriptor = try fileSystem.openFile(
            name,
            relativeTo: parentDescriptor,
            relativePath: relativePath
        )
        defer { close(descriptor) }
        let beforeHandle = try metadata(for: descriptor)
        guard beforeHandle.fileType == S_IFREG,
              beforeEntry.hasSameIdentity(as: beforeHandle),
              beforeHandle.size >= 0,
              beforeHandle.size <= off_t(Self.maximumFileByteCount),
              beforeHandle.size <= off_t(remainingAggregateByteCount) else {
            throw InstalledPluginReadFailure.invalid
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw InstalledPluginReadFailure.unknown
            }
            guard count <= Self.maximumFileByteCount - data.count,
                  count <= remainingAggregateByteCount - data.count else {
                throw InstalledPluginReadFailure.invalid
            }
            data.append(buffer, count: count)
        }
        try testEvent?(.readFile(relativePath))

        let afterHandle = try metadata(for: descriptor)
        let afterEntry = try metadata(
            for: name,
            relativeTo: parentDescriptor,
            noFollow: true
        )
        guard beforeHandle.isStable(as: afterHandle),
              beforeEntry.isStable(as: afterEntry),
              beforeHandle.hasSameIdentity(as: afterEntry),
              data.count == Int(afterHandle.size) else {
            throw InstalledPluginReadFailure.invalid
        }
        return data
    }

    private func openDirectory(
        _ name: String,
        relativeTo parentDescriptor: Int32,
        access: InstalledPluginAccess,
        requireStableMetadata: Bool
    ) throws -> InstalledPluginDirectoryLink {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            throw InstalledPluginReadFailure.invalid
        }
        let beforeEntry = try metadata(
            for: name,
            relativeTo: parentDescriptor,
            noFollow: true
        )
        guard beforeEntry.fileType == S_IFDIR else {
            throw InstalledPluginReadFailure.invalid
        }
        let descriptor = try fileSystem.openDirectory(
            name,
            relativeTo: parentDescriptor,
            access: access
        )
        do {
            let opened = try metadata(for: descriptor)
            guard opened.fileType == S_IFDIR,
                  beforeEntry.hasSameIdentity(as: opened) else {
                throw InstalledPluginReadFailure.invalid
            }
            return InstalledPluginDirectoryLink(
                parentDescriptor: parentDescriptor,
                name: name,
                descriptor: descriptor,
                before: opened,
                requireStableMetadata: requireStableMetadata
            )
        } catch {
            close(descriptor)
            throw error
        }
    }

    private func validateDirectoryLink(_ link: InstalledPluginDirectoryLink) throws {
        let afterHandle = try metadata(for: link.descriptor)
        let afterEntry = try metadata(
            for: link.name,
            relativeTo: link.parentDescriptor,
            noFollow: true
        )
        guard link.before.hasSameIdentity(as: afterHandle),
              link.before.hasSameIdentity(as: afterEntry),
              !link.requireStableMetadata || link.before.isStable(as: afterHandle) else {
            throw InstalledPluginReadFailure.invalid
        }
    }

    private func requireExactDirectoryEntries(
        _ descriptor: Int32,
        expected: Set<String>,
        relativeDirectory: String
    ) throws {
        let independentDescriptor = try fileSystem.openInventory(
            descriptor,
            relativeDirectory: relativeDirectory
        )
        guard let directory = fdopendir(independentDescriptor) else {
            close(independentDescriptor)
            throw InstalledPluginReadFailure.unknown
        }
        defer { closedir(directory) }
        var remaining = expected
        while true {
            errno = 0
            guard let entry = readdir(directory) else {
                if errno != 0 {
                    throw InstalledPluginReadFailure.unknown
                }
                break
            }
            let name = withUnsafePointer(to: entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." { continue }
            guard !name.isEmpty,
                  !name.contains("/"),
                  remaining.remove(name) != nil else {
                throw InstalledPluginReadFailure.invalid
            }
        }
        guard remaining.isEmpty else {
            throw InstalledPluginReadFailure.invalid
        }
    }

    private func metadata(for descriptor: Int32) throws -> InstalledPluginMetadata {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else {
            throw InstalledPluginReadFailure.unknown
        }
        return InstalledPluginMetadata(value)
    }

    private func metadata(
        for name: String,
        relativeTo descriptor: Int32,
        noFollow: Bool
    ) throws -> InstalledPluginMetadata {
        var value = stat()
        let flags = noFollow ? AT_SYMLINK_NOFOLLOW : 0
        guard fstatat(descriptor, name, &value, flags) == 0 else {
            throw installedPluginFailureForCurrentErrno()
        }
        return InstalledPluginMetadata(value)
    }

    private func validatePluginManifest(_ data: Data) throws {
        let object: Any
        do {
            object = try strictJSONValue(data)
        } catch {
            throw InstalledPluginReadFailure.invalid
        }
        guard let manifest = object as? [String: Any],
              manifest["name"] as? String == "release-radar",
              manifest["version"] as? String == version,
              manifest["skills"] as? String == "./skills/",
              manifest["mcpServers"] as? String == "./.mcp.json" else {
            throw InstalledPluginReadFailure.invalid
        }
    }

    private func validateMCPManifest(_ data: Data) throws {
        let object: Any
        do {
            object = try strictJSONValue(data)
        } catch {
            throw InstalledPluginReadFailure.invalid
        }
        guard let manifest = object as? [String: Any],
              Set(manifest.keys) == ["release_radar"],
              let server = manifest["release_radar"] as? [String: Any],
              Set(server.keys) == ["command", "args"],
              let command = server["command"] as? String,
              !command.isEmpty,
              !command.utf8.contains(0),
              let arguments = server["args"] as? [Any],
              arguments.allSatisfy({ $0 is String }) else {
            throw InstalledPluginReadFailure.invalid
        }
    }

    private func deterministicInstalledDigest(_ contents: [String: Data]) -> String {
        var hasher = SHA256()
        for relativePath in Self.requiredFiles.sorted() {
            let data = contents[relativePath]!
            hasher.update(data: Data(relativePath.utf8))
            hasher.update(data: Data([0]))
            var length = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private func effectiveUserHomeDirectory() throws -> URL {
    var account = passwd()
    var result: UnsafeMutablePointer<passwd>?
    var buffer = [CChar](repeating: 0, count: 16 * 1024)
    let status = getpwuid_r(geteuid(), &account, &buffer, buffer.count, &result)
    guard status == 0,
          result != nil,
          let directory = account.pw_dir else {
        throw InstalledPluginReadFailure.unknown
    }
    let path = String(cString: directory)
    guard path.hasPrefix("/"), !path.utf8.contains(0) else {
        throw InstalledPluginReadFailure.invalid
    }
    return URL(fileURLWithPath: path, isDirectory: true)
}

private func isStrictSemVer(_ version: String) -> Bool {
    guard !version.isEmpty,
          version.utf8.count <= 128,
          version.utf8.allSatisfy({ $0 < 0x80 }),
          !version.utf8.contains(0),
          !version.contains("/"),
          version != ".",
          version != ".." else {
        return false
    }
    let buildParts = version.split(separator: "+", omittingEmptySubsequences: false)
    guard buildParts.count <= 2,
          buildParts.allSatisfy({ !$0.isEmpty }) else {
        return false
    }
    let release = buildParts[0]
    if buildParts.count == 2,
       !validSemVerIdentifiers(buildParts[1], rejectNumericLeadingZero: false) {
        return false
    }
    let prereleaseParts = release.split(
        separator: "-",
        maxSplits: 1,
        omittingEmptySubsequences: false
    )
    guard prereleaseParts.allSatisfy({ !$0.isEmpty }) else {
        return false
    }
    let core = prereleaseParts[0].split(separator: ".", omittingEmptySubsequences: false)
    guard core.count == 3,
          core.allSatisfy(validSemVerCoreIdentifier) else {
        return false
    }
    return prereleaseParts.count == 1
        || validSemVerIdentifiers(prereleaseParts[1], rejectNumericLeadingZero: true)
}

private func validSemVerCoreIdentifier(_ identifier: Substring) -> Bool {
    guard !identifier.isEmpty,
          identifier.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else {
        return false
    }
    return identifier == "0" || identifier.first != "0"
}

private func validSemVerIdentifiers(
    _ value: Substring,
    rejectNumericLeadingZero: Bool
) -> Bool {
    let identifiers = value.split(separator: ".", omittingEmptySubsequences: false)
    return !identifiers.isEmpty && identifiers.allSatisfy { identifier in
        guard !identifier.isEmpty,
              identifier.utf8.allSatisfy({ byte in
                  (byte >= 0x30 && byte <= 0x39)
                      || (byte >= 0x41 && byte <= 0x5a)
                      || (byte >= 0x61 && byte <= 0x7a)
                      || byte == 0x2d
              }) else {
            return false
        }
        let numeric = identifier.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 })
        return !rejectNumericLeadingZero
            || !numeric
            || identifier == "0"
            || identifier.first != "0"
    }
}

private func isLowercaseSHA256(_ value: String) -> Bool {
    value.utf8.count == 64
        && value.utf8.allSatisfy({
            ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66)
        })
}

private func deterministicPackageDigest(at root: URL, expectedDigest: String?) throws -> String {
    let requiredFiles = [
        ".codex-plugin/plugin.json",
        ".mcp.json",
        "skills/release-radar/SKILL.md",
    ]
    let requiredDirectories: Set<String> = [
        ".codex-plugin",
        "skills",
        "skills/release-radar",
    ]
    var observedFiles = Set<String>()
    var observedDirectories = Set<String>()

    var rootStat = stat()
    guard lstat(root.path, &rootStat) == 0,
          rootStat.st_mode & S_IFMT == S_IFDIR,
          rootStat.st_mode & S_IFMT != S_IFLNK else {
        throw ProbeFailure(kind: .untrusted)
    }

    func visit(_ directory: URL, relativeDirectory: String) throws {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        } catch {
            throw ProbeFailure(kind: .untrusted)
        }
        for name in names {
            guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
                throw ProbeFailure(kind: .untrusted)
            }
            let relativePath = relativeDirectory.isEmpty ? name : "\(relativeDirectory)/\(name)"
            let url = directory.appendingPathComponent(name, isDirectory: false)
            var metadata = stat()
            guard lstat(url.path, &metadata) == 0 else {
                throw ProbeFailure(kind: .untrusted)
            }
            let type = metadata.st_mode & S_IFMT
            if type == S_IFDIR {
                guard requiredDirectories.contains(relativePath) else {
                    throw ProbeFailure(kind: .untrusted)
                }
                guard observedDirectories.insert(relativePath).inserted else {
                    throw ProbeFailure(kind: .untrusted)
                }
                try visit(url, relativeDirectory: relativePath)
            } else if type == S_IFREG {
                guard requiredFiles.contains(relativePath) else {
                    throw ProbeFailure(kind: .untrusted)
                }
                guard observedFiles.insert(relativePath).inserted else {
                    throw ProbeFailure(kind: .untrusted)
                }
            } else {
                throw ProbeFailure(kind: .untrusted)
            }
        }
    }

    try visit(root, relativeDirectory: "")
    guard observedFiles == Set(requiredFiles), observedDirectories == requiredDirectories else {
        throw ProbeFailure(kind: .untrusted)
    }

    var hasher = SHA256()
    for relativePath in requiredFiles.sorted() {
        guard !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..") else {
            throw ProbeFailure(kind: .untrusted)
        }
        let fileURL = root.appendingPathComponent(relativePath)
        let contents = try readStableRegularFile(fileURL)
        hasher.update(data: Data(relativePath.utf8))
        hasher.update(data: Data([0]))
        var length = UInt64(contents.count).bigEndian
        withUnsafeBytes(of: &length) { bytes in
            hasher.update(data: Data(bytes))
        }
        hasher.update(data: contents)
    }
    let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    if let expectedDigest, digest != expectedDigest.lowercased() {
        throw ProbeFailure(kind: .postcondition)
    }
    return digest
}

private func readStableRegularFile(_ url: URL) throws -> Data {
    var beforePath = stat()
    guard lstat(url.path, &beforePath) == 0,
          beforePath.st_mode & S_IFMT == S_IFREG,
          beforePath.st_mode & S_IFMT != S_IFLNK else {
        throw ProbeFailure(kind: .untrusted)
    }
    let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
    guard descriptor >= 0 else {
        throw ProbeFailure(kind: .untrusted)
    }
    defer { close(descriptor) }

    var beforeRead = stat()
    guard fstat(descriptor, &beforeRead) == 0,
          beforeRead.st_mode & S_IFMT == S_IFREG,
          beforeRead.st_dev == beforePath.st_dev,
          beforeRead.st_ino == beforePath.st_ino else {
        throw ProbeFailure(kind: .untrusted)
    }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
        let count = read(descriptor, &buffer, buffer.count)
        if count == 0 {
            break
        }
        guard count > 0 else {
            if errno == EINTR { continue }
            throw ProbeFailure(kind: .untrusted)
        }
        data.append(buffer, count: count)
    }

    var afterRead = stat()
    guard fstat(descriptor, &afterRead) == 0,
          beforeRead.st_dev == afterRead.st_dev,
          beforeRead.st_ino == afterRead.st_ino,
          beforeRead.st_size == afterRead.st_size,
          beforeRead.st_mtimespec.tv_sec == afterRead.st_mtimespec.tv_sec,
          beforeRead.st_mtimespec.tv_nsec == afterRead.st_mtimespec.tv_nsec,
          beforeRead.st_mode == afterRead.st_mode,
          data.count == Int(afterRead.st_size) else {
        throw ProbeFailure(kind: .untrusted)
    }
    return data
}

private func verifyFixedCodexExecutable(_ candidate: URL) throws {
    let fixedPath = "/Applications/ChatGPT.app/Contents/Resources/codex"
    guard candidate.standardizedFileURL.path == fixedPath else {
        throw ProbeFailure(kind: .untrusted)
    }
    try verifyCodexCandidate(candidate)
}

private func verifyCodexCandidate(_ candidate: URL) throws {
    let appURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
    try verifyPathComponents(candidate, finalType: S_IFREG)
    var executableStat = stat()
    guard lstat(candidate.path, &executableStat) == 0,
          executableStat.st_mode & 0o022 == 0,
          executableStat.st_mode & 0o111 != 0 else {
        throw ProbeFailure(kind: .untrusted)
    }
    try verifyPathComponents(appURL, finalType: S_IFDIR)
    try runStrictCodesignVerification(candidate)
    try validateSigningIdentity(
        candidate,
        identifier: "codex",
        teamIdentifier: "2DC432GLL2",
        requireHardenedRuntime: true
    )
    try runStrictCodesignVerification(appURL)
    try validateSigningIdentity(
        appURL,
        identifier: "com.openai.codex",
        teamIdentifier: "2DC432GLL2",
        requireHardenedRuntime: true
    )
}

private func verifyPathComponents(_ url: URL, finalType: mode_t) throws {
    let path = url.path
    guard path.hasPrefix("/") else {
        throw ProbeFailure(kind: .untrusted)
    }
    let components = path.split(separator: "/").map(String.init)
    var current = URL(fileURLWithPath: "/", isDirectory: true)
    for (index, component) in components.enumerated() {
        current.appendPathComponent(component)
        var metadata = stat()
        guard lstat(current.path, &metadata) == 0,
              metadata.st_mode & S_IFMT != S_IFLNK else {
            throw ProbeFailure(kind: .untrusted)
        }
        let expectedType = index == components.count - 1 ? finalType : S_IFDIR
        guard metadata.st_mode & S_IFMT == expectedType else {
            throw ProbeFailure(kind: .untrusted)
        }
    }
}

private func runStrictCodesignVerification(_ url: URL) throws {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments = ["--verify", "--strict", url.path]
    process.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
    process.environment = [
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
    ]
    process.standardOutput = stdout
    process.standardError = stderr
    do {
        try process.run()
    } catch {
        throw ProbeFailure(kind: .untrusted)
    }
    let deadline = Date().addingTimeInterval(15)
    while process.isRunning, Date() < deadline {
        usleep(10_000)
    }
    if process.isRunning {
        process.terminate()
    }
    process.waitUntilExit()
    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
        throw ProbeFailure(kind: .untrusted)
    }
}

private func validateSigningIdentity(
    _ url: URL,
    identifier: String,
    teamIdentifier: String,
    requireHardenedRuntime: Bool
) throws {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
          let staticCode else {
        throw ProbeFailure(kind: .untrusted)
    }

    let requirementText = "identifier \"\(identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    var requirement: SecRequirement?
    guard SecRequirementCreateWithString(
        requirementText as CFString,
        SecCSFlags(),
        &requirement
    ) == errSecSuccess, let requirement else {
        throw ProbeFailure(kind: .untrusted)
    }
    let validationFlags = SecCSFlags(rawValue: UInt32(kSecCSStrictValidate | kSecCSCheckAllArchitectures))
    guard SecStaticCodeCheckValidity(staticCode, validationFlags, requirement) == errSecSuccess else {
        throw ProbeFailure(kind: .untrusted)
    }

    var signingInformation: CFDictionary?
    let informationFlags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
    guard SecCodeCopySigningInformation(
        staticCode,
        informationFlags,
        &signingInformation
    ) == errSecSuccess, let dictionary = signingInformation as? [String: Any] else {
        throw ProbeFailure(kind: .untrusted)
    }
    guard dictionary[kSecCodeInfoIdentifier as String] as? String == identifier,
          dictionary[kSecCodeInfoTeamIdentifier as String] as? String == teamIdentifier else {
        throw ProbeFailure(kind: .untrusted)
    }
    if requireHardenedRuntime {
        guard let flags = dictionary[kSecCodeInfoFlags as String] as? NSNumber,
              flags.uint32Value & 0x0001_0000 != 0 else {
            throw ProbeFailure(kind: .untrusted)
        }
    }
}

private func runBoundedExecutable(
    executableURL: URL,
    arguments: [String],
    currentDirectoryURL: URL,
    environment: [String: String],
    operation: ProbeOperation,
    cliVersion: String,
    outputLimit: Int = 1_048_576,
    timeoutNanoseconds: UInt64 = 15_000_000_000,
    acceptedExitStatuses: Set<Int32> = [0]
) throws -> ProbeResult {
    guard (1...33_554_432).contains(outputLimit),
          (1_000_000...600_000_000_000).contains(timeoutNanoseconds),
          !acceptedExitStatuses.isEmpty,
          acceptedExitStatuses.allSatisfy({ (0...255).contains($0) }) else {
        throw ProbeFailure(kind: .untrusted)
    }
    let manager = FileManager.default
    guard executableURL.isFileURL,
          currentDirectoryURL.isFileURL,
          (try? manager.contentsOfDirectory(atPath: currentDirectoryURL.path))?.isEmpty == true,
          Set(environment.keys).isSubset(of: ["LANG", "LC_ALL", "PATH"]),
          environment["LANG"] == "C",
          environment["LC_ALL"] == "C",
          environment["PATH"] == "/usr/bin:/bin",
          !arguments.contains(where: { $0.utf8.contains(0) }) else {
        throw ProbeFailure(kind: .untrusted)
    }

    var stdoutPipe = [Int32](repeating: -1, count: 2)
    var stderrPipe = [Int32](repeating: -1, count: 2)
    guard pipe(&stdoutPipe) == 0, pipe(&stderrPipe) == 0 else {
        closePipe(stdoutPipe)
        closePipe(stderrPipe)
        throw ProbeFailure(kind: .unavailable)
    }
    var parentDescriptorsOpen = true
    defer {
        if parentDescriptorsOpen {
            closePipe(stdoutPipe)
            closePipe(stderrPipe)
        }
    }

    var fileActions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?
    guard posix_spawn_file_actions_init(&fileActions) == 0,
          posix_spawnattr_init(&attributes) == 0 else {
        throw ProbeFailure(kind: .unavailable)
    }
    defer {
        posix_spawn_file_actions_destroy(&fileActions)
        posix_spawnattr_destroy(&attributes)
    }

    guard posix_spawn_file_actions_addopen(
        &fileActions,
        STDIN_FILENO,
        "/dev/null",
        O_RDONLY,
        0
    ) == 0,
    posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO) == 0,
    posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO) == 0,
    posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0]) == 0,
    posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[1]) == 0,
    posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0]) == 0,
    posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1]) == 0,
    addSpawnChdirAction(&fileActions, path: currentDirectoryURL.path) == 0 else {
        throw ProbeFailure(kind: .unavailable)
    }

    var emptySignals = sigset_t()
    sigemptyset(&emptySignals)
    var defaultSignals = sigset_t()
    sigemptyset(&defaultSignals)
    sigaddset(&defaultSignals, SIGTERM)
    sigaddset(&defaultSignals, SIGINT)
    sigaddset(&defaultSignals, SIGPIPE)
    let spawnFlags = Int16(
        POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
    )
    guard posix_spawnattr_setflags(&attributes, spawnFlags) == 0,
          posix_spawnattr_setpgroup(&attributes, 0) == 0,
          posix_spawnattr_setsigmask(&attributes, &emptySignals) == 0,
          posix_spawnattr_setsigdefault(&attributes, &defaultSignals) == 0 else {
        throw ProbeFailure(kind: .unavailable)
    }

    let argv = [executableURL.path] + arguments
    let env = environment.keys.sorted().map { "\($0)=\(environment[$0]!)" }
    var childPID = pid_t()
    let started = DispatchTime.now().uptimeNanoseconds
    let spawnStatus = withMutableCStringArray(argv) { argvPointer in
        withMutableCStringArray(env) { envPointer in
            posix_spawn(
                &childPID,
                executableURL.path,
                &fileActions,
                &attributes,
                argvPointer,
                envPointer
            )
        }
    }
    guard spawnStatus == 0, childPID > 0 else {
        throw ProbeFailure(kind: .unavailable)
    }

    close(stdoutPipe[1])
    close(stderrPipe[1])
    stdoutPipe[1] = -1
    stderrPipe[1] = -1

    guard getpgid(childPID) == childPID else {
        _ = kill(-childPID, SIGKILL)
        var status = Int32()
        while waitpid(childPID, &status, 0) == -1 && errno == EINTR {}
        throw ProbeFailure(kind: .postcondition)
    }

    let capture = BoundedOutputCapture(limit: outputLimit)
    let readers = DispatchGroup()
    let stdoutReadDescriptor = stdoutPipe[0]
    let stderrReadDescriptor = stderrPipe[0]
    readers.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        readOutput(descriptor: stdoutReadDescriptor, stream: .stdout, capture: capture)
        readers.leave()
    }
    readers.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        readOutput(descriptor: stderrReadDescriptor, stream: .stderr, capture: capture)
        readers.leave()
    }
    stdoutPipe[0] = -1
    stderrPipe[0] = -1
    parentDescriptorsOpen = false

    var waitStatus = Int32()
    var childReaped = false
    var failureKind: ProbeFailure.Kind?
    let deadline = started + timeoutNanoseconds
    while !childReaped {
        let waited = waitpid(childPID, &waitStatus, WNOHANG)
        if waited == childPID {
            childReaped = true
            break
        }
        if waited == -1, errno != EINTR {
            failureKind = .postcondition
            break
        }
        if capture.didOverflow {
            failureKind = .outputOverflow
            break
        }
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            failureKind = .timeout
            break
        }
        usleep(10_000)
    }

    if childReaped {
        if !waitStatusExited(waitStatus)
            || !acceptedExitStatuses.contains(waitStatusExitCode(waitStatus)) {
            failureKind = .postcondition
        } else if processGroupExists(childPID) {
            failureKind = .postcondition
        }
    }

    if failureKind != nil {
        try terminateAndReapProcessGroup(
            groupID: childPID,
            childPID: childPID,
            waitStatus: &waitStatus,
            childReaped: &childReaped
        )
    } else if !childReaped {
        while waitpid(childPID, &waitStatus, 0) == -1 && errno == EINTR {}
        childReaped = true
    }

    guard readers.wait(timeout: .now() + 2) == .success else {
        throw ProbeFailure(kind: .postcondition)
    }
    let output = try finalizedOutput(capture)
    if let failureKind {
        throw ProbeFailure(kind: failureKind)
    }
    guard childReaped,
          waitStatusExited(waitStatus),
          acceptedExitStatuses.contains(waitStatusExitCode(waitStatus)) else {
        throw ProbeFailure(kind: .postcondition)
    }
    let elapsed = DispatchTime.now().uptimeNanoseconds - started
    return ProbeResult(
        cliVersion: cliVersion,
        operation: operation,
        exitStatus: waitStatusExitCode(waitStatus),
        stdout: output.stdout,
        stderr: output.stderr,
        elapsedMilliseconds: Int(elapsed / 1_000_000)
    )
}

private func runInternalChild(arguments: ArraySlice<String>) -> Int32 {
    let values = Array(arguments)
    guard let mode = values.first,
          let pidOption = values.firstIndex(of: "--pid-file"),
          pidOption + 1 < values.count else {
        return 64
    }
    let pidFile = URL(fileURLWithPath: values[pidOption + 1])
    if mode == "fast-overflow-stdout" {
        writeRepeatedByte(descriptor: STDOUT_FILENO, count: 1_048_577)
        return 0
    }
    if mode == "fast-overflow-stderr" {
        writeRepeatedByte(descriptor: STDERR_FILENO, count: 1_048_577)
        return 0
    }
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    var grandchildPID = pid_t()
    let argv = [executable.path, "internal-grandchild"]
    let env = ["LANG=C", "LC_ALL=C", "PATH=/usr/bin:/bin"]
    let spawnStatus = withMutableCStringArray(argv) { argvPointer in
        withMutableCStringArray(env) { envPointer in
            posix_spawn(
                &grandchildPID,
                executable.path,
                nil,
                nil,
                argvPointer,
                envPointer
            )
        }
    }
    guard spawnStatus == 0, grandchildPID > 0 else {
        return 70
    }
    do {
        try Data("\(getpid())\n\(grandchildPID)\n".utf8).write(to: pidFile, options: .atomic)
    } catch {
        _ = kill(grandchildPID, SIGKILL)
        var status = Int32()
        while waitpid(grandchildPID, &status, 0) == -1 && errno == EINTR {}
        return 74
    }

    switch mode {
    case "timeout":
        sleep(16)
    case "overflow-stdout":
        writeRepeatedByte(descriptor: STDOUT_FILENO, count: 1_048_577)
        sleep(16)
    case "overflow-stderr":
        writeRepeatedByte(descriptor: STDERR_FILENO, count: 1_048_577)
        sleep(16)
    case "abnormal":
        return 42
    default:
        _ = kill(grandchildPID, SIGKILL)
        var status = Int32()
        while waitpid(grandchildPID, &status, 0) == -1 && errno == EINTR {}
        return 64
    }

    _ = kill(grandchildPID, SIGKILL)
    var status = Int32()
    while waitpid(grandchildPID, &status, 0) == -1 && errno == EINTR {}
    return 0
}

private func runInternalGrandchild() -> Int32 {
    sleep(60)
    return 0
}

private enum CapturedStream {
    case stdout
    case stderr
}

private final class BoundedOutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var stdout = Data()
    private var stderr = Data()
    private var overflow = false
    private var readError = false

    init(limit: Int) {
        self.limit = limit
    }

    var didOverflow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return overflow
    }

    var didReadFail: Bool {
        lock.lock()
        defer { lock.unlock() }
        return readError
    }

    func recordReadError() {
        lock.lock()
        readError = true
        lock.unlock()
    }

    func append(_ data: Data, to stream: CapturedStream) {
        lock.lock()
        defer { lock.unlock() }
        var target = stream == .stdout ? stdout : stderr
        if target.count + data.count > limit {
            let remaining = max(0, limit - target.count)
            if remaining > 0 {
                target.append(data.prefix(remaining))
            }
            overflow = true
        } else {
            target.append(data)
        }
        if stream == .stdout {
            stdout = target
        } else {
            stderr = target
        }
    }

    func snapshot() -> (stdout: Data, stderr: Data) {
        lock.lock()
        defer { lock.unlock() }
        return (stdout, stderr)
    }
}

private func readOutput(
    descriptor: Int32,
    stream: CapturedStream,
    capture: BoundedOutputCapture
) {
    defer {
        if descriptor >= 0 { close(descriptor) }
    }
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    while true {
        let count = read(descriptor, &buffer, buffer.count)
        if count == 0 { return }
        if count < 0 {
            if errno == EINTR { continue }
            capture.recordReadError()
            return
        }
        capture.append(Data(buffer.prefix(count)), to: stream)
    }
}

private func finalizedOutput(
    _ capture: BoundedOutputCapture
) throws -> (stdout: Data, stderr: Data) {
    if capture.didOverflow {
        throw ProbeFailure(kind: .outputOverflow)
    }
    if capture.didReadFail {
        throw ProbeFailure(kind: .postcondition)
    }
    return capture.snapshot()
}

private func terminateAndReapProcessGroup(
    groupID: pid_t,
    childPID: pid_t,
    waitStatus: inout Int32,
    childReaped: inout Bool
) throws {
    if processGroupExists(groupID) {
        _ = kill(-groupID, SIGTERM)
    }
    let termDeadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
    while DispatchTime.now().uptimeNanoseconds < termDeadline {
        if !childReaped {
            let waited = waitpid(childPID, &waitStatus, WNOHANG)
            if waited == childPID {
                childReaped = true
            } else if waited == -1, errno != EINTR, errno != ECHILD {
                throw ProbeFailure(kind: .postcondition)
            }
        }
        if !processGroupExists(groupID) { break }
        usleep(10_000)
    }
    if processGroupExists(groupID) {
        _ = kill(-groupID, SIGKILL)
    }
    if !childReaped {
        while true {
            let waited = waitpid(childPID, &waitStatus, 0)
            if waited == childPID {
                childReaped = true
                break
            }
            if waited == -1, errno == EINTR { continue }
            if waited == -1, errno == ECHILD {
                childReaped = true
                break
            }
            throw ProbeFailure(kind: .postcondition)
        }
    }
    let killDeadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while processGroupExists(groupID), DispatchTime.now().uptimeNanoseconds < killDeadline {
        usleep(10_000)
    }
    guard !processGroupExists(groupID) else {
        throw ProbeFailure(kind: .postcondition)
    }
}

private func processGroupExists(_ groupID: pid_t) -> Bool {
    errno = 0
    return kill(-groupID, 0) == 0 || errno == EPERM
}

private func waitStatusExited(_ status: Int32) -> Bool {
    status & 0x7f == 0
}

private func waitStatusExitCode(_ status: Int32) -> Int32 {
    (status >> 8) & 0xff
}

private func writeRepeatedByte(descriptor: Int32, count: Int) {
    let chunk = [UInt8](repeating: 0x41, count: 16 * 1024)
    var remaining = count
    while remaining > 0 {
        let requested = min(remaining, chunk.count)
        let written = write(descriptor, chunk, requested)
        if written < 0 {
            if errno == EINTR { continue }
            return
        }
        remaining -= written
    }
}

private func closePipe(_ descriptors: [Int32]) {
    for descriptor in descriptors where descriptor >= 0 {
        close(descriptor)
    }
}

private func withMutableCStringArray<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Result
) -> Result {
    let storage = strings.map { strdup($0)! }
    defer {
        for pointer in storage {
            free(pointer)
        }
    }
    var pointers: [UnsafeMutablePointer<CChar>?] = storage.map { $0 }
    pointers.append(nil)
    return pointers.withUnsafeMutableBufferPointer { buffer in
        body(buffer.baseAddress)
    }
}

private typealias SpawnChdirFunction = @convention(c) (
    UnsafeMutablePointer<posix_spawn_file_actions_t?>?,
    UnsafePointer<CChar>
) -> Int32

private func addSpawnChdirAction(
    _ actions: inout posix_spawn_file_actions_t?,
    path: String
) -> Int32 {
    let defaultSymbolScope = UnsafeMutableRawPointer(bitPattern: -2)
    let symbol = dlsym(defaultSymbolScope, "posix_spawn_file_actions_addchdir")
        ?? dlsym(defaultSymbolScope, "posix_spawn_file_actions_addchdir_np")
    guard let symbol else { return ENOSYS }
    let function = unsafeBitCast(symbol, to: SpawnChdirFunction.self)
    return path.withCString { function(&actions, $0) }
}

@main
private enum CodexPluginLifecycleFeasibility {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.first == "internal-child" {
                exit(runInternalChild(arguments: arguments.dropFirst()))
            }
            if arguments.first == "internal-grandchild" {
                exit(runInternalGrandchild())
            }
            if arguments.first != "self-test" {
                do {
                    let invocation = try parseControllerInvocation(arguments)
                    if invocation.mode == .bridgePreflight {
                        let report = runBridgePreflightController()
                        try writeJSON(report, to: .standardOutput)
                        exit(report.ok ? 0 : 1)
                    }
                    guard let runtimePath = ProcessInfo.processInfo.environment["RR_PLUGIN_PROBE_ROOT"] else {
                        throw ProbeFailure(kind: .unavailable)
                    }
                    if [
                        ControllerMode.legacyMCPPreflight,
                        .legacyMCPRemove,
                        .legacyMCPRestore,
                        .bundledMCPPreflight,
                    ].contains(invocation.mode) {
                        let report = try runLiveLegacyMCPController(
                            invocation.mode,
                            runtimeRoot: URL(fileURLWithPath: runtimePath, isDirectory: true)
                        )
                        try writeJSON(report, to: .standardOutput)
                        exit(0)
                    }
                    if invocation.mode == .installedIntegrity {
                        let report = try runLiveInstalledIntegrityController(
                            runtimeRoot: URL(fileURLWithPath: runtimePath, isDirectory: true)
                        )
                        try writeJSON(report, to: .standardOutput)
                        exit(0)
                    }
                    if invocation.mode == .reinstall {
                        let report = try runLiveReinstallController(
                            runtimeRoot: URL(fileURLWithPath: runtimePath, isDirectory: true)
                        )
                        try writeJSON(report, to: .standardOutput)
                        exit(0)
                    }
                    if invocation.mode == .step7Prepare {
                        let report = try runLiveStep7PreparationController(
                            invocation: invocation,
                            runtimeRoot: URL(fileURLWithPath: runtimePath, isDirectory: true),
                            invocationWorkingRoot: URL(
                                fileURLWithPath: FileManager.default.currentDirectoryPath,
                                isDirectory: true
                            )
                        )
                        try writeJSON(report, to: .standardOutput)
                        exit(0)
                    }
                    if invocation.mode == .ownedCLICancellation {
                        let report = try runOwnedCLICancellationController(
                            runtimeRoot: URL(fileURLWithPath: runtimePath, isDirectory: true)
                        )
                        try writeJSON(report, to: .standardOutput)
                        exit(0)
                    }
                    let report = try runLiveControllerInvocation(
                        invocation,
                        runtimeRoot: URL(fileURLWithPath: runtimePath, isDirectory: true),
                        invocationWorkingRoot: URL(
                            fileURLWithPath: FileManager.default.currentDirectoryPath,
                            isDirectory: true
                        )
                    )
                    try writeJSON(report, to: .standardOutput)
                    exit(0)
                } catch let failure as ProbeFailure {
                    exitWithControllerFailure(failure.kind)
                } catch {
                    exitWithControllerFailure(.unavailable)
                }
            }
            let fixtureRoot = try option("--fixture-root", in: arguments)
            let cli = try option("--cli", in: arguments)
            guard let runtimePath = ProcessInfo.processInfo.environment["RR_PLUGIN_PROBE_ROOT"] else {
                throw TestFailure(description: "RR_PLUGIN_PROBE_ROOT is required")
            }
            let runtimeRoot = URL(fileURLWithPath: runtimePath, isDirectory: true)
            let invocationWorkingRoot = URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath,
                isDirectory: true
            )
            let validatedFixtureRoot = try validateFixtureRootArgument(
                fixtureRoot,
                runtimeRoot: runtimeRoot,
                invocationWorkingRoot: invocationWorkingRoot
            )
            let context = try SelfTestContext(
                runtimeRoot: runtimeRoot,
                fixtureRoot: validatedFixtureRoot.url,
                cliURL: URL(fileURLWithPath: cli)
            )
            exit(SelfTests.run(context: context))
        } catch {
            FileHandle.standardError.write(Data("ERROR \(error)\n".utf8))
            exit(2)
        }
    }

    private static func option(_ name: String, in arguments: [String]) throws -> String {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
            throw TestFailure(description: "missing \(name)")
        }
        return arguments[index + 1]
    }
}
