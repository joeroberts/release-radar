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
        let addProjectRDSReleaseDigest = "dfaed5c37d4d91e19743b4bae8539fe837a6b31e2aa4dede54ebe63685b1cb6a"

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
            .init(manifestVersion: "0.1.16", normalizedPackageDigest: addProjectRDSReleaseDigest,
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.17", normalizedPackageDigest: "94d7c1c3c506e3b62f7710e7e84df8ad4fc671b9029d06b1f0369b2882230a07",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.18", normalizedPackageDigest: "63f1f25156ff4738894aae72957e853936292e9c6f4299388a453e76701a1168",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.19", normalizedPackageDigest: "6275628c3b9e8b47e924b7b015c6532c31652fb7907638f372a2342d3a1bdf35",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.20", normalizedPackageDigest: "cb4863f28b85e31536cf61fae29c4062602152867ab3c66be98547055f7b5d5d",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.21", normalizedPackageDigest: "1fc6a145ecde33dfab53d32dad6dc3897e9b90eff39cd17c3cea7eca5eaa81c2",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.22", normalizedPackageDigest: "06e1dcc8f3f5efda400487cba566d7401dc8025dad7cbef75eedd8a6efe3fd10",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.23", normalizedPackageDigest: "a30ca6f866d5d192f5c5396fa634ab20f716f043f5a8de601de36612ac60b85c",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.24", normalizedPackageDigest: "91d4832283c38a4a0acb3af1c6618910e990859ec6c8ae4a8352260808eab251",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.25", normalizedPackageDigest: "791ae2b6d18cf06fcec7e22f7c4c68080561800946d94d1885ed70a0e5bb2aa5",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.26", normalizedPackageDigest: "9e23c922a4273449154699ec3063c3a3ecb8a35facf37de8be1e13d0eb7f793b",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.27", normalizedPackageDigest: "3855b92985d62b2b87544ff0d35eeda8cb998c76b7d6e3a831b8099d20ba7107",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.28", normalizedPackageDigest: "c79d9b7d79bf24c0d11a4e2caf74cf4901b5cd4ae4962dcc7ca160ff8f97cfcd",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.29", normalizedPackageDigest: "5c6ae4bac785fab77e8c2c27f8c8aae86bf4e15fd8774e6e147351722939e10d",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.30", normalizedPackageDigest: "58b26787e6f108a0de692b7aafda116d7c0918ce2cdfe279d54603eeeadea182",
                  sharedExecutionStandardVersions: [1]),
            .init(manifestVersion: "0.1.31", normalizedPackageDigest: "01c399bdf7e417904f055856a8fae787dadf3c8b59b44ffc8e44411cd05e6391",
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
            manifestVersion: "0.1.16",
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

        XCTAssertEqual(package.version, "0.1.31")
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
            contentsOf: repositoryRoot.appendingPathComponent("ReleaseRadarPluginLifecycleHelper/PluginDigester.swift"),
            encoding: .utf8
        )
        let start = try XCTUnwrap(source.range(of: "enum PluginDigester"))
        let digester = String(source[start.lowerBound...])

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
