import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RecognizedPluginCapabilityTests: XCTestCase {
    func testRegistryRecognizesOnlyExactVersionAndDigestPairs() {
        let legacyDigest = "75f513d53675b6ae5679d2add575b76f9d32575d605f77702fd91a8c70d9f198"
        let sharedExecutionDigest = "ecc221b2ca91ac8913e73555b6ed310bce63d7f1ac9462d05b025478173d5a40"
        let currentDigest = "b01335654a5dedcf2055c9bfa3e074e478f75dd2b9e4171dd16c1f2a4427ef83"
        let priorReleaseDigest = "7f70bcd7a4fac4fe038dc00945b8fb56d3cdd472ec7f7816c40812631107939c"
        let releaseDigest = "2677797fd17f0091821cca09653f9951ab9007ef578a1226458faf632d319a9d"
        let toolbarReleaseDigest = "8f23498996d2beb1994db711d39527ef42a96ffab6344d1976e5e18f925e90eb"
        let addProjectRDSReleaseDigest = "13e101216ce3e2ed3d7ad1f0fd9c649b8a36ed12a459a5ff18aad105fb6e731e"

        XCTAssertEqual(RecognizedPluginCapability.known, [
            .init(manifestVersion: "0.1.7", normalizedPackageDigest: legacyDigest,
                  sharedExecutionStandardVersions: []),
            .init(manifestVersion: "0.1.8", normalizedPackageDigest: sharedExecutionDigest,
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.9", normalizedPackageDigest: currentDigest,
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.10", normalizedPackageDigest: priorReleaseDigest,
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.11", normalizedPackageDigest: releaseDigest,
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.12", normalizedPackageDigest: "8f23498996d2beb1994db711d39527ef42a96ffab6344d1976e5e18f925e90eb",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.14", normalizedPackageDigest: addProjectRDSReleaseDigest,
                  sharedExecutionStandardVersions: [1]),
        ])
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: "0.1.7",
                normalizedPackageDigest: legacyDigest
            )?.sharedExecutionStandardVersions,
            []
        )
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: "0.1.8",
                normalizedPackageDigest: sharedExecutionDigest
            )?.sharedExecutionStandardVersions,
            [1]
        )
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: "0.1.9",
                normalizedPackageDigest: currentDigest
            )?.sharedExecutionStandardVersions,
            [1]
        )
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: "0.1.10",
                normalizedPackageDigest: priorReleaseDigest
            )?.sharedExecutionStandardVersions,
            [1]
        )
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: "0.1.11",
                normalizedPackageDigest: releaseDigest
            )?.sharedExecutionStandardVersions,
            [1]
        )
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: "0.1.12",
                normalizedPackageDigest: toolbarReleaseDigest
            )?.sharedExecutionStandardVersions,
            [1]
        )
        XCTAssertNil(RecognizedPluginCapability.recognize(
            manifestVersion: "0.1.8",
            normalizedPackageDigest: currentDigest
        ))
        XCTAssertNil(RecognizedPluginCapability.recognize(
            manifestVersion: "0.1.9",
            normalizedPackageDigest: sharedExecutionDigest
        ))
        XCTAssertNil(RecognizedPluginCapability.recognize(
            manifestVersion: "0.1.7",
            normalizedPackageDigest: currentDigest
        ))
        XCTAssertNil(RecognizedPluginCapability.recognize(
            manifestVersion: "0.1.14",
            normalizedPackageDigest: currentDigest
        ))
    }

    func testBundledPackageUsesTheCurrentFrozenInventoryAndCapability() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try CodexPluginPackage(
            rootURL: repositoryRoot.appendingPathComponent("ReleaseRadar/CodexPluginMarketplace")
        )

        XCTAssertEqual(package.version, "0.1.14")
        XCTAssertEqual(package.relativeFiles, [
            ".codex-plugin/plugin.json",
            ".mcp.json",
            "skills/release-radar/SKILL.md",
            "skills/shared-execution/SKILL.md",
        ])
        XCTAssertEqual(
            RecognizedPluginCapability.recognize(
                manifestVersion: package.version,
                normalizedPackageDigest: package.digest
            )?.sharedExecutionStandardVersions,
            [1]
        )
    }

    func testLifecycleHelperRetainsLegacyAndCurrentPackageInventories() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("ReleaseRadarPluginLifecycleHelper/main.swift"),
            encoding: .utf8
        )
        let start = try XCTUnwrap(source.range(of: "private enum PluginDigester"))
        let end = try XCTUnwrap(
            source.range(of: "\nprivate extension Int", range: start.upperBound..<source.endIndex)
        )
        let digester = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(digester.contains(
            #"private static let legacyFiles = [".codex-plugin/plugin.json", ".mcp.json", "skills/release-radar/SKILL.md"]"#
        ))
        XCTAssertTrue(digester.contains(
            #"private static let files = legacyFiles + ["skills/shared-execution/SKILL.md"]"#
        ))
        XCTAssertTrue(digester.contains("inventory.sorted() == legacyFiles.sorted()"))
        XCTAssertTrue(digester.contains("inventory.sorted() == files.sorted()"))
        XCTAssertTrue(digester.contains("for relative in packageFiles.sorted"))
    }
}
