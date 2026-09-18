import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class ProjectExecutionAdmissionTests: XCTestCase {
    func testHookDerivesOnlyExactOwnedCheckoutAndRejectsStoppedOrChangedContext() throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let paths = try ProjectExecutionPaths(storageRoot: root, projectID: "project-one", taskID: "task-one")
        try FileManager.default.createDirectory(at: paths.checkout, withIntermediateDirectories: true)
        let context = Data("Approved current context".utf8)
        try context.write(to: paths.checkout.appendingPathComponent("AGENTS.md"))
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: "/Primary", appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/RR/runner")
        policy.consent = .init()
        policy.hookReceipt = .init(command: "\"/RR/runner\" --hook", inline: false, beforeDigest: nil, intendedDigest: String(repeating: "a", count: 64), installed: true)
        let codex = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(codex, expected: nil)
        policy.codexContextID = codex.id
        try store.savePolicy(policy, expected: nil)
        var assignment = ProjectExecutionAssignment(id: "task-one", registration: registration, checkoutPath: paths.checkout.path, role: .delivery,
            permissionProfile: "rr-worker", model: "gpt-5.6-terra", effort: "medium", authorization: "Implement the approved work",
            context: [.init(path: "AGENTS.md", digest: SHA256.hash(data: context).map { String(format: "%02x", $0) }.joined())],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], sessionID: "session-one")
        assignment.codexContextID = codex.id
        try store.saveAssignment(assignment, expected: nil)
        XCTAssertEqual(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout, sessionID: "session-one"), assignment)
        XCTAssertNil(try ProjectExecutionHookAdmission.resolve(store: store, checkout: URL(fileURLWithPath: "/Manual"), sessionID: "manual"))
        XCTAssertThrowsError(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout.appendingPathComponent("child"), sessionID: "session-one"))
        XCTAssertThrowsError(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout, sessionID: "sibling-session"))
        let changedCodex = try CodexExecutionContext(home: root, bookmark: Data([2]))
        try store.saveCodexContext(changedCodex, expected: codex)
        XCTAssertThrowsError(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout, sessionID: "session-one"))
        try store.saveCodexContext(codex, expected: changedCodex)
        var unbound = assignment; unbound.codexContextID = nil
        try store.saveAssignment(unbound, expected: assignment)
        XCTAssertThrowsError(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout, sessionID: "session-one"))
        try store.saveAssignment(assignment, expected: unbound)
        var stopped = assignment; stopped.state = .stopped
        try store.saveAssignment(stopped, expected: assignment)
        XCTAssertThrowsError(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout, sessionID: "session-one"))
        try store.saveAssignment(assignment, expected: stopped)
        try Data("Changed context".utf8).write(to: paths.checkout.appendingPathComponent("AGENTS.md"))
        XCTAssertThrowsError(try ProjectExecutionHookAdmission.resolve(store: store, checkout: paths.checkout, sessionID: "session-one"))
    }
}
