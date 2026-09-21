import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionOnboardingTests: XCTestCase {
    actor Setup: ProjectExecutionSettingUp {
        var fails = true
        var prepareCount = 0
        var verifyCount = 0
        func prepare(project: AuthorizedProject) throws { prepareCount += 1; if fails { throw ProjectExecutionError.hookNotReady } }
        func verify(project: AuthorizedProject) throws { verifyCount += 1; if fails { throw ProjectExecutionError.hookNotReady } }
        func recover() { fails = false }
    }
    struct Discovery: GitWorktreeDiscovering { func discoverWorktrees(at folder: URL) -> [URL] { [folder] } }
    private struct RecoveryProvisioning: ExecutionWorktreeProvisioning {
        let candidateRevisionValue: String
        func revision(at root: URL, requireClean: Bool) -> String { candidateRevisionValue }
        func candidateRevision(worktree: ExecutionWorktree) -> String { candidateRevisionValue }
        func prepare(primaryRoot: URL, checkout: URL, projectID: String, taskID: String,
                     baseline: String) throws -> ExecutionWorktree { throw ProjectExecutionError.unavailable }
        func remove(primaryRoot: URL, worktree: ExecutionWorktree, projectID: String,
                    taskID: String) throws { throw ProjectExecutionError.unavailable }
    }
    private struct RecoveryProcessObserver: ProjectExecutionWorkerProcessObserving {
        func verifiedAbsence(for assignment: ProjectExecutionAssignment) throws
            -> ProjectExecutionAssignment.LostWorkerProcessEvidence {
            .init(version: 1, observedAt: Date(timeIntervalSince1970: 1_790_049_600),
                executablePath: CodexExecutionIdentity.executable,
                permissionProfile: assignment.permissionProfile,
                argumentMarker: "permissions.\(assignment.permissionProfile).network.enabled=false")
        }
    }
    private final class RecoveryGrantReconciler: ProjectExecutionContextGrantReconciling,
                                                 @unchecked Sendable {
        private let lock = NSLock()
        private(set) var calls = 0
        func reconcileLostWorkerGrant(for assignment: ProjectExecutionAssignment) throws
            -> ProjectExecutionAssignment.LostWorkerRecovery.GrantDisposition {
            try lock.withLock {
                calls += 1
                guard calls == 1 else { throw ProjectExecutionError.unavailable }
                return .matchingGrantReleased
            }
        }
    }

    func testLostWorkerPostCASAuditFailureReplaysExactReceiptWithoutRepeatingRecovery() async throws {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        let repository = base.appendingPathComponent("Repository")
        let execution = base.appendingPathComponent("Execution")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"),
            registrationID: "registration-one", requestGeneration: 1)
        let delivery = DeliveryStore(databaseURL: base.appendingPathComponent("fixture.sqlite"))
        try await delivery.transact(actor: .init(id: "fixture"), reason: "Seed recovery owner") { connection in
            try connection.execute("INSERT INTO projects(id,name) VALUES ('project-one','Fixture')")
            try connection.execute("INSERT INTO project_roots(id,project_id,path) VALUES ('root-one','project-one',?)",
                bindings: [.text(repository.path)])
            try connection.execute("INSERT INTO project_bookmarks(project_id,path,bookmark_data,is_stale) VALUES ('project-one',?,?,0)",
                bindings: [.text(repository.path), .blob(Data([1]))])
            try connection.execute("INSERT INTO project_registrations(project_id,registration_id,request_generation,setup_state) VALUES ('project-one','registration-one',1,'complete')")
        }
        let auditFault = try SQLiteConnection(url: delivery.databaseURL, createIfMissing: false)
        try auditFault.execute("""
            CREATE TRIGGER fail_lost_worker_success_audit BEFORE INSERT ON audit_events
            WHEN NEW.reason LIKE 'Lost worker connection recovered:%'
            BEGIN SELECT RAISE(ABORT, 'synthetic recovery audit failure'); END
            """)
        let bookmarks = ProjectBookmarkStore(
            resolver: { _ in .init(url: repository, isStale: false) },
            startAccessing: { _ in true }, stopAccessing: { _ in })
        let onboarding = FolderProjectOnboarding(store: delivery, bookmarkStore: bookmarks)
        let files = try ProjectExecutionFileStore(root: execution, create: true)
        let context = try CodexExecutionContext(home: execution, bookmark: Data([1]))
        try files.saveCodexContext(context, expected: nil)
        var policy = ProjectExecutionPolicy(registration: registration,
            primaryRoot: repository.path, appServerExecutable: CodexExecutionIdentity.executable,
            handlerPath: "/RR/handler")
        policy.consent = .init(); policy.codexContextID = context.id
        try files.savePolicy(policy, expected: nil)
        let paths = try ProjectExecutionPaths(storageRoot: execution,
            projectID: registration.projectID.rawValue, taskID: "delivery-lost")
        let candidateRevision = String(repeating: "b", count: 40)
        var assignment = ProjectExecutionAssignment(id: "delivery-lost", registration: registration,
            checkoutPath: paths.checkout.path, role: .delivery, permissionProfile: "rr-delivery-lost",
            model: "gpt-5.6-terra", effort: "medium", authorization: "Approved recovery fixture",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"],
            state: .authorized, sessionID: "lost-session",
            worktree: .init(checkout: paths.checkout.path, baseline: String(repeating: "a", count: 40),
                branch: "codex/rr-project-one-delivery-lost",
                commonGitDirectory: repository.path + "/.git", primaryRoot: repository.path),
            work: .init(projectID: registration.projectID, ticketID: "manage-project", taskID: "task-02",
                outcome: "Relocate controls", title: "Manage Project Task02",
                taskPlanRevision: 1, phaseID: "phase-six", phaseRevision: 1))
        assignment.codexContextID = context.id; assignment.launchReserved = true
        try files.saveAssignment(assignment, expected: nil)
        let grants = RecoveryGrantReconciler()
        let resources = ProjectExecutionResourceLifecycle(root: { execution },
            configuration: ProjectExecutionSetupTests.Configuration(),
            provisioning: RecoveryProvisioning(candidateRevisionValue: candidateRevision),
            processObserver: RecoveryProcessObserver(), grantReconciler: grants)

        do {
            try await onboarding.recoverLostWorker(registration: registration,
                expected: assignment, resources: resources)
            XCTFail("A failed success audit must remain visible after the recovery CAS")
        } catch {}
        let recovered = try files.assignment(projectID: registration.projectID.rawValue,
            taskID: assignment.id)
        let receipt = try XCTUnwrap(recovered.lostWorkerRecovery)
        XCTAssertEqual(recovered.state, .stopped)
        XCTAssertEqual(recovered.connectionClosed, true)
        XCTAssertEqual(recovered.uncertainOutcome, true)
        XCTAssertEqual(receipt.candidateRevision, candidateRevision)
        XCTAssertNotEqual(receipt.auditCompleted, true)
        XCTAssertEqual(grants.calls, 1)
        let failedAuditCounts = try await delivery.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Lost worker recovery requested:%'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Lost worker connection recovered:%'")
            )
        }
        XCTAssertEqual(failedAuditCounts.0, 1)
        XCTAssertEqual(failedAuditCounts.1, 0)

        try auditFault.execute("DROP TRIGGER fail_lost_worker_success_audit")
        try await onboarding.recoverLostWorker(registration: registration,
            expected: recovered, resources: resources)
        let reconciled = try files.assignment(projectID: registration.projectID.rawValue,
            taskID: assignment.id)
        XCTAssertEqual(reconciled.lostWorkerRecovery?.requestID, receipt.requestID)
        XCTAssertEqual(reconciled.lostWorkerRecovery?.candidateRevision, receipt.candidateRevision)
        XCTAssertEqual(reconciled.lostWorkerRecovery?.process, receipt.process)
        XCTAssertEqual(reconciled.lostWorkerRecovery?.grantDisposition, receipt.grantDisposition)
        XCTAssertEqual(reconciled.lostWorkerRecovery?.auditCompleted, true)
        XCTAssertEqual(grants.calls, 1, "Audit replay must not repeat grant release")
        var auditCounts = try await delivery.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Lost worker recovery requested:%'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Lost worker connection recovered:%'")
            )
        }
        XCTAssertEqual(auditCounts.0, 1)
        XCTAssertEqual(auditCounts.1, 1)

        try await onboarding.recoverLostWorker(registration: registration,
            expected: reconciled, resources: resources)
        auditCounts = try await delivery.read { connection in
            (
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Lost worker recovery requested:%'"),
                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason LIKE 'Lost worker connection recovered:%'")
            )
        }
        XCTAssertEqual(auditCounts.0, 1)
        XCTAssertEqual(auditCounts.1, 1)
        XCTAssertEqual(grants.calls, 1)
        let replayed = try XCTUnwrap(try files.assignment(projectID: registration.projectID.rawValue,
            taskID: assignment.id).lostWorkerRecovery)
        XCTAssertEqual(replayed.requestID, receipt.requestID)
        XCTAssertEqual(replayed.candidateRevision, receipt.candidateRevision)
        XCTAssertEqual(replayed.process, receipt.process)
        XCTAssertEqual(replayed.grantDisposition, receipt.grantDisposition)
        XCTAssertEqual(replayed.auditCompleted, true)
    }

    func testRemovedProjectReaddUsesNewRegistrationAndVerifiedOwnedHook() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let repository = root.appendingPathComponent("Repository")
        let execution = root.appendingPathComponent("Execution")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("fixture.sqlite"), executionAssignmentRoot: { execution })
        let configuration = ProjectExecutionSetupTests.Configuration(); await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { execution }, configuration: configuration, handlerPath: "/RR/handler")
        let onboarding = FolderProjectOnboarding(store: store, worktreeDiscovery: Discovery(), executionSetup: setup)
        let original = try await onboarding.inspect(folder: repository)
        let first = OnboardingDecision(preview: original, projectName: "Original", enableExecutionSetup: true)
        _ = try await onboarding.prepare(first); _ = try await onboarding.finish(first)
        let hook = try ProjectExecutionFileStore(root: repository, create: false).hookConfiguration()
        let removal = ProjectRemovalManager(store: store)
        let preview = try await removal.preview(projectID: original.registration.projectID)
        _ = try await removal.apply(preview)
        let files = try ProjectExecutionFileStore(root: execution, create: false)
        XCTAssertFalse(try files.policy(projectID: original.registration.projectID.rawValue).enabled)
        let readd = try await onboarding.inspect(folder: repository)
        XCTAssertNotEqual(readd.registration.projectID, original.registration.projectID)
        XCTAssertNotEqual(readd.registration.registrationID, original.registration.registrationID)
        let next = OnboardingDecision(preview: readd, projectName: "Re-added", enableExecutionSetup: true)
        _ = try await onboarding.prepare(next); _ = try await onboarding.finish(next)
        XCTAssertEqual(try files.policy(projectID: readd.registration.projectID.rawValue).previousProjectIDs, [original.registration.projectID.rawValue])
        XCTAssertEqual(try ProjectExecutionFileStore(root: repository, create: false).hookConfiguration(), hook)
        XCTAssertFalse(try files.policy(projectID: original.registration.projectID.rawValue).enabled)
    }

    func testFailedExecutionSetupRemainsPendingAndSameRegistrationResumes() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = DeliveryStore(databaseURL: root.appendingPathComponent("fixture.sqlite"))
        let setup = Setup()
        let onboarding = FolderProjectOnboarding(store: store, worktreeDiscovery: Discovery(), executionSetup: setup)
        let preview = try await onboarding.inspect(folder: root)
        let decision = OnboardingDecision(preview: preview, projectName: "Execution fixture", enableExecutionSetup: true)
        do { _ = try await onboarding.prepare(decision); XCTFail("Setup must not claim readiness") }
        catch let error as OnboardingPreparationError {
            guard case let .executionSetupFailedAfterSave(savedID, _) = error else { return XCTFail("Wrong pending recovery error") }
            XCTAssertEqual(savedID, preview.registration.projectID)
        }
        let pending = try await onboarding.inspect(folder: root)
        XCTAssertEqual(pending.pendingProjectID, preview.registration.projectID)
        let resumedDecision = OnboardingDecision(preview: pending, projectName: "Execution fixture", enableExecutionSetup: true)
        do { _ = try await onboarding.prepare(resumedDecision); XCTFail("A repeated failed resume must report its outcome.") }
        catch let error as OnboardingPreparationError {
            guard case let .executionSetupFailedAfterSave(savedID, detail) = error else { return XCTFail("Wrong retry error") }
            XCTAssertEqual(savedID, preview.registration.projectID)
            XCTAssertEqual(detail, ProjectExecutionError.hookNotReady.localizedDescription)
        }
        let stillPending = try await onboarding.inspect(folder: root)
        XCTAssertEqual(stillPending.registration, pending.registration)
        XCTAssertEqual(stillPending.pendingProjectID, pending.pendingProjectID)
        XCTAssertNil(stillPending.completedProjectID)
        do { _ = try await onboarding.finish(decision); XCTFail("Unverified setup must not finish") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .hookNotReady) }
        await setup.recover()
        let prepared = try await onboarding.prepare(decision)
        XCTAssertEqual(prepared, preview.registration.projectID)
        let completed = try await onboarding.finish(decision)
        XCTAssertEqual(completed, prepared)
        let counts = await (setup.prepareCount, setup.verifyCount)
        XCTAssertEqual(counts.0, 3); XCTAssertEqual(counts.1, 2)
    }
}
