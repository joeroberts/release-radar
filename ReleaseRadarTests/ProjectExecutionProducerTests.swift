import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionProducerTests: XCTestCase {
    actor Configuration: ProjectExecutionConfiguring {
        var failProfile = false
        var finishes = 0
        var profiles: [ProjectExecutionPermissionProfile] = []
        func validateInstallation(handlerPath: String) {}
        func hookStorage(primaryRoot: String) -> ProjectExecutionHookStorage { .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func finishConfiguration() { finishes += 1 }
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) throws {
            profiles.append(profile); if failProfile { throw ProjectExecutionError.hookNotReady }
        }
        func setFailure(_ value: Bool) { failProfile = value }
    }
    struct Provisioning: ExecutionWorktreeProvisioning {
        let source: URL
        let candidate: URL?
        func revision(at root: URL, requireClean: Bool) -> String { String(repeating: "a", count: 40) }
        func candidateRevision(worktree: ExecutionWorktree) -> String {
            String(repeating: candidate?.path == worktree.checkout ? "b" : "a", count: 40)
        }
        func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String, baseline: String) throws -> ExecutionWorktree {
            try FileManager.default.createDirectory(at: checkout.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: baseline == String(repeating: "b", count: 40) ? candidate! : source, to: checkout)
            return .init(checkout: checkout.path, baseline: baseline, branch: "codex/rr-\(projectID)-\(taskID)", commonGitDirectory: primaryRoot.path + "/.git", primaryRoot: primaryRoot.path)
        }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String, taskID: String) throws { throw ProjectExecutionError.unavailable }
    }
    private let handler = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator"
    private final class CleanupProvisioning: ExecutionWorktreeProvisioning, @unchecked Sendable {
        var removals = 0
        var dirty = false
        func revision(at root: URL, requireClean: Bool) -> String { String(repeating: "a", count: 40) }
        func candidateRevision(worktree: ExecutionWorktree) -> String { worktree.baseline }
        func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String, baseline: String) throws -> ExecutionWorktree { throw ProjectExecutionError.unavailable }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String, taskID: String) throws {
            if dirty { throw ProjectExecutionError.conflict }; removals += 1
        }
    }
    private actor CleanupConfiguration: ProjectExecutionConfiguring {
        var removedProfiles: [String] = []
        var conflict = false
        var connectionOpen = false
        var closeFails = false
        let connectionIdentity = UUID()
        var closedConnections: [UUID] = []
        func setConflict(_ value: Bool) { conflict = value }
        func setCloseFailure(_ value: Bool) { closeFails = value }
        func validateInstallation(handlerPath: String) {}
        func hookStorage(primaryRoot: String) -> ProjectExecutionHookStorage { .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func finishConfiguration() async throws {
            if connectionOpen {
                closedConnections.append(connectionIdentity)
                if closeFails { throw ProjectExecutionError.unavailable }
                connectionOpen = false
            }
        }
        func recoverConfigurationConnection() async throws { try await finishConfiguration() }
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) {}
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws {
            connectionOpen = true
            if conflict { throw ProjectExecutionError.conflict }; removedProfiles.append(profileID)
        }
    }
    private func cleanupAssignment(store: ProjectExecutionFileStore, project: AuthorizedProject, work: ProjectExecutionWork,
                                   state: ProjectExecutionAssignment.State, closed: Bool) throws -> ProjectExecutionAssignment {
        let paths = try ProjectExecutionPaths(storageRoot: store.root, projectID: project.projectID.rawValue, taskID: "delivery-cleanup")
        var value = ProjectExecutionAssignment(id: "delivery-cleanup", registration: project.registration!, checkoutPath: paths.checkout.path,
            role: .delivery, permissionProfile: "rr-delivery-cleanup", model: "gpt-5.6-terra", effort: "medium", authorization: "Approved work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))], excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: state, sessionID: "session-cleanup", worktree: .init(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-project-one-delivery-cleanup", commonGitDirectory: project.canonicalRoot.path + "/.git", primaryRoot: project.canonicalRoot.path), work: work)
        value.connectionClosed = closed; value.launchReserved = true
        if state == .unknown { value.uncertainOutcome = true }
        try store.saveAssignment(value, expected: nil); return value
    }

    func testOwnerRetirementPreservesUnknownOutcomeAndAllowsOnlyExplicitReplacement() async throws {
        let (root, source, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .unknown, closed: true)
        let configuration = CleanupConfiguration(); let provisioning = CleanupProvisioning()
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Unretired unknown outcome must block replacement") } catch {}
        let request = UUID()
        let retired = try await lifecycle.retire(project: project, expected: value, requestID: request)
        XCTAssertEqual(retired.state, .superseded); XCTAssertEqual(retired.uncertainOutcome, true)
        XCTAssertEqual(retired.retirement?.priorState, .unknown); XCTAssertEqual(retired.retirement?.requestID, request)
        XCTAssertEqual(retired.retirement?.completed, true); XCTAssertEqual(provisioning.removals, 1)
        let profiles = await configuration.removedProfiles; XCTAssertEqual(profiles, [value.permissionProfile])
        XCTAssertThrowsError(try retired.admit(registration: value.registration, checkoutPath: value.checkoutPath, sessionID: "session-cleanup", boundSessionID: "session-cleanup"))
        let replacement = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(replacement.state, .preparing); XCTAssertNotEqual(replacement.id, retired.id)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: retired.id).uncertainOutcome, true)
    }

    func testRetirementRefusesUnclosedRuntimeDirtyCheckoutAndReferencedCandidate() async throws {
        let (root, _, project, work, store) = try fixture()
        var value = try cleanupAssignment(store: store, project: project, work: work, state: .stopped, closed: false)
        let configuration = CleanupConfiguration(); let provisioning = CleanupProvisioning()
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        do { _ = try await lifecycle.retire(project: project, expected: value, requestID: UUID()); XCTFail("Open runtime must block cleanup") } catch {}
        XCTAssertEqual(provisioning.removals, 0)
        var closed = value; closed.connectionClosed = true; try store.saveAssignment(closed, expected: value); value = closed
        provisioning.dirty = true
        do { _ = try await lifecycle.retire(project: project, expected: value, requestID: UUID()); XCTFail("Dirty checkout must be preserved") } catch {}
        XCTAssertEqual(provisioning.removals, 0)
        let profiles = await configuration.removedProfiles; XCTAssertTrue(profiles.isEmpty)
        let pending = try store.assignment(projectID: "project-one", taskID: value.id)
        var review = ProjectExecutionAssignment(id: "review-dependent", registration: value.registration, checkoutPath: value.checkoutPath,
            role: .review, permissionProfile: "rr-review", model: value.model, effort: "high", authorization: value.authorization,
            context: value.context, excludedPaths: value.excludedPaths, worktree: value.worktree, work: work, reviewOfAssignmentID: value.id)
        review.state = .preparing; try store.saveAssignment(review, expected: nil)
        provisioning.dirty = false
        do { _ = try await lifecycle.retire(project: project, expected: pending, requestID: pending.retirement!.requestID); XCTFail("Referenced candidate must remain available") } catch {}
        XCTAssertEqual(provisioning.removals, 0)
    }

    func testProfileConflictRetainsExactPendingCleanupAndRetryDoesNotRepeatWorktreeRemoval() async throws {
        let (root, _, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .revoked, closed: true)
        let configuration = CleanupConfiguration(); await configuration.setConflict(true)
        let provisioning = CleanupProvisioning()
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        let request = UUID()
        do { _ = try await lifecycle.retire(project: project, expected: value, requestID: request); XCTFail("Edited profile must be preserved") } catch {}
        let pending = try store.assignment(projectID: "project-one", taskID: value.id)
        XCTAssertEqual(pending.state, .revoked); XCTAssertEqual(pending.retirement?.worktreeRemoved, true)
        XCTAssertEqual(pending.retirement?.completed, false)
        do { _ = try await lifecycle.retire(project: project, expected: pending, requestID: UUID()); XCTFail("Different request cannot replace cleanup intent") } catch {}
        await configuration.setConflict(false)
        let retired = try await lifecycle.retire(project: project, expected: pending, requestID: request)
        XCTAssertEqual(retired.state, .superseded); XCTAssertEqual(retired.retirement?.priorState, .revoked)
        XCTAssertEqual(provisioning.removals, 1)
    }

    func testUncertainConfigurationCloseRetainsVisibleExactReceiptAndSameConnectionUntilRetry() async throws {
        let (root, source, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .revoked, closed: true)
        let configuration = CleanupConfiguration(); await configuration.setCloseFailure(true)
        let provisioning = CleanupProvisioning()
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        let request = UUID()
        do { _ = try await lifecycle.retire(project: project, expected: value, requestID: request); XCTFail("Unconfirmed close cannot finish retirement") } catch {}
        let pending = try store.assignment(projectID: "project-one", taskID: value.id)
        XCTAssertEqual(pending.state, .revoked); XCTAssertEqual(pending.retirement?.completed, false)
        XCTAssertEqual(pending.retirement?.connectionCloseUncertain, true)
        let visible = try await lifecycle.assignments(project: project).filter { $0.retirement?.completed != true }
        XCTAssertTrue(visible.contains { $0.id == value.id })
        // Production owns separate configuration clients for producer and retirement.
        let producerConfiguration = Configuration()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: producerConfiguration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Replacement remains blocked") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
        let producerCloses = await producerConfiguration.finishes; XCTAssertEqual(producerCloses, 1)
        let lostHandle = ProjectExecutionResourceLifecycle(root: { root }, configuration: CleanupConfiguration(), provisioning: provisioning)
        do { _ = try await lostHandle.retire(project: project, expected: pending, requestID: request); XCTFail("New client cannot confirm the original connection") } catch {}
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: value.id), pending)
        let initialCloses = await configuration.closedConnections; XCTAssertEqual(initialCloses.count, 1)
        do { _ = try await lifecycle.retire(project: project, expected: pending, requestID: UUID()); XCTFail("Different request cannot recover the held connection") } catch {}
        let unchangedCloses = await configuration.closedConnections; XCTAssertEqual(unchangedCloses, initialCloses)
        await configuration.setCloseFailure(false)
        let retired = try await lifecycle.retire(project: project, expected: pending, requestID: request)
        XCTAssertEqual(retired.state, .superseded); XCTAssertEqual(retired.retirement?.completed, true)
        XCTAssertEqual(retired.retirement?.connectionCloseUncertain, false)
        let closes = await configuration.closedConnections; XCTAssertEqual(closes.count, 2); XCTAssertEqual(Set(closes).count, 1)
        XCTAssertEqual(provisioning.removals, 1)
        let profiles = await configuration.removedProfiles; XCTAssertEqual(profiles.count, 1)
        let replacement = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(replacement.state, .preparing)
    }
    private func fixture() throws -> (URL, URL, AuthorizedProject, ProjectExecutionWork, ProjectExecutionFileStore) {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let source = base.appendingPathComponent("Repository")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("Current approved instructions".utf8).write(to: source.appendingPathComponent("AGENTS.md"))
        let root = base.appendingPathComponent("Execution")
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: source.path, appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handler)
        policy.consent = .init(); policy.hookReceipt = .init(command: "\"" + handler + "\" --hook", inline: false, beforeDigest: nil, intendedDigest: String(repeating: "a", count: 64), installed: true)
        try store.savePolicy(policy, expected: nil)
        let work = ProjectExecutionWork(projectID: registration.projectID, ticketID: "ticket-one", taskID: "work-one", outcome: "Bounded outcome", title: "Approved task", taskPlanRevision: 1, phaseID: "phase-one", phaseRevision: 2)
        return (root, source, .init(registration: registration, canonicalRoot: source, authorizedRoots: [source]), work, store)
    }

    func testFailedProfilePreparationResumesSameAssignmentWithoutAuthorizingLaunch() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration(); await configuration.setFailure(true)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let request = UUID()
        do { _ = try await producer.prepare(project: project, work: work, requestID: request, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Failed setup must remain pending") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .hookNotReady) }
        let pending = try XCTUnwrap(store.assignments(projectID: "project-one").first)
        XCTAssertEqual(pending.state, .preparing)
        await configuration.setFailure(false)
        let resumed = try await producer.prepare(project: project, work: work, requestID: request, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(resumed.id, pending.id); XCTAssertEqual(resumed.state, .preparing)
        XCTAssertThrowsError(try resumed.admit(registration: project.registration!, checkoutPath: resumed.checkoutPath, sessionID: "session", boundSessionID: "session"))
        let admitted = try producer.admitPrepared(resumed)
        XCTAssertEqual(admitted.state, .authorized)
        XCTAssertEqual(try store.assignments(projectID: "project-one").count, 1)
        let finishes = await configuration.finishes; XCTAssertEqual(finishes, 2)
    }

    func testIndependentReviewUsesClosedDeliveryCandidateNotPrimaryHeadOrTaskCompletion() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let deliveryProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let delivery = try await deliveryProducer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        let admitted = try deliveryProducer.admitPrepared(delivery)
        var closed = admitted; closed.state = .closed; closed.sessionID = "author-session"
        try store.saveAssignment(closed, expected: admitted)
        let candidate = URL(fileURLWithPath: delivery.checkoutPath)
        let reviewProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: candidate))
        let review = try await reviewProducer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: closed.id, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(review.role, .review); XCTAssertEqual(review.worktree?.baseline, String(repeating: "b", count: 40))
        XCTAssertNotEqual(review.checkoutPath, delivery.checkoutPath); XCTAssertNil(review.sessionID)
        XCTAssertEqual(review.reviewOfAssignmentID, delivery.id)
        let profiles = await configuration.profiles
        XCTAssertEqual(profiles.last?.workspace["."], "read")
    }

    func testFreshRequestCannotReplaceUnknownLaunchOrReviewLiveWriter() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let delivery = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: delivery.id, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Live writer must not become a review candidate") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .assignmentNotAuthorized) }
        var unknown = delivery; unknown.state = .unknown
        try store.saveAssignment(unknown, expected: delivery)
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("A new request must not replace an unknown launch") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
        XCTAssertEqual(try store.assignments(projectID: "project-one").count, 1)
    }

    func testRevokedFinalizationCanResumeOnlyExactUnlaunchedRequest() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let request = UUID()
        let prepared = try await producer.prepare(project: project, work: work, requestID: request, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        try producer.revokePreparation(prepared)
        let revoked = try store.assignment(projectID: "project-one", taskID: prepared.id)
        XCTAssertEqual(revoked.state, .revoked)
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("A different request cannot replace failed finalization") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
        let resumed = try await producer.prepare(project: project, work: work, requestID: request, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(resumed.id, prepared.id); XCTAssertEqual(resumed.state, .preparing)
    }
}
