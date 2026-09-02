import Foundation
import XCTest
@testable import ReleaseRadar

final class DocumentationToolInstallationTests: XCTestCase {
    func testPackagedCheckerRunsAndFindsItsShippedReference() throws {
        let prompt = CodexPromptHandoff.prompt(for: .missing, projectRoot: URL(fileURLWithPath: "/example"))
        let helperLine = try XCTUnwrap(prompt.split(separator: "\n").first { $0.hasPrefix("Documentation checker: ") })
        let helper = URL(fileURLWithPath: String(helperLine.dropFirst("Documentation checker: ".count)))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helper.path), "The installed app must include the checker")
        let process = Process()
        process.executableURL = helper
        process.arguments = ["--help"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, text)
        let referenceLine = try XCTUnwrap(text.split(separator: "\n").first { $0.hasPrefix("Catalog v1 reference: ") })
        let reference = String(referenceLine.dropFirst("Catalog v1 reference: ".count))
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: reference))
        XCTAssertTrue(reference.hasPrefix(Bundle.main.bundleURL.path + "/Contents/Resources/"))
    }
}
