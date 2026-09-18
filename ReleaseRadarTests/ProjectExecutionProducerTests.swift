import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionProducerTests: XCTestCase {
    actor Configuration: ProjectExecutionConfiguring {
        func selectedCodexContextID() async -> UUID? { nil }
        func useCodexContext(_ expected: UUID?) async {}
        var failProfile = false
        var requireProjectLayer = false
        var rejectHook = false
        var hookChecks = 0
        var afterProfile: (@Sendable () throws -> Void)?
        var finishes = 0
        var profiles: [ProjectExecutionPermissionProfile] = []
        func validateInstallation(handlerPath: String) {}
        func hookStorage(primaryRoot: String) -> ProjectExecutionHookStorage { .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws {
            hookChecks += 1
            if requireProjectLayer {
                var directory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: checkout + "/.codex", isDirectory: &directory), directory.boolValue,
                      !permitOwnedTrust else { throw ProjectExecutionError.hookNotReady }
            }
            if rejectHook { throw ProjectExecutionError.hookNotReady }
            try await beforeWrite()
        }
        func requireLayer(rejectHook: Bool = false) { requireProjectLayer = true; self.rejectHook = rejectHook }
        func finishConfiguration() { finishes += 1 }
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) throws {
            profiles.append(profile); if failProfile { throw ProjectExecutionError.hookNotReady }
            try afterProfile?()
        }
        func setFailure(_ value: Bool) { failProfile = value }
        func onProfile(_ action: @escaping @Sendable () throws -> Void) { afterProfile = action }
    }
    struct Provisioning: ExecutionWorktreeProvisioning {
        let source: URL
        let candidate: URL?
        func revision(at root: URL, requireClean: Bool) -> String { String(repeating: "a", count: 40) }
        func candidateRevision(worktree: ExecutionWorktree) -> String {
            candidate?.path == worktree.checkout ? String(repeating: "b", count: 40) : worktree.baseline
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
        func selectedCodexContextID() async -> UUID? { nil }
        var refuseContext = false
        func useCodexContext(_ expected: UUID?) async throws { if refuseContext { throw CodexExecutionContextError.changed } }
        func setContextRefusal(_ value: Bool) { refuseContext = value }
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

    func testRetirementContextLossPreservesOwnedCheckoutProfileAndRequestState() async throws {
        let (root, _, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .stopped, closed: true)
        let configuration = CleanupConfiguration(); await configuration.setContextRefusal(true)
        let provisioning = CleanupProvisioning()
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        do { _ = try await lifecycle.retire(project: project, expected: value, requestID: UUID()); XCTFail("Lost context must block cleanup") } catch {}
        XCTAssertEqual(provisioning.removals, 0)
        let profiles = await configuration.removedProfiles; XCTAssertTrue(profiles.isEmpty)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: value.id), value)
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
        do { _ = try await lostHandle.retire(project: project, expected: pending, requestID: UUID()); XCTFail("A different request cannot recover the original connection") } catch {}
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

    func testLostConfigurationHandleAllowsExplicitReplacementWithoutClaimingOldClosure() async throws {
        let (root, source, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .unknown, closed: true)
        let configuration = CleanupConfiguration(); await configuration.setCloseFailure(true)
        let provisioning = CleanupProvisioning()
        let original = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        let request = UUID()
        do { _ = try await original.retire(project: project, expected: value, requestID: request) } catch {}
        let pending = try store.assignment(projectID: "project-one", taskID: value.id)
        let replacementControl = ProjectExecutionResourceLifecycle(root: { root }, configuration: CleanupConfiguration(), provisioning: provisioning)
        let recovered = try await replacementControl.retire(project: project, expected: pending, requestID: request)
        XCTAssertEqual(recovered.state, .unknown)
        XCTAssertEqual(recovered.retirement?.completed, false)
        XCTAssertEqual(recovered.retirement?.connectionCloseUncertain, true)
        XCTAssertEqual(recovered.retirement?.replacementAllowed, true)
        XCTAssertEqual(recovered.uncertainOutcome, true)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: Configuration(), handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let replacement = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(replacement.state, .preparing)
        XCTAssertNotEqual(replacement.id, recovered.id)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: value.id), recovered)
    }

    func testCurrentOwnerCanRetirePreviousGenerationWithoutGrantingItsOldLease() async throws {
        let (root, _, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .unknown, closed: true)
        let prior = try store.policy(projectID: "project-one")
        let registration = ProjectRegistration(projectID: project.projectID, registrationID: prior.registration.registrationID, requestGeneration: 2)
        var currentPolicy = ProjectExecutionPolicy(registration: registration, primaryRoot: prior.primaryRoot, appServerExecutable: prior.appServerExecutable, handlerPath: prior.handlerPath)
        currentPolicy.consent = prior.consent; currentPolicy.hookReceipt = prior.hookReceipt
        try store.savePolicy(currentPolicy, expected: prior)
        let current = AuthorizedProject(registration: registration, canonicalRoot: project.canonicalRoot, authorizedRoots: [project.canonicalRoot])
        let resources = ProjectExecutionResourceLifecycle(root: { root }, configuration: CleanupConfiguration(), provisioning: CleanupProvisioning())
        let visible = try await resources.assignments(project: current)
        XCTAssertTrue(visible.contains(value))
        let retired = try await resources.retire(project: current, expected: value, requestID: UUID())
        XCTAssertEqual(retired.registration, value.registration)
        XCTAssertEqual(retired.retirement?.completed, true)
        XCTAssertEqual(try store.policy(projectID: "project-one"), currentPolicy)
    }

    func testRelocatedOwnerRequiresExactOldRootGrantAndRetainsCurrentBinding() async throws {
        let (root, _, project, work, store) = try fixture()
        var value = try cleanupAssignment(store: store, project: project, work: work, state: .revoked, closed: true)
        let prior = try store.policy(projectID: "project-one")
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: value.id)
        let original = value; value.permissionProfileDefinition = try ProjectExecutionPermissionProfile(assignment: value, policy: prior, paths: paths).definition
        try store.saveAssignment(value, expected: original)
        let replacement = root.appendingPathComponent("Replacement")
        try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: true)
        var policy = ProjectExecutionPolicy(registration: prior.registration, primaryRoot: replacement.path, appServerExecutable: prior.appServerExecutable, handlerPath: prior.handlerPath)
        policy.consent = prior.consent; policy.hookReceipt = prior.hookReceipt
        try store.savePolicy(policy, expected: prior)
        let current = AuthorizedProject(registration: prior.registration, canonicalRoot: replacement, authorizedRoots: [replacement])
        let provisioning = CleanupProvisioning()
        let resources = ProjectExecutionResourceLifecycle(root: { root }, configuration: CleanupConfiguration(), provisioning: provisioning)
        do { _ = try await resources.retire(project: current, expected: value, requestID: UUID()); XCTFail("The current root grant cannot authorize old Git cleanup") } catch {}
        XCTAssertEqual(provisioning.removals, 0); XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: value.id), value)
        let authorized = AuthorizedProject(registration: prior.registration, canonicalRoot: replacement, authorizedRoots: [replacement, project.canonicalRoot])
        let retired = try await resources.retire(project: authorized, expected: value, requestID: UUID())
        XCTAssertEqual(retired.retirement?.completed, true)
        XCTAssertEqual(try store.policy(projectID: "project-one"), policy)
    }

    func testReaddedOwnerCanRetireOnlyItsProtectedPredecessorResources() async throws {
        let (root, _, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .unknown, closed: true)
        let prior = try store.policy(projectID: "project-one")
        var disabled = prior; disabled.enabled = false; try store.savePolicy(disabled, expected: prior)
        let registration = ProjectRegistration(projectID: .init(rawValue: "new-project"), registrationID: "new-registration", requestGeneration: 1)
        var currentPolicy = ProjectExecutionPolicy(registration: registration, primaryRoot: prior.primaryRoot, appServerExecutable: prior.appServerExecutable, handlerPath: prior.handlerPath)
        currentPolicy.consent = prior.consent; currentPolicy.hookReceipt = prior.hookReceipt
        try store.savePolicy(currentPolicy, expected: nil)
        let current = AuthorizedProject(registration: registration, canonicalRoot: project.canonicalRoot, authorizedRoots: [project.canonicalRoot])
        let resources = ProjectExecutionResourceLifecycle(root: { root }, configuration: CleanupConfiguration(), provisioning: CleanupProvisioning())
        do { _ = try await resources.retire(project: current, expected: value, requestID: UUID()); XCTFail("Unrelated project resources must not be adopted") } catch {}
        let unlinked = currentPolicy; currentPolicy.previousProjectIDs = ["project-one"]; try store.savePolicy(currentPolicy, expected: unlinked)
        let visible = try await resources.assignments(project: current)
        XCTAssertTrue(visible.contains(value))
        let retired = try await resources.retire(project: current, expected: value, requestID: UUID())
        XCTAssertEqual(retired.registration, value.registration)
        XCTAssertEqual(retired.retirement?.completed, true)
        XCTAssertFalse(try store.policy(projectID: "project-one").enabled)
    }

    func testGenerationAndRootReplacementThenRemovalReaddRetiresExactHistoricalResources() async throws {
        let (root, _, originalProject, work, store) = try fixture()
        var value = try cleanupAssignment(store: store, project: originalProject, work: work, state: .unknown, closed: true)
        let prior = try store.policy(projectID: "project-one")
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: value.id)
        let unpinned = value
        value.permissionProfileDefinition = try ProjectExecutionPermissionProfile(assignment: value, policy: prior, paths: paths).definition
        try store.saveAssignment(value, expected: unpinned)
        let originalFiles = try ProjectExecutionFileStore(root: originalProject.canonicalRoot, create: false)
        let originalHook = try ProjectExecutionHookRegistration.merge(nil, command: "\"" + handler + "\" --hook", previousCommand: nil)
        try originalFiles.saveHookConfiguration(originalHook, expected: nil)

        let replacementRoot = root.appendingPathComponent("Replacement")
        try FileManager.default.createDirectory(at: replacementRoot, withIntermediateDirectories: true)
        let generationTwo = ProjectRegistration(projectID: originalProject.projectID, registrationID: prior.registration.registrationID, requestGeneration: 2)
        let replacedProject = AuthorizedProject(registration: generationTwo, canonicalRoot: replacementRoot, authorizedRoots: [replacementRoot])
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: Configuration(), handlerPath: handler)
        try await setup.update(project: replacedProject)
        // Application removal disables its last binding; retained assignments
        // still carry their original generation and repository identity.
        let replacedPolicy = try store.policy(projectID: "project-one")
        var removed = replacedPolicy; removed.enabled = false; try store.savePolicy(removed, expected: replacedPolicy)
        let newRegistration = ProjectRegistration(projectID: .init(rawValue: "readded-project"), registrationID: "new-registration", requestGeneration: 1)
        let readded = AuthorizedProject(registration: newRegistration, canonicalRoot: replacementRoot, authorizedRoots: [replacementRoot])
        try await setup.prepare(project: readded, removedRegistrations: [generationTwo], beforeWrite: {})
        let readdedPolicy = try store.policy(projectID: "readded-project")
        XCTAssertEqual(readdedPolicy.previousProjectIDs, ["project-one"])

        let configuration = CleanupConfiguration(); let provisioning = CleanupProvisioning()
        let resources = ProjectExecutionResourceLifecycle(root: { root }, configuration: configuration, provisioning: provisioning)
        let visible = try await resources.assignments(project: readded)
        XCTAssertTrue(visible.contains(value))
        do { _ = try await resources.retire(project: readded, expected: value, requestID: UUID()); XCTFail("New root access cannot grant historical cleanup") } catch {}
        XCTAssertEqual(provisioning.removals, 0)
        let authorized = AuthorizedProject(registration: newRegistration, canonicalRoot: replacementRoot, authorizedRoots: [replacementRoot, originalProject.canonicalRoot])
        var unclosed = value; unclosed.connectionClosed = false; try store.saveAssignment(unclosed, expected: value)
        do { _ = try await resources.retire(project: authorized, expected: unclosed, requestID: UUID()); XCTFail("Historical recovery must still require old worker closure") } catch {}
        XCTAssertEqual(provisioning.removals, 0)
        try store.saveAssignment(value, expected: unclosed)
        let retired = try await resources.retire(project: authorized, expected: value, requestID: UUID())
        XCTAssertEqual(retired.registration, value.registration); XCTAssertEqual(retired.worktree, value.worktree)
        XCTAssertEqual(retired.retirement?.completed, true); XCTAssertEqual(retired.retirement?.priorState, .unknown)
        XCTAssertEqual(retired.uncertainOutcome, true); XCTAssertEqual(retired.connectionClosed, true)
        XCTAssertEqual(provisioning.removals, 1)
        let removedProfiles = await configuration.removedProfiles; XCTAssertEqual(removedProfiles, [value.permissionProfile])
        XCTAssertEqual(try store.policy(projectID: "project-one"), removed)
        XCTAssertEqual(try store.policy(projectID: "readded-project"), readdedPolicy)
        XCTAssertEqual(try originalFiles.hookConfiguration(), originalHook)
    }

    func testLostHandleReconcilesOnlyMatchingProfileAndPreservesOriginalUnknownClose() async throws {
        let (root, _, project, work, store) = try fixture()
        let value = try cleanupAssignment(store: store, project: project, work: work, state: .revoked, closed: true)
        let originalConfiguration = CleanupConfiguration(); await originalConfiguration.setConflict(true); await originalConfiguration.setCloseFailure(true)
        let provisioning = CleanupProvisioning()
        let original = ProjectExecutionResourceLifecycle(root: { root }, configuration: originalConfiguration, provisioning: provisioning)
        let request = UUID()
        do { _ = try await original.retire(project: project, expected: value, requestID: request) } catch {}
        let pending = try store.assignment(projectID: "project-one", taskID: value.id)
        XCTAssertEqual(pending.retirement?.profileRemoved, false)
        let recoveryConfiguration = CleanupConfiguration(); await recoveryConfiguration.setConflict(true)
        let recovery = ProjectExecutionResourceLifecycle(root: { root }, configuration: recoveryConfiguration, provisioning: provisioning)
        do { _ = try await recovery.retire(project: project, expected: pending, requestID: request); XCTFail("A modified profile cannot be replaced or removed") } catch {}
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: value.id), pending)
        await recoveryConfiguration.setConflict(false)
        let recovered = try await recovery.retire(project: project, expected: pending, requestID: request)
        XCTAssertEqual(recovered.retirement?.profileRemoved, true)
        XCTAssertEqual(recovered.retirement?.replacementAllowed, true)
        XCTAssertEqual(recovered.retirement?.connectionCloseUncertain, true)
        XCTAssertEqual(recovered.retirement?.completed, false)
        let newCloses = await recoveryConfiguration.closedConnections; XCTAssertEqual(newCloses.count, 2)
        XCTAssertEqual(provisioning.removals, 1)
    }
    private func fixture(bindContext: Bool = true) throws -> (URL, URL, AuthorizedProject, ProjectExecutionWork, ProjectExecutionFileStore) {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let source = base.appendingPathComponent("Repository")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("Current approved instructions".utf8).write(to: source.appendingPathComponent("AGENTS.md"))
        let root = base.appendingPathComponent("Execution")
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: source.path, appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handler)
        if bindContext {
            let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
            try store.saveCodexContext(context, expected: nil)
            policy.codexContextID = context.id
        }
        policy.consent = .init(); policy.hookReceipt = .init(command: "\"" + handler + "\" --hook", inline: false, beforeDigest: nil, intendedDigest: String(repeating: "a", count: 64), installed: true)
        try store.savePolicy(policy, expected: nil)
        let work = ProjectExecutionWork(projectID: registration.projectID, ticketID: "ticket-one", taskID: "work-one", outcome: "Bounded outcome", title: "Approved task", taskPlanRevision: 1, phaseID: "phase-one", phaseRevision: 2)
        return (root, source, .init(registration: registration, canonicalRoot: source, authorizedRoots: [source]), work, store)
    }

    func testFreshPreparationCreatesOnlyEmptyProjectLayerBeforeHookDiscovery() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration(); await configuration.requireLayer()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let request = UUID()
        let prepared = try await producer.prepare(project: project, work: work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: prepared.checkoutPath + "/.codex"), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path + "/.codex"))
        XCTAssertEqual(prepared.id, "delivery-" + request.uuidString.lowercased())
        XCTAssertEqual(prepared.state, .preparing)
        XCTAssertEqual(prepared.codexContextID, try store.policy(projectID: "project-one").codexContextID)
        XCTAssertEqual(try store.assignments(projectID: "project-one").count, 1)
        let profiles = await configuration.profiles
        XCTAssertEqual(profiles.first?.workspace[".codex"], "deny")
    }

    func testExactPreparingRecoveryEnsuresProjectLayerAndPreservesIdentityAndExistingContent() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration(); await configuration.setFailure(true)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let request = UUID()
        do { _ = try await producer.prepare(project: project, work: work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Expected profile failure") } catch {}
        let pending = try XCTUnwrap(store.assignments(projectID: "project-one").first)
        await configuration.setFailure(false); await configuration.requireLayer()
        let recovered = try await producer.prepare(project: project, work: work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(recovered.id, pending.id); XCTAssertEqual(recovered.worktree, pending.worktree)
        XCTAssertEqual(recovered.context, pending.context); XCTAssertEqual(recovered.work, pending.work)
        XCTAssertEqual(recovered.codexContextID, pending.codexContextID)
        XCTAssertEqual(recovered.authorization, pending.authorization)
        XCTAssertEqual(recovered.permissionProfileDefinition, pending.permissionProfileDefinition)
        let content = URL(fileURLWithPath: recovered.checkoutPath + "/.codex/owner.txt")
        try Data("preserve".utf8).write(to: content)
        let repeated = try await producer.prepare(project: project, work: work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(repeated, recovered)
        XCTAssertEqual(try String(contentsOf: content, encoding: .utf8), "preserve")
    }

    func testProjectLayerCollisionRefusesDiscoveryAndPreservesPreparingRequest() async throws {
        for symlink in [false, true] {
            let (root, source, project, work, store) = try fixture()
            let configuration = Configuration(); await configuration.setFailure(true)
            let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
                handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
            let request = UUID()
            do { _ = try await producer.prepare(project: project, work: work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]) } catch {}
            let pending = try XCTUnwrap(store.assignments(projectID: "project-one").first)
            let layer = URL(fileURLWithPath: pending.checkoutPath + "/.codex")
            if symlink { try FileManager.default.createSymbolicLink(at: layer, withDestinationURL: source) }
            else { try Data("collision".utf8).write(to: layer) }
            await configuration.setFailure(false)
            do { _ = try await producer.prepare(project: project, work: work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Collision must refuse") }
            catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
            XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: pending.id), pending)
            let checks = await configuration.hookChecks; XCTAssertEqual(checks, 0)
            if symlink { XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: layer.path), source.path) }
            else { XCTAssertEqual(try Data(contentsOf: layer), Data("collision".utf8)) }
        }
    }

    func testChangedPolicyOrAssignmentDuringProfilePreparationRefusesDirectoryMutation() async throws {
        for changePolicy in [false, true] {
            let (root, source, project, work, store) = try fixture()
            let configuration = Configuration()
            let request = UUID(); let id = "delivery-" + request.uuidString.lowercased()
            await configuration.onProfile {
                if changePolicy {
                    let prior = try store.policy(projectID: "project-one")
                    var disabled = prior; disabled.enabled = false
                    try store.savePolicy(disabled, expected: prior)
                } else {
                    let prior = try store.assignment(projectID: "project-one", taskID: id)
                    var reserved = prior; reserved.launchReserved = true
                    try store.saveAssignment(reserved, expected: prior)
                }
            }
            let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
                handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
            do { _ = try await producer.prepare(project: project, work: work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Changed authority must refuse directory mutation") }
            catch { XCTAssertEqual(error as? ProjectExecutionError, .assignmentNotAuthorized) }
            let pending = try store.assignment(projectID: "project-one", taskID: id)
            XCTAssertEqual(pending.state, .preparing)
            XCTAssertFalse(FileManager.default.fileExists(atPath: pending.checkoutPath + "/.codex"))
            if changePolicy { XCTAssertFalse(try store.policy(projectID: "project-one").enabled) }
            else { XCTAssertEqual(pending.launchReserved, true) }
            let checks = await configuration.hookChecks; XCTAssertEqual(checks, 0)
        }
    }

    func testReservedOrUncertainPreparingRequestCannotMaterializeProjectLayer() async throws {
        for uncertain in [false, true] {
            let (root, source, project, work, store) = try fixture()
            let configuration = Configuration(); await configuration.setFailure(true)
            let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
                handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
            let request = UUID()
            do { _ = try await producer.prepare(project: project, work: work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]) } catch {}
            let pending = try XCTUnwrap(store.assignments(projectID: "project-one").first)
            var reserved = pending
            if uncertain { reserved.uncertainOutcome = true } else { reserved.launchReserved = true }
            try store.saveAssignment(reserved, expected: pending)
            await configuration.setFailure(false)
            do { _ = try await producer.prepare(project: project, work: work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Reserved/uncertain request must remain blocked") }
            catch { XCTAssertEqual(error as? ProjectExecutionError, .assignmentNotAuthorized) }
            XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: reserved.id), reserved)
            XCTAssertFalse(FileManager.default.fileExists(atPath: reserved.checkoutPath + "/.codex"))
            let checks = await configuration.hookChecks; XCTAssertEqual(checks, 0)
        }
    }

    func testProjectLayerDoesNotBypassHookRejection() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration(); await configuration.requireLayer(rejectHook: true)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Untrusted/disabled hook must refuse") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .hookNotReady) }
        let pending = try XCTUnwrap(store.assignments(projectID: "project-one").first)
        XCTAssertEqual(pending.state, .preparing); XCTAssertNil(pending.preparedPolicyDigest)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: pending.checkoutPath + "/.codex"), [])
    }

    func testFinalAdmissionRejectsUnboundLegacyPreparationAndPreservesIt() async throws {
        let (root, source, project, work, store) = try fixture(bindContext: false)
        let configuration = Configuration()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let prepared = try await producer.prepare(project: project, work: work, requestID: UUID(),
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertNil(prepared.codexContextID)
        XCTAssertThrowsError(try producer.admitPrepared(prepared), "Historical unbound preparation cannot become authority")
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: prepared.id), prepared)
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
