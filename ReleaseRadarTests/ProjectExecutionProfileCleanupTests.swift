import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionProfileCleanupTests: XCTestCase {
    func testConfirmedCleanupReceiptBindsExactProfileContextAndDefinitionWithoutChangingLifecycle() throws {
        var assignment = terminalAssignment()
        let originalState = assignment.state
        let originalRetirement = assignment.retirement
        let receipt = ProjectExecutionProfileCleanupReceipt(requestID: UUID(),
            profileID: assignment.permissionProfile, selectedCodexContextID: try XCTUnwrap(assignment.codexContextID),
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(assignment.permissionProfileDefinition))

        assignment.profileCleanupReceipt = receipt

        XCTAssertTrue(receipt.validates(for: assignment))
        XCTAssertEqual(assignment.state, originalState)
        XCTAssertEqual(assignment.retirement, originalRetirement)
    }

    func testCleanupReceiptRejectsChangedTargetContextAndDefinition() throws {
        let original = terminalAssignment()
        let receipt = ProjectExecutionProfileCleanupReceipt(requestID: UUID(),
            profileID: original.permissionProfile, selectedCodexContextID: try XCTUnwrap(original.codexContextID),
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(original.permissionProfileDefinition))

        let changedProfile = ProjectExecutionProfileCleanupReceipt(requestID: UUID(),
            profileID: "rr-delivery-other", selectedCodexContextID: try XCTUnwrap(original.codexContextID),
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(original.permissionProfileDefinition))
        XCTAssertFalse(changedProfile.validates(for: original))

        var changedContext = original
        changedContext.codexContextID = UUID()
        XCTAssertFalse(receipt.validates(for: changedContext))

        var changedDefinition = original
        changedDefinition.permissionProfileDefinition = Data(#"{"network":{"enabled":true}}"#.utf8)
        XCTAssertFalse(receipt.validates(for: changedDefinition))
    }

    func testVerifiedRemovalRequiresReadbackAbsenceAndResultingVersion() throws {
        let assignment = terminalAssignment()
        let requestID = UUID()
        let contextID = try XCTUnwrap(assignment.codexContextID)
        let definition = try XCTUnwrap(assignment.permissionProfileDefinition)

        let absentWithoutVersion = ProjectExecutionProfileCleanupReceipt(requestID: requestID,
            profileID: assignment.permissionProfile, selectedCodexContextID: contextID,
            configurationVersion: "before-v1", expectedDefinition: definition,
            state: .removalVerified, acknowledgement: .acknowledged,
            observedTargetPresence: .absent)
        XCTAssertFalse(absentWithoutVersion.validates(for: assignment))

        let presentAfterAcknowledgement = ProjectExecutionProfileCleanupReceipt(requestID: requestID,
            profileID: assignment.permissionProfile, selectedCodexContextID: contextID,
            configurationVersion: "before-v1", expectedDefinition: definition,
            state: .removalVerified, acknowledgement: .acknowledged,
            observedTargetPresence: .present, observedConfigurationVersion: "after-v2")
        XCTAssertFalse(presentAfterAcknowledgement.validates(for: assignment))

        let verified = ProjectExecutionProfileCleanupReceipt(requestID: requestID,
            profileID: assignment.permissionProfile, selectedCodexContextID: contextID,
            configurationVersion: "before-v1", expectedDefinition: definition,
            state: .removalVerified, acknowledgement: .acknowledged,
            observedTargetPresence: .absent, observedConfigurationVersion: "after-v2",
            finalizationPending: true)
        XCTAssertTrue(verified.validates(for: assignment))
        XCTAssertTrue(verified.finalizationPending,
            "Post-effect bookkeeping is separate from deletion and must remain resumable")
    }

    func testConfirmationRetainsExactSelectedTargetBaseline() throws {
        let assignment = terminalAssignment()
        let contextID = try XCTUnwrap(assignment.codexContextID)
        let target = ProjectExecutionProfileCleanupConfirmation.Target(profileID: assignment.permissionProfile,
            assignmentID: assignment.id, expectedDefinition: try XCTUnwrap(assignment.permissionProfileDefinition),
            assignmentBaseline: assignment)
        let confirmation = ProjectExecutionProfileCleanupConfirmation(requestID: UUID(), registration: assignment.registration,
            selectedCodexContextID: contextID, configurationVersion: "before-v1", targets: [target])

        XCTAssertEqual(confirmation.targets, [target])
        XCTAssertEqual(confirmation.targets[0].assignmentBaseline.workerAttemptID, assignment.workerAttemptID)
        XCTAssertEqual(confirmation.targets[0].assignmentBaseline.sessionID, assignment.sessionID)
    }

    func testCleanupEmitsOneExactConfirmedRequestAndPersistsVerifiedReceipt() async throws {
        let fixture = try cleanupFixture()
        let configuration = RecordingConfiguration(observations: [fixture.observation, fixture.absentReadback])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation,
            beforeWrite: {})

        XCTAssertEqual(outcomes.count, 1)
        guard case .removed = outcomes[0].kind else { return XCTFail("Expected confirmed removal") }
        let requests = await configuration.requests
        XCTAssertEqual(requests, [.init(profileID: fixture.assignment.permissionProfile,
            selectedCodexContextID: fixture.contextID, configurationVersion: "before-v1",
            expectedDefinition: try XCTUnwrap(fixture.assignment.permissionProfileDefinition))])
        let saved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(saved.profileCleanupReceipt?.state, .removalVerified)
        XCTAssertEqual(saved.profileCleanupReceipt?.observedTargetPresence, .absent)
        XCTAssertEqual(saved.profileCleanupReceipt?.observedConfigurationVersion, "after-v2")
        XCTAssertNil(saved.retirement, "Profile cleanup must not retire the assignment")
    }

    func testCleanupRejectsVersionDriftBeforeWriterAndPreservesTarget() async throws {
        let fixture = try cleanupFixture()
        var drifted = fixture.observation
        drifted = .init(selectedCodexContextID: fixture.contextID, configurationVersion: "other-v9",
            observedAt: drifted.observedAt, entries: drifted.entries)
        let configuration = RecordingConfiguration(observations: [drifted])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation,
            beforeWrite: {})

        XCTAssertEqual(outcomes.count, 1)
        guard case .conflict = outcomes[0].kind else { return XCTFail("Expected version conflict") }
        let requests = await configuration.requests
        XCTAssertTrue(requests.isEmpty)
        let saved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertNil(saved.profileCleanupReceipt)
    }

    func testVerifiedReplayDoesNotWriteAndReappearedTargetConflicts() async throws {
        let fixture = try cleanupFixture()
        var completed = fixture.assignment
        completed.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: completed.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(completed.permissionProfileDefinition),
            state: .removalVerified, acknowledgement: .acknowledged,
            observedTargetPresence: .absent, observedConfigurationVersion: "after-v2")
        try fixture.store.saveAssignment(completed, expected: fixture.assignment)

        let missing = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "after-v2", observedAt: Date(), entries: [])
        let replayConfiguration = RecordingConfiguration(observations: [missing])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: replayConfiguration)
        let replay = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        XCTAssertEqual(replay.count, 1)
        guard case .replayed = replay[0].kind else { return XCTFail("Expected replay") }
        let replayRequests = await replayConfiguration.requests
        XCTAssertTrue(replayRequests.isEmpty)

        let reappearedConfiguration = RecordingConfiguration(observations: [fixture.observation], profileExists: true)
        let reappearedCoordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: reappearedConfiguration)
        let conflict = try await reappearedCoordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        XCTAssertEqual(conflict.count, 1)
        guard case .conflict = conflict[0].kind else { return XCTFail("Expected reappeared-profile conflict") }
        let reappearedRequests = await reappearedConfiguration.requests
        XCTAssertTrue(reappearedRequests.isEmpty)
    }

    func testUnknownWriterOutcomeRecordsUnknownEffectAndNeverClaimsRemoval() async throws {
        let fixture = try cleanupFixture()
        let configuration = RecordingConfiguration(observations: [fixture.observation, fixture.absentReadback],
            removalError: .unavailable)
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        XCTAssertEqual(outcomes.count, 1)
        guard case .unresolved = outcomes[0].kind else {
            return XCTFail("A lost writer reply must remain unresolved")
        }
        let requestCount = await configuration.requests.count
        XCTAssertEqual(requestCount, 1)
        let saved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(saved.profileCleanupReceipt?.state, .outcomeUnknown)
        XCTAssertEqual(saved.profileCleanupReceipt?.observedTargetPresence, .unavailable)
    }

    func testUnknownReceiptWithFreshAbsenceIsUnattributedAndDoesNotWrite() async throws {
        let fixture = try cleanupFixture()
        var pending = fixture.assignment
        pending.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: pending.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(pending.permissionProfileDefinition),
            state: .outcomeUnknown, acknowledgement: .unknown, observedTargetPresence: .unavailable)
        try fixture.store.saveAssignment(pending, expected: fixture.assignment)
        let configuration = RecordingConfiguration(observations: [fixture.absentReadback])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        XCTAssertEqual(outcomes.count, 1)
        guard case .observedAbsentUnattributed = outcomes[0].kind else { return XCTFail("Absence after an unknown effect is not proof of causation") }
        let requests = await configuration.requests
        XCTAssertTrue(requests.isEmpty)
        let saved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertNotEqual(saved.profileCleanupReceipt?.state, .removalVerified)
    }

    func testFinishFailureRecoversOriginalConnectionBeforeReplayWithoutWritingAgain() async throws {
        let fixture = try cleanupFixture()
        let configuration = RecordingConfiguration(observations: [fixture.observation, fixture.absentReadback, fixture.absentReadback], finishFailure: .unavailable)
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)
        let first = try await coordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        guard case .removed = try XCTUnwrap(first.outcomes.first).kind else {
            return XCTFail("Expected verified profile effect")
        }
        XCTAssertFalse(first.configurationFinalized)
        let saved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(saved.profileCleanupReceipt?.state, .removalVerified)
        XCTAssertEqual(saved.profileCleanupReceipt?.helperClosureState, .pending)
        XCTAssertNotNil(saved.profileCleanupReceipt?.configurationSessionID)
        XCTAssertTrue(saved.profileCleanupReceipt?.finalizationPending == true)
        await configuration.resetEvents()

        let replay = try await coordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        guard case .replayed = try XCTUnwrap(replay.outcomes.first).kind else {
            return XCTFail("Expected the verified effect to replay without deletion")
        }
        XCTAssertTrue(replay.configurationFinalized)
        let state = await configuration.state()
        XCTAssertEqual(state.requestCount, 1)
        XCTAssertEqual(state.recoveryAttempts, 1)
        XCTAssertEqual(state.events.first, "recover",
            "Retry must recover the retained original connection before observing configuration again")
        let recovered = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(recovered.profileCleanupReceipt?.helperClosureState, .verified)
    }

    func testFailedOriginalConnectionRecoveryRetainsExactConfirmationWithoutWritingAgain() async throws {
        let fixture = try cleanupFixture()
        let configuration = RecordingConfiguration(
            observations: [fixture.observation, fixture.absentReadback],
            finishFailure: .unavailable, recoveryFailure: .unavailable)
        let coordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: configuration)
        let first = try await coordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        XCTAssertFalse(first.configurationFinalized)
        await configuration.resetEvents()

        let replay = try await coordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        XCTAssertFalse(replay.configurationFinalized)
        let state = await configuration.state()
        XCTAssertEqual(state.requestCount, 1)
        XCTAssertEqual(state.recoveryAttempts, 1)
        XCTAssertEqual(state.events.first, "recover")
        let recoverable = try await coordinator.recoverableConfirmations(project: fixture.project)
        XCTAssertEqual(recoverable, [fixture.confirmation])
        let saved = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertNotEqual(saved.profileCleanupReceipt?.helperClosureState, .verified)
        XCTAssertTrue(saved.profileCleanupReceipt?.finalizationPending == true)
    }

    func testUnknownWriterOutcomeWithFailedCloseRecoversBeforeObservationWithoutAnotherRemoval() async throws {
        let fixture = try cleanupFixture()
        let configuration = RecordingConfiguration(
            observations: [fixture.observation, fixture.absentReadback],
            removalError: .unavailable, finishFailure: .unavailable)
        let coordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: configuration)

        let first = try await coordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        guard case .unresolved = try XCTUnwrap(first.outcomes.first).kind else {
            return XCTFail("A lost writer reply must remain unresolved")
        }
        XCTAssertFalse(first.configurationFinalized)
        let pending = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(pending.profileCleanupReceipt?.state, .outcomeUnknown)
        XCTAssertEqual(pending.profileCleanupReceipt?.helperClosureState, .pending)
        await configuration.resetEvents()

        let retry = try await coordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        guard case .observedAbsentUnattributed = try XCTUnwrap(retry.outcomes.first).kind else {
            return XCTFail("Fresh absence after an unknown effect must remain unattributed")
        }
        let state = await configuration.state()
        XCTAssertEqual(state.requestCount, 1,
            "Recovery and observation must not repeat the uncertain deletion")
        XCTAssertEqual(state.recoveryAttempts, 1)
        XCTAssertEqual(state.events.first, "recover",
            "The failed request-owned connection must recover before any observation")
    }

    func testLaterReplayCloseFailureRecoversExactConnectionAndFreshCoordinatorCannotAttestIt() async throws {
        let fixture = try cleanupFixture()
        let initialSessionID = UUID()
        let initialConfiguration = RecordingConfiguration(observations: [fixture.observation])
        let initialCoordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: initialConfiguration,
            configurationSessionID: initialSessionID)

        let first = try await initialCoordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        guard case .removed = try XCTUnwrap(first.outcomes.first).kind else {
            return XCTFail("Expected the first confirmed removal")
        }
        XCTAssertTrue(first.configurationFinalized)
        let initiallyClosed = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(initiallyClosed.profileCleanupReceipt?.configurationSessionID, initialSessionID)
        XCTAssertEqual(initiallyClosed.profileCleanupReceipt?.helperClosureState, .verified)
        XCTAssertTrue(initiallyClosed.profileCleanupReceipt?.finalizationPending == true)

        let replaySessionID = UUID()
        let replayConfiguration = RecordingConfiguration(
            observations: [fixture.absentReadback, fixture.absentReadback],
            finishFailuresByAttempt: [1: .unavailable])
        let replayCoordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: replayConfiguration,
            configurationSessionID: replaySessionID)
        let replay = try await replayCoordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        guard case .replayed = try XCTUnwrap(replay.outcomes.first).kind else {
            return XCTFail("Expected an audit-only replay without another deletion")
        }
        XCTAssertFalse(replay.configurationFinalized)
        let failedReplay = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(failedReplay.profileCleanupReceipt?.configurationSessionID, replaySessionID,
            "A fresh helper may replace only positively verified prior-session ownership")
        XCTAssertEqual(failedReplay.profileCleanupReceipt?.helperClosureState, .unknown,
            "A later failed helper close must replace stale verified closure evidence")

        let substituteSessionID = UUID()
        let freshConfiguration = RecordingConfiguration(observations: [fixture.absentReadback])
        let freshCoordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: freshConfiguration,
            configurationSessionID: substituteSessionID)
        let freshReplay = try await freshCoordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        XCTAssertFalse(freshReplay.configurationFinalized,
            "A fresh coordinator cannot attest a failed connection owned by another session")
        let afterFreshReplay = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(afterFreshReplay.profileCleanupReceipt?.configurationSessionID, replaySessionID,
            "A fresh coordinator must not replace unresolved prior-session ownership")
        XCTAssertEqual(afterFreshReplay.profileCleanupReceipt?.helperClosureState, .unknown)
        let substituteState = await freshConfiguration.state()
        XCTAssertEqual(substituteState.requestCount, 0)
        XCTAssertEqual(substituteState.recoveryAttempts, 0)

        await replayConfiguration.resetEvents()
        let recovered = try await replayCoordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        XCTAssertTrue(recovered.configurationFinalized)
        let state = await replayConfiguration.state()
        XCTAssertEqual(state.requestCount, 0)
        XCTAssertEqual(state.recoveryAttempts, 1)
        XCTAssertEqual(state.events.first, "recover",
            "The exact later failed connection must recover before observation")
        let initialState = await initialConfiguration.state()
        XCTAssertEqual(initialState.requestCount, 1,
            "Replay and recovery must not repeat the original deletion")
        let saved = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(saved.profileCleanupReceipt?.helperClosureState, .verified)
    }

    func testFreshConfigurationCannotClaimOriginalFailedConnectionWasFinalized() async throws {
        let fixture = try cleanupFixture()
        let original = RecordingConfiguration(
            observations: [fixture.observation], finishFailure: .unavailable)
        let originalCoordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: original)
        let first = try await originalCoordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        XCTAssertFalse(first.configurationFinalized)

        let fresh = RecordingConfiguration(observations: [fixture.absentReadback])
        let freshCoordinator = ProjectExecutionProfileCleanupCoordinator(
            root: { fixture.root }, configuration: fresh)
        let replay = try await freshCoordinator.cleanupRun(
            project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        guard case .replayed = try XCTUnwrap(replay.outcomes.first).kind else {
            return XCTFail("A fresh adapter may observe the retained known effect without repeating it")
        }
        XCTAssertFalse(replay.configurationFinalized,
            "Closing a new helper cannot prove the original failed connection closed")
        let freshState = await fresh.state()
        XCTAssertEqual(freshState.requestCount, 0)
        let saved = try fixture.store.assignment(
            projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertNotEqual(saved.profileCleanupReceipt?.helperClosureState, .verified)
        XCTAssertTrue(saved.profileCleanupReceipt?.finalizationPending == true)
    }

    func testPartialResumeChainsVerifiedAfterVersionBeforeAttemptingPendingTarget() async throws {
        let fixture = try cleanupFixture()
        var first = fixture.assignment
        first.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: first.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(first.permissionProfileDefinition),
            targetIndex: 0, targetCount: 2, attemptedConfigurationVersion: "before-v1",
            state: .removalVerified, acknowledgement: .acknowledged,
            observedTargetPresence: .absent, observedConfigurationVersion: "after-v2")
        try fixture.store.saveAssignment(first, expected: fixture.assignment)
        let second = try saveAdditionalAssignment(fixture: fixture, id: "review-cleanup", profileID: "rr-review-cleanup")
        let confirmation = confirmation(fixture: fixture, assignments: [fixture.assignment, second])
        var pendingSecond = second
        pendingSecond.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: second.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(second.permissionProfileDefinition),
            targetIndex: 1, targetCount: 2)
        try fixture.store.saveAssignment(pendingSecond, expected: second)
        let observation = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "after-v2", observedAt: Date(), entries: [
                .init(profileID: second.permissionProfile, observedDefinition: try XCTUnwrap(second.permissionProfileDefinition)),
            ])
        let configuration = RecordingConfiguration(observations: [observation], resultingVersions: [second.permissionProfile: "after-v3"])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: confirmation, beforeWrite: {})

        XCTAssertEqual(outcomes.count, 2)
        guard case .replayed = outcomes[0].kind, case .removed = outcomes[1].kind else {
            return XCTFail("Expected verified replay followed by the pending removal")
        }
        let requests = await configuration.requests
        XCTAssertEqual(requests.map(\.profileID), [second.permissionProfile])
        XCTAssertEqual(requests.first?.configurationVersion, "after-v2")
    }

    func testPartialResumeRefusesUnrelatedVersionDriftWithoutWritingPendingTarget() async throws {
        let fixture = try cleanupFixture()
        var first = fixture.assignment
        first.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: first.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(first.permissionProfileDefinition),
            targetIndex: 0, targetCount: 2, attemptedConfigurationVersion: "before-v1",
            state: .removalVerified, acknowledgement: .acknowledged,
            observedTargetPresence: .absent, observedConfigurationVersion: "after-v2")
        try fixture.store.saveAssignment(first, expected: fixture.assignment)
        let second = try saveAdditionalAssignment(fixture: fixture, id: "review-cleanup", profileID: "rr-review-cleanup")
        let confirmation = confirmation(fixture: fixture, assignments: [fixture.assignment, second])
        var pendingSecond = second
        pendingSecond.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: second.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(second.permissionProfileDefinition),
            targetIndex: 1, targetCount: 2)
        try fixture.store.saveAssignment(pendingSecond, expected: second)
        let drifted = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "unrelated-v9", observedAt: Date(), entries: [
                .init(profileID: second.permissionProfile, observedDefinition: try XCTUnwrap(second.permissionProfileDefinition)),
            ])
        let configuration = RecordingConfiguration(observations: [drifted])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: confirmation, beforeWrite: {})

        XCTAssertEqual(outcomes.count, 2)
        guard case .replayed = outcomes[0].kind, case .conflict = outcomes[1].kind else {
            return XCTFail("Unrelated drift must preserve the verified result and refuse the pending write")
        }
        let requests = await configuration.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testIntentRecordedWithFreshAbsenceIsUnattributedAndNotVerified() async throws {
        let fixture = try cleanupFixture()
        var pending = fixture.assignment
        pending.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: pending.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(pending.permissionProfileDefinition))
        try fixture.store.saveAssignment(pending, expected: fixture.assignment)
        let configuration = RecordingConfiguration(observations: [fixture.absentReadback])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        guard case .observedAbsentUnattributed = try XCTUnwrap(outcomes.first).kind else {
            return XCTFail("Intent plus absence must not claim causation")
        }
        let requests = await configuration.requests
        XCTAssertTrue(requests.isEmpty)
        let saved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        XCTAssertEqual(saved.profileCleanupReceipt?.state, .intentRecorded)
        XCTAssertEqual(saved.profileCleanupReceipt?.observedTargetPresence, .absent)
    }

    func testFreshAbsenceWithoutReceiptIsSkippedWithoutWriting() async throws {
        let fixture = try cleanupFixture()
        let configuration = RecordingConfiguration(observations: [fixture.absentReadback])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})

        guard case .skipped = try XCTUnwrap(outcomes.first).kind else { return XCTFail("Unattributed absence must be skipped") }
        let requests = await configuration.requests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertNil(try fixture.store.assignment(projectID: fixture.project.projectID.rawValue,
            taskID: fixture.assignment.id).profileCleanupReceipt)
    }

    func testOutcomeUnknownPresentRetriesOnlyAtExactReceiptVersion() async throws {
        let fixture = try cleanupFixture()
        var pending = fixture.assignment
        pending.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: pending.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(pending.permissionProfileDefinition),
            state: .outcomeUnknown, acknowledgement: .unknown, observedTargetPresence: .present)
        try fixture.store.saveAssignment(pending, expected: fixture.assignment)
        let retry = RecordingConfiguration(observations: [fixture.observation])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: retry)
        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        guard case .removed = try XCTUnwrap(outcomes.first).kind else { return XCTFail("Exact unchanged state should retry") }
        let retryVersions = await retry.requests.map(\.configurationVersion)
        XCTAssertEqual(retryVersions, ["before-v1"])

        try fixture.store.saveAssignment(pending,
            expected: try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id))
        let driftedObservation = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "unrelated-v9", observedAt: Date(), entries: fixture.observation.entries)
        let drift = RecordingConfiguration(observations: [driftedObservation])
        let driftCoordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: drift)
        let driftOutcomes = try await driftCoordinator.cleanup(project: fixture.project, confirmation: fixture.confirmation, beforeWrite: {})
        guard case .conflict = try XCTUnwrap(driftOutcomes.first).kind else { return XCTFail("Drift must block retry") }
        let driftRequests = await drift.requests
        XCTAssertTrue(driftRequests.isEmpty)
    }

    func testMixedBatchRetainsPriorRemovalAndMarksLaterFailureUnresolved() async throws {
        let fixture = try cleanupFixture()
        let second = try saveAdditionalAssignment(fixture: fixture, id: "review-cleanup", profileID: "rr-review-cleanup")
        let confirmation = confirmation(fixture: fixture, assignments: [fixture.assignment, second])
        let observation = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", observedAt: Date(), entries: [
                .init(profileID: fixture.assignment.permissionProfile,
                      observedDefinition: try XCTUnwrap(fixture.assignment.permissionProfileDefinition)),
                .init(profileID: second.permissionProfile, observedDefinition: try XCTUnwrap(second.permissionProfileDefinition)),
            ])
        let configuration = RecordingConfiguration(observations: [observation],
            removalErrorsByProfile: [second.permissionProfile: .unavailable],
            resultingVersions: [fixture.assignment.permissionProfile: "after-v2"])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: confirmation, beforeWrite: {})

        XCTAssertEqual(outcomes.count, 2)
        guard case .removed = outcomes[0].kind, case .unresolved = outcomes[1].kind else {
            return XCTFail("A later uncertainty must not erase the prior verified outcome")
        }
        let requestedProfiles = await configuration.requests.map(\.profileID)
        XCTAssertEqual(requestedProfiles,
            [fixture.assignment.permissionProfile, second.permissionProfile])
        let firstSaved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: fixture.assignment.id)
        let secondSaved = try fixture.store.assignment(projectID: fixture.project.projectID.rawValue, taskID: second.id)
        XCTAssertEqual(firstSaved.profileCleanupReceipt?.state, .removalVerified)
        XCTAssertTrue(firstSaved.profileCleanupReceipt?.finalizationPending == true)
        XCTAssertEqual(secondSaved.profileCleanupReceipt?.state, .outcomeUnknown)
    }

    func testRestartRecoversCompleteImmutableConfirmationAndResumesThroughOrdinaryCleanup() async throws {
        let fixture = try cleanupFixture()
        let second = try saveAdditionalAssignment(fixture: fixture, id: "review-cleanup", profileID: "rr-review-cleanup")
        let assignments = [fixture.assignment, second]
        let confirmedTargets = confirmation(fixture: fixture, assignments: assignments).targets
        for (index, baseline) in assignments.enumerated() {
            var pending = baseline
            pending.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
                profileID: baseline.permissionProfile, selectedCodexContextID: fixture.contextID,
                configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(baseline.permissionProfileDefinition),
                targetIndex: index, targetCount: assignments.count,
                attemptedConfigurationVersion: index == 0 ? "before-v1" : nil,
                confirmedTargets: confirmedTargets,
                state: .intentRecorded, acknowledgement: .notAttempted, observedTargetPresence: .present)
            try fixture.store.saveAssignment(pending, expected: baseline)
        }
        let observation = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", observedAt: Date(), entries: try assignments.map {
                .init(profileID: $0.permissionProfile, observedDefinition: try XCTUnwrap($0.permissionProfileDefinition))
            })
        let configuration = RecordingConfiguration(observations: [observation],
            resultingVersions: [fixture.assignment.permissionProfile: "after-v2", second.permissionProfile: "after-v3"])
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root }, configuration: configuration)

        let recovered = try await coordinator.recoverableConfirmations(project: fixture.project)

        XCTAssertEqual(recovered.count, 1)
        let confirmation = try XCTUnwrap(recovered.first)
        XCTAssertEqual(confirmation.requestID, fixture.confirmation.requestID)
        XCTAssertEqual(confirmation.selectedCodexContextID, fixture.contextID)
        XCTAssertEqual(confirmation.configurationVersion, "before-v1")
        XCTAssertEqual(confirmation.targets.map(\.profileID), assignments.map(\.permissionProfile))
        XCTAssertEqual(confirmation.targets.map(\.expectedDefinition), assignments.compactMap(\.permissionProfileDefinition))
        XCTAssertEqual(confirmation.targets.map { baselineWithoutReceipt($0.assignmentBaseline) },
            assignments.map(baselineWithoutReceipt))

        let outcomes = try await coordinator.cleanup(project: fixture.project, confirmation: confirmation, beforeWrite: {})
        XCTAssertEqual(outcomes.count, 2)
        let requestedProfiles = await configuration.requests.map(\.profileID)
        XCTAssertEqual(requestedProfiles, assignments.map(\.permissionProfile))
    }

    func testRestartRejectsIncompleteOrMismatchedReceiptGroupInsteadOfConstructingPartialConfirmation() async throws {
        let fixture = try cleanupFixture()
        var incomplete = fixture.assignment
        incomplete.profileCleanupReceipt = .init(requestID: fixture.confirmation.requestID,
            profileID: incomplete.permissionProfile, selectedCodexContextID: fixture.contextID,
            configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(incomplete.permissionProfileDefinition),
            targetIndex: 0, targetCount: 2, attemptedConfigurationVersion: "before-v1")
        try fixture.store.saveAssignment(incomplete, expected: fixture.assignment)
        let coordinator = ProjectExecutionProfileCleanupCoordinator(root: { fixture.root },
            configuration: RecordingConfiguration(observations: []))

        do {
            _ = try await coordinator.recoverableConfirmations(project: fixture.project)
            XCTFail("An incomplete receipt group must not create partial authority")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .conflict)
        }

        let mismatched = try cleanupFixture()
        let second = try saveAdditionalAssignment(fixture: mismatched, id: "review-cleanup", profileID: "rr-review-cleanup")
        for baseline in [mismatched.assignment, second] {
            var duplicateIndex = baseline
            duplicateIndex.profileCleanupReceipt = .init(requestID: mismatched.confirmation.requestID,
                profileID: baseline.permissionProfile, selectedCodexContextID: mismatched.contextID,
                configurationVersion: "before-v1", expectedDefinition: try XCTUnwrap(baseline.permissionProfileDefinition),
                targetIndex: 0, targetCount: 2)
            try mismatched.store.saveAssignment(duplicateIndex, expected: baseline)
        }
        let mismatchCoordinator = ProjectExecutionProfileCleanupCoordinator(root: { mismatched.root },
            configuration: RecordingConfiguration(observations: []))
        do {
            _ = try await mismatchCoordinator.recoverableConfirmations(project: mismatched.project)
            XCTFail("Duplicate target indexes must not create recovery authority")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .conflict)
        }
    }

    private func terminalAssignment() -> ProjectExecutionAssignment {
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"),
            registrationID: "registration-project-one", requestGeneration: 1)
        var assignment = ProjectExecutionAssignment(id: "delivery-cleanup", registration: registration,
            checkoutPath: "/Worktrees/project-one/delivery-cleanup", role: .delivery,
            permissionProfile: "rr-delivery-cleanup", model: "gpt-5.6-terra", effort: "medium",
            authorization: "Approved work", context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], state: .closed,
            worktree: .init(checkout: "/Worktrees/project-one/delivery-cleanup", baseline: String(repeating: "a", count: 40),
                branch: "codex/project-one-delivery-cleanup", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary"))
        assignment.codexContextID = UUID()
        assignment.permissionProfileDefinition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        assignment.profileProvisioningReceipt = .init(state: .verified, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1), verifiedAt: Date(timeIntervalSinceReferenceDate: 2))
        assignment.connectionClosed = true
        assignment.launchReserved = true
        assignment.workerAttemptID = UUID()
        assignment.sessionID = "closed-session"
        return assignment
    }

    private func baselineWithoutReceipt(_ assignment: ProjectExecutionAssignment) -> ProjectExecutionAssignment {
        var value = assignment
        value.profileCleanupReceipt = nil
        return value
    }

    private func cleanupFixture() throws -> (root: URL, store: ProjectExecutionFileStore, project: AuthorizedProject,
        assignment: ProjectExecutionAssignment, contextID: UUID, confirmation: ProjectExecutionProfileCleanupConfirmation,
        observation: ProjectExecutionWorkerProfileObservation, absentReadback: ProjectExecutionWorkerProfileObservation) {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let projectRoot = root.appendingPathComponent("Project")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let store = try ProjectExecutionFileStore(root: root.appendingPathComponent("Execution"), create: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let context = try CodexExecutionContext(home: store.root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: projectRoot.path,
            appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/RR/handler")
        policy.codexContextID = context.id
        try store.savePolicy(policy, expected: nil)
        var assignment = terminalAssignment()
        assignment = ProjectExecutionAssignment(id: assignment.id, registration: registration,
            checkoutPath: assignment.checkoutPath, role: assignment.role, permissionProfile: assignment.permissionProfile,
            model: assignment.model, effort: assignment.effort, authorization: assignment.authorization, context: assignment.context,
            excludedPaths: assignment.excludedPaths, state: assignment.state, sessionID: assignment.sessionID, worktree: assignment.worktree)
        assignment.codexContextID = context.id
        assignment.permissionProfileDefinition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        assignment.profileProvisioningReceipt = .init(state: .verified, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1), verifiedAt: Date(timeIntervalSinceReferenceDate: 2))
        assignment.connectionClosed = true; assignment.launchReserved = true; assignment.workerAttemptID = UUID()
        try store.saveAssignment(assignment, expected: nil)
        let target = ProjectExecutionProfileCleanupConfirmation.Target(profileID: assignment.permissionProfile,
            assignmentID: assignment.id, expectedDefinition: try XCTUnwrap(assignment.permissionProfileDefinition), assignmentBaseline: assignment)
        let confirmation = ProjectExecutionProfileCleanupConfirmation(requestID: UUID(), registration: registration,
            selectedCodexContextID: context.id, configurationVersion: "before-v1", targets: [target])
        let observation = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: context.id, configurationVersion: "before-v1",
            observedAt: Date(), entries: [.init(profileID: assignment.permissionProfile, observedDefinition: try XCTUnwrap(assignment.permissionProfileDefinition))])
        let absentReadback = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: context.id, configurationVersion: "after-v2",
            observedAt: Date(), entries: [])
        return (store.root, store, .init(registration: registration, canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
            assignment, context.id, confirmation, observation, absentReadback)
    }

    private func saveAdditionalAssignment(
        fixture: (root: URL, store: ProjectExecutionFileStore, project: AuthorizedProject,
            assignment: ProjectExecutionAssignment, contextID: UUID,
            confirmation: ProjectExecutionProfileCleanupConfirmation,
            observation: ProjectExecutionWorkerProfileObservation,
            absentReadback: ProjectExecutionWorkerProfileObservation),
        id: String, profileID: String
    ) throws -> ProjectExecutionAssignment {
        let checkout = fixture.root.appendingPathComponent("Worktrees/project-one/\(id)").path
        var assignment = ProjectExecutionAssignment(id: id, registration: fixture.assignment.registration,
            checkoutPath: checkout, role: .review, permissionProfile: profileID,
            model: fixture.assignment.model, effort: fixture.assignment.effort,
            authorization: fixture.assignment.authorization, context: fixture.assignment.context,
            excludedPaths: fixture.assignment.excludedPaths, state: .closed, sessionID: "closed-\(id)",
            worktree: .init(checkout: checkout, baseline: String(repeating: "b", count: 40),
                branch: "codex/project-one-\(id)", commonGitDirectory: "/Primary/.git", primaryRoot: "/Primary"))
        assignment.codexContextID = fixture.contextID
        assignment.permissionProfileDefinition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        assignment.profileProvisioningReceipt = .init(state: .verified, provenance: .newlyPrepared,
            requestedAt: Date(timeIntervalSinceReferenceDate: 1), verifiedAt: Date(timeIntervalSinceReferenceDate: 2))
        assignment.connectionClosed = true
        assignment.launchReserved = true
        assignment.workerAttemptID = UUID()
        try fixture.store.saveAssignment(assignment, expected: nil)
        return assignment
    }

    private func confirmation(
        fixture: (root: URL, store: ProjectExecutionFileStore, project: AuthorizedProject,
            assignment: ProjectExecutionAssignment, contextID: UUID,
            confirmation: ProjectExecutionProfileCleanupConfirmation,
            observation: ProjectExecutionWorkerProfileObservation,
            absentReadback: ProjectExecutionWorkerProfileObservation),
        assignments: [ProjectExecutionAssignment]
    ) -> ProjectExecutionProfileCleanupConfirmation {
        .init(requestID: fixture.confirmation.requestID, registration: fixture.assignment.registration,
            selectedCodexContextID: fixture.contextID, configurationVersion: fixture.confirmation.configurationVersion,
            targets: assignments.map { assignment in
                .init(profileID: assignment.permissionProfile, assignmentID: assignment.id,
                    expectedDefinition: assignment.permissionProfileDefinition!, assignmentBaseline: assignment)
            })
    }

    private actor RecordingConfiguration: ProjectExecutionConfiguring {
        private var pendingObservations: [ProjectExecutionWorkerProfileObservation]
        private let removalError: ProjectExecutionError?
        private let removalErrorsByProfile: [String: ProjectExecutionError]
        private let resultingVersions: [String: String]
        private let profileExists: Bool
        private let finishFailure: ProjectExecutionError?
        private let finishFailuresByAttempt: [Int: ProjectExecutionError]
        private let recoveryFailure: ProjectExecutionError?
        private var recoveredConnection = false
        private var retainedConnectionFailure = false
        private var finishAttempts = 0
        private(set) var requests = [ProjectExecutionConfirmedProfileRemoval]()
        private var recoveryAttempts = 0
        private var events = [String]()

        init(observations: [ProjectExecutionWorkerProfileObservation], removalError: ProjectExecutionError? = nil,
             profileExists: Bool = false, finishFailure: ProjectExecutionError? = nil,
             finishFailuresByAttempt: [Int: ProjectExecutionError] = [:],
             recoveryFailure: ProjectExecutionError? = nil,
             removalErrorsByProfile: [String: ProjectExecutionError] = [:],
             resultingVersions: [String: String] = [:]) {
            pendingObservations = observations; self.removalError = removalError
            self.profileExists = profileExists; self.finishFailure = finishFailure
            self.finishFailuresByAttempt = finishFailuresByAttempt
            self.recoveryFailure = recoveryFailure
            self.removalErrorsByProfile = removalErrorsByProfile; self.resultingVersions = resultingVersions
        }
        func selectedCodexContextID() async throws -> UUID? {
            pendingObservations.first?.selectedCodexContextID
        }
        func useCodexContext(_ expected: UUID?) async throws {}
        func validateInstallation(handlerPath: String) async throws {}
        func sharedExecutionSkill() async throws -> ProjectExecutionSharedExecutionSkill { throw ProjectExecutionError.unavailable }
        func validateHandlerIdentity(handlerPath: String) async throws {}
        func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage { .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {}
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws {}
        func finishConfiguration() async throws {
            events.append("finish")
            finishAttempts += 1
            if let failure = finishFailuresByAttempt[finishAttempts] {
                recoveredConnection = false
                retainedConnectionFailure = true
                throw failure
            }
            if let finishFailure, !recoveredConnection {
                retainedConnectionFailure = true
                throw finishFailure
            }
        }
        func recoverConfigurationConnection() async throws {
            events.append("recover-unscoped")
        }
        func recoverRetainedConfigurationConnection() async throws -> Bool {
            events.append("recover")
            recoveryAttempts += 1
            guard retainedConnectionFailure else { return false }
            if let recoveryFailure { throw recoveryFailure }
            recoveredConnection = true
            retainedConnectionFailure = false
            return true
        }
        func resetEvents() { events = [] }
        func state() -> (requestCount: Int, recoveryAttempts: Int, events: [String]) {
            (requests.count, recoveryAttempts, events)
        }
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws {}
        func workerProfileExists(primaryRoot: String, profileID: String) async throws -> Bool { profileExists }
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws {}
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws {}
        func observeWorkerProfiles(primaryRoot: String) async throws -> ProjectExecutionWorkerProfileObservation {
            events.append("observe")
            guard !pendingObservations.isEmpty else { throw ProjectExecutionError.unavailable }
            return pendingObservations.removeFirst()
        }
        func removeConfirmedWorkerProfile(primaryRoot: String, request: ProjectExecutionConfirmedProfileRemoval,
                                          beforeWrite: @Sendable () async throws -> Void) async throws -> ProjectExecutionConfirmedProfileRemovalResult {
            events.append("remove")
            requests.append(request)
            try await beforeWrite()
            if let error = removalErrorsByProfile[request.profileID] { throw error }
            if let removalError { throw removalError }
            return .init(configurationVersion: resultingVersions[request.profileID] ?? "after-v2")
        }
    }
}
