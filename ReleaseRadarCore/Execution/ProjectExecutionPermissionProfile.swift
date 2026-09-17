import Foundation

/// App-generated finite filesystem ceiling. No user-home, project sibling,
/// SQLite or authority-write access is admitted by an assignment.
public struct ProjectExecutionPermissionProfile: Equatable, Sendable {
    public let id: String
    public let workspace: [String: String]
    public let absolute: [String: String]

    public init(assignment: ProjectExecutionAssignment, policy: ProjectExecutionPolicy, paths: ProjectExecutionPaths) throws {
        try assignment.validated()
        guard let tree = assignment.worktree, tree.primaryRoot == policy.primaryRoot,
              assignment.checkoutPath == paths.checkout.path,
              policy.handlerPath.hasSuffix("/Contents/Helpers/ReleaseRadarCoordinator") else { throw ProjectExecutionError.identityMismatch }
        id = assignment.permissionProfile
        var workspace = [".": assignment.role == .review ? "read" : "write", ".codex": "deny"]
        var absolute = [paths.assignment.path: "read", paths.projectPolicy.path: "read",
            tree.primaryRoot: "deny", tree.commonGitDirectory: "deny",
            "/Applications/Xcode.app": "read", "/Library/Developer": "read", "/System/Library": "read", "/opt/homebrew": "read"]
        // The trusted hook executable must remain readable; the separate management
        // client cannot be executed by an ordinary worker. Hook mode has only reads.
        let contents = URL(fileURLWithPath: policy.handlerPath).deletingLastPathComponent().deletingLastPathComponent()
        absolute[policy.handlerPath] = "read"
        absolute[contents.appendingPathComponent("Frameworks").path] = "read"
        absolute[contents.appendingPathComponent("Helpers/ReleaseRadarAgentTools").path] = "deny"
        absolute["/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools"] = "deny"
        for exclusion in assignment.excludedPaths {
            if exclusion.hasPrefix("/") { absolute[exclusion] = "deny" }
            else { workspace[exclusion] = "deny" }
        }
        self.workspace = workspace; self.absolute = absolute
    }

    public var filesystemObject: [String: Any] {
        var result: [String: Any] = [":root": "deny", ":minimal": "read", ":workspace_roots": workspace]
        for (path, access) in absolute { result[path] = access }
        return result
    }
}
