import CLibGit2
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ExecutionWorktreeTests: XCTestCase {
    private func check(_ result: Int32) throws {
        guard result >= 0 else {
            throw StoreError.unavailable(git_error_last().flatMap { $0.pointee.message }.map { String(cString: $0) } ?? "Native fixture failed")
        }
    }
    private func head(at root: URL) throws -> (revision: String, branch: String) {
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        var repository: OpaquePointer?; try check(git_repository_open(&repository, root.path)); defer { git_repository_free(repository) }
        var head: OpaquePointer?; try check(git_repository_head(&head, repository)); defer { git_reference_free(head) }
        return (String(cString: git_oid_tostr_s(git_reference_target(head))), String(cString: git_reference_shorthand(head)))
    }
    private func fixture() throws -> (root: URL, checkout: URL, baseline: String) {
        let parent = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let root = parent.appendingPathComponent("primary")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        var repository: OpaquePointer?; try check(git_repository_init(&repository, root.path, 0)); defer { git_repository_free(repository) }
        try Data("baseline".utf8).write(to: root.appendingPathComponent("source.txt"))
        var index: OpaquePointer?; try check(git_repository_index(&index, repository)); defer { git_index_free(index) }
        try check(git_index_add_bypath(index, "source.txt")); try check(git_index_write(index))
        var treeID = git_oid(); try check(git_index_write_tree(&treeID, index))
        var tree: OpaquePointer?; try check(git_tree_lookup(&tree, repository, &treeID)); defer { git_tree_free(tree) }
        var signature: UnsafeMutablePointer<git_signature>?
        try check(git_signature_new(&signature, "Fixture", "fixture@example.invalid", 1_700_000_000, 0)); defer { git_signature_free(signature) }
        var commitID = git_oid()
        try check(git_commit_create(&commitID, repository, "HEAD", signature, signature, nil, "Fixture baseline", tree, 0, nil))
        return (root, parent.appendingPathComponent("worktrees/task-one"), String(cString: git_oid_tostr_s(&commitID)))
    }
    private func commitChange(at root: URL, path: String, contents: String,
                              message: String) throws -> String {
        try Data(contents.utf8).write(to: root.appendingPathComponent(path))
        try check(git_libgit2_init()); defer { git_libgit2_shutdown() }
        var repository: OpaquePointer?
        try check(git_repository_open(&repository, root.path)); defer { git_repository_free(repository) }
        var index: OpaquePointer?
        try check(git_repository_index(&index, repository)); defer { git_index_free(index) }
        try check(git_index_add_bypath(index, path)); try check(git_index_write(index))
        var treeID = git_oid(); try check(git_index_write_tree(&treeID, index))
        var tree: OpaquePointer?
        try check(git_tree_lookup(&tree, repository, &treeID)); defer { git_tree_free(tree) }
        var head: OpaquePointer?
        try check(git_repository_head(&head, repository)); defer { git_reference_free(head) }
        var parent: OpaquePointer?
        try check(git_commit_lookup(&parent, repository, git_reference_target(head)))
        defer { git_commit_free(parent) }
        var signature: UnsafeMutablePointer<git_signature>?
        try check(git_signature_new(&signature, "Fixture", "fixture@example.invalid",
            1_700_000_001, 0)); defer { git_signature_free(signature) }
        var commitID = git_oid()
        try withUnsafeMutablePointer(to: &parent) { parents in
            try check(git_commit_create(&commitID, repository, "HEAD", signature, signature,
                nil, message, tree, 1, parents))
        }
        return String(cString: git_oid_tostr_s(&commitID))
    }
    func testNativeCreationUsesExactCommittedBaselineAndRefusesDirtyReuseOrRemoval() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        XCTAssertEqual(tree.baseline, fixture.baseline)
        XCTAssertEqual(try head(at: fixture.checkout).revision, fixture.baseline)
        XCTAssertEqual(try head(at: fixture.checkout).branch, "codex/rr-project-one-task-one")
        XCTAssertEqual(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline), tree)
        try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.checkout.path))
        try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one")
        XCTAssertEqual(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline), tree)
        let wrongIdentity = ExecutionWorktree(checkout: tree.checkout, baseline: tree.baseline, branch: "codex/unowned",
            commonGitDirectory: tree.commonGitDirectory, primaryRoot: tree.primaryRoot)
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: wrongIdentity, projectID: "project-one", taskID: "task-one"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.checkout.path))
        try Data("owner edit".utf8).write(to: fixture.checkout.appendingPathComponent("source.txt"))
        XCTAssertThrowsError(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline))
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one"))
        XCTAssertEqual(try String(contentsOf: fixture.checkout.appendingPathComponent("source.txt"), encoding: .utf8), "owner edit")
    }
    func testDestinationCollisionInvalidRevisionAndMismatchedRemovalStayBounded() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        try FileManager.default.createDirectory(at: fixture.checkout, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: fixture.checkout.appendingPathComponent("owner.txt"))
        XCTAssertThrowsError(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline))
        XCTAssertThrowsError(try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: "main~1"))
        XCTAssertEqual(try String(contentsOf: fixture.checkout.appendingPathComponent("owner.txt"), encoding: .utf8), "keep")
    }

    func testPreparationResourceInspectionCoversAbsentBranchWorktreeCheckoutAndInvalidState() throws {
        let fixture = try fixture()
        let provisioner = LibGit2WorktreeProvisioner()
        let absent = fixture.checkout.deletingLastPathComponent().appendingPathComponent("absent")
        XCTAssertFalse(try provisioner.hasPreparedResources(primaryRoot: fixture.root, checkout: absent,
            projectID: "project-one", taskID: "absent"))

        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout,
            projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        XCTAssertTrue(try provisioner.hasPreparedResources(primaryRoot: fixture.root, checkout: fixture.checkout,
            projectID: "project-one", taskID: "task-one"), "A registered worktree is a preparation effect")
        try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.checkout.path))
        XCTAssertTrue(try provisioner.hasPreparedResources(primaryRoot: fixture.root, checkout: fixture.checkout,
            projectID: "project-one", taskID: "task-one"), "The retained branch is still a preparation effect")

        let checkoutOnly = fixture.checkout.deletingLastPathComponent().appendingPathComponent("checkout-only")
        try FileManager.default.createDirectory(at: checkoutOnly, withIntermediateDirectories: true)
        XCTAssertTrue(try provisioner.hasPreparedResources(primaryRoot: fixture.root, checkout: checkoutOnly,
            projectID: "project-one", taskID: "checkout-only"), "An orphaned checkout path must fail closed")

        let aliased = fixture.checkout.deletingLastPathComponent().appendingPathComponent("aliased")
        try FileManager.default.createSymbolicLink(at: aliased, withDestinationURL: fixture.root)
        XCTAssertThrowsError(try provisioner.hasPreparedResources(primaryRoot: fixture.root, checkout: aliased,
            projectID: "project-one", taskID: "aliased"), "A symlinked resource path cannot prove absence")
        let notRepository = fixture.root.deletingLastPathComponent().appendingPathComponent("not-a-repository")
        try FileManager.default.createDirectory(at: notRepository, withIntermediateDirectories: true)
        XCTAssertThrowsError(try provisioner.hasPreparedResources(primaryRoot: notRepository,
            checkout: notRepository.appendingPathComponent("worktree"), projectID: "project-one", taskID: "unreadable"),
            "Unavailable Git metadata cannot prove absence")
    }

    func testUntrackedDataAndWrongCommonGitIdentityCannotBePruned() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        let wrong = ExecutionWorktree(checkout: tree.checkout, baseline: tree.baseline, branch: tree.branch,
            commonGitDirectory: tree.commonGitDirectory + "-other", primaryRoot: tree.primaryRoot)
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: wrong, projectID: "project-one", taskID: "task-one"))
        try Data("untracked owner data".utf8).write(to: fixture.checkout.appendingPathComponent("owner.txt"))
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one"))
        XCTAssertEqual(try String(contentsOf: fixture.checkout.appendingPathComponent("owner.txt"), encoding: .utf8), "untracked owner data")
    }

    func testIgnoredOwnerContentBlocksPruningAndRemainsIntact() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout, projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent(".git/info"), withIntermediateDirectories: true)
        try Data(".env\nignored-data/\n".utf8).write(to: fixture.root.appendingPathComponent(".git/info/exclude"))
        let ignored = fixture.checkout.appendingPathComponent(".env")
        let contents = Data("fixture owner content, not credentials".utf8)
        try contents.write(to: ignored)
        XCTAssertThrowsError(try provisioner.remove(primaryRoot: fixture.root, worktree: tree, projectID: "project-one", taskID: "task-one"))
        XCTAssertEqual(try Data(contentsOf: ignored), contents)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.checkout.path))
        XCTAssertEqual(try head(at: fixture.checkout).revision, fixture.baseline)
    }

    func testIgnoredBuildArtifactsDoNotBlockCandidateRevision() throws {
        let fixture = try fixture(); let provisioner = LibGit2WorktreeProvisioner()
        let tree = try provisioner.prepare(primaryRoot: fixture.root, checkout: fixture.checkout,
            projectID: "project-one", taskID: "task-one", baseline: fixture.baseline)
        try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent(".git/info"), withIntermediateDirectories: true)
        try Data(".build/\nDerivedData/\ndefault.profraw\n".utf8).write(to: fixture.root.appendingPathComponent(".git/info/exclude"))
        let buildOutput = fixture.checkout.appendingPathComponent(".build/test-output/result")
        let derivedOutput = fixture.checkout.appendingPathComponent("DerivedData/Build/result")
        try FileManager.default.createDirectory(at: buildOutput.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: derivedOutput.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("build output".utf8).write(to: buildOutput)
        try Data("derived output".utf8).write(to: derivedOutput)
        try Data("profile output".utf8).write(to: fixture.checkout.appendingPathComponent("default.profraw"))

        XCTAssertEqual(try provisioner.candidateRevision(worktree: tree), fixture.baseline)
        try Data("tracked edit".utf8).write(to: fixture.checkout.appendingPathComponent("source.txt"))
        XCTAssertThrowsError(try provisioner.candidateRevision(worktree: tree)) {
            XCTAssertEqual($0 as? ProjectExecutionError, .conflict)
        }
        try Data("baseline".utf8).write(to: fixture.checkout.appendingPathComponent("source.txt"))
        XCTAssertEqual(try provisioner.candidateRevision(worktree: tree), fixture.baseline)
        try Data("untracked owner data".utf8).write(to: fixture.checkout.appendingPathComponent("owner.txt"))
        XCTAssertThrowsError(try provisioner.candidateRevision(worktree: tree)) {
            XCTAssertEqual($0 as? ProjectExecutionError, .conflict)
        }
    }

    private func executionFixture(_ fixture: (root: URL, checkout: URL, baseline: String)) throws
        -> (root: URL, project: AuthorizedProject, work: ProjectExecutionWork, store: ProjectExecutionFileStore) {
        let root = fixture.root.deletingLastPathComponent().appendingPathComponent("Execution")
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let handler = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator"
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: fixture.root.path,
            appServerExecutable: CodexExecutionIdentity.executable, handlerPath: handler)
        policy.codexContextID = context.id; policy.consent = .init()
        policy.hookReceipt = .init(command: "\"" + handler + "\" --hook", inline: false,
            beforeDigest: nil, intendedDigest: String(repeating: "a", count: 64), installed: true)
        try store.savePolicy(policy, expected: nil)
        let work = ProjectExecutionWork(projectID: registration.projectID, ticketID: "ticket-one", taskID: "work-one",
            outcome: "Bounded outcome", title: "Approved task", taskPlanRevision: 1, phaseID: "phase-one", phaseRevision: 1)
        return (root, .init(registration: registration, canonicalRoot: fixture.root, authorizedRoots: [fixture.root]), work, store)
    }

    func testNativeUntrackedPrimaryHookLeavesEmptyLinkedLayerForFreshAndExactRecovery() async throws {
        for recovery in [false, true] {
            let fixture = try fixture()
            let execution = try executionFixture(fixture)
            let handler = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator"
            let hook = try ProjectExecutionHookRegistration.merge(nil, command: "\"" + handler + "\" --hook", previousCommand: nil)
            let primary = try ProjectExecutionFileStore(root: fixture.root, create: false)
            try primary.saveHookConfiguration(hook, expected: nil) // Untracked, after the committed baseline.
            let configuration = ProjectExecutionProducerTests.Configuration()
            await configuration.requireLayer()
            if recovery { await configuration.setFailure(true) }
            let producer = ProjectExecutionAssignmentCoordinator(root: { execution.root }, configuration: configuration,
                handlerPath: handler, provisioning: LibGit2WorktreeProvisioner())
            let request = UUID()
            var pending: ProjectExecutionAssignment?
            if recovery {
                do { _ = try await producer.prepare(project: execution.project, work: execution.work, requestID: request,
                    reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["source.txt"]); XCTFail("Expected pending profile failure") }
                catch { XCTAssertEqual(error as? ProjectExecutionError, .hookNotReady) }
                pending = try XCTUnwrap(execution.store.assignments(projectID: "project-one").first)
                XCTAssertFalse(FileManager.default.fileExists(atPath: pending!.checkoutPath + "/.codex"))
                await configuration.setFailure(false)
            }
            let prepared = try await producer.prepare(project: execution.project, work: execution.work, requestID: request,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["source.txt"])
            XCTAssertEqual(prepared.worktree?.baseline, fixture.baseline)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: prepared.checkoutPath + "/.codex"), [])
            XCTAssertEqual(try primary.hookConfiguration(), hook)
            XCTAssertEqual(try LibGit2WorktreeProvisioner().candidateRevision(worktree: XCTUnwrap(prepared.worktree)), fixture.baseline)
            if let pending {
                XCTAssertEqual(prepared.id, pending.id); XCTAssertEqual(prepared.worktree, pending.worktree)
                XCTAssertEqual(prepared.context, pending.context); XCTAssertEqual(prepared.codexContextID, pending.codexContextID)
                XCTAssertEqual(prepared.permissionProfileDefinition, pending.permissionProfileDefinition)
            }
        }
    }

    func testNativeRecoveredAncestorUsesCleanClosedSuccessorCandidateAndRejectsDrift() async throws {
        for dirtyRecoveredAncestor in [false, true] {
            let fixture = try fixture()
            let execution = try executionFixture(fixture)
            let handler = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator"
            let provisioning = LibGit2WorktreeProvisioner()
            let producer = ProjectExecutionAssignmentCoordinator(root: { execution.root },
                configuration: ProjectExecutionProducerTests.Configuration(),
                handlerPath: handler, provisioning: provisioning)

            let originalRequest = UUID()
            let originalPending = try await producer.prepare(project: execution.project,
                work: execution.work, requestID: originalRequest,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: nil,
                contextPaths: ["source.txt"])
            let originalAdmitted = try producer.admitPrepared(originalPending)
            await producer.finishPreparation(work: execution.work, requestID: originalRequest)
            var recovered = originalAdmitted
            recovered.state = .stopped
            recovered.sessionID = "recovered-session"
            recovered.connectionClosed = true
            recovered.launchReserved = true
            recovered.uncertainOutcome = true
            recovered.lostWorkerRecovery = .init(requestID: UUID(), priorState: .authorized,
                candidateRevision: fixture.baseline,
                process: .init(version: 1, observedAt: Date(timeIntervalSince1970: 1_789_963_200),
                    executablePath: CodexExecutionIdentity.executable,
                    permissionProfile: recovered.permissionProfile,
                    argumentMarker: "permissions.\(recovered.permissionProfile).network.enabled=false"),
                grantDisposition: .noMatchingGrant)
            try execution.store.saveAssignment(recovered, expected: originalAdmitted)

            let successorRequest = UUID()
            let successorPending = try await producer.prepare(project: execution.project,
                work: execution.work, requestID: successorRequest,
                reviewOfAssignmentID: nil, baselineFromAssignmentID: recovered.id,
                contextPaths: ["source.txt"])
            let successorAdmitted = try producer.admitPrepared(successorPending)
            await producer.finishPreparation(work: execution.work, requestID: successorRequest)
            var successor = successorAdmitted
            successor.state = .closed
            successor.sessionID = "closed-successor-session"
            successor.connectionClosed = true
            try execution.store.saveAssignment(successor, expected: successorAdmitted)
            let successorRevision = try commitChange(at: URL(fileURLWithPath: successor.checkoutPath),
                path: "source.txt", contents: "closed successor candidate",
                message: "Fixture successor candidate")
            XCTAssertNotEqual(successorRevision, fixture.baseline)
            XCTAssertEqual(try provisioning.candidateRevision(
                worktree: XCTUnwrap(successor.worktree)), successorRevision)
            XCTAssertEqual(try execution.store.assignment(projectID: "project-one",
                taskID: recovered.id), recovered,
                "Preparing a newer successor candidate must not rewrite the recovered receipt")
            XCTAssertEqual(recovered.lostWorkerRecovery?.candidateRevision, fixture.baseline)
            XCTAssertEqual(try provisioning.candidateRevision(
                worktree: XCTUnwrap(recovered.worktree)), fixture.baseline)
            XCTAssertEqual(try String(contentsOf:
                URL(fileURLWithPath: recovered.checkoutPath).appendingPathComponent("source.txt"),
                encoding: .utf8), "baseline")

            if dirtyRecoveredAncestor {
                try Data("owner edit retained".utf8).write(to:
                    URL(fileURLWithPath: recovered.checkoutPath).appendingPathComponent("source.txt"))
            }

            let correctionRequest = UUID()
            do {
                let correction = try await producer.prepare(project: execution.project,
                    work: execution.work, requestID: correctionRequest,
                    reviewOfAssignmentID: nil, baselineFromAssignmentID: successor.id,
                    contextPaths: ["source.txt"])
                if dirtyRecoveredAncestor {
                    XCTFail("A dirty recovered ancestor must invalidate its successor chain")
                } else {
                    XCTAssertEqual(correction.baselineFromAssignmentID, successor.id)
                    XCTAssertEqual(correction.worktree?.baseline, successorRevision)
                    XCTAssertEqual(try String(contentsOf:
                        URL(fileURLWithPath: correction.checkoutPath).appendingPathComponent("source.txt"),
                        encoding: .utf8), "closed successor candidate")
                    XCTAssertEqual(try provisioning.candidateRevision(
                        worktree: XCTUnwrap(correction.worktree)), successorRevision)
                    let admitted = try producer.admitPrepared(correction)
                    XCTAssertEqual(admitted.state, .authorized)
                    XCTAssertEqual(admitted.worktree?.baseline, successorRevision)
                    await producer.finishPreparation(work: execution.work,
                        requestID: correctionRequest)
                    var closedCorrection = admitted
                    closedCorrection.state = .closed
                    closedCorrection.sessionID = "closed-correction-session"
                    closedCorrection.connectionClosed = true
                    try execution.store.saveAssignment(closedCorrection, expected: admitted)

                    let laterRequest = UUID()
                    let later = try await producer.prepare(project: execution.project,
                        work: execution.work, requestID: laterRequest,
                        reviewOfAssignmentID: nil,
                        baselineFromAssignmentID: closedCorrection.id,
                        contextPaths: ["source.txt"])
                    XCTAssertEqual(later.baselineFromAssignmentID, closedCorrection.id)
                    XCTAssertEqual(later.worktree?.baseline, successorRevision)
                    XCTAssertEqual(try String(contentsOf:
                        URL(fileURLWithPath: later.checkoutPath).appendingPathComponent("source.txt"),
                        encoding: .utf8), "closed successor candidate")
                    let laterAdmitted = try producer.admitPrepared(later)
                    XCTAssertEqual(laterAdmitted.state, .authorized)
                    XCTAssertEqual(laterAdmitted.worktree?.baseline, successorRevision)
                    await producer.finishPreparation(work: execution.work, requestID: laterRequest)

                    let preservedRecovered = try execution.store.assignment(
                        projectID: "project-one", taskID: recovered.id)
                    XCTAssertEqual(preservedRecovered, recovered)
                    XCTAssertEqual(preservedRecovered.state, .stopped)
                    XCTAssertEqual(preservedRecovered.uncertainOutcome, true)
                    XCTAssertEqual(preservedRecovered.sessionID, "recovered-session")
                    XCTAssertEqual(preservedRecovered.permissionProfile, recovered.permissionProfile)
                    XCTAssertEqual(preservedRecovered.worktree, recovered.worktree)
                    XCTAssertEqual(preservedRecovered.lostWorkerRecovery,
                        recovered.lostWorkerRecovery)
                }
            } catch {
                if !dirtyRecoveredAncestor { throw error }
            }
            await producer.finishPreparation(work: execution.work, requestID: correctionRequest)
        }
    }

    func testNativeWrongRecoveryCheckoutIdentityRefusesProjectLayerCreation() async throws {
        let fixture = try fixture()
        let execution = try executionFixture(fixture)
        let configuration = ProjectExecutionProducerTests.Configuration(); await configuration.setFailure(true)
        let producer = ProjectExecutionAssignmentCoordinator(root: { execution.root }, configuration: configuration,
            handlerPath: "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarCoordinator", provisioning: LibGit2WorktreeProvisioner())
        let request = UUID()
        do { _ = try await producer.prepare(project: execution.project, work: execution.work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["source.txt"]) } catch {}
        let pending = try XCTUnwrap(execution.store.assignments(projectID: "project-one").first)
        let tree = try XCTUnwrap(pending.worktree)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pending)) as? [String: Any])
        var worktree = try XCTUnwrap(object["worktree"] as? [String: Any])
        worktree["commonGitDirectory"] = tree.commonGitDirectory + "-other"; object["worktree"] = worktree
        let wrong = try JSONDecoder().decode(ProjectExecutionAssignment.self, from: JSONSerialization.data(withJSONObject: object))
        try execution.store.saveAssignment(wrong, expected: pending)
        await configuration.setFailure(false)
        do { _ = try await producer.prepare(project: execution.project, work: execution.work, requestID: request,
            reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["source.txt"]); XCTFail("Wrong checkout identity must refuse") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .identityMismatch) }
        XCTAssertEqual(try execution.store.assignment(projectID: "project-one", taskID: wrong.id), wrong)
        XCTAssertFalse(FileManager.default.fileExists(atPath: wrong.checkoutPath + "/.codex"))
        let checks = await configuration.hookChecks; XCTAssertEqual(checks, 0)
    }

}
