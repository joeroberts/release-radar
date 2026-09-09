import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryDocumentDiagnosticTests: XCTestCase {
    func testValidRepositoryProducesExactPassedEnvelopeWithoutWriting() throws {
        let root = try validFixture()
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        let before = try inventory(root)

        let result = RepositoryDocumentIndexTool().diagnose(authorizedRoot: root)

        XCTAssertEqual(result.format, "com.rekonlabs.release-radar.documentation-check-result")
        XCTAssertEqual(result.schemaVersion, 1)
        XCTAssertEqual(result.checker.contractVersion, 1)
        XCTAssertNil(result.checker.toolVersion)
        XCTAssertNil(result.checker.toolBuild)
        XCTAssertEqual(result.checker.supportedCatalogVersions, [1])
        XCTAssertEqual(result.target.repositoryID, "9141d1ea-3342-4462-9e06-6934d816c03f")
        XCTAssertEqual(result.target.catalogVersion, 1)
        XCTAssertNotNil(result.target.catalogDigest)
        XCTAssertEqual(result.status, .passed)
        XCTAssertNil(result.error)
        XCTAssertEqual(try inventory(root), before)
    }

    func testPassedEnvelopeEncodesDeterministicJSONWithExplicitNullFields() throws {
        let root = try validFixture()
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        let result = RepositoryDocumentIndexTool().diagnose(authorizedRoot: root)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let json = String(decoding: try encoder.encode(result), as: UTF8.self)

        XCTAssertEqual(
            json,
            #"{"checker":{"contractVersion":1,"supportedCatalogVersions":[1],"toolBuild":null,"toolVersion":null},"error":null,"format":"com.rekonlabs.release-radar.documentation-check-result","schemaVersion":1,"status":"passed","target":{"catalogDigest":"8707861b443590eaa5ad817e9e58893877e440a4d4a046e02867e3176b333e4c","catalogVersion":1,"repositoryID":"9141d1ea-3342-4462-9e06-6934d816c03f"}}"#
        )
    }

    func testStaleIndexesFailWithValidatedTargetIdentityWithoutWriting() throws {
        let root = try validFixture()
        let before = try inventory(root)

        let result = RepositoryDocumentIndexTool().diagnose(authorizedRoot: root)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.target.repositoryID, "9141d1ea-3342-4462-9e06-6934d816c03f")
        XCTAssertEqual(result.target.catalogVersion, 1)
        XCTAssertEqual(result.target.catalogDigest, "8707861b443590eaa5ad817e9e58893877e440a4d4a046e02867e3176b333e4c")
        XCTAssertEqual(result.error?.code, "staleIndex")
        XCTAssertEqual(result.error?.paths, ["docs/README.md", "docs/plans/README.md"])
        XCTAssertEqual(try inventory(root), before)
    }

    func testUnsupportedCatalogFailsWithoutTargetIdentityOrWrites() throws {
        let root = try validFixture()
        try editCatalog(root) { $0["version"] = 2 }
        let before = try inventory(root)

        let result = RepositoryDocumentIndexTool().diagnose(authorizedRoot: root)

        XCTAssertEqual(result.status, .failed)
        XCTAssertNil(result.target.repositoryID)
        XCTAssertNil(result.target.catalogVersion)
        XCTAssertNil(result.target.catalogDigest)
        XCTAssertEqual(result.error?.code, "unsupportedVersion")
        XCTAssertEqual(result.error?.paths, [])
        XCTAssertEqual(try inventory(root), before)
    }

    func testMalformedCatalogFailsWithBoundedErrorWithoutReflectingContent() throws {
        let root = try validFixture()
        try Data(#"{"secret":"do-not-reflect""#.utf8)
            .write(to: root.appendingPathComponent("docs/catalog.json"))

        let result = RepositoryDocumentIndexTool().diagnose(authorizedRoot: root)
        let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.error?.code, "malformedCatalog")
        XCTAssertEqual(result.error?.paths, [])
        XCTAssertFalse(encoded.contains("do-not-reflect"))
    }

    func testSymlinkedCatalogFailsWithoutReadingOrChangingItsTarget() throws {
        let root = try validFixture()
        let catalog = root.appendingPathComponent("docs/catalog.json")
        let outside = root.appendingPathComponent("outside.json")
        let outsideBytes = Data(#"{"secret":"outside"}"#.utf8)
        try outsideBytes.write(to: outside)
        try FileManager.default.removeItem(at: catalog)
        try FileManager.default.createSymbolicLink(at: catalog, withDestinationURL: outside)

        let result = RepositoryDocumentIndexTool().diagnose(authorizedRoot: root)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.error?.code, "unsafeFileType")
        XCTAssertEqual(result.error?.paths, ["docs/catalog.json"])
        XCTAssertEqual(try Data(contentsOf: outside), outsideBytes)
    }

    func testCatalogChangeDuringValidationFailsWithoutTargetIdentity() throws {
        let root = try validFixture()
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        var changed = false
        let tool = RepositoryDocumentIndexTool(afterRead: { path in
            guard path == RepositoryDocumentContract.catalogPath, !changed else { return }
            changed = true
            try! self.editCatalog(root) { $0["repositoryID"] = UUID().uuidString }
        })

        let result = tool.diagnose(authorizedRoot: root)

        XCTAssertTrue(changed)
        XCTAssertEqual(result.status, .failed)
        XCTAssertNil(result.target.repositoryID)
        XCTAssertNil(result.target.catalogVersion)
        XCTAssertNil(result.target.catalogDigest)
        XCTAssertEqual(result.error?.code, "changedDuringRead")
        XCTAssertEqual(result.error?.paths, [])
    }

    private var fixtureSource: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
    }

    private func validFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("ReleaseRadar-SharedExecution-Diagnostic-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: fixtureSource, to: root)
        for path in ["docs/README.md", "docs/plans/README.md"] {
            let contents = """
            # Human heading

            \(RepositoryDocumentContract.managedIndexStart)
            stale
            \(RepositoryDocumentContract.managedIndexEnd)
            """
            try Data((contents + "\n").utf8).write(to: root.appendingPathComponent(path))
        }
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    private func inventory(_ root: URL) throws -> [String: Data] {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey]
        )!
        var result: [String: Data] = [:]
        for case let file as URL in enumerator
        where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[String(file.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: file)
        }
        return result
    }

    private func editCatalog(_ root: URL, mutation: (inout [String: Any]) -> Void) throws {
        let catalog = root.appendingPathComponent("docs/catalog.json")
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as! [String: Any]
        mutation(&object)
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: catalog)
    }
}
