#!/usr/bin/env python3
"""QA contract tests for #166 selective GitHub Actions routing.

The production classifier deliberately accepts changed paths rather than
retrieving GitHub diffs.  These tests exercise the classification boundary;
the final test also keeps the workflow responsible for complete PR/push diff
collection and a stable required-check context.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
CLASSIFIER = REPOSITORY / "script/classify_development_changes.py"
WORKFLOW = REPOSITORY / ".github/workflows/development-documentation.yml"
RUN_KEYS = {
    "run_docs_validation",
    "run_swift_docs_checker_tests",
    "run_adr_checker_tests",
    "run_routing_tests",
}
CATEGORY_KEYS = {
    "docs",
    "swift_docs_checker",
    "adr_checker",
    "app",
    "workflow",
    "unknown",
}
EXPECTED_KEYS = {"schema_version", "fallback_reason"} | RUN_KEYS | CATEGORY_KEYS


class DevelopmentChangeClassifierTests(unittest.TestCase):
    maxDiff = None

    def classify(self, paths: list[str] | None = None, *, raw: bytes | None = None) -> dict[str, object]:
        if raw is None:
            self.assertIsNotNone(paths)
            raw = b"".join(path.encode() + b"\0" for path in paths or [])
        result = subprocess.run(
            ["python3", str(CLASSIFIER), "--changed-paths-stdin"],
            cwd=REPOSITORY,
            input=raw,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr.decode(errors="replace"))
        self.assertTrue(result.stdout.endswith(b"\n"), result.stdout)
        value = json.loads(result.stdout)
        self.assertEqual(EXPECTED_KEYS, set(value), value)
        self.assertEqual(1, value["schema_version"])
        for key in RUN_KEYS | CATEGORY_KEYS:
            self.assertIsInstance(value[key], bool, key)
        self.assertTrue(
            value["fallback_reason"] is None or bool(value["fallback_reason"]),
            value,
        )
        return value

    def assert_route(self, paths: list[str], **expected: object) -> None:
        actual = self.classify(paths)
        self.assertIsNone(actual["fallback_reason"], actual)
        for key, value in expected.items():
            self.assertEqual(value, actual[key], actual)

    def assert_fallback(self, raw: bytes) -> None:
        actual = self.classify(raw=raw)
        self.assertTrue(actual["unknown"], actual)
        self.assertTrue(actual["fallback_reason"], actual)
        for key in RUN_KEYS:
            self.assertTrue(actual[key], actual)

    def test_documentation_only_runs_only_documentation_validation(self) -> None:
        self.assert_route(
            ["docs/design/README.md", "README.md"],
            docs=True,
            swift_docs_checker=False,
            adr_checker=False,
            app=False,
            workflow=False,
            unknown=False,
            run_docs_validation=True,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=False,
            run_routing_tests=False,
        )

    def test_swift_documentation_checker_is_not_the_adr_checker(self) -> None:
        self.assert_route(
            ["script/check_development_docs.swift"],
            docs=False,
            swift_docs_checker=True,
            adr_checker=False,
            app=False,
            workflow=False,
            unknown=False,
            run_docs_validation=True,
            run_swift_docs_checker_tests=True,
            run_adr_checker_tests=False,
            run_routing_tests=False,
        )

    def test_adr_checker_implementation_and_fixtures_select_adr_tests(self) -> None:
        self.assert_route(
            [
                ".agents/skills/adr-management/scripts/adr_checker.py",
                "script/fixtures/adr-evals/malicious-adr.md",
            ],
            docs=False,
            swift_docs_checker=False,
            adr_checker=True,
            app=False,
            workflow=False,
            unknown=False,
            run_docs_validation=True,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=True,
            run_routing_tests=False,
        )

    def test_runtime_markdown_is_an_application_input_not_documentation_only(self) -> None:
        self.assert_route(
            ["ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/skills/release-radar/SKILL.md"],
            docs=False,
            swift_docs_checker=False,
            adr_checker=False,
            app=True,
            workflow=False,
            unknown=False,
            run_docs_validation=False,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=False,
            run_routing_tests=False,
        )

    def test_source_and_build_inputs_are_application_changes(self) -> None:
        self.assert_route(
            ["ReleaseRadar/App/AppModel.swift", "ReleaseRadar.xcodeproj/project.pbxproj", "dependencies/libgit2.json"],
            docs=False,
            swift_docs_checker=False,
            adr_checker=False,
            app=True,
            workflow=False,
            unknown=False,
            run_docs_validation=False,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=False,
            run_routing_tests=False,
        )

    def test_workflow_and_classifier_changes_select_routing_tests(self) -> None:
        self.assert_route(
            [".github/workflows/development-documentation.yml", "script/classify_development_changes.py"],
            docs=False,
            swift_docs_checker=False,
            adr_checker=False,
            app=False,
            workflow=True,
            unknown=False,
            run_docs_validation=False,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=False,
            run_routing_tests=True,
        )

    def test_mixed_changes_take_the_union(self) -> None:
        self.assert_route(
            ["docs/README.md", "script/test_adr_checker.py", "ReleaseRadarCore/Models/DeliveryModels.swift"],
            docs=True,
            swift_docs_checker=False,
            adr_checker=True,
            app=True,
            workflow=False,
            unknown=False,
            run_docs_validation=True,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=True,
            run_routing_tests=False,
        )

    def test_deleted_or_renamed_preimage_paths_are_classified(self) -> None:
        self.assert_route(
            ["ReleaseRadar/CodexPluginMarketplace/legacy-runtime.md"],
            docs=False,
            swift_docs_checker=False,
            adr_checker=False,
            app=True,
            workflow=False,
            unknown=False,
            run_docs_validation=False,
            run_swift_docs_checker_tests=False,
            run_adr_checker_tests=False,
            run_routing_tests=False,
        )

    def test_empty_malformed_and_unknown_input_fail_closed(self) -> None:
        for raw in [
            b"",
            b"docs/README.md",
            b"docs/README.md\0\0",
            b"/absolute/path\0",
            b"docs/../escape.md\0",
            b"unknown/input.ext\0",
            b"bad-utf8-\xff\0",
        ]:
            with self.subTest(raw=raw):
                self.assert_fallback(raw)

    def test_workflow_collects_complete_diffs_and_preserves_validate_context(self) -> None:
        text = WORKFLOW.read_text()
        self.assertIn("validate:", text)
        self.assertNotIn("paths-ignore:", text)
        self.assertIn("classify_development_changes.py", text)
        self.assertIn("merge-base", text, "PR routing must use the complete merge-base diff")
        self.assertIn("github.event.before", text, "push routing must use the complete before...after diff")
        self.assertIn("--no-renames", text, "rename/delete preimages must reach the classifier")
        self.assertIn("run_docs_validation", text)
        self.assertIn("run_adr_checker_tests", text)
        self.assertIn("run_routing_tests", text)
        self.assertIn("fallback", text.lower(), "diff failure must visibly take a safe fallback")


if __name__ == "__main__":
    unittest.main(verbosity=2)
