import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class DocumentationToolInstallationTests: XCTestCase {
    func testPackagedCheckerRunsAndFindsItsShippedReference() throws {
        let helper = try packagedHelper()
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helper.path), "The installed app must include the checker")
        let result = try run(helper, arguments: ["--help"])
        let text = result.stdout + result.stderr
        XCTAssertEqual(result.status, 0, text)
        let referenceLine = try XCTUnwrap(text.split(separator: "\n").first { $0.hasPrefix("Catalog v1 reference: ") })
        let reference = String(referenceLine.dropFirst("Catalog v1 reference: ".count))
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: reference))
        XCTAssertEqual(
            text,
            """
            Usage: ReleaseRadarDocumentationTool <check|write> --root <absolute-repository-root>
            check validates the catalog, files and generated indexes without writing.
            write updates only generated index blocks; requires owner authorization.
            Neither command binds a repository, accepts a catalog, or changes delivery state.
            Catalog v1 reference: \(reference)

            """
        )
        let packagedResources = helper
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
            .standardizedFileURL.path + "/"
        XCTAssertTrue(URL(fileURLWithPath: reference).standardizedFileURL.path.hasPrefix(packagedResources))
    }

    func testPackagedCheckerDiagnoseEmitsPassedJSONWithoutWriting() throws {
        let helper = try packagedHelper()
        let root = try validFixture()
        _ = try RepositoryDocumentIndexTool().write(authorizedRoot: root)
        let before = try inventory(root)

        let result = try run(helper, arguments: ["diagnose", "--root", root.path, "--format", "json"])

        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertEqual(result.stderr, "")
        let diagnostic = try JSONDecoder().decode(RepositoryDocumentDiagnostic.self, from: Data(result.stdout.utf8))
        let appBundle = try XCTUnwrap(Bundle(url: helper
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()))
        let expectedVersion = try XCTUnwrap(appBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let expectedBuild = try XCTUnwrap(appBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        XCTAssertEqual(diagnostic.checker.toolVersion, expectedVersion)
        XCTAssertEqual(diagnostic.checker.toolBuild, expectedBuild)
        XCTAssertEqual(diagnostic.status, .passed)
        XCTAssertEqual(diagnostic.target.repositoryID, "9141d1ea-3342-4462-9e06-6934d816c03f")
        XCTAssertEqual(diagnostic.target.catalogVersion, 1)
        XCTAssertEqual(diagnostic.target.catalogDigest, "8707861b443590eaa5ad817e9e58893877e440a4d4a046e02867e3176b333e4c")
        XCTAssertNil(diagnostic.error)
        XCTAssertEqual(try inventory(root), before)
    }

    func testPackagedCheckerDiagnoseEmitsBoundedFailureJSONWithoutWriting() throws {
        let helper = try packagedHelper()
        let root = try validFixture()
        let before = try inventory(root)

        let result = try run(helper, arguments: ["diagnose", "--root", root.path, "--format", "json"])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stderr, "")
        let diagnostic = try JSONDecoder().decode(RepositoryDocumentDiagnostic.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(diagnostic.status, .failed)
        XCTAssertEqual(diagnostic.target.repositoryID, "9141d1ea-3342-4462-9e06-6934d816c03f")
        XCTAssertEqual(diagnostic.error?.code, "staleIndex")
        XCTAssertEqual(diagnostic.error?.paths, ["docs/README.md", "docs/plans/README.md"])
        XCTAssertEqual(try inventory(root), before)
    }

    func testPackagedCheckerRejectsUnsupportedDiagnoseFormatWithLegacyUsageExit() throws {
        let helper = try packagedHelper()
        let root = try validFixture()

        let result = try run(helper, arguments: ["diagnose", "--root", root.path, "--format", "yaml"])

        XCTAssertEqual(result.status, 64)
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(
            result.stderr,
            "Usage: ReleaseRadarDocumentationTool <check|write> --root <absolute-repository-root>\n"
        )
    }

    func testPackagedCheckerPreservesCheckAndWriteOutputs() throws {
        let helper = try packagedHelper()
        let root = try validFixture()

        let write = try run(helper, arguments: ["write", "--root", root.path])
        let check = try run(helper, arguments: ["check", "--root", root.path])

        XCTAssertEqual(write.status, 0, write.stderr)
        XCTAssertEqual(write.stderr, "")
        XCTAssertEqual(
            write.stdout,
            "Updated 2 managed index file(s).\ndocs/README.md\ndocs/plans/README.md\n"
        )
        XCTAssertEqual(check.status, 0, check.stderr)
        XCTAssertEqual(check.stderr, "")
        XCTAssertEqual(check.stdout, "Repository documentation indexes match the catalog.\n")
    }

    private func packagedHelper() throws -> URL {
        let prompt = CodexPromptHandoff.prompt(for: .missing, projectRoot: URL(fileURLWithPath: "/example"))
        let helperLine = try XCTUnwrap(prompt.split(separator: "\n").first { $0.hasPrefix("Documentation checker: ") })
        return URL(fileURLWithPath: String(helperLine.dropFirst("Documentation checker: ".count)))
    }

    private func run(_ helper: URL, arguments: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = helper
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: stdoutData, as: UTF8.self),
            String(decoding: stderrData, as: UTF8.self)
        )
    }

    private var fixtureSource: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RepositoryDocuments/valid")
    }

    private func validFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("ReleaseRadar-SharedExecution-CLI-\(UUID().uuidString)")
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
}
