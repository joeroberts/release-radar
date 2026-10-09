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
elif operation == "tag-state":
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
    print("d" * 64)
elif operation == "copy-bundle":
    target = pathlib.Path(operands[1]); target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(operands[0], target)
    pathlib.Path(operands[0]).with_suffix(pathlib.Path(operands[0]).suffix + ".identity").replace(target.with_suffix(target.suffix + ".identity"))
elif operation == "remote-peeled-sha":
    print((root / "head").read_text().strip())
elif operation in {"prepare-version", "commit-release-metadata", "prepare-libgit2", "stop-running", "create-tag", "push-tag"}:
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
        self.assertEqual(1, receipt["schema_version"])
        self.assertEqual(SHA, receipt["candidate"]["source_revision"])
        self.assertEqual([SUITE], receipt["candidate"]["required_suite_ids"])
        self.assertEqual(str(self.root / "dist" / "ReleaseRadar.app"), receipt["destinations"]["staged_bundle"])
        self.assertEqual(str(self.root / "dist" / f"ReleaseRadar-{VERSION}.dmg"), receipt["destinations"]["dmg"])
        self.assertEqual(str(self.root / "Downloads" / f"ReleaseRadar-{VERSION}.dmg"), receipt["destinations"]["installer"])
        self.assertEqual(str(self.root / "Applications" / "ReleaseRadar.app"), receipt["destinations"]["installed_bundle"])
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

    def test_head_or_preflight_mismatch_records_bounded_failure_before_suite_or_build(self) -> None:
        (self.root / "head").write_text("b" * 40 + "\n")
        self.initialize()
        self.stage("preflight", expected=1)
        receipt = self.receipt_json()
        self.assertEqual("preflight", receipt["failure"]["stage"])
        self.assertIn("code", receipt["failure"])
        self.assertIn("message", receipt["failure"])
        self.assertNotIn("run-suite", self.operations())
        self.assertNotIn("build-stage", self.operations())

    def test_missing_or_nonpassing_required_suite_cannot_unlock_stage(self) -> None:
        self.initialize()
        self.stage("preflight")
        self.stage("stage", expected=1)
        self.assertNotIn("build-stage", self.operations())
        (self.root / "operations" / "fail-suite").touch()
        self.stage("checks", expected=1)
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
