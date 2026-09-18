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
}
