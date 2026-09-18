import Foundation
import OSLog
import ReleaseRadarCore
import Security

/// The app's bounded configuration client. The installer keeps its four operations.
actor ProjectExecutionSetupClient: ProjectExecutionConfiguring {
    private let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "ExecutionSetup")
    private let plugin: CodexPluginLifecycleCoordinator?
    private let bundle: URL
    private var transport: AppServerTransport?
    private var cleanupFailure: AppServerTransportError?

    enum DisabledReasonDiagnostic: Equatable {
        case explicitUntrusted(target: ProjectLayerTarget)
        case missingTrust(target: ProjectLayerTarget)
        case unrecognized

        var message: String {
            switch self {
            case let .explicitUntrusted(target): "explicit-untrusted, target: \(target.rawValue)"
            case let .missingTrust(target): "missing-trust, target: \(target.rawValue)"
            case .unrecognized: "unrecognized"
            }
        }
    }

    enum ProjectLayerTarget: String {
        case checkout
        case primaryRoot = "primary-root"
    }

    nonisolated static func disabledReasonDiagnostic(_ reason: String, checkout: String,
                                                     primaryRoot: String) -> DisabledReasonDiagnostic {
        let explicitUntrustedSuffix = " is marked as untrusted in the effective configuration. To load project-local config, hooks, and exec policies, update its trust setting. If that setting is managed by your organization, contact your administrator."
        let missingTrustPrefix = "To load project-local config, hooks, and exec policies, add "
        let missingTrustInfix = " as a trusted project in "
        for (key, target) in [(checkout, ProjectLayerTarget.checkout), (primaryRoot, .primaryRoot)] {
            if reason == key + explicitUntrustedSuffix {
                return .explicitUntrusted(target: target)
            }
            let prefix = missingTrustPrefix + key + missingTrustInfix
            guard reason.hasPrefix(prefix), reason.hasSuffix(".") else { continue }
            let userConfigFile = String(reason.dropFirst(prefix.count).dropLast())
            if userConfigFile.hasPrefix("/"),
               URL(fileURLWithPath: userConfigFile).lastPathComponent == "config.toml",
               userConfigFile == URL(fileURLWithPath: userConfigFile).standardizedFileURL.path,
               !userConfigFile.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) {
                return .missingTrust(target: target)
            }
        }
        return .unrecognized
    }

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

    static func resources(plugin: CodexPluginLifecycleCoordinator?) -> ProjectExecutionResourceLifecycle {
        .init(configuration: ProjectExecutionSetupClient(plugin: plugin))
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

    func validateHandlerIdentity(handlerPath: String) async throws {
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

    private func rpc(_ method: String, _ params: RPCObject, readback: Bool = false, beforeWrite: @Sendable () async throws -> Void = {}) async throws -> RPCObject {
        if let cleanupFailure { throw cleanupFailure }
        if transport == nil {
            let connection = try AppServerTransport(executable: CodexExecutionIdentity.executable,
                arguments: AppServerTransport.executionSetupArguments, onMessage: { _ in })
            transport = connection
            var handshakeOperation = "initialize"
            do {
                _ = try await connection.call("initialize", RPCObject(["clientInfo": ["name": "release-radar-setup", "version": "1"], "capabilities": ["experimentalApi": true]]))
                handshakeOperation = "initialized"
                try connection.send(["method": "initialized"])
            } catch {
                do { try connection.close() }
                catch {
                    let failure = AppServerTransportError(message: "Execution setup connection cleanup failed: \(error.localizedDescription)", outcomeUnknown: true)
                    cleanupFailure = failure; throw failure
                }
                transport = nil
                if let failure = error as? AppServerTransportError {
                    throw failure.addingSetupContext(method: handshakeOperation)
                }
                throw error
            }
        }
        guard let transport else { throw ProjectExecutionError.unavailable }
        try await beforeWrite()
        do { return try await transport.call(method, params) }
        catch let failure as AppServerTransportError {
            throw failure.addingSetupContext(method: method, parameters: params, readback: readback)
        }
    }

    private func read(_ root: String, readback: Bool = false) async throws -> [String: Any] {
        try await rpc("config/read", RPCObject(["cwd": root, "includeLayers": true]), readback: readback).object()
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

    private func writeUser(root: String, layer: [String: Any], key: String, value: Any, beforeWrite: @Sendable () async throws -> Void = {}) async throws {
        guard let name = layer["name"] as? [String: Any], let file = name["file"] as? String,
              let version = layer["version"] as? String else { throw ProjectExecutionError.unavailable }
        _ = try await rpc("config/batchWrite", RPCObject(["filePath": file, "expectedVersion": version,
            "edits": [["keyPath": key, "value": value, "mergeStrategy": "upsert"]], "reloadUserConfig": true]), beforeWrite: beforeWrite)
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

    func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {
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
            "edits": [["keyPath": "hooks", "value": hooks, "mergeStrategy": "replace"]], "reloadUserConfig": true]), beforeWrite: beforeWrite)
        guard case let .inline(actual) = try await hookStorage(primaryRoot: primaryRoot), actual == data else { throw ProjectExecutionError.conflict }
        try await beforeWrite()
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
        let readback = try userLayer(await read(primaryRoot, readback: true))
        let config = readback["config"] as? [String: Any] ?? [:]
        guard let actual = (config["permissions"] as? [String: Any])?[profile.id] as? [String: Any],
              NSDictionary(dictionary: actual).isEqual(to: desired) else { throw ProjectExecutionError.conflict }
    }

    func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws {
        try await removeWorkerProfile(primaryRoot: primaryRoot, profileID: profileID, expected: expected, beforeWrite: {})
    }

    func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {
        try ProjectExecutionPaths.component(profileID)
        let layer = try userLayer(await read(primaryRoot))
        let raw = layer["config"] as? [String: Any] ?? [:]
        guard raw["permissions"] == nil || raw["permissions"] is [String: Any] else { throw ProjectExecutionError.conflict }
        let existing = raw["permissions"] as? [String: Any] ?? [:]
        let profiles = try ProjectExecutionPermissionProfile.removingOwnedProfile(id: profileID, expected: expected, from: existing)
        if existing[profileID] != nil {
            guard let name = layer["name"] as? [String: Any], let file = name["file"] as? String,
                  let version = layer["version"] as? String else { throw ProjectExecutionError.unavailable }
            _ = try await rpc("config/batchWrite", RPCObject(["filePath": file, "expectedVersion": version,
                "edits": [["keyPath": "permissions", "value": profiles, "mergeStrategy": "replace"]], "reloadUserConfig": true]), beforeWrite: beforeWrite)
        }
        let readback = try userLayer(await read(primaryRoot, readback: true))
        let config = readback["config"] as? [String: Any] ?? [:]
        guard config["permissions"] == nil || config["permissions"] is [String: Any] else { throw ProjectExecutionError.conflict }
        let actual = config["permissions"] as? [String: Any] ?? [:]
        guard actual[profileID] == nil, NSDictionary(dictionary: actual).isEqual(to: profiles) else { throw ProjectExecutionError.conflict }
        try await beforeWrite()
    }

    func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws {
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
                guard permitOwnedTrust, trust == nil else {
                    logger.error("Hook verification failed: exact primary project trust is not ready")
                    throw ProjectExecutionError.hookNotReady
                }
                try await writeUser(root: primaryRoot, layer: layer, key: "projects." + quoted(primaryRoot) + ".trust_level", value: "trusted", beforeWrite: beforeWrite)
                layer = try userLayer(await read(primaryRoot, readback: true))
                let readback = layer["config"] as? [String: Any] ?? [:]
                guard ((readback["projects"] as? [String: Any])?[primaryRoot] as? [String: Any])?["trust_level"] as? String == "trusted" else {
                    logger.error("Hook verification failed: primary project trust readback is not ready")
                    throw ProjectExecutionError.hookNotReady
                }
            }
            let reply = try await rpc("hooks/list", RPCObject(["cwds": [checkout]]))
            let owned: ProjectExecutionHookReadiness
            do {
                owned = try ProjectExecutionHookReadiness.resolve(reply.data, checkout: checkout, primaryRoot: primaryRoot, command: command, requireTrusted: !permitOwnedTrust, inline: inline)
            } catch let error as ProjectExecutionError {
                if error == .hookNotReady { logger.error("Hook verification failed: first hooks/list readiness check") }
                if error == .hookNotReady,
                   let result = try? JSONSerialization.jsonObject(with: reply.data) as? [String: Any],
                   let entries = result["data"] as? [[String: Any]],
                   let entry = entries.first(where: { $0["cwd"] as? String == checkout }),
                   let hooks = entry["hooks"] as? [[String: Any]], hooks.isEmpty {
                    do {
                        let observation = try await read(checkout)
                        if let config = observation["config"] as? [String: Any],
                           let enabled = (config["features"] as? [String: Any])?["hooks"] as? Bool {
                            if enabled {
                                logger.error("Empty hook observation: checkout config hooks feature is explicitly true")
                            } else {
                                logger.error("Empty hook observation: checkout config hooks feature is explicitly false")
                            }
                        } else {
                            logger.error("Empty hook observation: checkout config hooks feature is unspecified or unsupported")
                        }
                        if let layers = observation["layers"] as? [[String: Any]] {
                            let supported = layers.allSatisfy { layer in
                                guard let name = layer["name"] as? [String: Any], let type = name["type"] as? String else { return false }
                                return type != "project" || name["dotCodexFolder"] is String
                            }
                            let projectLayers = layers.filter { layer in
                                let name = layer["name"] as? [String: Any]
                                return name?["type"] as? String == "project" && name?["dotCodexFolder"] as? String == checkout + "/.codex"
                            }
                            if !supported {
                                logger.error("Empty hook observation: checkout project layer metadata is unsupported")
                            } else if projectLayers.isEmpty {
                                logger.error("Empty hook observation: exact checkout project layer is absent")
                            } else if projectLayers.count > 1 {
                                logger.error("Empty hook observation: exact checkout project layer is duplicated")
                            } else if let layer = projectLayers.first {
                                if layer["disabledReason"] is NSNull {
                                    logger.error("Empty hook observation: exact checkout project layer is enabled")
                                } else if let disabledReason = layer["disabledReason"] as? String {
                                    let diagnostic = Self.disabledReasonDiagnostic(disabledReason, checkout: checkout, primaryRoot: primaryRoot)
                                    logger.error("Empty hook observation: exact checkout project layer is disabled (reason: \(diagnostic.message, privacy: .public))")
                                } else {
                                    logger.error("Empty hook observation: checkout project layer enablement is unsupported")
                                }
                                if let config = layer["config"] as? [String: Any] {
                                    if config["hooks"] is [String: Any] {
                                        logger.error("Empty hook observation: checkout project layer has inline hook declarations")
                                    } else if config["hooks"] == nil {
                                        logger.error("Empty hook observation: checkout project layer has no inline hook declarations")
                                    } else {
                                        logger.error("Empty hook observation: checkout inline hook declaration shape is unsupported")
                                    }
                                } else {
                                    logger.error("Empty hook observation: checkout project layer config shape is unsupported")
                                }
                            }
                        } else {
                            logger.error("Empty hook observation: checkout project layers are unavailable")
                        }
                    } catch {
                        logger.error("Empty hook observation unavailable: checkout config/read failed")
                    }
                }
                throw error
            }
            if owned.trustStatus != "trusted" {
                guard permitOwnedTrust else {
                    logger.error("Hook verification failed: owned hook trust is not ready")
                    throw ProjectExecutionError.hookNotReady
                }
                layer = try userLayer(await read(primaryRoot))
                try await writeUser(root: primaryRoot, layer: layer, key: "hooks.state." + quoted(owned.key), value: ["trusted_hash": owned.currentHash], beforeWrite: beforeWrite)
            }
            let readback = try await rpc("hooks/list", RPCObject(["cwds": [checkout]]), readback: true)
            do {
                _ = try ProjectExecutionHookReadiness.resolve(readback.data, checkout: checkout, primaryRoot: primaryRoot, command: command, requireTrusted: true, inline: inline)
            } catch let error as ProjectExecutionError {
                if error == .hookNotReady { logger.error("Hook verification failed: hooks/list readiness readback") }
                throw error
            }
            try await beforeWrite()
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

    func recoverConfigurationConnection() async throws {
        guard let cleanupFailure else { return }
        guard let current = transport else { throw cleanupFailure }
        do {
            try current.close() // Explicit owner retry on the retained original connection.
            transport = nil; self.cleanupFailure = nil
        } catch {
            let failure = AppServerTransportError(message: "Execution setup connection recovery remains incomplete: \(error.localizedDescription)", outcomeUnknown: true)
            self.cleanupFailure = failure; throw failure
        }
    }
}
