import CryptoKit
import Foundation
import ReleaseRadarCore

struct WorkerPolicy {
    let store: ProjectExecutionFileStore
    let assignment: ProjectExecutionAssignment
    let policy: ProjectExecutionPolicy
    let snapshot: URL

    init(store: ProjectExecutionFileStore, projectID: String, taskID: String) throws {
        self.store = store
        policy = try store.policy(projectID: projectID)
        assignment = try store.assignment(projectID: projectID, taskID: taskID)
        guard policy.version == 1, policy.enabled, policy.consent == ProjectExecutionPolicy.Consent(),
              policy.hookReceipt?.installed == true, policy.appServerExecutable == CodexExecutionIdentity.executable,
              policy.registration == assignment.registration,
              assignment.state == .authorized else { throw ProjectExecutionError.assignmentNotAuthorized }
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: projectID, taskID: taskID)
        guard assignment.checkoutPath == paths.checkout.path,
              paths.checkout.resolvingSymlinksInPath().path == paths.checkout.path else { throw ProjectExecutionError.identityMismatch }
        snapshot = paths.assignment
        try verifyContext()
    }

    func verifyContext() throws {
        try assignment.verifyContext()
    }

    func current(sessionID: String) throws -> ProjectExecutionAssignment {
        let currentPolicy = try store.policy(projectID: assignment.registration.projectID.rawValue)
        let current = try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        guard currentPolicy == policy else { throw ProjectExecutionError.assignmentNotAuthorized }
        var original = assignment; original.sessionID = sessionID
        guard current == original else { throw ProjectExecutionError.assignmentNotAuthorized }
        try current.admit(registration: policy.registration, checkoutPath: assignment.checkoutPath, sessionID: sessionID, boundSessionID: current.sessionID)
        try verifyContext()
        return current
    }

    func reserve() throws {
        var intent = assignment; intent.state = .unknown
        try store.saveAssignment(intent, expected: assignment)
    }

    func bind(sessionID: String) throws {
        guard assignment.sessionID == nil else { throw ProjectExecutionError.conflict }
        var bound = assignment; bound.sessionID = sessionID
        var intent = assignment; intent.state = .unknown
        try store.saveAssignment(bound, expected: intent)
    }

    func mark(_ state: ProjectExecutionAssignment.State, sessionID: String?, from allowed: [ProjectExecutionAssignment.State]) throws {
        let current = try store.assignment(projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        guard current.registration == assignment.registration, current.sessionID == sessionID else { throw ProjectExecutionError.identityMismatch }
        guard allowed.contains(current.state) else { return } // Preserve owner revocation/STOP.
        var changed = current; changed.state = state
        try store.saveAssignment(changed, expected: current)
    }

    func validate(config: [String: Any]) throws {
        guard let profiles = config["permissions"] as? [String: Any],
              let profile = profiles[assignment.permissionProfile] as? [String: Any],
              Set(profile.keys) == ["filesystem", "network"],
              let network = profile["network"] as? [String: Any], Set(network.keys) == ["enabled"], network["enabled"] as? Bool == false,
              let fs = profile["filesystem"] as? [String: Any] else { throw ProjectExecutionError.invalidAssignment }
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: assignment.registration.projectID.rawValue, taskID: assignment.id)
        let expected = try ProjectExecutionPermissionProfile(assignment: assignment, policy: policy, paths: paths)
        guard NSDictionary(dictionary: fs).isEqual(to: expected.filesystemObject) else { throw ProjectExecutionError.invalidAssignment }
    }

    func overrides(config: [String: Any]) throws -> [String: Any] {
        var result: [String: Any] = [
            "features.apps": false, "features.plugins": false, "features.browser_use": false,
            "features.browser_use_external": false, "features.browser_use_full_cdp_access": false,
            "features.computer_use": false, "features.in_app_browser": false,
            "features.multi_agent": false, "features.multi_agent_v2": false, "agents.enabled": false,
            "features.memories": false, "memories.use_memories": false, "features.remote_plugin": false,
            "features.skill_mcp_dependency_install": false, "features.image_generation": false,
            "features.view_image": false, "tools.view_image": false, "web_search": "disabled",
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
