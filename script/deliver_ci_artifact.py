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
import subprocess
import sys
from typing import BinaryIO, Iterator


SHARE = re.compile(r"^//(?:[^\s/]*@)?10\.0\.0\.3/software on (.+) \(smbfs(?:,|\))")
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


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


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: deliver_ci_artifact.py SOURCE_DIR ARCHIVE")
    result = subprocess.run(["/sbin/mount", "-t", "smbfs"], check=True, capture_output=True, text=True)
    deliver(Path(sys.argv[1]), sys.argv[2], mounted_share(result.stdout))


if __name__ == "__main__":
    main()
