#!/usr/bin/env python3
"""Fixture-only QA contract tests for the shared #132/#114 release flow."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "script/build_and_run.sh"
VERSION = "1.2.3"
BUILD = "42"
TAG = f"v{VERSION}"
SUITE = "release-radar-tests-v1"
SHA = "a" * 40

ADAPTER = r'''#!/usr/bin/env python3
import json
import pathlib
import shutil
import sys

args = sys.argv[1:]
if len(args) < 5 or args[0] != "--root" or args[2] != "--receipt":
    raise SystemExit("invalid adapter argv")
root, receipt, operation = pathlib.Path(args[1]), pathlib.Path(args[3]), args[4]
operands = args[5:]
(root / "operations.log").open("a").write(operation + "\n")
fail = lambda name: (root / "operations" / ("fail-" + name)).exists()

if operation == "head":
    print((root / "head").read_text().strip())
elif operation == "source-state":
    if fail("source-state-unavailable"):
        sys.exit(1)
    print(json.dumps({"clean": not fail("source-state")}, separators=(",", ":")))
elif operation == "tag-state":
    if fail("tag-collision"):
        print('{"state":"mismatch","peeled_sha":"' + "b" * 40 + '"}')
    elif fail("tag-mismatched-peel"):
        print('{"state":"matching-annotated","peeled_sha":"' + "b" * 40 + '"}')
    elif fail("tag-after-create") and (root / "operations" / "tag-created").exists():
        print('{"state":"mismatch","peeled_sha":"' + "b" * 40 + '"}')
    elif (root / "operations" / "tag-created").exists():
        print('{"state":"matching-annotated","peeled_sha":"' + (root / "head").read_text().strip() + '"}')
    else:
        print('{"state":"absent"}')
elif operation == "signing-status":
    print('{"available":true,"team_matches":true,"authority_matches":true}')
elif operation == "run-suite":
    print(json.dumps({"outcome": "failed" if fail("suite") else "passed"}, separators=(",", ":")))
elif operation == "build-stage":
    target = pathlib.Path(operands[0]); target.parent.mkdir(parents=True, exist_ok=True); target.write_text("staged\n")
    target.with_suffix(target.suffix + ".identity").write_text("com.rekonlabs.ReleaseRadar/1.2.3/42\n")
elif operation == "verify-bundle":
    sys.exit(1 if fail("verify") else 0)
elif operation == "bundle-identity":
    print(pathlib.Path(operands[0]).with_suffix(pathlib.Path(operands[0]).suffix + ".identity").read_text().strip())
elif operation == "package-dmg":
    target = pathlib.Path(operands[1]); target.parent.mkdir(parents=True, exist_ok=True); target.write_text("dmg\n")
    sys.exit(1 if fail("package") else 0)
elif operation == "dmg-sha256":
    path = pathlib.Path(operands[0])
    print("e" * 64 if fail("installer-digest") and "Downloads" in path.parts else "d" * 64)
elif operation == "copy-bundle":
    target = pathlib.Path(operands[1]); target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(operands[0], target)
    pathlib.Path(operands[0]).with_suffix(pathlib.Path(operands[0]).suffix + ".identity").replace(target.with_suffix(target.suffix + ".identity"))
elif operation == "remote-peeled-sha":
    print((root / "head").read_text().strip())
elif operation == "create-tag":
    (root / "operations" / "tag-created").touch()
    sys.exit(1 if fail(operation) else 0)
elif operation in {"prepare-version", "commit-release-metadata", "prepare-libgit2", "stop-running", "push-tag"}:
    sys.exit(1 if fail(operation) else 0)
else:
    raise SystemExit("unexpected operation: " + operation)
'''


class ReleaseDeliveryFixtureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="rr-release-delivery-qa-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "operations").mkdir()
        (self.root / "head").write_text(SHA + "\n")
        self.adapter = self.root / "adapter.py"
        self.adapter.write_text(ADAPTER)
        self.adapter.chmod(0o700)

    @property
    def receipt(self) -> Path:
        return self.root / "Downloads" / f"ReleaseRadar-{VERSION}.release.json"

    def command(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT), *arguments], cwd=REPOSITORY, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )

    def flags(self) -> list[str]:
        return ["--fixture-root", str(self.root), "--operations-adapter", str(self.adapter)]

    def initialize(self) -> None:
        result = self.command(
            "release-init", "--version", VERSION, "--build", BUILD,
            "--required-suite", SUITE, *self.flags(),
        )
        self.assertEqual(0, result.returncode, result.stderr)

    def stage(self, name: str, expected: int = 0) -> subprocess.CompletedProcess[str]:
        result = self.command("release-delivery", "--version", VERSION, "--stage", name, *self.flags())
        self.assertEqual(expected, result.returncode, result.stderr)
        return result

    def receipt_json(self) -> dict[str, object]:
        return json.loads(self.receipt.read_text())

    def operations(self) -> list[str]:
        log = self.root / "operations.log"
        return log.read_text().splitlines() if log.exists() else []

    def test_init_derives_receipt_sha_and_all_destinations_from_version(self) -> None:
        self.initialize()
        receipt = self.receipt_json()
        fixture_root = self.root.resolve()
        self.assertEqual(1, receipt["schema_version"])
        self.assertEqual(SHA, receipt["candidate"]["source_revision"])
        self.assertEqual([SUITE], receipt["candidate"]["required_suite_ids"])
        release_directory = fixture_root / ".build" / "releases" / VERSION
        self.assertEqual(str(release_directory / "ReleaseRadar.app"), receipt["destinations"]["staged_bundle"])
        self.assertEqual(str(release_directory / f"ReleaseRadar-{VERSION}.dmg"), receipt["destinations"]["dmg"])
        self.assertEqual(str(fixture_root / "Downloads" / f"ReleaseRadar-{VERSION}.dmg"), receipt["destinations"]["installer"])
        self.assertEqual(str(fixture_root / "Applications" / "ReleaseRadar.app"), receipt["destinations"]["installed_bundle"])
        self.assertEqual(
            {stage: "pending" for stage in ("preflight", "checks", "stage", "package", "install", "tag", "push_tag")},
            receipt["stages"],
        )
        self.assertIsNone(receipt["failure"])
        text = self.receipt.read_text().lower()
        for forbidden in ("token", "private_key", "entitlement", "stderr", "stdout"):
            self.assertNotIn(forbidden, text)

    def test_fixture_flags_must_be_paired_and_cannot_escape_root(self) -> None:
        one_flag = self.command("release-init", "--version", VERSION, "--build", BUILD, "--required-suite", SUITE,
                                "--fixture-root", str(self.root))
        self.assertNotEqual(0, one_flag.returncode)
        escaped = self.command("release-init", "--version", VERSION, "--build", BUILD, "--required-suite", SUITE,
                               "--fixture-root", str(self.root), "--operations-adapter", "/tmp/adapter")
        self.assertNotEqual(0, escaped.returncode)
        self.assertFalse(self.receipt.exists())

    def test_legacy_receipt_temp_symlink_cannot_escape_fixture_root(self) -> None:
        outside_temporary = tempfile.TemporaryDirectory(prefix="rr-release-delivery-outside-")
        self.addCleanup(outside_temporary.cleanup)
        sentinel = Path(outside_temporary.name) / "sentinel"
        sentinel.write_text("keep\n")
        self.receipt.parent.mkdir(parents=True, exist_ok=True)
        self.receipt.with_suffix(".json.tmp").symlink_to(sentinel)
        result = self.command(
            "release-init", "--version", VERSION, "--build", BUILD,
            "--required-suite", SUITE, *self.flags(),
        )
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("keep\n", sentinel.read_text())
        self.assertEqual([], self.operations())

    def test_head_or_preflight_mismatch_records_bounded_failure_before_suite_or_build(self) -> None:
        self.initialize()
        (self.root / "head").write_text("b" * 40 + "\n")
        self.stage("preflight", expected=1)
        receipt = self.receipt_json()
        self.assertEqual("preflight", receipt["failure"]["stage"])
        self.assertIn("code", receipt["failure"])
        self.assertIn("safe_message", receipt["failure"])
        self.assertNotIn("run-suite", self.operations())
        self.assertNotIn("build-stage", self.operations())

    def test_dirty_source_after_init_blocks_checks_before_suite_execution(self) -> None:
        self.initialize()
        self.stage("preflight")
        (self.root / "operations" / "fail-source-state").touch()
        self.stage("checks", expected=1)
        self.assertNotIn("prepare-libgit2", self.operations())
        self.assertNotIn("run-suite", self.operations())

    def test_unavailable_source_state_blocks_checks_before_suite_execution(self) -> None:
        self.initialize()
        self.stage("preflight")
        (self.root / "operations" / "fail-source-state-unavailable").touch()
        self.stage("checks", expected=1)
        self.assertNotIn("prepare-libgit2", self.operations())
        self.assertNotIn("run-suite", self.operations())

    def test_tag_collision_stops_before_release_metadata_mutation(self) -> None:
        (self.root / "operations" / "fail-tag-collision").touch()
        result = self.command(
            "release-init", "--version", VERSION, "--build", BUILD,
            "--required-suite", SUITE, *self.flags(),
        )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("tag-state", self.operations())
        self.assertNotIn("prepare-version", self.operations())
        self.assertNotIn("commit-release-metadata", self.operations())

    def test_shaped_but_wrong_tag_sha_fails_preflight(self) -> None:
        self.initialize()
        (self.root / "operations" / "fail-tag-mismatched-peel").touch()
        self.stage("preflight", expected=1)
        self.assertNotIn("create-tag", self.operations())

    def test_tag_creation_requires_post_create_candidate_identity(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage", "package", "install"):
            self.stage(name)
        (self.root / "operations" / "fail-tag-after-create").touch()
        self.stage("tag", expected=1)
        self.assertIn("create-tag", self.operations())
        self.assertNotIn("push-tag", self.operations())

    def test_missing_or_nonpassing_required_suite_cannot_unlock_stage(self) -> None:
        self.initialize()
        self.stage("preflight")
        self.stage("stage", expected=1)
        self.assertNotIn("build-stage", self.operations())
        (self.root / "operations" / "fail-suite").touch()
        self.stage("checks", expected=1)
        self.assertNotIn("build-stage", self.operations())

    def test_failed_check_rerun_invalidates_prior_passing_evidence(self) -> None:
        self.initialize()
        self.stage("preflight")
        self.stage("checks")
        (self.root / "operations" / "fail-prepare-libgit2").touch()
        self.stage("checks", expected=1)
        self.stage("stage", expected=1)
        self.assertNotIn("build-stage", self.operations())

    def test_failed_check_rerun_invalidates_prior_tag_before_push(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage", "package", "install", "tag"):
            self.stage(name)
        (self.root / "operations" / "fail-prepare-libgit2").touch()
        self.stage("checks", expected=1)
        self.stage("push_tag", expected=1)
        self.assertNotIn("push-tag", self.operations())

    def test_unrecorded_staged_bundle_is_not_adopted(self) -> None:
        self.initialize()
        self.stage("preflight")
        self.stage("checks")
        staged = self.root / ".build" / "releases" / VERSION / "ReleaseRadar.app"
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_text("old staged app\n")
        staged.with_suffix(staged.suffix + ".identity").write_text("old identity\n")
        self.stage("stage", expected=1)
        self.assertNotIn("build-stage", self.operations())

    def test_libgit2_or_package_failure_never_reaches_install_or_tag(self) -> None:
        self.initialize()
        self.stage("preflight")
        (self.root / "operations" / "fail-prepare-libgit2").touch()
        self.stage("checks", expected=1)
        self.assertNotIn("build-stage", self.operations())
        self.assertNotIn("stop-running", self.operations())
        self.assertNotIn("create-tag", self.operations())

    def test_invalid_staged_candidate_never_stops_or_replaces_installed_bundle(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage", "package"):
            self.stage(name)
        (self.root / "operations" / "fail-verify").touch()
        self.stage("install", expected=1)
        operations = self.operations()
        self.assertIn("verify-bundle", operations)
        self.assertNotIn("stop-running", operations)
        self.assertNotIn("copy-bundle", operations)
        self.assertFalse((self.root / "Applications" / "ReleaseRadar.app").exists())

    def test_package_failure_cannot_reach_install_or_tag(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage"):
            self.stage(name)
        (self.root / "operations" / "fail-package").touch()
        self.stage("package", expected=1)
        self.assertNotIn("stop-running", self.operations())
        self.assertNotIn("copy-bundle", self.operations())
        self.assertNotIn("create-tag", self.operations())

    def test_retained_installer_digest_mismatch_blocks_delivery(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage"):
            self.stage(name)
        (self.root / "operations" / "fail-installer-digest").touch()
        self.stage("package", expected=1)
        receipt = self.receipt_json()
        self.assertEqual("installer_mismatch", receipt["failure"]["code"])
        self.assertNotIn("stop-running", self.operations())
        self.assertNotIn("copy-bundle", self.operations())
        self.assertNotIn("create-tag", self.operations())

    def test_failed_package_rerun_invalidates_install_eligibility(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage", "package"):
            self.stage(name)
        (self.root / "operations" / "fail-installer-digest").touch()
        self.stage("package", expected=1)
        self.stage("install", expected=1)
        self.assertNotIn("stop-running", self.operations())
        self.assertNotIn("copy-bundle", self.operations())

    def test_incompatible_existing_destination_is_rejected_before_stop(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage", "package"):
            self.stage(name)
        installed = self.root / "Applications" / "ReleaseRadar.app"
        installed.parent.mkdir(parents=True, exist_ok=True)
        installed.write_text("old installed app\n")
        installed.with_suffix(installed.suffix + ".identity").write_text("old identity\n")
        (self.root / "operations" / "fail-verify").touch()
        self.stage("install", expected=1)
        self.assertNotIn("stop-running", self.operations())
        self.assertNotIn("copy-bundle", self.operations())

    def test_tag_and_push_require_matching_verified_identity(self) -> None:
        self.initialize()
        for name in ("preflight", "checks", "stage", "package", "install"):
            self.stage(name)
        (self.root / "head").write_text("c" * 40 + "\n")
        self.stage("tag", expected=1)
        self.assertNotIn("create-tag", self.operations())
        self.assertNotIn("push-tag", self.operations())


if __name__ == "__main__":
    unittest.main(verbosity=2)
