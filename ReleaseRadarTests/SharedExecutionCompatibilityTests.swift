import Foundation
import XCTest
@testable import ReleaseRadarCore

final class SharedExecutionCompatibilityTests: XCTestCase {
    func testReducerCoversEveryCompatibilityStateWithoutSemVerInference() {
        let legacy = RecognizedPluginCapability(
            manifestVersion: "0.1.6",
            normalizedPackageDigest: "legacy",
            sharedExecutionStandardVersions: [0]
        )
        let transitional = RecognizedPluginCapability(
            manifestVersion: "0.1.7-compatible",
            normalizedPackageDigest: "transitional",
            sharedExecutionStandardVersions: [0]
        )
        let current = RecognizedPluginCapability(
            manifestVersion: "0.1.8",
            normalizedPackageDigest: "current",
            sharedExecutionStandardVersions: [0, 1]
        )
        let identity = SharedExecutionRepositoryIdentity(
            repositoryID: "repository-one",
            catalogVersion: 1,
            catalogDigest: "catalog-one"
        )
        let passedChecker = SharedExecutionCheckerResult(
            contractVersion: 1,
            supportedCatalogVersions: [1],
            target: identity,
            status: .passed
        )
        let base = SharedExecutionCompatibilityInput(
            root: .exact("/Synthetic/Repository"),
            declaration: .exact(version: 1),
            plugin: .clean(installed: current, shipped: current),
            checker: .result(passedChecker),
            repository: .accepted(identity),
            directResults: [.fixture]
        )
        let cases: [(SharedExecutionCompatibilityState, SharedExecutionCompatibilityInput)] = [
            (.notDeclared, base.replacing(declaration: .absent)),
            (.compatibleV1, base),
            (.compatibleOlder, base.replacing(
                declaration: .legacy(version: 0),
                plugin: .clean(installed: legacy, shipped: legacy)
            )),
            (.updateAvailable, base.replacing(
                declaration: .legacy(version: 0),
                plugin: .clean(installed: transitional, shipped: current)
            )),
            (.pendingCatalogAcceptance, base.replacing(repository: .pendingAcceptance(identity))),
            (.incompatible, base.replacing(plugin: .unrecognized(manifestVersion: "0.1.8", normalizedPackageDigest: "wrong"))),
            (.unavailable, base.replacing(checker: .unavailable("diagnostic tool is unavailable"))),
            (.rootUnknown, base.replacing(root: .unknown)),
            (.unknown, base.replacing(repository: .unknown("observation was interrupted"))),
        ]

        for (expected, input) in cases {
            let result = SharedExecutionCompatibilityReducer.reduce(input)
            XCTAssertEqual(result.state, expected)
            XCTAssertEqual(result.directResults, [.fixture])
        }

        XCTAssertEqual(
            SharedExecutionCompatibilityReducer.reduce(
                base.replacing(declaration: .exact(version: 1), plugin: .clean(installed: legacy, shipped: current))
            ).state,
            .incompatible,
            "A newer shipped SemVer-like identity must not make an unsupported installed package compatible"
        )
    }

    func testReducerRejectsCheckerAndRepositoryIdentityMismatchAndPreservesPendingAcceptance() {
        let capability = RecognizedPluginCapability(
            manifestVersion: "0.1.8",
            normalizedPackageDigest: "current",
            sharedExecutionStandardVersions: [1]
        )
        let repository = SharedExecutionRepositoryIdentity(
            repositoryID: "repository-one",
            catalogVersion: 1,
            catalogDigest: "digest-one"
        )
        let other = SharedExecutionRepositoryIdentity(
            repositoryID: "repository-two",
            catalogVersion: 1,
            catalogDigest: "digest-two"
        )
        let input = SharedExecutionCompatibilityInput(
            root: .exact("/Synthetic/Repository"),
            declaration: .exact(version: 1),
            plugin: .clean(installed: capability, shipped: capability),
            checker: .result(.init(
                contractVersion: 1,
                supportedCatalogVersions: [1],
                target: other,
                status: .passed
            )),
            repository: .accepted(repository),
            directResults: []
        )

        XCTAssertEqual(SharedExecutionCompatibilityReducer.reduce(input).state, .incompatible)
        XCTAssertEqual(
            SharedExecutionCompatibilityReducer.reduce(input.replacing(
                checker: .result(.init(
                    contractVersion: 1,
                    supportedCatalogVersions: [1],
                    target: repository,
                    status: .passed
                )),
                repository: .pendingAcceptance(repository)
            )).state,
            .pendingCatalogAcceptance
        )
    }

    func testDirectResultVocabularyAndAdoptionProgressAreClosed() throws {
        let statuses: [SharedExecutionDirectResult.Status] = [
            .passed, .failed, .skipped, .unavailable, .unknown, .notRun,
        ]
        let applicability: [SharedExecutionDirectResult.Applicability] = [
            .exactRevision, .workingTree, .unknown,
        ]
        let progress: [SharedExecutionAdoptionProgress] = [
            .workingTreeCandidate, .committedCandidate, .ledgerRecorded, .unknown,
        ]

        XCTAssertEqual(statuses.map(\.rawValue), ["passed", "failed", "skipped", "unavailable", "unknown", "notRun"])
        XCTAssertEqual(applicability.map(\.rawValue), ["exactRevision", "workingTree", "unknown"])
        XCTAssertEqual(progress.map(\.rawValue), ["workingTreeCandidate", "committedCandidate", "ledgerRecorded", "unknown"])
        XCTAssertNoThrow(try JSONEncoder().encode(SharedExecutionDirectResult.fixture))
    }

    func testDeclarationParserDistinguishesAbsentExactDuplicateModifiedAndLegacy() {
        XCTAssertEqual(SharedExecutionDeclarationInspector.inspect(contents: nil), .absent)
        XCTAssertEqual(SharedExecutionDeclarationInspector.inspect(contents: "# Local instructions\n"), .absent)
        XCTAssertEqual(
            SharedExecutionDeclarationInspector.inspect(contents: SharedExecutionDeclarationInspector.managedBlock),
            .exact(version: 1)
        )
        XCTAssertEqual(
            SharedExecutionDeclarationInspector.inspect(
                contents: SharedExecutionDeclarationInspector.managedBlock + "\n" + SharedExecutionDeclarationInspector.managedBlock
            ),
            .duplicate
        )
        XCTAssertEqual(
            SharedExecutionDeclarationInspector.inspect(
                contents: SharedExecutionDeclarationInspector.managedBlock.replacingOccurrences(of: "bounded context", with: "expanded context")
            ),
            .modified(version: 1)
        )
        XCTAssertEqual(
            SharedExecutionDeclarationInspector.inspect(contents: """
            <!-- release-radar-shared-execution:v0:start -->
            legacy local declaration
            <!-- release-radar-shared-execution:end -->
            """),
            .legacy(version: 0)
        )
    }

    func testDeclarationInspectionUsesNoFollowRegularBoundedStableRead() throws {
        let parent = try temporaryDirectory("Boundaries")
        let root = parent.appendingPathComponent("repository", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let agents = root.appendingPathComponent("AGENTS.md")
        try Data(SharedExecutionDeclarationInspector.managedBlock.utf8).write(to: agents)
        XCTAssertEqual(SharedExecutionDeclarationInspector.inspect(rootURL: root), .exact(version: 1))

        let outside = parent.appendingPathComponent("outside.md")
        let outsideBytes = Data(SharedExecutionDeclarationInspector.managedBlock.utf8)
        try outsideBytes.write(to: outside)
        try FileManager.default.removeItem(at: agents)
        try FileManager.default.createSymbolicLink(at: agents, withDestinationURL: outside)
        XCTAssertEqual(SharedExecutionDeclarationInspector.inspect(rootURL: root), .unavailable(.unsafeFileType))
        XCTAssertEqual(try Data(contentsOf: outside), outsideBytes)

        try FileManager.default.removeItem(at: agents)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: false)
        XCTAssertEqual(SharedExecutionDeclarationInspector.inspect(rootURL: root), .unavailable(.unsafeFileType))

        try FileManager.default.removeItem(at: agents)
        try Data(repeating: 0x41, count: 65).write(to: agents)
        let limits = RepositoryDocumentContract.Limits(maximumFileBytes: 64)
        XCTAssertEqual(
            SharedExecutionDeclarationInspector.inspect(rootURL: root, limits: limits),
            .unavailable(.limitExceeded)
        )

        try Data([0xFF, 0xFE]).write(to: agents)
        XCTAssertEqual(SharedExecutionDeclarationInspector.inspect(rootURL: root), .unavailable(.invalidUTF8))
    }

    func testDeclarationInspectionReportsChangedDuringReadAsUnknown() throws {
        let root = try temporaryDirectory("Changed")
        let agents = root.appendingPathComponent("AGENTS.md")
        try Data(SharedExecutionDeclarationInspector.managedBlock.utf8).write(to: agents)
        var changed = false

        let result = SharedExecutionDeclarationInspector.inspect(rootURL: root) { path in
            guard path == "AGENTS.md", !changed else { return }
            changed = true
            try! Data("changed".utf8).write(to: agents)
        }

        XCTAssertTrue(changed)
        XCTAssertEqual(result, .unknown(.changedDuringRead))
    }

    private func temporaryDirectory(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("ReleaseRadar-SharedExecution-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }
}

private extension SharedExecutionDirectResult {
    static let fixture = Self(
        check: "documentation",
        runner: "ReleaseRadarDocumentationTool",
        scope: "/Synthetic/Repository/docs",
        source: "HEAD clean",
        applicability: .exactRevision,
        status: .passed,
        directResult: "exit 0",
        limitation: nil
    )
}

private extension SharedExecutionCompatibilityInput {
    func replacing(
        root: SharedExecutionRootObservation? = nil,
        declaration: SharedExecutionDeclarationObservation? = nil,
        plugin: SharedExecutionPluginObservation? = nil,
        checker: SharedExecutionCheckerObservation? = nil,
        repository: SharedExecutionRepositoryObservation? = nil
    ) -> Self {
        .init(
            root: root ?? self.root,
            declaration: declaration ?? self.declaration,
            plugin: plugin ?? self.plugin,
            checker: checker ?? self.checker,
            repository: repository ?? self.repository,
            directResults: directResults
        )
    }
}
