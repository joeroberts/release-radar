#!/usr/bin/env python3
"""Copy one private CI archive to the owner's already-mounted SMB share."""

from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import time
from typing import BinaryIO, Iterator


# The Air reports the owner-selected 10.0.0.3 share as 10.0.0.03.
SHARE = re.compile(r"^//(?:[^\s/]*@)?10\.0\.0\.(?:3|03)/software on (.+) \(smbfs(?:,|\))")
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
RETENTION_SECONDS = 30 * 24 * 60 * 60


def mounted_share(output: str) -> Path:
    matches = [match.group(1) for line in output.splitlines() if (match := SHARE.match(line))]
    if len(matches) != 1 or not os.path.isabs(matches[0]):
        raise ValueError("the exact owner SMB share must be mounted once")
    return Path(matches[0])


@contextmanager
def open_directory(path: str | Path, parent_fd: int | None = None) -> Iterator[int]:
    fd = os.open(path, DIRECTORY_FLAGS, dir_fd=parent_fd)
    try:
        yield fd
    finally:
        os.close(fd)


def sha256_stream(stream: BinaryIO) -> str:
    digest = hashlib.sha256()
    while chunk := stream.read(1024 * 1024):
        digest.update(chunk)
    return digest.hexdigest()


def copy_exclusive(source: Path, name: str, destination_fd: int) -> None:
    with source.open("rb") as source_file:
        target_fd = os.open(
            name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600, dir_fd=destination_fd,
        )
        with os.fdopen(target_fd, "wb") as target_file:
            shutil.copyfileobj(source_file, target_file)


def read_from_directory(directory_fd: int, name: str) -> bytes:
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory_fd)
    with os.fdopen(fd, "rb") as stream:
        return stream.read()


def digest_from_directory(directory_fd: int, name: str) -> str:
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory_fd)
    with os.fdopen(fd, "rb") as stream:
        return sha256_stream(stream)


def prune_old_runs(root_fd: int, current_run: str, cutoff: float) -> int:
    """Remove only complete CI archive triads older than the cutoff."""
    root_device = os.fstat(root_fd).st_dev
    removed = 0
    for run_name in os.listdir(root_fd):
        match = re.fullmatch(r"([0-9]+)-([0-9]+)", run_name)
        if run_name == current_run or match is None:
            continue
        run_stat = os.stat(run_name, dir_fd=root_fd, follow_symlinks=False)
        if not stat.S_ISDIR(run_stat.st_mode) or run_stat.st_dev != root_device:
            continue
        with open_directory(run_name, root_fd) as run_fd:
            if os.fstat(run_fd).st_dev != root_device:
                continue
            try:
                manifest_stat = os.stat("manifest.json", dir_fd=run_fd, follow_symlinks=False)
            except FileNotFoundError:
                continue
            if (not stat.S_ISREG(manifest_stat.st_mode)
                    or manifest_stat.st_dev != root_device or manifest_stat.st_size > 16_384):
                continue
            try:
                manifest = json.loads(read_from_directory(run_fd, "manifest.json"))
            except ValueError:
                continue
            if not isinstance(manifest, dict):
                continue
            sha = manifest.get("source_revision")
            digest = manifest.get("archive_sha256")
            if (not isinstance(sha, str) or re.fullmatch(r"[0-9a-f]{40}", sha) is None
                    or not isinstance(digest, str) or re.fullmatch(r"[0-9a-f]{64}", digest) is None
                    or manifest.get("run_id") != match.group(1)
                    or manifest.get("run_attempt") != match.group(2)):
                continue
            archive = f"ReleaseRadar-ci-{sha}.zip"
            if manifest.get("archive") != archive:
                continue
            names = (archive, f"{archive}.sha256", "manifest.json")
            try:
                files = [os.stat(name, dir_fd=run_fd, follow_symlinks=False) for name in names]
            except FileNotFoundError:
                continue
            if (any(not stat.S_ISREG(item.st_mode) or item.st_dev != root_device for item in files)
                    or max(item.st_mtime for item in files) >= cutoff):
                continue
            if read_from_directory(run_fd, names[1]) != f"{digest}  {archive}\n".encode():
                continue
            for name in names:
                os.unlink(name, dir_fd=run_fd)
            removed += 1
    return removed


def deliver(source_dir: Path, archive: str, share_mount: Path) -> None:
    sha = os.environ["GITHUB_SHA"]
    run_id = os.environ["GITHUB_RUN_ID"]
    attempt = os.environ["GITHUB_RUN_ATTEMPT"]
    if (not re.fullmatch(r"[0-9a-f]{40}", sha)
            or not re.fullmatch(r"[0-9]+", run_id)
            or not re.fullmatch(r"[0-9]+", attempt)):
        raise ValueError("invalid CI source or run identity")
    if archive != f"ReleaseRadar-ci-{sha}.zip":
        raise ValueError("archive does not match the CI source revision")

    manifest_bytes = (source_dir / "manifest.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    if any((manifest.get(key) != value for key, value in {
        "source_revision": sha,
        "run_id": run_id,
        "run_attempt": attempt,
        "archive": archive,
        "version": os.environ["RR_CI_VERSION"],
        "build": os.environ["RR_CI_BUILD"],
    }.items())):
        raise ValueError("manifest does not match the CI build identity")
    digest = manifest.get("archive_sha256")
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("manifest has no valid archive digest")
    checksum_bytes = (source_dir / f"{archive}.sha256").read_bytes()
    if checksum_bytes != f"{digest}  {archive}\n".encode():
        raise ValueError("checksum sidecar does not match the manifest")
    with (source_dir / archive).open("rb") as source_archive:
        if sha256_stream(source_archive) != digest:
            raise ValueError("source archive digest does not match the manifest")

    # Open each directory relative to the verified mount, refusing symlinks.
    with open_directory(share_mount) as share_fd:
        share_device = os.fstat(share_fd).st_dev
        if share_device == os.stat(share_mount.parent).st_dev:
            raise ValueError("the owner SMB mount is no longer active")
        with open_directory("build", share_fd) as build_fd:
            if os.fstat(build_fd).st_dev != share_device:
                raise ValueError("artifact destination leaves the owner SMB share")
            try:
                os.mkdir("ReleaseRadar", 0o700, dir_fd=build_fd)
            except FileExistsError:
                pass
            with open_directory("ReleaseRadar", build_fd) as product_fd:
                if os.fstat(product_fd).st_dev != share_device:
                    raise ValueError("artifact destination leaves the owner SMB share")
                os.mkdir(f"{run_id}-{attempt}", 0o700, dir_fd=product_fd)
                with open_directory(f"{run_id}-{attempt}", product_fd) as run_fd:
                    if os.fstat(run_fd).st_dev != share_device:
                        raise ValueError("artifact destination leaves the owner SMB share")
                    for name in (archive, f"{archive}.sha256", "manifest.json"):
                        copy_exclusive(source_dir / name, name, run_fd)
                    if digest_from_directory(run_fd, archive) != digest:
                        raise ValueError("copied archive digest mismatch")
                    if read_from_directory(run_fd, f"{archive}.sha256") != checksum_bytes:
                        raise ValueError("copied checksum sidecar mismatch")
                    if read_from_directory(run_fd, "manifest.json") != manifest_bytes:
                        raise ValueError("copied provenance manifest mismatch")
                pruned = prune_old_runs(product_fd, f"{run_id}-{attempt}", time.time() - RETENTION_SECONDS)
                print(f"Retired {pruned} old SMB archive set(s).")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: deliver_ci_artifact.py SOURCE_DIR ARCHIVE")
    result = subprocess.run(["/sbin/mount", "-t", "smbfs"], check=True, capture_output=True, text=True)
    source_dir = Path(sys.argv[1])
    current_run = f"{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    expected_source = Path(os.environ["RUNNER_WORKSPACE"]) / "release-radar-internal-builds" / current_run
    if source_dir != expected_source or not source_dir.is_absolute():
        raise ValueError("private source is outside the CI build root")
    deliver(source_dir, sys.argv[2], mounted_share(result.stdout))
    with open_directory(source_dir.parent) as air_fd:
        pruned = prune_old_runs(air_fd, current_run, time.time() - RETENTION_SECONDS)
    print(f"Retired {pruned} old Air archive set(s).")


if __name__ == "__main__":
    main()
