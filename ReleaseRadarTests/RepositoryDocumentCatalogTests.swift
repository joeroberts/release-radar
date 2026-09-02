import CryptoKit
import Darwin
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryDocumentCatalogTests: XCTestCase {
    func testValidCatalogProducesImmutableCanonicalSnapshotWithoutWriting() throws {
        let root = try fixture()
        let before = try Data(contentsOf: root.appendingPathComponent("docs/catalog.json"))
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        XCTAssertEqual(snapshot.version, 1)
        XCTAssertEqual(snapshot.catalog.artifacts.count, 7)
        XCTAssertEqual(snapshot.digest.count, 64)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("docs/catalog.json")), before)
        try edit(root) { catalog in
            catalog["artifacts"] = (catalog["artifacts"] as! [[String: Any]]).reversed().map { $0 }
            catalog["collections"] = (catalog["collections"] as! [[String: Any]]).reversed().map { $0 }
        }
        XCTAssertEqual(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root).digest, snapshot.digest)
    }

    func testMissingMalformedUnsupportedAndInvalidUTF8CatalogsReject() throws {
        for (bytes, expected) in [(Data("{".utf8), "malformedCatalog"), (Data([0xff]), "invalidUTF8")] {
            let root = try fixture()
            try bytes.write(to: root.appendingPathComponent("docs/catalog.json"))
            reject(expected) { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
        let root = try fixture()
        try edit(root) { $0["version"] = 2 }
        reject("unsupportedVersion") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/catalog.json"))
        reject("missingFile") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testIdentityAuthorityEnumAndGraphViolationsReject() throws {
        let cases: [(String, (inout [String: Any]) -> Void)] = [
            ("invalidIdentity", { $0["repositoryID"] = "not-a-repository-id" }),
            ("duplicateIdentity", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[1]["artifactID"] = "root-index"; catalog["artifacts"] = a }),
            ("duplicatePath", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[1]["path"] = "docs/readme.md"; catalog["artifacts"] = a }),
            ("malformedCatalog", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[1]["lifecycle"] = "current"; catalog["artifacts"] = a }),
            ("invalidAuthority", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[3]["authorityLevel"] = "controlling"; a[3]["authorityRole"] = "delivery"; catalog["artifacts"] = a }),
            ("conflictingController", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[3]["lifecycle"] = "active"; a[3]["authorityLevel"] = "controlling"; a[3]["authorityRole"] = "delivery"; catalog["artifacts"] = a }),
            ("supersessionCycle", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[2]["supersedes"] = ["draft"]; a[3]["supersedes"] = ["current"]; catalog["artifacts"] = a }),
            ("missingReplacement", { catalog in var a = catalog["artifacts"] as! [[String: Any]]; a[3]["supersedes"] = ["missing"]; catalog["artifacts"] = a }),
            ("invalidCollection", { catalog in var c = catalog["collections"] as! [[String: Any]]; c[1]["parentCollection"] = "archive"; catalog["collections"] = c }),
            ("invalidCollection", { catalog in var c = catalog["collections"] as! [[String: Any]]; c[1]["purpose"] = ""; catalog["collections"] = c }),
            ("invalidCollection", { catalog in var c = catalog["collections"] as! [[String: Any]]; c[1]["firstRead"] = "missing"; catalog["collections"] = c }),
            ("retiredIdentity", { $0["retiredArtifactIDs"] = ["draft"] })
        ]
        for (expected, mutation) in cases {
            let root = try fixture()
            try edit(root, mutation)
            reject(expected) { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
    }

    func testUnsafePathsRejectWithoutLeakingOwnerPath() throws {
        for path in ["/private/owner-secret", "docs/../secret", "docs//secret", "docs/./secret", "docs/secret\\file", "docs/%2e%2e/secret"] {
            let root = try fixture()
            try artifact(root, "draft") { $0["path"] = path }
            reject("unsafePath") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
    }

    func testCompletenessMissingFilesAndProhibitedTransientFilesReject() throws {
        let root = try fixture()
        try Data("extra".utf8).write(to: root.appendingPathComponent("docs/extra.md"))
        reject("uncataloguedFile") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/extra.md"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/plans/draft.md"))
        reject("missingFile") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        let other = try fixture()
        try FileManager.default.moveItem(at: other.appendingPathComponent("docs/plans/draft.md"), to: other.appendingPathComponent("docs/plans/.draft.md"))
        try artifact(other, "draft") { $0["path"] = "docs/plans/.draft.md" }
        reject("prohibitedContent") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: other) }
    }

    func testChecksumsApplicableLinksAndTextEncodingReject() throws {
        let root = try fixture()
        try Data("changed".utf8).write(to: root.appendingPathComponent("docs/plans/evidence.md"))
        reject("checksumMismatch") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        for content in [Data("[missing](absent.md)".utf8), Data("[ref][missing]\n\n[missing]: absent.md".utf8), Data([0xff])] {
            let root = try fixture()
            try content.write(to: root.appendingPathComponent("docs/plans/current.md"))
            reject(content == Data([0xff]) ? "invalidUTF8" : "brokenLink") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
    }

    func testBinaryVerificationEvidenceValidatesAndIndexesWithoutLosingFileChecks() throws {
        let root = try fixture()
        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN9sAAAAASUVORK5CYII="))
        XCTAssertNil(String(data: png, encoding: .utf8))
        let path = "docs/plans/evidence.png"
        let file = root.appendingPathComponent(path)
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/plans/evidence.md"))
        try png.write(to: file)
        try artifact(root, "evidence") { $0["path"] = path }
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        try Data("\(digest)  \(path)\n".utf8).write(to: root.appendingPathComponent("docs/plans/SHA256SUMS"))
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        XCTAssertEqual(snapshot.catalog.artifacts.first { $0.artifactID == "evidence" }?.kind, .verificationEvidence)

        for index in ["docs/README.md", "docs/plans/README.md"] {
            let url = root.appendingPathComponent(index)
            try (Data(contentsOf: url) + Data("\n\(RepositoryDocumentContract.managedIndexStart)\n\(RepositoryDocumentContract.managedIndexEnd)\n".utf8)).write(to: url)
        }
        XCTAssertEqual(try RepositoryDocumentIndexTool().write(authorizedRoot: root), ["docs/README.md", "docs/plans/README.md"])
        XCTAssertNoThrow(try RepositoryDocumentIndexTool().check(authorizedRoot: root))
        let index = try String(contentsOf: root.appendingPathComponent("docs/plans/README.md"), encoding: .utf8)
        XCTAssertTrue(index.contains("[docs/plans/evidence.png](evidence.png)"))
        XCTAssertTrue(index.contains("verificationEvidence"))
        XCTAssertEqual(try Data(contentsOf: file), png)

        try (png + Data([0xff])).write(to: file)
        reject("checksumMismatch") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        try png.write(to: file)
        let changing = RepositoryDocumentValidator(afterRead: { readPath in
            if readPath == path { try! (png + Data([0xff])).write(to: file) }
        })
        reject("changedDuringRead") { try changing.validateCurrent(authorizedRoot: root) }
        try FileManager.default.removeItem(at: file)
        let original = root.appendingPathComponent("original.png")
        try png.write(to: original)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: original)
        reject("unsafeFileType") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testBinaryEvidenceAllowancePreservesMarkdownAndTextValidation() throws {
        for path in ["docs/plans/evidence.md", "docs/plans/current.md", "docs/README.md", "docs/plans/SHA256SUMS"] {
            let root = try fixture()
            try Data([0xff]).write(to: root.appendingPathComponent(path))
            reject("invalidUTF8") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
        let root = try fixture()
        try artifact(root, "evidence") { $0["lifecycle"] = "active" }
        let contents = Data("[Missing evidence](missing.md)\n".utf8)
        try contents.write(to: root.appendingPathComponent("docs/plans/evidence.md"))
        let digest = SHA256.hash(data: contents).map { String(format: "%02x", $0) }.joined()
        try Data("\(digest)  docs/plans/evidence.md\n".utf8).write(to: root.appendingPathComponent("docs/plans/SHA256SUMS"))
        reject("brokenLink") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testSymlinkRootsIntermediateFinalAndNonRegularFilesReject() throws {
        for path in ["docs/catalog.json", "docs/plans/draft.md", "docs/plans"] {
            let root = try fixture()
            let original = root.appendingPathComponent(path)
            let moved = root.appendingPathComponent("outside")
            try FileManager.default.moveItem(at: original, to: moved)
            try FileManager.default.createSymbolicLink(at: original, withDestinationURL: moved)
            reject("unsafeFileType") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
        let root = try fixture()
        let link = root.appendingPathComponent("root-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        reject("unsafeFileType") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: link) }
        let fifo = root.appendingPathComponent("docs/pipe").path
        XCTAssertEqual(mkfifo(fifo, 0o600), 0)
        reject("unsafeFileType") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testBoundsRejectBeforeUnboundedReading() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator(limits: .init(maximumCatalogBytes: 10))
        reject("limitExceeded") { try validator.validateCurrent(authorizedRoot: root) }
        reject("limitExceeded") { try RepositoryDocumentValidator(limits: .init(maximumArtifactCount: 2)).validateCurrent(authorizedRoot: root) }
        reject("limitExceeded") { try RepositoryDocumentValidator(limits: .init(maximumFileBytes: 5)).validateCurrent(authorizedRoot: root) }
    }

    func testCatalogFileAndDirectoryChangesDuringSnapshotReject() throws {
        for changed in ["docs/catalog.json", "docs/plans/current.md", "docs/new.md"] {
            let root = try fixture()
            var mutated = false
            let validator = RepositoryDocumentValidator(afterRead: { path in
                if path == "docs/plans/current.md", !mutated {
                    mutated = true
                    try! Data("changed during read".utf8).write(to: root.appendingPathComponent(changed))
                }
            })
            reject("changedDuringRead") { try validator.validateCurrent(authorizedRoot: root) }
        }
    }

    func testAllowedLifecycleMoveAndReplacementTransitionsPreserveIdentity() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator()
        let prior = try validator.validateCurrent(authorizedRoot: root)
        try artifact(root, "draft") { $0["lifecycle"] = "active" }
        let active = try validator.validateCurrent(authorizedRoot: root)
        XCTAssertNoThrow(try validator.validateTransition(from: prior, to: active))
        try artifact(root, "current") { $0["lifecycle"] = "superseded"; $0["authorityLevel"] = "nonAuthoritative"; $0.removeValue(forKey: "authorityRole") }
        try artifact(root, "draft") { $0["authorityLevel"] = "controlling"; $0["authorityRole"] = "delivery"; $0["supersedes"] = ["current"] }
        XCTAssertNoThrow(try validator.validateTransition(from: active, to: validator.validateCurrent(authorizedRoot: root)))
        let moved = try fixture()
        let beforeMove = try validator.validateCurrent(authorizedRoot: moved)
        try FileManager.default.moveItem(at: moved.appendingPathComponent("docs/plans/draft.md"), to: moved.appendingPathComponent("docs/plans/renamed.md"))
        try artifact(moved, "draft") { $0["path"] = "docs/plans/renamed.md" }
        try Data("# Current\n".utf8).write(to: moved.appendingPathComponent("docs/plans/current.md"))
        XCTAssertNoThrow(try validator.validateTransition(from: beforeMove, to: validator.validateCurrent(authorizedRoot: moved)))
    }

    func testTransitionRefusesControllerDeletionMissingReplacementAndRepositoryReplacement() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator()
        let prior = try validator.validateCurrent(authorizedRoot: root)
        try artifact(root, "current") { $0["lifecycle"] = "superseded"; $0["authorityLevel"] = "nonAuthoritative"; $0.removeValue(forKey: "authorityRole") }
        reject("missingReplacement") { try validator.validateTransition(from: prior, to: validator.validateCurrent(authorizedRoot: root)) }
        let deleted = try fixture()
        try edit(deleted) { $0["artifacts"] = ($0["artifacts"] as! [[String: Any]]).filter { $0["artifactID"] as? String != "current" }; $0["retiredArtifactIDs"] = ["retired-document", "current"]
            var c = $0["collections"] as! [[String: Any]]; c[1]["firstRead"] = "draft"; $0["collections"] = c }
        try FileManager.default.removeItem(at: deleted.appendingPathComponent("docs/plans/current.md"))
        try Data("# Plans\n".utf8).write(to: deleted.appendingPathComponent("docs/plans/README.md"))
        reject("controllingDeletion") { try validator.validateTransition(from: prior, to: validator.validateCurrent(authorizedRoot: deleted)) }
        let replaced = try fixture()
        try edit(replaced) { $0["repositoryID"] = UUID().uuidString }
        reject("repositoryIdentityChanged") { try validator.validateTransition(from: prior, to: validator.validateCurrent(authorizedRoot: replaced)) }
    }

    func testRetirementIsPermanentAndArchivedRestorationIsRefused() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator()
        let prior = try validator.validateCurrent(authorizedRoot: root)
        try edit(root) { $0["retiredArtifactIDs"] = [] }
        reject("retiredIdentity") { try validator.validateTransition(from: prior, to: validator.validateCurrent(authorizedRoot: root)) }
        let archived = try fixture()
        try artifact(archived, "draft") { $0["lifecycle"] = "archived"; $0["authorityLevel"] = "nonAuthoritative"; $0["path"] = "docs/archive/draft.md"; $0["parentCollection"] = "archive" }
        try FileManager.default.moveItem(at: archived.appendingPathComponent("docs/plans/draft.md"), to: archived.appendingPathComponent("docs/archive/draft.md"))
        try Data("# Current\n".utf8).write(to: archived.appendingPathComponent("docs/plans/current.md"))
        let old = try validator.validateCurrent(authorizedRoot: archived)
        try artifact(archived, "draft") { $0["lifecycle"] = "active"; $0["authorityLevel"] = "supporting" }
        reject("invalidTransition") { try validator.validateTransition(from: old, to: validator.validateCurrent(authorizedRoot: archived)) }
    }

    func testActiveExecutionLinksCannotRouteThroughArchivedArtifacts() throws {
        let root = try fixture()
        try artifact(root, "draft") { $0["lifecycle"] = "archived"; $0["authorityLevel"] = "nonAuthoritative" }
        reject("archivedReference") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testCompletionArchivalAndUnsupportedTransitions() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator()
        let active = try validator.validateCurrent(authorizedRoot: root)
        try artifact(root, "current") { $0["lifecycle"] = "completed"; $0["authorityLevel"] = "nonAuthoritative"; $0.removeValue(forKey: "authorityRole") }
        let completed = try validator.validateCurrent(authorizedRoot: root)
        XCTAssertNoThrow(try validator.validateTransition(from: active, to: completed))
        // First-read metadata must stop directing readers to the artifact before archival.
        try edit(root) { var c = $0["collections"] as! [[String: Any]]; c[1]["firstRead"] = "draft"; $0["collections"] = c }
        try artifact(root, "current") { $0["lifecycle"] = "archived" }
        reject("invalidTransition") { try validator.validateTransition(from: completed, to: validator.validateCurrent(authorizedRoot: root)) }
        try FileManager.default.moveItem(at: root.appendingPathComponent("docs/plans/current.md"), to: root.appendingPathComponent("docs/archive/current.md"))
        try artifact(root, "current") { $0["path"] = "docs/archive/current.md"; $0["parentCollection"] = "archive" }
        try edit(root) { var c = $0["collections"] as! [[String: Any]]; c[1]["firstRead"] = "draft"; $0["collections"] = c }
        try Data("# Plans\n".utf8).write(to: root.appendingPathComponent("docs/plans/README.md"))
        XCTAssertNoThrow(try validator.validateTransition(from: completed, to: validator.validateCurrent(authorizedRoot: root)))
        let unsupported = try fixture()
        try artifact(unsupported, "draft") { $0["lifecycle"] = "completed" }
        reject("invalidTransition") { try validator.validateTransition(from: active, to: validator.validateCurrent(authorizedRoot: unsupported)) }
    }

    func testDeletionRequiresPermanentRetirementAndIdentityCannotBeReassigned() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator()
        let before = try validator.validateCurrent(authorizedRoot: root)
        try edit(root) { $0["artifacts"] = ($0["artifacts"] as! [[String: Any]]).filter { $0["artifactID"] as? String != "draft" } }
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/plans/draft.md"))
        try Data("# Current\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        reject("retiredIdentity") { try validator.validateTransition(from: before, to: validator.validateCurrent(authorizedRoot: root)) }
        try edit(root) { $0["retiredArtifactIDs"] = ["retired-document", "draft"] }
        XCTAssertNoThrow(try validator.validateTransition(from: before, to: validator.validateCurrent(authorizedRoot: root)))
        let reuse = try fixture()
        try artifact(reuse, "draft") { $0["artifactID"] = "retired-document" }
        try edit(reuse) { $0["retiredArtifactIDs"] = [] }
        reject("retiredIdentity") { try validator.validateTransition(from: before, to: validator.validateCurrent(authorizedRoot: reuse)) }
    }

    func testTransitionalSubtreeIsNarrowNavigableFrozenAndRemovedAtCutover() throws {
        let root = try fixture()
        let validator = RepositoryDocumentValidator()
        for child in ["plans", "specs"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent("docs/superpowers/" + child), withIntermediateDirectories: true)
        }
        try Data("# Existing plan\n".utf8).write(to: root.appendingPathComponent("docs/superpowers/plans/old.md"))
        try edit(root) { catalog in
            var collections = catalog["collections"] as! [[String: Any]]
            for (id, path, parent) in [("transitional", "docs/superpowers", "docs"), ("old-plans", "docs/superpowers/plans", "transitional"), ("old-specs", "docs/superpowers/specs", "transitional")] {
                collections.append(["collectionID": id, "path": path, "parentCollection": parent, "purpose": "Existing historical collection", "allowedContents": ["existing artifacts"], "prohibitedContents": ["new artifacts"], "isLeaf": true])
            }
            catalog["collections"] = collections
            var artifacts = catalog["artifacts"] as! [[String: Any]]
            var old = artifacts[3]; old["artifactID"] = "old"; old["path"] = "docs/superpowers/plans/old.md"; old["parentCollection"] = "old-plans"
            artifacts.append(old); catalog["artifacts"] = artifacts
            catalog["transitionalSubtree"] = ["path": "docs/superpowers", "indexedAncestor": "docs", "collectionIDs": ["transitional", "old-plans", "old-specs"], "artifactIDs": ["old"]]
        }
        let navigation = "# Docs\n[Tree](superpowers/)\n[Plans](superpowers/plans/)\n[Specs](superpowers/specs/)\n[Old](superpowers/plans/old.md)\n"
        try Data(navigation.utf8).write(to: root.appendingPathComponent("docs/README.md"))
        let prior = try validator.validateCurrent(authorizedRoot: root)
        try Data(("<!--\n" + navigation + "-->\n").utf8).write(to: root.appendingPathComponent("docs/README.md"))
        reject("invalidTransitionalSubtree") { try validator.validateCurrent(authorizedRoot: root) }
        try Data("# Docs\n".utf8).write(to: root.appendingPathComponent("docs/README.md"))
        reject("invalidTransitionalSubtree") { try validator.validateCurrent(authorizedRoot: root) }
        try Data(navigation.utf8).write(to: root.appendingPathComponent("docs/README.md"))
        try edit(root) { var t = $0["transitionalSubtree"] as! [String: Any]; t["path"] = "docs/other"; $0["transitionalSubtree"] = t }
        reject("invalidTransitionalSubtree") { try validator.validateCurrent(authorizedRoot: root) }
        try edit(root) { var t = $0["transitionalSubtree"] as! [String: Any]; t["path"] = "docs/superpowers"; $0["transitionalSubtree"] = t }
        try Data("# New\n".utf8).write(to: root.appendingPathComponent("docs/superpowers/plans/new.md"))
        try edit(root) { catalog in
            var a = catalog["artifacts"] as! [[String: Any]]; var added = a.last!; added["artifactID"] = "new"; added["path"] = "docs/superpowers/plans/new.md"; a.append(added); catalog["artifacts"] = a
            var t = catalog["transitionalSubtree"] as! [String: Any]; t["artifactIDs"] = ["old", "new"]; catalog["transitionalSubtree"] = t
        }
        try Data((navigation + "[New](superpowers/plans/new.md)\n").utf8).write(to: root.appendingPathComponent("docs/README.md"))
        reject("invalidTransitionalSubtree") { try validator.validateTransition(from: prior, to: validator.validateCurrent(authorizedRoot: root)) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/superpowers/plans/new.md"))
        try FileManager.default.moveItem(at: root.appendingPathComponent("docs/superpowers/plans/old.md"), to: root.appendingPathComponent("docs/plans/old.md"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("docs/superpowers"))
        try edit(root) { catalog in
            catalog.removeValue(forKey: "transitionalSubtree")
            catalog["collections"] = (catalog["collections"] as! [[String: Any]]).filter { !($0["path"] as! String).hasPrefix("docs/superpowers") }
            catalog["artifacts"] = (catalog["artifacts"] as! [[String: Any]]).filter { $0["artifactID"] as? String != "new" }.map { original in var a = original; if a["artifactID"] as? String == "old" { a["path"] = "docs/plans/old.md"; a["parentCollection"] = "plans" }; return a }
        }
        try Data("# Docs\n[Old](plans/old.md)\n".utf8).write(to: root.appendingPathComponent("docs/README.md"))
        let cutover = try validator.validateCurrent(authorizedRoot: root)
        XCTAssertNoThrow(try validator.validateTransition(from: prior, to: cutover))
        reject("invalidTransitionalSubtree") { try validator.validateTransition(from: cutover, to: prior) }
    }

    func testBalancedParenthesesAndNestedLabelsResolveTheirWholeDestinations() throws {
        let root = try fixture()
        try FileManager.default.moveItem(at: root.appendingPathComponent("docs/plans/draft.md"), to: root.appendingPathComponent("docs/plans/draft(v1).md"))
        try artifact(root, "draft") { $0["path"] = "docs/plans/draft(v1).md" }
        try Data("[Draft](draft(v1).md)\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        XCTAssertNoThrow(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
        try Data("[[History]](../archive/history.md)\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        reject("archivedReference") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testPathologicalUnmatchedLinkLabelsRejectAtBoundedNesting() throws {
        let root = try fixture()
        try Data((String(repeating: "[", count: 8_192) + "\n").utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        reject("limitExceeded") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testRootDirectoryReplacementBetweenMetadataAndOpenRejects() throws {
        let root = try fixture()
        let replacement = try fixture()
        let saved = root.deletingLastPathComponent().appendingPathComponent("ReleaseRadar-Catalog-Original-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: saved) }
        var replaced = false
        let validator = RepositoryDocumentValidator(beforeRootOpen: { component in
            if component == root.lastPathComponent, !replaced {
                replaced = true
                try! FileManager.default.moveItem(at: root, to: saved)
                try! FileManager.default.moveItem(at: replacement, to: root)
            }
        })
        reject("changedDuringRead") { try validator.validateCurrent(authorizedRoot: root) }
        XCTAssertTrue(replaced)
    }

    func testExplicitHistoricalInlineCitationIsAllowedPerOccurrenceOnly() throws {
        let root = try fixture()
        let file = root.appendingPathComponent("docs/plans/current.md")
        try Data("[Historical progress through August](../archive/history.md)\n".utf8).write(to: file)
        XCTAssertNoThrow(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
        try Data("[Historical missing](../archive/missing.md)\n".utf8).write(to: file)
        reject("brokenLink") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        try Data("[Historical progress](../archive/history.md)\n[Execute this](../archive/history.md)\n".utf8).write(to: file)
        reject("archivedReference") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        try Data("[historical progress](../archive/history.md)\n".utf8).write(to: file)
        reject("archivedReference") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testHistoricalCitationDoesNotRelaxFirstReadOrAuthority() throws {
        let root = try fixture()
        try artifact(root, "draft") { $0["lifecycle"] = "archived"; $0["authorityLevel"] = "nonAuthoritative" }
        try Data("[Historical draft](draft.md)\n".utf8).write(to: root.appendingPathComponent("docs/plans/current.md"))
        try edit(root) { var c = $0["collections"] as! [[String: Any]]; c[1]["firstRead"] = "draft"; $0["collections"] = c }
        reject("invalidCollection") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        try edit(root) { var c = $0["collections"] as! [[String: Any]]; c[1]["firstRead"] = "current"; $0["collections"] = c }
        try artifact(root, "draft") { $0["authorityLevel"] = "controlling"; $0["authorityRole"] = "historical" }
        reject("invalidAuthority") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
    }

    func testImageReferenceAndHTMLLinksRemainValidatedWhileExamplesAndCommentsAreIgnored() throws {
        let root = try fixture()
        let file = root.appendingPathComponent("docs/plans/current.md")
        for content in ["![Missing](missing.png)", "[Missing][target]\n[target]: missing.md", "<a href=\"missing.md\">Missing</a>", "<img src=\"missing.png\">"] {
            try Data(content.utf8).write(to: file)
            reject("brokenLink") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
        for content in ["`[Example](missing.md)`", "```markdown\n[Example](missing.md)\n```", "<!-- [Example](missing.md) -->"] {
            try Data(content.utf8).write(to: file)
            XCTAssertNoThrow(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
        }
        for content in ["![Historical plan](../archive/history.md)", "[Historical plan][target]\n[target]: ../archive/history.md", "<a href=\"../archive/history.md\">Historical plan</a>"] {
            try Data(content.utf8).write(to: file)
            reject("archivedReference") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
    }

    func testIncompleteAndMalformedAngleTextCannotHideFollowingMarkdownLinks() throws {
        let root = try fixture()
        let file = root.appendingPathComponent("docs/plans/current.md")
        for content in [
            "Compare <value and then [Execute](../archive/history.md).",
            "Compare <value and then [Execute](../archive/history.md). >",
            "Compare <value title=\"unfinished [Execute](../archive/history.md).",
            String(repeating: "<value ", count: 8_192) + "[Execute](../archive/history.md)."
        ] {
            try Data(content.utf8).write(to: file)
            reject("archivedReference") { try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root) }
        }
        try Data("Compare <value and then [Draft](draft.md).".utf8).write(to: file)
        XCTAssertNoThrow(try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root))
    }

    private func fixture() throws -> URL {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ReleaseRadar-Catalog-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: source, to: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func edit(_ root: URL, _ mutation: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("docs/catalog.json")
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutation(&object)
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
    }

    private func artifact(_ root: URL, _ id: String, _ mutation: (inout [String: Any]) -> Void) throws {
        try edit(root) { object in
            var artifacts = object["artifacts"] as! [[String: Any]]
            let index = artifacts.firstIndex { $0["artifactID"] as? String == id }!
            mutation(&artifacts[index])
            object["artifacts"] = artifacts
        }
    }

    private func reject<T>(_ code: String, file: StaticString = #filePath, line: UInt = #line, _ operation: () throws -> T) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            guard let failure = error as? RepositoryDocumentError else { return XCTFail("Unexpected error type", file: file, line: line) }
            XCTAssertEqual(failure.code.rawValue, code, file: file, line: line)
            XCTAssertFalse(failure.localizedDescription.contains("/private/"), file: file, line: line)
            XCTAssertFalse(failure.localizedDescription.contains("owner-secret"), file: file, line: line)
        }
    }
}
