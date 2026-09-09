import Foundation
import XCTest

final class SharedExecutionSkillContractTests: XCTestCase {
    func testBundledSkillCarriesTheReviewedV1ContractAndExactAdoptionBlock() throws {
        let skill = try String(contentsOf: skillURL, encoding: .utf8)
        let design = try String(contentsOf: designURL, encoding: .utf8)
        let adoptionBlock = try fencedAdoptionBlock(in: design)

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
        XCTAssertTrue(skill.contains(adoptionBlock))
    }

    func testBundledPluginAddsNoHookOrGenericRunnerDeclaration() throws {
        let manifestData = try Data(contentsOf: packageRoot.appendingPathComponent(".codex-plugin/plugin.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let skill = try String(contentsOf: skillURL, encoding: .utf8)

        XCTAssertEqual(manifest["version"] as? String, "0.1.8")
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

    private var designURL: URL {
        repositoryRoot.appendingPathComponent("docs/design/shared-execution-integration-v1-design.md")
    }

    private func fencedAdoptionBlock(in design: String) throws -> String {
        let fence = "```markdown\n<!-- release-radar-shared-execution:v1:start -->"
        let fencedStart = try XCTUnwrap(design.range(of: fence))
        let blockStart = design.index(fencedStart.lowerBound, offsetBy: "```markdown\n".count)
        let blockEnd = try XCTUnwrap(
            design.range(of: "\n```", range: blockStart..<design.endIndex)
        ).lowerBound
        return String(design[blockStart..<blockEnd])
    }
}
