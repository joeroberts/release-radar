import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionProfileCleanupClassificationTests: XCTestCase {
    func testClosedVerifiedAssignmentWithDurableSameAttemptClosureIsEligibleWithoutLiveAdapter() {
        var assignment = fixture(state: .closed)
        assignment.connectionClosed = true
        assignment.launchReserved = true
        assignment.workerAttemptID = UUID()
        assignment.sessionID = "closed-session"

        let result = classify(assignment)

        XCTAssertEqual(result.category, .cleanupEligible)
        XCTAssertEqual(result.assignmentID, assignment.id)
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.configurationBaseline?.candidateProfileID, assignment.permissionProfile)
        XCTAssertEqual(result.configurationBaseline?.selectedCodexContextID, assignment.codexContextID)
        XCTAssertEqual(result.configurationBaseline?.observedDefinition, assignment.permissionProfileDefinition)
        XCTAssertEqual(result.assignmentBaseline, assignment,
            "Later revalidation needs the exact persisted assignment identity, including registration and worker/session")
    }

    func testOpenCompletedAssignmentAndAuthenticatedLiveStatesRemainRetained() {
        var completedButOpen = fixture(state: .closed)
        completedButOpen.connectionClosed = false
        completedButOpen.launchReserved = true
        completedButOpen.workerAttemptID = UUID()
        completedButOpen.sessionID = "still-usable"

        XCTAssertEqual(classify(completedButOpen).category, .unknown,
            "A closed state without positive physical closure is not cleanup eligibility")

        var otherwiseClosed = fixture(state: .closed)
        otherwiseClosed.connectionClosed = true
        otherwiseClosed.launchReserved = true
        otherwiseClosed.workerAttemptID = UUID()
        otherwiseClosed.sessionID = "closed-session"
        XCTAssertEqual(classify(otherwiseClosed, liveState: .active).category, .active)
        XCTAssertEqual(classify(otherwiseClosed, liveState: .pendingApproval).category, .recoveryRetained)
        let unavailableAfterRestart = classify(otherwiseClosed, liveState: .unavailable)
        XCTAssertEqual(unavailableAfterRestart.category, .cleanupEligible)
        XCTAssertNil(unavailableAfterRestart.reason,
            "An unavailable adapter does not override a complete durable closure after restart")
        XCTAssertEqual(classify(completedButOpen, liveState: .unavailable).category, .unknown,
            "Unavailable runtime cannot supply the positive closure an incomplete record lacks")
    }

    func testIncompleteOrUncertainLifecycleEvidenceIsRetained() {
        var pending = fixture(state: .closed)
        pending.profileProvisioningReceipt = .init(state: .pending, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1), verifiedAt: nil)
        XCTAssertEqual(classify(pending).category, .recoveryRetained)
        XCTAssertEqual(classify(pending).reason, .incompleteProvisioning)

        var uncertain = terminalFixture()
        uncertain.uncertainOutcome = true
        XCTAssertEqual(classify(uncertain).category, .recoveryRetained)
        XCTAssertEqual(classify(uncertain).reason, .uncertainOutcome)

        var finalizationFailed = terminalFixture()
        finalizationFailed.finalizationFailed = true
        XCTAssertEqual(classify(finalizationFailed).category, .recoveryRetained)
        XCTAssertEqual(classify(finalizationFailed).reason, .finalizationFailed)

        var lostWorker = terminalFixture()
        lostWorker.state = .stopped
        lostWorker.uncertainOutcome = true
        lostWorker.lostWorkerRecovery = .init(requestID: UUID(), priorState: .authorized,
            candidateRevision: String(repeating: "a", count: 40),
            process: .init(version: 1, observedAt: Date(timeIntervalSinceReferenceDate: 1),
                executablePath: CodexExecutionIdentity.executable, permissionProfile: lostWorker.permissionProfile,
                argumentMarker: "permissions.\(lostWorker.permissionProfile).network.enabled=false"),
            grantDisposition: .noMatchingGrant)
        XCTAssertEqual(classify(lostWorker).category, .recoveryRetained)
        XCTAssertEqual(classify(lostWorker).reason, .uncertainOutcome)

        for state in [ProjectExecutionAssignment.State.stopped, .revoked] {
            var interrupted = fixture(state: state)
            interrupted.connectionClosed = true
            interrupted.launchReserved = true
            interrupted.workerAttemptID = UUID()
            interrupted.sessionID = "interrupted-session"
            let result = classify(interrupted)
            XCTAssertEqual(result.category, .recoveryRetained,
                "\(state) records remain recoverable unless a completed retirement proves otherwise")
            XCTAssertEqual(result.reason, .missingTerminalClosure)
        }
    }

    func testLegacyUnrecordedInstallationAndGenericRecoveryFlagDoNotVetoDurableClosure() {
        var legacy = terminalFixture()
        legacy.profileProvisioningReceipt = nil
        let legacyResult = classify(legacy, installationEvidence: .unrecorded)
        XCTAssertEqual(legacyResult.category, .cleanupEligible)
        XCTAssertNil(legacyResult.reason,
            "Unrecorded installation history is not unfinished lifecycle work when positive closure is durable")

        let result = classify(terminalFixture(), requiresInstallationRecovery: true)
        XCTAssertEqual(result.category, .cleanupEligible,
            "The generic association recovery convenience flag is not lifecycle evidence")
    }

    func testRetirementAndRemovalReceiptsNeverCreateARemainingEligibleProfile() {
        var partial = terminalFixture()
        partial.retirement = .init(requestID: UUID(), priorState: .closed)
        XCTAssertEqual(classify(partial).category, .recoveryRetained)
        XCTAssertEqual(classify(partial).reason, .incompleteRetirement)

        var removed = terminalFixture()
        removed.state = .superseded
        removed.retirement = .init(requestID: UUID(), priorState: .closed)
        removed.retirement?.worktreeRemoved = true
        removed.retirement?.profileRemoved = true
        removed.retirement?.completed = true
        XCTAssertEqual(classify(removed).category, .unknown)
        XCTAssertEqual(classify(removed).reason, .profileReappearedAfterRemoval)

        let absentAssociation = ProjectExecutionProfileAssociation.Result(category: .unknown,
            assignmentID: removed.id, reason: .profileMissing)
        let absent = ProjectExecutionProfileCleanupClassification.classify(input(assignment: removed,
            association: absentAssociation, configurationObservation: .missing))
        XCTAssertEqual(absent.category, .alreadyRemoved,
            "A completed removal receipt plus a freshly absent profile has no selectable cleanup target")
    }

    func testAssociationAndReusableProfileResultsStayOutsideOrUnknown() {
        let assignment = terminalFixture()
        let reserved = ProjectExecutionProfileAssociation.Result(category: .outsideAssignmentCleanup,
            reason: .reservedProfile)
        let reservedResult = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: reserved))
        XCTAssertEqual(reservedResult.category, .outsideAssignmentCleanup)
        XCTAssertEqual(reservedResult.reason, .association(.reservedProfile))

        var incorrectlyRetired = assignment
        incorrectlyRetired.retirement = .init(requestID: UUID(), priorState: .closed)
        incorrectlyRetired.retirement?.profileRemoved = true
        let reservedAfterBadLifecycleRecord = ProjectExecutionProfileCleanupClassification.classify(input(
            assignment: incorrectlyRetired, association: reserved))
        XCTAssertEqual(reservedAfterBadLifecycleRecord.category, .outsideAssignmentCleanup,
            "Reusable profiles stay outside assignment cleanup even when an inconsistent record claims removal")

        let missing = ProjectExecutionProfileAssociation.Result(category: .unknown,
            assignmentID: assignment.id, reason: .profileMissing)
        let missingResult = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: missing))
        XCTAssertEqual(missingResult.category, .unknown)
        XCTAssertEqual(missingResult.reason, .association(.profileMissing))
    }

    func testEveryPositiveTerminalFieldIsRequired() {
        let mutations: [(String, (inout ProjectExecutionAssignment) -> Void)] = [
            ("connection", { $0.connectionClosed = nil }),
            ("reservation", { $0.launchReserved = nil }),
            ("attempt", { $0.workerAttemptID = nil }),
            ("session", { $0.sessionID = "" }),
        ]

        for (name, mutate) in mutations {
            var assignment = terminalFixture()
            mutate(&assignment)
            let result = classify(assignment)
            XCTAssertEqual(result.category, .unknown, "Missing \(name) must fail closed")
            XCTAssertEqual(result.reason, .missingTerminalClosure)
        }
    }

    func testBaselineAndIdentityMustExactlyMatchTheProtectedAssociation() {
        let assignment = terminalFixture()
        let association = ProjectExecutionProfileAssociation.Result(category: .owned, assignmentID: assignment.id,
            ownershipProvenance: .verifiedProvisioningReceipt, installationEvidence: .verified)
        let valid = input(assignment: assignment, association: association)
        XCTAssertEqual(ProjectExecutionProfileCleanupClassification.classify(valid).configurationBaseline,
            valid.configurationBaseline)

        let wrongProfile = ProjectExecutionProfileCleanupClassification.ConfigurationBaseline(
            candidateProfileID: "rr-other", selectedCodexContextID: assignment.codexContextID!,
            observedDefinition: assignment.permissionProfileDefinition!)
        let wrongProfileResult = ProjectExecutionProfileCleanupClassification.classify(.init(assignment: assignment,
            association: association, configurationObservation: .present(assignment.permissionProfileDefinition!),
            configurationBaseline: wrongProfile))
        XCTAssertEqual(wrongProfileResult.category, .unknown)
        XCTAssertEqual(wrongProfileResult.reason, .identityMismatch)
        XCTAssertNil(wrongProfileResult.configurationBaseline)
        XCTAssertNil(wrongProfileResult.assignmentBaseline)

        let wrongAssociation = ProjectExecutionProfileAssociation.Result(category: .owned, assignmentID: "other-assignment",
            ownershipProvenance: .verifiedProvisioningReceipt, installationEvidence: .verified)
        let wrongAssociationResult = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: wrongAssociation))
        XCTAssertEqual(wrongAssociationResult.category, .unknown)
        XCTAssertEqual(wrongAssociationResult.reason, .identityMismatch)
        XCTAssertNil(wrongAssociationResult.configurationBaseline)
        XCTAssertNil(wrongAssociationResult.assignmentBaseline)
    }

    func testMissingAndUnavailableConfigurationObservationsNeverForgeACleanupBaseline() {
        let assignment = terminalFixture()
        let missingAssociation = ProjectExecutionProfileAssociation.Result(category: .unknown,
            assignmentID: assignment.id, reason: .profileMissing)
        let missing = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: missingAssociation, configurationObservation: .missing))
        XCTAssertEqual(missing.category, .unknown)
        XCTAssertEqual(missing.reason, .association(.profileMissing))
        XCTAssertNil(missing.configurationBaseline)
        XCTAssertNil(missing.assignmentBaseline)

        let unavailableAssociation = ProjectExecutionProfileAssociation.Result(category: .unknown,
            assignmentID: assignment.id, reason: .configurationUnavailable)
        let unavailable = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: unavailableAssociation, configurationObservation: .unavailable))
        XCTAssertEqual(unavailable.category, .unknown)
        XCTAssertEqual(unavailable.reason, .association(.configurationUnavailable))
        XCTAssertNil(unavailable.configurationBaseline)
        XCTAssertNil(unavailable.assignmentBaseline)

        let owned = ProjectExecutionProfileAssociation.Result(category: .owned, assignmentID: assignment.id,
            ownershipProvenance: .verifiedProvisioningReceipt, installationEvidence: .verified)
        let ownedMissing = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: owned, configurationObservation: .missing))
        XCTAssertEqual(ownedMissing.category, .unknown)
        XCTAssertEqual(ownedMissing.reason, .identityMismatch)
        XCTAssertNil(ownedMissing.configurationBaseline)
        XCTAssertNil(ownedMissing.assignmentBaseline)
    }

    func testMissingAssociationIsNotReportedAsDuplicateOwnership() {
        let assignment = terminalFixture()
        let missing = ProjectExecutionProfileAssociation.Result(category: .unknown,
            assignmentID: assignment.id, reason: .profileMissing)
        let result = ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: missing, configurationObservation: .missing))

        XCTAssertEqual(result.category, .unknown)
        XCTAssertEqual(result.reason, .association(.profileMissing))
        XCTAssertNotEqual(result.reason, .association(.duplicateOwnership))
    }

    func testOwnershipClaimScanReturnsExactCrossProjectClaimsAndPreservesNilContext() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let selectedContextID = UUID()
        var first = fixture(state: .closed, projectID: "project-one", assignmentID: "same-assignment")
        first.codexContextID = nil
        var second = fixture(state: .closed, projectID: "project-two", assignmentID: "same-assignment",
            permissionProfile: first.permissionProfile)
        second.codexContextID = selectedContextID
        var otherContext = fixture(state: .closed, projectID: "project-four", assignmentID: "same-assignment",
            permissionProfile: first.permissionProfile)
        otherContext.codexContextID = UUID()
        var unrelated = fixture(state: .closed, projectID: "project-three", assignmentID: "other-assignment",
            permissionProfile: "rr-delivery-unrelated")
        unrelated.codexContextID = selectedContextID

        try store.saveAssignment(first, expected: nil)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]), id: selectedContextID)
        try store.saveCodexContext(context, expected: nil)
        try store.saveAssignment(second, expected: nil)
        try store.saveAssignment(unrelated, expected: nil)
        let otherPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-four", taskID: otherContext.id)
        try FileManager.default.createDirectory(at: otherPaths.assignment.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try JSONEncoder().encode(otherContext).write(to: otherPaths.assignment)

        let reader = try ProjectExecutionFileStore(root: root, create: false)
        XCTAssertEqual(try reader.profileOwnershipClaims(candidateProfileIDs: [], selectedCodexContextID: selectedContextID), [],
            "An empty candidate selection must not require a protected namespace scan")

        let claims = try reader.profileOwnershipClaims(candidateProfileIDs: [first.permissionProfile],
            selectedCodexContextID: selectedContextID)
        XCTAssertEqual(Set(claims.map { "\($0.projectID)|\($0.registrationID)|\($0.registrationGeneration)|\($0.assignmentID)" }), Set([
            "project-one|registration-project-one|1|same-assignment",
            "project-two|registration-project-two|1|same-assignment",
        ]))
        XCTAssertTrue(claims.contains { $0.projectID == "project-one" && $0.codexContextID == nil },
            "A missing context remains a claim for later fail-closed classification, not an omitted record")
        XCTAssertFalse(claims.contains { $0.projectID == "project-four" },
            "A known different-context claim cannot compete with the selected context")
        XCTAssertFalse(claims.contains { $0.candidateProfileID == unrelated.permissionProfile })
    }

    func testOwnershipClaimScanFailsInsteadOfTreatingTamperedAssignmentAsNoClaims() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        var assignment = fixture(state: .closed, projectID: "project-one", assignmentID: "tampered-assignment")
        assignment.codexContextID = nil
        try store.saveAssignment(assignment, expected: nil)

        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: assignment.id)
        try Data("not-json".utf8).write(to: paths.assignment)

        XCTAssertThrowsError(try store.profileOwnershipClaims(candidateProfileIDs: [assignment.permissionProfile],
            selectedCodexContextID: UUID()))
    }

    private func classify(_ assignment: ProjectExecutionAssignment,
                          liveState: ProjectExecutionProfileCleanupClassification.LiveState? = nil,
                          installationEvidence: ProjectExecutionProfileAssociation.InstallationEvidence = .verified,
                          requiresInstallationRecovery: Bool = false) -> ProjectExecutionProfileCleanupClassification.Result {
        let association = ProjectExecutionProfileAssociation.Result(category: .owned, assignmentID: assignment.id,
            ownershipProvenance: .verifiedProvisioningReceipt, installationEvidence: installationEvidence,
            requiresInstallationRecovery: requiresInstallationRecovery)
        return ProjectExecutionProfileCleanupClassification.classify(input(assignment: assignment,
            association: association, liveState: liveState))
    }

    private func input(assignment: ProjectExecutionAssignment,
                       association: ProjectExecutionProfileAssociation.Result,
                       liveState: ProjectExecutionProfileCleanupClassification.LiveState? = nil,
                       configurationObservation: ProjectExecutionProfileObservation? = nil)
    -> ProjectExecutionProfileCleanupClassification.Input {
        let observation = configurationObservation ?? .present(assignment.permissionProfileDefinition!)
        let baseline: ProjectExecutionProfileCleanupClassification.ConfigurationBaseline?
        if case .present = observation {
            baseline = .init(candidateProfileID: assignment.permissionProfile,
                selectedCodexContextID: assignment.codexContextID!, observedDefinition: assignment.permissionProfileDefinition!)
        } else {
            baseline = nil
        }
        return .init(assignment: assignment, association: association, configurationObservation: observation,
            configurationBaseline: baseline, liveState: liveState)
    }

    private func terminalFixture() -> ProjectExecutionAssignment {
        var assignment = fixture(state: .closed)
        assignment.connectionClosed = true
        assignment.launchReserved = true
        assignment.workerAttemptID = UUID()
        assignment.sessionID = "closed-session"
        return assignment
    }

    private func fixture(state: ProjectExecutionAssignment.State, projectID: String = "project-one",
                         assignmentID: String = "delivery-cleanup",
                         permissionProfile: String = "rr-delivery-cleanup") -> ProjectExecutionAssignment {
        let registration = ProjectRegistration(projectID: .init(rawValue: projectID),
            registrationID: "registration-\(projectID)", requestGeneration: 1)
        var assignment = ProjectExecutionAssignment(id: assignmentID, registration: registration,
            checkoutPath: "/Worktrees/\(projectID)/\(assignmentID)", role: .delivery,
            permissionProfile: permissionProfile, model: "gpt-5.6-terra", effort: "medium",
            authorization: "Approved work", context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], state: state,
            worktree: .init(checkout: "/Worktrees/\(projectID)/\(assignmentID)", baseline: String(repeating: "a", count: 40),
                branch: "codex/\(projectID)-\(assignmentID)", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary"))
        assignment.codexContextID = UUID()
        assignment.permissionProfileDefinition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        assignment.profileProvisioningReceipt = .init(state: .verified, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1), verifiedAt: Date(timeIntervalSinceReferenceDate: 2))
        return assignment
    }
}
