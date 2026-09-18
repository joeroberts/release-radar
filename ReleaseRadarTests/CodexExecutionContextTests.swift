import Foundation
import XCTest
@testable import ReleaseRadarCore

final class CodexExecutionContextTests: XCTestCase {
    final class Scope: @unchecked Sendable {
        let lock = NSLock()
        var starts = 0
        var stops = 0
        var allowed = true
        func start(_ url: URL) -> Bool { lock.withLock { starts += 1; return allowed } }
        func stop(_ url: URL) { lock.withLock { stops += 1 } }
    }
    private func fixture() throws -> (ProjectExecutionFileStore, CodexExecutionContext) {
        let base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let home = base.appendingPathComponent("existing-codex")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let context = try CodexExecutionContext(home: home, bookmark: Data([1]))
        let store = try ProjectExecutionFileStore(root: base.appendingPathComponent("Execution"), create: true)
        try store.saveCodexContext(context, expected: nil)
        return (store, context)
    }
    func testProtectedSelectionPersistsMetadataOnlyAndRefusesConflictingChange() throws {
        let (store, context) = try fixture()
        XCTAssertEqual(try store.codexContext(), context)
        XCTAssertThrowsError(try store.saveCodexContext(context, expected: nil))
        let raw = try Data(contentsOf: store.root.appendingPathComponent("CodexContext/selection.json"))
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("token"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("auth.json").path))
        let attrs = try FileManager.default.attributesOfItem(atPath: store.root.appendingPathComponent("CodexContext/selection.json").path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testLeaseHoldsGrantUntilExplicitCloseAndRejectsChangedSelection() throws {
        let (store, context) = try fixture(); let scope = Scope()
        let lease = try CodexExecutionContextLease(context: context, current: { try store.codexContext() },
            resolve: { _ in .init(url: URL(fileURLWithPath: context.homePath), isStale: false) },
            start: scope.start, stop: scope.stop)
        try lease.validate(); XCTAssertEqual(scope.starts, 1); XCTAssertEqual(scope.stops, 0)
        let replacement = try CodexExecutionContext(home: URL(fileURLWithPath: context.homePath), bookmark: Data([2]))
        try store.saveCodexContext(replacement, expected: context)
        XCTAssertThrowsError(try lease.validate())
        XCTAssertEqual(scope.stops, 0, "Changing context does not establish physical connection closure")
        lease.release(); lease.release(); XCTAssertEqual(scope.stops, 1)
        XCTAssertThrowsError(try lease.validate())
    }
    func testStaleDeniedOrMovedBookmarkFailsClosedWithoutLeakingScope() throws {
        let (store, context) = try fixture()
        for stale in [true, false] {
            let scope = Scope(); scope.allowed = false
            XCTAssertThrowsError(try CodexExecutionContextLease(context: context, current: { try store.codexContext() },
                resolve: { _ in .init(url: URL(fileURLWithPath: context.homePath), isStale: stale) },
                start: scope.start, stop: scope.stop))
            XCTAssertEqual(scope.stops, 0)
        }
        let other = store.root
        let scope = Scope()
        XCTAssertThrowsError(try CodexExecutionContextLease(context: context, current: { try store.codexContext() },
            resolve: { _ in .init(url: other, isStale: false) }, start: scope.start, stop: scope.stop))
        XCTAssertEqual(scope.stops, scope.starts)
    }
    func testReplacingSelectedDirectoryFailsClosedWhilePreservingOriginalFolder() throws {
        let (store, context) = try fixture(); let scope = Scope()
        let lease = try CodexExecutionContextLease(context: context, current: { try store.codexContext() },
            resolve: { _ in .init(url: URL(fileURLWithPath: context.homePath), isStale: false) }, start: scope.start, stop: scope.stop)
        let original = URL(fileURLWithPath: context.homePath)
        let retained = original.appendingPathExtension("retained")
        try FileManager.default.moveItem(at: original, to: retained)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        XCTAssertThrowsError(try lease.validate())
        XCTAssertTrue(FileManager.default.fileExists(atPath: retained.path))
        lease.release(); XCTAssertEqual(scope.stops, 1)
    }

    func testMissingHomeNeverCreatesContextOrCopiesConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try CodexExecutionContext(home: root, bookmark: Data([1])))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testLeaseFailureDiagnosticsSeparateStagesAndSanitizeFoundationErrors() throws {
        let (store, context) = try fixture()
        let scope = Scope()
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 1,
            userInfo: [NSLocalizedDescriptionKey: "synthetic-private-underlying"])
        let error = NSError(domain: NSCocoaErrorDomain, code: 256,
            userInfo: [NSUnderlyingErrorKey: underlying, NSLocalizedDescriptionKey: "synthetic-private-auth"])
        XCTAssertThrowsError(try CodexExecutionContextLease(context: context,
            current: { try store.codexContext() }, resolve: { _ in throw error },
            start: scope.start, stop: scope.stop)) {
            XCTAssertTrue($0.localizedDescription.contains("resolve"))
            XCTAssertTrue($0.localizedDescription.contains("NSCocoaErrorDomain:256"))
            XCTAssertTrue($0.localizedDescription.contains("NSPOSIXErrorDomain:1"))
            XCTAssertFalse($0.localizedDescription.contains("synthetic-private"))
        }
        for stale in [true, false] {
            scope.allowed = false
            XCTAssertThrowsError(try CodexExecutionContextLease(context: context,
                current: { try store.codexContext() },
                resolve: { _ in .init(url: URL(fileURLWithPath: context.homePath), isStale: stale) },
                start: scope.start, stop: scope.stop)) {
                XCTAssertTrue($0.localizedDescription.contains(stale ? "stale" : "start"))
            }
        }
        scope.allowed = true
        XCTAssertThrowsError(try CodexExecutionContextLease(context: context,
            current: { try store.codexContext() },
            resolve: { _ in .init(url: store.root, isStale: false) },
            start: scope.start, stop: scope.stop)) {
            XCTAssertTrue($0.localizedDescription.contains("identity"))
        }
    }

    func testLeaseRetainsOriginalResolvedURLWhileComparingCanonicalIdentity() throws {
        let (store, context) = try fixture()
        let alias = store.root.deletingLastPathComponent().appendingPathComponent("selected-alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: URL(fileURLWithPath: context.homePath))
        let scope = Scope()
        let lease = try CodexExecutionContextLease(context: context, current: { try store.codexContext() },
            resolve: { _ in .init(url: alias, isStale: false) },
            start: { url in XCTAssertEqual(url, alias); return scope.start(url) },
            stop: { url in XCTAssertEqual(url, alias); scope.stop(url) })
        try lease.validate()
        XCTAssertEqual(scope.stops, 0)
        lease.release()
        XCTAssertEqual(scope.stops, 1)
    }

    func testRetainedAssignmentBlocksDifferentHomeButAllowsSameHomeRecovery() throws {
        let (store, context) = try fixture()
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        var assignment = ProjectExecutionAssignment(id: "retained-one", registration: registration,
            checkoutPath: store.root.appendingPathComponent("checkout").path, role: .delivery, permissionProfile: "rr-retained",
            model: "gpt-5.6-terra", effort: "medium", authorization: "Approved bounded work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], state: .unknown)
        assignment.codexContextID = context.id; assignment.launchReserved = true; assignment.uncertainOutcome = true
        try store.saveAssignment(assignment, expected: nil)
        let other = store.root.appendingPathComponent("other-existing-home")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let replacement = try CodexExecutionContext(home: other, bookmark: Data([2]), previousContextID: context.id)
        XCTAssertThrowsError(try store.saveCodexContext(replacement, expected: context))
        XCTAssertEqual(try store.codexContext(), context)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: assignment.id), assignment)
        let recovered = try CodexExecutionContext(home: URL(fileURLWithPath: context.homePath), bookmark: Data([3]), id: context.id)
        try store.saveCodexContext(recovered, expected: context)
        XCTAssertEqual(try store.codexContext()?.id, context.id)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: assignment.id), assignment)
        var retired = assignment; retired.state = .superseded; retired.connectionClosed = true
        retired.retirement = .init(requestID: UUID(), priorState: assignment.state)
        retired.retirement?.worktreeRemoved = true; retired.retirement?.profileRemoved = true; retired.retirement?.completed = true
        try store.saveAssignment(retired, expected: assignment)
        try store.saveCodexContext(replacement, expected: recovered)
        XCTAssertEqual(try store.codexContext(), replacement)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: assignment.id), retired)
    }

    func testInstalledHookBlocksDifferentHomeUntilOwnedHookIsRemoved() throws {
        let (store, context) = try fixture()
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        var policy = ProjectExecutionPolicy(registration: registration, primaryRoot: store.root.path,
            appServerExecutable: CodexExecutionIdentity.executable, handlerPath: "/fixture/coordinator")
        policy.codexContextID = context.id
        policy.hookReceipt = .init(command: "owned-hook", inline: false, beforeDigest: nil,
            intendedDigest: String(repeating: "a", count: 64), installed: true)
        try store.savePolicy(policy, expected: nil)
        let other = store.root.appendingPathComponent("other-existing-home")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let replacement = try CodexExecutionContext(home: other, bookmark: Data([2]))
        XCTAssertThrowsError(try store.saveCodexContext(replacement, expected: context)) {
            XCTAssertEqual($0 as? CodexExecutionContextError, .resourcesRetained)
        }
        XCTAssertEqual(try store.codexContext(), context)
        var removed = policy; removed.hookReceipt?.installed = false
        try store.savePolicy(removed, expected: policy)
        try store.saveCodexContext(replacement, expected: context)
        XCTAssertEqual(try store.codexContext(), replacement)
    }

    func testPreparationValidatedBeforeHomeSwitchCannotSaveStaleIntent() throws {
        let (store, original) = try fixture()
        let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
        var pending = ProjectExecutionAssignment(id: "paused-preparation", registration: registration,
            checkoutPath: store.root.appendingPathComponent("checkout").path, role: .delivery, permissionProfile: "rr-paused",
            model: "gpt-5.6-terra", effort: "medium", authorization: "Approved bounded work",
            context: [.init(path: "AGENTS.md", digest: String(repeating: "a", count: 64))],
            excludedPaths: [".git", ".codegraph", ".superpowers/sdd", "docs/delivery/archive"], state: .preparing)
        pending.codexContextID = original.id
        // Preparation captured A; removal left no retained inventory before B was selected.
        let other = store.root.appendingPathComponent("other-existing-home")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let replacement = try CodexExecutionContext(home: other, bookmark: Data([2]))
        try store.saveCodexContext(replacement, expected: original)
        XCTAssertThrowsError(try store.saveAssignment(pending, expected: nil)) {
            XCTAssertEqual($0 as? CodexExecutionContextError, .changed)
        }
        XCTAssertTrue(try store.assignments(projectID: "project-one").isEmpty)
        XCTAssertEqual(try store.codexContext(), replacement)
        var materialized = false
        XCTAssertThrowsError(try store.createAssignment(codexContextID: original.id) {
            materialized = true
            return pending
        })
        XCTAssertFalse(materialized, "Stale context must fail before creating checkout resources")
        try store.saveCodexContext(original, expected: replacement)
        XCTAssertEqual(try store.codexContext(), original, "A stale writer must not strand original-context recovery")
        let created = try store.createAssignment(codexContextID: original.id) { pending }
        XCTAssertEqual(created, pending)
        XCTAssertThrowsError(try store.saveCodexContext(replacement, expected: original))
        // Even after external selection corruption, STOP/closure can preserve the intent.
        let receipt = store.root.appendingPathComponent("CodexContext/selection.json")
        try JSONEncoder().encode(replacement).write(to: receipt)
        var stopped = pending; stopped.state = .stopped; stopped.connectionClosed = true
        try store.saveAssignment(stopped, expected: pending)
        XCTAssertEqual(try store.assignment(projectID: "project-one", taskID: pending.id), stopped)
    }
}
