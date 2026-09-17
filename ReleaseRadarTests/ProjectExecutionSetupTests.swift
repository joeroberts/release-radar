import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionSetupTests: XCTestCase {
    actor Configuration: ProjectExecutionConfiguring {
        var inline: Data?
        var failReadiness = true
        var finishes = 0
        init(inline: Data? = nil) { self.inline = inline }
        func validateInstallation(handlerPath: String) {}
        func hookStorage(primaryRoot: String) -> ProjectExecutionHookStorage { inline.map(ProjectExecutionHookStorage.inline) ?? .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data) throws {
            guard inline == expected else { throw ProjectExecutionError.conflict }; inline = data
        }
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool) throws {
            if failReadiness { throw ProjectExecutionError.hookNotReady }
        }
        func finishConfiguration() { finishes += 1 }
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) {}
        func recover() { failReadiness = false }
        func result() -> (Data?, Int) { (inline, finishes) }
    }

    private func fixture() throws -> (URL, URL, AuthorizedProject) {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let repository = base.appendingPathComponent("Repository")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        return (base.appendingPathComponent("Execution"), repository,
                AuthorizedProject(registration: registration, canonicalRoot: repository, authorizedRoots: [repository]))
    }

    func testPendingOwnedHookResumesSameConsentAndPreservesUnrelatedGroups() async throws {
        let (root, repository, project) = try fixture()
        let files = try ProjectExecutionFileStore(root: repository, create: false)
        let original = Data(#"{"custom":"keep","hooks":{"Stop":[{"hooks":[{"type":"command","command":"owner-handler"}]}]}}"#.utf8)
        try files.saveHookConfiguration(original, expected: nil)
        let configuration = Configuration()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        do { try await setup.prepare(project: project); XCTFail("Unverified hooks must remain pending") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .hookNotReady) }
        let store = try ProjectExecutionFileStore(root: root, create: false)
        let pending = try store.policy(projectID: "project-one")
        XCTAssertEqual(pending.consent, .init()); XCTAssertEqual(pending.hookReceipt?.installed, false)
        let edited = try XCTUnwrap(files.hookConfiguration())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: edited) as? [String: Any])
        XCTAssertEqual(object["custom"] as? String, "keep")
        XCTAssertNotNil((object["hooks"] as? [String: Any])?["Stop"])
        await configuration.recover()
        try await setup.prepare(project: project)
        try await setup.verify(project: project)
        XCTAssertEqual(try files.hookConfiguration(), edited)
        XCTAssertEqual(try store.policy(projectID: "project-one").hookReceipt?.installed, true)
        let result = await configuration.result(); XCTAssertEqual(result.1, 3)
    }

    func testInlineHookUsesExistingConfigAndCreatesNoShadowHookFile() async throws {
        let (root, repository, project) = try fixture()
        let configuration = Configuration(inline: Data(#"{"hooks":{"Stop":[]}}"#.utf8))
        await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        try await setup.prepare(project: project)
        XCTAssertNil(try ProjectExecutionFileStore(root: repository, create: false).hookConfiguration())
        let result = await configuration.result()
        XCTAssertTrue(String(decoding: try XCTUnwrap(result.0), as: UTF8.self).contains("UserPromptSubmit"))
        XCTAssertEqual(result.1, 1)
        XCTAssertEqual(try ProjectExecutionFileStore(root: root, create: false).policy(projectID: "project-one").hookReceipt?.inline, true)
    }

    func testConflictingPendingEditIsPreservedAndConfigurationIsClosed() async throws {
        let (root, repository, project) = try fixture()
        let configuration = Configuration()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        do { try await setup.prepare(project: project) } catch {}
        let files = try ProjectExecutionFileStore(root: repository, create: false)
        let pending = try XCTUnwrap(files.hookConfiguration())
        let conflicting = Data(#"{"hooks":{},"ownerEdit":true}"#.utf8)
        try files.saveHookConfiguration(conflicting, expected: pending)
        await configuration.recover()
        do { try await setup.prepare(project: project); XCTFail("Pending intent must not overwrite an owner edit") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
        XCTAssertEqual(try files.hookConfiguration(), conflicting)
        let result = await configuration.result(); XCTAssertEqual(result.1, 2)
    }

    func testDisabledPolicyCannotBeReenabledByRetry() async throws {
        let (root, _, project) = try fixture()
        let configuration = Configuration()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        do { try await setup.prepare(project: project) } catch {}
        let store = try ProjectExecutionFileStore(root: root, create: false)
        let pending = try store.policy(projectID: "project-one")
        var disabled = pending; disabled.enabled = false
        try store.savePolicy(disabled, expected: pending)
        await configuration.recover()
        do { try await setup.prepare(project: project); XCTFail("Explicit disablement must win") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .assignmentNotAuthorized) }
        XCTAssertEqual(try store.policy(projectID: "project-one"), disabled)
    }
}
