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

    func testOptionalResourceReceiptsPreserveLegacyDecodingAndCannotReadmitRetiredWork() throws {
        let original = assignment()
        let legacy = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ProjectExecutionAssignment.self, from: legacy), original)
        var retired = assignment(state: .unknown)
        retired.connectionClosed = true; retired.uncertainOutcome = true
        retired.retirement = .init(requestID: UUID(), priorState: .unknown)
        retired.retirement?.worktreeRemoved = true; retired.retirement?.profileRemoved = true; retired.retirement?.completed = true
        XCTAssertThrowsError(try retired.validated())
        retired.state = .superseded
        try retired.validated()
        XCTAssertEqual(try JSONDecoder().decode(ProjectExecutionAssignment.self, from: JSONEncoder().encode(retired)), retired)
        XCTAssertThrowsError(try retired.admit(registration: registration, checkoutPath: retired.checkoutPath, sessionID: "old", boundSessionID: "old"))
        retired.retirement?.connectionCloseUncertain = true
        XCTAssertThrowsError(try retired.validated())
    }

    func testLostWorkerReceiptPreservesUncertainOutcomeWithoutClaimingDeliveredWork() throws {
        let requestID = UUID()
        let observedAt = Date(timeIntervalSince1970: 1_789_963_200)
        var recovered = assignment(state: .stopped)
        recovered.sessionID = "lost-session"
        recovered.launchReserved = true
        recovered.connectionClosed = true
        recovered.uncertainOutcome = true
        recovered.lostWorkerRecovery = .init(
            requestID: requestID,
            priorState: .authorized,
            candidateRevision: String(repeating: "b", count: 40),
            process: .init(
                version: 1,
                observedAt: observedAt,
                executablePath: CodexExecutionIdentity.executable,
                permissionProfile: recovered.permissionProfile,
                argumentMarker: "permissions.\(recovered.permissionProfile).network.enabled=false"
            ),
            grantDisposition: .matchingGrantReleased
        )

        try recovered.validated()
        XCTAssertEqual(
            try JSONDecoder().decode(ProjectExecutionAssignment.self, from: JSONEncoder().encode(recovered)),
            recovered
        )
        XCTAssertNil(recovered.retirement)
        XCTAssertThrowsError(try recovered.admit(
            registration: registration,
            checkoutPath: recovered.checkoutPath,
            sessionID: "lost-session",
            boundSessionID: "lost-session"
        ))

        var falselyClosed = recovered
        falselyClosed.state = .closed
        XCTAssertThrowsError(try falselyClosed.validated(),
            "Process absence recovers the connection, not delivery completion")
        var wrongMarker = recovered
        wrongMarker.lostWorkerRecovery = .init(
            requestID: requestID,
            priorState: .authorized,
            candidateRevision: String(repeating: "b", count: 40),
            process: .init(
                version: 1,
                observedAt: observedAt,
                executablePath: CodexExecutionIdentity.executable,
                permissionProfile: recovered.permissionProfile,
                argumentMarker: "permissions.rr-another-assignment.network.enabled=false"
            ),
            grantDisposition: .noMatchingGrant
        )
        XCTAssertThrowsError(try wrongMarker.validated())
    }

    func testLostWorkerProcessInventoryFailsClosedForIncompleteOrSuspiciousIdentity() throws {
        let value = assignment()
        let marker = "permissions.\(value.permissionProfile).network.enabled=false"
        let observedAt = Date(timeIntervalSince1970: 1_789_963_200)
        let unrelated = ProjectExecutionWorkerProcessInventory.Process(
            processID: 41,
            startTime: 100,
            executablePath: "/usr/bin/true",
            arguments: ["true"],
            identity: .unrelated,
            stable: true
        )
        let evidence = try ProjectExecutionWorkerProcessInventory.verifiedAbsence(
            for: value,
            snapshot: .init(isComplete: true, processes: [unrelated]),
            observedAt: observedAt
        )
        XCTAssertEqual(evidence.argumentMarker, marker)
        XCTAssertEqual(evidence.executablePath, CodexExecutionIdentity.executable)

        let suspicious = ProjectExecutionWorkerProcessInventory.Process(
            processID: 42,
            startTime: 101,
            executablePath: "/tmp/codex",
            arguments: ["codex", "-c", marker],
            identity: .unexpected,
            stable: true
        )
        XCTAssertThrowsError(try ProjectExecutionWorkerProcessInventory.verifiedAbsence(
            for: value,
            snapshot: .init(isComplete: true, processes: [suspicious]),
            observedAt: observedAt
        ), "An exact marker on an unexpected path or signature is unavailable, never absent")

        let unreadable = ProjectExecutionWorkerProcessInventory.Process(
            processID: 43,
            startTime: 102,
            executablePath: CodexExecutionIdentity.executable,
            arguments: nil,
            identity: .unavailable,
            stable: true
        )
        XCTAssertThrowsError(try ProjectExecutionWorkerProcessInventory.verifiedAbsence(
            for: value,
            snapshot: .init(isComplete: true, processes: [unreadable]),
            observedAt: observedAt
        ))
        XCTAssertThrowsError(try ProjectExecutionWorkerProcessInventory.verifiedAbsence(
            for: value,
            snapshot: .init(isComplete: false, processes: []),
            observedAt: observedAt
        ))
    }
}
