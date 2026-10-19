import CryptoKit
import Foundation
import ReleaseRadarCore

struct WorkerPolicy {
    let store: ProjectExecutionFileStore
    let assignment: ProjectExecutionAssignment
    let policy: ProjectExecutionPolicy
    let snapshot: URL
    let codexContext: CodexExecutionContext

    init(store: ProjectExecutionFileStore, projectID: String, taskID: String) throws {
        self.store = store
        policy = try store.policy(projectID: projectID)
        assignment = try store.assignment(projectID: projectID, taskID: taskID)
        guard let context = try store.codexContext() else { throw CodexExecutionContextError.changed }
        codexContext = context
        guard policy.version == 1, policy.enabled, policy.bindingRecoveryPending != true, policy.consent == ProjectExecutionPolicy.Consent(),
              policy.hookReceipt?.installed == true, policy.appServerExecutable == CodexExecutionIdentity.executable,
              policy.registration == assignment.registration,
              assignment.state == .authorized, assignment.uncertainOutcome != true,
              assignment.connectionClosed != true else { throw ProjectExecutionError.assignmentNotAuthorized }
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: projectID, taskID: taskID)
        guard assignment.checkoutPath == paths.checkout.path,
              paths.checkout.resolvingSymlinksInPath().path == paths.checkout.path else { throw ProjectExecutionError.identityMismatch }
        snapshot = paths.assignment
        try verifyCodexContext()
        try verifyContext()
    }

    func verifyCodexContext() throws {
        guard let id = policy.codexContextID, assignment.codexContextID == id,
              codexContext.id == id, try store.codexContext() == codexContext else { throw CodexExecutionContextError.changed }
    }

    func verifyContext() throws {
        try assignment.verifyContext()
    }

    func current(sessionID: String, attemptID: UUID? = nil) throws -> ProjectExecutionAssignment {
        try verifyCodexContext()
        let currentPolicy = try store.policy(projectID: assignment.registration.projectID.rawValue)
        let current = try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        guard currentPolicy == policy else { throw ProjectExecutionError.assignmentNotAuthorized }
        var original = assignment; original.sessionID = sessionID; original.launchReserved = true
        if let attemptID { original.workerAttemptID = attemptID }
        guard current == original else { throw ProjectExecutionError.assignmentNotAuthorized }
        try current.admit(registration: policy.registration, checkoutPath: assignment.checkoutPath, sessionID: sessionID, boundSessionID: current.sessionID)
        try verifyContext()
        return current
    }

    func reserve(attemptID: UUID? = nil) throws {
        try verifyCodexContext()
        guard try store.policy(projectID: assignment.registration.projectID.rawValue) == policy else { throw ProjectExecutionError.assignmentNotAuthorized }
        var intent = assignment; intent.state = .unknown; intent.launchReserved = true; intent.uncertainOutcome = true
        intent.workerAttemptID = attemptID
        try store.saveAssignment(intent, expected: assignment)
    }

    func bind(sessionID: String, attemptID: UUID? = nil) throws {
        try verifyCodexContext()
        guard assignment.sessionID == nil else { throw ProjectExecutionError.conflict }
        guard try store.policy(projectID: assignment.registration.projectID.rawValue) == policy else { throw ProjectExecutionError.assignmentNotAuthorized }
        var bound = assignment; bound.sessionID = sessionID; bound.launchReserved = true; bound.workerAttemptID = attemptID
        var intent = assignment; intent.state = .unknown; intent.launchReserved = true; intent.uncertainOutcome = true
        intent.workerAttemptID = attemptID
        try store.saveAssignment(bound, expected: intent)
    }

    func mark(_ state: ProjectExecutionAssignment.State, sessionID: String?, attemptID: UUID,
              from allowed: [ProjectExecutionAssignment.State], connectionClosed: Bool = false) throws {
        let current = try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        guard current.registration == assignment.registration,
              current.workerAttemptID == attemptID,
              current.sessionID == sessionID || (connectionClosed && current.sessionID == nil && current.launchReserved == true && current.state != .authorized) else { throw ProjectExecutionError.identityMismatch }
        guard allowed.contains(current.state) else { return } // Preserve owner revocation/STOP.
        var changed = current; changed.state = state
        if current.state == .unknown { changed.state = .unknown }
        if state == .unknown { changed.uncertainOutcome = true }
        if connectionClosed {
            // Physical connection cleanup is independent of authorization. A
            // stopped/revoked assignment never becomes a delivered candidate.
            if [.stopped, .revoked, .superseded].contains(current.state) { changed.state = current.state }
            changed.connectionClosed = true
            if current.sessionID == nil { changed.sessionID = sessionID }
        }
        try store.saveAssignment(changed, expected: current)
    }

    func validate(config: [String: Any]) throws {
        guard config["model_provider"] == nil || config["model_provider"] is NSNull || config["model_provider"] as? String == "openai",
              Self.defaultEndpoint(config["openai_base_url"], expected: "https://api.openai.com/v1"),
              Self.defaultEndpoint(config["chatgpt_base_url"], expected: "https://chatgpt.com/backend-api/") else {
            throw CodexExecutionContextError.routingUnsupported
        }
        guard let profiles = config["permissions"] as? [String: Any],
              let profile = profiles[assignment.permissionProfile] as? [String: Any],
              Set(profile.keys).isSubset(of: ["description", "extends", "workspace_roots", "filesystem", "network"]),
              profile["description"] == nil || profile["description"] is NSNull || profile["description"] is String,
              Self.emptyMetadata(profile["extends"]), Self.emptyMetadata(profile["workspace_roots"]),
              let network = profile["network"] as? [String: Any], Self.disabledNetwork(network),
              let fs = profile["filesystem"] as? [String: Any] else { throw ProjectExecutionError.invalidAssignment }
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        let legacy = try ProjectExecutionPermissionProfile(assignment: assignment, policy: policy, paths: paths)
        let expectedFilesystem: [String: Any]
        if let definition = assignment.permissionProfileDefinition {
            guard let recorded = try JSONSerialization.jsonObject(with: definition) as? [String: Any],
                  Set(recorded.keys) == ["filesystem", "network"],
                  let recordedFilesystem = recorded["filesystem"] as? [String: Any],
                  let recordedNetwork = recorded["network"] as? [String: Any],
                  Set(recordedNetwork.keys) == ["enabled"], recordedNetwork["enabled"] as? Bool == false else {
                throw ProjectExecutionError.invalidAssignment
            }
            try Self.validateRecordedFilesystem(recordedFilesystem, legacy: legacy.filesystemObject,
                codexHome: codexContext.homePath)
            expectedFilesystem = recordedFilesystem
        } else {
            expectedFilesystem = legacy.filesystemObject
        }
        // config/read serializes the unset optional scan depth as null, separate from grants.
        guard fs["glob_scan_max_depth"] == nil || fs["glob_scan_max_depth"] is NSNull else { throw ProjectExecutionError.invalidAssignment }
        var entries = fs; entries.removeValue(forKey: "glob_scan_max_depth")
        guard NSDictionary(dictionary: entries).isEqual(to: expectedFilesystem) else { throw ProjectExecutionError.invalidAssignment }
    }

    private static func validateRecordedFilesystem(_ recorded: [String: Any], legacy: [String: Any],
                                                   codexHome: String) throws {
        var additions = recorded
        for (key, expected) in legacy {
            guard let actual = additions.removeValue(forKey: key), valuesEqual(actual, expected) else {
                throw ProjectExecutionError.invalidAssignment
            }
        }
        if additions.isEmpty { return }
        guard additions.count == 1, let (skillFile, access) = additions.first,
              access as? String == "read" else { throw ProjectExecutionError.invalidAssignment }
        let prefix = codexHome + "/"
        guard skillFile.hasPrefix(prefix) else { throw ProjectExecutionError.invalidAssignment }
        let relative = String(skillFile.dropFirst(prefix.count))
        let components = relative.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 8,
              components[0...3].elementsEqual(["plugins", "cache", CodexPluginPackage.pluginID,
                                                CodexPluginPackage.pluginID]),
              components[5...7].elementsEqual(["skills", "shared-execution", "SKILL.md"]),
              CodexPluginPackage.isStrictSemVer(components[4]),
              RecognizedPluginCapability.known.contains(where: {
                $0.manifestVersion == components[4]
                    && $0.sharedExecutionStandardVersions.contains(ProjectExecutionSharedExecutionSkill.standardVersion)
              }) else { throw ProjectExecutionError.invalidAssignment }
    }

    private static func valuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        NSDictionary(dictionary: ["value": lhs]).isEqual(to: ["value": rhs])
    }

    private static func disabledNetwork(_ network: [String: Any]) -> Bool {
        let optionalFields: Set<String> = ["proxy_url", "enable_socks5", "socks_url", "enable_socks5_udp",
            "allow_upstream_proxy", "dangerously_allow_non_loopback_proxy", "dangerously_allow_all_unix_sockets",
            "mode", "domains", "unix_sockets", "allow_local_binding", "mitm"]
        // Only documented, unset overlays are metadata; every configured value fails closed.
        return network["enabled"] as? Bool == false && network.allSatisfy {
            $0.key == "enabled" || (optionalFields.contains($0.key) && $0.value is NSNull)
        }
    }

    private static func emptyMetadata(_ value: Any?) -> Bool {
        value == nil || value is NSNull || (value as? [String])?.isEmpty == true
    }

    private static func defaultEndpoint(_ value: Any?, expected: String) -> Bool {
        value == nil || value is NSNull || value as? String == expected
    }

    func overrides(config: [String: Any]) throws -> [String: Any] {
        var result: [String: Any] = [
            "features.apps": false, "features.plugins": false, "features.browser_use": false,
            "features.browser_use_external": false, "features.browser_use_full_cdp_access": false,
            "features.computer_use": false, "features.in_app_browser": false,
            "features.multi_agent": false, "features.multi_agent_v2": false, "agents.enabled": false,
            "features.memories": false, "memories.use_memories": false, "features.remote_plugin": false,
            "features.skill_mcp_dependency_install": false, "features.image_generation": false,
            "features.view_image": assignment.role == .review, "tools.view_image": assignment.role == .review, "web_search": "disabled",
            "permissions.\(assignment.permissionProfile).network.enabled": false,
            "model_reasoning_effort": assignment.effort,
        ]
        for section in ["mcp_servers", "plugins"] {
            guard config[section] == nil || config[section] is [String: Any] else { throw ProjectExecutionError.invalidAssignment }
            for key in (config[section] as? [String: Any] ?? [:]).keys {
                guard !key.contains("."), !key.contains("\"") else { throw ProjectExecutionError.invalidAssignment }
                result["\(section).\(key).enabled"] = false
            }
        }
        return result
    }
}
