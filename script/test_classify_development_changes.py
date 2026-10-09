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
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
CLASSIFIER = REPOSITORY / "script/classify_development_changes.py"
COLLECTOR = REPOSITORY / "script/collect_development_changed_paths.sh"
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

    def test_release_delivery_scripts_are_application_changes_without_documentation_runs(self) -> None:
        for path in ["script/release_delivery.py", "script/test_release_delivery_fixture.py"]:
            with self.subTest(path=path):
                self.assert_route(
                    [path],
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
            b".githooks/pre-commit\0",
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


class DevelopmentChangedPathCollectionTests(unittest.TestCase):
    """Exercise the workflow-owned diff boundary with real, isolated Git history."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="rr-ci-routing-qa-")
        self.addCleanup(self.temporary.cleanup)
        self.repository = Path(self.temporary.name) / "repository"
        self.repository.mkdir()
        self.git("init", "-q", "--initial-branch=main")
        self.git("config", "user.name", "QA Fixture")
        self.git("config", "user.email", "qa@example.invalid")
        self.write("README.md", "baseline\n")
        self.git("add", "README.md")
        self.git("commit", "-qm", "baseline")

    def git(self, *arguments: str) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.repository,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )

    def write(self, path: str, contents: str) -> None:
        target = self.repository / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents)

    def revision(self, reference: str) -> str:
        return self.git("rev-parse", reference).stdout.decode().strip()

    def collect(self, *arguments: str) -> bytes:
        self.assertTrue(COLLECTOR.is_file(), f"missing production diff collector: {COLLECTOR}")
        result = subprocess.run(
            ["bash", str(COLLECTOR), *arguments],
            cwd=self.repository,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr.decode(errors="replace"))
        return result.stdout

    def paths(self, *arguments: str) -> list[str]:
        output = self.collect(*arguments)
        self.assertTrue(output.endswith(b"\0"), output)
        return [part.decode() for part in output[:-1].split(b"\0")]

    def test_pull_request_uses_merge_base_and_captures_every_commit(self) -> None:
        self.git("switch", "-qc", "feature")
        self.write("docs/README.md", "first feature commit\n")
        self.git("add", "docs/README.md")
        self.git("commit", "-qm", "docs change")
        self.write("ReleaseRadar/App/Feature.swift", "second feature commit\n")
        self.git("add", "ReleaseRadar/App/Feature.swift")
        self.git("commit", "-qm", "source change")

        self.assertEqual(
            ["ReleaseRadar/App/Feature.swift", "docs/README.md"],
            sorted(self.paths("--pull-request", "main", "feature")),
        )

    def test_push_uses_the_complete_before_after_range(self) -> None:
        before = self.revision("HEAD")
        self.write("docs/new-guide.md", "first push commit\n")
        self.git("add", "docs/new-guide.md")
        self.git("commit", "-qm", "first push commit")
        self.write("ReleaseRadarCore/NewFeature.swift", "second push commit\n")
        self.git("add", "ReleaseRadarCore/NewFeature.swift")
        self.git("commit", "-qm", "second push commit")
        after = self.revision("HEAD")

        self.assertEqual(
            ["ReleaseRadarCore/NewFeature.swift", "docs/new-guide.md"],
            sorted(self.paths("--push", before, after)),
        )

    def test_rename_and_delete_emit_preimage_and_postimage_paths(self) -> None:
        self.write("ReleaseRadar/CodexPluginMarketplace/old-runtime.md", "runtime input\n")
        self.write("ReleaseRadar/obsolete.swift", "obsolete\n")
        self.git("add", "ReleaseRadar/CodexPluginMarketplace/old-runtime.md", "ReleaseRadar/obsolete.swift")
        self.git("commit", "-qm", "add rename and delete inputs")
        self.git("switch", "-qc", "feature")
        self.git("mv", "ReleaseRadar/CodexPluginMarketplace/old-runtime.md", "ReleaseRadar/CodexPluginMarketplace/new-runtime.md")
        self.git("rm", "-q", "ReleaseRadar/obsolete.swift")
        self.git("commit", "-qm", "rename and delete inputs")

        self.assertEqual(
            [
                "ReleaseRadar/CodexPluginMarketplace/new-runtime.md",
                "ReleaseRadar/CodexPluginMarketplace/old-runtime.md",
                "ReleaseRadar/obsolete.swift",
            ],
            sorted(self.paths("--pull-request", "main", "feature")),
        )

    def test_invalid_refs_and_zero_before_are_empty_fail_closed_input(self) -> None:
        self.assertEqual(b"", self.collect("--pull-request", "missing-base", "missing-head"))
        self.assertEqual(
            b"",
            self.collect("--push", "0000000000000000000000000000000000000000", self.revision("HEAD")),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
