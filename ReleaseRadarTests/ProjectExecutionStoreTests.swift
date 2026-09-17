import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionStoreTests: XCTestCase {
    func testHookExpectedBytesAndSymlinkCannotOverwriteUnrelatedConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let original = Data(#"{"hooks":{},"owner":"keep"}"#.utf8)
        try store.saveHookConfiguration(original, expected: nil)
        XCTAssertThrowsError(try store.saveHookConfiguration(Data(#"{"hooks":{}}"#.utf8), expected: nil))
        XCTAssertEqual(try store.hookConfiguration(), original)
        let aliasRoot = root.appendingPathComponent("AliasRoot")
        let aliasStore = try ProjectExecutionFileStore(root: aliasRoot, create: true)
        try FileManager.default.createSymbolicLink(at: aliasRoot.appendingPathComponent(".codex"), withDestinationURL: root.appendingPathComponent(".codex"))
        XCTAssertThrowsError(try aliasStore.saveHookConfiguration(Data(#"{"hooks":{}}"#.utf8), expected: nil))
        XCTAssertEqual(try store.hookConfiguration(), original)
    }

    func testSymlinkAuthorityLockFailsClosed() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let directory = root.appendingPathComponent("Projects/project-one")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside")
        try Data("unchanged".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent(".policy.json.lock"), withDestinationURL: outside)
        let policy = ProjectExecutionPolicy(registration: .init(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1), primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        XCTAssertThrowsError(try store.savePolicy(policy, expected: nil))
        XCTAssertEqual(try Data(contentsOf: outside), Data("unchanged".utf8))
        XCTAssertNil(try store.policyIfPresent(projectID: "project-one"))
    }

    func testIndependentStoresSerializeConflictingPolicyUpdates() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let first = try ProjectExecutionFileStore(root: root, create: true)
        let second = try ProjectExecutionFileStore(root: root, create: false)
        let original = ProjectExecutionPolicy(registration: .init(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1), primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        try first.savePolicy(original, expected: nil)
        var disabled = original; disabled.enabled = false
        var consenting = original; consenting.consent = .init()
        let updates = [disabled, consenting]
        let successes = await withTaskGroup(of: Bool.self) { group in
            for (index, store) in [first, second].enumerated() {
                let update = updates[index]
                group.addTask { do { try store.savePolicy(update, expected: original); return true } catch { return false } }
            }
            var count = 0; for await success in group { if success { count += 1 } }; return count
        }
        XCTAssertEqual(successes, 1)
        XCTAssertTrue(updates.contains(try first.policy(projectID: "project-one")))
    }

    func testPolicyRetryPreservesIdentityAndDoesNotOverwriteConflict() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        let policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        try store.savePolicy(policy, expected: nil)
        XCTAssertEqual(try store.policy(projectID: "project-one"), policy)
        try store.savePolicy(policy, expected: policy)
        let other = ProjectExecutionPolicy(registration: .init(projectID: registration.projectID, registrationID: "other", requestGeneration: 1), primaryRoot: "/Repository", appServerExecutable: "/Codex/codex", handlerPath: "/RR/handler")
        XCTAssertThrowsError(try store.savePolicy(other, expected: nil))
        XCTAssertEqual(try store.policy(projectID: "project-one"), policy)
    }

    func testSymlinkStorageAndSymlinkAssignmentCannotRedirectAuthorityReads() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let alias = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        XCTAssertThrowsError(try ProjectExecutionFileStore(root: alias, create: false))
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let dir = root.appendingPathComponent("Assignments/project-one/task-one")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("untrusted.json")
        try Data("{}".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("assignment.json"), withDestinationURL: outside)
        XCTAssertThrowsError(try store.assignment(projectID: "project-one", taskID: "task-one"))
    }
}
