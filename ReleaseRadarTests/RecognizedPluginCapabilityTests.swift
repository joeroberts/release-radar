import Foundation
import XCTest
@testable import ReleaseRadarCore

final class RecognizedPluginCapabilityTests: XCTestCase {
    func testRegistryRecognizesOnlyExactVersionAndDigestPairs() {
        let legacyDigest = "75f513d53675b6ae5679d2add575b76f9d32575d605f77702fd91a8c70d9f198"
        let sharedExecutionDigest = "ecc221b2ca91ac8913e73555b6ed310bce63d7f1ac9462d05b025478173d5a40"
        let currentDigest = "dce1de894394ce26bdc556a1bc80ff472951a3487ae9bfc857f0efa5093c1f19"

        XCTAssertEqual(RecognizedPluginCapability.known, [
            .init(manifestVersion: "0.1.7", normalizedPackageDigest: legacyDigest,
                  sharedExecutionStandardVersions: []),
            .init(manifestVersion: "0.1.8", normalizedPackageDigest: sharedExecutionDigest,
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.9", normalizedPackageDigest: currentDigest,
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
            manifestVersion: "0.1.10",
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

        XCTAssertEqual(package.version, "0.1.9")
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
