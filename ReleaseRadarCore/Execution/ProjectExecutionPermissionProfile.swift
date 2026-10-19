import CryptoKit
import Foundation

/// One capability-recognized shared-execution skill file in the selected Codex context.
/// The installed package snapshot is verified by the configuration owner before this
/// value is constructed; this value only preserves its exact finite read boundary.
public struct ProjectExecutionSharedExecutionSkill: Equatable, Sendable {
    public static let standardVersion = 1
    public let skillFile: String
    public let pluginVersion: String
    public let packageDigest: String

    public init(skillFile: String, pluginVersion: String, packageDigest: String) throws {
        let components = skillFile.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let suffix = ["plugins", "cache", CodexPluginPackage.pluginID, CodexPluginPackage.pluginID,
                      pluginVersion, "skills", "shared-execution", "SKILL.md"]
        guard skillFile.hasPrefix("/"), !skillFile.utf8.contains(0),
              skillFile.rangeOfCharacter(from: .controlCharacters) == nil,
              URL(fileURLWithPath: skillFile).standardizedFileURL.path == skillFile,
              components.count > suffix.count, Array(components.suffix(suffix.count)) == suffix,
              CodexPluginPackage.isStrictSemVer(pluginVersion),
              packageDigest.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil,
              let capability = RecognizedPluginCapability.recognize(
                manifestVersion: pluginVersion,
                normalizedPackageDigest: packageDigest
              ), capability.sharedExecutionStandardVersions.contains(Self.standardVersion) else {
            throw ProjectExecutionError.unavailable
        }
        self.skillFile = skillFile
        self.pluginVersion = pluginVersion
        self.packageDigest = packageDigest
    }

    /// Resolves one exact installed package below the selected CODEX_HOME. The
    /// caller retains and revalidates the security-scoped context lease around
    /// this stable, no-follow snapshot.
    public static func verifyingInstalledPackage(in context: CodexExecutionContext,
                                                 expected: CodexPluginPackage) throws -> Self {
        try context.validateFolder()
        let packageFiles = Set(expected.relativeFiles)
        guard packageFiles == Set(CodexPluginPackage.relativeFiles) else {
            throw ProjectExecutionError.unavailable
        }
        let packageComponents = ["plugins", "cache", CodexPluginPackage.pluginID,
                                 CodexPluginPackage.pluginID, expected.version]
        let packageRoot = packageComponents.reduce(
            URL(fileURLWithPath: context.homePath, isDirectory: true)
        ) { $0.appendingPathComponent($1, isDirectory: true) }
        let files: [String: Data]
        do {
            let reader = try RepositoryDocumentReader(rootURL: packageRoot,
                limits: .init(maximumCatalogBytes: 1_048_576, maximumFileBytes: 1_048_576,
                              maximumArtifactCount: packageFiles.count,
                              maximumCollectionCount: 8, maximumTotalBytes: 4 * 1_048_576),
                afterRead: nil)
            files = try reader.readExactFiles(packageFiles)
        } catch {
            do { try context.validateFolder() }
            catch { throw CodexExecutionContextError.changed }
            throw ProjectExecutionError.unavailable
        }
        var hasher = SHA256()
        for relative in expected.relativeFiles.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            guard let data = files[relative] else { throw ProjectExecutionError.unavailable }
            hasher.update(data: Data(relative.utf8))
            hasher.update(data: Data([0]))
            var length = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
            hasher.update(data: data)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == expected.digest else { throw ProjectExecutionError.unavailable }
        try context.validateFolder()
        let skillFile = packageRoot.appendingPathComponent("skills/shared-execution/SKILL.md").path
        return try Self(skillFile: skillFile, pluginVersion: expected.version, packageDigest: digest)
    }
}

/// App-generated finite filesystem ceiling. No user-home, project sibling,
/// SQLite or authority-write access is admitted by an assignment.
public struct ProjectExecutionPermissionProfile: Equatable, Sendable {
    public let id: String
    public let workspace: [String: String]
    public let absolute: [String: String]

    public init(assignment: ProjectExecutionAssignment, policy: ProjectExecutionPolicy,
                paths: ProjectExecutionPaths) throws {
        try self.init(assignment: assignment, policy: policy, paths: paths, sharedExecutionSkill: nil)
    }

    public init(assignment: ProjectExecutionAssignment, policy: ProjectExecutionPolicy,
                paths: ProjectExecutionPaths,
                sharedExecutionSkill: ProjectExecutionSharedExecutionSkill) throws {
        try self.init(assignment: assignment, policy: policy, paths: paths,
                      sharedExecutionSkill: Optional(sharedExecutionSkill))
    }

    private init(assignment: ProjectExecutionAssignment, policy: ProjectExecutionPolicy,
                 paths: ProjectExecutionPaths,
                 sharedExecutionSkill: ProjectExecutionSharedExecutionSkill?) throws {
        try assignment.validated()
        guard let tree = assignment.worktree, tree.primaryRoot == policy.primaryRoot,
              assignment.checkoutPath == paths.checkout.path,
              policy.handlerPath.hasSuffix("/Contents/Helpers/ReleaseRadarCoordinator") else { throw ProjectExecutionError.identityMismatch }
        id = assignment.permissionProfile
        var workspace = [".": assignment.role == .review ? "read" : "write", ".codex": "deny"]
        if assignment.role == .review,
           assignment.reviewScratchVersion == ProjectExecutionAssignment.xcodeBuildScratchVersion {
            // Reviews retain a read-only candidate while Xcode writes only its
            // task-local caches, temporary files, result bundles and products.
            workspace[".build"] = "write"
        }
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
        if let sharedExecutionSkill {
            guard absolute[sharedExecutionSkill.skillFile] == nil else {
                throw ProjectExecutionError.invalidAssignment
            }
            absolute[sharedExecutionSkill.skillFile] = "read"
        }
        self.workspace = workspace; self.absolute = absolute
    }

    public var filesystemObject: [String: Any] {
        var result: [String: Any] = [":root": "deny", ":minimal": "read", ":workspace_roots": workspace]
        for (path, access) in absolute { result[path] = access }
        return result
    }

    public var definition: Data {
        get throws {
            try JSONSerialization.data(withJSONObject: ["filesystem": filesystemObject, "network": ["enabled": false]], options: [.sortedKeys])
        }
    }

    public static func removingOwnedProfile(id: String, expected: Data, from profiles: [String: Any]) throws -> [String: Any] {
        try ProjectExecutionPaths.component(id)
        guard let desired = try JSONSerialization.jsonObject(with: expected) as? [String: Any] else { throw ProjectExecutionError.invalidAssignment }
        var remaining = profiles
        if let existing = remaining[id] {
            guard let object = existing as? [String: Any], NSDictionary(dictionary: object).isEqual(to: desired) else { throw ProjectExecutionError.conflict }
            remaining.removeValue(forKey: id)
        }
        return remaining
    }
}
