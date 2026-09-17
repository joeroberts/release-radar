import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionAssignmentTests: XCTestCase {
    private let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)

    private func assignment(state: ProjectExecutionAssignment.State = .authorized) -> ProjectExecutionAssignment {
        .init(id: "task-one", registration: registration, checkoutPath: "/Execution/Worktrees/project-one/task-one", role: .delivery,
              permissionProfile: "rr-project-one-task-one", model: "gpt-5.6-sol", effort: "high", authorization: "Implement the approved slice",
              context: [.init(path: "docs/design/current.md", digest: String(repeating: "a", count: 64))],
              excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], state: state)
    }

    func testVerifiedAssignmentCarriesScopedAuthorizationWithoutRepeatedOwnerApproval() throws {
        let value = assignment()
        try value.admit(registration: registration, checkoutPath: value.checkoutPath, sessionID: "session-one", boundSessionID: "session-one")
        XCTAssertTrue(value.workerInstructions.contains("Implement the approved slice"))
        XCTAssertTrue(value.workerInstructions.contains("Runtime approval"))
        XCTAssertFalse(value.workerInstructions.contains("bypass"))
    }

    func testRevokedStoppedSupersededUnknownAndUnboundWorkersCannotStartWork() {
        for state in [ProjectExecutionAssignment.State.revoked, .stopped, .superseded, .unknown] {
            let value = assignment(state: state)
            XCTAssertThrowsError(try value.admit(registration: registration, checkoutPath: value.checkoutPath, sessionID: "session-one", boundSessionID: "session-one"))
        }
        let value = assignment()
        XCTAssertThrowsError(try value.admit(registration: registration, checkoutPath: value.checkoutPath, sessionID: "session-one", boundSessionID: nil))
        XCTAssertThrowsError(try value.admit(registration: registration, checkoutPath: value.checkoutPath, sessionID: "sibling-session", boundSessionID: "session-one"))
    }

    func testSiblingCheckoutStaleRegistrationTraversalAndUltraAreRejected() {
        let value = assignment()
        XCTAssertThrowsError(try value.admit(registration: registration, checkoutPath: "/Execution/Worktrees/project-one/task-two", sessionID: "session-one", boundSessionID: "session-one"))
        XCTAssertThrowsError(try value.admit(registration: .init(projectID: registration.projectID, registrationID: "old", requestGeneration: 1), checkoutPath: value.checkoutPath, sessionID: "session-one", boundSessionID: "session-one"))
        XCTAssertThrowsError(try ProjectExecutionPaths.component("../sibling"))
        XCTAssertThrowsError(try ProjectExecutionPaths.component("task/other"))
        XCTAssertThrowsError(try assignment().validated(effort: "ultra"))
    }

    func testProjectTaskLayoutSeparatesProtectedAssignmentsAndSiblingWorktrees() throws {
        let paths = try ProjectExecutionPaths(storageRoot: URL(fileURLWithPath: "/Execution"), projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(paths.checkout.path, "/Execution/Worktrees/project-one/task-one")
        XCTAssertEqual(paths.assignment.path, "/Execution/Assignments/project-one/task-one/assignment.json")
        XCTAssertFalse(paths.assignment.path.hasPrefix(paths.checkout.path + "/"))
    }
}
