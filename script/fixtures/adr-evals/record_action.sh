#!/bin/sh
set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: record_action.sh ABSOLUTE_NEW_OUTPUT ACTION [ARG ...]" >&2
  exit 64
fi

python3 - "$@" <<'PY'
import os
import stat
import sys


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(64)


output_path = sys.argv[1]
if not os.path.isabs(output_path):
    fail("recorder output must be an absolute path")

parent, leaf = os.path.split(output_path)
if not leaf or leaf in {".", ".."}:
    fail("recorder output must name a new file")

directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC
directory_flags |= getattr(os, "O_NOFOLLOW", 0)
try:
    directory_fd = os.open(parent, directory_flags)
except OSError as error:
    fail(f"recorder directory is unavailable: {error}")

try:
    details = os.fstat(directory_fd)
    if details.st_uid != os.geteuid() or stat.S_IMODE(details.st_mode) != 0o700:
        fail("recorder directory must be owner-only and owned by the current user")

    output_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC
    output_flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        output_fd = os.open(leaf, output_flags, 0o600, dir_fd=directory_fd)
    except OSError as error:
        fail(f"recorder output must not already exist: {error}")
    try:
        payload = (" ".join(sys.argv[2:]) + "\n").encode("utf-8")
        while payload:
            written = os.write(output_fd, payload)
            if written <= 0:
                fail("recorder output write failed")
            payload = payload[written:]
    finally:
        os.close(output_fd)
finally:
    os.close(directory_fd)
PY
