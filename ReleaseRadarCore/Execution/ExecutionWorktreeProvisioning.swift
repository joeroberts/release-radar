import Foundation

public struct ExecutionWorktree: Codable, Equatable, Sendable {
    public let checkout: String
    public let baseline: String
    public let branch: String
    public let commonGitDirectory: String
    public let primaryRoot: String
    public init(checkout: String, baseline: String, branch: String, commonGitDirectory: String, primaryRoot: String) {
        self.checkout = checkout; self.baseline = baseline; self.branch = branch
        self.commonGitDirectory = commonGitDirectory; self.primaryRoot = primaryRoot
    }
}

public protocol ExecutionWorktreeProvisioning: Sendable {
    func revision(at root: URL, requireClean: Bool) throws -> String
    func candidateRevision(worktree: ExecutionWorktree) throws -> String
    func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String, baseline: String) throws -> ExecutionWorktree
    func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String, taskID: String) throws
    func hasPreparedResources(primaryRoot: URL, checkout: URL, projectID: String, taskID: String) throws -> Bool
}

public extension ExecutionWorktreeProvisioning {
    func hasPreparedResources(primaryRoot: URL, checkout: URL, projectID: String, taskID: String) throws -> Bool {
        throw ProjectExecutionError.unavailable
    }
}
