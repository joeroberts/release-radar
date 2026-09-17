import Foundation
import ReleaseRadarCore
import Security

/// The app's bounded configuration client. The installer keeps its four operations.
actor ProjectExecutionSetupClient: ProjectExecutionConfiguring {
    private let plugin: CodexPluginLifecycleCoordinator?
    private let bundle: URL
    private var transport: AppServerTransport?
    private var cleanupFailure: AppServerTransportError?

    init(plugin: CodexPluginLifecycleCoordinator?, bundle: URL = Bundle.main.bundleURL) {
        self.plugin = plugin; self.bundle = bundle
    }

    static func setup(plugin: CodexPluginLifecycleCoordinator?) -> ProjectExecutionSetupCoordinator {
        let bundle = Bundle.main.bundleURL
        return .init(configuration: ProjectExecutionSetupClient(plugin: plugin, bundle: bundle),
                     handlerPath: bundle.appendingPathComponent("Contents/Helpers/ReleaseRadarCoordinator").path)
    }

    static func assignments(plugin: CodexPluginLifecycleCoordinator?) -> ProjectExecutionAssignmentCoordinator {
        let bundle = Bundle.main.bundleURL
        let configuration = ProjectExecutionSetupClient(plugin: plugin, bundle: bundle)
        return .init(configuration: configuration,
            handlerPath: bundle.appendingPathComponent("Contents/Helpers/ReleaseRadarCoordinator").path)
    }

    func validateInstallation(handlerPath: String) async throws {
        try await validateHandlerIdentity(handlerPath: handlerPath)
        guard let plugin else { throw ProjectExecutionError.unavailable }
        let package = try CodexPluginPackage(rootURL: bundle.appendingPathComponent("Contents/Resources/CodexPluginMarketplace"))
        let observation = await plugin.recoveryStatus()
        guard observation.error == nil,
              case let .known(receipt) = observation.management, receipt.intent == .managedInstalled,
              case let .clean(version, digest)? = observation.observedState,
              version == package.version, digest == package.digest,
              receipt.managedVersion == version, receipt.managedDigest == digest else {
            throw ProjectExecutionError.unavailable
        }
    }

    func validateHandlerIdentity(handlerPath: String) throws {
        guard handlerPath == bundle.appendingPathComponent("Contents/Helpers/ReleaseRadarCoordinator").path,
              bundle.resolvingSymlinksInPath().path == bundle.path else { throw ProjectExecutionError.unavailable }
        try verifyCode(bundle, identifier: "com.rekonlabs.ReleaseRadar")
        try verifyCode(URL(fileURLWithPath: handlerPath), identifier: "com.rekonlabs.ReleaseRadarCoordinator")
        _ = try CodexPluginPackage(rootURL: bundle.appendingPathComponent("Contents/Resources/CodexPluginMarketplace"))
    }

    private func verifyCode(_ url: URL, identifier: String) throws {
        guard url.resolvingSymlinksInPath().path == url.path else { throw ProjectExecutionError.identityMismatch }
        var code: SecStaticCode?
        var requirement: SecRequirement?
        let identity = "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              SecRequirementCreateWithString(identity as CFString, [], &requirement) == errSecSuccess,
              let code, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess else {
            throw ProjectExecutionError.unavailable
        }
    }

    private func rpc(_ method: String, _ params: RPCObject) async throws -> RPCObject {
        if let cleanupFailure { throw cleanupFailure }
        if transport == nil {
            let connection = try AppServerTransport(executable: CodexExecutionIdentity.executable,
                arguments: ["app-server", "--listen", "stdio://"], onMessage: { _ in })
            transport = connection
            do {
                _ = try await connection.call("initialize", RPCObject(["clientInfo": ["name": "release-radar-setup", "version": "1"], "capabilities": ["experimentalApi": true]]))
                try connection.send(["method": "initialized"])
            } catch {
                do { try connection.close() }
                catch {
                    let failure = AppServerTransportError(message: "Execution setup connection cleanup failed: \(error.localizedDescription)", outcomeUnknown: true)
                    cleanupFailure = failure; throw failure
                }
                transport = nil
                throw error
            }
        }
        guard let transport else { throw ProjectExecutionError.unavailable }
        return try await transport.call(method, params)
    }

    private func read(_ root: String) async throws -> [String: Any] {
        try await rpc("config/read", RPCObject(["cwd": root, "includeLayers": true])).object()
    }

    private func userLayer(_ result: [String: Any]) throws -> [String: Any] {
        let layers = (result["layers"] as? [[String: Any]] ?? []).filter {
            guard let name = $0["name"] as? [String: Any] else { return false }
            return name["type"] as? String == "user" && (name["profile"] == nil || name["profile"] is NSNull)
        }
        guard layers.count == 1, let layer = layers.first, layer["version"] is String,
              let name = layer["name"] as? [String: Any], let file = name["file"] as? String,
              file.hasPrefix("/"), file == URL(fileURLWithPath: file).standardizedFileURL.path,
              URL(fileURLWithPath: file).lastPathComponent == "config.toml",
              layer["config"] is [String: Any] else { throw ProjectExecutionError.unavailable }
        return layer
    }

    private func quoted(_ key: String) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: key, options: [.fragmentsAllowed]), as: UTF8.self)
    }

    private func writeUser(root: String, layer: [String: Any], key: String, value: Any) async throws {
        guard let name = layer["name"] as? [String: Any], let file = name["file"] as? String,
              let version = layer["version"] as? String else { throw ProjectExecutionError.unavailable }
        _ = try await rpc("config/batchWrite", RPCObject(["filePath": file, "expectedVersion": version,
            "edits": [["keyPath": key, "value": value, "mergeStrategy": "upsert"]], "reloadUserConfig": true]))
    }

    func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage {
        let result = try await read(primaryRoot)
        let layers = (result["layers"] as? [[String: Any]] ?? []).filter {
            let name = $0["name"] as? [String: Any]
            return name?["type"] as? String == "project" && name?["dotCodexFolder"] as? String == primaryRoot + "/.codex"
        }
        guard layers.count <= 1 else { throw ProjectExecutionError.conflict }
        if let raw = layers.first?["config"] as? [String: Any], let hooks = raw["hooks"] {
            guard hooks is [String: Any] else { throw ProjectExecutionError.conflict }
            return .inline(try JSONSerialization.data(withJSONObject: ["hooks": hooks], options: [.sortedKeys, .prettyPrinted]))
        }
        return .projectFile
    }

    func saveInlineHook(primaryRoot: String, data: Data, expected: Data) async throws {
        guard case let .inline(current) = try await hookStorage(primaryRoot: primaryRoot), current == expected,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = object["hooks"] as? [String: Any] else { throw ProjectExecutionError.conflict }
        let result = try await read(primaryRoot)
        let layers = (result["layers"] as? [[String: Any]] ?? []).filter {
            let name = $0["name"] as? [String: Any]
            return name?["type"] as? String == "project" && name?["dotCodexFolder"] as? String == primaryRoot + "/.codex"
        }
        guard let layer = layers.first, let version = layer["version"] as? String,
              let raw = layer["config"] as? [String: Any], let old = raw["hooks"],
              try JSONSerialization.data(withJSONObject: ["hooks": old], options: [.sortedKeys, .prettyPrinted]) == expected else { throw ProjectExecutionError.conflict }
        _ = try await rpc("config/batchWrite", RPCObject(["filePath": primaryRoot + "/.codex/config.toml", "expectedVersion": version,
            "edits": [["keyPath": "hooks", "value": hooks, "mergeStrategy": "replace"]], "reloadUserConfig": true]))
        guard case let .inline(actual) = try await hookStorage(primaryRoot: primaryRoot), actual == data else { throw ProjectExecutionError.conflict }
    }

    func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws {
        let layer = try userLayer(await read(primaryRoot))
        let raw = layer["config"] as? [String: Any] ?? [:]
        let desired: [String: Any] = ["filesystem": profile.filesystemObject, "network": ["enabled": false]]
        if let existing = (raw["permissions"] as? [String: Any])?[profile.id] {
            guard let object = existing as? [String: Any], NSDictionary(dictionary: object).isEqual(to: desired) else { throw ProjectExecutionError.conflict }
        } else {
            try await writeUser(root: primaryRoot, layer: layer, key: "permissions." + quoted(profile.id), value: desired)
        }
        let readback = try userLayer(await read(primaryRoot))
        let config = readback["config"] as? [String: Any] ?? [:]
        guard let actual = (config["permissions"] as? [String: Any])?[profile.id] as? [String: Any],
              NSDictionary(dictionary: actual).isEqual(to: desired) else { throw ProjectExecutionError.conflict }
    }

    func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool) async throws {
            let inline: Bool
            switch try await hookStorage(primaryRoot: primaryRoot) {
            case .projectFile: inline = false
            case .inline: inline = true
            }
            var layer = try userLayer(await read(primaryRoot))
            let raw = layer["config"] as? [String: Any] ?? [:]
            let projects = raw["projects"] as? [String: Any] ?? [:]
            let trust = (projects[primaryRoot] as? [String: Any])?["trust_level"] as? String
            if trust != "trusted" {
                guard permitOwnedTrust, trust == nil else { throw ProjectExecutionError.hookNotReady }
                try await writeUser(root: primaryRoot, layer: layer, key: "projects." + quoted(primaryRoot) + ".trust_level", value: "trusted")
                layer = try userLayer(await read(primaryRoot))
                let readback = layer["config"] as? [String: Any] ?? [:]
                guard ((readback["projects"] as? [String: Any])?[primaryRoot] as? [String: Any])?["trust_level"] as? String == "trusted" else { throw ProjectExecutionError.hookNotReady }
            }
            let reply = try await rpc("hooks/list", RPCObject(["cwds": [checkout]]))
            let owned = try ProjectExecutionHookReadiness.resolve(reply.data, checkout: checkout, primaryRoot: primaryRoot, command: command, requireTrusted: !permitOwnedTrust, inline: inline)
            if owned.trustStatus != "trusted" {
                guard permitOwnedTrust else { throw ProjectExecutionError.hookNotReady }
                layer = try userLayer(await read(primaryRoot))
                try await writeUser(root: primaryRoot, layer: layer, key: "hooks.state." + quoted(owned.key), value: ["trusted_hash": owned.currentHash])
            }
            let readback = try await rpc("hooks/list", RPCObject(["cwds": [checkout]]))
            _ = try ProjectExecutionHookReadiness.resolve(readback.data, checkout: checkout, primaryRoot: primaryRoot, command: command, requireTrusted: true, inline: inline)
    }

    func finishConfiguration() throws {
        if let cleanupFailure { throw cleanupFailure }
        guard let current = transport else { return }
        do { try current.close(); transport = nil }
        catch {
            let failure = AppServerTransportError(message: "Execution setup cleanup failed: \(error.localizedDescription)", outcomeUnknown: true)
            cleanupFailure = failure; throw failure
        }
    }
}
