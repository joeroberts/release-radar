#!/usr/bin/env python3
"""Fixture-only QA contract tests for the shared #132/#114 release flow."""

from __future__ import annotations

import json
import importlib.util
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "script/build_and_run.sh"
RELEASE_DELIVERY = REPOSITORY / "script/release_delivery.py"
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

    def release_delivery_module(self):
        spec = importlib.util.spec_from_file_location("release_delivery", RELEASE_DELIVERY)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        return module

    def metadata_fixture(self, directory: Path) -> Path:
        repository = directory / "repository"
        marketplace = "ReleaseRadar/CodexPluginMarketplace"
        for relative in (
            "ReleaseRadar.xcodeproj/project.pbxproj",
            "ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift",
        ):
            destination = repository / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPOSITORY / relative, destination)
        shutil.copytree(REPOSITORY / marketplace, repository / marketplace)
        return repository

    def test_prepare_release_metadata_updates_only_release_identity_and_appends_capability(self) -> None:
        fixture = self.metadata_fixture(self.root)
        project = fixture / "ReleaseRadar.xcodeproj/project.pbxproj"
        manifest = fixture / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json"
        capability = fixture / "ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift"
        plugin = manifest.parent.parent
        preserved = {
            relative: (plugin / relative).read_bytes()
            for relative in (".mcp.json", "skills/release-radar/SKILL.md", "skills/shared-execution/SKILL.md")
        }
        before_project = project.read_text()
        before_manifest = manifest.read_text()
        before_capability = capability.read_text()
        previous_version = json.loads(before_manifest)["version"]
        inherited_standards = re.findall(
            r"sharedExecutionStandardVersions: (\[[^\n]+\])", before_capability
        )[-1]
        marker = "\n    ]\n\n    public static func recognize"
        historical_prefix = before_capability[:before_capability.index(marker)]
        observed_roots: list[Path] = []

        def identity_provider(root: Path) -> str:
            observed_roots.append(root)
            return "d" * 64

        self.release_delivery_module().prepare_release_metadata(
            fixture, VERSION, BUILD, plugin_identity_provider=identity_provider
        )

        self.assertEqual([plugin], observed_roots)
        self.assertEqual(
            re.sub(r"(MARKETING_VERSION = )[^;]+;", rf"\g<1>{VERSION};", before_project)
            .replace(
                re.search(r"CURRENT_PROJECT_VERSION = [^;]+;", before_project).group(),
                f"CURRENT_PROJECT_VERSION = {BUILD};",
            ),
            project.read_text(),
        )
        self.assertEqual(
            before_manifest.replace(f'"version": "{previous_version}"', f'"version": "{VERSION}"'),
            manifest.read_text(),
        )
        self.assertEqual(
            preserved,
            {relative: (plugin / relative).read_bytes() for relative in preserved},
        )
        expected_capability = (
            historical_prefix
            + f'''\n        Self(\n            manifestVersion: "{VERSION}",\n            normalizedPackageDigest: "{'d' * 64}",\n            sharedExecutionStandardVersions: {inherited_standards}\n        ),\n    ]\n\n    public static func recognize'''
            + before_capability[before_capability.index(marker) + len(marker):]
        )
        self.assertEqual(expected_capability, capability.read_text())

    def test_prepare_release_metadata_rejects_conflicting_or_existing_plugin_metadata(self) -> None:
        module = self.release_delivery_module()
        conflict = self.metadata_fixture(self.root / "conflict")
        manifest = conflict / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json"
        current_version = json.loads(manifest.read_text())["version"]
        manifest.write_text(manifest.read_text().replace(
            f'"version": "{current_version}"', '"version": "9.9.9"',
        ))
        with self.assertRaises(ValueError):
            module.prepare_release_metadata(conflict, VERSION, BUILD, plugin_identity_provider=lambda _: "d" * 64)

        existing = self.metadata_fixture(self.root / "existing")
        existing_manifest = existing / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json"
        with self.assertRaises(ValueError):
            module.prepare_release_metadata(
                existing, json.loads(existing_manifest.read_text())["version"], BUILD,
                plugin_identity_provider=lambda _: "d" * 64,
            )

    def test_prepare_release_metadata_rejects_duplicate_manifest_version_before_mutation(self) -> None:
        fixture = self.metadata_fixture(self.root)
        manifest = fixture / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json"
        project = fixture / "ReleaseRadar.xcodeproj/project.pbxproj"
        capability = fixture / "ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift"
        manifest.write_text(manifest.read_text().replace(
            '  "version": "0.1.33",', '  "version": "0.1.33",\n  "version": "0.1.33",',
        ))
        originals = {path: path.read_bytes() for path in (project, manifest, capability)}
        with self.assertRaises(ValueError):
            self.release_delivery_module().prepare_release_metadata(
                fixture, VERSION, BUILD, plugin_identity_provider=lambda _: "d" * 64
            )
        self.assertEqual(originals, {path: path.read_bytes() for path in originals})

    def test_prepare_release_metadata_continues_rollback_after_one_restore_write_fails(self) -> None:
        fixture = self.metadata_fixture(self.root)
        project = fixture / "ReleaseRadar.xcodeproj/project.pbxproj"
        manifest = fixture / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json"
        capability = fixture / "ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift"
        originals = {path: path.read_bytes() for path in (project, manifest, capability)}
        original_write = Path.write_bytes
        failed = {"capability_update": False, "project_restore": False}

        def write_with_failures(path: Path, content: bytes, *args, **kwargs):
            if path == capability and not failed["capability_update"] and content != originals[capability]:
                failed["capability_update"] = True
                raise OSError("simulated capability write failure")
            if path == project and failed["capability_update"] and not failed["project_restore"] and content == originals[project]:
                failed["project_restore"] = True
                raise OSError("simulated project restoration failure")
            return original_write(path, content, *args, **kwargs)

        with mock.patch.object(Path, "write_bytes", new=write_with_failures):
            with self.assertRaises(OSError):
                self.release_delivery_module().prepare_release_metadata(
                    fixture, VERSION, BUILD, plugin_identity_provider=lambda _: "d" * 64
                )
        self.assertTrue(failed["capability_update"])
        self.assertTrue(failed["project_restore"])
        self.assertEqual(originals[manifest], manifest.read_bytes())
        self.assertEqual(originals[capability], capability.read_bytes())

    def test_prepare_release_metadata_preserves_crlf_bytes_on_success_and_failure(self) -> None:
        fixture = self.metadata_fixture(self.root)
        project = fixture / "ReleaseRadar.xcodeproj/project.pbxproj"
        manifest = fixture / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json"
        capability = fixture / "ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift"
        for path in (project, manifest, capability):
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))

        self.release_delivery_module().prepare_release_metadata(
            fixture, VERSION, BUILD, plugin_identity_provider=lambda _: "d" * 64
        )
        for path in (project, manifest, capability):
            self.assertNotIn(b"\n", path.read_bytes().replace(b"\r\n", b""))

        failure_fixture = self.metadata_fixture(self.root / "failure")
        failure_paths = [
            failure_fixture / "ReleaseRadar.xcodeproj/project.pbxproj",
            failure_fixture / "ReleaseRadar/CodexPluginMarketplace/plugins/release-radar/.codex-plugin/plugin.json",
            failure_fixture / "ReleaseRadarCore/CodexPlugin/CodexPluginLifecycle.swift",
        ]
        for path in failure_paths:
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        originals = {path: path.read_bytes() for path in failure_paths}
        with self.assertRaises(RuntimeError):
            self.release_delivery_module().prepare_release_metadata(
                failure_fixture, VERSION, BUILD,
                plugin_identity_provider=lambda _: (_ for _ in ()).throw(RuntimeError("digest failure")),
            )
        self.assertEqual(originals, {path: path.read_bytes() for path in failure_paths})

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
