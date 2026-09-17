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
