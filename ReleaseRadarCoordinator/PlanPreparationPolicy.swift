import CryptoKit
import Foundation
import ReleaseRadarCore

/// Pure admission and runtime-contract policy for the app-led, non-operative
/// repository-plan preparation purpose. Launch, collection and persistence are
/// intentionally owned by the adapter that consumes this policy.
struct PlanPreparationPolicy: Sendable {
    static let permissionProfileID = "rr-plan-preparation"

    let request: RepositoryPlanPreparationRequest

    init(request: RepositoryPlanPreparationRequest) throws {
        self.request = request
        try validateRequest()
    }

    func processOverrides(config: [String: Any]) throws -> [String: Any] {
        var result: [String: Any] = [
            "features.apps": false,
            "features.plugins": false,
            "features.browser_use": false,
            "features.browser_use_external": false,
            "features.browser_use_full_cdp_access": false,
            "features.computer_use": false,
            "features.in_app_browser": false,
            "features.multi_agent": false,
            "features.multi_agent_v2": false,
            "agents.enabled": false,
            "features.memories": false,
            "memories.use_memories": false,
            "features.remote_plugin": false,
            "features.skill_mcp_dependency_install": false,
            "features.image_generation": false,
            "features.view_image": false,
            "tools.view_image": false,
            "web_search": "disabled",
            "approval_policy": "never",
            "permissions.\(Self.permissionProfileID).filesystem": Self.filesystem,
            "permissions.\(Self.permissionProfileID).network.enabled": false,
            "model_reasoning_effort": request.effort,
        ]
        for section in ["mcp_servers", "plugins"] {
            guard config[section] == nil || config[section] is [String: Any] else {
                throw failure(.unsupportedRuntime)
            }
            for key in (config[section] as? [String: Any] ?? [:]).keys {
                guard !key.contains("."), !key.contains("\"") else {
                    throw failure(.unsupportedRuntime)
                }
                result["\(section).\(key).enabled"] = false
            }
        }
        return result
    }

    func validateConfiguration(_ config: [String: Any]) throws {
        guard config["model_provider"] == nil || config["model_provider"] is NSNull
                || config["model_provider"] as? String == "openai",
              Self.defaultEndpoint(config["openai_base_url"], expected: "https://api.openai.com/v1"),
              Self.defaultEndpoint(config["chatgpt_base_url"], expected: "https://chatgpt.com/backend-api/"),
              let profiles = config["permissions"] as? [String: Any],
              let profile = profiles[Self.permissionProfileID] as? [String: Any],
              Set(profile.keys).isSubset(of: ["description", "extends", "workspace_roots", "filesystem", "network"]),
              profile["description"] == nil || profile["description"] is NSNull,
              Self.emptyMetadata(profile["extends"]),
              Self.emptyMetadata(profile["workspace_roots"]),
              let filesystem = profile["filesystem"] as? [String: Any],
              filesystem["glob_scan_max_depth"] == nil || filesystem["glob_scan_max_depth"] is NSNull,
              let network = profile["network"] as? [String: Any], Self.disabledNetwork(network)
        else { throw failure(.unsupportedRuntime) }
        var grants = filesystem
        grants.removeValue(forKey: "glob_scan_max_depth")
        guard NSDictionary(dictionary: grants).isEqual(to: Self.filesystem) else {
            throw failure(.unsupportedRuntime)
        }
        _ = try processOverrides(config: config)
    }

    func threadStartParameters(config: [String: Any]) throws -> [String: Any] {
        try validateConfiguration(config)
        return [
            "cwd": request.snapshot.workingPath,
            "runtimeWorkspaceRoots": [request.snapshot.rootPath],
            "permissions": Self.permissionProfileID,
            "model": request.model,
            "allowProviderModelFallback": false,
            "config": try processOverrides(config: config),
        ]
    }

    func validateThreadStart(
        _ result: [String: Any],
        allowedInstructionSources: [String]
    ) throws {
        guard Self.exact(result["cwd"] as? String, request.snapshot.workingPath),
              let roots = result["runtimeWorkspaceRoots"] as? [String], roots.count == 1,
              Self.exact(roots[0], request.snapshot.rootPath),
              Self.exact(result["model"] as? String, request.model),
              Self.exact(result["reasoningEffort"] as? String, request.effort),
              (result["thread"] as? [String: Any])?["modelProvider"] as? String == "openai",
              (result["activePermissionProfile"] as? [String: Any])?["id"] as? String == Self.permissionProfileID,
              (result["sandbox"] as? [String: Any])?["networkAccess"] as? Bool == false,
              result["approvalPolicy"] as? String == "never",
              result["approvalsReviewer"] == nil || result["approvalsReviewer"] is NSNull,
              let sources = result["instructionSources"] as? [String]
        else { throw failure(.unsupportedRuntime) }

        let permitted = Set(allowedInstructionSources.map { Data($0.utf8) })
        guard Set(sources.map { Data($0.utf8) }).count == sources.count,
              sources.allSatisfy({ source in
                  permitted.contains(Data(source.utf8))
                      && !Self.contains(request.snapshot.rootPath, source)
                      && !Self.contains(request.sourceManifest.rootPath, source)
              })
        else { throw failure(.unsupportedRuntime) }
    }

    private func validateRequest() throws {
        let identity = request.identity
        let manifest = request.sourceManifest
        guard Self.sameRegistration(identity.registration, manifest.registration),
              Self.exact(identity.registration.projectID.rawValue, manifest.projectID.rawValue),
              Self.exact(identity.rootID, manifest.rootID),
              identity.registration.requestGeneration > 0,
              Self.validIdentity(identity.registration.projectID.rawValue),
              Self.validIdentity(identity.registration.registrationID),
              Self.validIdentity(identity.rootID),
              Self.validIdentity(identity.proposalID.rawValue),
              Self.validIdentity(manifest.repositoryID),
              manifest.acceptedCatalogVersion > 0,
              Self.validDigest(manifest.acceptedCatalogDigest),
              !manifest.sources.isEmpty,
              request.projectionRevision > 0,
              Self.validModel(request.model),
              ["low", "medium", "high", "xhigh", "max"].contains(request.effort)
        else { throw failure(.invalidRequest) }

        var artifactIDs = Set<Data>()
        var paths = Set<Data>()
        for source in manifest.sources {
            guard Self.validIdentity(source.artifactID), Self.validRelativePath(source.path),
                  artifactIDs.insert(Data(source.artifactID.utf8)).inserted,
                  paths.insert(Data(source.path.utf8)).inserted,
                  Self.digest(source.bytes) == source.contentSHA256
            else { throw failure(.identityMismatch) }
        }

        let sourceRoot = try Self.canonicalDirectory(manifest.rootPath)
        let snapshotRoot = try Self.canonicalDirectory(request.snapshot.rootPath)
        let working = try Self.canonicalDirectory(request.snapshot.workingPath)
        guard sourceRoot == manifest.rootPath,
              snapshotRoot == request.snapshot.rootPath,
              working == request.snapshot.workingPath,
              working == snapshotRoot + "/session",
              !Self.contains(sourceRoot, snapshotRoot),
              !Self.contains(snapshotRoot, sourceRoot),
              Self.validDigest(request.snapshot.manifestSHA256),
              try request.snapshot.manifestSHA256 == Self.manifestDigest(manifest)
        else { throw failure(.identityMismatch) }
    }

    private static var filesystem: [String: Any] {
        [
            ":root": "deny",
            ":minimal": "read",
            ":workspace_roots": [".": "read"],
        ]
    }

    private static func sameRegistration(_ lhs: ProjectRegistration, _ rhs: ProjectRegistration) -> Bool {
        exact(lhs.projectID.rawValue, rhs.projectID.rawValue)
            && exact(lhs.registrationID, rhs.registrationID)
            && lhs.requestGeneration == rhs.requestGeneration
    }

    private static func exact(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        return Data(lhs.utf8) == Data(rhs.utf8)
    }

    private static func validIdentity(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    private static func validModel(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    private static func validDigest(_ value: String) -> Bool {
        value.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil
    }

    private static func validRelativePath(_ value: String) -> Bool {
        !value.hasPrefix("/") && value.utf8.count <= 1_024
            && !value.split(separator: "/", omittingEmptySubsequences: false)
                .contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    private static func canonicalDirectory(_ path: String) throws -> String {
        guard path.hasPrefix("/"), path.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw failure(.identityMismatch)
        }
        let url = URL(fileURLWithPath: path)
        guard url.standardizedFileURL.path == path,
              url.resolvingSymlinksInPath().path == path,
              (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
        else { throw failure(.identityMismatch) }
        return path
    }

    private static func contains(_ parent: String, _ child: String) -> Bool {
        parent == "/" ? child.hasPrefix("/") : child == parent || child.hasPrefix(parent + "/")
    }

    private static func disabledNetwork(_ network: [String: Any]) -> Bool {
        let optionalFields: Set<String> = [
            "proxy_url", "enable_socks5", "socks_url", "enable_socks5_udp",
            "allow_upstream_proxy", "dangerously_allow_non_loopback_proxy",
            "dangerously_allow_all_unix_sockets", "mode", "domains", "unix_sockets",
            "allow_local_binding", "mitm",
        ]
        return network["enabled"] as? Bool == false && network.allSatisfy {
            $0.key == "enabled" || optionalFields.contains($0.key) && $0.value is NSNull
        }
    }

    private static func emptyMetadata(_ value: Any?) -> Bool {
        value == nil || value is NSNull || (value as? [String])?.isEmpty == true
    }

    private static func defaultEndpoint(_ value: Any?, expected: String) -> Bool {
        value == nil || value is NSNull || value as? String == expected
    }

    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func manifestDigest(_ manifest: RepositoryPlanSourceManifest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return digest(try encoder.encode(manifest))
    }

    private static func failure(_ code: RepositoryPlanPreparationError.Code) -> RepositoryPlanPreparationError {
        .init(code: code)
    }

    private func failure(_ code: RepositoryPlanPreparationError.Code) -> RepositoryPlanPreparationError {
        Self.failure(code)
    }
}
