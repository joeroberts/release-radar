import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionProfileTests: XCTestCase {
    func testOwnedProfileRemovalPreservesUnrelatedProfilesAndOwnerRemovalButRefusesEdits() throws {
        let owned: [String: Any] = ["filesystem": [":root": "deny"], "network": ["enabled": false]]
        let expected = try JSONSerialization.data(withJSONObject: owned, options: [.sortedKeys])
        let other: [String: Any] = ["filesystem": ["/Owner": "read"], "network": ["enabled": true]]
        let remaining = try ProjectExecutionPermissionProfile.removingOwnedProfile(id: "rr-owned", expected: expected,
            from: ["rr-owned": owned, "owner-profile": other])
        XCTAssertNil(remaining["rr-owned"])
        XCTAssertTrue(NSDictionary(dictionary: remaining).isEqual(to: ["owner-profile": other]))
        XCTAssertTrue(NSDictionary(dictionary: try ProjectExecutionPermissionProfile.removingOwnedProfile(id: "rr-owned", expected: expected,
            from: remaining)).isEqual(to: remaining))
        XCTAssertThrowsError(try ProjectExecutionPermissionProfile.removingOwnedProfile(id: "rr-owned", expected: expected,
            from: ["rr-owned": other, "owner-profile": other]))
    }

    func testDeliveryAndReviewProfilesGrantOnlyExactAuthorityReadsAndOwnedCheckout() throws {
        let root = URL(fileURLWithPath: "/Execution")
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: "task-one")
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Primary", appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator")
        let tree = ExecutionWorktree(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40), branch: "codex/rr-project-one-task-one", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary")
        for role in [ProjectExecutionAssignment.Role.delivery, .review] {
            let assignment = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: role,
                permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: role == .delivery ? "medium" : "high", authorization: "Existing authorized work",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], worktree: tree)
            let profile = try ProjectExecutionPermissionProfile(assignment: assignment, policy: policy, paths: paths)
            XCTAssertEqual(profile.workspace["."], role == .delivery ? "write" : "read")
            XCTAssertEqual(profile.workspace[".codex"], "deny")
            XCTAssertEqual(profile.absolute[paths.assignment.path], "read")
            XCTAssertEqual(profile.absolute[paths.projectPolicy.path], "read")
            XCTAssertEqual(profile.absolute["/Primary/.git"], "deny")
            XCTAssertEqual(profile.absolute["/Primary"], "deny")
            XCTAssertEqual(profile.absolute["/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools"], "deny")
            XCTAssertNil(profile.absolute[root.path]); XCTAssertNil(profile.absolute["/Users"])
            XCTAssertFalse(profile.absolute.values.contains("write"))
        }
    }
}
