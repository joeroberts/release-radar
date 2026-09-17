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
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data) {}
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool) {}
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
        XCTAssertEqual(resumed.id, pending.id); XCTAssertEqual(resumed.state, .authorized)
        XCTAssertEqual(try store.assignments(projectID: "project-one").count, 1)
        let finishes = await configuration.finishes; XCTAssertEqual(finishes, 2)
    }

    func testIndependentReviewUsesClosedDeliveryCandidateNotPrimaryHeadOrTaskCompletion() async throws {
        let (root, source, project, work, store) = try fixture()
        let configuration = Configuration()
        let deliveryProducer = ProjectExecutionAssignmentCoordinator(root: { root }, configuration: configuration, handlerPath: handler, provisioning: Provisioning(source: source, candidate: nil))
        let delivery = try await deliveryProducer.prepare(project: project, work: work, requestID: UUID(), reviewOfAssignmentID: nil, baselineFromAssignmentID: nil, contextPaths: ["AGENTS.md"])
        var closed = delivery; closed.state = .closed; closed.sessionID = "author-session"
        try store.saveAssignment(closed, expected: delivery)
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
}
