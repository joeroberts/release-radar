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
        do { _ = try await onboarding.finish(decision); XCTFail("Unverified setup must not finish") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .hookNotReady) }
        await setup.recover()
        let prepared = try await onboarding.prepare(decision)
        XCTAssertEqual(prepared, preview.registration.projectID)
        let completed = try await onboarding.finish(decision)
        XCTAssertEqual(completed, prepared)
        let counts = await (setup.prepareCount, setup.verifyCount)
        XCTAssertEqual(counts.0, 2); XCTAssertEqual(counts.1, 2)
    }
}
