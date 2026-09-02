import CryptoKit
import Darwin
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryDocumentIndexTests: XCTestCase {
    private let start = RepositoryDocumentContract.managedIndexStart
    private let end = RepositoryDocumentContract.managedIndexEnd

    func testGoldenOutputAndReadOnlyStaleCheck() throws {
        let root = try fixture()
        let before = try inventory(root)
        XCTAssertThrowsError(try RepositoryDocumentIndexTool().check(authorizedRoot: root))
        XCTAssertEqual(try inventory(root), before)
        let result = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        XCTAssertEqual(result, ["docs/README.md", "docs/plans/README.md"])
        for (path, golden) in [("docs/README.md", "root.txt"), ("docs/plans/README.md", "plans.txt")] {
            let expected = try Data(contentsOf: fixtureSource.deletingLastPathComponent().appendingPathComponent("indexes/" + golden))
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(path)), expected)
        }
        let written = try inventory(root)
        XCTAssertNoThrow(try RepositoryDocumentIndexTool().check(authorizedRoot: root))
        XCTAssertEqual(try inventory(root), written)
        XCTAssertEqual(try RepositoryDocumentIndexTool().write(authorizedRoot: root), [])
        XCTAssertEqual(try inventory(root), written)
    }

    func testStableOrderingAndEnumeration() throws {
        let one = try fixture(), two = try fixture()
        try edit(two) { object in
            object["artifacts"] = (object["artifacts"] as! [[String: Any]]).reversed().map { $0 }
            object["collections"] = (object["collections"] as! [[String: Any]]).reversed().map { value in
                var value = value
                value["allowedContents"] = (value["allowedContents"] as! [String]).reversed().map { $0 }
                return value
            }
        }
        let file = two.appendingPathComponent("docs/plans/draft.md")
        let contents = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        try contents.write(to: file)
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: one)
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: two)
        for path in ["docs/README.md", "docs/plans/README.md"] {
            XCTAssertEqual(try Data(contentsOf: one.appendingPathComponent(path)), try Data(contentsOf: two.appendingPathComponent(path)))
        }
    }

    func testMalformedMarkersPrevalidateAllFilesWithoutChangingBytes() throws {
        let malformed = ["missing", "\(end)\n\(start)\n", "\(start)\n\(start)\n\(end)\n", " \(start)\n\(end)\n", "\(start) trailing\n\(end)\n", "<!-- release-radar-docs:v2:start -->\n\(end)\n", "\(start)\n\(end)\n\(end)\n"]
        for content in malformed {
            let root = try fixture()
            try Data(content.utf8).write(to: root.appendingPathComponent("docs/plans/README.md"))
            let before = try inventory(root)
            XCTAssertThrowsError(try RepositoryDocumentIndexTool().write(authorizedRoot: root))
            XCTAssertEqual(try inventory(root), before)
        }
    }

    func testPreservesEveryHumanByteIncludingCRLFAndUnicode() throws {
        let root = try fixture()
        let prefix = Data("\u{feff}# Human e\u{301} 🛰\r\n\r\n".utf8)
        let suffix = Data("\r\nHuman tail\t \r\n".utf8)
        let file = root.appendingPathComponent("docs/README.md")
        try (prefix + Data((start + "\r\nstale\r\n" + end).utf8) + suffix).write(to: file)
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        let after = try Data(contentsOf: file)
        XCTAssertEqual(after.prefix(prefix.count), prefix)
        XCTAssertEqual(after.suffix(suffix.count), suffix)
        XCTAssertTrue(after.starts(with: prefix + Data((start + "\r\n").utf8)))
    }

    func testStaleBrokenManagedLinksCanBeRepairedButHumanLinksCannot() throws {
        let root = try fixture()
        let file = root.appendingPathComponent("docs/README.md")
        try Data((start + "\n[old](missing.md)\n" + end + "\n").utf8).write(to: file)
        XCTAssertNoThrow(try RepositoryDocumentIndexTool().write(authorizedRoot: root))
        try Data(("[human](missing.md)\n" + start + "\nstale\n" + end + "\n").utf8).write(to: file)
        let before = try inventory(root)
        XCTAssertThrowsError(try RepositoryDocumentIndexTool().write(authorizedRoot: root))
        XCTAssertEqual(try inventory(root), before)
    }

    func testCompleteGeneratedCandidateChecksumValidatedBeforeWrites() throws {
        let root = try fixture()
        let path = "docs/plans/README.md"
        let digest = SHA256.hash(data: try Data(contentsOf: root.appendingPathComponent(path))).map { String(format: "%02x", $0) }.joined()
        try edit(root) { object in
            var artifacts = object["artifacts"] as! [[String: Any]]
            let index = artifacts.firstIndex { $0["artifactID"] as? String == "plans-index" }!
            artifacts[index]["checksum"] = ["policy": "required", "manifestArtifactID": "checksums"]
            object["artifacts"] = artifacts
        }
        let manifest = root.appendingPathComponent("docs/plans/SHA256SUMS")
        try (Data(contentsOf: manifest) + Data((digest + "  " + path + "\n").utf8)).write(to: manifest)
        let before = try inventory(root)
        XCTAssertThrowsError(try RepositoryDocumentIndexTool().write(authorizedRoot: root))
        XCTAssertEqual(try inventory(root), before)
    }

    func testLateFailureRestoresOriginalBytesAndEachReplacementIsAtomic() throws {
        let root = try fixture()
        let before = try inventory(root)
        let held = open(root.appendingPathComponent("docs/README.md").path, O_RDONLY)
        XCTAssertGreaterThanOrEqual(held, 0)
        defer { close(held) }
        var sawFirstReplacement = false
        let tool = RepositoryDocumentIndexTool(beforeReplace: { path in
            if path == "docs/plans/README.md" {
                sawFirstReplacement = true
                XCTAssertNotEqual(try Data(contentsOf: root.appendingPathComponent("docs/README.md")), before["docs/README.md"])
                var bytes = [UInt8](repeating: 0, count: before["docs/README.md"]!.count)
                XCTAssertEqual(read(held, &bytes, bytes.count), bytes.count)
                XCTAssertEqual(Data(bytes), before["docs/README.md"])
                throw CocoaError(.fileWriteNoPermission)
            }
        })
        XCTAssertThrowsError(try tool.write(authorizedRoot: root))
        XCTAssertTrue(sawFirstReplacement)
        XCTAssertEqual(try inventory(root), before)
    }

    func testUnsafeRootsAndTargetsRejectWithoutWrites() throws {
        let root = try fixture()
        let target = root.appendingPathComponent("docs/plans/README.md")
        let outside = root.appendingPathComponent("outside.md")
        try FileManager.default.moveItem(at: target, to: outside)
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)
        let before = try Data(contentsOf: outside)
        XCTAssertThrowsError(try RepositoryDocumentIndexTool().write(authorizedRoot: root))
        XCTAssertEqual(try Data(contentsOf: outside), before)
    }


    func testTransitionalTreeEnumeratesEveryLeafAndArtifactWithoutNewIndexes() throws {
        let root = try fixture()
        for path in ["docs/superpowers/plans", "docs/superpowers/specs"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        try Data("# Old plan\n".utf8).write(to: root.appendingPathComponent("docs/superpowers/plans/old.md"))
        try edit(root) { object in
            var collections = object["collections"] as! [[String: Any]]
            for (id, path, parent) in [("transitional", "docs/superpowers", "docs"), ("old-plans", "docs/superpowers/plans", "transitional"), ("old-specs", "docs/superpowers/specs", "transitional")] {
                collections.append(["collectionID": id, "path": path, "parentCollection": parent, "purpose": "Existing historical collection", "allowedContents": ["existing artifacts"], "prohibitedContents": ["new artifacts"], "isLeaf": true])
            }
            object["collections"] = collections
            var artifacts = object["artifacts"] as! [[String: Any]]
            var old = artifacts[3]
            old["artifactID"] = "old"; old["path"] = "docs/superpowers/plans/old.md"; old["parentCollection"] = "old-plans"
            artifacts.append(old); object["artifacts"] = artifacts
            object["transitionalSubtree"] = ["path": "docs/superpowers", "indexedAncestor": "docs", "collectionIDs": ["old-specs", "transitional", "old-plans"], "artifactIDs": ["old"]]
        }
        let before = try inventory(root)
        XCTAssertThrowsError(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
        XCTAssertEqual(try RepositoryDocumentIndexTool().write(authorizedRoot: root), ["docs/README.md", "docs/plans/README.md"])
        XCTAssertNoThrow(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
        let text = try String(contentsOf: root.appendingPathComponent("docs/README.md"), encoding: .utf8)
        for destination in ["superpowers", "superpowers/plans", "superpowers/specs", "superpowers/plans/old.md"] {
            XCTAssertTrue(text.contains("](\(destination))"), destination)
        }
        XCTAssertTrue(text.contains("Leaf collection: old-specs"))
        XCTAssertEqual(Set(try inventory(root).keys), Set(before.keys))
        XCTAssertNoThrow(try RepositoryDocumentIndexTool().check(authorizedRoot: root))
    }

    func testSupersessionAndUntrustedMetadataRenderAsLiteralText() throws {
        let root = try fixture()
        let name = "draft [v1](old).md"
        try Data("# Current delivery\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        try FileManager.default.moveItem(at: root.appendingPathComponent("docs/plans/draft.md"), to: root.appendingPathComponent("docs/plans/" + name))
        try edit(root) { object in
            var artifacts = object["artifacts"] as! [[String: Any]]
            artifacts[2]["supersedes"] = ["retired-document", "draft"]
            artifacts[3]["path"] = "docs/plans/" + name
            artifacts[3]["lifecycle"] = "superseded"
            object["artifacts"] = artifacts
            var collections = object["collections"] as! [[String: Any]]
            collections[1]["purpose"] = "Literal [text](missing.md) <script> | code ` release-radar-docs:v1:start"
            object["collections"] = collections
        }
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        let text = try String(contentsOf: root.appendingPathComponent("docs/plans/README.md"), encoding: .utf8)
        XCTAssertTrue(text.contains("draft%20%5Bv1%5D%28old%29.md"))
        XCTAssertTrue(text.contains("&#91;text&#93;&#40;missing.md&#41; &#60;script&#62; &#124; code &#96;"))
        XCTAssertTrue(text.contains("retired-document (retired)"))
        XCTAssertTrue(text.contains("| superseded | none | [current](current.md) |"))
        XCTAssertNoThrow(try RepositoryDocumentIndexTool().check(authorizedRoot: root))
    }

    func testNewUncataloguedFileDuringStagingRejectsBeforeAnyReplacement() throws {
        let root = try fixture()
        let before = try inventory(root)
        var changed = false
        let tool = RepositoryDocumentIndexTool(beforeReplace: { _ in
            if !changed {
                changed = true
                try Data("external change".utf8).write(to: root.appendingPathComponent("docs/new.md"))
            }
        })
        XCTAssertThrowsError(try tool.write(authorizedRoot: root))
        var expected = before
        expected["docs/new.md"] = Data("external change".utf8)
        XCTAssertEqual(try inventory(root), expected)
    }

    func testCatalogMutationDuringStagingRejectsBeforeAnyReplacement() throws {
        let root = try fixture()
        let original = try inventory(root)
        let tool = RepositoryDocumentIndexTool(beforeReplace: { _ in
            try self.edit(root) { $0["repositoryID"] = UUID().uuidString }
        })
        XCTAssertThrowsError(try tool.write(authorizedRoot: root))
        for path in ["docs/README.md", "docs/plans/README.md"] {
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(path)), original[path])
        }
        XCTAssertEqual(Set(try inventory(root).keys), Set(original.keys))
    }

    func testRenderedCandidateBoundsRejectBeforeWrites() throws {
        let root = try fixture()
        let before = try inventory(root)
        XCTAssertThrowsError(try RepositoryDocumentIndexTool(limits: .init(maximumFileBytes: 500)).write(authorizedRoot: root))
        XCTAssertEqual(try inventory(root), before)
    }


    func testStagedCandidateTamperingRejectsBeforeReplacement() throws {
        for replaceInode in [false, true] {
            let root = try fixture()
            let before = try inventory(root)
            var tampered = false
            let tool = RepositoryDocumentIndexTool(beforeReplace: { _ in
                if !tampered {
                    tampered = true
                    let temporary = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("docs"), includingPropertiesForKeys: nil)
                        .first { $0.lastPathComponent.hasPrefix(".release-radar-index-") }!
                    if replaceInode { try FileManager.default.removeItem(at: temporary) }
                    try Data("tampered candidate".utf8).write(to: temporary)
                }
            })
            XCTAssertThrowsError(try tool.write(authorizedRoot: root))
            XCTAssertEqual(try inventory(root), before)
        }
    }


    func testCleanupFailureBeforeReplacementReportsDisposableCandidates() throws {
        try verifyCleanupFailure(failAt: "docs/README.md", expectedCode: "cleanupFailedAfterRollback", committed: false)
    }

    func testCleanupFailureAfterRollbackReportsDisposableCandidates() throws {
        try verifyCleanupFailure(failAt: "docs/plans/README.md", expectedCode: "cleanupFailedAfterRollback", committed: false)
    }

    func testCleanupFailureAfterCommitReportsObsoleteOriginalBackups() throws {
        try verifyCleanupFailure(failAt: nil, expectedCode: "cleanupFailedAfterCommit", committed: true)
    }


    func testIncompleteRollbackSeparatesOriginalBackupsFromDisposableCandidates() throws {
        let root = try fixture()
        let before = try inventory(root)
        let concurrent = Data("Concurrent README edit\n".utf8)
        defer { XCTAssertEqual(chmod(root.appendingPathComponent("docs/plans").path, 0o755), 0) }
        let tool = RepositoryDocumentIndexTool(beforeReplace: { path in
            if path == "docs/plans/README.md" {
                try concurrent.write(to: root.appendingPathComponent("docs/README.md"))
            }
        }, beforeCleanup: { temporaryPath in
            if temporaryPath.hasPrefix("docs/plans/") {
                XCTAssertEqual(chmod(root.appendingPathComponent("docs/plans").path, 0o555), 0)
            }
        })
        do {
            _ = try tool.write(authorizedRoot: root)
            XCTFail("Expected incomplete recovery plus cleanup failure")
        } catch let error as RepositoryDocumentIndexError {
            XCTAssertEqual(error.code.rawValue, "rollbackFailed")
            XCTAssertEqual(error.paths.count, 1, "Recovery paths must contain only original backup locations")
            let originalBackup = try XCTUnwrap(error.paths.first)
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(originalBackup)), before["docs/README.md"])
            let candidate = try XCTUnwrap(try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("docs/plans"), includingPropertiesForKeys: nil)
                .first { $0.lastPathComponent.hasPrefix(".release-radar-index-") })
            XCTAssertFalse(error.paths.contains("docs/plans/" + candidate.lastPathComponent))
            XCTAssertTrue(error.localizedDescription.contains("Disposable generated candidates: docs/plans/" + candidate.lastPathComponent))
            XCTAssertFalse(error.localizedDescription.contains("restore their original README contents"))
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("docs/README.md")), concurrent)
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("docs/plans/README.md")), before["docs/plans/README.md"])
            let golden = try Data(contentsOf: fixtureSource.deletingLastPathComponent().appendingPathComponent("indexes/plans.txt"))
            XCTAssertEqual(try Data(contentsOf: candidate), golden)
        }
    }

    private func verifyCleanupFailure(failAt: String?, expectedCode: String, committed: Bool) throws {
        let root = try fixture()
        let before = try inventory(root)
        let paths = ["docs/README.md", "docs/plans/README.md"]
        defer {
            // The seam changes only permissions on this synthetic fixture.
            for path in ["docs", "docs/plans"] {
                XCTAssertEqual(chmod(root.appendingPathComponent(path).path, 0o755), 0)
            }
        }
        let tool = RepositoryDocumentIndexTool(beforeReplace: { path in
            if path == failAt { throw CocoaError(.fileWriteNoPermission) }
        }, beforeCleanup: { temporaryPath in
            let directory = root.appendingPathComponent(temporaryPath).deletingLastPathComponent()
            XCTAssertEqual(chmod(directory.path, 0o555), 0)
        })
        do {
            _ = try tool.write(authorizedRoot: root)
            XCTFail("Expected an actual unlink permission failure")
        } catch let error as RepositoryDocumentIndexError {
            XCTAssertEqual(error.code.rawValue, expectedCode)
            XCTAssertEqual(error.paths.count, 2)
            XCTAssertFalse(error.localizedDescription.contains("restore their original README contents"))
            XCTAssertTrue(error.localizedDescription.contains(committed ? "replacements committed" : "original indexes are unchanged or restored"))
            XCTAssertTrue(error.localizedDescription.contains(committed ? "previous originals" : "generated or partial candidates"))
            for path in paths {
                let current = try Data(contentsOf: root.appendingPathComponent(path))
                let temporaryPath = try XCTUnwrap(error.paths.first {
                    URL(fileURLWithPath: $0).deletingLastPathComponent().lastPathComponent
                        == URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
                })
                let retained = try Data(contentsOf: root.appendingPathComponent(temporaryPath))
                let golden = path == "docs/README.md" ? "root.txt" : "plans.txt"
                let candidate = try Data(contentsOf: fixtureSource.deletingLastPathComponent().appendingPathComponent("indexes/" + golden))
                XCTAssertEqual(current, committed ? candidate : before[path])
                XCTAssertEqual(retained, committed ? before[path] : candidate)
            }
            XCTAssertEqual(Set(try inventory(root).keys), Set(before.keys).union(error.paths))
        }
    }

    private var fixtureSource: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-M2B-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: fixtureSource, to: root)
        for path in ["docs/README.md", "docs/plans/README.md"] {
            try Data(("# Human heading\n\n" + start + "\nstale\n" + end + "\n\nHuman footer.\n").utf8).write(to: root.appendingPathComponent(path))
        }
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    private func inventory(_ root: URL) throws -> [String: Data] {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        var result: [String: Data] = [:]
        for case let file as URL in enumerator where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[String(file.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: file)
        }
        return result
    }

    private func edit(_ root: URL, _ mutation: (inout [String: Any]) -> Void) throws {
        let file = root.appendingPathComponent("docs/catalog.json")
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        mutation(&object)
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: file)
    }
}
