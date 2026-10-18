import CryptoKit
import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RepositoryPlanSourceCaptureTests: XCTestCase {
    func testCaptureUsesOnlySelectedAcceptedArtifactAndReturnsCompleteBoundBytes() throws {
        let root = try fixture()
        let context = try documentationContext(root: root)

        let manifest = try RepositoryPlanSourceCapture.capture(context: context, artifactIDs: ["current"])

        XCTAssertEqual(manifest.projectID, .init(rawValue: "project-101"))
        XCTAssertEqual(manifest.rootID, "root-101")
        XCTAssertEqual(manifest.rootPath, root.path)
        XCTAssertEqual(manifest.repositoryID, "9141d1ea-3342-4462-9e06-6934d816c03f")
        XCTAssertEqual(manifest.acceptedCatalogVersion, 1)
        XCTAssertEqual(manifest.sources.map(\.artifactID), ["current"])
        XCTAssertEqual(manifest.sources.map(\.path), ["docs/plans/current.md"])

        let expected = try Data(contentsOf: root.appendingPathComponent("docs/plans/current.md"))
        XCTAssertEqual(manifest.sources[0].bytes, expected)
        XCTAssertEqual(manifest.sources[0].contentSHA256, sha256(expected))
        XCTAssertEqual(manifest.sources[0].lifecycle, .active)
        XCTAssertEqual(manifest.sources[0].authority, .controlling)
    }

    func testCaptureRejectsUnknownOrUnacceptedArtifactWithoutReturningPartialManifest() throws {
        let root = try fixture()
        let context = try documentationContext(root: root)

        XCTAssertThrowsError(try RepositoryPlanSourceCapture.capture(context: context, artifactIDs: ["missing"]))
        XCTAssertThrowsError(try RepositoryPlanSourceCapture.capture(context: context, artifactIDs: ["current", "missing"]))
    }

    private func fixture() throws -> URL {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid", isDirectory: true)
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("ReleaseRadar-Reconstruction-Capture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8)
            .write(to: root.appendingPathComponent(RepositoryDocumentContract.guidancePath))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func documentationContext(root: URL) throws -> DocumentationRootContext {
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        let projectID = ProjectID(rawValue: "project-101")
        let rootID = ProjectRootID(rawValue: "root-101")
        let binding = try ProjectDocumentationBinding(
            projectID: projectID,
            rootID: rootID,
            acceptedSnapshot: snapshot
        )
        return .init(
            projectID: projectID.rawValue,
            projectName: "Fixture project",
            rootID: rootID.rawValue,
            root: root,
            bookmark: Data(root.path.utf8),
            binding: binding,
            registration: .init(projectID: projectID, registrationID: "registration-101", requestGeneration: 1),
            schemaVersion: 19
        )
    }

    private func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
