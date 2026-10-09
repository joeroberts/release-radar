import Foundation
import XCTest
@testable import ReleaseRadarCore

final class SharedExecutionSkillContractTests: XCTestCase {
    func testBundledSkillCarriesTheReviewedV1ContractAndExactAdoptionBlock() throws {
        let skill = try String(contentsOf: skillURL, encoding: .utf8)
        let adoptionBlock = try String(contentsOf: expectedAdoptionBlockURL, encoding: .utf8)

        XCTAssertTrue(skill.contains("name: shared-execution"))
        XCTAssertTrue(skill.contains("description: Use when"))
        XCTAssertTrue(skill.contains("shared-execution-standard: 1"))
        for clause in 1...10 {
            XCTAssertTrue(skill.contains("SEI-\(clause)"), "Missing SEI-\(clause)")
        }
        for field in [
            "Standard", "Root", "Outcome", "Scope", "Authority", "Endpoint",
            "Direct checks", "Review",
        ] {
            XCTAssertTrue(skill.contains("| \(field) |"), "Missing task field \(field)")
        }
        for field in [
            "Check", "Runner", "Scope", "Source", "Applicability", "Status",
            "Direct result", "Limitation",
        ] {
            XCTAssertTrue(skill.contains("`\(field)`"), "Missing result field \(field)")
        }
        for status in ["passed", "failed", "skipped", "unavailable", "unknown", "notRun"] {
            XCTAssertTrue(skill.contains("`\(status)`"), "Missing result status \(status)")
        }
        for applicability in ["exactRevision", "workingTree", "unknown"] {
            XCTAssertTrue(skill.contains("`\(applicability)`"), "Missing applicability \(applicability)")
        }
        XCTAssertTrue(skill.contains(SharedExecutionDeclarationInspector.managedBlock))
        XCTAssertTrue(skill.contains(adoptionBlock))
    }

    func testBundledPluginAddsNoHookOrGenericRunnerDeclaration() throws {
        let manifestData = try Data(contentsOf: packageRoot.appendingPathComponent(".codex-plugin/plugin.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let skill = try String(contentsOf: skillURL, encoding: .utf8)

        let package = try CodexPluginPackage(
            rootURL: repositoryRoot.appendingPathComponent("ReleaseRadar/CodexPluginMarketplace")
        )
        XCTAssertEqual(manifest["version"] as? String, package.version)
        XCTAssertNil(manifest["hooks"])
        XCTAssertFalse(skill.contains("command-schema"))
        XCTAssertFalse(skill.contains("attestation-schema"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private var packageRoot: URL {
        repositoryRoot.appendingPathComponent(
            "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar",
            isDirectory: true
        )
    }

    private var skillURL: URL {
        packageRoot.appendingPathComponent("skills/shared-execution/SKILL.md")
    }

    private var expectedAdoptionBlockURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/ProductContracts/SharedExecution/expected-adoption-block.md")
    }
}
