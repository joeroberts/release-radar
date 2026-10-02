#!/usr/bin/env python3
"""Validate Release Radar Wiki ADR snapshots, transitions, and exceptions."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import unicodedata
from typing import Any


SCHEMA_VERSION = 1
CANONICAL_WIKI = "https://github.com/joeroberts/release-radar.wiki.git"
DEVELOPMENT_REPOSITORY = "https://github.com/joeroberts/release-radar"
ACCEPTED_CONTRACT_REVISION = "38cc05e4300df71faa16dfcdd234fe0f8cd46124"
ACCEPTED_CONTRACTS = {
    "adr-lifecycle": (
        "Contract-ADR-Lifecycle-and-Integrity.md",
        "2a0df264aa8a550476dcdb6981bd390210a0e54c",
    ),
    "development-exception": (
        "Scoped-Development-Exceptions-Contract.md",
        "d9c16ee8f4036b6b0876b4d2946d2072f635478f",
    ),
}
CATALOG_PATH = "ADR-Catalog.json"
INDEX_PATH = "Architecture-Decisions.md"
INDEX_INTRODUCTION = (
    "Architecture decisions do not authorize work. Accepted status does not by "
    "itself establish current applicability, and historical records do not override "
    "current instructions."
)
STATUSES = {"Proposed", "Accepted", "Rejected", "Superseded"}
APPLICABILITIES = {"current", "historical", "proposed", "unresolved"}
DOMAINS = {"product", "development"}
ELIGIBLE_FAILURES = {
    "ADR_SNAPSHOT_STALE",
    "ADR_FRESHNESS_UNAVAILABLE",
    "ADR_MISSING",
    "ADR_BLOB_MISMATCH",
    "ADR_UNCATALOGUED",
}
TRANSITION_ACTIONS = {
    "add", "remove", "path", "baseline", "status", "domain", "scopes",
    "proposed-body",
}
ADR_FILENAME = re.compile(r"^(ADR-([0-9]{3,})-[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*)\.md$")
ADR_ID = re.compile(r"^ADR-([0-9]{3,})$")
SCOPE_KEY = re.compile(r"^[a-z0-9][a-z0-9.-]*$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
URL = re.compile(r"^https://[^\s]+$")
RFC3339_UTC = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z$")
OPEN_MARKER = b"<!-- adr-metadata:v1 -->"
CLOSE_MARKER = b"<!-- /adr-metadata:v1 -->"
METADATA_KEYS = (
    "ID", "Status", "Date", "Date meaning", "Implementation",
    "Approval qualification",
)
MAX_ADRS = 1_000
MAX_ADR_BYTES = 256 * 1024
MAX_JSON_BYTES = 1024 * 1024
MAX_INDEX_BYTES = 1024 * 1024
MAX_COMBINED_ADR_BYTES = 16 * 1024 * 1024
MAX_EXCEPTION_BYTES = 64 * 1024


class UsageError(Exception):
    pass


class StrictJSONError(ValueError):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise UsageError(message)


@dataclass(frozen=True)
class TreeEntry:
    mode: str
    kind: str
    oid: str
    path: str


@dataclass
class SnapshotData:
    revision: str
    tree: dict[str, TreeEntry]
    catalog: dict[str, Any] | None
    records: dict[str, dict[str, Any]]
    selected_ids: list[str]
    diagnostics: list[dict[str, Any]]
    object_format: str | None


def diagnostic(code: str, message: str, **values: Any) -> dict[str, Any]:
    item: dict[str, Any] = {"code": code, "message": message}
    for key, value in values.items():
        if value is not None:
            item[key] = value
    return item


def result(
    status: str,
    ticket: str,
    operation: str,
    wiki_repository: str,
    revision: str | None,
    selected_ids: list[str],
    scopes: list[str],
    diagnostics: list[dict[str, Any]],
    exception: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "status": status,
        "ticket": ticket,
        "operation": operation,
        "wikiRepository": wiki_repository,
        "readRevision": revision,
        "selectedIds": selected_ids,
        "scopes": scopes,
        "diagnostics": diagnostics,
        "exception": exception,
    }


def emit(value: dict[str, Any]) -> int:
    sys.stdout.write(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")
    return 0 if value["status"] in {"verified", "proceeding_under_exception"} else 2


def run_git(repository: Path | None, *arguments: str) -> subprocess.CompletedProcess[bytes]:
    command = ["git"]
    if repository is not None:
        command += ["-C", str(repository)]
    command += list(arguments)
    environment = os.environ.copy()
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    return subprocess.run(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        env=environment,
    )


def git_bytes(repository: Path, *arguments: str) -> bytes:
    completed = run_git(repository, *arguments)
    if completed.returncode != 0:
        raise ValueError(completed.stderr.decode("utf-8", errors="replace").strip() or "Git read failed")
    return completed.stdout


def object_id_pattern(object_format: str) -> re.Pattern[str]:
    return re.compile(r"^[0-9a-f]{40}$" if object_format == "sha1" else r"^[0-9a-f]{64}$")


def git_blob_id(raw: bytes, object_format: str) -> str:
    framed = f"blob {len(raw)}\0".encode("ascii") + raw
    if object_format == "sha1":
        return hashlib.sha1(framed).hexdigest()
    if object_format == "sha256":
        return hashlib.sha256(framed).hexdigest()
    raise ValueError("unsupported Git object format")


def verify_repository_identity(repository: Path, wiki_repository: str) -> list[dict[str, Any]]:
    diagnostics: list[dict[str, Any]] = []
    if wiki_repository != CANONICAL_WIKI:
        diagnostics.append(diagnostic(
            "ADR_SOURCE_UNSAFE", "Wiki identity is not the canonical repository.",
            expected=CANONICAL_WIKI, actual=wiki_repository,
        ))
        return diagnostics
    try:
        origin = git_bytes(repository, "config", "--get", "remote.origin.url").decode("utf-8").strip()
    except (ValueError, UnicodeDecodeError):
        origin = ""
    if origin != wiki_repository:
        diagnostics.append(diagnostic(
            "ADR_SOURCE_UNSAFE", "Git origin does not match the canonical Wiki identity.",
            expected=wiki_repository, actual=origin or "absent",
        ))
    return diagnostics


def remote_head(wiki_repository: str) -> tuple[str | None, dict[str, Any] | None]:
    completed = run_git(None, "ls-remote", "--symref", wiki_repository, "HEAD")
    if completed.returncode != 0:
        return None, diagnostic(
            "ADR_FRESHNESS_UNAVAILABLE", "Canonical Wiki HEAD could not be resolved.",
            expected=wiki_repository,
        )
    try:
        output = completed.stdout.decode("utf-8")
    except UnicodeDecodeError:
        return None, diagnostic("ADR_FRESHNESS_UNAVAILABLE", "Canonical Wiki HEAD response was not UTF-8.")
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) == 2 and fields[1] == "HEAD" and re.fullmatch(r"[0-9a-f]{40,64}", fields[0]):
            return fields[0], None
    return None, diagnostic("ADR_FRESHNESS_UNAVAILABLE", "Canonical Wiki HEAD response was incomplete.")


def parse_tree(repository: Path, revision: str) -> dict[str, TreeEntry]:
    object_type = git_bytes(repository, "cat-file", "-t", revision).decode("ascii").strip()
    if object_type != "commit":
        raise ValueError(f"revision is not a commit: {revision}")
    raw = git_bytes(repository, "ls-tree", "-z", revision)
    entries: dict[str, TreeEntry] = {}
    for record in raw.split(b"\0"):
        if not record:
            continue
        header, raw_path = record.split(b"\t", 1)
        mode, kind, oid = header.decode("ascii").split(" ")
        path = raw_path.decode("utf-8")
        if path in entries:
            raise ValueError(f"duplicate tree path: {path}")
        entries[path] = TreeEntry(mode, kind, oid, path)
    return entries


def read_blob(repository: Path, revision: str, path: str, limit: int | None = None) -> bytes:
    size_raw = git_bytes(repository, "cat-file", "-s", f"{revision}:{path}")
    try:
        size = int(size_raw.decode("ascii").strip())
    except (UnicodeDecodeError, ValueError) as error:
        raise ValueError(f"{path} has an invalid Git object size") from error
    if limit is not None and size > limit:
        raise OverflowError(f"{path} exceeds {limit} bytes")
    raw = git_bytes(repository, "cat-file", "blob", f"{revision}:{path}")
    if len(raw) != size:
        raise ValueError(f"{path} size changed during its pinned read")
    return raw


def strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise StrictJSONError(f"duplicate JSON field: {key}")
        value[key] = item
    return value


def strict_json_bytes(raw: bytes, maximum: int) -> Any:
    if len(raw) > maximum:
        raise StrictJSONError("JSON input exceeds its size limit")
    if raw.startswith(b"\xef\xbb\xbf"):
        raise StrictJSONError("JSON input has a BOM")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise StrictJSONError("JSON input is not UTF-8") from error
    try:
        return json.loads(text, object_pairs_hook=strict_pairs)
    except (json.JSONDecodeError, StrictJSONError) as error:
        raise StrictJSONError(str(error)) from error


def strict_json_file(path: Path, maximum: int = MAX_JSON_BYTES) -> Any:
    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
        descriptor = os.open(path, flags)
        try:
            details = os.fstat(descriptor)
            if not stat.S_ISREG(details.st_mode) or details.st_size > maximum:
                raise StrictJSONError("JSON input is not a bounded regular file")
            chunks: list[bytes] = []
            remaining = maximum + 1
            while remaining:
                chunk = os.read(descriptor, min(65536, remaining))
                if not chunk:
                    break
                chunks.append(chunk)
                remaining -= len(chunk)
            raw = b"".join(chunks)
            if len(raw) > maximum or len(raw) != details.st_size:
                raise StrictJSONError("JSON input changed or exceeds its size limit")
        finally:
            os.close(descriptor)
        return strict_json_bytes(raw, maximum)
    except OSError as error:
        raise StrictJSONError(f"cannot read {path}: {error}") from error


def exact_fields(value: Any, fields: set[str]) -> bool:
    return type(value) is dict and set(value) == fields


def nonempty_string(value: Any, maximum: int | None = None) -> bool:
    if type(value) is not str or not value or "\x00" in value:
        return False
    return maximum is None or len(value.encode("utf-8")) <= maximum


def render_index(catalog: dict[str, Any]) -> bytes:
    rows = [
        INDEX_INTRODUCTION,
        "",
        "| ADR | Decision status |",
        "| --- | --- |",
    ]
    for record in sorted(catalog["records"], key=lambda item: int(item["id"].split("-")[1])):
        label = record["title"]
        for character in ("\\", "|", "[", "]", "(", ")"):
            label = label.replace(character, "\\" + character)
        rows.append(f"| [{label}]({record['path'][:-3]}) | {record['status']} |")
    return ("\n".join(rows) + "\n").encode("utf-8")


def parse_metadata(raw: bytes, path: str) -> tuple[dict[str, str], bytes]:
    if len(raw) > MAX_ADR_BYTES:
        raise ValueError("ADR exceeds 256 KiB")
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ValueError("ADR has a BOM")
    try:
        raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ValueError("ADR is not UTF-8") from error
    close_line = CLOSE_MARKER + b"\n"
    if not raw.startswith(OPEN_MARKER + b"\n"):
        raise ValueError("metadata does not start at byte zero")
    if raw.count(OPEN_MARKER) != 1 or raw.count(CLOSE_MARKER) != 1:
        raise ValueError("ADR must contain exactly one metadata block")
    close_end = raw.find(close_line)
    if close_end < 0:
        raise ValueError("metadata closing marker is not LF terminated")
    close_end += len(close_line)
    header_lines = raw[:close_end].split(b"\n")
    expected_line_count = len(METADATA_KEYS) + 3
    if len(header_lines) != expected_line_count:
        raise ValueError("metadata fields are not in the exact v1 shape")
    if header_lines[0] != OPEN_MARKER or header_lines[-2] != CLOSE_MARKER or header_lines[-1] != b"":
        raise ValueError("metadata marker shape is invalid")
    values: dict[str, str] = {}
    for index, key in enumerate(METADATA_KEYS, start=1):
        prefix = f"- {key}: ".encode("utf-8")
        line = header_lines[index]
        if not line.startswith(prefix) or len(line) == len(prefix):
            raise ValueError(f"metadata field {key} is missing, empty, or out of order")
        values[key] = line[len(prefix):].decode("utf-8")
    body = raw[close_end:]
    if not body.startswith(b"\n"):
        raise ValueError("metadata block must be followed by one blank line")
    if b"\n# " in body or body.startswith(b"# "):
        raise ValueError("ADR body contains a duplicate H1")
    match = ADR_FILENAME.fullmatch(path)
    if match is None or values["ID"] != path.split("-", 2)[0] + "-" + path.split("-", 2)[1]:
        raise ValueError("metadata ID does not match filename")
    if values["Status"] not in STATUSES:
        raise ValueError("metadata Status is invalid")
    return values, body


def validate_catalog(catalog: Any, object_format: str) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]]]:
    diagnostics: list[dict[str, Any]] = []
    records_by_id: dict[str, dict[str, Any]] = {}
    if not exact_fields(catalog, {"version", "wikiRepository", "objectFormat", "records"}):
        return records_by_id, [diagnostic("ADR_FORMAT_INVALID", "Catalog fields are invalid.", path=CATALOG_PATH)]
    if type(catalog["version"]) is not int or catalog["version"] != 1:
        diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Catalog version must be integer 1.", path=CATALOG_PATH))
    if type(catalog["wikiRepository"]) is not str or catalog["wikiRepository"] != CANONICAL_WIKI:
        diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", "Catalog Wiki identity is not canonical.", path=CATALOG_PATH, expected=CANONICAL_WIKI, actual=catalog["wikiRepository"]))
    if type(catalog["objectFormat"]) is not str or catalog["objectFormat"] not in {"sha1", "sha256"} or catalog["objectFormat"] != object_format:
        diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Catalog object format does not match Git.", path=CATALOG_PATH, expected=object_format, actual=catalog["objectFormat"]))
    if type(catalog["records"]) is not list or len(catalog["records"]) > MAX_ADRS:
        diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Catalog records must be an array within the record limit.", path=CATALOG_PATH))
        return records_by_id, diagnostics
    oid_pattern = object_id_pattern(object_format)
    numeric_ids: set[int] = set()
    paths: set[str] = set()
    normalized_paths: set[str] = set()
    previous_number = -1
    for record in catalog["records"]:
        if not exact_fields(record, {"id", "path", "title", "status", "domain", "scopes", "blob", "baseline", "evidence"}):
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Catalog record fields are invalid.", path=CATALOG_PATH))
            continue
        adr_match = ADR_ID.fullmatch(record["id"]) if type(record["id"]) is str else None
        filename_match = ADR_FILENAME.fullmatch(record["path"]) if type(record["path"]) is str else None
        if adr_match is None or filename_match is None or filename_match.group(1).split("-", 2)[:2] != record["id"].split("-", 1):
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Catalog ID or path is invalid.", path=str(record.get("path", CATALOG_PATH))))
            continue
        number = int(adr_match.group(1))
        if number in numeric_ids or number <= previous_number:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR numeric identities are duplicated or unsorted.", id=record["id"], path=record["path"]))
        numeric_ids.add(number)
        previous_number = number
        normalized = unicodedata.normalize("NFC", record["path"]).casefold()
        if record["path"] in paths or normalized in normalized_paths:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR paths collide.", id=record["id"], path=record["path"]))
        paths.add(record["path"])
        normalized_paths.add(normalized)
        if len(record["path"].encode("ascii")) > 255 or not nonempty_string(record["title"], 255) or "\n" in record["title"]:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR path or title exceeds its format limit.", id=record["id"], path=record["path"]))
        status = record["status"] if type(record["status"]) is str else ""
        domain = record["domain"] if type(record["domain"]) is str else ""
        if status not in STATUSES or domain not in DOMAINS:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR status or domain is invalid.", id=record["id"], path=record["path"]))
        if type(record["scopes"]) is not list or not record["scopes"] or len(record["scopes"]) > 100:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR scopes are invalid.", id=record["id"], path=record["path"]))
        else:
            seen_scopes: set[str] = set()
            for scope in record["scopes"]:
                if not exact_fields(scope, {"key", "applicability"}) or not nonempty_string(scope.get("key"), 128) or SCOPE_KEY.fullmatch(scope["key"]) is None or type(scope["applicability"]) is not str or scope["applicability"] not in APPLICABILITIES or scope["key"] in seen_scopes:
                    diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR scope entry is invalid.", id=record["id"], path=record["path"]))
                    continue
                seen_scopes.add(scope["key"])
                expected_applicabilities = (
                    {"proposed"} if status == "Proposed" else
                    {"historical"} if status in {"Rejected", "Superseded"} else
                    {"current", "historical", "unresolved"}
                )
                if scope["applicability"] not in expected_applicabilities:
                    diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Scope applicability disagrees with decision status.", id=record["id"], path=record["path"]))
        if type(record["blob"]) is not str or oid_pattern.fullmatch(record["blob"]) is None:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Current blob ID is invalid.", id=record["id"], path=record["path"]))
        baseline = record["baseline"]
        requires_baseline = status in {"Accepted", "Superseded"}
        if baseline is None:
            if requires_baseline:
                diagnostics.append(diagnostic("ADR_BASELINE_UNAVAILABLE", "Accepted decision has no fixed baseline.", id=record["id"], path=record["path"]))
        elif not exact_fields(baseline, {"commit", "path", "blob", "bodySha256"}) or type(baseline.get("commit")) is not str or oid_pattern.fullmatch(baseline["commit"]) is None or type(baseline.get("path")) is not str or ADR_FILENAME.fullmatch(baseline["path"]) is None or baseline["path"].split("-", 2)[:2] != record["id"].split("-", 1) or type(baseline.get("blob")) is not str or oid_pattern.fullmatch(baseline["blob"]) is None or type(baseline.get("bodySha256")) is not str or SHA256.fullmatch(baseline["bodySha256"]) is None:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Accepted baseline is malformed.", id=record["id"], path=record["path"]))
        elif not requires_baseline:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Never-accepted decision must have a null baseline.", id=record["id"], path=record["path"]))
        if type(record["evidence"]) is not list or not record["evidence"] or any(not nonempty_string(item, 2048) or URL.fullmatch(item) is None for item in record["evidence"]):
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Evidence URLs are invalid.", id=record["id"], path=record["path"]))
        records_by_id[record["id"]] = record
    return records_by_id, diagnostics


def validate_snapshot_content(
    repository: Path,
    revision: str,
    scopes: list[str],
    requested_ids: list[str],
) -> SnapshotData:
    diagnostics: list[dict[str, Any]] = []
    try:
        object_format = git_bytes(repository, "rev-parse", "--show-object-format").decode("ascii").strip()
        if object_format not in {"sha1", "sha256"}:
            raise ValueError("unsupported Git object format")
        if object_id_pattern(object_format).fullmatch(revision) is None:
            raise ValueError("revision is not a full object ID")
        tree = parse_tree(repository, revision)
    except (ValueError, UnicodeDecodeError) as error:
        diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", f"Pinned Git tree could not be read safely: {error}"))
        return SnapshotData(revision, {}, None, {}, sorted(set(requested_ids)), diagnostics, None)

    candidate_entries: dict[str, TreeEntry] = {}
    numeric_paths: dict[int, str] = {}
    normalized_paths: dict[str, str] = {}
    for path, entry in tree.items():
        normalized = unicodedata.normalize("NFC", path).casefold()
        if not (normalized.startswith("adr-") and normalized.endswith(".md")):
            continue
        candidate_entries[path] = entry
        match = ADR_FILENAME.fullmatch(path)
        if match is None:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Root ADR candidate has an invalid filename.", path=path))
            continue
        number = int(match.group(2))
        if number in numeric_paths:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Root ADR candidates share one numeric identity.", path=path, expected=numeric_paths[number]))
        numeric_paths[number] = path
        if normalized in normalized_paths:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Root ADR candidate paths collide after normalization.", path=path, expected=normalized_paths[normalized]))
        normalized_paths[normalized] = path
        if entry.mode != "100644" or entry.kind != "blob":
            diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", "ADR candidate is not a non-executable regular blob.", path=path, expected="100644 blob", actual=f"{entry.mode} {entry.kind}"))
    if len(candidate_entries) > MAX_ADRS:
        diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR inventory exceeds 1,000 records."))

    catalog: dict[str, Any] | None = None
    records: dict[str, dict[str, Any]] = {}
    catalog_entry = tree.get(CATALOG_PATH)
    if catalog_entry is None:
        diagnostics.append(diagnostic("ADR_MISSING", "ADR catalog is absent.", path=CATALOG_PATH))
    elif catalog_entry.mode != "100644" or catalog_entry.kind != "blob":
        diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", "ADR catalog is not a non-executable regular blob.", path=CATALOG_PATH))
    else:
        try:
            catalog_raw = read_blob(repository, revision, CATALOG_PATH, MAX_JSON_BYTES)
            parsed = strict_json_bytes(catalog_raw, MAX_JSON_BYTES)
            if type(parsed) is not dict:
                raise StrictJSONError("catalog root is not an object")
            records, catalog_diagnostics = validate_catalog(parsed, object_format)
            diagnostics.extend(catalog_diagnostics)
            if catalog_diagnostics:
                records = {}
                catalog = None
            else:
                catalog = parsed
        except (ValueError, OverflowError, StrictJSONError) as error:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", f"ADR catalog is invalid: {error}", path=CATALOG_PATH))

    catalog_paths = {record["path"] for record in records.values() if type(record.get("path")) is str}
    inventory_paths = set(candidate_entries)
    for path in sorted(catalog_paths - inventory_paths):
        record = next((item for item in records.values() if item.get("path") == path), None)
        diagnostics.append(diagnostic("ADR_MISSING", "Catalogued ADR is missing from the pinned tree.", id=record.get("id") if record else None, path=path, expected=record.get("blob") if record else None))
    for path in sorted(inventory_paths - catalog_paths):
        entry = candidate_entries[path]
        diagnostics.append(diagnostic("ADR_UNCATALOGUED", "Pinned tree contains an uncatalogued ADR candidate.", path=path, actual=entry.oid if entry.kind == "blob" else None))

    combined_size = 0
    for adr_id, record in records.items():
        path = record.get("path")
        baseline = record.get("baseline")
        baseline_metadata: dict[str, str] | None = None
        baseline_body: bytes | None = None
        if baseline is not None and exact_fields(baseline, {"commit", "path", "blob", "bodySha256"}):
            try:
                baseline_tree = parse_tree(repository, baseline["commit"])
                baseline_entry = baseline_tree.get(baseline["path"])
                if baseline_entry is None or baseline_entry.mode != "100644" or baseline_entry.kind != "blob" or baseline_entry.oid != baseline["blob"]:
                    raise ValueError("baseline path/blob is unavailable")
                baseline_raw = read_blob(repository, baseline["commit"], baseline["path"], MAX_ADR_BYTES)
                baseline_metadata, baseline_body = parse_metadata(baseline_raw, baseline["path"])
                if baseline_metadata["ID"] != adr_id or baseline_metadata["Status"] not in {"Proposed", "Accepted"}:
                    raise ValueError("baseline identity or source status is invalid")
                actual_body_hash = hashlib.sha256(baseline_body).hexdigest()
                if actual_body_hash != baseline["bodySha256"]:
                    raise ValueError("baseline body hash is inconsistent")
            except (ValueError, OverflowError) as error:
                diagnostics.append(diagnostic(
                    "ADR_BASELINE_UNAVAILABLE",
                    f"Fixed accepted baseline cannot be resolved: {error}",
                    id=adr_id, path=path, expected=baseline.get("blob"),
                ))
                baseline_metadata = None
                baseline_body = None
        entry = tree.get(path) if type(path) is str else None
        if entry is None or entry.kind != "blob" or entry.mode != "100644":
            continue
        try:
            raw = read_blob(repository, revision, path, MAX_ADR_BYTES)
            combined_size += len(raw)
            metadata, body = parse_metadata(raw, path)
        except (ValueError, OverflowError) as error:
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", f"ADR document is invalid: {error}", id=adr_id, path=path))
            continue
        if entry.oid != record.get("blob"):
            diagnostics.append(diagnostic("ADR_BLOB_MISMATCH", "Catalog blob does not match the pinned ADR blob.", id=adr_id, path=path, expected=record.get("blob"), actual=entry.oid))
        if metadata["ID"] != adr_id or metadata["Status"] != record.get("status"):
            diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "ADR metadata disagrees with the catalog.", id=adr_id, path=path))
        if baseline_metadata is not None and baseline_body is not None:
            immutable_keys = ("ID", "Date", "Date meaning", "Implementation", "Approval qualification")
            immutable_changed = any(metadata[key] != baseline_metadata[key] for key in immutable_keys)
            if body != baseline_body or immutable_changed:
                diagnostics.append(diagnostic("ADR_BODY_CHANGED", "Accepted protected bytes or immutable metadata changed.", id=adr_id, path=path, expected=baseline["bodySha256"], actual=hashlib.sha256(body).hexdigest()))
    if combined_size > MAX_COMBINED_ADR_BYTES:
        diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Combined ADR content exceeds 16 MiB."))

    if catalog is not None:
        expected_index = render_index(catalog)
        index_entry = tree.get(INDEX_PATH)
        if index_entry is None:
            diagnostics.append(diagnostic("ADR_INDEX_MISMATCH", "Derived ADR index is absent.", path=INDEX_PATH))
        elif index_entry.mode != "100644" or index_entry.kind != "blob":
            diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", "Derived ADR index is not a non-executable regular blob.", path=INDEX_PATH))
        else:
            try:
                actual_index = read_blob(repository, revision, INDEX_PATH, MAX_INDEX_BYTES)
                if actual_index != expected_index:
                    diagnostics.append(diagnostic("ADR_INDEX_MISMATCH", "Derived ADR index does not match the catalog.", path=INDEX_PATH, expected=hashlib.sha256(expected_index).hexdigest(), actual=hashlib.sha256(actual_index).hexdigest()))
            except OverflowError:
                diagnostics.append(diagnostic("ADR_FORMAT_INVALID", "Derived ADR index exceeds 1 MiB.", path=INDEX_PATH))

    if requested_ids:
        selected_ids = sorted(set(requested_ids), key=lambda value: int(value.split("-")[1]) if ADR_ID.fullmatch(value) else 10**18)
        for adr_id in selected_ids:
            if adr_id not in records:
                diagnostics.append(diagnostic("ADR_MISSING", "Selected ADR is absent from the catalog.", id=adr_id))
                continue
            selected_scopes = records[adr_id].get("scopes", [])
            if not any(scope.get("key") in scopes for scope in selected_scopes):
                diagnostics.append(diagnostic(
                    "ADR_SCOPE_UNRESOLVED",
                    "Selected ADR does not cover any requested decision scope.",
                    id=adr_id,
                ))
    else:
        selected_ids = sorted(
            [adr_id for adr_id, record in records.items() if any(scope.get("key") in scopes for scope in record.get("scopes", []))],
            key=lambda value: int(value.split("-")[1]),
        )
    for scope_key in scopes:
        matching = [scope for record in records.values() for scope in record.get("scopes", []) if scope.get("key") == scope_key]
        if not matching or any(scope.get("applicability") == "unresolved" for scope in matching):
            diagnostics.append(diagnostic("ADR_SCOPE_UNRESOLVED", "Requested decision scope has missing or unresolved coverage.", scope=scope_key))

    return SnapshotData(revision, tree, catalog, records, selected_ids, diagnostics, object_format)


def add_freshness(
    repository: Path,
    wiki_repository: str,
    expected_revision: str,
    diagnostics: list[dict[str, Any]],
) -> None:
    diagnostics.extend(verify_repository_identity(repository, wiki_repository))
    head, freshness_error = remote_head(wiki_repository)
    if freshness_error is not None:
        diagnostics.append(freshness_error)
    elif head != expected_revision:
        diagnostics.append(diagnostic("ADR_SNAPSHOT_STALE", "Pinned revision is not current canonical Wiki HEAD.", expected=head, actual=expected_revision))


def snapshot_command(arguments: argparse.Namespace) -> int:
    repository = Path(arguments.repository).resolve()
    data = validate_snapshot_content(repository, arguments.revision, arguments.scope, arguments.id)
    add_freshness(repository, arguments.wiki_repository, arguments.revision, data.diagnostics)
    value = result(
        "blocked" if data.diagnostics else "verified", arguments.ticket,
        arguments.operation, arguments.wiki_repository, arguments.revision,
        data.selected_ids, arguments.scope, data.diagnostics,
    )
    return emit(value)


def authorization_data(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        value = strict_json_file(path)
    except StrictJSONError as error:
        return None, str(error)
    fields = {"version", "ticket", "operation", "priorRevision", "candidateRevision", "changes", "approvalRef"}
    if not exact_fields(value, fields) or value["version"] != 1 or type(value["changes"]) is not list or not nonempty_string(value["ticket"], 2048) or not nonempty_string(value["operation"], 128) or not nonempty_string(value["approvalRef"], 4096):
        return None, "authorization object is malformed"
    seen: set[str] = set()
    for change in value["changes"]:
        if not exact_fields(change, {"id", "actions"}) or type(change["id"]) is not str or ADR_ID.fullmatch(change["id"]) is None or type(change["actions"]) is not list or any(type(action) is not str or action not in TRANSITION_ACTIONS for action in change["actions"]) or len(set(change["actions"])) != len(change["actions"]) or change["id"] in seen:
            return None, "authorization changes are malformed"
        seen.add(change["id"])
    return value, None


def actual_transition_actions(
    repository: Path,
    prior: SnapshotData,
    candidate: SnapshotData,
) -> dict[str, set[str]]:
    actions: dict[str, set[str]] = {}
    all_ids = set(prior.records) | set(candidate.records)
    for adr_id in all_ids:
        before = prior.records.get(adr_id)
        after = candidate.records.get(adr_id)
        changed: set[str] = set()
        if before is None:
            changed.add("add")
        elif after is None:
            changed.add("remove")
        else:
            for field in ("path", "baseline", "status", "domain", "scopes"):
                if before[field] != after[field]:
                    changed.add(field)
            if before["evidence"] != after["evidence"] and not set(before["evidence"]).issubset(set(after["evidence"])):
                changed.add("remove")
            if before["title"] != after["title"]:
                if before["status"] == after["status"] == "Proposed":
                    changed.add("proposed-body")
                else:
                    changed.add("title")
            if before["blob"] != after["blob"] and not ({"status", "path", "baseline"} & changed):
                try:
                    before_raw = read_blob(repository, prior.revision, before["path"], MAX_ADR_BYTES)
                    after_raw = read_blob(repository, candidate.revision, after["path"], MAX_ADR_BYTES)
                    before_metadata, before_body = parse_metadata(before_raw, before["path"])
                    after_metadata, after_body = parse_metadata(after_raw, after["path"])
                    if before["status"] == after["status"] == "Proposed" and (before_body != after_body or before_metadata != after_metadata):
                        changed.add("proposed-body")
                    elif before_body != after_body or before_metadata != after_metadata:
                        changed.add("remove")
                except (ValueError, OverflowError):
                    changed.add("remove")
        if changed:
            actions[adr_id] = changed
    return actions


def validate_lifecycle_transition(
    repository: Path,
    prior: SnapshotData,
    candidate: SnapshotData,
) -> list[dict[str, Any]]:
    diagnostics: list[dict[str, Any]] = []
    allowed_status_changes = {
        ("Proposed", "Accepted"),
        ("Proposed", "Rejected"),
        ("Accepted", "Superseded"),
    }
    for adr_id in set(candidate.records) - set(prior.records):
        record = candidate.records[adr_id]
        if record["status"] != "Proposed":
            diagnostics.append(diagnostic(
                "ADR_TRANSITION_UNAUTHORIZED",
                "A normal transition can add only a Proposed decision.",
                id=adr_id, path=record["path"], actual=record["status"],
            ))
    for adr_id in set(prior.records) & set(candidate.records):
        before = prior.records[adr_id]
        after = candidate.records[adr_id]
        if before["title"] != after["title"] and not (
            before["status"] == after["status"] == "Proposed"
        ):
            diagnostics.append(diagnostic(
                "ADR_TRANSITION_UNAUTHORIZED",
                "A non-Proposed decision title cannot change in place.",
                id=adr_id, expected=before["title"], actual=after["title"],
            ))
        if before["status"] != after["status"]:
            transition = (before["status"], after["status"])
            if transition not in allowed_status_changes:
                diagnostics.append(diagnostic(
                    "ADR_TRANSITION_UNAUTHORIZED",
                    "Decision status change is not an allowed lifecycle transition.",
                    id=adr_id, expected=before["status"], actual=after["status"],
                ))
            elif transition == ("Proposed", "Accepted"):
                baseline = after["baseline"]
                expected_blob = prior.tree.get(before["path"])
                try:
                    previous_raw = read_blob(repository, prior.revision, before["path"], MAX_ADR_BYTES)
                    _, previous_body = parse_metadata(previous_raw, before["path"])
                    expected_body_hash = hashlib.sha256(previous_body).hexdigest()
                except (ValueError, OverflowError):
                    expected_body_hash = None
                if (
                    baseline is None
                    or baseline.get("commit") != prior.revision
                    or baseline.get("path") != before["path"]
                    or expected_blob is None
                    or baseline.get("blob") != expected_blob.oid
                    or baseline.get("bodySha256") != expected_body_hash
                ):
                    diagnostics.append(diagnostic(
                        "ADR_TRANSITION_UNAUTHORIZED",
                        "Acceptance baseline is not the exact previously committed Proposed candidate.",
                        id=adr_id, path=before["path"],
                    ))
        if not set(before["evidence"]).issubset(set(after["evidence"])):
            diagnostics.append(diagnostic(
                "ADR_TRANSITION_UNAUTHORIZED",
                "Transition removed prior approval or provenance evidence.",
                id=adr_id, path=after["path"],
            ))
    return diagnostics


def transition_command(arguments: argparse.Namespace) -> int:
    repository = Path(arguments.repository).resolve()
    diagnostics = verify_repository_identity(repository, arguments.wiki_repository)
    head, freshness_error = remote_head(arguments.wiki_repository)
    if freshness_error is not None:
        diagnostics.append(freshness_error)
    elif head != arguments.prior_revision:
        diagnostics.append(diagnostic("ADR_SNAPSHOT_STALE", "Prior transition revision is not current canonical Wiki HEAD.", expected=head, actual=arguments.prior_revision))

    authorization, auth_error = authorization_data(Path(arguments.authorization))
    if auth_error is not None:
        diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", f"Transition authorization is invalid: {auth_error}"))
    elif authorization is not None and (
        authorization["ticket"] != arguments.ticket
        or authorization["operation"] != arguments.operation
        or authorization["priorRevision"] != arguments.prior_revision
        or authorization["candidateRevision"] != arguments.candidate_revision
    ):
        diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Transition authorization does not bind this invocation."))

    ancestry = run_git(repository, "merge-base", "--is-ancestor", arguments.prior_revision, arguments.candidate_revision)
    if ancestry.returncode != 0:
        diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", "Candidate is not a descendant of the trusted prior revision.", expected=arguments.prior_revision, actual=arguments.candidate_revision))

    prior_tree: dict[str, TreeEntry] = {}
    try:
        prior_tree = parse_tree(repository, arguments.prior_revision)
    except ValueError as error:
        diagnostics.append(diagnostic("ADR_SOURCE_UNSAFE", f"Prior revision cannot be read: {error}"))

    candidate = validate_snapshot_content(repository, arguments.candidate_revision, arguments.scope, [])
    diagnostics.extend(candidate.diagnostics)
    selected_ids = candidate.selected_ids
    if arguments.initial_catalog:
        if CATALOG_PATH in prior_tree:
            diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Initial catalog mode is invalid after a catalog already exists.", path=CATALOG_PATH))
        if authorization is not None:
            approved = {change["id"]: set(change["actions"]) for change in authorization["changes"]}
            required = set(candidate.records)
            if set(approved) != required or any(actions != {"add"} for actions in approved.values()):
                diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Initial catalog authorization must bind add for every candidate record."))
    else:
        prior = validate_snapshot_content(repository, arguments.prior_revision, arguments.scope, [])
        diagnostics.extend(prior.diagnostics)
        if authorization is not None and prior.catalog is not None and candidate.catalog is not None:
            diagnostics.extend(validate_lifecycle_transition(repository, prior, candidate))
            actual = actual_transition_actions(repository, prior, candidate)
            approved = {change["id"]: set(change["actions"]) for change in authorization["changes"]}
            if actual != approved:
                diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Transition changes do not exactly match structured authorization.", expected={key: sorted(value) for key, value in actual.items()}, actual={key: sorted(value) for key, value in approved.items()}))

    value = result(
        "blocked" if diagnostics else "verified", arguments.ticket,
        arguments.operation, arguments.wiki_repository, arguments.candidate_revision,
        selected_ids, arguments.scope, diagnostics,
    )
    return emit(value)


def render_index_command(arguments: argparse.Namespace) -> int:
    repository = Path(arguments.repository).resolve()
    tree = parse_tree(repository, arguments.revision)
    entry = tree.get(CATALOG_PATH)
    if entry is None or entry.mode != "100644" or entry.kind != "blob":
        raise ValueError("pinned revision has no safe ADR catalog")
    object_format = git_bytes(repository, "rev-parse", "--show-object-format").decode("ascii").strip()
    catalog = strict_json_bytes(read_blob(repository, arguments.revision, CATALOG_PATH, MAX_JSON_BYTES), MAX_JSON_BYTES)
    _, diagnostics = validate_catalog(catalog, object_format)
    if diagnostics:
        raise ValueError("pinned ADR catalog is invalid")
    sys.stdout.buffer.write(render_index(catalog))
    return 0


def read_contract_command(arguments: argparse.Namespace) -> int:
    repository = Path(arguments.repository).resolve()
    diagnostics = verify_repository_identity(repository, CANONICAL_WIKI)
    path, expected_blob = ACCEPTED_CONTRACTS[arguments.contract]
    try:
        tree = parse_tree(repository, ACCEPTED_CONTRACT_REVISION)
        entry = tree.get(path)
        if entry is None or entry.mode != "100644" or entry.kind != "blob" or entry.oid != expected_blob:
            diagnostics.append(diagnostic(
                "ADR_SOURCE_UNSAFE",
                "Accepted supporting contract object is missing, changed, or unsafe.",
                path=path, expected=expected_blob,
                actual=entry.oid if entry is not None and entry.kind == "blob" else None,
            ))
        else:
            raw = read_blob(repository, ACCEPTED_CONTRACT_REVISION, path, MAX_ADR_BYTES)
            if git_blob_id(raw, "sha1") != expected_blob:
                diagnostics.append(diagnostic(
                    "ADR_SOURCE_UNSAFE",
                    "Accepted supporting contract bytes do not hash to the fixed blob ID.",
                    path=path, expected=expected_blob,
                    actual=git_blob_id(raw, "sha1"),
                ))
    except (ValueError, OverflowError) as error:
        diagnostics.append(diagnostic(
            "ADR_SOURCE_UNSAFE",
            f"Accepted supporting contract cannot be read safely: {error}",
            path=path, expected=expected_blob,
        ))
    if diagnostics:
        sys.stderr.write(json.dumps({"status": "blocked", "diagnostics": diagnostics}, separators=(",", ":")) + "\n")
        return 2
    sys.stdout.buffer.write(raw)
    return 0


def extract_exception_block(body: str) -> bytes:
    opening = "```adr-exception-v1\n"
    closing = "```\n"
    if body.count(opening) != 1 or not body.startswith(opening) or not body.endswith(closing):
        raise StrictJSONError("exception comment must contain only one adr-exception-v1 block")
    block_text = body[len(opening):-len(closing)]
    if "```" in block_text or not block_text.endswith("\n"):
        raise StrictJSONError("exception block fence or final LF is invalid")
    block = block_text.encode("utf-8")
    if len(block) > MAX_EXCEPTION_BYTES:
        raise StrictJSONError("exception block exceeds 64 KiB")
    return block


def validate_issue_snapshot(value: Any) -> str | None:
    if not exact_fields(value, {"version", "issue", "comments", "commentsComplete"}) or value["version"] != 1 or type(value["commentsComplete"]) is not bool or type(value["comments"]) is not list or not exact_fields(value["issue"], {"url", "state", "body"}):
        return "issue snapshot shape is invalid"
    if not nonempty_string(value["issue"].get("url"), 2048) or not nonempty_string(value["issue"].get("state"), 128) or type(value["issue"].get("body")) is not str or "\x00" in value["issue"]["body"]:
        return "issue snapshot values are invalid"
    for comment in value["comments"]:
        if not exact_fields(comment, {"id", "url", "updatedAt", "body"}) or not all(nonempty_string(comment.get(key), 2048) for key in ("id", "url", "updatedAt")) or type(comment.get("body")) is not str or "\x00" in comment["body"]:
            return "issue comment shape is invalid"
    return None


def validate_trusted_approval(value: Any) -> str | None:
    fields = {"version", "exceptionId", "repository", "wikiRepository", "issue", "operation", "commentId", "commentUpdatedAt", "blockSha256", "approvalRef", "revokedOrResolvedIds"}
    if not exact_fields(value, fields) or value["version"] != 1 or type(value["revokedOrResolvedIds"]) is not list:
        return "trusted approval shape is invalid"
    string_limits = {
        "exceptionId": 128, "repository": 2048, "wikiRepository": 2048,
        "issue": 2048, "operation": 128, "commentId": 128,
        "commentUpdatedAt": 128, "blockSha256": 64, "approvalRef": 4096,
    }
    if any(not nonempty_string(value.get(key), limit) for key, limit in string_limits.items()) or SHA256.fullmatch(value["blockSha256"]) is None or any(not nonempty_string(item, 128) for item in value["revokedOrResolvedIds"]):
        return "trusted approval values are invalid"
    return None


def validate_exception_record(value: Any, object_format: str) -> str | None:
    fields = {"version", "exceptionId", "repository", "wikiRepository", "issue", "operation", "scopes", "failures", "catalogBlob", "indexBlob", "catalogRevision", "reason", "risk", "accountablePerson", "expiresAt", "resolutionCriteria", "approvalRef"}
    if not exact_fields(value, fields) or value["version"] != 1:
        return "exception record fields are invalid"
    limits = {
        "exceptionId": 128, "repository": 2048, "wikiRepository": 2048,
        "issue": 2048, "operation": 128, "reason": 4096, "risk": 4096,
        "accountablePerson": 4096, "expiresAt": 128,
        "resolutionCriteria": 4096, "approvalRef": 4096,
    }
    if any(not nonempty_string(value.get(key), limit) for key, limit in limits.items()):
        return "exception record strings are invalid"
    if type(value["scopes"]) is not list or not value["scopes"] or len(value["scopes"]) > 100 or any(not nonempty_string(scope, 128) for scope in value["scopes"]):
        return "exception scopes are invalid"
    oid_pattern = object_id_pattern(object_format)
    if any(type(value[key]) is not str or oid_pattern.fullmatch(value[key]) is None for key in ("catalogBlob", "indexBlob", "catalogRevision")):
        return "exception snapshot object IDs are invalid"
    if RFC3339_UTC.fullmatch(value["expiresAt"]) is None:
        return "exception expiry is not strict RFC 3339 UTC"
    if type(value["failures"]) is not list or not value["failures"] or len(value["failures"]) > 100:
        return "exception failures are invalid"
    failure_fields = {"code", "revision", "path", "expectedBlob", "observedBlob", "reliedOn"}
    relied_fields = {"commit", "path", "blob", "bodySha256"}
    seen: set[tuple[str, str, str]] = set()
    for failure in value["failures"]:
        if not exact_fields(failure, failure_fields) or failure["code"] not in ELIGIBLE_FAILURES or type(failure["revision"]) is not str or oid_pattern.fullmatch(failure["revision"]) is None or not nonempty_string(failure["path"], 255) or (ADR_FILENAME.fullmatch(failure["path"]) is None and failure["path"] not in {CATALOG_PATH, INDEX_PATH}) or type(failure["reliedOn"]) is not list or not failure["reliedOn"]:
            return "exception failure tuple is invalid"
        for key in ("expectedBlob", "observedBlob"):
            if failure[key] is not None and (type(failure[key]) is not str or oid_pattern.fullmatch(failure[key]) is None):
                return "exception failure blob is invalid"
        identity = (failure["code"], failure["revision"], failure["path"])
        if identity in seen:
            return "exception failure tuple is duplicated"
        seen.add(identity)
        for relied in failure["reliedOn"]:
            if not exact_fields(relied, relied_fields) or type(relied["commit"]) is not str or oid_pattern.fullmatch(relied["commit"]) is None or not nonempty_string(relied["path"], 255) or ADR_FILENAME.fullmatch(relied["path"]) is None or type(relied["blob"]) is not str or oid_pattern.fullmatch(relied["blob"]) is None or type(relied["bodySha256"]) is not str or SHA256.fullmatch(relied["bodySha256"]) is None:
                return "relied-on ADR tuple is invalid"
    return None


def reliance_for_document(
    repository: Path,
    commit: str,
    path: str,
    expected_blob: str | None = None,
    expected_id: str | None = None,
    allowed_statuses: set[str] | None = None,
) -> dict[str, str]:
    tree = parse_tree(repository, commit)
    entry = tree.get(path)
    if entry is None or entry.mode != "100644" or entry.kind != "blob":
        raise ValueError("relied-on ADR is not a safe regular blob")
    if expected_blob is not None and entry.oid != expected_blob:
        raise ValueError("relied-on ADR blob does not match its fixed identity")
    raw = read_blob(repository, commit, path, MAX_ADR_BYTES)
    metadata, body = parse_metadata(raw, path)
    if expected_id is not None and metadata["ID"] != expected_id:
        raise ValueError("relied-on ADR metadata ID does not match its catalog record")
    if allowed_statuses is not None and metadata["Status"] not in allowed_statuses:
        raise ValueError("relied-on ADR source status is invalid")
    return {
        "commit": commit,
        "path": path,
        "blob": entry.oid,
        "bodySha256": hashlib.sha256(body).hexdigest(),
    }


def validate_exception_semantics(
    repository: Path,
    current: SnapshotData,
    exception_record: dict[str, Any],
) -> list[dict[str, Any]]:
    diagnostics: list[dict[str, Any]] = []
    failures = exception_record["failures"]
    remaining = list(failures)
    expected_reliance: list[dict[str, str]] = []

    for adr_id in current.selected_ids:
        record = current.records.get(adr_id)
        if record is None:
            continue
        entry = current.tree.get(record["path"])
        try:
            if entry is not None and entry.mode == "100644" and entry.kind == "blob":
                expected_reliance.append(reliance_for_document(
                    repository, current.revision, record["path"], entry.oid,
                    expected_id=adr_id, allowed_statuses={record["status"]},
                ))
            elif record["status"] in {"Accepted", "Superseded"} and record["baseline"] is not None:
                baseline = record["baseline"]
                expected_reliance.append(reliance_for_document(
                    repository, baseline["commit"], baseline["path"], baseline["blob"],
                    expected_id=adr_id, allowed_statuses={"Proposed", "Accepted"},
                ))
        except (ValueError, OverflowError):
            diagnostics.append(diagnostic("ADR_BASELINE_UNAVAILABLE", "Selected relied-on ADR bytes cannot be verified.", id=adr_id, path=record["path"]))

    for item in current.diagnostics:
        match: dict[str, Any] | None = None
        for failure in remaining:
            if failure["code"] != item["code"] or failure["revision"] != current.revision:
                continue
            code = item["code"]
            if code in {"ADR_SNAPSHOT_STALE", "ADR_FRESHNESS_UNAVAILABLE"}:
                retained_catalog = current.tree.get(CATALOG_PATH)
                if retained_catalog is None or retained_catalog.mode != "100644" or retained_catalog.kind != "blob":
                    continue
                if (
                    failure["path"] == CATALOG_PATH
                    and failure["expectedBlob"] == retained_catalog.oid
                    and failure["observedBlob"] == retained_catalog.oid
                ):
                    match = failure
            elif code == "ADR_MISSING":
                record = next((record for record in current.records.values() if record["path"] == item.get("path")), None)
                if record is None or record["status"] not in {"Accepted", "Superseded"} or record["baseline"] is None:
                    continue
                baseline = record["baseline"]
                try:
                    baseline_reliance = reliance_for_document(
                        repository, baseline["commit"], baseline["path"], baseline["blob"],
                        expected_id=record["id"], allowed_statuses={"Proposed", "Accepted"},
                    )
                except (ValueError, OverflowError):
                    continue
                if baseline_reliance["bodySha256"] != baseline["bodySha256"]:
                    continue
                if (
                    failure["path"] == record["path"]
                    and failure["expectedBlob"] == record["blob"]
                    and failure["observedBlob"] is None
                    and baseline_reliance in failure["reliedOn"]
                ):
                    match = failure
            elif code == "ADR_UNCATALOGUED":
                path = item.get("path")
                entry = current.tree.get(path) if type(path) is str else None
                if entry is None or entry.mode != "100644" or entry.kind != "blob":
                    continue
                try:
                    raw = read_blob(repository, current.revision, path, MAX_ADR_BYTES)
                    metadata, _ = parse_metadata(raw, path)
                    proposed_reliance = reliance_for_document(
                        repository, current.revision, path, entry.oid,
                        expected_id=metadata["ID"], allowed_statuses={"Proposed"},
                    )
                except (ValueError, OverflowError):
                    continue
                if (
                    metadata["Status"] == "Proposed"
                    and failure["path"] == path
                    and failure["expectedBlob"] is None
                    and failure["observedBlob"] == entry.oid
                    and proposed_reliance in failure["reliedOn"]
                ):
                    match = failure
                    expected_reliance.append(proposed_reliance)
            elif code == "ADR_BLOB_MISMATCH":
                record = next((record for record in current.records.values() if record["path"] == item.get("path")), None)
                if record is None or record["status"] not in {"Accepted", "Superseded"} or record["baseline"] is None:
                    continue
                entry = current.tree.get(record["path"])
                if entry is None or entry.mode != "100644" or entry.kind != "blob":
                    continue
                try:
                    observed_reliance = reliance_for_document(
                        repository, current.revision, record["path"], entry.oid,
                        expected_id=record["id"], allowed_statuses={record["status"]},
                    )
                except (ValueError, OverflowError):
                    continue
                if (
                    failure["path"] == record["path"]
                    and failure["expectedBlob"] == record["blob"]
                    and failure["observedBlob"] == entry.oid
                    and observed_reliance in failure["reliedOn"]
                ):
                    match = failure
            if match is not None:
                break
        if match is None:
            diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception failure does not satisfy its exact eligible-condition binding.", actual=item["code"]))
        else:
            remaining.remove(match)

    if remaining:
        diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception contains failures not present in the current check."))

    actual_reliance = {
        (item["commit"], item["path"], item["blob"], item["bodySha256"])
        for failure in failures for item in failure["reliedOn"]
    }
    required_reliance = {
        (item["commit"], item["path"], item["blob"], item["bodySha256"])
        for item in expected_reliance
    }
    if actual_reliance != required_reliance:
        diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception reliedOn entries do not exactly bind every consumed ADR."))
    return diagnostics


def exception_command(arguments: argparse.Namespace) -> int:
    repository = Path(arguments.repository).resolve()
    current = validate_snapshot_content(repository, arguments.revision, arguments.scope, [])
    add_freshness(repository, arguments.wiki_repository, arguments.revision, current.diagnostics)
    recomputed = result(
        "blocked" if current.diagnostics else "verified", arguments.ticket,
        arguments.operation, arguments.wiki_repository, arguments.revision,
        current.selected_ids, arguments.scope, current.diagnostics,
    )
    diagnostics = list(current.diagnostics)
    approval_diagnostics: list[dict[str, Any]] = []
    try:
        prior_result = strict_json_file(Path(arguments.diagnostics))
        issue_snapshot = strict_json_file(Path(arguments.issue_snapshot))
        trusted = strict_json_file(Path(arguments.trusted_approval))
    except StrictJSONError as error:
        approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", f"Exception input is invalid: {error}"))
        prior_result = issue_snapshot = trusted = None

    if prior_result is not None and prior_result != recomputed:
        approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Current integrity diagnostics no longer match the approved blocked result."))
    if current.diagnostics and any(item["code"] not in ELIGIBLE_FAILURES for item in current.diagnostics):
        approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "At least one current integrity failure is ineligible for exception."))
    if not current.diagnostics:
        approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Ordinary ADR verification no longer needs an exception."))

    issue_error = validate_issue_snapshot(issue_snapshot) if issue_snapshot is not None else "missing issue snapshot"
    trusted_error = validate_trusted_approval(trusted) if trusted is not None else "missing trusted approval"
    if issue_error:
        approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", issue_error))
    if trusted_error:
        approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", trusted_error))

    exception_record: dict[str, Any] | None = None
    if not issue_error and not trusted_error:
        assert type(issue_snapshot) is dict and type(trusted) is dict
        if not issue_snapshot["commentsComplete"] or issue_snapshot["issue"]["state"].upper() != "OPEN" or issue_snapshot["issue"]["url"] != arguments.ticket:
            approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception issue is closed, incomplete, or mismatched."))
        bound_comments = [comment for comment in issue_snapshot["comments"] if comment["id"] == trusted["commentId"]]
        if len(bound_comments) != 1:
            approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Bound exception comment is unavailable."))
        else:
            comment = bound_comments[0]
            if comment["updatedAt"] != trusted["commentUpdatedAt"]:
                approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Bound exception comment was edited."))
            try:
                block = extract_exception_block(comment["body"])
                if hashlib.sha256(block).hexdigest() != trusted["blockSha256"]:
                    raise StrictJSONError("exception block hash does not match trusted approval")
                parsed_record = strict_json_bytes(block, MAX_EXCEPTION_BYTES)
                if type(parsed_record) is not dict:
                    raise StrictJSONError("exception block is not an object")
                exception_record = parsed_record
            except StrictJSONError as error:
                approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", f"Exception block is invalid: {error}"))

        marker_text = "\n".join([issue_snapshot["issue"]["body"]] + [comment["body"] for comment in issue_snapshot["comments"]])
        exception_id = trusted["exceptionId"]
        revoked = f"ADR-EXCEPTION-REVOKED: {exception_id}"
        resolved = f"ADR-EXCEPTION-RESOLVED: {exception_id}"
        if any(line in {revoked, resolved} for line in marker_text.splitlines()) or exception_id in trusted["revokedOrResolvedIds"]:
            approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception is revoked or resolved."))

    if exception_record is not None and current.object_format is not None and trusted is not None:
        record_error = validate_exception_record(exception_record, current.object_format)
        if record_error:
            approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", record_error))
        else:
            bindings = {
                "exceptionId": trusted["exceptionId"],
                "repository": trusted["repository"],
                "wikiRepository": arguments.wiki_repository,
                "issue": arguments.ticket,
                "operation": arguments.operation,
                "approvalRef": trusted["approvalRef"],
            }
            if trusted["repository"] != DEVELOPMENT_REPOSITORY or any(exception_record[key] != expected for key, expected in bindings.items()) or trusted["wikiRepository"] != arguments.wiki_repository or trusted["issue"] != arguments.ticket or trusted["operation"] != arguments.operation or exception_record["scopes"] != arguments.scope:
                approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception terms do not bind this repository, issue, operation, scope, or approval."))
            try:
                now = datetime.now(timezone.utc)
                expires = datetime.fromisoformat(exception_record["expiresAt"][:-1] + "+00:00")
                if now >= expires:
                    approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception has expired."))
            except ValueError:
                approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception expiry is invalid."))
            if exception_record["catalogRevision"] != arguments.revision:
                approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception catalog revision is not the current checked revision."))
            catalog_entry = current.tree.get(CATALOG_PATH)
            index_entry = current.tree.get(INDEX_PATH)
            if catalog_entry is None or index_entry is None or exception_record["catalogBlob"] != catalog_entry.oid or exception_record["indexBlob"] != index_entry.oid:
                approval_diagnostics.append(diagnostic("ADR_TRANSITION_UNAUTHORIZED", "Exception catalog or index blob binding is stale."))

            approval_diagnostics.extend(validate_exception_semantics(repository, current, exception_record))

    diagnostics.extend(approval_diagnostics)
    if not approval_diagnostics and exception_record is not None:
        exception_output = {
            "exceptionId": exception_record["exceptionId"],
            "sourceRevision": arguments.revision,
            "scopes": exception_record["scopes"],
            "operation": exception_record["operation"],
            "expiresAt": exception_record["expiresAt"],
            "approvalRef": exception_record["approvalRef"],
            "issue": exception_record["issue"],
            "failures": exception_record["failures"],
            "currentness": (
                "unknown"
                if any(item["code"] == "ADR_FRESHNESS_UNAVAILABLE" for item in current.diagnostics)
                else "retained-not-current"
                if any(item["code"] == "ADR_SNAPSHOT_STALE" for item in current.diagnostics)
                else "current"
            ),
        }
        value = result(
            "proceeding_under_exception", arguments.ticket, arguments.operation,
            arguments.wiki_repository, arguments.revision, current.selected_ids,
            arguments.scope, current.diagnostics, exception_output,
        )
    else:
        value = result(
            "blocked", arguments.ticket, arguments.operation,
            arguments.wiki_repository, arguments.revision, current.selected_ids,
            arguments.scope, diagnostics,
        )
    return emit(value)


def build_parser() -> Parser:
    parser = Parser(prog="adr_checker.py")
    subparsers = parser.add_subparsers(dest="command", required=True, parser_class=Parser)

    def common(subparser: Parser, revision_name: str = "revision") -> None:
        subparser.add_argument("--repository", required=True)
        subparser.add_argument("--wiki-repository", required=True)
        subparser.add_argument(f"--{revision_name.replace('_', '-')}", dest=revision_name, required=True)
        subparser.add_argument("--ticket", required=True)
        subparser.add_argument("--operation", required=True)
        subparser.add_argument("--scope", action="append", required=True)

    snapshot = subparsers.add_parser("snapshot")
    common(snapshot)
    snapshot.add_argument("--id", action="append", default=[])
    snapshot.set_defaults(handler=snapshot_command)

    transition = subparsers.add_parser("transition")
    transition.add_argument("--repository", required=True)
    transition.add_argument("--wiki-repository", required=True)
    transition.add_argument("--prior-revision", required=True)
    transition.add_argument("--candidate-revision", required=True)
    transition.add_argument("--ticket", required=True)
    transition.add_argument("--operation", required=True)
    transition.add_argument("--scope", action="append", required=True)
    transition.add_argument("--authorization", required=True)
    transition.add_argument("--initial-catalog", action="store_true")
    transition.set_defaults(handler=transition_command)

    renderer = subparsers.add_parser("render-index")
    renderer.add_argument("--repository", required=True)
    renderer.add_argument("--revision", required=True)
    renderer.set_defaults(handler=render_index_command)

    contract = subparsers.add_parser("read-contract")
    contract.add_argument("--repository", required=True)
    contract.add_argument("--contract", choices=sorted(ACCEPTED_CONTRACTS), required=True)
    contract.set_defaults(handler=read_contract_command)

    exception = subparsers.add_parser("exception")
    common(exception)
    exception.add_argument("--diagnostics", required=True)
    exception.add_argument("--issue-snapshot", required=True)
    exception.add_argument("--trusted-approval", required=True)
    exception.set_defaults(handler=exception_command)
    return parser


def main() -> int:
    try:
        arguments = build_parser().parse_args()
        return arguments.handler(arguments)
    except UsageError as error:
        sys.stderr.write(f"usage error: {error}\n")
        return 64
    except Exception as error:
        sys.stderr.write(f"internal error: {error}\n")
        return 70


if __name__ == "__main__":
    raise SystemExit(main())
