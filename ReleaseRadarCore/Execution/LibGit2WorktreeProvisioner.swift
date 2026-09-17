internal import CLibGit2
import Foundation

/// Local, in-process Git only, while the caller holds RR’s repository bookmark.
/// No subprocess, remote transport, helper privilege or hand-written Git metadata.
public struct LibGit2WorktreeProvisioner: ExecutionWorktreeProvisioning, Sendable {
    public init() {}
    private func check(_ result: Int32) throws {
        guard result >= 0 else {
            let message = git_error_last().flatMap { $0.pointee.message }.map { String(cString: $0) } ?? "Unknown local Git error"
            throw StoreError.unavailable("Project worktree setup failed: \(message). Preserve the existing checkout and resume setup in Release Radar.")
        }
    }
    private func repository(_ root: URL) throws -> OpaquePointer {
        guard root.resolvingSymlinksInPath().path == root.path else { throw ProjectExecutionError.identityMismatch }
        var repository: OpaquePointer?
        try check(git_repository_open_ext(&repository, root.path, UInt32(GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue), nil))
        guard let repository else { throw ProjectExecutionError.unavailable }
        return repository
    }
    private func name(projectID: String, taskID: String) throws -> String {
        try ProjectExecutionPaths.component(projectID); try ProjectExecutionPaths.component(taskID)
        return "rr-\(projectID)-\(taskID)"
    }
    private func clean(_ repository: OpaquePointer, includingIgnored: Bool = false) throws {
        var list: OpaquePointer?
        if includingIgnored {
            var options = git_status_options(); try check(git_status_options_init(&options, 1))
            options.flags |= UInt32(GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue | GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue)
            try check(git_status_list_new(&list, repository, &options))
        } else { try check(git_status_list_new(&list, repository, nil)) }
        defer { git_status_list_free(list) }
        guard git_status_list_entrycount(list) == 0 else { throw ProjectExecutionError.conflict }
    }

    public func revision(at root: URL, requireClean: Bool) throws -> String {
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        let repo = try repository(root); defer { git_repository_free(repo) }
        guard git_repository_is_bare(repo) == 0,
              git_repository_workdir(repo).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == root.path else { throw ProjectExecutionError.identityMismatch }
        if requireClean { try clean(repo) }
        var head: OpaquePointer?; try check(git_repository_head(&head, repo)); defer { git_reference_free(head) }
        guard let oid = git_reference_target(head), let value = git_oid_tostr_s(oid) else { throw ProjectExecutionError.unavailable }
        return String(cString: value)
    }

    public func candidateRevision(worktree: ExecutionWorktree) throws -> String {
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        let repo = try repository(URL(fileURLWithPath: worktree.checkout)); defer { git_repository_free(repo) }
        var head: OpaquePointer?; try check(git_repository_head(&head, repo)); defer { git_reference_free(head) }
        guard git_repository_is_worktree(repo) == 1,
              git_reference_name(head).map({ String(cString: $0) }) == "refs/heads/" + worktree.branch,
              git_repository_commondir(repo).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == worktree.commonGitDirectory,
              git_repository_workdir(repo).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == worktree.checkout else { throw ProjectExecutionError.identityMismatch }
        return try revision(at: URL(fileURLWithPath: worktree.checkout), requireClean: true)
    }

    public func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String, baseline: String) throws -> ExecutionWorktree {
        guard baseline.range(of: #"^[a-f0-9]{40}$"#, options: .regularExpression) != nil,
              checkout.resolvingSymlinksInPath().path == checkout.path else { throw ProjectExecutionError.invalidAssignment }
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        let repo = try repository(primaryRoot); defer { git_repository_free(repo) }
        guard git_repository_is_worktree(repo) == 0, git_repository_is_bare(repo) == 0 else { throw ProjectExecutionError.identityMismatch }
        let worktreeName = try name(projectID: projectID, taskID: taskID)
        let branchName = "codex/\(worktreeName)"
        guard let common = git_repository_commondir(repo), let primary = git_repository_workdir(repo) else { throw ProjectExecutionError.unavailable }
        let commonPath = URL(fileURLWithPath: String(cString: common)).standardizedFileURL.path
        let primaryPath = URL(fileURLWithPath: String(cString: primary)).standardizedFileURL.path
        guard primaryPath == primaryRoot.path else { throw ProjectExecutionError.identityMismatch }
        var existing: OpaquePointer?
        let lookup = git_worktree_lookup(&existing, repo, worktreeName)
        if lookup == 0, let existing {
            defer { git_worktree_free(existing) }
            try check(git_worktree_validate(existing))
            guard git_worktree_path(existing).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == checkout.path else { throw ProjectExecutionError.conflict }
            let linked = try repository(checkout); defer { git_repository_free(linked) }
            try clean(linked)
            var head: OpaquePointer?; try check(git_repository_head(&head, linked)); defer { git_reference_free(head) }
            guard git_reference_name(head).map({ String(cString: $0) }) == "refs/heads/\(branchName)",
                  git_reference_target(head).map({ String(cString: git_oid_tostr_s($0)) }) == baseline else { throw ProjectExecutionError.conflict }
            return .init(checkout: checkout.path, baseline: baseline, branch: branchName, commonGitDirectory: commonPath, primaryRoot: primaryPath)
        }
        guard lookup == GIT_ENOTFOUND.rawValue, !FileManager.default.fileExists(atPath: checkout.path) else { throw ProjectExecutionError.conflict }
        // Creation uses this exact committed object; unrelated dirty primary files are never copied or overwritten.
        var oid = git_oid(); try check(git_oid_fromstr(&oid, baseline))
        var commit: OpaquePointer?; try check(git_commit_lookup(&commit, repo, &oid)); defer { git_commit_free(commit) }
        var reference: OpaquePointer?
        let branchLookup = git_branch_lookup(&reference, repo, branchName, GIT_BRANCH_LOCAL)
        if branchLookup == GIT_ENOTFOUND.rawValue {
            try check(git_branch_create(&reference, repo, branchName, commit, 0))
        } else {
            try check(branchLookup)
            guard git_reference_target(reference).map({ String(cString: git_oid_tostr_s($0)) }) == baseline else { throw ProjectExecutionError.conflict }
        }
        defer { git_reference_free(reference) }
        try FileManager.default.createDirectory(at: checkout.deletingLastPathComponent(), withIntermediateDirectories: true)
        var options = git_worktree_add_options(); try check(git_worktree_add_options_init(&options, 1))
        options.ref = reference; options.lock = 1; options.checkout_existing = 1
        var tree: OpaquePointer?; try check(git_worktree_add(&tree, repo, worktreeName, checkout.path, &options)); defer { git_worktree_free(tree) }
        try check(git_worktree_validate(tree))
        return .init(checkout: checkout.path, baseline: baseline, branch: branchName, commonGitDirectory: commonPath, primaryRoot: primaryPath)
    }

    public func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String, taskID: String) throws {
        let worktreeName = try name(projectID: projectID, taskID: taskID)
        guard worktree.primaryRoot == primaryRoot.path, worktree.branch == "codex/" + worktreeName,
              URL(fileURLWithPath: worktree.checkout).resolvingSymlinksInPath().path == worktree.checkout else { throw ProjectExecutionError.identityMismatch }
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        let repo = try repository(primaryRoot); defer { git_repository_free(repo) }
        guard git_repository_is_worktree(repo) == 0, git_repository_is_bare(repo) == 0,
              git_repository_workdir(repo).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == worktree.primaryRoot,
              git_repository_commondir(repo).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == worktree.commonGitDirectory else { throw ProjectExecutionError.identityMismatch }
        var tree: OpaquePointer?; let lookup = git_worktree_lookup(&tree, repo, worktreeName)
        defer { git_worktree_free(tree) }
        if lookup == GIT_ENOTFOUND.rawValue, !FileManager.default.fileExists(atPath: worktree.checkout) { return }
        try check(lookup)
        guard git_worktree_path(tree).map({ URL(fileURLWithPath: String(cString: $0)).standardizedFileURL.path }) == worktree.checkout else { throw ProjectExecutionError.identityMismatch }
        _ = try candidateRevision(worktree: worktree) // Exact branch/common Git and clean, including untracked data.
        let linked = try repository(URL(fileURLWithPath: worktree.checkout)); defer { git_repository_free(linked) }
        try clean(linked, includingIgnored: true) // Ignored files can still contain owner data.
        var options = git_worktree_prune_options(); try check(git_worktree_prune_options_init(&options, 1))
        options.flags = UInt32(GIT_WORKTREE_PRUNE_VALID.rawValue | GIT_WORKTREE_PRUNE_WORKING_TREE.rawValue | GIT_WORKTREE_PRUNE_LOCKED.rawValue)
        guard git_worktree_is_prunable(tree, &options) == 1 else { throw ProjectExecutionError.conflict }
        try check(git_worktree_prune(tree, &options))
    }
}
