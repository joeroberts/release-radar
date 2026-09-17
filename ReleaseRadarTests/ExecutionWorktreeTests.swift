import CLibGit2
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ExecutionWorktreeTests: XCTestCase {
    private func check(_ result: Int32) throws {
        guard result >= 0 else {
            throw StoreError.unavailable(git_error_last().flatMap { $0.pointee.message }.map { String(cString: $0) } ?? "Native fixture failed")
        }
    }
    private func head(at root: URL) throws -> (revision: String, branch: String) {
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        var repository: OpaquePointer?; try check(git_repository_open(&repository, root.path)); defer { git_repository_free(repository) }
        var head: OpaquePointer?; try check(git_repository_head(&head, repository)); defer { git_reference_free(head) }
        return (String(cString: git_oid_tostr_s(git_reference_target(head))), String(cString: git_reference_shorthand(head)))
    }
    private func fixture() throws -> (root: URL, checkout: URL, baseline: String) {
        let parent = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let root = parent.appendingPathComponent("primary")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        var repository: OpaquePointer?; try check(git_repository_init(&repository, root.path, 0)); defer { git_repository_free(repository) }
        try Data("baseline".utf8).write(to: root.appendingPathComponent("source.txt"))
        var index: OpaquePointer?; try check(git_repository_index(&index, repository)); defer { git_index_free(index) }
        try check(git_index_add_bypath(index, "source.txt")); try check(git_index_write(index))
        var treeID = git_oid(); try check(git_index_write_tree(&treeID, index))
        var tree: OpaquePointer?; try check(git_tree_lookup(&tree, repository, &treeID)); defer { git_tree_free(tree) }
        var signature: UnsafeMutablePointer<git_signature>?
        try check(git_signature_new(&signature, "Fixture", "fixture@example.invalid", 1_700_000_000, 0)); defer { git_signature_free(signature) }
        var commitID = git_oid()
        try check(git_commit_create(&commitID, repository, "HEAD", signature, signature, nil, "Fixture baseline", tree, 0, nil))
        return (root, parent.appendingPathComponent("worktrees/task-one"), String(cString: git_oid_tostr_s(&commitID)))
    }
    func testNativeCreationUsesExactCommittedBaselineAndRefusesDirtyReuseOrRemoval() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        XCTAssertEqual(tree.baseline, fixture.baseline)
        XCTAssertEqual(try head(at: fixture.checkout).revision, fixture.baseline)
        XCTAssertEqual(try head(at: fixture.checkout).branch, "codex/rr-project-one-task-one")
        XCTAssertEqual(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline), tree)
        try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.checkout.path))
        try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline), tree)
        let wrongIdentity = ExecutionWorktree(checkout: tree.checkout, baseline: tree.baseline, branch: "codex/unowned",
            commonGitDirectory: tree.commonGitDirectory, primaryRoot: tree.primaryRoot)
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: wrongIdentity, projectID: "project-one", taskID: "task-one"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.checkout.path))
        try Data("owner edit".utf8).write(to: fixture.checkout.appendingPathComponent("source.txt"))
        XCTAssertThrowsError(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline))
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one"))
        XCTAssertEqual(try String(contentsOf: fixture.checkout.appendingPathComponent("source.txt"), encoding: .utf8), "owner edit")
    }
    func testDestinationCollisionInvalidRevisionAndMismatchedRemovalStayBounded() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        try FileManager.default.createDirectory(at: fixture.checkout, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: fixture.checkout.appendingPathComponent("owner.txt"))
        XCTAssertThrowsError(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline))
        XCTAssertThrowsError(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: "main~1"))
        XCTAssertEqual(try String(contentsOf: fixture.checkout.appendingPathComponent("owner.txt"), encoding: .utf8), "keep")
    }

    func testUntrackedDataAndWrongCommonGitIdentityCannotBePruned() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        let wrong = ExecutionWorktree(checkout: tree.checkout, baseline: tree.baseline, branch: tree.branch,
            commonGitDirectory: tree.commonGitDirectory + "-other", primaryRoot: tree.primaryRoot)
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: wrong, projectID: "project-one", taskID: "task-one"))
        try Data("untracked owner data".utf8).write(to: fixture.checkout.appendingPathComponent("owner.txt"))
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one"))
        XCTAssertEqual(try String(contentsOf: fixture.checkout.appendingPathComponent("owner.txt"), encoding: .utf8), "untracked owner data")
    }

    func testIgnoredOwnerContentBlocksPruningAndRemainsIntact() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent(".git/info"), withIntermediateDirectories: true)
        try Data(".env\nignored-data/\n".utf8).write(to: fixture.root.appendingPathComponent(".git/info/exclude"))
        let ignored = fixture.checkout.appendingPathComponent(".env")
        let contents = Data("fixture owner content, not credentials".utf8)
        try contents.write(to: ignored)
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one"))
        XCTAssertEqual(try Data(contentsOf: ignored), contents)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.checkout.path))
        XCTAssertEqual(try head(at: fixture.checkout).revision, fixture.baseline)
    }
}
