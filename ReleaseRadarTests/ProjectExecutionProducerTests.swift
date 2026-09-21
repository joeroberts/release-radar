import CryptoKit
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
        var afterHook: (@Sendable () throws -> Void)?
        var profileError: ProjectExecutionError?
        var finishes = 0
        var profiles: [ProjectExecutionPermissionProfile] = []
        var seededProfileIDs: Set<String> = []
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
            try afterHook?()
            try await beforeWrite()
        }
        func requireLayer(rejectHook: Bool = false) { requireProjectLayer = true; self.rejectHook = rejectHook }
        func finishConfiguration() { finishes += 1 }
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) throws {
            profiles.append(profile); if failProfile { throw ProjectExecutionError.hookNotReady }
            if let profileError { throw profileError }
            try afterProfile?()
        }
        func workerProfileExists(primaryRoot: String, profileID: String) -> Bool {
            seededProfileIDs.contains(profileID) || profiles.contains(where: { $0.id == profileID })
        }
        func seedProfile(_ id: String) { seededProfileIDs.insert(id) }
        func setFailure(_ value: Bool) { failProfile = value }
        func setProfileError(_ value: ProjectExecutionError?) { profileError = value }
        func onProfile(_ action: @escaping @Sendable () throws -> Void) { afterProfile = action }
        func onHook(_ action: @escaping @Sendable () throws -> Void) { afterHook = action }
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
        func hasPreparedResources(primaryRoot: URL, checkout: URL, projectID: String, taskID: String) -> Bool {
            FileManager.default.fileExists(atPath: checkout.path)
        }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String, taskID: String) throws { throw ProjectExecutionError.unavailable }
    }
    struct UninspectableProvisioning: ExecutionWorktreeProvisioning {
        let base: Provisioning
        func revision(at root: URL, requireClean: Bool) throws -> String { try base.revision(at: root, requireClean: requireClean) }
        func candidateRevision(worktree: ExecutionWorktree) throws -> String { try base.candidateRevision(worktree: worktree) }
        func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String, baseline: String) throws -> ExecutionWorktree {
            try base.prepare(primaryRoot: primaryRoot, checkout: checkout, projectID: projectID, taskID: taskID, baseline: baseline)
        }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String, taskID: String) throws {
            try base.remove(primaryRoot: primaryRoot, worktree: worktree, projectID: projectID, taskID: taskID)
        }
    }
    struct CandidateOverrideProvisioning: ExecutionWorktreeProvisioning {
        let base: Provisioning
        let revisions: [String: String]
        func revision(at root: URL, requireClean: Bool) throws -> String {
            try base.revision(at: root, requireClean: requireClean)
        }
        func candidateRevision(worktree: ExecutionWorktree) throws -> String {
            revisions[worktree.checkout] ?? (try base.candidateRevision(worktree: worktree))
        }
        func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String,
                     baseline: String) throws -> ExecutionWorktree {
            try base.prepare(primaryRoot: primaryRoot, checkout: checkout,
                projectID: projectID, taskID: taskID, baseline: baseline)
        }
        func hasPreparedResources(primaryRoot: URL, checkout: URL, projectID: String,
                                  taskID: String) throws -> Bool {
            try base.hasPreparedResources(primaryRoot: primaryRoot, checkout: checkout,
                projectID: projectID, taskID: taskID)
        }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String,
                    taskID: String) throws {
            try base.remove(primaryRoot: primaryRoot, worktree: worktree,
                projectID: projectID, taskID: taskID)
        }
    }
    struct ConflictProvisioning: ExecutionWorktreeProvisioning {
        enum Site: Equatable { case parentCandidate, targetPreparation }
        let base: Provisioning
        let site: Site
        func revision(at root: URL, requireClean: Bool) throws -> String {
            try base.revision(at: root, requireClean: requireClean)
        }
        func candidateRevision(worktree: ExecutionWorktree) throws -> String {
            if site == .parentCandidate { throw ProjectExecutionError.conflict }
            return try base.candidateRevision(worktree: worktree)
        }
        func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String,
                     baseline: String) throws -> ExecutionWorktree {
            if site == .targetPreparation { throw ProjectExecutionError.conflict }
            return try base.prepare(primaryRoot: primaryRoot, checkout: checkout,
                projectID: projectID, taskID: taskID, baseline: baseline)
        }
        func hasPreparedResources(primaryRoot: URL, checkout: URL, projectID: String,
                                  taskID: String) throws -> Bool {
            try base.hasPreparedResources(primaryRoot: primaryRoot, checkout: checkout,
                projectID: projectID, taskID: taskID)
        }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String,
                    taskID: String) throws {
            try base.remove(primaryRoot: primaryRoot, worktree: worktree,
                projectID: projectID, taskID: taskID)
        }
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
    private struct RecoveryProcessObserver: ProjectExecutionWorkerProcessObserving {
        let evidence: ProjectExecutionAssignment.LostWorkerProcessEvidence?
        let failure: ProjectExecutionError?
        func verifiedAbsence(for assignment: ProjectExecutionAssignment) throws
            -> ProjectExecutionAssignment.LostWorkerProcessEvidence {
            if let failure { throw failure }
            return try XCTUnwrap(evidence)
        }
    }
    private final class RecoveryGrantReconciler: ProjectExecutionContextGrantReconciling, @unchecked Sendable {
        private let lock = NSLock()
        private var outcomes: [ProjectExecutionAssignment.LostWorkerRecovery.GrantDisposition]
        private let failure: ProjectExecutionError?
        private(set) var calls = 0
        init(_ outcomes: [ProjectExecutionAssignment.LostWorkerRecovery.GrantDisposition],
             failure: ProjectExecutionError? = nil) {
            self.outcomes = outcomes; self.failure = failure
        }
        func reconcileLostWorkerGrant(for assignment: ProjectExecutionAssignment) throws
            -> ProjectExecutionAssignment.LostWorkerRecovery.GrantDisposition {
            try lock.withLock {
                calls += 1
                if let failure { throw failure }
                guard !outcomes.isEmpty else { throw ProjectExecutionError.unavailable }
                return outcomes.removeFirst()
            }
        }
    }
    private final class RecoveryValidationGate: @unchecked Sendable {
        private let lock = NSLock()
        private var callCount = 0
        private var failureCall: Int?
        init(failureCall: Int?) { self.failureCall = failureCall }
        func validate() throws {
            try lock.withLock {
                callCount += 1
                if callCount == failureCall { throw ProjectExecutionError.conflict }
            }
        }
        func allow() { lock.withLock { failureCall = nil } }
    }
    private final class RecoveryAuditCASInjector: @unchecked Sendable {
        private let lock = NSLock()
        private var callCount = 0
        private let store: ProjectExecutionFileStore
        private let expected: ProjectExecutionAssignment
        private let replacement: ProjectExecutionAssignment

        init(store: ProjectExecutionFileStore, expected: ProjectExecutionAssignment,
             replacement: ProjectExecutionAssignment) {
            self.store = store; self.expected = expected; self.replacement = replacement
        }

        func validate() throws {
            try lock.withLock {
                callCount += 1
                if callCount == 2 { try store.saveAssignment(replacement, expected: expected) }
            }
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

    private func legacyLostAssignment(root: URL, source: URL, project: AuthorizedProject,
                                      work: ProjectExecutionWork, store: ProjectExecutionFileStore,
                                      id: String = "delivery-legacy-lost") throws -> ProjectExecutionAssignment {
        let paths = try ProjectExecutionPaths(storageRoot: root,
            projectID: project.projectID.rawValue, taskID: id)
        try FileManager.default.createDirectory(at: paths.checkout.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: paths.checkout)
        let instructions = try Data(contentsOf: paths.checkout.appendingPathComponent("AGENTS.md"))
        var value = ProjectExecutionAssignment(id: id, registration: project.registration!,
            checkoutPath: paths.checkout.path, role: .delivery,
            permissionProfile: "rr-" + id, model: "gpt-5.6-terra", effort: "medium",
            authorization: "Approved legacy work",
            context: [.init(path: "AGENTS.md",
                digest: SHA256.hash(data: instructions).map { String(format: "%02x", $0) }.joined())],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .authorized, sessionID: "legacy-session",
            worktree: .init(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-\(project.projectID.rawValue)-\(id)",
                commonGitDirectory: source.path + "/.git", primaryRoot: source.path), work: work)
        value.codexContextID = try store.policy(projectID: project.projectID.rawValue).codexContextID
        value.launchReserved = true
        try store.saveAssignment(value, expected: nil)
        return value
    }

    private func processObserver(for assignment: ProjectExecutionAssignment,
                                 observedAt: Date = Date(timeIntervalSince1970: 1_789_963_200))
        -> RecoveryProcessObserver {
        .init(evidence: .init(
            version: 1,
            observedAt: observedAt,
            executablePath: CodexExecutionIdentity.executable,
            permissionProfile: assignment.permissionProfile,
            argumentMarker: "permissions.\(assignment.permissionProfile).network.enabled=false"
        ), failure: nil)
    }

    private func replacing(_ assignment: ProjectExecutionAssignment,
                           _ change: (inout [String: Any]) throws -> Void) throws
        -> ProjectExecutionAssignment {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(assignment)) as? [String: Any])
        try change(&object)
        return try JSONDecoder().decode(ProjectExecutionAssignment.self,
            from: JSONSerialization.data(withJSONObject: object))
    }

    private func recoveredAncestorAndClosedSuccessor(root: URL, source: URL,
                                                      project: AuthorizedProject,
                                                      work: ProjectExecutionWork,
                                                      store: ProjectExecutionFileStore) async throws
        -> (recovered: ProjectExecutionAssignment, successor: ProjectExecutionAssignment) {
        let legacy = try legacyLostAssignment(root: root, source: source, project: project,
            work: work, store: store)
        let recoveredProvisioning = Provisioning(source: source,
            candidate: URL(fileURLWithPath: legacy.checkoutPath))
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(), provisioning: recoveredProvisioning,
            processObserver: processObserver(for: legacy),
            grantReconciler: RecoveryGrantReconciler([.noMatchingGrant]))
        let recovered = try await lifecycle.recoverLostWorker(project: project,
            expected: legacy, requestID: UUID())

        let producer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler,
            provisioning: recoveredProvisioning)
        let requestID = UUID()
        let pending = try await producer.prepare(project: project, work: work,
            requestID: requestID, reviewOfAssignmentID: nil,
            baselineFromAssignmentID: recovered.id, contextPaths: ["AGENTS.md"])
        let admitted = try producer.admitPrepared(pending)
        await producer.finishPreparation(work: work, requestID: requestID)
        var successor = admitted
        successor.state = .closed
        successor.sessionID = "closed-successor-session"
        successor.connectionClosed = true
        try store.saveAssignment(successor, expected: admitted)
        return (recovered, successor)
    }

    private func continuationProvisioning(
        source: URL,
        recovered: ProjectExecutionAssignment,
        immediateParent: ProjectExecutionAssignment
    ) -> CandidateOverrideProvisioning {
        CandidateOverrideProvisioning(
            base: Provisioning(source: source,
                candidate: URL(fileURLWithPath: immediateParent.checkoutPath)),
            revisions: [recovered.checkoutPath: String(repeating: "b", count: 40)]
        )
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
        catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic.kind, .blockingAssignment)
            XCTAssertEqual(conflict.diagnostic.blockingAssignmentID, value.id)
        }
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

    func testLostWorkerRecoveryPreservesCheckoutAndAdmitsOnlyExactContinuationParent() async throws {
        let (root, source, project, work, store) = try fixture()
        let legacy = try legacyLostAssignment(root: root, source: source, project: project,
            work: work, store: store)
        let checkout = URL(fileURLWithPath: legacy.checkoutPath)
        let provisioning = Provisioning(source: source, candidate: checkout)
        let grants = RecoveryGrantReconciler([.matchingGrantReleased])
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(), provisioning: provisioning,
            processObserver: processObserver(for: legacy), grantReconciler: grants)
        let requestID = UUID()

        let recovered = try await lifecycle.recoverLostWorker(project: project,
            expected: legacy, requestID: requestID)

        XCTAssertEqual(recovered.state, .stopped)
        XCTAssertEqual(recovered.sessionID, legacy.sessionID)
        XCTAssertEqual(recovered.connectionClosed, true)
        XCTAssertEqual(recovered.launchReserved, true)
        XCTAssertEqual(recovered.uncertainOutcome, true)
        XCTAssertEqual(recovered.checkoutPath, legacy.checkoutPath)
        XCTAssertEqual(recovered.permissionProfile, legacy.permissionProfile)
        XCTAssertEqual(recovered.worktree, legacy.worktree)
        XCTAssertNil(recovered.retirement)
        XCTAssertEqual(recovered.lostWorkerRecovery?.requestID, requestID)
        XCTAssertEqual(recovered.lostWorkerRecovery?.priorState, .authorized)
        XCTAssertEqual(recovered.lostWorkerRecovery?.candidateRevision,
            String(repeating: "b", count: 40))
        XCTAssertEqual(recovered.lostWorkerRecovery?.grantDisposition, .matchingGrantReleased)
        XCTAssertEqual(grants.calls, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.checkoutPath))
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: legacy.id), recovered)

        let producer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler, provisioning: provisioning)
        let continuationRequest = UUID()
        let continuation = try await producer.prepare(project: project, work: work,
            requestID: continuationRequest, reviewOfAssignmentID: nil,
            baselineFromAssignmentID: recovered.id, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(continuation.role, .delivery)
        XCTAssertEqual(continuation.baselineFromAssignmentID, recovered.id)
        XCTAssertEqual(continuation.worktree?.baseline, String(repeating: "b", count: 40))
        XCTAssertNotEqual(continuation.checkoutPath, recovered.checkoutPath)
        await producer.finishPreparation(work: work, requestID: continuationRequest)
    }

    func testRecoveredAncestorChainUsesImmediateClosedSuccessorCandidateForCorrections() async throws {
        let (root, source, project, work, store) = try fixture()
        let chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
            project: project, work: work, store: store)
        let provisioning = continuationProvisioning(source: source,
            recovered: chain.recovered, immediateParent: chain.successor)

        let reviewProducer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler, provisioning: provisioning)
        let reviewRequest = UUID()
        let review = try await reviewProducer.prepare(project: project, work: work,
            requestID: reviewRequest, reviewOfAssignmentID: chain.successor.id,
            baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(review.role, .review)
        XCTAssertEqual(review.reviewOfAssignmentID, chain.successor.id,
            "A successful successor remains the review boundary; its recovered ancestor does not")
        await reviewProducer.finishPreparation(work: work, requestID: reviewRequest)

        let correctionProducer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler, provisioning: provisioning)
        let correctionRequest = UUID()
        let correction = try await correctionProducer.prepare(project: project, work: work,
            requestID: correctionRequest, reviewOfAssignmentID: nil,
            baselineFromAssignmentID: chain.successor.id, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(correction.baselineFromAssignmentID, chain.successor.id)
        XCTAssertEqual(correction.worktree?.baseline, chain.successor.worktree?.baseline)
        XCTAssertNotEqual(correction.checkoutPath, chain.successor.checkoutPath)
        let admitted = try correctionProducer.admitPrepared(correction)
        await correctionProducer.finishPreparation(work: work, requestID: correctionRequest)

        var closedCorrection = admitted
        closedCorrection.state = .closed
        closedCorrection.sessionID = "closed-correction-session"
        closedCorrection.connectionClosed = true
        try store.saveAssignment(closedCorrection, expected: admitted)

        let laterProducer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler,
            provisioning: continuationProvisioning(source: source,
                recovered: chain.recovered, immediateParent: closedCorrection))
        let laterRequest = UUID()
        let later = try await laterProducer.prepare(project: project, work: work,
            requestID: laterRequest, reviewOfAssignmentID: nil,
            baselineFromAssignmentID: closedCorrection.id, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(later.baselineFromAssignmentID, closedCorrection.id)
        XCTAssertEqual(later.worktree?.baseline, closedCorrection.worktree?.baseline)
        await laterProducer.finishPreparation(work: work, requestID: laterRequest)
    }

    func testRecoveredAncestorTraversalRejectsBrokenIdentityReceiptAndCandidateChains() async throws {
        for scenario in ["missing", "cycle", "stale-work", "missing-receipt",
                         "recovery-candidate-mismatch", "child-baseline-mismatch"] {
            let (root, source, project, work, store) = try fixture()
            var chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
                project: project, work: work, store: store)
            switch scenario {
            case "missing":
                let changed = try replacing(chain.successor) {
                    $0["baselineFromAssignmentID"] = "delivery-missing"
                }
                try store.saveAssignment(changed, expected: chain.successor)
                chain.successor = changed
            case "cycle":
                let changed = try replacing(chain.successor) {
                    $0["baselineFromAssignmentID"] = chain.successor.id
                }
                try store.saveAssignment(changed, expected: chain.successor)
                chain.successor = changed
            case "stale-work":
                let changed = try replacing(chain.recovered) {
                    var changedWork = try XCTUnwrap($0["work"] as? [String: Any])
                    changedWork["outcome"] = "Different outcome"
                    $0["work"] = changedWork
                }
                try store.saveAssignment(changed, expected: chain.recovered)
                chain.recovered = changed
            case "missing-receipt":
                let changed = try replacing(chain.recovered) { $0["lostWorkerRecovery"] = NSNull() }
                try store.saveAssignment(changed, expected: chain.recovered)
                chain.recovered = changed
            case "recovery-candidate-mismatch":
                let changed = try replacing(chain.recovered) {
                    var recovery = try XCTUnwrap($0["lostWorkerRecovery"] as? [String: Any])
                    recovery["candidateRevision"] = String(repeating: "c", count: 40)
                    $0["lostWorkerRecovery"] = recovery
                }
                try store.saveAssignment(changed, expected: chain.recovered)
                chain.recovered = changed
            case "child-baseline-mismatch":
                let changed = try replacing(chain.successor) {
                    var tree = try XCTUnwrap($0["worktree"] as? [String: Any])
                    tree["baseline"] = String(repeating: "a", count: 40)
                    $0["worktree"] = tree
                }
                try store.saveAssignment(changed, expected: chain.successor)
                chain.successor = changed
            default:
                XCTFail("Unknown fixture scenario")
            }

            let base = Provisioning(source: source,
                candidate: URL(fileURLWithPath: chain.successor.checkoutPath))
            let provisioning: any ExecutionWorktreeProvisioning = CandidateOverrideProvisioning(
                base: base, revisions: [
                    chain.recovered.checkoutPath: String(repeating: "b", count: 40),
                ])
            let producer = ProjectExecutionAssignmentCoordinator(root: { root },
                configuration: Configuration(), handlerPath: handler, provisioning: provisioning)
            do {
                _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                    reviewOfAssignmentID: nil, baselineFromAssignmentID: chain.successor.id,
                    contextPaths: ["AGENTS.md"])
                XCTFail("Broken recovered ancestry must refuse: \(scenario)")
            } catch {}
            XCTAssertEqual(try store.assignments(projectID: project.projectID.rawValue).count, 2,
                "Invalid ancestry must be rejected before a correction assignment is persisted")
        }
    }

    func testRecoveredAncestorCandidateDriftAndUnrelatedWorkersRemainBlocking() async throws {
        for siblingState in [ProjectExecutionAssignment.State.authorized, .unknown] {
            let (root, source, project, work, store) = try fixture()
            let chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
                project: project, work: work, store: store)
            let siblingID = siblingState == .authorized ? "delivery-active-sibling" : "delivery-uncertain-sibling"
            let siblingPaths = try ProjectExecutionPaths(storageRoot: root,
                projectID: project.projectID.rawValue, taskID: siblingID)
            var sibling = ProjectExecutionAssignment(id: siblingID, registration: project.registration!,
                checkoutPath: siblingPaths.checkout.path, role: .delivery,
                permissionProfile: "rr-" + siblingID, model: "gpt-5.6-terra", effort: "medium",
                authorization: "Unrelated retained work",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: siblingState, sessionID: "sibling-session",
                worktree: .init(checkout: siblingPaths.checkout.path,
                    baseline: String(repeating: "a", count: 40),
                    branch: "codex/rr-project-one-" + siblingID,
                    commonGitDirectory: source.path + "/.git", primaryRoot: source.path), work: work)
            sibling.codexContextID = try store.policy(projectID: project.projectID.rawValue).codexContextID
            sibling.launchReserved = true
            if siblingState == .unknown { sibling.uncertainOutcome = true }
            try store.saveAssignment(sibling, expected: nil)

            let producer = ProjectExecutionAssignmentCoordinator(root: { root },
                configuration: Configuration(), handlerPath: handler,
                provisioning: continuationProvisioning(source: source,
                    recovered: chain.recovered, immediateParent: chain.successor))
            do {
                _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                    reviewOfAssignmentID: nil, baselineFromAssignmentID: chain.successor.id,
                    contextPaths: ["AGENTS.md"])
                XCTFail("Recovered ancestry cannot exempt an unrelated sibling")
            } catch let conflict as ProjectExecutionPreparationConflict {
                XCTAssertEqual(conflict.diagnostic.kind, .blockingAssignment)
                XCTAssertEqual(conflict.diagnostic.blockingAssignmentID, siblingID)
            }
        }

        let (root, source, project, work, store) = try fixture()
        let chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
            project: project, work: work, store: store)
        let base = Provisioning(source: source,
            candidate: URL(fileURLWithPath: chain.successor.checkoutPath))
        let drifted = CandidateOverrideProvisioning(base: base, revisions: [
            chain.recovered.checkoutPath: String(repeating: "c", count: 40),
        ])
        let producer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler, provisioning: drifted)
        do {
            _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: nil, baselineFromAssignmentID: chain.successor.id,
                contextPaths: ["AGENTS.md"])
            XCTFail("A dirty or replaced recovered checkout must invalidate the chain")
        } catch {}
        XCTAssertEqual(try store.assignments(projectID: project.projectID.rawValue).count, 2)
    }

    func testRecoveredAncestryIsRecheckedAfterConfigurationAndAtFinalAdmission() async throws {
        do {
            let (root, source, project, work, store) = try fixture()
            let chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
                project: project, work: work, store: store)
            let changedSuccessor = try replacing(chain.successor) {
                $0["baselineFromAssignmentID"] = "delivery-missing-after-configuration"
            }
            let configuration = Configuration()
            await configuration.onProfile {
                try store.saveAssignment(changedSuccessor, expected: chain.successor)
            }
            let producer = ProjectExecutionAssignmentCoordinator(root: { root },
                configuration: configuration, handlerPath: handler,
                provisioning: continuationProvisioning(source: source,
                    recovered: chain.recovered, immediateParent: chain.successor))
            do {
                _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                    reviewOfAssignmentID: nil, baselineFromAssignmentID: chain.successor.id,
                    contextPaths: ["AGENTS.md"])
                XCTFail("An ancestry mutation during configuration must prevent preparation")
            } catch {}
            let successorPath = try ProjectExecutionPaths(storageRoot: root,
                projectID: project.projectID.rawValue, taskID: chain.successor.id).assignment
            let persistedSuccessor = try JSONDecoder().decode(ProjectExecutionAssignment.self,
                from: Data(contentsOf: successorPath))
            XCTAssertEqual(persistedSuccessor, changedSuccessor,
                "The race is preserved as evidence rather than overwritten")
        }

        do {
            let (root, source, project, work, store) = try fixture()
            let chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
                project: project, work: work, store: store)
            let producer = ProjectExecutionAssignmentCoordinator(root: { root },
                configuration: Configuration(), handlerPath: handler,
                provisioning: continuationProvisioning(source: source,
                    recovered: chain.recovered, immediateParent: chain.successor))
            let requestID = UUID()
            let pending = try await producer.prepare(project: project, work: work,
                requestID: requestID, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: chain.successor.id, contextPaths: ["AGENTS.md"])
            let changedRecovered = try replacing(chain.recovered) {
                var recovery = try XCTUnwrap($0["lostWorkerRecovery"] as? [String: Any])
                recovery["candidateRevision"] = String(repeating: "c", count: 40)
                $0["lostWorkerRecovery"] = recovery
            }
            try store.saveAssignment(changedRecovered, expected: chain.recovered)
            XCTAssertThrowsError(try producer.admitPrepared(pending),
                "Final admission must revalidate every relied-on recovered ancestor")
            XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
                taskID: pending.id).state, .preparing)
            await producer.finishPreparation(work: work, requestID: requestID)
        }
    }

    func testCompetingPreparationDuringRecoveredAncestryConfigurationStillBlocks() async throws {
        let (root, source, project, work, store) = try fixture()
        let chain = try await recoveredAncestorAndClosedSuccessor(root: root, source: source,
            project: project, work: work, store: store)
        let siblingID = "delivery-competing-preparation"
        let siblingPaths = try ProjectExecutionPaths(storageRoot: root,
            projectID: project.projectID.rawValue, taskID: siblingID)
        var sibling = ProjectExecutionAssignment(id: siblingID, registration: project.registration!,
            checkoutPath: siblingPaths.checkout.path, role: .delivery,
            permissionProfile: "rr-" + siblingID, model: "gpt-5.6-terra", effort: "medium",
            authorization: "Competing preparation",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .preparing,
            worktree: .init(checkout: siblingPaths.checkout.path,
                baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-project-one-" + siblingID,
                commonGitDirectory: source.path + "/.git", primaryRoot: source.path), work: work)
        sibling.codexContextID = try store.policy(projectID: project.projectID.rawValue).codexContextID
        let competingSibling = sibling
        let configuration = Configuration()
        await configuration.onHook { try store.saveAssignment(competingSibling, expected: nil) }
        let producer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: configuration, handlerPath: handler,
            provisioning: continuationProvisioning(source: source,
                recovered: chain.recovered, immediateParent: chain.successor))
        do {
            _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: nil, baselineFromAssignmentID: chain.successor.id,
                contextPaths: ["AGENTS.md"])
            XCTFail("A competing preparation discovered before finalization must block")
        } catch {}
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: siblingID), competingSibling)
        let hookChecks = await configuration.hookChecks
        XCTAssertEqual(hookChecks, 1, "The competing preparation fixture must occur after initial eligibility")
    }

    func testLostWorkerRecoveryRequiresProcessAndGrantEvidenceBeforeAnyStateWrite() async throws {
        let (root, source, project, work, store) = try fixture()
        let legacy = try legacyLostAssignment(root: root, source: source, project: project,
            work: work, store: store)
        let provisioning = Provisioning(source: source,
            candidate: URL(fileURLWithPath: legacy.checkoutPath))
        let unusedGrant = RecoveryGrantReconciler([.noMatchingGrant])
        let processUnavailable = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(), provisioning: provisioning,
            processObserver: RecoveryProcessObserver(evidence: nil, failure: .unavailable),
            grantReconciler: unusedGrant)
        do {
            _ = try await processUnavailable.recoverLostWorker(project: project,
                expected: legacy, requestID: UUID())
            XCTFail("Incomplete or suspicious process identity must block recovery")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .unavailable)
        }
        XCTAssertEqual(unusedGrant.calls, 0)
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: legacy.id), legacy)

        let grantUnavailable = RecoveryGrantReconciler([], failure: .unavailable)
        let noGrantProof = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(), provisioning: provisioning,
            processObserver: processObserver(for: legacy), grantReconciler: grantUnavailable)
        do {
            _ = try await noGrantProof.recoverLostWorker(project: project,
                expected: legacy, requestID: UUID())
            XCTFail("A no-match OS observation alone cannot establish complete closure")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .unavailable)
        }
        XCTAssertEqual(grantUnavailable.calls, 1)
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: legacy.id), legacy)
    }

    func testLostWorkerGrantReleaseBeforeCASIsSafelyReplayable() async throws {
        let (root, source, project, work, store) = try fixture()
        let legacy = try legacyLostAssignment(root: root, source: source, project: project,
            work: work, store: store)
        let provisioning = Provisioning(source: source,
            candidate: URL(fileURLWithPath: legacy.checkoutPath))
        let grants = RecoveryGrantReconciler([.matchingGrantReleased, .noMatchingGrant])
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(), provisioning: provisioning,
            processObserver: processObserver(for: legacy), grantReconciler: grants)
        let requestID = UUID()
        let gate = RecoveryValidationGate(failureCall: 2)

        do {
            _ = try await lifecycle.recoverLostWorker(project: project, expected: legacy,
                requestID: requestID, beforeWrite: { try gate.validate() })
            XCTFail("A concurrent state change after grant release must prevent the assignment CAS")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .conflict)
        }
        XCTAssertEqual(grants.calls, 1)
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: legacy.id), legacy)

        gate.allow()
        let recovered = try await lifecycle.recoverLostWorker(project: project,
            expected: legacy, requestID: requestID, beforeWrite: { try gate.validate() })
        XCTAssertEqual(grants.calls, 2)
        XCTAssertEqual(recovered.lostWorkerRecovery?.grantDisposition, .noMatchingGrant)
        XCTAssertEqual(recovered.lostWorkerRecovery?.requestID, requestID)
    }

    func testLostWorkerAuditCompletionReconcilesOnlyExactConcurrentReceipt() async throws {
        let (root, source, project, work, store) = try fixture()
        let legacy = try legacyLostAssignment(root: root, source: source, project: project,
            work: work, store: store)
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(),
            provisioning: Provisioning(source: source,
                candidate: URL(fileURLWithPath: legacy.checkoutPath)),
            processObserver: processObserver(for: legacy),
            grantReconciler: RecoveryGrantReconciler([.matchingGrantReleased]))
        let requestID = UUID()
        let pending = try await lifecycle.recoverLostWorker(project: project,
            expected: legacy, requestID: requestID)
        var completed = pending
        completed.lostWorkerRecovery?.auditCompleted = true
        let exact = RecoveryAuditCASInjector(store: store, expected: pending,
            replacement: completed)

        let reconciled = try await lifecycle.completeLostWorkerRecoveryAudit(
            project: project, expected: pending, requestID: requestID,
            beforeWrite: { try exact.validate() })
        XCTAssertEqual(reconciled, completed,
            "An exact competing audit completion must reconcile as success")

        try store.saveAssignment(pending, expected: completed)
        var conflicting = completed
        conflicting.lostWorkerRecovery?.auditCompleted = true
        let differentCandidate = String(repeating: "c", count: 40)
        let receipt = try XCTUnwrap(conflicting.lostWorkerRecovery)
        conflicting.lostWorkerRecovery = .init(requestID: receipt.requestID,
            priorState: receipt.priorState, candidateRevision: differentCandidate,
            process: receipt.process, grantDisposition: receipt.grantDisposition,
            auditCompleted: true)
        let conflict = RecoveryAuditCASInjector(store: store, expected: pending,
            replacement: conflicting)
        do {
            _ = try await lifecycle.completeLostWorkerRecoveryAudit(
                project: project, expected: pending, requestID: requestID,
                beforeWrite: { try conflict.validate() })
            XCTFail("A different receipt must remain a compare-and-swap conflict")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .conflict)
        }
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: pending.id), conflicting)
    }

    func testRecoveredWorkerCannotBePresentedAsDeliveredReviewCandidate() async throws {
        let (root, source, project, work, store) = try fixture()
        let legacy = try legacyLostAssignment(root: root, source: source, project: project,
            work: work, store: store)
        let checkout = URL(fileURLWithPath: legacy.checkoutPath)
        let provisioning = Provisioning(source: source, candidate: checkout)
        let lifecycle = ProjectExecutionResourceLifecycle(root: { root },
            configuration: CleanupConfiguration(), provisioning: provisioning,
            processObserver: processObserver(for: legacy),
            grantReconciler: RecoveryGrantReconciler([.noMatchingGrant]))
        let recovered = try await lifecycle.recoverLostWorker(project: project,
            expected: legacy, requestID: UUID())
        let producer = ProjectExecutionAssignmentCoordinator(root: { root },
            configuration: Configuration(), handlerPath: handler, provisioning: provisioning)

        do {
            _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: recovered.id, baselineFromAssignmentID: nil,
                contextPaths: ["AGENTS.md"])
            XCTFail("Recovered stopped work is a continuation parent, not a delivered review candidate")
        } catch let failure as ProjectExecutionPreparationFailure {
            XCTAssertEqual(failure.error, .assignmentNotAuthorized)
        }
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

    func testParentCandidateConflictReportsNarrowPreparationStage() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let base = Provisioning(source: source, candidate: nil)
        let deliveryProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: base)
        let deliveryRequestID = UUID()
        let pending = try await deliveryProducer.prepare(project: project, work: work,
            requestID: deliveryRequestID, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil,
            contextPaths: ["AGENTS.md"])
        let admitted = try deliveryProducer.admitPrepared(pending)
        await deliveryProducer.finishPreparation(work: work, requestID: deliveryRequestID)
        var closed = admitted
        closed.state = .closed
        closed.sessionID = "closed-delivery"
        try store.saveAssignment(closed, expected: admitted)

        let reviewProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: ConflictProvisioning(
                base: .init(source: source, candidate: URL(fileURLWithPath: closed.checkoutPath)),
                site: .parentCandidate))
        do {
            _ = try await reviewProducer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: closed.id, baselineFromAssignmentID: nil,
                contextPaths: ["AGENTS.md"])
            XCTFail("Parent candidate conflict must remain typed")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .causeUnavailable,
                stage: .parentCandidateValidation,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
    }

    func testTargetProvisioningConflictReportsNarrowPreparationStage() async throws {
        let (root, source, project, work, _) = try fixture()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: Configuration(),
            handlerPath: handler, provisioning: ConflictProvisioning(
                base: .init(source: source, candidate: nil), site: .targetPreparation))

        do {
            _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("Target provisioning conflict must remain typed")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .causeUnavailable,
                stage: .targetProvisioning,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
    }

    func testPreparedAssignmentConfigurationConflictReportsNarrowPreparationStage() async throws {
        let (root, source, project, work, _) = try fixture()
        let configuration = Configuration()
        await configuration.setProfileError(.conflict)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))

        do {
            _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("Prepared assignment configuration conflict must remain typed")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .causeUnavailable,
                stage: .preparedAssignmentConfiguration,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
    }

    func testAssignmentStoreIntegrityConflictReportsNarrowPreparationStage() async throws {
        let (root, source, project, work, _) = try fixture()
        try Data("{".utf8).write(to: root.appendingPathComponent("Projects/project-one/policy.json"))
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: Configuration(),
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))

        do {
            _ = try await producer.prepare(project: project, work: work, requestID: UUID(),
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("Assignment-store integrity conflict must remain typed")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .causeUnavailable,
                stage: .assignmentStoreIntegrity,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
    }

    func testAssignmentStoreCompareAndSwapConflictReportsNarrowPreparationStage() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let requestID = UUID()
        let assignmentID = "delivery-" + requestID.uuidString.lowercased()
        await configuration.onHook {
            let current = try store.assignment(projectID: project.projectID.rawValue, taskID: assignmentID)
            var changed = current
            changed.finalizationFailed = true
            try store.saveAssignment(changed, expected: current)
        }
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))

        do {
            _ = try await producer.prepare(project: project, work: work, requestID: requestID,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("Assignment-store compare-and-swap conflict must remain typed")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .causeUnavailable,
                stage: .assignmentStoreCompareAndSwap,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
        XCTAssertEqual(try store.assignment(projectID: project.projectID.rawValue,
            taskID: assignmentID).finalizationFailed, true)
    }

    func testNarrowPreparationStageWrapperPreservesNestedStoreStage() throws {
        do {
            let _: Void = try withProjectExecutionPreparationStage(.preparedAssignmentConfiguration) {
                let _: Void = try withProjectExecutionPreparationStage(.assignmentStoreCompareAndSwap) {
                    throw ProjectExecutionError.conflict
                }
            }
            XCTFail("Nested store stage must remain typed")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .causeUnavailable,
                stage: .assignmentStoreCompareAndSwap,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
    }

    func testRetiredParentRefusalRequiresAuthoritativeAbsenceOfEveryChildResource() async throws {
        for residual in ["none", "worktree", "profile"] {
            let (root, source, project, work, store) = try fixture()
            let parentID = "delivery-retired"
            let parentPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: parentID)
            var parent = ProjectExecutionAssignment(id: parentID, registration: project.registration!,
                checkoutPath: parentPaths.checkout.path, role: .delivery, permissionProfile: "rr-" + parentID,
                model: "gpt-5.6-terra", effort: "medium", authorization: "Previously approved work",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: .superseded, sessionID: "closed-session",
                worktree: .init(checkout: parentPaths.checkout.path, baseline: String(repeating: "a", count: 40),
                    branch: "codex/rr-project-one-" + parentID, commonGitDirectory: source.path + "/.git",
                    primaryRoot: source.path), work: work)
            parent.codexContextID = try store.policy(projectID: "project-one").codexContextID
            parent.connectionClosed = true
            var retirement = ProjectExecutionAssignment.Retirement(requestID: UUID(), priorState: .closed)
            retirement.worktreeRemoved = true; retirement.profileRemoved = true; retirement.completed = true
            parent.retirement = retirement
            try store.saveAssignment(parent, expected: nil)

            let configuration = Configuration()
            let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
                handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
            let requestID = UUID()
            do {
                _ = try await producer.prepare(project: project, work: work, requestID: requestID,
                    reviewOfAssignmentID: nil, baselineFromAssignmentID: parentID, contextPaths: ["AGENTS.md"])
                XCTFail("A retired parent cannot be replayed as a preparation baseline")
            } catch let failure as ProjectExecutionPreparationFailure {
                XCTAssertEqual(failure.error, .assignmentNotAuthorized)
            }

            let childID = "delivery-" + requestID.uuidString.lowercased()
            let childPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: childID)
            if residual == "worktree" {
                try FileManager.default.createDirectory(at: childPaths.checkout, withIntermediateDirectories: true)
            } else if residual == "profile" {
                await configuration.seedProfile("rr-" + childID)
            }
            let verified = try await producer.verifyNoPreparationEffects(project: project, work: work,
                requestID: requestID, reviewOfAssignmentID: nil, baselineFromAssignmentID: parentID)
            XCTAssertEqual(verified, residual == "none")
            let preparedProfiles = await configuration.profiles
            XCTAssertTrue(preparedProfiles.isEmpty, "Recovery inspection must not prepare a profile")
            let hookChecks = await configuration.hookChecks
            XCTAssertEqual(hookChecks, 0, "Recovery inspection must not configure the checkout")
            await producer.finishPreparation(work: work, requestID: requestID)
        }
    }

    func testTaskMismatchRefusalRequiresClosedParentAndAuthoritativeAbsenceOfEveryChildResource() async throws {
        for residual in ["none", "assignment", "worktree", "profile"] {
            let (root, source, project, work, store) = try fixture()
            let parentID = "delivery-other-task"
            let parentPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: parentID)
            let parentWork = ProjectExecutionWork(projectID: work.projectID, ticketID: work.ticketID,
                taskID: "other-task", outcome: work.outcome, title: "Other task",
                taskPlanRevision: work.taskPlanRevision, phaseID: work.phaseID,
                phaseRevision: work.phaseRevision, incarnationID: work.incarnationID)
            var parent = ProjectExecutionAssignment(id: parentID, registration: project.registration!,
                checkoutPath: parentPaths.checkout.path, role: .delivery, permissionProfile: "rr-" + parentID,
                model: "gpt-5.6-terra", effort: "medium", authorization: "Previously approved work",
                context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                state: .closed, sessionID: "closed-session",
                worktree: .init(checkout: parentPaths.checkout.path, baseline: String(repeating: "a", count: 40),
                    branch: "codex/rr-project-one-" + parentID, commonGitDirectory: source.path + "/.git",
                    primaryRoot: source.path), work: parentWork)
            parent.codexContextID = try store.policy(projectID: "project-one").codexContextID
            parent.connectionClosed = true
            try store.saveAssignment(parent, expected: nil)

            let configuration = Configuration()
            let provisioning = Provisioning(source: source, candidate: nil)
            let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
                handlerPath: handler, provisioning: provisioning)
            let requestID = UUID()
            do {
                _ = try await producer.prepare(project: project, work: work, requestID: requestID,
                    reviewOfAssignmentID: parentID, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
                XCTFail("A parent from another task cannot authorize review")
            } catch let failure as ProjectExecutionPreparationFailure {
                XCTAssertEqual(failure.error, .assignmentNotAuthorized)
            } catch {
                XCTFail("Task mismatch must use the typed pre-configuration path, got \(error)")
            }

            let childID = "review-" + requestID.uuidString.lowercased()
            let childPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: childID)
            if residual == "assignment" {
                var child = ProjectExecutionAssignment(id: childID, registration: project.registration!,
                    checkoutPath: childPaths.checkout.path, role: .review, permissionProfile: "rr-" + childID,
                    model: "gpt-5.6-terra", effort: "high", authorization: "Unexpected partial child",
                    context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                    excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                    state: .preparing, work: work, reviewOfAssignmentID: parentID)
                child.codexContextID = try store.policy(projectID: "project-one").codexContextID
                try store.saveAssignment(child, expected: nil)
            } else if residual == "worktree" {
                try FileManager.default.createDirectory(at: childPaths.checkout, withIntermediateDirectories: true)
            } else if residual == "profile" {
                await configuration.seedProfile("rr-" + childID)
            }

            let verified = try await producer.verifyNoPreparationEffects(project: project, work: work,
                requestID: requestID, reviewOfAssignmentID: parentID, baselineFromAssignmentID: nil)
            XCTAssertEqual(verified, residual == "none")
            let preparedProfiles = await configuration.profiles
            XCTAssertTrue(preparedProfiles.isEmpty,
                "Task-mismatch recovery inspection must not prepare a profile")
            let hookChecks = await configuration.hookChecks
            XCTAssertEqual(hookChecks, 0,
                "Task-mismatch recovery inspection must not configure the checkout")
            await producer.finishPreparation(work: work, requestID: requestID)
        }
    }

    func testTaskMismatchWithLiveParentOrUnreadableResourcesRemainsUnsettled() async throws {
        let (root, source, project, work, store) = try fixture()
        let parentID = "delivery-other-task"
        let parentPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: parentID)
        let parentWork = ProjectExecutionWork(projectID: work.projectID, ticketID: work.ticketID,
            taskID: "other-task", outcome: work.outcome, title: "Other task",
            taskPlanRevision: work.taskPlanRevision, phaseID: work.phaseID, phaseRevision: work.phaseRevision)
        var parent = ProjectExecutionAssignment(id: parentID, registration: project.registration!,
            checkoutPath: parentPaths.checkout.path, role: .delivery, permissionProfile: "rr-" + parentID,
            model: "gpt-5.6-terra", effort: "medium", authorization: "Live work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .authorized, sessionID: "live-session",
            worktree: .init(checkout: parentPaths.checkout.path, baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-project-one-" + parentID, commonGitDirectory: source.path + "/.git",
                primaryRoot: source.path), work: parentWork)
        parent.codexContextID = try store.policy(projectID: "project-one").codexContextID
        try store.saveAssignment(parent, expected: nil)
        let configuration = Configuration()
        let requestID = UUID()
        let liveProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        do {
            _ = try await liveProducer.prepare(project: project, work: work, requestID: requestID,
                reviewOfAssignmentID: parentID, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("A live mismatched parent must remain refused")
        } catch is ProjectExecutionPreparationFailure {
            XCTFail("A live parent cannot be classified as a definite no-effects mismatch")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .assignmentNotAuthorized)
        }

        var closed = parent
        closed.state = .closed
        closed.connectionClosed = true
        try store.saveAssignment(closed, expected: parent)
        let unreadableProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: UninspectableProvisioning(base: .init(source: source, candidate: nil)))
        let unreadableRequestID = UUID()
        do {
            _ = try await unreadableProducer.prepare(project: project, work: work, requestID: unreadableRequestID,
                reviewOfAssignmentID: parentID, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("A closed mismatched parent must refuse before effects")
        } catch let failure as ProjectExecutionPreparationFailure {
            XCTAssertEqual(failure.error, .assignmentNotAuthorized)
        }
        do {
            _ = try await unreadableProducer.verifyNoPreparationEffects(project: project, work: work,
                requestID: unreadableRequestID, reviewOfAssignmentID: parentID, baselineFromAssignmentID: nil)
            XCTFail("Unreadable provisioning state cannot prove absence")
        } catch {
            XCTAssertEqual(error as? ProjectExecutionError, .unavailable)
        }
        await unreadableProducer.finishPreparation(work: work, requestID: unreadableRequestID)
    }

    func testRetiredParentRefusesPersistedPreparingChildBeforeConfiguration() async throws {
        let (root, source, project, work, store) = try fixture()
        let parentID = "delivery-retired"
        let parentPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: parentID)
        var parent = ProjectExecutionAssignment(id: parentID, registration: project.registration!,
            checkoutPath: parentPaths.checkout.path, role: .delivery, permissionProfile: "rr-" + parentID,
            model: "gpt-5.6-terra", effort: "medium", authorization: "Previously approved work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .superseded, sessionID: "closed-session",
            worktree: .init(checkout: parentPaths.checkout.path, baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-project-one-" + parentID, commonGitDirectory: source.path + "/.git",
                primaryRoot: source.path), work: work)
        parent.codexContextID = try store.policy(projectID: "project-one").codexContextID
        parent.connectionClosed = true
        var retirement = ProjectExecutionAssignment.Retirement(requestID: UUID(), priorState: .closed)
        retirement.worktreeRemoved = true; retirement.profileRemoved = true; retirement.completed = true
        parent.retirement = retirement
        try store.saveAssignment(parent, expected: nil)

        let requestID = UUID()
        let childID = "delivery-" + requestID.uuidString.lowercased()
        let childPaths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: childID)
        let provisioning = Provisioning(source: source, candidate: nil)
        let tree = try provisioning.prepare(primaryRoot: source, checkout: childPaths.checkout,
            projectID: "project-one", taskID: childID, baseline: String(repeating: "a", count: 40))
        let contextBytes = try Data(contentsOf: source.appendingPathComponent("AGENTS.md"))
        let contextDigest = SHA256.hash(data: contextBytes).map { String(format: "%02x", $0) }.joined()
        var child = ProjectExecutionAssignment(id: childID, registration: project.registration!,
            checkoutPath: childPaths.checkout.path, role: .delivery, permissionProfile: "rr-" + childID,
            model: "gpt-5.6-terra", effort: "medium", authorization: "Approved child work",
            context: [.init(path: "AGENTS.md", digest: contextDigest)],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .preparing, worktree: tree, work: work, baselineFromAssignmentID: parentID)
        child.codexContextID = try store.policy(projectID: "project-one").codexContextID
        try store.saveAssignment(child, expected: nil)

        let configuration = Configuration()
        await configuration.seedProfile(child.permissionProfile)
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration,
            handlerPath: handler, provisioning: provisioning)
        do {
            _ = try await producer.prepare(project: project, work: work, requestID: requestID,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: parentID, contextPaths: ["AGENTS.md"])
            XCTFail("A partial child cannot resume from a retired parent")
        } catch let failure as ProjectExecutionPreparationFailure {
            XCTAssertEqual(failure.error, .assignmentNotAuthorized)
        } catch {
            XCTFail("Retired-parent refusal must use the typed pre-configuration path, got \(error)")
        }
        let preparedProfiles = await configuration.profiles
        XCTAssertTrue(preparedProfiles.isEmpty, "Retired-parent refusal must precede profile configuration")
        let hookChecks = await configuration.hookChecks
        XCTAssertEqual(hookChecks, 0, "Retired-parent refusal must precede hook configuration")
        let verified = try await producer.verifyNoPreparationEffects(project: project, work: work,
            requestID: requestID, reviewOfAssignmentID: nil, baselineFromAssignmentID: parentID)
        XCTAssertFalse(verified, "Persisted child effects must keep the request uncertain")
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: childID), child)
        await producer.finishPreparation(work: work, requestID: requestID)
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
        do {
            _ = try await producer.prepare(project: project, work: work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            XCTFail("Preparation must remain single-flight until finalization")
        } catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .preparationInProgress,
                blockingRequestID: nil,
                blockingAssignmentID: nil,
                evidence: .observedAtFailure
            ))
        }
        await producer.finishPreparation(work: work, requestID: request)
        let content = URL(fileURLWithPath: recovered.checkoutPath + "/.codex/owner.txt")
        try Data("preserve".utf8).write(to: content)
        let repeated = try await producer.prepare(project: project, work: work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(repeated, recovered)
        XCTAssertEqual(try String(contentsOf: content, encoding: .utf8), "preserve")
        await producer.finishPreparation(work: work, requestID: request)
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
        await producer.finishPreparation(work: work, requestID: request)
    }

    func testIndependentReviewUsesClosedDeliveryCandidateNotPrimaryHeadOrTaskCompletion() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let deliveryProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let deliveryRequestID = UUID()
        let delivery = try await deliveryProducer.prepare(project: project, work: work, requestID: deliveryRequestID, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        let admitted = try deliveryProducer.admitPrepared(delivery)
        await deliveryProducer.finishPreparation(work: work, requestID: deliveryRequestID)
        var closed = admitted; closed.state = .closed; closed.sessionID = "author-session"
        try store.saveAssignment(closed, expected: admitted)
        let candidate = URL(fileURLWithPath: delivery.checkoutPath)
        let reviewProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: candidate))
        let reviewRequestID = UUID()
        let review = try await reviewProducer.prepare(project: project, work: work, requestID: reviewRequestID, reviewOfAssignmentID: closed.id, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(review.role, .review); XCTAssertEqual(review.worktree?.baseline, String(repeating: "b", count: 40))
        XCTAssertNotEqual(review.checkoutPath, delivery.checkoutPath); XCTAssertNil(review.sessionID)
        XCTAssertEqual(review.reviewOfAssignmentID, delivery.id)
        XCTAssertEqual(review.reviewScratchVersion, ProjectExecutionAssignment.xcodeBuildScratchVersion)
        let profiles = await configuration.profiles
        XCTAssertEqual(profiles.last?.workspace["."], "read")
        XCTAssertEqual(profiles.last?.workspace[".build"], "write")
        await reviewProducer.finishPreparation(work: work, requestID: reviewRequestID)
    }

    func testMissingParentContextRequiresAuthoritativeAbsenceOfEveryReviewResource() async throws {
        for residual in ["none", "assignment", "worktree", "profile"] {
            let (root, source, project, work, store) = try fixture()
            let configuration = Configuration()
            let deliveryProducer = ProjectExecutionAssignmentCoordinator(root: { root },
                configuration: configuration, handlerPath: handler,
                provisioning: Provisioning(source: source, candidate: nil))
            let deliveryRequestID = UUID()
            let delivery = try await deliveryProducer.prepare(project: project, work: work,
                requestID: deliveryRequestID, reviewOfAssignmentID: nil,
                baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
            let admitted = try deliveryProducer.admitPrepared(delivery)
            await deliveryProducer.finishPreparation(work: work, requestID: deliveryRequestID)
            var closed = admitted
            closed.state = .closed
            closed.sessionID = "author-session"
            try store.saveAssignment(closed, expected: admitted)

            let currentBrief = source.appendingPathComponent("docs/current-brief.md")
            try FileManager.default.createDirectory(at: currentBrief.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try Data("Current controlling brief".utf8).write(to: currentBrief)

            let reviewProducer = ProjectExecutionAssignmentCoordinator(root: { root },
                configuration: configuration, handlerPath: handler,
                provisioning: Provisioning(source: source,
                    candidate: URL(fileURLWithPath: closed.checkoutPath)))
            let reviewRequestID = UUID()
            do {
                _ = try await reviewProducer.prepare(project: project, work: work,
                    requestID: reviewRequestID, reviewOfAssignmentID: closed.id,
                    baselineFromAssignmentID: nil,
                    contextPaths: ["AGENTS.md", "docs/current-brief.md"])
                XCTFail("A review cannot prepare when its closed candidate lacks selected context")
            } catch let failure as ProjectExecutionPreparationFailure {
                XCTAssertEqual(failure.error, .assignmentNotAuthorized)
            } catch {
                XCTFail("Missing candidate context must use the typed no-effects path, got \(error)")
            }

            let childID = "review-" + reviewRequestID.uuidString.lowercased()
            let childPaths = try ProjectExecutionPaths(storageRoot: root,
                projectID: "project-one", taskID: childID)
            if residual == "assignment" {
                var child = ProjectExecutionAssignment(id: childID, registration: project.registration!,
                    checkoutPath: childPaths.checkout.path, role: .review,
                    permissionProfile: "rr-" + childID, model: "gpt-5.6-terra", effort: "high",
                    authorization: "Unexpected partial review",
                    context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
                    excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
                    state: .preparing, work: work, reviewOfAssignmentID: closed.id)
                child.codexContextID = try store.policy(projectID: "project-one").codexContextID
                try store.saveAssignment(child, expected: nil)
            } else if residual == "worktree" {
                try FileManager.default.createDirectory(at: childPaths.checkout,
                    withIntermediateDirectories: true)
            } else if residual == "profile" {
                await configuration.seedProfile("rr-" + childID)
            }

            let verified = try await reviewProducer.verifyNoPreparationEffects(project: project,
                work: work, requestID: reviewRequestID, reviewOfAssignmentID: closed.id,
                baselineFromAssignmentID: nil)
            XCTAssertEqual(verified, residual == "none")
            let preparedProfiles = await configuration.profiles
            XCTAssertEqual(preparedProfiles.count, 1,
                "Recovery inspection must not prepare an additional profile")
            let hookChecks = await configuration.hookChecks
            XCTAssertEqual(hookChecks, 1,
                "Recovery inspection must not configure an additional checkout")
            await reviewProducer.finishPreparation(work: work, requestID: reviewRequestID)
        }
    }

    func testFreshRequestCannotReplaceUnknownLaunchOrReviewLiveWriter() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let deliveryRequestID = UUID()
        let delivery = try await producer.prepare(project: project, work: work, requestID: deliveryRequestID, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: delivery.id, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("Live writer must not become a review candidate") }
        catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic.kind, .preparationInProgress)
            XCTAssertNil(conflict.diagnostic.blockingRequestID)
            XCTAssertNil(conflict.diagnostic.blockingAssignmentID)
        }
        await producer.finishPreparation(work: work, requestID: deliveryRequestID)
        var unknown = delivery; unknown.state = .unknown
        try store.saveAssignment(unknown, expected: delivery)
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("A new request must not replace an unknown launch") }
        catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic, .init(
                kind: .blockingAssignment,
                blockingRequestID: nil,
                blockingAssignmentID: delivery.id,
                evidence: .observedAtFailure
            ))
        }
        XCTAssertEqual(try store.assignments(projectID: "project-one").count, 1)
    }

    func testRevokedFinalizationCanResumeOnlyExactUnlaunchedRequest() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let producer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let request = UUID()
        let prepared = try await producer.prepare(project: project, work: work, requestID: request, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        try producer.revokePreparation(prepared)
        await producer.finishPreparation(work: work, requestID: request)
        let revoked = try store.assignment(projectID: "project-one", taskID: prepared.id)
        XCTAssertEqual(revoked.state, .revoked)
        do { _ = try await producer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"]); XCTFail("A different request cannot replace failed finalization") }
        catch let conflict as ProjectExecutionPreparationConflict {
            XCTAssertEqual(conflict.diagnostic.kind, .blockingAssignment)
            XCTAssertEqual(conflict.diagnostic.blockingAssignmentID, prepared.id)
        }
        let resumed = try await producer.prepare(project: project, work: work, requestID: request, reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        XCTAssertEqual(resumed.id, prepared.id); XCTAssertEqual(resumed.state, .preparing)
        await producer.finishPreparation(work: work, requestID: request)
    }
}
