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

    func testOwnedHookUpdateReplacesOnlyVerifiedPriorHandlerAndPreservesOwnerRemoval() async throws {
        let (root, repository, project) = try fixture()
        let configuration = Configuration(); await configuration.recover()
        let original = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/old-handler")
        try await original.prepare(project: project)
        let update = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/new-handler")
        try await update.update(project: project)
        let files = try ProjectExecutionFileStore(root: repository, create: false)
        let installed = try XCTUnwrap(files.hookConfiguration())
        XCTAssertTrue(String(decoding: installed, as: UTF8.self).contains("new-handler"))
        XCTAssertFalse(String(decoding: installed, as: UTF8.self).contains("old-handler"))
        let removed = try ProjectExecutionHookRegistration.remove(installed, previousCommand: "\"/RR/new-handler\" --hook")
        try files.saveHookConfiguration(removed, expected: installed)
        do { try await update.update(project: project); XCTFail("Owner removal must not be silently reversed") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
        XCTAssertEqual(try files.hookConfiguration(), removed)
    }

    func testRemoveOwnedHookPreservesUnrelatedHooksAndCannotBeReenabledByOnboardingRetry() async throws {
        let (root, repository, project) = try fixture()
        let files = try ProjectExecutionFileStore(root: repository, create: false)
        let unrelated = Data(#"{"custom":"keep","hooks":{"Stop":[{"hooks":[{"type":"command","command":"owner-handler"}]}]}}"#.utf8)
        try files.saveHookConfiguration(unrelated, expected: nil)
        let configuration = Configuration(); await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        try await setup.prepare(project: project)
        try await setup.removeHook(project: project)
        let removed = try XCTUnwrap(files.hookConfiguration())
        XCTAssertTrue(String(decoding: removed, as: UTF8.self).contains("owner-handler"))
        XCTAssertTrue(String(decoding: removed, as: UTF8.self).contains("keep"))
        XCTAssertFalse(String(decoding: removed, as: UTF8.self).contains("/RR/handler"))
        let policy = try ProjectExecutionFileStore(root: root, create: false).policy(projectID: "project-one")
        XCTAssertFalse(policy.enabled); XCTAssertTrue(policy.hookRemovalReceipt?.completed == true)
        try await setup.removeHook(project: project) // Exact completed removal is idempotent.
        do { try await setup.prepare(project: project); XCTFail("Removal must remain disabled") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .assignmentNotAuthorized) }
    }

    func testRemovalRefusesModifiedOwnedHookAfterDisablingAdmission() async throws {
        let (root, repository, project) = try fixture()
        let configuration = Configuration(); await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        try await setup.prepare(project: project)
        let files = try ProjectExecutionFileStore(root: repository, create: false)
        let installed = try XCTUnwrap(files.hookConfiguration())
        var object = try JSONSerialization.jsonObject(with: installed) as! [String: Any]
        var events = object["hooks"] as! [String: Any]
        var groups = events[ProjectExecutionHookRegistration.event] as! [[String: Any]]
        var definitions = groups[0]["hooks"] as! [[String: Any]]
        definitions[0]["timeout"] = 20; groups[0]["hooks"] = definitions
        events[ProjectExecutionHookRegistration.event] = groups; object["hooks"] = events
        let changed = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertNotEqual(changed, installed)
        try files.saveHookConfiguration(changed, expected: installed)
        do { try await setup.removeHook(project: project); XCTFail("Modified owned definition must be preserved") }
        catch { XCTAssertEqual(error as? ProjectExecutionError, .conflict) }
        XCTAssertEqual(try files.hookConfiguration(), changed)
        XCTAssertFalse(try ProjectExecutionFileStore(root: root, create: false).policy(projectID: "project-one").enabled)
    }

    func testInlineRemovalPreservesExistingStorageWithoutShadowFile() async throws {
        let (root, repository, project) = try fixture()
        let configuration = Configuration(inline: Data(#"{"hooks":{"Stop":[]}}"#.utf8)); await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        try await setup.prepare(project: project)
        try await setup.removeHook(project: project)
        let result = await configuration.result()
        XCTAssertFalse(String(decoding: try XCTUnwrap(result.0), as: UTF8.self).contains("/RR/handler"))
        XCTAssertNil(try ProjectExecutionFileStore(root: repository, create: false).hookConfiguration())
    }

    func testUnknownWorkerRetainsAdmissionHookAfterRemovalDisablesWorkflow() async throws {
        let (root, repository, project) = try fixture()
        let configuration = Configuration(); await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        try await setup.prepare(project: project)
        let store = try ProjectExecutionFileStore(root: root, create: false)
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: "task-one")
        var unknown = ProjectExecutionAssignment(id: "task-one", registration: project.registration!, checkoutPath: paths.checkout.path,
            role: .delivery, permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "medium", authorization: "Existing bounded work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))], excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"])
        unknown.state = .unknown; try store.saveAssignment(unknown, expected: nil)
        let files = try ProjectExecutionFileStore(root: repository, create: false)
        let installed = try files.hookConfiguration()
        do { try await setup.removeHook(project: project); XCTFail("Unknown worker must retain admission hook") }
        catch { XCTAssertTrue(error is ProjectExecutionHookRemovalError) }
        XCTAssertEqual(try files.hookConfiguration(), installed)
        XCTAssertFalse(try store.policy(projectID: "project-one").enabled)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: "task-one").state, .unknown)
    }

    func testOwnerHookManagementAuditsExactRegistrationAndRejectsStaleTarget() async throws {
        let (root, repository, project) = try fixture()
        let store = DeliveryStore(databaseURL: repository.deletingLastPathComponent().appendingPathComponent("owner.sqlite"))
        try await store.transact(actor: .init(id: "fixture"), reason: "Seed exact owner registration") { c in
            try c.execute("INSERT INTO projects(id,name) VALUES ('project-one','Fixture')")
            try c.execute("INSERT INTO project_roots(id,project_id,path) VALUES ('root-one','project-one',?)", bindings: [.text(repository.path)])
            try c.execute("INSERT INTO project_bookmarks(project_id,path,bookmark_data,is_stale) VALUES ('project-one',?,?,0)", bindings: [.text(repository.path), .blob(Data([1]))])
            try c.execute("INSERT INTO project_registrations(project_id,registration_id,request_generation,setup_state) VALUES ('project-one','registration-one',1,'complete')")
        }
        let bookmarks = ProjectBookmarkStore(resolver: { _ in .init(url: repository, isStale: false) }, startAccessing: { _ in true }, stopAccessing: { _ in })
        let onboarding = FolderProjectOnboarding(store: store, bookmarkStore: bookmarks)
        let configuration = Configuration(); await configuration.recover()
        let setup = ProjectExecutionSetupCoordinator(root: { root }, configuration: configuration, handlerPath: "/RR/handler")
        try await setup.prepare(project: project)
        let stale = ProjectRegistration(projectID: project.projectID, registrationID: "other-registration", requestGeneration: 1)
        do { try await onboarding.manageExecutionHook(registration: stale, action: .remove, setup: setup); XCTFail("Stale target must not disable another registration") }
        catch { XCTAssertEqual(error as? OnboardingError, .staleRegistration) }
        XCTAssertTrue(try ProjectExecutionFileStore(root: root, create: false).policy(projectID: "project-one").enabled)
        try await onboarding.manageExecutionHook(registration: project.registration!, action: .remove, setup: setup)
        let auditReasons = try await store.read { try $0.rows("SELECT reason,actor_id,project_id FROM audit_events WHERE reason LIKE 'Execution hook%'") }
        XCTAssertEqual(auditReasons.count, 2)
        for row in auditReasons { XCTAssertEqual(row["actor_id"], .text("release-radar-owner")); XCTAssertEqual(row["project_id"], .text("project-one")) }
    }
}
