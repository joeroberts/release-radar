#!/usr/bin/env python3
"""Classify a complete Git diff for the development-documentation workflow."""

from __future__ import annotations

import argparse
import json
import sys


SCHEMA_VERSION = 1
RUN_KEYS = (
    "run_docs_validation",
    "run_swift_docs_checker_tests",
    "run_adr_checker_tests",
    "run_routing_tests",
)


def empty_result(*, fallback_reason: str | None = None) -> dict[str, object]:
    result: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "docs": False,
        "swift_docs_checker": False,
        "adr_checker": False,
        "app": False,
        "workflow": False,
        "unknown": fallback_reason is not None,
        "fallback_reason": fallback_reason,
    }
    for key in RUN_KEYS:
        result[key] = fallback_reason is not None
    return result


def classify_path(path: str, result: dict[str, object]) -> bool:
    if path in {
        "script/classify_development_changes.py",
        "script/collect_development_changed_paths.sh",
        "script/test_classify_development_changes.py",
    } or path.startswith(".github/workflows/"):
        result["workflow"] = True
        return True
    if path in {
        "script/check_development_docs.swift",
        "script/test_check_development_docs.sh",
        "script/test_development_docs_git_integration.sh",
    }:
        result["swift_docs_checker"] = True
        return True
    if path in {
        ".agents/skills/adr-management/scripts/adr_checker.py",
        "script/test_adr_checker.py",
    } or path.startswith("script/fixtures/adr-evals/"):
        result["adr_checker"] = True
        return True
    if path.startswith("docs/") or ("/" not in path and path.endswith(".md")):
        result["docs"] = True
        return True
    if (
        path.startswith(("ReleaseRadar/", "ReleaseRadarCore/", "ReleaseRadarTests/", "ReleaseRadarUITests/"))
        or path.startswith("ReleaseRadar.xcodeproj/")
        or path.startswith("dependencies/")
        or path.startswith("script/build")
        or path in {"Package.swift", "Package.resolved"}
    ):
        result["app"] = True
        return True
    return False


def read_paths(raw: bytes) -> tuple[list[str] | None, str | None]:
    if not raw:
        return None, "empty changed-path input"
    if not raw.endswith(b"\0"):
        return None, "changed-path input was not NUL terminated"
    records = raw[:-1].split(b"\0")
    if not records or any(not record for record in records):
        return None, "changed-path input contains an empty record"
    try:
        paths = [record.decode("utf-8") for record in records]
    except UnicodeDecodeError:
        return None, "changed-path input contains invalid UTF-8"
    for path in paths:
        if path.startswith("/") or any(part == ".." for part in path.split("/")):
            return None, "changed-path input contains a non-repository-relative path"
    return paths, None


def classify(raw: bytes) -> dict[str, object]:
    paths, failure = read_paths(raw)
    if failure is not None:
        return empty_result(fallback_reason=failure)

    result = empty_result()
    assert paths is not None
    for path in paths:
        if not classify_path(path, result):
            return empty_result(fallback_reason=f"unclassified changed path: {path}")

    result["run_docs_validation"] = bool(
        result["docs"] or result["swift_docs_checker"] or result["adr_checker"]
    )
    result["run_swift_docs_checker_tests"] = bool(result["swift_docs_checker"])
    result["run_adr_checker_tests"] = bool(result["adr_checker"])
    result["run_routing_tests"] = bool(result["workflow"])
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changed-paths-stdin", action="store_true", required=True)
    parser.parse_args()
    print(json.dumps(classify(sys.stdin.buffer.read()), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
