import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionProfileTests: XCTestCase {
    func testLegacyDecodedReviewRemainsReadOnlyAndRejectsUnsupportedScratchVersions() throws {
        let root = URL(fileURLWithPath: "/Execution")
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: "task-one")
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Primary", appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator")
        let tree = ExecutionWorktree(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40), branch: "codex/rr-project-one-task-one", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary")
        let review = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .review,
            permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "high", authorization: "Existing authorized work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], worktree: tree)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(review)) as? [String: Any])
        legacyObject.removeValue(forKey: "reviewScratchVersion")
        let legacy = try JSONDecoder().decode(ProjectExecutionAssignment.self, from: JSONSerialization.data(withJSONObject: legacyObject))
        XCTAssertNil(legacy.reviewScratchVersion)
        let legacyProfile = try ProjectExecutionPermissionProfile(assignment: legacy, policy: policy, paths: paths)
        XCTAssertNil(legacyProfile.workspace[".build"])
        XCTAssertEqual(try legacyProfile.definition, try ProjectExecutionPermissionProfile(assignment: review, policy: policy, paths: paths).definition)

        let unsupported = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .review,
            permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "high", authorization: "Existing authorized work",
            context: review.context, excludedPaths: review.excludedPaths, worktree: tree, reviewScratchVersion: 2)
        XCTAssertThrowsError(try unsupported.validated())
        let deliveryScratch = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .delivery,
            permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "medium", authorization: "Existing authorized work",
            context: review.context, excludedPaths: review.excludedPaths, worktree: tree,
            reviewScratchVersion: ProjectExecutionAssignment.xcodeBuildScratchVersion)
        XCTAssertThrowsError(try deliveryScratch.validated())
    }

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
        let profiles: [(ProjectExecutionAssignment.Role, Int?)] = [(.delivery, nil), (.review, ProjectExecutionAssignment.xcodeBuildScratchVersion)]
        for (role, reviewScratchVersion) in profiles {
            let assignment = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: role,
                permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: role == .delivery ? "medium" : "high", authorization: "Existing authorized work",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], worktree: tree,
                reviewScratchVersion: reviewScratchVersion)
            let profile = try ProjectExecutionPermissionProfile(assignment: assignment, policy: policy, paths: paths)
            XCTAssertEqual(profile.workspace["."], role == .delivery ? "write" : "read")
            XCTAssertEqual(profile.workspace[".codex"], "deny")
            XCTAssertEqual(profile.workspace[".build"], role == .review ? "write" : nil)
            XCTAssertNil(profile.workspace["DerivedData"])
            XCTAssertEqual(profile.absolute[paths.assignment.path], "read")
            XCTAssertEqual(profile.absolute[paths.projectPolicy.path], "read")
            XCTAssertEqual(profile.absolute["/Primary/.git"], "deny")
            XCTAssertEqual(profile.absolute["/Primary"], "deny")
            XCTAssertEqual(profile.absolute["/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools"], "deny")
            XCTAssertNil(profile.absolute[root.path]); XCTAssertNil(profile.absolute["/Users"])
            XCTAssertNil(profile.absolute["/tmp"]); XCTAssertNil(profile.absolute[":tmpdir"])
            XCTAssertFalse(profile.absolute.values.contains("write"))
        }
    }

    // Unit-only: active worker sandbox enforcement requires a separate supported runtime probe.
    func testSharedExecutionSkillProfileAddsOnlyTheRecognizedExactSkillFileRead() throws {
        let (assignment, policy, paths) = try profileFixture()
        let skillPath = "/selected/.codex/plugins/cache/release-radar/release-radar/0.1.12/skills/shared-execution/SKILL.md"
        let skill = try ProjectExecutionSharedExecutionSkill(
            skillFile: skillPath,
            pluginVersion: "0.1.12",
            packageDigest: "8f23498996d2beb1994db711d39527ef42a96ffab6344d1976e5e18f925e90eb"
        )

        let profile = try ProjectExecutionPermissionProfile(
            assignment: assignment,
            policy: policy,
            paths: paths,
            sharedExecutionSkill: skill
        )

        XCTAssertEqual(profile.absolute[skillPath], "read")
        XCTAssertEqual(profile.absolute.count, try ProjectExecutionPermissionProfile(
            assignment: assignment, policy: policy, paths: paths
        ).absolute.count + 1)
        XCTAssertEqual(profile.filesystemObject[":root"] as? String, "deny")
        XCTAssertEqual(profile.absolute[policy.primaryRoot], "deny")
        XCTAssertEqual(profile.absolute[assignment.worktree?.commonGitDirectory ?? ""], "deny")
        XCTAssertFalse(profile.absolute.values.contains("write"))
    }

    func testSharedExecutionSkillRejectsNonportableOrUnrecognizedRoots() throws {
        let skillPath = "/selected/.codex/plugins/cache/release-radar/release-radar/0.1.12/skills/shared-execution/SKILL.md"
        let recognizedDigest = "8f23498996d2beb1994db711d39527ef42a96ffab6344d1976e5e18f925e90eb"
        let invalid: [(String, String, String)] = [
            ("relative/skills/shared-execution", "0.1.12", recognizedDigest),
            ("/selected/.codex/plugins/cache/release-radar/release-radar/0.1.12/skills/shared-execution", "0.1.12", recognizedDigest),
            (skillPath, "0.1.7", "75f513d53675b6ae5679d2add575b76f9d32575d605f77702fd91a8c70d9f198"),
            (skillPath.replacingOccurrences(of: "/0.1.12/", with: "/0.1.12-dev/"), "0.1.12-dev", recognizedDigest),
            (skillPath, "0.1.12", String(repeating: "a", count: 64)),
            (skillPath + "/child", "0.1.12", recognizedDigest),
        ]

        for (path, version, digest) in invalid {
            XCTAssertThrowsError(try ProjectExecutionSharedExecutionSkill(
                skillFile: path, pluginVersion: version, packageDigest: digest
            ), "\(path) must not become a worker read grant")
        }
    }

    private func profileFixture() throws -> (ProjectExecutionAssignment, ProjectExecutionPolicy, ProjectExecutionPaths) {
        let paths = try ProjectExecutionPaths(storageRoot: URL(fileURLWithPath: "/Execution"), projectID: "project-one", taskID: "task-one")
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Primary", appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator")
        let worktree = ExecutionWorktree(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40), branch: "codex/rr-project-one-task-one", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary")
        let assignment = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .review,
            permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "high", authorization: "Existing authorized work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], worktree: worktree)
        return (assignment, policy, paths)
    }
}
