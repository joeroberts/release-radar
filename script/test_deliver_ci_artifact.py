#!/usr/bin/env python3
"""QA fixtures for private CI artifact delivery without an SMB write."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from script import deliver_ci_artifact as delivery


SHA = "a" * 40
ARCHIVE = f"ReleaseRadar-ci-{SHA}.zip"
RUN_ID = "42"
ATTEMPT = "3"


class MountedShareTests(unittest.TestCase):
    def test_selects_only_the_exact_owner_smb_share(self) -> None:
        output = (
            "//someone@10.0.0.4/software on /Volumes/other (smbfs, nodev)\n"
            "//owner@10.0.0.3/software on /Volumes/software (smbfs, nodev)\n"
        )
        self.assertEqual(Path("/Volumes/software"), delivery.mounted_share(output))

    def test_absent_wrong_or_ambiguous_mount_fails_closed(self) -> None:
        for output in (
            "",
            "//owner@10.0.0.4/software on /Volumes/software (smbfs)\n",
            "//owner@10.0.0.3/other on /Volumes/software (smbfs)\n",
            "//owner@10.0.0.3/software on /Volumes/software (apfs)\n",
            "//owner@10.0.0.3/software on relative/path (smbfs)\n",
            "//owner@10.0.0.3/software on /Volumes/software (smbfs)\n"
            "//other@10.0.0.3/software on /Volumes/software-2 (smbfs)\n",
        ):
            with self.subTest(output=output), self.assertRaises(ValueError):
                delivery.mounted_share(output)


class ArtifactDeliveryTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="rr-ci-delivery-qa-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.source = root / "private-source"
        self.source.mkdir()
        self.mount = root / "mock-share"
        (self.mount / "build").mkdir(parents=True)
        with zipfile.ZipFile(self.source / ARCHIVE, "w") as archive:
            archive.writestr("ReleaseRadar.app/Contents/Info.plist", "fixture")
        self.archive_bytes = (self.source / ARCHIVE).read_bytes()
        self.digest = hashlib.sha256(self.archive_bytes).hexdigest()
        self.manifest = {
            "source_revision": SHA,
            "run_id": RUN_ID,
            "run_attempt": ATTEMPT,
            "archive": ARCHIVE,
            "archive_sha256": self.digest,
            "version": "1.2.3",
            "build": "45",
            "architecture": "arm64",
            "xcode": "Xcode 27.0",
        }
        (self.source / "manifest.json").write_text(json.dumps(self.manifest) + "\n")
        (self.source / f"{ARCHIVE}.sha256").write_text(f"{self.digest}  {ARCHIVE}\n")
        environment = patch.dict(os.environ, {
            "GITHUB_SHA": SHA,
            "GITHUB_RUN_ID": RUN_ID,
            "GITHUB_RUN_ATTEMPT": ATTEMPT,
            "RR_CI_VERSION": "1.2.3",
            "RR_CI_BUILD": "45",
        })
        environment.start()
        self.addCleanup(environment.stop)

    def deliver_on_mock_mount(self) -> None:
        # Fixture directories share a device; model the separately mounted SMB volume.
        parent_device = os.stat(self.mount.parent).st_dev
        with patch.object(delivery.os, "fstat", return_value=SimpleNamespace(st_dev=parent_device + 1)):
            delivery.deliver(self.source, ARCHIVE, self.mount)

    def test_copied_zip_checksum_and_manifest_retain_integrity_and_provenance(self) -> None:
        self.deliver_on_mock_mount()
        destination = self.mount / "build" / "ReleaseRadar" / f"{RUN_ID}-{ATTEMPT}"
        self.assertEqual(self.archive_bytes, (destination / ARCHIVE).read_bytes())
        self.assertEqual(self.digest, hashlib.sha256((destination / ARCHIVE).read_bytes()).hexdigest())
        self.assertEqual((self.source / f"{ARCHIVE}.sha256").read_bytes(),
                         (destination / f"{ARCHIVE}.sha256").read_bytes())
        self.assertEqual((self.source / "manifest.json").read_bytes(),
                         (destination / "manifest.json").read_bytes())
        self.assertEqual(self.manifest, json.loads((destination / "manifest.json").read_text()))

    def test_existing_run_destination_is_not_overwritten(self) -> None:
        self.deliver_on_mock_mount()
        destination = self.mount / "build" / "ReleaseRadar" / f"{RUN_ID}-{ATTEMPT}"
        original = {path.name: path.read_bytes() for path in destination.iterdir()}
        with self.assertRaises(FileExistsError):
            self.deliver_on_mock_mount()
        self.assertEqual(original, {path.name: path.read_bytes() for path in destination.iterdir()})

    def test_unmounted_path_and_invalid_source_identity_fail_before_copy(self) -> None:
        with self.assertRaisesRegex(ValueError, "no longer active"):
            delivery.deliver(self.source, ARCHIVE, self.mount)
        self.assertFalse((self.mount / "build" / "ReleaseRadar").exists())

        self.manifest["source_revision"] = "b" * 40
        (self.source / "manifest.json").write_text(json.dumps(self.manifest) + "\n")
        with self.assertRaisesRegex(ValueError, "CI build identity"):
            self.deliver_on_mock_mount()
        self.assertFalse((self.mount / "build" / "ReleaseRadar").exists())

    def test_source_digest_mismatch_fails_before_copy(self) -> None:
        with (self.source / ARCHIVE).open("ab") as archive:
            archive.write(b"corrupt")
        with self.assertRaisesRegex(ValueError, "source archive digest"):
            self.deliver_on_mock_mount()
        self.assertFalse((self.mount / "build" / "ReleaseRadar").exists())

    def test_post_copy_corruption_is_detected(self) -> None:
        original_copy = delivery.copy_exclusive

        def corrupt_copy(source: Path, name: str, destination_fd: int) -> None:
            original_copy(source, name, destination_fd)
            if name == ARCHIVE:
                fd = os.open(name, os.O_WRONLY, dir_fd=destination_fd)
                with os.fdopen(fd, "wb") as destination:
                    destination.write(b"corrupt")

        with patch.object(delivery, "copy_exclusive", side_effect=corrupt_copy):
            with self.assertRaisesRegex(ValueError, "copied archive digest"):
                self.deliver_on_mock_mount()


if __name__ == "__main__":
    unittest.main(verbosity=2)
